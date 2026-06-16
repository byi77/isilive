---@diagnostic disable: undefined-global

-- Scenarios for InitializeStatusAndOperationalHelpers
-- (factory/isiLive_factory_controllers.lua:264-599). The orchestrator
-- InitializeFactoryRuntimeHelpers(ctx) attaches every helper lazily, so
-- we can stub ctx sub-controllers and modules and then invoke the
-- individual ctx-helpers directly.
--
-- Companion file to isilive_test_scenarios_factory_controllers_helpers.lua
-- which covers the other three Initialize* sub-functions.

local function BuildRuntimeStateStub(overrides)
  overrides = overrides or {}
  local state = {
    latestDungeonName = overrides.latestDungeonName,
    latestActivityID = overrides.latestActivityID,
    latestExtra = overrides.latestExtra,
    latestQueueMapID = overrides.latestQueueMapID,
    activeJoinedKeyMapID = overrides.activeJoinedKeyMapID,
    pendingQueueJoinInfo = overrides.pendingQueueJoinInfo,
    clearLatestQueueTargetCalls = 0,
  }
  state.ClearLatestQueueTarget = function()
    state.clearLatestQueueTargetCalls = state.clearLatestQueueTargetCalls + 1
    state.latestDungeonName = nil
    state.latestActivityID = nil
    state.latestExtra = nil
    state.latestQueueMapID = nil
  end
  state.GetLatestQueueState = function()
    return state.latestDungeonName, state.latestActivityID, state.latestExtra, state.latestQueueMapID
  end
  state.SetLatestQueueState = function(dungeonName, activityID, teleportSpellID, mapID)
    state.latestDungeonName = dungeonName
    state.latestActivityID = activityID
    state.latestExtra = teleportSpellID
    state.latestQueueMapID = mapID
  end
  state.GetActiveJoinedKeyMapID = function()
    return state.activeJoinedKeyMapID
  end
  state.GetPendingQueueJoinInfo = function()
    return state.pendingQueueJoinInfo
  end
  state.SetPendingQueueJoinInfo = function(value)
    state.pendingQueueJoinInfo = value
  end
  -- Minimal surface for InitializeGameAPIHelpers / Delegates / Rio; the
  -- orchestrator runs them too but they must not raise on a bare stub.
  state.IsReadyCheckActive = function()
    return false
  end
  state.SetReadyCheckActive = function() end
  state.GetReadyCheckReadyUntil = function() end
  state.SetReadyCheckReadyUntil = function() end
  state.ClearAllReadyCheckReady = function() end
  state.ClearExpiredReadyCheckReady = function() end
  state.GetReadyCheckDeclinedUntil = function() end
  state.SetReadyCheckDeclinedUntil = function() end
  state.ClearAllReadyCheckDeclined = function() end
  state.ClearExpiredReadyCheckDeclined = function() end
  state.GetWasInGroup = function() end
  state.SetWasInGroup = function() end
  state.GetWasRaidGroup = function() end
  state.SetWasRaidGroup = function() end
  state.GetWasGroupLeader = function() end
  state.SetWasGroupLeader = function() end
  state.GetRoster = function()
    return state.rosterRef or {}
  end
  state.SetRoster = function(v)
    state.rosterRef = v
  end
  state.SetRioBaselineByPlayerKey = function() end
  state.GetRioBaselineByPlayerKey = function()
    return {}
  end
  state.HasRioBaselineSnapshot = function()
    return false
  end
  state.SetHasRioBaselineSnapshot = function() end
  state.IsRioDeltaDisplayEnabled = function()
    return false
  end
  state.SetRioDeltaDisplayEnabled = function() end
  state.ClearRioBaseline = function() end
  return state
end

local function BuildModulesStub(overrides)
  overrides = overrides or {}
  return {
    sync = overrides.sync or {
      NormalizePlayerKey = function(name, realm)
        return (name or "") .. "-" .. (realm or "")
      end,
    },
    teleport = overrides.teleport,
    queue = overrides.queue,
  }
end

local function BuildCtx(runtimeState, modules, overrides)
  overrides = overrides or {}
  local printed = {}
  local ctx = {
    modules = modules,
    runtimeState = runtimeState,
    locale = overrides.locale or "enUS",
    L = overrides.L or {
      BTN_COUNTDOWN_CANCEL = "CANCEL",
      UNKNOWN_GROUP = "unknown",
      CHAT_QUEUE_PREFIX = "ISI-Q",
      JOINED_FROM_QUEUE = "joined %s",
    },
    GetL = overrides.GetL,
    GetRoster = overrides.GetRoster,
    IsPlayerLeader = overrides.IsPlayerLeader or function()
      return false
    end,
    Print = overrides.Print or function(msg)
      table.insert(printed, msg)
    end,
    _printed = printed,
    UpdateStatusLine = overrides.UpdateStatusLine,
    inspectController = overrides.inspectController,
    bindingController = overrides.bindingController,
    keySyncController = overrides.keySyncController,
    rosterPanelController = overrides.rosterPanelController,
    runtimeLogController = overrides.runtimeLogController,
    mainFrame = overrides.mainFrame,
    ResolveMapIDByActivityID = overrides.ResolveMapIDByActivityID or function()
      return nil
    end,
    GetUnitRio = function()
      return nil
    end,
  }
  ctx.GetL = ctx.GetL or function()
    return ctx.L
  end
  ctx.GetRoster = ctx.GetRoster or function()
    return runtimeState.rosterRef or {}
  end
  return ctx
end

local function Init(addon, ctx)
  addon._FactoryInternal.InitializeFactoryRuntimeHelpers(ctx)
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  local function Load()
    return LoadAddonModules({ "isiLive_factory_controllers.lua" })
  end

  -- =====================================================
  -- getPlayerSyncSummary / inspect + binding delegates
  -- =====================================================

  test("factory_controllers.status: getPlayerSyncSummary returns nil without sync module function", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local mods = BuildModulesStub({
      sync = {
        NormalizePlayerKey = function(n, r)
          return (n or "") .. "-" .. (r or "")
        end,
      },
    })
    local c = BuildCtx(rs, mods)
    WithGlobals({}, function()
      Init(addon, c)
      Assert.Nil(c.getPlayerSyncSummary("Alice", "Draenor"))
    end)
  end)

  test("factory_controllers.status: getPlayerSyncSummary delegates to sync.GetPlayerSyncSummary", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local captured
    local mods = BuildModulesStub({
      sync = {
        NormalizePlayerKey = function(n, r)
          return (n or "") .. "-" .. (r or "")
        end,
        GetPlayerSyncSummary = function(name, realm)
          captured = { name = name, realm = realm }
          return { status = "ok" }
        end,
      },
    })
    local c = BuildCtx(rs, mods)
    WithGlobals({}, function()
      Init(addon, c)
      local result = c.getPlayerSyncSummary("Alice", "Draenor")
      Assert.Equal(result.status, "ok")
      Assert.Equal(captured.name, "Alice")
      Assert.Equal(captured.realm, "Draenor")
    end)
  end)

  test("factory_controllers.status: ResetInspectAll / ResetInspectQueues delegate to inspectController", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local calls = { all = 0, queues = 0 }
    local inspectController = {
      ResetAll = function()
        calls.all = calls.all + 1
      end,
      ResetQueues = function()
        calls.queues = calls.queues + 1
      end,
    }
    local c = BuildCtx(rs, BuildModulesStub(), { inspectController = inspectController })
    WithGlobals({}, function()
      Init(addon, c)
      c.ResetInspectAll()
      c.ResetInspectQueues()
    end)
    Assert.Equal(calls.all, 1)
    Assert.Equal(calls.queues, 1)
  end)

  test("factory_controllers.status: GetPendingBindingApply returns false without bindingController", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      Assert.Equal(c.GetPendingBindingApply(), false)
    end)
  end)

  test("factory_controllers.status: GetPendingBindingApply delegates to bindingController", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub(), {
      bindingController = {
        GetPendingBindingApply = function()
          return true
        end,
      },
    })
    WithGlobals({}, function()
      Init(addon, c)
      Assert.Equal(c.GetPendingBindingApply(), true)
    end)
  end)

  -- =====================================================
  -- ClearLatestQueueTarget
  -- =====================================================

  test("factory_controllers.status: ClearLatestQueueTarget clears runtime + triggers UpdateStatusLine", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub({ latestQueueMapID = 2649 })
    local statusUpdates = 0
    local c = BuildCtx(rs, BuildModulesStub(), {
      UpdateStatusLine = function()
        statusUpdates = statusUpdates + 1
      end,
    })
    WithGlobals({}, function()
      Init(addon, c)
      c.ClearLatestQueueTarget()
    end)
    Assert.Equal(rs.clearLatestQueueTargetCalls, 1)
    Assert.Equal(statusUpdates, 1)
    Assert.Nil(rs.latestQueueMapID)
  end)

  test("factory_controllers.status: ClearLatestQueueTarget without UpdateStatusLine is safe", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      c.ClearLatestQueueTarget()
    end)
    Assert.Equal(rs.clearLatestQueueTargetCalls, 1)
  end)

  -- =====================================================
  -- AnnounceQueuedGroupJoin
  -- =====================================================

  test("factory_controllers.status: AnnounceQueuedGroupJoin returns silently when pending info missing", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      c.AnnounceQueuedGroupJoin()
    end)
    Assert.Equal(#c._printed, 0)
  end)

  test("factory_controllers.status: AnnounceQueuedGroupJoin clears pending info when player is leader", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub({ pendingQueueJoinInfo = { groupName = "Group A" } })
    local c = BuildCtx(rs, BuildModulesStub(), {
      IsPlayerLeader = function()
        return true
      end,
    })
    WithGlobals({}, function()
      Init(addon, c)
      c.AnnounceQueuedGroupJoin()
    end)
    Assert.Nil(rs.pendingQueueJoinInfo, "leader branch must clear pending info without printing")
    Assert.Equal(#c._printed, 0)
  end)

  test("factory_controllers.status: AnnounceQueuedGroupJoin prints join line and clears pending info", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub({ pendingQueueJoinInfo = { groupName = "Group A" } })
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      c.AnnounceQueuedGroupJoin()
    end)
    Assert.Nil(rs.pendingQueueJoinInfo)
    Assert.Equal(#c._printed, 3, "separator + body + separator")
    local body = c._printed[2]
    local found = string.find(body, "Group A", 1, true)
    Assert.Equal(found ~= nil, true, "printed body must mention the group name")
  end)

  test("factory_controllers.status: AnnounceQueuedGroupJoin falls back to UNKNOWN_GROUP label", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub({ pendingQueueJoinInfo = {} })
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      c.AnnounceQueuedGroupJoin()
    end)
    local found = string.find(c._printed[2], "unknown", 1, true)
    Assert.Equal(found ~= nil, true)
  end)

  -- =====================================================
  -- CaptureQueueJoinCandidate
  -- =====================================================

  test("factory_controllers.status: CaptureQueueJoinCandidate logs + blocks when challenge is active", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local logLines = {}
    local c = BuildCtx(rs, BuildModulesStub(), {
      runtimeLogController = {
        Log = function(msg)
          table.insert(logLines, msg)
        end,
      },
    })
    WithGlobals({
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return 42
        end,
      },
      IsInGroup = function()
        return false
      end,
      GetTime = function()
        return 100
      end,
    }, function()
      Init(addon, c)
      c.CaptureQueueJoinCandidate("My Group")
    end)
    Assert.Nil(rs.pendingQueueJoinInfo, "challenge-active must not record pending info")
    local matched = false
    for _, line in ipairs(logLines) do
      if string.find(line, "challenge_active", 1, true) then
        matched = true
      end
    end
    Assert.Equal(matched, true, "log must carry the blocked reason")
  end)

  test("factory_controllers.status: CaptureQueueJoinCandidate resets pending when not in group", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub({ pendingQueueJoinInfo = { groupName = "Stale" } })
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
      IsInGroup = function()
        return false
      end,
      GetTime = function()
        return 200
      end,
    }, function()
      Init(addon, c)
      c.CaptureQueueJoinCandidate({ groupName = "Fresh" })
    end)
    Assert.Equal(rs.pendingQueueJoinInfo.groupName, "Fresh", "new table candidate must capture groupName")
    Assert.Equal(rs.pendingQueueJoinInfo.capturedAt, 200)
  end)

  test("factory_controllers.status: CaptureQueueJoinCandidate filters system strings", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
      IsInGroup = function()
        return false
      end,
      GetTime = function()
        return 300
      end,
    }, function()
      Init(addon, c)
      c.CaptureQueueJoinCandidate("applied")
      c.CaptureQueueJoinCandidate("You have been invited")
      c.CaptureQueueJoinCandidate("declined")
    end)
    Assert.Nil(rs.pendingQueueJoinInfo, "system keyword strings must not be captured as group names")
  end)

  test("factory_controllers.status: CaptureQueueJoinCandidate announces immediately when in a group", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
      IsInGroup = function()
        return true
      end,
      GetTime = function()
        return 400
      end,
    }, function()
      Init(addon, c)
      c.CaptureQueueJoinCandidate({ name = "RealGroup" })
    end)
    Assert.Nil(rs.pendingQueueJoinInfo, "AnnounceQueuedGroupJoin must clear after printing")
    Assert.Equal(#c._printed, 3)
  end)

  test("factory_controllers.status: CaptureQueueJoinCandidate logs skipped reason when no group name", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local logLines = {}
    local c = BuildCtx(rs, BuildModulesStub(), {
      runtimeLogController = {
        Log = function(msg)
          table.insert(logLines, msg)
        end,
      },
    })
    WithGlobals({
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
      IsInGroup = function()
        return false
      end,
      GetTime = function()
        return 500
      end,
    }, function()
      Init(addon, c)
      c.CaptureQueueJoinCandidate({})
    end)
    local matched = false
    for _, line in ipairs(logLines) do
      if string.find(line, "no_group_name", 1, true) then
        matched = true
      end
    end
    Assert.Equal(matched, true)
    Assert.Nil(rs.pendingQueueJoinInfo)
  end)

  -- =====================================================
  -- RefreshLocalPlayerKey
  -- =====================================================

  test("factory_controllers.status: RefreshLocalPlayerKey delegates roster to keySyncController", function()
    local addon = Load()
    local roster = { player = { name = "Alice" } }
    local rs = BuildRuntimeStateStub()
    rs.rosterRef = roster
    local seenRoster
    local c = BuildCtx(rs, BuildModulesStub(), {
      keySyncController = {
        RefreshLocalPlayerKey = function(r)
          seenRoster = r
          return "refreshed"
        end,
      },
    })
    WithGlobals({}, function()
      Init(addon, c)
      Assert.Equal(c.RefreshLocalPlayerKey(), "refreshed")
    end)
    Assert.Equal(seenRoster, roster)
  end)

  -- =====================================================
  -- NormalizeStatusTargetName / NormalizeConcreteStatusTargetName
  -- =====================================================

  test("factory_controllers.status: NormalizeStatusTargetName rejects non-string and empty input", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      Assert.Nil(c.NormalizeStatusTargetName(nil))
      Assert.Nil(c.NormalizeStatusTargetName(42))
      Assert.Nil(c.NormalizeStatusTargetName(""))
      Assert.Nil(c.NormalizeStatusTargetName("   "), "whitespace-only must trim away and resolve to nil")
      Assert.Equal(c.NormalizeStatusTargetName("  Ara-Kara  "), "Ara-Kara")
    end)
  end)

  test("factory_controllers.status: NormalizeConcreteStatusTargetName drops name matching map ID", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      Assert.Equal(c.NormalizeConcreteStatusTargetName("Ara-Kara", 2649), "Ara-Kara")
      Assert.Nil(
        c.NormalizeConcreteStatusTargetName("2649", 2649),
        "a raw numeric name that equals the map ID is not a concrete dungeon label"
      )
      Assert.Equal(c.NormalizeConcreteStatusTargetName("2649", 500), "2649", "different map ID keeps the numeric label")
      Assert.Nil(c.NormalizeConcreteStatusTargetName(nil, 2649))
    end)
  end)

  -- =====================================================
  -- ResolveLocalStatusTargetMapID
  -- =====================================================

  test("factory_controllers.status: ResolveLocalStatusTargetMapID prefers LFGDetect detected map ID", function()
    local addon = Load()
    addon.LFGDetect = {
      GetDetectedMapID = function()
        return 2649
      end,
    }
    local rs = BuildRuntimeStateStub({ activeJoinedKeyMapID = 999, latestQueueMapID = 111 })
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      Assert.Equal(c.ResolveLocalStatusTargetMapID(), 2649)
    end)
    addon.LFGDetect = nil
  end)

  test("factory_controllers.status: ResolveLocalStatusTargetMapID falls back to active joined key", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub({ activeJoinedKeyMapID = 500, latestQueueMapID = 111 })
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      Assert.Equal(c.ResolveLocalStatusTargetMapID(), 500)
    end)
  end)

  test("factory_controllers.status: ResolveLocalStatusTargetMapID falls back to latest queue map ID", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub({ latestQueueMapID = 777 })
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      Assert.Equal(c.ResolveLocalStatusTargetMapID(), 777)
    end)
  end)

  test("factory_controllers.status: ResolveLocalStatusTargetMapID resolves activity ID via helper", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub({ latestActivityID = 9001 })
    local c = BuildCtx(rs, BuildModulesStub(), {
      ResolveMapIDByActivityID = function(id)
        if id == 9001 then
          return 321
        end
      end,
    })
    WithGlobals({}, function()
      Init(addon, c)
      Assert.Equal(c.ResolveLocalStatusTargetMapID(), 321)
    end)
  end)

  test("factory_controllers.status: ResolveLocalStatusTargetMapID returns nil when nothing matches", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      Assert.Nil(c.ResolveLocalStatusTargetMapID())
    end)
  end)

  -- =====================================================
  -- ResolveSyncedTargetInfo / ResolveStatusTargetMapID
  -- =====================================================

  test("factory_controllers.status: ResolveSyncedTargetInfo returns nil without sync surface", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      Assert.Nil(c.ResolveSyncedTargetInfo())
    end)
  end)

  test("factory_controllers.status: ResolveSyncedTargetInfo returns unified map + level", function()
    local addon = Load()
    local roster = {
      player = { name = "Alice", realm = "D" },
      party1 = { name = "Bob", realm = "D" },
    }
    local rs = BuildRuntimeStateStub()
    rs.rosterRef = roster
    local targetInfoByName = {
      Alice = { mapID = 2649, level = 12 },
      Bob = { mapID = 2649, level = 12 },
    }
    local mods = BuildModulesStub({
      sync = {
        NormalizePlayerKey = function(n, r)
          return (n or "") .. "-" .. (r or "")
        end,
        GetPlayerTargetInfo = function(name)
          return targetInfoByName[name]
        end,
      },
    })
    local c = BuildCtx(rs, mods)
    WithGlobals({}, function()
      Init(addon, c)
      local info = c.ResolveSyncedTargetInfo()
      Assert.Equal(info.mapID, 2649)
      Assert.Equal(info.level, 12)
    end)
  end)

  test("factory_controllers.status: ResolveSyncedTargetInfo returns nil when map IDs conflict", function()
    local addon = Load()
    local roster = {
      player = { name = "Alice", realm = "D" },
      party1 = { name = "Bob", realm = "D" },
    }
    local rs = BuildRuntimeStateStub()
    rs.rosterRef = roster
    local targetInfoByName = {
      Alice = { mapID = 2649, level = 12 },
      Bob = { mapID = 2650, level = 12 },
    }
    local mods = BuildModulesStub({
      sync = {
        NormalizePlayerKey = function(n, r)
          return (n or "") .. "-" .. (r or "")
        end,
        GetPlayerTargetInfo = function(name)
          return targetInfoByName[name]
        end,
      },
    })
    local c = BuildCtx(rs, mods)
    WithGlobals({}, function()
      Init(addon, c)
      Assert.Nil(c.ResolveSyncedTargetInfo())
    end)
  end)

  test("factory_controllers.status: ResolveSyncedTargetInfo drops level on conflict but keeps map ID", function()
    local addon = Load()
    local roster = {
      player = { name = "Alice", realm = "D" },
      party1 = { name = "Bob", realm = "D" },
    }
    local rs = BuildRuntimeStateStub()
    rs.rosterRef = roster
    local targetInfoByName = {
      Alice = { mapID = 2649, level = 12 },
      Bob = { mapID = 2649, level = 11 },
    }
    local mods = BuildModulesStub({
      sync = {
        NormalizePlayerKey = function(n, r)
          return (n or "") .. "-" .. (r or "")
        end,
        GetPlayerTargetInfo = function(name)
          return targetInfoByName[name]
        end,
      },
    })
    local c = BuildCtx(rs, mods)
    WithGlobals({}, function()
      Init(addon, c)
      local info = c.ResolveSyncedTargetInfo()
      Assert.Equal(info.mapID, 2649)
      Assert.Nil(info.level, "conflicting levels must drop back to nil")
    end)
  end)

  test("factory_controllers.status: ResolveStatusTargetMapID prefers local resolver, then synced", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub({ latestQueueMapID = 300 })
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      Assert.Equal(c.ResolveStatusTargetMapID(), 300)
    end)

    local rs2 = BuildRuntimeStateStub()
    local roster = { player = { name = "Alice", realm = "D" } }
    rs2.rosterRef = roster
    local mods2 = BuildModulesStub({
      sync = {
        NormalizePlayerKey = function(n, r)
          return (n or "") .. "-" .. (r or "")
        end,
        GetPlayerTargetInfo = function()
          return { mapID = 501 }
        end,
      },
    })
    local c2 = BuildCtx(rs2, mods2)
    WithGlobals({}, function()
      Init(addon, c2)
      Assert.Equal(c2.ResolveStatusTargetMapID(), 501, "fallback must use ResolveSyncedTargetInfo map ID")
    end)

    local rs3 = BuildRuntimeStateStub()
    local c3 = BuildCtx(rs3, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c3)
      Assert.Nil(c3.ResolveStatusTargetMapID())
    end)
  end)

  -- =====================================================
  -- GetStatusTargetDungeonInfo
  -- =====================================================

  test("factory_controllers.status: GetStatusTargetDungeonInfo uses latest queue name when concrete", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub({ latestDungeonName = "Ara-Kara", latestQueueMapID = 2649 })
    rs.rosterRef = {}
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      local info = c.GetStatusTargetDungeonInfo()
      Assert.Equal(info.name, "Ara-Kara")
      Assert.Nil(info.level, "no roster owner and no synced level => nil level")
    end)
  end)

  test("factory_controllers.status: GetStatusTargetDungeonInfo falls back to teleport module", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub({ latestQueueMapID = 2649 })
    rs.rosterRef = {}
    local mods = BuildModulesStub({
      teleport = {
        GetTeleportInfoByMapID = function(mapID)
          if mapID == 2649 then
            return { mapName = "Ara-Kara" }
          end
        end,
      },
    })
    local c = BuildCtx(rs, mods)
    WithGlobals({}, function()
      Init(addon, c)
      local info = c.GetStatusTargetDungeonInfo()
      Assert.Equal(info.name, "Ara-Kara")
    end)
  end)

  test("factory_controllers.status: GetStatusTargetDungeonInfo rejects stale queue name for accepted map", function()
    local addon = Load()
    addon.LFGDetect = {
      GetDetectedMapID = function()
        return 2441
      end,
    }
    local rs = BuildRuntimeStateStub({
      latestDungeonName = "Sitz des Triumvirats",
      latestQueueMapID = 1989,
    })
    rs.rosterRef = {}
    local mods = BuildModulesStub({
      teleport = {
        GetTeleportInfoByMapID = function(mapID)
          if mapID == 2441 then
            return { mapName = "Akademie von Algeth'ar" }
          end
        end,
      },
    })
    local c = BuildCtx(rs, mods)
    WithGlobals({}, function()
      Init(addon, c)
      local info = c.GetStatusTargetDungeonInfo()
      Assert.Equal(
        info.name,
        "Akademie von Algeth'ar",
        "accepted mapID must not be paired with a stale latestQueueDungeonName"
      )
    end)
    addon.LFGDetect = nil
  end)

  test("factory_controllers.status: GetStatusTargetDungeonInfo falls back to queue activity name", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub({ latestActivityID = 9001, latestQueueMapID = 1 })
    rs.rosterRef = {}
    local mods = BuildModulesStub({
      queue = {
        GetActivityName = function(id)
          if id == 9001 then
            return "City of Threads"
          end
        end,
      },
    })
    local c = BuildCtx(rs, mods)
    WithGlobals({}, function()
      Init(addon, c)
      local info = c.GetStatusTargetDungeonInfo()
      Assert.Equal(info.name, "City of Threads")
    end)
  end)

  test("factory_controllers.status: GetStatusTargetDungeonInfo returns nil when no name resolves", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      Assert.Nil(c.GetStatusTargetDungeonInfo())
    end)
  end)

  test("factory_controllers.status: GetStatusTargetDungeonInfo picks level from roster owner unit", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub({ latestDungeonName = "Ara-Kara", latestQueueMapID = 2649 })
    local roster = { party1 = { name = "Bob", realm = "D", keyLevel = 14 } }
    rs.rosterRef = roster
    local c = BuildCtx(rs, BuildModulesStub(), {})
    WithGlobals({}, function()
      Init(addon, c)
      -- Route ResolveActiveKeyOwnerUnit to party1 so the roster level is picked up.
      c.ResolveActiveKeyOwnerUnit = function()
        return "party1"
      end
      local info = c.GetStatusTargetDungeonInfo()
      Assert.Equal(info.level, 14)
    end)
  end)

  test("factory_controllers.status: GetStatusTargetDungeonInfo uses synced level when owner level missing", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub({ latestDungeonName = "Ara-Kara", latestQueueMapID = 2649 })
    local roster = { player = { name = "Alice", realm = "D" } }
    rs.rosterRef = roster
    local mods = BuildModulesStub({
      sync = {
        NormalizePlayerKey = function(n, r)
          return (n or "") .. "-" .. (r or "")
        end,
        GetPlayerTargetInfo = function()
          return { mapID = 2649, level = 15 }
        end,
      },
    })
    local c = BuildCtx(rs, mods)
    WithGlobals({}, function()
      Init(addon, c)
      local info = c.GetStatusTargetDungeonInfo()
      Assert.Equal(info.level, 15)
    end)
  end)

  test("factory_controllers.status: GetStatusTargetDungeonInfo prefers LFG title level over roster owner", function()
    -- LFG group title "+13" must win over a +14 roster owner: the listing
    -- title is authoritative for the played key level (boost runs, leader
    -- is not the key owner), and once the invite is accepted the level must
    -- not flip when later roster/sync updates settle.
    local addon = Load()
    local rs = BuildRuntimeStateStub({ latestDungeonName = "Ara-Kara", latestQueueMapID = 2649 })
    local roster = { party1 = { name = "Bob", realm = "D", keyLevel = 14 } }
    rs.rosterRef = roster
    addon.LFGDetect = {
      GetActiveInviteTitleLevel = function()
        return 13
      end,
    }
    local c = BuildCtx(rs, BuildModulesStub(), {})
    WithGlobals({}, function()
      Init(addon, c)
      c.ResolveActiveKeyOwnerUnit = function()
        return "party1"
      end
      local info = c.GetStatusTargetDungeonInfo()
      Assert.Equal(info.level, 13)
    end)
  end)

  test("factory_controllers.status: GetStatusTargetDungeonInfo prefers LFG title level over synced level", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub({ latestDungeonName = "Ara-Kara", latestQueueMapID = 2649 })
    local roster = { player = { name = "Alice", realm = "D" } }
    rs.rosterRef = roster
    local mods = BuildModulesStub({
      sync = {
        NormalizePlayerKey = function(n, r)
          return (n or "") .. "-" .. (r or "")
        end,
        GetPlayerTargetInfo = function()
          return { mapID = 2649, level = 15 }
        end,
      },
    })
    addon.LFGDetect = {
      GetActiveInviteTitleLevel = function()
        return 12
      end,
    }
    local c = BuildCtx(rs, mods)
    WithGlobals({}, function()
      Init(addon, c)
      local info = c.GetStatusTargetDungeonInfo()
      Assert.Equal(info.level, 12)
    end)
  end)

  test("factory_controllers.status: reload roster target snapshot restores target level before roster owner", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local roster = { party1 = { name = "Bob", realm = "D", keyLevel = 14 } }
    rs.rosterRef = roster
    local c = BuildCtx(rs, BuildModulesStub(), {})
    WithGlobals({}, function()
      Init(addon, c)
      local restored = c.RestoreReloadRosterTargetSnapshot({
        mapID = 2441,
        name = "Tazavesh",
        level = 12,
        levelText = "+12",
      })
      Assert.True(restored, "valid reload target snapshot must be accepted")
      c.ResolveActiveKeyOwnerUnit = function()
        return "party1"
      end
      local info = c.GetStatusTargetDungeonInfo()
      Assert.Equal(info.name, "Tazavesh")
      Assert.Equal(info.level, 12, "reload snapshot level must keep accepted key level after reload")
      Assert.Equal(c.ResolveLocalStatusTargetMapID(), 2441, "restored snapshot must seed local target mapID")

      local saved = c.GetReloadRosterTargetSnapshot()
      Assert.Equal(saved.mapID, 2441, "saved target snapshot must keep mapID")
      Assert.Equal(saved.name, "Tazavesh", "saved target snapshot must keep name")
      Assert.Equal(saved.level, 12, "saved target snapshot must keep level")
    end)
  end)

  test(
    "factory_controllers.status: GetStatusTargetDungeonInfo carries LFG level markup when numeric level is unresolved",
    function()
      local addon = Load()
      local rs = BuildRuntimeStateStub({ latestDungeonName = "Ara-Kara", latestQueueMapID = 2649 })
      rs.rosterRef = { player = { name = "Alice", realm = "D" } }
      addon.LFGDetect = {
        GetActiveInviteTitleLevel = function()
          return nil
        end,
        GetActiveInviteTitleLevelText = function()
          return "|Kk584|k"
        end,
      }
      local c = BuildCtx(rs, BuildModulesStub())
      WithGlobals({}, function()
        Init(addon, c)
        local info = c.GetStatusTargetDungeonInfo()
        Assert.Nil(info.level, "opaque Blizzard markup must not become a synthetic numeric level")
        Assert.Equal(info.levelText, "|Kk584|k", "exact Blizzard keystone markup must remain available to UI")
      end)
    end
  )

  test(
    "factory_controllers.status: GetStatusTargetDungeonInfo falls back to roster owner when title hint missing",
    function()
      -- Manual /invite or no LFG context: GetActiveInviteTitleLevel returns nil
      -- and the roster-owner level remains the source of truth.
      local addon = Load()
      local rs = BuildRuntimeStateStub({ latestDungeonName = "Ara-Kara", latestQueueMapID = 2649 })
      local roster = { party1 = { name = "Bob", realm = "D", keyLevel = 14 } }
      rs.rosterRef = roster
      addon.LFGDetect = {
        GetActiveInviteTitleLevel = function()
          return nil
        end,
      }
      local c = BuildCtx(rs, BuildModulesStub(), {})
      WithGlobals({}, function()
        Init(addon, c)
        c.ResolveActiveKeyOwnerUnit = function()
          return "party1"
        end
        local info = c.GetStatusTargetDungeonInfo()
        Assert.Equal(info.level, 14)
      end)
    end
  )

  -- =====================================================
  -- SendOwnTargetSnapshot
  -- =====================================================

  test("factory_controllers.status: SendOwnTargetSnapshot no-ops without sync.SendTarget", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      -- Must not raise.
      c.SendOwnTargetSnapshot(false, "test", false)
    end)
  end)

  test("factory_controllers.status: SendOwnTargetSnapshot sends resolved target payload", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub({ latestQueueMapID = 2649 })
    local roster = { party1 = { name = "Bob", realm = "D", keyLevel = 14 } }
    rs.rosterRef = roster
    local sent
    local mods = BuildModulesStub({
      sync = {
        NormalizePlayerKey = function(n, r)
          return (n or "") .. "-" .. (r or "")
        end,
        SendTarget = function(payload)
          sent = payload
        end,
      },
    })
    local mainFrame = {
      IsShown = function()
        return true
      end,
    }
    local c = BuildCtx(rs, mods, {
      keySyncController = {
        ResolveActiveKeyOwnerUnit = function(_, _, _)
          return "party1"
        end,
      },
      mainFrame = mainFrame,
    })
    WithGlobals({}, function()
      Init(addon, c)
      c.SendOwnTargetSnapshot(true, "unit-test", false)
    end)
    Assert.Equal(sent.mapID, 2649)
    Assert.Equal(sent.level, 14)
    Assert.Equal(sent.force, true)
    Assert.Equal(sent.isVisible, true)
    Assert.Equal(sent.allowHidden, false)
    Assert.Equal(sent.source, "unit-test")
  end)

  test("factory_controllers.status: SendOwnTargetSnapshot prefers LFG title level over roster owner", function()
    -- Sync payload must mirror the local announce: LFG title-level wins so
    -- peers without a local title hint (joined by /invite) receive the
    -- correct level instead of an arbitrary roster-owner level.
    local addon = Load()
    local rs = BuildRuntimeStateStub({ latestQueueMapID = 2649 })
    local roster = { party1 = { name = "Bob", realm = "D", keyLevel = 14 } }
    rs.rosterRef = roster
    local sent
    local mods = BuildModulesStub({
      sync = {
        NormalizePlayerKey = function(n, r)
          return (n or "") .. "-" .. (r or "")
        end,
        SendTarget = function(payload)
          sent = payload
        end,
      },
    })
    addon.LFGDetect = {
      GetActiveInviteTitleLevel = function()
        return 13
      end,
      GetActiveInviteLeader = function()
        return nil
      end,
    }
    local c = BuildCtx(rs, mods, {
      keySyncController = {
        ResolveActiveKeyOwnerUnit = function(_, _, _)
          return "party1"
        end,
      },
      mainFrame = {
        IsShown = function()
          return true
        end,
      },
    })
    WithGlobals({}, function()
      Init(addon, c)
      c.SendOwnTargetSnapshot(true, "title-wins", false)
    end)
    Assert.Equal(sent.mapID, 2649)
    Assert.Equal(sent.level, 13, "LFG title-level (+13) must win over roster owner +14")
  end)

  test(
    "factory_controllers.status: SendOwnTargetSnapshot carries LFG level markup when numeric level is unresolved",
    function()
      local addon = Load()
      local rs = BuildRuntimeStateStub({ latestQueueMapID = 2649 })
      local sent
      local mods = BuildModulesStub({
        sync = {
          NormalizePlayerKey = function(n, r)
            return (n or "") .. "-" .. (r or "")
          end,
          SendTarget = function(payload)
            sent = payload
          end,
        },
      })
      addon.LFGDetect = {
        GetActiveInviteTitleLevel = function()
          return nil
        end,
        GetActiveInviteTitleLevelText = function()
          return "|Kk584|k"
        end,
      }
      local c = BuildCtx(rs, mods, {
        mainFrame = {
          IsShown = function()
            return true
          end,
        },
      })
      WithGlobals({}, function()
        Init(addon, c)
        c.SendOwnTargetSnapshot(true, "level-text", false)
      end)
      Assert.Equal(sent.mapID, 2649)
      Assert.Nil(sent.level, "opaque Blizzard markup must not become a synthetic numeric level")
      Assert.Equal(sent.levelText, "|Kk584|k", "exact Blizzard keystone markup must be sent to peers")
    end
  )

  test("factory_controllers.status: SendOwnTargetSnapshot marks allowHidden when frame is hidden", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local sent
    local mods = BuildModulesStub({
      sync = {
        NormalizePlayerKey = function(n, r)
          return (n or "") .. "-" .. (r or "")
        end,
        SendTarget = function(payload)
          sent = payload
        end,
      },
    })
    local c = BuildCtx(rs, mods, {
      mainFrame = {
        IsShown = function()
          return false
        end,
      },
    })
    WithGlobals({}, function()
      Init(addon, c)
      c.SendOwnTargetSnapshot(false, "hidden-case", false)
    end)
    Assert.Equal(sent.isVisible, false)
    Assert.Equal(sent.allowHidden, true, "hidden frame must force allowHidden=true")
  end)

  -- =====================================================
  -- UpdateCountdownCancelButton
  -- =====================================================

  test("factory_controllers.status: UpdateCountdownCancelButton no-ops without rosterPanelController", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      c.UpdateCountdownCancelButton()
    end)
  end)

  test("factory_controllers.status: UpdateCountdownCancelButton forwards localized label", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local captured
    local c = BuildCtx(rs, BuildModulesStub(), {
      rosterPanelController = {
        SetCountdownCancelText = function(text)
          captured = text
        end,
      },
    })
    WithGlobals({}, function()
      Init(addon, c)
      c.UpdateCountdownCancelButton()
    end)
    Assert.Equal(captured, "CANCEL")
  end)

  -- =====================================================
  -- GetTeleportEmptyStateText
  -- =====================================================

  test("factory_controllers.status: GetTeleportEmptyStateText returns nil without SeasonData", function()
    local addon = Load()
    addon.SeasonData = nil
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      Init(addon, c)
      Assert.Nil(c.GetTeleportEmptyStateText())
    end)
  end)

  test("factory_controllers.status: GetTeleportEmptyStateText returns nil when season has active dungeons", function()
    local addon = Load()
    addon.SeasonData = {
      HasActiveDungeons = function()
        return true
      end,
      GetInactivePortalMessage = function()
        return "SHOULD NOT BE READ"
      end,
    }
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    local previous = rawget(_G, "IsiLiveDB")
    rawset(_G, "IsiLiveDB", { locale = "deDE" })
    local ok, err = pcall(function()
      WithGlobals({}, function()
        Init(addon, c)
        Assert.Nil(c.GetTeleportEmptyStateText())
      end)
    end)
    rawset(_G, "IsiLiveDB", previous)
    addon.SeasonData = nil
    if not ok then
      error(err, 0)
    end
  end)

  test("factory_controllers.status: GetTeleportEmptyStateText returns localized inactive-portal message", function()
    local addon = Load()
    local seenLocale
    addon.SeasonData = {
      HasActiveDungeons = function()
        return false
      end,
      GetInactivePortalMessage = function(locale)
        seenLocale = locale
        return "no active portals (" .. locale .. ")"
      end,
    }
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub(), { locale = "enUS" })
    local previous = rawget(_G, "IsiLiveDB")
    rawset(_G, "IsiLiveDB", { locale = "deDE" })
    local ok, err = pcall(function()
      WithGlobals({}, function()
        Init(addon, c)
        local text = c.GetTeleportEmptyStateText()
        Assert.Equal(text, "no active portals (deDE)", "DB locale must win over ctx locale")
      end)
    end)
    rawset(_G, "IsiLiveDB", previous)
    addon.SeasonData = nil
    if not ok then
      error(err, 0)
    end
    Assert.Equal(seenLocale, "deDE")
  end)
end
