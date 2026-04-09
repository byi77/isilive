local _, addonTable = ...

addonTable = addonTable or {}

local Sync = {}
addonTable.Sync = Sync
local SeasonData = addonTable.SeasonData or {}
local StringUtils = addonTable.StringUtils

local ISILIVE_SYNC_PREFIX = "ISILIVE"
local LIBKEYSTONE_SYNC_PREFIX = "LibKS"
local LIBKEYSTONE_SOURCE = "libks"
local ISILIVE_SYNC_PROTOCOL_VERSION = 2
local ISILIVE_HELLO_COOLDOWN = 8
local ISILIVE_KEY_COOLDOWN = 5
local ISILIVE_STATS_COOLDOWN = 5
local ISILIVE_TARGET_COOLDOWN = 5
local ISILIVE_REFRESH_REQUEST_COOLDOWN = 1
local LIBKEYSTONE_REQUEST_COOLDOWN = 3

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

local function GetSyncTimestamp()
  local getServerTime = rawget(_G, "GetServerTime")
  if type(getServerTime) == "function" then
    local ok, serverTime = pcall(getServerTime)
    local numericServerTime = ok and tonumber(serverTime) or nil
    if numericServerTime and numericServerTime > 0 then
      return math.floor(numericServerTime)
    end
  end

  local timeFn = rawget(_G, "time")
  if type(timeFn) == "function" then
    local ok, unixTime = pcall(timeFn)
    local numericUnixTime = ok and tonumber(unixTime) or nil
    if numericUnixTime and numericUnixTime > 0 then
      return math.floor(numericUnixTime)
    end
  end

  local getTime = rawget(_G, "GetTime")
  if type(getTime) == "function" then
    local ok, elapsed = pcall(getTime)
    local numericElapsed = ok and tonumber(elapsed) or nil
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
  local numericVersion = tonumber(protocolVersion)
  if not numericVersion or numericVersion <= 0 then
    return ISILIVE_SYNC_PROTOCOL_VERSION
  end
  return math.floor(numericVersion)
end

local function SplitPayload(message)
  local parts = {}
  for part in tostring(message or ""):gmatch("([^:]+)") do
    parts[#parts + 1] = part
  end
  return parts
end

local function IsSyncEnabled()
  local db = rawget(_G, "IsiLiveDB")
  return not db or db.syncEnabled ~= false
end

-- Realm-Normalisierung ist identisch mit NormalizeName() in isiLive_stats.lua:
-- beide entfernen Spaces, Bindestriche, Punkte, Klammern und Apostrophe aus dem Realm.
function Sync.NormalizePlayerKey(name, realm)
  local n = name and tostring(name) or ""
  local r = realm and tostring(realm) or ""

  if r == "" and string.find(n, "-", 1, true) then
    local splitName, splitRealm = strsplit("-", n, 2)
    n = splitName or n
    r = splitRealm or r
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

function Sync.GetPrefix()
  return ISILIVE_SYNC_PREFIX
end

function Sync.GetProtocolVersion()
  return ISILIVE_SYNC_PROTOCOL_VERSION
end

local function NormalizeKeyPayload(mapID, level, capturedAt, source)
  local numericLevel = tonumber(level)
  local numericMapID = tonumber(mapID)
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
  local normalizedCapturedAt = tonumber(capturedAt)
  if not normalizedCapturedAt or normalizedCapturedAt <= 0 then
    normalizedCapturedAt = GetSyncTimestamp() or 0
  end
  local normalizedSource = NormalizeSyncSource(source) or "local"
  return string.format(
    "KEY:%d:%d:%d:%s",
    numericMapID,
    numericLevel,
    math.floor(normalizedCapturedAt),
    normalizedSource
  ),
    numericMapID,
    numericLevel,
    math.floor(normalizedCapturedAt),
    normalizedSource
end

local function NormalizeStatsPayload(specID, ilvl, rio, capturedAt, source)
  local numericSpecID = tonumber(specID)
  local numericIlvl = tonumber(ilvl)
  local numericRio = tonumber(rio)

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

  local normalizedCapturedAt = tonumber(capturedAt)
  if not normalizedCapturedAt or normalizedCapturedAt <= 0 then
    normalizedCapturedAt = GetSyncTimestamp() or 0
  end
  local normalizedSource = NormalizeSyncSource(source) or "local"

  return string.format(
    "STATS:%d:%d:%d:%d:%s",
    numericSpecID,
    numericIlvl,
    numericRio,
    math.floor(normalizedCapturedAt),
    normalizedSource
  ),
    numericSpecID,
    numericIlvl,
    numericRio,
    math.floor(normalizedCapturedAt),
    normalizedSource
end

local function NormalizeDpsPayload(dps, capturedAt, source)
  local numericDps = tonumber(dps)
  if not numericDps or numericDps < 0 then
    numericDps = 0
  else
    numericDps = math.floor(numericDps + 0.5)
  end
  local normalizedCapturedAt = tonumber(capturedAt)
  if not normalizedCapturedAt or normalizedCapturedAt <= 0 then
    normalizedCapturedAt = GetSyncTimestamp() or 0
  end
  local normalizedSource = NormalizeSyncSource(source) or "local"
  return string.format("DPS:%d:%d:%s", numericDps, math.floor(normalizedCapturedAt), normalizedSource),
    numericDps,
    math.floor(normalizedCapturedAt),
    normalizedSource
end

local function NormalizeLocPayload(mapID, capturedAt, source)
  local numericMapID = tonumber(mapID)
  if not numericMapID or numericMapID <= 0 then
    local normalizedCapturedAt = tonumber(capturedAt)
    if not normalizedCapturedAt or normalizedCapturedAt <= 0 then
      normalizedCapturedAt = GetSyncTimestamp() or 0
    end
    local normalizedSource = NormalizeSyncSource(source) or "local"
    return string.format("LOC:0:%d:%s", math.floor(normalizedCapturedAt), normalizedSource),
      nil,
      math.floor(normalizedCapturedAt),
      normalizedSource
  end
  numericMapID = math.floor(numericMapID)
  local normalizedCapturedAt = tonumber(capturedAt)
  if not normalizedCapturedAt or normalizedCapturedAt <= 0 then
    normalizedCapturedAt = GetSyncTimestamp() or 0
  end
  local normalizedSource = NormalizeSyncSource(source) or "local"
  return string.format("LOC:%d:%d:%s", numericMapID, math.floor(normalizedCapturedAt), normalizedSource),
    numericMapID,
    math.floor(normalizedCapturedAt),
    normalizedSource
end

local function NormalizeTargetPayload(mapID, level, capturedAt, source)
  local numericMapID = tonumber(mapID)
  local numericLevel = tonumber(level)
  if not numericMapID or numericMapID <= 0 then
    local normalizedCapturedAt = tonumber(capturedAt)
    if not normalizedCapturedAt or normalizedCapturedAt <= 0 then
      normalizedCapturedAt = GetSyncTimestamp() or 0
    end
    local normalizedSource = NormalizeSyncSource(source) or "local"
    return string.format("TARGET:0:0:%d:%s", math.floor(normalizedCapturedAt), normalizedSource),
      nil,
      nil,
      math.floor(normalizedCapturedAt),
      normalizedSource
  end

  numericMapID = math.floor(numericMapID)
  if not numericLevel or numericLevel <= 0 then
    numericLevel = nil
  else
    numericLevel = math.floor(numericLevel)
  end

  local normalizedCapturedAt = tonumber(capturedAt)
  if not normalizedCapturedAt or normalizedCapturedAt <= 0 then
    normalizedCapturedAt = GetSyncTimestamp() or 0
  end
  local normalizedSource = NormalizeSyncSource(source) or "local"
  return string.format(
    "TARGET:%d:%d:%d:%s",
    numericMapID,
    numericLevel or 0,
    math.floor(normalizedCapturedAt),
    normalizedSource
  ),
    numericMapID,
    numericLevel,
    math.floor(normalizedCapturedAt),
    normalizedSource
end

function Sync.MarkUser(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  if key and key ~= "" then
    isiLiveUsersByKey[key] = true
  end
end

function Sync.IsUserKnown(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  return key and isiLiveUsersByKey[key] == true
end

function Sync.IsUnitKnown(getUnitNameAndRealm, unit)
  if type(getUnitNameAndRealm) ~= "function" then
    return false
  end
  local name, realm = getUnitNameAndRealm(unit)
  return Sync.IsUserKnown(name, realm)
end

function Sync.ClearKnownUsers()
  isiLiveUsersByKey = {}
  helloInfoByPlayerKey = {}
  keyInfoByPlayerKey = {}
  statsInfoByPlayerKey = {}
  dpsInfoByPlayerKey = {}
  locInfoByPlayerKey = {}
  targetInfoByPlayerKey = {}
  kickInfoByPlayerKey = {}
  lastIsiLiveHelloAt = 0
  lastIsiLiveKeyAt = 0
  lastIsiLiveStatsAt = 0
  lastIsiLiveDpsAt = 0
  lastIsiLiveLocAt = 0
  lastIsiLiveTargetAt = 0
  lastIsiLiveKickAt = 0
  lastIsiLiveRefreshRequestAt = 0
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

  local capturedAt = tonumber(entry.capturedAt)
  local receivedAt = tonumber(entry.receivedAt)
  return capturedAt or receivedAt
end

local function SetEntryPreviousSyncStamp(entry, previousStamp)
  if type(entry) ~= "table" then
    return
  end

  previousStamp = tonumber(previousStamp)
  local nextStamp = GetEntrySyncStamp(entry)
  if previousStamp and nextStamp and nextStamp >= previousStamp then
    entry.previousSyncStamp = previousStamp
  else
    entry.previousSyncStamp = nil
  end
end

function Sync.SetPlayerHelloInfo(name, realm, addonVersion, protocolVersion, capturedAt, source)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
    return false
  end

  local normalizedProtocolVersion = NormalizeSyncProtocolVersion(protocolVersion)
  local normalizedCapturedAt = tonumber(capturedAt)
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

function Sync.GetPlayerHelloInfo(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
    return nil
  end
  return helloInfoByPlayerKey[key]
end

function Sync.SetPlayerKeyInfo(name, realm, mapID, level, capturedAt, source)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
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

function Sync.GetPlayerKeyInfo(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
    return nil
  end
  return keyInfoByPlayerKey[key]
end

function Sync.SetPlayerStatsInfo(name, realm, specID, ilvl, rio, capturedAt, source)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
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

function Sync.GetPlayerStatsInfo(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
    return nil
  end
  return statsInfoByPlayerKey[key]
end

function Sync.SetPlayerDpsInfo(name, realm, dps, capturedAt, source)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
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

function Sync.GetPlayerDpsInfo(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
    return nil
  end
  return dpsInfoByPlayerKey[key]
end

function Sync.SetPlayerKickInfo(name, realm, onCooldown, cooldownRemain, capturedAt, hasKick)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
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
  local numericRemain = tonumber(cooldownRemain)
  if newHasKick then
    if numericRemain == nil or numericRemain < 0 then
      return false
    end
  elseif newOnCooldown then
    return false
  end
  local prevRemain = tonumber(prev and prev.cooldownRemain) or 0
  local remainChanged = newHasKick and newOnCooldown and math.abs(prevRemain - numericRemain) > 0.05
  local changed = not prev or prev.onCooldown ~= newOnCooldown or prev.hasKick ~= newHasKick or remainChanged
  local getTime = rawget(_G, "GetTime")
  kickInfoByPlayerKey[key] = {
    hasKick = newHasKick,
    onCooldown = newOnCooldown,
    cooldownRemain = newHasKick and numericRemain or 0,
    capturedAt = tonumber(capturedAt) or now,
    receivedAt = now,
    receivedAtGetTime = type(getTime) == "function" and getTime() or nil,
  }
  return changed
end

function Sync.GetPlayerKickInfo(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
    return nil
  end
  return kickInfoByPlayerKey[key]
end

function Sync.ClearPlayerKickInfo(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
    return false
  end
  local hadValue = type(kickInfoByPlayerKey[key]) == "table"
  kickInfoByPlayerKey[key] = nil
  return hadValue
end

function Sync.SetPlayerLocInfo(name, realm, mapID, capturedAt, source)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
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

function Sync.GetPlayerLocInfo(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
    return nil
  end
  return locInfoByPlayerKey[key]
end

function Sync.SetPlayerTargetInfo(name, realm, mapID, level, capturedAt, source)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
    return false
  end

  local _, numericMapID, numericLevel, normalizedCapturedAt, normalizedSource =
    NormalizeTargetPayload(mapID, level, capturedAt, source)
  local previous = targetInfoByPlayerKey[key]
  local previousStamp = GetEntrySyncStamp(previous)
  if not numericMapID then
    local hadValue = type(targetInfoByPlayerKey[key]) == "table"
    targetInfoByPlayerKey[key] = nil
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
  targetInfoByPlayerKey[key] = nextValue
  return true
end

function Sync.GetPlayerTargetInfo(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
    return nil
  end
  return targetInfoByPlayerKey[key]
end

function Sync.GetPlayerSyncSummary(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
    return nil
  end

  local candidates = {
    { kind = "hello", data = helloInfoByPlayerKey[key] },
    { kind = "key", data = keyInfoByPlayerKey[key] },
    { kind = "stats", data = statsInfoByPlayerKey[key] },
    { kind = "dps", data = dpsInfoByPlayerKey[key] },
    { kind = "loc", data = locInfoByPlayerKey[key] },
    { kind = "target", data = targetInfoByPlayerKey[key] },
  }

  local best = nil
  for _, candidate in ipairs(candidates) do
    local data = candidate.data
    if type(data) == "table" then
      local capturedAt = tonumber(data.capturedAt)
      local receivedAt = tonumber(data.receivedAt)
      local previousSyncStamp = tonumber(data.previousSyncStamp)
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

function Sync.GetAddonSyncChannel()
  local inInstanceGroup = LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
  if inInstanceGroup then
    return "INSTANCE_CHAT"
  end
  if IsInRaid() then
    return "RAID"
  end
  if IsInGroup() then
    return "PARTY"
  end
  return nil
end

function Sync.RegisterPrefix()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, ISILIVE_SYNC_PREFIX)
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, LIBKEYSTONE_SYNC_PREFIX)
  end
end

function Sync.SendHello(opts)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return
  end
  if not IsSyncEnabled() then
    return
  end
  opts = opts or {}

  if opts.isVisible == false and opts.allowHidden ~= true then
    return
  end

  local channel = Sync.GetAddonSyncChannel()
  if not channel then
    return
  end

  local now = GetTime()
  if not opts.force and (now - lastIsiLiveHelloAt) < ISILIVE_HELLO_COOLDOWN then
    return
  end

  lastIsiLiveHelloAt = now
  local payload = string.format(
    "HELLO:%s:%d:%d:%s",
    tostring(opts.version or "?"),
    NormalizeSyncProtocolVersion(opts.protocolVersion),
    GetSyncTimestamp() or 0,
    NormalizeSyncSource(opts.source) or "local"
  )
  C_ChatInfo.SendAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel)
end

function Sync.SendKey(opts)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return
  end
  if not IsSyncEnabled() then
    return
  end
  opts = opts or {}

  if opts.isVisible == false and opts.allowHidden ~= true then
    return
  end

  local channel = Sync.GetAddonSyncChannel()
  if not channel then
    return
  end

  local payload, numericMapID, numericLevel = NormalizeKeyPayload(opts.mapID, opts.level, opts.capturedAt, opts.source)
  local dedupePayload = string.format("KEY:%d:%d", tonumber(numericMapID) or 0, tonumber(numericLevel) or 0)
  local now = GetTime()
  if not opts.force and opts.onlyIfChanged == true and dedupePayload == lastKeyPayloadSent then
    return
  end
  if not opts.force and dedupePayload == lastKeyPayloadSent and (now - lastIsiLiveKeyAt) < ISILIVE_KEY_COOLDOWN then
    return
  end

  lastIsiLiveKeyAt = now
  lastKeyPayloadSent = dedupePayload
  C_ChatInfo.SendAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel)
end

function Sync.SendStats(opts)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return
  end
  if not IsSyncEnabled() then
    return
  end
  opts = opts or {}

  if opts.isVisible == false and opts.allowHidden ~= true then
    return
  end

  local channel = Sync.GetAddonSyncChannel()
  if not channel then
    return
  end

  local payload, numericSpecID, numericIlvl, numericRio =
    NormalizeStatsPayload(opts.specID, opts.ilvl, opts.rio, opts.capturedAt, opts.source)
  local dedupePayload =
    string.format("STATS:%d:%d:%d", tonumber(numericSpecID) or 0, tonumber(numericIlvl) or 0, tonumber(numericRio) or 0)
  local now = GetTime()
  if not opts.force and opts.onlyIfChanged == true and dedupePayload == lastStatsPayloadSent then
    return
  end
  if
    not opts.force
    and dedupePayload == lastStatsPayloadSent
    and (now - lastIsiLiveStatsAt) < ISILIVE_STATS_COOLDOWN
  then
    return
  end

  lastIsiLiveStatsAt = now
  lastStatsPayloadSent = dedupePayload
  C_ChatInfo.SendAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel)
end

function Sync.SendDps(opts)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return
  end
  if not IsSyncEnabled() then
    return
  end
  opts = opts or {}

  if opts.isVisible == false and opts.allowHidden ~= true then
    return
  end

  local channel = Sync.GetAddonSyncChannel()
  if not channel then
    return
  end

  local payload, numericDps = NormalizeDpsPayload(opts.dps, opts.capturedAt, opts.source)
  local dedupePayload = string.format("DPS:%d", tonumber(numericDps) or 0)
  local now = GetTime()
  if not opts.force and opts.onlyIfChanged == true and dedupePayload == lastDpsPayloadSent then
    return
  end
  if not opts.force and dedupePayload == lastDpsPayloadSent and (now - lastIsiLiveDpsAt) < ISILIVE_STATS_COOLDOWN then
    return
  end

  lastIsiLiveDpsAt = now
  lastDpsPayloadSent = dedupePayload
  C_ChatInfo.SendAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel)
end

function Sync.SendKick(opts)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return
  end
  if not IsSyncEnabled() then
    return
  end
  opts = opts or {}
  local channel = Sync.GetAddonSyncChannel()
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
  local cooldownRemain = tonumber(opts.cooldownRemain)
  if hasKick == true then
    if cooldownRemain == nil or cooldownRemain < 0 then
      return
    end
  elseif onCooldown == true then
    return
  end
  local encodedHasKick = hasKick == true
  local encodedOnCooldown = encodedHasKick and (onCooldown == true and 1 or 0) or -1
  local remain = encodedHasKick and math.ceil(cooldownRemain) or 0
  local now = GetTime()
  local payload = string.format("KICK:%d:%d", encodedOnCooldown, remain)
  if not opts.force and payload == lastKickPayloadSent and (now - lastIsiLiveKickAt) < 1 then
    return
  end
  lastIsiLiveKickAt = now
  lastKickPayloadSent = payload
  C_ChatInfo.SendAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel)
end

function Sync.SendLoc(opts)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return
  end
  if not IsSyncEnabled() then
    return
  end
  opts = opts or {}

  if opts.isVisible == false and opts.allowHidden ~= true then
    return
  end

  local channel = Sync.GetAddonSyncChannel()
  if not channel then
    return
  end

  local payload, numericMapID = NormalizeLocPayload(opts.mapID, opts.capturedAt, opts.source)
  local dedupePayload = string.format("LOC:%d", tonumber(numericMapID) or 0)
  local now = GetTime()
  if not opts.force and opts.onlyIfChanged == true and dedupePayload == lastLocPayloadSent then
    return
  end
  if not opts.force and dedupePayload == lastLocPayloadSent and (now - lastIsiLiveLocAt) < ISILIVE_STATS_COOLDOWN then
    return
  end

  lastIsiLiveLocAt = now
  lastLocPayloadSent = dedupePayload
  C_ChatInfo.SendAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel)
end

function Sync.SendTarget(opts)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return
  end
  if not IsSyncEnabled() then
    return
  end
  opts = opts or {}

  if opts.isVisible == false and opts.allowHidden ~= true then
    return
  end

  local channel = Sync.GetAddonSyncChannel()
  if not channel then
    return
  end

  local payload, numericMapID, numericLevel =
    NormalizeTargetPayload(opts.mapID, opts.level, opts.capturedAt, opts.source)
  local dedupePayload = string.format("TARGET:%d:%d", tonumber(numericMapID) or 0, tonumber(numericLevel) or 0)
  local now = GetTime()
  if
    not opts.force
    and dedupePayload == lastTargetPayloadSent
    and (now - lastIsiLiveTargetAt) < ISILIVE_TARGET_COOLDOWN
  then
    return
  end

  lastIsiLiveTargetAt = now
  lastTargetPayloadSent = dedupePayload
  C_ChatInfo.SendAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel)
end

function Sync.SendRefreshRequest(opts)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return
  end
  if not IsSyncEnabled() then
    return
  end
  opts = opts or {}

  local channel = Sync.GetAddonSyncChannel()
  if not channel then
    return
  end

  local now = GetTime()
  if not opts.force and (now - lastIsiLiveRefreshRequestAt) < ISILIVE_REFRESH_REQUEST_COOLDOWN then
    return
  end

  lastIsiLiveRefreshRequestAt = now
  C_ChatInfo.SendAddonMessage(ISILIVE_SYNC_PREFIX, "REQSYNC", channel)
end

function Sync.SendLibKeystoneRequest(opts)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return false
  end
  if not IsSyncEnabled() then
    return false
  end
  opts = opts or {}

  if IsInRaid and IsInRaid() then
    return false
  end
  if not (IsInGroup and IsInGroup()) then
    return false
  end

  local now = GetTime()
  if not opts.force and (now - lastLibKeystoneRequestAt) < LIBKEYSTONE_REQUEST_COOLDOWN then
    return false
  end

  lastLibKeystoneRequestAt = now
  C_ChatInfo.SendAddonMessage(LIBKEYSTONE_SYNC_PREFIX, "R", "PARTY")
  return true
end

function Sync.SendLibKeystonePartyData(opts)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return false
  end
  if not IsSyncEnabled() then
    return false
  end
  opts = opts or {}

  if IsInRaid and IsInRaid() then
    return false
  end
  if not (IsInGroup and IsInGroup()) then
    return false
  end

  local numericLevel = tonumber(opts.level)
  local numericMapID = tonumber(opts.mapID)
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

  local numericRio = tonumber(opts.rio)
  if numericRio == nil or numericRio < 0 then
    numericRio = 0
  else
    numericRio = math.floor(numericRio)
  end

  C_ChatInfo.SendAddonMessage(
    LIBKEYSTONE_SYNC_PREFIX,
    string.format("%d,%d,%d", numericLevel, numericMapID, numericRio),
    "PARTY"
  )
  return true
end

function Sync.SendShareKeysRequest()
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return
  end
  if not IsSyncEnabled() then
    return
  end
  local channel = Sync.GetAddonSyncChannel()
  if not channel then
    return
  end
  C_ChatInfo.SendAddonMessage(ISILIVE_SYNC_PREFIX, "SHAREKEYS", channel)
end

local function ProcessLibKeystoneMessage(message, sender, localName, localRealm, channel)
  if type(sender) ~= "string" or sender == "" then
    return nil
  end
  if channel ~= nil and channel ~= "PARTY" then
    return nil
  end

  local senderKey = Sync.NormalizePlayerKey(sender)
  local selfKey = Sync.NormalizePlayerKey(localName, localRealm)
  if type(message) == "string" and message == "R" then
    return {
      sender = sender,
      shouldReplyLibKeystone = senderKey ~= selfKey,
    }
  end

  local levelRaw, mapIDRaw, ratingRaw = nil, nil, nil
  if type(message) == "string" then
    levelRaw, mapIDRaw, ratingRaw = string.match(message, "^(-?%d+),(-?%d+),(%d+)$")
  end
  if not levelRaw or not mapIDRaw or not ratingRaw then
    return nil
  end

  local keyLevel = tonumber(levelRaw)
  local keyMapID = tonumber(mapIDRaw)
  local playerRating = tonumber(ratingRaw)
  if playerRating == nil or playerRating < 0 then
    return nil
  end

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

  Sync.MarkUser(sender)

  local senderKey = Sync.NormalizePlayerKey(sender)
  local selfKey = Sync.NormalizePlayerKey(localName, localRealm)
  local isHelloMessage = type(message) == "string" and message:find("^HELLO:")
  local shouldAck = isHelloMessage and senderKey ~= selfKey
  local shouldRequestRefresh = type(message) == "string" and message == "REQSYNC" and senderKey ~= selfKey
  local shouldShareKeys = type(message) == "string" and message == "SHAREKEYS" and senderKey ~= selfKey
  local keyUpdated = false

  if type(message) == "string" and message:find("^KEY:") then
    local parts = SplitPayload(message)
    local mapIDRaw = parts[2]
    local levelRaw = parts[3]
    local capturedAtRaw = parts[4]
    local sourceRaw = parts[5]
    if mapIDRaw and levelRaw then
      keyUpdated =
        Sync.SetPlayerKeyInfo(sender, nil, tonumber(mapIDRaw), tonumber(levelRaw), tonumber(capturedAtRaw), sourceRaw)
    end
  end

  local statsUpdated = false
  if type(message) == "string" and message:find("^STATS:") then
    local parts = SplitPayload(message)
    local specIDRaw = parts[2]
    local ilvlRaw = parts[3]
    local rioRaw = parts[4]
    local capturedAtRaw = parts[5]
    local sourceRaw = parts[6]
    if specIDRaw and ilvlRaw and rioRaw then
      statsUpdated = Sync.SetPlayerStatsInfo(
        sender,
        nil,
        tonumber(specIDRaw),
        tonumber(ilvlRaw),
        tonumber(rioRaw),
        tonumber(capturedAtRaw),
        sourceRaw
      )
    end
  end

  local dpsUpdated = false
  if type(message) == "string" and message:find("^DPS:") then
    local parts = SplitPayload(message)
    local dpsRaw = parts[2]
    local capturedAtRaw = parts[3]
    local sourceRaw = parts[4]
    if dpsRaw then
      dpsUpdated = Sync.SetPlayerDpsInfo(sender, nil, tonumber(dpsRaw), tonumber(capturedAtRaw), sourceRaw)
    end
  end

  local locUpdated = false
  if type(message) == "string" and message:find("^LOC:") then
    local parts = SplitPayload(message)
    local mapIDRaw = parts[2]
    local capturedAtRaw = parts[3]
    local sourceRaw = parts[4]
    if mapIDRaw then
      locUpdated = Sync.SetPlayerLocInfo(sender, nil, tonumber(mapIDRaw), tonumber(capturedAtRaw), sourceRaw)
    end
  end

  local kickUpdated = false
  if type(message) == "string" and message:find("^KICK:") then
    local parts = SplitPayload(message)
    local onCooldownRaw = parts[2]
    local remainRaw = parts[3]
    if onCooldownRaw ~= nil and remainRaw ~= nil then
      local numericState = tonumber(onCooldownRaw)
      local numericRemain = tonumber(remainRaw)
      if numericState == -1 or numericState == 0 or numericState == 1 then
        if numericRemain ~= nil and numericRemain >= 0 then
          local hasKick = numericState ~= -1
          kickUpdated = Sync.SetPlayerKickInfo(sender, nil, numericState == 1, numericRemain, nil, hasKick)
        end
      end
    end
  end

  local targetUpdated = false
  if type(message) == "string" and message:find("^TARGET:") then
    local parts = SplitPayload(message)
    local mapIDRaw = parts[2]
    local levelRaw = parts[3]
    local capturedAtRaw = parts[4]
    local sourceRaw = parts[5]
    if mapIDRaw and levelRaw then
      targetUpdated = Sync.SetPlayerTargetInfo(
        sender,
        nil,
        tonumber(mapIDRaw),
        tonumber(levelRaw),
        tonumber(capturedAtRaw),
        sourceRaw
      )
    end
  end

  local peerAddonVersion = nil
  local peerProtocolVersion = nil
  local peerCapturedAt = nil
  local peerSource = nil
  if isHelloMessage then
    local parts = SplitPayload(message)
    peerAddonVersion = parts[2]
    peerProtocolVersion = tonumber(parts[3])
    peerCapturedAt = tonumber(parts[4])
    peerSource = parts[5]
    Sync.SetPlayerHelloInfo(sender, nil, peerAddonVersion, peerProtocolVersion, peerCapturedAt, peerSource)
  end

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
  }
end
