local _, addonTable = ...

addonTable = addonTable or {}

-- Font-family selection for the isiLive interface.
--
-- Extracted from `ui/isiLive_ui_common.lua` along a clear UI responsibility:
-- that module owns colors, backdrops, text helpers and locale resolution,
-- while everything about *which typeface* a FontString should carry lives
-- here. The public surface stays on `UICommon`, so no call site changes.
local UICommon = addonTable.UICommon
if type(UICommon) ~= "table" then
  return
end

-- Selectable UI font families.
--
-- `key` is the stable identifier persisted in IsiLiveDB.uiFontFamily; it must
-- never change once shipped, because saved values are matched against it. The
-- empty key means "keep whatever font the Blizzard template brought", which is
-- the default and the behaviour every version before this one had.
--
-- Only fonts the WoW client ships itself are listed here, so the selection
-- works without any external media library. MORPHEUS and SKURRI carry no
-- Cyrillic glyphs -- that is handled by the locale override and the per-text
-- Cyrillic veto in ApplyReadableFontForText, not by removing them here.
UICommon.BUILTIN_FONT_CHOICES = {
  { key = "", path = "" },
  { key = "friz", path = "Fonts\\FRIZQT__.TTF" },
  { key = "arial", path = "Fonts\\ARIALN.TTF" },
  { key = "morpheus", path = "Fonts\\MORPHEUS.TTF" },
  { key = "skurri", path = "Fonts\\SKURRI.TTF" },
}

-- The selection is deliberately limited to the fonts the client ships.
--
-- Pulling in a shared media pool was tried and dropped on 2026-09-13: with a
-- pool loaded the list ran to dozens of entries, and the settings dropdown
-- renders every option as a button without scrolling. A short, predictable
-- list beats an unusable one.
function UICommon.GetFontChoices()
  local choices = {}
  for _, entry in ipairs(UICommon.BUILTIN_FONT_CHOICES) do
    choices[#choices + 1] = { key = entry.key, path = entry.path, label = entry.label }
  end

  return choices
end

-- Resolves a persisted key to a usable font path. An unknown key resolves to
-- nil, which falls back to the template font instead of erroring -- that also
-- covers a value saved by a build whose choice list looked different.
function UICommon.ResolveFontPathByKey(key)
  if type(key) ~= "string" or key == "" then
    return nil
  end

  for _, entry in ipairs(UICommon.GetFontChoices()) do
    if entry.key == key and type(entry.path) == "string" and entry.path ~= "" then
      return entry.path
    end
  end

  return nil
end

function UICommon.GetUserFontPath()
  local db = rawget(_G, "IsiLiveDB")
  if type(db) ~= "table" then
    return nil
  end

  return UICommon.ResolveFontPathByKey(db.uiFontFamily)
end

-- The single decision point for "which font should this string use".
--
-- Order matters and is deliberate: a locale that needs its own font (ruRU)
-- wins over the user's pick, because a Latin-only choice would turn every
-- localized label into boxes. The user's pick only applies where the client
-- locale has no such requirement.
function UICommon.GetPreferredFontPath(localeTag)
  local localeFontPath = UICommon.GetLocaleFontPath(localeTag)
  if type(localeFontPath) == "string" and localeFontPath ~= "" then
    return localeFontPath
  end

  return UICommon.GetUserFontPath()
end
