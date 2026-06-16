local _, addonTable = ...

addonTable = addonTable or {}

local RuntimeLifecycle = {}
addonTable.EventHandlersRuntimeLifecycle = RuntimeLifecycle
local ChallengeLifecycle = addonTable.EventHandlersChallengeLifecycle
local IsRaidModeActive

local function GetDB()
  return rawget(_G, "IsiLiveDB")
end

local function ApplyPendingLeaderButtonUpdates(ctx)
  if type(ctx.applyPendingLeaderButtonUpdates) == "function" then
    ctx.applyPendingLeaderButtonUpdates()
  end
end

local function GetPendingSummonStatusValue()
  local enumTable = rawget(_G, "Enum")
  local summonStatus = type(enumTable) == "table" and enumTable.SummonStatus or nil
  local pending = type(summonStatus) == "table" and summonStatus.Pending or nil
  return pending
end

local function IsPlayerIncomingSummonPending(unitTarget)
  if unitTarget ~= "player" then
    return false
  end
  local incomingSummon = rawget(_G, "C_IncomingSummon")
  local getStatus = type(incomingSummon) == "table" and incomingSummon.IncomingSummonStatus or nil
  if type(getStatus) ~= "function" then
    return false
  end
  local ok, status = pcall(getStatus, "player")
  if not ok then
    return false
  end
  local pending = GetPendingSummonStatusValue()
  return pending ~= nil and status == pending
end

local function HandleConfirmSummonSound(ctx)
  if IsRaidModeActive(ctx) then
    return
  end
  ctx.playIncomingSummonSound()
end

local function HandleIncomingSummonChangedSound(ctx, unitTarget)
  if IsRaidModeActive(ctx) then
    return
  end
  if not IsPlayerIncomingSummonPending(unitTarget) then
    return
  end
  ctx.playIncomingSummonSound()
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
  if type(getBestMapForUnit) ~= "function" or type(UnitExists) ~= "function" then
    return nil
  end
  local okUnit, unitExists = pcall(UnitExists, "player")
  if not (okUnit and unitExists) then
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

function IsRaidModeActive(ctx)
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

-- Centralized SavedVariables sanitizer + Lua-error capture install. Called
-- from HandleAddonLoadedEvent, AFTER WoW restored IsiLiveDB but BEFORE any
-- live module reads from it. Schema details: core/isiLive_db_schema.lua.
-- Error-log details: core/isiLive_error_log.lua.
local function SanitizeDBAndInstallErrorLog(ctx)
  local DBSchema = addonTable.DBSchema
  if DBSchema and type(DBSchema.Sanitize) == "function" then
    local corrections, migrations = DBSchema.Sanitize(IsiLiveDB, function(message)
      if type(ctx.logRuntimeTrace) == "function" then
        ctx.logRuntimeTrace("[DBSCHEMA] " .. tostring(message))
      end
    end)
    if (corrections > 0 or migrations > 0) and type(ctx.logRuntimeTrace) == "function" then
      ctx.logRuntimeTrace(
        string.format("[DBSCHEMA] sanitized: %d correction(s), %d migration(s)", corrections, migrations)
      )
    end
  end
  local ErrorLog = addonTable.ErrorLog
  if ErrorLog and type(ErrorLog.Install) == "function" then
    ErrorLog.Install()
  end
end

-- Re-poll cached roster.role for player + party slots from the live API.
-- Shared by PLAYER_ROLES_ASSIGNED, ROLE_CHANGED_INFORM and the spec-change
-- chain (Units.GetUnitRole prefers spec role for "player").
local function RefreshRosterRoles(ctx)
  if IsRaidModeActive(ctx) then
    return
  end
  if type(ctx.getUnitRole) ~= "function" then
    return
  end
  local roster = ctx.getRoster()
  if type(roster) ~= "table" then
    return
  end
  local changed = false
  for unit, info in pairs(roster) do
    if type(info) == "table" and not info.isGhost and (unit == "player" or string.find(unit, "^party") ~= nil) then
      local role = ctx.getUnitRole(unit)
      if (role == "TANK" or role == "HEALER" or role == "DAMAGER" or role == "NONE") and role ~= info.role then
        info.role = role
        changed = true
      end
    end
  end
  if changed then
    ctx.updateUI()
    ctx.updateLeaderButtons()
  end
end

-- Refresh the cached spec name on the player roster entry so the spec column
-- reflects the new spec immediately on PLAYER_SPECIALIZATION_CHANGED. Skipped
-- when an inspect refresh is queued so the inspect pipeline keeps ownership of
-- spec writes for that cycle. Returns true when the cached spec actually
-- changed so the caller can fire updateUI even if the role stayed the same
-- (Mage Arcane -> Frost: same DAMAGER role, different spec name).
local function RefreshPlayerSpecCache(ctx)
  if type(ctx.getPlayerSpecName) ~= "function" then
    return false
  end
  local roster = ctx.getRoster()
  local playerInfo = type(roster) == "table" and roster.player or nil
  if type(playerInfo) ~= "table" or playerInfo._refreshQueued then
    return false
  end
  local specName = ctx.getPlayerSpecName()
  if type(specName) == "string" and specName ~= "" and specName ~= playerInfo.spec then
    playerInfo.spec = specName
    return true
  end
  return false
end

-- Sated/Exhaustion debuff IDs that CdTracker.ScanLust matches against the
-- player's HARMFUL aura list. Mirrors LUST_SATED_IDS in game/isiLive_cd_tracker.lua;
-- kept in sync so the event-side filter knows which UNIT_AURA payloads are
-- actually load-bearing for the CD-tracker scan.
local LUST_SATED_AURA_IDS = {
  [57723] = true,
  [57724] = true,
  [80354] = true,
  [264689] = true,
  [390435] = true,
  [95809] = true,
}

-- UNIT_AURA for "player" fires many times per second in combat (DoT ticks,
-- proc refreshes, stack changes). The CD-tracker only cares about the six
-- Sated/Exhaustion IDs above. Use the unitAuraUpdateInfo payload to skip the
-- 40-slot HARMFUL pcall scan when no Sated-relevant change is in this event.
-- Aura removals and instance updates do not reliably include spellId, only
-- aura instance IDs, so those payloads must scan to detect natural
-- Sated/Exhaustion expiry.
-- Conservative fallback: scan whenever the payload is missing or signals a
-- full update, so /reload and zone transitions still resync.
--
-- Secret-Value note: in WoW 12.0+ M+ / boss restriction zones, aura fields
-- on the payload can be Secret Values. `type(secret)` lies and returns
-- "number", but using the value as a table key raises "attempted to index a
-- table that cannot be indexed with secret keys". The lookup MUST run inside
-- pcall — mirroring the same defence in game/isiLive_cd_tracker.lua:ScanLust.
local function UnitAuraUpdateRequiresCdScan(updateInfo)
  if type(updateInfo) ~= "table" then
    return true
  end
  if updateInfo.isFullUpdate then
    return true
  end
  if type(updateInfo.removedAuraInstanceIDs) == "table" and #updateInfo.removedAuraInstanceIDs > 0 then
    return true
  end
  if type(updateInfo.updatedAuraInstanceIDs) == "table" and #updateInfo.updatedAuraInstanceIDs > 0 then
    return true
  end
  if type(updateInfo.removedAuras) == "table" and #updateInfo.removedAuras > 0 then
    return true
  end
  local added = updateInfo.addedAuras
  if type(added) == "table" then
    for i = 1, #added do
      local aura = added[i]
      if type(aura) == "table" then
        local isMatch = false
        pcall(function()
          local sid = rawget(aura, "spellId")
          if sid and LUST_SATED_AURA_IDS[sid] then
            isMatch = true
          end
        end)
        if isMatch then
          return true
        end
      end
    end
  end
  return false
end

-- SPELL_UPDATE_COOLDOWN and SPELL_UPDATE_CHARGES fire many times per second
-- during combat (every GCD start/end, every charge regen, every item CD).
-- Coalesce bursts into one trailing handler call ~100ms later so the
-- kick-tracker cache and teleport-button refresh do not run 20+ times/sec
-- for state that only changes at most once per cast. Each call to
-- BuildSpellCooldownCoalescer returns a fresh closure pair so per-controller
-- state stays isolated (one controller per session in production, one per
-- test in the harness).
local SPELL_COOLDOWN_COALESCE_SECONDS = 0.1
local function BuildSpellCooldownCoalescer(ctx, isRaidActive)
  local pendingCooldown = false
  local pendingCharges = false

  local function HandleCooldown(_self)
    if isRaidActive() then
      return
    end
    if pendingCooldown then
      return
    end
    local function dispatch()
      pendingCooldown = false
      if isRaidActive() then
        return
      end
      ctx.handleKickTrackerEvent("SPELL_UPDATE_COOLDOWN")
      ctx.updateMPlusTeleportButton()
    end
    local timer = rawget(_G, "C_Timer")
    local after = type(timer) == "table" and timer.After or nil
    if type(after) == "function" then
      pendingCooldown = true
      after(SPELL_COOLDOWN_COALESCE_SECONDS, dispatch)
      return
    end
    dispatch()
  end

  local function HandleCharges(_self)
    if isRaidActive() then
      return
    end
    if pendingCharges then
      return
    end
    local function dispatch()
      pendingCharges = false
      if isRaidActive() then
        return
      end
      ctx.updateCdTracker()
    end
    local timer = rawget(_G, "C_Timer")
    local after = type(timer) == "table" and timer.After or nil
    if type(after) == "function" then
      pendingCharges = true
      after(SPELL_COOLDOWN_COALESCE_SECONDS, dispatch)
      return
    end
    dispatch()
  end

  return HandleCooldown, HandleCharges
end

local function HandleShareKeysRequest(ctx, syncResult, sender)
  local resolvedSender = tostring(syncResult.sender or sender)
  if type(ctx.logRuntimeTracef) == "function" then
    ctx.logRuntimeTracef("[SHAREKEYS] received sender=%s", resolvedSender)
  end
  local didShareOwnKey = type(ctx.sendOwnKeystoneToChat) == "function" and ctx.sendOwnKeystoneToChat() == true
  if type(ctx.logRuntimeTracef) == "function" then
    ctx.logRuntimeTracef("[SHAREKEYS] reply_result sender=%s sent=%s", resolvedSender, tostring(didShareOwnKey))
  end
  if type(ctx.triggerShareKeysCooldown) == "function" then
    ctx.triggerShareKeysCooldown()
    if type(ctx.logRuntimeTracef) == "function" then
      ctx.logRuntimeTracef("[SHAREKEYS] cooldown_triggered sender=%s", resolvedSender)
    end
  end
end

local function ResetChallengeRuntimeOnInactiveInstanceEntry(ctx, wasInPartyInstance, inPartyInstance)
  if wasInPartyInstance == nil or wasInPartyInstance == true or inPartyInstance ~= true then
    return false
  end
  if ctx.isInChallengeMode() then
    return false
  end

  ctx.handleMplusTimerEvent("CHALLENGE_MODE_RESET")
  ctx.updateCdTracker({
    suppressBattleResReadySound = true,
    suppressLustReadySound = true,
    resetRuntimeTimers = true,
  })
  return true
end

-- Full own-state fan-out towards a peer (hello-ack and REQSYNC paths share
-- it): hello + refresh response (key, stats, dps, loc) + target + kick +
-- share-keys cooldown mirror.
local function SendPeerStateFanOut(ctx, helloSource, targetSource)
  ctx.sendIsiLiveHello(true, helloSource)
  ctx.sendRefreshResponse()
  ctx.sendOwnTargetSnapshot(true, targetSource, true)
  ctx.sendOwnKickState()
  ctx.sendShareKeysCooldownState()
end

local function ApplyMirroredShareKeysCooldown(ctx, syncResult)
  local remain = tonumber(syncResult.shareKeysCooldownRemain)
  if remain and remain > 0 then
    -- Mirror a peer's share-keys lock (max-merge happens inside the button).
    ctx.triggerShareKeysCooldown(remain)
  end
end

local function NoopEventHandler(_event, ...) end

local function ResolveEventHandler(handler)
  return type(handler) == "function" and handler or NoopEventHandler
end

local function ApplyVIPGuestSoundSettingsIfAvailable()
  if
    type(addonTable.SoundUtils) == "table" and type(addonTable.SoundUtils.ApplyVIPGuestSoundSettings) == "function"
  then
    addonTable.SoundUtils.ApplyVIPGuestSoundSettings()
  end
end

local function BuildNonRaidEventForwarder(ctx, handlerName, eventName)
  return function(_self, ...)
    if not IsRaidModeActive(ctx) then
      ctx[handlerName](eventName, ...)
    end
  end
end

local function BuildUnitSpellcastSucceededForwarder(ctx)
  return function(_self, ...)
    if not IsRaidModeActive(ctx) then
      ctx.handleKickTrackerEvent("UNIT_SPELLCAST_SUCCEEDED", ...)
      ctx.handleCombatEventsEvent("UNIT_SPELLCAST_SUCCEEDED", ...)
    end
  end
end

local function BuildPartyLeaderChangedForwarder(ctx)
  return function(_self, ...)
    if not IsRaidModeActive(ctx) then
      ctx.handleLeaderWatchEvent("PARTY_LEADER_CHANGED", ...)
      -- Forward to LFGDetect so the stale activeInviteLeader / -TitleLevel
      -- (captured when the previous leader's listing was accepted) is
      -- dropped; the new leader is its own authority and must be resolved via
      -- UnitIsGroupLeader by downstream consumers.
      ctx.handleLFGDetectEvent("PARTY_LEADER_CHANGED")
    end
  end
end

function RuntimeLifecycle.BuildHandlers(ctx)
  ctx.handleLFGDetectEvent = ResolveEventHandler(ctx.handleLFGDetectEvent)
  ctx.handleKillTrackEvent = ResolveEventHandler(ctx.handleKillTrackEvent)
  ctx.handleCombatEventsEvent = ResolveEventHandler(ctx.handleCombatEventsEvent)
  ctx.handleDeathWatchEvent = ResolveEventHandler(ctx.handleDeathWatchEvent)
  ctx.handleKickTrackerEvent = ResolveEventHandler(ctx.handleKickTrackerEvent)
  ctx.handleMplusTimerEvent = ResolveEventHandler(ctx.handleMplusTimerEvent)
  ctx.handleLeaderWatchEvent = ResolveEventHandler(ctx.handleLeaderWatchEvent)

  local function HandleGroupRosterUpdateEvent(frame)
    if ctx.isInGroup() and (ctx.isTestMode() or ctx.isTestAllMode()) then
      ctx.exitTestMode()
      return
    end

    ctx.handleGroupRosterUpdate()
    -- Back-fill the player spec if PLAYER_SPECIALIZATION_CHANGED fired before
    -- the player's roster entry existed (typical post-PLAYER_LOGIN ordering):
    -- the prior call silently dropped the spec because roster.player was nil.
    RefreshPlayerSpecCache(ctx)
    ctx.handleLeaderWatchEvent("GROUP_ROSTER_UPDATE")
    ctx.handleLFGDetectEvent("GROUP_ROSTER_UPDATE")
    ctx.handleDeathWatchEvent("GROUP_ROSTER_UPDATE")
    -- Refresh status line after roster settles so the "Ziel-Dungeon: X +Y"
    -- chat announce fires as soon as the group is formed (post-invite-accept),
    -- not only when a peer's key sync arrives later. Skipped in raid mode so
    -- the suppression contract for background hooks stays intact (raid exit
    -- still flows via handleGroupRosterUpdate above).
    if not IsRaidModeActive(ctx) then
      ctx.updateStatusLine()
    end
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
    SanitizeDBAndInstallErrorLog(ctx)
    IsiLiveDB.locale = ctx.resolveLocaleTag(IsiLiveDB.locale or ctx.defaultLocale)
    ctx.setLocaleTable(ctx.locales[IsiLiveDB.locale] or ctx.locales.enUS)
    -- Administrative debug settings are never persisted: always start disabled, user must re-enable each session.
    IsiLiveDB.queueDebug = false
    IsiLiveDB.runtimeLogEnabled = false
    ctx.ensureQueueDebugStorage()
    ctx.setQueueDebugEnabled(false)
    ctx.ensureRuntimeLogStorage()
    ctx.setRuntimeLogEnabled(false)
    ctx.restoreRioBaseline()
    ApplyVIPGuestSoundSettingsIfAvailable()

    local mainFrame = ctx.getMainFrame()
    local pos = IsiLiveDB.position
    if mainFrame and mainFrame.ClearAllPoints and mainFrame.SetPoint and type(pos) == "table" then
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
        ctx.restoreBgAlpha(IsiLiveDB.bgAlpha)
      end
    end
    RegisterSyncPrefixAndBindings(ctx)
    ctx.applyLocalizationToUI()
    ctx.restoreLayoutState()
    ctx.updateCountdownCancelButton()
    ctx.updateLeaderButtons()
    -- Re-apply user-controlled flags now that SavedVariables are restored.
    -- The first ApplyDBSettings call ran at file-load with IsiLiveDB still
    -- nil (WoW restores SavedVariables only after the addon's lua files
    -- finish), so MobNameplate/MobTooltip/LFGFlags/RosterInternal got the
    -- defaults applied. Without this second call, a saved
    -- mobNameplateEnabled = true would never reach MobNameplate.SetEnabled
    -- and the user would see the overlay revert to the off default after
    -- every /reload.
    ctx.applyDBSettings()
    -- IsiLiveDB is now available; apply minimap button visibility before PLAYER_LOGIN
    -- so MinimapButtonButton sees the correct shown-state when it scans.
  end

  local function HandlePlayerLoginEvent(_self)
    ApplyBindingStartupRefresh(ctx)
    ctx.handleLFGDetectEvent("PLAYER_LOGIN")
    if not IsRaidModeActive(ctx) and ctx.shouldShowMainFrameOnStartup() then
      ctx.setMainFrameVisible(true)
    end
    local playerName, playerRealm = ctx.getUnitNameAndRealm("player")
    ctx.markIsiLiveUser(playerName, playerRealm)
    if type(ctx.logRuntimeTracef) == "function" then
      ctx.logRuntimeTracef(
        "[RUNTIME] player_login playerName=%s playerRealm=%s",
        tostring(playerName),
        tostring(playerRealm)
      )
    end
  end

  local function HandlePlayerEnteringWorldEvent(_self)
    local inPartyInstance = ctx.isInPartyInstance() == true
    local wasInPartyInstance = ctx.wasInPartyInstance
    if type(ctx.logRuntimeTracef) == "function" then
      ctx.logRuntimeTracef(
        "[RUNTIME] player_entering_world isRaid=%s inPartyInstance=%s isInGroup=%s isInChallenge=%s",
        tostring(IsRaidModeActive(ctx)),
        tostring(inPartyInstance),
        tostring(ctx.isInGroup()),
        tostring(ctx.isInChallengeMode())
      )
    end
    if IsRaidModeActive(ctx) then
      ctx.wasInPartyInstance = inPartyInstance
      return
    end
    ctx.handleKillTrackEvent("PLAYER_ENTERING_WORLD")
    ctx.handleMplusTimerEvent("PLAYER_ENTERING_WORLD")
    local didResetChallengeRuntime =
      ResetChallengeRuntimeOnInactiveInstanceEntry(ctx, wasInPartyInstance, inPartyInstance)
    if not didResetChallengeRuntime then
      ctx.updateCdTracker()
    end
    UpdateTrackedMythicZeroRun(ctx)
    ScheduleBindingStartupRefresh(ctx)
    ctx.sendOwnKeySnapshot(true, "world", not ctx.isMainFrameShown())
    ctx.sendOwnKickState(true)
    ctx.maybeShowNonMythicDungeonEntryNotice()
    ctx.maybeShowPortalNavigatorNotice()
    ctx.updateStatusLine()
    ctx.checkIfEnteredTargetDungeon()

    ctx.wasInPartyInstance = inPartyInstance

    if wasInPartyInstance == nil and ctx.isInGroup() then
      -- After a reload, rebuild the roster so the group is shown immediately.
      ctx.handleGroupRosterUpdate()
      -- A /reload mid-key leaves peers running but unaware that we just lost
      -- their cached state, and RunFullRefresh is gated off during an active
      -- challenge (RULE-REFRESH-NO-CHALLENGE). Trigger a one-shot peer-data
      -- request here so peers re-broadcast their keys / RIO immediately --
      -- without this, ilvl/key columns stay empty until the key ends.
      if ctx.isInChallengeMode() and type(ctx.sendRefreshRequest) == "function" then
        ctx.sendRefreshRequest(true)
      end
    elseif wasInPartyInstance ~= nil and not wasInPartyInstance and inPartyInstance and not ctx.isInChallengeMode() then
      ctx.setMainFrameVisible(true)
    end
  end

  local function HandleUpdateBindingsEvent(_self)
    ctx.applyHotkeyBindings()
  end

  local function HandlePlayerRegenDisabledEvent(_self)
    if type(ctx.logRuntimeTrace) == "function" then
      ctx.logRuntimeTrace("[RUNTIME] player_regen_disabled")
    end
    ctx.handleKillTrackEvent("PLAYER_REGEN_DISABLED")
    ApplyCombatFade(ctx, 0)
  end

  local function HandlePlayerRegenEnabledEvent(_self)
    if type(ctx.logRuntimeTrace) == "function" then
      ctx.logRuntimeTrace("[RUNTIME] player_regen_enabled")
    end
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
    ctx.handleKickTrackerEvent("PLAYER_REGEN_ENABLED")
    ctx.handleKillTrackEvent("PLAYER_REGEN_ENABLED")
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
    ApplyPendingLeaderButtonUpdates(ctx)
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
    ctx.handleKickTrackerEvent("PLAYER_SPECIALIZATION_CHANGED", unit)
    ctx.sendOwnBackgroundSnapshot("player-state")
    -- Spec change can be role-flipping (Druid Balance -> Guardian) or pure
    -- intra-role (Mage Arcane -> Frost). RefreshRosterRoles only fires
    -- updateUI when the role actually changed, so the spec-only path needs
    -- its own updateUI trigger to surface the new spec name.
    local specChanged = RefreshPlayerSpecCache(ctx)
    RefreshRosterRoles(ctx)
    if specChanged then
      ctx.updateUI()
    end
  end

  local function HandlePlayerRolesAssignedEvent(_self)
    RefreshRosterRoles(ctx)
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
      if type(ctx.saveReloadRosterMirror) == "function" then
        ctx.saveReloadRosterMirror()
      end
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
      -- New peer detected: send the full own-state fan-out immediately.
      SendPeerStateFanOut(ctx, "hello-ack", "hello")
    end
    if syncResult.shouldRequestRefresh then
      SendPeerStateFanOut(ctx, "reqsync-ack", "reqsync")
    end
    if syncResult.shouldShareKeys then
      HandleShareKeysRequest(ctx, syncResult, sender)
    end
    ApplyMirroredShareKeysCooldown(ctx, syncResult)
    if syncResult.combatAnnounce then
      ctx.showCombatAnnounce(syncResult.combatAnnounce)
    end

    if type(ctx.registerVerifiedSyncAliasForRoster) == "function" then
      ctx.registerVerifiedSyncAliasForRoster(ctx.getRoster(), syncResult.sender)
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
      if type(ctx.saveReloadRosterMirror) == "function" then
        ctx.saveReloadRosterMirror()
      end
      ctx.updateUI()
    end
  end

  local HandleSpellUpdateCooldownEvent, HandleSpellUpdateChargesEvent = BuildSpellCooldownCoalescer(ctx, function()
    return IsRaidModeActive(ctx)
  end)

  local function HandleUnitAuraEvent(_self, unit, unitAuraUpdateInfo)
    if unit ~= "player" then
      return
    end
    if IsRaidModeActive(ctx) then
      return
    end
    if not UnitAuraUpdateRequiresCdScan(unitAuraUpdateInfo) then
      return
    end
    ctx.updateCdTracker({ playLustSoundOnStart = true })
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
    PLAYER_ROLES_ASSIGNED = HandlePlayerRolesAssignedEvent,
    ROLE_CHANGED_INFORM = HandlePlayerRolesAssignedEvent,
    INSPECT_READY = HandleInspectReadyEvent,
    CHAT_MSG_ADDON = HandleChatMsgAddonEvent,
    CONFIRM_SUMMON = function(_self)
      HandleConfirmSummonSound(ctx)
    end,
    INCOMING_SUMMON_CHANGED = function(_self, unitTarget)
      HandleIncomingSummonChangedSound(ctx, unitTarget)
    end,
    SPELL_UPDATE_COOLDOWN = HandleSpellUpdateCooldownEvent,
    SPELL_UPDATE_CHARGES = HandleSpellUpdateChargesEvent,
    UNIT_AURA = HandleUnitAuraEvent,
    SPELLS_CHANGED = BuildNonRaidEventForwarder(ctx, "handleKickTrackerEvent", "SPELLS_CHANGED"),
    UNIT_PET = BuildNonRaidEventForwarder(ctx, "handleKickTrackerEvent", "UNIT_PET"),
    UNIT_SPELLCAST_SUCCEEDED = BuildUnitSpellcastSucceededForwarder(ctx),
    UNIT_HEALTH = BuildNonRaidEventForwarder(ctx, "handleDeathWatchEvent", "UNIT_HEALTH"),
    SCENARIO_CRITERIA_UPDATE = BuildNonRaidEventForwarder(ctx, "handleKillTrackEvent", "SCENARIO_CRITERIA_UPDATE"),
    CHALLENGE_MODE_DEATH_COUNT_UPDATED = BuildNonRaidEventForwarder(
      ctx,
      "handleMplusTimerEvent",
      "CHALLENGE_MODE_DEATH_COUNT_UPDATED"
    ),
    PARTY_LEADER_CHANGED = BuildPartyLeaderChangedForwarder(ctx),
  }
end
