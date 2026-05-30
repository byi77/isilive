#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Heuristic regression guard for the WoW 12.0 (Midnight) Secret Values
-- contract. In tainted M+ code paths several Blizzard APIs return masked
-- values that crash the addon when treated as plain strings/numbers. CLAUDE.md
-- mandates every such call site is wrapped in `pcall` AND the result passes
-- through an `IsSecretValue` guard (or returns nil/0 fallback).
--
-- This gate lists every direct call to one of the watched API names that
-- does not show one of the recognized guards on the same line. It is an
-- intentional heuristic — NOT every hit is a real bug. Every hit is worth a
-- human look. Use the inline override `-- secret-value-ok` to silence a line
-- once a maintainer has confirmed the call is safe (e.g. it lives inside a
-- pcall-wrapped helper that itself short-circuits on Secret Values).
--
-- Watched APIs (any direct call to one of these triggers the gate):
--   * UnitGUID, UnitName, UnitFullName
--   * UnitReaction, UnitClass, UnitIsGroupLeader
--   * UnitGroupRolesAssigned, UnitIsUnit, UnitIsVisible
--   * FontString GetStringWidth
--   * GetActiveChallengeMapID (both bare and via C_ChallengeMode)
--   * CombatLogGetCurrentEventInfo (also forbidden in 12.0; double-belt)
--
-- A line is considered "guarded" when it shows ANY of:
--   * the literal `pcall(`
--   * the literal `IsSecretValue(` or `issecretvalue(`
--   * the literal `rawget(_G,` (stub lookup; called inside a guarded helper)
--   * the literal `or function` (default-fallback in BuildDeps tables)
--   * the literal `function ` followed by the API name (definition, not call)
--   * an `=` to the LEFT of the API token (assignment to a stub: API = function)
--   * inline override `-- secret-value-ok`
--
-- Exits 0 on clean, 1 on hits, 2 on IO/setup errors.
-- Run from repo root:
--   lua tools/check_secret_value_guards.lua

local SCAN_DIRS = { "core", "factory", "game", "logic", "ui" }

-- Pattern fragments ordered: longer/more specific names first so they are
-- matched before shorter prefixes (e.g. UnitFullName vs UnitName).
local WATCHED_APIS = {
  "UnitGroupRolesAssigned",
  "UnitIsGroupLeader",
  "CombatLogGetCurrentEventInfo",
  "GetActiveChallengeMapID",
  "UnitFullName",
  "GetStringWidth",
  "UnitIsUnit",
  "UnitIsVisible",
  "UnitReaction",
  "UnitClass",
  "UnitGUID",
  "UnitName",
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

local function stripComment(line)
  -- Pre-strip `-- ...` so accidental occurrences of the API name in a comment
  -- are not flagged. The comment itself is still inspected separately for
  -- inline overrides via the raw line.
  local pos = line:find("%-%-")
  if pos then
    return line:sub(1, pos - 1)
  end
  return line
end

local function hasInlineOverride(rawLine)
  return rawLine:match("%-%-%s*secret%-value[%s%-:]+ok") ~= nil or rawLine:match("%-%-%s*secret%-value:%s*ok") ~= nil
end

-- A line is "definitional" (assignment / function-def / stub binding) when
-- the token appears as the LHS of an `=`, in a function definition, or
-- inside a rawget / type-check / global stub table. None of these are real
-- API call sites at runtime.
local function lineIsDefinitionFor(code, api)
  -- function NAME(  or  function ... .NAME(
  if code:find("function%s+" .. api .. "%s*%(") then
    return true
  end
  if code:find("function%s+[%w_%.]+%." .. api .. "%s*%(") then
    return true
  end
  -- ["NAME"] = function( -- stub table key
  if code:find('%["' .. api .. '"%]%s*=%s*function') then
    return true
  end
  -- NAME = function(   or   .NAME = function(   -- stub assignment
  if code:find("[%.%s]" .. api .. "%s*=%s*function") then
    return true
  end
  if code:find("^" .. api .. "%s*=%s*function") then
    return true
  end
  -- rawget(_G, "NAME")  -- safe stub lookup
  if code:find('rawget%(%s*_G%s*,%s*"' .. api .. '"%s*%)') then
    return true
  end
  -- opts.NAME or NAME -- defaults pattern in BuildDeps tables
  if code:find("[%.%s]" .. api .. "%s*$") then
    return true
  end
  -- type check: type(API) == "function"
  if code:find("type%s*%(%s*" .. api .. "%s*%)") then
    return true
  end
  return false
end

local function lineIsGuarded(code, api)
  if code:find("pcall%s*%(", 1) then
    return true
  end
  if code:find("IsSecretValue%s*%(") or code:find("issecretvalue%s*%(") then
    return true
  end
  -- short-circuit pattern: <APIname> and <api>(unit)  -- existence check
  -- before call (if the function table is nil, the call short-circuits).
  if code:find(api .. "%s+and%s+" .. api .. "%s*%(") then
    return true
  end
  return false
end

local function main()
  local hits = {}
  local files = {}
  for _, dir in ipairs(SCAN_DIRS) do
    if lfs.attributes(dir, "mode") == "directory" then
      walkDir(dir, files)
    end
  end
  table.sort(files)

  for _, path in ipairs(files) do
    local lines = readLines(path)
    if not lines then
      io.stderr:write("secret-value: cannot read " .. path .. "\n")
      os.exit(2)
    end
    for lineno, raw in ipairs(lines) do
      -- Accept the override either on the same line or on the immediately
      -- preceding line — long call sites tend to push the override comment
      -- onto its own line for readability.
      local previous = lineno > 1 and lines[lineno - 1] or ""
      if not (hasInlineOverride(raw) or hasInlineOverride(previous)) then
        local code = stripComment(raw)
        for _, api in ipairs(WATCHED_APIS) do
          -- Match an actual call site: API name followed by `(` and not
          -- preceded by a letter / digit / underscore (so we don't match
          -- e.g. `MyUnitGUID(` as `UnitGUID(`).
          local pattern = "[^%w_]" .. api .. "%s*%("
          if (code:sub(1, #api + 1) .. " "):find("^" .. api .. "%s*%(") or code:find(pattern) then
            if not lineIsDefinitionFor(code, api) and not lineIsGuarded(code, api) then
              hits[#hits + 1] = string.format(
                "%s:%d [%s]: direct call without pcall / IsSecretValue / short-circuit guard",
                path,
                lineno,
                api
              )
              -- Only one hit per line.
              break
            end
          end
        end
      end
    end
  end

  if #hits == 0 then
    io.write("secret-value: clean — every watched API call is guarded or annotated\n")
    os.exit(0)
  end

  io.write(string.format("secret-value: %d unguarded call site(s) — review each one\n\n", #hits))
  for _, line in ipairs(hits) do
    io.write("  " .. line .. "\n")
  end
  io.write(
    "\n  Annotate confirmed-safe lines with `-- secret-value-ok` to silence the gate.\n"
      .. "  See CLAUDE.md WoW 12.0 addon-restrictions section for the contract.\n"
  )
  os.exit(1)
end

main()
