---@diagnostic disable: undefined-global

local function BuildTestModeController(LoadAddonModules, overrides)
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
    captureRioBaselineCalls = 0,
    clearRioBaselineCalls = 0,
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
      return {
        player = { name = "Test", rio = 1000 },
        party1 = { name = "Dummy1", rio = 2000 },
        party2 = { name = "Dummy2", rio = 2100 },
        party3 = { name = "Dummy3", rio = 2200 },
        party4 = { name = "Dummy4", rio = 2300 },
      }
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
    captureRioBaselineSnapshot = function()
      state.captureRioBaselineCalls = state.captureRioBaselineCalls + 1
    end,
    clearRioBaselineSnapshot = function()
      state.clearRioBaselineCalls = state.clearRioBaselineCalls + 1
    end,
  })

  return controller, state
end

local function RegisterTestModeToggleTests(test, Assert, LoadAddonModules)
  test("TestMode toggle enters and exits test mode", function()
    local controller, state = BuildTestModeController(LoadAddonModules)

    controller.ToggleStandardTestMode()
    Assert.True(state.isTestMode, "isTestMode must be true after toggle on")
    Assert.True(state.mainFrameVisible, "frame must be visible in test mode")
    Assert.Equal(state.uiUpdates, 1, "UI must update on enter")
    Assert.Equal(state.captureRioBaselineCalls, 1, "test-mode enter must capture one RIO baseline snapshot")
    Assert.Equal(state.roster.player.rio, 1015, "test-mode preview should apply visible positive RIO delta")

    controller.ToggleStandardTestMode()
    Assert.False(state.isTestMode, "isTestMode must be false after toggle off")
    Assert.False(state.mainFrameVisible, "frame must be hidden after exit")
    Assert.Equal(state.clearRioBaselineCalls, 1, "test-mode exit must clear RIO baseline snapshot")
  end)

  test("TestMode full dummy preview sets testall state", function()
    local controller, state = BuildTestModeController(LoadAddonModules)

    controller.EnterFullDummyPreview()
    Assert.True(state.isTestMode, "isTestMode must be true for full preview")
    Assert.True(state.isTestAllMode, "isTestAllMode must be true for full preview")
    Assert.True(state.mainFrameVisible, "frame must be visible for full preview")
    Assert.NotNil(state.roster.player, "roster must contain dummy player")
    Assert.Equal(state.captureRioBaselineCalls, 1, "testall preview must capture one RIO baseline snapshot")
    Assert.Equal(state.roster.party1.rio, 2012, "testall preview should apply visible positive RIO delta")
  end)

  test("TestMode refresh rebuilds active dummy preview roster", function()
    local controller, state = BuildTestModeController(LoadAddonModules)

    controller.EnterFullDummyPreview()
    state.roster.player.rio = 9999

    local refreshed = controller.RefreshActivePreview()

    Assert.True(refreshed, "active demo preview refresh must report success")
    Assert.Equal(state.captureRioBaselineCalls, 2, "refresh must capture a fresh RIO baseline snapshot")
    Assert.Equal(state.roster.player.rio, 1015, "refresh must rebuild the dummy roster instead of reusing mutated rows")
  end)
end

local function RegisterTestModeGuardTests(test, Assert, LoadAddonModules)
  test("TestMode toggle blocked when stopped", function()
    local controller, state = BuildTestModeController(LoadAddonModules, { isStopped = true })

    controller.ToggleStandardTestMode()
    Assert.False(state.isTestMode, "test mode must not activate when stopped")
    Assert.True(#state.prints > 0, "must print error when stopped")
  end)

  test("TestMode toggle blocked when paused", function()
    local controller, state = BuildTestModeController(LoadAddonModules, { isPaused = true })

    controller.ToggleStandardTestMode()
    Assert.False(state.isTestMode, "test mode must not activate when paused")
    Assert.True(#state.prints > 0, "must print error when paused")
  end)
end

local function RegisterDemoRosterTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Demo dummy roster uses canonical hunter spec name so short-label mapping can resolve", function()
    WithGlobals({
      UnitClass = function(_unit)
        return "Warrior", "WARRIOR"
      end,
      UnitName = function(_unit)
        return "Player"
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_demo.lua" })
      local roster = addon.Demo.BuildDummyRoster({
        getUnitNameAndRealm = function(unit)
          if unit == "player" then
            return "Player", "Realm"
          end
          return nil, nil
        end,
        getUnitRole = function(unit)
          if unit == "player" then
            return "TANK"
          end
          return "DAMAGER"
        end,
        getPlayerSpecName = function()
          return "Protection"
        end,
        getUnitRio = function(_unit)
          return 3000
        end,
      })

      Assert.Equal(
        roster.party4.spec,
        "Marksmanship",
        "demo roster should keep the canonical hunter spec name for short-label mapping"
      )
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterTestModeToggleTests(test, Assert, LoadAddonModules)
  RegisterTestModeGuardTests(test, Assert, LoadAddonModules)
  RegisterDemoRosterTests(test, Assert, WithGlobals, LoadAddonModules)
end
