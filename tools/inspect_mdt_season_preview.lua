#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Scans an already cloned MythicDungeonTools checkout for textual candidates
-- matching planned isiLive season dungeons. The output is an inspect artifact,
-- not a source of verified runtime IDs.

local DEFAULT_LANGUAGE_PATH = "locale/isiLive_languages.lua"
local DEFAULT_SEASON_DATA_PATH = "game/isiLive_season_data.lua"
local DEFAULT_MDT_PATH = "tools/cache/mdt"
local DEFAULT_SEASON_ID = "midnight_s2"

local function ParseArgs(args)
  local opts = {}
  for _, arg in ipairs(args or {}) do
    local key, value = tostring(arg):match("^%-%-([^=]+)=(.*)$")
    if key == "season" then
      opts.seasonID = value
    elseif key == "mdt" then
      opts.mdtPath = value
    elseif key == "season-data" then
      opts.seasonDataPath = value
    end
  end
  return opts
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

local function IsWindows()
  return package.config:sub(1, 1) == "\\"
end

local function ShellQuote(path)
  path = tostring(path or "")
  if IsWindows() then
    return '"' .. path:gsub('"', '\\"') .. '"'
  end
  return "'" .. path:gsub("'", "'\\''") .. "'"
end

local function ListLuaFiles(root)
  local command
  if IsWindows() then
    command = "dir /b /s " .. ShellQuote(root .. "\\*.lua") .. " 2>nul"
  else
    command = "find " .. ShellQuote(root) .. " -type f -name '*.lua' 2>/dev/null"
  end

  local handle = io.popen(command)
  if not handle then
    return {}
  end

  local files = {}
  for line in handle:lines() do
    if line and line ~= "" then
      files[#files + 1] = line
    end
  end
  handle:close()
  table.sort(files)
  return files
end

local function ReadFile(path)
  local file = io.open(path, "rb")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content or ""
end

local function NormalizeText(value)
  return tostring(value or ""):lower():gsub("[^%w]+", "")
end

local function FirstLineContaining(content, needle)
  local normalizedNeedle = NormalizeText(needle)
  if normalizedNeedle == "" then
    return nil
  end

  for line in tostring(content or ""):gmatch("[^\r\n]+") do
    if NormalizeText(line):find(normalizedNeedle, 1, true) then
      return line:gsub("^%s+", ""):gsub("%s+$", "")
    end
  end
  return nil
end

local function ReadMdtVersion(root)
  local tocContent = ReadFile(root .. "/MythicDungeonTools.toc") or ReadFile(root .. "\\MythicDungeonTools.toc")
  if not tocContent then
    return "unresolved"
  end
  return tocContent:match("##%s*Version:%s*([^\r\n]+)") or "unresolved"
end

local M = {}

function M.BuildSummary(opts)
  opts = opts or {}
  local seasonID = opts.seasonID or DEFAULT_SEASON_ID
  local mdtPath = opts.mdtPath or DEFAULT_MDT_PATH
  local addonTable = {}
  local lines = {
    "## isiLive MDT Season Preview",
    "",
    "- Season: " .. tostring(seasonID),
    "- MDT path: " .. tostring(mdtPath),
    "- MDT version: " .. ReadMdtVersion(mdtPath),
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
  local season = type(seasonData) == "table" and seasonData.SEASONS and seasonData.SEASONS[seasonID] or nil
  if type(season) ~= "table" then
    lines[#lines + 1] = "- Status: unresolved"
    lines[#lines + 1] = "- Reason: season id not present in SeasonData"
    return table.concat(lines, "\n") .. "\n"
  end

  local plannedDungeons = type(season.plannedDungeons) == "table" and season.plannedDungeons or {}
  local files = ListLuaFiles(mdtPath)
  local candidateMatches = 0
  lines[#lines + 1] = "- Lua files scanned: " .. tostring(#files)

  local tableLines = {
    "",
    "| Planned dungeon | Candidate file | Matched line |",
    "| --- | --- | --- |",
  }
  for _, dungeonName in ipairs(plannedDungeons) do
    local candidateFile = "unresolved"
    local matchedLine = "unresolved"
    for _, filePath in ipairs(files) do
      local content = ReadFile(filePath)
      local line = FirstLineContaining(content, dungeonName)
      if line then
        candidateFile = filePath
        matchedLine = line
        candidateMatches = candidateMatches + 1
        break
      end
    end
    tableLines[#tableLines + 1] =
      string.format("| %s | %s | %s |", tostring(dungeonName), tostring(candidateFile), tostring(matchedLine))
  end

  if #plannedDungeons == 0 then
    tableLines[#tableLines + 1] = "| unresolved | unresolved | plannedDungeons is empty |"
  end

  lines[#lines + 1] = "- Candidate matches: " .. tostring(candidateMatches)
  for _, line in ipairs(tableLines) do
    lines[#lines + 1] = line
  end

  return table.concat(lines, "\n") .. "\n"
end

local cliArg = rawget(_G, "arg")
local isDirectRun = type(cliArg) == "table"
  and type(cliArg[0]) == "string"
  and cliArg[0]:find("inspect_mdt_season_preview.lua", 1, true) ~= nil

if isDirectRun then
  local cliArgs = {}
  for index = 1, #cliArg do
    cliArgs[#cliArgs + 1] = cliArg[index]
  end
  local opts = ParseArgs(cliArgs)
  io.write(M.BuildSummary(opts))
end

return M
