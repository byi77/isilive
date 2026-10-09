---@diagnostic disable: undefined-global
-- One client workload for the CLI simulator and deterministic usecases.
-- Only WoW APIs/widgets/time are mocked; Factory, dispatcher, controllers,
-- nameplate renderer and both ends of KICK parsing are production code.
local Regression = {}
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local rawPcall = pcall
local report = print
local PLATES = 8
local BURST = 1000

local function Prepare(globals, session)
  session.protectedCalls = 0
  session.failedProtectedCalls = 0
  local function RecordResult(ok, ...)
    if not ok then
      session.failedProtectedCalls = session.failedProtectedCalls + 1
    end
    return ok, ...
  end
  globals.pcall = function(...)
    session.protectedCalls = session.protectedCalls + 1
    return RecordResult(rawPcall(...))
  end
  globals.IsiLiveDB.mobNameplateEnabled = true
  -- Recorded file-backed DB, frozen at its generation date. The independent
  -- lifetime gate still checks the real current date in both CI paths.
  local data = {}
  assert(loadfile("data/isiLive_mplus_forces.lua"))("isiLive", data)
  session.forcesDB = data.MPlusForces
  globals.date = function()
    return session.forcesDB.generatedAt
  end
  session.mapID = 249
  session.npcID = 133935
  session.plates = {}
  session.present = {}
  local unitExists, unitGUID = globals.UnitExists, globals.UnitGUID
  globals.UnitExists = function(unit)
    return session.present[unit] == true or unitExists(unit)
  end
  globals.UnitGUID = function(unit)
    if session.present[unit] then
      return "Creature-0-1-1-1-" .. session.npcID .. "-0000000001"
    end
    return unitGUID(unit)
  end
  globals.UnitReaction = function()
    return 3
  end
  globals.UnitHealth = function()
    return session.dead and 0 or 100
  end
  globals.UnitHealthMax = function()
    return 100
  end
  globals.UnitIsDeadOrGhost = function()
    return session.dead == true
  end
  globals.C_ChallengeMode.GetDeathCount = function()
    return session.deaths or 0, session.deaths and 25 or 0
  end
  globals.C_ChallengeMode.IsChallengeModeActive = function()
    return session.active
  end
  globals.C_ChallengeMode.GetActiveChallengeMapID = function()
    return session.active and session.mapID or nil
  end
  globals.C_ChallengeMode.GetMapUIInfo = function()
    return session.forcesDB.dungeonTotal[session.mapID].name, nil, 1800
  end
  globals.C_NamePlate = {
    GetNamePlateForUnit = function(unit)
      return session.present[unit] and session.plates[unit] or nil
    end,
  }
  session.apiFallbackReads = 0
  globals.C_ScenarioInfo.GetUnitCriteriaProgressValues = function()
    session.apiFallbackReads = session.apiFallbackReads + 1
    error("verified DB-backed NPCs must not use the unmeasured E4 fallback")
  end
end

local function Snapshot(session)
  return {
    pcalls = session.protectedCalls,
    failed = session.failedProtectedCalls,
    frames = #session.frames,
    renders = session.fullRenders,
    kicks = session.kickRefreshes,
    auras = session.harmfulReads,
    scenario = session.scenarioReads,
    after = session.afterCalls,
  }
end

local function Phase(session, label, callback, budgets)
  local before = Snapshot(session)
  local memoryEnabled = not package.loaded.luacov
  local beforeHeap, peakHeap, retained
  if memoryEnabled then
    collectgarbage("collect")
    beforeHeap = collectgarbage("count")
    collectgarbage("stop")
  end
  local ok, err = rawPcall(callback)
  if memoryEnabled then
    peakHeap = collectgarbage("count") - beforeHeap
    collectgarbage("restart")
    collectgarbage("collect")
    retained = collectgarbage("count") - beforeHeap
  end
  assert(ok, err)
  local after = Snapshot(session)
  local fields = {}
  for _, key in ipairs({ "pcalls", "failed", "frames", "renders", "kicks", "auras", "scenario", "after" }) do
    local delta = after[key] - before[key]
    fields[#fields + 1] = key .. "=" .. delta
    if budgets and budgets[key] then
      session.assert.True(delta <= budgets[key], label .. ": " .. key .. " exceeds budget " .. budgets[key])
    end
  end
  session.assert.Equal(after.failed - before.failed, 0, label .. ": no swallowed protected-call failures")
  if memoryEnabled then
    if budgets and budgets.retained then
      session.assert.True(retained <= budgets.retained, label .. ": retained heap exceeds mock regression budget")
    end
    fields[#fields + 1] = string.format("heap_kib=%.2f retained_kib=%.2f", peakHeap, retained)
  end
  report("[R5] " .. session.mode .. " " .. label .. " " .. table.concat(fields, " "))
end

local function DeliverKick(session, remain, peer)
  session.sender.Sync.SendKick({
    hasKick = true,
    onCooldown = remain > 0,
    cooldownRemain = remain,
    spellID = 2139,
    force = true,
  })
  local wire = session.messages[#session.messages]
  session.assert.True(wire and wire.payload:find("KICK:", 1, true) == 1, "use the real KICK wire encoder")
  session.DispatchToFrames("CHAT_MSG_ADDON", wire.prefix, wire.payload, wire.channel, "Peer" .. peer .. "-Realm")
end

local function AddPlates(session)
  for index = 1, PLATES do
    local unit = "nameplate" .. index
    session.present[unit] = true
    session.DispatchToFrames("NAME_PLATE_UNIT_ADDED", unit)
  end
  local frames = session.addon.MobNameplate._Test_GetFrames()
  local entry = session.forcesDB.byNpcId[session.npcID]
  local total = session.forcesDB.dungeonTotal[session.mapID].total
  local expected = string.format("%.2f%%", entry.count / total * 100)
  for index = 1, PLATES do
    local frame = frames["nameplate" .. index]
    session.assert.True(frame and frame:IsShown(), "eligible plates must have a visible real overlay")
    session.assert.Equal(frame.text:GetText(), expected, "overlay uses the verified NPC contribution")
  end
end

local function RemovePlates(session)
  for index = 1, PLATES do
    local unit = "nameplate" .. index
    session.present[unit] = nil
    session.DispatchToFrames("NAME_PLATE_UNIT_REMOVED", unit)
  end
  session.assert.Nil(next(session.addon.MobNameplate._Test_GetFrames()), "removed units release all active overlays")
end

function Regression.Run(ctx, mode, beforeWorkload)
  Stress.WithKey(ctx, Fixture, function(session)
    session.assert, session.mode = ctx.assert, mode
    session.addon.MPlusForces = session.forcesDB
    session.assert.Equal(
      session.addon.SeasonData.GetMatchingForcesData(),
      session.forcesDB,
      "use the real season/DB gate"
    )
    session.sender = ctx.load_modules({ "isiLive_sync.lua" })
    session.kickRefreshes = 0
    local panel = session.runtime.rosterPanelController
    local refreshKick = panel.RefreshKickColumn
    panel.RefreshKickColumn = function(...)
      session.kickRefreshes = session.kickRefreshes + 1
      return refreshKick(...)
    end
    -- Blizzard-owned plates are fixture widgets, not addon allocations.
    for index = 1, PLATES do
      local plate = session.globals.CreateFrame("Frame")
      plate.UnitFrame = { healthBar = session.globals.CreateFrame("Frame") }
      session.plates["nameplate" .. index] = plate
    end
    -- Warm every peer and all eight overlay slots before the steady-state budget.
    for peer = 1, 4 do
      DeliverKick(session, 15, peer)
    end
    local framesBeforeWarmup = #session.frames
    AddPlates(session)
    session.assert.Equal(
      #session.frames - framesBeforeWarmup,
      PLATES,
      "warmup creates exactly one overlay per active slot"
    )
    RemovePlates(session)
    session.Advance(1)
    if mode == "hidden" then
      session.runtime.mainFrame:Hide()
      session.Advance(1)
    end
    session.combat = true
    session.DispatchToFrames("PLAYER_REGEN_DISABLED")
    if beforeWorkload then
      beforeWorkload(session)
    end
    local initialHeap
    if not package.loaded.luacov then
      collectgarbage("collect")
      initialHeap = collectgarbage("count")
    end
    Phase(session, "aura-health-burst", function()
      local beforeAuras = session.harmfulReads
      local irrelevant = { addedAuras = { { spellId = 133 } } }
      local relevant = { updatedAuraInstanceIDs = { 7 } }
      for _ = 1, BURST do
        session.DispatchToFrames("UNIT_AURA", "player", irrelevant)
        session.DispatchToFrames("UNIT_AURA", "player", relevant)
        session.DispatchToFrames("UNIT_HEALTH", "party1")
        session.DispatchToFrames("UNIT_HEALTH", "nameplate1")
      end
      session.Advance(0.1)
      session.assert.Equal(
        session.harmfulReads - beforeAuras,
        1,
        "relevant aura burst must perform its one trailing scan"
      )
    end, { pcalls = 31000, frames = 0, after = 1, auras = 1, renders = 1, scenario = 0, retained = 4 })
    Phase(session, "four-kick-peers", function()
      for remain = 14, 0, -1 do
        for peer = 1, 4 do
          DeliverKick(session, remain, peer)
        end
        session.Advance(1)
      end
      for peer = 1, 4 do
        local row = session.runtime.GetRoster()["party" .. peer]
        session.assert.True(row.syncHasKick, "each verified peer retains its kick")
        session.assert.False(row.syncKickOnCooldown, "each final ready packet converges")
      end
    end, { pcalls = 1200, frames = 0, renders = 0, kicks = 90, auras = 15, scenario = 30, after = 0, retained = 32 })
    Phase(session, "nameplate-churn", function()
      for _ = 1, 100 do
        AddPlates(session)
        RemovePlates(session)
      end
    end, { pcalls = 14400, frames = 0, renders = 0, after = 0, auras = 0, scenario = 0, retained = 4 })
    Phase(session, "nameplate-churn-repeat", function()
      for _ = 1, 100 do
        AddPlates(session)
        RemovePlates(session)
      end
    end, { pcalls = 14400, frames = 0, renders = 0, after = 0, auras = 0, scenario = 0, retained = 4 })
    Phase(session, "wipe-recovery", function()
      session.dead = true
      session.deaths = 5
      session.DispatchToFrames("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
      session.assert.Equal(
        session.addon.MplusTimer.GetTimerData().deaths,
        5,
        "the real timer must observe all five wipe deaths"
      )
      for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
        session.DispatchToFrames("UNIT_HEALTH", unit)
      end
      session.Advance(1)
      session.dead = false
      session.combat = false
      session.DispatchToFrames("PLAYER_REGEN_ENABLED")
      session.Advance(1)
      session.assert.True(session.addon.MplusTimer.GetTimerData().running, "a wipe must not end the running key")
    end, { pcalls = 300, frames = 0, renders = 1, kicks = 4, auras = 2, scenario = 5, after = 1, retained = 8 })
    Phase(session, "completion-and-solo", function()
      session.forces = 100
      session.DispatchToFrames("SCENARIO_CRITERIA_UPDATE")
      for _ = 1, BURST do
        session.DispatchToFrames("SPELL_UPDATE_CHARGES")
      end
      session.active = false
      session.DispatchToFrames("CHALLENGE_MODE_COMPLETED")
      session.assert.False(
        session.addon.MplusTimer.GetTimerData().running,
        "completion resets the real timer before solo cleanup"
      )
      session.grouped = false
      session.DispatchToFrames("GROUP_ROSTER_UPDATE")
      session.Advance(30)
      local timer = session.addon.MplusTimer.GetTimerData()
      session.assert.False(timer.running, "completion must stop the timer")
      session.assert.False(session.addon.KillTrack.GetData().active, "completion must clear forces")
      session.assert.Nil(session.runtime.cdTrackerController.GetBResInfo(), "no late BR state after completion")
      session.assert.Equal(session.CountTickers(0.5), 0, "solo owns no forces or kick ticker")
      session.assert.Equal(session.CountTickers(1), 0, "solo owns no CD ticker")
    end, { pcalls = 2700, frames = 0, renders = 2, kicks = 0, auras = 0, scenario = 1, after = 2, retained = 16 })
    if initialHeap then
      collectgarbage("collect")
      local retained = collectgarbage("count") - initialHeap
      report(string.format("[R5] %s lifecycle retained_kib=%.2f budget_kib=64", mode, retained))
      session.assert.True(retained <= 64, "entire lifecycle retained heap exceeds mock regression budget")
    end
    session.assert.Equal(session.failedProtectedCalls, 0, "entire lifecycle has no swallowed protected-call failures")
    session.assert.Equal(session.apiFallbackReads, 0, "E4 is deliberately excluded until live measurement")
  end, Prepare)
end

return Regression
