---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  local function BuildRefreshController(overrides)
    overrides = overrides or {}
    local state = {
      rosterUpdates = 0,
      syncRefreshes = 0,
      hellos = 0,
      keySnapshots = 0,
      queueRefreshes = 0,
      uiUpdates = 0,
      keyRefreshes = 0,
    }

    local addon = LoadAddonModules({ "isiLive_refresh.lua" })
    local controller = addon.Refresh.CreateController({
      isStopped = overrides.isStopped or function() return false end,
      isPaused = overrides.isPaused or function() return false end,
      isInGroup = overrides.isInGroup or function() return true end,
      isRosterEmpty = overrides.isRosterEmpty or function() return false end,
      triggerGroupRosterUpdate = function()
        state.rosterUpdates = state.rosterUpdates + 1
      end,
      forceRefreshSyncState = function()
        state.syncRefreshes = state.syncRefreshes + 1
      end,
      sendIsiLiveHello = function(_force)
        state.hellos = state.hellos + 1
      end,
      sendOwnKeySnapshot = function(_force)
        state.keySnapshots = state.keySnapshots + 1
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
      getActiveChallengeMapID = overrides.getActiveChallengeMapID or function() return nil end,
    })

    return controller, state
  end

  test("Refresh RunFullRefresh executes all refresh steps", function()
    local controller, state = BuildRefreshController()

    local result = controller.RunFullRefresh()

    Assert.True(result, "RunFullRefresh must return true when active")
    Assert.Equal(state.syncRefreshes, 1, "must refresh sync state")
    Assert.Equal(state.hellos, 1, "must send hello")
    Assert.Equal(state.keySnapshots, 1, "must send key snapshot")
    Assert.Equal(state.queueRefreshes, 1, "must refresh queue data")
    Assert.Equal(state.uiUpdates, 1, "must update UI")
  end)

  test("Refresh RunFullRefresh skips when stopped", function()
    local controller, state = BuildRefreshController({
      isStopped = function() return true end,
    })

    local result = controller.RunFullRefresh()

    Assert.False(result, "RunFullRefresh must return false when stopped")
    Assert.Equal(state.syncRefreshes, 0, "must not refresh when stopped")
  end)

  test("Refresh RunFullRefresh skips during active M+", function()
    local controller, state = BuildRefreshController({
      getActiveChallengeMapID = function() return 2649 end,
    })

    local result = controller.RunFullRefresh()

    Assert.False(result, "RunFullRefresh must return false during active M+")
    Assert.Equal(state.uiUpdates, 0, "must not update UI during active M+")
  end)
end
