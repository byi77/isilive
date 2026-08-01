local _, addonTable = ...

addonTable = addonTable or {}

local Model = {}
addonTable.LFGBonusModel = Model

local bonusesEnabled = true
local CLASS_BONUS_TEXT_COLOR = "|cff00ff00"
local CLASS_BONUS_DIM_COLOR = "|cff777777"
local CLASS_BONUS_UTILITY_COLOR = "|cffffd100"
local CLASS_BONUS_RESET_COLOR = "|r"
local APPLICANT_BONUS_TEXT_COLOR = { 0.20, 1.00, 0.20, 1.00 }
local APPLICANT_BONUS_MAJOR_COLOR = { 1.00, 0.82, 0.00, 1.00 }
-- WoW texture APIs resolve the .tga asset from this extensionless path.
local SEARCH_RESULT_BONUS_TEXTURE = "Interface\\AddOns\\isiLive\\media\\heart_bonus_green"
local SEARCH_RESULT_BONUS_MARKUP = "|T" .. SEARCH_RESULT_BONUS_TEXTURE .. ":12:12|t"
local SEARCH_RESULT_BONUS_MAX_MARKERS = 4

local CLASS_TOKENS = {
  DEATHKNIGHT = true,
  DEMONHUNTER = true,
  DRUID = true,
  EVOKER = true,
  HUNTER = true,
  MAGE = true,
  MONK = true,
  PALADIN = true,
  PRIEST = true,
  ROGUE = true,
  SHAMAN = true,
  WARLOCK = true,
  WARRIOR = true,
}

local AUGMENTATION_EVOKER_SPEC_ID = 1473

local INTELLECT_SPEC_IDS = {
  [62] = true,
  [63] = true,
  [64] = true,
  [65] = true,
  [102] = true,
  [105] = true,
  [256] = true,
  [257] = true,
  [258] = true,
  [262] = true,
  [264] = true,
  [265] = true,
  [266] = true,
  [267] = true,
  [270] = true,
  [1467] = true,
  [1468] = true,
  [1473] = true,
}

local AP_CLASS_TOKENS = {
  DEATHKNIGHT = true,
  DEMONHUNTER = true,
  HUNTER = true,
  ROGUE = true,
  WARRIOR = true,
}

local AP_SPEC_IDS = {
  [66] = true,
  [70] = true,
  [71] = true,
  [72] = true,
  [73] = true,
  [103] = true,
  [104] = true,
  [250] = true,
  [251] = true,
  [252] = true,
  [253] = true,
  [254] = true,
  [255] = true,
  [259] = true,
  [260] = true,
  [261] = true,
  [263] = true,
  [268] = true,
  [269] = true,
  [577] = true,
  [581] = true,
  [1480] = true,
}

local MAGIC_DAMAGE_CLASS_TOKENS = {
  MAGE = true,
  PRIEST = true,
  WARLOCK = true,
  EVOKER = true,
}

local MAGIC_DAMAGE_SPEC_IDS = {
  [62] = true,
  [63] = true,
  [64] = true,
  [251] = true,
  [252] = true,
  [102] = true,
  [256] = true,
  [257] = true,
  [258] = true,
  [262] = true,
  [264] = true,
  [265] = true,
  [266] = true,
  [267] = true,
  [1467] = true,
  [1468] = true,
  [1473] = true,
}

local PHYSICAL_DAMAGE_CLASS_TOKENS = {
  DEATHKNIGHT = true,
  DEMONHUNTER = true,
  HUNTER = true,
  ROGUE = true,
  WARRIOR = true,
}

local PHYSICAL_DAMAGE_SPEC_IDS = {
  [66] = true,
  [70] = true,
  [71] = true,
  [72] = true,
  [73] = true,
  [103] = true,
  [104] = true,
  [250] = true,
  [253] = true,
  [254] = true,
  [255] = true,
  [259] = true,
  [260] = true,
  [261] = true,
  [263] = true,
  [268] = true,
  [269] = true,
  [577] = true,
  [581] = true,
  [1480] = true,
}

-- Intentionally shown group-bonus surface for the LFG helper. This list only
-- contains bonuses that matter for choosing a Mythic+ group at a glance; class
-- mobility/convenience buffs that do not increase the player's output or key
-- safety signal are deliberately omitted.
local CLASS_BONUSES = {
  DEATHKNIGHT = {
    { textKey = "LFG_BONUS_BR", kind = "utility" },
  },
  DEMONHUNTER = {
    { textKey = "LFG_BONUS_MAGIC", kind = "magic_damage" },
  },
  DRUID = {
    { textKey = "LFG_BONUS_VERSA", kind = "universal" },
    { textKey = "LFG_BONUS_BR", kind = "utility" },
  },
  EVOKER = {
    { textKey = "LFG_BONUS_BL", kind = "utility" },
  },
  HUNTER = {
    { textKey = "LFG_BONUS_DMG", kind = "universal" },
  },
  MAGE = {
    { textKey = "LFG_BONUS_INT", kind = "intellect" },
    { textKey = "LFG_BONUS_BL", kind = "utility" },
  },
  MONK = {
    { textKey = "LFG_BONUS_PHYSICAL", kind = "physical_damage" },
  },
  PALADIN = {
    { textKey = "LFG_BONUS_DEVOTION", kind = "utility" },
    { textKey = "LFG_BONUS_BR", kind = "utility" },
  },
  PRIEST = {
    { textKey = "LFG_BONUS_STAMINA", kind = "universal" },
    { textKey = "LFG_BONUS_PI", kind = "utility" },
  },
  ROGUE = {
    { textKey = "LFG_BONUS_ENEMY_DMG", kind = "utility" },
  },
  SHAMAN = {
    { textKey = "LFG_BONUS_MASTERY", kind = "universal" },
    { textKey = "LFG_BONUS_BL", kind = "utility" },
  },
  WARLOCK = {
    { textKey = "LFG_BONUS_BR", kind = "utility" },
    { textKey = "LFG_BONUS_HS", kind = "utility" },
  },
  WARRIOR = {
    { textKey = "LFG_BONUS_AP", kind = "attack_power" },
  },
}

local SPEC_BONUSES = {
  [253] = {
    { textKey = "LFG_BONUS_BL", kind = "utility" },
  },
  [254] = {
    { textKey = "LFG_BONUS_BL", kind = "utility" },
  },
  [255] = {
    { textKey = "LFG_BONUS_BL", kind = "utility" },
  },
  [AUGMENTATION_EVOKER_SPEC_ID] = {
    { textKey = "LFG_BONUS_EBON_MIGHT", kind = "universal" },
  },
}

local SPEC_CLASS_TOKENS = {
  [253] = "HUNTER",
  [254] = "HUNTER",
  [255] = "HUNTER",
  [AUGMENTATION_EVOKER_SPEC_ID] = "EVOKER",
}

-- Injected via Register().

local function NormalizeToken(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end
  local token = string.upper(value)
  token = token:gsub("%s+", "")
  token = token:gsub("_", "")
  return token
end

local function ResolveClassToken(value)
  local token = NormalizeToken(value)
  if token and CLASS_TOKENS[token] then
    return token
  end
  if type(value) ~= "string" or value == "" then
    return nil
  end
  local localizedTables = {
    rawget(_G, "LOCALIZED_CLASS_NAMES_MALE"),
    rawget(_G, "LOCALIZED_CLASS_NAMES_FEMALE"),
  }
  for _, localized in ipairs(localizedTables) do
    if type(localized) == "table" then
      for classToken, className in pairs(localized) do
        if type(classToken) == "string" and CLASS_TOKENS[classToken] and className == value then
          return classToken
        end
      end
    end
  end
  return nil
end

local function NormalizeSpecText(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end
  local text = string.lower(value)
  text = text:gsub("^%s+", "")
  text = text:gsub("%s+$", "")
  text = text:gsub("ä", "a")
  text = text:gsub("ö", "o")
  text = text:gsub("ü", "u")
  text = text:gsub("ß", "ss")
  return text
end

local function IsSecretValue(value)
  local issecretvalue_ref = rawget(_G, "issecretvalue")
  if type(issecretvalue_ref) ~= "function" then
    return false
  end
  local ok, result = pcall(issecretvalue_ref, value)
  return ok and result == true
end

local function ReadPositiveNumber(value)
  if value == nil or IsSecretValue(value) then
    return nil
  end
  local ok, numericValue = pcall(tonumber, value)
  if not ok or type(numericValue) ~= "number" or numericValue <= 0 then
    return nil
  end
  return math.floor(numericValue)
end

local function ResolveSpecIDFromText(value, classToken)
  local normalized = NormalizeSpecText(value)
  if not normalized then
    return nil
  end
  if
    classToken == "EVOKER"
    and (normalized == "augmentation" or normalized == "verstarkung" or normalized == "starkung")
  then
    return AUGMENTATION_EVOKER_SPEC_ID
  end
  return nil
end

local function ResolvePlayerClassToken()
  if not addonTable.Validators.IsExistingUnit("player") then
    return nil
  end
  local unitClass = rawget(_G, "UnitClass")
  if type(unitClass) ~= "function" then
    return nil
  end
  local ok, _, classToken = pcall(unitClass, "player")
  if not ok or IsSecretValue(classToken) then
    return nil
  end
  return ResolveClassToken(classToken)
end

local function ResolvePlayerSpecID()
  local getSpecialization = rawget(_G, "GetSpecialization")
  local getSpecializationInfo = rawget(_G, "GetSpecializationInfo")
  if type(getSpecialization) ~= "function" or type(getSpecializationInfo) ~= "function" then
    return nil
  end
  local okIndex, specIndex = pcall(getSpecialization)
  if not okIndex or IsSecretValue(specIndex) or not specIndex then
    return nil
  end
  local okInfo, specID = pcall(getSpecializationInfo, specIndex)
  if not okInfo or IsSecretValue(specID) then
    return nil
  end
  return ReadPositiveNumber(specID)
end

local function ResolvePlayerBonusProfile()
  local classToken = ResolvePlayerClassToken()
  local specID = ResolvePlayerSpecID()
  if not classToken and not specID then
    return nil
  end
  return {
    classToken = classToken,
    specID = specID,
    usesIntellect = (specID and INTELLECT_SPEC_IDS[specID]) == true,
    usesAttackPower = (specID and AP_SPEC_IDS[specID]) == true
      or (not specID and classToken and AP_CLASS_TOKENS[classToken]) == true,
    dealsMagicDamage = (specID and MAGIC_DAMAGE_SPEC_IDS[specID]) == true
      or (not specID and classToken and MAGIC_DAMAGE_CLASS_TOKENS[classToken]) == true,
    dealsPhysicalDamage = (specID and PHYSICAL_DAMAGE_SPEC_IDS[specID]) == true
      or (not specID and classToken and PHYSICAL_DAMAGE_CLASS_TOKENS[classToken]) == true,
  }
end

local function ResolveBonusLocale()
  local db = rawget(_G, "IsiLiveDB")
  local languages = addonTable.Languages
  local resolveTag = type(languages) == "table" and languages.ResolveTag or nil
  if type(db) == "table" and type(db.locale) == "string" and db.locale ~= "" then
    if type(resolveTag) == "function" then
      return resolveTag(db.locale)
    end
    return string.sub(db.locale, 1, 2) == "de" and "deDE" or "enUS"
  end
  local getLocale = rawget(_G, "GetLocale")
  if type(getLocale) == "function" then
    local ok, locale = pcall(getLocale)
    if ok and type(locale) == "string" then
      if type(resolveTag) == "function" then
        return resolveTag(locale)
      end
      if string.sub(locale, 1, 2) == "de" then
        return "deDE"
      end
    end
  end
  return "enUS"
end

local function ResolveLocalizedText(key)
  if type(key) ~= "string" or key == "" then
    return nil
  end
  local textsModule = addonTable.Texts
  local getLocaleTables = type(textsModule) == "table" and textsModule.GetLocaleTables or nil
  if type(getLocaleTables) ~= "function" then
    return nil
  end
  local locales = getLocaleTables()
  if type(locales) ~= "table" then
    return nil
  end
  local locale = ResolveBonusLocale()
  local localeTable = type(locales[locale]) == "table" and locales[locale] or nil
  local enTable = type(locales.enUS) == "table" and locales.enUS or nil
  local text = localeTable and localeTable[key] or nil
  if type(text) ~= "string" or text == "" then
    text = enTable and enTable[key] or nil
  end
  return type(text) == "string" and text ~= "" and text or nil
end

local function ResolveBonusText(bonus)
  if type(bonus) ~= "table" then
    return nil
  end
  return ResolveLocalizedText(bonus.textKey)
end

local function BuildBonusList(classToken, specID)
  local parts = {}
  local seen = {}
  local function appendBonuses(bonuses)
    if type(bonuses) ~= "table" then
      return
    end
    for _, bonus in ipairs(bonuses) do
      if type(bonus) == "table" and type(bonus.textKey) == "string" and not seen[bonus.textKey] then
        seen[bonus.textKey] = true
        table.insert(parts, bonus)
      end
    end
  end
  appendBonuses(CLASS_BONUSES[classToken])
  if specID and SPEC_CLASS_TOKENS[specID] == classToken then
    appendBonuses(SPEC_BONUSES[specID])
  end
  return #parts > 0 and parts or nil
end

local function BuildBonusCacheKey(resultID, profile)
  local parts = {
    tostring(resultID),
    ResolveBonusLocale(),
  }
  if type(profile) == "table" then
    table.insert(parts, tostring(profile.classToken or ""))
    table.insert(parts, tostring(profile.specID or ""))
    table.insert(parts, profile.usesIntellect and "int" or "")
    table.insert(parts, profile.usesAttackPower and "ap" or "")
    table.insert(parts, profile.dealsMagicDamage and "magic" or "")
    table.insert(parts, profile.dealsPhysicalDamage and "physical" or "")
  end
  return table.concat(parts, "|")
end

local function IsBonusRelevantForPlayer(bonus, profile)
  if type(bonus) ~= "table" then
    return nil
  end
  local kind = bonus.kind
  if kind == "utility" then
    return "utility"
  end
  if kind == "universal" or kind == "defensive" then
    return true
  end
  if type(profile) ~= "table" then
    return nil
  end
  if kind == "intellect" then
    return profile.usesIntellect == true
  end
  if kind == "attack_power" then
    return profile.usesAttackPower == true
  end
  if kind == "magic_damage" then
    return profile.dealsMagicDamage == true
  end
  if kind == "physical_damage" then
    return profile.dealsPhysicalDamage == true
  end
  return nil
end

local function ColorizeBonusText(bonus, profile)
  local text = ResolveBonusText(bonus)
  if not text then
    return nil
  end
  local relevance = IsBonusRelevantForPlayer(bonus, profile)
  if relevance == "utility" then
    return CLASS_BONUS_UTILITY_COLOR .. text .. CLASS_BONUS_RESET_COLOR
  end
  if relevance == true then
    return CLASS_BONUS_TEXT_COLOR .. text .. CLASS_BONUS_RESET_COLOR
  end
  if relevance == false then
    return CLASS_BONUS_DIM_COLOR .. text .. CLASS_BONUS_RESET_COLOR
  end
  return text
end

local function BuildBonusSuffix(classToken, specID, profile)
  local bonuses = BuildBonusList(classToken, specID)
  if type(bonuses) ~= "table" or next(bonuses) == nil then
    return nil
  end
  local parts = {}
  for _, bonus in ipairs(bonuses) do
    local text = ColorizeBonusText(bonus, profile)
    if text then
      table.insert(parts, text)
    end
  end
  if #parts == 0 then
    return nil
  end
  return "(" .. table.concat(parts, ", ") .. ")"
end

local function IsRosterTooltipUtilityBonus(bonus)
  if type(bonus) ~= "table" or bonus.kind ~= "utility" then
    return false
  end
  return bonus.textKey == "LFG_BONUS_BL" or bonus.textKey == "LFG_BONUS_BR" or bonus.textKey == "LFG_BONUS_PI"
end

local function BuildRosterTooltipBonusSuffix(classToken, specID, profile)
  local bonuses = BuildBonusList(classToken, specID)
  if type(bonuses) ~= "table" or next(bonuses) == nil then
    return nil
  end
  local parts = {}
  for _, bonus in ipairs(bonuses) do
    if
      type(bonus) == "table"
      and (
        (bonus.kind ~= "utility" and IsBonusRelevantForPlayer(bonus, profile) == true)
        or IsRosterTooltipUtilityBonus(bonus)
      )
    then
      local text = ColorizeBonusText(bonus, profile)
      if text then
        table.insert(parts, text)
      end
    end
  end
  if #parts == 0 then
    return nil
  end
  return "(" .. table.concat(parts, ", ") .. ")"
end

local function IsMajorApplicantUtility(bonus)
  if type(bonus) ~= "table" or bonus.kind ~= "utility" then
    return false
  end
  return bonus.textKey == "LFG_BONUS_BL" or bonus.textKey == "LFG_BONUS_BR"
end

local function AddRelevantSearchResultBonusKeys(classToken, specID, profile, seenKeys)
  local bonuses = BuildBonusList(classToken, specID)
  if type(bonuses) ~= "table" or type(seenKeys) ~= "table" then
    return 0
  end
  local added = 0
  for _, bonus in ipairs(bonuses) do
    if
      type(bonus) == "table"
      and type(bonus.textKey) == "string"
      and bonus.kind ~= "utility"
      and not seenKeys[bonus.textKey]
      and IsBonusRelevantForPlayer(bonus, profile) == true
    then
      seenKeys[bonus.textKey] = true
      added = added + 1
    end
  end
  return added
end

local function BuildSearchResultBonusBadgeText(count)
  local numericCount = tonumber(count)
  if not numericCount or numericCount <= 0 then
    return nil
  end
  numericCount = math.min(SEARCH_RESULT_BONUS_MAX_MARKERS, math.floor(numericCount))
  return string.rep(SEARCH_RESULT_BONUS_MARKUP, numericCount)
end

local function BuildApplicantBonusBadge(classToken, specID, profile)
  local bonuses = BuildBonusList(classToken, specID)
  if type(bonuses) ~= "table" or next(bonuses) == nil then
    return nil
  end
  local hasRelevantBonus = false
  local hasMajorUtility = false
  for _, bonus in ipairs(bonuses) do
    if IsMajorApplicantUtility(bonus) then
      hasMajorUtility = true
    elseif IsBonusRelevantForPlayer(bonus, profile) == true then
      hasRelevantBonus = true
    end
  end
  if hasMajorUtility then
    return "++", APPLICANT_BONUS_MAJOR_COLOR
  end
  if hasRelevantBonus then
    return "+", APPLICANT_BONUS_TEXT_COLOR
  end
  return nil
end

local function CountApplicantBonusMarkers(classToken, specID, profile)
  local bonuses = BuildBonusList(classToken, specID)
  if type(bonuses) ~= "table" or next(bonuses) == nil then
    return 0
  end
  local relevantBonusCount = 0
  for _, bonus in ipairs(bonuses) do
    if type(bonus) == "table" and bonus.kind ~= "utility" and IsBonusRelevantForPlayer(bonus, profile) == true then
      relevantBonusCount = relevantBonusCount + 1
    end
  end
  return math.min(SEARCH_RESULT_BONUS_MAX_MARKERS, relevantBonusCount)
end

local function BuildApplicantBonusMarkerBadge(classToken, specID, profile)
  local relevantBonusCount = CountApplicantBonusMarkers(classToken, specID, profile)
  if relevantBonusCount <= 0 then
    return nil
  end
  return BuildSearchResultBonusBadgeText(relevantBonusCount), APPLICANT_BONUS_TEXT_COLOR
end

local function BuildRosterBonusMarkerBadge(classToken, specID)
  if not bonusesEnabled then
    return nil
  end

  classToken = ResolveClassToken(classToken)
  specID = ReadPositiveNumber(specID)
  if specID and SPEC_CLASS_TOKENS[specID] ~= classToken then
    specID = nil
  end
  if not classToken or not CLASS_TOKENS[classToken] then
    return nil
  end

  return BuildApplicantBonusMarkerBadge(classToken, specID, ResolvePlayerBonusProfile())
end

local function BuildRosterBonusTooltipLine(classToken, specID)
  if not bonusesEnabled then
    return nil
  end

  classToken = ResolveClassToken(classToken)
  specID = ReadPositiveNumber(specID)
  if specID and SPEC_CLASS_TOKENS[specID] ~= classToken then
    specID = nil
  end
  if not classToken or not CLASS_TOKENS[classToken] then
    return nil
  end

  local suffix = BuildRosterTooltipBonusSuffix(classToken, specID, ResolvePlayerBonusProfile())
  if type(suffix) ~= "string" or suffix == "" then
    return nil
  end

  local tooltipText = ResolveLocalizedText("LFG_BONUS_TOOLTIP_FMT") or "Group bonus: %s"
  local okFormatted, line = pcall(string.format, tooltipText, suffix)
  if okFormatted and type(line) == "string" and line ~= "" then
    return line
  end
  return "Group bonus: " .. suffix
end

Model.APPLICANT_BONUS_TEXT_COLOR = APPLICANT_BONUS_TEXT_COLOR
Model.SEARCH_RESULT_BONUS_TEXTURE = SEARCH_RESULT_BONUS_TEXTURE
Model.SEARCH_RESULT_BONUS_MAX_MARKERS = SEARCH_RESULT_BONUS_MAX_MARKERS
Model.CLASS_TOKENS = CLASS_TOKENS
Model.CLASS_BONUSES = CLASS_BONUSES
Model.SPEC_BONUSES = SPEC_BONUSES
Model.SPEC_CLASS_TOKENS = SPEC_CLASS_TOKENS
Model.IsSecretValue = IsSecretValue
Model.ResolveClassToken = ResolveClassToken
Model.ReadPositiveNumber = ReadPositiveNumber
Model.ResolveSpecIDFromText = ResolveSpecIDFromText
Model.ResolvePlayerBonusProfile = ResolvePlayerBonusProfile
Model.ResolveLocalizedText = ResolveLocalizedText
Model.BuildBonusCacheKey = BuildBonusCacheKey
Model.BuildBonusSuffix = BuildBonusSuffix
Model.AddRelevantSearchResultBonusKeys = AddRelevantSearchResultBonusKeys
Model.BuildSearchResultBonusBadgeText = BuildSearchResultBonusBadgeText
Model.BuildApplicantBonusBadge = BuildApplicantBonusBadge
Model.CountApplicantBonusMarkers = CountApplicantBonusMarkers
Model.BuildApplicantBonusMarkerBadge = BuildApplicantBonusMarkerBadge
Model.BuildRosterBonusMarkerBadge = BuildRosterBonusMarkerBadge
Model.BuildRosterBonusTooltipLine = BuildRosterBonusTooltipLine

function Model.SetEnabled(enabled)
  bonusesEnabled = enabled ~= false
end
