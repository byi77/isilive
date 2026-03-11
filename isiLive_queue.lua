local _, addonTable = ...

addonTable = addonTable or {}

local Queue = {}
addonTable.Queue = Queue

local function IsSecretValue(value)
  return _G.issecretvalue and _G.issecretvalue(value) == true
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

  local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
  if ok and type(info) == "table" then
    return rawget(info, "fullName") or rawget(info, "shortName") or rawget(info, "activityName")
  end

  return nil
end

local function HasConcreteActivityMap(activityID)
  if not activityID or not (C_LFGList and C_LFGList.GetActivityInfoTable) then
    return false
  end

  local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
  if not ok or type(info) ~= "table" then
    return false
  end

  local mapID = tonumber(rawget(info, "mapID") or rawget(info, "mapId"))
  return mapID and mapID > 0
end

local function NormalizeStableNumericID(value)
  if IsSecretValue(value) then
    return nil
  end
  if type(value) ~= "number" or value <= 0 then
    return nil
  end
  return math.floor(value)
end

local function BuildStableQueueEventID(snapshot)
  local applicationID = NormalizeStableNumericID(snapshot and snapshot.applicationID)
  if applicationID then
    return "app:" .. tostring(applicationID)
  end

  local searchResultID = NormalizeStableNumericID(snapshot and snapshot.searchResultID)
  if searchResultID then
    return "search:" .. tostring(searchResultID)
  end

  local listingID = NormalizeStableNumericID(snapshot and snapshot.listingID)
  if listingID then
    return "listing:" .. tostring(listingID)
  end

  return nil
end

local function AddUniqueActivityCandidate(candidateIDs, seen, id)
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

local function AddUniqueActivityCandidateList(candidateIDs, seen, ids)
  if type(ids) ~= "table" or IsSecretValue(ids) then
    return
  end

  local list = {}
  for _, id in pairs(ids) do
    if not IsSecretValue(id) and type(id) == "number" and id > 0 and not seen[id] then
      table.insert(list, id)
    end
  end
  table.sort(list)

  for _, id in ipairs(list) do
    AddUniqueActivityCandidate(candidateIDs, seen, id)
  end
end

local function RegisterByMap(storage, keyCount, mapID, activityID)
  if storage[mapID] then
    return keyCount
  end
  storage[mapID] = activityID
  return keyCount + 1
end

local function GetActivityContext(activityID)
  if not (C_LFGList and C_LFGList.GetActivityInfoTable) then
    return nil, false
  end

  local ok, activityInfo = pcall(C_LFGList.GetActivityInfoTable, activityID)
  if not ok or type(activityInfo) ~= "table" then
    return nil, false
  end

  local mapID = tonumber(rawget(activityInfo, "mapID") or rawget(activityInfo, "mapId"))
  local isDungeonLike = rawget(activityInfo, "isMythicPlusActivity") == true or rawget(activityInfo, "categoryID") == 2
  return mapID, isDungeonLike
end

local function ParseResolverResult(value)
  if type(value) == "table" then
    local mapID = tonumber(rawget(value, "mapID") or rawget(value, "mapId"))
    local spellID = tonumber(rawget(value, "spellID") or rawget(value, "spellId") or rawget(value, "teleportSpellID"))
    return mapID, spellID
  end

  if type(value) == "number" and value > 0 then
    -- Legacy callback behavior: a positive numeric result means "concrete mapped candidate".
    return nil, value
  end

  return nil, nil
end

function Queue.GetSearchResultActivityID(result, resolveTeleportSpellIDByActivityID)
  if not result then
    return nil
  end

  local candidateIDs = {}
  local seen = {}
  AddUniqueActivityCandidate(candidateIDs, seen, result.activityID)
  AddUniqueActivityCandidate(candidateIDs, seen, result.primaryActivityID)
  AddUniqueActivityCandidate(candidateIDs, seen, result.activity)

  AddUniqueActivityCandidateList(candidateIDs, seen, result.activityIDs)
  AddUniqueActivityCandidateList(candidateIDs, seen, result.activities)

  local mappedByMap = {}
  local mappedMapCount = 0
  local dungeonByMap = {}
  local dungeonMapCount = 0

  for _, id in ipairs(candidateIDs) do
    local resolveResult = nil
    if resolveTeleportSpellIDByActivityID then
      resolveResult = resolveTeleportSpellIDByActivityID(id)
    end

    local resolverMapID, resolverSpellID = ParseResolverResult(resolveResult)
    local activityMapID, isDungeonLike = GetActivityContext(id)
    local mapID = resolverMapID or activityMapID
    if type(mapID) == "number" and mapID > 0 then
      if resolverSpellID and resolverSpellID > 0 then
        mappedMapCount = RegisterByMap(mappedByMap, mappedMapCount, mapID, id)
      elseif isDungeonLike then
        dungeonMapCount = RegisterByMap(dungeonByMap, dungeonMapCount, mapID, id)
      end
    end
  end

  if mappedMapCount == 1 then
    local _, activityID = next(mappedByMap)
    return activityID
  end
  if mappedMapCount > 1 then
    return nil
  end

  if dungeonMapCount == 1 then
    local _, activityID = next(dungeonByMap)
    return activityID
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

local function GetApplicationInfoSafe(appID)
  if not (C_LFGList and C_LFGList.GetApplicationInfo) then
    return
  end
  local results = { pcall(C_LFGList.GetApplicationInfo, appID) }
  if not results[1] then
    return
  end
  return table.unpack(results, 2)
end

local function ResolveActivityIDFromSearchResultID(searchResultID, resolveTeleportSpellIDByActivityID)
  local searchResultInfo = GetSearchResultInfoSafe(searchResultID)
  if not searchResultInfo then
    return nil, nil, false
  end

  local activityID = Queue.GetSearchResultActivityID(searchResultInfo, resolveTeleportSpellIDByActivityID)
  local groupName = searchResultInfo.name or searchResultInfo.leaderName
  return activityID, groupName, true
end

local function ReadApplicationInfoStruct(data, resolveTeleportSpellIDByActivityID)
  local appStatus = data.applicationStatus or data.appStatus or data.status
  local pendingStatus = data.pendingStatus or data.pendingApplicationStatus
  local searchResultInfo = data.searchResultInfo or data.searchResultData or data.searchResult
  local searchResultID = NormalizeStableNumericID(data.searchResultID or data.resultID)
  local listingID = NormalizeStableNumericID(data.listingID)
  if not searchResultID then
    searchResultID = listingID
  end
  local applicationID = NormalizeStableNumericID(data.applicationID or data.appID or data.id)
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
    if type(directActivityID) == "number" and HasConcreteActivityMap(directActivityID) then
      activityID = directActivityID
    end
  end

  return appStatus, pendingStatus, groupName, activityID, applicationID, searchResultID, listingID
end

local function SeedSnapshotFromSingleStruct(values, resolveTeleportSpellIDByActivityID, state)
  if type(values[1]) ~= "table" or #values ~= 1 then
    return
  end

  local structAppID
  local structSearchResultID
  local structListingID
  local appStatus
  local pendingStatus
  local groupName
  local activityID
  appStatus, pendingStatus, groupName, activityID, structAppID, structSearchResultID, structListingID =
    ReadApplicationInfoStruct(values[1], resolveTeleportSpellIDByActivityID)
  state.appStatus = appStatus
  state.pendingStatus = pendingStatus
  state.groupName = groupName
  state.activityID = activityID

  if structAppID then
    state.applicationID = structAppID
  end
  if structSearchResultID then
    state.searchResultID = structSearchResultID
  end
  if structListingID then
    state.listingID = structListingID
  end

  DebugLog(
    "struct appInfo status=%s pending=%s group=%s activity=%s stableID=%s",
    tostring(state.appStatus),
    tostring(state.pendingStatus),
    tostring(state.groupName),
    tostring(state.activityID),
    tostring(BuildStableQueueEventID({
      applicationID = state.applicationID,
      searchResultID = state.searchResultID,
      listingID = state.listingID,
    }))
  )
end

local function AccumulateStatusFlags(value, state)
  local statusHit, acceptedHit = Queue.ParseApplicationStatus(value)
  if statusHit then
    state.isInviteLike = true
    if acceptedHit then
      state.isAccepted = true
    end
  end
end

local function HandleNumericApplicationValue(numericID, index, resolveTeleportSpellIDByActivityID, state)
  if not numericID then
    DebugLog("skip secret/invalid numeric application value")
    return
  end
  if state.activityID then
    return
  end

  -- Raw numeric tuple values are usually app/search IDs.
  -- Treating them as activity IDs causes false dungeon matches.
  local resolvedActivityID, resolvedGroupName, foundSearchResult =
    ResolveActivityIDFromSearchResultID(numericID, resolveTeleportSpellIDByActivityID)
  if foundSearchResult and not state.searchResultID then
    state.searchResultID = numericID
  end
  if resolvedActivityID then
    state.activityID = resolvedActivityID
    state.groupName = state.groupName or resolvedGroupName
  else
    DebugLog("ignore unresolved numeric application value=%s", tostring(numericID))
  end
  if (not foundSearchResult) and index == 1 and not state.applicationID then
    state.applicationID = numericID
  end
end

local function ScanApplicationTupleValues(values, resolveTeleportSpellIDByActivityID, state)
  for index, value in ipairs(values) do
    AccumulateStatusFlags(value, state)

    if type(value) == "table" and not state.activityID then
      state.activityID = Queue.GetSearchResultActivityID(value, resolveTeleportSpellIDByActivityID)
      if value.name and type(value.name) == "string" and value.name ~= "" and not state.groupName then
        state.groupName = value.name
      elseif
        value.leaderName
        and type(value.leaderName) == "string"
        and value.leaderName ~= ""
        and not state.groupName
      then
        state.groupName = value.leaderName
      end
    elseif type(value) == "string" and not state.groupName and not IsLikelyStatusText(value) then
      state.groupName = value
    elseif type(value) == "number" then
      HandleNumericApplicationValue(NormalizeStableNumericID(value), index, resolveTeleportSpellIDByActivityID, state)
    end
  end
end

local function ApplySingleStructFallback(values, state)
  if type(values[1]) ~= "table" or #values ~= 1 then
    return
  end

  local data = values[1]
  AccumulateStatusFlags(data.applicationStatus or data.appStatus or data.status, state)

  if not state.activityID and type(data.activityIDs) == "table" and not IsSecretValue(data.activityIDs) then
    for _, id in pairs(data.activityIDs) do
      if not IsSecretValue(id) and type(id) == "number" and HasConcreteActivityMap(id) then
        state.activityID = id
        break
      end
    end
  end

  if not state.groupName and type(data.searchResultInfo) == "table" then
    state.groupName = data.searchResultInfo.name or data.searchResultInfo.leaderName
  end
end

local function ExtractApplicationSnapshot(values, resolveTeleportSpellIDByActivityID, opts)
  opts = opts or {}
  local state = {
    appStatus = values[2],
    pendingStatus = values[3],
    groupName = nil,
    activityID = nil,
    applicationID = NormalizeStableNumericID(opts.defaultApplicationID),
    searchResultID = NormalizeStableNumericID(opts.defaultSearchResultID),
    listingID = NormalizeStableNumericID(opts.defaultListingID),
    isInviteLike = false,
    isAccepted = false,
  }

  SeedSnapshotFromSingleStruct(values, resolveTeleportSpellIDByActivityID, state)
  AccumulateStatusFlags(state.appStatus, state)
  ScanApplicationTupleValues(values, resolveTeleportSpellIDByActivityID, state)
  ApplySingleStructFallback(values, state)

  if state.pendingStatus == 0 or state.pendingStatus == "" then
    state.pendingStatus = nil
  end

  local snapshot = {
    isInviteLike = state.isInviteLike,
    isAccepted = state.isAccepted,
    pendingStatus = state.pendingStatus,
    groupName = state.groupName,
    activityID = state.activityID,
    applicationID = state.applicationID,
    searchResultID = state.searchResultID,
    listingID = state.listingID,
  }
  snapshot.stableQueueEventID = BuildStableQueueEventID(snapshot)
  return snapshot
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
    local values = { GetApplicationInfoSafe(appID) }
    if #values == 0 then
      DebugLog("skip application info failure id=%s", tostring(appID))
    else
      local snap = ExtractApplicationSnapshot(values, resolveTeleportSpellIDByActivityID, {
        defaultApplicationID = appID,
      })

      local status = tostring(values[2])
      local pending = tostring(values[3])
      DebugLog(
        "app id=%s status=%s pending=%s invite=%s accepted=%s group=%s activity=%s stableID=%s",
        tostring(appID),
        status,
        pending,
        tostring(snap.isInviteLike),
        tostring(snap.isAccepted),
        tostring(snap.groupName),
        tostring(snap.activityID),
        tostring(snap.stableQueueEventID)
      )

      if snap.isInviteLike and not snap.pendingStatus then
        local dungeonName = Queue.GetActivityName(snap.activityID)
        local priority = snap.isAccepted and 2 or 1
        local signature = table.concat({
          tostring(appID),
          tostring(snap.stableQueueEventID),
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
          updatePendingQueueJoin(snap.groupName, dungeonName, priority, snap.activityID, {
            stableQueueEventID = snap.stableQueueEventID,
            applicationID = snap.applicationID,
            searchResultID = snap.searchResultID,
            listingID = snap.listingID,
          })
        end
      end
    end
  end
end

function Queue.CaptureQueueJoinCandidate(updatePendingQueueJoin, resolveTeleportSpellIDByActivityID, ...)
  local snap = ExtractApplicationSnapshot({ ... }, resolveTeleportSpellIDByActivityID)
  DebugLog(
    "event candidate invite=%s accepted=%s pending=%s group=%s activity=%s stableID=%s",
    tostring(snap.isInviteLike),
    tostring(snap.isAccepted),
    tostring(snap.pendingStatus),
    tostring(snap.groupName),
    tostring(snap.activityID),
    tostring(snap.stableQueueEventID)
  )
  if snap.isInviteLike and not snap.pendingStatus then
    local dungeonName = Queue.GetActivityName(snap.activityID)
    local priority = snap.isAccepted and 2 or 1
    local signature = table.concat({
      "event",
      tostring(snap.stableQueueEventID),
      tostring(snap.isAccepted),
      tostring(priority),
      tostring(snap.groupName),
      tostring(snap.activityID),
    }, "|")
    if ShouldSkipDuplicateApply(signature) then
      DebugLog("skip duplicate apply event")
    else
      DebugLog("apply event priority=%s dungeon=%s", tostring(priority), tostring(dungeonName))
      updatePendingQueueJoin(snap.groupName, dungeonName, priority, snap.activityID, {
        stableQueueEventID = snap.stableQueueEventID,
        applicationID = snap.applicationID,
        searchResultID = snap.searchResultID,
        listingID = snap.listingID,
      })
    end
  end

  Queue.CaptureQueueJoinFromApplications(updatePendingQueueJoin, resolveTeleportSpellIDByActivityID)
end
