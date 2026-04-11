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
  { tag = "esES", cmdAliases = { "es", "eses", "esmx" }, buttonLabel = "Español" },
  { tag = "ptBR", cmdAliases = { "pt", "ptbr", "ptpt" }, buttonLabel = "Português" },
  { tag = "itIT", cmdAliases = { "it", "itit" }, buttonLabel = "Italiano" },
  { tag = "ruRU", cmdAliases = { "ru", "ruru" }, buttonLabel = "Русский" },
  { tag = "trTR", cmdAliases = { "tr", "trtr" }, buttonLabel = "Türkçe" },
}

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
