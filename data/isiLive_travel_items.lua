local _, addonTable = ...

addonTable = addonTable or {}

-- Central maintenance file for the travel items behind the ESC travel and mount
-- strips: the hearthstone toy pool, the fixed travel items and the mount spells.
-- None of this is seasonal; new entries arrive with patches, events or the shop.
--
-- Maintenance workflow for a new hearthstone toy (or any other entry):
-- 1. Collect the ID in docs/TRAVEL_INTAKE.md first; IDs are never guessed.
-- 2. Add one record here with `verification.status = "verified"`, a `source`
--    and a `verifiedAt` date (YYYY-MM-DD). The intake row and the record must
--    carry the same ID; tools/check_travel_items.lua enforces both.
-- 3. Conditional toys declare `requires` instead of custom code:
--    `{ covenantID = n, renownCriteria = n }` (either condition unlocks) or
--    `{ raceIDs = { ... } }`. The evaluator lives in ui/isiLive_ui_game_menu_travel.lua.
-- 4. Run `lua tools/check_travel_items.lua` and `lua tools/validate_usecases.lua`.
--
-- `legacy` marks entries that predate this file (2026-10-20). Their IDs have
-- shipped for many releases, but no source was recorded; they are not
-- re-sourced after the fact. Every new entry must be `verified`.
local LEGACY = {
  status = "legacy",
  source = "pre-2026-10-20 in-code list, provenance not recorded",
}

addonTable.TravelItemManifest = {
  -- Achievement whose criteria 1-4 track the covenant renown unlocks that make
  -- the covenant hearthstones usable outside the active covenant. The criteria
  -- index per covenant is taken over unchanged from the former in-code checks.
  covenantRenownAchievementID = 15646,

  -- Standard Hearthstone item; fallback when no toy is owned or selected.
  defaultHearthstoneItemID = 6948,
  defaultHearthstoneVerification = LEGACY,

  -- Dalaran Hearthstone toy behind its own travel button, not a pool member.
  dalaranHearthstoneToyID = 140192,
  dalaranHearthstoneVerification = LEGACY,

  -- Personal Key to the Arcantina, used through `/use item:<id>`. The English
  -- item name is "Arcantina"; the former English macro text "Arkantine" did
  -- not match it.
  arcantinaKeyItemID = 253629,
  arcantinaKeyVerification = {
    status = "verified",
    source = "warcraft.wiki.gg Personal_Key_to_the_Arcantina; wowhead item=253629",
    verifiedAt = "2026-10-20",
    -- Needs in-game confirmation that `/use item:253629` uses the key on every client locale.
  },

  -- Pool for the "random owned hearthstone" choice and the settings selector.
  hearthstoneToys = {
    { id = 54452, englishName = "Ethereal Portal", verification = LEGACY },
    { id = 64488, englishName = "The Innkeeper's Daughter", verification = LEGACY },
    { id = 93672, englishName = "Dark Portal", verification = LEGACY },
    { id = 142542, englishName = "Tome of Town Portal", verification = LEGACY },
    { id = 162973, englishName = "Greatfather Winter's Hearthstone", verification = LEGACY },
    { id = 163045, englishName = "Headless Horseman's Hearthstone", verification = LEGACY },
    { id = 163206, englishName = "Weary Spirit Binding", verification = LEGACY },
    { id = 165669, englishName = "Lunar Elder's Hearthstone", verification = LEGACY },
    { id = 165670, englishName = "Peddlefeet's Lovely Hearthstone", verification = LEGACY },
    { id = 165802, englishName = "Noble Gardener's Hearthstone", verification = LEGACY },
    { id = 166746, englishName = "Fire Eater's Hearthstone", verification = LEGACY },
    { id = 166747, englishName = "Brewfest Reveler's Hearthstone", verification = LEGACY },
    { id = 168907, englishName = "Holographic Digitalization Hearthstone", verification = LEGACY },
    { id = 172179, englishName = "Eternal Traveler's Hearthstone", verification = LEGACY },
    {
      id = 180290,
      englishName = "Night Fae Hearthstone",
      requires = { covenantID = 3, renownCriteria = 3 },
      verification = LEGACY,
    },
    {
      id = 182773,
      englishName = "Necrolord Hearthstone",
      requires = { covenantID = 4, renownCriteria = 2 },
      verification = LEGACY,
    },
    {
      id = 183716,
      englishName = "Venthyr Sinstone",
      requires = { covenantID = 2, renownCriteria = 4 },
      verification = LEGACY,
    },
    {
      id = 184353,
      englishName = "Kyrian Hearthstone",
      requires = { covenantID = 1, renownCriteria = 1 },
      verification = LEGACY,
    },
    { id = 188952, englishName = "Dominated Hearthstone", verification = LEGACY },
    { id = 190196, englishName = "Enlightened Hearthstone", verification = LEGACY },
    { id = 190237, englishName = "Broker Translocation Matrix", verification = LEGACY },
    { id = 193588, englishName = "Timewalker's Hearthstone", verification = LEGACY },
    { id = 200630, englishName = "Ohn'ir Windsage's Hearthstone", verification = LEGACY },
    { id = 206195, englishName = "Path of the Naaru", verification = LEGACY },
    { id = 208704, englishName = "Deepdweller's Earthen Hearthstone", verification = LEGACY },
    { id = 209035, englishName = "Hearthstone of the Flame", verification = LEGACY },
    -- Race IDs 11 (Draenei) and 30 (Lightforged Draenei).
    { id = 210455, englishName = "Draenic Hologem", requires = { raceIDs = { 11, 30 } }, verification = LEGACY },
    { id = 212337, englishName = "Stone of the Hearth", verification = LEGACY },
    { id = 228940, englishName = "Notorious Thread's Hearthstone", verification = LEGACY },
    { id = 235016, englishName = "Redeployment Module", verification = LEGACY },
    { id = 236687, englishName = "Explosive Hearthstone", verification = LEGACY },
    { id = 245970, englishName = "P.O.S.T. Master's Express Hearthstone", verification = LEGACY },
    { id = 246565, englishName = "Cosmic Hearthstone", verification = LEGACY },
    { id = 257736, englishName = "Lightcalled Hearthstone", verification = LEGACY },
    { id = 263489, englishName = "Naaru's Enfold", verification = LEGACY },
    { id = 263933, englishName = "Preyseeker's Hearthstone", verification = LEGACY },
    { id = 265100, englishName = "Corewarden's Hearthstone", verification = LEGACY },
  },

  -- Spells behind the ESC mount strip.
  mountSpells = {
    randomFavorite = { spellID = 150544, verification = LEGACY },
    auctionHouse = { spellID = 465235, verification = LEGACY },
    repair = { spellID = 122708, verification = LEGACY },
  },
}
