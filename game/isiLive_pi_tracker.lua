local _, addonTable = ...
addonTable = addonTable or {}

local PiTracker = {}
addonTable.PiTracker = PiTracker

local POWER_INFUSION_SPELL_ID = 10060
local DEDUP_WINDOW_SECONDS = 30

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

local function DefaultGetAuraDataByIndex(unit, index, filter)
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
  local getUnitNameFn = rawget(_G, "GetUnitName")
  if type(getUnitNameFn) == "function" then
    local ok, name = pcall(getUnitNameFn, unit, true)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end
  local unitNameFn = rawget(_G, "UnitName")
  if type(unitNameFn) == "function" then
    local ok, name = pcall(unitNameFn, unit)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end
  return nil
end

local function DefaultGetUnitClassToken(unit)
  local unitClass = rawget(_G, "UnitClass")
  if type(unitClass) ~= "function" then
    return nil
  end
  local ok, _, classToken = pcall(unitClass, unit)
  if ok and type(classToken) == "string" and classToken ~= "" then
    return classToken
  end
  return nil
end

local function ReadSpellID(aura)
  if type(aura) ~= "table" then
    return nil
  end
  local spellID = nil
  pcall(function()
    spellID = rawget(aura, "spellId")
  end)
  return type(spellID) == "number" and spellID or nil
end

local function ReadAuraInstanceID(aura)
  if type(aura) ~= "table" then
    return nil
  end
  local auraInstanceID = nil
  pcall(function()
    auraInstanceID = rawget(aura, "auraInstanceID")
  end)
  if type(auraInstanceID) == "number" or type(auraInstanceID) == "string" then
    return tostring(auraInstanceID)
  end
  return nil
end

local function ReadSourceUnit(aura)
  if type(aura) ~= "table" then
    return nil
  end
  local sourceUnit = nil
  pcall(function()
    sourceUnit = rawget(aura, "sourceUnit")
  end)
  return type(sourceUnit) == "string" and sourceUnit ~= "" and sourceUnit or nil
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
    or function(_casterName, _recipientName, _isLocalRecipient) end

  local recent = {}

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
    local addedAuras = type(unitAuraUpdateInfo) == "table" and rawget(unitAuraUpdateInfo, "addedAuras") or nil
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

  function controller.HandleUnitAura(unit, unitAuraUpdateInfo)
    if not TRACKED_UNITS[unit] then
      return false
    end
    if CheckAddedAuras(unit, unitAuraUpdateInfo) then
      return true
    end
    if type(unitAuraUpdateInfo) ~= "table" or unitAuraUpdateInfo.isFullUpdate == true then
      return ScanUnit(unit)
    end
    return false
  end

  function controller.Reset()
    recent = {}
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
