local _, addonTable = ...

addonTable = addonTable or {}

-- Read-only samplers of the probe mode (rule 239): they read the client and
-- return text, nothing else. logic/isiLive_probe_log.lua decides when they
-- run and writes the lines.
local ProbeSamples = {}
addonTable.ProbeSamples = ProbeSamples
local IsSecretValue = addonTable.Validators.IsSecretValue

local function YesNo(value)
  return value and "yes" or "no"
end

-- Own buffs (K4): how many the client lists and how many of them, or of
-- their spell IDs and expiration times, are masked. Also whether
-- GetPlayerAuraBySpellID answers readably for the first readable spell ID,
-- the call a consumable check would make with a season ID list.
function ProbeSamples.OwnAuras(maxAuras)
  local unitAuras = rawget(_G, "C_UnitAuras")
  local byIndex = type(unitAuras) == "table" and rawget(unitAuras, "GetAuraDataByIndex") or nil
  if type(byIndex) ~= "function" then
    return "auras=api_missing"
  end
  local counts = { auras = 0, auraSecret = 0, spellIdSecret = 0, expirationSecret = 0, errors = 0 }
  local candidate = nil
  -- Readable spell IDs of the own buffs: the season IDs of food, flask and
  -- augment rune for the consumable check (rule 246) come from here.
  local spellIds = {}
  for index = 1, maxAuras do
    local ok, aura = pcall(byIndex, "player", index, "HELPFUL")
    if not ok then
      counts.errors = counts.errors + 1
      break
    end
    if IsSecretValue(aura) then
      counts.auras = counts.auras + 1
      counts.auraSecret = counts.auraSecret + 1
    elseif type(aura) ~= "table" then
      break
    else
      counts.auras = counts.auras + 1
      local spellId = aura.spellId
      if IsSecretValue(spellId) then
        counts.spellIdSecret = counts.spellIdSecret + 1
      elseif type(spellId) == "number" then
        candidate = candidate or spellId
        spellIds[#spellIds + 1] = string.format("%d", spellId)
      end
      if IsSecretValue(aura.expirationTime) then
        counts.expirationSecret = counts.expirationSecret + 1
      end
    end
  end
  local bySpellId = "no_candidate"
  local bySpellFn = type(unitAuras) == "table" and rawget(unitAuras, "GetPlayerAuraBySpellID") or nil
  if type(bySpellFn) ~= "function" then
    bySpellId = "api_missing"
  elseif candidate ~= nil then
    local ok, aura = pcall(bySpellFn, candidate)
    if not ok then
      bySpellId = "error"
    elseif IsSecretValue(aura) then
      bySpellId = "secret"
    else
      bySpellId = type(aura) == "table" and "readable" or "nil"
    end
  end
  return string.format(
    "auras=%d auraSecret=%d spellIdSecret=%d expirationSecret=%d auraErrors=%d bySpellID=%s",
    counts.auras,
    counts.auraSecret,
    counts.spellIdSecret,
    counts.expirationSecret,
    counts.errors,
    bySpellId
  ),
    #spellIds > 0 and table.concat(spellIds, ",") or "none"
end

-- One weapon slot of the weapon enchant reader (GetWeaponEnchantInfo shape): has / minutes left / enchant ID.
local function DescribeWeaponSlot(prefix, has, expirationMs, enchantId)
  local hasText
  if IsSecretValue(has) then
    hasText = "secret"
  else
    hasText = YesNo(has == true or has == 1)
  end
  local minutes = "nil"
  if IsSecretValue(expirationMs) then
    minutes = "secret"
  elseif type(expirationMs) == "number" then
    minutes = string.format("%d", math.floor(expirationMs / 60000))
  end
  local enchant = "nil"
  if IsSecretValue(enchantId) then
    enchant = "secret"
  elseif type(enchantId) == "number" then
    enchant = string.format("%d", enchantId)
  end
  return string.format("%s=%s %sMin=%s %sEnchant=%s", prefix, hasText, prefix, minutes, prefix, enchant)
end

-- Weapon oil (K4): the temporary enchant API needs no season ID list.
function ProbeSamples.WeaponEnchants()
  local getInfo = addonTable.Validators.ResolveWeaponEnchantReader()
  if type(getInfo) ~= "function" then
    return "weapon=api_missing"
  end
  local ok, hasMain, mainExp, _, mainId, hasOff, offExp, _, offId = pcall(getInfo)
  if not ok then
    return "weapon=error"
  end
  return DescribeWeaponSlot("mh", hasMain, mainExp, mainId) .. " " .. DescribeWeaponSlot("oh", hasOff, offExp, offId)
end
