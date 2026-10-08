---@diagnostic disable: undefined-global

-- Branch-coverage scenarios for logic/isiLive_highlight.lua. The main
-- highlight tests file exercises the resolver happy paths through a
-- well-formed deps controller. This file targets the still-uncovered
-- defensive branches: logging hooks, the boolean-tuple legacy
-- C_LFGList API, missing globals, and CreateController default deps.

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  -- TryGet key3 path -----------------------------------------------------------
  --
  -- TryGet is local; the key3 fallback is only reachable through the
  -- normalized GetActiveEntryInfo on a table response. To cover the
  -- key3 fallback, supply a table that has neither the key1 nor key2
  -- variants and lets one of the TryGet calls fall through to key3.
  -- title => `TryGet(r1, "title", "groupTitle", nil)` only has two keys
  -- in production, so the key3 path is exercised through the
  -- name-style chain by a manual call after loading the module: we
  -- instead trigger it via the normalized return path that uses
  -- TryGet(r1, "name", "listingName", nil) — supplying neither yields
  -- the bottom return path. The test below also covers the tuple-form
  -- pcall branch.

  test("CreateController returns controller using zero-opts default deps", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      -- Pass nil opts to exercise default isInGroup / resolver fallbacks.
      local controller = addon.Highlight.CreateController(nil)
      Assert.NotNil(controller, "controller must be returned")
      Assert.Equal(controller.ResolveActiveTeleportSpellID(123, 456), nil, "default deps must yield nil for any input")
    end)
  end)

  test("GetNormalizedActiveEntryInfo returns nil when C_LFGList is missing", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = addon.Highlight.CreateController({
        isInGroup = function()
          return true
        end,
      })
      Assert.Nil(controller.GetNormalizedActiveEntryInfo(), "no C_LFGList must yield nil")
    end)
  end)

  test("GetNormalizedActiveEntryInfo returns nil when GetActiveEntryInfo raises", function()
    WithGlobals({
      C_LFGList = {
        GetActiveEntryInfo = function()
          error("boom")
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = addon.Highlight.CreateController({})
      Assert.Nil(controller.GetNormalizedActiveEntryInfo(), "pcall failure must yield nil")
    end)
  end)

  test("GetNormalizedActiveEntryInfo handles legacy boolean-tuple API", function()
    -- WoW used to return (active, activityID, ?, ?, name1, name2, name3)
    -- as a tuple. Modern API returns a table. The legacy path must
    -- still build an entry { active, activityID, name }.
    WithGlobals({
      C_LFGList = {
        GetActiveEntryInfo = function()
          -- active=true, activityID=42, then 2 placeholders, then 3 name candidates
          return true, 42, nil, nil, "", "Group Name", "Activity Name"
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = addon.Highlight.CreateController({})
      local entry = controller.GetNormalizedActiveEntryInfo()
      Assert.NotNil(entry, "tuple form must produce an entry")
      Assert.Equal(entry.active, true, "active flag must be carried over")
      Assert.Equal(entry.activityID, 42, "activityID must be parsed from tuple position 2")
      Assert.Equal(entry.name, "Group Name", "first non-empty string must become entry.name")
    end)
  end)

  -- Location lookup: no location API at all -----------------------------------

  test("Highlight queue path resolves without any location API", function()
    -- Without GetInstanceInfo / C_ChallengeMode in _G the "inside the target
    -- dungeon" check fails closed, so the queue path is allowed to run (no
    -- in-dungeon block).
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = addon.Highlight.CreateController({
        isInGroup = function()
          return true
        end,
        resolveTeleportSpellIDByMapID = function()
          return 999
        end,
        resolveMapIDByActivityID = function()
          return 5
        end,
      })
      -- Provide a queue activity id; resolver maps to mapID=5,
      -- spellID=999. With no instance context, the queue path returns
      -- the spellID.
      Assert.Equal(
        controller.ResolveActiveTeleportSpellID(123, nil),
        999,
        "queue path must resolve without location APIs"
      )
    end)
  end)

  test("Highlight treats GetInstanceInfo errors as outside the target dungeon", function()
    WithGlobals({
      GetInstanceInfo = function()
        error("instance lookup unavailable")
      end,
      C_ChallengeMode = {
        GetMapUIInfo = function()
          return "Dungeon", 5, 1800, nil, nil, 2813
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = addon.Highlight.CreateController({
        isInGroup = function()
          return true
        end,
        resolveTeleportSpellIDByMapID = function(mapID)
          if mapID == 5 then
            return 999
          end
          return nil
        end,
        resolveMapIDByActivityID = function()
          return 5
        end,
      })

      Assert.Equal(
        controller.ResolveActiveTeleportSpellID(123, nil),
        999,
        "instance lookup errors must not abort queue-based highlight resolution"
      )
    end)
  end)

  -- ResolveMapIDFromActivityID guards ------------------------------------------

  test("ResolveMapIDFromActivityID returns nil for non-positive activity id", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = addon.Highlight.CreateController({
        resolveMapIDByActivityID = function()
          return 42
        end,
      })
      Assert.Nil(controller.ResolveMapIDFromActivityID(0), "zero must yield nil")
      Assert.Nil(controller.ResolveMapIDFromActivityID(-1), "negative must yield nil")
    end)
  end)

  test("ResolveMapIDFromActivityID returns nil when resolver yields zero", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = addon.Highlight.CreateController({
        resolveMapIDByActivityID = function()
          return 0
        end,
      })
      Assert.Nil(controller.ResolveMapIDFromActivityID(123), "non-positive resolved must yield nil")
    end)
  end)

  -- ResolveActiveListingTarget: defensive paths --------------------------------

  test("ResolveActiveListingTarget returns nil for non-table entryInfo", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = addon.Highlight.CreateController({})
      Assert.Nil(controller.ResolveActiveListingTarget("not-a-table"), "non-table must yield nil")
    end)
  end)

  test("ResolveActiveListingTarget returns nil when no spell maps to the resolved mapID", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = addon.Highlight.CreateController({
        resolveTeleportSpellIDByMapID = function()
          return nil -- no spell available for this map
        end,
      })
      Assert.Nil(
        controller.ResolveActiveListingTarget({ active = true, mapID = 42 }),
        "missing spell mapping must yield nil"
      )
    end)
  end)

  -- Logging hooks: every logf call should be exercised --------------------------

  test("ResolveActiveTeleportSpellID logs every decision when logRuntimeTracef is set", function()
    local logCalls = {}
    local activeEntry = { active = true, mapID = 2442 }
    local currentInstanceID = nil
    local instanceByChallengeMapID = { [2442] = 2651, [2662] = 2660 }
    WithGlobals({
      GetInstanceInfo = function()
        return "Instance", currentInstanceID and "party" or "none", 0, "", 5, 0, false, currentInstanceID, 0, 0
      end,
      C_ChallengeMode = {
        GetMapUIInfo = function(challengeMapID)
          return "Dungeon", challengeMapID, 1800, nil, nil, instanceByChallengeMapID[challengeMapID]
        end,
      },
      C_LFGList = {
        GetActiveEntryInfo = function()
          return activeEntry
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = addon.Highlight.CreateController({
        isInGroup = function()
          return true
        end,
        resolveTeleportSpellIDByMapID = function(mapID)
          if mapID == 2442 then
            return 367416
          end
          if mapID == 2662 then
            return 445414
          end
          return nil
        end,
        resolveMapIDByActivityID = function(activityID)
          if activityID == 1001 then
            return 2662
          end
          return nil
        end,
        logRuntimeTracef = function(format, ...)
          table.insert(logCalls, { format = format, args = { ... } })
        end,
      })

      -- Case 1: active target with mapID, player in another instance -> spell_from_active_target
      currentInstanceID = 2649
      Assert.Equal(controller.ResolveActiveTeleportSpellID(nil, nil), 367416, "active target spell must resolve")

      -- Case 2: active target, player inside its instance -> blocked_already_in_dungeon
      currentInstanceID = 2651
      Assert.Nil(controller.ResolveActiveTeleportSpellID(nil, nil), "matching map must block highlight")

      -- Case 3: not active, not in group -> blocked_not_in_group
      activeEntry = nil
      currentInstanceID = nil
      local controllerNoGroup = addon.Highlight.CreateController({
        isInGroup = function()
          return false
        end,
        logRuntimeTracef = function(format, ...)
          table.insert(logCalls, { format = format, args = { ... } })
        end,
      })
      Assert.Nil(controllerNoGroup.ResolveActiveTeleportSpellID(nil, nil), "no group must block")

      -- Case 4: in group, queue activity resolves to map -> spell_from_queue
      Assert.Equal(controller.ResolveActiveTeleportSpellID(1001, nil), 445414, "queue path must resolve to spell")

      -- Case 5: in group, player inside the queue map instance -> blocked_already_in_dungeon
      currentInstanceID = 2660
      Assert.Nil(controller.ResolveActiveTeleportSpellID(1001, nil), "queue map matches current map -> blocked")

      -- Case 6: in group, no queue map at all -> blocked_no_queue_map
      currentInstanceID = nil
      Assert.Nil(controller.ResolveActiveTeleportSpellID(nil, nil), "no queue map -> blocked")
    end)

    Assert.True(#logCalls > 0, "logRuntimeTracef must have been invoked at least once")
    -- Spot-check that several distinct log formats were emitted.
    local formats = {}
    for _, call in ipairs(logCalls) do
      formats[call.format] = true
    end
    Assert.True(
      formats["[HIGHLIGHT] resolve_spell_id currentInstanceID=%s queueActivityID=%s queueMapID=%s"] == true,
      "resolve_spell_id trace must fire on every call"
    )
  end)

  -- ResolveJoinedKeyMapID: thin wrapper, exercise ignore-spellID arg -----------

  test("ResolveJoinedKeyMapID delegates to ResolveMapIDFromActivityID and ignores spellID", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = addon.Highlight.CreateController({
        resolveMapIDByActivityID = function(activityID)
          return activityID == 1001 and 2662 or nil
        end,
      })
      Assert.Equal(controller.ResolveJoinedKeyMapID(1001, 9999), 2662, "delegates to map-from-activity")
      Assert.Nil(controller.ResolveJoinedKeyMapID(0, 9999), "non-positive activity yields nil")
    end)
  end)

  -- ResolveActiveListingTarget: activityIDs collection multi-map disambiguation ---

  test("ResolveActiveListingTarget bails out when activityIDs map to multiple distinct maps", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_highlight.lua" })
      local controller = addon.Highlight.CreateController({
        resolveMapIDByActivityID = function(activityID)
          if activityID == 11 then
            return 100
          end
          if activityID == 22 then
            return 200
          end
          return nil
        end,
        resolveTeleportSpellIDByMapID = function()
          return 9999
        end,
      })
      -- Two different maps => uniqueMaps != 1 => mapID stays nil => target nil.
      Assert.Nil(
        controller.ResolveActiveListingTarget({
          active = true,
          activityIDs = { 11, 22 },
        }),
        "ambiguous activityIDs must yield no target"
      )
    end)
  end)
end
