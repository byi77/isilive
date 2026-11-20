#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Season doctor (maintainability package 5 N): one command that runs every
-- automatable check for one season and lists only what is still open, plus
-- the in-game steps no tool can take. It reads the shipped data in data/ and
-- docs/, changes nothing and needs no network.
--
-- Usage (from repo root):
--   lua tools/season_doctor.lua [--season=<id>] [--no-sim] [--versions=<dir>]
--
--   --season    default: the manifest's upcomingSeasonID, else activeSeasonID
--   --no-sim    skip the wowsim season smoke (enUS, deDE)
--   --versions  directory with Blizzard version tables (<product>.txt, as the
--               patch-watch workflow saves them) for the TOC interface check
--
-- Exit codes: 0 every automatable check passed, 1 at least one failed,
-- 2 the season is unknown or the data cannot be loaded.

local M = {}

local SEASON_PATH = "data/isiLive_seasons.lua"
local FORCES_PATH = "data/isiLive_mplus_forces.lua"
local CONSUMABLES_PATH = "data/isiLive_consumables.lua"

local function LoadInto(path, addonTable)
  local chunk, err = loadfile(path)
  if not chunk then
    return false, err
  end
  return pcall(chunk, "isiLive", addonTable)
end

local function LoadTool(path)
  local chunk = assert(loadfile(path))
  return chunk("module")
end

local function LoadData()
  local addonTable = {}
  for _, path in ipairs({
    "core/isiLive_validation_helpers.lua",
    "locale/isiLive_languages.lua",
    SEASON_PATH,
    "game/isiLive_season_data.lua",
    FORCES_PATH,
    CONSUMABLES_PATH,
  }) do
    local ok, err = LoadInto(path, addonTable)
    if not ok then
      return nil, path .. ": " .. tostring(err)
    end
  end
  return addonTable
end

-- os.execute returns a number on Lua 5.1 and true/nil plus the code on 5.2+.
local function Run(command)
  local a, _, c = os.execute(command)
  if type(a) == "number" then
    return a == 0
  end
  return a == true and (c == nil or c == 0)
end

local function ParseArgs(argv)
  local args = {}
  for _, value in ipairs(argv or {}) do
    local key, val = value:match("^%-%-([%w_%-]+)=(.*)$")
    if key then
      args[key] = val
    elseif value == "--no-sim" then
      args.noSim = true
    end
  end
  return args
end

--- Runs the checks. Returns code, markdown report, rows.
-- opts: season, noSim, versions, today (YYYY-MM-DD for the forces expiry),
--       runSim (function(seasonID, locale) -> ok),
--       data (preloaded addonTable for tests).
function M.Run(opts)
  opts = opts or {}
  local data, loadErr = opts.data, nil
  if not data then
    data, loadErr = LoadData()
  end
  if not data then
    return 2, "## Season doctor\n\n- Status: unresolved\n- Reason: " .. tostring(loadErr), {}
  end
  local manifest = data.SeasonManifest
  local seasonData = data.SeasonData
  local seasonID = opts.season or manifest.upcomingSeasonID or manifest.activeSeasonID
  local season = manifest.seasons and manifest.seasons[seasonID]
  if type(season) ~= "table" then
    return 2, "## Season doctor\n\n- Status: unresolved\n- Reason: unknown season " .. tostring(seasonID), {}
  end
  local isActive = seasonID == manifest.activeSeasonID

  local rows = {}
  local function Row(status, name, detail)
    rows[#rows + 1] = { status = status, name = name, detail = detail }
  end
  -- Detail only for a failed check (`ok and nil or text` would always yield text).
  local function FailDetail(ok, detail)
    if ok then
      return nil
    end
    return detail
  end

  -- 1. Manifest and readiness.
  local manifestErrors = seasonData.MANIFEST_ERRORS or {}
  Row(#manifestErrors == 0 and "ok" or "fail", "Manifest", FailDetail(#manifestErrors == 0, manifestErrors[1]))
  local readiness = seasonData.GetSeasonReadiness(seasonID)
  Row(
    readiness.isReady and "ok" or "fail",
    "Readiness",
    readiness.isReady and string.format("%d dungeons", readiness.mappedDungeonCount)
      or (readiness.errors[1] or readiness.warnings[1])
  )

  -- 2. Launch-day switch.
  if season.autoDetectFromChallengeMaps == true then
    Row("ok", "Runtime switch", "autoDetectFromChallengeMaps = true")
  else
    Row(
      isActive and "warn" or "fail",
      "Runtime switch",
      "autoDetectFromChallengeMaps is not true: the season cannot switch by itself on launch day"
    )
  end
  if not isActive then
    Row(
      manifest.upcomingSeasonID == seasonID and "ok" or "fail",
      "upcomingSeasonID",
      FailDetail(
        manifest.upcomingSeasonID == seasonID,
        "set upcomingSeasonID so tools and the MDT sync target this season"
      )
    )
  end

  -- 3. Intake.
  local intakeTool = LoadTool("tools/check_season_intake.lua")
  local intakeOk, intake = intakeTool.Check({ seasonID = seasonID })
  local verified = type(intake.summary) == "string" and intake.summary:match("(%d+/%d+) verified") or nil
  Row(
    intakeOk and "ok" or "fail",
    "Intake (docs/SEASON_INTAKE.md)",
    intakeOk and (verified and (verified .. " verified") or nil) or (intake.errors and intake.errors[1])
  )

  -- 4. Forces section.
  if season.requiresForces == true then
    local section = type(data.MPlusForcesBySeason) == "table" and data.MPlusForcesBySeason[seasonID]
      or (type(data.MPlusForces) == "table" and data.MPlusForces.season == seasonID and data.MPlusForces)
      or nil
    if not section then
      Row(
        "fail",
        "Forces DB section",
        "missing: run tools/sync_mdt_forces.lua once MDT ships the season (needs upcomingSeasonID)"
      )
    else
      local lifetime = LoadTool("tools/check_mplus_db_lifetime.lua")
      local code, msg =
        lifetime.Check(nil, { db = section, activeSeasonID = seasonID, requiresForces = true, today = opts.today })
      if code == 0 then
        code, msg = lifetime.CheckStructure(nil, { db = section, activeSeasonID = seasonID })
      end
      Row(code == 0 and "ok" or "fail", "Forces DB section", msg)
    end
  else
    Row("skip", "Forces DB section", "requiresForces = false")
  end

  -- 5. Consumables (expansion set).
  local consumables = data.ConsumableData
  local set = type(consumables) == "table" and consumables.ResolveSet(seasonID) or nil
  Row(
    set and "ok" or "fail",
    "Consumable set",
    FailDetail(set ~= nil, "data/isiLive_consumables.lua has no set for this season (new expansion?)")
  )

  -- 6. TOC interface (optional input).
  if opts.versions then
    local toc = LoadTool("tools/check_toc_interface.lua")
    local versions = {}
    for _, product in ipairs({ "wow", "wowt", "wowxptr", "wow_beta" }) do
      local file = io.open(opts.versions .. "/" .. product .. ".txt", "rb")
      if file then
        versions[product] = toc.ParseVersions(file:read("*a"))
        file:close()
      end
    end
    local tocFile = assert(io.open("isiLive.toc", "rb"))
    local code, report = toc.Evaluate(versions, toc.ParseTocInterfaces(tocFile:read("*a")))
    tocFile:close()
    Row(code == 0 and "ok" or "fail", "TOC interface", FailDetail(code == 0, report:match("%- Missing: ([^\n]+)")))
  else
    Row("skip", "TOC interface", "pass --versions=<dir> (or see the Patch Watch issue)")
  end

  -- 7. Simulator.
  if opts.noSim then
    Row("skip", "wowsim season_smoke", "--no-sim")
  else
    local runSim = opts.runSim
      or function(id, locale)
        local silence = package.config:sub(1, 1) == "\\" and " >nul 2>&1" or " >/dev/null 2>&1"
        return Run(
          string.format("lua tools/wowsim/wowsim.lua season_smoke --season %s --locale %s --quiet", id, locale)
            .. silence
        )
      end
    for _, locale in ipairs({ "enUS", "deDE" }) do
      local ok = runSim(seasonID, locale)
      Row(
        ok and "ok" or "fail",
        "wowsim season_smoke " .. locale,
        FailDetail(
          ok,
          "rerun: lua tools/wowsim/wowsim.lua season_smoke --season " .. seasonID .. " --locale " .. locale
        )
      )
    end
  end

  local failed = 0
  local icon = { ok = "[x]", fail = "[ ]", warn = "[!]", skip = "[-]" }
  local lines = {
    string.format("## Season doctor: %s (%s)", seasonID, isActive and "active" or "prepared"),
    "",
    "Automatic checks:",
  }
  for _, row in ipairs(rows) do
    if row.status == "fail" then
      failed = failed + 1
    end
    lines[#lines + 1] =
      string.format("- %s %s%s", icon[row.status], row.name, row.detail and (": " .. tostring(row.detail)) or "")
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Still to do by hand (docs/SAISON_WECHSEL.md):"
  lines[#lines + 1] = "- [ ] PTR or live client: `/isilive selftest` without MISSING/ERROR rows, `/isilive seasondump`"
  lines[#lines + 1] = "- [ ] In game (enUS and deDE): portal buttons, portal navigator, LFG detection, dungeon names"
  lines[#lines + 1] =
    "- [ ] First key of the season: TTK `evaluated=true`, important-enemy filter on bosses and casters"
  if isActive then
    lines[#lines + 1] = "- [ ] After switching activeSeasonID: only the two reminder tests may fail "
      .. "(forces DB, docs/WARTUNG.md 3.4)"
  else
    lines[#lines + 1] = "- [ ] Release before launch; after launch set activeSeasonID, clear upcomingSeasonID, "
      .. "rerun this doctor"
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = failed == 0 and "- Status: every automatic check passed"
    or string.format("- Status: %d automatic check(s) open", failed)
  return failed == 0 and 0 or 1, table.concat(lines, "\n"), rows
end

function M.Main(argv)
  local args = ParseArgs(argv)
  local code, report = M.Run({ season = args.season, noSim = args.noSim, versions = args.versions })
  io.write(report, "\n")
  return code
end

if ... == "module" then
  return M
end

os.exit(M.Main(arg))
