#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Sound asset gate (rule 266). The sound registry
-- (core/isiLive_sound_registry.lua) is the only place that names a bundled
-- sound file. This gate checks, in both directions:
--
--   1. every file the registry references (file, fallbackFile,
--      localizedFiles.*, voice.file, voice.fallbackFile,
--      voice.localizedFiles.*) exists in sounds/, is whitelisted in
--      .gitignore (`!sounds/<name>`) and has an entry in
--      docs/AUDIO_ASSETS.json (`"path": "sounds/<name>"`);
--   2. every file in sounds/ is referenced by the registry and whitelisted;
--   3. no production Lua file outside the registry contains a literal
--      `Interface\AddOns\isiLive\sounds\` path.
--
-- A registry string that names the sounds folder in any other field also
-- fails, so a new field cannot slip past check 1.
--
-- Exits 0 on clean, 1 on violations, 2 on IO/setup errors.
-- Run from repo root:
--   lua tools/check_sound_assets.lua

local REGISTRY_FILE = "core/isiLive_sound_registry.lua"
local SOUNDS_DIR = "sounds"
local GITIGNORE_FILE = ".gitignore"
local AUDIO_ASSETS_FILE = "docs/AUDIO_ASSETS.json"
local SOUND_PATH_PREFIX = "Interface\\AddOns\\isiLive\\sounds\\"
-- Production Lua (everything the TOC can load). Tests and tools may name
-- sound paths to assert on them.
local SCAN_DIRS = { "core", "data", "factory", "game", "locale", "logic", "ui" }

local ok_lfs, lfs = pcall(require, "lfs")
if not ok_lfs then
  lfs = require("tools.lfs_compat")
end

local function fail(code, message)
  io.stderr:write("sound-assets: " .. message .. "\n")
  os.exit(code)
end

local function readFile(path)
  local fh = io.open(path, "rb")
  if not fh then
    return nil
  end
  local content = fh:read("*a")
  fh:close()
  return content
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

local function sortedKeys(set)
  local keys = {}
  for key in pairs(set) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

local failures = {}
local function report(message)
  failures[#failures + 1] = "  " .. message
end

-- 1. Load the registry exactly as the client does (`local _, addonTable = ...`).
local chunk, loadErr = loadfile(REGISTRY_FILE)
if not chunk then
  fail(2, "cannot load " .. REGISTRY_FILE .. ": " .. tostring(loadErr))
end
local addonTable = {}
local okRun, runErr = pcall(chunk, "isiLive", addonTable)
if not okRun then
  fail(2, REGISTRY_FILE .. " raised: " .. tostring(runErr))
end
local registry = type(addonTable.SoundRegistry) == "table" and addonTable.SoundRegistry.Registry or nil
if type(registry) ~= "table" then
  fail(2, REGISTRY_FILE .. " does not export SoundRegistry.Registry")
end

local referenced = {} -- file name -> list of "key.field"
local checkedStrings = {} -- registry strings covered by the known fields

local function addReference(key, field, value)
  if type(value) ~= "string" then
    return
  end
  checkedStrings[value] = true
  if value:sub(1, #SOUND_PATH_PREFIX) ~= SOUND_PATH_PREFIX then
    report(string.format("registry %s.%s does not start with %s: %s", key, field, SOUND_PATH_PREFIX, value))
    return
  end
  local name = value:sub(#SOUND_PATH_PREFIX + 1)
  if name == "" or name:find("[\\/]") then
    report(string.format("registry %s.%s must name a file directly in sounds/: %s", key, field, value))
    return
  end
  referenced[name] = referenced[name] or {}
  table.insert(referenced[name], key .. "." .. field)
end

local function addFileSet(key, prefix, spec)
  if type(spec) ~= "table" then
    return
  end
  addReference(key, prefix .. "file", spec.file)
  addReference(key, prefix .. "fallbackFile", spec.fallbackFile)
  if type(spec.localizedFiles) == "table" then
    for locale, path in pairs(spec.localizedFiles) do
      addReference(key, prefix .. "localizedFiles." .. tostring(locale), path)
    end
  end
end

-- Any string anywhere in an entry that points into the sounds folder must be
-- one of the known fields above.
local function scanStrings(key, value, path)
  if type(value) == "string" then
    if value:lower():find("isilive[\\/]+sounds[\\/]") and not checkedStrings[value] then
      report(string.format("registry %s.%s names a sound file in an unchecked field: %s", key, path, value))
    end
  elseif type(value) == "table" then
    for field, child in pairs(value) do
      scanStrings(key, child, path == "" and tostring(field) or (path .. "." .. tostring(field)))
    end
  end
end

for _, key in ipairs(sortedKeys(registry)) do
  local entry = registry[key]
  addFileSet(key, "", entry)
  addFileSet(key, "voice.", type(entry) == "table" and entry.voice or nil)
end
for _, key in ipairs(sortedKeys(registry)) do
  scanStrings(key, registry[key], "")
end

-- 2. Files in sounds/.
local present = {}
if lfs.attributes(SOUNDS_DIR, "mode") ~= "directory" then
  fail(2, SOUNDS_DIR .. "/ not found (run from repo root)")
end
for entry in lfs.dir(SOUNDS_DIR) do
  if entry ~= "." and entry ~= ".." and lfs.attributes(SOUNDS_DIR .. "/" .. entry, "mode") == "file" then
    present[entry] = true
  end
end

-- 3. .gitignore whitelist.
local gitignore = readFile(GITIGNORE_FILE)
if not gitignore then
  fail(2, "cannot read " .. GITIGNORE_FILE)
end
local whitelisted = {}
for line in gitignore:gmatch("[^\r\n]+") do
  local name = line:match("^!sounds/(.+)$")
  if name then
    whitelisted[name] = true
  end
end

-- 4. docs/AUDIO_ASSETS.json entries (every "path" value).
local assetsJson = readFile(AUDIO_ASSETS_FILE)
if not assetsJson then
  fail(2, "cannot read " .. AUDIO_ASSETS_FILE)
end
local documented = {}
for path in assetsJson:gmatch('"path"%s*:%s*"([^"]+)"') do
  local name = path:match("^sounds/(.+)$")
  if name then
    documented[name] = true
  end
end

for _, name in ipairs(sortedKeys(referenced)) do
  local users = table.concat(referenced[name], ", ")
  if not present[name] then
    report(string.format("sounds/%s is missing (referenced by %s)", name, users))
  end
  if not whitelisted[name] then
    report(string.format("sounds/%s is not whitelisted in %s (!sounds/%s)", name, GITIGNORE_FILE, name))
  end
  if not documented[name] then
    report(string.format("sounds/%s has no entry in %s", name, AUDIO_ASSETS_FILE))
  end
end
for _, name in ipairs(sortedKeys(present)) do
  if not referenced[name] then
    report(string.format("sounds/%s is not referenced by the sound registry", name))
  end
end
for _, name in ipairs(sortedKeys(whitelisted)) do
  if not referenced[name] then
    report(string.format("%s whitelists sounds/%s, which the registry does not reference", GITIGNORE_FILE, name))
  end
end
for _, name in ipairs(sortedKeys(documented)) do
  if not referenced[name] then
    report(string.format("%s lists sounds/%s, which the registry does not reference", AUDIO_ASSETS_FILE, name))
  end
end

-- 5. No literal sound path outside the registry.
local files = {}
for _, dir in ipairs(SCAN_DIRS) do
  if lfs.attributes(dir, "mode") == "directory" then
    walkDir(dir, files)
  end
end
table.sort(files)
for _, path in ipairs(files) do
  if path ~= REGISTRY_FILE then
    local content = readFile(path) or ""
    local lineNo = 0
    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
      lineNo = lineNo + 1
      if line:lower():find("isilive[\\/]+sounds[\\/]") then
        report(string.format("%s:%d names a sound path outside the registry", path, lineNo))
      end
    end
  end
end

local referencedCount = #sortedKeys(referenced)
if #failures > 0 then
  io.stderr:write(string.format("sound-assets: %d issue(s) found\n", #failures))
  for _, message in ipairs(failures) do
    io.stderr:write(message .. "\n")
  end
  os.exit(1)
end
print(
  string.format("sound-assets: clean (%d registry files, all present, whitelisted and documented)", referencedCount)
)
os.exit(0)
