#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Scans ui/ and logic/ Lua files for hardcoded user-visible string literals
-- in AddLine / SetText / SetTitle / SetTooltipText calls. Flags any literal
-- that contains a "real word" (>= 4 alphabetic chars) not in the whitelist
-- of game-jargon / addon tokens.
--
-- Rationale: check_locale_drift.lua only catches drift BETWEEN the 8 locale
-- tables. It cannot see UI code that bypasses the locale system entirely
-- (e.g. tooltip:AddLine("Click to mark unit") with no L.KEY indirection).
-- v0.9.187 found 12 such regressions during a manual audit; this gate
-- prevents the next one at preflight time.
--
-- Inline override: append `-- i18n-ok` (or `-- i18n: ok`) to a line to
-- silence the gate. Use sparingly, only for genuinely language-neutral
-- content (icon-only labels, debug-trace strings, color-code tests).
--
-- Exits 0 on clean, 1 on hardcoded literals found, 2 on IO/setup errors.
-- Run from repo root:
--   lua tools/check_hardcoded_strings.lua

local SCAN_DIRS = { "ui", "logic" }

-- Methods whose first string-literal argument lands directly on the user UI.
local SCAN_METHOD_NAMES = {
  AddLine = true,
  SetText = true,
  SetTitle = true,
  SetTooltipText = true,
}

-- Tokens that never need localization. Lowercased; only words >= 4 chars are
-- checked, so e.g. "BR", "BL", "RC", "M+", "DPS" pass the length filter
-- silently. Add new entries sparingly; prefer L.<KEY> lookups.
local TOKEN_WHITELIST = {
  ilvl = true,
  rio = true,
  isilive = true,
  npcid = true,
  brez = true,
  mythic = true,
  -- Locale tags themselves (4 chars, may show up as debug labels)
  enus = true,
  dede = true,
  frfr = true,
  eses = true,
  ptbr = true,
  itit = true,
  ruru = true,
  trtr = true,
}

local ok_lfs, lfs = pcall(require, "lfs")
if not ok_lfs then
  lfs = require("tools.lfs_compat")
end

local function walkDir(dir, files)
  for entry in lfs.dir(dir) do
    if entry ~= "." and entry ~= ".." then
      local path = dir .. "/" .. entry
      local mode = lfs.attributes(path, "mode")
      if mode == "directory" then
        walkDir(path, files)
      elseif mode == "file" and path:match("%.lua$") then
        files[#files + 1] = path
      end
    end
  end
  return files
end

local function readLines(path)
  local lines = {}
  local fh = io.open(path, "r")
  if not fh then
    return nil
  end
  for line in fh:lines() do
    lines[#lines + 1] = line
  end
  fh:close()
  return lines
end

local function extractStringLiterals(line)
  -- Returns list of double-quoted string contents in line.
  -- Limitation: doesn't handle escaped \" inside literals; rare in UI code.
  --
  -- Strips two well-formed "fallback" patterns first so they don't trip the
  -- gate, since they ARE localized -- the hardcoded literal is only the
  -- safety net when the locale key is missing:
  --   1. `<expr> or "literal"`     -- Lua nil-coalesce idiom
  --   2. `(<expr> or "literal")`   -- same idiom inside parens
  -- The localized branch lives in `<expr>`, the literal is the explicit fallback.
  local stripped = line:gsub('%s+or%s+"[^"]*"', "")
  local literals = {}
  for content in stripped:gmatch('"([^"]*)"') do
    literals[#literals + 1] = content
  end
  return literals
end

local function stripWowMarkup(s)
  -- Color codes: |cffRRGGBB...|r — the hex run is up to 8 chars after |cff,
  -- which can collide with the alpha-word tokenizer (e.g. "cffff" matches
  -- [A-Za-z]+ even though it is hex).
  s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
  s = s:gsub("|r", "")
  -- Texture / atlas markup: |T...|t, |A...|a — drop the contents wholesale,
  -- they are file paths or atlas keys, never user-translatable prose.
  s = s:gsub("|T[^|]*|t", "")
  s = s:gsub("|A[^|]*|a", "")
  -- Hyperlinks: |H...|h<text>|h — the text inside |h...|h CAN be
  -- user-visible, but in practice we render hyperlinks via L.<KEY>
  -- already; strip the |H prefix so it does not pollute the tokenizer.
  s = s:gsub("|H[^|]*|h", "")
  s = s:gsub("|h", "")
  return s
end

local function literalHasUnwhitelistedWord(literal)
  -- Strip WoW markup first so |cff... color codes don't show up as words.
  literal = stripWowMarkup(literal)
  -- Tokenize alphabetic sequences (case-insensitive). Flag if any sequence
  -- of length >= 4 is not in the whitelist.
  for word in literal:gmatch("[A-Za-z]+") do
    if #word >= 4 and not TOKEN_WHITELIST[word:lower()] then
      return word
    end
  end
  return nil
end

local function lineCallsUiMethod(line)
  for method in line:gmatch("[:.](%w+)%s*%(") do
    if SCAN_METHOD_NAMES[method] then
      return true
    end
  end
  return false
end

local function lineHasI18nOk(line)
  return line:match("%-%-%s*i18n[%s%-:]+ok") ~= nil
end

-- Second rule: locale-dependent READ paths.
--
-- The write-side rule above only sees literals handed to AddLine/SetText/...
-- It cannot see code that RECOGNISES client-rendered text, e.g.
--   string.find(plain, "Mitglieder", 1, true)
--   ["Beförderung angeboten"] = true
-- Those silently never match on the other supported client locales. v0.9.354
-- found three such sites in ui/isiLive_lfg_flags.lua (member-section header,
-- promotion-offered playstyle, Proving Grounds tooltip block) that had shipped
-- undetected because this gate could not see them.
--
-- Correct pattern: compare against a client-localized Blizzard global string
-- (rawget(_G, "LFG_LIST_TOOLTIP_MEMBERS")), never against a literal.
local MATCH_FUNCTION_NAMES = {
  find = true,
  match = true,
  gmatch = true,
  gsub = true,
}

local function lineCallsStringMatcher(line)
  for name in line:gmatch("[:.](%w+)%s*%(") do
    if MATCH_FUNCTION_NAMES[name] then
      return true
    end
  end
  return false
end

-- Table constructor keys: `["Some Text"] = ...`. A literal in key position is
-- an exact-match lookup table, the same defect class as a find() literal.
local function extractTableKeyLiterals(line)
  local literals = {}
  for content in line:gmatch('%[%s*"([^"]*)"%s*%]%s*=') do
    literals[#literals + 1] = content
  end
  return literals
end

-- Narrow the read-side rule to literals that plausibly are CLIENT-RENDERED
-- PROSE, otherwise it drowns in true negatives: unit tokens ("player",
-- "^party%d+$"), Lua type names ("table"), slash-command keywords ("debug"),
-- sync protocol tokens ("KICK", "WHISPER") and hyperlink patterns are all
-- legitimately compared as literals and are not locale-dependent.
--
-- Signal used: a Titlecase word. Game prose is capitalized ("Mitglieder",
-- "Proving Grounds", "Beförderung angeboten"); identifiers and protocol
-- tokens are all-lowercase or ALL-CAPS.
local function looksLikeClientRenderedText(literal)
  -- Non-ASCII characters in localized literals are written as decimal byte
  -- escapes ("Bef\195\182rderung"). Fold them to a plain letter first, so the
  -- backslash rejection below does not exempt exactly the umlaut-bearing
  -- German / French / Spanish strings this rule exists to catch.
  literal = literal:gsub("\\%d%d?%d?", "a")
  -- Lua patterns, path separators and WoW markup are never plain prose.
  if literal:find("[%%%^%$\\|%[%]]") then
    return false
  end
  -- camelCase / PascalCase identifiers (frame names, binding names, addon
  -- names) are code, not prose. Detected via an internal lower->upper
  -- transition inside a single unbroken identifier.
  if literal:find("^[%a_][%w_]*$") and literal:find("%l%u") then
    return false
  end
  -- Titlecase word: uppercase followed by at least two lowercase letters.
  -- Deliberately only two, so UTF-8 umlauts in the third position
  -- ("Bef|ö|rderung") still register.
  return literal:find("%u%l%l") ~= nil
end

local function main()
  local issues = {}
  local files = {}
  for _, dir in ipairs(SCAN_DIRS) do
    if lfs.attributes(dir, "mode") == "directory" then
      walkDir(dir, files)
    else
      io.stderr:write(string.format("hardcoded-strings: skip missing dir %s\n", dir))
    end
  end
  table.sort(files)

  for _, path in ipairs(files) do
    local lines = readLines(path)
    if not lines then
      io.stderr:write(string.format("hardcoded-strings: cannot read %s\n", path))
      os.exit(2)
    end
    for lineno, line in ipairs(lines) do
      if not lineHasI18nOk(line) then
        if lineCallsUiMethod(line) then
          for _, lit in ipairs(extractStringLiterals(line)) do
            local word = literalHasUnwhitelistedWord(lit)
            if word then
              issues[#issues + 1] = string.format(
                '%s:%d: hardcoded literal "%s" (word "%s") -- route via L.<KEY> or annotate `-- i18n-ok`',
                path,
                lineno,
                lit,
                word
              )
            end
          end
        end

        local readLiterals = {}
        if lineCallsStringMatcher(line) then
          for _, lit in ipairs(extractStringLiterals(line)) do
            readLiterals[#readLiterals + 1] = lit
          end
        end
        for _, lit in ipairs(extractTableKeyLiterals(line)) do
          readLiterals[#readLiterals + 1] = lit
        end
        for _, lit in ipairs(readLiterals) do
          local word = looksLikeClientRenderedText(lit) and literalHasUnwhitelistedWord(lit) or nil
          if word then
            issues[#issues + 1] = string.format(
              '%s:%d: locale-dependent literal "%s" (word "%s") -- compare against a Blizzard global string'
                .. " (rawget(_G, ...)) or annotate `-- i18n-ok`",
              path,
              lineno,
              lit,
              word
            )
          end
        end
      end
    end
  end

  if #issues == 0 then
    io.write(
      "hardcoded-strings: clean — no unlocalized literals in ui/ or logic/ write paths"
        .. " (AddLine/SetText/SetTitle) or locale-dependent read paths (find/match, table keys)\n"
    )
    os.exit(0)
  end

  io.write(string.format("hardcoded-strings: %d issue(s) found\n\n", #issues))
  for _, line in ipairs(issues) do
    io.write("  " .. line .. "\n")
  end
  os.exit(1)
end

main()
