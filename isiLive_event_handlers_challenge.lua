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

local function ResetDamageMeterIfAvailable()
  local damageMeterAPI = _G.C_DamageMeter
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

local function DidRecordRunSucceed(recorded)
  return recorded ~= false
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

  local capturedNow = DidRecordRunSucceed(ctx.recordRun(runInfo.mapID, runInfo.level, runInfo.onTime))
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
  if refreshed then
    ctx.enableRioDeltaDisplay()
    RefreshRosterAfterRunStateChange(ctx, frame)
    if followUpRefreshesRemaining > 0 and ctx.timerAfter then
      ctx.timerAfter(POST_RUN_FOLLOWUP_REFRESH_DELAY_SECONDS, function()
        RunDelayedPostChallengeRefresh(ctx, frame, 0, followUpRefreshesRemaining - 1)
      end)
    end
    return
  end

  if retriesRemaining > 0 and ctx.timerAfter then
    ctx.timerAfter(POST_RUN_REFRESH_RETRY_DELAY_SECONDS, function()
      RunDelayedPostChallengeRefresh(ctx, frame, retriesRemaining - 1, followUpRefreshesRemaining)
    end)
    return
  end

  ctx.enableRioDeltaDisplay()
  RefreshRosterAfterRunStateChange(ctx, frame)
end

function ChallengeLifecycle.BuildHandlers(ctx)
  local function HandleChallengeModeStart(_self)
    ctx.lastRecordedRunSignature = nil
    ctx.lastRecordedRunCaptured = false
    ctx.pendingRecordedRunRetrySignature = nil
    ctx.setReadyCheckActive(false)
    ResetDamageMeterIfAvailable()
    ctx.captureRioBaselineSnapshot()
    ctx.setActiveJoinedKeyMapID(nil)
    ctx.checkIfEnteredTargetDungeon()
    if not ctx.isRosterCollapsed() then
      ctx.setMainFrameVisible(false)
    end
    ctx.updateLeaderButtons()
    ctx.updateStatusLine()
    ctx.updateMPlusTeleportButton()
  end

  local function HandleChallengeModeCompletedOrReset(frame)
    TryRecordCompletedRun(ctx, ResolveCompletedRunInfo(), POST_RUN_CAPTURE_RETRIES)

    if ctx.isInGroup() then
      ctx.setMainFrameVisible(true)
    end
    RefreshRosterAfterRunStateChange(ctx, frame)
    ctx.updateStatusLine()
    ctx.sendOwnKeySnapshot(true, "challenge")
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
      ctx.setReadyCheckActive(true)
      ctx.updateUI()
    end,
    READY_CHECK_CONFIRM = function(_self)
      if ctx.isReadyCheckActive() then
        ctx.updateUI()
      end
    end,
    READY_CHECK_FINISHED = function(_self)
      ctx.setReadyCheckActive(false)
      ctx.updateUI()
    end,
  }
end
