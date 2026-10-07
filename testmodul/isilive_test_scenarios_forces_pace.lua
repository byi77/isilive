---@diagnostic disable: undefined-global

-- Forces pace for the M+ killtracker (rule 145).
--
-- End-to-end through the real modules: KillTrack reads the scenario criteria
-- stubs (weighted enemy forces plus non-weighted boss criteria) and hands its
-- snapshots to the real ForcesPace, which learns into a real IsiLiveDB table;
-- the kill row renders whatever the real KillTrack.GetData() returns. Events
-- enter through KillTrack.HandleEvent, the entry point the controller wiring
-- dispatches to.

local helpersChunk, helpersErr = loadfile("testmodul/isilive_test_ui_helpers.lua")
if not helpersChunk then
  error("cannot load UI helpers: " .. tostring(helpersErr))
end
local helpers = helpersChunk()
local BuildCreateFrameStub = helpers.BuildCreateFrameStub

local SECRET = "__ISILIVE_TEST_SECRET__"
local MAP_ID = 2649
local FORCES_CRITERIA_ID = 9001

-- Criteria layout like the game: one non-weighted criterion per boss first,
-- then any extra weighted boss bars, then enemy forces.
local function BuildScenario(opts)
  opts = opts or {}
  local scenario = {
    mapID = opts.mapID or MAP_ID,
    bosses = {},
    extra = {},
    unreadable = {},
    forces = {
      isWeightedProgress = true,
      criteriaID = FORCES_CRITERIA_ID,
      totalQuantity = opts.total or 300,
      quantity = 0,
      quantityString = "0",
      completed = false,
    },
  }
  for i = 1, opts.bossCount or 3 do
    scenario.bosses[i] = { isWeightedProgress = false, completed = false, criteriaID = 100 + i }
  end

  local function List()
    local list = {}
    for _, boss in ipairs(scenario.bosses) do
      list[#list + 1] = boss
    end
    for _, bar in ipairs(scenario.extra) do
      list[#list + 1] = bar
    end
    list[#list + 1] = scenario.forces
    return list
  end

  function scenario.SetForces(count)
    scenario.forces.quantity = count
    scenario.forces.quantityString = tostring(count)
  end
  function scenario.Kill(index)
    scenario.bosses[index].completed = true
  end
  function scenario.ResetBosses()
    for _, boss in ipairs(scenario.bosses) do
      boss.completed = false
    end
    scenario.SetForces(0)
    scenario.forces.completed = false
  end

  scenario.C_ScenarioInfo = {
    GetScenarioStepInfo = function()
      return { numCriteria = #List() }
    end,
    GetCriteriaInfo = function(i)
      if scenario.unreadable[i] then
        error("criteria API fault")
      end
      return List()[i]
    end,
  }
  scenario.C_ChallengeMode = {
    GetActiveChallengeMapID = function()
      return scenario.mapID
    end,
  }
  return scenario
end

local function BuildEnv(opts)
  opts = opts or {}
  local scenario = BuildScenario(opts)
  local env = { scenario = scenario, db = opts.db or {}, clock = 5000 }
  env.globals = {
    C_ChallengeMode = scenario.C_ChallengeMode,
    C_ScenarioInfo = scenario.C_ScenarioInfo,
    C_Timer = {
      After = function() end,
      NewTicker = function()
        return { Cancel = function() end }
      end,
    },
    GetTime = function()
      return 1000
    end,
    time = function()
      return env.clock
    end,
    IsiLiveDB = env.db,
    issecretvalue = function(value)
      return value == SECRET
    end,
  }
  return env
end

local function LoadPaceModules(LoadAddonModules, extraFiles)
  local files = { "isiLive_season_data.lua", "isiLive_killtrack.lua" }
  for _, file in ipairs(extraFiles or {}) do
    files[#files + 1] = file
  end
  return LoadAddonModules(files)
end

-- One run: CHALLENGE_MODE_START, then per kill a forces update followed by
-- the boss criterion completing, then CHALLENGE_MODE_COMPLETED.
local function PlayRun(addon, scenario, kills, finishEvent)
  scenario.ResetBosses()
  addon.KillTrack.HandleEvent("CHALLENGE_MODE_START")
  for _, kill in ipairs(kills) do
    scenario.SetForces(kill.forces)
    addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
    scenario.Kill(kill.boss)
    addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
  end
  addon.KillTrack.HandleEvent(finishEvent or "CHALLENGE_MODE_COMPLETED")
end

local function GetRoutes(addon, db)
  local seasonID = addon.SeasonData.GetActiveSeasonID()
  local root = db.forcesPace
  local seasonBucket = type(root) == "table" and root[seasonID] or nil
  local mapBucket = type(seasonBucket) == "table" and seasonBucket[MAP_ID] or nil
  return type(mapBucket) == "table" and mapBucket.routes or nil
end

local function CountKeys(map)
  local count = 0
  for _ in pairs(map or {}) do
    count = count + 1
  end
  return count
end

local function SeedRoutes(addon, db, routes)
  db.forcesPace = {
    [addon.SeasonData.GetActiveSeasonID()] = {
      [MAP_ID] = { routes = routes },
    },
  }
end

local function Route(order, checkpoints, extra)
  local score = 0
  for _, value in ipairs(checkpoints) do
    score = score + value
  end
  local route = { order = order, checkpoints = checkpoints, leanScore = score, runs = 1, lastSeen = 1 }
  for key, value in pairs(extra or {}) do
    route[key] = value
  end
  return route
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
  function tex.GetAlpha()
    return 1
  end
  function tex.SetAlpha() end
  function tex.CreateAnimationGroup()
    return {
      CreateAnimation = function()
        return {
          SetFromAlpha = function() end,
          SetToAlpha = function() end,
          SetDuration = function() end,
          SetSmoothing = function() end,
        }
      end,
      SetScript = function() end,
      IsPlaying = function()
        return false
      end,
      Play = function() end,
      Stop = function() end,
    }
  end
  return tex
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

local function NewRow(barWidth)
  local container = {
    GetWidth = function()
      return barWidth
    end,
    Show = function() end,
    Hide = function() end,
  }
  return {
    killTrackBarContainer = container,
    killTrackBarBg = NewTextureStub(),
    killTrackBarFill = NewTextureStub(),
    killTrackBarPull = NewTextureStub(),
    killTrackPaceTick = NewTextureStub(),
    killTrackTargetText = NewTextStub(),
    killTrackTargetLevelText = NewTextStub(),
    killTrackActiveDungeonBackdrop = NewTextureStub(),
    killTrackActiveDungeonText = NewTextStub(),
    killTrackPctText = NewTextStub(),
    killTrackPullText = NewTextStub(),
  }
end

local function RegisterLearningTests(test, Assert, WithGlobals, LoadAddonModules)
  test("ForcesPace records boss kill order and forces percent at each kill", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = LoadPaceModules(LoadAddonModules)
      PlayRun(addon, env.scenario, {
        { boss = 2, forces = 47 },
        { boss = 1, forces = 140 },
        { boss = 3, forces = 230 },
      })
      local routes = Assert.NotNil(GetRoutes(addon, env.db), "a complete run must be stored per season and map")
      local route = Assert.NotNil(routes["2-1-3"], "the route key must be the kill order of criteria indices")
      Assert.Equal(table.concat(route.order, ","), "2,1,3", "kill order must follow the death order")
      Assert.Equal(route.checkpoints[1], 15.7, "47/300 forces must be captured with one decimal")
      Assert.Equal(route.checkpoints[2], 46.7, "140/300 forces must be captured with one decimal")
      Assert.Equal(route.checkpoints[3], 76.7, "230/300 forces must be captured with one decimal")
      Assert.Equal(route.leanScore, 139.1, "lean score must be the sum of the kill percentages")
      Assert.Equal(route.runs, 1, "the first run of a route counts once")
      Assert.Equal(route.lastSeen, 5000, "lastSeen must come from time()")
    end)
  end)

  test("ForcesPace run revision moves with boss kills but not with trash forces", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = LoadPaceModules(LoadAddonModules)
      local pace = addon.ForcesPace
      env.scenario.ResetBosses()
      local beforeStart = pace.GetRunRevision()
      addon.KillTrack.HandleEvent("CHALLENGE_MODE_START")
      local afterStart = pace.GetRunRevision()
      Assert.True(afterStart ~= beforeStart, "a new run must move the revision")

      for count = 10, 40, 10 do
        env.scenario.SetForces(count)
        addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      end
      Assert.Equal(pace.GetRunRevision(), afterStart, "trash forces alone must not move the pace revision")

      env.scenario.Kill(2)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      local afterKill = pace.GetRunRevision()
      Assert.True(afterKill ~= afterStart, "a boss kill must move the revision so the pace target is recomputed")
      addon.KillTrack.HandleEvent("CHALLENGE_MODE_RESET")
      Assert.True(pace.GetRunRevision() ~= afterKill, "discarding the run must move the revision")
    end)
  end)

  test("ForcesPace commits only a complete run tracked from the start", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = LoadPaceModules(LoadAddonModules)
      PlayRun(addon, env.scenario, { { boss = 1, forces = 60 }, { boss = 2, forces = 150 } })
      Assert.Equal(CountKeys(GetRoutes(addon, env.db)), 0, "a run with a boss left alive must not be learned")

      -- Completion without a start in this session (e.g. after a reload).
      env.scenario.ResetBosses()
      addon.KillTrack.HandleEvent("CHALLENGE_MODE_COMPLETED")
      Assert.Equal(CountKeys(GetRoutes(addon, env.db)), 0, "a completion without a tracked run learns nothing")
    end)
  end)

  test("ForcesPace keeps the leaner run per route and counts every run", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = LoadPaceModules(LoadAddonModules)
      PlayRun(
        addon,
        env.scenario,
        { { boss = 1, forces = 90 }, { boss = 2, forces = 180 }, { boss = 3, forces = 270 } }
      )
      env.clock = 6000
      PlayRun(
        addon,
        env.scenario,
        { { boss = 1, forces = 60 }, { boss = 2, forces = 150 }, { boss = 3, forces = 240 } }
      )
      local route = GetRoutes(addon, env.db)["1-2-3"]
      Assert.Equal(route.checkpoints[1], 20, "a leaner run must replace the stored checkpoints")
      Assert.Equal(route.leanScore, 150, "a leaner run must replace the stored lean score")
      Assert.Equal(route.runs, 2, "the run counter must carry over a replacement")

      env.clock = 7000
      PlayRun(
        addon,
        env.scenario,
        { { boss = 1, forces = 120 }, { boss = 2, forces = 210 }, { boss = 3, forces = 285 } }
      )
      route = GetRoutes(addon, env.db)["1-2-3"]
      Assert.Equal(route.checkpoints[1], 20, "a worse run must keep the leaner checkpoints")
      Assert.Equal(route.leanScore, 150, "a worse run must keep the leaner score")
      Assert.Equal(route.runs, 3, "a worse run must still bump the run counter")
      Assert.Equal(route.lastSeen, 7000, "a worse run must still refresh lastSeen")
    end)
  end)

  test("ForcesPace discards the run on CHALLENGE_MODE_RESET", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = LoadPaceModules(LoadAddonModules)
      PlayRun(addon, env.scenario, {
        { boss = 1, forces = 60 },
        { boss = 2, forces = 150 },
        { boss = 3, forces = 240 },
      }, "CHALLENGE_MODE_RESET")
      addon.KillTrack.HandleEvent("CHALLENGE_MODE_COMPLETED")
      Assert.Equal(CountKeys(GetRoutes(addon, env.db)), 0, "a reset run must never be learned")
    end)
  end)

  test("ForcesPace does not learn or pace a run already in progress when tracking began", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = LoadPaceModules(LoadAddonModules)
      SeedRoutes(addon, env.db, { ["1-2-3"] = Route({ 1, 2, 3 }, { 20, 50, 80 }) })

      -- Boss 1 is already dead at CHALLENGE_MODE_START.
      env.scenario.Kill(1)
      env.scenario.SetForces(60)
      addon.KillTrack.HandleEvent("CHALLENGE_MODE_START")
      Assert.Nil(addon.KillTrack.GetData().paceTarget, "an unknown kill order must not show a pace target")
      env.scenario.SetForces(150)
      env.scenario.Kill(2)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      env.scenario.SetForces(240)
      env.scenario.Kill(3)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      addon.KillTrack.HandleEvent("CHALLENGE_MODE_COMPLETED")
      local routes = GetRoutes(addon, env.db)
      Assert.Equal(CountKeys(routes), 1, "a run with a boss dead at start must not be learned")
      Assert.Equal(routes["1-2-3"].runs, 1, "the stored route must not be touched")

      -- Reload mid-run: no CHALLENGE_MODE_START, first read already shows a kill.
      env.scenario.ResetBosses()
      env.scenario.Kill(2)
      addon.KillTrack.HandleEvent("PLAYER_ENTERING_WORLD")
      env.scenario.Kill(1)
      env.scenario.Kill(3)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      addon.KillTrack.HandleEvent("CHALLENGE_MODE_COMPLETED")
      Assert.Equal(CountKeys(GetRoutes(addon, env.db)), 1, "a run picked up mid-way must not be learned")
    end)
  end)

  test("ForcesPace neither learns nor shows a target when the season is unresolved", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = LoadPaceModules(LoadAddonModules)
      SeedRoutes(addon, env.db, { ["1-2-3"] = Route({ 1, 2, 3 }, { 20, 50, 80 }) })
      local seasonID = addon.SeasonData.GetActiveSeasonID()
      addon.SeasonData.GetActiveSeasonID = function()
        return nil
      end
      env.scenario.ResetBosses()
      addon.KillTrack.HandleEvent("CHALLENGE_MODE_START")
      Assert.Nil(addon.KillTrack.GetData().paceTarget, "an unresolved season must not show a pace target")
      PlayRun(
        addon,
        env.scenario,
        { { boss = 2, forces = 60 }, { boss = 1, forces = 150 }, { boss = 3, forces = 240 } }
      )
      local routes = env.db.forcesPace[seasonID][MAP_ID].routes
      Assert.Equal(CountKeys(routes), 1, "an unresolved season must not learn")
      Assert.Equal(CountKeys(env.db.forcesPace), 1, "no bucket may be created without a season")
    end)
  end)

  test("ForcesPace bounds the stored routes per dungeon by evicting the least recently seen", function()
    local env = BuildEnv({ bossCount = 5 })
    WithGlobals(env.globals, function()
      local addon = LoadPaceModules(LoadAddonModules)
      local routes = {}
      local count = 0
      local function Permute(prefix, rest)
        if count >= 24 then
          return
        end
        if #rest == 0 then
          local key = table.concat(prefix, "-")
          if key ~= "1-2-3-4-5" then
            count = count + 1
            local order = {}
            for k = 1, #prefix do
              order[k] = prefix[k]
            end
            routes[key] = Route(order, { 10, 20, 30, 40, 50 }, { lastSeen = count })
          end
          return
        end
        for i = 1, #rest do
          local nextPrefix, nextRest = {}, {}
          for k = 1, #prefix do
            nextPrefix[k] = prefix[k]
          end
          nextPrefix[#nextPrefix + 1] = rest[i]
          for j = 1, #rest do
            if j ~= i then
              nextRest[#nextRest + 1] = rest[j]
            end
          end
          Permute(nextPrefix, nextRest)
        end
      end
      Permute({}, { 1, 2, 3, 4, 5 })
      local oldestKey = nil
      for key, route in pairs(routes) do
        if route.lastSeen == 1 then
          oldestKey = key
        end
      end
      routes.bogus = { order = "broken" }
      SeedRoutes(addon, env.db, routes)
      PlayRun(addon, env.scenario, {
        { boss = 1, forces = 30 },
        { boss = 2, forces = 60 },
        { boss = 3, forces = 90 },
        { boss = 4, forces = 120 },
        { boss = 5, forces = 150 },
      })
      local stored = GetRoutes(addon, env.db)
      Assert.Equal(CountKeys(stored), 24, "the route count must be trimmed back to the cap")
      Assert.NotNil(stored["1-2-3-4-5"], "the newly committed route must be kept")
      Assert.Nil(stored.bogus, "a malformed route must be evicted first")
      Assert.Nil(stored[oldestKey], "then the least recently seen route is evicted")
    end)
  end)
end

local function RegisterLookupTests(test, Assert, WithGlobals, LoadAddonModules)
  test("ForcesPace target is the minimum next checkpoint across routes matching the kill prefix", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = LoadPaceModules(LoadAddonModules)
      SeedRoutes(addon, env.db, {
        ["1-2-3"] = Route({ 1, 2, 3 }, { 10, 40, 80 }),
        ["1-3-2"] = Route({ 1, 3, 2 }, { 12, 50, 85 }),
        ["2-1-3"] = Route({ 2, 1, 3 }, { 5, 30, 70 }),
      })
      env.scenario.ResetBosses()
      addon.KillTrack.HandleEvent("CHALLENGE_MODE_START")
      Assert.Equal(addon.KillTrack.GetData().paceTarget, 5, "first boss target is the minimum over every route")

      env.scenario.SetForces(30)
      env.scenario.Kill(1)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      Assert.Equal(addon.KillTrack.GetData().paceTarget, 40, "only routes starting with boss 1 remain candidates")

      env.scenario.SetForces(120)
      env.scenario.Kill(3)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      Assert.Equal(addon.KillTrack.GetData().paceTarget, 85, "the single remaining route gives the last target")

      env.scenario.SetForces(260)
      env.scenario.Kill(2)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      Assert.Nil(addon.KillTrack.GetData().paceTarget, "with every boss dead there is no next target")

      env.scenario.ResetBosses()
      addon.KillTrack.HandleEvent("CHALLENGE_MODE_START")
      env.scenario.Kill(3)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      Assert.Nil(addon.KillTrack.GetData().paceTarget, "a kill order no stored route starts with has no target")
    end)
  end)

  test("ForcesPace ignores corrupt persisted routes without failing", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = LoadPaceModules(LoadAddonModules)
      SeedRoutes(addon, env.db, {
        ["1-2-3"] = Route({ 1, 2, 3 }, { 30, 60, 90 }),
        ["2-1-3"] = Route({ 1, 2, 3 }, { 1, 2, 3 }),
        ["1-3-2"] = "not a table",
        ["3-2-1"] = Route({ 3, 2, 1 }, { 1, 2 }),
        ["3-1-2"] = Route({ 3, 1, 2 }, { 1, 2, 300 }),
        ["2-3-1"] = Route({ 2, 3, 1 }, { "1", 2, 3 }),
        ["1-1-3"] = Route({ 1, 1, 3 }, { 1, 2, 3 }),
        ["2-3"] = { order = { 2, 3 }, checkpoints = { 1, 2 } },
      })
      env.scenario.ResetBosses()
      addon.KillTrack.HandleEvent("CHALLENGE_MODE_START")
      Assert.Equal(addon.KillTrack.GetData().paceTarget, 30, "only the valid route may provide a target")

      env.db.forcesPace = "garbage"
      Assert.Nil(addon.KillTrack.GetData().paceTarget, "a malformed root must read as no data")
      PlayRun(
        addon,
        env.scenario,
        { { boss = 1, forces = 60 }, { boss = 2, forces = 150 }, { boss = 3, forces = 240 } }
      )
      local routes = Assert.NotNil(GetRoutes(addon, env.db), "learning must rebuild a malformed storage root")
      Assert.Equal(routes["1-2-3"].checkpoints[1], 20, "the committed run must be stored after the rebuild")
    end)
  end)
end

local function RegisterCriteriaTests(test, Assert, WithGlobals, LoadAddonModules)
  test("ForcesPace secret or unreadable boss criteria never create a kill entry", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = LoadPaceModules(LoadAddonModules)
      env.scenario.ResetBosses()
      addon.KillTrack.HandleEvent("CHALLENGE_MODE_START")

      env.scenario.SetForces(47)
      env.scenario.bosses[1].completed = SECRET
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      Assert.True(
        math.abs(addon.KillTrack.GetData().percent - 47 / 3) < 0.001,
        "enemy forces stay readable through the locked forces criterion"
      )
      env.scenario.SetForces(52)
      env.scenario.bosses[1].completed = false
      env.scenario.unreadable[1] = true
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      Assert.True(
        math.abs(addon.KillTrack.GetData().percent - 52 / 3) < 0.001,
        "an unreadable boss criterion must not block the locked forces read"
      )

      env.scenario.unreadable[1] = nil
      env.scenario.SetForces(60)
      env.scenario.Kill(1)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      env.scenario.SetForces(150)
      env.scenario.Kill(2)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      env.scenario.SetForces(240)
      env.scenario.Kill(3)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      addon.KillTrack.HandleEvent("CHALLENGE_MODE_COMPLETED")

      local route = GetRoutes(addon, env.db)["1-2-3"]
      Assert.Equal(route.checkpoints[1], 20, "boss 1 is recorded only once its state is readable (60/300)")
    end)
  end)

  test("KillTrack keeps enemy forces when a boss fight adds its own weighted bar", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = LoadPaceModules(LoadAddonModules)
      env.scenario.SetForces(90)
      addon.KillTrack.HandleEvent("CHALLENGE_MODE_START")
      Assert.Equal(addon.KillTrack.GetData().percent, 30, "enemy forces is the only weighted bar at start")

      -- The boss bar sits before enemy forces and has the larger total.
      env.scenario.extra[1] = {
        isWeightedProgress = true,
        criteriaID = 7777,
        totalQuantity = 500,
        quantity = 450,
        quantityString = "450",
        completed = false,
      }
      env.scenario.SetForces(120)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      Assert.Equal(addon.KillTrack.GetData().percent, 40, "the locked forces criterion must win over a boss bar")
      Assert.Equal(addon.KillTrack.GetData().total, 300, "the boss bar total must not leak into the forces total")
    end)
  end)

  test("KillTrack picks the weighted criterion with the largest total when no forces ID is locked", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = LoadPaceModules(LoadAddonModules)
      env.scenario.extra[1] = {
        isWeightedProgress = true,
        criteriaID = 7777,
        totalQuantity = 100,
        quantity = 90,
        quantityString = "90",
        completed = false,
      }
      env.scenario.SetForces(150)
      -- Loaded mid-boss: both bars exist on the very first read.
      addon.KillTrack.HandleEvent("PLAYER_ENTERING_WORLD")
      Assert.Equal(addon.KillTrack.GetData().percent, 50, "the largest total must identify enemy forces")
    end)
  end)

  test("KillTrack reads completed enemy forces as 100 percent", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = LoadPaceModules(LoadAddonModules)
      env.scenario.ResetBosses()
      addon.KillTrack.HandleEvent("CHALLENGE_MODE_START")
      env.scenario.SetForces(60)
      env.scenario.Kill(1)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      env.scenario.SetForces(150)
      env.scenario.Kill(2)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")

      -- The game stops updating a completed criterion below its total.
      env.scenario.SetForces(280)
      env.scenario.forces.completed = true
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      Assert.Equal(addon.KillTrack.GetData().percent, 100, "completed enemy forces must read as 100%")

      env.scenario.Kill(3)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      addon.KillTrack.HandleEvent("CHALLENGE_MODE_COMPLETED")
      Assert.Equal(GetRoutes(addon, env.db)["1-2-3"].checkpoints[3], 100, "a kill after completion records 100%")
    end)
  end)
end

local function RegisterKillRowTests(test, Assert, WithGlobals, LoadAddonModules)
  local ROW_FILES = { "isiLive_ui_common.lua", "isiLive_roster_panel_helpers.lua", "isiLive_roster_panel_kill_row.lua" }

  local function StartPacedRun(env, forces)
    local addon = LoadPaceModules(LoadAddonModules, ROW_FILES)
    SeedRoutes(addon, env.db, { ["1-2-3"] = Route({ 1, 2, 3 }, { 40, 70, 90 }) })
    env.scenario.ResetBosses()
    env.scenario.SetForces(forces)
    addon.KillTrack.HandleEvent("CHALLENGE_MODE_START")
    return addon
  end

  test("UpdateKillTrackRow places the pace tick at the learned target and shows the signed delta", function()
    local env = BuildEnv({ total = 10000 })
    WithGlobals(env.globals, function()
      local addon = StartPacedRun(env, 5000)
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      local tick = row.killTrackPaceTick
      Assert.True(tick._shown, "the pace tick must show while a target exists")
      Assert.Equal(tick._points[1][1], "CENTER", "the tick is centred on its target position")
      Assert.Equal(tick._points[1][2], row.killTrackBarContainer, "the tick is anchored to the bar")
      Assert.Equal(tick._points[1][4], 80, "40% of a 200px bar puts the tick at 80px")
      Assert.Equal(row.killTrackPullText._text, "+10.0%", "ahead of pace shows a plus delta with one decimal")
      Assert.Equal(row.killTrackPullText._color[1], addon.UICommon.Colors.GREEN_HINT_TEXT[1], "ahead is green")

      env.scenario.SetForces(3000)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackPullText._text, "-10.0%", "short of pace shows a minus delta")
      Assert.Equal(row.killTrackPullText._color[1], addon.UICommon.Colors.TEXT_ALERT_DANGER[1], "short is red")
      Assert.Equal(row.killTrackPullText._color[2], addon.UICommon.Colors.TEXT_ALERT_DANGER[2], "short is red")

      env.scenario.SetForces(3997)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackPullText._text, "0.0%", "a delta that rounds to zero is on pace without a sign")
      Assert.Equal(row.killTrackPullText._color[1], addon.UICommon.Colors.GREEN_HINT_TEXT[1], "on pace is green")

      local previousSeparator = addon.UICommon.GetDecimalSeparator
      addon.UICommon.GetDecimalSeparator = function()
        return ","
      end
      env.scenario.SetForces(5150)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      addon._RosterInternal.UpdateKillTrackRow(row)
      addon.UICommon.GetDecimalSeparator = previousSeparator
      Assert.Equal(row.killTrackPullText._text, "+11,5%", "the delta uses the addon language decimal separator")
    end)
  end)

  test("UpdateKillTrackRow keeps the live pull text ahead of the pace delta", function()
    local env = BuildEnv({ total = 10000 })
    WithGlobals(env.globals, function()
      local addon = StartPacedRun(env, 5000)
      addon.KillTrack.HandleEvent("PLAYER_REGEN_DISABLED")
      env.scenario.SetForces(5300)
      addon.KillTrack.HandleEvent("SCENARIO_CRITERIA_UPDATE")
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackPullText._text, "+3.00%", "the live pull keeps the text slot")
      Assert.Equal(
        row.killTrackPullText._color[1],
        addon.UICommon.Colors.LIGHT_BLUE_LEVEL_TEXT[1],
        "the pull text keeps its color"
      )
      Assert.True(row.killTrackPaceTick._shown, "the tick stays visible during a pull")
    end)
  end)

  test("UpdateKillTrackRow hides the pace tick and delta when disabled or without a target", function()
    local env = BuildEnv({ total = 10000 })
    WithGlobals(env.globals, function()
      local addon = StartPacedRun(env, 5000)
      local row = NewRow(200)
      env.db.forcesPaceEnabled = false
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.False(row.killTrackPaceTick._shown, "a disabled setting hides the tick")
      Assert.Equal(row.killTrackPullText._text, "", "a disabled setting hides the delta")

      env.db.forcesPaceEnabled = true
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.True(row.killTrackPaceTick._shown, "re-enabling shows the tick on the next refresh")

      env.db.forcesPace = {}
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.False(row.killTrackPaceTick._shown, "no learned route hides the tick")
      Assert.Equal(row.killTrackPullText._text, "", "no learned route leaves the slot empty")

      addon.KillTrack.HandleEvent("CHALLENGE_MODE_COMPLETED")
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.False(row.killTrackPaceTick._shown, "an inactive tracker hides the tick")
    end)
  end)

  test("CreateKillTrackRow creates a hidden cool pace tick inside the bar", function()
    local createFrameStub = BuildCreateFrameStub()
    WithGlobals({ CreateFrame = createFrameStub }, function()
      local addon = LoadAddonModules(ROW_FILES)
      local row = addon._RosterInternal.CreateKillTrackRow(createFrameStub("Frame", nil, nil))
      local tick = Assert.NotNil(row.killTrackPaceTick, "the kill row must create a pace tick")
      Assert.True(tick.hidden, "the pace tick starts hidden")
      Assert.Equal(tick._width, 2, "the pace tick is a thin marker")
      Assert.Equal(tick._height, 10, "the pace tick stays within the bar height")
      local tickColor = addon.UICommon.Colors.MPLUS_TIMELINE_TICK
      Assert.Equal(tick._vertexColor[1], tickColor[1], "the pace tick reuses the cool timeline tick color")
      Assert.Equal(tick._vertexColor[4], tickColor[4], "the pace tick reuses the timeline tick alpha")
    end)
  end)
end

local function RegisterSettingTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Settings forces-pace toggle is default-on, persists and refreshes the kill row", function()
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
        "isiLive_forces_pace.lua",
        "isiLive_settings.lua",
      })
      local fresh = {}
      addon.DBSchema.Sanitize(fresh)
      Assert.True(fresh.forcesPaceEnabled, "the schema default must be on")
      Assert.Equal(type(fresh.forcesPace), "table", "the schema must provide the route storage table")
      Assert.True(addon.ForcesPace.IsEnabled(), "a fresh install reads the setting as on")

      local panel = addon.SettingsPanel.Create({
        getL = function()
          return { SETTINGS_FORCES_PACE = "M+ Killtracker: Forces pace" }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
        onForcesPaceToggle = function(enabled)
          toggles[#toggles + 1] = enabled
        end,
      })

      local check = nil
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "CheckButton" and frame._settingKey == "SETTINGS_FORCES_PACE" then
          check = frame
        end
      end
      check = Assert.NotNil(check, "the display section must render the forces-pace toggle")
      Assert.True(check:GetChecked(), "the toggle must default to on")
      Assert.Nil(db.forcesPaceEnabled, "opening settings must not persist the default")

      check:SetChecked(false)
      check._scripts.OnClick(check)
      Assert.False(db.forcesPaceEnabled, "turning it off must persist false")
      Assert.False(addon.ForcesPace.IsEnabled(), "the module must read the persisted off state")
      Assert.Equal(toggles[1], false, "the toggle must live-apply through onForcesPaceToggle")

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
  RegisterLookupTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCriteriaTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterKillRowTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterSettingTests(test, Assert, WithGlobals, LoadAddonModules)
end
