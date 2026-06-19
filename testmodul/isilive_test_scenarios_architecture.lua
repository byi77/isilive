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
      "local groupContext = ctx.groupControllerContext or ctx",
      "RuntimeSetup must accept a narrow group-controller context bundle"
    )
    AssertContains(
      Assert,
      content,
      "local eventContext = ctx.eventHandlersContext or ctx",
      "RuntimeSetup must accept an event-handler context bundle"
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
      "runtimeSetupContext.eventHandlersContext = runtimeSetupContext",
      "factory root must pass the event-handler context explicitly"
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

  test("Architecture optional WoW globals use guarded rawget caches", function()
    local lfgFlagsContent = ReadFile("isiLive_lfg_flags.lua")
    local noticeContent = ReadFile("isiLive_notice.lua")
    local checkedRawgetFiles = {
      "isiLive_controller_wiring.lua",
      "isiLive_event_handlers_runtime.lua",
      "isiLive_factory_demo.lua",
      "isiLive_factory_primary.lua",
      "isiLive_factory_refresh.lua",
      "isiLive_factory_status.lua",
      "isiLive_killtrack.lua",
      "isiLive_status.lua",
      "isiLive_teleport.lua",
    }

    local function StripLuaComments(content)
      content = content:gsub("%-%-%[%[.-%]%]", "")
      content = content:gsub("%-%-[^\r\n]*", "")
      return content
    end

    AssertContains(
      Assert,
      lfgFlagsContent,
      'local createFrame = rawget(_G, "CreateFrame")',
      "LFGFlags fallback event frames must resolve CreateFrame through rawget"
    )
    AssertContains(
      Assert,
      lfgFlagsContent,
      'local timer = rawget(_G, "C_Timer")',
      "LFGFlags delayed fallback refresh must resolve C_Timer through rawget"
    )
    AssertContains(
      Assert,
      lfgFlagsContent,
      'local hooksecurefuncRef = rawget(_G, "hooksecurefunc")',
      "LFGFlags hook wiring must resolve hooksecurefunc through rawget"
    )
    AssertNotContains(
      Assert,
      lfgFlagsContent,
      "pcall(hooksecurefunc,",
      "LFGFlags must not call bare hooksecurefunc in pcall"
    )
    AssertNotContains(Assert, lfgFlagsContent, "C_Timer.After", "LFGFlags must not call bare C_Timer.After")
    AssertContains(
      Assert,
      noticeContent,
      'local spellApi = rawget(_G, "C_Spell")',
      "Notice teleport-button icon lookup must resolve C_Spell through rawget"
    )
    AssertNotContains(
      Assert,
      noticeContent,
      "if spellID and C_Spell and C_Spell.GetSpellTexture then",
      "Notice teleport-button icon lookup must not use bare C_Spell short-circuit chains"
    )

    for _, file in ipairs(checkedRawgetFiles) do
      local content = StripLuaComments(ReadFile(file))
      Assert.True(not content:find("C_Timer and", 1, true), file .. " must not use bare C_Timer short-circuit chains")
      Assert.True(not content:find("C_Timer.", 1, true), file .. " must not call bare C_Timer APIs")
      Assert.True(
        not content:find("C_Spell and C_Spell", 1, true),
        file .. " must not use bare C_Spell short-circuit chains"
      )
      Assert.True(not content:find("C_Spell.", 1, true), file .. " must not call bare C_Spell APIs")
    end

    local teleportContent = ReadFile("isiLive_teleport.lua")
    AssertContains(
      Assert,
      teleportContent,
      'local createFrame = rawget(_G, "CreateFrame")',
      "Teleport combat retry frame must resolve fallback-capable CreateFrame through rawget"
    )
  end)

  test("Architecture large-module watchlist is documented and gate-pinned", function()
    local architectureContent = ReadFile("ARCHITECTURE.md")

    AssertContains(
      Assert,
      architectureContent,
      "## Architektur-Refactoring-Watchlist",
      "architecture docs must keep a visible refactoring watchlist section"
    )
    AssertContains(
      Assert,
      architectureContent,
      "`ui/isiLive_lfg_flags.lua`",
      "large-module watchlist must include LFGFlags"
    )
    AssertContains(Assert, architectureContent, "`logic/isiLive_sync.lua`", "large-module watchlist must include Sync")
    AssertContains(Assert, architectureContent, "`ui/isiLive_notice.lua`", "large-module watchlist must include Notice")
    AssertContains(
      Assert,
      architectureContent,
      "Splits erfolgen nur entlang klarer Runtime- oder",
      "large-module watchlist must preserve the split contract"
    )
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
      ["ui/isiLive_ui_main_frame.lua"] = {
        "RegisterForClicks",
        'rawget(_G, "InCombatLockdown")',
        "lockMainFramePosition",
      },
      ["factory/isiLive_factory_minimap.lua"] = {
        "RegisterForClicks",
      },
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

  test("Architecture combat utility ticker rerenders UI while Mythic+ timer is active", function()
    local content = ReadFile("isiLive_factory_cd_tracker.lua")

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

  test("Architecture gitignore keeps packaged sound assets trackable", function()
    local content = ReadFile(".gitignore")
    local soundFiles = {
      "Portal.ogg",
      "RoosterChickenCalls.ogg",
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
      "isiLive_EnterDungeon.png",
      "isiLive_H_ui.png",
      "isiLive_InviteAccepted.png",
      "isiLive_LFGBuffRating.png",
      "isiLive_LFGBuffRating2.png",
      "isiLive_MPlus_ui.png",
      "isiLive_M_ui.png",
      "isiLive_PortalNavigator.png",
      "isiLive_Statsbox.png",
      "isiLive_V_ui.png",
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
      "isiLive_EnterDungeon.png",
      "isiLive_H_ui.png",
      "isiLive_InviteAccepted.png",
      "isiLive_LFGBuffRating.png",
      "isiLive_LFGBuffRating2.png",
      "isiLive_MPlus_ui.png",
      "isiLive_M_ui.png",
      "isiLive_PortalNavigator.png",
      "isiLive_Statsbox.png",
      "isiLive_V_ui.png",
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
      "onGroupJoined = ctx.onGroupJoined,",
      "ControllerWiring must pass the group-joined callback through"
    )
    AssertContains(
      Assert,
      wiringContent,
      "PlayGroupJoin()",
      "ControllerWiring member-join sound hook must use the dedicated SynthChord helper"
    )

    local playCalls = 0
    local playedPath = nil
    local playedChannel = nil
    local playedSoundKit = nil
    local stoppedHandles = {}
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
        return true, "file:" .. tostring(playCalls)
      end,
      PlaySound = function(id, channel)
        playCalls = playCalls + 1
        playedSoundKit = id
        playedChannel = channel
        return true, "kit:" .. tostring(playCalls)
      end,
      StopSound = function(handle)
        stoppedHandles[#stoppedHandles + 1] = handle
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
      Assert.True(
        addon.SoundUtils.HasKey("ready_check_complete"),
        "sound registry should include the ready-check-complete key"
      )
      Assert.True(addon.SoundUtils.HasKey("portal_available"), "sound registry should include the portal key")
      Assert.True(addon.SoundUtils.HasKey("battle_res"), "sound registry should include the battle-res key")
      Assert.True(addon.SoundUtils.HasKey("battle_res_ready"), "sound registry should include the battle-res-ready key")
      Assert.True(addon.SoundUtils.HasKey("bloodlust"), "sound registry should include the bloodlust key")
      Assert.True(addon.SoundUtils.HasKey("bloodlust_ready"), "sound registry should include the bloodlust-ready key")
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
      Assert.True(
        addon.SoundUtils.IsEnabled("group_join"),
        "group-join sound should be enabled by default when no DB override exists"
      )
      local readyCheckCompleteEntry = addon.SoundUtils.GetEntry("ready_check_complete")
      Assert.NotNil(readyCheckCompleteEntry, "ready-check-complete sound entry should exist")
      Assert.Equal(
        readyCheckCompleteEntry.settingKey,
        "soundReadyCheckCompleteEnabled",
        "ready-check-complete sound should map to the ready-check-complete setting key"
      )
      Assert.Equal(
        readyCheckCompleteEntry.file,
        "Interface\\AddOns\\isiLive\\sounds\\BttF_Tinkle.wav",
        "ready-check-complete sound should use the bundled BttF tinkle asset"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("ready_check_complete"),
        "ready-check-complete sound should default to enabled when no DB override exists"
      )
      local portalEntry = addon.SoundUtils.GetEntry("portal_available")
      Assert.NotNil(portalEntry, "portal sound entry should exist")
      Assert.Equal(
        portalEntry.settingKey,
        "soundPortalAvailableEnabled",
        "portal sound should map to the portal-enabled setting key"
      )
      Assert.Equal(
        portalEntry.file,
        "Interface\\AddOns\\isiLive\\sounds\\Portal.ogg",
        "portal sound should use the bundled incoming-summon asset"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("portal_available"),
        "portal sound should default to enabled when no DB override exists"
      )
      local battleResEntry = addon.SoundUtils.GetEntry("battle_res")
      Assert.NotNil(battleResEntry, "battle-res sound entry should exist")
      Assert.Equal(
        battleResEntry.settingKey,
        "soundBattleResEnabled",
        "battle-res sound should map to the battle-res setting key"
      )
      Assert.Equal(
        battleResEntry.file,
        "Interface\\AddOns\\isiLive\\sounds\\ChickenAlarm.ogg",
        "battle-res entry should point at the chicken-alarm asset"
      )
      Assert.Equal(
        battleResEntry.fallbackFile,
        "Interface\\AddOns\\isiLive\\sounds\\RoosterChickenCalls.ogg",
        "battle-res entry should fall back to a non-ready BR asset if the primary file is rejected"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("battle_res"),
        "battle-res sound should default to enabled when no DB override exists"
      )
      local battleResReadyEntry = addon.SoundUtils.GetEntry("battle_res_ready")
      Assert.NotNil(battleResReadyEntry, "battle-res-ready sound entry should exist")
      Assert.Equal(
        battleResReadyEntry.settingKey,
        "soundBattleResReadyEnabled",
        "battle-res-ready sound should map to the battle-res-ready setting key"
      )
      Assert.Equal(
        battleResReadyEntry.file,
        "Interface\\AddOns\\isiLive\\sounds\\BattleRezReady.wav",
        "battle-res-ready entry should point at the bundled WAV asset"
      )
      Assert.False(
        battleResEntry.fallbackFile == battleResReadyEntry.file,
        "combat battle-res fallback must not reuse the battle-res-ready WAV asset"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("battle_res_ready"),
        "battle-res-ready sound should default to enabled when no DB override exists"
      )
      local bloodlustEntry = addon.SoundUtils.GetEntry("bloodlust")
      Assert.NotNil(bloodlustEntry, "bloodlust sound entry should exist")
      Assert.Equal(
        bloodlustEntry.settingKey,
        "soundBloodlustEnabled",
        "bloodlust sound should map to the bloodlust setting key"
      )
      Assert.Equal(
        bloodlustEntry.file,
        "Interface\\AddOns\\isiLive\\sounds\\BoxingArenaSound.ogg",
        "bloodlust entry should point at the boxing-arena asset"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("bloodlust"),
        "bloodlust sound should default to enabled when no DB override exists"
      )
      local bloodlustReadyEntry = addon.SoundUtils.GetEntry("bloodlust_ready")
      Assert.NotNil(bloodlustReadyEntry, "bloodlust-ready sound entry should exist")
      Assert.Equal(
        bloodlustReadyEntry.settingKey,
        "soundBloodlustReadyEnabled",
        "bloodlust-ready sound should map to the bloodlust-ready setting key"
      )
      Assert.Equal(
        bloodlustReadyEntry.file,
        "Interface\\AddOns\\isiLive\\sounds\\BloodlustReady.wav",
        "bloodlust-ready entry should point at the bundled WAV asset"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("bloodlust_ready"),
        "bloodlust-ready sound should default to enabled when no DB override exists"
      )
      Assert.NotNil(addon.SoundUtils.PlayGroupJoin, "sound utils should expose a dedicated group-join sound helper")
      Assert.NotNil(addon.SoundUtils.StopAllActiveSounds, "sound utils should expose a stop-all helper")
      Assert.NotNil(
        addon.SoundUtils.PlayReadyCheckComplete,
        "sound utils should expose a dedicated ready-check-complete sound helper"
      )
      Assert.NotNil(addon.SoundUtils.PlayPortalAvailable, "sound utils should expose a dedicated portal sound helper")
      Assert.NotNil(addon.SoundUtils.PlayIncomingSummon, "sound utils should expose a dedicated summon sound helper")
      Assert.NotNil(addon.SoundUtils.PlayBattleRes, "sound utils should expose a dedicated battle-res sound helper")
      Assert.NotNil(
        addon.SoundUtils.PlayBattleResReady,
        "sound utils should expose a dedicated battle-res-ready sound helper"
      )
      Assert.NotNil(addon.SoundUtils.PlayBloodlust, "sound utils should expose a dedicated bloodlust sound helper")
      Assert.NotNil(
        addon.SoundUtils.PlayBloodlustReady,
        "sound utils should expose a dedicated bloodlust-ready sound helper"
      )
      addon.SoundUtils.PlayKey("leader_transfer")
      Assert.Equal(playCalls, 1, "leader-transfer sound helper should play exactly once")
      Assert.Equal(
        playedPath,
        "Interface\\AddOns\\isiLive\\sounds\\CartoonVoiceBaritone.ogg",
        "leader-transfer sound helper should use the transfer asset"
      )
      Assert.Equal(playedChannel, "Master", "leader-transfer sound helper should use the Master channel")
      db.soundGroupJoinEnabled = true
      addon.SoundUtils.PlayGroupJoin()
      Assert.Equal(playCalls, 2, "group-join sound helper should play exactly once after the leader sound")
      Assert.Equal(
        playedPath,
        "Interface\\AddOns\\isiLive\\sounds\\SynthChord.ogg",
        "group-join sound helper should use the SynthChord asset"
      )
      Assert.Equal(playedChannel, "Master", "group-join sound helper should use the Master channel")
      addon.SoundUtils.PlayReadyCheckComplete()
      Assert.Equal(playCalls, 3, "ready-check-complete sound helper should play exactly once after the group sound")
      Assert.Equal(
        playedPath,
        "Interface\\AddOns\\isiLive\\sounds\\BttF_Tinkle.wav",
        "ready-check-complete sound helper should use the bundled BttF tinkle asset"
      )
      Assert.Equal(playedChannel, "Master", "ready-check-complete sound helper should use the Master channel")
      addon.SoundUtils.PlayPortalAvailable()
      Assert.Equal(playCalls, 4, "portal sound helper should play exactly once after the ready-check sound")
      Assert.Equal(
        playedPath,
        "Interface\\AddOns\\isiLive\\sounds\\Portal.ogg",
        "portal sound helper should use the bundled portal asset"
      )
      Assert.Equal(playedChannel, "Master", "portal sound helper should use the Master channel")
      addon.SoundUtils.PlayBattleRes()
      addon.SoundUtils.PlayBattleResReady()
      addon.SoundUtils.PlayBloodlust()
      addon.SoundUtils.PlayBloodlustReady()
      Assert.Equal(
        playCalls,
        8,
        "battle-res, battle-res-ready, bloodlust, and bloodlust-ready play their configured assets"
      )
      Assert.Equal(
        playedPath,
        "Interface\\AddOns\\isiLive\\sounds\\BloodlustReady.wav",
        "bloodlust-ready helper should use the bundled WAV asset"
      )
      addon.SoundUtils.StopAllActiveSounds()
      Assert.Equal(#stoppedHandles, 8, "stop-all helper must stop every active sound handle")
      local stoppedByHandle = {}
      for _, handle in ipairs(stoppedHandles) do
        stoppedByHandle[handle] = true
      end
      Assert.True(stoppedByHandle["file:1"] == true, "stop-all helper must pass file playback handles to StopSound")

      db.soundLeadEnabled = false
      db.soundGroupJoinEnabled = true
      db.soundReadyCheckCompleteEnabled = false
      db.soundPortalAvailableEnabled = false
      db.soundBattleResEnabled = true
      db.soundBattleResReadyEnabled = true
      db.soundBloodlustEnabled = true
      db.soundBloodlustReadyEnabled = true
      now = 2.9
      playCalls = 0
      addon.SoundUtils.PlayGroupJoin()
      Assert.Equal(playCalls, 1, "same sound key replay is temporarily allowed without the global spam window")

      now = 3
      addon.SoundUtils.PlayKey("leader_transfer")
      addon.SoundUtils.PlayGroupJoin()
      addon.SoundUtils.PlayReadyCheckComplete()
      addon.SoundUtils.PlayPortalAvailable()
      addon.SoundUtils.PlayBattleRes()
      addon.SoundUtils.PlayBattleResReady()
      addon.SoundUtils.PlayBloodlust()
      addon.SoundUtils.PlayBloodlustReady()
      Assert.Equal(
        playCalls,
        6,
        "enabled group-join, battle-res, battle-res-ready, bloodlust, and bloodlust-ready should play; "
          .. "disabled lead, ready-check, and portal stay silent"
      )
      Assert.Equal(
        playedPath,
        "Interface\\AddOns\\isiLive\\sounds\\BloodlustReady.wav",
        "bloodlust-ready asset should be the last played sound"
      )

      playCalls = 0
      playedSoundKit = nil
      _G.SOUNDKIT = {
        UI_TEST_SOUND = 4242,
      }
      now = 10
      addon.SoundUtils.PlaySoundKit(nil)
      addon.SoundUtils.PlaySoundKit("UNKNOWN_SOUND")
      Assert.Equal(playCalls, 0, "missing SoundKit values must fail closed without playback")
      addon.SoundUtils.PlaySoundKit("UI_TEST_SOUND", "Dialog")
      Assert.Equal(playCalls, 1, "named SoundKit values must resolve through SOUNDKIT")
      Assert.Equal(playedSoundKit, 4242, "named SoundKit playback must pass the resolved numeric id")
      Assert.Equal(playedChannel, "Dialog", "explicit SoundKit channel should be preserved")
      addon.SoundUtils.PlaySoundKit("UI_TEST_SOUND", "Dialog")
      Assert.Equal(playCalls, 2, "SoundKit duplicate playback is temporarily allowed")
      now = 12.9
      addon.SoundUtils.PlaySoundKit("UI_TEST_SOUND", "Dialog")
      Assert.Equal(playCalls, 3, "SoundKit playback remains allowed before the old spam window would expire")
      now = 13
      addon.SoundUtils.PlaySoundKit("UI_TEST_SOUND", "Dialog")
      Assert.Equal(playCalls, 4, "SoundKit playback remains allowed after the old spam window would expire")
      now = 16
      addon.SoundUtils.PlaySoundKit(7777)
      Assert.Equal(playCalls, 5, "numeric SoundKit ids must play directly")
      Assert.Equal(playedSoundKit, 7777, "numeric SoundKit playback must pass the given id")
      Assert.Equal(playedChannel, "Master", "SoundKit playback defaults to the Master channel")

      local aurochsIDs = addon.SoundUtils.GetAstralAurochsSoundFileIDs()
      Assert.NotNil(aurochsIDs, "astral aurochs sound mute list must be exposed for tests")
      Assert.True(#aurochsIDs >= 88, "astral aurochs mute list should include summon, special, flight, and loop files")
      local hasWingFlap = false
      local hasLoop = false
      for _, id in ipairs(aurochsIDs) do
        if id == 4906115 then
          hasWingFlap = true
        elseif id == 6788040 then
          hasLoop = true
        end
      end
      Assert.True(hasWingFlap, "astral aurochs mute list must include the model wing-flap flight sound")
      Assert.True(hasLoop, "astral aurochs mute list must include the model loop flight sound")
      local yakIDs = addon.SoundUtils.GetGrandExpeditionYakSoundFileIDs()
      local brutosaurIDs = addon.SoundUtils.GetGildedBrutosaurSoundFileIDs()
      Assert.True(#yakIDs >= 300, "grand expedition yak mute list must include verified model and footstep files")
      Assert.True(#brutosaurIDs >= 100, "gilded brutosaur mute list must include verified model and special files")
      Assert.Equal(yakIDs[1], 613111, "grand expedition yak mute list must start with the verified base yak file")
      Assert.Equal(
        brutosaurIDs[1],
        1824124,
        "gilded brutosaur mute list must start with the verified base brutosaur file"
      )
      local hasYakFootstep = false
      local hasYakMountFoley = false
      local hasYakFalsePositive = false
      for _, id in ipairs(yakIDs) do
        if id == 1023697 then
          hasYakFootstep = true
        elseif id == 633579 then
          hasYakMountFoley = true
        elseif id == 3528725 then
          hasYakFalsePositive = true
        end
      end
      Assert.True(hasYakFootstep, "grand expedition yak mute list must include verified footstep files")
      Assert.True(hasYakMountFoley, "grand expedition yak mute list must include verified yak mount foley files")
      Assert.False(
        hasYakFalsePositive,
        "grand expedition yak mute list must not include the MountID 1460 false-positive row"
      )
      local hasBrutosaurFootstep = false
      local hasBrutosaurMoving = false
      local hasBrutosaurLateFidget = false
      for _, id in ipairs(brutosaurIDs) do
        if id == 801310 then
          hasBrutosaurFootstep = true
        elseif id == 6211355 then
          hasBrutosaurMoving = true
        elseif id == 6211670 then
          hasBrutosaurLateFidget = true
        end
      end
      Assert.True(hasBrutosaurFootstep, "gilded brutosaur mute list must include verified footstep files")
      Assert.True(hasBrutosaurMoving, "gilded brutosaur mute list must include verified mount-special moving files")
      Assert.True(hasBrutosaurLateFidget, "gilded brutosaur mute list must include verified late fidget files")
    end)

    local fallbackCalls = {}
    WithGlobals({
      IsiLiveDB = {
        soundBattleResEnabled = true,
        soundBloodlustEnabled = true,
      },
      GetTime = function()
        return 100
      end,
      PlaySoundFile = function(path, channel)
        fallbackCalls[#fallbackCalls + 1] = { path = path, channel = channel }
        if path == "Interface\\AddOns\\isiLive\\sounds\\ChickenAlarm.ogg" then
          return false
        end
        return true
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.True(addon.SoundUtils.PlayBattleRes(), "battle-res should fall back when the primary file is rejected")
      Assert.Equal(
        fallbackCalls[1].path,
        "Interface\\AddOns\\isiLive\\sounds\\ChickenAlarm.ogg",
        "BR must try the primary configured asset first"
      )
      Assert.Equal(fallbackCalls[1].channel, "Master", "BR primary attempt must keep the configured channel")
      Assert.Equal(
        fallbackCalls[2].path,
        "Interface\\AddOns\\isiLive\\sounds\\RoosterChickenCalls.ogg",
        "BR must try the fallback asset when the primary asset is rejected"
      )
      Assert.Equal(fallbackCalls[2].channel, "Master", "BR fallback must keep the configured channel")
      Assert.Equal(#fallbackCalls, 2, "BR fallback must add exactly one secondary playback attempt")
    end)

    local bloodlustCalls = {}
    WithGlobals({
      IsiLiveDB = {
        soundBloodlustEnabled = true,
      },
      GetTime = function()
        return 200
      end,
      PlaySoundFile = function(path, channel)
        bloodlustCalls[#bloodlustCalls + 1] = { path = path, channel = channel }
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.False(addon.SoundUtils.PlayBloodlust(), "bloodlust should report rejected playback without a fallback")
      Assert.Equal(#bloodlustCalls, 1, "bloodlust must not inherit the battle-res fallback")
      Assert.Equal(
        bloodlustCalls[1].path,
        "Interface\\AddOns\\isiLive\\sounds\\BoxingArenaSound.ogg",
        "bloodlust must keep the BoxingArenaSound asset"
      )
    end)

    local muted = {}
    local unmuted = {}

    WithGlobals({
      C_Sound = {
        MuteSoundFile = function(id)
          muted[#muted + 1] = id
        end,
        UnmuteSoundFile = function(id)
          unmuted[#unmuted + 1] = id
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.True(addon.SoundUtils.ApplyAstralAurochsSoundSetting(true), "C_Sound mute API should be accepted")
      Assert.Equal(muted[1], 7340960, "C_Sound mute API should receive astral aurochs file IDs")
      Assert.True(addon.SoundUtils.ApplyAstralAurochsSoundSetting(false), "C_Sound unmute API should be accepted")
      Assert.Equal(unmuted[1], 7340960, "C_Sound unmute API should receive astral aurochs file IDs")
    end)
  end)

  test("SoundUtils uses Master by default and SFX when configured", function()
    local now = 1
    local playedChannel = nil
    local playedByPath = {}
    local db = {}

    WithGlobals({
      IsiLiveDB = db,
      GetTime = function()
        return now
      end,
      PlaySoundFile = function(path, channel)
        playedChannel = channel
        playedByPath[path] = channel
        return true
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.Equal(
        addon.SoundUtils.GetConfiguredOutputChannel(),
        "Master",
        "sound output channel should default to Master"
      )

      addon.SoundUtils.PlayGroupJoin()
      Assert.Equal(playedChannel, "Master", "built-in sound playback should use Master by default")

      db.soundOutputChannel = "SFX"
      now = 4
      addon.SoundUtils.PlayGroupJoin()
      Assert.Equal(playedChannel, "SFX", "built-in sound playback should use configured SFX output")

      for _, key in ipairs(addon.SoundUtils.SettingsOrder) do
        now = now + 1
        local entry = addon.SoundUtils.GetEntry(key)
        playedChannel = nil
        Assert.True(addon.SoundUtils.PlayKey(key), "registered sound key should play: " .. tostring(key))
        Assert.Equal(playedChannel, "SFX", "runtime sound key must use configured SFX output: " .. tostring(key))

        now = now + 1
        playedChannel = nil
        Assert.True(addon.SoundUtils.PlayPreviewKey(key), "preview sound key should play: " .. tostring(key))
        Assert.Equal(playedChannel, "SFX", "preview sound key must use configured SFX output: " .. tostring(key))
        Assert.Equal(
          playedByPath[entry.file],
          "SFX",
          "registry asset must be bound to configured SFX output: " .. tostring(entry.file)
        )
      end

      db.soundOutputChannel = "Dialog"
      now = 7
      addon.SoundUtils.PlayGroupJoin()
      Assert.Equal(playedChannel, "Master", "invalid sound output channel should fail closed to Master")
    end)
  end)

  test("SoundUtils Bloodlust-ready setting disables WAV playback", function()
    local playCalls = 0
    local db = {
      soundBloodlustReadyEnabled = false,
    }
    WithGlobals({
      IsiLiveDB = db,
      GetTime = function()
        return 30
      end,
      PlaySoundFile = function()
        playCalls = playCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.False(
        addon.SoundUtils.IsEnabled("bloodlust_ready"),
        "bloodlust-ready setting should disable the WAV sound"
      )
      addon.SoundUtils.PlayBloodlustReady()
      Assert.Equal(playCalls, 0, "disabled bloodlust-ready setting must suppress WAV playback")

      db.soundBloodlustReadyEnabled = true
      addon.SoundUtils.PlayBloodlustReady()
      Assert.Equal(playCalls, 1, "enabled bloodlust-ready setting should allow one WAV playback")
    end)
  end)

  test("SoundUtils Battle Res-ready setting disables WAV playback", function()
    local playCalls = 0
    local db = {
      soundBattleResReadyEnabled = false,
    }
    WithGlobals({
      IsiLiveDB = db,
      GetTime = function()
        return 40
      end,
      PlaySoundFile = function()
        playCalls = playCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.False(
        addon.SoundUtils.IsEnabled("battle_res_ready"),
        "battle-res-ready setting should disable the WAV sound"
      )
      addon.SoundUtils.PlayBattleResReady()
      Assert.Equal(playCalls, 0, "disabled battle-res-ready setting must suppress WAV playback")

      db.soundBattleResReadyEnabled = true
      addon.SoundUtils.PlayBattleResReady()
      Assert.Equal(playCalls, 1, "enabled battle-res-ready setting should allow one WAV playback")
    end)
  end)

  test("SoundUtils ready-check-complete setting disables BttF playback", function()
    local playCalls = 0
    local db = {
      soundReadyCheckCompleteEnabled = false,
    }
    WithGlobals({
      IsiLiveDB = db,
      GetTime = function()
        return 50
      end,
      PlaySoundFile = function()
        playCalls = playCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.False(
        addon.SoundUtils.IsEnabled("ready_check_complete"),
        "ready-check-complete setting should disable the BttF sound"
      )
      addon.SoundUtils.PlayReadyCheckComplete()
      Assert.Equal(playCalls, 0, "disabled ready-check-complete setting must suppress BttF playback")

      db.soundReadyCheckCompleteEnabled = true
      addon.SoundUtils.PlayReadyCheckComplete()
      Assert.Equal(playCalls, 1, "enabled ready-check-complete setting should allow one BttF playback")
    end)
  end)

  test("Architecture kick tracker uses lightweight kick-column refresh hooks", function()
    local helpersContent = ReadFile("isiLive_factory_kick_tracker.lua")
    local rosterPanelContent = ReadFile("isiLive_roster_panel.lua")

    AssertContains(
      Assert,
      helpersContent,
      "ctx.HandleKickTrackerEvent = function(event, unit, _, spellID)",
      "factory kick tracking must expose a central-gate kick event handler"
    )
    AssertContains(
      Assert,
      helpersContent,
      'event == "UNIT_SPELLCAST_SUCCEEDED"',
      "factory kick tracking must handle player/pet interrupt casts through the central event path"
    )
    AssertContains(
      Assert,
      helpersContent,
      'event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UNIT_PET"',
      "factory kick tracking must refresh interrupt availability through central events"
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
      "SetKickCellText(row.kick, info, getL)",
      "RosterPanel dedicated kick-column refresh must use the same compact ready marker as full roster renders"
    )
    local rosterPanelRenderContent = ReadFile("isiLive_roster_panel_render.lua")
    AssertContains(
      Assert,
      rosterPanelRenderContent,
      'SetReadableText(cell, "|cff44ff44" .. readyText .. "|r")',
      "RosterPanel render module must render the compact kick-ready state in green"
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
      "(frameWidth or FULL_FRAME_WIDTH) - 96",
      "RosterPanel title budget must reserve space for the right-side toolbar buttons"
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
      "lua tools/check_hardcoded_strings.lua",
      "workflow must gate releases on hardcoded user-visible strings in ui/ and logic/"
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
      'Invoke-CheckedCommand "Hardcoded Strings Check" "lua tools/check_hardcoded_strings.lua"',
      "local preflight must gate releases on hardcoded user-visible strings"
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
  RegisterArchitectureAudioAndKickWiringTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
  RegisterArchitectureNoticeTypographyTests(test, ctx.assert)
  RegisterArchitectureWorkflowTests(test, ctx.assert)
  RegisterArchitectureModuleApiTests(test, ctx.assert, ctx.load_modules)
  RegisterArchitectureGuardsSyncTests(test, ctx.assert)
  RegisterArchitectureLoadOrderTests(test, ctx.assert)
end
