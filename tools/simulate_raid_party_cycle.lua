-- Standalone CLI tool: simulates a full Party -> Raid -> Party cycle through
-- Group.HandleGroupRosterUpdate and verifies the side-effect contract:
--   * joining a party fires fresh-join recovery (roster reset, hello, refresh)
--   * promoting the group to a raid hides the main frame and clears all
--     queue / RIO / inspect state in one shot
--   * dropping back to a party clears the known-users cache, because raid
--     mode skips all hello traffic
--   * leaving the group clears the persisted roster snapshot
-- A regression that forgets a single one of those steps would silently break
-- recovery after a wing-clear / raid stop, so this simulator pins the entire
-- transition matrix.
--
-- End-to-end discipline (CLAUDE.md "Tests & simulators: end-to-end by default"):
--   * Group.HandleGroupRosterUpdate is the real production controller (no replica).
--   * RuntimeState is real (RuntimeState.CreateController) — covers
--     setWasInGroup / setWasRaidGroup / setWasGroupLeader / setRoster /
--     getRoster / getWasInGroup / getWasRaidGroup through the production
--     mutator. Replaces the previous closure-only group-state stub.
--   * COMPONENT-ONLY exceptions (justified): IsInGroup / GetNumGroupMembers
--     are WoW globals we cannot drive via real Blizzard events from a
--     standalone Lua process — they are stubbed against an in-memory
--     `state.inGroup` / `state.numMembers` model. The downstream side-effect
--     callbacks (sendIsiLiveHello, sendOwnKeySnapshot, sendRefreshRequest,
--     onGroupJoined, captureQueueJoinCandidate, ...) remain event-recorders;
--     loading the real Sync / KeySync / Inspect / FactoryControllers chain
--     pulls in ~10 transitive deps. The dispatch contract those modules see
--     is pinned here; their internal logic is in dedicated module-level tests.
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

local failures = 0

local function Check(condition, message)
  if condition then
    print("  [CHECK PASS] " .. message)
    return
  end
  failures = failures + 1
  print("  [CHECK FAIL] " .. message)
end

local function FormatBool(value)
  return value == true and "yes" or (value == false and "no" or "-")
end

-- WoW-globals model: only the (extern) Blizzard surface — IsInGroup,
-- GetNumGroupMembers — that we cannot drive via real Blizzard events.
-- Everything else lives in the real RuntimeState below.
local function NewWowGlobalsModel()
  return {
    inGroup = false,
    numMembers = 0,
    knownUsers = { ["Peer-OtherRealm"] = true, ["Tank-OtherRealm"] = true },
  }
end

local function BuildSim()
  local model = NewWowGlobalsModel()
  local events = {}
  local visibility = {} -- list of { visible = bool, reason = string }
  local timers = {}
  local now = 0

  local function record(name, payload)
    events[#events + 1] = { name = name, payload = payload }
  end

  local addon, runtimeState
  Harness.WithGlobals({}, function()
    addon = Harness.LoadAddonModules({
      "isiLive_runtime_state.lua",
      "isiLive_group.lua",
    })
    runtimeState = addon.RuntimeState.CreateController({})
  end)

  local opts = {
    isInGroup = function()
      return model.inGroup
    end,
    getNumGroupMembers = function()
      return model.numMembers
    end,
    getActiveChallengeMapID = function()
      return nil
    end,
    -- Real RuntimeState wiring (replaces the previous closure-only state stubs).
    getWasInGroup = runtimeState.GetWasInGroup,
    setWasInGroup = function(flag)
      runtimeState.SetWasInGroup(flag)
      record("setWasInGroup", flag)
    end,
    getWasRaidGroup = runtimeState.GetWasRaidGroup,
    setWasRaidGroup = function(flag)
      runtimeState.SetWasRaidGroup(flag)
      record("setWasRaidGroup", flag)
    end,
    setWasGroupLeader = function(flag)
      runtimeState.SetWasGroupLeader(flag)
      record("setWasGroupLeader", flag)
    end,
    getRoster = runtimeState.GetRoster,
    setRoster = function(next)
      runtimeState.SetRoster(next)
      record("setRoster", next)
    end,
    captureQueueJoinCandidate = function()
      record("captureQueueJoinCandidate")
    end,
    announceQueuedGroupJoin = function()
      record("announceQueuedGroupJoin")
    end,
    setMainFrameVisible = function(visible, ctx)
      visibility[#visibility + 1] = { visible = visible == true, reason = ctx and ctx.reason or nil }
      record("setMainFrameVisible", { visible = visible, reason = ctx and ctx.reason })
    end,
    isMainFrameVisible = function()
      local latest = visibility[#visibility]
      if latest then
        return latest.visible == true
      end
      return false
    end,
    updateLeaderButtons = function()
      record("updateLeaderButtons")
    end,
    clearLatestQueueTarget = function()
      record("clearLatestQueueTarget")
    end,
    clearRioBaselineSnapshot = function()
      record("clearRioBaselineSnapshot")
    end,
    clearKnownUsers = function()
      model.knownUsers = {}
      record("clearKnownUsers")
    end,
    resetInspectAll = function()
      record("resetInspectAll")
    end,
    resetInspectQueues = function()
      record("resetInspectQueues")
    end,
    updateUI = function()
      record("updateUI")
    end,
    updateMPlusTeleportButton = function()
      record("updateMPlusTeleportButton")
    end,
    clearPendingQueueJoinInfo = function()
      record("clearPendingQueueJoinInfo")
    end,
    getUnitNameAndRealm = function(unit)
      if unit == "player" then
        return "Self", "Realm"
      end
      return nil, nil
    end,
    getUnitClass = function()
      return nil, nil
    end,
    getUnitServerLanguage = function()
      return "??"
    end,
    getOwnedKeystoneSnapshot = function()
      return nil, nil
    end,
    markIsiLiveUser = function()
      record("markIsiLiveUser")
    end,
    setPlayerKeyInfo = function()
      record("setPlayerKeyInfo")
    end,
    getUnitRole = function()
      return nil
    end,
    getPlayerSpecName = function()
      return nil
    end,
    getUnitRio = function()
      return nil
    end,
    unitIsGroupLeader = function()
      return false
    end,
    unitHasIsiLive = function()
      return false
    end,
    applyKnownKeyToRosterEntry = function()
      return false
    end,
    enqueueInspect = function() end,
    sendOwnKeySnapshot = function(force, source)
      record("sendOwnKeySnapshot", { force = force, source = source })
    end,
    sendIsiLiveHello = function(force, source)
      record("sendIsiLiveHello", { force = force, source = source })
    end,
    sendRefreshRequest = function(force)
      record("sendRefreshRequest", { force = force })
    end,
    onGroupJoined = function()
      record("onGroupJoined")
    end,
    onMemberJoinedGroup = function() end,
    timerAfter = function(delay, callback)
      timers[#timers + 1] = { at = now + delay, callback = callback }
    end,
    shouldAutoCloseOnSoloChange = function()
      return false
    end,
    getRaidTransitionBehavior = function()
      return "hide"
    end,
    autoCloseMainFrame = function() end,
    logRuntimeTracef = function() end,
    logRuntimeTrace = function() end,
  }

  local controller = addon.Group.CreateController(opts)

  local function advance(seconds)
    now = now + seconds
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
    model = model,
    runtimeState = runtimeState,
    events = events,
    visibility = visibility,
    advance = advance,
    transition = function(label, mutate)
      mutate(model)
      print("---- " .. label)
      print(
        string.format(
          "  before HandleGroupRosterUpdate: inGroup=%s numMembers=%s wasInGroup=%s wasRaidGroup=%s",
          FormatBool(model.inGroup),
          tostring(model.numMembers),
          FormatBool(runtimeState.GetWasInGroup()),
          FormatBool(runtimeState.GetWasRaidGroup())
        )
      )
      controller.HandleGroupRosterUpdate()
      advance(1)
      print(
        string.format(
          "  after  HandleGroupRosterUpdate: inGroup=%s numMembers=%s wasInGroup=%s wasRaidGroup=%s",
          FormatBool(model.inGroup),
          tostring(model.numMembers),
          FormatBool(runtimeState.GetWasInGroup()),
          FormatBool(runtimeState.GetWasRaidGroup())
        )
      )
    end,
  }
end

local function CountEvents(events, name, fromIndex)
  local n = 0
  for i = fromIndex or 1, #events do
    if events[i].name == name then
      n = n + 1
    end
  end
  return n
end

local function Run()
  print("========== Party -> Raid -> Party cycle simulator ==========\n")

  local sim = BuildSim()

  -- Phase 1: fresh login, no group yet, then a party invite hits.
  sim.transition("Phase 1: party invite (3-man)", function(state)
    state.inGroup = true
    state.numMembers = 3
  end)
  local phase1End = #sim.events
  Check(
    CountEvents(sim.events, "setRoster") >= 1,
    "joining a party rebuilds the roster from scratch (initial setRoster({}))"
  )
  Check(
    CountEvents(sim.events, "captureQueueJoinCandidate") == 1,
    "joining a party captures the queue-join candidate exactly once"
  )
  Check(CountEvents(sim.events, "announceQueuedGroupJoin") == 1, "joining a party fires the queued group join announce")
  Check(CountEvents(sim.events, "onGroupJoined") == 1, "joining a party invokes onGroupJoined hook")
  Check(CountEvents(sim.events, "sendIsiLiveHello") == 1, "joining a party sends the isiLive hello")
  Check(CountEvents(sim.events, "sendOwnKeySnapshot") == 1, "joining a party sends the own keystone snapshot")
  Check(CountEvents(sim.events, "sendRefreshRequest") == 1, "joining a party schedules the deferred refresh request")
  local visibilityForPhase1 = sim.visibility[#sim.visibility]
  Check(
    visibilityForPhase1 and visibilityForPhase1.visible == true and visibilityForPhase1.reason == "queue",
    "joining a party shows the main frame with reason=queue"
  )
  Check(
    sim.runtimeState.GetWasInGroup() == true,
    "wasInGroup is set true after the join transition (real RuntimeState)"
  )
  Check(sim.runtimeState.GetWasRaidGroup() == false, "wasRaidGroup stays false in a 3-man party (real RuntimeState)")

  -- Phase 2: the group expands beyond 5 members -> raid hard-off.
  sim.transition("Phase 2: party expands to 10-man raid", function(state)
    state.numMembers = 10
  end)
  local phase2End = #sim.events
  Check(
    CountEvents(sim.events, "clearPendingQueueJoinInfo", phase1End + 1) == 1,
    "raid transition clears pending queue-join info"
  )
  Check(
    CountEvents(sim.events, "clearLatestQueueTarget", phase1End + 1) == 1,
    "raid transition clears the latest queue target"
  )
  Check(
    CountEvents(sim.events, "clearRioBaselineSnapshot", phase1End + 1) == 1,
    "raid transition clears the RIO baseline snapshot"
  )
  Check(CountEvents(sim.events, "resetInspectAll", phase1End + 1) == 1, "raid transition resets the inspect-all queue")
  Check(
    CountEvents(sim.events, "resetInspectQueues", phase1End + 1) == 1,
    "raid transition resets the per-unit inspect queues"
  )
  Check(CountEvents(sim.events, "setRoster", phase1End + 1) == 1, "raid transition wipes the persisted roster")
  local raidVisibility = sim.visibility[#sim.visibility]
  Check(
    raidVisibility and raidVisibility.visible == false and raidVisibility.reason == "raid",
    "raid transition hides the main frame with reason=raid"
  )
  Check(
    sim.runtimeState.GetWasRaidGroup() == true,
    "wasRaidGroup is true after the 10-man transition (real RuntimeState)"
  )
  Check(
    CountEvents(sim.events, "sendIsiLiveHello", phase1End + 1) == 0,
    "raid mode does NOT send hello traffic during the raid transition itself"
  )
  Check(
    CountEvents(sim.events, "sendOwnKeySnapshot", phase1End + 1) == 0,
    "raid mode does NOT send the keystone snapshot during the raid transition"
  )
  Check(
    CountEvents(sim.events, "sendRefreshRequest", phase1End + 1) == 0,
    "raid mode does NOT schedule a refresh request"
  )

  -- Phase 3: raid drops back to a 4-man party (someone left). The known-users
  -- cache must be cleared because raid mode never updated it.
  sim.transition("Phase 3: raid shrinks back to 4-man party", function(state)
    state.numMembers = 4
  end)
  Check(
    CountEvents(sim.events, "clearKnownUsers", phase2End + 1) == 1,
    "raid -> party recovery clears the known-users cache exactly once"
  )
  Check(
    sim.runtimeState.GetWasRaidGroup() == false,
    "wasRaidGroup is reset after returning to a 5-or-fewer party (real RuntimeState)"
  )
  Check(
    CountEvents(sim.events, "sendIsiLiveHello", phase2End + 1) == 1,
    "raid -> party recovery re-sends hello so peers re-populate"
  )
  Check(
    CountEvents(sim.events, "sendOwnKeySnapshot", phase2End + 1) == 1,
    "raid -> party recovery re-sends the keystone snapshot"
  )
  local raidReturnVisibility = sim.visibility[#sim.visibility]
  Check(
    raidReturnVisibility and raidReturnVisibility.visible == true and raidReturnVisibility.reason == "raid-return",
    "raid -> party recovery restores the frame when it was visible before raid"
  )
  -- joinedNow is false here (already in group), so we should NOT reset the
  -- roster a second time and should NOT call captureQueueJoinCandidate again.
  Check(
    CountEvents(sim.events, "captureQueueJoinCandidate", phase2End + 1) == 0,
    "raid -> party recovery does not re-fire the queue-join capture"
  )
  Check(
    CountEvents(sim.events, "announceQueuedGroupJoin", phase2End + 1) == 0,
    "raid -> party recovery does not re-fire the queued-group announce"
  )

  -- Phase 4: the user leaves the group entirely. The persisted roster, queue
  -- target, and known-users cache should all be cleared so a fresh login state
  -- is reached even if the user immediately requeues.
  local phase3End = #sim.events
  sim.transition("Phase 4: leave group entirely", function(state)
    state.inGroup = false
    state.numMembers = 0
  end)
  Check(sim.runtimeState.GetWasInGroup() == false, "wasInGroup is cleared on group leave (real RuntimeState)")
  -- HandleNoGroup is the off-ramp; it should drop the roster snapshot.
  Check(
    CountEvents(sim.events, "setRoster", phase3End + 1) >= 1,
    "leaving the group clears the persisted roster snapshot"
  )

  if failures > 0 then
    print(string.format("\nRaid-party cycle simulator failed: %d check(s) failed", failures))
    os.exit(1)
  end

  print("\nRaid-party cycle simulator passed.")
end

Run()
