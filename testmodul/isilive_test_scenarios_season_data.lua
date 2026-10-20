---@diagnostic disable: undefined-global

-- Branch-coverage scenarios for game/isiLive_season_data.lua. Targets the
-- readiness validator (every error/warning branch), the data-shape error
-- paths in SetActiveSeasonID, and the locale fallbacks in GetDungeonName /
-- GetInactivePortalMessage / GetShortCodes / GetDungeonShortCode.

local function LoadSeasonData(LoadAddonModules)
  return LoadAddonModules({ "isiLive_season_data.lua" })
end

local FixtureSeasons = assert(loadfile("testmodul/isilive_test_fixture_seasons.lua"))()
local FIXTURE_PREV = FixtureSeasons.PREVIOUS_SEASON_ID

-- Production manifest plus the synthetic non-active fixture season. Tests that
-- need "another season" use it, so retiring a real season never breaks them.
local function LoadSeasonDataWithFixture(LoadAddonModules)
  return FixtureSeasons.Install(LoadSeasonData(LoadAddonModules))
end

-- The harness always loads data/isiLive_seasons.lua as a dependency, which
-- replaces a seeded SeasonManifest. Recompile SeasonData against the given
-- manifest on top of the loaded modules instead.
local function LoadSeasonDataWithManifest(LoadAddonModules, manifest)
  local addon = LoadSeasonData(LoadAddonModules)
  addon.SeasonManifest = manifest
  local chunk = assert(loadfile("game/isiLive_season_data.lua"))
  chunk("isiLive", addon)
  return addon
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
  -- SetActiveSeasonID and TryAutoSelectSeasonFromChallengeMapIDs report
  -- readiness.errors[1] to the user as *the* reason a season is not ready. Most
  -- of the readiness entries are appended while iterating maps with `pairs`, so
  -- without an explicit ordering that first entry is whichever key the hash
  -- happened to yield first -- the message can differ between two runs over
  -- identical data, which makes a support report unreproducible.
  --
  -- Note the rest of this file only ever reaches errors via findError(); the
  -- suite has always treated the order as unreliable while production indexed
  -- into it.
  test("SeasonData.GetSeasonReadiness returns errors and warnings in a stable order", function()
    local addon = LoadSeasonData(LoadAddonModules)
    -- Several simultaneous failures whose insertion order is driven by `pairs`
    -- over a numeric-keyed map: every entry here yields both a bad-spell error
    -- and a missing-short-code error.
    addon.SeasonData.SEASONS.test_season = {
      label = "Test",
      mapToTeleport = {
        [101] = -1,
        [202] = -2,
        [303] = -3,
        [404] = -4,
        [505] = -5,
        [606] = -6,
        [707] = -7,
        [808] = -8,
      },
      shortCodesByLocale = { default = {}, deDE = {} },
      namesByLocale = { enUS = {}, deDE = {} },
      displayOrder = {},
      challengeMapAliases = {},
    }

    local first = addon.SeasonData.GetSeasonReadiness("test_season")
    Assert.True(#first.errors > 1, "scenario must produce several errors, otherwise it proves nothing")
    Assert.True(#first.warnings > 1, "scenario must produce several warnings, otherwise it proves nothing")

    -- Sorted output is the contract: it is reproducible across runs and across
    -- Lua versions, which "whatever pairs yielded" is not.
    local sortedErrors = {}
    for index, value in ipairs(first.errors) do
      sortedErrors[index] = value
    end
    table.sort(sortedErrors)
    for index, value in ipairs(sortedErrors) do
      Assert.Equal(first.errors[index], value, "errors must be returned in sorted order")
    end

    local sortedWarnings = {}
    for index, value in ipairs(first.warnings) do
      sortedWarnings[index] = value
    end
    table.sort(sortedWarnings)
    for index, value in ipairs(sortedWarnings) do
      Assert.Equal(first.warnings[index], value, "warnings must be returned in sorted order")
    end

    -- Repeated calls must agree on the first entry, since that is the one the
    -- user is shown.
    local second = addon.SeasonData.GetSeasonReadiness("test_season")
    Assert.Equal(second.errors[1], first.errors[1], "errors[1] must be stable across calls")
    Assert.Equal(second.warnings[1], first.warnings[1], "warnings[1] must be stable across calls")
  end)

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

  -- What is asserted is that a non-active season stays fully described and
  -- manually selectable, which is the property that matters when Blizzard's map
  -- table and the manifest ever disagree. The non-active season is the synthetic
  -- fixture, so the test survives retiring any real season from the manifest.
  test("SeasonData keeps a non-active season manually activatable", function()
    local addon = LoadSeasonDataWithFixture(LoadAddonModules)
    local liveSeasonID = addon.SeasonManifest.activeSeasonID
    local readiness = addon.SeasonData.GetSeasonReadiness(FIXTURE_PREV)
    Assert.Equal(addon.SeasonData.GetActiveSeasonID(), liveSeasonID, "the manifest season is the active season")
    Assert.True(readiness.isReady, "the non-active season must stay fully described")
    Assert.Equal(
      readiness.mappedDungeonCount,
      #FixtureSeasons.MapIDs(),
      "the non-active season must expose all its map mappings"
    )
    local ok = addon.SeasonData.SetActiveSeasonID(FIXTURE_PREV)
    Assert.True(ok, "manual activation of the non-active season must remain possible as the fallback")
    Assert.Equal(addon.SeasonData.GetActiveSeasonID(), FIXTURE_PREV, "manual activation must select it")
    Assert.Nil(
      addon.SeasonData.GetInactivePortalMessage("deDE", "midnight_s2"),
      "a live season with mapped dungeons carries no prepared-season empty-state message"
    )
  end)

  test("SeasonData.GetMatchingForcesData exposes only the active season DB", function()
    local addon = LoadSeasonDataWithFixture(LoadAddonModules)
    addon.MPlusForces = {
      season = "midnight_s2",
      expiresAt = "2099-01-01",
      dungeonTotal = {},
      byNpcId = {},
    }
    Assert.NotNil(
      addon.SeasonData.GetMatchingForcesData(nil, { currentDate = "2026-07-27" }),
      "active S2 must receive its matching Forces DB"
    )

    local ok = addon.SeasonData.SetActiveSeasonID(FIXTURE_PREV)
    Assert.True(ok, "manual activation of another season must succeed for the season-match test")
    Assert.Nil(
      addon.SeasonData.GetMatchingForcesData(nil, { currentDate = "2026-07-27" }),
      "S2 Forces must be hidden while another season is active"
    )

    addon.MPlusForces = {
      season = FIXTURE_PREV,
      expiresAt = "2099-01-01",
      dungeonTotal = {},
      byNpcId = {},
    }
    Assert.NotNil(
      addon.SeasonData.GetMatchingForcesData(nil, { currentDate = "2026-07-27" }),
      "Forces matching the newly active season must become available"
    )
  end)

  test("SeasonData.GetMatchingForcesData rejects expired or unverifiable forces data", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.MPlusForces = {
      season = "midnight_s2",
      expiresAt = "2026-08-07",
      dungeonTotal = {},
      byNpcId = {},
    }

    Assert.NotNil(
      addon.SeasonData.GetMatchingForcesData(nil, { currentDate = "2026-08-07" }),
      "Forces data must remain usable through its exact expiry date"
    )
    Assert.Nil(
      addon.SeasonData.GetMatchingForcesData(nil, { currentDate = "2026-08-08" }),
      "expired Forces data must be hidden from every runtime consumer"
    )

    addon.MPlusForces.expiresAt = "2026-02-30"
    Assert.Nil(
      addon.SeasonData.GetMatchingForcesData(nil, { currentDate = "2026-02-28" }),
      "an impossible expiry date must remain unresolved"
    )
    addon.MPlusForces.expiresAt = "2099-01-01"
    Assert.Nil(
      addon.SeasonData.GetMatchingForcesData(nil, { currentDate = "not-a-date" }),
      "an unverifiable current date must fail closed"
    )
  end)

  test("SeasonData marks only Midnight native dungeons with level 90 portal gates", function()
    local addon = LoadSeasonDataWithFixture(LoadAddonModules)
    -- Compiler behavior on a season with both kinds of dungeons ...
    for _, mapID in ipairs(FixtureSeasons.NativeMapIDs()) do
      Assert.Equal(
        addon.SeasonData.GetMinimumPlayerLevel(mapID, FIXTURE_PREV),
        90,
        "a dungeon with an explicit minimumPlayerLevel must carry the level-90 portal gate"
      )
    end
    for _, mapID in ipairs(FixtureSeasons.LegacyMapIDs()) do
      Assert.Nil(
        addon.SeasonData.GetMinimumPlayerLevel(mapID, FIXTURE_PREV),
        "returning legacy dungeons must not inherit the level-90 portal gate"
      )
    end
    -- ... and the approved production data of the live season.
    for _, mapID in ipairs({ 584, 585, 586, 587, 588 }) do
      Assert.Equal(
        addon.SeasonData.GetMinimumPlayerLevel(mapID, "midnight_s2"),
        90,
        "new Midnight Season 2 dungeons require player level 90"
      )
    end
    for _, mapID in ipairs({ 249, 399, 250 }) do
      Assert.Nil(
        addon.SeasonData.GetMinimumPlayerLevel(mapID, "midnight_s2"),
        "returning Season 2 dungeons must not inherit the level-90 portal gate"
      )
    end
  end)

  test("SeasonData Midnight Season 2 exposes approved English and German display metadata", function()
    local addon = LoadSeasonData(LoadAddonModules)
    local expectedDefaultCodes = {
      [588] = "AOF",
      [587] = "MR",
      [586] = "DON",
      [584] = "TBV",
      [585] = "VA",
      [249] = "KR",
      [399] = "RLP",
      [250] = "TOS",
    }
    local expectedGermanCodes = {
      [588] = "ADF",
      [587] = "MG",
      [586] = "NB",
      [584] = "DBT",
      [585] = "ADL",
      [249] = "KR",
      [399] = "RLB",
      [250] = "TVS",
    }
    local expectedEnglishNames = {
      [588] = "Altar of Fangs",
      [587] = "Murder Row",
      [586] = "Den of Nalorakk",
      [584] = "The Blinding Vale",
      [585] = "Voidscar Arena",
      [249] = "King's Rest",
      [399] = "Ruby Life Pools",
      [250] = "Temple of Sethraliss",
    }
    local expectedGermanNames = {
      [588] = "Der Altar der Fänge",
      [587] = "Mördergasse",
      [586] = "Nalorakks Bau",
      [584] = "Das blendende Tal",
      [585] = "Arena der Leerennarbe",
      [249] = "Königsruh",
      [399] = "Rubinlebensbecken",
      [250] = "Tempel von Sethraliss",
    }

    for mapID, code in pairs(expectedDefaultCodes) do
      Assert.Equal(addon.SeasonData.GetDungeonShortCode(mapID, "enUS", "midnight_s2"), code, "default S2 code")
      Assert.Equal(
        addon.SeasonData.GetDungeonShortCode(mapID, "frFR", "midnight_s2"),
        code,
        "other locales use default S2 code"
      )
      Assert.Equal(
        addon.SeasonData.GetDungeonShortCode(mapID, "deDE", "midnight_s2"),
        expectedGermanCodes[mapID],
        "German S2 code"
      )
      Assert.Equal(
        addon.SeasonData.GetDungeonName(mapID, "enUS", "midnight_s2"),
        expectedEnglishNames[mapID],
        "English S2 name"
      )
      Assert.Equal(
        addon.SeasonData.GetDungeonName(mapID, "deDE", "midnight_s2"),
        expectedGermanNames[mapID],
        "German S2 name"
      )
    end
    local ordered = addon.SeasonData.GetOrderedMapIDs("midnight_s2")
    local expectedOrder = { 249, 250, 399, 584, 585, 586, 587, 588 }
    for index, mapID in ipairs(expectedOrder) do
      Assert.Equal(ordered[index], mapID, "S2 display order must remain ascending by map ID")
    end
  end)

  test("SeasonData Midnight Season 2 maps verified challenge IDs to castable portal spells", function()
    local addon = LoadSeasonData(LoadAddonModules)
    local mappings = addon.SeasonData.GetMapToTeleport("midnight_s2")
    local expected = {
      [588] = 1286812,
      [587] = 1286809,
      [586] = 1286807,
      [584] = 1286801,
      [585] = 1286804,
      [249] = 1286831,
      [399] = 393256,
      [250] = 1286828,
    }

    local mappingCount = 0
    for _ in pairs(mappings) do
      mappingCount = mappingCount + 1
    end
    for mapID, spellID in pairs(expected) do
      Assert.Equal(mappings[mapID], spellID, "S2 mapping must preserve the approved castable portal spell")
    end
    Assert.Equal(mappingCount, 8, "the S2 map must contain exactly the eight approved mappings")
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

  test("SeasonData.GetSeasonReadiness flags missing English and German dungeon names", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_season = {
      label = "Test",
      mapToTeleport = { [2662] = 445414 },
      shortCodesByLocale = { default = { [2662] = "DB" } },
      namesByLocale = { enUS = {}, deDE = {} },
      displayOrder = { 2662 },
      challengeMapAliases = {},
    }
    local readiness = addon.SeasonData.GetSeasonReadiness("test_season")
    Assert.NotNil(
      findError(readiness, "namesByLocale.enUS is missing map id 2662"),
      "missing English dungeon name must block readiness"
    )
    Assert.NotNil(
      findError(readiness, "namesByLocale.deDE is missing map id 2662"),
      "missing German dungeon name must block readiness"
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

  test("SeasonData.GetSeasonReadiness warns when the deDE short-code table is missing", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_season = {
      label = "Test",
      mapToTeleport = { [2662] = 445414 },
      shortCodesByLocale = { default = { [2662] = "DB" } },
      namesByLocale = { enUS = { [2662] = "Test" }, deDE = { [2662] = "Test" } },
      displayOrder = { 2662 },
      challengeMapAliases = {},
    }
    local readiness = addon.SeasonData.GetSeasonReadiness("test_season")
    Assert.NotNil(
      findWarning(readiness, "shortCodesByLocale.deDE must be a table"),
      "a missing German short-code table must block green readiness"
    )
    Assert.False(readiness.isReady, "missing German short-code table must not pass readiness")
  end)

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

local function RegisterAutomaticSeasonSelectionTests(test, Assert, LoadAddonModules)
  test("SeasonData auto-selects Midnight Season 2 only once Blizzard ships the S2 map set", function()
    local addon = LoadSeasonDataWithFixture(LoadAddonModules)
    local season = addon.SeasonData.SEASONS.midnight_s2
    Assert.True(season.autoDetectFromChallengeMaps, "S2 must be an auto-selection candidate ahead of launch")

    -- While Blizzard still ships another season's map set, the S2 entry must not win.
    local liveSeasonID = addon.SeasonData.ResolveSeasonIDFromChallengeMapIDs(FixtureSeasons.MapIDs())
    Assert.Equal(liveSeasonID, FIXTURE_PREV, "another season's map set must keep resolving to that season")

    local seasonID, reason = addon.SeasonData.ResolveSeasonIDFromChallengeMapIDs({
      249,
      250,
      399,
      584,
      585,
      586,
      587,
      588,
    })
    Assert.Equal(seasonID, "midnight_s2", "the exact S2 map set must resolve to S2")
    Assert.Nil(reason, "a successful resolution must not report a rejection reason")

    -- S2 is the manifest's active season since it went live, so the auto-selection
    -- has to be observed from the other side: start on another season and let
    -- Blizzard's S2 map set move it. Without this the call is a no-op and reports
    -- no change.
    Assert.True(addon.SeasonData.SetActiveSeasonID(FIXTURE_PREV), "test starts from another season")

    -- S2 declares requiresForces = true and ships with its own forces DB, which is
    -- what the shipped addon looks like; the readiness gate must accept that.
    addon.MPlusForces = {
      season = "midnight_s2",
      expiresAt = "2099-01-01",
      dungeonTotal = {
        [249] = { total = 100 },
        [250] = { total = 100 },
        [399] = { total = 100 },
        [584] = { total = 100 },
        [585] = { total = 100 },
        [586] = { total = 100 },
        [587] = { total = 100 },
        [588] = { total = 100 },
      },
      byNpcId = {
        [1000] = { count = 1, mapID = 249 },
        [1001] = { count = 1, mapID = 250 },
        [1002] = { count = 1, mapID = 399 },
        [1003] = { count = 1, mapID = 584 },
        [1004] = { count = 1, mapID = 585 },
        [1005] = { count = 1, mapID = 586 },
        [1006] = { count = 1, mapID = 587 },
        [1007] = { count = 1, mapID = 588 },
      },
    }
    local ok, changed = addon.SeasonData.TryAutoSelectSeasonFromChallengeMapIDs({
      249,
      250,
      399,
      584,
      585,
      586,
      587,
      588,
    }, { currentDate = "2026-09-06" })
    Assert.True(ok, "S2 must pass the readiness gate with its matching forces data")
    Assert.True(changed, "auto-selection must report the active-season change")
    Assert.Equal(addon.SeasonData.GetActiveSeasonID(), "midnight_s2", "S2 must become the runtime-active season")
  end)

  test("SeasonData auto-selects only an exact Blizzard challenge-map set with complete ready data", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_auto = {
      label = "Test Auto",
      autoDetectFromChallengeMaps = true,
      mapToTeleport = { [11] = 1011, [22] = 1022 },
      shortCodesByLocale = {
        default = { [11] = "A", [22] = "B" },
        deDE = { [11] = "A", [22] = "B" },
      },
      namesByLocale = { enUS = { [11] = "A", [22] = "B" }, deDE = { [11] = "A", [22] = "B" } },
      displayOrder = { 11, 22 },
      challengeMapAliases = {},
    }

    local resolved = addon.SeasonData.ResolveSeasonIDFromChallengeMapIDs({ 22, 11 })
    Assert.Equal(resolved, "test_auto", "exact map set must resolve independent of Blizzard order")
    local partial, partialError = addon.SeasonData.ResolveSeasonIDFromChallengeMapIDs({ 11 })
    Assert.Equal(partial, nil, "partial map set must remain unresolved")
    Assert.True(type(partialError) == "string" and partialError ~= "", "partial map set must explain rejection")
    local duplicate = addon.SeasonData.ResolveSeasonIDFromChallengeMapIDs({ 11, 11 })
    Assert.Equal(duplicate, nil, "duplicate Blizzard map ids must fail closed")

    local ok, changed = addon.SeasonData.TryAutoSelectSeasonFromChallengeMapIDs({ 11, 22 })
    Assert.True(ok, "ready exact season must auto-select")
    Assert.True(changed, "selection must report the active-season change")
    Assert.Equal(addon.SeasonData.GetActiveSeasonID(), "test_auto", "exact ready season must become active")
  end)

  test("SeasonData auto-selection marks only a missing or empty map list as retryable", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_auto = {
      label = "Test Auto",
      autoDetectFromChallengeMaps = true,
      mapToTeleport = { [11] = 1011, [22] = 1022 },
      shortCodesByLocale = {
        default = { [11] = "A", [22] = "B" },
        deDE = { [11] = "A", [22] = "B" },
      },
      namesByLocale = { enUS = { [11] = "A", [22] = "B" }, deDE = { [11] = "A", [22] = "B" } },
      displayOrder = { 11, 22 },
      challengeMapAliases = {},
    }
    addon.SeasonData.SEASONS.test_unready = {
      label = "Test Unready",
      autoDetectFromChallengeMaps = true,
      mapToTeleport = { [77] = 1077 },
      shortCodesByLocale = { default = {}, deDE = {} },
      namesByLocale = { enUS = {}, deDE = {} },
      displayOrder = { 77 },
      challengeMapAliases = {},
    }

    local function Retryable(mapIDs)
      local ok, _, _, retryable = addon.SeasonData.TryAutoSelectSeasonFromChallengeMapIDs(mapIDs)
      Assert.False(ok, "the map list must be rejected")
      return retryable
    end
    Assert.True(Retryable(nil), "an unavailable map list is transient")
    Assert.True(Retryable({}), "an empty map list is transient")
    Assert.False(Retryable({ 11 }), "a partial map set is a conclusive rejection")
    Assert.False(Retryable({ 11, 11 }), "duplicate map ids are a conclusive rejection")
    Assert.False(Retryable({ 999 }), "an unknown map set is a conclusive rejection")
    Assert.False(Retryable({ 77 }), "a matched but unready season is a conclusive rejection")
  end)

  test("SeasonData auto-selection ignores missing stale or mismatched forces data", function()
    local addon = LoadSeasonDataWithFixture(LoadAddonModules)
    addon.SeasonData.SEASONS.test_forces = {
      label = "Test Forces",
      autoDetectFromChallengeMaps = true,
      requiresForces = true,
      mapToTeleport = { [33] = 1033 },
      shortCodesByLocale = { default = { [33] = "TF" }, deDE = { [33] = "TF" } },
      namesByLocale = { enUS = { [33] = "Test Forces" }, deDE = { [33] = "Test Forces" } },
      displayOrder = { 33 },
      challengeMapAliases = {},
    }
    local npcs = { [9001] = { count = 5, mapID = 33 } }
    local totals = { [33] = { total = 100 } }
    local variants = {
      { label = "missing", forces = false },
      {
        label = "expired",
        forces = { season = "test_forces", expiresAt = "2026-07-12", dungeonTotal = totals, byNpcId = npcs },
      },
      {
        label = "foreign",
        forces = { season = "other_season", expiresAt = "2099-01-01", dungeonTotal = totals, byNpcId = npcs },
      },
    }

    -- Regression: forces data used to be part of the activation readiness, so a
    -- client that had not updated within the forces lifetime stayed on the
    -- previous season's portals once Blizzard shipped the prepared season.
    for _, variant in ipairs(variants) do
      Assert.True(addon.SeasonData.SetActiveSeasonID(FIXTURE_PREV), "each variant starts from another season")
      addon.MPlusForces = variant.forces or nil
      local opts = { forcesData = variant.forces, currentDate = "2026-07-13" }
      local ok, changed = addon.SeasonData.TryAutoSelectSeasonFromChallengeMapIDs({ 33 }, opts)
      Assert.True(ok, variant.label .. " forces data must not block auto-selection")
      Assert.True(changed, variant.label .. " forces data must not block the season change")
      Assert.Equal(addon.SeasonData.GetActiveSeasonID(), "test_forces", variant.label .. ": season must switch")
      Assert.Equal(
        addon.SeasonData.GetMatchingForcesData(nil, { currentDate = "2026-07-13" }),
        nil,
        variant.label .. " forces data must stay closed for the MDT displays"
      )
    end
  end)

  test("SeasonData forces readiness rejects missing stale or mismatched forces data", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_forces = {
      label = "Test Forces",
      requiresForces = true,
      mapToTeleport = { [33] = 1033 },
    }
    addon.SeasonData.SEASONS.test_no_forces = {
      label = "Test No Forces",
      requiresForces = false,
      mapToTeleport = { [34] = 1034 },
    }
    local npcs = { [9001] = { count = 5, mapID = 33 } }
    local totals = { [33] = { total = 100 } }
    local function Readiness(seasonID, forces)
      return addon.SeasonData.GetForcesReadiness(seasonID, { forcesData = forces, currentDate = "2026-07-13" })
    end

    local missing = Readiness("test_forces", false)
    Assert.False(missing.isReady, "missing forces data must fail the forces gate")
    Assert.True(missing.required, "requiresForces must be reported")
    Assert.NotNil(findError(missing, "forces data is missing"), "missing data must be named")

    local stale = Readiness(
      "test_forces",
      { season = "test_forces", expiresAt = "2026-07-12", dungeonTotal = totals, byNpcId = npcs }
    )
    Assert.False(stale.isReady, "expired forces data must fail the forces gate")
    Assert.NotNil(findError(stale, "expired on 2026-07-12"), "expiry must be named")

    local foreign = Readiness(
      "test_forces",
      { season = "other_season", expiresAt = "2099-01-01", dungeonTotal = totals, byNpcId = npcs }
    )
    Assert.False(foreign.isReady, "forces data for another season must fail the forces gate")
    Assert.NotNil(findError(foreign, "season mismatch"), "season mismatch must be named")

    local valid = Readiness(
      "test_forces",
      { season = "test_forces", expiresAt = "2099-01-01", dungeonTotal = totals, byNpcId = npcs }
    )
    Assert.True(valid.isReady, "matching fresh forces data must pass the forces gate")

    local skipped = Readiness("test_no_forces", false)
    Assert.True(skipped.isReady, "a requiresForces = false season must skip the forces gate")
    Assert.False(skipped.required, "the skipped gate must report required = false")

    Assert.False(Readiness("does_not_exist", false).isReady, "an unknown season must fail the forces gate")
    Assert.Equal(
      findError(addon.SeasonData.GetSeasonReadiness("test_forces"), "forces"),
      nil,
      "activation readiness must not report forces errors"
    )
  end)

  test("SeasonData forces readiness rejects invalid NPC entries and maps without NPC coverage", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_forces_coverage = {
      label = "Test Forces Coverage",
      autoDetectFromChallengeMaps = true,
      requiresForces = true,
      mapToTeleport = { [41] = 1041, [42] = 1042 },
      shortCodesByLocale = { default = { [41] = "A", [42] = "B" }, deDE = { [41] = "A", [42] = "B" } },
      namesByLocale = {
        enUS = { [41] = "A", [42] = "B" },
        deDE = { [41] = "A", [42] = "B" },
      },
      displayOrder = { 41, 42 },
      challengeMapAliases = {},
    }
    local readiness = addon.SeasonData.GetForcesReadiness("test_forces_coverage", {
      currentDate = "2026-07-13",
      forcesData = {
        season = "test_forces_coverage",
        expiresAt = "2099-01-01",
        dungeonTotal = { [41] = { total = 100 }, [42] = { total = 100 } },
        byNpcId = {
          [9001] = { count = 0, mapID = 41 },
          [9002] = { count = 5, mapID = 999 },
        },
      },
    })
    Assert.False(readiness.isReady, "invalid or cross-season NPC data must block Forces readiness")
    Assert.NotNil(findError(readiness, "NPC id 9001 must have a positive count"), "zero NPC count must error")
    Assert.NotNil(findError(readiness, "NPC id 9002 points outside season"), "foreign NPC map must error")
    Assert.NotNil(findError(readiness, "missing positive NPC data for map id 41"), "map 41 coverage must error")
    Assert.NotNil(findError(readiness, "missing positive NPC data for map id 42"), "map 42 coverage must error")
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

  test("Season manifest compiles dungeon records into all runtime indexes", function()
    local addon = LoadSeasonData(LoadAddonModules)
    local manifest = addon.SeasonData.MANIFEST
    local source = manifest and manifest.seasons and manifest.seasons.midnight_s2
    Assert.Equal(manifest.activeSeasonID, "midnight_s2", "manifest must own the active season id")
    Assert.Equal(#source.dungeons, 8, "S2 must be maintained as eight normalized dungeon records")
    Assert.Equal(
      addon.SeasonData.GetMapIDByActivityID(1933, "midnight_s2"),
      588,
      "verified S2 activity id must compile into the season-scoped LFG index"
    )
    Assert.Equal(
      addon.SeasonData.GetMapToTeleport("midnight_s2")[588],
      1286812,
      "the same dungeon record must compile into the teleport index"
    )
    local navigator = addon.SeasonData.GetPortalNavigatorConfig("midnight_s2")
    Assert.Equal(navigator.slots.half_left, 249, "S2 portal-room slots must live in the manifest")
    Assert.Equal(navigator.slots.center, 399, "S2 portal-room center must resolve from the manifest")
    Assert.False(navigator.slots.left, "explicitly empty S2 portal-room slots must remain false")
    Assert.Equal(
      addon.SeasonData.GetMdtDirectory("midnight_s2"),
      "Midnight",
      "the verified S2 MDT directory must compile into the season index"
    )
  end)

  test("SeasonData compiles the portal-room zone into normalized lookup sets", function()
    local addon = LoadSeasonData(LoadAddonModules)

    -- Every season in the production manifest, whichever are configured: the
    -- compiled sets must carry exactly the manifest's hub map ids and lowercased
    -- names, so retiring or adding a season needs no edit here.
    local checked = 0
    for seasonID, source in pairs(addon.SeasonManifest.seasons) do
      local raw = source.portalNavigator.zone
      local zone = addon.SeasonData.GetPortalNavigatorZone(seasonID)
      for _, mapID in ipairs(raw.mapIDs or {}) do
        Assert.True(zone.mapIDs[mapID] == true, seasonID .. " must gate the navigator on hub map id " .. mapID)
      end
      for _, name in ipairs(raw.names or {}) do
        -- Names are lowercased at compile time so callers can compare directly
        -- against normalized zone text from the Blizzard API.
        Assert.True(zone.names[string.lower(name)] == true, seasonID .. " must accept hub zone name " .. name)
        if string.lower(name) ~= name then
          Assert.Nil(zone.names[name], "zone names must not stay in their original casing")
        end
      end
      Assert.Nil(zone.mapIDs[9999], "an unrelated map id must not gate the navigator open")
      checked = checked + 1
    end
    Assert.True(checked > 0, "the production manifest must configure at least one season")

    -- The live season's portal room is the Midnight hub (confirmed 2026-07-22).
    local live = addon.SeasonData.GetPortalNavigatorZone("midnight_s2")
    Assert.True(live.mapIDs[2266] == true, "midnight_s2 must gate the navigator on the Midnight hub map id")
    Assert.True(live.names["millennia's threshold"] == true, "midnight_s2 must accept the enUS hub zone name")
  end)

  test("SeasonData zone lookup drops invalid entries and fails closed on a missing zone", function()
    local addon = LoadSeasonData(LoadAddonModules)
    addon.SeasonData.SEASONS.test_zone = {
      label = "Test Zone",
      portalNavigator = {
        zone = { mapIDs = { 42, "nope", -1, 0 }, names = { "Real Zone", "", 17 } },
      },
    }

    local zone = addon.SeasonData.GetPortalNavigatorZone("test_zone")
    Assert.True(zone.mapIDs[42] == true, "a valid positive map id must survive normalization")
    Assert.Nil(zone.mapIDs[-1], "a negative map id must be dropped")
    Assert.Nil(zone.mapIDs[0], "a zero map id must be dropped")
    Assert.True(zone.names["real zone"] == true, "a valid zone name must survive normalization")
    Assert.Nil(zone.names[""], "an empty zone name must be dropped")

    -- A season without a navigator zone must yield empty sets, never a nil that
    -- would blow up the UI-side lookup.
    addon.SeasonData.SEASONS.test_nozone = { label = "No Zone", portalNavigator = { slots = {} } }
    local missing = addon.SeasonData.GetPortalNavigatorZone("test_nozone")
    Assert.Equal(next(missing.mapIDs), nil, "a season without a zone must expose an empty map-id set")
    Assert.Equal(next(missing.names), nil, "a season without a zone must expose an empty name set")

    local unknown = addon.SeasonData.GetPortalNavigatorZone("does_not_exist")
    Assert.Equal(next(unknown.mapIDs), nil, "an unknown season must fail closed with an empty zone")
  end)

  test("Season manifest rejects a portal navigator without a hub zone", function()
    -- Seed the manifest before loading so the real CompileSeason path runs
    -- against a season whose navigator has slots and a title but no zone.
    local addon = LoadSeasonDataWithManifest(LoadAddonModules, {
      activeSeasonID = "zoneless",
      seasons = {
        zoneless = {
          label = "Zoneless",
          portalNavigator = {
            titleByLocale = { default = "isiLive - Zoneless Navigator" },
            slots = { left = 100, half_left = false, center = false, half_right = false, right = false },
          },
          dungeons = {
            {
              mapID = 100,
              activityIDs = { 900 },
              portalSpellIDs = { 800 },
              displayOrder = 1,
              names = { enUS = "Zoneless Dungeon", deDE = "Zoneloser Dungeon" },
              shortCodes = { default = "ZD", deDE = "ZD" },
            },
          },
        },
      },
    })

    local readiness = addon.SeasonData.GetSeasonReadiness("zoneless")
    Assert.False(readiness.isReady, "a season without a portal-room zone must not be ready")
    Assert.True(findError(readiness, "zone") ~= nil, "the readiness report must name the missing portal-navigator zone")

    -- The shipped seasons must not report that error. Their full readiness
    -- (including the forces DB, which this harness does not load) is covered by
    -- tools/inspect_season_readiness.lua.
    local shipped = LoadSeasonData(LoadAddonModules)
    for seasonID in pairs(shipped.SeasonManifest.seasons) do
      Assert.Nil(
        findError(shipped.SeasonData.GetSeasonReadiness(seasonID), "zone"),
        seasonID .. " must not report a missing portal-navigator zone"
      )
    end
  end)
end

local function RegisterUpcomingSeasonTests(test, Assert, LoadAddonModules)
  test("SeasonData tool default prefers a configured upcomingSeasonID and rejects an unknown one", function()
    local shipped = LoadSeasonData(LoadAddonModules)
    Assert.Nil(shipped.SeasonData.UPCOMING_SEASON_ID, "the shipped manifest prepares no next season")
    Assert.Equal(#shipped.SeasonData.MANIFEST_ERRORS, 0, "the shipped manifest must carry no manifest errors")
    Assert.Equal(
      shipped.SeasonData.GetToolDefaultSeasonID(),
      shipped.SeasonData.GetActiveSeasonID(),
      "without upcomingSeasonID the tooling must target the active season"
    )

    local prepared = LoadSeasonDataWithManifest(LoadAddonModules, {
      activeSeasonID = "running",
      upcomingSeasonID = "next",
      seasons = { running = { label = "Running", dungeons = {} }, next = { label = "Next", dungeons = {} } },
    })
    Assert.Equal(prepared.SeasonData.UPCOMING_SEASON_ID, "next", "a configured upcoming season must be exposed")
    Assert.Equal(prepared.SeasonData.GetToolDefaultSeasonID(), "next", "the tooling must target the upcoming season")
    Assert.Equal(prepared.SeasonData.GetActiveSeasonID(), "running", "upcomingSeasonID must never change the runtime")

    local unknown = LoadSeasonDataWithManifest(LoadAddonModules, {
      activeSeasonID = "running",
      upcomingSeasonID = "typo_season",
      seasons = { running = { label = "Running", dungeons = {} } },
    })
    Assert.Nil(unknown.SeasonData.UPCOMING_SEASON_ID, "an unknown upcoming season must not be exposed")
    Assert.Equal(#unknown.SeasonData.MANIFEST_ERRORS, 1, "an unknown upcoming season must be a manifest error")
    Assert.True(
      string.find(unknown.SeasonData.MANIFEST_ERRORS[1], "typo_season", 1, true) ~= nil,
      "the manifest error must name the unknown season id"
    )
    Assert.Equal(
      unknown.SeasonData.GetToolDefaultSeasonID(),
      "running",
      "an unknown upcoming season must fall back to the active season"
    )
  end)
end

local function RegisterLocalizedNameTests(test, Assert, LoadAddonModules, WithGlobals)
  -- King's Rest (249) ships enUS + deDE manifest names only.
  local function BuildClientGlobals(clientLocale, uiNamesByMapID)
    local calls = { count = 0 }
    return {
      GetLocale = function()
        return clientLocale
      end,
      C_ChallengeMode = {
        GetMapUIInfo = function(mapID)
          calls.count = calls.count + 1
          return uiNamesByMapID[mapID]
        end,
      },
    },
      calls
  end

  test(
    "SeasonData.GetDungeonName uses the client-localized Blizzard name for locales without manifest names",
    function()
      local globals, calls = BuildClientGlobals("frFR", { [249] = "Repos des rois" })
      WithGlobals(globals, function()
        local addon = LoadSeasonData(LoadAddonModules)
        Assert.Equal(
          addon.SeasonData.GetDungeonName(249, "frFR", "midnight_s2"),
          "Repos des rois",
          "a frFR client must see Blizzard's French name instead of the English manifest name"
        )
        Assert.Equal(calls.count, 1, "the Blizzard name must be read once")
      end)
    end
  )

  test("SeasonData.GetDungeonName keeps manifest names ahead of the Blizzard name", function()
    local globals, calls = BuildClientGlobals("deDE", { [249] = "API-Name" })
    WithGlobals(globals, function()
      local addon = LoadSeasonData(LoadAddonModules)
      Assert.Equal(
        addon.SeasonData.GetDungeonName(249, "deDE", "midnight_s2"),
        "Königsruh",
        "a deDE request must keep the verified manifest name"
      )
      Assert.Equal(
        addon.SeasonData.GetDungeonName(249, "enUS", "midnight_s2"),
        "King's Rest",
        "an enUS request must keep the English manifest name"
      )
      Assert.Equal(
        addon.SeasonData.GetDungeonName(249, nil, "midnight_s2"),
        "King's Rest",
        "a request without locale must keep the English manifest name"
      )
      Assert.Equal(calls.count, 0, "a manifest hit must not call the Blizzard API")
    end)
  end)

  test("SeasonData.GetDungeonName uses the Blizzard name only for the client locale", function()
    local globals, calls = BuildClientGlobals("deDE", { [249] = "Königsruh (API)" })
    WithGlobals(globals, function()
      local addon = LoadSeasonData(LoadAddonModules)
      Assert.Equal(
        addon.SeasonData.GetDungeonName(249, "frFR", "midnight_s2"),
        "King's Rest",
        "a frFR UI on a deDE client must fall back to English, not show the German API name"
      )
      Assert.Equal(calls.count, 0, "a foreign-locale request must not call the Blizzard API")
    end)
  end)

  test("SeasonData.GetDungeonName serves unsupported client locales from Blizzard and falls back to English", function()
    local globals = BuildClientGlobals("koKR", { [249] = "왕들의 안식처" })
    WithGlobals(globals, function()
      local addon = LoadSeasonData(LoadAddonModules)
      Assert.Equal(
        addon.SeasonData.GetDungeonName(249, "koKR", "midnight_s2"),
        "왕들의 안식처",
        "an unsupported client locale must reach the Blizzard name"
      )
    end)

    local missingApi = {
      GetLocale = function()
        return "frFR"
      end,
      C_ChallengeMode = {},
    }
    WithGlobals(missingApi, function()
      local addon = LoadSeasonData(LoadAddonModules)
      Assert.Equal(
        addon.SeasonData.GetDungeonName(249, "frFR", "midnight_s2"),
        "King's Rest",
        "without GetMapUIInfo the English manifest name must remain"
      )
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  RegisterReadinessTests(test, Assert, LoadAddonModules)
  RegisterSetActiveSeasonIDTests(test, Assert, LoadAddonModules)
  RegisterAutomaticSeasonSelectionTests(test, Assert, LoadAddonModules)
  RegisterAccessorFallbackTests(test, Assert, LoadAddonModules)
  RegisterUpcomingSeasonTests(test, Assert, LoadAddonModules)
  RegisterLocalizedNameTests(test, Assert, LoadAddonModules, ctx.with_globals)
end
