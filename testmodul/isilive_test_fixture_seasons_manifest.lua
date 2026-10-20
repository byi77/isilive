---@diagnostic disable: undefined-global

-- Manifest chunk for offline tools under test: the production season manifest
-- plus the synthetic fixture season from isilive_test_fixture_seasons.lua.
-- Loaded with the same (addonName, addonTable) signature as data/isiLive_seasons.lua.
local addonName, addonTable = ...

assert(loadfile("data/isiLive_seasons.lua"))(addonName, addonTable)
local FixtureSeasons = assert(loadfile("testmodul/isilive_test_fixture_seasons.lua"))()
addonTable.SeasonManifest.seasons[FixtureSeasons.PREVIOUS_SEASON_ID] = FixtureSeasons.BuildSeason()
