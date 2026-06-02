---@diagnostic disable: undefined-global

-- Scenarios for factory/isiLive_factory_frame_bridge.lua.
-- This file exports three entry points:
--   1. FI.BuildFactoryModules(tbl)        - pure table-mapping helper
--   2. FI.CreateFactoryContext(name, tbl) - composition root, heavy deps
--   3. FI.InitializeFactoryFrameBridge(ctx) - UI-bridge wiring
-- The scenarios here exercise the mapping + the early-exit / pure-function
-- surfaces and a happy-path CreateFactoryContext run using stubbed
-- modules. InitializeFactoryFrameBridge is left to a later pass because
-- it drags in the notice/ui/frameBridge module surfaces.

-- `false` in an override slot means "omit this module entirely" so we can
-- exercise the CreateFactoryContext early-exit path for missing Guards;
-- `nil` would be swallowed by pairs() during merging. Any table value is
-- used as-is.
local function ResolveOverride(value, default)
  if value == false then
    return nil
  end
  if value ~= nil then
    return value
  end
  return default
end

local function BuildMinimalAddonTable(overrides)
  overrides = overrides or {}
  local tbl = {
    Guards = ResolveOverride(overrides.Guards, {
      Validate = function(_t)
        return true
      end,
    }),
    Texts = overrides.Texts or {
      GetLocaleTables = function()
        return {
          enUS = { greeting = "hi" },
          deDE = { greeting = "hallo" },
        }
      end,
    },
    ContextHelpers = overrides.ContextHelpers or {
      GetAddonVersionRaw = function(_name)
        return "0.9.180"
      end,
      CreateRealmInfoGetter = function()
        return function()
          return {}
        end
      end,
      GetUnitServerLanguage = function(_locale, _getter, _unit, _realm)
        return "en"
      end,
      BuildDummyRoster = function(_opts)
        return {}
      end,
    },
    RuntimeLog = overrides.RuntimeLog or {
      CreateController = function(_opts)
        return {
          Log = function() end,
          Logf = function() end,
        }
      end,
    },
    TraceChatFrame = overrides.TraceChatFrame or {
      CreateController = function()
        return {}
      end,
    },
    QueueDebug = overrides.QueueDebug or {
      CreateController = function(_opts)
        return {
          Log = function() end,
        }
      end,
    },
    Queue = overrides.Queue or {
      SetDebugLogger = function(_fn) end,
      SetDebugEnabled = function(_b) end,
      IsDebugEnabled = function()
        return false
      end,
    },
    RuntimeState = overrides.RuntimeState or {
      CreateController = function()
        return {
          IsTestAllMode = function()
            return false
          end,
          SetRoster = function(_r) end,
        }
      end,
    },
    SpellUtils = overrides.SpellUtils or {
      GetSpellCooldownSafe = function() end,
      ApplyCooldownFrameSafe = function() end,
      IsSpellKnownSafe = function()
        return false
      end,
      GetTeleportCooldownRemaining = function()
        return 0
      end,
      FormatCooldownSeconds = function()
        return ""
      end,
    },
    EventUtils = overrides.EventUtils or {
      IsNegativeApplicationStatusEvent = function()
        return false
      end,
    },
    Units = overrides.Units or {
      GetUnitRole = function()
        return "NONE"
      end,
      GetUnitClass = function()
        return nil, nil
      end,
      TruncateName = function(n)
        return n
      end,
      GetUnitNameAndRealm = function()
        return nil, nil
      end,
      GetPlayerSpecName = function()
        return nil
      end,
      GetInspectSpecName = function()
        return nil
      end,
      GetShortSpecLabel = function()
        return nil
      end,
      GetUnitRio = function()
        return nil
      end,
    },
    Locale = overrides.Locale or {
      GetLanguageTooltipMarkup = function()
        return ""
      end,
    },
    Demo = overrides.Demo or {
      BuildDummyRoster = function()
        return {}
      end,
    },
  }
  return tbl
end

-- Resolve an override slot: `false` means "drop this stub entirely" (used
-- to exercise the `type(X) ~= "function"` branches), any non-nil value is
-- taken as-is, and a missing override falls back to the default stub.
local function ResolveStub(override, default)
  if override == false then
    return nil
  end
  if override ~= nil then
    return override
  end
  return default
end

local function BuildDefaultGlobals(overrides)
  overrides = overrides or {}
  local prints = {}
  local globals = {
    GetLocale = function()
      return "enUS"
    end,
    IsiLiveDB = ResolveStub(overrides.IsiLiveDB, {}),
    IsInGroup = ResolveStub(overrides.IsInGroup, function()
      return false
    end),
    UnitIsGroupLeader = ResolveStub(overrides.UnitIsGroupLeader, function()
      return false
    end),
    UnitExists = ResolveStub(overrides.UnitExists, function()
      return false
    end),
    GetNumGroupMembers = ResolveStub(overrides.GetNumGroupMembers, function()
      return 0
    end),
    IsInRaid = ResolveStub(overrides.IsInRaid, function()
      return false
    end),
    GetSubZoneText = ResolveStub(overrides.GetSubZoneText, function()
      return ""
    end),
    GetZoneText = ResolveStub(overrides.GetZoneText, function()
      return ""
    end),
    GetRealZoneText = ResolveStub(overrides.GetRealZoneText, function()
      return ""
    end),
    C_Map = ResolveStub(overrides.C_Map, {
      GetBestMapForUnit = function()
        return nil
      end,
      GetMapInfo = function()
        return nil
      end,
    }),
    print = function(msg)
      prints[#prints + 1] = tostring(msg)
    end,
    InCombatLockdown = function()
      return false
    end,
  }
  if overrides.globals then
    for k, v in pairs(overrides.globals) do
      globals[k] = v
    end
  end
  return globals, prints
end

-- Helper: run `callback(factoryCtx, prints)` inside a with_globals block so
-- that factoryCtx.IsRaidGroup / GetNumGroupMembers / GetPlayerMapID etc.
-- still see the stubbed WoW globals at call time.
local function WithContext(ctx, globalsOverrides, addonTableOverrides, callback)
  local globals, prints = BuildDefaultGlobals(globalsOverrides)
  ctx.with_globals(globals, function()
    local addonTable = ctx.load_modules({ "isiLive_factory_frame_bridge.lua" })
    local tbl = BuildMinimalAddonTable(addonTableOverrides)
    local factoryCtx = addonTable._FactoryInternal.CreateFactoryContext("isiLive", tbl)
    callback(factoryCtx, prints)
  end)
end

local function Register(test, ctx)
  local Assert = ctx.assert

  -- ===========================================================
  -- BuildFactoryModules: pure table mapping
  -- ===========================================================

  test("factory_frame_bridge: BuildFactoryModules returns nil fields for an empty table", function()
    local addonTable
    ctx.with_globals({
      GetLocale = function()
        return "enUS"
      end,
    }, function()
      addonTable = ctx.load_modules({ "isiLive_factory_frame_bridge.lua" })
    end)
    local modules = addonTable._FactoryInternal.BuildFactoryModules({})
    Assert.Nil(modules.sync, "sync must be nil for empty input")
    Assert.Nil(modules.ui, "ui must be nil for empty input")
    Assert.Nil(modules.settingsPanel, "settingsPanel must be nil for empty input")
  end)

  test("factory_frame_bridge: BuildFactoryModules maps well-known keys when provided", function()
    local addonTable
    ctx.with_globals({
      GetLocale = function()
        return "enUS"
      end,
    }, function()
      addonTable = ctx.load_modules({ "isiLive_factory_frame_bridge.lua" })
    end)
    local sentinelSync = { tag = "sync-sentinel" }
    local sentinelUI = { tag = "ui-sentinel" }
    local modules = addonTable._FactoryInternal.BuildFactoryModules({
      Sync = sentinelSync,
      UI = sentinelUI,
      Guards = { tag = "guards" },
    })
    Assert.Equal(modules.sync, sentinelSync, "sync must receive the Sync table reference")
    Assert.Equal(modules.ui, sentinelUI, "ui must receive the UI table reference")
    Assert.Equal(modules.guards.tag, "guards", "guards field must propagate table content")
  end)

  test("factory_frame_bridge: BuildFactoryModules accepts nil input without error", function()
    local addonTable
    ctx.with_globals({
      GetLocale = function()
        return "enUS"
      end,
    }, function()
      addonTable = ctx.load_modules({ "isiLive_factory_frame_bridge.lua" })
    end)
    local modules = addonTable._FactoryInternal.BuildFactoryModules(nil)
    Assert.NotNil(modules, "BuildFactoryModules must return a table even for nil input")
    Assert.Nil(modules.sync, "sync must be nil for nil input")
  end)

  -- ===========================================================
  -- CreateFactoryContext: early-exit guards
  -- ===========================================================

  test("factory_frame_bridge: CreateFactoryContext returns nil when Guards module is absent", function()
    local globals, prints = BuildDefaultGlobals()
    local addonTable
    local result
    ctx.with_globals(globals, function()
      addonTable = ctx.load_modules({ "isiLive_factory_frame_bridge.lua" })
      -- `false` sentinel drops Guards entirely so the early-exit warning fires.
      local tbl = BuildMinimalAddonTable({ Guards = false })
      result = addonTable._FactoryInternal.CreateFactoryContext("isiLive", tbl)
    end)
    Assert.Nil(result, "must short-circuit to nil when Guards is missing")
    local foundWarning = false
    for _, line in ipairs(prints) do
      if string.find(line, "missing module Guards", 1, true) then
        foundWarning = true
        break
      end
    end
    Assert.True(foundWarning, "must emit a user-visible warning when Guards is missing")
  end)

  test("factory_frame_bridge: CreateFactoryContext returns nil when Guards.Validate raises", function()
    local globals, prints = BuildDefaultGlobals()
    local addonTable
    local result
    ctx.with_globals(globals, function()
      addonTable = ctx.load_modules({ "isiLive_factory_frame_bridge.lua" })
      local tbl = BuildMinimalAddonTable({
        Guards = {
          Validate = function(_t)
            error("guards-validation-bang", 0)
          end,
        },
      })
      result = addonTable._FactoryInternal.CreateFactoryContext("isiLive", tbl)
    end)
    Assert.Nil(result, "must short-circuit to nil when Guards.Validate raises")
    local foundError = false
    for _, line in ipairs(prints) do
      if string.find(line, "guards-validation-bang", 1, true) then
        foundError = true
        break
      end
    end
    Assert.True(foundError, "must surface the guards-validation error to the print channel")
  end)

  test("factory_frame_bridge: CreateFactoryContext returns nil when Guards.Validate is not a function", function()
    local globals = BuildDefaultGlobals()
    local addonTable
    local result
    ctx.with_globals(globals, function()
      addonTable = ctx.load_modules({ "isiLive_factory_frame_bridge.lua" })
      local tbl = BuildMinimalAddonTable({ Guards = { Validate = "not-a-function" } })
      result = addonTable._FactoryInternal.CreateFactoryContext("isiLive", tbl)
    end)
    Assert.Nil(result, "Guards.Validate must actually be a callable function")
  end)

  -- ===========================================================
  -- CreateFactoryContext: happy path
  -- ===========================================================

  test("factory_frame_bridge: CreateFactoryContext happy path populates helper fields", function()
    local globals = BuildDefaultGlobals()
    local addonTable
    local factoryCtx
    ctx.with_globals(globals, function()
      addonTable = ctx.load_modules({ "isiLive_factory_frame_bridge.lua" })
      factoryCtx = addonTable._FactoryInternal.CreateFactoryContext("isiLive", BuildMinimalAddonTable())
    end)
    Assert.NotNil(factoryCtx, "context must be returned for a valid addon table")
    Assert.Equal(factoryCtx.addonName, "isiLive", "addonName must be recorded")
    Assert.Equal(factoryCtx.INSPECT_TIMEOUT, 2, "static INSPECT_TIMEOUT constant must be set")
    Assert.Equal(factoryCtx.MIN_FRAME_HEIGHT, 236, "static MIN_FRAME_HEIGHT constant must be set")
    Assert.NotNil(factoryCtx.runtimeLogController, "runtime log controller must be created")
    Assert.NotNil(factoryCtx.queueDebugController, "queue debug controller must be created")
    Assert.NotNil(factoryCtx.runtimeState, "runtime state controller must be attached")
    Assert.NotNil(factoryCtx.L, "default locale table must be attached")
    Assert.Equal(factoryCtx.locales.enUS.greeting, "hi", "locale tables must be exposed")
  end)

  test("factory_frame_bridge: CreateFactoryContext exposes live IsInGroup for ready sound gates", function()
    local inGroup = false
    local globals = BuildDefaultGlobals({
      IsInGroup = function()
        return inGroup
      end,
    })
    local addonTable
    local factoryCtx
    ctx.with_globals(globals, function()
      addonTable = ctx.load_modules({ "isiLive_factory_frame_bridge.lua" })
      factoryCtx = addonTable._FactoryInternal.CreateFactoryContext("isiLive", BuildMinimalAddonTable())
      factoryCtx = Assert.NotNil(factoryCtx, "context must be returned for a valid addon table")

      Assert.Equal(factoryCtx.isInGroup(), false, "ready sound gate must see the initial solo state")
      inGroup = true
      Assert.Equal(factoryCtx.isInGroup(), true, "ready sound gate must read the current group state live")
    end)
  end)

  test("factory_frame_bridge: GetL returns the currently assigned locale table", function()
    local globals = BuildDefaultGlobals()
    local addonTable
    local factoryCtx
    ctx.with_globals(globals, function()
      addonTable = ctx.load_modules({ "isiLive_factory_frame_bridge.lua" })
      factoryCtx = addonTable._FactoryInternal.CreateFactoryContext("isiLive", BuildMinimalAddonTable())
    end)
    Assert.Equal(factoryCtx.GetL(), factoryCtx.L, "GetL must return the attached locale reference")
  end)

  test("factory_frame_bridge: Initialize forwards map teleport resolver to center notice", function()
    local globals = BuildDefaultGlobals({
      globals = {
        UIParent = {},
      },
    })
    local addonTable
    local capturedOpts
    local mapResolver = function(mapID)
      return mapID == 559 and 1254563 or nil
    end

    ctx.with_globals(globals, function()
      addonTable = ctx.load_modules({ "isiLive_factory_frame_bridge.lua" })
      local factoryCtx = {
        modules = {
          contextHelpers = {},
          teleport = {
            ResolveTeleportSpellIDByActivityID = function() end,
            ResolveTeleportSpellIDByMapID = mapResolver,
            ResolveMapIDByActivityID = function() end,
            ResolveMapIDBySpellID = function() end,
            ResolveTeleportSpellID = function() end,
            GetDungeonName = function() end,
            ApplySecureSpellToButton = function() end,
          },
          notice = {
            CreatePortalNavigatorNotice = function()
              return {
                frame = {},
                SetVisible = function() end,
                Show = function() end,
              }
            end,
            CreateCenterNotice = function() end,
          },
          ui = {
            CreateMainFrame = function() end,
          },
          frameBridge = {
            CreateContext = function(opts)
              capturedOpts = opts
              return {
                centerNotice = { Show = function() end },
                centerNoticeFrame = {},
                centerNoticeTeleportButton = {},
                mainUI = {},
                mainFrame = {},
                SetCenterNoticeVisible = function() end,
                UpdateCenterTeleportButtonVisual = function() end,
                ShowCenterNotice = function() end,
                SetMainFrameVisible = function() end,
              }
            end,
          },
        },
        MIN_FRAME_HEIGHT = 236,
        locale = "enUS",
        GetL = function()
          return {}
        end,
        IsRaidGroup = function()
          return false
        end,
        ResolveMainFramePositionLockEnabled = function()
          return true
        end,
        IsSpellKnownSafe = function()
          return true
        end,
        GetTeleportCooldownRemaining = function()
          return 0
        end,
        FormatCooldownSeconds = function()
          return ""
        end,
      }

      addonTable._FactoryInternal.InitializeFactoryFrameBridge(factoryCtx)
      Assert.Equal(
        factoryCtx.ResolveTeleportSpellIDByMapID,
        mapResolver,
        "factory context must retain the map teleport resolver"
      )
      Assert.Equal(
        capturedOpts.resolveTeleportSpellIDByMapID,
        mapResolver,
        "center notice must receive the verified mapID teleport resolver"
      )
    end)
  end)

  test("factory_frame_bridge: Print prefixes isiLive and feeds runtime log when available", function()
    local globals, prints = BuildDefaultGlobals()
    local logLines = {}
    local addonTable
    local factoryCtx
    ctx.with_globals(globals, function()
      addonTable = ctx.load_modules({ "isiLive_factory_frame_bridge.lua" })
      local tbl = BuildMinimalAddonTable({
        RuntimeLog = {
          CreateController = function(_opts)
            return {
              Log = function(msg)
                logLines[#logLines + 1] = msg
              end,
              Logf = function() end,
            }
          end,
        },
      })
      factoryCtx = addonTable._FactoryInternal.CreateFactoryContext("isiLive", tbl)
      factoryCtx.Print("hello-world")
    end)
    local foundPrint = false
    for _, line in ipairs(prints) do
      if string.find(line, "isiLive: hello-world", 1, true) then
        foundPrint = true
        break
      end
    end
    Assert.True(foundPrint, "Print must emit a prefixed chat line")
    Assert.Equal(#logLines, 1, "Print must forward the message to the runtime log")
    Assert.Equal(logLines[1], "hello-world", "runtime log must receive the raw text")
  end)

  -- ===========================================================
  -- Pure functions attached by CreateFactoryContext
  -- ===========================================================

  test("factory_frame_bridge: ResolveMainFramePositionLockEnabled treats missing db as locked", function()
    local globals = BuildDefaultGlobals()
    local factoryCtx
    ctx.with_globals(globals, function()
      local addonTable = ctx.load_modules({ "isiLive_factory_frame_bridge.lua" })
      factoryCtx = addonTable._FactoryInternal.CreateFactoryContext("isiLive", BuildMinimalAddonTable())
    end)
    Assert.Equal(factoryCtx.ResolveMainFramePositionLockEnabled(nil), true, "nil db must be treated as locked")
    Assert.Equal(factoryCtx.ResolveMainFramePositionLockEnabled({}), true, "empty db must stay locked by default")
    Assert.Equal(
      factoryCtx.ResolveMainFramePositionLockEnabled({ lockMainFramePosition = true }),
      true,
      "explicit lock=true remains locked"
    )
    Assert.Equal(
      factoryCtx.ResolveMainFramePositionLockEnabled({ lockMainFramePosition = false }),
      false,
      "explicit lock=false unlocks the frame"
    )
  end)

  test("factory_frame_bridge: IsPlayerLeader returns true in TestAllMode without consulting the API", function()
    WithContext(ctx, {
      UnitExists = function()
        error("UnitExists must not be called when test-all mode is active")
      end,
    }, {
      RuntimeState = {
        CreateController = function()
          return {
            IsTestAllMode = function()
              return true
            end,
            SetRoster = function() end,
          }
        end,
      },
    }, function(factoryCtx)
      Assert.Equal(factoryCtx.IsPlayerLeader(), true, "TestAllMode short-circuits to leader=true")
    end)
  end)

  test("factory_frame_bridge: IsPlayerLeader returns false when UnitExists reports no player", function()
    WithContext(ctx, {
      UnitExists = function()
        return false
      end,
    }, {}, function(factoryCtx)
      Assert.Equal(factoryCtx.IsPlayerLeader(), false, "missing player must resolve to not-leader")
    end)
  end)

  test("factory_frame_bridge: IsPlayerLeader requires in-group and unit-is-leader to return true", function()
    WithContext(ctx, {
      UnitExists = function()
        return true
      end,
      IsInGroup = function()
        return true
      end,
      UnitIsGroupLeader = function()
        return true
      end,
    }, {}, function(factoryCtx)
      Assert.Equal(factoryCtx.IsPlayerLeader(), true, "in-group + leader must resolve to true")
    end)
  end)

  test("factory_frame_bridge: GetNumGroupMembers clamps and floors API response", function()
    local responses = { -5, 2.7, "not-a-number", 0, 5 }
    local idx = 0
    WithContext(ctx, {
      GetNumGroupMembers = function()
        idx = idx + 1
        return responses[idx]
      end,
    }, {}, function(factoryCtx)
      Assert.Equal(factoryCtx.GetNumGroupMembers(), 0, "-5 must clamp to 0")
      Assert.Equal(factoryCtx.GetNumGroupMembers(), 2, "2.7 must floor to 2")
      Assert.Equal(factoryCtx.GetNumGroupMembers(), 0, "non-numeric must resolve to 0")
      Assert.Equal(factoryCtx.GetNumGroupMembers(), 0, "0 stays 0")
      Assert.Equal(factoryCtx.GetNumGroupMembers(), 5, "valid 5 stays 5")
    end)
  end)

  test("factory_frame_bridge: GetNumGroupMembers returns 0 when API is absent", function()
    WithContext(ctx, { GetNumGroupMembers = false }, {}, function(factoryCtx)
      Assert.Equal(factoryCtx.GetNumGroupMembers(), 0, "missing API must resolve to 0")
    end)
  end)

  test("factory_frame_bridge: IsRaidGroup prefers IsInRaid when available", function()
    WithContext(ctx, {
      IsInRaid = function()
        return true
      end,
    }, {}, function(factoryCtx)
      Assert.Equal(factoryCtx.IsRaidGroup(), true, "IsInRaid=true must short-circuit to raid")
    end)
  end)

  test("factory_frame_bridge: IsRaidGroup falls back to group-size>5 when IsInRaid reports false", function()
    WithContext(ctx, {
      IsInRaid = function()
        return false
      end,
      IsInGroup = function()
        return true
      end,
      GetNumGroupMembers = function()
        return 8
      end,
    }, {}, function(factoryCtx)
      Assert.Equal(factoryCtx.IsRaidGroup(), true, "group size 8 must count as raid")
    end)
  end)

  test("factory_frame_bridge: IsRaidGroup returns false for party-size groups", function()
    WithContext(ctx, {
      IsInRaid = function()
        return false
      end,
      IsInGroup = function()
        return true
      end,
      GetNumGroupMembers = function()
        return 4
      end,
    }, {}, function(factoryCtx)
      Assert.Equal(factoryCtx.IsRaidGroup(), false, "4-man group must not count as raid")
    end)
  end)

  test("factory_frame_bridge: GetPlayerMapID returns nil when player does not exist", function()
    WithContext(ctx, {
      UnitExists = function()
        return false
      end,
    }, {}, function(factoryCtx)
      Assert.Nil(factoryCtx.GetPlayerMapID(), "missing player must resolve to nil map id")
    end)
  end)

  test("factory_frame_bridge: GetPlayerMapID returns numeric map id when C_Map resolves", function()
    WithContext(ctx, {
      UnitExists = function()
        return true
      end,
      C_Map = {
        GetBestMapForUnit = function()
          return 2.9
        end,
        GetMapInfo = function()
          return nil
        end,
      },
    }, {}, function(factoryCtx)
      Assert.Equal(factoryCtx.GetPlayerMapID(), 2, "map id must be floored to integer")
    end)
  end)

  test("factory_frame_bridge: GetPlayerMapID rejects zero and negative map ids", function()
    local mapValue = 0
    WithContext(ctx, {
      UnitExists = function()
        return true
      end,
      C_Map = {
        GetBestMapForUnit = function()
          return mapValue
        end,
        GetMapInfo = function()
          return nil
        end,
      },
    }, {}, function(factoryCtx)
      Assert.Nil(factoryCtx.GetPlayerMapID(), "map id 0 must resolve to nil")
      mapValue = -3
      Assert.Nil(factoryCtx.GetPlayerMapID(), "negative map id must resolve to nil")
    end)
  end)

  test("factory_frame_bridge: GetMapInfoName returns name when C_Map.GetMapInfo resolves", function()
    WithContext(ctx, {
      C_Map = {
        GetBestMapForUnit = function()
          return nil
        end,
        GetMapInfo = function(mapID)
          if mapID == 2649 then
            return { name = "Ara-Kara, City of Echoes" }
          end
          return nil
        end,
      },
    }, {}, function(factoryCtx)
      Assert.Equal(factoryCtx.GetMapInfoName(2649), "Ara-Kara, City of Echoes", "resolved name must be returned")
      Assert.Nil(factoryCtx.GetMapInfoName(0), "invalid map id must resolve to nil without calling the API")
      Assert.Nil(factoryCtx.GetMapInfoName("not-a-number"), "non-numeric map id must resolve to nil")
    end)
  end)

  test("factory_frame_bridge: GetSubZoneText / GetZoneText / GetRealZoneText return nil when API is absent", function()
    WithContext(ctx, {
      GetSubZoneText = false,
      GetZoneText = false,
      GetRealZoneText = false,
    }, {}, function(factoryCtx)
      Assert.Nil(factoryCtx.GetSubZoneText(), "missing GetSubZoneText must resolve to nil")
      Assert.Nil(factoryCtx.GetZoneText(), "missing GetZoneText must resolve to nil")
      Assert.Nil(factoryCtx.GetRealZoneText(), "missing GetRealZoneText must resolve to nil")
    end)
  end)

  test("factory_frame_bridge: zone text getters forward API results", function()
    WithContext(ctx, {
      GetSubZoneText = function()
        return "sub-zone"
      end,
      GetZoneText = function()
        return "zone"
      end,
      GetRealZoneText = function()
        return "real-zone"
      end,
    }, {}, function(factoryCtx)
      Assert.Equal(factoryCtx.GetSubZoneText(), "sub-zone", "sub-zone text must be forwarded")
      Assert.Equal(factoryCtx.GetZoneText(), "zone", "zone text must be forwarded")
      Assert.Equal(factoryCtx.GetRealZoneText(), "real-zone", "real zone text must be forwarded")
    end)
  end)
end

return Register
