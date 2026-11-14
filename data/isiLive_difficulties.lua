local _, addonTable = ...

addonTable = addonTable or {}

-- Central maintenance file for the Blizzard instance difficulty IDs and LFG
-- category IDs that isiLive classifies. Every consumer reads these tables;
-- no module keeps a literal copy (guarded by the usecase test "Difficulty
-- manifest owns every literal difficulty and LFG category ID").
--
-- Maintenance workflow after a WoW patch:
-- 1. Check https://warcraft.wiki.gg/wiki/DifficultyID and the patch API notes
--    for new or renumbered difficulties. Verify a new ID in the live client
--    (`/isilive seasondump` prints GetInstanceInfo's difficultyID). IDs are
--    never guessed.
-- 2. Add the ID to the matching set below.
-- 3. Run `lua tools/validate_usecases.lua`.
--
-- This file loads before core/isiLive_runtime_mode.lua (TOC order), because
-- the runtime profile reads it at load.
addonTable.DifficultyManifest = {
  -- Party (5-player) dungeon difficulties, from GetInstanceInfo().
  party = {
    normal = { 1 },
    heroic = { 2, 174 },
    -- Mythic without a running keystone: a real M0 run or a key dungeon before
    -- the keystone is inserted (the API cannot tell them apart).
    mythic = { 23 },
    -- Mythic Keystone: a key is inserted and running.
    mythicKeystone = { 8 },
    -- Timewalking is a reduced-profile dungeon, never mythic.
    timewalking = { 24 },
  },

  -- Raid difficulties -> localized label key.
  raidLabelKeys = {
    [14] = "DUNGEON_DIFF_RAID_NORMAL",
    [15] = "DUNGEON_DIFF_RAID_HEROIC",
    [16] = "DUNGEON_DIFF_RAID_MYTHIC",
    [17] = "DUNGEON_DIFF_RAID_LFR",
  },

  -- C_LFGList activity categoryID values.
  lfgCategory = {
    dungeons = 2,
    raids = 3,
  },
}

local Difficulties = {}
addonTable.Difficulties = Difficulties

local function BuildSet(list)
  local set = {}
  for _, id in ipairs(list or {}) do
    set[id] = true
  end
  return set
end

local party = addonTable.DifficultyManifest.party
local PARTY_SETS = {
  normal = BuildSet(party.normal),
  heroic = BuildSet(party.heroic),
  mythic = BuildSet(party.mythic),
  mythicKeystone = BuildSet(party.mythicKeystone),
  timewalking = BuildSet(party.timewalking),
}

--- True when `difficultyID` belongs to the named party difficulty group
-- (`normal`, `heroic`, `mythic`, `mythicKeystone`, `timewalking`).
function Difficulties.IsParty(group, difficultyID)
  local set = PARTY_SETS[group]
  return set ~= nil and difficultyID ~= nil and set[difficultyID] == true
end

--- Returns a fresh set copy of a party difficulty group, so callers cannot
-- mutate the manifest.
function Difficulties.GetPartySet(group)
  local copy = {}
  for id in pairs(PARTY_SETS[group] or {}) do
    copy[id] = true
  end
  return copy
end

--- Localized label key for a raid difficulty ID, or nil.
function Difficulties.GetRaidLabelKey(difficultyID)
  if difficultyID == nil then
    return nil
  end
  return addonTable.DifficultyManifest.raidLabelKeys[difficultyID]
end

--- LFG categoryID for `dungeons` or `raids`.
function Difficulties.GetLfgCategory(name)
  return addonTable.DifficultyManifest.lfgCategory[name]
end
