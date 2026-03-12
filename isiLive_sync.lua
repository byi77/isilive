local _, addonTable = ...

addonTable = addonTable or {}

local Sync = {}
addonTable.Sync = Sync
local SeasonData = addonTable.SeasonData or {}

local ISILIVE_SYNC_PREFIX = "ISILIVE"
local ISILIVE_HELLO_COOLDOWN = 8
local ISILIVE_KEY_COOLDOWN = 5
local ISILIVE_STATS_COOLDOWN = 5

-- Hinweis: Die folgenden Variablen sind bewusst auf Modul-Ebene (Singleton).
-- Das Addon hat genau eine aktive Sync-Instanz pro Session. Die Cooldown-Variablen
-- (lastIsiLive*) verhindern Doppelnachrichten addon-weit. isiLiveUsersByKey und
-- keyInfoByPlayerKey sind session-globaler Zustand, der beim Gruppenauflösen via
-- ClearKnownUsers() zurückgesetzt wird (siehe group.lua → HandleNoGroup).
-- Architekturinkonsistenz zum CreateController()-Muster der übrigen Module ist bekannt.
local lastIsiLiveHelloAt = 0
local lastIsiLiveKeyAt = 0
local lastIsiLiveStatsAt = 0
local lastKeyPayloadSent = nil
local lastStatsPayloadSent = nil
local isiLiveUsersByKey = {}
local keyInfoByPlayerKey = {}
local statsInfoByPlayerKey = {}

-- Hinweis: Diese Normalisierung ist strikter als NormalizeName() in isiLive_stats.lua
-- (entfernt zusätzlich Sonderzeichen aus dem Realm-Namen). Beide müssen konsistent
-- gehalten werden, sonst können Keys bei Realms mit Sonderzeichen divergieren.
function Sync.NormalizePlayerKey(name, realm)
  local n = name and tostring(name) or ""
  local r = realm and tostring(realm) or ""

  if r == "" and string.find(n, "-", 1, true) then
    local splitName, splitRealm = strsplit("-", n, 2)
    n = splitName or n
    r = splitRealm or r
  end

  if r == "" then
    r = GetRealmName() or ""
  end

  -- Strict normalization:
  -- Name: remove spaces (shouldn't have any, but safety first)
  -- Realm: remove spaces, dashes, dots, parens, quotes (matches Locale.NormalizeRealmLookupKey)
  local n_clean = tostring(n):gsub("%s+", "")
  local r_clean = tostring(r):gsub("[%s%-%.%(%)'`]", "")
  local key = string.lower(n_clean .. "-" .. r_clean)
  return key
end

function Sync.GetPrefix()
  return ISILIVE_SYNC_PREFIX
end

local function NormalizeKeyPayload(mapID, level)
  local numericLevel = tonumber(level)
  local numericMapID = tonumber(mapID)
  if type(SeasonData.NormalizeMapID) == "function" then
    numericMapID = SeasonData.NormalizeMapID(numericMapID)
  end
  if not numericLevel or numericLevel <= 0 or not numericMapID or numericMapID <= 0 then
    return "KEY:0:0", nil, nil
  end
  return string.format("KEY:%d:%d", numericMapID, numericLevel), numericMapID, numericLevel
end

local function NormalizeStatsPayload(specID, ilvl, rio)
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

  return string.format("STATS:%d:%d:%d", numericSpecID, numericIlvl, numericRio), numericSpecID, numericIlvl, numericRio
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
end

function Sync.SetPlayerKeyInfo(name, realm, mapID, level)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
    return false
  end

  local _, numericMapID, numericLevel = NormalizeKeyPayload(mapID, level)
  local previous = keyInfoByPlayerKey[key]
  if not numericMapID or not numericLevel then
    local hadValue = type(previous) == "table"
    keyInfoByPlayerKey[key] = nil
    return hadValue
  end

  if previous and previous.mapID == numericMapID and previous.level == numericLevel then
    return false
  end

  keyInfoByPlayerKey[key] = {
    mapID = numericMapID,
    level = numericLevel,
  }
  return true
end

function Sync.GetPlayerKeyInfo(name, realm)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
    return nil
  end
  return keyInfoByPlayerKey[key]
end

function Sync.SetPlayerStatsInfo(name, realm, specID, ilvl, rio)
  local key = Sync.NormalizePlayerKey(name, realm)
  if not key or key == "" then
    return false
  end

  local _, numericSpecID, numericIlvl, numericRio = NormalizeStatsPayload(specID, ilvl, rio)
  local nextValue = {
    specID = numericSpecID > 0 and numericSpecID or nil,
    ilvl = numericIlvl > 0 and numericIlvl or nil,
    rio = numericRio >= 0 and numericRio or nil,
  }

  if nextValue.specID == nil and nextValue.ilvl == nil and nextValue.rio == nil then
    local hadValue = type(statsInfoByPlayerKey[key]) == "table"
    statsInfoByPlayerKey[key] = nil
    return hadValue
  end

  local previous = statsInfoByPlayerKey[key]
  if
    previous
    and previous.specID == nextValue.specID
    and previous.ilvl == nextValue.ilvl
    and previous.rio == nextValue.rio
  then
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
  end
end

function Sync.SendHello(opts)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return
  end
  opts = opts or {}

  if opts.isVisible == false then
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
  C_ChatInfo.SendAddonMessage(ISILIVE_SYNC_PREFIX, "HELLO:" .. tostring(opts.version or "?"), channel)
end

function Sync.SendKey(opts)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return
  end
  opts = opts or {}

  if opts.isVisible == false then
    return
  end

  local channel = Sync.GetAddonSyncChannel()
  if not channel then
    return
  end

  local payload = NormalizeKeyPayload(opts.mapID, opts.level)
  local now = GetTime()
  if not opts.force and payload == lastKeyPayloadSent and (now - lastIsiLiveKeyAt) < ISILIVE_KEY_COOLDOWN then
    return
  end

  lastIsiLiveKeyAt = now
  lastKeyPayloadSent = payload
  C_ChatInfo.SendAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel)
end

function Sync.SendStats(opts)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return
  end
  opts = opts or {}

  if opts.isVisible == false then
    return
  end

  local channel = Sync.GetAddonSyncChannel()
  if not channel then
    return
  end

  local payload = NormalizeStatsPayload(opts.specID, opts.ilvl, opts.rio)
  local now = GetTime()
  if not opts.force and payload == lastStatsPayloadSent and (now - lastIsiLiveStatsAt) < ISILIVE_STATS_COOLDOWN then
    return
  end

  lastIsiLiveStatsAt = now
  lastStatsPayloadSent = payload
  C_ChatInfo.SendAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel)
end

function Sync.ProcessAddonMessage(prefix, message, sender, localName, localRealm)
  if prefix ~= ISILIVE_SYNC_PREFIX then
    return nil
  end
  if type(sender) ~= "string" or sender == "" then
    return nil
  end

  Sync.MarkUser(sender)

  local senderKey = Sync.NormalizePlayerKey(sender)
  local selfKey = Sync.NormalizePlayerKey(localName, localRealm)
  local shouldAck = type(message) == "string" and message:find("^HELLO:") and senderKey ~= selfKey
  local keyUpdated = false

  if type(message) == "string" and message:find("^KEY:") then
    local mapIDRaw, levelRaw = string.match(message, "^KEY:([%-]?%d+):([%-]?%d+)$")
    if mapIDRaw and levelRaw then
      keyUpdated = Sync.SetPlayerKeyInfo(sender, nil, tonumber(mapIDRaw), tonumber(levelRaw))
    end
  end

  local statsUpdated = false
  if type(message) == "string" and message:find("^STATS:") then
    local specIDRaw, ilvlRaw, rioRaw = string.match(message, "^STATS:([%-]?%d+):([%-]?%d+):([%-]?%d+)$")
    if specIDRaw and ilvlRaw and rioRaw then
      statsUpdated = Sync.SetPlayerStatsInfo(sender, nil, tonumber(specIDRaw), tonumber(ilvlRaw), tonumber(rioRaw))
    end
  end

  return {
    shouldAck = shouldAck and true or false,
    sender = sender,
    keyUpdated = keyUpdated and true or false,
    statsUpdated = statsUpdated and true or false,
  }
end
