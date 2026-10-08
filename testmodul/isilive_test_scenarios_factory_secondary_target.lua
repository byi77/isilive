-- Ingame values recorded 2026-10-08 in Murder Row: the challenge-mode map ID
-- (season data, ResolveStatusTargetMapID) is 587, the instance ID
-- (8th return of GetInstanceInfo, 6th return of C_ChallengeMode.GetMapUIInfo)
-- is 2813 and the UiMapID (C_Map.GetBestMapForUnit) is 2433. The three IDs
-- live in separate ID spaces; the mocks below keep them separate on purpose.
local MURDER_ROW_CHALLENGE_MAP_ID = 587
local MURDER_ROW_INSTANCE_ID = 2813
local MURDER_ROW_UI_MAP_ID = 2433

local function BuildDungeonGlobals(location, overrides)
  overrides = overrides or {}
  local globals = {
    UnitExists = function()
      return true
    end,
    C_Map = {
      GetBestMapForUnit = function()
        return location.uiMapID
      end,
    },
    GetInstanceInfo = function()
      return location.instanceName or "Instance",
        location.instanceType or "none",
        location.difficultyID or 0,
        "",
        5,
        0,
        false,
        location.instanceID,
        0,
        0,
        nil,
        nil
    end,
    C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        return location.activeChallengeMapID
      end,
      GetMapUIInfo = function(challengeMapID)
        if challengeMapID == MURDER_ROW_CHALLENGE_MAP_ID then
          return "Murder Row", MURDER_ROW_CHALLENGE_MAP_ID, 1800, nil, nil, MURDER_ROW_INSTANCE_ID
        end
        return nil
      end,
    },
  }
  for key, value in pairs(overrides) do
    globals[key] = value
  end
  return globals
end

local function InsideMurderRow()
  return {
    instanceName = "Murder Row",
    instanceType = "party",
    difficultyID = 8,
    instanceID = MURDER_ROW_INSTANCE_ID,
    uiMapID = MURDER_ROW_UI_MAP_ID,
    activeChallengeMapID = MURDER_ROW_CHALLENGE_MAP_ID,
  }
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules
  local Fixtures = ctx.fixtures

  ---@diagnostic disable-next-line: undefined-global
  local chunk, loadErr = loadfile("testmodul/isilive_test_scenarios_factory_secondary.lua")
  if not chunk then
    error(string.format("cannot load factory secondary scenario helper: %s", tostring(loadErr)))
  end

  local helperAddon = {}
  local ok, runErr = pcall(chunk, "isiLive", helperAddon)
  if not ok then
    error(string.format("cannot execute factory secondary scenario helper: %s", tostring(runErr)))
  end

  local factorySecondaryTests = helperAddon._FactorySecondaryTests or {}
  local BuildFactorySecondaryControllerState = factorySecondaryTests.BuildFactorySecondaryControllerState
  if type(BuildFactorySecondaryControllerState) ~= "function" then
    error("Factory secondary test helper is unavailable")
  end

  -- Builds the real factory secondary context with the real
  -- CheckIfEnteredTargetDungeon and wires it into the real event-handler
  -- controller, so every check below enters through controller:Dispatch.
  local function BuildTargetDungeonScenario()
    local calls = { clear = 0, queueClear = 0, teleport = 0 }
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = true,
    })

    state.ctx.addonTable.LFGDetect = {
      ClearAllState = function()
        calls.clear = calls.clear + 1
      end,
    }
    state.ctx.ResolveStatusTargetMapID = function()
      return MURDER_ROW_CHALLENGE_MAP_ID
    end
    state.ctx.ClearLatestQueueTarget = function()
      calls.queueClear = calls.queueClear + 1
    end
    state.ctx.UpdateMPlusTeleportButton = function()
      calls.teleport = calls.teleport + 1
    end

    local handlersAddon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(handlersAddon.EventHandlers, { value = nil }, {}, {
      checkIfEnteredTargetDungeon = state.ctx.CheckIfEnteredTargetDungeon,
    })
    return state, controller, calls
  end

  local function AssertNoMatch(calls, reason)
    Assert.Equal(calls.clear, 0, reason .. " must not clear the LFG detect state")
    Assert.Equal(calls.queueClear, 0, reason .. " must not clear the latest queue target")
    Assert.Equal(calls.teleport, 0, reason .. " must not refresh the teleport button")
  end

  -- Name pinned by rule 8; the scenario now checks instance IDs (rule 193).
  test("Factory target dungeon clear waits for actual player map entry", function()
    local _, controller, calls = BuildTargetDungeonScenario()
    local location = {
      instanceType = "none",
      uiMapID = 2393,
      activeChallengeMapID = MURDER_ROW_CHALLENGE_MAP_ID,
    }

    WithGlobals(BuildDungeonGlobals(location), function()
      controller:Dispatch("ZONE_CHANGED_NEW_AREA")
      AssertNoMatch(calls, "an active challenge map outside the dungeon")

      local inside = InsideMurderRow()
      for key, value in pairs(inside) do
        location[key] = value
      end
      controller:Dispatch("ZONE_CHANGED_NEW_AREA")
      Assert.Equal(calls.clear, 1, "entering the target instance must clear the LFG detect state once")
      Assert.Equal(calls.queueClear, 1, "entering the target instance must clear the latest queue target once")
      Assert.Equal(calls.teleport, 1, "entering the target instance must refresh the teleport button once")
    end)
  end)

  test(
    "Factory target dungeon clear fires on PLAYER_ENTERING_WORLD and CHALLENGE_MODE_START inside the dungeon",
    function()
      local _, controller, calls = BuildTargetDungeonScenario()

      WithGlobals(BuildDungeonGlobals(InsideMurderRow()), function()
        controller:Dispatch("PLAYER_ENTERING_WORLD")
        Assert.Equal(calls.clear, 1, "PLAYER_ENTERING_WORLD inside the target instance must clear the target")
        controller:Dispatch("CHALLENGE_MODE_START")
        Assert.Equal(calls.clear, 2, "CHALLENGE_MODE_START inside the target instance must clear the target")
        Assert.Equal(calls.queueClear, 2, "both events must clear the latest queue target")
        Assert.Equal(calls.teleport, 2, "both events must refresh the teleport button")
      end)
    end
  )

  test("Factory target dungeon check ignores a UiMapID that collides with the challenge map ID", function()
    local _, controller, calls = BuildTargetDungeonScenario()
    local location = {
      instanceType = "none",
      instanceID = 2552,
      uiMapID = MURDER_ROW_CHALLENGE_MAP_ID,
    }

    WithGlobals(BuildDungeonGlobals(location), function()
      controller:Dispatch("ZONE_CHANGED_NEW_AREA")
      AssertNoMatch(calls, "a zone whose UiMapID equals the challenge map ID")
    end)
  end)

  test("Factory target dungeon check requires a party instance", function()
    local _, controller, calls = BuildTargetDungeonScenario()
    local location = InsideMurderRow()
    location.instanceType = "scenario"

    WithGlobals(BuildDungeonGlobals(location), function()
      controller:Dispatch("ZONE_CHANGED_NEW_AREA")
      AssertNoMatch(calls, "a non-party instance with the target instance ID")
    end)
  end)

  test("Factory target dungeon check fails closed when the instance APIs are missing or masked", function()
    local secret, secretGlobals = Fixtures.MakeStrictSecret("number")

    local function RunCase(overrides, reason)
      local _, controller, calls = BuildTargetDungeonScenario()
      WithGlobals(BuildDungeonGlobals(InsideMurderRow(), overrides), function()
        controller:Dispatch("ZONE_CHANGED_NEW_AREA")
        AssertNoMatch(calls, reason)
      end)
    end

    RunCase({
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return MURDER_ROW_CHALLENGE_MAP_ID
        end,
      },
    }, "a missing C_ChallengeMode.GetMapUIInfo")
    RunCase({
      C_ChallengeMode = {
        GetMapUIInfo = function()
          error("map ui info unavailable")
        end,
      },
    }, "a failing C_ChallengeMode.GetMapUIInfo")
    RunCase({ GetInstanceInfo = false }, "a missing GetInstanceInfo")
    RunCase({
      issecretvalue = secretGlobals.issecretvalue,
      type = secretGlobals.type,
      C_ChallengeMode = {
        GetMapUIInfo = function()
          return "Murder Row", MURDER_ROW_CHALLENGE_MAP_ID, 1800, nil, nil, secret
        end,
      },
    }, "a masked challenge map instance ID")
    RunCase({
      issecretvalue = secretGlobals.issecretvalue,
      type = secretGlobals.type,
      GetInstanceInfo = function()
        return "Murder Row", "party", 8, "", 5, 0, false, secret, 0, 0, nil, nil
      end,
    }, "a masked player instance ID")
  end)
end
