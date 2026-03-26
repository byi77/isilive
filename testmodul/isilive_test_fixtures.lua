local Fixtures = {}

local function Merge(base, overrides)
  local merged = {}
  for key, value in pairs(base or {}) do
    merged[key] = value
  end
  for key, value in pairs(overrides or {}) do
    merged[key] = value
  end
  return merged
end

local function EnsureEventHandlerCounters(counters)
  counters = counters or {}
  counters.clears = counters.clears or 0
  counters.updates = counters.updates or 0
  counters.captures = counters.captures or 0
  counters.exits = counters.exits or 0
  counters.rosterUpdates = counters.rosterUpdates or 0
  counters.uiUpdates = counters.uiUpdates or 0
  counters.pendingSets = counters.pendingSets or 0
  counters.acks = counters.acks or 0
  counters.refreshResponses = counters.refreshResponses or 0
  return counters
end

local function BuildEventHandlersBaseOptions(entryRef, counters)
  return {
    addonName = "isiLive",
    defaultLocale = "enUS",
    locales = { enUS = {} },
    resolveLocaleTag = function(tag)
      return tag
    end,
    setLocaleTable = function(_table) end,
    isRosterCollapsed = function()
      return false
    end,
    isInGroup = function()
      return true
    end,
    isTestMode = function()
      return false
    end,
    isTestAllMode = function()
      return false
    end,
    exitTestMode = function()
      counters.exits = counters.exits + 1
    end,
    handleGroupRosterUpdate = function()
      counters.rosterUpdates = counters.rosterUpdates + 1
    end,
    isInChallengeMode = function()
      return false
    end,
    isNegativeApplicationStatusEvent = function()
      return true
    end,
    getNormalizedActiveEntryInfo = function()
      return entryRef.value
    end,
    setPendingQueueJoinInfo = function(_value)
      counters.pendingSets = counters.pendingSets + 1
    end,
    clearLatestQueueTarget = function()
      counters.clears = counters.clears + 1
    end,
    updateMPlusTeleportButton = function()
      counters.updates = counters.updates + 1
    end,
    captureQueueJoinCandidate = function()
      counters.captures = counters.captures + 1
    end,
    getActiveJoinedKeyMapID = function()
      return nil
    end,
    setActiveJoinedKeyMapID = function(_value) end,
    updateUI = function()
      counters.uiUpdates = counters.uiUpdates + 1
    end,
    setMainFrameVisible = function(_visible) end,
    updateLeaderButtons = function() end,
    updateStatusLine = function() end,
    sendOwnKeySnapshot = function(_force) end,
    sendOwnTargetSnapshot = function(_force, _source, _allowHidden) end,
    ensureQueueDebugStorage = function() end,
    setQueueDebugEnabled = function(_enabled) end,
    ensureRuntimeLogStorage = function() end,
    setRuntimeLogEnabled = function(_enabled) end,
    getMainFrame = function()
      return {
        ClearAllPoints = function() end,
        SetPoint = function() end,
      }
    end,
    registerIsiLiveSyncPrefix = function() end,
    applyHotkeyBindings = function() end,
    startBindingWatchdog = function() end,
    applyLocalizationToUI = function() end,
    restoreLayoutState = function() end,
    updateCountdownCancelButton = function() end,
    getUnitNameAndRealm = function()
      return "player", "realm"
    end,
    markIsiLiveUser = function() end,
    maybeShowNonMythicDungeonEntryNotice = function() end,
    maybeShowPortalNavigatorNotice = function() end,
    checkIfEnteredTargetDungeon = function() end,
    getPendingBindingApply = function()
      return false
    end,
    getPendingMainFrameHeight = function()
      return nil
    end,
    setMainFrameHeightSafe = function(_height) end,
    getPendingMainFrameWidth = function()
      return nil
    end,
    setMainFrameWidthSafe = function(_width) end,
    tryRestoreCenterNoticeTeleportButton = function() end,
    handleOwnedKeyRefresh = function() end,
    isMainFrameShown = function()
      return true
    end,
    onInspectReady = function(_guid)
      return false
    end,
    processAddonMessage = function(_prefix, _message, _sender)
      return nil
    end,
    sendAck = function(_sender)
      counters.acks = counters.acks + 1
    end,
    sendRefreshResponse = function()
      counters.refreshResponses = counters.refreshResponses + 1
      return true
    end,
    forEachRosterInfo = function(_visitor) end,
    isSyncUserKnown = function(_name, _realm)
      return false
    end,
    applyKnownKeyToRosterEntry = function(_info)
      return false
    end,
    runFullRefresh = function() end,
    getRoster = function()
      return {}
    end,
    restoreRioBaseline = function() end,
  }
end

function Fixtures.BuildEventHandlersController(eventHandlersModule, entryRef, counters, overrides)
  entryRef = entryRef or { value = nil }
  counters = EnsureEventHandlerCounters(counters)
  local baseOptions = BuildEventHandlersBaseOptions(entryRef, counters)
  local options = Merge(baseOptions, overrides)
  return eventHandlersModule.CreateController(options), counters, entryRef
end

function Fixtures.BuildQueueFlowController(queueFlowModule, overrides)
  local state = {
    pending = nil,
    prints = {},
  }

  local baseOptions = {
    getL = function()
      return {
        UNKNOWN_GROUP = "Unknown",
        JOINED_FROM_QUEUE = "Joined from queue: %s",
        CHAT_QUEUE_PREFIX = "Queue Join",
      }
    end,
    getPendingQueueJoinInfo = function()
      return state.pending
    end,
    setPendingQueueJoinInfo = function(value)
      state.pending = value
    end,
    printFn = function(message)
      table.insert(state.prints, tostring(message))
    end,
    isInChallengeMode = function()
      return false
    end,
    isInGroup = function()
      return false
    end,
    isPlayerLeader = function()
      return false
    end,
    getTimeFn = function()
      return 42
    end,
  }

  local options = Merge(baseOptions, overrides)
  local controller = queueFlowModule.CreateController(options)
  return controller, state, options
end

return Fixtures
