return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function BuildHighlightController(addon, overrides)
    overrides = overrides or {}
    return addon.Highlight.CreateController({
      isInGroup = overrides.isInGroup or function()
        return true
      end,
      resolveSeason3TeleportSpellIDByMapID = overrides.resolveSeason3TeleportSpellIDByMapID or function(mapID)
        if mapID == 2441 or mapID == 2442 then
          return 367416
        end
        if mapID == 2662 then
          return 445414
        end
        return nil
      end,
      resolveSeason3MapIDByActivityID = overrides.resolveSeason3MapIDByActivityID or function(activityID)
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

  test("Highlight keeps active listing for shared spell when map is different", function()
    local currentMapID = nil
    local activeEntry = nil

    WithGlobals({
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
      C_Map = {
        GetBestMapForUnit = function(_unit)
          return currentMapID
        end,
      },
      C_LFGList = {
        GetActiveEntryInfo = function()
          return activeEntry
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = BuildHighlightController(addon)
      activeEntry = { active = true, mapID = 2442 }

      currentMapID = 2441
      local differentMapSpell = controller.ResolveActiveTeleportSpellID(nil, nil)
      Assert.Equal(differentMapSpell, 367416, "shared spell should stay highlighted on sibling map")

      currentMapID = 2442
      local exactMapSpell = controller.ResolveActiveTeleportSpellID(nil, nil)
      Assert.Nil(exactMapSpell, "shared spell should clear on exact listing map")
    end)
  end)

  test("Highlight queue path uses exact-map suppression for shared spell", function()
    local currentMapID = nil

    WithGlobals({
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
      C_Map = {
        GetBestMapForUnit = function(_unit)
          return currentMapID
        end,
      },
      C_LFGList = {
        GetActiveEntryInfo = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = BuildHighlightController(addon)

      currentMapID = 2441
      local differentMapSpell = controller.ResolveActiveTeleportSpellID(1001, nil)
      Assert.Equal(differentMapSpell, 367416, "queue shared spell should stay highlighted on sibling map")

      currentMapID = 2442
      local exactMapSpell = controller.ResolveActiveTeleportSpellID(1001, nil)
      Assert.Nil(exactMapSpell, "queue shared spell should clear on exact target map")
    end)
  end)

  test("Highlight joined-key resolver requires activity-based map context", function()
    local addon = LoadAddonModules({ "isiLive_highlight.lua" })
    local controller = BuildHighlightController(addon)

    local fromActivity = controller.ResolveJoinedKeyMapID(2001, nil)
    Assert.Equal(fromActivity, 2662, "joined-key map should resolve from activity")

    local spellOnly = controller.ResolveJoinedKeyMapID(nil, 445414)
    Assert.Nil(spellOnly, "joined-key map must stay nil for spell-only context")
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

  test("Highlight listing resolver requires unique activity map", function()
    local addon = LoadAddonModules({ "isiLive_highlight.lua" })
    local controller = BuildHighlightController(addon, {
      resolveSeason3MapIDByActivityID = function(activityID)
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
end
