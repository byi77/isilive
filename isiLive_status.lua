local _, addonTable = ...

addonTable = addonTable or {}

local Status = {}
addonTable.Status = Status

function Status.CreateController(opts)
  opts = opts or {}
  local getL = opts.getL or function()
    return {}
  end
  local showCenterNotice =
    opts.showCenterNotice or function(_message, _durationSeconds, _dungeonName, _activityID, _showOptions) end
  local hideCenterNotice =
    opts.hideCenterNotice or function() end
  local isPlayerLeader = opts.isPlayerLeader or function()
    return false
  end

  local wasInDungeon = nil
  local nonMythicNoticeToken = 0

  local controller = {}

  function controller.GetAddonStateText(flags)
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

  function controller.GetDungeonDifficultyLabel()
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
    if difficultyID == 8 then
      return L.DUNGEON_DIFF_MYTHIC, true, true
    end
    if difficultyID == 23 then
      return L.DUNGEON_DIFF_MYTHIC, true, true
    end
    if difficultyID == 24 then
      return L.DUNGEON_DIFF_MYTHIC, true, true
    end
    if difficultyID == 167 then
      return L.DUNGEON_DIFF_MYTHIC, true, true
    end

    return L.DUNGEON_DIFF_UNKNOWN, false, true
  end

  function controller.MaybeShowNonMythicDungeonEntryNotice()
    local L = getL()
    local _, _, inDungeon = controller.GetDungeonDifficultyLabel()

    if wasInDungeon == nil then
      wasInDungeon = inDungeon
      return
    end

    if not inDungeon then
      nonMythicNoticeToken = nonMythicNoticeToken + 1
      hideCenterNotice()
    end

    local enteredDungeon = inDungeon and not wasInDungeon
    if enteredDungeon then
      nonMythicNoticeToken = nonMythicNoticeToken + 1
      local token = nonMythicNoticeToken

      local function ConfirmAndShowNotice()
        if token ~= nonMythicNoticeToken then
          return
        end
        local confirmedText, confirmedMythic, confirmedInDungeon = controller.GetDungeonDifficultyLabel()
        if not confirmedInDungeon or confirmedMythic then
          return
        end
        if confirmedText == L.DUNGEON_DIFF_UNKNOWN then
          return
        end
        showCenterNotice(string.format(L.NON_MYTHIC_ENTERED, confirmedText), 120, nil, nil, {
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

    wasInDungeon = inDungeon
  end

  function controller.BuildStatusLineText(flags)
    local L = getL()
    local leadText = isPlayerLeader() and L.STATUS_LEAD_YES or L.STATUS_LEAD_NO
    local mplusText = C_ChallengeMode.GetActiveChallengeMapID() and L.STATUS_MPLUS_YES or L.STATUS_MPLUS_NO
    local stateText = controller.GetAddonStateText(flags)
    local difficultyText = select(1, controller.GetDungeonDifficultyLabel())
    return leadText
      .. " | "
      .. mplusText
      .. " | "
      .. stateText
      .. " | "
      .. string.format(L.DUNGEON_DIFF_TEXT, difficultyText)
  end

  return controller
end
