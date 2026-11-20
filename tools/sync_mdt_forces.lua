#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- sync_mdt_forces.lua
-- Extracts NPC count + dungeon total values from a local MDT clone and
-- generates data/isiLive_mplus_forces.lua for isiLive.
--
-- Usage (from repo root):
--   lua tools/sync_mdt_forces.lua [--season=<seasonID>] [--mdt=tools/cache/mdt]
--     [--source_commit=<40-char git sha>] [--out=data/isiLive_mplus_forces.lua]
--
-- Seasons (rule 260): without --season the tool writes the manifest's
-- activeSeasonID and, when set, its upcomingSeasonID into one file
-- (`MPlusForcesBySeason`, one section per season with its own metadata). The
-- active season is required: any gap there fails the run as before. The
-- upcoming season is best effort: while MDT has not published it completely it
-- is left out with a note, so a prepared season ships its forces data before
-- launch day without ever blocking the active one. --season=<id> writes
-- exactly that one season. `addonTable.MPlusForces` stays an alias of the
-- first (active or --season) section for tooling and older readers.
--
-- MDT dungeon files mutate an `MDT` table. We stub that table, run each file
-- as a chunk, and serialize the collected data. Files up to 6.1.x read the
-- table as an environment global; 6.2.0+ reads it as the second chunk vararg
-- (`local _, MDT = ...`). loadDungeonFile supplies both.
--
-- Re-run semantics: every invocation regenerates the whole file from
-- scratch — there is no incremental cache and no `mdtVersion`-keyed
-- short-circuit. Two consecutive runs against the same MDT commit
-- therefore produce identical `dungeonTotal` / `byNpcId` tables and
-- only differ in the `generatedAt` / `expiresAt` window stamp. That
-- is expected and not a sign of a header-only refresh: it means MDT
-- itself was stable upstream.

local manifestAddon = {}
local manifestLoader = loadfile("data/isiLive_seasons.lua")
if manifestLoader then
  manifestLoader("isiLive", manifestAddon)
end
local SEASON_MANIFEST = manifestAddon.SeasonManifest or {}
local LIFETIME_DAYS = 15
local MAX_DUNGEON_SOURCE_BYTES = 8 * 1024 * 1024
local MAX_DUNGEON_INSTRUCTIONS = 1000000

local function parseArgs(argv)
  local args = { mdt = "tools/cache/mdt", out = "data/isiLive_mplus_forces.lua" }
  for _, v in ipairs(argv or {}) do
    local k, val = v:match("^%-%-([%w_]+)=(.*)$")
    if k then
      args[k] = val
    end
  end
  return args
end

local function normalizeSourceCommit(value)
  if type(value) ~= "string" or #value ~= 40 or not value:match("^[0-9a-fA-F]+$") then
    return nil
  end
  return value:lower()
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
    -- MDT 6.2.0 builds texture paths as 'Interface\\AddOns\\'..addonName..'\\...'
    -- from MDT.AddonName. A nil here turns into a concat error that skips the
    -- whole dungeon file, so the stub has to carry the real addon folder name.
    AddonName = "MythicDungeonTools",
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

  -- Newer MDT dungeon files register their zone mapping through
  -- MDT:RegisterDungeonLocation (defined in MDT's Modules/MapView.lua, which
  -- the sandbox does not load). A missing method skips every dungeon file, so
  -- stub it; the zone mapping is irrelevant for the forces DB.
  MDT.RegisterDungeonLocation = function() end

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
  --
  -- MDT is provided BOTH ways on purpose:
  --   * as an environment global, which is how files up to 6.1.x read it, and
  --   * as the second chunk vararg (see the pcall below), which is how 6.2.0+
  --     reads it via `local _, MDT = ...` -- the WoW addonName/addonTable
  --     convention. 6.2.0-alpha5 switched to that form, and every dungeon file
  --     failed with "attempt to index a nil value (local 'MDT')" until the
  --     vararg was supplied.
  -- Keeping both keeps the generator working across an MDT version bump
  -- instead of silently producing an empty DB.
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
  local ok, runErr = pcall(chunk, "isiLive-sync", MDT)
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

local function addSeasonSection(add, data)
  add(string.format("  [%q] = {", data.season))
  add(string.format("    season = %q,", data.season))
  add(string.format("    mdtVersion = %q,", data.mdtVersion))
  add(string.format("    sourceCommit = %q,", data.sourceCommit))
  add(string.format("    generatedAt = %q,", data.generatedAt))
  add(string.format("    expiresAt = %q,", data.expiresAt))
  add(string.format("    dungeonCount = %d,", data.dungeonCount))
  add(string.format("    npcCount = %d,", data.npcCount))
  add("")
  add("    -- Enemy Forces total per dungeon (keyed by challenge-mode mapID)")
  add("    dungeonTotal = {")
  for _, mapID in ipairs(sortedKeys(data.dungeonTotal)) do
    local entry = data.dungeonTotal[mapID]
    add(string.format("      [%d] = { total = %d, name = %q },", mapID, entry.total, entry.name))
  end
  add("    },")
  add("")
  add("    -- count per NPC-id (appears in one of the dungeons above)")
  add("    byNpcId = {")
  for _, npcId in ipairs(sortedKeys(data.byNpcId)) do
    local entry = data.byNpcId[npcId]
    local name = tostring(entry.name or ""):gsub("\n", " ")
    add(string.format("      [%d] = { count = %d, mapID = %d }, -- %s", npcId, entry.count, entry.mapID, name))
  end
  add("    },")
  add("  },")
end

-- `sections` lists the season data tables (active season first);
-- `aliasSeason` names the section `addonTable.MPlusForces` points at.
local function formatDbLua(sections, aliasSeason)
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
  add("-- One section per season (rule 260): the active season and, once MDT")
  add("-- publishes it, the prepared upcoming season, so its mob percentages work")
  add("-- on launch day without another release.")
  add("addonTable.MPlusForcesBySeason = {")
  for index, data in ipairs(sections) do
    if index > 1 then
      add("")
    end
    addSeasonSection(add, data)
  end
  add("}")
  add("")
  add("-- Alias of the active season's section for tooling and older readers.")
  add(string.format("addonTable.MPlusForces = addonTable.MPlusForcesBySeason[%q]", aliasSeason))
  add("")

  return table.concat(lines, "\n")
end

-- Extracts one season from the MDT clone. Returns the season data table, or
-- nil, a message and the exit code a required season fails with. A season
-- without an mdtDirectory and requiresForces = false is not an error
-- (exit code 0): MDT upstream has not published it yet.
local function extractSeason(seasonID, args, sourceCommit, manifest)
  local season = type(manifest.seasons) == "table" and manifest.seasons[seasonID] or nil
  if type(season) ~= "table" then
    return nil, string.format("unknown season %q", tostring(seasonID)), 2
  end

  local mdtSubDir = season.mdtDirectory
  if type(mdtSubDir) ~= "string" or mdtSubDir == "" then
    if season.requiresForces == true then
      return nil, string.format("season %q requires forces but has no mdtDirectory", seasonID), 2
    end
    return nil, string.format("season=%s has no mdtDirectory and requiresForces = false, nothing to sync", seasonID), 0
  end

  -- Restrict the generated data to the target season's own dungeons.
  --
  -- The upstream directory is not a per-season folder: 6.1.x happened to hold
  -- exactly the eight Season 1 dungeons, so an unfiltered sweep looked correct.
  -- 6.2.0 ships Season 1 and Season 2 side by side in the same folder, and the
  -- unfiltered sweep silently produced a 16-dungeon DB stamped
  -- season = "midnight_s1". SeasonData.GetForcesReadiness rejects every
  -- out-of-season map id and npc id, so each season section carries exactly
  -- its own season's maps.
  local allowedMapIDs = {}
  local allowedCount = 0
  for _, dungeon in ipairs(type(season.dungeons) == "table" and season.dungeons or {}) do
    local mapID = tonumber(type(dungeon) == "table" and dungeon.mapID or nil)
    if mapID and mapID > 0 then
      allowedMapIDs[mapID] = true
      allowedCount = allowedCount + 1
    end
  end
  if allowedCount == 0 then
    return nil, string.format("season %q has no dungeon map ids in the manifest", seasonID), 2
  end

  local sourceDir = args.mdt .. "/" .. mdtSubDir
  local files = listLuaFiles(sourceDir)
  if #files == 0 then
    return nil, string.format("no .lua files in %s", sourceDir), 2
  end

  local MDT = buildSandbox()
  print(string.format("[sync_mdt_forces] season=%s mdt=%s files=%d", seasonID, args.mdt, #files))

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
  local skippedStubs, skippedBosses, skippedDupes, skippedOtherSeason = 0, 0, 0, 0

  for dungeonIdx, enemies in pairs(MDT.dungeonEnemies) do
    local info = MDT.mapInfo[dungeonIdx]
    local totals = MDT.dungeonTotalCount[dungeonIdx]
    local mapID = info and tonumber(info.mapID)
    local englishName = info and info.englishName or ("dungeon#" .. tostring(dungeonIdx))

    -- Stubs carry mapID=12345 (see MurderRow) and are skipped quietly.
    if not mapID or mapID == 12345 or mapID <= 0 then
      skippedStubs = skippedStubs + 1
    elseif not allowedMapIDs[mapID] then
      skippedOtherSeason = skippedOtherSeason + 1
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
      "[sync_mdt_forces] season=%s dungeons=%d/%d npcs=%d "
        .. "(skipped: stubs=%d bosses=%d cross-dungeon-dupes=%d other-season=%d)",
      seasonID,
      dungeonCount,
      allowedCount,
      npcCount,
      skippedStubs,
      skippedBosses,
      skippedDupes,
      skippedOtherSeason
    )
  )

  -- A season whose dungeons are missing upstream is a real gap, not a partial
  -- result to ship: the runtime would report every map id as missing a
  -- positive total and the season would never become ready.
  if dungeonCount < allowedCount then
    return nil,
      string.format(
        "season %q expects %d dungeons but upstream yielded %d, refusing to write a partial section",
        seasonID,
        allowedCount,
        dungeonCount
      ),
      3
  end
  if dungeonCount == 0 or npcCount == 0 then
    return nil, string.format("season %q yielded no forces data, refusing to write an empty section", seasonID), 3
  end

  return {
    season = seasonID,
    mdtVersion = readMdtVersion(args.mdt),
    sourceCommit = sourceCommit,
    generatedAt = isoDate(0),
    expiresAt = isoDate(LIFETIME_DAYS),
    dungeonCount = dungeonCount,
    npcCount = npcCount,
    dungeonTotal = dungeonTotal,
    byNpcId = byNpcId,
  }
end

-- Target seasons: the explicit --season alone (required), otherwise the active
-- season (required) plus a different upcomingSeasonID (best effort).
local function resolveTargets(args, manifest)
  manifest = manifest or SEASON_MANIFEST
  if type(args.season) == "string" and args.season ~= "" then
    return { { id = args.season, required = true } }
  end
  local active = manifest.activeSeasonID or ""
  local upcoming = manifest.upcomingSeasonID
  local targets = { { id = active, required = true } }
  if type(upcoming) == "string" and upcoming ~= "" and upcoming ~= active then
    targets[#targets + 1] = { id = upcoming, required = false }
  end
  return targets
end

-- Builds the DB text for `args` against `manifest` (default: the shipped
-- manifest). Returns { text, seasons, notes } on success. On failure returns
-- nil, message, exitCode; exitCode 0 means a required season legitimately has
-- no MDT data and the existing file stays untouched.
local function generate(args, manifest)
  manifest = manifest or SEASON_MANIFEST
  local sourceCommit = normalizeSourceCommit(args.source_commit)
  if not sourceCommit then
    return nil, "--source_commit must be the exact 40-character MDT git commit", 2
  end

  local targets = resolveTargets(args, manifest)
  local sections, written, notes = {}, {}, {}
  for _, target in ipairs(targets) do
    local data, message, exitCode = extractSeason(target.id, args, sourceCommit, manifest)
    if data then
      sections[#sections + 1] = data
      written[#written + 1] = data.season
    elseif target.required then
      return nil, message, exitCode
    else
      notes[#notes + 1] = "upcoming season left out: " .. message
    end
  end
  return { text = formatDbLua(sections, targets[1].id), seasons = written, notes = notes }
end

local function main(argv)
  local args = parseArgs(argv)
  local result, message, exitCode = generate(args)
  if not result then
    if exitCode == 0 then
      print(string.format("[sync_mdt_forces] %s, leaving %s untouched.", message, args.out))
    else
      io.stderr:write("[sync_mdt_forces] " .. message .. "\n")
    end
    os.exit(exitCode)
  end
  for _, note in ipairs(result.notes) do
    print("[sync_mdt_forces] " .. note)
  end

  local outFile, werr = io.open(args.out, "wb")
  if not outFile then
    io.stderr:write(string.format("[sync_mdt_forces] cannot open %s: %s\n", args.out, tostring(werr)))
    os.exit(4)
  end
  outFile:write(result.text)
  outFile:close()

  print(
    string.format(
      "[sync_mdt_forces] wrote %s seasons=%s (expires %s)",
      args.out,
      table.concat(result.seasons, ","),
      isoDate(LIFETIME_DAYS)
    )
  )
end

if ... == "module" then
  return {
    BuildSandbox = buildSandbox,
    LoadDungeonFile = loadDungeonFile,
    NormalizeSourceCommit = normalizeSourceCommit,
    FormatDbLua = formatDbLua,
    ResolveTargets = resolveTargets,
    Generate = generate,
  }
end

main(arg)
