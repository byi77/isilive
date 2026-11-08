---@diagnostic disable: undefined-global, undefined-field, unused-local, unused-vararg
-- End-to-end tests for the late run capture (rule 118, RULE-KEYENDE-RUN-IDENTITAET):
-- the damage meter answers in Secret Values at CHALLENGE_MODE_COMPLETED and is
-- read again once the restrictions lift. Every step goes through the real
-- factory composition and the real event dispatcher; the meter, the clock,
-- IsInInstance and the addon-message API are the only stubs.
local FactoryFixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local BuildGlobals = FactoryFixture.buildGlobals
local GetAllIsiLiveFiles = FactoryFixture.moduleFiles

local MAP_ID = 2662
local KEY_LEVEL = 17

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  local SECRET = setmetatable({}, {
    __lt = function()
      error("attempt to compare a secret value")
    end,
    __le = function()
      error("attempt to compare a secret value")
    end,
    __concat = function()
      error("attempt to concatenate a secret value")
    end,
  })

  local function ReadableDamage()
    return {
      durationSeconds = 1800,
      combatSources = {
        { name = "Tester", amountPerSecond = 456789.4, totalAmount = 822220920 },
        { name = "Buddy-OtherRealm", amountPerSecond = 321123.8, totalAmount = 578022840 },
        { name = "Healer-OtherRealm", amountPerSecond = 51000.2, totalAmount = 91800360 },
      },
    }
  end

  local function MaskedDamage()
    return {
      durationSeconds = SECRET,
      combatSources = {
        { name = SECRET, amountPerSecond = SECRET, totalAmount = SECRET },
        { name = SECRET, amountPerSecond = SECRET, totalAmount = SECRET },
        { name = SECRET, amountPerSecond = SECRET, totalAmount = SECRET },
      },
    }
  end

  -- Builds the globals for a three-member group (own player, a cross-realm
  -- isiLive-less damage dealer and a cross-realm healer) inside a key.
  local function BuildRunWorld()
    local globals, db = BuildGlobals()
    db.syncEnabled = true
    local world = {
      now = 1000,
      inInstance = true,
      activeMapID = nil,
      meterReadable = false,
      meterOverride = nil,
      timers = {},
      sent = {},
      resets = 0,
    }
    globals.GetTime = function()
      return world.now
    end
    globals.IsInInstance = function()
      return world.inInstance, world.inInstance and "party" or "none"
    end
    globals.issecretvalue = function(value)
      return value == SECRET
    end
    globals.IsInGroup = function(category)
      return category == nil
    end
    globals.GetNumGroupMembers = function()
      return 3
    end
    globals.UnitExists = function(unit)
      return unit == "player" or unit == "party1" or unit == "party2"
    end
    globals.UnitName = function(unit)
      if unit == "player" then
        return "Tester", "Realm"
      end
      if unit == "party1" then
        return "Buddy", "OtherRealm"
      end
      if unit == "party2" then
        return "Healer", "OtherRealm"
      end
      return nil
    end
    globals.UnitFullName = globals.UnitName
    globals.UnitClass = function(unit)
      if unit == "player" or unit == "party1" or unit == "party2" then
        return "Mage", "MAGE", 8
      end
      return nil
    end
    globals.Enum = globals.Enum or {}
    globals.Enum.AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4 }
    globals.Enum.AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 }
    globals.C_ChallengeMode.GetActiveChallengeMapID = function()
      return world.activeMapID
    end
    globals.C_ChallengeMode.GetActiveKeystoneInfo = function()
      return KEY_LEVEL, {}, 0
    end
    globals.C_ChallengeMode.GetChallengeCompletionInfo = function()
      return { mapChallengeModeID = MAP_ID, level = KEY_LEVEL, time = 1500000, onTime = false }
    end
    globals.C_DamageMeter = {
      IsDamageMeterAvailable = function()
        return true
      end,
      ResetAllCombatSessions = function()
        world.resets = world.resets + 1
      end,
      GetCombatSessionFromType = function(sessionType, meterType)
        if world.meterOverride then
          return world.meterOverride(sessionType, meterType)
        end
        if meterType ~= 0 then
          return nil
        end
        return world.meterReadable and ReadableDamage() or MaskedDamage()
      end,
    }
    globals.C_Timer.After = function(seconds, callback)
      world.timers[#world.timers + 1] = { at = world.now + (tonumber(seconds) or 0), callback = callback }
    end
    globals.C_ChatInfo.SendAddonMessage = function(prefix, payload, channel)
      world.sent[#world.sent + 1] = { prefix = prefix, payload = payload, channel = channel }
      return 0
    end
    return globals, db, world
  end

  -- Moves the clock in one-second steps so a timer scheduled by a callback
  -- fires at its own time, like C_Timer.After does.
  local function Advance(world, seconds)
    for _ = 1, seconds do
      world.now = world.now + 1
      local fired = true
      while fired do
        fired = false
        for index, timer in ipairs(world.timers) do
          if timer.at <= world.now then
            table.remove(world.timers, index)
            timer.callback()
            fired = true
            break
          end
        end
      end
    end
  end

  local function Boot(world)
    local addon = LoadAddonModules(GetAllIsiLiveFiles())
    local factoryCtx = addon.Factory.InitializeAddon("isiLive", addon, { returnContext = true })
    local frame = factoryCtx.eventFrame
    local function Dispatch(event, ...)
      frame._scripts.OnEvent(frame, event, ...)
    end
    Dispatch("PLAYER_LOGIN")
    Dispatch("GROUP_ROSTER_UPDATE")
    return addon, factoryCtx, Dispatch
  end

  local function RunMaskedKey(world, Dispatch)
    world.activeMapID = MAP_ID
    Dispatch("CHALLENGE_MODE_START")
    world.activeMapID = nil
    world.meterReadable = false
    Dispatch("CHALLENGE_MODE_COMPLETED")
    -- The five 1 s retries after the key end all meet the masked meter.
    Advance(world, 6)
  end

  local function FindDpsPayloads(world)
    local out = {}
    for _, message in ipairs(world.sent) do
      if message.prefix == "ISILIVE" and string.find(message.payload, "^DPS:") then
        out[#out + 1] = message.payload
      end
    end
    return out
  end

  test("Late run capture fills the DPS after leaving the instance when the key end was masked", function()
    local globals, _, world = BuildRunWorld()
    WithGlobals(globals, function()
      local _, factoryCtx, Dispatch = Boot(world)
      local stats = factoryCtx.statsController
      RunMaskedKey(world, Dispatch)
      Assert.Nil(stats.GetPlayerLastRunDps("Tester", "Realm"), "a masked key end must not record a DPS value")

      factoryCtx.runtimeLogController.SetEnabled(true)
      world.meterReadable = true
      world.inInstance = false
      world.sent = {}
      Dispatch("PLAYER_ENTERING_WORLD")

      Assert.Equal(
        math.floor(stats.GetPlayerLastRunDps("Tester", "Realm") or 0),
        456789,
        "leaving the instance must capture the own DPS of the run"
      )
      Assert.Equal(
        math.floor(stats.GetPlayerLastRunDps("Buddy", "OtherRealm") or 0),
        321123,
        "leaving the instance must capture a cross-realm member's DPS"
      )
      local lateTrace = false
      local capturedTrace = false
      for _, line in ipairs(factoryCtx.runtimeLogController.GetLogTail(100) or {}) do
        local text = type(line) == "table" and tostring(line.message or line.text or "") or tostring(line)
        if string.find(text, "[STATS] event=record_run phase=late trigger=world", 1, true) then
          lateTrace = true
        end
        if string.find(text, "[STATS] event=late_capture state=captured", 1, true) then
          capturedTrace = true
        end
      end
      Assert.True(lateTrace, "the late capture attempt must be visible in the [STATS] trace")
      Assert.True(capturedTrace, "the successful late capture must be visible in the [STATS] trace")
      local dpsPayloads = FindDpsPayloads(world)
      Assert.True(#dpsPayloads > 0, "the late DPS must be sent to the peers")
      Assert.True(
        string.find(dpsPayloads[#dpsPayloads], "^DPS:456789:") ~= nil,
        "the sent DPS payload must carry the late value: " .. tostring(dpsPayloads[#dpsPayloads])
      )
    end)
  end)

  test("Late run capture retries when an addon restriction is lifted inside the instance", function()
    local globals, _, world = BuildRunWorld()
    WithGlobals(globals, function()
      local _, factoryCtx, Dispatch = Boot(world)
      local stats = factoryCtx.statsController
      RunMaskedKey(world, Dispatch)

      -- An active (not lifted) restriction proves nothing.
      world.meterReadable = true
      Dispatch("ADDON_RESTRICTION_STATE_CHANGED", 2, 2)
      Assert.Nil(stats.GetPlayerLastRunDps("Tester", "Realm"), "an activating restriction must not trigger a capture")

      world.sent = {}
      Dispatch("ADDON_RESTRICTION_STATE_CHANGED", 2, 0)
      Assert.Equal(
        math.floor(stats.GetPlayerLastRunDps("Tester", "Realm") or 0),
        456789,
        "a lifted restriction must capture the run"
      )
      Assert.True(#FindDpsPayloads(world) > 0, "a late capture outside PLAYER_ENTERING_WORLD sends its own snapshot")
    end)
  end)

  test("Late run capture stays empty when the meter stays masked", function()
    local globals, _, world = BuildRunWorld()
    WithGlobals(globals, function()
      local _, factoryCtx, Dispatch = Boot(world)
      local stats = factoryCtx.statsController
      RunMaskedKey(world, Dispatch)
      world.inInstance = false
      Dispatch("PLAYER_ENTERING_WORLD")
      Dispatch("ZONE_CHANGED_NEW_AREA")
      Dispatch("ADDON_RESTRICTION_STATE_CHANGED", 0, 0)
      Assert.Nil(stats.GetPlayerLastRunDps("Tester", "Realm"), "a meter masked forever must leave the DPS empty")
      Assert.Nil(stats.GetPlayerLastRunDps("Buddy", "OtherRealm"), "no member gets a guessed DPS")

      -- The window closes after ten minutes; a readable meter later is no
      -- longer taken for the run.
      Advance(world, 601)
      world.meterReadable = true
      Dispatch("ZONE_CHANGED_NEW_AREA")
      Assert.Nil(stats.GetPlayerLastRunDps("Tester", "Realm"), "an expired late capture must not read the meter")
    end)
  end)

  test("Late run capture fills an abandoned key that was masked when it was left", function()
    local globals, _, world = BuildRunWorld()
    WithGlobals(globals, function()
      local _, factoryCtx, Dispatch = Boot(world)
      local stats = factoryCtx.statsController
      world.activeMapID = MAP_ID
      Dispatch("CHALLENGE_MODE_START")
      world.activeMapID = nil
      world.meterReadable = false
      Dispatch("CHALLENGE_MODE_RESET")
      Advance(world, 6)
      Assert.Nil(stats.GetPlayerLastRunDps("Tester", "Realm"), "a masked abandoned key must not record yet")

      world.meterReadable = true
      world.inInstance = false
      Dispatch("PLAYER_ENTERING_WORLD")
      Assert.Equal(
        math.floor(stats.GetPlayerLastRunDps("Tester", "Realm") or 0),
        456789,
        "the abandoned key must be captured late once the player is outside"
      )
    end)
  end)

  test("Late run capture is cancelled by a new key start", function()
    local globals, _, world = BuildRunWorld()
    WithGlobals(globals, function()
      local _, factoryCtx, Dispatch = Boot(world)
      local stats = factoryCtx.statsController
      RunMaskedKey(world, Dispatch)

      world.activeMapID = MAP_ID
      Dispatch("CHALLENGE_MODE_START")
      world.meterReadable = true
      world.inInstance = false
      Dispatch("PLAYER_ENTERING_WORLD")
      Assert.Nil(
        stats.GetPlayerLastRunDps("Tester", "Realm"),
        "after a new key start the meter belongs to the new key and must not fill the old run"
      )
    end)
  end)

  test("Late run capture is cancelled by new combat after the key", function()
    local globals, _, world = BuildRunWorld()
    WithGlobals(globals, function()
      local _, factoryCtx, Dispatch = Boot(world)
      local stats = factoryCtx.statsController
      RunMaskedKey(world, Dispatch)

      Dispatch("PLAYER_REGEN_DISABLED")
      world.meterReadable = true
      world.inInstance = false
      Dispatch("PLAYER_ENTERING_WORLD")
      Assert.Nil(
        stats.GetPlayerLastRunDps("Tester", "Realm"),
        "combat after the key adds to the Overall session, so the late capture must not run"
      )
    end)
  end)

  test("Late run capture reads only the Overall session", function()
    local globals, _, world = BuildRunWorld()
    WithGlobals(globals, function()
      local _, factoryCtx, Dispatch = Boot(world)
      local stats = factoryCtx.statsController
      RunMaskedKey(world, Dispatch)

      local askedCurrent = false
      world.meterOverride = function(sessionType, meterType)
        if sessionType == 1 then
          askedCurrent = true
          return meterType == 0 and ReadableDamage() or nil
        end
        return nil
      end
      world.inInstance = false
      Dispatch("PLAYER_ENTERING_WORLD")
      Assert.Nil(
        stats.GetPlayerLastRunDps("Tester", "Realm"),
        "a readable Current session alone must not be taken for the run after the key"
      )
      Assert.False(askedCurrent, "the late capture must not even read the Current session")
    end)
  end)
end
