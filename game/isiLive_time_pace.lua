local _, addonTable = ...

addonTable = addonTable or {}

-- Time pace for the M+ killtracker: is the current key on its way to time?
--
-- Run progress is one number from 0 to 1: half enemy forces, half killed
-- bosses. It does not depend on the kill order, so a run picked up after a
-- reload still reads correctly.
--
-- Two answers, in order of preference:
--   reference  -- the player's own slowest timed run on the same dungeon and
--                 key level (per season). It is the slowest pace that still
--                 made the timer, so being ahead of it means on time. The
--                 answer is elapsed time minus the reference's time at the
--                 same progress (negative = ahead).
--   projection -- without a reference: elapsed time divided by progress,
--                 compared against the key's time limit.
--
-- KillTrack owns every scenario read and hands this module the same
-- validated snapshots it gives ForcesPace. Elapsed time, time limit and key
-- level come from MplusTimer. The only Blizzard call made here is
-- C_ChallengeMode.GetChallengeCompletionInfo at commit time.
--
-- Storage shape:
--   IsiLiveDB.timePace[seasonID][mapID][keyLevel] = {
--     duration = s, times = { s, ... }, progress = { p, ... }, lastSeen = time() }
local TimePace = {}
addonTable.TimePace = TimePace

local FORCES_WEIGHT = 0.5
local BOSS_WEIGHT = 1 - FORCES_WEIGHT
-- A new sample is recorded only when progress grew by at least this much
-- (or a boss died), which keeps a reference run to a few hundred points.
local SAMPLE_MIN_STEP = 0.002
local MAX_SAMPLES = 600
-- Upper bound for persisted key levels per dungeon; the level seen least
-- recently is dropped first.
local MAX_LEVELS_PER_MAP = 30
-- The projection divides by progress, so it is meaningless at the very
-- start of a key.
local PROJECTION_MIN_PROGRESS = 0.05
local PROJECTION_MIN_ELAPSED = 60

local IsFiniteNumber = addonTable.Validators.IsFiniteNumber
local IsSecretValue = addonTable.Validators.IsSecretValue
local ReadPlainNumber = addonTable.Validators.ReadPlainNumber
local ReadPlainBoolean = addonTable.Validators.ReadPlainBoolean

-- Run state for the key currently in progress (nil outside a run).
--   trackedFromStart: run began with CHALLENGE_MODE_START in this session
--   seeded: the first resolved boss list has been seen
--   learnable: no boss was already dead when tracking began
local run = nil

local function IsPositiveInteger(value)
  return IsFiniteNumber(value) and value > 0 and value % 1 == 0
end

local function Round(value, decimals)
  return tonumber(string.format("%." .. decimals .. "f", value))
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

-- Running key timer snapshot from MplusTimer, or nil. GetTimerData guards
-- its own Blizzard read, so it is called directly (no extra pcall on the
-- 0.5 s killtracker path).
local function ReadTimer()
  local timer = addonTable.MplusTimer
  if type(timer) ~= "table" or type(timer.GetTimerData) ~= "function" then
    return nil
  end
  local data = timer.GetTimerData()
  if type(data) ~= "table" or data.running ~= true then
    return nil
  end
  if not IsFiniteNumber(data.timer) or data.timer < 0 then
    return nil
  end
  return data
end

local function NewRun(trackedFromStart)
  return {
    trackedFromStart = trackedFromStart == true,
    seasonID = ResolveSeasonID(),
    mapID = nil,
    keyLevel = nil,
    seeded = false,
    learnable = trackedFromStart == true,
    progress = 0,
    kills = 0,
    times = {},
    samples = {},
  }
end

-- Progress from one snapshot, or nil when forces or bosses are unresolved.
local function ComputeProgress(snapshot)
  if snapshot.percentResolved ~= true or not IsFiniteNumber(snapshot.percent) then
    return nil
  end
  if snapshot.bossesResolved ~= true or type(snapshot.bosses) ~= "table" or #snapshot.bosses == 0 then
    return nil
  end
  local kills = 0
  for i = 1, #snapshot.bosses do
    if snapshot.bosses[i].completed == true then
      kills = kills + 1
    end
  end
  local forces = math.max(0, math.min(snapshot.percent, 100)) / 100
  return FORCES_WEIGHT * forces + BOSS_WEIGHT * (kills / #snapshot.bosses), kills
end

local function AppendSample(elapsed, progress)
  local count = #run.times
  if count >= MAX_SAMPLES then
    return
  end
  local t = math.floor(elapsed + 0.5)
  local p = Round(progress, 4)
  -- Keep both series monotonic: a reference is interpolated by progress.
  if count > 0 and (t < run.times[count] or p <= run.samples[count]) then
    return
  end
  run.times[count + 1] = t
  run.samples[count + 1] = p
end

function TimePace.BeginRun()
  run = NewRun(true)
end

-- Drops the current run without learning (CHALLENGE_MODE_RESET).
function TimePace.DiscardRun()
  run = nil
end

-- Feeds one validated scenario snapshot from KillTrack.
function TimePace.Observe(snapshot)
  if type(snapshot) ~= "table" or not IsPositiveInteger(snapshot.mapID) then
    return
  end
  if run == nil or (run.mapID ~= nil and run.mapID ~= snapshot.mapID) then
    -- No CHALLENGE_MODE_START in this session: compare, but never learn.
    run = NewRun(false)
  end
  run.mapID = snapshot.mapID

  local mplusTimer = addonTable.MplusTimer
  if type(mplusTimer) == "table" and type(mplusTimer.GetKeyLevel) == "function" then
    local keyLevel = mplusTimer.GetKeyLevel()
    if IsPositiveInteger(keyLevel) then
      run.keyLevel = keyLevel
    end
  end

  if not run.seeded and snapshot.bossesResolved == true and type(snapshot.bosses) == "table" then
    if #snapshot.bosses > 0 then
      for i = 1, #snapshot.bosses do
        if snapshot.bosses[i].completed == true then
          run.learnable = false
        end
      end
      run.seeded = true
    end
  end

  local progress, kills = ComputeProgress(snapshot)
  if progress == nil then
    return
  end
  local grew = progress - run.progress >= SAMPLE_MIN_STEP or kills > run.kills
  run.progress = progress
  run.kills = kills
  if grew and run.learnable then
    local timer = ReadTimer()
    if timer then
      AppendSample(timer.timer, progress)
    end
  end
end

local function ReadCompletionInfo()
  local api = rawget(_G, "C_ChallengeMode")
  if type(api) ~= "table" then
    return nil
  end
  local getInfo = rawget(api, "GetChallengeCompletionInfo")
  if type(getInfo) ~= "function" then
    return nil
  end
  local ok, info = pcall(getInfo)
  if not ok or IsSecretValue(info) or type(info) ~= "table" then
    return nil
  end
  return {
    mapID = ReadPlainNumber(info, "mapChallengeModeID"),
    level = ReadPlainNumber(info, "level"),
    time = ReadPlainNumber(info, "time"),
    onTime = ReadPlainBoolean(info, "onTime"),
  }
end

local function IsValidReference(entry)
  if type(entry) ~= "table" or not IsFiniteNumber(entry.duration) or entry.duration <= 0 then
    return false
  end
  local times, progress = entry.times, entry.progress
  if type(times) ~= "table" or type(progress) ~= "table" then
    return false
  end
  local count = #times
  if count < 2 or count ~= #progress or count > MAX_SAMPLES + 1 then
    return false
  end
  local lastT, lastP = -1, -1
  for i = 1, count do
    local t, p = times[i], progress[i]
    if not IsFiniteNumber(t) or not IsFiniteNumber(p) or t < lastT or p <= lastP or p > 1 then
      return false
    end
    lastT, lastP = t, p
  end
  return true
end

local function GetMapLevels(seasonID, mapID, create)
  local db = GetDB()
  if not db or seasonID == nil or not IsPositiveInteger(mapID) then
    return nil
  end
  local root = db.timePace
  if type(root) ~= "table" then
    if not create then
      return nil
    end
    root = {}
    db.timePace = root
  end
  local seasonBucket = root[seasonID]
  if type(seasonBucket) ~= "table" then
    if not create then
      return nil
    end
    seasonBucket = {}
    root[seasonID] = seasonBucket
  end
  local levels = seasonBucket[mapID]
  if type(levels) ~= "table" then
    if not create then
      return nil
    end
    levels = {}
    seasonBucket[mapID] = levels
  end
  return levels
end

local function EnforceLevelCap(levels, keepLevel)
  local count = 0
  for _ in pairs(levels) do
    count = count + 1
  end
  while count > MAX_LEVELS_PER_MAP do
    local dropLevel, dropSeen = nil, nil
    for level, entry in pairs(levels) do
      if level ~= keepLevel then
        local seen = type(entry) == "table" and IsFiniteNumber(entry.lastSeen) and entry.lastSeen or -1
        if dropSeen == nil or seen < dropSeen then
          dropLevel, dropSeen = level, seen
        end
      end
    end
    if dropLevel == nil then
      return
    end
    levels[dropLevel] = nil
    count = count - 1
  end
end

-- Learns the finished run (CHALLENGE_MODE_COMPLETED). Only a timed run
-- tracked from its start, with no boss dead before tracking began, is
-- stored; per dungeon and key level the slowest such run wins. Returns true
-- when the run was stored.
function TimePace.CommitRun()
  local finished = run
  run = nil
  if type(finished) ~= "table" or not finished.trackedFromStart or not finished.learnable or not finished.seeded then
    return false
  end
  if finished.seasonID == nil or not IsPositiveInteger(finished.mapID) or not IsPositiveInteger(finished.keyLevel) then
    return false
  end
  local info = ReadCompletionInfo()
  if not info or info.onTime ~= true or not IsFiniteNumber(info.time) or info.time <= 0 then
    return false
  end
  if info.mapID ~= finished.mapID or info.level ~= finished.keyLevel then
    return false
  end
  local duration = math.floor(info.time / 1000 + 0.5)
  local times, progress = {}, {}
  for i = 1, #finished.times do
    if finished.times[i] <= duration then
      times[#times + 1] = finished.times[i]
      progress[#progress + 1] = math.min(finished.samples[i], 0.9999)
    end
  end
  times[#times + 1] = duration
  progress[#progress + 1] = 1
  local entry = { duration = duration, times = times, progress = progress, lastSeen = Now() }
  if not IsValidReference(entry) then
    return false
  end

  local levels = GetMapLevels(finished.seasonID, finished.mapID, true)
  if not levels then
    return false
  end
  local existing = levels[finished.keyLevel]
  if IsValidReference(existing) and existing.duration >= duration then
    existing.lastSeen = entry.lastSeen
    return false
  end
  levels[finished.keyLevel] = entry
  EnforceLevelCap(levels, finished.keyLevel)
  return true
end

-- Reference time at `progress`: linear between the two samples around it.
local function ReferenceTimeAt(entry, progress)
  local times, samples = entry.times, entry.progress
  if progress <= samples[1] then
    return times[1] * (progress / samples[1])
  end
  for i = 2, #samples do
    if progress <= samples[i] then
      local p0, p1 = samples[i - 1], samples[i]
      local t0, t1 = times[i - 1], times[i]
      return t0 + (t1 - t0) * ((progress - p0) / (p1 - p0))
    end
  end
  return times[#times]
end

-- Pace answer for the current run on `mapID`, or nil:
--   { mode = "reference", delta = s, keyLevel = n }   (delta < 0 = ahead)
--   { mode = "projection", projected = s, timeLimit = s }
function TimePace.GetStatus(mapID)
  if type(run) ~= "table" or not IsPositiveInteger(mapID) or run.mapID ~= mapID then
    return nil
  end
  local progress = run.progress
  if not IsFiniteNumber(progress) or progress <= 0 or progress >= 1 then
    return nil
  end
  local timer = ReadTimer()
  if not timer then
    return nil
  end
  local elapsed = timer.timer
  local keyLevel = IsPositiveInteger(timer.keyLevel) and timer.keyLevel or run.keyLevel

  if run.seasonID ~= nil and IsPositiveInteger(keyLevel) then
    local levels = GetMapLevels(run.seasonID, mapID, false)
    local entry = levels and levels[keyLevel]
    if IsValidReference(entry) then
      return { mode = "reference", delta = elapsed - ReferenceTimeAt(entry, progress), keyLevel = keyLevel }
    end
  end

  if progress < PROJECTION_MIN_PROGRESS or elapsed < PROJECTION_MIN_ELAPSED then
    return nil
  end
  if not IsFiniteNumber(timer.timeLimit) or timer.timeLimit <= 0 then
    return nil
  end
  return { mode = "projection", projected = elapsed / progress, timeLimit = timer.timeLimit }
end

-- Display toggle (default on). Learning continues while the display is off.
function TimePace.IsEnabled()
  local db = GetDB()
  if not db then
    return true
  end
  return db.timePaceEnabled ~= false
end
