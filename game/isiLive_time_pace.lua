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
--                 key level (per season). The gap to it at the same progress
--                 carries over to its finish time, which gives the forecast;
--                 the answer is that forecast against the key's time limit
--                 (negative = on time). Being behind a reference that beat the
--                 limit by minutes is not late.
--   projection -- without a reference: the median of up to three finish-time
--                 estimates (of an even count, the mean of the middle two),
--                 compared against the key's time limit:
--                   whole run: elapsed / progress.
--                   rolling tempo: the rest of the key at the tempo of the
--                     last 240 s. Needs 120 s of covered history and progress
--                     inside it; kept for every run, also after a reload.
--                   curve: elapsed / curve share at this progress, from the
--                     dungeon's time curve in data/isiLive_time_seed.lua.
--                 The median keeps one estimate going wild out of the answer.
--
-- During a pull the clock runs while progress only moves on kills, so the
-- answer drifts towards late and snaps back when mobs die. KillTrack
-- therefore pauses the shown answer for each fight in the key: PauseStatus
-- freezes the answer at the pull and ResumeStatus releases it once the
-- kills of the pull are counted. Learning keeps the real timer throughout.
--
-- Trace: while the runtime log is on, a `[TIMEPACE]` line records every
-- estimate (whole / rolling / curve / reference), the progress split and the
-- shown verdict at pull start, pull end, boss kill, verdict change and run
-- end, never per tick. It only reads; the shown answer is the same with the
-- trace on or off.
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
-- Before the first kills the clock runs at progress zero, and the projection
-- divides by progress: no answer says anything at the very start of a key.
local PACE_MIN_PROGRESS = 0.05
local PACE_MIN_ELAPSED = 60
-- Rolling tempo: the window it looks back over and the history it needs.
local ROLLING_WINDOW = 240
local ROLLING_MIN_COVERAGE = 120
-- A forecast within this many seconds of the limit, either side, is "tight":
-- the forecast is not precise enough to call it on time or late.
local TIGHT_SECONDS = 30
-- Shown verdict (C3, calibrated on the logged +14 of 2026-11-12, whose
-- forecast moved up to ~230 s between two pulls): the word changes only at a
-- checkpoint (pull end, boss kill) and only when the forecast lies this far
-- past the boundary it crosses -- a 60 s buffer around each boundary.
local VERDICT_HYSTERESIS = 30

local IsFiniteNumber = addonTable.Validators.IsFiniteNumber
local IsSecretValue = addonTable.Validators.IsSecretValue
local ReadPlainNumber = addonTable.Validators.ReadPlainNumber
local ReadPlainBoolean = addonTable.Validators.ReadPlainBoolean

-- Run state for the key currently in progress (nil outside a run).
--   trackedFromStart: run began with CHALLENGE_MODE_START in this session
--   seeded: the first resolved boss list has been seen
--   learnable: no boss was already dead when tracking began
---@class IsiLiveTimePaceRun
---@field trackedFromStart boolean
---@field seasonID number|nil
---@field mapID number|nil
---@field keyLevel number|nil
---@field seeded boolean
---@field learnable boolean
---@field progress number
---@field sampleProgress number
---@field kills number
---@field forces number|nil forces percent of the last resolved snapshot
---@field bossTotal number|nil boss count of the last resolved snapshot
---@field times number[]
---@field samples number[]
---@field recentMark number
---@field recentTimes number[]
---@field recentSamples number[]

-- Typed non-optional on purpose: an optional type would flag every field read
-- in the sample helpers, which only run while a run exists. The two resets
-- that clear it suppress the resulting cast warning on their own line.
---@type IsiLiveTimePaceRun
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

---@return IsiLiveTimePaceRun
local function NewRun(trackedFromStart)
  return {
    trackedFromStart = trackedFromStart == true,
    seasonID = ResolveSeasonID(),
    mapID = nil,
    keyLevel = nil,
    seeded = false,
    learnable = trackedFromStart == true,
    progress = 0,
    sampleProgress = 0,
    kills = 0,
    times = {},
    samples = {},
    -- Rolling history of the last ROLLING_WINDOW seconds, kept for every run.
    recentMark = 0,
    recentTimes = {},
    recentSamples = {},
  }
end

-- Answer frozen by PauseStatus while a fight in the key runs. `active` is
-- separate from `status` because the frozen answer may be nil.
local paused = { active = false, status = nil }

local function ClearPause()
  paused.active = false
  paused.status = nil
end

-- [TIMEPACE] trace sink (SetTraceLogger) and the verdict of the answer shown
-- last, so a change of the shown word is traced once. TraceStatus is
-- assigned below ComputeStatus, which it reads.
local traceFn, traceActive = nil, nil
local lastVerdict = "none"
-- Verdict the badge shows ("ontime", "tight", "late"), nil until the first
-- answer of the run.
local shownVerdict = nil
local TraceStatus
-- Assigned below ComputeStatus as well: Observe runs the boss checkpoint.
local WithVerdict
local VerdictCheckpoint

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
  local percent = math.max(0, math.min(snapshot.percent, 100))
  local total = #snapshot.bosses
  return FORCES_WEIGHT * percent / 100 + BOSS_WEIGHT * (kills / total), kills, percent, total
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
  run.sampleProgress = progress
end

-- Unlike AppendSample this also runs for a run that never learns.
local function AppendRecent(elapsed, progress)
  local times, samples = run.recentTimes, run.recentSamples
  local count = #times
  if count > 0 and elapsed < times[count] then
    return
  end
  times[count + 1] = elapsed
  samples[count + 1] = progress
  run.recentMark = progress
  local oldest = elapsed - ROLLING_WINDOW
  while #times > MAX_SAMPLES or times[1] < oldest do
    table.remove(times, 1)
    table.remove(samples, 1)
  end
end

local function RecordProgress(progress, kills)
  local bossDied = kills > run.kills
  local grew = run.learnable and (progress - run.sampleProgress >= SAMPLE_MIN_STEP or bossDied)
  local grewRecent = progress - run.recentMark >= SAMPLE_MIN_STEP or bossDied
  run.progress = progress
  run.kills = kills
  if not grew and not grewRecent then
    return
  end
  local timer = ReadTimer()
  if not timer then
    return
  end
  if grew then
    AppendSample(timer.timer, progress)
  end
  if grewRecent then
    AppendRecent(timer.timer, progress)
  end
end

local function IsTraceOn()
  return traceFn ~= nil and (traceActive == nil or traceActive() == true)
end

-- One line for a run boundary: start, discard or end with the learn result.
local function TraceRunEvent(reason, target, stored)
  if not IsTraceOn() then
    return
  end
  traceFn(function()
    if type(target) ~= "table" then
      return string.format("[TIMEPACE] reason=%s run=none", reason)
    end
    return string.format(
      "[TIMEPACE] reason=%s mapID=%s key=%s tracked=%s learnable=%s seeded=%s samples=%d stored=%s",
      reason,
      tostring(target.mapID),
      tostring(target.keyLevel),
      tostring(target.trackedFromStart),
      tostring(target.learnable),
      tostring(target.seeded),
      #target.times,
      tostring(stored)
    )
  end)
end

function TimePace.BeginRun()
  run = NewRun(true)
  ClearPause()
  lastVerdict = "none"
  shownVerdict = nil
  TraceRunEvent("run_start", run, nil)
end

-- Drops the current run without learning (CHALLENGE_MODE_RESET).
function TimePace.DiscardRun()
  local dropped = run
  run = nil ---@diagnostic disable-line: cast-local-type
  ClearPause()
  lastVerdict = "none"
  shownVerdict = nil
  TraceRunEvent("run_discard", dropped, false)
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

  local progress, kills, percent, total = ComputeProgress(snapshot)
  if progress == nil then
    return
  end
  local bossDied = kills > run.kills
  run.forces = percent
  run.bossTotal = total
  RecordProgress(progress, kills)
  if bossDied then
    -- Checkpoint: a boss kill may change the verdict.
    VerdictCheckpoint()
    TraceStatus("boss")
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
local function StoreFinishedRun(finished)
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

function TimePace.CommitRun()
  local finished = run
  run = nil ---@diagnostic disable-line: cast-local-type
  ClearPause()
  lastVerdict = "none"
  shownVerdict = nil
  local stored = StoreFinishedRun(finished)
  TraceRunEvent("run_end", finished, stored)
  return stored
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

-- Time curve of a dungeon as a reference entry with a duration of 1, or nil.
local function GetSeedCurve(seasonID, mapID)
  local seed = addonTable.TimeSeed
  local seasonBucket = type(seed) == "table" and seed[seasonID] or nil
  if type(seasonBucket) ~= "table" then
    return nil
  end
  local entry = { duration = 1, times = seasonBucket[mapID], progress = seasonBucket.progress }
  return IsValidReference(entry) and entry or nil
end

-- Finish time at the tempo of the last ROLLING_WINDOW seconds, or nil.
local function EstimateRollingFinish(elapsed, progress)
  local times, samples = run.recentTimes, run.recentSamples
  local oldest = elapsed - ROLLING_WINDOW
  for i = 1, #times do
    if times[i] >= oldest then
      local dt = elapsed - times[i]
      local dp = progress - samples[i]
      if dt < ROLLING_MIN_COVERAGE or dp <= 0 then
        return nil
      end
      return elapsed + (1 - progress) * dt / dp
    end
  end
  return nil
end

-- Finish time from the dungeon's time curve, or nil.
local function EstimateCurveFinish(mapID, elapsed, progress)
  local curve = run.seasonID ~= nil and GetSeedCurve(run.seasonID, mapID) or nil
  if not curve then
    return nil
  end
  local share = ReferenceTimeAt(curve, progress)
  if share <= 0 then
    return nil
  end
  return elapsed / share
end

local function Median(values)
  table.sort(values)
  local count = #values
  local middle = math.floor((count + 1) / 2)
  if count % 2 == 1 then
    return values[middle]
  end
  return (values[middle] + values[middle + 1]) / 2
end

local function EstimateFinish(mapID, elapsed, progress)
  local estimates = { elapsed / progress }
  estimates[#estimates + 1] = EstimateRollingFinish(elapsed, progress)
  estimates[#estimates + 1] = EstimateCurveFinish(mapID, elapsed, progress)
  return Median(estimates)
end

local function ComputeStatus(mapID)
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
  if progress < PACE_MIN_PROGRESS or elapsed < PACE_MIN_ELAPSED then
    return nil
  end
  if not IsFiniteNumber(timer.timeLimit) or timer.timeLimit <= 0 then
    return nil
  end

  if run.seasonID ~= nil and IsPositiveInteger(keyLevel) then
    local levels = GetMapLevels(run.seasonID, mapID, false)
    local entry = levels and levels[keyLevel]
    if IsValidReference(entry) then
      local forecast = entry.duration + elapsed - ReferenceTimeAt(entry, progress)
      return { mode = "reference", delta = forecast - timer.timeLimit, keyLevel = keyLevel }
    end
  end

  return { mode = "projection", projected = EstimateFinish(mapID, elapsed, progress), timeLimit = timer.timeLimit }
end

-- Shown state of a forecast `delta` seconds past the limit (negative =
-- ahead): "tight" within TIGHT_SECONDS either side, in whole seconds, so a
-- forecast exactly on the limit is tight; otherwise "ontime" or "late".
function TimePace.ClassifyDelta(delta)
  local seconds = math.floor(math.abs(delta) + 0.5)
  if seconds <= TIGHT_SECONDS then
    return "tight"
  elseif delta < 0 then
    return "ontime"
  end
  return "late"
end

-- Forecast minus time limit of a status, or nil.
local function StatusDelta(status)
  if type(status) ~= "table" then
    return nil
  end
  local delta = nil
  if status.mode == "reference" then
    delta = status.delta
  elseif status.mode == "projection" and IsFiniteNumber(status.projected) and IsFiniteNumber(status.timeLimit) then
    delta = status.projected - status.timeLimit
  end
  return IsFiniteNumber(delta) and delta or nil
end

local function VerdictOf(status)
  local delta = StatusDelta(status)
  return delta and TimePace.ClassifyDelta(delta) or "none"
end

-- True when `delta` lies VERDICT_HYSTERESIS past the boundary between the
-- shown verdict and `target`.
local function ClearsBoundary(delta, target)
  if target == "ontime" then
    return delta <= -TIGHT_SECONDS - VERDICT_HYSTERESIS
  elseif target == "late" then
    return delta >= TIGHT_SECONDS + VERDICT_HYSTERESIS
  elseif shownVerdict == "ontime" then
    return delta >= -TIGHT_SECONDS + VERDICT_HYSTERESIS
  end
  return delta <= TIGHT_SECONDS - VERDICT_HYSTERESIS
end

-- Forces done and only the last boss left: progress cannot move until the
-- kill, so the forecast drifts late with every second of the fight (the
-- logged +14 drifted ~3 min). The word holds until that boss dies.
local function IsLastBossHold()
  return IsFiniteNumber(run.forces)
    and run.forces >= 100
    and IsPositiveInteger(run.bossTotal)
    and run.kills == run.bossTotal - 1
end

-- The verdict the badge shows for `status`. The first answer of a run sets
-- it; afterwards it changes only at a checkpoint, outside the last-boss
-- hold, and only past the hysteresis.
local function ResolveVerdict(status, checkpoint)
  local delta = StatusDelta(status)
  if not delta then
    return shownVerdict
  end
  local candidate = TimePace.ClassifyDelta(delta)
  if shownVerdict == nil then
    shownVerdict = candidate
  elseif checkpoint and candidate ~= shownVerdict and not IsLastBossHold() and ClearsBoundary(delta, candidate) then
    shownVerdict = candidate
  end
  return shownVerdict
end

-- Checkpoint (pull end, boss kill): the verdict of the live answer may change.
VerdictCheckpoint = function()
  if type(run) == "table" and IsPositiveInteger(run.mapID) then
    WithVerdict(ComputeStatus(run.mapID), true)
  end
end

-- A status with the verdict the badge shows (nil stays nil).
WithVerdict = function(status, checkpoint)
  if type(status) == "table" then
    status.verdict = ResolveVerdict(status, checkpoint)
  end
  return status
end

local function FormatSeconds(value)
  return IsFiniteNumber(value) and string.format("%.0f", value) or "nil"
end

-- Builds the [TIMEPACE] line for the live answer. Every projection estimate
-- is written in both modes, so a log shows which one jumps.
local function BuildTraceLine(reason, status)
  local timer = ReadTimer()
  local elapsed = timer and timer.timer or nil
  local progress = run.progress
  local whole, rolling, curve = nil, nil, nil
  if IsFiniteNumber(elapsed) and IsFiniteNumber(progress) and progress > 0 then
    whole = elapsed / progress
    rolling = EstimateRollingFinish(elapsed, progress)
    curve = IsPositiveInteger(run.mapID) and EstimateCurveFinish(run.mapID, elapsed, progress) or nil
  end
  local delta = StatusDelta(status)
  local limit = timer and timer.timeLimit or nil
  return string.format(
    "[TIMEPACE] reason=%s mode=%s verdict=%s shown=%s gap=%s forecast=%s limit=%s elapsed=%s progress=%s "
      .. "forces=%s bosses=%s/%s whole=%s rolling=%s curve=%s paused=%s key=%s learn=%s",
    reason,
    type(status) == "table" and tostring(status.mode) or "none",
    VerdictOf(status),
    tostring(shownVerdict or "none"),
    delta and string.format("%+.0f", delta) or "nil",
    (delta and IsFiniteNumber(limit)) and FormatSeconds(limit + delta) or "nil",
    FormatSeconds(limit),
    FormatSeconds(elapsed),
    IsFiniteNumber(progress) and string.format("%.4f", progress) or "nil",
    IsFiniteNumber(run.forces) and string.format("%.1f", run.forces) or "nil",
    tostring(run.kills),
    tostring(run.bossTotal),
    FormatSeconds(whole),
    FormatSeconds(rolling),
    FormatSeconds(curve),
    tostring(paused.active),
    tostring(run.keyLevel),
    tostring(run.learnable)
  )
end

-- Traces the live answer. Outside a pause it is also the shown one, whose
-- verdict then becomes the baseline for the next change.
TraceStatus = function(reason)
  if not IsTraceOn() or type(run) ~= "table" or not IsPositiveInteger(run.mapID) then
    return
  end
  local status = ComputeStatus(run.mapID)
  if not paused.active then
    lastVerdict = VerdictOf(status)
  end
  traceFn(function()
    return BuildTraceLine(reason, status)
  end)
end

--- Sets the runtime-log sink for the [TIMEPACE] trace.
-- @param fn function|nil Receives a lazy builder function (RuntimeLog.Trace). nil disables it.
-- @param isActive function|nil When it returns false nothing is built.
function TimePace.SetTraceLogger(fn, isActive)
  traceFn = type(fn) == "function" and fn or nil
  traceActive = type(isActive) == "function" and isActive or nil
  lastVerdict = "none"
end

-- Pace answer for the current run on `mapID`, or nil:
--   { mode = "reference", delta = s, keyLevel = n }   (delta < 0 = ahead)
--   { mode = "projection", projected = s, timeLimit = s }
-- While paused, the answer frozen at the pull with `paused = true`.
function TimePace.GetStatus(mapID)
  if type(run) ~= "table" or not IsPositiveInteger(mapID) or run.mapID ~= mapID then
    return nil
  end
  if paused.active then
    return paused.status
  end
  local status = WithVerdict(ComputeStatus(mapID), false)
  if IsTraceOn() and VerdictOf(status) ~= lastVerdict then
    TraceStatus("verdict")
  end
  return status
end

-- Freezes the shown answer at the start of a fight (PLAYER_REGEN_DISABLED).
-- A pull inside the post-combat grace window freezes again with the
-- progress the previous pull reached.
function TimePace.PauseStatus()
  ClearPause()
  if type(run) ~= "table" or not IsPositiveInteger(run.mapID) then
    return
  end
  -- Traced before freezing: the frozen answer is the live one at the pull.
  TraceStatus("pull_start")
  local status = WithVerdict(ComputeStatus(run.mapID), false)
  if status then
    status.paused = true
  end
  paused.active = true
  paused.status = status
end

-- Releases the frozen answer once the fight's kills are counted.
function TimePace.ResumeStatus()
  local wasPaused = paused.active
  ClearPause()
  if wasPaused then
    -- Checkpoint: the pull's kills are counted, the verdict may change.
    VerdictCheckpoint()
    TraceStatus("pull_end")
  end
end

function TimePace.IsStatusPaused()
  return paused.active
end

-- Display toggle (default on). Learning continues while the display is off.
function TimePace.IsEnabled()
  local db = GetDB()
  if not db then
    return true
  end
  return db.timePaceEnabled ~= false
end
