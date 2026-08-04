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
    local kickSnapshotForceCalls = {}
    local scheduled = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      timerAfter = function(seconds, callback)
        table.insert(scheduled, { seconds = seconds, callback = callback })
      end,
      sendOwnKeySnapshot = function(force)
        table.insert(keySnapshotForceCalls, force == true)
      end,
      sendOwnKickState = function(force)
        table.insert(kickSnapshotForceCalls, force == true)
      end,
    })

    controller:Dispatch("PLAYER_ENTERING_WORLD")

    Assert.Equal(#keySnapshotForceCalls, 1, "entering world should send one immediate key snapshot")
    Assert.True(keySnapshotForceCalls[1], "immediate entering-world key snapshot must stay forced")
    Assert.Equal(#kickSnapshotForceCalls, 1, "entering world should send one immediate kick snapshot")
    Assert.True(kickSnapshotForceCalls[1], "immediate entering-world kick snapshot must stay forced")
    Assert.Equal(#scheduled, 2, "entering world should only schedule hotkey reapply callbacks")
  end)

  test("Event handlers force kick snapshot on PLAYER_ENTERING_WORLD independent of specialization", function()
    local kickSnapshotForceCalls = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 71
        end
        return nil
      end,
      sendOwnKickState = function(force)
        table.insert(kickSnapshotForceCalls, force == true)
      end,
    })

    controller:Dispatch("PLAYER_ENTERING_WORLD")

    Assert.Equal(#kickSnapshotForceCalls, 1, "entering world must force one kick snapshot regardless of specialization")
    Assert.True(
      kickSnapshotForceCalls[1],
      "entering-world kick snapshot must stay forced for non-hunter interrupt specs"
    )
  end)

  test("Event handlers send real sync snapshots on PLAYER_ENTERING_WORLD after reload", function()
    local sentMessages = {}
    local rosterUpdates = 0

    WithGlobals({
      GetTime = function()
        return 100
      end,
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
        end,
      },
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          return 15
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return 2649
        end,
      },
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 72, "Fury"
        end
        return nil
      end,
      C_Item = {
        GetAverageItemLevel = function()
          return 611.4, 615.2
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua", "isiLive_keysync.lua", "isiLive_event_handlers.lua" })
      local keysync = addon.KeySync.CreateController({
        sync = addon.Sync,
        getUnitNameAndRealm = function(_unit)
          return "Me", "Realm"
        end,
        getAddonVersionRaw = function()
          return "1.0"
        end,
        getUnitRio = function(_unit)
          return 3210
        end,
        isFrameVisible = function()
          return false
        end,
      })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
        isInGroup = function()
          return true
        end,
        isInPartyInstance = function()
          return false
        end,
        isMainFrameShown = function()
          return false
        end,
        timerAfter = function(_seconds, callback)
          callback()
        end,
        handleGroupRosterUpdate = function()
          rosterUpdates = rosterUpdates + 1
        end,
        sendOwnKeySnapshot = function(force, source, allowHidden)
          return keysync.SendOwnKeySnapshot(force, source, allowHidden)
        end,
        sendOwnKickState = function(force)
          return addon.Sync.SendKick({
            force = force == true,
            hasKick = false,
            onCooldown = false,
            cooldownRemain = 0,
          })
        end,
      })

      controller:Dispatch("PLAYER_ENTERING_WORLD")
    end)

    Assert.Equal(rosterUpdates, 1, "entering world after reload must rebuild the roster once")
    Assert.Equal(#sentMessages, 5, "entering world must publish key, stats, dps, loc, and kick payloads")
    Assert.Equal(sentMessages[1].message, "KEY:2649:15:100:world", "entering world must publish a forced KEY snapshot")
    Assert.Equal(
      sentMessages[2].message,
      "STATS:72:615:3210:100:world",
      "entering world must publish a forced STATS snapshot"
    )
    Assert.Equal(sentMessages[3].message, "DPS:0:100:world", "entering world must publish a forced DPS snapshot")
    Assert.Equal(sentMessages[4].message, "LOC:0:100:world", "entering world must publish a forced LOC snapshot")
    Assert.Equal(sentMessages[5].message, "KICK:-1:0", "entering world must publish a forced kick snapshot")
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

  test("Event handlers call updateCdTracker only on Sated-relevant UNIT_AURA payloads", function()
    local cdTrackerCalls = 0
    local lastOptions = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      updateCdTracker = function(opts)
        cdTrackerCalls = cdTrackerCalls + 1
        lastOptions = opts
      end,
    })

    -- Full-update and missing-payload variants are the conservative path:
    -- always scan, because we cannot tell what changed.
    controller:Dispatch("UNIT_AURA", "player", { isFullUpdate = true })
    controller:Dispatch("UNIT_AURA", "player", nil)
    Assert.Equal(cdTrackerCalls, 2, "isFullUpdate=true and nil updateInfo must trigger a scan")

    -- Empty-payload event from a DoT tick / proc refresh: no aura actually
    -- added or removed -> no Sated change possible -> skip the 40-slot pcall scan.
    controller:Dispatch("UNIT_AURA", "player", {})
    controller:Dispatch("UNIT_AURA", "player", { addedAuras = {} })
    controller:Dispatch("UNIT_AURA", "player", { addedAuras = { { spellId = 12345 } } })
    Assert.Equal(cdTrackerCalls, 2, "UNIT_AURA without a Sated-relevant change must skip the CD scan")

    -- Added a Sated debuff -> must scan so the lust countdown is picked up.
    controller:Dispatch("UNIT_AURA", "player", { addedAuras = { { spellId = 57723 } } })
    Assert.Equal(cdTrackerCalls, 3, "added Sated debuff must trigger a scan")
    Assert.True(
      type(lastOptions) == "table" and lastOptions.playLustSoundOnStart == true,
      "Sated UNIT_AURA scans must allow the factory to play the Bloodlust onset sound"
    )
  end)

  test("Event handlers call updateCdTracker on UNIT_AURA aura removals", function()
    local cdTrackerCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      updateCdTracker = function()
        cdTrackerCalls = cdTrackerCalls + 1
      end,
    })

    controller:Dispatch("UNIT_AURA", "player", { removedAuraInstanceIDs = { 42 } })
    Assert.Equal(
      cdTrackerCalls,
      1,
      "removed aura instance payloads must trigger a scan because Sated expiry has no spellId"
    )

    controller:Dispatch("UNIT_AURA", "player", { removedAuras = { 42 } })
    Assert.Equal(cdTrackerCalls, 2, "legacy removed aura payloads must also trigger a scan")
  end)

  test("Event handlers call updateCdTracker on UNIT_AURA aura instance updates", function()
    local cdTrackerCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      updateCdTracker = function()
        cdTrackerCalls = cdTrackerCalls + 1
      end,
    })

    controller:Dispatch("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 42 } })
    Assert.Equal(
      cdTrackerCalls,
      1,
      "updated aura instance payloads must trigger a scan because Sated expiry can arrive without spellId"
    )
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
      UnitExists = function(unit)
        return unit == "player"
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

  test("Event handlers record run when leaving a mythic zero dungeon", function()
    -- difficultyID 23: mythic party dungeon without an inserted keystone. This
    -- is the only non-challenge run still tracked; normal, heroic and
    -- timewalking runs belong to the reduced profile and record nothing.
    local current = {
      instanceType = "party",
      difficultyID = 23,
      mapID = 2649,
    }
    local recordedRuns = {}
    local trackedContexts = {}
    local clearTrackedContexts = 0
    local roster = {
      player = { name = "Me", realm = "MyRealm" },
      party1 = { name = "Buddy", realm = "Realm" },
    }

    WithGlobals({
      GetInstanceInfo = function()
        return "Priory of the Sacred Flame", current.instanceType, current.difficultyID, "Mythic"
      end,
      UnitExists = function(unit)
        return unit == "player"
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
        setTrackedPartyRunInfo = function(value)
          trackedContexts[#trackedContexts + 1] = value
        end,
        clearTrackedPartyRunInfo = function()
          clearTrackedContexts = clearTrackedContexts + 1
        end,
      })

      controller:Dispatch("PLAYER_ENTERING_WORLD")
      Assert.Equal(#trackedContexts, 1, "mythic zero entry must publish a verified tracked party-run context")
      Assert.Equal(trackedContexts[1].mapID, 2649, "tracked party-run context must carry the verified map id")
      Assert.Equal(
        trackedContexts[1].difficultyID,
        23,
        "tracked party-run context must carry the verified difficulty id"
      )
      Assert.Equal(
        trackedContexts[1].instanceName,
        "Priory of the Sacred Flame",
        "tracked party-run context must carry the verified instance name when available"
      )

      current.instanceType = "none"
      current.difficultyID = 0
      current.mapID = nil
      roster = {}

      controller:Dispatch("PLAYER_ENTERING_WORLD")
    end)

    Assert.Equal(#recordedRuns, 1, "mythic zero exits should record one non-challenge run snapshot")
    Assert.Equal(recordedRuns[1].mapID, 2649, "mythic zero exit should keep the recorded dungeon map id")
    Assert.Equal(recordedRuns[1].level, 0, "mythic zero snapshots should keep non-key level 0")
    Assert.Nil(recordedRuns[1].onTime, "mythic zero snapshots have no timed-run flag")
    Assert.True(clearTrackedContexts > 0, "mythic zero exit must clear the tracked party-run utility context")
  end)

  test("Event handlers record no run for reduced-profile dungeons", function()
    -- Normal, heroic and timewalking runs are IDLE profile: the last-run DPS
    -- snapshot is a Mythic+ statistic and must not be captured for them.
    for _, difficultyID in ipairs({ 1, 2, 24 }) do
      local current = {
        instanceType = "party",
        difficultyID = difficultyID,
        mapID = 2649,
      }
      local recordedRuns = {}
      local trackedContexts = {}
      local roster = {
        player = { name = "Me", realm = "MyRealm" },
        party1 = { name = "Buddy", realm = "Realm" },
      }

      WithGlobals({
        GetInstanceInfo = function()
          return "Priory of the Sacred Flame", current.instanceType, current.difficultyID, "Reduced"
        end,
        UnitExists = function(unit)
          return unit == "player"
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
            table.insert(recordedRuns, { mapID = mapID, level = level, onTime = onTime })
          end,
          setTrackedPartyRunInfo = function(value)
            trackedContexts[#trackedContexts + 1] = value
          end,
          clearTrackedPartyRunInfo = function() end,
        })

        controller:Dispatch("PLAYER_ENTERING_WORLD")
        Assert.Equal(#trackedContexts, 0, "reduced-profile dungeon entry must not publish a tracked party-run context")

        current.instanceType = "none"
        current.difficultyID = 0
        current.mapID = nil
        roster = {}
        controller:Dispatch("PLAYER_ENTERING_WORLD")
      end)

      Assert.Equal(#recordedRuns, 0, "reduced-profile dungeon exit must not record a run snapshot")
    end
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
      UnitExists = function(unit)
        return unit == "player"
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
      UnitExists = function(unit)
        return unit == "player"
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
      UnitExists = function(unit)
        return unit == "player"
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

  test("Event handlers tracked M0 map lookup skips player map lookup when player unit is missing", function()
    local mapCalls = 0

    WithGlobals({
      GetInstanceInfo = function()
        return "Tracked Dungeon", "party", 23, "Mythic"
      end,
      UnitExists = function(_unit)
        return false
      end,
      C_Map = {
        GetBestMapForUnit = function(_unit)
          mapCalls = mapCalls + 1
          error("GetBestMapForUnit must not run when player unit is missing")
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
        getRoster = function()
          return {}
        end,
      })

      controller:Dispatch("PLAYER_ENTERING_WORLD")
    end)

    Assert.Equal(mapCalls, 0, "tracked M0 startup must skip player map lookup when UnitExists is false")
  end)
end

local function RegisterCombatStartupM0TrackingTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterCombatStartupM0LifecycleTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterCombatStartupM0EdgeCaseTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
end

local function RegisterCombatStartupStateRestoreTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
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

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules
  local Fixtures = ctx.fixtures

  RegisterCombatStartupTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
end
