local _, addonTable = ...

addonTable = addonTable or {}

local Queue = {}
addonTable.Queue = Queue

local function IsSecretValue(value)
  return issecretvalue and issecretvalue(value) == true
end

local queueDebugEnabled = false
local queueDebugLogger
local lastApplySignature
local lastApplyAt = 0

local function DebugLog(fmt, ...)
  if not queueDebugEnabled then
    return
  end

  local msg = tostring(fmt or "")
  if select("#", ...) > 0 then
    msg = string.format(msg, ...)
  end

  if queueDebugLogger then
    queueDebugLogger("[QDBG] " .. msg)
  else
    print("isiLive: [QDBG] " .. msg)
  end
end

function Queue.SetDebugEnabled(enabled)
  queueDebugEnabled = enabled and true or false
  DebugLog("queue debug enabled")
end

function Queue.IsDebugEnabled()
  return queueDebugEnabled
end

function Queue.SetDebugLogger(logger)
  if type(logger) == "function" then
    queueDebugLogger = logger
  else
    queueDebugLogger = nil
  end
end

function Queue.GetActivityName(activityID)
  if not activityID or not (C_LFGList and C_LFGList.GetActivityInfoTable) then
    return nil
  end

  local info = C_LFGList.GetActivityInfoTable(activityID)
  if info then
    return rawget(info, "fullName") or rawget(info, "shortName") or rawget(info, "activityName")
  end

  return nil
end

function Queue.GetSearchResultActivityID(result, resolveTeleportSpellIDByActivityID)
  if not result then
    return nil
  end

  local candidateIDs = {}
  local seen = {}
  local function AddCandidate(id)
    if IsSecretValue(id) then
      return
    end
    if type(id) ~= "number" or id <= 0 then
      return
    end
    if seen[id] then
      return
    end
    seen[id] = true
    table.insert(candidateIDs, id)
  end

  AddCandidate(result.activityID)

  if type(result.activityIDs) == "table" then
    for _, id in pairs(result.activityIDs) do
      AddCandidate(id)
    end
  end

  for _, id in ipairs(candidateIDs) do
    if resolveTeleportSpellIDByActivityID and resolveTeleportSpellIDByActivityID(id) then
      return id
    end
  end

  if #candidateIDs > 0 then
    return candidateIDs[1]
  end

  return nil
end

function Queue.ParseApplicationStatus(rawStatus)
  local statusText
  local isAccepted
  local isInviteLike

  if type(rawStatus) == "string" then
    statusText = string.lower(rawStatus)
    isAccepted = statusText:find("accepted") ~= nil
    isInviteLike = statusText:find("invite") ~= nil or isAccepted
    return isInviteLike, isAccepted
  end

  if type(rawStatus) == "number" and Enum and Enum.LFGListApplicationStatus then
    for key, value in pairs(Enum.LFGListApplicationStatus) do
      if value == rawStatus then
        local keyText = string.lower(tostring(key))
        isAccepted = keyText:find("accepted") ~= nil
        isInviteLike = keyText:find("invite") ~= nil or isAccepted
        return isInviteLike, isAccepted
      end
    end
  end

  return false, false
end

local function IsLikelyStatusText(value)
  if type(value) ~= "string" or value == "" then
    return false
  end

  local low = string.lower(value)
  if low:find("invite") or low:find("accept") then
    return true
  end
  if low == "applied" or low == "application" then
    return true
  end
  if low:find("declin") or low:find("cancel") or low:find("failed") or low:find("timeout") then
    return true
  end

  return false
end

local function GetSearchResultInfoSafe(searchResultID)
  if not (C_LFGList and C_LFGList.GetSearchResultInfo) then
    return nil
  end
  if IsSecretValue(searchResultID) or type(searchResultID) ~= "number" or searchResultID <= 0 then
    return nil
  end

  local ok, info = pcall(C_LFGList.GetSearchResultInfo, searchResultID)
  if not ok or type(info) ~= "table" then
    return nil
  end
  return info
end

local function ResolveActivityIDFromSearchResultID(searchResultID, resolveTeleportSpellIDByActivityID)
  local searchResultInfo = GetSearchResultInfoSafe(searchResultID)
  if not searchResultInfo then
    return nil, nil
  end

  local activityID = Queue.GetSearchResultActivityID(searchResultInfo, resolveTeleportSpellIDByActivityID)
  local groupName = searchResultInfo.name or searchResultInfo.leaderName
  return activityID, groupName
end

local function ReadApplicationInfoStruct(data, resolveTeleportSpellIDByActivityID)
  local appStatus = data.applicationStatus or data.appStatus or data.status
  local pendingStatus = data.pendingStatus or data.pendingApplicationStatus
  local searchResultInfo = data.searchResultInfo or data.searchResultData or data.searchResult
  local searchResultID = data.searchResultID or data.resultID or data.listingID
  local groupName = data.name or data.groupName
  local activityID

  if type(searchResultInfo) == "table" then
    activityID = Queue.GetSearchResultActivityID(searchResultInfo, resolveTeleportSpellIDByActivityID)
    groupName = groupName or searchResultInfo.name or searchResultInfo.leaderName
  end

  if not activityID and searchResultID then
    local resolvedActivityID, resolvedGroupName =
      ResolveActivityIDFromSearchResultID(searchResultID, resolveTeleportSpellIDByActivityID)
    activityID = resolvedActivityID or activityID
    groupName = groupName or resolvedGroupName
  end

  if not activityID then
    local directActivityID = data.activityID
    if type(directActivityID) == "number" and Queue.GetActivityName(directActivityID) then
      activityID = directActivityID
    end
  end

  return appStatus, pendingStatus, groupName, activityID
end

local function ExtractApplicationSnapshot(values, resolveTeleportSpellIDByActivityID)
  local appStatus = values[2]
  local pendingStatus = values[3]
  local seededGroupName
  local seededActivityID

  if type(values[1]) == "table" and #values == 1 then
    appStatus, pendingStatus, seededGroupName, seededActivityID =
      ReadApplicationInfoStruct(values[1], resolveTeleportSpellIDByActivityID)
    DebugLog(
      "struct appInfo status=%s pending=%s group=%s activity=%s",
      tostring(appStatus),
      tostring(pendingStatus),
      tostring(seededGroupName),
      tostring(seededActivityID)
    )
  end

  local statusMatch, acceptedMatch = Queue.ParseApplicationStatus(appStatus)
  local isInviteLike = statusMatch
  local isAccepted = acceptedMatch

  local groupName = seededGroupName
  local resultActivityID = seededActivityID

  for _, value in ipairs(values) do
    local statusHit, acceptedHit = Queue.ParseApplicationStatus(value)
    if statusHit then
      isInviteLike = true
      if acceptedHit then
        isAccepted = true
      end
    end

    if type(value) == "table" and not resultActivityID then
      resultActivityID = Queue.GetSearchResultActivityID(value, resolveTeleportSpellIDByActivityID)
      if value.name and type(value.name) == "string" and value.name ~= "" and not groupName then
        groupName = value.name
      elseif value.leaderName and type(value.leaderName) == "string" and value.leaderName ~= "" and not groupName then
        groupName = value.leaderName
      end
    elseif type(value) == "string" and not groupName and not IsLikelyStatusText(value) then
      groupName = value
    elseif type(value) == "number" and not resultActivityID then
      if IsSecretValue(value) then
        DebugLog("skip secret numeric application value")
      else
        -- Raw numeric tuple values are usually app/search IDs.
        -- Treating them as activity IDs causes false dungeon matches.
        local resolvedActivityID, resolvedGroupName =
          ResolveActivityIDFromSearchResultID(value, resolveTeleportSpellIDByActivityID)
        if resolvedActivityID then
          resultActivityID = resolvedActivityID
          groupName = groupName or resolvedGroupName
        else
          DebugLog("ignore unresolved numeric application value=%s", tostring(value))
        end
      end
    end
  end

  if type(values[1]) == "table" and #values == 1 then
    local data = values[1]
    local statusFromFields = data.applicationStatus or data.appStatus or data.status
    local statusHit, acceptedHit = Queue.ParseApplicationStatus(statusFromFields)
    if statusHit then
      isInviteLike = true
      if acceptedHit then
        isAccepted = true
      end
    end

    if not resultActivityID and type(data.activityIDs) == "table" then
      for _, id in pairs(data.activityIDs) do
        if not IsSecretValue(id) and type(id) == "number" and Queue.GetActivityName(id) then
          resultActivityID = id
          break
        end
      end
    end

    if not groupName and type(data.searchResultInfo) == "table" then
      groupName = data.searchResultInfo.name or data.searchResultInfo.leaderName
    end
  end

  return {
    isInviteLike = isInviteLike,
    isAccepted = isAccepted,
    pendingStatus = pendingStatus,
    groupName = groupName,
    activityID = resultActivityID,
  }
end

local function ShouldSkipDuplicateApply(signature)
  local now = GetTime and GetTime() or 0
  if lastApplySignature == signature and (now - lastApplyAt) <= 0.75 then
    return true
  end
  lastApplySignature = signature
  lastApplyAt = now
  return false
end

function Queue.CaptureQueueJoinFromApplications(updatePendingQueueJoin, resolveTeleportSpellIDByActivityID)
  if not (C_LFGList and C_LFGList.GetApplications and C_LFGList.GetApplicationInfo) then
    return
  end

  local appIDs = C_LFGList.GetApplications()
  if type(appIDs) ~= "table" then
    DebugLog("applications: unexpected type=%s", type(appIDs))
    return
  end

  DebugLog("applications: count=%d", #appIDs)

  for _, appID in ipairs(appIDs) do
    local values = { C_LFGList.GetApplicationInfo(appID) }
    local snap = ExtractApplicationSnapshot(values, resolveTeleportSpellIDByActivityID)
    local status = tostring(values[2])
    local pending = tostring(values[3])
    if type(values[1]) == "table" and #values == 1 then
      local data = values[1]
      status = tostring(data.applicationStatus or data.appStatus or data.status)
      pending = tostring(data.pendingStatus or data.pendingApplicationStatus)
    end
    DebugLog(
      "app id=%s status=%s pending=%s invite=%s accepted=%s group=%s activity=%s",
      tostring(appID),
      status,
      pending,
      tostring(snap.isInviteLike),
      tostring(snap.isAccepted),
      tostring(snap.groupName),
      tostring(snap.activityID)
    )

    if snap.isInviteLike and not snap.pendingStatus then
      local dungeonName = Queue.GetActivityName(snap.activityID)
      local priority = snap.isAccepted and 2 or 1
      local signature = table.concat({
        tostring(appID),
        tostring(snap.isAccepted),
        tostring(priority),
        tostring(snap.groupName),
        tostring(snap.activityID),
      }, "|")
      local skipApply = ShouldSkipDuplicateApply(signature)
      if skipApply then
        DebugLog("skip duplicate apply app id=%s", tostring(appID))
      else
        DebugLog("apply app id=%s priority=%s dungeon=%s", tostring(appID), tostring(priority), tostring(dungeonName))
        updatePendingQueueJoin(snap.groupName, dungeonName, priority, snap.activityID)
      end
    end
  end
end

function Queue.CaptureQueueJoinCandidate(updatePendingQueueJoin, resolveTeleportSpellIDByActivityID, ...)
  local snap = ExtractApplicationSnapshot({ ... }, resolveTeleportSpellIDByActivityID)
  DebugLog(
    "event candidate invite=%s accepted=%s pending=%s group=%s activity=%s",
    tostring(snap.isInviteLike),
    tostring(snap.isAccepted),
    tostring(snap.pendingStatus),
    tostring(snap.groupName),
    tostring(snap.activityID)
  )
  if snap.isInviteLike and not snap.pendingStatus then
    local dungeonName = Queue.GetActivityName(snap.activityID)
    local priority = snap.isAccepted and 2 or 1
    local signature = table.concat({
      "event",
      tostring(snap.isAccepted),
      tostring(priority),
      tostring(snap.groupName),
      tostring(snap.activityID),
    }, "|")
    if ShouldSkipDuplicateApply(signature) then
      DebugLog("skip duplicate apply event")
    else
      DebugLog("apply event priority=%s dungeon=%s", tostring(priority), tostring(dungeonName))
      updatePendingQueueJoin(snap.groupName, dungeonName, priority, snap.activityID)
    end
  end

  Queue.CaptureQueueJoinFromApplications(updatePendingQueueJoin, resolveTeleportSpellIDByActivityID)
end
