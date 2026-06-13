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
local IsReadyCheckRosterUnit
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
local IsRaidModeActive

local function GetPendingPostChallengeRefresh(ctx)
  return type(ctx.getPendingPostChallengeRefresh) == "function" and ctx.getPendingPostChallengeRefresh() or nil
end

local function CountReadyCheckUnits(units)
  local count = 0
  for _, isMarked in pairs(units or {}) do
    if isMarked == true then
      count = count + 1
    end
  end
  return count
end

local function CollectMarkedReadyCheckUnits(units)
  local out = {}
  for unit, isMarked in pairs(units or {}) do
    if isMarked == true and type(unit) == "string" and unit ~= "" then
      out[#out + 1] = unit
    end
  end
  table.sort(out)
  return out
end

local function CountReadyCheckHoldUnits(getUntil, roster, now)
  if type(getUntil) ~= "function" or type(roster) ~= "table" then
    return 0
  end

  local count = 0
  for unit in pairs(roster) do
    if type(unit) == "string" and unit ~= "" then
      local untilTime = tonumber(getUntil(unit))
      if untilTime and untilTime > now then
        count = count + 1
      end
    end
  end
  return count
end

local function CollectReadyCheckRosterUnits(ctx)
  local roster = type(ctx.getRoster) == "function" and ctx.getRoster() or nil
  if type(roster) ~= "table" then
    return nil
  end

  local units = {}
  for unit, info in pairs(roster) do
    if IsReadyCheckRosterUnit(unit, info) then
      units[#units + 1] = unit
    end
  end
  table.sort(units)
  return units
end

local function MaybePlayReadyCheckCompleteSound(ctx)
  if ctx.readyCheckCompleteSoundPlayed == true then
    return false
  end
  if not (ctx.isReadyCheckActive and ctx.isReadyCheckActive() == true) then
    return false
  end

  local units = CollectReadyCheckRosterUnits(ctx)
  if type(units) ~= "table" or #units ~= 5 then
    return false
  end

  local readyUnits = ctx.readyCheckReadyUnits or {}
  for _, unit in ipairs(units) do
    if readyUnits[unit] ~= true then
      return false
    end
  end

  ctx.readyCheckCompleteSoundPlayed = true
  ctx.playReadyCheckCompleteSound()
  return true
end

local function LogReadyCheckTrace(ctx, eventName, unit, status, extra)
  local logRuntimeTrace = type(ctx.logRuntimeTrace) == "function" and ctx.logRuntimeTrace or nil
  if not logRuntimeTrace then
    return
  end

  local now = tonumber(ctx.getTime and ctx.getTime()) or 0
  local active = ctx.isReadyCheckActive and ctx.isReadyCheckActive() == true
  local holdUntil = tonumber(ctx.readyCheckHoldUntil) or 0
  local parts = {
    string.format("event=%s", tostring(eventName)),
    string.format("now=%s", tostring(now)),
    string.format("active=%s", tostring(active)),
    string.format("hold=%s", holdUntil > 0 and tostring(holdUntil) or "nil"),
    string.format("ready=%d", CountReadyCheckUnits(ctx.readyCheckReadyUnits)),
    string.format("declined=%d", CountReadyCheckUnits(ctx.readyCheckDeclinedUnits)),
  }

  if type(unit) == "string" and unit ~= "" then
    parts[#parts + 1] = string.format("unit=%s", unit)
  end
  if type(status) == "string" and status ~= "" then
    parts[#parts + 1] = string.format("status=%s", status)
  end
  if type(extra) == "string" and extra ~= "" then
    parts[#parts + 1] = extra
  end

  logRuntimeTrace("[READYCHECK] " .. table.concat(parts, " "))
end

local function LogReadyCheckFinishHold(ctx, activeBefore, readyUnits, declinedUnits)
  local logRuntimeTrace = type(ctx.logRuntimeTrace) == "function" and ctx.logRuntimeTrace or nil
  if not logRuntimeTrace then
    return
  end

  local now = tonumber(ctx.getTime and ctx.getTime()) or 0
  local roster = type(ctx.getRoster) == "function" and ctx.getRoster() or nil
  local readyUntilCount = CountReadyCheckHoldUnits(ctx.getReadyCheckReadyUntil, roster, now)
  local declinedUntilCount = CountReadyCheckHoldUnits(ctx.getReadyCheckDeclinedUntil, roster, now)
  local readyList = #readyUnits > 0 and table.concat(readyUnits, ",") or "-"
  local declinedList = #declinedUnits > 0 and table.concat(declinedUnits, ",") or "-"
  local activeAfter = ctx.isReadyCheckActive and ctx.isReadyCheckActive() == true

  logRuntimeTrace(
    string.format(
      "[RC_FINISH_HOLD] ts=%s event=READY_CHECK_FINISHED active_before=%s "
        .. "active_after=%s ready_units=%s declined_units=%s "
        .. "ready_until_count=%d declined_until_count=%d",
      tostring(now),
      tostring(activeBefore),
      tostring(activeAfter),
      readyList,
      declinedList,
      readyUntilCount,
      declinedUntilCount
    )
  )
end

local function SetPendingPostChallengeRefresh(ctx, value)
  if type(ctx.setPendingPostChallengeRefresh) == "function" then
    ctx.setPendingPostChallengeRefresh(value)
  end
end

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
  if IsRaidModeActive(ctx) then
    SetPendingPostChallengeRefresh(ctx, {
      frame = frame,
      retriesRemaining = retriesRemaining,
      followUpRefreshesRemaining = followUpRefreshesRemaining,
    })
    return
  end

  SetPendingPostChallengeRefresh(ctx, nil)
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
  ctx.readyCheckCompleteSoundPlayed = false
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
  LogReadyCheckTrace(ctx, "CONFIRM_HOLD", unit, nil, string.format("hold=%s", tostring(numericHoldUntil)))
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
    LogReadyCheckTrace(ctx, "HOLD_CLEAR", nil, nil, string.format("changed=%s", tostring(changed)))
    if changed then
      RefreshReadyCheckUI(ctx)
    end
  end)
end

local function PromoteReadyCheckUnitsToHold(ctx, unitsKey, clearFn, setUntilFn)
  local units = ctx[unitsKey] or {}
  local hasAny = false
  local holdUntil = (tonumber(ctx.getTime and ctx.getTime()) or 0) + READY_CHECK_DECLINED_HOLD_SECONDS

  clearFn()

  for unit, isSet in pairs(units) do
    if isSet == true then
      setUntilFn(unit, holdUntil)
      hasAny = true
    end
  end
  ctx[unitsKey] = {}

  if hasAny then
    ScheduleReadyCheckHoldClear(ctx, holdUntil)
  end
end

local function PromoteReadyCheckReadyUnitsToHold(ctx)
  PromoteReadyCheckUnitsToHold(ctx, "readyCheckReadyUnits", ctx.clearAllReadyCheckReady, ctx.setReadyCheckReadyUntil)
end

local function PromoteDeclinedReadyCheckUnitsToHold(ctx)
  PromoteReadyCheckUnitsToHold(
    ctx,
    "readyCheckDeclinedUnits",
    ctx.clearAllReadyCheckDeclined,
    ctx.setReadyCheckDeclinedUntil
  )
end

IsReadyCheckRosterUnit = function(unit, info)
  if type(unit) ~= "string" or unit == "" then
    return false
  end
  if type(info) ~= "table" or info.isGhost then
    return false
  end

  return unit == "player" or string.match(unit, "^party%d+$") ~= nil
end

local function PromoteUnansweredReadyCheckUnitsToDeclined(ctx)
  local getRoster = type(ctx.getRoster) == "function" and ctx.getRoster or nil
  if not getRoster then
    return
  end

  local roster = getRoster()
  if type(roster) ~= "table" then
    return
  end

  local readyUnits = ctx.readyCheckReadyUnits or {}
  local declinedUnits = ctx.readyCheckDeclinedUnits or {}
  ctx.readyCheckDeclinedUnits = declinedUnits

  for unit, info in pairs(roster) do
    if IsReadyCheckRosterUnit(unit, info) and readyUnits[unit] ~= true and declinedUnits[unit] ~= true then
      declinedUnits[unit] = true
    end
  end
end

local function UpdateReadyCheckUnits(ctx, unit, readyValue, declinedValue)
  local readyUnits = ctx.readyCheckReadyUnits or {}
  ctx.readyCheckReadyUnits = readyUnits
  readyUnits[unit] = readyValue
  local declinedUnits = ctx.readyCheckDeclinedUnits or {}
  ctx.readyCheckDeclinedUnits = declinedUnits
  declinedUnits[unit] = declinedValue
end

-- Pre-marks the player who started the ready check as ready. Blizzard does
-- not fire READY_CHECK_CONFIRM for the initiator (they are implicit), so
-- without this pre-mark PromoteUnansweredReadyCheckUnitsToDeclined would
-- flip the initiator's row to "declined" red on READY_CHECK_FINISHED — which
-- in M+ groups is typically the leader / active key holder.
--
-- initiatorName is Blizzard's READY_CHECK first arg, e.g. "Mematiwow" (same
-- realm) or "Mematiwow-Blackmoore" (cross-realm). The roster's info.name is
-- the bare name, info.realm the realm; we accept either form.
local function MarkReadyCheckInitiatorReady(ctx, initiatorName)
  if type(initiatorName) ~= "string" or initiatorName == "" then
    return
  end
  local getRoster = type(ctx.getRoster) == "function" and ctx.getRoster or nil
  if not getRoster then
    return
  end
  local roster = getRoster()
  if type(roster) ~= "table" then
    return
  end

  local hintName, hintRealm
  local dash = string.find(initiatorName, "-", 1, true)
  if dash then
    hintName = string.sub(initiatorName, 1, dash - 1)
    hintRealm = string.sub(initiatorName, dash + 1)
    if hintRealm == "" then
      hintRealm = nil
    end
  else
    hintName = initiatorName
  end
  if hintName == "" then
    return
  end

  for unit, info in pairs(roster) do
    if
      type(unit) == "string"
      and unit ~= ""
      and type(info) == "table"
      and not info.isGhost
      and info.name == hintName
      and (hintRealm == nil or info.realm == nil or info.realm == hintRealm)
    then
      UpdateReadyCheckUnits(ctx, unit, true, nil)
      return
    end
  end
end

IsRaidModeActive = function(ctx)
  return type(ctx.isRaidGroup) == "function" and ctx.isRaidGroup() == true
end

function ChallengeLifecycle.ResumeDeferredPostChallengeRefresh(ctx, frame)
  local pending = GetPendingPostChallengeRefresh(ctx)
  if type(pending) ~= "table" or IsRaidModeActive(ctx) then
    return false
  end

  SetPendingPostChallengeRefresh(ctx, nil)
  RunDelayedPostChallengeRefresh(
    ctx,
    pending.frame or frame,
    pending.retriesRemaining or POST_RUN_REFRESH_RETRIES,
    pending.followUpRefreshesRemaining or POST_RUN_FOLLOWUP_REFRESH_ATTEMPTS
  )
  return true
end

function ChallengeLifecycle.BuildHandlers(ctx)
  ctx.handleMplusTimerEvent = type(ctx.handleMplusTimerEvent) == "function" and ctx.handleMplusTimerEvent
    or function(_event, ...) end
  ctx.handleKillTrackEvent = type(ctx.handleKillTrackEvent) == "function" and ctx.handleKillTrackEvent
    or function(_event, ...) end
  ctx.handleCombatEventsEvent = type(ctx.handleCombatEventsEvent) == "function" and ctx.handleCombatEventsEvent
    or function(_event, ...) end
  ctx.handleDeathWatchEvent = type(ctx.handleDeathWatchEvent) == "function" and ctx.handleDeathWatchEvent
    or function(_event, ...) end

  local function HandleChallengeModeStart(_self)
    if IsRaidModeActive(ctx) then
      return
    end
    ctx.handleMplusTimerEvent("CHALLENGE_MODE_START")
    ctx.handleKillTrackEvent("CHALLENGE_MODE_START")
    ctx.handleCombatEventsEvent("CHALLENGE_MODE_START")
    ctx.handleDeathWatchEvent("CHALLENGE_MODE_START")
    ctx.handleLFGDetectEvent("CHALLENGE_MODE_START")
    if type(ctx.logRuntimeTrace) == "function" then
      ctx.logRuntimeTrace("[RC] challenge_mode_start state_set var=readyCheckActive val=false")
    end
    SetPendingPostChallengeRefresh(ctx, nil)
    if type(ctx.resetKickStats) == "function" then
      ctx.resetKickStats()
    end
    ctx.lastRecordedRunSignature = nil
    ctx.lastRecordedRunCaptured = false
    ctx.pendingRecordedRunRetrySignature = nil
    ctx.setReadyCheckActive(false)
    -- Clear stale ready/declined marks: if a READY_CHECK landed just before
    -- the M+ start and READY_CHECK_FINISHED never fired between them, the
    -- per-unit maps would otherwise carry into the run.
    ResetReadyCheckDeclinedTracking(ctx)
    ResetDamageMeterIfAvailable()
    ctx.captureRioBaselineSnapshot()
    if type(ctx.logRuntimeTrace) == "function" then
      ctx.logRuntimeTrace("[STATE] set_active_joined_key_map_id value=nil reason=challenge_start")
    end
    ctx.setActiveJoinedKeyMapID(nil)
    ctx.checkIfEnteredTargetDungeon()
    if ctx.shouldAutoCloseOnKeyStart() and not ctx.isRosterCollapsed() then
      ctx.setMainFrameVisible(false)
    end
    ctx.updateLeaderButtons()
    ctx.updateStatusLine()
    ctx.updateMPlusTeleportButton()
  end

  local function HandleChallengeModeCompletedOrReset(frame, event)
    if IsRaidModeActive(ctx) then
      return
    end
    ctx.handleMplusTimerEvent(event)
    ctx.handleKillTrackEvent(event)
    ctx.handleCombatEventsEvent(event)
    ctx.handleDeathWatchEvent(event)
    ctx.updateCdTracker({
      suppressBattleResReadySound = true,
      suppressLustReadySound = true,
      resetRuntimeTimers = true,
    })
    -- Clear the accepted-invite listing identity inside LFGDetect (leader /
    -- title-level / detectedMapID / acceptedInviteSearchResultID). The next
    -- key the group plays is a pre-formed-group continuation, not a fresh
    -- LFG invite — leaking the previous listing's identity would surface
    -- the wrong "+N" on the new dungeon (e.g. a +13 hint from the just-
    -- finished POS run leaking into a subsequent NPX +15 run).
    ctx.handleLFGDetectEvent(event)
    local runInfo = ResolveCompletedRunInfo()
    if type(ctx.logRuntimeTracef) == "function" then
      ctx.logRuntimeTracef(
        "[RC] challenge_mode_end mapID=%s level=%s onTime=%s",
        tostring(runInfo and runInfo.mapID),
        tostring(runInfo and runInfo.level),
        tostring(runInfo and runInfo.onTime)
      )
    end
    TryRecordCompletedRun(ctx, runInfo, POST_RUN_CAPTURE_RETRIES)

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
    CHALLENGE_MODE_COMPLETED = function(frame)
      HandleChallengeModeCompletedOrReset(frame, "CHALLENGE_MODE_COMPLETED")
    end,
    CHALLENGE_MODE_RESET = function(frame)
      HandleChallengeModeCompletedOrReset(frame, "CHALLENGE_MODE_RESET")
    end,
    READY_CHECK = function(_self, initiatorName)
      if IsRaidModeActive(ctx) then
        return
      end
      ctx.setReadyCheckActive(true)
      ResetReadyCheckDeclinedTracking(ctx)
      MarkReadyCheckInitiatorReady(ctx, initiatorName)
      LogReadyCheckTrace(ctx, "READY_CHECK", nil, nil, string.format("reset=1 initiator=%s", tostring(initiatorName)))
      RefreshReadyCheckUI(ctx)
    end,
    READY_CHECK_CONFIRM = function(_self, unit, status)
      if IsRaidModeActive(ctx) then
        return
      end
      if type(unit) ~= "string" or unit == "" then
        return
      end

      -- Blizzard fires status as a boolean (true=ready, false=notready); the
      -- "ready"/"notready" string form is kept for the test simulator. A nil
      -- value falls through to the generic-refresh branch the same way the
      -- previous string-only check did.
      local isReady = status == true or status == 1 or status == "ready"
      local isNotReady = status == false or status == 0 or status == "notready"

      if isNotReady then
        if ctx.isReadyCheckActive() then
          UpdateReadyCheckUnits(ctx, unit, nil, true)
          LogReadyCheckTrace(ctx, "READY_CHECK_CONFIRM", unit, status, "active=1")
          RefreshReadyCheckUI(ctx)
        else
          MarkReadyCheckDeclinedUnit(ctx, unit)
        end
        return
      end

      if isReady then
        if ctx.isReadyCheckActive() then
          UpdateReadyCheckUnits(ctx, unit, true, nil)
          MaybePlayReadyCheckCompleteSound(ctx)
          LogReadyCheckTrace(ctx, "READY_CHECK_CONFIRM", unit, status, "active=1")
          RefreshReadyCheckUI(ctx)
        else
          MarkReadyCheckReadyUnit(ctx, unit)
        end
        return
      end

      if ctx.isReadyCheckActive() then
        UpdateReadyCheckUnits(ctx, unit, nil, nil)
        LogReadyCheckTrace(ctx, "READY_CHECK_CONFIRM", unit, status, "active=1")
        RefreshReadyCheckUI(ctx)
      end
    end,
    READY_CHECK_FINISHED = function()
      if IsRaidModeActive(ctx) then
        return
      end
      local activeBefore = ctx.isReadyCheckActive and ctx.isReadyCheckActive() == true
      PromoteUnansweredReadyCheckUnitsToDeclined(ctx)
      local readyUnits = CollectMarkedReadyCheckUnits(ctx.readyCheckReadyUnits)
      local declinedUnits = CollectMarkedReadyCheckUnits(ctx.readyCheckDeclinedUnits)
      LogReadyCheckTrace(ctx, "READY_CHECK_FINISHED", nil, nil, "promote_hold=1")
      ctx.setReadyCheckActive(false)
      PromoteReadyCheckReadyUnitsToHold(ctx)
      PromoteDeclinedReadyCheckUnitsToHold(ctx)
      LogReadyCheckFinishHold(ctx, activeBefore, readyUnits, declinedUnits)
      RefreshReadyCheckUI(ctx)
    end,
  }
end
