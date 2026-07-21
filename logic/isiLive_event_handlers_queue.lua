local _, addonTable = ...

addonTable = addonTable or {}

local QueueLifecycle = {}
addonTable.EventHandlersQueueLifecycle = QueueLifecycle

local NEGATIVE_STATUS_PENDING_GRACE_SECONDS = 20
local INVITE_ACCEPTED_STATUS_REFRESH_DELAY_SECONDS = 0.2

local function HasActiveListing(entryInfo)
  if type(entryInfo) ~= "table" then
    return false
  end

  local active = entryInfo.active
  if type(active) == "boolean" then
    return active
  end

  if tonumber(entryInfo.activityID) or tonumber(entryInfo.primaryActivityID) or tonumber(entryInfo.mapID) then
    return true
  end

  if type(entryInfo.activityIDs) == "table" and next(entryInfo.activityIDs) ~= nil then
    return true
  end

  if type(entryInfo.name) == "string" and entryInfo.name ~= "" then
    return true
  end
  if type(entryInfo.activityName) == "string" and entryInfo.activityName ~= "" then
    return true
  end
  if type(entryInfo.title) == "string" and entryInfo.title ~= "" then
    return true
  end

  return false
end

local function ShouldPreservePendingQueueJoinInfoOnNegativeStatus(ctx)
  local pending = ctx.getPendingQueueJoinInfo()
  if type(pending) ~= "table" then
    return false
  end

  local capturedAt = tonumber(pending.capturedAt)
  if not capturedAt then
    return true
  end

  if type(ctx.getTime) ~= "function" then
    return true
  end

  local now = tonumber(ctx.getTime())
  if not now then
    return true
  end

  return (now - capturedAt) <= NEGATIVE_STATUS_PENDING_GRACE_SECONDS
end

local function IsRaidModeActive(ctx)
  return type(ctx.isRaidGroup) == "function" and ctx.isRaidGroup() == true
end

local function IsInviteAcceptedStatus(...)
  local newStatus = select(2, ...)
  return type(newStatus) == "string" and string.lower(newStatus) == "inviteaccepted"
end

local function RefreshTargetStatusAfterInviteAccepted(ctx)
  if type(ctx.updateStatusLine) == "function" then
    ctx.updateStatusLine()
  end
  if type(ctx.timerAfter) == "function" then
    ctx.timerAfter(INVITE_ACCEPTED_STATUS_REFRESH_DELAY_SECONDS, function()
      if IsRaidModeActive(ctx) then
        return
      end
      if type(ctx.updateStatusLine) == "function" then
        ctx.updateStatusLine()
      end
    end)
  end
end

function QueueLifecycle.BuildHandlers(ctx)
  ctx.handleLFGDetectEvent = type(ctx.handleLFGDetectEvent) == "function" and ctx.handleLFGDetectEvent
    or function(_event, ...) end
  local logf = type(ctx.logRuntimeTracef) == "function" and ctx.logRuntimeTracef or nil
  return {
    LFG_LIST_APPLICATION_STATUS_UPDATED = function(_self, ...)
      if logf then
        local args = { ... }
        logf(
          "[QUEUE] application_status_updated searchResultID=%s status=%s inChallenge=%s",
          tostring(args[1]),
          tostring(args[2]),
          tostring(ctx.isInChallengeMode())
        )
      end
      if ctx.isInChallengeMode() or IsRaidModeActive(ctx) then
        return
      end
      ctx.handleLFGDetectEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", ...)
      if IsInviteAcceptedStatus(...) then
        RefreshTargetStatusAfterInviteAccepted(ctx)
      end
      if ctx.isTestMode() or ctx.isTestAllMode() then
        ctx.exitTestMode()
      end
      if ctx.isNegativeApplicationStatusEvent(...) then
        local preserve = ShouldPreservePendingQueueJoinInfoOnNegativeStatus(ctx)
        if logf then
          local args = { ... }
          logf("[QUEUE] negative_status searchResultID=%s preservePending=%s", tostring(args[1]), tostring(preserve))
        end
        if not preserve then
          ctx.setPendingQueueJoinInfo(nil)
        end
        local entryInfo = ctx.getNormalizedActiveEntryInfo()
        if not HasActiveListing(entryInfo) and not ctx.isInGroup() then
          ctx.clearLatestQueueTarget()
        end
        ctx.updateMPlusTeleportButton("queue")
        return
      end
      ctx.captureQueueJoinCandidate(...)
    end,
    LFG_LIST_SEARCH_RESULT_UPDATED = function(_self, ...)
      if logf then
        local args = { ... }
        logf(
          "[QUEUE] search_result_updated searchResultID=%s inChallenge=%s",
          tostring(args[1]),
          tostring(ctx.isInChallengeMode())
        )
      end
      if ctx.isInChallengeMode() or IsRaidModeActive(ctx) then
        return
      end
      ctx.captureQueueJoinCandidate(...)
    end,
    LFG_LIST_ACTIVE_ENTRY_UPDATE = function(_self)
      if ctx.isInChallengeMode() or IsRaidModeActive(ctx) then
        return
      end
      ctx.handleLFGDetectEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
      local entryInfo = ctx.getNormalizedActiveEntryInfo()
      local hadActiveJoinedKey = ctx.getActiveJoinedKeyMapID() ~= nil
      local activityID = type(entryInfo) == "table"
          and (entryInfo.activityID or (type(entryInfo.activityIDs) == "table" and next(entryInfo.activityIDs)))
        or nil
      local mapID = type(entryInfo) == "table" and entryInfo.mapID or nil
      if logf then
        logf(
          "[QUEUE] active_entry_update hasListing=%s activityID=%s mapID=%s hadActiveJoinedKey=%s",
          tostring(HasActiveListing(entryInfo)),
          tostring(activityID),
          tostring(mapID),
          tostring(hadActiveJoinedKey)
        )
      end
      if HasActiveListing(entryInfo) then
        if ctx.isTestMode() or ctx.isTestAllMode() then
          ctx.exitTestMode()
        end
        if type(ctx.logRuntimeTrace) == "function" then
          ctx.logRuntimeTrace("[STATE] set_active_joined_key_map_id value=nil reason=active_entry_update")
        end
        ctx.setActiveJoinedKeyMapID(nil)
      end
      ctx.setPendingQueueJoinInfo(nil)
      ctx.updateMPlusTeleportButton("queue")
      if hadActiveJoinedKey and not ctx.getActiveJoinedKeyMapID() then
        ctx.updateUI()
      end
    end,
  }
end
