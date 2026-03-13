local function RegisterStatsPruningTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Stats controller records dungeon runs without persisting foreign or unused legacy stats data", function()
    local db = {
      stats = {
        dungeons = {},
        players = { ["friend-realm"] = 99 },
        playerLastRuns = {
          ["friend-realm"] = { dps = 1 },
        },
      },
    }
    local roster = {
      player = { name = "Me", realm = "MyRealm" },
      party1 = { name = "Friend", realm = "Realm" },
      party2 = { name = "Stranger", realm = "Realm" },
    }

    WithGlobals({
      IsiLiveDB = db,
      GetRealmName = function()
        return "MyRealm"
      end,
      C_DamageMeter = {
        GetCombatSessionFromType = function()
          return {
            durationSeconds = 1800,
            combatSources = {
              { name = "Me", amountPerSecond = 456789.4, totalAmount = 822220920 },
              { name = "Friend-Realm", amountPerSecond = 321123.8, totalAmount = 578022840 },
            },
          }
        end,
      },
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

      Assert.Nil(db.stats.dungeons, "unused dungeon counters must not stay persisted")
      Assert.Nil(db.stats.players, "foreign player counters must not stay persisted")
      Assert.Nil(db.stats.playerLastRuns, "legacy foreign player DPS storage must be pruned")
      Assert.Equal(
        math.floor((db.stats.playerLastRunByCharacter["me-myrealm"] or {}).dps or 0),
        456789,
        "local player DPS should persist in the character-keyed store"
      )
    end)
  end)

  test("Stats controller does not touch IsiLiveDB before first method call", function()
    local db = {
      stats = {
        players = { ["buddy-realm"] = 7 },
        dungeons = { [2662] = 4 },
        playerLastRuns = { ["me-myrealm"] = { dps = 100 } },
      },
    }

    WithGlobals({
      IsiLiveDB = db,
      GetRealmName = function()
        return "MyRealm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_stats.lua" })
      addon.Stats.CreateController({
        getRoster = function()
          return {}
        end,
        getUnitNameAndRealm = function(unit)
          if unit == "player" then
            return "Me", "MyRealm"
          end
          return nil
        end,
      })

      -- Migration must be deferred: SavedVariables may not be restored yet at construction time
      Assert.NotNil(db.stats.players, "IsiLiveDB must not be modified before first method call")
      Assert.NotNil(db.stats.dungeons, "IsiLiveDB must not be modified before first method call")
      Assert.NotNil(db.stats.playerLastRuns, "IsiLiveDB must not be modified before first method call")
    end)
  end)

  test("Stats controller migrates legacy local-player DPS and prunes foreign legacy entries on first use", function()
    local db = {
      stats = {
        dungeons = { [2662] = 4 },
        playerLastRuns = {
          ["me-myrealm"] = { dps = 456789.4, mapID = 2662, level = 12 },
          ["buddy-realm"] = { dps = 321123.8, mapID = 2662, level = 12 },
        },
        players = {
          ["buddy-realm"] = 7,
        },
      },
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
          return {}
        end,
        getUnitNameAndRealm = function(unit)
          if unit == "player" then
            return "Me", "MyRealm"
          end
          return nil
        end,
      })

      -- Migration runs lazily on first method call, not at construction time
      Assert.Equal(
        math.floor(controller.GetPlayerLastRunDps("Me", "MyRealm") or 0),
        456789,
        "migrated local-player DPS should be readable on first use"
      )
      Assert.Nil(db.stats.players, "legacy foreign player counters must be pruned on first use")
      Assert.Nil(db.stats.dungeons, "unused legacy dungeon counters must be pruned on first use")
      Assert.Nil(db.stats.playerLastRuns, "legacy multi-player last-run storage must be removed on first use")
      Assert.Equal(
        math.floor((db.stats.playerLastRunByCharacter["me-myrealm"] or {}).dps or 0),
        456789,
        "local player's legacy DPS snapshot should migrate into the character-keyed local store"
      )
      Assert.Nil(
        controller.GetPlayerLastRunDps("Buddy", "Realm"),
        "foreign legacy DPS snapshots must not survive migration"
      )
    end)
  end)

  test(
    "Stats controller discards ambiguous legacy single-slot DPS instead of reassigning it to another local character",
    function()
      local db = {
        stats = {
          playerLastRun = { dps = 456789.4, mapID = 2662, level = 12 },
        },
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
            return {}
          end,
          getUnitNameAndRealm = function(unit)
            if unit == "player" then
              return "Alt", "MyRealm"
            end
            return nil
          end,
        })

        Assert.Nil(
          controller.GetPlayerLastRunDps("Alt", "MyRealm"),
          "ambiguous legacy single-slot DPS must not be guessed onto the currently logged-in alt"
        )
        Assert.Nil(db.stats.playerLastRun, "legacy single-slot DPS must be removed during migration")
        Assert.Nil(
          (db.stats.playerLastRunByCharacter or {})["alt-myrealm"],
          "no new character-keyed DPS entry may be fabricated from the ambiguous legacy slot"
        )
      end)
    end
  )
end

local function RegisterStatsDamageMeterTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Stats controller reports whether a run snapshot captured any roster DPS", function()
    local db = { stats = {} }
    local damageMeterSession = nil

    WithGlobals({
      IsiLiveDB = db,
      GetRealmName = function()
        return "MyRealm"
      end,
      C_DamageMeter = {
        GetCombatSessionFromType = function()
          return damageMeterSession
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_stats.lua" })
      local controller = addon.Stats.CreateController({
        getRoster = function()
          return {
            player = { name = "Me", realm = "MyRealm" },
          }
        end,
        getUnitNameAndRealm = function(unit)
          if unit == "player" then
            return "Me", "MyRealm"
          end
          return nil
        end,
      })

      Assert.False(controller.RecordRun(2662, 12, true), "empty damage-meter data should report an uncaptured run")

      damageMeterSession = {
        durationSeconds = 1800,
        combatSources = {
          { name = "Me", amountPerSecond = 456789.4, totalAmount = 822220920 },
        },
      }

      Assert.True(controller.RecordRun(2662, 12, true), "matching roster DPS snapshot should report successful capture")
    end)
  end)

  test("Stats controller stores latest run DPS from Blizzard damage meter for roster players", function()
    local db = { stats = {} }
    local roster = {
      player = { name = "Me", realm = "MyRealm" },
      party1 = { name = "Buddy", realm = "Realm" },
      party2 = { name = "Other", realm = "Else" },
    }

    WithGlobals({
      IsiLiveDB = db,
      GetRealmName = function()
        return "MyRealm"
      end,
      C_DamageMeter = {
        GetCombatSessionFromType = function(sessionType, damageType)
          Assert.Equal(sessionType, 0, "completed run snapshot should read the overall damage-meter session")
          Assert.Equal(damageType, 0, "completed run snapshot should read damage-done data")
          return {
            durationSeconds = 1800,
            combatSources = {
              { name = "Me", amountPerSecond = 456789.4, totalAmount = 822220920 },
              { name = "Buddy-Realm", amountPerSecond = 321123.8, totalAmount = 578022840 },
              { name = "Random-Outland", amountPerSecond = 999999.9, totalAmount = 1 },
            },
          }
        end,
      },
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

      controller.RecordRun(2662, 12, true)

      Assert.Equal(
        math.floor(controller.GetPlayerLastRunDps("Me", "MyRealm") or 0),
        456789,
        "player DPS should be stored from the damage-meter snapshot"
      )
      Assert.Equal(
        math.floor(controller.GetPlayerLastRunDps("Buddy", "Realm") or 0),
        321123,
        "party member DPS should be exposed for the current session"
      )
      Assert.Nil(
        controller.GetPlayerLastRunDps("Other", "Else"),
        "roster members without a matching damage-meter source should stay unresolved"
      )
    end)
  end)

  test("Stats controller falls back to current damage-meter session when overall session is unavailable", function()
    local db = { stats = {} }
    local requestedSessionTypes = {}

    WithGlobals({
      IsiLiveDB = db,
      GetRealmName = function()
        return "MyRealm"
      end,
      C_DamageMeter = {
        GetCombatSessionFromType = function(_damageType, sessionType)
          table.insert(requestedSessionTypes, sessionType)
          if sessionType == 0 then
            return nil
          end
          return {
            durationSeconds = 1800,
            combatSources = {
              { name = "Me", amountPerSecond = 456789.4, totalAmount = 822220920 },
            },
          }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_stats.lua" })
      local controller = addon.Stats.CreateController({
        getRoster = function()
          return {
            player = { name = "Me", realm = "MyRealm" },
          }
        end,
        getUnitNameAndRealm = function(unit)
          if unit == "player" then
            return "Me", "MyRealm"
          end
          return nil
        end,
      })

      controller.RecordRun(2662, 12, true)

      Assert.Equal(
        #requestedSessionTypes,
        2,
        "damage-meter lookup should retry with current session when overall is unavailable"
      )
      Assert.Equal(requestedSessionTypes[1], 0, "overall session must be attempted first")
      Assert.Equal(requestedSessionTypes[2], 1, "current session must be used as fallback")
      Assert.Equal(
        math.floor(controller.GetPlayerLastRunDps("Me", "MyRealm") or 0),
        456789,
        "current-session fallback should still produce a local DPS snapshot"
      )
    end)
  end)
end

local function RegisterStatsPersistenceTests(test, Assert, WithGlobals, LoadAddonModules)
  test(
    "Stats controller persists only the matching local character's last-run DPS across controller recreation",
    function()
      local db = { stats = {} }

      WithGlobals({
        IsiLiveDB = db,
        GetRealmName = function()
          return "MyRealm"
        end,
        C_DamageMeter = {
          GetCombatSessionFromType = function()
            return {
              durationSeconds = 1800,
              combatSources = {
                { name = "Me", amountPerSecond = 456789.4, totalAmount = 822220920 },
                { name = "Buddy-Realm", amountPerSecond = 321123.8, totalAmount = 578022840 },
              },
            }
          end,
        },
      }, function()
        local addon = LoadAddonModules({ "isiLive_stats.lua" })
        local firstController = addon.Stats.CreateController({
          getRoster = function()
            return {
              player = { name = "Me", realm = "MyRealm" },
              party1 = { name = "Buddy", realm = "Realm" },
            }
          end,
          getUnitNameAndRealm = function(unit)
            if unit == "player" then
              return "Me", "MyRealm"
            end
            return nil
          end,
        })

        firstController.RecordRun(2662, 12, true)

        local secondController = addon.Stats.CreateController({
          getRoster = function()
            return {}
          end,
          getUnitNameAndRealm = function(unit)
            if unit == "player" then
              return "Me", "MyRealm"
            end
            return nil
          end,
        })

        Assert.Equal(
          math.floor(secondController.GetPlayerLastRunDps("Me", "MyRealm") or 0),
          456789,
          "local player's last-run DPS should persist across reload/controller recreation"
        )
        Assert.Nil(
          secondController.GetPlayerLastRunDps("Buddy", "Realm"),
          "foreign player DPS must stay session-only and disappear after controller recreation"
        )

        local altController = addon.Stats.CreateController({
          getRoster = function()
            return {}
          end,
          getUnitNameAndRealm = function(unit)
            if unit == "player" then
              return "Alt", "MyRealm"
            end
            return nil
          end,
        })

        Assert.Nil(
          altController.GetPlayerLastRunDps("Alt", "MyRealm"),
          "a different local character must not inherit another character's persisted DPS entry"
        )
      end)
    end
  )

  test("Stats controller can resolve DPS from explicit frozen roster snapshot override", function()
    local db = { stats = {} }

    WithGlobals({
      IsiLiveDB = db,
      GetRealmName = function()
        return "MyRealm"
      end,
      C_DamageMeter = {
        GetCombatSessionFromType = function()
          return {
            durationSeconds = 1800,
            combatSources = {
              { name = "Me", amountPerSecond = 456789.4, totalAmount = 822220920 },
              { name = "Buddy-Realm", amountPerSecond = 321123.8, totalAmount = 578022840 },
            },
          }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_stats.lua" })
      local controller = addon.Stats.CreateController({
        getRoster = function()
          return {}
        end,
        getUnitNameAndRealm = function(unit)
          if unit == "player" then
            return "Me", "MyRealm"
          end
          return nil
        end,
      })

      controller.RecordRun(2662, 0, nil, {
        player = { name = "Me", realm = "MyRealm" },
        party1 = { name = "Buddy", realm = "Realm" },
      })

      Assert.Equal(
        math.floor(controller.GetPlayerLastRunDps("Buddy", "Realm") or 0),
        321123,
        "explicit frozen roster snapshot should allow party DPS resolution after live roster is gone"
      )
    end)
  end)
end

local function RegisterStatsTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterStatsPruningTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterStatsDamageMeterTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterStatsPersistenceTests(test, Assert, WithGlobals, LoadAddonModules)
end

return function(test, ctx)
  RegisterStatsTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
end
