#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Validates docs/SEASON_INTAKE.md as the pre-activation collection surface for
-- upcoming season data. Unresolved values are allowed; guessed or source-less
-- concrete IDs are not.

local DEFAULT_INTAKE_PATH = "docs/SEASON_INTAKE.md"
local DEFAULT_LANGUAGE_PATH = "locale/isiLive_languages.lua"
local DEFAULT_SEASON_DATA_PATH = "game/isiLive_season_data.lua"
local DEFAULT_TARGET_SEASON = "midnight_s2"

local STATUS_VALUES = {
  unresolved = true,
  candidate = true,
  partial = true,
  verified = true,
}

local function Trim(value)
  return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ReadFile(path)
  local file, err = io.open(path, "rb")
  if not file then
    return nil, string.format("cannot read %s: %s", tostring(path), tostring(err))
  end
  local content = file:read("*a") or ""
  file:close()
  return content
end

local function SplitMarkdownRow(line)
  local trimmed = Trim(line)
  if not trimmed:match("^|") then
    return nil
  end
  trimmed = trimmed:gsub("^|", ""):gsub("|$", "")
  local cells = {}
  for cell in trimmed:gmatch("([^|]*)") do
    cells[#cells + 1] = Trim(cell)
  end
  return cells
end

local function IsSeparatorRow(cells)
  if type(cells) ~= "table" or #cells == 0 then
    return false
  end
  for _, cell in ipairs(cells) do
    if not cell:match("^:?-+:?$") then
      return false
    end
  end
  return true
end

local function ParseTables(content)
  local sections = {
    dungeons = {},
    hearthstones = {},
    mounts = {},
  }
  local current
  local header

  for line in tostring(content or ""):gmatch("[^\r\n]+") do
    if line:find("^## Dungeon%-Intake") then
      current = "dungeons"
      header = nil
    elseif line:find("^## Ruhestein%-Intake") then
      current = "hearthstones"
      header = nil
    elseif line:find("^## Mount%-Intake") then
      current = "mounts"
      header = nil
    elseif line:find("^## ") then
      current = nil
      header = nil
    elseif current then
      local cells = SplitMarkdownRow(line)
      if cells then
        if not header then
          header = cells
        elseif not IsSeparatorRow(cells) then
          local row = {}
          for index, column in ipairs(header) do
            row[column] = cells[index] or ""
          end
          sections[current][#sections[current] + 1] = row
        end
      end
    end
  end

  return sections
end

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

local function LoadSeasonData(opts)
  local addonTable = {}
  local ok, err = LoadAddonFile(opts.languagePath or DEFAULT_LANGUAGE_PATH, addonTable)
  if not ok then
    return nil, err
  end
  ok, err = LoadAddonFile(opts.seasonDataPath or DEFAULT_SEASON_DATA_PATH, addonTable)
  if not ok then
    return nil, err
  end
  if type(addonTable.SeasonData) ~= "table" then
    return nil, "addonTable.SeasonData missing"
  end
  return addonTable.SeasonData
end

local function IsUnresolved(value)
  return Trim(value) == "unresolved"
end

local function IsPositiveInteger(value)
  return tostring(value or ""):match("^[1-9]%d*$") ~= nil
end

local function IsDate(value)
  return tostring(value or ""):match("^%d%d%d%d%-%d%d%-%d%d$") ~= nil
end

local function AddError(errors, message)
  errors[#errors + 1] = message
end

local function ValidateSourceAndDate(errors, label, row)
  if IsUnresolved(row.Source) then
    AddError(errors, label .. " has concrete or candidate data without Source")
  end
  if not IsDate(row.VerifiedAt) then
    AddError(errors, label .. " has concrete or candidate data without YYYY-MM-DD VerifiedAt")
  end
end

local function ValidateRow(errors, label, row, idFields)
  local status = Trim(row.Status)
  if not STATUS_VALUES[status] then
    AddError(errors, label .. " has invalid Status '" .. tostring(row.Status) .. "'")
    return
  end

  local numericCount = 0
  local unresolvedCount = 0
  for _, field in ipairs(idFields) do
    local value = row[field]
    if IsUnresolved(value) then
      unresolvedCount = unresolvedCount + 1
    elseif IsPositiveInteger(value) then
      numericCount = numericCount + 1
    else
      AddError(errors, label .. " has non-numeric " .. field .. " '" .. tostring(value) .. "'")
    end
  end

  if status == "unresolved" then
    if numericCount > 0 then
      AddError(errors, label .. " is unresolved but already contains numeric data")
    end
    if not IsUnresolved(row.Source) or not IsUnresolved(row.VerifiedAt) then
      AddError(errors, label .. " is unresolved but Source/VerifiedAt is already set")
    end
  elseif status == "verified" then
    if unresolvedCount > 0 then
      AddError(errors, label .. " is verified but still has unresolved IDs")
    end
    ValidateSourceAndDate(errors, label, row)
  elseif status == "partial" then
    if numericCount == 0 or unresolvedCount == 0 then
      AddError(errors, label .. " is partial but does not contain both numeric and unresolved IDs")
    end
    ValidateSourceAndDate(errors, label, row)
  elseif status == "candidate" then
    ValidateSourceAndDate(errors, label, row)
  end
end

local function RegisterUnique(errors, seen, kind, value, label)
  if IsUnresolved(value) then
    return
  end
  if seen[value] then
    AddError(errors, string.format("%s %s is duplicated between %s and %s", kind, value, seen[value], label))
    return
  end
  seen[value] = label
end

local function BuildPlannedDungeonSet(seasonData, seasonID)
  local season = seasonData.SEASONS and seasonData.SEASONS[seasonID] or nil
  local set = {}
  local ordered = {}
  if type(season) == "table" and type(season.plannedDungeons) == "table" then
    for _, name in ipairs(season.plannedDungeons) do
      set[name] = true
      ordered[#ordered + 1] = name
    end
  end
  return set, ordered
end

local function CountStatuses(rows)
  local counts = {
    unresolved = 0,
    candidate = 0,
    partial = 0,
    verified = 0,
  }
  for _, row in ipairs(rows) do
    local status = Trim(row.Status)
    if counts[status] ~= nil then
      counts[status] = counts[status] + 1
    end
  end
  return counts
end

local M = {}

function M.Check(opts)
  opts = opts or {}
  local targetSeason = opts.seasonID or DEFAULT_TARGET_SEASON
  local content, readErr = ReadFile(opts.intakePath or DEFAULT_INTAKE_PATH)
  local errors = {}
  if not content then
    return false,
      {
        seasonID = targetSeason,
        errors = { readErr },
        summary = "## Season Intake Check\n\n- Status: invalid\n- Reason: " .. tostring(readErr) .. "\n",
      }
  end

  local seasonData, seasonErr = LoadSeasonData(opts)
  if not seasonData then
    return false,
      {
        seasonID = targetSeason,
        errors = { seasonErr },
        summary = "## Season Intake Check\n\n- Status: invalid\n- Reason: " .. tostring(seasonErr) .. "\n",
      }
  end

  local tables = ParseTables(content)
  local plannedSet, plannedOrder = BuildPlannedDungeonSet(seasonData, targetSeason)
  if #plannedOrder == 0 then
    AddError(errors, "target season " .. targetSeason .. " has no plannedDungeons in SeasonData")
  end

  local dungeonRowsByName = {}
  local seenChallenge = {}
  local seenPortal = {}
  local seenLfg = {}
  local seenToy = {}
  local seenMount = {}

  for _, row in ipairs(tables.dungeons) do
    local label = string.format("dungeon row %s/%s", tostring(row.Season), tostring(row.Dungeon))
    if row.Season == targetSeason then
      if not plannedSet[row.Dungeon] then
        AddError(errors, label .. " is not listed in SeasonData.plannedDungeons")
      elseif dungeonRowsByName[row.Dungeon] then
        AddError(errors, "duplicate dungeon intake row for " .. row.Dungeon)
      else
        dungeonRowsByName[row.Dungeon] = row
      end
      ValidateRow(errors, label, row, { "ChallengeMapID", "PortalSpellID", "LFGActivityID" })
      RegisterUnique(errors, seenChallenge, "ChallengeMapID", row.ChallengeMapID, label)
      RegisterUnique(errors, seenPortal, "PortalSpellID", row.PortalSpellID, label)
      RegisterUnique(errors, seenLfg, "LFGActivityID", row.LFGActivityID, label)
    end
  end

  for _, name in ipairs(plannedOrder) do
    if not dungeonRowsByName[name] then
      AddError(errors, "missing dungeon intake row for planned dungeon " .. name)
    end
  end

  for _, row in ipairs(tables.hearthstones) do
    if row.Season == targetSeason then
      local label = string.format("hearthstone row %s/%s", tostring(row.Season), tostring(row.Name))
      ValidateRow(errors, label, row, { "ToyID" })
      RegisterUnique(errors, seenToy, "ToyID", row.ToyID, label)
    end
  end

  for _, row in ipairs(tables.mounts) do
    if row.Season == targetSeason then
      local label = string.format("mount row %s/%s", tostring(row.Season), tostring(row.Name))
      ValidateRow(errors, label, row, { "SpellID" })
      RegisterUnique(errors, seenMount, "SpellID", row.SpellID, label)
    end
  end

  local counts = CountStatuses(tables.dungeons)
  local lines = {
    "## Season Intake Check",
    "",
    "- Season: " .. targetSeason,
    "- Status: " .. (#errors == 0 and "valid" or "invalid"),
    string.format(
      "- Dungeon progress: %d/%d verified, %d partial, %d candidate, %d unresolved",
      counts.verified,
      #plannedOrder,
      counts.partial,
      counts.candidate,
      counts.unresolved
    ),
    "",
    "| Dungeon | ChallengeMapID | PortalSpellID | LFGActivityID | Status | Source | VerifiedAt |",
    "| --- | --- | --- | --- | --- | --- | --- |",
  }

  for _, name in ipairs(plannedOrder) do
    local row = dungeonRowsByName[name] or {}
    lines[#lines + 1] = string.format(
      "| %s | %s | %s | %s | %s | %s | %s |",
      name,
      tostring(row.ChallengeMapID or "missing"),
      tostring(row.PortalSpellID or "missing"),
      tostring(row.LFGActivityID or "missing"),
      tostring(row.Status or "missing"),
      tostring(row.Source or "missing"),
      tostring(row.VerifiedAt or "missing")
    )
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "### Weitere Daten"
  lines[#lines + 1] = string.format("- Ruhestein-Zeilen: %d", #tables.hearthstones)
  lines[#lines + 1] = string.format("- Mount-Zeilen: %d", #tables.mounts)

  if #errors > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "### Fehler"
    for _, err in ipairs(errors) do
      lines[#lines + 1] = "- " .. err
    end
  end

  return #errors == 0,
    {
      seasonID = targetSeason,
      errors = errors,
      tables = tables,
      summary = table.concat(lines, "\n") .. "\n",
    }
end

local cliArg = rawget(_G, "arg")
local isDirectRun = type(cliArg) == "table"
  and type(cliArg[0]) == "string"
  and cliArg[0]:find("check_season_intake.lua", 1, true) ~= nil

if isDirectRun then
  local ok, result = M.Check()
  io.write(result.summary)
  if not ok then
    os.exit(1)
  end
end

return M
