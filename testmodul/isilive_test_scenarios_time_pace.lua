---@diagnostic disable: undefined-global

-- Time pace for the M+ killtracker (rule 208).
--
-- End-to-end through the real modules: KillTrack reads the scenario criteria
-- stubs and hands its snapshots to the real TimePace, which reads elapsed
-- time, time limit and key level from the real MplusTimer and learns into a
-- real IsiLiveDB table; the kill row renders whatever the real
-- KillTrack.GetData() returns. Events enter through the modules' HandleEvent
-- entry points, the ones the controller wiring dispatches to.

local helpersChunk, helpersErr = loadfile("testmodul/isilive_test_ui_helpers.lua")
if not helpersChunk then
  error("cannot load UI helpers: " .. tostring(helpersErr))
end
local helpers = helpersChunk()
local BuildCreateFrameStub = helpers.BuildCreateFrameStub

local MAP_ID = 2649
local TIME_LIMIT = 1800
local KEY_LEVEL = 10

local function BuildEnv(opts)
  opts = opts or {}
  local env = {
    db = opts.db or {},
    clock = 5000,
    elapsed = 0,
    keyLevel = opts.keyLevel or KEY_LEVEL,
    bosses = {},
    forces = { isWeightedProgress = true, criteriaID = 9001, totalQuantity = 300, quantity = 0, completed = false },
    completion = nil,
    -- C_Timer.After callbacks (KillTrack's post-combat grace window).
    timers = {},
  }
  for i = 1, 3 do
    env.bosses[i] = { isWeightedProgress = false, completed = false, criteriaID = 100 + i }
  end
  local function List()
    local list = {}
    for _, boss in ipairs(env.bosses) do
      list[#list + 1] = boss
    end
    list[#list + 1] = env.forces
    return list
  end
  env.globals = {
    C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        return MAP_ID
      end,
      GetActiveKeystoneInfo = function()
        return env.keyLevel, {}, 0
      end,
      GetMapUIInfo = function()
        return "Dungeon", 1, TIME_LIMIT
      end,
      GetDeathCount = function()
        return 0, 0
      end,
      GetChallengeCompletionInfo = function()
        return env.completion
      end,
    },
    C_ScenarioInfo = {
      GetScenarioStepInfo = function()
        return { numCriteria = #List() }
      end,
      GetCriteriaInfo = function(i)
        return List()[i]
      end,
    },
    C_Timer = {
      After = function(_, fn)
        env.timers[#env.timers + 1] = fn
      end,
      NewTicker = function()
        return { Cancel = function() end }
      end,
    },
    GetWorldElapsedTime = function()
      return 1, env.elapsed
    end,
    GetTime = function()
      return 1000
    end,
    time = function()
      return env.clock
    end,
    IsiLiveDB = env.db,
  }
  return env
end

local function Load(LoadAddonModules, extraFiles)
  local files = { "isiLive_season_data.lua", "isiLive_mplus_timer.lua", "isiLive_killtrack.lua" }
  for _, file in ipairs(extraFiles or {}) do
    files[#files + 1] = file
  end
  return LoadAddonModules(files)
end

local function Dispatch(addon, event)
  addon.MplusTimer.HandleEvent(event)
  addon.KillTrack.HandleEvent(event)
end

local function StartRun(addon, env)
  for _, boss in ipairs(env.bosses) do
    boss.completed = false
  end
  env.forces.quantity = 0
  env.elapsed = 0
  Dispatch(addon, "CHALLENGE_MODE_START")
end

-- Moves the run to `elapsed` seconds with `forces` of 300 and `kills` bosses.
local function Advance(addon, env, elapsed, forces, kills)
  env.elapsed = elapsed
  env.forces.quantity = forces
  for i = 1, #env.bosses do
    env.bosses[i].completed = i <= kills
  end
  Dispatch(addon, "SCENARIO_CRITERIA_UPDATE")
end

-- A full run reaching 100% forces and all three bosses at `duration`.
local function PlayRun(addon, env, duration, onTime, level)
  StartRun(addon, env)
  Advance(addon, env, duration * 0.25, 75, 1)
  Advance(addon, env, duration * 0.5, 150, 1)
  Advance(addon, env, duration * 0.75, 225, 2)
  Advance(addon, env, duration, 300, 3)
  env.completion = {
    mapChallengeModeID = MAP_ID,
    level = level or env.keyLevel,
    time = duration * 1000,
    onTime = onTime ~= false,
  }
  Dispatch(addon, "CHALLENGE_MODE_COMPLETED")
end

-- Fires the pending C_Timer.After callbacks, i.e. lets the grace window end.
local function RunTimers(env)
  local pending = env.timers
  env.timers = {}
  for _, fn in ipairs(pending) do
    fn()
  end
end

local function GetReference(addon, db, level)
  local root = db.timePace
  local seasonBucket = type(root) == "table" and root[addon.SeasonData.GetActiveSeasonID()] or nil
  local levels = type(seasonBucket) == "table" and seasonBucket[MAP_ID] or nil
  return type(levels) == "table" and levels[level or KEY_LEVEL] or nil
end

local function NewTextStub()
  local fs = { _text = "" }
  function fs.SetText(self, text)
    self._text = text
  end
  function fs.SetTextColor(self, r, g, b)
    self._color = { r, g, b }
  end
  function fs.SetJustifyH() end
  function fs.SetAlpha() end
  return fs
end

local function NewTextureStub()
  local tex = { _shown = true, _points = {} }
  function tex.Show(self)
    self._shown = true
  end
  function tex.Hide(self)
    self._shown = false
  end
  function tex.SetWidth(self, width)
    self._width = width
  end
  function tex.SetVertexColor(self, ...)
    self._color = { ... }
  end
  function tex.ClearAllPoints(self)
    self._points = {}
  end
  function tex.SetPoint(self, ...)
    table.insert(self._points, { ... })
  end
  function tex.SetAlpha() end
  function tex.GetAlpha()
    return 1
  end
  return tex
end

local function NewRow()
  return {
    killTrackBarContainer = {
      GetWidth = function()
        return 200
      end,
      Show = function() end,
      Hide = function() end,
    },
    killTrackBarBg = NewTextureStub(),
    killTrackBarFill = NewTextureStub(),
    killTrackBarPull = NewTextureStub(),
    killTrackPaceTick = NewTextureStub(),
    killTrackTargetText = NewTextStub(),
    killTrackTargetLevelText = NewTextStub(),
    killTrackPctText = NewTextStub(),
    killTrackPullText = NewTextStub(),
    killTrackTimePaceText = NewTextStub(),
    killTrackTimeStrip = NewTextureStub(),
    killTrackTimeGap = NewTextureStub(),
  }
end

local function RegisterLearningTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TimePace accumulates small forces steps and compares an identical replay without false delay", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules)
      local function AdvanceTrash()
        for count = 1, 300 do
          Advance(addon, env, count * 4, count, 0)
        end
      end
      StartRun(addon, env)
      AdvanceTrash()
      for kills = 1, 3 do
        Advance(addon, env, 1200 + kills * 100, 300, kills)
      end
      env.completion = { mapChallengeModeID = MAP_ID, level = KEY_LEVEL, time = 1500000, onTime = true }
      Dispatch(addon, "CHALLENGE_MODE_COMPLETED")
      local reference = Assert.NotNil(GetReference(addon, env.db), "the timed reference must be learned")
      Assert.True(#reference.times > 100, "small steps must accumulate into samples throughout the trash phase")
      Assert.True(reference.times[1] < 20, "recording begins before the first boss")
      Assert.True(#reference.times <= 601, "the existing sample bound remains intact")
      StartRun(addon, env)
      AdvanceTrash()
      local status = Assert.NotNil(addon.KillTrack.GetData().timePace, "the replay compares the reference")
      Assert.Equal(status.mode, "reference", "a learned reference is used")
      Assert.True(math.abs(status.delta) < 0.5, "identical progress at the same time has no false delay")
    end)
  end)

  test("TimePace stores a timed run as the reference for its dungeon and key level", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules)
      PlayRun(addon, env, 1500)
      local entry = Assert.NotNil(GetReference(addon, env.db), "a timed run must be stored per season, map and level")
      Assert.Equal(entry.duration, 1500, "the duration comes from the completion info in seconds")
      Assert.Equal(entry.lastSeen, 5000, "lastSeen must come from time()")
      Assert.Equal(#entry.times, #entry.progress, "times and progress must stay paired")
      Assert.Equal(entry.times[#entry.times], 1500, "the reference ends at the completion time")
      Assert.Equal(entry.progress[#entry.progress], 1, "the reference ends at full progress")
      -- 75/300 forces and 1 of 3 bosses: 0.5 * 0.25 + 0.5 / 3.
      Assert.Equal(entry.times[1], 375, "the first sample is the first progress change")
      Assert.Equal(entry.progress[1], 0.2917, "progress is half forces, half bosses, four decimals")
    end)
  end)

  test("TimePace keeps the slowest timed run per level and ignores untimed runs", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules)
      PlayRun(addon, env, 1500)
      env.clock = 6000
      PlayRun(addon, env, 1400)
      local entry = GetReference(addon, env.db)
      Assert.Equal(entry.duration, 1500, "a faster timed run must not replace the slower reference")
      Assert.Equal(entry.lastSeen, 6000, "a faster timed run still refreshes lastSeen")

      PlayRun(addon, env, 1700)
      Assert.Equal(GetReference(addon, env.db).duration, 1700, "a slower timed run becomes the reference")

      PlayRun(addon, env, 1790, false)
      Assert.Equal(GetReference(addon, env.db).duration, 1700, "an untimed run is never a reference")
    end)
  end)

  test("TimePace does not learn a reset, mismatched or already started run", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules)
      StartRun(addon, env)
      Advance(addon, env, 600, 150, 2)
      Dispatch(addon, "CHALLENGE_MODE_RESET")
      env.completion = { mapChallengeModeID = MAP_ID, level = KEY_LEVEL, time = 1500000, onTime = true }
      Dispatch(addon, "CHALLENGE_MODE_COMPLETED")
      Assert.Nil(GetReference(addon, env.db), "a reset run must never be learned")

      PlayRun(addon, env, 1500, true, KEY_LEVEL + 1)
      Assert.Nil(GetReference(addon, env.db), "a completion for another key level must not be learned")
      Assert.Nil(GetReference(addon, env.db, KEY_LEVEL + 1), "nor stored under the completion's level")

      -- A boss is already dead when tracking begins.
      env.bosses[1].completed = true
      env.elapsed = 0
      Dispatch(addon, "CHALLENGE_MODE_START")
      Advance(addon, env, 1500, 300, 3)
      env.completion = { mapChallengeModeID = MAP_ID, level = KEY_LEVEL, time = 1500000, onTime = true }
      Dispatch(addon, "CHALLENGE_MODE_COMPLETED")
      Assert.Nil(GetReference(addon, env.db), "a run with a boss dead at start must not be learned")
    end)
  end)

  test("TimePace ignores a corrupt stored reference and falls back to the projection", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules)
      env.db.timePace = {
        [addon.SeasonData.GetActiveSeasonID()] = {
          [MAP_ID] = { [KEY_LEVEL] = { duration = 1500, times = { 900, 300 }, progress = { 0.5, 1 } } },
        },
      }
      StartRun(addon, env)
      Advance(addon, env, 600, 90, 1)
      local status = Assert.NotNil(addon.KillTrack.GetData().timePace, "the run must still get a pace answer")
      Assert.Equal(status.mode, "projection", "a non-monotonic reference must be ignored")
    end)
  end)
end

local function RegisterStatusTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TimePace projects the finish time from forces and bosses without a reference", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules)
      StartRun(addon, env)
      Advance(addon, env, 30, 15, 0)
      Assert.Nil(addon.KillTrack.GetData().timePace, "the projection waits for 5% progress and 60 seconds")

      Advance(addon, env, 600, 90, 1)
      local status = Assert.NotNil(addon.KillTrack.GetData().timePace, "a projection must exist mid-run")
      Assert.Equal(status.mode, "projection", "without a reference the answer is a projection")
      -- progress = 0.5 * 0.3 + 0.5 / 3 = 0.31667 -> 600 / 0.31667 = 1894.7 s
      Assert.Equal(math.floor(status.projected), 1894, "projected = elapsed / progress")
      Assert.Equal(status.timeLimit, TIME_LIMIT, "the time limit comes from MplusTimer")
    end)
  end)

  test("TimePace compares against the reference at the same progress", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules)
      PlayRun(addon, env, 1600)
      StartRun(addon, env)
      -- 150/300 forces and 1 boss: the reference was here at 800 s.
      Advance(addon, env, 700, 150, 1)
      local status = Assert.NotNil(addon.KillTrack.GetData().timePace, "a reference answer must exist")
      Assert.Equal(status.mode, "reference", "a stored reference wins over the projection")
      Assert.Equal(status.keyLevel, KEY_LEVEL, "the answer names the compared key level")
      Assert.True(math.abs(status.delta + 100) < 0.5, "100 s earlier than the reference at the same progress")

      -- Between samples the reference time is interpolated: progress 0.4917
      -- lies between 0.4167 (800 s) and 0.7083 (1200 s), at about 902.9 s.
      Advance(addon, env, 1000, 195, 1)
      status = addon.KillTrack.GetData().timePace
      Assert.True(math.abs(status.delta - (1000 - 902.9)) < 0.5, "the reference time is interpolated")
    end)
  end)

  test("TimePace counts the dungeon's time curve into the forecast until a reference exists", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules)
      local seasonID = addon.SeasonData.GetActiveSeasonID()
      addon.TimeSeed = {
        [seasonID] = { progress = { 0.25, 0.5, 1 }, [MAP_ID] = { 0.2, 0.6, 1 } },
      }
      StartRun(addon, env)
      Advance(addon, env, 30, 15, 0)
      Assert.Nil(
        addon.KillTrack.GetData().timePace,
        "the curve waits for 5% progress and 60 seconds like the projection"
      )

      -- progress = 0.5 * 0.5 + 0.5 / 3 = 0.41667 lies at 2/3 between 0.25 and
      -- 0.5, so the curve share is 0.46667 and its estimate 800 / 0.46667 =
      -- 1714.3 s. The whole run says 800 / 0.41667 = 1920 s, the rolling tempo
      -- has no history inside its window: the mean of the two.
      Advance(addon, env, 800, 150, 1)
      local status = Assert.NotNil(addon.KillTrack.GetData().timePace, "the curve must answer mid-run")
      Assert.Equal(status.mode, "projection", "the curve no longer answers like a reference")
      Assert.Nil(status.delta, "a forecast has no reference delta")
      Assert.Equal(status.timeLimit, TIME_LIMIT, "the forecast is compared against the time limit")
      Assert.True(math.abs(status.projected - 1817.1) < 0.5, "two estimates meet in the middle")

      addon.TimeSeed[seasonID][MAP_ID] = { 0.9, 0.6, 1 }
      status = addon.KillTrack.GetData().timePace
      Assert.Equal(status.mode, "projection", "a broken curve leaves the other estimates")
      Assert.True(math.abs(status.projected - 1920) < 0.5, "only the whole-run estimate is left")
    end)
  end)

  test("TimePace forecasts the median of whole run, rolling tempo and curve", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules)
      addon.TimeSeed = {
        [addon.SeasonData.GetActiveSeasonID()] = { progress = { 0.25, 0.5, 1 }, [MAP_ID] = { 0.2, 0.6, 1 } },
      }
      StartRun(addon, env)
      Advance(addon, env, 100, 30, 0)
      Advance(addon, env, 560, 120, 0)
      -- Progress 0.41667 at 800 s. Whole run: 1920 s. Curve: 1714.3 s. Rolling:
      -- the 100 s sample left the window, so from 560 s (progress 0.2):
      -- 800 + 0.58333 * 240 / 0.21667 = 1446.2 s.
      Advance(addon, env, 800, 150, 1)
      local status = Assert.NotNil(addon.KillTrack.GetData().timePace, "all three estimates must answer")
      Assert.Equal(status.mode, "projection", "the median is a forecast")
      Assert.True(math.abs(status.projected - 1714.3) < 0.5, "the middle estimate is the answer")
    end)
  end)

  test("TimePace leaves the rolling tempo out until it covers two minutes", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules)
      addon.TimeSeed = {
        [addon.SeasonData.GetActiveSeasonID()] = { progress = { 0.25, 0.5, 1 }, [MAP_ID] = { 0.2, 0.6, 1 } },
      }
      StartRun(addon, env)
      Advance(addon, env, 40, 30, 0)
      -- 110 s of history. Progress 0.26667: whole run 562.5 s, curve 661.8 s.
      Advance(addon, env, 150, 60, 1)
      local status = Assert.NotNil(addon.KillTrack.GetData().timePace, "the forecast starts without the rolling tempo")
      Assert.True(math.abs(status.projected - 612.1) < 0.5, "two estimates average without the rolling tempo")

      -- 125 s of history. Progress 0.29167: rolling 531.4 s, whole run 565.7 s,
      -- curve 618.8 s.
      Advance(addon, env, 165, 75, 1)
      status = addon.KillTrack.GetData().timePace
      Assert.True(math.abs(status.projected - 565.7) < 0.5, "from 120 s on the rolling tempo counts")

      -- No progress inside the window: the rolling tempo says nothing.
      StartRun(addon, env)
      Advance(addon, env, 40, 30, 0)
      env.elapsed = 200
      status = addon.KillTrack.GetData().timePace
      -- Progress 0.05: whole run 4000 s, curve 200 / 0.04 = 5000 s.
      Assert.True(math.abs(status.projected - 4500) < 0.5, "a flat window has no rolling tempo")
    end)
  end)

  test("TimePace keeps the rolling tempo for a run picked up after a reload", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules)
      env.elapsed = 700
      env.forces.quantity = 150
      env.bosses[1].completed = true
      Dispatch(addon, "PLAYER_ENTERING_WORLD")
      Dispatch(addon, "SCENARIO_CRITERIA_UPDATE")
      -- Progress 0.49167: whole run 1830.5 s, rolling from 700 s (0.41667)
      -- 900 + 0.50833 * 200 / 0.075 = 2255.6 s.
      Advance(addon, env, 900, 195, 1)
      local status = Assert.NotNil(addon.KillTrack.GetData().timePace, "a reloaded run must get a forecast")
      Assert.True(math.abs(status.projected - 2043) < 0.5, "the rolling history does not need a learnable run")
    end)
  end)

  test("TimePace median keeps one wild estimate out of the forecast", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules)
      local seasonBucket = { progress = { 0.25, 0.5, 1 }, [MAP_ID] = { 0.2, 0.6, 1 } }
      addon.TimeSeed = { [addon.SeasonData.GetActiveSeasonID()] = seasonBucket }

      -- Rolling goes wild after a stall: 800 + 0.58333 * 240 / 0.005 = 28800 s.
      StartRun(addon, env)
      Advance(addon, env, 560, 147, 1)
      Advance(addon, env, 800, 150, 1)
      local status = addon.KillTrack.GetData().timePace
      Assert.True(math.abs(status.projected - 1920) < 0.5, "a stalled tempo stops at the whole-run estimate")

      -- The curve goes wild the other way round: a share near zero.
      seasonBucket[MAP_ID] = { 0.0001, 0.0002, 1 }
      StartRun(addon, env)
      Advance(addon, env, 560, 120, 0)
      Advance(addon, env, 800, 150, 1)
      status = addon.KillTrack.GetData().timePace
      Assert.True(math.abs(status.projected - 1920) < 0.5, "a broken share stops at the whole-run estimate")
    end)
  end)

  test("TimePace uses the projection for a key level without a reference", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules)
      PlayRun(addon, env, 1600)
      env.keyLevel = KEY_LEVEL + 2
      StartRun(addon, env)
      Advance(addon, env, 700, 150, 1)
      Assert.Equal(addon.KillTrack.GetData().timePace.mode, "projection", "references are per key level")
    end)
  end)

  test("TimePace compares a run picked up after a reload but does not learn it", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules)
      PlayRun(addon, env, 1600)
      -- Fresh load mid-key: no CHALLENGE_MODE_START in this session.
      addon = Load(LoadAddonModules)
      env.elapsed = 700
      env.forces.quantity = 150
      env.bosses[1].completed = true
      Dispatch(addon, "PLAYER_ENTERING_WORLD")
      Dispatch(addon, "SCENARIO_CRITERIA_UPDATE")
      local status = Assert.NotNil(addon.KillTrack.GetData().timePace, "a reloaded run must still be compared")
      Assert.Equal(status.mode, "reference", "progress does not depend on the kill order")
      Advance(addon, env, 1650, 300, 3)
      env.completion = { mapChallengeModeID = MAP_ID, level = KEY_LEVEL, time = 1650000, onTime = true }
      Dispatch(addon, "CHALLENGE_MODE_COMPLETED")
      Assert.Equal(GetReference(addon, env.db).duration, 1600, "a reloaded run must not become the reference")
    end)
  end)
end

-- Combat pause: the shown pace freezes for each fight in the key.
local function RegisterCombatPauseTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TimePace freezes the shown pace during a fight and resumes once the pull's kills land", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules)
      PlayRun(addon, env, 1600)
      StartRun(addon, env)
      Advance(addon, env, 700, 150, 1)
      Dispatch(addon, "PLAYER_REGEN_DISABLED")
      local status = Assert.NotNil(addon.KillTrack.GetData().timePace, "the pull freezes the current answer")
      Assert.True(status.paused, "the frozen answer is marked as paused")
      Assert.True(math.abs(status.delta + 100) < 0.5, "the frozen answer is the one at the pull")

      -- The clock runs, kills land mid-pull: the shown answer stays put.
      env.elapsed = 760
      Dispatch(addon, "SCENARIO_CRITERIA_UPDATE")
      Advance(addon, env, 790, 180, 1)
      status = addon.KillTrack.GetData().timePace
      Assert.True(status.paused and math.abs(status.delta + 100) < 0.5, "the answer does not drift during the fight")

      Dispatch(addon, "PLAYER_REGEN_ENABLED")
      Assert.True(addon.KillTrack.GetData().timePace.paused, "the grace window waits for the late criteria update")
      RunTimers(env)
      status = addon.KillTrack.GetData().timePace
      Assert.Nil(status.paused, "the grace window end releases the answer")
      -- progress 0.4667 lies between 0.4167 (800 s) and 0.7083 (1200 s), at about 868.6 s.
      Assert.True(math.abs(status.delta - (790 - 868.6)) < 1, "the released answer counts the pull's kills")

      -- Learning used the real timer during the fight: the slower run becomes
      -- the reference and keeps the sample taken mid-pull.
      Advance(addon, env, 1700, 300, 3)
      env.completion = { mapChallengeModeID = MAP_ID, level = KEY_LEVEL, time = 1700000, onTime = true }
      Dispatch(addon, "CHALLENGE_MODE_COMPLETED")
      local reference = GetReference(addon, env.db)
      local hasPullSample = false
      for _, t in ipairs(reference.times) do
        hasPullSample = hasPullSample or t == 790
      end
      Assert.True(hasPullSample, "the pause never touches the learned samples")
    end)
  end)

  test("TimePace refreezes a chained pull and drops the pause with the run", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules)
      StartRun(addon, env)
      Advance(addon, env, 600, 90, 1)
      Dispatch(addon, "PLAYER_REGEN_DISABLED")
      Advance(addon, env, 650, 120, 1)
      Dispatch(addon, "PLAYER_REGEN_ENABLED")
      -- Next pull inside the grace window: frozen again at the new progress.
      Dispatch(addon, "PLAYER_REGEN_DISABLED")
      local status = addon.KillTrack.GetData().timePace
      Assert.True(status.paused, "the chained pull is paused")
      -- progress = 0.5 * 0.4 + 0.5 / 3 = 0.36667 -> 650 / 0.36667 = 1772.7 s
      Assert.Equal(math.floor(status.projected), 1772, "the chained pull freezes with the previous pull's kills")
      RunTimers(env)
      Assert.True(addon.KillTrack.GetData().timePace.paused, "the older grace window does not end the new pull's pause")

      Dispatch(addon, "CHALLENGE_MODE_RESET")
      Assert.False(addon.TimePace.IsStatusPaused(), "a reset drops the pause")
      StartRun(addon, env)
      Advance(addon, env, 600, 90, 1)
      Assert.Nil(addon.KillTrack.GetData().timePace.paused, "the next run starts unpaused")
    end)
  end)
end

local function RegisterTimeOverlayTests(test, Assert, WithGlobals, LoadAddonModules)
  -- The timer box module shares the grade colour keys with the kill row.
  local ROW_FILES = {
    "isiLive_ui_common.lua",
    "isiLive_roster_panel_helpers.lua",
    "isiLive_roster_panel_cd_row.lua",
    "isiLive_roster_panel_kill_row.lua",
  }

  test("Kill row overlays spent time on the forces bar and tints the gap by who leads", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules, ROW_FILES)
      local RI = addon._RosterInternal
      local colors = addon.UICommon.Colors
      StartRun(addon, env)
      Advance(addon, env, 600, 150, 1)
      local row = NewRow()
      RI.UpdateKillTrackRow(row)
      -- 600 of 1800 s spent, +3 still reachable (grade 3).
      RI.UpdateKillTrackTimeOverlay(row, { running = true, timer = 600, timeLimit = 1800 }, 3)
      local strip, gap = row.killTrackTimeStrip, row.killTrackTimeGap
      Assert.True(strip._shown, "the time strip shows during a key")
      Assert.Equal(strip._width, 67, "a third of the time limit fills a third of the 200 px bar")
      Assert.Equal(strip._color[1], colors.MPLUS_GRADE3_FILL[1], "the strip uses the timer box's grade colour")
      Assert.True(gap._shown, "the gap between forces and time is tinted")
      Assert.Equal(gap._width, 33, "50% forces against 33% time leaves a 33 px lead")
      Assert.Equal(gap._color[1], colors.MPLUS_PACE_AHEAD_GAP[1], "forces ahead of the clock tint green")

      RI.UpdateKillTrackTimeOverlay(row, { running = true, timer = 1200, timeLimit = 1800 }, 2)
      Assert.Equal(gap._width, 33, "67% time against 50% forces leaves a 33 px gap")
      Assert.Equal(gap._color[1], colors.MPLUS_PACE_BEHIND_GAP[1], "the clock ahead of forces tints red")
      Assert.Equal(strip._color[1], colors.MPLUS_GRADE2_FILL[1], "the strip follows the reachable grade")
    end)
  end)

  test("Kill row time overlay hides without a running key or with time pace off", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules, ROW_FILES)
      local RI = addon._RosterInternal
      StartRun(addon, env)
      Advance(addon, env, 600, 150, 1)
      local row = NewRow()
      RI.UpdateKillTrackRow(row)
      RI.UpdateKillTrackTimeOverlay(row, nil, nil)
      Assert.False(row.killTrackTimeStrip._shown, "no timer snapshot hides the strip")
      Assert.False(row.killTrackTimeGap._shown, "no timer snapshot hides the gap")

      env.db.timePaceEnabled = false
      RI.UpdateKillTrackTimeOverlay(row, { running = true, timer = 600, timeLimit = 1800 }, 3)
      Assert.False(row.killTrackTimeStrip._shown, "the time pace setting also switches the overlay off")
      env.db.timePaceEnabled = nil

      Dispatch(addon, "CHALLENGE_MODE_RESET")
      RI.UpdateKillTrackRow(row)
      Assert.False(row.killTrackTimeStrip._shown, "outside an active killtracker the overlay hides")
    end)
  end)
end

local function RegisterKillRowTests(test, Assert, WithGlobals, LoadAddonModules)
  local ROW_FILES = { "isiLive_ui_common.lua", "isiLive_roster_panel_helpers.lua", "isiLive_roster_panel_kill_row.lua" }

  test("UpdateKillTrackRow shows the reference delta on the bar in green or red", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules, ROW_FILES)
      PlayRun(addon, env, 1600)
      StartRun(addon, env)
      Advance(addon, env, 728, 150, 1)
      local row = NewRow()
      addon._RosterInternal.UpdateKillTrackRow(row)
      local line = row.killTrackTimePaceText
      Assert.Equal(line._text, "-1:12", "ahead of the reference shows a minus delta")
      Assert.Equal(line._color[1], addon.UICommon.Colors.GREEN_HINT_TEXT[1], "ahead is green")

      Advance(addon, env, 875, 150, 1)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(line._text, "+1:15", "behind the reference shows a plus delta")
      Assert.Equal(line._color[1], addon.UICommon.Colors.TEXT_ALERT_DANGER[1], "behind is red")

      Dispatch(addon, "PLAYER_REGEN_DISABLED")
      Advance(addon, env, 950, 150, 1)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(line._text, "Pause +1:15", "a fight keeps the pull's delta behind the pause word")
      Assert.Equal(line._color[1], addon.UICommon.Colors.TEXT_ALERT_DANGER[1], "the paused delta keeps the pull's red")
    end)
  end)

  test("UpdateKillTrackRow shows the forecast delta, and clears it outside a run or when off", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Load(LoadAddonModules, ROW_FILES)
      StartRun(addon, env)
      Advance(addon, env, 600, 90, 1)
      local row = NewRow()
      addon._RosterInternal.UpdateKillTrackRow(row)
      local line = row.killTrackTimePaceText
      Assert.Equal(line._text, "+1:35", "the forecast shows its delta to the time limit")
      Assert.Equal(line._color[1], addon.UICommon.Colors.TEXT_ALERT_DANGER[1], "over the limit is red")

      Advance(addon, env, 600, 150, 2)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(line._color[1], addon.UICommon.Colors.GREEN_HINT_TEXT[1], "within the limit is green")

      env.db.timePaceEnabled = false
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(line._text, "", "the setting turns the line off")
      env.db.timePaceEnabled = nil

      Dispatch(addon, "CHALLENGE_MODE_RESET")
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(line._text, "", "no line outside a run")
    end)
  end)
end

local function RegisterSettingTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Settings time-pace toggle is default-on, persists and refreshes the kill row", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    local toggles = {}

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_db_schema.lua",
        "isiLive_ui_common.lua",
        "isiLive_time_pace.lua",
        "isiLive_settings.lua",
      })
      local fresh = {}
      addon.DBSchema.Sanitize(fresh)
      Assert.True(fresh.timePaceEnabled, "the schema default must be on")
      Assert.Equal(type(fresh.timePace), "table", "the schema must provide the reference storage table")
      Assert.True(addon.TimePace.IsEnabled(), "a fresh install reads the setting as on")

      local panel = addon.SettingsPanel.Create({
        getL = function()
          return { SETTINGS_TIME_PACE = "M+ Killtracker: Time pace" }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
        -- The factory wires only the forces-pace refresh; the time-pace
        -- toggle shares it.
        onForcesPaceToggle = function(enabled)
          toggles[#toggles + 1] = enabled
        end,
      })

      local check = nil
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "CheckButton" and frame._settingKey == "SETTINGS_TIME_PACE" then
          check = frame
        end
      end
      check = Assert.NotNil(check, "the display section must render the time-pace toggle")
      Assert.True(check:GetChecked(), "the toggle must default to on")
      Assert.Nil(db.timePaceEnabled, "opening settings must not persist the default")

      check:SetChecked(false)
      check._scripts.OnClick(check)
      Assert.False(db.timePaceEnabled, "turning it off must persist false")
      Assert.False(addon.TimePace.IsEnabled(), "the module must read the persisted off state")
      Assert.Equal(toggles[1], false, "the toggle must live-apply through the kill-row refresh")

      panel.Refresh()
      Assert.False(check:GetChecked(), "refresh must mirror the stored off state")
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterLearningTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterStatusTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCombatPauseTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterKillRowTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTimeOverlayTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterSettingTests(test, Assert, WithGlobals, LoadAddonModules)
end
