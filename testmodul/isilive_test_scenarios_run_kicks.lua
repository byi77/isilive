---@diagnostic disable: undefined-global, undefined-field
-- Run kicks in the kick column after a key (rule 238). Every flow boots the
-- real factory through the stress fixture and pumps client events through the
-- real gated dispatcher: the key starts with CHALLENGE_MODE_START, own kicks
-- arrive as UNIT_SPELLCAST_SUCCEEDED, the key ends with
-- CHALLENGE_MODE_COMPLETED, and peer counts arrive as CHAT_MSG_ADDON built
-- from the bytes the real sender emitted. Only the WoW API surface is stubbed:
-- the damage meter, the completion info and IsInInstance.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

local COUNTERSPELL = 2139
local MAP_ID = 2662
local KEY_LEVEL = 12
local INTERRUPTS_TYPE = 5

local SECRET = setmetatable({}, {
  __lt = function()
    error("attempt to compare a secret value")
  end,
  __le = function()
    error("attempt to compare a secret value")
  end,
})

-- Landed interrupts per meter name; Peer4 never appears (healer without kicks).
local LANDED = { Tester = 32, ["Peer1-Realm"] = 23, ["Peer2-Realm"] = 20, ["Peer3-Realm"] = 3 }

local function DamageSession()
  local sources = {
    { name = "Tester", amountPerSecond = 456789.4, totalAmount = 822220920 },
  }
  for index = 1, 4 do
    sources[#sources + 1] = {
      name = "Peer" .. index .. "-Realm",
      amountPerSecond = 300000 + index,
      totalAmount = 540000000 + index,
    }
  end
  return { durationSeconds = 1800, combatSources = sources }
end

local function InterruptSession(landed)
  local sources = {}
  for _, name in ipairs({ "Tester", "Peer1-Realm", "Peer2-Realm", "Peer3-Realm" }) do
    if landed[name] then
      sources[#sources + 1] = { name = name, totalAmount = landed[name], amountPerSecond = 0 }
    end
  end
  return { combatSources = sources }
end

local function MaskedSession()
  return { combatSources = { { name = SECRET, amountPerSecond = SECRET, totalAmount = SECRET } } }
end

-- meter.state: "readable", "masked", or "interrupts-masked" (DPS readable,
-- the Interrupts list masked).
local function Prepare(meter)
  return function(globals, session)
    session.inInstance = true
    globals.Enum = globals.Enum or {}
    globals.Enum.DamageMeterType = { DamageDone = 0, Dps = 1, Interrupts = INTERRUPTS_TYPE }
    globals.Enum.AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 }
    globals.issecretvalue = function(value)
      return value == SECRET
    end
    globals.IsInInstance = function()
      return session.inInstance, session.inInstance and "party" or "none"
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
        if meter.state == "masked" then
          return MaskedSession()
        end
        if meterType == INTERRUPTS_TYPE then
          if meter.state == "interrupts-masked" then
            return MaskedSession()
          end
          return InterruptSession(meter.landed or LANDED)
        end
        if meterType == 0 then
          return DamageSession()
        end
        return nil
      end,
    }
  end
end

local function KickTimes(session, count)
  session.combat = true
  session.Dispatch("PLAYER_REGEN_DISABLED")
  for _ = 1, count do
    local delivered = session.DispatchToFrames("UNIT_SPELLCAST_SUCCEEDED", "player", "kick-cast", COUNTERSPELL)
    assert(delivered == 1, "the own kick must reach exactly one registered isiLive frame")
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

-- Kick cells are the roster FontStrings of the main frame; the run-kick texts
-- used here ("37/32", "23", ...) appear nowhere else in the window.
local function HasCellText(session, text)
  for _, fontString in ipairs(session.runtime.mainFrame._fontStrings or {}) do
    if type(fontString.GetText) == "function" and fontString:GetText() == text then
      return true
    end
  end
  return false
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

local function RenderRoster(session)
  session.runtime.rosterPanelController.RenderRoster(session.runtime.GetRoster())
end

return function(test, ctx)
  local Assert = ctx.assert

  test("Run kicks show cast and landed for the own row and landed for members without isiLive", function()
    local meter = { state = "readable" }
    Stress.WithKey(ctx, Fixture, function(session)
      local stats = session.runtime.statsController
      KickTimes(session, 37)
      RenderRoster(session)
      Assert.False(HasCellText(session, "37/32"), "a running key keeps the kick cooldown in the column")

      CompleteKey(session)
      local own = stats.GetPlayerLastRunKicks("Tester", "Realm")
      Assert.Equal(own and own.cast, 37, "the own casts of the run are counted by the kick tracker")
      Assert.Equal(own and own.landed, 32, "the own landed kicks come from the damage meter")
      local peer = stats.GetPlayerLastRunKicks("Peer1", "Realm")
      Assert.Equal(peer and peer.landed, 23, "a member's landed kicks come from the damage meter")
      Assert.Nil(peer and peer.cast, "a member without isiLive has no cast count")
      local healer = stats.GetPlayerLastRunKicks("Peer4", "Realm")
      Assert.Equal(healer and healer.landed, 0, "a member missing from a readable Interrupts list landed none")

      RenderRoster(session)
      Assert.True(HasCellText(session, "37/32"), "the own row shows cast/landed after the key")
      Assert.True(HasCellText(session, "23"), "a member without isiLive shows the landed count only")
      Assert.True(HasCellText(session, "0"), "the member without kicks shows 0 landed")
    end, Prepare(meter))
  end)

  test("Run kicks sync the own cast count to peers from the real sender bytes", function()
    local meter = { state = "readable" }
    Stress.WithKey(ctx, Fixture, function(session)
      KickTimes(session, 37)
      CompleteKey(session)
      local payload = LastDpsPayload(session)
      Assert.NotNil(payload, "the post-run snapshot sends the DPS bucket")
      Assert.True(
        string.find(payload, ":KC:37:" .. MAP_ID .. ":" .. KEY_LEVEL .. "$") ~= nil,
        "the DPS payload carries the own casts of the run as the KC suffix: " .. tostring(payload)
      )
      -- An older client reads only fields 2-4 of the DPS bucket.
      local legacyParts = {}
      for part in (payload .. ":"):gmatch("(.-):") do
        legacyParts[#legacyParts + 1] = part
      end
      Assert.Equal(legacyParts[1], "DPS", "the bucket name is unchanged")
      Assert.Equal(tonumber(legacyParts[2]), 456789, "field 2 still carries the DPS for old peers")

      -- The same bytes arrive from Peer1, whose landed count this client read.
      session.Dispatch("CHAT_MSG_ADDON", "ISILIVE", payload, "PARTY", "Peer1-Realm")
      local peer = session.runtime.statsController.GetPlayerLastRunKicks("Peer1", "Realm")
      Assert.Equal(peer and peer.cast, 37, "the receiver pairs the synced casts with its own snapshot of the run")
      Assert.Equal(peer and peer.landed, 23, "landed stays the receiver's own meter value")
      RenderRoster(session)
      Assert.True(HasCellText(session, "37/23"), "the isiLive peer row shows cast/landed")

      -- A count for another run is not paired with this one.
      local otherRun = payload:gsub(":KC:37:%d+:%d+$", ":KC:9:" .. MAP_ID .. ":" .. (KEY_LEVEL + 1))
      session.Dispatch("CHAT_MSG_ADDON", "ISILIVE", otherRun, "PARTY", "Peer2-Realm")
      local other = session.runtime.statsController.GetPlayerLastRunKicks("Peer2", "Realm")
      Assert.Nil(other and other.cast, "casts of a different key level are never shown for this run")
    end, Prepare(meter))
  end)

  test("Run kicks hide again when the next key starts", function()
    local meter = { state = "readable" }
    Stress.WithKey(ctx, Fixture, function(session)
      KickTimes(session, 37)
      CompleteKey(session)
      RenderRoster(session)
      Assert.True(HasCellText(session, "37/32"), "the run kicks show after the key")

      session.active = true
      session.Dispatch("CHALLENGE_MODE_START")
      session.Advance(1)
      RenderRoster(session)
      Assert.False(HasCellText(session, "37/32"), "a new key brings the kick cooldown back")
      Assert.Nil(
        session.runtime.statsController.GetPlayerLastRunKicks("Tester", "Realm"),
        "the previous run's kicks are hidden while the next key runs"
      )
    end, Prepare(meter))
  end)

  test("Run kicks hide when a Mythic 0 run starts", function()
    local meter = { state = "readable" }
    Stress.WithKey(ctx, Fixture, function(session)
      KickTimes(session, 37)
      CompleteKey(session)
      Assert.NotNil(session.runtime.statsController.GetPlayerLastRunKicks("Tester", "Realm"), "the run kicks show")

      -- The stubs were copied into _G at boot; WithGlobals restores this key.
      _G.GetInstanceInfo = function()
        return "Test dungeon", "party", 23, "Mythic", 5, false, false, MAP_ID
      end
      session.Dispatch("PLAYER_ENTERING_WORLD")
      Assert.Nil(
        session.runtime.statsController.GetPlayerLastRunKicks("Tester", "Realm"),
        "an M0 run brings the kick cooldown back like a key start"
      )
    end, Prepare(meter))
  end)

  test("Run kicks fill late after leaving the instance when the key end was masked", function()
    local meter = { state = "masked" }
    Stress.WithKey(ctx, Fixture, function(session)
      local stats = session.runtime.statsController
      KickTimes(session, 37)
      CompleteKey(session)
      Assert.Nil(stats.GetPlayerLastRunKicks("Tester", "Realm"), "a masked meter yields no kick value")
      Assert.Nil(stats.GetPlayerLastRunDps("Tester", "Realm"), "and no DPS")

      meter.state = "readable"
      session.inInstance = false
      session.Dispatch("PLAYER_ENTERING_WORLD")
      local own = stats.GetPlayerLastRunKicks("Tester", "Realm")
      Assert.Equal(own and own.cast, 37, "the cast count of the run survives until the late capture")
      Assert.Equal(own and own.landed, 32, "the late capture reads the landed kicks")
      Assert.Equal(math.floor(stats.GetPlayerLastRunDps("Tester", "Realm") or 0), 456789, "and the DPS")
      local payload = LastDpsPayload(session)
      Assert.True(
        payload ~= nil and string.find(payload, ":KC:37:") ~= nil,
        "the late capture syncs the own casts: " .. tostring(payload)
      )
    end, Prepare(meter))
  end)

  test("Run kicks stay empty when the meter stays masked or only the Interrupts list is masked", function()
    local meter = { state = "masked" }
    Stress.WithKey(ctx, Fixture, function(session)
      local stats = session.runtime.statsController
      KickTimes(session, 3)
      CompleteKey(session)
      session.inInstance = false
      session.Dispatch("PLAYER_ENTERING_WORLD")
      Assert.Nil(stats.GetPlayerLastRunKicks("Tester", "Realm"), "a meter masked forever shows no kick value")
      RenderRoster(session)
      Assert.False(HasCellText(session, "3/0"), "no landed count is guessed")
    end, Prepare(meter))

    local partial = { state = "interrupts-masked" }
    Stress.WithKey(ctx, Fixture, function(session)
      local stats = session.runtime.statsController
      KickTimes(session, 3)
      CompleteKey(session)
      Assert.NotNil(stats.GetPlayerLastRunDps("Tester", "Realm"), "the DPS is captured")
      Assert.Nil(stats.GetPlayerLastRunKicks("Tester", "Realm"), "a masked Interrupts list gives no landed value")
      Assert.Nil(stats.GetPlayerLastRunKicks("Peer4", "Realm"), "and no member is taken for 0 landed")
    end, Prepare(partial))
  end)

  test("Run kicks drop the cast count after a masked own cast", function()
    local meter = { state = "readable" }
    Stress.WithKey(ctx, Fixture, function(session)
      KickTimes(session, 37)
      -- A cast whose spell ID is masked could have been a kick.
      session.DispatchToFrames("UNIT_SPELLCAST_SUCCEEDED", "player", "masked-cast", SECRET)
      CompleteKey(session)
      local own = session.runtime.statsController.GetPlayerLastRunKicks("Tester", "Realm")
      Assert.Equal(own and own.landed, 32, "landed still comes from the meter")
      Assert.Nil(own and own.cast, "an unknown cast count is not shown")
      RenderRoster(session)
      Assert.True(HasCellText(session, "32"), "the own row shows the landed count only")
    end, Prepare(meter))
  end)

  test("Run kicks drop a cast count below the landed count", function()
    local meter = { state = "readable" }
    Stress.WithKey(ctx, Fixture, function(session)
      KickTimes(session, 5)
      CompleteKey(session)
      local own = session.runtime.statsController.GetPlayerLastRunKicks("Tester", "Realm")
      Assert.Equal(own and own.landed, 32, "landed comes from the meter")
      Assert.Nil(own and own.cast, "5 casts cannot have landed 32 kicks: the count is incomplete and dropped")
      RenderRoster(session)
      Assert.True(HasCellText(session, "32"), "the column falls back to the landed count")
    end, Prepare(meter))
  end)
end
