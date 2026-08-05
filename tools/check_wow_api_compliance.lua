#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Pins the WoW 12.0 (Midnight) addon-restriction rules from CLAUDE.md.
-- Source of truth: https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes
--
-- Static grep-based gate. Reports only; the fix always needs human judgment
-- because the right replacement depends on what the feature was trying to do.
--
-- Checks (all in production code only — testmodul/ and libs/ are skipped):
--   1. COMBAT_LOG_EVENT_UNFILTERED          → removed; raises ADDON_ACTION_FORBIDDEN
--      Replacement: UNIT_SPELLCAST_SUCCEEDED (see game/isiLive_combat_events.lua)
--   2. CombatLogGetCurrentEventInfo()       → unavailable to tainted code
--   3. C_MythicPlus.GetOwnedKeystoneLink    → function is nil in retail
--      Replacement: bag scan via C_Container.GetContainerItemLink for item 180653
--   4. "Peer version" / "Peer-Version"      → tooltip sync-version regression
--   5. protocolVersion in roster_tooltip    → tooltip sync-version regression
--   6. SetRaidTarget                        → protected; ADDON_ACTION_FORBIDDEN
--      Replacement: secure worldmarker / macrotext buttons
--
-- Inline override: append `-- wow-api-ok` (or `-- wow-api: ok`) to a line to
-- silence the gate. Use sparingly — these rules exist because each violation
-- shipped at least one shipped-bug in the addon's history.
--
-- Exits 0 on clean, 1 on violations, 2 on IO/setup errors.
-- Run from repo root:
--   lua tools/check_wow_api_compliance.lua

local SCAN_DIRS = { "core", "factory", "game", "logic", "ui" }

-- A rule consists of:
--   id          -- short identifier shown in the report
--   pattern     -- Lua pattern matched against the post-comment-strip line
--   message     -- human-readable explanation
--   restrictTo  -- optional, restricts the rule to specific files
local RULES = {
  {
    id = "combat-log-event-unfiltered",
    pattern = "COMBAT_LOG_EVENT_UNFILTERED",
    message = "COMBAT_LOG_EVENT_UNFILTERED is removed in 12.0; RegisterEvent raises ADDON_ACTION_FORBIDDEN. "
      .. "Use UNIT_SPELLCAST_SUCCEEDED (see game/isiLive_combat_events.lua) or C_CombatLog.* instead.",
  },
  {
    id = "combat-log-get-current",
    pattern = "CombatLogGetCurrentEventInfo",
    message = "CombatLogGetCurrentEventInfo is not callable from tainted code in 12.0. "
      .. "Switch to UNIT_SPELLCAST_SUCCEEDED or the new C_CombatLog API.",
  },
  {
    id = "owned-keystone-link",
    pattern = "GetOwnedKeystoneLink",
    message = "C_MythicPlus.GetOwnedKeystoneLink is nil in retail (the table exists, the function does not). "
      .. "Use a bag scan via C_Container.GetContainerItemLink for item 180653.",
  },
  {
    id = "tooltip-peer-version",
    pattern = "Peer[%- ]Version",
    message = "Tooltip sync-version line must read 'Client version' / 'Client-Version', not 'Peer'. "
      .. "See CLAUDE.md tooltip-sync-version rule and ui/isiLive_roster_tooltip.lua.",
  },
  {
    id = "tooltip-protocol-version",
    pattern = "protocolVersion",
    message = "Tooltip sync-version rendering must not branch on protocolVersion (no '(p%d)' suffix). "
      .. "See CLAUDE.md tooltip-sync-version rule.",
    restrictTo = {
      ["ui/isiLive_roster_tooltip.lua"] = true,
      ["ui\\isiLive_roster_tooltip.lua"] = true,
    },
  },
  {
    id = "protected-set-raid-target",
    pattern = "SetRaidTarget",
    message = "SetRaidTarget is protected and raises ADDON_ACTION_FORBIDDEN from addon code. "
      .. "Raid markers go through the secure worldmarker and macrotext buttons in "
      .. "ui/isiLive_roster_panel_chrome.lua / ui/isiLive_roster_panel_render.lua. "
      .. "This also covers merely capturing the global into a deps table: an unread "
      .. "handle is invisible to the taint trap in testmodul/isilive_test_scenarios_taint.lua, "
      .. "so the gate is the only thing that catches it.",
  },
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
  -- Find the first `--` that is not inside a string. Simple heuristic: track
  -- whether we are inside a double-quoted literal. Single-quoted literals are
  -- rare in this codebase.
  local inString = false
  local i = 1
  while i <= #line do
    local c = line:sub(i, i)
    if c == "\\" and inString then
      i = i + 2
    else
      if c == '"' then
        inString = not inString
      elseif not inString and c == "-" and line:sub(i + 1, i + 1) == "-" then
        return line:sub(1, i - 1)
      end
      i = i + 1
    end
  end
  return line
end

local function lineHasOverride(line)
  return line:match("%-%-%s*wow%-api[%s%-:]+ok") ~= nil
end

local function ruleAppliesTo(rule, path)
  if not rule.restrictTo then
    return true
  end
  return rule.restrictTo[path] == true
end

local function main()
  local issues = {}
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
      io.stderr:write(string.format("wow-api-compliance: cannot read %s\n", path))
      os.exit(2)
    end
    for lineno, raw in ipairs(lines) do
      if not lineHasOverride(raw) then
        local code = stripComment(raw)
        for _, rule in ipairs(RULES) do
          if ruleAppliesTo(rule, path) and code:find(rule.pattern) then
            issues[#issues + 1] = string.format("%s:%d [%s]: %s", path, lineno, rule.id, rule.message)
          end
        end
      end
    end
  end

  if #issues == 0 then
    io.write("wow-api-compliance: clean — no 12.0 restriction violations found\n")
    os.exit(0)
  end

  io.write(string.format("wow-api-compliance: %d violation(s) found\n\n", #issues))
  for _, line in ipairs(issues) do
    io.write("  " .. line .. "\n")
  end
  os.exit(1)
end

main()
