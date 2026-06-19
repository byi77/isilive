local _, addonTable = ...

addonTable = addonTable or {}

local Teleport = {}
addonTable.Teleport = Teleport

local SeasonData = addonTable.SeasonData or {}
local SpellUtils = addonTable.SpellUtils

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

local createFrame = rawget(_G, "CreateFrame")
local combatRetryFrame = type(createFrame) == "function" and createFrame("Frame") or nil
-- PLAYER_REGEN_ENABLED is registered statically at module load to avoid a
-- dynamic RegisterEvent from handlers dispatched by protected code (e.g.
-- CHALLENGE_MODE_START), which raises ADDON_ACTION_FORBIDDEN in 12.0+.
if combatRetryFrame then
  combatRetryFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  combatRetryFrame:SetScript("OnEvent", function(_, event)
    if event ~= "PLAYER_REGEN_ENABLED" then
      return
    end
    if next(pendingCombatUpdates) == nil then
      return
    end
    -- Snapshot the queue so ApplySecureSpellToButton's own per-entry mutations
    -- (clears successful entries, re-defers if it sees InCombatLockdown again)
    -- don't race the pairs() traversal. No blanket ClearTable afterwards — the
    -- per-entry state is the source of truth so a re-deferred apply survives to
    -- the next regen tick.
    local snapshot = {}
    for button, spellID in pairs(pendingCombatUpdates) do
      snapshot[button] = spellID
    end
    for button, spellID in pairs(snapshot) do
      Teleport.ApplySecureSpellToButton(button, spellID)
    end
  end)
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
        if SpellUtils.IsSpellKnownSafe(spellID) then
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

function Teleport.ResolveMapIDByActivityID(activityID)
  local numericActivityID = tonumber(activityID)
  if not numericActivityID or numericActivityID <= 0 then
    return nil
  end

  local cached = ACTIVITY_TO_MAP_CACHE[numericActivityID]
  if type(cached) == "number" and cached > 0 then
    return cached
  end

  local lfgListApi = rawget(_G, "C_LFGList")
  if type(lfgListApi) ~= "table" or type(lfgListApi.GetActivityInfoTable) ~= "function" then
    return nil
  end

  local ok, activityInfo = pcall(lfgListApi.GetActivityInfoTable, numericActivityID)
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

  local mapID = Teleport.ResolveMapIDByActivityID(numericActivityID)
  if not mapID then
    return nil
  end

  local spellID = Teleport.ResolveTeleportSpellIDByMapID(mapID)
  if not spellID then
    return nil
  end

  ACTIVITY_TO_TELEPORT_CACHE[numericActivityID] = spellID
  return spellID
end

function Teleport.GetTeleportInfoByMapID(mapID)
  local numericMapID = tonumber(mapID)
  if type(SeasonData.NormalizeMapID) == "function" then
    numericMapID = SeasonData.NormalizeMapID(numericMapID)
  end
  if not numericMapID then
    return nil
  end

  local spellID = ResolveMappedSpellID(numericMapID)
  if not spellID then
    return nil
  end

  local icon
  local spellApi = rawget(_G, "C_Spell")
  if type(spellApi) == "table" and type(spellApi.GetSpellTexture) == "function" then
    icon = spellApi.GetSpellTexture(spellID)
  end
  if not icon then
    icon = "Interface\\Icons\\INV_Misc_QuestionMark"
  end

  local mapName = Teleport.GetDungeonName and Teleport.GetDungeonName(numericMapID) or nil
  return {
    mapID = numericMapID,
    mapName = mapName,
    spellID = spellID,
    icon = icon,
  }
end

function Teleport.GetDungeonShortCode(mapID, localeTag)
  local numericMapID = tonumber(mapID)
  if not numericMapID then
    return nil
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

  return nil
end

function Teleport.GetDungeonName(mapID, localeTag)
  local numericMapID = tonumber(mapID)
  if type(SeasonData.NormalizeMapID) == "function" then
    numericMapID = SeasonData.NormalizeMapID(numericMapID)
  end
  if not numericMapID then
    return nil
  end

  local currentLocale = nil
  local getLocale = rawget(_G, "GetLocale")
  if type(getLocale) == "function" then
    local ok, locale = pcall(getLocale)
    if ok and type(locale) == "string" and locale ~= "" then
      currentLocale = locale
    end
  end

  local resolvedLocale = (localeTag ~= nil and localeTag ~= "") and localeTag or currentLocale

  local dungeonName = nil
  if type(SeasonData.GetDungeonName) == "function" then
    dungeonName = SeasonData.GetDungeonName(numericMapID, resolvedLocale)
  end
  if type(dungeonName) == "string" and dungeonName ~= "" then
    return dungeonName
  end

  if resolvedLocale == nil or resolvedLocale == "" or resolvedLocale == currentLocale then
    local challengeMode = rawget(_G, "C_ChallengeMode")
    if type(challengeMode) == "table" and type(challengeMode.GetMapUIInfo) == "function" then
      local okName, localizedName = pcall(challengeMode.GetMapUIInfo, numericMapID)
      if okName and type(localizedName) == "string" and localizedName ~= "" then
        return localizedName
      end
    end
  end

  return nil
end

function Teleport.ResolveTeleportSpellIDByMapID(mapID)
  local numericMapID = tonumber(mapID)
  if type(SeasonData.NormalizeMapID) == "function" then
    numericMapID = SeasonData.NormalizeMapID(numericMapID)
  end
  local mapToTeleport = GetMapToTeleport()
  if numericMapID and mapToTeleport[numericMapID] then
    return ResolveMappedSpellID(numericMapID)
  end
  return nil
end

function Teleport.ResolveMapIDBySpellID(spellID)
  local mapIDs = Teleport.ResolveMapIDsBySpellID(spellID)
  if type(mapIDs) ~= "table" then
    return nil
  end
  return mapIDs[1]
end

function Teleport.ResolveMapIDsBySpellID(spellID)
  local mapIDs = CollectMapIDsForSpell(spellID)
  if #mapIDs == 0 then
    return nil
  end
  return mapIDs
end

function Teleport.ResolveTeleportSpellIDByActivityID(activityID)
  if not activityID then
    return nil
  end

  -- Strict resolver: activityID -> mapID -> spellID only.
  return Teleport.ResolveTeleportSpellByActivityID(activityID)
end

function Teleport.ResolveTeleportSpellID(activityID, _dungeonName)
  return Teleport.ResolveTeleportSpellIDByActivityID(activityID)
end

function Teleport.ApplySecureSpellToButton(button, spellID)
  if not button or not spellID then
    return false
  end

  -- Protection: Cannot set attributes on secure frames while in combat.
  local inCombat = rawget(_G, "InCombatLockdown")
  if type(inCombat) == "function" and inCombat() then
    pendingCombatUpdates[button] = spellID
    return false
  end

  local spellValue = spellID
  local spellApi = rawget(_G, "C_Spell")
  if type(spellApi) == "table" and type(spellApi.GetSpellName) == "function" then
    local spellName = spellApi.GetSpellName(spellID)
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

  pendingCombatUpdates[button] = nil
  return true
end

function Teleport.BuildTeleportEntries()
  local entries = {}
  local seenSpellID = {}
  local orderedMapIDs = nil

  if type(SeasonData.GetOrderedMapIDs) == "function" then
    orderedMapIDs = SeasonData.GetOrderedMapIDs()
  end

  if type(orderedMapIDs) ~= "table" then
    orderedMapIDs = {}
    local mapToTeleport = GetMapToTeleport()
    for mapID in pairs(mapToTeleport) do
      table.insert(orderedMapIDs, mapID)
    end
    table.sort(orderedMapIDs)
  elseif #orderedMapIDs == 0 then
    local mapToTeleport = GetMapToTeleport()
    for mapID in pairs(mapToTeleport) do
      table.insert(orderedMapIDs, mapID)
    end
    table.sort(orderedMapIDs)
  end

  for slotIndex, mapID in ipairs(orderedMapIDs) do
    local info = Teleport.GetTeleportInfoByMapID(mapID)
    if info then
      local spellID = tonumber(info.spellID)
      if spellID and not seenSpellID[spellID] then
        seenSpellID[spellID] = true
        info.slotIndex = slotIndex
        table.insert(entries, info)
      end
    end
  end

  return entries
end
