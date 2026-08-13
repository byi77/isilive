#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Heuristic regression guard for the WoW 12.0 (Midnight) Secret Values
-- contract. In tainted M+ code paths several Blizzard APIs return masked
-- values that crash the addon when treated as plain strings/numbers. CLAUDE.md
-- mandates every such call site is wrapped in `pcall` AND the result passes
-- through an `IsSecretValue` guard (or returns nil/0 fallback).
--
-- This gate follows direct calls, table-method calls and local aliases into
-- pcall. For assigned pcall results it also verifies that the same returned
-- variable reaches an IsSecretValue/issecretvalue check before any other use.
-- Use the inline override `-- secret-value-ok` only when a maintainer has
-- confirmed that a wrapper outside the local analysis window enforces the
-- same ordering.
--
-- Watched APIs (any direct call to one of these triggers the gate):
--   * UnitGUID, UnitName, UnitFullName
--   * UnitExists, UnitReaction, UnitClass, UnitRace, UnitIsGroupLeader
--   * UnitGroupRolesAssigned, UnitIsUnit, UnitIsVisible, UnitIsConnected,
--     UnitIsDeadOrGhost, UnitIsPlayer, UnitLevel
--   * GetSpecialization, GetSpecializationInfo, GetSpecializationInfoByID,
--     GetInspectSpecialization, GetSpecializationRole,
--     GetSpecializationRoleByID
--   * GetAverageItemLevel, GetInspectItemLevel, GetBestMapForUnit,
--     GetIncomingSummonStatus
--   * FontString GetStringWidth
--   * GetActiveChallengeMapID, GetActiveKeystoneInfo and
--     IsChallengeModeActive
--   * CombatLogGetCurrentEventInfo (also forbidden in 12.0; double-belt)
--
-- Entry channels for a masked value (what this gate does and does not see):
--   1. Return value of a watched Blizzard API  -> covered by the call-site
--      rules below.
--   2. FIELD of a Blizzard-supplied table (event payload, API result struct,
--      tooltip data)                           -> covered by the payload-field
--      rule below.
--   3. Varargs of an event handler (e.g. the spellID of
--      UNIT_SPELLCAST_SUCCEEDED)               -> NOT covered statically. The
--      handler signature carries no marker a line-based gate could key on;
--      those paths are pinned by runtime simulators instead
--      (tools/simulate_secret_value_pipeline.lua).
--   4. Values handed to a callback by a Blizzard library or hook
--                                              -> NOT covered, same reason.
--
-- The channel-2 rule is line-local: a field copied into a local on one line and
-- compared on the next is not seen (`local e = rawget(aura, "expirationTime")`
-- followed by `e - now`). Routing every such read through
-- `Validators.ReadPlain*` is what closes that gap, not the gate.
--
-- Channel 2 was added after WoW 12.1 masked `unitAuraUpdateInfo.isFullUpdate`:
-- comparing it raised "attempt to compare field 'isFullUpdate' (a secret
-- boolean value)" and took down the whole UNIT_AURA dispatch, while this gate
-- stayed green because no watched API NAME appears on such a line. A rule
-- scoped to the symbols known when it was written certifies those symbols, not
-- the property it is meant to enforce.
--
-- Detector ownership (second, independent rule):
--   Only `core/isiLive_validation_helpers.lua` may read the raw `issecretvalue`
--   global. Every other production module must call
--   `addonTable.Validators.IsSecretValue`, so the rawget + type-check + pcall
--   hardening exists in exactly one place. Locally re-implemented detectors
--   have shipped without the pcall (and once without any guard at all), which
--   the call-site rules above cannot see.
--
-- A call is considered guarded when it is protected by `pcall` and its
-- returned value is rejected by `IsSecretValue`/`issecretvalue` in the same
-- short code window. Both protections are required.
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

-- The one module allowed to touch the raw `issecretvalue` global. Every other
-- production module must go through `addonTable.Validators.IsSecretValue`, so
-- the rawget + type-check + pcall hardening lives in exactly one place.
local CANONICAL_DETECTOR_FILE = "core/isiLive_validation_helpers.lua"

-- Pattern fragments ordered: longer/more specific names first so they are
-- matched before shorter prefixes (e.g. UnitFullName vs UnitName).
local WATCHED_APIS = {
  "GetSpecializationRoleByID",
  "GetInspectSpecialization",
  "GetSpecializationInfoByID",
  "GetSpecializationInfo",
  "GetSpecializationRole",
  "GetIncomingSummonStatus",
  "IsChallengeModeActive",
  "GetActiveKeystoneInfo",
  "GetInspectItemLevel",
  "UnitGroupRolesAssigned",
  "UnitIsDeadOrGhost",
  "UnitIsGroupLeader",
  "UnitIsConnected",
  "UnitIsPlayer",
  "CombatLogGetCurrentEventInfo",
  "GetActiveChallengeMapID",
  "GetAverageItemLevel",
  "GetBestMapForUnit",
  "GetSpecialization",
  "UnitFullName",
  "GetStringWidth",
  "UnitIsUnit",
  "UnitIsVisible",
  "UnitReaction",
  "UnitExists",
  "UnitLevel",
  "UnitClass",
  "UnitRace",
  "UnitGUID",
  "UnitName",
}

local WATCHED_API_SET = {}
for _, api in ipairs(WATCHED_APIS) do
  WATCHED_API_SET[api] = true
end

-- Fields of Blizzard-supplied tables that are known to carry Secret Values in
-- restricted instances. Only names Blizzard actually owns belong here -- a
-- generic name like `icon` or `name` would flag our own structs on every line.
local WATCHED_PAYLOAD_FIELDS = {
  "isFullUpdate",
  "addedAuras",
  "updatedAuraInstanceIDs",
  "removedAuraInstanceIDs",
  "removedAuras",
  "auraInstanceID",
  "expirationTime",
  "applications",
  "sourceUnit",
  "spellId",
}

-- Operations that raise when applied to a Secret Value. Assignment and plain
-- copying are safe and deliberately absent. Arithmetic requires surrounding
-- whitespace because StyLua enforces it, which keeps the pattern off unrelated
-- hyphens and slashes.
local PAYLOAD_FIELD_RISK_OPERATIONS = {
  { pattern = "#", label = "length-read" },
  { pattern = "==", label = "compared" },
  { pattern = "~=", label = "compared" },
  { pattern = "<", label = "compared" },
  { pattern = ">", label = "compared" },
  { pattern = "%.%.", label = "concatenated" },
  { pattern = "%s%+%s", label = "used in arithmetic" },
  { pattern = "%s%-%s", label = "used in arithmetic" },
  { pattern = "%s%*%s", label = "used in arithmetic" },
  { pattern = "%s/%s", label = "used in arithmetic" },
}

-- Branching on a masked field does not raise today, but it reads every Secret
-- Value as truthy: the branch then fires on every event instead of only when
-- the real flag is set. Same defect, performance symptom instead of a crash.
local PAYLOAD_FIELD_CONDITION_SUFFIXES = { "then", "and", "or" }

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

local function callHasAnyGuard(lines, lineno, code)
  if not code:find("pcall%s*%(", 1) then
    return false
  end
  local lastLine = math.min(#lines, lineno + 6)
  for index = lineno, lastLine do
    local nearby = stripComment(lines[index])
    if nearby:find("IsSecretValue%s*%(") or nearby:find("issecretvalue%s*%(") then
      return true
    end
  end
  return false
end

local function trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function resolveWatchedApi(target, watchedAliasByName)
  target = trim(target)
  local basename = target:match("([%w_]+)$")
  if basename and WATCHED_API_SET[basename] then
    return basename
  end
  return watchedAliasByName[target] or (basename and watchedAliasByName[basename]) or nil
end

local function registerAliases(code, watchedAliasByName)
  local alias = code:match("^%s*local%s+([%w_]+)%s*=")
  if not alias then
    return
  end

  watchedAliasByName[alias] = nil
  local rhs = code:match("^%s*local%s+[%w_]+%s*=%s*(.+)$") or ""
  local rawgetApi = rhs:match('rawget%(%s*[%w_%.]+%s*,%s*"([%w_]+)"%s*%)')
  if rawgetApi and WATCHED_API_SET[rawgetApi] then
    watchedAliasByName[alias] = rawgetApi
    return
  end

  for _, api in ipairs(WATCHED_APIS) do
    if
      rhs:find("[%.%s%(]" .. api .. "[%s%)]*$")
      or rhs:find("%." .. api .. "[%s%)]")
      or rhs:find("%." .. api .. "%s+or%s+")
      or rhs:find("%s" .. api .. "%s+or%s+")
      or trim(rhs) == api
    then
      watchedAliasByName[alias] = api
      return
    end
  end
end

local function splitAssignedNames(rawNames)
  local names = {}
  for name in tostring(rawNames or ""):gmatch("([^,]+)") do
    names[#names + 1] = trim(name)
  end
  return names
end

local function resultHasOrderedGuard(lines, lineno, variable)
  if variable == "" or variable == "_" then
    return true
  end

  local escaped = variable:gsub("([^%w])", "%%%1")
  local lastLine = math.min(#lines, lineno + 8)
  for index = lineno + 1, lastLine do
    local raw = lines[index]
    if hasInlineOverride(raw) then
      return true
    end
    local code = stripComment(raw)
    local withoutLhs = code:gsub("^%s*" .. escaped .. "%s*=%s*", "", 1)
    local firstUse = withoutLhs:find("%f[%w_]" .. escaped .. "%f[^%w_]")
    if firstUse then
      local secretStart = withoutLhs:find("IsSecretValue%s*%(%s*" .. escaped .. "%s*%)")
        or withoutLhs:find("issecretvalue%s*%(%s*" .. escaped .. "%s*%)")
      if secretStart and secretStart <= firstUse then
        return true
      end
      return false
    end
  end
  return false
end

-- Guards the detector itself, not its call sites. A module that re-implements
-- the `issecretvalue` lookup locally can silently drop the pcall or the
-- type-check that `Validators.IsSecretValue` guarantees -- which is exactly how
-- an unguarded `_G.issecretvalue(value)` once reached the LFG queue path while
-- every call-site rule above stayed green.
local function analyzeDetectorOwnership(path, lines)
  local hits = {}
  if path == CANONICAL_DETECTOR_FILE then
    return hits
  end

  for lineno, raw in ipairs(lines) do
    if not hasInlineOverride(raw) then
      local code = stripComment(raw)
      if code:find("issecretvalue") then
        hits[#hits + 1] = string.format(
          "%s:%d [local-secret-detector]: re-implements the Secret-Value detector; "
            .. "use `addonTable.Validators.IsSecretValue` instead (only %s may read the raw global)",
          path,
          lineno,
          CANONICAL_DETECTOR_FILE
        )
      end
    end
  end
  return hits
end

-- A line is exempt when it routes the field through the central secret-safe
-- readers, or checks it explicitly. `Validators.ReadPlain*` rejects a masked
-- value before returning, so anything it produced is plain by construction.
local function lineHasPayloadGuard(code)
  return code:find("ReadPlain") ~= nil
    or code:find("IsSecretValue%s*%(") ~= nil
    or code:find("issecretvalue%s*%(") ~= nil
end

local function lineReadsPayloadField(code, field)
  if code:find("%." .. field .. "%f[^%w_]") then
    return true
  end
  if code:find('"' .. field .. '"') then
    return true
  end
  return false
end

local function payloadFieldRiskLabel(code, field)
  for _, operation in ipairs(PAYLOAD_FIELD_RISK_OPERATIONS) do
    if code:find(operation.pattern) then
      return operation.label
    end
  end
  for _, suffix in ipairs(PAYLOAD_FIELD_CONDITION_SUFFIXES) do
    if code:find("%." .. field .. "%s+" .. suffix .. "%f[^%w_]") then
      return "branched on"
    end
  end
  if code:find("%[[^%]]*%." .. field .. "%f[^%w_]") or code:find('%[[^%]]*"' .. field .. '"') then
    return "used as a table key"
  end
  return nil
end

-- Second entry channel: a Secret Value that arrives as a FIELD of a
-- Blizzard-supplied table rather than as a watched API return. The call-site
-- rules cannot see it because no watched API name appears on the line.
local function analyzePayloadFields(path, lines)
  local hits = {}
  for lineno, raw in ipairs(lines) do
    local previous = lineno > 1 and lines[lineno - 1] or ""
    if not hasInlineOverride(raw) and not hasInlineOverride(previous) then
      local code = stripComment(raw)
      if not lineHasPayloadGuard(code) then
        for _, field in ipairs(WATCHED_PAYLOAD_FIELDS) do
          if lineReadsPayloadField(code, field) then
            local label = payloadFieldRiskLabel(code, field)
            if label then
              hits[#hits + 1] = string.format(
                "%s:%d [payload field %s]: masked-capable field is %s without a Secret-Value guard; "
                  .. "read it through addonTable.Validators.ReadPlain*",
                path,
                lineno,
                field,
                label
              )
              break
            end
          end
        end
      end
    end
  end
  return hits
end

local function analyzeLines(path, lines)
  local hits = {}
  local watchedAliasByName = {}
  local localWrapperByName = {}
  for lineno, raw in ipairs(lines) do
    local previous = lineno > 1 and lines[lineno - 1] or ""
    local overridden = hasInlineOverride(raw) or hasInlineOverride(previous)
    local code = stripComment(raw)
    registerAliases(code, watchedAliasByName)
    local localFunctionName = code:match("^%s*local%s+function%s+([%w_]+)%s*%(")
    if localFunctionName then
      localWrapperByName[localFunctionName] = true
    end

    if not overridden then
      local assignedNames, pcallTarget = code:match("^%s*local%s+([^=]-)%s*=%s*pcall%s*%(%s*([%w_%.]+)")
      local pcallApi = pcallTarget and resolveWatchedApi(pcallTarget, watchedAliasByName) or nil
      if pcallApi and assignedNames then
        local names = splitAssignedNames(assignedNames)
        for index = 2, #names do
          if not resultHasOrderedGuard(lines, lineno, names[index]) then
            hits[#hits + 1] = string.format(
              "%s:%d [%s result %s]: pcall result is used before the same value is rejected as secret",
              path,
              lineno,
              pcallApi,
              names[index]
            )
          end
        end
      end

      for _, api in ipairs(WATCHED_APIS) do
        local pattern = "[^%w_]" .. api .. "%s*%("
        local startsBare = (code:sub(1, #api + 1) .. " "):find("^" .. api .. "%s*%(") ~= nil
          or code:find("^%s*" .. api .. "%s*%(") ~= nil
        local hasAnyCall = startsBare or code:find(pattern)
        local isBareLocalWrapper = localWrapperByName[api] and code:find("[%.:]" .. api .. "%s*%(") == nil
        if hasAnyCall and not isBareLocalWrapper then
          if not lineIsDefinitionFor(code, api) and not callHasAnyGuard(lines, lineno, code) then
            hits[#hits + 1] = string.format(
              "%s:%d [%s]: direct call without both pcall and a Secret-Value rejection",
              path,
              lineno,
              api
            )
            break
          end
        end
      end

      for alias, api in pairs(watchedAliasByName) do
        local aliasCall = "[^%w_]" .. alias .. "%s*%("
        local startsWithAlias = code:find("^%s*" .. alias .. "%s*%(") ~= nil
        local pcallWithAlias = code:find("pcall%s*%(%s*" .. alias .. "[%s,%)]") ~= nil
        if
          (startsWithAlias or code:find(aliasCall) or pcallWithAlias)
          and not code:find("function%s+" .. alias .. "%s*%(")
          and not assignedNames
        then
          if not callHasAnyGuard(lines, lineno, code) then
            hits[#hits + 1] = string.format(
              "%s:%d [%s via %s]: aliased call without both pcall and a Secret-Value rejection",
              path,
              lineno,
              api,
              alias
            )
          end
          break
        end
      end
    end
  end
  return hits
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
    local fileHits = analyzeLines(path, lines)
    for _, hit in ipairs(fileHits) do
      hits[#hits + 1] = hit
    end
    local detectorHits = analyzeDetectorOwnership(path, lines)
    for _, hit in ipairs(detectorHits) do
      hits[#hits + 1] = hit
    end
    local payloadHits = analyzePayloadFields(path, lines)
    for _, hit in ipairs(payloadHits) do
      hits[#hits + 1] = hit
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

if ... == "test" then
  return {
    AnalyzeLines = analyzeLines,
    AnalyzePayloadFields = analyzePayloadFields,
  }
end

main()
