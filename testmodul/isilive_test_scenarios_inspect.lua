---@diagnostic disable: undefined-global

local function RegisterInspectRetryTests(test, Assert, WithGlobals, LoadAddonModules)
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
      C_PaperDollInfo = {
        GetInspectItemLevel = function(_unit)
          return 615
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local controller = addon.Inspect.CreateController({})

      local roster = {
        party1 = {},
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
      Assert.Equal(#controller.inspectQueue, 1, "force refresh should queue unit for a new inspect")
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

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterInspectRetryTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterInspectFreshnessTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterInspectRobustnessTests(test, Assert, WithGlobals, LoadAddonModules)
end
