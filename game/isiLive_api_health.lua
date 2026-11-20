local _, addonTable = ...

addonTable = addonTable or {}

-- Patch-day self test (`/isilive selftest`, rule 251). Many isiLive features
-- fail closed and silently when Blizzard renames, removes or masks an API
-- (TTK, nameplate forces, damage meter, LFG detection). This report lists,
-- per feature, whether the Blizzard APIs it reads still exist, so a patch
-- shows at once which feature went dark. It only reads: no API is called
-- except the side-effect-free probes below, each under pcall.
local ApiHealth = {}
addonTable.ApiHealth = ApiHealth

local IsSecretValue = addonTable.Validators.IsSecretValue

-- { feature, root, function [, { altRoot, altFunction }] }. `root = nil` names
-- a global function. The optional fourth entry is the fallback the runtime
-- uses when the first API is missing; the check passes when either exists. The list
-- covers the Blizzard surfaces docs/WARTUNG.md section 3 names as the first to
-- break after a patch; extend it with every new API surface a feature needs.
ApiHealth.CHECKS = {
  { "Instance", nil, "GetInstanceInfo" },
  { "Instance", "C_Map", "GetBestMapForUnit" },
  { "M+ key", "C_ChallengeMode", "GetActiveChallengeMapID" },
  { "M+ key", "C_ChallengeMode", "GetActiveKeystoneInfo" },
  { "M+ key", "C_ChallengeMode", "GetMapUIInfo" },
  { "M+ key", "C_ChallengeMode", "GetDeathCount" },
  { "M+ key", "C_ChallengeMode", "GetChallengeCompletionInfo" },
  { "Season", "C_ChallengeMode", "GetMapTable" },
  { "Season", "C_MythicPlus", "RequestMapInfo" },
  { "Item level colours", "C_MythicPlus", "GetRewardLevelFromKeystoneLevel" },
  { "LFG personal best", "C_MythicPlus", "GetSeasonBestForMap" },
  { "Rating", "C_PlayerInfo", "GetPlayerMythicPlusRatingSummary" },
  { "Killtracker", "C_ScenarioInfo", "GetScenarioStepInfo" },
  { "Killtracker", "C_ScenarioInfo", "GetCriteriaInfo" },
  { "DPS / kicks", "C_DamageMeter", "GetCombatSessionFromType" },
  { "TTK", "C_CurveUtil", "CreateCurve" },
  { "TTK", nil, "UnitHealthPercent" },
  { "Nameplates", "C_NamePlate", "GetNamePlateForUnit" },
  { "LFG", "C_LFGList", "GetActivityInfoTable" },
  { "LFG", "C_LFGList", "GetActiveEntryInfo" },
  { "LFG", "C_LFGList", "GetSearchResultInfo" },
  { "Sync", "C_ChatInfo", "SendAddonMessage" },
  { "Sync", "C_ChatInfo", "RegisterAddonMessagePrefix" },
  { "Sync", "C_ChatInfo", "InChatMessagingLockdown" },
  { "Cooldowns", "C_Spell", "GetSpellCooldown" },
  { "Cooldowns", "C_Spell", "GetSpellName" },
  { "Auras", "C_UnitAuras", "GetAuraDataByIndex" },
  { "Auras", "C_UnitAuras", "GetPlayerAuraBySpellID" },
  { "Keystone link", "C_Container", "GetContainerItemLink" },
  -- The runtime reads C_Item.GetAverageItemLevel and falls back to the global
  -- (logic/isiLive_keysync.lua); 12.1 ships only the global (selftest 2026-11-20).
  { "Item level", "C_Item", "GetAverageItemLevel", { nil, "GetAverageItemLevel" } },
  { "Inspect", "C_PaperDollInfo", "GetInspectItemLevel" },
  { "Invite navigation", "C_EncounterJournal", "GetDungeonEntrancesForMap" },
  { "Timers", "C_Timer", "After" },
  { "Secret values", nil, "issecretvalue" }, -- secret-value-ok: presence check only, never called
  { "Events", "C_EventUtils", "IsEventValid" },
}

-- Rule 258: every event registration that EventUtils refused this session
-- (removed or renamed by a patch) becomes a MISSING row of feature "Events".
local MAX_EVENT_REASON_LENGTH = 80

local function AppendEventRegistrationRows(rows, counts)
  local eventUtils = addonTable.EventUtils
  if type(eventUtils) ~= "table" or type(eventUtils.GetRegistrationFailures) ~= "function" then
    return
  end
  for _, failure in ipairs(eventUtils.GetRegistrationFailures()) do
    local reason = tostring(failure.reason or "")
    if #reason > MAX_EVENT_REASON_LENGTH then
      reason = reason:sub(1, MAX_EVENT_REASON_LENGTH) .. "..."
    end
    counts.missing = counts.missing + 1
    rows[#rows + 1] = {
      feature = "Events",
      name = "event " .. tostring(failure.event),
      status = "missing",
      detail = reason ~= "" and reason or nil,
    }
  end
end

local function ResolveFunction(rootName, fnName)
  if rootName == nil then
    return rawget(_G, fnName)
  end
  local root = rawget(_G, rootName)
  if type(root) ~= "table" then
    return nil
  end
  return rawget(root, fnName)
end

local function QualifiedName(rootName, fnName)
  return rootName and (rootName .. "." .. fnName) or fnName
end

-- Side-effect-free live probes: they show that a present API still answers
-- the way isiLive reads it.
local function ProbeMapTable()
  local fn = ResolveFunction("C_ChallengeMode", "GetMapTable")
  local ok, maps = pcall(fn)
  if not ok then
    return false, "error"
  end
  if IsSecretValue(maps) or type(maps) ~= "table" then
    return false, "no table"
  end
  return true, string.format("%d maps", #maps)
end

local function ProbeCurve()
  local fn = ResolveFunction("C_CurveUtil", "CreateCurve")
  local ok, curve = pcall(fn)
  if not ok then
    return false, "error"
  end
  -- The curve is userdata in the client; only nil means failure.
  if curve == nil then
    return false, "no curve"
  end
  return true, "curve created"
end

local PROBES = {
  ["C_ChallengeMode.GetMapTable"] = ProbeMapTable,
  ["C_CurveUtil.CreateCurve"] = ProbeCurve,
}

--- Runs every check. Returns the result rows and the counts.
-- Row: { feature, name, status = "ok" | "missing" | "error", detail }.
function ApiHealth.Run()
  local rows = {}
  local counts = { ok = 0, missing = 0, error = 0 }
  for _, check in ipairs(ApiHealth.CHECKS) do
    local feature, rootName, fnName = check[1], check[2], check[3]
    local name = QualifiedName(rootName, fnName)
    local status, detail = "ok", nil
    local fallback = check[4]
    if type(ResolveFunction(rootName, fnName)) ~= "function" then
      local altName = type(fallback) == "table" and fallback[2] or nil
      if altName and type(ResolveFunction(fallback[1], altName)) == "function" then
        detail = "via " .. QualifiedName(fallback[1], altName)
      else
        status = "missing"
      end
    else
      local probe = PROBES[name]
      if probe then
        local probeOk, probeDetail = probe()
        status = probeOk and "ok" or "error"
        detail = probeDetail
      end
    end
    counts[status] = counts[status] + 1
    rows[#rows + 1] = { feature = feature, name = name, status = status, detail = detail }
  end
  AppendEventRegistrationRows(rows, counts)
  return rows, counts
end

-- Data checks (rule 261): the Blizzard IDs isiLive ships in data/ must still
-- resolve in this client. On the PTR this is the data check of a prepared
-- season in one command; after a patch it shows an ID Blizzard removed. Each
-- check only reads static client data under pcall; a check whose API is
-- missing is skipped (the API row above already reports it).
local function ReadPlainString(value)
  if IsSecretValue(value) or type(value) ~= "string" or value == "" then
    return nil
  end
  return value
end

local function ReadPlainNumber(value)
  if IsSecretValue(value) or type(value) ~= "number" then
    return nil
  end
  return value
end

local function SpellNameReader()
  local fn = ResolveFunction("C_Spell", "GetSpellName")
  if type(fn) ~= "function" then
    return nil
  end
  return function(spellID)
    local ok, name = pcall(fn, spellID)
    return ok and ReadPlainString(name) or nil
  end
end

local function AddDataRow(rows, counts, feature, name, status, detail)
  counts[status] = counts[status] + 1
  rows[#rows + 1] = { feature = feature, name = name, status = status, detail = detail }
end

local function CheckSpellList(rows, counts, readSpell, feature, label, ids)
  for _, spellID in ipairs(ids) do
    local name = readSpell(spellID)
    AddDataRow(rows, counts, feature, string.format("%s %d", label, spellID), name and "ok" or "missing", name)
  end
end

local function CollectSpellManifestIDs()
  local manifest = addonTable.SpellManifest
  local ids = {}
  if type(manifest) ~= "table" then
    return ids
  end
  local seen = {}
  local function Add(id)
    if type(id) == "number" and not seen[id] then
      seen[id] = true
      ids[#ids + 1] = id
    end
  end
  for _, listName in ipairs({ "battleRes", "lustCasts", "lustSated" }) do
    for _, record in ipairs(type(manifest[listName]) == "table" and manifest[listName] or {}) do
      Add(type(record) == "table" and record.id or nil)
    end
  end
  for _, iconID in pairs(type(manifest.icons) == "table" and manifest.icons or {}) do
    Add(iconID)
  end
  Add(manifest.powerInfusion)
  table.sort(ids)
  return ids
end

local function CollectConsumableIDs(seasonID)
  local consumables = addonTable.ConsumableData
  local set = type(consumables) == "table"
      and type(consumables.ResolveSet) == "function"
      and consumables.ResolveSet(seasonID)
    or nil
  local ids = {}
  if type(set) ~= "table" then
    return ids
  end
  for _, category in ipairs({ "food", "flask", "augmentRune" }) do
    for _, id in ipairs(type(set[category]) == "table" and set[category] or {}) do
      if type(id) == "number" then
        ids[#ids + 1] = id
      end
    end
  end
  return ids
end

local function SortedNumericKeys(map)
  local keys = {}
  for key in pairs(type(map) == "table" and map or {}) do
    if type(key) == "number" then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys)
  return keys
end

-- Portal spells, challenge maps and LFG activities of the served season.
local function CheckSeasonData(rows, counts, readSpell)
  local seasonData = addonTable.SeasonData
  if type(seasonData) ~= "table" or type(seasonData.GetSeasonConfig) ~= "function" then
    return
  end
  local season = seasonData.GetSeasonConfig()
  if type(season) ~= "table" then
    AddDataRow(rows, counts, "Season data", "served season", "error", "none (unrecognized map set, rule 259)")
    return
  end
  local mapToTeleport = type(season.mapToTeleport) == "table" and season.mapToTeleport or {}
  local mapUIInfo = ResolveFunction("C_ChallengeMode", "GetMapUIInfo")
  for _, mapID in ipairs(SortedNumericKeys(mapToTeleport)) do
    if type(mapUIInfo) == "function" then
      local ok, name = pcall(mapUIInfo, mapID)
      local mapName = ok and ReadPlainString(name) or nil
      AddDataRow(rows, counts, "Season data", "challenge map " .. mapID, mapName and "ok" or "missing", mapName)
    end
    if readSpell then
      local spells = mapToTeleport[mapID]
      CheckSpellList(rows, counts, readSpell, "Season data", "portal spell", type(spells) == "table" and spells or {
        spells,
      })
    end
  end

  local activityInfo = ResolveFunction("C_LFGList", "GetActivityInfoTable")
  local validators = addonTable.Validators
  if type(activityInfo) ~= "function" then
    return
  end
  local activityToMap = type(season.activityToMap) == "table" and season.activityToMap or {}
  for _, activityID in ipairs(SortedNumericKeys(activityToMap)) do
    local mapID = activityToMap[activityID]
    local ok, info = pcall(activityInfo, activityID)
    local name = "LFG activity " .. activityID
    if not ok or type(info) ~= "table" then
      AddDataRow(rows, counts, "Season data", name, "missing", "map " .. tostring(mapID))
    else
      local instanceID = ReadPlainNumber(info.mapID)
      local expected = type(validators) == "table"
          and type(validators.ResolveChallengeMapInstanceID) == "function"
          and validators.ResolveChallengeMapInstanceID(mapID)
        or nil
      if instanceID and expected and instanceID ~= expected then
        AddDataRow(
          rows,
          counts,
          "Season data",
          name,
          "error",
          string.format("instance %d, map %d is instance %d", instanceID, mapID, expected)
        )
      else
        AddDataRow(rows, counts, "Season data", name, "ok", ReadPlainString(info.fullName))
      end
    end
  end
end

local function CollectKickSpellIDs()
  local kickTracker = addonTable.KickTracker
  if type(kickTracker) ~= "table" or type(kickTracker.GetInterruptSpellIDs) ~= "function" then
    return {}
  end
  return kickTracker.GetInterruptSpellIDs()
end

-- Every specialization the client knows must have a record in
-- data/isiLive_specs.lua (package 5 O): a new spec of an expansion or patch
-- (Devourer came with Midnight) otherwise has no interrupt data, no LFG bonus
-- profile and no roster label. Reads only static class data.
local function CheckClientSpecs(rows, counts)
  local manifest = addonTable.SpecManifest
  local numClasses = ResolveFunction(nil, "GetNumClasses")
  local numSpecs = ResolveFunction(nil, "GetNumSpecializationsForClassID")
  local specInfo = ResolveFunction(nil, "GetSpecializationInfoForClassID")
  if
    type(manifest) ~= "table"
    or type(manifest.specs) ~= "table"
    or type(numClasses) ~= "function"
    or type(numSpecs) ~= "function"
    or type(specInfo) ~= "function"
  then
    return
  end
  local okClasses, classCount = pcall(numClasses)
  classCount = okClasses and ReadPlainNumber(classCount) or nil
  for classID = 1, classCount or 0 do
    local okCount, specCount = pcall(numSpecs, classID)
    specCount = okCount and ReadPlainNumber(specCount) or 0
    for specIndex = 1, specCount do
      local okSpec, specID, specName = pcall(specInfo, classID, specIndex)
      specID = okSpec and ReadPlainNumber(specID) or nil
      if specID then
        local name = string.format("spec %d", specID)
        if manifest.specs[specID] ~= nil then
          AddDataRow(rows, counts, "Specs", name, "ok", ReadPlainString(specName))
        else
          local label = ReadPlainString(specName) or "unknown name"
          AddDataRow(rows, counts, "Specs", name, "missing", label .. " not in data/isiLive_specs.lua")
        end
      end
    end
  end
end

-- Item IDs from data/isiLive_items.lua through C_Item.GetItemInfoInstant,
-- which answers from static client data without an item request.
local function CheckItems(rows, counts)
  local manifest = addonTable.ItemManifest
  local itemInfo = ResolveFunction("C_Item", "GetItemInfoInstant")
  if type(manifest) ~= "table" or type(itemInfo) ~= "function" then
    return
  end
  local keys = {}
  for key in pairs(manifest) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local itemID = manifest[key]
    if type(itemID) == "number" then
      local ok, resolvedID = pcall(itemInfo, itemID)
      local found = ok and ReadPlainNumber(resolvedID) == itemID
      AddDataRow(rows, counts, "Items", string.format("item %d", itemID), found and "ok" or "missing", key)
    end
  end
end

--- Runs every data check. Returns the rows and counts like ApiHealth.Run.
function ApiHealth.RunDataChecks()
  local rows = {}
  local counts = { ok = 0, missing = 0, error = 0 }
  local readSpell = SpellNameReader()
  CheckSeasonData(rows, counts, readSpell)
  if readSpell then
    CheckSpellList(rows, counts, readSpell, "Spells", "spell", CollectSpellManifestIDs())
    local seasonData = addonTable.SeasonData
    local seasonID = type(seasonData) == "table"
        and type(seasonData.GetActiveSeasonID) == "function"
        and seasonData.GetActiveSeasonID()
      or nil
    CheckSpellList(rows, counts, readSpell, "Consumables", "buff", CollectConsumableIDs(seasonID))
    CheckSpellList(rows, counts, readSpell, "Kicks", "interrupt spell", CollectKickSpellIDs())
  end
  CheckItems(rows, counts)
  CheckClientSpecs(rows, counts)
  return rows, counts
end

local STATUS_TEXT = { ok = "ok", missing = "MISSING", error = "ERROR" }

local function AppendRowLines(lines, rows, verbose)
  for _, wanted in ipairs({ "missing", "error", "ok" }) do
    if wanted ~= "ok" or verbose then
      for _, row in ipairs(rows) do
        if row.status == wanted then
          local detail = row.detail and (" (" .. row.detail .. ")") or ""
          lines[#lines + 1] =
            string.format("[SELFTEST] %s %s - %s%s", STATUS_TEXT[row.status], row.name, row.feature, detail)
        end
      end
    end
  end
end

--- Report lines: failures first (they are what a patch day needs), then a
-- summary line; the data checks follow with a summary of their own when any
-- data is loaded. `verbose = true` also lists every passing check.
-- Returns lines, API counts, data counts.
function ApiHealth.BuildReportLines(verbose)
  local rows, counts = ApiHealth.Run()
  local lines = {}
  AppendRowLines(lines, rows, verbose)
  lines[#lines + 1] = string.format(
    "[SELFTEST] %d ok, %d missing, %d error of %d Blizzard APIs",
    counts.ok,
    counts.missing,
    counts.error,
    #rows
  )
  local dataRows, dataCounts = ApiHealth.RunDataChecks()
  if #dataRows > 0 then
    AppendRowLines(lines, dataRows, verbose)
    lines[#lines + 1] = string.format(
      "[SELFTEST] %d ok, %d missing, %d error of %d data IDs",
      dataCounts.ok,
      dataCounts.missing,
      dataCounts.error,
      #dataRows
    )
  end
  return lines, counts, dataCounts
end

function ApiHealth.PrintReport(printFn, verbose)
  printFn = type(printFn) == "function" and printFn or print
  local lines = ApiHealth.BuildReportLines(verbose)
  for _, line in ipairs(lines) do
    printFn(line)
  end
end

-- Patch watch (rule 261): once per client build, shortly after login, the
-- self test runs silently and writes one chat line only when something
-- failed. The checked build is stored in IsiLiveDB.selftestBuild.
ApiHealth.PATCH_WATCH_DELAY_SECONDS = 20

local function ReadClientBuild()
  local getBuildInfo = rawget(_G, "GetBuildInfo")
  if type(getBuildInfo) ~= "function" then
    return nil
  end
  -- GetBuildInfo returns version, build, date, tocVersion; the build number
  -- (second value) changes with every client update, hotfix builds included.
  local ok, build = pcall(function()
    return select(2, getBuildInfo())
  end)
  if not ok then
    return nil
  end
  return ReadPlainString(build) or (ReadPlainNumber(build) and tostring(build)) or nil
end

local function DefaultAfter(delay, fn)
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    timer.After(delay, fn)
    return
  end
  fn()
end

--- Creates the login hook.
-- @param deps table { getDB, getL, printFn, after?, getBuild? }
-- @return table { OnLogin, CheckNow }
function ApiHealth.CreatePatchWatch(deps)
  deps = type(deps) == "table" and deps or {}
  local after = type(deps.after) == "function" and deps.after or DefaultAfter
  local getBuild = type(deps.getBuild) == "function" and deps.getBuild or ReadClientBuild
  local scheduled = false
  local controller = {}

  --- Runs the check when the build changed. Returns the number of failures,
  -- or nil when nothing ran (same build, no build or no database).
  function controller.CheckNow()
    local db = type(deps.getDB) == "function" and deps.getDB() or nil
    local build = getBuild()
    if type(db) ~= "table" or type(build) ~= "string" or db.selftestBuild == build then
      return nil
    end
    local _, counts, dataCounts = ApiHealth.BuildReportLines(false)
    db.selftestBuild = build
    local failures = counts.missing + counts.error
    if type(dataCounts) == "table" then
      failures = failures + dataCounts.missing + dataCounts.error
    end
    if failures > 0 and type(deps.printFn) == "function" then
      local L = type(deps.getL) == "function" and deps.getL() or nil
      local template = type(L) == "table" and L.SELFTEST_PATCH_NOTICE or nil
      if type(template) ~= "string" or template == "" then
        template = "Self test after the client update (build %s) found %d problem(s). " .. "Details: /isilive selftest"
      end
      deps.printFn("|cffffd200" .. string.format(template, build, failures) .. "|r")
    end
    return failures
  end

  --- PLAYER_LOGIN: schedules the check once per session.
  function controller.OnLogin()
    if scheduled then
      return
    end
    scheduled = true
    after(ApiHealth.PATCH_WATCH_DELAY_SECONDS, controller.CheckNow)
  end

  return controller
end
