local _, addonTable = ...
addonTable = addonTable or {}

local Factory = {}
addonTable.Factory = Factory

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI
local CreateFactoryContext = FI.CreateFactoryContext
local InitializeFactoryFrameBridge = FI.InitializeFactoryFrameBridge
local InitializeFactoryRuntimeHelpers = FI.InitializeFactoryRuntimeHelpers
local InitializeFactoryPrimaryControllers = FI.InitializeFactoryPrimaryControllers
local InitializeFactoryRefreshAndStatusControllers = FI.InitializeFactoryRefreshAndStatusControllers
local InitializeFactorySecondaryControllers = FI.InitializeFactorySecondaryControllers
local CreateFactoryMinimapButton = FI.CreateFactoryMinimapButton

local function ResolveAutoCloseMainFrameEnabled(dbRef)
  return type(dbRef) == "table" and dbRef.autoCloseMainFrame == true
end

local function ResolveAutoShowMainFrameOnStartupEnabled(dbRef)
  return not (type(dbRef) == "table" and dbRef.autoShowMainFrameOnStartup == false)
end

local function ResolveAutoOpenMainFrameOnKeyEndEnabled(dbRef)
  return not (type(dbRef) == "table" and dbRef.autoOpenMainFrameOnKeyEnd == false)
end

local function ResolveRaidTransitionBehavior(dbRef)
  if type(dbRef) ~= "table" then
    return "hide"
  end

  return "hide"
end

FI.ResolveAutoCloseMainFrameEnabled = ResolveAutoCloseMainFrameEnabled
FI.ResolveAutoShowMainFrameOnStartupEnabled = ResolveAutoShowMainFrameOnStartupEnabled
FI.ResolveAutoOpenMainFrameOnKeyEndEnabled = ResolveAutoOpenMainFrameOnKeyEndEnabled
FI.ResolveRaidTransitionBehavior = ResolveRaidTransitionBehavior

local function FinalizeFactorySettings(ctx)
  local modules = ctx.modules

  if modules.settingsPanel and type(modules.settingsPanel.Create) == "function" then
    ctx.settingsPanel = modules.settingsPanel.Create({
      getL = ctx.GetL,
      setLanguage = ctx.SetLanguage,
      getCurrentLocale = function()
        return IsiLiveDB and IsiLiveDB.locale or ctx.locale
      end,
      getDB = function()
        return IsiLiveDB or {}
      end,
      onEscPanelToggle = function(_enabled)
        if ctx.panelUI and type(ctx.panelUI.SyncVisibility) == "function" then
          ctx.panelUI.SyncVisibility()
        end
        if ctx.secondPanelUI and type(ctx.secondPanelUI.SyncVisibility) == "function" then
          ctx.secondPanelUI.SyncVisibility()
        end
      end,
      getQueueDebugEnabled = function()
        if ctx.queueDebugController and type(ctx.queueDebugController.IsEnabled) == "function" then
          return ctx.queueDebugController.IsEnabled()
        end
        return false
      end,
      onQueueDebugToggle = function(enabled)
        if ctx.queueDebugController and type(ctx.queueDebugController.SetEnabled) == "function" then
          ctx.queueDebugController.SetEnabled(enabled)
        end
      end,
      getRuntimeLogEnabled = function()
        if ctx.runtimeLogController and type(ctx.runtimeLogController.IsEnabled) == "function" then
          return ctx.runtimeLogController.IsEnabled()
        end
        return false
      end,
      onRuntimeLogToggle = function(enabled)
        if ctx.runtimeLogController and type(ctx.runtimeLogController.SetEnabled) == "function" then
          ctx.runtimeLogController.SetEnabled(enabled)
        end
      end,
      onPortalNavigatorToggle = function(_enabled)
        if ctx.statusController and type(ctx.statusController.MaybeShowPortalNavigatorNotice) == "function" then
          ctx.statusController.MaybeShowPortalNavigatorNotice()
        end
      end,
      onBgAlphaChange = function(val)
        local uiCommon = ctx.addonTable and ctx.addonTable.UICommon
        if type(uiCommon) == "table" and type(uiCommon.Colors) == "table" then
          uiCommon.Colors.BG_PRIMARY[4] = val
        end
        if ctx.mainFrame and type(ctx.mainFrame.SetBackdropColor) == "function" then
          ctx.mainFrame:SetBackdropColor(0, 0, 0, val)
        end
        local bg = uiCommon and uiCommon.Colors and uiCommon.Colors.BG_PRIMARY or { 0.08, 0.08, 0.12, val }
        if ctx.panelUI and ctx.panelUI.panelFrame and type(ctx.panelUI.panelFrame.SetBackdropColor) == "function" then
          ctx.panelUI.panelFrame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        end
        if
          ctx.settingsPanel
          and ctx.settingsPanel.canvas
          and type(ctx.settingsPanel.canvas.SetBackdropColor) == "function"
        then
          ctx.settingsPanel.canvas:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        end
      end,
      onUiScaleChange = function(val)
        if ctx.mainFrame and type(ctx.mainFrame.SetScale) == "function" then
          ctx.mainFrame:SetScale(val)
        end
      end,
      onSyncToggle = function(_enabled)
        -- Runtime reads IsiLiveDB.syncEnabled directly; no additional action needed
      end,
      onShowDpsColumnToggle = function(_enabled)
        if ctx.rosterPanelController and type(ctx.rosterPanelController.RenderRoster) == "function" then
          ctx.rosterPanelController.RenderRoster(ctx.GetRoster())
        end
      end,
      onRosterColumnGuidesToggle = function(_enabled)
        if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshLayoutState) == "function" then
          ctx.rosterPanelController.RefreshLayoutState()
        elseif ctx.rosterPanelController and type(ctx.rosterPanelController.RenderRoster) == "function" then
          ctx.rosterPanelController.RenderRoster(ctx.GetRoster())
        end
      end,
      onMinimapButtonToggle = function(enabled)
        if ctx.minimapButton then
          if enabled then
            ctx.minimapButton:Show()
          else
            ctx.minimapButton:Hide()
          end
        end
      end,
      onAutoOpenQueueToggle = function(_enabled)
        -- Runtime reads IsiLiveDB.autoOpenOnQueue directly; no additional action needed
      end,
      onAutoCloseMainFrameToggle = function(_enabled)
        -- Runtime reads IsiLiveDB.autoCloseMainFrame directly; no additional action needed.
      end,
      onCombatFadeMMToggle = function(_enabled)
        -- Runtime reads IsiLiveDB.combatFadeMM directly; no additional action needed.
      end,
      onAutoShowMainFrameOnStartupToggle = function(_enabled)
        -- Runtime reads IsiLiveDB.autoShowMainFrameOnStartup directly; no additional action needed.
      end,
      onAutoOpenMainFrameOnKeyEndToggle = function(_enabled)
        -- Runtime reads IsiLiveDB.autoOpenMainFrameOnKeyEnd directly; no additional action needed.
      end,
      onRaidTransitionBehaviorChange = function(_behavior)
        -- Runtime reads IsiLiveDB.raidTransitionBehavior directly; no additional action needed.
      end,
      onDefaultLayoutModeChange = function(_layoutMode)
        ctx.RestoreLayoutState()
      end,
      onNameMaxCharsChange = function(_maxChars)
        if ctx.rosterPanelController and type(ctx.rosterPanelController.RenderRoster) == "function" then
          ctx.rosterPanelController.RenderRoster(ctx.GetRoster())
        end
      end,
      onMarkersLeaderOnlyToggle = function(_enabled)
        if ctx.rosterPanelController and type(ctx.rosterPanelController.RenderRoster) == "function" then
          ctx.rosterPanelController.RenderRoster(ctx.GetRoster())
        end
      end,
      onTeleportColumnsChange = function(_columns)
        if ctx.teleportUIController and type(ctx.teleportUIController.UpdateButtons) == "function" then
          ctx.teleportUIController.UpdateButtons(ctx.ResolveTeleportSpellID())
        end
      end,
      onResetDB = function()
        ctx.resetDB()
      end,
    })
  end

  -- Restore saved UI Scale
  if IsiLiveDB and type(IsiLiveDB.uiScale) == "number" and IsiLiveDB.uiScale ~= 1.0 then
    if ctx.mainFrame and type(ctx.mainFrame.SetScale) == "function" then
      ctx.mainFrame:SetScale(IsiLiveDB.uiScale)
    end
  end

  -- Minimap Button: create with correct initial visibility so MinimapButtonButton
  -- sees the right shown-state when it scans on PLAYER_LOGIN.
  -- IsiLiveDB is already populated from SavedVariables at file-load time.
  -- Create always hidden; ADDON_LOADED handler shows it if the setting is enabled.
  -- SavedVariables (IsiLiveDB) are not yet available at file-load time.
  ctx.minimapButton = CreateFactoryMinimapButton(ctx)
  if ctx.minimapButton then
    ctx.minimapButton:Hide()
  end
end

local function FinalizeFactoryRuntime(ctx)
  local modules = ctx.modules
  local runtimeState = ctx.runtimeState
  local isiLiveRuntimeSetup = modules.runtimeSetup

  ctx.inspectController = modules.inspect.CreateController({
    inspectTimeout = ctx.INSPECT_TIMEOUT,
    retryInterval = ctx.RETRY_INTERVAL,
    inspectDelay = ctx.INSPECT_DELAY,
    sendOwnKeySnapshot = ctx.SendOwnKeySnapshot,
  })
  ctx.OnEvent = function(self, event, ...)
    ctx.eventHandlersController.Dispatch(self, event, ...)
  end
  ctx.InspectLoop = function(_self, elapsed)
    ctx.inspectLoopTimer = ctx.inspectLoopTimer + (elapsed or 0)
    if ctx.inspectLoopTimer >= 0.25 then
      ctx.inspectLoopTimer = 0
      if ctx.GetActiveChallengeMapID() then
        return
      end
      ctx.inspectController.OnUpdate()
    end
  end

  ctx.resetDB = function()
    local reloadUI = rawget(_G, "ReloadUI")
    IsiLiveDB = nil
    ctx.Print((ctx.GetL() or {}).RESET_DB_DONE or "Settings reset. Reloading UI...")
    if type(reloadUI) == "function" then
      reloadUI()
    end
  end

  modules.bootstrap.RegisterMainFrameEvents(ctx.mainFrame)
  modules.bootstrap.BindMainFrameScripts(ctx.mainFrame, {
    onShow = function()
      ctx.SetProcessingActive(true)
      if ctx.rosterPanelController and ctx.rosterPanelController.RefreshSystemOptionToggles then
        ctx.rosterPanelController.RefreshSystemOptionToggles()
      end
      if IsInGroup() and ctx.SendOwnKeySnapshot then
        ctx.SendOwnKeySnapshot(true, "show")
      end
    end,
    onHide = function()
      ctx.SetProcessingActive(false)
    end,
  })

  local runtimeSetupResult = isiLiveRuntimeSetup.Configure({
    controllerWiring = modules.controllerWiring,
    configBuilders = modules.configBuilders,
    bootstrap = modules.bootstrap,
    leaderWatchModule = modules.leaderWatch,
    groupModule = modules.group,
    eventHandlersModule = modules.eventHandlers,
    mainFrame = ctx.mainFrame,
    onEvent = ctx.OnEvent,
    onDispatchError = function(_frame, event, err)
      ctx.Print(string.format("Event dispatch failed (%s): %s", tostring(event), tostring(err)))
    end,
    sync = modules.sync,
    events = modules.events,
    commands = modules.commands,
    isInGroup = IsInGroup,
    getNumGroupMembers = GetNumGroupMembers,
    getActiveChallengeMapID = ctx.GetActiveChallengeMapID,
    getWasInGroup = ctx.GetWasInGroup,
    setWasInGroup = ctx.SetWasInGroup,
    getWasRaidGroup = ctx.GetWasRaidGroup,
    setWasRaidGroup = ctx.SetWasRaidGroup,
    isRosterCollapsed = ctx.IsRosterCollapsed,
    switchToRaidMode = ctx.SwitchToRaidMode,
    isRaidGroup = ctx.IsRaidGroup,
    setWasGroupLeader = ctx.SetWasGroupLeader,
    getWasGroupLeader = ctx.GetWasGroupLeader,
    getRoster = ctx.GetRoster,
    setRoster = ctx.SetRoster,
    captureQueueJoinCandidate = ctx.CaptureQueueJoinCandidate,
    announceQueuedGroupJoin = ctx.AnnounceQueuedGroupJoin,
    setMainFrameVisible = ctx.SetMainFrameVisible,
    setMainFrameHeightSafe = ctx.SetMainFrameHeightSafe,
    setMainFrameWidthSafe = ctx.SetMainFrameWidthSafe,
    updateLeaderButtons = ctx.UpdateLeaderButtons,
    clearLatestQueueTarget = ctx.ClearLatestQueueTarget,
    clearRioBaselineSnapshot = ctx.ClearRioBaselineSnapshot,
    clearPendingQueueJoinInfo = function()
      runtimeState.SetPendingQueueJoinInfo(nil)
    end,
    resetInspectAll = ctx.ResetInspectAll,
    resetInspectQueues = ctx.ResetInspectQueues,
    updateUI = ctx.UpdateUI,
    refreshReadyCheckUI = ctx.RefreshReadyCheckUI,
    updateMPlusTeleportButton = ctx.UpdateMPlusTeleportButton,
    getUnitNameAndRealm = ctx.GetUnitNameAndRealm,
    getUnitClass = ctx.GetUnitClass,
    getUnitServerLanguage = ctx.GetUnitServerLanguage,
    getOwnedKeystoneSnapshot = ctx.GetOwnedKeystoneSnapshot,
    markIsiLiveUser = ctx.MarkIsiLiveUser,
    getUnitRole = ctx.GetUnitRole,
    getPlayerSpecName = ctx.GetPlayerSpecName,
    getUnitRio = ctx.GetUnitRio,
    getInspectSpecName = ctx.GetInspectSpecName,
    unitHasIsiLive = ctx.UnitHasIsiLive,
    applyKnownKeyToRosterEntry = ctx.ApplyKnownKeyToRosterEntry,
    enqueueInspect = ctx.EnqueueInspect,
    sendOwnKeySnapshot = ctx.SendOwnKeySnapshot,
    sendOwnBackgroundSnapshot = ctx.SendOwnBackgroundSnapshot,
    sendRefreshRequest = ctx.SendRefreshRequest,
    sendOwnTargetSnapshot = ctx.SendOwnTargetSnapshot,
    sendRefreshResponse = ctx.SendRefreshResponse,
    sendIsiLiveHello = ctx.SendIsiLiveHello,
    shouldAutoCloseMainFrame = function()
      local dbRef = rawget(_G, "IsiLiveDB")
      return ResolveAutoCloseMainFrameEnabled(dbRef)
    end,
    shouldShowMainFrameOnStartup = function()
      local dbRef = rawget(_G, "IsiLiveDB")
      return ResolveAutoShowMainFrameOnStartupEnabled(dbRef)
    end,
    shouldAutoOpenMainFrameOnKeyEnd = function()
      local dbRef = rawget(_G, "IsiLiveDB")
      return ResolveAutoOpenMainFrameOnKeyEndEnabled(dbRef)
    end,
    getRaidTransitionBehavior = function()
      local dbRef = rawget(_G, "IsiLiveDB")
      return ResolveRaidTransitionBehavior(dbRef)
    end,
    autoCloseMainFrame = function()
      if ctx.mainFrame:IsShown() then
        ctx.SetMainFrameVisible(false)
      end
    end,
    unitIsGroupLeader = function(unit)
      if type(unit) ~= "string" or unit == "" then
        return false
      end

      local unitExists = rawget(_G, "UnitExists")
      if type(unitExists) ~= "function" then
        return false
      end

      local okExists, exists = pcall(unitExists, unit)
      if not okExists or not exists then
        return false
      end

      local unitIsGroupLeader = rawget(_G, "UnitIsGroupLeader")
      if type(unitIsGroupLeader) ~= "function" then
        return false
      end

      local okLeader, isLeader = pcall(unitIsGroupLeader, unit)
      return okLeader and isLeader == true
    end,
    unitExists = UnitExists,
    getRaidTargetIndex = rawget(_G, "GetRaidTargetIndex"),
    setRaidTarget = rawget(_G, "SetRaidTarget"),
    isPlayerLeader = ctx.IsPlayerLeader,
    isStopped = runtimeState.IsStopped,
    isPaused = runtimeState.IsPaused,
    isTestMode = runtimeState.IsTestMode,
    isInCombat = ctx.IsInCombat,
    isInPartyInstance = ctx.IsInPartyInstance,
    isTestAllMode = runtimeState.IsTestAllMode,
    getL = ctx.GetL,
    printFn = ctx.Print,
    showCenterNotice = ctx.ShowCenterNotice,
    isMainFrameShown = function()
      return ctx.mainFrame and ctx.mainFrame:IsShown()
    end,
    defaultLocale = ctx.locale,
    locales = ctx.locales,
    resolveLocaleTag = modules.locale.ResolveLocaleTag,
    setLocaleTable = ctx.SetLocaleTable,
    isInChallengeMode = ctx.GetActiveChallengeMapID,
    isNegativeApplicationStatusEvent = ctx.IsNegativeApplicationStatusEvent,
    getNormalizedActiveEntryInfo = ctx.GetNormalizedActiveEntryInfo,
    ensureQueueDebugStorage = ctx.queueDebugController.EnsureStorage,
    setQueueDebugEnabled = ctx.queueDebugController.SetEnabled,
    ensureRuntimeLogStorage = ctx.runtimeLogController.EnsureStorage,
    setRuntimeLogEnabled = ctx.runtimeLogController.SetEnabled,
    registerIsiLiveSyncPrefix = ctx.RegisterIsiLiveSyncPrefix,
    applyHotkeyBindings = ctx.ApplyHotkeyBindings,
    startBindingWatchdog = ctx.StartBindingWatchdog,
    getAddonVersionRaw = ctx.GetAddonVersionRaw,
    getTime = GetTime,
    getPendingQueueJoinInfo = runtimeState.GetPendingQueueJoinInfo,
    setPendingQueueJoinInfo = runtimeState.SetPendingQueueJoinInfo,
    getActiveJoinedKeyMapID = runtimeState.GetActiveJoinedKeyMapID,
    setActiveJoinedKeyMapID = runtimeState.SetActiveJoinedKeyMapID,
    getPendingBindingApply = ctx.GetPendingBindingApply,
    mainUI = ctx.mainUI,
    centerNotice = ctx.centerNotice,
    centerNoticeFrame = ctx.centerNoticeFrame,
    centerNoticeTeleportButton = ctx.centerNoticeTeleportButton,
    applySecureSpellToButton = ctx.ApplySecureSpellToButton,
    refreshController = ctx.refreshController,
    inspectController = ctx.inspectController,
    statusController = ctx.statusController,
    exitTestMode = ctx.ExitTestMode,
    updateStatusLine = ctx.UpdateStatusLine,
    applyLocalizationToUI = ctx.ApplyLocalizationToUI,
    updateCountdownCancelButton = ctx.UpdateCountdownCancelButton,
    restoreLayoutState = ctx.RestoreLayoutState,
    checkIfEnteredTargetDungeon = ctx.CheckIfEnteredTargetDungeon,
    captureRioBaselineSnapshot = ctx.CaptureRioBaselineSnapshot,
    restoreRioBaseline = ctx.RestoreRioBaseline,
    isReadyCheckActive = ctx.IsReadyCheckActive,
    setReadyCheckActive = ctx.SetReadyCheckActive,
    enableRioDeltaDisplay = ctx.EnableRioDeltaDisplay,
    setCenterNoticeVisible = ctx.SetCenterNoticeVisible,
    getState = runtimeState.GetRuntimeFlags,
    setState = runtimeState.PatchRuntimeFlags,
    triggerGroupRosterUpdate = ctx.TriggerGroupRosterUpdate,
    toggleStandardTestMode = ctx.ToggleStandardTestMode,
    enterFullDummyPreview = ctx.EnterFullDummyPreview,
    setLanguage = ctx.SetLanguage,
    teleportDebugController = ctx.teleportDebugController,
    queueDebugController = ctx.queueDebugController,
    runtimeLogController = ctx.runtimeLogController,
    recordRun = ctx.RecordRun,
    addonName = ctx.addonName,
    resetDB = ctx.resetDB,
  })

  ctx.eventHandlersController = runtimeSetupResult.eventHandlersController
  ctx.Print(string.format(ctx.L.LOADED_HINT, ctx.GetAddonVersionRaw()))

  FinalizeFactorySettings(ctx)
end

function Factory.InitializeAddon(addonName, tbl)
  local ctx = CreateFactoryContext(addonName, tbl)
  if not ctx then
    return
  end

  InitializeFactoryFrameBridge(ctx)
  InitializeFactoryRuntimeHelpers(ctx)
  InitializeFactoryPrimaryControllers(ctx)
  InitializeFactoryRefreshAndStatusControllers(ctx)
  InitializeFactorySecondaryControllers(ctx)
  FinalizeFactoryRuntime(ctx)
end
