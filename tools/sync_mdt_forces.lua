#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- sync_mdt_forces.lua
-- Extracts NPC count + dungeon total values from a local MDT clone and
-- generates data/isiLive_mplus_forces.lua for isiLive.
--
-- Usage (from repo root):
--   lua tools/sync_mdt_forces.lua [--season=midnight_s1] [--mdt=tools/cache/mdt] [--out=data/isiLive_mplus_forces.lua]
--
-- MDT dungeon files mutate a global `MDT` table. We stub that table,
-- run each file as a chunk, and serialize the collected data.
--
-- Re-run semantics: every invocation regenerates the whole file from
-- scratch — there is no incremental cache and no `mdtVersion`-keyed
-- short-circuit. Two consecutive runs against the same MDT commit
-- therefore produce identical `dungeonTotal` / `byNpcId` tables and
-- only differ in the `generatedAt` / `expiresAt` window stamp. That
-- is expected and not a sign of a header-only refresh: it means MDT
-- itself was stable upstream.

local SEASON_DEFAULT = "midnight_s1"
local SEASON_TO_MDT_DIR = {
  midnight_s1 = "Midnight",
}
local LIFETIME_DAYS = 15
local MAX_DUNGEON_SOURCE_BYTES = 8 * 1024 * 1024
local MAX_DUNGEON_INSTRUCTIONS = 1000000

local function parseArgs(argv)
  local args = { season = SEASON_DEFAULT, mdt = "tools/cache/mdt", out = "data/isiLive_mplus_forces.lua" }
  for _, v in ipairs(argv or {}) do
    local k, val = v:match("^%-%-([%w_]+)=(.*)$")
    if k then
      args[k] = val
    end
  end
  return args
end

local function buildSandbox()
  local autoTbl
  autoTbl = setmetatable({}, {
    __index = function(t, k)
      local sub = setmetatable({}, getmetatable(t))
      rawset(t, k, sub)
      return sub
    end,
  })

  local L = setmetatable({}, {
    __index = function(_, k)
      return k
    end,
  })

  local MDT = {
    L = L,
    dungeonList = {},
    mapInfo = {},
    dungeonTotalCount = {},
    dungeonEnemies = {},
    dungeonMaps = autoTbl,
    mapPOIs = autoTbl,
    dungeonSubLevels = autoTbl,
    zoneIdToDungeonIdx = {},
    mapPOIsCustomSize = {},
    dungeonBosses = {},
    dungeonBossPulls = {},
  }

  return MDT
end

local function loadDungeonFile(path, MDT)
  local file, readErr = io.open(path, "rb")
  if not file then
    return false, readErr
  end
  local source = file:read("*a")
  file:close()
  if type(source) ~= "string" then
    return false, "source is unreadable"
  end
  if #source > MAX_DUNGEON_SOURCE_BYTES then
    return false, string.format("source exceeds %d byte limit", MAX_DUNGEON_SOURCE_BYTES)
  end
  if source:byte(1) == 27 then
    return false, "Lua bytecode is not accepted"
  end

  -- MDT dungeon data is third-party input. Current source files require only
  -- the injected MDT table plus ipairs; never inherit _G because this tool can
  -- run in an automated workflow with repository write permission.
  local env = { MDT = MDT, ipairs = ipairs }
  local chunk, err
  if setfenv then
    chunk, err = loadstring(source, "@" .. path)
    if not chunk then
      return false, err
    end
    setfenv(chunk, env)
  else
    chunk, err = load(source, "@" .. path, "t", env)
    if not chunk then
      return false, err
    end
  end

  local debugLib = rawget(_G, "debug")
  local canLimitInstructions = type(debugLib) == "table"
    and type(debugLib.sethook) == "function"
    and type(debugLib.gethook) == "function"
  local previousHook, previousMask, previousCount
  if canLimitInstructions then
    previousHook, previousMask, previousCount = debugLib.gethook()
    debugLib.sethook(function()
      error("MDT dungeon source exceeded instruction limit")
    end, "", MAX_DUNGEON_INSTRUCTIONS)
  end
  local ok, runErr = pcall(chunk, "isiLive-sync")
  if canLimitInstructions then
    if previousHook then
      debugLib.sethook(previousHook, previousMask or "", previousCount or 0)
    else
      debugLib.sethook()
    end
  end
  if not ok then
    return false, runErr
  end
  return true, nil
end

local function listLuaFiles(dir)
  local files = {}
  local sep = package.config:sub(1, 1)
  local cmd
  if sep == "\\" then
    cmd = 'dir /b "' .. dir:gsub("/", "\\") .. '\\*.lua"'
  else
    cmd = 'ls "' .. dir .. '"/*.lua 2>/dev/null'
  end
  local p = io.popen(cmd)
  if not p then
    return files
  end
  for line in p:lines() do
    line = line:gsub("\r$", "")
    if line ~= "" then
      if sep == "\\" then
        files[#files + 1] = dir .. "/" .. line
      else
        files[#files + 1] = line
      end
    end
  end
  p:close()
  table.sort(files)
  return files
end

local function isoDate(offsetDays)
  local t = os.time() + (offsetDays or 0) * 86400
  return os.date("!%Y-%m-%d", t)
end

local function readMdtVersion(mdtRoot)
  local tocPath = mdtRoot .. "/MythicDungeonTools.toc"
  local f = io.open(tocPath, "r")
  if not f then
    return "unknown"
  end
  for line in f:lines() do
    local v = line:match("^##%s*Version:%s*(.-)%s*$")
    if v then
      f:close()
      return v
    end
  end
  f:close()
  return "unknown"
end

local function sortedKeys(t)
  local keys = {}
  for k in pairs(t) do
    keys[#keys + 1] = k
  end
  table.sort(keys)
  return keys
end

local function formatDbLua(data)
  local lines = {}
  local function add(s)
    lines[#lines + 1] = s
  end

  add("-- GENERATED by tools/sync_mdt_forces.lua — do not edit by hand.")
  add("-- Data derived from MythicDungeonTools (GPLv2) by Nnoggie —")
  add("-- https://github.com/Nnoggie/MythicDungeonTools")
  add("")
  add("local _, addonTable = ...")
  add("")
  add("addonTable.MPlusForces = {")
  add(string.format("  season = %q,", data.season))
  add(string.format("  mdtVersion = %q,", data.mdtVersion))
  add(string.format("  generatedAt = %q,", data.generatedAt))
  add(string.format("  expiresAt = %q,", data.expiresAt))
  add(string.format("  dungeonCount = %d,", data.dungeonCount))
  add(string.format("  npcCount = %d,", data.npcCount))
  add("")
  add("  -- Enemy Forces total per dungeon (keyed by challenge-mode mapID)")
  add("  dungeonTotal = {")
  for _, mapID in ipairs(sortedKeys(data.dungeonTotal)) do
    local entry = data.dungeonTotal[mapID]
    add(string.format("    [%d] = { total = %d, name = %q },", mapID, entry.total, entry.name))
  end
  add("  },")
  add("")
  add("  -- count per NPC-id (appears in one of the dungeons above)")
  add("  byNpcId = {")
  for _, npcId in ipairs(sortedKeys(data.byNpcId)) do
    local entry = data.byNpcId[npcId]
    add(
      string.format(
        "    [%d] = { count = %d, mapID = %d }, -- %s",
        npcId,
        entry.count,
        entry.mapID,
        entry.name:gsub("\n", " ")
      )
    )
  end
  add("  },")
  add("}")
  add("")

  return table.concat(lines, "\n")
end

local function main(argv)
  local args = parseArgs(argv)

  local mdtSubDir = SEASON_TO_MDT_DIR[args.season]
  if not mdtSubDir then
    io.stderr:write(string.format("[sync_mdt_forces] unknown season %q\n", args.season))
    os.exit(2)
  end

  local sourceDir = args.mdt .. "/" .. mdtSubDir
  local files = listLuaFiles(sourceDir)
  if #files == 0 then
    io.stderr:write(string.format("[sync_mdt_forces] no .lua files in %s\n", sourceDir))
    os.exit(2)
  end

  local MDT = buildSandbox()
  print(string.format("[sync_mdt_forces] season=%s mdt=%s files=%d", args.season, args.mdt, #files))

  local loaded = {}
  for _, path in ipairs(files) do
    local ok, err = loadDungeonFile(path, MDT)
    if ok then
      loaded[#loaded + 1] = path
    else
      io.stderr:write(string.format("[sync_mdt_forces] skip %s: %s\n", path, tostring(err)))
    end
  end
  print(string.format("[sync_mdt_forces] loaded %d/%d dungeon files", #loaded, #files))

  local dungeonTotal = {}
  local byNpcId = {}
  local skippedStubs, skippedBosses, skippedDupes = 0, 0, 0

  for dungeonIdx, enemies in pairs(MDT.dungeonEnemies) do
    local info = MDT.mapInfo[dungeonIdx]
    local totals = MDT.dungeonTotalCount[dungeonIdx]
    local mapID = info and tonumber(info.mapID)
    local englishName = info and info.englishName or ("dungeon#" .. tostring(dungeonIdx))

    -- Stubs carry mapID=12345 (see MurderRow) — skip quietly.
    if not mapID or mapID == 12345 or mapID <= 0 then
      skippedStubs = skippedStubs + 1
    else
      local total = totals and tonumber(totals.normal) or 0
      if total > 0 then
        dungeonTotal[mapID] = { total = total, name = englishName }
      end

      for _, e in pairs(enemies) do
        local id = tonumber(e.id)
        local count = tonumber(e.count) or 0
        if id and count > 0 then
          if byNpcId[id] and byNpcId[id].mapID ~= mapID then
            skippedDupes = skippedDupes + 1
          end
          byNpcId[id] = {
            count = count,
            mapID = mapID,
            name = tostring(e.name or ""),
          }
        elseif id and count == 0 then
          skippedBosses = skippedBosses + 1
        end
      end
    end
  end

  local dungeonCount, npcCount = 0, 0
  for _ in pairs(dungeonTotal) do
    dungeonCount = dungeonCount + 1
  end
  for _ in pairs(byNpcId) do
    npcCount = npcCount + 1
  end

  print(
    string.format(
      "[sync_mdt_forces] dungeons=%d npcs=%d (skipped: stubs=%d bosses=%d cross-dungeon-dupes=%d)",
      dungeonCount,
      npcCount,
      skippedStubs,
      skippedBosses,
      skippedDupes
    )
  )

  if dungeonCount == 0 or npcCount == 0 then
    io.stderr:write("[sync_mdt_forces] refusing to write empty DB\n")
    os.exit(3)
  end

  local out = formatDbLua({
    season = args.season,
    mdtVersion = readMdtVersion(args.mdt),
    generatedAt = isoDate(0),
    expiresAt = isoDate(LIFETIME_DAYS),
    dungeonCount = dungeonCount,
    npcCount = npcCount,
    dungeonTotal = dungeonTotal,
    byNpcId = byNpcId,
  })

  local outFile, werr = io.open(args.out, "wb")
  if not outFile then
    io.stderr:write(string.format("[sync_mdt_forces] cannot open %s: %s\n", args.out, tostring(werr)))
    os.exit(4)
  end
  outFile:write(out)
  outFile:close()

  print(string.format("[sync_mdt_forces] wrote %s (expires %s)", args.out, isoDate(LIFETIME_DAYS)))
end

if ... == "module" then
  return {
    BuildSandbox = buildSandbox,
    LoadDungeonFile = loadDungeonFile,
  }
end

main(arg)
