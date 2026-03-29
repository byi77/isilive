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
    sendOwnBackgroundSnapshot = ctx.sendOwnBackgroundSnapshot,
    sendRefreshRequest = ctx.sendRefreshRequest,
    queueForceRefreshData = ctx.queueForceRefreshData,
    updateUI = ctx.updateUI,
    refreshLocalPlayerKey = ctx.refreshLocalPlayerKey,
    getActiveChallengeMapID = ctx.getActiveChallengeMapID,
    getTime = ctx.getTime,
    refreshDebounceSeconds = ctx.refreshDebounceSeconds,
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
    resetInspectAll = ctx.resetInspectAll,
    clearLatestQueueState = ctx.clearLatestQueueState,
    updateMPlusTeleportButton = ctx.updateMPlusTeleportButton,
    setCenterNoticeVisible = ctx.setCenterNoticeVisible,
    hideInviteHint = ctx.hideInviteHint,
    triggerGroupRosterUpdate = ctx.triggerGroupRosterUpdate,
    captureRioBaselineSnapshot = ctx.captureRioBaselineSnapshot,
    clearRioBaselineSnapshot = ctx.clearRioBaselineSnapshot,
    enableRioDeltaDisplay = ctx.enableRioDeltaDisplay,
    setDemoTimerData = ctx.setDemoTimerData,
    clearDemoTimerData = ctx.clearDemoTimerData,
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
    getActiveChallengeMapID = ctx.getActiveChallengeMapID,
    allowWhenHidden = {
      CHAT_MSG_ADDON = true,
      GROUP_ROSTER_UPDATE = true,
      ZONE_CHANGED = true,
      ZONE_CHANGED_INDOORS = true,
      ZONE_CHANGED_NEW_AREA = true,
      BAG_UPDATE_DELAYED = true,
      CHALLENGE_MODE_MAPS_UPDATE = true,
      PLAYER_EQUIPMENT_CHANGED = true,
      PLAYER_SPECIALIZATION_CHANGED = true,
    },
  }
end
