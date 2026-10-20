#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Validates data/isiLive_specs.lua as the single source for per-spec data:
-- 1. every record carries the required fields,
-- 2. every spec has an interrupt decision in game/isiLive_kick_tracker.lua
--    (SPEC_DATA entry or NO_INTERRUPT_SPEC_IDS) and the kick tracker names no
--    spec the manifest lacks,
-- 3. no runtime module keeps its own literal spec-ID table again (a run of at
--    least MIN_SPEC_KEYS_PER_TABLE known spec IDs used as `[id] =` keys).

local M = {}

local DEFAULT_DATA_PATH = "data/isiLive_specs.lua"
local DEFAULT_KICK_TRACKER_PATH = "game/isiLive_kick_tracker.lua"
local DEFAULT_SCAN_DIRS = { "core", "factory", "game", "logic", "ui" }
local MIN_SPEC_KEYS_PER_TABLE = 3

local CLASS_TOKENS = {
  DEATHKNIGHT = true,
  DEMONHUNTER = true,
  DRUID = true,
  EVOKER = true,
  HUNTER = true,
  MAGE = true,
  MONK = true,
  PALADIN = true,
  PRIEST = true,
  ROGUE = true,
  SHAMAN = true,
  WARLOCK = true,
  WARRIOR = true,
}
local LFG_FLAGS = { "intellect", "attackPower", "magicDamage", "physicalDamage" }
local PRIMARY_STATS = { strength = true, agility = true, intellect = true }

-- Literal spec-keyed tables that deliberately stay outside data/.
local ALLOWED_LITERAL_TABLES = {
  -- Interrupt spell + tooltip-audited cooldown per spec (interrupt-audit skill).
  ["game/isiLive_kick_tracker.lua:SPEC_DATA"] = true,
  ["game/isiLive_kick_tracker.lua:NO_INTERRUPT_SPEC_IDS"] = true,
}

local function ReadFile(path)
  local file, err = io.open(path, "rb")
  if not file then
    return nil, string.format("cannot read %s: %s", tostring(path), tostring(err))
  end
  local content = file:read("*a") or ""
  file:close()
  return content
end

local function LoadManifest(path)
  local chunk, loadErr = loadfile(path)
  if not chunk then
    return nil, string.format("cannot load %s: %s", tostring(path), tostring(loadErr))
  end
  local addonTable = {}
  local ok, runErr = pcall(chunk, "isiLive", addonTable)
  if not ok then
    return nil, string.format("load error in %s: %s", tostring(path), tostring(runErr))
  end
  if type(addonTable.SpecManifest) ~= "table" or type(addonTable.SpecManifest.specs) ~= "table" then
    return nil, string.format("%s does not define SpecManifest.specs", tostring(path))
  end
  return addonTable.SpecManifest
end

local function SortedKeys(map)
  local keys = {}
  for key in pairs(map) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

local function ValidateRecords(errors, specs)
  for _, specID in ipairs(SortedKeys(specs)) do
    local spec = specs[specID]
    local label = "spec " .. tostring(specID)
    if type(specID) ~= "number" or specID <= 0 or specID ~= math.floor(specID) then
      errors[#errors + 1] = label .. ": key must be a positive integer spec ID"
    end
    if type(spec) ~= "table" then
      errors[#errors + 1] = label .. ": record must be a table"
    else
      if not CLASS_TOKENS[spec.class] then
        errors[#errors + 1] = label .. ": class must be a known class token"
      end
      if type(spec.name) ~= "string" or spec.name == "" then
        errors[#errors + 1] = label .. ": name is required"
      end
      if type(spec.lfg) ~= "table" then
        errors[#errors + 1] = label .. ": lfg profile is required"
      else
        for _, flag in ipairs(LFG_FLAGS) do
          if type(spec.lfg[flag]) ~= "boolean" then
            errors[#errors + 1] = string.format("%s: lfg.%s must be an explicit boolean", label, flag)
          end
        end
      end
      if spec.primaryStat ~= nil and not PRIMARY_STATS[spec.primaryStat] then
        errors[#errors + 1] = label .. ": primaryStat must be strength, agility or intellect"
      end
    end
  end
end

-- Returns the body of `local <name> = { ... }` up to the first top-level `}`.
local function ExtractTopLevelTable(source, name)
  local startPos = source:find("\nlocal " .. name .. " = {\n", 1, true)
  if not startPos then
    return nil
  end
  local bodyStart = startPos + #("\nlocal " .. name .. " = {\n")
  local endPos = source:find("\n}\n", bodyStart, true)
  if not endPos then
    return nil
  end
  return source:sub(bodyStart, endPos)
end

local function ParseKickTracker(errors, source)
  local covered = {}
  local specData = ExtractTopLevelTable(source, "SPEC_DATA")
  local noInterrupt = ExtractTopLevelTable(source, "NO_INTERRUPT_SPEC_IDS")
  if not specData then
    errors[#errors + 1] = "kick tracker: SPEC_DATA table not found"
  end
  if not noInterrupt then
    errors[#errors + 1] = "kick tracker: NO_INTERRUPT_SPEC_IDS table not found"
  end
  -- Only top-level (two-space indented) keys are spec IDs; nested spell lists
  -- sit deeper. `[id] = nil` documents a spec without interrupt and counts only
  -- when NO_INTERRUPT_SPEC_IDS lists it too.
  for line in (specData or ""):gmatch("[^\n]+") do
    local specID, value = line:match("^  %[(%d+)%] = (%S+)")
    if specID and value ~= "nil," then
      covered[tonumber(specID)] = "SPEC_DATA"
    end
  end
  for line in (noInterrupt or ""):gmatch("[^\n]+") do
    local specID = line:match("^  %[(%d+)%] = true")
    if specID then
      covered[tonumber(specID)] = "NO_INTERRUPT_SPEC_IDS"
    end
  end
  return covered
end

local function ValidateKickCoverage(errors, specs, covered)
  for _, specID in ipairs(SortedKeys(specs)) do
    if not covered[specID] then
      errors[#errors + 1] = string.format(
        "spec %d has no interrupt decision in game/isiLive_kick_tracker.lua (SPEC_DATA or NO_INTERRUPT_SPEC_IDS)",
        specID
      )
    end
  end
  for _, specID in ipairs(SortedKeys(covered)) do
    if specs[specID] == nil then
      errors[#errors + 1] =
        string.format("kick tracker %s names spec %d, which data/isiLive_specs.lua lacks", covered[specID], specID)
    end
  end
end

-- Finds runs of `[id] =` lines whose keys are known spec IDs. Blank and comment
-- lines do not break a run; any other line does. The run is attributed to the
-- nearest preceding `local NAME = {` for the allowlist.
function M.FindLiteralSpecTables(path, source, specs)
  local hits = {}
  local currentName
  local run = { count = 0 }
  local function Flush()
    if run.count >= MIN_SPEC_KEYS_PER_TABLE then
      local key = path .. ":" .. tostring(run.name)
      if not ALLOWED_LITERAL_TABLES[key] then
        hits[#hits + 1] = { path = path, line = run.firstLine, name = run.name, count = run.count }
      end
    end
    run = { count = 0 }
  end

  local lineNumber = 0
  for line in (source .. "\n"):gmatch("([^\n]*)\n") do
    lineNumber = lineNumber + 1
    local tableName = line:match("^local ([%w_]+) = {%s*$")
    if tableName then
      currentName = tableName
    end
    local key = line:match("^%s*%[(%d+)%]%s*=")
    if key and specs[tonumber(key)] ~= nil then
      if run.count == 0 then
        run.firstLine = lineNumber
        run.name = currentName
      end
      run.count = run.count + 1
    elseif not (line:match("^%s*$") or line:match("^%s*%-%-")) then
      Flush()
    end
  end
  Flush()
  return hits
end

local function ListLuaFiles(dir)
  local files = {}
  local isWindows = package.config:sub(1, 1) == "\\"
  local command = isWindows and string.format('dir /b /s "%s\\*.lua" 2>nul', dir:gsub("/", "\\"))
    or string.format('find "%s" -name "*.lua" 2>/dev/null', dir)
  local handle = io.popen(command)
  if not handle then
    return files
  end
  for line in handle:lines() do
    local normalized = line:gsub("\\", "/")
    local relative = normalized:match("(" .. dir:gsub("%-", "%%-") .. "/.+%.lua)$")
    if relative then
      files[#files + 1] = relative
    end
  end
  handle:close()
  table.sort(files)
  return files
end

function M.Check(opts)
  opts = opts or {}
  local errors = {}
  local manifest, manifestErr = LoadManifest(opts.dataPath or DEFAULT_DATA_PATH)
  if not manifest then
    errors[#errors + 1] = manifestErr
  end
  local kickSource, kickErr = ReadFile(opts.kickTrackerPath or DEFAULT_KICK_TRACKER_PATH)
  if not kickSource then
    errors[#errors + 1] = kickErr
  end

  local specCount = 0
  local scannedFiles = 0
  if manifest then
    local specs = manifest.specs
    specCount = #SortedKeys(specs)
    ValidateRecords(errors, specs)
    if kickSource then
      ValidateKickCoverage(errors, specs, ParseKickTracker(errors, kickSource))
    end

    local files = opts.scanFiles
    if type(files) ~= "table" then
      files = {}
      for _, dir in ipairs(opts.scanDirs or DEFAULT_SCAN_DIRS) do
        for _, file in ipairs(ListLuaFiles(dir)) do
          files[#files + 1] = file
        end
      end
    end
    for _, file in ipairs(files) do
      local source = ReadFile(file)
      if source then
        scannedFiles = scannedFiles + 1
        for _, hit in ipairs(M.FindLiteralSpecTables(file, source, specs)) do
          errors[#errors + 1] = string.format(
            "%s:%d: literal spec-ID table %s (%d spec keys) -- move it into data/isiLive_specs.lua",
            hit.path,
            hit.line,
            tostring(hit.name),
            hit.count
          )
        end
      end
    end
  end

  local lines = {
    "## Spec Coverage Check",
    "",
    "- Status: " .. (#errors == 0 and "valid" or "invalid"),
    string.format("- Specs: %d", specCount),
    string.format("- Scanned runtime files: %d", scannedFiles),
  }
  if #errors > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "### Fehler"
    for _, err in ipairs(errors) do
      lines[#lines + 1] = "- " .. err
    end
  end
  return #errors == 0, { errors = errors, specCount = specCount, summary = table.concat(lines, "\n") .. "\n" }
end

local cliArg = rawget(_G, "arg")
local isDirectRun = type(cliArg) == "table"
  and type(cliArg[0]) == "string"
  and cliArg[0]:find("check_spec_coverage.lua", 1, true) ~= nil

if isDirectRun then
  local ok, result = M.Check({})
  io.write(result.summary)
  if not ok then
    os.exit(1)
  end
end

return M
