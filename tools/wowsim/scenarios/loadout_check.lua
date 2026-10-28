-- Pre-key talent / loot spec check (rule 215).
--
-- Entering a season dungeon on Mythic difficulty (23) before the key shows the
-- loadout card. The first visit has no target and offers "remember"; after a
-- confirm and a re-entry with a different loadout and loot spec the card flags
-- both, the one-click buttons fix them, and the key start closes the card.
--
-- The simulator has no talent model, so this scenario installs a small one on
-- the focus client's environment: two saved loadouts for Fire Mage and the
-- three Mage specs as loot choices.
local MURDER_ROW_MAP_ID = 587
local FIRE_MAGE = 63
local FROST_MAGE = 64
local ARCANE_MAGE = 62
local MYTHIC_PARTY_DIFFICULTY_ID = 23
local MYTHIC_KEYSTONE_DIFFICULTY_ID = 8

local SPEC_NAMES = { [ARCANE_MAGE] = "Arcane", [FIRE_MAGE] = "Fire", [FROST_MAGE] = "Frost" }
local SPEC_ORDER = { ARCANE_MAGE, FIRE_MAGE, FROST_MAGE }
local LOADOUTS = { { id = 9101, name = "M+ AoE Fire" }, { id = 9102, name = "M+ Single Target" } }

local function InstallTalentModel(sim)
  local env = sim.Env()
  local state = { selected = 9101, lootSpecID = 0, loads = {} }

  env.GetSpecializationInfo = function(index)
    local specID = SPEC_ORDER[index]
    if not specID then
      return nil
    end
    return specID, SPEC_NAMES[specID], "", 136243, "DAMAGER", "MAGE"
  end
  env.GetSpecialization = function()
    return 2
  end
  env.C_SpecializationInfo.GetSpecialization = env.GetSpecialization
  env.C_SpecializationInfo.GetSpecializationInfo = env.GetSpecializationInfo

  env.C_Traits.GetConfigInfo = function(configID)
    for _, loadout in ipairs(LOADOUTS) do
      if loadout.id == configID then
        return { name = loadout.name }
      end
    end
    return nil
  end
  env.C_ClassTalents.GetConfigIDsBySpecID = function(specID)
    if specID ~= FIRE_MAGE then
      return {}
    end
    return { LOADOUTS[1].id, LOADOUTS[2].id }
  end
  env.C_ClassTalents.GetStarterBuildActive = function()
    return false
  end
  env.C_ClassTalents.GetLastSelectedSavedConfigID = function()
    return state.selected
  end
  env.C_ClassTalents.LoadConfig = function(configID)
    state.loads[#state.loads + 1] = configID
    state.selected = configID
    sim.Fire("TRAIT_CONFIG_UPDATED", configID)
    return 2 -- Enum.LoadConfigResult.LoadInProgress
  end
  env.C_ClassTalents.UpdateLastSelectedSavedConfigID = function() end
  env.GetLootSpecialization = function()
    return state.lootSpecID
  end
  env.SetLootSpecialization = function(specID)
    state.lootSpecID = specID
    sim.Fire("PLAYER_LOOT_SPEC_UPDATED")
  end
  return state
end

local function EnterBeforeKey(sim)
  sim.EnterDungeon(MURDER_ROW_MAP_ID)
  sim.world.instance.difficultyID = MYTHIC_PARTY_DIFFICULTY_ID
  sim.Wait(3)
end

-- The card's buttons carry their label in `_flatLabel`, which sim.Click does
-- not search, so the click is dispatched here.
local function ClickCardButton(sim, pattern)
  local engine = sim.Client().engine
  for _, obj in ipairs(engine.all) do
    local label = obj._flatLabel and obj._flatLabel._text
    if label and obj:IsVisible() and engine.StripEscapes(label):find(pattern) then
      local onClick = obj:GetScript("OnClick")
      if onClick then
        onClick(obj, "LeftButton", false)
        return true
      end
    end
  end
  sim.Expect(false, "card button '" .. pattern .. "' not found")
  return false
end

local function CardShown(sim)
  local card = sim.Env().IsiLiveLoadoutCheckCard
  return card ~= nil and card:IsShown() == true
end

return {
  name = "loadout_check",
  description = "Pre-key talent and loot spec check: learn, flag, one-click fix, close on key start",
  setup = {
    locale = "deDE",
    party = {
      { name = "Isiplayer", class = "MAGE", specID = FIRE_MAGE, role = "DAMAGER", ilvl = 330, rating = 3310 },
      { name = "Tankone", class = "WARRIOR", specID = 73, role = "TANK", addon = "none" },
      { name = "Healone", class = "PRIEST", specID = 257, role = "HEALER", addon = "none" },
      { name = "Dpsone", class = "HUNTER", specID = 253, role = "DAMAGER", addon = "none" },
      { name = "Dpstwo", class = "ROGUE", specID = 260, role = "DAMAGER", addon = "none" },
    },
  },
  run = function(sim)
    local state = InstallTalentModel(sim)
    sim.Login()
    sim.JoinGroup("Tankone", "Healone", "Dpsone", "Dpstwo")
    sim.Wait(3)

    EnterBeforeKey(sim)
    sim.Step("First visit: nothing remembered yet")
    sim.Expect(CardShown(sim), "card appears on entering a season dungeon before the key")
    sim.ExpectText("noch nicht gemerkt", "first visit shows the not-yet-remembered status")
    sim.ExpectText("Passt – merken", "first visit offers to remember")

    ClickCardButton(sim, "Passt – merken")
    sim.Wait(1)
    sim.Step("Confirmed and remembered")
    sim.Expect(not CardShown(sim), "confirm closes the card")
    local stored = sim.Env().IsiLiveDB.loadoutCheck
    sim.Expect(type(stored) == "table" and next(stored) ~= nil, "confirm stores the target in IsiLiveDB")

    sim.LeaveDungeon()
    sim.Wait(3)
    state.selected = 9102
    state.lootSpecID = FROST_MAGE
    EnterBeforeKey(sim)
    sim.Step("Second visit: wrong loadout and loot spec")
    sim.Expect(CardShown(sim), "re-entry checks again")
    sim.ExpectText("erwartet: M%+ AoE Fire", "talent mismatch names the expected loadout")
    sim.ExpectText("erwartet: Aktuelle Spec %(Fire%)", "loot mismatch names the expected loot spec")

    ClickCardButton(sim, "M%+ AoE Fire")
    ClickCardButton(sim, "Aktuelle Spec")
    sim.Wait(1)
    sim.Step("Fixed with one click each")
    sim.Expect(state.loads[#state.loads] == 9101, "the loadout button loads the clicked loadout")
    sim.Expect(state.lootSpecID == 0, "the loot button sets the current-spec default")
    sim.ExpectText("Alles OK", "with both fixed the confirm button reads all OK")

    ClickCardButton(sim, "Alles OK")
    sim.LeaveDungeon()
    sim.Wait(3)
    EnterBeforeKey(sim)
    sim.Step("Third visit: everything matches")
    sim.Expect(not CardShown(sim), "a full match shows no card")
    sim.ExpectLog("print", "passen für Murder Row", nil, "a full match prints one green chat line")

    sim.world.instance.difficultyID = MYTHIC_KEYSTONE_DIFFICULTY_ID
    sim.StartKey({ mapID = MURDER_ROW_MAP_ID, level = 12 })
    sim.Wait(2)
    sim.Step("Key started")
    sim.Expect(not CardShown(sim), "key start closes the card")
  end,
}
