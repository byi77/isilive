local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local FactoryDemo = FI.FactoryDemo or {}

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
    hideInviteHint = function()
      ctx.inviteHint.frame:Hide()
    end,
    triggerGroupRosterUpdate = ctx.TriggerGroupRosterUpdate,
  }))

  ctx.EnterFullDummyPreview = function()
    local logFn = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil
    if logFn then
      logFn("[TESTMODE] enter_full_dummy_preview")
    end
    ctx.testModeController.EnterFullDummyPreview()
  end
  ctx.ExitTestMode = function()
    local logFn = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil
    if logFn then
      logFn("[TESTMODE] exit")
    end
    ctx.testModeController.ExitTestMode()
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
