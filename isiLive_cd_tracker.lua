local _, addonTable = ...
addonTable = addonTable or {}

local CdTracker = {}
addonTable.CdTracker = CdTracker

local BRES_SPELL_ID = 20484

-- All Bloodlust / Heroism / Time Warp variant spell IDs that inflict Sated/Exhaustion
local LUST_SATED_IDS = {
  [2825]   = true, [32182]  = true, [80353]  = true, [264667] = true, [390386] = true,
  [381301] = true, [178207] = true, [230935] = true, [256740] = true, [57723]  = true,
  [57724]  = true, [80354]  = true, [264689] = true, [390435] = true, [95809]  = true,
  [16045]  = true,
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
    local getBySpellID = type(C_UnitAuras_ref) == "table"
      and rawget(C_UnitAuras_ref, "GetPlayerAuraBySpellID") or nil
    if type(getBySpellID) ~= "function" then
      lustRemain = nil
      lustIcon = nil
      return
    end
    -- Query each known lust spell ID directly — avoids using tainted aura.spellId as table index.
    local found = false
    for spellId in pairs(LUST_SATED_IDS) do
      local ok, aura = pcall(getBySpellID, spellId)
      if ok and type(aura) == "table" then
        local expiry = rawget(aura, "expirationTime")
        local remain = type(expiry) == "number" and math.max(0, expiry - getTime()) or 0
        lustRemain = remain > 0 and remain or nil
        lustIcon = rawget(aura, "icon")
        found = true
        break
      end
    end
    if not found then
      lustRemain = nil
      lustIcon = nil
    end
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

  return controller
end
