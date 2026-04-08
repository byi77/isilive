local _, addonTable = ...

addonTable = addonTable or {}

local ChallengeLifecycle = {}
addonTable.EventHandlersChallengeLifecycle = ChallengeLifecycle

local POST_RUN_REFRESH_INITIAL_DELAY_SECONDS = 5
local POST_RUN_REFRESH_RETRIES = 5
local POST_RUN_REFRESH_RETRY_DELAY_SECONDS = 1
local POST_RUN_FOLLOWUP_REFRESH_DELAY_SECONDS = 6
local POST_RUN_FOLLOWUP_REFRESH_ATTEMPTS = 2
local POST_RUN_CAPTURE_RETRIES = 5
local POST_RUN_CAPTURE_RETRY_DELAY_SECONDS = 1
local READY_CHECK_DECLINED_HOLD_SECONDS = 20
local function ResetDamageMeterIfAvailable()
  local damageMeterAPI = rawget(_G, "C_DamageMeter")
  if
    not (
      type(damageMeterAPI) == "table"
      and type(damageMeterAPI.IsDamageMeterAvailable) == "function"
      and type(damageMeterAPI.ResetAllCombatSessions) == "function"
    )
  then
    return false
  end

  local okAvailable, isAvailable = pcall(damageMeterAPI.IsDamageMeterAvailable)
  if not okAvailable or not isAvailable then
    return false
  end

  local okReset = pcall(damageMeterAPI.ResetAllCombatSessions)
  return okReset
end

local function GetChallengeCompletionInfoSafe()
  local challengeModeAPI = type(C_ChallengeMode) == "table" and C_ChallengeMode or nil
  local getCompletionInfo = challengeModeAPI and rawget(challengeModeAPI, "GetCompletionInfo") or nil
  if type(getCompletionInfo) ~= "function" then
    return nil, nil, nil, nil
  end

  local ok, mapID, level, time, onTime = pcall(getCompletionInfo)
  if not ok then
    return nil, nil, nil, nil
  end

  return mapID, level, time, onTime
end

local function ResolveCompletedRunInfo()
  local mapID, level, time, onTime = GetChallengeCompletionInfoSafe()
  if not (mapID and level) then
    return nil
  end

  return {
    mapID = mapID,
    level = level,
    onTime = onTime,
    signature = string.format("%s:%s:%s:%s", tostring(mapID), tostring(level), tostring(time), tostring(onTime)),
  }
end

local TryRecordCompletedRun

local function ScheduleCompletedRunRetry(ctx, runInfo, retriesRemaining)
  if
    type(runInfo) ~= "table"
    or retriesRemaining <= 0
    or not ctx.timerAfter
    or ctx.pendingRecordedRunRetrySignature == runInfo.signature
  then
    return false
  end

  ctx.pendingRecordedRunRetrySignature = runInfo.signature
  ctx.timerAfter(POST_RUN_CAPTURE_RETRY_DELAY_SECONDS, function()
    if ctx.lastRecordedRunSignature ~= runInfo.signature or ctx.lastRecordedRunCaptured then
      return
    end

    ctx.pendingRecordedRunRetrySignature = nil
    if TryRecordCompletedRun(ctx, runInfo, retriesRemaining - 1) then
      ctx.updateUI()
    end
  end)

  return true
end

local function RefreshRosterAfterRunStateChange(ctx, frame)
  if ctx.isInGroup() then
    local onEventHandler = frame and frame.GetScript and frame:GetScript("OnEvent") or nil
    if onEventHandler then
      onEventHandler(frame, "GROUP_ROSTER_UPDATE")
      return
    end
    ctx.updateUI()
    return
  end

  ctx.updateLeaderButtons()
end

TryRecordCompletedRun = function(ctx, runInfo, retriesRemaining)
  if type(runInfo) ~= "table" then
    return false
  end

  if ctx.lastRecordedRunSignature ~= runInfo.signature then
    ctx.lastRecordedRunSignature = runInfo.signature
    ctx.lastRecordedRunCaptured = false
    ctx.pendingRecordedRunRetrySignature = nil
  elseif ctx.lastRecordedRunCaptured then
    return false
  end

  local capturedNow = ctx.recordRun(runInfo.mapID, runInfo.level, runInfo.onTime) ~= false
  if capturedNow then
    ctx.lastRecordedRunCaptured = true
    ctx.pendingRecordedRunRetrySignature = nil
    return true
  end

  ScheduleCompletedRunRetry(ctx, runInfo, retriesRemaining or POST_RUN_CAPTURE_RETRIES)
  return false
end

local function RunDelayedPostChallengeRefresh(ctx, frame, retriesRemaining, followUpRefreshesRemaining)
  if not ctx.isInGroup() then
    ctx.enableRioDeltaDisplay()
    return
  end

  local refreshed = ctx.runFullRefresh() ~= false

  if not refreshed and retriesRemaining > 0 and ctx.timerAfter then
    ctx.timerAfter(POST_RUN_REFRESH_RETRY_DELAY_SECONDS, function()
      RunDelayedPostChallengeRefresh(ctx, frame, retriesRemaining - 1, followUpRefreshesRemaining)
    end)
    return
  end

  ctx.enableRioDeltaDisplay()
  RefreshRosterAfterRunStateChange(ctx, frame)

  if refreshed and followUpRefreshesRemaining > 0 and ctx.timerAfter then
    ctx.timerAfter(POST_RUN_FOLLOWUP_REFRESH_DELAY_SECONDS, function()
      RunDelayedPostChallengeRefresh(ctx, frame, 0, followUpRefreshesRemaining - 1)
    end)
  end
end

local function RefreshReadyCheckUI(ctx)
  ctx.refreshReadyCheckUI()
end

local function ResetReadyCheckDeclinedTracking(ctx)
  ctx.readyCheckReadyUnits = {}
  ctx.readyCheckDeclinedUnits = {}
  ctx.clearAllReadyCheckReady()
  ctx.clearAllReadyCheckDeclined()
  ctx.readyCheckHoldUntil = nil
end

local ScheduleReadyCheckHoldClear

local function GetReadyCheckHoldUntil(ctx)
  local holdUntil = tonumber(ctx.readyCheckHoldUntil)
  local now = tonumber(ctx.getTime and ctx.getTime()) or 0
  if holdUntil and holdUntil > now then
    return holdUntil
  end

  return now + READY_CHECK_DECLINED_HOLD_SECONDS
end

local function MarkReadyCheckUnit(ctx, unit, setUntilFn)
  if type(unit) ~= "string" or unit == "" then
    return false
  end

  local numericHoldUntil = GetReadyCheckHoldUntil(ctx)
  if numericHoldUntil <= 0 then
    return false
  end

  local now = tonumber(ctx.getTime and ctx.getTime()) or 0
  local currentHoldUntil = tonumber(ctx.readyCheckHoldUntil) or 0
  setUntilFn(unit, numericHoldUntil)
  if not currentHoldUntil or currentHoldUntil <= now then
    ScheduleReadyCheckHoldClear(ctx, numericHoldUntil)
  end
  RefreshReadyCheckUI(ctx)
  return true
end

local function MarkReadyCheckDeclinedUnit(ctx, unit)
  return MarkReadyCheckUnit(ctx, unit, ctx.setReadyCheckDeclinedUntil)
end

local function MarkReadyCheckReadyUnit(ctx, unit)
  return MarkReadyCheckUnit(ctx, unit, ctx.setReadyCheckReadyUntil)
end

ScheduleReadyCheckHoldClear = function(ctx, holdUntil)
  if not ctx.timerAfter or not holdUntil then
    return
  end

  local now = tonumber(ctx.getTime and ctx.getTime()) or 0
  local delaySeconds = math.max(0, holdUntil - now)
  ctx.readyCheckHoldUntil = holdUntil
  ctx.timerAfter(delaySeconds, function()
    if ctx.readyCheckHoldUntil ~= holdUntil then
      return
    end
    ctx.readyCheckHoldUntil = nil
    local currentTime = tonumber(ctx.getTime and ctx.getTime()) or holdUntil
    local changed = false
    if ctx.clearExpiredReadyCheckReady(currentTime) then
      changed = true
    end
    if ctx.clearExpiredReadyCheckDeclined(currentTime) then
      changed = true
    end
    if changed then
      RefreshReadyCheckUI(ctx)
    end
  end)
end

local function PromoteReadyCheckReadyUnitsToHold(ctx)
  local readyUnits = ctx.readyCheckReadyUnits or {}
  local hasReady = false
  local holdUntil = (tonumber(ctx.getTime and ctx.getTime()) or 0) + READY_CHECK_DECLINED_HOLD_SECONDS

  ctx.clearAllReadyCheckReady()

  for unit, isReady in pairs(readyUnits) do
    if isReady == true then
      ctx.setReadyCheckReadyUntil(unit, holdUntil)
      hasReady = true
    end
  end
  ctx.readyCheckReadyUnits = {}

  if hasReady then
    ScheduleReadyCheckHoldClear(ctx, holdUntil)
  end
end

local function PromoteDeclinedReadyCheckUnitsToHold(ctx)
  local declinedUnits = ctx.readyCheckDeclinedUnits or {}
  local hasDeclined = false
  local holdUntil = (tonumber(ctx.getTime and ctx.getTime()) or 0) + READY_CHECK_DECLINED_HOLD_SECONDS

  ctx.clearAllReadyCheckDeclined()

  for unit, isDeclined in pairs(declinedUnits) do
    if isDeclined == true then
      ctx.setReadyCheckDeclinedUntil(unit, holdUntil)
      hasDeclined = true
    end
  end
  ctx.readyCheckDeclinedUnits = {}

  if hasDeclined then
    ScheduleReadyCheckHoldClear(ctx, holdUntil)
  end
end

local function IsRaidModeActive(ctx)
  return type(ctx.isRaidGroup) == "function" and ctx.isRaidGroup() == true
end

function ChallengeLifecycle.BuildHandlers(ctx)
  local function HandleChallengeModeStart(_self)
    if IsRaidModeActive(ctx) then
      return
    end
    ctx.lastRecordedRunSignature = nil
    ctx.lastRecordedRunCaptured = false
    ctx.pendingRecordedRunRetrySignature = nil
    ctx.setReadyCheckActive(false)
    ResetReadyCheckDeclinedTracking(ctx)
    ResetDamageMeterIfAvailable()
    ctx.captureRioBaselineSnapshot()
    ctx.setActiveJoinedKeyMapID(nil)
    ctx.checkIfEnteredTargetDungeon()
    if ctx.shouldAutoCloseMainFrame() and not ctx.isRosterCollapsed() then
      ctx.setMainFrameVisible(false)
    end
    ctx.updateLeaderButtons()
    ctx.updateStatusLine()
    ctx.updateMPlusTeleportButton()
  end

  local function HandleChallengeModeCompletedOrReset(frame)
    if IsRaidModeActive(ctx) then
      return
    end
    TryRecordCompletedRun(ctx, ResolveCompletedRunInfo(), POST_RUN_CAPTURE_RETRIES)

    if ctx.isInGroup() and ctx.shouldAutoOpenMainFrameOnKeyEnd() then
      ctx.setMainFrameVisible(true)
    end
    RefreshRosterAfterRunStateChange(ctx, frame)
    ctx.updateStatusLine()
    ctx.notifyPostChallengeSync()
    if ctx.timerAfter then
      ctx.timerAfter(POST_RUN_REFRESH_INITIAL_DELAY_SECONDS, function()
        RunDelayedPostChallengeRefresh(ctx, frame, POST_RUN_REFRESH_RETRIES, POST_RUN_FOLLOWUP_REFRESH_ATTEMPTS)
      end)
      return
    end

    RunDelayedPostChallengeRefresh(ctx, frame, 0, 0)
  end

  return {
    CHALLENGE_MODE_START = HandleChallengeModeStart,
    CHALLENGE_MODE_COMPLETED = HandleChallengeModeCompletedOrReset,
    CHALLENGE_MODE_RESET = HandleChallengeModeCompletedOrReset,
    READY_CHECK = function(_self)
      if IsRaidModeActive(ctx) then
        return
      end
      ctx._readyCheckLingerSeq = (ctx._readyCheckLingerSeq or 0) + 1
      ctx.setReadyCheckActive(true)
      ResetReadyCheckDeclinedTracking(ctx)
      RefreshReadyCheckUI(ctx)
    end,
    READY_CHECK_CONFIRM = function(_self, unit, status)
      if IsRaidModeActive(ctx) then
        return
      end
      if type(unit) ~= "string" or unit == "" then
        return
      end

      if status == "notready" then
        if ctx.isReadyCheckActive() then
          local readyUnits = ctx.readyCheckReadyUnits or {}
          ctx.readyCheckReadyUnits = readyUnits
          readyUnits[unit] = nil
          local declinedUnits = ctx.readyCheckDeclinedUnits or {}
          ctx.readyCheckDeclinedUnits = declinedUnits
          declinedUnits[unit] = true
          RefreshReadyCheckUI(ctx)
        else
          MarkReadyCheckDeclinedUnit(ctx, unit)
        end
        return
      end

      if status == "ready" then
        if ctx.isReadyCheckActive() then
          local declinedUnits = ctx.readyCheckDeclinedUnits or {}
          ctx.readyCheckDeclinedUnits = declinedUnits
          declinedUnits[unit] = nil
          local readyUnits = ctx.readyCheckReadyUnits or {}
          ctx.readyCheckReadyUnits = readyUnits
          readyUnits[unit] = true
          RefreshReadyCheckUI(ctx)
        else
          MarkReadyCheckReadyUnit(ctx, unit)
        end
        return
      end

      if ctx.isReadyCheckActive() then
        local readyUnits = ctx.readyCheckReadyUnits or {}
        ctx.readyCheckReadyUnits = readyUnits
        readyUnits[unit] = nil
        local declinedUnits = ctx.readyCheckDeclinedUnits or {}
        ctx.readyCheckDeclinedUnits = declinedUnits
        declinedUnits[unit] = nil
        RefreshReadyCheckUI(ctx)
      end
    end,
    READY_CHECK_FINISHED = function()
      if IsRaidModeActive(ctx) then
        return
      end
      ctx.setReadyCheckActive(false)
      PromoteReadyCheckReadyUnitsToHold(ctx)
      PromoteDeclinedReadyCheckUnitsToHold(ctx)
      RefreshReadyCheckUI(ctx)
    end,
  }
end
