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
  })
end

local function BuildEventHandlersBaseConfig(deps, state, refs, controllers, callbacks)
  return {
    addonName = assert(deps.addonName, "isiLive: ControllerWiring requires addonName"),
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
    getMainFrame = function()
      return refs.mainFrame
    end,
    applyCenterNoticeStoredPosition = function(position)
      refs.centerNotice.ApplyStoredPosition(position)
    end,
    registerIsiLiveSyncPrefix = RequireFunction(deps.registerIsiLiveSyncPrefix, "registerIsiLiveSyncPrefix"),
    applyHotkeyBindings = RequireFunction(deps.applyHotkeyBindings, "applyHotkeyBindings"),
    startBindingWatchdog = RequireFunction(deps.startBindingWatchdog, "startBindingWatchdog"),
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
  config.sendIsiLiveHello = RequireFunction(deps.sendIsiLiveHello, "sendIsiLiveHello")
  config.maybeShowNonMythicDungeonEntryNotice = function()
    controllers.status.MaybeShowNonMythicDungeonEntryNotice()
  end
  config.checkIfEnteredTargetDungeon =
    RequireFunction(callbacks.checkIfEnteredTargetDungeon, "callbacks.checkIfEnteredTargetDungeon")
  config.timerAfter = function(seconds, callback)
    if C_Timer and C_Timer.After then
      C_Timer.After(seconds, callback)
    end
  end
  config.getPendingBindingApply = RequireFunction(state.getPendingBindingApply, "state.getPendingBindingApply")
  config.getPendingMainFrameHeight = function()
    return refs.mainUI.GetPendingHeight()
  end
  config.setMainFrameHeightSafe = RequireFunction(callbacks.setMainFrameHeightSafe, "callbacks.setMainFrameHeightSafe")
  config.getPendingMainFrameVisible = function()
    return refs.mainUI.GetPendingVisible()
  end
  config.getPendingCenterNoticeVisible = function()
    return refs.centerNotice.GetPendingVisible()
  end
  config.setCenterNoticeVisible = RequireFunction(callbacks.setCenterNoticeVisible, "callbacks.setCenterNoticeVisible")
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
  config.captureRioBaselineSnapshot = callbacks.captureRioBaselineSnapshot
  config.enableRioDeltaDisplay = callbacks.enableRioDeltaDisplay
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
