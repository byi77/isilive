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
}

function Locale.ResolveLocaleTag(tag)
  if not tag then
    return "enUS"
  end
  local normalized = string.lower(tostring(tag))
  if normalized == "de" or normalized == "dede" then
    return "deDE"
  end
  return "enUS"
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
  if normalized == "ptbr" or normalized == "ptpt" then
    return "PT"
  end
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

function Locale.GetLanguageFlagMarkup(languageTag)
  local tag = languageTag and tostring(languageTag):upper() or "??"
  local texturePath = LANGUAGE_FLAG_TEXTURE_BY_TAG[tag]
  if not texturePath then
    return "|cffbfbfbf??|r"
  end
  return string.format("|T%s:14:10:0:0|t", texturePath)
end

function Locale.NormalizeRealmLookupKey(realm)
  if not realm then
    return ""
  end
  local key = tostring(realm):lower()
  key = key:gsub("[%s%-%.%(%)'`]", "")
  return key
end

function Locale.GetRealmLocaleFromStaticData(realm)
  if not realm or realm == "" then
    return nil
  end

  local exactLookup = _G.IsiLiveRealmLocaleByExactName
  if type(exactLookup) == "table" then
    local exactLocale = exactLookup[tostring(realm):lower()]
    if exactLocale then
      return exactLocale
    end
  end

  local normalizedLookup = _G.IsiLiveRealmLocaleByNormalizedName
  if type(normalizedLookup) == "table" then
    local normalizedLocale = normalizedLookup[Locale.NormalizeRealmLookupKey(realm)]
    if normalizedLocale then
      return normalizedLocale
    end
  end

  return nil
end

function Locale.GetUnitServerLanguage(unit, realm, getRealmInfoLib)
  local staticLocale = Locale.GetRealmLocaleFromStaticData(realm)
  if staticLocale then
    return Locale.LocaleToLanguageTag(staticLocale)
  end

  local lib = type(getRealmInfoLib) == "function" and getRealmInfoLib() or nil
  if lib and unit and UnitExists(unit) then
    local guid = UnitGUID(unit)
    if guid then
      local _, _, _, _, realmLocale = lib:GetRealmInfoByGUID(guid)
      if realmLocale then
        return Locale.LocaleToLanguageTag(realmLocale)
      end
    end
  end

  if lib and realm and realm ~= "" then
    local _, _, _, _, realmLocale = lib:GetRealmInfo(realm)
    if realmLocale then
      return Locale.LocaleToLanguageTag(realmLocale)
    end
  end

  if unit and UnitIsUnit(unit, "player") then
    return Locale.LocaleToLanguageTag(GetLocale())
  end

  return "??"
end
