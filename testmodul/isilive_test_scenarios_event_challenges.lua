local function RegisterChallengeStartAndDelayTests(test, Assert, _WithGlobals, LoadAddonModules, Fixtures)
  test("Event handlers capture RIO baseline snapshot on challenge start", function()
    local captureCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      captureRioBaselineSnapshot = function()
        captureCalls = captureCalls + 1
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_START")

    Assert.Equal(captureCalls, 1, "challenge start must capture one RIO baseline snapshot")
  end)

  test("Event handlers do not auto-hide main frame on challenge start by default", function()
    local hideCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      setMainFrameVisible = function(_visible)
        hideCalls = hideCalls + 1
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_START")

    Assert.Equal(hideCalls, 0, "challenge start must keep the main frame state unchanged by default")
  end)

  test("Event handlers auto-hide main frame on challenge start when auto-close is enabled", function()
    local hideCalls = 0
    local lastVisible = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      shouldAutoCloseOnKeyStart = function()
        return true
      end,
      setMainFrameVisible = function(visible)
        hideCalls = hideCalls + 1
        lastVisible = visible
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_START")

    Assert.Equal(hideCalls, 1, "enabled auto-close must hide the main frame on challenge start exactly once")
    Assert.Equal(lastVisible, false, "enabled auto-close must request a hidden main frame")
  end)

  test("Event handlers reset kick stats on challenge start", function()
    local resetCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      resetKickStats = function()
        resetCalls = resetCalls + 1
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_START")

    Assert.Equal(resetCalls, 1, "challenge start must reset kick stats exactly once")
  end)

  test("Event handlers forward challenge start to LFGDetect", function()
    local lfgEvents = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      handleLFGDetectEvent = function(event)
        lfgEvents[#lfgEvents + 1] = event
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_START")

    Assert.Equal(#lfgEvents, 1, "challenge start must notify LFGDetect exactly once")
    Assert.Equal(lfgEvents[1], "CHALLENGE_MODE_START", "LFGDetect must receive the key-start boundary")
  end)

  test("Event handlers auto-show main frame on challenge completion while grouped", function()
    local showCalls = 0
    local lastVisible = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      setMainFrameVisible = function(visible)
        showCalls = showCalls + 1
        lastVisible = visible
      end,
      isInGroup = function()
        return true
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")

    Assert.Equal(showCalls, 1, "challenge completion must call main-frame visibility update exactly once")
    Assert.Equal(lastVisible, true, "challenge completion must auto-show main frame while grouped")
  end)

  test("Event handlers skip auto-show on challenge completion when key-end setting is disabled", function()
    local showCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      shouldAutoOpenMainFrameOnKeyEnd = function()
        return false
      end,
      setMainFrameVisible = function(_visible)
        showCalls = showCalls + 1
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")

    Assert.Equal(showCalls, 0, "disabled key-end auto-open must not request a frame open on completion")
  end)

  test("Event handlers refresh CD tracker on challenge completion and reset", function()
    local cdRefreshCalls = 0
    local timerEvents = {}
    local cdRefreshOpts = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      handleMplusTimerEvent = function(event)
        timerEvents[#timerEvents + 1] = event
      end,
      updateCdTracker = function(opts)
        cdRefreshCalls = cdRefreshCalls + 1
        cdRefreshOpts[#cdRefreshOpts + 1] = opts
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    controller:Dispatch("CHALLENGE_MODE_RESET")

    Assert.Equal(timerEvents[1], "CHALLENGE_MODE_COMPLETED", "completion must reach the M+ timer before UI refresh")
    Assert.Equal(timerEvents[2], "CHALLENGE_MODE_RESET", "reset must reach the M+ timer before UI refresh")
    Assert.Equal(cdRefreshCalls, 2, "key end and key reset must refresh the CD tracker row")
    Assert.True(cdRefreshOpts[1].resetRuntimeTimers, "completion must request a visible BR/BL timer reset")
    Assert.True(cdRefreshOpts[2].resetRuntimeTimers, "reset must request a visible BR/BL timer reset")
    Assert.True(cdRefreshOpts[1].suppressBattleResReadySound, "completion must suppress BRes-ready sound")
    Assert.True(cdRefreshOpts[1].suppressLustReadySound, "completion must suppress Bloodlust-ready sound")
  end)

  test("Event handlers enable RIO delta only after delayed post-run refresh", function()
    local enableCalls = 0
    local refreshCalls = 0
    local delayedCallback = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      timerAfter = function(seconds, callback)
        if seconds == 5 then
          delayedCallback = callback
        end
      end,
      runFullRefresh = function()
        refreshCalls = refreshCalls + 1
        return true
      end,
      enableRioDeltaDisplay = function()
        enableCalls = enableCalls + 1
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")

    Assert.Equal(enableCalls, 0, "delta display must stay disabled before delayed refresh callback")
    Assert.NotNil(delayedCallback, "post-run refresh must be scheduled with delay")
    if type(delayedCallback) ~= "function" then
      return
    end

    delayedCallback()

    Assert.Equal(refreshCalls, 1, "delayed callback must run one refresh attempt")
    Assert.Equal(enableCalls, 1, "delta display must enable after delayed refresh")
  end)
end

local function RegisterChallengeRetryTests(test, Assert, LoadAddonModules, Fixtures)
  test("Event handlers retry post-run refresh when first delayed attempt is blocked", function()
    local enableCalls = 0
    local refreshCalls = 0
    local callbacks = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      timerAfter = function(_seconds, callback)
        table.insert(callbacks, callback)
      end,
      runFullRefresh = function()
        refreshCalls = refreshCalls + 1
        return refreshCalls >= 2
      end,
      enableRioDeltaDisplay = function()
        enableCalls = enableCalls + 1
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")

    Assert.Equal(enableCalls, 0, "delta display must stay disabled until refresh succeeds")
    Assert.Equal(#callbacks, 1, "initial delayed refresh callback must be scheduled")

    callbacks[1]()
    Assert.Equal(refreshCalls, 1, "first delayed refresh attempt should run once")
    Assert.Equal(enableCalls, 0, "delta display must not enable on failed refresh attempt")
    Assert.Equal(#callbacks, 2, "failed attempt must schedule one retry callback")

    callbacks[2]()
    Assert.Equal(refreshCalls, 2, "retry callback should run second refresh attempt")
    Assert.Equal(enableCalls, 1, "delta display must enable after successful retry")
  end)

  test("Event handlers schedule follow-up refreshes after successful delayed refresh", function()
    local refreshCalls = 0
    local scheduled = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      timerAfter = function(seconds, callback)
        table.insert(scheduled, {
          seconds = seconds,
          callback = callback,
        })
      end,
      runFullRefresh = function()
        refreshCalls = refreshCalls + 1
        return true
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    Assert.Equal(#scheduled, 1, "initial delayed refresh callback must be scheduled")
    Assert.Equal(scheduled[1].seconds, 5, "initial delayed refresh should use 5-second delay")

    scheduled[1].callback()
    Assert.Equal(refreshCalls, 1, "initial delayed callback should run one refresh attempt")
    Assert.Equal(#scheduled, 2, "successful refresh should schedule first follow-up callback")
    Assert.Equal(scheduled[2].seconds, 6, "follow-up refresh should use short fixed delay")

    scheduled[2].callback()
    Assert.Equal(refreshCalls, 2, "first follow-up callback should run second refresh attempt")
    Assert.Equal(#scheduled, 3, "second follow-up callback should be scheduled")
    Assert.Equal(scheduled[3].seconds, 6, "second follow-up should keep same delay")

    scheduled[3].callback()
    Assert.Equal(refreshCalls, 3, "second follow-up callback should run third refresh attempt")
    Assert.Equal(#scheduled, 3, "no further follow-up callback should be scheduled after configured attempts")
  end)

  test("Event handlers retry completed-run capture when damage meter snapshot is delayed", function()
    local captureAttempts = 0
    local scheduled = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      timerAfter = function(seconds, callback)
        table.insert(scheduled, {
          seconds = seconds,
          callback = callback,
        })
      end,
      recordRun = function(mapID, level, onTime)
        captureAttempts = captureAttempts + 1
        Assert.Equal(mapID, 2662, "completed-run retry must keep challenge map id")
        Assert.Equal(level, 10, "completed-run retry must keep challenge level")
        Assert.True(onTime == true, "completed-run retry must keep timed flag")
        return captureAttempts >= 2
      end,
    })

    local previousChallengeMode = _G.C_ChallengeMode
    _G.C_ChallengeMode = {
      GetCompletionInfo = function()
        return 2662, 10, 123456, true
      end,
    }

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    _G.C_ChallengeMode = previousChallengeMode

    Assert.Equal(captureAttempts, 1, "challenge completion should attempt immediate run capture once")
    Assert.Equal(#scheduled, 2, "challenge completion should schedule one capture retry plus delayed refresh")
    Assert.Equal(scheduled[1].seconds, 1, "capture retry should use short fixed delay")
    Assert.Equal(scheduled[2].seconds, 5, "delayed refresh should keep its existing delay")

    scheduled[1].callback()

    Assert.Equal(captureAttempts, 2, "capture retry should attempt completed-run capture again")
  end)
end

local function RegisterHiddenFrameRegenTests(test, Assert, LoadAddonModules, Fixtures)
  test("Event handlers keep non-UI regen recovery while frame is hidden", function()
    local applyHotkeyCalls = 0
    local pendingHeightApplied = nil
    local teleportRefreshCalls = 0
    local restoreButtonCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      getPendingBindingApply = function()
        return true
      end,
      applyHotkeyBindings = function()
        applyHotkeyCalls = applyHotkeyCalls + 1
      end,
      getPendingMainFrameHeight = function()
        return 420
      end,
      setMainFrameHeightSafe = function(height)
        pendingHeightApplied = height
      end,
      getPendingMainFrameWidth = function()
        return nil
      end,
      setMainFrameWidthSafe = function(_width) end,
      isMainFrameShown = function()
        return false
      end,
      updateMPlusTeleportButton = function()
        teleportRefreshCalls = teleportRefreshCalls + 1
      end,
      tryRestoreCenterNoticeTeleportButton = function()
        restoreButtonCalls = restoreButtonCalls + 1
      end,
    })

    controller:Dispatch("PLAYER_REGEN_ENABLED")

    Assert.Equal(applyHotkeyCalls, 1, "regen must still apply pending bindings while frame is hidden")
    Assert.Equal(pendingHeightApplied, 420, "regen must still apply pending frame height while frame is hidden")
    Assert.Equal(teleportRefreshCalls, 0, "hidden regen must skip teleport UI refresh")
    Assert.Equal(restoreButtonCalls, 0, "hidden regen must skip teleport button restore")
  end)

  test("Event handlers apply pending visibility on regen when combat-deferred show is queued", function()
    local visibilityCalls = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      getPendingMainFrameVisible = function()
        return true
      end,
      setMainFrameVisible = function(visible)
        table.insert(visibilityCalls, visible)
      end,
      isMainFrameShown = function()
        return true
      end,
      updateMPlusTeleportButton = function() end,
      tryRestoreCenterNoticeTeleportButton = function() end,
    })

    controller:Dispatch("PLAYER_REGEN_ENABLED")

    Assert.Equal(#visibilityCalls, 1, "regen must apply pending visibility exactly once")
    Assert.True(visibilityCalls[1], "regen must apply pending show when combat-deferred show was queued")
  end)

  test("Event handlers apply pending visibility on regen when combat-deferred hide is queued", function()
    local visibilityCalls = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      getPendingMainFrameVisible = function()
        return false
      end,
      setMainFrameVisible = function(visible)
        table.insert(visibilityCalls, visible)
      end,
      isMainFrameShown = function()
        return false
      end,
      updateMPlusTeleportButton = function() end,
      tryRestoreCenterNoticeTeleportButton = function() end,
    })

    controller:Dispatch("PLAYER_REGEN_ENABLED")

    Assert.Equal(#visibilityCalls, 1, "regen must apply pending visibility exactly once")
    Assert.False(visibilityCalls[1], "regen must apply pending hide when combat-deferred hide was queued")
  end)

  test("Event handlers skip pending visibility on regen when no combat-deferred toggle exists", function()
    local visibilityCalls = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      getPendingMainFrameVisible = function()
        return nil
      end,
      setMainFrameVisible = function(visible)
        table.insert(visibilityCalls, visible)
      end,
      isMainFrameShown = function()
        return true
      end,
      updateMPlusTeleportButton = function() end,
      tryRestoreCenterNoticeTeleportButton = function() end,
    })

    controller:Dispatch("PLAYER_REGEN_ENABLED")

    Assert.Equal(#visibilityCalls, 0, "regen must not call setMainFrameVisible when no pending toggle exists")
  end)

  test("Event handlers run regen teleport refresh when frame is visible", function()
    local teleportRefreshCalls = 0
    local restoreButtonCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      isMainFrameShown = function()
        return true
      end,
      updateMPlusTeleportButton = function()
        teleportRefreshCalls = teleportRefreshCalls + 1
      end,
      tryRestoreCenterNoticeTeleportButton = function()
        restoreButtonCalls = restoreButtonCalls + 1
      end,
    })

    controller:Dispatch("PLAYER_REGEN_ENABLED")

    Assert.Equal(teleportRefreshCalls, 1, "visible regen must refresh teleport UI")
    Assert.Equal(restoreButtonCalls, 1, "visible regen must restore center notice teleport button")
  end)

  test("Event handlers rerender visible UI on regen after combat-safe layout changes", function()
    local counters = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      isMainFrameShown = function()
        return true
      end,
      updateMPlusTeleportButton = function() end,
      tryRestoreCenterNoticeTeleportButton = function() end,
    })

    controller:Dispatch("PLAYER_REGEN_ENABLED")

    Assert.Equal(counters.uiUpdates, 1, "visible regen must rerender the main UI once")
  end)

  test("Event handlers suppress background processing while raid mode is active", function()
    local counters = {
      groupUpdates = 0,
      uiUpdates = 0,
      backgroundSnapshots = 0,
      teleportUpdates = 0,
      chatProcessed = 0,
    }

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      isRaidGroup = function()
        return true
      end,
      handleGroupRosterUpdate = function()
        counters.groupUpdates = counters.groupUpdates + 1
      end,
      updateUI = function()
        counters.uiUpdates = counters.uiUpdates + 1
      end,
      updateMPlusTeleportButton = function()
        counters.teleportUpdates = counters.teleportUpdates + 1
      end,
      sendOwnBackgroundSnapshot = function()
        counters.backgroundSnapshots = counters.backgroundSnapshots + 1
      end,
      processAddonMessage = function()
        counters.chatProcessed = counters.chatProcessed + 1
        return { shouldAck = true }
      end,
      getPendingMainFrameVisible = function()
        return nil
      end,
      getPendingMainFrameHeight = function()
        return nil
      end,
      getPendingMainFrameWidth = function()
        return nil
      end,
      isMainFrameShown = function()
        return false
      end,
      tryRestoreCenterNoticeTeleportButton = function() end,
      updateCdTracker = function()
        counters.backgroundSnapshots = counters.backgroundSnapshots + 1
      end,
      updateStatusLine = function()
        counters.backgroundSnapshots = counters.backgroundSnapshots + 1
      end,
      maybeShowNonMythicDungeonEntryNotice = function()
        counters.backgroundSnapshots = counters.backgroundSnapshots + 1
      end,
      maybeShowPortalNavigatorNotice = function()
        counters.backgroundSnapshots = counters.backgroundSnapshots + 1
      end,
      checkIfEnteredTargetDungeon = function()
        counters.backgroundSnapshots = counters.backgroundSnapshots + 1
      end,
    })

    controller:Dispatch("PLAYER_LOGIN")
    controller:Dispatch("PLAYER_ENTERING_WORLD")
    controller:Dispatch("PLAYER_SPECIALIZATION_CHANGED", "player")
    controller:Dispatch("PLAYER_EQUIPMENT_CHANGED")
    controller:Dispatch("SPELL_UPDATE_COOLDOWN")
    controller:Dispatch("CHAT_MSG_ADDON", "ISI_SYNC", "REQSYNC", "PARTY", "Alpha")
    controller:Dispatch("GROUP_ROSTER_UPDATE")

    Assert.Equal(counters.groupUpdates, 1, "raid mode must still route roster updates so raid exit can be detected")
    Assert.Equal(counters.uiUpdates, 0, "raid mode must not rerender the UI")
    Assert.Equal(counters.teleportUpdates, 0, "raid mode must not refresh teleport buttons")
    Assert.Equal(counters.chatProcessed, 0, "raid mode must not process addon sync traffic")
    Assert.Equal(counters.backgroundSnapshots, 0, "raid mode must not run background refresh hooks")
  end)

  test("Event handlers suppress addon sync messages while raid mode is active", function()
    local counters = { uiUpdates = 0, refreshResponses = 0 }
    local syncCalls = 0

    local addon = LoadAddonModules({ "isiLive_sync.lua", "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      isRaidGroup = function()
        return true
      end,
      processAddonMessage = function()
        syncCalls = syncCalls + 1
        error("raid mode must stop addon sync before parsing")
      end,
      sendAck = function()
        error("raid mode must suppress sync replies")
      end,
      sendIsiLiveHello = function()
        error("raid mode must suppress sync replies")
      end,
      sendRefreshResponse = function()
        error("raid mode must suppress sync replies")
      end,
      sendOwnTargetSnapshot = function()
        error("raid mode must suppress sync replies")
      end,
      sendOwnKickState = function()
        error("raid mode must suppress sync replies")
      end,
      sendLibKeystonePartyData = function()
        error("raid mode must suppress libkeystone replies")
      end,
      sendOwnKeystoneToChat = function()
        error("raid mode must suppress share-key replies")
      end,
      updateStatusLine = function()
        error("raid mode must suppress statusline refresh")
      end,
      updateMPlusTeleportButton = function()
        error("raid mode must suppress teleport refresh")
      end,
      updateUI = function()
        error("raid mode must suppress UI refresh")
      end,
    })

    controller:Dispatch("CHAT_MSG_ADDON", "ISI_SYNC", "HELLO:0.9.36:2:123:refresh", "PARTY", "Alpha-RealmA")

    Assert.Equal(syncCalls, 0, "raid mode must stop addon sync before parsing")
    Assert.Equal(counters.uiUpdates, 0, "raid mode must not force UI redraws")
    Assert.Equal(counters.refreshResponses, 0, "raid mode must not trigger refresh responses")
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules
  local Fixtures = ctx.fixtures

  RegisterChallengeStartAndDelayTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterChallengeRetryTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterHiddenFrameRegenTests(test, Assert, LoadAddonModules, Fixtures)
end
