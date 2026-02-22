return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules
  local Fixtures = ctx.fixtures

  test("Event handlers keep target when active listing is inferred", function()
    local entryRef = { value = { activityID = 1001 } }
    local counters = { clears = 0, updates = 0 }

    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, entryRef, counters)

      controller:Dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined")
      Assert.Equal(counters.clears, 0, "target must stay for inferred active listing")

      entryRef.value = {}
      controller:Dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined")
      Assert.Equal(counters.clears, 0, "target must stay while grouped even when listing info is empty")

      entryRef.value = {}
      local pendingQueueJoinInfo = {
        groupName = "Race Group",
        priority = 2,
        capturedAt = 100,
      }
      local pendingClears = 0
      controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, entryRef, counters, {
        isInGroup = function()
          return false
        end,
        getTime = function()
          return 105
        end,
        getPendingQueueJoinInfo = function()
          return pendingQueueJoinInfo
        end,
        setPendingQueueJoinInfo = function(value)
          counters.pendingSets = counters.pendingSets + 1
          pendingQueueJoinInfo = value
          if value == nil then
            pendingClears = pendingClears + 1
          end
        end,
      })
      controller:Dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined")
      Assert.Equal(counters.clears, 1, "target must clear outside group when listing info is empty")
      Assert.NotNil(
        pendingQueueJoinInfo,
        "recent pending queue invite context must survive negative status race before group join"
      )
      Assert.Equal(pendingClears, 0, "recent pending queue invite context must not be cleared on negative status")

      entryRef.value = { active = false }
      pendingQueueJoinInfo = {
        groupName = "Stale Group",
        priority = 2,
        capturedAt = 70,
      }
      controller:Dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined")
      Assert.Equal(counters.clears, 2, "target must clear outside group for explicit inactive listing")
      Assert.Nil(pendingQueueJoinInfo, "stale pending queue invite context should clear on negative status update")
      Assert.Equal(pendingClears, 1, "stale pending queue invite context should be cleared exactly once")
    end)
  end)

  test("Event handlers keep target on negative updates when group fills to five", function()
    local counters = { clears = 0, updates = 0 }

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = {} }, counters, {
      isInGroup = function()
        return true
      end,
    })

    controller:Dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined")

    Assert.Equal(counters.clears, 0, "negative updates after join must not clear latest target while grouped")
    Assert.Equal(counters.updates, 1, "teleport button should still refresh on negative update")
  end)

  test("Event handlers forward positive application events to queue capture", function()
    local counters = { clears = 0, updates = 0, captures = 0 }

    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
        isNegativeApplicationStatusEvent = function()
          return false
        end,
      })

      controller:Dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 7, "invited")
    end)

    Assert.Equal(counters.captures, 1, "positive application events must call queue capture")
    Assert.Equal(counters.clears, 0, "positive application events must not clear latest queue target")
  end)

  test("Event handlers active-entry update clears joined key and refreshes UI", function()
    local counters = { updates = 0, uiUpdates = 0, pendingSets = 0 }
    local activeJoinedKey = 2441

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(
      addon.EventHandlers,
      { value = { activityID = 1001 } },
      counters,
      {
        getActiveJoinedKeyMapID = function()
          return activeJoinedKey
        end,
        setActiveJoinedKeyMapID = function(value)
          activeJoinedKey = value
        end,
      }
    )

    controller:Dispatch("LFG_LIST_ACTIVE_ENTRY_UPDATE")

    Assert.Nil(activeJoinedKey, "active joined key map must be cleared when listing becomes active")
    Assert.Equal(counters.pendingSets, 1, "pending queue info must be cleared on active listing event")
    Assert.Equal(counters.updates, 1, "teleport button must refresh on active listing event")
    Assert.Equal(counters.uiUpdates, 1, "UI must refresh when active joined key was cleared")
  end)

  test("Event handlers exit test mode on GROUP_ROSTER_UPDATE while grouped", function()
    local counters = { exits = 0, rosterUpdates = 0 }

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      isTestMode = function()
        return true
      end,
    })

    controller:Dispatch("GROUP_ROSTER_UPDATE")

    Assert.Equal(counters.exits, 1, "GROUP_ROSTER_UPDATE should exit test mode when grouped")
    Assert.Equal(counters.rosterUpdates, 0, "GROUP_ROSTER_UPDATE should short-circuit after test-mode exit")
  end)

  test("Event handlers call roster update when no test mode is active", function()
    local counters = { exits = 0, rosterUpdates = 0 }

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters)

    controller:Dispatch("GROUP_ROSTER_UPDATE")

    Assert.Equal(counters.exits, 0, "normal GROUP_ROSTER_UPDATE should not exit test mode")
    Assert.Equal(counters.rosterUpdates, 1, "normal GROUP_ROSTER_UPDATE must call roster handler")
  end)

  test("Event handlers process addon sync messages and refresh changed roster", function()
    local counters = { acks = 0, uiUpdates = 0 }
    local roster = {
      { name = "Alpha", realm = "RealmA", hasIsiLive = false },
      { name = "Beta", realm = "RealmB", hasIsiLive = true },
    }

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      processAddonMessage = function(_prefix, _message, _sender)
        return { shouldAck = true, sender = "Alpha-RealmA" }
      end,
      forEachRosterInfo = function(visitor)
        for _, info in ipairs(roster) do
          visitor(info)
        end
      end,
      isSyncUserKnown = function(name, _realm)
        return name == "Alpha"
      end,
      applyKnownKeyToRosterEntry = function(info)
        return info.name == "Beta"
      end,
    })

    controller:Dispatch("CHAT_MSG_ADDON", "ISI_SYNC", "hello", "PARTY", "Alpha-RealmA")

    Assert.Equal(counters.acks, 1, "sync payload requiring ack must send ack once")
    Assert.Equal(counters.uiUpdates, 1, "roster changes from sync must refresh UI")
    Assert.True(roster[1].hasIsiLive, "known sync user should be marked as isiLive-enabled")
  end)

  test("Event handlers keep advanced combat logging hard-enabled across startup events", function()
    local setCalls = 0
    local cvarValue = "0"

    WithGlobals({
      C_CVar = {
        GetCVar = function(name)
          if name == "advancedCombatLogging" then
            return cvarValue
          end
          return nil
        end,
        SetCVar = function(name, value)
          if name == "advancedCombatLogging" then
            cvarValue = tostring(value)
            setCalls = setCalls + 1
          end
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {})

      controller:Dispatch("ADDON_LOADED", "isiLive")
      controller:Dispatch("PLAYER_LOGIN")
      controller:Dispatch("PLAYER_ENTERING_WORLD")
    end)

    Assert.Equal(setCalls, 1, "advanced combat logging should be enabled once and remain enforced")
    Assert.Equal(cvarValue, "1", "advanced combat logging cvar should be hard-enabled")
  end)

  test("Event handlers reset damage meter on challenge start when available", function()
    local resetCalls = 0
    local setCalls = 0

    WithGlobals({
      C_DamageMeter = {
        IsDamageMeterAvailable = function()
          return true
        end,
        ResetAllCombatSessions = function()
          resetCalls = resetCalls + 1
        end,
      },
      C_CVar = {
        GetCVar = function(_name)
          return "0"
        end,
        SetCVar = function(name, value)
          if name == "advancedCombatLogging" and tostring(value) == "1" then
            setCalls = setCalls + 1
          end
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {})

      controller:Dispatch("CHALLENGE_MODE_START")
    end)

    Assert.Equal(resetCalls, 1, "challenge start must hard-reset Blizzard damage meter when API is available")
    Assert.Equal(setCalls, 1, "challenge start should enforce advanced combat logging")
  end)

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

    delayedCallback()

    Assert.Equal(refreshCalls, 1, "delayed callback must run one refresh attempt")
    Assert.Equal(enableCalls, 1, "delta display must enable after delayed refresh")
  end)

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
end
