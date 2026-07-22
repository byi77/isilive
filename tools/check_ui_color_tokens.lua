#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Scans ui/ Lua files for literal RGBA arguments passed directly to
-- SetTextColor / SetVertexColor / SetColorTexture. Real color values must
-- live in UICommon.Colors (ui/isiLive_ui_common.lua) and be consumed via
-- `unpack(UICommon.Colors.TOKEN)` -- optionally `unpack(Colors.TOKEN or
-- { ... })` as a defensive fallback. That fallback literal sits inside the
-- unpack(...) call, not as the direct call argument, so it does not trip
-- this gate.
--
-- Rationale: added 2026-07-22 during the UI color-token consolidation pass
-- (69 literal call sites across 17 files migrated to named tokens in
-- UICommon.Colors). Without a gate, new literal colors would silently creep
-- back in and defeat the point of centralizing them -- a future palette
-- change would again have to grep the whole ui/ tree instead of touching
-- one table.
--
-- Inline override: append `-- color-ok` to a line to silence the gate. Use
-- sparingly -- e.g. a dynamically computed threshold color list assigned to
-- local variables (not a direct call argument) is not flagged in the first
-- place and needs no override.
--
-- Exits 0 on clean, 1 on literal color arguments found, 2 on IO/setup errors.
-- Run from repo root:
--   lua tools/check_ui_color_tokens.lua

local SCAN_DIRS = { "ui" }

-- Methods whose literal first argument is a hardcoded color that should
-- instead come from UICommon.Colors.
local SCAN_METHOD_NAMES = {
  SetTextColor = true,
  SetVertexColor = true,
  SetColorTexture = true,
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

local function lineHasOverride(line)
  return line:match("%-%-%s*color%-ok") ~= nil
end

-- Finds a `:MethodName(` / `.MethodName(` call (method in SCAN_METHOD_NAMES)
-- whose first argument starts with a digit, decimal point, or minus sign --
-- i.e. a literal number, not a variable, unpack(...), or table expression.
local function findLiteralColorCall(line)
  for method, argStart in line:gmatch("[:%.](%w+)%s*%(%s*()") do
    if SCAN_METHOD_NAMES[method] then
      local nextChar = line:sub(argStart, argStart)
      if nextChar:match("[%d%.%-]") then
        return method
      end
    end
  end
  return nil
end

local function main()
  local issues = {}
  local files = {}
  for _, dir in ipairs(SCAN_DIRS) do
    if lfs.attributes(dir, "mode") == "directory" then
      walkDir(dir, files)
    else
      io.stderr:write(string.format("ui-color-tokens: skip missing dir %s\n", dir))
    end
  end
  table.sort(files)

  for _, path in ipairs(files) do
    local lines = readLines(path)
    if not lines then
      io.stderr:write(string.format("ui-color-tokens: cannot read %s\n", path))
      os.exit(2)
    end
    for lineno, line in ipairs(lines) do
      if not lineHasOverride(line) then
        local method = findLiteralColorCall(line)
        if method then
          issues[#issues + 1] = string.format(
            "%s:%d: literal color argument passed to %s(...) -- add/reuse a token in UICommon.Colors"
              .. " (ui/isiLive_ui_common.lua) and call it via unpack(...)",
            path,
            lineno,
            method
          )
        end
      end
    end
  end

  if #issues == 0 then
    io.write("ui-color-tokens: clean -- no literal SetTextColor/SetVertexColor/SetColorTexture arguments in ui/\n")
    os.exit(0)
  end

  io.write(string.format("ui-color-tokens: %d issue(s) found\n\n", #issues))
  for _, line in ipairs(issues) do
    io.write("  " .. line .. "\n")
  end
  os.exit(1)
end

main()
