local function RegisterStatsTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Stats controller records dungeon and player runs", function()
    local db = { stats = { dungeons = {}, players = {} } }
    local roster = {
      party1 = { name = "Friend", realm = "Realm" },
      party2 = { name = "Stranger", realm = "Realm" },
    }

    WithGlobals({
      IsiLiveDB = db,
      GetRealmName = function()
        return "MyRealm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_stats.lua" })
      local controller = addon.Stats.CreateController({
        getRoster = function()
          return roster
        end,
        getUnitNameAndRealm = function(unit)
          if unit == "player" then
            return "Me", "MyRealm"
          end
          return nil
        end,
      })

      controller.RecordRun(2662, 10, true)

      Assert.Equal(db.stats.dungeons[2662], 1, "dungeon run count should increment")
      Assert.Equal(db.stats.players["friend-realm"], 1, "player run count should increment for party1")
      Assert.Equal(db.stats.players["stranger-realm"], 1, "player run count should increment for party2")

      -- Record again
      controller.RecordRun(2662, 10, true)
      Assert.Equal(db.stats.dungeons[2662], 2, "dungeon run count should accumulate")
      Assert.Equal(db.stats.players["friend-realm"], 2, "player run count should accumulate")
    end)
  end)

  test("Stats controller normalizes names correctly", function()
    local db = { stats = { players = {} } }

    WithGlobals({
      IsiLiveDB = db,
      GetRealmName = function()
        return "DefaultRealm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_stats.lua" })
      local controller = addon.Stats.CreateController({})

      -- Manually inject data to test retrieval normalization
      db.stats.players["toon-defaultrealm"] = 5

      local count = controller.GetPlayerCount("Toon", nil)
      Assert.Equal(count, 5, "GetPlayerCount should normalize name and use default realm")

      local countExplicit = controller.GetPlayerCount("Toon", "DefaultRealm")
      Assert.Equal(countExplicit, 5, "GetPlayerCount should handle explicit realm")
    end)
  end)
end

return function(test, ctx)
  RegisterStatsTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
end
