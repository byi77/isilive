local _, addonTable = ...

addonTable = addonTable or {}

-- Central maintenance file for per-specialization data shared by several
-- modules. Spec IDs per warcraft.wiki.gg/wiki/SpecializationID.
--
-- Maintenance workflow when a patch adds or changes a specialization:
-- 1. Add one record here with every required field (`class`, `name` and all
--    four `lfg` flags as explicit booleans). Unknown values are not guessed;
--    resolve them from a reliable source first.
-- 2. Give the spec an interrupt entry in game/isiLive_kick_tracker.lua
--    (SPEC_DATA or NO_INTERRUPT_SPEC_IDS); its cooldown comes from the in-game
--    tooltip (interrupt-audit skill).
-- 3. Run `lua tools/check_spec_coverage.lua` and `lua tools/validate_usecases.lua`.
--
-- Fields:
-- - `class`: class token. `name`: English spec name (maintenance label only).
-- - `shortLabel`: roster spec label (max 5 chars) for clients without a
--   hand-maintained name mapping in game/isiLive_units.lua (everything except
--   deDE/enUS).
-- - `lfg`: the LFG group-bonus profile (ui/isiLive_lfg_bonus_model.lua): which
--   group buffs count as relevant for this spec. Taken over unchanged from the
--   former per-module lists on 2026-10-20, overlaps included (Frost/Unholy Death
--   Knights count as attack-power users and magic-damage dealers).
-- - `primaryStat`: the stats box row (ui/isiLive_stats_box.lua). Only set where
--   the spec overrides its class default; classes with one primary stat use the
--   class table in the stats box.
addonTable.SpecManifest = {
  specs = {
    -- Death Knight
    [250] = {
      class = "DEATHKNIGHT",
      name = "Blood",
      shortLabel = "Blood",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    [251] = {
      class = "DEATHKNIGHT",
      name = "Frost",
      shortLabel = "Frost",
      lfg = { intellect = false, attackPower = true, magicDamage = true, physicalDamage = false },
    },
    [252] = {
      class = "DEATHKNIGHT",
      name = "Unholy",
      shortLabel = "UH",
      lfg = { intellect = false, attackPower = true, magicDamage = true, physicalDamage = false },
    },
    -- Demon Hunter
    [577] = {
      class = "DEMONHUNTER",
      name = "Havoc",
      shortLabel = "Havoc",
      primaryStat = "agility",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    [581] = {
      class = "DEMONHUNTER",
      name = "Vengeance",
      shortLabel = "Venge",
      primaryStat = "agility",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    [1480] = {
      class = "DEMONHUNTER",
      name = "Devourer",
      shortLabel = "Devou",
      primaryStat = "intellect",
      lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false },
    },
    -- Druid
    [102] = {
      class = "DRUID",
      name = "Balance",
      shortLabel = "Boomy",
      primaryStat = "intellect",
      lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false },
    },
    [103] = {
      class = "DRUID",
      name = "Feral",
      shortLabel = "Feral",
      primaryStat = "agility",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    [104] = {
      class = "DRUID",
      name = "Guardian",
      shortLabel = "Guard",
      primaryStat = "agility",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    [105] = {
      class = "DRUID",
      name = "Restoration",
      shortLabel = "Resto",
      primaryStat = "intellect",
      lfg = { intellect = true, attackPower = false, magicDamage = false, physicalDamage = false },
    },
    -- Evoker
    [1467] = {
      class = "EVOKER",
      name = "Devastation",
      shortLabel = "Devas",
      lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false },
    },
    [1468] = {
      class = "EVOKER",
      name = "Preservation",
      shortLabel = "Pres",
      lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false },
    },
    [1473] = {
      class = "EVOKER",
      name = "Augmentation",
      shortLabel = "Aug",
      lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false },
    },
    -- Hunter
    [253] = {
      class = "HUNTER",
      name = "Beast Mastery",
      shortLabel = "BM",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    [254] = {
      class = "HUNTER",
      name = "Marksmanship",
      shortLabel = "MM",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    [255] = {
      class = "HUNTER",
      name = "Survival",
      shortLabel = "Surv",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    -- Mage
    [62] = {
      class = "MAGE",
      name = "Arcane",
      shortLabel = "Arc",
      lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false },
    },
    [63] = {
      class = "MAGE",
      name = "Fire",
      shortLabel = "Fire",
      lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false },
    },
    [64] = {
      class = "MAGE",
      name = "Frost",
      shortLabel = "Frost",
      lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false },
    },
    -- Monk
    [268] = {
      class = "MONK",
      name = "Brewmaster",
      shortLabel = "Brew",
      primaryStat = "agility",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    [269] = {
      class = "MONK",
      name = "Windwalker",
      shortLabel = "WW",
      primaryStat = "agility",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    [270] = {
      class = "MONK",
      name = "Mistweaver",
      shortLabel = "MW",
      primaryStat = "intellect",
      lfg = { intellect = true, attackPower = false, magicDamage = false, physicalDamage = false },
    },
    -- Paladin
    [65] = {
      class = "PALADIN",
      name = "Holy",
      shortLabel = "Holy",
      primaryStat = "intellect",
      lfg = { intellect = true, attackPower = false, magicDamage = false, physicalDamage = false },
    },
    [66] = {
      class = "PALADIN",
      name = "Protection",
      shortLabel = "Prot",
      primaryStat = "strength",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    [70] = {
      class = "PALADIN",
      name = "Retribution",
      shortLabel = "Retri",
      primaryStat = "strength",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    -- Priest
    [256] = {
      class = "PRIEST",
      name = "Discipline",
      shortLabel = "Disci",
      lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false },
    },
    [257] = {
      class = "PRIEST",
      name = "Holy",
      shortLabel = "Holy",
      lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false },
    },
    [258] = {
      class = "PRIEST",
      name = "Shadow",
      shortLabel = "Shado",
      lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false },
    },
    -- Rogue
    [259] = {
      class = "ROGUE",
      name = "Assassination",
      shortLabel = "Assas",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    [260] = {
      class = "ROGUE",
      name = "Outlaw",
      shortLabel = "Outl",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    [261] = {
      class = "ROGUE",
      name = "Subtlety",
      shortLabel = "Sub",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    -- Shaman
    [262] = {
      class = "SHAMAN",
      name = "Elemental",
      shortLabel = "Ele",
      primaryStat = "intellect",
      lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false },
    },
    [263] = {
      class = "SHAMAN",
      name = "Enhancement",
      shortLabel = "EH",
      primaryStat = "agility",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    [264] = {
      class = "SHAMAN",
      name = "Restoration",
      shortLabel = "Resto",
      primaryStat = "intellect",
      lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false },
    },
    -- Warlock
    [265] = {
      class = "WARLOCK",
      name = "Affliction",
      shortLabel = "Affli",
      lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false },
    },
    [266] = {
      class = "WARLOCK",
      name = "Demonology",
      shortLabel = "Demon",
      lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false },
    },
    [267] = {
      class = "WARLOCK",
      name = "Destruction",
      shortLabel = "Destr",
      lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false },
    },
    -- Warrior
    [71] = {
      class = "WARRIOR",
      name = "Arms",
      shortLabel = "Arms",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    [72] = {
      class = "WARRIOR",
      name = "Fury",
      shortLabel = "Fury",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
    [73] = {
      class = "WARRIOR",
      name = "Protection",
      shortLabel = "Prot",
      lfg = { intellect = false, attackPower = true, magicDamage = false, physicalDamage = true },
    },
  },
}

local Specs = {}
addonTable.Specs = Specs

-- Returns { [specID] = true } for every spec whose `lfg[flag]` is true.
function Specs.BuildLfgFlagSet(flag)
  local out = {}
  for specID, spec in pairs(addonTable.SpecManifest.specs) do
    if type(spec.lfg) == "table" and spec.lfg[flag] == true then
      out[specID] = true
    end
  end
  return out
end

-- Returns { [specID] = shortLabel } for every spec.
function Specs.BuildShortLabels()
  local out = {}
  for specID, spec in pairs(addonTable.SpecManifest.specs) do
    out[specID] = spec.shortLabel
  end
  return out
end

-- Returns { [specID] = primaryStat } for the specs that override their class.
function Specs.BuildPrimaryStatOverrides()
  local out = {}
  for specID, spec in pairs(addonTable.SpecManifest.specs) do
    if type(spec.primaryStat) == "string" then
      out[specID] = spec.primaryStat
    end
  end
  return out
end

function Specs.GetClassToken(specID)
  local spec = addonTable.SpecManifest.specs[specID]
  return type(spec) == "table" and spec.class or nil
end
