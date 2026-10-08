local ioLib = rawget(_G, "io")

local function ReadFile(path)
  local file, err = ioLib.open(path, "rb")
  if not file then
    error(string.format("cannot read %s: %s", tostring(path), tostring(err)))
  end
  local content = file:read("*a")
  file:close()
  return content or ""
end

return function(test, ctx)
  local Assert = ctx.assert

  test("Architecture large-module watchlist is documented and gate-pinned", function()
    local architecture = ReadFile("docs/ARCHITECTURE.md")
    local metrics = ReadFile("tools/lua_metrics_check.lua")
    local expected = {
      "ui/isiLive_lfg_flags.lua",
      "logic/isiLive_sync.lua",
    }
    Assert.True(architecture:find("## Architektur-Refactoring-Watchlist", 1, true) ~= nil, "watchlist required")
    for _, path in ipairs(expected) do
      Assert.True(architecture:find("`" .. path .. "`", 1, true) ~= nil, path .. " must be documented")
    end
    Assert.True(metrics:find('read_file("docs/ARCHITECTURE.md")', 1, true) ~= nil, "metrics must read watchlist")
    Assert.True(metrics:find("watchlist missing", 1, true) ~= nil, "metrics must fail for missing entries")
  end)

  test("Architecture sync receive module is isolated behind injected facade", function()
    local toc = ReadFile("isiLive.toc")
    local receive = ReadFile("logic/isiLive_sync_receive.lua")
    local sync = ReadFile("logic/isiLive_sync.lua")
    local receiveIndex = toc:find("logic/isiLive_sync_receive.lua", 1, true)
    local syncIndex = toc:find("logic/isiLive_sync.lua", 1, true)
    Assert.True(
      receiveIndex ~= nil and syncIndex ~= nil and receiveIndex < syncIndex,
      "receiver factory must load before the Sync facade"
    )
    Assert.True(
      receive:find("addonTable.SyncReceiveFactory = function(deps)", 1, true) ~= nil,
      "receive behavior must be exposed as a dependency-injected factory"
    )
    Assert.True(
      sync:find("Sync.ProcessAddonMessage = receiveFactory({", 1, true) ~= nil,
      "Sync facade must attach the extracted receiver with its required local dependencies"
    )
    Assert.Nil(
      sync:find("function Sync.ProcessAddonMessage", 1, true),
      "Sync facade must not retain the receive implementation"
    )
  end)

  test("Architecture LFG entry resolver owns verified listing normalization behind LFGDetect facade", function()
    local toc = ReadFile("isiLive.toc")
    local resolverIndex = toc:find("game/isiLive_lfg_entry_resolver.lua", 1, true)
    local detectIndex = toc:find("game/isiLive_lfg_detect.lua", 1, true)
    Assert.True(resolverIndex ~= nil, "LFGEntryResolver must be listed in the TOC")
    Assert.True(detectIndex ~= nil, "LFGDetect must be listed in the TOC")
    Assert.True(resolverIndex < detectIndex, "LFGEntryResolver must load before LFGDetect")

    local resolver = ReadFile("game/isiLive_lfg_entry_resolver.lua")
    local detect = ReadFile("game/isiLive_lfg_detect.lua")
    Assert.True(
      resolver:find("function Resolver.MapIDFromActivityID(activityID)", 1, true) ~= nil,
      "LFGEntryResolver must own activity-map resolution"
    )
    Assert.True(
      resolver:find("function Resolver.ResolveInviteEntry(searchResultID, log)", 1, true) ~= nil,
      "LFGEntryResolver must own verified listing normalization"
    )
    Assert.True(
      detect:find("return EntryResolver.ResolveInviteEntry(searchResultID, Log)", 1, true) ~= nil,
      "LFGDetect must preserve its invite-entry facade"
    )
    Assert.True(
      detect:find("local pendingInvites = {}", 1, true) ~= nil,
      "LFGDetect must retain invite lifecycle state"
    )
    Assert.Nil(
      detect:find("local function ParseTitleKeyLevel", 1, true),
      "LFGDetect must not retain listing normalization"
    )
  end)

  test("Architecture LFG bonus model owns guarded bonus classification behind LFGFlags facade", function()
    local toc = ReadFile("isiLive.toc")
    local modelIndex = toc:find("ui/isiLive_lfg_bonus_model.lua", 1, true)
    local flagsIndex = toc:find("ui/isiLive_lfg_flags.lua", 1, true)
    Assert.True(modelIndex ~= nil, "LFGBonusModel must be listed in the TOC")
    Assert.True(flagsIndex ~= nil, "LFGFlags must be listed in the TOC")
    Assert.True(modelIndex < flagsIndex, "LFGBonusModel must load before LFGFlags")

    local model = ReadFile("ui/isiLive_lfg_bonus_model.lua")
    local flags = ReadFile("ui/isiLive_lfg_flags.lua")
    Assert.True(
      model:find("local function BuildBonusSuffix(classToken, specID, profile)", 1, true) ~= nil,
      "LFGBonusModel must own bonus classification"
    )
    Assert.True(model:find("Model.IsSecretValue = IsSecretValue", 1, true) ~= nil, "secret guards must stay exported")
    Assert.True(
      flags:find("BonusModel.SetEnabled(lfgGroupBonusesEnabled)", 1, true) ~= nil,
      "LFGFlags must keep model enablement synchronized"
    )
    Assert.Nil(flags:find("local CLASS_BONUSES = {", 1, true), "LFGFlags must not duplicate the bonus catalog")
  end)

  test("Architecture LFG view hooks own Blizzard frame lifecycle behind LFGFlags facade", function()
    local toc = ReadFile("isiLive.toc")
    local hooksIndex = toc:find("ui/isiLive_lfg_view_hooks.lua", 1, true)
    local flagsIndex = toc:find("ui/isiLive_lfg_flags.lua", 1, true)
    Assert.True(hooksIndex ~= nil, "LFGViewHooks must be listed in the TOC")
    Assert.True(flagsIndex ~= nil, "LFGFlags must be listed in the TOC")
    Assert.True(hooksIndex < flagsIndex, "LFGViewHooks must load before LFGFlags")

    local hooks = ReadFile("ui/isiLive_lfg_view_hooks.lua")
    local flags = ReadFile("ui/isiLive_lfg_flags.lua")
    Assert.True(
      hooks:find("function Hooks.HookSearchPanel()", 1, true) ~= nil,
      "LFGViewHooks must own search-panel frame lifecycle"
    )
    Assert.True(
      hooks:find('pcall(hooksecurefuncRef, "LFGListApplicationViewer_UpdateResults"', 1, true) ~= nil,
      "LFGViewHooks must own applicant-viewer hooks"
    )
    Assert.True(
      flags:find("ViewHooks.Configure({", 1, true) ~= nil,
      "LFGFlags must provide rendering callbacks to LFGViewHooks"
    )
    Assert.True(
      flags:find("ViewHooks.HookSearchPanel()", 1, true) ~= nil,
      "LFGFlags must retain its public HookSearchPanel facade"
    )
    Assert.Nil(flags:find("local function HookGlobalFunction(", 1, true), "LFGFlags must not retain global hook wiring")
  end)

  test("Architecture game menu panel owns generic button construction and layout", function()
    local toc = ReadFile("isiLive.toc")
    local panelIndex = toc:find("ui/isiLive_ui_game_menu_panel.lua", 1, true)
    local gameMenuIndex = toc:find("ui/isiLive_ui_game_menu.lua", 1, true)
    Assert.True(panelIndex ~= nil, "UIGameMenuPanel must be listed in the TOC")
    Assert.True(gameMenuIndex ~= nil, "UIGameMenu facade must be listed in the TOC")
    Assert.True(panelIndex < gameMenuIndex, "UIGameMenuPanel must load before the game menu facade")

    local panel = ReadFile("ui/isiLive_ui_game_menu_panel.lua")
    local gameMenu = ReadFile("ui/isiLive_ui_game_menu.lua")
    Assert.True(
      panel:find("function Panel.CreateButton(", 1, true) ~= nil,
      "UIGameMenuPanel must own generic button construction"
    )
    Assert.True(
      panel:find("function Panel.PositionButtons(", 1, true) ~= nil,
      "UIGameMenuPanel must own generic panel layout"
    )
    Assert.True(
      gameMenu:find("return GameMenuPanel.PositionButtons(state, {", 1, true) ~= nil,
      "UIGameMenu must preserve its layout facade"
    )
    Assert.Nil(
      gameMenu:find("local function CreatePanelUIButton", 1, true),
      "UIGameMenu must not retain generic button construction"
    )
  end)

  test("Architecture portal navigator notice owns portal construction behind Notice facade", function()
    local toc = ReadFile("isiLive.toc")
    local commonIndex = toc:find("ui/isiLive_notice_common.lua", 1, true)
    local portalIndex = toc:find("ui/isiLive_portal_navigator_notice.lua", 1, true)
    local noticeIndex = toc:find("ui/isiLive_notice.lua", 1, true)
    Assert.True(commonIndex ~= nil, "NoticeCommon must be listed in the TOC")
    Assert.True(portalIndex ~= nil, "PortalNavigatorNotice must be listed in the TOC")
    Assert.True(noticeIndex ~= nil, "Notice facade must be listed in the TOC")
    Assert.True(commonIndex < portalIndex and portalIndex < noticeIndex, "notice submodules must load before Notice")
    local portal = ReadFile("ui/isiLive_portal_navigator_notice.lua")
    local notice = ReadFile("ui/isiLive_notice.lua")
    Assert.True(
      portal:find("function PortalNavigatorNotice.Create(opts, deps)", 1, true) ~= nil,
      "PortalNavigatorNotice must own portal construction"
    )
    Assert.True(
      notice:find("return PortalNavigatorNotice.Create(opts, {", 1, true) ~= nil,
      "Notice must preserve the public portal navigator facade"
    )
    Assert.Nil(
      notice:find("local function CreatePortalNavigatorEntry", 1, true),
      "Notice facade must not retain portal entry construction"
    )
  end)

  test("Architecture notice rich layout owns the info-card layout behind Notice facade", function()
    local toc = ReadFile("isiLive.toc")
    local commonIndex = toc:find("ui/isiLive_notice_common.lua", 1, true)
    local richIndex = toc:find("ui/isiLive_notice_rich_layout.lua", 1, true)
    local noticeIndex = toc:find("ui/isiLive_notice.lua", 1, true)
    Assert.True(richIndex ~= nil, "NoticeRichLayout must be listed in the TOC")
    Assert.True(noticeIndex ~= nil, "Notice facade must be listed in the TOC")
    Assert.True(
      commonIndex < richIndex and richIndex < noticeIndex,
      "NoticeRichLayout must load after NoticeCommon and before Notice"
    )

    local rich = ReadFile("ui/isiLive_notice_rich_layout.lua")
    local notice = ReadFile("ui/isiLive_notice.lua")
    Assert.True(
      rich:find("function NoticeRichLayout.Create(deps)", 1, true) ~= nil
        and rich:find("function NoticeRichLayout.CreateElements(frame, config)", 1, true) ~= nil,
      "NoticeRichLayout must expose the element factory and a dependency-injected layout factory"
    )
    Assert.True(
      rich:find("local function ApplyCenterNoticeRichLayout(deps, state, payload, hasTeleportButton)", 1, true) ~= nil
        and rich:find("local function HideRichCenterNoticeElements(state)", 1, true) ~= nil,
      "NoticeRichLayout must own the rich layout and hide paths"
    )
    Assert.True(
      notice:find("local RichLayout = NoticeRichLayout.Create({", 1, true) ~= nil
        and notice:find("setTeleportButtonSize = SetCenterNoticeTeleportButtonSize", 1, true) ~= nil
        and notice:find("setTeleportButtonAnchor = SetCenterNoticeTeleportButtonAnchor", 1, true) ~= nil,
      "Notice must inject its combat-deferred teleport button setters into the rich layout"
    )
    Assert.Nil(
      notice:find("local function ApplyCenterNoticeRichLayout", 1, true),
      "facade must not retain the rich layout"
    )
    Assert.Nil(notice:find("local FIELD_LABEL_WIDTH", 1, true), "facade must not duplicate rich layout constants")
    Assert.Nil(
      rich:find("InsecureActionButtonTemplate", 1, true),
      "the secure teleport button must stay in the Notice facade"
    )
  end)

  test("Architecture mob nameplate diagnostics own the dump surface behind MobNameplate facade", function()
    local toc = ReadFile("isiLive.toc")
    local diagnosticsIndex = toc:find("ui/isiLive_mob_nameplate_diagnostics.lua", 1, true)
    local nameplateIndex = toc:find("ui/isiLive_mob_nameplate.lua", 1, true)
    Assert.True(diagnosticsIndex ~= nil, "MobNameplateDiagnostics must be listed in the TOC")
    Assert.True(nameplateIndex ~= nil, "MobNameplate facade must be listed in the TOC")
    Assert.True(diagnosticsIndex < nameplateIndex, "MobNameplateDiagnostics must load before MobNameplate")

    local diagnostics = ReadFile("ui/isiLive_mob_nameplate_diagnostics.lua")
    local nameplate = ReadFile("ui/isiLive_mob_nameplate.lua")
    Assert.True(
      diagnostics:find("function MobNameplateDiagnostics.Create(deps)", 1, true) ~= nil,
      "MobNameplateDiagnostics must expose a dependency-injected factory"
    )
    Assert.True(
      diagnostics:find("local function DumpFrames()", 1, true) ~= nil
        and diagnostics:find("local function DumpState(unit)", 1, true) ~= nil,
      "MobNameplateDiagnostics must own the DumpFrames / DumpState implementation"
    )
    Assert.True(
      nameplate:find("MobNameplate.DumpFrames = diagnostics.DumpFrames", 1, true) ~= nil
        and nameplate:find("MobNameplate.DumpState = diagnostics.DumpState", 1, true) ~= nil,
      "MobNameplate must preserve its public DumpFrames / DumpState facade"
    )
    Assert.Nil(nameplate:find("function MobNameplate.DumpFrames", 1, true), "facade must not retain DumpFrames")
    Assert.Nil(nameplate:find("function MobNameplate.DumpState", 1, true), "facade must not retain DumpState")
  end)

  test("Architecture UI motion and private tooltip install behind the UICommon facade", function()
    local toc = ReadFile("isiLive.toc")
    local motionIndex = toc:find("ui/isiLive_ui_motion.lua", 1, true)
    local tooltipIndex = toc:find("ui/isiLive_ui_private_tooltip.lua", 1, true)
    local commonIndex = toc:find("ui/isiLive_ui_common.lua", 1, true)
    local noticeIndex = toc:find("ui/isiLive_notice.lua", 1, true)
    Assert.True(motionIndex ~= nil, "UIMotion must be listed in the TOC")
    Assert.True(tooltipIndex ~= nil, "UIPrivateTooltip must be listed in the TOC")
    Assert.True(commonIndex ~= nil and noticeIndex ~= nil, "UICommon and Notice must be listed in the TOC")
    Assert.True(
      motionIndex < commonIndex and tooltipIndex < commonIndex,
      "UIMotion and UIPrivateTooltip must load before the UICommon facade that installs them"
    )
    Assert.True(commonIndex < noticeIndex, "UICommon must load before Notice, which asserts CreatePrivateTooltip")

    local motion = ReadFile("ui/isiLive_ui_motion.lua")
    local tooltip = ReadFile("ui/isiLive_ui_private_tooltip.lua")
    local common = ReadFile("ui/isiLive_ui_common.lua")
    Assert.True(
      motion:find("function UIMotion.Install(target)", 1, true) ~= nil
        and motion:find("local function PlayAlphaTransition(frame, key, opts)", 1, true) ~= nil
        and motion:find("local motionTransitions = setmetatable", 1, true) ~= nil,
      "UIMotion must own the transition registry and install the motion surface"
    )
    Assert.True(
      tooltip:find("function UIPrivateTooltip.Install(target)", 1, true) ~= nil
        and tooltip:find("local function EnsurePrivateTooltipAPI(tooltip)", 1, true) ~= nil
        and tooltip:find("local function ResolveSpellName(spellID)", 1, true) ~= nil,
      "UIPrivateTooltip must own the tooltip API shim and install the tooltip surface"
    )
    Assert.True(
      common:find('assert(addonTable.UIMotion, "isiLive: UIMotion missing").Install(UICommon)', 1, true) ~= nil
        and common:find(
            'assert(addonTable.UIPrivateTooltip, "isiLive: UIPrivateTooltip missing").Install(UICommon)',
            1,
            true
          )
          ~= nil,
      "UICommon must install both surfaces while it loads"
    )
    Assert.Nil(common:find("motionTransitions", 1, true), "facade must not retain the transition registry")
    Assert.Nil(common:find("EnsurePrivateTooltipAPI", 1, true), "facade must not retain the tooltip API shim")
    Assert.Nil(common:find("TOOLTIP_WIDTH", 1, true), "facade must not duplicate tooltip layout constants")
  end)

  test("Architecture party-run module owns the tracked M0 run behind the runtime lifecycle", function()
    local toc = ReadFile("isiLive.toc")
    local partyRunIndex = toc:find("logic/isiLive_event_handlers_party_run.lua", 1, true)
    local runtimeIndex = toc:find("logic/isiLive_event_handlers_runtime.lua", 1, true)
    Assert.True(partyRunIndex ~= nil, "EventHandlersPartyRun must be listed in the TOC")
    Assert.True(runtimeIndex ~= nil, "runtime lifecycle must be listed in the TOC")
    Assert.True(partyRunIndex < runtimeIndex, "EventHandlersPartyRun must load before the runtime lifecycle")

    local partyRun = ReadFile("logic/isiLive_event_handlers_party_run.lua")
    local runtime = ReadFile("logic/isiLive_event_handlers_runtime.lua")
    Assert.True(
      partyRun:find("addonTable.EventHandlersPartyRun = PartyRun", 1, true) ~= nil
        and partyRun:find("local function IsTrackedPartyDifficulty(difficultyID)", 1, true) ~= nil
        and partyRun:find("local function GetTrackedMythicZeroState(ctx)", 1, true) ~= nil
        and partyRun:find("RetryTrackedMythicZeroRunCapture = function(ctx, runInfo, retriesRemaining)", 1, true)
          ~= nil,
      "EventHandlersPartyRun must own difficulty gating, state resolution and capture retries"
    )
    Assert.True(
      partyRun:find("PartyRun.ClearTrackedPartyRunState = ClearTrackedPartyRunState", 1, true) ~= nil
        and partyRun:find("PartyRun.UpdateTrackedMythicZeroRun = UpdateTrackedMythicZeroRun", 1, true) ~= nil
        and partyRun:find("PartyRun.CaptureTrackedMythicZeroRosterSnapshotIfPending =", 1, true) ~= nil,
      "EventHandlersPartyRun must export the three entry points the runtime lifecycle calls"
    )
    Assert.True(
      runtime:find(
        'local PartyRun = assert(addonTable.EventHandlersPartyRun, "isiLive: EventHandlersPartyRun missing")',
        1,
        true
      ) ~= nil,
      "runtime lifecycle must bind EventHandlersPartyRun at load"
    )
    Assert.Nil(runtime:find("local function UpdateTrackedMythicZeroRun", 1, true), "runtime must not retain M0 run")
    Assert.Nil(runtime:find("NON_CHALLENGE_RUN_CAPTURE_RETRIES", 1, true), "runtime must not retain retry constants")
    Assert.Nil(runtime:find("GetInstanceInfoSafe", 1, true), "runtime must not read instance info directly")
    Assert.Nil(partyRun:find("RegisterEvent", 1, true), "party-run module must not register events")
  end)

  test("Architecture CD coalescer module owns the aura filter behind the runtime lifecycle", function()
    local toc = ReadFile("isiLive.toc")
    local coalescerIndex = toc:find("logic/isiLive_event_handlers_cd_coalescer.lua", 1, true)
    local runtimeIndex = toc:find("logic/isiLive_event_handlers_runtime.lua", 1, true)
    Assert.True(coalescerIndex ~= nil, "EventHandlersCdCoalescer must be listed in the TOC")
    Assert.True(
      runtimeIndex ~= nil and coalescerIndex < runtimeIndex,
      "EventHandlersCdCoalescer must load before the runtime lifecycle"
    )

    local coalescer = ReadFile("logic/isiLive_event_handlers_cd_coalescer.lua")
    local runtime = ReadFile("logic/isiLive_event_handlers_runtime.lua")
    Assert.True(
      coalescer:find("addonTable.EventHandlersCdCoalescer = CdCoalescer", 1, true) ~= nil
        and coalescer:find("local LUST_SATED_AURA_IDS = {", 1, true) ~= nil
        and coalescer:find("local function UnitAuraUpdateRequiresCdScan(updateInfo)", 1, true) ~= nil
        and coalescer:find("local function BuildSpellCooldownCoalescer(ctx, isRaidActive)", 1, true) ~= nil
        and coalescer:find("local SPELL_COOLDOWN_COALESCE_SECONDS = 0.1", 1, true) ~= nil,
      "EventHandlersCdCoalescer must own the Sated filter and the shared 0.1s coalescer"
    )
    Assert.True(
      coalescer:find("return HandleCooldown, HandleCharges, HandlePlayerAuraCdScan", 1, true) ~= nil,
      "coalescer must keep returning the cooldown, charges and aura-scan handlers"
    )
    Assert.True(
      runtime:find(
        'local CdCoalescer = assert(addonTable.EventHandlersCdCoalescer, "isiLive: EventHandlersCdCoalescer missing")',
        1,
        true
      )
          ~= nil
        and runtime:find("BuildSpellCooldownCoalescer(ctx, IsCoalescerRaidActive)", 1, true) ~= nil,
      "runtime lifecycle must bind the coalescer at load and inject its raid check"
    )
    Assert.Nil(runtime:find("LUST_SATED_AURA_IDS", 1, true), "runtime must not duplicate the Sated ID list")
    Assert.Nil(runtime:find("ReadPlainField", 1, true), "runtime must not read aura payload fields itself")
    Assert.Nil(coalescer:find("IsRaidModeActive", 1, true), "coalescer must take the raid check as a callback")
  end)

  test("Architecture settings general module owns the General and ESC-menu sections", function()
    local toc = ReadFile("isiLive.toc")
    local generalIndex = toc:find("ui/isiLive_settings_general.lua", 1, true)
    local sectionsIndex = toc:find("ui/isiLive_settings_sections.lua", 1, true)
    local panelIndex = toc:find("ui/isiLive_settings.lua\n", 1, true)
    Assert.True(generalIndex ~= nil, "SettingsGeneral must be listed in the TOC")
    Assert.True(sectionsIndex ~= nil and panelIndex ~= nil, "SettingsSections and SettingsPanel must be in the TOC")
    Assert.True(
      generalIndex < sectionsIndex and sectionsIndex < panelIndex,
      "SettingsGeneral must load before the SettingsSections facade, which loads before SettingsPanel"
    )

    local general = ReadFile("ui/isiLive_settings_general.lua")
    local sections = ReadFile("ui/isiLive_settings_sections.lua")
    Assert.True(
      general:find("addonTable.SettingsGeneral = SettingsGeneral", 1, true) ~= nil
        and general:find("function SettingsGeneral.BuildGeneralSection(", 1, true) ~= nil
        and general:find("function SettingsGeneral.BuildEscMenuSection(", 1, true) ~= nil
        and general:find("function SettingsGeneral.RefreshGeneralControls(", 1, true) ~= nil
        and general:find("function SettingsGeneral.RefreshEscMenuControls(", 1, true) ~= nil
        and general:find("local function NormalizeStoredLayoutMode(layoutMode)", 1, true) ~= nil,
      "SettingsGeneral must own the General / ESC-menu builders, refreshers and layout-mode normalization"
    )
    Assert.True(
      sections:find(
        'local SettingsGeneral = assert(addonTable.SettingsGeneral, "isiLive: SettingsGeneral missing")',
        1,
        true
      ) ~= nil,
      "SettingsSections must bind SettingsGeneral at load"
    )
    for _, name in ipairs({
      "BuildGeneralSection",
      "BuildEscMenuSection",
      "RefreshGeneralControls",
      "RefreshEscMenuControls",
    }) do
      Assert.True(
        sections:find("SettingsSections." .. name .. " = SettingsGeneral." .. name, 1, true) ~= nil,
        "SettingsSections must keep the public name " .. name
      )
    end
    Assert.Nil(sections:find("DEFAULT_LAYOUT_MODE_", 1, true), "facade must not retain the layout-mode constants")
    Assert.Nil(sections:find("CreateLanguageSelector", 1, true), "facade must not build the language selector")
    Assert.Nil(sections:find("BuildHearthstoneSettingsOptions", 1, true), "facade must not build hearthstone options")
  end)

  test("Architecture production layers do not consume private roster UI registry", function()
    local consumers = {
      "logic/isiLive_event_handlers_runtime.lua",
      "logic/isiLive_event_handlers_party_run.lua",
      "logic/isiLive_event_handlers_cd_coalescer.lua",
      "factory/isiLive_controller_init.lua",
      "factory/isiLive_factory.lua",
      "factory/isiLive_factory_refresh.lua",
      "factory/isiLive_factory_secondary_runtime.lua",
    }
    for _, path in ipairs(consumers) do
      Assert.Nil(ReadFile(path):find("_RosterInternal", 1, true), path .. " must use explicit public APIs")
    end
  end)

  test("Architecture optional WoW globals use guarded rawget caches", function()
    local consumers = {
      ["core/isiLive_validation_helpers.lua"] = {
        'rawget(_G, "GetInstanceInfo")',
        'rawget(_G, "C_ChallengeMode")',
      },
      -- Rule 193: both "player is inside the target dungeon" checks go through
      -- the shared instance-ID helper instead of reading the player UiMapID.
      ["factory/isiLive_factory_secondary_runtime.lua"] = {
        "IsPlayerInChallengeMapInstance",
      },
      ["logic/isiLive_highlight.lua"] = {
        "IsPlayerInChallengeMapInstance",
      },
      ["logic/isiLive_keysync.lua"] = {
        "GetInstanceInfoSafe",
      },
      ["logic/isiLive_event_handlers.lua"] = {
        "GetInstanceInfoSafe",
      },
      ["factory/isiLive_factory_runtime_helpers.lua"] = {
        "GetInstanceInfoSafe",
      },
      ["ui/isiLive_status.lua"] = {
        "GetInstanceInfoSafe",
      },
      ["logic/isiLive_event_handlers_party_run.lua"] = {
        "GetInstanceInfoSafe",
      },
      ["core/isiLive_runtime_mode.lua"] = {
        "GetInstanceInfoSafe",
      },
      ["game/isiLive_season_debug.lua"] = {
        "GetInstanceInfoSafe",
      },
    }
    for path, required in pairs(consumers) do
      local content = ReadFile(path):gsub("%-%-[^\r\n]*", "")
      for _, needle in ipairs(required) do
        Assert.True(content:find(needle, 1, true) ~= nil, path .. " must contain " .. needle)
      end
      Assert.Nil(content:find("C_Map and", 1, true), path .. " must not use bare C_Map chains")
      Assert.Nil(content:find("pcall(UnitExists", 1, true), path .. " must not call bare UnitExists")
      Assert.Nil(content:find("pcall(GetInstanceInfo", 1, true), path .. " must not call bare GetInstanceInfo")
      Assert.Nil(content:find("GetInstanceInfo(", 1, true), path .. " must not call bare GetInstanceInfo")
    end

    local factoryContent = ReadFile("factory/isiLive_factory.lua"):gsub("%-%-[^\r\n]*", "")
    Assert.Nil(
      factoryContent:find("unitExists = UnitExists", 1, true),
      "factory context must not capture a bare UnitExists handle"
    )
  end)

  test("Architecture CTL wire-order simulator is enforced by local and GitHub CI", function()
    local command = "lua tools/simulate_ctl_wire_order.lua"
    local localPreflight = ReadFile("tools/validate_ci_local.ps1")
    local workflow = ReadFile(".github/workflows/lua-check.yml")
    Assert.True(localPreflight:find(command, 1, true) ~= nil, "local preflight must execute the CTL simulator")
    Assert.True(workflow:find(command, 1, true) ~= nil, "GitHub CI must execute the CTL simulator")
  end)

  test("Architecture factory does not publish mutable composition context", function()
    local content = ReadFile("factory/isiLive_factory.lua")
    Assert.Nil(content:find("tbl._factoryCtx", 1, true), "factory context must not escape through addonTable")
    Assert.True(content:find("testOptions.returnContext == true", 1, true) ~= nil, "test introspection must be opt-in")
    Assert.True(content:find("return true", 1, true) ~= nil, "production composition must return only success")
  end)

  test("Architecture event gate reuses protected dispatch slots without per-event closure tables", function()
    local content = ReadFile("logic/isiLive_events.lua")
    Assert.True(content:find("local dispatchSlots = {}", 1, true) ~= nil, "event dispatch must own a slot pool")
    Assert.True(
      content:find("local slot = dispatchSlots[dispatchDepth]", 1, true) ~= nil,
      "event dispatch must select slots by re-entrancy depth"
    )
    Assert.True(
      content:find("slot.args[index] = select(index, ...)", 1, true) ~= nil,
      "event dispatch must refill its reusable argument buffer"
    )
    Assert.Nil(content:find("local args = { ... }", 1, true), "event dispatch must not allocate argument tables")
  end)

  test("Architecture combat utility refresh keeps hidden Mythic+ pre-render without visible full render", function()
    local content = ReadFile("factory/isiLive_factory_cd_tracker.lua")
    Assert.True(content:find("local timerData = MplusTimer.GetTimerData()", 1, true) ~= nil, "timer state required")
    Assert.True(content:find("if timerData and timerData.running then", 1, true) ~= nil, "running gate required")
    Assert.True(
      content:find("if mplusRunning and not fromVisibleRender and not IsMainFrameShown() then", 1, true) ~= nil,
      "hidden event-driven Mythic+ pre-render must remain"
    )
    Assert.Nil(
      content:find("if mplusRunning and not fromVisibleRender then\n      if ctx.UpdateUI then", 1, true),
      "visible Mythic+ refreshes must not rebuild the complete roster and layout"
    )
  end)

  test("Architecture season manifest is the only manually maintained runtime season source", function()
    local toc = ReadFile("isiLive.toc")
    local seasonData = ReadFile("game/isiLive_season_data.lua")
    local lfgEntryResolver = ReadFile("game/isiLive_lfg_entry_resolver.lua")
    local status = ReadFile("ui/isiLive_status.lua")
    local forcesTool = ReadFile("tools/sync_mdt_forces.lua")
    Assert.True(toc:find("data/isiLive_seasons.lua", 1, true) ~= nil, "TOC must load the season manifest")
    Assert.True(seasonData:find("addonTable.SeasonManifest", 1, true) ~= nil, "SeasonData must compile it")
    Assert.True(
      lfgEntryResolver:find("seasonData.GetMapIDByActivityID(numID)", 1, true) ~= nil,
      "LFG entry resolution must use the season manifest"
    )
    Assert.Nil(lfgEntryResolver:find("[1542] = 557", 1, true), "LFG must not duplicate season activity ids")
    Assert.True(status:find("seasonData.GetPortalNavigatorConfig()", 1, true) ~= nil, "status must use it")
    Assert.True(forcesTool:find("season.mdtDirectory", 1, true) ~= nil, "MDT tooling must use it")
    Assert.Nil(forcesTool:find("SEASON_TO_MDT_DIR", 1, true), "MDT tooling must not duplicate seasons")
  end)

  test("Architecture automatic season wiring uses Blizzard map table and rebuilds teleport buttons", function()
    local wiring = ReadFile("factory/isiLive_controller_wiring.lua")
    Assert.True(
      wiring:find('rawget(challengeMode, "GetMapTable")', 1, true) ~= nil,
      "automatic season wiring must read Blizzard's challenge-map table through the guarded API cache"
    )
    Assert.True(
      wiring:find("seasonData.TryAutoSelectSeasonFromChallengeMapIDs(mapIDs", 1, true) ~= nil,
      "automatic season wiring must delegate exact-set selection to SeasonData"
    )
    Assert.True(
      wiring:find("controllers.teleport.BuildButtons()", 1, true) ~= nil,
      "a successful automatic season change must rebuild the teleport buttons"
    )
  end)

  test("Architecture main-frame action hierarchy uses shared semantic button roles", function()
    local common = ReadFile("ui/isiLive_ui_common.lua")
    local rosterPanel = ReadFile("ui/isiLive_roster_panel.lua")
    local rosterChrome = ReadFile("ui/isiLive_roster_panel_chrome.lua")

    Assert.True(
      common:find("function UICommon.CreateActionButton(parent, opts)", 1, true) ~= nil,
      "UICommon must own the shared semantic action-button component"
    )
    Assert.True(
      rosterChrome:find("return CreateActionButton(parent, {", 1, true) ~= nil,
      "Roster chrome must delegate flat action-button construction to UICommon"
    )
    Assert.True(
      rosterPanel:find('readyCheckButton:SetSemanticRole("primary")', 1, true) ~= nil,
      "Ready Check must be a primary main-frame action"
    )
    Assert.True(
      rosterPanel:find('countdownButton:SetSemanticRole("primary")', 1, true) ~= nil,
      "Countdown must be a primary main-frame action"
    )
    Assert.True(
      rosterPanel:find('shareKeysButton:SetSemanticRole("secondary")', 1, true) ~= nil,
      "Share Keys must remain a secondary main-frame action"
    )
    Assert.True(
      rosterPanel:find('refreshButton:SetSemanticRole("secondary")', 1, true) ~= nil,
      "Refresh must remain a secondary main-frame action"
    )
  end)
end
