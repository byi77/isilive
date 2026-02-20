---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  local function BuildLeaderWatchController(overrides)
    overrides = overrides or {}
    local state = {
      isLeader = overrides.isLeader or false,
      wasGroupLeader = overrides.wasGroupLeader,
      prints = {},
      centerNotices = {},
      leaderButtonUpdates = 0,
    }

    local addon = LoadAddonModules({ "isiLive_leader_watch.lua" })
    local controller = addon.LeaderWatch.CreateController({
      isPlayerLeader = function()
        return state.isLeader
      end,
      getWasGroupLeader = function()
        return state.wasGroupLeader
      end,
      setWasGroupLeader = function(value)
        state.wasGroupLeader = value
      end,
      isStopped = function()
        return false
      end,
      isMainFrameShown = function()
        return true
      end,
      showCenterNotice = function(message, duration)
        table.insert(state.centerNotices, { message = message, duration = duration })
      end,
      printFn = function(msg)
        table.insert(state.prints, tostring(msg))
      end,
      getL = function()
        return {
          LEAD_GAINED = "You are now the group leader.",
          LEAD_LOST = "You are no longer the group leader.",
          LEAD_TRANSFERRED_CENTER = "You are now the group leader!",
        }
      end,
      updateLeaderButtons = function()
        state.leaderButtonUpdates = state.leaderButtonUpdates + 1
      end,
    })

    return controller, state
  end

  test("LeaderWatch detects leader gain via PARTY_LEADER_CHANGED", function()
    local controller, state = BuildLeaderWatchController({
      wasGroupLeader = false,
      isLeader = true,
    })

    controller.UpdateLeaderState("PARTY_LEADER_CHANGED")

    Assert.Equal(#state.centerNotices, 1, "center notice must show on leader transfer")
    Assert.True(state.wasGroupLeader, "wasGroupLeader must be updated to true")
    Assert.Equal(state.leaderButtonUpdates, 1, "leader buttons must update")
  end)

  test("LeaderWatch detects leader loss", function()
    local controller, state = BuildLeaderWatchController({
      wasGroupLeader = true,
      isLeader = false,
    })

    controller.UpdateLeaderState("PARTY_LEADER_CHANGED")

    Assert.Equal(#state.prints, 1, "must print lead lost message")
    Assert.True(state.prints[1]:find("no longer") ~= nil, "message must mention losing lead")
    Assert.False(state.wasGroupLeader, "wasGroupLeader must be updated to false")
  end)

  test("LeaderWatch first check initializes state without notification", function()
    local controller, state = BuildLeaderWatchController({
      wasGroupLeader = nil,
      isLeader = true,
    })

    controller.UpdateLeaderState("GROUP_ROSTER_UPDATE")

    Assert.Equal(#state.prints, 0, "first check must not print")
    Assert.Equal(#state.centerNotices, 0, "first check must not show notice")
    Assert.True(state.wasGroupLeader, "wasGroupLeader must be initialized")
  end)
end
