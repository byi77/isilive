local function RegisterQueueFlowAnnounceTests(test, Assert, LoadAddonModules, Fixtures)
  test("QueueFlow announce clears pending for leaders without printing", function()
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow, {
      isPlayerLeader = function()
        return true
      end,
    })

    state.pending = {
      groupName = "Leader Group",
      capturedAt = 1,
    }

    controller.AnnounceQueuedGroupJoin()

    Assert.Nil(state.pending, "leader announce path should clear pending queue info")
    Assert.Equal(#state.prints, 0, "leader announce path should not print chat message")
  end)

  test("QueueFlow announce prints queue joined message for members and clears pending", function()
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow)

    state.pending = {
      groupName = "Member Group",
      capturedAt = 1,
    }

    controller.AnnounceQueuedGroupJoin()

    Assert.Nil(state.pending, "member announce path should clear pending queue info after print")
    Assert.True(#state.prints >= 3, "member announce should print queue summary lines")
  end)

  test("QueueFlow announce does nothing when no pending info exists", function()
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow)

    controller.AnnounceQueuedGroupJoin()

    Assert.Equal(#state.prints, 0, "announce without pending should not print anything")
  end)
end

local function RegisterQueueFlowCaptureTests(test, Assert, LoadAddonModules, Fixtures)
  test("QueueFlow capture ignores queue events while in challenge mode", function()
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow, {
      isInChallengeMode = function()
        return true
      end,
    })

    controller.CaptureQueueJoinCandidate(1001, "invited")

    Assert.Nil(state.pending, "challenge mode must not update pending queue target")
    Assert.Equal(#state.prints, 0, "challenge mode must not print anything")
  end)

  test("QueueFlow capture stores pending info when not in group", function()
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow, {
      isInGroup = function()
        return false
      end,
    })

    controller.CaptureQueueJoinCandidate({ groupName = "My Group" })

    Assert.NotNil(state.pending, "capture outside group should store pending info")
  end)

  test("QueueFlow capture announces immediately when already in group", function()
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow, {
      isInGroup = function()
        return true
      end,
    })

    state.pending = { groupName = "Late Group", capturedAt = 42 }

    controller.CaptureQueueJoinCandidate()

    Assert.Nil(state.pending, "late grouped capture should be consumed by immediate announce")
    Assert.True(#state.prints >= 3, "late grouped capture should print chat summary lines")
  end)

  test("QueueFlow capture resets pending when new search starts outside group", function()
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow, {
      isInGroup = function()
        return false
      end,
    })

    state.pending = { groupName = "Old Group", capturedAt = 1 }
    controller.CaptureQueueJoinCandidate()

    Assert.Nil(state.pending, "capture outside group should reset stale pending info")
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local Fixtures = ctx.fixtures

  RegisterQueueFlowAnnounceTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterQueueFlowCaptureTests(test, Assert, LoadAddonModules, Fixtures)
end
