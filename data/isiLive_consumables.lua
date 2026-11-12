local _, addonTable = ...
addonTable = addonTable or {}

-- Consumable buffs for the ready-check consumable check (rule 246,
-- game/isiLive_consumable_check.lua): aura spell IDs of food, flask and
-- augment rune. A category with an empty or missing list is not checked;
-- weapon oil needs no IDs (GetWeaponEnchantInfo).
--
-- Consumables belong to the expansion, not to the season, so the lists live
-- in one set per expansion (`sets`). A season finds its set by name:
-- "midnight_s1", "midnight_s2", ... -> "midnight" (the part before the
-- trailing "_s<number>"), so a new season of the same expansion needs no
-- entry here. `seasonSets` overrides that for a season whose ID does not
-- follow the pattern. A new expansion needs a new set; the test
-- "Consumable check finds a buff set for every season of the manifest" fails
-- until it exists.
--
-- Each list holds the buff the player carries, not the item: the regular
-- and the fleeting flask of a stat share one buff. Food is different: every
-- dish has a buff ID of its own, all named "Well Fed" or "Hearty Well Fed",
-- so the food list only names reference buffs for that name (name match:
-- still to be built). `disabled` switches a category off without dropping
-- its data. Check the IDs in the live client after a patch: probe mode
-- writes the spell IDs of the own buffs on every ready check
-- (`[PROBE] event=ready_check ... spellIDs=...`). Maintenance step in
-- docs/SAISON_WECHSEL.md.
local ConsumableData = {
  sets = {
    midnight = {
      -- Name references only (see above); the dish buffs differ per dish.
      food = {
        1232491, -- Well Fed
        1233724, -- Hearty Well Fed
      },
      flask = {
        1235108, -- Flask of the Magisters (mastery)
        1235110, -- Flask of the Blood Knights (haste)
        1235111, -- Flask of the Shattered Sun (critical strike)
        1235057, -- Flask of Thalassian Resistance (versatility)
        1250533, -- Freightrunner's Flask
      },
      augmentRune = {
        1264426, -- Void-Touched Augment Rune
        1295329, -- Tidesworn Augment Rune
      },
      -- User decision 2026-11-12: food (needs the name match) and rune stay
      -- off until they are confirmed in the live client.
      disabled = { food = true, augmentRune = true },
    },
  },
  -- seasonID -> set name, only for seasons whose ID does not name the set.
  seasonSets = {},
}

--- Buff set of a season, or nil.
function ConsumableData.ResolveSet(seasonID)
  if type(seasonID) ~= "string" or seasonID == "" then
    return nil
  end
  local setName = ConsumableData.seasonSets[seasonID] or seasonID:match("^(.-)_s%d+$") or seasonID
  return ConsumableData.sets[setName]
end

addonTable.ConsumableData = ConsumableData
