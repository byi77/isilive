local _, addonTable = ...

addonTable = addonTable or {}

local Locale = {}
addonTable.Locale = Locale

local LANGUAGE_FLAG_TEXTURE_BY_TAG = {
  DE = "Interface\\AddOns\\isiLive\\media\\flags\\de",
  EN = "Interface\\AddOns\\isiLive\\media\\flags\\en",
  FR = "Interface\\AddOns\\isiLive\\media\\flags\\fr",
  ES = "Interface\\AddOns\\isiLive\\media\\flags\\es",
  IT = "Interface\\AddOns\\isiLive\\media\\flags\\it",
  PT = "Interface\\AddOns\\isiLive\\media\\flags\\pt",
  RU = "Interface\\AddOns\\isiLive\\media\\flags\\ru",
  TR = "Interface\\AddOns\\isiLive\\media\\flags\\tr",
}

local LANGUAGE_NAME_BY_LOCALE = {
  enUS = {
    CN = "Chinese",
    DE = "German",
    EN = "English",
    ES = "Spanish",
    FR = "French",
    IT = "Italian",
    KR = "Korean",
    PT = "Portuguese",
    RU = "Russian",
    TR = "Turkish",
    TW = "Taiwanese",
  },
  deDE = {
    CN = "Chinesisch",
    DE = "Deutsch",
    EN = "Englisch",
    ES = "Spanisch",
    FR = "Franzoesisch",
    IT = "Italienisch",
    KR = "Koreanisch",
    PT = "Portugiesisch",
    RU = "Russisch",
    TR = "Tuerkisch",
    TW = "Taiwanesisch",
  },
  frFR = {
    CN = "Chinois",
    DE = "Allemand",
    EN = "Anglais",
    ES = "Espagnol",
    FR = "Francais",
    IT = "Italien",
    KR = "Coreen",
    PT = "Portugais",
    RU = "Russe",
    TR = "Turc",
    TW = "Taiwanais",
  },
  esES = {
    CN = "Chino",
    DE = "Aleman",
    EN = "Ingles",
    ES = "Espanol",
    FR = "Frances",
    IT = "Italiano",
    KR = "Coreano",
    PT = "Portugues",
    RU = "Ruso",
    TR = "Turco",
    TW = "Taiwanes",
  },
  ptBR = {
    CN = "Chines",
    DE = "Alemao",
    EN = "Ingles",
    ES = "Espanhol",
    FR = "Frances",
    IT = "Italiano",
    KR = "Coreano",
    PT = "Portugues",
    RU = "Russo",
    TR = "Turco",
    TW = "Taiwanes",
  },
  itIT = {
    CN = "Cinese",
    DE = "Tedesco",
    EN = "Inglese",
    ES = "Spagnolo",
    FR = "Francese",
    IT = "Italiano",
    KR = "Coreano",
    PT = "Portoghese",
    RU = "Russo",
    TR = "Turco",
    TW = "Taiwanese",
  },
  ruRU = {
    CN = "Kitaiskii",
    DE = "Nemetskii",
    EN = "Angliiskii",
    ES = "Ispanskii",
    FR = "Frantsuzskii",
    IT = "Italyanskii",
    KR = "Koreiskii",
    PT = "Portugalskii",
    RU = "Russkii",
    TR = "Turetskii",
    TW = "Taivanskii",
  },
  trTR = {
    CN = "Cince",
    DE = "Almanca",
    EN = "Ingilizce",
    ES = "Ispanyolca",
    FR = "Fransizca",
    IT = "Italyanca",
    KR = "Korece",
    PT = "Portekizce",
    RU = "Rusca",
    TR = "Turkce",
    TW = "Tayvan Cincesi",
  },
}

function Locale.ResolveLocaleTag(tag)
  return addonTable.Languages.ResolveTag(tag)
end

function Locale.LocaleToLanguageTag(localeTag)
  if not localeTag then
    return "??"
  end
  local normalized = tostring(localeTag):gsub("%-", ""):lower()
  if normalized == "dede" then
    return "DE"
  end
  if normalized == "enus" or normalized == "engb" then
    return "EN"
  end
  if normalized == "frfr" then
    return "FR"
  end
  if normalized == "eses" or normalized == "esmx" then
    return "ES"
  end
  if normalized == "ruru" then
    return "RU"
  end
  if normalized == "itit" then
    return "IT"
  end
  if normalized == "trtr" then
    return "TR"
  end
  if normalized == "ptbr" or normalized == "ptpt" then
    return "PT"
  end
  -- KR/CN/TW: tags are recognized but have no flag asset in
  -- LANGUAGE_FLAG_TEXTURE_BY_TAG → GetLanguageFlagMarkup returns "??".
  if normalized == "kokr" then
    return "KR"
  end
  if normalized == "zhcn" then
    return "CN"
  end
  if normalized == "zhtw" then
    return "TW"
  end
  return "??"
end

function Locale.GetLanguageFlagTexturePath(languageTag)
  local tag = languageTag and tostring(languageTag):upper() or "??"
  return LANGUAGE_FLAG_TEXTURE_BY_TAG[tag]
end

function Locale.GetLanguageFlagMarkup(languageTag)
  local tag = languageTag and tostring(languageTag):upper() or "??"
  local texturePath = LANGUAGE_FLAG_TEXTURE_BY_TAG[tag]
  if not texturePath then
    -- Show the language tag as text instead of a generic "??" so that
    -- KR/CN/TW players see recognizable abbreviations instead of question marks.
    return string.format("|cffbfbfbf%s|r", tag)
  end
  return string.format("|T%s:12:16:0:0|t", texturePath)
end

function Locale.GetLanguageDisplayName(languageTag, localeTag)
  local tag = languageTag and tostring(languageTag):upper() or "??"
  local displayLocale = Locale.ResolveLocaleTag(localeTag or (rawget(_G, "GetLocale") and GetLocale() or nil))
  local localeNames = LANGUAGE_NAME_BY_LOCALE[displayLocale] or LANGUAGE_NAME_BY_LOCALE.enUS
  return localeNames[tag] or tag
end

function Locale.GetLanguageTooltipMarkup(languageTag, localeTag)
  local flagMarkup = Locale.GetLanguageFlagMarkup(languageTag)
  local displayLocale = Locale.ResolveLocaleTag(localeTag or (rawget(_G, "GetLocale") and GetLocale() or nil))
  local displayName = Locale.GetLanguageDisplayName(languageTag, displayLocale)
  if displayName == "" then
    return flagMarkup
  end
  if flagMarkup == "" then
    return displayName
  end
  return string.format("%s %s", flagMarkup, displayName)
end

function Locale.NormalizeRealmLookupKey(realm)
  if not realm then
    return ""
  end
  return addonTable.StringUtils.NormalizeRealmName(tostring(realm)):lower()
end

function Locale.GetRealmLocaleFromStaticData(realm)
  if not realm or realm == "" then
    return nil
  end

  local RealmData = addonTable.RealmData or {}
  local exactLookup = RealmData.IsiLiveRealmLocaleByExactName
  if type(exactLookup) == "table" then
    local exactLocale = exactLookup[tostring(realm):lower()]
    if exactLocale then
      return exactLocale
    end
  end

  local normalizedLookup = RealmData.IsiLiveRealmLocaleByNormalizedName
  if type(normalizedLookup) == "table" then
    local normalizedLocale = normalizedLookup[Locale.NormalizeRealmLookupKey(realm)]
    if normalizedLocale then
      return normalizedLocale
    end
  end

  return nil
end

local IsExistingUnit = addonTable.Validators.IsExistingUnit

function Locale.GetUnitServerLanguage(unit, realm, getRealmInfoLib)
  if not realm or realm == "" then
    local getRealmName = rawget(_G, "GetRealmName")
    realm = type(getRealmName) == "function" and getRealmName() or ""
  end

  local staticLocale = Locale.GetRealmLocaleFromStaticData(realm)
  if staticLocale then
    return Locale.LocaleToLanguageTag(staticLocale)
  end

  local lib = type(getRealmInfoLib) == "function" and getRealmInfoLib() or nil
  if lib and IsExistingUnit(unit) then
    local unitGUID = rawget(_G, "UnitGUID")
    if type(unitGUID) == "function" then
      local okGuid, guid = pcall(unitGUID, unit)
      if okGuid and guid then
        local _, _, _, _, realmLocale = lib:GetRealmInfoByGUID(guid)
        if realmLocale then
          return Locale.LocaleToLanguageTag(realmLocale)
        end
      end
    end
  end

  if lib and realm and realm ~= "" then
    local _, _, _, _, realmLocale = lib:GetRealmInfo(realm)
    if realmLocale then
      return Locale.LocaleToLanguageTag(realmLocale)
    end
  end

  local unitIsUnit = rawget(_G, "UnitIsUnit")
  if IsExistingUnit(unit) and type(unitIsUnit) == "function" and unitIsUnit(unit, "player") then
    return Locale.LocaleToLanguageTag(GetLocale())
  end

  return "??"
end
