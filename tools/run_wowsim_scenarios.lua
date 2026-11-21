#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Runs every wowsim scenario in tools/wowsim/scenarios (rule 263). Scenarios
-- that no pipeline runs fall out of date unnoticed: card_stack, offseason and
-- language_dungeon_names failed for weeks before 2026-11-21 because wowsim was
-- not part of CI. A new scenario file is picked up automatically.
--
-- Usage (from repo root):
--   lua tools/run_wowsim_scenarios.lua
--
-- Exit codes: 0 every scenario passed, 1 at least one failed.

local isWindows = package.config:sub(1, 1) == "\\"

local function ListScenarios()
  local command = isWindows and 'dir /b "tools\\wowsim\\scenarios\\*.lua" 2>nul'
    or "ls -1 tools/wowsim/scenarios 2>/dev/null"
  local names = {}
  local pipe = assert(io.popen(command))
  for line in pipe:lines() do
    local name = line:match("^([%w_]+)%.lua%s*$")
    if name then
      names[#names + 1] = name
    end
  end
  pipe:close()
  table.sort(names)
  return names
end

-- os.execute returns a number on Lua 5.1 and true/nil plus the code on 5.2+.
local function Run(command)
  local a, _, c = os.execute(command)
  if type(a) == "number" then
    return a == 0
  end
  return a == true and (c == nil or c == 0)
end

local silence = isWindows and " >nul 2>&1" or " >/dev/null 2>&1"
local failed = {}
local scenarios = ListScenarios()
for _, name in ipairs(scenarios) do
  local ok = Run("lua tools/wowsim/wowsim.lua " .. name .. " --quiet" .. silence)
  print(string.format("[wowsim] %-28s %s", name, ok and "ok" or "FAILED"))
  if not ok then
    failed[#failed + 1] = name
  end
end
if #scenarios == 0 then
  print("[wowsim] no scenarios found")
  os.exit(1)
end
if #failed > 0 then
  print(
    string.format(
      "[wowsim] %d of %d scenarios failed: %s (rerun one with lua tools/wowsim/wowsim.lua <name>)",
      #failed,
      #scenarios,
      table.concat(failed, ", ")
    )
  )
  os.exit(1)
end
print(string.format("[wowsim] all %d scenarios passed", #scenarios))
