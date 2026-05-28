---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  -- Captures every ctx-side-effect the handlers can produce so individual
  -- branches can be observed without a full event-handlers fixture.
  local function NewCounters()
    return {
      exits = 0,
      pendingSets = 0,
      pendingValue = "unset",
      clears = 0,
      teleportUpdates = 0,
      captures = 0,
      uiUpdates = 0,
      activeJoinedKeyMapID = nil,
      activeJoinedKeyMapIDSets = 0,
      runtimeTraces = {},
      statusUpdates = 0,
      scheduled = {},
      inviteEvents = {},
      lfgEvents = {},
    }
  end

  local function NewCtx(overrides)
    local counters = NewCounters()
    local entryRef = { value = nil }
    local pendingRef = { value = nil }
    local base = {
      isInChallengeMode = function()
        return false
      end,
      isRaidGroup = function()
        return false
      end,
      isTestMode = function()
        return false
      end,
      isTestAllMode = function()
        return false
      end,
      exitTestMode = function()
        counters.exits = counters.exits + 1
      end,
      isNegativeApplicationStatusEvent = function()
        return false
      end,
      isInGroup = function()
        return false
      end,
      getNormalizedActiveEntryInfo = function()
        return entryRef.value
      end,
      getPendingQueueJoinInfo = function()
        return pendingRef.value
      end,
      setPendingQueueJoinInfo = function(value)
        counters.pendingSets = counters.pendingSets + 1
        counters.pendingValue = value
        pendingRef.value = value
      end,
      clearLatestQueueTarget = function()
        counters.clears = counters.clears + 1
      end,
      updateMPlusTeleportButton = function()
        counters.teleportUpdates = counters.teleportUpdates + 1
      end,
      captureQueueJoinCandidate = function()
        counters.captures = counters.captures + 1
      end,
      getActiveJoinedKeyMapID = function()
        return counters.activeJoinedKeyMapID
      end,
      setActiveJoinedKeyMapID = function(value)
        counters.activeJoinedKeyMapID = value
        counters.activeJoinedKeyMapIDSets = counters.activeJoinedKeyMapIDSets + 1
      end,
      updateUI = function()
        counters.uiUpdates = counters.uiUpdates + 1
      end,
      updateStatusLine = function()
        counters.statusUpdates = counters.statusUpdates + 1
      end,
      handleLFGDetectEvent = function(event, ...)
        counters.lfgEvents[#counters.lfgEvents + 1] = { event, ... }
      end,
      timerAfter = function(delay, fn)
        counters.scheduled[#counters.scheduled + 1] = { delay = delay, fn = fn }
      end,
      logRuntimeTrace = function(message)
        table.insert(counters.runtimeTraces, message)
      end,
      getTime = function()
        return 100
      end,
    }
    if overrides then
      for key, value in pairs(overrides) do
        base[key] = value
      end
    end
    return base, counters, entryRef, pendingRef
  end

  local function LoadHandlers(overrides)
    local addon = LoadAddonModules({ "isiLive_event_handlers_queue.lua" })
    local stub, counters, entryRef, pendingRef = NewCtx(overrides)
    return addon.EventHandlersQueueLifecycle.BuildHandlers(stub), counters, entryRef, pendingRef, stub
  end

  -- LFG_LIST_APPLICATION_STATUS_UPDATED: early-return paths --------------------

  test("APPLICATION_STATUS_UPDATED bails out in challenge mode", function()
    local handlers, counters = LoadHandlers({
      isInChallengeMode = function()
        return true
      end,
      isNegativeApplicationStatusEvent = function()
        return true
      end,
    })
    handlers.LFG_LIST_APPLICATION_STATUS_UPDATED(nil, 7, "declined")
    Assert.Equal(counters.captures, 0, "must not capture in challenge mode")
    Assert.Equal(counters.teleportUpdates, 0, "must not refresh teleport button in challenge mode")
    Assert.Equal(counters.pendingSets, 0, "must not touch pending in challenge mode")
  end)

  test("APPLICATION_STATUS_UPDATED bails out in raid group", function()
    local handlers, counters = LoadHandlers({
      isRaidGroup = function()
        return true
      end,
      isNegativeApplicationStatusEvent = function()
        return true
      end,
    })
    handlers.LFG_LIST_APPLICATION_STATUS_UPDATED(nil, 7, "declined")
    Assert.Equal(counters.teleportUpdates, 0, "must not refresh teleport button while raiding")
  end)

  test("APPLICATION_STATUS_UPDATED exits test mode before processing", function()
    local handlers, counters = LoadHandlers({
      isTestMode = function()
        return true
      end,
    })
    handlers.LFG_LIST_APPLICATION_STATUS_UPDATED(nil, 7, "applied")
    Assert.Equal(counters.exits, 1, "test mode must be exited")
    Assert.Equal(counters.captures, 1, "positive event still captures")
  end)

  test("APPLICATION_STATUS_UPDATED exits test-all mode before processing", function()
    local handlers, counters = LoadHandlers({
      isTestAllMode = function()
        return true
      end,
    })
    handlers.LFG_LIST_APPLICATION_STATUS_UPDATED(nil, 7, "applied")
    Assert.Equal(counters.exits, 1, "test-all mode must be exited")
  end)

  test("APPLICATION_STATUS_UPDATED does not forward removed invite-list handling", function()
    local handlers, counters = LoadHandlers()

    handlers.LFG_LIST_APPLICATION_STATUS_UPDATED(nil, 7, "invited")

    Assert.Equal(#counters.inviteEvents, 0, "removed invite-list feature must not receive status events")
    Assert.Equal(#counters.lfgEvents, 1, "regular LFGDetect handling must stay active")
    Assert.Equal(counters.captures, 1, "regular queue capture must stay active for positive statuses")
  end)

  test(
    "APPLICATION_STATUS_UPDATED inviteaccepted refreshes target status immediately and after roster settle",
    function()
      local lfgEvents = {}
      local handlers, counters = LoadHandlers({
        handleLFGDetectEvent = function(event, ...)
          lfgEvents[#lfgEvents + 1] = { event, ... }
        end,
      })

      handlers.LFG_LIST_APPLICATION_STATUS_UPDATED(nil, 7, "inviteaccepted")

      Assert.Equal(lfgEvents[1][1], "LFG_LIST_APPLICATION_STATUS_UPDATED", "inviteaccepted must reach LFGDetect first")
      Assert.Equal(counters.statusUpdates, 1, "inviteaccepted must refresh status immediately")
      Assert.Equal(#counters.scheduled, 1, "inviteaccepted must schedule one settle refresh")
      Assert.Equal(counters.scheduled[1].delay, 0.2, "settle refresh must use the short invite delay")

      counters.scheduled[1].fn()
      Assert.Equal(counters.statusUpdates, 2, "scheduled settle refresh must refresh status again")
    end
  )

  -- ShouldPreservePendingQueueJoinInfoOnNegativeStatus edge cases --------------

  test("negative status preserves pending invite when capturedAt is missing", function()
    local handlers, counters, _, pendingRef = LoadHandlers({
      isNegativeApplicationStatusEvent = function()
        return true
      end,
    })
    pendingRef.value = { groupName = "x" } -- no capturedAt
    handlers.LFG_LIST_APPLICATION_STATUS_UPDATED(nil, 7, "declined")
    Assert.Equal(counters.pendingSets, 0, "missing capturedAt must preserve pending (no nil-set)")
    Assert.NotNil(pendingRef.value, "pending must survive negative status without capturedAt")
  end)

  test("negative status preserves pending invite when getTime is not callable", function()
    local handlers, counters, _, pendingRef = LoadHandlers({
      isNegativeApplicationStatusEvent = function()
        return true
      end,
      getTime = "not-a-function",
    })
    pendingRef.value = { groupName = "x", capturedAt = 50 }
    handlers.LFG_LIST_APPLICATION_STATUS_UPDATED(nil, 7, "declined")
    Assert.Equal(counters.pendingSets, 0, "missing getTime must preserve pending")
  end)

  test("negative status preserves pending invite when getTime returns non-numeric", function()
    local handlers, counters, _, pendingRef = LoadHandlers({
      isNegativeApplicationStatusEvent = function()
        return true
      end,
      getTime = function()
        return "now"
      end,
    })
    pendingRef.value = { groupName = "x", capturedAt = 50 }
    handlers.LFG_LIST_APPLICATION_STATUS_UPDATED(nil, 7, "declined")
    Assert.Equal(counters.pendingSets, 0, "non-numeric getTime must preserve pending")
  end)

  -- HasActiveListing branches via APPLICATION_STATUS_UPDATED --------------------

  test("negative status keeps target when activityIDs table marks listing active", function()
    local handlers, counters, entryRef = LoadHandlers({
      isNegativeApplicationStatusEvent = function()
        return true
      end,
    })
    entryRef.value = { activityIDs = { [1234] = true } }
    handlers.LFG_LIST_APPLICATION_STATUS_UPDATED(nil, 7, "declined")
    Assert.Equal(counters.clears, 0, "active listing via activityIDs table must keep target")
    Assert.Equal(counters.teleportUpdates, 1, "teleport button still refreshes")
  end)

  test("negative status keeps target when listing carries non-empty name string", function()
    local handlers, counters, entryRef = LoadHandlers({
      isNegativeApplicationStatusEvent = function()
        return true
      end,
    })
    entryRef.value = { name = "Some Group" }
    handlers.LFG_LIST_APPLICATION_STATUS_UPDATED(nil, 7, "declined")
    Assert.Equal(counters.clears, 0, "active listing via name string must keep target")
  end)

  test("negative status keeps target when listing carries activityName string", function()
    local handlers, counters, entryRef = LoadHandlers({
      isNegativeApplicationStatusEvent = function()
        return true
      end,
    })
    entryRef.value = { activityName = "Some Activity" }
    handlers.LFG_LIST_APPLICATION_STATUS_UPDATED(nil, 7, "declined")
    Assert.Equal(counters.clears, 0, "active listing via activityName must keep target")
  end)

  test("negative status keeps target when listing carries title string", function()
    local handlers, counters, entryRef = LoadHandlers({
      isNegativeApplicationStatusEvent = function()
        return true
      end,
    })
    entryRef.value = { title = "Some Title" }
    handlers.LFG_LIST_APPLICATION_STATUS_UPDATED(nil, 7, "declined")
    Assert.Equal(counters.clears, 0, "active listing via title must keep target")
  end)

  test("negative status clears target when entryInfo is non-table (no listing)", function()
    local handlers, counters, entryRef = LoadHandlers({
      isNegativeApplicationStatusEvent = function()
        return true
      end,
      isInGroup = function()
        return false
      end,
    })
    entryRef.value = "not-a-table"
    handlers.LFG_LIST_APPLICATION_STATUS_UPDATED(nil, 7, "declined")
    Assert.Equal(counters.clears, 1, "non-table entryInfo must be treated as no active listing")
  end)

  -- LFG_LIST_SEARCH_RESULT_UPDATED ---------------------------------------------

  test("SEARCH_RESULT_UPDATED captures candidate in normal mode", function()
    local handlers, counters = LoadHandlers()
    handlers.LFG_LIST_SEARCH_RESULT_UPDATED(nil, 42)
    Assert.Equal(counters.captures, 1, "must capture candidate")
  end)

  test("SEARCH_RESULT_UPDATED logs via logRuntimeTracef when configured", function()
    local logCalls = {}
    local handlers, counters = LoadHandlers({
      logRuntimeTracef = function(format, ...)
        table.insert(logCalls, { format = format, args = { ... } })
      end,
    })
    handlers.LFG_LIST_SEARCH_RESULT_UPDATED(nil, 99)
    Assert.Equal(#logCalls, 1, "logRuntimeTracef must be invoked exactly once")
    Assert.Equal(
      logCalls[1].format,
      "[QUEUE] search_result_updated searchResultID=%s inChallenge=%s",
      "trace format string must match"
    )
    Assert.Equal(logCalls[1].args[1], "99", "first formatted arg is the search result id")
    Assert.Equal(counters.captures, 1, "candidate is still captured after logging")
  end)

  test("SEARCH_RESULT_UPDATED bails out in challenge mode", function()
    local handlers, counters = LoadHandlers({
      isInChallengeMode = function()
        return true
      end,
    })
    handlers.LFG_LIST_SEARCH_RESULT_UPDATED(nil, 42)
    Assert.Equal(counters.captures, 0, "must not capture in challenge mode")
  end)

  test("SEARCH_RESULT_UPDATED bails out in raid group", function()
    local handlers, counters = LoadHandlers({
      isRaidGroup = function()
        return true
      end,
    })
    handlers.LFG_LIST_SEARCH_RESULT_UPDATED(nil, 42)
    Assert.Equal(counters.captures, 0, "must not capture in raid group")
  end)

  test("SEARCH_RESULT_UPDATED also runs without a logRuntimeTracef function", function()
    -- The handler reads logf at BuildHandlers-time; passing nil exercises the
    -- 'logf == nil' branch on every following dispatch.
    local handlers, counters = LoadHandlers({
      logRuntimeTracef = nil,
    })
    handlers.LFG_LIST_SEARCH_RESULT_UPDATED(nil, 42)
    Assert.Equal(counters.captures, 1, "must capture even without runtime trace function")
  end)

  -- LFG_LIST_ACTIVE_ENTRY_UPDATE -----------------------------------------------

  test("ACTIVE_ENTRY_UPDATE bails out in challenge mode", function()
    local handlers, counters = LoadHandlers({
      isInChallengeMode = function()
        return true
      end,
    })
    handlers.LFG_LIST_ACTIVE_ENTRY_UPDATE(nil)
    Assert.Equal(counters.teleportUpdates, 0, "must not refresh in challenge mode")
    Assert.Equal(counters.pendingSets, 0, "must not touch pending in challenge mode")
  end)

  test("ACTIVE_ENTRY_UPDATE bails out in raid group", function()
    local handlers, counters = LoadHandlers({
      isRaidGroup = function()
        return true
      end,
    })
    handlers.LFG_LIST_ACTIVE_ENTRY_UPDATE(nil)
    Assert.Equal(counters.teleportUpdates, 0, "must not refresh while raiding")
  end)

  test("ACTIVE_ENTRY_UPDATE exits test mode when listing becomes active", function()
    local handlers, counters, entryRef = LoadHandlers({
      isTestMode = function()
        return true
      end,
    })
    entryRef.value = { activityID = 1001 }
    handlers.LFG_LIST_ACTIVE_ENTRY_UPDATE(nil)
    Assert.Equal(counters.exits, 1, "test mode must be exited when active listing appears")
    Assert.Equal(counters.activeJoinedKeyMapIDSets, 1, "must clear active joined key map id")
  end)

  test("ACTIVE_ENTRY_UPDATE exits test-all mode when listing becomes active", function()
    local handlers, counters, entryRef = LoadHandlers({
      isTestAllMode = function()
        return true
      end,
    })
    entryRef.value = { activityID = 1001 }
    handlers.LFG_LIST_ACTIVE_ENTRY_UPDATE(nil)
    Assert.Equal(counters.exits, 1, "test-all mode must be exited when active listing appears")
  end)

  test("ACTIVE_ENTRY_UPDATE refreshes UI when active joined key map id was cleared elsewhere", function()
    ---@type integer?
    local hadKey = 12345
    local handlers, counters, entryRef = LoadHandlers({
      getActiveJoinedKeyMapID = function()
        local current = hadKey
        hadKey = nil -- second read returns nil, simulating prior clear
        return current
      end,
      setActiveJoinedKeyMapID = function() end,
    })
    entryRef.value = nil -- no active listing
    handlers.LFG_LIST_ACTIVE_ENTRY_UPDATE(nil)
    Assert.Equal(counters.uiUpdates, 1, "UI must refresh after active joined key was dropped")
    Assert.Equal(counters.teleportUpdates, 1, "teleport button still refreshes once")
  end)
end
