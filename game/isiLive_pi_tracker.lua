local _, addonTable = ...
addonTable = addonTable or {}

local PiTracker = {}
addonTable.PiTracker = PiTracker
local IsSecretValue = addonTable.Validators.IsSecretValue
local IsSecretField = addonTable.Validators.IsSecretField
local ReadPlainField = addonTable.Validators.ReadPlainField
local ReadPlainBoolean = addonTable.Validators.ReadPlainBoolean
local ReadPlainNumber = addonTable.Validators.ReadPlainNumber
local ReadPlainString = addonTable.Validators.ReadPlainString

local POWER_INFUSION_SPELL_ID = 10060
local DEDUP_WINDOW_SECONDS = 30

-- Every delta list WoW can put into a UNIT_AURA payload. A full update arrives
-- without any of them; every incremental update carries at least one. See
-- ResolveFullUpdate below for why the shape matters.
local UNIT_AURA_DELTA_KEYS = {
  "addedAuras",
  "updatedAuraInstanceIDs",
  "removedAuraInstanceIDs",
  "removedAuras",
}

local TRACKED_UNITS = {
  player = true,
  party1 = true,
  party2 = true,
  party3 = true,
  party4 = true,
}

local function DefaultGetTime()
  local fn = rawget(_G, "GetTime")
  return type(fn) == "function" and fn() or 0
end

-- Asks Blizzard directly whether the player currently carries a given aura.
--
-- The payload-driven path below reads `spellId` and `sourceUnit` off the aura
-- table, and WoW 12.1 masks both of those inside restricted instances -- exactly
-- where Power Infusion matters. Our guards then correctly read nil and the
-- announcement silently never happens. This lookup takes a spell id and answers
-- for the player alone, so it does not depend on any maskable payload field.
local function DefaultGetPlayerAuraBySpellID(spellID)
  local unitAuras = rawget(_G, "C_UnitAuras")
  local getPlayerAura = type(unitAuras) == "table" and rawget(unitAuras, "GetPlayerAuraBySpellID") or nil
  if type(getPlayerAura) ~= "function" then
    return nil
  end
  local ok, aura = pcall(getPlayerAura, spellID)
  if ok and type(aura) == "table" then
    return aura
  end
  return nil
end

local function DefaultGetAuraDataByIndex(unit, index, filter)
  if not addonTable.Validators.IsExistingUnit(unit) then
    return nil
  end
  local unitAuras = rawget(_G, "C_UnitAuras")
  local getAuraDataByIndex = type(unitAuras) == "table" and rawget(unitAuras, "GetAuraDataByIndex") or nil
  if type(getAuraDataByIndex) ~= "function" then
    return nil
  end
  local ok, aura = pcall(getAuraDataByIndex, unit, index, filter)
  if ok and type(aura) == "table" then
    return aura
  end
  return nil
end

local function DefaultGetUnitName(unit)
  if not addonTable.Validators.IsExistingUnit(unit) then
    return nil
  end
  local getUnitNameFn = rawget(_G, "GetUnitName")
  if type(getUnitNameFn) == "function" then
    local ok, name = pcall(getUnitNameFn, unit, true)
    if ok and not IsSecretValue(name) and type(name) == "string" and name ~= "" then
      return name
    end
  end
  local unitNameFn = rawget(_G, "UnitName")
  if type(unitNameFn) == "function" then
    local ok, name = pcall(unitNameFn, unit)
    if ok and not IsSecretValue(name) and type(name) == "string" and name ~= "" then
      return name
    end
  end
  return nil
end

local function DefaultGetUnitClassToken(unit)
  if not addonTable.Validators.IsExistingUnit(unit) then
    return nil
  end
  local unitClass = rawget(_G, "UnitClass")
  if type(unitClass) ~= "function" then
    return nil
  end
  local ok, _, classToken = pcall(unitClass, unit)
  if ok and not IsSecretValue(classToken) and type(classToken) == "string" and classToken ~= "" then
    return classToken
  end
  return nil
end

local function ReadSpellID(aura)
  return ReadPlainNumber(aura, "spellId")
end

local function ReadAuraInstanceID(aura)
  -- The masked check already happened inside ReadPlainField, so type() can be
  -- trusted from here on and tostring() cannot hit a Secret Value.
  local auraInstanceID = ReadPlainField(aura, "auraInstanceID")
  if type(auraInstanceID) == "number" or type(auraInstanceID) == "string" then
    return tostring(auraInstanceID)
  end
  return nil
end

local function ReadSourceUnit(aura)
  local sourceUnit = ReadPlainString(aura, "sourceUnit")
  if sourceUnit == nil or sourceUnit == "" then
    return nil
  end
  return sourceUnit
end

--- Answers whether a UNIT_AURA payload asks for a full re-scan.
---
--- WoW 12.1 masks `isFullUpdate` as a Secret Value inside restricted instances
--- (M+ / boss encounters) -- exactly where isiLive runs. Comparing the masked
--- flag raises "attempt to compare field 'isFullUpdate' (a secret boolean
--- value)", which killed the whole UNIT_AURA dispatch and spammed the chat with
--- one dispatch-error line per event.
---
--- When the flag is masked the SHAPE of the payload carries the same
--- information: WoW sends a bare table for a full update and always attaches at
--- least one delta list to an incremental one. Deriving it structurally keeps
--- the /reload + zone-transition resync alive without ever touching the masked
--- value, and without falling back to "scan on every event" -- which would mean
--- a 40-slot scan per tracked unit many times per second in precisely the
--- instances where the flag is masked.
---
--- A flag that is genuinely ABSENT is not the same as a masked one and keeps
--- the pre-12.1 answer (no full update). Only a present-but-unreadable flag
--- triggers the structural inference.
--- @param unitAuraUpdateInfo table|nil
--- @return boolean
local function ResolveFullUpdate(unitAuraUpdateInfo)
  if type(unitAuraUpdateInfo) ~= "table" then
    return true
  end
  local isFullUpdate = ReadPlainBoolean(unitAuraUpdateInfo, "isFullUpdate")
  if isFullUpdate ~= nil then
    return isFullUpdate
  end
  if not IsSecretField(unitAuraUpdateInfo, "isFullUpdate") then
    return false
  end
  for index = 1, #UNIT_AURA_DELTA_KEYS do
    if type(ReadPlainField(unitAuraUpdateInfo, UNIT_AURA_DELTA_KEYS[index])) == "table" then
      return false
    end
  end
  return true
end

local function DefaultSpellIDMatches(spellID, expectedSpellID)
  if type(spellID) ~= "number" then
    return false
  end
  local ok, matches = pcall(function()
    return spellID == expectedSpellID
  end)
  return ok and matches == true
end

function PiTracker.CreateController(opts)
  opts = opts or {}
  local getTime = type(opts.getTime) == "function" and opts.getTime or DefaultGetTime
  local getAuraDataByIndex = type(opts.getAuraDataByIndex) == "function" and opts.getAuraDataByIndex
    or DefaultGetAuraDataByIndex
  local getUnitName = type(opts.getUnitName) == "function" and opts.getUnitName or DefaultGetUnitName
  local getUnitClassToken = type(opts.getUnitClassToken) == "function" and opts.getUnitClassToken
    or DefaultGetUnitClassToken
  local spellIDMatches = type(opts.spellIDMatches) == "function" and opts.spellIDMatches or DefaultSpellIDMatches
  local announcePowerInfusion = type(opts.announcePowerInfusion) == "function" and opts.announcePowerInfusion
    or function(_casterName, _recipientName, _isLocalRecipient, _isLocalCaster) end
  local getPlayerAuraBySpellID = type(opts.getPlayerAuraBySpellID) == "function" and opts.getPlayerAuraBySpellID
    or DefaultGetPlayerAuraBySpellID

  local recent = {}
  -- Latch for the self-receive path below: true while we have already announced
  -- the buff we can currently see on the player.
  local selfPowerInfusionAnnounced = false

  local controller = {}

  local function Sweep(now)
    for key, when in pairs(recent) do
      if type(when) ~= "number" or (now - when) >= DEDUP_WINDOW_SECONDS then
        recent[key] = nil
      end
    end
  end

  local function BuildDedupKey(unit, aura)
    return unit .. "|" .. (ReadSourceUnit(aura) or "") .. "|" .. (ReadAuraInstanceID(aura) or POWER_INFUSION_SPELL_ID)
  end

  local function ResolveVerifiedUnitName(unit)
    local name = getUnitName(unit)
    if type(name) == "string" and name ~= "" and name ~= unit then
      return name
    end
    return nil
  end

  local function AnnounceIfFresh(unit, aura)
    -- The self-receive path may already have announced this very buff; it shares
    -- the latch so the player never gets the message twice when both paths see
    -- the same aura.
    if unit == "player" and selfPowerInfusionAnnounced then
      return false
    end
    local ok, isPowerInfusion = pcall(spellIDMatches, ReadSpellID(aura), POWER_INFUSION_SPELL_ID)
    if not ok or isPowerInfusion ~= true then
      return false
    end
    local sourceUnit = ReadSourceUnit(aura)
    if not sourceUnit or getUnitClassToken(sourceUnit) ~= "PRIEST" then
      return false
    end
    local casterName = ResolveVerifiedUnitName(sourceUnit)
    local recipientName = ResolveVerifiedUnitName(unit)
    if not casterName or not recipientName then
      return false
    end
    local now = getTime()
    Sweep(now)
    local key = BuildDedupKey(unit, aura)
    local last = recent[key]
    if type(last) == "number" and (now - last) < DEDUP_WINDOW_SECONDS then
      return false
    end
    recent[key] = now
    if unit == "player" then
      selfPowerInfusionAnnounced = true
    end
    announcePowerInfusion(casterName, recipientName, unit == "player", sourceUnit == "player")
    return true
  end

  local function ScanUnit(unit)
    for index = 1, 40 do
      local aura = getAuraDataByIndex(unit, index, "HELPFUL")
      if type(aura) == "table" and AnnounceIfFresh(unit, aura) then
        return true
      end
    end
    return false
  end

  local function CheckAddedAuras(unit, unitAuraUpdateInfo)
    local addedAuras = ReadPlainField(unitAuraUpdateInfo, "addedAuras")
    if type(addedAuras) ~= "table" then
      return false
    end
    local announced = false
    for _, aura in ipairs(addedAuras) do
      if AnnounceIfFresh(unit, aura) then
        announced = true
      end
    end
    return announced
  end

  -- Second, independent path: does the player carry Power Infusion right now?
  --
  -- The payload path above needs a readable spellId AND a readable sourceUnit
  -- whose owner resolves to a priest with a real name. Any one of those coming
  -- back masked takes the whole announcement down without a trace, and 12.1
  -- masks the aura fields precisely inside instances. This asks Blizzard for the
  -- player's own buff by spell id instead, which no payload masking can hide.
  --
  -- The caster stays unknown here -- sourceUnit is the very field that may be
  -- gone. Rather than invent a name, the announcement goes out without one; the
  -- on-screen alert and the sound, which is what the player reacts to, need no
  -- caster at all.
  local function CheckSelfPowerInfusion()
    local aura = getPlayerAuraBySpellID(POWER_INFUSION_SPELL_ID)
    if type(aura) ~= "table" then
      selfPowerInfusionAnnounced = false
      return false
    end
    if selfPowerInfusionAnnounced then
      return false
    end
    selfPowerInfusionAnnounced = true

    local casterName = nil
    local sourceUnit = ReadSourceUnit(aura)
    if sourceUnit and getUnitClassToken(sourceUnit) == "PRIEST" then
      casterName = ResolveVerifiedUnitName(sourceUnit)
    end
    announcePowerInfusion(casterName, ResolveVerifiedUnitName("player"), true, false)
    return true
  end

  function controller.HandleUnitAura(unit, unitAuraUpdateInfo)
    if not TRACKED_UNITS[unit] then
      return false
    end
    local announcedSelf = false
    if unit == "player" then
      announcedSelf = CheckSelfPowerInfusion()
    end
    if CheckAddedAuras(unit, unitAuraUpdateInfo) then
      return true
    end
    if ResolveFullUpdate(unitAuraUpdateInfo) then
      return ScanUnit(unit) or announcedSelf
    end
    return announcedSelf
  end

  function controller.Reset()
    recent = {}
    selfPowerInfusionAnnounced = false
  end

  function controller._Test_GetRecentSize()
    local n = 0
    for _ in pairs(recent) do
      n = n + 1
    end
    return n
  end

  return controller
end

local controllerInstance = nil

function PiTracker.SetDependencies(deps)
  if type(deps) ~= "table" then
    return
  end
  controllerInstance = PiTracker.CreateController(deps)
end

function PiTracker.HandleEvent(event, ...)
  if not controllerInstance then
    return
  end
  if event == "UNIT_AURA" then
    controllerInstance.HandleUnitAura(...)
    return
  end
  if event == "GROUP_ROSTER_UPDATE" or event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
    controllerInstance.Reset()
  end
end
