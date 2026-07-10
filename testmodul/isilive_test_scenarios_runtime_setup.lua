---@diagnostic disable: undefined-global

-- Scenarios for core/isiLive_runtime_setup.lua - RuntimeSetup.Configure()
-- is the composition-root glue that validates ctx inputs and wires the
-- group + event handlers + slash commands + gated onEvent together.
--
-- The existing architecture scenarios only look at the source text
-- statically; these tests exercise Configure() at runtime with minimal
-- stubs for the module surfaces it depends on.

local function BuildMainFrameStub()
  local state = { onEvent = nil, scriptType = nil }
  state.SetScript = function(_, scriptType, fn)
    state.scriptType = scriptType
    state.onEvent = fn
  end
  return state
end

local function BuildEventFrameStub()
  local state = { onEvent = nil, scriptType = nil }
  state.SetScript = function(_, scriptType, fn)
    state.scriptType = scriptType
    state.onEvent = fn
  end
  return state
end

local function BuildCtx(overrides)
  overrides = overrides or {}
  local calls = { leaderStart = 0 }

  local groupController = { id = "group-ctrl" }
  local leaderWatchController = {
    Start = function()
      calls.leaderStart = calls.leaderStart + 1
    end,
  }
  local eventHandlersController = { id = "events-ctrl" }
  local gatedHandler = function() end

  local controllerWiring = {
    CreateGroupControllerFromContext = function(_, _)
      return overrides.groupController or groupController
    end,
    CreateEventHandlersControllerFromContext = function(_, _)
      return overrides.eventHandlersController or eventHandlersController
    end,
  }
  local leaderWatchModule = {
    CreateController = function(_)
      return overrides.leaderWatchController or leaderWatchController
    end,
  }
  local bootstrap = {
    RegisterSlashCommands = function(_)
      calls.slashRegistered = true
    end,
    CreateGatedOnEvent = function(_)
      return gatedHandler
    end,
  }
  local configBuilders = {
    BuildLeaderWatchControllerOpts = function(_)
      return { kind = "leaderOpts" }
    end,
    BuildSlashCommandsOpts = function(_)
      return { kind = "slashOpts" }
    end,
    BuildGateOpts = function(_)
      return { kind = "gateOpts" }
    end,
  }

  local ctx = {
    controllerWiring = controllerWiring,
    configBuilders = configBuilders,
    bootstrap = bootstrap,
    leaderWatchModule = leaderWatchModule,
    groupModule = { id = "groupModule" },
    eventHandlersModule = { id = "eventHandlersModule" },
    mainFrame = overrides.mainFrame or BuildMainFrameStub(),
    eventFrame = overrides.eventFrame or BuildEventFrameStub(),
    onEvent = overrides.onEvent or function() end,
    groupControllerContext = overrides.groupControllerContext or { kind = "groupContext" },
    eventHandlersContext = overrides.eventHandlersContext or { kind = "eventContext" },
    leaderWatchContext = overrides.leaderWatchContext or { kind = "leaderContext" },
    slashCommandsContext = overrides.slashCommandsContext or { kind = "slashContext" },
    gateContext = overrides.gateContext or { kind = "gateContext" },
  }
  if overrides.scrub then
    for _, key in ipairs(overrides.scrub) do
      ctx[key] = nil
    end
  end
  return ctx, calls, gatedHandler
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  local function Load()
    return LoadAddonModules({ "isiLive_runtime_setup.lua", "isiLive_guards.lua" })
  end

  test("RuntimeSetup.Configure wires group controller, event handlers, slash commands, gated handler", function()
    local addon = Load()
    local c, calls, gatedHandler = BuildCtx()
    local result
    WithGlobals({}, function()
      result = addon.RuntimeSetup.Configure(c)
    end)
    Assert.Equal(
      c.eventHandlersContext.groupController.id,
      "group-ctrl",
      "group controller must be attached only to the event-handler context"
    )
    Assert.Equal(
      c.eventHandlersContext.leaderWatchController,
      c.leaderWatchContext ~= nil and c.eventHandlersContext.leaderWatchController or nil,
      "leader-watch controller must be attached to the event-handler context"
    )
    Assert.Equal(calls.leaderStart, 1, "leader watch controller must be started exactly once")
    Assert.Equal(calls.slashRegistered, true, "slash commands must be registered via bootstrap")
    Assert.Equal(c.mainFrame.scriptType, "OnEvent", "mainFrame OnEvent script must be wired")
    Assert.Equal(c.mainFrame.onEvent, gatedHandler, "OnEvent handler must be the gated variant from bootstrap")
    Assert.Equal(c.eventFrame.scriptType, "OnEvent", "eventFrame OnEvent script must be wired")
    Assert.Equal(
      c.eventFrame.onEvent,
      gatedHandler,
      "eventFrame OnEvent handler must be the gated variant so natural events pass through the gate"
    )
    Assert.Equal(result.eventHandlersController.id, "events-ctrl", "result must expose eventHandlersController")
  end)

  test("RuntimeSetup.Configure raises when ctx table is missing", function()
    local addon = Load()
    local ok, err
    WithGlobals({}, function()
      ok, err = pcall(addon.RuntimeSetup.Configure, nil)
    end)
    Assert.Equal(ok, false, "nil ctx must fail")
    Assert.Equal(type(err) == "string" and err:find("ctx", 1, true) ~= nil, true)
  end)

  test("RuntimeSetup.Configure rejects missing named dependency contexts", function()
    for _, key in ipairs({
      "groupControllerContext",
      "eventHandlersContext",
      "leaderWatchContext",
      "slashCommandsContext",
      "gateContext",
    }) do
      local c = BuildCtx({ scrub = { key } })
      local ok, err
      WithGlobals({}, function()
        ok, err = pcall(Load().RuntimeSetup.Configure, c)
      end)
      Assert.False(ok, key .. " must be required")
      Assert.True(type(err) == "string" and err:find(key, 1, true) ~= nil, key .. " error must be explicit")
    end
  end)

  test("RuntimeSetup.Configure raises when controllerWiring is missing", function()
    local addon = Load()
    local c = BuildCtx()
    c.controllerWiring = nil
    local ok, err
    WithGlobals({}, function()
      ok, err = pcall(addon.RuntimeSetup.Configure, c)
    end)
    Assert.Equal(ok, false)
    Assert.Equal(type(err) == "string" and err:find("controllerWiring", 1, true) ~= nil, true)
  end)

  test("RuntimeSetup.Configure raises when configBuilders is missing", function()
    local addon = Load()
    local c = BuildCtx()
    c.configBuilders = nil
    local ok, err
    WithGlobals({}, function()
      ok, err = pcall(addon.RuntimeSetup.Configure, c)
    end)
    Assert.Equal(ok, false)
    Assert.Equal(type(err) == "string" and err:find("configBuilders", 1, true) ~= nil, true)
  end)

  test("RuntimeSetup.Configure raises when bootstrap is missing", function()
    local addon = Load()
    local c = BuildCtx()
    c.bootstrap = nil
    local ok, err
    WithGlobals({}, function()
      ok, err = pcall(addon.RuntimeSetup.Configure, c)
    end)
    Assert.Equal(ok, false)
    Assert.Equal(type(err) == "string" and err:find("bootstrap", 1, true) ~= nil, true)
  end)

  test("RuntimeSetup.Configure raises when leaderWatchModule is missing", function()
    local addon = Load()
    local c = BuildCtx()
    c.leaderWatchModule = nil
    local ok, err
    WithGlobals({}, function()
      ok, err = pcall(addon.RuntimeSetup.Configure, c)
    end)
    Assert.Equal(ok, false)
    Assert.Equal(type(err) == "string" and err:find("leaderWatchModule", 1, true) ~= nil, true)
  end)

  test("RuntimeSetup.Configure raises when groupModule is missing", function()
    local addon = Load()
    local c = BuildCtx()
    c.groupModule = nil
    local ok, err
    WithGlobals({}, function()
      ok, err = pcall(addon.RuntimeSetup.Configure, c)
    end)
    Assert.Equal(ok, false)
    Assert.Equal(type(err) == "string" and err:find("groupModule", 1, true) ~= nil, true)
  end)

  test("RuntimeSetup.Configure raises when eventHandlersModule is missing", function()
    local addon = Load()
    local c = BuildCtx()
    c.eventHandlersModule = nil
    local ok, err
    WithGlobals({}, function()
      ok, err = pcall(addon.RuntimeSetup.Configure, c)
    end)
    Assert.Equal(ok, false)
    Assert.Equal(type(err) == "string" and err:find("eventHandlersModule", 1, true) ~= nil, true)
  end)

  test("RuntimeSetup.Configure raises when mainFrame is missing", function()
    local addon = Load()
    local c = BuildCtx()
    c.mainFrame = nil
    local ok, err
    WithGlobals({}, function()
      ok, err = pcall(addon.RuntimeSetup.Configure, c)
    end)
    Assert.Equal(ok, false)
    Assert.Equal(type(err) == "string" and err:find("mainFrame", 1, true) ~= nil, true)
  end)

  test("RuntimeSetup.Configure raises when onEvent is not a function", function()
    local addon = Load()
    local c = BuildCtx()
    c.onEvent = "not-a-fn"
    local ok, err
    WithGlobals({}, function()
      ok, err = pcall(addon.RuntimeSetup.Configure, c)
    end)
    Assert.Equal(ok, false)
    Assert.Equal(type(err) == "string" and err:find("onEvent", 1, true) ~= nil, true)
  end)
end
