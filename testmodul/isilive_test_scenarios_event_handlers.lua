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
      controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, entryRef, counters, {
        isInGroup = function()
          return false
        end,
      })
      controller:Dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined")
      Assert.Equal(counters.clears, 1, "target must clear outside group when listing info is empty")

      entryRef.value = { active = false }
      controller:Dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined")
      Assert.Equal(counters.clears, 2, "target must clear outside group for explicit inactive listing")
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
end
