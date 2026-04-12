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
  local uiCommon = addonTable.UICommon
  local defaultBgAlpha = uiCommon and uiCommon.DEFAULT_BG_ALPHA or 0.50

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
    getMainFrameLocked = function()
      local mainUI = ctx.mainUI
      if mainUI and type(mainUI.GetDragLocked) == "function" then
        return mainUI.GetDragLocked() == true
      end
      local db = rawget(_G, "IsiLiveDB")
      return not (type(db) == "table" and db.lockMainFramePosition == false)
    end,
    setMainFrameLocked = function(locked)
      local nextLocked = locked == true
      local db = rawget(_G, "IsiLiveDB")
      if not db then
        db = {}
        IsiLiveDB = db
      end
      db.lockMainFramePosition = nextLocked
      local mainUI = ctx.mainUI
      if mainUI and type(mainUI.SetDragLocked) == "function" then
        mainUI.SetDragLocked(nextLocked)
      end
    end,
    resetMainFramePosition = function()
      local db = rawget(_G, "IsiLiveDB")
      if not db then
        db = {}
        IsiLiveDB = db
      end
      db.uiScale = 1.0
      db.bgAlpha = defaultBgAlpha

      local mainFrame = ctx.mainFrame
      if mainFrame and type(mainFrame.SetScale) == "function" then
        mainFrame:SetScale(1.0)
      end

      local mainUI = ctx.mainUI
      if mainUI and type(mainUI.ResetPosition) == "function" then
        mainUI.ResetPosition()
      end

      if mainFrame and type(mainFrame.SetBackdropColor) == "function" then
        mainFrame:SetBackdropColor(0, 0, 0, defaultBgAlpha)
      end

      local colors = uiCommon and uiCommon.Colors
      if type(colors) == "table" and type(colors.BG_PRIMARY) == "table" then
        colors.BG_PRIMARY[4] = defaultBgAlpha
      end

      local bg = colors and colors.BG_PRIMARY or { 0.08, 0.08, 0.12, defaultBgAlpha }
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
      if ctx.settingsPanel and type(ctx.settingsPanel.Refresh) == "function" then
        ctx.settingsPanel.Refresh()
      end
    end,
    updateLeaderButtons = ctx.updateLeaderButtons,
    isPlayerLeader = ctx.isPlayerLeader,
    setLanguage = ctx.setLanguage,
    teleportDebugController = ctx.teleportDebugController,
    queueDebugController = ctx.queueDebugController,
    runtimeLogController = ctx.runtimeLogController,
    resetDB = ctx.resetDB,
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
