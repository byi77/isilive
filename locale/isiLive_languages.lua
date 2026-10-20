local _, addonTable = ...

addonTable = addonTable or {}

local Languages = {}
addonTable.Languages = Languages

-- Single source of truth for all supported UI languages.
-- To add a new language: follow the steps in CLAUDE.md ("Adding a new UI language").

Languages.SUPPORTED = {
  { tag = "enUS", cmdAliases = { "en", "enus", "engb" }, buttonLabel = "English" },
  { tag = "deDE", cmdAliases = { "de", "dede" }, buttonLabel = "Deutsch" },
  { tag = "frFR", cmdAliases = { "fr", "frfr" }, buttonLabel = "Français" },
  { tag = "ruRU", cmdAliases = { "ru", "ruru" }, buttonLabel = "Русский" },
  { tag = "trTR", cmdAliases = { "tr", "trtr" }, buttonLabel = "Türkçe" },
}

-- Settings-selector opt-in list. It currently equals SUPPORTED: esES, ptBR and
-- itIT left the selector in 0.9.316 and were removed as UI languages entirely
-- on 2026-10-20 (user decision); clients on those locales fall back to enUS via
-- ResolveTag. A newly added language still needs an explicit entry here (see
-- CLAUDE.md, "Adding a new UI language", step 6).
local SETTINGS_SELECTABLE_TAGS = {
  enUS = true,
  deDE = true,
  frFR = true,
  ruRU = true,
  trTR = true,
}

Languages.SETTINGS_SUPPORTED = {}
for _, lang in ipairs(Languages.SUPPORTED) do
  if SETTINGS_SELECTABLE_TAGS[lang.tag] then
    Languages.SETTINGS_SUPPORTED[#Languages.SETTINGS_SUPPORTED + 1] = lang
  end
end

-- Resolves a user-supplied tag (e.g. "de", "deDE", "fr") to a canonical locale tag
-- (e.g. "deDE", "frFR"). Returns "enUS" for unknown input.
function Languages.ResolveTag(tag)
  if not tag then
    return "enUS"
  end
  local normalized = tostring(tag):gsub("%-", ""):lower()
  for _, lang in ipairs(Languages.SUPPORTED) do
    for _, alias in ipairs(lang.cmdAliases) do
      if normalized == alias then
        return lang.tag
      end
    end
    if normalized == lang.tag:lower() then
      return lang.tag
    end
  end
  return "enUS"
end

-- Returns true if the given tag (any alias or canonical) is a supported language.
function Languages.IsSupported(tag)
  if not tag then
    return false
  end
  local normalized = tostring(tag):gsub("%-", ""):lower()
  for _, lang in ipairs(Languages.SUPPORTED) do
    for _, alias in ipairs(lang.cmdAliases) do
      if normalized == alias then
        return true
      end
    end
    if normalized == lang.tag:lower() then
      return true
    end
  end
  return false
end

-- Returns the WoW client locale, or nil when GetLocale is unavailable or masked.
-- Offline tools load this file without Validators, so the secret-value guard is optional.
function Languages.ReadClientLocale()
  local getLocale = rawget(_G, "GetLocale")
  if type(getLocale) ~= "function" then
    return nil
  end
  local ok, locale = pcall(getLocale)
  local validators = addonTable.Validators
  if
    ok
    and type(validators) == "table"
    and type(validators.IsSecretValue) == "function"
    and validators.IsSecretValue(locale) == true
  then
    return nil
  end
  if not ok or type(locale) ~= "string" or locale == "" then
    return nil
  end
  return locale
end

-- True when `localeTag` names the client language. Blizzard APIs return names in
-- the client language, so a live API name only fits a request in that language.
function Languages.IsClientLocale(localeTag)
  if type(localeTag) ~= "string" or localeTag == "" then
    return false
  end
  local clientLocale = Languages.ReadClientLocale()
  if not clientLocale then
    return false
  end
  if localeTag == clientLocale then
    return true
  end
  return Languages.IsSupported(localeTag)
    and Languages.IsSupported(clientLocale)
    and Languages.ResolveTag(localeTag) == Languages.ResolveTag(clientLocale)
end
