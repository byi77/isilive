---@diagnostic disable: undefined-global, undefined-field
-- The own kick state goes out on the 0.5 s kick poll while a cooldown runs.
-- These flows boot the real factory through the stress fixture, cast the own
-- kick as UNIT_SPELLCAST_SUCCEEDED through the real dispatcher and let the
-- production ticker run; the runtime log and the addon-message API are read
-- back. Only C_ChatInfo.InChatMessagingLockdown is stubbed on top.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

local COUNTERSPELL = 2139

local function Prepare(globals, session)
  session.lockdown = false
  globals.C_ChatInfo.InChatMessagingLockdown = function()
    return session.lockdown
  end
end

local function CountLog(session, needle)
  local count = 0
  for _, line in ipairs(session.runtime.runtimeLogController.GetLogTail(100) or {}) do
    if string.find(tostring(line), needle, 1, true) then
      count = count + 1
    end
  end
  return count
end

local function CountKickMessages(session)
  local count = 0
  for _, message in ipairs(session.messages) do
    if message.prefix == "ISILIVE" and string.find(message.payload, "^KICK:") then
      count = count + 1
    end
  end
  return count
end

local function Kick(session)
  local delivered = session.DispatchToFrames("UNIT_SPELLCAST_SUCCEEDED", "player", "kick-cast", COUNTERSPELL)
  assert(delivered == 1, "the own kick must reach exactly one registered isiLive frame")
end

return function(test, ctx)
  local Assert = ctx.assert

  test("Kick sync traces send_kick only when its reported state changes", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.runtime.runtimeLogController.SetEnabled(true)
      session.messages = {}
      Kick(session)
      -- 25 s cooldown on the 0.5 s poll: about fifty send attempts.
      session.Advance(30)
      local sends = CountKickMessages(session)
      Assert.True(sends >= 20, "the poll keeps the peers updated while the cooldown runs, got " .. sends)
      local traces = CountLog(session, "event=send_kick ")
      Assert.True(
        traces <= 4,
        "send_kick is traced on state changes (cooldown start, ready), not per tick: got " .. traces
      )
      Assert.True(CountLog(session, "repeats=") > 0, "a logged line reports how many identical outcomes it stood for")
    end, Prepare)
  end)

  test("Kick sync skips sends while addon chat is locked down and resyncs at once after it", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.runtime.runtimeLogController.SetEnabled(true)
      session.lockdown = true
      session.messages = {}
      Kick(session)
      session.Advance(10)
      Assert.Equal(CountKickMessages(session), 0, "nothing is dispatched while addon chat is locked down")
      Assert.Equal(CountLog(session, "sent=lockdown"), 1, "the lockdown is traced once, not per tick")

      session.lockdown = false
      session.Advance(0.5)
      Assert.True(CountKickMessages(session) >= 1, "the first poll after the lockdown sends the kick state")
    end, Prepare)
  end)
end
