local _, addonTable = ...

addonTable = addonTable or {}

local SeasonData = {}
addonTable.SeasonData = SeasonData

-- Seasonal data is centralized here.
-- To onboard a new season:
-- 1) Add a new entry under SeasonData.SEASONS.
-- 2) Set SeasonData.ACTIVE_SEASON_ID to that entry key.
-- 3) Keep locale short-code overrides inside shortCodesByLocale.

local function NormalizeLocaleTag(localeTag)
  if not localeTag then
    return "default"
  end

  local normalized = tostring(localeTag):gsub("%-", ""):lower()
  if normalized == "de" or normalized == "dede" then
    return "deDE"
  end
  if normalized == "en" or normalized == "enus" or normalized == "engb" then
    return "enUS"
  end

  return "default"
end

SeasonData.ACTIVE_SEASON_ID = "tww_s3"

SeasonData.SEASONS = {
  tww_s3 = {
    label = "TWW Season 3",
    -- MapID -> Teleport SpellID
    mapToTeleport = {
      [2649] = 445444, -- Priory of the Sacred Flame
      [2830] = 1237215, -- Eco-Dome Al'dani
      [2287] = 354465, -- Halls of Atonement
      [2773] = 1216786, -- Operation: Floodgate
      [2660] = 445417, -- Ara-Kara, City of Echoes
      [2441] = 367416, -- Tazavesh: Streets of Wonder
      [2442] = 367416, -- Tazavesh: So'leah's Gambit
      [2662] = 445414, -- The Dawnbreaker
    },
    -- MapID -> short code grouped by locale.
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
  },
}

function SeasonData.GetSeasonConfig(seasonID)
  local resolvedSeasonID = seasonID or SeasonData.ACTIVE_SEASON_ID
  local seasons = SeasonData.SEASONS or {}
  return seasons[resolvedSeasonID]
end

function SeasonData.GetMapToTeleport(seasonID)
  local season = SeasonData.GetSeasonConfig(seasonID)
  if type(season) ~= "table" then
    return {}
  end
  return season.mapToTeleport or {}
end

function SeasonData.GetShortCodes(localeTag, seasonID)
  local season = SeasonData.GetSeasonConfig(seasonID)
  if type(season) ~= "table" then
    return {}
  end

  local byLocale = season.shortCodesByLocale or {}
  local localeKey = NormalizeLocaleTag(localeTag)
  if localeKey ~= "default" and type(byLocale[localeKey]) == "table" then
    return byLocale[localeKey]
  end

  if type(byLocale.default) == "table" then
    return byLocale.default
  end

  return {}
end

function SeasonData.GetDungeonShortCode(mapID, localeTag, seasonID)
  local numericMapID = tonumber(mapID)
  if not numericMapID then
    return nil
  end

  local localizedShortCodes = SeasonData.GetShortCodes(localeTag, seasonID)
  if localizedShortCodes[numericMapID] then
    return localizedShortCodes[numericMapID]
  end

  local defaultShortCodes = SeasonData.GetShortCodes("default", seasonID)
  return defaultShortCodes[numericMapID]
end

-- Backward-compatible aliases used by existing runtime wiring.
SeasonData.MAP_TO_TELEPORT = SeasonData.GetMapToTeleport()
SeasonData.MAP_SHORT_CODES = SeasonData.GetShortCodes("enUS")
