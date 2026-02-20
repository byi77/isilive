---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  local function BuildTestModeController(overrides)
    overrides = overrides or {}
    local state = {
      isTestMode = false,
      isTestAllMode = false,
      isStopped = overrides.isStopped or false,
      isPaused = overrides.isPaused or false,
      roster = {},
      mainFrameVisible = false,
      centerNoticeVisible = true,
      prints = {},
      uiUpdates = 0,
    }

    local addon = LoadAddonModules({ "isiLive_test_mode.lua" })
    local controller = addon.TestMode.CreateController({
      getL = function()
        return {
          TEST_ENABLED = "Test mode enabled.",
          TEST_DISABLED = "Test mode disabled.",
          ERR_STOPPED_TEST = "Addon is stopped.",
          ERR_PAUSED_TEST = "Addon is paused.",
          LEAD_TRANSFERRED_CENTER = "You are now the group leader!",
          TESTALL_DUMMY_GROUP = "Dummy Keys",
          TESTALL_DUMMY_DUNGEON = "The Dawnbreaker",
          TESTALL_CHAT_ACTIVE = "Dummy preview active.",
          CHAT_QUEUE_PREFIX = "Queue Join",
        }
      end,
      printFn = function(msg)
        table.insert(state.prints, tostring(msg))
      end,
      getState = function()
        return state
      end,
      setState = function(patch)
        for k, v in pairs(patch) do
          state[k] = v
        end
      end,
      buildDummyRoster = function()
        return { player = { name = "Test" } }
      end,
      setRoster = function(value)
        state.roster = value
      end,
      setMainFrameVisible = function(visible)
        state.mainFrameVisible = visible
      end,
      updateUI = function()
        state.uiUpdates = state.uiUpdates + 1
      end,
      updateLeaderButtons = function() end,
      showCenterNotice = function() end,
      showQueueJoinPreview = function() end,
      resetInspectAll = function() end,
      clearLatestQueueState = function() end,
      updateMPlusTeleportButton = function() end,
      setCenterNoticeVisible = function(visible)
        state.centerNoticeVisible = visible
      end,
      hideInviteHint = function() end,
      triggerGroupRosterUpdate = function() end,
    })

    return controller, state
  end

  test("TestMode toggle enters and exits test mode", function()
    local controller, state = BuildTestModeController()

    controller.ToggleStandardTestMode()
    Assert.True(state.isTestMode, "isTestMode must be true after toggle on")
    Assert.True(state.mainFrameVisible, "frame must be visible in test mode")
    Assert.Equal(state.uiUpdates, 1, "UI must update on enter")

    controller.ToggleStandardTestMode()
    Assert.False(state.isTestMode, "isTestMode must be false after toggle off")
    Assert.False(state.mainFrameVisible, "frame must be hidden after exit")
  end)

  test("TestMode toggle blocked when stopped", function()
    local controller, state = BuildTestModeController({ isStopped = true })

    controller.ToggleStandardTestMode()
    Assert.False(state.isTestMode, "test mode must not activate when stopped")
    Assert.True(#state.prints > 0, "must print error when stopped")
  end)

  test("TestMode toggle blocked when paused", function()
    local controller, state = BuildTestModeController({ isPaused = true })

    controller.ToggleStandardTestMode()
    Assert.False(state.isTestMode, "test mode must not activate when paused")
    Assert.True(#state.prints > 0, "must print error when paused")
  end)

  test("TestMode full dummy preview sets testall state", function()
    local controller, state = BuildTestModeController()

    controller.EnterFullDummyPreview()
    Assert.True(state.isTestMode, "isTestMode must be true for full preview")
    Assert.True(state.isTestAllMode, "isTestAllMode must be true for full preview")
    Assert.True(state.mainFrameVisible, "frame must be visible for full preview")
    Assert.NotNil(state.roster.player, "roster must contain dummy player")
  end)
end
