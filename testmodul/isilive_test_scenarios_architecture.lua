local ioLib = rawget(_G, "io")

-- Lua module paths come from the shared test harness (single source of truth).
-- Architecture tests extend this with docs / non-Lua assets they need to read.
---@diagnostic disable-next-line: undefined-global
local harnessChunk, harnessErr = loadfile("testmodul/isilive_test_harness.lua")
if not harnessChunk then
  error(string.format("cannot load test harness for architecture tests: %s", tostring(harnessErr)))
end
local Harness = harnessChunk()
if type(Harness) ~= "table" or type(Harness.FILE_PATHS) ~= "table" then
  error("test harness must expose FILE_PATHS table for architecture tests")
end

local FILE_PATHS = {}
for key, value in pairs(Harness.FILE_PATHS) do
  FILE_PATHS[key] = value
end
FILE_PATHS["ARCHITECTURE.md"] = "docs/ARCHITECTURE.md"
FILE_PATHS["ARCHITECTURE_RULES.md"] = "docs/ARCHITECTURE_RULES.md"
FILE_PATHS["CHANGELOG.md"] = "docs/CHANGELOG.md"
FILE_PATHS["CHANGELOG_RELEASE.md"] = "CHANGELOG_RELEASE.md"
FILE_PATHS["RELEASE.md"] = "docs/RELEASE.md"
FILE_PATHS["RULES.md"] = "docs/RULES.md"
FILE_PATHS["RULES_LOGIC.md"] = "docs/RULES_LOGIC.md"
FILE_PATHS["SEASON_INTAKE.md"] = "docs/SEASON_INTAKE.md"
FILE_PATHS["USECASES.md"] = "docs/USECASES.md"
FILE_PATHS["WARTUNG.md"] = "docs/WARTUNG.md"
FILE_PATHS["simulate_multi_invite_target_chain.lua"] = "tools/simulate_multi_invite_target_chain.lua"

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
      "local runtimeSetupResult = isiLiveRuntimeSetup.Configure(runtimeSetupContext)",
      "isiLive_factory.lua must delegate final assembly to RuntimeSetup.Configure"
        .. " through the named runtime setup context"
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
      "controllerWiring.CreateGroupControllerFromContext(groupModule, groupContext)",
      "RuntimeSetup must create group controller via the explicit group context wiring factory"
    )
    AssertContains(
      Assert,
      content,
      "controllerWiring.CreateEventHandlersControllerFromContext(eventHandlersModule, eventContext)",
      "RuntimeSetup must create event handler controller via the explicit event context wiring factory"
    )
    AssertContains(
      Assert,
      content,
      'local groupContext = RequireTable(ctx.groupControllerContext, "groupControllerContext")',
      "RuntimeSetup must require a narrow group-controller context bundle"
    )
    AssertContains(
      Assert,
      content,
      'local eventContext = RequireTable(ctx.eventHandlersContext, "eventHandlersContext")',
      "RuntimeSetup must require an event-handler context bundle"
    )
    AssertNotContains(
      Assert,
      content,
      "or ctx",
      "RuntimeSetup must not silently fall back from a named bundle to its composition root"
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

  test("Architecture factory passes named runtime setup controller contexts", function()
    local content = ReadFile("isiLive_factory.lua")

    AssertContains(
      Assert,
      content,
      "local function BuildRuntimeSetupGroupContext(ctx, runtimeState)",
      "factory root must build a named group-controller context for RuntimeSetup"
    )
    AssertContains(
      Assert,
      content,
      "groupControllerContext = BuildRuntimeSetupGroupContext(ctx, runtimeState)",
      "factory root must pass the group-controller context explicitly"
    )
    AssertContains(
      Assert,
      content,
      "eventHandlersContext = eventHandlersContext",
      "factory root must pass a separately constructed event-handler context explicitly"
    )
    AssertNotContains(
      Assert,
      content,
      "runtimeSetupContext.eventHandlersContext = runtimeSetupContext",
      "factory root must not self-reference its RuntimeSetup context as event dependencies"
    )
    AssertContains(
      Assert,
      content,
      "local runtimeSetupResult = isiLiveRuntimeSetup.Configure(runtimeSetupContext)",
      "factory root must hand RuntimeSetup the named context object"
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
    AssertContains(
      Assert,
      content,
      "PLAYER_ROLES_ASSIGNED = true",
      "ConfigBuilders hidden-gate allowlist must include hidden role-assignment updates"
    )
    AssertContains(
      Assert,
      content,
      "ROLE_CHANGED_INFORM = true",
      "ConfigBuilders hidden-gate allowlist must include hidden live role-change events"
    )
    AssertContains(
      Assert,
      content,
      "SPELL_UPDATE_CHARGES = true",
      "ConfigBuilders hidden-gate allowlist must include hidden BRes charge refresh events"
    )
    AssertContains(
      Assert,
      content,
      "UNIT_AURA = true",
      "ConfigBuilders hidden-gate allowlist must include hidden Bloodlust aura refresh events"
    )
  end)

  test("Architecture root keeps challenge helper guarded and de-duplicates roster trigger helper", function()
    local runtimeHelpersContent = ReadFile("isiLive_factory_runtime_helpers.lua")
    local controllersContent = ReadFile("isiLive_factory_controllers.lua")
    local refreshContent = ReadFile("isiLive_factory_refresh.lua")

    AssertContains(
      Assert,
      runtimeHelpersContent,
      'local challengeMode = rawget(_G, "C_ChallengeMode")',
      "isiLive_factory_runtime_helpers.lua must guard Blizzard challenge API access in root helper"
    )
    AssertContains(
      Assert,
      refreshContent,
      "local function TriggerGroupRosterUpdate()",
      "isiLive_factory_refresh.lua must centralize GROUP_ROSTER_UPDATE helper"
    )
    AssertNotContains(
      Assert,
      controllersContent,
      "triggerGroupRosterUpdate = function()",
      "isiLive_factory_controllers.lua must not keep duplicated inline GROUP_ROSTER_UPDATE closures"
    )
    AssertNotContains(
      Assert,
      refreshContent,
      "triggerGroupRosterUpdate = function()",
      "isiLive_factory_refresh.lua must not keep duplicated inline GROUP_ROSTER_UPDATE closures"
    )
  end)

  -- Pins the rawget(_G, "...") sweep finished after the 1ed372d / 1575a5b / 1a5612a
  -- commits. Each consumer must reach C_ChallengeMode / C_ChatInfo / InCombatLockdown
  -- through a sandbox-safe local cache, not a bare global lookup. Without these
  -- assertions a regression goes silently green because the bare-global form still
  -- runs in WoW itself (only Mock-_G tests would notice).
  test("Architecture C_ChallengeMode consumers route through rawget(_G) cache", function()
    local consumers = {
      "isiLive_status.lua",
      "isiLive_killtrack.lua",
      "isiLive_mplus_timer.lua",
      "isiLive_teleport.lua",
    }
    for _, file in ipairs(consumers) do
      local content = ReadFile(file)
      AssertContains(
        Assert,
        content,
        'rawget(_G, "C_ChallengeMode")',
        file .. " must cache C_ChallengeMode via rawget(_G, ...) before calling its API"
      )
      AssertNotContains(
        Assert,
        content,
        "pcall(C_ChallengeMode.",
        file .. " must not pcall bare C_ChallengeMode.X — go through the rawget cache"
      )
    end
  end)

  test("Architecture C_ChatInfo senders route through rawget(_G) cache", function()
    local senders = { "isiLive_controller_wiring.lua", "isiLive_sync.lua" }
    for _, file in ipairs(senders) do
      local content = ReadFile(file)
      AssertContains(
        Assert,
        content,
        'rawget(_G, "C_ChatInfo")',
        file .. " must cache C_ChatInfo via rawget(_G, ...) before sending addon messages"
      )
      AssertNotContains(
        Assert,
        content,
        "C_ChatInfo and C_ChatInfo.",
        file .. " must not lean on bare C_ChatInfo short-circuit chains"
      )
    end
  end)

  -- Pins the Phase 5 fix from commit 60f2236 against replica-drift. The
  -- target-dungeon-chat simulator must drive the group-leave path through
  -- the real production sequence (ClearAllState -> isInGroup flip ->
  -- numMembers=0 -> GROUP_ROSTER_UPDATE on re-accept), not a bare
  -- statusModel.inGroup=false flicker. Without these assertions a future
  -- edit to Phase 5 could silently regress to the pre-60f2236 shape and
  -- mask the same class of "info=nil reset never reached" bugs the fix
  -- was written to cover.
  -- Pins the PARTY_LEADER_CHANGED initial-convert guard: WoW fires PLC when
  -- the listing owner forms the freshly accepted group, BEFORE the first
  -- GROUP_ROSTER_UPDATE reports inGroup=true. The rosterEstablishedSinceAccept
  -- flag distinguishes that path from a genuine later handoff. Without these
  -- assertions a future refactor could drop one of the four trigger sites
  -- (set false on accept, set true on inGroup=true, reset on
  -- ClearAllStateImpl, read inside the PLC handler) and silently regress to
  -- the pre-fix shape where every PLC dropped the listing identity.
  test("Architecture lfg_detect pins the PLC initial-convert guard wiring", function()
    local content = ReadFile("isiLive_lfg_detect.lua")

    AssertContains(
      Assert,
      content,
      "local rosterEstablishedSinceAccept = false",
      "lfg_detect.lua must declare the rosterEstablishedSinceAccept flag at module scope"
    )
    AssertContains(
      Assert,
      content,
      "rosterEstablishedSinceAccept = false",
      "lfg_detect.lua must reset rosterEstablishedSinceAccept on accept (and clear)"
    )
    AssertContains(
      Assert,
      content,
      "rosterEstablishedSinceAccept = true",
      "lfg_detect.lua must arm rosterEstablishedSinceAccept once GROUP_ROSTER_UPDATE confirms inGroup=true"
    )
    AssertContains(
      Assert,
      content,
      "if not rosterEstablishedSinceAccept then",
      "lfg_detect.lua PARTY_LEADER_CHANGED handler must guard on rosterEstablishedSinceAccept before clearing"
    )
  end)

  test("Architecture target-dungeon-chat simulator Phase 5 mirrors the real group-leave sequence", function()
    local content = ReadFile("simulate_multi_invite_target_chain.lua")

    local phase5Start = content:find("Phase 5: end-of-cycle reset", 1, true)
    Assert.True(phase5Start ~= nil, "simulator must keep its Phase 5 header so the section is locatable")

    local phase5 = content:sub(phase5Start)
    AssertContains(
      Assert,
      phase5,
      "addon.LFGDetect.ClearAllState()",
      "Phase 5 must drop LFGDetect identity through the production ClearAllState path"
    )
    AssertContains(
      Assert,
      phase5,
      "isInGroup[1] = false",
      "Phase 5 must flip the IsInGroup stub to false before the reset announce"
    )
    AssertContains(
      Assert,
      phase5,
      "numMembers[1] = 0",
      "Phase 5 must empty the roster numMembers stub so the resolver collapses to nil"
    )
    AssertContains(
      Assert,
      phase5,
      'fire("GROUP_ROSTER_UPDATE")',
      "Phase 5 re-accept must fire GROUP_ROSTER_UPDATE so the resolver re-arms via real events"
    )
  end)

  test("Architecture InCombatLockdown consumers route through rawget(_G) cache", function()
    local consumers = { "isiLive_roster_layout.lua", "isiLive_notice.lua", "isiLive_teleport_ui.lua" }
    for _, file in ipairs(consumers) do
      local content = ReadFile(file)
      AssertContains(
        Assert,
        content,
        'rawget(_G, "InCombatLockdown")',
        file .. " must cache InCombatLockdown via rawget(_G, ...) instead of touching the bare global"
      )
      AssertNotContains(
        Assert,
        content,
        "InCombatLockdown and InCombatLockdown()",
        file .. " must not lean on bare InCombatLockdown short-circuit chains"
      )
    end
  end)

  test("Architecture secure button mutation surface is explicitly audited for combat and key safety", function()
    local audited = {
      ["game/isiLive_teleport.lua"] = {
        "pendingCombatUpdates",
        "PLAYER_REGEN_ENABLED",
        'rawget(_G, "InCombatLockdown")',
      },
      ["ui/isiLive_bindings.lua"] = {
        "pendingBindingApply",
        'rawget(_G, "InCombatLockdown")',
      },
      ["ui/isiLive_teleport_ui.lua"] = {
        "InsecureActionButtonTemplate",
        'rawget(_G, "InCombatLockdown")',
      },
      ["ui/isiLive_notice.lua"] = {
        "InsecureActionButtonTemplate",
        "pendingTeleportButtonVisible",
        'rawget(_G, "InCombatLockdown")',
      },
      ["ui/isiLive_roster_layout.lua"] = {
        "IsCombatLockdownActive",
        'rawget(_G, "InCombatLockdown")',
      },
      ["ui/isiLive_roster_panel.lua"] = {
        "pendingLeaderButtonUpdate",
        "IsInCombatLockdown",
      },
      ["ui/isiLive_roster_panel_chrome.lua"] = {
        "SecureActionButtonTemplate",
        'btn:SetAttribute("type", "worldmarker")',
      },
      ["ui/isiLive_roster_panel_render.lua"] = {
        "IsCombatLockdownActive",
        "row.roleButton:SetAttribute",
      },
      ["ui/isiLive_ui_game_menu.lua"] = {
        "IsPanelUISecureUpdateBlocked",
        "QueuePanelUISecureStateRefresh",
        "PLAYER_REGEN_ENABLED",
        "C_ChallengeMode",
      },
      ["ui/isiLive_ui_game_menu_panel.lua"] = { "skipInitialClickRegistration", "deps.isSecureUpdateBlocked" },
      ["ui/isiLive_ui_main_frame.lua"] = {
        "RegisterForClicks",
        'rawget(_G, "InCombatLockdown")',
        "lockMainFramePosition",
      },
      ["ui/isiLive_ui_common.lua"] = { "CreateActionButton", "RegisterForClicks", "ApplyActionButtonVisual" },
      ["factory/isiLive_factory_minimap.lua"] = { "RegisterForClicks" },
    }
    local checked = {}
    local surfaceMarkers = {
      "SecureActionButtonTemplate",
      "InsecureActionButtonTemplate",
      "SetAttribute",
      "RegisterForClicks",
    }
    local function StripLuaComments(content)
      content = content:gsub("%-%-%[%[.-%]%]", "")
      content = content:gsub("%-%-[^\r\n]*", "")
      return content
    end

    local function IsProductionLuaPath(path)
      return path:match("^core/.+%.lua$") ~= nil
        or path:match("^factory/.+%.lua$") ~= nil
        or path:match("^game/.+%.lua$") ~= nil
        or path:match("^logic/.+%.lua$") ~= nil
        or path:match("^ui/.+%.lua$") ~= nil
    end

    for _, resolvedPath in pairs(FILE_PATHS) do
      if IsProductionLuaPath(resolvedPath) then
        local content = StripLuaComments(ReadFile(resolvedPath))
        local hasSurface = false
        for _, marker in ipairs(surfaceMarkers) do
          if content:find(marker, 1, true) then
            hasSurface = true
            break
          end
        end
        if hasSurface then
          Assert.True(
            audited[resolvedPath] ~= nil,
            resolvedPath .. " touches secure/click mutation APIs and must be explicitly audited"
          )
          checked[resolvedPath] = true
        end
      end
    end

    for path, requiredMarkers in pairs(audited) do
      Assert.True(checked[path] == true, path .. " audit entry must still match a live secure/click mutation surface")
      local content = ReadFile(path)
      for _, marker in ipairs(requiredMarkers) do
        AssertContains(Assert, content, marker, path .. " must keep audited secure safety marker " .. marker)
      end
    end
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

  test("Architecture runtime log factory keeps the documented 800 entry cap", function()
    local content = ReadFile("factory/isiLive_factory_frame_bridge.lua")

    AssertContains(Assert, content, "maxEntries = 800", "runtime log factory must enforce the documented cap")
    AssertNotContains(Assert, content, "maxEntries = 10000", "runtime log factory must not restore the oversized cap")
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

  test("Architecture release packages exclude root maintenance TODO", function()
    local pkgmetaContent = ReadFile(".pkgmeta")
    local workflowContent = ReadFile(".github/workflows/release.yml")

    AssertContains(Assert, pkgmetaContent, "  - TODO.md", ".pkgmeta must exclude the root maintenance TODO")
    AssertContains(
      Assert,
      workflowContent,
      "|TODO.md|",
      "release workflow must exclude the root maintenance TODO from the WowUp package"
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
    local highlightCount = 0
    for line in changelogStub:gmatch("[^\r\n]+") do
      if line:match("^%- ") then
        highlightCount = highlightCount + 1
      end
    end
    Assert.True(
      highlightCount >= 3 and highlightCount <= 5,
      "release changelog stub must contain between three and five top-level highlights"
    )
  end)

  test("Architecture pkgmeta keeps sound assets packaged for CurseForge release", function()
    local content = ReadFile(".pkgmeta")

    Assert.False(
      content:find("sounds", 1, true) ~= nil,
      ".pkgmeta must not ignore the sounds/ folder because release audio assets are shipped with the addon"
    )
  end)

  test("Architecture gitignore keeps packaged sound assets trackable", function()
    local content = ReadFile(".gitignore")
    local soundFiles = {
      "BattleRezReady.wav",
      "BattleRezReady_deDE.wav",
      "BloodlustReady.wav",
      "BloodlustReady_deDE.wav",
      "PowerInfusionReceived.wav",
      "PowerInfusionReceived_deDE.wav",
      "HealerDied.wav",
      "HealerDied_deDE.wav",
      "Portal.ogg",
      "Portal_deDE.wav",
      "RoosterChickenCalls.ogg",
      "TankDied.wav",
      "TankDied_deDE.wav",
    }

    for _, soundFile in ipairs(soundFiles) do
      AssertContains(
        Assert,
        content,
        "!sounds/" .. soundFile,
        ".gitignore must allow sounds/"
          .. soundFile
          .. " to be tracked because release packages are built from git files"
      )
    end
  end)

  test("Architecture pkgmeta excludes root screenshot assets from release package", function()
    local content = ReadFile(".pkgmeta")
    local screenshots = {
      "isiLive.png",
      "isiLive_LFGBuffRating.png",
      "isiLive_MPlus_ui.png",
      "isiLive_M_ui.png",
      "isiLive_PortalNavigator.png",
      "isiLive_Statsbox.png",
      "isiLive_screenshot.png",
    }

    for _, screenshot in ipairs(screenshots) do
      AssertContains(
        Assert,
        content,
        "  - " .. screenshot,
        ".pkgmeta must exclude root screenshot asset " .. screenshot .. " from CurseForge packaging"
      )
    end
  end)

  test("Architecture release workflow excludes root screenshot assets from WowUp package", function()
    local content = ReadFile(".github/workflows/release.yml")
    local screenshots = {
      "isiLive.png",
      "isiLive_LFGBuffRating.png",
      "isiLive_MPlus_ui.png",
      "isiLive_M_ui.png",
      "isiLive_PortalNavigator.png",
      "isiLive_Statsbox.png",
      "isiLive_screenshot.png",
    }

    AssertContains(
      Assert,
      content,
      "Prepare GitHub/WowUp asset",
      "release workflow must keep a dedicated WowUp package preparation step"
    )
    for _, screenshot in ipairs(screenshots) do
      AssertContains(
        Assert,
        content,
        screenshot,
        "release workflow must exclude root screenshot asset " .. screenshot .. " from the WowUp package"
      )
    end
  end)

  test("Architecture release package ignore lists stay identical for CurseForge and WowUp", function()
    local pkgmetaContent = ReadFile(".pkgmeta")
    local workflowContent = ReadFile(".github/workflows/release.yml")
    local workflowLine = workflowContent:match("[^\n]*luacheck_output%.txt[^\n]*")

    Assert.NotNil(workflowLine, "release workflow must keep an explicit WowUp package exclusion line")

    local function normalize(entry)
      local directoryEntries = {
        [".github"] = true,
        [".githooks"] = true,
        [".vscode"] = true,
        [".claude"] = true,
        [".luarocks"] = true,
        ["docs"] = true,
        ["tools"] = true,
        ["testmodul"] = true,
      }

      if type(entry) ~= "string" or entry == "" then
        return nil
      end
      entry = entry:gsub("/%*$", "")
      if directoryEntries[entry] then
        return entry
      end
      return entry
    end

    local pkgmetaIgnores = {}
    for entry in pkgmetaContent:gmatch("\n%s+%-%s+([^\n]+)") do
      local normalized = normalize((entry:gsub("%s+$", "")))
      if normalized then
        pkgmetaIgnores[normalized] = true
      end
    end

    local workflowIgnores = {}
    for entry in workflowLine:gmatch("([^|%)]+)") do
      entry = entry:gsub("^%s+", ""):gsub("%s+$", "")
      local normalized = normalize(entry)
      if normalized and normalized ~= ".pkgmeta" then
        workflowIgnores[normalized] = true
      end
    end

    for entry in pairs(pkgmetaIgnores) do
      Assert.True(
        workflowIgnores[entry] == true,
        "WowUp package exclusions must include CurseForge exclusion " .. entry
      )
    end
    for entry in pairs(workflowIgnores) do
      Assert.True(pkgmetaIgnores[entry] == true, "CurseForge package exclusions must include WowUp exclusion " .. entry)
    end
  end)

  test("Architecture release workflow maps comma-separated TOC interfaces to CurseForge game versions", function()
    local content = ReadFile(".github/workflows/release.yml")

    AssertContains(
      Assert,
      content,
      "TOC_INTERFACES=\"$(awk -F': *' '/^## Interface:/ { print $2; exit }' isiLive.toc)\"",
      "release workflow must read the full TOC interface list"
    )
    AssertContains(Assert, content, "tr ',' '\\n'", "release workflow must split comma-separated TOC interfaces")
    AssertContains(
      Assert,
      content,
      "--argjson game_versions",
      "release workflow must pass parsed game versions as JSON"
    )
    AssertContains(
      Assert,
      content,
      "gameVersionNames: $game_versions",
      "CurseForge metadata must include every parsed TOC game version"
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
    local helpersContent = ReadFile("isiLive_factory_status_helpers.lua")

    AssertContains(
      Assert,
      helpersContent,
      "ctx.CaptureQueueJoinCandidate = function(...)",
      "factory status helpers must define CaptureQueueJoinCandidate directly"
    )
    AssertContains(
      Assert,
      helpersContent,
      "ctx.AnnounceQueuedGroupJoin = function()",
      "factory status helpers must define AnnounceQueuedGroupJoin directly"
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

local function RegisterArchitectureTeleportWiringTests(test, Assert)
  test("Architecture teleport column refresh uses the shared teleport highlight path", function()
    local factoryContent = ReadFile("isiLive_factory.lua")

    AssertContains(
      Assert,
      factoryContent,
      "onTeleportColumnsChange = function(_columns)",
      "Factory settings callback must still expose the teleport column handler"
    )
    AssertContains(
      Assert,
      factoryContent,
      "ctx.UpdateMPlusTeleportButton()",
      "Teleport column refresh must route through the shared highlight updater"
    )
    AssertNotContains(
      Assert,
      factoryContent,
      "ctx.teleportUIController.UpdateButtons(ctx.ResolveTeleportSpellID())",
      "Teleport column refresh must not bypass the shared highlight updater"
    )
  end)

  test("Architecture event-handler context threads the teleport UI controller", function()
    -- The season auto-switch rebuilds the M+ teleport button grid via
    -- controllers.teleport.BuildButtons(). That branch is a silent no-op unless
    -- the event-handler context exposes teleportUIController, so guard the field
    -- explicitly: without it the buttons stay stuck on the startup season while
    -- the portal navigator (a live-render path) already follows the new season.
    local factoryContent = ReadFile("isiLive_factory.lua")

    AssertContains(
      Assert,
      factoryContent,
      "teleportUIController = ctx.teleportUIController,",
      "eventHandlersContext must thread teleportUIController so season-switch BuildButtons is not a silent no-op"
    )
  end)

  test("Architecture ResolveLocalStatusTargetMapID prioritises LFG detected mapID", function()
    local controllersContent = ReadFile("isiLive_factory_status_helpers.lua")

    local resolverStart = controllersContent:find("ctx%.ResolveLocalStatusTargetMapID = function%(%)", 1, false)
    Assert.True(resolverStart ~= nil, "ResolveLocalStatusTargetMapID must still be defined in factory status helpers")
    local resolverEnd = resolverStart and controllersContent:find("GetLatestQueueState", resolverStart, true)
    Assert.True(
      resolverEnd ~= nil,
      "ResolveLocalStatusTargetMapID must still read queue state after LFGDetect priority"
    )
    local resolverBody = controllersContent:sub(resolverStart or 1, resolverEnd or -1)

    AssertContains(
      Assert,
      resolverBody,
      "addonTable.LFGDetect",
      "ResolveLocalStatusTargetMapID must consult LFGDetect before queue/listing state"
    )
    AssertContains(
      Assert,
      resolverBody,
      "lfgDetect.GetDetectedMapID()",
      "ResolveLocalStatusTargetMapID must read detectedMapID via GetDetectedMapID"
    )
  end)
end

local function RegisterArchitectureReadyCheckWiringTests(test, Assert)
  test("Architecture ready check refresh stays wired through runtime setup and controller wiring", function()
    local wiringContent = ReadFile("isiLive_controller_wiring.lua")
    local factoryContent = ReadFile("isiLive_factory.lua")
    local helpersContent = ReadFile("isiLive_factory_primary.lua")
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
    AssertContains(
      Assert,
      wiringContent,
      "config.playReadyCheckCompleteSound",
      "ControllerWiring must forward the ready-check-complete sound callback into event handlers"
    )
    AssertContains(
      Assert,
      wiringContent,
      "soundUtils.PlayReadyCheckComplete()",
      "ControllerWiring context builder must route ready-check-complete playback through SoundUtils"
    )
    AssertContains(
      Assert,
      handlersContent,
      "ctx.playReadyCheckCompleteSound = OptionalFunction(opts.playReadyCheckCompleteSound",
      "EventHandlers must accept the ready-check-complete sound callback"
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
    local commonContent = ReadFile("isiLive_notice_common.lua")
    local portalContent = ReadFile("isiLive_portal_navigator_notice.lua")
    local noticeContent = ReadFile("isiLive_notice.lua")
    AssertContains(
      Assert,
      commonContent,
      "function NoticeCommon.CreateBodyText(frame, config)",
      "NoticeCommon must own the shared notice body text helper"
    )
    AssertContains(
      Assert,
      portalContent,
      "local text = deps.createBodyText(frame, config)",
      "PortalNavigatorNotice must receive the shared body text helper"
    )
    AssertContains(
      Assert,
      noticeContent,
      "local CreatePortalStyleBodyText = NoticeCommon.CreateBodyText",
      "Notice must bind its body text path to NoticeCommon"
    )
    AssertContains(
      Assert,
      noticeContent,
      "local function CreateCenterNoticeText(frame, config)\n"
        .. "  local text = CreatePortalStyleBodyText(frame, config)",
      "Notice module must build center notice body text from the shared body text helper"
    )
  end)

  test("Architecture main-frame title bar applies a toolbar-safe text budget", function()
    local rosterPanelContent = ReadFile("isiLive_roster_panel.lua")

    AssertContains(
      Assert,
      rosterPanelContent,
      "local function ApplyTitleBudget()",
      "RosterPanel title bar must keep an explicit text-budget helper"
    )
    AssertContains(
      Assert,
      rosterPanelContent,
      "(frameWidth or FULL_FRAME_WIDTH) - 160",
      "RosterPanel title budget must reserve space for the right-side mode and toolbar buttons"
    )
    AssertContains(
      Assert,
      rosterPanelContent,
      "local TITLE_Y = -7",
      "RosterPanel title row must stay vertically aligned with the mode buttons"
    )
    AssertContains(
      Assert,
      rosterPanelContent,
      "ApplyFontStringSize(title, 12)",
      "RosterPanel title text must stay compact enough for the toolbar row"
    )
    AssertContains(
      Assert,
      rosterPanelContent,
      "ApplyFontStringSize(titleVersion, 12)",
      "RosterPanel version text must stay compact enough for the toolbar row"
    )
    AssertContains(
      Assert,
      rosterPanelContent,
      "ApplyFontStringSize(titleHint, 12)",
      "RosterPanel title hint text must stay compact enough for the toolbar row"
    )
    AssertContains(
      Assert,
      rosterPanelContent,
      "local titleWidth = math.max(56, (measureWidth and measureWidth(title)) or 56)",
      "RosterPanel title budget must keep the title fallback compact instead of pushing the version away"
    )
    AssertContains(
      Assert,
      rosterPanelContent,
      "local versionWidth = math.max(92, (measureWidth and measureWidth(titleVersion)) or 92)",
      "RosterPanel title budget must reserve enough width for the full version label"
    )
    AssertContains(
      Assert,
      rosterPanelContent,
      "titleHint:Hide()",
      "RosterPanel title budget must drop the hint before it collides with toolbar buttons"
    )
    AssertContains(
      Assert,
      rosterPanelContent,
      "ui.ApplyTitleBudget()",
      "RosterPanel localization refresh must reapply the title budget after locale text changes"
    )
  end)
end

local function RegisterArchitectureWorkflowTests(test, Assert)
  test("Architecture external workflow actions use immutable SHA pins with version comments", function()
    local workflowFiles = {
      ".github/workflows/inspect-mplus-season-preview.yml",
      ".github/workflows/lua-check.yml",
      ".github/workflows/pre-release.yml",
      ".github/workflows/release.yml",
      ".github/workflows/season-intake.yml",
      ".github/workflows/season-readiness.yml",
      ".github/workflows/sync-mplus-forces.yml",
    }

    for _, workflowFile in ipairs(workflowFiles) do
      local content = ReadFile(workflowFile)
      for line in content:gmatch("[^\r\n]+") do
        local actionRef = line:match("uses:%s+([^%s]+)")
        if actionRef and actionRef:sub(1, 2) ~= "./" then
          local sha = actionRef:match("@([0-9a-f]+)$")
          Assert.True(
            sha ~= nil and #sha == 40,
            workflowFile .. " external action must use a full 40-character commit SHA: " .. actionRef
          )
          Assert.True(
            line:match("#%s+v%d+") ~= nil,
            workflowFile .. " SHA pin must retain its human-readable major version comment"
          )
        end
      end
    end

    local dependabot = ReadFile(".github/dependabot.yml")
    AssertContains(
      Assert,
      dependabot,
      'package-ecosystem: "github-actions"',
      "Dependabot must keep immutable GitHub Action pins maintainable"
    )
  end)

  test("Architecture workflows use checkout v7.0.1", function()
    local workflowFiles = {
      ".github/workflows/inspect-mplus-season-preview.yml",
      ".github/workflows/lua-check.yml",
      ".github/workflows/pre-release.yml",
      ".github/workflows/release.yml",
      ".github/workflows/season-intake.yml",
      ".github/workflows/season-readiness.yml",
      ".github/workflows/sync-mplus-forces.yml",
    }
    local expectedCheckout = "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1"

    for _, workflowFile in ipairs(workflowFiles) do
      AssertContains(
        Assert,
        ReadFile(workflowFile),
        expectedCheckout,
        workflowFile .. " must use the verified checkout v7.0.1 SHA and matching version comment"
      )
    end
  end)

  test("Architecture GitHub Lua Check workflow keeps CI validation steps wired", function()
    local workflowContent = ReadFile(".github/workflows/lua-check.yml")
    local syncWorkflowContent = ReadFile(".github/workflows/sync-mplus-forces.yml")

    AssertContains(Assert, workflowContent, "name: Lua Check", "workflow must keep the Lua Check name")
    AssertContains(
      Assert,
      workflowContent,
      'branches: ["main"]',
      "workflow must run on push and pull_request against main"
    )
    AssertContains(Assert, workflowContent, "stylua --check .", "workflow must keep the StyLua check step")
    AssertContains(
      Assert,
      workflowContent,
      'luacheck --exclude-files ".luarocks/**" "tools/cache/**" -- .',
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
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/simulate_nameplate_keystart.lua all",
      "workflow must keep the nameplate key-start simulator gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/simulate_savedvariables_reload.lua",
      "workflow must keep the SavedVariables reload simulator gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/simulate_key_start_lifecycle.lua",
      "workflow must keep the key-start lifecycle simulator gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/simulate_hidden_sync_reload.lua",
      "workflow must keep the hidden-sync reload simulator gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/simulate_raid_party_cycle.lua",
      "workflow must keep the raid-party cycle simulator gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/simulate_lfg_join_target_chain.lua",
      "workflow must keep the LFG join target-chain simulator gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/simulate_reload_storm.lua",
      "workflow must keep the reload-storm simulator gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/check_sound_channel.lua",
      "workflow must keep the sound-channel gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/check_chat_color_safety.lua",
      "workflow must keep the chat-color-safety gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/check_wow_api_compliance.lua",
      "workflow must keep the WoW 12.0 API compliance gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/check_format_string_consistency.lua",
      "workflow must keep the format-string consistency gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/check_secret_value_guards.lua",
      "workflow must keep the secret-value guards gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/check_addon_message_size.lua",
      "workflow must keep the addon-message-size gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/check_button_label_length.lua",
      "workflow must keep the button-label-length gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/check_toc_file_list.lua",
      "workflow must keep the TOC file-list gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/check_dead_locale_keys.lua",
      "workflow must keep the dead-locale-keys gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/check_settings_default_pattern.lua",
      "workflow must keep the settings-default-pattern gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/simulate_key_completion_lifecycle.lua",
      "workflow must keep the key-completion lifecycle simulator gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/simulate_nameplate_keystart.lua all",
      "M+ forces sync workflow must keep the nameplate key-start simulator gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/simulate_savedvariables_reload.lua",
      "M+ forces sync workflow must keep the SavedVariables reload simulator gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/simulate_key_start_lifecycle.lua",
      "M+ forces sync workflow must keep the key-start lifecycle simulator gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/simulate_hidden_sync_reload.lua",
      "M+ forces sync workflow must keep the hidden-sync reload simulator gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/simulate_raid_party_cycle.lua",
      "M+ forces sync workflow must keep the raid-party cycle simulator gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/simulate_lfg_join_target_chain.lua",
      "M+ forces sync workflow must keep the LFG join target-chain simulator gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/simulate_reload_storm.lua",
      "M+ forces sync workflow must keep the reload-storm simulator gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/check_sound_channel.lua",
      "M+ forces sync workflow must keep the sound-channel gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/check_chat_color_safety.lua",
      "M+ forces sync workflow must keep the chat-color-safety gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/check_wow_api_compliance.lua",
      "M+ forces sync workflow must keep the WoW 12.0 API compliance gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/check_format_string_consistency.lua",
      "M+ forces sync workflow must keep the format-string consistency gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/check_secret_value_guards.lua",
      "M+ forces sync workflow must keep the secret-value guards gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/check_addon_message_size.lua",
      "M+ forces sync workflow must keep the addon-message-size gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/check_button_label_length.lua",
      "M+ forces sync workflow must keep the button-label-length gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/check_toc_file_list.lua",
      "M+ forces sync workflow must keep the TOC file-list gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/check_dead_locale_keys.lua",
      "M+ forces sync workflow must keep the dead-locale-keys gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/check_settings_default_pattern.lua",
      "M+ forces sync workflow must keep the settings-default-pattern gate"
    )
    AssertContains(
      Assert,
      syncWorkflowContent,
      "lua tools/simulate_key_completion_lifecycle.lua",
      "M+ forces sync workflow must keep the key-completion lifecycle simulator gate"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/check_mplus_db_lifetime.lua",
      "workflow must gate releases on the M+ forces DB lifetime"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/check_season_intake.lua",
      "workflow must validate the pre-activation season intake"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/check_hardcoded_strings.lua",
      "workflow must gate releases on hardcoded user-visible strings in ui/ and logic/"
    )
    AssertContains(
      Assert,
      workflowContent,
      "lua tools/check_ui_color_tokens.lua",
      "workflow must gate releases on literal UI colors outside UICommon.Colors"
    )
    AssertContains(Assert, workflowContent, "Lua Syntax Check", "workflow must keep the syntax validation step")
    AssertContains(
      Assert,
      workflowContent,
      '-not -path "./tools/cache/*"',
      "workflow syntax validation must exclude generated and downloaded cache sources"
    )
  end)

  test("Architecture season inspect workflows avoid content writes and keep artifact reports", function()
    local readinessWorkflow = ReadFile(".github/workflows/season-readiness.yml")
    local previewWorkflow = ReadFile(".github/workflows/inspect-mplus-season-preview.yml")
    local intakeWorkflow = ReadFile(".github/workflows/season-intake.yml")

    AssertContains(
      Assert,
      readinessWorkflow,
      "lua tools/inspect_season_readiness.lua",
      "season readiness workflow must run the repository inspect tool"
    )
    AssertContains(
      Assert,
      readinessWorkflow,
      "actions/upload-artifact@330a01c490aca151604b8cf639adc76d48f6c5d4 # v5",
      "season readiness workflow must upload its report as an artifact"
    )
    AssertContains(
      Assert,
      readinessWorkflow,
      "contents: read",
      "season readiness workflow must not request write permissions"
    )
    AssertNotContains(Assert, readinessWorkflow, "git commit", "season readiness workflow must not commit data")
    AssertNotContains(Assert, readinessWorkflow, "git push", "season readiness workflow must not push data")

    AssertContains(
      Assert,
      previewWorkflow,
      "git clone --depth 1 https://github.com/Nnoggie/MythicDungeonTools tools/cache/mdt",
      "MDT preview workflow must inspect the current MDT checkout"
    )
    AssertContains(
      Assert,
      previewWorkflow,
      "lua tools/inspect_mdt_season_preview.lua",
      "MDT preview workflow must run the repository inspect tool"
    )
    AssertContains(
      Assert,
      previewWorkflow,
      "actions/upload-artifact@330a01c490aca151604b8cf639adc76d48f6c5d4 # v5",
      "MDT preview workflow must upload its report as an artifact"
    )
    AssertContains(
      Assert,
      previewWorkflow,
      "contents: read",
      "MDT preview workflow must not request content write permissions"
    )
    AssertContains(
      Assert,
      previewWorkflow,
      "issues: write",
      "MDT preview workflow may write issues so complete Forces availability becomes visible"
    )
    AssertContains(
      Assert,
      previewWorkflow,
      "actions/github-script@ed597411d8f924073f98dfc5c65a23a2325f34cd # v8",
      "MDT preview workflow must create or update a GitHub issue when Forces data is complete"
    )
    AssertContains(
      Assert,
      previewWorkflow,
      "steps.preview.outputs.forces_ready == 'yes'",
      "MDT preview workflow must only notify when every configured dungeon has usable Forces data"
    )
    AssertContains(Assert, previewWorkflow, 'cron: "30 7 * * *"', "MDT Forces availability must be checked daily")
    Assert.True(
      previewWorkflow:find("S2 Forces sources available in MDT for ", 1, true) ~= nil
        and previewWorkflow:find("github.paginate(github.rest.issues.listForRepo", 1, true) ~= nil
        and previewWorkflow:find('state: "all"', 1, true) ~= nil
        and previewWorkflow:find("issue.body.includes(marker)", 1, true) ~= nil,
      "MDT preview workflow must find and reopen its marker-stable Forces issue across every issue page"
    )
    AssertNotContains(Assert, previewWorkflow, "git commit", "MDT preview workflow must not commit data")
    AssertNotContains(Assert, previewWorkflow, "git push", "MDT preview workflow must not push data")

    AssertContains(
      Assert,
      intakeWorkflow,
      "lua tools/check_season_intake.lua",
      "season intake workflow must validate the structured intake file"
    )
    AssertContains(
      Assert,
      intakeWorkflow,
      "const title = `Season Intake Status: ${season}`;",
      "season intake workflow must derive its stable issue title from the validated intake season"
    )
    AssertContains(
      Assert,
      intakeWorkflow,
      "const marker = `<!-- isiLive:season-intake:${season} -->`;",
      "season intake workflow must derive its issue marker from the validated intake season"
    )
    AssertContains(
      Assert,
      intakeWorkflow,
      "issues: write",
      "season intake workflow may write issues so intake drift becomes visible"
    )
    AssertContains(
      Assert,
      intakeWorkflow,
      "contents: read",
      "season intake workflow must not request content write permissions"
    )
    AssertContains(
      Assert,
      intakeWorkflow,
      "actions/upload-artifact@330a01c490aca151604b8cf639adc76d48f6c5d4 # v5",
      "season intake workflow must upload its report as an artifact"
    )
    AssertNotContains(Assert, intakeWorkflow, "git commit", "season intake workflow must not commit data")
    AssertNotContains(Assert, intakeWorkflow, "git push", "season intake workflow must not push data")
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
      'Invoke-LuaRocksCommand "Luacheck" "luacheck" @("--exclude-files", ".luarocks/**", "tools/cache/**", "--", ".")',
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
      "*\\tools\\cache\\*",
      "local syntax validation must exclude generated and downloaded cache sources"
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
      'Invoke-CheckedCommand "Coverage Run" "lua -lluacov tools/validate_usecases.lua"',
      "local preflight must run the same coverage collection as the workflow"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Coverage Threshold (>=80% per file)" "lua tools/coverage_below.lua 80 luacov.report.out"',
      "local preflight must enforce the same per-file coverage threshold as the workflow"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Coverage Threshold (>=88% total)" '
        .. '"lua tools/coverage_total_gate.lua 88 luacov.report.out"',
      "local preflight must enforce the same total coverage threshold as the workflow"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Nameplate Key-Start Simulator" "lua tools/simulate_nameplate_keystart.lua all"',
      "local preflight must run the nameplate key-start simulator gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "SavedVariables Reload Simulator" "lua tools/simulate_savedvariables_reload.lua"',
      "local preflight must run the SavedVariables reload simulator gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Key-Start Lifecycle Simulator" "lua tools/simulate_key_start_lifecycle.lua"',
      "local preflight must run the key-start lifecycle simulator gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Hidden-Sync Reload Simulator" "lua tools/simulate_hidden_sync_reload.lua"',
      "local preflight must run the hidden-sync reload simulator gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Raid-Party Cycle Simulator" "lua tools/simulate_raid_party_cycle.lua"',
      "local preflight must run the raid-party cycle simulator gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "LFG Join Target Chain Simulator" "lua tools/simulate_lfg_join_target_chain.lua"',
      "local preflight must run the LFG join target-chain simulator gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Reload-Storm Simulator" "lua tools/simulate_reload_storm.lua"',
      "local preflight must run the reload-storm simulator gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Sound Channel Check" "lua tools/check_sound_channel.lua"',
      "local preflight must run the sound-channel gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Chat Color Safety Check" "lua tools/check_chat_color_safety.lua"',
      "local preflight must run the chat-color-safety gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "WoW 12.0 API Compliance Check" "lua tools/check_wow_api_compliance.lua"',
      "local preflight must run the WoW 12.0 API compliance gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Format String Consistency Check" "lua tools/check_format_string_consistency.lua"',
      "local preflight must run the format-string consistency gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Secret Value Guards Check" "lua tools/check_secret_value_guards.lua"',
      "local preflight must run the secret-value guards gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Addon Message Size Check" "lua tools/check_addon_message_size.lua"',
      "local preflight must run the addon-message-size gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Button Label Length Check" "lua tools/check_button_label_length.lua"',
      "local preflight must run the button-label-length gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "TOC File List Check" "lua tools/check_toc_file_list.lua"',
      "local preflight must run the TOC file-list gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Dead Locale Keys Check" "lua tools/check_dead_locale_keys.lua"',
      "local preflight must run the dead-locale-keys gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Settings Default Pattern Check" "lua tools/check_settings_default_pattern.lua"',
      "local preflight must run the settings-default-pattern gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Key-Completion Lifecycle Simulator" "lua tools/simulate_key_completion_lifecycle.lua"',
      "local preflight must run the key-completion lifecycle simulator gate"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "M+ Forces DB Lifetime" "lua tools/check_mplus_db_lifetime.lua"',
      "local preflight must gate releases on the M+ forces DB lifetime"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Season Intake Check" "lua tools/check_season_intake.lua"',
      "local preflight must validate the pre-activation season intake"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "Hardcoded Strings Check" "lua tools/check_hardcoded_strings.lua"',
      "local preflight must gate releases on hardcoded user-visible strings"
    )
    AssertContains(
      Assert,
      localPreflightContent,
      'Invoke-CheckedCommand "UI Color Tokens Check" "lua tools/check_ui_color_tokens.lua"',
      "local preflight must gate releases on literal UI colors outside UICommon.Colors"
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

  test("Architecture rules validator indexes split scenario files from dofile and require", function()
    ---@diagnostic disable-next-line: undefined-global
    local validatorChunk, validatorErr = loadfile("tools/rules_logic_validator.lua")
    if not validatorChunk then
      error(string.format("cannot load rules validator: %s", tostring(validatorErr)))
    end
    ---@diagnostic disable-next-line: undefined-global
    local scenarioChunk, scenarioErr = loadfile("tools/usecase_scenarios.lua")
    if not scenarioChunk then
      error(string.format("cannot load scenario manifest: %s", tostring(scenarioErr)))
    end

    local validator = validatorChunk()
    local ok, result = validator.Run({
      rulesPath = "docs/RULES_LOGIC.md",
      scenarioFiles = scenarioChunk(),
      printFn = function() end,
    })

    Assert.True(ok == true, "rules validator must pass with the live rule set")
    local expanded = {}
    for _, path in ipairs(result.expandedScenarioFiles or {}) do
      expanded[path] = true
    end
    Assert.True(
      expanded["testmodul/isilive_test_scenarios_factory_primary_part1.lua"] == true,
      "rules validator must index dofile-based split scenario files"
    )
    Assert.True(
      expanded["testmodul/isilive_test_scenarios_factory_primary_part2.lua"] == true,
      "rules validator must index require-based split scenario files"
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

local function RegisterArchitectureGuardsSyncTests(test, Assert)
  local cachedModules

  local function GetGuardsRequiredModuleFiles()
    if cachedModules then
      return cachedModules
    end
    local guardsContent = ReadFile("isiLive_guards.lua")
    local requiredBlock = string.match(guardsContent, "local%s+REQUIRED_MODULES%s*=%s*(%b{})")
    if not requiredBlock then
      error("architecture test cannot locate local REQUIRED_MODULES = { ... } block in isiLive_guards.lua")
    end
    local modules = {}
    local entryPattern = '{%s*key%s*=%s*"[%w_]+"%s*,%s*file%s*=%s*"(isiLive_[%w_]+%.lua)"%s*}'
    for fileName in string.gmatch(requiredBlock, entryPattern) do
      modules[#modules + 1] = fileName
    end
    cachedModules = modules
    return modules
  end

  local function AssertEveryGuardsModuleReferenced(content, referenceTemplate, targetLabel)
    local modules = GetGuardsRequiredModuleFiles()
    for _, fileName in ipairs(modules) do
      AssertContains(
        Assert,
        content,
        string.format(referenceTemplate, fileName),
        string.format("%s must reference %s (required by Guards)", targetLabel, fileName)
      )
    end
  end

  test("Architecture Guards REQUIRED_MODULES parse yields paired key/file entries", function()
    local modules = GetGuardsRequiredModuleFiles()
    Assert.True(#modules > 0, "Guards REQUIRED_MODULES parse must yield at least one { key = ..., file = ... } entry")
  end)

  test("Architecture Guards required modules are registered in test harness FILE_PATHS", function()
    local harnessContent = ReadFile("testmodul/isilive_test_harness.lua")
    AssertEveryGuardsModuleReferenced(harnessContent, '["%s"]', "test harness FILE_PATHS")
  end)

  test("Architecture Guards required modules are covered by guards test scenario list", function()
    local guardsTestContent = ReadFile("testmodul/isilive_test_scenarios_guards.lua")
    AssertEveryGuardsModuleReferenced(guardsTestContent, '"%s"', "guards scenario REQUIRED_MODULES")
  end)
end

local function RegisterArchitectureLoadOrderTests(test, Assert)
  local function ParseTocOrder()
    local tocContent = ReadFile("isiLive.toc")
    local order = {}
    local index = 0
    for line in tocContent:gmatch("[^\r\n]+") do
      local trimmed = line:match("^%s*(.-)%s*$") or ""
      if trimmed ~= "" and not trimmed:match("^##") and not trimmed:match("^#") then
        local bareName = trimmed:match("([^/\\]+%.lua)$")
        if bareName then
          index = index + 1
          order[bareName] = index
        end
      end
    end
    return order
  end

  local function ParseHarnessDependencies()
    local harnessContent = ReadFile("testmodul/isilive_test_harness.lua")
    local block = string.match(harnessContent, "local%s+IMPLICIT_DEPENDENCIES%s*=%s*(%b{})")
    if not block then
      error("architecture test cannot locate local IMPLICIT_DEPENDENCIES = { ... } block in test harness")
    end
    local deps = {}
    local order = {}
    for key, body in string.gmatch(block, '%["([^"]+)"%]%s*=%s*(%b{})') do
      local list = {}
      for dep in string.gmatch(body, '"([^"]+)"') do
        list[#list + 1] = dep
      end
      deps[key] = list
      order[#order + 1] = key
    end
    return deps, order
  end

  test("Architecture IMPLICIT_DEPENDENCIES keys exist in .toc", function()
    local tocOrder = ParseTocOrder()
    local deps, keyOrder = ParseHarnessDependencies()
    Assert.True(#keyOrder > 0, "IMPLICIT_DEPENDENCIES must contain at least one entry")
    for _, key in ipairs(keyOrder) do
      Assert.True(
        tocOrder[key] ~= nil,
        string.format("IMPLICIT_DEPENDENCIES key %q must be listed in isiLive.toc", key)
      )
      for _, dep in ipairs(deps[key]) do
        Assert.True(
          tocOrder[dep] ~= nil,
          string.format("IMPLICIT_DEPENDENCIES[%q] dependency %q must be listed in isiLive.toc", key, dep)
        )
      end
    end
  end)

  test("Architecture IMPLICIT_DEPENDENCIES dependencies precede dependents in .toc", function()
    local tocOrder = ParseTocOrder()
    local deps, keyOrder = ParseHarnessDependencies()
    for _, key in ipairs(keyOrder) do
      local keyIndex = tocOrder[key]
      if keyIndex then
        for _, dep in ipairs(deps[key]) do
          local depIndex = tocOrder[dep]
          if depIndex then
            Assert.True(
              depIndex < keyIndex,
              string.format(
                "IMPLICIT_DEPENDENCIES[%q] dependency %q must precede %q in isiLive.toc (dep at %d, key at %d)",
                key,
                dep,
                key,
                depIndex,
                keyIndex
              )
            )
          end
        end
      end
    end
  end)

  test("Architecture IMPLICIT_DEPENDENCIES files are registered in test harness FILE_PATHS", function()
    local harnessContent = ReadFile("testmodul/isilive_test_harness.lua")
    local pathsBlock = string.match(harnessContent, "local%s+FILE_PATHS%s*=%s*(%b{})")
    if not pathsBlock then
      error("architecture test cannot locate local FILE_PATHS = { ... } block in test harness")
    end
    local registered = {}
    for fileName in string.gmatch(pathsBlock, '%["([^"]+)"%]') do
      registered[fileName] = true
    end
    local deps, keyOrder = ParseHarnessDependencies()
    for _, key in ipairs(keyOrder) do
      Assert.True(
        registered[key] == true,
        string.format("IMPLICIT_DEPENDENCIES key %q must be registered in test harness FILE_PATHS", key)
      )
      for _, dep in ipairs(deps[key]) do
        Assert.True(
          registered[dep] == true,
          string.format(
            "IMPLICIT_DEPENDENCIES[%q] dependency %q must be registered in test harness FILE_PATHS",
            key,
            dep
          )
        )
      end
    end
  end)

  test("Architecture factory submodules load before the controller compatibility anchor", function()
    local tocOrder = ParseTocOrder()
    local deps = ParseHarnessDependencies()
    local controllerFile = "isiLive_factory_controllers.lua"
    local controllerIndex = tocOrder[controllerFile]
    Assert.True(controllerIndex ~= nil, "factory controller compatibility anchor must be listed in isiLive.toc")

    local expectedSubmodules = {
      "isiLive_factory_demo.lua",
      "isiLive_factory_notices.lua",
      "isiLive_factory_cd_tracker.lua",
      "isiLive_factory_status_helpers.lua",
      "isiLive_factory_runtime_helpers.lua",
      "isiLive_factory_testmode_bindings.lua",
      "isiLive_factory_combat_announces.lua",
      "isiLive_factory_localization.lua",
      "isiLive_factory_refresh.lua",
      "isiLive_factory_lfg_wiring.lua",
      "isiLive_factory_secondary_runtime.lua",
      "isiLive_factory_primary.lua",
      "isiLive_factory_status.lua",
      "isiLive_factory_secondary.lua",
    }

    local controllerDeps = {}
    for _, dep in ipairs(deps[controllerFile] or {}) do
      controllerDeps[dep] = true
    end
    for _, fileName in ipairs(expectedSubmodules) do
      local submoduleIndex = tocOrder[fileName]
      Assert.True(submoduleIndex ~= nil, fileName .. " must be listed in isiLive.toc")
      Assert.True(
        controllerDeps[fileName] == true,
        fileName .. " must be an implicit dependency of the factory controller anchor"
      )
      Assert.True(submoduleIndex < controllerIndex, fileName .. " must load before isiLive_factory_controllers.lua")
    end
  end)

  test("Architecture removed LFG invite list modules stay absent from TOC and harness", function()
    local tocContent = ReadFile("isiLive.toc")
    local harnessContent = ReadFile("testmodul/isilive_test_harness.lua")
    local guardsContent = ReadFile("isiLive_guards.lua")

    for _, fileName in ipairs({ "isiLive_invites.lua", "isiLive_invite_list.lua" }) do
      Assert.Nil(tocContent:find(fileName, 1, true), fileName .. " must stay out of isiLive.toc")
      Assert.Nil(harnessContent:find(fileName, 1, true), fileName .. " must stay out of test harness FILE_PATHS")
      Assert.Nil(guardsContent:find(fileName, 1, true), fileName .. " must stay out of required module guards")
    end

    local removedPaths = {
      "logic/isiLive_invites.lua",
      "ui/isiLive_invite_list.lua",
      "testmodul/isilive_test_scenarios_invites.lua",
    }
    for _, path in ipairs(removedPaths) do
      local file = ioLib.open(path, "rb")
      if file then
        file:close()
      end
      Assert.Nil(file, path .. " must not exist after removing the abandoned invite-list feature")
    end
  end)
end

return function(test, ctx)
  RegisterArchitectureSourceBoundaryTests(test, ctx.assert)
  RegisterArchitectureQueueWiringTests(test, ctx.assert)
  RegisterArchitectureTeleportWiringTests(test, ctx.assert)
  RegisterArchitectureReadyCheckWiringTests(test, ctx.assert)
  RegisterArchitectureLeaderMarkerWiringTests(test, ctx.assert)
  RegisterArchitectureNoticeTypographyTests(test, ctx.assert)
  RegisterArchitectureWorkflowTests(test, ctx.assert)
  RegisterArchitectureModuleApiTests(test, ctx.assert, ctx.load_modules)
  RegisterArchitectureGuardsSyncTests(test, ctx.assert)
  RegisterArchitectureLoadOrderTests(test, ctx.assert)
end
