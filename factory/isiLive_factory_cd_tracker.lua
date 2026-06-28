local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local LUST_READY_REMINDER_SECONDS = 60

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
  local initialDBRef = rawget(_G, "IsiLiveDB")
  local function ClearReadySoundState()
    lastBResCharges = nil
    lastBResCooldownRemain = nil
    lastLustDisplayedTimer = false
    lustReadyDisplayActive = false
    lastLustReadySoundAt = nil
  end

  local function IsMplusTimerRunning()
    local MplusTimer = ctx.addonTable and ctx.addonTable.MplusTimer
    if type(MplusTimer) == "table" and type(MplusTimer.GetTimerData) == "function" then
      local timerData = MplusTimer.GetTimerData()
      if timerData and timerData.running then
        return true
      end
    end
    return false
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

  local function IsCombatUtilityContextActive()
    return IsMplusTimerRunning() or IsTrackedPartyRunActive()
  end

  local function IsActiveChallengeContext()
    if type(ctx.GetActiveChallengeMapID) ~= "function" then
      return true
    end
    local ok, mapID = pcall(ctx.GetActiveChallengeMapID)
    if not ok or mapID == nil then
      return false
    end
    local isSecretValue = rawget(_G, "issecretvalue")
    if type(isSecretValue) == "function" then
      local secretOk, isSecret = pcall(isSecretValue, mapID)
      if secretOk and isSecret == true then
        return false
      end
    end
    return true
  end

  local function IsGroupedUtilityContext()
    if type(ctx.isInGroup) == "function" and ctx.isInGroup() == true then
      return true
    end
    if type(ctx.isInInstanceGroup) == "function" and ctx.isInInstanceGroup() == true then
      return true
    end
    return false
  end

  local function PlayBloodlustReadySound()
    if
      ctx.addonTable
      and type(ctx.addonTable.SoundUtils) == "table"
      and type(ctx.addonTable.SoundUtils.PlayBloodlustReady) == "function"
    then
      ctx.addonTable.SoundUtils.PlayBloodlustReady()
      return true
    end
    return false
  end

  local function IsBloodlustReadyReminderEnabled()
    local db = rawget(_G, "IsiLiveDB")
    if type(db) ~= "table" then
      db = initialDBRef
    end
    if type(db) == "table" and db.soundBloodlustReadyReminderEnabled == false then
      return false
    end
    return true
  end

  ctx.UpdateCdTracker = function(opts)
    local optsTable = type(opts) == "table" and opts or nil
    local suppressBattleResReadySound = optsTable and optsTable.suppressBattleResReadySound == true
    local suppressLustReadySound = optsTable and optsTable.suppressLustReadySound == true
    local resetRuntimeTimers = optsTable and optsTable.resetRuntimeTimers == true
    local fromVisibleRender = optsTable and optsTable.fromVisibleRender == true
    if IsRaidModeActive() then
      ClearReadySoundState()
      if ctx.cdTrackerController and type(ctx.cdTrackerController.ClearRuntimeData) == "function" then
        ctx.cdTrackerController.ClearRuntimeData()
      end
      lastMplusRunning = false
      return
    end
    local mplusRunning = IsMplusTimerRunning()
    local combatUtilityContextActive = mplusRunning or IsTrackedPartyRunActive()
    local readySoundContextActive = mplusRunning and IsGroupedUtilityContext() and IsActiveChallengeContext()
    if mplusRunning and not lastMplusRunning then
      lastBResCharges = nil
      lastBResCooldownRemain = nil
    end
    if resetRuntimeTimers or not combatUtilityContextActive then
      ClearReadySoundState()
      if ctx.cdTrackerController and type(ctx.cdTrackerController.ClearRuntimeData) == "function" then
        ctx.cdTrackerController.ClearRuntimeData()
      end
    else
      ctx.cdTrackerController.Scan()
    end
    local bresInfo = type(ctx.cdTrackerController.GetBResInfo) == "function" and ctx.cdTrackerController.GetBResInfo()
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
      and ctx.addonTable
      and type(ctx.addonTable.SoundUtils) == "table"
      and type(ctx.addonTable.SoundUtils.PlayBattleResReady) == "function"
    then
      ctx.addonTable.SoundUtils.PlayBattleResReady()
    end
    if suppressBattleResReadySound or not readySoundContextActive then
      lastBResCharges = nil
      lastBResCooldownRemain = nil
    else
      lastBResCharges = bresCharges
      lastBResCooldownRemain = bresCooldownRemain
    end
    lastMplusRunning = mplusRunning
    local lustInfo = type(ctx.cdTrackerController.GetLustInfo) == "function" and ctx.cdTrackerController.GetLustInfo()
      or nil
    local lustRemain = type(lustInfo) == "table" and tonumber(lustInfo.remain) or nil
    local lustTimerDisplayed = lustRemain ~= nil and lustRemain > 0
    if lustTimerDisplayed then
      lastLustReadySoundAt = nil
      lustReadyDisplayActive = false
    end
    if
      lustTimerDisplayed
      and not lastLustDisplayedTimer
      and readySoundContextActive
      and type(opts) == "table"
      and opts.playLustSoundOnStart == true
      and ctx.addonTable
      and type(ctx.addonTable.SoundUtils) == "table"
      and type(ctx.addonTable.SoundUtils.PlayBloodlust) == "function"
    then
      ctx.addonTable.SoundUtils.PlayBloodlust()
    end
    if readySoundContextActive and lastLustDisplayedTimer and not lustTimerDisplayed and not suppressLustReadySound then
      if PlayBloodlustReadySound() then
        lastLustReadySoundAt = getTime()
        lustReadyDisplayActive = true
      end
    elseif
      readySoundContextActive
      and not lustTimerDisplayed
      and not suppressLustReadySound
      and lastLustReadySoundAt ~= nil
      and IsBloodlustReadyReminderEnabled()
      and getTime() - lastLustReadySoundAt >= LUST_READY_REMINDER_SECONDS
    then
      if PlayBloodlustReadySound() then
        lastLustReadySoundAt = getTime()
      end
    end
    if suppressLustReadySound or not readySoundContextActive then
      lastLustDisplayedTimer = false
      lustReadyDisplayActive = false
      lastLustReadySoundAt = nil
    else
      lastLustDisplayedTimer = lustTimerDisplayed
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
    -- Also refresh full UI if M+ key is running so the timer counts down.
    if mplusRunning and not fromVisibleRender then
      if ctx.UpdateUI then
        ctx.UpdateUI()
      end
    end
  end
  if ctx.rosterPanelController and type(ctx.rosterPanelController.SetCdController) == "function" then
    local uiCdController = {
      Scan = function()
        ctx.UpdateCdTracker({ fromVisibleRender = true })
      end,
      GetBResInfo = function()
        if not IsCombatUtilityContextActive() or not IsGroupedUtilityContext() then
          return nil
        end
        return type(ctx.cdTrackerController.GetBResInfo) == "function" and ctx.cdTrackerController.GetBResInfo() or nil
      end,
      GetLustInfo = function()
        if not IsCombatUtilityContextActive() or not IsGroupedUtilityContext() then
          return nil
        end
        local info = type(ctx.cdTrackerController.GetLustInfo) == "function" and ctx.cdTrackerController.GetLustInfo()
          or nil
        if info ~= nil then
          return info
        end
        if lustReadyDisplayActive and IsMplusTimerRunning() and IsGroupedUtilityContext() then
          return { remain = 0 }
        end
        return nil
      end,
    }
    ctx.rosterPanelController.SetCdController(uiCdController)
  end

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
        if type(mobNameplate) == "table" and type(mobNameplate.RefreshAll) == "function" then
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
  local C_Timer_ref = rawget(_G, "C_Timer")
  if type(C_Timer_ref) == "table" and type(C_Timer_ref.NewTicker) == "function" then
    C_Timer_ref.NewTicker(1.0, function()
      if not IsMainFrameShown() then
        return
      end
      local needsTick = IsCombatUtilityContextActive()
      if not needsTick and ctx.cdTrackerController and type(ctx.cdTrackerController.GetLustInfo) == "function" then
        local lustInfo = ctx.cdTrackerController.GetLustInfo()
        if lustInfo and tonumber(lustInfo.remain) and lustInfo.remain > 0 then
          needsTick = true
        end
      end
      if needsTick then
        ctx.UpdateCdTracker()
      end
    end)
  end
end

FI.InitializeFactorySecondaryCdTracker = InitializeFactorySecondaryCdTracker

return {
  InitializeFactorySecondaryCdTracker = InitializeFactorySecondaryCdTracker,
}
