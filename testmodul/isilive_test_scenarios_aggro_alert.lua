---@diagnostic disable: undefined-global

-- Rule 244: aggro alert for non-tanks (game/isiLive_aggro_alert.lua). Every
-- flow boots the real factory inside a running key (stress helpers) and
-- delivers client events only to the frames that registered them, with their
-- unit filter, so the own event frame and its registration are part of the
-- path. The alert is the real death-alert frame, the sound the real registry.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

local FixtureWithSound = {
  buildGlobals = Fixture.buildGlobals,
  moduleFiles = function()
    local files = Fixture.moduleFiles()
    table.insert(files, 1, "isiLive_db_schema.lua")
    table.insert(files, 1, "isiLive_sound_registry.lua")
    return files
  end,
}

-- Test stand-in for the client's SOUNDKIT constant; only "is a number" matters.
local ALARM_KIT = 12867
local ALERT_TEXT = "AGGRO"

-- opts: { enabled, sound, ownRole }
local function Prepare(opts)
  opts = opts or {}
  return function(globals, session)
    session.sounds = {}
    session.threat = 0
    session.ownRole = opts.ownRole or "DAMAGER"
    session.tankDead = false
    local db = globals.IsiLiveDB
    db.aggroAlertEnabled = opts.enabled ~= false
    db.aggroAlertSound = opts.sound == true
    globals.UnitThreatSituation = function(unit, mob)
      if unit == "player" and mob == nil then
        return session.threat
      end
      return nil
    end
    globals.GetSpecialization = function()
      return 1
    end
    globals.GetSpecializationRole = function()
      return session.ownRole
    end
    local rolesAssigned = globals.UnitGroupRolesAssigned
    globals.UnitGroupRolesAssigned = function(unit)
      if unit == "party1" then
        return "TANK"
      end
      return rolesAssigned(unit)
    end
    globals.UnitIsDeadOrGhost = function(unit)
      return unit == "party1" and session.tankDead
    end
    globals.SOUNDKIT = { ALARM_CLOCK_WARNING_3 = ALARM_KIT }
    globals.PlaySound = function(kit, channel)
      session.sounds[#session.sounds + 1] = { kit = kit, channel = channel }
      return true, #session.sounds
    end
  end
end

-- The one death-alert frame; its alertKind names the alert on screen.
local function AlertFrame(session)
  for _, frame in ipairs(session.frames) do
    if type(frame) == "table" and rawget(frame, "alertKind") ~= nil then
      return frame
    end
  end
  return nil
end

local function AlertShown(session, kind)
  local frame = AlertFrame(session)
  return frame ~= nil and frame:IsShown() == true and frame.alertKind == (kind or "AGGRO")
end

-- The stub animation group never finishes: hide by hand to see a fresh show.
local function ResetAlert(session)
  local frame = AlertFrame(session)
  if frame then
    frame:Hide()
  end
  session.sounds = {}
end

local function Pull(session)
  session.combat = true
  session.DispatchToFrames("PLAYER_REGEN_DISABLED")
end

local function Threat(session, status)
  session.threat = status
  return session.DispatchToFrames("UNIT_THREAT_SITUATION_UPDATE", "player")
end

return function(test, ctx)
  local Assert = ctx.assert

  test("Aggro alert shows once per pull after half a second of aggro for a non-tank in a key", function()
    Stress.WithKey(ctx, FixtureWithSound, function(session)
      Pull(session)
      Assert.Equal(Threat(session, 3), 1, "the player's threat update reaches the aggro frame only")
      session.Advance(0.3)
      Assert.False(AlertShown(session), "the alert waits for the hold time")
      session.Advance(0.3)
      Assert.True(AlertShown(session), "aggro that held shows AGGRO")
      Assert.Equal(AlertFrame(session).text:GetText(), ALERT_TEXT, "with the AGGRO text")
      Assert.Equal(#session.sounds, 1, "with its sound")
      Assert.Equal(session.sounds[1].kit, ALARM_KIT, "the aggro sound kit")

      ResetAlert(session)
      Threat(session, 2)
      session.Advance(1)
      Assert.False(AlertShown(session), "at most once per pull")

      Pull(session)
      Threat(session, 3)
      session.Advance(1)
      Assert.True(AlertShown(session), "the next pull may alert again")
    end, Prepare({ sound = true }))
  end)

  test("Aggro alert stays quiet for a short tap, for tanks, while the tank is dead and when off", function()
    Stress.WithKey(ctx, FixtureWithSound, function(session)
      Pull(session)
      Threat(session, 3)
      session.Advance(0.2)
      Threat(session, 0)
      session.Advance(1)
      Assert.False(AlertShown(session), "aggro that drops within the hold time does not alert")

      session.tankDead = true
      Threat(session, 3)
      session.Advance(1)
      Assert.False(AlertShown(session), "no alert while the group's tank is dead")
    end, Prepare())

    Stress.WithKey(ctx, FixtureWithSound, function(session)
      Pull(session)
      Threat(session, 3)
      session.Advance(1)
      Assert.False(AlertShown(session), "a tank never gets the alert")
    end, Prepare({ ownRole = "TANK" }))

    Stress.WithKey(ctx, FixtureWithSound, function(session)
      Pull(session)
      Assert.Equal(Threat(session, 3), 0, "switched off, the threat event is not even registered")
      session.Advance(1)
      Assert.False(AlertShown(session), "no alert when switched off")
    end, Prepare({ enabled = false }))
  end)

  test("Aggro alert never replaces a death alert that is still on screen", function()
    Stress.WithKey(ctx, FixtureWithSound, function(session)
      Pull(session)
      session.addon.DeathAlert.ShowRoleDeath("TANK")
      Threat(session, 3)
      session.Advance(1)
      Assert.False(AlertShown(session), "the death alert keeps the screen")
      Assert.True(AlertShown(session, "TANK"), "the death alert stays visible")
    end, Prepare())
  end)
end
