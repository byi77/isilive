---@diagnostic disable: undefined-global
-- Audit round 7, wiring findings: dependencies the factory owned but never
-- handed through eventHandlersContext -> ControllerWiring -> EventHandlers
-- BuildContext, plus the M+ timer that walking out of a running key lost.
-- Every test boots the real factory and pumps events through the real gated
-- dispatcher (testmodul/isilive_test_mplus_stress_helpers.lua).
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

local SYNC_PREFIX = "ISILIVE"

-- Collects chat lines printed through the client's print while fn runs.
local function CapturePrints(fn)
  local lines = {}
  local previous = _G.print
  _G.print = function(...)
    local parts = {}
    for index = 1, select("#", ...) do
      parts[#parts + 1] = tostring((select(index, ...)))
    end
    lines[#lines + 1] = table.concat(parts, " ")
    return previous(...)
  end
  local ok, err = pcall(fn)
  _G.print = previous
  if not ok then
    error(err, 0)
  end
  return lines
end

local function CountPayloads(session, pattern, fromIndex)
  local count = 0
  for index = fromIndex or 1, #session.messages do
    local message = session.messages[index]
    if message.prefix == SYNC_PREFIX and tostring(message.payload):find(pattern) then
      count = count + 1
    end
  end
  return count
end

-- Runs fn(capture) and returns the payloads the real sender put on the wire.
local function CaptureSentPayloads(session, fn)
  local first = #session.messages + 1
  fn()
  session.Advance(1)
  local payloads = {}
  for index = first, #session.messages do
    payloads[#payloads + 1] = session.messages[index].payload
  end
  return payloads
end

-- Boots the real factory the way the client does: SavedVariables are nil
-- while the addon files run and are restored before ADDON_LOADED.
local function BootFromSavedVariables(ctx, prepare, callback)
  local globals, session = Stress.BuildGlobals(Fixture.buildGlobals)
  local savedDB = globals.IsiLiveDB
  if type(prepare) == "function" then
    prepare(globals, session, savedDB)
  end
  ctx.with_globals(globals, function()
    _G.IsiLiveDB = nil
    local addon = ctx.load_modules(Fixture.moduleFiles())
    local runtime
    session.initPrints = CapturePrints(function()
      runtime = addon.Factory.InitializeAddon("isiLive", addon, { returnContext = true })
    end)
    session.addon, session.runtime, session.globals = addon, runtime, globals
    local gated = runtime.eventFrame:GetScript("OnEvent")
    function session.Dispatch(event, ...)
      gated(runtime.eventFrame, event, ...)
    end
    _G.IsiLiveDB = savedDB
    session.loadedPrints = CapturePrints(function()
      session.Dispatch("ADDON_LOADED", "isiLive")
    end)
    session.Dispatch("PLAYER_LOGIN")
    session.Dispatch("GROUP_ROSTER_UPDATE")
    session.Advance(5)
    callback(session, savedDB)
    ctx.assert.Equal(#session.errors, 0, "protected dispatch must report zero errors throughout the workload")
  end)
end

local function FindReadyCheckButton(session)
  for _, frame in ipairs(session.frames) do
    if type(frame.GetAttribute) == "function" and frame:GetAttribute("macrotext") == "/readycheck" then
      return frame
    end
  end
  return nil
end

return function(test, ctx)
  local Assert = ctx.assert

  test("R7 L-1 peer Power Infusion announce reaches the local chat without a dispatch error", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local spellID = session.addon.SpellManifest.powerInfusion
      -- Wire bytes come from the real sender, then go into the real receiver
      -- through the gated CHAT_MSG_ADDON dispatcher as if Peer1 sent them.
      local payloads = CaptureSentPayloads(session, function()
        session.addon.Sync.SendPowerInfusionAnnounce({ caster = "Peer1", recipient = "Peer2", spellID = spellID })
      end)
      local piPayload
      for _, payload in ipairs(payloads) do
        if tostring(payload):find("^PI:") then
          piPayload = payload
        end
      end
      Assert.NotNil(piPayload, "the real sender must emit a PI payload")
      local lines = CapturePrints(function()
        session.Dispatch("CHAT_MSG_ADDON", SYNC_PREFIX, piPayload, "PARTY", "Peer1-Realm")
      end)
      Assert.Equal(#session.errors, 0, "a peer PI announce must not crash the dispatcher")
      local template = session.runtime.L.COMBAT_CHAT_PI_RECEIVED
      local expected = "isiLive: " .. string.format(template, "Peer1", "Peer2")
      local found = false
      for _, line in ipairs(lines) do
        if line == expected then
          found = true
        end
      end
      Assert.True(found, "the peer PI announce must be rendered locally: " .. table.concat(lines, " | "))
    end)
  end)

  test("R7 L-2 leader buttons queued in combat are applied when combat ends", function()
    local leader = false
    Stress.WithParty(ctx, Fixture, function(session)
      -- Hidden frame: the post-combat full render is skipped, so only the
      -- pending-leader-button drain can bring the buttons up to date.
      session.runtime.mainFrame:Hide()
      local button = Assert.NotNil(FindReadyCheckButton(session), "the real ready-check button must exist")
      local enabledCalls = {}
      local originalSetEnabled = button.SetEnabled
      button.SetEnabled = function(self, value)
        enabledCalls[#enabledCalls + 1] = value
        if type(originalSetEnabled) == "function" then
          return originalSetEnabled(self, value)
        end
      end

      session.combat = true
      session.Dispatch("PLAYER_REGEN_DISABLED")
      leader = true
      session.Dispatch("GROUP_ROSTER_UPDATE")
      session.Advance(1)
      Assert.Equal(#enabledCalls, 0, "leader buttons must not be touched during combat lockdown")

      session.combat = false
      session.Dispatch("PLAYER_REGEN_ENABLED")
      session.Advance(1)
      Assert.True(#enabledCalls >= 1, "the queued leader-button update must run after combat")
      Assert.Equal(enabledCalls[#enabledCalls], true, "the new leader gets enabled leader buttons")
    end, function(globals)
      globals.UnitIsGroupLeader = function(unit)
        return unit == "player" and leader
      end
    end)
  end)

  test("R7 L-3 a saved unlocked main frame position is restored on ADDON_LOADED", function()
    BootFromSavedVariables(ctx, function(_globals, _session, savedDB)
      savedDB.lockMainFramePosition = false
    end, function(session)
      Assert.True(session.runtime.mainFrame:IsMovable(), "a saved unlock must make the main frame movable")
    end)
    BootFromSavedVariables(ctx, function(_globals, _session, savedDB)
      savedDB.lockMainFramePosition = true
    end, function(session)
      Assert.False(session.runtime.mainFrame:IsMovable(), "a saved lock must keep the main frame fixed")
    end)
  end)

  test("R7 L-4 a peer REQSYNC is answered with a forced TARGET snapshot", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local payloads = CaptureSentPayloads(session, function()
        session.addon.Sync.SendRefreshRequest({ force = true })
      end)
      local request
      for _, payload in ipairs(payloads) do
        if payload == "REQSYNC" or tostring(payload):find("^REQSYNC") then
          request = payload
        end
      end
      Assert.NotNil(request, "the real sender must emit a REQSYNC payload")
      -- Leave every fan-out window behind before the peer asks.
      session.Advance(120)
      local first = #session.messages + 1
      session.Dispatch("CHAT_MSG_ADDON", SYNC_PREFIX, request, "PARTY", "Peer1-Realm")
      session.Advance(1)
      -- The status line may re-send TARGET on its own; only the fan-out tags
      -- the payload with the "reqsync" source.
      Assert.Equal(
        CountPayloads(session, "^TARGET:%d+:%d+:%d+:reqsync", first),
        1,
        "the REQSYNC fan-out must include one forced TARGET"
      )
    end)
  end)

  test("R7 L-5 a fresh group join delays its REQSYNC until the group has settled", function()
    Stress.WithParty(ctx, Fixture, function(session)
      session.grouped = false
      session.Dispatch("GROUP_ROSTER_UPDATE")
      session.Advance(5)
      local first = #session.messages + 1
      session.grouped = true
      session.Dispatch("GROUP_ROSTER_UPDATE")
      Assert.Equal(CountPayloads(session, "^REQSYNC", first), 0, "the join REQSYNC must not go out at once")
      session.Advance(0.6)
      Assert.Equal(CountPayloads(session, "^REQSYNC", first), 1, "the join REQSYNC goes out after the delay")
    end)
  end)

  test("R7 F-5 the loaded hint is printed once after ADDON_LOADED in the saved locale", function()
    BootFromSavedVariables(ctx, function(_globals, _session, savedDB)
      savedDB.locale = "deDE"
    end, function(session)
      local deHint = session.runtime.locales.deDE.LOADED_HINT
      local enHint = session.runtime.locales.enUS.LOADED_HINT
      Assert.True(deHint ~= enHint, "fixture precondition: the hints differ per locale")
      local version = session.runtime.GetAddonVersionRaw()
      local expected = "isiLive: " .. string.format(deHint, version)
      local english = "isiLive: " .. string.format(enHint, version)
      local function Count(lines, wanted)
        local count = 0
        for _, line in ipairs(lines) do
          if line == wanted then
            count = count + 1
          end
        end
        return count
      end
      Assert.Equal(Count(session.initPrints, english), 0, "file load must not print the English hint")
      Assert.Equal(Count(session.loadedPrints, expected), 1, "ADDON_LOADED prints the hint once in German")
      local again = CapturePrints(function()
        session.Dispatch("ADDON_LOADED", "isiLive")
      end)
      Assert.Equal(Count(again, expected), 0, "a second ADDON_LOADED must not repeat the hint")
    end)
  end)

  local function WithWalkableKey(callback)
    local outside = false
    Stress.WithKey(ctx, Fixture, function(session)
      -- Outside the instance Blizzard reports no active challenge map.
      function session.WalkOut()
        outside = true
        session.active = false
        session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
        session.Advance(1)
      end
      function session.WalkIn()
        outside = false
        session.active = true
        session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
        session.Advance(1)
      end
      -- The client fires PLAYER_ENTERING_WORLD inside the dungeon after
      -- login; it is what records "was in a party instance".
      session.Dispatch("PLAYER_ENTERING_WORLD", true, false)
      session.Advance(1)
      Assert.True(session.addon.MplusTimer.IsRunning(), "the key runs inside the dungeon")
      callback(session)
    end, function(globals)
      globals.GetInstanceInfo = function()
        if outside then
          return "Dornogal", "none", 0, "", 0, false, false, 2552
        end
        return "Test dungeon", "party", 8, "Mythic Keystone", 5, false, false, 2662
      end
    end)
  end

  test("R7 G-1 the M+ timer comes back when the player walks back into a running key", function()
    WithWalkableKey(function(session)
      local timer = session.addon.MplusTimer
      session.Advance(60)
      session.WalkOut()
      Assert.False(timer.IsRunning(), "outside the instance the timer display is cleared")
      session.Advance(30)
      session.WalkIn()
      local data = timer.GetTimerData()
      Assert.True(data.running, "re-entering the running key must restore the timer")
      Assert.Equal(data.timeLimit, 1800, "the restored run keeps the key's time limit")
      Assert.Equal(data.keyLevel, 12, "the restored run keeps the key level")
      Assert.True(data.timer >= 90, "the restored run continues from Blizzard's elapsed time")
    end)
  end)

  test("R7 G-1 a real reset or completion after walking out still clears the run for good", function()
    WithWalkableKey(function(session)
      local timer = session.addon.MplusTimer
      session.WalkOut()
      -- Key abandoned while outside: the real event clears the restore.
      session.Dispatch("CHALLENGE_MODE_RESET")
      session.WalkIn()
      Assert.False(timer.IsRunning(), "a real CHALLENGE_MODE_RESET must not be undone by re-entry")
    end)
    WithWalkableKey(function(session)
      local timer = session.addon.MplusTimer
      session.Dispatch("CHALLENGE_MODE_COMPLETED")
      session.WalkOut()
      session.WalkIn()
      Assert.False(timer.IsRunning(), "a completed key must not come back after walking out and in")
    end)
  end)
end
