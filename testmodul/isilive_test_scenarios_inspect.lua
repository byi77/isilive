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

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterInspectRetryTests(test, Assert, WithGlobals, LoadAddonModules)
end
