local _, addonTable = ...
addonTable = addonTable or {}
local Texts = {}
addonTable.Texts = Texts

-- Per-language string tables live in locale/isiLive_texts_<tag>.lua and
-- register themselves into addonTable.TextsLocales before this aggregator
-- runs (TOC order). Standalone tool runs (loadfile from the repo root, e.g.
-- tools/check_locale_drift.lua) hit the loadfile fallback below instead;
-- the WoW client never takes that path because the TOC pre-loads the files.
local LANGUAGE_FILES = {
  "isiLive_texts_common.lua",
  "isiLive_texts_enUS.lua",
  "isiLive_texts_deDE.lua",
  "isiLive_texts_frFR.lua",
  "isiLive_texts_esES.lua",
  "isiLive_texts_ptBR.lua",
  "isiLive_texts_itIT.lua",
  "isiLive_texts_ruRU.lua",
  "isiLive_texts_trTR.lua",
}

if type(addonTable.TextsLocales) ~= "table" then
  local loadfileRef = rawget(_G, "loadfile")
  if type(loadfileRef) == "function" then
    for _, file in ipairs(LANGUAGE_FILES) do
      local chunk = loadfileRef("locale/" .. file)
      if chunk then
        chunk("isiLive", addonTable)
      end
    end
  end
end

local LOCALES = type(addonTable.TextsLocales) == "table" and addonTable.TextsLocales or {}

for _, localeTable in pairs(LOCALES) do
  localeTable.SETTINGS_SOUND_CHANNEL_MASTER = "Master"
  localeTable.SETTINGS_SOUND_CHANNEL_SFX = "SFX"
end

function Texts.GetLocaleTables()
  return LOCALES
end
