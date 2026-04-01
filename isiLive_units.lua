local _, addonTable = ...

addonTable = addonTable or {}

local Units = {}
addonTable.Units = Units

local SPEC_SHORT_LABELS = {
  -- German short labels (mostly 5 chars)
  ["wiederherstellung"] = "Resto",
  ["vergeltung"] = "Retri",
  ["schutz"] = "Prote",
  ["heilig"] = "Holy",
  ["disziplin"] = "Disci",
  ["schatten"] = "Shado",
  ["gleichgewicht"] = "Boomy",
  ["wildheit"] = "Feral",
  ["wachter"] = "Guard",
  ["verwustung"] = "Havoc",
  ["rachsucht"] = "Venge",
  ["verschlinger"] = "Devou",
  ["braumeister"] = "Brewm",
  ["nebelwirker"] = "MW",
  ["windlaufer"] = "WW",
  ["verstarkung"] = "Enhan",
  ["elementar"] = "Eleme",
  ["waffen"] = "Arms",
  ["furor"] = "Fury",
  ["blut"] = "Blood",
  ["frost"] = "Frost",
  ["unheilig"] = "Unhol",
  ["treffsicherheit"] = "MM",
  ["tierherrschaft"] = "BM",
  ["uberleben"] = "Survi",
  ["gebrechen"] = "Affli",
  ["demonologie"] = "Demon",
  ["zerstorung"] = "Destr",
  ["meucheln"] = "Assas",
  ["gesetzlosigkeit"] = "Outla",
  ["tauschung"] = "Subtl",
  ["feuer"] = "Fire",
  ["arkan"] = "Arcan",
  ["bewahrung"] = "Prese",
  ["verwustung-evoker"] = "Devas",
  ["augmentation"] = "Aug",
  ["starkung"] = "Aug", -- DE: Augmentation Evoker (NormalizeSpecKey converts ä→a)

  -- English short labels (mostly 5 chars)
  ["restoration"] = "Resto",
  ["retribution"] = "Retri",
  ["protection"] = "Prote",
  ["holy"] = "Holy",
  ["discipline"] = "Disci",
  ["shadow"] = "Shado",
  ["balance"] = "Boomy",
  ["feral"] = "Feral",
  ["guardian"] = "Guard",
  ["havoc"] = "Havoc",
  ["vengeance"] = "Venge",
  ["devourer"] = "Devou",
  ["brewmaster"] = "Brewm",
  ["mistweaver"] = "MW",
  ["windwalker"] = "WW",
  ["enhancement"] = "Enhan",
  ["elemental"] = "Eleme",
  ["arms"] = "Arms",
  ["fury"] = "Fury",
  ["blood"] = "Blood",
  ["unholy"] = "Unhol",
  ["marksmanship"] = "MM",
  ["beast mastery"] = "BM",
  ["survival"] = "Survi",
  ["affliction"] = "Affli",
  ["demonology"] = "Demon",
  ["destruction"] = "Destr",
  ["assassination"] = "Assas",
  ["outlaw"] = "Outla",
  ["subtlety"] = "Subtl",
  ["fire"] = "Fire",
  ["arcane"] = "Arcan",
  ["preservation"] = "Prese",
  ["devastation"] = "Devas",
  -- frost: shared key between DE (Frost DK/Mage) and EN, already mapped above
}

local function NormalizeSpecKey(text)
  local value = string.lower(tostring(text or ""))
  value = value:gsub("^%s+", "")
  value = value:gsub("%s+$", "")
  value = value:gsub("%s+", " ")
  value = value:gsub("ä", "a")
  value = value:gsub("ö", "o")
  value = value:gsub("ü", "u")
  value = value:gsub("ß", "ss")
  return value
end

local IsExistingUnit = addonTable.Validators.IsExistingUnit

local function Utf8Sub(text, startChar, endChar)
  local startIndex = math.max(1, tonumber(startChar) or 1)
  local finishIndex = math.max(startIndex, tonumber(endChar) or startIndex)
  local length = #text
  local charIndex = 0
  local byteIndex = 1
  local startByte = nil

  while byteIndex <= length do
    charIndex = charIndex + 1
    if charIndex == startIndex then
      startByte = byteIndex
    end

    local b1 = text:byte(byteIndex)
    local step = 1
    if b1 and b1 < 0x80 then
      step = 1
    elseif b1 and b1 >= 0xC2 and b1 <= 0xDF then
      step = 2
    elseif b1 and b1 >= 0xE0 and b1 <= 0xEF then
      step = 3
    elseif b1 and b1 >= 0xF0 and b1 <= 0xF4 then
      step = 4
    end

    if charIndex == finishIndex then
      if not startByte then
        return ""
      end
      return text:sub(startByte, byteIndex + step - 1)
    end

    byteIndex = byteIndex + step
  end

  if not startByte then
    return ""
  end

  return text:sub(startByte)
end

function Units.GetUnitRole(unit)
  if not IsExistingUnit(unit) then
    return "NONE"
  end

  local role = UnitGroupRolesAssigned(unit)
  if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
    return role
  end

  -- Fallback for player: use current specialization role if group role is not set
  if UnitIsUnit(unit, "player") and GetSpecialization and GetSpecializationRole then
    local specIndex = GetSpecialization()
    if specIndex then
      role = GetSpecializationRole(specIndex)
      if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
        return role
      end
    end
  end

  return "NONE"
end

function Units.GetUnitClass(unit)
  if not IsExistingUnit(unit) then
    return nil, nil
  end

  local unitClass = rawget(_G, "UnitClass")
  if type(unitClass) ~= "function" then
    return nil, nil
  end

  local ok, localizedClass, classToken = pcall(unitClass, unit)
  if not ok then
    return nil, nil
  end

  return localizedClass, classToken
end

function Units.TruncateName(name, maxChars)
  if not name then
    return ""
  end
  maxChars = maxChars or 10

  local utf8len = rawget(_G, "utf8len")
  local utf8sub = rawget(_G, "utf8sub")
  if utf8len and utf8sub then
    if utf8len(name) > maxChars then
      return utf8sub(name, 1, maxChars)
    end
    return name
  end

  if string.len(name) > maxChars then
    return Utf8Sub(name, 1, maxChars)
  end
  return name
end

function Units.GetUnitNameAndRealm(unit)
  if not IsExistingUnit(unit) then
    return nil, nil
  end

  local name, realm = UnitFullName(unit)
  if not name then
    name = UnitName(unit)
  end
  if not realm or realm == "" then
    realm = GetRealmName() or ""
  end
  return name, realm
end

function Units.GetPlayerSpecName()
  if not GetSpecialization or not GetSpecializationInfo then
    return nil
  end
  local specIndex = GetSpecialization()
  if not specIndex or specIndex <= 0 then
    return nil
  end
  local _, specName = GetSpecializationInfo(specIndex)
  return specName
end

function Units.GetInspectSpecName(unit)
  if not IsExistingUnit(unit) or not GetInspectSpecialization or not GetSpecializationInfoByID then
    return nil
  end

  local okSpec, specID = pcall(GetInspectSpecialization, unit)
  if not okSpec or not specID or specID <= 0 then
    return nil
  end

  local okName, _, specName = pcall(GetSpecializationInfoByID, specID)
  if okName and type(specName) == "string" and specName ~= "" then
    return specName
  end
  return nil
end

function Units.GetShortSpecLabel(specName)
  if type(specName) ~= "string" or specName == "" then
    return specName
  end

  local normalized = NormalizeSpecKey(specName)
  local mapped = SPEC_SHORT_LABELS[normalized]
  if mapped then
    return mapped
  end

  return specName
end

function Units.GetUnitRio(unit)
  if not IsExistingUnit(unit) then
    return nil
  end
  if not C_PlayerInfo or not C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
    return nil
  end

  local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
  if ok and summary then
    local currentSeasonScore = rawget(summary, "currentSeasonScore")
    local currentSeasonBestScore = rawget(summary, "currentSeasonBestScore")
    local rating = rawget(summary, "rating")
    local score = rawget(summary, "score")

    if currentSeasonScore then
      return currentSeasonScore
    end
    if currentSeasonBestScore then
      return currentSeasonBestScore
    end
    if rating then
      return rating
    end
    if score then
      return score
    end
  end

  return nil
end
