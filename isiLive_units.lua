local _, addonTable = ...

addonTable = addonTable or {}

local Units = {}
addonTable.Units = Units

local SPEC_SHORT_LABELS = {
  -- German (max 4 chars)
  ["wiederherstellung"] = "Rest",
  ["vergeltung"] = "Retr",
  ["schutz"] = "Prot",
  ["heilig"] = "Holy",
  ["disziplin"] = "Disc",
  ["schatten"] = "Shad",
  ["gleichgewicht"] = "Boom",
  ["wildheit"] = "Ferl",
  ["wachter"] = "Grdn",
  ["verwustung"] = "Havo",
  ["rachsucht"] = "Veng",
  ["verschlinger"] = "Devo",
  ["braumeister"] = "Brew",
  ["nebelwirker"] = "MW",
  ["windlaufer"] = "WW",
  ["verstarkung"] = "Enh",
  ["elementar"] = "Ele",
  ["waffen"] = "Arms",
  ["furor"] = "Fury",
  ["blut"] = "Blod",
  ["frost"] = "Fros",
  ["unheilig"] = "Unho",
  ["treffsicherheit"] = "MM",
  ["tierherrschaft"] = "BM",
  ["uberleben"] = "Surv",
  ["gebrechen"] = "Affl",
  ["demonologie"] = "Demo",
  ["zerstorung"] = "Dest",
  ["meucheln"] = "Assa",
  ["gesetzlosigkeit"] = "Outl",
  ["tauschung"] = "Sub",
  ["feuer"] = "Fire",
  ["arkan"] = "Arca",
  ["bewahrung"] = "Pres",
  ["verwustung-evoker"] = "Deva",
  ["augmentation"] = "Aug",
  ["starkung"] = "Aug", -- DE: Augmentation Evoker (NormalizeSpecKey konvertiert ä→a)

  -- English (max 4 chars)
  ["restoration"] = "Rest",
  ["retribution"] = "Retr",
  ["protection"] = "Prot",
  ["holy"] = "Holy",
  ["discipline"] = "Disc",
  ["shadow"] = "Shad",
  ["balance"] = "Boom",
  ["feral"] = "Ferl",
  ["guardian"] = "Grdn",
  ["havoc"] = "Havo",
  ["vengeance"] = "Veng",
  ["devourer"] = "Devo",
  ["brewmaster"] = "Brew",
  ["mistweaver"] = "MW",
  ["windwalker"] = "WW",
  ["enhancement"] = "Enh",
  ["elemental"] = "Ele",
  ["arms"] = "Arms",
  ["fury"] = "Fury",
  ["blood"] = "Blod",
  ["unholy"] = "Unho",
  ["marksmanship"] = "MM",
  ["beast mastery"] = "BM",
  ["survival"] = "Surv",
  ["affliction"] = "Affl",
  ["demonology"] = "Demo",
  ["destruction"] = "Dest",
  ["assassination"] = "Assa",
  ["outlaw"] = "Outl",
  ["subtlety"] = "Sub",
  ["fire"] = "Fire",
  ["arcane"] = "Arca",
  ["preservation"] = "Pres",
  ["devastation"] = "Deva",
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

function Units.GetUnitRole(unit)
  if not unit or not UnitExists(unit) then
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
    local truncated = string.sub(name, 1, maxChars)
    -- Continuation-Bytes (0x80–0xBF) am Schnittrand zurückrollen,
    -- damit kein beschädigtes UTF-8 entsteht.
    while #truncated > 0 and truncated:byte(#truncated) >= 0x80 and truncated:byte(#truncated) <= 0xBF do
      truncated = string.sub(truncated, 1, #truncated - 1)
    end
    return #truncated > 0 and truncated or string.sub(name, 1, maxChars)
  end
  return name
end

function Units.GetUnitNameAndRealm(unit)
  if not unit or not UnitExists(unit) then
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
  if not unit or not GetInspectSpecialization or not GetSpecializationInfoByID then
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
  if not unit or not UnitExists(unit) then
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
