local ioLib = rawget(_G, "io")

local FILE_PATHS = {
  ["isiLive_validation_helpers.lua"] = "core/isiLive_validation_helpers.lua",
  ["isiLive_string_utils.lua"] = "core/isiLive_string_utils.lua",
  ["isiLive_sound_utils.lua"] = "core/isiLive_sound_utils.lua",
  ["isiLive_event_utils.lua"] = "core/isiLive_event_utils.lua",
  ["isiLive_runtime_state.lua"] = "core/isiLive_runtime_state.lua",
  ["isiLive_bootstrap.lua"] = "core/isiLive_bootstrap.lua",
  ["isiLive_context_helpers.lua"] = "core/isiLive_context_helpers.lua",
  ["isiLive_runtime_setup.lua"] = "core/isiLive_runtime_setup.lua",
  ["isiLive_log_buffer.lua"] = "core/isiLive_log_buffer.lua",
  ["isiLive_runtime_log.lua"] = "core/isiLive_runtime_log.lua",
  ["isiLive_guards.lua"] = "core/isiLive_guards.lua",
  ["realm_language_data.lua"] = "locale/realm_language_data.lua",
  ["isiLive_languages.lua"] = "locale/isiLive_languages.lua",
  ["isiLive_locale.lua"] = "locale/isiLive_locale.lua",
  ["isiLive_texts.lua"] = "locale/isiLive_texts.lua",
  ["isiLive_spell_utils.lua"] = "game/isiLive_spell_utils.lua",
  ["isiLive_cd_tracker.lua"] = "game/isiLive_cd_tracker.lua",
  ["isiLive_season_data.lua"] = "game/isiLive_season_data.lua",
  ["isiLive_teleport.lua"] = "game/isiLive_teleport.lua",
  ["isiLive_teleport_debug.lua"] = "ui/isiLive_teleport_debug.lua",
  ["isiLive_units.lua"] = "game/isiLive_units.lua",
  ["isiLive_mplus_timer.lua"] = "game/isiLive_mplus_timer.lua",
  ["isiLive_kick_tracker.lua"] = "game/isiLive_kick_tracker.lua",
  ["isiLive_bindings.lua"] = "ui/isiLive_bindings.lua",
  ["isiLive_ui_common.lua"] = "ui/isiLive_ui_common.lua",
  ["isiLive_teleport_ui.lua"] = "ui/isiLive_teleport_ui.lua",
  ["isiLive_notice.lua"] = "ui/isiLive_notice.lua",
  ["isiLive_status.lua"] = "ui/isiLive_status.lua",
  ["isiLive_roster.lua"] = "ui/isiLive_roster.lua",
  ["isiLive_roster_tooltip.lua"] = "ui/isiLive_roster_tooltip.lua",
  ["isiLive_roster_layout.lua"] = "ui/isiLive_roster_layout.lua",
  ["isiLive_roster_panel.lua"] = "ui/isiLive_roster_panel.lua",
  ["isiLive_ui.lua"] = "ui/isiLive_ui.lua",
  ["isiLive_settings.lua"] = "ui/isiLive_settings.lua",
  ["isiLive_leader_watch.lua"] = "logic/isiLive_leader_watch.lua",
  ["isiLive_demo.lua"] = "logic/isiLive_demo.lua",
  ["isiLive_test_mode.lua"] = "logic/isiLive_test_mode.lua",
  ["isiLive_sync.lua"] = "logic/isiLive_sync.lua",
  ["isiLive_keysync.lua"] = "logic/isiLive_keysync.lua",
  ["isiLive_refresh.lua"] = "logic/isiLive_refresh.lua",
  ["isiLive_highlight.lua"] = "logic/isiLive_highlight.lua",
  ["isiLive_group.lua"] = "logic/isiLive_group.lua",
  ["isiLive_queue.lua"] = "logic/isiLive_queue.lua",
  ["isiLive_queue_debug.lua"] = "logic/isiLive_queue_debug.lua",
  ["isiLive_queue_flow.lua"] = "logic/isiLive_queue_flow.lua",
  ["isiLive_stats.lua"] = "logic/isiLive_stats.lua",
  ["isiLive_inspect.lua"] = "logic/isiLive_inspect.lua",
  ["isiLive_events.lua"] = "logic/isiLive_events.lua",
  ["isiLive_event_handlers_queue.lua"] = "logic/isiLive_event_handlers_queue.lua",
  ["isiLive_event_handlers_challenge.lua"] = "logic/isiLive_event_handlers_challenge.lua",
  ["isiLive_event_handlers_runtime.lua"] = "logic/isiLive_event_handlers_runtime.lua",
  ["isiLive_event_handlers.lua"] = "logic/isiLive_event_handlers.lua",
  ["isiLive_commands.lua"] = "logic/isiLive_commands.lua",
  ["isiLive_controller_wiring.lua"] = "factory/isiLive_controller_wiring.lua",
  ["isiLive_config_builders.lua"] = "factory/isiLive_config_builders.lua",
  ["isiLive_frame_bridge.lua"] = "factory/isiLive_frame_bridge.lua",
  ["isiLive_controller_init.lua"] = "factory/isiLive_controller_init.lua",
  ["isiLive_factory_frame_bridge.lua"] = "factory/isiLive_factory_frame_bridge.lua",
  ["isiLive_factory_controllers.lua"] = "factory/isiLive_factory_controllers.lua",
  ["isiLive_factory.lua"] = "factory/isiLive_factory.lua",
  ["ARCHITECTURE.md"] = "docs/ARCHITECTURE.md",
  ["ARCHITECTURE_RULES.md"] = "docs/ARCHITECTURE_RULES.md",
  ["CHANGELOG.md"] = "docs/CHANGELOG.md",
  ["CHANGELOG_RELEASE.md"] = "CHANGELOG_RELEASE.md",
  ["RELEASE.md"] = "docs/RELEASE.md",
  ["RULES.md"] = "docs/RULES.md",
  ["RULES_LOGIC.md"] = "docs/RULES_LOGIC.md",
  ["USECASES.md"] = "docs/USECASES.md",
  ["WARTUNG.md"] = "docs/WARTUNG.md",
}

local function ReadFile(path)
  if type(ioLib) ~= "table" or type(ioLib.open) ~= "function" then
    error("io library unavailable for architecture source checks")
  end

  local resolved = FILE_PATHS[path] or path
  local file, openErr = ioLib.open(resolved, "rb")
  if not file then
    error(string.format("cannot read %s: %s", tostring(resolved), tostring(openErr)))
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

    AssertContains(
      Assert,
      content,
      "  - docs",
      ".pkgmeta must exclude the docs/ folder (contains WARTUNG.md) from CurseForge packaging"
    )
  end)

  test("Architecture pkgmeta excludes the full CHANGELOG from release packaging and uses a short link stub", function()
    local content = ReadFile(".pkgmeta")
    local changelogStub = ReadFile("CHANGELOG_RELEASE.md")

    AssertContains(
      Assert,
      content,
      "filename: CHANGELOG_RELEASE.md",
      ".pkgmeta must use the short changelog stub for release notes"
    )
    AssertContains(
      Assert,
      content,
      "  - docs",
      ".pkgmeta must exclude the docs/ folder (contains CHANGELOG.md) from CurseForge packaging"
    )
    AssertContains(
      Assert,
      changelogStub,
      "https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md",
      "release changelog stub must point back to the repository changelog"
    )
  end)

  test("Architecture pkgmeta keeps sound assets packaged for CurseForge release", function()
    local content = ReadFile(".pkgmeta")

    Assert.False(
      content:find("sounds", 1, true) ~= nil,
      ".pkgmeta must not ignore the sounds/ folder because release audio assets are shipped with the addon"
    )
  end)

  test("Architecture WARTUNG runbook references the required maintenance document chain", function()
    local content = ReadFile("WARTUNG.md")

    AssertContains(Assert, content, "CHANGELOG.md", "WARTUNG.md must reference CHANGELOG.md")
    AssertContains(Assert, content, "TODO.md", "WARTUNG.md must reference TODO.md")
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

local function RegisterArchitectureAudioAndKickWiringTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Architecture group-join sound hook stays local to controller wiring", function()
    local wiringContent = ReadFile("isiLive_controller_wiring.lua")
    local groupContent = ReadFile("isiLive_group.lua")
    local leaderWatchContent = ReadFile("isiLive_leader_watch.lua")

    AssertContains(
      Assert,
      groupContent,
      "onGroupJoined = opts.onGroupJoined or function() end,",
      "Group controller must accept the optional group-join callback"
    )
    AssertContains(
      Assert,
      groupContent,
      "deps.onGroupJoined()",
      "Group controller must invoke the group-join callback on the first real join"
    )
    AssertContains(
      Assert,
      leaderWatchContent,
      'PlayKey("leader_transfer")',
      "LeaderWatch must route leader transfer audio through the registry key"
    )
    AssertContains(
      Assert,
      wiringContent,
      "onGroupJoined = function()",
      "ControllerWiring must own the concrete group-join sound hook"
    )
    AssertContains(
      Assert,
      wiringContent,
      "PlayGroupJoin()",
      "ControllerWiring group-join sound hook must use the dedicated SynthChord helper"
    )

    local playCalls = 0
    local playedPath = nil
    local playedChannel = nil
    local now = 0
    local db = {}
    WithGlobals({
      IsiLiveDB = db,
      GetTime = function()
        return now
      end,
      PlaySoundFile = function(path, channel)
        playCalls = playCalls + 1
        playedPath = path
        playedChannel = channel
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.NotNil(addon.SoundUtils, "sound utils module should load")
      Assert.NotNil(addon.SoundUtils.Registry, "sound utils should expose a sound registry")
      Assert.NotNil(addon.SoundUtils.SettingsOrder, "sound utils should expose a stable settings order")
      Assert.NotNil(addon.SoundUtils.GetEntry, "sound utils should expose a registry lookup helper")
      Assert.NotNil(addon.SoundUtils.HasKey, "sound utils should expose a registry presence helper")
      Assert.NotNil(addon.SoundUtils.IsEnabled, "sound utils should expose an enabled-state helper")
      Assert.NotNil(addon.SoundUtils.PlayKey, "sound utils should expose a key-based play helper")
      Assert.True(addon.SoundUtils.HasKey("leader_transfer"), "sound registry should include the leader-transfer key")
      Assert.True(addon.SoundUtils.HasKey("group_join"), "sound registry should include the group-join key")
      Assert.True(addon.SoundUtils.HasKey("portal_available"), "sound registry should include the portal key")
      local leaderEntry = addon.SoundUtils.GetEntry("leader_transfer")
      Assert.NotNil(leaderEntry, "leader-transfer entry should exist")
      Assert.Equal(
        leaderEntry.file,
        "Interface\\AddOns\\isiLive\\sounds\\CartoonVoiceBaritone.ogg",
        "leader-transfer entry should point at the transfer asset"
      )
      Assert.True(leaderEntry.defaultEnabled, "leader-transfer sound should default to enabled")
      Assert.Equal(
        leaderEntry.settingKey,
        "soundLeadEnabled",
        "leader-transfer sound should map to the lead-enabled setting key"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("leader_transfer"),
        "leader-transfer sound should be enabled by default when no DB override exists"
      )
      local groupEntry = addon.SoundUtils.GetEntry("group_join")
      Assert.NotNil(groupEntry, "group-join entry should exist")
      Assert.Equal(
        groupEntry.settingKey,
        "soundGroupJoinEnabled",
        "group-join sound should map to the group-join setting key"
      )
      Assert.False(
        addon.SoundUtils.IsEnabled("group_join"),
        "group-join sound should remain disabled by default when no DB override exists"
      )
      local portalEntry = addon.SoundUtils.GetEntry("portal_available")
      Assert.NotNil(portalEntry, "portal sound entry should exist")
      Assert.Equal(
        portalEntry.settingKey,
        "soundPortalAvailableEnabled",
        "portal sound should map to the portal-enabled setting key"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("portal_available"),
        "portal sound should default to enabled when no DB override exists"
      )
      Assert.NotNil(addon.SoundUtils.PlayGroupJoin, "sound utils should expose a dedicated group-join sound helper")
      Assert.NotNil(addon.SoundUtils.PlayPortalAvailable, "sound utils should expose a dedicated portal sound helper")
      addon.SoundUtils.PlayKey("leader_transfer")
      Assert.Equal(playCalls, 1, "leader-transfer sound helper should play exactly once")
      Assert.Equal(
        playedPath,
        "Interface\\AddOns\\isiLive\\sounds\\CartoonVoiceBaritone.ogg",
        "leader-transfer sound helper should use the transfer asset"
      )
      Assert.Equal(playedChannel, "SFX", "leader-transfer sound helper should use the SFX channel")
      db.soundGroupJoinEnabled = true
      addon.SoundUtils.PlayGroupJoin()
      Assert.Equal(playCalls, 2, "group-join sound helper should play exactly once after the leader sound")
      Assert.Equal(
        playedPath,
        "Interface\\AddOns\\isiLive\\sounds\\SynthChord.ogg",
        "group-join sound helper should use the SynthChord asset"
      )
      Assert.Equal(playedChannel, "SFX", "group-join sound helper should use the SFX channel")
      addon.SoundUtils.PlayPortalAvailable()
      Assert.Equal(playCalls, 3, "portal sound helper should play exactly once after the group sound")
      Assert.Equal(
        playedPath,
        "Interface\\AddOns\\isiLive\\sounds\\Portal.ogg",
        "portal sound helper should use the Portal asset"
      )
      Assert.Equal(playedChannel, "SFX", "portal sound helper should use the SFX channel")

      db.soundLeadEnabled = false
      db.soundGroupJoinEnabled = true
      db.soundPortalAvailableEnabled = false
      now = 2
      playCalls = 0
      addon.SoundUtils.PlayKey("leader_transfer")
      addon.SoundUtils.PlayGroupJoin()
      addon.SoundUtils.PlayPortalAvailable()
      Assert.Equal(playCalls, 1, "only the enabled group-join sound should play when settings are toggled")
      Assert.Equal(
        playedPath,
        "Interface\\AddOns\\isiLive\\sounds\\SynthChord.ogg",
        "enabled group-join sound should remain the only played asset"
      )
    end)
  end)

  test("Architecture kick tracker uses lightweight kick-column refresh hooks", function()
    local helpersContent = ReadFile("isiLive_factory_controllers.lua")
    local rosterPanelContent = ReadFile("isiLive_roster_panel.lua")

    AssertContains(
      Assert,
      helpersContent,
      'castFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")',
      "factory kick tracking must refresh spell resolution on specialization changes"
    )
    AssertContains(
      Assert,
      helpersContent,
      'castFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")',
      "factory kick tracking must also watch pet interrupt casts"
    )
    AssertContains(
      Assert,
      helpersContent,
      'castFrame:RegisterUnitEvent("UNIT_PET", "player")',
      "factory kick tracking must refresh interrupt availability when the player's pet changes"
    )
    AssertContains(
      Assert,
      helpersContent,
      "ctx.rosterPanelController.RefreshKickColumn()",
      "factory kick tracking must use the dedicated roster kick refresh path"
    )
    AssertContains(
      Assert,
      rosterPanelContent,
      "function controller.RefreshKickColumn()",
      "RosterPanel must expose a dedicated kick-column refresh helper"
    )
    AssertContains(
      Assert,
      rosterPanelContent,
      'cell:SetText("|cff44ff44ready|r")',
      "RosterPanel kick refresh helper must render the ready state in green"
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

local function RegisterArchitectureWorkflowTests(test, Assert)
  test("Architecture GitHub Lua Check workflow keeps CI validation steps wired", function()
    local workflowContent = ReadFile(".github/workflows/lua-check.yml")

    AssertContains(Assert, workflowContent, "name: Lua Check", "workflow must keep the Lua Check name")
    AssertContains(
      Assert,
      workflowContent,
      'branches: ["main"]',
      "workflow must run on push and pull_request against main"
    )
    AssertContains(
      Assert,
      workflowContent,
      "uses: JohnnyMorganz/stylua-action@v4",
      "workflow must keep the StyLua check step"
    )
    AssertContains(
      Assert,
      workflowContent,
      'luacheck --exclude-files ".luarocks/**" -- .',
      "workflow must keep the luacheck step"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/lua_metrics_check.lua",
      "workflow must keep the Lua metrics step"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/validate_usecases.lua",
      "workflow must keep deterministic usecase and rules validation"
    )
    AssertContains(Assert, workflowContent, "Lua Syntax Check", "workflow must keep the syntax validation step")
  end)

  test("Architecture local CI preflight mirrors the GitHub Lua Check workflow", function()
    local workflowContent = ReadFile(".github/workflows/lua-check.yml")
    local localPreflightContent = ReadFile("tools/validate_ci_local.ps1")
    local luacheckShimContent = ReadFile("tools/luacheck.cmd")

    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "StyLua (check)" "stylua --check ."',
      "local preflight must run the same StyLua check as the workflow"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      '$env:PATH = "$PSScriptRoot;$env:PATH"',
      "local preflight must prefer the repo-local luacheck shim over the LuaRocks script"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      "function Invoke-LuaRocksCommand($label, $name, [string[]]$arguments) {",
      "local preflight must route LuaRocks tools through an explicit launcher"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-LuaRocksCommand "Luacheck" "luacheck" @("--exclude-files", ".luarocks/**", "--", ".")',
      "local preflight must run luacheck through the launcher instead of invoking the bare script"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Write-Step "Lua Syntax Check"',
      "local preflight must keep the same Lua syntax check phase as the workflow"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Lua Metrics Check" "lua tools/lua_metrics_check.lua"',
      "local preflight must run the same Lua metrics check as the workflow"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Deterministic Usecase + Rules Logic Validation" "lua tools/validate_usecases.lua"',
      "local preflight must run the same deterministic validation step as the workflow"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Write-Host "Local CI preflight passed."',
      "local preflight must report success after all workflow-equivalent checks finish"
    )
    AssertContains(
      Assert,
      workflowContent,
      "Lua Metrics Check",
      "workflow must still define the metrics step that the local preflight mirrors"
    )
    AssertContains(
      Assert,
      luacheckShimContent,
      'set "LUACHECK_SCRIPT=%APPDATA%\\luarocks\\bin\\luacheck"',
      "repo-local luacheck shim must resolve the LuaRocks script explicitly"
    )
    AssertContains(
      Assert,
      luacheckShimContent,
      'lua "%LUACHECK_SCRIPT%" %*',
      "repo-local luacheck shim must launch the LuaRocks script through lua"
    )
  end)

  test("Architecture local CI wrapper forwards directly into the preflight script", function()
    local wrapperContent = ReadFile("tools/run_local_ci.ps1")

    AssertContains(Assert, wrapperContent, "param(", "local CI wrapper must accept the same optional install switch")
    AssertContains(
      Assert,
      wrapperContent,
      "[switch]$InstallLuaRocksDeps",
      "local CI wrapper must forward the optional LuaRocks installation flag"
    )
    AssertContains(
      Assert,
      wrapperContent,
      'Join-Path $PSScriptRoot "validate_ci_local.ps1"',
      "local CI wrapper must target the validated preflight script"
    )
    AssertContains(
      Assert,
      wrapperContent,
      "& $scriptPath @PSBoundParameters",
      "local CI wrapper must delegate execution without adding parallel logic"
    )
  end)

  test("Architecture local CI shorthand wrapper forwards into the local CI wrapper", function()
    local shortcutContent = ReadFile("tools/check.ps1")

    AssertContains(Assert, shortcutContent, "param(", "local CI shortcut must accept the install switch")
    AssertContains(
      Assert,
      shortcutContent,
      "[switch]$InstallLuaRocksDeps",
      "local CI shortcut must forward the optional LuaRocks installation flag"
    )
    AssertContains(
      Assert,
      shortcutContent,
      'Join-Path $PSScriptRoot "run_local_ci.ps1"',
      "local CI shortcut must target the local CI wrapper"
    )
    AssertContains(
      Assert,
      shortcutContent,
      "& $scriptPath @PSBoundParameters",
      "local CI shortcut must delegate execution without adding parallel logic"
    )
  end)

  test("Architecture local CI cmd wrapper forwards into the PowerShell shortcut", function()
    local cmdWrapperContent = ReadFile("tools/check.cmd")

    AssertContains(
      Assert,
      cmdWrapperContent,
      'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check.ps1" %*',
      "cmd wrapper must launch the PowerShell shortcut with forwarded args"
    )
    AssertContains(
      Assert,
      cmdWrapperContent,
      "exit /b %ERRORLEVEL%",
      "cmd wrapper must forward the exit code from the PowerShell shortcut"
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
    Assert.Equal(
      type(state.GetPendingPostChallengeRefresh),
      "function",
      "RuntimeState must expose GetPendingPostChallengeRefresh"
    )
    Assert.Equal(
      type(state.SetPendingPostChallengeRefresh),
      "function",
      "RuntimeState must expose SetPendingPostChallengeRefresh"
    )
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
  RegisterArchitectureAudioAndKickWiringTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
  RegisterArchitectureNoticeTypographyTests(test, ctx.assert)
  RegisterArchitectureWorkflowTests(test, ctx.assert)
  RegisterArchitectureModuleApiTests(test, ctx.assert, ctx.load_modules)
end
