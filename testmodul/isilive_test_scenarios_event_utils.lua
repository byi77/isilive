---@diagnostic disable: undefined-global

local function RegisterNegativeStatusTests(test, Assert, WithGlobals, LoadAddonModules)
  test("EventUtils detects negative status strings", function()
    local addon = LoadAddonModules({ "isiLive_event_utils.lua" })

    Assert.True(addon.EventUtils.IsNegativeApplicationStatusValue("declined"), "declined must be negative")
    Assert.True(addon.EventUtils.IsNegativeApplicationStatusValue("cancelled"), "cancelled must be negative")
    Assert.True(addon.EventUtils.IsNegativeApplicationStatusValue("failed"), "failed must be negative")
    Assert.True(addon.EventUtils.IsNegativeApplicationStatusValue("timeout"), "timeout must be negative")
    Assert.True(
      addon.EventUtils.IsNegativeApplicationStatusValue("InviteDeclined"),
      "InviteDeclined must be negative (mixed case)"
    )
  end)

  test("EventUtils detects negative status enums", function()
    WithGlobals({
      Enum = {
        LFGListApplicationStatus = {
          InviteDeclined = 2,
          Cancelled = 5,
          Failed = 6,
          InviteAccepted = 3,
        },
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_utils.lua" })

      Assert.True(addon.EventUtils.IsNegativeApplicationStatusValue(2), "InviteDeclined enum must be negative")
      Assert.True(addon.EventUtils.IsNegativeApplicationStatusValue(5), "Cancelled enum must be negative")
      Assert.True(addon.EventUtils.IsNegativeApplicationStatusValue(6), "Failed enum must be negative")
    end)
  end)

  test("EventUtils ignores first numeric argument as non-status identifier", function()
    WithGlobals({
      Enum = {
        LFGListApplicationStatus = {
          InviteAccepted = 3,
          InviteDeclined = 2,
        },
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_utils.lua" })

      Assert.False(
        addon.EventUtils.IsNegativeApplicationStatusEvent(
          2,
          Enum.LFGListApplicationStatus.InviteAccepted,
          Enum.LFGListApplicationStatus.InviteAccepted
        ),
        "first numeric argument should be treated as identifier, not status"
      )
      Assert.True(
        addon.EventUtils.IsNegativeApplicationStatusEvent(
          9999,
          Enum.LFGListApplicationStatus.InviteDeclined,
          Enum.LFGListApplicationStatus.InviteAccepted
        ),
        "negative numeric status in later argument must still be detected"
      )
    end)
  end)

  test("EventUtils returns false for positive status events", function()
    WithGlobals({
      Enum = {
        LFGListApplicationStatus = {
          InviteAccepted = 3,
          Applied = 1,
        },
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_utils.lua" })

      Assert.False(addon.EventUtils.IsNegativeApplicationStatusValue("invited"), "invited must not be negative")
      Assert.False(addon.EventUtils.IsNegativeApplicationStatusValue("accepted"), "accepted must not be negative")
      Assert.False(addon.EventUtils.IsNegativeApplicationStatusValue(3), "InviteAccepted enum must not be negative")
      Assert.False(addon.EventUtils.IsNegativeApplicationStatusValue(1), "Applied enum must not be negative")
    end)
  end)

  test("EventUtils handles nil and empty arguments without crashing", function()
    local addon = LoadAddonModules({ "isiLive_event_utils.lua" })

    Assert.False(addon.EventUtils.IsNegativeApplicationStatusEvent(), "no arguments should return false")
    Assert.False(addon.EventUtils.IsNegativeApplicationStatusEvent(nil, nil), "nil arguments should return false")
    Assert.False(
      addon.EventUtils.IsNegativeApplicationStatusEvent(42, true, {}),
      "non-string/non-enum arguments should return false"
    )
    Assert.True(
      addon.EventUtils.IsNegativeApplicationStatusEvent(1, "declined", 3),
      "declined at any position should be detected"
    )
  end)
end

local function RegisterEventGateTests(test, Assert, LoadAddonModules)
  test("Events gate blocks non-essential events during combat", function()
    local dispatched = 0

    local addon = LoadAddonModules({ "isiLive_events.lua" })
    local gate = addon.Events.CreateGate({
      dispatch = function(_frame, _event, ...)
        local _ = ...
        dispatched = dispatched + 1
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
        return true
      end,
      allowInCombat = {
        PLAYER_REGEN_ENABLED = true,
      },
    })

    local frame = {
      IsShown = function()
        return true
      end,
    }
    gate(frame, "GROUP_ROSTER_UPDATE")

    Assert.Equal(dispatched, 0, "combat gate must suppress non-essential events")
  end)

  test("Events gate allows whitelisted events during combat", function()
    local dispatched = 0

    local addon = LoadAddonModules({ "isiLive_events.lua" })
    local gate = addon.Events.CreateGate({
      dispatch = function(_frame, _event, ...)
        local _ = ...
        dispatched = dispatched + 1
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
        return true
      end,
      allowInCombat = {
        PLAYER_REGEN_ENABLED = true,
      },
    })

    local frame = {
      IsShown = function()
        return true
      end,
    }
    gate(frame, "PLAYER_REGEN_ENABLED")

    Assert.Equal(dispatched, 1, "combat gate must allow explicitly whitelisted events")
  end)

  test("Events gate reports dispatch errors via callback without crashing", function()
    local reports = {}

    local addon = LoadAddonModules({ "isiLive_events.lua" })
    local gate = addon.Events.CreateGate({
      dispatch = function(_frame, _event, ...)
        local _ = ...
        error("simulated dispatch error")
      end,
      onDispatchError = function(_frame, event, err)
        table.insert(reports, {
          event = event,
          err = tostring(err),
        })
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
        return false
      end,
    })

    local frame = {
      IsShown = function()
        return true
      end,
    }

    local ok, callErr = pcall(function()
      gate(frame, "GROUP_ROSTER_UPDATE")
    end)

    Assert.True(ok, "dispatch errors must be caught by gate: " .. tostring(callErr))
    Assert.Equal(#reports, 1, "dispatch errors must be reported exactly once")
    Assert.Equal(reports[1].event, "GROUP_ROSTER_UPDATE", "error callback must receive event name")
    local errText = string.lower(reports[1].err)
    Assert.True(
      errText:find("simulated", 1, true) ~= nil or errText:find("dispatch", 1, true) ~= nil,
      "error payload must include root error context"
    )
  end)

  test("Events gate preserves nil-containing varargs for dispatch", function()
    ---@type { count: integer, values: table<number, any> }|nil
    local captured = nil

    local addon = LoadAddonModules({ "isiLive_events.lua" })
    local gate = addon.Events.CreateGate({
      dispatch = function(_frame, _event, ...)
        captured = {
          count = select("#", ...),
          values = { ... },
        }
      end,
      onDispatchError = function(_frame, _event, _err) end,
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
        return false
      end,
    })

    local frame = {
      IsShown = function()
        return true
      end,
    }

    gate(frame, "GROUP_ROSTER_UPDATE", "first", nil, "third")

    local capturedResult = captured
    Assert.NotNil(capturedResult, "dispatch must be called")
    if capturedResult ~= nil then
      Assert.Equal(capturedResult.count, 3, "dispatch must receive all vararg positions including nil holes")
      Assert.Equal(capturedResult.values[1], "first", "first argument must stay intact")
      Assert.Equal(capturedResult.values[2], nil, "second argument must remain nil")
      Assert.Equal(capturedResult.values[3], "third", "third argument after nil hole must be preserved")
    end
  end)

  test("Events gate preserves outer arguments across re-entrant protected dispatch", function()
    local calls = {}
    local gate

    local addon = LoadAddonModules({ "isiLive_events.lua" })
    gate = addon.Events.CreateGate({
      dispatch = function(frame, event, ...)
        calls[#calls + 1] = {
          event = event,
          count = select("#", ...),
          first = select(1, ...),
          second = select(2, ...),
        }
        if event == "OUTER" then
          gate(frame, "INNER", "inner")
          calls[#calls + 1] = {
            event = event .. "_AFTER",
            count = select("#", ...),
            first = select(1, ...),
            second = select(2, ...),
          }
        end
      end,
      onDispatchError = function(_frame, _event, _err) end,
    })

    local frame = {
      IsShown = function()
        return true
      end,
    }
    gate(frame, "OUTER", "first", nil)

    Assert.Equal(#calls, 3, "outer, inner, and resumed outer dispatch must all complete")
    Assert.Equal(calls[1].event, "OUTER")
    Assert.Equal(calls[2].event, "INNER")
    Assert.Equal(calls[3].event, "OUTER_AFTER")
    Assert.Equal(calls[3].count, 2, "outer nil-containing varargs must survive nested dispatch")
    Assert.Equal(calls[3].first, "first")
    Assert.Nil(calls[3].second)
  end)

  test("Events gate uses default isStopped/isPaused/isTestMode/isInCombat fallbacks when config omits them", function()
    local dispatched = 0

    local addon = LoadAddonModules({ "isiLive_events.lua" })
    local gate = addon.Events.CreateGate({
      dispatch = function(_frame, _event, ...)
        local _ = ...
        dispatched = dispatched + 1
      end,
    })

    local frame = {
      IsShown = function()
        return true
      end,
    }
    gate(frame, "GROUP_ROSTER_UPDATE")

    Assert.Equal(dispatched, 1, "default false-returning fallbacks must allow dispatch through")
  end)

  test("Events gate suppresses non-ADDON_LOADED events when isStopped returns true", function()
    local dispatched = 0

    local addon = LoadAddonModules({ "isiLive_events.lua" })
    local gate = addon.Events.CreateGate({
      dispatch = function(_frame, _event, ...)
        local _ = ...
        dispatched = dispatched + 1
      end,
      isStopped = function()
        return true
      end,
    })

    local frame = {
      IsShown = function()
        return true
      end,
    }
    gate(frame, "GROUP_ROSTER_UPDATE")
    gate(frame, "ADDON_LOADED")

    Assert.Equal(dispatched, 1, "isStopped must suppress every event except ADDON_LOADED")
  end)

  test("Events gate suppresses non-ADDON_LOADED events when isPaused returns true", function()
    local dispatched = 0

    local addon = LoadAddonModules({ "isiLive_events.lua" })
    local gate = addon.Events.CreateGate({
      dispatch = function(_frame, _event, ...)
        local _ = ...
        dispatched = dispatched + 1
      end,
      isStopped = function()
        return false
      end,
      isPaused = function()
        return true
      end,
    })

    local frame = {
      IsShown = function()
        return true
      end,
    }
    gate(frame, "GROUP_ROSTER_UPDATE")
    gate(frame, "ADDON_LOADED")

    Assert.Equal(dispatched, 1, "isPaused must suppress every event except ADDON_LOADED")
  end)

  test("Events gate xpcall handler falls back to raw error message when debug.traceback is unavailable", function()
    local reports = {}

    local addon = LoadAddonModules({ "isiLive_events.lua" })
    local gate = addon.Events.CreateGate({
      dispatch = function(_frame, _event, ...)
        local _ = ...
        error("simulated dispatch error without traceback")
      end,
      onDispatchError = function(_frame, event, err)
        table.insert(reports, { event = event, err = tostring(err) })
      end,
    })

    local frame = {
      IsShown = function()
        return true
      end,
    }

    -- Force the xpcall fallback path: replace debug.traceback with a non-function
    -- value so the handler hits the `return msg` branch. Mutating the field in
    -- place (instead of swapping out _G.debug) keeps debug.sethook intact, which
    -- is required for luacov's instrumentation to keep running during the test.
    local debugLib = rawget(_G, "debug")
    local originalTraceback = debugLib and debugLib.traceback or nil
    if type(debugLib) == "table" then
      debugLib.traceback = "not-a-function"
    end

    local ok = pcall(function()
      gate(frame, "GROUP_ROSTER_UPDATE")
    end)

    if type(debugLib) == "table" then
      debugLib.traceback = originalTraceback
    end

    Assert.True(ok, "gate must catch dispatch error even without debug.traceback")
    Assert.Equal(#reports, 1, "error must still be reported once")
    Assert.True(
      reports[1].err:lower():find("simulated", 1, true) ~= nil,
      "raw message must reach the error callback when traceback is missing"
    )
  end)
end

local function RegisterBootstrapHiddenGateTests(test, Assert, LoadAddonModules)
  local function CreateBootstrapGate(addon, dispatch, opts)
    opts = opts or {}
    return addon.Bootstrap.CreateGatedOnEvent({
      events = addon.Events,
      dispatch = dispatch,
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
        return false
      end,
      isInGroup = function()
        if opts.isInGroup ~= nil then
          return opts.isInGroup
        end
        return true
      end,
      isInPartyInstance = function()
        return opts.isInPartyInstance == true
      end,
      getNumGroupMembers = function()
        return opts.numMembers or 5
      end,
      getActiveChallengeMapID = function()
        return opts.activeChallengeMapID
      end,
    })
  end

  test("Bootstrap registers ready check lifecycle events on main frame", function()
    local addon = LoadAddonModules({ "isiLive_bootstrap.lua" })
    local frame = {
      _events = {},
      RegisterEvent = function(self, event)
        self._events[event] = true
      end,
      IsEventRegistered = function(self, event)
        return self._events[event] == true
      end,
    }

    addon.Bootstrap.RegisterDispatcherEvents(frame)

    Assert.True(frame:IsEventRegistered("READY_CHECK"), "READY_CHECK must be registered")
    Assert.True(frame:IsEventRegistered("READY_CHECK_CONFIRM"), "READY_CHECK_CONFIRM must be registered")
    Assert.True(frame:IsEventRegistered("READY_CHECK_FINISHED"), "READY_CHECK_FINISHED must be registered")
    Assert.True(frame:IsEventRegistered("ZONE_CHANGED"), "ZONE_CHANGED must be registered")
    Assert.True(frame:IsEventRegistered("ZONE_CHANGED_INDOORS"), "ZONE_CHANGED_INDOORS must be registered")
    Assert.True(frame:IsEventRegistered("ZONE_CHANGED_NEW_AREA"), "ZONE_CHANGED_NEW_AREA must be registered")
  end)

  test("Bootstrap gate allows ready check events during combat", function()
    local dispatched = {}

    local addon = LoadAddonModules({ "isiLive_events.lua", "isiLive_bootstrap.lua" })
    local gate = addon.Bootstrap.CreateGatedOnEvent({
      events = addon.Events,
      dispatch = function(_frame, event)
        table.insert(dispatched, event)
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
        return true
      end,
      isInGroup = function()
        return true
      end,
      isInPartyInstance = function()
        return false
      end,
      getNumGroupMembers = function()
        return 5
      end,
      getActiveChallengeMapID = function()
        return nil
      end,
    })

    local frame = {
      IsShown = function()
        return true
      end,
    }

    gate(frame, "READY_CHECK")
    gate(frame, "READY_CHECK_CONFIRM")
    gate(frame, "READY_CHECK_FINISHED")

    Assert.Equal(#dispatched, 3, "combat gate should allow ready check lifecycle events")
  end)

  test("Bootstrap gate allows addon sync during combat for in-key BRLUST announces", function()
    local dispatched = {}

    local addon = LoadAddonModules({ "isiLive_events.lua", "isiLive_bootstrap.lua" })
    local gate = addon.Bootstrap.CreateGatedOnEvent({
      events = addon.Events,
      dispatch = function(_frame, event, ...)
        table.insert(dispatched, { event = event, args = { ... } })
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
        return true
      end,
    })

    local frame = {
      IsShown = function()
        return true
      end,
    }

    gate(frame, "CHAT_MSG_ADDON", "ISILIVE", "BRLUST:BR:Druid-Realm:20484", "INSTANCE_CHAT", "Druid-Realm")

    Assert.Equal(#dispatched, 1, "combat gate must keep addon sync for BRLUST peer announces")
    Assert.Equal(dispatched[1].event, "CHAT_MSG_ADDON", "CHAT_MSG_ADDON must reach the dispatcher in combat")
    Assert.Equal(dispatched[1].args[2], "BRLUST:BR:Druid-Realm:20484", "BRLUST payload must be preserved")
    Assert.Equal(dispatched[1].args[3], "INSTANCE_CHAT", "in-key addon channel must be preserved")
  end)

  test("Bootstrap gate allows sync events while frame is hidden if configured", function()
    local dispatched = {}

    local addon = LoadAddonModules({ "isiLive_events.lua", "isiLive_bootstrap.lua" })
    -- Simulate RuntimeSetup configuration for Rule 28
    local gate = addon.Bootstrap.CreateGatedOnEvent({
      events = addon.Events,
      dispatch = function(_frame, event)
        table.insert(dispatched, event)
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
        return false
      end,
      isInGroup = function()
        return true
      end,
      isInPartyInstance = function()
        return false
      end,
      getNumGroupMembers = function()
        return 5
      end,
      getActiveChallengeMapID = function()
        return nil
      end,
      allowWhenHidden = {
        CHAT_MSG_ADDON = true,
        GROUP_ROSTER_UPDATE = true,
      },
    })

    local frame = {
      IsShown = function()
        return false
      end,
    }

    gate(frame, "LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "applied")
    gate(frame, "LFG_LIST_SEARCH_RESULT_UPDATED", 1001)
    gate(frame, "LFG_LIST_ACTIVE_ENTRY_UPDATE")
    gate(frame, "CHAT_MSG_ADDON", "ISI_SYNC", "HELLO", "PARTY", "Alpha-Realm")
    gate(frame, "GROUP_ROSTER_UPDATE")

    Assert.Equal(#dispatched, 2, "hidden gate must allow configured sync events")
    Assert.Equal(dispatched[1], "CHAT_MSG_ADDON", "CHAT_MSG_ADDON should pass")
    Assert.Equal(dispatched[2], "GROUP_ROSTER_UPDATE", "GROUP_ROSTER_UPDATE should pass")
  end)

  test("Bootstrap gate keeps hidden lifecycle triggers for key start/end and summon", function()
    local dispatched = {}

    local addon = LoadAddonModules({ "isiLive_events.lua", "isiLive_bootstrap.lua" })
    local gate = CreateBootstrapGate(addon, function(_frame, event, ...)
      local _ = ...
      table.insert(dispatched, event)
    end)

    local frame = {
      IsShown = function()
        return false
      end,
    }

    -- These events are marked hidden=true in EVENT_REGISTRY, so they must pass
    -- through the gate even when the addon UI is hidden. GROUP_ROSTER_UPDATE
    -- is intentionally NOT in this set: its hidden-allow is opt-in via the
    -- caller's allowWhenHidden override (production sets it via BuildGateOpts).
    gate(frame, "CHALLENGE_MODE_START")
    gate(frame, "CHALLENGE_MODE_COMPLETED")
    gate(frame, "CHALLENGE_MODE_RESET")
    gate(frame, "CONFIRM_SUMMON")
    gate(frame, "INCOMING_SUMMON_CHANGED", "player")

    Assert.Equal(#dispatched, 5, "hidden gate must keep required lifecycle triggers")
    Assert.Equal(dispatched[1], "CHALLENGE_MODE_START", "key-start trigger should pass hidden gate")
    Assert.Equal(dispatched[2], "CHALLENGE_MODE_COMPLETED", "key-end completed trigger should pass hidden gate")
    Assert.Equal(dispatched[3], "CHALLENGE_MODE_RESET", "key-end reset trigger should pass hidden gate")
    Assert.Equal(dispatched[4], "CONFIRM_SUMMON", "incoming summon trigger should pass hidden gate")
    Assert.Equal(dispatched[5], "INCOMING_SUMMON_CHANGED", "incoming summon status trigger should pass hidden gate")
  end)

  test("Bootstrap gate keeps hidden CD refresh triggers for ready sounds", function()
    local dispatched = {}

    local addon = LoadAddonModules({ "isiLive_events.lua", "isiLive_bootstrap.lua" })
    local gate = CreateBootstrapGate(addon, function(_frame, event, ...)
      local _ = ...
      table.insert(dispatched, event)
    end)

    local frame = {
      IsShown = function()
        return false
      end,
    }

    gate(frame, "UNIT_AURA", "player", { isFullUpdate = true })
    gate(frame, "SPELL_UPDATE_CHARGES")

    Assert.Equal(#dispatched, 2, "hidden gate must keep event-driven CD refresh triggers")
    Assert.Equal(dispatched[1], "UNIT_AURA", "UNIT_AURA should pass hidden gate for Bloodlust-ready")
    Assert.Equal(dispatched[2], "SPELL_UPDATE_CHARGES", "SPELL_UPDATE_CHARGES should pass hidden gate for BRes-ready")
  end)

  -- 0.9.238: GROUP_ROSTER_UPDATE is now combat-allowed. In sustained-combat
  -- instances (Delves are the canonical case) Blizzard fires the event only
  -- once when a member joins; if the gate drops it because of InCombat-
  -- Lockdown, the new member stays missing from the addon's roster until
  -- some unrelated later event happens to trigger a fresh GROUP_ROSTER_UPDATE
  -- — typically the post-boss combat-end follow-up several minutes later.
  -- HandleGroupRosterUpdate touches only Lua state plus the FontString-driven
  -- main frame, no secure / taint-sensitive code, so it is safe to run
  -- during combat.
  test("Bootstrap gate allows GROUP_ROSTER_UPDATE during combat (Delves member-join fix)", function()
    local dispatched = {}

    local addon = LoadAddonModules({ "isiLive_events.lua", "isiLive_bootstrap.lua" })
    local gate = addon.Bootstrap.CreateGatedOnEvent({
      events = addon.Events,
      dispatch = function(_frame, event, ...)
        local _ = ...
        table.insert(dispatched, event)
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
      -- Player is in combat — Delves keep this true for minutes at a time.
      isInCombat = function()
        return true
      end,
    })

    local frame = {
      IsShown = function()
        return true
      end,
    }

    gate(frame, "GROUP_ROSTER_UPDATE")
    Assert.Equal(#dispatched, 1, "GROUP_ROSTER_UPDATE must pass through during combat")
    Assert.Equal(dispatched[1], "GROUP_ROSTER_UPDATE", "the GROUP_ROSTER_UPDATE event must reach the dispatcher")
  end)

  test("Bootstrap gate allows portal navigator zone events while frame is hidden", function()
    local dispatched = {}

    local addon = LoadAddonModules({ "isiLive_events.lua", "isiLive_bootstrap.lua" })
    local gate = CreateBootstrapGate(addon, function(_frame, event, ...)
      local _ = ...
      table.insert(dispatched, event)
    end)

    local frame = {
      IsShown = function()
        return false
      end,
    }

    gate(frame, "ZONE_CHANGED")
    gate(frame, "ZONE_CHANGED_INDOORS")
    gate(frame, "ZONE_CHANGED_NEW_AREA")

    Assert.Equal(#dispatched, 3, "hidden gate must allow portal navigator zone events")
    Assert.Equal(dispatched[1], "ZONE_CHANGED", "ZONE_CHANGED should pass hidden gate")
    Assert.Equal(dispatched[2], "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_INDOORS should pass hidden gate")
    Assert.Equal(dispatched[3], "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_NEW_AREA should pass hidden gate")
  end)

  test("Config builders gate allows portal navigator zone events while frame is hidden", function()
    local dispatched = {}

    local addon = LoadAddonModules({ "isiLive_events.lua", "isiLive_bootstrap.lua", "isiLive_config_builders.lua" })
    local gate = addon.Bootstrap.CreateGatedOnEvent(addon.ConfigBuilders.BuildGateOpts({
      events = addon.Events,
      onEvent = function(_frame, event, ...)
        local _ = ...
        table.insert(dispatched, event)
      end,
      onDispatchError = nil,
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
        return false
      end,
      isInGroup = function()
        return true
      end,
      isInPartyInstance = function()
        return false
      end,
      getActiveChallengeMapID = function()
        return nil
      end,
    }))

    local frame = {
      IsShown = function()
        return false
      end,
    }

    gate(frame, "ZONE_CHANGED")
    gate(frame, "ZONE_CHANGED_INDOORS")
    gate(frame, "ZONE_CHANGED_NEW_AREA")

    Assert.Equal(#dispatched, 3, "config builders gate must allow portal navigator zone events")
    Assert.Equal(dispatched[1], "ZONE_CHANGED", "config builders gate should pass ZONE_CHANGED")
    Assert.Equal(dispatched[2], "ZONE_CHANGED_INDOORS", "config builders gate should pass ZONE_CHANGED_INDOORS")
    Assert.Equal(dispatched[3], "ZONE_CHANGED_NEW_AREA", "config builders gate should pass ZONE_CHANGED_NEW_AREA")
  end)

  test("Config builders gate allows sparse local change events while frame is hidden", function()
    local dispatched = {}

    local addon = LoadAddonModules({ "isiLive_events.lua", "isiLive_bootstrap.lua", "isiLive_config_builders.lua" })
    local gate = addon.Bootstrap.CreateGatedOnEvent(addon.ConfigBuilders.BuildGateOpts({
      events = addon.Events,
      onEvent = function(_frame, event, ...)
        local _ = ...
        table.insert(dispatched, event)
      end,
      onDispatchError = nil,
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
        return false
      end,
      isInGroup = function()
        return true
      end,
      isInPartyInstance = function()
        return false
      end,
      getActiveChallengeMapID = function()
        return nil
      end,
    }))

    local frame = {
      IsShown = function()
        return false
      end,
    }

    gate(frame, "BAG_UPDATE_DELAYED")
    gate(frame, "CHALLENGE_MODE_MAPS_UPDATE")
    gate(frame, "PLAYER_EQUIPMENT_CHANGED", 16, true)
    gate(frame, "PLAYER_SPECIALIZATION_CHANGED", "player")
    gate(frame, "PLAYER_ROLES_ASSIGNED")
    gate(frame, "ROLE_CHANGED_INFORM", "Alpha", "Alpha", "DAMAGER", "TANK")

    Assert.Equal(#dispatched, 6, "config builders gate must allow sparse hidden local change events")
    Assert.Equal(dispatched[1], "BAG_UPDATE_DELAYED", "config builders gate should pass BAG_UPDATE_DELAYED")
    Assert.Equal(
      dispatched[2],
      "CHALLENGE_MODE_MAPS_UPDATE",
      "config builders gate should pass CHALLENGE_MODE_MAPS_UPDATE"
    )
    Assert.Equal(dispatched[3], "PLAYER_EQUIPMENT_CHANGED", "config builders gate should pass PLAYER_EQUIPMENT_CHANGED")
    Assert.Equal(
      dispatched[4],
      "PLAYER_SPECIALIZATION_CHANGED",
      "config builders gate should pass PLAYER_SPECIALIZATION_CHANGED"
    )
    Assert.Equal(dispatched[5], "PLAYER_ROLES_ASSIGNED", "config builders gate should pass PLAYER_ROLES_ASSIGNED")
    Assert.Equal(dispatched[6], "ROLE_CHANGED_INFORM", "config builders gate should pass ROLE_CHANGED_INFORM")
  end)

  test("Config builders gate allows CD refresh events while frame is hidden", function()
    local dispatched = {}

    local addon = LoadAddonModules({ "isiLive_events.lua", "isiLive_bootstrap.lua", "isiLive_config_builders.lua" })
    local gate = addon.Bootstrap.CreateGatedOnEvent(addon.ConfigBuilders.BuildGateOpts({
      events = addon.Events,
      onEvent = function(_frame, event, ...)
        local _ = ...
        table.insert(dispatched, event)
      end,
      onDispatchError = nil,
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
        return false
      end,
      isInGroup = function()
        return true
      end,
      isInPartyInstance = function()
        return false
      end,
      getActiveChallengeMapID = function()
        return nil
      end,
    }))

    local frame = {
      IsShown = function()
        return false
      end,
    }

    gate(frame, "UNIT_AURA", "player", { isFullUpdate = true })
    gate(frame, "SPELL_UPDATE_CHARGES")

    Assert.Equal(#dispatched, 2, "config builders gate must allow hidden event-driven CD refreshes")
    Assert.Equal(dispatched[1], "UNIT_AURA", "config builders gate should pass UNIT_AURA")
    Assert.Equal(dispatched[2], "SPELL_UPDATE_CHARGES", "config builders gate should pass SPELL_UPDATE_CHARGES")
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterNegativeStatusTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterEventGateTests(test, Assert, LoadAddonModules)
  RegisterBootstrapHiddenGateTests(test, Assert, LoadAddonModules)
end
