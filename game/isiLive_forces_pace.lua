local _, addonTable = ...

addonTable = addonTable or {}

-- Forces pace for the M+ killtracker.
--
-- Learns, per dungeon and boss kill order, the enemy-forces percentage the
-- player's own completed runs had banked when each boss died, and answers
-- which forces percentage the current run should reach before the next boss.
--
-- KillTrack owns every scenario read and hands this module already validated
-- snapshots ({ mapID, percent, percentResolved, bosses, bossesResolved }).
-- This module never calls a Blizzard scenario API itself.
--
-- Boss identity is the scenario criteria index: it is stable per dungeon
-- regardless of the order in which the bosses die, so a kill order is the
-- list of criteria indices in death order ("route"). Storage shape:
--   IsiLiveDB.forcesPace[seasonID][mapID].routes[routeKey] = {
--     order = { idx, ... }, checkpoints = { pct, ... },
--     leanScore = n, runs = n, lastSeen = time() }
local ForcesPace = {}
addonTable.ForcesPace = ForcesPace

local ROUTE_KEY_SEPARATOR = "-"
-- Upper bound for persisted routes per dungeon. A dungeon has a handful of
-- sensible kill orders; when a new route would exceed the cap, the route that
-- was seen least recently is dropped.
local MAX_ROUTES_PER_MAP = 24
-- No dungeon has anywhere near this many boss criteria; longer persisted
-- orders are treated as corrupt.
local MAX_BOSSES = 32

-- Run state for the key currently in progress (nil outside a run).
--   trackedFromStart: run began with CHALLENGE_MODE_START in this session
--   seeded: the first resolved boss list has been seen
--   learnable: no boss was already dead when tracking began
--   orderComplete: the kill order covers every dead boss (no seeded kills)
local run = nil

local function IsFiniteNumber(value)
  return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function RoundOne(value)
  return tonumber(string.format("%.1f", value))
end

local function Now()
  local timeFn = rawget(_G, "time")
  if type(timeFn) == "function" then
    local ok, value = pcall(timeFn)
    if ok and IsFiniteNumber(value) then
      return value
    end
  end
  return nil
end

-- Season scoping keeps routes of different seasons apart. An unresolved
-- season disables learning and display (fail closed).
local function ResolveSeasonID()
  local seasonData = addonTable.SeasonData
  if type(seasonData) ~= "table" or type(seasonData.GetActiveSeasonID) ~= "function" then
    return nil
  end
  local ok, seasonID = pcall(seasonData.GetActiveSeasonID)
  if not ok then
    return nil
  end
  if type(seasonID) == "string" and seasonID ~= "" then
    return seasonID
  end
  if IsFiniteNumber(seasonID) and seasonID > 0 then
    return seasonID
  end
  return nil
end

local function GetDB()
  local db = rawget(_G, "IsiLiveDB")
  if type(db) == "table" then
    return db
  end
  return nil
end

local function NewRun(trackedFromStart)
  return {
    trackedFromStart = trackedFromStart == true,
    seasonID = ResolveSeasonID(),
    mapID = nil,
    seeded = false,
    learnable = trackedFromStart == true,
    orderComplete = true,
    seen = {},
    order = {},
    checkpoints = {},
    totalBosses = 0,
  }
end

local function IsPositiveInteger(value)
  return IsFiniteNumber(value) and value > 0 and value % 1 == 0
end

-- Persisted data is user-editable and may come from older builds: every
-- field is checked before use, and a route that fails any check is ignored.
local function IsValidRoute(routeKey, route)
  if type(routeKey) ~= "string" or type(route) ~= "table" then
    return false
  end
  local order = route.order
  local checkpoints = route.checkpoints
  if type(order) ~= "table" or type(checkpoints) ~= "table" then
    return false
  end
  local count = #order
  if count < 1 or count > MAX_BOSSES or #checkpoints ~= count then
    return false
  end
  local seen = {}
  for i = 1, count do
    local index = order[i]
    if not IsPositiveInteger(index) or seen[index] then
      return false
    end
    seen[index] = true
    local checkpoint = checkpoints[i]
    if not IsFiniteNumber(checkpoint) or checkpoint < 0 or checkpoint > 100 then
      return false
    end
  end
  if table.concat(order, ROUTE_KEY_SEPARATOR) ~= routeKey then
    return false
  end
  return IsFiniteNumber(route.leanScore)
end

-- Returns the routes table for one season + dungeon. With `create`, missing
-- or malformed buckets on the path are (re)built; without it, nil is returned
-- whenever any level is missing or malformed.
local function GetMapRoutes(seasonID, mapID, create)
  local db = GetDB()
  if not db or seasonID == nil or not IsPositiveInteger(mapID) then
    return nil
  end
  local root = db.forcesPace
  if type(root) ~= "table" then
    if not create then
      return nil
    end
    root = {}
    db.forcesPace = root
  end
  local seasonBucket = root[seasonID]
  if type(seasonBucket) ~= "table" then
    if not create then
      return nil
    end
    seasonBucket = {}
    root[seasonID] = seasonBucket
  end
  local mapBucket = seasonBucket[mapID]
  if type(mapBucket) ~= "table" or type(mapBucket.routes) ~= "table" then
    if not create then
      return nil
    end
    mapBucket = { routes = {} }
    seasonBucket[mapID] = mapBucket
  end
  return mapBucket.routes
end

local function EnforceRouteCap(routes, keepKey)
  local count = 0
  for _ in pairs(routes) do
    count = count + 1
  end
  while count > MAX_ROUTES_PER_MAP do
    local evictKey, evictSeen = nil, nil
    for key, route in pairs(routes) do
      if key ~= keepKey then
        -- Malformed entries go first; among valid ones the oldest lastSeen.
        local seenAt = IsValidRoute(key, route) and IsFiniteNumber(route.lastSeen) and route.lastSeen or -math.huge
        if evictKey == nil or seenAt < evictSeen then
          evictKey, evictSeen = key, seenAt
        end
      end
    end
    if evictKey == nil then
      return
    end
    routes[evictKey] = nil
    count = count - 1
  end
end

local function RouteStartsWith(route, prefix)
  for i = 1, #prefix do
    if route.order[i] ~= prefix[i] then
      return false
    end
  end
  return true
end

-- Starts tracking a fresh run. Called by KillTrack on CHALLENGE_MODE_START
-- before the first scenario read of that run.
function ForcesPace.BeginRun()
  run = NewRun(true)
end

-- Drops the current run without learning (CHALLENGE_MODE_RESET).
function ForcesPace.DiscardRun()
  run = nil
end

-- Feeds one validated scenario snapshot from KillTrack. Boss kills are
-- detected by criteria index in index order; each new kill records the
-- current forces percentage with one decimal.
function ForcesPace.Observe(snapshot)
  if type(snapshot) ~= "table" or not IsPositiveInteger(snapshot.mapID) then
    return
  end
  if run == nil or (run.mapID ~= nil and run.mapID ~= snapshot.mapID) then
    -- No CHALLENGE_MODE_START was seen for this key (reload mid-run, addon
    -- enabled late, or another dungeon): track it, but never learn from it.
    run = NewRun(false)
  end
  if run.mapID == nil then
    run.mapID = snapshot.mapID
  end
  if snapshot.bossesResolved ~= true or type(snapshot.bosses) ~= "table" then
    return
  end
  local bosses = snapshot.bosses
  if #bosses == 0 then
    return
  end
  run.totalBosses = #bosses

  if not run.seeded then
    -- Bosses already dead when tracking begins cannot be placed in the kill
    -- order: they are marked as seen, and the run neither learns nor shows a
    -- pace target.
    for i = 1, #bosses do
      local boss = bosses[i]
      if boss.completed == true then
        run.seen[boss.index] = true
        run.learnable = false
        run.orderComplete = false
      end
    end
    run.seeded = true
    return
  end

  if snapshot.percentResolved ~= true or not IsFiniteNumber(snapshot.percent) then
    return
  end
  local percent = RoundOne(math.max(0, math.min(snapshot.percent, 100)))
  for i = 1, #bosses do
    local boss = bosses[i]
    if boss.completed == true and not run.seen[boss.index] then
      run.seen[boss.index] = true
      local position = #run.order + 1
      run.order[position] = boss.index
      run.checkpoints[position] = percent
    end
  end
end

-- Learns the finished run (CHALLENGE_MODE_COMPLETED). Only a run tracked
-- from its start with every boss captured in order is stored. Per route the
-- leanest run (lowest sum of checkpoints) wins; every committed run bumps the
-- route's run counter. Returns true when the run was committed.
function ForcesPace.CommitRun()
  local finished = run
  run = nil
  if type(finished) ~= "table" or not finished.trackedFromStart or not finished.learnable or not finished.seeded then
    return false
  end
  local total = finished.totalBosses
  if not IsPositiveInteger(total) or #finished.order ~= total then
    return false
  end
  local score = 0
  local order, checkpoints = {}, {}
  for i = 1, total do
    local index = finished.order[i]
    local checkpoint = finished.checkpoints[i]
    if not IsPositiveInteger(index) or not IsFiniteNumber(checkpoint) then
      return false
    end
    order[i] = index
    checkpoints[i] = checkpoint
    score = score + checkpoint
  end
  score = RoundOne(score)

  local routes = GetMapRoutes(finished.seasonID, finished.mapID, true)
  if not routes then
    return false
  end
  local routeKey = table.concat(order, ROUTE_KEY_SEPARATOR)
  local existing = routes[routeKey]
  local existingValid = IsValidRoute(routeKey, existing)
  local previousRuns = existingValid and IsPositiveInteger(existing.runs) and existing.runs or 0
  local now = Now()
  if not existingValid or score < existing.leanScore then
    routes[routeKey] = {
      order = order,
      checkpoints = checkpoints,
      leanScore = score,
      runs = previousRuns + 1,
      lastSeen = now,
    }
  else
    existing.runs = previousRuns + 1
    existing.lastSeen = now
  end
  EnforceRouteCap(routes, routeKey)
  return true
end

-- Target forces percentage for the next boss of the current run on `mapID`:
-- the minimum checkpoint at the next kill position across all stored routes
-- of the current season and dungeon whose kill order starts with the current
-- kill order. nil when nothing verified is known.
function ForcesPace.GetPaceTarget(mapID)
  if type(run) ~= "table" or not run.seeded or not run.orderComplete then
    return nil
  end
  if not IsPositiveInteger(mapID) or run.mapID ~= mapID or run.seasonID == nil then
    return nil
  end
  local total = run.totalBosses
  local kills = #run.order
  if not IsPositiveInteger(total) or kills >= total then
    return nil
  end
  local routes = GetMapRoutes(run.seasonID, mapID, false)
  if not routes then
    return nil
  end
  local nextPosition = kills + 1
  local target = nil
  for routeKey, route in pairs(routes) do
    if IsValidRoute(routeKey, route) and #route.order == total and RouteStartsWith(route, run.order) then
      local checkpoint = route.checkpoints[nextPosition]
      if target == nil or checkpoint < target then
        target = checkpoint
      end
    end
  end
  return target
end

-- Display toggle (default on). Learning continues while the display is off,
-- so turning it back on uses every run completed in the meantime.
function ForcesPace.IsEnabled()
  local db = GetDB()
  if not db then
    return true
  end
  return db.forcesPaceEnabled ~= false
end
