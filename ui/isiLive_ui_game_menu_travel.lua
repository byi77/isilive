local _, addonTable = ...

addonTable = addonTable or {}
addonTable.UI = addonTable.UI or {}

local Travel = {}
addonTable.UIGameMenuTravel = Travel
local IsSecretValue = addonTable.Validators.IsSecretValue

local covenantRenownCriteria = nil
local function HasCompletedCovenantRenownCriteria(criteriaIndex)
  criteriaIndex = tonumber(criteriaIndex)
  if not criteriaIndex then
    return false
  end
  if covenantRenownCriteria == nil then
    covenantRenownCriteria = {}
    local getCriteriaInfo = rawget(_G, "GetAchievementCriteriaInfo")
    if type(getCriteriaInfo) == "function" then
      for index = 1, 4 do
        local ok, _, _, completed = pcall(getCriteriaInfo, 15646, index)
        covenantRenownCriteria[index] = ok and completed == true or false
      end
    end
  end
  return covenantRenownCriteria[criteriaIndex] == true
end

local function HasActiveCovenant(covenantID)
  local covenantsApi = rawget(_G, "C_Covenants")
  if type(covenantsApi) ~= "table" or type(covenantsApi.GetActiveCovenantID) ~= "function" then
    return false
  end
  local ok, activeID = pcall(covenantsApi.GetActiveCovenantID)
  return ok and activeID == covenantID
end

local function PlayerRaceIDIs(...)
  if not addonTable.Validators.IsExistingUnit("player") then
    return false
  end
  local unitRace = rawget(_G, "UnitRace")
  if type(unitRace) ~= "function" then
    return false
  end
  local ok, _, _, raceID = pcall(unitRace, "player")
  if not ok or IsSecretValue(raceID) then
    return false
  end
  for index = 1, select("#", ...) do
    if raceID == select(index, ...) then
      return true
    end
  end
  return false
end

local function IsNightFaeHearthstoneUsable()
  return HasCompletedCovenantRenownCriteria(3) or HasActiveCovenant(3)
end

local function IsNecrolordHearthstoneUsable()
  return HasCompletedCovenantRenownCriteria(2) or HasActiveCovenant(4)
end

local function IsVenthyrHearthstoneUsable()
  return HasCompletedCovenantRenownCriteria(4) or HasActiveCovenant(2)
end

local function IsKyrianHearthstoneUsable()
  return HasCompletedCovenantRenownCriteria(1) or HasActiveCovenant(1)
end

local function IsDraenicHologemUsable()
  return PlayerRaceIDIs(11, 30)
end

local HEARTHSTONE_TOYS = {
  { id = 54452, englishName = "Ethereal Portal" },
  { id = 64488, englishName = "The Innkeeper's Daughter" },
  { id = 93672, englishName = "Dark Portal" },
  { id = 142542, englishName = "Tome of Town Portal" },
  { id = 162973, englishName = "Greatfather Winter's Hearthstone" },
  { id = 163045, englishName = "Headless Horseman's Hearthstone" },
  { id = 163206, englishName = "Weary Spirit Binding" },
  { id = 165669, englishName = "Lunar Elder's Hearthstone" },
  { id = 165670, englishName = "Peddlefeet's Lovely Hearthstone" },
  { id = 165802, englishName = "Noble Gardener's Hearthstone" },
  { id = 166746, englishName = "Fire Eater's Hearthstone" },
  { id = 166747, englishName = "Brewfest Reveler's Hearthstone" },
  { id = 168907, englishName = "Holographic Digitalization Hearthstone" },
  { id = 172179, englishName = "Eternal Traveler's Hearthstone" },
  { id = 180290, englishName = "Night Fae Hearthstone", usable = IsNightFaeHearthstoneUsable },
  { id = 182773, englishName = "Necrolord Hearthstone", usable = IsNecrolordHearthstoneUsable },
  { id = 183716, englishName = "Venthyr Sinstone", usable = IsVenthyrHearthstoneUsable },
  { id = 184353, englishName = "Kyrian Hearthstone", usable = IsKyrianHearthstoneUsable },
  { id = 188952, englishName = "Dominated Hearthstone" },
  { id = 190196, englishName = "Enlightened Hearthstone" },
  { id = 190237, englishName = "Broker Translocation Matrix" },
  { id = 193588, englishName = "Timewalker's Hearthstone" },
  { id = 200630, englishName = "Ohn'ir Windsage's Hearthstone" },
  { id = 206195, englishName = "Path of the Naaru" },
  { id = 208704, englishName = "Deepdweller's Earthen Hearthstone" },
  { id = 209035, englishName = "Hearthstone of the Flame" },
  { id = 210455, englishName = "Draenic Hologem", usable = IsDraenicHologemUsable },
  { id = 212337, englishName = "Stone of the Hearth" },
  { id = 228940, englishName = "Notorious Thread's Hearthstone" },
  { id = 235016, englishName = "Redeployment Module" },
  { id = 236687, englishName = "Explosive Hearthstone" },
  { id = 245970, englishName = "P.O.S.T. Master's Express Hearthstone" },
  { id = 246565, englishName = "Cosmic Hearthstone" },
  { id = 257736, englishName = "Lightcalled Hearthstone" },
  { id = 263489, englishName = "Naaru's Enfold" },
  { id = 263933, englishName = "Preyseeker's Hearthstone" },
  { id = 265100, englishName = "Corewarden's Hearthstone" },
}
local HEARTHSTONE_TOY_LOOKUP = {}
for _, entry in ipairs(HEARTHSTONE_TOYS) do
  HEARTHSTONE_TOY_LOOKUP[entry.id] = entry
end

local DALARAN_HEARTHSTONE_TOY_ID = 140192

local function IsOwnedToy(toyId)
  toyId = tonumber(toyId)
  if not toyId then
    return false
  end
  local playerHasToy = rawget(_G, "PlayerHasToy")
  if type(playerHasToy) ~= "function" then
    return false
  end
  local ok, hasToy = pcall(playerHasToy, toyId)
  return ok and hasToy == true
end

local function CollectOwnedHearthstoneToys()
  local owned = {}
  for _, entry in ipairs(HEARTHSTONE_TOYS) do
    if IsOwnedToy(entry.id) then
      local usable = true
      if type(entry.usable) == "function" then
        local okUsable, result = pcall(entry.usable)
        usable = okUsable and result == true
      end
      if usable then
        owned[#owned + 1] = entry.id
      end
    end
  end
  return owned
end

local function GetKnownHearthstoneToyIDs()
  local out = {}
  for _, entry in ipairs(HEARTHSTONE_TOYS) do
    out[#out + 1] = entry.id
  end
  return out
end

local function IsAvailableHearthstoneToy(toyId)
  toyId = tonumber(toyId)
  if not toyId or not HEARTHSTONE_TOY_LOOKUP[toyId] then
    return false
  end
  if not IsOwnedToy(toyId) then
    return false
  end
  local usable = HEARTHSTONE_TOY_LOOKUP[toyId].usable
  if type(usable) ~= "function" then
    return true
  end
  local okUsable, result = pcall(usable)
  return okUsable and result == true
end

local function GetHearthstoneToyEnglishName(toyId)
  toyId = tonumber(toyId)
  local entry = toyId and HEARTHSTONE_TOY_LOOKUP[toyId] or nil
  if type(entry) ~= "table" or type(entry.englishName) ~= "string" or entry.englishName == "" then
    return nil
  end
  return entry.englishName
end

local function ResolveHearthstoneChoice(choice)
  if type(choice) == "number" then
    return IsAvailableHearthstoneToy(choice) and choice or nil, nil
  end

  if type(choice) ~= "string" then
    return nil, nil
  end

  local normalized = tostring(choice)
  local toyId = normalized:match("^toy:(%d+)$")
  if toyId then
    local numericToyId = tonumber(toyId)
    return IsAvailableHearthstoneToy(numericToyId) and numericToyId or nil, nil
  end

  if normalized == "item:6948" then
    return nil, normalized
  end

  local numericToyId = tonumber(normalized)
  if numericToyId then
    return IsAvailableHearthstoneToy(numericToyId) and numericToyId or nil, nil
  end

  return nil, nil
end

local function IsDalaranHearthstoneAvailable()
  return IsOwnedToy(DALARAN_HEARTHSTONE_TOY_ID)
end

-- Export helper so other modules (settings) can query owned hearthstone toys.
addonTable.UI = addonTable.UI or {}
addonTable.UI.CollectOwnedHearthstoneToys = CollectOwnedHearthstoneToys
addonTable.UI.GetHearthstoneToyEnglishName = GetHearthstoneToyEnglishName
local SECOND_PANEL_UI_ENTRIES = {
  {
    id = "arkanatine_key",
    labelKey = "BTN_SECOND_ARKANATINE_KEY",
    fallbackText = "Arkantine",
    icon = "Interface\\Icons\\INV_Misc_Key_14",
    -- Item names differ by WoW client locale; resolved at button creation via GetLocale().
    secureMacroText = function()
      local getLocale = rawget(_G, "GetLocale")
      local clientLocale = type(getLocale) == "function" and getLocale() or ""
      if clientLocale == "deDE" then
        return "/use Persönlicher Schlüssel zur Arkantine"
      end
      return "/use Personal Key to the Arkantine"
    end,
  },
  {
    id = "hearthstone",
    labelKey = "BTN_SECOND_HEARTHSTONE",
    fallbackText = "Hearthstone",
    icon = "Interface\\Icons\\INV_Misc_Rune_04",
    isSecure = true,
  },
  {
    id = "dalaran_hearthstone",
    labelKey = "BTN_SECOND_DALARAN",
    fallbackText = "Dalaran",
    icon = "Interface\\Icons\\INV_Misc_Rune_04",
    isSecure = true,
  },
  {
    id = "housing_plot",
    labelKey = "BTN_SECOND_HOUSING",
    fallbackText = "Housing",
    iconAtlas = "UI-HUD-MicroMenu-Housing-Up",
    isSecure = true,
  },
}

Travel.SECOND_PANEL_UI_ENTRIES = SECOND_PANEL_UI_ENTRIES
Travel.CollectOwnedHearthstoneToys = CollectOwnedHearthstoneToys
Travel.GetHearthstoneToyEnglishName = GetHearthstoneToyEnglishName
Travel.GetKnownHearthstoneToyIDs = GetKnownHearthstoneToyIDs
Travel.ResolveHearthstoneChoice = ResolveHearthstoneChoice
Travel.DALARAN_HEARTHSTONE_TOY_ID = DALARAN_HEARTHSTONE_TOY_ID
Travel.IsDalaranHearthstoneAvailable = IsDalaranHearthstoneAvailable
