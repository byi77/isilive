local _, addonTable = ...

addonTable = addonTable or {}
addonTable.UI = addonTable.UI or {}

local Travel = {}
addonTable.UIGameMenuTravel = Travel
local IsSecretValue = addonTable.Validators.IsSecretValue

-- Curated IDs live in data/isiLive_travel_items.lua; this module only evaluates them.
local TravelItems = addonTable.TravelItemManifest or {}
local HEARTHSTONE_TOYS = type(TravelItems.hearthstoneToys) == "table" and TravelItems.hearthstoneToys or {}
local COVENANT_RENOWN_ACHIEVEMENT_ID = TravelItems.covenantRenownAchievementID
local DEFAULT_HEARTHSTONE_ITEM_STRING = TravelItems.defaultHearthstoneItemID
    and ("item:" .. tostring(TravelItems.defaultHearthstoneItemID))
  or nil
local DALARAN_HEARTHSTONE_TOY_ID = TravelItems.dalaranHearthstoneToyID
local ARCANTINA_KEY_ITEM_ID = TravelItems.arcantinaKeyItemID

local covenantRenownCriteria = nil
local function HasCompletedCovenantRenownCriteria(criteriaIndex)
  criteriaIndex = tonumber(criteriaIndex)
  if not criteriaIndex then
    return false
  end
  if covenantRenownCriteria == nil then
    covenantRenownCriteria = {}
    local getCriteriaInfo = rawget(_G, "GetAchievementCriteriaInfo")
    if type(getCriteriaInfo) == "function" and COVENANT_RENOWN_ACHIEVEMENT_ID then
      for index = 1, 4 do
        local ok, _, _, completed = pcall(getCriteriaInfo, COVENANT_RENOWN_ACHIEVEMENT_ID, index)
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

local function PlayerRaceIDIn(raceIDs)
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
  for _, candidate in ipairs(raceIDs) do
    if raceID == candidate then
      return true
    end
  end
  return false
end

-- Evaluates a declarative `requires` block from the travel-item manifest.
-- A covenant toy unlocks through the renown criteria or the active covenant;
-- an unknown requirement shape fails closed.
local function MeetsRequirements(requires)
  if requires == nil then
    return true
  end
  if type(requires) ~= "table" then
    return false
  end
  if requires.covenantID ~= nil or requires.renownCriteria ~= nil then
    return HasCompletedCovenantRenownCriteria(requires.renownCriteria) or HasActiveCovenant(requires.covenantID)
  end
  if type(requires.raceIDs) == "table" then
    return PlayerRaceIDIn(requires.raceIDs)
  end
  return false
end

local HEARTHSTONE_TOY_LOOKUP = {}
for _, entry in ipairs(HEARTHSTONE_TOYS) do
  HEARTHSTONE_TOY_LOOKUP[entry.id] = entry
end

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

local function IsUsableHearthstoneEntry(entry)
  local okUsable, usable = pcall(MeetsRequirements, entry.requires)
  return okUsable and usable == true
end

local function CollectOwnedHearthstoneToys()
  local owned = {}
  for _, entry in ipairs(HEARTHSTONE_TOYS) do
    if IsOwnedToy(entry.id) and IsUsableHearthstoneEntry(entry) then
      owned[#owned + 1] = entry.id
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
  return IsUsableHearthstoneEntry(HEARTHSTONE_TOY_LOOKUP[toyId])
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

  if DEFAULT_HEARTHSTONE_ITEM_STRING and normalized == DEFAULT_HEARTHSTONE_ITEM_STRING then
    return nil, normalized
  end

  local numericToyId = tonumber(normalized)
  if numericToyId then
    return IsAvailableHearthstoneToy(numericToyId) and numericToyId or nil, nil
  end

  return nil, nil
end

-- Picks a random entry from `pool` that differs from `current` when possible.
--
-- The previous shape was `repeat pick = pool[math.random(1, #pool)] until pick
-- ~= current`, guarded only by an `#pool == 1` special case. That loop never
-- terminates when every remaining entry equals `current` -- which happens the
-- moment the owned-toy list contains the same ID twice. The catalogue has no
-- duplicates today, so this was latent rather than live, but the failure mode
-- is a frozen client on a hearthstone click, so the loop gets a hard bound
-- instead of relying on the data staying clean. After MAX_PICK_ATTEMPTS we
-- accept a repeat of the current toy: rerolling the same mount is a cosmetic
-- miss, hanging the client is not.
local MAX_PICK_ATTEMPTS = 10

local function PickDifferentEntry(pool, current)
  local size = #pool
  if size == 0 then
    return nil
  end
  if size == 1 then
    return pool[1]
  end
  local pick = pool[math.random(1, size)]
  local attempts = 1
  while pick == current and attempts < MAX_PICK_ATTEMPTS do
    pick = pool[math.random(1, size)]
    attempts = attempts + 1
  end
  return pick
end

-- Single source for what the hearthstone button should bind, shared by the
-- secure refresh, the TOYS_UPDATED handler and the PreClick re-roll. Callers
-- own the combat-lockdown gate and the SetAttribute calls.
--
-- Returns { isExplicit, type, value, pool }:
--   * explicit owned toy  -> type "toy", value = toy id, pool = { toy id }
--   * explicit item       -> type "item", value = item string, pool = nil
--   * random              -> type "toy", value = a pick from the owned pool;
--                            `opts.pool` is reused when non-empty, and
--                            `opts.current` is avoided when possible
--   * random, none owned  -> type "item", value = default hearthstone, pool = nil
function Travel.ResolveHearthstoneSelection(choice, opts)
  opts = type(opts) == "table" and opts or {}
  local explicitToyId, explicitItemString = ResolveHearthstoneChoice(choice)
  if explicitToyId then
    return { isExplicit = true, type = "toy", value = explicitToyId, pool = { explicitToyId } }
  end
  if explicitItemString then
    return { isExplicit = true, type = "item", value = explicitItemString, pool = nil }
  end

  local pool = opts.pool
  if type(pool) ~= "table" or #pool == 0 then
    pool = CollectOwnedHearthstoneToys()
  end
  if #pool > 0 then
    return { isExplicit = false, type = "toy", value = PickDifferentEntry(pool, opts.current), pool = pool }
  end
  return { isExplicit = false, type = "item", value = DEFAULT_HEARTHSTONE_ITEM_STRING, pool = nil }
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
    -- The item ID resolves on every client locale; item names did not (the
    -- English macro text "Arkantine" never matched "Personal Key to the Arcantina").
    secureMacroText = function()
      if not ARCANTINA_KEY_ITEM_ID then
        return nil
      end
      return "/use item:" .. tostring(ARCANTINA_KEY_ITEM_ID)
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
Travel.PickDifferentEntry = PickDifferentEntry
Travel.DEFAULT_HEARTHSTONE_ITEM_STRING = DEFAULT_HEARTHSTONE_ITEM_STRING
Travel.DALARAN_HEARTHSTONE_TOY_ID = DALARAN_HEARTHSTONE_TOY_ID
Travel.IsDalaranHearthstoneAvailable = IsDalaranHearthstoneAvailable
