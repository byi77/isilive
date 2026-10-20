local _, addonTable = ...

addonTable = addonTable or {}

-- Central maintenance file for the group-utility spell IDs that several modules
-- match against: Battle Res casts, Bloodlust-class casts, the Sated-class
-- debuffs they leave behind, and Power Infusion.
--
-- Maintenance workflow after a WoW patch:
-- 1. Verify every new or changed ID against a reliable source (live client
--    C_Spell.GetSpellName / tooltip, warcraft.wiki.gg, Wowhead). IDs are never
--    guessed; an unverified candidate does not go in here.
-- 2. Add one record to the matching list. Consumers derive their lookup sets
--    from these lists, so no module keeps its own copy.
-- 3. Run `lua tools/validate_usecases.lua`.
--
-- Interrupt spells stay in game/isiLive_kick_tracker.lua: their cooldowns are
-- tooltip-audited per spec (see the interrupt-audit skill).
addonTable.SpellManifest = {
  -- Battle-Res spells a player can cast on a dead ally in combat. The order is
  -- the scan order CdTracker uses for the shared charge pool.
  battleRes = {
    { id = 20484, name = "Rebirth", class = "DRUID" },
    { id = 61999, name = "Raise Ally", class = "DEATHKNIGHT" },
    { id = 391054, name = "Intercession", class = "PALADIN" },
    { id = 20707, name = "Soulstone Resurrection", class = "WARLOCK" },
  },

  -- Bloodlust-class cast IDs. UNIT_SPELLCAST_SUCCEEDED fires once per completed
  -- cast, so only cast-triggering IDs belong here; the Sated debuffs never
  -- produce a cast event. `actionButton = true` marks the spells the Bloodlust
  -- button warning looks for on the player's action bars (drums are items, not
  -- class spells, and stay out of that scan).
  lustCasts = {
    { id = 2825, name = "Bloodlust", source = "Shaman", actionButton = true },
    { id = 32182, name = "Heroism", source = "Shaman", actionButton = true },
    { id = 80353, name = "Time Warp", source = "Mage", actionButton = true },
    { id = 264667, name = "Primal Rage", source = "Hunter Ferocity pet", actionButton = true },
    { id = 390386, name = "Fury of the Aspects", source = "Evoker", actionButton = true },
    { id = 466904, name = "Harrier's Cry", source = "Marksmanship Hunter", actionButton = true },
    { id = 381301, name = "Feral Hide Drums", source = "Drums" },
    { id = 178207, name = "Drums of Fury", source = "Drums" },
    { id = 230935, name = "Drums of the Mountain", source = "Drums" },
    { id = 256740, name = "Drums of the Maelstrom", source = "Drums" },
    { id = 292463, name = "Drums of Deathly Ferocity", source = "Drums" },
    { id = 90355, name = "Ancient Hysteria", source = "Core Hound pet", actionButton = true },
    { id = 160452, name = "Netherwinds", source = "Nether Ray pet", actionButton = true },
  },

  -- Sated / Exhaustion / Insanity / Temporal Displacement debuffs left behind by
  -- Bloodlust-class effects. Matched against the player's HARMFUL aura list, so
  -- only the debuff IDs belong here, never the cast IDs above.
  lustSated = {
    { id = 57723, name = "Exhaustion", source = "Bloodlust" },
    { id = 57724, name = "Sated", source = "Heroism" },
    { id = 80354, name = "Temporal Displacement", source = "Time Warp" },
    { id = 264689, name = "Fatigued", source = "Primal Rage" },
    -- Name confirmed on Wowhead (spell=390435) on 2026-10-20; the applying
    -- spell is not stated there. Former comments disagreed ("Ancient Hysteria"
    -- vs. none), so the source stays unrecorded until a reliable one exists.
    { id = 390435, name = "Exhaustion", source = nil },
    { id = 95809, name = "Insanity", source = "pet variants" },
  },

  -- Spells whose icons stand for the CD-tracker row in the roster panel.
  icons = {
    battleRes = 20484, -- Rebirth
    lust = 2825, -- Bloodlust
  },

  -- Power Infusion (Priest): tracked on the player's auras and synced to peers.
  powerInfusion = 10060,
}

-- Lookup helpers shared by every consumer. Kept next to the data so the TOC
-- order (data before game/) is the only load requirement.
local Spells = {}
addonTable.Spells = Spells

-- Returns { [id] = true } for every record in `list` that passes `filter`.
function Spells.BuildIDSet(list, filter)
  local out = {}
  for _, record in ipairs(type(list) == "table" and list or {}) do
    if type(record) == "table" and type(record.id) == "number" and (filter == nil or filter(record)) then
      out[record.id] = true
    end
  end
  return out
end

-- Returns the IDs of `list` as an array, preserving the manifest order.
function Spells.BuildIDList(list)
  local out = {}
  for _, record in ipairs(type(list) == "table" and list or {}) do
    if type(record) == "table" and type(record.id) == "number" then
      out[#out + 1] = record.id
    end
  end
  return out
end

function Spells.IsActionButtonLust(record)
  return record.actionButton == true
end
