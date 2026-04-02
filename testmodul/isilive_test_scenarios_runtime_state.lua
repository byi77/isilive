local function RegisterRuntimeStateTests(test, Assert, LoadAddonModules)
  test("RuntimeState patches runtime flags and preserves unrelated state", function()
    local addon = LoadAddonModules({ "isiLive_runtime_state.lua" })
    local state = addon.RuntimeState.CreateController({
      isStopped = false,
      isPaused = false,
      isTestMode = false,
      isTestAllMode = false,
      wasGroupLeader = nil,
      roster = {
        player = { name = "Me" },
      },
    })

    state.PatchRuntimeFlags({
      isStopped = true,
      isTestMode = true,
      wasGroupLeader = "player",
    })

    local flags = state.GetRuntimeFlags()
    Assert.True(flags.isStopped, "PatchRuntimeFlags should update stop flag")
    Assert.False(flags.isPaused, "PatchRuntimeFlags should preserve unrelated pause flag")
    Assert.True(flags.isTestMode, "PatchRuntimeFlags should update test mode flag")
    Assert.False(flags.isTestAllMode, "PatchRuntimeFlags should preserve unrelated test-all flag")
    Assert.Equal(flags.wasGroupLeader, "player", "PatchRuntimeFlags should update leader token")
    Assert.Equal(state.GetRoster().player.name, "Me", "runtime flag patch must not replace roster state")
  end)

  test("RuntimeState latest queue clear can keep active joined key when requested", function()
    local addon = LoadAddonModules({ "isiLive_runtime_state.lua" })
    local state = addon.RuntimeState.CreateController({
      activeJoinedKeyMapID = 2441,
      latestQueueDungeonName = "Dungeon",
      latestQueueActivityID = 1001,
      latestQueueTeleportSpellID = 367416,
      latestQueueMapID = 2441,
    })

    state.ClearLatestQueueTarget({ keepActiveJoinedKey = true })

    local dungeonName, activityID, spellID, mapID = state.GetLatestQueueState()
    Assert.Nil(dungeonName, "queue clear should remove dungeon name")
    Assert.Nil(activityID, "queue clear should remove activity id")
    Assert.Nil(spellID, "queue clear should remove teleport spell id")
    Assert.Nil(mapID, "queue clear should remove queue map id")
    Assert.Equal(state.GetActiveJoinedKeyMapID(), 2441, "keepActiveJoinedKey must preserve joined key map id")
  end)

  test("RuntimeState rio baseline clear resets snapshot and delta flags", function()
    local addon = LoadAddonModules({ "isiLive_runtime_state.lua" })
    local state = addon.RuntimeState.CreateController({
      rioBaselineByPlayerKey = {
        ["alpha-realm"] = 2500,
      },
      isRioDeltaDisplayEnabled = true,
    })

    Assert.True(state.HasRioBaselineSnapshot(), "rio snapshot should be detected from initial baseline table")
    state.ClearRioBaseline()
    Assert.False(state.HasRioBaselineSnapshot(), "ClearRioBaseline should clear snapshot flag")
    Assert.False(state.IsRioDeltaDisplayEnabled(), "ClearRioBaseline should disable delta flag")
    Assert.Nil(next(state.GetRioBaselineByPlayerKey()), "ClearRioBaseline should clear baseline table")
  end)

  test("RuntimeState tracks ready-check hold expiry per unit", function()
    local addon = LoadAddonModules({ "isiLive_runtime_state.lua" })
    local state = addon.RuntimeState.CreateController({
      readyCheckReadyUntilByUnit = {
        party1 = 130,
      },
      readyCheckDeclinedUntilByUnit = {
        party1 = 120,
      },
    })

    Assert.Equal(state.GetReadyCheckReadyUntil("party1"), 130, "initial ready hold should be readable by unit")
    Assert.Equal(state.GetReadyCheckDeclinedUntil("party1"), 120, "initial declined hold should be readable by unit")
    state.SetReadyCheckReadyUntil("party2", 150)
    state.SetReadyCheckDeclinedUntil("party2", 140)
    Assert.Equal(state.GetReadyCheckReadyUntil("party2"), 150, "SetReadyCheckReadyUntil should store expiry")
    Assert.Equal(state.GetReadyCheckDeclinedUntil("party2"), 140, "SetReadyCheckDeclinedUntil should store expiry")
    Assert.False(state.ClearExpiredReadyCheckReady(129), "pre-expiry ready cleanup should not change state")
    Assert.True(state.ClearExpiredReadyCheckReady(130), "ready expiry cleanup should report a state change")
    Assert.Nil(state.GetReadyCheckReadyUntil("party1"), "expired ready hold should be cleared by cleanup")
    Assert.False(state.ClearExpiredReadyCheckDeclined(119), "pre-expiry cleanup should not change state")
    Assert.True(state.ClearExpiredReadyCheckDeclined(120), "expiry cleanup should report a state change")
    Assert.Nil(state.GetReadyCheckDeclinedUntil("party1"), "expired hold should be cleared by cleanup")
    state.ClearAllReadyCheckReady()
    state.ClearAllReadyCheckDeclined()
    Assert.Nil(state.GetReadyCheckReadyUntil("party2"), "ClearAllReadyCheckReady should wipe remaining ready holds")
    Assert.Nil(state.GetReadyCheckDeclinedUntil("party2"), "ClearAllReadyCheckDeclined should wipe remaining holds")
  end)
end

return function(test, ctx)
  RegisterRuntimeStateTests(test, ctx.assert, ctx.load_modules)
end
