local function RegisterTargetHandlingTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
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
end

local function RegisterTargetActiveEntryTests(test, Assert, LoadAddonModules, Fixtures)
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
end

local function RegisterGroupAndSyncTests(test, Assert, LoadAddonModules, Fixtures)
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
    local counters = { acks = 0, uiUpdates = 0, updates = 0 }
    local statusUpdates = 0
    local kickReplies = 0
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
      updateStatusLine = function()
        statusUpdates = statusUpdates + 1
      end,
      sendOwnKickState = function()
        kickReplies = kickReplies + 1
      end,
    })

    controller:Dispatch("CHAT_MSG_ADDON", "ISI_SYNC", "hello", "PARTY", "Alpha-RealmA")

    Assert.Equal(counters.acks, 1, "sync payload requiring ack must send ack once")
    Assert.Equal(counters.uiUpdates, 1, "roster changes from sync must refresh UI")
    Assert.Equal(counters.updates, 1, "sync-driven target changes must refresh teleport highlight state")
    Assert.Equal(statusUpdates, 1, "sync-driven target changes must refresh statusline state")
    Assert.Equal(kickReplies, 1, "HELLO ack handling must send one kick-state reply")
    Assert.True(roster[1].hasIsiLive, "known sync user should be marked as isiLive-enabled")
  end)

  test("Event handlers refresh target-dependent UI when addon sync updates exact target only", function()
    local counters = { uiUpdates = 0, updates = 0 }
    local statusUpdates = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      processAddonMessage = function(_prefix, _message, _sender)
        return { targetUpdated = true }
      end,
      forEachRosterInfo = function(_visitor) end,
      updateStatusLine = function()
        statusUpdates = statusUpdates + 1
      end,
    })

    controller:Dispatch("CHAT_MSG_ADDON", "ISI_SYNC", "TARGET:2441:14", "PARTY", "Alpha-RealmA")

    Assert.Equal(
      counters.uiUpdates,
      1,
      "exact target sync must trigger one UI refresh even without roster field changes"
    )
    Assert.Equal(counters.updates, 1, "exact target sync must refresh teleport highlight state")
    Assert.Equal(statusUpdates, 1, "exact target sync must refresh statusline state")
  end)
end

local function RegisterCombatStartupCVarAndWorldEntryTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  test("Event handlers do not force Blizzard cvars during startup events", function()
    local cvarValues = {
      advancedCombatLogging = "0",
      damageMeterResetOnNewInstance = "0",
    }
    local setCalls = {
      advancedCombatLogging = 0,
      damageMeterResetOnNewInstance = 0,
    }

    WithGlobals({
      C_CVar = {
        GetCVar = function(name)
          return cvarValues[name]
        end,
        SetCVar = function(name, value)
          if cvarValues[name] ~= nil then
            cvarValues[name] = tostring(value)
            setCalls[name] = setCalls[name] + 1
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

    Assert.Equal(setCalls.advancedCombatLogging, 0, "startup should not force advanced combat logging")
    Assert.Equal(
      setCalls.damageMeterResetOnNewInstance,
      0,
      "startup should not force damage meter reset-on-new-instance"
    )
    Assert.Equal(
      cvarValues.advancedCombatLogging,
      "0",
      "advanced combat logging cvar should remain unchanged on startup"
    )
    Assert.Equal(
      cvarValues.damageMeterResetOnNewInstance,
      "0",
      "damage meter reset-on-new-instance cvar should remain unchanged on startup"
    )
  end)

  test("Event handlers send one forced key snapshot on PLAYER_ENTERING_WORLD", function()
    local keySnapshotForceCalls = {}
    local scheduled = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      timerAfter = function(seconds, callback)
        table.insert(scheduled, { seconds = seconds, callback = callback })
      end,
      sendOwnKeySnapshot = function(force)
        table.insert(keySnapshotForceCalls, force == true)
      end,
    })

    controller:Dispatch("PLAYER_ENTERING_WORLD")

    Assert.Equal(#keySnapshotForceCalls, 1, "entering world should send one immediate key snapshot")
    Assert.True(keySnapshotForceCalls[1], "immediate entering-world key snapshot must stay forced")
    Assert.Equal(#scheduled, 2, "entering world should only schedule hotkey reapply callbacks")
  end)

  test("Event handlers auto-show main frame on PLAYER_LOGIN for startup login and reload", function()
    local showCalls = 0
    local lastVisible = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      setMainFrameVisible = function(visible)
        showCalls = showCalls + 1
        lastVisible = visible
      end,
    })

    controller:Dispatch("PLAYER_LOGIN")

    Assert.Equal(showCalls, 1, "PLAYER_LOGIN must request one startup auto-open")
    Assert.True(lastVisible == true, "PLAYER_LOGIN startup auto-open must show the main frame")
  end)

  test("Event handlers skip PLAYER_LOGIN auto-show when startup setting is disabled", function()
    local showCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      shouldShowMainFrameOnStartup = function()
        return false
      end,
      setMainFrameVisible = function(_visible)
        showCalls = showCalls + 1
      end,
    })

    controller:Dispatch("PLAYER_LOGIN")

    Assert.Equal(showCalls, 0, "disabled startup auto-show must not request a frame open on PLAYER_LOGIN")
  end)

  test("Event handlers call updateCdTracker on UNIT_AURA for player", function()
    local cdTrackerCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      updateCdTracker = function()
        cdTrackerCalls = cdTrackerCalls + 1
      end,
    })

    controller:Dispatch("UNIT_AURA", "player", { isFullUpdate = true })
    controller:Dispatch("UNIT_AURA", "player", {})
    controller:Dispatch("UNIT_AURA", "player", nil)

    Assert.Equal(cdTrackerCalls, 3, "all player UNIT_AURA variants must call updateCdTracker")
  end)

  test("Event handlers ignore UNIT_AURA events for non-player units", function()
    local cdTrackerCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      updateCdTracker = function()
        cdTrackerCalls = cdTrackerCalls + 1
      end,
    })

    controller:Dispatch("UNIT_AURA", "party1", { isFullUpdate = true })
    controller:Dispatch("UNIT_AURA", "target", {})
    controller:Dispatch("UNIT_AURA", "focus", nil)

    Assert.Equal(cdTrackerCalls, 0, "UNIT_AURA for non-player units must not reach the cd tracker")
  end)

  test("Event handlers trigger portal navigator checks on world and zone changes", function()
    local portalCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      maybeShowPortalNavigatorNotice = function()
        portalCalls = portalCalls + 1
      end,
    })

    controller:Dispatch("PLAYER_ENTERING_WORLD")
    controller:Dispatch("ZONE_CHANGED")
    controller:Dispatch("ZONE_CHANGED_INDOORS")
    controller:Dispatch("ZONE_CHANGED_NEW_AREA")
    controller:Dispatch("UPDATE_INSTANCE_INFO")

    Assert.Equal(portalCalls, 5, "portal navigator checks should run on world-entry and all zone-change events")
  end)

  test("Event handlers auto-show main frame on dungeon entry after outdoor state", function()
    local showCalls = 0
    local lastVisible = nil
    local inPartyInstance = false

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      isInPartyInstance = function()
        return inPartyInstance
      end,
      setMainFrameVisible = function(visible)
        showCalls = showCalls + 1
        lastVisible = visible
      end,
    })

    controller:Dispatch("PLAYER_ENTERING_WORLD")
    Assert.Equal(showCalls, 0, "first outdoor state sample must not auto-open")

    inPartyInstance = true
    controller:Dispatch("PLAYER_ENTERING_WORLD")
    Assert.Equal(showCalls, 1, "fresh dungeon entry must auto-open main frame")
    Assert.Equal(lastVisible, true, "dungeon entry auto-open must show main frame")

    controller:Dispatch("PLAYER_ENTERING_WORLD")
    Assert.Equal(showCalls, 1, "repeated in-dungeon entering-world events must not re-open again")
  end)
end

local function RegisterCombatStartupM0LifecycleTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  test("Event handlers record M0 run when leaving tracked mythic non-challenge dungeon", function()
    local current = {
      instanceType = "party",
      difficultyID = 23,
      mapID = 2662,
    }
    local recordedRuns = {}
    local roster = {
      player = { name = "Me", realm = "MyRealm" },
      party1 = { name = "Buddy", realm = "Realm" },
      party2 = { name = "Other", realm = "Else" },
    }

    WithGlobals({
      GetInstanceInfo = function()
        return "The Dawnbreaker", current.instanceType, current.difficultyID, "Mythic"
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return current.mapID
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
        getRoster = function()
          return roster
        end,
        recordRun = function(mapID, level, onTime, rosterSnapshot)
          table.insert(recordedRuns, {
            mapID = mapID,
            level = level,
            onTime = onTime,
            rosterSnapshot = rosterSnapshot,
          })
        end,
      })

      controller:Dispatch("PLAYER_ENTERING_WORLD")
      Assert.Equal(#recordedRuns, 0, "entering tracked M0 dungeon must not record a run yet")

      current.instanceType = "none"
      current.difficultyID = 0
      current.mapID = nil
      roster = {}

      controller:Dispatch("PLAYER_ENTERING_WORLD")
    end)

    Assert.Equal(#recordedRuns, 1, "leaving tracked M0 dungeon should record exactly one run snapshot")
    Assert.Equal(recordedRuns[1].mapID, 2662, "recorded M0 run should keep the last tracked dungeon map id")
    Assert.Equal(recordedRuns[1].level, 0, "M0 snapshots should use level 0")
    Assert.Nil(recordedRuns[1].onTime, "M0 snapshots have no timed-run flag")
    Assert.NotNil(recordedRuns[1].rosterSnapshot.party1, "M0 exit should still use the frozen entry roster snapshot")
    Assert.Equal(
      recordedRuns[1].rosterSnapshot.party1.name,
      "Buddy",
      "frozen M0 roster snapshot should preserve party members after group dissolution"
    )
  end)

  test("Event handlers record run when leaving non-challenge normal dungeon", function()
    local current = {
      instanceType = "party",
      difficultyID = 1,
      mapID = 2649,
    }
    local recordedRuns = {}
    local roster = {
      player = { name = "Me", realm = "MyRealm" },
      party1 = { name = "Buddy", realm = "Realm" },
    }

    WithGlobals({
      GetInstanceInfo = function()
        return "Priory of the Sacred Flame", current.instanceType, current.difficultyID, "Normal"
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return current.mapID
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
        getRoster = function()
          return roster
        end,
        recordRun = function(mapID, level, onTime)
          table.insert(recordedRuns, {
            mapID = mapID,
            level = level,
            onTime = onTime,
          })
        end,
      })

      controller:Dispatch("PLAYER_ENTERING_WORLD")

      current.instanceType = "none"
      current.difficultyID = 0
      current.mapID = nil
      roster = {}

      controller:Dispatch("PLAYER_ENTERING_WORLD")
    end)

    Assert.Equal(#recordedRuns, 1, "normal dungeon exits should record one non-challenge run snapshot")
    Assert.Equal(recordedRuns[1].mapID, 2649, "normal dungeon exit should keep the recorded dungeon map id")
    Assert.Equal(recordedRuns[1].level, 0, "normal dungeon snapshots should keep non-key level 0")
    Assert.Nil(recordedRuns[1].onTime, "normal dungeon snapshots have no timed-run flag")
  end)
end

local function RegisterCombatStartupM0EdgeCaseTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  test("Event handlers do not record M0 run on tracked mythic subzone map changes", function()
    local current = {
      instanceType = "party",
      difficultyID = 23,
      mapID = 2662,
    }
    local recordedRuns = {}
    local roster = {
      player = { name = "Me", realm = "MyRealm" },
      party1 = { name = "Buddy", realm = "Realm" },
    }

    WithGlobals({
      GetInstanceInfo = function()
        return "Tracked Dungeon", current.instanceType, current.difficultyID, "Mythic"
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return current.mapID
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
        getRoster = function()
          return roster
        end,
        recordRun = function(mapID, level, onTime, rosterSnapshot)
          table.insert(recordedRuns, {
            mapID = mapID,
            level = level,
            onTime = onTime,
            rosterSnapshot = rosterSnapshot,
          })
        end,
      })

      controller:Dispatch("PLAYER_ENTERING_WORLD")
      Assert.Equal(#recordedRuns, 0, "initial tracked M0 entry must not record a run")

      current.mapID = 2649
      roster = {
        player = { name = "Me", realm = "MyRealm" },
        party1 = { name = "Replacement", realm = "Realm" },
      }
      controller:Dispatch("ZONE_CHANGED_NEW_AREA")

      Assert.Equal(
        #recordedRuns,
        0,
        "tracked mythic subzone map changes inside the same M0 dungeon must not flush a completed run"
      )

      current.instanceType = "none"
      current.difficultyID = 0
      current.mapID = nil
      roster = {}
      controller:Dispatch("PLAYER_ENTERING_WORLD")
    end)

    Assert.Equal(#recordedRuns, 1, "tracked M0 run should still be recorded exactly once on real instance exit")
    Assert.Equal(recordedRuns[1].mapID, 2662, "recorded run should keep the original tracked dungeon map id")
    Assert.Equal(recordedRuns[1].level, 0, "tracked M0 exit snapshots should still use level 0")
    Assert.Nil(recordedRuns[1].onTime, "tracked M0 exit snapshots have no timed-run flag")
    Assert.Equal(
      recordedRuns[1].rosterSnapshot.party1.name,
      "Buddy",
      "tracked M0 exit must keep the frozen roster from the original dungeon entry despite subzone map changes"
    )
  end)

  test("Event handlers hydrate pending M0 roster snapshot from later group roster update", function()
    local current = {
      instanceType = "party",
      difficultyID = 23,
      mapID = 2662,
    }
    local recordedRuns = {}
    local roster = {
      player = { name = "Me", realm = "MyRealm" },
    }

    WithGlobals({
      GetInstanceInfo = function()
        return "Tracked Dungeon", current.instanceType, current.difficultyID, "Mythic"
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return current.mapID
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
        getRoster = function()
          return roster
        end,
        recordRun = function(mapID, level, onTime, rosterSnapshot)
          table.insert(recordedRuns, {
            mapID = mapID,
            level = level,
            onTime = onTime,
            rosterSnapshot = rosterSnapshot,
          })
        end,
      })

      controller:Dispatch("PLAYER_ENTERING_WORLD")

      roster = {
        player = { name = "Me", realm = "MyRealm" },
        party1 = { name = "LateBuddy", realm = "Realm" },
      }
      controller:Dispatch("GROUP_ROSTER_UPDATE")

      current.instanceType = "none"
      current.difficultyID = 0
      current.mapID = nil
      roster = {}
      controller:Dispatch("PLAYER_ENTERING_WORLD")
    end)

    Assert.Equal(#recordedRuns, 1, "tracked M0 exit should still record exactly one run")
    Assert.NotNil(
      recordedRuns[1].rosterSnapshot.party1,
      "late group roster update should hydrate pending M0 snapshot before exit"
    )
    Assert.Equal(
      recordedRuns[1].rosterSnapshot.party1.name,
      "LateBuddy",
      "hydrated M0 snapshot should use the first full roster update after entry"
    )
  end)

  test("Event handlers retry M0 run capture when damage meter snapshot is delayed", function()
    local current = {
      instanceType = "party",
      difficultyID = 23,
      mapID = 2662,
    }
    local captureAttempts = 0
    local scheduled = {}
    local roster = {
      player = { name = "Me", realm = "MyRealm" },
      party1 = { name = "Buddy", realm = "Realm" },
    }

    WithGlobals({
      GetInstanceInfo = function()
        return "Tracked Dungeon", current.instanceType, current.difficultyID, "Mythic"
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return current.mapID
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
        getRoster = function()
          return roster
        end,
        timerAfter = function(seconds, callback)
          table.insert(scheduled, {
            seconds = seconds,
            callback = callback,
          })
        end,
        recordRun = function(mapID, level, onTime, rosterSnapshot)
          captureAttempts = captureAttempts + 1
          Assert.Equal(mapID, 2662, "M0 retry capture must keep original dungeon map id")
          Assert.Equal(level, 0, "M0 retry capture must stay on level 0")
          Assert.Nil(onTime, "M0 retry capture must keep nil timed flag")
          Assert.NotNil(rosterSnapshot.party1, "M0 retry capture must keep frozen roster snapshot")
          return captureAttempts >= 2
        end,
      })

      controller:Dispatch("PLAYER_ENTERING_WORLD")

      current.instanceType = "none"
      current.difficultyID = 0
      current.mapID = nil
      roster = {}

      controller:Dispatch("PLAYER_ENTERING_WORLD")
    end)

    Assert.Equal(captureAttempts, 1, "M0 exit should attempt immediate run capture once")
    Assert.Equal(#scheduled, 5, "M0 entry/exit should keep the normal binding refresh callbacks plus one capture retry")
    Assert.Equal(scheduled[3].seconds, 1, "run capture retry should use short fixed delay")

    scheduled[3].callback()

    Assert.Equal(captureAttempts, 2, "scheduled M0 retry should attempt run capture again")
  end)
end

local function RegisterCombatStartupM0TrackingTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterCombatStartupM0LifecycleTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterCombatStartupM0EdgeCaseTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
end

local function RegisterCombatStartupStateRestoreTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  test("Event handlers force hidden setting defaults on ADDON_LOADED", function()
    local db = {
      locale = "enUS",
      showDpsColumn = false,
      markersLeaderOnly = false,
      position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    }

    WithGlobals({
      IsiLiveDB = db,
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {})
      controller:Dispatch("ADDON_LOADED", "isiLive")
    end)

    Assert.True(db.showDpsColumn == true, "ADDON_LOADED must force the hidden DPS-column setting on")
    Assert.False(db.markersLeaderOnly == true, "ADDON_LOADED must force the hidden marker setting off")
  end)

  test("Event handlers reset runtime log storage and enabled flag on ADDON_LOADED", function()
    local ensureRuntimeLogStorageCalls = 0
    local setRuntimeLogEnabledValue = nil

    WithGlobals({
      IsiLiveDB = {
        locale = "enUS",
        queueDebug = false,
        runtimeLogEnabled = true,
        position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
        ensureRuntimeLogStorage = function()
          ensureRuntimeLogStorageCalls = ensureRuntimeLogStorageCalls + 1
        end,
        setRuntimeLogEnabled = function(enabled)
          setRuntimeLogEnabledValue = enabled
        end,
      })

      controller:Dispatch("ADDON_LOADED", "isiLive")
    end)

    Assert.Equal(ensureRuntimeLogStorageCalls, 1, "ADDON_LOADED must ensure runtime log storage exactly once")
    Assert.False(setRuntimeLogEnabledValue == true, "ADDON_LOADED must reset runtime log enabled state to OFF")
  end)

  test("Event handlers restore Rio baseline from DB on ADDON_LOADED", function()
    local restoreCalls = 0

    WithGlobals({
      IsiLiveDB = {
        locale = "enUS",
        queueDebug = false,
        rioBaseline = { ["Alpha-Blackmoore"] = 2400 },
        position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
        restoreRioBaseline = function()
          restoreCalls = restoreCalls + 1
        end,
      })

      controller:Dispatch("ADDON_LOADED", "isiLive")
    end)

    Assert.Equal(restoreCalls, 1, "ADDON_LOADED must restore Rio baseline from DB exactly once")
  end)

  test("Event handlers reset damage meter on challenge start when available", function()
    local resetCalls = 0
    local cvarValues = {
      advancedCombatLogging = "0",
      damageMeterResetOnNewInstance = "0",
    }
    local setCalls = {
      advancedCombatLogging = 0,
      damageMeterResetOnNewInstance = 0,
    }

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
        GetCVar = function(name)
          return cvarValues[name]
        end,
        SetCVar = function(name, value)
          if cvarValues[name] ~= nil and tostring(value) == "1" then
            cvarValues[name] = "1"
            setCalls[name] = setCalls[name] + 1
          end
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {})

      controller:Dispatch("CHALLENGE_MODE_START")
    end)

    Assert.Equal(resetCalls, 1, "challenge start must hard-reset Blizzard damage meter when API is available")
    Assert.Equal(setCalls.advancedCombatLogging, 0, "challenge start should not force advanced combat logging")
    Assert.Equal(
      setCalls.damageMeterResetOnNewInstance,
      0,
      "challenge start should not force damage meter reset-on-new-instance"
    )
    Assert.Equal(
      cvarValues.advancedCombatLogging,
      "0",
      "challenge start should leave advanced combat logging unchanged"
    )
  end)
end

local function RegisterCombatStartupTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterCombatStartupCVarAndWorldEntryTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterCombatStartupM0TrackingTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterCombatStartupStateRestoreTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
end

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
      shouldAutoCloseMainFrame = function()
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

  test("Event handlers pre-render UI for hidden addon sync updates", function()
    local counters = { uiUpdates = 0 }
    local roster = {
      { name = "Alpha", realm = "RealmA", hasIsiLive = false },
    }

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      isMainFrameShown = function()
        return false
      end,
      processAddonMessage = function(_prefix, _message, _sender)
        return { shouldAck = false }
      end,
      forEachRosterInfo = function(visitor)
        for _, info in ipairs(roster) do
          visitor(info)
        end
      end,
      isSyncUserKnown = function(name, _realm)
        return name == "Alpha"
      end,
    })

    controller:Dispatch("CHAT_MSG_ADDON", "ISI_SYNC", "hello", "PARTY", "Alpha-RealmA")

    Assert.True(roster[1].hasIsiLive, "hidden sync handling must still update background roster state")
    Assert.Equal(counters.uiUpdates, 1, "hidden sync handling should pre-render UI state once")
  end)

  test("Event handlers answer refresh requests while frame is hidden", function()
    local counters = { uiUpdates = 0, refreshResponses = 0 }
    local targetSnapshots = 0
    local kickReplies = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      isMainFrameShown = function()
        return false
      end,
      processAddonMessage = function(_prefix, _message, _sender)
        return { shouldAck = false, shouldRequestRefresh = true }
      end,
      sendOwnTargetSnapshot = function(force, source, allowHidden)
        if force and source == "reqsync" and allowHidden == true then
          targetSnapshots = targetSnapshots + 1
        end
      end,
      sendOwnKickState = function()
        kickReplies = kickReplies + 1
      end,
    })

    controller:Dispatch("CHAT_MSG_ADDON", "ISI_SYNC", "REQSYNC", "PARTY", "Alpha-RealmA")

    Assert.Equal(counters.refreshResponses, 1, "hidden refresh requests must trigger one sync response")
    Assert.Equal(targetSnapshots, 1, "hidden refresh requests must also trigger one exact target snapshot")
    Assert.Equal(kickReplies, 1, "hidden refresh requests must also trigger one kick-state snapshot")
    Assert.Equal(counters.uiUpdates, 0, "answering a hidden refresh request must not force a UI redraw by itself")
  end)

  test("Event handlers answer SHAREKEYS requests while frame is hidden", function()
    local counters = { uiUpdates = 0, refreshResponses = 0 }
    local keystoneChatShares = 0
    local cooldownTriggers = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      isMainFrameShown = function()
        return false
      end,
      processAddonMessage = function(_prefix, _message, _sender)
        return { shouldAck = false, shouldShareKeys = true }
      end,
      sendOwnKeystoneToChat = function()
        keystoneChatShares = keystoneChatShares + 1
      end,
      triggerShareKeysCooldown = function()
        cooldownTriggers = cooldownTriggers + 1
      end,
    })

    controller:Dispatch("CHAT_MSG_ADDON", "ISI_SYNC", "SHAREKEYS", "PARTY", "Alpha-RealmA")

    Assert.Equal(keystoneChatShares, 1, "hidden SHAREKEYS must trigger one own-key chat announcement")
    Assert.Equal(cooldownTriggers, 1, "SHAREKEYS must lock the local share-keys button on all clients")
    Assert.Equal(counters.refreshResponses, 0, "SHAREKEYS must not trigger a refresh response")
    Assert.Equal(counters.uiUpdates, 0, "hidden SHAREKEYS must not force a UI redraw by itself")
  end)

  test("Event handlers send sparse background snapshot on hidden zone changes", function()
    local counters = { uiUpdates = 0 }
    local backgroundSources = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      isMainFrameShown = function()
        return false
      end,
      sendOwnBackgroundSnapshot = function(source)
        table.insert(backgroundSources, source)
      end,
    })

    controller:Dispatch("ZONE_CHANGED")

    Assert.Equal(#backgroundSources, 1, "hidden zone changes must trigger one sparse background snapshot")
    Assert.Equal(backgroundSources[1], "zone", "hidden zone changes must use the zone sync source")
  end)

  test("Event handlers send sparse background snapshot only for player-owned state changes", function()
    local counters = { uiUpdates = 0 }
    local backgroundSources = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      sendOwnBackgroundSnapshot = function(source)
        table.insert(backgroundSources, source)
      end,
    })

    controller:Dispatch("PLAYER_SPECIALIZATION_CHANGED", "party1")
    controller:Dispatch("PLAYER_SPECIALIZATION_CHANGED", "player")
    controller:Dispatch("PLAYER_EQUIPMENT_CHANGED", 16, true)

    Assert.Equal(#backgroundSources, 2, "only local player state changes must trigger sparse background sync")
    Assert.Equal(backgroundSources[1], "player-state", "player specialization changes must use player-state sync")
    Assert.Equal(backgroundSources[2], "player-state", "player equipment changes must use player-state sync")
  end)
end

local function RegisterReadyCheckAndStatsTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  test("Event handlers toggle ready check state and refresh UI on ready check events", function()
    local counters = { uiUpdates = 0, readyCheckRefreshes = 0 }
    local readyCheckActive = false
    local now = 100
    local readyUntilByUnit = {}
    local scheduledDelay = nil
    local scheduledCallback = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      setReadyCheckActive = function(value)
        readyCheckActive = value and true or false
      end,
      isReadyCheckActive = function()
        return readyCheckActive
      end,
      getTime = function()
        return now
      end,
      setReadyCheckReadyUntil = function(unit, value)
        readyUntilByUnit[unit] = value
      end,
      clearAllReadyCheckReady = function()
        readyUntilByUnit = {}
      end,
      clearExpiredReadyCheckReady = function(currentTime)
        local changed = false
        for unit, untilTime in pairs(readyUntilByUnit) do
          if untilTime <= currentTime then
            readyUntilByUnit[unit] = nil
            changed = true
          end
        end
        return changed
      end,
      timerAfter = function(delaySeconds, callback)
        scheduledDelay = delaySeconds
        scheduledCallback = callback
      end,
    })

    controller:Dispatch("READY_CHECK")
    Assert.True(readyCheckActive, "READY_CHECK must mark ready check as active")
    Assert.Equal(counters.readyCheckRefreshes, 1, "READY_CHECK should refresh ready-check UI once")
    Assert.Equal(counters.uiUpdates, 0, "READY_CHECK must not call the generic UI rerender path")

    controller:Dispatch("READY_CHECK_CONFIRM", "party1", "ready")
    Assert.Equal(
      counters.readyCheckRefreshes,
      2,
      "READY_CHECK_CONFIRM should refresh the dedicated ready-check UI while active"
    )
    Assert.Equal(counters.uiUpdates, 0, "READY_CHECK_CONFIRM must not call the generic UI rerender path")

    controller:Dispatch("READY_CHECK_FINISHED")
    Assert.False(readyCheckActive, "READY_CHECK_FINISHED must clear ready check state")
    Assert.Equal(counters.readyCheckRefreshes, 3, "READY_CHECK_FINISHED should refresh ready-check UI once")
    Assert.Equal(counters.uiUpdates, 0, "READY_CHECK_FINISHED must not call the generic UI rerender path")
    Assert.Equal(readyUntilByUnit.party1, 120, "READY_CHECK_FINISHED should keep ready unit green for 20 seconds")
    Assert.Equal(scheduledDelay, 20, "READY_CHECK_FINISHED should schedule a 20-second ready hold cleanup")
    Assert.NotNil(scheduledCallback, "READY_CHECK_FINISHED should schedule a ready-hold cleanup callback")

    now = 121
    controller:Dispatch("READY_CHECK_CONFIRM", "party1", "ready")
    Assert.Equal(
      counters.readyCheckRefreshes,
      4,
      "READY_CHECK_CONFIRM should still refresh ready-check UI after ready check finished"
    )
    Assert.Equal(counters.uiUpdates, 0, "READY_CHECK_CONFIRM after finish must keep the generic UI rerender path idle")
    Assert.Equal(readyUntilByUnit.party1, 141, "late ready confirm should refresh its 20-second hold")
    Assert.Equal(scheduledDelay, 20, "late ready confirm should schedule a 20-second cleanup")
    Assert.NotNil(scheduledCallback, "late ready confirm should schedule a cleanup callback")

    now = 141
    local cleanupCallback = scheduledCallback
    if cleanupCallback == nil then
      error("late ready confirm should schedule a cleanup callback")
    end
    cleanupCallback()

    Assert.Nil(readyUntilByUnit.party1, "late ready confirm hold should clear after the timer expires")
    Assert.Equal(counters.readyCheckRefreshes, 5, "ready-hold expiry should trigger one more ready-check refresh")
    Assert.Equal(counters.uiUpdates, 0, "ready-hold expiry must not call the generic UI rerender path")
  end)

  test("Event handlers route ready check lifecycle through refreshReadyCheckUI without generic rerender", function()
    local counters = { uiUpdates = 0, readyCheckRefreshes = 0 }
    local readyCheckActive = false
    local now = 100
    local declinedUntilByUnit = {}
    local scheduledDelay = nil
    local scheduledCallback = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      setReadyCheckActive = function(value)
        readyCheckActive = value and true or false
      end,
      isReadyCheckActive = function()
        return readyCheckActive
      end,
      getTime = function()
        return now
      end,
      setReadyCheckDeclinedUntil = function(unit, value)
        declinedUntilByUnit[unit] = value
      end,
      clearAllReadyCheckDeclined = function()
        declinedUntilByUnit = {}
      end,
      clearExpiredReadyCheckDeclined = function(currentTime)
        local changed = false
        for unit, untilTime in pairs(declinedUntilByUnit) do
          if untilTime <= currentTime then
            declinedUntilByUnit[unit] = nil
            changed = true
          end
        end
        return changed
      end,
      timerAfter = function(delaySeconds, callback)
        scheduledDelay = delaySeconds
        scheduledCallback = callback
      end,
      refreshReadyCheckUI = function()
        counters.readyCheckRefreshes = counters.readyCheckRefreshes + 1
      end,
    })

    controller:Dispatch("READY_CHECK")
    Assert.True(readyCheckActive, "READY_CHECK must mark ready check as active before the ready-check refresh runs")
    Assert.Equal(counters.readyCheckRefreshes, 1, "READY_CHECK must call refreshReadyCheckUI exactly once")
    Assert.Equal(counters.uiUpdates, 0, "READY_CHECK must not call updateUI")

    controller:Dispatch("READY_CHECK_CONFIRM", "party1", "notready")
    Assert.Equal(counters.readyCheckRefreshes, 2, "READY_CHECK_CONFIRM must call refreshReadyCheckUI while active")
    Assert.Equal(counters.uiUpdates, 0, "READY_CHECK_CONFIRM must not call updateUI")

    controller:Dispatch("READY_CHECK_FINISHED")
    Assert.False(readyCheckActive, "READY_CHECK_FINISHED must clear ready check state before the refresh runs")
    Assert.Equal(counters.readyCheckRefreshes, 3, "READY_CHECK_FINISHED must call refreshReadyCheckUI once")
    Assert.Equal(counters.uiUpdates, 0, "READY_CHECK_FINISHED must not call updateUI")
    Assert.Equal(declinedUntilByUnit.party1, 120, "declined ready-check unit should stay marked for 20 seconds")
    Assert.Equal(scheduledDelay, 20, "declined ready-check hold should schedule one 20-second cleanup refresh")
    Assert.NotNil(scheduledCallback, "declined ready-check hold must schedule a cleanup callback")

    now = 121
    controller:Dispatch("READY_CHECK_CONFIRM", "party1", "notready")
    Assert.Equal(
      counters.readyCheckRefreshes,
      4,
      "late READY_CHECK_CONFIRM notready should still call refreshReadyCheckUI after finish"
    )
    Assert.Equal(counters.uiUpdates, 0, "late READY_CHECK_CONFIRM notready must not call updateUI")
    Assert.Equal(declinedUntilByUnit.party1, 141, "late declined ready-check unit should refresh its 20-second hold")
    Assert.Equal(scheduledDelay, 20, "late declined ready-check hold should schedule one 20-second cleanup refresh")
    Assert.NotNil(scheduledCallback, "late declined ready-check hold must schedule a cleanup callback")

    now = 141
    local cleanupCallback = scheduledCallback
    if cleanupCallback == nil then
      error("late declined ready-check hold must schedule a cleanup callback")
    end
    cleanupCallback()

    Assert.Nil(declinedUntilByUnit.party1, "late declined ready-check hold should clear after the timer expires")
    Assert.Equal(counters.readyCheckRefreshes, 5, "timer expiry should trigger one more dedicated ready-check refresh")
    Assert.Equal(counters.uiUpdates, 0, "timer expiry must not call updateUI")
  end)

  test("Event handlers keep declined ready-check rows red for 20 seconds after finish", function()
    local counters = { uiUpdates = 0, readyCheckRefreshes = 0 }
    local readyCheckActive = false
    local now = 100
    local declinedUntilByUnit = {}
    local scheduledDelay = nil
    local scheduledCallback = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      setReadyCheckActive = function(value)
        readyCheckActive = value and true or false
      end,
      isReadyCheckActive = function()
        return readyCheckActive
      end,
      getTime = function()
        return now
      end,
      setReadyCheckDeclinedUntil = function(unit, value)
        declinedUntilByUnit[unit] = value
      end,
      clearAllReadyCheckDeclined = function()
        declinedUntilByUnit = {}
      end,
      clearExpiredReadyCheckDeclined = function(currentTime)
        local changed = false
        for unit, untilTime in pairs(declinedUntilByUnit) do
          if untilTime <= currentTime then
            declinedUntilByUnit[unit] = nil
            changed = true
          end
        end
        return changed
      end,
      timerAfter = function(delaySeconds, callback)
        scheduledDelay = delaySeconds
        scheduledCallback = callback
      end,
    })

    controller:Dispatch("READY_CHECK")
    controller:Dispatch("READY_CHECK_CONFIRM", "party1", "notready")
    controller:Dispatch("READY_CHECK_CONFIRM", "party2", "ready")
    controller:Dispatch("READY_CHECK_FINISHED")

    Assert.False(readyCheckActive, "READY_CHECK_FINISHED must clear ready check state")
    Assert.Equal(declinedUntilByUnit.party1, 120, "declined ready-check unit should stay marked for 20 seconds")
    Assert.Nil(declinedUntilByUnit.party2, "ready unit must not receive a declined hold")
    Assert.Equal(scheduledDelay, 20, "declined ready-check hold should schedule one 20-second cleanup refresh")
    Assert.NotNil(scheduledCallback, "declined ready-check hold must schedule a cleanup callback")
    Assert.Equal(counters.readyCheckRefreshes, 4, "finish path should still refresh the dedicated ready-check UI")
    Assert.Equal(counters.uiUpdates, 0, "declined ready-check hold must not use generic updateUI")

    now = 120
    local cleanupCallback = scheduledCallback
    if cleanupCallback == nil then
      error("declined ready-check hold must schedule a cleanup callback")
    end
    cleanupCallback()

    Assert.Nil(declinedUntilByUnit.party1, "declined ready-check hold should clear after the timer expires")
    Assert.Equal(counters.readyCheckRefreshes, 5, "timer expiry should trigger one more dedicated ready-check refresh")
    Assert.Equal(counters.uiUpdates, 0, "timer expiry must not use generic updateUI")
  end)

  test("Event handlers keep ready-check rows green for 20 seconds after finish", function()
    local counters = { uiUpdates = 0, readyCheckRefreshes = 0 }
    local readyCheckActive = false
    local now = 100
    local readyUntilByUnit = {}
    local scheduledDelay = nil
    local scheduledCallback = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      setReadyCheckActive = function(value)
        readyCheckActive = value and true or false
      end,
      isReadyCheckActive = function()
        return readyCheckActive
      end,
      getTime = function()
        return now
      end,
      setReadyCheckReadyUntil = function(unit, value)
        readyUntilByUnit[unit] = value
      end,
      clearAllReadyCheckReady = function()
        readyUntilByUnit = {}
      end,
      clearExpiredReadyCheckReady = function(currentTime)
        local changed = false
        for unit, untilTime in pairs(readyUntilByUnit) do
          if untilTime <= currentTime then
            readyUntilByUnit[unit] = nil
            changed = true
          end
        end
        return changed
      end,
      timerAfter = function(delaySeconds, callback)
        scheduledDelay = delaySeconds
        scheduledCallback = callback
      end,
    })

    controller:Dispatch("READY_CHECK")
    controller:Dispatch("READY_CHECK_CONFIRM", "party2", "ready")
    controller:Dispatch("READY_CHECK_FINISHED")

    Assert.False(readyCheckActive, "READY_CHECK_FINISHED must clear ready check state")
    Assert.Equal(readyUntilByUnit.party2, 120, "ready ready-check unit should stay marked for 20 seconds")
    Assert.Equal(scheduledDelay, 20, "ready ready-check hold should schedule one 20-second cleanup refresh")
    Assert.NotNil(scheduledCallback, "ready ready-check hold must schedule a cleanup callback")
    Assert.Equal(counters.readyCheckRefreshes, 3, "finish path should still refresh the dedicated ready-check UI")
    Assert.Equal(counters.uiUpdates, 0, "ready ready-check hold must not use generic updateUI")

    now = 120
    local cleanupCallback = scheduledCallback
    if cleanupCallback == nil then
      error("ready ready-check hold must schedule a cleanup callback")
    end
    cleanupCallback()

    Assert.Nil(readyUntilByUnit.party2, "ready ready-check hold should clear after the timer expires")
    Assert.Equal(counters.readyCheckRefreshes, 4, "timer expiry should trigger one more dedicated ready-check refresh")
    Assert.Equal(counters.uiUpdates, 0, "timer expiry must not use generic updateUI")
  end)

  test("Event handlers record completed run only once across completion and reset events", function()
    local recordedRuns = {}

    WithGlobals({
      C_ChallengeMode = {
        GetCompletionInfo = function()
          return 2662, 10, 123456, true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
        recordRun = function(mapID, level, onTime)
          table.insert(recordedRuns, {
            mapID = mapID,
            level = level,
            onTime = onTime,
          })
        end,
      })

      controller:Dispatch("CHALLENGE_MODE_COMPLETED")
      controller:Dispatch("CHALLENGE_MODE_RESET")
      Assert.Equal(#recordedRuns, 1, "completion/reset pair must record the run only once")

      controller:Dispatch("CHALLENGE_MODE_START")
      controller:Dispatch("CHALLENGE_MODE_COMPLETED")
      Assert.Equal(#recordedRuns, 2, "new run after challenge start should be recordable again")
    end)
  end)
end

local function RegisterChallengeRaidResumeTests(test, Assert, LoadAddonModules, Fixtures)
  test("Event handlers defer post-run refresh while raid mode is active and resume after raid exit", function()
    local delayedCallback = nil
    local raidActive = false
    local refreshCalls = 0
    local enableCalls = 0
    local rosterUpdates = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      timerAfter = function(seconds, callback)
        if seconds == 5 then
          delayedCallback = callback
        end
      end,
      isRaidGroup = function()
        return raidActive
      end,
      handleGroupRosterUpdate = function()
        rosterUpdates = rosterUpdates + 1
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

    Assert.NotNil(delayedCallback, "challenge completion must still schedule a delayed post-run refresh")
    if type(delayedCallback) ~= "function" then
      return
    end

    raidActive = true
    delayedCallback()

    Assert.Equal(refreshCalls, 0, "delayed post-run refresh must not run while raid mode is active")
    Assert.Equal(enableCalls, 0, "RIO delta must stay disabled while the delayed refresh is deferred in raid")

    controller:Dispatch("GROUP_ROSTER_UPDATE")

    Assert.Equal(rosterUpdates, 1, "raid mode must still route roster updates while refresh is deferred")
    Assert.Equal(refreshCalls, 0, "raid roster updates must not resume the deferred post-run refresh yet")
    Assert.Equal(enableCalls, 0, "raid roster updates must not enable RIO delta yet")

    raidActive = false
    controller:Dispatch("GROUP_ROSTER_UPDATE")

    Assert.Equal(rosterUpdates, 2, "raid exit detection must still flow through GROUP_ROSTER_UPDATE")
    Assert.Equal(refreshCalls, 1, "first roster update after raid exit must resume the deferred post-run refresh")
    Assert.Equal(enableCalls, 1, "RIO delta must enable after the resumed post-run refresh succeeds")
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules
  local Fixtures = ctx.fixtures

  RegisterTargetHandlingTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterTargetActiveEntryTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterGroupAndSyncTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterCombatStartupTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterChallengeStartAndDelayTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterChallengeRetryTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterChallengeRaidResumeTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterHiddenFrameRegenTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterReadyCheckAndStatsTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
end
