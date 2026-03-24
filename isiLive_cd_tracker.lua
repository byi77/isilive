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
  local onLustStart = type(opts.onLustStart) == "function" and opts.onLustStart or nil

  local bresCharges = nil
  local bresMaxCharges = nil
  local bresCooldownRemain = nil
  local lustRemain = nil
  local lustIcon = nil
  local wasLustActive = false
  local suppressOnsetUntil = 0
  -- Gate that blocks onLustStart until SuppressOnset has been called at least once.
  -- Prevents any scan that fires before PLAYER_ENTERING_WORLD (ticker, early UNIT_AURA)
  -- from triggering the sound. skipReadyGate = true bypasses this for unit tests.
  local ready = opts.skipReadyGate == true

  local function ScanBRes()
    local C_Spell_ref = rawget(_G, "C_Spell")
    if type(C_Spell_ref) ~= "table" or type(C_Spell_ref.GetSpellCharges) ~= "function" then
      bresCharges = nil
      return
    end
    local ok, charges, maxCharges, _, chargeStart, chargeDuration = pcall(C_Spell_ref.GetSpellCharges, BRES_SPELL_ID)
    if not ok or not charges then
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

  local function ScanLust(isFullUpdate)
    local C_UnitAuras_ref = rawget(_G, "C_UnitAuras")
    local getAuraDataByIndex = type(C_UnitAuras_ref) == "table" and rawget(C_UnitAuras_ref, "GetAuraDataByIndex") or nil
    if type(getAuraDataByIndex) ~= "function" then
      lustRemain = nil
      lustIcon = nil
      return
    end
    -- Query each aura slot for a known Sated/Exhaustion debuff.
    -- rawget avoids triggering taint traps on WoW's secure aura objects.
    local found = false
    for index = 1, 40 do
      local ok, aura = pcall(getAuraDataByIndex, "player", index, "HARMFUL")
      if ok and type(aura) == "table" then
        local spellId = rawget(aura, "spellId")
        -- WoW "secret" values are truthy but cannot be used as table keys.
        -- type() safely identifies them: secret-nil returns "nil", not "number".
        if type(spellId) == "number" and LUST_SATED_IDS[spellId] then
          local expiry = rawget(aura, "expirationTime")
          local remain = type(expiry) == "number" and math.max(0, expiry - getTime()) or 0
          lustRemain = remain > 0 and remain or nil
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
    local isLustNowActive = lustRemain ~= nil
    if not wasLustActive and isLustNowActive then
      if isFullUpdate then
        -- WoW is restoring all auras after a zone change or UI reload.
        -- Mark lust as active without firing the onset callback to avoid false positives.
        wasLustActive = true
        return
      end
      if ready and onLustStart and getTime() >= suppressOnsetUntil then
        onLustStart()
      end
    end
    wasLustActive = isLustNowActive
  end

  local controller = {}

  function controller.GetBResInfo()
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
    if lustRemain == nil then
      return nil
    end
    return { remain = lustRemain, icon = lustIcon }
  end

  -- isFullUpdate: pass true when called from a UNIT_AURA event with isFullUpdate=true
  -- (zone change / UI reload aura restore). Prevents false onset callbacks.
  function controller.Scan(isFullUpdate)
    ScanBRes()
    ScanLust(isFullUpdate)
  end

  -- Suppress lust onset for the given number of seconds.
  -- Call this on PLAYER_ENTERING_WORLD as a safety net for the ticker window
  -- between the event and the first UNIT_AURA(isFullUpdate=true) arriving.
  -- Also performs an immediate full-update scan so that lust already visible
  -- on reload is captured without triggering the onset callback.
  function controller.SuppressOnset(seconds)
    ready = true
    suppressOnsetUntil = getTime() + (seconds or 2)
    ScanLust(true)
  end

  -- Notify the tracker that a spell was cast (UNIT_SPELLCAST_SUCCEEDED).
  -- Fires onLustStart immediately for lust spell IDs, bypassing the suppress
  -- window — an actual spell cast is never a zone-change artefact.
  -- Sets wasLustActive so the aura-scan path does not fire a duplicate onset.
  function controller.NotifySpellCast(spellId)
    if not LUST_SATED_IDS[spellId] then
      return
    end
    if onLustStart then
      onLustStart()
    end
    wasLustActive = true
  end

  return controller
end
