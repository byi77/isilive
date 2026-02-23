local _, addonTable = ...

addonTable = addonTable or {}

local KeySync = {}
addonTable.KeySync = KeySync

local SeasonData = addonTable.SeasonData or {}

local function GetOwnedKeystoneSnapshot()
  local mythicPlusApi = rawget(_G, "C_MythicPlus")
  if not mythicPlusApi then
    return nil, nil
  end

  local okLevel, level = pcall(mythicPlusApi.GetOwnedKeystoneLevel)
  local okMapID, mapID = pcall(mythicPlusApi.GetOwnedKeystoneChallengeMapID)
  if not okLevel or not okMapID then
    return nil, nil
  end

  level = tonumber(level)
  mapID = tonumber(mapID)
  if type(SeasonData.NormalizeMapID) == "function" then
    mapID = SeasonData.NormalizeMapID(mapID)
  end
  if not level or level <= 0 or not mapID or mapID <= 0 then
    return nil, nil
  end

  return mapID, level
end

local function SendIsiLiveHello(sync, isFrameVisible, getAddonVersionRaw, force)
  sync.SendHello({
    force = force and true or false,
    isVisible = isFrameVisible(),
    version = getAddonVersionRaw(),
  })
end

local function SendOwnKeySnapshot(sync, isFrameVisible, force)
  local mapID, level = GetOwnedKeystoneSnapshot()
  sync.SendKey({
    force = force and true or false,
    isVisible = isFrameVisible(),
    mapID = mapID,
    level = level,
  })
end

local function ApplyKnownKeyToRosterEntry(sync, info)
  if type(info) ~= "table" then
    return false
  end
  local keyInfo = sync.GetPlayerKeyInfo(info.name, info.realm)
  local newMapID = keyInfo and keyInfo.mapID or nil
  local newLevel = keyInfo and keyInfo.level or nil
  if info.keyMapID == newMapID and info.keyLevel == newLevel then
    return false
  end
  info.keyMapID = newMapID
  info.keyLevel = newLevel
  return true
end

local function RefreshLocalPlayerKey(sync, roster)
  local playerInfo = roster and roster.player
  if type(playerInfo) ~= "table" then
    return false
  end

  local mapID, level = GetOwnedKeystoneSnapshot()
  sync.SetPlayerKeyInfo(playerInfo.name, playerInfo.realm, mapID, level)
  if playerInfo.keyMapID == mapID and playerInfo.keyLevel == level then
    return false
  end
  playerInfo.keyMapID = mapID
  playerInfo.keyLevel = level
  return true
end

local function ForceRefreshSyncState(sync, getUnitNameAndRealm, roster)
  if not roster then
    return
  end

  if sync.ClearKnownUsers then
    sync.ClearKnownUsers()
  end

  local playerName, playerRealm = getUnitNameAndRealm("player")
  sync.MarkUser(playerName, playerRealm)

  for unit, info in pairs(roster) do
    if type(info) == "table" then
      info.hasIsiLive = (unit == "player")
      info.keyMapID = nil
      info.keyLevel = nil
      sync.SetPlayerKeyInfo(info.name, info.realm, nil, nil)
    end
  end

  local ownKeyMapID, ownKeyLevel = GetOwnedKeystoneSnapshot()
  if roster.player and type(roster.player) == "table" then
    roster.player.keyMapID = ownKeyMapID
    roster.player.keyLevel = ownKeyLevel
  end
  sync.SetPlayerKeyInfo(playerName, playerRealm, ownKeyMapID, ownKeyLevel)
end

local function ResolveActiveKeyOwnerUnit(roster, activeJoinedKeyMapID)
  local targetMapID = tonumber(activeJoinedKeyMapID)
  if not targetMapID then
    return nil
  end

  local ownerUnit = nil
  local matches = 0
  for unit, info in pairs(roster or {}) do
    if type(info) == "table" and tonumber(info.keyMapID) == targetMapID then
      matches = matches + 1
      ownerUnit = unit
      if matches > 1 then
        return nil
      end
    end
  end

  if matches == 1 then
    return ownerUnit
  end
  return nil
end

function KeySync.CreateController(opts)
  opts = opts or {}
  local sync = opts.sync or {}
  local getUnitNameAndRealm = opts.getUnitNameAndRealm or function(_unit)
    return nil, nil
  end
  local getAddonVersionRaw = opts.getAddonVersionRaw or function()
    return "?"
  end
  local isFrameVisible = opts.isFrameVisible or function()
    return false
  end

  assert(type(sync.MarkUser) == "function", "isiLive: KeySync requires sync.MarkUser")
  assert(type(sync.IsUnitKnown) == "function", "isiLive: KeySync requires sync.IsUnitKnown")
  assert(type(sync.RegisterPrefix) == "function", "isiLive: KeySync requires sync.RegisterPrefix")
  assert(type(sync.SendHello) == "function", "isiLive: KeySync requires sync.SendHello")
  assert(type(sync.SendKey) == "function", "isiLive: KeySync requires sync.SendKey")
  assert(type(sync.GetPlayerKeyInfo) == "function", "isiLive: KeySync requires sync.GetPlayerKeyInfo")
  assert(type(sync.SetPlayerKeyInfo) == "function", "isiLive: KeySync requires sync.SetPlayerKeyInfo")

  local controller = {}

  function controller.MarkIsiLiveUser(name, realm)
    sync.MarkUser(name, realm)
  end

  function controller.UnitHasIsiLive(unit)
    return sync.IsUnitKnown(getUnitNameAndRealm, unit)
  end

  function controller.RegisterIsiLiveSyncPrefix()
    sync.RegisterPrefix()
  end

  function controller.SendIsiLiveHello(force)
    SendIsiLiveHello(sync, isFrameVisible, getAddonVersionRaw, force)
  end

  function controller.GetOwnedKeystoneSnapshot()
    return GetOwnedKeystoneSnapshot()
  end

  function controller.SendOwnKeySnapshot(force)
    SendOwnKeySnapshot(sync, isFrameVisible, force)
  end

  function controller.ApplyKnownKeyToRosterEntry(info)
    return ApplyKnownKeyToRosterEntry(sync, info)
  end

  function controller.RefreshLocalPlayerKey(roster)
    return RefreshLocalPlayerKey(sync, roster)
  end

  function controller.ForceRefreshSyncState(roster)
    ForceRefreshSyncState(sync, getUnitNameAndRealm, roster)
  end

  function controller.ResolveActiveKeyOwnerUnit(roster, activeJoinedKeyMapID)
    return ResolveActiveKeyOwnerUnit(roster, activeJoinedKeyMapID)
  end

  return controller
end
