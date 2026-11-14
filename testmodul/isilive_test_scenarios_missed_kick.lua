---@diagnostic disable: undefined-global, undefined-field

-- Missed-kick alert ("Kick ins Leere", rule 236). Every flow boots the real
-- factory and pumps the client events through the real gated dispatcher
-- (testmodul/isilive_test_mplus_stress_helpers.lua): the own interrupt arrives
-- as UNIT_SPELLCAST_SUCCEEDED, hostile interrupts as UNIT_SPELLCAST_INTERRUPTED
-- or UNIT_SPELLCAST_CHANNEL_STOP, and the verdict runs from the production
-- C_Timer callback driven by session.Advance. Only the WoW API surface is
-- stubbed: class/spec, UnitCanAttack, PlaySound and the SOUNDKIT table.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

-- The sound registry, the DB schema and the simulation tablet are not part of
-- the default fixture; the alert sound and the E6 tablet action need them.
local FixtureWithSound = {
  buildGlobals = Fixture.buildGlobals,
  moduleFiles = function()
    local files = Fixture.moduleFiles()
    table.insert(files, 1, "isiLive_simulation_tablet.lua")
    table.insert(files, 1, "isiLive_db_schema.lua")
    table.insert(files, 1, "isiLive_sound_registry.lua")
    return files
  end,
}

local COUNTERSPELL = 2139
local REBUKE = 96231
local AVENGERS_SHIELD = 31935
-- Test stand-in for the client's SOUNDKIT constant; only "is a number" matters.
local RAID_WARNING_KIT = 8959
local ALERT_TEXT = "MISSED KICK"

-- opts: { alert, onlyInKey, sound, class = "MAGE"|"PALADIN" }
local function Prepare(opts)
  opts = opts or {}
  return function(globals, session)
    session.sounds = {}
    local db = globals.IsiLiveDB
    db.missedKickAlertEnabled = opts.alert ~= false
    db.missedKickOnlyInKey = opts.onlyInKey
    db.missedKickSound = opts.sound == true
    if opts.class == "PALADIN" then
      local unitClass = globals.UnitClass
      globals.UnitClass = function(unit)
        if unit == "player" then
          return "Paladin", "PALADIN", 2
        end
        return unitClass(unit)
      end
      globals.GetSpecializationInfo = function()
        return 66, "Protection", "desc", 0, "TANK"
      end
    end
    -- Party tokens are friendly, everything else in these flows is hostile.
    globals.UnitCanAttack = function(_, unit)
      return not (unit == "player" or unit:find("^party%d") ~= nil)
    end
    globals.SOUNDKIT = { RAID_WARNING = RAID_WARNING_KIT }
    globals.PlaySound = function(kit, channel)
      session.sounds[#session.sounds + 1] = { kit = kit, channel = channel }
      return true, #session.sounds
    end
  end
end

local function AlertFrame(session)
  for _, frame in ipairs(session.frames) do
    local text = type(frame) == "table" and rawget(frame, "text") or nil
    if type(text) == "table" and type(text.GetText) == "function" and text:GetText() == ALERT_TEXT then
      return frame
    end
  end
  return nil
end

local function AlertShown(session)
  local frame = AlertFrame(session)
  return frame ~= nil and frame:IsShown() == true
end

-- The stub animation group never finishes, so a shown alert is hidden by hand
-- before the next step to observe a fresh show.
local function ResetAlert(session)
  local frame = AlertFrame(session)
  if frame then
    frame:Hide()
  end
  session.sounds = {}
end

local function EnterCombat(session)
  session.combat = true
  session.Dispatch("PLAYER_REGEN_DISABLED")
end

-- Client-style delivery: the event reaches only frames that registered it
-- (with their unit filter), so the static registration is part of the path.
local function Deliver(session, event, ...)
  local delivered = session.DispatchToFrames(event, ...)
  assert(delivered == 1, event .. " must reach exactly one registered isiLive frame, got " .. tostring(delivered))
end

local function Kick(session, spellID)
  Deliver(session, "UNIT_SPELLCAST_SUCCEEDED", "player", "kick-cast", spellID or COUNTERSPELL)
end

local function HostileInterrupt(session, unit, interruptedBy)
  Deliver(session, "UNIT_SPELLCAST_INTERRUPTED", unit or "nameplate3", "hostile-cast", 12345, interruptedBy, 1)
end

local function ChannelStop(session, unit, interruptedBy)
  Deliver(session, "UNIT_SPELLCAST_CHANNEL_STOP", unit, "hostile-channel", 777, interruptedBy, 2)
end

-- Past every kick's cooldown and the one-second sound spam window, so each
-- step starts from a ready interrupt.
local function NextStep(session)
  session.Advance(30)
  ResetAlert(session)
end

return function(test, ctx)
  local Assert = ctx.assert

  test("Missed kick alert shows after an own kick without any hostile interrupt", function()
    Stress.WithKey(ctx, FixtureWithSound, function(session)
      EnterCombat(session)
      Kick(session)
      Assert.False(AlertShown(session), "the verdict waits for the window")
      session.Advance(0.3)
      Assert.True(AlertShown(session), "a kick without any hostile interrupt raises the missed-kick notice")
      Assert.Equal(#session.sounds, 0, "the sound stays off by default (Pattern B)")
    end, Prepare())
  end)

  test("Missed kick alert plays its sound on the configured channel when enabled", function()
    Stress.WithKey(ctx, FixtureWithSound, function(session)
      EnterCombat(session)
      Kick(session)
      session.Advance(0.3)
      Assert.True(AlertShown(session), "the notice shows")
      Assert.Equal(#session.sounds, 1, "missedKickSound plays the cue once")
      Assert.Equal(session.sounds[1].kit, RAID_WARNING_KIT, "the cue is the registry SoundKit")
      Assert.Equal(session.sounds[1].channel, "Master", "the cue follows soundOutputChannel (default Master)")

      NextStep(session)
      session.globals.IsiLiveDB.soundOutputChannel = "SFX" -- sound-ok
      Kick(session)
      session.Advance(0.3)
      Assert.Equal(session.sounds[1].channel, "SFX", "the cue follows the configured output channel") -- sound-ok
    end, Prepare({ sound = true }))
  end)

  test("Missed kick alert stays silent when a hostile interrupt lands inside the window", function()
    Stress.WithKey(ctx, FixtureWithSound, function(session)
      EnterCombat(session)
      Kick(session)
      -- One frame later (16 ms, measured in-game) still lands.
      session.Advance(0.016)
      HostileInterrupt(session, "nameplate3")
      session.Advance(0.5)
      Assert.False(AlertShown(session), "an interrupt inside the window means the kick landed")

      NextStep(session)
      Kick(session)
      session.Advance(0.016)
      ChannelStop(session, "boss1", "Player-1-Tester")
      session.Advance(0.5)
      Assert.False(AlertShown(session), "an interrupted hostile channel counts as a landed kick")

      NextStep(session)
      Kick(session)
      -- 39 ms: a teammate's interrupt the damage meter did not count as the
      -- own (probe log 2026-11-14).
      session.Advance(0.039)
      HostileInterrupt(session, "nameplate3")
      session.Advance(0.5)
      Assert.True(AlertShown(session), "an interrupt after the window does not rescue the kick")
    end, Prepare())
  end)

  test("Missed kick alert counts a teammate interrupt inside the window as landed", function()
    Stress.WithKey(ctx, FixtureWithSound, function(session)
      EnterCombat(session)
      Kick(session)
      HostileInterrupt(session, "target", "Player-1-Peer1")
      session.Advance(0.5)
      Assert.False(AlertShown(session), "a simultaneous teammate kick suppresses the alert")

      -- Same frame (equal GetTime), the interrupt event first: still landed.
      NextStep(session)
      HostileInterrupt(session, "focus", "Player-1-Peer2")
      Kick(session)
      session.Advance(0.5)
      Assert.False(AlertShown(session), "an interrupt in the same frame as the own cast counts as landed")
    end, Prepare())
  end)

  test("Missed kick alert counts a late kick after a teammate interrupt as missed", function()
    Stress.WithKey(ctx, FixtureWithSound, function(session)
      EnterCombat(session)
      -- A teammate interrupted the cast 30 ms before the own kick.
      HostileInterrupt(session, "target", "Player-1-Peer1")
      session.Advance(0.03)
      Kick(session)
      session.Advance(0.5)
      Assert.True(AlertShown(session), "a kick 30 ms after a teammate's interrupt came late and is missed")

      -- 200 ms late.
      NextStep(session)
      HostileInterrupt(session, "focus", "Player-1-Peer2")
      session.Advance(0.2)
      Kick(session)
      session.Advance(0.5)
      Assert.True(AlertShown(session), "a kick 200 ms after a teammate's interrupt is missed")

      -- An interrupt inside the window after the own kick still lands it.
      NextStep(session)
      HostileInterrupt(session, "focus", "Player-1-Peer2")
      session.Advance(0.2)
      Kick(session)
      session.Advance(0.016)
      HostileInterrupt(session, "nameplate3")
      session.Advance(0.5)
      Assert.False(AlertShown(session), "the own interrupt event after the cast decides, not the earlier one")
    end, Prepare())
  end)

  test("Missed kick alert ignores friendly interrupts and naturally ended channels", function()
    Stress.WithKey(ctx, FixtureWithSound, function(session)
      EnterCombat(session)
      Kick(session)
      HostileInterrupt(session, "party2")
      HostileInterrupt(session, "player")
      ChannelStop(session, "nameplate4", nil)
      session.Advance(0.3)
      Assert.True(AlertShown(session), "party casts and a channel that simply ended are no interrupt of the kick")
    end, Prepare())
  end)

  test("Missed kick alert treats a secret interruptedBy as an interrupt without touching it", function()
    local secret, secretGlobals = ctx.fixtures.MakeStrictSecret("string")
    Stress.WithKey(ctx, FixtureWithSound, function(session)
      EnterCombat(session)
      Kick(session)
      HostileInterrupt(session, "nameplate7", secret)
      session.Advance(0.5)
      Assert.False(AlertShown(session), "a hostile interrupt with a secret interruptedBy still counts by its timestamp")

      NextStep(session)
      Kick(session)
      ChannelStop(session, "nameplate7", secret)
      session.Advance(0.5)
      Assert.False(AlertShown(session), "a channel stop with a secret interruptedBy counts as interrupted")

      NextStep(session)
      Kick(session)
      HostileInterrupt(session, secret, secret)
      session.Advance(0.5)
      Assert.False(AlertShown(session), "a secret unit token cannot be filtered and only suppresses the alert")
    end, function(globals, session)
      Prepare()(globals, session)
      for key, value in pairs(secretGlobals) do
        globals[key] = value
      end
    end)
  end)

  test("Missed kick alert stays off with the setting off", function()
    Stress.WithKey(ctx, FixtureWithSound, function(session)
      EnterCombat(session)
      Kick(session)
      session.Advance(0.5)
      Assert.False(AlertShown(session), "missedKickAlertEnabled defaults to off and gates everything")
      Assert.Equal(#session.sounds, 0, "no sound without the alert")
    end, Prepare({ alert = false, sound = true }))
  end)

  test("Missed kick alert stays off outside combat", function()
    Stress.WithKey(ctx, FixtureWithSound, function(session)
      Kick(session)
      session.Advance(0.5)
      Assert.False(AlertShown(session), "a kick outside combat never alerts")
    end, Prepare())
  end)

  test("Missed kick alert only-in-key option limits the alert to running keys", function()
    Stress.WithParty(ctx, FixtureWithSound, function(session)
      EnterCombat(session)
      Kick(session)
      session.Advance(0.5)
      Assert.False(AlertShown(session), "outside a key the default only-in-key option keeps the alert off")

      NextStep(session)
      session.globals.IsiLiveDB.missedKickOnlyInKey = false
      Kick(session)
      session.Advance(0.5)
      Assert.True(AlertShown(session), "with only-in-key off a missed kick in any fight alerts")
    end, Prepare())
  end)

  test("Missed kick alert skips excluded kicks that work without a target cast", function()
    Stress.WithKey(ctx, FixtureWithSound, function(session)
      EnterCombat(session)
      Kick(session, AVENGERS_SHIELD)
      session.Advance(0.8)
      Assert.False(AlertShown(session), "Avenger's Shield is excluded: it still hits without a cast")

      NextStep(session)
      Kick(session, REBUKE)
      session.Advance(0.3)
      Assert.True(AlertShown(session), "the same paladin's Rebuke into nothing alerts")
    end, Prepare({ class = "PALADIN" }))
  end)

  test("Missed kick alert does not replace a death alert still on screen", function()
    Stress.WithKey(ctx, FixtureWithSound, function(session)
      EnterCombat(session)
      session.runtime.ShowRoleDeathAlert("TANK", "party1")
      Kick(session)
      session.Advance(0.3)
      Assert.False(AlertShown(session), "the tank death text stays; the missed kick yields")
    end, Prepare())
  end)

  test("Simulation tablet E6 previews the missed-kick notice and sound without a key", function()
    Stress.WithParty(ctx, FixtureWithSound, function(session)
      session.globals.SlashCmdList.ISILIVE("sim")
      session.Advance(1)
      local action
      for _, entry in ipairs(session.runtime._simulationTabletActions or {}) do
        if entry.id == "E6" then
          action = entry
        end
      end
      Assert.NotNil(action, "the tablet offers the missed-kick preview as E6")
      Assert.Equal(action.category, "alerts", "E6 sits with the other alert previews")
      action.run()
      Assert.True(AlertShown(session), "E6 shows the notice outside a key and out of combat")
      Assert.Equal(#session.sounds, 1, "E6 plays the sound preview even with missedKickSound off")
      Assert.False(session.globals.IsiLiveDB.missedKickAlertEnabled, "the preview leaves the settings untouched")
    end, Prepare({ alert = false }))
  end)
end
