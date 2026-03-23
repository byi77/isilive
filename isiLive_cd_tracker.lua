local _, addonTable = ...
addonTable = addonTable or {}

local CdTracker = {}
addonTable.CdTracker = CdTracker

local BRES_SPELL_ID = 20484
local CONTINUED_LUST_EXPIRY_TOLERANCE_SECONDS = 3

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
  local lastKnownLustExpiration = nil
  local continuedLustExpectedExpiration = nil
  -- True when lust was already active at the moment SuppressOnset was called.
  -- Used as a fallback when lastKnownLustExpiration is nil (lust known only via
  -- NotifySpellCast) so that the aura re-appearing after a zone transition is
  -- still recognised as a continuation rather than a new onset.
  local lustWasActiveWhenSuppressed = false
  -- Gate that blocks onLustStart until SuppressOnset has been called at least once.
  -- Mirrors BResLustTracker's isInitialized flag: prevents any scan that fires before
  -- PLAYER_ENTERING_WORLD (ticker, early UNIT_AURA) from triggering the sound.
  -- skipReadyGate = true bypasses this for unit tests that exercise onset directly.
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

  local function ScanLust()
    local C_UnitAuras_ref = rawget(_G, "C_UnitAuras")
    local getAuraDataByIndex = type(C_UnitAuras_ref) == "table" and rawget(C_UnitAuras_ref, "GetAuraDataByIndex") or nil
    if type(getAuraDataByIndex) ~= "function" then
      lustRemain = nil
      lustIcon = nil
      return
    end
    -- Query each known lust spell ID directly — avoids using tainted aura.spellId as table index.
    local found = false
    local detectedExpiry = nil
    for index = 1, 40 do
      local ok, aura = pcall(getAuraDataByIndex, "player", index, "HARMFUL")
      if ok and type(aura) == "table" then
        local spellId = rawget(aura, "spellId")
        -- spellId may be tainted ("secret") in the WoW secure environment;
        -- wrap the table lookup in pcall to avoid "table index is secret" errors.
        local isLustAura = false
        if spellId ~= nil then
          local ok2, result = pcall(function()
            return LUST_SATED_IDS[spellId]
          end)
          isLustAura = ok2 and result == true
        end
        if isLustAura then
          local expiry = rawget(aura, "expirationTime")
          local remain = type(expiry) == "number" and math.max(0, expiry - getTime()) or 0
          lustRemain = remain > 0 and remain or nil
          lustIcon = rawget(aura, "icon")
          detectedExpiry = type(expiry) == "number" and expiry or nil
          found = true
          break
        end
      end
    end
    if not found then
      lustRemain = nil
      lustIcon = nil
      if type(lastKnownLustExpiration) == "number" and lastKnownLustExpiration <= getTime() then
        lastKnownLustExpiration = nil
      end
      if
        type(continuedLustExpectedExpiration) == "number"
        and continuedLustExpectedExpiration + CONTINUED_LUST_EXPIRY_TOLERANCE_SECONDS <= getTime()
      then
        continuedLustExpectedExpiration = nil
      end
    elseif type(detectedExpiry) == "number" then
      lastKnownLustExpiration = detectedExpiry
    end
    local isLustNowActive = lustRemain ~= nil
    if not wasLustActive and isLustNowActive then
      local isContinuedLust = (
        type(detectedExpiry) == "number"
        and type(continuedLustExpectedExpiration) == "number"
        and math.abs(detectedExpiry - continuedLustExpectedExpiration) <= CONTINUED_LUST_EXPIRY_TOLERANCE_SECONDS
      )
        or (lustWasActiveWhenSuppressed and getTime() <= suppressOnsetUntil + CONTINUED_LUST_EXPIRY_TOLERANCE_SECONDS)

      if not isContinuedLust and ready and onLustStart and getTime() >= suppressOnsetUntil then
        onLustStart()
        -- Genuine new onset: clear continuation tracking.
        continuedLustExpectedExpiration = nil
        lustWasActiveWhenSuppressed = false
      else
        -- Suppressed or recognised as continuation.  Keep continuedLustExpectedExpiration
        -- up to date so a subsequent brief removal + re-appearance of the SAME aura is
        -- still recognised as a continuation (fixes the case where the first suppressed
        -- transition would otherwise clear the value and leave later scans unprotected).
        if type(detectedExpiry) == "number" then
          continuedLustExpectedExpiration = detectedExpiry
        end
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

  function controller.Scan()
    ScanBRes()
    ScanLust()
  end

  -- Suppress lust onset callback for the given number of seconds.
  -- Call this after zone changes / reloads to avoid false positives
  -- from auras temporarily disappearing and reappearing.
  -- Performs an immediate ScanLust() with the suppress window already active so that
  -- lastKnownLustExpiration is populated before continuedLustExpectedExpiration is seeded —
  -- this covers the reload case where lastKnownLustExpiration is nil but the Sated aura
  -- is already present in the client before PLAYER_ENTERING_WORLD fires.
  function controller.SuppressOnset(seconds)
    ready = true
    suppressOnsetUntil = getTime() + (seconds or 3)
    -- Capture the pre-scan flag, then scan.  On reload lastKnownLustExpiration is nil;
    -- scanning here populates it so continuedLustExpectedExpiration is seeded correctly.
    -- wasActiveBeforeScan catches the case where the aura was active before the zone
    -- transition but UNIT_AURA removal fired (dropping wasLustActive to false) before
    -- PLAYER_ENTERING_WORLD; wasLustActive after the scan catches the case where the
    -- aura is already present when SuppressOnset runs (fresh reload).
    local wasActiveBeforeScan = wasLustActive
    ScanLust()
    lustWasActiveWhenSuppressed = wasActiveBeforeScan or wasLustActive
    if type(lastKnownLustExpiration) == "number" and lastKnownLustExpiration > getTime() then
      continuedLustExpectedExpiration = lastKnownLustExpiration
    else
      continuedLustExpectedExpiration = nil
    end
  end

  -- Notify the tracker that a spell was cast (UNIT_SPELLCAST_SUCCEEDED).
  -- Fires onLustStart immediately for lust spell IDs, bypassing the suppress
  -- window — an actual spell cast is never a zone-change artefact.
  -- Sets wasLustActive so the aura-scan path does not fire a duplicate onset.
  function controller.NotifySpellCast(spellId)
    if not LUST_SATED_IDS[spellId] then
      return
    end
    continuedLustExpectedExpiration = nil
    lustWasActiveWhenSuppressed = false
    if onLustStart then
      onLustStart()
    end
    wasLustActive = true
  end

  return controller
end
