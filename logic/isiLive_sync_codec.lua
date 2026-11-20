local _, addonTable = ...

addonTable = addonTable or {}

-- Sync wire codec: numeric bounds, peer-string normalization and the payload
-- encoders and parsers shared by the Sync senders (logic/isiLive_sync.lua),
-- the peer-state store (logic/isiLive_sync_peer_state.lua) and the receiver
-- (logic/isiLive_sync_receive.lua). Pure functions only: no send path and no
-- stored peer data.
local SyncCodec = {}
addonTable.SyncCodec = SyncCodec
local SeasonData = addonTable.SeasonData or {}
local StringUtils = addonTable.StringUtils

local ISILIVE_SYNC_PROTOCOL_VERSION = 2
local MAX_SAFE_INTEGER = 9007199254740991

-- Upper sanity bounds for numeric peer payloads. These are NOT claims about
-- game limits -- they are display bounds. Without them a broken or hostile
-- peer can publish a key level or rating up to MAX_SAFE_INTEGER, which renders
-- into the roster and blows up the column layout for everyone in the group.
-- The rest of the ingest path is already strict this way (ParseKickPayload
-- rejects malformed suffixes outright, SKCD caps at 30s). Values above the
-- bound are treated as unresolved rather than clamped, per the fail-closed
-- contract: a silently clamped number would be a fabricated value.
--
-- Every numeric bucket that reaches a rendered surface is covered: KEY and
-- STATS, plus TARGET (carries its own key level, rendered as "+<level>" in the
-- kill row) and DPS (roster DPS column). TARGET and DPS were missed when the
-- first two were added, which left exactly the gap this comment claimed to
-- close -- so when adding a new numeric bucket, bound it here as well.
local MAX_SYNC_KEY_LEVEL = 1000
local MAX_SYNC_ILVL = 10000
local MAX_SYNC_RIO = 100000
-- Roughly two orders of magnitude above realistic end-of-expansion dps, so it
-- only ever catches broken or hostile values, never a real parse.
local MAX_SYNC_DPS = 100000000
-- Far above any interrupt or stun cooldown; the kick column renders this value.
local MAX_SYNC_KICK_REMAIN = 3600
-- Own interrupt casts of one run (rule 238, KC suffix of the DPS bucket); far
-- above any real key, rendered in the kick column as "cast/landed".
local MAX_SYNC_RUN_KICKS = 1000

local function ToFiniteNumber(value)
  local numericValue = tonumber(value)
  if
    numericValue == nil
    or numericValue ~= numericValue
    or numericValue == math.huge
    or numericValue == -math.huge
    or math.abs(numericValue) > MAX_SAFE_INTEGER
  then
    return nil
  end
  return numericValue
end

local function IsExplicitNonFiniteNumber(value)
  return tonumber(value) ~= nil and ToFiniteNumber(value) == nil
end

local function FormatBytes(value)
  local text = tostring(value or "")
  if text == "" then
    return ""
  end
  local out = {}
  for i = 1, #text do
    out[#out + 1] = string.format("%02X", string.byte(text, i))
  end
  return table.concat(out, "-")
end

local function GetSyncTimestamp()
  local getServerTime = rawget(_G, "GetServerTime")
  if type(getServerTime) == "function" then
    local ok, serverTime = pcall(getServerTime)
    local numericServerTime = ok and ToFiniteNumber(serverTime) or nil
    if numericServerTime and numericServerTime > 0 then
      return math.floor(numericServerTime)
    end
  end

  local timeFn = rawget(_G, "time")
  if type(timeFn) == "function" then
    local ok, unixTime = pcall(timeFn)
    local numericUnixTime = ok and ToFiniteNumber(unixTime) or nil
    if numericUnixTime and numericUnixTime > 0 then
      return math.floor(numericUnixTime)
    end
  end

  local getTime = rawget(_G, "GetTime")
  if type(getTime) == "function" then
    local ok, elapsed = pcall(getTime)
    local numericElapsed = ok and ToFiniteNumber(elapsed) or nil
    if numericElapsed and numericElapsed > 0 then
      return math.floor(numericElapsed)
    end
  end

  return nil
end

local function NormalizeSyncSource(source)
  local text = StringUtils.Trim(source and tostring(source) or ""):lower()
  text = text:gsub("%s+", "_"):gsub("[^%w_%-]", "")
  if text == "" then
    return nil
  end
  return text
end

-- Peer-supplied version strings are rendered verbatim in the roster tooltip,
-- where WoW interprets `|c`, `|T` and `|H` escapes. Every other peer string
-- field is normalized before it is stored (see NormalizeSyncSource and the
-- levelText pattern check), so this one follows the same whitelist approach:
-- SemVer characters only, which drops any UI markup a modified client could
-- send. Length is capped so a peer cannot stretch the tooltip line.
local MAX_SYNC_ADDON_VERSION_LENGTH = 32

local function NormalizeSyncAddonVersion(addonVersion)
  local text = StringUtils.Trim(addonVersion and tostring(addonVersion) or "")
  text = text:gsub("[^%w%.%-_+]", "")
  if text == "" then
    return nil
  end
  return text:sub(1, MAX_SYNC_ADDON_VERSION_LENGTH)
end

-- Peer-supplied player names that are not checked against the authenticated
-- sender (the Power Infusion recipient) are printed into the local chat frame,
-- which interprets the same `|` escapes. A real "Name-Realm" never contains a
-- pipe or a control character, so such a name is rejected rather than cleaned
-- up. The byte cap covers a 12-glyph UTF-8 name plus the longest realm suffix.
local MAX_SYNC_PEER_NAME_LENGTH = 96

local function IsPlainPeerName(text)
  return type(text) == "string" and text ~= "" and #text <= MAX_SYNC_PEER_NAME_LENGTH and not text:find("[|%c]")
end

local function NormalizeSyncProtocolVersion(protocolVersion)
  local numericVersion = ToFiniteNumber(protocolVersion)
  if not numericVersion or numericVersion <= 0 then
    return ISILIVE_SYNC_PROTOCOL_VERSION
  end
  return math.floor(numericVersion)
end

local MAX_PAYLOAD_FIELDS = 10

local function SplitPayload(message)
  local parts = {}
  for part in (tostring(message or "") .. ":"):gmatch("(.-):") do
    if #parts >= MAX_PAYLOAD_FIELDS then
      break
    end
    parts[#parts + 1] = part
  end
  return parts
end

local function ParseKickPayload(message)
  if type(message) ~= "string" then
    return nil
  end

  local stateRaw, remainRaw, suffix = message:match("^KICK:([^:]+):([^:]+)(.*)$")
  if not stateRaw or not remainRaw then
    return nil
  end

  local numericState = ToFiniteNumber(stateRaw)
  local numericRemain = ToFiniteNumber(remainRaw)
  if
    not (
      (numericState == -1 or numericState == 0 or numericState == 1)
      and numericRemain
      and numericRemain >= 0
      and numericRemain <= MAX_SYNC_KICK_REMAIN
    )
  then
    return nil
  end

  local spellID = nil
  local extras = nil
  local sawExtras = false
  while suffix ~= "" do
    local spellRaw, afterSpell = suffix:match("^:S:(%d+)(.*)$")
    if spellRaw then
      if spellID ~= nil then
        return nil
      end
      spellID = ToFiniteNumber(spellRaw)
      if not spellID or spellID <= 0 then
        return nil
      end
      suffix = afterSpell or ""
    else
      local extrasRaw, afterExtras = suffix:match("^:E:([^:]+)(.*)$")
      if not extrasRaw or sawExtras then
        return nil
      end
      sawExtras = true
      if
        extrasRaw:find("[^%d,;]")
        or extrasRaw:sub(1, 1) == ";"
        or extrasRaw:sub(-1) == ";"
        or extrasRaw:find(";;", 1, true)
      then
        return nil
      end

      local count = 0
      for entry in extrasRaw:gmatch("[^;]+") do
        local sidStr, remainStr = entry:match("^(%d+),(%d+)$")
        local sid = ToFiniteNumber(sidStr)
        local rem = ToFiniteNumber(remainStr)
        if not sid or not rem or rem <= 0 or rem > MAX_SYNC_KICK_REMAIN then
          return nil
        end
        if count < 8 then
          extras = extras or {}
          extras[sid] = { cooldownRemain = rem }
          count = count + 1
        end
      end

      if count == 0 then
        return nil
      end
      suffix = afterExtras or ""
    end
  end

  if numericState == -1 and spellID ~= nil then
    return nil
  end

  return {
    state = numericState,
    remain = numericRemain,
    hasKick = numericState ~= -1,
    spellID = spellID,
    extras = extras,
  }
end

local function EncodeKickSpellSuffix(spellID, hasKick)
  if hasKick ~= true then
    return ""
  end
  local sid = ToFiniteNumber(spellID)
  if not sid or sid <= 0 then
    return ""
  end
  return string.format(":S:%d", math.floor(sid))
end

local function EncodeKickExtrasSuffix(extras)
  if type(extras) ~= "table" then
    return ""
  end

  -- Collect (spellID, remain) tuples, then sort numerically by spellID so
  -- the dedup-payload hash is deterministic regardless of pairs() order.
  -- Numerical sort matters when spell IDs differ in digit count (e.g. 1766
  -- Rogue Kick vs 119914 Axe Toss); a string-based sort would put "1766"
  -- after "119914" lexicographically, breaking dedup if the same map is
  -- emitted twice with shuffled pairs() order.
  local entries = {}
  for spellID, data in pairs(extras) do
    if type(data) == "table" then
      local sid = ToFiniteNumber(spellID)
      local r = ToFiniteNumber(data.cooldownRemain)
      if sid and r and r > 0 then
        entries[#entries + 1] = { sid = sid, remain = math.ceil(r) }
      end
    end
  end
  if #entries == 0 then
    return ""
  end

  table.sort(entries, function(a, b)
    return a.sid < b.sid
  end)
  local pieces = {}
  for _, e in ipairs(entries) do
    pieces[#pieces + 1] = string.format("%d,%d", e.sid, e.remain)
  end
  return ":E:" .. table.concat(pieces, ";")
end

-- ParseKickPayload is intentionally strict: every optional suffix segment
-- must be known and well-formed, otherwise the full KICK payload is dropped.
-- This preserves the no-guess contract for peer kick state.

local function NormalizeCapturedAtAndSource(capturedAt, source)
  local ts = ToFiniteNumber(capturedAt)
  if not ts or ts <= 0 then
    ts = GetSyncTimestamp() or 0
  end
  return math.floor(ts), NormalizeSyncSource(source) or "local"
end

local function NormalizeKeyPayload(mapID, level, capturedAt, source)
  local numericLevel = ToFiniteNumber(level)
  local numericMapID = ToFiniteNumber(mapID)
  if type(SeasonData.NormalizeMapID) == "function" then
    numericMapID = SeasonData.NormalizeMapID(numericMapID)
  end
  numericLevel = numericLevel and math.floor(numericLevel)
  numericMapID = numericMapID and math.floor(numericMapID)
  if
    not numericLevel
    or numericLevel <= 0
    or numericLevel > MAX_SYNC_KEY_LEVEL
    or not numericMapID
    or numericMapID <= 0
  then
    return string.format("KEY:0:0:%d:%s", GetSyncTimestamp() or 0, NormalizeSyncSource(source) or "local"),
      nil,
      nil,
      nil,
      nil
  end
  local normalizedCapturedAt, normalizedSource = NormalizeCapturedAtAndSource(capturedAt, source)
  return string.format("KEY:%d:%d:%d:%s", numericMapID, numericLevel, normalizedCapturedAt, normalizedSource),
    numericMapID,
    numericLevel,
    normalizedCapturedAt,
    normalizedSource
end

local function NormalizeStatsPayload(specID, ilvl, rio, capturedAt, source)
  local numericSpecID = ToFiniteNumber(specID)
  local numericIlvl = ToFiniteNumber(ilvl)
  local numericRio = ToFiniteNumber(rio)

  if not numericSpecID or numericSpecID <= 0 then
    numericSpecID = 0
  else
    numericSpecID = math.floor(numericSpecID)
  end

  if not numericIlvl or numericIlvl <= 0 or numericIlvl > MAX_SYNC_ILVL then
    numericIlvl = -1
  else
    numericIlvl = math.floor(numericIlvl)
  end

  if numericRio == nil or numericRio > MAX_SYNC_RIO then
    numericRio = -1
  else
    numericRio = math.floor(numericRio)
    if numericRio < 0 then
      numericRio = -1
    end
  end

  local normalizedCapturedAt, normalizedSource = NormalizeCapturedAtAndSource(capturedAt, source)
  return string.format(
    "STATS:%d:%d:%d:%d:%s",
    numericSpecID,
    numericIlvl,
    numericRio,
    normalizedCapturedAt,
    normalizedSource
  ),
    numericSpecID,
    numericIlvl,
    numericRio,
    normalizedCapturedAt,
    normalizedSource
end

local function NormalizeDpsPayload(dps, capturedAt, source)
  local numericDps = ToFiniteNumber(dps)
  if not numericDps or numericDps < 0 or numericDps > MAX_SYNC_DPS then
    numericDps = 0
  else
    numericDps = math.floor(numericDps + 0.5)
  end
  local normalizedCapturedAt, normalizedSource = NormalizeCapturedAtAndSource(capturedAt, source)
  return string.format("DPS:%d:%d:%s", numericDps, normalizedCapturedAt, normalizedSource),
    numericDps,
    normalizedCapturedAt,
    normalizedSource
end

-- Run kicks ride on the DPS bucket as the tagged suffix ":KC:<cast>:<mapID>:<level>"
-- (rule 238). Clients up to 0.9.506 read only fields 2-4 of a DPS payload and
-- ignore the suffix. The map ID and key level bind the count to the run it
-- was cast in; a receiver pairs it only with its own snapshot of that run.
-- Returns the suffix and the three normalized numbers, or "" when any part is
-- missing or out of bounds.
local function NormalizeRunKicksSuffix(cast, mapID, level)
  local numericCast = ToFiniteNumber(cast)
  local numericMapID = ToFiniteNumber(mapID)
  local numericLevel = ToFiniteNumber(level)
  if
    not numericCast
    or numericCast < 0
    or numericCast > MAX_SYNC_RUN_KICKS
    or numericCast ~= math.floor(numericCast)
    or not numericMapID
    or numericMapID <= 0
    or numericMapID ~= math.floor(numericMapID)
    or not numericLevel
    or numericLevel < 0
    or numericLevel > MAX_SYNC_KEY_LEVEL
    or numericLevel ~= math.floor(numericLevel)
  then
    return "", nil, nil, nil
  end
  return string.format(":KC:%d:%d:%d", numericCast, numericMapID, numericLevel), numericCast, numericMapID, numericLevel
end

-- The own missed kicks of the run (rule 240) follow the KC suffix as
-- ":KM:<missed>" (fields 9-10, inside the 10-field split). Clients up to
-- 0.9.508 read fields 5-8 only and ignore it. Returns the suffix and the
-- number, or "" when there is no KC suffix or the count is out of bounds
-- (negative, fractional or above the cast count).
local function NormalizeRunKicksMissedSuffix(missed, numericCast)
  local numericMissed = ToFiniteNumber(missed)
  if
    not numericCast
    or not numericMissed
    or numericMissed < 0
    or numericMissed > numericCast
    or numericMissed ~= math.floor(numericMissed)
  then
    return "", nil
  end
  return string.format(":KM:%d", numericMissed), numericMissed
end

local function NormalizePositiveLocID(value)
  local numeric = ToFiniteNumber(value)
  if not numeric or numeric <= 0 then
    return nil
  end
  return math.floor(numeric)
end

-- Wire format: LOC:<uiMapID>:<capturedAt>:<source>[:IN:<instanceID>]
-- Field 2 keeps the legacy UiMapID (C_Map.GetBestMapForUnit) so clients up to
-- 0.9.423, which read only fields 2-4, behave exactly as before. The party
-- instance ID (8th return of GetInstanceInfo) rides in the tagged "IN" suffix
-- (same extension style as the TARGET "LT" suffix). Every LOC-capable release
-- splits on ":" into at most 10 fields and ignores fields 5+ (rule 194).
local function NormalizeLocPayload(mapID, capturedAt, source, instanceID)
  local numericMapID = NormalizePositiveLocID(mapID)
  local numericInstanceID = NormalizePositiveLocID(instanceID)
  local normalizedCapturedAt, normalizedSource = NormalizeCapturedAtAndSource(capturedAt, source)
  local payload = string.format("LOC:%d:%d:%s", numericMapID or 0, normalizedCapturedAt, normalizedSource)
  if numericInstanceID then
    payload = payload .. ":IN:" .. numericInstanceID
  end
  return payload, numericMapID, normalizedCapturedAt, normalizedSource, numericInstanceID
end

local function NormalizeTargetLevelText(levelText, numericLevel)
  if numericLevel ~= nil then
    return nil
  end
  if type(levelText) == "string" and levelText:match("^|Kk%d+|k$") then
    return levelText
  end
  return nil
end

local function NormalizeTargetPayload(mapID, level, capturedAt, source, levelText)
  local numericMapID = ToFiniteNumber(mapID)
  local numericLevel = ToFiniteNumber(level)
  local normalizedCapturedAt, normalizedSource = NormalizeCapturedAtAndSource(capturedAt, source)
  local normalizedLevelText = nil
  if not numericMapID or numericMapID <= 0 then
    return string.format("TARGET:0:0:%d:%s", normalizedCapturedAt, normalizedSource),
      nil,
      nil,
      normalizedCapturedAt,
      normalizedSource,
      nil
  end

  numericMapID = math.floor(numericMapID)
  -- An out-of-range level is dropped to unresolved, not clamped, and the entry
  -- itself survives on its still-valid map id -- same handling as a missing
  -- level. Bounded like KEY: TARGET renders "+<level>" into the kill row.
  if not numericLevel or numericLevel <= 0 or numericLevel > MAX_SYNC_KEY_LEVEL then
    numericLevel = nil
    normalizedLevelText = NormalizeTargetLevelText(levelText, nil)
  else
    numericLevel = math.floor(numericLevel)
  end

  local payload =
    string.format("TARGET:%d:%d:%d:%s", numericMapID, numericLevel or 0, normalizedCapturedAt, normalizedSource)
  if normalizedLevelText then
    payload = payload .. ":LT:" .. normalizedLevelText
  end

  return payload, numericMapID, numericLevel, normalizedCapturedAt, normalizedSource, normalizedLevelText
end

-- LibKeystone party data, wire format "level,mapID,rio". An invalid key
-- encodes as 0,0 and a missing or negative rating as 0.
local function NormalizeLibKeystonePartyPayload(mapID, level, rio)
  local numericLevel = ToFiniteNumber(level)
  local numericMapID = ToFiniteNumber(mapID)
  if type(SeasonData.NormalizeMapID) == "function" then
    numericMapID = SeasonData.NormalizeMapID(numericMapID)
  end

  if
    not numericLevel
    or numericLevel <= 0
    or numericLevel > MAX_SYNC_KEY_LEVEL
    or not numericMapID
    or numericMapID <= 0
  then
    numericLevel = 0
    numericMapID = 0
  else
    numericLevel = math.floor(numericLevel)
    numericMapID = math.floor(numericMapID)
  end

  local numericRio = ToFiniteNumber(rio)
  if numericRio == nil or numericRio < 0 then
    numericRio = 0
  else
    numericRio = math.floor(numericRio)
  end

  return string.format("%d,%d,%d", numericLevel, numericMapID, numericRio), numericLevel, numericMapID, numericRio
end

SyncCodec.PROTOCOL_VERSION = ISILIVE_SYNC_PROTOCOL_VERSION
SyncCodec.ToFiniteNumber = ToFiniteNumber
SyncCodec.IsExplicitNonFiniteNumber = IsExplicitNonFiniteNumber
SyncCodec.FormatBytes = FormatBytes
SyncCodec.GetSyncTimestamp = GetSyncTimestamp
SyncCodec.NormalizeSyncSource = NormalizeSyncSource
SyncCodec.NormalizeSyncAddonVersion = NormalizeSyncAddonVersion
SyncCodec.IsPlainPeerName = IsPlainPeerName
SyncCodec.NormalizeSyncProtocolVersion = NormalizeSyncProtocolVersion
SyncCodec.SplitPayload = SplitPayload
SyncCodec.ParseKickPayload = ParseKickPayload
SyncCodec.EncodeKickSpellSuffix = EncodeKickSpellSuffix
SyncCodec.EncodeKickExtrasSuffix = EncodeKickExtrasSuffix
SyncCodec.NormalizeKeyPayload = NormalizeKeyPayload
SyncCodec.NormalizeStatsPayload = NormalizeStatsPayload
SyncCodec.NormalizeDpsPayload = NormalizeDpsPayload
SyncCodec.NormalizeRunKicksSuffix = NormalizeRunKicksSuffix
SyncCodec.NormalizeRunKicksMissedSuffix = NormalizeRunKicksMissedSuffix
SyncCodec.NormalizeLocPayload = NormalizeLocPayload
SyncCodec.NormalizeTargetPayload = NormalizeTargetPayload
SyncCodec.NormalizeLibKeystonePartyPayload = NormalizeLibKeystonePartyPayload
