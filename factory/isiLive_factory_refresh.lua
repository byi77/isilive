local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local function InitializeFactoryRefreshControllers(ctx, modules, runtimeState)
  local function QueueForceRefreshData()
    ctx.inspectController.QueueForceRefreshData(ctx.GetRoster())
  end

  local function ForceRefreshSyncState()
    ctx.keySyncController.ForceRefreshSyncState(ctx.GetRoster())
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

  local rosterUI = ctx.addonTable and ctx.addonTable.RosterUI or {}
  local setFlatButtonText = type(rosterUI.SetFlatButtonText) == "function" and rosterUI.SetFlatButtonText
    or function(btn, text)
      if btn and btn.SetText then
        btn:SetText(text)
      end
    end

  local function UpdateResyncButton()
    local btn = ctx.refreshButton
    if not btn then
      return
    end
    local getTimeFn = rawget(_G, "GetTime")
    local now = type(getTimeFn) == "function" and getTimeFn() or 0
    local remaining = math.ceil(resyncCooldownEnd - now)
    if remaining > 0 then
      btn:SetEnabled(false)
      btn:SetAlpha(0.5)
      local label = btn._baseText or btn._fullText or "Re-Sync"
      btn._baseText = label
      local cooldownText = string.format("%s (%ds)", label, remaining)
      btn._fullText = cooldownText
      setFlatButtonText(btn, cooldownText)
    else
      btn:SetEnabled(true)
      btn:SetAlpha(1.0)
      if btn._baseText then
        btn._fullText = btn._baseText
        btn._baseText = nil
      end
      local label = btn._fullText or "Re-Sync"
      setFlatButtonText(btn, label)
      if resyncTicker then
        resyncTicker:Cancel()
        resyncTicker = nil
      end
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
