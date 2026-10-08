local _, addonTable = ...
addonTable = addonTable or {}

local CdTracker = {}
addonTable.CdTracker = CdTracker
local ReadPlainField = addonTable.Validators.ReadPlainField
local ReadPlainNumber = addonTable.Validators.ReadPlainNumber
local IsSecretValue = addonTable.Validators.IsSecretValue

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
  -- Total length of the running recharge / Sated debuff. Only used to draw a
  -- cooldown swipe; nil whenever the client did not report a plain value.
  local bresCooldownDuration = nil
  local lustRemain = nil
  local lustDuration = nil
  local lustIcon = nil

  -- GetSpellCharges may hand back Secret Values in restricted content, both as
  -- the flat multi-return and as fields of the ChargeInfo struct. Every value
  -- is rejected as secret before anything else touches it -- the plain nil
  -- check of the first return is already an operation on a Secret Value.
  -- A masked first return still means "this spell answered": the scan stops
  -- there and reports no charge info, so the row fails closed to "BR: --".
  local function ResolveBResChargeInfo(C_Spell_ref)
    for _, spellID in ipairs(BRES_SPELL_IDS) do
      local ok, chargeInfoOrCharges, maxCharges, _, chargeStart, chargeDuration =
        pcall(C_Spell_ref.GetSpellCharges, spellID)
      local maskedTiming = IsSecretValue(chargeStart) or IsSecretValue(chargeDuration)
      if ok and (IsSecretValue(chargeInfoOrCharges) or IsSecretValue(maxCharges)) then
        return nil
      end
      if maskedTiming then
        chargeStart, chargeDuration = nil, nil
      end
      if ok and type(chargeInfoOrCharges) ~= "nil" then
        return chargeInfoOrCharges, maxCharges, chargeStart, chargeDuration
      end
    end
    return nil
  end

  local function ApplyBResChargeInfo(chargeInfoOrCharges, maxCharges, chargeStart, chargeDuration)
    local charges
    if type(chargeInfoOrCharges) == "table" then
      charges = ReadPlainNumber(chargeInfoOrCharges, "currentCharges")
      maxCharges = ReadPlainNumber(chargeInfoOrCharges, "maxCharges")
      chargeStart = ReadPlainNumber(chargeInfoOrCharges, "cooldownStartTime")
      chargeDuration = ReadPlainNumber(chargeInfoOrCharges, "cooldownDuration")
    else
      -- Flat multi-return: ResolveBResChargeInfo already rejected every
      -- masked value, so only the type is left to check.
      charges = chargeInfoOrCharges
    end

    -- Missing or masked charge counts fail closed (no made-up number).
    if type(charges) ~= "number" or type(maxCharges) ~= "number" then
      return false
    end
    if type(chargeStart) ~= "number" then
      chargeStart = nil
    end
    if type(chargeDuration) ~= "number" then
      chargeDuration = nil
    end
    bresCharges = charges
    bresMaxCharges = maxCharges
    if charges < maxCharges and chargeStart and chargeStart > 0 and chargeDuration then
      bresCooldownRemain = math.max(0, chargeStart + chargeDuration - getTime())
      bresCooldownDuration = chargeDuration
    else
      -- Full charges, or a recharge whose timing is masked: no countdown is
      -- invented, the row shows the plain charge count only.
      bresCooldownRemain = 0
      bresCooldownDuration = nil
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
    -- but throw "table index is secret" when used as table keys, and raise on
    -- every comparison or calculation. Validators.ReadPlain* rejects a masked
    -- field before it is ever used, so both the table lookup below and the
    -- expiry arithmetic only ever see plain values.
    local found = false
    for index = 1, 40 do
      local ok, aura = pcall(getAuraDataByIndex, "player", index, "HARMFUL")
      if ok and type(aura) == "table" then
        local spellID = ReadPlainNumber(aura, "spellId")
        if spellID and LUST_SATED_IDS[spellID] then
          local expiry = ReadPlainNumber(aura, "expirationTime")
          local remain = expiry and math.max(0, expiry - getTime()) or 0
          if remain > 0 then
            lustRemain = remain
          elseif lustRemain ~= nil then
            lustRemain = 0
          end
          lustIcon = ReadPlainField(aura, "icon")
          lustDuration = ReadPlainNumber(aura, "duration")
          found = true
          break
        end
      end
    end
    if not found then
      lustRemain = nil
      lustDuration = nil
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
    bresCooldownDuration = nil
    lustRemain = nil
    lustDuration = nil
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
      cooldownDuration = bresCooldownDuration,
    }
  end

  function controller.GetLustInfo()
    if demoOverride then
      return demoOverride.lust
    end
    if lustRemain == nil then
      return nil
    end
    return { remain = lustRemain, duration = lustDuration, icon = lustIcon }
  end

  function controller.Scan()
    ScanBRes()
    ScanLust()
  end

  return controller
end
