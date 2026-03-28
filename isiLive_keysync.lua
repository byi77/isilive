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

local function ResolveAverageItemLevel()
  if C_Item and C_Item.GetAverageItemLevel then
    local avgIlvl, equippedIlvl = C_Item.GetAverageItemLevel()
    local resolved = tonumber(equippedIlvl) or tonumber(avgIlvl)
    if resolved and resolved > 0 then
      return math.floor(resolved)
    end
  elseif GetAverageItemLevel then
    local avgIlvl, equippedIlvl = GetAverageItemLevel()
    local resolved = tonumber(equippedIlvl) or tonumber(avgIlvl)
    if resolved and resolved > 0 then
      return math.floor(resolved)
    end
  end
  return nil
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

  local ilvl = ResolveAverageItemLevel()

  local rio = nil
  if type(getUnitRio) == "function" then
    local resolvedRio = tonumber(getUnitRio("player"))
    if resolvedRio then
      rio = math.max(0, math.floor(resolvedRio))
    end
  end

  return specID, ilvl, rio
end

local function SendIsiLiveHello(sync, isFrameVisible, getAddonVersionRaw, force, source)
  sync.SendHello({
    force = force and true or false,
    isVisible = isFrameVisible(),
    version = getAddonVersionRaw(),
    protocolVersion = type(sync.GetProtocolVersion) == "function" and sync.GetProtocolVersion() or nil,
    source = source,
  })
end

local function SendRefreshRequest(sync, force)
  sync.SendRefreshRequest({
    force = force and true or false,
  })
end

local function GetOwnedLocMapID()
  if not GetInstanceInfo then
    return nil
  end
  local ok, _, instanceType = pcall(GetInstanceInfo)
  if not ok or instanceType ~= "party" then
    return nil
  end
  local mapApi = rawget(_G, "C_Map")
  local getBestMapForUnit = mapApi and mapApi.GetBestMapForUnit
  if type(getBestMapForUnit) ~= "function" then
    return nil
  end
  local okMap, mapID = pcall(getBestMapForUnit, "player")
  mapID = okMap and tonumber(mapID) or nil
  if not mapID or mapID <= 0 then
    return nil
  end
  return math.floor(mapID)
end

local function SendOwnStateSnapshot(sync, isFrameVisible, getUnitRio, getPlayerLastRunDps, getUnitNameAndRealm, opts)
  opts = opts or {}

  local isVisible = isFrameVisible()
  local force = opts.force and true or false
  local source = opts.source
  local allowHidden = opts.allowHidden == true
  local onlyIfChanged = opts.onlyIfChanged == true
  local includeDps = opts.includeDps ~= false

  local mapID, level = GetOwnedKeystoneSnapshot()
  sync.SendKey({
    force = force,
    isVisible = isVisible,
    allowHidden = allowHidden,
    onlyIfChanged = onlyIfChanged,
    mapID = mapID,
    level = level,
    source = source,
  })

  local specID, ilvl, rio = GetOwnedStatsSnapshot(getUnitRio)
  sync.SendStats({
    force = force,
    isVisible = isVisible,
    allowHidden = allowHidden,
    onlyIfChanged = onlyIfChanged,
    specID = specID,
    ilvl = ilvl,
    rio = rio,
    source = source,
  })

  if includeDps then
    local dps = nil
    if type(getPlayerLastRunDps) == "function" and type(getUnitNameAndRealm) == "function" then
      local name, realm = getUnitNameAndRealm("player")
      if name then
        dps = getPlayerLastRunDps(name, realm)
      end
    end
    sync.SendDps({
      force = force,
      isVisible = isVisible,
      allowHidden = allowHidden,
      onlyIfChanged = onlyIfChanged,
      dps = dps,
      source = source,
    })
  end

  local locMapID = GetOwnedLocMapID()
  sync.SendLoc({
    force = force,
    isVisible = isVisible,
    allowHidden = allowHidden,
    onlyIfChanged = onlyIfChanged,
    mapID = locMapID,
    source = source,
  })
end

local function SendOwnKeySnapshot(
  sync,
  isFrameVisible,
  getUnitRio,
  getPlayerLastRunDps,
  getUnitNameAndRealm,
  force,
  source,
  allowHidden,
  onlyIfChanged,
  includeDps
)
  SendOwnStateSnapshot(sync, isFrameVisible, getUnitRio, getPlayerLastRunDps, getUnitNameAndRealm, {
    force = force,
    source = source,
    allowHidden = allowHidden,
    onlyIfChanged = onlyIfChanged,
    includeDps = includeDps,
  })
end

local function SendOwnBackgroundSnapshot(
  sync,
  isFrameVisible,
  getUnitRio,
  getPlayerLastRunDps,
  getUnitNameAndRealm,
  source
)
  local visible = isFrameVisible()
  SendOwnStateSnapshot(sync, isFrameVisible, getUnitRio, getPlayerLastRunDps, getUnitNameAndRealm, {
    force = false,
    source = source,
    allowHidden = not visible,
    onlyIfChanged = not visible,
    includeDps = visible,
  })
end

local function SendRefreshResponse(
  sync,
  isFrameVisible,
  getUnitRio,
  getPlayerLastRunDps,
  getUnitNameAndRealm,
  canRespondToRefreshRequest
)
  if type(canRespondToRefreshRequest) == "function" and not canRespondToRefreshRequest() then
    return false
  end

  local mapID, level = GetOwnedKeystoneSnapshot()
  sync.SendKey({
    force = true,
    isVisible = isFrameVisible(),
    allowHidden = true,
    mapID = mapID,
    level = level,
    source = "reqsync",
  })

  local specID, ilvl, rio = GetOwnedStatsSnapshot(getUnitRio)
  sync.SendStats({
    force = true,
    isVisible = isFrameVisible(),
    allowHidden = true,
    specID = specID,
    ilvl = ilvl,
    rio = rio,
    source = "reqsync",
  })

  local dps = nil
  if type(getPlayerLastRunDps) == "function" and type(getUnitNameAndRealm) == "function" then
    local name, realm = getUnitNameAndRealm("player")
    if name then
      dps = getPlayerLastRunDps(name, realm)
    end
  end
  sync.SendDps({
    force = true,
    isVisible = isFrameVisible(),
    allowHidden = true,
    dps = dps,
    source = "reqsync",
  })

  local locMapID = GetOwnedLocMapID()
  sync.SendLoc({
    force = true,
    isVisible = isFrameVisible(),
    allowHidden = true,
    mapID = locMapID,
    source = "reqsync",
  })
  return true
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

local function CanBackfillPendingInspectValue(info, currentValue)
  if type(info) ~= "table" then
    return false
  end
  if not info._refreshQueued then
    return true
  end
  return currentValue == nil
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
      if specName and CanBackfillPendingInspectValue(info, info.spec) and info.spec ~= specName then
        info.spec = specName
        changed = true
      end
    end
    if
      not info._localIlvlFresh
      and statsInfo.ilvl
      and CanBackfillPendingInspectValue(info, info.ilvl)
      and info.ilvl ~= statsInfo.ilvl
    then
      info.ilvl = statsInfo.ilvl
      changed = true
    end
    if
      not info._localRioFresh
      and statsInfo.rio ~= nil
      and CanBackfillPendingInspectValue(info, info.rio)
      and info.rio ~= statsInfo.rio
    then
      info.rio = statsInfo.rio
      changed = true
    end
  end

  local dpsInfo = sync.GetPlayerDpsInfo(info.name, info.realm)
  if type(dpsInfo) == "table" then
    if info.syncDps ~= dpsInfo.dps then
      info.syncDps = dpsInfo.dps
      changed = true
    end
  elseif info.syncDps ~= nil then
    info.syncDps = nil
    changed = true
  end

  local locInfo = sync.GetPlayerLocInfo(info.name, info.realm)
  if type(locInfo) == "table" then
    local newLocMapID = locInfo.mapID
    if info.syncLocMapID ~= newLocMapID then
      info.syncLocMapID = newLocMapID
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

  -- Nicht-Spieler-Einträge werden gecleart; der Spieler-Eintrag wird danach
  -- direkt auf den aktuellen Keystone gesetzt und braucht keinen Zwischenclear.
  for unit, info in pairs(roster) do
    if type(info) == "table" then
      info.hasIsiLive = (unit == "player")
      info.syncDps = nil
      info.syncLocMapID = nil
      if unit ~= "player" then
        info.keyMapID = nil
        info.keyLevel = nil
        sync.SetPlayerKeyInfo(info.name, info.realm, nil, nil)
      end
      if type(sync.SetPlayerStatsInfo) == "function" then
        sync.SetPlayerStatsInfo(info.name, info.realm, nil, nil, nil)
      end
      if type(sync.SetPlayerDpsInfo) == "function" then
        sync.SetPlayerDpsInfo(info.name, info.realm, nil)
      end
      if type(sync.SetPlayerLocInfo) == "function" then
        sync.SetPlayerLocInfo(info.name, info.realm, nil)
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
  local canRespondToRefreshRequest = opts.canRespondToRefreshRequest or function()
    return true
  end
  local getPlayerLastRunDps = opts.getPlayerLastRunDps or nil
  assert(type(sync.MarkUser) == "function", "isiLive: KeySync requires sync.MarkUser")
  assert(type(sync.IsUnitKnown) == "function", "isiLive: KeySync requires sync.IsUnitKnown")
  assert(type(sync.RegisterPrefix) == "function", "isiLive: KeySync requires sync.RegisterPrefix")
  assert(type(sync.SendHello) == "function", "isiLive: KeySync requires sync.SendHello")
  assert(type(sync.SendKey) == "function", "isiLive: KeySync requires sync.SendKey")
  assert(type(sync.SendStats) == "function", "isiLive: KeySync requires sync.SendStats")
  assert(type(sync.SendDps) == "function", "isiLive: KeySync requires sync.SendDps")
  assert(type(sync.SendLoc) == "function", "isiLive: KeySync requires sync.SendLoc")
  assert(type(sync.SendRefreshRequest) == "function", "isiLive: KeySync requires sync.SendRefreshRequest")
  assert(type(sync.GetPlayerKeyInfo) == "function", "isiLive: KeySync requires sync.GetPlayerKeyInfo")
  assert(type(sync.GetPlayerStatsInfo) == "function", "isiLive: KeySync requires sync.GetPlayerStatsInfo")
  assert(type(sync.GetPlayerDpsInfo) == "function", "isiLive: KeySync requires sync.GetPlayerDpsInfo")
  assert(type(sync.GetPlayerLocInfo) == "function", "isiLive: KeySync requires sync.GetPlayerLocInfo")
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

  function controller.SendIsiLiveHello(force, source)
    SendIsiLiveHello(sync, isFrameVisible, getAddonVersionRaw, force, source)
  end

  function controller.SendRefreshRequest(force)
    SendRefreshRequest(sync, force)
  end

  function controller.GetOwnedKeystoneSnapshot()
    return GetOwnedKeystoneSnapshot()
  end

  function controller.SendOwnKeySnapshot(force, source, allowHidden, onlyIfChanged, includeDps)
    SendOwnKeySnapshot(
      sync,
      isFrameVisible,
      getUnitRio,
      getPlayerLastRunDps,
      getUnitNameAndRealm,
      force,
      source,
      allowHidden,
      onlyIfChanged,
      includeDps
    )
  end

  function controller.SendOwnBackgroundSnapshot(source)
    SendOwnBackgroundSnapshot(sync, isFrameVisible, getUnitRio, getPlayerLastRunDps, getUnitNameAndRealm, source)
  end

  function controller.SendRefreshResponse()
    return SendRefreshResponse(
      sync,
      isFrameVisible,
      getUnitRio,
      getPlayerLastRunDps,
      getUnitNameAndRealm,
      canRespondToRefreshRequest
    )
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
