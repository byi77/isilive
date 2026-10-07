---@diagnostic disable: undefined-global
local Helpers = {}
local report = print

-- This clock models the WoW timer API, not addon logic. Every callback belongs
-- to a real production timer. No wall-clock waits or replica controllers.
function Helpers.BuildClock(session)
  local timers = {}
  local function Schedule(delay, callback, interval)
    local timer = { due = session.now + delay, callback = callback, interval = interval }
    function timer:Cancel()
      self.cancelled = true
    end
    timers[#timers + 1] = timer
    return timer
  end
  session.afterCalls = 0
  session.timerApi = {
    After = function(delay, callback)
      session.afterCalls = session.afterCalls + 1
      Schedule(delay, callback)
    end,
    NewTimer = function(delay, callback)
      return Schedule(delay, callback)
    end,
    NewTicker = function(interval, callback)
      return Schedule(interval, callback, interval)
    end,
  }
  function session.Advance(seconds)
    local target = session.now + seconds
    local callbacks = 0
    while true do
      local nextTimer
      for _, timer in ipairs(timers) do
        if not timer.cancelled and timer.due <= target and (not nextTimer or timer.due < nextTimer.due) then
          nextTimer = timer
        end
      end
      if not nextTimer then
        break
      end
      callbacks = callbacks + 1
      assert(callbacks < 100000, "production timers must not schedule an infinite immediate loop")
      session.now = nextTimer.due
      if nextTimer.interval then
        nextTimer.due = nextTimer.due + nextTimer.interval
      else
        nextTimer.cancelled = true
      end
      nextTimer.callback(nextTimer)
    end
    session.now = target
    for index = #timers, 1, -1 do
      if timers[index].cancelled then
        table.remove(timers, index)
      end
    end
  end
  function session.CountTickers(interval)
    local count = 0
    for _, timer in ipairs(timers) do
      if not timer.cancelled and timer.interval == interval then
        count = count + 1
      end
    end
    return count
  end
end

function Helpers.BuildGlobals(buildGlobals)
  local globals, db = buildGlobals()
  local session = {
    now = 100,
    active = false,
    grouped = true,
    combat = false,
    raid = false,
    forces = 10,
    scenarioReads = 0,
    harmfulReads = 0,
    messages = {},
    errors = {},
    fullRenders = 0,
    cooldownReads = 0,
  }
  Helpers.BuildClock(session)
  globals.C_Timer = session.timerApi
  -- Models the client's event delivery: every created frame that registered
  -- an event receives it through its own OnEvent script, exactly as in WoW.
  session.frames = {}
  local createFrame = globals.CreateFrame
  local parents = {}
  globals.CreateFrame = function(frameType, name, parent, ...)
    local frame = createFrame(frameType, name, parent, ...)
    session.frames[#session.frames + 1] = frame
    parents[frame] = parent
    return frame
  end
  -- The frame stub fires only its own OnShow; the client also fires OnShow on
  -- the shown children of a frame that becomes visible.
  function session.FireChildrenOnShow(parent)
    for _, frame in ipairs(session.frames) do
      local onShow = parents[frame] == parent and frame:GetScript("OnShow")
      if onShow then
        onShow(frame)
      end
    end
  end
  function session.DispatchToFrames(event, ...)
    local delivered = 0
    for _, frame in ipairs(session.frames) do
      local registered = type(frame._registeredEvents) == "table" and frame._registeredEvents[event]
      local onEvent = registered and frame:GetScript("OnEvent")
      if onEvent then
        delivered = delivered + 1
        onEvent(frame, event, ...)
      end
    end
    return delivered
  end
  globals.GetTime = function()
    return session.now
  end
  globals.GetWorldElapsedTime = function()
    if session.elapsedUnavailable then
      error("test: elapsed unavailable")
    end
    return 1, session.now - 100
  end
  globals.IsInGroup = function(category)
    return session.grouped and category ~= 2
  end
  globals.IsInRaid = function()
    return session.raid
  end
  globals.GetNumGroupMembers = function()
    return session.raid and 20 or (session.grouped and 5 or 0)
  end
  globals.InCombatLockdown = function()
    return session.combat
  end
  local names = { player = "Tester", party1 = "Peer1", party2 = "Peer2", party3 = "Peer3", party4 = "Peer4" }
  globals.UnitExists = function(unit)
    return names[unit] ~= nil and (unit == "player" or session.grouped)
  end
  globals.UnitName = function(unit)
    return names[unit], "Realm"
  end
  globals.UnitFullName = globals.UnitName
  globals.GetUnitName = function(unit)
    return names[unit] and (names[unit] .. "-Realm") or nil
  end
  globals.UnitGUID = function(unit)
    return names[unit] and ("Player-1-" .. names[unit]) or nil
  end
  globals.UnitClass = function(unit)
    if names[unit] then
      return "Mage", "MAGE", 8
    end
  end
  globals.UnitIsDeadOrGhost = function()
    return false
  end
  globals.GetInstanceInfo = function()
    return "Test dungeon", "party", 8, "Mythic Keystone", 5, false, false, 2662
  end
  globals.C_ChallengeMode.GetActiveChallengeMapID = function()
    return session.active and 2662 or nil
  end
  globals.C_ChallengeMode.GetActiveKeystoneInfo = function()
    return 12, {}, 0
  end
  globals.C_ChallengeMode.GetMapUIInfo = function()
    return "Test dungeon", 2662, 1800
  end
  globals.C_ChallengeMode.GetDeathCount = function()
    return 0, 0
  end
  globals.C_Spell.GetSpellCooldown = function()
    session.cooldownReads = session.cooldownReads + 1
    return { startTime = 0, duration = 0, isEnabled = true, modRate = 1 }
  end
  globals.C_Spell.GetSpellCharges = function()
    return { currentCharges = 1, maxCharges = 1 }
  end
  globals.C_UnitAuras = {
    GetAuraDataByIndex = function(_, _, filter)
      if filter == "HARMFUL" then
        session.harmfulReads = session.harmfulReads + 1
      end
      return nil
    end,
    GetPlayerAuraBySpellID = function()
      return nil
    end,
  }
  globals.C_ScenarioInfo = {
    GetScenarioStepInfo = function()
      session.scenarioReads = session.scenarioReads + 1
      if session.scenarioUnavailable then
        error("test: scenario unavailable")
      end
      return { numCriteria = 1 }
    end,
    GetCriteriaInfo = function()
      return {
        criteriaID = 9001,
        isWeightedProgress = true,
        quantity = session.forces,
        quantityString = tostring(session.forces),
        totalQuantity = 100,
        completed = false,
      }
    end,
  }
  globals.C_ChatInfo.SendAddonMessage = function(prefix, payload, channel)
    session.messages[#session.messages + 1] = { prefix = prefix, payload = payload, channel = channel }
    return true
  end
  globals.print = function(message)
    if tostring(message):find("Event dispatch failed", 1, true) then
      session.errors[#session.errors + 1] = message
    end
  end
  db.autoOpenMainFrameOnKeyEnd = false
  return globals, session
end

function Helpers.WithKey(ctx, fixtures, callback)
  local globals, session = Helpers.BuildGlobals(fixtures.buildGlobals)
  ctx.with_globals(globals, function()
    local addon = ctx.load_modules(fixtures.moduleFiles())
    local runtime = addon.Factory.InitializeAddon("isiLive", addon, { returnContext = true })
    session.addon, session.runtime, session.globals = addon, runtime, globals
    local gated = runtime.eventFrame:GetScript("OnEvent")
    function session.Dispatch(event, ...)
      gated(runtime.eventFrame, event, ...)
    end
    session.Dispatch("PLAYER_LOGIN")
    session.Dispatch("GROUP_ROSTER_UPDATE")
    session.active = true
    session.Dispatch("CHALLENGE_MODE_START")
    session.Advance(5)
    local originalRender = runtime.rosterPanelController.RenderRoster
    runtime.rosterPanelController.RenderRoster = function(...)
      session.fullRenders = session.fullRenders + 1
      return originalRender(...)
    end
    ctx.assert.True(addon.MplusTimer.GetTimerData().running, "stress fixture must start through the real dispatcher")
    ctx.assert.Equal(addon.KillTrack.GetData().percent, 10, "forces fixture must hydrate through the real key start")
    callback(session)
    ctx.assert.Equal(#session.errors, 0, "protected dispatch must report zero errors throughout the workload")
  end)
end

-- CPU and heap readings describe this Lua mock workload, never in-game FPS.
-- No guessed time budget: correctness is asserted with deterministic counts.
function Helpers.Measure(label, count, callback)
  -- Coverage instrumentation changes CPU/heap costs and must keep GC running.
  if package.loaded.luacov then
    callback()
    report(string.format("[STRESS] %s operations=%d (coverage; timing disabled)", label, count))
    return
  end
  collectgarbage("collect")
  local before = collectgarbage("count")
  local started = os.clock()
  collectgarbage("stop")
  local ok, err = pcall(callback)
  local heap = collectgarbage("count") - before
  local elapsed = os.clock() - started
  collectgarbage("restart")
  collectgarbage("collect")
  local retained = collectgarbage("count") - before
  report(
    string.format(
      "[STRESS] %s operations=%d cpu_ms=%.1f heap_kib=%.1f retained_kib=%.1f",
      label,
      count,
      elapsed * 1000,
      heap,
      retained
    )
  )
  if not ok then
    error(err)
  end
end

return Helpers
