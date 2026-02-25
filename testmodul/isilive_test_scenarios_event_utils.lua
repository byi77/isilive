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
      getNumGroupMembers = function()
        return opts.numMembers or 5
      end,
      getActiveChallengeMapID = function()
        return opts.activeChallengeMapID
      end,
    })
  end

  test("Bootstrap gate suppresses queue and sync events while frame is hidden", function()
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

    gate(frame, "LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "applied")
    gate(frame, "LFG_LIST_SEARCH_RESULT_UPDATED", 1001)
    gate(frame, "LFG_LIST_ACTIVE_ENTRY_UPDATE")
    gate(frame, "CHAT_MSG_ADDON", "ISI_SYNC", "HELLO", "PARTY", "Alpha-Realm")

    Assert.Equal(#dispatched, 0, "hidden gate must suppress queue/sync processing events")
  end)

  test("Bootstrap gate keeps hidden auto-open triggers for group join and key end", function()
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

    gate(frame, "GROUP_ROSTER_UPDATE")
    gate(frame, "CHALLENGE_MODE_COMPLETED")
    gate(frame, "CHALLENGE_MODE_RESET")

    Assert.Equal(#dispatched, 3, "hidden gate must keep required auto-open triggers")
    Assert.Equal(dispatched[1], "GROUP_ROSTER_UPDATE", "group-join trigger should pass hidden gate")
    Assert.Equal(dispatched[2], "CHALLENGE_MODE_COMPLETED", "key-end completed trigger should pass hidden gate")
    Assert.Equal(dispatched[3], "CHALLENGE_MODE_RESET", "key-end reset trigger should pass hidden gate")
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
