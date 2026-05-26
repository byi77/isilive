local _, addonTable = ...

addonTable = addonTable or {}

local TestMode = {}
addonTable.TestMode = TestMode

local function RequireFunction(value, name)
  return addonTable.Validators.RequireFunction(value, name, "TestMode")
end

local function ApplyDummyRioDeltaPreview(roster)
  if type(roster) ~= "table" then
    return
  end

  local incrementsByUnit = {
    player = 15,
    party1 = 12,
    party2 = 9,
    party3 = 6,
    party4 = 3,
  }

  for unit, increment in pairs(incrementsByUnit) do
    local info = roster[unit]
    local currentRio = info and tonumber(info.rio)
    if currentRio then
      info.rio = math.max(0, math.floor(currentRio) + increment)
    end
  end
end

local function BuildDeps(opts)
  opts = opts or {}
  local deps = {}
  deps.getL = RequireFunction(opts.getL, "getL")
  deps.printFn = opts.printFn or print
  deps.getState = RequireFunction(opts.getState, "getState")
  deps.setState = RequireFunction(opts.setState, "setState")
  deps.buildDummyRoster = RequireFunction(opts.buildDummyRoster, "buildDummyRoster")
  deps.setRoster = RequireFunction(opts.setRoster, "setRoster")
  deps.setMainFrameVisible = RequireFunction(opts.setMainFrameVisible, "setMainFrameVisible")
  deps.updateUI = RequireFunction(opts.updateUI, "updateUI")
  deps.updateLeaderButtons = RequireFunction(opts.updateLeaderButtons, "updateLeaderButtons")
  deps.showCenterNotice = RequireFunction(opts.showCenterNotice, "showCenterNotice")
  deps.resetInspectAll = RequireFunction(opts.resetInspectAll, "resetInspectAll")
  deps.clearLatestQueueState = RequireFunction(opts.clearLatestQueueState, "clearLatestQueueState")
  deps.updateMPlusTeleportButton = RequireFunction(opts.updateMPlusTeleportButton, "updateMPlusTeleportButton")
  deps.setCenterNoticeVisible = RequireFunction(opts.setCenterNoticeVisible, "setCenterNoticeVisible")
  deps.hideInviteHint = RequireFunction(opts.hideInviteHint, "hideInviteHint")
  deps.triggerGroupRosterUpdate = RequireFunction(opts.triggerGroupRosterUpdate, "triggerGroupRosterUpdate")
  deps.captureRioBaselineSnapshot = opts.captureRioBaselineSnapshot or function() end
  deps.clearRioBaselineSnapshot = opts.clearRioBaselineSnapshot or function() end
  deps.enableRioDeltaDisplay = opts.enableRioDeltaDisplay or function() end
  deps.setDemoTimerData = opts.setDemoTimerData or function() end
  deps.clearDemoTimerData = opts.clearDemoTimerData or function() end
  deps.setDemoFeatureData = opts.setDemoFeatureData or function() end
  deps.clearDemoFeatureData = opts.clearDemoFeatureData or function() end

  assert(type(deps.printFn) == "function", "isiLive: TestMode requires printFn")
  assert(type(deps.captureRioBaselineSnapshot) == "function", "isiLive: TestMode requires captureRioBaselineSnapshot")
  assert(type(deps.clearRioBaselineSnapshot) == "function", "isiLive: TestMode requires clearRioBaselineSnapshot")
  assert(type(deps.enableRioDeltaDisplay) == "function", "isiLive: TestMode requires enableRioDeltaDisplay")
  assert(type(deps.setDemoFeatureData) == "function", "isiLive: TestMode requires setDemoFeatureData")
  assert(type(deps.clearDemoFeatureData) == "function", "isiLive: TestMode requires clearDemoFeatureData")
  return deps
end

function TestMode.CreateController(opts)
  local deps = BuildDeps(opts)
  local controller = {}

  local function ApplyDummyPreviewState(statePatch, shouldAnnounceLeader, shouldPrintChat, previewVariant)
    local L = deps.getL()
    if type(statePatch) == "table" then
      deps.setState(statePatch)
    end
    local dummyRoster = deps.buildDummyRoster({
      previewVariant = previewVariant,
      includeGhostMember = true,
    })
    deps.setRoster(dummyRoster)
    deps.captureRioBaselineSnapshot()
    ApplyDummyRioDeltaPreview(dummyRoster)
    deps.enableRioDeltaDisplay()
    deps.setDemoTimerData()
    if shouldAnnounceLeader then
      deps.showCenterNotice(L.LEAD_TRANSFERRED_CENTER, 20)
    end
    deps.setDemoFeatureData()
    deps.setMainFrameVisible(true)
    deps.updateUI()
    deps.updateLeaderButtons()

    if shouldPrintChat then
      deps.printFn(L.CHAT_QUEUE_PREFIX .. " | " .. L.TESTALL_CHAT_ACTIVE)
    end
  end

  function controller.EnterFullDummyPreview()
    ApplyDummyPreviewState({
      isTestMode = true,
      isTestAllMode = true,
    }, true, true, "full")
  end

  function controller.RefreshActivePreview()
    local state = deps.getState()
    if not state.isTestMode and not state.isTestAllMode then
      return false
    end

    ApplyDummyPreviewState(nil, false, false, state.isTestAllMode and "full" or "standard")
    return true
  end

  function controller.ExitTestMode()
    local state = deps.getState()
    if not state.isTestMode and not state.isTestAllMode then
      return
    end

    local L = deps.getL()
    deps.setState({
      isTestMode = false,
      isTestAllMode = false,
    })
    deps.printFn(L.TEST_DISABLED)
    deps.clearRioBaselineSnapshot()
    deps.clearDemoTimerData()
    deps.clearDemoFeatureData()
    deps.setRoster({})
    deps.resetInspectAll()
    deps.clearLatestQueueState()
    deps.updateUI()
    deps.updateMPlusTeleportButton()
    deps.updateLeaderButtons()
    deps.setCenterNoticeVisible(false)
    deps.hideInviteHint()
    deps.setMainFrameVisible(false)
    deps.triggerGroupRosterUpdate()
  end

  function controller.ToggleStandardTestMode()
    local state = deps.getState()
    local L = deps.getL()
    if state.isStopped then
      deps.printFn(L.ERR_STOPPED_TEST)
      return
    end
    if state.isPaused then
      deps.printFn(L.ERR_PAUSED_TEST)
      return
    end

    if state.isTestMode then
      controller.ExitTestMode()
      return
    end

    deps.printFn(L.TEST_ENABLED)
    controller.EnterFullDummyPreview()
  end

  -- Toggles demo mode without closing the visualisation. Unlike ExitTestMode
  -- this path keeps the main frame visible and skips the trailing
  -- triggerGroupRosterUpdate / updateUI / setMainFrameVisible(false) — the
  -- caller in factory_controllers wires the real-group restore separately so
  -- it can SetWasInGroup(true) first and rebuild the solo-player entry on
  -- HandleNoGroup.
  function controller.ToggleDemoMode()
    local state = deps.getState()
    local L = deps.getL()
    if state.isStopped then
      deps.printFn(L.ERR_STOPPED_TEST)
      return
    end
    if state.isPaused then
      deps.printFn(L.ERR_PAUSED_TEST)
      return
    end

    if state.isTestMode or state.isTestAllMode then
      deps.setState({ isTestMode = false, isTestAllMode = false })
      deps.printFn(L.TEST_DISABLED)
      deps.clearRioBaselineSnapshot()
      deps.clearDemoTimerData()
      deps.clearDemoFeatureData()
      deps.setRoster({})
      deps.resetInspectAll()
      deps.clearLatestQueueState()
      deps.updateLeaderButtons()
      deps.setCenterNoticeVisible(false)
      deps.hideInviteHint()
      return
    end

    deps.printFn(L.TEST_ENABLED)
    controller.EnterFullDummyPreview()
  end

  return controller
end
