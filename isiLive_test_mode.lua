local _, addonTable = ...

addonTable = addonTable or {}

local TestMode = {}
addonTable.TestMode = TestMode

local function RequireFunction(value, name)
  assert(type(value) == "function", "isiLive: TestMode requires " .. name)
  return value
end

function TestMode.CreateController(opts)
  opts = opts or {}

  local getL = RequireFunction(opts.getL, "getL")
  local printFn = opts.printFn or print
  local getState = RequireFunction(opts.getState, "getState")
  local setState = RequireFunction(opts.setState, "setState")
  local buildDummyRoster = RequireFunction(opts.buildDummyRoster, "buildDummyRoster")
  local setRoster = RequireFunction(opts.setRoster, "setRoster")
  local setMainFrameVisible = RequireFunction(opts.setMainFrameVisible, "setMainFrameVisible")
  local updateUI = RequireFunction(opts.updateUI, "updateUI")
  local updateLeaderButtons = RequireFunction(opts.updateLeaderButtons, "updateLeaderButtons")
  local showCenterNotice = RequireFunction(opts.showCenterNotice, "showCenterNotice")
  local showQueueJoinPreview = RequireFunction(opts.showQueueJoinPreview, "showQueueJoinPreview")
  local resetInspectAll = RequireFunction(opts.resetInspectAll, "resetInspectAll")
  local clearLatestQueueState = RequireFunction(opts.clearLatestQueueState, "clearLatestQueueState")
  local updateMPlusTeleportButton = RequireFunction(opts.updateMPlusTeleportButton, "updateMPlusTeleportButton")
  local setCenterNoticeVisible = RequireFunction(opts.setCenterNoticeVisible, "setCenterNoticeVisible")
  local hideInviteHint = RequireFunction(opts.hideInviteHint, "hideInviteHint")
  local triggerGroupRosterUpdate = RequireFunction(opts.triggerGroupRosterUpdate, "triggerGroupRosterUpdate")

  assert(type(printFn) == "function", "isiLive: TestMode requires printFn")

  local controller = {}

  function controller.EnterFullDummyPreview()
    local L = getL()
    setState({
      isTestMode = true,
      isTestAllMode = true,
    })
    setRoster(buildDummyRoster())
    setMainFrameVisible(true)
    updateUI()
    updateLeaderButtons()

    showCenterNotice(L.LEAD_TRANSFERRED_CENTER, 20)
    showQueueJoinPreview(L.TESTALL_DUMMY_GROUP, L.TESTALL_DUMMY_DUNGEON)
    printFn(L.CHAT_QUEUE_PREFIX .. " | " .. L.TESTALL_CHAT_ACTIVE)
  end

  function controller.ExitTestMode()
    local state = getState()
    if not state.isTestMode and not state.isTestAllMode then
      return
    end

    local L = getL()
    setState({
      isTestMode = false,
      isTestAllMode = false,
    })
    printFn(L.TEST_DISABLED)
    setRoster({})
    resetInspectAll()
    clearLatestQueueState()
    updateUI()
    updateMPlusTeleportButton()
    updateLeaderButtons()
    setCenterNoticeVisible(false)
    hideInviteHint()
    setMainFrameVisible(false)
    triggerGroupRosterUpdate()
  end

  function controller.ToggleStandardTestMode()
    local state = getState()
    local L = getL()
    if state.isStopped then
      printFn(L.ERR_STOPPED_TEST)
      return
    end
    if state.isPaused then
      printFn(L.ERR_PAUSED_TEST)
      return
    end

    if state.isTestMode then
      controller.ExitTestMode()
      return
    end

    setState({
      isTestMode = true,
      isTestAllMode = false,
    })
    printFn(L.TEST_ENABLED)
    setRoster(buildDummyRoster())
    setMainFrameVisible(true)
    updateUI()
    updateLeaderButtons()
    showQueueJoinPreview(L.TESTALL_DUMMY_GROUP, L.TESTALL_DUMMY_DUNGEON)
  end

  return controller
end
