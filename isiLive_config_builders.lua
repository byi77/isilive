local _, addonTable = ...

addonTable = addonTable or {}

local ConfigBuilders = {}
addonTable.ConfigBuilders = ConfigBuilders

function ConfigBuilders.BuildRefreshControllerOpts(ctx)
  return {
    isStopped = ctx.isStopped,
    isPaused = ctx.isPaused,
    isTestMode = ctx.isTestMode,
    isTestAllMode = ctx.isTestAllMode,
    isInGroup = ctx.isInGroup,
    isRosterEmpty = ctx.isRosterEmpty,
    triggerGroupRosterUpdate = ctx.triggerGroupRosterUpdate,
    refreshTestModeRoster = ctx.refreshTestModeRoster,
    forceRefreshSyncState = ctx.forceRefreshSyncState,
    sendIsiLiveHello = ctx.sendIsiLiveHello,
    sendOwnKeySnapshot = ctx.sendOwnKeySnapshot,
    queueForceRefreshData = ctx.queueForceRefreshData,
    updateUI = ctx.updateUI,
    refreshLocalPlayerKey = ctx.refreshLocalPlayerKey,
    getActiveChallengeMapID = ctx.getActiveChallengeMapID,
    getTime = ctx.getTime,
    refreshDebounceSeconds = ctx.refreshDebounceSeconds,
  }
end

function ConfigBuilders.BuildQueueFlowControllerOpts(ctx)
  return {
    getL = ctx.getL,
    getPendingQueueJoinInfo = ctx.getPendingQueueJoinInfo,
    setPendingQueueJoinInfo = ctx.setPendingQueueJoinInfo,
    resolveMapIDByActivityID = ctx.resolveMapIDByActivityID,
    resolveTeleportSpellIDByMapID = ctx.resolveTeleportSpellIDByMapID,
    resolveJoinedKeyMapID = ctx.resolveJoinedKeyMapID,
    updateMPlusTeleportButton = ctx.updateMPlusTeleportButton,
    showInviteHint = ctx.showInviteHint,
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
  return {
    events = ctx.events,
    dispatch = ctx.onEvent,
    onDispatchError = ctx.onDispatchError,
    isStopped = ctx.isStopped,
    isPaused = ctx.isPaused,
    isTestMode = ctx.isTestMode,
    isInCombat = ctx.isInCombat,
    isInGroup = ctx.isInGroup,
    isInPartyInstance = ctx.isInPartyInstance,
    getNumGroupMembers = ctx.getNumGroupMembers,
    getActiveChallengeMapID = ctx.getActiveChallengeMapID,
    allowWhenHidden = {
      CHAT_MSG_ADDON = true,
      GROUP_ROSTER_UPDATE = true,
    },
  }
end
