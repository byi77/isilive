local _, addonTable = ...
addonTable = addonTable or {}

local CdTracker = {}
addonTable.CdTracker = CdTracker

local BRES_SPELL_ID = 20484

-- All Bloodlust / Heroism / Time Warp variant spell IDs that inflict Sated/Exhaustion
local LUST_SATED_IDS = {
  [2825] = true,
  [32182] = true,
  [80353] = true,
  [264667] = true,
  [390386] = true,
  [381301] = true,
  [178207] = true,
  [230935] = true,
  [256740] = true,
  [57723] = true,
  [57724] = true,
  [80354] = true,
  [264689] = true,
  [390435] = true,
  [95809] = true,
  [16045] = true,
}

function CdTracker.CreateController(opts)
  opts = opts or {}
  local getTime = type(opts.getTime) == "function" and opts.getTime or GetTime

  local bresCharges = nil
  local bresMaxCharges = nil
  local bresCooldownRemain = nil
  local lustRemain = nil
  local lustIcon = nil

  local function ScanBRes()
    local C_Spell_ref = rawget(_G, "C_Spell")
    if type(C_Spell_ref) ~= "table" or type(C_Spell_ref.GetSpellCharges) ~= "function" then
      bresCharges = nil
      return
    end
    local ok, chargeInfoOrCharges, maxCharges, _, chargeStart, chargeDuration =
      pcall(C_Spell_ref.GetSpellCharges, BRES_SPELL_ID)
    if not ok then
      bresCharges = nil
      return
    end

    local charges
    if type(chargeInfoOrCharges) == "table" then
      charges = chargeInfoOrCharges.currentCharges
      maxCharges = chargeInfoOrCharges.maxCharges
      chargeStart = chargeInfoOrCharges.cooldownStartTime
      chargeDuration = chargeInfoOrCharges.cooldownDuration
    else
      charges = chargeInfoOrCharges
    end

    if type(charges) ~= "number" or type(maxCharges) ~= "number" then
      bresCharges = nil
      return
    end
    bresCharges = charges
    bresMaxCharges = maxCharges
    if charges < maxCharges and chargeStart and chargeStart > 0 and chargeDuration then
      bresCooldownRemain = math.max(0, chargeStart + chargeDuration - getTime())
    else
      bresCooldownRemain = 0
    end
  end

  local function ScanLust()
    local C_UnitAuras_ref = rawget(_G, "C_UnitAuras")
    local getAuraDataByIndex = type(C_UnitAuras_ref) == "table" and rawget(C_UnitAuras_ref, "GetAuraDataByIndex") or nil
    if type(getAuraDataByIndex) ~= "function" then
      lustRemain = nil
      lustIcon = nil
      return
    end
    -- Query each aura slot for a known Sated/Exhaustion debuff.
    -- WoW aura objects contain "secret" values that look like numbers to type()
    -- but throw "table index is secret" when used as table keys.  Wrapping the
    -- spell-ID check in pcall is the only safe path.
    local found = false
    for index = 1, 40 do
      local ok, aura = pcall(getAuraDataByIndex, "player", index, "HARMFUL")
      if ok and type(aura) == "table" then
        local isMatch = false
        pcall(function()
          local sid = rawget(aura, "spellId")
          if sid and LUST_SATED_IDS[sid] then
            isMatch = true
          end
        end)
        if isMatch then
          local expiry = rawget(aura, "expirationTime")
          local remain = type(expiry) == "number" and math.max(0, expiry - getTime()) or 0
          if remain > 0 then lustRemain = remain end
          lustIcon = rawget(aura, "icon")
          found = true
          break
        end
      end
    end
    if not found then
      lustRemain = nil
      lustIcon = nil
    end
  end

  local demoOverride = nil

  local controller = {}

  function controller.SetDemoData(data)
    demoOverride = data
  end

  function controller.ClearDemoData()
    demoOverride = nil
  end

  function controller.GetBResInfo()
    if demoOverride then
      return demoOverride.bres
    end
    if bresCharges == nil then
      return nil
    end
    return {
      charges = bresCharges,
      maxCharges = bresMaxCharges,
      cooldownRemain = bresCooldownRemain,
    }
  end

  function controller.GetLustInfo()
    if demoOverride then
      return demoOverride.lust
    end
    if lustRemain == nil then
      return nil
    end
    return { remain = lustRemain, icon = lustIcon }
  end

  function controller.Scan()
    ScanBRes()
    ScanLust()
  end

  return controller
end
