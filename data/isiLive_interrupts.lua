local _, addonTable = ...

addonTable = addonTable or {}

-- Interrupt data per specialization for the kick tracker
-- (game/isiLive_kick_tracker.lua). One place per data type (AGENTS.md,
-- maintainability check; package 5 J): a patch that changes an interrupt spell
-- or cooldown is a data change here, never a code change. Cooldowns come from
-- the in-game spell tooltip (interrupt-audit skill), never from other addons.
-- tools/check_spec_coverage.lua verifies that every spec of
-- data/isiLive_specs.lua has a decision here (SPEC_DATA or
-- NO_INTERRUPT_SPEC_IDS), and `/isilive selftest` checks that every spell ID
-- still resolves in the client (rule 261).
local NO_INTERRUPT_SPEC_IDS = {
  [105] = true, -- Restoration Druid
  [256] = true, -- Discipline Priest
  [257] = true, -- Holy Priest
  [65] = true, -- Holy Paladin (no Rebuke)
  [270] = true, -- Mistweaver Monk (no Spear Hand Strike)
}

-- Spec-keyed interrupt data (spec ID → { spellID, cd }).
local SPEC_DATA = {
  -- Death Knight
  [250] = { spellID = 47528, cd = 15 }, -- Blood
  [251] = { spellID = 47528, cd = 15 }, -- Frost
  [252] = { spellID = 47528, cd = 15 }, -- Unholy
  -- Demon Hunter -- all three specs share the class baseline interrupt.
  -- Verified on a live client 2026-07-26: C_Spell.GetSpellName(183752) resolves
  -- on every spec, and the tooltip reads 15s on each. Spec 1480 was confirmed
  -- via GetSpecializationInfoByID as a Demon Hunter damage spec.
  --
  -- Naming trap for future audits: 183752 is Disrupt in English but reads
  -- "Unterbrechen" on a German client -- which is also the generic German word
  -- for "interrupt". Do not conclude from a spell NAME that a spec lacks this
  -- ability; resolve the ID via C_Spell.GetSpellName instead.
  [577] = { spellID = 183752, cd = 15 }, -- Havoc
  [581] = { spellID = 183752, cd = 15 }, -- Vengeance
  [1480] = { spellID = 183752, cd = 15 }, -- Devourer (Midnight third spec)
  -- Druid
  [102] = { spellID = 78675, cd = 45 }, -- Balance: Solar Beam (45s in Midnight)
  [103] = { spellID = 106839, cd = 15 }, -- Feral: Skull Bash
  [104] = { spellID = 106839, cd = 15 }, -- Guardian: Skull Bash
  [105] = nil, -- Restoration: no interrupt
  -- Evoker
  [1467] = { spellID = 351338, cd = 18 }, -- Devastation: Quell
  [1468] = { spellID = 351338, cd = 18 }, -- Preservation: Quell
  [1473] = { spellID = 351338, cd = 18 }, -- Augmentation: Quell
  -- Hunter
  [253] = { spellID = 147362, cd = 24 }, -- BM: Counter Shot
  [254] = { spellID = 147362, cd = 24 }, -- MM: Counter Shot
  [255] = { spellID = 187707, cd = 15 }, -- Survival: Muzzle
  -- Mage
  [62] = { spellID = 2139, cd = 25 }, -- Counterspell (25s base; talent 382297 reduces to 20)
  [63] = { spellID = 2139, cd = 25 },
  [64] = { spellID = 2139, cd = 25 },
  -- Monk
  [268] = { spellID = 116705, cd = 15 }, -- Brewmaster: Spear Hand Strike
  [269] = { spellID = 116705, cd = 15 }, -- Windwalker: Spear Hand Strike
  [270] = nil, -- Mistweaver: no interrupt
  -- Paladin
  [65] = nil, -- Holy: no Rebuke
  [66] = { spellID = 96231, cd = 15 }, -- Protection: Rebuke
  [70] = { spellID = 96231, cd = 15 }, -- Retribution: Rebuke
  -- Priest
  [256] = nil, -- Discipline
  [257] = nil, -- Holy
  [258] = { spellID = 15487, cd = 30 }, -- Shadow: Silence
  -- Rogue
  [259] = { spellID = 1766, cd = 15 },
  [260] = { spellID = 1766, cd = 15 },
  [261] = { spellID = 1766, cd = 15 },
  -- Shaman
  [262] = { spellID = 57994, cd = 12 },
  [263] = { spellID = 57994, cd = 12 },
  [264] = { spellID = 57994, cd = 30 }, -- Resto: 30s
  -- Warlock
  [265] = {
    castUnit = "pet",
    requireAvailability = true,
    spells = {
      { spellID = 19647, cd = 24 }, -- Spell Lock
    },
  },
  [266] = {
    castUnit = "pet",
    requireAvailability = true,
    spells = {
      { spellID = 119914, cd = 30, castSpellIDs = { 89766 } }, -- Axe Toss (player-facing ID; pet cast uses 89766)
      { spellID = 19647, cd = 24 }, -- Spell Lock (e.g. Fel Ravager path)
    },
  },
  [267] = {
    castUnit = "pet",
    requireAvailability = true,
    spells = {
      { spellID = 19647, cd = 24 }, -- Spell Lock
    },
  },
  -- Warrior
  [71] = { spellID = 6552, cd = 15 },
  [72] = { spellID = 6552, cd = 15 },
  [73] = { spellID = 6552, cd = 15 },
}

-- Class-level whitelist of all known interrupt spell IDs (across specs/talents).
-- Used by OnCast to detect a cast that is "an interrupt of my class but NOT
-- the registered primary slot" -- e.g. Demo Warlock with Inner Demons casts
-- both Spell Lock (Felhunter) and Axe Toss (Felguard) in the same key, or
-- Prot Paladin with the Avenger's Shield interrupt talent.
--
-- Classes with only one interrupt-spell across all specs are intentionally
-- not listed -- spec-switching for them is handled via RefreshSpec on
-- PLAYER_SPECIALIZATION_CHANGED, not through OnCast detection.
local CLASS_INTERRUPT_LIST = {
  WARLOCK = { 19647, 119914 }, -- Spell Lock + Axe Toss (player-facing)
  PALADIN = { 96231, 31935 }, -- Rebuke + Avenger's Shield (talent-as-interrupt)
}

-- CDs for spells that appear ONLY as extras (not as a spec's primary in
-- SPEC_DATA). Primary spells take their CD from SPEC_DATA, extras need this
-- because there's no spec-slot to read from.
local EXTRA_KICK_CD = {
  -- Verified in-game 2026-07-26 on a Protection Paladin with the interrupt
  -- talent active: the spell tooltip reads a flat 13s. Not haste-scaled --
  -- Rebuke read exactly 15s on the same character at 13.03% haste, so a fixed
  -- constant is the right model here.
  --
  -- Caveat: 13s is the value WITH that character's talent build. The
  -- Protection tree also carries cooldown reductions for this spell, and
  -- whether the reading already includes one cannot be separated without
  -- respeccing. Left unmodelled in CD_REDUCTION_DEFS rather than guessed --
  -- this constant only seeds the extras slot until the exact live cooldown
  -- lands (see ApplyExactActiveCooldownForExtra), and serves as the fallback
  -- when a Secret Value blocks that read.
  [31935] = 13, -- Avenger's Shield (Prot Paladin interrupt talent)
}

addonTable.InterruptManifest = {
  -- Spec ID -> true: the spec has no interrupt.
  noInterruptSpecs = NO_INTERRUPT_SPEC_IDS,
  -- Spec ID -> { spellID, cd } or a pet-cast record with `spells`.
  specs = SPEC_DATA,
  -- Class token -> every interrupt spell ID of the class (OnCast detection).
  classAlternatives = CLASS_INTERRUPT_LIST,
  -- Spell ID -> cooldown for interrupts that are only extras.
  extraCooldowns = EXTRA_KICK_CD,
}
