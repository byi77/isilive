local _, addonTable = ...

addonTable = addonTable or {}

local Sync = {}
addonTable.Sync = Sync

local ISILIVE_SYNC_PREFIX = "ISILIVE"
local ISILIVE_HELLO_COOLDOWN = 8
local lastIsiLiveHelloAt = 0
local isiLiveUsersByKey = {}

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

  local key = string.lower(n .. "-" .. r)
  key = key:gsub("%s+", "")
  return key
end

function Sync.GetPrefix()
  return ISILIVE_SYNC_PREFIX
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

  if not opts.isVisible then
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

  return {
    shouldAck = shouldAck and true or false,
    sender = sender,
  }
end
