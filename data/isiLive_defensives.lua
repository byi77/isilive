local _, addonTable = ...

addonTable = addonTable or {}

-- Central maintenance file for the group defensive / external cooldown tracker
-- (vorhaben V1, rule 267) and the aura container probe (rule 239).
--
-- One record per tracked spell, in the probe's scan order:
--   cast      spell ID of the cast (UNIT_SPELLCAST_SUCCEEDED, C_Spell cooldown
--             reads, DEF sync wire ID)
--   aura      buff ID the spell leaves on its target (aura reads, sensors)
--   name      English spell name (maintenance label only, never displayed)
--   kind      "external" (cast on another player), "raid" (damage reduction
--             for the group) or "personal"
--   class     class token
--   specs     spec IDs from data/isiLive_specs.lua when the client data
--             restricts the spell to these specs; nil = any spec of the class
--             may know it (class talent or baseline). The runtime never trusts
--             this field for the own player: it asks the client whether the
--             spell is known.
--   talent    true when DB2 TraitDefinition lists the spell (same build):
--             the estimate needs the member's inspected talents for it
--   cooldown  base cooldown in seconds from Blizzard's client tables (DB2) of
--             build 12.1.5.70961 (wago.tools CSV export, read 2026-11-21):
--             SpellCategory.ChargeRecoveryTime of the spell's ChargeCategory
--             when it has one, otherwise the larger of
--             SpellCooldowns.RecoveryTime and CategoryRecoveryTime
--             (DifficultyID 0). Talent reductions are not modelled. nil = no
--             verified value. Values from other addons or third-party
--             databases are not allowed (rule 264 applies the same way).
--   probe     true for the IDs the aura container probe filters on (the list
--             the user supplied on 2026-11-21); the probe keeps exactly these.
--
-- Spec restrictions come from DB2 SpecializationSpells and from talent nodes
-- whose visibility condition names only these specs (TraitNodeGroupXTraitCond
-- -> TraitCond.SpecSetID -> SpecSetMember), same build.
--
-- Maintenance after a class patch (docs/SAISON_WECHSEL.md): run
-- tools/check_db2.lua against the new build; it reports every cast or aura ID
-- the client no longer has and every cooldown that no longer matches DB2.
local DEFENSIVE_LIST = {
  -- Externals.
  {
    cast = 33206,
    aura = 33206,
    name = "Pain Suppression",
    kind = "external",
    class = "PRIEST",
    talent = true,
    specs = { 256 },
    cooldown = 180,
    probe = true,
  },
  {
    cast = 47788,
    aura = 47788,
    name = "Guardian Spirit",
    kind = "external",
    class = "PRIEST",
    talent = true,
    specs = { 257 },
    cooldown = 180,
    probe = true,
  },
  {
    cast = 102342,
    aura = 102342,
    name = "Ironbark",
    kind = "external",
    class = "DRUID",
    talent = true,
    specs = { 105 },
    cooldown = 90,
    probe = true,
  },
  {
    cast = 116849,
    aura = 116849,
    name = "Life Cocoon",
    kind = "external",
    class = "MONK",
    talent = true,
    specs = { 270 },
    cooldown = 120,
    probe = true,
  },
  {
    cast = 6940,
    aura = 6940,
    name = "Blessing of Sacrifice",
    kind = "external",
    class = "PALADIN",
    talent = true,
    cooldown = 120,
    probe = true,
  },
  {
    cast = 1022,
    aura = 1022,
    name = "Blessing of Protection",
    kind = "external",
    class = "PALADIN",
    talent = true,
    cooldown = 300,
    probe = true,
  },
  {
    cast = 357170,
    aura = 357170,
    name = "Time Dilation",
    kind = "external",
    class = "EVOKER",
    talent = true,
    specs = { 1468 },
    cooldown = 60,
    probe = true,
  },
  -- Damage-reducing group cooldowns.
  {
    cast = 51052,
    aura = 145629,
    name = "Anti-Magic Zone",
    kind = "raid",
    class = "DEATHKNIGHT",
    talent = true,
    cooldown = 240,
    probe = true,
  },
  {
    cast = 196718,
    aura = 209426,
    name = "Darkness",
    kind = "raid",
    class = "DEMONHUNTER",
    talent = true,
    cooldown = 300,
    probe = true,
  },
  {
    cast = 97462,
    aura = 97463,
    name = "Rallying Cry",
    kind = "raid",
    class = "WARRIOR",
    talent = true,
    cooldown = 180,
    probe = true,
  },
  {
    cast = 98008,
    aura = 325174,
    name = "Spirit Link Totem",
    kind = "raid",
    class = "SHAMAN",
    talent = true,
    specs = { 264 },
    cooldown = 180,
    probe = true,
  },
  {
    cast = 62618,
    aura = 81782,
    name = "Power Word: Barrier",
    kind = "raid",
    class = "PRIEST",
    talent = true,
    specs = { 256 },
    cooldown = 180,
    probe = true,
  },
  {
    cast = 31821,
    aura = 31821,
    name = "Aura Mastery",
    kind = "raid",
    class = "PALADIN",
    talent = true,
    specs = { 65 },
    cooldown = 180,
    probe = true,
  },
  -- Personal defensives.
  {
    cast = 48792,
    aura = 48792,
    name = "Icebound Fortitude",
    kind = "personal",
    class = "DEATHKNIGHT",
    talent = true,
    cooldown = 120,
    probe = true,
  },
  {
    cast = 48707,
    aura = 48707,
    name = "Anti-Magic Shell",
    kind = "personal",
    class = "DEATHKNIGHT",
    talent = true,
    cooldown = 60,
    probe = true,
  },
  {
    cast = 198589,
    aura = 212800,
    name = "Blur",
    kind = "personal",
    class = "DEMONHUNTER",
    specs = { 577, 1480 },
    cooldown = 60,
    probe = true,
  },
  {
    cast = 22812,
    aura = 22812,
    name = "Barkskin",
    kind = "personal",
    class = "DRUID",
    cooldown = 60,
    probe = true,
  },
  {
    cast = 61336,
    aura = 61336,
    name = "Survival Instincts",
    kind = "personal",
    class = "DRUID",
    talent = true,
    specs = { 103, 104 },
    cooldown = 180,
    probe = true,
  },
  {
    cast = 363916,
    aura = 363916,
    name = "Obsidian Scales",
    kind = "personal",
    class = "EVOKER",
    talent = true,
    cooldown = 90,
    probe = true,
  },
  {
    cast = 186265,
    aura = 186265,
    name = "Aspect of the Turtle",
    kind = "personal",
    class = "HUNTER",
    cooldown = 180,
    probe = true,
  },
  {
    cast = 45438,
    aura = 45438,
    name = "Ice Block",
    kind = "personal",
    class = "MAGE",
    talent = true,
    cooldown = 240,
    probe = true,
  },
  {
    cast = 115203,
    aura = 120954,
    name = "Fortifying Brew",
    kind = "personal",
    class = "MONK",
    cooldown = 360,
    probe = true,
  },
  {
    cast = 642,
    aura = 642,
    name = "Divine Shield",
    kind = "personal",
    class = "PALADIN",
    cooldown = 300,
    probe = true,
  },
  {
    cast = 498,
    aura = 498,
    name = "Divine Protection",
    kind = "personal",
    class = "PALADIN",
    specs = { 65 },
    cooldown = 60,
    probe = true,
  },
  {
    cast = 31850,
    aura = 31850,
    name = "Ardent Defender",
    kind = "personal",
    class = "PALADIN",
    talent = true,
    specs = { 66 },
    cooldown = 90,
    probe = true,
  },
  {
    cast = 86659,
    aura = 86659,
    name = "Guardian of Ancient Kings",
    kind = "personal",
    class = "PALADIN",
    talent = true,
    specs = { 66 },
    cooldown = 180,
    probe = true,
  },
  {
    cast = 47585,
    aura = 47585,
    name = "Dispersion",
    kind = "personal",
    class = "PRIEST",
    specs = { 258 },
    cooldown = 120,
    probe = true,
  },
  {
    cast = 19236,
    aura = 19236,
    name = "Desperate Prayer",
    kind = "personal",
    class = "PRIEST",
    talent = true,
    cooldown = 90,
    probe = true,
  },
  {
    cast = 31224,
    aura = 31224,
    name = "Cloak of Shadows",
    kind = "personal",
    class = "ROGUE",
    talent = true,
    cooldown = 120,
    probe = true,
  },
  {
    cast = 5277,
    aura = 5277,
    name = "Evasion",
    kind = "personal",
    class = "ROGUE",
    talent = true,
    cooldown = 120,
    probe = true,
  },
  {
    cast = 1966,
    aura = 1966,
    name = "Feint",
    kind = "personal",
    class = "ROGUE",
    cooldown = 15,
    probe = true,
  },
  {
    cast = 108271,
    aura = 108271,
    name = "Astral Shift",
    kind = "personal",
    class = "SHAMAN",
    talent = true,
    cooldown = 120,
    probe = true,
  },
  {
    cast = 104773,
    aura = 104773,
    name = "Unending Resolve",
    kind = "personal",
    class = "WARLOCK",
    cooldown = 180,
    probe = true,
  },
  {
    cast = 871,
    aura = 871,
    name = "Shield Wall",
    kind = "personal",
    class = "WARRIOR",
    talent = true,
    specs = { 73 },
    cooldown = 180,
    probe = true,
  },
  {
    cast = 12975,
    aura = 12975,
    name = "Last Stand",
    kind = "personal",
    class = "WARRIOR",
    talent = true,
    specs = { 73 },
    cooldown = 180,
    probe = true,
  },
  {
    cast = 118038,
    aura = 118038,
    name = "Die by the Sword",
    kind = "personal",
    class = "WARRIOR",
    talent = true,
    specs = { 71 },
    cooldown = 120,
    probe = true,
  },
  {
    cast = 184364,
    aura = 184364,
    name = "Enraged Regeneration",
    kind = "personal",
    class = "WARRIOR",
    talent = true,
    specs = { 72 },
    cooldown = 120,
    probe = true,
  },
  -- Personal defensives of tank specs the probe list did not cover.
  {
    cast = 55233,
    aura = 55233,
    name = "Vampiric Blood",
    kind = "personal",
    class = "DEATHKNIGHT",
    talent = true,
    specs = { 250 },
    cooldown = 90,
  },
  {
    cast = 187827,
    aura = 187827,
    name = "Metamorphosis",
    kind = "personal",
    class = "DEMONHUNTER",
    specs = { 581 },
    cooldown = 120,
  },
  {
    cast = 264735,
    aura = 264735,
    name = "Survival of the Fittest",
    kind = "personal",
    class = "HUNTER",
    talent = true,
    cooldown = 90,
  },
}

-- Display and sort order of the kinds: externals first, then group cooldowns,
-- then personal defensives.
local KIND_ORDER = { external = 1, raid = 2, personal = 3 }

local spells = {}
for _, record in ipairs(DEFENSIVE_LIST) do
  spells[record.cast] = {
    aura = record.aura,
    name = record.name,
    kind = record.kind,
    class = record.class,
    specs = record.specs,
    talent = record.talent,
    cooldown = record.cooldown,
  }
end

addonTable.DefensiveManifest = {
  -- Ordered records (probe scan order, maintenance view).
  list = DEFENSIVE_LIST,
  -- spells[castID] = { aura, name, kind, class, specs, cooldown }
  spells = spells,
  kindOrder = KIND_ORDER,
  -- Forbearance (debuff after the Paladin immunities): probe secrecy check
  -- only (rule 239).
  forbearance = 25771,
}
