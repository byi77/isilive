local addonName, addonTable = ...

addonTable = addonTable or {}

local Queue = {}
addonTable.Queue = Queue

function Queue.GetActivityName(activityID)
    if not activityID then return nil end

    local info = C_LFGList.GetActivityInfoTable(activityID)
    if info then
        return rawget(info, "fullName") or rawget(info, "shortName") or rawget(info, "activityName")
    end

    return nil
end

function Queue.GetSearchResultActivityID(result, resolveTeleportSpellIDByActivityID)
    if not result then return nil end

    local candidateIDs = {}
    local seen = {}
    local function AddCandidate(id)
        if type(id) ~= "number" or id <= 0 then return end
        if seen[id] then return end
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
    local isAccepted = false
    local isInviteLike = false

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

function Queue.CaptureQueueJoinFromApplications(updatePendingQueueJoin, resolveTeleportSpellIDByActivityID)
    if not (C_LFGList and C_LFGList.GetApplications and C_LFGList.GetApplicationInfo and C_LFGList.GetSearchResultInfo) then
        return
    end

    local appIDs = C_LFGList.GetApplications()
    if type(appIDs) ~= "table" then return end

    for _, appID in ipairs(appIDs) do
        local values = { C_LFGList.GetApplicationInfo(appID) }
        local isAccepted = false
        local isInviteLike = false
        local searchResultID

        for _, value in ipairs(values) do
            local statusMatch, acceptedMatch = Queue.ParseApplicationStatus(value)
            if statusMatch then
                isInviteLike = true
                if acceptedMatch then
                    isAccepted = true
                end
            end

            if type(value) == "number" then
                if not searchResultID and C_LFGList.GetSearchResultInfo(value) then
                    searchResultID = value
                end
            end
        end

        if isInviteLike and searchResultID then
            local result = C_LFGList.GetSearchResultInfo(searchResultID)
            if result then
                local groupName = result.name or result.leaderName
                local resultActivityID = Queue.GetSearchResultActivityID(result, resolveTeleportSpellIDByActivityID)
                local dungeonName = Queue.GetActivityName(resultActivityID)
                local priority = isAccepted and 2 or 1
                updatePendingQueueJoin(groupName, dungeonName, priority, resultActivityID)
            end
        end
    end
end

function Queue.CaptureQueueJoinCandidate(updatePendingQueueJoin, resolveTeleportSpellIDByActivityID, ...)
    local args = { ... }
    local searchResultID
    local groupName
    local isAccepted = false
    local isInviteLike = false

    for _, value in ipairs(args) do
        local statusMatch, acceptedMatch = Queue.ParseApplicationStatus(value)
        if statusMatch then
            isInviteLike = true
            if acceptedMatch then
                isAccepted = true
            end
        end

        if type(value) == "string" and not groupName and value ~= "" then
            local low = string.lower(value)
            if not (low:find("accepted") or low:find("invite")) then
                groupName = value
            end
        elseif type(value) == "number" then
            if not searchResultID and C_LFGList and C_LFGList.GetSearchResultInfo and C_LFGList.GetSearchResultInfo(value) then
                searchResultID = value
            end
        end
    end

    if isInviteLike then
        local dungeonName
        local resultActivityID
        local resolvedGroupName = groupName

        if searchResultID and C_LFGList and C_LFGList.GetSearchResultInfo then
            local result = C_LFGList.GetSearchResultInfo(searchResultID)
            if result then
                resolvedGroupName = resolvedGroupName or result.name or result.leaderName
                resultActivityID = Queue.GetSearchResultActivityID(result, resolveTeleportSpellIDByActivityID)
                dungeonName = Queue.GetActivityName(resultActivityID)
            end
        end

        local priority = isAccepted and 2 or 1
        updatePendingQueueJoin(resolvedGroupName, dungeonName, priority, resultActivityID)
    end

    Queue.CaptureQueueJoinFromApplications(updatePendingQueueJoin, resolveTeleportSpellIDByActivityID)
end

