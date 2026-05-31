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
    -- Forward the runtime-log handles so refresh.lua's `[REFRESH] ...`
    -- traces actually fire in production. Earlier revisions silently
    -- dropped these even though factory_controllers wired them into the
    -- input ctx, leaving every refresh trace dead behind the
    -- `if logRuntimeTracef then` guards.
    logRuntimeTrace = ctx.logRuntimeTrace,
    logRuntimeTracef = ctx.logRuntimeTracef,
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
    setDemoFeatureData = ctx.setDemoFeatureData,
    clearDemoFeatureData = ctx.clearDemoFeatureData,
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
    logRuntimeTrace = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil,
    logRuntimeTracef = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil,
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
      -- IsiLiveDB is restored before ADDON_LOADED. Both /il lock and the
      -- lock-button OnClick that target this callback run from post-load
      -- contexts, so a missing DB here means we're in a (theoretical) pre-
      -- load callsite where lazy-allocating would race the SavedVariables
      -- restore. Mirror the in-memory lock state but skip persistence.
      local db = rawget(_G, "IsiLiveDB")
      if type(db) == "table" then
        db.lockMainFramePosition = nextLocked
      end
      local mainUI = ctx.mainUI
      if mainUI and type(mainUI.SetDragLocked) == "function" then
        mainUI.SetDragLocked(nextLocked)
      end
    end,
    resetMainFramePosition = function()
      -- See setMainFrameLocked above for the no-op-on-nil rationale.
      local db = rawget(_G, "IsiLiveDB")
      if type(db) ~= "table" then
        return
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
    traceChatFrameController = ctx.traceChatFrameController,
    runtimeLogController = ctx.runtimeLogController,
    getRuntimeLogEnabled = ctx.getRuntimeLogEnabled,
    setRuntimeLogEnabled = ctx.setRuntimeLogEnabled,
    getRuntimeLogLevel = ctx.getRuntimeLogLevel,
    setRuntimeLogLevel = ctx.setRuntimeLogLevel,
    clearRuntimeLog = ctx.clearRuntimeLog,
    getRuntimeLogCount = ctx.getRuntimeLogCount,
    getRuntimeLogTail = ctx.getRuntimeLogTail,
    getRuntimeLogTailFiltered = ctx.getRuntimeLogTailFiltered,
    setRuntimeLogWatch = ctx.setRuntimeLogWatch,
    getRuntimeLogWatchActive = ctx.getRuntimeLogWatchActive,
    -- Always-on Lua-error capture, exposed to /isilive errorlog.
    getErrorLogTail = function(limit)
      local errorLog = addonTable.ErrorLog
      if type(errorLog) == "table" and type(errorLog.GetTail) == "function" then
        return errorLog.GetTail(limit)
      end
      return {}
    end,
    getErrorLogCount = function()
      local errorLog = addonTable.ErrorLog
      if type(errorLog) == "table" and type(errorLog.GetCount) == "function" then
        return errorLog.GetCount()
      end
      return 0
    end,
    getErrorLogMaxEntries = function()
      local errorLog = addonTable.ErrorLog
      if type(errorLog) == "table" and type(errorLog.GetMaxEntries) == "function" then
        return errorLog.GetMaxEntries()
      end
      return 0
    end,
    getErrorLogInstalled = function()
      local errorLog = addonTable.ErrorLog
      if type(errorLog) == "table" and type(errorLog.IsInstalled) == "function" then
        return errorLog.IsInstalled()
      end
      return false
    end,
    clearErrorLog = function()
      local errorLog = addonTable.ErrorLog
      if type(errorLog) == "table" and type(errorLog.Clear) == "function" then
        errorLog.Clear()
      end
    end,
    openSettings = function()
      local blizzardSettings = rawget(_G, "Settings")
      if type(blizzardSettings) ~= "table" or type(blizzardSettings.OpenToCategory) ~= "function" then
        return false
      end
      if ctx.settingsPanel and ctx.settingsPanel.category then
        blizzardSettings.OpenToCategory(ctx.settingsPanel.category.ID)
        return true
      end
      return false
    end,
    resetDB = ctx.resetDB,
    toggleNameplateTestMode = function(arg)
      local mobNameplate = addonTable.MobNameplate
      if type(mobNameplate) ~= "table" or type(mobNameplate.SetTestMode) ~= "function" then
        return false
      end
      local percent = nil
      if type(arg) == "string" and arg ~= "" then
        local n = tonumber(arg)
        if n and n >= 0 then
          percent = string.format("%.2f", n)
        else
          percent = arg
        end
      end
      return mobNameplate.SetTestMode(nil, percent)
    end,
    dumpNameplateState = function(unit)
      local mobNameplate = addonTable.MobNameplate
      if type(mobNameplate) ~= "table" or type(mobNameplate.DumpState) ~= "function" then
        ctx.printFn("[NP] MobNameplate module unavailable.")
        return
      end
      local state = mobNameplate.DumpState(unit)
      if type(state) ~= "table" then
        ctx.printFn("[NP] No state returned.")
        return
      end
      local function fmt(v)
        if v == nil then
          return "nil"
        end
        local t = type(v)
        if t == "table" then
          return "table"
        end
        return tostring(v)
      end
      ctx.printFn(
        string.format(
          "[NP] unit=%s enabled=%s testMode=%s appearanceFontSize=%s",
          fmt(state.unit),
          fmt(state.enabled),
          fmt(state.testMode),
          fmt(state.appearanceFontSize)
        )
      )
      ctx.printFn(
        string.format(
          "[NP] hasNamePlateAPI=%s hasProgressAPI=%s challengeActive=%s activeMapID=%s eligible=%s",
          fmt(state.hasNamePlateAPI),
          fmt(state.hasProgressAPI),
          fmt(state.challengeActive),
          fmt(state.activeMapID),
          fmt(state.eligible)
        )
      )
      ctx.printFn(
        string.format(
          "[NP] unitName=%s unitNameSecret=%s guid=%s guidIsSecret=%s npcId=%s",
          fmt(state.unitName),
          fmt(state.unitNameSecret),
          fmt(state.guid),
          fmt(state.guidIsSecret),
          fmt(state.npcId)
        )
      )
      ctx.printFn(
        string.format(
          "[NP] dbHasByNpcId=%s dbEntry=%s dbEntryMatchesMap=%s",
          fmt(state.dbHasByNpcId),
          fmt(state.dbEntry),
          fmt(state.dbEntryMatchesMap)
        )
      )
      ctx.printFn(
        string.format(
          "[NP] dbDungeonTotal=%s dbPercent=%s apiPercent=%s apiPercentSecret=%s resolvedPercent=%s resolvedText=%s",
          fmt(state.dbDungeonTotal),
          fmt(state.dbPercent),
          fmt(state.apiPercent),
          fmt(state.apiPercentSecret),
          fmt(state.resolvedPercent),
          fmt(state.resolvedText)
        )
      )
      ctx.printFn(
        string.format(
          "[NP] frameExists=%s frameShown=%s fontFile=%s fontHeight=%s fontFlags=%s fontStringText=%s",
          fmt(state.frameExists),
          fmt(state.frameShown),
          fmt(state.fontFile),
          fmt(state.fontHeight),
          fmt(state.fontFlags),
          fmt(state.fontStringText)
        )
      )

      -- Dump every actively-rendered nameplate frame so the user can see what
      -- font height the FontStrings actually have, regardless of whether
      -- "target" was a unit token we stored in `frames`.
      if type(mobNameplate.DumpFrames) == "function" then
        local framesDump = mobNameplate.DumpFrames()
        if type(framesDump) == "table" then
          ctx.printFn(
            string.format(
              "[NP-FRAMES] count=%s appearanceFontSize=%s",
              fmt(framesDump.frameCount),
              fmt(framesDump.appearanceFontSize)
            )
          )
          if type(framesDump.frames) == "table" then
            for _, row in ipairs(framesDump.frames) do
              ctx.printFn(
                string.format(
                  "[NP-FRAMES] unit=%s shown=%s w=%s h=%s fontHeight=%s text=%s",
                  fmt(row.unit),
                  fmt(row.frameShown),
                  fmt(row.frameWidth),
                  fmt(row.frameHeight),
                  fmt(row.fontHeight),
                  fmt(row.fontStringText)
                )
              )
            end
          end
        end
      end
    end,
    logRuntimeTrace = ctx.logRuntimeTrace,
    logRuntimeTracef = ctx.logRuntimeTracef,
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
    -- The gate is bound to the dispatcher frame (always shown) and to the
    -- mainFrame (the actual UI window). For the dispatcher case `frame:IsShown()`
    -- would always return true; pass an explicit mainFrame visibility callback so
    -- the hidden-suppression branch behaves consistently across both bindings.
    isShown = ctx.isMainFrameShown,
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
      PLAYER_ROLES_ASSIGNED = true,
      ROLE_CHANGED_INFORM = true,
      SPELL_UPDATE_CHARGES = true,
      UNIT_AURA = true,
    },
  }
end
