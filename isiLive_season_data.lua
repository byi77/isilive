local _, addonTable = ...

addonTable = addonTable or {}

local SeasonData = {}
addonTable.SeasonData = SeasonData

-- Seasonal data is centralized here.
-- To onboard a new season:
-- 1) Add a new entry under SeasonData.SEASONS.
-- 2) Fill mapToTeleport / shortCodesByLocale / challengeMapAliases completely.
-- 3) Keep locale short-code overrides inside shortCodesByLocale.
-- 4) Switch SeasonData.ACTIVE_SEASON_ID only after step 2 is complete.

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

local function NormalizeMapIDInput(mapID)
  local numericMapID = tonumber(mapID)
  if not numericMapID then
    return nil
  end
  return numericMapID
end

local function IsPositiveNumber(value)
  local numericValue = tonumber(value)
  return numericValue and numericValue > 0
end

local function CountTableEntries(value)
  if type(value) ~= "table" then
    return 0
  end

  local count = 0
  for _ in pairs(value) do
    count = count + 1
  end
  return count
end

SeasonData.ACTIVE_SEASON_ID = "midnight_s1"

SeasonData.SEASONS = {
  midnight_s1 = {
    label = "Midnight Season 1 (prepared, inactive)",
    mapToTeleport = {
      -- TODO: Add numeric MapIDs and SpellIDs when Midnight PTR is available
      -- [2526] = 393256, -- Algeth'ar Academy (DF S1 IDs, might change)
      -- [115]  = 0,      -- Magisters' Terrace
      -- [658]  = 0,      -- Pit of Saron
      -- [1677] = 0,      -- Seat of the Triumvirate
      -- [1176] = 0,      -- Skyreach
      -- [?]    = 0,      -- Maisara Caverns
      -- [?]    = 0,      -- Nexus-Point Xenas
      -- [?]    = 0,      -- Windrunner Spire
    },
    displayOrder = {
      -- 2526, -- Algeth'ar Academy
      -- 115,  -- Magisters' Terrace
      -- 658,  -- Pit of Saron
      -- 1677, -- Seat of the Triumvirate
      -- 1176, -- Skyreach
      -- ?,    -- Maisara Caverns
      -- ?,    -- Nexus-Point Xenas
      -- ?,    -- Windrunner Spire
    },
    shortCodesByLocale = {
      default = {
        -- [2526] = "AA",
        -- [115]  = "MGT",
        -- [658]  = "POS",
        -- [1677] = "SOT",
        -- [1176] = "SKY",
        -- [?]    = "MAC",
        -- [?]    = "NPX",
        -- [?]    = "WS",
      },
      deDE = {
        -- [2526] = "AA",
        -- [115]  = "TDM",
        -- [658]  = "GVS",
        -- [1677] = "SDT",
        -- [1176] = "HN",
        -- [?]    = "MH",
        -- [?]    = "NPX",
        -- [?]    = "WS",
      },
    },
    challengeMapAliases = {},
    inactivePortalMessageByLocale = {
      default = "Midnight S1 launches March 18, 2026\nM+ available March 25, 2026",
      deDE = "Midnight S1 startet am 18.03.2026\nM+ verfügbar ab 25.03.2026",
    },
  },
}

local function RefreshLegacyAliases()
  SeasonData.MAP_TO_TELEPORT = SeasonData.GetMapToTeleport()
  SeasonData.MAP_SHORT_CODES = SeasonData.GetShortCodes("enUS")
end

function SeasonData.GetSeasonConfig(seasonID)
  local resolvedSeasonID = seasonID or SeasonData.ACTIVE_SEASON_ID
  local seasons = SeasonData.SEASONS or {}
  return seasons[resolvedSeasonID]
end

function SeasonData.GetSeasonLabel(seasonID)
  local season = SeasonData.GetSeasonConfig(seasonID)
  if type(season) ~= "table" then
    return tostring(seasonID or "")
  end
  if type(season.label) == "string" and season.label ~= "" then
    return season.label
  end
  return tostring(seasonID or "")
end

function SeasonData.GetActiveSeasonID()
  return SeasonData.ACTIVE_SEASON_ID
end

function SeasonData.GetAvailableSeasonIDs()
  local out = {}
  local seasons = SeasonData.SEASONS or {}
  for seasonID in pairs(seasons) do
    table.insert(out, seasonID)
  end
  table.sort(out)
  return out
end

function SeasonData.GetSeasonReadiness(seasonID)
  local resolvedSeasonID = seasonID or SeasonData.ACTIVE_SEASON_ID
  local season = SeasonData.GetSeasonConfig(resolvedSeasonID)
  local errors = {}
  local warnings = {}

  if type(season) ~= "table" then
    return {
      seasonID = resolvedSeasonID,
      label = tostring(resolvedSeasonID or ""),
      isReady = false,
      mappedDungeonCount = 0,
      aliasCount = 0,
      errors = {
        string.format("Unknown season id '%s'", tostring(resolvedSeasonID)),
      },
      warnings = warnings,
    }
  end

  local mapToTeleport = season.mapToTeleport
  local displayOrder = season.displayOrder
  local byLocale = season.shortCodesByLocale
  local aliases = season.challengeMapAliases

  local mapCount = CountTableEntries(mapToTeleport)
  local aliasCount = CountTableEntries(aliases)

  if type(mapToTeleport) ~= "table" then
    table.insert(errors, "mapToTeleport must be a table")
  elseif mapCount == 0 then
    table.insert(errors, "mapToTeleport is empty")
  else
    local defaultShortCodes = type(byLocale) == "table" and byLocale.default or nil
    local deShortCodes = type(byLocale) == "table" and byLocale.deDE or nil

    if type(defaultShortCodes) ~= "table" then
      table.insert(errors, "shortCodesByLocale.default must be a table")
    end

    for mapID, spellValue in pairs(mapToTeleport) do
      local numericMapID = NormalizeMapIDInput(mapID)
      if not numericMapID then
        table.insert(errors, string.format("mapToTeleport has non-numeric map id key '%s'", tostring(mapID)))
      else
        if type(spellValue) == "number" then
          if not IsPositiveNumber(spellValue) then
            table.insert(errors, string.format("mapToTeleport[%d] must be a positive spell id", numericMapID))
          end
        elseif type(spellValue) == "table" then
          local validSpellCount = 0
          for _, candidate in ipairs(spellValue) do
            if IsPositiveNumber(candidate) then
              validSpellCount = validSpellCount + 1
            end
          end
          if validSpellCount == 0 then
            table.insert(
              errors,
              string.format("mapToTeleport[%d] list must contain at least one valid spell id", numericMapID)
            )
          end
        else
          table.insert(
            errors,
            string.format("mapToTeleport[%d] must be a spell id number or list of spell ids", numericMapID)
          )
        end

        if type(defaultShortCodes) == "table" then
          local defaultShortCode = defaultShortCodes[numericMapID]
          if type(defaultShortCode) ~= "string" or defaultShortCode == "" then
            table.insert(errors, string.format("shortCodesByLocale.default is missing map id %d", numericMapID))
          end
        end

        if type(deShortCodes) == "table" then
          local deShortCode = deShortCodes[numericMapID]
          if type(deShortCode) ~= "string" or deShortCode == "" then
            table.insert(warnings, string.format("shortCodesByLocale.deDE is missing map id %d", numericMapID))
          end
        end
      end
    end
  end

  if type(displayOrder) ~= "table" then
    table.insert(errors, "displayOrder must be a table")
  elseif type(mapToTeleport) == "table" and mapCount > 0 then
    local seenMapID = {}
    for _, mapID in ipairs(displayOrder) do
      local numericMapID = NormalizeMapIDInput(mapID)
      if not numericMapID then
        table.insert(errors, string.format("displayOrder contains non-numeric map id '%s'", tostring(mapID)))
      elseif type(mapToTeleport[numericMapID]) ~= "number" and type(mapToTeleport[numericMapID]) ~= "table" then
        table.insert(errors, string.format("displayOrder contains unknown map id %d", numericMapID))
      else
        seenMapID[numericMapID] = true
      end
    end

    for mapID in pairs(mapToTeleport) do
      if not seenMapID[mapID] then
        table.insert(warnings, string.format("displayOrder is missing mapped map id %d", mapID))
      end
    end
  end

  if type(aliases) ~= "table" then
    table.insert(errors, "challengeMapAliases must be a table")
  elseif type(mapToTeleport) == "table" then
    for aliasMapID, canonicalMapID in pairs(aliases) do
      local aliasNumeric = NormalizeMapIDInput(aliasMapID)
      local canonicalNumeric = NormalizeMapIDInput(canonicalMapID)
      if not aliasNumeric then
        table.insert(
          errors,
          string.format("challengeMapAliases contains non-numeric alias key '%s'", tostring(aliasMapID))
        )
      elseif not canonicalNumeric then
        table.insert(
          errors,
          string.format("challengeMapAliases[%d] contains non-numeric canonical map id", aliasNumeric)
        )
      elseif mapToTeleport[canonicalNumeric] == nil then
        table.insert(
          errors,
          string.format(
            "challengeMapAliases[%d] points to unmapped canonical map id %d",
            aliasNumeric,
            canonicalNumeric
          )
        )
      end
    end
  end

  return {
    seasonID = resolvedSeasonID,
    label = SeasonData.GetSeasonLabel(resolvedSeasonID),
    isReady = #errors == 0,
    mappedDungeonCount = mapCount,
    aliasCount = aliasCount,
    errors = errors,
    warnings = warnings,
  }
end

function SeasonData.IsSeasonReady(seasonID)
  local readiness = SeasonData.GetSeasonReadiness(seasonID)
  return readiness.isReady == true
end

function SeasonData.HasActiveDungeons(seasonID)
  local mapToTeleport = SeasonData.GetMapToTeleport(seasonID)
  return next(mapToTeleport) ~= nil
end

function SeasonData.SetActiveSeasonID(seasonID, opts)
  opts = opts or {}

  local resolvedSeasonID = tostring(seasonID or "")
  local season = SeasonData.GetSeasonConfig(resolvedSeasonID)
  if type(season) ~= "table" then
    return false, string.format("Unknown season id '%s'", resolvedSeasonID)
  end

  local readiness = SeasonData.GetSeasonReadiness(resolvedSeasonID)
  local allowIncomplete = opts.allowIncomplete == true
  if not allowIncomplete and not readiness.isReady then
    local firstError = readiness.errors[1] or "season data is incomplete"
    return false, string.format("Season '%s' is not ready: %s", resolvedSeasonID, firstError)
  end

  SeasonData.ACTIVE_SEASON_ID = resolvedSeasonID
  RefreshLegacyAliases()
  return true, string.format("Active season set to %s", resolvedSeasonID)
end

function SeasonData.NormalizeMapID(mapID, seasonID)
  local numericMapID = NormalizeMapIDInput(mapID)
  if not numericMapID then
    return nil
  end

  local season = SeasonData.GetSeasonConfig(seasonID)
  if type(season) ~= "table" then
    return numericMapID
  end

  local mapToTeleport = season.mapToTeleport or {}
  if mapToTeleport[numericMapID] then
    return numericMapID
  end

  local aliases = season.challengeMapAliases or {}
  local canonical = NormalizeMapIDInput(aliases[numericMapID])
  if canonical and mapToTeleport[canonical] then
    return canonical
  end

  return numericMapID
end

function SeasonData.GetMapToTeleport(seasonID)
  local season = SeasonData.GetSeasonConfig(seasonID)
  if type(season) ~= "table" then
    return {}
  end
  return season.mapToTeleport or {}
end

function SeasonData.GetOrderedMapIDs(seasonID)
  local season = SeasonData.GetSeasonConfig(seasonID)
  if type(season) ~= "table" then
    return {}
  end

  local mapToTeleport = season.mapToTeleport or {}
  local ordered = {}
  local seen = {}

  local explicitOrder = season.displayOrder
  if type(explicitOrder) == "table" then
    for _, mapID in ipairs(explicitOrder) do
      local numericMapID = NormalizeMapIDInput(mapID)
      if numericMapID and mapToTeleport[numericMapID] and not seen[numericMapID] then
        seen[numericMapID] = true
        table.insert(ordered, numericMapID)
      end
    end
  end

  local remaining = {}
  for mapID in pairs(mapToTeleport) do
    if not seen[mapID] then
      table.insert(remaining, mapID)
    end
  end
  table.sort(remaining)
  for _, mapID in ipairs(remaining) do
    table.insert(ordered, mapID)
  end

  return ordered
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
  local numericMapID = SeasonData.NormalizeMapID(mapID, seasonID)
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

function SeasonData.GetInactivePortalMessage(localeTag, seasonID)
  local season = SeasonData.GetSeasonConfig(seasonID)
  if type(season) ~= "table" then
    return nil
  end

  local byLocale = season.inactivePortalMessageByLocale or {}
  local localeKey = NormalizeLocaleTag(localeTag)
  if localeKey ~= "default" and type(byLocale[localeKey]) == "string" and byLocale[localeKey] ~= "" then
    return byLocale[localeKey]
  end

  if type(byLocale.default) == "string" and byLocale.default ~= "" then
    return byLocale.default
  end

  return nil
end

-- Backward-compatible aliases used by existing runtime wiring.
RefreshLegacyAliases()
