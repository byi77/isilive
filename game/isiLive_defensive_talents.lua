local _, addonTable = ...

addonTable = addonTable or {}

-- Talented defensives of group members (rule 268, vorhaben V1 stage 3).
--
-- Reads Blizzard's inspect trait config while an INSPECT_READY reply is being
-- applied (logic/isiLive_inspect.lua); it never starts an inspect itself. Per
-- GUID it keeps which manifest spells of the class tree are taken. Unreadable
-- data changes nothing: the member stays "unknown", and a talent spell then
-- shows "?" instead of an estimate (no guess).
local DefensiveTalents = {}
addonTable.DefensiveTalents = DefensiveTalents

local Validators = addonTable.Validators
local IsSecretValue = Validators.IsSecretValue
local ReadPlainNumber = Validators.ReadPlainNumber

local INSPECT_CONFIG_FALLBACK = -1 -- Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID

local takenByGuid = {} -- [guid] = { [castID] = true|false }
local spotsByTree = {} -- [treeID] = { { node, entry, spellID } }

local function Manifest()
  local manifest = addonTable.DefensiveManifest
  return type(manifest) == "table" and type(manifest.spells) == "table" and manifest or nil
end

-- Calls C_Traits.<name>; nil when it fails or answers a secret value.
local function CallTraits(name, ...)
  local traits = rawget(_G, "C_Traits")
  local fn = type(traits) == "table" and traits[name] or nil
  if type(fn) ~= "function" then
    return nil
  end
  local ok, result = pcall(fn, ...)
  if not ok or IsSecretValue(result) then
    return nil
  end
  return result
end

local function ReadList(source, field)
  local ok, list = pcall(function()
    return source[field]
  end)
  if not ok or IsSecretValue(list) or type(list) ~= "table" then
    return nil
  end
  local out = {}
  for _, value in ipairs(list) do
    if IsSecretValue(value) or type(value) ~= "number" then
      return nil
    end
    out[#out + 1] = value
  end
  return out
end

local function InspectConfigID()
  local constants = rawget(_G, "Constants")
  local traitConsts = type(constants) == "table" and constants.TraitConsts or nil
  local configID = type(traitConsts) == "table" and ReadPlainNumber(traitConsts, "INSPECT_TRAIT_CONFIG_ID") or nil
  return configID or INSPECT_CONFIG_FALLBACK
end

-- Where the manifest spells sit in a tree, or nil when a part is unreadable.
local function BuildSpots(configID, treeID, manifest)
  local nodes = CallTraits("GetTreeNodes", treeID)
  if type(nodes) ~= "table" then
    return nil
  end
  local spots = {}
  for _, nodeID in ipairs(nodes) do
    local node = CallTraits("GetNodeInfo", configID, nodeID)
    if type(node) ~= "table" then
      return nil
    end
    local entries = ReadList(node, "entryIDs")
    if not entries then
      return nil
    end
    for _, entryID in ipairs(entries) do
      local entry = CallTraits("GetEntryInfo", configID, entryID)
      if type(entry) ~= "table" then
        return nil
      end
      -- No definition on a hero tree selection entry.
      local definitionID = ReadPlainNumber(entry, "definitionID")
      local definition = definitionID and CallTraits("GetDefinitionInfo", definitionID) or nil
      local spellID = type(definition) == "table" and ReadPlainNumber(definition, "spellID") or nil
      if spellID and manifest.spells[spellID] then
        spots[#spots + 1] = { node = nodeID, entry = entryID, spellID = spellID }
      end
    end
  end
  return #nodes > 0 and spots or nil
end

-- The taken manifest talents of one tree into `taken`; false when unreadable.
local function ReadTree(configID, treeID, manifest, taken)
  local spots = spotsByTree[treeID]
  if not spots then
    spots = BuildSpots(configID, treeID, manifest)
    if not spots then
      return false
    end
    spotsByTree[treeID] = spots
  end
  for _, spot in ipairs(spots) do
    local node = CallTraits("GetNodeInfo", configID, spot.node)
    if type(node) ~= "table" then
      return false
    end
    local rank = ReadPlainNumber(node, "activeRank")
    if not rank then
      return false
    end
    local active = false
    if rank > 0 then
      local okEntry, activeEntry = pcall(function()
        return node.activeEntry
      end)
      if not okEntry or IsSecretValue(activeEntry) then
        return false
      end
      active = type(activeEntry) == "table" and ReadPlainNumber(activeEntry, "entryID") == spot.entry
    end
    taken[spot.spellID] = taken[spot.spellID] == true or active
  end
  return true
end

--- Reads the talents of the member whose INSPECT_READY is being applied.
-- Returns true when a complete answer was stored.
function DefensiveTalents.CaptureInspect(guid)
  local manifest = Manifest()
  if not manifest or IsSecretValue(guid) or type(guid) ~= "string" then
    return false
  end
  if CallTraits("HasValidInspectData") ~= true then
    return false
  end
  local configID = InspectConfigID()
  local config = CallTraits("GetConfigInfo", configID)
  if type(config) ~= "table" then
    return false
  end
  local trees = ReadList(config, "treeIDs")
  if not trees or #trees == 0 then
    return false
  end
  local taken = {}
  for _, treeID in ipairs(trees) do
    if not ReadTree(configID, treeID, manifest, taken) then
      return false
    end
  end
  takenByGuid[guid] = taken
  return true
end

--- The taken talents of `unit` ({ [castID] = true|false }), or nil = unknown.
function DefensiveTalents.GetTalents(unit)
  local getGUID = rawget(_G, "UnitGUID")
  if type(getGUID) ~= "function" then
    return nil
  end
  local ok, guid = pcall(getGUID, unit)
  if not ok or IsSecretValue(guid) or type(guid) ~= "string" then
    return nil
  end
  return takenByGuid[guid]
end
