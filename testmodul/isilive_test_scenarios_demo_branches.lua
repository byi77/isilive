---@diagnostic disable: undefined-global

-- Branch-coverage scenarios for logic/isiLive_demo.lua. Existing
-- test_mode scenarios pass full opts overrides into Demo.BuildDummyRoster
-- and never exercise the default-helper paths
-- (DefaultGetUnitNameAndRealm, DefaultGetUnitClass, ResolvePlayerIlvl,
-- ResolvePlayerKeystone) nor the HEALER fill ordering, the
-- CLASS_FALLBACKS replacement, or the realm-less ghost key. This file
-- targets exactly those paths by stubbing the relevant WoW globals and
-- letting the module's own defaults run.

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  -- DefaultGetUnitNameAndRealm: pcall existence path with full WoW stubs ------

  test("BuildDummyRoster runs DefaultGetUnitNameAndRealm via UnitFullName when opts skip the helper", function()
    WithGlobals({
      UnitExists = function()
        return true
      end,
      UnitFullName = function()
        return "Aria", "Sanguino"
      end,
      UnitClass = function()
        return "Mage", "MAGE"
      end,
      GetRealmName = function()
        return "Sanguino"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_demo.lua" })
      -- No getUnitNameAndRealm / getUnitClass overrides -> defaults run.
      local roster = addon.Demo.BuildDummyRoster({})
      Assert.Equal(roster.player.name, "Aria", "default helper must read name from UnitFullName")
      Assert.Equal(roster.player.realm, "Sanguino", "default helper must read realm from UnitFullName")
      Assert.Equal(roster.player.class, "MAGE", "default helper must read class token from UnitClass")
    end)
  end)

  test("BuildDummyRoster falls back to UnitName when UnitFullName is unavailable", function()
    WithGlobals({
      UnitExists = function()
        return true
      end,
      UnitName = function()
        return "Solo"
      end,
      UnitClass = function()
        return "Hunter", "HUNTER"
      end,
      GetRealmName = function()
        return "FallbackRealm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_demo.lua" })
      local roster = addon.Demo.BuildDummyRoster({})
      Assert.Equal(roster.player.name, "Solo", "UnitName fallback must populate name")
      Assert.Equal(
        roster.player.realm,
        "FallbackRealm",
        "blank realm from UnitFullName must fall back to GetRealmName()"
      )
    end)
  end)

  test("BuildDummyRoster handles UnitExists pcall returning false (no globals)", function()
    -- No UnitExists stub at all -> default helpers return nil/nil. The
    -- player entry then uses the literal Player/empty-realm fallbacks.
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_demo.lua" })
      local roster = addon.Demo.BuildDummyRoster({})
      Assert.Equal(roster.player.name, "Player", "missing UnitExists must yield literal Player")
      Assert.Equal(roster.player.realm, "", "missing GetRealmName must yield empty realm")
      Assert.Equal(roster.player.class, "WARRIOR", "missing class must default to WARRIOR")
    end)
  end)

  -- DefaultGetUnitClass: pcall failure on UnitClass leaves class nil -----------

  test("BuildDummyRoster keeps default class when UnitClass raises", function()
    WithGlobals({
      UnitExists = function()
        return true
      end,
      UnitFullName = function()
        return "RaidLeader", "Realm"
      end,
      UnitClass = function()
        error("blizz failure")
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_demo.lua" })
      local roster = addon.Demo.BuildDummyRoster({})
      Assert.Equal(roster.player.class, "WARRIOR", "UnitClass error must fall back to WARRIOR")
    end)
  end)

  -- ResolvePlayerIlvl: GetAverageItemLevel branch ------------------------------

  test("BuildDummyRoster reads ilvl from GetAverageItemLevel when C_Item is missing", function()
    WithGlobals({
      UnitExists = function()
        return true
      end,
      UnitFullName = function()
        return "Geared", "Realm"
      end,
      UnitClass = function()
        return "Druid", "DRUID"
      end,
      GetAverageItemLevel = function()
        return 280, 275 -- avg, equipped
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_demo.lua" })
      local roster = addon.Demo.BuildDummyRoster({})
      Assert.Equal(roster.player.ilvl, 275, "equipped ilvl must win over average")
    end)
  end)

  test("BuildDummyRoster reads ilvl from C_Item.GetAverageItemLevel when present", function()
    WithGlobals({
      UnitExists = function()
        return true
      end,
      UnitFullName = function()
        return "Geared", "Realm"
      end,
      UnitClass = function()
        return "Druid", "DRUID"
      end,
      C_Item = {
        GetAverageItemLevel = function()
          return 312
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_demo.lua" })
      local roster = addon.Demo.BuildDummyRoster({})
      Assert.Equal(roster.player.ilvl, 312, "C_Item ilvl must be used when API is present")
    end)
  end)

  -- ResolvePlayerKeystone: full happy path -------------------------------------

  test("BuildDummyRoster reads owned keystone level + map when C_MythicPlus is present", function()
    WithGlobals({
      UnitExists = function()
        return true
      end,
      UnitFullName = function()
        return "Pusher", "Realm"
      end,
      UnitClass = function()
        return "Rogue", "ROGUE"
      end,
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          return 14
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return 2649
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_demo.lua" })
      local roster = addon.Demo.BuildDummyRoster({})
      Assert.Equal(roster.player.keyMapID, 2649, "owned keystone mapID must be carried over")
      Assert.Equal(roster.player.keyLevel, 14, "owned keystone level must be carried over")
    end)
  end)

  test("BuildDummyRoster ignores keystone when GetOwnedKeystoneLevel raises", function()
    WithGlobals({
      UnitExists = function()
        return true
      end,
      UnitFullName = function()
        return "Pusher", "Realm"
      end,
      UnitClass = function()
        return "Rogue", "ROGUE"
      end,
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          error("api error")
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return 2649
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_demo.lua" })
      local roster = addon.Demo.BuildDummyRoster({})
      Assert.Nil(roster.player.keyMapID, "pcall failure must yield nil keystone")
    end)
  end)

  test("BuildDummyRoster ignores keystone when level is non-positive", function()
    WithGlobals({
      UnitExists = function()
        return true
      end,
      UnitFullName = function()
        return "Pusher", "Realm"
      end,
      UnitClass = function()
        return "Rogue", "ROGUE"
      end,
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          return 0
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return 2649
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_demo.lua" })
      local roster = addon.Demo.BuildDummyRoster({})
      Assert.Nil(roster.player.keyMapID, "non-positive level must not produce keystone")
    end)
  end)

  -- BuildFillMembers HEALER variant -------------------------------------------

  test("BuildDummyRoster orders fill list as TANK first when player role is HEALER", function()
    WithGlobals({
      UnitClass = function()
        return "Priest", "PRIEST"
      end,
      UnitName = function()
        return "Healer"
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_demo.lua" })
      local roster = addon.Demo.BuildDummyRoster({
        getUnitNameAndRealm = function(unit)
          if unit == "player" then
            return "Healer", "Realm"
          end
          return nil, nil
        end,
        getUnitRole = function(unit)
          return unit == "player" and "HEALER" or "DAMAGER"
        end,
      })
      -- HEALER ordering: tank, dd1, dd2, dd3 (no healer in fill)
      Assert.Equal(roster.party1.role, "TANK", "first fill member must be the tank")
      Assert.Equal(roster.party2.role, "DAMAGER", "second fill member must be a damager")
    end)
  end)

  -- CLASS_FALLBACKS replacement: player class clashes with dummy class --------

  test("BuildDummyRoster swaps a clashing dummy class with a fallback when player shares it", function()
    -- Player is MAGE, which is the dummy.dd1 class. The replacement
    -- loop must drop the colliding dummy and pick a class from
    -- CLASS_FALLBACKS instead. UnitExists must be installed so the
    -- DefaultGetUnitClass guard does not bail out early.
    WithGlobals({
      UnitExists = function()
        return true
      end,
      UnitClass = function()
        return "Mage", "MAGE"
      end,
      UnitName = function()
        return "Mage"
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_demo.lua" })
      local roster = addon.Demo.BuildDummyRoster({
        getUnitNameAndRealm = function(unit)
          if unit == "player" then
            return "Mage", "Realm"
          end
          return nil, nil
        end,
      })

      -- After replacement, no fill member may share the player class.
      for _, key in ipairs({ "party1", "party2", "party3", "party4" }) do
        local member = roster[key]
        if member then
          Assert.True(member.class ~= "MAGE", string.format("%s must not collide with player class", key))
        end
      end
      -- And the replacement must come from one of the canonical
      -- CLASS_FALLBACKS classes.
      local fallbackClasses = {
        WARRIOR = true,
        ROGUE = true,
        DEATHKNIGHT = true,
        MONK = true,
        DEMONHUNTER = true,
        SHAMAN = true,
        EVOKER = true,
      }
      local replacementFound = false
      for _, key in ipairs({ "party1", "party2", "party3", "party4" }) do
        local member = roster[key]
        if member and fallbackClasses[member.class] then
          replacementFound = true
        end
      end
      Assert.True(replacementFound, "at least one fill slot must use a CLASS_FALLBACKS class")
    end)
  end)

  -- BuildGhostUnitKey realm-less ghost key -------------------------------------

  test("BuildDummyRoster produces a ghost-with-realm key for the full preview ghost", function()
    -- The default ghost is dd3 ("Ravencast", "Antonidas") which has a
    -- realm — exercises the realm-included branch of BuildGhostUnitKey.
    WithGlobals({
      UnitClass = function()
        return "Warrior", "WARRIOR"
      end,
      UnitName = function()
        return "Tank"
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_demo.lua" })
      local roster = addon.Demo.BuildDummyRoster({
        previewVariant = "full",
        getUnitNameAndRealm = function(unit)
          if unit == "player" then
            return "Tank", "Realm"
          end
          return nil, nil
        end,
        getUnitRole = function(unit)
          return unit == "player" and "TANK" or "DAMAGER"
        end,
      })

      local ghostKey
      for unit, info in pairs(roster) do
        if info and info.isGhost then
          ghostKey = unit
          break
        end
      end
      Assert.NotNil(ghostKey, "ghost unit must be present in full preview")
      Assert.Equal(ghostKey, "ghost:Ravencast-Antonidas", "ghost key must include name and realm")
    end)
  end)

  local function BuildDemoRosterOpts()
    return {
      getUnitNameAndRealm = function()
        return "Player", "Realm"
      end,
      getUnitClass = function()
        return "Warlock", "WARLOCK"
      end,
      getUnitRole = function()
        return "DAMAGER"
      end,
    }
  end

  test("BuildDummyRoster keys follow the active season dungeon order", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_season_data.lua", "isiLive_demo.lua" })
      local ordered = addon.SeasonData.GetOrderedMapIDs()
      Assert.True(#ordered >= 4, "active season must provide at least four dungeons for this scenario")
      local roster = addon.Demo.BuildDummyRoster(BuildDemoRosterOpts())
      for index = 1, 4 do
        local entry = roster["party" .. index]
        Assert.Equal(entry.keyMapID, ordered[index], "dummy key " .. index .. " must use the active season order")
        Assert.Nil(entry.keyMapSlot, "the internal season slot must not leak into the roster entry")
      end
    end)
  end)

  test("BuildDummyRoster dummies carry manifest spec IDs and isiLive markers", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_specs.lua", "isiLive_demo.lua" })
      local specs = addon.SpecManifest.specs
      local opts = BuildDemoRosterOpts()
      -- Mage player: dd1 (Frost Mage) is replaced by a class fallback.
      opts.getUnitClass = function()
        return "Mage", "MAGE"
      end
      local roster = addon.Demo.BuildDummyRoster(opts)
      local replaced = true
      for index = 1, 4 do
        local entry = roster["party" .. index]
        local spec = specs[entry.specID]
        Assert.NotNil(spec, "dummy " .. index .. " must carry a known spec ID")
        Assert.Equal(spec.class, entry.class, "dummy " .. index .. " spec ID must belong to its class")
        if entry.role == "HEALER" then
          Assert.Nil(entry.hasIsiLive, "the healer dummy stays a plain group member")
        else
          Assert.True(entry.hasIsiLive == true, "dummy " .. index .. " with sync data must be an isiLive user")
        end
        replaced = replaced and entry.name ~= "Zephyrax"
      end
      Assert.True(replaced, "a class fallback must have replaced the clashing dummy")
    end)
  end)

  test("BuildDummyRoster drops dummy keys when the active season has no dungeons", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_season_data.lua", "isiLive_demo.lua" })
      addon.SeasonData.GetOrderedMapIDs = function()
        return {}
      end
      local roster = addon.Demo.BuildDummyRoster(BuildDemoRosterOpts())
      for index = 1, 4 do
        local entry = roster["party" .. index]
        Assert.Nil(entry.keyMapID, "dummy key " .. index .. " must not invent a map without an active season")
        Assert.Nil(entry.keyLevel, "dummy key " .. index .. " must not show a level without a map")
      end
    end)
  end)
end
