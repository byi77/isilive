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

local function RegisterCombatStartupM0TrackingTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
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

  test("Event handlers do not record run when leaving non-mythic dungeon", function()
    local current = {
      instanceType = "party",
      difficultyID = 2,
      mapID = 2649,
    }
    local recordedRuns = {}

    WithGlobals({
      GetInstanceInfo = function()
        return "Priory of the Sacred Flame", current.instanceType, current.difficultyID, "Heroic"
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

      controller:Dispatch("PLAYER_ENTERING_WORLD")
    end)

    Assert.Equal(#recordedRuns, 0, "non-mythic dungeon exits must not record an M0 run snapshot")
  end)

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
end

local function RegisterCombatStartupStateRestoreTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  test("Event handlers restore runtime log storage and enabled flag on ADDON_LOADED", function()
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
    Assert.True(setRuntimeLogEnabledValue == true, "ADDON_LOADED must restore runtime log enabled state from DB")
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

local function RegisterChallengeStartAndDelayTests(test, Assert, LoadAddonModules, Fixtures)
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

  test("Event handlers auto-hide main frame on challenge start", function()
    local hideCalls = 0
    local lastVisible = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      setMainFrameVisible = function(visible)
        hideCalls = hideCalls + 1
        lastVisible = visible
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_START")

    Assert.Equal(hideCalls, 1, "challenge start must call main-frame visibility update exactly once")
    Assert.Equal(lastVisible, false, "challenge start must auto-hide main frame")
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
end

local function RegisterReadyCheckAndStatsTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  test("Event handlers toggle ready check state and refresh UI on ready check events", function()
    local counters = { uiUpdates = 0 }
    local readyCheckActive = false

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      setReadyCheckActive = function(value)
        readyCheckActive = value and true or false
      end,
      isReadyCheckActive = function()
        return readyCheckActive
      end,
    })

    controller:Dispatch("READY_CHECK")
    Assert.True(readyCheckActive, "READY_CHECK must mark ready check as active")
    Assert.Equal(counters.uiUpdates, 1, "READY_CHECK should refresh UI once")

    controller:Dispatch("READY_CHECK_CONFIRM", "party1", "ready")
    Assert.Equal(counters.uiUpdates, 2, "READY_CHECK_CONFIRM should refresh UI while ready check is active")

    controller:Dispatch("READY_CHECK_FINISHED")
    Assert.False(readyCheckActive, "READY_CHECK_FINISHED must clear ready check state")
    Assert.Equal(counters.uiUpdates, 3, "READY_CHECK_FINISHED should refresh UI once")

    controller:Dispatch("READY_CHECK_CONFIRM", "party1", "ready")
    Assert.Equal(counters.uiUpdates, 3, "READY_CHECK_CONFIRM should not refresh UI after ready check finished")
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

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules
  local Fixtures = ctx.fixtures

  RegisterTargetHandlingTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterTargetActiveEntryTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterGroupAndSyncTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterCombatStartupTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterChallengeStartAndDelayTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterChallengeRetryTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterHiddenFrameRegenTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterReadyCheckAndStatsTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
end
