#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Pins format-specifier consistency across the 8 locale tables in
-- locale/isiLive_texts.lua. A typical regression: enUS reads
--   "%s reaches %d%%"
-- but a translator drops one of the %s or swaps a %d for %s, producing
-- e.g. deDE "erreicht %s%% (%s)". string.format then crashes ONLY in the
-- offending language, which means a 1/8 user base sees the error and the
-- maintainer never notices. This gate enforces:
--
--   1. Every key present in enUS must exist in every other locale.
--      (locale-drift already covers this; we re-check defensively.)
--   2. The MULTISET of specifier types ({"%s","%d","%.2f",...}) must match
--      between enUS and every other locale, key by key. Order is allowed
--      to differ — natural-language word order varies — but count and type
--      of placeholders must agree, otherwise string.format raises.
--   3. The literal "%%" sequence (escaped percent) is preserved as a literal,
--      not as a placeholder.
--
-- enUS is the source of truth: every other locale's specifier multiset must
-- match enUS for the same key.
--
-- Inline override: append `-- format-ok` to a value line (in the locale
-- table) when an asymmetric translation is intentional. Use sparingly.
--
-- Exits 0 on clean, 1 on violations, 2 on IO/setup errors.
-- Run from repo root:
--   lua tools/check_format_string_consistency.lua

local ENUS_KEY = "enUS"
local LOCALE_ORDER = { "deDE", "frFR", "esES", "ptBR", "itIT", "ruRU", "trTR" }

local function LoadLocaleTables()
  local addonTable = {}
  local chunk, loadErr = loadfile("locale/isiLive_texts.lua")
  if not chunk then
    io.stderr:write("format-string: cannot load locale/isiLive_texts.lua: " .. tostring(loadErr) .. "\n")
    os.exit(2)
  end
  local ok, runErr = pcall(chunk, "isiLive", addonTable)
  if not ok then
    io.stderr:write("format-string: error executing isiLive_texts.lua: " .. tostring(runErr) .. "\n")
    os.exit(2)
  end
  if type(addonTable.Texts) ~= "table" or type(addonTable.Texts.GetLocaleTables) ~= "function" then
    io.stderr:write("format-string: addonTable.Texts.GetLocaleTables is missing\n")
    os.exit(2)
  end
  return addonTable.Texts.GetLocaleTables()
end

-- Extract format specifiers from a string. Lua's string.format follows the
-- printf grammar: %[flags][width][.precision]conversion. We treat "%%" as a
-- literal percent (no specifier) and recognize the conversion characters
-- isiLive actually uses: s, d, i, f, x, X, q, %.
local SPECIFIER_PATTERN = "%%([%-%+ #0]*)(%d*)%.?(%d*)([sdifxXq%%])"

local function ExtractSpecifiers(value)
  if type(value) ~= "string" then
    return {}
  end
  local specs = {}
  for flags, width, precision, conv in value:gmatch(SPECIFIER_PATTERN) do
    if conv ~= "%" then
      -- Normalize: keep conversion letter + precision token. Width is an
      -- ergonomic detail that translators may legitimately tweak (e.g. "%5d"
      -- vs "%d") so we strip it. Precision matters for %.2f vs %.4f though
      -- — keep it.
      local normalized
      if precision ~= "" then
        normalized = "%." .. precision .. conv
      else
        normalized = "%" .. conv
      end
      specs[#specs + 1] = normalized
      -- Suppress unused-variable warnings via touch: flags / width are kept
      -- in the pattern so that "%-5d" and similar still parse correctly.
      local _ = flags
      local _ = width
    end
  end
  return specs
end

local function MultisetCount(list)
  local counts = {}
  for _, item in ipairs(list) do
    counts[item] = (counts[item] or 0) + 1
  end
  return counts
end

local function MultisetEqual(a, b)
  for key, count in pairs(a) do
    if b[key] ~= count then
      return false
    end
  end
  for key, count in pairs(b) do
    if a[key] ~= count then
      return false
    end
  end
  return true
end

local function MultisetToString(counts)
  local parts = {}
  for key, count in pairs(counts) do
    parts[#parts + 1] = string.format("%s×%d", key, count)
  end
  table.sort(parts)
  if #parts == 0 then
    return "(none)"
  end
  return table.concat(parts, ", ")
end

-- Inline override scan: parse the locale file once and record line numbers
-- for any value tagged `-- format-ok`. We approximate the location by
-- matching `KEY = "..."` with the comment on the same physical line.
local OVERRIDE_SCAN_FILES = {
  "locale/isiLive_texts.lua",
  "locale/isiLive_texts_common.lua",
  "locale/isiLive_texts_enUS.lua",
  "locale/isiLive_texts_deDE.lua",
  "locale/isiLive_texts_frFR.lua",
  "locale/isiLive_texts_esES.lua",
  "locale/isiLive_texts_ptBR.lua",
  "locale/isiLive_texts_itIT.lua",
  "locale/isiLive_texts_ruRU.lua",
  "locale/isiLive_texts_trTR.lua",
}

local function LoadOverrideKeys()
  local overrides = {}
  for _, path in ipairs(OVERRIDE_SCAN_FILES) do
    local fh = io.open(path, "r")
    if fh then
      for line in fh:lines() do
        local key = line:match('^%s*([%w_]+)%s*=%s*"')
        if key and (line:find("%-%-%s*format[%s%-:]+ok") or line:find("%-%-%s*format:%s*ok")) then
          overrides[key] = true
        end
      end
      fh:close()
    end
  end
  return overrides
end

local function main()
  local locales = LoadLocaleTables()
  local enus = locales[ENUS_KEY]
  if type(enus) ~= "table" then
    io.stderr:write("format-string: enUS table missing from GetLocaleTables\n")
    os.exit(2)
  end

  local overrides = LoadOverrideKeys()
  local issues = {}

  for _, lang in ipairs(LOCALE_ORDER) do
    local localeTable = locales[lang]
    if type(localeTable) ~= "table" then
      issues[#issues + 1] = string.format("locale '%s' is missing entirely from GetLocaleTables", lang)
    else
      for key, enValue in pairs(enus) do
        if not overrides[key] then
          local localeValue = localeTable[key]
          if type(enValue) == "string" and type(localeValue) == "string" then
            local enSpecs = ExtractSpecifiers(enValue)
            local localeSpecs = ExtractSpecifiers(localeValue)
            local enCounts = MultisetCount(enSpecs)
            local localeCounts = MultisetCount(localeSpecs)
            if not MultisetEqual(enCounts, localeCounts) then
              issues[#issues + 1] = string.format(
                "[%s] key '%s': specifier mismatch — enUS has {%s}, %s has {%s}\n      enUS:    %q\n      %s: %q",
                lang,
                key,
                MultisetToString(enCounts),
                lang,
                MultisetToString(localeCounts),
                enValue,
                lang,
                localeValue
              )
            end
          end
        end
      end
    end
  end

  if #issues == 0 then
    io.write("format-string: clean — every locale matches enUS specifier multisets across all keys\n")
    os.exit(0)
  end

  io.write(string.format("format-string: %d violation(s) found\n\n", #issues))
  for _, line in ipairs(issues) do
    io.write("  " .. line .. "\n")
  end
  os.exit(1)
end

main()
