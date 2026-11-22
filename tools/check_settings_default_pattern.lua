#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Pins the CLAUDE.md "Settings: default-on / default-off pattern" rule.
--
-- For every boolean setting written by the settings panel (patterns
-- `db.X = checked` or `db.X = checked == true`), verify there is a boolean
-- schema default, at least one matching read site
-- elsewhere in the codebase, and that all reads use a CONSISTENT pattern:
--
--   * Pattern A (default-ON):  read = `db.X ~= false`
--   * Pattern B (default-OFF): read = `db.X == true`
--   * Pattern C (migration in factory.lua ApplyDBSettings):
--                             `if db.X == nil then db.X = ... end`
--                              followed by Pattern A reads elsewhere
--
-- Mixed patterns silently flip the default for some users when the read-
-- pattern is changed without a migration block — the v0.9.211 settings
-- audit found this class of drift after a long delay.
--
-- The gate skips:
--   * non-boolean writes (db.X = tonumber(val), db.X = NormalizeXxx(val), ...)
--   * computed-boolean writes (db.X = (mode == "Y")) — those are
--     deliberate and accompany migration blocks already
--
-- Sound registry keys (rule 266): the sound settings write their keys
-- generically (`db[settingKey] = checked`, `db[voice.settingKey] = ...`), so
-- the literal scan above cannot see them. The gate therefore also loads
-- core/isiLive_sound_registry.lua and checks every `settingKey` and
-- `voice.settingKey`: `defaultEnabled ~= false` demands Pattern A reads only,
-- `defaultEnabled == false` Pattern B reads only; the schema default must
-- match; and a write site must exist (the generic writers in
-- ui/isiLive_settings_sound.lua for SettingsOrder entries and
-- ui/isiLive_settings_sound_voice.lua for voice parts,
-- otherwise a literal write or the key as a string in a settings file).
--
-- Exits 0 on clean, 1 on inconsistencies found, 2 on IO/setup errors.
-- Run from repo root:
--   lua tools/check_settings_default_pattern.lua

local SCAN_DIRS = { "core", "factory", "game", "logic", "ui" }
local SETTINGS_DIR = "ui"
local SETTINGS_FILE_PATTERN = "^isiLive_settings.*%.lua$"
-- One-time IsiLiveDB migrations (Pattern C) live in MigrateDBSettings.
local FACTORY_FILE = "factory/isiLive_factory_db_settings.lua"
local DB_SCHEMA_FILE = "core/isiLive_db_schema.lua"
local SOUND_REGISTRY_FILE = "core/isiLive_sound_registry.lua"
local SOUND_SETTINGS_FILE = "ui/isiLive_settings_sound.lua"
local VOICE_SETTINGS_FILE = "ui/isiLive_settings_sound_voice.lua"
-- Generic writers of the sound settings panel (registry-driven keys).
local GENERIC_SOUND_WRITE = "db%[settingKey%]%s*=%s*checked"
local GENERIC_VOICE_WRITE = "db%[voice%.settingKey%]%s*=%s*checked"

-- Settings that are deliberately exempt (e.g. computed booleans that derive
-- their value from a string-mode selector and use Pattern C migration).
local OVERRIDES = {
  -- mode-toggle written via `db.X = (mode == "...")` and migrated in
  -- ApplyDBSettings — flagging would be a false positive.
  mobNameplateEnabled = "tri-state mode-toggle (off/tooltip/nameplate); migrated in ApplyDBSettings",
  mplusForcesEstimate = "tri-state mode-toggle (off/tooltip/nameplate); migrated in ApplyDBSettings",
}

-- Directory walking via io.popen instead of LuaFileSystem so the gate is
-- runnable on a stock Lua install (no `luarocks install luafilesystem`).
-- The CI runner has lfs available, but pre-commit / local audits should not
-- need an extra dep just to verify the settings pattern.
local function listEntries(dir)
  local sep = package.config:sub(1, 1)
  local files, dirs = {}, {}
  if sep == "\\" then
    -- Windows cmd: /A:-D = non-directories, /A:D = directories.
    local fileP = io.popen('dir /b /A:-D "' .. dir:gsub("/", "\\") .. '" 2>nul')
    if fileP then
      for line in fileP:lines() do
        line = line:gsub("\r$", "")
        if line ~= "" then
          files[#files + 1] = line
        end
      end
      fileP:close()
    end
    local dirP = io.popen('dir /b /A:D "' .. dir:gsub("/", "\\") .. '" 2>nul')
    if dirP then
      for line in dirP:lines() do
        line = line:gsub("\r$", "")
        if line ~= "" then
          dirs[#dirs + 1] = line
        end
      end
      dirP:close()
    end
  else
    -- POSIX: `ls -A -p` marks directories with a trailing slash.
    local p = io.popen('ls -A -p "' .. dir .. '" 2>/dev/null')
    if p then
      for line in p:lines() do
        if line:sub(-1) == "/" then
          dirs[#dirs + 1] = line:sub(1, -2)
        elseif line ~= "" then
          files[#files + 1] = line
        end
      end
      p:close()
    end
  end
  return files, dirs
end

local function dirExists(path)
  -- Probe via listEntries — listing a missing dir yields zero entries on
  -- both Windows and POSIX paths via io.popen. Distinguishes "missing dir"
  -- from "empty dir" only weakly, but for our scan dirs that is acceptable:
  -- core/factory/game/logic/ui are never legitimately empty in this repo.
  local files, dirs = listEntries(path)
  return (#files + #dirs) > 0
end

local function fail(code, message)
  io.stderr:write("settings-default-pattern: " .. message .. "\n")
  os.exit(code)
end

local function walkDir(dir, files)
  local entryFiles, entryDirs = listEntries(dir)
  for _, name in ipairs(entryFiles) do
    if name:match("%.lua$") then
      files[#files + 1] = dir .. "/" .. name
    end
  end
  for _, name in ipairs(entryDirs) do
    walkDir(dir .. "/" .. name, files)
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

-- ----------------------------------------------------------------------
-- Step 1: enumerate boolean writes in the settings panel.
-- A "boolean write" is `db.X = checked` exactly (no transformation) — we
-- also accept `db.X = checked == true`, which is the same persisted boolean
-- normalization. We ignore numeric / string / other computed writes.
-- ----------------------------------------------------------------------
local function collectSettingsFiles()
  if not dirExists(SETTINGS_DIR) then
    fail(2, "scan dir mismatch: " .. SETTINGS_DIR .. " not found (run from repo root)")
  end
  local files = {}
  local entryFiles = listEntries(SETTINGS_DIR)
  for _, name in ipairs(entryFiles) do
    if name:match(SETTINGS_FILE_PATTERN) then
      files[#files + 1] = SETTINGS_DIR .. "/" .. name
    end
  end
  table.sort(files)
  return files
end

local function collectBooleanWrites()
  local settingsFiles = collectSettingsFiles()
  if #settingsFiles == 0 then
    fail(2, "no settings files matched " .. SETTINGS_DIR .. "/" .. SETTINGS_FILE_PATTERN)
  end
  local settings = {}
  local sourceFiles = {}
  for _, path in ipairs(settingsFiles) do
    local content = readFile(path)
    if content == "" then
      fail(2, "cannot read " .. path)
    end
    sourceFiles[path] = true
    for fieldName in content:gmatch("db%.([%a_][%w_]*)%s*=%s*checked%s*==%s*true") do
      settings[fieldName] = true
    end
    for fieldName in content:gmatch("db%.([%a_][%w_]*)%s*=%s*checked") do
      settings[fieldName] = true
    end
  end
  return settings, sourceFiles
end

local function collectBooleanSchemaDefaults()
  local content = readFile(DB_SCHEMA_FILE)
  if content == "" then
    fail(2, "cannot read " .. DB_SCHEMA_FILE)
  end
  local defaults = {}
  for fieldName in content:gmatch('([%a_][%w_]*)%s*=%s*{%s*type%s*=%s*"boolean"%s*,%s*default%s*=%s*true') do
    defaults[fieldName] = true
  end
  for fieldName in content:gmatch('([%a_][%w_]*)%s*=%s*{%s*type%s*=%s*"boolean"%s*,%s*default%s*=%s*false') do
    defaults[fieldName] = false
  end
  return defaults
end

-- ----------------------------------------------------------------------
-- Step 2: for each setting, scan production code for read patterns.
--
--   Pattern A read:  db.X ~= false
--   Pattern B read:  db.X == true
--   Pattern C migr:  if db.X == nil then ... db.X = ... end (factory.lua)
--
-- Returns: { [setting] = { patternA = bool, patternB = bool, hasMigration = bool } }
-- ----------------------------------------------------------------------
local function classifyReads(settings, files, settingsSourceFiles)
  local result = {}
  for name in pairs(settings) do
    result[name] = { patternA = false, patternB = false, hasMigration = false }
  end

  -- Migration check (FACTORY_FILE only). Match "if <var>.X == nil then"
  -- where <var> is any local-table reference (db, dbRef, IsiLiveDB, ...).
  local factoryContent = readFile(FACTORY_FILE)
  for name in pairs(settings) do
    local migrationPattern = "if%s+[%w_]+%." .. name .. "%s*==%s*nil%s+then"
    if factoryContent:find(migrationPattern) then
      result[name].hasMigration = true
    end
  end

  -- Scan ALL production files for read patterns. We exclude settings files
  -- themselves (they have both writes AND their own reads of `db.X` to seed
  -- checkbox initial state, which would skew classification).
  --
  -- Pattern A (default-ON) read forms in the wild:
  --   `<var>.X ~= false`        -- standard
  --   `<var>.X == false`        -- inverted, in skip-the-ON-action context
  --   `not (<var>.X == false)`  -- explicit double-negation
  --
  -- Pattern B (default-OFF) read forms in the wild:
  --   `<var>.X == true`         -- standard
  --   `<var>.X ~= true`         -- inverted, in skip-the-OFF-action context
  --   `if <var>.X then`         -- truthy check (nil/false → skip, true → act)
  --
  -- Earlier versions of this gate matched only literal "db.X" + only the
  -- two standard forms, and missed the many call sites that read through
  -- factory-bridge variables (dbRef, savedDb, IsiLiveDB) or used the
  -- negated/truthy variants.
  for _, path in ipairs(files) do
    if not settingsSourceFiles[path] and not path:match("^tools/") then
      local content = readFile(path)
      for name in pairs(settings) do
        -- Pattern A: any "false" comparison against the field
        local patternA1 = "[%w_]+%." .. name .. "%s*~=%s*false"
        local patternA2 = "[%w_]+%." .. name .. "%s*==%s*false"
        if content:find(patternA1) or content:find(patternA2) then
          result[name].patternA = true
        end
        -- Pattern B: any "true" comparison OR truthy `if X then` check
        local patternB1 = "[%w_]+%." .. name .. "%s*==%s*true"
        local patternB2 = "[%w_]+%." .. name .. "%s*~=%s*true"
        local patternB3 = "and%s+[%w_]+%." .. name .. "%s+then"
        local patternB4 = "if%s+[%w_]+%." .. name .. "%s+then"
        if content:find(patternB1) or content:find(patternB2) or content:find(patternB3) or content:find(patternB4) then
          result[name].patternB = true
        end
      end
    end
  end
  return result
end

-- ----------------------------------------------------------------------
-- Step 3: classify each setting's status.
--
--   "ok-A"      = pattern A reads only (default-ON, consistent)
--   "ok-B"      = pattern B reads only (default-OFF, consistent)
--   "ok-C"      = pattern A reads + migration in ApplyDBSettings
--   "no-reads"  = settings panel writes but nothing reads ⇒ DEAD setting
--   "mixed"     = some reads use ~= false, others use == true (DRIFT RISK)
-- ----------------------------------------------------------------------
local function classifyStatus(name, info)
  if OVERRIDES[name] then
    return "override"
  end
  if not info.patternA and not info.patternB then
    return "no-reads"
  end
  if info.patternA and info.patternB then
    return "mixed"
  end
  if info.patternA then
    if info.hasMigration then
      return "ok-C"
    end
    return "ok-A"
  end
  return "ok-B"
end

-- ----------------------------------------------------------------------
-- Sound registry keys (rule 266).
-- Returns a list of { name, defaultOn, source, generic = "sound"|"voice"|nil }.
-- ----------------------------------------------------------------------
local function collectRegistrySettings()
  local chunk, loadErr = loadfile(SOUND_REGISTRY_FILE)
  if not chunk then
    fail(2, "cannot load " .. SOUND_REGISTRY_FILE .. ": " .. tostring(loadErr))
  end
  local addonTable = {}
  local ok, runErr = pcall(chunk, "isiLive", addonTable)
  local registryData = ok and addonTable.SoundRegistry or nil
  if type(registryData) ~= "table" or type(registryData.Registry) ~= "table" then
    fail(2, SOUND_REGISTRY_FILE .. " does not export SoundRegistry.Registry: " .. tostring(runErr))
  end
  local inOrder = {}
  for _, key in ipairs(registryData.SettingsOrder or {}) do
    inOrder[key] = true
  end
  local keys = {}
  for key in pairs(registryData.Registry) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  local list = {}
  for _, key in ipairs(keys) do
    local entry = registryData.Registry[key]
    if type(entry) == "table" and type(entry.settingKey) == "string" then
      list[#list + 1] = {
        name = entry.settingKey,
        defaultOn = entry.defaultEnabled ~= false,
        source = key,
        generic = inOrder[key] and "sound" or nil,
      }
    end
    local voice = type(entry) == "table" and entry.voice or nil
    if type(voice) == "table" and type(voice.settingKey) == "string" then
      list[#list + 1] = {
        name = voice.settingKey,
        defaultOn = voice.defaultEnabled ~= false,
        source = key .. ".voice",
        generic = "voice",
      }
    end
  end
  return list
end

local function auditRegistrySettings(files, settingsSourceFiles, literalWrites, schemaDefaults, failures)
  local list = collectRegistrySettings()
  local names = {}
  for _, item in ipairs(list) do
    names[item.name] = true
  end
  local reads = classifyReads(names, files, settingsSourceFiles)
  local soundSettings = readFile(SOUND_SETTINGS_FILE)
  local hasGeneric = {
    sound = soundSettings:find(GENERIC_SOUND_WRITE) ~= nil,
    voice = readFile(VOICE_SETTINGS_FILE):find(GENERIC_VOICE_WRITE) ~= nil,
  }
  local settingsText = {}
  for path in pairs(settingsSourceFiles) do
    settingsText[#settingsText + 1] = readFile(path)
  end
  settingsText = table.concat(settingsText, "\n")

  print("settings-default-pattern: " .. #list .. " sound registry keys audited")
  for _, item in ipairs(list) do
    local info = reads[item.name]
    local expected = item.defaultOn and "A" or "B"
    local problems = {}
    if item.defaultOn and info.patternB then
      problems[#problems + 1] = "registry default ON but a Pattern B read (`== true` / truthy) exists"
    end
    if not item.defaultOn and info.patternA then
      problems[#problems + 1] = "registry default OFF but a Pattern A read (`~= false` / `== false`) exists"
    end
    if schemaDefaults[item.name] == nil then
      problems[#problems + 1] = "no boolean default in " .. DB_SCHEMA_FILE
    elseif schemaDefaults[item.name] ~= item.defaultOn then
      problems[#problems + 1] = string.format(
        "schema default %s differs from registry defaultEnabled %s",
        tostring(schemaDefaults[item.name]),
        tostring(item.defaultOn)
      )
    end
    local written = (item.generic and hasGeneric[item.generic])
      or literalWrites[item.name]
      or settingsText:find('"' .. item.name .. '"', 1, true) ~= nil
    if not written then
      problems[#problems + 1] = "no write site in the settings panel"
    end
    local readLabel = (info.patternA and "A" or "") .. (info.patternB and "B" or "")
    if readLabel == "" then
      readLabel = "generic"
    end
    print(
      string.format(
        "  %-40s %-26s expect Pattern %s, literal reads: %s",
        item.name,
        "(" .. item.source .. ")",
        expected,
        readLabel
      )
    )
    for _, problem in ipairs(problems) do
      table.insert(failures, string.format("  %s (registry %s): %s", item.name, item.source, problem))
    end
  end
end

-- ----------------------------------------------------------------------
-- Main.
-- ----------------------------------------------------------------------
local function main()
  local files = {}
  for _, dir in ipairs(SCAN_DIRS) do
    if dirExists(dir) then
      walkDir(dir, files)
    end
  end

  local settings, settingsSourceFiles = collectBooleanWrites()
  local schemaDefaults = collectBooleanSchemaDefaults()
  local reads = classifyReads(settings, files, settingsSourceFiles)

  local failures = {}
  local report = {}
  local names = {}
  for name in pairs(settings) do
    names[#names + 1] = name
  end
  table.sort(names)

  for _, name in ipairs(names) do
    local info = reads[name]
    local status = classifyStatus(name, info)
    table.insert(report, { name = name, status = status, info = info })
    if schemaDefaults[name] == nil then
      table.insert(
        failures,
        string.format("  %s: written by settings panel, but has NO boolean default in %s", name, DB_SCHEMA_FILE)
      )
    end
    if status == "no-reads" then
      table.insert(
        failures,
        string.format("  %s: written by settings panel, but NO read site found (dead setting?)", name)
      )
    elseif status == "mixed" then
      table.insert(
        failures,
        string.format(
          "  %s: MIXED read patterns — some `~= false` (default-ON), some `== true` (default-OFF). "
            .. "Pick one and stick with it across the codebase.",
          name
        )
      )
    end
  end

  print("settings-default-pattern: " .. #names .. " boolean settings audited")
  for _, entry in ipairs(report) do
    local label = ({
      ["ok-A"] = "default-ON  (Pattern A: ~= false)",
      ["ok-B"] = "default-OFF (Pattern B: == true)",
      ["ok-C"] = "default-ON  (Pattern C: migration + ~= false)",
      ["override"] = "override (manually exempt)",
      ["no-reads"] = "FAIL: no read site",
      ["mixed"] = "FAIL: mixed read patterns",
    })[entry.status] or entry.status
    local schemaLabel = schemaDefaults[entry.name]
    if schemaLabel == nil then
      schemaLabel = "schema: MISSING"
    else
      schemaLabel = "schema default: " .. tostring(schemaLabel)
    end
    print(string.format("  %-40s %-45s %s", entry.name, label, schemaLabel))
  end

  auditRegistrySettings(files, settingsSourceFiles, settings, schemaDefaults, failures)

  if #failures > 0 then
    io.stderr:write("\n")
    io.stderr:write(string.format("settings-default-pattern: %d issue(s) found\n", #failures))
    for _, msg in ipairs(failures) do
      io.stderr:write(msg .. "\n")
    end
    os.exit(1)
  end

  print("settings-default-pattern: clean")
  os.exit(0)
end

main()
