local _, addonTable = ...

addonTable = addonTable or {}

local RuntimeSetup = {}
addonTable.RuntimeSetup = RuntimeSetup

local function RequireFunction(value, name)
  return addonTable.Validators.RequireFunction(value, name, "RuntimeSetup")
end

local function RequireTable(value, name)
  return addonTable.Validators.RequireTable(value, name, "RuntimeSetup")
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
  RequireFunction(ctx.onEvent, "onEvent")

  local groupController = controllerWiring.CreateGroupControllerFromContext(groupModule, ctx)
  ctx.groupController = groupController

  local leaderWatchController = leaderWatchModule.CreateController(configBuilders.BuildLeaderWatchControllerOpts(ctx))
  leaderWatchController.Start()

  local eventHandlersController = controllerWiring.CreateEventHandlersControllerFromContext(eventHandlersModule, ctx)

  bootstrap.RegisterSlashCommands(configBuilders.BuildSlashCommandsOpts(ctx))

  local gateOpts = configBuilders.BuildGateOpts(ctx)
  local gatedOnEvent = bootstrap.CreateGatedOnEvent(gateOpts)
  mainFrame:SetScript("OnEvent", gatedOnEvent)

  return {
    eventHandlersController = eventHandlersController,
  }
end
