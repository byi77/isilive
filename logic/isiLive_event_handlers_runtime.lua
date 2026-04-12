local _, addonTable = ...

addonTable = addonTable or {}

local RuntimeLifecycle = {}
addonTable.EventHandlersRuntimeLifecycle = RuntimeLifecycle
local ChallengeLifecycle = addonTable.EventHandlersChallengeLifecycle

local function GetDB()
  return rawget(_G, "IsiLiveDB")
end

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
  if type(getBestMapForUnit) ~= "function" or type(UnitExists) ~= "function" or not UnitExists("player") then
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

  local capturedNow = ctx.recordRun(runInfo.mapID, 0, nil, runInfo.rosterSnapshot) ~= false
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
-- applyHotkeyBindings is intentionally called multiple times on startup
-- (ADDON_LOADED / PLAYER_LOGIN via ApplyBindingStartupRefresh, and
-- PLAYER_ENTERING_WORLD + 2 delayed via ScheduleBindingStartupRefresh)
-- to reliably catch timing issues with the WoW binding system.
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

local COMBAT_FADE_DURATION = 0.4
local COMBAT_FADE_TICK = 0.05
local activeFadeTicker = nil

local function IsRaidModeActive(ctx)
  return type(ctx.isRaidGroup) == "function" and ctx.isRaidGroup() == true
end

local function AnimateMainFrameAlpha(mainFrame, targetAlpha)
  if not mainFrame or type(mainFrame.SetAlpha) ~= "function" then
    return
  end
  if activeFadeTicker then
    activeFadeTicker:Cancel()
    activeFadeTicker = nil
  end
  local currentAlpha = mainFrame:GetAlpha()
  if math.abs(currentAlpha - targetAlpha) < 0.01 then
    mainFrame:SetAlpha(targetAlpha)
    return
  end
  local steps = math.max(1, math.floor(COMBAT_FADE_DURATION / COMBAT_FADE_TICK))
  local delta = (targetAlpha - currentAlpha) / steps
  local stepsDone = 0
  activeFadeTicker = C_Timer.NewTicker(COMBAT_FADE_TICK, function()
    stepsDone = stepsDone + 1
    local newAlpha = currentAlpha + delta * stepsDone
    if stepsDone >= steps then
      mainFrame:SetAlpha(targetAlpha)
      activeFadeTicker = nil
    else
      mainFrame:SetAlpha(newAlpha)
    end
  end, steps)
end

local function IsCombatFadeLayout(layoutMode)
  local RI = addonTable._RosterInternal or {}
  return layoutMode == (RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL or "compact_main_horizontal")
    or layoutMode == (RI.LAYOUT_MODE_EXPANDED or "expanded")
end

local function ApplyCombatFade(ctx, targetAlpha)
  local db = GetDB()
  if not db or db.combatFadeMM ~= true then
    return
  end
  local RI = addonTable._RosterInternal or {}
  local fallbackLayout = RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL or "compact_main_horizontal"
  local layoutMode = db.defaultLayoutMode or fallbackLayout
  if not IsCombatFadeLayout(layoutMode) then
    return
  end
  local mainFrame = type(ctx.getMainFrame) == "function" and ctx.getMainFrame()
  if mainFrame and type(mainFrame.IsShown) == "function" and mainFrame:IsShown() then
    AnimateMainFrameAlpha(mainFrame, targetAlpha)
  end
end

function RuntimeLifecycle.BuildHandlers(ctx)
  local function HandleGroupRosterUpdateEvent(frame)
    if ctx.isInGroup() and (ctx.isTestMode() or ctx.isTestAllMode()) then
      ctx.exitTestMode()
      return
    end

    ctx.handleGroupRosterUpdate()
    if
      type(ChallengeLifecycle) == "table"
      and type(ChallengeLifecycle.ResumeDeferredPostChallengeRefresh) == "function"
    then
      ChallengeLifecycle.ResumeDeferredPostChallengeRefresh(ctx, frame)
    end
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
    -- Administrative debug settings are never persisted: always start disabled, user must re-enable each session.
    IsiLiveDB.queueDebug = false
    IsiLiveDB.runtimeLogEnabled = false
    ctx.ensureQueueDebugStorage()
    ctx.setQueueDebugEnabled(false)
    ctx.ensureRuntimeLogStorage()
    ctx.setRuntimeLogEnabled(false)
    ctx.restoreRioBaseline()

    local mainFrame = ctx.getMainFrame()
    local pos = IsiLiveDB.position
    if mainFrame and mainFrame.ClearAllPoints and mainFrame.SetPoint then
      mainFrame:ClearAllPoints()
      mainFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    end
    if ctx.mainUI and type(ctx.mainUI.SetDragLocked) == "function" then
      ctx.mainUI.SetDragLocked(IsiLiveDB.lockMainFramePosition ~= false)
    end
    -- Restore UI scale and background opacity from SavedVariables.
    -- This must happen here (ADDON_LOADED) because IsiLiveDB is nil at file-load time.
    if mainFrame then
      if type(IsiLiveDB.uiScale) == "number" and type(mainFrame.SetScale) == "function" then
        mainFrame:SetScale(IsiLiveDB.uiScale)
      end
      if type(IsiLiveDB.bgAlpha) == "number" then
        if type(mainFrame.SetBackdropColor) == "function" then
          mainFrame:SetBackdropColor(0, 0, 0, IsiLiveDB.bgAlpha)
        end
        local uiCommon = addonTable.UICommon
        if
          type(uiCommon) == "table"
          and type(uiCommon.Colors) == "table"
          and type(uiCommon.Colors.BG_PRIMARY) == "table"
        then
          uiCommon.Colors.BG_PRIMARY[4] = IsiLiveDB.bgAlpha
        end
        if ctx.panelUI and ctx.panelUI.panelFrame and type(ctx.panelUI.panelFrame.SetBackdropColor) == "function" then
          local bg = uiCommon and uiCommon.Colors and uiCommon.Colors.BG_PRIMARY
            or { 0.08, 0.08, 0.12, IsiLiveDB.bgAlpha }
          ctx.panelUI.panelFrame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        end
        if
          ctx.settingsPanel
          and ctx.settingsPanel.canvas
          and type(ctx.settingsPanel.canvas.SetBackdropColor) == "function"
        then
          local bg = uiCommon and uiCommon.Colors and uiCommon.Colors.BG_PRIMARY
            or { 0.08, 0.08, 0.12, IsiLiveDB.bgAlpha }
          ctx.settingsPanel.canvas:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        end
      end
    end
    RegisterSyncPrefixAndBindings(ctx)
    ctx.applyLocalizationToUI()
    ctx.restoreLayoutState()
    ctx.updateCountdownCancelButton()
    ctx.updateLeaderButtons()
    -- IsiLiveDB is now available; apply minimap button visibility before PLAYER_LOGIN
    -- so MinimapButtonButton sees the correct shown-state when it scans.
  end

  local function HandlePlayerLoginEvent(_self)
    ApplyBindingStartupRefresh(ctx)
    if not IsRaidModeActive(ctx) and ctx.shouldShowMainFrameOnStartup() then
      ctx.setMainFrameVisible(true)
    end
    local playerName, playerRealm = ctx.getUnitNameAndRealm("player")
    ctx.markIsiLiveUser(playerName, playerRealm)
  end

  local function HandlePlayerEnteringWorldEvent(_self)
    if IsRaidModeActive(ctx) then
      ctx.wasInPartyInstance = ctx.isInPartyInstance() == true
      return
    end
    ctx.updateCdTracker()
    UpdateTrackedMythicZeroRun(ctx)
    ScheduleBindingStartupRefresh(ctx)
    ctx.sendOwnKeySnapshot(true, "world", not ctx.isMainFrameShown())
    ctx.sendOwnKickState(true)
    ctx.maybeShowNonMythicDungeonEntryNotice()
    ctx.maybeShowPortalNavigatorNotice()
    ctx.updateStatusLine()
    ctx.checkIfEnteredTargetDungeon()

    local inPartyInstance = ctx.isInPartyInstance() == true
    local wasInPartyInstance = ctx.wasInPartyInstance
    ctx.wasInPartyInstance = inPartyInstance

    if wasInPartyInstance == nil and ctx.isInGroup() then
      -- After a reload, rebuild the roster so the group is shown immediately.
      ctx.handleGroupRosterUpdate()
    elseif wasInPartyInstance ~= nil and not wasInPartyInstance and inPartyInstance and not ctx.isInChallengeMode() then
      ctx.setMainFrameVisible(true)
    end
  end

  local function HandleUpdateBindingsEvent(_self)
    ctx.applyHotkeyBindings()
  end

  local function HandlePlayerRegenDisabledEvent(_self)
    ApplyCombatFade(ctx, 0)
  end

  local function HandlePlayerRegenEnabledEvent(_self)
    if ctx.getPendingBindingApply() then
      ctx.applyHotkeyBindings()
    end
    local pendingVisible = ctx.getPendingMainFrameVisible and ctx.getPendingMainFrameVisible()
    if pendingVisible ~= nil then
      if IsRaidModeActive(ctx) then
        ctx.setMainFrameVisible(false)
      else
        ctx.setMainFrameVisible(pendingVisible)
      end
    end
    ApplyCombatFade(ctx, 1)
    if IsRaidModeActive(ctx) then
      return
    end
    local pendingMainFrameHeight = ctx.getPendingMainFrameHeight()
    if pendingMainFrameHeight then
      ctx.setMainFrameHeightSafe(pendingMainFrameHeight)
    end
    local pendingMainFrameWidth = ctx.getPendingMainFrameWidth()
    if pendingMainFrameWidth then
      ctx.setMainFrameWidthSafe(pendingMainFrameWidth)
    end
    if ctx.isMainFrameShown() then
      ctx.updateUI()
      ctx.updateMPlusTeleportButton()
      ctx.tryRestoreCenterNoticeTeleportButton()
    end
  end

  local function HandleInstanceContextChangedEvent(_self)
    if IsRaidModeActive(ctx) then
      return
    end
    ctx.updateCdTracker()
    UpdateTrackedMythicZeroRun(ctx)
    ctx.updateStatusLine()
    ctx.maybeShowNonMythicDungeonEntryNotice()
    ctx.maybeShowPortalNavigatorNotice()
    ctx.checkIfEnteredTargetDungeon()
    ctx.sendOwnBackgroundSnapshot("zone")
  end

  local function HandleOwnedKeyContextEvent(_self)
    if IsRaidModeActive(ctx) then
      return
    end
    ctx.updateStatusLine()
    ctx.handleOwnedKeyRefresh()
    ctx.maybeShowNonMythicDungeonEntryNotice()
    ctx.checkIfEnteredTargetDungeon()
  end

  local function HandlePlayerSpecializationChangedEvent(_self, unit)
    if unit ~= nil and unit ~= "player" then
      return
    end
    if IsRaidModeActive(ctx) then
      return
    end
    ctx.sendOwnBackgroundSnapshot("player-state")
  end

  local function HandlePlayerEquipmentChangedEvent(_self)
    if IsRaidModeActive(ctx) then
      return
    end
    ctx.sendOwnBackgroundSnapshot("player-state")
  end

  local function HandleInspectReadyEvent(_self, guid)
    if IsRaidModeActive(ctx) then
      return
    end
    if not ctx.isMainFrameShown() then
      return
    end

    if ctx.onInspectReady(guid) then
      ctx.updateUI()
    end
  end

  local function HandleChatMsgAddonEvent(_self, prefix, message, channel, sender)
    if IsRaidModeActive(ctx) then
      return
    end
    local syncResult = ctx.processAddonMessage(prefix, message, sender, channel)
    if not syncResult then
      return
    end

    if syncResult.shouldReplyLibKeystone then
      ctx.sendLibKeystonePartyData(true)
    end
    if syncResult.shouldAck then
      ctx.sendAck(syncResult.sender)
      -- New peer detected: send hello + full state (key, stats, dps, loc) + kick immediately.
      ctx.sendIsiLiveHello(true, "hello-ack")
      ctx.sendRefreshResponse()
      ctx.sendOwnTargetSnapshot(true, "hello", true)
      ctx.sendOwnKickState()
    end
    if syncResult.shouldRequestRefresh then
      ctx.sendIsiLiveHello(true, "reqsync-ack")
      ctx.sendRefreshResponse()
      ctx.sendOwnTargetSnapshot(true, "reqsync", true)
      ctx.sendOwnKickState()
    end
    if syncResult.shouldShareKeys then
      ctx.sendOwnKeystoneToChat()
      if type(ctx.triggerShareKeysCooldown) == "function" then
        ctx.triggerShareKeysCooldown()
      end
    end

    local changed = syncResult.targetUpdated == true or syncResult.kickUpdated == true
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
      ctx.updateStatusLine()
      ctx.updateMPlusTeleportButton()
      ctx.updateUI()
    end
  end

  local function HandleSpellUpdateCooldownEvent(_self)
    if IsRaidModeActive(ctx) then
      return
    end
    ctx.updateMPlusTeleportButton()
  end

  local function HandleSpellUpdateChargesEvent(_self)
    if IsRaidModeActive(ctx) then
      return
    end
    ctx.updateCdTracker()
  end

  local function HandleUnitAuraEvent(_self, unit, _unitAuraUpdateInfo)
    if unit ~= "player" then
      return
    end
    if IsRaidModeActive(ctx) then
      return
    end
    ctx.updateCdTracker()
  end

  return {
    GROUP_ROSTER_UPDATE = HandleGroupRosterUpdateEvent,
    ADDON_LOADED = HandleAddonLoadedEvent,
    PLAYER_LOGIN = HandlePlayerLoginEvent,
    PLAYER_ENTERING_WORLD = HandlePlayerEnteringWorldEvent,
    UPDATE_BINDINGS = HandleUpdateBindingsEvent,
    PLAYER_REGEN_ENABLED = HandlePlayerRegenEnabledEvent,
    PLAYER_REGEN_DISABLED = HandlePlayerRegenDisabledEvent,
    PLAYER_DIFFICULTY_CHANGED = HandleInstanceContextChangedEvent,
    ZONE_CHANGED = HandleInstanceContextChangedEvent,
    ZONE_CHANGED_INDOORS = HandleInstanceContextChangedEvent,
    ZONE_CHANGED_NEW_AREA = HandleInstanceContextChangedEvent,
    UPDATE_INSTANCE_INFO = HandleInstanceContextChangedEvent,
    BAG_UPDATE_DELAYED = HandleOwnedKeyContextEvent,
    CHALLENGE_MODE_MAPS_UPDATE = HandleOwnedKeyContextEvent,
    PLAYER_EQUIPMENT_CHANGED = HandlePlayerEquipmentChangedEvent,
    PLAYER_SPECIALIZATION_CHANGED = HandlePlayerSpecializationChangedEvent,
    INSPECT_READY = HandleInspectReadyEvent,
    CHAT_MSG_ADDON = HandleChatMsgAddonEvent,
    SPELL_UPDATE_COOLDOWN = HandleSpellUpdateCooldownEvent,
    SPELL_UPDATE_CHARGES = HandleSpellUpdateChargesEvent,
    UNIT_AURA = HandleUnitAuraEvent,
  }
end
