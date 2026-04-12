local _, addonTable = ...

addonTable = addonTable or {}

local ControllerWiring = {}
addonTable.ControllerWiring = ControllerWiring

local function RequireFunction(value, name)
  return addonTable.Validators.RequireFunction(value, name, "ControllerWiring")
end

local function RequireTable(value, name)
  return addonTable.Validators.RequireTable(value, name, "ControllerWiring")
end

local ContextHelpers = addonTable.ContextHelpers or {}

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
    updateLeaderButtons = RequireFunction(callbacks.updateLeaderButtons, "callbacks.updateLeaderButtons"),
    clearLatestQueueTarget = RequireFunction(callbacks.clearLatestQueueTarget, "callbacks.clearLatestQueueTarget"),
    clearRioBaselineSnapshot = type(callbacks.clearRioBaselineSnapshot) == "function"
        and callbacks.clearRioBaselineSnapshot
      or function() end,
    clearPendingQueueJoinInfo = type(callbacks.clearPendingQueueJoinInfo) == "function"
        and callbacks.clearPendingQueueJoinInfo
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
    unitIsGroupLeader = RequireFunction(deps.unitIsGroupLeader, "unitIsGroupLeader"),
    unitHasIsiLive = RequireFunction(deps.unitHasIsiLive, "unitHasIsiLive"),
    applyKnownKeyToRosterEntry = RequireFunction(deps.applyKnownKeyToRosterEntry, "applyKnownKeyToRosterEntry"),
    enqueueInspect = RequireFunction(deps.enqueueInspect, "enqueueInspect"),
    sendOwnKeySnapshot = RequireFunction(deps.sendOwnKeySnapshot, "sendOwnKeySnapshot"),
    sendIsiLiveHello = RequireFunction(deps.sendIsiLiveHello, "sendIsiLiveHello"),
    sendRefreshRequest = RequireFunction(deps.sendRefreshRequest, "sendRefreshRequest"),
    getRaidTransitionBehavior = deps.getRaidTransitionBehavior or function()
      return "hide"
    end,
    shouldAutoCloseMainFrame = deps.shouldAutoCloseMainFrame or function()
      return false
    end,
    autoCloseMainFrame = deps.autoCloseMainFrame or function() end,
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
      updateLeaderButtons = ctx.updateLeaderButtons,
      clearLatestQueueTarget = ctx.clearLatestQueueTarget,
      clearRioBaselineSnapshot = ctx.clearRioBaselineSnapshot,
      clearPendingQueueJoinInfo = ctx.clearPendingQueueJoinInfo,
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
    unitIsGroupLeader = ctx.unitIsGroupLeader,
    unitHasIsiLive = ctx.unitHasIsiLive,
    applyKnownKeyToRosterEntry = ctx.applyKnownKeyToRosterEntry,
    enqueueInspect = ctx.enqueueInspect,
    sendOwnKeySnapshot = ctx.sendOwnKeySnapshot,
    sendIsiLiveHello = ctx.sendIsiLiveHello,
    sendRefreshRequest = ctx.sendRefreshRequest,
    timerAfter = function(seconds, callback)
      if C_Timer and C_Timer.After then
        C_Timer.After(seconds, function()
          pcall(callback)
        end)
      end
    end,
    onGroupJoined = function() end,
    onMemberJoinedGroup = function()
      local soundUtils = addonTable.SoundUtils
      if type(soundUtils) == "table" and type(soundUtils.PlayGroupJoin) == "function" then
        soundUtils.PlayGroupJoin()
        return
      end
      if type(soundUtils) == "table" and type(soundUtils.Play) == "function" then
        soundUtils.Play("Interface\\AddOns\\isiLive\\sounds\\SynthChord.ogg")
      end
    end,
    getRaidTransitionBehavior = ctx.getRaidTransitionBehavior,
    shouldAutoCloseMainFrame = ctx.shouldAutoCloseMainFrame,
    autoCloseMainFrame = ctx.autoCloseMainFrame,
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
    isRaidGroup = type(deps.isRaidGroup) == "function" and deps.isRaidGroup or function()
      return false
    end,
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
    getPendingPostChallengeRefresh = type(state.getPendingPostChallengeRefresh) == "function"
        and state.getPendingPostChallengeRefresh
      or function()
        return nil
      end,
    setPendingPostChallengeRefresh = RequireFunction(
      state.setPendingPostChallengeRefresh,
      "state.setPendingPostChallengeRefresh"
    ),
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
    refreshReadyCheckUI = RequireFunction(callbacks.refreshReadyCheckUI, "callbacks.refreshReadyCheckUI"),
    setMainFrameVisible = RequireFunction(callbacks.setMainFrameVisible, "callbacks.setMainFrameVisible"),
    shouldShowMainFrameOnStartup = type(deps.shouldShowMainFrameOnStartup) == "function"
        and deps.shouldShowMainFrameOnStartup
      or function()
        return true
      end,
    shouldAutoOpenMainFrameOnKeyEnd = type(deps.shouldAutoOpenMainFrameOnKeyEnd) == "function"
        and deps.shouldAutoOpenMainFrameOnKeyEnd
      or function()
        return true
      end,
    updateLeaderButtons = RequireFunction(callbacks.updateLeaderButtons, "callbacks.updateLeaderButtons"),
    updateStatusLine = RequireFunction(callbacks.updateStatusLine, "callbacks.updateStatusLine"),
    sendIsiLiveHello = RequireFunction(deps.sendIsiLiveHello, "sendIsiLiveHello"),
    sendLibKeystonePartyData = type(deps.sendLibKeystonePartyData) == "function" and deps.sendLibKeystonePartyData
      or function(_force)
        return false
      end,
    sendOwnKeySnapshot = RequireFunction(deps.sendOwnKeySnapshot, "sendOwnKeySnapshot"),
    sendOwnBackgroundSnapshot = RequireFunction(deps.sendOwnBackgroundSnapshot, "sendOwnBackgroundSnapshot"),
    shouldAutoCloseMainFrame = type(deps.shouldAutoCloseMainFrame) == "function" and deps.shouldAutoCloseMainFrame
      or function()
        return false
      end,
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
  config.getPendingMainFrameWidth = function()
    return refs.mainUI.GetPendingWidth()
  end
  config.getPendingMainFrameVisible = function()
    return refs.mainUI.GetPendingVisible()
  end
  config.setMainFrameHeightSafe = RequireFunction(callbacks.setMainFrameHeightSafe, "callbacks.setMainFrameHeightSafe")
  config.setMainFrameWidthSafe = RequireFunction(callbacks.setMainFrameWidthSafe, "callbacks.setMainFrameWidthSafe")
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
  config.notifyPostChallengeSync = function()
    controllers.refresh.NotifyPostChallengeSync()
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
  config.processAddonMessage = function(prefix, message, sender, channel)
    local localName, localRealm = deps.getUnitNameAndRealm("player")
    return modules.sync.ProcessAddonMessage(prefix, message, sender, localName, localRealm, channel)
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
  config.getReadyCheckReadyUntil = type(state.getReadyCheckReadyUntil) == "function" and state.getReadyCheckReadyUntil
    or function(_unit)
      return nil
    end
  config.setReadyCheckReadyUntil = type(state.setReadyCheckReadyUntil) == "function" and state.setReadyCheckReadyUntil
    or function(_unit, _value) end
  config.clearAllReadyCheckReady = type(state.clearAllReadyCheckReady) == "function" and state.clearAllReadyCheckReady
    or function() end
  config.clearExpiredReadyCheckReady = type(state.clearExpiredReadyCheckReady) == "function"
      and state.clearExpiredReadyCheckReady
    or function(_now)
      return false
    end
  config.getReadyCheckDeclinedUntil = type(state.getReadyCheckDeclinedUntil) == "function"
      and state.getReadyCheckDeclinedUntil
    or function(_unit)
      return nil
    end
  config.setReadyCheckDeclinedUntil = type(state.setReadyCheckDeclinedUntil) == "function"
      and state.setReadyCheckDeclinedUntil
    or function(_unit, _value) end
  config.clearAllReadyCheckDeclined = type(state.clearAllReadyCheckDeclined) == "function"
      and state.clearAllReadyCheckDeclined
    or function() end
  config.clearExpiredReadyCheckDeclined = type(state.clearExpiredReadyCheckDeclined) == "function"
      and state.clearExpiredReadyCheckDeclined
    or function(_now)
      return false
    end
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
    isRaidGroup = ctx.isRaidGroup,
    isNegativeApplicationStatusEvent = ctx.isNegativeApplicationStatusEvent,
    getNormalizedActiveEntryInfo = ctx.getNormalizedActiveEntryInfo,
    sendIsiLiveHello = ctx.sendIsiLiveHello,
    sendLibKeystonePartyData = ctx.sendLibKeystonePartyData,
    sendOwnKeySnapshot = ctx.sendOwnKeySnapshot,
    sendOwnBackgroundSnapshot = ctx.sendOwnBackgroundSnapshot,
    shouldShowMainFrameOnStartup = ctx.shouldShowMainFrameOnStartup,
    shouldAutoOpenMainFrameOnKeyEnd = ctx.shouldAutoOpenMainFrameOnKeyEnd,
    shouldAutoCloseMainFrame = ctx.shouldAutoCloseMainFrame,
    sendRefreshResponse = ctx.sendRefreshResponse,
    triggerShareKeysCooldown = ctx.TriggerShareKeysCooldown,
    sendOwnKeystoneToChat = function()
      local now = GetTime()
      if ctx._lastKeystoneChatAt and (now - ctx._lastKeystoneChatAt) < 30 then
        return
      end
      local roster = ctx.GetRoster and ctx.GetRoster()
      local playerInfo = roster and roster.player
      if type(playerInfo) ~= "table" then
        return
      end
      local keyLevel = tonumber(playerInfo.keyLevel)
      local keyMapID = tonumber(playerInfo.keyMapID)
      if not keyLevel or keyLevel <= 0 or not keyMapID or keyMapID <= 0 then
        return
      end
      local keyLink = ContextHelpers.BuildKeystoneChatLink(keyMapID, keyLevel)
      if not keyLink then
        local db = rawget(_G, "IsiLiveDB")
        local activeLocale = (db and db.locale) or ctx.locale
        local short = (
          ctx.modules
          and ctx.modules.teleport
          and ctx.modules.teleport.GetDungeonShortCode(keyMapID, activeLocale)
        ) or tostring(keyMapID)
        keyLink =
          ContextHelpers.BuildClickableKeystoneLink(keyMapID, keyLevel, string.format("%s +%d", short, keyLevel))
      end
      local L = ctx.GetL and ctx.GetL()
      local announcePrefix = L and tostring(L.ANNOUNCE_PREFIX or "PartyKeys:"):gsub("%s+", "") or "PartyKeys:"
      local line = string.format("[isiLive] %s %s", announcePrefix, keyLink)
      local sendChatMessage = rawget(_G, "SendChatMessage")
      if type(sendChatMessage) == "function" and ctx.isInGroup and ctx.isInGroup() then
        pcall(sendChatMessage, line, "PARTY")
        ctx._lastKeystoneChatAt = now
      end
    end,
    ensureQueueDebugStorage = ctx.ensureQueueDebugStorage,
    setQueueDebugEnabled = ctx.setQueueDebugEnabled,
    ensureRuntimeLogStorage = ctx.ensureRuntimeLogStorage,
    setRuntimeLogEnabled = ctx.setRuntimeLogEnabled,
    logRuntimeTrace = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil,
    registerIsiLiveSyncPrefix = ctx.registerIsiLiveSyncPrefix,
    applyHotkeyBindings = ctx.applyHotkeyBindings,
    startBindingWatchdog = ctx.startBindingWatchdog,
    getUnitNameAndRealm = ctx.getUnitNameAndRealm,
    markIsiLiveUser = ctx.markIsiLiveUser,
    getUnitRio = ctx.getUnitRio,
    getInspectSpecName = ctx.getInspectSpecName,
    getPlayerSpecName = ctx.getPlayerSpecName,
    getAddonVersionRaw = ctx.getAddonVersionRaw,
    getCombatLogEventInfo = ctx.GetCombatLogEventInfo,
    kickTrackerController = ctx.kickTrackerController,
    HandleKickCastSucceeded = ctx.HandleKickCastSucceeded,
    HandleKickPetChanged = ctx.HandleKickPetChanged,
    RefreshKickState = ctx.RefreshKickState,
    CacheKickCooldown = ctx.CacheKickCooldown,
    getTime = ctx.getTime,
    recordRun = ctx.recordRun,
    applyKnownKeyToRosterEntry = ctx.applyKnownKeyToRosterEntry,
    sendOwnKickState = ctx.sendOwnKickState,
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
      getPendingPostChallengeRefresh = ctx.getPendingPostChallengeRefresh,
      setPendingPostChallengeRefresh = ctx.setPendingPostChallengeRefresh,
      getActiveJoinedKeyMapID = ctx.getActiveJoinedKeyMapID,
      setActiveJoinedKeyMapID = ctx.setActiveJoinedKeyMapID,
      getPendingBindingApply = ctx.getPendingBindingApply,
      getRoster = ctx.getRoster,
      getReadyCheckReadyUntil = ctx.GetReadyCheckReadyUntil,
      getReadyCheckDeclinedUntil = ctx.GetReadyCheckDeclinedUntil,
      setReadyCheckDeclinedUntil = ctx.SetReadyCheckDeclinedUntil,
      setReadyCheckReadyUntil = ctx.SetReadyCheckReadyUntil,
      clearAllReadyCheckReady = ctx.ClearAllReadyCheckReady,
      clearAllReadyCheckDeclined = ctx.ClearAllReadyCheckDeclined,
      clearExpiredReadyCheckReady = ctx.ClearExpiredReadyCheckReady,
      clearExpiredReadyCheckDeclined = ctx.ClearExpiredReadyCheckDeclined,
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
      refreshReadyCheckUI = ctx.refreshReadyCheckUI,
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
      setMainFrameWidthSafe = ctx.setMainFrameWidthSafe,
      -- Late-bound: ctx.UpdateCdTracker is set after event handlers are wired,
      -- so capture ctx by reference and resolve at call time.
      updateCdTracker = function()
        if type(ctx.UpdateCdTracker) == "function" then
          ctx.UpdateCdTracker()
        end
      end,
    },
  }
end

function ControllerWiring.CreateEventHandlersControllerFromContext(eventHandlersModule, ctx)
  return ControllerWiring.CreateEventHandlersController(eventHandlersModule, BuildEventHandlersDepsFromContext(ctx))
end
