local _, addonTable = ...

addonTable = addonTable or {}

local SeasonData = {}
addonTable.SeasonData = SeasonData

-- Configuration for Current Season (TWW Season 3)
-- Update these tables when a new season starts.

-- MapID -> Teleport SpellID
SeasonData.MAP_TO_TELEPORT = {
  [2649] = 445444, -- Priory of the Sacred Flame
  [2830] = 1237215, -- Eco-Dome Al'dani
  [2287] = 354465, -- Halls of Atonement
  [2773] = 1216786, -- Operation: Floodgate
  [2660] = 445417, -- Ara-Kara, City of Echoes
  [2441] = 367416, -- Tazavesh: Streets of Wonder / So'leah's Gambit
  [2662] = 445414, -- The Dawnbreaker
}

-- MapID -> Short Code (displayed in roster Key column)
SeasonData.MAP_SHORT_CODES = {
  [2649] = "PSF",
  [2830] = "EDA",
  [2287] = "HOA",
  [2773] = "OFG",
  [2660] = "AK",
  [2441] = "TAZ",
  [2662] = "DB",
}
