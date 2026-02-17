local _, addonTable = ...

addonTable = addonTable or {}

local RuntimeSetup = {}
addonTable.RuntimeSetup = RuntimeSetup

local function RequireFunction(value, name)
  assert(type(value) == "function", "isiLive: RuntimeSetup requires " .. name)
  return value
end

local function RequireTable(value, name)
  assert(type(value) == "table", "isiLive: RuntimeSetup requires table " .. name)
  return value
end

function RuntimeSetup.Configure(ctx)
  ctx = RequireTable(ctx, "ctx")

  local controllerWiring = RequireTable(ctx.controllerWiring, "controllerWiring")
  local configBuilders = RequireTable(ctx.configBuilders, "configBuilders")
  local bootstrap = RequireTable(ctx.bootstrap, "bootstrap")
  local leaderWatchModule = RequireTable(ctx.leaderWatchModule, "leaderWatchModule")
  local groupModule = assert(ctx.groupModule, "isiLive: RuntimeSetup requires groupModule")
  local eventHandlersModule = assert(ctx.eventHandlersModule, "isiLive: RuntimeSetup requires eventHandlersModule")
  local mainFrame = assert(ctx.mainFrame, "isiLive: RuntimeSetup requires mainFrame")
  local onEvent = RequireFunction(ctx.onEvent, "onEvent")

  local groupController =
    controllerWiring.CreateGroupController(groupModule, configBuilders.BuildGroupControllerDeps(ctx))
  ctx.groupController = groupController

  local leaderWatchController = leaderWatchModule.CreateController(configBuilders.BuildLeaderWatchControllerOpts(ctx))
  leaderWatchController.Start()

  local eventHandlersController = controllerWiring.CreateEventHandlersController(
    eventHandlersModule,
    configBuilders.BuildEventHandlersControllerDeps(ctx)
  )

  bootstrap.RegisterSlashCommands(configBuilders.BuildSlashCommandsOpts(ctx))

  local gatedOnEvent = bootstrap.CreateGatedOnEvent(configBuilders.BuildGateOpts(ctx))
  mainFrame:SetScript("OnEvent", gatedOnEvent)

  return {
    groupController = groupController,
    leaderWatchController = leaderWatchController,
    eventHandlersController = eventHandlersController,
    gatedOnEvent = gatedOnEvent,
    onEvent = onEvent,
  }
end
