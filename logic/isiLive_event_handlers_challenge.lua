local _, addonTable = ...

addonTable = addonTable or {}

local ChallengeLifecycle = {}
addonTable.EventHandlersChallengeLifecycle = ChallengeLifecycle
local ReadPlainNumber = addonTable.Validators.ReadPlainNumber
local ReadPlainBoolean = addonTable.Validators.ReadPlainBoolean
local IsSecretValue = addonTable.Validators.IsSecretValue

local POST_RUN_REFRESH_INITIAL_DELAY_SECONDS = 5
local POST_RUN_REFRESH_RETRIES = 5
local POST_RUN_REFRESH_RETRY_DELAY_SECONDS = 1
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

-- C_ChallengeMode.GetCompletionInfo was deprecated in 11.0.5 and removed in
-- 12.0.0; calling it raises "attempt to call a nil value". Its replacement
-- returns one ChallengeCompletionInfo table instead of a tuple. Reading the
-- removed function first cost the addon every completed key: the resolver
-- answered nil, so the run never reached the damage-meter snapshot and the DPS
-- column kept whatever the last successful capture had left behind.
local function GetChallengeCompletionInfoSafe()
  local challengeModeAPI = type(C_ChallengeMode) == "table" and C_ChallengeMode or nil
  if not challengeModeAPI then
    return nil, nil, nil, nil
  end

  local getChallengeCompletionInfo = rawget(challengeModeAPI, "GetChallengeCompletionInfo")
  if type(getChallengeCompletionInfo) == "function" then
    local ok, info = pcall(getChallengeCompletionInfo)
    if ok and type(info) == "table" then
      return ReadPlainNumber(info, "mapChallengeModeID"),
        ReadPlainNumber(info, "level"),
        ReadPlainNumber(info, "time"),
        ReadPlainBoolean(info, "onTime")
    end
    return nil, nil, nil, nil
  end

  -- Pre-12.0 clients still carry the tuple form.
  local getCompletionInfo = rawget(challengeModeAPI, "GetCompletionInfo")
  if type(getCompletionInfo) ~= "function" then
    return nil, nil, nil, nil
  end

  local ok, mapID, level, time, onTime = pcall(getCompletionInfo)
  if not ok then
    return nil, nil, nil, nil
  end

  return mapID, level, time, onTime
end

-- ChallengeCompletionInfo documents every numeric field as "default 0", so a
-- client with no completion to report answers mapChallengeModeID = 0 and
-- level = 0 rather than nil. Zero is truthy in Lua; without the explicit
-- bounds such a struct would be taken for a completed run.
local function ResolveCompletedRunInfo()
  local mapID, level, time, onTime = GetChallengeCompletionInfoSafe()
  mapID = tonumber(mapID)
  level = tonumber(level)
  if not (mapID and level) or mapID <= 0 or level <= 0 then
    return nil
  end

  return {
    mapID = mapID,
    level = level,
    onTime = onTime,
    signature = string.format("%s:%s:%s:%s", tostring(mapID), tostring(level), tostring(time), tostring(onTime)),
  }
end

-- Identity of the key that is currently running, read at CHALLENGE_MODE_START.
-- A key the player abandons never produces completion info, so without this the
-- run has no map id and level to record under and the whole group's damage is
-- dropped -- even though the damage meter still holds it.
local function ResolveActiveChallengeRunIdentity()
  local challengeModeAPI = type(C_ChallengeMode) == "table" and C_ChallengeMode or nil
  if not challengeModeAPI then
    return nil
  end

  local getActiveChallengeMapID = rawget(challengeModeAPI, "GetActiveChallengeMapID")
  if type(getActiveChallengeMapID) ~= "function" then
    return nil
  end
  local okMap, mapID = pcall(getActiveChallengeMapID)
  mapID = okMap and not IsSecretValue(mapID) and tonumber(mapID) or nil
  if not mapID or mapID <= 0 then
    return nil
  end

  local level = nil
  local getActiveKeystoneInfo = rawget(challengeModeAPI, "GetActiveKeystoneInfo")
  if type(getActiveKeystoneInfo) == "function" then
    local okKeystone, keystoneLevel = pcall(getActiveKeystoneInfo)
    level = okKeystone and not IsSecretValue(keystoneLevel) and tonumber(keystoneLevel) or nil
  end

  return {
    mapID = mapID,
    level = level or 0,
    onTime = false,
    signature = string.format("abandoned:%s:%s", tostring(mapID), tostring(level or 0)),
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
    ctx.activeChallengeRunIdentity = nil
    return true
  end

  ScheduleCompletedRunRetry(ctx, runInfo, retriesRemaining or POST_RUN_CAPTURE_RETRIES)
  return false
end

-- Banner verdict of a completed key. An unreadable onTime has no verdict.
local function ResolveCompletionOutcome(runInfo)
  if type(runInfo) ~= "table" or type(runInfo.onTime) ~= "boolean" then
    return nil
  end
  return runInfo.onTime and "timed" or "late"
end

-- The banner ends on its own after a fixed time, and with the session on a
-- reload or a new login. A key start and a newly joined group end it earlier
-- (rule 231).
local function ClearKeyEndBanner(ctx)
  ctx.keyEndBannerActive = false
  ctx.clearKeyEndOutcome()
end

local function ShowKeyEndBanner(ctx, outcome)
  ctx.keyEndBannerActive = true
  ctx.keyEndBannerInGroup = ctx.isInGroup() == true
  ctx.showKeyEndOutcome(outcome)
end

-- Follows the group state while a banner may stand.
function ChallengeLifecycle.UpdateKeyEndBannerForGroup(ctx)
  if ctx.keyEndBannerActive ~= true then
    return
  end
  local inGroup = ctx.isInGroup() == true
  local wasInGroup = ctx.keyEndBannerInGroup
  ctx.keyEndBannerInGroup = inGroup
  if inGroup and not wasInGroup then
    ClearKeyEndBanner(ctx)
  end
end

-- Leaving the group ends the player's run at once, while the instance and the
-- active challenge map stay for a grace period, so this runs from the roster
-- update as well. A key started solo has no group to leave, and a finished key
-- whose completion data is still on its way is not a departure.
function ChallengeLifecycle.ShowKeyLeftIfGroupGone(ctx)
  local identity = ctx.activeChallengeRunIdentity
  if
    type(identity) ~= "table"
    or identity.startedInGroup ~= true
    or identity.leftShown == true
    or ctx.awaitingCompletionInfo == true
    or ctx.isInGroup()
  then
    return false
  end
  identity.leftShown = true
  ShowKeyEndBanner(ctx, "left")
  return true
end

-- Records the run of a key that ended without completion info: abandoned,
-- depleted-and-left, or left mid-run. The identity comes from the stash taken
-- at CHALLENGE_MODE_START, the damage still from the live meter, which keeps
-- the session well past the point where the group breaks up. Recording a
-- completed run clears the stash, so a finished key never reaches this path.
-- `outcome` is the banner for a run the player did not leave; walking out of
-- the instance passes none, because the key goes on for the group.
function ChallengeLifecycle.TryRecordAbandonedRun(ctx, outcome)
  local identity = ctx.activeChallengeRunIdentity
  if type(identity) ~= "table" then
    return false
  end
  if ctx.isInChallengeMode and ctx.isInChallengeMode() then
    return false
  end

  ChallengeLifecycle.ShowKeyLeftIfGroupGone(ctx)
  if outcome and identity.leftShown ~= true then
    ShowKeyEndBanner(ctx, outcome)
  end
  ctx.activeChallengeRunIdentity = nil
  if type(ctx.logRuntimeTracef) == "function" then
    ctx.logRuntimeTracef(
      "[RC] challenge_mode_abandoned mapID=%s level=%s",
      tostring(identity.mapID),
      tostring(identity.level)
    )
  end

  return TryRecordCompletedRun(ctx, identity, POST_RUN_CAPTURE_RETRIES)
end

-- One delayed refresh with retries. The former follow-up refreshes (6 s after a
-- successful refresh) always hit the 10 s refresh debounce and never refreshed
-- anything; they were removed in 0.9.417.
--
-- Every run owns one chain: `chain` is the token of the key end that started
-- it, and a callback whose token is no longer current belongs to an older run.
local function RunDelayedPostChallengeRefresh(ctx, frame, retriesRemaining, chain)
  if chain ~= ctx.postRunRefreshChain then
    return
  end

  if IsRaidModeActive(ctx) then
    SetPendingPostChallengeRefresh(ctx, {
      frame = frame,
      retriesRemaining = retriesRemaining,
      chain = chain,
    })
    return
  end

  SetPendingPostChallengeRefresh(ctx, nil)
  if not ctx.isInGroup() then
    -- Leaving the group before the delayed callback lands is the same rule-4
    -- situation as an exhausted retry chain: no refresh ran, so no post-run
    -- RIO was ever fetched and any delta would be computed against the pre-run
    -- snapshot. There is nothing left to refresh either -- the roster the
    -- delta describes is gone -- so this returns without enabling.
    ctx.postRunRefreshChain = nil
    return
  end

  -- Known peers survive the run; their HELLOs then fall under the known-peer
  -- fan-out window instead of drawing one full fan-out per peer. The click
  -- debounce does not apply: a Re-Sync press right after the key ended must
  -- not block the one refresh rule 4 waits for.
  local refreshed = ctx.runFullRefresh({ keepKnownPeers = true, ignoreDebounce = true }) ~= false

  if not refreshed and retriesRemaining > 0 and ctx.timerAfter then
    ctx.timerAfter(POST_RUN_REFRESH_RETRY_DELAY_SECONDS, function()
      RunDelayedPostChallengeRefresh(ctx, frame, retriesRemaining - 1, chain)
    end)
    return
  end

  -- Rule 4: the delta may only appear after a refresh that actually succeeded.
  -- Falling through here with `refreshed == false` means the retries ran out,
  -- not that the data arrived -- enabling the display then shows a delta
  -- computed against a pre-run snapshot that was never updated.
  if refreshed then
    ctx.enableRioDeltaDisplay()
  else
    -- Rule 4 is still waiting for a success, so a later key-end event of this
    -- run may start over. A successful chain stays in place and keeps the
    -- other key-end event of the same run from refreshing again.
    ctx.postRunRefreshChain = nil
  end
  RefreshRosterAfterRunStateChange(ctx, frame)
end

-- COMPLETED and the RESET that follows it end the same run; whichever arrives
-- first starts the chain and the other one joins it. A run ends with at most
-- one of each, so a repeated event belongs to another run, even one whose
-- CHALLENGE_MODE_START was never seen here (joined as a replacement).
local function StartPostRunRefreshChain(ctx, frame, event)
  local current = ctx.postRunRefreshChain
  if current and not current[event] then
    current[event] = true
    return
  end

  SetPendingPostChallengeRefresh(ctx, nil)
  local chain = { [event] = true }
  ctx.postRunRefreshChain = chain
  if ctx.timerAfter then
    ctx.timerAfter(POST_RUN_REFRESH_INITIAL_DELAY_SECONDS, function()
      RunDelayedPostChallengeRefresh(ctx, frame, POST_RUN_REFRESH_RETRIES, chain)
    end)
    return
  end

  RunDelayedPostChallengeRefresh(ctx, frame, 0, chain)
end

-- True when completion info names another key than the run stashed at start.
-- Without a stash nothing can contradict it.
local function CompletionContradictsRun(runInfo, identity)
  return type(runInfo) == "table"
    and type(identity) == "table"
    and (runInfo.mapID ~= identity.mapID or (identity.level > 0 and runInfo.level ~= identity.level))
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
    pending.chain
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
    ClearKeyEndBanner(ctx)
    if IsRaidModeActive(ctx) then
      return
    end
    ctx.handleMplusTimerEvent("CHALLENGE_MODE_START")
    ctx.handleKillTrackEvent("CHALLENGE_MODE_START")
    ctx.handleCombatEventsEvent("CHALLENGE_MODE_START")
    ctx.handleDeathWatchEvent("CHALLENGE_MODE_START")
    ctx.handleLFGDetectEvent("CHALLENGE_MODE_START")
    if type(ctx.clearTrackedPartyRunInfo) == "function" then
      ctx.clearTrackedPartyRunInfo()
    end
    if type(ctx.logRuntimeTrace) == "function" then
      ctx.logRuntimeTrace("[RC] challenge_mode_start state_set var=readyCheckActive val=false")
    end
    SetPendingPostChallengeRefresh(ctx, nil)
    ctx.postRunRefreshChain = nil
    if type(ctx.resetKickStats) == "function" then
      ctx.resetKickStats()
    end
    ctx.lastRecordedRunSignature = nil
    ctx.lastRecordedRunCaptured = false
    ctx.pendingRecordedRunRetrySignature = nil
    ctx.awaitingCompletionInfo = false
    ctx.activeChallengeRunIdentity = ResolveActiveChallengeRunIdentity()
    if ctx.activeChallengeRunIdentity then
      ctx.activeChallengeRunIdentity.startedInGroup = ctx.isInGroup() == true
    end
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
    local identity = ctx.activeChallengeRunIdentity
    if event == "CHALLENGE_MODE_RESET" then
      -- A reset carries no completion of its own, and the struct keeps the last
      -- finished key: equal map and level do not prove it belongs to this run.
      -- It only counts while COMPLETED fired without data for this very run.
      local awaitingCompletionInfo = ctx.awaitingCompletionInfo
      ctx.awaitingCompletionInfo = false
      if not awaitingCompletionInfo or CompletionContradictsRun(runInfo, identity) then
        runInfo = nil
      elseif runInfo then
        -- Same ownership step as below: from here on the completion path holds
        -- the run, also while its capture still waits for a retry.
        ctx.activeChallengeRunIdentity = nil
      end
    elseif CompletionContradictsRun(runInfo, identity) then
      -- The struct still names the previous key; this run's data may follow by
      -- the reset, and until then the stash stays the run's only identity.
      runInfo = nil
      ctx.awaitingCompletionInfo = true
    elseif runInfo then
      -- The run has real completion info, so the completion path owns it. The
      -- stash is dropped now rather than on a successful capture: while a
      -- capture retry is still pending, the following reset must not record the
      -- same key a second time as abandoned.
      ctx.activeChallengeRunIdentity = nil
    else
      ctx.awaitingCompletionInfo = true
    end
    if type(ctx.logRuntimeTracef) == "function" then
      ctx.logRuntimeTracef(
        "[RC] challenge_mode_end mapID=%s level=%s onTime=%s",
        tostring(runInfo and runInfo.mapID),
        tostring(runInfo and runInfo.level),
        tostring(runInfo and runInfo.onTime)
      )
    end
    TryRecordCompletedRun(ctx, runInfo, POST_RUN_CAPTURE_RETRIES)

    -- An auto-open that actually showed the window already ran the in-group
    -- roster refresh through its show callback; the same refresh again in the
    -- same frame is skipped.
    local autoOpenedWithRefresh = false
    if ctx.isInGroup() and ctx.shouldAutoOpenMainFrameOnKeyEnd() then
      autoOpenedWithRefresh = ctx.setMainFrameVisible(true) == true
    end
    if not autoOpenedWithRefresh then
      RefreshRosterAfterRunStateChange(ctx, frame)
    end
    -- After the auto-open above, so the banner finds its row on screen.
    local outcome = ResolveCompletionOutcome(runInfo)
    if outcome then
      ShowKeyEndBanner(ctx, outcome)
    end
    ctx.updateStatusLine()
    ctx.notifyPostChallengeSync()
    StartPostRunRefreshChain(ctx, frame, event)
  end

  return {
    CHALLENGE_MODE_START = HandleChallengeModeStart,
    CHALLENGE_MODE_COMPLETED = function(frame)
      HandleChallengeModeCompletedOrReset(frame, "CHALLENGE_MODE_COMPLETED")
    end,
    CHALLENGE_MODE_RESET = function(frame)
      -- COMPLETED already fired for this run: its reset is no abandoned key,
      -- even when the completion data never arrives.
      local completed = ctx.awaitingCompletionInfo == true
      HandleChallengeModeCompletedOrReset(frame, "CHALLENGE_MODE_RESET")
      ChallengeLifecycle.TryRecordAbandonedRun(ctx, not completed and "abandoned" or nil)
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
