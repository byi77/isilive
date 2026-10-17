local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local function InitializeFactoryRefreshControllers(ctx, modules, runtimeState)
  local function QueueForceRefreshData()
    ctx.inspectController.QueueForceRefreshData(ctx.GetRoster())
  end

  local function ForceRefreshSyncState(opts)
    ctx.keySyncController.ForceRefreshSyncState(ctx.GetRoster(), opts)
  end

  local function TriggerGroupRosterUpdate()
    local onEventHandler = ctx.mainFrame:GetScript("OnEvent")
    if onEventHandler then
      onEventHandler(ctx.mainFrame, "GROUP_ROSTER_UPDATE")
    end
  end

  ctx.TriggerGroupRosterUpdate = TriggerGroupRosterUpdate

  ctx.refreshController = modules.refresh.CreateController(modules.configBuilders.BuildRefreshControllerOpts({
    isStopped = runtimeState.IsStopped,
    isPaused = runtimeState.IsPaused,
    isTestMode = runtimeState.IsTestMode,
    isTestAllMode = runtimeState.IsTestAllMode,
    isInGroup = IsInGroup,
    isRosterEmpty = function()
      return next(ctx.GetRoster()) == nil
    end,
    triggerGroupRosterUpdate = ctx.TriggerGroupRosterUpdate,
    refreshTestModeRoster = function()
      if not ctx.testModeController then
        return false
      end
      return ctx.testModeController.RefreshActivePreview()
    end,
    forceRefreshSyncState = ForceRefreshSyncState,
    sendIsiLiveHello = ctx.SendIsiLiveHello,
    sendOwnKeySnapshot = ctx.SendOwnKeySnapshot,
    sendOwnBackgroundSnapshot = ctx.SendOwnBackgroundSnapshot,
    sendRefreshRequest = ctx.SendRefreshRequest,
    queueForceRefreshData = QueueForceRefreshData,
    updateUI = ctx.UpdateUI,
    refreshLocalPlayerKey = ctx.RefreshLocalPlayerKey,
    getActiveChallengeMapID = ctx.GetActiveChallengeMapID,
    getTime = rawget(_G, "GetTime"),
    refreshDebounceSeconds = 10,
    logRuntimeTrace = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil,
    logRuntimeTracef = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil,
  }))

  local RESYNC_COOLDOWN = 10
  local resyncCooldownEnd = 0
  local resyncTicker = nil

  -- The title-bar Re-Sync icon shows the remaining seconds in place of its
  -- icon (ShowCooldownRemaining, ui/isiLive_roster_layout.lua).
  local function UpdateResyncButton()
    local btn = ctx.refreshButton
    if not btn then
      return
    end
    local getTimeFn = rawget(_G, "GetTime")
    local now = type(getTimeFn) == "function" and getTimeFn() or 0
    local remaining = math.ceil(resyncCooldownEnd - now)
    local showCooldown = type(btn.ShowCooldownRemaining) == "function" and btn.ShowCooldownRemaining or nil
    if remaining > 0 then
      btn:SetEnabled(false)
      btn:SetAlpha(0.5)
      if showCooldown then
        showCooldown(remaining)
      end
      return
    end
    btn:SetEnabled(true)
    btn:SetAlpha(1.0)
    if showCooldown then
      showCooldown(nil)
    end
    if resyncTicker then
      resyncTicker:Cancel()
      resyncTicker = nil
    end
  end

  ctx.refreshButton:SetScript("OnClick", function()
    local getTimeFn = rawget(_G, "GetTime")
    local now = type(getTimeFn) == "function" and getTimeFn() or 0
    if now < resyncCooldownEnd then
      return
    end
    local logFn = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil
    if logFn then
      logFn("[UI] btn_click name=refresh")
    end
    ctx.refreshController.RunFullRefresh()
    resyncCooldownEnd = now + RESYNC_COOLDOWN
    if resyncTicker then
      resyncTicker:Cancel()
    end
    local timer = rawget(_G, "C_Timer")
    if type(timer) == "table" and type(timer.NewTicker) == "function" then
      resyncTicker = timer.NewTicker(1.0, UpdateResyncButton, RESYNC_COOLDOWN)
    end
    UpdateResyncButton()
  end)
end

FI.InitializeFactoryRefreshControllers = InitializeFactoryRefreshControllers

return {
  InitializeFactoryRefreshControllers = InitializeFactoryRefreshControllers,
}
