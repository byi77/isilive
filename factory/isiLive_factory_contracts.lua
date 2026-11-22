local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

-- Named dependency contracts of the composition root. Each builder returns
-- the small set of callbacks one feature needs from the factory context;
-- RuntimeSetup contexts are composed from these sets instead of one large,
-- hand-filled table. Every key has exactly one owning contract: Compose
-- raises on a duplicate, so two contracts can never silently shadow each
-- other. A builder reads ctx at composition time, exactly like the former
-- inline tables; late-bound values stay explicit closures.
local Contracts = {}
FI.FactoryContracts = Contracts

--- Merges contract tables into one context table.
-- @param label string Context name used in the duplicate-key error.
-- @param ... table Contract tables (each built by one Contracts.* builder).
-- @return table
function Contracts.Compose(label, ...)
  local merged = {}
  local owners = {}
  for index = 1, select("#", ...) do
    local contract = select(index, ...)
    if type(contract) ~= "table" then
      error(string.format("%s: contract #%d is not a table", tostring(label), index), 2)
    end
    for key, value in pairs(contract) do
      if owners[key] ~= nil then
        error(string.format("%s: key %q provided by contract #%d and #%d", tostring(label), key, owners[key], index), 2)
      end
      owners[key] = index
      merged[key] = value
    end
  end
  return merged
end

-- DB preference readers. Exported through FI for the resolver scenarios.

-- Auto-close when the M+ keystone starts. Default OFF: only an explicit
-- user-enabled boolean true may close the main UI on key start.
local function ResolveAutoCloseOnKeyStartEnabled(dbRef)
  return type(dbRef) == "table" and dbRef.autoCloseOnKeyStart == true
end

local function ResolveAutoCloseOnSoloChangeEnabled(dbRef)
  return type(dbRef) == "table" and dbRef.autoCloseOnSoloChange == true
end

local function ResolveAutoShowMainFrameOnStartupEnabled(dbRef)
  return not (type(dbRef) == "table" and dbRef.autoShowMainFrameOnStartup == false)
end

local function ResolveAutoOpenMainFrameOnKeyEndEnabled(dbRef)
  return not (type(dbRef) == "table" and dbRef.autoOpenMainFrameOnKeyEnd == false)
end

local function ResolveMainFramePositionLockEnabled(dbRef)
  return not (type(dbRef) == "table" and dbRef.lockMainFramePosition == false)
end

local function ResolveRaidTransitionBehavior(dbRef)
  if type(dbRef) ~= "table" then
    return "hide"
  end

  return "hide"
end

FI.ResolveAutoCloseOnKeyStartEnabled = ResolveAutoCloseOnKeyStartEnabled
FI.ResolveAutoCloseOnSoloChangeEnabled = ResolveAutoCloseOnSoloChangeEnabled
FI.ResolveAutoShowMainFrameOnStartupEnabled = ResolveAutoShowMainFrameOnStartupEnabled
FI.ResolveAutoOpenMainFrameOnKeyEndEnabled = ResolveAutoOpenMainFrameOnKeyEndEnabled
FI.ResolveMainFramePositionLockEnabled = ResolveMainFramePositionLockEnabled
FI.ResolveRaidTransitionBehavior = ResolveRaidTransitionBehavior

local function ReadDB()
  return rawget(_G, "IsiLiveDB")
end

local function IsMainFrameShownFn(ctx)
  return function()
    return ctx.mainFrame and ctx.mainFrame:IsShown()
  end
end

-- UnitIsGroupLeader behind secret-value and existence guards. The factory
-- context exposes no direct unit-existence handle.
local function UnitIsGroupLeaderSafe(unit)
  if type(unit) ~= "string" or unit == "" then
    return false
  end

  local unitExists = rawget(_G, "UnitExists")
  if type(unitExists) ~= "function" then
    return false
  end

  local okExists, exists = pcall(unitExists, unit)
  if not okExists or addonTable.Validators.IsSecretValue(exists) or exists ~= true then
    return false
  end

  local unitIsGroupLeader = rawget(_G, "UnitIsGroupLeader")
  if type(unitIsGroupLeader) ~= "function" then
    return false
  end

  local okLeader, isLeader = pcall(unitIsGroupLeader, unit)
  return okLeader and not addonTable.Validators.IsSecretValue(isLeader) and isLeader == true
end

-- ---------------------------------------------------------------------------
-- Contracts shared by the group controller and the event handlers.
-- ---------------------------------------------------------------------------

--- Group membership and the remembered previous group shape.
function Contracts.GroupMembership(ctx)
  return {
    isInGroup = IsInGroup,
    getNumGroupMembers = GetNumGroupMembers,
    getActiveChallengeMapID = ctx.GetActiveChallengeMapID,
    isRaidGroup = ctx.IsRaidGroup,
    getWasInGroup = ctx.GetWasInGroup,
    setWasInGroup = ctx.SetWasInGroup,
    getWasRaidGroup = ctx.GetWasRaidGroup,
    setWasRaidGroup = ctx.SetWasRaidGroup,
    isRosterCollapsed = ctx.IsRosterCollapsed,
    setWasGroupLeader = ctx.SetWasGroupLeader,
  }
end

--- Roster model and the per-unit readers that fill it.
function Contracts.RosterData(ctx)
  return {
    getRoster = ctx.GetRoster,
    setRoster = ctx.SetRoster,
    getUnitNameAndRealm = ctx.GetUnitNameAndRealm,
    getUnitClass = ctx.GetUnitClass,
    getUnitServerLanguage = ctx.GetUnitServerLanguage,
    getOwnedKeystoneSnapshot = ctx.GetOwnedKeystoneSnapshot,
    markIsiLiveUser = ctx.MarkIsiLiveUser,
    getUnitRole = ctx.GetUnitRole,
    getPlayerSpecName = ctx.GetPlayerSpecName,
    getUnitRio = ctx.GetUnitRio,
    getOwnAverageItemLevel = ctx.GetOwnAverageItemLevel,
    unitHasIsiLive = ctx.UnitHasIsiLive,
    applyKnownKeyToRosterEntry = ctx.ApplyKnownKeyToRosterEntry,
    unitIsGroupLeader = UnitIsGroupLeaderSafe,
  }
end

--- Inspect queue control.
function Contracts.InspectQueue(ctx)
  return {
    enqueueInspect = ctx.EnqueueInspect,
    resetInspectAll = ctx.ResetInspectAll,
    resetInspectQueues = ctx.ResetInspectQueues,
  }
end

--- Queue-join bookkeeping around a group join or leave, including the RIO
-- baseline that a join invalidates.
function Contracts.QueueJoin(ctx, runtimeState)
  return {
    captureQueueJoinCandidate = ctx.CaptureQueueJoinCandidate,
    announceQueuedGroupJoin = ctx.AnnounceQueuedGroupJoin,
    clearLatestQueueTarget = ctx.ClearLatestQueueTarget,
    clearRioBaselineSnapshot = ctx.ClearRioBaselineSnapshot,
    clearPendingQueueJoinInfo = function()
      runtimeState.SetPendingQueueJoinInfo(nil)
    end,
  }
end

--- Own-state broadcasts a roster change triggers.
function Contracts.GroupSyncSenders(ctx)
  return {
    sendOwnKeySnapshot = ctx.SendOwnKeySnapshot,
    sendIsiLiveHello = ctx.SendIsiLiveHello,
    sendRefreshRequest = ctx.SendRefreshRequest,
  }
end

--- Persisted roster mirror that bridges a /reload.
function Contracts.ReloadRosterMirror(ctx)
  return {
    getReloadRosterMirror = function()
      local dbRef = ReadDB()
      return type(dbRef) == "table" and dbRef.reloadRosterMirror or nil
    end,
    setReloadRosterMirror = function(snapshot)
      local dbRef = ReadDB()
      if type(dbRef) == "table" then
        dbRef.reloadRosterMirror = snapshot
      end
    end,
    clearReloadRosterMirror = function()
      local dbRef = ReadDB()
      if type(dbRef) == "table" then
        dbRef.reloadRosterMirror = {}
      end
    end,
    getReloadRosterTargetSnapshot = ctx.GetReloadRosterTargetSnapshot,
    restoreReloadRosterTargetSnapshot = ctx.RestoreReloadRosterTargetSnapshot,
  }
end

--- Main window visibility and its group-change auto-close preferences.
function Contracts.MainFrameAutoClose(ctx)
  return {
    setMainFrameVisible = ctx.SetMainFrameVisible,
    isMainFrameVisible = ctx.IsMainFrameVisible,
    shouldAutoCloseOnSoloChange = function()
      return ResolveAutoCloseOnSoloChangeEnabled(ReadDB())
    end,
    getRaidTransitionBehavior = function()
      return ResolveRaidTransitionBehavior(ReadDB())
    end,
    autoCloseMainFrame = function()
      if ctx.mainFrame:IsShown() then
        ctx.SetMainFrameVisible(false)
      end
    end,
  }
end

--- Re-render entry points.
function Contracts.UiRefresh(ctx)
  return {
    updateUI = ctx.UpdateUI,
    updateMPlusTeleportButton = ctx.UpdateMPlusTeleportButton,
    updateLeaderButtons = ctx.UpdateLeaderButtons,
  }
end

--- Localized chat output and the runtime trace log.
function Contracts.ChatOutput(ctx)
  return {
    runtimeLogController = ctx.runtimeLogController,
    getL = ctx.GetL,
    printFn = ctx.Print,
  }
end

-- ---------------------------------------------------------------------------
-- Contracts used only by the event handlers.
-- ---------------------------------------------------------------------------

--- Ready-check member state and its roster refresh.
function Contracts.ReadyCheck(ctx)
  return {
    GetReadyCheckReadyUntil = ctx.GetReadyCheckReadyUntil,
    SetReadyCheckReadyUntil = ctx.SetReadyCheckReadyUntil,
    ClearAllReadyCheckReady = ctx.ClearAllReadyCheckReady,
    ClearExpiredReadyCheckReady = ctx.ClearExpiredReadyCheckReady,
    GetReadyCheckDeclinedUntil = ctx.GetReadyCheckDeclinedUntil,
    SetReadyCheckDeclinedUntil = ctx.SetReadyCheckDeclinedUntil,
    ClearAllReadyCheckDeclined = ctx.ClearAllReadyCheckDeclined,
    ClearExpiredReadyCheckDeclined = ctx.ClearExpiredReadyCheckDeclined,
    refreshReadyCheckUI = ctx.RefreshReadyCheckUI,
    isReadyCheckActive = ctx.IsReadyCheckActive,
    setReadyCheckActive = ctx.SetReadyCheckActive,
  }
end

--- Combat utilities: kick tracker, BR/Lust and Power Infusion announces,
-- the CD tracker row and the kick column.
function Contracts.CombatUtilities(ctx)
  return {
    HandleKickTrackerEvent = ctx.HandleKickTrackerEvent,
    -- Defensive tracker (rule 267): rides on the kick tracker's event stream
    -- and on the own kick state's fan-out (controller wiring).
    HandleDefensiveTrackerEvent = ctx.HandleDefensiveTrackerEvent,
    SendOwnDefensiveState = ctx.SendOwnDefensiveState,
    ShowCombatAnnounce = ctx.ShowCombatAnnounce,
    ShowPowerInfusionAnnounce = ctx.ShowPowerInfusionAnnounce,
    UpdateCdTracker = ctx.UpdateCdTracker,
    -- Late-bound: the roster panel controller exists only after wiring.
    refreshKickColumn = function()
      local panel = ctx.rosterPanelController
      if type(panel) ~= "table" or type(panel.RefreshKickColumn) ~= "function" then
        return false
      end
      panel.RefreshKickColumn()
      return true
    end,
  }
end

--- Share-keys button cooldown, local and peer-mirrored.
function Contracts.ShareKeys(ctx)
  return {
    TriggerShareKeysCooldown = ctx.TriggerShareKeysCooldown,
    GetShareKeysCooldownRemaining = ctx.GetShareKeysCooldownRemaining,
    GetShareKeysLocalCooldownRemaining = ctx.GetShareKeysLocalCooldownRemaining,
  }
end

--- Sync replies and background broadcasts sent from event handlers.
function Contracts.EventSyncSenders(ctx)
  return {
    registerIsiLiveSyncPrefix = ctx.RegisterIsiLiveSyncPrefix,
    sendOwnBackgroundSnapshot = ctx.SendOwnBackgroundSnapshot,
    sendOwnTargetSnapshot = ctx.SendOwnTargetSnapshot,
    sendOwnKickState = ctx.SendOwnKickState,
    sendRefreshResponse = ctx.SendRefreshResponse,
    sendLibKeystonePartyData = ctx.SendLibKeystonePartyData,
  }
end

--- Main window lifecycle: startup and key-boundary open/close preferences,
-- size setters and layout/background restore.
function Contracts.MainFrameLifecycle(ctx)
  return {
    isMainFrameShown = IsMainFrameShownFn(ctx),
    setMainFrameHeightSafe = ctx.SetMainFrameHeightSafe,
    setMainFrameWidthSafe = ctx.SetMainFrameWidthSafe,
    shouldAutoCloseOnKeyStart = function()
      return ResolveAutoCloseOnKeyStartEnabled(ReadDB())
    end,
    shouldShowMainFrameOnStartup = function()
      return ResolveAutoShowMainFrameOnStartupEnabled(ReadDB())
    end,
    shouldAutoOpenMainFrameOnKeyEnd = function()
      return ResolveAutoOpenMainFrameOnKeyEndEnabled(ReadDB())
    end,
    restoreLayoutState = ctx.RestoreLayoutState,
    RestoreBgAlpha = ctx.RestoreBgAlpha,
  }
end

--- Module handles the event handlers dispatch into.
function Contracts.Modules(ctx)
  local modules = ctx.modules
  return {
    modules = modules,
    sync = modules.sync,
    events = modules.events,
    commands = modules.commands,
  }
end

--- Local leader status and the leader-only buttons.
function Contracts.Leadership(ctx)
  return {
    isPlayerLeader = ctx.IsPlayerLeader,
    getWasGroupLeader = ctx.GetWasGroupLeader,
    applyPendingLeaderButtonUpdates = ctx.ApplyPendingLeaderButtonUpdates,
  }
end

--- Specialization readers backed by the inspect results.
function Contracts.InspectSpec(ctx)
  return {
    getInspectSpecName = ctx.GetInspectSpecName,
    getInspectSpecRole = ctx.GetInspectSpecRole,
  }
end

--- Key-end outcome strip and run recording.
function Contracts.KeyEnd(ctx)
  return {
    showKeyEndOutcome = function(outcome)
      if ctx.rosterPanelController and type(ctx.rosterPanelController.PlayKillTrackRunEnd) == "function" then
        ctx.rosterPanelController.PlayKillTrackRunEnd(outcome)
      end
    end,
    clearKeyEndOutcome = function()
      if ctx.rosterPanelController and type(ctx.rosterPanelController.ClearKillTrackRunEnd) == "function" then
        ctx.rosterPanelController.ClearKillTrackRunEnd()
      end
    end,
    recordRun = ctx.RecordRun,
  }
end

--- Runtime gates (stopped, paused, test mode, combat) and the raw flag table.
function Contracts.RuntimeFlags(ctx, runtimeState)
  return {
    isStopped = runtimeState.IsStopped,
    isPaused = runtimeState.IsPaused,
    isTestMode = runtimeState.IsTestMode,
    isTestAllMode = runtimeState.IsTestAllMode,
    isInCombat = ctx.IsInCombat,
    isInPartyInstance = ctx.IsInPartyInstance,
    getState = runtimeState.GetRuntimeFlags,
    setState = runtimeState.PatchRuntimeFlags,
    getTime = GetTime,
  }
end

--- Pending queue join, post-challenge refresh and tracked party-run state.
function Contracts.PartyRunState(runtimeState)
  return {
    getPendingQueueJoinInfo = runtimeState.GetPendingQueueJoinInfo,
    setPendingQueueJoinInfo = runtimeState.SetPendingQueueJoinInfo,
    getPendingPostChallengeRefresh = runtimeState.GetPendingPostChallengeRefresh,
    setPendingPostChallengeRefresh = runtimeState.SetPendingPostChallengeRefresh,
    setTrackedPartyRunInfo = runtimeState.SetTrackedPartyRunInfo,
    clearTrackedPartyRunInfo = runtimeState.ClearTrackedPartyRunInfo,
    isTrackedPartyRunActive = runtimeState.IsTrackedPartyRunActive,
    getActiveJoinedKeyMapID = runtimeState.GetActiveJoinedKeyMapID,
    setActiveJoinedKeyMapID = runtimeState.SetActiveJoinedKeyMapID,
  }
end

--- Locale switching and the localized UI rebind.
function Contracts.Localization(ctx)
  return {
    defaultLocale = ctx.locale,
    locales = ctx.locales,
    resolveLocaleTag = ctx.modules.locale.ResolveLocaleTag,
    setLocaleTable = ctx.SetLocaleTable,
    setLanguage = ctx.SetLanguage,
    applyLocalizationToUI = ctx.ApplyLocalizationToUI,
    printLoadedHint = ctx.PrintLoadedHint,
  }
end

--- LFG listing state and the target-dungeon entry check.
function Contracts.LfgQueue(ctx)
  return {
    isInChallengeMode = ctx.GetActiveChallengeMapID,
    isNegativeApplicationStatusEvent = ctx.IsNegativeApplicationStatusEvent,
    getNormalizedActiveEntryInfo = ctx.GetNormalizedActiveEntryInfo,
    hasAcceptedLfgInvite = function()
      local lfgDetect = addonTable.LFGDetect
      return type(lfgDetect) == "table"
        and type(lfgDetect.GetAcceptedInviteSearchResultID) == "function"
        and lfgDetect.GetAcceptedInviteSearchResultID() ~= nil
    end,
    checkIfEnteredTargetDungeon = ctx.CheckIfEnteredTargetDungeon,
  }
end

--- RIO baseline capture and delta display around a key.
function Contracts.RioBaseline(ctx)
  return {
    captureRioBaselineSnapshot = ctx.CaptureRioBaselineSnapshot,
    restoreRioBaseline = ctx.RestoreRioBaseline,
    enableRioDeltaDisplay = ctx.EnableRioDeltaDisplay,
  }
end

--- Queue-debug and runtime-log storage and toggles.
function Contracts.DebugLogs(ctx)
  return {
    ensureQueueDebugStorage = ctx.queueDebugController.EnsureStorage,
    setQueueDebugEnabled = ctx.queueDebugController.SetEnabled,
    ensureRuntimeLogStorage = ctx.runtimeLogController.EnsureStorage,
    setRuntimeLogEnabled = ctx.runtimeLogController.SetEnabled,
    teleportDebugController = ctx.teleportDebugController,
    queueDebugController = ctx.queueDebugController,
  }
end

--- Hotkey bindings and their watchdog.
function Contracts.Bindings(ctx)
  return {
    applyHotkeyBindings = ctx.ApplyHotkeyBindings,
    startBindingWatchdog = ctx.StartBindingWatchdog,
    getPendingBindingApply = ctx.GetPendingBindingApply,
  }
end

--- Center notice frame, its secure teleport button and the countdown cancel.
function Contracts.CenterNotice(ctx)
  return {
    showCenterNotice = ctx.ShowCenterNotice,
    centerNotice = ctx.centerNotice,
    centerNoticeFrame = ctx.centerNoticeFrame,
    centerNoticeTeleportButton = ctx.centerNoticeTeleportButton,
    applySecureSpellToButton = ctx.ApplySecureSpellToButton,
    setCenterNoticeVisible = ctx.SetCenterNoticeVisible,
    updateCountdownCancelButton = ctx.UpdateCountdownCancelButton,
  }
end

--- Controllers the handlers drive directly. teleportUIController must stay
-- here: the season auto-switch rebuilds the M+ teleport grid through it.
function Contracts.Controllers(ctx)
  return {
    mainUI = ctx.mainUI,
    refreshController = ctx.refreshController,
    inspectController = ctx.inspectController,
    statusController = ctx.statusController,
    teleportUIController = ctx.teleportUIController,
    updateStatusLine = ctx.UpdateStatusLine,
  }
end

--- Test mode, demo preview and the simulation tablet.
function Contracts.TestMode(ctx)
  return {
    exitTestMode = ctx.ExitTestMode,
    exitTestModeForCombat = ctx.ExitTestModeForCombat,
    triggerGroupRosterUpdate = ctx.TriggerGroupRosterUpdate,
    toggleStandardTestMode = ctx.ToggleStandardTestMode,
    enterFullDummyPreview = ctx.EnterFullDummyPreview,
    toggleSimulationTablet = ctx.ToggleSimulationTablet,
  }
end

--- SavedVariables lifecycle: settings apply, demo restore and reset.
function Contracts.Persistence(ctx)
  return {
    addonName = ctx.addonName,
    getAddonVersionRaw = ctx.GetAddonVersionRaw,
    applyDBSettings = function()
      if type(ctx.ApplyDBSettings) == "function" then
        return ctx.ApplyDBSettings()
      end
    end,
    restorePersistedDemoSnapshot = function(db)
      local factoryDemo = FI.FactoryDemo
      if type(factoryDemo) == "table" and type(factoryDemo.RestorePersistedDemoSnapshot) == "function" then
        return factoryDemo.RestorePersistedDemoSnapshot(db)
      end
      return false
    end,
    resetDB = ctx.resetDB,
  }
end

FI.IsMainFrameShownFn = IsMainFrameShownFn
