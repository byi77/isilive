---@diagnostic disable: undefined-global

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  test("SeasonDebug dump fails closed when Blizzard season APIs are unavailable", function()
    local addon = LoadAddonModules({ "isiLive_season_data.lua", "isiLive_season_debug.lua" })
    local joined = table.concat(addon.SeasonDebug.BuildDumpLines(), "\n")
    Assert.True(joined:find("activeSeasonID=midnight_s1", 1, true) ~= nil, "dump must include active season")
    Assert.True(joined:find("GetInstanceInfo=unavailable", 1, true) ~= nil, "missing instance API is surfaced")
    Assert.True(joined:find("activeChallengeMapID=unavailable", 1, true) ~= nil, "missing challenge API is surfaced")
    Assert.True(joined:find("activeLfgEntry=unavailable", 1, true) ~= nil, "missing LFG API is surfaced")
  end)

  test("SeasonDebug dump prints observed instance challenge map and active LFG data", function()
    local joined = nil
    WithGlobals({
      GetInstanceInfo = function()
        return "Test Dungeon", "party", 23, "Heroic", 5, nil, nil, 777, 12345
      end,
      UnitExists = function(unit)
        return unit == "player"
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          return unit == "player" and 888 or nil
        end,
      },
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return 999
        end,
        GetActiveKeystoneInfo = function()
          return 12, 1, 2, 3, 4
        end,
      },
      C_LFGList = {
        GetActiveEntryInfo = function()
          return { activityID = 456, activityIDs = { 456, 457 }, name = "Observed listing" }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_season_data.lua", "isiLive_season_debug.lua" }, {
        MPlusForces = {
          season = "midnight_s1",
          mdtVersion = "test",
          generatedAt = "2026-06-30",
          expiresAt = "2030-01-01",
          dungeonCount = 8,
          npcCount = 10,
        },
      })
      joined = table.concat(addon.SeasonDebug.BuildDumpLines(), "\n")
    end)
    Assert.True(joined:find("instance name=Test Dungeon", 1, true) ~= nil, "instance line must include name")
    Assert.True(joined:find("playerBestMapID=888", 1, true) ~= nil, "map line must include observed player map")
    Assert.True(joined:find("activeChallengeMapID=999", 1, true) ~= nil, "challenge line must include observed map")
    Assert.True(joined:find("activityID=456", 1, true) ~= nil, "LFG line must include observed activity")
  end)

  test("SeasonDebug dump hides secret instance metadata", function()
    local secret = {}
    WithGlobals({
      GetInstanceInfo = function()
        return "Secret Dungeon", secret, 23, "Mythic", 5, nil, nil, 777, 12345
      end,
      issecretvalue = function(value)
        return value == secret
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_season_data.lua", "isiLive_season_debug.lua" })
      local joined = table.concat(addon.SeasonDebug.BuildDumpLines(), "\n")
      Assert.True(
        joined:find("GetInstanceInfo=unavailable", 1, true) ~= nil,
        "secret instance metadata must not be written to the debug dump"
      )
      Assert.True(
        joined:find("instance name=Secret Dungeon", 1, true) == nil,
        "secret instance metadata must not be rendered"
      )
    end)
  end)
end
