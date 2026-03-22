local _, addonTable = ...

addonTable = addonTable or {}

local EventHandlers = {}
addonTable.EventHandlers = EventHandlers
local QueueLifecycle = addonTable.EventHandlersQueueLifecycle
local ChallengeLifecycle = addonTable.EventHandlersChallengeLifecycle
local RuntimeLifecycle = addonTable.EventHandlersRuntimeLifecycle

local function RequireFunction(value, name)
  assert(type(value) == "function", "isiLive: EventHandlers requires " .. name)
  return value
end

local function OptionalFunction(value, fallback)
  if type(value) == "function" then
    return value
  end
  return fallback
end

local function BuildContext(opts)
  local ctx = {}

  ctx.addonName = opts.addonName
  ctx.defaultLocale = opts.defaultLocale
  ctx.locales = opts.locales or {}

  ctx.resolveLocaleTag = RequireFunction(opts.resolveLocaleTag, "resolveLocaleTag")
  ctx.setLocaleTable = RequireFunction(opts.setLocaleTable, "setLocaleTable")

  ctx.isRosterCollapsed = RequireFunction(opts.isRosterCollapsed, "isRosterCollapsed")

  ctx.isInGroup = RequireFunction(opts.isInGroup, "isInGroup")
  ctx.isInPartyInstance = OptionalFunction(opts.isInPartyInstance, function()
    local ok, _, instanceType = pcall(GetInstanceInfo)
    if not ok then
      return false
    end
    return instanceType == "party"
  end)
  ctx.wasInPartyInstance = nil
  ctx.isTestMode = RequireFunction(opts.isTestMode, "isTestMode")
  ctx.isTestAllMode = RequireFunction(opts.isTestAllMode, "isTestAllMode")
  ctx.exitTestMode = RequireFunction(opts.exitTestMode, "exitTestMode")
  ctx.handleGroupRosterUpdate = RequireFunction(opts.handleGroupRosterUpdate, "handleGroupRosterUpdate")

  ctx.isInChallengeMode = RequireFunction(opts.isInChallengeMode, "isInChallengeMode")
  ctx.isNegativeApplicationStatusEvent =
    RequireFunction(opts.isNegativeApplicationStatusEvent, "isNegativeApplicationStatusEvent")
  ctx.getNormalizedActiveEntryInfo = RequireFunction(opts.getNormalizedActiveEntryInfo, "getNormalizedActiveEntryInfo")
  ctx.setPendingQueueJoinInfo = RequireFunction(opts.setPendingQueueJoinInfo, "setPendingQueueJoinInfo")
  ctx.getPendingQueueJoinInfo = OptionalFunction(opts.getPendingQueueJoinInfo, function()
    return nil
  end)
  ctx.clearLatestQueueTarget = RequireFunction(opts.clearLatestQueueTarget, "clearLatestQueueTarget")
  ctx.updateMPlusTeleportButton = RequireFunction(opts.updateMPlusTeleportButton, "updateMPlusTeleportButton")
  ctx.captureQueueJoinCandidate = RequireFunction(opts.captureQueueJoinCandidate, "captureQueueJoinCandidate")
  ctx.getActiveJoinedKeyMapID = RequireFunction(opts.getActiveJoinedKeyMapID, "getActiveJoinedKeyMapID")
  ctx.setActiveJoinedKeyMapID = RequireFunction(opts.setActiveJoinedKeyMapID, "setActiveJoinedKeyMapID")
  ctx.updateUI = RequireFunction(opts.updateUI, "updateUI")

  ctx.setMainFrameVisible = RequireFunction(opts.setMainFrameVisible, "setMainFrameVisible")
  ctx.updateLeaderButtons = RequireFunction(opts.updateLeaderButtons, "updateLeaderButtons")
  ctx.updateStatusLine = RequireFunction(opts.updateStatusLine, "updateStatusLine")
  ctx.sendOwnKeySnapshot = RequireFunction(opts.sendOwnKeySnapshot, "sendOwnKeySnapshot")

  ctx.ensureQueueDebugStorage = RequireFunction(opts.ensureQueueDebugStorage, "ensureQueueDebugStorage")
  ctx.setQueueDebugEnabled = RequireFunction(opts.setQueueDebugEnabled, "setQueueDebugEnabled")
  ctx.ensureRuntimeLogStorage = OptionalFunction(opts.ensureRuntimeLogStorage, function() end)
  ctx.setRuntimeLogEnabled = OptionalFunction(opts.setRuntimeLogEnabled, function(_enabled) end)
  ctx.getMainFrame = RequireFunction(opts.getMainFrame, "getMainFrame")
  ctx.registerIsiLiveSyncPrefix = RequireFunction(opts.registerIsiLiveSyncPrefix, "registerIsiLiveSyncPrefix")
  ctx.applyHotkeyBindings = RequireFunction(opts.applyHotkeyBindings, "applyHotkeyBindings")
  ctx.startBindingWatchdog = RequireFunction(opts.startBindingWatchdog, "startBindingWatchdog")
  ctx.applyLocalizationToUI = RequireFunction(opts.applyLocalizationToUI, "applyLocalizationToUI")
  ctx.restoreLayoutState = RequireFunction(opts.restoreLayoutState, "restoreLayoutState")
  ctx.updateCountdownCancelButton = RequireFunction(opts.updateCountdownCancelButton, "updateCountdownCancelButton")
  ctx.getUnitNameAndRealm = RequireFunction(opts.getUnitNameAndRealm, "getUnitNameAndRealm")
  ctx.markIsiLiveUser = RequireFunction(opts.markIsiLiveUser, "markIsiLiveUser")
  ctx.maybeShowNonMythicDungeonEntryNotice =
    RequireFunction(opts.maybeShowNonMythicDungeonEntryNotice, "maybeShowNonMythicDungeonEntryNotice")
  ctx.maybeShowPortalNavigatorNotice =
    RequireFunction(opts.maybeShowPortalNavigatorNotice, "maybeShowPortalNavigatorNotice")
  ctx.checkIfEnteredTargetDungeon = RequireFunction(opts.checkIfEnteredTargetDungeon, "checkIfEnteredTargetDungeon")
  ctx.captureRioBaselineSnapshot = OptionalFunction(opts.captureRioBaselineSnapshot, function() end)
  ctx.restoreRioBaseline = OptionalFunction(opts.restoreRioBaseline, function() end)
  ctx.enableRioDeltaDisplay = OptionalFunction(opts.enableRioDeltaDisplay, function() end)
  ctx.updateCdTracker = OptionalFunction(opts.updateCdTracker, function() end)
  ctx.timerAfter = OptionalFunction(opts.timerAfter, nil)
  ctx.getTime = OptionalFunction(opts.getTime, GetTime)

  ctx.getPendingBindingApply = RequireFunction(opts.getPendingBindingApply, "getPendingBindingApply")
  ctx.getPendingMainFrameVisible = OptionalFunction(opts.getPendingMainFrameVisible, function()
    return nil
  end)
  ctx.getPendingMainFrameHeight = RequireFunction(opts.getPendingMainFrameHeight, "getPendingMainFrameHeight")
  ctx.setMainFrameHeightSafe = RequireFunction(opts.setMainFrameHeightSafe, "setMainFrameHeightSafe")
  ctx.tryRestoreCenterNoticeTeleportButton =
    RequireFunction(opts.tryRestoreCenterNoticeTeleportButton, "tryRestoreCenterNoticeTeleportButton")

  ctx.handleOwnedKeyRefresh = RequireFunction(opts.handleOwnedKeyRefresh, "handleOwnedKeyRefresh")
  ctx.isMainFrameShown = RequireFunction(opts.isMainFrameShown, "isMainFrameShown")
  ctx.onInspectReady = RequireFunction(opts.onInspectReady, "onInspectReady")

  ctx.processAddonMessage = RequireFunction(opts.processAddonMessage, "processAddonMessage")
  ctx.sendAck = RequireFunction(opts.sendAck, "sendAck")
  ctx.sendRefreshResponse = RequireFunction(opts.sendRefreshResponse, "sendRefreshResponse")
  ctx.forEachRosterInfo = RequireFunction(opts.forEachRosterInfo, "forEachRosterInfo")
  ctx.isSyncUserKnown = RequireFunction(opts.isSyncUserKnown, "isSyncUserKnown")
  ctx.applyKnownKeyToRosterEntry = RequireFunction(opts.applyKnownKeyToRosterEntry, "applyKnownKeyToRosterEntry")
  ctx.runFullRefresh = RequireFunction(opts.runFullRefresh, "runFullRefresh")
  ctx.recordRun = OptionalFunction(opts.recordRun, function() end)
  ctx.getRoster = OptionalFunction(opts.getRoster, function()
    return {}
  end)
  ctx.setReadyCheckActive = OptionalFunction(opts.setReadyCheckActive, function(_value) end)
  ctx.isReadyCheckActive = OptionalFunction(opts.isReadyCheckActive, function()
    return false
  end)
  ctx.lastRecordedRunSignature = nil
  ctx.lastRecordedRunCaptured = false
  ctx.pendingRecordedRunRetrySignature = nil
  ctx.activeMythicZeroMapID = nil
  ctx.activeMythicZeroRosterSnapshot = nil
  ctx.pendingMythicZeroRunCapture = nil

  return ctx
end

local function RequireLifecycleModule(moduleValue, name)
  assert(type(moduleValue) == "table", "isiLive: EventHandlers requires module " .. name)
  assert(type(moduleValue.BuildHandlers) == "function", "isiLive: EventHandlers requires " .. name .. ".BuildHandlers")
  return moduleValue
end

local function AppendHandlers(target, source)
  for eventName, handler in pairs(source or {}) do
    target[eventName] = handler
  end
end

local function BuildHandlerMap(ctx)
  local handlers = {}

  AppendHandlers(handlers, RequireLifecycleModule(RuntimeLifecycle, "EventHandlersRuntimeLifecycle").BuildHandlers(ctx))
  AppendHandlers(handlers, RequireLifecycleModule(QueueLifecycle, "EventHandlersQueueLifecycle").BuildHandlers(ctx))
  AppendHandlers(
    handlers,
    RequireLifecycleModule(ChallengeLifecycle, "EventHandlersChallengeLifecycle").BuildHandlers(ctx)
  )

  return handlers
end

function EventHandlers.CreateController(opts)
  opts = opts or {}

  local ctx = BuildContext(opts)
  local eventHandlers = BuildHandlerMap(ctx)

  assert(type(ctx.addonName) == "string" and ctx.addonName ~= "", "isiLive: EventHandlers requires addonName")
  assert(
    type(ctx.defaultLocale) == "string" and ctx.defaultLocale ~= "",
    "isiLive: EventHandlers requires defaultLocale"
  )

  local controller = {}

  function controller.Dispatch(self, event, ...)
    local handler = eventHandlers[event]
    if handler then
      handler(self, ...)
    end
  end

  return controller
end
