local _, addonTable = ...
addonTable = addonTable or {}

local LFGFlags = {}
addonTable.LFGFlags = LFGFlags

-- Internal helpers exposed for tests via addonTable._LFGFlagsInternal.
-- Production callers continue to use the local references defined below.
local LI = addonTable._LFGFlagsInternal or {}
addonTable._LFGFlagsInternal = LI

local FLAG_WIDTH = 12
local FLAG_HEIGHT = 9
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
local APPLICANT_BONUS_ICON_SIZE = 12
local APPLICANT_BONUS_ICON_GAP = 1
local SEARCH_RESULT_FLAG_X = 2
local SEARCH_RESULT_FLAG_Y = 10
local SEARCH_RESULT_FLAG_ACTIVITY_NAME_OFFSET_Y = -2
local SEARCH_RESULT_DUNGEON_NAME_SHIFT_X = FLAG_WIDTH + 4
local APPLICANT_FLAG_NAME_SHIFT_X = FLAG_WIDTH + 4
local SEARCH_RESULT_BONUS_RIGHT_X = -44
local SEARCH_RESULT_BONUS_Y = -16
local SEARCH_RESULT_BONUS_WIDTH = 68
local SEARCH_RESULT_KEYSTONE_LABELS = {
  ["Mythic Keystone"] = true,
  ["Mythischer Schl\195\188sselstein"] = true,
}
local SEARCH_RESULT_PROMOTION_OFFERED_PLAYSTYLE_TEXTS = {
  ["Bef\195\182rderung angeboten"] = true,
}

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
local getRealmInfoLib
local getLanguageTag
local getFlagTexturePath
local lfgFlagsEnabled = true
local lfgGroupBonusesEnabled = true

-- resultID -> tag string|false cache; cleared on new search.
local resultTagCache = {}
local resultBonusBadgeCache = {}
local resultMemberBonusCache = {}

-- WeakTable so recycled Blizzard buttons don't prevent GC.
local hooked = setmetatable({}, { __mode = "k" })
local hookedApplicants = setmetatable({}, { __mode = "k" })
local hookedApplicantMembers = setmetatable({}, { __mode = "k" })

-- -------------------------------------------------------------------------
-- Helpers
-- -------------------------------------------------------------------------

local function SplitNameRealm(fullName)
  if not fullName then
    return nil, nil
  end
  -- Split on FIRST dash so realms with embedded hyphens (e.g. "Area-52") stay
  -- intact. Greedy "^(.+)-(.+)$" would split "Player-Area-52" into
  -- ("Player-Area", "52"), diverging from the four other name-realm splitters
  -- in the codebase which all consume the first dash only.
  local dash = string.find(fullName, "-", 1, true)
  if not dash then
    return fullName, nil
  end
  return string.sub(fullName, 1, dash - 1), string.sub(fullName, dash + 1)
end

local function NormalizeToken(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end
  local token = string.upper(value)
  token = token:gsub("%s+", "")
  token = token:gsub("_", "")
  return token
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
  local unitClass = rawget(_G, "UnitClass")
  if type(unitClass) ~= "function" then
    return nil
  end
  local ok, _, classToken = pcall(unitClass, "player")
  if not ok then
    return nil
  end
  classToken = NormalizeToken(classToken)
  return CLASS_TOKENS[classToken] and classToken or nil
end

local function ResolvePlayerSpecID()
  local getSpecialization = rawget(_G, "GetSpecialization")
  local getSpecializationInfo = rawget(_G, "GetSpecializationInfo")
  if type(getSpecialization) ~= "function" or type(getSpecializationInfo) ~= "function" then
    return nil
  end
  local okIndex, specIndex = pcall(getSpecialization)
  if not okIndex or not specIndex then
    return nil
  end
  local okInfo, specID = pcall(getSpecializationInfo, specIndex)
  if not okInfo then
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

local function GetTagForResult(resultID)
  local cached = resultTagCache[resultID]
  if cached ~= nil then
    return cached or nil
  end
  local C_LFGList_ref = rawget(_G, "C_LFGList")
  if type(C_LFGList_ref) ~= "table" then
    return nil
  end
  local ok, info = pcall(C_LFGList_ref.GetSearchResultInfo, resultID)
  if not ok or not info then
    resultTagCache[resultID] = false
    return nil
  end
  local issecretvalue_ref = rawget(_G, "issecretvalue")
  if type(issecretvalue_ref) == "function" and issecretvalue_ref(info) then
    resultTagCache[resultID] = false
    return nil
  end
  local leaderName = info.leaderName
  if not leaderName then
    resultTagCache[resultID] = false
    return nil
  end
  local _, realm = SplitNameRealm(leaderName)
  if not realm then
    local getRealmName = rawget(_G, "GetRealmName")
    if type(getRealmName) == "function" then
      realm = getRealmName()
    end
  end
  local tag
  if type(getLanguageTag) == "function" and realm then
    local tagOk, tagResult = pcall(getLanguageTag, realm)
    if tagOk and type(tagResult) == "string" and tagResult ~= "" and tagResult ~= "??" then
      tag = tagResult
    end
  end
  resultTagCache[resultID] = tag or false
  return tag
end

local function ResolveLanguageTagFromName(fullName)
  local name, realm = SplitNameRealm(fullName)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  if not realm then
    local getRealmName = rawget(_G, "GetRealmName")
    if type(getRealmName) == "function" then
      local ok, realmName = pcall(getRealmName)
      if ok and type(realmName) == "string" and realmName ~= "" then
        realm = realmName
      end
    end
  end
  if type(realm) ~= "string" or realm == "" or type(getLanguageTag) ~= "function" then
    return nil
  end
  local ok, tag = pcall(getLanguageTag, realm)
  if ok and type(tag) == "string" and tag ~= "" and tag ~= "??" then
    return tag
  end
  return nil
end

local function ExtractMemberInfoFromTable(info)
  if type(info) ~= "table" or IsSecretValue(info) then
    return nil
  end
  local classToken = NormalizeToken(info.classFilename or info.classFileName or info.classToken or info.class)
  local specID = ReadPositiveNumber(info.specID or info.specId or info.specializationID or info.specializationId)
  if specID and SPEC_CLASS_TOKENS[specID] ~= classToken then
    specID = nil
  end
  specID = specID or ResolveSpecIDFromText(info.specName or info.specializationName or info.spec, classToken)
  local className = type(info.className) == "string" and info.className
    or type(info.localizedClassName) == "string" and info.localizedClassName
    or nil
  local specName = type(info.specName) == "string" and info.specName
    or type(info.specializationName) == "string" and info.specializationName
    or nil
  if not classToken or not CLASS_TOKENS[classToken] then
    return nil
  end
  return {
    classToken = classToken,
    specID = specID,
    className = className,
    specName = specName,
  }
end

local function ExtractMemberInfoFromValues(...)
  local classToken, specID, className, specName
  local pendingNumericSpecID
  local pendingSpecText
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    local numericValue = ReadPositiveNumber(value)
    if numericValue and SPEC_BONUSES[numericValue] then
      if classToken and SPEC_CLASS_TOKENS[numericValue] == classToken then
        specID = specID or numericValue
      elseif not classToken then
        pendingNumericSpecID = pendingNumericSpecID or numericValue
      end
    elseif type(value) == "string" and value ~= "" and not IsSecretValue(value) then
      local token = NormalizeToken(value)
      if token and CLASS_TOKENS[token] then
        classToken = classToken or token
        if not specID and pendingNumericSpecID and SPEC_CLASS_TOKENS[pendingNumericSpecID] == classToken then
          specID = pendingNumericSpecID
        end
      else
        local resolvedSpecID = ResolveSpecIDFromText(value, classToken)
        if resolvedSpecID then
          specID = specID or resolvedSpecID
        elseif not pendingSpecText and ResolveSpecIDFromText(value, "EVOKER") then
          pendingSpecText = value
        end
        if (resolvedSpecID or pendingSpecText == value) and not specName then
          specName = value
        elseif index > 1 and not className then
          className = value
        end
      end
    end
  end
  if not specID and classToken == "EVOKER" then
    specID = ResolveSpecIDFromText(pendingSpecText, classToken)
  end
  if not classToken then
    return nil
  end
  return {
    classToken = classToken,
    specID = specID,
    className = className,
    specName = specName,
  }
end

local function GetSearchResultMemberCount(resultID)
  local C_LFGList_ref = rawget(_G, "C_LFGList")
  if type(C_LFGList_ref) ~= "table" or type(C_LFGList_ref.GetSearchResultInfo) ~= "function" then
    return nil
  end
  local ok, info = pcall(C_LFGList_ref.GetSearchResultInfo, resultID)
  if not ok or type(info) ~= "table" or IsSecretValue(info) then
    return nil
  end
  return ReadPositiveNumber(info.numMembers or info.numMember or info.memberCount)
end

local function ReadSearchResultMemberInfo(resultID, memberIndex)
  local C_LFGList_ref = rawget(_G, "C_LFGList")
  if type(C_LFGList_ref) ~= "table" or type(C_LFGList_ref.GetSearchResultPlayerInfo) ~= "function" then
    return nil
  end
  local values = { pcall(C_LFGList_ref.GetSearchResultPlayerInfo, resultID, memberIndex) }
  if values[1] ~= true then
    return nil
  end
  if type(values[2]) == "table" then
    return ExtractMemberInfoFromTable(values[2])
  end
  table.remove(values, 1)
  local unpack_ref = rawget(_G, "unpack") or rawget(table, "unpack")
  return ExtractMemberInfoFromValues(unpack_ref(values))
end

local function BuildSearchResultMemberBonuses(resultID)
  if not lfgGroupBonusesEnabled then
    return nil
  end
  if not resultID then
    return nil
  end
  local profile = ResolvePlayerBonusProfile()
  local cacheKey = BuildBonusCacheKey(resultID, profile)
  if resultMemberBonusCache[cacheKey] ~= nil then
    return resultMemberBonusCache[cacheKey] or nil
  end
  local memberCount = GetSearchResultMemberCount(resultID)
  if not memberCount then
    resultMemberBonusCache[cacheKey] = false
    return nil
  end
  local members = {}
  local hasBonus = false
  for index = 1, memberCount do
    local member = ReadSearchResultMemberInfo(resultID, index)
    if member then
      member.suffix = BuildBonusSuffix(member.classToken, member.specID, profile)
      if member.suffix then
        hasBonus = true
      end
    end
    members[index] = member
  end
  resultMemberBonusCache[cacheKey] = hasBonus and members or false
  return resultMemberBonusCache[cacheKey] or nil
end

local function BuildSearchResultBonusBadge(resultID)
  if not lfgGroupBonusesEnabled then
    return nil
  end
  if not resultID then
    return nil
  end
  local profile = ResolvePlayerBonusProfile()
  local cacheKey = BuildBonusCacheKey(resultID, profile)
  if resultBonusBadgeCache[cacheKey] ~= nil then
    local cached = resultBonusBadgeCache[cacheKey]
    if type(cached) == "table" then
      return cached.badge, cached.color
    end
    return nil
  end
  local memberCount = GetSearchResultMemberCount(resultID)
  if not memberCount then
    resultBonusBadgeCache[cacheKey] = false
    return nil
  end
  local relevantBonusCount = 0
  local seenBonusKeys = {}
  for index = 1, memberCount do
    local member = ReadSearchResultMemberInfo(resultID, index)
    if member then
      relevantBonusCount = relevantBonusCount
        + AddRelevantSearchResultBonusKeys(member.classToken, member.specID, profile, seenBonusKeys)
    end
  end
  local badge = BuildSearchResultBonusBadgeText(relevantBonusCount)
  if badge then
    resultBonusBadgeCache[cacheKey] = { badge = badge, color = APPLICANT_BONUS_TEXT_COLOR }
    return badge, APPLICANT_BONUS_TEXT_COLOR
  end
  resultBonusBadgeCache[cacheKey] = false
  return nil
end

local function ReadApplicantInfo(applicantID)
  local C_LFGList_ref = rawget(_G, "C_LFGList")
  if type(C_LFGList_ref) ~= "table" or type(C_LFGList_ref.GetApplicantInfo) ~= "function" then
    return nil
  end
  local ok, info = pcall(C_LFGList_ref.GetApplicantInfo, applicantID)
  if not ok or type(info) ~= "table" or IsSecretValue(info) then
    return nil
  end
  return info
end

local function ReadApplicantMemberInfo(applicantID, memberIndex)
  local C_LFGList_ref = rawget(_G, "C_LFGList")
  if type(C_LFGList_ref) ~= "table" or type(C_LFGList_ref.GetApplicantMemberInfo) ~= "function" then
    return nil
  end
  local result = { pcall(C_LFGList_ref.GetApplicantMemberInfo, applicantID, memberIndex) }
  if not result[1] then
    return nil
  end
  local classToken = result[3]
  local localizedClass = result[4]
  local specID = result[17]
  classToken = NormalizeToken(classToken)
  if not classToken or not CLASS_TOKENS[classToken] then
    return nil
  end
  return {
    name = type(result[2]) == "string" and result[2] or nil,
    classToken = classToken,
    specID = ReadPositiveNumber(specID),
    className = type(localizedClass) == "string" and localizedClass or nil,
  }
end

local function BuildApplicantMemberBonuses(applicantID)
  if not lfgGroupBonusesEnabled then
    return nil
  end
  if not applicantID then
    return nil
  end
  local info = ReadApplicantInfo(applicantID)
  local memberCount = info and ReadPositiveNumber(info.numMembers or info.numMember or info.memberCount)
  if not memberCount then
    return nil
  end
  local profile = ResolvePlayerBonusProfile()
  local members = {}
  local hasBonus = false
  for index = 1, memberCount do
    local member = ReadApplicantMemberInfo(applicantID, index)
    if member then
      member.suffix = BuildBonusSuffix(member.classToken, member.specID, profile)
      if member.suffix then
        hasBonus = true
      end
    end
    members[index] = member
  end
  return hasBonus and members or nil
end

local function BuildSingleApplicantMemberSuffix(applicantID, memberIndex)
  if not lfgGroupBonusesEnabled then
    return nil
  end
  local member = applicantID and memberIndex and ReadApplicantMemberInfo(applicantID, memberIndex) or nil
  if not member then
    return nil
  end
  return BuildBonusSuffix(member.classToken, member.specID, ResolvePlayerBonusProfile())
end

local function BuildSingleApplicantMemberBadge(applicantID, memberIndex)
  if not lfgGroupBonusesEnabled then
    return nil, nil, 0
  end
  local member = applicantID and memberIndex and ReadApplicantMemberInfo(applicantID, memberIndex) or nil
  if not member then
    return nil, nil, 0
  end
  local profile = ResolvePlayerBonusProfile()
  return BuildApplicantBonusMarkerBadge(member.classToken, member.specID, profile),
    APPLICANT_BONUS_TEXT_COLOR,
    CountApplicantBonusMarkers(member.classToken, member.specID, profile)
end

local function StripColorCodes(text)
  if type(text) ~= "string" then
    return ""
  end
  local stripped = text:gsub("|c%x%x%x%x%x%x%x%x", "")
  stripped = stripped:gsub("|r", "")
  return stripped
end

local function IsSearchResultPromotionOfferedRow(button)
  local playstyle = type(button) == "table" and rawget(button, "Playstyle") or nil
  if type(playstyle) ~= "table" or type(playstyle.GetText) ~= "function" then
    return false
  end
  local text = StripColorCodes(playstyle:GetText())
  return SEARCH_RESULT_PROMOTION_OFFERED_PLAYSTYLE_TEXTS[text] == true
end

local function ClearSearchResultBonusCache(resultID)
  if resultID == nil then
    resultBonusBadgeCache = {}
    resultMemberBonusCache = {}
    return
  end
  local prefix = tostring(resultID) .. "|"
  for cacheKey in pairs(resultBonusBadgeCache) do
    if string.sub(tostring(cacheKey), 1, #prefix) == prefix then
      resultBonusBadgeCache[cacheKey] = nil
    end
  end
  for cacheKey in pairs(resultMemberBonusCache) do
    if string.sub(tostring(cacheKey), 1, #prefix) == prefix then
      resultMemberBonusCache[cacheKey] = nil
    end
  end
end

local function HasExistingBonusSuffix(text)
  local plain = StripColorCodes(text)
  local textsModule = addonTable.Texts
  local getLocaleTables = type(textsModule) == "table" and textsModule.GetLocaleTables or nil
  local locales = type(getLocaleTables) == "function" and getLocaleTables() or nil
  local function containsBonusText(bonus)
    if type(bonus) ~= "table" or type(locales) ~= "table" or type(bonus.textKey) ~= "string" then
      return false
    end
    for _, localeTable in pairs(locales) do
      local bonusText = type(localeTable) == "table" and localeTable[bonus.textKey] or nil
      if type(bonusText) == "string" and bonusText ~= "" and string.find(plain, bonusText, 1, true) then
        return true
      end
    end
    return false
  end
  for _, bonuses in pairs(CLASS_BONUSES) do
    for _, bonus in ipairs(bonuses) do
      if containsBonusText(bonus) then
        return true
      end
    end
  end
  for _, bonuses in pairs(SPEC_BONUSES) do
    for _, bonus in ipairs(bonuses) do
      if containsBonusText(bonus) then
        return true
      end
    end
  end
  return false
end

local function IsMembersHeader(text)
  local plain = StripColorCodes(text)
  return string.find(plain, "Mitglieder", 1, true) ~= nil or string.find(plain, "Members", 1, true) ~= nil
end

local function IsMemberSectionEnd(text)
  local plain = StripColorCodes(text)
  if plain == "" then
    return false
  end
  return string.find(plain, "Erstellt", 1, true) ~= nil
    or string.find(plain, "Created", 1, true) ~= nil
    or string.find(plain, "Raider.IO", 1, true) ~= nil
    or string.find(plain, "Beste", 1, true) ~= nil
    or string.find(plain, "Best", 1, true) ~= nil
end

local function GetTooltipLine(index)
  return rawget(_G, "GameTooltipTextLeft" .. tostring(index))
end

local function TooltipHasApplicantBonusLine(suffix)
  if type(suffix) ~= "string" or suffix == "" then
    return false
  end
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.NumLines) ~= "function" then
    return false
  end
  local ok, numLines = pcall(tooltip.NumLines, tooltip)
  numLines = ok and tonumber(numLines) or nil
  if not numLines or numLines <= 0 then
    return false
  end
  local suffixPlain = StripColorCodes(suffix)
  for index = 1, numLines do
    local line = GetTooltipLine(index)
    local text = line and type(line.GetText) == "function" and line:GetText() or nil
    local plain = StripColorCodes(text)
    if string.find(plain, "isiLive Bonus:", 1, true) and string.find(plain, suffixPlain, 1, true) then
      return true
    end
  end
  return false
end

local function HideTooltipLine(line)
  if type(line) ~= "table" then
    return
  end
  if type(line.SetText) == "function" then
    line:SetText("")
  end
  if type(line.Hide) == "function" then
    line:Hide()
  end
end

local function HideApplicantProvingGroundTooltipLines()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.NumLines) ~= "function" then
    return
  end
  local ok, numLines = pcall(tooltip.NumLines, tooltip)
  numLines = ok and tonumber(numLines) or nil
  if not numLines or numLines <= 0 then
    return
  end
  for index = 1, numLines do
    local line = GetTooltipLine(index)
    local text = line and type(line.GetText) == "function" and line:GetText() or nil
    local plain = StripColorCodes(text)
    if string.find(plain, "Die Feuerprobe", 1, true) or string.find(plain, "Proving Grounds", 1, true) then
      HideTooltipLine(line)
      HideTooltipLine(GetTooltipLine(index + 1))
      return
    end
  end
end

local function CollectTooltipMemberLines()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.NumLines) ~= "function" then
    return {}
  end
  local ok, numLines = pcall(tooltip.NumLines, tooltip)
  numLines = ok and tonumber(numLines) or nil
  if not numLines or numLines <= 0 then
    return {}
  end
  local memberLines = {}
  local fallbackLines = {}
  local inMembers = false
  for index = 1, numLines do
    local line = GetTooltipLine(index)
    local text = line and type(line.GetText) == "function" and line:GetText() or nil
    if type(text) == "string" then
      if text ~= "" then
        table.insert(fallbackLines, {
          index = index,
          line = line,
          text = text,
        })
      end
      if inMembers then
        if IsMemberSectionEnd(text) then
          break
        end
        if text ~= "" then
          table.insert(memberLines, {
            index = index,
            line = line,
            text = text,
          })
        end
      elseif IsMembersHeader(text) then
        inMembers = true
      end
    end
  end
  return #memberLines > 0 and memberLines or fallbackLines
end

local function TextContainsAll(text, ...)
  local plain = string.lower(StripColorCodes(text))
  for index = 1, select("#", ...) do
    local needle = select(index, ...)
    if type(needle) == "string" and needle ~= "" then
      local normalizedNeedle = string.lower(needle)
      if not string.find(plain, normalizedNeedle, 1, true) then
        return false
      end
    end
  end
  return true
end

local function MatchMemberLine(member, memberLines, usedLines)
  if type(member) ~= "table" or not member.suffix then
    return nil
  end
  if member.className and member.specName then
    for _, candidate in ipairs(memberLines) do
      if not usedLines[candidate.index] and TextContainsAll(candidate.text, member.className, member.specName) then
        return candidate
      end
    end
  end
  if member.specName then
    for _, candidate in ipairs(memberLines) do
      if not usedLines[candidate.index] and TextContainsAll(candidate.text, member.specName) then
        return candidate
      end
    end
  end
  return nil
end

local function ApplyGroupBonusTooltipLines(resultID)
  if not lfgGroupBonusesEnabled then
    return
  end
  local members = BuildSearchResultMemberBonuses(resultID)
  if type(members) ~= "table" then
    return
  end
  local memberLines = CollectTooltipMemberLines()
  if #memberLines == 0 then
    return
  end

  local usedLines = {}
  local unmatchedMembers = {}
  for index, member in ipairs(members) do
    if type(member) == "table" and member.suffix then
      local line = MatchMemberLine(member, memberLines, usedLines)
      if line then
        usedLines[line.index] = true
        if type(line.line.SetText) == "function" and not HasExistingBonusSuffix(line.text) then
          line.line:SetText(line.text .. " " .. member.suffix)
        end
      else
        table.insert(unmatchedMembers, { index = index, member = member })
      end
    end
  end

  if #unmatchedMembers == 0 or #memberLines ~= #members then
    return
  end
  for _, unresolved in ipairs(unmatchedMembers) do
    local line = memberLines[unresolved.index]
    local member = unresolved.member
    if
      line
      and not usedLines[line.index]
      and type(line.line.SetText) == "function"
      and not HasExistingBonusSuffix(line.text)
    then
      usedLines[line.index] = true
      line.line:SetText(line.text .. " " .. member.suffix)
    end
  end
end

local function BuildCombinedSuffixFromMembers(members)
  if type(members) ~= "table" then
    return nil
  end
  local parts = {}
  local seen = {}
  for _, member in ipairs(members) do
    if type(member) == "table" and type(member.suffix) == "string" and member.suffix ~= "" then
      local plain = StripColorCodes(member.suffix)
      if not seen[plain] then
        seen[plain] = true
        table.insert(parts, member.suffix)
      end
    end
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts, " ")
end

local function ResolveApplicantIDFromButton(button)
  if type(button) ~= "table" then
    return nil
  end
  local candidate = rawget(button, "applicantID")
    or rawget(button, "applicantId")
    or rawget(button, "id")
    or rawget(button, "ID")
  local numericCandidate = ReadPositiveNumber(candidate)
  if numericCandidate then
    return numericCandidate
  end
  local parent = type(button.GetParent) == "function" and button:GetParent() or nil
  if type(parent) == "table" then
    return ResolveApplicantIDFromButton(parent)
  end
  return nil
end

local function ApplyApplicantBonusToButton(button, applicantIDOverride)
  if not lfgGroupBonusesEnabled then
    return
  end
  local applicantID = ReadPositiveNumber(applicantIDOverride) or ResolveApplicantIDFromButton(button)
  local members = applicantID and BuildApplicantMemberBonuses(applicantID) or nil
  local suffix = BuildCombinedSuffixFromMembers(members)
  if not suffix then
    return
  end

  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.AddLine) == "function" and type(tooltip.Show) == "function" then
    local owner = type(tooltip.GetOwner) == "function" and tooltip:GetOwner() or nil
    if owner == button or owner == rawget(button, "InviteButton") or owner == rawget(button, "DeclineButton") then
      if TooltipHasApplicantBonusLine(suffix) then
        return
      end
      local tooltipText = ResolveLocalizedText("LFG_BONUS_TOOLTIP_FMT") or "isiLive Bonus: %s"
      tooltip:AddLine(string.format(tooltipText, suffix), 0.85, 0.85, 0.9)
      tooltip:Show()
    end
  end
end

local function ResolveApplicantRoleAnchor(member)
  if type(member) ~= "table" then
    return nil
  end
  local classAnchorKeys = {
    "ClassIcon",
    "Class",
    "ClassButton",
    "ClassIconTexture",
    "SpecIcon",
    "Spec",
    "SpecIconTexture",
  }
  for _, key in ipairs(classAnchorKeys) do
    local value = rawget(member, key)
    if type(value) == "table" then
      return value
    end
  end
  local roleAnchorKeys = {
    "RoleIcon",
    "Role",
    "RoleButton",
    "RoleIconTexture",
  }
  for _, key in ipairs(roleAnchorKeys) do
    local value = rawget(member, key)
    if type(value) == "table" then
      return value
    end
  end
  return nil
end

local function AnchorApplicantBonusBadge(member, badgeText)
  if type(member) ~= "table" or type(badgeText) ~= "table" or type(badgeText.SetPoint) ~= "function" then
    return
  end
  if type(badgeText.ClearAllPoints) == "function" then
    badgeText:ClearAllPoints()
  end
  local roleAnchor = ResolveApplicantRoleAnchor(member)
  if roleAnchor then
    badgeText:SetPoint("LEFT", roleAnchor, "RIGHT", 5, 0)
    return
  end
  badgeText:SetPoint("LEFT", member, "LEFT", 104, 0)
end

local function HideApplicantBonusIcons(member)
  if type(member) ~= "table" or type(member._isiLiveBonusBadgeIcons) ~= "table" then
    return
  end
  for _, icon in ipairs(member._isiLiveBonusBadgeIcons) do
    if type(icon) == "table" and type(icon.Hide) == "function" then
      icon:Hide()
    end
  end
end

local function ResolveApplicantBonusTextureOwner(member)
  if type(member) ~= "table" then
    return nil
  end
  if type(member.CreateTexture) == "function" then
    return member
  end
  local parent = type(member.GetParent) == "function" and member:GetParent() or nil
  if type(parent) == "table" and type(parent.CreateTexture) == "function" then
    return parent
  end
  local nameText = rawget(member, "Name")
  local nameParent = type(nameText) == "table"
      and type(nameText.GetParent) == "function"
      and nameText:GetParent()
    or nil
  if type(nameParent) == "table" and type(nameParent.CreateTexture) == "function" then
    return nameParent
  end
  return nil
end

local function ClearApplicantBonusMarker(member)
  if type(member) ~= "table" then
    return
  end
  if member._isiLiveBonusText and type(member._isiLiveBonusText.SetText) == "function" then
    member._isiLiveBonusText:SetText("")
    if type(member._isiLiveBonusText.Hide) == "function" then
      member._isiLiveBonusText:Hide()
    end
  end
  if member._isiLiveBonusBadge and type(member._isiLiveBonusBadge.SetText) == "function" then
    member._isiLiveBonusBadge:SetText("")
    if type(member._isiLiveBonusBadge.Hide) == "function" then
      member._isiLiveBonusBadge:Hide()
    end
  end
  HideApplicantBonusIcons(member)
end

local function EnsureApplicantFlagTexture(member)
  local textureOwner = ResolveApplicantBonusTextureOwner(member)
  if type(member) ~= "table" or not textureOwner then
    return nil
  end
  if type(member._isiApplicantFlagTex) == "table" then
    return member._isiApplicantFlagTex
  end
  local tex = textureOwner:CreateTexture(nil, "OVERLAY")
  if type(tex.SetSize) == "function" then
    tex:SetSize(FLAG_WIDTH, FLAG_HEIGHT)
  end
  if type(tex.Hide) == "function" then
    tex:Hide()
  end
  member._isiApplicantFlagTex = tex
  return tex
end

local function RestoreApplicantNameAnchor(member)
  if type(member) ~= "table" then
    return
  end
  local nameText = rawget(member, "Name")
  local stored = rawget(member, "_isiApplicantNameOriginalPoint")
  if
    type(nameText) ~= "table"
    or type(stored) ~= "table"
    or type(nameText.SetPoint) ~= "function"
  then
    return
  end
  if type(nameText.ClearAllPoints) == "function" then
    nameText:ClearAllPoints()
  end
  nameText:SetPoint(stored.point, stored.relativeTo, stored.relativePoint, stored.offsetX, stored.offsetY)
end

local function AnchorApplicantFlag(member, nameText, tex)
  if
    type(member) ~= "table"
    or type(nameText) ~= "table"
    or type(tex) ~= "table"
    or type(tex.SetPoint) ~= "function"
    or type(nameText.SetPoint) ~= "function"
  then
    return
  end
  local stored = rawget(member, "_isiApplicantNameOriginalPoint")
  if type(stored) ~= "table" and type(nameText.GetPoint) == "function" then
    local point, relativeTo, relativePoint, offsetX, offsetY = nameText:GetPoint(1)
    if type(point) == "string" then
      stored = {
        point = point,
        relativeTo = relativeTo or member,
        relativePoint = relativePoint or point,
        offsetX = tonumber(offsetX) or 0,
        offsetY = tonumber(offsetY) or 0,
      }
      member._isiApplicantNameOriginalPoint = stored
    end
  end
  if type(stored) ~= "table" then
    if type(tex.ClearAllPoints) == "function" then
      tex:ClearAllPoints()
    end
    tex:SetPoint("LEFT", member, "LEFT", 6, 0)
    return
  end
  if type(tex.ClearAllPoints) == "function" then
    tex:ClearAllPoints()
  end
  tex:SetPoint(stored.point, stored.relativeTo, stored.relativePoint, stored.offsetX, stored.offsetY)
  if type(nameText.ClearAllPoints) == "function" then
    nameText:ClearAllPoints()
  end
  nameText:SetPoint(
    stored.point,
    stored.relativeTo,
    stored.relativePoint,
    stored.offsetX + APPLICANT_FLAG_NAME_SHIFT_X,
    stored.offsetY
  )
end

local function ApplyApplicantFlagToMemberFrame(member, applicantID, memberIndex)
  if type(member) ~= "table" then
    return
  end
  local tex = EnsureApplicantFlagTexture(member)
  if not tex then
    return
  end
  local function hide()
    if type(tex.Hide) == "function" then
      tex:Hide()
    end
    RestoreApplicantNameAnchor(member)
  end
  if not lfgFlagsEnabled then
    hide()
    return
  end
  applicantID = ReadPositiveNumber(applicantID)
  memberIndex = ReadPositiveNumber(memberIndex or rawget(member, "memberIdx"))
  if not applicantID or not memberIndex then
    hide()
    return
  end
  member._isiApplicantID = applicantID
  member._isiApplicantMemberIndex = memberIndex
  local applicantMember = ReadApplicantMemberInfo(applicantID, memberIndex)
  local tag = applicantMember and ResolveLanguageTagFromName(applicantMember.name)
  local path = tag and type(getFlagTexturePath) == "function" and getFlagTexturePath(tag)
  if not path then
    hide()
    return
  end
  if type(tex.SetTexture) == "function" then
    tex:SetTexture(path)
  end
  local nameText = rawget(member, "Name")
  AnchorApplicantFlag(member, nameText, tex)
  if type(tex.Show) == "function" then
    tex:Show()
  end
end

local function AnchorApplicantBonusIcon(member, icon, index)
  if type(member) ~= "table" or type(icon) ~= "table" or type(icon.SetPoint) ~= "function" then
    return
  end
  if type(icon.ClearAllPoints) == "function" then
    icon:ClearAllPoints()
  end
  if index and index > 1 and type(member._isiLiveBonusBadgeIcons) == "table" then
    local previousIcon = member._isiLiveBonusBadgeIcons[index - 1]
    if type(previousIcon) == "table" then
      icon:SetPoint("LEFT", previousIcon, "RIGHT", APPLICANT_BONUS_ICON_GAP, 0)
      return
    end
  end
  local roleAnchor = ResolveApplicantRoleAnchor(member)
  if roleAnchor then
    icon:SetPoint("LEFT", roleAnchor, "RIGHT", 5, 0)
    return
  end
  icon:SetPoint("LEFT", member, "LEFT", 104, 0)
end

local function ApplyApplicantBonusIconMarkers(member, markerCount)
  markerCount = math.min(SEARCH_RESULT_BONUS_MAX_MARKERS, math.floor(tonumber(markerCount) or 0))
  local textureOwner = ResolveApplicantBonusTextureOwner(member)
  if markerCount <= 0 or type(member) ~= "table" or not textureOwner then
    return false
  end
  member._isiLiveBonusBadgeIcons = member._isiLiveBonusBadgeIcons or {}
  for index = 1, SEARCH_RESULT_BONUS_MAX_MARKERS do
    local icon = member._isiLiveBonusBadgeIcons[index]
    if type(icon) ~= "table" then
      icon = textureOwner:CreateTexture(nil, "OVERLAY")
      member._isiLiveBonusBadgeIcons[index] = icon
    end
    if type(icon) == "table" then
      if type(icon.SetSize) == "function" then
        icon:SetSize(APPLICANT_BONUS_ICON_SIZE, APPLICANT_BONUS_ICON_SIZE)
      end
      if type(icon.SetTexture) == "function" then
        icon:SetTexture(SEARCH_RESULT_BONUS_TEXTURE)
      end
      if type(icon.SetTexCoord) == "function" then
        icon:SetTexCoord(0, 1, 0, 1)
      end
      if type(icon.SetVertexColor) == "function" then
        icon:SetVertexColor(1, 1, 1, 1)
      end
      AnchorApplicantBonusIcon(member, icon, index)
      if index <= markerCount then
        if type(icon.Show) == "function" then
          icon:Show()
        end
      elseif type(icon.Hide) == "function" then
        icon:Hide()
      end
    end
  end
  return true
end

local function ApplyApplicantBonusToMemberFrame(member, applicantID, memberIndex)
  if type(member) ~= "table" then
    return
  end
  hookedApplicantMembers[member] = true
  ApplyApplicantFlagToMemberFrame(member, applicantID, memberIndex)
  applicantID = ReadPositiveNumber(applicantID)
  memberIndex = ReadPositiveNumber(memberIndex or rawget(member, "memberIdx"))
  local badge, markerCount
  if applicantID and memberIndex then
    badge, _, markerCount = BuildSingleApplicantMemberBadge(applicantID, memberIndex)
  end
  local nameText = rawget(member, "Name")
  if type(nameText) ~= "table" or type(nameText.GetText) ~= "function" or type(nameText.SetText) ~= "function" then
    return
  end
  ClearApplicantBonusMarker(member)
  if not badge then
    return
  end
  if ApplyApplicantBonusIconMarkers(member, markerCount) then
    return
  end
end

local function HookApplicantButton(button, applicantIDOverride)
  if not button or hookedApplicants[button] then
    ApplyApplicantBonusToButton(button, applicantIDOverride)
    return
  end
  hookedApplicants[button] = true
  if type(button.HookScript) == "function" then
    button:HookScript("OnEnter", function(self)
      ApplyApplicantBonusToButton(self)
    end)
  end
  local inviteButton = rawget(button, "InviteButton")
  if
    type(inviteButton) == "table"
    and type(inviteButton.HookScript) == "function"
    and not hookedApplicants[inviteButton]
  then
    hookedApplicants[inviteButton] = true
    inviteButton:HookScript("OnEnter", function(self)
      ApplyApplicantBonusToButton(self, ResolveApplicantIDFromButton(button))
    end)
  end
  ApplyApplicantBonusToButton(button, applicantIDOverride)
end

local function HookApplicantButtonsFromViewer(viewer)
  if type(viewer) ~= "table" then
    return
  end
  local scrollFrame = rawget(viewer, "ScrollFrame")
  local buttons = type(scrollFrame) == "table" and rawget(scrollFrame, "buttons") or nil
  if type(buttons) == "table" then
    for _, button in ipairs(buttons) do
      HookApplicantButton(button)
    end
  end
  local scrollBox = rawget(viewer, "ScrollBox")
  if type(scrollBox) == "table" and type(scrollBox.GetFrames) == "function" then
    for _, button in pairs(scrollBox:GetFrames() or {}) do
      HookApplicantButton(button)
    end
  end
end

local function HookNamedApplicantButtons()
  for index = 1, 20 do
    local button = rawget(_G, "LFGListApplicationViewerScrollFrameButton" .. tostring(index))
    if type(button) == "table" then
      HookApplicantButton(button)
    end
  end
end

local function HookApplicationViewer()
  local LFGListFrameRef = rawget(_G, "LFGListFrame")
  local viewer = LFGListFrameRef and rawget(LFGListFrameRef, "ApplicationViewer") or nil
  HookApplicantButtonsFromViewer(viewer)
  HookNamedApplicantButtons()

  local ScrollBoxUtil_ref = rawget(_G, "ScrollBoxUtil")
  local scrollBox = type(viewer) == "table" and rawget(viewer, "ScrollBox") or nil
  if type(ScrollBoxUtil_ref) == "table" and type(ScrollBoxUtil_ref.OnViewFramesChanged) == "function" and scrollBox then
    ScrollBoxUtil_ref:OnViewFramesChanged(scrollBox, function(buttons)
      if type(buttons) == "table" then
        for _, button in pairs(buttons) do
          HookApplicantButton(button)
        end
      end
    end)
  end

  pcall(hooksecurefunc, "LFGListApplicationViewer_UpdateResults", function(self)
    HookApplicantButtonsFromViewer(self)
    HookNamedApplicantButtons()
  end)
  pcall(hooksecurefunc, "LFGListApplicationViewer_UpdateApplicant", function(button, applicantID)
    HookApplicantButton(button, applicantID)
  end)
  pcall(hooksecurefunc, "LFGListApplicationViewer_UpdateApplicantMember", function(member, applicantID, memberIndex)
    ApplyApplicantBonusToMemberFrame(member, applicantID, memberIndex)
  end)
  pcall(hooksecurefunc, "LFGListApplicantMember_OnEnter", function(member)
    HideApplicantProvingGroundTooltipLines()
    local parent = type(member) == "table" and type(member.GetParent) == "function" and member:GetParent() or nil
    local applicantID = parent and rawget(parent, "applicantID") or nil
    local memberIndex = type(member) == "table" and rawget(member, "memberIdx") or nil
    local suffix = BuildSingleApplicantMemberSuffix(applicantID, memberIndex)
    local tooltip = rawget(_G, "GameTooltip")
    if
      suffix
      and type(tooltip) == "table"
      and type(tooltip.AddLine) == "function"
      and type(tooltip.Show) == "function"
    then
      tooltip:AddLine(" ")
      local tooltipText = ResolveLocalizedText("LFG_BONUS_TOOLTIP_FMT") or "isiLive Bonus: %s"
      tooltip:AddLine(string.format(tooltipText, suffix), 0.20, 1.00, 0.20)
      tooltip:Show()
    end
  end)
end

-- -------------------------------------------------------------------------
-- Per-button flag texture
-- -------------------------------------------------------------------------

local function EnsureFlagTexture(button)
  if button._isiFlagTex then
    return button._isiFlagTex
  end
  local tex = button:CreateTexture(nil, "OVERLAY")
  tex:SetSize(FLAG_WIDTH, FLAG_HEIGHT)
  tex:SetPoint("LEFT", button, "LEFT", SEARCH_RESULT_FLAG_X, SEARCH_RESULT_FLAG_Y)

  tex:Hide()
  button._isiFlagTex = tex
  return tex
end

local function StripSearchResultKeystoneSuffix(text)
  if type(text) ~= "string" or text == "" then
    return text
  end
  local labels = {}
  local liveLabel = rawget(_G, "DUNGEON_DIFFICULTY_MYTHIC_KEYSTONE")
  if type(liveLabel) == "string" and liveLabel ~= "" then
    labels[liveLabel] = true
  end
  for label in pairs(SEARCH_RESULT_KEYSTONE_LABELS) do
    labels[label] = true
  end
  for label in pairs(labels) do
    local suffix = " (" .. label .. ")"
    if string.sub(text, -string.len(suffix)) == suffix then
      return string.sub(text, 1, string.len(text) - string.len(suffix))
    end
  end
  return text
end

local function ApplySearchResultActivityNameText(activityName)
  if
    type(activityName) ~= "table"
    or type(activityName.GetText) ~= "function"
    or type(activityName.SetText) ~= "function"
  then
    return
  end
  if rawget(activityName, "_isiActivityNameCleaning") == true then
    return
  end
  local currentText = activityName:GetText()
  local displayText = StripSearchResultKeystoneSuffix(currentText)
  if displayText == currentText then
    return
  end
  activityName._isiActivityNameCleaning = true
  activityName:SetText(displayText)
  activityName._isiActivityNameCleaning = nil
end

local function HookSearchResultActivityNameText(activityName)
  if
    type(activityName) ~= "table"
    or rawget(activityName, "_isiActivityNameTextHooked") == true
    or type(activityName.SetText) ~= "function"
  then
    return
  end
  local hooksecurefuncRef = rawget(_G, "hooksecurefunc")
  if type(hooksecurefuncRef) ~= "function" then
    return
  end
  activityName._isiActivityNameTextHooked = true
  pcall(hooksecurefuncRef, activityName, "SetText", function(self)
    ApplySearchResultActivityNameText(self)
  end)
end

local function GetStoredActivityNamePoint(button, activityName)
  local stored = rawget(button, "_isiActivityNameOriginalPoint")
  if type(stored) == "table" and rawget(button, "_isiActivityNameOriginalRegion") == activityName then
    return stored
  end
  if type(activityName.GetPoint) ~= "function" then
    return nil
  end
  local point, relativeTo, relativePoint, offsetX, offsetY = activityName:GetPoint(1)
  if type(point) ~= "string" then
    return nil
  end
  stored = {
    point = point,
    relativeTo = relativeTo or button,
    relativePoint = relativePoint or point,
    offsetX = tonumber(offsetX) or 0,
    offsetY = tonumber(offsetY) or 0,
  }
  button._isiActivityNameOriginalPoint = stored
  button._isiActivityNameOriginalRegion = activityName
  return stored
end

local function GetStoredPlaystylePoint(button, playstyle)
  local stored = rawget(button, "_isiPlaystyleOriginalPoint")
  if type(stored) == "table" and rawget(button, "_isiPlaystyleOriginalRegion") == playstyle then
    return stored
  end
  if type(playstyle) ~= "table" or type(playstyle.GetPoint) ~= "function" then
    return nil
  end
  local point, relativeTo, relativePoint, offsetX, offsetY = playstyle:GetPoint(1)
  if type(point) ~= "string" then
    return nil
  end
  stored = {
    point = point,
    relativeTo = relativeTo or button,
    relativePoint = relativePoint or point,
    offsetX = tonumber(offsetX) or 0,
    offsetY = tonumber(offsetY) or 0,
  }
  button._isiPlaystyleOriginalPoint = stored
  button._isiPlaystyleOriginalRegion = playstyle
  return stored
end

local function RestoreSearchResultPlaystyle(button, activityName, playstyleOriginalPoint)
  local playstyle = rawget(button, "Playstyle")
  if
    type(playstyle) ~= "table"
    or type(playstyle.SetPoint) ~= "function"
    or type(playstyleOriginalPoint) ~= "table"
  then
    return
  end
  local offsetX = playstyleOriginalPoint.offsetX
  if playstyleOriginalPoint.relativeTo == activityName then
    offsetX = offsetX - SEARCH_RESULT_DUNGEON_NAME_SHIFT_X
  end
  if type(playstyle.ClearAllPoints) == "function" then
    playstyle:ClearAllPoints()
  end
  playstyle:SetPoint(
    playstyleOriginalPoint.point,
    playstyleOriginalPoint.relativeTo,
    playstyleOriginalPoint.relativePoint,
    offsetX,
    playstyleOriginalPoint.offsetY
  )
end

local function AnchorSearchResultDungeonName(button)
  local activityName = rawget(button, "ActivityName")
  if type(activityName) ~= "table" or type(activityName.SetPoint) ~= "function" then
    return
  end
  HookSearchResultActivityNameText(activityName)
  local originalPoint = GetStoredActivityNamePoint(button, activityName)
  local playstyleOriginalPoint = GetStoredPlaystylePoint(button, rawget(button, "Playstyle"))
  if originalPoint then
    if type(activityName.ClearAllPoints) == "function" then
      activityName:ClearAllPoints()
    end
    activityName:SetPoint(
      originalPoint.point,
      originalPoint.relativeTo,
      originalPoint.relativePoint,
      originalPoint.offsetX + SEARCH_RESULT_DUNGEON_NAME_SHIFT_X,
      originalPoint.offsetY
    )

    local flagTex = EnsureFlagTexture(button)
    if type(flagTex.ClearAllPoints) == "function" then
      flagTex:ClearAllPoints()
    end
    flagTex:SetPoint(
      originalPoint.point,
      originalPoint.relativeTo,
      originalPoint.relativePoint,
      originalPoint.offsetX,
      originalPoint.offsetY + SEARCH_RESULT_FLAG_ACTIVITY_NAME_OFFSET_Y
    )
    RestoreSearchResultPlaystyle(button, activityName, playstyleOriginalPoint)
  end
  ApplySearchResultActivityNameText(activityName)
end

local function ApplyFlagToButton(button, resultID)
  local tex = EnsureFlagTexture(button)
  local tag = lfgFlagsEnabled and resultID and GetTagForResult(resultID)
  local path = tag and type(getFlagTexturePath) == "function" and getFlagTexturePath(tag)
  if path then
    tex:SetTexture(path)
    tex:Show()
  else
    tex:Hide()
  end
end

local function ConfigureSearchResultBonusBadgeText(badgeText)
  if type(badgeText.SetJustifyH) == "function" then
    badgeText:SetJustifyH("RIGHT")
  end
  if type(badgeText.SetWidth) == "function" then
    badgeText:SetWidth(SEARCH_RESULT_BONUS_WIDTH)
  end
  if type(badgeText.SetHeight) == "function" then
    badgeText:SetHeight(14)
  end
  if type(badgeText.SetShadowColor) == "function" then
    badgeText:SetShadowColor(0, 0, 0, 1)
  end
  if type(badgeText.SetShadowOffset) == "function" then
    badgeText:SetShadowOffset(1, -1)
  end
end

local function EnsureSearchResultBonusBadges(button)
  if type(button._isiSearchBonusBadges) == "table" then
    return button._isiSearchBonusBadges
  end
  if type(button.CreateFontString) ~= "function" then
    return nil
  end
  local badges = {}
  local badgeText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ConfigureSearchResultBonusBadgeText(badgeText)
  if type(badgeText.Hide) == "function" then
    badgeText:Hide()
  end
  badges[1] = badgeText
  button._isiSearchBonusBadges = badges
  return badges
end

local function AnchorSearchResultBonusBadge(button, badgeText)
  if type(badgeText) ~= "table" or type(badgeText.SetPoint) ~= "function" then
    return
  end
  if type(badgeText.ClearAllPoints) == "function" then
    badgeText:ClearAllPoints()
  end
  badgeText:SetPoint("RIGHT", button, "RIGHT", SEARCH_RESULT_BONUS_RIGHT_X, SEARCH_RESULT_BONUS_Y)
end

local function HideSearchResultBonusBadges(badges)
  if type(badges) ~= "table" then
    return
  end
  for _, badgeText in ipairs(badges) do
    if type(badgeText) == "table" then
      if type(badgeText.SetText) == "function" then
        badgeText:SetText("")
      end
      if type(badgeText.Hide) == "function" then
        badgeText:Hide()
      end
    end
  end
end

local function ApplySearchResultBonusBadge(button, resultID)
  local badges = EnsureSearchResultBonusBadges(button)
  if not badges then
    return
  end
  if IsSearchResultPromotionOfferedRow(button) then
    HideSearchResultBonusBadges(badges)
    return
  end
  local badge, badgeColor
  if lfgGroupBonusesEnabled then
    badge, badgeColor = BuildSearchResultBonusBadge(resultID)
  end
  if not badge then
    HideSearchResultBonusBadges(badges)
    return
  end
  local badgeText = badges[1]
  AnchorSearchResultBonusBadge(button, badgeText)
  if badgeColor and type(badgeText.SetTextColor) == "function" then
    badgeText:SetTextColor(badgeColor[1], badgeColor[2], badgeColor[3], badgeColor[4])
  end
  badgeText:SetText(badge)
  if type(badgeText.Show) == "function" then
    badgeText:Show()
  end
end

-- -------------------------------------------------------------------------
-- Hooking search-result buttons
-- -------------------------------------------------------------------------

local function UpdateButton(button)
  -- resultID is a direct field on the Blizzard LFG search result button.
  local resultID = rawget(button, "resultID")
  AnchorSearchResultDungeonName(button)
  ApplyFlagToButton(button, resultID)
  ApplySearchResultBonusBadge(button, resultID)
end

local function HookButton(button)
  if not button or hooked[button] then
    return
  end
  hooked[button] = true
  button:HookScript("OnEnter", function(self)
    UpdateButton(self)
    ApplyGroupBonusTooltipLines(rawget(self, "resultID"))
    local C_Timer_ref = rawget(_G, "C_Timer")
    if type(C_Timer_ref) == "table" and type(C_Timer_ref.After) == "function" then
      C_Timer_ref.After(0, function()
        ApplyGroupBonusTooltipLines(rawget(self, "resultID"))
      end)
    end
  end)
  UpdateButton(button)
end

local function HookButtons(buttons)
  for _, btn in pairs(buttons) do
    HookButton(btn)
  end
end

local function RefreshAll()
  for btn in pairs(hooked) do
    UpdateButton(btn)
  end
end

-- -------------------------------------------------------------------------
-- Panel wiring
-- -------------------------------------------------------------------------

-- Expose internal helpers under addonTable._LFGFlagsInternal so the
-- test suite can drive them directly. The production code paths
-- continue to call the local references; assigning them to LI is
-- behaviour-neutral.
LI.SplitNameRealm = SplitNameRealm
LI.GetTagForResult = GetTagForResult
LI.EnsureFlagTexture = EnsureFlagTexture
LI.StripSearchResultKeystoneSuffix = StripSearchResultKeystoneSuffix
LI.ApplySearchResultActivityNameText = ApplySearchResultActivityNameText
LI.HookSearchResultActivityNameText = HookSearchResultActivityNameText
LI.AnchorSearchResultDungeonName = AnchorSearchResultDungeonName
LI.ApplyFlagToButton = ApplyFlagToButton
LI.UpdateButton = UpdateButton
LI.HookButton = HookButton
LI.HookButtons = HookButtons
LI.RefreshAll = RefreshAll
LI.BuildBonusSuffix = BuildBonusSuffix
LI.BuildSearchResultMemberBonuses = BuildSearchResultMemberBonuses
LI.BuildSearchResultBonusBadge = BuildSearchResultBonusBadge
LI.BuildApplicantMemberBonuses = BuildApplicantMemberBonuses
LI.ApplyApplicantBonusToMemberFrame = ApplyApplicantBonusToMemberFrame
LI.ApplyApplicantFlagToMemberFrame = ApplyApplicantFlagToMemberFrame
LI.ApplyApplicantBonusToButton = ApplyApplicantBonusToButton
LI.ApplyGroupBonusTooltipLines = ApplyGroupBonusTooltipLines
LI.ResolvePlayerBonusProfile = ResolvePlayerBonusProfile
LI.BuildApplicantBonusBadge = BuildApplicantBonusBadge
LI.BuildApplicantBonusMarkerBadge = BuildApplicantBonusMarkerBadge
LI.ResolveApplicantRoleAnchor = ResolveApplicantRoleAnchor
LI.AnchorApplicantBonusBadge = AnchorApplicantBonusBadge
LI.IsSearchResultPromotionOfferedRow = IsSearchResultPromotionOfferedRow
LI.ResetCacheForTests = function()
  resultTagCache = {}
  resultBonusBadgeCache = {}
  resultMemberBonusCache = {}
end
LI.GetCacheForTests = function()
  return resultTagCache
end

function LFGFlags.HookSearchPanel()
  local LFGListFrameRef = rawget(_G, "LFGListFrame")
  if not LFGListFrameRef or not LFGListFrameRef.SearchPanel or not LFGListFrameRef.SearchPanel.ScrollBox then
    return
  end
  local searchBox = LFGListFrameRef.SearchPanel.ScrollBox
  HookApplicationViewer()

  local ScrollBoxUtil_ref = rawget(_G, "ScrollBoxUtil")
  if type(ScrollBoxUtil_ref) == "table" and type(ScrollBoxUtil_ref.OnViewFramesChanged) == "function" then
    ScrollBoxUtil_ref:OnViewFramesChanged(searchBox, HookButtons)
    if type(ScrollBoxUtil_ref.OnViewScrollChanged) == "function" then
      ScrollBoxUtil_ref:OnViewScrollChanged(searchBox, RefreshAll)
    end
  else
    -- ScrollBoxUtil not available: hook on search results event instead.
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    eventFrame:SetScript("OnEvent", function()
      C_Timer.After(0.1, function()
        if type(searchBox.GetFrames) == "function" then
          HookButtons(searchBox:GetFrames() or {})
        end
        -- resultID is set by Blizzard after the initial populate; refresh again.
        C_Timer.After(0.3, RefreshAll)
      end)
    end)
  end

  -- Clear result cache on new search so stale language data is not shown.
  pcall(hooksecurefunc, "LFGListSearchPanel_DoSearch", function()
    resultTagCache = {}
    ClearSearchResultBonusCache()
  end)

  -- Extra trigger: update the specific button when Blizzard activates it.
  pcall(hooksecurefunc, "LFGListUtil_SetSearchEntryTooltip", function(_, resultID)
    if not resultID then
      return
    end
    ClearSearchResultBonusCache(resultID)
    for btn in pairs(hooked) do
      if rawget(btn, "resultID") == resultID then
        ApplyFlagToButton(btn, resultID)
        ApplySearchResultBonusBadge(btn, resultID)
      end
    end
    ApplyGroupBonusTooltipLines(resultID)
  end)
end

-- -------------------------------------------------------------------------
-- Public: called from factory
-- -------------------------------------------------------------------------

function LFGFlags.SetEnabled(enabled)
  lfgFlagsEnabled = enabled ~= false
  if not lfgFlagsEnabled then
    for btn in pairs(hooked) do
      local tex = rawget(btn, "_isiFlagTex")
      if tex and type(tex.Hide) == "function" then
        tex:Hide()
      end
    end
    for member in pairs(hookedApplicantMembers) do
      local tex = rawget(member, "_isiApplicantFlagTex")
      if tex and type(tex.Hide) == "function" then
        tex:Hide()
      end
    end
  else
    for btn in pairs(hooked) do
      UpdateButton(btn)
    end
    for member in pairs(hookedApplicantMembers) do
      ApplyApplicantFlagToMemberFrame(
        member,
        rawget(member, "_isiApplicantID"),
        rawget(member, "_isiApplicantMemberIndex") or rawget(member, "memberIdx")
      )
    end
  end
end

function LFGFlags.SetGroupBonusesEnabled(enabled)
  lfgGroupBonusesEnabled = enabled ~= false
  ClearSearchResultBonusCache()
  for btn in pairs(hooked) do
    ApplySearchResultBonusBadge(btn, rawget(btn, "resultID"))
  end
  if lfgGroupBonusesEnabled then
    return
  end
  for member in pairs(hookedApplicantMembers) do
    ClearApplicantBonusMarker(member)
  end
end

function LFGFlags.Register(deps)
  if type(deps) ~= "table" then
    return
  end

  local localeModule = deps.localeModule
  getRealmInfoLib = deps.getRealmInfoLib

  if type(localeModule) == "table" then
    if type(localeModule.GetUnitServerLanguage) == "function" then
      getLanguageTag = function(realm)
        return localeModule.GetUnitServerLanguage(nil, realm, getRealmInfoLib)
      end
    end
    if type(localeModule.GetLanguageFlagTexturePath) == "function" then
      getFlagTexturePath = function(tag)
        return localeModule.GetLanguageFlagTexturePath(tag)
      end
    end
  end

  local LFGListFrameRef = rawget(_G, "LFGListFrame")
  if LFGListFrameRef and LFGListFrameRef.SearchPanel then
    LFGFlags.HookSearchPanel()
  else
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(self, _, name)
      if name ~= "Blizzard_LFGList" then
        return
      end
      self:UnregisterEvent("ADDON_LOADED")
      LFGFlags.HookSearchPanel()
    end)
  end
end
