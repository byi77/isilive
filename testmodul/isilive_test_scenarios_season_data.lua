---@diagnostic disable: undefined-global

-- Branch-coverage scenarios for game/isiLive_season_data.lua. Targets the
-- readiness validator (every error/warning branch), the data-shape error
-- paths in SetActiveSeasonID, and the locale fallbacks in GetDungeonName /
-- GetInactivePortalMessage / GetShortCodes / GetDungeonShortCode.

local function LoadSeasonData(LoadAddonModules)
  return LoadAddonModules({ "isiLive_season_data.lua" })
end

local function findError(readiness, needle)
  for _, line in ipairs(readiness.errors or {}) do
    if string.find(line, needle, 1, true) then
      return line
    end
  end
  return nil
end

local function findWarning(readiness, needle)
  for _, line in ipairs(readiness.warnings or {}) do
    if string.find(line, needle, 1, true) then
      return line
    end
  end
  return nil
end

local function RegisterReadinessTests(test, Assert, LoadAddonModules)
  test("SeasonData.GetSeasonReadiness reports unknown-season error for missing season id", function()
    local addon = LoadSeasonData(LoadAddonModules)
    local readiness = addon.SeasonData.GetSeasonReadiness("does_not_exist")
    Assert.False(readiness.isReady, "unknown season must not be ready")
    Assert.NotNil(
      findError(readiness, "Unknown season id 'does_not_exist'"),
      "unknown season must surface an Unknown-season-id error"
    )
  end)

  test("SeasonData.GetSeasonReadiness flags non-table mapToTeleport", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_season = {
      label = "Test",
      mapToTeleport = "not-a-table",
      shortCodesByLocale = { default = {} },
      displayOrder = {},
      challengeMapAliases = {},
    }
    local readiness = addon.SeasonData.GetSeasonReadiness("test_season")
    Assert.False(readiness.isReady, "non-table mapToTeleport must not be ready")
    Assert.NotNil(findError(readiness, "mapToTeleport must be a table"), "must flag non-table mapToTeleport")
  end)

  test("SeasonData.GetSeasonReadiness flags empty mapToTeleport", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_season = {
      label = "Test",
      mapToTeleport = {},
      shortCodesByLocale = { default = {} },
      displayOrder = {},
      challengeMapAliases = {},
    }
    local readiness = addon.SeasonData.GetSeasonReadiness("test_season")
    Assert.NotNil(findError(readiness, "mapToTeleport is empty"), "empty mapToTeleport must surface an error")
  end)

  test("SeasonData keeps prepared Midnight Season 2 scaffold inactive until verified IDs exist", function()
    local addon = LoadSeasonData(LoadAddonModules)
    local readiness = addon.SeasonData.GetSeasonReadiness("midnight_s2")
    Assert.Equal(addon.SeasonData.GetActiveSeasonID(), "midnight_s1", "prepared S2 scaffold must not be active")
    Assert.False(readiness.isReady, "prepared S2 scaffold must fail readiness until verified IDs exist")
    Assert.Equal(readiness.mappedDungeonCount, 0, "prepared S2 scaffold must not expose guessed map IDs")
    Assert.NotNil(findError(readiness, "mapToTeleport is empty"), "prepared S2 scaffold must stay blocked by empty map data")
    Assert.Equal(
      addon.SeasonData.GetInactivePortalMessage("deDE", "midnight_s2"),
      "Midnight-Season-2-Portaldaten sind noch nicht verifiziert.",
      "prepared S2 scaffold should expose a German inactive message"
    )
  end)

  test("SeasonData.GetSeasonReadiness flags non-table shortCodesByLocale.default", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_season = {
      label = "Test",
      mapToTeleport = { [2662] = 445414 },
      shortCodesByLocale = { default = "not-a-table" },
      displayOrder = { 2662 },
      challengeMapAliases = {},
    }
    local readiness = addon.SeasonData.GetSeasonReadiness("test_season")
    Assert.NotNil(
      findError(readiness, "shortCodesByLocale.default must be a table"),
      "non-table default short codes must surface an error"
    )
  end)

  test("SeasonData.GetSeasonReadiness flags non-numeric mapToTeleport keys", function()
    -- displayOrder is set non-table so the (separate) "displayOrder is missing
    -- mapped map id %d" warning loop is skipped — that loop format-strings
    -- every key with %d and would otherwise crash on the string key here.
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_season = {
      label = "Test",
      mapToTeleport = { ["not-a-number"] = 1 },
      shortCodesByLocale = { default = {} },
      displayOrder = "not-a-table",
      challengeMapAliases = {},
    }
    local readiness = addon.SeasonData.GetSeasonReadiness("test_season")
    Assert.NotNil(findError(readiness, "non-numeric map id key 'not-a-number'"), "non-numeric key must be flagged")
  end)

  test("SeasonData.GetSeasonReadiness flags non-positive spell, invalid spell list, wrong-type spell value", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_season = {
      label = "Test",
      mapToTeleport = {
        [100] = 0, -- non-positive spell
        [101] = { -1, -2 }, -- list with no valid entries
        [102] = "string", -- wrong type
      },
      shortCodesByLocale = { default = {} },
      displayOrder = {},
      challengeMapAliases = {},
    }
    local readiness = addon.SeasonData.GetSeasonReadiness("test_season")
    Assert.NotNil(
      findError(readiness, "mapToTeleport[100] must be a positive spell id"),
      "non-positive spell must be flagged"
    )
    Assert.NotNil(
      findError(readiness, "mapToTeleport[101] list must contain at least one valid spell id"),
      "all-negative spell list must be flagged"
    )
    Assert.NotNil(
      findError(readiness, "mapToTeleport[102] must be a spell id number or list of spell ids"),
      "string spell value must be flagged"
    )
  end)

  test(
    "SeasonData.GetSeasonReadiness flags missing default short code and warns about missing deDE short code",
    function()
      local addon = LoadSeasonData(LoadAddonModules)
      addon.SeasonData.SEASONS.test_season = {
        label = "Test",
        mapToTeleport = { [2662] = 445414 },
        shortCodesByLocale = { default = {}, deDE = {} },
        displayOrder = { 2662 },
        challengeMapAliases = {},
      }
      local readiness = addon.SeasonData.GetSeasonReadiness("test_season")
      Assert.NotNil(
        findError(readiness, "shortCodesByLocale.default is missing map id 2662"),
        "missing default short code must error"
      )
      Assert.NotNil(
        findWarning(readiness, "shortCodesByLocale.deDE is missing map id 2662"),
        "missing deDE short code must warn (not error)"
      )
    end
  )

  test("SeasonData.GetSeasonReadiness flags non-table displayOrder, non-numeric entry, and unknown map id", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_season = {
      label = "Test",
      mapToTeleport = { [2662] = 445414 },
      shortCodesByLocale = { default = { [2662] = "DB" } },
      displayOrder = "not-a-table",
      challengeMapAliases = {},
    }
    local readiness1 = addon.SeasonData.GetSeasonReadiness("test_season")
    Assert.NotNil(findError(readiness1, "displayOrder must be a table"), "non-table displayOrder must error")

    addon.SeasonData.SEASONS.test_season.displayOrder = { "abc", 9999 }
    local readiness2 = addon.SeasonData.GetSeasonReadiness("test_season")
    Assert.NotNil(
      findError(readiness2, "displayOrder contains non-numeric map id 'abc'"),
      "non-numeric displayOrder entry must error"
    )
    Assert.NotNil(
      findError(readiness2, "displayOrder contains unknown map id 9999"),
      "displayOrder entry not in mapToTeleport must error"
    )
  end)

  test("SeasonData.GetSeasonReadiness warns about mapToTeleport entries missing from displayOrder", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_season = {
      label = "Test",
      mapToTeleport = { [2662] = 445414, [2649] = 445444 },
      shortCodesByLocale = { default = { [2662] = "DB", [2649] = "PSF" } },
      displayOrder = { 2662 }, -- 2649 missing
      challengeMapAliases = {},
    }
    local readiness = addon.SeasonData.GetSeasonReadiness("test_season")
    Assert.NotNil(
      findWarning(readiness, "displayOrder is missing mapped map id 2649"),
      "missing mapped map id in displayOrder must warn"
    )
  end)

  test("SeasonData.GetSeasonReadiness flags non-table aliases, non-numeric keys, and unmapped canonical id", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_season = {
      label = "Test",
      mapToTeleport = { [2662] = 445414 },
      shortCodesByLocale = { default = { [2662] = "DB" } },
      displayOrder = { 2662 },
      challengeMapAliases = "not-a-table",
    }
    local readiness1 = addon.SeasonData.GetSeasonReadiness("test_season")
    Assert.NotNil(findError(readiness1, "challengeMapAliases must be a table"), "non-table aliases must error")

    addon.SeasonData.SEASONS.test_season.challengeMapAliases = {
      ["abc"] = 2662, -- non-numeric alias key
      [505] = "xyz", -- non-numeric canonical
      [499] = 9999, -- unmapped canonical
    }
    local readiness2 = addon.SeasonData.GetSeasonReadiness("test_season")
    Assert.NotNil(
      findError(readiness2, "challengeMapAliases contains non-numeric alias key 'abc'"),
      "non-numeric alias key must error"
    )
    Assert.NotNil(
      findError(readiness2, "challengeMapAliases[505] contains non-numeric canonical map id"),
      "non-numeric canonical must error"
    )
    Assert.NotNil(
      findError(readiness2, "challengeMapAliases[499] points to unmapped canonical map id 9999"),
      "unmapped canonical must error"
    )
  end)
end

local function RegisterSetActiveSeasonIDTests(test, Assert, LoadAddonModules)
  test("SeasonData.SetActiveSeasonID rejects unknown season with explanatory error string", function()
    local addon = LoadSeasonData(LoadAddonModules)
    local ok, err = addon.SeasonData.SetActiveSeasonID("does_not_exist")
    Assert.False(ok, "unknown season must be rejected")
    Assert.True(
      string.find(tostring(err), "Unknown season id 'does_not_exist'", 1, true) ~= nil,
      "error must name the unknown id"
    )
  end)

  test("SeasonData.SetActiveSeasonID rejects unready season unless allowIncomplete=true", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_season = {
      label = "Test",
      mapToTeleport = {}, -- empty → readiness = not ready
      shortCodesByLocale = { default = {} },
      displayOrder = {},
      challengeMapAliases = {},
    }
    local ok1, err1 = addon.SeasonData.SetActiveSeasonID("test_season")
    Assert.False(ok1, "unready season must be rejected by default")
    Assert.True(string.find(tostring(err1), "is not ready", 1, true) ~= nil, "error must mention readiness")

    -- allowIncomplete=true overrides the readiness gate.
    local ok2 = addon.SeasonData.SetActiveSeasonID("test_season", { allowIncomplete = true })
    Assert.True(ok2, "allowIncomplete=true must accept an unready season")
  end)
end

local function RegisterAccessorFallbackTests(test, Assert, LoadAddonModules)
  test("SeasonData.GetSeasonLabel falls back to tostring(seasonID) for unknown season", function()
    local addon = LoadSeasonData(LoadAddonModules)
    Assert.Equal(addon.SeasonData.GetSeasonLabel("does_not_exist"), "does_not_exist", "unknown season returns its id")
  end)

  test("SeasonData.GetSeasonLabel falls back to tostring(seasonID) when label is missing or empty", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_no_label = { mapToTeleport = {} }
    Assert.Equal(addon.SeasonData.GetSeasonLabel("test_no_label"), "test_no_label", "missing label returns id")
    addon.SeasonData.SEASONS.test_empty_label = { label = "", mapToTeleport = {} }
    Assert.Equal(addon.SeasonData.GetSeasonLabel("test_empty_label"), "test_empty_label", "empty label returns id")
  end)

  test("SeasonData.GetMapToTeleport returns empty table for unknown season", function()
    local addon = LoadSeasonData(LoadAddonModules)
    local result = addon.SeasonData.GetMapToTeleport("does_not_exist")
    Assert.True(type(result) == "table", "must return a table")
    Assert.True(next(result) == nil, "must be empty for unknown season")
  end)

  test("SeasonData.GetOrderedMapIDs returns empty table for unknown season", function()
    local addon = LoadSeasonData(LoadAddonModules)
    local ordered = addon.SeasonData.GetOrderedMapIDs("does_not_exist")
    Assert.True(type(ordered) == "table" and next(ordered) == nil, "must be empty for unknown season")
  end)

  test("SeasonData.GetOrderedMapIDs honours displayOrder and appends unmentioned maps in sorted order", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_season = {
      mapToTeleport = { [2662] = 1, [2649] = 1, [2287] = 1, [2773] = 1 },
      displayOrder = { 2662, 2649 }, -- 2287 and 2773 missing → appended sorted
      shortCodesByLocale = { default = {} },
      challengeMapAliases = {},
    }
    local ordered = addon.SeasonData.GetOrderedMapIDs("test_season")
    Assert.Equal(ordered[1], 2662, "first explicit entry preserved")
    Assert.Equal(ordered[2], 2649, "second explicit entry preserved")
    Assert.Equal(ordered[3], 2287, "remaining maps must be appended sorted ascending")
    Assert.Equal(ordered[4], 2773, "remaining maps must be appended sorted ascending")
  end)

  test("SeasonData.GetShortCodes returns empty table for unknown season", function()
    local addon = LoadSeasonData(LoadAddonModules)
    local result = addon.SeasonData.GetShortCodes("enUS", "does_not_exist")
    Assert.True(type(result) == "table" and next(result) == nil, "must be empty for unknown season")
  end)

  test("SeasonData.GetDungeonShortCode returns nil when mapID does not normalize", function()
    local addon = LoadSeasonData(LoadAddonModules)
    Assert.Nil(addon.SeasonData.GetDungeonShortCode("not-a-number"), "non-numeric mapID returns nil")
  end)

  test("SeasonData.GetDungeonName returns nil for unknown season", function()
    local addon = LoadSeasonData(LoadAddonModules)
    Assert.Nil(addon.SeasonData.GetDungeonName(2662, "enUS", "does_not_exist"), "unknown season returns nil")
  end)

  test("SeasonData.GetDungeonName returns nil when mapID does not normalize", function()
    local addon = LoadSeasonData(LoadAddonModules)
    Assert.Nil(addon.SeasonData.GetDungeonName("not-a-number"), "non-numeric mapID returns nil")
  end)

  test("SeasonData.GetDungeonName falls back to enUS when locale lookup misses", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_season = {
      mapToTeleport = { [2662] = 445414 },
      shortCodesByLocale = { default = { [2662] = "DB" } },
      displayOrder = { 2662 },
      challengeMapAliases = {},
      namesByLocale = {
        enUS = { [2662] = "The Dawnbreaker" },
        deDE = {}, -- missing
      },
    }
    Assert.Equal(
      addon.SeasonData.GetDungeonName(2662, "deDE", "test_season"),
      "The Dawnbreaker",
      "deDE miss must fall back to enUS"
    )
  end)

  test("SeasonData.GetInactivePortalMessage returns nil when season is unknown", function()
    local addon = LoadSeasonData(LoadAddonModules)
    Assert.Nil(addon.SeasonData.GetInactivePortalMessage("enUS", "does_not_exist"), "unknown season returns nil")
  end)

  test("SeasonData.GetInactivePortalMessage prefers locale string and falls back to default", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_season = {
      mapToTeleport = {},
      shortCodesByLocale = { default = {} },
      displayOrder = {},
      challengeMapAliases = {},
      inactivePortalMessageByLocale = {
        default = "Default message",
        deDE = "Deutsche Nachricht",
      },
    }
    Assert.Equal(
      addon.SeasonData.GetInactivePortalMessage("deDE", "test_season"),
      "Deutsche Nachricht",
      "locale match wins over default"
    )
    Assert.Equal(
      addon.SeasonData.GetInactivePortalMessage("frFR", "test_season"),
      "Default message",
      "missing locale falls back to default"
    )
  end)

  test("SeasonData.GetInactivePortalMessage returns nil when neither locale nor default is set", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_season = {
      mapToTeleport = {},
      shortCodesByLocale = { default = {} },
      displayOrder = {},
      challengeMapAliases = {},
    }
    Assert.Nil(
      addon.SeasonData.GetInactivePortalMessage("enUS", "test_season"),
      "no message in any locale must return nil"
    )
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  RegisterReadinessTests(test, Assert, LoadAddonModules)
  RegisterSetActiveSeasonIDTests(test, Assert, LoadAddonModules)
  RegisterAccessorFallbackTests(test, Assert, LoadAddonModules)
end
