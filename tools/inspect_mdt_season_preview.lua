#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Scans an already cloned MythicDungeonTools checkout for planned isiLive
-- season dungeons and verifies whether every matching dungeon file contains a
-- usable forces dataset. The output is an inspect artifact, not a runtime DB.

local DEFAULT_LANGUAGE_PATH = "locale/isiLive_languages.lua"
local DEFAULT_SEASON_DATA_PATH = "game/isiLive_season_data.lua"
local DEFAULT_MDT_PATH = "tools/cache/mdt"
local DEFAULT_SEASON_ID = "midnight_s2"
local DEFAULT_SYNC_TOOL_PATH = "tools/sync_mdt_forces.lua"

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

local function IsDungeonDataFile(path)
  local normalized = tostring(path or ""):gsub("\\", "/"):lower()
  return not normalized:find("/locales/", 1, true) and not normalized:find("/modules/", 1, true)
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

local function LoadTool(path)
  local chunk, err = loadfile(path)
  if not chunk then
    return nil, string.format("cannot load %s: %s", tostring(path), tostring(err))
  end
  local ok, tool = pcall(chunk, "module")
  if not ok or type(tool) ~= "table" then
    return nil, string.format("load error in %s: %s", tostring(path), tostring(tool))
  end
  return tool
end

local function ValidateForcesCandidate(filePath, expectedMapID, expectedName, syncTool)
  if filePath == "unresolved" then
    return false, "candidate file is missing"
  end
  if
    type(syncTool) ~= "table"
    or type(syncTool.BuildSandbox) ~= "function"
    or type(syncTool.LoadDungeonFile) ~= "function"
  then
    return false, "forces sandbox is unavailable"
  end

  local MDT = syncTool.BuildSandbox()
  local ok, err = syncTool.LoadDungeonFile(filePath, MDT)
  if not ok then
    return false, "candidate execution failed: " .. tostring(err)
  end

  for dungeonIndex, info in pairs(MDT.mapInfo or {}) do
    if type(info) == "table" and info.englishName == expectedName then
      if tonumber(info.mapID) ~= expectedMapID then
        return false, string.format("mapID mismatch: expected %d, got %s", expectedMapID, tostring(info.mapID))
      end

      local totals = MDT.dungeonTotalCount and MDT.dungeonTotalCount[dungeonIndex]
      if type(totals) ~= "table" or not tonumber(totals.normal) or tonumber(totals.normal) <= 0 then
        return false, "positive normal dungeon total is missing"
      end

      local enemies = MDT.dungeonEnemies and MDT.dungeonEnemies[dungeonIndex]
      if type(enemies) ~= "table" then
        return false, "dungeon enemies are missing"
      end
      for _, enemy in pairs(enemies) do
        if
          type(enemy) == "table"
          and tonumber(enemy.id)
          and tonumber(enemy.id) > 0
          and tonumber(enemy.count)
          and tonumber(enemy.count) > 0
        then
          return true, "ready"
        end
      end
      return false, "positive NPC forces entry is missing"
    end
  end

  return false, "exact English dungeon name is missing from MDT mapInfo"
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
  local mapToTeleport = type(season.mapToTeleport) == "table" and season.mapToTeleport or {}
  local namesByMapID = type(season.namesByLocale) == "table" and season.namesByLocale.enUS or {}
  local mapIDByName = {}
  for mapID in pairs(mapToTeleport) do
    local name = type(namesByMapID) == "table" and namesByMapID[mapID] or nil
    if type(name) == "string" and name ~= "" then
      mapIDByName[name] = mapID
    end
  end
  local syncTool, syncToolError = LoadTool(opts.syncToolPath or DEFAULT_SYNC_TOOL_PATH)
  local files = ListLuaFiles(mdtPath)
  local candidateMatches = 0
  local forcesReadyDungeons = 0
  lines[#lines + 1] = "- Lua files scanned: " .. tostring(#files)

  local tableLines = {
    "",
    "| Planned dungeon | Map ID | Candidate file | Matched line | Forces status |",
    "| --- | ---: | --- | --- | --- |",
  }
  for _, dungeonName in ipairs(plannedDungeons) do
    local candidateFile = "unresolved"
    local matchedLine = "unresolved"
    local expectedMapID = mapIDByName[dungeonName]
    local forcesReady = false
    local forcesStatus = "unresolved: candidate file is missing"
    for _, filePath in ipairs(files) do
      if IsDungeonDataFile(filePath) then
        local content = ReadFile(filePath)
        local line = FirstLineContaining(content, dungeonName)
        if line then
          candidateMatches = candidateMatches + 1
          candidateFile = filePath
          matchedLine = line
          if expectedMapID and syncTool then
            local ready, reason = ValidateForcesCandidate(filePath, expectedMapID, dungeonName, syncTool)
            if ready then
              candidateFile = filePath
              matchedLine = line
              forcesReady = true
              forcesStatus = "ready"
              break
            end
            forcesStatus = "unresolved: " .. tostring(reason)
          end
        end
      end
    end
    if not expectedMapID then
      forcesStatus = "unresolved: configured map ID is missing"
    elseif not syncTool then
      forcesStatus = "unresolved: " .. tostring(syncToolError)
    end
    if forcesReady then
      forcesReadyDungeons = forcesReadyDungeons + 1
    end
    tableLines[#tableLines + 1] = string.format(
      "| %s | %s | %s | %s | %s |",
      tostring(dungeonName),
      tostring(expectedMapID or "unresolved"),
      tostring(candidateFile),
      tostring(matchedLine),
      tostring(forcesStatus)
    )
  end

  if #plannedDungeons == 0 then
    tableLines[#tableLines + 1] = "| unresolved | unresolved | unresolved | plannedDungeons is empty | unresolved |"
  end

  lines[#lines + 1] = "- Candidate matches: " .. tostring(candidateMatches)
  lines[#lines + 1] = string.format("- Forces-ready dungeons: %d/%d", forcesReadyDungeons, #plannedDungeons)
  lines[#lines + 1] = "- Forces-ready: "
    .. ((#plannedDungeons > 0 and forcesReadyDungeons == #plannedDungeons) and "yes" or "no")
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
