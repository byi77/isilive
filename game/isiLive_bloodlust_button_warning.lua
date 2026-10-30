local _, addonTable = ...
addonTable = addonTable or {}

local BloodlustButtonWarning = {}
addonTable.BloodlustButtonWarning = BloodlustButtonWarning
local IsSecretValue = addonTable.Validators.IsSecretValue
local ReadPlainNumber = addonTable.Validators.ReadPlainNumber

-- Sated-class debuffs and the Bloodlust-class spells looked for on the action
-- bars come from data/isiLive_spells.lua (`actionButton = true` entries).
local Spells = addonTable.Spells
local SpellManifest = addonTable.SpellManifest
local LUST_SATED_IDS = Spells.BuildIDSet(SpellManifest.lustSated)

local BLOODLUST_CLASS_TOKENS = {
  SHAMAN = true,
  MAGE = true,
  EVOKER = true,
  HUNTER = true,
}

local BLOODLUST_BUTTON_SPELL_IDS = Spells.BuildIDSet(SpellManifest.lustCasts, Spells.IsActionButtonLust)

local function DefaultGetDB()
  return rawget(_G, "IsiLiveDB") or {}
end

local function DefaultIsLocalBloodlustClass()
  if not addonTable.Validators.IsExistingUnit("player") then
    return false
  end
  local unitClass = rawget(_G, "UnitClass")
  if type(unitClass) ~= "function" then
    return false
  end
  local ok, _, classToken = pcall(unitClass, "player")
  return ok and not IsSecretValue(classToken) and BLOODLUST_CLASS_TOKENS[classToken] == true
end

local function DefaultGetActionSpellID(button)
  local helper = addonTable.ActionButtonOverlay
  if type(helper) == "table" and type(helper.GetActionSpellID) == "function" then
    return helper.GetActionSpellID(button)
  end
  return nil
end

local function DefaultScanBloodlustButtons(getActionSpellID)
  local helper = addonTable.ActionButtonOverlay
  if type(helper) == "table" and type(helper.ScanButtonsForSpellIDs) == "function" then
    return helper.ScanButtonsForSpellIDs(getActionSpellID, BLOODLUST_BUTTON_SPELL_IDS)
  end
  return {}
end

local function DefaultCreateOverlay(button)
  local helper = addonTable.ActionButtonOverlay
  if type(helper) == "table" and type(helper.CreateCrossOverlay) == "function" then
    return helper.CreateCrossOverlay(button)
  end
  return nil
end

-- Same read order as the CD tracker: the spell ID lookup still answers while the
-- aura list is blocked during a key. Returns true or false when the debuff state
-- is known, nil when it cannot be read.
local function ReadExhaustionBySpellID(getPlayerAura)
  local complete = true
  for _, record in ipairs(SpellManifest.lustSated) do
    local ok, aura = pcall(getPlayerAura, record.id)
    if not ok or IsSecretValue(aura) then
      complete = false
    elseif aura ~= nil then
      return true
    end
  end
  if complete then
    return false
  end
  return nil
end

local function DefaultHasBloodlustExhaustionDebuff()
  local C_UnitAuras_ref = rawget(_G, "C_UnitAuras")
  if type(C_UnitAuras_ref) ~= "table" then
    return false
  end
  local getPlayerAura = rawget(C_UnitAuras_ref, "GetPlayerAuraBySpellID")
  if type(getPlayerAura) == "function" then
    local known = ReadExhaustionBySpellID(getPlayerAura)
    if known ~= nil then
      return known
    end
  end
  local getAuraDataByIndex = rawget(C_UnitAuras_ref, "GetAuraDataByIndex")
  if type(getAuraDataByIndex) ~= "function" then
    if type(getPlayerAura) == "function" then
      return nil
    end
    return false
  end
  local complete = true
  for index = 1, 40 do
    local ok, aura = pcall(getAuraDataByIndex, "player", index, "HARMFUL")
    if not ok or IsSecretValue(aura) then
      complete = false
    elseif type(aura) == "table" then
      -- ReadPlainNumber rejects a masked spellId before it reaches the lookup;
      -- a Secret Value used as a table key raises "table index is secret".
      local spellID = ReadPlainNumber(aura, "spellId")
      if spellID and LUST_SATED_IDS[spellID] == true then
        return true
      end
      complete = complete and spellID ~= nil
    end
  end
  if complete then
    return false
  end
  return nil
end

function BloodlustButtonWarning.CreateController(opts)
  opts = opts or {}
  local getDB = type(opts.getDB) == "function" and opts.getDB or DefaultGetDB
  local isLocalBloodlustClass = type(opts.isLocalBloodlustClass) == "function" and opts.isLocalBloodlustClass
    or DefaultIsLocalBloodlustClass
  local getActionSpellID = type(opts.getActionSpellID) == "function" and opts.getActionSpellID
    or DefaultGetActionSpellID
  local scanBloodlustButtons = type(opts.scanBloodlustButtons) == "function" and opts.scanBloodlustButtons
    or function()
      return DefaultScanBloodlustButtons(getActionSpellID)
    end
  local createOverlay = type(opts.createOverlay) == "function" and opts.createOverlay or DefaultCreateOverlay
  local hasBloodlustExhaustionDebuff = type(opts.hasBloodlustExhaustionDebuff) == "function"
      and opts.hasBloodlustExhaustionDebuff
    or DefaultHasBloodlustExhaustionDebuff

  local controller = {}
  local overlaysByButton = {}

  local function HideAll()
    for _, overlay in pairs(overlaysByButton) do
      if type(overlay) == "table" and type(overlay.Hide) == "function" then
        overlay:Hide()
      end
    end
  end

  local function IsEnabled()
    local db = getDB() or {}
    return db.vipBloodlustDebuffButtonWarningEnabled == true and isLocalBloodlustClass() == true
  end

  function controller.Refresh()
    if not IsEnabled() then
      HideAll()
      return
    end
    -- nil means unreadable, which says nothing about the debuff: the current
    -- crosses stay until a readable answer arrives.
    local debuffed = hasBloodlustExhaustionDebuff()
    if debuffed == nil then
      return
    end
    if debuffed ~= true then
      HideAll()
      return
    end

    local seen = {}
    local buttons = scanBloodlustButtons() or {}
    for _, button in ipairs(buttons) do
      if type(button) == "table" then
        seen[button] = true
        local overlay = overlaysByButton[button]
        if not overlay then
          overlay = createOverlay(button)
          overlaysByButton[button] = overlay
        end
        if type(overlay) == "table" and type(overlay.Show) == "function" then
          overlay:Show()
        end
      end
    end

    for button, overlay in pairs(overlaysByButton) do
      if not seen[button] and type(overlay) == "table" and type(overlay.Hide) == "function" then
        overlay:Hide()
      end
    end
  end

  function controller.Stop()
    HideAll()
  end

  function controller.GetOverlayCountForTests()
    local count = 0
    for _ in pairs(overlaysByButton) do
      count = count + 1
    end
    return count
  end

  return controller
end

local controllerInstance = nil

function BloodlustButtonWarning.SetDependencies(deps)
  if type(deps) ~= "table" then
    return
  end
  controllerInstance = BloodlustButtonWarning.CreateController(deps)
end

function BloodlustButtonWarning.HandleEvent(event, unit)
  if not controllerInstance then
    return
  end
  if event == "UNIT_AURA" and unit ~= "player" then
    return
  end
  if
    event == "UNIT_AURA"
    or event == "PLAYER_LOGIN"
    or event == "PLAYER_ENTERING_WORLD"
    or event == "PLAYER_SPECIALIZATION_CHANGED"
    or event == "PLAYER_REGEN_ENABLED"
  then
    controllerInstance.Refresh()
  end
end
