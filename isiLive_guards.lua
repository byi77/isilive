local _, addonTable = ...

addonTable = addonTable or {}

local Guards = {}
addonTable.Guards = Guards

local REQUIRED_MODULES = {
  { key = "Sync", file = "isiLive_sync.lua" },
  { key = "KeySync", file = "isiLive_keysync.lua" },
  { key = "Refresh", file = "isiLive_refresh.lua" },
  { key = "Highlight", file = "isiLive_highlight.lua" },
  { key = "Group", file = "isiLive_group.lua" },
  { key = "Queue", file = "isiLive_queue.lua" },
  { key = "QueueFlow", file = "isiLive_queue_flow.lua" },
  { key = "LogBuffer", file = "isiLive_log_buffer.lua" },
  { key = "Inspect", file = "isiLive_inspect.lua" },
  { key = "Roster", file = "isiLive_roster.lua" },
  { key = "Events", file = "isiLive_events.lua" },
  { key = "EventHandlers", file = "isiLive_event_handlers.lua" },
  { key = "Commands", file = "isiLive_commands.lua" },
  { key = "Locale", file = "isiLive_locale.lua" },
  { key = "Texts", file = "isiLive_texts.lua" },
  { key = "UI", file = "isiLive_ui.lua" },
  { key = "UICommon", file = "isiLive_ui_common.lua" },
  { key = "Teleport", file = "isiLive_teleport.lua" },
  { key = "TeleportUI", file = "isiLive_teleport_ui.lua" },
  { key = "TeleportDebug", file = "isiLive_teleport_debug.lua" },
  { key = "Notice", file = "isiLive_notice.lua" },
  { key = "Status", file = "isiLive_status.lua" },
  { key = "Units", file = "isiLive_units.lua" },
  { key = "Demo", file = "isiLive_demo.lua" },
  { key = "TestMode", file = "isiLive_test_mode.lua" },
  { key = "QueueDebug", file = "isiLive_queue_debug.lua" },
  { key = "RuntimeLog", file = "isiLive_runtime_log.lua" },
  { key = "RosterPanel", file = "isiLive_roster_panel.lua" },
  { key = "Stats", file = "isiLive_stats.lua" },
  { key = "SpellUtils", file = "isiLive_spell_utils.lua" },
  { key = "Bindings", file = "isiLive_bindings.lua" },
  { key = "EventUtils", file = "isiLive_event_utils.lua" },
  { key = "RuntimeState", file = "isiLive_runtime_state.lua" },
  { key = "Bootstrap", file = "isiLive_bootstrap.lua" },
  { key = "ControllerWiring", file = "isiLive_controller_wiring.lua" },
  { key = "LeaderWatch", file = "isiLive_leader_watch.lua" },
  { key = "ConfigBuilders", file = "isiLive_config_builders.lua" },
  { key = "FrameBridge", file = "isiLive_frame_bridge.lua" },
  { key = "ContextHelpers", file = "isiLive_context_helpers.lua" },
  { key = "RuntimeSetup", file = "isiLive_runtime_setup.lua" },
  { key = "ControllerInit", file = "isiLive_controller_init.lua" },
  { key = "SeasonData", file = "isiLive_season_data.lua" },
  { key = "EventHandlersQueueLifecycle", file = "isiLive_event_handlers_queue.lua" },
  { key = "EventHandlersChallengeLifecycle", file = "isiLive_event_handlers_challenge.lua" },
  { key = "EventHandlersRuntimeLifecycle", file = "isiLive_event_handlers_runtime.lua" },
}

local REQUIRED_FUNCTIONS = {
  { path = { "Queue", "CaptureQueueJoinCandidate" }, message = "isiLive: Queue.CaptureQueueJoinCandidate missing" },
  { path = { "KeySync", "CreateController" }, message = "isiLive: KeySync.CreateController missing" },
  { path = { "Refresh", "CreateController" }, message = "isiLive: Refresh.CreateController missing" },
  { path = { "Highlight", "CreateController" }, message = "isiLive: Highlight.CreateController missing" },
  { path = { "Group", "CreateController" }, message = "isiLive: Group.CreateController missing" },
  { path = { "Inspect", "CreateController" }, message = "isiLive: Inspect.CreateController missing" },
  { path = { "QueueFlow", "CreateController" }, message = "isiLive: QueueFlow.CreateController missing" },
  { path = { "Roster", "BuildOrderedRoster" }, message = "isiLive: Roster.BuildOrderedRoster missing" },
  { path = { "Events", "CreateGate" }, message = "isiLive: Events.CreateGate missing" },
  { path = { "EventHandlers", "CreateController" }, message = "isiLive: EventHandlers.CreateController missing" },
  { path = { "Commands", "RegisterSlashCommands" }, message = "isiLive: Commands.RegisterSlashCommands missing" },
  { path = { "Texts", "GetLocaleTables" }, message = "isiLive: Texts.GetLocaleTables missing" },
  { path = { "UI", "CreateMainFrame" }, message = "isiLive: UI.CreateMainFrame missing" },
  { path = { "UICommon", "CreateRedCloseButton" }, message = "isiLive: UICommon.CreateRedCloseButton missing" },
  { path = { "UICommon", "CreatePrivateTooltip" }, message = "isiLive: UICommon.CreatePrivateTooltip missing" },
  { path = { "UICommon", "PreparePrivateTooltip" }, message = "isiLive: UICommon.PreparePrivateTooltip missing" },
  { path = { "UICommon", "HidePrivateTooltip" }, message = "isiLive: UICommon.HidePrivateTooltip missing" },
  { path = { "Notice", "CreateCenterNotice" }, message = "isiLive: Notice.CreateCenterNotice missing" },
  { path = { "Notice", "CreatePortalNavigatorNotice" }, message = "isiLive: Notice.CreatePortalNavigatorNotice missing" },
  { path = { "Status", "CreateController" }, message = "isiLive: Status.CreateController missing" },
  { path = { "QueueDebug", "CreateController" }, message = "isiLive: QueueDebug.CreateController missing" },
  { path = { "RuntimeLog", "CreateController" }, message = "isiLive: RuntimeLog.CreateController missing" },
  { path = { "TestMode", "CreateController" }, message = "isiLive: TestMode.CreateController missing" },
  { path = { "RosterPanel", "CreateController" }, message = "isiLive: RosterPanel.CreateController missing" },
  { path = { "Stats", "CreateController" }, message = "isiLive: Stats.CreateController missing" },
  { path = { "SpellUtils", "GetSpellCooldownSafe" }, message = "isiLive: SpellUtils.GetSpellCooldownSafe missing" },
  { path = { "SpellUtils", "ApplyCooldownFrameSafe" }, message = "isiLive: SpellUtils.ApplyCooldownFrameSafe missing" },
  { path = { "SpellUtils", "IsSpellKnownSafe" }, message = "isiLive: SpellUtils.IsSpellKnownSafe missing" },
  {
    path = { "SpellUtils", "GetTeleportCooldownRemaining" },
    message = "isiLive: SpellUtils.GetTeleportCooldownRemaining missing",
  },
  { path = { "SpellUtils", "FormatCooldownSeconds" }, message = "isiLive: SpellUtils.FormatCooldownSeconds missing" },
  { path = { "Bindings", "CreateController" }, message = "isiLive: Bindings.CreateController missing" },
  { path = { "RuntimeState", "CreateController" }, message = "isiLive: RuntimeState.CreateController missing" },
  {
    path = { "EventUtils", "IsNegativeApplicationStatusEvent" },
    message = "isiLive: EventUtils.IsNegativeApplicationStatusEvent missing",
  },
  {
    path = { "EventHandlersQueueLifecycle", "BuildHandlers" },
    message = "isiLive: EventHandlersQueueLifecycle.BuildHandlers missing",
  },
  {
    path = { "EventHandlersChallengeLifecycle", "BuildHandlers" },
    message = "isiLive: EventHandlersChallengeLifecycle.BuildHandlers missing",
  },
  {
    path = { "EventHandlersRuntimeLifecycle", "BuildHandlers" },
    message = "isiLive: EventHandlersRuntimeLifecycle.BuildHandlers missing",
  },
  { path = { "Bootstrap", "RegisterSlashCommands" }, message = "isiLive: Bootstrap.RegisterSlashCommands missing" },
  { path = { "Bootstrap", "CreateGatedOnEvent" }, message = "isiLive: Bootstrap.CreateGatedOnEvent missing" },
  { path = { "Bootstrap", "RegisterMainFrameEvents" }, message = "isiLive: Bootstrap.RegisterMainFrameEvents missing" },
  { path = { "Bootstrap", "BindMainFrameScripts" }, message = "isiLive: Bootstrap.BindMainFrameScripts missing" },
  {
    path = { "ControllerWiring", "CreateGroupController" },
    message = "isiLive: ControllerWiring.CreateGroupController missing",
  },
  {
    path = { "ControllerWiring", "CreateGroupControllerFromContext" },
    message = "isiLive: ControllerWiring.CreateGroupControllerFromContext missing",
  },
  {
    path = { "ControllerWiring", "CreateEventHandlersController" },
    message = "isiLive: ControllerWiring.CreateEventHandlersController missing",
  },
  {
    path = { "ControllerWiring", "CreateEventHandlersControllerFromContext" },
    message = "isiLive: ControllerWiring.CreateEventHandlersControllerFromContext missing",
  },
  { path = { "LeaderWatch", "CreateController" }, message = "isiLive: LeaderWatch.CreateController missing" },
  {
    path = { "ConfigBuilders", "BuildRefreshControllerOpts" },
    message = "isiLive: ConfigBuilders.BuildRefreshControllerOpts missing",
  },
  { path = { "FrameBridge", "CreateContext" }, message = "isiLive: FrameBridge.CreateContext missing" },
  { path = { "ContextHelpers", "GetAddonVersionRaw" }, message = "isiLive: ContextHelpers.GetAddonVersionRaw missing" },
  { path = { "RuntimeSetup", "Configure" }, message = "isiLive: RuntimeSetup.Configure missing" },
  { path = { "ControllerInit", "CreateControllers" }, message = "isiLive: ControllerInit.CreateControllers missing" },
  {
    path = { "Teleport", "ResolveTeleportSpellID" },
    message = "isiLive: Teleport.ResolveTeleportSpellID missing",
  },
  {
    path = { "Teleport", "BuildTeleportEntries" },
    message = "isiLive: Teleport.BuildTeleportEntries missing",
  },
  {
    path = { "Teleport", "GetDungeonShortCode" },
    message = "isiLive: Teleport.GetDungeonShortCode missing",
  },
  { path = { "TeleportUI", "CreateController" }, message = "isiLive: TeleportUI.CreateController missing" },
  { path = { "TeleportDebug", "CreateController" }, message = "isiLive: TeleportDebug.CreateController missing" },
}

local function ResolvePath(root, path)
  local value = root
  for i = 1, #path do
    if type(value) ~= "table" then
      return nil
    end
    value = value[path[i]]
  end
  return value
end

function Guards.Validate(root)
  root = root or addonTable

  for _, entry in ipairs(REQUIRED_MODULES) do
    assert(root[entry.key], string.format("isiLive: missing module %s (%s)", entry.key, entry.file))
  end

  for _, entry in ipairs(REQUIRED_FUNCTIONS) do
    local value = ResolvePath(root, entry.path)
    assert(type(value) == "function", entry.message)
  end
end
