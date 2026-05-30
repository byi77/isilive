#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Bidirectional consistency gate between isiLive.toc and the on-disk Lua
-- file layout. Two failure modes — both observable only inside WoW, never
-- in the test runner:
--
--   * Dead reference: the TOC names a file that no longer exists on disk.
--     WoW logs "Missing dependencies" or refuses to load the addon entirely.
--   * Missing reference: a Lua file lives in core / factory / game / locale
--     /  logic / ui but the TOC does not name it. Tests find it (loadfile
--     can read any path) but WoW never reaches it because the addon loader
--     only runs files listed in the TOC.
--
-- This catches both: every line in `isiLive.toc` that names a Lua file must
-- exist, and every Lua file in the production source dirs must be named in
-- the TOC.
--
-- Source dirs scanned bidirectionally:
--   core / factory / game / locale / logic / ui  +  isiLive.lua at root
-- Skipped: testmodul / tools / libs (vendored) / data (referenced explicitly)
--
-- Exits 0 on clean, 1 on violations, 2 on IO/setup errors.
-- Run from repo root:
--   lua tools/check_toc_file_list.lua

local TOC_PATH = "isiLive.toc"
local TRACKED_DIRS = { "core", "factory", "game", "locale", "logic", "ui" }
-- Files that may live in the TOC but aren't under TRACKED_DIRS — explicitly
-- listed so the existence check still applies, but the missing-reference
-- check skips them. `libs/` is vendored; `data/` holds the MDT-synced forces
-- DB (one file, referenced explicitly in TOC).
local EXTRA_TOC_PATHS = {
  ["libs/ChatThrottleLib/ChatThrottleLib.lua"] = true,
  ["data/isiLive_mplus_forces.lua"] = true,
  ["isiLive.lua"] = true,
}

local ok_lfs, lfs = pcall(require, "lfs")
if not ok_lfs then
  lfs = require("tools.lfs_compat")
end

local function fail(code, message)
  io.stderr:write("toc-file-list: " .. message .. "\n")
  os.exit(code)
end

local function fileExists(path)
  return lfs.attributes(path, "mode") == "file"
end

local function NormalizeSlashes(p)
  -- TOC files use forward slashes by convention. lfs.dir on Windows returns
  -- entries without a leading prefix, but path concatenation here uses "/".
  return (p:gsub("\\", "/"))
end

local function ReadTocReferences()
  local fh, err = io.open(TOC_PATH, "r")
  if not fh then
    fail(2, "cannot open " .. TOC_PATH .. ": " .. tostring(err))
  end
  local refs = {}
  local lineno = 0
  for line in fh:lines() do
    lineno = lineno + 1
    -- Trim leading whitespace, ignore comments / metadata directives.
    local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed ~= "" and not trimmed:match("^#") then
      if trimmed:match("%.lua$") then
        refs[#refs + 1] = { path = NormalizeSlashes(trimmed), lineno = lineno }
      end
    end
  end
  fh:close()
  return refs
end

local function WalkDirCollectLua(dir, files)
  if lfs.attributes(dir, "mode") ~= "directory" then
    return files
  end
  for entry in lfs.dir(dir) do
    if entry ~= "." and entry ~= ".." then
      local path = dir .. "/" .. entry
      local mode = lfs.attributes(path, "mode")
      if mode == "directory" then
        WalkDirCollectLua(path, files)
      elseif mode == "file" and path:match("%.lua$") then
        files[#files + 1] = path
      end
    end
  end
  return files
end

local function main()
  local issues = {}

  -- Direction 1: every TOC reference points to a file that exists.
  local tocRefs = ReadTocReferences()
  local tocSet = {}
  for _, ref in ipairs(tocRefs) do
    tocSet[ref.path] = true
    if not fileExists(ref.path) then
      issues[#issues + 1] =
        string.format("%s:%d: dead reference '%s' — file does not exist on disk", TOC_PATH, ref.lineno, ref.path)
    end
  end

  -- Direction 2: every Lua file in the tracked dirs is referenced in the TOC.
  for _, dir in ipairs(TRACKED_DIRS) do
    local files = WalkDirCollectLua(dir, {})
    table.sort(files)
    for _, path in ipairs(files) do
      local normalized = NormalizeSlashes(path)
      if not tocSet[normalized] and not EXTRA_TOC_PATHS[normalized] then
        issues[#issues + 1] = string.format(
          "%s: untracked file — exists on disk but is NOT listed in %s " .. "(addon will silently skip it inside WoW)",
          normalized,
          TOC_PATH
        )
      end
    end
  end

  -- Direction 1b: also verify the EXTRA_TOC_PATHS exist (so the override
  -- table doesn't drift away from reality).
  for path in pairs(EXTRA_TOC_PATHS) do
    if not fileExists(path) then
      issues[#issues + 1] = string.format(
        "EXTRA_TOC_PATHS lists '%s' but the file does not exist on disk -- " .. "remove the entry or restore the file",
        path
      )
    end
  end

  if #issues == 0 then
    io.write(
      string.format("toc-file-list: clean -- %s and disk agree (%d Lua references checked)\n", TOC_PATH, #tocRefs)
    )
    os.exit(0)
  end

  io.write(string.format("toc-file-list: %d violation(s) found\n\n", #issues))
  for _, line in ipairs(issues) do
    io.write("  " .. line .. "\n")
  end
  os.exit(1)
end

main()
