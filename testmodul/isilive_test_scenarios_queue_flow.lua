return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules
  local Fixtures = ctx.fixtures

  test("QueueFlow strict resolver is robust when activity API errors", function()
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
        resolveSeason3MapIDByActivityID = function(activityID)
          local info = C_LFGList.GetActivityInfoTable(activityID)
          return info and info.mapID or nil
        end,
        queueCaptureQueueJoinCandidate = function(_updatePendingQueueJoin, strictResolver, ...)
          local ok, value = pcall(strictResolver, 777, ...)
          callbackChecked = true
          callbackOk = ok
          callbackValue = value
        end,
      })

      controller.CaptureQueueJoinCandidate("dummy")
    end)

    Assert.True(callbackChecked, "queue capture callback must run")
    Assert.True(callbackOk, "permissive resolver must not raise on API failure")
    Assert.Nil(callbackValue, "strict resolver should return nil on API failure")
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

  test("QueueFlow update does not carry forward stale target for same group", function()
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow, {
      resolveSeason3MapIDByActivityID = function(_activityID)
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
    Assert.Nil(state.pending.dungeonName, "same-group updates must not carry old dungeon")
    Assert.Nil(state.pending.activityID, "same-group updates must not carry old activityID")
    Assert.Nil(state.pending.mapID, "same-group updates must not carry old mapID")
    Assert.Nil(state.pending.teleportSpellID, "same-group updates must not carry old teleport spell")
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
    Assert.Equal(state.queueTargets[1].mapID, 2441, "preview should resolve target mapID from activity")
    Assert.Equal(#state.centerNotices, 0, "member announce should not show center notice")
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

  test("QueueFlow capture announces immediately when candidate arrives after group join", function()
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow, {
      isInGroup = function()
        return true
      end,
      queueCaptureQueueJoinCandidate = function(updatePendingQueueJoin, _strictResolver, _activityID, _status)
        updatePendingQueueJoin("Late Group", "Late Dungeon", 2, 1001)
      end,
    })

    controller.CaptureQueueJoinCandidate(1001, "accepted")

    Assert.Nil(state.pending, "late grouped capture should be consumed by immediate announce")
    Assert.Equal(#state.queueTargets, 1, "late grouped capture should set queue target")
    Assert.Equal(state.queueTargets[1].activityID, 1001, "late grouped capture should keep activityID")
    Assert.Equal(state.queueTargets[1].mapID, 2441, "late grouped capture should resolve mapID")
    Assert.Equal(state.queueTargets[1].spellID, 367416, "late grouped capture should resolve spellID")
    Assert.Equal(#state.centerNotices, 0, "late grouped capture should not show center notice")
    Assert.True(#state.prints >= 3, "late grouped capture should print chat summary lines")
  end)

  test("QueueFlow deduplicates repeated grouped announce for same target", function()
    local now = 100
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow, {
      isInGroup = function()
        return true
      end,
      getTimeFn = function()
        return now
      end,
      queueCaptureQueueJoinCandidate = function(updatePendingQueueJoin, _strictResolver, _activityID, _status)
        updatePendingQueueJoin("Spam Group", "Spam Dungeon", 2, 1001)
      end,
    })

    controller.CaptureQueueJoinCandidate(1001, "accepted")
    now = now + 5
    controller.CaptureQueueJoinCandidate(1001, "accepted")

    Assert.Equal(#state.queueTargets, 1, "same grouped target should not be re-announced repeatedly")
    Assert.Equal(#state.centerNotices, 0, "same grouped target should not show center notice")
    Assert.True(#state.prints >= 3, "first grouped capture should still print queue summary")
    Assert.True(#state.prints < 6, "second grouped capture should not duplicate chat summary")
  end)

  test("QueueFlow deduplicates grouped announce by stable queue event ID", function()
    local now = 100
    local captureIndex = 0
    local addon = LoadAddonModules({ "isiLive_queue_flow.lua" })
    local controller, state = Fixtures.BuildQueueFlowController(addon.QueueFlow, {
      isInGroup = function()
        return true
      end,
      getTimeFn = function()
        return now
      end,
      queueCaptureQueueJoinCandidate = function(updatePendingQueueJoin, _strictResolver, _activityID, _status)
        captureIndex = captureIndex + 1
        local groupName = captureIndex == 1 and "Stable Group A" or "Stable Group B"
        local dungeonName = captureIndex == 1 and "Stable Dungeon A" or "Stable Dungeon B"
        updatePendingQueueJoin(groupName, dungeonName, 2, 1001, {
          stableQueueEventID = "search:901",
        })
      end,
    })

    controller.CaptureQueueJoinCandidate(1001, "accepted")
    now = now + 5
    controller.CaptureQueueJoinCandidate(1001, "accepted")

    Assert.Equal(
      #state.queueTargets,
      1,
      "same stable queue event ID should suppress re-announce even with changed display text"
    )
    Assert.True(#state.prints >= 3, "first grouped capture should still print queue summary")
    Assert.True(#state.prints < 6, "second grouped capture should not duplicate chat summary")
  end)
end
