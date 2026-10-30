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
      backgroundSnapshots = 0,
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
      sendOwnKeySnapshot = function(_force, _source, allowHidden)
        state.keySnapshots = state.keySnapshots + 1
        state.lastKeySnapshotAllowHidden = allowHidden
      end,
      sendOwnBackgroundSnapshot = function(_source)
        state.backgroundSnapshots = (state.backgroundSnapshots or 0) + 1
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

  test("Refresh HandleOwnedKeyRefresh sends force snapshot when key changed", function()
    local controller, state = BuildRefreshController({
      keyChanged = true,
    })

    local changed = controller.HandleOwnedKeyRefresh()

    Assert.True(changed, "HandleOwnedKeyRefresh must return the local key change result")
    Assert.Equal(state.keyRefreshes, 1, "HandleOwnedKeyRefresh must refresh the local key exactly once")
    Assert.Equal(state.uiUpdates, 1, "local key changes must still refresh the UI once")
    Assert.Equal(state.keySnapshots, 1, "HandleOwnedKeyRefresh must send a forced snapshot when key changed")
    Assert.Equal(
      state.backgroundSnapshots,
      0,
      "HandleOwnedKeyRefresh must not send background snapshot when key changed"
    )
  end)

  test("Refresh HandleOwnedKeyRefresh sends background snapshot when key unchanged", function()
    local controller, state = BuildRefreshController({
      keyChanged = false,
    })

    local changed = controller.HandleOwnedKeyRefresh()

    Assert.False(changed, "HandleOwnedKeyRefresh must return false when key did not change")
    Assert.Equal(state.keyRefreshes, 1, "HandleOwnedKeyRefresh must refresh the local key exactly once")
    Assert.Equal(state.uiUpdates, 0, "no UI update when key did not change")
    Assert.Equal(state.backgroundSnapshots, 1, "HandleOwnedKeyRefresh must send background snapshot when key unchanged")
    Assert.Equal(state.keySnapshots, 0, "HandleOwnedKeyRefresh must not send forced snapshot when key unchanged")
  end)

  test("Refresh HandleOwnedKeyRefresh sends force snapshot when post-challenge flag is set", function()
    local controller, state = BuildRefreshController({
      keyChanged = false,
    })

    controller.NotifyPostChallengeSync()
    local changed = controller.HandleOwnedKeyRefresh()

    Assert.False(changed, "key did not change")
    Assert.Equal(state.keySnapshots, 1, "must send forced snapshot when post-challenge flag is set")
    Assert.Equal(state.backgroundSnapshots, 0, "must not send background snapshot when post-challenge flag is set")
  end)

  test("Refresh publishes the changed own key while the window is hidden", function()
    local controller, state = BuildRefreshController({
      keyChanged = true,
    })

    controller.HandleOwnedKeyRefresh()

    Assert.Equal(state.keySnapshots, 1, "a changed key must be published")
    Assert.True(state.lastKeySnapshotAllowHidden, "the snapshot must pass the hidden gate of rule 52")
  end)

  test("Refresh RunFullRefresh skips when paused", function()
    local controller, state = BuildRefreshController({
      isPaused = function()
        return true
      end,
    })
    Assert.False(controller.RunFullRefresh(), "paused refresh must return false")
    Assert.Equal(state.syncRefreshes, 0)
  end)

  test("Refresh RunFullRefresh triggers roster update when group is non-empty and roster is empty", function()
    local controller, state = BuildRefreshController({
      isInGroup = function()
        return true
      end,
      isRosterEmpty = function()
        return true
      end,
    })
    Assert.True(controller.RunFullRefresh())
    Assert.Equal(state.rosterUpdates, 1, "empty roster in a group must trigger a roster update once")
  end)

  test("Refresh RunFullRefresh in testAllMode reroutes to demo refresh", function()
    local controller, state = BuildRefreshController({
      isTestAllMode = function()
        return true
      end,
    })
    Assert.True(controller.RunFullRefresh())
    Assert.Equal(state.demoRefreshes, 1, "testAllMode must also route to refreshTestModeRoster")
  end)

  test("Refresh RunFullRefresh emits runtime-log traces when loggers are wired", function()
    local state = {
      logs = {},
      logfs = {},
    }
    local addon = LoadAddonModules({ "isiLive_refresh.lua" })
    local controller = addon.Refresh.CreateController({
      getTime = function()
        return 0
      end,
      sendIsiLiveHello = function() end,
      sendOwnKeySnapshot = function() end,
      sendOwnBackgroundSnapshot = function() end,
      sendRefreshRequest = function() end,
      queueForceRefreshData = function() end,
      updateUI = function() end,
      triggerGroupRosterUpdate = function() end,
      forceRefreshSyncState = function() end,
      refreshTestModeRoster = function()
        return true
      end,
      refreshLocalPlayerKey = function()
        return false
      end,
      getActiveChallengeMapID = function()
        return nil
      end,
      logRuntimeTrace = function(msg)
        table.insert(state.logs, msg)
      end,
      logRuntimeTracef = function(fmt, ...)
        table.insert(state.logfs, string.format(fmt, ...))
      end,
    })
    controller.RunFullRefresh()
    controller.NotifyPostChallengeSync()
    controller.HandleOwnedKeyRefresh()
    Assert.True(#state.logfs > 0, "logf path must fire on full-refresh + owned-key-refresh")
    Assert.True(#state.logs > 0, "plain log path must fire on notify_post_challenge_sync")
  end)

  test("Refresh RunFullRefresh logs blocked reason when stopped / paused / challenge-active", function()
    local addon = LoadAddonModules({ "isiLive_refresh.lua" })
    local stoppedLogs = {}
    local stoppedController = addon.Refresh.CreateController({
      isStopped = function()
        return true
      end,
      logRuntimeTracef = function(fmt, ...)
        table.insert(stoppedLogs, string.format(fmt, ...))
      end,
    })
    stoppedController.RunFullRefresh()
    local matchedStopped = false
    for _, line in ipairs(stoppedLogs) do
      if line:find("reason=stopped", 1, true) then
        matchedStopped = true
      end
    end
    Assert.True(matchedStopped, "stopped blocked reason must be traced")

    local pausedLogs = {}
    local pausedController = addon.Refresh.CreateController({
      isPaused = function()
        return true
      end,
      logRuntimeTracef = function(fmt, ...)
        table.insert(pausedLogs, string.format(fmt, ...))
      end,
    })
    pausedController.RunFullRefresh()
    local matchedPaused = false
    for _, line in ipairs(pausedLogs) do
      if line:find("reason=paused", 1, true) then
        matchedPaused = true
      end
    end
    Assert.True(matchedPaused, "paused blocked reason must be traced")

    local challengeLogs = {}
    local challengeController = addon.Refresh.CreateController({
      getActiveChallengeMapID = function()
        return 2649
      end,
      logRuntimeTracef = function(fmt, ...)
        table.insert(challengeLogs, string.format(fmt, ...))
      end,
    })
    challengeController.RunFullRefresh()
    local matchedChallenge = false
    for _, line in ipairs(challengeLogs) do
      if line:find("reason=challenge_active", 1, true) and line:find("mapID=2649", 1, true) then
        matchedChallenge = true
      end
    end
    Assert.True(matchedChallenge, "challenge_active blocked reason must include mapID")
  end)

  test("Refresh RunFullRefresh debounce path logs remaining cooldown", function()
    local logs = {}
    local addon = LoadAddonModules({ "isiLive_refresh.lua" })
    local now = 10
    local controller = addon.Refresh.CreateController({
      getTime = function()
        return now
      end,
      refreshDebounceSeconds = 2,
      sendIsiLiveHello = function() end,
      sendOwnKeySnapshot = function() end,
      sendRefreshRequest = function() end,
      queueForceRefreshData = function() end,
      updateUI = function() end,
      forceRefreshSyncState = function() end,
      logRuntimeTracef = function(fmt, ...)
        table.insert(logs, string.format(fmt, ...))
      end,
    })
    controller.RunFullRefresh()
    now = 10.5
    controller.RunFullRefresh()
    local matched = false
    for _, line in ipairs(logs) do
      if line:find("reason=debounce", 1, true) and line:find("remain=1.5", 1, true) then
        matched = true
      end
    end
    Assert.True(matched, "debounce block must include remaining seconds in the log: " .. table.concat(logs, " | "))
  end)

  test("Refresh controller default opts guard against raw nil without raising", function()
    local addon = LoadAddonModules({ "isiLive_refresh.lua" })
    local controller = addon.Refresh.CreateController()
    -- With all opts defaulted to no-op/false the full refresh must still
    -- report true (no test mode, no debounce, nothing blocking).
    Assert.True(controller.RunFullRefresh(), "default-args controller must complete RunFullRefresh")
    Assert.False(controller.HandleOwnedKeyRefresh(), "default refreshLocalPlayerKey returns false => no change")
  end)

  test("Refresh debounce negative value is clamped to zero (never blocks)", function()
    local addon = LoadAddonModules({ "isiLive_refresh.lua" })
    local calls = 0
    local controller = addon.Refresh.CreateController({
      refreshDebounceSeconds = -5,
      sendIsiLiveHello = function() end,
      sendOwnKeySnapshot = function() end,
      sendRefreshRequest = function() end,
      queueForceRefreshData = function() end,
      updateUI = function() end,
      forceRefreshSyncState = function()
        calls = calls + 1
      end,
    })
    controller.RunFullRefresh()
    controller.RunFullRefresh()
    Assert.Equal(calls, 2, "clamped debounce=0 must allow back-to-back refreshes")
  end)
end
