local _, addonTable = ...

addonTable = addonTable or {}

local QueueFlow = {}
addonTable.QueueFlow = QueueFlow

local function RequireFunction(value, name)
  assert(type(value) == "function", "isiLive: QueueFlow requires " .. name)
  return value
end

function QueueFlow.CreateController(opts)
  opts = opts or {}

  local getL = RequireFunction(opts.getL, "getL")
  local getPendingQueueJoinInfo = RequireFunction(opts.getPendingQueueJoinInfo, "getPendingQueueJoinInfo")
  local setPendingQueueJoinInfo = RequireFunction(opts.setPendingQueueJoinInfo, "setPendingQueueJoinInfo")
  local resolveSeason3TeleportSpellID = RequireFunction(opts.resolveSeason3TeleportSpellID, "resolveSeason3TeleportSpellID")
  local resolveSeason3TeleportSpellIDByActivityID =
    RequireFunction(opts.resolveSeason3TeleportSpellIDByActivityID, "resolveSeason3TeleportSpellIDByActivityID")
  local resolveJoinedKeyMapID = RequireFunction(opts.resolveJoinedKeyMapID, "resolveJoinedKeyMapID")
  local updateMPlusTeleportButton = RequireFunction(opts.updateMPlusTeleportButton, "updateMPlusTeleportButton")
  local showInviteHint = RequireFunction(opts.showInviteHint, "showInviteHint")
  local showCenterNotice = RequireFunction(opts.showCenterNotice, "showCenterNotice")
  local updateUI = RequireFunction(opts.updateUI, "updateUI")
  local printFn = opts.printFn or print
  local setQueueTargetState = RequireFunction(opts.setQueueTargetState, "setQueueTargetState")
  local queueCaptureQueueJoinCandidate =
    RequireFunction(opts.queueCaptureQueueJoinCandidate, "queueCaptureQueueJoinCandidate")
  local isInChallengeMode = RequireFunction(opts.isInChallengeMode, "isInChallengeMode")
  local isPlayerLeader = RequireFunction(opts.isPlayerLeader, "isPlayerLeader")
  local getTimeFn = opts.getTimeFn or GetTime

  assert(type(printFn) == "function", "isiLive: QueueFlow requires printFn")
  assert(type(getTimeFn) == "function", "isiLive: QueueFlow requires getTimeFn")

  local controller = {}

  function controller.UpdatePendingQueueJoin(groupName, dungeonName, priority, activityID)
    local L = getL()
    local previous = getPendingQueueJoinInfo()
    local oldPriority = previous and previous.priority or 0
    if priority < oldPriority then
      return
    end

    -- Only carry dungeon forward when it is clearly the same group to avoid cross-application mixups.
    if
      previous
      and previous.dungeonName
      and not dungeonName
      and groupName
      and previous.groupName
      and groupName == previous.groupName
    then
      dungeonName = previous.dungeonName
    end

    if not activityID and groupName and previous and previous.groupName and groupName == previous.groupName then
      activityID = previous.activityID
    end

    local resolvedTeleportSpellID = resolveSeason3TeleportSpellID(activityID, dungeonName)
    if not resolvedTeleportSpellID and previous then
      local sameGroup = (not groupName) or not previous.groupName or (groupName == previous.groupName)
      if sameGroup then
        dungeonName = dungeonName or previous.dungeonName
        activityID = activityID or previous.activityID
        resolvedTeleportSpellID = previous.teleportSpellID
      end
    end

    local nextGroupName = groupName or (previous and previous.groupName) or nil
    local isDuplicateUpdate = previous
      and previous.priority == priority
      and previous.groupName == nextGroupName
      and previous.dungeonName == dungeonName
      and previous.activityID == activityID
      and previous.teleportSpellID == resolvedTeleportSpellID
    if isDuplicateUpdate then
      return
    end

    local pending = {
      groupName = nextGroupName,
      dungeonName = dungeonName,
      activityID = activityID,
      teleportSpellID = resolvedTeleportSpellID,
      priority = priority,
      capturedAt = getTimeFn(),
    }
    setPendingQueueJoinInfo(pending)

    local groupText = string.format(L.INVITE_HINT_GROUP, pending.groupName or L.UNKNOWN_GROUP)
    local dungeonText = pending.dungeonName and string.format(L.INVITE_HINT_DUNGEON, pending.dungeonName)
      or L.INVITE_HINT_UNKNOWN_DUNGEON
    showInviteHint(groupText .. "\n" .. dungeonText, 10)
    updateMPlusTeleportButton()
  end

  function controller.CaptureQueueJoinCandidate(...)
    if isInChallengeMode() then
      return
    end

    local function permissiveResolver(activityID)
      local spellID = resolveSeason3TeleportSpellIDByActivityID(activityID)
      if spellID then
        return spellID
      end
      if activityID and C_LFGList and C_LFGList.GetActivityInfoTable then
        local info = C_LFGList.GetActivityInfoTable(activityID)
        if info and (info.isMythicPlusActivity or info.categoryID == 2) then
          return true -- Valid dungeon/M+ activity, capture it even without teleport spell
        end
      end
      return nil
    end

    queueCaptureQueueJoinCandidate(controller.UpdatePendingQueueJoin, permissiveResolver, ...)
  end

  function controller.ShowQueueJoinPreview(groupName, dungeonName, activityID)
    local L = getL()
    local group = groupName or L.UNKNOWN_GROUP
    local dungeon = dungeonName
    local spellID = resolveSeason3TeleportSpellID(activityID, dungeon)
    local joinedKeyMapID = resolveJoinedKeyMapID(activityID, spellID)

    setQueueTargetState(dungeon, activityID, spellID, joinedKeyMapID)
    updateMPlusTeleportButton()
    updateUI()

    local msg
    if dungeon and dungeon ~= "" then
      msg = string.format(L.JOINED_FROM_QUEUE_DUNGEON, group, dungeon)
    else
      msg = string.format(L.JOINED_FROM_QUEUE, group)
    end

    local separator = "|cffffffff----------------------------------------|r"
    printFn(separator)
    printFn("|cffffffff" .. L.CHAT_QUEUE_PREFIX .. " | " .. msg .. "|r")
    printFn(separator)
    showCenterNotice(msg, 20, dungeon, activityID)
    showInviteHint(
      string.format(L.INVITE_HINT_GROUP, group)
        .. "\n"
        .. (dungeon and string.format(L.INVITE_HINT_DUNGEON, dungeon) or L.INVITE_HINT_UNKNOWN_DUNGEON),
      10
    )
  end

  function controller.AnnounceQueuedGroupJoin()
    local L = getL()
    local pending = getPendingQueueJoinInfo()
    if not pending then
      return
    end

    if isPlayerLeader() then
      setPendingQueueJoinInfo(nil)
      return
    end

    local groupName = pending.groupName or L.UNKNOWN_GROUP
    local dungeonName = pending.dungeonName
    local activityID = pending.activityID
    controller.ShowQueueJoinPreview(groupName, dungeonName, activityID)
    setPendingQueueJoinInfo(nil)
  end

  return controller
end
