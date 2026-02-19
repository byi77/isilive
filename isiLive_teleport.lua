local _, addonTable = ...

addonTable = addonTable or {}

local Teleport = {}
addonTable.Teleport = Teleport

local SeasonData = addonTable.SeasonData or {}
local MAP_TO_TELEPORT = SeasonData.MAP_TO_TELEPORT or {}
local MAP_SHORT_CODES = SeasonData.MAP_SHORT_CODES or {}

-- Cache: ActivityID -> SpellID
local ACTIVITY_TO_TELEPORT_CACHE = {}
local TAZAVESH_TOKENS_CACHE = nil

local pendingCombatUpdates = {}
local combatRetryFrame = CreateFrame("Frame")
combatRetryFrame:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_REGEN_ENABLED" then
    for button, spellID in pairs(pendingCombatUpdates) do
      Teleport.ApplySecureSpellToButton(button, spellID)
    end
    table.wipe(pendingCombatUpdates)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end
end)

local function IsSpellKnownByID(spellID)
  if not spellID then
    return false
  end

  if C_SpellBook and C_SpellBook.IsSpellKnownOrOverridesKnown then
    local ok, known = pcall(C_SpellBook.IsSpellKnownOrOverridesKnown, spellID)
    if ok and known == true then
      return true
    end
  end

  if C_SpellBook and C_SpellBook.IsSpellKnown then
    local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
    if ok and known == true then
      return true
    end
  end

  return false
end

local function ResolveMappedSpellID(mapID)
  local mapped = MAP_TO_TELEPORT[mapID]

  if type(mapped) == "number" then
    return mapped
  end

  if type(mapped) == "table" then
    local firstCandidate = nil
    for _, candidate in ipairs(mapped) do
      local spellID = tonumber(candidate)
      if spellID then
        if not firstCandidate then
          firstCandidate = spellID
        end
        if IsSpellKnownByID(spellID) then
          return spellID
        end
      end
    end
    return firstCandidate
  end

  return nil
end

local function IterateMappedSpellIDs(mapID, callback)
  local mapped = MAP_TO_TELEPORT[mapID]

  if type(mapped) == "number" then
    callback(mapped)
    return
  end

  if type(mapped) == "table" then
    for _, candidate in ipairs(mapped) do
      local spellID = tonumber(candidate)
      if spellID then
        callback(spellID)
      end
    end
  end
end

local function CollectMapIDsForSpell(spellID)
  local numericSpellID = tonumber(spellID)
  if not numericSpellID then
    return {}
  end

  local mapIDs = {}
  for mapID in pairs(MAP_TO_TELEPORT) do
    local matched = false
    IterateMappedSpellIDs(mapID, function(mappedSpellID)
      if mappedSpellID == numericSpellID then
        matched = true
      end
    end)
    if matched then
      table.insert(mapIDs, mapID)
    end
  end

  table.sort(mapIDs)
  return mapIDs
end

local function NormalizeNameForMatch(text)
  if type(text) ~= "string" then
    return ""
  end
  local normalized = string.lower(text)
  normalized = normalized:gsub("[%p%c]", " ")
  normalized = normalized:gsub("%s+", " ")
  normalized = normalized:gsub("^%s+", "")
  normalized = normalized:gsub("%s+$", "")
  return normalized
end

local function GetTazaveshMatchTokens()
  if TAZAVESH_TOKENS_CACHE then
    return TAZAVESH_TOKENS_CACHE
  end

  local tokens = {}
  local seen = {}
  local function AddToken(raw)
    local token = NormalizeNameForMatch(raw)
    if token == "" or seen[token] then
      return
    end
    seen[token] = true
    table.insert(tokens, token)
  end

  local info = Teleport.GetSeason3TeleportInfoByMapID(2441)
  if info and info.mapName then
    AddToken(info.mapName)
    for part in string.gmatch(info.mapName, "[^:/%-]+") do
      AddToken(part)
    end
  end

  -- Fallback aliases for cases where activity/map names are incomplete.
  AddToken("Tazavesh")
  AddToken("Streets of Wonder")
  AddToken("So'leah's Gambit")
  AddToken("Soleahs Gambit")

  TAZAVESH_TOKENS_CACHE = tokens
  return tokens
end

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
    if mapID and MAP_TO_TELEPORT[mapID] then
      local spellID = ResolveMappedSpellID(mapID)
      if spellID then
        ACTIVITY_TO_TELEPORT_CACHE[activityID] = spellID
        return spellID
      end
    end
  end
  return nil
end

function Teleport.GetSeason3TeleportInfoByMapID(mapID)
  local numericMapID = tonumber(mapID)
  if not numericMapID then
    return nil
  end

  local spellID = ResolveMappedSpellID(numericMapID)
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

function Teleport.GetSeason3DungeonShortCode(mapID)
  local numericMapID = tonumber(mapID)
  if not numericMapID then
    return "?"
  end
  if MAP_SHORT_CODES[numericMapID] then
    return MAP_SHORT_CODES[numericMapID]
  end

  local mapName = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(numericMapID)
  if type(mapName) ~= "string" or mapName == "" then
    return tostring(numericMapID)
  end

  local acronym = ""
  for word in string.gmatch(mapName, "%a+") do
    acronym = acronym .. string.upper(string.sub(word, 1, 1))
    if #acronym >= 4 then
      break
    end
  end
  if acronym == "" then
    return tostring(numericMapID)
  end
  return acronym
end

function Teleport.ResolveSeason3TeleportSpellIDByMapID(mapID)
  local numericMapID = tonumber(mapID)
  if numericMapID and MAP_TO_TELEPORT[numericMapID] then
    return ResolveMappedSpellID(numericMapID)
  end
  return nil
end

function Teleport.ResolveSeason3MapIDBySpellID(spellID)
  local mapIDs = Teleport.ResolveSeason3MapIDsBySpellID(spellID)
  if type(mapIDs) ~= "table" then
    return nil
  end
  return mapIDs[1]
end

function Teleport.ResolveSeason3MapIDsBySpellID(spellID)
  local mapIDs = CollectMapIDsForSpell(spellID)
  if #mapIDs == 0 then
    return nil
  end
  return mapIDs
end

function Teleport.ResolveSeason3TeleportSpellIDByActivityID(activityID)
  if not activityID then
    return nil
  end

  -- Nutze die Cache-Funktion, die bereits den kompletten Lookup (Cache + LFG-Fallback) durchführt.
  return Teleport.ResolveTeleportSpellByActivityID(activityID)
end

function Teleport.ResolveSeason3TeleportSpellID(activityID, dungeonName)
  local spellFromActivityID = Teleport.ResolveSeason3TeleportSpellIDByActivityID(activityID)
  if spellFromActivityID then
    return spellFromActivityID
  end

  -- Fallback: Name resolution
  local nameToUse = dungeonName
  if (not nameToUse or nameToUse == "") and activityID and C_LFGList and C_LFGList.GetActivityInfoTable then
    local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
    if ok and info then
      nameToUse = info.fullName or info.shortName
    end
  end

  if nameToUse and nameToUse ~= "" then
    local normalizedName = NormalizeNameForMatch(nameToUse)
    for _, token in ipairs(GetTazaveshMatchTokens()) do
      if token ~= "" and string.find(normalizedName, token, 1, true) then
        return 367416
      end
    end
    for mapID in pairs(MAP_TO_TELEPORT) do
      local info = Teleport.GetSeason3TeleportInfoByMapID(mapID)
      if info and info.mapName then
        local normalizedMapName = NormalizeNameForMatch(info.mapName)
        if normalizedMapName ~= "" and string.find(normalizedName, normalizedMapName, 1, true) then
          return info.spellID
        end
      end
      if info and info.mapName and string.find(nameToUse, info.mapName, 1, true) then
        return info.spellID
      end
    end
  end

  return nil
end

function Teleport.ApplySecureSpellToButton(button, spellID)
  if not button or not spellID then
    return false
  end

  -- Protection: Cannot set attributes on secure frames while in combat.
  if InCombatLockdown and InCombatLockdown() then
    pendingCombatUpdates[button] = spellID
    combatRetryFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
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
  if button.EnableMouse then
    button:EnableMouse(true)
  end

  -- Clear from pending if it was queued previously
  if pendingCombatUpdates[button] then
    pendingCombatUpdates[button] = nil
    if next(pendingCombatUpdates) == nil then
      combatRetryFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
  end
  return true
end

function Teleport.BuildSeason3TeleportEntries()
  local entries = {}
  local bySpellID = {}
  local orderedMapIDs = {}
  for mapID in pairs(MAP_TO_TELEPORT) do
    table.insert(orderedMapIDs, mapID)
  end
  table.sort(orderedMapIDs)

  for _, mapID in ipairs(orderedMapIDs) do
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
