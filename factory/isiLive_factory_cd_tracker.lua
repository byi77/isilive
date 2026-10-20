local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local LUST_READY_REMINDER_SECONDS = 60
-- The "Bloodlust ready in 10 seconds" voice alert fires once per Sated cycle
-- when the observed remain first drops to this value.
local LUST_SOON_SECONDS = 10
-- Wake-ups land slightly after the moment they target, so the scan sees the
-- remain crossed and not a few milliseconds short of it.
local LUST_WAKE_MARGIN_SECONDS = 0.25

-- One UpdateCdTracker pass asks for the combat-utility context up to five
-- times (directly, through GetBResInfo / GetLustInfo of the row refresh, and
-- through the polling check). Outside a running key every answer costs a full
-- RuntimeMode resolve with a GetInstanceInfo read, so the pass memoizes it.
-- The memo lives only while a pass is on the stack -- never across events, so
-- a context change between two events cannot be answered from a stale value.
-- Passes are re-entrant (a hidden-frame pass renders the roster, whose CD row
-- calls back in); only the outermost one opens and closes the memo. The time
-- stamp bounds a pass that raised before closing it to the frame it ran in.
local function CreatePassMemo(resolve, getTime)
  local depth = 0
  local value = nil
  local stamp = nil
  local memo = {}

  function memo.Get()
    if depth <= 0 then
      return resolve()
    end
    local now = getTime()
    if value ~= nil and stamp == now then
      return value
    end
    value = resolve()
    stamp = now
    return value
  end

  function memo.Run(fn, arg)
    if depth <= 0 then
      depth = 0
      value = nil
    end
    depth = depth + 1
    fn(arg)
    depth = depth - 1
    if depth <= 0 then
      depth = 0
      value = nil
    end
  end

  return memo
end

-- Calls an optional SoundUtils playback helper; false when it is missing.
local function PlaySoundUtil(ctx, fnName)
  local soundUtils = ctx.addonTable and ctx.addonTable.SoundUtils
  if type(soundUtils) == "table" and type(soundUtils[fnName]) == "function" then
    soundUtils[fnName]()
    return true
  end
  return false
end

-- Seconds from now until the next Lust alert is due, or nil when none is:
-- the 10-second warning, the expiry, a short retry while an expired timer is
-- not confirmed yet, or the next 60-second reminder.
local function NextLustWakeDelay(state)
  if state.timerDisplayed then
    if state.remain > LUST_SOON_SECONDS and not state.soonWarned then
      return state.remain - LUST_SOON_SECONDS
    end
    return state.remain
  end
  if state.lastDisplayed then
    return 1
  end
  if state.lastReadyAt ~= nil and state.reminderEnabled then
    return math.max(0, state.lastReadyAt + LUST_READY_REMINDER_SECONDS - state.now)
  end
  return nil
end

-- One pending one-shot wake-up for the Lust alerts. The 1s CD ticker only
-- runs while the main frame is shown; these wake-ups make the 10-second
-- warning, the ready alert and the 60-second reminder fire on time with a
-- hidden frame too. A newer target supersedes the pending one through the
-- generation counter.
local function CreateLustWakeScheduler(getTime, timerApi, onWake)
  local generation = 0
  local wakeAt = nil
  local scheduler = {}

  function scheduler.Cancel()
    generation = generation + 1
    wakeAt = nil
  end

  function scheduler.Schedule(delay)
    if delay == nil then
      scheduler.Cancel()
      return
    end
    local after = type(timerApi) == "table" and timerApi.After or nil
    if type(after) ~= "function" then
      return
    end
    local target = getTime() + delay + LUST_WAKE_MARGIN_SECONDS
    -- The visible 1s ticker recomputes the same target every pass; keep the
    -- pending wake-up instead of stacking a new timer per second.
    if wakeAt ~= nil and math.abs(wakeAt - target) < 0.5 then
      return
    end
    scheduler.Cancel()
    wakeAt = target
    local scheduled = generation
    after(delay + LUST_WAKE_MARGIN_SECONDS, function()
      if scheduled ~= generation then
        return
      end
      wakeAt = nil
      onWake()
    end)
  end

  return scheduler
end

-- The 60-second Bloodlust-ready reminder is on unless explicitly disabled.
-- Falls back to the DB table seen at init when the global is not a table.
local function IsBloodlustReadyReminderEnabled(initialDBRef)
  local db = rawget(_G, "IsiLiveDB")
  if type(db) ~= "table" then
    db = initialDBRef
  end
  return not (type(db) == "table" and db.soundBloodlustReadyReminderEnabled == false)
end

local function IsMplusTimerRunning(ctx)
  local MplusTimer = ctx.addonTable and ctx.addonTable.MplusTimer
  if type(MplusTimer) == "table" and type(MplusTimer.IsRunning) == "function" then
    return MplusTimer.IsRunning() == true
  end
  if type(MplusTimer) == "table" and type(MplusTimer.GetTimerData) == "function" then
    local timerData = MplusTimer.GetTimerData()
    if timerData and timerData.running then
      return true
    end
  end
  return false
end

-- BRes / Bloodlust tracking is a Mythic+ utility and only runs in the full
-- runtime profile (active keystone or M0). A tracked party run alone is not
-- enough any more: normal, heroic and timewalking runs are tracked for the
-- last-run DPS snapshot, but must not start the 1s CD poll. Fails closed
-- when the resolver is missing.
local function IsFullProfileActive(ctx)
  -- Running keystone: answered by the injected bridge, which stays valid in
  -- every call context. The wider M0 / pre-insert case can only be read from
  -- live instance data, so it goes through the central resolver.
  if type(ctx.GetActiveChallengeMapID) == "function" then
    local okBridge, mapID = pcall(ctx.GetActiveChallengeMapID)
    if okBridge and not addonTable.Validators.IsSecretValue(mapID) then
      local numeric = tonumber(mapID)
      if numeric and numeric > 0 then
        return true
      end
    end
  end
  local runtimeMode = addonTable.RuntimeMode
  if type(runtimeMode) ~= "table" or type(runtimeMode.IsFullProfileContext) ~= "function" then
    return false
  end
  local ok, isFullProfile = pcall(runtimeMode.IsFullProfileContext)
  return ok and isFullProfile == true
end

local function IsActiveChallengeContext(ctx)
  if type(ctx.GetActiveChallengeMapID) ~= "function" then
    return true
  end
  local ok, mapID = pcall(ctx.GetActiveChallengeMapID)
  if not ok or addonTable.Validators.IsSecretValue(mapID) or mapID == nil then
    return false
  end
  return true
end

local function IsGroupedUtilityContext(ctx)
  if type(ctx.isInGroup) == "function" and ctx.isInGroup() == true then
    return true
  end
  if type(ctx.isInInstanceGroup) == "function" and ctx.isInInstanceGroup() == true then
    return true
  end
  return false
end

-- Plays one Lust alert and writes its outcome to the runtime log, so a
-- missing in-game announcement can be told apart from a muted or rejected
-- playback.
local function PlayLustAlert(ctx, fnName, label)
  local played = PlaySoundUtil(ctx, fnName)
  local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
  if type(logf) == "function" then
    local soundUtils = ctx.addonTable and ctx.addonTable.SoundUtils
    local result = type(soundUtils) == "table"
        and type(soundUtils.GetLastPlayResult) == "function"
        and soundUtils.GetLastPlayResult()
      or nil
    logf(
      "[LUST] %s played=%s reason=%s",
      label,
      tostring(played),
      tostring(type(result) == "table" and result.reason or nil)
    )
  end
  return played
end

local function DescribeAura(aura)
  if addonTable.Validators.IsSecretValue(aura) or type(aura) ~= "table" then
    return "secret"
  end
  local spellID = addonTable.Validators.ReadPlainNumber(aura, "spellId")
  local expiry = addonTable.Validators.ReadPlainNumber(aura, "expirationTime")
  return string.format("id=%s exp=%s", tostring(spellID or "secret"), tostring(expiry or "secret"))
end

local function DescribeHarmfulSlot(index)
  local api = rawget(_G, "C_UnitAuras")
  local readAura = type(api) == "table" and rawget(api, "GetAuraDataByIndex") or nil
  if type(readAura) ~= "function" then
    return "api-missing"
  end
  local ok, aura = pcall(readAura, "player", index, "HARMFUL")
  if not ok then
    return "error"
  end
  if addonTable.Validators.IsSecretValue(aura) then
    return "secret"
  end
  if aura == nil then
    return nil
  end
  return DescribeAura(aura)
end

-- The aura list the Lust scan reads first (see CdTracker.ReadLustAuras).
local function DescribeUnitAuraList(Line)
  local api = rawget(_G, "C_UnitAuras")
  local getUnitAuras = type(api) == "table" and rawget(api, "GetUnitAuras") or nil
  if type(getUnitAuras) ~= "function" then
    Line("unitAuras: api-missing")
    return
  end
  local ok, list = pcall(getUnitAuras, "player", "HARMFUL")
  if not ok or addonTable.Validators.IsSecretValue(list) or type(list) ~= "table" then
    Line("unitAuras: %s", ok and "unreadable" or "error")
    return
  end
  Line("unitAuras: %d entries", #list)
  for index = 1, math.min(#list, 40) do
    Line("unitAuras[%d] %s", index, DescribeAura(list[index]))
  end
end

-- `/isilive bldump`: one chat snapshot of everything the Bloodlust alerts
-- depend on -- key context, what the aura scan sees, alert state, settings
-- and the last playback result.
local function PrintLustDump(ctx, printFn, state)
  local function Line(fmt, ...)
    printFn(string.format("[BL] " .. fmt, ...))
  end
  local controller = ctx.cdTrackerController
  local info = controller and type(controller.GetLustInfo) == "function" and controller.GetLustInfo() or nil
  Line(
    "context: mplusTimer=%s grouped=%s activeKey=%s",
    tostring(IsMplusTimerRunning(ctx)),
    tostring(IsGroupedUtilityContext(ctx)),
    tostring(IsActiveChallengeContext(ctx))
  )
  Line(
    "tracker: resolved=%s remain=%s",
    tostring(controller and type(controller.IsLustScanResolved) == "function" and controller.IsLustScanResolved()),
    tostring(type(info) == "table" and info.remain or nil)
  )
  local api = rawget(_G, "C_UnitAuras")
  local lookup = type(api) == "table" and rawget(api, "GetPlayerAuraBySpellID") or nil
  if type(lookup) == "function" then
    for _, record in ipairs(addonTable.SpellManifest.lustSated) do
      local ok, aura = pcall(lookup, record.id)
      local description = "error"
      if ok then
        if addonTable.Validators.IsSecretValue(aura) then
          description = "secret"
        elseif aura == nil then
          description = "absent"
        else
          description = DescribeAura(aura)
        end
      end
      Line("direct[%d] %s", record.id, description)
    end
  else
    Line("direct: api-missing")
  end
  DescribeUnitAuraList(Line)
  for index = 1, 40 do
    local slot = DescribeHarmfulSlot(index)
    if slot == nil then
      Line("harmful slots: %d readable end", index - 1)
      break
    end
    Line("harmful[%d] %s", index, slot)
    if slot == "error" or slot == "api-missing" then
      break
    end
  end
  Line(
    "state: lastTimer=%s soonWarned=%s readyAt=%s now=%s",
    tostring(state.lastDisplayed),
    tostring(state.soonWarned),
    tostring(state.lastReadyAt),
    tostring(state.now)
  )
  local db = rawget(_G, "IsiLiveDB")
  db = type(db) == "table" and db or {}
  Line(
    "settings: soon=%s ready=%s reminder=%s channel=%s",
    tostring(db.soundBloodlustSoonEnabled),
    tostring(db.soundBloodlustReadyEnabled),
    tostring(db.soundBloodlustReadyReminderEnabled),
    tostring(db.soundOutputChannel)
  )
  local soundUtils = ctx.addonTable and ctx.addonTable.SoundUtils
  local result = type(soundUtils) == "table"
      and type(soundUtils.GetLastPlayResult) == "function"
      and soundUtils.GetLastPlayResult()
    or nil
  if type(result) == "table" then
    Line(
      "last sound: ok=%s reason=%s path=%s",
      tostring(result.ok),
      tostring(result.reason),
      tostring(result.path or result.soundKit)
    )
  end
end

local function InitializeFactorySecondaryCdTracker(
  ctx,
  modules,
  runtimeState,
  getTime,
  IsMainFrameShown,
  IsRaidModeActive
)
  if not (modules.cdTracker and type(modules.cdTracker.CreateController) == "function") then
    return
  end

  ctx.cdTrackerController = modules.cdTracker.CreateController({
    getTime = getTime,
  })
  local lastBResCharges = nil
  local lastBResCooldownRemain = nil
  local lastMplusRunning = false
  local lastLustDisplayedTimer = false
  local lustReadyDisplayActive = false
  local lastLustReadySoundAt = nil
  local lustSoonWarned = false
  local initialDBRef = rawget(_G, "IsiLiveDB")
  local C_Timer_ref = rawget(_G, "C_Timer")
  local cdPollingTicker = nil
  local lustWake = CreateLustWakeScheduler(getTime, C_Timer_ref, function()
    ctx.UpdateCdTracker()
  end)
  local function ClearReadySoundState()
    lastBResCharges = nil
    lastBResCooldownRemain = nil
    lastLustDisplayedTimer = false
    lustReadyDisplayActive = false
    lastLustReadySoundAt = nil
    lustSoonWarned = false
    lustWake.Cancel()
  end

  local function IsTrackedPartyRunActive()
    if runtimeState and type(runtimeState.IsTrackedPartyRunActive) == "function" then
      return runtimeState.IsTrackedPartyRunActive() == true
    end
    if type(ctx.IsTrackedPartyRunActive) == "function" then
      return ctx.IsTrackedPartyRunActive() == true
    end
    return false
  end

  local function ResolveCombatUtilityContextActive()
    -- A running key timer is itself proof of the full profile; no second
    -- opinion needed. The tracked-party-run branch does need one: it also
    -- covers normal, heroic and timewalking runs, which are tracked for the
    -- last-run DPS snapshot but must not start the 1s CD poll.
    if IsMplusTimerRunning(ctx) then
      return true
    end
    if not IsFullProfileActive(ctx) then
      return false
    end
    return IsTrackedPartyRunActive()
  end

  local contextMemo = CreatePassMemo(ResolveCombatUtilityContextActive, getTime)
  local IsCombatUtilityContextActive = contextMemo.Get

  local function StopCdTrackerPolling()
    if cdPollingTicker and type(cdPollingTicker.Cancel) == "function" then
      cdPollingTicker:Cancel()
    end
    cdPollingTicker = nil
  end

  local function NeedsCdTrackerPolling()
    if not IsMainFrameShown() then
      return false
    end
    if IsCombatUtilityContextActive() then
      return true
    end
    if ctx.cdTrackerController and type(ctx.cdTrackerController.GetLustInfo) == "function" then
      local lustInfo = ctx.cdTrackerController.GetLustInfo()
      return lustInfo and tonumber(lustInfo.remain) and lustInfo.remain > 0 or false
    end
    return false
  end

  local function RefreshCdTrackerPolling()
    if IsRaidModeActive() or not NeedsCdTrackerPolling() then
      StopCdTrackerPolling()
      return false
    end
    if cdPollingTicker then
      return true
    end
    if type(C_Timer_ref) ~= "table" or type(C_Timer_ref.NewTicker) ~= "function" then
      return false
    end
    cdPollingTicker = C_Timer_ref.NewTicker(1.0, function()
      if not NeedsCdTrackerPolling() then
        StopCdTrackerPolling()
        return
      end
      ctx.UpdateCdTracker()
    end)
    return cdPollingTicker ~= nil
  end

  ctx.RefreshCdTrackerPolling = RefreshCdTrackerPolling
  ctx.StopCdTrackerPolling = StopCdTrackerPolling

  local function IsLustScanResolved()
    return ctx.cdTrackerController
        and type(ctx.cdTrackerController.IsLustScanResolved) == "function"
        and ctx.cdTrackerController.IsLustScanResolved() == true
      or false
  end

  local function UpdateCdTrackerPass(opts)
    local optsTable = type(opts) == "table" and opts or nil
    local suppressBattleResReadySound = optsTable and optsTable.suppressBattleResReadySound == true
    local suppressLustReadySound = optsTable and optsTable.suppressLustReadySound == true
    local resetRuntimeTimers = optsTable and optsTable.resetRuntimeTimers == true
    local fromVisibleRender = optsTable and optsTable.fromVisibleRender == true
    if IsRaidModeActive() then
      StopCdTrackerPolling()
      ClearReadySoundState()
      if ctx.cdTrackerController and type(ctx.cdTrackerController.ClearRuntimeData) == "function" then
        ctx.cdTrackerController.ClearRuntimeData()
      end
      lastMplusRunning = false
      return
    end
    local mplusRunning = IsMplusTimerRunning(ctx)
    local combatUtilityContextActive = IsCombatUtilityContextActive()
    local readySoundContextActive = mplusRunning and IsGroupedUtilityContext(ctx) and IsActiveChallengeContext(ctx)
    if mplusRunning and not lastMplusRunning then
      lastBResCharges = nil
      lastBResCooldownRemain = nil
    end
    if resetRuntimeTimers or not combatUtilityContextActive then
      ClearReadySoundState()
      if ctx.cdTrackerController and type(ctx.cdTrackerController.ClearRuntimeData) == "function" then
        ctx.cdTrackerController.ClearRuntimeData()
      end
    elseif ctx.cdTrackerController and type(ctx.cdTrackerController.Scan) == "function" then
      ctx.cdTrackerController.Scan()
    end
    local bresInfo = ctx.cdTrackerController
        and type(ctx.cdTrackerController.GetBResInfo) == "function"
        and ctx.cdTrackerController.GetBResInfo()
      or nil
    local bresCharges = type(bresInfo) == "table" and tonumber(bresInfo.charges) or nil
    local bresCooldownRemain = type(bresInfo) == "table" and tonumber(bresInfo.cooldownRemain) or nil
    if not readySoundContextActive then
      ClearReadySoundState()
    end
    local bresChargesIncreased = lastBResCharges ~= nil and bresCharges ~= nil and bresCharges > lastBResCharges
    local bresDisplayedCooldownExpired = lastBResCooldownRemain ~= nil
      and lastBResCooldownRemain > 0
      and bresCooldownRemain ~= nil
      and bresCooldownRemain <= 0
    if
      (bresChargesIncreased or bresDisplayedCooldownExpired)
      and readySoundContextActive
      and not suppressBattleResReadySound
    then
      PlaySoundUtil(ctx, "PlayBattleResReady")
    end
    if suppressBattleResReadySound or not readySoundContextActive then
      lastBResCharges = nil
      lastBResCooldownRemain = nil
    else
      lastBResCharges = bresCharges
      lastBResCooldownRemain = bresCooldownRemain
    end
    lastMplusRunning = mplusRunning
    local lustInfo = ctx.cdTrackerController
        and type(ctx.cdTrackerController.GetLustInfo) == "function"
        and ctx.cdTrackerController.GetLustInfo()
      or nil
    local lustRemain = type(lustInfo) == "table" and tonumber(lustInfo.remain) or nil
    local lustResolved = IsLustScanResolved()
    -- An unresolved scan only pauses ready transitions and reminders; keep the
    -- reminder clock so a later resolved scan resumes the confirmed ready cycle.
    local lustTimerDisplayed = lustRemain ~= nil and lustRemain > 0
    if lustTimerDisplayed then
      lastLustReadySoundAt = nil
      lustReadyDisplayActive = false
      lustSoonWarned = lustSoonWarned and lustRemain <= LUST_SOON_SECONDS
    end
    if
      readySoundContextActive
      and lustResolved
      and lustTimerDisplayed
      and lustRemain <= LUST_SOON_SECONDS
      and not lustSoonWarned
      and not suppressLustReadySound
    then
      lustSoonWarned = true
      PlayLustAlert(ctx, "PlayBloodlustSoon", "soon")
    end
    if
      lustTimerDisplayed
      and not lastLustDisplayedTimer
      and readySoundContextActive
      and type(opts) == "table"
      and opts.playLustSoundOnStart == true
    then
      PlaySoundUtil(ctx, "PlayBloodlust")
    end
    if
      readySoundContextActive
      and lustResolved
      and lastLustDisplayedTimer
      and not lustTimerDisplayed
      and not suppressLustReadySound
    then
      if PlayLustAlert(ctx, "PlayBloodlustReady", "ready") then
        lastLustReadySoundAt = getTime()
        lustReadyDisplayActive = true
      end
    elseif
      readySoundContextActive
      and lustResolved
      and not lustTimerDisplayed
      and not suppressLustReadySound
      and lastLustReadySoundAt ~= nil
      and IsBloodlustReadyReminderEnabled(initialDBRef)
      and getTime() - lastLustReadySoundAt >= LUST_READY_REMINDER_SECONDS
    then
      if PlayLustAlert(ctx, "PlayBloodlustReady", "reminder") then
        lastLustReadySoundAt = getTime()
      end
    end
    if suppressLustReadySound or not readySoundContextActive then
      lastLustDisplayedTimer = false
      lustReadyDisplayActive = false
      lastLustReadySoundAt = nil
    elseif lustResolved then
      lastLustDisplayedTimer = lustTimerDisplayed
    end
    if suppressLustReadySound or not readySoundContextActive then
      lustWake.Cancel()
    else
      lustWake.Schedule(NextLustWakeDelay({
        timerDisplayed = lustTimerDisplayed,
        remain = lustRemain,
        soonWarned = lustSoonWarned,
        lastDisplayed = lastLustDisplayedTimer,
        lastReadyAt = lastLustReadySoundAt,
        reminderEnabled = IsBloodlustReadyReminderEnabled(initialDBRef),
        now = getTime(),
      }))
    end
    if
      not fromVisibleRender
      and ctx.rosterPanelController
      and type(ctx.rosterPanelController.RefreshCdTracker) == "function"
    then
      ctx.rosterPanelController.RefreshCdTracker()
    end
    if
      runtimeState
      and type(runtimeState.IsReadyCheckActive) == "function"
      and type(runtimeState.HasReadyCheckHold) == "function"
      and (runtimeState.IsReadyCheckActive() or runtimeState.HasReadyCheckHold())
      and ctx.rosterPanelController
      and type(ctx.rosterPanelController.RefreshReadyCheckState) == "function"
    then
      ctx.rosterPanelController.RefreshReadyCheckState(ctx.GetRoster())
    end
    -- The targeted CD-row refresh above already advances the visible M+ timer.
    -- Keep the full render only for hidden event-driven pre-rendering; the
    -- visible one-second ticker must not rebuild the complete roster/layout.
    if mplusRunning and not fromVisibleRender and not IsMainFrameShown() then
      if ctx.UpdateUI then
        ctx.UpdateUI()
      end
    end
    RefreshCdTrackerPolling()
  end

  ctx.UpdateCdTracker = function(opts)
    contextMemo.Run(UpdateCdTrackerPass, opts)
  end
  if ctx.rosterPanelController and type(ctx.rosterPanelController.SetCdController) == "function" then
    local uiCdController = {
      Scan = function()
        ctx.UpdateCdTracker({ fromVisibleRender = true })
      end,
      GetBResInfo = function()
        if not IsCombatUtilityContextActive() or not IsGroupedUtilityContext(ctx) then
          return nil
        end
        return ctx.cdTrackerController
            and type(ctx.cdTrackerController.GetBResInfo) == "function"
            and ctx.cdTrackerController.GetBResInfo()
          or nil
      end,
      GetLustInfo = function()
        if not IsCombatUtilityContextActive() or not IsGroupedUtilityContext(ctx) then
          return nil
        end
        local info = ctx.cdTrackerController
            and type(ctx.cdTrackerController.GetLustInfo) == "function"
            and ctx.cdTrackerController.GetLustInfo()
          or nil
        if info ~= nil then
          return info
        end
        if
          lustReadyDisplayActive
          and IsLustScanResolved()
          and IsMplusTimerRunning(ctx)
          and IsGroupedUtilityContext(ctx)
        then
          return { remain = 0 }
        end
        return nil
      end,
    }
    ctx.rosterPanelController.SetCdController(uiCdController)
  end

  addonTable.LustDebug = {
    PrintDump = function(printFn)
      PrintLustDump(ctx, printFn, {
        lastDisplayed = lastLustDisplayedTimer,
        soonWarned = lustSoonWarned,
        lastReadyAt = lastLustReadySoundAt,
        now = getTime(),
      })
    end,
  }

  -- Subscribe the kill-track row to state updates so the pull bar refreshes
  -- on every scenario tick / combat transition instead of only on roster
  -- renders (which fire on sync events, not on scenario progress).
  local killTrack = ctx.addonTable and ctx.addonTable.KillTrack
  if type(killTrack) == "table" then
    if type(killTrack.OnUpdate) == "function" then
      killTrack.OnUpdate(function()
        if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshKillTrackRow) == "function" then
          ctx.rosterPanelController.RefreshKillTrackRow()
        end
        local mobNameplate = ctx.addonTable and ctx.addonTable.MobNameplate
        if type(mobNameplate) == "table" and type(mobNameplate.RefreshActive) == "function" then
          mobNameplate.RefreshActive()
        elseif type(mobNameplate) == "table" and type(mobNameplate.RefreshAll) == "function" then
          mobNameplate.RefreshAll()
        end
      end)
    end
    -- Forward API-vs-DB total drift warnings into the runtime log so they
    -- surface in /isilive log dump without spamming chat.
    if type(killTrack.SetDebugLogger) == "function" then
      killTrack.SetDebugLogger(function(fmt, ...)
        if ctx.runtimeLogController and type(ctx.runtimeLogController.Logf) == "function" then
          ctx.runtimeLogController.Logf(fmt, ...)
        end
      end)
    end
  end
  -- Ticker: scan + UI refresh every second for countdown timers (BL remaining time).
  -- Gated on the M+ key being active OR a Bloodlust countdown still running, so
  -- a freshly opened main frame in town does not burn 40 pcall(GetAuraDataByIndex)
  -- and a full roster render every second for state that cannot change.
  RefreshCdTrackerPolling()
end

FI.InitializeFactorySecondaryCdTracker = InitializeFactorySecondaryCdTracker

return {
  InitializeFactorySecondaryCdTracker = InitializeFactorySecondaryCdTracker,
}
