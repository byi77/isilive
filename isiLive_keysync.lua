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
  -- NormalizeMapID hier beim Lesen anwenden; sync.lua NormalizeKeyPayload
  -- wendet es nochmals an (idempotent), um eingehende Nachrichten einheitlich
  -- zu normalisieren.
  if type(SeasonData.NormalizeMapID) == "function" then
    mapID = SeasonData.NormalizeMapID(mapID)
  end
  if not level or level <= 0 or not mapID or mapID <= 0 then
    return nil, nil
  end

  return mapID, level
end

local function GetOwnedStatsSnapshot(getUnitRio)
  local specID = nil
  if GetSpecialization and GetSpecializationInfo then
    local specIndex = GetSpecialization()
    if specIndex and specIndex > 0 then
      local resolvedSpecID = GetSpecializationInfo(specIndex)
      resolvedSpecID = tonumber(resolvedSpecID)
      if resolvedSpecID and resolvedSpecID > 0 then
        specID = math.floor(resolvedSpecID)
      end
    end
  end

  local ilvl = nil
  if C_Item and C_Item.GetAverageItemLevel then
    local avgIlvl, equippedIlvl = C_Item.GetAverageItemLevel()
    local resolvedIlvl = tonumber(equippedIlvl) or tonumber(avgIlvl)
    if resolvedIlvl and resolvedIlvl > 0 then
      ilvl = math.floor(resolvedIlvl)
    end
  elseif GetAverageItemLevel then
    -- Note: This is an unfortunate copy of the C_Item fallback logic above.
    -- Kept inline to avoid an extra function call overhead for just 4 lines.
    local avgIlvl, equippedIlvl = GetAverageItemLevel()
    local resolvedIlvl = tonumber(equippedIlvl) or tonumber(avgIlvl)
    if resolvedIlvl and resolvedIlvl > 0 then
      ilvl = math.floor(resolvedIlvl)
    end
  end

  local rio = nil
  if type(getUnitRio) == "function" then
    local resolvedRio = tonumber(getUnitRio("player"))
    if resolvedRio then
      rio = math.max(0, math.floor(resolvedRio))
    end
  end

  return specID, ilvl, rio
end

local function SendIsiLiveHello(sync, isFrameVisible, getAddonVersionRaw, force)
  sync.SendHello({
    force = force and true or false,
    isVisible = isFrameVisible(),
    version = getAddonVersionRaw(),
  })
end

local function SendOwnStatsSnapshot(sync, isFrameVisible, getUnitRio, force)
  local specID, ilvl, rio = GetOwnedStatsSnapshot(getUnitRio)
  sync.SendStats({
    force = force and true or false,
    isVisible = isFrameVisible(),
    specID = specID,
    ilvl = ilvl,
    rio = rio,
  })
end

local function SendOwnKeySnapshot(sync, isFrameVisible, getUnitRio, force)
  local mapID, level = GetOwnedKeystoneSnapshot()
  sync.SendKey({
    force = force and true or false,
    isVisible = isFrameVisible(),
    mapID = mapID,
    level = level,
  })
  SendOwnStatsSnapshot(sync, isFrameVisible, getUnitRio, force)
end

local function ResolveSpecName(specID)
  local numericSpecID = tonumber(specID)
  if not numericSpecID or numericSpecID <= 0 then
    return nil
  end
  if not GetSpecializationInfoByID then
    return nil
  end
  local _, specName = GetSpecializationInfoByID(numericSpecID)
  return specName
end

local function ApplyKnownKeyToRosterEntry(sync, info)
  if type(info) ~= "table" then
    return false
  end

  local changed = false

  local keyInfo = sync.GetPlayerKeyInfo(info.name, info.realm)
  local newMapID = keyInfo and keyInfo.mapID or nil
  local newLevel = keyInfo and keyInfo.level or nil
  if info.keyMapID ~= newMapID or info.keyLevel ~= newLevel then
    info.keyMapID = newMapID
    info.keyLevel = newLevel
    changed = true
  end

  local statsInfo = sync.GetPlayerStatsInfo(info.name, info.realm)
  if type(statsInfo) == "table" then
    if not info._localSpecFresh and statsInfo.specID then
      local specName = ResolveSpecName(statsInfo.specID)
      if specName and info.spec ~= specName then
        info.spec = specName
        changed = true
      end
    end
    if not info._localIlvlFresh and statsInfo.ilvl and info.ilvl ~= statsInfo.ilvl then
      info.ilvl = statsInfo.ilvl
      changed = true
    end
    if not info._localRioFresh and statsInfo.rio ~= nil and info.rio ~= statsInfo.rio then
      info.rio = statsInfo.rio
      changed = true
    end
  end

  return changed
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
      if type(sync.SetPlayerStatsInfo) == "function" then
        sync.SetPlayerStatsInfo(info.name, info.realm, nil, nil, nil)
      end
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
  local getUnitRio = opts.getUnitRio or function(_unit)
    return nil
  end
  local isFrameVisible = opts.isFrameVisible or function()
    return false
  end

  assert(type(sync.MarkUser) == "function", "isiLive: KeySync requires sync.MarkUser")
  assert(type(sync.IsUnitKnown) == "function", "isiLive: KeySync requires sync.IsUnitKnown")
  assert(type(sync.RegisterPrefix) == "function", "isiLive: KeySync requires sync.RegisterPrefix")
  assert(type(sync.SendHello) == "function", "isiLive: KeySync requires sync.SendHello")
  assert(type(sync.SendKey) == "function", "isiLive: KeySync requires sync.SendKey")
  assert(type(sync.SendStats) == "function", "isiLive: KeySync requires sync.SendStats")
  assert(type(sync.GetPlayerKeyInfo) == "function", "isiLive: KeySync requires sync.GetPlayerKeyInfo")
  assert(type(sync.GetPlayerStatsInfo) == "function", "isiLive: KeySync requires sync.GetPlayerStatsInfo")
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
    SendOwnKeySnapshot(sync, isFrameVisible, getUnitRio, force)
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
