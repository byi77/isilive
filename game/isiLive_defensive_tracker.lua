local _, addonTable = ...

addonTable = addonTable or {}

-- Own defensive / external cooldowns (rule 267, vorhaben V1 stage 1).
--
-- Reads the local player's state from the live client only:
--   * which manifest spells (data/isiLive_defensives.lua) the player knows:
--     class from UnitClass, then C_SpellBook.IsSpellKnown (fallback global
--     IsPlayerSpell) per cast ID; resolved again on spell or spec changes
--   * per known spell the cooldown (C_Spell.GetSpellCooldown, fallback the
--     duration object of C_Spell.GetSpellCooldownDuration) or, for spells with
--     more than one charge, C_Spell.GetSpellCharges
--   * whether the own buff runs (C_UnitAuras.GetPlayerAuraBySpellID on the
--     manifest aura, cast by the player or the pet)
-- C_Secrets.ShouldSpellCooldownBeSecret gates every cooldown number. A
-- masked cooldown (every key) still has a state: isActive, isEnabled and
-- isOnGCD of SpellCooldownInfo are NeverSecret. Such an entry is `hidden`:
-- ready or cooldown without a number, which the cell lets Blizzard draw from
-- the duration object. Without those fields the spell is left out
-- (fail-closed): no estimate, no last value. A secret aura answer only drops
-- the "active" detail.
-- ReadEntries also says whether the list is complete: every known spell read
-- with its numbers. Only a complete list may go out as DEF.
-- Own casts (UNIT_SPELLCAST_SUCCEEDED player/pet) are matched against the
-- manifest to trigger an immediate re-read; the secret check runs first.
local DefensiveTracker = {}
addonTable.DefensiveTracker = DefensiveTracker

local Validators = addonTable.Validators
local IsSecretValue = Validators.IsSecretValue
local ReadPlainNumber = Validators.ReadPlainNumber
local ReadPlainBoolean = Validators.ReadPlainBoolean
local ReadPlainString = Validators.ReadPlainString

-- Cooldowns at or below this are the global cooldown, not the spell's own.
local GCD_MAX_SECONDS = 2
local MAX_REMAIN_SECONDS = 3600
local MAX_CHARGES = 9

local function Manifest()
  local manifest = addonTable.DefensiveManifest
  return type(manifest) == "table" and type(manifest.spells) == "table" and manifest or nil
end

local function ResolveFunction(namespace, name)
  local root = namespace and rawget(_G, namespace) or _G
  if type(root) ~= "table" then
    return nil
  end
  local fn = rawget(root, name)
  return type(fn) == "function" and fn or nil
end

-- Calls `fn` under pcall; nil when it fails or answers a secret value.
local function CallPlain(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, result = pcall(fn, ...)
  if not ok or IsSecretValue(result) then
    return nil
  end
  return result
end

local function ReadPlayerClass()
  local unitClass = ResolveFunction(nil, "UnitClass")
  if not unitClass then
    return nil
  end
  local ok, _, classToken = pcall(unitClass, "player")
  if not ok or IsSecretValue(classToken) or type(classToken) ~= "string" or classToken == "" then
    return nil
  end
  return classToken
end

-- True / false when the client answers plainly, nil when it cannot tell.
local function IsSpellKnownByPlayer(spellID)
  local known = CallPlain(ResolveFunction("C_SpellBook", "IsSpellKnown"), spellID)
  if known == true then
    return true
  end
  local isPlayerSpell = CallPlain(ResolveFunction(nil, "IsPlayerSpell"), spellID)
  if isPlayerSpell == true then
    return true
  end
  if known == false or isPlayerSpell == false then
    return false
  end
  return nil
end

-- True when the client says this spell's cooldown is secret right now, or
-- answers the question itself with a secret value (fail-closed).
local function IsCooldownSecret(spellID)
  local predicate = ResolveFunction("C_Secrets", "ShouldSpellCooldownBeSecret")
  if not predicate then
    return false
  end
  local ok, secret = pcall(predicate, spellID)
  if not ok or IsSecretValue(secret) then
    return true
  end
  return secret == true
end

local function ClampRemain(remain)
  if remain <= 0 then
    return 0
  end
  return remain
end

-- Charge-based spells (GetSpellCharges answers only for those). Returns
-- state, remain, charges (only with more than one charge), isCharged.
local function ReadCharges(spellID, now)
  local info = CallPlain(ResolveFunction("C_Spell", "GetSpellCharges"), spellID)
  if type(info) ~= "table" then
    return nil, nil, nil, false
  end
  local maxCharges = ReadPlainNumber(info, "maxCharges")
  if not maxCharges or maxCharges < 1 then
    return nil, nil, nil, false
  end
  local current = ReadPlainNumber(info, "currentCharges")
  local start = ReadPlainNumber(info, "cooldownStartTime")
  local duration = ReadPlainNumber(info, "cooldownDuration")
  if not current or not start or not duration or current < 0 or current > MAX_CHARGES or current % 1 ~= 0 then
    return nil, nil, nil, true
  end
  local recharging = current < maxCharges and start > 0 and duration > GCD_MAX_SECONDS
  local remain = recharging and ClampRemain(start + duration - now) or 0
  local charges = maxCharges > 1 and current or nil
  if current > 0 then
    return "ready", remain, charges, true
  end
  if remain <= 0 then
    return nil, nil, nil, true
  end
  return "cd", remain, charges, true
end

-- Duration-object fallback when C_Spell.GetSpellCooldown is missing.
local function ReadCooldownDuration(spellID)
  local duration = CallPlain(ResolveFunction("C_Spell", "GetSpellCooldownDuration"), spellID, true)
  if duration == nil then
    return nil
  end
  local hasSecrets = duration.HasSecretValues
  if type(hasSecrets) ~= "function" then
    return nil
  end
  local okSecret, secret = pcall(hasSecrets, duration)
  if not okSecret or IsSecretValue(secret) or secret ~= false then
    return nil
  end
  local getRemaining = duration.GetRemainingDuration
  if type(getRemaining) ~= "function" then
    return nil
  end
  local okRemain, remain = pcall(getRemaining, duration)
  if not okRemain or not Validators.IsFiniteNumber(remain) or remain < 0 then
    return nil
  end
  if remain <= GCD_MAX_SECONDS then
    return "ready", 0
  end
  return "cd", remain
end

-- Single-charge spells. Returns state, remain or nil.
local function ReadCooldown(spellID, now)
  local getCooldown = ResolveFunction("C_Spell", "GetSpellCooldown")
  if not getCooldown then
    return ReadCooldownDuration(spellID)
  end
  local info = CallPlain(getCooldown, spellID)
  if type(info) ~= "table" then
    return nil
  end
  local start = ReadPlainNumber(info, "startTime")
  local duration = ReadPlainNumber(info, "duration")
  local enabled = ReadPlainBoolean(info, "isEnabled")
  if not start or not duration or enabled == nil then
    return nil
  end
  if enabled == false then
    -- On hold until an active effect ends: the remain is not known yet.
    return nil
  end
  if start <= 0 or duration <= GCD_MAX_SECONDS then
    return "ready", 0
  end
  local remain = start + duration - now
  if remain <= 0 then
    return "ready", 0
  end
  return "cd", remain
end

-- True when the own buff of the spell runs and the player (or the pet) cast
-- it. A secret or unreadable answer is no "active".
local function IsOwnAuraActive(auraID)
  local aura = CallPlain(ResolveFunction("C_UnitAuras", "GetPlayerAuraBySpellID"), auraID)
  if type(aura) ~= "table" then
    return false
  end
  local source = ReadPlainString(aura, "sourceUnit")
  return source == "player" or source == "pet"
end

local function IsMaskedField(info, field)
  if type(info) ~= "table" then
    return false
  end
  local ok, masked = pcall(function()
    return IsSecretValue(info[field])
  end)
  return not ok or masked
end

-- The state of a masked cooldown from its NeverSecret fields, or nil. A
-- running global cooldown is no cooldown of the spell; an on-hold cooldown
-- (isEnabled false) is one. For charges the spell's cooldown only runs with
-- no charge left.
local function ReadHiddenState(info)
  if type(info) ~= "table" then
    return nil
  end
  local enabled = ReadPlainBoolean(info, "isEnabled")
  if enabled == false then
    return "cd"
  end
  local active = ReadPlainBoolean(info, "isActive")
  if enabled == nil or active == nil then
    return nil
  end
  if active and ReadPlainBoolean(info, "isOnGCD") ~= true then
    return "cd"
  end
  return "ready"
end

local function IsNumberMasked(spellID, info)
  if IsCooldownSecret(spellID) or IsMaskedField(info, "startTime") or IsMaskedField(info, "duration") then
    return true
  end
  local charges = CallPlain(ResolveFunction("C_Spell", "GetSpellCharges"), spellID)
  return IsMaskedField(charges, "currentCharges") or IsMaskedField(charges, "cooldownStartTime")
end

--- Reads one known spell. Returns the entry or nil (fail-closed).
local function ReadSpellState(spellID, record, now)
  local info = CallPlain(ResolveFunction("C_Spell", "GetSpellCooldown"), spellID)
  if IsNumberMasked(spellID, info) then
    local state = ReadHiddenState(info)
    if state == nil then
      return nil
    end
    if IsOwnAuraActive(record.aura) then
      state = "active"
    end
    return { spellID = spellID, kind = record.kind, state = state, remain = 0, hidden = true }
  end
  local state, remain, charges, isCharged = ReadCharges(spellID, now)
  if not isCharged then
    state, remain = ReadCooldown(spellID, now)
  end
  if state == nil or not Validators.IsFiniteNumber(remain) or remain > MAX_REMAIN_SECONDS then
    return nil
  end
  if IsOwnAuraActive(record.aura) then
    state = "active"
  end
  return { spellID = spellID, kind = record.kind, state = state, remain = remain, charges = charges }
end

--- Creates the own-state controller.
-- @param opts table|nil { getTime = function }
function DefensiveTracker.CreateController(opts)
  opts = opts or {}
  local getTime = type(opts.getTime) == "function" and opts.getTime or rawget(_G, "GetTime")
  local controller = {}
  local knownSpells = nil -- sorted cast IDs, nil until resolved
  local allAnswered = false -- every spellbook question had a plain answer

  --- Resolves which manifest spells the player knows. Returns the count, or
  -- nil when the class cannot be read (then nothing is tracked).
  function controller.ResolveKnownSpells()
    local manifest = Manifest()
    local classToken = ReadPlayerClass()
    if not manifest or not classToken then
      knownSpells = nil
      allAnswered = false
      return nil
    end
    local list, answered = {}, true
    for spellID, record in pairs(manifest.spells) do
      if record.class == classToken then
        local known = IsSpellKnownByPlayer(spellID)
        if known == true then
          list[#list + 1] = spellID
        elseif known == nil then
          answered = false
        end
      end
    end
    table.sort(list)
    knownSpells, allAnswered = list, answered
    return #list
  end

  --- Own cast from UNIT_SPELLCAST_SUCCEEDED. Returns true for a tracked
  -- manifest spell of the player or the pet.
  function controller.OnCast(unit, spellID)
    if IsSecretValue(unit) or IsSecretValue(spellID) then
      return false
    end
    if unit ~= "player" and unit ~= "pet" then
      return false
    end
    local manifest = Manifest()
    return manifest ~= nil and type(spellID) == "number" and manifest.spells[spellID] ~= nil
  end

  --- The own entries at `now` (defaults to GetTime()), read from the client,
  -- and whether they are complete: the spellbook answered and every known
  -- spell has plain numbers. An empty list is complete only without known
  -- spells.
  function controller.ReadEntries(now)
    now = now or (type(getTime) == "function" and getTime() or nil)
    local manifest = Manifest()
    if not Validators.IsFiniteNumber(now) or not manifest then
      return {}, false
    end
    if knownSpells == nil or not allAnswered then
      controller.ResolveKnownSpells()
    end
    local entries = {}
    local complete = knownSpells ~= nil and allAnswered
    for _, spellID in ipairs(knownSpells or {}) do
      local entry = ReadSpellState(spellID, manifest.spells[spellID], now)
      if entry then
        entries[#entries + 1] = entry
      end
      if not entry or entry.hidden then
        complete = false
      end
    end
    return entries, complete
  end

  --- Cast IDs the player knows (copy), or an empty list before resolution.
  function controller.GetKnownSpellIDs()
    local out = {}
    for index, spellID in ipairs(knownSpells or {}) do
      out[index] = spellID
    end
    return out
  end

  function controller.Reset()
    knownSpells = nil
    allAnswered = false
  end

  return controller
end
