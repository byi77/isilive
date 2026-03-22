---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  local function BuildRefreshController(overrides)
    overrides = overrides or {}
    local now = overrides.now or 100
    local state = {
      rosterUpdates = 0,
      syncRefreshes = 0,
      hellos = 0,
      keySnapshots = 0,
      refreshRequests = 0,
      queueRefreshes = 0,
      uiUpdates = 0,
      keyRefreshes = 0,
      demoRefreshes = 0,
    }

    local addon = LoadAddonModules({ "isiLive_refresh.lua" })
    local controller = addon.Refresh.CreateController({
      isStopped = overrides.isStopped or function()
        return false
      end,
      isPaused = overrides.isPaused or function()
        return false
      end,
      isTestMode = overrides.isTestMode or function()
        return false
      end,
      isTestAllMode = overrides.isTestAllMode or function()
        return false
      end,
      isInGroup = overrides.isInGroup or function()
        return true
      end,
      isRosterEmpty = overrides.isRosterEmpty or function()
        return false
      end,
      triggerGroupRosterUpdate = function()
        state.rosterUpdates = state.rosterUpdates + 1
      end,
      refreshTestModeRoster = function()
        state.demoRefreshes = state.demoRefreshes + 1
        if overrides.refreshTestModeRoster then
          return overrides.refreshTestModeRoster(state)
        end
        return true
      end,
      forceRefreshSyncState = function()
        state.syncRefreshes = state.syncRefreshes + 1
      end,
      sendIsiLiveHello = function(_force, _source)
        state.hellos = state.hellos + 1
      end,
      sendOwnKeySnapshot = function(_force, _source)
        state.keySnapshots = state.keySnapshots + 1
      end,
      sendRefreshRequest = function(_force)
        state.refreshRequests = state.refreshRequests + 1
      end,
      queueForceRefreshData = function()
        state.queueRefreshes = state.queueRefreshes + 1
      end,
      updateUI = function()
        state.uiUpdates = state.uiUpdates + 1
      end,
      refreshLocalPlayerKey = function()
        state.keyRefreshes = state.keyRefreshes + 1
        return overrides.keyChanged or false
      end,
      getActiveChallengeMapID = overrides.getActiveChallengeMapID or function()
        return nil
      end,
      getTime = overrides.getTime or function()
        return now
      end,
      refreshDebounceSeconds = overrides.refreshDebounceSeconds or 0,
    })

    state.setNow = function(value)
      now = tonumber(value) or now
    end

    return controller, state
  end

  test("Refresh RunFullRefresh executes all refresh steps", function()
    local controller, state = BuildRefreshController()

    local result = controller.RunFullRefresh()

    Assert.True(result, "RunFullRefresh must return true when active")
    Assert.Equal(state.syncRefreshes, 1, "must refresh sync state")
    Assert.Equal(state.hellos, 1, "must send hello")
    Assert.Equal(state.keySnapshots, 1, "must send key snapshot")
    Assert.Equal(state.refreshRequests, 1, "must request hidden peer sync replies")
    Assert.Equal(state.queueRefreshes, 1, "must refresh queue data")
    Assert.Equal(state.uiUpdates, 1, "must update UI")
  end)

  test("Refresh RunFullRefresh requests hidden peer sync replies", function()
    local controller, state = BuildRefreshController()

    local result = controller.RunFullRefresh()

    Assert.True(result, "RunFullRefresh must stay successful when hidden peer sync replies are requested")
    Assert.Equal(state.refreshRequests, 1, "refresh must broadcast exactly one sync request")
  end)

  test("Refresh RunFullRefresh reroutes to demo preview while test mode is active", function()
    local controller, state = BuildRefreshController({
      isTestMode = function()
        return true
      end,
    })

    local result = controller.RunFullRefresh()

    Assert.True(result, "RunFullRefresh must return true when demo refresh succeeds")
    Assert.Equal(state.demoRefreshes, 1, "must rebuild demo roster once")
    Assert.Equal(state.syncRefreshes, 0, "must not run live sync refresh in demo mode")
    Assert.Equal(state.hellos, 0, "must not send hello in demo mode")
    Assert.Equal(state.keySnapshots, 0, "must not send key snapshot in demo mode")
    Assert.Equal(state.refreshRequests, 0, "must not request peer sync in demo mode")
    Assert.Equal(state.queueRefreshes, 0, "must not refresh live queue data in demo mode")
  end)

  test("Refresh RunFullRefresh skips when stopped", function()
    local controller, state = BuildRefreshController({
      isStopped = function()
        return true
      end,
    })

    local result = controller.RunFullRefresh()

    Assert.False(result, "RunFullRefresh must return false when stopped")
    Assert.Equal(state.syncRefreshes, 0, "must not refresh when stopped")
    Assert.Equal(state.refreshRequests, 0, "stopped refresh must not request peer sync")
  end)

  test("Refresh RunFullRefresh skips during active M+", function()
    local controller, state = BuildRefreshController({
      getActiveChallengeMapID = function()
        return 2649
      end,
    })

    local result = controller.RunFullRefresh()

    Assert.False(result, "RunFullRefresh must return false during active M+")
    Assert.Equal(state.uiUpdates, 0, "must not update UI during active M+")
    Assert.Equal(state.refreshRequests, 0, "active M+ refresh must not request peer sync")
  end)

  test("Refresh RunFullRefresh debounces rapid clicks", function()
    local controller, state = BuildRefreshController({
      refreshDebounceSeconds = 1,
      now = 10,
    })

    local firstResult = controller.RunFullRefresh()
    local secondResult = controller.RunFullRefresh()

    state.setNow(11.2)
    local thirdResult = controller.RunFullRefresh()

    Assert.True(firstResult, "first refresh should run")
    Assert.False(secondResult, "second refresh inside debounce window must be ignored")
    Assert.True(thirdResult, "refresh after debounce window should run again")
    Assert.Equal(state.syncRefreshes, 2, "only first and third refresh should execute refresh actions")
  end)
end
