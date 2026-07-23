local _, addonTable = ...

addonTable = addonTable or {}

local Sync = {}
addonTable.Sync = Sync
local SeasonData = addonTable.SeasonData or {}
local StringUtils = addonTable.StringUtils
local Unpack = rawget(_G, "unpack") or rawget(table, "unpack")

local ISILIVE_SYNC_PREFIX = "ISILIVE"
local LIBKEYSTONE_SYNC_PREFIX = "LibKS"
local LIBKEYSTONE_SOURCE = "libks"
local ISILIVE_SYNC_PROTOCOL_VERSION = 2
local ISILIVE_HELLO_COOLDOWN = 8
local ISILIVE_KEY_COOLDOWN = 5
local ISILIVE_STATS_COOLDOWN = 5
local ISILIVE_TARGET_COOLDOWN = 5
local ISILIVE_REFRESH_REQUEST_COOLDOWN = 1
local ISILIVE_SHAREKEYS_CD_COOLDOWN = 1
local ISILIVE_SHAREKEYS_CD_MAX_SECONDS = 30
local LIBKEYSTONE_REQUEST_COOLDOWN = 3
local MAX_SAFE_INTEGER = 9007199254740991

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

-- Architecture note: Module-level singleton state (intentional deviation from CreateController pattern).
--
-- Rationale: The addon runs exactly one Sync instance per session. Cooldown timestamps
-- (lastIsiLive*At) are addon-wide send rate-limiters. Payload dedup trackers (last*PayloadSent)
-- suppress identical re-sends within the same session. User/key/stats/dps/loc lookup tables
-- (isiLiveUsersByKey, *InfoByPlayerKey) hold received peer data that must survive across
-- controller re-creations during the same session.
--
-- Reset contract: ClearKnownUsers() resets ALL mutable state (cooldowns, dedup trackers,
-- and lookup tables) and is called by isiLive_controller_wiring.lua and isiLive_keysync.lua
-- on group disband. This ensures a clean slate when the player joins a new group.
local lastIsiLiveHelloAt = 0
local lastIsiLiveKeyAt = 0
local lastIsiLiveStatsAt = 0
local lastIsiLiveDpsAt = 0
local lastIsiLiveLocAt = 0
local lastIsiLiveTargetAt = 0
local lastIsiLiveKickAt = 0
local lastIsiLiveRefreshRequestAt = 0
local lastIsiLiveShareKeysCdAt = 0
local lastLibKeystoneRequestAt = 0
local lastKeyPayloadSent = nil
local lastStatsPayloadSent = nil
local lastDpsPayloadSent = nil
local lastLocPayloadSent = nil
local lastTargetPayloadSent = nil
local lastKickPayloadSent = nil
local isiLiveUsersByKey = {}
local helloInfoByPlayerKey = {}
local keyInfoByPlayerKey = {}
local statsInfoByPlayerKey = {}
local dpsInfoByPlayerKey = {}
local locInfoByPlayerKey = {}
local targetInfoByPlayerKey = {}
local kickInfoByPlayerKey = {}
local verifiedAliasByRosterKey = {}
local syncDebugLog = nil
local syncDebugTrace = nil
local syncDebugTraceDeep = nil

--- Sets the primary debug logger for sync events.
-- @param fn function|nil Receives a formatted string. Pass nil to disable.
function Sync.SetLogger(fn)
  syncDebugLog = type(fn) == "function" and fn or nil
end

--- Sets the trace logger for sync send/receive events.
-- @param fn function|nil Receives a lazy builder function; call it to materialise the string. Pass nil to disable.
function Sync.SetTraceLogger(fn)
  syncDebugTrace = type(fn) == "function" and fn or nil
end

--- Sets the deep-trace logger for high-frequency suppression events (e.g. cooldown blocks).
-- @param fn function|nil Same lazy-builder contract as SetTraceLogger. Pass nil to disable.
function Sync.SetDeepTraceLogger(fn)
  syncDebugTraceDeep = type(fn) == "function" and fn or nil
end

local function SyncLogInternal(traceFn, event, formatText, ...)
  if not traceFn and not syncDebugLog then
    return
  end
  local argCount = select("#", ...)
  if traceFn then
    local args = { ... }
    traceFn(function()
      local data = formatText
      if argCount > 0 then
        data = string.format(tostring(formatText or ""), Unpack(args))
      end
      return string.format("[SYNC] %s %s", event, data or "")
    end)
    return
  end
  local data = formatText
  if argCount > 0 then
    data = string.format(tostring(formatText or ""), ...)
  end
  if syncDebugLog then
    syncDebugLog(string.format("[SYNC] %s %s", event, data or ""))
  end
end

local function SyncLog(event, formatText, ...)
  SyncLogInternal(syncDebugTrace, event, formatText, ...)
end

local function SyncLogDeep(event, formatText, ...)
  SyncLogInternal(syncDebugTraceDeep, event, formatText, ...)
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
  for part in tostring(message or ""):gmatch("([^:]+)") do
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
  if not ((numericState == -1 or numericState == 0 or numericState == 1) and numericRemain and numericRemain >= 0) then
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
        if not sid or not rem or rem <= 0 then
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

-- The parser above is intentionally strict: every optional suffix segment
-- must be known and well-formed, otherwise the full KICK payload is dropped.
-- This preserves the no-guess contract for peer kick state.

local function IsSyncEnabled()
  local db = rawget(_G, "IsiLiveDB")
  return not db or db.syncEnabled ~= false
end

--- Normalizes a name/realm pair into a stable, case-insensitive lookup key.
-- Handles combined "Name-Realm" form and falls back to GetRealmName() when realm is empty.
-- Realm normalization strips spaces, dashes, dots, parens, and quotes.
-- @param name string Player name, or "Name-Realm" combined form.
-- @param realm string|nil Realm name; optional when name already contains "-Realm".
-- @return string Lowercase key of the form "name-realm".
-- @see StringUtils.NormalizeRealmName
-- Realm normalization is identical to NormalizeName() in isiLive_stats.lua:
-- both strip spaces, dashes, dots, parens, and quotes from the realm.
function Sync.NormalizePlayerKey(name, realm)
  local n = name and tostring(name) or ""
  local r = realm and tostring(realm) or ""

  if r == "" and string.find(n, "-", 1, true) then
    local dash = string.find(n, "-", 1, true)
    if dash then
      r = string.sub(n, dash + 1)
      n = string.sub(n, 1, dash - 1)
    end
  end

  if r == "" then
    local getRealmName = rawget(_G, "GetRealmName")
    r = type(getRealmName) == "function" and getRealmName() or ""
  end

  -- Strict normalization via shared StringUtils:
  -- Name: strip all whitespace; Realm: strip spaces/dashes/dots/parens/quotes
  local n_clean = StringUtils.StripWhitespace(tostring(n))
  local r_clean = StringUtils.NormalizeRealmName(tostring(r))
  local key = string.lower(n_clean .. "-" .. r_clean)
  return key
end

--- Returns the ISILIVE addon message prefix used for all sync payloads.
-- @return string
function Sync.GetPrefix()
  return ISILIVE_SYNC_PREFIX
end

--- Returns the current sync protocol version number (currently 2).
-- @return number
function Sync.GetProtocolVersion()
  return ISILIVE_SYNC_PROTOCOL_VERSION
end

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
  if not numericLevel or numericLevel <= 0 or not numericMapID or numericMapID <= 0 then
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

  if not numericIlvl or numericIlvl <= 0 then
    numericIlvl = -1
  else
    numericIlvl = math.floor(numericIlvl)
  end

  if numericRio == nil then
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
  if not numericDps or numericDps < 0 then
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

local function NormalizeLocPayload(mapID, capturedAt, source)
  local numericMapID = ToFiniteNumber(mapID)
  local normalizedCapturedAt, normalizedSource = NormalizeCapturedAtAndSource(capturedAt, source)
  if not numericMapID or numericMapID <= 0 then
    return string.format("LOC:0:%d:%s", normalizedCapturedAt, normalizedSource),
      nil,
      normalizedCapturedAt,
      normalizedSource
  end
  numericMapID = math.floor(numericMapID)
  return string.format("LOC:%d:%d:%s", numericMapID, normalizedCapturedAt, normalizedSource),
    numericMapID,
    normalizedCapturedAt,
    normalizedSource
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
  if not numericLevel or numericLevel <= 0 then
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

--- Records that a player has sent at least one sync message this session.
-- @param name string Player name.
-- @param realm string|nil Realm name.
function Sync.MarkUser(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  if key and key ~= "" then
    isiLiveUsersByKey[key] = true
  end
end

--- Returns whether a player is a known sync peer (has sent at least one message this session).
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return boolean
function Sync.IsUserKnown(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  local aliasKey = key and verifiedAliasByRosterKey[key] or nil
  return key and (isiLiveUsersByKey[key] == true or (aliasKey and isiLiveUsersByKey[aliasKey] == true)) or false
end

local function GetRealmKey(playerKey)
  if type(playerKey) ~= "string" then
    return nil
  end
  return playerKey:match("%-([^-]+)$")
end

local function ResolveLookupKey(store, name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  if type(store) == "table" and store[key] ~= nil then
    return key
  end
  local aliasKey = verifiedAliasByRosterKey[key]
  if type(aliasKey) == "string" and aliasKey ~= "" and type(store) == "table" and store[aliasKey] ~= nil then
    return aliasKey
  end
  return key
end

function Sync.RegisterVerifiedAlias(senderName, senderRealm, rosterName, rosterRealm)
  local senderKey = Sync.NormalizePlayerKey(senderName, senderRealm)
  local rosterKey = Sync.NormalizePlayerKey(rosterName, rosterRealm)
  if StringUtils.IsBlank(senderKey) or StringUtils.IsBlank(rosterKey) or senderKey == rosterKey then
    return false
  end
  if isiLiveUsersByKey[senderKey] ~= true then
    return false
  end
  if GetRealmKey(senderKey) ~= GetRealmKey(rosterKey) then
    return false
  end
  if verifiedAliasByRosterKey[rosterKey] == senderKey then
    return false
  end
  verifiedAliasByRosterKey[rosterKey] = senderKey
  SyncLogDeep("alias_registered", "sender=%s roster=%s", tostring(senderKey), tostring(rosterKey))
  return true
end

--- Returns whether the given WoW unit belongs to a known sync peer.
-- @param getUnitNameAndRealm function Callback returning (name, realm) for a unit token.
-- @param unit string WoW unit token (e.g. "party1").
-- @return boolean
function Sync.IsUnitKnown(getUnitNameAndRealm, unit)
  if type(getUnitNameAndRealm) ~= "function" then
    return false
  end
  local name, realm = getUnitNameAndRealm(unit)
  return Sync.IsUserKnown(name, realm)
end

--- Resets all session-wide sync state: known users, per-player caches, send cooldowns, and dedup trackers.
-- Called on group disband to ensure a clean slate for the next group.
-- @see isiLive_controller_wiring.lua, isiLive_keysync.lua
function Sync.ClearKnownUsers()
  isiLiveUsersByKey = {}
  helloInfoByPlayerKey = {}
  keyInfoByPlayerKey = {}
  statsInfoByPlayerKey = {}
  dpsInfoByPlayerKey = {}
  locInfoByPlayerKey = {}
  targetInfoByPlayerKey = {}
  kickInfoByPlayerKey = {}
  verifiedAliasByRosterKey = {}
  lastIsiLiveHelloAt = 0
  lastIsiLiveKeyAt = 0
  lastIsiLiveStatsAt = 0
  lastIsiLiveDpsAt = 0
  lastIsiLiveLocAt = 0
  lastIsiLiveTargetAt = 0
  lastIsiLiveKickAt = 0
  lastIsiLiveRefreshRequestAt = 0
  lastIsiLiveShareKeysCdAt = 0
  lastLibKeystoneRequestAt = 0
  lastKeyPayloadSent = nil
  lastStatsPayloadSent = nil
  lastDpsPayloadSent = nil
  lastLocPayloadSent = nil
  lastTargetPayloadSent = nil
  lastKickPayloadSent = nil
end

local function GetEntrySyncStamp(entry)
  if type(entry) ~= "table" then
    return nil
  end

  local capturedAt = ToFiniteNumber(entry.capturedAt)
  local receivedAt = ToFiniteNumber(entry.receivedAt)
  return capturedAt or receivedAt
end

local function SetEntryPreviousSyncStamp(entry, previousStamp)
  if type(entry) ~= "table" then
    return
  end

  previousStamp = ToFiniteNumber(previousStamp)
  local nextStamp = GetEntrySyncStamp(entry)
  if previousStamp and nextStamp and nextStamp >= previousStamp then
    entry.previousSyncStamp = previousStamp
  else
    entry.previousSyncStamp = nil
  end
end

--- Stores a received HELLO payload for a peer.
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param addonVersion string Peer's addon version string.
-- @param protocolVersion number|nil Peer's declared protocol version.
-- @param capturedAt number|nil Timestamp from the payload.
-- @param source string|nil Sync source label (e.g. "refresh", "local").
-- @return boolean true if this is the first HELLO from this peer; false if updated in-place.
function Sync.SetPlayerHelloInfo(name, realm, addonVersion, protocolVersion, capturedAt, source)
  local key = Sync.NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end

  local normalizedProtocolVersion = NormalizeSyncProtocolVersion(protocolVersion)
  local normalizedCapturedAt = ToFiniteNumber(capturedAt)
  if not normalizedCapturedAt or normalizedCapturedAt <= 0 then
    normalizedCapturedAt = GetSyncTimestamp() or 0
  end
  local normalizedSource = NormalizeSyncSource(source) or "local"
  local previous = helloInfoByPlayerKey[key]
  local previousStamp = GetEntrySyncStamp(previous)
  local nextValue = {
    addonVersion = type(addonVersion) == "string" and addonVersion or tostring(addonVersion or "?"),
    protocolVersion = normalizedProtocolVersion,
    capturedAt = math.floor(normalizedCapturedAt),
    source = normalizedSource,
    receivedAt = GetSyncTimestamp(),
  }
  SetEntryPreviousSyncStamp(nextValue, previousStamp)

  if previous then
    previous.addonVersion = nextValue.addonVersion
    previous.protocolVersion = nextValue.protocolVersion
    previous.capturedAt = nextValue.capturedAt
    previous.source = nextValue.source
    previous.receivedAt = nextValue.receivedAt
    SetEntryPreviousSyncStamp(previous, previousStamp)
    return false
  end

  helloInfoByPlayerKey[key] = nextValue
  return true
end

--- Stores a received ACK (version-only hello acknowledgement) for a peer.
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param addonVersion string Peer's addon version string.
-- @return boolean true if the stored version changed; false if unchanged or empty.
function Sync.SetPlayerHelloAckInfo(name, realm, addonVersion)
  local key = Sync.NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end

  local normalizedAddonVersion = type(addonVersion) == "string" and addonVersion or tostring(addonVersion or "")
  if normalizedAddonVersion == "" then
    return false
  end

  local previous = helloInfoByPlayerKey[key]
  local previousStamp = GetEntrySyncStamp(previous)

  if previous then
    local changed = previous.addonVersion ~= normalizedAddonVersion
    previous.addonVersion = normalizedAddonVersion
    previous.source = "ack"
    previous.receivedAt = GetSyncTimestamp()
    SetEntryPreviousSyncStamp(previous, previousStamp)
    return changed
  end

  local nextValue = {
    addonVersion = normalizedAddonVersion,
    protocolVersion = nil,
    capturedAt = nil,
    source = "ack",
    receivedAt = GetSyncTimestamp(),
  }
  SetEntryPreviousSyncStamp(nextValue, previousStamp)
  helloInfoByPlayerKey[key] = nextValue
  return true
end

--- Returns stored HELLO/ACK info for a peer, or nil if none received.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {addonVersion, protocolVersion, capturedAt, source, receivedAt, previousSyncStamp}
function Sync.GetPlayerHelloInfo(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  return helloInfoByPlayerKey[key]
end

--- Stores a received keystone payload for a peer. Clears the entry when mapID or level is invalid.
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param mapID number|nil Dungeon map ID; 0 or nil clears the entry.
-- @param level number|nil Key level; 0 or nil clears the entry.
-- @param capturedAt number|nil Timestamp from the payload.
-- @param source string|nil Sync source label.
-- @return boolean true if the stored key changed; false if deduplicated or cleared unchanged.
function Sync.SetPlayerKeyInfo(name, realm, mapID, level, capturedAt, source)
  local key = Sync.NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end

  local _, numericMapID, numericLevel, normalizedCapturedAt, normalizedSource =
    NormalizeKeyPayload(mapID, level, capturedAt, source)
  local previous = keyInfoByPlayerKey[key]
  local previousStamp = GetEntrySyncStamp(previous)
  if not numericMapID or not numericLevel then
    local hadValue = type(previous) == "table"
    keyInfoByPlayerKey[key] = nil
    return hadValue
  end

  if previous and previous.mapID == numericMapID and previous.level == numericLevel then
    previous.capturedAt = normalizedCapturedAt
    previous.source = normalizedSource
    previous.receivedAt = GetSyncTimestamp()
    SetEntryPreviousSyncStamp(previous, previousStamp)
    return false
  end

  local nextValue = {
    mapID = numericMapID,
    level = numericLevel,
    capturedAt = normalizedCapturedAt,
    source = normalizedSource,
    receivedAt = GetSyncTimestamp(),
  }
  SetEntryPreviousSyncStamp(nextValue, previousStamp)
  keyInfoByPlayerKey[key] = nextValue
  return true
end

--- Returns stored keystone info for a peer, or nil if none received.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {mapID, level, capturedAt, source, receivedAt, previousSyncStamp}
function Sync.GetPlayerKeyInfo(name, realm)
  local key = ResolveLookupKey(keyInfoByPlayerKey, name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  return keyInfoByPlayerKey[key]
end

--- Stores a received stats payload (spec/ilvl/rio) for a peer. Clears the entry when all fields are invalid.
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param specID number|nil Specialization ID (0 treated as missing).
-- @param ilvl number|nil Average item level (<=0 treated as missing).
-- @param rio number|nil Mythic+ rating (<0 treated as missing).
-- @param capturedAt number|nil Timestamp from the payload.
-- @param source string|nil Sync source label.
-- @return boolean true if stored stats changed; false if deduplicated or cleared unchanged.
function Sync.SetPlayerStatsInfo(name, realm, specID, ilvl, rio, capturedAt, source)
  local key = Sync.NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end

  local _, numericSpecID, numericIlvl, numericRio, normalizedCapturedAt, normalizedSource =
    NormalizeStatsPayload(specID, ilvl, rio, capturedAt, source)
  local previous = statsInfoByPlayerKey[key]
  local previousStamp = GetEntrySyncStamp(previous)
  local nextValue = {
    specID = numericSpecID > 0 and numericSpecID or nil,
    ilvl = numericIlvl > 0 and numericIlvl or nil,
    rio = numericRio >= 0 and numericRio or nil,
    capturedAt = normalizedCapturedAt,
    source = normalizedSource,
    receivedAt = GetSyncTimestamp(),
  }
  SetEntryPreviousSyncStamp(nextValue, previousStamp)

  if nextValue.specID == nil and nextValue.ilvl == nil and nextValue.rio == nil then
    local hadValue = type(statsInfoByPlayerKey[key]) == "table"
    statsInfoByPlayerKey[key] = nil
    return hadValue
  end

  if
    previous
    and previous.specID == nextValue.specID
    and previous.ilvl == nextValue.ilvl
    and previous.rio == nextValue.rio
  then
    previous.capturedAt = nextValue.capturedAt
    previous.source = nextValue.source
    previous.receivedAt = nextValue.receivedAt
    SetEntryPreviousSyncStamp(previous, previousStamp)
    return false
  end

  statsInfoByPlayerKey[key] = nextValue
  return true
end

--- Returns stored stats info for a peer, or nil if none received.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {specID, ilvl, rio, capturedAt, source, receivedAt, previousSyncStamp}
function Sync.GetPlayerStatsInfo(name, realm)
  local key = ResolveLookupKey(statsInfoByPlayerKey, name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  return statsInfoByPlayerKey[key]
end

--- Stores a received DPS payload for a peer. Clears the entry when dps <= 0.
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param dps number Damage per second (rounded to nearest integer).
-- @param capturedAt number|nil Timestamp from the payload.
-- @param source string|nil Sync source label.
-- @return boolean true if stored DPS changed; false if deduplicated or cleared unchanged.
function Sync.SetPlayerDpsInfo(name, realm, dps, capturedAt, source)
  local key = Sync.NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end

  local _, numericDps, normalizedCapturedAt, normalizedSource = NormalizeDpsPayload(dps, capturedAt, source)
  local previous = dpsInfoByPlayerKey[key]
  local previousStamp = GetEntrySyncStamp(previous)
  if not numericDps or numericDps <= 0 then
    local hadValue = type(dpsInfoByPlayerKey[key]) == "table"
    dpsInfoByPlayerKey[key] = nil
    return hadValue
  end

  if previous and previous.dps == numericDps then
    previous.capturedAt = normalizedCapturedAt
    previous.source = normalizedSource
    previous.receivedAt = GetSyncTimestamp()
    SetEntryPreviousSyncStamp(previous, previousStamp)
    return false
  end

  local nextValue = {
    dps = numericDps,
    capturedAt = normalizedCapturedAt,
    source = normalizedSource,
    receivedAt = GetSyncTimestamp(),
  }
  SetEntryPreviousSyncStamp(nextValue, previousStamp)
  dpsInfoByPlayerKey[key] = nextValue
  return true
end

--- Returns stored DPS info for a peer, or nil if none received.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {dps, capturedAt, source, receivedAt, previousSyncStamp}
function Sync.GetPlayerDpsInfo(name, realm)
  local key = ResolveLookupKey(dpsInfoByPlayerKey, name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  return dpsInfoByPlayerKey[key]
end

--- Stores a received kick/interrupt availability payload for a peer.
-- Rejected (returns false) when hasKick or onCooldown are not explicit booleans,
-- or when hasKick==true and cooldownRemain is nil or negative.
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param onCooldown boolean Whether the kick spell is currently on cooldown.
-- @param cooldownRemain number Remaining cooldown seconds; required when hasKick==true.
-- @param capturedAt number|nil Timestamp from the payload.
-- @param hasKick boolean Whether the player has a kick spell at all.
-- @param extras table|nil Extra kick cooldowns keyed by spellID.
-- @param spellID number|nil Primary kick spell ID when explicitly synced.
-- @return boolean true if stored kick state changed; false if unchanged or rejected.
function Sync.SetPlayerKickInfo(name, realm, onCooldown, cooldownRemain, capturedAt, hasKick, extras, spellID)
  local key = Sync.NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end
  if hasKick ~= true and hasKick ~= false then
    return false
  end
  if onCooldown ~= true and onCooldown ~= false then
    return false
  end
  local now = GetSyncTimestamp()
  local prev = kickInfoByPlayerKey[key]
  local newOnCooldown = onCooldown == true
  local newHasKick = hasKick == true
  local numericRemain = ToFiniteNumber(cooldownRemain)
  if newHasKick then
    if numericRemain == nil or numericRemain < 0 then
      return false
    end
  elseif newOnCooldown then
    return false
  end
  local prevRemain = ToFiniteNumber(prev and prev.cooldownRemain) or 0
  local remainChanged = newHasKick and newOnCooldown and math.abs(prevRemain - numericRemain) > 0.05
  local numericSpellID = newHasKick and ToFiniteNumber(spellID) or nil
  if numericSpellID then
    if numericSpellID <= 0 then
      return false
    end
    numericSpellID = math.floor(numericSpellID)
  end
  -- Extras: sanitize input map; only pass through {[spellID]={cooldownRemain}}
  -- entries with a positive remain. Caller may pass nil to clear.
  local sanitizedExtras = nil
  if type(extras) == "table" then
    for extraSpellID, data in pairs(extras) do
      local sid = ToFiniteNumber(extraSpellID)
      local r = type(data) == "table" and ToFiniteNumber(data.cooldownRemain) or nil
      if sid and r and r > 0 then
        sanitizedExtras = sanitizedExtras or {}
        sanitizedExtras[sid] = { cooldownRemain = r }
      end
    end
  end
  local extrasChanged = false
  local prevExtras = prev and prev.extras or nil
  if (prevExtras == nil) ~= (sanitizedExtras == nil) then
    extrasChanged = true
  elseif sanitizedExtras and prevExtras then
    -- Compare keys + remains; small drift (<0.6s) treated as unchanged.
    for sid, d in pairs(sanitizedExtras) do
      local pd = prevExtras[sid]
      if not pd or math.abs((pd.cooldownRemain or 0) - d.cooldownRemain) > 0.6 then
        extrasChanged = true
        break
      end
    end
    if not extrasChanged then
      for sid in pairs(prevExtras) do
        if not sanitizedExtras[sid] then
          extrasChanged = true
          break
        end
      end
    end
  end
  local changed = not prev
    or prev.onCooldown ~= newOnCooldown
    or prev.hasKick ~= newHasKick
    or prev.spellID ~= numericSpellID
    or remainChanged
    or extrasChanged
  local getTime = rawget(_G, "GetTime")
  kickInfoByPlayerKey[key] = {
    hasKick = newHasKick,
    spellID = numericSpellID,
    onCooldown = newOnCooldown,
    cooldownRemain = newHasKick and numericRemain or 0,
    extras = sanitizedExtras,
    capturedAt = ToFiniteNumber(capturedAt) or now,
    receivedAt = now,
    receivedAtGetTime = type(getTime) == "function" and getTime() or nil,
  }
  return changed
end

--- Returns stored kick info for a peer, or nil if none received.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {hasKick, onCooldown, cooldownRemain, capturedAt, receivedAt, receivedAtGetTime}
function Sync.GetPlayerKickInfo(name, realm)
  local key = ResolveLookupKey(kickInfoByPlayerKey, name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  return kickInfoByPlayerKey[key]
end

--- Clears stored kick info for a peer (e.g. when the player leaves the group).
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return boolean true if an entry existed and was removed.
function Sync.ClearPlayerKickInfo(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end
  local hadValue = type(kickInfoByPlayerKey[key]) == "table"
  kickInfoByPlayerKey[key] = nil
  return hadValue
end

--- Stores a received location (map) payload for a peer. Clears the entry when mapID is invalid.
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param mapID number|nil Current dungeon/zone map ID; nil or 0 clears the entry.
-- @param capturedAt number|nil Timestamp from the payload.
-- @param source string|nil Sync source label.
-- @return boolean true if stored location changed; false if deduplicated or cleared unchanged.
function Sync.SetPlayerLocInfo(name, realm, mapID, capturedAt, source)
  local key = Sync.NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end

  local _, numericMapID, normalizedCapturedAt, normalizedSource = NormalizeLocPayload(mapID, capturedAt, source)
  local previous = locInfoByPlayerKey[key]
  local previousStamp = GetEntrySyncStamp(previous)
  if not numericMapID then
    local hadValue = type(locInfoByPlayerKey[key]) == "table"
    locInfoByPlayerKey[key] = nil
    return hadValue
  end

  if previous and previous.mapID == numericMapID then
    previous.capturedAt = normalizedCapturedAt
    previous.source = normalizedSource
    previous.receivedAt = GetSyncTimestamp()
    SetEntryPreviousSyncStamp(previous, previousStamp)
    return false
  end

  local nextValue = {
    mapID = numericMapID,
    capturedAt = normalizedCapturedAt,
    source = normalizedSource,
    receivedAt = GetSyncTimestamp(),
  }
  SetEntryPreviousSyncStamp(nextValue, previousStamp)
  locInfoByPlayerKey[key] = nextValue
  return true
end

--- Returns stored location info for a peer, or nil if none received.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {mapID, capturedAt, source, receivedAt, previousSyncStamp}
function Sync.GetPlayerLocInfo(name, realm)
  local key = ResolveLookupKey(locInfoByPlayerKey, name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  return locInfoByPlayerKey[key]
end

--- Stores a received target-keystone payload for a peer. Clears the entry when mapID is invalid.
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param mapID number|nil Target dungeon map ID; nil or 0 clears the entry.
-- @param level number|nil Target key level (nil when unknown).
-- @param capturedAt number|nil Timestamp from the payload.
-- @param source string|nil Sync source label.
-- @param levelText string|nil Verified opaque Blizzard keystone level markup.
-- @return boolean true if stored target changed; false if deduplicated or cleared unchanged.
function Sync.SetPlayerTargetInfo(name, realm, mapID, level, capturedAt, source, levelText)
  local key = Sync.NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end

  local _, numericMapID, numericLevel, normalizedCapturedAt, normalizedSource, normalizedLevelText =
    NormalizeTargetPayload(mapID, level, capturedAt, source, levelText)
  local previous = targetInfoByPlayerKey[key]
  local previousStamp = GetEntrySyncStamp(previous)
  if not numericMapID then
    local hadValue = type(targetInfoByPlayerKey[key]) == "table"
    targetInfoByPlayerKey[key] = nil
    return hadValue
  end

  if
    previous
    and previous.mapID == numericMapID
    and previous.level == numericLevel
    and previous.levelText == normalizedLevelText
  then
    previous.capturedAt = normalizedCapturedAt
    previous.source = normalizedSource
    previous.receivedAt = GetSyncTimestamp()
    SetEntryPreviousSyncStamp(previous, previousStamp)
    return false
  end

  local nextValue = {
    mapID = numericMapID,
    level = numericLevel,
    levelText = normalizedLevelText,
    capturedAt = normalizedCapturedAt,
    source = normalizedSource,
    receivedAt = GetSyncTimestamp(),
  }
  SetEntryPreviousSyncStamp(nextValue, previousStamp)
  targetInfoByPlayerKey[key] = nextValue
  return true
end

--- Returns stored target info for a peer, or nil if none received.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {mapID, level, levelText, capturedAt, source, receivedAt, previousSyncStamp}
function Sync.GetPlayerTargetInfo(name, realm)
  local key = ResolveLookupKey(targetInfoByPlayerKey, name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  return targetInfoByPlayerKey[key]
end

--- Returns a summary of the most recently received sync bucket for a peer.
-- Picks the bucket with the highest capturedAt/receivedAt timestamp across all data types.
-- Used to compute approximate sync intervals for tooltip display.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {kind, capturedAt, receivedAt, previousSyncStamp,
--   intervalSeconds, source, addonVersion, protocolVersion}
function Sync.GetPlayerSyncSummary(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  local aliasKey = verifiedAliasByRosterKey[key]

  local candidates = {
    { kind = "hello", data = helloInfoByPlayerKey[key] or (aliasKey and helloInfoByPlayerKey[aliasKey]) },
    { kind = "key", data = keyInfoByPlayerKey[key] or (aliasKey and keyInfoByPlayerKey[aliasKey]) },
    { kind = "stats", data = statsInfoByPlayerKey[key] or (aliasKey and statsInfoByPlayerKey[aliasKey]) },
    { kind = "dps", data = dpsInfoByPlayerKey[key] or (aliasKey and dpsInfoByPlayerKey[aliasKey]) },
    { kind = "loc", data = locInfoByPlayerKey[key] or (aliasKey and locInfoByPlayerKey[aliasKey]) },
    { kind = "target", data = targetInfoByPlayerKey[key] or (aliasKey and targetInfoByPlayerKey[aliasKey]) },
  }

  local best = nil
  for _, candidate in ipairs(candidates) do
    local data = candidate.data
    if type(data) == "table" then
      local capturedAt = ToFiniteNumber(data.capturedAt)
      local receivedAt = ToFiniteNumber(data.receivedAt)
      local previousSyncStamp = ToFiniteNumber(data.previousSyncStamp)
      local sortStamp = capturedAt or receivedAt
      if sortStamp then
        local summary = {
          kind = candidate.kind,
          capturedAt = capturedAt,
          receivedAt = receivedAt,
          previousSyncStamp = previousSyncStamp,
          intervalSeconds = previousSyncStamp and sortStamp >= previousSyncStamp and (sortStamp - previousSyncStamp)
            or nil,
          source = data.source,
          addonVersion = data.addonVersion,
          protocolVersion = data.protocolVersion,
          sortStamp = sortStamp,
        }
        if not best or summary.sortStamp > best.sortStamp then
          best = summary
        end
      end
    end
  end

  if best then
    best.sortStamp = nil
  end

  return best
end

local function SafeBooleanCall(fn, ...)
  local ok, result = pcall(fn, ...)
  return ok and not addonTable.Validators.IsSecretValue(result) and result == true
end

local function IsVerifiedInstanceGroup()
  local isInGroup = rawget(_G, "IsInGroup")
  local instanceCategory = rawget(_G, "LE_PARTY_CATEGORY_INSTANCE")
  if type(isInGroup) ~= "function" or instanceCategory == nil then
    return false
  end
  return SafeBooleanCall(isInGroup, instanceCategory)
end

local function IsVerifiedHomeParty()
  local isInGroup = rawget(_G, "IsInGroup")
  local homeCategory = rawget(_G, "LE_PARTY_CATEGORY_HOME")
  if homeCategory ~= nil and type(isInGroup) == "function" and SafeBooleanCall(isInGroup, homeCategory) then
    return true
  end

  local unitInParty = rawget(_G, "UnitInParty")
  if type(unitInParty) == "function" then
    return SafeBooleanCall(unitInParty, "player")
  end

  return type(isInGroup) == "function" and SafeBooleanCall(isInGroup)
end

local function IsVerifiedRaid()
  local isInRaid = rawget(_G, "IsInRaid")
  return type(isInRaid) == "function" and SafeBooleanCall(isInRaid)
end

--- Returns the current group addon sync channel, or nil when not in a group or raid.
-- Priority: raid hard-off, then INSTANCE_CHAT > verified home PARTY.
-- @return string|nil "INSTANCE_CHAT", "PARTY", or nil.
function Sync.GetAddonSyncChannel()
  if IsVerifiedRaid() then
    return nil
  end
  if IsVerifiedInstanceGroup() then
    return "INSTANCE_CHAT"
  end
  if IsVerifiedHomeParty() then
    return "PARTY"
  end
  return nil
end

--- Registers ISILIVE and LibKS addon message prefixes with C_ChatInfo.
-- Must be called once (on PLAYER_LOGIN) before addon messages can be received.
function Sync.RegisterPrefix()
  local chatInfo = rawget(_G, "C_ChatInfo")
  if type(chatInfo) == "table" and type(chatInfo.RegisterAddonMessagePrefix) == "function" then
    pcall(chatInfo.RegisterAddonMessagePrefix, ISILIVE_SYNC_PREFIX)
    pcall(chatInfo.RegisterAddonMessagePrefix, LIBKEYSTONE_SYNC_PREFIX)
  end
end

-- Common pre-send guard shared by Send* functions: API availability, sync-enabled,
-- caller visibility, and channel resolution. Returns the outgoing channel string,
-- or nil when the send should be suppressed.
local function ResolveSendChannel(opts)
  local chatInfo = rawget(_G, "C_ChatInfo")
  if type(chatInfo) ~= "table" or type(chatInfo.SendAddonMessage) ~= "function" then
    return nil
  end
  if not IsSyncEnabled() then
    return nil
  end
  if opts.isVisible == false and opts.allowHidden ~= true then
    return nil
  end
  return Sync.GetAddonSyncChannel()
end

-- Routes an addon message through ChatThrottleLib when the embedded lib is
-- present (priority-queued, fair-shared with other addons). Falls back to
-- raw C_ChatInfo.SendAddonMessage if the lib is unavailable. Returns true
-- if the message was accepted for dispatch (either enqueued by CTL or
-- handed to Blizzard), false if it was rejected outright.
local function DispatchAddonMessage(prefix, payload, channel, priority)
  local ctl = rawget(_G, "ChatThrottleLib")
  if ctl and type(ctl.SendAddonMessage) == "function" then
    local ok = pcall(ctl.SendAddonMessage, ctl, priority or "NORMAL", prefix, payload, channel)
    return ok
  end
  local chatInfo = rawget(_G, "C_ChatInfo")
  if type(chatInfo) == "table" and type(chatInfo.SendAddonMessage) == "function" then
    local ok, result = pcall(chatInfo.SendAddonMessage, prefix, payload, channel)
    return ok and result ~= false
  end
  return false
end

-- Shared dedupe/cooldown gate for Send* functions that share the pattern
-- "skip if identical payload and still in cooldown window".
-- Returns (blocked:boolean, now:number). onBlocked, if provided, is called with
-- ("unchanged") or ("cooldown", remainSeconds) for deep-trace logging.
local function IsBlockedBySendGate(opts, lastPayload, lastAt, dedupePayload, cooldown, onBlocked)
  local getTimeFn = rawget(_G, "GetTime")
  local now = type(getTimeFn) == "function" and getTimeFn() or 0
  if opts.force then
    return false, now
  end
  if opts.onlyIfChanged == true and dedupePayload == lastPayload then
    if onBlocked then
      onBlocked("unchanged", 0)
    end
    return true, now
  end
  if dedupePayload == lastPayload and (now - lastAt) < cooldown then
    if onBlocked then
      onBlocked("cooldown", cooldown - (now - lastAt))
    end
    return true, now
  end
  return false, now
end

--- Broadcasts a HELLO announcement to the group.
-- Rate-limited by ISILIVE_HELLO_COOLDOWN (8 s). Suppressed when isVisible==false unless allowHidden==true.
-- @param opts table {version:string, protocolVersion:number, source:string,
--   isVisible:boolean, allowHidden:boolean, force:boolean}
function Sync.SendHello(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end

  local getTimeFn = rawget(_G, "GetTime")
  local now = type(getTimeFn) == "function" and getTimeFn() or 0
  if not opts.force and (now - lastIsiLiveHelloAt) < ISILIVE_HELLO_COOLDOWN then
    return
  end

  local payload = string.format(
    "HELLO:%s:%d:%d:%s",
    tostring(opts.version or "?"),
    NormalizeSyncProtocolVersion(opts.protocolVersion),
    GetSyncTimestamp() or 0,
    NormalizeSyncSource(opts.source) or "local"
  )
  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "NORMAL")
  if sent == true then
    lastIsiLiveHelloAt = now
  end
  SyncLog(
    "send_hello",
    "version=%s channel=%s source=%s sent=%s",
    tostring(opts.version or "?"),
    tostring(channel),
    tostring(opts.source or "local"),
    tostring(sent)
  )
end

--- Broadcasts the local player's keystone to the group.
-- Deduplicated (onlyIfChanged) and rate-limited by ISILIVE_KEY_COOLDOWN (5 s).
-- @param opts table {mapID:number, level:number, capturedAt:number, source:string,
--   isVisible:boolean, allowHidden:boolean, force:boolean, onlyIfChanged:boolean}
function Sync.SendKey(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end

  local payload, numericMapID, numericLevel = NormalizeKeyPayload(opts.mapID, opts.level, opts.capturedAt, opts.source)
  local dedupePayload = string.format("KEY:%d:%d", tonumber(numericMapID) or 0, tonumber(numericLevel) or 0)
  local blocked, now = IsBlockedBySendGate(
    opts,
    lastKeyPayloadSent,
    lastIsiLiveKeyAt,
    dedupePayload,
    ISILIVE_KEY_COOLDOWN,
    function(reason, remain)
      if reason == "unchanged" then
        SyncLogDeep(
          "send_key_blocked",
          "reason=unchanged mapID=%s level=%s",
          tostring(numericMapID),
          tostring(numericLevel)
        )
      else
        SyncLogDeep(
          "send_key_blocked",
          "reason=cooldown mapID=%s level=%s remain=%.1f",
          tostring(numericMapID),
          tostring(numericLevel),
          remain
        )
      end
    end
  )
  if blocked then
    return
  end

  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "NORMAL")
  if sent == true then
    lastIsiLiveKeyAt = now
    lastKeyPayloadSent = dedupePayload
  end
  SyncLog(
    "send_key",
    "mapID=%s level=%s channel=%s sent=%s",
    tostring(numericMapID),
    tostring(numericLevel),
    tostring(channel),
    tostring(sent)
  )
end

--- Broadcasts the local player's stats (spec/ilvl/rio) to the group.
-- Deduplicated and rate-limited by ISILIVE_STATS_COOLDOWN (5 s).
-- @param opts table {specID:number, ilvl:number, rio:number, capturedAt:number,
--   source:string, isVisible:boolean, allowHidden:boolean, force:boolean, onlyIfChanged:boolean}
function Sync.SendStats(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end

  local payload, numericSpecID, numericIlvl, numericRio =
    NormalizeStatsPayload(opts.specID, opts.ilvl, opts.rio, opts.capturedAt, opts.source)
  local dedupePayload =
    string.format("STATS:%d:%d:%d", tonumber(numericSpecID) or 0, tonumber(numericIlvl) or 0, tonumber(numericRio) or 0)
  local blocked, now =
    IsBlockedBySendGate(opts, lastStatsPayloadSent, lastIsiLiveStatsAt, dedupePayload, ISILIVE_STATS_COOLDOWN, nil)
  if blocked then
    return
  end

  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "BULK")
  if sent == true then
    lastIsiLiveStatsAt = now
    lastStatsPayloadSent = dedupePayload
  end
  SyncLog(
    "send_stats",
    "specID=%s ilvl=%s rio=%s channel=%s sent=%s",
    tostring(numericSpecID),
    tostring(numericIlvl),
    tostring(numericRio),
    tostring(channel),
    tostring(sent)
  )
end

--- Broadcasts the local player's last-run DPS to the group.
-- Deduplicated and rate-limited by ISILIVE_STATS_COOLDOWN (5 s).
-- @param opts table {dps:number, capturedAt:number, source:string,
--   isVisible:boolean, allowHidden:boolean, force:boolean, onlyIfChanged:boolean}
function Sync.SendDps(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end

  local payload, numericDps = NormalizeDpsPayload(opts.dps, opts.capturedAt, opts.source)
  local dedupePayload = string.format("DPS:%d", tonumber(numericDps) or 0)
  local blocked, now =
    IsBlockedBySendGate(opts, lastDpsPayloadSent, lastIsiLiveDpsAt, dedupePayload, ISILIVE_STATS_COOLDOWN, nil)
  if blocked then
    return
  end

  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "BULK")
  if sent == true then
    lastIsiLiveDpsAt = now
    lastDpsPayloadSent = dedupePayload
  end
  SyncLog("send_dps", "dps=%s channel=%s sent=%s", tostring(numericDps), tostring(channel), tostring(sent))
end

--- Broadcasts the local player's kick/interrupt availability to the group.
-- Rate-limited to 1 s; deduplicated by payload string.
-- @param opts table {hasKick:boolean, onCooldown:boolean, cooldownRemain:number, spellID:number|nil, force:boolean}
function Sync.SendKick(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end

  local hasKick = opts.hasKick
  if hasKick ~= true and hasKick ~= false then
    return
  end
  local onCooldown = opts.onCooldown
  if onCooldown ~= true and onCooldown ~= false then
    return
  end
  local cooldownRemain = ToFiniteNumber(opts.cooldownRemain)
  if hasKick == true then
    if cooldownRemain == nil or cooldownRemain < 0 then
      return
    end
  elseif onCooldown == true then
    return
  end
  local encodedHasKick = hasKick == true
  local encodedOnCooldown = encodedHasKick and (onCooldown == true and 1 or 0) or -1
  local remain = 0
  if encodedHasKick and cooldownRemain then
    remain = math.ceil(cooldownRemain)
  end
  local extrasSuffix = EncodeKickExtrasSuffix(opts.extras)
  local spellSuffix = EncodeKickSpellSuffix(opts.spellID, encodedHasKick)
  local payload = string.format("KICK:%d:%d%s%s", encodedOnCooldown, remain, extrasSuffix, spellSuffix)
  local blocked, now = IsBlockedBySendGate(opts, lastKickPayloadSent, lastIsiLiveKickAt, payload, 1, nil)
  if blocked then
    return false
  end
  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "ALERT")
  if sent == true then
    lastIsiLiveKickAt = now
    lastKickPayloadSent = payload
  end
  SyncLog(
    "send_kick",
    "hasKick=%s onCooldown=%s remain=%s channel=%s sent=%s",
    tostring(hasKick),
    tostring(onCooldown),
    tostring(remain),
    tostring(channel),
    tostring(sent)
  )
  return sent == true
end

--- Broadcasts the local player's current dungeon/zone map ID to the group.
-- Deduplicated and rate-limited by ISILIVE_STATS_COOLDOWN (5 s).
-- @param opts table {mapID:number, capturedAt:number, source:string,
--   isVisible:boolean, allowHidden:boolean, force:boolean, onlyIfChanged:boolean}
function Sync.SendLoc(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end

  local payload, numericMapID = NormalizeLocPayload(opts.mapID, opts.capturedAt, opts.source)
  local dedupePayload = string.format("LOC:%d", tonumber(numericMapID) or 0)
  local blocked, now =
    IsBlockedBySendGate(opts, lastLocPayloadSent, lastIsiLiveLocAt, dedupePayload, ISILIVE_STATS_COOLDOWN, nil)
  if blocked then
    return
  end

  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "BULK")
  if sent == true then
    lastIsiLiveLocAt = now
    lastLocPayloadSent = dedupePayload
  end
  SyncLog("send_loc", "mapID=%s channel=%s sent=%s", tostring(numericMapID), tostring(channel), tostring(sent))
end

--- Broadcasts the local player's target keystone (desired dungeon/level) to the group.
-- Deduplicated and rate-limited by ISILIVE_TARGET_COOLDOWN (5 s).
-- @param opts table {mapID:number, level:number, levelText:string, capturedAt:number, source:string,
--   isVisible:boolean, allowHidden:boolean, force:boolean}
function Sync.SendTarget(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end

  local payload, numericMapID, numericLevel, _, _, normalizedLevelText =
    NormalizeTargetPayload(opts.mapID, opts.level, opts.capturedAt, opts.source, opts.levelText)
  local dedupePayload = string.format(
    "TARGET:%d:%d:%s",
    tonumber(numericMapID) or 0,
    tonumber(numericLevel) or 0,
    normalizedLevelText or ""
  )
  local blocked, now =
    IsBlockedBySendGate(opts, lastTargetPayloadSent, lastIsiLiveTargetAt, dedupePayload, ISILIVE_TARGET_COOLDOWN, nil)
  if blocked then
    return
  end

  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "NORMAL")
  if sent == true then
    lastIsiLiveTargetAt = now
    lastTargetPayloadSent = dedupePayload
  end
  SyncLog(
    "send_target",
    "mapID=%s level=%s levelText=%s channel=%s sent=%s",
    tostring(numericMapID),
    tostring(numericLevel),
    tostring(normalizedLevelText),
    tostring(channel),
    tostring(sent)
  )
end

--- Broadcasts a BR / Bloodlust combat announcement to all isiLive peers.
-- Sender-side dedup is handled upstream by combat_events.HandleUnitSpellcastSucceeded
-- (per source+spellID, 3 s window), so this function does not gate again. Suppressed
-- when no group channel is available; isVisible / allowHidden semantics follow
-- ResolveSendChannel.
-- @param opts table {kind:"BR"|"LUST", caster:string, spellID:number,
--   isVisible:boolean, allowHidden:boolean}
function Sync.SendCombatAnnounce(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end
  local kind = tostring(opts.kind or "")
  if kind ~= "BR" and kind ~= "LUST" then
    return
  end
  local caster = tostring(opts.caster or "")
  if caster == "" or string.find(caster, ":", 1, true) then
    return
  end
  local spellID = ToFiniteNumber(opts.spellID) or 0
  local payload = string.format("BRLUST:%s:%s:%d", kind, caster, spellID)
  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "NORMAL")
  SyncLog(
    "send_combat_announce",
    "kind=%s caster=%s spellID=%d channel=%s sent=%s",
    kind,
    caster,
    spellID,
    tostring(channel),
    tostring(sent)
  )
end

--- Broadcasts a verified Power Infusion announcement to all isiLive peers.
-- Sender-side verification is owned by PiTracker: this function only transports
-- already resolved caster/recipient names and does not infer missing data.
-- @param opts table {caster:string, recipient:string, spellID:number,
--   isVisible:boolean, allowHidden:boolean}
function Sync.SendPowerInfusionAnnounce(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end
  local caster = tostring(opts.caster or "")
  local recipient = tostring(opts.recipient or "")
  if caster == "" or recipient == "" or string.find(caster, ":", 1, true) or string.find(recipient, ":", 1, true) then
    return
  end
  local spellID = ToFiniteNumber(opts.spellID) or 10060
  if spellID ~= 10060 then
    return
  end
  local payload = string.format("PI:%s:%s:%d", caster, recipient, spellID)
  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "NORMAL")
  SyncLog(
    "send_power_infusion",
    "caster=%s recipient=%s spellID=%d channel=%s sent=%s",
    caster,
    recipient,
    spellID,
    tostring(channel),
    tostring(sent)
  )
end

--- Broadcasts a REQSYNC request, asking all peers to re-send their current sync snapshot.
-- Rate-limited by ISILIVE_REFRESH_REQUEST_COOLDOWN (1 s).
-- @param opts table|nil {force:boolean}
function Sync.SendRefreshRequest(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end

  local getTimeFn = rawget(_G, "GetTime")
  local now = type(getTimeFn) == "function" and getTimeFn() or 0
  if not opts.force and (now - lastIsiLiveRefreshRequestAt) < ISILIVE_REFRESH_REQUEST_COOLDOWN then
    return
  end

  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, "REQSYNC", channel, "ALERT")
  if sent == true then
    lastIsiLiveRefreshRequestAt = now
  end
  SyncLog("send_reqsync", "channel=%s sent=%s", tostring(channel), tostring(sent))
end

--- Sends a LibKeystone "R" request to the party asking peers to reply with their key data.
-- Only sent in party (not raid). Rate-limited by LIBKEYSTONE_REQUEST_COOLDOWN (3 s).
-- @param opts table|nil {force:boolean}
-- @return boolean true if the message was sent; false if suppressed.
function Sync.SendLibKeystoneRequest(opts)
  local chatInfo = rawget(_G, "C_ChatInfo")
  if type(chatInfo) ~= "table" or type(chatInfo.SendAddonMessage) ~= "function" then
    return false
  end
  if not IsSyncEnabled() then
    return false
  end
  opts = opts or {}

  local libKsChannel = Sync.GetAddonSyncChannel()
  if not libKsChannel then
    return false
  end

  local getTimeFn = rawget(_G, "GetTime")
  local now = type(getTimeFn) == "function" and getTimeFn() or 0
  if not opts.force and (now - lastLibKeystoneRequestAt) < LIBKEYSTONE_REQUEST_COOLDOWN then
    return false
  end

  local sent = DispatchAddonMessage(LIBKEYSTONE_SYNC_PREFIX, "R", libKsChannel, "NORMAL")
  if sent == true then
    lastLibKeystoneRequestAt = now
  end
  SyncLog("send_libkeystone_request", "channel=%s sent=%s", tostring(libKsChannel), tostring(sent))
  return sent == true
end

--- Sends the local player's keystone and rio to party in LibKeystone format ("level,mapID,rio").
-- Only sent in party (not raid). No cooldown — caller is responsible for throttling.
-- @param opts table {mapID:number, level:number, rio:number}
-- @return boolean true if the message was sent; false if suppressed.
function Sync.SendLibKeystonePartyData(opts)
  local chatInfo = rawget(_G, "C_ChatInfo")
  if type(chatInfo) ~= "table" or type(chatInfo.SendAddonMessage) ~= "function" then
    return false
  end
  if not IsSyncEnabled() then
    return false
  end
  opts = opts or {}

  local libKsChannel = Sync.GetAddonSyncChannel()
  if not libKsChannel then
    return false
  end

  local numericLevel = ToFiniteNumber(opts.level)
  local numericMapID = ToFiniteNumber(opts.mapID)
  if type(SeasonData.NormalizeMapID) == "function" then
    numericMapID = SeasonData.NormalizeMapID(numericMapID)
  end

  if not numericLevel or numericLevel <= 0 or not numericMapID or numericMapID <= 0 then
    numericLevel = 0
    numericMapID = 0
  else
    numericLevel = math.floor(numericLevel)
    numericMapID = math.floor(numericMapID)
  end

  local numericRio = ToFiniteNumber(opts.rio)
  if numericRio == nil or numericRio < 0 then
    numericRio = 0
  else
    numericRio = math.floor(numericRio)
  end

  local payload = string.format("%d,%d,%d", numericLevel, numericMapID, numericRio)
  local sent = DispatchAddonMessage(LIBKEYSTONE_SYNC_PREFIX, payload, libKsChannel, "NORMAL")
  SyncLog(
    "send_libkeystone_party",
    "channel=%s level=%s mapID=%s rio=%s sent=%s",
    tostring(libKsChannel),
    tostring(numericLevel),
    tostring(numericMapID),
    tostring(numericRio),
    tostring(sent)
  )
  return sent == true
end

--- Broadcasts a SHAREKEYS request, asking all peers to announce their keystones in group chat.
-- No cooldown on the request itself; receivers handle their own rate-limiting.
-- @return boolean true if the message was sent; false when not in a group.
function Sync.SendShareKeysRequest()
  local channel = ResolveSendChannel({})
  if not channel then
    return false
  end
  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, "SHAREKEYS", channel, "ALERT")
  SyncLog("send_sharekeys", "channel=%s sent=%s", tostring(channel), tostring(sent))
  return sent == true
end

--- Broadcasts the remaining share-keys button cooldown to the group.
-- Sent as part of the hello-ack / REQSYNC state fan-out so a freshly joined
-- peer mirrors the lock instead of immediately re-triggering a SHAREKEYS wave.
-- Rate-limited by ISILIVE_SHAREKEYS_CD_COOLDOWN (1 s); remain is clamped to
-- 1..ISILIVE_SHAREKEYS_CD_MAX_SECONDS (30 s, the button debounce window).
-- @param opts table {remain:number, force:boolean}
-- @return boolean true if the message was sent; false if suppressed or invalid.
function Sync.SendShareKeysCooldown(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return false
  end

  local remain = ToFiniteNumber(opts.remain)
  if not remain or remain <= 0 then
    return false
  end
  remain = math.ceil(remain)
  if remain > ISILIVE_SHAREKEYS_CD_MAX_SECONDS then
    remain = ISILIVE_SHAREKEYS_CD_MAX_SECONDS
  end

  local getTimeFn = rawget(_G, "GetTime")
  local now = type(getTimeFn) == "function" and getTimeFn() or 0
  if not opts.force and (now - lastIsiLiveShareKeysCdAt) < ISILIVE_SHAREKEYS_CD_COOLDOWN then
    return false
  end

  local payload = string.format("SKCD:%d", remain)
  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "NORMAL")
  if sent == true then
    lastIsiLiveShareKeysCdAt = now
  end
  SyncLog("send_sharekeys_cd", "remain=%d channel=%s sent=%s", remain, tostring(channel), tostring(sent))
  return sent == true
end

local MAX_ADDON_MESSAGE_LENGTH = 255

local function IsIsiLiveReceiveChannelAllowed(message, channel)
  if channel == nil or channel == "PARTY" or channel == "INSTANCE_CHAT" then
    return true
  end
  return channel == "WHISPER" and type(message) == "string" and message:find("^ACK:") ~= nil
end

local function ProcessLibKeystoneMessage(message, sender, localName, localRealm, channel)
  if type(sender) ~= "string" or sender == "" then
    return nil
  end
  if type(message) ~= "string" or #message == 0 or #message > MAX_ADDON_MESSAGE_LENGTH then
    return nil
  end
  -- LibKeystone is party-only protocol, but inside an instance the WoW server
  -- delivers party addon messages on the INSTANCE_CHAT channel. Accept both
  -- so peers running RaiderIO (or any other LibKeystone-using addon) reach us
  -- inside M+ keys, dungeons, and scenarios.
  if channel ~= nil and channel ~= "PARTY" and channel ~= "INSTANCE_CHAT" then
    return nil
  end

  local senderKey = Sync.NormalizePlayerKey(sender)
  local selfKey = Sync.NormalizePlayerKey(localName, localRealm)
  if type(message) == "string" and message == "R" then
    SyncLog("libkeystone_request", "sender=%s shouldReply=%s", tostring(sender), tostring(senderKey ~= selfKey))
    return {
      sender = sender,
      shouldReplyLibKeystone = senderKey ~= selfKey,
    }
  end

  local levelRaw, mapIDRaw, ratingRaw = nil, nil, nil
  if type(message) == "string" then
    levelRaw, mapIDRaw, ratingRaw = string.match(message, "^(%d+),(%d+),(%d+)$")
  end
  if not levelRaw or not mapIDRaw or not ratingRaw then
    return nil
  end

  local keyLevel = ToFiniteNumber(levelRaw)
  local keyMapID = ToFiniteNumber(mapIDRaw)
  local playerRating = ToFiniteNumber(ratingRaw)
  if playerRating == nil or playerRating < 0 then
    return nil
  end

  SyncLog(
    "libkeystone_received",
    "sender=%s mapID=%s level=%s rio=%s",
    tostring(sender),
    tostring(keyMapID),
    tostring(keyLevel),
    tostring(playerRating)
  )
  local keyUpdated = Sync.SetPlayerKeyInfo(sender, nil, keyMapID, keyLevel, nil, LIBKEYSTONE_SOURCE)
  local previousStats = Sync.GetPlayerStatsInfo(sender, nil)
  local statsUpdated = Sync.SetPlayerStatsInfo(
    sender,
    nil,
    previousStats and previousStats.specID or nil,
    previousStats and previousStats.ilvl or nil,
    playerRating,
    nil,
    LIBKEYSTONE_SOURCE
  )

  return {
    sender = sender,
    keyUpdated = keyUpdated and true or false,
    statsUpdated = statsUpdated and true or false,
    shouldReplyLibKeystone = false,
  }
end

--- Processes an incoming addon message and updates peer sync state accordingly.
-- Routes ISILIVE payloads (KEY, STATS, DPS, LOC, TARGET, KICK, HELLO, ACK, REQSYNC, SHAREKEYS, SKCD)
-- and LibKS payloads to their respective handlers. Silently drops messages that fail
-- prefix, sender, or length validation.
-- @param prefix string Addon message prefix ("ISILIVE" or "LibKS").
-- @param message string Raw payload (max 255 bytes; empty or oversized are dropped).
-- @param sender string Sender's "Name-Realm" string (must be non-empty).
-- @param localName string Local player name (used to detect self-messages).
-- @param localRealm string|nil Local player realm.
-- @param channel string|nil Arrival channel (LibKS accepts PARTY + INSTANCE_CHAT).
-- @return table|nil Result with fields: shouldAck, shouldRequestRefresh, shouldShareKeys, sender,
--   peerAddonVersion, peerProtocolVersion, peerCapturedAt, peerSource,
--   keyUpdated, statsUpdated, dpsUpdated, locUpdated, targetUpdated, kickUpdated,
--   shareKeysCooldownRemain (number|nil, mirrored share-keys lock from a peer).
--   Returns nil when the message is rejected or the prefix is unrecognized.
function Sync.ProcessAddonMessage(prefix, message, sender, localName, localRealm, channel)
  if prefix == LIBKEYSTONE_SYNC_PREFIX then
    return ProcessLibKeystoneMessage(message, sender, localName, localRealm, channel)
  end
  if prefix ~= ISILIVE_SYNC_PREFIX then
    return nil
  end
  if type(sender) ~= "string" or sender == "" then
    return nil
  end
  if type(message) ~= "string" or #message == 0 or #message > MAX_ADDON_MESSAGE_LENGTH then
    return nil
  end
  if not IsIsiLiveReceiveChannelAllowed(message, channel) then
    return nil
  end

  SyncLog("message_received", "sender=%s type=%s", tostring(sender), tostring(message:match("^(%a+)") or "unknown"))

  local senderKey = Sync.NormalizePlayerKey(sender)
  local selfKey = Sync.NormalizePlayerKey(localName, localRealm)
  local isHelloMessage = message:find("^HELLO:") ~= nil
  local isAckMessage = message:find("^ACK:") ~= nil
  local shouldAck = isHelloMessage and senderKey ~= selfKey
  local shouldRequestRefresh = message == "REQSYNC" and senderKey ~= selfKey
  local shouldShareKeys = message == "SHAREKEYS" and senderKey ~= selfKey

  local keyUpdated = false
  local statsUpdated = false
  local dpsUpdated = false
  local locUpdated = false
  local kickUpdated = false
  local targetUpdated = false
  local combatAnnounce = nil
  local powerInfusionAnnounce = nil
  local shareKeysCooldownRemain = nil
  local payloadValid = message == "REQSYNC" or message == "SHAREKEYS"

  local parts = SplitPayload(message)
  local bucket = parts[1]
  SyncLogDeep(
    "message_payload",
    "sender=%s senderBytes=%s bucket=%s raw=%s",
    tostring(sender),
    FormatBytes(sender),
    tostring(bucket or "unknown"),
    tostring(message)
  )

  if bucket == "KEY" and parts[2] and parts[3] then
    local mapID = ToFiniteNumber(parts[2])
    local level = ToFiniteNumber(parts[3])
    local capturedAt = ToFiniteNumber(parts[4])
    if mapID and level and (parts[4] == nil or capturedAt) then
      payloadValid = true
      keyUpdated = Sync.SetPlayerKeyInfo(sender, nil, mapID, level, capturedAt, parts[5])
    end
  elseif bucket == "STATS" and parts[2] and parts[3] and parts[4] then
    local specID = ToFiniteNumber(parts[2])
    local ilvl = ToFiniteNumber(parts[3])
    local rio = ToFiniteNumber(parts[4])
    local capturedAt = ToFiniteNumber(parts[5])
    if specID and ilvl and rio and (parts[5] == nil or capturedAt) then
      payloadValid = true
      statsUpdated = Sync.SetPlayerStatsInfo(sender, nil, specID, ilvl, rio, capturedAt, parts[6])
    end
  elseif bucket == "DPS" and parts[2] then
    local dps = ToFiniteNumber(parts[2])
    local capturedAt = ToFiniteNumber(parts[3])
    if dps and (parts[3] == nil or capturedAt) then
      payloadValid = true
      dpsUpdated = Sync.SetPlayerDpsInfo(sender, nil, dps, capturedAt, parts[4])
    end
  elseif bucket == "LOC" and parts[2] then
    local mapID = ToFiniteNumber(parts[2])
    local capturedAt = ToFiniteNumber(parts[3])
    if mapID and (parts[3] == nil or capturedAt) then
      payloadValid = true
      locUpdated = Sync.SetPlayerLocInfo(sender, nil, mapID, capturedAt, parts[4])
    end
  elseif bucket == "TARGET" and parts[2] and parts[3] then
    local levelText = nil
    if parts[6] == "LT" and type(parts[7]) == "string" then
      levelText = parts[7]
    end
    local mapID = ToFiniteNumber(parts[2])
    local level = ToFiniteNumber(parts[3])
    local capturedAt = ToFiniteNumber(parts[4])
    if mapID and level and (parts[4] == nil or capturedAt) then
      payloadValid = true
      targetUpdated = Sync.SetPlayerTargetInfo(sender, nil, mapID, level, capturedAt, parts[5], levelText)
    end
  elseif bucket == "KICK" then
    local parsedKick = ParseKickPayload(message)
    if parsedKick then
      payloadValid = true
      kickUpdated = Sync.SetPlayerKickInfo(
        sender,
        nil,
        parsedKick.state == 1,
        parsedKick.remain,
        nil,
        parsedKick.hasKick,
        parsedKick.extras,
        parsedKick.spellID
      )
    end
  elseif bucket == "SKCD" and parts[2] then
    -- Mirrored share-keys button lock from a peer (hello-ack / REQSYNC fan-out).
    -- Self-echo is skipped: the local button is already on cooldown.
    if senderKey ~= selfKey then
      local remain = ToFiniteNumber(parts[2])
      if remain and remain > 0 then
        payloadValid = true
        remain = math.ceil(remain)
        if remain > ISILIVE_SHAREKEYS_CD_MAX_SECONDS then
          remain = ISILIVE_SHAREKEYS_CD_MAX_SECONDS
        end
        shareKeysCooldownRemain = remain
      end
    end
  elseif bucket == "BRLUST" and parts[2] and parts[3] then
    -- Skip self-echo: BroadcastCombatAnnounce already rendered the announce
    -- locally before sending. CHAT_MSG_ADDON on PARTY/INSTANCE_CHAT echoes
    -- back to the sender, so without this guard the print + sound fire twice
    -- for the caster.
    if senderKey ~= selfKey and Sync.NormalizePlayerKey(parts[3]) == senderKey then
      local kind = parts[2]
      if kind == "BR" or kind == "LUST" then
        local spellID = ToFiniteNumber(parts[4])
        if not spellID or spellID <= 0 then
          spellID = nil
        end
        if spellID then
          payloadValid = true
          combatAnnounce = {
            kind = kind,
            caster = parts[3],
            spellID = math.floor(spellID),
          }
        end
      end
    end
  elseif bucket == "PI" and parts[2] and parts[3] then
    -- Skip self-echo: BroadcastPowerInfusionAnnounce already rendered the
    -- announce locally before sending.
    if senderKey ~= selfKey and Sync.NormalizePlayerKey(parts[2]) == senderKey then
      local caster = parts[2]
      local recipient = parts[3]
      local spellID = ToFiniteNumber(parts[4]) or 0
      if caster ~= "" and recipient ~= "" and spellID == 10060 then
        payloadValid = true
        powerInfusionAnnounce = {
          caster = caster,
          recipient = recipient,
          spellID = spellID,
          isLocalRecipient = Sync.NormalizePlayerKey(recipient) == selfKey,
        }
      end
    end
  end

  local peerAddonVersion = nil
  local peerProtocolVersion = nil
  local peerCapturedAt = nil
  local peerSource = nil
  if isHelloMessage or isAckMessage then
    peerAddonVersion = parts[2]
    if isHelloMessage then
      peerProtocolVersion = ToFiniteNumber(parts[3])
      peerCapturedAt = ToFiniteNumber(parts[4])
      peerSource = parts[5]
      local metadataValid = not IsExplicitNonFiniteNumber(parts[3]) and not IsExplicitNonFiniteNumber(parts[4])
      if metadataValid then
        payloadValid = true
        Sync.SetPlayerHelloInfo(sender, nil, peerAddonVersion, peerProtocolVersion, peerCapturedAt, peerSource)
      else
        peerAddonVersion = nil
        peerProtocolVersion = nil
        peerCapturedAt = nil
        peerSource = nil
        shouldAck = false
      end
    elseif peerAddonVersion and peerAddonVersion ~= "" then
      payloadValid = true
      peerSource = "ack"
      Sync.SetPlayerHelloAckInfo(sender, nil, peerAddonVersion)
    end
  end

  -- Loop breaker: a HELLO that is itself an ack fan-out reply must not be
  -- acked again. Without this, two peers answer each other's hello-acks
  -- forever (the fan-out hello is force-sent past the 8 s rate limit), the
  -- resulting message flood backs up the ChatThrottleLib queue by ~30 s, and
  -- the mirrored SKCD locks reflect between the peers indefinitely.
  if shouldAck and (peerSource == "hello-ack" or peerSource == "reqsync-ack") then
    shouldAck = false
  end

  if payloadValid then
    Sync.MarkUser(sender)
  end

  local anyFlag = keyUpdated
    or statsUpdated
    or dpsUpdated
    or locUpdated
    or targetUpdated
    or kickUpdated
    or shouldAck
    or shouldRequestRefresh
    or shouldShareKeys
    or shareKeysCooldownRemain ~= nil
  local logFn = anyFlag and SyncLog or SyncLogDeep
  logFn(
    "message_applied",
    "sender=%s key=%s stats=%s dps=%s loc=%s target=%s kick=%s ack=%s reqsync=%s sharekeys=%s skcd=%s",
    tostring(sender),
    tostring(keyUpdated),
    tostring(statsUpdated),
    tostring(dpsUpdated),
    tostring(locUpdated),
    tostring(targetUpdated),
    tostring(kickUpdated),
    tostring(shouldAck),
    tostring(shouldRequestRefresh),
    tostring(shouldShareKeys),
    tostring(shareKeysCooldownRemain)
  )
  return {
    shouldAck = shouldAck and true or false,
    shouldRequestRefresh = shouldRequestRefresh and true or false,
    sender = sender,
    peerAddonVersion = peerAddonVersion,
    peerProtocolVersion = peerProtocolVersion,
    peerCapturedAt = peerCapturedAt,
    peerSource = peerSource,
    keyUpdated = keyUpdated and true or false,
    statsUpdated = statsUpdated and true or false,
    dpsUpdated = dpsUpdated and true or false,
    locUpdated = locUpdated and true or false,
    targetUpdated = targetUpdated and true or false,
    kickUpdated = kickUpdated and true or false,
    shouldShareKeys = shouldShareKeys and true or false,
    shareKeysCooldownRemain = shareKeysCooldownRemain,
    combatAnnounce = combatAnnounce,
    powerInfusionAnnounce = powerInfusionAnnounce,
  }
end
