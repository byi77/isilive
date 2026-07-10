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
  local eventFrame = ctx.eventFrame
  RequireFunction(ctx.onEvent, "onEvent")

  local groupContext = RequireTable(ctx.groupControllerContext, "groupControllerContext")
  local eventContext = RequireTable(ctx.eventHandlersContext, "eventHandlersContext")
  local leaderWatchContext = RequireTable(ctx.leaderWatchContext, "leaderWatchContext")
  local slashCommandsContext = RequireTable(ctx.slashCommandsContext, "slashCommandsContext")
  local gateContext = RequireTable(ctx.gateContext, "gateContext")

  local groupController = controllerWiring.CreateGroupControllerFromContext(groupModule, groupContext)
  eventContext.groupController = groupController

  local leaderWatchController =
    leaderWatchModule.CreateController(configBuilders.BuildLeaderWatchControllerOpts(leaderWatchContext))
  eventContext.leaderWatchController = leaderWatchController
  leaderWatchController.Start()

  local eventHandlersController =
    controllerWiring.CreateEventHandlersControllerFromContext(eventHandlersModule, eventContext)

  bootstrap.RegisterSlashCommands(configBuilders.BuildSlashCommandsOpts(slashCommandsContext))

  local gateOpts = configBuilders.BuildGateOpts(gateContext)
  local gatedOnEvent = bootstrap.CreateGatedOnEvent(gateOpts)
  -- Bind the gate on both frames:
  --   * eventFrame is where Blizzard delivers all natural RegisterEvent fires
  --     (factory.lua wires RegisterDispatcherEvents to it). Without this the
  --     gate's stop/pause/testMode/inCombat/hidden suppression would only
  --     apply to synthetic re-dispatches, never to natural events.
  --   * mainFrame keeps the gate so the existing synthetic dispatch sites
  --     (TriggerGroupRosterUpdate / onShownInGroup / RefreshRosterAfterRunStateChange
  --     via `mainFrame:GetScript("OnEvent")`) stay in lockstep with the natural
  --     path.
  if eventFrame and type(eventFrame.SetScript) == "function" then
    eventFrame:SetScript("OnEvent", gatedOnEvent)
  end
  mainFrame:SetScript("OnEvent", gatedOnEvent)

  return {
    eventHandlersController = eventHandlersController,
  }
end
