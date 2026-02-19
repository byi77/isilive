return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules
  local Fixtures = ctx.fixtures

  test("QueueFlow permissive resolver is robust when activity API errors", function()
    local callbackChecked = false
    local callbackOk = false
    local callbackValue = "unset"

    WithGlobals({
      C_LFGList = {
        GetActivityInfoTable = function(_activityID)
          error("simulated api failure")
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
      local controller = Fixtures.BuildQueueFlowController(addon.QueueFlow, {
        queueCaptureQueueJoinCandidate = function(_updatePendingQueueJoin, permissiveResolver, ...)
          local ok, value = pcall(permissiveResolver, 777, ...)
          callbackChecked = true
          callbackOk = ok
          callbackValue = value
        end,
      })

      controller.CaptureQueueJoinCandidate("dummy")
    end)

    Assert.True(callbackChecked, "queue capture callback must run")
    Assert.True(callbackOk, "permissive resolver must not raise on API failure")
    Assert.Nil(callbackValue, "permissive resolver should return nil on API failure")
  end)

  test("QueueFlow update ignores lower-priority pending updates", function()
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow)

    state.pending = {
      groupName = "Top Group",
      dungeonName = "Top Dungeon",
      activityID = 1001,
      teleportSpellID = 367416,
      priority = 2,
      capturedAt = 1,
    }

    controller.UpdatePendingQueueJoin("New Group", "New Dungeon", 1, 2001)

    Assert.Equal(state.pending.groupName, "Top Group", "lower priority update must not replace pending group")
    Assert.Equal(state.pending.dungeonName, "Top Dungeon", "lower priority update must not replace pending dungeon")
    Assert.Equal(#state.hints, 0, "ignored updates must not produce invite hints")
  end)

  test("QueueFlow update carries forward known target for same group", function()
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow, {
      resolveSeason3TeleportSpellID = function(_activityID, _dungeonName)
        return nil
      end,
    })

    state.pending = {
      groupName = "Carry Group",
      dungeonName = "Carry Dungeon",
      activityID = 2001,
      teleportSpellID = 445414,
      priority = 1,
      capturedAt = 10,
    }

    controller.UpdatePendingQueueJoin("Carry Group", nil, 1, nil)

    Assert.NotNil(state.pending, "pending state should remain available")
    Assert.Equal(state.pending.dungeonName, "Carry Dungeon", "same-group updates should keep known dungeon")
    Assert.Equal(state.pending.activityID, 2001, "same-group updates should keep known activityID")
    Assert.Equal(state.pending.teleportSpellID, 445414, "same-group updates should keep known teleport spell")
  end)

  test("QueueFlow update suppresses exact duplicate updates", function()
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow)

    controller.UpdatePendingQueueJoin("Dup Group", "Dup Dungeon", 1, 1001)
    controller.UpdatePendingQueueJoin("Dup Group", "Dup Dungeon", 1, 1001)

    Assert.Equal(#state.hints, 1, "duplicate updates should only emit one invite hint")
    Assert.Equal(state.teleportUpdates, 1, "duplicate updates should only trigger one teleport refresh")
  end)

  test("QueueFlow announce clears pending for leaders without preview", function()
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow, {
      isPlayerLeader = function()
        return true
      end,
    })

    state.pending = {
      groupName = "Leader Group",
      dungeonName = "Leader Dungeon",
      activityID = 1001,
      priority = 2,
    }

    controller.AnnounceQueuedGroupJoin()

    Assert.Nil(state.pending, "leader announce path should clear pending queue info")
    Assert.Equal(#state.queueTargets, 0, "leader announce path should not render queue target preview")
  end)

  test("QueueFlow announce shows preview for members and clears pending", function()
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow)

    state.pending = {
      groupName = "Member Group",
      dungeonName = "Member Dungeon",
      activityID = 1001,
      priority = 2,
    }

    controller.AnnounceQueuedGroupJoin()

    Assert.Nil(state.pending, "member announce path should clear pending queue info after preview")
    Assert.Equal(#state.queueTargets, 1, "member announce path should set queue target preview")
    Assert.Equal(state.queueTargets[1].activityID, 1001, "preview should keep pending activityID")
    Assert.Equal(state.queueTargets[1].spellID, 367416, "preview should resolve teleport spell for activity")
    Assert.Equal(#state.centerNotices, 1, "member announce should show center notice")
    Assert.True(#state.prints >= 3, "member announce should print queue summary lines")
  end)

  test("QueueFlow capture ignores queue events while in challenge mode", function()
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow, {
      isInChallengeMode = function()
        return true
      end,
    })

    controller.CaptureQueueJoinCandidate(1001, "invited")

    Assert.Equal(state.captures, 0, "challenge mode must skip queue candidate capture")
    Assert.Nil(state.pending, "challenge mode must not update pending queue target")
  end)
end
