local _, addonTable = ...

addonTable = addonTable or {}

local Teleport = {}
addonTable.Teleport = Teleport

local SeasonData = addonTable.SeasonData or {}

local function GetMapToTeleport()
  if type(SeasonData.GetMapToTeleport) == "function" then
    return SeasonData.GetMapToTeleport()
  end
  return SeasonData.MAP_TO_TELEPORT or {}
end

-- Cache: ActivityID -> SpellID / MapID
local ACTIVITY_TO_TELEPORT_CACHE = {}
local ACTIVITY_TO_MAP_CACHE = {}

local pendingCombatUpdates = {}
local function ClearTable(t)
  if type(t) ~= "table" then
    return
  end
  for key in pairs(t) do
    t[key] = nil
  end
end
local combatRetryFrame = CreateFrame("Frame")
combatRetryFrame:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_REGEN_ENABLED" then
    for button, spellID in pairs(pendingCombatUpdates) do
      Teleport.ApplySecureSpellToButton(button, spellID)
    end
    ClearTable(pendingCombatUpdates)
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
  local mapToTeleport = GetMapToTeleport()
  local mapped = mapToTeleport[mapID]

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
  local mapToTeleport = GetMapToTeleport()
  local mapped = mapToTeleport[mapID]

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
  local mapToTeleport = GetMapToTeleport()
  for mapID in pairs(mapToTeleport) do
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

function Teleport.ResolveSeason3MapIDByActivityID(activityID)
  local numericActivityID = tonumber(activityID)
  if not numericActivityID or numericActivityID <= 0 then
    return nil
  end

  local cached = ACTIVITY_TO_MAP_CACHE[numericActivityID]
  if type(cached) == "number" and cached > 0 then
    return cached
  end

  if not (C_LFGList and C_LFGList.GetActivityInfoTable) then
    return nil
  end

  local ok, activityInfo = pcall(C_LFGList.GetActivityInfoTable, numericActivityID)
  if not ok or type(activityInfo) ~= "table" then
    return nil
  end

  local mapID = tonumber(rawget(activityInfo, "mapID") or rawget(activityInfo, "mapId"))
  if not mapID or mapID <= 0 then
    return nil
  end

  ACTIVITY_TO_MAP_CACHE[numericActivityID] = mapID
  return mapID
end

function Teleport.ResolveTeleportSpellByActivityID(activityID)
  local numericActivityID = tonumber(activityID)
  if not numericActivityID or numericActivityID <= 0 then
    return nil
  end

  -- Cache successful resolutions only. Unresolved lookups must be retryable.
  local cached = ACTIVITY_TO_TELEPORT_CACHE[numericActivityID]
  if type(cached) == "number" and cached > 0 then
    return cached
  end

  local mapID = Teleport.ResolveSeason3MapIDByActivityID(numericActivityID)
  if not mapID then
    return nil
  end

  local spellID = Teleport.ResolveSeason3TeleportSpellIDByMapID(mapID)
  if not spellID then
    return nil
  end

  ACTIVITY_TO_TELEPORT_CACHE[numericActivityID] = spellID
  return spellID
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

  local mapName = nil
  if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
    local resolvedMapName = C_ChallengeMode.GetMapUIInfo(numericMapID)
    if type(resolvedMapName) == "string" and resolvedMapName ~= "" then
      mapName = resolvedMapName
    end
  end
  return {
    mapID = numericMapID,
    mapName = mapName,
    spellID = spellID,
    icon = icon,
  }
end

function Teleport.GetSeason3DungeonShortCode(mapID, localeTag)
  local numericMapID = tonumber(mapID)
  if not numericMapID then
    return "?"
  end

  local shortCode = nil
  if type(SeasonData.GetDungeonShortCode) == "function" then
    shortCode = SeasonData.GetDungeonShortCode(numericMapID, localeTag)
  elseif type(SeasonData.MAP_SHORT_CODES) == "table" then
    shortCode = SeasonData.MAP_SHORT_CODES[numericMapID]
  end

  if type(shortCode) == "string" and shortCode ~= "" then
    return shortCode
  end

  return tostring(numericMapID)
end

function Teleport.ResolveSeason3TeleportSpellIDByMapID(mapID)
  local numericMapID = tonumber(mapID)
  local mapToTeleport = GetMapToTeleport()
  if numericMapID and mapToTeleport[numericMapID] then
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

  -- Strict resolver: activityID -> mapID -> spellID only.
  return Teleport.ResolveTeleportSpellByActivityID(activityID)
end

function Teleport.ResolveSeason3TeleportSpellID(activityID, _dungeonName)
  return Teleport.ResolveSeason3TeleportSpellIDByActivityID(activityID)
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
  local mapToTeleport = GetMapToTeleport()
  for mapID in pairs(mapToTeleport) do
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
