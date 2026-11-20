local _, addonTable = ...

addonTable = addonTable or {}

-- Blizzard item IDs isiLive reads at runtime. One place per data type
-- (AGENTS.md, maintainability check); `/isilive selftest` checks that each ID
-- still resolves in the client (rule 261).
addonTable.ItemManifest = {
  -- Mythic Keystone. Unchanged since Shadowlands; a new expansion may ship a
  -- new keystone item, which the patch-watch self test then reports.
  mythicKeystone = 180653,
}
