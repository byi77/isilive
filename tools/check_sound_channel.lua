#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Pins the current project sound-channel policy: every built-in isiLive sound
-- defaults to channel "Master". The only supported "SFX" path is the persisted
-- user output-channel setting; hard-coded SFX playback remains forbidden unless
-- a line is explicitly documented with the inline override below.
--
-- Scans production Lua files (core / factory / game / logic / ui) for any
-- "SFX" string literal that appears in a sound-related context. A line
-- counts as sound-related if it mentions PlaySound, defaultChannel, channel,
-- or Sound — that catches both direct PlaySoundFile(..., "SFX") calls and
-- indirect entries like `defaultChannel = "SFX"` in a sound registry.
--
-- Inline override: append `-- sound-ok` to a line to silence the gate. Use it
-- only for the persisted soundOutputChannel setting or for genuinely non-sound
-- usages of the literal "SFX" (extremely rare in this codebase).
--
-- Exits 0 on clean, 1 on violations, 2 on IO/setup errors.
-- Run from repo root:
--   lua tools/check_sound_channel.lua

local SCAN_DIRS = { "core", "factory", "game", "logic", "ui" }

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
  -- Lua single-line comment starts with `--` outside of a string. We keep
  -- it simple: split on the first `--` that follows non-quote content. This
  -- mis-handles `"--"` literals, but those do not occur in sound-call lines
  -- in this codebase.
  local pos = line:find("%-%-")
  if pos then
    return line:sub(1, pos - 1)
  end
  return line
end

local function isSoundContext(line)
  -- Match without anchors so PlaySoundFile / PlaySound / defaultChannel /
  -- channel = "..." / sound = "..." all qualify.
  if line:find("PlaySound") then
    return true
  end
  if line:find("defaultChannel") then
    return true
  end
  -- Plain "channel" needs to appear as an identifier (= / : / . / followed by
  -- a literal). A naïve match risks false positives, so require the literal
  -- "SFX" to follow within the same line.
  if line:lower():find("channel") then
    return true
  end
  return false
end

local function lineHasSoundOk(line)
  return line:match("%-%-%s*sound%-ok") ~= nil or line:match("%-%-%s*sound:%s*ok") ~= nil
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
      io.stderr:write(string.format("sound-channel: cannot read %s\n", path))
      os.exit(2)
    end
    for lineno, raw in ipairs(lines) do
      if not lineHasSoundOk(raw) then
        local code = stripComment(raw)
        if code:find('"SFX"') and isSoundContext(code) then
          issues[#issues + 1] = string.format(
            '%s:%d: hard-coded sound channel "SFX" detected — default to "Master" '
              .. "or mark the persisted user setting with -- sound-ok",
            path,
            lineno
          )
        end
      end
    end
  end

  if #issues == 0 then
    io.write(
      'sound-channel: clean — built-in playback defaults to "Master"; only documented user-setting SFX paths remain\n'
    )
    os.exit(0)
  end

  io.write(string.format("sound-channel: %d violation(s) found\n\n", #issues))
  for _, line in ipairs(issues) do
    io.write("  " .. line .. "\n")
  end
  os.exit(1)
end

main()
