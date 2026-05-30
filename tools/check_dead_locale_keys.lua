#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Pins the rule: every key in the enUS locale table must be referenced
-- somewhere in production code. Orphan keys are translation overhead with
-- zero user benefit — and they hide real bugs (e.g. an enum-based switch
-- only covers 5 of 8 locales because the maintainer forgot the missing
-- branches; the locale keys for those branches go unreferenced and stay
-- orphan until a translator notices).
--
-- A key is "alive" if any of these patterns matches anywhere outside the
-- locale tables themselves:
--   .KEY[non-word]   -- property access (L.KEY, ctx.GetL().KEY, etc.)
--   ["KEY"]          -- bracketed string-indexed lookup
--   "KEY"            -- bare string literal (resolveLocaleKey style)
--   'KEY'            -- single-quoted variant (rare)
--
-- The check runs over enUS only (locale-drift handles the parity between
-- enUS and the other 7 tables). False positives from genuinely dynamic
-- lookups can be silenced by adding the key to the OVERRIDES table below.
--
-- Exits 0 on clean, 1 on orphans found, 2 on IO/setup errors.
-- Run from repo root:
--   lua tools/check_dead_locale_keys.lua

local SCAN_DIRS = { "core", "factory", "game", "locale", "logic", "ui" }

-- Overrides for keys that ARE alive but only via a fully-dynamic lookup
-- (e.g. composed from runtime data and impossible to grep). Each entry
-- documents WHY the key is exempt — without that, the override decays.
local OVERRIDES = {
  -- Add entries here as: KEY_NAME = "reason it's exempt",
}

local ok_lfs, lfs = pcall(require, "lfs")
if not ok_lfs then
  lfs = require("tools.lfs_compat")
end

local function fail(code, message)
  io.stderr:write("dead-locale-keys: " .. message .. "\n")
  os.exit(code)
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

local function readFile(path)
  local fh = io.open(path, "r")
  if not fh then
    return ""
  end
  local content = fh:read("*a")
  fh:close()
  return content
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

local function main()
  -- Build the production blob: every Lua file in scan dirs except the locale
  -- tables themselves (those define every key by construction and would
  -- give every key a free pass).
  local blobParts = {}
  for _, dir in ipairs(SCAN_DIRS) do
    local files = walkDir(dir, {})
    for _, path in ipairs(files) do
      if not path:match("isiLive_texts%.lua$") then
        blobParts[#blobParts + 1] = readFile(path)
      end
    end
  end
  local blob = table.concat(blobParts, "\n")

  local locales = LoadLocaleTables()
  local enus = locales.enUS
  if type(enus) ~= "table" then
    fail(2, "enUS table missing from GetLocaleTables")
  end

  local orphans = {}
  local total = 0
  for key in pairs(enus) do
    total = total + 1
    if not OVERRIDES[key] then
      local pat1 = "%." .. key .. "[^%w_]"
      local pat2 = '%["' .. key .. '"%]'
      local pat3 = '"' .. key .. '"'
      local pat4 = "'" .. key .. "'"
      if not (blob:find(pat1) or blob:find(pat2) or blob:find(pat3) or blob:find(pat4)) then
        orphans[#orphans + 1] = key
      end
    end
  end

  table.sort(orphans)

  if #orphans == 0 then
    io.write(string.format("dead-locale-keys: clean -- all %d enUS keys referenced in production code\n", total))
    os.exit(0)
  end

  io.write(
    string.format("dead-locale-keys: %d orphan(s) of %d total enUS keys (no production reference)\n\n", #orphans, total)
  )
  for _, key in ipairs(orphans) do
    io.write("  " .. key .. "\n")
  end
  io.write(
    "\n  Either remove the key (and any orphan tests that reference it),\n"
      .. "  or add it to OVERRIDES{} with a short reason if the lookup is genuinely dynamic.\n"
  )
  os.exit(1)
end

main()
