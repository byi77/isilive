local _, addonTable = ...

addonTable = addonTable or {}

local SeasonData = {}
addonTable.SeasonData = SeasonData

-- Configuration for Current Season (TWW Season 1)
-- Update these tables when a new season starts.

-- MapID -> Teleport SpellID
SeasonData.MAP_TO_TELEPORT = {
  [2660] = 445417, -- Ara-Kara, City of Echoes
  [2669] = 445416, -- City of Threads
  [2652] = 445269, -- The Stonevault
  [2662] = 445414, -- The Dawnbreaker
  [2290] = 354469, -- Mists of Tirna Scithe
  [2286] = 354464, -- The Necrotic Wake
  [2444] = 445424, -- Siege of Boralus
  [2651] = 445423, -- Grim Batol
}

-- MapID -> Short Code (displayed in roster Key column)
SeasonData.MAP_SHORT_CODES = {
  [2660] = "AK",
  [2669] = "COT",
  [2652] = "SV",
  [2662] = "DB",
  [2290] = "MISTS",
  [2286] = "NW",
  [2444] = "SOB",
  [2651] = "GB",
}
