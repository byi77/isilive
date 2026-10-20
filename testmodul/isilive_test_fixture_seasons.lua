---@diagnostic disable: undefined-global

-- Synthetic season for tests that need "some other, non-active season" next to
-- the live one. Tests used to borrow a real historical season for that role,
-- which pinned it in data/isiLive_seasons.lua forever: retiring it would have
-- broken every such test. The fixture is compiled by the real SeasonData
-- compiler, so it exercises the same path as a manifest entry.
--
-- All IDs sit in ranges no Blizzard data uses (challenge maps 90001+, LFG
-- activities 99001+, portal spells 9900001+, hub map 99901), so a fixture value
-- can never be mistaken for, or collide with, a real one.

local FixtureSeasons = {}

FixtureSeasons.PREVIOUS_SEASON_ID = "fixture_prev"
FixtureSeasons.PREVIOUS_SEASON_LABEL = "Fixture Previous Season"
FixtureSeasons.HUB_MAP_ID = 99901
FixtureSeasons.HUB_ZONE_NAME = "Fixture Hub"

local DUNGEON_COUNT = 8
-- The first half models dungeons new to the expansion (level-90 portal gate),
-- the second half returning legacy dungeons (no gate).
local NATIVE_COUNT = 4

function FixtureSeasons.MapIDs()
  local out = {}
  for index = 1, DUNGEON_COUNT do
    out[index] = 90000 + index
  end
  return out
end

function FixtureSeasons.NativeMapIDs()
  local out = {}
  for index = 1, NATIVE_COUNT do
    out[index] = 90000 + index
  end
  return out
end

function FixtureSeasons.LegacyMapIDs()
  local out = {}
  for index = NATIVE_COUNT + 1, DUNGEON_COUNT do
    out[#out + 1] = 90000 + index
  end
  return out
end

-- Returns a complete, ready manifest record (the shape data/isiLive_seasons.lua
-- uses), freshly built on every call so tests can mutate it.
function FixtureSeasons.BuildSeason()
  local dungeons = {}
  for index = 1, DUNGEON_COUNT do
    local mapID = 90000 + index
    local code = "FX" .. tostring(index)
    dungeons[index] = {
      mapID = mapID,
      activityIDs = { 99000 + index },
      portalSpellIDs = { 9900000 + index },
      displayOrder = index,
      minimumPlayerLevel = index <= NATIVE_COUNT and 90 or nil,
      names = { enUS = "Fixture Dungeon " .. tostring(index), deDE = "Fixture-Dungeon " .. tostring(index) },
      shortCodes = { default = code, deDE = code },
    }
  end
  return {
    label = FixtureSeasons.PREVIOUS_SEASON_LABEL,
    autoDetectFromChallengeMaps = true,
    requiresForces = false,
    inactivePortalMessageByLocale = {},
    portalNavigator = {
      zone = { mapIDs = { FixtureSeasons.HUB_MAP_ID }, names = { FixtureSeasons.HUB_ZONE_NAME } },
      titleByLocale = { default = "Fixture Navigator" },
      slots = { left = 90001, half_left = 90002, center = false, half_right = 90003, right = 90004 },
    },
    dungeons = dungeons,
  }
end

-- Compiles the fixture with the production compiler into a throwaway addon
-- table and inserts the compiled season into the already loaded SeasonData.
-- Inserting (instead of reloading game/isiLive_season_data.lua) keeps the
-- SeasonData table identity that modules such as Teleport captured at load.
function FixtureSeasons.Install(addon)
  assert(type(addon) == "table" and type(addon.SeasonData) == "table", "Install needs a loaded SeasonData")
  local scratch = {
    Languages = addon.Languages,
    Validators = addon.Validators,
    SeasonManifest = {
      activeSeasonID = FixtureSeasons.PREVIOUS_SEASON_ID,
      seasons = { [FixtureSeasons.PREVIOUS_SEASON_ID] = FixtureSeasons.BuildSeason() },
    },
  }
  local chunk = assert(loadfile("game/isiLive_season_data.lua"))
  chunk("isiLive", scratch)
  local compiled = scratch.SeasonData.SEASONS[FixtureSeasons.PREVIOUS_SEASON_ID]
  assert(type(compiled) == "table", "fixture season must compile")
  addon.SeasonData.SEASONS[FixtureSeasons.PREVIOUS_SEASON_ID] = compiled
  return addon
end

-- Path of a manifest chunk (data/isiLive_seasons.lua plus the fixture season)
-- for offline tools that take a manifest path, e.g. tools/check_mplus_db_lifetime.lua.
FixtureSeasons.MANIFEST_PATH = "testmodul/isilive_test_fixture_seasons_manifest.lua"

return FixtureSeasons
