local function BuildHighlightController(addon, overrides)
  overrides = overrides or {}
  return addon.Highlight.CreateController({
    isInGroup = overrides.isInGroup or function()
      return true
    end,
    resolveTeleportSpellIDByMapID = overrides.resolveTeleportSpellIDByMapID or function(mapID)
      if mapID == 2441 or mapID == 2442 then
        return 367416
      end
      if mapID == 2662 then
        return 445414
      end
      return nil
    end,
    resolveMapIDByActivityID = overrides.resolveMapIDByActivityID or function(activityID)
      if activityID == 1001 then
        return 2442
      end
      if activityID == 1002 then
        return 2441
      end
      if activityID == 2001 then
        return 2662
      end
      return nil
    end,
  })
end

-- Location mocks keep the three Blizzard ID spaces apart: challenge-mode map
-- IDs (season data, activity resolver) resolve to instance IDs through the 6th
-- return of C_ChallengeMode.GetMapUIInfo, the player location is the 8th return
-- of GetInstanceInfo, and the UiMapID from C_Map.GetBestMapForUnit is a third
-- space that must never decide the "already inside" suppression (rule 193).
-- Ingame 2026-10-08, Murder Row: challenge 587 -> instance 2813, UiMapID 2433.
local INSTANCE_ID_BY_CHALLENGE_MAP_ID = {
  [587] = 2813,
  [2441] = 2649,
  [2442] = 2651,
  [2662] = 2660,
}

local function BuildLocationGlobals(location, overrides)
  local globals = {
    UnitExists = function(unit)
      return unit == "player"
    end,
    C_Map = {
      GetBestMapForUnit = function(_unit)
        return location.uiMapID
      end,
    },
    GetInstanceInfo = function()
      return "Instance", location.instanceType or "none", 0, "", 5, 0, false, location.instanceID, 0, 0, nil, nil
    end,
    C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        return location.activeChallengeMapID
      end,
      GetMapUIInfo = function(challengeMapID)
        local instanceID = INSTANCE_ID_BY_CHALLENGE_MAP_ID[challengeMapID]
        if not instanceID then
          return nil
        end
        return "Dungeon", challengeMapID, 1800, nil, nil, instanceID
      end,
    },
    C_LFGList = {
      GetActiveEntryInfo = function()
        return location.activeEntry
      end,
    },
  }
  for key, value in pairs(overrides or {}) do
    globals[key] = value
  end
  return globals
end

local function MovePlayerInto(location, challengeMapID)
  location.instanceType = "party"
  location.instanceID = INSTANCE_ID_BY_CHALLENGE_MAP_ID[challengeMapID]
end

local function BuildMurderRowController(addon)
  return BuildHighlightController(addon, {
    resolveTeleportSpellIDByMapID = function(mapID)
      return mapID == 587 and 1286809 or nil
    end,
    resolveMapIDByActivityID = function(activityID)
      return activityID == 1950 and 587 or nil
    end,
  })
end

local function RegisterHighlightActiveAndQueueTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  test("Highlight keeps active listing for shared spell when map is different", function()
    local location = { activeEntry = { active = true, mapID = 2442 } }

    WithGlobals(BuildLocationGlobals(location), function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = BuildHighlightController(addon)

      MovePlayerInto(location, 2441)
      local differentMapSpell = controller.ResolveActiveTeleportSpellID(nil, nil)
      Assert.Equal(differentMapSpell, 367416, "shared spell should stay highlighted on sibling map")

      MovePlayerInto(location, 2442)
      local exactMapSpell = controller.ResolveActiveTeleportSpellID(nil, nil)
      Assert.Nil(exactMapSpell, "shared spell should clear on exact listing map")
    end)
  end)

  test("Highlight queue path uses exact-map suppression for shared spell", function()
    local location = {}

    WithGlobals(BuildLocationGlobals(location), function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = BuildHighlightController(addon)

      MovePlayerInto(location, 2441)
      local differentMapSpell = controller.ResolveActiveTeleportSpellID(1001, nil)
      Assert.Equal(differentMapSpell, 367416, "queue shared spell should stay highlighted on sibling map")

      MovePlayerInto(location, 2442)
      local exactMapSpell = controller.ResolveActiveTeleportSpellID(1001, nil)
      Assert.Nil(exactMapSpell, "queue shared spell should clear on exact target map")
    end)
  end)

  -- COMPONENT-ONLY: the highlight resolver is reached in production through
  -- the teleport-button refresh of the frame bridge; the real Highlight
  -- controller is driven here with the real Validators location helpers and
  -- only the Blizzard globals mocked.
  test("Highlight suppresses the Murder Row teleport only inside instance 2813", function()
    local location = { instanceType = "none", uiMapID = 2393 }

    WithGlobals(BuildLocationGlobals(location), function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = BuildMurderRowController(addon)

      Assert.Equal(controller.ResolveActiveTeleportSpellID(1950, nil), 1286809, "outside: queue teleport stays")

      location.instanceType = "party"
      location.instanceID = 2813
      location.uiMapID = 2433
      Assert.Nil(controller.ResolveActiveTeleportSpellID(1950, nil), "inside instance 2813: queue teleport clears")
      location.activeEntry = { active = true, mapID = 587 }
      Assert.Nil(controller.ResolveActiveTeleportSpellID(nil, nil), "inside instance 2813: listing teleport clears")

      location.instanceType = "scenario"
      Assert.Equal(
        controller.ResolveActiveTeleportSpellID(nil, nil),
        1286809,
        "a non-party instance with the same instance ID must not suppress the teleport"
      )
    end)
  end)

  test("Highlight ignores a player UiMapID that collides with the target challenge map ID", function()
    local location = { instanceType = "none", instanceID = 2552, uiMapID = 587 }

    WithGlobals(BuildLocationGlobals(location), function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = BuildMurderRowController(addon)

      Assert.Equal(
        controller.ResolveActiveTeleportSpellID(1950, nil),
        1286809,
        "a UiMapID equal to the challenge map ID must not suppress the queue teleport"
      )
      location.activeEntry = { active = true, mapID = 587 }
      Assert.Equal(
        controller.ResolveActiveTeleportSpellID(nil, nil),
        1286809,
        "a UiMapID equal to the challenge map ID must not suppress the listing teleport"
      )
    end)
  end)

  test("Highlight keeps the teleport when the instance APIs are missing or masked", function()
    local secret, secretGlobals = Fixtures.MakeStrictSecret("number")

    local function RunCase(overrides, reason)
      local location = { uiMapID = 2433 }
      MovePlayerInto(location, 587)
      WithGlobals(BuildLocationGlobals(location, overrides), function()
        local addon = LoadAddonModules({ "isiLive_highlight.lua" })
        local controller = BuildMurderRowController(addon)
        Assert.Equal(controller.ResolveActiveTeleportSpellID(1950, nil), 1286809, reason)
      end)
    end

    RunCase({ C_ChallengeMode = {} }, "missing GetMapUIInfo must keep the teleport")
    RunCase({ GetInstanceInfo = false }, "missing GetInstanceInfo must keep the teleport")
    RunCase({
      C_ChallengeMode = {
        GetMapUIInfo = function()
          error("map ui info unavailable")
        end,
      },
    }, "a failing GetMapUIInfo must keep the teleport")
    RunCase({
      issecretvalue = secretGlobals.issecretvalue,
      type = secretGlobals.type,
      C_ChallengeMode = {
        GetMapUIInfo = function()
          return "Murder Row", 587, 1800, nil, nil, secret
        end,
      },
    }, "a masked challenge map instance ID must keep the teleport")
    RunCase({
      issecretvalue = secretGlobals.issecretvalue,
      type = secretGlobals.type,
      GetInstanceInfo = function()
        return "Murder Row", "party", 8, "", 5, 0, false, secret, 0, 0, nil, nil
      end,
    }, "a masked player instance ID must keep the teleport")
  end)

  test("Highlight joined-key resolver requires activity-based map context", function()
    local addon = LoadAddonModules({ "isiLive_highlight.lua" })
    local controller = BuildHighlightController(addon)

    local fromActivity = controller.ResolveJoinedKeyMapID(2001, nil)
    Assert.Equal(fromActivity, 2662, "joined-key map should resolve from activity")

    local spellOnly = controller.ResolveJoinedKeyMapID(nil, 445414)
    Assert.Nil(spellOnly, "joined-key map must stay nil for spell-only context")
  end)
end

local function RegisterHighlightNormalizationTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Highlight treats struct-based inactive listing correctly when active=false in C_LFGList response", function()
    WithGlobals({
      C_LFGList = {
        GetActiveEntryInfo = function()
          return { active = false, mapID = 2441 }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = BuildHighlightController(addon)

      local entry = controller.GetNormalizedActiveEntryInfo()
      Assert.NotNil(entry, "entry info should be present even when inactive")
      Assert.Equal(entry.active, false, "struct active=false must propagate through TryGet normalization")

      local spellID = controller.ResolveActiveListingTeleportSpellID(entry)
      Assert.Nil(spellID, "inactive struct listing must not produce active highlight spell")
    end)
  end)

  test("Highlight normalizes active-entry tables with activityIDs fallback", function()
    WithGlobals({
      C_LFGList = {
        GetActiveEntryInfo = function()
          return {
            active = true,
            mapId = 2441,
            activityIDs = { "skip", 1001 },
            listingName = "Queue Listing",
          }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = BuildHighlightController(addon)
      local entry = controller.GetNormalizedActiveEntryInfo()

      Assert.NotNil(entry, "normalized entry should exist")
      Assert.Equal(entry.activityID, 1001, "activityIDs fallback should pick first numeric candidate")
      Assert.Equal(entry.mapID, 2441, "mapId alias should normalize to mapID")
      Assert.Equal(entry.name, "Queue Listing", "listing name alias should normalize")
    end)
  end)

  test("Highlight active-listing resolver respects explicit inactive state", function()
    local addon = LoadAddonModules({ "isiLive_highlight.lua" })
    local controller = BuildHighlightController(addon)

    local spellID = controller.ResolveActiveListingTeleportSpellID({
      active = false,
      mapID = 2441,
      activityID = 1001,
    })
    Assert.Nil(spellID, "inactive listing must not produce active highlight spell")
  end)

  test("Highlight queue fallback is disabled while not in group", function()
    WithGlobals({
      UnitExists = function(unit)
        return unit == "player"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
      C_Map = {
        GetBestMapForUnit = function(_unit)
          return 2662
        end,
      },
      C_LFGList = {
        GetActiveEntryInfo = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = BuildHighlightController(addon, {
        isInGroup = function()
          return false
        end,
      })

      local spellID = controller.ResolveActiveTeleportSpellID(1001, nil)
      Assert.Nil(spellID, "queue-derived highlight should be blocked while player is not in group")
    end)
  end)

  test("Highlight never reads the player UiMapID", function()
    local mapCalls = 0
    local location = { activeEntry = { active = true, mapID = 2442 } }

    WithGlobals(
      BuildLocationGlobals(location, {
        C_Map = {
          GetBestMapForUnit = function(_unit)
            mapCalls = mapCalls + 1
            error("GetBestMapForUnit must not decide the highlight suppression")
          end,
        },
      }),
      function()
        local addon = LoadAddonModules({ "isiLive_highlight.lua" })
        local controller = BuildHighlightController(addon)

        local spellID = controller.ResolveActiveTeleportSpellID(nil, nil)
        Assert.Equal(spellID, 367416, "outside an instance the listing teleport must stay")
      end
    )

    Assert.Equal(mapCalls, 0, "highlight must not query the player UiMapID")
  end)

  test("Highlight queue path ignores active challenge map before actual dungeon entry", function()
    local location = { instanceType = "none", uiMapID = 2441, activeChallengeMapID = 2442 }

    WithGlobals(BuildLocationGlobals(location), function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = BuildHighlightController(addon)

      local spellID = controller.ResolveActiveTeleportSpellID(1001, nil)
      Assert.Equal(
        spellID,
        367416,
        "active challenge map must not suppress the pre-entry queue highlight while the player is still outside"
      )
    end)
  end)
end

local function RegisterHighlightResolverTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Highlight listing resolver requires unique activity map", function()
    local addon = LoadAddonModules({ "isiLive_highlight.lua" })
    local controller = BuildHighlightController(addon, {
      resolveMapIDByActivityID = function(activityID)
        if activityID == 1001 then
          return 2441
        end
        if activityID == 1002 then
          return 2662
        end
        return nil
      end,
    })

    local ambiguous = controller.ResolveActiveListingTeleportSpellID({
      active = true,
      activityIDs = { 1001, 1002 },
    })
    Assert.Nil(ambiguous, "ambiguous activity map sets must not produce a highlight")

    local unique = controller.ResolveActiveListingTeleportSpellID({
      active = true,
      activityIDs = { 1001 },
    })
    Assert.Equal(unique, 367416, "unique activity map should produce deterministic highlight")
  end)

  test("Highlight listing resolver rejects partially unresolved activity maps", function()
    local addon = LoadAddonModules({ "isiLive_highlight.lua" })
    local controller = BuildHighlightController(addon, {
      resolveMapIDByActivityID = function(activityID)
        if activityID == 1001 then
          return 2441
        end
        return nil
      end,
    })

    local partiallyUnresolved = controller.ResolveActiveListingTeleportSpellID({
      active = true,
      activityIDs = { 1001, 9999 },
    })
    Assert.Nil(partiallyUnresolved, "partially unresolved activity map sets must not produce a highlight")
  end)

  test("Highlight map resolver does not bypass injected resolver with direct API fallback", function()
    WithGlobals({
      C_LFGList = {
        GetActivityInfoTable = function(_activityID)
          return { mapID = 2662 }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = BuildHighlightController(addon, {
        resolveMapIDByActivityID = function(_activityID)
          return nil
        end,
      })

      local mapID = controller.ResolveMapIDFromActivityID(2001)
      Assert.Nil(mapID, "highlight must not bypass strict resolver with direct C_LFGList fallback")
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules
  local Fixtures = ctx.fixtures

  RegisterHighlightActiveAndQueueTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterHighlightNormalizationTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterHighlightResolverTests(test, Assert, WithGlobals, LoadAddonModules)
end
