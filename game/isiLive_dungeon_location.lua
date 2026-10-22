local _, addonTable = ...
addonTable = addonTable or {}

-- Resolves the outdoor zone (and, when known, the entrance coordinates) of a
-- challenge-mode dungeon for the accepted-invite card. Season dungeons use the
-- curated `entrance` from the season manifest; the zone name is still read
-- from the client so it is localized.
--
-- Fallback for dungeons without a curated entrance, ID chain (signatures per warcraft.wiki.gg, checked 2026-10-21):
--   challenge map ID -> instance ID     (Validators.ResolveChallengeMapInstanceID)
--   instance ID -> journal instance ID  (C_EncounterJournal.GetInstanceForGameMap,
--                                        takes a game map ID, not a UiMapID)
--   journal instance -> entrance pin    (C_EncounterJournal.GetDungeonEntrancesForMap
--                                        on each zone, matched by journalInstanceID)
-- EJ_GetInstanceInfo's 7th return (dungeonAreaMapID) is 0 for many dungeons,
-- so its parent zone is only the cheap first candidate; the full zone scan is
-- the fallback. Unresolved lookups return nil and the card omits the row.
local DungeonLocation = {}
addonTable.DungeonLocation = DungeonLocation

-- Enum.UIMapType: 1 World, 2 Continent, 3 Zone.
local UI_MAP_TYPE_CONTINENT = 2
local UI_MAP_TYPE_ZONE = 3
-- Azeroth; its zone descendants cover every continent the dungeons sit on.
local COSMIC_SCAN_ROOT_MAP_ID = 946
local MAX_PARENT_STEPS = 8

local locationByChallengeMapID = {}

local function IsSecret(value)
  return addonTable.Validators.IsSecretValue(value)
end

local function ReadPositiveNumber(value)
  if IsSecret(value) or type(value) ~= "number" or value <= 0 or value ~= value or value >= math.huge then
    return nil
  end
  return value
end

local function GetApi(namespace, member)
  local api = rawget(_G, namespace)
  if type(api) ~= "table" then
    return nil
  end
  local fn = rawget(api, member)
  return type(fn) == "function" and fn or nil
end

local function GetMapInfo(uiMapID)
  local getMapInfo = GetApi("C_Map", "GetMapInfo")
  if not getMapInfo then
    return nil
  end
  local ok, info = pcall(getMapInfo, uiMapID)
  if not ok or IsSecret(info) or type(info) ~= "table" then
    return nil
  end
  return info
end

local function ReadMapName(info)
  local name = info and rawget(info, "name")
  if IsSecret(name) or type(name) ~= "string" or name == "" then
    return nil
  end
  return name
end

local function ReadMapType(info)
  local mapType = info and rawget(info, "mapType")
  if IsSecret(mapType) or type(mapType) ~= "number" then
    return nil
  end
  return mapType
end

-- Walks up from a dungeon's own UiMap to the first zone above it.
local function FindParentZone(uiMapID)
  local current = ReadPositiveNumber(uiMapID)
  for _ = 1, MAX_PARENT_STEPS do
    if not current then
      return nil
    end
    local info = GetMapInfo(current)
    if not info then
      return nil
    end
    local mapType = ReadMapType(info)
    if mapType == UI_MAP_TYPE_ZONE then
      return current, ReadMapName(info)
    end
    if mapType and mapType <= UI_MAP_TYPE_CONTINENT then
      return nil
    end
    current = ReadPositiveNumber(rawget(info, "parentMapID"))
  end
  return nil
end

local function ResolveJournalInstanceID(challengeMapID)
  local instanceID = addonTable.Validators.ResolveChallengeMapInstanceID(challengeMapID)
  local getInstanceForGameMap = GetApi("C_EncounterJournal", "GetInstanceForGameMap")
  if not instanceID or not getInstanceForGameMap then
    return nil
  end
  local ok, journalInstanceID = pcall(getInstanceForGameMap, instanceID)
  if not ok then
    return nil
  end
  return ReadPositiveNumber(journalInstanceID)
end

local function ReadDungeonAreaMapID(journalInstanceID)
  local getInstanceInfo = rawget(_G, "EJ_GetInstanceInfo")
  if type(getInstanceInfo) ~= "function" then
    return nil
  end
  local ok, _, _, _, _, _, _, dungeonAreaMapID = pcall(getInstanceInfo, journalInstanceID)
  if not ok then
    return nil
  end
  return ReadPositiveNumber(dungeonAreaMapID)
end

local function ReadCoordinate(position, axis)
  local value = type(position) == "table" and rawget(position, axis) or nil
  if IsSecret(value) or type(value) ~= "number" or value < 0 or value > 1 then
    return nil
  end
  return value * 100
end

-- Returns the entrance pin of journalInstanceID on zone uiMapID, if listed.
local function FindEntranceOnZone(zoneMapID, journalInstanceID)
  local getEntrances = GetApi("C_EncounterJournal", "GetDungeonEntrancesForMap")
  if not getEntrances then
    return nil
  end
  local ok, entrances = pcall(getEntrances, zoneMapID)
  if not ok or IsSecret(entrances) or type(entrances) ~= "table" then
    return nil
  end
  for _, entrance in ipairs(entrances) do
    if type(entrance) == "table" and not IsSecret(entrance) then
      local entryID = rawget(entrance, "journalInstanceID")
      if not IsSecret(entryID) and entryID == journalInstanceID then
        local position = rawget(entrance, "position")
        if IsSecret(position) then
          position = nil
        end
        return { x = ReadCoordinate(position, "x"), y = ReadCoordinate(position, "y") }
      end
    end
  end
  return nil
end

local function ScanZonesForEntrance(journalInstanceID)
  local getChildren = GetApi("C_Map", "GetMapChildrenInfo")
  if not getChildren then
    return nil
  end
  local ok, zones = pcall(getChildren, COSMIC_SCAN_ROOT_MAP_ID, UI_MAP_TYPE_ZONE, true)
  if not ok or IsSecret(zones) or type(zones) ~= "table" then
    return nil
  end
  for _, zone in ipairs(zones) do
    local zoneMapID = type(zone) == "table" and not IsSecret(zone) and ReadPositiveNumber(rawget(zone, "mapID"))
    if zoneMapID then
      local entrance = FindEntranceOnZone(zoneMapID, journalInstanceID)
      if entrance then
        local zoneName = ReadMapName(zone) or ReadMapName(GetMapInfo(zoneMapID))
        if zoneName then
          return zoneName, entrance
        end
      end
    end
  end
  return nil
end

-- Manifest fallback name in the client language, else English.
local function ReadFallbackZoneName(zoneNames)
  if type(zoneNames) ~= "table" then
    return nil
  end
  local getLocale = rawget(_G, "GetLocale")
  local ok, localeTag = false, nil
  if type(getLocale) == "function" then
    ok, localeTag = pcall(getLocale)
  end
  local name = ok and type(localeTag) == "string" and zoneNames[localeTag] or nil
  if type(name) ~= "string" or name == "" then
    name = zoneNames.enUS
  end
  return name
end

-- Season manifest entrance (data/isiLive_seasons.lua). The zone name comes
-- from the client so it follows the client language; the manifest's
-- zoneNames only cover a missing or masked map info.
local function ReadCuratedEntrance(challengeMapID)
  local seasonData = addonTable.SeasonData
  if type(seasonData) ~= "table" or type(seasonData.GetDungeonEntrance) ~= "function" then
    return nil
  end
  local ok, entrance = pcall(seasonData.GetDungeonEntrance, challengeMapID)
  if not ok or type(entrance) ~= "table" then
    return nil
  end
  local zoneName = ReadMapName(GetMapInfo(entrance.uiMapID)) or ReadFallbackZoneName(entrance.zoneNames)
  if type(zoneName) ~= "string" or zoneName == "" then
    return nil
  end
  return { zoneName = zoneName, x = entrance.x, y = entrance.y }
end

--- Zone name and entrance coordinates (0-100) of a challenge-mode dungeon.
--- @param challengeMapID any
--- @return table|nil -- { zoneName = string, x = number|nil, y = number|nil }
function DungeonLocation.Resolve(challengeMapID)
  challengeMapID = ReadPositiveNumber(challengeMapID)
  if not challengeMapID then
    return nil
  end
  local cached = locationByChallengeMapID[challengeMapID]
  if cached then
    return cached
  end

  local curated = ReadCuratedEntrance(challengeMapID)
  if curated then
    locationByChallengeMapID[challengeMapID] = curated
    return curated
  end

  local journalInstanceID = ResolveJournalInstanceID(challengeMapID)
  if not journalInstanceID then
    return nil
  end

  local zoneName, entrance
  local zoneMapID, parentZoneName = FindParentZone(ReadDungeonAreaMapID(journalInstanceID))
  if zoneMapID then
    entrance = FindEntranceOnZone(zoneMapID, journalInstanceID)
    zoneName = parentZoneName
  end
  if not entrance then
    local scannedZoneName, scannedEntrance = ScanZonesForEntrance(journalInstanceID)
    if scannedZoneName then
      zoneName, entrance = scannedZoneName, scannedEntrance
    end
  end
  if not zoneName then
    return nil
  end

  local location = { zoneName = zoneName, x = entrance and entrance.x, y = entrance and entrance.y }
  -- The dungeon -> zone mapping is static; failed lookups stay uncached.
  locationByChallengeMapID[challengeMapID] = location
  return location
end

--- Name of the season portal room when it holds a portal to this dungeon
--- (the dungeon fills a portalNavigator slot), else nil. The client's map name
--- comes first; the manifest's first zone name covers a missing map info.
--- @param challengeMapID any
--- @return string|nil
function DungeonLocation.GetPortalRoomName(challengeMapID)
  challengeMapID = ReadPositiveNumber(challengeMapID)
  local seasonData = addonTable.SeasonData
  if not challengeMapID or type(seasonData) ~= "table" or type(seasonData.GetPortalNavigatorConfig) ~= "function" then
    return nil
  end
  local ok, navigator = pcall(seasonData.GetPortalNavigatorConfig)
  if not ok or type(navigator) ~= "table" or type(navigator.slots) ~= "table" then
    return nil
  end
  local hasPortal = false
  for _, slotMapID in pairs(navigator.slots) do
    if slotMapID == challengeMapID then
      hasPortal = true
      break
    end
  end
  local zone = navigator.zone
  if not hasPortal or type(zone) ~= "table" then
    return nil
  end
  local hubMapID = type(zone.mapIDs) == "table" and zone.mapIDs[1] or nil
  local name = hubMapID and ReadMapName(GetMapInfo(hubMapID)) or nil
  if not name and type(zone.names) == "table" and type(zone.names[1]) == "string" and zone.names[1] ~= "" then
    name = zone.names[1]
  end
  return name
end

--- Display text for the "Navigation" row: the zone name, plus a second line
--- with the portal hint when the season portal room has this dungeon.
--- @param challengeMapID any
--- @param portalFormat string|nil -- format with %s (portal room name)
--- @return string|nil
function DungeonLocation.GetNavigationText(challengeMapID, portalFormat)
  local lines = {}
  local location = DungeonLocation.Resolve(challengeMapID)
  if location then
    lines[1] = location.zoneName
  end
  local portalRoomName = DungeonLocation.GetPortalRoomName(challengeMapID)
  if portalRoomName then
    -- The German map name can carry its article ("Die Jahrhundertschwelle");
    -- the localized sentence supplies its own ("in der %s").
    portalRoomName = portalRoomName:gsub("^Die ", "")
    lines[#lines + 1] = string.format(portalFormat or "Use the portal in %s", portalRoomName)
  end
  if #lines == 0 then
    return nil
  end
  return table.concat(lines, "\n")
end

return DungeonLocation
