#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Ensures every deterministic simulator under tools/ is actually executed by
-- both CI paths. A simulator no pipeline runs is not a gate -- it is dead
-- weight that rots silently against the production code it claims to pin.
--
-- This is not hypothetical. Nine simulators existed without any pipeline
-- calling them, and three of those (ready-check lifecycle, secret-value
-- pipeline, sound playback) had been failing since 2026-07-23 -- broken by a
-- runtime-hardening commit and unnoticed through three releases, because
-- nothing ever ran them. The comment asking maintainers to wire new
-- simulators up is not enforcement; this gate is.
--
-- Both CI paths must execute each simulator:
--   * tools/validate_ci_local.ps1        (local preflight)
--   * .github/workflows/lua-check.yml    (GitHub quality gate)
--
-- There is deliberately no automatic "helper module" exemption. No simulator
-- currently loads another one -- they only mention each other in comments --
-- so name-based detection would exempt real gates for merely being referenced
-- in a neighbour's prose. Every simulator is a gate until a maintainer says
-- otherwise, in writing.
--
-- Inline override: put `-- simulator-ci-ok` anywhere in a simulator to
-- exempt it deliberately. Use sparingly and say why in the same line.
--
-- Exits 0 on clean, 1 on violations, 2 on IO/setup errors.
-- Run from repo root:
--   lua tools/check_simulator_ci_coverage.lua

local TOOLS_DIR = "tools"
local LOCAL_PREFLIGHT = "tools/validate_ci_local.ps1"
local GITHUB_WORKFLOW = ".github/workflows/lua-check.yml"

local ok_lfs, lfs = pcall(require, "lfs")
if not ok_lfs then
  lfs = require("tools.lfs_compat")
end

local function readFile(path)
  local fh = io.open(path, "r")
  if not fh then
    return nil
  end
  local contents = fh:read("*a")
  fh:close()
  return contents
end

local function collectSimulators()
  local names = {}
  for entry in lfs.dir(TOOLS_DIR) do
    if entry:match("^simulate_.*%.lua$") then
      names[#names + 1] = entry
    end
  end
  table.sort(names)
  return names
end

local function main()
  if lfs.attributes(TOOLS_DIR, "mode") ~= "directory" then
    io.stderr:write("simulator-ci-coverage: cannot read " .. TOOLS_DIR .. "\n")
    os.exit(2)
  end

  local localPreflight = readFile(LOCAL_PREFLIGHT)
  local workflow = readFile(GITHUB_WORKFLOW)
  if not localPreflight or not workflow then
    io.stderr:write("simulator-ci-coverage: cannot read one of the CI definitions\n")
    os.exit(2)
  end

  local names = collectSimulators()
  if #names == 0 then
    io.stderr:write("simulator-ci-coverage: no simulators found under " .. TOOLS_DIR .. "\n")
    os.exit(2)
  end

  local issues = {}
  local checked, exempt = 0, 0

  for _, name in ipairs(names) do
    local path = TOOLS_DIR .. "/" .. name
    local contents = readFile(path)
    if contents and contents:match("%-%-%s*simulator%-ci%-ok") then
      exempt = exempt + 1
    else
      checked = checked + 1
      local invocation = "lua tools/" .. name
      if not localPreflight:find(invocation, 1, true) then
        issues[#issues + 1] = string.format("%s: not executed by %s", path, LOCAL_PREFLIGHT)
      end
      if not workflow:find(invocation, 1, true) then
        issues[#issues + 1] = string.format("%s: not executed by %s", path, GITHUB_WORKFLOW)
      end
    end
  end

  if #issues == 0 then
    io.write(
      string.format(
        "simulator-ci-coverage: clean -- %d simulator(s) run in both CI paths, %d helper/exempt\n",
        checked,
        exempt
      )
    )
    os.exit(0)
  end

  io.write(string.format("simulator-ci-coverage: %d violation(s) found\n\n", #issues))
  for _, line in ipairs(issues) do
    io.write("  " .. line .. "\n")
  end
  io.write(
    "\n  Add the simulator to both CI definitions, or annotate it with\n"
      .. "  `-- simulator-ci-ok` plus a reason if it is deliberately not a gate.\n"
  )
  os.exit(1)
end

main()
