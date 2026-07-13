#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Emits a markdown readiness report for the configured season datasets.
--
-- This tool does not fetch external data and does not infer missing runtime
-- values. It only reports what is already persisted in the repository.

local DEFAULT_LANGUAGE_PATH = "locale/isiLive_languages.lua"
local DEFAULT_SEASON_DATA_PATH = "game/isiLive_season_data.lua"
local DEFAULT_FORCES_PATH = "data/isiLive_mplus_forces.lua"

local function LoadAddonFile(path, addonTable)
  local loader, loadErr = loadfile(path)
  if not loader then
    return false, string.format("cannot load %s: %s", tostring(path), tostring(loadErr))
  end

  local ok, err = pcall(loader, "isiLive", addonTable)
  if not ok then
    return false, string.format("load error in %s: %s", tostring(path), tostring(err))
  end

  return true
end

local function SortedKeys(value)
  local out = {}
  if type(value) ~= "table" then
    return out
  end
  for key in pairs(value) do
    out[#out + 1] = key
  end
  table.sort(out, function(a, b)
    return tostring(a) < tostring(b)
  end)
  return out
end

local function CountEntries(value)
  if type(value) ~= "table" then
    return 0
  end

  local count = 0
  for _ in pairs(value) do
    count = count + 1
  end
  return count
end

local function AppendList(lines, label, values)
  if type(values) ~= "table" or #values == 0 then
    lines[#lines + 1] = string.format("- %s: unresolved", label)
    return
  end

  lines[#lines + 1] = string.format("- %s:", label)
  for _, value in ipairs(values) do
    lines[#lines + 1] = string.format("  - %s", tostring(value))
  end
end

local M = {}

function M.BuildSummary(opts)
  opts = opts or {}

  local addonTable = {}
  local lines = {
    "## isiLive Season Readiness",
    "",
  }

  local ok, err = LoadAddonFile(opts.languagePath or DEFAULT_LANGUAGE_PATH, addonTable)
  if not ok then
    lines[#lines + 1] = "- Status: unresolved"
    lines[#lines + 1] = "- Reason: " .. err
    return table.concat(lines, "\n") .. "\n"
  end

  ok, err = LoadAddonFile(opts.seasonDataPath or DEFAULT_SEASON_DATA_PATH, addonTable)
  if not ok then
    lines[#lines + 1] = "- Status: unresolved"
    lines[#lines + 1] = "- Reason: " .. err
    return table.concat(lines, "\n") .. "\n"
  end

  local seasonData = addonTable.SeasonData
  if type(seasonData) ~= "table" then
    lines[#lines + 1] = "- Status: unresolved"
    lines[#lines + 1] = "- Reason: addonTable.SeasonData missing"
    return table.concat(lines, "\n") .. "\n"
  end

  local forcesPath = opts.forcesPath or DEFAULT_FORCES_PATH
  local forcesOk, forcesErr = LoadAddonFile(forcesPath, addonTable)

  lines[#lines + 1] = "- Active season: " .. tostring(seasonData.ACTIVE_SEASON_ID or "unresolved")
  lines[#lines + 1] = ""
  lines[#lines + 1] = "| Season | Label | Ready | Mapped dungeons | Aliases | Errors | Warnings |"
  lines[#lines + 1] = "| --- | --- | --- | ---: | ---: | --- | --- |"

  local seasonIDs = SortedKeys(seasonData.SEASONS)
  for _, seasonID in ipairs(seasonIDs) do
    local readiness = seasonData.GetSeasonReadiness(seasonID)
    local errors = type(readiness.errors) == "table" and table.concat(readiness.errors, "<br>") or ""
    local warnings = type(readiness.warnings) == "table" and table.concat(readiness.warnings, "<br>") or ""
    if errors == "" then
      errors = "-"
    end
    if warnings == "" then
      warnings = "-"
    end
    lines[#lines + 1] = string.format(
      "| %s | %s | %s | %d | %d | %s | %s |",
      tostring(seasonID),
      tostring(readiness.label or ""),
      readiness.isReady and "yes" or "no",
      tonumber(readiness.mappedDungeonCount) or 0,
      tonumber(readiness.aliasCount) or 0,
      errors,
      warnings
    )
  end

  for _, seasonID in ipairs(seasonIDs) do
    local season = seasonData.SEASONS[seasonID]
    lines[#lines + 1] = ""
    lines[#lines + 1] = "### " .. tostring(seasonID)
    AppendList(lines, "planned dungeons", type(season) == "table" and season.plannedDungeons or nil)
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "### M+ Forces DB"
  if not forcesOk then
    lines[#lines + 1] = "- Status: unresolved"
    lines[#lines + 1] = "- Reason: " .. forcesErr
  else
    local forces = addonTable.MPlusForces
    if type(forces) ~= "table" then
      lines[#lines + 1] = "- Status: unresolved"
      lines[#lines + 1] = "- Reason: addonTable.MPlusForces missing"
    else
      lines[#lines + 1] = "- Season: " .. tostring(forces.season or "unresolved")
      lines[#lines + 1] = "- MDT version: " .. tostring(forces.mdtVersion or "unresolved")
      lines[#lines + 1] = "- Generated at: " .. tostring(forces.generatedAt or "unresolved")
      lines[#lines + 1] = "- Expires at: " .. tostring(forces.expiresAt or "unresolved")
      lines[#lines + 1] = "- Dungeon count: " .. tostring(forces.dungeonCount or CountEntries(forces.dungeonTotal))
      lines[#lines + 1] = "- NPC count: " .. tostring(forces.npcCount or CountEntries(forces.byNpcId))
      lines[#lines + 1] = "- Matches active season: "
        .. ((forces.season == seasonData.ACTIVE_SEASON_ID) and "yes" or "no")
    end
  end

  return table.concat(lines, "\n") .. "\n"
end

local cliArg = rawget(_G, "arg")
local isDirectRun = type(cliArg) == "table"
  and type(cliArg[0]) == "string"
  and cliArg[0]:find("inspect_season_readiness.lua", 1, true) ~= nil

if isDirectRun then
  io.write(M.BuildSummary())
end

return M
