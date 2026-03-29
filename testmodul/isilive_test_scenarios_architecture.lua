local ioLib = rawget(_G, "io")

local function ReadFile(path)
  if type(ioLib) ~= "table" or type(ioLib.open) ~= "function" then
    error("io library unavailable for architecture source checks")
  end

  local file, openErr = ioLib.open(path, "rb")
  if not file then
    error(string.format("cannot read %s: %s", tostring(path), tostring(openErr)))
  end

  local content = file:read("*a")
  file:close()
  return content or ""
end

local function AssertContains(Assert, haystack, needle, message)
  Assert.True(haystack:find(needle, 1, true) ~= nil, message)
end

local function AssertNotContains(Assert, haystack, needle, message)
  Assert.True(haystack:find(needle, 1, true) == nil, message)
end

local function RegisterArchitectureSourceBoundaryTests(test, Assert)
  test("Architecture root wires runtime through RuntimeState and RuntimeSetup", function()
    local contextContent = ReadFile("isiLive_factory_frame_bridge.lua")
    local factoryContent = ReadFile("isiLive_factory.lua")

    AssertContains(
      Assert,
      contextContent,
      "local runtimeState = isiLiveRuntimeState.CreateController()",
      "isiLive_factory_frame_bridge.lua must instantiate RuntimeState centrally"
    )
    AssertContains(
      Assert,
      factoryContent,
      "local runtimeSetupResult = isiLiveRuntimeSetup.Configure({",
      "isiLive_factory.lua must delegate final assembly to RuntimeSetup.Configure"
    )
    AssertNotContains(
      Assert,
      factoryContent,
      "isiLiveEventHandlers.CreateController(",
      "isiLive_factory.lua must not instantiate EventHandlers directly"
    )
    AssertNotContains(
      Assert,
      factoryContent,
      "isiLiveGroup.CreateController(",
      "isiLive_factory.lua must not instantiate Group directly"
    )
  end)

  test("Architecture event handler aggregator uses split lifecycle modules", function()
    local content = ReadFile("isiLive_event_handlers.lua")

    AssertContains(
      Assert,
      content,
      'RequireLifecycleModule(RuntimeLifecycle, "EventHandlersRuntimeLifecycle").BuildHandlers(ctx)',
      "event handler aggregator must include runtime lifecycle module"
    )
    AssertContains(
      Assert,
      content,
      'RequireLifecycleModule(QueueLifecycle, "EventHandlersQueueLifecycle").BuildHandlers(ctx)',
      "event handler aggregator must include queue lifecycle module"
    )
    AssertContains(
      Assert,
      content,
      'RequireLifecycleModule(ChallengeLifecycle, "EventHandlersChallengeLifecycle").BuildHandlers(ctx)',
      "event handler aggregator must include challenge lifecycle module"
    )
    AssertNotContains(
      Assert,
      content,
      "READY_CHECK = function",
      "event handler aggregator must not inline challenge event handlers"
    )
    AssertNotContains(
      Assert,
      content,
      "ADDON_LOADED =",
      "event handler aggregator must not inline runtime event handlers"
    )
  end)

  test("Architecture runtime setup uses context-based wiring factories", function()
    local content = ReadFile("isiLive_runtime_setup.lua")

    AssertContains(
      Assert,
      content,
      "controllerWiring.CreateGroupControllerFromContext(groupModule, ctx)",
      "RuntimeSetup must create group controller via context-based wiring factory"
    )
    AssertContains(
      Assert,
      content,
      "controllerWiring.CreateEventHandlersControllerFromContext(eventHandlersModule, ctx)",
      "RuntimeSetup must create event handler controller via context-based wiring factory"
    )
    AssertNotContains(
      Assert,
      content,
      "BuildGroupControllerDeps(",
      "RuntimeSetup must not rebuild legacy group deps directly"
    )
    AssertNotContains(
      Assert,
      content,
      "BuildEventHandlersControllerDeps(",
      "RuntimeSetup must not rebuild legacy event deps directly"
    )
    AssertNotContains(
      Assert,
      content,
      "RuntimeSetup requires statsModule",
      "RuntimeSetup must not require dead statsModule wiring"
    )
    AssertNotContains(
      Assert,
      content,
      "gateOpts.allowWhenHidden",
      "RuntimeSetup must not mutate hidden-gate policy after config building"
    )
    AssertNotContains(
      Assert,
      content,
      "    groupController = groupController,",
      "RuntimeSetup must not expose unused group controller return payload"
    )
    AssertNotContains(
      Assert,
      content,
      "    leaderWatchController = leaderWatchController,",
      "RuntimeSetup must not expose unused leader-watch return payload"
    )
    AssertNotContains(
      Assert,
      content,
      "    gatedOnEvent = gatedOnEvent,",
      "RuntimeSetup must not expose unused gated handler return payload"
    )
    AssertNotContains(
      Assert,
      content,
      "    onEvent = ctx.onEvent,",
      "RuntimeSetup must not expose unused raw onEvent return payload"
    )
  end)

  test("Architecture hidden-gate policy is owned by config builders instead of runtime setup", function()
    local content = ReadFile("isiLive_config_builders.lua")

    AssertContains(Assert, content, "allowWhenHidden = {", "ConfigBuilders must define hidden-gate allowlist centrally")
    AssertContains(
      Assert,
      content,
      "CHAT_MSG_ADDON = true",
      "ConfigBuilders hidden-gate allowlist must include addon sync"
    )
    AssertContains(
      Assert,
      content,
      "GROUP_ROSTER_UPDATE = true",
      "ConfigBuilders hidden-gate allowlist must include roster sync"
    )
    AssertContains(
      Assert,
      content,
      "ZONE_CHANGED = true",
      "ConfigBuilders hidden-gate allowlist must include portal zone changes"
    )
    AssertContains(
      Assert,
      content,
      "ZONE_CHANGED_INDOORS = true",
      "ConfigBuilders hidden-gate allowlist must include indoor portal zone changes"
    )
    AssertContains(
      Assert,
      content,
      "ZONE_CHANGED_NEW_AREA = true",
      "ConfigBuilders hidden-gate allowlist must include area portal zone changes"
    )
    AssertContains(
      Assert,
      content,
      "BAG_UPDATE_DELAYED = true",
      "ConfigBuilders hidden-gate allowlist must include hidden owned-key change events"
    )
    AssertContains(
      Assert,
      content,
      "CHALLENGE_MODE_MAPS_UPDATE = true",
      "ConfigBuilders hidden-gate allowlist must include hidden keystone-map updates"
    )
    AssertContains(
      Assert,
      content,
      "PLAYER_EQUIPMENT_CHANGED = true",
      "ConfigBuilders hidden-gate allowlist must include hidden equipment change updates"
    )
    AssertContains(
      Assert,
      content,
      "PLAYER_SPECIALIZATION_CHANGED = true",
      "ConfigBuilders hidden-gate allowlist must include hidden specialization change updates"
    )
  end)

  test("Architecture root keeps challenge helper guarded and de-duplicates roster trigger helper", function()
    local content = ReadFile("isiLive_factory_controllers.lua")

    AssertContains(
      Assert,
      content,
      "if not (C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID) then",
      "isiLive_factory_controllers.lua must guard Blizzard challenge API access in root helper"
    )
    AssertContains(
      Assert,
      content,
      "local function TriggerGroupRosterUpdate()",
      "isiLive_factory_controllers.lua must centralize GROUP_ROSTER_UPDATE helper"
    )
    AssertNotContains(
      Assert,
      content,
      "triggerGroupRosterUpdate = function()",
      "isiLive_factory_controllers.lua must not keep duplicated inline GROUP_ROSTER_UPDATE closures"
    )
  end)

  test("Architecture combat utility ticker rerenders UI while Mythic+ timer is active", function()
    local content = ReadFile("isiLive_factory_controllers.lua")

    AssertContains(
      Assert,
      content,
      "local timerData = MplusTimer.GetTimerData()",
      "factory secondary controllers must read MplusTimer state during utility refreshes"
    )
    AssertContains(
      Assert,
      content,
      "if timerData and timerData.running then",
      "factory secondary controllers must gate the extra rerender on an active Mythic+ timer"
    )
    AssertContains(
      Assert,
      content,
      "ctx.UpdateUI()",
      "factory secondary controllers must rerender the UI when the Mythic+ timer is active"
    )
  end)

  test("Architecture root omits removed auto-mark state from runtime setup and roster panel wiring", function()
    local content = ReadFile("isiLive_factory.lua")

    AssertNotContains(
      Assert,
      content,
      "ctx.GetAutoMarkEnabled = function()",
      "isiLive_factory.lua must not expose removed GetAutoMarkEnabled state on the factory context"
    )
    AssertNotContains(
      Assert,
      content,
      "ctx.SetAutoMarkEnabled = function(value)",
      "isiLive_factory.lua must not expose removed SetAutoMarkEnabled state on the factory context"
    )
    AssertNotContains(
      Assert,
      content,
      "getAutoMarkEnabled = ctx.GetAutoMarkEnabled,",
      "isiLive_factory.lua must not forward removed getAutoMarkEnabled wiring"
    )
    AssertNotContains(
      Assert,
      content,
      "setAutoMarkEnabled = ctx.SetAutoMarkEnabled,",
      "isiLive_factory.lua must not forward removed setAutoMarkEnabled wiring"
    )
  end)

  test("Architecture controller wiring forwards recordRun into event handler config", function()
    local content = ReadFile("isiLive_controller_wiring.lua")

    AssertContains(
      Assert,
      content,
      'config.recordRun = type(deps.recordRun) == "function" and deps.recordRun or function() end',
      "ControllerWiring must forward recordRun into event handler config"
    )
    AssertContains(
      Assert,
      content,
      "recordRun = ctx.recordRun,",
      "ControllerWiring context builder must pass top-level recordRun into event handlers"
    )
  end)

  test("Architecture pkgmeta excludes WARTUNG maintenance doc from release package", function()
    local content = ReadFile(".pkgmeta")

    AssertContains(Assert, content, "  - WARTUNG.md", ".pkgmeta must exclude WARTUNG.md from CurseForge packaging")
  end)

  test("Architecture WARTUNG runbook references the required maintenance document chain", function()
    local content = ReadFile("WARTUNG.md")

    AssertContains(Assert, content, "CHANGELOG.md", "WARTUNG.md must reference CHANGELOG.md")
    AssertContains(Assert, content, "TODO.md", "WARTUNG.md must reference TODO.md")
    AssertContains(Assert, content, "TODO_RENAME.md", "WARTUNG.md must reference TODO_RENAME.md")
    AssertContains(Assert, content, "RULES_LOGIC.md", "WARTUNG.md must reference RULES_LOGIC.md")
    AssertContains(Assert, content, "ARCHITECTURE_RULES.md", "WARTUNG.md must reference ARCHITECTURE_RULES.md")
    AssertContains(Assert, content, "AGENTS.md", "WARTUNG.md must reference AGENTS.md")
    AssertContains(Assert, content, "README.md", "WARTUNG.md must reference README.md")
    AssertContains(Assert, content, "RELEASE.md", "WARTUNG.md must reference RELEASE.md")
    AssertContains(Assert, content, "USECASES.md", "WARTUNG.md must reference USECASES.md")
    AssertContains(Assert, content, "ARCHITECTURE.md", "WARTUNG.md must reference ARCHITECTURE.md")
  end)
end

local function RegisterArchitectureQueueWiringTests(test, Assert)
  test("Architecture queue join callbacks stay wired through runtime setup and controller wiring", function()
    local wiringContent = ReadFile("isiLive_controller_wiring.lua")
    local factoryContent = ReadFile("isiLive_factory.lua")
    local helpersContent = ReadFile("isiLive_factory_controllers.lua")

    AssertContains(
      Assert,
      helpersContent,
      "ctx.CaptureQueueJoinCandidate = function(...)",
      "factory runtime helpers must define CaptureQueueJoinCandidate directly"
    )
    AssertContains(
      Assert,
      helpersContent,
      "ctx.AnnounceQueuedGroupJoin = function()",
      "factory runtime helpers must define AnnounceQueuedGroupJoin directly"
    )
    AssertContains(
      Assert,
      factoryContent,
      "captureQueueJoinCandidate = ctx.CaptureQueueJoinCandidate,",
      "Factory runtime setup must forward queue capture callback"
    )
    AssertContains(
      Assert,
      factoryContent,
      "announceQueuedGroupJoin = ctx.AnnounceQueuedGroupJoin,",
      "Factory runtime setup must forward queue announce callback"
    )
    AssertContains(
      Assert,
      wiringContent,
      "captureQueueJoinCandidate = RequireFunction(",
      "ControllerWiring must require queue capture callback for group/event handler wiring"
    )
    AssertContains(
      Assert,
      wiringContent,
      "callbacks.captureQueueJoinCandidate",
      "ControllerWiring must forward queue capture callback into RequireFunction validation"
    )
    AssertContains(
      Assert,
      wiringContent,
      "announceQueuedGroupJoin = RequireFunction(",
      "ControllerWiring must require queue announce callback for group wiring"
    )
    AssertContains(
      Assert,
      wiringContent,
      "callbacks.announceQueuedGroupJoin",
      "ControllerWiring must forward queue announce callback into RequireFunction validation"
    )
    AssertContains(
      Assert,
      wiringContent,
      "captureQueueJoinCandidate = ctx.captureQueueJoinCandidate,",
      "ControllerWiring context builders must pass queue capture callback through"
    )
    AssertContains(
      Assert,
      wiringContent,
      "announceQueuedGroupJoin = ctx.announceQueuedGroupJoin,",
      "ControllerWiring context builders must pass queue announce callback through"
    )
  end)
end

local function RegisterArchitectureReadyCheckWiringTests(test, Assert)
  test("Architecture ready check refresh stays wired through runtime setup and controller wiring", function()
    local wiringContent = ReadFile("isiLive_controller_wiring.lua")
    local factoryContent = ReadFile("isiLive_factory.lua")
    local helpersContent = ReadFile("isiLive_factory_controllers.lua")
    local handlersContent = ReadFile("isiLive_event_handlers.lua")

    AssertContains(
      Assert,
      helpersContent,
      "ctx.RefreshReadyCheckUI = function()",
      "factory runtime helpers must define RefreshReadyCheckUI directly"
    )
    AssertContains(
      Assert,
      helpersContent,
      "ctx.rosterPanelController.RefreshReadyCheckState(ctx.GetRoster())",
      "factory ready-check helper must use the dedicated roster-panel refresh path"
    )
    AssertContains(
      Assert,
      factoryContent,
      "refreshReadyCheckUI = ctx.RefreshReadyCheckUI,",
      "Factory runtime setup must forward ready-check refresh callback"
    )
    AssertContains(
      Assert,
      wiringContent,
      'refreshReadyCheckUI = RequireFunction(callbacks.refreshReadyCheckUI, "callbacks.refreshReadyCheckUI")',
      "ControllerWiring must require ready-check refresh callback for event handlers"
    )
    AssertContains(
      Assert,
      wiringContent,
      "refreshReadyCheckUI = ctx.refreshReadyCheckUI,",
      "ControllerWiring context builder must pass ready-check refresh callback through"
    )
    AssertContains(
      Assert,
      handlersContent,
      'ctx.refreshReadyCheckUI = RequireFunction(opts.refreshReadyCheckUI, "refreshReadyCheckUI")',
      "EventHandlers must require the dedicated ready-check refresh callback"
    )
  end)
end

local function RegisterArchitectureLeaderMarkerWiringTests(test, Assert)
  test("Architecture leader marker stays wired through runtime setup and controller wiring", function()
    local wiringContent = ReadFile("isiLive_controller_wiring.lua")
    local factoryContent = ReadFile("isiLive_factory.lua")
    local groupContent = ReadFile("isiLive_group.lua")

    AssertContains(
      Assert,
      factoryContent,
      "unitIsGroupLeader = function(unit)",
      "Factory runtime setup must expose the UnitIsGroupLeader wrapper"
    )
    AssertContains(
      Assert,
      wiringContent,
      'unitIsGroupLeader = RequireFunction(deps.unitIsGroupLeader, "unitIsGroupLeader")',
      "ControllerWiring must require the leader-status callback for group wiring"
    )
    AssertContains(
      Assert,
      wiringContent,
      "unitIsGroupLeader = ctx.unitIsGroupLeader,",
      "ControllerWiring context builder must pass leader-status callback through"
    )
    AssertContains(
      Assert,
      groupContent,
      "unitIsGroupLeader = opts.unitIsGroupLeader or function(_unit)",
      "Group controller must accept the injected leader-status callback"
    )
  end)
end

local function RegisterArchitectureNoticeTypographyTests(test, Assert)
  test("Architecture center notice and portal entries share the same notice body typography helper", function()
    local noticeContent = ReadFile("isiLive_notice.lua")

    AssertContains(
      Assert,
      noticeContent,
      "local function CreatePortalStyleBodyText(frame, config)",
      "Notice module must define a shared portal-style body text helper"
    )
    AssertContains(
      Assert,
      noticeContent,
      "local function CreatePortalNavigatorEntry(frame, config, slot)\n"
        .. "  local text = CreatePortalStyleBodyText(frame, config)",
      "Notice module must build portal navigator entries from the shared body text helper"
    )
    AssertContains(
      Assert,
      noticeContent,
      "local function CreateCenterNoticeText(frame, config)\n"
        .. "  local text = CreatePortalStyleBodyText(frame, config)",
      "Notice module must build center notice body text from the shared body text helper"
    )
  end)
end

local function RegisterArchitectureModuleApiTests(test, Assert, LoadAddonModules)
  test("Architecture runtime state exposes shared mutable state API", function()
    local addon = LoadAddonModules({ "isiLive_runtime_state.lua" })
    local state = addon.RuntimeState.CreateController()

    Assert.Equal(type(state.GetRoster), "function", "RuntimeState must expose GetRoster")
    Assert.Equal(type(state.SetRoster), "function", "RuntimeState must expose SetRoster")
    Assert.Equal(type(state.GetPendingQueueJoinInfo), "function", "RuntimeState must expose GetPendingQueueJoinInfo")
    Assert.Equal(type(state.SetPendingQueueJoinInfo), "function", "RuntimeState must expose SetPendingQueueJoinInfo")
    Assert.Equal(type(state.GetActiveJoinedKeyMapID), "function", "RuntimeState must expose GetActiveJoinedKeyMapID")
    Assert.Equal(type(state.SetActiveJoinedKeyMapID), "function", "RuntimeState must expose SetActiveJoinedKeyMapID")
    Assert.Equal(type(state.GetLatestQueueState), "function", "RuntimeState must expose GetLatestQueueState")
    Assert.Equal(type(state.ClearLatestQueueTarget), "function", "RuntimeState must expose ClearLatestQueueTarget")
    Assert.Equal(type(state.IsReadyCheckActive), "function", "RuntimeState must expose IsReadyCheckActive")
    Assert.Equal(type(state.SetReadyCheckActive), "function", "RuntimeState must expose SetReadyCheckActive")
    Assert.Nil(state.GetAutoMarkEnabled, "RuntimeState must not expose removed GetAutoMarkEnabled state")
    Assert.Nil(state.SetAutoMarkEnabled, "RuntimeState must not expose removed SetAutoMarkEnabled state")
    Assert.Equal(
      type(state.GetRioBaselineByPlayerKey),
      "function",
      "RuntimeState must expose GetRioBaselineByPlayerKey"
    )
    Assert.Equal(type(state.ClearRioBaseline), "function", "RuntimeState must expose ClearRioBaseline")
  end)

  test("Architecture controller wiring exports context factories", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })

    Assert.Equal(
      type(addon.ControllerWiring.CreateGroupControllerFromContext),
      "function",
      "ControllerWiring must export CreateGroupControllerFromContext"
    )
    Assert.Equal(
      type(addon.ControllerWiring.CreateEventHandlersControllerFromContext),
      "function",
      "ControllerWiring must export CreateEventHandlersControllerFromContext"
    )
  end)

  test("Architecture config builders omit legacy event and group dependency builders", function()
    local addon = LoadAddonModules({ "isiLive_config_builders.lua" })
    local builders = addon.ConfigBuilders

    Assert.Nil(builders.BuildGroupControllerDeps, "ConfigBuilders must not expose legacy group deps builder")
    Assert.Nil(builders.BuildEventHandlersControllerDeps, "ConfigBuilders must not expose legacy event deps builder")
    Assert.Nil(builders.BuildEventState, "ConfigBuilders must not expose legacy event state builder")
    Assert.Nil(builders.BuildEventRefs, "ConfigBuilders must not expose legacy event refs builder")
    Assert.Nil(builders.BuildEventControllers, "ConfigBuilders must not expose legacy event controller builder")
    Assert.Nil(builders.BuildEventCallbacks, "ConfigBuilders must not expose legacy event callbacks builder")
  end)
end

return function(test, ctx)
  RegisterArchitectureSourceBoundaryTests(test, ctx.assert)
  RegisterArchitectureQueueWiringTests(test, ctx.assert)
  RegisterArchitectureReadyCheckWiringTests(test, ctx.assert)
  RegisterArchitectureLeaderMarkerWiringTests(test, ctx.assert)
  RegisterArchitectureNoticeTypographyTests(test, ctx.assert)
  RegisterArchitectureModuleApiTests(test, ctx.assert, ctx.load_modules)
end
