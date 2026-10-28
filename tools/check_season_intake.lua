#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Validates docs/SEASON_INTAKE.md as the pre-activation collection surface for
-- upcoming season data. Unresolved values are allowed; guessed or source-less
-- concrete IDs are not.

local DEFAULT_INTAKE_PATH = "docs/SEASON_INTAKE.md"
local DEFAULT_LANGUAGE_PATH = "locale/isiLive_languages.lua"
local DEFAULT_SEASON_DATA_PATH = "game/isiLive_season_data.lua"

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
  -- The full match must consume the delimiter. Lua 5.1 and 5.4 advance
  -- zero-length gmatch results differently, which can shift table columns.
  for cell in (trimmed .. "|"):gmatch("(.-)|") do
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
  -- Hearthstone, mount and travel-item intake is not seasonal and lives in
  -- docs/TRAVEL_INTAKE.md (tools/check_travel_items.lua).
  local sections = {
    dungeons = {},
  }
  local current
  local header

  for line in tostring(content or ""):gmatch("[^\r\n]+") do
    if line:find("^## Dungeon%-Intake") then
      current = "dungeons"
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

-- Without an explicit season every season that appears in the intake is
-- validated on its own, in order of first appearance. Verified rows of the
-- running season stay next to the rows collected for the next one, so the
-- drift check against the manifest keeps covering both.
local function ResolveTargetSeasons(tables, requestedSeason)
  if requestedSeason ~= nil then
    local normalized = Trim(requestedSeason)
    if not normalized:match("^[%w_%-]+$") then
      return nil, "requested season ID has an invalid format"
    end
    return { normalized }
  end

  local seen = {}
  local ordered = {}
  for _, section in ipairs({ "dungeons" }) do
    for _, row in ipairs(type(tables) == "table" and tables[section] or {}) do
      local seasonID = Trim(row.Season)
      if seasonID == "" then
        return nil, "intake row without a season ID in section " .. section
      end
      if not seasonID:match("^[%w_%-]+$") then
        return nil, "intake season ID '" .. seasonID .. "' has an invalid format"
      end
      if not seen[seasonID] then
        seen[seasonID] = true
        ordered[#ordered + 1] = seasonID
      end
    end
  end

  if #ordered == 0 then
    return nil, "intake does not contain a season ID"
  end
  return ordered
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

local function CountStatuses(rows, seasonID)
  local counts = {
    unresolved = 0,
    candidate = 0,
    partial = 0,
    verified = 0,
  }
  for _, row in ipairs(rows) do
    if row.Season == seasonID then
      local status = Trim(row.Status)
      if counts[status] ~= nil then
        counts[status] = counts[status] + 1
      end
    end
  end
  return counts
end

local M = {}

-- Shared intake-row primitives, reused by tools/check_travel_items.lua so both
-- intake gates apply the same Status / Source / VerifiedAt contract.
M.SplitMarkdownRow = SplitMarkdownRow
M.IsSeparatorRow = IsSeparatorRow
M.ValidateRow = ValidateRow
M.RegisterUnique = RegisterUnique
M.IsUnresolved = IsUnresolved
M.IsPositiveInteger = IsPositiveInteger
M.IsDate = IsDate
M.Trim = Trim

local function BuildManifestDungeonIndex(seasonData, seasonID)
  local manifestSeason = seasonData.MANIFEST and seasonData.MANIFEST.seasons and seasonData.MANIFEST.seasons[seasonID]
  local byMapID = {}
  for _, dungeon in ipairs(type(manifestSeason) == "table" and manifestSeason.dungeons or {}) do
    local mapID = tonumber(dungeon.mapID)
    if mapID then
      byMapID[mapID] = dungeon
    end
  end
  return byMapID
end

local function ValidateManifestDrift(errors, seasonData, targetSeason, manifestDungeonByMapID, row, label)
  local mapID = tonumber(row.ChallengeMapID)
  local portalSpellID = tonumber(row.PortalSpellID)
  local activityID = tonumber(row.LFGActivityID)
  if not (mapID and portalSpellID and activityID) then
    return
  end
  local manifestDungeon = manifestDungeonByMapID[mapID]
  if type(manifestDungeon) ~= "table" then
    AddError(errors, label .. " is missing from the season manifest")
    return
  end
  if seasonData.GetDungeonName(mapID, "enUS", targetSeason) ~= row.Dungeon then
    AddError(errors, label .. " dungeon name does not match the season manifest")
  end
  if seasonData.GetMapToTeleport(targetSeason)[mapID] ~= portalSpellID then
    AddError(errors, label .. " PortalSpellID does not match the season manifest")
  end
  if seasonData.GetMapIDByActivityID(activityID, targetSeason) ~= mapID then
    AddError(errors, label .. " LFGActivityID does not match the season manifest")
  end
  local verification = manifestDungeon.verification
  if type(verification) == "table" then
    if verification.status ~= row.Status then
      AddError(errors, label .. " Status does not match the season manifest")
    end
    if verification.verifiedAt ~= row.VerifiedAt then
      AddError(errors, label .. " VerifiedAt does not match the season manifest")
    end
  end
end

-- Validates one season of the intake. A season that has no manifest entry yet
-- is a pure collection surface: its rows may be unresolved, candidate or
-- partial, but nothing may claim `verified` before the manifest carries it.
local function CheckSeason(tables, targetSeason, seasonData)
  local errors = {}
  local inManifest = type(seasonData.SEASONS) == "table" and seasonData.SEASONS[targetSeason] ~= nil

  local plannedSet, plannedOrder = BuildPlannedDungeonSet(seasonData, targetSeason)
  if inManifest and #plannedOrder == 0 then
    AddError(errors, "target season " .. targetSeason .. " has no plannedDungeons in SeasonData")
  end

  local dungeonRowsByName = {}
  local dungeonRowOrder = {}
  local seenChallenge = {}
  local seenPortal = {}
  local seenLfg = {}
  local manifestDungeonByMapID = BuildManifestDungeonIndex(seasonData, targetSeason)

  local function RejectVerifiedWithoutManifest(label, row)
    if not inManifest and Trim(row.Status) == "verified" then
      AddError(errors, label .. " is verified but season " .. targetSeason .. " is not in the season manifest")
    end
  end

  for _, row in ipairs(tables.dungeons) do
    local label = string.format("dungeon row %s/%s", tostring(row.Season), tostring(row.Dungeon))
    if row.Season == targetSeason then
      if dungeonRowsByName[row.Dungeon] then
        AddError(errors, "duplicate dungeon intake row for " .. row.Dungeon)
      else
        if inManifest and not plannedSet[row.Dungeon] then
          AddError(errors, label .. " is not listed in SeasonData.plannedDungeons")
        end
        dungeonRowsByName[row.Dungeon] = row
        dungeonRowOrder[#dungeonRowOrder + 1] = row.Dungeon
      end
      ValidateRow(errors, label, row, { "ChallengeMapID", "PortalSpellID", "LFGActivityID" })
      RejectVerifiedWithoutManifest(label, row)
      RegisterUnique(errors, seenChallenge, "ChallengeMapID", row.ChallengeMapID, label)
      RegisterUnique(errors, seenPortal, "PortalSpellID", row.PortalSpellID, label)
      RegisterUnique(errors, seenLfg, "LFGActivityID", row.LFGActivityID, label)
      if inManifest then
        ValidateManifestDrift(errors, seasonData, targetSeason, manifestDungeonByMapID, row, label)
      end
    end
  end

  if inManifest then
    for _, name in ipairs(plannedOrder) do
      if not dungeonRowsByName[name] then
        AddError(errors, "missing dungeon intake row for planned dungeon " .. name)
      end
    end
  end

  -- A manifest season lists its planned dungeons; a pre-manifest season only
  -- has the rows collected so far.
  local reportOrder = inManifest and plannedOrder or dungeonRowOrder
  local counts = CountStatuses(tables.dungeons, targetSeason)
  local lines = {
    "## Season Intake Check",
    "",
    "- Season: " .. targetSeason,
    "- Manifest: " .. (inManifest and "configured" or "not configured yet (collection only)"),
    "- Status: " .. (#errors == 0 and "valid" or "invalid"),
    string.format(
      "- Dungeon progress: %d/%d verified, %d partial, %d candidate, %d unresolved",
      counts.verified,
      #reportOrder,
      counts.partial,
      counts.candidate,
      counts.unresolved
    ),
    "",
    "| Dungeon | ChallengeMapID | PortalSpellID | LFGActivityID | Status | Source | VerifiedAt |",
    "| --- | --- | --- | --- | --- | --- | --- |",
  }

  for _, name in ipairs(reportOrder) do
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
      inManifest = inManifest,
      errors = errors,
      summary = table.concat(lines, "\n") .. "\n",
    }
end

local function FailureResult(seasonID, reason, withSeasonLine)
  local header = "## Season Intake Check\n\n"
  if withSeasonLine then
    header = header .. "- Season: " .. tostring(seasonID) .. "\n"
  end
  return false,
    {
      seasonID = seasonID,
      seasonIDs = {},
      results = {},
      errors = { reason },
      summary = header .. "- Status: invalid\n- Reason: " .. tostring(reason) .. "\n",
    }
end

-- Lists the seasons a run without `seasonID` validates (CLI `--list-seasons`).
function M.ListSeasons(opts)
  opts = opts or {}
  local content, readErr = ReadFile(opts.intakePath or DEFAULT_INTAKE_PATH)
  if not content then
    return nil, readErr
  end
  return ResolveTargetSeasons(ParseTables(content), opts.seasonID)
end

-- The season the runtime serves (CLI `--print-active-season`). The intake is a
-- pre-activation surface, so the workflow retires that season's issue.
function M.ResolveActiveSeasonID(opts)
  local seasonData, err = LoadSeasonData(opts or {})
  if not seasonData then
    return nil, err
  end
  local seasonID = seasonData.ACTIVE_SEASON_ID
  if type(seasonID) ~= "string" or seasonID == "" then
    return nil, "season manifest has no active season"
  end
  return seasonID
end

function M.Check(opts)
  opts = opts or {}
  local content, readErr = ReadFile(opts.intakePath or DEFAULT_INTAKE_PATH)
  if not content then
    return FailureResult(opts.seasonID or "unresolved", readErr, false)
  end

  local tables = ParseTables(content)
  local targetSeasons, targetErr = ResolveTargetSeasons(tables, opts.seasonID)
  if not targetSeasons then
    return FailureResult("unresolved", targetErr, true)
  end

  local seasonData, seasonErr = LoadSeasonData(opts)
  if not seasonData then
    return FailureResult(targetSeasons[1], seasonErr, false)
  end

  local allOk = true
  local errors = {}
  local results = {}
  local summaries = {}
  for _, manifestError in ipairs(seasonData.MANIFEST_ERRORS or {}) do
    allOk = false
    errors[#errors + 1] = "season manifest: " .. tostring(manifestError)
  end
  if #errors > 0 then
    local lines = { "## Season Manifest", "", "- Status: invalid" }
    for _, err in ipairs(errors) do
      lines[#lines + 1] = "- " .. err
    end
    summaries[#summaries + 1] = table.concat(lines, "\n") .. "\n"
  end

  for _, seasonID in ipairs(targetSeasons) do
    local ok, result = CheckSeason(tables, seasonID, seasonData)
    allOk = allOk and ok
    results[seasonID] = result
    summaries[#summaries + 1] = result.summary
    for _, err in ipairs(result.errors) do
      errors[#errors + 1] = seasonID .. ": " .. err
    end
  end

  return allOk,
    {
      -- Kept for single-season callers; nil once the intake carries several seasons.
      seasonID = #targetSeasons == 1 and targetSeasons[1] or nil,
      seasonIDs = targetSeasons,
      results = results,
      errors = errors,
      tables = tables,
      summary = table.concat(summaries, "\n"),
    }
end

local function ParseCliArgs(cliArg)
  local opts = {}
  for index = 1, #cliArg do
    local value = tostring(cliArg[index])
    local seasonID = value:match("^%-%-season=(.+)$")
    if seasonID then
      opts.seasonID = seasonID
    elseif value == "--list-seasons" then
      opts.listSeasons = true
    elseif value == "--print-active-season" then
      opts.printActiveSeason = true
    else
      return nil, "unknown argument " .. value
    end
  end
  return opts
end

local cliArg = rawget(_G, "arg")
local isDirectRun = type(cliArg) == "table"
  and type(cliArg[0]) == "string"
  and cliArg[0]:find("check_season_intake.lua", 1, true) ~= nil

if isDirectRun then
  local cliOpts, argErr = ParseCliArgs(cliArg)
  if not cliOpts then
    io.stderr:write("[check_season_intake] " .. argErr .. "\n")
    os.exit(2)
  end
  if cliOpts.listSeasons then
    local seasonIDs, listErr = M.ListSeasons(cliOpts)
    if not seasonIDs then
      io.stderr:write("[check_season_intake] " .. tostring(listErr) .. "\n")
      os.exit(1)
    end
    io.write(table.concat(seasonIDs, "\n") .. "\n")
  elseif cliOpts.printActiveSeason then
    local seasonID, activeErr = M.ResolveActiveSeasonID(cliOpts)
    if not seasonID then
      io.stderr:write("[check_season_intake] " .. tostring(activeErr) .. "\n")
      os.exit(1)
    end
    io.write(seasonID .. "\n")
  else
    local ok, result = M.Check(cliOpts)
    io.write(result.summary)
    if not ok then
      os.exit(1)
    end
  end
end

return M
