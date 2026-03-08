---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  local function BuildLeaderWatchController(overrides)
    overrides = overrides or {}
    local state = {
      isLeader = overrides.isLeader or false,
      wasGroupLeader = overrides.wasGroupLeader,
      prints = {},
      centerNotices = {},
      leaderButtonUpdates = 0,
      mainFrameShown = overrides.mainFrameShown ~= false,
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
        return state.mainFrameShown
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

  test("LeaderWatch silently tracks hidden leader changes and preserves next visible transition", function()
    local frameScript = nil

    WithGlobals({
      CreateFrame = function()
        return {
          RegisterEvent = function() end,
          SetScript = function(_, scriptType, script)
            if scriptType == "OnEvent" then
              frameScript = script
            end
          end,
        }
      end,
    }, function()
      local controller, state = BuildLeaderWatchController({
        wasGroupLeader = false,
        isLeader = true,
        mainFrameShown = false,
      })

      controller.Start()
      Assert.NotNil(frameScript, "LeaderWatch must register an OnEvent handler when started")

      frameScript(nil, "PARTY_LEADER_CHANGED")
      Assert.True(state.wasGroupLeader, "hidden leader change must still update cached leader state")
      Assert.Equal(#state.centerNotices, 0, "hidden leader change must not show a notice")
      Assert.Equal(#state.prints, 0, "hidden leader change must not print chat output")
      Assert.Equal(state.leaderButtonUpdates, 0, "hidden leader change must not refresh leader buttons")

      state.mainFrameShown = true
      state.isLeader = false
      frameScript(nil, "PARTY_LEADER_CHANGED")

      Assert.Equal(#state.prints, 1, "next visible leader loss must still be detected after hidden sync")
      Assert.False(state.wasGroupLeader, "visible transition after hidden sync must update cached leader state")
      Assert.Equal(state.leaderButtonUpdates, 1, "visible transition must refresh leader buttons exactly once")
    end)
  end)
end
