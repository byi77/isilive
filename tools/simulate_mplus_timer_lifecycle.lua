-- Standalone CLI tool: full lifecycle for the M+ timer module.
-- Drives CHALLENGE_MODE_START -> on-demand timer read ->
-- CHALLENGE_MODE_DEATH_COUNT_UPDATED -> CHALLENGE_MODE_COMPLETED /
-- CHALLENGE_MODE_RESET through the production HandleEvent dispatcher and
-- pins the +1 / +2 / +3 cutoff math, the death-penalty key-level gate,
-- and the back-to-back reset between runs.
--
-- Verifies:
--   * START reads mapID + keystone level + map time-limit, marks running=true,
--     resets timer/deaths/death-time-lost, computes +1/+2/+3 cutoffs from
--     the GetMapUIInfo timeLimit (100% / 80% / 60%).
--   * GetTimerData reads GetWorldElapsedTime on demand and advances state.timer.
--   * CHALLENGE_MODE_DEATH_COUNT_UPDATED reads GetDeathCount and updates
--     deaths + deathTimeLost.
--   * Death-penalty gate: GetTimerData() exposes deathTimeLost only when
--     keyLevel >= 4 (no penalty on +2/+3 keys per Blizzard's rule).
--   * COMPLETED and RESET stop live sampling and wipe the timer/deaths/cutoffs
--     entirely.
--   * timeRemaining1/2/3 = (cutoffSeconds - state.timer); negative when
--     the cutoff has been missed.
--   * SetDemoData wins over live state; ClearDemoData restores the live read.
--   * Back-to-back runs: START -> COMPLETED -> START leaves the second run
--     with timer=0, deaths=0, completed=false (no leak from run 1).
--
-- End-to-end discipline (CLAUDE.md "Tests & simulators: end-to-end by default"):
-- the real MplusTimer module is loaded; every state mutation flows through
-- MplusTimer.HandleEvent (the production dispatcher); timer reads run through
-- the production GetTimerData on-demand sampling path.
-- The C_ChallengeMode / GetWorldElapsedTime globals are the
-- exact surface WoW exposes.
---@diagnostic disable: undefined-global
local io = io
---@diagnostic disable-next-line: undefined-global
local load = load
---@diagnostic disable-next-line: undefined-global
local os = os

local function LoadLocal(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  local chunk, err = (loadstring or load)(source, "@" .. path)
  assert(chunk, err)
  return chunk()
end

local Harness = LoadLocal("testmodul/isilive_test_harness.lua")

local failures = 0

local function Check(condition, message)
  if condition then
    print("  [CHECK PASS] " .. message)
    return
  end
  failures = failures + 1
  print("  [CHECK FAIL] " .. message)
end

-- ----------------------------------------------------------------------
-- Steerable WoW-globals model. The C_ChallengeMode + GetWorldElapsedTime
-- mocks below dereference these fields, so test scenarios
-- mutate them between HandleEvent calls.
-- ----------------------------------------------------------------------
local model = {
  activeMapID = 2649,
  keyLevel = 12,
  -- Ara-Kara timeLimit ~30 minutes; +2 cutoff at 24 min, +3 at 18 min.
  mapTimeLimit = 1800,
  worldElapsedTime = 0,
  deathCount = 0,
  deathTimeLost = 0,
}

local function ResetModel()
  model.activeMapID = 2649
  model.keyLevel = 12
  model.mapTimeLimit = 1800
  model.worldElapsedTime = 0
  model.deathCount = 0
  model.deathTimeLost = 0
end

local function buildGlobals()
  return {
    C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        return model.activeMapID
      end,
      GetActiveKeystoneInfo = function()
        return model.keyLevel
      end,
      GetMapUIInfo = function(_mapID)
        -- Production destructures `ok, _, _, timeLimit = pcall(GetMapUIInfo, ...)`
        -- so timeLimit is the THIRD post-pcall return value.
        return "Ara-Kara, City of Echoes", "desc", model.mapTimeLimit
      end,
      GetDeathCount = function()
        return model.deathCount, model.deathTimeLost
      end,
    },
    GetWorldElapsedTime = function(_timerID)
      return 1, model.worldElapsedTime, model.mapTimeLimit
    end,
  }
end

local function BuildSession()
  local addon
  Harness.WithGlobals(buildGlobals(), function()
    addon = Harness.LoadAddonModules({ "isiLive_mplus_timer.lua" })
  end)
  return {
    addon = addon,
    fire = function(event)
      Harness.WithGlobals(buildGlobals(), function()
        addon.MplusTimer.HandleEvent(event)
      end)
    end,
    getTimerData = function()
      local data
      Harness.WithGlobals(buildGlobals(), function()
        data = addon.MplusTimer.GetTimerData()
      end)
      return data
    end,
  }
end

-- ----------------------------------------------------------------------
-- Phase 1: CHALLENGE_MODE_START reads mapID + keyLevel + timeLimit,
-- sets running=true, resets timer/deaths, computes +1/+2/+3 cutoffs.
-- ----------------------------------------------------------------------
local function ScenarioKeyStart()
  print("\n========== Scenario 1: CHALLENGE_MODE_START reads + arms timer ==========")
  ResetModel()
  model.mapTimeLimit = 1800 -- 30 min
  model.keyLevel = 12
  local session = BuildSession()

  session.fire("CHALLENGE_MODE_START")
  local data = session.getTimerData()
  Check(data.running == true, "post-START: running=true")
  Check(data.completed == false, "post-START: completed=false")
  Check(data.timeLimit == 1800, "post-START: timeLimit picked up from GetMapUIInfo (1800s = 30min)")
  Check(data.keyLevel == 12, "post-START: keyLevel=12")
  Check(data.timer == 0, "post-START: timer reset to 0")
  Check(data.deaths == 0, "post-START: deaths reset to 0")
  Check(data.deathTimeLost == 0, "post-START: deathTimeLost reset to 0")

  -- +1/+2/+3 cutoffs: 1800s / 1440s / 1080s remaining (since timer=0).
  Check(data.timeRemaining1 == 1800, "+1 cutoff (100%) = 1800s remaining at start")
  Check(data.timeRemaining2 == 1440, "+2 cutoff (80%) = 1440s remaining at start")
  Check(data.timeRemaining3 == 1080, "+3 cutoff (60%) = 1080s remaining at start")
end

-- ----------------------------------------------------------------------
-- Phase 2: GetTimerData reads GetWorldElapsedTime and advances state.timer.
-- ----------------------------------------------------------------------
local function ScenarioTickAdvancesTimer()
  print("\n========== Scenario 2: on-demand read advances state.timer ==========")
  ResetModel()
  local session = BuildSession()
  session.fire("CHALLENGE_MODE_START")

  -- Game world reports 30s elapsed; the next read picks that up.
  model.worldElapsedTime = 30
  local data = session.getTimerData()
  Check(data.timer == 30, "read samples GetWorldElapsedTime and sets state.timer=30")
  Check(data.timeRemaining1 == 1770, "timeRemaining1 = 1800 - 30 = 1770")

  -- Game world reports 1500s elapsed (well into the run).
  model.worldElapsedTime = 1500
  data = session.getTimerData()
  Check(data.timer == 1500, "read at 1500s elapsed advances state.timer=1500")
  Check(data.timeRemaining3 == -420, "+3 missed: timeRemaining3 = 1080 - 1500 = -420 (negative)")
end

-- ----------------------------------------------------------------------
-- Phase 3: CHALLENGE_MODE_DEATH_COUNT_UPDATED reads GetDeathCount.
-- Death penalty gate: only key-level >= 4 surfaces deathTimeLost.
-- ----------------------------------------------------------------------
local function ScenarioDeathCountAndPenaltyGate()
  print("\n========== Scenario 3: death count + key-level >= 4 penalty gate ==========")
  ResetModel()
  model.keyLevel = 12 -- well above the +4 penalty gate
  local session = BuildSession()
  session.fire("CHALLENGE_MODE_START")

  model.deathCount = 3
  model.deathTimeLost = 45
  session.fire("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
  local data = session.getTimerData()
  Check(data.deaths == 3, "deaths=3 picked up from GetDeathCount")
  Check(data.deathTimeLost == 45, "deathTimeLost=45 surfaced because keyLevel >= 4")

  -- Restart at key-level 2: penalty gate must hide the time-lost field.
  model.keyLevel = 2
  model.deathCount = 5
  model.deathTimeLost = 75
  session.fire("CHALLENGE_MODE_RESET") -- clear first
  session.fire("CHALLENGE_MODE_START")
  session.fire("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
  data = session.getTimerData()
  Check(data.deaths == 5, "deaths=5 still recorded at key-level 2")
  Check(
    data.deathTimeLost == 0,
    "deathTimeLost=0 at key-level 2 (Blizzard's death penalty only applies at +4 and above)"
  )
end

-- ----------------------------------------------------------------------
-- Phase 4: CHALLENGE_MODE_COMPLETED wipes everything.
-- ----------------------------------------------------------------------
local function ScenarioKeyCompleted()
  print("\n========== Scenario 4: CHALLENGE_MODE_COMPLETED wipes state ==========")
  ResetModel()
  local session = BuildSession()
  session.fire("CHALLENGE_MODE_START")
  model.worldElapsedTime = 1200

  session.fire("CHALLENGE_MODE_COMPLETED")
  local data = session.getTimerData()
  Check(data.running == false, "post-COMPLETED: running=false")
  Check(data.completed == false, "post-COMPLETED: completed=false")
  Check(data.timer == 0, "post-COMPLETED: timer wiped to 0")
  Check(data.deaths == 0, "post-COMPLETED: deaths wiped to 0")
  Check(data.deathTimeLost == 0, "post-COMPLETED: deathTimeLost wiped to 0")
  Check(data.timeLimit == 0, "post-COMPLETED: timeLimit wiped to 0")
  Check(data.timeRemaining1 == 0, "post-COMPLETED: cutoff arrays reset (timeRemaining1=0)")

  -- A subsequent read must NOT advance the timer or restore the wiped state.
  model.worldElapsedTime = 1500
  data = session.getTimerData()
  Check(data.timer == 0, "read after COMPLETED leaves the timer wiped")
end

-- ----------------------------------------------------------------------
-- Phase 5: CHALLENGE_MODE_RESET wipes everything.
-- ----------------------------------------------------------------------
local function ScenarioKeyReset()
  print("\n========== Scenario 5: CHALLENGE_MODE_RESET wipes state ==========")
  ResetModel()
  local session = BuildSession()
  session.fire("CHALLENGE_MODE_START")
  model.worldElapsedTime = 600
  model.deathCount = 2
  model.deathTimeLost = 30
  session.fire("CHALLENGE_MODE_DEATH_COUNT_UPDATED")

  session.fire("CHALLENGE_MODE_RESET")
  local data = session.getTimerData()
  Check(data.running == false, "post-RESET: running=false")
  Check(data.completed == false, "post-RESET: completed=false (different from COMPLETED)")
  Check(data.timer == 0, "post-RESET: timer wiped to 0")
  Check(data.deaths == 0, "post-RESET: deaths wiped to 0")
  Check(data.deathTimeLost == 0, "post-RESET: deathTimeLost wiped to 0")
  Check(data.timeLimit == 0, "post-RESET: timeLimit wiped to 0")
  Check(data.timeRemaining1 == 0, "post-RESET: cutoff arrays reset (timeRemaining1=0)")
end

-- ----------------------------------------------------------------------
-- Phase 6: SetDemoData / ClearDemoData short-circuit.
-- ----------------------------------------------------------------------
local function ScenarioDemoData()
  print("\n========== Scenario 6: demo data short-circuits live state ==========")
  ResetModel()
  local session = BuildSession()
  session.fire("CHALLENGE_MODE_START")
  model.worldElapsedTime = 100

  session.addon.MplusTimer.SetDemoData({
    running = true,
    completed = false,
    timer = 999,
    timeLimit = 1800,
    keyLevel = 22,
    timeRemaining1 = 1,
    timeRemaining2 = 2,
    timeRemaining3 = 3,
    deaths = 0,
    deathTimeLost = 0,
  })
  local data = session.getTimerData()
  Check(data.timer == 999 and data.keyLevel == 22, "SetDemoData replaces GetTimerData() entirely")

  session.addon.MplusTimer.ClearDemoData()
  data = session.getTimerData()
  Check(data.timer == 100 and data.keyLevel == 12, "ClearDemoData restores the live read")
end

-- ----------------------------------------------------------------------
-- Phase 7: back-to-back keys leave run 2 with clean state.
-- ----------------------------------------------------------------------
local function ScenarioBackToBackKeys()
  print("\n========== Scenario 7: back-to-back keys reset cleanly ==========")
  ResetModel()
  local session = BuildSession()
  session.fire("CHALLENGE_MODE_START")
  model.worldElapsedTime = 1500
  model.deathCount = 4
  model.deathTimeLost = 60
  session.fire("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
  session.fire("CHALLENGE_MODE_COMPLETED")

  -- Run 2 starts fresh.
  model.activeMapID = 2660 -- City of Threads
  model.keyLevel = 14
  model.mapTimeLimit = 2100 -- 35 min
  model.worldElapsedTime = 0
  model.deathCount = 0
  model.deathTimeLost = 0
  session.fire("CHALLENGE_MODE_START")
  local data = session.getTimerData()
  Check(data.running == true, "run 2: running=true after second START")
  Check(data.completed == false, "run 2: completed=false (no leak from run 1)")
  Check(data.timer == 0, "run 2: timer reset to 0")
  Check(data.deaths == 0, "run 2: deaths reset to 0")
  Check(data.deathTimeLost == 0, "run 2: deathTimeLost reset to 0")
  Check(data.keyLevel == 14, "run 2: keyLevel re-read from GetActiveKeystoneInfo")
  Check(data.timeLimit == 2100, "run 2: timeLimit re-read from new map's GetMapUIInfo")
end

ScenarioKeyStart()
ScenarioTickAdvancesTimer()
ScenarioDeathCountAndPenaltyGate()
ScenarioKeyCompleted()
ScenarioKeyReset()
ScenarioDemoData()
ScenarioBackToBackKeys()

if failures > 0 then
  print(string.format("\nMplusTimer lifecycle simulator failed: %d check(s) failed", failures))
  os.exit(1)
end

print("\nMplusTimer lifecycle simulator passed.")
