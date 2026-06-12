local function RegisterReadyCheckHoldAndRunRecordTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  test("Event handlers keep unanswered ready-check rows red for 20 seconds after finish", function()
    local counters = { uiUpdates = 0, readyCheckRefreshes = 0 }
    local readyCheckActive = false
    local now = 100
    local readyUntilByUnit = {}
    local declinedUntilByUnit = {}
    local scheduledDelay = nil
    local scheduledCallback = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      setReadyCheckActive = function(value)
        readyCheckActive = value and true or false
      end,
      isReadyCheckActive = function()
        return readyCheckActive
      end,
      getTime = function()
        return now
      end,
      getRoster = function()
        return {
          party1 = { name = "ReadyMate", role = "DAMAGER" },
          party2 = { name = "SilentMate", role = "DAMAGER" },
        }
      end,
      setReadyCheckReadyUntil = function(unit, value)
        readyUntilByUnit[unit] = value
      end,
      clearAllReadyCheckReady = function()
        readyUntilByUnit = {}
      end,
      clearExpiredReadyCheckReady = function(currentTime)
        local changed = false
        for unit, untilTime in pairs(readyUntilByUnit) do
          if untilTime <= currentTime then
            readyUntilByUnit[unit] = nil
            changed = true
          end
        end
        return changed
      end,
      setReadyCheckDeclinedUntil = function(unit, value)
        declinedUntilByUnit[unit] = value
      end,
      clearAllReadyCheckDeclined = function()
        declinedUntilByUnit = {}
      end,
      clearExpiredReadyCheckDeclined = function(currentTime)
        local changed = false
        for unit, untilTime in pairs(declinedUntilByUnit) do
          if untilTime <= currentTime then
            declinedUntilByUnit[unit] = nil
            changed = true
          end
        end
        return changed
      end,
      timerAfter = function(delaySeconds, callback)
        scheduledDelay = delaySeconds
        scheduledCallback = callback
      end,
    })

    controller:Dispatch("READY_CHECK")
    controller:Dispatch("READY_CHECK_CONFIRM", "party1", "ready")
    controller:Dispatch("READY_CHECK_FINISHED")

    Assert.False(readyCheckActive, "READY_CHECK_FINISHED must clear ready check state")
    Assert.Equal(readyUntilByUnit.party1, 120, "explicit ready answers should stay green for 20 seconds")
    Assert.Equal(declinedUntilByUnit.party2, 120, "missing ready-check answers should stay red for 20 seconds")
    Assert.Nil(declinedUntilByUnit.party1, "ready answers must not also receive a declined hold")
    Assert.Equal(scheduledDelay, 20, "unanswered ready-check hold should schedule one 20-second cleanup refresh")
    Assert.NotNil(scheduledCallback, "unanswered ready-check hold must schedule a cleanup callback")
    Assert.Equal(counters.readyCheckRefreshes, 3, "finish path should still refresh the dedicated ready-check UI")
    Assert.Equal(counters.uiUpdates, 0, "unanswered ready-check hold must not use generic updateUI")

    now = 120
    local cleanupCallback = scheduledCallback
    if cleanupCallback == nil then
      error("unanswered ready-check hold must schedule a cleanup callback")
    end
    cleanupCallback()

    Assert.Nil(readyUntilByUnit.party1, "ready hold should clear after the timer expires")
    Assert.Nil(declinedUntilByUnit.party2, "unanswered declined hold should clear after the timer expires")
    Assert.Equal(counters.readyCheckRefreshes, 4, "timer expiry should trigger one more dedicated ready-check refresh")
    Assert.Equal(counters.uiUpdates, 0, "timer expiry must not use generic updateUI")
  end)

  test("Event handlers record completed run only once across completion and reset events", function()
    local recordedRuns = {}

    WithGlobals({
      C_ChallengeMode = {
        GetCompletionInfo = function()
          return 2662, 10, 123456, true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
        recordRun = function(mapID, level, onTime)
          table.insert(recordedRuns, {
            mapID = mapID,
            level = level,
            onTime = onTime,
          })
        end,
      })

      controller:Dispatch("CHALLENGE_MODE_COMPLETED")
      controller:Dispatch("CHALLENGE_MODE_RESET")
      Assert.Equal(#recordedRuns, 1, "completion/reset pair must record the run only once")

      controller:Dispatch("CHALLENGE_MODE_START")
      controller:Dispatch("CHALLENGE_MODE_COMPLETED")
      Assert.Equal(#recordedRuns, 2, "new run after challenge start should be recordable again")
    end)
  end)
end

local function RegisterReadyCheckLifecycleTests(test, Assert, _WithGlobals, LoadAddonModules, Fixtures)
  test("Event handlers toggle ready check state and refresh UI on ready check events", function()
    local counters = { uiUpdates = 0, readyCheckRefreshes = 0 }
    local readyCheckActive = false
    local now = 100
    local readyUntilByUnit = {}
    local scheduledDelay = nil
    local scheduledCallback = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      setReadyCheckActive = function(value)
        readyCheckActive = value and true or false
      end,
      isReadyCheckActive = function()
        return readyCheckActive
      end,
      getTime = function()
        return now
      end,
      setReadyCheckReadyUntil = function(unit, value)
        readyUntilByUnit[unit] = value
      end,
      clearAllReadyCheckReady = function()
        readyUntilByUnit = {}
      end,
      clearExpiredReadyCheckReady = function(currentTime)
        local changed = false
        for unit, untilTime in pairs(readyUntilByUnit) do
          if untilTime <= currentTime then
            readyUntilByUnit[unit] = nil
            changed = true
          end
        end
        return changed
      end,
      timerAfter = function(delaySeconds, callback)
        scheduledDelay = delaySeconds
        scheduledCallback = callback
      end,
    })

    controller:Dispatch("READY_CHECK")
    Assert.True(readyCheckActive, "READY_CHECK must mark ready check as active")
    Assert.Equal(counters.readyCheckRefreshes, 1, "READY_CHECK should refresh ready-check UI once")
    Assert.Equal(counters.uiUpdates, 0, "READY_CHECK must not call the generic UI rerender path")

    controller:Dispatch("READY_CHECK_CONFIRM", "party1", "ready")
    Assert.Equal(
      counters.readyCheckRefreshes,
      2,
      "READY_CHECK_CONFIRM should refresh the dedicated ready-check UI while active"
    )
    Assert.Equal(counters.uiUpdates, 0, "READY_CHECK_CONFIRM must not call the generic UI rerender path")

    controller:Dispatch("READY_CHECK_FINISHED")
    Assert.False(readyCheckActive, "READY_CHECK_FINISHED must clear ready check state")
    Assert.Equal(counters.readyCheckRefreshes, 3, "READY_CHECK_FINISHED should refresh ready-check UI once")
    Assert.Equal(counters.uiUpdates, 0, "READY_CHECK_FINISHED must not call the generic UI rerender path")
    Assert.Equal(readyUntilByUnit.party1, 120, "READY_CHECK_FINISHED should keep ready unit green for 20 seconds")
    Assert.Equal(scheduledDelay, 20, "READY_CHECK_FINISHED should schedule a 20-second ready hold cleanup")
    Assert.NotNil(scheduledCallback, "READY_CHECK_FINISHED should schedule a ready-hold cleanup callback")

    now = 121
    controller:Dispatch("READY_CHECK_CONFIRM", "party1", "ready")
    Assert.Equal(
      counters.readyCheckRefreshes,
      4,
      "READY_CHECK_CONFIRM should still refresh ready-check UI after ready check finished"
    )
    Assert.Equal(counters.uiUpdates, 0, "READY_CHECK_CONFIRM after finish must keep the generic UI rerender path idle")
    Assert.Equal(readyUntilByUnit.party1, 141, "late ready confirm should refresh its 20-second hold")
    Assert.Equal(scheduledDelay, 20, "late ready confirm should schedule a 20-second cleanup")
    Assert.NotNil(scheduledCallback, "late ready confirm should schedule a cleanup callback")

    now = 141
    local cleanupCallback = scheduledCallback
    if cleanupCallback == nil then
      error("late ready confirm should schedule a cleanup callback")
    end
    cleanupCallback()

    Assert.Nil(readyUntilByUnit.party1, "late ready confirm hold should clear after the timer expires")
    Assert.Equal(counters.readyCheckRefreshes, 5, "ready-hold expiry should trigger one more ready-check refresh")
    Assert.Equal(counters.uiUpdates, 0, "ready-hold expiry must not call the generic UI rerender path")
  end)

  test("Event handlers write ready check trace entries when runtime logging is available", function()
    local counters = { uiUpdates = 0, readyCheckRefreshes = 0 }
    local readyCheckActive = false
    local now = 100
    local readyUntilByUnit = {}
    local declinedUntilByUnit = {}
    local scheduledCallback = nil
    local logEntries = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      setReadyCheckActive = function(value)
        readyCheckActive = value and true or false
      end,
      isReadyCheckActive = function()
        return readyCheckActive
      end,
      getTime = function()
        return now
      end,
      getRoster = function()
        return {
          party1 = { name = "ReadyOne" },
          party2 = { name = "ReadyTwo" },
        }
      end,
      setReadyCheckReadyUntil = function(unit, value)
        readyUntilByUnit[unit] = value
      end,
      getReadyCheckReadyUntil = function(unit)
        return readyUntilByUnit[unit]
      end,
      clearAllReadyCheckReady = function()
        readyUntilByUnit = {}
      end,
      setReadyCheckDeclinedUntil = function(unit, value)
        declinedUntilByUnit[unit] = value
      end,
      getReadyCheckDeclinedUntil = function(unit)
        return declinedUntilByUnit[unit]
      end,
      clearAllReadyCheckDeclined = function()
        declinedUntilByUnit = {}
      end,
      clearExpiredReadyCheckReady = function(currentTime)
        local changed = false
        for unit, untilTime in pairs(readyUntilByUnit) do
          if untilTime <= currentTime then
            readyUntilByUnit[unit] = nil
            changed = true
          end
        end
        return changed
      end,
      clearExpiredReadyCheckDeclined = function(currentTime)
        local changed = false
        for unit, untilTime in pairs(declinedUntilByUnit) do
          if untilTime <= currentTime then
            declinedUntilByUnit[unit] = nil
            changed = true
          end
        end
        return changed
      end,
      timerAfter = function(_delaySeconds, callback)
        scheduledCallback = callback
      end,
      logRuntimeTrace = function(message)
        table.insert(logEntries, message)
      end,
      logRuntimeTracef = function(fmt, ...)
        table.insert(logEntries, string.format(fmt, ...))
      end,
    })

    controller:Dispatch("READY_CHECK")
    controller:Dispatch("READY_CHECK_CONFIRM", "party1", "ready")
    controller:Dispatch("READY_CHECK_FINISHED")

    Assert.Equal(#logEntries, 7, "ready check lifecycle should emit seven trace entries before cleanup")
    Assert.True(
      logEntries[1]:find("[EVENT_DISPATCH] event=READY_CHECK handled=true", 1, true) ~= nil,
      "first trace entry must record the READY_CHECK dispatch"
    )
    Assert.True(logEntries[2]:find("event=READY_CHECK", 1, true) ~= nil, "second trace entry must record READY_CHECK")
    Assert.True(
      logEntries[3]:find("[EVENT_DISPATCH] event=READY_CHECK_CONFIRM handled=true", 1, true) ~= nil,
      "third trace entry must record the READY_CHECK_CONFIRM dispatch"
    )
    Assert.True(
      logEntries[4]:find("event=READY_CHECK_CONFIRM", 1, true) ~= nil,
      "fourth trace entry must record READY_CHECK_CONFIRM"
    )
    Assert.True(
      logEntries[5]:find("[EVENT_DISPATCH] event=READY_CHECK_FINISHED handled=true", 1, true) ~= nil,
      "fifth trace entry must record the READY_CHECK_FINISHED dispatch"
    )
    Assert.True(
      logEntries[6]:find("event=READY_CHECK_FINISHED", 1, true) ~= nil,
      "sixth trace entry must record READY_CHECK_FINISHED"
    )
    Assert.True(
      logEntries[7]:find("[RC_FINISH_HOLD]", 1, true) ~= nil,
      "seventh trace entry must record the ready-check hold snapshot"
    )
    Assert.True(
      logEntries[7]:find("ready_units=party1", 1, true) ~= nil,
      "hold snapshot must record the explicitly ready unit"
    )
    Assert.True(
      logEntries[7]:find("declined_units=party2", 1, true) ~= nil,
      "hold snapshot must record unanswered units promoted to declined"
    )
    Assert.True(
      logEntries[7]:find("ready_until_count=1", 1, true) ~= nil,
      "hold snapshot must count ready hold entries"
    )
    Assert.True(
      logEntries[7]:find("declined_until_count=1", 1, true) ~= nil,
      "hold snapshot must count declined hold entries"
    )

    now = 120
    local cleanupCallback = scheduledCallback
    if cleanupCallback == nil then
      error("ready check trace test must schedule a cleanup callback")
    end
    cleanupCallback()

    Assert.Equal(#logEntries, 8, "cleanup callback should append a hold-clear trace entry")
    Assert.True(logEntries[8]:find("event=HOLD_CLEAR", 1, true) ~= nil, "cleanup trace must record HOLD_CLEAR")
  end)
end

local function RegisterReadyCheckHoldTests(test, Assert, _WithGlobals, LoadAddonModules, Fixtures)
  test("Event handlers keep declined ready-check rows red for 20 seconds after finish", function()
    local counters = { uiUpdates = 0, readyCheckRefreshes = 0 }
    local readyCheckActive = false
    local now = 100
    local declinedUntilByUnit = {}
    local scheduledDelay = nil
    local scheduledCallback = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      setReadyCheckActive = function(value)
        readyCheckActive = value and true or false
      end,
      isReadyCheckActive = function()
        return readyCheckActive
      end,
      getTime = function()
        return now
      end,
      setReadyCheckDeclinedUntil = function(unit, value)
        declinedUntilByUnit[unit] = value
      end,
      clearAllReadyCheckDeclined = function()
        declinedUntilByUnit = {}
      end,
      clearExpiredReadyCheckDeclined = function(currentTime)
        local changed = false
        for unit, untilTime in pairs(declinedUntilByUnit) do
          if untilTime <= currentTime then
            declinedUntilByUnit[unit] = nil
            changed = true
          end
        end
        return changed
      end,
      timerAfter = function(delaySeconds, callback)
        scheduledDelay = delaySeconds
        scheduledCallback = callback
      end,
    })

    controller:Dispatch("READY_CHECK")
    controller:Dispatch("READY_CHECK_CONFIRM", "party1", "notready")
    controller:Dispatch("READY_CHECK_CONFIRM", "party2", "ready")
    controller:Dispatch("READY_CHECK_FINISHED")

    Assert.False(readyCheckActive, "READY_CHECK_FINISHED must clear ready check state")
    Assert.Equal(declinedUntilByUnit.party1, 120, "declined ready-check unit should stay marked for 20 seconds")
    Assert.Nil(declinedUntilByUnit.party2, "ready unit must not receive a declined hold")
    Assert.Equal(scheduledDelay, 20, "declined ready-check hold should schedule one 20-second cleanup refresh")
    Assert.NotNil(scheduledCallback, "declined ready-check hold must schedule a cleanup callback")
    Assert.Equal(counters.readyCheckRefreshes, 4, "finish path should still refresh the dedicated ready-check UI")
    Assert.Equal(counters.uiUpdates, 0, "declined ready-check hold must not use generic updateUI")

    now = 120
    local cleanupCallback = scheduledCallback
    if cleanupCallback == nil then
      error("declined ready-check hold must schedule a cleanup callback")
    end
    cleanupCallback()

    Assert.Nil(declinedUntilByUnit.party1, "declined ready-check hold should clear after the timer expires")
    Assert.Equal(counters.readyCheckRefreshes, 5, "timer expiry should trigger one more dedicated ready-check refresh")
    Assert.Equal(counters.uiUpdates, 0, "timer expiry must not use generic updateUI")
  end)

  test("Event handlers keep ready-check rows green for 20 seconds after finish", function()
    local counters = { uiUpdates = 0, readyCheckRefreshes = 0 }
    local readyCheckActive = false
    local now = 100
    local readyUntilByUnit = {}
    local scheduledDelay = nil
    local scheduledCallback = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      setReadyCheckActive = function(value)
        readyCheckActive = value and true or false
      end,
      isReadyCheckActive = function()
        return readyCheckActive
      end,
      getTime = function()
        return now
      end,
      setReadyCheckReadyUntil = function(unit, value)
        readyUntilByUnit[unit] = value
      end,
      clearAllReadyCheckReady = function()
        readyUntilByUnit = {}
      end,
      clearExpiredReadyCheckReady = function(currentTime)
        local changed = false
        for unit, untilTime in pairs(readyUntilByUnit) do
          if untilTime <= currentTime then
            readyUntilByUnit[unit] = nil
            changed = true
          end
        end
        return changed
      end,
      timerAfter = function(delaySeconds, callback)
        scheduledDelay = delaySeconds
        scheduledCallback = callback
      end,
    })

    controller:Dispatch("READY_CHECK")
    controller:Dispatch("READY_CHECK_CONFIRM", "party2", "ready")
    controller:Dispatch("READY_CHECK_FINISHED")

    Assert.False(readyCheckActive, "READY_CHECK_FINISHED must clear ready check state")
    Assert.Equal(readyUntilByUnit.party2, 120, "ready ready-check unit should stay marked for 20 seconds")
    Assert.Equal(scheduledDelay, 20, "ready ready-check hold should schedule one 20-second cleanup refresh")
    Assert.NotNil(scheduledCallback, "ready ready-check hold must schedule a cleanup callback")
    Assert.Equal(counters.readyCheckRefreshes, 3, "finish path should still refresh the dedicated ready-check UI")
    Assert.Equal(counters.uiUpdates, 0, "ready ready-check hold must not use generic updateUI")

    now = 120
    local cleanupCallback = scheduledCallback
    if cleanupCallback == nil then
      error("ready ready-check hold must schedule a cleanup callback")
    end
    cleanupCallback()

    Assert.Nil(readyUntilByUnit.party2, "ready ready-check hold should clear after the timer expires")
    Assert.Equal(counters.readyCheckRefreshes, 4, "timer expiry should trigger one more dedicated ready-check refresh")
    Assert.Equal(counters.uiUpdates, 0, "timer expiry must not use generic updateUI")
  end)
end

-- Branch-coverage tests for MarkReadyCheckInitiatorReady. The initiator-name
-- arg of the READY_CHECK event flows into roster lookup; on READY_CHECK_FINISHED,
-- a matched initiator lands on setReadyCheckReadyUntil while a non-match
-- promotes the unit to declined via the unanswered-hold path. We observe both
-- via the public dispatch surface — no _Test_GetCtx backdoor needed.
local function BuildInitiatorReadyEnv(LoadAddonModules, Fixtures, roster)
  local readyCheckActive = false
  local readyUntilByUnit = {}
  local declinedUntilByUnit = {}
  local now = 100

  local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
  local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
    setReadyCheckActive = function(value)
      readyCheckActive = value and true or false
    end,
    isReadyCheckActive = function()
      return readyCheckActive
    end,
    getTime = function()
      return now
    end,
    getRoster = function()
      return roster
    end,
    setReadyCheckReadyUntil = function(unit, value)
      readyUntilByUnit[unit] = value
    end,
    clearAllReadyCheckReady = function()
      readyUntilByUnit = {}
    end,
    clearExpiredReadyCheckReady = function()
      return false
    end,
    setReadyCheckDeclinedUntil = function(unit, value)
      declinedUntilByUnit[unit] = value
    end,
    clearAllReadyCheckDeclined = function()
      declinedUntilByUnit = {}
    end,
    clearExpiredReadyCheckDeclined = function()
      return false
    end,
    timerAfter = function() end,
  })
  return controller, function()
    return readyUntilByUnit
  end, function()
    return declinedUntilByUnit
  end
end

local function RegisterReadyCheckInitiatorTests(test, Assert, _WithGlobals, LoadAddonModules, Fixtures)
  test("READY_CHECK same-realm initiator name flags the matching unit as ready", function()
    local roster = {
      player = { name = "Me", realm = "Tichondrius" },
      party1 = { name = "Mematiwow", realm = "Blackmoore" },
      party2 = { name = "Other", realm = "Tichondrius" },
    }
    local controller, getReadyUntil = BuildInitiatorReadyEnv(LoadAddonModules, Fixtures, roster)

    -- Bare name (no '-Realm') — must still match Mematiwow's row by name only.
    controller:Dispatch("READY_CHECK", "Mematiwow")
    controller:Dispatch("READY_CHECK_FINISHED")

    Assert.NotNil(getReadyUntil().party1, "matched initiator unit must land in setReadyCheckReadyUntil after FINISHED")
    Assert.Nil(getReadyUntil().party2, "unrelated unit must not get a ready hold")
  end)

  test("READY_CHECK cross-realm initiator 'Name-Realm' splits and matches by name + realm", function()
    local roster = {
      player = { name = "Me", realm = "Tichondrius" },
      party1 = { name = "Mematiwow", realm = "Blackmoore" },
      party2 = { name = "Mematiwow", realm = "Tichondrius" }, -- same name, different realm
    }
    local controller, getReadyUntil = BuildInitiatorReadyEnv(LoadAddonModules, Fixtures, roster)

    controller:Dispatch("READY_CHECK", "Mematiwow-Blackmoore")
    controller:Dispatch("READY_CHECK_FINISHED")

    Assert.NotNil(getReadyUntil().party1, "the cross-realm match must mark Mematiwow-Blackmoore as ready")
    Assert.Nil(
      getReadyUntil().party2,
      "the same-named, different-realm unit must NOT be flagged when realm hint disambiguates"
    )
  end)

  test("READY_CHECK initiator name with empty realm suffix falls back to bare-name match", function()
    local roster = {
      player = { name = "Me", realm = "Tichondrius" },
      party1 = { name = "Solo", realm = "Blackmoore" },
    }
    local controller, getReadyUntil = BuildInitiatorReadyEnv(LoadAddonModules, Fixtures, roster)

    -- Empty realm after dash: hintRealm becomes nil, falls through to bare-name match.
    controller:Dispatch("READY_CHECK", "Solo-")
    controller:Dispatch("READY_CHECK_FINISHED")

    Assert.NotNil(getReadyUntil().party1, "trailing dash with empty realm must still match by bare name")
  end)

  test("READY_CHECK with no matching initiator promotes unanswered units to declined on FINISHED", function()
    local roster = {
      player = { name = "Me", realm = "Tichondrius" },
      party1 = { name = "Other", realm = "Realm1" },
    }
    local controller, getReadyUntil, getDeclinedUntil = BuildInitiatorReadyEnv(LoadAddonModules, Fixtures, roster)

    controller:Dispatch("READY_CHECK", "DoesNotMatch")
    controller:Dispatch("READY_CHECK_FINISHED")

    Assert.Nil(getReadyUntil().party1, "no match → no ready hold")
    Assert.NotNil(
      getDeclinedUntil().party1,
      "unanswered unit must land in declined hold via PromoteUnansweredReadyCheckUnitsToDeclined"
    )
  end)

  test("READY_CHECK ignores empty initiator name and ghost roster entries", function()
    local roster = {
      player = { name = "Me", realm = "Tichondrius" },
      party1 = { name = "Initiator", realm = "X", isGhost = true }, -- ghost must be skipped
      party2 = { name = "Initiator", realm = "Y" }, -- non-ghost twin must win
    }
    local controller, getReadyUntil = BuildInitiatorReadyEnv(LoadAddonModules, Fixtures, roster)

    -- Empty / non-string initiator → MarkReadyCheckInitiatorReady early-return.
    controller:Dispatch("READY_CHECK", "")
    controller:Dispatch("READY_CHECK_FINISHED")
    Assert.Nil(getReadyUntil().party1, "empty initiator must not flag anyone")
    Assert.Nil(getReadyUntil().party2, "empty initiator must not flag anyone")

    -- Real initiator name: ghost row at party1 must be skipped, party2 wins.
    -- Build a fresh env so the previous READY_CHECK_FINISHED state is gone.
    local controller2, getReadyUntil2 = BuildInitiatorReadyEnv(LoadAddonModules, Fixtures, roster)
    controller2:Dispatch("READY_CHECK", "Initiator")
    controller2:Dispatch("READY_CHECK_FINISHED")
    Assert.Nil(getReadyUntil2().party1, "ghost row must NOT be matched even when name fits")
    Assert.NotNil(getReadyUntil2().party2, "non-ghost twin must be the matched initiator")
  end)
end

local function RegisterReadyCheckCompleteSoundTests(test, Assert, _WithGlobals, LoadAddonModules, Fixtures)
  local function BuildCompleteSoundController(roster, playSound)
    local readyCheckActive = false
    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    return Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      setReadyCheckActive = function(value)
        readyCheckActive = value and true or false
      end,
      isReadyCheckActive = function()
        return readyCheckActive
      end,
      getRoster = function()
        return roster
      end,
      playReadyCheckCompleteSound = playSound,
    })
  end

  test("Event handlers play ready-check complete sound once when all five players are ready", function()
    local soundCalls = 0
    local roster = {
      player = { name = "Me" },
      party1 = { name = "One" },
      party2 = { name = "Two" },
      party3 = { name = "Three" },
      party4 = { name = "Four" },
    }
    local controller = BuildCompleteSoundController(roster, function()
      soundCalls = soundCalls + 1
    end)

    controller:Dispatch("READY_CHECK")
    controller:Dispatch("READY_CHECK_CONFIRM", "player", "ready")
    controller:Dispatch("READY_CHECK_CONFIRM", "party1", true)
    controller:Dispatch("READY_CHECK_CONFIRM", "party2", "ready")
    controller:Dispatch("READY_CHECK_CONFIRM", "party3", 1)
    Assert.Equal(soundCalls, 0, "four ready players must not play the complete sound")

    controller:Dispatch("READY_CHECK_CONFIRM", "party4", "ready")
    Assert.Equal(soundCalls, 1, "the fifth ready player must play the complete sound exactly once")

    controller:Dispatch("READY_CHECK_CONFIRM", "party4", "ready")
    controller:Dispatch("READY_CHECK_CONFIRM", "party3", "ready")
    Assert.Equal(soundCalls, 1, "duplicate ready confirmations must not replay the complete sound")
  end)

  test("Event handlers keep ready-check complete sound silent unless exactly five players are ready", function()
    local soundCalls = 0
    local roster = {
      player = { name = "Me" },
      party1 = { name = "One" },
      party2 = { name = "Two" },
      party3 = { name = "Three" },
    }
    local controller = BuildCompleteSoundController(roster, function()
      soundCalls = soundCalls + 1
    end)

    controller:Dispatch("READY_CHECK")
    controller:Dispatch("READY_CHECK_CONFIRM", "player", "ready")
    controller:Dispatch("READY_CHECK_CONFIRM", "party1", "ready")
    controller:Dispatch("READY_CHECK_CONFIRM", "party2", "ready")
    controller:Dispatch("READY_CHECK_CONFIRM", "party3", "ready")
    Assert.Equal(soundCalls, 0, "underfilled ready checks must not play the complete sound")

    roster.party4 = { name = "Four", isGhost = true }
    controller:Dispatch("READY_CHECK")
    controller:Dispatch("READY_CHECK_CONFIRM", "player", "ready")
    controller:Dispatch("READY_CHECK_CONFIRM", "party1", "ready")
    controller:Dispatch("READY_CHECK_CONFIRM", "party2", "ready")
    controller:Dispatch("READY_CHECK_CONFIRM", "party3", "ready")
    controller:Dispatch("READY_CHECK_CONFIRM", "party4", "ready")
    Assert.Equal(soundCalls, 0, "ghost roster rows must not count toward the five-player ready gate")
  end)
end

local function RegisterReadyCheckAndStatsTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterReadyCheckLifecycleTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterReadyCheckHoldTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterReadyCheckHoldAndRunRecordTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterReadyCheckInitiatorTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterReadyCheckCompleteSoundTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules
  local Fixtures = ctx.fixtures

  RegisterReadyCheckAndStatsTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
end
