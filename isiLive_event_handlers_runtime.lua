local _, addonTable = ...

addonTable = addonTable or {}

local RuntimeLifecycle = {}
addonTable.EventHandlersRuntimeLifecycle = RuntimeLifecycle

local TRACKED_NON_CHALLENGE_PARTY_DIFFICULTY_IDS = {
  [1] = true,
  [2] = true,
  [174] = true,
  [8] = true,
  [23] = true,
  [24] = true,
  [167] = true,
}
local NON_CHALLENGE_RUN_CAPTURE_RETRIES = 5
local NON_CHALLENGE_RUN_CAPTURE_RETRY_DELAY_SECONDS = 1

local function ResolveTrackedMythicZeroMapID()
  local okInstance, _, _, _, _, _, _, rawInstanceMapID = pcall(GetInstanceInfo)
  local instanceMapID = okInstance and tonumber(rawInstanceMapID) or nil
  if instanceMapID and instanceMapID > 0 then
    return math.floor(instanceMapID)
  end

  local mapApi = rawget(_G, "C_Map")
  local getBestMapForUnit = mapApi and rawget(mapApi, "GetBestMapForUnit") or nil
  if type(getBestMapForUnit) ~= "function" then
    return nil
  end

  local okMap, mapID = pcall(getBestMapForUnit, "player")
  mapID = okMap and tonumber(mapID) or nil
  if not mapID or mapID <= 0 then
    return nil
  end

  return math.floor(mapID)
end

local function GetTrackedMythicZeroState(ctx)
  if ctx.isInChallengeMode() then
    return false, nil
  end

  local okInstance, _, instanceType, difficultyID = pcall(GetInstanceInfo)
  -- Legacy helper name: this now tracks all supported non-challenge party dungeons
  -- so last-run DPS also appears after normal and heroic completions.
  if not okInstance or instanceType ~= "party" or not TRACKED_NON_CHALLENGE_PARTY_DIFFICULTY_IDS[difficultyID] then
    return false, nil
  end

  return true, ResolveTrackedMythicZeroMapID()
end

local function CloneRosterSnapshotForStats(roster)
  if type(roster) ~= "table" then
    return {}
  end

  local snapshot = {}
  for unit, info in pairs(roster) do
    if type(info) == "table" then
      local clonedInfo = {}
      for key, value in pairs(info) do
        clonedInfo[key] = value
      end
      snapshot[unit] = clonedInfo
    end
  end

  return snapshot
end

local function HasReliableTrackedMythicZeroRoster(ctx, roster)
  if type(roster) ~= "table" then
    return false
  end

  local memberCount = 0
  for unit, info in pairs(roster) do
    if type(info) == "table" and info.isGhost ~= true then
      memberCount = memberCount + 1
      if unit ~= "player" then
        return true
      end
    end
  end

  if memberCount == 0 then
    return false
  end

  return not ctx.isInGroup()
end

local function DidRecordRunSucceed(recorded)
  return recorded ~= false
end

local RetryTrackedMythicZeroRunCapture

local function ScheduleTrackedMythicZeroRunRetry(ctx, runInfo, retriesRemaining)
  if
    type(runInfo) ~= "table"
    or retriesRemaining <= 0
    or not ctx.timerAfter
    or ctx.pendingMythicZeroRunCapture ~= runInfo
    or runInfo.retryScheduled
  then
    return false
  end

  runInfo.retryScheduled = true
  ctx.timerAfter(NON_CHALLENGE_RUN_CAPTURE_RETRY_DELAY_SECONDS, function()
    if ctx.pendingMythicZeroRunCapture ~= runInfo then
      return
    end

    runInfo.retryScheduled = false
    if RetryTrackedMythicZeroRunCapture(ctx, runInfo, retriesRemaining - 1) then
      ctx.updateUI()
    end
  end)

  return true
end

RetryTrackedMythicZeroRunCapture = function(ctx, runInfo, retriesRemaining)
  if type(runInfo) ~= "table" or ctx.pendingMythicZeroRunCapture ~= runInfo then
    return false
  end

  local capturedNow = DidRecordRunSucceed(ctx.recordRun(runInfo.mapID, 0, nil, runInfo.rosterSnapshot))
  if capturedNow then
    ctx.pendingMythicZeroRunCapture = nil
    return true
  end

  ScheduleTrackedMythicZeroRunRetry(ctx, runInfo, retriesRemaining or NON_CHALLENGE_RUN_CAPTURE_RETRIES)
  return false
end

local function UpdateTrackedMythicZeroRun(ctx)
  local isTrackedMythicZero, currentMapID = GetTrackedMythicZeroState(ctx)
  local previousMapID = tonumber(ctx.activeMythicZeroMapID)
  local roster = ctx.getRoster()

  if isTrackedMythicZero then
    ctx.pendingMythicZeroRunCapture = nil
    if ctx.activeMythicZeroRosterSnapshot == nil and HasReliableTrackedMythicZeroRoster(ctx, roster) then
      ctx.activeMythicZeroRosterSnapshot = CloneRosterSnapshotForStats(roster)
    end
    if not previousMapID and currentMapID then
      ctx.activeMythicZeroMapID = currentMapID
    end
    return
  end

  if previousMapID then
    local rosterSnapshot = ctx.activeMythicZeroRosterSnapshot
    if rosterSnapshot == nil and type(roster) == "table" and next(roster) ~= nil then
      rosterSnapshot = CloneRosterSnapshotForStats(roster)
    end
    if rosterSnapshot ~= nil then
      local runInfo = {
        mapID = previousMapID,
        rosterSnapshot = rosterSnapshot,
        retryScheduled = false,
      }
      ctx.pendingMythicZeroRunCapture = runInfo
      RetryTrackedMythicZeroRunCapture(ctx, runInfo, NON_CHALLENGE_RUN_CAPTURE_RETRIES)
    end
  end
  ctx.activeMythicZeroMapID = nil
  ctx.activeMythicZeroRosterSnapshot = nil
end

local function CaptureTrackedMythicZeroRosterSnapshotIfPending(ctx)
  if ctx.activeMythicZeroRosterSnapshot ~= nil or not ctx.activeMythicZeroMapID then
    return false
  end

  local isTrackedMythicZero = GetTrackedMythicZeroState(ctx)
  if not isTrackedMythicZero then
    return false
  end

  local roster = ctx.getRoster()
  if type(roster) ~= "table" or next(roster) == nil then
    return false
  end

  ctx.activeMythicZeroRosterSnapshot = CloneRosterSnapshotForStats(roster)
  return true
end
-- applyHotkeyBindings wird beim Startup bewusst mehrfach aufgerufen
-- (ADDON_LOADED / PLAYER_LOGIN via ApplyBindingStartupRefresh, sowie
-- PLAYER_ENTERING_WORLD + 2 delayed via ScheduleBindingStartupRefresh),
-- um Timing-Probleme mit dem WoW-Binding-System zuverlässig abzufangen.
local function ApplyBindingStartupRefresh(ctx)
  ctx.applyHotkeyBindings()
  ctx.startBindingWatchdog()
end

local function ScheduleBindingStartupRefresh(ctx)
  ApplyBindingStartupRefresh(ctx)
  if ctx.timerAfter then
    ctx.timerAfter(1, ctx.applyHotkeyBindings)
    ctx.timerAfter(3, ctx.applyHotkeyBindings)
  end
end

local function RegisterSyncPrefixAndBindings(ctx)
  ctx.registerIsiLiveSyncPrefix()
  ApplyBindingStartupRefresh(ctx)
end

function RuntimeLifecycle.BuildHandlers(ctx)
  local function HandleGroupRosterUpdateEvent(_self)
    if ctx.isInGroup() and (ctx.isTestMode() or ctx.isTestAllMode()) then
      ctx.exitTestMode()
      return
    end

    ctx.handleGroupRosterUpdate()
    CaptureTrackedMythicZeroRosterSnapshotIfPending(ctx)
  end

  local function HandleAddonLoadedEvent(_self, loadedAddon)
    if loadedAddon ~= ctx.addonName then
      return
    end

    IsiLiveDB = IsiLiveDB or {}
    IsiLiveDB.position = IsiLiveDB.position or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
    IsiLiveDB.locale = ctx.resolveLocaleTag(IsiLiveDB.locale or ctx.defaultLocale)
    ctx.setLocaleTable(ctx.locales[IsiLiveDB.locale] or ctx.locales.enUS)
    -- These settings are temporarily hidden from Blizzard Settings.
    -- Keep SavedVariables aligned with the hard runtime defaults until the controls return.
    IsiLiveDB.showDpsColumn = true
    IsiLiveDB.markersLeaderOnly = false
    IsiLiveDB.soundEnabled = false
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

    local mainFrame = ctx.getMainFrame()
    local pos = IsiLiveDB.position
    if mainFrame and mainFrame.ClearAllPoints and mainFrame.SetPoint then
      mainFrame:ClearAllPoints()
      mainFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    end
    RegisterSyncPrefixAndBindings(ctx)
    ctx.applyLocalizationToUI()
    ctx.restoreLayoutState()
    ctx.updateCountdownCancelButton()
    ctx.updateLeaderButtons()
  end

  local function HandlePlayerLoginEvent(_self)
    ApplyBindingStartupRefresh(ctx)
    local playerName, playerRealm = ctx.getUnitNameAndRealm("player")
    ctx.markIsiLiveUser(playerName, playerRealm)
  end

  local function HandlePlayerEnteringWorldEvent(_self)
    ctx.baselineCdTracker()
    UpdateTrackedMythicZeroRun(ctx)
    ScheduleBindingStartupRefresh(ctx)
    ctx.sendOwnKeySnapshot(true, "world")
    ctx.maybeShowNonMythicDungeonEntryNotice()
    ctx.maybeShowPortalNavigatorNotice()
    ctx.updateStatusLine()
    ctx.checkIfEnteredTargetDungeon()

    local inPartyInstance = ctx.isInPartyInstance() == true
    local wasInPartyInstance = ctx.wasInPartyInstance
    ctx.wasInPartyInstance = inPartyInstance
    if wasInPartyInstance ~= nil and not wasInPartyInstance and inPartyInstance and not ctx.isInChallengeMode() then
      ctx.setMainFrameVisible(true)
    end
  end

  local function HandleUpdateBindingsEvent(_self)
    ctx.applyHotkeyBindings()
  end

  local function HandlePlayerRegenEnabledEvent(_self)
    if ctx.getPendingBindingApply() then
      ctx.applyHotkeyBindings()
    end
    local pendingVisible = ctx.getPendingMainFrameVisible and ctx.getPendingMainFrameVisible()
    if pendingVisible ~= nil then
      ctx.setMainFrameVisible(pendingVisible)
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

  local function HandleInstanceContextChangedEvent(_self)
    ctx.baselineCdTracker(1)
    UpdateTrackedMythicZeroRun(ctx)
    ctx.updateStatusLine()
    ctx.maybeShowNonMythicDungeonEntryNotice()
    ctx.maybeShowPortalNavigatorNotice()
    ctx.checkIfEnteredTargetDungeon()
    ctx.sendOwnKeySnapshot(false, "zone")
  end

  local function HandleOwnedKeyContextEvent(_self)
    ctx.updateStatusLine()
    ctx.handleOwnedKeyRefresh()
    ctx.maybeShowNonMythicDungeonEntryNotice()
    ctx.checkIfEnteredTargetDungeon()
  end

  local function HandleInspectReadyEvent(_self, guid)
    if not ctx.isMainFrameShown() then
      return
    end

    if ctx.onInspectReady(guid) then
      ctx.updateUI()
    end
  end

  local function HandleChatMsgAddonEvent(_self, prefix, message, _channel, sender)
    local syncResult = ctx.processAddonMessage(prefix, message, sender)
    if not syncResult then
      return
    end

    if syncResult.shouldAck then
      ctx.sendAck(syncResult.sender)
    end
    if syncResult.shouldRequestRefresh then
      ctx.sendRefreshResponse()
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

  local function HandleSpellUpdateCooldownEvent(_self)
    ctx.updateMPlusTeleportButton()
  end

  local function HandleSpellUpdateChargesEvent(_self)
    ctx.updateCdTracker()
  end

  local function HandleUnitAuraEvent(_self, unit)
    if unit ~= "player" then
      return
    end
    ctx.updateCdTracker()
  end

  local function HandleUnitSpellcastSucceededEvent(_self, _unit, _castGUID, spellID)
    ctx.notifyCdTrackerSpellCast(spellID)
  end

  return {
    GROUP_ROSTER_UPDATE = HandleGroupRosterUpdateEvent,
    ADDON_LOADED = HandleAddonLoadedEvent,
    PLAYER_LOGIN = HandlePlayerLoginEvent,
    PLAYER_ENTERING_WORLD = HandlePlayerEnteringWorldEvent,
    UPDATE_BINDINGS = HandleUpdateBindingsEvent,
    PLAYER_REGEN_ENABLED = HandlePlayerRegenEnabledEvent,
    PLAYER_DIFFICULTY_CHANGED = HandleInstanceContextChangedEvent,
    ZONE_CHANGED = HandleInstanceContextChangedEvent,
    ZONE_CHANGED_INDOORS = HandleInstanceContextChangedEvent,
    ZONE_CHANGED_NEW_AREA = HandleInstanceContextChangedEvent,
    UPDATE_INSTANCE_INFO = HandleInstanceContextChangedEvent,
    BAG_UPDATE_DELAYED = HandleOwnedKeyContextEvent,
    CHALLENGE_MODE_MAPS_UPDATE = HandleOwnedKeyContextEvent,
    INSPECT_READY = HandleInspectReadyEvent,
    CHAT_MSG_ADDON = HandleChatMsgAddonEvent,
    SPELL_UPDATE_COOLDOWN = HandleSpellUpdateCooldownEvent,
    SPELL_UPDATE_CHARGES = HandleSpellUpdateChargesEvent,
    UNIT_AURA = HandleUnitAuraEvent,
    UNIT_SPELLCAST_SUCCEEDED = HandleUnitSpellcastSucceededEvent,
  }
end
