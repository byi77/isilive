local _, addonTable = ...
addonTable = addonTable or {}

local CdTracker = {}
addonTable.CdTracker = CdTracker

local BRES_SPELL_IDS = {
  20484, -- Rebirth (Druid)
  61999, -- Raise Ally (Death Knight)
  391054, -- Intercession (Paladin)
  20707, -- Soulstone Resurrection (Warlock)
}

-- Sated / Exhaustion / Insanity / Temporal Displacement debuff IDs left behind
-- by Bloodlust-class effects. ScanLust matches these against the player's
-- HARMFUL aura list, so only the actual debuff IDs belong here — the cast
-- IDs (e.g. 2825 Bloodlust, 32182 Heroism, 80353 Time Warp) would never
-- appear as HARMFUL auras and were dead matches.
local LUST_SATED_IDS = {
  [57723] = true, -- Exhaustion (Bloodlust)
  [57724] = true, -- Sated (Heroism)
  [80354] = true, -- Temporal Displacement (Time Warp)
  [264689] = true, -- Fatigued (Primal Rage)
  [390435] = true, -- Exhaustion (Ancient Hysteria)
  [95809] = true, -- Insanity (pet variants)
}

function CdTracker.CreateController(opts)
  opts = opts or {}
  local getTime = type(opts.getTime) == "function" and opts.getTime or GetTime

  local bresCharges = nil
  local bresMaxCharges = nil
  local bresCooldownRemain = nil
  local lustRemain = nil
  local lustIcon = nil

  local function ResolveBResChargeInfo(C_Spell_ref)
    for _, spellID in ipairs(BRES_SPELL_IDS) do
      local ok, chargeInfoOrCharges, maxCharges, _, chargeStart, chargeDuration =
        pcall(C_Spell_ref.GetSpellCharges, spellID)
      if ok and chargeInfoOrCharges ~= nil then
        return chargeInfoOrCharges, maxCharges, chargeStart, chargeDuration
      end
    end
    return nil
  end

  local function ApplyBResChargeInfo(chargeInfoOrCharges, maxCharges, chargeStart, chargeDuration)
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
      return false
    end
    bresCharges = charges
    bresMaxCharges = maxCharges
    if charges < maxCharges and chargeStart and chargeStart > 0 and chargeDuration then
      bresCooldownRemain = math.max(0, chargeStart + chargeDuration - getTime())
    else
      bresCooldownRemain = 0
    end
    return true
  end

  local function ScanBRes()
    local C_Spell_ref = rawget(_G, "C_Spell")
    if type(C_Spell_ref) ~= "table" or type(C_Spell_ref.GetSpellCharges) ~= "function" then
      bresCharges = nil
      return
    end
    local chargeInfoOrCharges, maxCharges, chargeStart, chargeDuration = ResolveBResChargeInfo(C_Spell_ref)
    if not ApplyBResChargeInfo(chargeInfoOrCharges, maxCharges, chargeStart, chargeDuration) then
      bresCharges = nil
      return
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
          if remain > 0 then
            lustRemain = remain
          elseif lustRemain ~= nil then
            lustRemain = 0
          end
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

  function controller.ClearRuntimeData()
    bresCharges = nil
    bresMaxCharges = nil
    bresCooldownRemain = nil
    lustRemain = nil
    lustIcon = nil
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
