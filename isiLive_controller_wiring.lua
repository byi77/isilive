local _, addonTable = ...

addonTable = addonTable or {}

local ControllerWiring = {}
addonTable.ControllerWiring = ControllerWiring

local function RequireFunction(value, name)
  assert(type(value) == "function", "isiLive: ControllerWiring requires " .. name)
  return value
end

local function RequireTable(value, name)
  assert(type(value) == "table", "isiLive: ControllerWiring requires table " .. name)
  return value
end

function ControllerWiring.CreateGroupController(groupModule, deps)
  assert(groupModule, "isiLive: ControllerWiring.CreateGroupController requires groupModule")
  deps = deps or {}

  local state = RequireTable(deps.state, "state")
  local callbacks = RequireTable(deps.callbacks, "callbacks")
  local modules = RequireTable(deps.modules, "modules")

  return groupModule.CreateController({
    printFn = RequireFunction(deps.printFn, "printFn"),
    getL = RequireFunction(deps.getL, "getL"),
    isRosterCollapsed = deps.isRosterCollapsed,
    isInGroup = RequireFunction(deps.isInGroup, "isInGroup"),
    getNumGroupMembers = RequireFunction(deps.getNumGroupMembers, "getNumGroupMembers"),
    getActiveChallengeMapID = RequireFunction(deps.getActiveChallengeMapID, "getActiveChallengeMapID"),
    getWasInGroup = RequireFunction(state.getWasInGroup, "state.getWasInGroup"),
    setWasInGroup = RequireFunction(state.setWasInGroup, "state.setWasInGroup"),
    getWasRaidGroup = RequireFunction(state.getWasRaidGroup, "state.getWasRaidGroup"),
    setWasRaidGroup = RequireFunction(state.setWasRaidGroup, "state.setWasRaidGroup"),
    setWasGroupLeader = RequireFunction(state.setWasGroupLeader, "state.setWasGroupLeader"),
    getRoster = RequireFunction(state.getRoster, "state.getRoster"),
    setRoster = RequireFunction(state.setRoster, "state.setRoster"),
    captureQueueJoinCandidate = RequireFunction(
      callbacks.captureQueueJoinCandidate,
      "callbacks.captureQueueJoinCandidate"
    ),
    announceQueuedGroupJoin = RequireFunction(callbacks.announceQueuedGroupJoin, "callbacks.announceQueuedGroupJoin"),
    setMainFrameVisible = RequireFunction(callbacks.setMainFrameVisible, "callbacks.setMainFrameVisible"),
    switchToRaidMode = callbacks.switchToRaidMode or function() end,
    updateLeaderButtons = RequireFunction(callbacks.updateLeaderButtons, "callbacks.updateLeaderButtons"),
    clearLatestQueueTarget = RequireFunction(callbacks.clearLatestQueueTarget, "callbacks.clearLatestQueueTarget"),
    clearRioBaselineSnapshot = type(callbacks.clearRioBaselineSnapshot) == "function"
        and callbacks.clearRioBaselineSnapshot
      or function() end,
    clearKnownUsers = function()
      local sync = modules.sync
      if sync and sync.ClearKnownUsers then
        sync.ClearKnownUsers()
      end
    end,
    resetInspectAll = RequireFunction(callbacks.resetInspectAll, "callbacks.resetInspectAll"),
    resetInspectQueues = RequireFunction(callbacks.resetInspectQueues, "callbacks.resetInspectQueues"),
    updateUI = RequireFunction(callbacks.updateUI, "callbacks.updateUI"),
    updateMPlusTeleportButton = RequireFunction(
      callbacks.updateMPlusTeleportButton,
      "callbacks.updateMPlusTeleportButton"
    ),
    getUnitNameAndRealm = RequireFunction(deps.getUnitNameAndRealm, "getUnitNameAndRealm"),
    getUnitClass = RequireFunction(deps.getUnitClass, "getUnitClass"),
    getUnitServerLanguage = RequireFunction(deps.getUnitServerLanguage, "getUnitServerLanguage"),
    getOwnedKeystoneSnapshot = RequireFunction(deps.getOwnedKeystoneSnapshot, "getOwnedKeystoneSnapshot"),
    markIsiLiveUser = RequireFunction(deps.markIsiLiveUser, "markIsiLiveUser"),
    setPlayerKeyInfo = function(name, realm, mapID, level)
      modules.sync.SetPlayerKeyInfo(name, realm, mapID, level)
    end,
    getUnitRole = RequireFunction(deps.getUnitRole, "getUnitRole"),
    getPlayerSpecName = RequireFunction(deps.getPlayerSpecName, "getPlayerSpecName"),
    getUnitRio = RequireFunction(deps.getUnitRio, "getUnitRio"),
    unitHasIsiLive = RequireFunction(deps.unitHasIsiLive, "unitHasIsiLive"),
    applyKnownKeyToRosterEntry = RequireFunction(deps.applyKnownKeyToRosterEntry, "applyKnownKeyToRosterEntry"),
    enqueueInspect = RequireFunction(deps.enqueueInspect, "enqueueInspect"),
    sendOwnKeySnapshot = RequireFunction(deps.sendOwnKeySnapshot, "sendOwnKeySnapshot"),
    sendIsiLiveHello = RequireFunction(deps.sendIsiLiveHello, "sendIsiLiveHello"),
    autoHideSolo = deps.autoHideSolo or function() end,
  })
end

local function BuildGroupControllerDepsFromContext(ctx)
  return {
    printFn = ctx.printFn,
    getL = ctx.getL,
    isRosterCollapsed = ctx.isRosterCollapsed,
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
      switchToRaidMode = ctx.switchToRaidMode,
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
    autoHideSolo = ctx.autoHideSolo,
  }
end

function ControllerWiring.CreateGroupControllerFromContext(groupModule, ctx)
  return ControllerWiring.CreateGroupController(groupModule, BuildGroupControllerDepsFromContext(ctx))
end

local function BuildEventHandlersBaseConfig(deps, state, refs, controllers, callbacks)
  return {
    addonName = assert(deps.addonName, "isiLive: ControllerWiring requires addonName"),
    isRosterCollapsed = deps.isRosterCollapsed,
    defaultLocale = assert(deps.defaultLocale, "isiLive: ControllerWiring requires defaultLocale"),
    locales = assert(deps.locales, "isiLive: ControllerWiring requires locales"),
    resolveLocaleTag = RequireFunction(deps.resolveLocaleTag, "resolveLocaleTag"),
    setLocaleTable = RequireFunction(deps.setLocaleTable, "setLocaleTable"),
    isInGroup = RequireFunction(deps.isInGroup, "isInGroup"),
    isTestMode = RequireFunction(state.isTestMode, "state.isTestMode"),
    isTestAllMode = RequireFunction(state.isTestAllMode, "state.isTestAllMode"),
    exitTestMode = RequireFunction(callbacks.exitTestMode, "callbacks.exitTestMode"),
    handleGroupRosterUpdate = function()
      controllers.group.HandleGroupRosterUpdate()
    end,
    isInChallengeMode = RequireFunction(deps.isInChallengeMode, "isInChallengeMode"),
    isNegativeApplicationStatusEvent = RequireFunction(
      deps.isNegativeApplicationStatusEvent,
      "isNegativeApplicationStatusEvent"
    ),
    getNormalizedActiveEntryInfo = RequireFunction(deps.getNormalizedActiveEntryInfo, "getNormalizedActiveEntryInfo"),
    getPendingQueueJoinInfo = type(state.getPendingQueueJoinInfo) == "function" and state.getPendingQueueJoinInfo
      or function()
        return nil
      end,
    setPendingQueueJoinInfo = RequireFunction(state.setPendingQueueJoinInfo, "state.setPendingQueueJoinInfo"),
    clearLatestQueueTarget = RequireFunction(callbacks.clearLatestQueueTarget, "callbacks.clearLatestQueueTarget"),
    updateMPlusTeleportButton = RequireFunction(
      callbacks.updateMPlusTeleportButton,
      "callbacks.updateMPlusTeleportButton"
    ),
    captureQueueJoinCandidate = RequireFunction(
      callbacks.captureQueueJoinCandidate,
      "callbacks.captureQueueJoinCandidate"
    ),
    getActiveJoinedKeyMapID = RequireFunction(state.getActiveJoinedKeyMapID, "state.getActiveJoinedKeyMapID"),
    setActiveJoinedKeyMapID = RequireFunction(state.setActiveJoinedKeyMapID, "state.setActiveJoinedKeyMapID"),
    updateUI = RequireFunction(callbacks.updateUI, "callbacks.updateUI"),
    setMainFrameVisible = RequireFunction(callbacks.setMainFrameVisible, "callbacks.setMainFrameVisible"),
    updateLeaderButtons = RequireFunction(callbacks.updateLeaderButtons, "callbacks.updateLeaderButtons"),
    updateStatusLine = RequireFunction(callbacks.updateStatusLine, "callbacks.updateStatusLine"),
    sendOwnKeySnapshot = RequireFunction(deps.sendOwnKeySnapshot, "sendOwnKeySnapshot"),
    ensureQueueDebugStorage = RequireFunction(deps.ensureQueueDebugStorage, "ensureQueueDebugStorage"),
    setQueueDebugEnabled = RequireFunction(deps.setQueueDebugEnabled, "setQueueDebugEnabled"),
    ensureRuntimeLogStorage = type(deps.ensureRuntimeLogStorage) == "function" and deps.ensureRuntimeLogStorage
      or function() end,
    setRuntimeLogEnabled = type(deps.setRuntimeLogEnabled) == "function" and deps.setRuntimeLogEnabled
      or function(_enabled) end,
    getMainFrame = function()
      return refs.mainFrame
    end,
    registerIsiLiveSyncPrefix = RequireFunction(deps.registerIsiLiveSyncPrefix, "registerIsiLiveSyncPrefix"),
    applyHotkeyBindings = RequireFunction(deps.applyHotkeyBindings, "applyHotkeyBindings"),
    startBindingWatchdog = RequireFunction(deps.startBindingWatchdog, "startBindingWatchdog"),
    restoreLayoutState = RequireFunction(callbacks.restoreLayoutState, "callbacks.restoreLayoutState"),
    applyLocalizationToUI = RequireFunction(callbacks.applyLocalizationToUI, "callbacks.applyLocalizationToUI"),
    updateCountdownCancelButton = RequireFunction(
      callbacks.updateCountdownCancelButton,
      "callbacks.updateCountdownCancelButton"
    ),
  }
end

local function ExtendEventHandlersConfig(config, deps, state, refs, controllers, callbacks, modules)
  config.getUnitNameAndRealm = RequireFunction(deps.getUnitNameAndRealm, "getUnitNameAndRealm")
  config.markIsiLiveUser = RequireFunction(deps.markIsiLiveUser, "markIsiLiveUser")
  config.maybeShowNonMythicDungeonEntryNotice = function()
    local seasonData = addonTable.SeasonData
    if type(seasonData) == "table" and type(seasonData.HasActiveDungeons) == "function" then
      if not seasonData.HasActiveDungeons() then
        return
      end
    end
    controllers.status.MaybeShowNonMythicDungeonEntryNotice()
  end
  config.maybeShowPortalNavigatorNotice = function()
    controllers.status.MaybeShowPortalNavigatorNotice()
  end
  config.checkIfEnteredTargetDungeon =
    RequireFunction(callbacks.checkIfEnteredTargetDungeon, "callbacks.checkIfEnteredTargetDungeon")
  config.timerAfter = function(seconds, callback)
    if C_Timer and C_Timer.After then
      C_Timer.After(seconds, function()
        local ok, err = xpcall(callback, function(e)
          local debugLib = rawget(_G, "debug")
          if type(debugLib) == "table" and type(debugLib.traceback) == "function" then
            return debugLib.traceback(tostring(e), 2)
          end
          return tostring(e)
        end)
        if not ok then
          -- Fehler an WoWs globalem Error-Handler melden (roter Fehlerrahmen),
          -- damit Timer-Callback-Crashes nicht lautlos verschwinden.
          local getEH = rawget(_G, "geterrorhandler")
          if type(getEH) == "function" then
            local h = getEH()
            if type(h) == "function" then
              pcall(h, err)
            end
          end
        end
      end)
    end
  end
  config.getPendingBindingApply = RequireFunction(state.getPendingBindingApply, "state.getPendingBindingApply")
  config.getPendingMainFrameHeight = function()
    return refs.mainUI.GetPendingHeight()
  end
  config.getPendingMainFrameVisible = function()
    return refs.mainUI.GetPendingVisible()
  end
  config.setMainFrameHeightSafe = RequireFunction(callbacks.setMainFrameHeightSafe, "callbacks.setMainFrameHeightSafe")
  config.tryRestoreCenterNoticeTeleportButton = function()
    local centerNoticeFrame = refs.centerNoticeFrame
    local centerNoticeTeleportButton = refs.centerNoticeTeleportButton
    if
      centerNoticeFrame
      and centerNoticeFrame:IsShown()
      and centerNoticeTeleportButton
      and centerNoticeTeleportButton.spellID
    then
      refs.applySecureSpellToButton(centerNoticeTeleportButton, centerNoticeTeleportButton.spellID)
      centerNoticeTeleportButton:Enable()
    end
  end
  config.handleOwnedKeyRefresh = function()
    controllers.refresh.HandleOwnedKeyRefresh()
  end
  config.isMainFrameShown = function()
    return refs.mainFrame:IsShown()
  end
  config.onInspectReady = function(guid)
    return controllers.inspect.OnInspectReady(
      guid,
      state.getRoster(),
      deps.getUnitRio,
      deps.getInspectSpecName,
      deps.getPlayerSpecName
    )
  end
  config.processAddonMessage = function(prefix, message, sender)
    local localName, localRealm = deps.getUnitNameAndRealm("player")
    return modules.sync.ProcessAddonMessage(prefix, message, sender, localName, localRealm)
  end
  config.sendAck = function(sender)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage and type(sender) == "string" and sender ~= "" then
      C_ChatInfo.SendAddonMessage(modules.sync.GetPrefix(), "ACK:" .. deps.getAddonVersionRaw(), "WHISPER", sender)
    end
  end
  config.sendRefreshResponse = RequireFunction(deps.sendRefreshResponse, "sendRefreshResponse")
  config.forEachRosterInfo = function(visitor)
    for _, info in pairs(state.getRoster()) do
      visitor(info)
    end
  end
  config.isSyncUserKnown = function(name, realm)
    return modules.sync.IsUserKnown(name, realm)
  end
  config.applyKnownKeyToRosterEntry = RequireFunction(deps.applyKnownKeyToRosterEntry, "applyKnownKeyToRosterEntry")
  config.runFullRefresh = RequireFunction(deps.runFullRefresh, "runFullRefresh")
  config.recordRun = type(deps.recordRun) == "function" and deps.recordRun or function() end
  config.getRoster = RequireFunction(state.getRoster, "state.getRoster")
  config.captureRioBaselineSnapshot = callbacks.captureRioBaselineSnapshot
  config.restoreRioBaseline = callbacks.restoreRioBaseline
  config.enableRioDeltaDisplay = callbacks.enableRioDeltaDisplay
  config.updateCdTracker = type(callbacks.updateCdTracker) == "function" and callbacks.updateCdTracker or function() end
  config.isReadyCheckActive = type(callbacks.isReadyCheckActive) == "function" and callbacks.isReadyCheckActive
    or function()
      return false
    end
  config.setReadyCheckActive = type(callbacks.setReadyCheckActive) == "function" and callbacks.setReadyCheckActive
    or function(_value) end
  if type(deps.getTime) == "function" then
    config.getTime = deps.getTime
  end
end

function ControllerWiring.CreateEventHandlersController(eventHandlersModule, deps)
  assert(eventHandlersModule, "isiLive: ControllerWiring.CreateEventHandlersController requires eventHandlersModule")
  deps = deps or {}

  local state = RequireTable(deps.state, "state")
  local refs = RequireTable(deps.refs, "refs")
  local controllers = RequireTable(deps.controllers, "controllers")
  local callbacks = RequireTable(deps.callbacks, "callbacks")
  local modules = RequireTable(deps.modules, "modules")

  local config = BuildEventHandlersBaseConfig(deps, state, refs, controllers, callbacks)
  ExtendEventHandlersConfig(config, deps, state, refs, controllers, callbacks, modules)
  return eventHandlersModule.CreateController(config)
end

local function BuildEventHandlersDepsFromContext(ctx)
  return {
    addonName = ctx.addonName,
    isRosterCollapsed = ctx.isRosterCollapsed,
    defaultLocale = ctx.defaultLocale,
    locales = ctx.locales,
    resolveLocaleTag = ctx.resolveLocaleTag,
    setLocaleTable = ctx.setLocaleTable,
    isInGroup = ctx.isInGroup,
    isInChallengeMode = ctx.isInChallengeMode,
    isNegativeApplicationStatusEvent = ctx.isNegativeApplicationStatusEvent,
    getNormalizedActiveEntryInfo = ctx.getNormalizedActiveEntryInfo,
    sendOwnKeySnapshot = ctx.sendOwnKeySnapshot,
    sendRefreshResponse = ctx.sendRefreshResponse,
    ensureQueueDebugStorage = ctx.ensureQueueDebugStorage,
    setQueueDebugEnabled = ctx.setQueueDebugEnabled,
    ensureRuntimeLogStorage = ctx.ensureRuntimeLogStorage,
    setRuntimeLogEnabled = ctx.setRuntimeLogEnabled,
    registerIsiLiveSyncPrefix = ctx.registerIsiLiveSyncPrefix,
    applyHotkeyBindings = ctx.applyHotkeyBindings,
    startBindingWatchdog = ctx.startBindingWatchdog,
    getUnitNameAndRealm = ctx.getUnitNameAndRealm,
    markIsiLiveUser = ctx.markIsiLiveUser,
    getUnitRio = ctx.getUnitRio,
    getInspectSpecName = ctx.getInspectSpecName,
    getPlayerSpecName = ctx.getPlayerSpecName,
    getAddonVersionRaw = ctx.getAddonVersionRaw,
    getTime = ctx.getTime,
    recordRun = ctx.recordRun,
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
    state = {
      isTestMode = ctx.isTestMode,
      isTestAllMode = ctx.isTestAllMode,
      getPendingQueueJoinInfo = ctx.getPendingQueueJoinInfo,
      setPendingQueueJoinInfo = ctx.setPendingQueueJoinInfo,
      getActiveJoinedKeyMapID = ctx.getActiveJoinedKeyMapID,
      setActiveJoinedKeyMapID = ctx.setActiveJoinedKeyMapID,
      getPendingBindingApply = ctx.getPendingBindingApply,
      getRoster = ctx.getRoster,
    },
    refs = {
      mainFrame = ctx.mainFrame,
      mainUI = ctx.mainUI,
      centerNotice = ctx.centerNotice,
      centerNoticeFrame = ctx.centerNoticeFrame,
      centerNoticeTeleportButton = ctx.centerNoticeTeleportButton,
      applySecureSpellToButton = ctx.applySecureSpellToButton,
    },
    controllers = {
      group = ctx.groupController,
      refresh = ctx.refreshController,
      inspect = ctx.inspectController,
      status = ctx.statusController,
    },
    callbacks = {
      exitTestMode = ctx.exitTestMode,
      clearLatestQueueTarget = ctx.clearLatestQueueTarget,
      updateMPlusTeleportButton = ctx.updateMPlusTeleportButton,
      captureQueueJoinCandidate = ctx.captureQueueJoinCandidate,
      updateUI = ctx.updateUI,
      setMainFrameVisible = ctx.setMainFrameVisible,
      updateLeaderButtons = ctx.updateLeaderButtons,
      updateStatusLine = ctx.updateStatusLine,
      applyLocalizationToUI = ctx.applyLocalizationToUI,
      restoreLayoutState = ctx.restoreLayoutState,
      updateCountdownCancelButton = ctx.updateCountdownCancelButton,
      checkIfEnteredTargetDungeon = ctx.checkIfEnteredTargetDungeon,
      captureRioBaselineSnapshot = ctx.captureRioBaselineSnapshot,
      restoreRioBaseline = ctx.restoreRioBaseline,
      isReadyCheckActive = ctx.isReadyCheckActive,
      setReadyCheckActive = ctx.setReadyCheckActive,
      enableRioDeltaDisplay = ctx.enableRioDeltaDisplay,
      setMainFrameHeightSafe = ctx.setMainFrameHeightSafe,
      -- Late-bound: ctx.UpdateCdTracker / ctx.baselineCdTracker are set after event
      -- handlers are wired, so capture ctx by reference and resolve at call time.
      updateCdTracker = function()
        if type(ctx.UpdateCdTracker) == "function" then
          ctx.UpdateCdTracker()
        end
      end,
      baselineCdTracker = function(seconds)
        if type(ctx.baselineCdTracker) == "function" then
          ctx.baselineCdTracker(seconds)
        end
      end,
      -- Late-bound: ctx.cdTrackerController is set after event handlers are wired.
      notifyCdTrackerSpellCast = function(spellId)
        local ctrl = ctx.cdTrackerController
        if type(ctrl) == "table" and type(ctrl.NotifySpellCast) == "function" then
          ctrl.NotifySpellCast(spellId)
        end
      end,
    },
  }
end

function ControllerWiring.CreateEventHandlersControllerFromContext(eventHandlersModule, ctx)
  return ControllerWiring.CreateEventHandlersController(eventHandlersModule, BuildEventHandlersDepsFromContext(ctx))
end
