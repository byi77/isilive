local _, addonTable = ...

addonTable = addonTable or {}

local SeasonData = {}
addonTable.SeasonData = SeasonData

-- Runtime compiler and access API for the normalized season manifest.
-- Add or update seasons only in data/isiLive_seasons.lua. Generated forces
-- data remains separate and is exposed only after an exact season match.

local function NormalizeLocaleTag(localeTag)
  if not localeTag then
    return "default"
  end
  local resolved = addonTable.Languages.ResolveTag(localeTag)
  -- ResolveTag returns "enUS" for unknown tags; map that to "default" so callers
  -- fall through to the locale-neutral shortcode/name table.
  if resolved == "enUS" then
    return "default"
  end
  return resolved
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

if type(addonTable.SeasonManifest) ~= "table" then
  local loadfileRef = rawget(_G, "loadfile")
  if type(loadfileRef) == "function" then
    local chunk = loadfileRef("data/isiLive_seasons.lua")
    if chunk then
      chunk("isiLive", addonTable)
    end
  end
end

local SeasonManifest = addonTable.SeasonManifest or {}

local function CompileSeason(source)
  source = type(source) == "table" and source or {}
  local season = {
    label = source.label,
    autoDetectFromChallengeMaps = source.autoDetectFromChallengeMaps == true,
    requiresForces = source.requiresForces == true,
    mdtDirectory = source.mdtDirectory,
    inactivePortalMessageByLocale = source.inactivePortalMessageByLocale or {},
    portalNavigator = source.portalNavigator,
    dungeons = source.dungeons,
    mapToTeleport = {},
    displayOrder = {},
    minimumPlayerLevelByMapID = {},
    shortCodesByLocale = { default = {}, deDE = {} },
    namesByLocale = { enUS = {}, deDE = {} },
    challengeMapAliases = {},
    activityToMap = {},
    plannedDungeons = {},
    manifestErrors = {},
  }
  local ordered = {}
  local seenMapIDs = {}
  local seenActivityIDs = {}
  local seenDisplayOrders = {}

  if type(source.dungeons) ~= "table" then
    season.manifestErrors[#season.manifestErrors + 1] = "dungeons must be a table"
    return season
  end

  for index, dungeon in ipairs(source.dungeons) do
    local mapID = type(dungeon) == "table" and tonumber(dungeon.mapID) or nil
    if not mapID or mapID <= 0 or mapID ~= math.floor(mapID) then
      season.manifestErrors[#season.manifestErrors + 1] = string.format("dungeon %d has invalid mapID", index)
    elseif seenMapIDs[mapID] then
      season.manifestErrors[#season.manifestErrors + 1] = string.format("duplicate mapID %d", mapID)
    else
      seenMapIDs[mapID] = true
      local spells = dungeon.portalSpellIDs
      if type(spells) ~= "table" or #spells == 0 then
        season.manifestErrors[#season.manifestErrors + 1] = string.format("mapID %d has no portalSpellIDs", mapID)
      elseif #spells == 1 then
        season.mapToTeleport[mapID] = spells[1]
      else
        season.mapToTeleport[mapID] = spells
      end

      local order = tonumber(dungeon.displayOrder)
      if not order or order <= 0 or order ~= math.floor(order) then
        season.manifestErrors[#season.manifestErrors + 1] = string.format("mapID %d has invalid displayOrder", mapID)
      elseif seenDisplayOrders[order] then
        season.manifestErrors[#season.manifestErrors + 1] = string.format("duplicate displayOrder %d", order)
      else
        seenDisplayOrders[order] = true
      end
      ordered[#ordered + 1] = { mapID = mapID, order = order or math.huge }
      if dungeon.minimumPlayerLevel ~= nil then
        season.minimumPlayerLevelByMapID[mapID] = dungeon.minimumPlayerLevel
      end

      for localeTag, name in pairs(type(dungeon.names) == "table" and dungeon.names or {}) do
        season.namesByLocale[localeTag] = season.namesByLocale[localeTag] or {}
        season.namesByLocale[localeTag][mapID] = name
      end
      for localeTag, code in pairs(type(dungeon.shortCodes) == "table" and dungeon.shortCodes or {}) do
        season.shortCodesByLocale[localeTag] = season.shortCodesByLocale[localeTag] or {}
        season.shortCodesByLocale[localeTag][mapID] = code
      end
      for _, aliasMapID in ipairs(type(dungeon.challengeMapAliases) == "table" and dungeon.challengeMapAliases or {}) do
        season.challengeMapAliases[aliasMapID] = mapID
      end
      local activityIDs = type(dungeon.activityIDs) == "table" and dungeon.activityIDs or {}
      if #activityIDs == 0 then
        season.manifestErrors[#season.manifestErrors + 1] = string.format("mapID %d has no activityIDs", mapID)
      end
      for _, activityID in ipairs(activityIDs) do
        local numericActivityID = tonumber(activityID)
        if not numericActivityID or numericActivityID <= 0 or numericActivityID ~= math.floor(numericActivityID) then
          season.manifestErrors[#season.manifestErrors + 1] = string.format("mapID %d has invalid activityID", mapID)
        elseif seenActivityIDs[numericActivityID] then
          season.manifestErrors[#season.manifestErrors + 1] =
            string.format("duplicate activityID %d", numericActivityID)
        else
          seenActivityIDs[numericActivityID] = true
          season.activityToMap[numericActivityID] = mapID
        end
      end

      local englishName = season.namesByLocale.enUS[mapID]
      if type(englishName) == "string" and englishName ~= "" then
        season.plannedDungeons[#season.plannedDungeons + 1] = englishName
      end
    end
  end

  table.sort(ordered, function(left, right)
    if left.order == right.order then
      return left.mapID < right.mapID
    end
    return left.order < right.order
  end)
  for _, entry in ipairs(ordered) do
    season.displayOrder[#season.displayOrder + 1] = entry.mapID
  end

  if season.requiresForces and (type(season.mdtDirectory) ~= "string" or season.mdtDirectory == "") then
    season.manifestErrors[#season.manifestErrors + 1] = "requiresForces season has no mdtDirectory"
  end
  local navigator = season.portalNavigator
  local slots = type(navigator) == "table" and navigator.slots or nil
  local titles = type(navigator) == "table" and navigator.titleByLocale or nil
  local zone = type(navigator) == "table" and navigator.zone or nil
  -- Without a hub zone the navigator can never open, so treat it like the slots:
  -- a manifest error, not a silent no-op.
  if type(zone) ~= "table" or (CountTableEntries(zone.mapIDs) == 0 and CountTableEntries(zone.names) == 0) then
    season.manifestErrors[#season.manifestErrors + 1] = "portalNavigator must provide a zone with mapIDs or names"
  end
  if type(slots) ~= "table" or type(titles) ~= "table" or type(titles.default) ~= "string" or titles.default == "" then
    season.manifestErrors[#season.manifestErrors + 1] = "portalNavigator must provide slots and a default title"
  else
    for _, slot in ipairs({ "left", "half_left", "center", "half_right", "right" }) do
      local mapID = slots[slot]
      if mapID ~= false and (type(mapID) ~= "number" or not seenMapIDs[mapID]) then
        season.manifestErrors[#season.manifestErrors + 1] = string.format("portalNavigator slot %s is unresolved", slot)
      end
    end
  end

  return season
end

SeasonData.ACTIVE_SEASON_ID = SeasonManifest.activeSeasonID
SeasonData.MANIFEST = SeasonManifest
SeasonData.SEASONS = {}
for seasonID, source in pairs(SeasonManifest.seasons or {}) do
  SeasonData.SEASONS[seasonID] = CompileSeason(source)
end

local function RefreshLegacyAliases()
  SeasonData.MAP_TO_TELEPORT = SeasonData.GetMapToTeleport()
  SeasonData.MAP_SHORT_CODES = SeasonData.GetShortCodes("enUS")
end

local function ParseIsoDate(value)
  if type(value) ~= "string" then
    return nil
  end
  local year, month, day = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if not year then
    return nil
  end
  return tonumber(year) * 10000 + tonumber(month) * 100 + tonumber(day)
end

local function ResolveCurrentDate(opts)
  if type(opts) == "table" and type(opts.currentDate) == "string" then
    return opts.currentDate
  end

  local dateFn = rawget(_G, "date")
  if type(dateFn) == "function" then
    local ok, value = pcall(dateFn, "!%Y-%m-%d")
    if ok and type(value) == "string" then
      return value
    end
  end

  local osLib = rawget(_G, "os")
  if type(osLib) == "table" and type(osLib.date) == "function" then
    local ok, value = pcall(osLib.date, "!%Y-%m-%d")
    if ok and type(value) == "string" then
      return value
    end
  end

  return nil
end

local function AppendForcesReadinessErrors(errors, seasonID, season, opts)
  if season.requiresForces ~= true then
    return
  end

  local forces = type(opts) == "table" and opts.forcesData or nil
  if forces == nil then
    forces = addonTable.MPlusForces
  end
  if type(forces) ~= "table" then
    table.insert(errors, "matching M+ forces data is missing")
    return
  end
  if forces.season ~= seasonID then
    table.insert(
      errors,
      string.format("M+ forces season mismatch: expected %s, got %s", tostring(seasonID), tostring(forces.season))
    )
    return
  end

  local dungeonTotal = forces.dungeonTotal
  local byNpcId = forces.byNpcId
  if type(dungeonTotal) ~= "table" then
    table.insert(errors, "M+ forces dungeonTotal must be a table")
  else
    local mapped = type(season.mapToTeleport) == "table" and season.mapToTeleport or {}
    for mapID in pairs(mapped) do
      local entry = dungeonTotal[mapID]
      if type(entry) ~= "table" or not IsPositiveNumber(entry.total) then
        table.insert(errors, string.format("M+ forces is missing a positive total for map id %d", mapID))
      end
    end
    for mapID in pairs(dungeonTotal) do
      if mapped[mapID] == nil then
        table.insert(errors, string.format("M+ forces contains map id %s outside season %s", tostring(mapID), seasonID))
      end
    end
  end
  if type(byNpcId) ~= "table" or next(byNpcId) == nil then
    table.insert(errors, "M+ forces byNpcId is empty")
  else
    local mapped = type(season.mapToTeleport) == "table" and season.mapToTeleport or {}
    local npcCountByMapID = {}
    for npcID, entry in pairs(byNpcId) do
      local numericNpcID = tonumber(npcID)
      local entryMapID = type(entry) == "table" and tonumber(entry.mapID) or nil
      local entryCount = type(entry) == "table" and tonumber(entry.count) or nil
      if not numericNpcID or numericNpcID <= 0 or numericNpcID ~= math.floor(numericNpcID) then
        table.insert(errors, string.format("M+ forces contains invalid NPC id %s", tostring(npcID)))
      elseif not entryMapID or mapped[entryMapID] == nil then
        table.insert(
          errors,
          string.format("M+ forces NPC id %d points outside season %s", numericNpcID, tostring(seasonID))
        )
      elseif not entryCount or entryCount <= 0 then
        table.insert(errors, string.format("M+ forces NPC id %d must have a positive count", numericNpcID))
      else
        npcCountByMapID[entryMapID] = (npcCountByMapID[entryMapID] or 0) + 1
      end
    end
    for mapID in pairs(mapped) do
      if not npcCountByMapID[mapID] then
        table.insert(errors, string.format("M+ forces is missing positive NPC data for map id %d", mapID))
      end
    end
  end

  local expiresKey = ParseIsoDate(forces.expiresAt)
  local currentDate = ResolveCurrentDate(opts)
  local currentKey = ParseIsoDate(currentDate)
  if not expiresKey then
    table.insert(errors, "M+ forces expiresAt is missing or malformed")
  elseif not currentKey then
    table.insert(errors, "current date is unavailable for M+ forces validation")
  elseif currentKey > expiresKey then
    table.insert(errors, string.format("M+ forces expired on %s", tostring(forces.expiresAt)))
  end
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

function SeasonData.GetMatchingForcesData(seasonID)
  local resolvedSeasonID = seasonID or SeasonData.ACTIVE_SEASON_ID
  local forces = addonTable.MPlusForces
  if type(forces) ~= "table" or forces.season ~= resolvedSeasonID then
    return nil
  end
  if type(forces.dungeonTotal) ~= "table" or type(forces.byNpcId) ~= "table" then
    return nil
  end
  return forces
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

function SeasonData.GetSeasonReadiness(seasonID, opts)
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

  for _, manifestError in ipairs(season.manifestErrors or {}) do
    errors[#errors + 1] = "season manifest: " .. tostring(manifestError)
  end

  local mapToTeleport = season.mapToTeleport
  local displayOrder = season.displayOrder
  local byLocale = season.shortCodesByLocale
  local namesByLocale = season.namesByLocale
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
    local enNames = type(namesByLocale) == "table" and namesByLocale.enUS or nil
    local deNames = type(namesByLocale) == "table" and namesByLocale.deDE or nil

    if type(defaultShortCodes) ~= "table" then
      table.insert(errors, "shortCodesByLocale.default must be a table")
    end
    if type(deShortCodes) ~= "table" then
      table.insert(warnings, "shortCodesByLocale.deDE must be a table")
    end
    if type(enNames) ~= "table" then
      table.insert(errors, "namesByLocale.enUS must be a table")
    end
    if type(deNames) ~= "table" then
      table.insert(errors, "namesByLocale.deDE must be a table")
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

        if type(enNames) == "table" then
          local name = enNames[numericMapID]
          if type(name) ~= "string" or name == "" then
            table.insert(errors, string.format("namesByLocale.enUS is missing map id %d", numericMapID))
          end
        end
        if type(deNames) == "table" then
          local name = deNames[numericMapID]
          if type(name) ~= "string" or name == "" then
            table.insert(errors, string.format("namesByLocale.deDE is missing map id %d", numericMapID))
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

  AppendForcesReadinessErrors(errors, resolvedSeasonID, season, opts)

  return {
    seasonID = resolvedSeasonID,
    label = SeasonData.GetSeasonLabel(resolvedSeasonID),
    isReady = #errors == 0 and #warnings == 0,
    mappedDungeonCount = mapCount,
    aliasCount = aliasCount,
    errors = errors,
    warnings = warnings,
  }
end

function SeasonData.ResolveSeasonIDFromChallengeMapIDs(mapIDs)
  if type(mapIDs) ~= "table" then
    return nil, "Blizzard challenge map list is unavailable"
  end

  local observed = {}
  local observedCount = 0
  for _, rawMapID in ipairs(mapIDs) do
    local mapID = NormalizeMapIDInput(rawMapID)
    if not mapID or mapID <= 0 or mapID ~= math.floor(mapID) then
      return nil, "Blizzard challenge map list contains an invalid map id"
    end
    if observed[mapID] then
      return nil, string.format("Blizzard challenge map list contains duplicate map id %d", mapID)
    end
    observed[mapID] = true
    observedCount = observedCount + 1
  end
  if observedCount == 0 then
    return nil, "Blizzard challenge map list is empty"
  end

  local match
  for seasonID, season in pairs(SeasonData.SEASONS or {}) do
    if type(season) == "table" and season.autoDetectFromChallengeMaps == true then
      local mapped = season.mapToTeleport
      if type(mapped) == "table" and CountTableEntries(mapped) == observedCount then
        local exact = true
        for mapID in pairs(mapped) do
          if observed[mapID] ~= true then
            exact = false
            break
          end
        end
        if exact then
          if match then
            return nil, "Blizzard challenge map list matches more than one configured season"
          end
          match = seasonID
        end
      end
    end
  end

  if not match then
    return nil, "Blizzard challenge map list does not exactly match a configured season"
  end
  return match, nil
end

function SeasonData.TryAutoSelectSeasonFromChallengeMapIDs(mapIDs, opts)
  local seasonID, resolveError = SeasonData.ResolveSeasonIDFromChallengeMapIDs(mapIDs)
  if not seasonID then
    return false, false, resolveError
  end

  local readiness = SeasonData.GetSeasonReadiness(seasonID, opts)
  if not readiness.isReady then
    local reason = readiness.errors[1] or readiness.warnings[1] or "season data is incomplete"
    return false, false, string.format("Season '%s' is not ready: %s", seasonID, reason)
  end
  if SeasonData.ACTIVE_SEASON_ID == seasonID then
    return true, false, string.format("Active season already matches %s", seasonID)
  end

  local ok, message = SeasonData.SetActiveSeasonID(seasonID, opts)
  return ok, ok == true, message
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

  local readiness = SeasonData.GetSeasonReadiness(resolvedSeasonID, opts)
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

function SeasonData.GetMinimumPlayerLevel(mapID, seasonID)
  local numericMapID = SeasonData.NormalizeMapID(mapID, seasonID)
  if not numericMapID then
    return nil
  end

  local season = SeasonData.GetSeasonConfig(seasonID)
  local minimumLevels = type(season) == "table" and season.minimumPlayerLevelByMapID or nil
  local minimumLevel = type(minimumLevels) == "table" and tonumber(minimumLevels[numericMapID]) or nil
  if not minimumLevel or minimumLevel <= 0 or minimumLevel ~= math.floor(minimumLevel) then
    return nil
  end
  return minimumLevel
end

function SeasonData.GetMapIDByActivityID(activityID, seasonID)
  local numericActivityID = tonumber(activityID)
  if not numericActivityID or numericActivityID <= 0 or numericActivityID ~= math.floor(numericActivityID) then
    return nil
  end
  local season = SeasonData.GetSeasonConfig(seasonID)
  local activityToMap = type(season) == "table" and season.activityToMap or nil
  return type(activityToMap) == "table" and activityToMap[numericActivityID] or nil
end

function SeasonData.GetMdtDirectory(seasonID)
  local season = SeasonData.GetSeasonConfig(seasonID)
  if type(season) ~= "table" or type(season.mdtDirectory) ~= "string" or season.mdtDirectory == "" then
    return nil
  end
  return season.mdtDirectory
end

function SeasonData.GetPortalNavigatorConfig(seasonID)
  local season = SeasonData.GetSeasonConfig(seasonID)
  if type(season) ~= "table" or type(season.portalNavigator) ~= "table" then
    return nil
  end
  return season.portalNavigator
end

-- Returns the hub-zone gate for the season's portal room as lookup sets:
-- `mapIDs` keyed by numeric map id, `names` keyed by lowercased zone name.
-- Callers compare against both because the map id is unavailable in some states.
function SeasonData.GetPortalNavigatorZone(seasonID)
  local navigator = SeasonData.GetPortalNavigatorConfig(seasonID)
  local zone = type(navigator) == "table" and navigator.zone or nil
  if type(zone) ~= "table" then
    return { mapIDs = {}, names = {} }
  end

  local mapIDs = {}
  for _, rawMapID in ipairs(type(zone.mapIDs) == "table" and zone.mapIDs or {}) do
    local mapID = NormalizeMapIDInput(rawMapID)
    if mapID and mapID > 0 then
      mapIDs[mapID] = true
    end
  end

  local names = {}
  for _, rawName in ipairs(type(zone.names) == "table" and zone.names or {}) do
    if type(rawName) == "string" and rawName ~= "" then
      names[string.lower(rawName)] = true
    end
  end

  return { mapIDs = mapIDs, names = names }
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

function SeasonData.GetDungeonName(mapID, localeTag, seasonID)
  local numericMapID = SeasonData.NormalizeMapID(mapID, seasonID)
  if not numericMapID then
    return nil
  end

  local season = SeasonData.GetSeasonConfig(seasonID)
  if type(season) ~= "table" then
    return nil
  end

  local byLocale = season.namesByLocale or {}
  local localeKey = NormalizeLocaleTag(localeTag)
  if localeKey ~= "default" and type(byLocale[localeKey]) == "table" then
    local localizedName = byLocale[localeKey][numericMapID]
    if type(localizedName) == "string" and localizedName ~= "" then
      return localizedName
    end
  end

  local defaultNames = byLocale.enUS
  if type(defaultNames) == "table" then
    local defaultName = defaultNames[numericMapID]
    if type(defaultName) == "string" and defaultName ~= "" then
      return defaultName
    end
  end

  return nil
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
