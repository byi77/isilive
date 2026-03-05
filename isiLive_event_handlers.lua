local _, addonTable = ...

addonTable = addonTable or {}

local EventHandlers = {}
addonTable.EventHandlers = EventHandlers

local POST_RUN_REFRESH_INITIAL_DELAY_SECONDS = 5
local POST_RUN_REFRESH_RETRIES = 5
local POST_RUN_REFRESH_RETRY_DELAY_SECONDS = 1
local POST_RUN_FOLLOWUP_REFRESH_DELAY_SECONDS = 6
local POST_RUN_FOLLOWUP_REFRESH_ATTEMPTS = 2
local NEGATIVE_STATUS_PENDING_GRACE_SECONDS = 20

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

  ctx.isInGroup = RequireFunction(opts.isInGroup, "isInGroup")
  ctx.isInPartyInstance = OptionalFunction(opts.isInPartyInstance, function()
    if type(GetInstanceInfo) ~= "function" then
      return false
    end
    local _, instanceType = GetInstanceInfo()
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
  ctx.updateCountdownCancelButton = RequireFunction(opts.updateCountdownCancelButton, "updateCountdownCancelButton")
  ctx.getUnitNameAndRealm = RequireFunction(opts.getUnitNameAndRealm, "getUnitNameAndRealm")
  ctx.markIsiLiveUser = RequireFunction(opts.markIsiLiveUser, "markIsiLiveUser")
  ctx.maybeShowNonMythicDungeonEntryNotice =
    RequireFunction(opts.maybeShowNonMythicDungeonEntryNotice, "maybeShowNonMythicDungeonEntryNotice")
  ctx.checkIfEnteredTargetDungeon = RequireFunction(opts.checkIfEnteredTargetDungeon, "checkIfEnteredTargetDungeon")
  ctx.captureRioBaselineSnapshot = OptionalFunction(opts.captureRioBaselineSnapshot, function() end)
  ctx.restoreRioBaseline = OptionalFunction(opts.restoreRioBaseline, function() end)
  ctx.enableRioDeltaDisplay = OptionalFunction(opts.enableRioDeltaDisplay, function() end)
  ctx.timerAfter = OptionalFunction(opts.timerAfter, nil)
  ctx.getTime = OptionalFunction(opts.getTime, GetTime)

  ctx.getPendingBindingApply = RequireFunction(opts.getPendingBindingApply, "getPendingBindingApply")
  ctx.getPendingMainFrameHeight = RequireFunction(opts.getPendingMainFrameHeight, "getPendingMainFrameHeight")
  ctx.setMainFrameHeightSafe = RequireFunction(opts.setMainFrameHeightSafe, "setMainFrameHeightSafe")
  ctx.tryRestoreCenterNoticeTeleportButton =
    RequireFunction(opts.tryRestoreCenterNoticeTeleportButton, "tryRestoreCenterNoticeTeleportButton")

  ctx.handleOwnedKeyRefresh = RequireFunction(opts.handleOwnedKeyRefresh, "handleOwnedKeyRefresh")
  ctx.isMainFrameShown = RequireFunction(opts.isMainFrameShown, "isMainFrameShown")
  ctx.onInspectReady = RequireFunction(opts.onInspectReady, "onInspectReady")

  ctx.processAddonMessage = RequireFunction(opts.processAddonMessage, "processAddonMessage")
  ctx.sendAck = RequireFunction(opts.sendAck, "sendAck")
  ctx.forEachRosterInfo = RequireFunction(opts.forEachRosterInfo, "forEachRosterInfo")
  ctx.isSyncUserKnown = RequireFunction(opts.isSyncUserKnown, "isSyncUserKnown")
  ctx.applyKnownKeyToRosterEntry = RequireFunction(opts.applyKnownKeyToRosterEntry, "applyKnownKeyToRosterEntry")
  ctx.runFullRefresh = RequireFunction(opts.runFullRefresh, "runFullRefresh")

  return ctx
end

local function HasActiveListing(entryInfo)
  if type(entryInfo) ~= "table" then
    return false
  end

  local active = entryInfo.active
  if type(active) == "boolean" then
    return active
  end

  if tonumber(entryInfo.activityID) or tonumber(entryInfo.primaryActivityID) or tonumber(entryInfo.mapID) then
    return true
  end

  if type(entryInfo.activityIDs) == "table" and next(entryInfo.activityIDs) ~= nil then
    return true
  end

  if type(entryInfo.name) == "string" and entryInfo.name ~= "" then
    return true
  end
  if type(entryInfo.activityName) == "string" and entryInfo.activityName ~= "" then
    return true
  end
  if type(entryInfo.title) == "string" and entryInfo.title ~= "" then
    return true
  end

  return false
end

local function ResetDamageMeterIfAvailable()
  local damageMeterAPI = _G.C_DamageMeter
  if
    not (
      type(damageMeterAPI) == "table"
      and type(damageMeterAPI.IsDamageMeterAvailable) == "function"
      and type(damageMeterAPI.ResetAllCombatSessions) == "function"
    )
  then
    return false
  end

  local okAvailable, isAvailable = pcall(damageMeterAPI.IsDamageMeterAvailable)
  if not okAvailable or not isAvailable then
    return false
  end

  local okReset = pcall(damageMeterAPI.ResetAllCombatSessions)
  return okReset
end

local function HandleGroupRosterUpdateEvent(ctx, _self)
  if ctx.isInGroup() and (ctx.isTestMode() or ctx.isTestAllMode()) then
    ctx.exitTestMode()
    return
  end

  ctx.handleGroupRosterUpdate()
end

local function ShouldPreservePendingQueueJoinInfoOnNegativeStatus(ctx)
  local pending = ctx.getPendingQueueJoinInfo()
  if type(pending) ~= "table" then
    return false
  end

  local capturedAt = tonumber(pending.capturedAt)
  if not capturedAt then
    return true
  end

  if type(ctx.getTime) ~= "function" then
    return true
  end

  local now = tonumber(ctx.getTime())
  if not now then
    return true
  end

  return (now - capturedAt) <= NEGATIVE_STATUS_PENDING_GRACE_SECONDS
end

local function HandleLfgListApplicationStatusUpdatedEvent(ctx, _self, ...)
  if ctx.isInChallengeMode() then
    return
  end
  if ctx.isTestMode() or ctx.isTestAllMode() then
    ctx.exitTestMode()
  end
  if ctx.isNegativeApplicationStatusEvent(...) then
    if not ShouldPreservePendingQueueJoinInfoOnNegativeStatus(ctx) then
      ctx.setPendingQueueJoinInfo(nil)
    end
    local entryInfo = ctx.getNormalizedActiveEntryInfo()
    -- Negative application updates can still arrive after a successful join
    -- (for example when the group fills and other applications get declined).
    -- While grouped, keep the latest queue target so portal highlight remains stable.
    if not HasActiveListing(entryInfo) and not ctx.isInGroup() then
      ctx.clearLatestQueueTarget()
    end
    ctx.updateMPlusTeleportButton()
    return
  end
  ctx.captureQueueJoinCandidate(...)
end

local function HandleLfgListSearchResultUpdatedEvent(ctx, _self, ...)
  if ctx.isInChallengeMode() then
    return
  end
  ctx.captureQueueJoinCandidate(...)
end

local function HandleLfgListActiveEntryUpdateEvent(ctx, _self)
  if ctx.isInChallengeMode() then
    return
  end
  local entryInfo = ctx.getNormalizedActiveEntryInfo()
  local hadActiveJoinedKey = ctx.getActiveJoinedKeyMapID() ~= nil
  if HasActiveListing(entryInfo) then
    if ctx.isTestMode() or ctx.isTestAllMode() then
      ctx.exitTestMode()
    end
    ctx.setActiveJoinedKeyMapID(nil)
    -- Active listing detected: clear pending info (old applications) only.
    -- Keep latest* vars so self-hosted listings stay highlighted.
    ctx.setPendingQueueJoinInfo(nil)
  else
    -- No active listing anymore: clear pending info.
    ctx.setPendingQueueJoinInfo(nil)
  end
  ctx.updateMPlusTeleportButton()
  if hadActiveJoinedKey and not ctx.getActiveJoinedKeyMapID() then
    ctx.updateUI()
  end
end

local function HandleChallengeModeStartEvent(ctx, _self)
  ResetDamageMeterIfAvailable()
  ctx.captureRioBaselineSnapshot()
  ctx.setActiveJoinedKeyMapID(nil)
  ctx.checkIfEnteredTargetDungeon()
  ctx.setMainFrameVisible(false)
  ctx.updateLeaderButtons()
  ctx.updateStatusLine()
  ctx.updateMPlusTeleportButton()
end

local function RefreshRosterAfterRunStateChange(ctx, self)
  if ctx.isInGroup() then
    local onEventHandler = self and self.GetScript and self:GetScript("OnEvent") or nil
    if onEventHandler then
      onEventHandler(self, "GROUP_ROSTER_UPDATE")
      return
    end
    ctx.updateUI()
    return
  end

  ctx.updateLeaderButtons()
end

local function RunDelayedPostChallengeRefresh(ctx, self, retriesRemaining, followUpRefreshesRemaining)
  if not ctx.isInGroup() then
    ctx.enableRioDeltaDisplay()
    return
  end

  local refreshed = ctx.runFullRefresh() ~= false
  if refreshed then
    ctx.enableRioDeltaDisplay()
    RefreshRosterAfterRunStateChange(ctx, self)
    if followUpRefreshesRemaining > 0 and ctx.timerAfter then
      ctx.timerAfter(POST_RUN_FOLLOWUP_REFRESH_DELAY_SECONDS, function()
        RunDelayedPostChallengeRefresh(ctx, self, 0, followUpRefreshesRemaining - 1)
      end)
    end
    return
  end

  if retriesRemaining > 0 and ctx.timerAfter then
    ctx.timerAfter(POST_RUN_REFRESH_RETRY_DELAY_SECONDS, function()
      RunDelayedPostChallengeRefresh(ctx, self, retriesRemaining - 1, followUpRefreshesRemaining)
    end)
    return
  end

  ctx.enableRioDeltaDisplay()
  RefreshRosterAfterRunStateChange(ctx, self)
end

local function HandleChallengeModeCompletedOrResetEvent(ctx, self)
  if ctx.isInGroup() then
    ctx.setMainFrameVisible(true)
  end
  RefreshRosterAfterRunStateChange(ctx, self)
  ctx.updateStatusLine()
  ctx.sendOwnKeySnapshot(true)
  if ctx.timerAfter then
    ctx.timerAfter(POST_RUN_REFRESH_INITIAL_DELAY_SECONDS, function()
      RunDelayedPostChallengeRefresh(ctx, self, POST_RUN_REFRESH_RETRIES, POST_RUN_FOLLOWUP_REFRESH_ATTEMPTS)
    end)
    return
  end

  RunDelayedPostChallengeRefresh(ctx, self, 0, 0)
end

local function HandleAddonLoadedEvent(ctx, _self, loadedAddon)
  if loadedAddon ~= ctx.addonName then
    return
  end

  -- Initialize DB
  IsiLiveDB = IsiLiveDB or {}
  IsiLiveDB.position = IsiLiveDB.position or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
  IsiLiveDB.locale = ctx.resolveLocaleTag(IsiLiveDB.locale or ctx.defaultLocale)
  ctx.setLocaleTable(ctx.locales[IsiLiveDB.locale] or ctx.locales.enUS)
  if IsiLiveDB.queueDebug == nil then
    IsiLiveDB.queueDebug = false
  end
  if IsiLiveDB.runtimeLogEnabled == nil then
    IsiLiveDB.runtimeLogEnabled = false
  end
  ctx.ensureQueueDebugStorage()
  ctx.setQueueDebugEnabled(IsiLiveDB.queueDebug)
  ctx.ensureRuntimeLogStorage()
  ctx.setRuntimeLogEnabled(IsiLiveDB.runtimeLogEnabled)
  ctx.restoreRioBaseline()

  -- Restore position
  local mainFrame = ctx.getMainFrame()
  local pos = IsiLiveDB.position
  if mainFrame and mainFrame.ClearAllPoints and mainFrame.SetPoint then
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
  end
  ctx.registerIsiLiveSyncPrefix()
  ctx.applyHotkeyBindings()
  ctx.startBindingWatchdog()
  ctx.applyLocalizationToUI()
  ctx.updateCountdownCancelButton()
  ctx.updateLeaderButtons()
end

local function HandlePlayerLoginEvent(ctx, _self)
  ctx.registerIsiLiveSyncPrefix()
  local playerName, playerRealm = ctx.getUnitNameAndRealm("player")
  ctx.markIsiLiveUser(playerName, playerRealm)
  ctx.applyHotkeyBindings()
  ctx.startBindingWatchdog()
end

local function HandlePlayerEnteringWorldEvent(ctx, _self)
  ctx.applyHotkeyBindings()
  ctx.startBindingWatchdog()
  if ctx.timerAfter then
    ctx.timerAfter(1, ctx.applyHotkeyBindings)
    ctx.timerAfter(3, ctx.applyHotkeyBindings)
  end
  ctx.sendOwnKeySnapshot(true)
  ctx.maybeShowNonMythicDungeonEntryNotice()
  ctx.updateStatusLine()
  ctx.checkIfEnteredTargetDungeon()

  local inPartyInstance = ctx.isInPartyInstance() and true or false
  local wasInPartyInstance = ctx.wasInPartyInstance
  ctx.wasInPartyInstance = inPartyInstance
  if wasInPartyInstance ~= nil and not wasInPartyInstance and inPartyInstance and not ctx.isInChallengeMode() then
    ctx.setMainFrameVisible(true)
  end
end

local function HandleUpdateBindingsEvent(ctx, _self)
  ctx.applyHotkeyBindings()
end

local function HandlePlayerRegenEnabledEvent(ctx, _self)
  if ctx.getPendingBindingApply() then
    ctx.applyHotkeyBindings()
  end
  local pendingMainFrameHeight = ctx.getPendingMainFrameHeight()
  if pendingMainFrameHeight then
    ctx.setMainFrameHeightSafe(pendingMainFrameHeight)
  end
  if ctx.isMainFrameShown() then
    ctx.updateMPlusTeleportButton()
    ctx.tryRestoreCenterNoticeTeleportButton()
  end
end

local function HandleInstanceContextChangedEvent(ctx, _self)
  ctx.updateStatusLine()
  ctx.maybeShowNonMythicDungeonEntryNotice()
  ctx.checkIfEnteredTargetDungeon()
end

local function HandleOwnedKeyContextEvent(ctx, _self)
  ctx.updateStatusLine()
  ctx.handleOwnedKeyRefresh()
  ctx.maybeShowNonMythicDungeonEntryNotice()
  ctx.checkIfEnteredTargetDungeon()
end

local function HandleInspectReadyEvent(ctx, _self, guid)
  if not ctx.isMainFrameShown() then
    return
  end

  if ctx.onInspectReady(guid) then
    ctx.updateUI()
  end
end

local function HandleChatMsgAddonEvent(ctx, _self, prefix, message, _channel, sender)
  local syncResult = ctx.processAddonMessage(prefix, message, sender)
  if not syncResult then
    return
  end

  if syncResult.shouldAck then
    ctx.sendAck(syncResult.sender)
  end

  local changed = false
  ctx.forEachRosterInfo(function(info)
    if not info.hasIsiLive and ctx.isSyncUserKnown(info.name, info.realm) then
      info.hasIsiLive = true
      changed = true
    end
    if ctx.applyKnownKeyToRosterEntry(info) then
      changed = true
    end
  end)
  if changed then
    ctx.updateUI()
  end
end

local function HandleSpellUpdateCooldownEvent(ctx, _self)
  ctx.updateMPlusTeleportButton()
end

local EVENT_HANDLERS = {
  GROUP_ROSTER_UPDATE = HandleGroupRosterUpdateEvent,
  LFG_LIST_APPLICATION_STATUS_UPDATED = HandleLfgListApplicationStatusUpdatedEvent,
  LFG_LIST_SEARCH_RESULT_UPDATED = HandleLfgListSearchResultUpdatedEvent,
  LFG_LIST_ACTIVE_ENTRY_UPDATE = HandleLfgListActiveEntryUpdateEvent,
  CHALLENGE_MODE_START = HandleChallengeModeStartEvent,
  CHALLENGE_MODE_COMPLETED = HandleChallengeModeCompletedOrResetEvent,
  CHALLENGE_MODE_RESET = HandleChallengeModeCompletedOrResetEvent,
  ADDON_LOADED = HandleAddonLoadedEvent,
  PLAYER_LOGIN = HandlePlayerLoginEvent,
  PLAYER_ENTERING_WORLD = HandlePlayerEnteringWorldEvent,
  UPDATE_BINDINGS = HandleUpdateBindingsEvent,
  PLAYER_REGEN_ENABLED = HandlePlayerRegenEnabledEvent,
  PLAYER_DIFFICULTY_CHANGED = HandleInstanceContextChangedEvent,
  ZONE_CHANGED_NEW_AREA = HandleInstanceContextChangedEvent,
  UPDATE_INSTANCE_INFO = HandleInstanceContextChangedEvent,
  BAG_UPDATE_DELAYED = HandleOwnedKeyContextEvent,
  CHALLENGE_MODE_MAPS_UPDATE = HandleOwnedKeyContextEvent,
  INSPECT_READY = HandleInspectReadyEvent,
  CHAT_MSG_ADDON = HandleChatMsgAddonEvent,
  SPELL_UPDATE_COOLDOWN = HandleSpellUpdateCooldownEvent,
}

function EventHandlers.CreateController(opts)
  opts = opts or {}

  local ctx = BuildContext(opts)

  assert(type(ctx.addonName) == "string" and ctx.addonName ~= "", "isiLive: EventHandlers requires addonName")
  assert(
    type(ctx.defaultLocale) == "string" and ctx.defaultLocale ~= "",
    "isiLive: EventHandlers requires defaultLocale"
  )

  local controller = {}

  function controller.Dispatch(self, event, ...)
    local handler = EVENT_HANDLERS[event]
    if handler then
      handler(ctx, self, ...)
    end
  end

  return controller
end
