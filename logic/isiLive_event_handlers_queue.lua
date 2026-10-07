local _, addonTable = ...

addonTable = addonTable or {}

local QueueLifecycle = {}
addonTable.EventHandlersQueueLifecycle = QueueLifecycle
local IsSecretValue = addonTable.Validators.IsSecretValue

local NEGATIVE_STATUS_PENDING_GRACE_SECONDS = 20
-- One entry per second is enough to see that the LFG browser is churning
-- without letting it own the whole runtime log buffer.
local NOISY_QUEUE_LOG_INTERVAL_SECONDS = 1
local INVITE_ACCEPTED_STATUS_REFRESH_DELAY_SECONDS = 0.2
local GROUP_INVITE_SOUND_LOOP_SECONDS = 5

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

local function IsInvitedStatus(status)
  if IsSecretValue(status) or type(status) ~= "string" then
    return false
  end
  return string.lower(status) == "invited"
end

--- Gate predicate: lets an LFG "invited" status through while the main frame
-- is hidden or the player is in combat, so the group-invite voice alert still
-- fires. Every other application status keeps the default gates.
function QueueLifecycle.IsLfgInviteStatusEvent(event, _searchResultID, newStatus)
  return event == "LFG_LIST_APPLICATION_STATUS_UPDATED" and IsInvitedStatus(newStatus)
end

local function IsInCombatLockdown()
  local inCombatLockdown = rawget(_G, "InCombatLockdown")
  return type(inCombatLockdown) == "function" and inCombatLockdown() == true
end

-- A direct invite is pending while Blizzard shows its invite dialog: the plain
-- PARTY_INVITE popup, or LFGInvitePopup when the inviter asked for roles.
-- Accept, decline and the dialog timeout all hide it.
local function IsPartyInviteDialogShown()
  local staticPopupVisible = rawget(_G, "StaticPopup_Visible")
  if type(staticPopupVisible) == "function" then
    local ok, visible = pcall(staticPopupVisible, "PARTY_INVITE")
    if ok and visible then
      return true
    end
  end
  local rolePopup = rawget(_G, "LFGInvitePopup")
  if type(rolePopup) == "table" and type(rolePopup.IsShown) == "function" then
    local ok, shown = pcall(rolePopup.IsShown, rolePopup)
    return ok and shown == true
  end
  return false
end

-- Same check Blizzard's LFGListInviteDialog uses to decide whether an
-- application still waits for an answer: status "invited", no pending status.
local function IsLfgInvitePending()
  local lfgList = rawget(_G, "C_LFGList")
  if
    type(lfgList) ~= "table"
    or type(lfgList.GetApplications) ~= "function"
    or type(lfgList.GetApplicationInfo) ~= "function"
  then
    return false
  end
  local ok, applications = pcall(lfgList.GetApplications)
  if not ok or type(applications) ~= "table" then
    return false
  end
  for _, applicationID in ipairs(applications) do
    if not IsSecretValue(applicationID) then
      local infoOk, _, status, pendingStatus = pcall(lfgList.GetApplicationInfo, applicationID)
      if infoOk and IsInvitedStatus(status) and not IsSecretValue(pendingStatus) and not pendingStatus then
        return true
      end
    end
  end
  return false
end

local function IsGroupInvitePending()
  return IsPartyInviteDialogShown() or IsLfgInvitePending()
end

local function StopGroupInviteSoundLoop(ctx)
  local ticker = ctx.groupInviteSoundLoopTicker
  ctx.groupInviteSoundLoopTicker = nil
  if ticker and type(ticker.Cancel) == "function" then
    ticker:Cancel()
  end
end

-- Starts without a pending check: PARTY_INVITE_REQUEST reaches isiLive and
-- Blizzard's own handler in undefined order, so the invite dialog may not be
-- shown yet. Every tick verifies the live state before it plays.
local function IsGroupInviteLoopEnabled(ctx)
  return type(ctx.isGroupInviteSoundLoopEnabled) ~= "function" or ctx.isGroupInviteSoundLoopEnabled() == true
end

local function StartGroupInviteSoundLoop(ctx)
  if not IsGroupInviteLoopEnabled(ctx) then
    StopGroupInviteSoundLoop(ctx)
    return
  end
  if ctx.groupInviteSoundLoopTicker then
    return
  end
  local timer = rawget(_G, "C_Timer")
  local newTicker = type(timer) == "table" and timer.NewTicker or nil
  if type(newTicker) ~= "function" then
    return
  end

  ctx.groupInviteSoundLoopTicker = newTicker(GROUP_INVITE_SOUND_LOOP_SECONDS, function()
    if
      IsRaidModeActive(ctx)
      or ctx.isGroupInviteSoundEnabled() ~= true
      or not IsGroupInviteLoopEnabled(ctx)
      or not IsGroupInvitePending()
    then
      StopGroupInviteSoundLoop(ctx)
      return
    end
    ctx.playGroupInviteSound()
  end)
end

local function HandleGroupInviteReceived(ctx)
  if IsRaidModeActive(ctx) or ctx.isGroupInviteSoundEnabled() ~= true then
    return
  end
  ctx.playGroupInviteSound()
  StartGroupInviteSoundLoop(ctx)
end

local function HandlePartyInviteCancel(ctx)
  if IsLfgInvitePending() then
    return
  end
  StopGroupInviteSoundLoop(ctx)
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
  local logfThrottled = type(ctx.logRuntimeTracefThrottled) == "function" and ctx.logRuntimeTracefThrottled or nil
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
      if IsInvitedStatus(select(2, ...)) then
        HandleGroupInviteReceived(ctx)
        -- Only the voice alert may use the gate exception for "invited"; the
        -- queue pipeline below keeps the default hidden and combat gates.
        if not ctx.isMainFrameShown() or IsInCombatLockdown() then
          return
        end
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
      -- The client passes only the numeric search-result ID, and the queue-join
      -- capture can only take a group name from a string or table payload: a
      -- numeric payload always ended in its "no_group_name" skip, after an
      -- argument table, a challenge check and log arguments per listed result.
      local payload = ...
      if type(payload) ~= "string" and type(payload) ~= "table" then
        return
      end
      -- Throttled: the LFG browser fires this once per listed result, many
      -- times a second, which used to evict the entire runtime log buffer.
      if logfThrottled then
        local args = { ... }
        logfThrottled(
          "queue_search_result",
          NOISY_QUEUE_LOG_INTERVAL_SECONDS,
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
    PARTY_INVITE_REQUEST = function(_self)
      HandleGroupInviteReceived(ctx)
    end,
    PARTY_INVITE_CANCEL = function(_self)
      HandlePartyInviteCancel(ctx)
    end,
  }
end
