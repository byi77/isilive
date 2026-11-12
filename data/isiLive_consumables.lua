local _, addonTable = ...
addonTable = addonTable or {}

-- Consumable buffs per season for the ready-check consumable check
-- (rule 246, game/isiLive_consumable_check.lua): aura spell IDs of food,
-- flask and augment rune, keyed by SeasonData.GetActiveSeasonID().
--
-- IDs come from the live client only (CLAUDE.md): probe mode writes the
-- spell IDs of the own buffs on every ready check (`[PROBE] event=ready_check
-- ... spellIDs=...`). Never copy them from third-party addons or databases.
-- A category with an empty list is not checked; weapon oil needs no IDs
-- (GetWeaponEnchantInfo). Maintenance step in docs/SAISON_WECHSEL.md.
addonTable.ConsumableData = {
  seasons = {},
}
