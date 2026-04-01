local _, addonTable = ...

addonTable = addonTable or {}

local QueueLifecycle = {}
addonTable.EventHandlersQueueLifecycle = QueueLifecycle

local NEGATIVE_STATUS_PENDING_GRACE_SECONDS = 20

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

function QueueLifecycle.BuildHandlers(ctx)
  return {
    LFG_LIST_APPLICATION_STATUS_UPDATED = function(_self, ...)
      if ctx.isInChallengeMode() or IsRaidModeActive(ctx) then
        return
      end
      if ctx.isTestMode() or ctx.isTestAllMode() then
        ctx.exitTestMode()
      end
      if ctx.isNegativeApplicationStatusEvent(...) then
        if not ShouldPreservePendingQueueJoinInfoOnNegativeStatus(ctx) then
          ctx.setPendingQueueJoinInfo(nil)
        end
        local entryInfo = ctx.getNormalizedActiveEntryInfo()
        if not HasActiveListing(entryInfo) and not ctx.isInGroup() then
          ctx.clearLatestQueueTarget()
        end
        ctx.updateMPlusTeleportButton()
        return
      end
      ctx.captureQueueJoinCandidate(...)
    end,
    LFG_LIST_SEARCH_RESULT_UPDATED = function(_self, ...)
      if ctx.isInChallengeMode() or IsRaidModeActive(ctx) then
        return
      end
      ctx.captureQueueJoinCandidate(...)
    end,
    LFG_LIST_ACTIVE_ENTRY_UPDATE = function(_self)
      if ctx.isInChallengeMode() or IsRaidModeActive(ctx) then
        return
      end
      local entryInfo = ctx.getNormalizedActiveEntryInfo()
      local hadActiveJoinedKey = ctx.getActiveJoinedKeyMapID() ~= nil
      if HasActiveListing(entryInfo) then
        if ctx.isTestMode() or ctx.isTestAllMode() then
          ctx.exitTestMode()
        end
        ctx.setActiveJoinedKeyMapID(nil)
      end
      ctx.setPendingQueueJoinInfo(nil)
      ctx.updateMPlusTeleportButton()
      if hadActiveJoinedKey and not ctx.getActiveJoinedKeyMapID() then
        ctx.updateUI()
      end
    end,
  }
end
