---@diagnostic disable: undefined-global

-- Scenarios for the central runtime-profile resolver in
-- core/isiLive_runtime_mode.lua plus the two contracts that depend on it:
-- the raid hard-off at event-registration level, and the group chat / addon
-- sync channel resolution that must never answer PARTY inside an automatic
-- instance group.

local function BuildInstanceGlobals(instanceType, difficultyID, activeChallengeMapID)
  return {
    GetInstanceInfo = function()
      return "Instance", instanceType, difficultyID, nil, nil, nil, nil, 2000
    end,
    C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        return activeChallengeMapID
      end,
    },
    IsInRaid = function()
      return false
    end,
    IsInGroup = function(category)
      return category ~= 2
    end,
    GetNumGroupMembers = function()
      return 5
    end,
  }
end

local function NewEventFrameStub()
  local frame = {
    registered = {},
    unitRegistered = {},
  }

  function frame:RegisterEvent(event)
    self.registered[event] = true
  end

  function frame:RegisterUnitEvent(event, ...)
    self.registered[event] = true
    self.unitRegistered[event] = { ... }
  end

  function frame:UnregisterEvent(event)
    self.registered[event] = nil
  end

  return frame
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  local function ResolveIn(globals)
    local resolved = nil
    WithGlobals(globals, function()
      local addon = LoadAddonModules({})
      resolved = addon.RuntimeMode.Resolve()
    end)
    return resolved
  end

  test("RuntimeMode resolves OFF in a raid", function()
    local globals = BuildInstanceGlobals("party", 8, 559)
    globals.IsInRaid = function()
      return true
    end
    Assert.Equal(ResolveIn(globals), "OFF", "a raid must switch the addon off even inside a keystone")
  end)

  test("RuntimeMode resolves OFF for any group larger than five", function()
    local globals = BuildInstanceGlobals("party", 8, 559)
    globals.IsInGroup = function()
      return true
    end
    globals.GetNumGroupMembers = function()
      return 6
    end
    Assert.Equal(ResolveIn(globals), "OFF", "six players must switch the addon off")
  end)

  test("RuntimeMode resolves KEY for a running keystone", function()
    Assert.Equal(
      ResolveIn(BuildInstanceGlobals("party", 8, 559)),
      "KEY",
      "an active keystone must run the full profile"
    )
  end)

  test("RuntimeMode resolves KEY for mythic difficulty without an inserted keystone", function()
    -- difficultyID 23 covers both a genuine M0 run and a key dungeon whose
    -- keystone has not been inserted yet; the API cannot separate them.
    Assert.Equal(
      ResolveIn(BuildInstanceGlobals("party", 23, nil)),
      "KEY",
      "mythic difficulty must run the full profile so the key run-up stays covered"
    )
  end)

  test("RuntimeMode resolves IDLE for timewalking, normal and heroic dungeons", function()
    Assert.Equal(ResolveIn(BuildInstanceGlobals("party", 24, nil)), "IDLE", "timewalking must run the reduced profile")
    Assert.Equal(ResolveIn(BuildInstanceGlobals("party", 1, nil)), "IDLE", "normal must run the reduced profile")
    Assert.Equal(ResolveIn(BuildInstanceGlobals("party", 2, nil)), "IDLE", "heroic must run the reduced profile")
  end)

  test("RuntimeMode resolves IDLE outside instances and in non-party instances", function()
    Assert.Equal(ResolveIn(BuildInstanceGlobals("none", 0, nil)), "IDLE", "the open world must run the reduced profile")
    -- Torghast and delve-style content reports a scenario instance type.
    Assert.Equal(
      ResolveIn(BuildInstanceGlobals("scenario", 167, nil)),
      "IDLE",
      "scenario instances must run the reduced profile"
    )
  end)

  test("RuntimeMode separates an active challenge from the wider full profile", function()
    WithGlobals(BuildInstanceGlobals("party", 23, nil), function()
      local addon = LoadAddonModules({})
      Assert.True(addon.RuntimeMode.IsFullProfileContext(), "mythic difficulty must count as full profile")
      Assert.False(
        addon.RuntimeMode.IsActiveChallenge(),
        "M0 must not report an active challenge -- timer and forces stay bound to a real keystone"
      )
    end)
  end)

  test("RuntimeMode fails closed when instance data is unavailable", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({})
      Assert.False(addon.RuntimeMode.IsFullProfileContext(), "missing instance API must not grant the full profile")
      Assert.Equal(addon.RuntimeMode.Resolve(), "IDLE", "missing instance API must fall back to the reduced profile")
    end)
  end)

  test("RuntimeMode rejects secret instance metadata", function()
    local secret = {}
    local globals = BuildInstanceGlobals("party", 8, nil)
    globals.GetInstanceInfo = function()
      return "Instance", secret, 8, nil, nil, nil, nil, 2000
    end
    globals.issecretvalue = function(value)
      return value == secret
    end
    Assert.Equal(ResolveIn(globals), "IDLE", "secret instance metadata must not grant the full runtime profile")
  end)

  test("RuntimeMode keeps timewalking out of the full-profile difficulty table", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({})
      local difficultyIDs = addon.RuntimeMode.GetFullProfileDifficultyIDs()
      Assert.True(difficultyIDs[8], "an inserted keystone must stay in the full-profile table")
      Assert.True(difficultyIDs[23], "mythic difficulty must stay in the full-profile table")
      Assert.Nil(difficultyIDs[24], "timewalking must not be treated as mythic")
      Assert.Nil(difficultyIDs[1], "normal must not be treated as mythic")
      Assert.Nil(difficultyIDs[2], "heroic must not be treated as mythic")
    end)
  end)

  test("Sync channel resolution survives a missing party-category constant", function()
    -- Regression: without a numeric fallback the instance-group check is
    -- skipped, the resolver falls through to PARTY, and Blizzard rejects the
    -- send with ERR_NOT_IN_GROUP -- the player sees "you are not in a group"
    -- in an automatic instance group (LFG timewalking, dungeon finder).
    WithGlobals({
      IsInRaid = function()
        return false
      end,
      IsInGroup = function(category)
        return category == 2
      end,
      UnitInParty = function()
        return true
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      Assert.Equal(
        addon.Sync.GetAddonSyncChannel(),
        "INSTANCE_CHAT",
        "an instance group must resolve to INSTANCE_CHAT even without LE_PARTY_CATEGORY_INSTANCE"
      )
      Assert.Equal(
        addon.ContextHelpers.ResolveGroupChatChannel(),
        "INSTANCE_CHAT",
        "the visible chat channel must follow the same instance-group rule"
      )
    end)
  end)

  test("Sync channel resolution still answers PARTY for a verified home party", function()
    WithGlobals({
      IsInRaid = function()
        return false
      end,
      IsInGroup = function(category)
        return category ~= 2
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      Assert.Equal(addon.Sync.GetAddonSyncChannel(), "PARTY", "a home party must still resolve to PARTY")
      Assert.Equal(addon.ContextHelpers.ResolveGroupChatChannel(), "PARTY", "the visible chat channel must match")
    end)
  end)

  test("Raid suppression unregisters dispatcher events but keeps the wake-up events", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_bootstrap.lua" })
      local frame = NewEventFrameStub()
      addon.Bootstrap.RegisterDispatcherEvents(frame)

      Assert.True(frame.registered.UNIT_HEALTH, "UNIT_HEALTH must be registered before suppression")
      Assert.True(frame.registered.UNIT_AURA, "UNIT_AURA must be registered before suppression")

      Assert.True(addon.Bootstrap.ApplyRaidEventSuppression(true), "entering raid must change the suppression state")
      Assert.True(addon.Bootstrap.IsRaidEventSuppressionActive(), "suppression must be reported as active")

      Assert.Nil(frame.registered.UNIT_HEALTH, "the unfiltered UNIT_HEALTH traffic must stop in a raid")
      Assert.Nil(frame.registered.UNIT_AURA, "the unfiltered UNIT_AURA traffic must stop in a raid")
      Assert.Nil(frame.registered.CHAT_MSG_ADDON, "addon sync must stop in a raid")
      Assert.True(
        frame.registered.GROUP_ROSTER_UPDATE,
        "GROUP_ROSTER_UPDATE must survive: it is how the addon learns the raid ended"
      )
      Assert.True(frame.registered.PLAYER_ENTERING_WORLD, "PLAYER_ENTERING_WORLD must survive as the second wake-up")
    end)
  end)

  test("Raid suppression restores every event when the raid ends", function()
    local pendingCallbacks = {}
    WithGlobals({
      C_Timer = {
        After = function(_seconds, callback)
          table.insert(pendingCallbacks, callback)
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_bootstrap.lua" })
      local frame = NewEventFrameStub()
      addon.Bootstrap.RegisterDispatcherEvents(frame)
      addon.Bootstrap.ApplyRaidEventSuppression(true)

      Assert.True(addon.Bootstrap.ApplyRaidEventSuppression(false), "leaving raid must change the suppression state")
      Assert.False(addon.Bootstrap.IsRaidEventSuppressionActive(), "suppression must be reported as lifted")
      Assert.Equal(
        #pendingCallbacks,
        1,
        "re-registration must be deferred: RegisterEvent from a protected dispatch is forbidden in 12.0"
      )

      Assert.Nil(frame.registered.UNIT_HEALTH, "events must stay unregistered until the deferred callback runs")
      pendingCallbacks[1]()
      Assert.True(frame.registered.UNIT_HEALTH, "the deferred callback must restore UNIT_HEALTH")
      Assert.True(frame.registered.CHAT_MSG_ADDON, "the deferred callback must restore addon sync")
      Assert.NotNil(
        frame.unitRegistered.UNIT_SPELLCAST_SUCCEEDED,
        "unit-filtered events must be restored with their unit filter, not as plain events"
      )
    end)
  end)

  test("Raid suppression is idempotent", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_bootstrap.lua" })
      local frame = NewEventFrameStub()
      addon.Bootstrap.RegisterDispatcherEvents(frame)

      Assert.True(addon.Bootstrap.ApplyRaidEventSuppression(true), "first suppression must report a change")
      Assert.False(addon.Bootstrap.ApplyRaidEventSuppression(true), "repeated suppression must report no change")
    end)
  end)
end
