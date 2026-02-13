local _, addonTable = ...

addonTable = addonTable or {}

local Teleport = {}
addonTable.Teleport = Teleport

local TWW_SEASON3_MAP_TO_TELEPORT = {
  -- TWW Season 3 mapIDs (aktuelle WoW Version)
  [2649] = 445444, -- Priory of the Sacred Flame
  [2830] = 1237215, -- Eco-Dome Al'dani
  [2287] = 354465, -- Halls of Atonement
  [2773] = 1216786, -- Operation: Floodgate
  [2660] = 445417, -- Ara-Kara, City of Echoes
  [2441] = 367416, -- Tazavesh: Streets of Wonder / So'leah's Gambit
  [2662] = 445414, -- The Dawnbreaker
}

-- Cache: ActivityID -> SpellID
local ACTIVITY_TO_TELEPORT_CACHE = {}

function Teleport.AddActivityToTeleportCache(activityID, spellID)
  if activityID and spellID then
    ACTIVITY_TO_TELEPORT_CACHE[activityID] = spellID
  end
end

function Teleport.ResolveTeleportSpellByActivityID(activityID)
  if not activityID then
    return nil
  end

  -- Prüfe Cache zuerst
  if ACTIVITY_TO_TELEPORT_CACHE[activityID] then
    return ACTIVITY_TO_TELEPORT_CACHE[activityID]
  end

  -- Versuche via GetActivityInfoTable
  if not (C_LFGList and C_LFGList.GetActivityInfoTable) then
    return nil
  end

  local ok, activityInfo = pcall(C_LFGList.GetActivityInfoTable, activityID)
  if ok and type(activityInfo) == "table" then
    local mapID = tonumber(rawget(activityInfo, "mapID") or rawget(activityInfo, "mapId"))

    -- Versuche via mapID
    if mapID and TWW_SEASON3_MAP_TO_TELEPORT[mapID] then
      local spellID = TWW_SEASON3_MAP_TO_TELEPORT[mapID]
      ACTIVITY_TO_TELEPORT_CACHE[activityID] = spellID
      return spellID
    end
  end
  return nil
end

function Teleport.GetSeason3TeleportInfoByMapID(mapID)
  local numericMapID = tonumber(mapID)
  if not numericMapID then
    return nil
  end

  local spellID = TWW_SEASON3_MAP_TO_TELEPORT[numericMapID]
  if not spellID then
    return nil
  end

  local icon
  if C_Spell and C_Spell.GetSpellTexture then
    icon = C_Spell.GetSpellTexture(spellID)
  end
  if not icon then
    icon = "Interface\\Icons\\INV_Misc_QuestionMark"
  end

  local mapName = (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(numericMapID))
    or tostring(numericMapID)
  return {
    mapID = numericMapID,
    mapName = mapName,
    spellID = spellID,
    icon = icon,
  }
end

function Teleport.ResolveSeason3TeleportSpellIDByMapID(mapID)
  local info = Teleport.GetSeason3TeleportInfoByMapID(mapID)
  if info and info.spellID then
    return info.spellID
  end
  return nil
end

function Teleport.ResolveSeason3TeleportSpellIDByActivityID(activityID)
  if not activityID then
    return nil
  end

  -- Versuche zuerst den Activity Cache
  local cachedSpell = Teleport.ResolveTeleportSpellByActivityID(activityID)
  if cachedSpell then
    return cachedSpell
  end

  -- Fallback: Versuche über MapID via GetActivityInfoTable
  if not (C_LFGList and C_LFGList.GetActivityInfoTable) then
    return nil
  end

  local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
  if not ok or not info then
    return nil
  end

  local mapID = tonumber(rawget(info, "mapID") or rawget(info, "mapId"))
  if mapID then
    local spellID = Teleport.ResolveSeason3TeleportSpellIDByMapID(mapID)
    if spellID then
      return spellID, mapID
    end
  end
  return nil
end

function Teleport.ResolveSeason3TeleportSpellID(activityID, dungeonName)
  local _ = dungeonName
  local spellFromActivityID = Teleport.ResolveSeason3TeleportSpellIDByActivityID(activityID)
  if spellFromActivityID then
    return spellFromActivityID
  end
  return nil
end

function Teleport.ApplySecureSpellToButton(button, spellID)
  if not button or not spellID then
    return false
  end

  local spellValue = spellID
  if C_Spell and C_Spell.GetSpellName then
    local spellName = C_Spell.GetSpellName(spellID)
    if spellName and spellName ~= "" then
      spellValue = spellName
    end
  end

  button.spellID = spellID
  button:SetAttribute("type", "spell")
  button:SetAttribute("type1", "spell")
  button:SetAttribute("*type1", "spell")
  button:SetAttribute("useOnKeyDown", true)
  button:SetAttribute("spell", spellValue)
  button:SetAttribute("spell1", spellValue)
  return true
end

function Teleport.BuildSeason3TeleportEntries()
  local entries = {}
  local bySpellID = {}
  for mapID in pairs(TWW_SEASON3_MAP_TO_TELEPORT) do
    local info = Teleport.GetSeason3TeleportInfoByMapID(mapID)
    if info then
      if not bySpellID[info.spellID] then
        bySpellID[info.spellID] = info
      end
    end
  end
  for _, info in pairs(bySpellID) do
    table.insert(entries, info)
  end
  table.sort(entries, function(a, b)
    return tostring(a.mapName) < tostring(b.mapName)
  end)
  return entries
end
