local _, addonTable = ...

addonTable = addonTable or {}

local Status = {}
addonTable.Status = Status

local MYTHIC_DIFFICULTY_IDS = {
  [8] = true,
  [23] = true,
  [24] = true,
  [167] = true,
}

local HEROIC_DIFFICULTY_IDS = {
  [2] = true,
  [174] = true,
}

local function BuildDungeonContextSignature(instanceType, difficultyID, instanceName, isMythic)
  if instanceType ~= "party" then
    return nil
  end

  return table.concat({
    tostring(instanceName or ""),
    tostring(difficultyID or ""),
    tostring(isMythic and 1 or 0),
  }, "|")
end

local PORTAL_NAVIGATOR_ZONE_NAMES = {
  jahrhunderschwelle = true,
  ["die jahrhunderschwelle"] = true,
  ["millennia's threshold"] = true,
  timeways = true,
  ["the timeways"] = true,
}

local PORTAL_NAVIGATOR_MAP_IDS = {
  [2266] = true,
}

local function NormalizeZoneText(value)
  if type(value) ~= "string" then
    return nil
  end

  local normalized = value:gsub("^%s+", ""):gsub("%s+$", "")
  if normalized == "" then
    return nil
  end
  return string.lower(normalized)
end

local function SafeCallTextProvider(provider)
  if type(provider) ~= "function" then
    return nil
  end

  local ok, text = pcall(provider)
  if not ok then
    return nil
  end
  return text
end

local function SafeCallNumberProvider(provider)
  if type(provider) ~= "function" then
    return nil
  end

  local ok, value = pcall(provider)
  if not ok then
    return nil
  end

  local numericValue = tonumber(value)
  if not numericValue or numericValue <= 0 then
    return nil
  end
  return math.floor(numericValue)
end

local function ResolvePortalNavigatorZoneSignature(deps)
  local playerMapID = SafeCallNumberProvider(deps.getPlayerMapID)
  if playerMapID and PORTAL_NAVIGATOR_MAP_IDS[playerMapID] then
    return "map:" .. tostring(playerMapID), true
  end

  local mapInfoName = nil
  if playerMapID then
    mapInfoName = SafeCallTextProvider(function()
      return deps.getMapInfoName(playerMapID)
    end)
  end

  local zoneText = SafeCallTextProvider(deps.getZoneText)
  local subZoneText = SafeCallTextProvider(deps.getSubZoneText)
  local realZoneText = SafeCallTextProvider(deps.getRealZoneText)
  local sawZoneText = false

  local candidates = {}
  if type(mapInfoName) == "string" then
    local normalizedMapInfoName = NormalizeZoneText(mapInfoName)
    if normalizedMapInfoName then
      sawZoneText = true
      table.insert(candidates, normalizedMapInfoName)
    end
  end
  if type(zoneText) == "string" then
    local normalizedZoneText = NormalizeZoneText(zoneText)
    if normalizedZoneText then
      sawZoneText = true
      table.insert(candidates, normalizedZoneText)
    end
  end
  if type(subZoneText) == "string" then
    local normalizedSubZoneText = NormalizeZoneText(subZoneText)
    if normalizedSubZoneText then
      sawZoneText = true
      table.insert(candidates, normalizedSubZoneText)
    end
  end
  if type(realZoneText) == "string" and realZoneText ~= subZoneText then
    local normalizedRealZoneText = NormalizeZoneText(realZoneText)
    if normalizedRealZoneText then
      sawZoneText = true
      table.insert(candidates, normalizedRealZoneText)
    end
  end

  for _, candidateZoneText in ipairs(candidates) do
    if PORTAL_NAVIGATOR_ZONE_NAMES[candidateZoneText] then
      return candidateZoneText, true
    end
  end

  return nil, sawZoneText
end

local function BuildPortalNavigatorLayout(deps)
  local L = deps.getL()
  local title = L.PORTAL_NAVIGATOR_TITLE
  if type(title) ~= "string" or title == "" then
    return nil
  end
  local entries = {
    {
      slot = "half_left",
      direction = L.PORTAL_NAVIGATOR_HALF_LEFT,
      destination = L.PORTAL_NAVIGATOR_PIT_OF_SARON,
    },
    {
      slot = "left",
      direction = L.PORTAL_NAVIGATOR_LEFT,
      destination = L.PORTAL_NAVIGATOR_SKYREACH,
    },
    {
      slot = "right",
      direction = L.PORTAL_NAVIGATOR_RIGHT,
      destination = L.PORTAL_NAVIGATOR_TRIUMVIRATE,
    },
    {
      slot = "half_right",
      direction = L.PORTAL_NAVIGATOR_HALF_RIGHT,
      destination = L.PORTAL_NAVIGATOR_ALGETHAR,
    },
  }

  for _, entry in ipairs(entries) do
    if type(entry.direction) ~= "string" or entry.direction == "" then
      return nil
    end
    if type(entry.destination) ~= "string" or entry.destination == "" then
      return nil
    end
  end

  return {
    title = title,
    entries = entries,
  }
end

local function GetAddonStateText(getL, flags)
  flags = flags or {}
  local L = getL()
  if flags.isStopped then
    return L.STATUS_STATE_STOPPED
  end
  if flags.isPaused then
    return L.STATUS_STATE_PAUSED
  end
  if flags.isTestMode then
    return L.STATUS_STATE_TEST
  end
  return L.STATUS_STATE_RUNNING
end

local function BuildTargetDungeonText(deps)
  local L = deps.getL()
  local template = L.STATUS_TARGET_DUNGEON_TEXT or "Target Dungeon: %s"
  local emptyText = L.STATUS_TARGET_DUNGEON_NONE or string.format(template, "-")

  local info = deps.getTargetDungeonInfo and deps.getTargetDungeonInfo() or nil
  if type(info) ~= "table" then
    if type(deps.hasActiveDungeons) == "function" and deps.hasActiveDungeons() == false then
      local seasonLabel = type(deps.getActiveSeasonLabel) == "function" and deps.getActiveSeasonLabel() or nil
      if type(seasonLabel) == "string" and seasonLabel ~= "" then
        local preSeasonTemplate = L.STATUS_TARGET_DUNGEON_PRESEASON or template
        return string.format(preSeasonTemplate, seasonLabel)
      end
    end
    return emptyText
  end

  local name = tostring(info.name or "")
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then
    return emptyText
  end

  local level = tonumber(info.level)
  local targetText = name
  if level and level > 0 then
    targetText = string.format("%s +%d", name, level)
  end

  return string.format(template, targetText)
end

local function GetDungeonDifficultyLabel(getL)
  local L = getL()
  local instanceName, instanceType, difficultyID = GetInstanceInfo()
  if instanceType ~= "party" then
    return L.DUNGEON_DIFF_OUTSIDE, false, false, instanceType, difficultyID, instanceName
  end

  if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID() then
    return L.DUNGEON_DIFF_MYTHIC, true, true, instanceType, difficultyID, instanceName
  end

  if difficultyID == 1 then
    return L.DUNGEON_DIFF_NORMAL, false, true, instanceType, difficultyID, instanceName
  end
  if HEROIC_DIFFICULTY_IDS[difficultyID] then
    return L.DUNGEON_DIFF_HEROIC, false, true, instanceType, difficultyID, instanceName
  end
  if MYTHIC_DIFFICULTY_IDS[difficultyID] then
    return L.DUNGEON_DIFF_MYTHIC, true, true, instanceType, difficultyID, instanceName
  end

  return L.DUNGEON_DIFF_UNKNOWN, false, true, instanceType, difficultyID, instanceName
end

local function MaybeShowNonMythicDungeonEntryNotice(state, deps)
  local L = deps.getL()
  local isMythic, inDungeon, instanceType, difficultyID, instanceName = select(2, GetDungeonDifficultyLabel(deps.getL))
  local dungeonContextSignature = BuildDungeonContextSignature(instanceType, difficultyID, instanceName, isMythic)

  if state.wasInDungeon == nil then
    state.wasInDungeon = inDungeon
    state.lastDungeonContextSignature = dungeonContextSignature
    return
  end

  if not inDungeon then
    state.nonMythicNoticeToken = state.nonMythicNoticeToken + 1
    state.lastAnnouncedNonMythicSignature = nil
    deps.hideCenterNotice()
  end

  local contextChanged = inDungeon and dungeonContextSignature ~= state.lastDungeonContextSignature
  local enteredDungeon = inDungeon and not state.wasInDungeon
  if enteredDungeon or contextChanged then
    state.nonMythicNoticeToken = state.nonMythicNoticeToken + 1
    local token = state.nonMythicNoticeToken

    local function ConfirmAndShowNotice()
      if token ~= state.nonMythicNoticeToken then
        return
      end
      -- GetDungeonDifficultyLabel einmal aufrufen und alle 6 Rückgabewerte entpacken.
      local cText, cMythic, cInDungeon, cInstanceType, cDifficultyID, cInstanceName =
        GetDungeonDifficultyLabel(deps.getL)
      if not cInDungeon or cMythic then
        return
      end
      if cText == L.DUNGEON_DIFF_UNKNOWN then
        return
      end
      local confirmedSignature = BuildDungeonContextSignature(cInstanceType, cDifficultyID, cInstanceName, cMythic)
      if confirmedSignature == state.lastAnnouncedNonMythicSignature then
        return
      end
      state.lastAnnouncedNonMythicSignature = confirmedSignature
      deps.showCenterNotice(string.format(L.NON_MYTHIC_ENTERED, cText), 120, nil, nil, {
        blink = true,
        fontScale = 1.35,
        textColor = { 1, 0.2, 0.2 },
      })
    end

    if C_Timer and C_Timer.After then
      C_Timer.After(3, function()
        pcall(ConfirmAndShowNotice)
      end)
    else
      ConfirmAndShowNotice()
    end
  end

  state.wasInDungeon = inDungeon
  state.lastDungeonContextSignature = dungeonContextSignature
end

local function MaybeShowPortalNavigatorNotice(state, deps)
  if type(deps.isPortalNavigatorEnabled) == "function" and deps.isPortalNavigatorEnabled() == false then
    state.portalNavigatorRetryToken = (state.portalNavigatorRetryToken or 0) + 1
    state.portalNavigatorRetryScheduledToken = nil
    if state.wasInPortalRoom == true or state.lastPortalNavigatorSignature ~= nil then
      deps.hidePortalNavigatorNotice()
    end
    state.wasInPortalRoom = false
    state.lastPortalNavigatorSignature = nil
    return
  end

  local zoneSignature, hasZoneText = ResolvePortalNavigatorZoneSignature(deps)
  if hasZoneText ~= true then
    if type(deps.timerAfter) == "function" then
      state.portalNavigatorRetryToken = (state.portalNavigatorRetryToken or 0) + 1
      local token = state.portalNavigatorRetryToken
      if state.portalNavigatorRetryScheduledToken ~= token then
        state.portalNavigatorRetryScheduledToken = token
        deps.timerAfter(1, function()
          if state.portalNavigatorRetryScheduledToken ~= token then
            return
          end
          state.portalNavigatorRetryScheduledToken = nil
          MaybeShowPortalNavigatorNotice(state, deps)
        end)
      end
    end
    return
  end
  local inPortalRoom = zoneSignature ~= nil

  if state.wasInPortalRoom == nil then
    state.wasInPortalRoom = inPortalRoom
    state.lastPortalNavigatorSignature = zoneSignature
    if inPortalRoom then
      local layout = BuildPortalNavigatorLayout(deps)
      if layout then
        deps.showPortalNavigatorNotice(layout)
      end
    end
    return
  end

  if not inPortalRoom then
    if state.wasInPortalRoom then
      deps.hidePortalNavigatorNotice()
    end
    state.wasInPortalRoom = false
    state.lastPortalNavigatorSignature = nil
    return
  end

  if (not state.wasInPortalRoom) or state.lastPortalNavigatorSignature ~= zoneSignature then
    local layout = BuildPortalNavigatorLayout(deps)
    if layout then
      deps.showPortalNavigatorNotice(layout)
    end
    state.lastPortalNavigatorSignature = zoneSignature
  end

  state.wasInPortalRoom = true
end

local function BuildStatusLineText(deps, flags)
  local L = deps.getL()
  local leadText = deps.isPlayerLeader() and L.STATUS_LEAD_YES or L.STATUS_LEAD_NO
  local hasActiveChallenge = false
  if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
    hasActiveChallenge = C_ChallengeMode.GetActiveChallengeMapID() and true or false
  end
  local mplusText = hasActiveChallenge and L.STATUS_MPLUS_YES or L.STATUS_MPLUS_NO
  local targetDungeonText = BuildTargetDungeonText(deps)
  local stateText = GetAddonStateText(deps.getL, flags)
  local difficultyText = select(1, GetDungeonDifficultyLabel(deps.getL))
  return leadText
    .. " | "
    .. mplusText
    .. " | "
    .. stateText
    .. " | "
    .. string.format(L.DUNGEON_DIFF_TEXT, difficultyText)
    .. "\n"
    .. targetDungeonText
end

function Status.CreateController(opts)
  opts = opts or {}
  local deps = {
    getL = opts.getL or function()
      return {}
    end,
    getSubZoneText = opts.getSubZoneText or function()
      local getSubZoneText = rawget(_G, "GetSubZoneText")
      if type(getSubZoneText) ~= "function" then
        return nil
      end
      local ok, text = pcall(getSubZoneText)
      if not ok then
        return nil
      end
      return text
    end,
    getZoneText = opts.getZoneText or function()
      local getZoneText = rawget(_G, "GetZoneText")
      if type(getZoneText) ~= "function" then
        return nil
      end
      local ok, text = pcall(getZoneText)
      if not ok then
        return nil
      end
      return text
    end,
    getPlayerMapID = opts.getPlayerMapID or function()
      local mapApi = rawget(_G, "C_Map")
      local getBestMapForUnit = mapApi and rawget(mapApi, "GetBestMapForUnit")
      if type(getBestMapForUnit) ~= "function" then
        return nil
      end
      local ok, mapID = pcall(getBestMapForUnit, "player")
      mapID = ok and tonumber(mapID) or nil
      if not mapID or mapID <= 0 then
        return nil
      end
      return math.floor(mapID)
    end,
    getMapInfoName = opts.getMapInfoName or function(mapID)
      local numericMapID = tonumber(mapID)
      if not numericMapID or numericMapID <= 0 then
        return nil
      end
      local mapApi = rawget(_G, "C_Map")
      local getMapInfo = mapApi and rawget(mapApi, "GetMapInfo")
      if type(getMapInfo) ~= "function" then
        return nil
      end
      local ok, mapInfo = pcall(getMapInfo, numericMapID)
      if not ok or type(mapInfo) ~= "table" then
        return nil
      end
      if type(mapInfo.name) ~= "string" then
        return nil
      end
      return mapInfo.name
    end,
    getRealZoneText = opts.getRealZoneText or function()
      local getRealZoneText = rawget(_G, "GetRealZoneText")
      if type(getRealZoneText) ~= "function" then
        return nil
      end
      local ok, text = pcall(getRealZoneText)
      if not ok then
        return nil
      end
      return text
    end,
    showCenterNotice = opts.showCenterNotice
      or function(_message, _durationSeconds, _dungeonName, _activityID, _showOptions) end,
    hideCenterNotice = opts.hideCenterNotice or function() end,
    showPortalNavigatorNotice = opts.showPortalNavigatorNotice or function(_message) end,
    hidePortalNavigatorNotice = opts.hidePortalNavigatorNotice or function() end,
    isPortalNavigatorEnabled = opts.isPortalNavigatorEnabled or function()
      return true
    end,
    timerAfter = opts.timerAfter or function(_seconds, _callback) end,
    isPlayerLeader = opts.isPlayerLeader or function()
      return false
    end,
    getTargetDungeonInfo = opts.getTargetDungeonInfo or function()
      return nil
    end,
    hasActiveDungeons = opts.hasActiveDungeons or function()
      return true
    end,
    getActiveSeasonLabel = opts.getActiveSeasonLabel or function()
      return nil
    end,
  }

  local state = {
    wasInDungeon = nil,
    nonMythicNoticeToken = 0,
    lastDungeonContextSignature = nil,
    lastAnnouncedNonMythicSignature = nil,
    wasInPortalRoom = nil,
    lastPortalNavigatorSignature = nil,
    portalNavigatorRetryToken = 0,
    portalNavigatorRetryScheduledToken = nil,
  }

  local controller = {}

  function controller.GetAddonStateText(flags)
    return GetAddonStateText(deps.getL, flags)
  end

  function controller.GetDungeonDifficultyLabel()
    return GetDungeonDifficultyLabel(deps.getL)
  end

  function controller.MaybeShowNonMythicDungeonEntryNotice()
    return MaybeShowNonMythicDungeonEntryNotice(state, deps)
  end

  function controller.MaybeShowPortalNavigatorNotice()
    return MaybeShowPortalNavigatorNotice(state, deps)
  end

  function controller.BuildStatusLineText(flags)
    return BuildStatusLineText(deps, flags)
  end

  return controller
end
