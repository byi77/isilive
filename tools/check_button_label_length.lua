#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Pins CLAUDE.md rule: full-width action buttons in the main UI are 120x24px,
-- and although `SetFlatButtonText` clamps the label, visually truncated text
-- is bad UX. Target: <=14 characters for any BTN_* key. Compact-mode variants
-- (_SHORT, _hModeText) are scoped to <=6 characters.
--
-- This catches the typical regression where a translator picks a longer word
-- and the German / French / Russian button gets clipped on screen, while the
-- enUS variant looks fine to the maintainer.
--
-- Two-tier limits:
--   * BTN_*_SHORT / BTN_*_hModeText / BTN_*_LOCKED -> SHORT_LIMIT
--   * any other BTN_*                              -> LONG_LIMIT
-- The character count uses utf8.len when available (Lua 5.3+) and falls back
-- to a small UTF-8 codepoint counter on Lua 5.1 so multi-byte characters
-- (cyrillic, umlauts) count consistently across local and CI toolchains.
--
-- Override via the OVERRIDES table below. Use sparingly: every entry is a
-- visual regression waiting to happen.
--
-- Exits 0 on clean, 1 on violations, 2 on IO/setup errors.
-- Run from repo root:
--   lua tools/check_button_label_length.lua

local LONG_LIMIT = 14
local SHORT_LIMIT = 6

-- Simulator tablet action buttons (SIM_ACTION_*_TITLE). These are not BTN_*
-- keys and were unchecked until now, which is how a 25-character Italian
-- label got in. They live in a two-column grid: FRAME_WIDTH 420 minus 2x
-- FRAME_PADDING 14 minus COLUMN_GAP 8, halved -> 192px per button, and the
-- label is anchored LEFT +36 / RIGHT -46, leaving ~110px of text width.
--
-- The cap below is a REGRESSION CEILING, not a measured pixel fit: it is set
-- to the longest labels that have already shipped and drawn acceptably (the
-- German titles have sat at 23-24 characters for many releases). It stops
-- labels from growing further; it does not prove that 24 is the true limit.
-- If a label ever visibly clips in game, lower this and shorten the labels.
local SIM_ACTION_TITLE_LIMIT = 24

-- Per-key length-cap overrides for legitimate edge cases (tooltip-text
-- entries that just happen to live in the BTN_* namespace, multi-line
-- buttons that wrap, etc.). Keep this table small — every entry is a
-- truncation risk if the surrounding UI element ever changes width.
-- Format: KEY -> max characters.
local OVERRIDES = {
  -- Used as a Tooltip:SetText title in ui/isiLive_notice.lua and
  -- ui/isiLive_teleport_ui.lua, NOT as a button label. Tooltips are wide
  -- enough that 30 chars still renders without clipping.
  BTN_TELEPORT_LOCKED = 30,
  -- ruRU labels are intentionally longer than the old hard cap. The fixed
  -- roster/action buttons now use SetFlatButtonText font fitting, and the
  -- regression coverage pins short, long, and post-shrink refits.
  BTN_COUNTDOWN_CANCEL_SHORT = 9,
  BTN_GAMEMENU_RELOADUI = 15,
  BTN_GAMEMENU_SPELLBOOK = 16,
  BTN_READYCHECK = 19,
  BTN_REFRESH = 15,
  BTN_SECOND_HEARTHSTONE = 18,
  BTN_SHARE_KEYS = 18,
}

local function utf8len(s)
  -- Standard library presence varies. Newer Lua versions expose `utf8.len`.
  -- Lua 5.1 on GitHub Actions does not, so count UTF-8 leading bytes there:
  -- continuation bytes are 0x80..0xBF, every other byte starts a codepoint.
  local utf8 = rawget(_G, "utf8")
  if type(utf8) == "table" and type(utf8.len) == "function" then
    local n = utf8.len(s)
    if type(n) == "number" then
      return n
    end
  end
  local n = 0
  for i = 1, #s do
    local byte = s:byte(i)
    if byte < 128 or byte >= 192 then
      n = n + 1
    end
  end
  return n
end

local function fail(code, message)
  io.stderr:write("button-label-length: " .. message .. "\n")
  os.exit(code)
end

local function LoadLocaleTables()
  local addonTable = {}
  local chunk, loadErr = loadfile("locale/isiLive_texts.lua")
  if not chunk then
    fail(2, "cannot load locale/isiLive_texts.lua: " .. tostring(loadErr))
  end
  local ok, runErr = pcall(chunk, "isiLive", addonTable)
  if not ok then
    fail(2, "error executing isiLive_texts.lua: " .. tostring(runErr))
  end
  if type(addonTable.Texts) ~= "table" or type(addonTable.Texts.GetLocaleTables) ~= "function" then
    fail(2, "addonTable.Texts.GetLocaleTables is missing")
  end
  return addonTable.Texts.GetLocaleTables()
end

local function IsCheckedKey(key)
  return key:sub(1, 4) == "BTN_" or (key:find("^SIM_ACTION_") ~= nil and key:find("_TITLE$") ~= nil)
end

local function ResolveLimit(key)
  if OVERRIDES[key] then
    return OVERRIDES[key]
  end
  if key:find("^SIM_ACTION_") and key:find("_TITLE$") then
    return SIM_ACTION_TITLE_LIMIT
  end
  -- Compact-mode variants: only the explicit suffixes that this codebase
  -- actually uses for narrow / hModeText layouts. _LOCKED is a button STATE
  -- (used as tooltip text), not a size variant — the override table handles
  -- those individually.
  if key:find("_SHORT$") or key:find("_hModeText$") then
    return SHORT_LIMIT
  end
  return LONG_LIMIT
end

local function main()
  local locales = LoadLocaleTables()
  local violations = {}
  local checked = 0

  -- Iterate over a stable, sorted locale order so the report is deterministic.
  local localeOrder = {}
  for lang in pairs(locales) do
    localeOrder[#localeOrder + 1] = lang
  end
  table.sort(localeOrder)

  for _, lang in ipairs(localeOrder) do
    local table_ = locales[lang]
    if type(table_) == "table" then
      -- Sort keys so the report is identical run-to-run.
      local keys = {}
      for key in pairs(table_) do
        if type(key) == "string" and IsCheckedKey(key) then
          keys[#keys + 1] = key
        end
      end
      table.sort(keys)
      for _, key in ipairs(keys) do
        local value = table_[key]
        if type(value) == "string" then
          checked = checked + 1
          local limit = ResolveLimit(key)
          local length = utf8len(value)
          if length > limit then
            violations[#violations + 1] =
              string.format("[%s] %s = %q (%d chars > limit %d)", lang, key, value, length, limit)
          end
        end
      end
    end
  end

  if #violations == 0 then
    io.write(
      string.format(
        "button-label-length: clean -- all %d BTN_* / SIM_ACTION_*_TITLE labels within limits "
          .. "(long<=%d, short<=%d, sim-title<=%d)\n",
        checked,
        LONG_LIMIT,
        SHORT_LIMIT,
        SIM_ACTION_TITLE_LIMIT
      )
    )
    os.exit(0)
  end

  io.write(string.format("button-label-length: %d violation(s) found\n\n", #violations))
  for _, v in ipairs(violations) do
    io.write("  " .. v .. "\n")
  end
  io.write(
    string.format(
      "\n  Long limit: <=%d, Short limit: <=%d, Simulator title limit: <=%d\n",
      LONG_LIMIT,
      SHORT_LIMIT,
      SIM_ACTION_TITLE_LIMIT
    )
  )
  io.write("  Add an entry to OVERRIDES{} in this script if a label is intentionally longer.\n")
  os.exit(1)
end

main()
