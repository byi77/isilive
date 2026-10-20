local _, addonTable = ...
addonTable = addonTable or {}

local CdTracker = {}
addonTable.CdTracker = CdTracker
local ReadPlainField = addonTable.Validators.ReadPlainField
local ReadPlainNumber = addonTable.Validators.ReadPlainNumber
local IsSecretValue = addonTable.Validators.IsSecretValue

-- Battle-Res spells (scan order) and the Sated-class debuff IDs come from
-- data/isiLive_spells.lua. ScanLust matches the debuffs against the player's
-- HARMFUL aura list; cast IDs would never appear there.
local Spells = addonTable.Spells
local SpellManifest = addonTable.SpellManifest
local BRES_SPELL_IDS = Spells.BuildIDList(SpellManifest.battleRes)
local LUST_SATED_IDS = Spells.BuildIDSet(SpellManifest.lustSated)

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
  -- Expiry of the last plainly read Sated debuff. In a running key the client
  -- throws on secret aura slots, so after Sated drops the list often cannot be
  -- read to its end and absence stays unproven. Sated has a fixed length and
  -- cannot be removed or refreshed early, so a verified expiry that has passed
  -- proves readiness on its own.
  local lustKnownExpiry = nil
  -- Readiness confirmed by a readable list ending or a passed verified expiry.
  -- Sated/Exhaustion is on Blizzard's never-secret aura list, so a slot the
  -- client refuses to read cannot be a new Sated: while this is set, an
  -- undecided scan still means "ready" and the 60-second reminder keeps
  -- running inside a key. A plainly read Sated (Lust used again) clears it.
  local lustReadyConfirmed = false

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

  -- Classifies one aura: "found" for a verified Sated match (its timer is
  -- applied), "undecided" for a Sated whose expiry is masked, "other" for a
  -- plainly read other aura, nil when the aura itself cannot be read.
  local function MatchLustAura(aura, previouslyObserved)
    local spellID = not IsSecretValue(aura) and type(aura) == "table" and ReadPlainNumber(aura, "spellId") or nil
    if not spellID then
      return nil
    end
    if not LUST_SATED_IDS[spellID] then
      return "other"
    end
    local expiry = ReadPlainNumber(aura, "expirationTime")
    if not expiry then
      return "undecided"
    end
    local remain = math.max(0, expiry - getTime())
    lustRemain = (remain > 0 or previouslyObserved) and remain or nil
    lustDuration = ReadPlainNumber(aura, "duration")
    lustIcon = ReadPlainField(aura, "icon")
    lustKnownExpiry = remain > 0 and expiry or nil
    return "found"
  end

  -- Both readers return "found" for a verified Sated match, "absent" for a
  -- fully readable list without one, nil when the scan could not decide:
  -- skipped secret/error entries cannot prove readiness.
  local function ReadLustAuraList(list, previouslyObserved)
    local complete = true
    for index = 1, #list do
      local match = MatchLustAura(list[index], previouslyObserved)
      if match == "found" then
        return "found"
      elseif match == "undecided" then
        return nil
      elseif match == nil then
        complete = false
      end
    end
    return complete and "absent" or nil
  end

  local function ReadLustAurasByIndex(readAura, previouslyObserved)
    local complete = true
    for index = 1, 40 do
      local ok, aura = pcall(readAura, "player", index, "HARMFUL")
      if ok and not IsSecretValue(aura) and aura == nil then
        return complete and "absent" or nil
      end
      local match = ok and MatchLustAura(aura, previouslyObserved) or nil
      if match == "found" then
        return "found"
      elseif match == "undecided" then
        return nil
      elseif match == nil then
        complete = false
      end
    end
    return nil
  end

  local function ReadLustAuras(api, previouslyObserved)
    local getPlayerAura = rawget(api, "GetPlayerAuraBySpellID")
    if type(getPlayerAura) == "function" then
      local complete = true
      for _, record in ipairs(SpellManifest.lustSated) do
        local ok, aura = pcall(getPlayerAura, record.id)
        if not ok or IsSecretValue(aura) then
          complete = false
        elseif aura ~= nil then
          local match = MatchLustAura(aura, previouslyObserved)
          if match == "found" then
            return "found"
          end
          complete = false
        end
      end
      if complete then
        return "absent"
      end
    end
    local getUnitAuras = rawget(api, "GetUnitAuras")
    if type(getUnitAuras) == "function" then
      local ok, list = pcall(getUnitAuras, "player", "HARMFUL")
      if ok and not IsSecretValue(list) and type(list) == "table" then
        return ReadLustAuraList(list, previouslyObserved)
      end
    end
    local readAura = rawget(api, "GetAuraDataByIndex")
    if type(readAura) == "function" then
      return ReadLustAurasByIndex(readAura, previouslyObserved)
    end
    return nil
  end

  local function ScanLust()
    local previouslyObserved = lustRemain ~= nil
    lustScanResolved = false
    lustRemain, lustDuration, lustIcon = nil, nil, nil
    local api = rawget(_G, "C_UnitAuras")
    if type(api) ~= "table" then
      return
    end
    local result = ReadLustAuras(api, previouslyObserved)
    if result ~= nil then
      lustScanResolved = true
      lustReadyConfirmed = result == "absent"
      if result == "absent" then
        lustKnownExpiry = nil
      end
      return
    end
    -- Undecided scan: a verified expiry that has passed resolves it as the
    -- zero tick of the observed timer (the ready transition) ...
    if lustKnownExpiry ~= nil and getTime() >= lustKnownExpiry then
      lustKnownExpiry = nil
      lustReadyConfirmed = true
      lustScanResolved = true
      lustRemain = 0
      return
    end
    -- ... and an already confirmed ready state stays ready.
    if lustReadyConfirmed then
      lustScanResolved = true
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
    lustKnownExpiry = nil
    lustReadyConfirmed = false
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
