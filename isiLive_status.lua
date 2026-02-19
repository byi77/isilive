local _, addonTable = ...

addonTable = addonTable or {}

local Status = {}
addonTable.Status = Status

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

local function GetDungeonDifficultyLabel(getL)
  local L = getL()
  local _, instanceType, difficultyID = GetInstanceInfo()
  if instanceType ~= "party" then
    return L.DUNGEON_DIFF_OUTSIDE, false, false
  end

  if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID() then
    return L.DUNGEON_DIFF_MYTHIC, true, true
  end

  if difficultyID == 1 then
    return L.DUNGEON_DIFF_NORMAL, false, true
  end
  if difficultyID == 2 then
    return L.DUNGEON_DIFF_HEROIC, false, true
  end
  if difficultyID == 8 or difficultyID == 23 or difficultyID == 24 or difficultyID == 167 then
    return L.DUNGEON_DIFF_MYTHIC, true, true
  end

  return L.DUNGEON_DIFF_UNKNOWN, false, true
end

local function MaybeShowNonMythicDungeonEntryNotice(state, deps)
  local L = deps.getL()
  local _, _, inDungeon = GetDungeonDifficultyLabel(deps.getL)

  if state.wasInDungeon == nil then
    state.wasInDungeon = inDungeon
    return
  end

  if not inDungeon then
    state.nonMythicNoticeToken = state.nonMythicNoticeToken + 1
    deps.hideCenterNotice()
  end

  local enteredDungeon = inDungeon and not state.wasInDungeon
  if enteredDungeon then
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
end

local function BuildStatusLineText(deps, flags)
  local L = deps.getL()
  local leadText = deps.isPlayerLeader() and L.STATUS_LEAD_YES or L.STATUS_LEAD_NO
  local mplusText = C_ChallengeMode.GetActiveChallengeMapID() and L.STATUS_MPLUS_YES or L.STATUS_MPLUS_NO
  local stateText = GetAddonStateText(deps.getL, flags)
  local difficultyText = select(1, GetDungeonDifficultyLabel(deps.getL))
  return leadText
    .. " | "
    .. mplusText
    .. " | "
    .. stateText
    .. " | "
    .. string.format(L.DUNGEON_DIFF_TEXT, difficultyText)
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
  }

  local state = {
    wasInDungeon = nil,
    nonMythicNoticeToken = 0,
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
