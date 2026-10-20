#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Scans locale/isiLive_texts.lua for drift between enUS (reference) and the
-- other locales (deDE/frFR/ruRU/trTR):
--   * missing keys in a locale (key exists in enUS but not in target)
--   * extra keys in a locale (key exists in target but not in enUS)
--   * %s/%d placeholder count mismatches (would crash string.format at runtime)
--
-- Also scans locale/isiLive_locale.lua LANGUAGE_NAME_BY_LOCALE for the same
-- drift (missing/extra keys) across the supported display locales.
--
-- Exits 0 on clean, 1 on drift. Intended for local runs and CI.
-- Run from repo root:
--   lua tools/check_locale_drift.lua

local TEXTS_PATH = "locale/isiLive_texts.lua"
local LOCALE_PATH = "locale/isiLive_locale.lua"

local loader = loadfile(TEXTS_PATH)
if not loader then
  io.stderr:write("drift: cannot load " .. TEXTS_PATH .. "\n")
  os.exit(2)
end

local addonTable = {
  Validators = {
    IsExistingUnit = function()
      return false
    end,
  },
  StringUtils = {
    NormalizeRealmName = function(s)
      return tostring(s or "")
    end,
  },
  Languages = {
    ResolveTag = function(tag)
      return tag
    end,
  },
}
local ok, err = pcall(loader, "isiLive", addonTable)
if not ok then
  io.stderr:write("drift: load error: " .. tostring(err) .. "\n")
  os.exit(2)
end

if not addonTable.Texts or type(addonTable.Texts.GetLocaleTables) ~= "function" then
  io.stderr:write("drift: addonTable.Texts.GetLocaleTables not available\n")
  os.exit(2)
end

local locales = addonTable.Texts.GetLocaleTables()
local ref = locales.enUS
if type(ref) ~= "table" then
  io.stderr:write("drift: enUS locale missing\n")
  os.exit(2)
end

local function countPlaceholders(s)
  local count = 0
  for _ in s:gmatch("%%[sd]") do
    count = count + 1
  end
  return count
end

local function sortedKeys(tbl)
  local keys = {}
  for k in pairs(tbl) do
    keys[#keys + 1] = k
  end
  table.sort(keys)
  return keys
end

local issues = {}

local orderedLocales = { "deDE", "frFR", "ruRU", "trTR" }

for _, localeName in ipairs(orderedLocales) do
  local localeTable = locales[localeName]
  if type(localeTable) ~= "table" then
    issues[#issues + 1] = string.format("%s: locale table missing entirely", localeName)
  else
    for _, key in ipairs(sortedKeys(ref)) do
      local refValue = ref[key]
      local trValue = localeTable[key]
      if trValue == nil then
        issues[#issues + 1] = string.format("%s.%s: MISSING (enUS has this key)", localeName, key)
      elseif type(refValue) == "string" and type(trValue) == "string" then
        local refC = countPlaceholders(refValue)
        local trC = countPlaceholders(trValue)
        if refC ~= trC then
          issues[#issues + 1] = string.format(
            '%s.%s: PLACEHOLDER MISMATCH (enUS=%d, %s=%d)\n    enUS: "%s"\n    %s: "%s"',
            localeName,
            key,
            refC,
            localeName,
            trC,
            refValue,
            localeName,
            trValue
          )
        end
      end
    end

    for _, key in ipairs(sortedKeys(localeTable)) do
      if ref[key] == nil then
        issues[#issues + 1] = string.format("%s.%s: EXTRA (not present in enUS)", localeName, key)
      end
    end
  end
end

local localeLoader = loadfile(LOCALE_PATH)
if not localeLoader then
  io.stderr:write("drift: cannot load " .. LOCALE_PATH .. "\n")
  os.exit(2)
end
local okLocale, errLocale = pcall(localeLoader, "isiLive", addonTable)
if not okLocale then
  io.stderr:write("drift: load error (" .. LOCALE_PATH .. "): " .. tostring(errLocale) .. "\n")
  os.exit(2)
end
if not addonTable.Locale or type(addonTable.Locale.GetLanguageNameTables) ~= "function" then
  io.stderr:write("drift: addonTable.Locale.GetLanguageNameTables not available\n")
  os.exit(2)
end

local languageNameTables = addonTable.Locale.GetLanguageNameTables()
local languageNameRef = languageNameTables and languageNameTables.enUS
if type(languageNameRef) ~= "table" then
  io.stderr:write("drift: LANGUAGE_NAME_BY_LOCALE.enUS missing\n")
  os.exit(2)
end

for _, localeName in ipairs(orderedLocales) do
  local localeTable = languageNameTables[localeName]
  if type(localeTable) ~= "table" then
    issues[#issues + 1] = string.format("LANGUAGE_NAME_BY_LOCALE.%s: locale table missing entirely", localeName)
  else
    for _, key in ipairs(sortedKeys(languageNameRef)) do
      if localeTable[key] == nil then
        issues[#issues + 1] =
          string.format("LANGUAGE_NAME_BY_LOCALE.%s.%s: MISSING (enUS has this key)", localeName, key)
      end
    end
    for _, key in ipairs(sortedKeys(localeTable)) do
      if languageNameRef[key] == nil then
        issues[#issues + 1] =
          string.format("LANGUAGE_NAME_BY_LOCALE.%s.%s: EXTRA (not present in enUS)", localeName, key)
      end
    end
  end
end

if #issues == 0 then
  io.write("drift: clean — all locales aligned with enUS (keys + placeholders)\n")
  os.exit(0)
end

io.write(string.format("drift: %d issue(s) found\n\n", #issues))
for _, line in ipairs(issues) do
  io.write("  " .. line .. "\n")
end
os.exit(1)
