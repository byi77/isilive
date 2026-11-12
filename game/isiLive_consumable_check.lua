local _, addonTable = ...
addonTable = addonTable or {}

-- Ready-check consumable check, stage 1: display only (rule 246, K4). On a
-- ready check outside combat and outside raids the own weapon oil (main and
-- off hand, GetWeaponEnchantInfo, no ID list needed) and -- once the season
-- data in data/isiLive_consumables.lua has IDs -- food, flask and augment
-- rune (C_UnitAuras.GetPlayerAuraBySpellID) are checked. The probe key of
-- 2026-11-12 found all of it readable at a ready check in the dungeon before
-- the key start. When something is missing or ends within LOW_MINUTES, a
-- card in the shared card stack lists every checked item for CARD_SECONDS.
-- Masked or unreadable values never count as missing. Setting
-- consumableCheckEnabled (Pattern B). Own event frame, installed after every
-- window exists (FactoryEditMode.InstallLate).
local ConsumableCheck = {}
addonTable.ConsumableCheck = ConsumableCheck

local LOW_MINUTES = 10
local CARD_SECONDS = 25
local CATEGORIES = {
  { key = "food", label = "CONSUMABLE_FOOD", fallback = "Food:" },
  { key = "flask", label = "CONSUMABLE_FLASK", fallback = "Flask:" },
  { key = "augmentRune", label = "CONSUMABLE_RUNE", fallback = "Augment rune:" },
}

local IsSecretValue = addonTable.Validators.IsSecretValue

local function GetDB()
  local db = rawget(_G, "IsiLiveDB")
  return type(db) == "table" and db or nil
end

--- Pattern B: off unless the player switched it on.
function ConsumableCheck.IsEnabled()
  local db = GetDB()
  return db ~= nil and db.consumableCheckEnabled == true
end

local function Plain(value)
  if IsSecretValue(value) then
    return nil
  end
  return value
end

-- "ok" / "low" / "missing" with minutes left, or nil when unreadable.
local function Judge(has, minutes)
  if has == nil then
    return nil
  end
  if not has then
    return { status = "missing" }
  end
  if type(minutes) == "number" and minutes < LOW_MINUTES then
    return { status = "low", minutes = minutes }
  end
  return { status = "ok", minutes = minutes }
end

local function ReadWeapons()
  local getInfo = rawget(_G, "GetWeaponEnchantInfo")
  if type(getInfo) ~= "function" then
    return nil, nil
  end
  local ok, hasMain, mainMs, _, _, hasOff, offMs = pcall(getInfo)
  if not ok then
    return nil, nil
  end
  local function Slot(has, ms)
    has = Plain(has)
    ms = Plain(ms)
    if has == nil then
      return nil
    end
    local minutes = type(ms) == "number" and math.floor(ms / 60000) or nil
    return Judge(has == true or has == 1, minutes)
  end
  local main = Slot(hasMain, mainMs)
  -- The off hand is only judged when it carries an enchant: a shield or a
  -- held-in-off-hand item cannot take oil, so "none" is no finding there.
  local off = Plain(hasOff) and Slot(hasOff, offMs) or nil
  return main, off
end

local function ReadAuraList(ids)
  local unitAuras = rawget(_G, "C_UnitAuras")
  local bySpell = type(unitAuras) == "table" and unitAuras.GetPlayerAuraBySpellID or nil
  if type(bySpell) ~= "function" or type(ids) ~= "table" or #ids == 0 then
    return nil
  end
  local getTime = rawget(_G, "GetTime")
  local now = type(getTime) == "function" and Plain(getTime()) or nil
  for _, id in ipairs(ids) do
    local ok, aura = pcall(bySpell, id)
    if not ok or IsSecretValue(aura) then
      return nil
    end
    if type(aura) == "table" then
      local expires = Plain(aura.expirationTime)
      local minutes = nil
      if type(expires) == "number" and expires > 0 and type(now) == "number" then
        minutes = math.floor((expires - now) / 60)
      end
      return Judge(true, minutes)
    end
  end
  return Judge(false)
end

-- Buff set of the active season (data/isiLive_consumables.lua resolves the
-- season to its expansion's set), or nil.
local function SeasonData()
  local data = addonTable.ConsumableData
  local seasonModule = addonTable.SeasonData
  local seasonID = type(seasonModule) == "table"
      and type(seasonModule.GetActiveSeasonID) == "function"
      and seasonModule.GetActiveSeasonID()
    or nil
  if type(data) ~= "table" or type(data.ResolveSet) ~= "function" then
    return nil
  end
  return data.ResolveSet(seasonID)
end

--- Checked items in display order: { labelKey, fallback, result } with
--- result.status "ok" | "low" | "missing" and result.minutes when known.
function ConsumableCheck.Evaluate()
  local rows = {}
  local main, off = ReadWeapons()
  if main then
    rows[#rows + 1] = { labelKey = "CONSUMABLE_WEAPON_MAIN", fallback = "Weapon oil (main hand):", result = main }
  end
  if off then
    rows[#rows + 1] = { labelKey = "CONSUMABLE_WEAPON_OFF", fallback = "Weapon oil (off hand):", result = off }
  end
  local season = SeasonData()
  for _, category in ipairs(CATEGORIES) do
    local result = type(season) == "table" and ReadAuraList(season[category.key]) or nil
    if result then
      rows[#rows + 1] = { labelKey = category.label, fallback = category.fallback, result = result }
    end
  end
  return rows
end

local function NeedsAttention(rows)
  for _, row in ipairs(rows) do
    if row.result.status ~= "ok" then
      return true
    end
  end
  return false
end

local function Blocked()
  local inCombat = rawget(_G, "InCombatLockdown")
  if type(inCombat) == "function" and Plain(inCombat()) == true then
    return true
  end
  local runtimeMode = addonTable.RuntimeMode
  return type(runtimeMode) == "table"
    and type(runtimeMode.IsRaidContext) == "function"
    and runtimeMode.IsRaidContext() == true
end

-- Card payload for the shared center notice (rich layout).
local function BuildCard(rows, getText)
  local fields = {}
  for _, row in ipairs(rows) do
    local status = row.result.status
    local value
    if status == "missing" then
      value = getText("CONSUMABLE_MISSING", "missing")
    else
      local minutes = row.result.minutes
      value = minutes and string.format(getText("CONSUMABLE_MINUTES_LEFT", "%d min left"), minutes)
        or getText("CONSUMABLE_OK", "active")
    end
    fields[#fields + 1] = { label = getText(row.labelKey, row.fallback), value = value, warning = status ~= "ok" }
  end
  return {
    eyebrow = getText("CONSUMABLE_CHECK_EYEBROW", "Ready check"),
    title = getText("CONSUMABLE_CHECK_TITLE", "isiLive - Consumables"),
    fields = fields,
  }
end

--- Runs the check for a ready check; shows the card when something needs
--- attention. Returns the rows when it checked, or nil.
function ConsumableCheck.OnReadyCheck(showCard, getText)
  if not ConsumableCheck.IsEnabled() or Blocked() then
    return nil
  end
  local rows = ConsumableCheck.Evaluate()
  if #rows > 0 and NeedsAttention(rows) and type(showCard) == "function" then
    showCard(BuildCard(rows, getText), CARD_SECONDS)
  end
  return rows
end

--- Event frame for READY_CHECK. opts.showCard(options, seconds),
--- opts.getText(key, fallback).
function ConsumableCheck.Install(opts)
  opts = type(opts) == "table" and opts or {}
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return nil
  end
  local getText = type(opts.getText) == "function" and opts.getText or function(_, fallback)
    return fallback
  end
  local frame = createFrame("Frame")
  frame:SetScript("OnEvent", function()
    ConsumableCheck.OnReadyCheck(opts.showCard, getText)
  end)
  frame:RegisterEvent("READY_CHECK")
  return frame
end
