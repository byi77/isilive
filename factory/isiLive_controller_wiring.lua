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

local function BuildTimerAfter()
  return function(seconds, callback)
    local timer = rawget(_G, "C_Timer")
    if type(timer) == "table" and type(timer.After) == "function" then
      timer.After(seconds, function()
        local ok, err = xpcall(callback, function(e)
          local debugLib = rawget(_G, "debug")
          if type(debugLib) == "table" and type(debugLib.traceback) == "function" then
            return debugLib.traceback(tostring(e), 2)
          end
          return tostring(e)
        end)
        if not ok then
          -- Report callback crashes to WoW's global error handler so they stay visible.
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
end

addonTable.ContextHelpers = addonTable.ContextHelpers or {}
local ContextHelpers = addonTable.ContextHelpers

local function DispatchModuleEvent(moduleValue, event, ...)
  if type(moduleValue) == "table" and type(moduleValue.HandleEvent) == "function" then
    moduleValue.HandleEvent(event, ...)
  end
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
    onGroupJoined = type(callbacks.onGroupJoined) == "function" and callbacks.onGroupJoined or function() end,
    onMemberJoinedGroup = type(callbacks.onMemberJoinedGroup) == "function" and callbacks.onMemberJoinedGroup
      or function() end,
    setMainFrameVisible = RequireFunction(callbacks.setMainFrameVisible, "callbacks.setMainFrameVisible"),
    isMainFrameVisible = type(callbacks.isMainFrameVisible) == "function" and callbacks.isMainFrameVisible
      or function()
        return false
      end,
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
    getInspectSpecRole = type(deps.getInspectSpecRole) == "function" and deps.getInspectSpecRole or function()
      return nil
    end,
    getUnitRio = RequireFunction(deps.getUnitRio, "getUnitRio"),
    getOwnAverageItemLevel = type(deps.getOwnAverageItemLevel) == "function" and deps.getOwnAverageItemLevel
      or function()
        return nil
      end,
    unitIsGroupLeader = RequireFunction(deps.unitIsGroupLeader, "unitIsGroupLeader"),
    unitHasIsiLive = RequireFunction(deps.unitHasIsiLive, "unitHasIsiLive"),
    applyKnownKeyToRosterEntry = RequireFunction(deps.applyKnownKeyToRosterEntry, "applyKnownKeyToRosterEntry"),
    enqueueInspect = RequireFunction(deps.enqueueInspect, "enqueueInspect"),
    sendOwnKeySnapshot = RequireFunction(deps.sendOwnKeySnapshot, "sendOwnKeySnapshot"),
    sendIsiLiveHello = RequireFunction(deps.sendIsiLiveHello, "sendIsiLiveHello"),
    sendRefreshRequest = RequireFunction(deps.sendRefreshRequest, "sendRefreshRequest"),
    getReloadRosterMirror = type(deps.getReloadRosterMirror) == "function" and deps.getReloadRosterMirror or function()
      return nil
    end,
    setReloadRosterMirror = type(deps.setReloadRosterMirror) == "function" and deps.setReloadRosterMirror
      or function() end,
    clearReloadRosterMirror = type(deps.clearReloadRosterMirror) == "function" and deps.clearReloadRosterMirror
      or function() end,
    getReloadRosterTargetSnapshot = type(deps.getReloadRosterTargetSnapshot) == "function"
        and deps.getReloadRosterTargetSnapshot
      or function()
        return nil
      end,
    restoreReloadRosterTargetSnapshot = type(deps.restoreReloadRosterTargetSnapshot) == "function"
        and deps.restoreReloadRosterTargetSnapshot
      or function() end,
    getRaidTransitionBehavior = deps.getRaidTransitionBehavior or function()
      return "hide"
    end,
    shouldAutoCloseOnSoloChange = deps.shouldAutoCloseOnSoloChange or function()
      return false
    end,
    autoCloseMainFrame = deps.autoCloseMainFrame or function() end,
    logRuntimeTrace = deps.logRuntimeTrace,
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
      onGroupJoined = ctx.onGroupJoined,
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
      setMainFrameVisible = ctx.setMainFrameVisible,
      isMainFrameVisible = ctx.isMainFrameVisible,
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
    getOwnAverageItemLevel = ctx.getOwnAverageItemLevel,
    unitIsGroupLeader = ctx.unitIsGroupLeader,
    unitHasIsiLive = ctx.unitHasIsiLive,
    applyKnownKeyToRosterEntry = ctx.applyKnownKeyToRosterEntry,
    enqueueInspect = ctx.enqueueInspect,
    sendOwnKeySnapshot = ctx.sendOwnKeySnapshot,
    sendIsiLiveHello = ctx.sendIsiLiveHello,
    sendRefreshRequest = ctx.sendRefreshRequest,
    getReloadRosterMirror = ctx.getReloadRosterMirror,
    setReloadRosterMirror = ctx.setReloadRosterMirror,
    clearReloadRosterMirror = ctx.clearReloadRosterMirror,
    getReloadRosterTargetSnapshot = ctx.getReloadRosterTargetSnapshot,
    restoreReloadRosterTargetSnapshot = ctx.restoreReloadRosterTargetSnapshot,
    timerAfter = BuildTimerAfter(),
    onGroupJoined = function() end,
    getRaidTransitionBehavior = ctx.getRaidTransitionBehavior,
    shouldAutoCloseOnSoloChange = ctx.shouldAutoCloseOnSoloChange,
    autoCloseMainFrame = ctx.autoCloseMainFrame,
    isMainFrameVisible = ctx.isMainFrameVisible,
    logRuntimeTrace = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil,
    logRuntimeTracef = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil,
  }
end

function ControllerWiring.CreateGroupControllerFromContext(groupModule, ctx)
  return ControllerWiring.CreateGroupController(groupModule, BuildGroupControllerDepsFromContext(ctx))
end

local function BuildEventHandlersBaseConfig(deps, state, refs, controllers, callbacks)
  local function GetMainFrame()
    if refs.mainFrame then
      return refs.mainFrame
    end
    if refs.mainUI and refs.mainUI.frame then
      return refs.mainUI.frame
    end
    return nil
  end

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
    saveReloadRosterMirror = function()
      if controllers.group and type(controllers.group.SaveReloadRosterMirror) == "function" then
        controllers.group.SaveReloadRosterMirror()
      end
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
    shouldAutoCloseOnKeyStart = type(deps.shouldAutoCloseOnKeyStart) == "function" and deps.shouldAutoCloseOnKeyStart
      or function()
        return false
      end,
    ensureQueueDebugStorage = RequireFunction(deps.ensureQueueDebugStorage, "ensureQueueDebugStorage"),
    setQueueDebugEnabled = RequireFunction(deps.setQueueDebugEnabled, "setQueueDebugEnabled"),
    ensureRuntimeLogStorage = type(deps.ensureRuntimeLogStorage) == "function" and deps.ensureRuntimeLogStorage
      or function() end,
    setRuntimeLogEnabled = type(deps.setRuntimeLogEnabled) == "function" and deps.setRuntimeLogEnabled
      or function(_enabled) end,
    logRuntimeTrace = type(deps.logRuntimeTrace) == "function" and deps.logRuntimeTrace or function(_message) end,
    logRuntimeTracef = type(deps.logRuntimeTracef) == "function" and deps.logRuntimeTracef or function(_formatText) end,
    getMainFrame = GetMainFrame,
    registerIsiLiveSyncPrefix = RequireFunction(deps.registerIsiLiveSyncPrefix, "registerIsiLiveSyncPrefix"),
    applyHotkeyBindings = RequireFunction(deps.applyHotkeyBindings, "applyHotkeyBindings"),
    startBindingWatchdog = RequireFunction(deps.startBindingWatchdog, "startBindingWatchdog"),
    restoreLayoutState = RequireFunction(callbacks.restoreLayoutState, "callbacks.restoreLayoutState"),
    applyLocalizationToUI = RequireFunction(callbacks.applyLocalizationToUI, "callbacks.applyLocalizationToUI"),
    applyDBSettings = type(callbacks.applyDBSettings) == "function" and callbacks.applyDBSettings or function() end,
    updateCountdownCancelButton = RequireFunction(
      callbacks.updateCountdownCancelButton,
      "callbacks.updateCountdownCancelButton"
    ),
    restoreBgAlpha = type(callbacks.restoreBgAlpha) == "function" and callbacks.restoreBgAlpha or function(_alpha) end,
  }
end

local function ExtendEventHandlersConfig(config, deps, state, refs, controllers, callbacks, modules)
  config.getUnitNameAndRealm = RequireFunction(deps.getUnitNameAndRealm, "getUnitNameAndRealm")
  config.getUnitRole = type(deps.getUnitRole) == "function" and deps.getUnitRole or function(_unit)
    return nil
  end
  config.getPlayerSpecName = type(deps.getPlayerSpecName) == "function" and deps.getPlayerSpecName
    or function()
      return nil
    end
  config.markIsiLiveUser = RequireFunction(deps.markIsiLiveUser, "markIsiLiveUser")
  config.refreshActiveSeasonFromBlizzard = function(eventName)
    local seasonData = addonTable.SeasonData
    local challengeMode = rawget(_G, "C_ChallengeMode")
    local getMapTable = type(challengeMode) == "table" and rawget(challengeMode, "GetMapTable") or nil
    if
      type(seasonData) ~= "table"
      or type(seasonData.TryAutoSelectSeasonFromChallengeMapIDs) ~= "function"
      or type(getMapTable) ~= "function"
    then
      return false
    end

    local inCombatLockdown = rawget(_G, "InCombatLockdown")
    if type(inCombatLockdown) == "function" then
      local okCombat, inCombat = pcall(inCombatLockdown)
      if not okCombat or inCombat == true then
        return false
      end
    end

    local okMaps, mapIDs = pcall(getMapTable)
    if not okMaps or type(mapIDs) ~= "table" then
      return false
    end

    local ok, changed, message = seasonData.TryAutoSelectSeasonFromChallengeMapIDs(mapIDs, {
      forcesData = addonTable.MPlusForces,
    })
    if type(config.logRuntimeTracef) == "function" then
      config.logRuntimeTracef(
        "[SEASON] auto_select event=%s ok=%s changed=%s active=%s reason=%s",
        tostring(eventName),
        tostring(ok),
        tostring(changed),
        tostring(seasonData.GetActiveSeasonID and seasonData.GetActiveSeasonID() or nil),
        tostring(message)
      )
    end
    if not (ok and changed) then
      return false
    end

    if controllers.teleport and type(controllers.teleport.BuildButtons) == "function" then
      controllers.teleport.BuildButtons()
    end
    if type(callbacks.updateUI) == "function" then
      callbacks.updateUI()
    end
    return true
  end
  config.maybeShowNonMythicDungeonEntryNotice = function()
    local seasonData = addonTable.SeasonData
    if type(seasonData) == "table" and type(seasonData.HasActiveDungeons) == "function" then
      if not seasonData.HasActiveDungeons() then
        return
      end
    end
    if controllers.status then
      controllers.status.MaybeShowNonMythicDungeonEntryNotice()
    end
  end
  config.maybeShowPortalNavigatorNotice = function()
    if controllers.status then
      controllers.status.MaybeShowPortalNavigatorNotice()
    end
  end
  config.checkIfEnteredTargetDungeon =
    RequireFunction(callbacks.checkIfEnteredTargetDungeon, "callbacks.checkIfEnteredTargetDungeon")
  config.timerAfter = BuildTimerAfter()
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
    -- Drain the pending-state captured by SetCenterNoticeTeleportButton* during
    -- the combat lockdown that just ended. Previously this drain ran in the
    -- center-notice OnUpdate every frame; now it fires exactly once on the
    -- regen-enabled edge.
    local centerNotice = refs.centerNotice
    if centerNotice and type(centerNotice.ApplyPendingTeleportButtonState) == "function" then
      centerNotice.ApplyPendingTeleportButtonState()
    end
  end
  config.handleOwnedKeyRefresh = function()
    if controllers.refresh then
      controllers.refresh.HandleOwnedKeyRefresh()
    end
  end
  config.notifyPostChallengeSync = function()
    if controllers.refresh then
      controllers.refresh.NotifyPostChallengeSync()
    end
  end
  config.isMainFrameShown = function()
    local mainFrame = type(config.getMainFrame) == "function" and config.getMainFrame() or nil
    return mainFrame and type(mainFrame.IsShown) == "function" and mainFrame:IsShown() == true
  end
  config.onInspectReady = function(guid)
    if not controllers.inspect then
      return
    end
    return controllers.inspect.OnInspectReady(
      guid,
      state.getRoster(),
      deps.getUnitRio,
      deps.getInspectSpecName,
      deps.getPlayerSpecName,
      deps.getOwnAverageItemLevel,
      deps.getInspectSpecRole
    )
  end
  config.processAddonMessage = function(prefix, message, sender, channel)
    local localName, localRealm = deps.getUnitNameAndRealm("player")
    return modules.sync.ProcessAddonMessage(prefix, message, sender, localName, localRealm, channel)
  end
  config.showCombatAnnounce = type(deps.showCombatAnnounce) == "function" and deps.showCombatAnnounce
    or function(_info) end
  config.showPowerInfusionAnnounce = type(deps.showPowerInfusionAnnounce) == "function"
      and deps.showPowerInfusionAnnounce
    or function(_info) end
  config.playIncomingSummonSound = type(deps.playIncomingSummonSound) == "function" and deps.playIncomingSummonSound
    or function() end
  config.isIncomingSummonSoundLoopEnabled = type(deps.isIncomingSummonSoundLoopEnabled) == "function"
      and deps.isIncomingSummonSoundLoopEnabled
    or function()
      return true
    end
  config.playReadyCheckCompleteSound = type(deps.playReadyCheckCompleteSound) == "function"
      and deps.playReadyCheckCompleteSound
    or function() end
  config.sendAck = function(sender)
    if type(sender) ~= "string" or sender == "" then
      return
    end
    local chatInfo = rawget(_G, "C_ChatInfo")
    if type(chatInfo) ~= "table" or type(chatInfo.SendAddonMessage) ~= "function" then
      return
    end
    pcall(chatInfo.SendAddonMessage, modules.sync.GetPrefix(), "ACK:" .. deps.getAddonVersionRaw(), "WHISPER", sender)
  end
  config.sendRefreshResponse = RequireFunction(deps.sendRefreshResponse, "sendRefreshResponse")
  config.sendOwnKeystoneToChat = type(deps.sendOwnKeystoneToChat) == "function" and deps.sendOwnKeystoneToChat
    or function()
      return false
    end
  config.triggerShareKeysCooldown = type(deps.triggerShareKeysCooldown) == "function" and deps.triggerShareKeysCooldown
    or function() end
  config.sendShareKeysCooldownState = function()
    -- Mirror only locally owned locks (own click / received SHAREKEYS).
    -- Re-broadcasting a lock that was itself set by a remote SKCD mirror
    -- would reflect the cooldown between peers indefinitely.
    local getRemaining = deps.getShareKeysLocalCooldownRemaining
    local remain = type(getRemaining) == "function" and tonumber(getRemaining()) or nil
    if not remain or remain <= 0 then
      return false
    end
    if type(modules.sync.SendShareKeysCooldown) ~= "function" then
      return false
    end
    return modules.sync.SendShareKeysCooldown({ remain = remain }) == true
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
  config.registerVerifiedSyncAliasForRoster = type(deps.registerVerifiedSyncAliasForRoster) == "function"
      and deps.registerVerifiedSyncAliasForRoster
    or function(_roster, _sender)
      return false
    end
  config.runFullRefresh = RequireFunction(deps.runFullRefresh, "runFullRefresh")
  config.recordRun = type(deps.recordRun) == "function" and deps.recordRun or function() end
  config.getRoster = RequireFunction(state.getRoster, "state.getRoster")
  config.captureRioBaselineSnapshot = callbacks.captureRioBaselineSnapshot
  config.restoreRioBaseline = callbacks.restoreRioBaseline
  config.enableRioDeltaDisplay = callbacks.enableRioDeltaDisplay
  config.updateCdTracker = type(callbacks.updateCdTracker) == "function" and callbacks.updateCdTracker or function() end
  config.handleLFGDetectEvent = type(deps.handleLFGDetectEvent) == "function" and deps.handleLFGDetectEvent
    or function(_event, ...) end
  config.handleMplusTimerEvent = type(deps.handleMplusTimerEvent) == "function" and deps.handleMplusTimerEvent
    or function(_event, ...) end
  config.handleKillTrackEvent = type(deps.handleKillTrackEvent) == "function" and deps.handleKillTrackEvent
    or function(_event, ...) end
  config.handleCombatEventsEvent = type(deps.handleCombatEventsEvent) == "function" and deps.handleCombatEventsEvent
    or function(_event, ...) end
  config.handlePiTrackerEvent = type(deps.handlePiTrackerEvent) == "function" and deps.handlePiTrackerEvent
    or function(_event, ...) end
  config.handleBloodlustButtonWarningEvent = type(deps.handleBloodlustButtonWarningEvent) == "function"
      and deps.handleBloodlustButtonWarningEvent
    or function(_event, ...) end
  config.handleVipDkAssistEvent = type(deps.handleVipDkAssistEvent) == "function" and deps.handleVipDkAssistEvent
    or function(_event, ...) end
  config.handleDeathWatchEvent = type(deps.handleDeathWatchEvent) == "function" and deps.handleDeathWatchEvent
    or function(_event, ...) end
  config.handleKickTrackerEvent = type(deps.handleKickTrackerEvent) == "function" and deps.handleKickTrackerEvent
    or function(_event, ...) end
  config.handleLeaderWatchEvent = type(deps.handleLeaderWatchEvent) == "function" and deps.handleLeaderWatchEvent
    or function(_event, ...) end
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
    shouldAutoCloseOnKeyStart = ctx.shouldAutoCloseOnKeyStart,
    sendRefreshResponse = ctx.sendRefreshResponse,
    sendRefreshRequest = ctx.sendRefreshRequest,
    triggerShareKeysCooldown = ctx.TriggerShareKeysCooldown,
    getShareKeysCooldownRemaining = ctx.GetShareKeysCooldownRemaining,
    getShareKeysLocalCooldownRemaining = ctx.GetShareKeysLocalCooldownRemaining,
    registerVerifiedSyncAliasForRoster = ctx.registerVerifiedSyncAliasForRoster,
    sendOwnKeystoneToChat = function()
      local logFn = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil
      local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
      local traceDeep = ctx.runtimeLogController and ctx.runtimeLogController.TraceDeep or nil
      local getTimeFn = rawget(_G, "GetTime")
      local now = type(getTimeFn) == "function" and getTimeFn() or 0
      if logf then
        logf("[KEYSTONE] share_triggered isInGroup=%s", tostring(ctx.isInGroup and ctx.isInGroup()))
      end
      if ctx._lastKeystoneChatAt and (now - ctx._lastKeystoneChatAt) < 30 then
        if traceDeep then
          traceDeep(function()
            return string.format(
              "[KEYSTONE] aborted reason=cooldown remaining=%s",
              tostring(30 - (now - ctx._lastKeystoneChatAt))
            )
          end)
        end
        return false
      end

      -- The share-keys button cooldown doubles as the shared quiet-window
      -- stamp: it starts on a local click (own key already announced then)
      -- and on every received SHAREKEYS. Honour it here because
      -- _lastKeystoneChatAt is only written by this response path — without
      -- this guard an incoming SHAREKEYS shortly after a local click would
      -- re-post the key a second time.
      local buttonCooldownRemain = type(ctx.GetShareKeysCooldownRemaining) == "function"
          and tonumber(ctx.GetShareKeysCooldownRemaining())
        or nil
      if buttonCooldownRemain and buttonCooldownRemain > 0 then
        if traceDeep then
          traceDeep(function()
            return string.format(
              "[KEYSTONE] aborted reason=button_cooldown remaining=%s",
              tostring(buttonCooldownRemain)
            )
          end)
        end
        return false
      end

      local roster = ctx.getRoster and ctx.getRoster()
      if traceDeep then
        traceDeep(function()
          local memberCount = "nil"
          if type(roster) == "table" then
            local n = 0
            for _ in pairs(roster) do
              n = n + 1
            end
            memberCount = tostring(n)
          end
          return string.format("[KEYSTONE] roster_resolved memberCount=%s", memberCount)
        end)
      end

      local snapshotMapID, snapshotLevel
      if ctx.getOwnedKeystoneSnapshot then
        snapshotMapID, snapshotLevel = ctx.getOwnedKeystoneSnapshot()
      end
      if traceDeep then
        traceDeep(function()
          return string.format(
            "[KEYSTONE] snapshot_resolved mapID=%s level=%s",
            tostring(snapshotMapID or "nil"),
            tostring(snapshotLevel or "nil")
          )
        end)
      end

      local line = type(ContextHelpers.BuildOwnKeystoneAnnounceLine) == "function"
        and ContextHelpers.BuildOwnKeystoneAnnounceLine({
          getL = ctx.getL,
          getRoster = ctx.getRoster,
          getOwnedKeystoneSnapshot = ctx.getOwnedKeystoneSnapshot,
          getDungeonShortCode = function(mapID)
            local db = rawget(_G, "IsiLiveDB")
            local activeLocale = (db and db.locale) or ctx.locale
            return ctx.modules
              and ctx.modules.teleport
              and ctx.modules.teleport.GetDungeonShortCode(mapID, activeLocale)
          end,
        })

      if type(line) ~= "string" or line == "" then
        if logFn then
          logFn("[KEYSTONE] aborted reason=no_line")
        end
        return false
      end

      if ctx.isInGroup and ctx.isInGroup() then
        local sent = ContextHelpers.SendPartyChatMessage(line)
        if sent then
          ctx._lastKeystoneChatAt = now
          if traceDeep then
            traceDeep(function()
              return string.format("[KEYSTONE] chat_sent msg=%s", tostring(line))
            end)
          end
        else
          if logFn then
            logFn("[KEYSTONE] aborted reason=send_failed")
          end
        end
        return sent == true
      else
        local printFn = rawget(_G, "print")
        local printed = false
        if type(printFn) == "function" then
          printed = pcall(printFn, line)
        end
        if printed then
          ctx._lastKeystoneChatAt = now
          if traceDeep then
            traceDeep(function()
              return string.format("[KEYSTONE] chat_sent msg=%s", tostring(line))
            end)
          end
        end
        return printed == true
      end
    end,
    ensureQueueDebugStorage = ctx.ensureQueueDebugStorage,
    setQueueDebugEnabled = ctx.setQueueDebugEnabled,
    ensureRuntimeLogStorage = ctx.ensureRuntimeLogStorage,
    setRuntimeLogEnabled = ctx.setRuntimeLogEnabled,
    logRuntimeTrace = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil,
    logRuntimeTracef = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil,
    registerIsiLiveSyncPrefix = ctx.registerIsiLiveSyncPrefix,
    applyHotkeyBindings = ctx.applyHotkeyBindings,
    startBindingWatchdog = ctx.startBindingWatchdog,
    getUnitNameAndRealm = ctx.getUnitNameAndRealm,
    getUnitRole = ctx.getUnitRole,
    showCombatAnnounce = ctx.ShowCombatAnnounce,
    showPowerInfusionAnnounce = ctx.ShowPowerInfusionAnnounce,
    playIncomingSummonSound = function()
      local soundUtils = addonTable.SoundUtils
      if type(soundUtils) == "table" and type(soundUtils.PlayIncomingSummon) == "function" then
        soundUtils.PlayIncomingSummon()
      end
    end,
    isIncomingSummonSoundLoopEnabled = function()
      local db = rawget(_G, "IsiLiveDB")
      return type(db) ~= "table" or db.soundIncomingSummonLoopEnabled ~= false
    end,
    playReadyCheckCompleteSound = function()
      local soundUtils = addonTable.SoundUtils
      if type(soundUtils) == "table" and type(soundUtils.PlayReadyCheckComplete) == "function" then
        soundUtils.PlayReadyCheckComplete()
      end
    end,
    markIsiLiveUser = ctx.markIsiLiveUser,
    getUnitRio = ctx.getUnitRio,
    getInspectSpecName = ctx.getInspectSpecName,
    getInspectSpecRole = ctx.getInspectSpecRole,
    getPlayerSpecName = ctx.getPlayerSpecName,
    getOwnAverageItemLevel = ctx.getOwnAverageItemLevel,
    getAddonVersionRaw = ctx.getAddonVersionRaw,
    handleLFGDetectEvent = function(event, ...)
      DispatchModuleEvent(ctx.modules and ctx.modules.lfgDetect, event, ...)
    end,
    handleMplusTimerEvent = function(event, ...)
      DispatchModuleEvent(ctx.modules and ctx.modules.mplusTimer, event, ...)
    end,
    handleKillTrackEvent = function(event, ...)
      DispatchModuleEvent(ctx.modules and ctx.modules.killTrack, event, ...)
    end,
    handleCombatEventsEvent = function(event, ...)
      DispatchModuleEvent(ctx.modules and ctx.modules.combatEvents, event, ...)
    end,
    handlePiTrackerEvent = function(event, ...)
      DispatchModuleEvent(ctx.modules and ctx.modules.piTracker, event, ...)
    end,
    handleBloodlustButtonWarningEvent = function(event, ...)
      DispatchModuleEvent(ctx.modules and ctx.modules.bloodlustButtonWarning, event, ...)
    end,
    handleVipDkAssistEvent = function(event, ...)
      DispatchModuleEvent(ctx.modules and ctx.modules.vipDkAssist, event, ...)
    end,
    handleDeathWatchEvent = function(event, ...)
      DispatchModuleEvent(ctx.modules and ctx.modules.deathWatch, event, ...)
    end,
    handleKickTrackerEvent = function(event, ...)
      if type(ctx.HandleKickTrackerEvent) == "function" then
        ctx.HandleKickTrackerEvent(event, ...)
      end
    end,
    handleLeaderWatchEvent = function(event, ...)
      if ctx.leaderWatchController and type(ctx.leaderWatchController.HandleEvent) == "function" then
        ctx.leaderWatchController.HandleEvent(event, ...)
      end
    end,
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
      teleport = ctx.teleportUIController,
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
      applyDBSettings = ctx.applyDBSettings,
      restoreLayoutState = ctx.restoreLayoutState,
      updateCountdownCancelButton = ctx.updateCountdownCancelButton,
      restoreBgAlpha = ctx.RestoreBgAlpha,
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
      updateCdTracker = function(opts)
        if type(ctx.UpdateCdTracker) == "function" then
          ctx.UpdateCdTracker(opts)
        end
      end,
    },
  }
end

function ControllerWiring.CreateEventHandlersControllerFromContext(eventHandlersModule, ctx)
  return ControllerWiring.CreateEventHandlersController(eventHandlersModule, BuildEventHandlersDepsFromContext(ctx))
end
