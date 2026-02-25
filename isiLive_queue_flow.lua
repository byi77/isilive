local _, addonTable = ...

addonTable = addonTable or {}

local QueueFlow = {}
addonTable.QueueFlow = QueueFlow

local AnnounceQueuedGroupJoin

local function BuildAnnouncementSignature(pending, groupName, dungeonName, activityID, mapID, spellID)
  local stableQueueEventID = type(pending) == "table" and pending.stableQueueEventID or nil
  if type(stableQueueEventID) == "string" and stableQueueEventID ~= "" then
    return "stable|" .. stableQueueEventID
  end

  return table.concat({
    tostring(groupName or ""),
    tostring(dungeonName or ""),
    tostring(activityID or ""),
    tostring(mapID or ""),
    tostring(spellID or ""),
  }, "|")
end

local function RequireFunction(value, name)
  assert(type(value) == "function", "isiLive: QueueFlow requires " .. name)
  return value
end

local function UpdatePendingQueueJoin(deps, groupName, dungeonName, priority, activityID, sourceInfo)
  local L = deps.getL()
  local previous = deps.getPendingQueueJoinInfo()
  local oldPriority = previous and previous.priority or 0
  if priority < oldPriority then
    return
  end

  local stableQueueEventID = nil
  if type(sourceInfo) == "table" and type(sourceInfo.stableQueueEventID) == "string" then
    if sourceInfo.stableQueueEventID ~= "" then
      stableQueueEventID = sourceInfo.stableQueueEventID
    end
  end

  local resolvedMapID = deps.resolveSeason3MapIDByActivityID(activityID)
  local resolvedTeleportSpellID = resolvedMapID and deps.resolveSeason3TeleportSpellIDByMapID(resolvedMapID) or nil
  local nextGroupName = groupName or nil

  local isDuplicateUpdate = previous
    and previous.priority == priority
    and previous.groupName == nextGroupName
    and previous.dungeonName == dungeonName
    and previous.activityID == activityID
    and previous.mapID == resolvedMapID
    and previous.teleportSpellID == resolvedTeleportSpellID
    and previous.stableQueueEventID == stableQueueEventID
  if isDuplicateUpdate then
    return
  end

  local pending = {
    groupName = nextGroupName,
    dungeonName = dungeonName,
    activityID = activityID,
    mapID = resolvedMapID,
    teleportSpellID = resolvedTeleportSpellID,
    priority = priority,
    stableQueueEventID = stableQueueEventID,
    capturedAt = deps.getTimeFn(),
  }
  deps.setPendingQueueJoinInfo(pending)

  local groupText = string.format(L.INVITE_HINT_GROUP, pending.groupName or L.UNKNOWN_GROUP)
  local dungeonText = pending.dungeonName and string.format(L.INVITE_HINT_DUNGEON, pending.dungeonName)
    or L.INVITE_HINT_UNKNOWN_DUNGEON
  deps.showInviteHint(groupText .. "\n" .. dungeonText, 10)
  deps.updateMPlusTeleportButton()
end

local function CaptureQueueJoinCandidate(deps, ...)
  if deps.isInChallengeMode() then
    return
  end

  local function strictResolver(activityID)
    local ok, mapID = pcall(deps.resolveSeason3MapIDByActivityID, activityID)
    if not ok then
      return nil
    end
    if type(mapID) ~= "number" or mapID <= 0 then
      return nil
    end

    return {
      mapID = mapID,
      spellID = deps.resolveSeason3TeleportSpellIDByMapID(mapID),
    }
  end

  deps.queueCaptureQueueJoinCandidate(function(...)
    return UpdatePendingQueueJoin(deps, ...)
  end, strictResolver, ...)

  -- Race guard: GROUP_ROSTER_UPDATE can happen before the final LFG payload.
  -- If a valid candidate arrives while already grouped, announce immediately.
  if deps.isInGroup() then
    AnnounceQueuedGroupJoin(deps)
  end
end

local function ShowQueueJoinPreview(deps, groupName, dungeonName, activityID)
  local L = deps.getL()
  local group = groupName or L.UNKNOWN_GROUP
  local dungeon = dungeonName
  local mapID = deps.resolveSeason3MapIDByActivityID(activityID)
  local spellID = mapID and deps.resolveSeason3TeleportSpellIDByMapID(mapID) or nil
  local joinedKeyMapID = deps.resolveJoinedKeyMapID(activityID, nil)

  deps.setQueueTargetState(dungeon, activityID, spellID, joinedKeyMapID, mapID)
  deps.updateMPlusTeleportButton()
  deps.updateUI()

  local msg
  if dungeon and dungeon ~= "" then
    msg = string.format(L.JOINED_FROM_QUEUE_DUNGEON, group, dungeon)
  else
    msg = string.format(L.JOINED_FROM_QUEUE, group)
  end

  local separator = "|cffffffff----------------------------------------|r"
  deps.printFn(separator)
  deps.printFn("|cffffffff" .. L.CHAT_QUEUE_PREFIX .. " | " .. msg .. "|r")
  deps.printFn(separator)
  deps.showInviteHint(
    string.format(L.INVITE_HINT_GROUP, group)
      .. "\n"
      .. (dungeon and string.format(L.INVITE_HINT_DUNGEON, dungeon) or L.INVITE_HINT_UNKNOWN_DUNGEON),
    10
  )
end

AnnounceQueuedGroupJoin = function(deps)
  local L = deps.getL()
  local pending = deps.getPendingQueueJoinInfo()
  if not pending then
    return
  end

  if deps.isPlayerLeader() then
    deps.setPendingQueueJoinInfo(nil)
    return
  end

  local groupName = pending.groupName or L.UNKNOWN_GROUP
  local dungeonName = pending.dungeonName
  local activityID = pending.activityID
  local mapID = pending.mapID or deps.resolveSeason3MapIDByActivityID(activityID)
  local spellID = pending.teleportSpellID or (mapID and deps.resolveSeason3TeleportSpellIDByMapID(mapID) or nil)
  local signature = BuildAnnouncementSignature(pending, groupName, dungeonName, activityID, mapID, spellID)
  local now = deps.getTimeFn()

  if
    deps.lastAnnouncementSignature == signature
    and (now - deps.lastAnnouncementAt) <= deps.announcementDedupWindowSeconds
  then
    deps.setPendingQueueJoinInfo(nil)
    return
  end

  deps.lastAnnouncementSignature = signature
  deps.lastAnnouncementAt = now
  ShowQueueJoinPreview(deps, groupName, dungeonName, activityID)
  deps.setPendingQueueJoinInfo(nil)
end

function QueueFlow.CreateController(opts)
  opts = opts or {}

  local deps = {
    getL = RequireFunction(opts.getL, "getL"),
    getPendingQueueJoinInfo = RequireFunction(opts.getPendingQueueJoinInfo, "getPendingQueueJoinInfo"),
    setPendingQueueJoinInfo = RequireFunction(opts.setPendingQueueJoinInfo, "setPendingQueueJoinInfo"),
    resolveSeason3MapIDByActivityID = RequireFunction(
      opts.resolveSeason3MapIDByActivityID,
      "resolveSeason3MapIDByActivityID"
    ),
    resolveSeason3TeleportSpellIDByMapID = RequireFunction(
      opts.resolveSeason3TeleportSpellIDByMapID,
      "resolveSeason3TeleportSpellIDByMapID"
    ),
    resolveJoinedKeyMapID = RequireFunction(opts.resolveJoinedKeyMapID, "resolveJoinedKeyMapID"),
    updateMPlusTeleportButton = RequireFunction(opts.updateMPlusTeleportButton, "updateMPlusTeleportButton"),
    showInviteHint = RequireFunction(opts.showInviteHint, "showInviteHint"),
    showCenterNotice = RequireFunction(opts.showCenterNotice, "showCenterNotice"),
    updateUI = RequireFunction(opts.updateUI, "updateUI"),
    printFn = opts.printFn or print,
    setQueueTargetState = RequireFunction(opts.setQueueTargetState, "setQueueTargetState"),
    queueCaptureQueueJoinCandidate = RequireFunction(
      opts.queueCaptureQueueJoinCandidate,
      "queueCaptureQueueJoinCandidate"
    ),
    isInChallengeMode = RequireFunction(opts.isInChallengeMode, "isInChallengeMode"),
    isInGroup = RequireFunction(opts.isInGroup, "isInGroup"),
    isPlayerLeader = RequireFunction(opts.isPlayerLeader, "isPlayerLeader"),
    getTimeFn = opts.getTimeFn or GetTime,
    announcementDedupWindowSeconds = tonumber(opts.announcementDedupWindowSeconds) or 30,
    lastAnnouncementSignature = nil,
    lastAnnouncementAt = 0,
  }

  assert(type(deps.printFn) == "function", "isiLive: QueueFlow requires printFn")
  assert(type(deps.getTimeFn) == "function", "isiLive: QueueFlow requires getTimeFn")

  local controller = {}

  function controller.UpdatePendingQueueJoin(groupName, dungeonName, priority, activityID, sourceInfo)
    UpdatePendingQueueJoin(deps, groupName, dungeonName, priority, activityID, sourceInfo)
  end

  function controller.CaptureQueueJoinCandidate(...)
    CaptureQueueJoinCandidate(deps, ...)
  end

  function controller.ShowQueueJoinPreview(groupName, dungeonName, activityID)
    ShowQueueJoinPreview(deps, groupName, dungeonName, activityID)
  end

  function controller.AnnounceQueuedGroupJoin()
    AnnounceQueuedGroupJoin(deps)
  end

  return controller
end
