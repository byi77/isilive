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
  counters.readyCheckRefreshes = counters.readyCheckRefreshes or 0
  counters.pendingSets = counters.pendingSets or 0
  counters.acks = counters.acks or 0
  counters.refreshResponses = counters.refreshResponses or 0
  return counters
end

local function BuildEventHandlersBaseOptions(entryRef, counters)
  local pendingPostChallengeRefresh = nil
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
    getPendingPostChallengeRefresh = function()
      return pendingPostChallengeRefresh
    end,
    setPendingPostChallengeRefresh = function(value)
      pendingPostChallengeRefresh = value
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
    refreshReadyCheckUI = function()
      counters.readyCheckRefreshes = counters.readyCheckRefreshes + 1
    end,
    setMainFrameVisible = function(_visible) end,
    shouldShowMainFrameOnStartup = function()
      return true
    end,
    shouldAutoOpenMainFrameOnKeyEnd = function()
      return true
    end,
    updateLeaderButtons = function() end,
    updateStatusLine = function() end,
    sendIsiLiveHello = function(_force, _source) end,
    sendLibKeystonePartyData = function(_force)
      return false
    end,
    notifyPostChallengeSync = function() end,
    sendOwnKeySnapshot = function(_force) end,
    sendOwnBackgroundSnapshot = function(_source) end,
    sendOwnTargetSnapshot = function(_force, _source, _allowHidden) end,
    sendOwnKickState = function() end,
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
    getUnitRole = function(_unit)
      return nil
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
    showCombatAnnounce = function(_info) end,
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
    getReadyCheckDeclinedUntil = function(_unit)
      return nil
    end,
    getReadyCheckReadyUntil = function(_unit)
      return nil
    end,
    setReadyCheckReadyUntil = function(_unit, _value) end,
    setReadyCheckDeclinedUntil = function(_unit, _value) end,
    clearAllReadyCheckReady = function() end,
    clearAllReadyCheckDeclined = function() end,
    clearExpiredReadyCheckReady = function(_now)
      return false
    end,
    clearExpiredReadyCheckDeclined = function(_now)
      return false
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

-- Strict Secret Value stand-in. Like the client value it lies to `type()`
-- (reports `typeName`, default "number") and raises on ordering, arithmetic,
-- concatenation, length, indexing and calls. Lua cannot make `== nil`, `~= nil`
-- or a plain table-key lookup raise, so those stay invisible here; they are
-- pinned by tools/check_secret_value_guards.lua or source checks instead.
-- Returns the value plus the globals (`issecretvalue`, `type`) to install via
-- WithGlobals for the duration of the test.
function Fixtures.MakeStrictSecret(typeName)
  typeName = typeName or "number"
  local function Raise()
    error("attempt to perform an operation on a secret value", 2)
  end
  local secret = setmetatable({}, {
    __lt = Raise,
    __le = Raise,
    __eq = Raise,
    __add = Raise,
    __sub = Raise,
    __mul = Raise,
    __div = Raise,
    __mod = Raise,
    __unm = Raise,
    __concat = Raise,
    __len = Raise,
    __index = Raise,
    __newindex = Raise,
    __call = Raise,
    __tostring = Raise,
  })
  local rawType = type
  local globals = {
    issecretvalue = function(value)
      return rawequal(value, secret)
    end,
    type = function(value)
      if rawequal(value, secret) then
        return typeName
      end
      return rawType(value)
    end,
  }
  return secret, globals
end

return Fixtures
