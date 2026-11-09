---@diagnostic disable: undefined-global, undefined-field
-- Missed kicks of the run (rule 240). Every flow boots the real factory through
-- the stress fixture and pumps client events through the real dispatcher: the
-- key starts with CHALLENGE_MODE_START, own kicks arrive as
-- UNIT_SPELLCAST_SUCCEEDED, hostile interrupts as UNIT_SPELLCAST_INTERRUPTED,
-- the verdicts run from the production C_Timer callbacks and the key ends with
-- CHALLENGE_MODE_COMPLETED. Peer counts arrive as CHAT_MSG_ADDON built from the
-- bytes the real sender emitted. The missed-kick alert stays off (its default),
-- so every count here comes from the run counter alone. Only the WoW API
-- surface is stubbed: the damage meter, the completion info and UnitCanAttack.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

local COUNTERSPELL = 2139
local MAP_ID = 2662
local KEY_LEVEL = 12
local INTERRUPTS_TYPE = 5

local function Session(names, valueFor)
  local sources = {}
  for _, name in ipairs(names) do
    sources[#sources + 1] = { name = name, totalAmount = valueFor(name), amountPerSecond = valueFor(name) }
  end
  return { durationSeconds = 1800, combatSources = sources }
end

local MEMBERS = { "Tester", "Peer1-Realm", "Peer2-Realm", "Peer3-Realm", "Peer4-Realm" }

-- landed: interrupts per meter name in the Interrupts list.
local function Prepare(landed)
  return function(globals, session)
    session.inInstance = true
    globals.Enum = globals.Enum or {}
    globals.Enum.DamageMeterType = { DamageDone = 0, Dps = 1, Interrupts = INTERRUPTS_TYPE }
    globals.IsInInstance = function()
      return session.inInstance, session.inInstance and "party" or "none"
    end
    globals.UnitCanAttack = function(_, unit)
      return not (unit == "player" or unit:find("^party%d") ~= nil)
    end
    globals.C_ChallengeMode.GetChallengeCompletionInfo = function()
      return { mapChallengeModeID = MAP_ID, level = KEY_LEVEL, time = 1700000, onTime = true }
    end
    globals.C_DamageMeter = {
      IsDamageMeterAvailable = function()
        return true
      end,
      ResetAllCombatSessions = function() end,
      GetCombatSessionFromType = function(_sessionType, meterType)
        if meterType == INTERRUPTS_TYPE then
          return Session(MEMBERS, function(name)
            return landed[name] or 0
          end)
        end
        if meterType == 0 then
          return Session(MEMBERS, function()
            return 400000
          end)
        end
        return nil
      end,
    }
  end
end

local function Deliver(session, event, ...)
  local delivered = session.DispatchToFrames(event, ...)
  assert(delivered == 1, event .. " must reach exactly one registered isiLive frame, got " .. tostring(delivered))
end

local function Kick(session)
  Deliver(session, "UNIT_SPELLCAST_SUCCEEDED", "player", "kick-cast", COUNTERSPELL)
end

local function HostileInterrupt(session)
  Deliver(session, "UNIT_SPELLCAST_INTERRUPTED", "nameplate3", "hostile-cast", 12345, nil, 1)
end

-- landedCount kicks stop a hostile cast in the same frame, missedCount kicks
-- hit nothing; each kick waits out its cooldown.
local function KickRun(session, landedCount, missedCount)
  session.combat = true
  session.Dispatch("PLAYER_REGEN_DISABLED")
  for index = 1, landedCount + missedCount do
    Kick(session)
    if index <= landedCount then
      HostileInterrupt(session)
    end
    session.Advance(25)
  end
  session.combat = false
  session.Dispatch("PLAYER_REGEN_ENABLED")
end

local function CompleteKey(session)
  session.active = false
  session.Dispatch("CHALLENGE_MODE_COMPLETED")
  session.Advance(12)
end

local function LastDpsPayload(session)
  local payload = nil
  for _, message in ipairs(session.messages) do
    if message.prefix == "ISILIVE" and string.find(message.payload, "^DPS:") then
      payload = message.payload
    end
  end
  return payload
end

return function(test, ctx)
  local Assert = ctx.assert

  test("Missed kicks count own kicks without a hostile interrupt while the alert is off", function()
    Stress.WithKey(ctx, Fixture, function(session)
      Assert.True(rawget(_G, "IsiLiveDB").missedKickAlertEnabled ~= true, "the missed-kick alert is off")
      KickRun(session, 3, 2)
      CompleteKey(session)
      local own = session.runtime.statsController.GetPlayerLastRunKicks("Tester", "Realm")
      Assert.Equal(own and own.cast, 5, "every own kick counts as cast")
      Assert.Equal(own and own.landed, 3, "landed comes from the damage meter")
      Assert.Equal(own and own.missed, 2, "two kicks without a hostile interrupt count as missed")
    end, Prepare({ Tester = 3, ["Peer1-Realm"] = 3 }))
  end)

  test("Missed kicks sync to peers as the KM suffix from the real sender bytes", function()
    Stress.WithKey(ctx, Fixture, function(session)
      KickRun(session, 3, 2)
      CompleteKey(session)
      local payload = LastDpsPayload(session)
      Assert.True(
        payload ~= nil and string.find(payload, ":KC:5:" .. MAP_ID .. ":" .. KEY_LEVEL .. ":KM:2$") ~= nil,
        "the DPS payload carries the missed kicks after the KC suffix: " .. tostring(payload)
      )

      -- The same bytes arrive from Peer1, whose landed count this client read.
      session.Dispatch("CHAT_MSG_ADDON", "ISILIVE", payload, "PARTY", "Peer1-Realm")
      local peer = session.runtime.statsController.GetPlayerLastRunKicks("Peer1", "Realm")
      Assert.Equal(peer and peer.cast, 5, "the peer's casts pair with the run")
      Assert.Equal(peer and peer.missed, 2, "the peer's missed kicks come from its KM suffix")

      -- An older peer sends no KM suffix: its missed kicks stay unknown.
      local legacy = payload:gsub(":KM:%d+$", "")
      session.Dispatch("CHAT_MSG_ADDON", "ISILIVE", legacy, "PARTY", "Peer2-Realm")
      local older = session.runtime.statsController.GetPlayerLastRunKicks("Peer2", "Realm")
      Assert.Equal(older and older.cast, 5, "the legacy payload still carries the casts")
      Assert.Nil(older and older.missed, "no KM suffix, no missed count")

      -- A KM value above the cast count is impossible and dropped.
      local broken = payload:gsub(":KM:%d+$", ":KM:9")
      session.Dispatch("CHAT_MSG_ADDON", "ISILIVE", broken, "PARTY", "Peer3-Realm")
      local invalid = session.runtime.statsController.GetPlayerLastRunKicks("Peer3", "Realm")
      Assert.Nil(invalid and invalid.missed, "a missed count above the casts is never shown")
    end, Prepare({ Tester = 3, ["Peer1-Realm"] = 3, ["Peer2-Realm"] = 3, ["Peer3-Realm"] = 3 }))
  end)

  test("Missed kicks turn unknown when a kick's verdict is lost", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.combat = true
      session.Dispatch("PLAYER_REGEN_DISABLED")
      -- The second kick replaces the first before its verdict window ends.
      Kick(session)
      Kick(session)
      session.Advance(25)
      CompleteKey(session)
      local own = session.runtime.statsController.GetPlayerLastRunKicks("Tester", "Realm")
      Assert.Equal(own and own.cast, 2, "both kicks count as cast")
      Assert.Nil(own and own.missed, "a lost verdict makes the missed count unknown, never short")
    end, Prepare({ Tester = 1 }))
  end)

  test("Missed kicks start from zero at the next key start", function()
    Stress.WithKey(ctx, Fixture, function(session)
      KickRun(session, 0, 2)
      CompleteKey(session)
      local own = session.runtime.statsController.GetPlayerLastRunKicks("Tester", "Realm")
      Assert.Equal(own and own.missed, 2, "the finished run has two missed kicks")

      session.active = true
      session.Dispatch("CHALLENGE_MODE_START")
      session.Advance(1)
      KickRun(session, 1, 0)
      CompleteKey(session)
      own = session.runtime.statsController.GetPlayerLastRunKicks("Tester", "Realm")
      Assert.Equal(own and own.cast, 1, "the new run counts its own cast only")
      Assert.Equal(own and own.missed, 0, "the new run starts its missed count at zero")
    end, Prepare({ Tester = 1 }))
  end)
end
