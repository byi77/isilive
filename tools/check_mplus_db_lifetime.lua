#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Fails the build when data/isiLive_mplus_forces.lua is past its expiresAt date.
-- The generated DB is a snapshot of MythicDungeonTools' enemy-forces numbers;
-- once the season data drifts, tooltip percentages become misleading. The gate
-- forces us to re-run tools/sync_mdt_forces.lua before releasing.
--
-- Exits 0 when fresh, 1 when expired, 2 on structural/parse errors.
--
-- Env overrides:
--   ISILIVE_ALLOW_STALE_MPLUS_DB=1  Bypass an expired DB (e.g. hotfix releases
--                                   that do not touch the M+ forces feature).
--   ISILIVE_TODAY_OVERRIDE=YYYY-MM-DD  Override "today" for deterministic runs
--                                      (CI replay, regression reproduction).
--   ISILIVE_ACTIVE_SEASON_ID=season_id  Optional active season id; when set,
--                                      the DB's `season` field must match.
--
-- Run from repo root:
--   lua tools/check_mplus_db_lifetime.lua

local DB_PATH = "data/isiLive_mplus_forces.lua"
local SEASON_DATA_PATH = "data/isiLive_seasons.lua"
local ENV_OVERRIDE = "ISILIVE_ALLOW_STALE_MPLUS_DB"

local function today()
  local override = os.getenv("ISILIVE_TODAY_OVERRIDE")
  if override and override ~= "" then
    return override
  end
  return os.date("!%Y-%m-%d")
end

local function parseDate(s)
  if type(s) ~= "string" then
    return nil
  end
  local y, m, d = s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if not y then
    return nil
  end
  return tonumber(y) * 10000 + tonumber(m) * 100 + tonumber(d)
end

local function readActiveSeasonID(path)
  path = path or SEASON_DATA_PATH
  local file = io.open(path, "rb")
  if not file then
    return nil
  end
  local content = file:read("*a") or ""
  file:close()
  return content:match('activeSeasonID%s*=%s*"([^"]+)"')
end

local M = {}

function M.Check(dbPath, opts)
  dbPath = dbPath or DB_PATH
  opts = opts or {}

  local loader, loadErr = loadfile(dbPath)
  if not loader then
    return 2, "cannot load " .. dbPath .. ": " .. tostring(loadErr)
  end

  local addonTable = {}
  local ok, err = pcall(loader, "isiLive", addonTable)
  if not ok then
    return 2, "load error: " .. tostring(err)
  end

  local db = addonTable.MPlusForces
  if type(db) ~= "table" then
    return 2, "addonTable.MPlusForces missing or not a table"
  end

  local activeSeasonID = opts.activeSeasonID
    or os.getenv("ISILIVE_ACTIVE_SEASON_ID")
    or readActiveSeasonID(opts.seasonDataPath)
  if type(activeSeasonID) == "string" and activeSeasonID ~= "" and db.season ~= activeSeasonID then
    return 2,
      string.format(
        "M+ forces DB season mismatch: active season is %s but DB season is %s",
        tostring(activeSeasonID),
        tostring(db.season)
      )
  end

  local expiresAt = db.expiresAt
  local expiresKey = parseDate(expiresAt)
  if not expiresKey then
    return 2, "expiresAt missing or malformed (expected YYYY-MM-DD, got " .. tostring(expiresAt) .. ")"
  end

  local todayStr = opts.today or today()
  local todayKey = parseDate(todayStr)
  if not todayKey then
    return 2, "today override malformed (expected YYYY-MM-DD, got " .. tostring(todayStr) .. ")"
  end

  if todayKey <= expiresKey then
    return 0, string.format("M+ forces DB valid until %s (today %s)", expiresAt, todayStr)
  end

  local override = opts.override
  if override == nil then
    override = os.getenv(ENV_OVERRIDE)
  end
  if override == "1" then
    return 0,
      string.format("M+ forces DB expired on %s (today %s) — bypassed via %s=1", expiresAt, todayStr, ENV_OVERRIDE)
  end

  return 1,
    string.format(
      "M+ forces DB expired on %s (today %s). Re-run tools/sync_mdt_forces.lua or set %s=1 to bypass.",
      expiresAt,
      todayStr,
      ENV_OVERRIDE
    )
end

if ... == nil then
  local code, msg = M.Check()
  if code == 0 then
    io.stdout:write(msg .. "\n")
  else
    io.stderr:write("mplus_db_lifetime: " .. msg .. "\n")
  end
  os.exit(code)
end

return M
