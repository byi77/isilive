local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local FactoryDemo = FI.FactoryDemo or {}

-- Ends the demo after five idle minutes (TestMode.CreateIdleWatch); the
-- frame stays open like on combat start. Nil without a ticker API.
local function CreateDemoIdleWatch(ctx, modules, runtimeState)
  local cTimer = rawget(_G, "C_Timer")
  local createWatch = modules.testMode and modules.testMode.CreateIdleWatch
  if type(createWatch) ~= "function" or type(cTimer) ~= "table" or type(cTimer.NewTicker) ~= "function" then
    return nil
  end
  local getCursor = rawget(_G, "GetCursorPosition")
  local isMoving = rawget(_G, "IsPlayerMoving")
  return createWatch({
    isActive = function()
      return runtimeState.IsTestMode() == true or runtimeState.IsTestAllMode() == true
    end,
    exit = function()
      local logFn = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil
      if logFn then
        logFn("[TESTMODE] exit_idle")
      end
      ctx.ExitTestModeForCombat()
    end,
    newTicker = cTimer.NewTicker,
    getTime = rawget(_G, "GetTime") or os.time,
    getCursor = type(getCursor) == "function" and getCursor or nil,
    isMoving = type(isMoving) == "function" and isMoving or nil,
  })
end

local function StartDemoIdleWatch(ctx)
  if ctx.demoIdleWatch then
    ctx.demoIdleWatch.Start()
  end
end

local function InitializeFactorySecondaryTestModeAndBindings(ctx, modules, runtimeState)
  local demoCallbacks = FactoryDemo.BuildTestModeControllerCallbacks(ctx, runtimeState)
  ctx.testModeController = modules.testMode.CreateController(modules.configBuilders.BuildTestModeControllerOpts({
    getL = ctx.GetL,
    printFn = ctx.Print,
    getState = runtimeState.GetRuntimeFlags,
    setState = runtimeState.PatchRuntimeFlags,
    buildDummyRoster = ctx.BuildDummyRoster,
    setRoster = ctx.SetRoster,
    setMainFrameVisible = ctx.SetMainFrameVisible,
    updateUI = ctx.UpdateUI,
    updateLeaderButtons = ctx.UpdateLeaderButtons,
    showCenterNotice = ctx.ShowCenterNotice,
    resetInspectAll = ctx.ResetInspectAll,
    clearLatestQueueState = function()
      runtimeState.ClearLatestQueueTarget({ keepActiveJoinedKey = true })
    end,
    captureRioBaselineSnapshot = ctx.CaptureRioBaselineSnapshot,
    clearRioBaselineSnapshot = ctx.ClearRioBaselineSnapshot,
    enableRioDeltaDisplay = ctx.EnableRioDeltaDisplay,
    setDemoTimerData = demoCallbacks.setDemoTimerData,
    clearDemoTimerData = demoCallbacks.clearDemoTimerData,
    setDemoFeatureData = demoCallbacks.setDemoFeatureData,
    clearDemoFeatureData = demoCallbacks.clearDemoFeatureData,
    updateMPlusTeleportButton = ctx.UpdateMPlusTeleportButton,
    setCenterNoticeVisible = ctx.SetCenterNoticeVisible,
    hideInviteHint = function() end,
    triggerGroupRosterUpdate = ctx.TriggerGroupRosterUpdate,
  }))

  ctx.demoIdleWatch = CreateDemoIdleWatch(ctx, modules, runtimeState)
  ctx.EnterFullDummyPreview = function()
    local logFn = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil
    if logFn then
      logFn("[TESTMODE] enter_full_dummy_preview")
    end
    ctx.testModeController.EnterFullDummyPreview()
    StartDemoIdleWatch(ctx)
  end
  ctx.ExitTestMode = function()
    local logFn = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil
    if logFn then
      logFn("[TESTMODE] exit")
    end
    ctx.testModeController.ExitTestMode()
  end
  -- Combat start ends the preview but keeps the main frame open; like the
  -- demo toggle, the "was in group" flag lets HandleNoGroup rebuild the solo
  -- player entry from the restored real roster.
  ctx.ExitTestModeForCombat = function()
    if not (runtimeState.IsTestMode() or runtimeState.IsTestAllMode()) then
      return false
    end
    local logFn = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil
    if logFn then
      logFn("[TESTMODE] exit_for_combat")
    end
    ctx.SetWasInGroup(true)
    return ctx.testModeController.ExitTestModeForCombat()
  end
  ctx.ToggleStandardTestMode = function()
    local logFn = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil
    if logFn then
      logFn("[TESTMODE] toggle_standard")
    end
    ctx.testModeController.ToggleStandardTestMode()
  end
  ctx.ToggleDemoMode = function()
    local wasTestMode = runtimeState.IsTestMode() or runtimeState.IsTestAllMode()
    local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
    if logf then
      logf("[TESTMODE] toggle_demo wasTestMode=%s", tostring(wasTestMode))
    end
    ctx.testModeController.ToggleDemoMode()
    StartDemoIdleWatch(ctx)
    -- After demo exit, pretend we just left a group so HandleNoGroup rebuilds
    -- the player entry correctly even when the player is solo.
    if wasTestMode then
      ctx.SetWasInGroup(true)
      ctx.TriggerGroupRosterUpdate()
    end
  end

  ctx.bindingController = modules.bindings.CreateController({
    onToggleMainFrame = ctx.ToggleMainFrameVisibility,
    onToggleTestMode = ctx.ToggleDemoMode,
  })
  ctx.ApplyHotkeyBindings()
end

FI.InitializeFactorySecondaryTestModeAndBindings = InitializeFactorySecondaryTestModeAndBindings

return {
  InitializeFactorySecondaryTestModeAndBindings = InitializeFactorySecondaryTestModeAndBindings,
}
