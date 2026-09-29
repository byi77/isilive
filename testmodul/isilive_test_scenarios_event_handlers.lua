local function RegisterTargetHandlingTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  test("Event handlers keep target when active listing is inferred", function()
    local entryRef = { value = { activityID = 1001 } }
    local counters = { clears = 0, updates = 0 }

    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, entryRef, counters)

      controller:Dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined")
      Assert.Equal(counters.clears, 0, "target must stay for inferred active listing")

      entryRef.value = {}
      controller:Dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined")
      Assert.Equal(counters.clears, 0, "target must stay while grouped even when listing info is empty")

      entryRef.value = {}
      local pendingQueueJoinInfo = {
        groupName = "Race Group",
        priority = 2,
        capturedAt = 100,
      }
      local pendingClears = 0
      controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, entryRef, counters, {
        isInGroup = function()
          return false
        end,
        getTime = function()
          return 105
        end,
        getPendingQueueJoinInfo = function()
          return pendingQueueJoinInfo
        end,
        setPendingQueueJoinInfo = function(value)
          counters.pendingSets = counters.pendingSets + 1
          pendingQueueJoinInfo = value
          if value == nil then
            pendingClears = pendingClears + 1
          end
        end,
      })
      controller:Dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined")
      Assert.Equal(counters.clears, 1, "target must clear outside group when listing info is empty")
      Assert.NotNil(
        pendingQueueJoinInfo,
        "recent pending queue invite context must survive negative status race before group join"
      )
      Assert.Equal(pendingClears, 0, "recent pending queue invite context must not be cleared on negative status")

      entryRef.value = { active = false }
      pendingQueueJoinInfo = {
        groupName = "Stale Group",
        priority = 2,
        capturedAt = 70,
      }
      controller:Dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined")
      Assert.Equal(counters.clears, 2, "target must clear outside group for explicit inactive listing")
      Assert.Nil(pendingQueueJoinInfo, "stale pending queue invite context should clear on negative status update")
      Assert.Equal(pendingClears, 1, "stale pending queue invite context should be cleared exactly once")
    end)
  end)

  test("Event handlers keep target on negative updates when group fills to five", function()
    local counters = { clears = 0, updates = 0 }

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = {} }, counters, {
      isInGroup = function()
        return true
      end,
    })

    controller:Dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined")

    Assert.Equal(counters.clears, 0, "negative updates after join must not clear latest target while grouped")
    Assert.Equal(counters.updates, 1, "teleport button should still refresh on negative update")
  end)

  test("Event handlers forward positive application events to queue capture", function()
    local counters = { clears = 0, updates = 0, captures = 0 }

    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
      local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
        isNegativeApplicationStatusEvent = function()
          return false
        end,
      })

      controller:Dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 7, "invited")
    end)

    Assert.Equal(counters.captures, 1, "positive application events must call queue capture")
    Assert.Equal(counters.clears, 0, "positive application events must not clear latest queue target")
  end)
end

local function RegisterTargetActiveEntryTests(test, Assert, LoadAddonModules, Fixtures)
  test("Event handlers active-entry update clears joined key and refreshes UI", function()
    local counters = { updates = 0, uiUpdates = 0, pendingSets = 0 }
    local activeJoinedKey = 2441

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(
      addon.EventHandlers,
      { value = { activityID = 1001 } },
      counters,
      {
        getActiveJoinedKeyMapID = function()
          return activeJoinedKey
        end,
        setActiveJoinedKeyMapID = function(value)
          activeJoinedKey = value
        end,
      }
    )

    controller:Dispatch("LFG_LIST_ACTIVE_ENTRY_UPDATE")

    Assert.Nil(activeJoinedKey, "active joined key map must be cleared when listing becomes active")
    Assert.Equal(counters.pendingSets, 1, "pending queue info must be cleared on active listing event")
    Assert.Equal(counters.updates, 1, "teleport button must refresh on active listing event")
    Assert.Equal(counters.uiUpdates, 1, "UI must refresh when active joined key was cleared")
  end)
end

local function RegisterGroupAndSyncTests(test, Assert, LoadAddonModules, Fixtures)
  test("Event handlers exit test mode on GROUP_ROSTER_UPDATE while grouped", function()
    local counters = { exits = 0, rosterUpdates = 0 }

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      isTestMode = function()
        return true
      end,
    })

    controller:Dispatch("GROUP_ROSTER_UPDATE")

    Assert.Equal(counters.exits, 1, "GROUP_ROSTER_UPDATE should exit test mode when grouped")
    Assert.Equal(counters.rosterUpdates, 0, "GROUP_ROSTER_UPDATE should short-circuit after test-mode exit")
  end)

  test("Event handlers call roster update when no test mode is active", function()
    local counters = { exits = 0, rosterUpdates = 0 }

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters)

    controller:Dispatch("GROUP_ROSTER_UPDATE")

    Assert.Equal(counters.exits, 0, "normal GROUP_ROSTER_UPDATE should not exit test mode")
    Assert.Equal(counters.rosterUpdates, 1, "normal GROUP_ROSTER_UPDATE must call roster handler")
  end)

  test("Event handlers process addon sync messages and refresh changed roster", function()
    local counters = { acks = 0, uiUpdates = 0, updates = 0 }
    local statusUpdates = 0
    local kickReplies = 0
    local roster = {
      { name = "Alpha", realm = "RealmA", hasIsiLive = false },
      { name = "Beta", realm = "RealmB", hasIsiLive = true },
    }

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      processAddonMessage = function(_prefix, _message, _sender)
        return { shouldAck = true, sender = "Alpha-RealmA" }
      end,
      forEachRosterInfo = function(visitor)
        for _, info in ipairs(roster) do
          visitor(info)
        end
      end,
      isSyncUserKnown = function(name, _realm)
        return name == "Alpha"
      end,
      applyKnownKeyToRosterEntry = function(info)
        return info.name == "Beta"
      end,
      updateStatusLine = function()
        statusUpdates = statusUpdates + 1
      end,
      sendOwnKickState = function()
        kickReplies = kickReplies + 1
      end,
    })

    controller:Dispatch("CHAT_MSG_ADDON", "ISI_SYNC", "hello", "PARTY", "Alpha-RealmA")

    Assert.Equal(counters.acks, 1, "sync payload requiring ack must send ack once")
    Assert.Equal(counters.uiUpdates, 1, "roster changes from sync must refresh UI")
    Assert.Equal(counters.updates, 1, "sync-driven target changes must refresh teleport highlight state")
    Assert.Equal(statusUpdates, 1, "sync-driven target changes must refresh statusline state")
    Assert.Equal(kickReplies, 1, "HELLO ack handling must send one kick-state reply")
    Assert.True(roster[1].hasIsiLive, "known sync user should be marked as isiLive-enabled")
  end)

  test("Event handlers refresh target-dependent UI when addon sync updates exact target only", function()
    local counters = { uiUpdates = 0, updates = 0 }
    local statusUpdates = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
      processAddonMessage = function(_prefix, _message, _sender)
        return { targetUpdated = true }
      end,
      forEachRosterInfo = function(_visitor) end,
      updateStatusLine = function()
        statusUpdates = statusUpdates + 1
      end,
    })

    controller:Dispatch("CHAT_MSG_ADDON", "ISI_SYNC", "TARGET:2441:14", "PARTY", "Alpha-RealmA")

    Assert.Equal(
      counters.uiUpdates,
      1,
      "exact target sync must trigger one UI refresh even without roster field changes"
    )
    Assert.Equal(counters.updates, 1, "exact target sync must refresh teleport highlight state")
    Assert.Equal(statusUpdates, 1, "exact target sync must refresh statusline state")
  end)
end

local function RegisterChallengeRaidResumeTests(test, Assert, LoadAddonModules, Fixtures)
  test("Event handlers defer post-run refresh while raid mode is active and resume after raid exit", function()
    local delayedCallback = nil
    local raidActive = false
    local refreshCalls = 0
    local enableCalls = 0
    local rosterUpdates = 0

    local addon = LoadAddonModules({ "isiLive_event_handlers.lua" })
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      timerAfter = function(seconds, callback)
        if seconds == 5 then
          delayedCallback = callback
        end
      end,
      isRaidGroup = function()
        return raidActive
      end,
      handleGroupRosterUpdate = function()
        rosterUpdates = rosterUpdates + 1
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

    Assert.NotNil(delayedCallback, "challenge completion must still schedule a delayed post-run refresh")
    if type(delayedCallback) ~= "function" then
      return
    end

    raidActive = true
    delayedCallback()

    Assert.Equal(refreshCalls, 0, "delayed post-run refresh must not run while raid mode is active")
    Assert.Equal(enableCalls, 0, "RIO delta must stay disabled while the delayed refresh is deferred in raid")

    controller:Dispatch("GROUP_ROSTER_UPDATE")

    Assert.Equal(rosterUpdates, 1, "raid mode must still route roster updates while refresh is deferred")
    Assert.Equal(refreshCalls, 0, "raid roster updates must not resume the deferred post-run refresh yet")
    Assert.Equal(enableCalls, 0, "raid roster updates must not enable RIO delta yet")

    raidActive = false
    controller:Dispatch("GROUP_ROSTER_UPDATE")

    Assert.Equal(rosterUpdates, 2, "raid exit detection must still flow through GROUP_ROSTER_UPDATE")
    Assert.Equal(refreshCalls, 1, "first roster update after raid exit must resume the deferred post-run refresh")
    Assert.Equal(enableCalls, 1, "RIO delta must enable after the resumed post-run refresh succeeds")
  end)
end

-- Group-invite voice alert, end to end: real gate options, real bootstrap
-- gate, real controller dispatch and real SoundUtils playback. Only the
-- Blizzard APIs (invite dialogs, C_LFGList, timers, PlaySoundFile) are mocked.
local function BuildGroupInviteEnv(overrides)
  overrides = overrides or {}
  local env = {
    plays = {},
    ticker = nil,
    tickerInterval = nil,
    tickerCancels = 0,
    now = 0,
    shown = overrides.shown == true,
    inCombat = overrides.inCombat == true,
    raid = false,
    partyDialog = false,
    applications = {},
    db = {},
    locale = overrides.locale or "enUS",
  }
  env.globals = {
    IsiLiveDB = env.db,
    GetLocale = function()
      return env.locale
    end,
    GetTime = function()
      return env.now
    end,
    PlaySoundFile = function(path, channel)
      env.plays[#env.plays + 1] = { path = path, channel = channel }
      return true
    end,
    InCombatLockdown = function()
      return env.inCombat
    end,
    StaticPopup_Visible = function(which)
      if which == "PARTY_INVITE" and env.partyDialog then
        return "StaticPopup1"
      end
      return nil
    end,
    C_LFGList = {
      GetApplications = function()
        local ids = {}
        for id in pairs(env.applications) do
          ids[#ids + 1] = id
        end
        return ids
      end,
      GetApplicationInfo = function(id)
        local app = env.applications[id]
        if not app then
          return nil
        end
        return id, app.status, app.pendingStatus
      end,
    },
    C_Timer = {
      NewTicker = function(interval, callback)
        env.tickerInterval = interval
        env.ticker = callback
        return {
          Cancel = function()
            env.tickerCancels = env.tickerCancels + 1
            env.ticker = nil
          end,
        }
      end,
      After = function(_delay, fn)
        fn()
      end,
    },
  }
  return env
end

local function BuildGroupInviteGate(env, addon, Fixtures, counters)
  local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
    isRaidGroup = function()
      return env.raid
    end,
    isMainFrameShown = function()
      return env.shown
    end,
    isNegativeApplicationStatusEvent = function()
      return false
    end,
    playGroupInviteSound = addon.SoundUtils.PlayGroupInvite,
    isGroupInviteSoundEnabled = function()
      return env.db.soundGroupInviteEnabled ~= false
    end,
  })
  local gateOpts = addon.ConfigBuilders.BuildGateOpts({
    events = addon.Events,
    onEvent = function(_frame, event, ...)
      controller:Dispatch(event, ...)
    end,
    isStopped = function()
      return false
    end,
    isPaused = function()
      return false
    end,
    isTestMode = function()
      return false
    end,
    isInCombat = function()
      return env.inCombat
    end,
    isMainFrameShown = function()
      return env.shown
    end,
  })
  local gate = addon.Bootstrap.CreateGatedOnEvent(gateOpts)
  local frame = {
    IsShown = function()
      return true
    end,
  }
  return function(event, ...)
    gate(frame, event, ...)
  end
end

local function LoadGroupInviteModules(LoadAddonModules)
  return LoadAddonModules({
    "isiLive_events.lua",
    "isiLive_bootstrap.lua",
    "isiLive_config_builders.lua",
    "isiLive_sound_utils.lua",
    "isiLive_event_handlers.lua",
  })
end

local function RegisterGroupInviteSoundTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  test("Group invite plays the voice alert and repeats it every 5 seconds while the invite dialog is open", function()
    local env = BuildGroupInviteEnv({ shown = false, inCombat = true })
    WithGlobals(env.globals, function()
      local addon = LoadGroupInviteModules(LoadAddonModules)
      local dispatch = BuildGroupInviteGate(env, addon, Fixtures, {})

      dispatch("PARTY_INVITE_REQUEST", "Inviter", false, false, false, true, false, "Player-1-1", false)
      Assert.Equal(#env.plays, 1, "a direct invite must play immediately, even hidden and in combat")
      Assert.True(env.plays[1].path:find("GroupInvite.wav", 1, true) ~= nil, "enUS must play the English WAV")
      Assert.Equal(env.plays[1].channel, "Master", "the alert must use the configured sound channel")
      Assert.Equal(env.tickerInterval, 5, "the repeat loop must use a 5-second ticker")

      env.partyDialog = true
      env.now = 5
      env.ticker()
      Assert.Equal(#env.plays, 2, "the loop must repeat while the invite dialog is open")

      env.partyDialog = false
      env.now = 10
      env.ticker()
      Assert.Equal(#env.plays, 2, "an answered or expired invite must not play again")
      Assert.Equal(env.tickerCancels, 1, "the loop must stop once the invite dialog is gone")
    end)
  end)

  test("Group invite loop stops immediately when the invite is declined", function()
    local env = BuildGroupInviteEnv({ shown = true })
    WithGlobals(env.globals, function()
      local addon = LoadGroupInviteModules(LoadAddonModules)
      local dispatch = BuildGroupInviteGate(env, addon, Fixtures, {})

      dispatch("PARTY_INVITE_REQUEST", "Inviter", false, false, false, true, false, "Player-1-1", false)
      Assert.NotNil(env.ticker, "the invite must start the repeat loop")
      dispatch("PARTY_INVITE_CANCEL")
      Assert.Equal(env.tickerCancels, 1, "PARTY_INVITE_CANCEL must stop the loop without waiting for a tick")
      Assert.Equal(#env.plays, 1, "declining must not play another alert")
    end)
  end)

  test("Group invite from the group finder plays the voice alert while the main frame is hidden", function()
    local env = BuildGroupInviteEnv({ shown = false, inCombat = true, locale = "deDE" })
    local counters = { captures = 0 }
    WithGlobals(env.globals, function()
      local addon = LoadGroupInviteModules(LoadAddonModules)
      local dispatch = BuildGroupInviteGate(env, addon, Fixtures, counters)

      env.applications[7] = { status = "applied" }
      dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 7, "applied", "none", "Group")
      Assert.Equal(#env.plays, 0, "a plain application must stay silent")
      Assert.Equal(counters.captures, 0, "hidden non-invite statuses must stay blocked by the gate")

      env.applications[7] = { status = "invited" }
      dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 7, "invited", "applied", "Group")
      Assert.Equal(#env.plays, 1, "an LFG invite must play immediately, even hidden and in combat")
      Assert.True(env.plays[1].path:find("GroupInvite_deDE.wav", 1, true) ~= nil, "deDE must play the German WAV")
      Assert.Equal(counters.captures, 0, "the gate exception must not open the queue pipeline while hidden")

      env.now = 5
      env.ticker()
      Assert.Equal(#env.plays, 2, "the loop must repeat while the LFG invite is still open")

      env.applications[7] = { status = "invited", pendingStatus = "inviteaccepted" }
      env.now = 10
      env.ticker()
      Assert.Equal(#env.plays, 2, "an invite with a pending answer must not play again")
      Assert.Equal(env.tickerCancels, 1, "the loop must stop once the LFG invite is answered")
    end)
  end)

  test("Group invite keeps the visible LFG queue pipeline unchanged", function()
    local env = BuildGroupInviteEnv({ shown = true })
    local counters = { captures = 0 }
    WithGlobals(env.globals, function()
      local addon = LoadGroupInviteModules(LoadAddonModules)
      local dispatch = BuildGroupInviteGate(env, addon, Fixtures, counters)

      env.applications[7] = { status = "invited" }
      dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 7, "invited", "applied", "Group")
      Assert.Equal(#env.plays, 1, "a visible LFG invite must play the alert")
      Assert.Equal(counters.captures, 1, "a visible LFG invite must still reach queue capture")
    end)
  end)

  test("Group invite alert stays silent when disabled or in raid mode", function()
    local env = BuildGroupInviteEnv({ shown = true })
    WithGlobals(env.globals, function()
      local addon = LoadGroupInviteModules(LoadAddonModules)
      local dispatch = BuildGroupInviteGate(env, addon, Fixtures, {})

      env.db.soundGroupInviteEnabled = false
      dispatch("PARTY_INVITE_REQUEST", "Inviter", false, false, false, true, false, "Player-1-1", false)
      Assert.Equal(#env.plays, 0, "a disabled setting must keep the alert silent")
      Assert.Nil(env.ticker, "a disabled setting must not start the loop")

      env.db.soundGroupInviteEnabled = nil
      env.raid = true
      dispatch("PARTY_INVITE_REQUEST", "Inviter", false, false, false, true, false, "Player-1-1", false)
      Assert.Equal(#env.plays, 0, "the alert must follow the raid hard-off")

      env.raid = false
      dispatch("PARTY_INVITE_REQUEST", "Inviter", false, false, false, true, false, "Player-1-1", false)
      Assert.Equal(#env.plays, 1, "default-on setting must play the alert")
      env.partyDialog = true
      env.db.soundGroupInviteEnabled = false
      env.now = 5
      env.ticker()
      Assert.Equal(#env.plays, 1, "disabling the setting during a pending invite must stop the loop")
      Assert.Equal(env.tickerCancels, 1, "disabling the setting must cancel the ticker")
    end)
  end)

  test("Group invite loop fails closed on secret LFG application data", function()
    local env = BuildGroupInviteEnv({ shown = true })
    local secret = setmetatable({}, {
      __eq = function()
        error("secret value compared")
      end,
    })
    env.globals.issecretvalue = function(value)
      return rawequal(value, secret)
    end
    WithGlobals(env.globals, function()
      local addon = LoadGroupInviteModules(LoadAddonModules)
      local dispatch = BuildGroupInviteGate(env, addon, Fixtures, {})

      env.applications[7] = { status = "invited" }
      dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 7, secret, "applied", "Group")
      Assert.Equal(#env.plays, 0, "a secret status payload must never be compared")

      dispatch("LFG_LIST_APPLICATION_STATUS_UPDATED", 7, "invited", "applied", "Group")
      Assert.Equal(#env.plays, 1, "a plain invite must still play")
      env.applications[7] = { status = secret }
      env.now = 5
      env.ticker()
      Assert.Equal(#env.plays, 1, "a secret application status must end the loop instead of guessing")
      Assert.Equal(env.tickerCancels, 1, "a secret application status must cancel the ticker")
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules
  local Fixtures = ctx.fixtures

  RegisterTargetHandlingTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterTargetActiveEntryTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterGroupAndSyncTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterChallengeRaidResumeTests(test, Assert, LoadAddonModules, Fixtures)
  RegisterGroupInviteSoundTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
end
