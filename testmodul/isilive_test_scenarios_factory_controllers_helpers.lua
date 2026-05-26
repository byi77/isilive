---@diagnostic disable: undefined-global

-- Scenarios for the ctx-helper initializers in
-- factory/isiLive_factory_controllers.lua, invoked via the exported
-- FI.InitializeFactoryRuntimeHelpers(ctx). This covers three of the
-- four internal Initialize* sub-functions:
--
--   * InitializeGameAPIHelpers: ReadyCheck delegates, challenge-map
--     reader, party-instance + portal-navigator resolvers.
--   * InitializeRuntimeStateDelegates: was-in-group / was-raid-group /
--     was-group-leader / roster getter+setter + NormalizePlayerKey.
--   * InitializeRioHelpers: BuildRosterInfoPlayerKey, RestoreRioBaseline,
--     ClearRioBaselineSnapshot, CaptureRioBaselineSnapshot,
--     EnableRioDeltaDisplay, GetRioDeltaForRosterInfo.
--
-- The fourth sub-function (InitializeStatusAndOperationalHelpers, 340
-- lines at factory_controllers.lua:264-602) is left to a follow-up
-- pass - it wires status/target/teleport callbacks with a much wider
-- dependency surface.
--
-- The existing factory_primary / factory_secondary scenarios already
-- exercise end-to-end flows; this file targets the sub-function
-- surfaces that those flows happen to skip.

local function BuildRuntimeStateStub()
  local state = {
    storage = {
      wasInGroup = false,
      wasRaidGroup = false,
      wasGroupLeader = false,
      roster = {},
      readyCheckActive = false,
      readyCheckReady = {},
      readyCheckDeclined = {},
      rioBaselineByKey = {},
      hasRioBaselineSnapshot = false,
      rioDeltaDisplayEnabled = false,
      rioBaselineClears = 0,
    },
  }
  local s = state.storage

  state.GetWasInGroup = function()
    return s.wasInGroup
  end
  state.SetWasInGroup = function(v)
    s.wasInGroup = v
  end
  state.GetWasRaidGroup = function()
    return s.wasRaidGroup
  end
  state.SetWasRaidGroup = function(v)
    s.wasRaidGroup = v
  end
  state.GetWasGroupLeader = function()
    return s.wasGroupLeader
  end
  state.SetWasGroupLeader = function(v)
    s.wasGroupLeader = v
  end
  state.GetRoster = function()
    return s.roster
  end
  state.SetRoster = function(v)
    s.roster = v
  end
  state.IsReadyCheckActive = function()
    return s.readyCheckActive
  end
  state.SetReadyCheckActive = function(v)
    s.readyCheckActive = v
  end
  state.GetReadyCheckReadyUntil = function(unit)
    return s.readyCheckReady[unit]
  end
  state.SetReadyCheckReadyUntil = function(unit, v)
    s.readyCheckReady[unit] = v
  end
  state.ClearAllReadyCheckReady = function()
    s.readyCheckReady = {}
  end
  state.ClearExpiredReadyCheckReady = function(now)
    local cleared = false
    for u, until_ in pairs(s.readyCheckReady) do
      if until_ and until_ <= now then
        s.readyCheckReady[u] = nil
        cleared = true
      end
    end
    return cleared
  end
  state.GetReadyCheckDeclinedUntil = function(unit)
    return s.readyCheckDeclined[unit]
  end
  state.SetReadyCheckDeclinedUntil = function(unit, v)
    s.readyCheckDeclined[unit] = v
  end
  state.ClearAllReadyCheckDeclined = function()
    s.readyCheckDeclined = {}
  end
  state.ClearExpiredReadyCheckDeclined = function(now)
    local cleared = false
    for u, until_ in pairs(s.readyCheckDeclined) do
      if until_ and until_ <= now then
        s.readyCheckDeclined[u] = nil
        cleared = true
      end
    end
    return cleared
  end
  state.SetRioBaselineByPlayerKey = function(v)
    s.rioBaselineByKey = v or {}
  end
  state.GetRioBaselineByPlayerKey = function()
    return s.rioBaselineByKey
  end
  state.HasRioBaselineSnapshot = function()
    return s.hasRioBaselineSnapshot
  end
  state.SetHasRioBaselineSnapshot = function(v)
    s.hasRioBaselineSnapshot = v and true or false
  end
  state.IsRioDeltaDisplayEnabled = function()
    return s.rioDeltaDisplayEnabled
  end
  state.SetRioDeltaDisplayEnabled = function(v)
    s.rioDeltaDisplayEnabled = v and true or false
  end
  state.ClearRioBaseline = function()
    s.rioBaselineByKey = {}
    s.hasRioBaselineSnapshot = false
    s.rioDeltaDisplayEnabled = false
    s.rioBaselineClears = s.rioBaselineClears + 1
  end

  return state, s
end

local function BuildModulesStub(overrides)
  overrides = overrides or {}
  return {
    sync = {
      NormalizePlayerKey = overrides.NormalizePlayerKey or function(name, realm)
        return (name or "") .. "-" .. (realm or "")
      end,
    },
    teleport = overrides.teleport,
  }
end

local function BuildCtx(runtimeState, modules, overrides)
  overrides = overrides or {}
  return {
    modules = modules,
    runtimeState = runtimeState,
    GetUnitRio = overrides.GetUnitRio or function()
      return nil
    end,
  }
end

local function InitializeHelpers(ctx, addonTable)
  addonTable._FactoryInternal.InitializeFactoryRuntimeHelpers(ctx)
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  local function Load()
    return LoadAddonModules({ "isiLive_factory_controllers.lua" })
  end

  -- =====================================================
  -- InitializeGameAPIHelpers
  -- =====================================================

  test("factory_controllers: GetActiveChallengeMapID returns nil when C_ChallengeMode is absent", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({ C_ChallengeMode = false }, function()
      InitializeHelpers(c, addon)
      Assert.Nil(c.GetActiveChallengeMapID(), "missing C_ChallengeMode must resolve to nil")
    end)
  end)

  test("factory_controllers: GetActiveChallengeMapID forwards the pcalled API result", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals(
      { C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return 2649
        end,
      } },
      function()
        InitializeHelpers(c, addon)
        Assert.Equal(c.GetActiveChallengeMapID(), 2649, "API result must be forwarded")
      end
    )
  end)

  test("factory_controllers: GetActiveChallengeMapID returns nil when API raises", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          error("boom", 0)
        end,
      },
    }, function()
      InitializeHelpers(c, addon)
      Assert.Nil(c.GetActiveChallengeMapID(), "pcall failure must resolve to nil")
    end)
  end)

  test("factory_controllers: GetActiveChallengeMapID returns nil for secret values", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    local secretMapID = {}
    WithGlobals({
      issecretvalue = function(value)
        return value == secretMapID
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return secretMapID
        end,
      },
    }, function()
      InitializeHelpers(c, addon)
      Assert.Nil(c.GetActiveChallengeMapID(), "secret active map ID must resolve to nil")
    end)
  end)

  test("factory_controllers: ready-check delegates forward to runtimeState", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    c.SetReadyCheckActive(true)
    Assert.Equal(c.IsReadyCheckActive(), true, "SetReadyCheckActive must propagate to runtimeState")
    Assert.Equal(storage.readyCheckActive, true, "state storage must reflect the set value")
    c.SetReadyCheckReadyUntil("player", 123)
    Assert.Equal(c.GetReadyCheckReadyUntil("player"), 123, "ready-until getter/setter must round-trip")
    c.SetReadyCheckReadyUntil("party1", 50)
    Assert.Equal(c.ClearExpiredReadyCheckReady(100), true, "expired entries must be cleared and reported")
    Assert.Nil(c.GetReadyCheckReadyUntil("party1"), "expired ready entry must be gone")
    Assert.Equal(c.GetReadyCheckReadyUntil("player"), 123, "future ready entry must survive")
    c.ClearAllReadyCheckReady()
    Assert.Nil(c.GetReadyCheckReadyUntil("player"), "ClearAllReadyCheckReady must wipe all entries")
  end)

  test("factory_controllers: declined-check delegates forward to runtimeState", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    c.SetReadyCheckDeclinedUntil("party2", 42)
    Assert.Equal(c.GetReadyCheckDeclinedUntil("party2"), 42, "declined-until setter/getter must round-trip")
    c.SetReadyCheckDeclinedUntil("party3", 10)
    Assert.Equal(c.ClearExpiredReadyCheckDeclined(20), true, "expired declined entries must be reported cleared")
    Assert.Nil(c.GetReadyCheckDeclinedUntil("party3"), "expired declined entry must be gone")
    c.ClearAllReadyCheckDeclined()
    Assert.Nil(c.GetReadyCheckDeclinedUntil("party2"), "ClearAllReadyCheckDeclined must wipe all entries")
  end)

  test("factory_controllers: IsInPartyInstance returns true only for party instance type", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    local instanceType = "party"
    WithGlobals({
      GetInstanceInfo = function()
        return "Name", instanceType
      end,
    }, function()
      InitializeHelpers(c, addon)
      Assert.Equal(c.IsInPartyInstance(), true, "party instance must resolve to true")
      instanceType = "raid"
      Assert.Equal(c.IsInPartyInstance(), false, "raid instance must resolve to false")
      instanceType = "none"
      Assert.Equal(c.IsInPartyInstance(), false, "none instance must resolve to false")
    end)
  end)

  test("factory_controllers: IsPortalNavigatorEnabled defaults to true when IsiLiveDB is absent", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    -- rawset explicitly to nil because WithGlobals iterates stubs via
    -- pairs(), which cannot express "set this key to nil" - the
    -- production code checks `dbRef == nil`, not `dbRef == false`.
    local previous = rawget(_G, "IsiLiveDB")
    rawset(_G, "IsiLiveDB", nil)
    local ok, err = pcall(function()
      WithGlobals({}, function()
        InitializeHelpers(c, addon)
        Assert.Equal(c.IsPortalNavigatorEnabled(), true, "missing DB must keep navigator enabled by default")
      end)
    end)
    rawset(_G, "IsiLiveDB", previous)
    if not ok then
      error(err, 0)
    end
  end)

  test("factory_controllers: IsPortalNavigatorEnabled respects explicit DB disable", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({ IsiLiveDB = { showPortalNavigator = false } }, function()
      InitializeHelpers(c, addon)
      Assert.Equal(c.IsPortalNavigatorEnabled(), false, "explicit showPortalNavigator=false must disable")
    end)
  end)

  test("factory_controllers: IsPortalNavigatorEnabled keeps enabled when DB has no override", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({ IsiLiveDB = {} }, function()
      InitializeHelpers(c, addon)
      Assert.Equal(c.IsPortalNavigatorEnabled(), true, "missing flag must stay enabled")
    end)
  end)

  -- =====================================================
  -- InitializeRuntimeStateDelegates
  -- =====================================================

  test("factory_controllers: was-in-group delegate round-trips via runtimeState", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    c.SetWasInGroup(true)
    Assert.Equal(storage.wasInGroup, true, "SetWasInGroup must store through runtimeState")
    Assert.Equal(c.GetWasInGroup(), true, "GetWasInGroup must read from runtimeState")
  end)

  test("factory_controllers: was-raid-group delegate round-trips", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    c.SetWasRaidGroup(true)
    Assert.Equal(storage.wasRaidGroup, true, "SetWasRaidGroup must store through runtimeState")
    Assert.Equal(c.GetWasRaidGroup(), true, "GetWasRaidGroup must read from runtimeState")
  end)

  test("factory_controllers: was-group-leader delegate round-trips", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    c.SetWasGroupLeader(true)
    Assert.Equal(storage.wasGroupLeader, true, "SetWasGroupLeader must store through runtimeState")
    Assert.Equal(c.GetWasGroupLeader(), true, "GetWasGroupLeader must read from runtimeState")
  end)

  test("factory_controllers: roster delegate round-trips", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    local newRoster = { player = { name = "P" } }
    c.SetRoster(newRoster)
    Assert.Equal(storage.roster, newRoster, "SetRoster must store through runtimeState")
    Assert.Equal(c.GetRoster(), newRoster, "GetRoster must read from runtimeState")
  end)

  test("factory_controllers: NormalizePlayerKey delegates to sync module", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local captured
    local modules = BuildModulesStub({
      NormalizePlayerKey = function(name, realm)
        captured = { name = name, realm = realm }
        return "NORMALIZED"
      end,
    })
    local c = BuildCtx(rs, modules)
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    Assert.Equal(c.NormalizePlayerKey("Alice", "Draenor"), "NORMALIZED", "return value must come from sync module")
    Assert.Equal(captured.name, "Alice", "name must be forwarded unchanged")
    Assert.Equal(captured.realm, "Draenor", "realm must be forwarded unchanged")
  end)

  -- =====================================================
  -- InitializeRioHelpers
  -- =====================================================

  test("factory_controllers: BuildRosterInfoPlayerKey returns nil for non-table input", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    Assert.Nil(c.BuildRosterInfoPlayerKey(nil), "nil input must resolve to nil key")
    Assert.Nil(c.BuildRosterInfoPlayerKey("not-a-table"), "string input must resolve to nil key")
    Assert.Nil(c.BuildRosterInfoPlayerKey(42), "number input must resolve to nil key")
  end)

  test("factory_controllers: BuildRosterInfoPlayerKey returns nil for missing or empty name", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    Assert.Nil(c.BuildRosterInfoPlayerKey({}), "missing name must resolve to nil")
    Assert.Nil(c.BuildRosterInfoPlayerKey({ name = "" }), "empty name must resolve to nil")
    Assert.Nil(c.BuildRosterInfoPlayerKey({ name = 42 }), "non-string name must resolve to nil")
  end)

  test("factory_controllers: BuildRosterInfoPlayerKey normalizes name+realm via NormalizePlayerKey", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local modules = BuildModulesStub({
      NormalizePlayerKey = function(name, realm)
        return (name or "?") .. "@" .. (realm or "?")
      end,
    })
    local c = BuildCtx(rs, modules)
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    Assert.Equal(c.BuildRosterInfoPlayerKey({ name = "Alice", realm = "Draenor" }), "Alice@Draenor")
    Assert.Equal(c.BuildRosterInfoPlayerKey({ name = "Bob" }), "Bob@?", "missing realm forwards as nil")
  end)

  test(
    "factory_controllers: RestoreRioBaseline loads from IsiLiveDB and enables display when snapshot exists",
    function()
      local addon = Load()
      local rs, storage = BuildRuntimeStateStub()
      local c = BuildCtx(rs, BuildModulesStub())
      local db = { rioBaseline = { ["Alice-Draenor"] = 3400 } }
      WithGlobals({ IsiLiveDB = db }, function()
        InitializeHelpers(c, addon)
        storage.hasRioBaselineSnapshot = true
        c.RestoreRioBaseline()
      end)
      Assert.Equal(storage.rioBaselineByKey["Alice-Draenor"], 3400, "baseline must be loaded from DB")
      Assert.Equal(storage.rioDeltaDisplayEnabled, true, "delta display must be enabled when snapshot exists")
    end
  )

  test("factory_controllers: RestoreRioBaseline is a no-op when IsiLiveDB lacks a baseline", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({ IsiLiveDB = {} }, function()
      InitializeHelpers(c, addon)
      c.RestoreRioBaseline()
    end)
    Assert.Equal(storage.rioDeltaDisplayEnabled, false, "no baseline must not enable delta display")
  end)

  test("factory_controllers: ClearRioBaselineSnapshot clears runtimeState and DB", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    local db = { rioBaseline = { ["Alice-Draenor"] = 3400 } }
    WithGlobals({ IsiLiveDB = db }, function()
      InitializeHelpers(c, addon)
      c.ClearRioBaselineSnapshot()
    end)
    Assert.Equal(storage.rioBaselineClears, 1, "runtimeState.ClearRioBaseline must be called once")
    Assert.Nil(db.rioBaseline, "DB rioBaseline field must be cleared")
  end)

  test("factory_controllers: CaptureRioBaselineSnapshot snapshots the current roster by player key", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    storage.roster = {
      player = { name = "Alice", realm = "Draenor", rio = 3400 },
      party1 = { name = "Bob", realm = "Draenor", rio = 2800 },
    }
    local c = BuildCtx(rs, BuildModulesStub())
    local db = {}
    WithGlobals({ IsiLiveDB = db }, function()
      InitializeHelpers(c, addon)
      c.CaptureRioBaselineSnapshot()
    end)
    Assert.Equal(storage.rioBaselineByKey["Alice-Draenor"], 3400, "Alice baseline must be captured")
    Assert.Equal(storage.rioBaselineByKey["Bob-Draenor"], 2800, "Bob baseline must be captured")
    Assert.Equal(storage.hasRioBaselineSnapshot, true, "has-snapshot flag must be true after capture")
    Assert.Equal(storage.rioDeltaDisplayEnabled, false, "delta display must still be disabled right after capture")
    Assert.Equal(db.rioBaseline["Alice-Draenor"], 3400, "DB baseline must mirror the runtime snapshot")
  end)

  test("factory_controllers: CaptureRioBaselineSnapshot falls back to GetUnitRio when roster info lacks rio", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    storage.roster = {
      player = { name = "Alice", realm = "Draenor" },
    }
    local c = BuildCtx(rs, BuildModulesStub(), {
      GetUnitRio = function(unit)
        if unit == "player" then
          return 3400
        end
      end,
    })
    WithGlobals({ IsiLiveDB = nil }, function()
      InitializeHelpers(c, addon)
      c.CaptureRioBaselineSnapshot()
    end)
    Assert.Equal(
      storage.rioBaselineByKey["Alice-Draenor"],
      3400,
      "GetUnitRio fallback must populate the baseline when info.rio is missing"
    )
  end)

  test("factory_controllers: CaptureRioBaselineSnapshot floors fractional rio values", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    storage.roster = {
      player = { name = "Alice", realm = "Draenor", rio = 3400.7 },
    }
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
      c.CaptureRioBaselineSnapshot()
    end)
    Assert.Equal(storage.rioBaselineByKey["Alice-Draenor"], 3400, "fractional rio must be floored")
  end)

  test("factory_controllers: EnableRioDeltaDisplay skips when no snapshot exists", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
      c.EnableRioDeltaDisplay()
    end)
    Assert.Equal(storage.rioDeltaDisplayEnabled, false, "without a snapshot the display must stay disabled")
  end)

  test("factory_controllers: EnableRioDeltaDisplay enables when snapshot is present", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    storage.hasRioBaselineSnapshot = true
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
      c.EnableRioDeltaDisplay()
    end)
    Assert.Equal(storage.rioDeltaDisplayEnabled, true, "snapshot present must enable the display")
  end)

  test("factory_controllers: GetRioDeltaForRosterInfo returns nil without baseline snapshot", function()
    local addon = Load()
    local rs = BuildRuntimeStateStub()
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    Assert.Nil(c.GetRioDeltaForRosterInfo({ name = "Alice", rio = 3500 }), "no baseline => nil delta")
  end)

  test("factory_controllers: GetRioDeltaForRosterInfo returns nil when delta display is disabled", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    storage.hasRioBaselineSnapshot = true
    storage.rioBaselineByKey = { ["Alice-Draenor"] = 3400 }
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    Assert.Nil(
      c.GetRioDeltaForRosterInfo({ name = "Alice", realm = "Draenor", rio = 3500 }),
      "display disabled => nil delta"
    )
  end)

  test("factory_controllers: GetRioDeltaForRosterInfo returns positive delta when rio grew", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    storage.hasRioBaselineSnapshot = true
    storage.rioDeltaDisplayEnabled = true
    storage.rioBaselineByKey = { ["Alice-Draenor"] = 3400 }
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    Assert.Equal(
      c.GetRioDeltaForRosterInfo({ name = "Alice", realm = "Draenor", rio = 3450 }),
      50,
      "positive delta must equal current - baseline"
    )
  end)

  test("factory_controllers: GetRioDeltaForRosterInfo clamps negative delta to zero", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    storage.hasRioBaselineSnapshot = true
    storage.rioDeltaDisplayEnabled = true
    storage.rioBaselineByKey = { ["Alice-Draenor"] = 3400 }
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    Assert.Equal(
      c.GetRioDeltaForRosterInfo({ name = "Alice", realm = "Draenor", rio = 3300 }),
      0,
      "RIO regressions must clamp to 0 (never render a negative delta per RULE-RIO-DELTA-FORMAT)"
    )
  end)

  test("factory_controllers: GetRioDeltaForRosterInfo prefers live GetUnitRio over info.rio", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    storage.hasRioBaselineSnapshot = true
    storage.rioDeltaDisplayEnabled = true
    storage.rioBaselineByKey = { ["Alice-Draenor"] = 3400 }
    local liveRioCalls = 0
    local c = BuildCtx(rs, BuildModulesStub(), {
      GetUnitRio = function(unit)
        liveRioCalls = liveRioCalls + 1
        if unit == "player" then
          return 3500
        end
      end,
    })
    local info = { name = "Alice", realm = "Draenor", rio = 3400 }
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    Assert.Equal(
      c.GetRioDeltaForRosterInfo(info, "player"),
      100,
      "live GetUnitRio (3500) must override info.rio (3400) for the delta computation"
    )
    Assert.Equal(liveRioCalls, 1, "GetUnitRio must be called exactly once per delta lookup with a unit token")
    Assert.Equal(info.rio, 3500, "info.rio must be mutated to the live value for downstream consumers")
  end)

  test("factory_controllers: GetRioDeltaForRosterInfo returns nil when no rio value is available", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    storage.hasRioBaselineSnapshot = true
    storage.rioDeltaDisplayEnabled = true
    storage.rioBaselineByKey = { ["Alice-Draenor"] = 3400 }
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    Assert.Nil(
      c.GetRioDeltaForRosterInfo({ name = "Alice", realm = "Draenor" }),
      "missing info.rio and no live fallback must resolve to nil"
    )
  end)

  test("factory_controllers: GetRioDeltaForRosterInfo returns nil when baseline has no entry for the key", function()
    local addon = Load()
    local rs, storage = BuildRuntimeStateStub()
    storage.hasRioBaselineSnapshot = true
    storage.rioDeltaDisplayEnabled = true
    storage.rioBaselineByKey = { ["Bob-Draenor"] = 2800 }
    local c = BuildCtx(rs, BuildModulesStub())
    WithGlobals({}, function()
      InitializeHelpers(c, addon)
    end)
    Assert.Nil(
      c.GetRioDeltaForRosterInfo({ name = "Alice", realm = "Draenor", rio = 3500 }),
      "missing baseline key must resolve to nil"
    )
  end)

  -- =====================================================
  -- Accepted-Invite Center-Notice helpers (FI exports)
  -- Covers the four module-local helpers (RoleName, DungeonName,
  -- BuildFields, Render) that wire the post-accept rich center notice
  -- in InitializeFactoryPrimaryControllers.
  -- =====================================================

  local function BuildAcceptedInviteCtx(overrides)
    overrides = overrides or {}
    return {
      GetL = overrides.GetL or function()
        return {
          ROLE_NAME_TANK = "Tank-DE",
          ROLE_NAME_HEALER = "Heal-DE",
          ROLE_NAME_DAMAGE = "DD-DE",
          INVITE_HINT_UNKNOWN_DUNGEON = "Unbekannt-DE",
          INVITE_ACCEPTED_NOTICE_HEADLINE_WITH_LEVEL = "%s +%d",
          INVITE_ACCEPTED_NOTICE_HEADLINE_NO_LEVEL = "%s",
          INVITE_ACCEPTED_NOTICE_LABEL_DUNGEON = "Dungeon-DE:",
          INVITE_ACCEPTED_NOTICE_LABEL_GROUP = "Gruppe-DE:",
          INVITE_ACCEPTED_NOTICE_LABEL_DESCRIPTION = "Beschr-DE:",
          INVITE_ACCEPTED_NOTICE_LABEL_ROLE = "Rolle-DE:",
          INVITE_ACCEPTED_NOTICE_TITLE = "isiLive - Invite-DE",
          INVITE_ACCEPTED_RAID_NOTICE_TITLE = "isiLive - Raid-Invite-DE",
          INVITE_ACCEPTED_NOTICE_TELEPORT_HEADER = "TP-DE:",
        }
      end,
      GetUnitRole = overrides.GetUnitRole,
      ShowCenterNotice = overrides.ShowCenterNotice,
    }
  end

  test("factory_controllers: ResolveAcceptedInviteRoleName rejects non-string / empty / NONE input", function()
    local addon = Load()
    local resolve = addon._FactoryInternal.ResolveAcceptedInviteRoleName
    local c = BuildAcceptedInviteCtx()
    Assert.Nil(resolve(c, nil), "nil role must resolve to nil")
    Assert.Nil(resolve(c, ""), "empty role must resolve to nil")
    Assert.Nil(resolve(c, "NONE"), "NONE role must resolve to nil")
    Assert.Nil(resolve(c, 42), "non-string role must resolve to nil")
    Assert.Nil(resolve(c, "WHATEVER"), "unknown role must resolve to nil")
  end)

  test("factory_controllers: ResolveAcceptedInviteRoleName maps TANK / HEALER / DAMAGER to locale strings", function()
    local addon = Load()
    local resolve = addon._FactoryInternal.ResolveAcceptedInviteRoleName
    local c = BuildAcceptedInviteCtx()
    Assert.Equal(resolve(c, "TANK"), "Tank-DE", "TANK must resolve to L.ROLE_NAME_TANK")
    Assert.Equal(resolve(c, "HEALER"), "Heal-DE", "HEALER must resolve to L.ROLE_NAME_HEALER")
    Assert.Equal(resolve(c, "DAMAGER"), "DD-DE", "DAMAGER must resolve to L.ROLE_NAME_DAMAGE")
  end)

  test("factory_controllers: ResolveAcceptedInviteRoleName falls back when ctx.GetL is missing", function()
    local addon = Load()
    local resolve = addon._FactoryInternal.ResolveAcceptedInviteRoleName
    local c = { GetL = nil }
    Assert.Nil(resolve(c, "TANK"), "missing locale table must resolve to nil rather than crash")
  end)

  test("factory_controllers: ResolveAcceptedInviteDungeonName uses mapName when present", function()
    local addon = Load()
    local resolve = addon._FactoryInternal.ResolveAcceptedInviteDungeonName
    local c = BuildAcceptedInviteCtx()
    local modules = {
      teleport = {
        GetTeleportInfoByMapID = function(mapID)
          Assert.Equal(mapID, 559, "mapID must be forwarded to the teleport lookup")
          return { mapName = "Halls", name = "FallbackName" }
        end,
      },
    }
    Assert.Equal(resolve(c, modules, 559), "Halls", "mapName must take priority over name")
  end)

  test("factory_controllers: ResolveAcceptedInviteDungeonName falls back to info.name when mapName missing", function()
    local addon = Load()
    local resolve = addon._FactoryInternal.ResolveAcceptedInviteDungeonName
    local c = BuildAcceptedInviteCtx()
    local modules = {
      teleport = {
        GetTeleportInfoByMapID = function()
          return { mapName = "", name = "Backup" }
        end,
      },
    }
    Assert.Equal(resolve(c, modules, 200), "Backup", "name must be used when mapName is blank")
  end)

  test(
    "factory_controllers: ResolveAcceptedInviteDungeonName falls back to locale string on missing teleport / lookup",
    function()
      local addon = Load()
      local resolve = addon._FactoryInternal.ResolveAcceptedInviteDungeonName
      local c = BuildAcceptedInviteCtx()
      Assert.Equal(resolve(c, {}, 200), "Unbekannt-DE", "missing teleport module must fall back to locale string")
      Assert.Equal(
        resolve(c, { teleport = {} }, 200),
        "Unbekannt-DE",
        "missing GetTeleportInfoByMapID must fall back to locale string"
      )
      local modules = {
        teleport = {
          GetTeleportInfoByMapID = function()
            return nil
          end,
        },
      }
      Assert.Equal(resolve(c, modules, 200), "Unbekannt-DE", "nil info must fall back to locale string")
      Assert.Equal(resolve(c, modules, nil), "Unbekannt-DE", "nil mapID must fall back to locale string")
      local emptyStrings = {
        teleport = {
          GetTeleportInfoByMapID = function()
            return { mapName = "", name = "" }
          end,
        },
      }
      Assert.Equal(resolve(c, emptyStrings, 200), "Unbekannt-DE", "blank mapName + name must fall back")
    end
  )

  test(
    "factory_controllers: ResolveAcceptedInviteDungeonName uses hardcoded fallback when locale lacks the key",
    function()
      local addon = Load()
      local resolve = addon._FactoryInternal.ResolveAcceptedInviteDungeonName
      local c = {
        GetL = function()
          return {}
        end,
      }
      Assert.Equal(
        resolve(c, {}, 200),
        "Unknown dungeon",
        "missing INVITE_HINT_UNKNOWN_DUNGEON must use english fallback"
      )
    end
  )

  test("factory_controllers: BuildAcceptedInviteFields renders dungeon row with +N when level > 0", function()
    local addon = Load()
    local build = addon._FactoryInternal.BuildAcceptedInviteFields
    local c = BuildAcceptedInviteCtx({
      GetUnitRole = function(unit)
        Assert.Equal(unit, "player", "unit must always be 'player' for the local role lookup")
        return "TANK"
      end,
    })
    local fields = build(c, "MyDungeon", { level = 10, groupName = "Crew", comment = "Pls timer" })
    Assert.Equal(#fields, 4, "must render dungeon + group + description + role rows")
    Assert.Equal(fields[1].label, "Dungeon-DE:", "row 1 must be the dungeon label")
    Assert.Equal(fields[1].value, "MyDungeon +10", "row 1 must render +N from the level")
    Assert.Equal(fields[2].label, "Gruppe-DE:", "row 2 must be the group label")
    Assert.Equal(fields[2].value, "Crew", "row 2 must echo the group name")
    Assert.Equal(fields[3].label, "Beschr-DE:", "row 3 must be the description label")
    Assert.Equal(fields[3].value, "Pls timer", "row 3 must echo the comment")
    Assert.Equal(fields[4].label, "Rolle-DE:", "row 4 must be the role label")
    Assert.Equal(fields[4].value, "Tank-DE", "row 4 must render the resolved role name")
  end)

  test("factory_controllers: BuildAcceptedInviteFields drops level suffix when level is nil or non-positive", function()
    local addon = Load()
    local build = addon._FactoryInternal.BuildAcceptedInviteFields
    local c = BuildAcceptedInviteCtx()

    local fieldsNoLevel = build(c, "MyDungeon", {})
    Assert.Equal(fieldsNoLevel[1].value, "MyDungeon", "missing level must render dungeon name without +N")

    local fieldsZero = build(c, "MyDungeon", { level = 0 })
    Assert.Equal(fieldsZero[1].value, "MyDungeon", "level=0 must render dungeon name without +N")

    local fieldsNeg = build(c, "MyDungeon", { level = -5 })
    Assert.Equal(fieldsNeg[1].value, "MyDungeon", "negative level must render dungeon name without +N")
  end)

  test("factory_controllers: BuildAcceptedInviteFields omits optional rows when their source is missing", function()
    local addon = Load()
    local build = addon._FactoryInternal.BuildAcceptedInviteFields
    local c = BuildAcceptedInviteCtx({
      GetUnitRole = function()
        return "NONE"
      end,
    })

    local fields = build(c, "MyDungeon", { level = 5 })
    Assert.Equal(#fields, 1, "no group + no comment + NONE role must leave only the dungeon row")
    Assert.Equal(fields[1].label, "Dungeon-DE:", "the dungeon row must always be present")

    -- empty / non-string group + comment must be dropped (string guard)
    local fieldsEmpty = build(c, "MyDungeon", { level = 5, groupName = "", comment = "" })
    Assert.Equal(#fieldsEmpty, 1, "blank optional strings must be treated as missing")

    local fieldsBadType = build(c, "MyDungeon", { level = 5, groupName = 42, comment = false })
    Assert.Equal(#fieldsBadType, 1, "non-string optional values must be dropped")
  end)

  test(
    "factory_controllers: BuildAcceptedInviteFields uses hardcoded label fallbacks when locale lacks keys",
    function()
      local addon = Load()
      local build = addon._FactoryInternal.BuildAcceptedInviteFields
      local c = {
        GetL = function()
          return {}
        end,
        GetUnitRole = function()
          return "TANK"
        end,
      }
      local fields = build(c, "Dun", { level = 7, groupName = "G", comment = "C" })
      -- ResolveAcceptedInviteRoleName returns nil when L.ROLE_NAME_TANK is
      -- missing, so the role row is dropped — only dungeon + group +
      -- description remain. The english fallback for the role label is
      -- never reached on an empty locale table; that branch is exercised
      -- when the locale only lacks the label keys, not the role names.
      Assert.Equal(#fields, 3, "missing role-name keys drop the role row")
      Assert.Equal(fields[1].label, "Dungeon:", "missing dungeon label key must fall back to english")
      Assert.Equal(fields[1].value, "Dun +7", "missing headline template must fall back to english")
      Assert.Equal(fields[2].label, "Group:", "missing group label key must fall back to english")
      Assert.Equal(fields[3].label, "Description:", "missing description label key must fall back to english")
    end
  )

  test("factory_controllers: RenderAcceptedInviteNotice is a no-op for non-table payload", function()
    local addon = Load()
    local render = addon._FactoryInternal.RenderAcceptedInviteNotice
    local called = false
    local c = BuildAcceptedInviteCtx({
      ShowCenterNotice = function()
        called = true
      end,
    })
    render(c, {}, nil)
    render(c, {}, "string-payload")
    render(c, {}, 42)
    Assert.Equal(called, false, "ShowCenterNotice must not fire for invalid payloads")
  end)

  test("factory_controllers: RenderAcceptedInviteNotice is a no-op when ShowCenterNotice is missing", function()
    local addon = Load()
    local render = addon._FactoryInternal.RenderAcceptedInviteNotice
    local c = BuildAcceptedInviteCtx()
    -- Should not crash even though ShowCenterNotice is absent.
    render(c, {}, { mapID = 200, level = 5 })
  end)

  test("factory_controllers: RenderAcceptedInviteNotice forwards a populated payload to ShowCenterNotice", function()
    local addon = Load()
    local render = addon._FactoryInternal.RenderAcceptedInviteNotice
    local captured
    local c = BuildAcceptedInviteCtx({
      GetUnitRole = function()
        return "HEALER"
      end,
      ShowCenterNotice = function(unit, holdTime, mapName, activityID, opts)
        captured = {
          unit = unit,
          holdTime = holdTime,
          mapName = mapName,
          activityID = activityID,
          opts = opts,
        }
      end,
    })
    local modules = {
      teleport = {
        GetTeleportInfoByMapID = function(mapID)
          Assert.Equal(mapID, 559, "mapID must be forwarded to the teleport lookup")
          return { mapName = "Halls" }
        end,
      },
    }
    render(c, modules, {
      mapID = 559,
      activityID = 1234,
      level = 12,
      groupName = "Crew",
      comment = "Pls timer",
    })
    Assert.NotNil(captured, "ShowCenterNotice must be invoked once")
    Assert.Equal(captured.unit, nil, "ShowCenterNotice unit arg must be nil (center notice)")
    Assert.Nil(captured.holdTime, "ShowCenterNotice hold time must be nil (persistent until right-click)")
    Assert.True(captured.opts.persistent == true, "opts.persistent must be true (no auto-hide)")
    Assert.Equal(captured.mapName, "Halls", "mapName arg must configure the embedded notice teleport button")
    Assert.Equal(captured.activityID, 1234, "activityID arg must configure the embedded notice teleport button")
    Assert.Equal(captured.opts.teleportMapID, 559, "verified mapID must configure the embedded notice portal")
    Assert.Equal(captured.opts.title, "isiLive - Invite-DE", "opts.title must come from the locale table")
    Assert.Equal(captured.opts.teleportLabel, "TP-DE:", "opts.teleportLabel must come from the locale table")
    Assert.Equal(captured.opts.frameWidth, 540, "opts.frameWidth must be the compact 540px card width")
    Assert.Equal(#captured.opts.fields, 4, "opts.fields must contain dungeon + group + comment + role rows")
    Assert.Equal(captured.opts.fields[1].value, "Halls +12", "dungeon row must carry the resolved mapName + level")
    Assert.Equal(captured.opts.fields[4].value, "Heal-DE", "role row must reflect HEALER -> ROLE_NAME_HEALER")
  end)

  test("factory_controllers: RenderAcceptedInviteNotice uses verified mapID when activityID is missing", function()
    local addon = Load()
    local render = addon._FactoryInternal.RenderAcceptedInviteNotice
    local captured
    local c = BuildAcceptedInviteCtx({
      ShowCenterNotice = function(_unit, _holdTime, mapName, activityID, opts)
        captured = {
          mapName = mapName,
          activityID = activityID,
          opts = opts,
        }
      end,
    })
    local modules = {
      teleport = {
        GetTeleportInfoByMapID = function()
          return { mapName = "Halls" }
        end,
      },
    }

    render(c, modules, { mapID = 559, level = 12 })

    Assert.NotNil(captured, "ShowCenterNotice must still render the accepted-invite info card")
    Assert.Equal(captured.mapName, "Halls", "verified mapID may forward dungeonName into teleport configuration")
    Assert.Nil(captured.activityID, "missing activityID must remain unresolved")
    Assert.Equal(captured.opts.teleportMapID, 559, "verified mapID must configure the teleport resolver")
    Assert.Equal(captured.opts.teleportLabel, "TP-DE:", "verified mapID should render the teleport header")
  end)

  test("factory_controllers: direct-push persists accepted target for killtracker refresh", function()
    local addon = Load()
    local handle = addon._FactoryInternal.HandleTargetDungeonChatPayload
    local latestQueue
    local announced
    local refreshes = 0
    local c = BuildAcceptedInviteCtx({
      GetL = function()
        return {
          INVITE_HINT_UNKNOWN_DUNGEON = "Unbekannt-DE",
        }
      end,
    })
    c.runtimeState = {
      SetLatestQueueState = function(dungeonName, activityID, teleportSpellID, mapID)
        latestQueue = {
          dungeonName = dungeonName,
          activityID = activityID,
          teleportSpellID = teleportSpellID,
          mapID = mapID,
        }
      end,
    }
    c.rosterPanelController = {
      RefreshKillTrackRow = function()
        refreshes = refreshes + 1
      end,
    }
    local modules = {
      teleport = {
        GetTeleportInfoByMapID = function(mapID)
          Assert.Equal(mapID, 2688, "direct-push must resolve the accepted mapID")
          return { mapName = "Nexuspunkt Xenas" }
        end,
      },
    }
    local statusController = {
      AnnounceTargetDungeonFromPayload = function(payload)
        announced = payload
      end,
    }

    handle(c, modules, statusController, {
      mapID = 2688,
      activityID = 1768,
      level = 14,
      groupName = "+14 Kompetitiv",
      searchResultID = 605,
    })

    Assert.NotNil(latestQueue, "direct-push must persist the accepted target for status consumers")
    Assert.Equal(latestQueue.dungeonName, "Nexuspunkt Xenas", "killtracker source must receive the resolved dungeon")
    Assert.Equal(latestQueue.activityID, 1768, "accepted activityID must stay attached to the target")
    Assert.Nil(latestQueue.teleportSpellID, "direct-push must not invent a teleport spellID")
    Assert.Equal(latestQueue.mapID, 2688, "accepted mapID must stay attached to the target")
    Assert.Equal(announced.name, "Nexuspunkt Xenas", "chat announce must use the same accepted dungeon")
    Assert.Equal(announced.level, 14, "chat announce must use the accepted level")
    Assert.Equal(refreshes, 1, "killtracker must refresh after the accepted target is persisted")
  end)

  -- =====================================================
  -- Raid invite-accept notice (0.9.237). Mirrors the M+ tests above but pins
  -- the Raid-specific surface: no "+N" headline, no teleport-button wiring,
  -- separate title key, otherwise identical Center Notice layout.
  -- =====================================================

  test("factory_controllers: BuildAcceptedRaidInviteFields renders dungeon row WITHOUT level suffix", function()
    local addon = Load()
    local build = addon._FactoryInternal.BuildAcceptedRaidInviteFields
    local c = BuildAcceptedInviteCtx({
      GetUnitRole = function(unit)
        Assert.Equal(unit, "player", "unit must always be 'player' for the local role lookup")
        return "HEALER"
      end,
    })
    -- Raid payload deliberately has no level / activityID; the build helper
    -- must not synthesise a "+N" even if the payload tried to inject one.
    local fields = build(c, "Manaforge Omega", { groupName = "AOTC", comment = "exp only" })
    Assert.Equal(#fields, 4, "must render dungeon + group + description + role rows")
    Assert.Equal(fields[1].label, "Dungeon-DE:", "row 1 must be the dungeon label")
    Assert.Equal(fields[1].value, "Manaforge Omega", "row 1 must render the raid name without +N suffix")
    Assert.Equal(fields[2].label, "Gruppe-DE:", "row 2 must be the group label")
    Assert.Equal(fields[2].value, "AOTC", "row 2 must echo the group name")
    Assert.Equal(fields[3].label, "Beschr-DE:", "row 3 must be the description label")
    Assert.Equal(fields[3].value, "exp only", "row 3 must echo the comment")
    Assert.Equal(fields[4].label, "Rolle-DE:", "row 4 must be the role label")
    Assert.Equal(fields[4].value, "Heal-DE", "row 4 must render the resolved role name")
  end)

  test("factory_controllers: BuildAcceptedRaidInviteFields ignores a stray level on the payload", function()
    local addon = Load()
    local build = addon._FactoryInternal.BuildAcceptedRaidInviteFields
    local c = BuildAcceptedInviteCtx()
    -- Defensive: even if a future resolver leaks a level onto the Raid
    -- payload, the renderer must keep the dungeon row level-less.
    local fields = build(c, "Manaforge Omega", { level = 99 })
    Assert.Equal(fields[1].value, "Manaforge Omega", "stray payload.level must be ignored")
  end)

  test("factory_controllers: BuildAcceptedRaidInviteFields drops optional rows when sources are missing", function()
    local addon = Load()
    local build = addon._FactoryInternal.BuildAcceptedRaidInviteFields
    local c = BuildAcceptedInviteCtx({
      GetUnitRole = function()
        return "NONE"
      end,
    })

    local fields = build(c, "Manaforge Omega", {})
    Assert.Equal(#fields, 1, "no group + no comment + NONE role must leave only the dungeon row")
    Assert.Equal(fields[1].label, "Dungeon-DE:", "the dungeon row must always be present")

    local fieldsEmpty = build(c, "Manaforge Omega", { groupName = "", comment = "" })
    Assert.Equal(#fieldsEmpty, 1, "blank optional strings must be treated as missing")
  end)

  test("factory_controllers: RenderAcceptedRaidInviteNotice is a no-op for non-table payload", function()
    local addon = Load()
    local render = addon._FactoryInternal.RenderAcceptedRaidInviteNotice
    local called = false
    local c = BuildAcceptedInviteCtx({
      ShowCenterNotice = function()
        called = true
      end,
    })
    render(c, {}, nil)
    render(c, {}, "string-payload")
    render(c, {}, 42)
    Assert.Equal(called, false, "ShowCenterNotice must not fire for invalid Raid payloads")
  end)

  test("factory_controllers: RenderAcceptedRaidInviteNotice is a no-op when ShowCenterNotice is missing", function()
    local addon = Load()
    local render = addon._FactoryInternal.RenderAcceptedRaidInviteNotice
    local c = BuildAcceptedInviteCtx()
    -- ctx without ShowCenterNotice must not crash.
    render(c, {}, { mapID = 2657 })
  end)

  test(
    "factory_controllers: RenderAcceptedRaidInviteNotice forwards payload + raid title to ShowCenterNotice",
    function()
      local addon = Load()
      local render = addon._FactoryInternal.RenderAcceptedRaidInviteNotice
      local captured
      local c = BuildAcceptedInviteCtx({
        GetUnitRole = function()
          return "TANK"
        end,
        ShowCenterNotice = function(unit, holdTime, mapName, activityID, opts)
          captured = {
            unit = unit,
            holdTime = holdTime,
            mapName = mapName,
            activityID = activityID,
            opts = opts,
          }
        end,
      })
      local modules = {
        teleport = {
          GetTeleportInfoByMapID = function(mapID)
            Assert.Equal(mapID, 2657, "mapID must be forwarded to the teleport lookup")
            return { mapName = "Manaforge Omega" }
          end,
        },
      }
      render(c, modules, {
        mapID = 2657,
        leaderName = "RaidLead",
        groupName = "AOTC Manaforge",
        comment = "exp only",
        searchResultID = 801,
      })
      Assert.NotNil(captured, "ShowCenterNotice must be invoked once")
      Assert.Nil(captured.unit, "first arg must be nil (Raid notice has no chat message)")
      Assert.Nil(captured.holdTime, "hold time must be nil (persistent until close)")
      Assert.Nil(captured.mapName, "mapName arg must be nil so no teleport button renders")
      Assert.Nil(captured.activityID, "activityID arg must be nil so no teleport button renders")
      Assert.Equal(captured.opts.title, "isiLive - Raid-Invite-DE", "opts.title must use the Raid-specific locale key")
      Assert.Equal(captured.opts.persistent, true, "opts.persistent must be true (no auto-hide)")
      Assert.Equal(captured.opts.frameWidth, 540, "opts.frameWidth must match the compact 540px card width")
      Assert.Equal(#captured.opts.fields, 4, "opts.fields must contain dungeon + group + comment + role rows")
      Assert.Equal(captured.opts.fields[1].value, "Manaforge Omega", "dungeon row must NOT carry a +N suffix")
      Assert.Equal(captured.opts.fields[4].value, "Tank-DE", "role row must reflect TANK -> ROLE_NAME_TANK")
    end
  )
end
