local _, addonTable = ...

addonTable = addonTable or {}

local ConfigBuilders = {}
addonTable.ConfigBuilders = ConfigBuilders

function ConfigBuilders.BuildRefreshControllerOpts(ctx)
  return {
    isStopped = ctx.isStopped,
    isPaused = ctx.isPaused,
    isInGroup = ctx.isInGroup,
    isRosterEmpty = ctx.isRosterEmpty,
    triggerGroupRosterUpdate = ctx.triggerGroupRosterUpdate,
    forceRefreshSyncState = ctx.forceRefreshSyncState,
    sendIsiLiveHello = ctx.sendIsiLiveHello,
    sendOwnKeySnapshot = ctx.sendOwnKeySnapshot,
    queueForceRefreshData = ctx.queueForceRefreshData,
    updateUI = ctx.updateUI,
    refreshLocalPlayerKey = ctx.refreshLocalPlayerKey,
    getActiveChallengeMapID = ctx.getActiveChallengeMapID,
  }
end

function ConfigBuilders.BuildQueueFlowControllerOpts(ctx)
  return {
    getL = ctx.getL,
    getPendingQueueJoinInfo = ctx.getPendingQueueJoinInfo,
    setPendingQueueJoinInfo = ctx.setPendingQueueJoinInfo,
    resolveSeason3MapIDByActivityID = ctx.resolveSeason3MapIDByActivityID,
    resolveSeason3TeleportSpellIDByMapID = ctx.resolveSeason3TeleportSpellIDByMapID,
    resolveJoinedKeyMapID = ctx.resolveJoinedKeyMapID,
    updateMPlusTeleportButton = ctx.updateMPlusTeleportButton,
    showInviteHint = ctx.showInviteHint,
    showCenterNotice = ctx.showCenterNotice,
    updateUI = ctx.updateUI,
    printFn = ctx.printFn,
    setQueueTargetState = ctx.setQueueTargetState,
    queueCaptureQueueJoinCandidate = ctx.queueCaptureQueueJoinCandidate,
    isInChallengeMode = ctx.isInChallengeMode,
    isInGroup = ctx.isInGroup,
    isPlayerLeader = ctx.isPlayerLeader,
    getTimeFn = ctx.getTimeFn,
  }
end

function ConfigBuilders.BuildTestModeControllerOpts(ctx)
  return {
    getL = ctx.getL,
    printFn = ctx.printFn,
    getState = ctx.getState,
    setState = ctx.setState,
    buildDummyRoster = ctx.buildDummyRoster,
    setRoster = ctx.setRoster,
    setMainFrameVisible = ctx.setMainFrameVisible,
    updateUI = ctx.updateUI,
    updateLeaderButtons = ctx.updateLeaderButtons,
    showCenterNotice = ctx.showCenterNotice,
    showQueueJoinPreview = ctx.showQueueJoinPreview,
    resetInspectAll = ctx.resetInspectAll,
    clearLatestQueueState = ctx.clearLatestQueueState,
    updateMPlusTeleportButton = ctx.updateMPlusTeleportButton,
    setCenterNoticeVisible = ctx.setCenterNoticeVisible,
    hideInviteHint = ctx.hideInviteHint,
    triggerGroupRosterUpdate = ctx.triggerGroupRosterUpdate,
    captureRioBaselineSnapshot = ctx.captureRioBaselineSnapshot,
    clearRioBaselineSnapshot = ctx.clearRioBaselineSnapshot,
    enableRioDeltaDisplay = ctx.enableRioDeltaDisplay,
  }
end

function ConfigBuilders.BuildGroupControllerDeps(ctx)
  return {
    printFn = ctx.printFn,
    getL = ctx.getL,
    modules = {
      sync = ctx.sync,
    },
    isInGroup = ctx.isInGroup,
    getNumGroupMembers = ctx.getNumGroupMembers,
    getActiveChallengeMapID = ctx.getActiveChallengeMapID,
    state = {
      getWasInGroup = ctx.getWasInGroup,
      setWasInGroup = ctx.setWasInGroup,
      getWasRaidGroup = ctx.getWasRaidGroup,
      setWasRaidGroup = ctx.setWasRaidGroup,
      setWasGroupLeader = ctx.setWasGroupLeader,
      getRoster = ctx.getRoster,
      setRoster = ctx.setRoster,
    },
    callbacks = {
      captureQueueJoinCandidate = ctx.captureQueueJoinCandidate,
      announceQueuedGroupJoin = ctx.announceQueuedGroupJoin,
      setMainFrameVisible = ctx.setMainFrameVisible,
      updateLeaderButtons = ctx.updateLeaderButtons,
      clearLatestQueueTarget = ctx.clearLatestQueueTarget,
      clearRioBaselineSnapshot = ctx.clearRioBaselineSnapshot,
      resetInspectAll = ctx.resetInspectAll,
      resetInspectQueues = ctx.resetInspectQueues,
      updateUI = ctx.updateUI,
      updateMPlusTeleportButton = ctx.updateMPlusTeleportButton,
    },
    getUnitNameAndRealm = ctx.getUnitNameAndRealm,
    getUnitClass = ctx.getUnitClass,
    getUnitServerLanguage = ctx.getUnitServerLanguage,
    getOwnedKeystoneSnapshot = ctx.getOwnedKeystoneSnapshot,
    markIsiLiveUser = ctx.markIsiLiveUser,
    getUnitRole = ctx.getUnitRole,
    getPlayerSpecName = ctx.getPlayerSpecName,
    getUnitRio = ctx.getUnitRio,
    unitHasIsiLive = ctx.unitHasIsiLive,
    applyKnownKeyToRosterEntry = ctx.applyKnownKeyToRosterEntry,
    enqueueInspect = ctx.enqueueInspect,
    sendOwnKeySnapshot = ctx.sendOwnKeySnapshot,
    sendIsiLiveHello = ctx.sendIsiLiveHello,
  }
end

function ConfigBuilders.BuildLeaderWatchControllerOpts(ctx)
  return {
    isPlayerLeader = ctx.isPlayerLeader,
    getWasGroupLeader = ctx.getWasGroupLeader,
    setWasGroupLeader = ctx.setWasGroupLeader,
    isStopped = ctx.isStopped,
    isMainFrameShown = ctx.isMainFrameShown,
    showCenterNotice = ctx.showCenterNotice,
    printFn = ctx.printFn,
    getL = ctx.getL,
    updateLeaderButtons = ctx.updateLeaderButtons,
  }
end

local function BuildEventState(ctx)
  return {
    isTestMode = ctx.isTestMode,
    isTestAllMode = ctx.isTestAllMode,
    getPendingQueueJoinInfo = ctx.getPendingQueueJoinInfo,
    setPendingQueueJoinInfo = ctx.setPendingQueueJoinInfo,
    getActiveJoinedKeyMapID = ctx.getActiveJoinedKeyMapID,
    setActiveJoinedKeyMapID = ctx.setActiveJoinedKeyMapID,
    getPendingBindingApply = ctx.getPendingBindingApply,
    getRoster = ctx.getRoster,
  }
end

local function BuildEventRefs(ctx)
  return {
    mainFrame = ctx.mainFrame,
    mainUI = ctx.mainUI,
    centerNotice = ctx.centerNotice,
    centerNoticeFrame = ctx.centerNoticeFrame,
    centerNoticeTeleportButton = ctx.centerNoticeTeleportButton,
    applySecureSpellToButton = ctx.applySecureSpellToButton,
  }
end

local function BuildEventControllers(ctx)
  return {
    group = ctx.groupController,
    refresh = ctx.refreshController,
    inspect = ctx.inspectController,
    status = ctx.statusController,
  }
end

local function BuildEventCallbacks(ctx)
  return {
    exitTestMode = ctx.exitTestMode,
    clearLatestQueueTarget = ctx.clearLatestQueueTarget,
    updateMPlusTeleportButton = ctx.updateMPlusTeleportButton,
    captureQueueJoinCandidate = ctx.captureQueueJoinCandidate,
    updateUI = ctx.updateUI,
    setMainFrameVisible = ctx.setMainFrameVisible,
    updateLeaderButtons = ctx.updateLeaderButtons,
    updateStatusLine = ctx.updateStatusLine,
    applyLocalizationToUI = ctx.applyLocalizationToUI,
    updateCountdownCancelButton = ctx.updateCountdownCancelButton,
    checkIfEnteredTargetDungeon = ctx.checkIfEnteredTargetDungeon,
    captureRioBaselineSnapshot = ctx.captureRioBaselineSnapshot,
    enableRioDeltaDisplay = ctx.enableRioDeltaDisplay,
    setMainFrameHeightSafe = ctx.setMainFrameHeightSafe,
    setCenterNoticeVisible = ctx.setCenterNoticeVisible,
  }
end

function ConfigBuilders.BuildEventHandlersControllerDeps(ctx)
  return {
    addonName = ctx.addonName,
    defaultLocale = ctx.defaultLocale,
    locales = ctx.locales,
    resolveLocaleTag = ctx.resolveLocaleTag,
    setLocaleTable = ctx.setLocaleTable,
    isInGroup = ctx.isInGroup,
    isInChallengeMode = ctx.isInChallengeMode,
    isNegativeApplicationStatusEvent = ctx.isNegativeApplicationStatusEvent,
    getNormalizedActiveEntryInfo = ctx.getNormalizedActiveEntryInfo,
    sendOwnKeySnapshot = ctx.sendOwnKeySnapshot,
    ensureQueueDebugStorage = ctx.ensureQueueDebugStorage,
    setQueueDebugEnabled = ctx.setQueueDebugEnabled,
    ensureRuntimeLogStorage = ctx.ensureRuntimeLogStorage,
    setRuntimeLogEnabled = ctx.setRuntimeLogEnabled,
    registerIsiLiveSyncPrefix = ctx.registerIsiLiveSyncPrefix,
    applyHotkeyBindings = ctx.applyHotkeyBindings,
    startBindingWatchdog = ctx.startBindingWatchdog,
    getUnitNameAndRealm = ctx.getUnitNameAndRealm,
    markIsiLiveUser = ctx.markIsiLiveUser,
    sendIsiLiveHello = ctx.sendIsiLiveHello,
    getUnitRio = ctx.getUnitRio,
    getInspectSpecName = ctx.getInspectSpecName,
    getPlayerSpecName = ctx.getPlayerSpecName,
    getAddonVersionRaw = ctx.getAddonVersionRaw,
    getTime = ctx.getTime,
    applyKnownKeyToRosterEntry = ctx.applyKnownKeyToRosterEntry,
    runFullRefresh = function()
      if ctx.refreshController then
        return ctx.refreshController.RunFullRefresh()
      end
      return false
    end,
    modules = {
      sync = ctx.sync,
    },
    state = BuildEventState(ctx),
    refs = BuildEventRefs(ctx),
    controllers = BuildEventControllers(ctx),
    callbacks = BuildEventCallbacks(ctx),
  }
end

function ConfigBuilders.BuildSlashCommandsOpts(ctx)
  return {
    commands = ctx.commands,
    printFn = ctx.printFn,
    getL = ctx.getL,
    getState = ctx.getState,
    setState = ctx.setState,
    triggerGroupRosterUpdate = ctx.triggerGroupRosterUpdate,
    toggleStandardTestMode = ctx.toggleStandardTestMode,
    enterFullDummyPreview = ctx.enterFullDummyPreview,
    setMainFrameVisible = ctx.setMainFrameVisible,
    updateLeaderButtons = ctx.updateLeaderButtons,
    isPlayerLeader = ctx.isPlayerLeader,
    setLanguage = ctx.setLanguage,
    teleportDebugController = ctx.teleportDebugController,
    queueDebugController = ctx.queueDebugController,
    runtimeLogController = ctx.runtimeLogController,
  }
end

function ConfigBuilders.BuildGateOpts(ctx)
  local dispatch = ctx.dispatch or ctx.onEvent
  return {
    events = ctx.events,
    dispatch = dispatch,
    isStopped = ctx.isStopped,
    isPaused = ctx.isPaused,
    isTestMode = ctx.isTestMode,
    isInGroup = ctx.isInGroup,
    getNumGroupMembers = ctx.getNumGroupMembers,
    getActiveChallengeMapID = ctx.getActiveChallengeMapID,
  }
end
