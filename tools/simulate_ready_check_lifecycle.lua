-- Standalone CLI tool: simulates the full ready-check lifecycle (READY_CHECK →
-- READY_CHECK_CONFIRM → READY_CHECK_FINISHED → hold expiry) and asserts the
-- background-color state of each roster row at every step. Verifies that the
-- 20-second hold actually keeps the row decorated after the ready check ended,
-- and pinpoints whether the bug is on the event-handler side, the state side,
-- or the render side.
--
-- End-to-end discipline (CLAUDE.md "Tests & simulators: end-to-end by default"):
-- the EventHandlers controller is real, BuildDisplayData is real, the
-- per-unit hold timestamps live in real per-call closures. Asserts use the
-- shared Check/exit-1 pattern so a regression breaks CI rather than just
-- printing different colors.
---@diagnostic disable-next-line: undefined-global
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

-- Color constants matching READY_CHECK_BACKGROUND_COLORS in roster.lua.
-- ColorLabel() below uses the same r-channel discriminator.
local LABEL_GREEN = "GREEN(ready)"
local LABEL_RED = "RED(notready)"
local LABEL_YELLOW = "YELLOW(waiting)"
local LABEL_NONE = "(none)"

local function ExpectColor(snap, unit, expectedLabel, message)
  local info = snap[unit] or {}
  local actual
  if type(info.color) == "table" then
    if info.color[1] == 0.08 then
      actual = LABEL_GREEN
    elseif info.color[1] == 0.48 then
      actual = LABEL_RED
    elseif info.color[1] == 0.55 then
      actual = LABEL_YELLOW
    else
      actual = string.format("rgba(%.2f,%.2f,%.2f,%.2f)", info.color[1], info.color[2], info.color[3], info.color[4])
    end
  else
    actual = LABEL_NONE
  end
  Check(actual == expectedLabel, string.format("%s [%s] expected=%s actual=%s", message, unit, expectedLabel, actual))
end

-- Simulated state: ready-check active flag, per-unit hold timestamps,
-- per-unit live status (what GetReadyCheckStatus would return), and a
-- monotonic clock we manually advance between steps.
local sim = {
  now = 100,
  isReadyCheckActive = false,
  readyCheckStatus = {}, -- unit → "ready"|"notready"|"waiting"|nil
  readyUntilByUnit = {},
  declinedUntilByUnit = {},
  scheduledTimers = {}, -- list of { fireAt, callback }
}

local function Tick(deltaSeconds)
  sim.now = sim.now + deltaSeconds
  -- Fire any timer whose deadline has passed (in scheduled order).
  local pending = sim.scheduledTimers
  sim.scheduledTimers = {}
  for _, timer in ipairs(pending) do
    if timer.fireAt <= sim.now then
      timer.callback()
    else
      table.insert(sim.scheduledTimers, timer)
    end
  end
end

local roster = {
  player = { name = "Tank", class = "WARRIOR", role = "TANK" },
  party1 = { name = "Healer", class = "PRIEST", role = "HEALER" },
  party2 = { name = "Dps1", class = "MAGE", role = "DAMAGER" },
  party3 = { name = "Dps2", class = "ROGUE", role = "DAMAGER" },
  party4 = { name = "Dps3", class = "WARLOCK", role = "DAMAGER" },
}

-- rolePriority / unitPriority are referenced when this simulator is later
-- extended to call BuildOrderedRoster directly. Currently kept for future use.

local function BuildController()
  local addon = Harness.LoadAddonModules({ "isiLive_event_handlers.lua" })
  local entryRef = { value = nil }
  local counters = {}
  local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, entryRef, counters, {
    setReadyCheckActive = function(value)
      sim.isReadyCheckActive = value and true or false
    end,
    isReadyCheckActive = function()
      return sim.isReadyCheckActive
    end,
    getTime = function()
      return sim.now
    end,
    getRoster = function()
      return roster
    end,
    setReadyCheckReadyUntil = function(unit, value)
      sim.readyUntilByUnit[unit] = value
    end,
    setReadyCheckDeclinedUntil = function(unit, value)
      sim.declinedUntilByUnit[unit] = value
    end,
    getReadyCheckReadyUntil = function(unit)
      return sim.readyUntilByUnit[unit]
    end,
    getReadyCheckDeclinedUntil = function(unit)
      return sim.declinedUntilByUnit[unit]
    end,
    clearAllReadyCheckReady = function()
      sim.readyUntilByUnit = {}
    end,
    clearAllReadyCheckDeclined = function()
      sim.declinedUntilByUnit = {}
    end,
    clearExpiredReadyCheckReady = function(currentTime)
      local changed = false
      for unit, untilTime in pairs(sim.readyUntilByUnit) do
        if untilTime <= currentTime then
          sim.readyUntilByUnit[unit] = nil
          changed = true
        end
      end
      return changed
    end,
    clearExpiredReadyCheckDeclined = function(currentTime)
      local changed = false
      for unit, untilTime in pairs(sim.declinedUntilByUnit) do
        if untilTime <= currentTime then
          sim.declinedUntilByUnit[unit] = nil
          changed = true
        end
      end
      return changed
    end,
    timerAfter = function(delaySeconds, callback)
      table.insert(sim.scheduledTimers, { fireAt = sim.now + delaySeconds, callback = callback })
    end,
  })
  return controller, counters
end

local function LoadRoster()
  return Harness.LoadAddonModules({ "isiLive_roster.lua" })
end

-- Builds the display data for every roster member with the ready-check hooks
-- routed to the simulated state. Returns a table { unit = backgroundColor|nil }.
local function SnapshotBackgrounds()
  local result = {}
  Harness.WithGlobals({
    GetReadyCheckStatus = function(unit)
      return sim.readyCheckStatus[unit]
    end,
    RAID_CLASS_COLORS = {
      WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
      PRIEST = { r = 1, g = 1, b = 1 },
      MAGE = { r = 0.41, g = 0.8, b = 0.94 },
      ROGUE = { r = 1, g = 0.96, b = 0.41 },
      WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
    },
    UnitIsConnected = function()
      return true
    end,
    -- GetReadyCheckStatusSafe bails out through Validators.IsExistingUnit
    -- before it ever reads the status, so every simulated unit has to exist.
    -- Without this stub the whole matrix silently reports "(none)".
    UnitExists = function(unit)
      return roster[unit] ~= nil
    end,
  }, function()
    local addon = LoadRoster()
    for unit, info in pairs(roster) do
      local data = addon.Roster.BuildDisplayData(info, {
        unit = unit,
        isReadyCheckActive = sim.isReadyCheckActive,
        getReadyCheckReadyUntil = function(u)
          return sim.readyUntilByUnit[u]
        end,
        getReadyCheckDeclinedUntil = function(u)
          return sim.declinedUntilByUnit[u]
        end,
        getTime = function()
          return sim.now
        end,
      })
      result[unit] = {
        status = data.readyCheckStatus,
        color = data.readyCheckBackgroundColor,
        markup = data.readyCheckMarkup,
      }
    end
  end)
  return result
end

local function ColorLabel(color)
  if type(color) ~= "table" then
    return "(none)"
  end
  -- Match against READY_CHECK_BACKGROUND_COLORS in roster.lua
  if color[1] == 0.08 then
    return "GREEN(ready)"
  elseif color[1] == 0.48 then
    return "RED(notready)"
  elseif color[1] == 0.55 then
    return "YELLOW(waiting)"
  end
  return string.format("rgba(%.2f,%.2f,%.2f,%.2f)", color[1], color[2], color[3], color[4])
end

local function PrintSnapshot(label)
  local snap = SnapshotBackgrounds()
  local order = { "player", "party1", "party2", "party3", "party4" }
  print(string.format("---- %s [t=%d, active=%s]", label, sim.now, tostring(sim.isReadyCheckActive)))
  for _, unit in ipairs(order) do
    local info = snap[unit] or {}
    print(
      string.format(
        "  %-7s name=%-7s status=%-9s bg=%-15s readyUntil=%s declinedUntil=%s",
        unit,
        roster[unit].name,
        tostring(info.status or "-"),
        ColorLabel(info.color),
        tostring(sim.readyUntilByUnit[unit] or "-"),
        tostring(sim.declinedUntilByUnit[unit] or "-")
      )
    )
  end
end

local function ResetSim()
  sim.now = 100
  sim.isReadyCheckActive = false
  sim.readyCheckStatus = {}
  sim.readyUntilByUnit = {}
  sim.declinedUntilByUnit = {}
  sim.scheduledTimers = {}
end

local function ExpectColors(snap, mapping, label)
  for unit, expected in pairs(mapping) do
    ExpectColor(snap, unit, expected, label)
  end
end

local function PrintAndSnapshot(snapshotLabel)
  PrintSnapshot(snapshotLabel)
  return SnapshotBackgrounds()
end

local function ScenarioHappyPath()
  print("\n========== Scenario 1: happy path (mixed responses) ==========")
  ResetSim()
  local controller = BuildController()

  local snap = PrintAndSnapshot("0. baseline (no ready check)")
  ExpectColors(snap, {
    player = LABEL_NONE,
    party1 = LABEL_NONE,
    party2 = LABEL_NONE,
    party3 = LABEL_NONE,
    party4 = LABEL_NONE,
  }, "baseline → no decoration")

  controller:Dispatch("READY_CHECK")
  for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
    sim.readyCheckStatus[unit] = "waiting"
  end
  snap = PrintAndSnapshot("1. READY_CHECK fired (all waiting)")
  ExpectColors(snap, {
    player = LABEL_YELLOW,
    party1 = LABEL_YELLOW,
    party2 = LABEL_YELLOW,
    party3 = LABEL_YELLOW,
    party4 = LABEL_YELLOW,
  }, "READY_CHECK fired → every unit yellow (waiting)")

  Tick(2)
  sim.readyCheckStatus.player = "ready"
  controller:Dispatch("READY_CHECK_CONFIRM", "player", "ready")
  sim.readyCheckStatus.party1 = "ready"
  controller:Dispatch("READY_CHECK_CONFIRM", "party1", "ready")
  sim.readyCheckStatus.party2 = "notready"
  controller:Dispatch("READY_CHECK_CONFIRM", "party2", "notready")
  -- party3 and party4 remain "waiting" (no answer)
  snap = PrintAndSnapshot("2. confirms received (player+party1=ready, party2=notready, party3+4=no answer)")
  ExpectColors(snap, {
    player = LABEL_GREEN,
    party1 = LABEL_GREEN,
    party2 = LABEL_RED,
    party3 = LABEL_YELLOW,
    party4 = LABEL_YELLOW,
  }, "confirms applied → ready=green, notready=red, no-answer=yellow")

  Tick(3)
  -- READY_CHECK_FINISHED simulates the WoW client clearing live status:
  for unit in pairs(sim.readyCheckStatus) do
    sim.readyCheckStatus[unit] = nil
  end
  controller:Dispatch("READY_CHECK_FINISHED")
  snap = PrintAndSnapshot("3. READY_CHECK_FINISHED → hold should be active for 20s")
  ExpectColors(snap, {
    player = LABEL_GREEN,
    party1 = LABEL_GREEN,
    party2 = LABEL_RED,
    party3 = LABEL_RED,
    party4 = LABEL_RED,
  }, "FINISHED → hold active: ready stays green, notready+no-answer = red (declined-promotion)")

  Tick(5)
  snap = PrintAndSnapshot("4. +5s into hold (still within 20s window)")
  ExpectColors(snap, {
    player = LABEL_GREEN,
    party1 = LABEL_GREEN,
    party2 = LABEL_RED,
  }, "+5s into hold → colors persist")

  Tick(10)
  snap = PrintAndSnapshot("5. +15s into hold (still within 20s window)")
  ExpectColors(snap, {
    player = LABEL_GREEN,
    party2 = LABEL_RED,
  }, "+15s into hold → colors still persist")

  Tick(6)
  snap = PrintAndSnapshot("6. +21s after FINISHED (hold expired, timers fired)")
  ExpectColors(snap, {
    player = LABEL_NONE,
    party1 = LABEL_NONE,
    party2 = LABEL_NONE,
    party3 = LABEL_NONE,
    party4 = LABEL_NONE,
  }, "hold expired → all decorations cleared")
end

local function ScenarioRapidRecheck()
  print("\n========== Scenario 2: a second READY_CHECK fires while a hold is still active ==========")
  ResetSim()
  local controller = BuildController()

  controller:Dispatch("READY_CHECK")
  sim.readyCheckStatus.player = "ready"
  controller:Dispatch("READY_CHECK_CONFIRM", "player", "ready")
  sim.readyCheckStatus.party1 = "notready"
  controller:Dispatch("READY_CHECK_CONFIRM", "party1", "notready")
  for unit in pairs(sim.readyCheckStatus) do
    sim.readyCheckStatus[unit] = nil
  end
  controller:Dispatch("READY_CHECK_FINISHED")
  local snap = PrintAndSnapshot("1. first ready check finished → hold active")
  ExpectColors(snap, {
    player = LABEL_GREEN,
    party1 = LABEL_RED,
  }, "first finished → ready=green, notready=red")

  Tick(5)
  -- Second ready check starts mid-hold. The current code wipes all holds
  -- via ResetReadyCheckDeclinedTracking — verify behavior is what we want.
  controller:Dispatch("READY_CHECK")
  for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
    sim.readyCheckStatus[unit] = "waiting"
  end
  snap = PrintAndSnapshot("2. second READY_CHECK fired (holds wiped, all waiting again)")
  ExpectColors(snap, {
    player = LABEL_YELLOW,
    party1 = LABEL_YELLOW,
    party2 = LABEL_YELLOW,
    party3 = LABEL_YELLOW,
    party4 = LABEL_YELLOW,
  }, "second READY_CHECK wipes holds and re-yellows everyone")
end

local function ScenarioFinishWithNoConfirms()
  print("\n========== Scenario 3: nobody answers the ready check (all 'waiting' on FINISHED) ==========")
  ResetSim()
  local controller = BuildController()

  controller:Dispatch("READY_CHECK")
  for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
    sim.readyCheckStatus[unit] = "waiting"
  end
  local snap = PrintAndSnapshot("1. READY_CHECK fired (all waiting)")
  ExpectColors(snap, {
    player = LABEL_YELLOW,
    party4 = LABEL_YELLOW,
  }, "READY_CHECK fired → all yellow")

  Tick(30) -- typical WoW 30s ready-check timeout
  for unit in pairs(sim.readyCheckStatus) do
    sim.readyCheckStatus[unit] = nil
  end
  controller:Dispatch("READY_CHECK_FINISHED")
  snap = PrintAndSnapshot("2. READY_CHECK_FINISHED → 'no answer' members are promoted to declined → red")
  -- Per the current implementation, unanswered units are promoted to
  -- DECLINED on FINISHED. The "grau = keine antwort" UX wish from the
  -- original spec is intentionally NOT met by the production code.
  ExpectColors(snap, {
    player = LABEL_RED,
    party1 = LABEL_RED,
    party2 = LABEL_RED,
    party3 = LABEL_RED,
    party4 = LABEL_RED,
  }, "all-no-answer + FINISHED → all red (declined-promotion, NOT gray)")
end

local function ScenarioRenderAfterFinish()
  print("\n========== Scenario 4: a generic UI re-render happens 1s AFTER FINISHED ==========")
  print("(this pins the user-reported 'background overwritten right after readycheck' regression)")
  ResetSim()
  local controller = BuildController()

  controller:Dispatch("READY_CHECK")
  sim.readyCheckStatus.player = "ready"
  controller:Dispatch("READY_CHECK_CONFIRM", "player", "ready")
  for unit in pairs(sim.readyCheckStatus) do
    sim.readyCheckStatus[unit] = nil
  end
  controller:Dispatch("READY_CHECK_FINISHED")
  local snap = PrintAndSnapshot("1. READY_CHECK_FINISHED → hold active")
  ExpectColor(snap, "player", LABEL_GREEN, "post-FINISHED player still green")

  -- Simulate any other event triggering a render: GROUP_ROSTER_UPDATE,
  -- INSPECT_READY etc would all call BuildDisplayData via RenderRoster.
  -- This snapshot is exactly what a re-render would compute right after.
  Tick(1)
  snap = PrintAndSnapshot("2. +1s, simulating a generic UI rerender (e.g. GROUP_ROSTER_UPDATE)")
  ExpectColor(snap, "player", LABEL_GREEN, "+1s rerender does not wipe the hold")

  Tick(2)
  snap = PrintAndSnapshot("3. +3s, another rerender")
  ExpectColor(snap, "player", LABEL_GREEN, "+3s rerender does not wipe the hold")

  Tick(15)
  snap = PrintAndSnapshot("4. +18s, just before hold expiry")
  ExpectColor(snap, "player", LABEL_GREEN, "+18s (still within 20s) hold persists through repeated renders")
end

ScenarioHappyPath()
ScenarioRapidRecheck()
ScenarioFinishWithNoConfirms()
ScenarioRenderAfterFinish()

if failures > 0 then
  print(string.format("\nReady-check lifecycle simulator failed: %d check(s) failed", failures))
  os.exit(1)
end

print("\nReady-check lifecycle simulator passed.")
