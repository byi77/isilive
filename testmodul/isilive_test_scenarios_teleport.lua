local function BuildCreateFrameStub()
  local createdFrames = {}

  local function CreateFrameStub(_frameType)
    local frame = {
      _events = {},
      _scripts = {},
    }

    function frame:SetScript(name, handler)
      self._scripts[name] = handler
    end

    function frame:RegisterEvent(event)
      self._events[event] = true
    end

    function frame:UnregisterEvent(event)
      self._events[event] = nil
    end

    function frame:IsEventRegistered(event)
      return self._events[event] == true
    end

    function frame:FireEvent(event)
      local handler = self._scripts.OnEvent
      if handler then
        handler(self, event)
      end
    end

    table.insert(createdFrames, frame)
    return frame
  end

  return CreateFrameStub, createdFrames
end

local function ActivateSeasonOrFail(Assert, addon, seasonID, opts)
  -- Resolver fixtures intentionally define only fields used by Teleport; the
  -- production automatic selector is covered separately with full readiness.
  opts = opts or {}
  opts.allowIncomplete = true
  local ok, err = addon.SeasonData.SetActiveSeasonID(seasonID, opts)
  Assert.True(ok, tostring(err))
end

local function RegisterTeleportResolverCoreTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Teleport resolves shared-map spell IDs as deterministic sorted map list", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      addon.SeasonData.SEASONS.test_season = {
        mapToTeleport = {
          [2649] = 445444,
          [2830] = 1237215,
          [2287] = 354465,
          [2773] = 1216786,
          [2660] = 445417,
          [2441] = 367416,
          [2442] = 367416,
          [2662] = 445414,
        },
        displayOrder = { 2287, 2441, 2442, 2649, 2660, 2662, 2773, 2830 },
        shortCodesByLocale = {
          default = {
            [2649] = "PSF",
            [2830] = "EDA",
            [2287] = "HOA",
            [2773] = "OFG",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "DB",
          },
          deDE = {
            [2649] = "PRI",
            [2830] = "BIO",
            [2287] = "HDS",
            [2773] = "SCH",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "MB",
          },
        },
        challengeMapAliases = {
          [378] = 2287,
          [391] = 2441,
          [392] = 2441,
          [499] = 2649,
          [503] = 2660,
          [505] = 2662,
          [525] = 2773,
          [542] = 2830,
        },
      }
      ActivateSeasonOrFail(Assert, addon, "test_season")
      local mapIDs = addon.Teleport.ResolveMapIDsBySpellID(367416)

      Assert.NotNil(mapIDs, "shared spell should map to map list")
      Assert.Equal(#mapIDs, 2, "shared tazavesh spell should map to exactly two dungeons")
      Assert.Equal(mapIDs[1], 2441, "first shared map should be sorted ascending")
      Assert.Equal(mapIDs[2], 2442, "second shared map should be sorted ascending")
    end)
  end)

  test("Teleport returns locale-specific dungeon short codes for deDE and keeps enUS defaults", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })

      Assert.Equal(addon.SeasonData.GetActiveSeasonID(), "midnight_s2", "runtime should default to midnight_s2")
      Assert.True(
        addon.SeasonData.HasActiveDungeons(),
        "runtime should expose the active Midnight Season 2 portal pool"
      )
      Assert.Equal(
        #addon.SeasonData.GetOrderedMapIDs(),
        8,
        "runtime should keep all 8 Midnight Season 2 dungeons in the active ordered map list"
      )

      addon.SeasonData.SEASONS.test_season = {
        mapToTeleport = {
          [2649] = 445444,
          [2830] = 1237215,
          [2287] = 354465,
          [2773] = 1216786,
          [2660] = 445417,
          [2441] = 367416,
          [2442] = 367416,
          [2662] = 445414,
        },
        displayOrder = { 2287, 2441, 2442, 2649, 2660, 2662, 2773, 2830 },
        shortCodesByLocale = {
          default = {
            [2649] = "PSF",
            [2830] = "EDA",
            [2287] = "HOA",
            [2773] = "OFG",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "DB",
          },
          deDE = {
            [2649] = "PRI",
            [2830] = "BIO",
            [2287] = "HDS",
            [2773] = "SCH",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "MB",
          },
        },
        challengeMapAliases = {
          [378] = 2287,
          [391] = 2441,
          [392] = 2441,
          [499] = 2649,
          [503] = 2660,
          [505] = 2662,
          [525] = 2773,
          [542] = 2830,
        },
      }
      ActivateSeasonOrFail(Assert, addon, "test_season")

      Assert.Equal(addon.Teleport.GetDungeonShortCode(2649, "deDE"), "PRI", "deDE should map PSF to PRI")
      Assert.Equal(addon.Teleport.GetDungeonShortCode(2830, "deDE"), "BIO", "deDE should map EDA to BIO")
      Assert.Equal(addon.Teleport.GetDungeonShortCode(2287, "deDE"), "HDS", "deDE should map HOA to HDS")
      Assert.Equal(addon.Teleport.GetDungeonShortCode(2773, "deDE"), "SCH", "deDE should map OFG to SCH")
      Assert.Equal(addon.Teleport.GetDungeonShortCode(2660, "deDE"), "AK", "deDE should keep AK")
      Assert.Equal(addon.Teleport.GetDungeonShortCode(2441, "deDE"), "TAZ", "deDE should keep TAZ")
      Assert.Equal(addon.Teleport.GetDungeonShortCode(2662, "deDE"), "MB", "deDE should map DB to MB")
      Assert.Equal(
        addon.Teleport.GetDungeonShortCode(542, "deDE"),
        "BIO",
        "challenge-map alias should resolve to same localized short code list"
      )
      Assert.Equal(
        addon.Teleport.ResolveTeleportSpellIDByMapID(542),
        1237215,
        "challenge-map alias should resolve to canonical teleport spell"
      )
      Assert.Equal(addon.Teleport.GetDungeonShortCode(2649, "enUS"), "PSF", "enUS should keep PSF")
      Assert.Equal(
        addon.SeasonData.GetMapToTeleport()[2662],
        445414,
        "active season map->spell table should stay centralized"
      )
      Assert.Equal(
        addon.SeasonData.GetDungeonShortCode(2662, "frFR"),
        "DB",
        "unsupported locales should fallback to default"
      )
      Assert.Equal(
        addon.SeasonData.GetActiveSeasonID(),
        "test_season",
        "legacy season switch should work explicitly for mapping validation"
      )
      local orderedActiveMapIDs = addon.SeasonData.GetOrderedMapIDs()
      Assert.Equal(#orderedActiveMapIDs, 8, "active season ordered map list should include all mapped dungeons")
      Assert.Equal(orderedActiveMapIDs[1], 2287, "explicit season display order should place HOA first")
      Assert.Equal(orderedActiveMapIDs[2], 2441, "explicit season display order should keep Tazavesh slot stable")

      local availableSeasonIDs = addon.SeasonData.GetAvailableSeasonIDs()
      local hasPreparedMidnightSeason = false
      for _, seasonID in ipairs(availableSeasonIDs) do
        if seasonID == "midnight_s1" then
          hasPreparedMidnightSeason = true
          break
        end
      end
      Assert.True(hasPreparedMidnightSeason, "prepared midnight_s1 season scaffold should be registered")
      Assert.NotNil(
        next(addon.SeasonData.GetMapToTeleport("midnight_s1")),
        "midnight_s1 should expose filled live mappings once portal IDs are available"
      )
      Assert.Equal(
        #addon.SeasonData.GetOrderedMapIDs("midnight_s1"),
        8,
        "midnight_s1 should keep all 8 active ordered-map entries once mappings are provided"
      )
    end)
  end)

  test("Teleport returns locale-specific full dungeon names for deDE and enUS", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })

      Assert.Equal(
        addon.Teleport.GetDungeonName(250, "deDE"),
        "Tempel von Sethraliss",
        "deDE should resolve the localized full dungeon name"
      )
      Assert.Equal(
        addon.Teleport.GetDungeonName(250, "enUS"),
        "Temple of Sethraliss",
        "enUS should resolve the English full dungeon name"
      )
    end)
  end)

  test("Teleport active Midnight Season 2 exposes the locale-specific short codes", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })

      -- Season 1 used one short code per dungeon for both locales. Season 2 does
      -- not: the German client abbreviates the localized names, so enUS and deDE
      -- diverge for six of the eight dungeons and are asserted separately.
      local expectedShortCodes = {
        [249] = { enUS = "KR", deDE = "KR" },
        [250] = { enUS = "TOS", deDE = "TVS" },
        [399] = { enUS = "RLP", deDE = "RLB" },
        [584] = { enUS = "TBV", deDE = "DBT" },
        [585] = { enUS = "VA", deDE = "ADL" },
        [586] = { enUS = "DON", deDE = "NB" },
        [587] = { enUS = "MR", deDE = "MG" },
        [588] = { enUS = "AOF", deDE = "ADF" },
      }

      for mapID, expected in pairs(expectedShortCodes) do
        Assert.Equal(
          addon.Teleport.GetDungeonShortCode(mapID, "enUS"),
          expected.enUS,
          string.format("enUS short code for map %d should match the active season baseline", mapID)
        )
        Assert.Equal(
          addon.Teleport.GetDungeonShortCode(mapID, "deDE"),
          expected.deDE,
          string.format("deDE short code for map %d should match the active season baseline", mapID)
        )
      end
    end)
  end)

  test("Teleport active Midnight Season 2 resolves the deDE dungeon names", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })

      local expectedNames = {
        [249] = "Königsruh",
        [250] = "Tempel von Sethraliss",
        [399] = "Rubinlebensbecken",
        [584] = "Das blendende Tal",
        [585] = "Arena der Leerennarbe",
        [586] = "Nalorakks Bau",
        [587] = "Mördergasse",
        [588] = "Der Altar der Fänge",
      }

      for mapID, expectedName in pairs(expectedNames) do
        Assert.Equal(
          addon.Teleport.GetDungeonName(mapID, "deDE"),
          expectedName,
          string.format("deDE dungeon name for map %d should match the active season baseline", mapID)
        )
      end
    end)
  end)
end

local function RegisterTeleportResolverAliasTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Teleport resolves challenge-map IDs by static alias list before short-code rendering", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
      C_ChallengeMode = {
        GetMapUIInfo = function(mapID)
          local names = {
            [2441] = "Tazavesh: Streets of Wonder",
            [392] = "Tazavesh: Streets of Wonder",
            [2662] = "The Dawnbreaker",
            [505] = "The Dawnbreaker",
          }
          return names[mapID]
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
        "isiLive_sync.lua",
      })
      addon.SeasonData.SEASONS.test_season = {
        mapToTeleport = {
          [2649] = 445444,
          [2830] = 1237215,
          [2287] = 354465,
          [2773] = 1216786,
          [2660] = 445417,
          [2441] = 367416,
          [2442] = 367416,
          [2662] = 445414,
        },
        displayOrder = { 2287, 2441, 2442, 2649, 2660, 2662, 2773, 2830 },
        shortCodesByLocale = {
          default = {
            [2649] = "PSF",
            [2830] = "EDA",
            [2287] = "HOA",
            [2773] = "OFG",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "DB",
          },
          deDE = {
            [2649] = "PRI",
            [2830] = "BIO",
            [2287] = "HDS",
            [2773] = "SCH",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "MB",
          },
        },
        challengeMapAliases = {
          [378] = 2287,
          [391] = 2441,
          [392] = 2441,
          [499] = 2649,
          [503] = 2660,
          [505] = 2662,
          [525] = 2773,
          [542] = 2830,
        },
      }
      ActivateSeasonOrFail(Assert, addon, "test_season")

      Assert.Equal(
        addon.Teleport.GetDungeonShortCode(392, "deDE"),
        "TAZ",
        "challenge-map aliases resolved by map name should use localized short code"
      )
      Assert.Equal(
        addon.Teleport.GetDungeonShortCode(505, "deDE"),
        "MB",
        "challenge-map aliases resolved by map name should use dawnbreaker short code"
      )
      Assert.Equal(
        addon.Teleport.ResolveTeleportSpellIDByMapID(505),
        445414,
        "runtime map-name alias should resolve canonical teleport spell"
      )

      local keyChanged = addon.Sync.SetPlayerKeyInfo("Tester", "Realm", 505, 12)
      local keyInfo = addon.Sync.GetPlayerKeyInfo("Tester", "Realm")
      Assert.True(keyChanged, "sync key cache should accept first normalized challenge-map update")
      Assert.Equal(keyInfo and keyInfo.mapID, 2662, "sync key cache should store canonical map id after normalization")
    end)
  end)

  test("Teleport short-code resolver keeps unknown maps unresolved instead of showing map ids", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
      C_ChallengeMode = {
        GetMapUIInfo = function(_mapID)
          return "Mystery Dungeon Name"
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      local shortCode = addon.Teleport.GetDungeonShortCode(9999, "enUS")
      Assert.Nil(shortCode, "unknown maps should stay unresolved instead of showing numeric map ids")
    end)
  end)

  test("Teleport info keeps map name unresolved when API has no concrete name", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
      C_ChallengeMode = {
        GetMapUIInfo = function(_mapID)
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      addon.SeasonData.SEASONS.test_season = {
        mapToTeleport = {
          [2649] = 445444,
          [2830] = 1237215,
          [2287] = 354465,
          [2773] = 1216786,
          [2660] = 445417,
          [2441] = 367416,
          [2442] = 367416,
          [2662] = 445414,
        },
        displayOrder = { 2287, 2441, 2442, 2649, 2660, 2662, 2773, 2830 },
        shortCodesByLocale = {
          default = {
            [2649] = "PSF",
            [2830] = "EDA",
            [2287] = "HOA",
            [2773] = "OFG",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "DB",
          },
          deDE = {
            [2649] = "PRI",
            [2830] = "BIO",
            [2287] = "HDS",
            [2773] = "SCH",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "MB",
          },
        },
        challengeMapAliases = {
          [378] = 2287,
          [391] = 2441,
          [392] = 2441,
          [499] = 2649,
          [503] = 2660,
          [505] = 2662,
          [525] = 2773,
          [542] = 2830,
        },
      }
      ActivateSeasonOrFail(Assert, addon, "test_season")
      local info = addon.Teleport.GetTeleportInfoByMapID(2662)
      Assert.NotNil(info, "known map should still resolve teleport info")
      Assert.Nil(info.mapName, "map name must stay unresolved when API provides no concrete name")
    end)
  end)
end

local function RegisterTeleportResolverActivityTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Teleport resolves activity map and caches activity lookups", function()
    local createFrameStub = BuildCreateFrameStub()
    local activityInfoCalls = 0

    WithGlobals({
      CreateFrame = createFrameStub,
      C_LFGList = {
        GetActivityInfoTable = function(activityID)
          activityInfoCalls = activityInfoCalls + 1
          if activityID == 9900 then
            return { mapID = 2662 }
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      addon.SeasonData.SEASONS.test_season = {
        mapToTeleport = {
          [2649] = 445444,
          [2830] = 1237215,
          [2287] = 354465,
          [2773] = 1216786,
          [2660] = 445417,
          [2441] = 367416,
          [2442] = 367416,
          [2662] = 445414,
        },
        displayOrder = { 2287, 2441, 2442, 2649, 2660, 2662, 2773, 2830 },
        shortCodesByLocale = {
          default = {
            [2649] = "PSF",
            [2830] = "EDA",
            [2287] = "HOA",
            [2773] = "OFG",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "DB",
          },
          deDE = {
            [2649] = "PRI",
            [2830] = "BIO",
            [2287] = "HDS",
            [2773] = "SCH",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "MB",
          },
        },
        challengeMapAliases = {
          [378] = 2287,
          [391] = 2441,
          [392] = 2441,
          [499] = 2649,
          [503] = 2660,
          [505] = 2662,
          [525] = 2773,
          [542] = 2830,
        },
      }
      ActivateSeasonOrFail(Assert, addon, "test_season")
      local mapFirst = addon.Teleport.ResolveMapIDByActivityID(9900)
      local mapSecond = addon.Teleport.ResolveMapIDByActivityID(9900)
      local first = addon.Teleport.ResolveTeleportSpellIDByActivityID(9900)
      local second = addon.Teleport.ResolveTeleportSpellIDByActivityID(9900)
      local genericMap = addon.Teleport.ResolveMapIDByActivityID(9900)
      local genericActivitySpell = addon.Teleport.ResolveTeleportSpellIDByActivityID(9900)
      local genericMapSpell = addon.Teleport.ResolveTeleportSpellIDByMapID(2662)

      Assert.Equal(mapFirst, 2662, "activity map should resolve directly from activity info")
      Assert.Equal(mapSecond, 2662, "activity map resolver should use cached value")
      Assert.Equal(first, 445414, "activity map should resolve to mapped teleport spell")
      Assert.Equal(second, 445414, "cached activity map should keep same resolved spell")
      Assert.Equal(
        genericMap,
        2662,
        "generic activity map resolver should stay compatible with season-specific resolver"
      )
      Assert.Equal(
        genericActivitySpell,
        445414,
        "generic activity spell resolver should stay compatible with season-specific resolver"
      )
      Assert.Equal(
        genericMapSpell,
        445414,
        "generic map spell resolver should stay compatible with season-specific resolver"
      )
    end)

    Assert.Equal(activityInfoCalls, 1, "activity lookup should be cached after first successful resolve")
  end)

  test("Teleport does not resolve by dungeon name without activityID", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      local spellID = addon.Teleport.ResolveTeleportSpellID(nil, "Queue to Tazavesh Gambit")
      Assert.Nil(spellID, "name-only resolution must stay nil in strict mode")
    end)
  end)

  test("Teleport does not resolve localized dungeon names without activityID", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      local spellID = addon.Teleport.ResolveTeleportSpellID(nil, "Biokuppel Al'dani")
      Assert.Nil(spellID, "localized name-only resolution must stay nil in strict mode")
    end)
  end)
end

local function RegisterTeleportResolverRecoveryTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Teleport keeps activity unresolved when mapID is missing and retries unresolved lookups", function()
    local createFrameStub = BuildCreateFrameStub()
    local activityInfoCalls = 0

    WithGlobals({
      CreateFrame = createFrameStub,
      C_LFGList = {
        GetActivityInfoTable = function(activityID)
          activityInfoCalls = activityInfoCalls + 1
          if activityID == 9910 then
            return { fullName = "Biokuppel Al'dani" }
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      local first = addon.Teleport.ResolveTeleportSpellIDByActivityID(9910)
      local second = addon.Teleport.ResolveTeleportSpellIDByActivityID(9910)

      Assert.Nil(first, "activity without concrete mapID must remain unresolved")
      Assert.Nil(second, "unresolved activity result should stay nil")
    end)

    Assert.Equal(activityInfoCalls, 2, "unresolved map lookups should be retried (no negative cache lock)")
  end)

  test("Teleport unresolved activity lookup can recover when map data appears later", function()
    local createFrameStub = BuildCreateFrameStub()
    local activityInfoCalls = 0
    local exposeMap = false

    WithGlobals({
      CreateFrame = createFrameStub,
      C_LFGList = {
        GetActivityInfoTable = function(activityID)
          activityInfoCalls = activityInfoCalls + 1
          if activityID ~= 9911 then
            return nil
          end
          if exposeMap then
            return { mapID = 2662 }
          end
          return { fullName = "Late Map Payload" }
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      addon.SeasonData.SEASONS.test_season = {
        mapToTeleport = {
          [2649] = 445444,
          [2830] = 1237215,
          [2287] = 354465,
          [2773] = 1216786,
          [2660] = 445417,
          [2441] = 367416,
          [2442] = 367416,
          [2662] = 445414,
        },
        displayOrder = { 2287, 2441, 2442, 2649, 2660, 2662, 2773, 2830 },
        shortCodesByLocale = {
          default = {
            [2649] = "PSF",
            [2830] = "EDA",
            [2287] = "HOA",
            [2773] = "OFG",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "DB",
          },
          deDE = {
            [2649] = "PRI",
            [2830] = "BIO",
            [2287] = "HDS",
            [2773] = "SCH",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "MB",
          },
        },
        challengeMapAliases = {
          [378] = 2287,
          [391] = 2441,
          [392] = 2441,
          [499] = 2649,
          [503] = 2660,
          [505] = 2662,
          [525] = 2773,
          [542] = 2830,
        },
      }
      ActivateSeasonOrFail(Assert, addon, "test_season")

      local first = addon.Teleport.ResolveTeleportSpellIDByActivityID(9911)
      Assert.Nil(first, "first resolve must stay nil while map data is missing")

      exposeMap = true
      local second = addon.Teleport.ResolveTeleportSpellIDByActivityID(9911)
      Assert.Equal(second, 445414, "resolver must recover once concrete map data appears")
    end)

    Assert.Equal(activityInfoCalls, 2, "resolver should query activity info again after unresolved first attempt")
  end)
end

local function RegisterTeleportEntryAndCombatTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Teleport entry builder de-duplicates shared spells for grid rendering", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
      C_ChallengeMode = {
        GetMapUIInfo = function(mapID)
          return "Map-" .. tostring(mapID)
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      addon.SeasonData.SEASONS.test_season = {
        mapToTeleport = {
          [2649] = 445444,
          [2830] = 1237215,
          [2287] = 354465,
          [2773] = 1216786,
          [2660] = 445417,
          [2441] = 367416,
          [2442] = 367416,
          [2662] = 445414,
        },
        displayOrder = { 2287, 2441, 2442, 2649, 2660, 2662, 2773, 2830 },
        shortCodesByLocale = {
          default = {
            [2649] = "PSF",
            [2830] = "EDA",
            [2287] = "HOA",
            [2773] = "OFG",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "DB",
          },
          deDE = {
            [2649] = "PRI",
            [2830] = "BIO",
            [2287] = "HDS",
            [2773] = "SCH",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "MB",
          },
        },
        challengeMapAliases = {
          [378] = 2287,
          [391] = 2441,
          [392] = 2441,
          [499] = 2649,
          [503] = 2660,
          [505] = 2662,
          [525] = 2773,
          [542] = 2830,
        },
      }
      ActivateSeasonOrFail(Assert, addon, "test_season")
      local entries = addon.Teleport.BuildTeleportEntries()
      local genericEntries = addon.Teleport.BuildTeleportEntries()
      local expectedMapOrder = { 2287, 2441, 2649, 2660, 2662, 2773, 2830 }

      local sharedSpellCount = 0
      for index, info in ipairs(entries) do
        if info.spellID == 367416 then
          sharedSpellCount = sharedSpellCount + 1
        end
        Assert.Equal(
          info.mapID,
          expectedMapOrder[index],
          "teleport entries should keep deterministic slot order by canonical map sequence"
        )
      end

      Assert.Equal(#entries, 7, "8 maps with one shared spell should render as 7 unique teleport entries")
      Assert.Equal(
        #genericEntries,
        #entries,
        "generic teleport entry builder should mirror legacy season-specific behavior"
      )
      Assert.Equal(sharedSpellCount, 1, "shared teleport spell should appear exactly once")
    end)
  end)

  test("Teleport secure button updates are deferred during combat and applied after regen", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local inCombat = true

    local attributes = {}
    local button = {
      SetAttribute = function(_self, key, value)
        attributes[key] = value
      end,
      EnableMouse = function(_self, value)
        attributes.enableMouse = value
      end,
    }

    WithGlobals({
      CreateFrame = createFrameStub,
      InCombatLockdown = function()
        return inCombat
      end,
      C_Spell = {
        GetSpellName = function(spellID)
          return "Spell-" .. tostring(spellID)
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      local appliedInCombat = addon.Teleport.ApplySecureSpellToButton(button, 445414)
      Assert.False(appliedInCombat, "secure button update should defer during combat lockdown")
      Assert.Equal(#createdFrames, 1, "combat retry frame should be created once")
      Assert.True(
        createdFrames[1]:IsEventRegistered("PLAYER_REGEN_ENABLED"),
        "combat retry frame should register PLAYER_REGEN_ENABLED"
      )

      inCombat = false
      createdFrames[1]:FireEvent("PLAYER_REGEN_ENABLED")
      Assert.Equal(attributes.spell, "Spell-445414", "deferred update should apply spell attribute after combat")
      Assert.True(attributes.enableMouse, "deferred update should restore mouse interactions")
      -- PLAYER_REGEN_ENABLED stays registered after drain: the frame is statically
      -- registered at module load to avoid dynamic RegisterEvent from protected
      -- dispatch (ADDON_ACTION_FORBIDDEN in 12.0+). OnEvent early-returns when the
      -- pending queue is empty.
      Assert.True(
        createdFrames[1]:IsEventRegistered("PLAYER_REGEN_ENABLED"),
        "retry frame keeps PLAYER_REGEN_ENABLED registered (static registration)"
      )
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterTeleportResolverCoreTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportResolverAliasTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportResolverActivityTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportResolverRecoveryTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportEntryAndCombatTests(test, Assert, WithGlobals, LoadAddonModules)
end
