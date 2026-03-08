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
      local confirmedText, confirmedMythic, confirmedInDungeon = GetDungeonDifficultyLabel(deps.getL)
      if not confirmedInDungeon or confirmedMythic then
        return
      end
      if confirmedText == L.DUNGEON_DIFF_UNKNOWN then
        return
      end
      local _, _, _, confirmedInstanceType, confirmedDifficultyID, confirmedInstanceName =
        GetDungeonDifficultyLabel(deps.getL)
      local confirmedSignature = BuildDungeonContextSignature(
        confirmedInstanceType,
        confirmedDifficultyID,
        confirmedInstanceName,
        confirmedMythic
      )
      if confirmedSignature == state.lastAnnouncedNonMythicSignature then
        return
      end
      state.lastAnnouncedNonMythicSignature = confirmedSignature
      deps.showCenterNotice(string.format(L.NON_MYTHIC_ENTERED, confirmedText), 120, nil, nil, {
        blink = true,
        fontScale = 1.35,
        textColor = { 1, 0.2, 0.2 },
      })
    end

    if C_Timer and C_Timer.After then
      C_Timer.After(3, ConfirmAndShowNotice)
    else
      ConfirmAndShowNotice()
    end
  end

  state.wasInDungeon = inDungeon
  state.lastDungeonContextSignature = dungeonContextSignature
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
    .. " | "
    .. targetDungeonText
end

function Status.CreateController(opts)
  opts = opts or {}
  local deps = {
    getL = opts.getL or function()
      return {}
    end,
    showCenterNotice = opts.showCenterNotice
      or function(_message, _durationSeconds, _dungeonName, _activityID, _showOptions) end,
    hideCenterNotice = opts.hideCenterNotice or function() end,
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

  function controller.BuildStatusLineText(flags)
    return BuildStatusLineText(deps, flags)
  end

  return controller
end
