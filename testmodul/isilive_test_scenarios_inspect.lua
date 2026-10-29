---@diagnostic disable: undefined-global

local function RegisterInspectRetryTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Inspect partial replies preserve known stats and retry until complete including zero score", function()
    local now, notifications = 10, 0
    WithGlobals({
      GetTime = function()
        return now
      end,
      UnitExists = function()
        return true
      end,
      UnitGUID = function(unit)
        return "guid-" .. unit
      end,
      UnitIsVisible = function()
        return true
      end,
      CanInspect = function()
        return true
      end,
      NotifyInspect = function()
        notifications = notifications + 1
      end,
      C_PaperDollInfo = {
        GetInspectItemLevel = function()
          return 620
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local ctrl = addon.Inspect.CreateController({ inspectDelay = 0, retryInterval = 1 })
      local roster = { party1 = { spec = "Frost", rio = 3210, ilvl = 620 } }
      ctrl.InvalidateMember("party1", roster)
      ctrl.OnUpdate()
      ctrl.OnInspectReady("guid-party1", roster, function()
        return nil
      end, function()
        return nil
      end)
      Assert.Equal(roster.party1.spec, "Frost", "missing spec preserves last known value")
      Assert.Equal(roster.party1.rio, 3210, "missing score preserves last known value")
      Assert.True(roster.party1._refreshQueued, "partial reply remains pending")
      Assert.Equal(#ctrl.retryQueue, 1, "partial reply schedules retry")
      now = 11
      ctrl.OnUpdate()
      ctrl.OnUpdate()
      Assert.Equal(notifications, 2, "retry dispatches a second real inspect")
      ctrl.OnInspectReady("guid-party1", roster, function()
        return 0
      end, function()
        return "Fire"
      end)
      Assert.Equal(roster.party1.rio, 0, "zero score is valid data")
      Assert.Equal(ctrl.rioCache["guid-party1"], 0, "zero score is cached")
      Assert.Equal(roster.party1.spec, "Fire", "complete spec replaces historical value")
      Assert.Nil(roster.party1._refreshQueued, "complete reply ends refresh")
      Assert.False(ctrl.HasPendingWork(), "no retry remains after completion")
    end)
  end)

  test("Inspect retry queue requeues inspectable unit without CheckInteractDistance", function()
    local now = 0
    local canInspect = false
    local notifyCalls = 0

    WithGlobals({
      GetTime = function()
        return now
      end,
      UnitExists = function(_unit)
        return true
      end,
      UnitGUID = function(unit)
        return "guid-" .. tostring(unit)
      end,
      UnitIsVisible = function(_unit)
        return true
      end,
      CanInspect = function(_unit)
        return canInspect
      end,
      NotifyInspect = function(_unit)
        notifyCalls = notifyCalls + 1
      end,
      CheckInteractDistance = nil,
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local controller = addon.Inspect.CreateController({
        inspectDelay = 0,
        retryInterval = 1,
      })

      local roster = { party1 = {} }
      controller.EnqueueInspect("party1", roster)

      controller.OnUpdate()
      Assert.Equal(#controller.inspectQueue, 0, "initial dispatch should consume inspect queue entry")
      Assert.Equal(#controller.retryQueue, 1, "non-inspectable unit should be queued for retry")
      Assert.Equal(notifyCalls, 0, "NotifyInspect must not run while unit is not inspectable")

      canInspect = true
      now = 1
      controller.OnUpdate()
      Assert.Equal(#controller.retryQueue, 0, "retry entry should be removed once unit becomes inspectable")
      Assert.Equal(#controller.inspectQueue, 1, "unit should re-enter inspect queue after retry gate passes")
      Assert.Equal(notifyCalls, 0, "retry processing should only requeue, not inspect immediately")

      controller.OnUpdate()
      Assert.Equal(notifyCalls, 1, "NotifyInspect should run after unit is requeued and dispatch resumes")
      Assert.Equal(controller.isInspecting, "party1", "controller should track currently inspected unit")
    end)
  end)
end

local function RegisterInspectFreshnessTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Inspect marks local stats fresh and clears freshness on force refresh", function()
    local now = 10
    local unitExists = {
      party1 = true,
      party2 = false,
      player = true,
    }

    WithGlobals({
      GetTime = function()
        return now
      end,
      UnitExists = function(unit)
        return unitExists[unit] == true
      end,
      UnitGUID = function(unit)
        if not unitExists[unit] then
          error("UnitGUID must not be called for missing units")
        end
        return "guid-" .. tostring(unit)
      end,
      C_PaperDollInfo = {
        GetInspectItemLevel = function(_unit)
          return 615
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local controller = addon.Inspect.CreateController({})

      local roster = {
        party1 = {
          name = "PartyOne",
          realm = "RealmOne",
        },
        party2 = {
          name = "PartyTwo",
          realm = "RealmTwo",
          spec = "Holy",
          ilvl = 610,
          rio = 2000,
          _localSpecFresh = true,
          _localIlvlFresh = true,
          _localRioFresh = true,
        },
      }

      controller.isInspecting = "party1"
      local changed = controller.OnInspectReady("guid-party1", roster, function(_unit)
        return 3210
      end, function(_unit)
        return "Fury"
      end, nil)

      Assert.True(changed, "matching inspect ready event must update roster")
      Assert.Equal(roster.party1.spec, "Fury", "inspect should write spec")
      Assert.Equal(roster.party1.ilvl, 615, "inspect should write ilvl")
      Assert.Equal(roster.party1.rio, 3210, "inspect should write rio")
      Assert.True(roster.party1._localSpecFresh, "inspect should mark spec as fresh local data")
      Assert.True(roster.party1._localIlvlFresh, "inspect should mark ilvl as fresh local data")
      Assert.True(roster.party1._localRioFresh, "inspect should mark rio as fresh local data")

      controller.QueueForceRefreshData(roster)

      Assert.Nil(roster.party1.spec, "force refresh should clear spec")
      Assert.Nil(roster.party1.ilvl, "force refresh should clear ilvl")
      Assert.Nil(roster.party1.rio, "force refresh should clear rio")
      Assert.Nil(roster.party1._localSpecFresh, "force refresh should clear spec freshness")
      Assert.Nil(roster.party1._localIlvlFresh, "force refresh should clear ilvl freshness")
      Assert.Nil(roster.party1._localRioFresh, "force refresh should clear rio freshness")
      Assert.True(
        roster.party1._refreshQueued,
        "force refresh should keep existing units pending until inspect completes"
      )
      Assert.Equal(#controller.inspectQueue, 1, "force refresh should queue unit for a new inspect")
      Assert.Equal(controller.inspectQueue[1], "party1", "force refresh should immediately queue existing units")
      Assert.Equal(
        roster.party2.spec,
        "Holy",
        "missing units must keep their visible spec until they can be inspected again"
      )
      Assert.Equal(
        roster.party2.ilvl,
        610,
        "missing units must keep their visible ilvl until they can be inspected again"
      )
      Assert.Equal(
        roster.party2.rio,
        2000,
        "missing units must keep their visible rio until they can be inspected again"
      )
      Assert.True(roster.party2._refreshQueued, "missing units must be marked for a later forced inspect")

      local function InspectQueueContains(unit)
        for i = 1, #controller.inspectQueue do
          if controller.inspectQueue[i] == unit then
            return true
          end
        end
        return false
      end

      unitExists.party2 = true
      local addonWithGroup = LoadAddonModules({ "isiLive_inspect.lua", "isiLive_group.lua" })
      local groupController = addonWithGroup.Group.CreateController({
        isInGroup = function()
          return true
        end,
        getWasInGroup = function()
          return true
        end,
        getNumGroupMembers = function()
          return 3
        end,
        getRoster = function()
          return roster
        end,
        setRoster = function(value)
          roster = value
        end,
        resetInspectQueues = function()
          controller.ResetQueues()
        end,
        enqueueInspect = function(unit)
          controller.EnqueueInspect(unit, roster)
        end,
        getUnitNameAndRealm = function(unit)
          if unit == "player" then
            return "TestPlayer", "TestRealm"
          end
          if unit == "party1" then
            return "PartyOne", "RealmOne"
          end
          if unit == "party2" then
            return "PartyTwo", "RealmTwo"
          end
          return nil, nil
        end,
        getUnitClass = function(unit)
          if unit == "player" then
            return "Warrior", "WARRIOR"
          end
          return "Mage", "MAGE"
        end,
        getUnitServerLanguage = function()
          return "DE"
        end,
        getOwnedKeystoneSnapshot = function()
          return nil, nil
        end,
        markIsiLiveUser = function() end,
        setPlayerKeyInfo = function() end,
        getUnitRole = function()
          return "DAMAGER"
        end,
        getPlayerSpecName = function()
          return "Arms"
        end,
        getUnitRio = function()
          return nil
        end,
        unitHasIsiLive = function()
          return false
        end,
        applyKnownKeyToRosterEntry = function(info)
          if not info._refreshQueued and not info._localSpecFresh then
            info.spec = "SYNC-SPEC"
          end
          if not info._refreshQueued and not info._localIlvlFresh then
            info.ilvl = 999
          end
          if not info._refreshQueued and not info._localRioFresh then
            info.rio = 9999
          end
          return true
        end,
      })

      groupController.HandleGroupRosterUpdate()

      Assert.Nil(roster.party1.spec, "rebuilt row must stay blank while the forced refresh is pending")
      Assert.Nil(roster.party1.ilvl, "rebuilt row must stay blank while the forced refresh is pending")
      Assert.Nil(roster.party1.rio, "rebuilt row must stay blank while the forced refresh is pending")
      Assert.True(roster.party1._refreshQueued, "rebuilt row must keep the pending forced refresh")
      Assert.True(InspectQueueContains("party1"), "rebuilt existing units must be re-queued for forced inspect")
      Assert.Equal(roster.party2.spec, "Holy", "rebuilt row must keep the local spec freshness")
      Assert.Equal(roster.party2.ilvl, 610, "rebuilt row must keep the local ilvl freshness")
      Assert.Equal(roster.party2.rio, 2000, "rebuilt row must keep the local rio freshness")
      Assert.True(roster.party2._localSpecFresh, "rebuilt row must keep the local spec freshness flag")
      Assert.True(roster.party2._localIlvlFresh, "rebuilt row must keep the local ilvl freshness flag")
      Assert.True(roster.party2._localRioFresh, "rebuilt row must keep the local rio freshness flag")
      Assert.True(roster.party2._refreshQueued, "rebuilt row must keep the pending forced refresh")
      Assert.True(InspectQueueContains("party2"), "missing units must queue once they become available again")
    end)
  end)

  test("Inspect re-inspects a party member whose spec changed instead of reusing the cached spec", function()
    WithGlobals({
      GetTime = function()
        return 10
      end,
      UnitExists = function(unit)
        return unit == "party1" or unit == "player"
      end,
      UnitGUID = function(unit)
        return "guid-" .. tostring(unit)
      end,
      C_PaperDollInfo = {
        GetInspectItemLevel = function(_unit)
          return 615
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local controller = addon.Inspect.CreateController({})
      local roster = { party1 = { name = "Druid", realm = "Realm", role = "HEALER" } }
      local inspectedSpec, inspectedRole = "Restoration", "HEALER"
      local function Inspect()
        controller.isInspecting = "party1"
        return controller.OnInspectReady(
          "guid-party1",
          roster,
          function(_unit)
            return 3000
          end,
          function(_unit)
            return inspectedSpec
          end,
          nil,
          nil,
          function(_unit)
            return inspectedRole
          end
        )
      end
      Inspect()
      Assert.Equal(roster.party1.spec, "Restoration", "first inspect writes the spec")
      Assert.Equal(controller.GetInspectedSpecRole("party1"), "HEALER", "the inspected spec role is cached")

      controller.inspectQueue = {}
      controller.EnqueueInspect("party1", roster)
      Assert.Equal(#controller.inspectQueue, 0, "a fully cached member is not inspected again")

      -- The healer switches to Balance but keeps the assigned HEALER role.
      inspectedSpec, inspectedRole = "Balance", "DAMAGER"
      Assert.True(controller.InvalidateMember("party1", roster), "a live member is invalidated")
      Assert.Nil(controller.GetInspectedSpecRole("party1"), "the stale spec role is dropped")
      Assert.Equal(#controller.inspectQueue, 1, "the member is queued for a new inspect")
      Assert.True(roster.party1._refreshQueued, "the member stays pending until the inspect returns")
      Inspect()
      Assert.Equal(roster.party1.spec, "Balance", "the new spec replaces the cached one")
      Assert.Equal(roster.party1.role, "DAMAGER", "the inspected spec role replaces the assigned role")

      -- A roster rebuild writes the stale assigned role again; the cache wins.
      roster.party1 = { name = "Druid", realm = "Realm", role = "HEALER" }
      controller.EnqueueInspect("party1", roster)
      Assert.Equal(roster.party1.role, "DAMAGER", "a roster rebuild keeps the inspected spec role")
      Assert.Equal(roster.party1.spec, "Balance", "a roster rebuild keeps the inspected spec")
      Assert.False(controller.InvalidateMember("party2", roster), "an unknown slot is ignored")
    end)
  end)

  test("Inspect triggers sendOwnKeySnapshot on player data change", function()
    local sentSnapshot = false
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitExists = function(_unit)
        return true
      end,
      UnitGUID = function(unit)
        return "guid-" .. unit
      end,
      C_PaperDollInfo = {
        GetInspectItemLevel = function()
          return 620
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local controller = addon.Inspect.CreateController({
        sendOwnKeySnapshot = function()
          sentSnapshot = true
        end,
      })

      local roster = { player = { ilvl = 610 } }
      controller.isInspecting = "player"

      -- Simulate inspect ready with changed data
      controller.OnInspectReady(
        "guid-player",
        roster,
        function()
          return 2000
        end, -- rio
        function()
          return "Fury"
        end, -- spec
        function()
          return "Fury"
        end -- player spec
      )

      Assert.True(sentSnapshot, "should trigger snapshot send when player data changes")
      Assert.Equal(roster.player.ilvl, 620, "roster should be updated")
    end)
  end)

  test("Inspect OnInspectReady updates roster role from inspected specialization role", function()
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitExists = function(_unit)
        return true
      end,
      UnitGUID = function(unit)
        return "guid-" .. unit
      end,
      C_PaperDollInfo = {
        GetInspectItemLevel = function()
          return 620
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local controller = addon.Inspect.CreateController({})
      local roster = {
        party1 = {
          name = "Culus",
          role = "DAMAGER",
          spec = "Unholy",
        },
      }
      controller.isInspecting = "party1"

      local changed = controller.OnInspectReady(
        "guid-party1",
        roster,
        function()
          return 2000
        end,
        function()
          return "Blood"
        end,
        nil,
        nil,
        function()
          return "TANK"
        end
      )

      Assert.True(changed, "role correction from inspected specialization must count as changed data")
      Assert.Equal(roster.party1.spec, "Blood", "inspect must write the verified spec name")
      Assert.Equal(roster.party1.role, "TANK", "inspect must correct stale group-role data from spec role")
    end)
  end)

  test("OnInspectReady falls back to getOwnAverageItemLevel for player when GetInspectItemLevel returns 0", function()
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitExists = function(_unit)
        return true
      end,
      UnitGUID = function(unit)
        return "guid-" .. unit
      end,
      C_PaperDollInfo = {
        GetInspectItemLevel = function()
          return 0 -- Simulates the common case where GetInspectItemLevel("player") returns 0
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local controller = addon.Inspect.CreateController({})

      local roster = { player = {} }
      controller.isInspecting = "player"

      controller.OnInspectReady("guid-player", roster, function()
        return 3000
      end, function()
        return nil
      end, function()
        return "Frost"
      end, function()
        return 645 -- getOwnAverageItemLevel fallback
      end)

      Assert.Equal(roster.player.ilvl, 645, "OnInspectReady must use getOwnAverageItemLevel fallback for player")
      Assert.True(roster.player._localIlvlFresh, "player ilvl from local API must be marked fresh")
    end)
  end)

  test("OnInspectReady does not overwrite existing ilvl when GetInspectItemLevel returns 0/nil", function()
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitExists = function(_unit)
        return true
      end,
      UnitGUID = function(unit)
        return "guid-" .. unit
      end,
      C_PaperDollInfo = {
        GetInspectItemLevel = function()
          return 0
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local controller = addon.Inspect.CreateController({})

      local roster = { party1 = { ilvl = 618, _localIlvlFresh = true } }
      controller.isInspecting = "party1"

      controller.OnInspectReady("guid-party1", roster, function()
        return nil
      end, function()
        return nil
      end, nil, nil)

      Assert.Equal(roster.party1.ilvl, 618, "previously good ilvl must not be wiped by a 0 inspect response")
      Assert.True(roster.party1._localIlvlFresh, "_localIlvlFresh must be preserved when no overwrite happens")
    end)
  end)

  test("Inspect force refresh keeps ghost member data and skips ghost inspect queueing", function()
    WithGlobals({
      UnitGUID = function(unit)
        return "guid-" .. tostring(unit)
      end,
      UnitExists = function(_unit)
        return true
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local controller = addon.Inspect.CreateController({})

      local roster = {
        party1 = {
          spec = "Fury",
          ilvl = 615,
          rio = 3200,
          _localSpecFresh = true,
          _localIlvlFresh = true,
          _localRioFresh = true,
        },
        ["ghost:Leaver-Realm"] = {
          name = "Leaver",
          realm = "Realm",
          spec = "Holy",
          ilvl = 612,
          rio = 3000,
          isGhost = true,
          _localSpecFresh = true,
          _localIlvlFresh = true,
          _localRioFresh = true,
        },
      }

      controller.QueueForceRefreshData(roster)

      Assert.Nil(roster.party1.spec, "active roster entry should be cleared for refresh")
      Assert.Equal(#controller.inspectQueue, 1, "only active roster entry should be queued for inspect")
      Assert.Equal(controller.inspectQueue[1], "party1", "ghost roster entries must not be queued for inspect")

      Assert.Equal(roster["ghost:Leaver-Realm"].spec, "Holy", "ghost spec should be preserved")
      Assert.Equal(roster["ghost:Leaver-Realm"].ilvl, 612, "ghost ilvl should be preserved")
      Assert.Equal(roster["ghost:Leaver-Realm"].rio, 3000, "ghost rio should be preserved")
      Assert.True(roster["ghost:Leaver-Realm"]._localSpecFresh, "ghost freshness flags should stay intact")
      Assert.True(roster["ghost:Leaver-Realm"]._localIlvlFresh, "ghost freshness flags should stay intact")
      Assert.True(roster["ghost:Leaver-Realm"]._localRioFresh, "ghost freshness flags should stay intact")
    end)
  end)
end

local function RegisterInspectRobustnessTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Inspect OnUpdate handles UnitIsVisible errors gracefully by requeueing unit", function()
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitIsVisible = function(_unit)
        error("simulated api error")
      end,
      CanInspect = function(_unit)
        return true
      end,
      NotifyInspect = function(_unit) end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local controller = addon.Inspect.CreateController({
        inspectDelay = 0,
        retryInterval = 5,
      })

      table.insert(controller.inspectQueue, "party1")

      controller.OnUpdate()

      Assert.Equal(#controller.inspectQueue, 0, "unit should be removed from inspect queue")
      Assert.Equal(#controller.retryQueue, 1, "unit should be moved to retry queue on error")
      Assert.Equal(controller.retryQueue[1].unit, "party1", "retry entry should be the problematic unit")
    end)
  end)

  test("Inspect skips missing units before UnitGUID, UnitIsVisible, or CanInspect are called", function()
    local now = 0
    local notifyCalls = 0

    WithGlobals({
      GetTime = function()
        return now
      end,
      UnitExists = function(unit)
        return unit == "player"
      end,
      UnitGUID = function(_unit)
        error("UnitGUID must not be called for missing units")
      end,
      UnitIsVisible = function(_unit)
        error("UnitIsVisible must not be called for missing units")
      end,
      CanInspect = function(_unit)
        error("CanInspect must not be called for missing units")
      end,
      NotifyInspect = function(_unit)
        notifyCalls = notifyCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local controller = addon.Inspect.CreateController({
        inspectDelay = 0,
        retryInterval = 1,
      })

      local roster = { party1 = {} }

      controller.EnqueueInspect("party1", roster)
      Assert.Equal(#controller.inspectQueue, 0, "missing units must not be queued for inspect")

      controller.QueueForceRefreshData(roster)
      Assert.Equal(#controller.inspectQueue, 0, "force refresh must not queue missing units for inspect")

      controller.isInspecting = "party1"
      local changed = controller.OnInspectReady("guid-party1", roster, nil, nil, nil)
      Assert.False(changed, "missing units must not complete inspect-ready processing")
      controller.isInspecting = nil

      table.insert(controller.inspectQueue, "party1")
      controller.OnUpdate()

      Assert.Equal(notifyCalls, 0, "missing units must not reach NotifyInspect")
      Assert.Equal(
        #controller.retryQueue,
        1,
        "stale inspect queue entries should be deferred without raw unit API calls"
      )
    end)
  end)
end

-- Branch coverage targeting the OnUpdate dispatcher (timeout + dispatch_skipped),
-- partial-cache-hit enqueue, IsUnitInInspectQueue duplicate-skip, and the
-- logRuntimeTracef trace lines.
local function RegisterInspectBranchCoverageTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Inspect EnqueueInspect skips when the unit is already queued (IsUnitInInspectQueue=true)", function()
    WithGlobals({
      UnitExists = function(unit)
        return unit == "party1"
      end,
      UnitGUID = function()
        return "guid-party1"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local controller = addon.Inspect.CreateController({})
      local roster = { party1 = { name = "P1" } }

      controller.EnqueueInspect("party1", roster)
      controller.EnqueueInspect("party1", roster) -- second call must not duplicate

      Assert.Equal(#controller.inspectQueue, 1, "duplicate enqueue must be suppressed via IsUnitInInspectQueue")
    end)
  end)

  test("Inspect EnqueueInspect with partial cache hit keeps queueing because rio + spec are still missing", function()
    WithGlobals({
      UnitExists = function(unit)
        return unit == "party1"
      end,
      UnitGUID = function()
        return "guid-party1"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local controller = addon.Inspect.CreateController({})
      controller.ilvlCache["guid-party1"] = 615 -- only ilvl cached, rio + spec missing

      local roster = { party1 = { name = "P1" } }
      controller.EnqueueInspect("party1", roster)

      Assert.Equal(roster.party1.ilvl, 615, "cached ilvl must be applied to roster entry")
      Assert.True(roster.party1._localIlvlFresh == true, "ilvl freshness flag must be set")
      Assert.Nil(roster.party1.rio, "rio remains nil when only ilvl was cached")
      Assert.Equal(#controller.inspectQueue, 1, "unit must still enqueue when not all three caches are populated")
    end)
  end)

  test("Inspect OnUpdate triggers OnInspectTimeout when isInspecting exceeds inspectTimeout", function()
    local now = 0
    WithGlobals({
      GetTime = function()
        return now
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local traces = {}
      local controller = addon.Inspect.CreateController({
        inspectTimeout = 2,
        retryInterval = 5,
        logRuntimeTracef = function(fmt, ...)
          table.insert(traces, string.format(fmt, ...))
        end,
      })
      controller.isInspecting = "party1"
      controller.lastInspectTime = 0

      now = 10 -- well past the 2s timeout
      controller.OnUpdate()

      Assert.Nil(controller.isInspecting, "isInspecting must clear on timeout")
      Assert.Equal(#controller.retryQueue, 1, "retry queue must receive a re-attempt entry")
      Assert.Equal(controller.retryQueue[1].unit, "party1", "retry entry must remember the timed-out unit")
      Assert.Equal(controller.retryQueue[1].nextRetry, 10 + 5, "retry must schedule at now + retryInterval")
      local found = false
      for _, line in ipairs(traces) do
        if line:find("[INSPECT] timeout unit=party1", 1, true) then
          found = true
          break
        end
      end
      Assert.True(found, "logRuntimeTracef must surface the timeout line")
    end)
  end)

  test("Inspect OnUpdate dispatch logs not-inspectable skip when UnitIsVisible returns false", function()
    local now = 100
    WithGlobals({
      GetTime = function()
        return now
      end,
      UnitExists = function()
        return true
      end,
      UnitIsVisible = function()
        return false -- forces IsUnitInspectable -> false
      end,
      CanInspect = function()
        return true
      end,
      NotifyInspect = function()
        error("NotifyInspect must not fire when unit is not inspectable")
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local traces = {}
      local controller = addon.Inspect.CreateController({
        inspectDelay = 0,
        retryInterval = 5,
        logRuntimeTracef = function(fmt, ...)
          table.insert(traces, string.format(fmt, ...))
        end,
      })
      table.insert(controller.inspectQueue, "party1")
      controller.lastInspectTime = 0

      controller.OnUpdate()

      Assert.Nil(controller.isInspecting, "must not start inspecting an invisible unit")
      Assert.Equal(#controller.retryQueue, 1, "invisible unit must be moved to the retry queue")
      Assert.Equal(controller.retryQueue[1].unit, "party1", "retry entry must remember the unit")
      Assert.Equal(controller.retryQueue[1].nextRetry, now + 5, "retry must schedule at now + retryInterval")
      local found = false
      for _, line in ipairs(traces) do
        if line:find("dispatch_skipped unit=party1 not_inspectable", 1, true) then
          found = true
          break
        end
      end
      Assert.True(found, "logRuntimeTracef must surface the dispatch_skipped line")
    end)
  end)

  test("Inspect OnUpdate dispatch logs the dispatch line when unit IS inspectable", function()
    local now = 100
    local notifyTarget
    WithGlobals({
      GetTime = function()
        return now
      end,
      UnitExists = function()
        return true
      end,
      UnitIsVisible = function()
        return true
      end,
      CanInspect = function()
        return true
      end,
      NotifyInspect = function(unit)
        notifyTarget = unit
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local traces = {}
      local controller = addon.Inspect.CreateController({
        inspectDelay = 0,
        logRuntimeTracef = function(fmt, ...)
          table.insert(traces, string.format(fmt, ...))
        end,
      })
      table.insert(controller.inspectQueue, "party2")
      controller.lastInspectTime = 0

      controller.OnUpdate()

      Assert.Equal(notifyTarget, "party2", "NotifyInspect must be called with the dispatched unit")
      Assert.Equal(controller.isInspecting, "party2", "controller must mark the unit as actively inspected")
      local found = false
      for _, line in ipairs(traces) do
        if line:find("dispatch unit=party2 queueRemaining=0", 1, true) then
          found = true
          break
        end
      end
      Assert.True(found, "logRuntimeTracef must surface the dispatch line")
    end)
  end)

  test("Inspect OnInspectReady emits the result trace when logRuntimeTracef is configured", function()
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitExists = function()
        return true
      end,
      UnitGUID = function()
        return "guid-party3"
      end,
      C_PaperDollInfo = {
        GetInspectItemLevel = function()
          return 620
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local traces = {}
      local controller = addon.Inspect.CreateController({
        logRuntimeTracef = function(fmt, ...)
          table.insert(traces, string.format(fmt, ...))
        end,
      })
      controller.isInspecting = "party3"
      local roster = { party3 = { name = "P3" } }

      controller.OnInspectReady("guid-party3", roster, function()
        return 2500
      end, function()
        return "Frost"
      end, nil)

      local found = false
      for _, line in ipairs(traces) do
        if line:find("[INSPECT] result unit=party3", 1, true) and line:find("ilvl=620", 1, true) then
          found = true
          break
        end
      end
      Assert.True(found, "logRuntimeTracef must surface the result line with the captured values")
    end)
  end)
end

local function BaseInspectGlobals(overrides)
  local globals = {
    UnitExists = function(unit)
      return unit ~= nil and unit ~= ""
    end,
    UnitGUID = function(unit)
      return "guid-" .. tostring(unit)
    end,
    UnitIsVisible = function()
      return true
    end,
    CanInspect = function()
      return true
    end,
    C_PaperDollInfo = {
      GetInspectItemLevel = function(unit)
        return unit == "party2" and 633 or 620
      end,
    },
  }
  for key, value in pairs(overrides or {}) do
    globals[key] = value
  end
  return globals
end

local function RegisterInspectHarvestTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Inspect harvests a foreign INSPECT_READY without touching the own in-flight inspect", function()
    local now, notified = 10, {}
    WithGlobals(
      BaseInspectGlobals({
        GetTime = function()
          return now
        end,
        NotifyInspect = function(unit)
          notified[#notified + 1] = unit
        end,
      }),
      function()
        local addon = LoadAddonModules({ "isiLive_inspect.lua" })
        local traces = {}
        local ctrl = addon.Inspect.CreateController({
          inspectDelay = 0,
          retryInterval = 1,
          logRuntimeTracef = function(fmt, ...)
            traces[#traces + 1] = string.format(fmt, ...)
          end,
        })
        local roster = { party1 = {}, party2 = { _refreshQueued = true } }
        ctrl.EnqueueInspect("party1", roster)
        ctrl.EnqueueInspect("party2", roster)
        ctrl.OnUpdate()
        Assert.Equal(ctrl.isInspecting, "party1", "own inspect is in flight for party1")
        Assert.Equal(#ctrl.inspectQueue, 1, "party2 still waits in the queue")

        now = 10.5
        local changed = ctrl.OnInspectReady("guid-party2", roster, function()
          return 2400
        end, function()
          return "Frost"
        end)

        Assert.True(changed, "harvested data reports a change")
        Assert.Equal(roster.party2.ilvl, 633, "foreign reply fills the item level")
        Assert.Equal(roster.party2.rio, 2400, "foreign reply fills the score")
        Assert.Equal(roster.party2.spec, "Frost", "foreign reply fills the spec")
        Assert.True(roster.party2._localIlvlFresh, "harvested inspect counts as a local inspect")
        Assert.Nil(roster.party2._refreshQueued, "complete harvest ends the pending refresh")
        Assert.Equal(ctrl.ilvlCache["guid-party2"], 633, "harvested item level is cached per GUID")
        Assert.Equal(#ctrl.inspectQueue, 0, "complete harvest removes the member from the queue")
        Assert.Equal(ctrl.isInspecting, "party1", "own in-flight inspect is untouched")
        Assert.Equal(ctrl.lastInspectTime, 10, "own inspect timer is untouched")
        Assert.Equal(#ctrl.retryQueue, 0, "harvest schedules no retry")

        local harvestedTrace = false
        for _, line in ipairs(traces) do
          if line:find("[INSPECT] harvested unit=party2", 1, true) then
            harvestedTrace = true
          end
        end
        Assert.True(harvestedTrace, "harvest is visible in the runtime log")

        ctrl.OnInspectReady("guid-party1", roster, function()
          return 2100
        end, function()
          return "Fire"
        end)
        Assert.Nil(ctrl.isInspecting, "own reply still releases the dispatcher afterwards")
        Assert.Equal(roster.party1.spec, "Fire", "own reply is applied as before")
        Assert.Equal(#notified, 1, "no extra inspect was sent for the harvested member")
      end
    )
  end)

  test("Inspect keeps the queue when a harvested foreign reply is incomplete", function()
    WithGlobals(
      BaseInspectGlobals({
        GetTime = function()
          return 5
        end,
        NotifyInspect = function() end,
      }),
      function()
        local addon = LoadAddonModules({ "isiLive_inspect.lua" })
        local ctrl = addon.Inspect.CreateController({ inspectDelay = 1, retryInterval = 1 })
        local roster = { party2 = { rio = 1800 } }
        ctrl.EnqueueInspect("party2", roster)
        ctrl.OnInspectReady("guid-party2", roster, function()
          return 1800
        end, function()
          return nil
        end)
        Assert.Equal(roster.party2.ilvl, 633, "readable fields are still kept")
        Assert.Equal(#ctrl.inspectQueue, 1, "incomplete harvest leaves the member queued")
        Assert.Equal(#ctrl.retryQueue, 0, "incomplete harvest adds no retry of its own")
        Assert.Nil(ctrl.isInspecting, "nothing was dispatched")
      end
    )
  end)

  test("Inspect ignores INSPECT_READY for unknown, ghost and secret GUIDs", function()
    WithGlobals(
      BaseInspectGlobals({
        GetTime = function()
          return 5
        end,
        issecretvalue = function(value)
          return value == "secret-guid"
        end,
      }),
      function()
        local addon = LoadAddonModules({ "isiLive_inspect.lua" })
        local ctrl = addon.Inspect.CreateController({})
        local roster = { party1 = {}, ["ghost:Bob"] = { isGhost = true } }
        Assert.False(ctrl.OnInspectReady("guid-raid7", roster), "GUID outside the roster is ignored")
        Assert.False(ctrl.OnInspectReady("guid-ghost:Bob", roster), "ghost rows are never matched")
        Assert.False(ctrl.OnInspectReady("secret-guid", roster), "secret GUID is never compared")
        Assert.Nil(roster.party1.ilvl, "no data was written")
      end
    )
  end)
end

local function RegisterInspectFrameGuardTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Inspect holds dispatch while the inspect window is open and resumes after it closes", function()
    local now, notified, shown = 10, 0, true
    local inspectFrame = {
      IsShown = function()
        return shown
      end,
    }
    WithGlobals(
      BaseInspectGlobals({
        GetTime = function()
          return now
        end,
        NotifyInspect = function()
          notified = notified + 1
        end,
        InspectFrame = inspectFrame,
      }),
      function()
        local addon = LoadAddonModules({ "isiLive_inspect.lua" })
        local traces = {}
        local ctrl = addon.Inspect.CreateController({
          inspectDelay = 0,
          logRuntimeTracef = function(fmt, ...)
            traces[#traces + 1] = string.format(fmt, ...)
          end,
        })
        local roster = { party1 = {} }
        ctrl.EnqueueInspect("party1", roster)
        ctrl.OnUpdate()
        now = 11
        ctrl.OnUpdate()
        Assert.Equal(notified, 0, "no NotifyInspect while the inspect window is open")
        Assert.Equal(#ctrl.inspectQueue, 1, "queue is kept while paused")
        Assert.True(ctrl.HasDueWork(), "paused work keeps the loop attached")
        Assert.Equal(#traces, 1, "pause is logged once, not every tick")

        shown = false
        now = 12
        ctrl.OnUpdate()
        Assert.Equal(notified, 1, "dispatch resumes once the window is closed")
        Assert.Equal(ctrl.isInspecting, "party1", "the held member is inspected")
      end
    )
  end)
end

local function CreateOpenRaidStub(gearByUnit)
  local stub = { registrations = {} }
  stub.lib = {
    RegisterCallback = function(addonObject, event, memberName)
      if type(addonObject) ~= "table" or type(addonObject[memberName]) ~= "function" then
        return 3
      end
      stub.registrations[#stub.registrations + 1] = { addonObject, event, memberName }
      return true
    end,
    GetUnitGear = function(unit)
      if unit == "party3" then
        error("secret name used as table key")
      end
      return gearByUnit[unit]
    end,
  }
  stub.LibStub = {
    GetLibrary = function(_self, major, silent)
      return major == "LibOpenRaid-1.0" and silent == true and stub.lib or nil
    end,
  }
  -- Fires the way LibOpenRaid's TriggerCallback does: payload only, no self.
  function stub.Fire(unitId, gearInfo)
    for _, registration in ipairs(stub.registrations) do
      local addonObject, memberName = registration[1], registration[3]
      addonObject[memberName](unitId, gearInfo, {})
    end
  end
  return stub
end

local function RegisterOpenRaidBridgeTests(test, Assert, WithGlobals, LoadAddonModules)
  test("OpenRaid bridge fills item levels by priority: inspect, then sync, then LibOpenRaid", function()
    local secretGear = {}
    local stub = CreateOpenRaidStub({ party4 = { ilevel = 612 } })
    WithGlobals(
      BaseInspectGlobals({
        GetTime = function()
          return 10
        end,
        NotifyInspect = function() end,
        LibStub = stub.LibStub,
        issecretvalue = function(value)
          return value == secretGear
        end,
        UnitGUID = function(unit)
          if unit == "Bob" then
            return "guid-party1"
          end
          return "guid-" .. tostring(unit)
        end,
      }),
      function()
        local addon = LoadAddonModules({ "isiLive_inspect.lua" })
        local ctrl = addon.Inspect.CreateController({ inspectDelay = 0 })
        local roster = {
          player = { ilvl = 650, _localIlvlFresh = true },
          party1 = {},
          party2 = { ilvl = 630 },
          party3 = {},
          party4 = {},
        }
        local raid, changes = false, 0
        local bridge = addon.Inspect.CreateOpenRaidBridge({
          inspectController = ctrl,
          getRoster = function()
            return roster
          end,
          isActive = function()
            return not raid
          end,
          onChanged = function()
            changes = changes + 1
          end,
        })

        Assert.True(bridge.Attach(), "bridge registers its GearUpdate callback")
        Assert.True(bridge.Attach(), "second attach is a no-op")
        Assert.Equal(#stub.registrations, 1, "callback is registered exactly once")

        stub.Fire("party1", { ilevel = 640 })
        Assert.Equal(roster.party1.ilvl, 640, "broadcast fills an empty item level")
        Assert.Nil(roster.party1._localIlvlFresh, "broadcast is not marked as a local inspect")
        Assert.Nil(ctrl.ilvlCache["guid-party1"], "broadcast is not cached as an inspect result")
        Assert.Equal(changes, 1, "a change triggers one UI update")

        stub.Fire("Bob", { ilevel = 641 })
        Assert.Equal(roster.party1.ilvl, 641, "bare-name unitId resolves through the GUID")

        ctrl.EnqueueInspect("party1", roster)
        Assert.Equal(#ctrl.inspectQueue, 1, "broadcast leaves the rio/spec inspect owed")
        ctrl.OnUpdate()
        ctrl.OnInspectReady("guid-party1", roster, function()
          return 2000
        end, function()
          return "Arms"
        end)
        Assert.Equal(roster.party1.ilvl, 620, "own inspect replaces the broadcast value")
        stub.Fire("party1", { ilevel = 655 })
        Assert.Equal(roster.party1.ilvl, 620, "inspect wins over a later broadcast")

        stub.Fire("party2", { ilevel = 645 })
        Assert.Equal(roster.party2.ilvl, 630, "isiLive sync value is kept")

        stub.Fire("player", { ilevel = 700 })
        Assert.Equal(roster.player.ilvl, 650, "own player is ignored")

        stub.Fire("party4", secretGear)
        stub.Fire("party4", { ilevel = 0 })
        Assert.Nil(roster.party4.ilvl, "secret or empty gear is ignored")

        raid = true
        stub.Fire("party4", { ilevel = 610 })
        Assert.Nil(roster.party4.ilvl, "bridge is inert in a raid")
        raid = false

        local before = changes
        Assert.True(bridge.Sweep(), "sweep drains gear received before registration")
        Assert.Equal(roster.party4.ilvl, 612, "sweep fills the stored value")
        Assert.Equal(changes, before + 1, "one sweep triggers one UI update")
        Assert.Nil(roster.party3.ilvl, "a throwing GetUnitGear is contained")

        stub.Fire("party4", { ilevel = 615 })
        Assert.Equal(roster.party4.ilvl, 615, "a newer broadcast replaces its own older value")
      end
    )
  end)

  test("OpenRaid bridge stays inert without LibOpenRaid and schedules no timer", function()
    local timers = 0
    WithGlobals(
      BaseInspectGlobals({
        LibStub = nil,
        C_Timer = {
          After = function()
            timers = timers + 1
          end,
        },
      }),
      function()
        local addon = LoadAddonModules({ "isiLive_inspect.lua" })
        local ctrl = addon.Inspect.CreateController({})
        local bridge = addon.Inspect.CreateOpenRaidBridge({
          inspectController = ctrl,
          getRoster = function()
            return { party1 = {} }
          end,
        })
        Assert.False(bridge.Attach(), "nothing to attach to")
        bridge.ScheduleSweep()
        Assert.Equal(timers, 0, "no sweep timer without the library")
        Assert.False(bridge.Sweep(), "sweep is a no-op")
      end
    )
  end)

  test("OpenRaid bridge collapses roster bursts into one delayed sweep", function()
    local pending = {}
    local stub = CreateOpenRaidStub({ party1 = { ilevel = 605 } })
    WithGlobals(
      BaseInspectGlobals({
        LibStub = stub.LibStub,
        C_Timer = {
          After = function(_delay, callback)
            pending[#pending + 1] = callback
          end,
        },
      }),
      function()
        local addon = LoadAddonModules({ "isiLive_inspect.lua" })
        local ctrl = addon.Inspect.CreateController({})
        local roster = { party1 = {} }
        local bridge = addon.Inspect.CreateOpenRaidBridge({
          inspectController = ctrl,
          getRoster = function()
            return roster
          end,
        })
        bridge.ScheduleSweep()
        bridge.ScheduleSweep()
        Assert.Equal(#pending, 1, "a burst schedules one sweep")
        pending[1]()
        Assert.Equal(roster.party1.ilvl, 605, "delayed sweep applies the stored gear")
        bridge.ScheduleSweep()
        Assert.Equal(#pending, 2, "a later roster change schedules again")
      end
    )
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterInspectRetryTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterInspectFreshnessTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterInspectRobustnessTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterInspectBranchCoverageTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterInspectHarvestTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterInspectFrameGuardTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterOpenRaidBridgeTests(test, Assert, WithGlobals, LoadAddonModules)
end
