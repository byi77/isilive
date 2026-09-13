-- Standalone CLI tool: simulates CHALLENGE_MODE_COMPLETED + CHALLENGE_MODE_RESET
-- through the real EventHandlers controller and verifies the post-key
-- side-effect contract:
--   * MplusTimer / KillTrack / CombatEvents each receive the event exactly once
--   * notifyPostChallengeSync() fires once on completion, broadcasting final state
--   * the post-run delayed refresh is scheduled via timerAfter (initial delay)
--   * the main frame is auto-opened only when (isInGroup AND shouldAutoOpenMainFrameOnKeyEnd)
--   * raid mode hard-off suppresses every side effect (mirrors key-start contract)
--   * CHALLENGE_MODE_RESET (depleted / abandoned) follows the same lifecycle path
-- Symmetric counterpart to simulate_key_start_lifecycle.lua. State leaks between
-- a finished key and the next one are subtle and only show up after the second
-- run of the session — this gate makes them visible at preflight time.
--
-- End-to-end discipline (CLAUDE.md "Tests & simulators: end-to-end by default"):
--   * EventHandlers controller is real (controller:Dispatch path).
--   * RuntimeState is real (RuntimeState.CreateController) — covers
--     getPendingPostChallengeRefresh / setPendingPostChallengeRefresh through
--     the production mutator. No more closure-only refresh-state stub.
--   * COMPONENT-ONLY exceptions (justified): handleMplusTimerEvent,
--     handleKillTrackEvent, handleCombatEventsEvent, notifyPostChallengeSync,
--     and the UI refresh callbacks remain stubs. Loading the real Mplus timer /
--     KillTrack / CombatEvents / Sync modules pulls in ~12 transitive deps
--     (frame APIs, scenario data, UnitGUID, sync wiring). The dispatch-order
--     contract those modules see is covered here; their internal logic is in
--     dedicated module-level scenarios under testmodul/.
---@diagnostic disable: undefined-global
local io = io
---@diagnostic disable-next-line: undefined-global
local load = load

local function LoadLocal(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  local chunk, err = (loadstring or load)(source, "@" .. path)
  assert(chunk, err)
  return chunk()
end

local Harness = LoadLocal("testmodul/isilive_test_harness.lua")
local Fixtures = LoadLocal("testmodul/isilive_test_fixtures.lua")

local failures = 0

local function Check(condition, message)
  if condition then
    print("  [CHECK PASS] " .. message)
    return
  end
  failures = failures + 1
  print("  [CHECK FAIL] " .. message)
end

local function Append(list, value)
  list[#list + 1] = value
end

local function Count(list, value)
  local n = 0
  for _, item in ipairs(list or {}) do
    if item == value then
      n = n + 1
    end
  end
  return n
end

local function IndexOf(list, value)
  for i, item in ipairs(list or {}) do
    if item == value then
      return i
    end
  end
  return nil
end

local function FormatEvents(events)
  if #events == 0 then
    return "-"
  end
  return table.concat(events, " -> ")
end

local function BuildController(opts)
  opts = opts or {}
  local events = {}
  local visibility = {}
  local timers = {}
  local now = 0
  local state = {
    timerEvents = {},
    killTrackEvents = {},
    combatEvents = {},
    postChallengeSyncs = 0,
    statusLineRefreshes = 0,
    leaderButtonRefreshes = 0,
    teleportButtonRefreshes = 0,
  }

  local globals = {
    -- Stub C_ChallengeMode so ResolveCompletedRunInfo returns a deterministic
    -- runInfo. The real handler reads the 12.0 ChallengeCompletionInfo table
    -- (GetCompletionInfo was removed in 12.0.0) and the simulator records the call.
    C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        return 2649
      end,
      GetChallengeCompletionInfo = function()
        return {
          mapChallengeModeID = 2649,
          level = 1234567,
          time = 1500000,
          onTime = opts.onTime ~= false,
          keystoneUpgradeLevels = 1,
        }
      end,
    },
  }

  local controller
  local runtimeState
  local pendingMutatorStats = { calls = 0, lastValue = nil, sawNonNil = false }
  Harness.WithGlobals(globals, function()
    local addon = Harness.LoadAddonModules({
      "isiLive_runtime_state.lua",
      "isiLive_event_handlers.lua",
    })
    runtimeState = addon.RuntimeState.CreateController({})
    controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      -- Real RuntimeState wiring (replaces fixture's closure-only refresh
      -- stub). The set-path is wrapped with a counter spy so we can assert
      -- the production mutator is hit even when the value is nil (which a
      -- nil-pushing array would silently drop in Lua).
      getPendingPostChallengeRefresh = runtimeState.GetPendingPostChallengeRefresh,
      setPendingPostChallengeRefresh = function(value)
        pendingMutatorStats.calls = pendingMutatorStats.calls + 1
        pendingMutatorStats.lastValue = value
        if value ~= nil then
          pendingMutatorStats.sawNonNil = true
        end
        return runtimeState.SetPendingPostChallengeRefresh(value)
      end,
      isRaidGroup = function()
        return opts.inRaid == true
      end,
      isInGroup = function()
        return opts.inGroup ~= false
      end,
      isRosterCollapsed = function()
        return opts.rosterCollapsed == true
      end,
      shouldAutoOpenMainFrameOnKeyEnd = function()
        return opts.autoOpen ~= false
      end,
      setMainFrameVisible = function(visible)
        Append(events, "ui.visible=" .. tostring(visible))
        visibility[#visibility + 1] = visible == true
      end,
      handleMplusTimerEvent = function(event)
        Append(events, "timer." .. tostring(event))
        state.timerEvents[#state.timerEvents + 1] = event
      end,
      handleKillTrackEvent = function(event)
        Append(events, "killTrack." .. tostring(event))
        state.killTrackEvents[#state.killTrackEvents + 1] = event
      end,
      handleCombatEventsEvent = function(event)
        Append(events, "combatEvents." .. tostring(event))
        state.combatEvents[#state.combatEvents + 1] = event
      end,
      notifyPostChallengeSync = function()
        Append(events, "sync.notifyPostChallenge")
        state.postChallengeSyncs = state.postChallengeSyncs + 1
      end,
      updateStatusLine = function()
        Append(events, "ui.statusLine")
        state.statusLineRefreshes = state.statusLineRefreshes + 1
      end,
      updateLeaderButtons = function()
        Append(events, "ui.leaderButtons")
        state.leaderButtonRefreshes = state.leaderButtonRefreshes + 1
      end,
      updateMPlusTeleportButton = function()
        Append(events, "ui.teleportButton")
        state.teleportButtonRefreshes = state.teleportButtonRefreshes + 1
      end,
      timerAfter = function(delay, callback)
        Append(events, "timer.after=" .. tostring(delay))
        timers[#timers + 1] = { at = now + (delay or 0), callback = callback }
      end,
      logRuntimeTrace = function(message)
        Append(events, "trace:" .. tostring(message))
      end,
      logRuntimeTracef = function(_fmt)
        Append(events, "tracef")
      end,
    })
  end)

  local function advance(seconds)
    now = now + (seconds or 0)
    local pending = timers
    timers = {}
    for _, timer in ipairs(pending) do
      if timer.at <= now then
        timer.callback()
      else
        timers[#timers + 1] = timer
      end
    end
  end

  return {
    controller = controller,
    dispatch = function(event)
      Harness.WithGlobals(globals, function()
        controller:Dispatch(event)
      end)
    end,
    advance = advance,
    events = events,
    visibility = visibility,
    state = state,
    runtimeState = runtimeState,
    pendingMutatorStats = pendingMutatorStats,
    pendingTimers = function()
      return #timers
    end,
  }
end

local function PrintSummary(label, sim)
  print("---- " .. label)
  print("  events                = " .. FormatEvents(sim.events))
  print("  postChallengeSyncs    = " .. tostring(sim.state.postChallengeSyncs))
  print("  statusLineRefreshes   = " .. tostring(sim.state.statusLineRefreshes))
  print("  pendingTimers         = " .. tostring(sim.pendingTimers()))
end

local function CheckCommonCompletionLifecycle(sim, eventName)
  Check(Count(sim.events, "timer." .. eventName) == 1, "M+ timer receives " .. eventName .. " exactly once")
  Check(Count(sim.events, "killTrack." .. eventName) == 1, "KillTrack receives " .. eventName .. " exactly once")
  Check(Count(sim.events, "combatEvents." .. eventName) == 1, "CombatEvents receives " .. eventName .. " exactly once")
  Check(sim.state.postChallengeSyncs == 1, "post-challenge sync notify fires exactly once on " .. eventName)
  Check(sim.state.statusLineRefreshes == 1, "status line refreshes once on " .. eventName)
  Check(sim.pendingTimers() >= 1, eventName .. " schedules at least one delayed post-run refresh via timerAfter")

  local timerIndex = IndexOf(sim.events, "timer." .. eventName) or 0
  local killIndex = IndexOf(sim.events, "killTrack." .. eventName) or 0
  local combatIndex = IndexOf(sim.events, "combatEvents." .. eventName) or 0
  local syncIndex = IndexOf(sim.events, "sync.notifyPostChallenge") or 0
  Check(
    timerIndex > 0 and killIndex > timerIndex and combatIndex > killIndex,
    "module dispatch order is preserved: timer -> KillTrack -> CombatEvents"
  )
  Check(syncIndex > combatIndex, "post-challenge sync fires AFTER the per-module dispatches")
end

local function ScenarioInTimeComplete()
  print("\n========== Scenario 1: in-time CHALLENGE_MODE_COMPLETED ==========")
  local sim = BuildController({ onTime = true, autoOpen = true })
  sim.dispatch("CHALLENGE_MODE_COMPLETED")
  PrintSummary("after CHALLENGE_MODE_COMPLETED", sim)
  CheckCommonCompletionLifecycle(sim, "CHALLENGE_MODE_COMPLETED")
  Check(
    #sim.visibility == 1 and sim.visibility[1] == true,
    "in-group + auto-open=true shows the main frame after key completion"
  )
end

local function ScenarioDepletedReset()
  print("\n========== Scenario 2: depleted / aborted CHALLENGE_MODE_RESET ==========")
  local sim = BuildController({ onTime = false, autoOpen = true })
  sim.dispatch("CHALLENGE_MODE_RESET")
  PrintSummary("after CHALLENGE_MODE_RESET", sim)
  CheckCommonCompletionLifecycle(sim, "CHALLENGE_MODE_RESET")
end

local function ScenarioRaidHardOff()
  print("\n========== Scenario 3: raid mode hard-off suppresses completion ==========")
  local sim = BuildController({ inRaid = true, autoOpen = true })
  sim.dispatch("CHALLENGE_MODE_COMPLETED")
  PrintSummary("after CHALLENGE_MODE_COMPLETED", sim)
  Check(#sim.events == 0, "raid mode suppresses every completion side effect")
  Check(sim.state.postChallengeSyncs == 0, "raid mode does NOT trigger post-challenge sync")
  Check(sim.state.statusLineRefreshes == 0, "raid mode does NOT refresh the status line")
  Check(#sim.visibility == 0, "raid mode does NOT mutate main frame visibility")
end

local function ScenarioAutoOpenDisabled()
  print("\n========== Scenario 4: auto-open disabled keeps frame hidden ==========")
  local sim = BuildController({ autoOpen = false })
  sim.dispatch("CHALLENGE_MODE_COMPLETED")
  PrintSummary("after CHALLENGE_MODE_COMPLETED", sim)
  CheckCommonCompletionLifecycle(sim, "CHALLENGE_MODE_COMPLETED")
  Check(#sim.visibility == 0, "auto-open=false leaves the main frame untouched after key completion")
end

local function ScenarioOutOfGroup()
  print("\n========== Scenario 5: solo-completion does NOT trigger main-frame open ==========")
  local sim = BuildController({ inGroup = false, autoOpen = true })
  sim.dispatch("CHALLENGE_MODE_COMPLETED")
  PrintSummary("after CHALLENGE_MODE_COMPLETED", sim)
  CheckCommonCompletionLifecycle(sim, "CHALLENGE_MODE_COMPLETED")
  Check(#sim.visibility == 0, "isInGroup=false suppresses the auto-open even when shouldAutoOpenMainFrameOnKeyEnd=true")
end

local function ScenarioBackToBackKeys()
  print("\n========== Scenario 6: back-to-back keys — second completion is clean ==========")
  local sim = BuildController({ onTime = true, autoOpen = true })
  sim.dispatch("CHALLENGE_MODE_COMPLETED")
  local firstSyncCount = sim.state.postChallengeSyncs
  local firstStatusCount = sim.state.statusLineRefreshes
  local refreshAfterFirst = sim.runtimeState.GetPendingPostChallengeRefresh()

  sim.dispatch("CHALLENGE_MODE_START")
  sim.dispatch("CHALLENGE_MODE_COMPLETED")
  PrintSummary("after second CHALLENGE_MODE_COMPLETED", sim)

  Check(
    sim.state.postChallengeSyncs == firstSyncCount + 1,
    "second key completion fires post-challenge sync EXACTLY one more time (no batched leak)"
  )
  Check(
    sim.state.statusLineRefreshes >= firstStatusCount + 1,
    "second key completion refreshes status line at least once more"
  )
  Check(
    Count(sim.events, "timer.CHALLENGE_MODE_COMPLETED") == 2,
    "MplusTimer receives CHALLENGE_MODE_COMPLETED twice across the two keys"
  )
  -- Real production wiring: COMPLETED schedules the delayed refresh via
  -- timerAfter; on fire RunDelayedPostChallengeRefresh calls
  -- SetPendingPostChallengeRefresh(ctx, nil) (line 251 in challenge.lua),
  -- which routes through the real RuntimeState mutator wrapped by our spy.
  Check(refreshAfterFirst == nil, "first completion alone does not mutate pending refresh marker (timer not yet fired)")
  local callsBeforeAdvance = sim.pendingMutatorStats.calls
  sim.advance(10) -- fire the post-completion refresh timer (scheduled at +5s)
  Check(
    sim.pendingMutatorStats.calls > callsBeforeAdvance,
    "real RuntimeState.SetPendingPostChallengeRefresh is hit when the post-completion refresh timer fires"
  )
  Check(
    sim.pendingMutatorStats.lastValue == nil,
    "the timer-fire mutator call sets the pending marker back to nil (RunDelayedPostChallengeRefresh non-raid path)"
  )
end

local function Run()
  ScenarioInTimeComplete()
  ScenarioDepletedReset()
  ScenarioRaidHardOff()
  ScenarioAutoOpenDisabled()
  ScenarioOutOfGroup()
  ScenarioBackToBackKeys()

  if failures > 0 then
    print(string.format("\nKey-completion lifecycle simulator failed: %d check(s) failed", failures))
    os.exit(1)
  end

  print("\nKey-completion lifecycle simulator passed.")
end

Run()
