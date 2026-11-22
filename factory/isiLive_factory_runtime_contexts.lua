local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

-- RuntimeSetup contexts of the composition root, each composed from the
-- named dependency contracts in factory/isiLive_factory_contracts.lua.
-- Every context stays a separate table, so a dependency missing from one
-- controller cannot be masked by another controller's context.

---@class IsiLiveRuntimeSetupContext
---@field controllerWiring table ControllerWiring module.
---@field configBuilders table ConfigBuilders module.
---@field bootstrap table Bootstrap module.
---@field leaderWatchModule table LeaderWatch module.
---@field groupModule table Group module.
---@field eventHandlersModule table EventHandlers module.
---@field mainFrame table Main window frame.
---@field eventFrame table Event dispatcher frame.
---@field onEvent function Factory event entry point.
---@field groupControllerContext table See BuildRuntimeSetupGroupContext.
---@field eventHandlersContext table See BuildRuntimeSetupEventHandlersContext.
---@field leaderWatchContext table See BuildRuntimeSetupLeaderWatchContext.
---@field slashCommandsContext table See BuildRuntimeSetupSlashCommandsContext.
---@field gateContext table See BuildRuntimeSetupGateContext.

local Contracts = FI.FactoryContracts
local Compose = Contracts.Compose

--- Group controller: roster membership, roster data and the join/leave side effects.
local function BuildRuntimeSetupGroupContext(ctx, runtimeState)
  return Compose(
    "groupControllerContext",
    Contracts.GroupMembership(ctx),
    Contracts.RosterData(ctx),
    Contracts.InspectQueue(ctx),
    Contracts.QueueJoin(ctx, runtimeState),
    Contracts.GroupSyncSenders(ctx),
    Contracts.ReloadRosterMirror(ctx),
    Contracts.MainFrameAutoClose(ctx),
    Contracts.UiRefresh(ctx),
    Contracts.ChatOutput(ctx),
    {
      sync = ctx.modules.sync,
      onGroupJoined = function()
        if type(ctx.ShowJoinedTargetNotice) == "function" then
          ctx.ShowJoinedTargetNotice()
        end
      end,
    }
  )
end

--- Event handlers: the group contracts plus every feature an event touches.
-- No getRaidTargetIndex / setRaidTarget here on purpose. SetRaidTarget is
-- protected and its direct runtime path was removed after it raised
-- ADDON_ACTION_FORBIDDEN; raid markers go through the secure worldmarker
-- and macrotext buttons instead (ui/isiLive_roster_panel_chrome.lua,
-- ui/isiLive_roster_panel_render.lua).
local function BuildRuntimeSetupEventHandlersContext(ctx, runtimeState)
  return Compose(
    "eventHandlersContext",
    Contracts.Modules(ctx),
    Contracts.GroupMembership(ctx),
    Contracts.RosterData(ctx),
    Contracts.InspectQueue(ctx),
    Contracts.InspectSpec(ctx),
    Contracts.QueueJoin(ctx, runtimeState),
    Contracts.GroupSyncSenders(ctx),
    Contracts.EventSyncSenders(ctx),
    Contracts.ReloadRosterMirror(ctx),
    Contracts.MainFrameAutoClose(ctx),
    Contracts.MainFrameLifecycle(ctx),
    Contracts.UiRefresh(ctx),
    Contracts.ChatOutput(ctx),
    Contracts.Leadership(ctx),
    Contracts.ReadyCheck(ctx),
    Contracts.CombatUtilities(ctx),
    Contracts.ShareKeys(ctx),
    Contracts.KeyEnd(ctx),
    Contracts.RuntimeFlags(ctx, runtimeState),
    Contracts.PartyRunState(runtimeState),
    Contracts.Localization(ctx),
    Contracts.LfgQueue(ctx),
    Contracts.RioBaseline(ctx),
    Contracts.DebugLogs(ctx),
    Contracts.Bindings(ctx),
    Contracts.CenterNotice(ctx),
    Contracts.Controllers(ctx),
    Contracts.TestMode(ctx),
    Contracts.Persistence(ctx)
  )
end

local function BuildRuntimeSetupLeaderWatchContext(ctx, runtimeState)
  return {
    isPlayerLeader = ctx.IsPlayerLeader,
    getWasGroupLeader = ctx.GetWasGroupLeader,
    setWasGroupLeader = ctx.SetWasGroupLeader,
    isStopped = runtimeState.IsStopped,
    isMainFrameShown = FI.IsMainFrameShownFn(ctx),
    showCenterNotice = ctx.ShowCenterNotice,
    printFn = ctx.Print,
    getL = ctx.GetL,
    updateLeaderButtons = ctx.UpdateLeaderButtons,
    runtimeLogController = ctx.runtimeLogController,
  }
end

local function BuildRuntimeSetupSlashCommandsContext(ctx, runtimeState)
  return {
    commands = ctx.modules.commands,
    printFn = ctx.Print,
    printNoLogFn = ctx.PrintNoLog,
    getL = ctx.GetL,
    statsController = ctx.statsController,
    getState = runtimeState.GetRuntimeFlags,
    setState = runtimeState.PatchRuntimeFlags,
    triggerGroupRosterUpdate = ctx.TriggerGroupRosterUpdate,
    toggleStandardTestMode = ctx.ToggleStandardTestMode,
    enterFullDummyPreview = ctx.EnterFullDummyPreview,
    toggleSimulationTablet = ctx.ToggleSimulationTablet,
    setMainFrameVisible = ctx.SetMainFrameVisible,
    mainFrame = ctx.mainFrame,
    mainUI = ctx.mainUI,
    panelUI = ctx.panelUI,
    -- Resolved per call: ApplyLocalizationToUI creates the ESC panel on
    -- ADDON_LOADED, after this context is built, so a captured ctx.panelUI is nil.
    getPanelUI = function()
      return ctx.panelUI
    end,
    -- Resolved per call: FinalizeFactorySettings creates the settings panel
    -- after this context is built, so a captured ctx.settingsPanel is nil.
    getSettingsPanel = function()
      return ctx.settingsPanel
    end,
    updateLeaderButtons = ctx.UpdateLeaderButtons,
    isPlayerLeader = ctx.IsPlayerLeader,
    setLanguage = ctx.SetLanguage,
    teleportDebugController = ctx.teleportDebugController,
    queueDebugController = ctx.queueDebugController,
    traceChatFrameController = ctx.traceChatFrameController,
    runtimeLogController = ctx.runtimeLogController,
    resetDB = ctx.resetDB,
    getUiDesign = function()
      local db = rawget(_G, "IsiLiveDB")
      local uiCommon = ctx.addonTable and ctx.addonTable.UICommon
      local stored = type(db) == "table" and uiCommon and uiCommon.NormalizeDesign(db.uiDesign) or nil
      return stored or (uiCommon and uiCommon.DEFAULT_DESIGN) or "modern"
    end,
    setUiDesign = function(name)
      return FI.SetUiDesign(ctx, name)
    end,
    getRosterPanelController = function()
      return ctx.rosterPanelController
    end,
    logRuntimeTrace = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil,
    logRuntimeTracef = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil,
  }
end

-- A dispatch error on a high-frequency event (UNIT_AURA fires many times per
-- second for five units) turns one broken read into a wall of chat lines. When
-- a client patch masks a value we did not expect, the addon should report the
-- problem once, not once per event. Identical event+error pairs are therefore
-- printed at most once per window; a different error still prints immediately.
local DISPATCH_ERROR_REPEAT_SECONDS = 60

local function BuildDispatchErrorReporter(ctx)
  local lastMessage = nil
  local lastPrintedAt = nil

  return function(_frame, event, err)
    local message = string.format("Event dispatch failed (%s): %s", tostring(event), tostring(err))
    local getTime = rawget(_G, "GetTime")
    local ok, now = pcall(function()
      return type(getTime) == "function" and getTime() or nil
    end)
    now = ok and type(now) == "number" and now or nil
    if
      message == lastMessage
      and now ~= nil
      and lastPrintedAt ~= nil
      and (now - lastPrintedAt) < DISPATCH_ERROR_REPEAT_SECONDS
    then
      return
    end
    lastMessage = message
    lastPrintedAt = now
    ctx.Print(message)
  end
end

local function BuildRuntimeSetupGateContext(ctx, runtimeState)
  return {
    events = ctx.modules.events,
    onEvent = ctx.OnEvent,
    onDispatchError = BuildDispatchErrorReporter(ctx),
    isStopped = runtimeState.IsStopped,
    isPaused = runtimeState.IsPaused,
    isTestMode = runtimeState.IsTestMode,
    isInCombat = ctx.IsInCombat,
    isInPartyInstance = ctx.IsInPartyInstance,
    -- Read at event time: the controller is created after this context.
    wasInPartyInstance = function()
      local controller = ctx.eventHandlersController
      return controller ~= nil and controller.WasInPartyInstance() == true
    end,
    isMainFrameShown = FI.IsMainFrameShownFn(ctx),
  }
end

--- Builds the complete RuntimeSetup.Configure input.
---@return IsiLiveRuntimeSetupContext
local function BuildRuntimeSetupContext(ctx)
  local modules = ctx.modules
  local runtimeState = ctx.runtimeState
  local eventHandlersContext = BuildRuntimeSetupEventHandlersContext(ctx, runtimeState)
  return {
    controllerWiring = modules.controllerWiring,
    configBuilders = modules.configBuilders,
    bootstrap = modules.bootstrap,
    leaderWatchModule = modules.leaderWatch,
    groupModule = modules.group,
    eventHandlersModule = modules.eventHandlers,
    mainFrame = ctx.mainFrame,
    eventFrame = ctx.eventFrame,
    onEvent = ctx.OnEvent,
    groupControllerContext = BuildRuntimeSetupGroupContext(ctx, runtimeState),
    eventHandlersContext = eventHandlersContext,
    leaderWatchContext = BuildRuntimeSetupLeaderWatchContext(ctx, runtimeState),
    slashCommandsContext = BuildRuntimeSetupSlashCommandsContext(ctx, runtimeState),
    gateContext = BuildRuntimeSetupGateContext(ctx, runtimeState),
  }
end

FI.BuildRuntimeSetupContext = BuildRuntimeSetupContext
FI.BuildRuntimeSetupGroupContext = BuildRuntimeSetupGroupContext
FI.BuildRuntimeSetupEventHandlersContext = BuildRuntimeSetupEventHandlersContext
