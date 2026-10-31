local function RegisterChallengeStartAndDelayTests(test, Assert, _WithGlobals, LoadAddonModules, Fixtures)
  test("Event handlers capture RIO baseline snapshot on challenge start", function()
    local captureCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      captureRioBaselineSnapshot = function()
        captureCalls = captureCalls + 1
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_START")

    Assert.Equal(captureCalls, 1, "challenge start must capture one RIO baseline snapshot")
  end)

  test("Event handlers do not auto-hide main frame on challenge start by default", function()
    local hideCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      setMainFrameVisible = function(_visible)
        hideCalls = hideCalls + 1
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_START")

    Assert.Equal(hideCalls, 0, "challenge start must keep the main frame state unchanged by default")
  end)

  test("Event handlers auto-hide main frame on challenge start when auto-close is enabled", function()
    local hideCalls = 0
    local lastVisible = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      shouldAutoCloseOnKeyStart = function()
        return true
      end,
      setMainFrameVisible = function(visible)
        hideCalls = hideCalls + 1
        lastVisible = visible
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_START")

    Assert.Equal(hideCalls, 1, "enabled auto-close must hide the main frame on challenge start exactly once")
    Assert.Equal(lastVisible, false, "enabled auto-close must request a hidden main frame")
  end)

  test("Event handlers reset kick stats on challenge start", function()
    local resetCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      resetKickStats = function()
        resetCalls = resetCalls + 1
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_START")

    Assert.Equal(resetCalls, 1, "challenge start must reset kick stats exactly once")
  end)

  test("Event handlers forward challenge start to LFGDetect", function()
    local lfgEvents = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      handleLFGDetectEvent = function(event)
        lfgEvents[#lfgEvents + 1] = event
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_START")

    Assert.Equal(#lfgEvents, 1, "challenge start must notify LFGDetect exactly once")
    Assert.Equal(lfgEvents[1], "CHALLENGE_MODE_START", "LFGDetect must receive the key-start boundary")
  end)

  test("Event handlers auto-show main frame on challenge completion while grouped", function()
    local showCalls = 0
    local lastVisible = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      setMainFrameVisible = function(visible)
        showCalls = showCalls + 1
        lastVisible = visible
      end,
      isInGroup = function()
        return true
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")

    Assert.Equal(showCalls, 1, "challenge completion must call main-frame visibility update exactly once")
    Assert.Equal(lastVisible, true, "challenge completion must auto-show main frame while grouped")
  end)

  test("Event handlers skip auto-show on challenge completion when key-end setting is disabled", function()
    local showCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      shouldAutoOpenMainFrameOnKeyEnd = function()
        return false
      end,
      setMainFrameVisible = function(_visible)
        showCalls = showCalls + 1
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")

    Assert.Equal(showCalls, 0, "disabled key-end auto-open must not request a frame open on completion")
  end)

  test("Event handlers refresh CD tracker on challenge completion and reset", function()
    local cdRefreshCalls = 0
    local timerEvents = {}
    local cdRefreshOpts = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      handleMplusTimerEvent = function(event)
        timerEvents[#timerEvents + 1] = event
      end,
      updateCdTracker = function(opts)
        cdRefreshCalls = cdRefreshCalls + 1
        cdRefreshOpts[#cdRefreshOpts + 1] = opts
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    controller:Dispatch("CHALLENGE_MODE_RESET")

    Assert.Equal(timerEvents[1], "CHALLENGE_MODE_COMPLETED", "completion must reach the M+ timer before UI refresh")
    Assert.Equal(timerEvents[2], "CHALLENGE_MODE_RESET", "reset must reach the M+ timer before UI refresh")
    Assert.Equal(cdRefreshCalls, 2, "key end and key reset must refresh the CD tracker row")
    Assert.True(cdRefreshOpts[1].resetRuntimeTimers, "completion must request a visible BR/BL timer reset")
    Assert.True(cdRefreshOpts[2].resetRuntimeTimers, "reset must request a visible BR/BL timer reset")
    Assert.True(cdRefreshOpts[1].suppressBattleResReadySound, "completion must suppress BRes-ready sound")
    Assert.True(cdRefreshOpts[1].suppressLustReadySound, "completion must suppress Bloodlust-ready sound")
  end)

  test("Event handlers enable RIO delta only after delayed post-run refresh", function()
    local enableCalls = 0
    local refreshCalls = 0
    local delayedCallback = nil

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      timerAfter = function(seconds, callback)
        if seconds == 5 then
          delayedCallback = callback
        end
      end,
      runFullRefresh = function()
        refreshCalls = refreshCalls + 1
        return true
      end,
      enableRioDeltaDisplay = function()
        enableCalls = enableCalls + 1
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")

    Assert.Equal(enableCalls, 0, "delta display must stay disabled before delayed refresh callback")
    Assert.NotNil(delayedCallback, "post-run refresh must be scheduled with delay")
    if type(delayedCallback) ~= "function" then
      return
    end

    delayedCallback()

    Assert.Equal(refreshCalls, 1, "delayed callback must run one refresh attempt")
    Assert.Equal(enableCalls, 1, "delta display must enable after delayed refresh")
  end)
end

local function RegisterChallengeRetryTests(test, Assert, LoadAddonModules, Fixtures)
  test("Event handlers retry post-run refresh when first delayed attempt is blocked", function()
    local enableCalls = 0
    local refreshCalls = 0
    local callbacks = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      timerAfter = function(_seconds, callback)
        table.insert(callbacks, callback)
      end,
      runFullRefresh = function()
        refreshCalls = refreshCalls + 1
        return refreshCalls >= 2
      end,
      enableRioDeltaDisplay = function()
        enableCalls = enableCalls + 1
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")

    Assert.Equal(enableCalls, 0, "delta display must stay disabled until refresh succeeds")
    Assert.Equal(#callbacks, 1, "initial delayed refresh callback must be scheduled")

    callbacks[1]()
    Assert.Equal(refreshCalls, 1, "first delayed refresh attempt should run once")
    Assert.Equal(enableCalls, 0, "delta display must not enable on failed refresh attempt")
    Assert.Equal(#callbacks, 2, "failed attempt must schedule one retry callback")

    callbacks[2]()
    Assert.Equal(refreshCalls, 2, "retry callback should run second refresh attempt")
    Assert.Equal(enableCalls, 1, "delta display must enable after successful retry")
  end)

  test("Event handlers keep RIO delta disabled when every post-run refresh fails", function()
    local enableCalls = 0
    local refreshCalls = 0
    local callbacks = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      timerAfter = function(_seconds, callback)
        table.insert(callbacks, callback)
      end,
      runFullRefresh = function()
        refreshCalls = refreshCalls + 1
        return false
      end,
      enableRioDeltaDisplay = function()
        enableCalls = enableCalls + 1
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")

    -- Drain the whole retry chain. Every attempt reports failure, so the last
    -- one runs with no retries left and falls through instead of rescheduling.
    local index = 1
    while callbacks[index] do
      callbacks[index]()
      index = index + 1
      Assert.True(index < 20, "retry chain must terminate")
    end

    Assert.True(refreshCalls > 1, "the failing refresh must have been retried")
    Assert.Equal(
      enableCalls,
      0,
      "delta display must stay disabled when the retries run out without a successful refresh"
    )
  end)

  test("Event handlers keep RIO delta disabled when the group is gone before the delayed refresh", function()
    -- Leaving the group between the run ending and the delayed callback means
    -- no post-run refresh ever ran, so rule 4 forbids the delta just as it does
    -- for an exhausted retry chain.
    local enableCalls = 0
    local refreshCalls = 0
    local callbacks = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      timerAfter = function(_seconds, callback)
        table.insert(callbacks, callback)
      end,
      isInGroup = function()
        return false
      end,
      runFullRefresh = function()
        refreshCalls = refreshCalls + 1
        return true
      end,
      enableRioDeltaDisplay = function()
        enableCalls = enableCalls + 1
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    Assert.NotNil(callbacks[1], "the delayed refresh must still be scheduled")
    callbacks[1]()

    Assert.Equal(refreshCalls, 0, "a group that no longer exists must not be refreshed")
    Assert.Equal(enableCalls, 0, "delta display must stay disabled when no refresh ran")
  end)

  test("Event handlers schedule no post-run follow-up after a successful delayed refresh", function()
    local refreshCalls = 0
    local scheduled = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      timerAfter = function(seconds, callback)
        table.insert(scheduled, {
          seconds = seconds,
          callback = callback,
        })
      end,
      runFullRefresh = function()
        refreshCalls = refreshCalls + 1
        return true
      end,
    })

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    Assert.Equal(#scheduled, 1, "initial delayed refresh callback must be scheduled")
    Assert.Equal(scheduled[1].seconds, 5, "initial delayed refresh should use 5-second delay")

    scheduled[1].callback()
    Assert.Equal(refreshCalls, 1, "initial delayed callback should run one refresh attempt")
    Assert.Equal(#scheduled, 1, "a successful refresh must not schedule a follow-up refresh")
  end)

  test("Event handlers retry completed-run capture when damage meter snapshot is delayed", function()
    local captureAttempts = 0
    local scheduled = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      timerAfter = function(seconds, callback)
        table.insert(scheduled, {
          seconds = seconds,
          callback = callback,
        })
      end,
      recordRun = function(mapID, level, onTime)
        captureAttempts = captureAttempts + 1
        Assert.Equal(mapID, 2662, "completed-run retry must keep challenge map id")
        Assert.Equal(level, 10, "completed-run retry must keep challenge level")
        Assert.True(onTime == true, "completed-run retry must keep timed flag")
        return captureAttempts >= 2
      end,
    })

    local previousChallengeMode = _G.C_ChallengeMode
    _G.C_ChallengeMode = {
      GetChallengeCompletionInfo = function()
        return {
          mapChallengeModeID = 2662,
          level = 10,
          time = 123456,
          onTime = true,
        }
      end,
    }

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    _G.C_ChallengeMode = previousChallengeMode

    Assert.Equal(captureAttempts, 1, "challenge completion should attempt immediate run capture once")
    Assert.Equal(#scheduled, 2, "challenge completion should schedule one capture retry plus delayed refresh")
    Assert.Equal(scheduled[1].seconds, 1, "capture retry should use short fixed delay")
    Assert.Equal(scheduled[2].seconds, 5, "delayed refresh should keep its existing delay")

    scheduled[1].callback()

    Assert.Equal(captureAttempts, 2, "capture retry should attempt completed-run capture again")
  end)

  test("Event handlers record an abandoned key from the identity stashed at start", function()
    -- A key left mid-run produces no completion info, so without the start
    -- stash the group's damage is dropped even though the meter still holds it.
    local recordedRuns = {}
    local inChallenge = true
    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      isInChallengeMode = function()
        return inChallenge
      end,
      recordRun = function(mapID, level, onTime)
        table.insert(recordedRuns, { mapID = mapID, level = level, onTime = onTime })
        return true
      end,
    })

    local previousChallengeMode = _G.C_ChallengeMode
    _G.C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        return 2649
      end,
      GetActiveKeystoneInfo = function()
        return 13, {}, true
      end,
    }

    controller:Dispatch("CHALLENGE_MODE_START")
    inChallenge = false
    controller:Dispatch("CHALLENGE_MODE_RESET")
    _G.C_ChallengeMode = previousChallengeMode

    Assert.Equal(#recordedRuns, 1, "an abandoned key must record exactly one run")
    Assert.Equal(recordedRuns[1].mapID, 2649, "the abandoned run must carry the running key's map id")
    Assert.Equal(recordedRuns[1].level, 13, "the abandoned run must carry the inserted keystone level")
    Assert.False(recordedRuns[1].onTime, "an abandoned key is never a timed run")
  end)

  test("Event handlers do not record an abandoned run for a key that completed", function()
    -- The completed path clears the stash, so the reset that follows a finished
    -- key must not write a second, level-less run over its result.
    local recordedRuns = {}
    local inChallenge = true
    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      isInChallengeMode = function()
        return inChallenge
      end,
      recordRun = function(mapID, level, onTime)
        table.insert(recordedRuns, { mapID = mapID, level = level, onTime = onTime })
        return true
      end,
    })

    local previousChallengeMode = _G.C_ChallengeMode
    _G.C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        return 2649
      end,
      GetActiveKeystoneInfo = function()
        return 13, {}, true
      end,
      GetChallengeCompletionInfo = function()
        return {
          mapChallengeModeID = 2649,
          level = 13,
          time = 1500000,
          onTime = true,
        }
      end,
    }

    controller:Dispatch("CHALLENGE_MODE_START")
    inChallenge = false
    controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    controller:Dispatch("CHALLENGE_MODE_RESET")
    _G.C_ChallengeMode = previousChallengeMode

    Assert.Equal(#recordedRuns, 1, "a completed key must record exactly once across completion and reset")
    Assert.True(recordedRuns[1].onTime, "the recorded run must be the completed one, not an abandoned fallback")
  end)

  test("Event handlers resolve completed-run info from the pre-12.0 completion tuple", function()
    -- GetCompletionInfo was removed in 12.0.0, but a client that still carries
    -- the tuple form must keep producing the same run identity.
    local recordedRuns = {}
    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      recordRun = function(mapID, level, onTime)
        table.insert(recordedRuns, { mapID = mapID, level = level, onTime = onTime })
        return true
      end,
    })

    local previousChallengeMode = _G.C_ChallengeMode
    _G.C_ChallengeMode = {
      GetCompletionInfo = function()
        return 2649, 15, 987654, false
      end,
    }

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    _G.C_ChallengeMode = previousChallengeMode

    Assert.Equal(#recordedRuns, 1, "the legacy tuple must still record exactly one completed run")
    Assert.Equal(recordedRuns[1].mapID, 2649, "legacy tuple map id must reach the run snapshot")
    Assert.Equal(recordedRuns[1].level, 15, "legacy tuple level must reach the run snapshot")
    Assert.False(recordedRuns[1].onTime, "legacy tuple timed flag must reach the run snapshot")
  end)

  test("Event handlers record no run when the removed completion API is all the client offers", function()
    -- The 12.0 client exposes neither function under this name: reading the
    -- removed one must fail closed instead of raising, and the capture must
    -- not run with a half-resolved run identity.
    local recordedRuns = {}
    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      recordRun = function(mapID, level, onTime)
        table.insert(recordedRuns, { mapID = mapID, level = level, onTime = onTime })
        return true
      end,
    })

    local previousChallengeMode = _G.C_ChallengeMode
    _G.C_ChallengeMode = {}

    controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    _G.C_ChallengeMode = previousChallengeMode

    Assert.Equal(#recordedRuns, 0, "an unresolvable run identity must not reach the run snapshot")
  end)
end

-- Key end banner (rule 231) through the real dispatcher. `opts.completion` is
-- what GetChallengeCompletionInfo answers; `opts.inGroup` the starting group
-- state. The outcomes reaching the UI land in driver.outcomes.
local function RegisterKeyEndBannerTests(test, Assert, LoadAddonModules, Fixtures)
  local function NewDriver(opts)
    local driver = {
      outcomes = {},
      clears = 0,
      inChallenge = true,
      inGroup = opts.inGroup ~= false,
      completion = opts.completion,
    }
    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      isInChallengeMode = function()
        return driver.inChallenge
      end,
      isInGroup = function()
        return driver.inGroup
      end,
      recordRun = function()
        return true
      end,
      showKeyEndOutcome = function(outcome)
        table.insert(driver.outcomes, outcome)
      end,
      clearKeyEndOutcome = function()
        driver.clears = driver.clears + 1
      end,
    })
    function driver.Dispatch(event)
      local previous = _G.C_ChallengeMode
      _G.C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return 2649
        end,
        GetActiveKeystoneInfo = function()
          return 13, {}, true
        end,
        GetChallengeCompletionInfo = function()
          return driver.completion
        end,
      }
      local ok, err = pcall(controller.Dispatch, controller, event)
      _G.C_ChallengeMode = previous
      if not ok then
        error(err, 0)
      end
    end
    driver.Dispatch("CHALLENGE_MODE_START")
    driver.clears = 0
    return driver
  end

  local function Completion(onTime)
    return { mapChallengeModeID = 2649, level = 13, time = 1800000, onTime = onTime }
  end

  test("Key end banner names a timed key from verified completion info", function()
    local driver = NewDriver({ completion = Completion(true) })
    driver.inChallenge = false
    driver.Dispatch("CHALLENGE_MODE_COMPLETED")
    Assert.Equal(#driver.outcomes, 1, "a completed key shows one banner")
    Assert.Equal(driver.outcomes[1], "timed", "onTime true is a timed key")
  end)

  test("Key end banner names a key over time from verified completion info", function()
    local driver = NewDriver({ completion = Completion(false) })
    driver.inChallenge = false
    driver.Dispatch("CHALLENGE_MODE_COMPLETED")
    Assert.Equal(#driver.outcomes, 1, "a completed key shows one banner")
    Assert.Equal(driver.outcomes[1], "late", "onTime false is a key over time")
  end)

  test("Key end banner stays away when onTime is unreadable", function()
    local driver = NewDriver({ completion = Completion(nil) })
    driver.inChallenge = false
    driver.Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.Dispatch("CHALLENGE_MODE_RESET")
    Assert.Equal(#driver.outcomes, 0, "an unreadable verdict shows no banner")
  end)

  test("Key end banner does not call a completed key without data abandoned", function()
    local driver = NewDriver({ completion = nil })
    driver.inChallenge = false
    driver.Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.Dispatch("CHALLENGE_MODE_RESET")
    Assert.Equal(#driver.outcomes, 0, "COMPLETED without data then RESET is no abandoned key")
  end)

  test("Key end banner uses completion data that arrives with the reset", function()
    local driver = NewDriver({ completion = nil })
    driver.inChallenge = false
    driver.Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.completion = Completion(true)
    driver.Dispatch("CHALLENGE_MODE_RESET")
    Assert.Equal(#driver.outcomes, 1, "the delayed verdict shows one banner")
    Assert.Equal(driver.outcomes[1], "timed", "the delayed verdict names the key")
  end)

  test("Key end banner shows once when a reset follows a completed key", function()
    local driver = NewDriver({ completion = Completion(true) })
    driver.inChallenge = false
    driver.Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.Dispatch("CHALLENGE_MODE_RESET")
    Assert.Equal(#driver.outcomes, 1, "the reset after a completed key adds nothing")
    Assert.Equal(driver.outcomes[1], "timed", "the verdict stays")
  end)

  test("Key end banner names an abandoned key on reset", function()
    local driver = NewDriver({})
    driver.inChallenge = false
    driver.Dispatch("CHALLENGE_MODE_RESET")
    Assert.Equal(#driver.outcomes, 1, "an abandoned key shows one banner")
    Assert.Equal(driver.outcomes[1], "abandoned", "a reset without completion is an abandoned key")
  end)

  test("Key end banner stays away when the player walks out while the group stays", function()
    local driver = NewDriver({})
    driver.inChallenge = false
    driver.Dispatch("PLAYER_ENTERING_WORLD")
    Assert.Equal(#driver.outcomes, 0, "the key goes on for the group")
  end)

  test("Key end banner shows the left group once at the roster update", function()
    local driver = NewDriver({})
    driver.inGroup = false
    driver.Dispatch("GROUP_ROSTER_UPDATE")
    Assert.Equal(#driver.outcomes, 1, "leaving the group shows the banner while the map is still active")
    Assert.Equal(driver.outcomes[1], "left", "the outcome names the departure")
    driver.Dispatch("GROUP_ROSTER_UPDATE")
    driver.inChallenge = false
    driver.Dispatch("PLAYER_ENTERING_WORLD")
    driver.Dispatch("CHALLENGE_MODE_RESET")
    Assert.Equal(#driver.outcomes, 1, "later roster, world and reset events add nothing")
  end)

  test("Key end banner does not report a left group for a key started solo", function()
    local driver = NewDriver({ inGroup = false })
    driver.Dispatch("GROUP_ROSTER_UPDATE")
    driver.inChallenge = false
    driver.Dispatch("PLAYER_ENTERING_WORLD")
    Assert.Equal(#driver.outcomes, 0, "a solo key has no group to leave")
  end)

  test("Key end banner stands through zoning and ends with the next key", function()
    local driver = NewDriver({ completion = Completion(true) })
    driver.Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.Dispatch("CHALLENGE_MODE_RESET")
    driver.inChallenge = false
    driver.Dispatch("PLAYER_ENTERING_WORLD")
    driver.Dispatch("GROUP_ROSTER_UPDATE")
    Assert.Equal(driver.clears, 0, "a change that is no status change keeps the banner")
    driver.Dispatch("CHALLENGE_MODE_START")
    Assert.Equal(driver.clears, 1, "a new key ends the banner")
  end)

  test("Key end banner ends at once when a new group is joined", function()
    local driver = NewDriver({ completion = Completion(true) })
    driver.Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.inGroup = false
    driver.Dispatch("GROUP_ROSTER_UPDATE")
    Assert.Equal(driver.clears, 0, "leaving the group alone does not end the banner")
    driver.inGroup = true
    driver.Dispatch("GROUP_ROSTER_UPDATE")
    Assert.Equal(driver.clears, 1, "joining a group ends the banner")
  end)

  test("Key end banner of a solo key ends when a group is joined", function()
    local driver = NewDriver({ inGroup = false, completion = Completion(true) })
    driver.Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.Dispatch("GROUP_ROSTER_UPDATE")
    Assert.Equal(driver.clears, 0, "a solo key has no group to leave")
    driver.inGroup = true
    driver.Dispatch("GROUP_ROSTER_UPDATE")
    Assert.Equal(driver.clears, 1, "the first group ends the banner")
  end)
end

-- Split out of RegisterChallengeRetryTests to keep that function under the
-- 420-line metrics limit.
local function RegisterAbandonedRunIdentityTests(test, Assert, LoadAddonModules, Fixtures)
  -- Drives START -> RESET for an abandoned 2649 +13 while GetChallengeCompletionInfo
  -- answers with `completion`, and returns every run handed to recordRun.
  local function RecordAbandonedKeyWithCompletionInfo(completion)
    local recordedRuns = {}
    local inChallenge = true
    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      isInChallengeMode = function()
        return inChallenge
      end,
      recordRun = function(mapID, level, onTime)
        table.insert(recordedRuns, { mapID = mapID, level = level, onTime = onTime })
        return true
      end,
    })

    local previousChallengeMode = _G.C_ChallengeMode
    _G.C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        return 2649
      end,
      GetActiveKeystoneInfo = function()
        return 13, {}, true
      end,
      GetChallengeCompletionInfo = function()
        return completion
      end,
    }

    controller:Dispatch("CHALLENGE_MODE_START")
    inChallenge = false
    controller:Dispatch("CHALLENGE_MODE_RESET")
    _G.C_ChallengeMode = previousChallengeMode
    return recordedRuns
  end

  test("Event handlers treat a zero-default completion struct as no completion", function()
    -- ChallengeCompletionInfo documents its numeric fields as "default 0". An
    -- abandoned key must not be recorded under map 0 / level 0, and must still
    -- reach the abandoned path with the identity stashed at start.
    local recordedRuns = RecordAbandonedKeyWithCompletionInfo({
      mapChallengeModeID = 0,
      level = 0,
      time = 0,
      onTime = false,
    })
    Assert.Equal(#recordedRuns, 1, "an abandoned key must record exactly one run")
    Assert.Equal(recordedRuns[1].mapID, 2649, "the run must carry the running key's map id, not the default 0")
    Assert.Equal(recordedRuns[1].level, 13, "the run must carry the inserted keystone level, not the default 0")
  end)

  test("Event handlers ignore completion info left over from an earlier key on reset", function()
    local recordedRuns = RecordAbandonedKeyWithCompletionInfo({
      mapChallengeModeID = 2662,
      level = 10,
      time = 123456,
      onTime = true,
    })
    Assert.Equal(#recordedRuns, 1, "an abandoned key must record exactly one run")
    Assert.Equal(recordedRuns[1].mapID, 2649, "a stale completion must not relabel the abandoned key's map")
    Assert.Equal(recordedRuns[1].level, 13, "a stale completion must not relabel the abandoned key's level")
    Assert.False(recordedRuns[1].onTime, "the abandoned run must not inherit the stale timed flag")
  end)

  test("Event handlers do not record a completed key as abandoned while its capture retry is pending", function()
    local recordedRuns = {}
    local captureReady = false
    local completionCleared = false
    local inChallenge = true
    local scheduled = {}
    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      isInChallengeMode = function()
        return inChallenge
      end,
      timerAfter = function(seconds, callback)
        table.insert(scheduled, { seconds = seconds, callback = callback })
      end,
      recordRun = function(mapID, level, onTime)
        if not captureReady then
          return false
        end
        table.insert(recordedRuns, { mapID = mapID, level = level, onTime = onTime })
        return true
      end,
    })

    local previousChallengeMode = _G.C_ChallengeMode
    _G.C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        return 2649
      end,
      GetActiveKeystoneInfo = function()
        return 13, {}, true
      end,
      GetChallengeCompletionInfo = function()
        if completionCleared then
          return { mapChallengeModeID = 0, level = 0, time = 0, onTime = false }
        end
        return {
          mapChallengeModeID = 2649,
          level = 13,
          time = 1500000,
          onTime = true,
        }
      end,
    }

    controller:Dispatch("CHALLENGE_MODE_START")
    inChallenge = false
    -- The damage meter has not finalized yet: the first capture fails and a
    -- retry is scheduled. The meter becomes ready before the reset arrives.
    controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    -- By the reset the completion struct is back to its zero defaults, so the
    -- reset itself resolves no completion.
    captureReady = true
    completionCleared = true
    controller:Dispatch("CHALLENGE_MODE_RESET")
    for _, entry in ipairs(scheduled) do
      if entry.seconds == 1 then
        entry.callback()
      end
    end
    _G.C_ChallengeMode = previousChallengeMode

    Assert.Equal(#recordedRuns, 1, "the completed key must be recorded exactly once")
    Assert.True(recordedRuns[1].onTime, "the recorded run must keep the completed run's timed flag")
  end)
end

local function RegisterStaleCompletionTests(test, Assert, LoadAddonModules, Fixtures)
  -- Real dispatcher plus a mutable completion struct: `completion` is what
  -- GetChallengeCompletionInfo answers at the moment each event is dispatched.
  local function BuildRunDriver(opts)
    opts = opts or {}
    local driver = { recordedRuns = {}, scheduled = {}, completion = opts.completion }
    local inChallenge = false
    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      isInChallengeMode = function()
        return inChallenge
      end,
      timerAfter = function(seconds, callback)
        table.insert(driver.scheduled, { seconds = seconds, callback = callback })
      end,
      recordRun = function(mapID, level, onTime)
        if driver.captureBlocked then
          return false
        end
        table.insert(driver.recordedRuns, { mapID = mapID, level = level, onTime = onTime })
        return true
      end,
    })

    function driver.Dispatch(event)
      local previousChallengeMode = _G.C_ChallengeMode
      _G.C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return 2649
        end,
        GetActiveKeystoneInfo = function()
          return 13, {}, true
        end,
        GetChallengeCompletionInfo = function()
          return driver.completion
        end,
      }
      inChallenge = event == "CHALLENGE_MODE_START"
      controller:Dispatch(event)
      _G.C_ChallengeMode = previousChallengeMode
    end

    function driver.FireCaptureRetries()
      for _, entry in ipairs(driver.scheduled) do
        if entry.seconds == 1 then
          entry.callback()
        end
      end
    end

    return driver
  end

  local PREVIOUS_RUN = { mapChallengeModeID = 2649, level = 13, time = 123456, onTime = true }
  local EMPTY_COMPLETION = { mapChallengeModeID = 0, level = 0, time = 0, onTime = false }

  test("Event handlers keep an abandoned key abandoned when stale completion info names the same key", function()
    local driver = BuildRunDriver({ completion = PREVIOUS_RUN })
    driver.Dispatch("CHALLENGE_MODE_START")
    driver.Dispatch("CHALLENGE_MODE_RESET")

    Assert.Equal(#driver.recordedRuns, 1, "the abandoned key must record exactly one run")
    Assert.Equal(driver.recordedRuns[1].mapID, 2649, "the run must keep the running key's map id")
    Assert.Equal(driver.recordedRuns[1].level, 13, "the run must keep the running key's level")
    Assert.False(driver.recordedRuns[1].onTime, "an equal map and level do not prove this run was timed")
  end)

  test("Event handlers accept completion info that arrives after the completed event by reset", function()
    local driver = BuildRunDriver({ completion = EMPTY_COMPLETION })
    driver.Dispatch("CHALLENGE_MODE_START")
    driver.Dispatch("CHALLENGE_MODE_COMPLETED")
    Assert.Equal(#driver.recordedRuns, 0, "completion without data must not record yet")

    driver.completion = { mapChallengeModeID = 2649, level = 13, time = 654321, onTime = true }
    driver.Dispatch("CHALLENGE_MODE_RESET")

    Assert.Equal(#driver.recordedRuns, 1, "the delayed completion must record exactly once")
    Assert.True(driver.recordedRuns[1].onTime, "the delayed completion must keep its timed flag")
  end)

  test("Event handlers do not add an abandoned run when delayed completion info awaits its capture", function()
    local driver = BuildRunDriver({ completion = EMPTY_COMPLETION })
    driver.Dispatch("CHALLENGE_MODE_START")
    driver.Dispatch("CHALLENGE_MODE_COMPLETED")

    driver.completion = { mapChallengeModeID = 2649, level = 13, time = 654321, onTime = true }
    driver.captureBlocked = true
    driver.Dispatch("CHALLENGE_MODE_RESET")
    driver.captureBlocked = false
    driver.FireCaptureRetries()

    Assert.Equal(#driver.recordedRuns, 1, "the delayed completion must record exactly once")
    Assert.True(driver.recordedRuns[1].onTime, "the capture retry must keep the completed result")
  end)

  test("Event handlers rule out delayed completion info naming another key", function()
    local driver = BuildRunDriver({ completion = EMPTY_COMPLETION })
    driver.Dispatch("CHALLENGE_MODE_START")
    driver.Dispatch("CHALLENGE_MODE_COMPLETED")

    driver.completion = { mapChallengeModeID = 2662, level = 10, time = 654321, onTime = true }
    driver.Dispatch("CHALLENGE_MODE_RESET")

    Assert.Equal(#driver.recordedRuns, 1, "the run must fall back to its stashed identity")
    Assert.Equal(driver.recordedRuns[1].mapID, 2649, "foreign completion info must not relabel the run")
    Assert.False(driver.recordedRuns[1].onTime, "foreign completion info must not lend its timed flag")
  end)

  test("Event handlers do not take completion info naming another key at the completed event", function()
    local driver = BuildRunDriver({ completion = { mapChallengeModeID = 2662, level = 10, time = 1, onTime = true } })
    driver.Dispatch("CHALLENGE_MODE_START")
    driver.Dispatch("CHALLENGE_MODE_COMPLETED")
    Assert.Equal(#driver.recordedRuns, 0, "the previous key's struct must not be recorded for this run")

    driver.Dispatch("CHALLENGE_MODE_RESET")
    Assert.Equal(#driver.recordedRuns, 1, "the run must fall back to its stashed identity")
    Assert.Equal(driver.recordedRuns[1].mapID, 2649, "the previous key must not relabel the run")
    Assert.False(driver.recordedRuns[1].onTime, "the previous key must not lend its timed flag")
  end)

  test("Event handlers accept the real completion after a contradicting struct at the completed event", function()
    local driver = BuildRunDriver({ completion = { mapChallengeModeID = 2662, level = 10, time = 1, onTime = true } })
    driver.Dispatch("CHALLENGE_MODE_START")
    driver.Dispatch("CHALLENGE_MODE_COMPLETED")

    driver.completion = { mapChallengeModeID = 2649, level = 13, time = 654321, onTime = true }
    driver.Dispatch("CHALLENGE_MODE_RESET")

    Assert.Equal(#driver.recordedRuns, 1, "the delayed completion must record exactly once")
    Assert.Equal(driver.recordedRuns[1].mapID, 2649, "the delayed completion must name this run")
    Assert.True(driver.recordedRuns[1].onTime, "the delayed completion must keep its timed flag")
  end)

  test("Event handlers keep completion info at the completed event without a stashed run", function()
    local driver = BuildRunDriver({ completion = { mapChallengeModeID = 2662, level = 10, time = 1, onTime = true } })
    driver.Dispatch("CHALLENGE_MODE_COMPLETED")

    Assert.Equal(#driver.recordedRuns, 1, "without a known run nothing contradicts the completion")
    Assert.Equal(driver.recordedRuns[1].mapID, 2662, "the completion must keep its own map id")
  end)

  test("Event handlers record nothing on a reset without any known run", function()
    -- No CHALLENGE_MODE_START was seen, for example after a reload during the
    -- key: the completion struct cannot be tied to anything that ended now.
    local driver = BuildRunDriver({ completion = PREVIOUS_RUN })
    driver.Dispatch("CHALLENGE_MODE_RESET")

    Assert.Equal(#driver.recordedRuns, 0, "a reset without run evidence must not record a success")
  end)

  test("Event handlers do not hand a pending capture retry to the next key", function()
    local driver = BuildRunDriver({ completion = PREVIOUS_RUN })
    driver.Dispatch("CHALLENGE_MODE_START")
    driver.captureBlocked = true
    driver.Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.Dispatch("CHALLENGE_MODE_START")
    driver.captureBlocked = false
    driver.FireCaptureRetries()
    Assert.Equal(#driver.recordedRuns, 0, "the old retry must not record into the new key")

    driver.Dispatch("CHALLENGE_MODE_RESET")
    Assert.Equal(#driver.recordedRuns, 1, "the new key must record its own abandoned run")
    Assert.False(driver.recordedRuns[1].onTime, "the new key must not inherit the old timed result")
  end)
end

local function RegisterPostRunRefreshChainTests(test, Assert, LoadAddonModules, Fixtures)
  local function BuildChainDriver(opts)
    opts = opts or {}
    local driver = { refreshCalls = 0, enableCalls = 0, scheduled = {}, inRaid = false }
    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    driver.controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      timerAfter = function(seconds, callback)
        table.insert(driver.scheduled, { seconds = seconds, callback = callback })
      end,
      isRaidGroup = function()
        return driver.inRaid
      end,
      runFullRefresh = function()
        driver.refreshCalls = driver.refreshCalls + 1
        if opts.refreshResult then
          return opts.refreshResult(driver.refreshCalls)
        end
        return true
      end,
      enableRioDeltaDisplay = function()
        driver.enableCalls = driver.enableCalls + 1
      end,
    })

    function driver.FireDue()
      local index = 1
      while driver.scheduled[index] do
        driver.scheduled[index].callback()
        index = index + 1
        Assert.True(index < 30, "post-run refresh chain must terminate")
      end
      driver.scheduled = {}
    end

    return driver
  end

  test("Event handlers run one post-run refresh for completed and reset of the same key", function()
    local driver = BuildChainDriver()
    driver.controller:Dispatch("CHALLENGE_MODE_START")
    driver.controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.controller:Dispatch("CHALLENGE_MODE_RESET")
    driver.FireDue()

    Assert.Equal(driver.refreshCalls, 1, "both key-end events must share one post-run refresh")
    Assert.Equal(driver.enableCalls, 1, "the shared refresh must enable the RIO delta once")
  end)

  test("Event handlers skip the post-run refresh on a reset after the refresh already succeeded", function()
    local driver = BuildChainDriver()
    driver.controller:Dispatch("CHALLENGE_MODE_START")
    driver.controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.FireDue()
    driver.controller:Dispatch("CHALLENGE_MODE_RESET")
    driver.FireDue()

    Assert.Equal(driver.refreshCalls, 1, "a late reset of the same key must not refresh a second time")
  end)

  test("Event handlers run the post-run refresh of a completed key whose start was never seen", function()
    local driver = BuildChainDriver()
    driver.controller:Dispatch("CHALLENGE_MODE_START")
    driver.controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.FireDue()
    driver.controller:Dispatch("CHALLENGE_MODE_RESET")
    driver.FireDue()
    Assert.Equal(driver.refreshCalls, 1, "setup: the first key refreshes once")

    -- Joined as a replacement: the second key ends without any START here.
    driver.controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.FireDue()
    driver.controller:Dispatch("CHALLENGE_MODE_RESET")
    driver.FireDue()

    Assert.Equal(driver.refreshCalls, 2, "the second key must get its own refresh, once")
    Assert.Equal(driver.enableCalls, 2, "the second key must enable its RIO delta")
  end)

  test("Event handlers run the post-run refresh of an abandoned key whose start was never seen", function()
    local driver = BuildChainDriver()
    driver.controller:Dispatch("CHALLENGE_MODE_START")
    driver.controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.controller:Dispatch("CHALLENGE_MODE_RESET")
    driver.FireDue()

    driver.controller:Dispatch("CHALLENGE_MODE_RESET")
    driver.FireDue()

    Assert.Equal(driver.refreshCalls, 2, "a second reset ends another key and must refresh")
  end)

  test("Event handlers run the post-run refresh for a reset alone", function()
    local driver = BuildChainDriver()
    driver.controller:Dispatch("CHALLENGE_MODE_START")
    driver.controller:Dispatch("CHALLENGE_MODE_RESET")
    driver.FireDue()

    Assert.Equal(driver.refreshCalls, 1, "an abandoned key must still get its post-run refresh")
    Assert.Equal(driver.enableCalls, 1, "the refresh must enable the RIO delta")
  end)

  test("Event handlers discard a scheduled post-run refresh when the next key starts", function()
    local driver = BuildChainDriver()
    driver.controller:Dispatch("CHALLENGE_MODE_START")
    driver.controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.controller:Dispatch("CHALLENGE_MODE_START")
    driver.FireDue()

    Assert.Equal(driver.refreshCalls, 0, "work scheduled for the old key must not run into the new key")
    Assert.Equal(driver.enableCalls, 0, "stale work must not enable the RIO delta")
  end)

  test("Event handlers discard a pending post-run retry when the next key starts", function()
    local driver = BuildChainDriver({
      refreshResult = function()
        return false
      end,
    })
    driver.controller:Dispatch("CHALLENGE_MODE_START")
    driver.controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.scheduled[1].callback()
    Assert.Equal(driver.refreshCalls, 1, "the first attempt must run")
    Assert.Equal(#driver.scheduled, 2, "the failed attempt must schedule a retry")

    driver.controller:Dispatch("CHALLENGE_MODE_START")
    driver.scheduled[2].callback()

    Assert.Equal(driver.refreshCalls, 1, "the retry of the old key must not run into the new key")
  end)

  test("Event handlers share one post-run chain across retries and a following reset", function()
    local driver = BuildChainDriver({
      refreshResult = function(attempt)
        return attempt >= 2
      end,
    })
    driver.controller:Dispatch("CHALLENGE_MODE_START")
    driver.controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.scheduled[1].callback()
    Assert.Equal(driver.enableCalls, 0, "a failed attempt must not enable the RIO delta")
    driver.controller:Dispatch("CHALLENGE_MODE_RESET")
    Assert.Equal(#driver.scheduled, 2, "the reset must join the retry instead of scheduling more work")
    driver.scheduled[2].callback()

    Assert.Equal(driver.refreshCalls, 2, "the chain must stop after its successful retry")
    Assert.Equal(driver.enableCalls, 1, "the delta must enable after the successful retry only")
  end)

  test("Event handlers let a reset try again after the post-run chain ran out of retries", function()
    local driver = BuildChainDriver({
      refreshResult = function(attempt)
        return attempt > 6
      end,
    })
    driver.controller:Dispatch("CHALLENGE_MODE_START")
    driver.controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.FireDue()
    Assert.Equal(driver.refreshCalls, 6, "the first attempt and all retries must have failed")
    Assert.Equal(driver.enableCalls, 0, "an exhausted chain must not enable the RIO delta")

    driver.controller:Dispatch("CHALLENGE_MODE_RESET")
    driver.FireDue()

    Assert.Equal(driver.refreshCalls, 7, "rule 4 still waits for a success, so the reset may try once more")
    Assert.Equal(driver.enableCalls, 1, "the successful refresh must enable the RIO delta")
  end)

  test("Event handlers keep a raid-deferred post-run refresh in the chain of its key", function()
    local driver = BuildChainDriver()
    driver.controller:Dispatch("CHALLENGE_MODE_START")
    driver.controller:Dispatch("CHALLENGE_MODE_COMPLETED")
    driver.inRaid = true
    driver.FireDue()
    Assert.Equal(driver.refreshCalls, 0, "the refresh must wait while the group is a raid")
    driver.inRaid = false
    driver.controller:Dispatch("CHALLENGE_MODE_RESET")
    driver.FireDue()
    driver.controller:Dispatch("GROUP_ROSTER_UPDATE")
    driver.FireDue()

    Assert.Equal(driver.refreshCalls, 1, "deferred refresh and reset must share one refresh after the raid")
    Assert.Equal(driver.enableCalls, 1, "the deferred refresh must enable the RIO delta")
  end)
end

local function RegisterRunEndRefreshCostTests(test, Assert, LoadAddonModules, Fixtures)
  test("Event handlers refresh the roster once when the key end auto-opens the window", function()
    local function CountRosterRefreshes(showResult)
      local uiUpdates = 0
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
        timerAfter = function() end,
        shouldAutoOpenMainFrameOnKeyEnd = function()
          return true
        end,
        setMainFrameVisible = function()
          return showResult
        end,
        updateUI = function()
          uiUpdates = uiUpdates + 1
        end,
      })
      controller:Dispatch("CHALLENGE_MODE_COMPLETED")
      return uiUpdates
    end
    local withoutShow = CountRosterRefreshes(false)
    local withShow = CountRosterRefreshes(true)
    Assert.Equal(
      withShow,
      withoutShow - 1,
      "an auto-open that showed the window already refreshed the roster; the second refresh is skipped"
    )
  end)

  test("Event handlers do not repeat the post-combat render after a deferred show", function()
    local function CountRegenRenders(showResult)
      local uiUpdates = 0
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
        getPendingMainFrameVisible = function()
          return true
        end,
        setMainFrameVisible = function()
          return showResult
        end,
        isMainFrameShown = function()
          return true
        end,
        updateUI = function()
          uiUpdates = uiUpdates + 1
        end,
        updateMPlusTeleportButton = function() end,
        tryRestoreCenterNoticeTeleportButton = function() end,
      })
      controller:Dispatch("PLAYER_REGEN_ENABLED")
      return uiUpdates
    end
    Assert.Equal(CountRegenRenders(false), 1, "without a deferred show the post-combat render must run")
    Assert.Equal(CountRegenRenders(true), 0, "a deferred show already rendered after combat")
  end)
end

local function RegisterHiddenFrameRegenTests(test, Assert, LoadAddonModules, Fixtures)
  test("Event handlers keep non-UI regen recovery while frame is hidden", function()
    local applyHotkeyCalls = 0
    local pendingHeightApplied = nil
    local teleportRefreshCalls = 0
    local restoreButtonCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      getPendingBindingApply = function()
        return true
      end,
      applyHotkeyBindings = function()
        applyHotkeyCalls = applyHotkeyCalls + 1
      end,
      getPendingMainFrameHeight = function()
        return 420
      end,
      setMainFrameHeightSafe = function(height)
        pendingHeightApplied = height
      end,
      getPendingMainFrameWidth = function()
        return nil
      end,
      setMainFrameWidthSafe = function(_width) end,
      isMainFrameShown = function()
        return false
      end,
      updateMPlusTeleportButton = function()
        teleportRefreshCalls = teleportRefreshCalls + 1
      end,
      tryRestoreCenterNoticeTeleportButton = function()
        restoreButtonCalls = restoreButtonCalls + 1
      end,
    })

    controller:Dispatch("PLAYER_REGEN_ENABLED")

    Assert.Equal(applyHotkeyCalls, 1, "regen must still apply pending bindings while frame is hidden")
    Assert.Equal(pendingHeightApplied, 420, "regen must still apply pending frame height while frame is hidden")
    Assert.Equal(teleportRefreshCalls, 0, "hidden regen must skip teleport UI refresh")
    Assert.Equal(restoreButtonCalls, 0, "hidden regen must skip teleport button restore")
  end)

  test("Event handlers apply pending visibility on regen when combat-deferred show is queued", function()
    local visibilityCalls = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      getPendingMainFrameVisible = function()
        return true
      end,
      setMainFrameVisible = function(visible)
        table.insert(visibilityCalls, visible)
      end,
      isMainFrameShown = function()
        return true
      end,
      updateMPlusTeleportButton = function() end,
      tryRestoreCenterNoticeTeleportButton = function() end,
    })

    controller:Dispatch("PLAYER_REGEN_ENABLED")

    Assert.Equal(#visibilityCalls, 1, "regen must apply pending visibility exactly once")
    Assert.True(visibilityCalls[1], "regen must apply pending show when combat-deferred show was queued")
  end)

  test("Event handlers apply pending visibility on regen when combat-deferred hide is queued", function()
    local visibilityCalls = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      getPendingMainFrameVisible = function()
        return false
      end,
      setMainFrameVisible = function(visible)
        table.insert(visibilityCalls, visible)
      end,
      isMainFrameShown = function()
        return false
      end,
      updateMPlusTeleportButton = function() end,
      tryRestoreCenterNoticeTeleportButton = function() end,
    })

    controller:Dispatch("PLAYER_REGEN_ENABLED")

    Assert.Equal(#visibilityCalls, 1, "regen must apply pending visibility exactly once")
    Assert.False(visibilityCalls[1], "regen must apply pending hide when combat-deferred hide was queued")
  end)

  test("Event handlers skip pending visibility on regen when no combat-deferred toggle exists", function()
    local visibilityCalls = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      getPendingMainFrameVisible = function()
        return nil
      end,
      setMainFrameVisible = function(visible)
        table.insert(visibilityCalls, visible)
      end,
      isMainFrameShown = function()
        return true
      end,
      updateMPlusTeleportButton = function() end,
      tryRestoreCenterNoticeTeleportButton = function() end,
    })

    controller:Dispatch("PLAYER_REGEN_ENABLED")

    Assert.Equal(#visibilityCalls, 0, "regen must not call setMainFrameVisible when no pending toggle exists")
  end)

  test("Event handlers run regen teleport refresh when frame is visible", function()
    local teleportRefreshCalls = 0
    local restoreButtonCalls = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      isMainFrameShown = function()
        return true
      end,
      updateMPlusTeleportButton = function()
        teleportRefreshCalls = teleportRefreshCalls + 1
      end,
      tryRestoreCenterNoticeTeleportButton = function()
        restoreButtonCalls = restoreButtonCalls + 1
      end,
    })

    controller:Dispatch("PLAYER_REGEN_ENABLED")

    Assert.Equal(teleportRefreshCalls, 1, "visible regen must refresh teleport UI")
    Assert.Equal(restoreButtonCalls, 1, "visible regen must restore center notice teleport button")
  end)

  test("Event handlers rerender visible UI on regen after combat-safe layout changes", function()
    local counters = {}

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      isMainFrameShown = function()
        return true
      end,
      updateMPlusTeleportButton = function() end,
      tryRestoreCenterNoticeTeleportButton = function() end,
    })

    controller:Dispatch("PLAYER_REGEN_ENABLED")

    Assert.Equal(counters.uiUpdates, 1, "visible regen must rerender the main UI once")
  end)

  test("Event handlers suppress background processing while raid mode is active", function()
    local counters = {
      groupUpdates = 0,
      uiUpdates = 0,
      backgroundSnapshots = 0,
      teleportUpdates = 0,
      chatProcessed = 0,
    }

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      isRaidGroup = function()
        return true
      end,
      handleGroupRosterUpdate = function()
        counters.groupUpdates = counters.groupUpdates + 1
      end,
      updateUI = function()
        counters.uiUpdates = counters.uiUpdates + 1
      end,
      updateMPlusTeleportButton = function()
        counters.teleportUpdates = counters.teleportUpdates + 1
      end,
      sendOwnBackgroundSnapshot = function()
        counters.backgroundSnapshots = counters.backgroundSnapshots + 1
      end,
      processAddonMessage = function()
        counters.chatProcessed = counters.chatProcessed + 1
        return { shouldAck = true }
      end,
      getPendingMainFrameVisible = function()
        return nil
      end,
      getPendingMainFrameHeight = function()
        return nil
      end,
      getPendingMainFrameWidth = function()
        return nil
      end,
      isMainFrameShown = function()
        return false
      end,
      tryRestoreCenterNoticeTeleportButton = function() end,
      updateCdTracker = function()
        counters.backgroundSnapshots = counters.backgroundSnapshots + 1
      end,
      updateStatusLine = function()
        counters.backgroundSnapshots = counters.backgroundSnapshots + 1
      end,
      maybeShowNonMythicDungeonEntryNotice = function()
        counters.backgroundSnapshots = counters.backgroundSnapshots + 1
      end,
      maybeShowPortalNavigatorNotice = function()
        counters.backgroundSnapshots = counters.backgroundSnapshots + 1
      end,
      checkIfEnteredTargetDungeon = function()
        counters.backgroundSnapshots = counters.backgroundSnapshots + 1
      end,
    })

    controller:Dispatch("PLAYER_LOGIN")
    controller:Dispatch("PLAYER_ENTERING_WORLD")
    controller:Dispatch("PLAYER_SPECIALIZATION_CHANGED", "player")
    controller:Dispatch("PLAYER_EQUIPMENT_CHANGED")
    controller:Dispatch("SPELL_UPDATE_COOLDOWN")
    controller:Dispatch("CHAT_MSG_ADDON", "ISI_SYNC", "REQSYNC", "PARTY", "Alpha")
    controller:Dispatch("GROUP_ROSTER_UPDATE")

    Assert.Equal(counters.groupUpdates, 1, "raid mode must still route roster updates so raid exit can be detected")
    Assert.Equal(counters.uiUpdates, 0, "raid mode must not rerender the UI")
    Assert.Equal(counters.teleportUpdates, 0, "raid mode must not refresh teleport buttons")
    Assert.Equal(counters.chatProcessed, 0, "raid mode must not process addon sync traffic")
    Assert.Equal(counters.backgroundSnapshots, 0, "raid mode must not run background refresh hooks")
  end)

  test("Event handlers suppress addon sync messages while raid mode is active", function()
    local counters = { uiUpdates = 0, refreshResponses = 0 }
    local syncCalls = 0

    local addon = LoadAddonModules({ "isiLive_sync.lua", "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      isRaidGroup = function()
        return true
      end,
      processAddonMessage = function()
        syncCalls = syncCalls + 1
        error("raid mode must stop addon sync before parsing")
      end,
      sendAck = function()
        error("raid mode must suppress sync replies")
      end,
      sendIsiLiveHello = function()
        error("raid mode must suppress sync replies")
      end,
      sendRefreshResponse = function()
        error("raid mode must suppress sync replies")
      end,
      sendOwnTargetSnapshot = function()
        error("raid mode must suppress sync replies")
      end,
      sendOwnKickState = function()
        error("raid mode must suppress sync replies")
      end,
      sendLibKeystonePartyData = function()
        error("raid mode must suppress libkeystone replies")
      end,
      sendOwnKeystoneToChat = function()
        error("raid mode must suppress share-key replies")
      end,
      updateStatusLine = function()
        error("raid mode must suppress statusline refresh")
      end,
      updateMPlusTeleportButton = function()
        error("raid mode must suppress teleport refresh")
      end,
      updateUI = function()
        error("raid mode must suppress UI refresh")
      end,
    })

    controller:Dispatch("CHAT_MSG_ADDON", "ISI_SYNC", "HELLO:0.9.36:2:123:refresh", "PARTY", "Alpha-RealmA")

    Assert.Equal(syncCalls, 0, "raid mode must stop addon sync before parsing")
    Assert.Equal(counters.uiUpdates, 0, "raid mode must not force UI redraws")
    Assert.Equal(counters.refreshResponses, 0, "raid mode must not trigger refresh responses")
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules
  local Fixtures = ctx.fixtures

  RegisterChallengeStartAndDelayTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterChallengeRetryTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterAbandonedRunIdentityTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterStaleCompletionTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterPostRunRefreshChainTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterHiddenFrameRegenTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterRunEndRefreshCostTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterKeyEndBannerTests(test, Assert, LoadAddonModules, Fixtures)
end
