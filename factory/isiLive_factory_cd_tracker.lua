local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

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
  local lastLustActive = false
  ctx.UpdateCdTracker = function(opts)
    if IsRaidModeActive() then
      return
    end
    ctx.cdTrackerController.Scan()
    local lustInfo = type(ctx.cdTrackerController.GetLustInfo) == "function" and ctx.cdTrackerController.GetLustInfo()
      or nil
    local lustActive = type(lustInfo) == "table" and tonumber(lustInfo.remain) ~= nil and lustInfo.remain > 0
    if
      lustActive
      and not lastLustActive
      and type(opts) == "table"
      and opts.playLustSoundOnStart == true
      and ctx.addonTable
      and type(ctx.addonTable.SoundUtils) == "table"
      and type(ctx.addonTable.SoundUtils.PlayBloodlust) == "function"
    then
      ctx.addonTable.SoundUtils.PlayBloodlust()
    end
    lastLustActive = lustActive
    if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshCdTracker) == "function" then
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
    local MplusTimer = ctx.addonTable and ctx.addonTable.MplusTimer
    if type(MplusTimer) == "table" and type(MplusTimer.GetTimerData) == "function" then
      local timerData = MplusTimer.GetTimerData()
      if timerData and timerData.running then
        if ctx.UpdateUI then
          ctx.UpdateUI()
        end
      end
    end
  end
  if ctx.rosterPanelController and type(ctx.rosterPanelController.SetCdController) == "function" then
    ctx.rosterPanelController.SetCdController(ctx.cdTrackerController)
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
      local needsTick = false
      local MplusTimer = ctx.addonTable and ctx.addonTable.MplusTimer
      if type(MplusTimer) == "table" and type(MplusTimer.GetTimerData) == "function" then
        local timerData = MplusTimer.GetTimerData()
        if timerData and timerData.running then
          needsTick = true
        end
      end
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
