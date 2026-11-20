---@diagnostic disable: undefined-global, undefined-field

-- Scenarios for the small DB-resolver helpers exported via _FactoryInternal
-- from factory/isiLive_factory.lua. These are pure, tiny predicates used by
-- the composition root; they were never exercised by the existing factory
-- scenarios which only touch the orchestrator path.

local function Load(LoadAddonModules)
  return LoadAddonModules({ "isiLive_factory.lua" })
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  test("factory resolvers: ResolveAutoCloseOnKeyStartEnabled defaults disabled and requires explicit true", function()
    local addon = Load(LoadAddonModules)
    local fn = addon._FactoryInternal.ResolveAutoCloseOnKeyStartEnabled
    Assert.Equal(fn(nil), false, "nil DB must default to disabled")
    Assert.Equal(fn({}), false, "empty table must default to disabled")
    Assert.Equal(fn({ autoCloseOnKeyStart = false }), false, "explicit false keeps the default disabled")
    Assert.Equal(
      fn({ autoCloseOnKeyStart = "false" }),
      false,
      "non-boolean values must not enable key-start auto-close"
    )
    Assert.Equal(fn({ autoCloseOnKeyStart = true }), true, "explicit true enables key-start auto-close")
    Assert.Equal(fn("not-a-table"), false, "non-table input falls back to the disabled default")
  end)

  test("factory resolvers: ResolveAutoCloseOnSoloChangeEnabled requires explicit true", function()
    local addon = Load(LoadAddonModules)
    local fn = addon._FactoryInternal.ResolveAutoCloseOnSoloChangeEnabled
    Assert.Equal(fn(nil), false, "nil DB must default to disabled")
    Assert.Equal(fn({}), false, "empty table must default to disabled")
    Assert.Equal(fn({ autoCloseOnSoloChange = false }), false)
    Assert.Equal(fn({ autoCloseOnSoloChange = true }), true)
  end)

  test("factory resolvers: ResolveAutoShowMainFrameOnStartupEnabled defaults true", function()
    local addon = Load(LoadAddonModules)
    local fn = addon._FactoryInternal.ResolveAutoShowMainFrameOnStartupEnabled
    Assert.Equal(fn(nil), true, "nil DB must default to enabled")
    Assert.Equal(fn({}), true)
    Assert.Equal(fn({ autoShowMainFrameOnStartup = true }), true)
    Assert.Equal(fn({ autoShowMainFrameOnStartup = false }), false, "explicit false disables")
    Assert.Equal(fn({ autoShowMainFrameOnStartup = "false" }), true, "only strict boolean false disables")
  end)

  test("factory resolvers: ResolveAutoOpenMainFrameOnKeyEndEnabled defaults true", function()
    local addon = Load(LoadAddonModules)
    local fn = addon._FactoryInternal.ResolveAutoOpenMainFrameOnKeyEndEnabled
    Assert.Equal(fn(nil), true)
    Assert.Equal(fn({}), true)
    Assert.Equal(fn({ autoOpenMainFrameOnKeyEnd = false }), false)
    Assert.Equal(fn({ autoOpenMainFrameOnKeyEnd = true }), true)
  end)

  test("factory resolvers: ResolveMainFramePositionLockEnabled defaults true", function()
    local addon = Load(LoadAddonModules)
    local fn = addon._FactoryInternal.ResolveMainFramePositionLockEnabled
    Assert.Equal(fn(nil), true, "nil DB must default to locked")
    Assert.Equal(fn({}), true, "empty table must default to locked")
    Assert.Equal(fn({ lockMainFramePosition = false }), false, "explicit false unlocks the frame")
    Assert.Equal(fn({ lockMainFramePosition = true }), true)
    Assert.Equal(fn({ lockMainFramePosition = 0 }), true, "only strict boolean false unlocks")
  end)

  test("factory resolvers: ResolveRaidTransitionBehavior always returns hide", function()
    local addon = Load(LoadAddonModules)
    local fn = addon._FactoryInternal.ResolveRaidTransitionBehavior
    Assert.Equal(fn(nil), "hide", "missing DB must default to hide")
    Assert.Equal(fn({}), "hide")
    Assert.Equal(fn({ raidTransitionBehavior = "show" }), "hide", "setting is intentionally frozen to hide")
    Assert.Equal(fn("not-a-table"), "hide")
  end)

  test("factory contracts: Compose merges contracts and rejects a key two contracts provide", function()
    local addon = Load(LoadAddonModules)
    local Compose = addon._FactoryInternal.FactoryContracts.Compose
    local first = function() end
    local merged = Compose("ctx", { a = first }, { b = 2 })
    Assert.Equal(merged.a, first, "contract values are carried over unchanged")
    Assert.Equal(merged.b, 2)
    local ok, err = pcall(Compose, "ctx", { a = 1 }, { a = 2 })
    Assert.False(ok, "a duplicated key must not shadow silently")
    Assert.True(tostring(err):find('key "a"', 1, true) ~= nil, "the error names the duplicated key")
    Assert.False((pcall(Compose, "ctx", { a = 1 }, "not-a-table")), "a non-table contract is rejected")
  end)

  test("factory contracts: group and event-handler contexts share the group contracts", function()
    local addon = Load(LoadAddonModules)
    local FI = addon._FactoryInternal
    local function Stub()
      return setmetatable({}, {
        __index = function(t, k)
          local v = function() end
          rawset(t, k, v)
          return v
        end,
      })
    end
    local ctx = Stub()
    ctx.modules = { sync = {}, events = {}, commands = {}, locale = { ResolveLocaleTag = function() end } }
    ctx.queueDebugController = Stub()
    ctx.runtimeLogController = Stub()
    local runtimeState = Stub()
    local group = FI.BuildRuntimeSetupGroupContext(ctx, runtimeState)
    local handlers = FI.BuildRuntimeSetupEventHandlersContext(ctx, runtimeState)
    -- Every group dependency except the group-only join hook reaches the
    -- event handlers too; plain ctx handles are the identical value.
    for key in pairs(group) do
      if key ~= "onGroupJoined" then
        Assert.NotNil(handlers[key], "event handlers also provide " .. key)
      end
    end
    for _, key in ipairs({ "getRoster", "setWasInGroup", "enqueueInspect", "sendOwnKeySnapshot", "updateUI" }) do
      Assert.Equal(handlers[key], group[key], "event handlers see the same " .. key)
    end
    Assert.Equal(handlers.teleportUIController, ctx.teleportUIController, "season switch needs the teleport UI")
    Assert.Equal(handlers.refreshReadyCheckUI, ctx.RefreshReadyCheckUI)
    Assert.Equal(group.captureQueueJoinCandidate, ctx.CaptureQueueJoinCandidate)
  end)
end
