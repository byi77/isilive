---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  local function BuildGroupController(overrides)
    overrides = overrides or {}
    local state = {
      wasInGroup = overrides.wasInGroup or false,
      wasRaidGroup = overrides.wasRaidGroup or false,
      roster = {},
      mainFrameVisible = false,
      prints = {},
      queued = 0,
      announced = 0,
      knownUsersCleared = 0,
      inspectResets = 0,
      uiUpdates = 0,
      teleportUpdates = 0,
    }

    local addon = LoadAddonModules({ "isiLive_group.lua" })
    local controller = addon.Group.CreateController({
      printFn = function(msg)
        table.insert(state.prints, tostring(msg))
      end,
      getL = overrides.getL or function()
        return { RAID_GROUP_HIDDEN = "Raid group detected (>5 members). Addon paused." }
      end,
      isInGroup = overrides.isInGroup or function()
        return true
      end,
      getNumGroupMembers = overrides.getNumGroupMembers or function()
        return 5
      end,
      getActiveChallengeMapID = overrides.getActiveChallengeMapID or function()
        return nil
      end,
      getWasInGroup = function()
        return state.wasInGroup
      end,
      setWasInGroup = function(value)
        state.wasInGroup = value
      end,
      getWasRaidGroup = function()
        return state.wasRaidGroup
      end,
      setWasRaidGroup = function(value)
        state.wasRaidGroup = value
      end,
      setWasGroupLeader = function(_value) end,
      getRoster = function()
        return state.roster
      end,
      setRoster = function(value)
        state.roster = value
      end,
      captureQueueJoinCandidate = function()
        state.queued = state.queued + 1
      end,
      announceQueuedGroupJoin = function()
        state.announced = state.announced + 1
      end,
      setMainFrameVisible = function(visible)
        state.mainFrameVisible = visible
      end,
      updateLeaderButtons = function() end,
      clearLatestQueueTarget = function() end,
      clearKnownUsers = function()
        state.knownUsersCleared = state.knownUsersCleared + 1
      end,
      resetInspectAll = function()
        state.inspectResets = state.inspectResets + 1
      end,
      resetInspectQueues = function() end,
      updateUI = function()
        state.uiUpdates = state.uiUpdates + 1
      end,
      updateMPlusTeleportButton = function()
        state.teleportUpdates = state.teleportUpdates + 1
      end,
      getUnitNameAndRealm = overrides.getUnitNameAndRealm or function(unit)
        if unit == "player" then return "TestPlayer", "TestRealm" end
        local idx = tonumber(unit:match("party(%d+)"))
        if idx then return "Party" .. idx, "Realm" .. idx end
        return nil, nil
      end,
      getUnitClass = overrides.getUnitClass or function(unit)
        if unit == "player" then return "Warrior", "WARRIOR" end
        return "Mage", "MAGE"
      end,
      getUnitServerLanguage = function(_unit, _realm)
        return "DE"
      end,
      getOwnedKeystoneSnapshot = function()
        return 2649, 15
      end,
      markIsiLiveUser = function() end,
      setPlayerKeyInfo = function() end,
      getUnitRole = function(_unit)
        return "DAMAGER"
      end,
      getPlayerSpecName = function()
        return "Arms"
      end,
      getUnitRio = function(_unit)
        return 3500
      end,
      unitHasIsiLive = function(_unit)
        return false
      end,
      applyKnownKeyToRosterEntry = function(_info)
        return false
      end,
      enqueueInspect = function(_unit) end,
      sendOwnKeySnapshot = function(_force) end,
      sendIsiLiveHello = function(_force) end,
    })

    return controller, state
  end

  test("Group join builds roster with player and 4 party members", function()
    local controller, state = BuildGroupController({
      getNumGroupMembers = function() return 5 end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.NotNil(state.roster.player, "player entry must exist in roster")
    Assert.Equal(state.roster.player.name, "TestPlayer", "player name must be set")
    Assert.Equal(state.roster.player.class, "WARRIOR", "player class must be set")
    Assert.Equal(state.roster.player.hasIsiLive, true, "player must be marked as isiLive user")
    Assert.NotNil(state.roster.party1, "party1 must exist")
    Assert.NotNil(state.roster.party4, "party4 must exist")
    Assert.True(state.mainFrameVisible, "main frame must be visible after group join")
  end)

  test("Group leave clears roster and hides frame", function()
    local controller, state = BuildGroupController({
      isInGroup = function() return false end,
      wasInGroup = true,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Nil(state.roster.player, "roster must be empty after leave")
    Assert.False(state.mainFrameVisible, "main frame must be hidden after leave")
    Assert.Equal(state.inspectResets, 1, "inspect queues must be reset on leave")
    Assert.Equal(state.knownUsersCleared, 1, "known users must be cleared on leave")
  end)

  test("Raid group hides frame and prints notification", function()
    local controller, state = BuildGroupController({
      getNumGroupMembers = function() return 6 end,
    })

    controller.HandleGroupRosterUpdate()
    controller.HandleGroupRosterUpdate()

    Assert.False(state.mainFrameVisible, "frame must be hidden for raid group")
    Assert.Equal(#state.prints, 1, "exactly one notification must be printed")
    Assert.True(
      state.prints[1]:find("Raid group") ~= nil,
      "notification must contain raid group message"
    )
  end)

  test("Raid notification prints again after leaving raid-size group", function()
    local members = 6
    local controller, state = BuildGroupController({
      getNumGroupMembers = function() return members end,
    })

    controller.HandleGroupRosterUpdate()
    members = 5
    controller.HandleGroupRosterUpdate()
    members = 6
    controller.HandleGroupRosterUpdate()

    Assert.Equal(#state.prints, 2, "raid notification should print again on fresh transition to raid size")
  end)

  test("First group join fires queue capture and announce", function()
    local controller, state = BuildGroupController({
      wasInGroup = false,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Equal(state.queued, 1, "queue capture must fire on first join")
    Assert.Equal(state.announced, 1, "queue announce must fire on first join")
  end)

  test("Active M+ key blocks roster rebuild", function()
    local controller, state = BuildGroupController({
      getActiveChallengeMapID = function() return 2649 end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Nil(state.roster.player, "roster must not rebuild during active M+")
    Assert.Equal(state.uiUpdates, 1, "UI should still update during active M+")
  end)

  test("Re-join after leave resets wasInGroup correctly", function()
    local controller, state = BuildGroupController({
      wasInGroup = false,
    })

    controller.HandleGroupRosterUpdate()
    Assert.True(state.wasInGroup, "wasInGroup must be true after join")
    Assert.Equal(state.queued, 1, "first join must capture queue")

    controller.HandleGroupRosterUpdate()
    Assert.Equal(state.queued, 1, "subsequent updates must not re-capture queue")
  end)

  test("Party members get correct roles and classes", function()
    local controller, state = BuildGroupController({
      getNumGroupMembers = function() return 3 end,
      getUnitClass = function(unit)
        if unit == "player" then return "Paladin", "PALADIN" end
        if unit == "party1" then return "Priest", "PRIEST" end
        if unit == "party2" then return "Rogue", "ROGUE" end
        return "Warrior", "WARRIOR"
      end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Equal(state.roster.player.class, "PALADIN", "player class must match")
    Assert.Equal(state.roster.party1.class, "PRIEST", "party1 class must match")
    Assert.Equal(state.roster.party2.class, "ROGUE", "party2 class must match")
  end)

  test("Group leave clears known isiLive users", function()
    local controller, state = BuildGroupController({
      isInGroup = function() return false end,
      wasInGroup = true,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Equal(state.knownUsersCleared, 1, "known users cache must be cleared on group leave")
  end)
end
