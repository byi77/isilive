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
  local lustScanResolved = false

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
    local previouslyObserved = lustRemain ~= nil
    lustScanResolved = false
    lustRemain, lustDuration, lustIcon = nil, nil, nil
    local api = rawget(_G, "C_UnitAuras")
    local readAura = type(api) == "table" and rawget(api, "GetAuraDataByIndex") or nil
    if type(readAura) ~= "function" then
      return
    end
    -- Absence requires a readable list ending; skipped secret/error slots
    -- cannot prove readiness. A verified active match still resolves directly.
    local complete = true
    for index = 1, 40 do
      local ok, aura = pcall(readAura, "player", index, "HARMFUL")
      local plain = ok and not IsSecretValue(aura)
      if plain and aura == nil then
        lustScanResolved = complete
        return
      end
      local spellID = plain and type(aura) == "table" and ReadPlainNumber(aura, "spellId") or nil
      if spellID and LUST_SATED_IDS[spellID] then
        local expiry = ReadPlainNumber(aura, "expirationTime")
        if expiry then
          lustScanResolved = true
          local remain = math.max(0, expiry - getTime())
          lustRemain = (remain > 0 or previouslyObserved) and remain or nil
          lustDuration = ReadPlainNumber(aura, "duration")
          lustIcon = ReadPlainField(aura, "icon")
        end
        return
      end
      if not spellID then
        complete = false
      end
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
    lustScanResolved = false
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

  function controller.IsLustScanResolved()
    return demoOverride ~= nil or lustScanResolved
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
