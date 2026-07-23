-- Standalone CLI tool: simulates the LFG apply -> invite accepted -> group fills
-- chain through Group.HandleGroupRosterUpdate and the queue-join announce
-- pipeline. Verifies:
--   * applying to an LFG group captures the group name BEFORE the roster
--     update arrives
--   * the first roster update that flips isInGroup -> true fires the announce
--     exactly once
--   * subsequent roster updates as the group fills (3/5, 4/5, 5/5) DO NOT
--     re-announce ("kein Doppelspam")
--   * if the local player is the group leader, the announce is suppressed
--     and the pending state is cleared
--   * leaving and rejoining a fresh group does not surface the previous
--     pending info (state was cleared on the first announce)
--
-- End-to-end discipline (CLAUDE.md "Tests & simulators: end-to-end by default"):
-- this simulator drives the REAL ctx.AnnounceQueuedGroupJoin and
-- ctx.CaptureQueueJoinCandidate closures from factory_controllers.lua via
-- FI.InitializeFactoryRuntimeHelpers(ctx) on a real
-- RuntimeState.CreateController. No replica mock of the announce/capture
-- pipeline.
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

-- One shared per-sim state pointer, swapped at the top of each scenario.
-- The dynamic globals (IsInGroup, GetTime) below dereference whatever
-- BuildSim() sets here, so the production closures see live group state
-- without needing per-call scope juggling.
local currentSim = nil

local globals = {
  GetTime = function()
    return currentSim and currentSim.now or 100
  end,
  IsInGroup = function()
    return currentSim ~= nil and currentSim.groupState.inGroup == true
  end,
  IsInRaid = function()
    return false
  end,
  UnitName = function(unit)
    if unit == "player" then
      return "Self"
    end
    return nil
  end,
  GetRealmName = function()
    return "Realm"
  end,
}

local addon

local function ContainsLine(lines, needle)
  for _, line in ipairs(lines) do
    if string.find(line, needle, 1, true) then
      return true
    end
  end
  return false
end

local function BuildSim(opts)
  opts = opts or {}
  local groupState = {
    inGroup = false,
    numMembers = 0,
    wasInGroup = false,
    wasRaidGroup = false,
    isLeader = opts.isLeader == true,
  }
  local statusLineUpdates = 0
  local timers = {}
  local printedLines = {}

  local runtimeState = addon.RuntimeState.CreateController({})

  local ctx = {
    modules = {
      sync = {
        NormalizePlayerKey = function(name, realm)
          return (name or "") .. "-" .. (realm or "")
        end,
      },
    },
    runtimeState = runtimeState,
    locale = "enUS",
    L = {
      UNKNOWN_GROUP = "unknown",
      CHAT_QUEUE_PREFIX = "ISI-Q",
      JOINED_FROM_QUEUE = "joined %s",
    },
    GetRoster = function()
      return {}
    end,
    IsPlayerLeader = function()
      return groupState.isLeader
    end,
    Print = function(msg)
      printedLines[#printedLines + 1] = tostring(msg)
    end,
    UpdateStatusLine = function() end,
  }
  ctx.GetL = function()
    return ctx.L
  end

  -- Bind the production closures (ctx.CaptureQueueJoinCandidate,
  -- ctx.AnnounceQueuedGroupJoin) onto ctx.
  addon._FactoryInternal.InitializeFactoryRuntimeHelpers(ctx)

  local groupOpts = {
    isInGroup = function()
      return groupState.inGroup
    end,
    getNumGroupMembers = function()
      return groupState.numMembers
    end,
    getActiveChallengeMapID = function()
      return nil
    end,
    getWasInGroup = function()
      return groupState.wasInGroup
    end,
    setWasInGroup = function(flag)
      groupState.wasInGroup = flag == true
    end,
    getWasRaidGroup = function()
      return groupState.wasRaidGroup
    end,
    setWasRaidGroup = function(flag)
      groupState.wasRaidGroup = flag == true
    end,
    setWasGroupLeader = function() end,
    getRoster = function()
      return {}
    end,
    setRoster = function() end,
    captureQueueJoinCandidate = function(...)
      return ctx.CaptureQueueJoinCandidate(...)
    end,
    announceQueuedGroupJoin = function()
      return ctx.AnnounceQueuedGroupJoin()
    end,
    setMainFrameVisible = function() end,
    updateLeaderButtons = function() end,
    clearLatestQueueTarget = function() end,
    clearRioBaselineSnapshot = function() end,
    clearKnownUsers = function() end,
    resetInspectAll = function() end,
    resetInspectQueues = function() end,
    updateUI = function()
      statusLineUpdates = statusLineUpdates + 1
    end,
    updateMPlusTeleportButton = function() end,
    clearPendingQueueJoinInfo = function()
      runtimeState.SetPendingQueueJoinInfo(nil)
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
    markIsiLiveUser = function() end,
    setPlayerKeyInfo = function() end,
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
      return groupState.isLeader
    end,
    unitHasIsiLive = function()
      return false
    end,
    applyKnownKeyToRosterEntry = function()
      return false
    end,
    enqueueInspect = function() end,
    sendOwnKeySnapshot = function() end,
    sendIsiLiveHello = function() end,
    sendRefreshRequest = function() end,
    onGroupJoined = function() end,
    onMemberJoinedGroup = function() end,
    timerAfter = function(delay, callback)
      timers[#timers + 1] = { at = (currentSim and currentSim.now or 0) + delay, callback = callback }
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

  local controller = addon.Group.CreateController(groupOpts)

  local sim
  local function advance(seconds)
    sim.now = sim.now + seconds
    local pending = timers
    timers = {}
    for _, timer in ipairs(pending) do
      if timer.at <= sim.now then
        timer.callback()
      else
        timers[#timers + 1] = timer
      end
    end
  end

  sim = {
    groupState = groupState,
    ctx = ctx,
    runtimeState = runtimeState,
    printedLines = printedLines,
    now = 0,
    captureCandidate = function(args)
      ctx.CaptureQueueJoinCandidate(args)
    end,
    rosterUpdate = function()
      controller.HandleGroupRosterUpdate()
      advance(1)
    end,
    statusLineUpdates = function()
      return statusLineUpdates
    end,
  }
  return sim
end

local function PendingGroupName(sim)
  local pending = sim.runtimeState.GetPendingQueueJoinInfo()
  if type(pending) ~= "table" then
    return nil
  end
  return pending.groupName
end

local function AnnouncedFor(sim, groupName)
  return ContainsLine(sim.printedLines, groupName)
end

local function CountAnnounceLines(sim)
  -- Each AnnounceQueuedGroupJoin emits 3 Print calls (separator, body, separator).
  -- The body line carries the localized prefix "ISI-Q | joined <groupName>",
  -- so counting body lines = counting announces.
  local count = 0
  for _, line in ipairs(sim.printedLines) do
    if string.find(line, "ISI-Q | joined", 1, true) then
      count = count + 1
    end
  end
  return count
end

local function Run()
  print("========== LFG apply -> invite -> group full -> announce simulator ==========\n")

  Harness.WithGlobals(globals, function()
    addon = Harness.LoadAddonModules({
      "isiLive_runtime_state.lua",
      "isiLive_factory_controllers.lua",
      "isiLive_group.lua",
    })

    -- ------------------------------------------------------------------
    -- Scenario 1: applicant joins as a non-leader. Announce fires exactly
    -- once even though the roster fills from 2 to 5 in four updates.
    -- ------------------------------------------------------------------
    print("---- Scenario 1: applicant joins, group fills to 5/5 ----")
    do
      local sim = BuildSim({ isLeader = false })
      currentSim = sim

      -- Phase 1: still solo, LFG apply captures the group name.
      sim.captureCandidate({ groupName = "+10 NW Push" })
      Check(
        PendingGroupName(sim) == "+10 NW Push",
        "LFG apply captures the pending group name before the roster update arrives"
      )
      Check(CountAnnounceLines(sim) == 0, "no announce fires while still solo")

      -- Phase 2: invite accepted, GROUP_ROSTER_UPDATE flips isInGroup=true.
      sim.groupState.inGroup = true
      sim.groupState.numMembers = 2
      sim.rosterUpdate()
      Check(CountAnnounceLines(sim) == 1, "first roster update with isInGroup=true announces the queued group join")
      Check(AnnouncedFor(sim, "+10 NW Push"), "announce carries the captured group name")
      Check(PendingGroupName(sim) == nil, "pending info is cleared after the announce")

      -- Phase 3: group fills to 3/5, 4/5, 5/5. NONE of these may re-announce.
      local announceCountAfterJoin = CountAnnounceLines(sim)
      for _, count in ipairs({ 3, 4, 5 }) do
        sim.groupState.numMembers = count
        sim.rosterUpdate()
      end
      Check(
        CountAnnounceLines(sim) == announceCountAfterJoin,
        "no additional announces fire while the group fills from 3/5 to 5/5 (no double-spam)"
      )
    end

    -- ------------------------------------------------------------------
    -- Scenario 2: the local player created the group (is the leader).
    -- The pending info must be discarded silently.
    -- ------------------------------------------------------------------
    print("\n---- Scenario 2: applicant becomes leader (suppressed announce) ----")
    do
      local sim = BuildSim({ isLeader = true })
      currentSim = sim

      sim.captureCandidate({ groupName = "+12 ML Vault" })
      Check(
        PendingGroupName(sim) == "+12 ML Vault",
        "leader-flow still captures the group name (the suppression decision happens at announce time)"
      )

      sim.groupState.inGroup = true
      sim.groupState.numMembers = 2
      sim.rosterUpdate()
      Check(CountAnnounceLines(sim) == 0, "leader does not get a queued-join announce")
      Check(PendingGroupName(sim) == nil, "leader path still clears the pending info")
    end

    -- ------------------------------------------------------------------
    -- Scenario 3: applicant joins, leaves, then re-joins a fresh group
    -- without applying via LFG again. The second join must NOT announce
    -- the stale group name from the first cycle.
    -- ------------------------------------------------------------------
    print("\n---- Scenario 3: leave + rejoin without re-applying (no stale announce) ----")
    do
      local sim = BuildSim({ isLeader = false })
      currentSim = sim

      sim.captureCandidate({ groupName = "+8 Halls" })
      sim.groupState.inGroup = true
      sim.groupState.numMembers = 4
      sim.rosterUpdate()
      Check(CountAnnounceLines(sim) == 1, "first cycle announces once")

      -- leave
      sim.groupState.inGroup = false
      sim.groupState.numMembers = 0
      sim.rosterUpdate()

      -- rejoin a different group, but no new LFG apply happened — pending must
      -- stay nil so no stale group name is surfaced.
      sim.groupState.inGroup = true
      sim.groupState.numMembers = 3
      sim.rosterUpdate()
      Check(CountAnnounceLines(sim) == 1, "rejoin without a fresh LFG apply does not replay the previous announce")
    end

    -- ------------------------------------------------------------------
    -- Scenario 4a: double-capture while solo OVERWRITES the pending entry.
    -- This is the production behaviour — when not in a group,
    -- CaptureQueueJoinCandidate clears the pending entry first, then the
    -- next capture call with a valid groupName replaces it. The replica
    -- mock that previously backed this simulator had the wrong "idempotent
    -- while solo" assumption, which was caught when the simulator was
    -- wired to the real factory_controllers closures.
    -- ------------------------------------------------------------------
    print("\n---- Scenario 4a: double-capture while solo overwrites pending ----")
    do
      local sim = BuildSim({ isLeader = false })
      currentSim = sim

      sim.captureCandidate({ groupName = "+11 NW" })
      Check(PendingGroupName(sim) == "+11 NW", "first solo capture sets the pending group name")

      sim.captureCandidate({ groupName = "+15 BRH" })
      Check(PendingGroupName(sim) == "+15 BRH", "second verified solo capture replaces the pending group name")

      sim.groupState.inGroup = true
      sim.groupState.numMembers = 3
      sim.rosterUpdate()
      Check(AnnouncedFor(sim, "+15 BRH"), "announce uses the most recent solo capture")
    end

    -- ------------------------------------------------------------------
    -- Scenario 4b: once in a group, capture IS idempotent. A subsequent
    -- capture call with a different groupName must not displace the
    -- already-pending entry.
    -- ------------------------------------------------------------------
    print("\n---- Scenario 4b: double-capture while in-group is idempotent ----")
    do
      local sim = BuildSim({ isLeader = false })
      currentSim = sim

      -- Capture solo, then enter group BEFORE the announce-eligible roster
      -- update fires (e.g. invite accept arrives slightly before the next
      -- GROUP_ROSTER_UPDATE).
      sim.captureCandidate({ groupName = "+11 NW" })
      sim.groupState.inGroup = true
      Check(PendingGroupName(sim) == "+11 NW", "first capture sets pending while solo")

      -- Second capture while in-group: production keeps the existing
      -- pending entry untouched (the if-branch guards on GetPendingQueueJoinInfo)
      -- and triggers an announce immediately.
      sim.captureCandidate({ groupName = "+15 BRH" })
      Check(AnnouncedFor(sim, "+11 NW"), "in-group second capture announces the FIRST pending name")
      Check(not AnnouncedFor(sim, "+15 BRH"), "in-group second capture does not surface the new groupName")
      Check(PendingGroupName(sim) == nil, "announce clears the pending entry")
    end
  end)

  if failures > 0 then
    print(string.format("\nLFG join + target-chain simulator failed: %d check(s) failed", failures))
    os.exit(1)
  end

  print("\nLFG join + target-chain simulator passed.")
end

Run()
