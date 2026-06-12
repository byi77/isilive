---@diagnostic disable: undefined-global

-- Scenarios for the EventHandlers wiring surface of
-- factory/isiLive_controller_wiring.lua. The existing
-- isilive_test_scenarios_controller_wiring.lua file focuses on
-- CreateGroupController; this file covers:
--
--   * CreateEventHandlersController required-deps validation
--   * CreateEventHandlersControllerFromContext happy path
--   * BuildTimerAfter error routing to the global error handler
--   * BuildEventHandlersDepsFromContext.sendOwnKeystoneToChat closure:
--       - 30s cooldown dedup
--       - solo-fallback path via _G.print
--       - in-group path via ContextHelpers.SendPartyChatMessage
--       - no-line abort when the announce builder returns empty
--
-- The closure path is deliberately the widest target — it is ~100 lines
-- of untested code inside the module and has several branches that
-- ContextHelpers and WoW globals drive.

local function Noop() end

local function BuildMinimalEventDeps()
  return {
    addonName = "isiLive",
    defaultLocale = "enUS",
    locales = { enUS = {} },
    resolveLocaleTag = Noop,
    setLocaleTable = Noop,
    isInGroup = Noop,
    isInChallengeMode = Noop,
    isNegativeApplicationStatusEvent = Noop,
    getNormalizedActiveEntryInfo = Noop,
    sendIsiLiveHello = Noop,
    sendOwnKeySnapshot = Noop,
    sendOwnBackgroundSnapshot = Noop,
    sendRefreshResponse = Noop,
    ensureQueueDebugStorage = Noop,
    setQueueDebugEnabled = Noop,
    registerIsiLiveSyncPrefix = Noop,
    applyHotkeyBindings = Noop,
    startBindingWatchdog = Noop,
    getUnitNameAndRealm = Noop,
    markIsiLiveUser = Noop,
    applyKnownKeyToRosterEntry = Noop,
    runFullRefresh = Noop,
    state = {
      isTestMode = Noop,
      isTestAllMode = Noop,
      setPendingQueueJoinInfo = Noop,
      setPendingPostChallengeRefresh = Noop,
      getActiveJoinedKeyMapID = Noop,
      setActiveJoinedKeyMapID = Noop,
      getPendingBindingApply = Noop,
      getRoster = function()
        return {}
      end,
    },
    refs = {
      mainFrame = {
        IsShown = function()
          return false
        end,
      },
      mainUI = {
        GetPendingHeight = Noop,
        GetPendingWidth = Noop,
        GetPendingVisible = Noop,
      },
      applySecureSpellToButton = Noop,
    },
    controllers = {
      group = {
        HandleGroupRosterUpdate = Noop,
      },
    },
    callbacks = {
      exitTestMode = Noop,
      clearLatestQueueTarget = Noop,
      updateMPlusTeleportButton = Noop,
      captureQueueJoinCandidate = Noop,
      updateUI = Noop,
      refreshReadyCheckUI = Noop,
      setMainFrameVisible = Noop,
      updateLeaderButtons = Noop,
      updateStatusLine = Noop,
      applyLocalizationToUI = Noop,
      restoreLayoutState = Noop,
      updateCountdownCancelButton = Noop,
      checkIfEnteredTargetDungeon = Noop,
      setMainFrameHeightSafe = Noop,
      setMainFrameWidthSafe = Noop,
    },
    modules = {
      sync = {
        ProcessAddonMessage = Noop,
        GetPrefix = function()
          return "ISILIVE"
        end,
        IsUserKnown = function()
          return false
        end,
      },
    },
  }
end

local function CaptureEventModule()
  local captured
  local module = {
    CreateController = function(config)
      captured = config
      return { Handle = Noop }
    end,
  }
  return module, function()
    return captured
  end
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  -- ================================================================
  -- CreateEventHandlersController: required-deps validation
  -- ================================================================

  test("ControllerWiring CreateEventHandlersController throws when eventHandlersModule is nil", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local ok, err = pcall(function()
      addon.ControllerWiring.CreateEventHandlersController(nil, BuildMinimalEventDeps())
    end)
    Assert.False(ok, "nil eventHandlersModule must throw")
    Assert.True(
      type(err) == "string" and err:find("eventHandlersModule", 1, true) ~= nil,
      "error must mention eventHandlersModule"
    )
  end)

  test("ControllerWiring CreateEventHandlersController throws when state table is missing", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local deps = BuildMinimalEventDeps()
    deps.state = nil
    local module = CaptureEventModule()
    local ok, err = pcall(function()
      addon.ControllerWiring.CreateEventHandlersController(module, deps)
    end)
    Assert.False(ok, "missing state table must throw")
    Assert.True(type(err) == "string" and err:find("state", 1, true) ~= nil, "error must mention state")
  end)

  test("ControllerWiring CreateEventHandlersController throws when refs table is missing", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local deps = BuildMinimalEventDeps()
    deps.refs = nil
    local module = CaptureEventModule()
    local ok, err = pcall(function()
      addon.ControllerWiring.CreateEventHandlersController(module, deps)
    end)
    Assert.False(ok, "missing refs table must throw")
    Assert.True(type(err) == "string" and err:find("refs", 1, true) ~= nil, "error must mention refs")
  end)

  test("ControllerWiring CreateEventHandlersController throws when controllers table is missing", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local deps = BuildMinimalEventDeps()
    deps.controllers = nil
    local module = CaptureEventModule()
    local ok, err = pcall(function()
      addon.ControllerWiring.CreateEventHandlersController(module, deps)
    end)
    Assert.False(ok, "missing controllers table must throw")
    Assert.True(type(err) == "string" and err:find("controllers", 1, true) ~= nil, "error must mention controllers")
  end)

  test("ControllerWiring CreateEventHandlersController throws when modules table is missing", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local deps = BuildMinimalEventDeps()
    deps.modules = nil
    local module = CaptureEventModule()
    local ok, err = pcall(function()
      addon.ControllerWiring.CreateEventHandlersController(module, deps)
    end)
    Assert.False(ok, "missing modules table must throw")
    Assert.True(type(err) == "string" and err:find("modules", 1, true) ~= nil, "error must mention modules")
  end)

  test("ControllerWiring CreateEventHandlersController throws when addonName is missing", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local deps = BuildMinimalEventDeps()
    deps.addonName = nil
    local module = CaptureEventModule()
    local ok, err = pcall(function()
      addon.ControllerWiring.CreateEventHandlersController(module, deps)
    end)
    Assert.False(ok, "missing addonName must throw")
    Assert.True(type(err) == "string" and err:find("addonName", 1, true) ~= nil, "error must mention addonName")
  end)

  test("ControllerWiring CreateEventHandlersController throws when resolveLocaleTag is missing", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local deps = BuildMinimalEventDeps()
    deps.resolveLocaleTag = nil
    local module = CaptureEventModule()
    local ok, err = pcall(function()
      addon.ControllerWiring.CreateEventHandlersController(module, deps)
    end)
    Assert.False(ok, "missing resolveLocaleTag must throw")
    Assert.True(
      type(err) == "string" and err:find("resolveLocaleTag", 1, true) ~= nil,
      "error must mention resolveLocaleTag"
    )
  end)

  -- ================================================================
  -- CreateEventHandlersController: happy path + optional defaults
  -- ================================================================

  test("ControllerWiring CreateEventHandlersController succeeds with minimal deps", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local module, getCaptured = CaptureEventModule()
    local ctrl = addon.ControllerWiring.CreateEventHandlersController(module, BuildMinimalEventDeps())
    Assert.NotNil(ctrl, "controller must be returned")
    local config = getCaptured()
    Assert.NotNil(config, "eventHandlersModule.CreateController must receive a config")
    Assert.Equal(config.addonName, "isiLive", "addonName must be forwarded")
    Assert.Equal(type(config.isRaidGroup), "function", "isRaidGroup default must be a function")
    Assert.Equal(config.isRaidGroup(), false, "missing isRaidGroup dep must default to false")
    Assert.Equal(type(config.shouldShowMainFrameOnStartup), "function", "startup default must be a function")
    Assert.Equal(config.shouldShowMainFrameOnStartup(), true, "startup default must be true")
    Assert.Equal(type(config.shouldAutoOpenMainFrameOnKeyEnd), "function", "key-end default must be a function")
    Assert.Equal(config.shouldAutoOpenMainFrameOnKeyEnd(), true, "key-end default must be true")
    Assert.Equal(type(config.shouldAutoCloseOnKeyStart), "function", "key-start auto-close default must be a function")
    Assert.Equal(config.shouldAutoCloseOnKeyStart(), false, "key-start auto-close default must be false")
  end)

  test("ControllerWiring CreateEventHandlersController threads handleGroupRosterUpdate via controller", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local module, getCaptured = CaptureEventModule()
    local invoked = false
    local deps = BuildMinimalEventDeps()
    deps.controllers.group.HandleGroupRosterUpdate = function()
      invoked = true
    end
    addon.ControllerWiring.CreateEventHandlersController(module, deps)
    local config = getCaptured()
    config.handleGroupRosterUpdate()
    Assert.True(invoked, "handleGroupRosterUpdate must invoke controllers.group.HandleGroupRosterUpdate")
  end)

  test("ControllerWiring CreateEventHandlersController processAddonMessage feeds sync module", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local module, getCaptured = CaptureEventModule()
    local received = {}
    local deps = BuildMinimalEventDeps()
    deps.getUnitNameAndRealm = function(_unit)
      return "LocalPlayer", "LocalRealm"
    end
    deps.modules.sync.ProcessAddonMessage = function(prefix, message, sender, name, realm, channel)
      received = {
        prefix = prefix,
        message = message,
        sender = sender,
        name = name,
        realm = realm,
        channel = channel,
      }
      return "handled"
    end
    addon.ControllerWiring.CreateEventHandlersController(module, deps)
    local config = getCaptured()
    local result = config.processAddonMessage("ISILIVE", "HELLO:1", "Peer-Realm", "PARTY")
    Assert.Equal(received.prefix, "ISILIVE", "prefix must be forwarded")
    Assert.Equal(received.message, "HELLO:1", "message must be forwarded")
    Assert.Equal(received.sender, "Peer-Realm", "sender must be forwarded")
    Assert.Equal(received.name, "LocalPlayer", "local name must be injected from getUnitNameAndRealm")
    Assert.Equal(received.realm, "LocalRealm", "local realm must be injected from getUnitNameAndRealm")
    Assert.Equal(received.channel, "PARTY", "channel must be forwarded")
    Assert.Equal(result, "handled", "sync module's return value must propagate to the caller")
  end)

  test("ControllerWiring sendShareKeysCooldownState mirrors only the locally owned cooldown", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local module, getCaptured = CaptureEventModule()
    local sentRemains = {}
    local localRemain = 0
    local deps = BuildMinimalEventDeps()
    deps.getShareKeysLocalCooldownRemaining = function()
      return localRemain
    end
    -- The full getter also reports remote-mirrored locks; it must never
    -- drive SKCD sends, otherwise the lock reflects between peers forever.
    deps.getShareKeysCooldownRemaining = function()
      return 23
    end
    deps.modules.sync.SendShareKeysCooldown = function(opts)
      table.insert(sentRemains, opts.remain)
      return true
    end
    addon.ControllerWiring.CreateEventHandlersController(module, deps)
    local config = getCaptured()

    Assert.False(config.sendShareKeysCooldownState(), "a remote-owned lock must not be mirrored")
    Assert.Equal(#sentRemains, 0, "no SKCD payload may be sent for a remote-owned lock")

    localRemain = 17
    Assert.True(config.sendShareKeysCooldownState(), "a locally owned lock must be mirrored")
    Assert.Equal(sentRemains[1], 17, "SKCD payload must carry the locally owned remaining time")
  end)

  test("ControllerWiring CreateEventHandlersController sendAck skips when sender is empty", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local module, getCaptured = CaptureEventModule()
    local sentCalls = 0
    WithGlobals({
      C_ChatInfo = {
        SendAddonMessage = function(_prefix, _msg, _channel, _sender)
          sentCalls = sentCalls + 1
        end,
      },
    }, function()
      local deps = BuildMinimalEventDeps()
      deps.getAddonVersionRaw = function()
        return "0.9.180"
      end
      addon.ControllerWiring.CreateEventHandlersController(module, deps)
      local config = getCaptured()
      config.sendAck(nil)
      config.sendAck("")
    end)
    Assert.Equal(sentCalls, 0, "sendAck must skip when sender is nil or empty")
  end)

  test("ControllerWiring CreateEventHandlersController sendAck includes addon version in payload", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local module, getCaptured = CaptureEventModule()
    local captured
    WithGlobals({
      C_ChatInfo = {
        SendAddonMessage = function(prefix, msg, channel, sender)
          captured = { prefix = prefix, msg = msg, channel = channel, sender = sender }
        end,
      },
    }, function()
      local deps = BuildMinimalEventDeps()
      deps.getAddonVersionRaw = function()
        return "0.9.180"
      end
      addon.ControllerWiring.CreateEventHandlersController(module, deps)
      local config = getCaptured()
      config.sendAck("Alice-Realm")
    end)
    Assert.NotNil(captured, "sendAck must dispatch an addon message when sender is valid")
    Assert.Equal(captured.prefix, "ISILIVE", "ACK prefix must be the sync prefix")
    Assert.Equal(captured.msg, "ACK:0.9.180", "ACK payload must embed the addon version")
    Assert.Equal(captured.channel, "WHISPER", "ACK must be delivered via WHISPER")
    Assert.Equal(captured.sender, "Alice-Realm", "ACK must be addressed to the incoming sender")
  end)

  -- ================================================================
  -- BuildTimerAfter: error path routes to geterrorhandler
  -- ================================================================

  test("ControllerWiring BuildTimerAfter routes callback errors to geterrorhandler", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local module, getCaptured = CaptureEventModule()
    local handlerCalls = {}
    local scheduled = {}
    WithGlobals({
      C_Timer = {
        After = function(_seconds, callback)
          scheduled[#scheduled + 1] = callback
        end,
      },
      geterrorhandler = function()
        return function(err)
          handlerCalls[#handlerCalls + 1] = err
        end
      end,
    }, function()
      addon.ControllerWiring.CreateEventHandlersController(module, BuildMinimalEventDeps())
      local config = getCaptured()
      config.timerAfter(0.1, function()
        error("timer-callback-bang", 0)
      end)
      Assert.Equal(#scheduled, 1, "timerAfter must schedule exactly one callback via C_Timer.After")
      scheduled[1]()
    end)
    Assert.Equal(#handlerCalls, 1, "exactly one error-handler call must be produced")
    Assert.True(
      type(handlerCalls[1]) == "string" and handlerCalls[1]:find("timer-callback-bang", 1, true) ~= nil,
      "error message must flow through to geterrorhandler"
    )
  end)

  test("ControllerWiring BuildTimerAfter is a no-op when C_Timer is absent", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local module, getCaptured = CaptureEventModule()
    WithGlobals({ C_Timer = false }, function()
      addon.ControllerWiring.CreateEventHandlersController(module, BuildMinimalEventDeps())
      local config = getCaptured()
      -- Must not raise even though C_Timer is absent.
      config.timerAfter(0.1, function() end)
    end)
  end)

  -- ================================================================
  -- CreateEventHandlersControllerFromContext: context mapping
  -- ================================================================

  test("ControllerWiring CreateEventHandlersControllerFromContext builds deps from ctx", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local module, getCaptured = CaptureEventModule()
    local fakeCtx = {
      addonName = "isiLive",
      isRosterCollapsed = Noop,
      defaultLocale = "enUS",
      locales = { enUS = {} },
      resolveLocaleTag = Noop,
      setLocaleTable = Noop,
      isInGroup = Noop,
      isInChallengeMode = Noop,
      isRaidGroup = Noop,
      isNegativeApplicationStatusEvent = Noop,
      getNormalizedActiveEntryInfo = Noop,
      sendIsiLiveHello = Noop,
      sendOwnKeySnapshot = Noop,
      sendOwnBackgroundSnapshot = Noop,
      sendRefreshResponse = Noop,
      ensureQueueDebugStorage = Noop,
      setQueueDebugEnabled = Noop,
      registerIsiLiveSyncPrefix = Noop,
      applyHotkeyBindings = Noop,
      startBindingWatchdog = Noop,
      getUnitNameAndRealm = Noop,
      markIsiLiveUser = Noop,
      applyKnownKeyToRosterEntry = Noop,
      isTestMode = Noop,
      isTestAllMode = Noop,
      setPendingQueueJoinInfo = Noop,
      setPendingPostChallengeRefresh = Noop,
      getActiveJoinedKeyMapID = Noop,
      setActiveJoinedKeyMapID = Noop,
      getPendingBindingApply = Noop,
      getRoster = function()
        return {}
      end,
      mainFrame = {
        IsShown = function()
          return true
        end,
      },
      mainUI = {
        GetPendingHeight = Noop,
        GetPendingWidth = Noop,
        GetPendingVisible = Noop,
      },
      applySecureSpellToButton = Noop,
      groupController = { HandleGroupRosterUpdate = Noop },
      exitTestMode = Noop,
      clearLatestQueueTarget = Noop,
      updateMPlusTeleportButton = Noop,
      captureQueueJoinCandidate = Noop,
      updateUI = Noop,
      refreshReadyCheckUI = Noop,
      setMainFrameVisible = Noop,
      updateLeaderButtons = Noop,
      updateStatusLine = Noop,
      applyLocalizationToUI = Noop,
      restoreLayoutState = Noop,
      updateCountdownCancelButton = Noop,
      checkIfEnteredTargetDungeon = Noop,
      setMainFrameHeightSafe = Noop,
      setMainFrameWidthSafe = Noop,
      sync = {
        ProcessAddonMessage = Noop,
        GetPrefix = function()
          return "ISILIVE"
        end,
        IsUserKnown = function()
          return false
        end,
      },
      runFullRefresh = Noop,
      getAddonVersionRaw = function()
        return "0.9.180"
      end,
    }
    local ctrl = addon.ControllerWiring.CreateEventHandlersControllerFromContext(module, fakeCtx)
    Assert.NotNil(ctrl, "controller must be returned from context-based wiring")
    local config = getCaptured()
    Assert.NotNil(config, "module config must be captured")
    Assert.Equal(config.addonName, "isiLive", "addonName must propagate via the context mapping")
  end)
end
