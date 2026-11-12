---@diagnostic disable: undefined-global

-- Rule 245 (K9): live kicks of the running key. The real factory runs inside
-- a key (stress helpers); PLAYER_REGEN_ENABLED reaches the frames that
-- registered it, and the read goes through the real Stats controller into
-- the getter the roster tooltip uses. Only the client's damage meter is
-- stubbed.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

local FixtureWithSchema = {
  buildGlobals = Fixture.buildGlobals,
  moduleFiles = function()
    local files = Fixture.moduleFiles()
    table.insert(files, 1, "isiLive_db_schema.lua")
    return files
  end,
}

local SESSION_OVERALL = 0
local METER_DAMAGE, METER_INTERRUPTS = 0, 5

-- opts: { enabled }
local function Prepare(opts)
  opts = opts or {}
  return function(globals, session)
    session.interrupts = { { name = "Peer1", totalAmount = 3 } }
    session.masked = false
    globals.IsiLiveDB.liveRunKicksEnabled = opts.enabled
    globals.Enum = globals.Enum or {}
    globals.Enum.DamageMeterSessionType = { Overall = SESSION_OVERALL, Current = 1 }
    globals.Enum.DamageMeterType = { DamageDone = METER_DAMAGE, Interrupts = METER_INTERRUPTS }
    globals.C_DamageMeter = {
      IsDamageMeterAvailable = function()
        return true
      end,
      ResetAllCombatSessions = function() end,
      GetCombatSessionFromType = function(sessionType, meterType)
        if sessionType ~= SESSION_OVERALL or meterType ~= METER_INTERRUPTS or session.masked then
          return nil
        end
        return { combatSources = session.interrupts }
      end,
    }
  end
end

local function EndPull(session)
  session.combat = false
  session.DispatchToFrames("PLAYER_REGEN_ENABLED")
end

local function StartPull(session)
  session.combat = true
  session.DispatchToFrames("PLAYER_REGEN_DISABLED")
end

return function(test, ctx)
  local Assert = ctx.assert

  test("Live kicks read the running key's landed kicks after every pull", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      local getKicks = session.runtime.statsController.GetPlayerLastRunKicks
      Assert.Nil(getKicks("Peer1"), "nothing before the first pull of the key ended")
      EndPull(session)
      local kicks = Assert.NotNil(getKicks("Peer1"), "after the pull the live count is there")
      Assert.Equal(kicks.landed, 3, "landed kicks from the Overall interrupts session")
      Assert.True(kicks.live, "marked as the running key's count")
      Assert.Equal(getKicks("Peer2").landed, 0, "a member missing from a readable list landed none")

      session.interrupts = { { name = "Peer1", totalAmount = 7 } }
      session.masked = true
      EndPull(session)
      Assert.Equal(getKicks("Peer1").landed, 3, "a masked read keeps the previous count")
      session.masked = false
      StartPull(session)
      Assert.Equal(getKicks("Peer1").landed, 7, "the next pull start picks up the late count")

      session.globals.IsiLiveDB.liveRunKicksEnabled = false
      Assert.Nil(getKicks("Peer1"), "switched off, the tooltip shows nothing during the key")
    end, Prepare())
  end)

  test("Live kicks stay off when the setting is off", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      EndPull(session)
      Assert.Nil(session.runtime.statsController.GetPlayerLastRunKicks("Peer1"), "no live read with the setting off")
    end, Prepare({ enabled = false }))
  end)
end
