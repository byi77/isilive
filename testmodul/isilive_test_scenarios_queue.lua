return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Queue prefers concrete teleport-mapped activity over generic candidate", function()
    WithGlobals({
      C_LFGList = {
        GetActivityInfoTable = function(activityID)
          if activityID == 200 then
            return { mapID = 2441, isMythicPlusActivity = true, categoryID = 2 }
          end
          if activityID == 201 then
            return { mapID = 2442, isMythicPlusActivity = true, categoryID = 2 }
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_queue.lua" })
      local result = {
        activityID = 200,
        activityIDs = { 201 },
      }

      local resolvedID = addon.Queue.GetSearchResultActivityID(result, function(activityID)
        if activityID == 201 then
          return 367416
        end
        if activityID == 200 then
          return true
        end
        return nil
      end)

      Assert.Equal(resolvedID, 201, "queue candidate resolution must prefer concrete mapping")
    end)
  end)

  test("Queue does not guess first candidate when no concrete map is available", function()
    WithGlobals({
      C_LFGList = {
        GetActivityInfoTable = function(_activityID)
          return { isMythicPlusActivity = true, categoryID = 2 }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_queue.lua" })
      local result = {
        activityID = 9001,
        activityIDs = { 9002 },
      }

      local resolvedID = addon.Queue.GetSearchResultActivityID(result, function(_activityID)
        return nil
      end)

      Assert.Nil(resolvedID, "queue activity should remain unresolved without concrete map context")
    end)
  end)

  test("Queue activity name lookup is protected against API errors", function()
    WithGlobals({
      C_LFGList = {
        GetActivityInfoTable = function(_activityID)
          error("simulated api failure")
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_queue.lua" })
      local name = addon.Queue.GetActivityName(123)
      Assert.Nil(name, "activity name lookup should not crash on API failure")
    end)
  end)

  test("Queue.ParseApplicationStatus handles string states", function()
    local addon = LoadAddonModules({ "isiLive_queue.lua" })

    local invitedLike, invitedAccepted = addon.Queue.ParseApplicationStatus("invited")
    Assert.True(invitedLike, "invited string must be invite-like")
    Assert.False(invitedAccepted, "invited string must not be accepted")

    local acceptedLike, acceptedState = addon.Queue.ParseApplicationStatus("accepted")
    Assert.True(acceptedLike, "accepted string must be invite-like")
    Assert.True(acceptedState, "accepted string must be accepted")
  end)

  test("Queue.ParseApplicationStatus handles enum states", function()
    WithGlobals({
      Enum = {
        LFGListApplicationStatus = {
          InviteDeclined = 2,
          InviteAccepted = 3,
        },
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_queue.lua" })

      local inviteLike, accepted = addon.Queue.ParseApplicationStatus(2)
      Assert.True(inviteLike, "invite enum must be invite-like")
      Assert.False(accepted, "decline enum must not be accepted")

      local acceptedLike, acceptedState = addon.Queue.ParseApplicationStatus(3)
      Assert.True(acceptedLike, "accepted enum must be invite-like")
      Assert.True(acceptedState, "accepted enum must be accepted")
    end)
  end)

  test("Queue capture ignores pending application updates", function()
    local applied = 0

    WithGlobals({
      C_LFGList = {
        GetActivityInfoTable = function(activityID)
          if activityID == 777 then
            return { fullName = "Dungeon 777", mapID = 2441, isMythicPlusActivity = true }
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_queue.lua" })
      addon.Queue.CaptureQueueJoinCandidate(function(_groupName, _dungeonName, _priority, _activityID)
        applied = applied + 1
      end, function(_activityID)
        return nil
      end, {
        applicationStatus = "invited",
        pendingStatus = "applied",
        groupName = "Pending Group",
        activityID = 777,
      })
    end)

    Assert.Equal(applied, 0, "pending updates must not set queue target")
  end)

  test("Queue capture deduplicates duplicate apply signatures", function()
    local applied = 0

    WithGlobals({
      GetTime = function()
        return 100
      end,
      C_LFGList = {
        GetActivityInfoTable = function(activityID)
          if activityID == 778 then
            return { fullName = "Dungeon 778", mapID = 2442, isMythicPlusActivity = true }
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_queue.lua" })
      local payload = {
        applicationStatus = "accepted",
        groupName = "Dedup Group",
        activityID = 778,
      }

      addon.Queue.CaptureQueueJoinCandidate(function(_groupName, _dungeonName, _priority, _activityID)
        applied = applied + 1
      end, function(_activityID)
        return nil
      end, payload)

      addon.Queue.CaptureQueueJoinCandidate(function(_groupName, _dungeonName, _priority, _activityID)
        applied = applied + 1
      end, function(_activityID)
        return nil
      end, payload)
    end)

    Assert.Equal(applied, 1, "duplicate queue apply events within debounce window must be ignored")
  end)

  test("Queue capture resolves numeric values via search-result info", function()
    local applied = nil

    WithGlobals({
      C_LFGList = {
        GetActivityInfoTable = function(activityID)
          if activityID == 310 then
            return { fullName = "Floodgate", mapID = 2773, isMythicPlusActivity = true }
          end
          return nil
        end,
        GetSearchResultInfo = function(searchResultID)
          if searchResultID == 900 then
            return {
              name = "Result Group",
              activityIDs = { 310 },
            }
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_queue.lua" })
      addon.Queue.CaptureQueueJoinCandidate(function(groupName, dungeonName, priority, activityID)
        applied = {
          groupName = groupName,
          dungeonName = dungeonName,
          priority = priority,
          activityID = activityID,
        }
      end, function(activityID)
        if activityID == 310 then
          return 1216786
        end
        return nil
      end, 900, "invited")
    end)

    Assert.NotNil(applied, "numeric search result IDs must resolve to a concrete apply")
    Assert.Equal(applied.groupName, "Result Group", "resolved search result group name must be used")
    Assert.Equal(applied.activityID, 310, "resolved activityID must come from search result payload")
    Assert.Equal(applied.dungeonName, "Floodgate", "resolved activity name must be used for hint text")
    Assert.Equal(applied.priority, 1, "invited (not accepted) should use priority 1")
  end)
end
