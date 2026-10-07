local _, addonTable = ...

addonTable = addonTable or {}

local RuntimeLifecycle = {}
addonTable.EventHandlersRuntimeLifecycle = RuntimeLifecycle
local ChallengeLifecycle = addonTable.EventHandlersChallengeLifecycle
local IsSecretValue = addonTable.Validators.IsSecretValue
-- Tracked M0 party run lifecycle: logic/isiLive_event_handlers_party_run.lua.
local PartyRun = assert(addonTable.EventHandlersPartyRun, "isiLive: EventHandlersPartyRun missing")
local ClearTrackedPartyRunState = PartyRun.ClearTrackedPartyRunState
local UpdateTrackedMythicZeroRun = PartyRun.UpdateTrackedMythicZeroRun
local CaptureTrackedMythicZeroRosterSnapshotIfPending = PartyRun.CaptureTrackedMythicZeroRosterSnapshotIfPending
-- Player UNIT_AURA filter + shared CD coalescer:
-- logic/isiLive_event_handlers_cd_coalescer.lua.
local CdCoalescer = assert(addonTable.EventHandlersCdCoalescer, "isiLive: EventHandlersCdCoalescer missing")
local UnitAuraUpdateRequiresCdScan = CdCoalescer.UnitAuraUpdateRequiresCdScan
local BuildSpellCooldownCoalescer = CdCoalescer.BuildSpellCooldownCoalescer
local IsRaidModeActive
local INCOMING_SUMMON_SOUND_LOOP_SECONDS = 5
-- The client repeats the no-path error for every pet order that fails, so one
-- stuck pet can raise it several times per second while the player spams
-- /petattack. One voice alert per window is enough to get noticed.
local PET_STUCK_SOUND_COOLDOWN_SECONDS = 5

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
  if not ok or IsSecretValue(status) then
    return false
  end
  local pending = GetPendingSummonStatusValue()
  return pending ~= nil and status == pending
end

-- Raids keep the hard-off (rule 11) unless the player opted this alert into
-- raid groups (rule 144). Outside raids nothing changes.
local function IsRaidSoundBlocked(ctx, soundKey)
  if not IsRaidModeActive(ctx) then
    return false
  end
  return type(ctx.isRaidSoundOptInEnabled) ~= "function" or ctx.isRaidSoundOptInEnabled(soundKey) ~= true
end

local function StopIncomingSummonSoundLoop(ctx)
  local ticker = ctx.incomingSummonSoundLoopTicker
  ctx.incomingSummonSoundLoopTicker = nil
  if ticker and type(ticker.Cancel) == "function" then
    ticker:Cancel()
  end
end

local function StartIncomingSummonSoundLoopIfPending(ctx)
  if type(ctx.isIncomingSummonSoundLoopEnabled) == "function" and ctx.isIncomingSummonSoundLoopEnabled() ~= true then
    StopIncomingSummonSoundLoop(ctx)
    return
  end
  if ctx.incomingSummonSoundLoopTicker then
    return
  end
  if not IsPlayerIncomingSummonPending("player") then
    return
  end

  local timer = rawget(_G, "C_Timer")
  local newTicker = type(timer) == "table" and timer.NewTicker or nil
  if type(newTicker) ~= "function" then
    return
  end

  ctx.incomingSummonSoundLoopTicker = newTicker(INCOMING_SUMMON_SOUND_LOOP_SECONDS, function()
    if
      IsRaidSoundBlocked(ctx, "portal_available")
      or (type(ctx.isIncomingSummonSoundLoopEnabled) == "function" and ctx.isIncomingSummonSoundLoopEnabled() ~= true)
      or not IsPlayerIncomingSummonPending("player")
    then
      StopIncomingSummonSoundLoop(ctx)
      return
    end
    ctx.playIncomingSummonSound()
  end)
end

local function HandleConfirmSummonSound(ctx)
  if IsRaidSoundBlocked(ctx, "portal_available") then
    return
  end
  ctx.playIncomingSummonSound()
  StartIncomingSummonSoundLoopIfPending(ctx)
end

local function HandleIncomingSummonChangedSound(ctx, unitTarget)
  if IsRaidSoundBlocked(ctx, "portal_available") then
    StopIncomingSummonSoundLoop(ctx)
    return
  end
  if not IsPlayerIncomingSummonPending(unitTarget) then
    if unitTarget == "player" then
      StopIncomingSummonSoundLoop(ctx)
    end
    return
  end
  ctx.playIncomingSummonSound()
  StartIncomingSummonSoundLoopIfPending(ctx)
end

-- Matches the error text against the client's own localized global instead of
-- a hard-coded string, so every client locale is covered. The payload is not
-- documented as secret, but it is checked first anyway: comparing a Secret
-- Value raises and would taint the whole dispatch.
local function IsPetNoPathError(message)
  if IsSecretValue(message) or type(message) ~= "string" then
    return false
  end
  local noPathText = rawget(_G, "ERR_PET_SPELL_NOPATH")
  return type(noPathText) == "string" and noPathText ~= "" and message == noPathText
end

local function HandlePetStuckErrorSound(ctx, message)
  if IsRaidSoundBlocked(ctx, "pet_stuck") or not IsPetNoPathError(message) then
    return
  end
  local getTime = rawget(_G, "GetTime")
  local now = type(getTime) == "function" and getTime() or 0
  local last = ctx.lastPetStuckSoundAt
  if last and (now - last) < PET_STUCK_SOUND_COOLDOWN_SECONDS then
    return
  end
  ctx.lastPetStuckSoundAt = now
  ctx.playPetStuckSound()
end

-- The client reports a removal from the group only as the localized system
-- message ERR_UNINVITE_YOU; matching the client's own global covers every
-- locale without a hard-coded text. Chat payloads can be Secret Values, so the
-- check runs before any comparison.
local function IsRemovedFromGroupMessage(message)
  if IsSecretValue(message) or type(message) ~= "string" then
    return false
  end
  local removedText = rawget(_G, "ERR_UNINVITE_YOU")
  return type(removedText) == "string" and removedText ~= "" and message == removedText
end

-- Deliberately not raid-gated: being removed matters in a raid as much as in a
-- party, and the message itself ends the raid context.
local function HandleGroupRemovedSystemMessage(ctx, message)
  if not IsRemovedFromGroupMessage(message) then
    return
  end
  ctx.playGroupRemovedSound()
end

-- applyHotkeyBindings is intentionally called multiple times on startup
-- (ADDON_LOADED / PLAYER_LOGIN via ApplyBindingStartupRefresh, and
-- PLAYER_ENTERING_WORLD + 2 delayed via ScheduleBindingStartupRefresh)
-- to reliably catch timing issues with the WoW binding system.
-- PLAYER_LOGIN visibility, including the raid case.
--
-- Outside a raid the frame opens per the startup setting. Inside one it stays
-- closed, but the restore has to be armed: logging in or reloading while
-- already in a raid never passes through the "group grew past five" moment that
-- normally records whether the frame was up, so leaving the raid used to leave
-- the UI dark until the next /reload. Startup is the only place that knows it
-- would have shown the frame if the raid were not there.
local function ApplyStartupMainFrameVisibility(ctx)
  local wantsStartupFrame = ctx.shouldShowMainFrameOnStartup()
  if not IsRaidModeActive(ctx) then
    ctx.handleBloodlustButtonWarningEvent("PLAYER_LOGIN")
    if wantsStartupFrame then
      ctx.setMainFrameVisible(true)
    end
    return
  end
  if wantsStartupFrame and type(ctx.armMainFrameRestoreAfterRaid) == "function" then
    ctx.armMainFrameRestoreAfterRaid()
  end
end

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
  local timer = rawget(_G, "C_Timer")
  if type(timer) ~= "table" or type(timer.NewTicker) ~= "function" then
    mainFrame:SetAlpha(targetAlpha)
    return
  end
  activeFadeTicker = timer.NewTicker(COMBAT_FADE_TICK, function()
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
  return layoutMode == "compact_main_horizontal" or layoutMode == "expanded"
end

local function ApplyCombatFade(ctx, targetAlpha)
  local db = GetDB()
  if not db or db.combatFadeMM ~= true then
    return
  end
  local fallbackLayout = "compact_main_horizontal"
  local layoutMode = db.rosterLayoutMode or fallbackLayout
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
  ctx.handleDeathWatchEvent("CHALLENGE_MODE_RESET")
  ctx.updateCdTracker({
    suppressBattleResReadySound = true,
    suppressLustReadySound = true,
    resetRuntimeTimers = true,
  })
  if ctx.isMainFrameShown() then
    ctx.updateUI()
  end
  return true
end

local function ResetChallengeRuntimeOnPartyInstanceExit(ctx, wasInPartyInstance, inPartyInstance)
  if wasInPartyInstance ~= true or inPartyInstance == true then
    return false
  end

  ctx.handleMplusTimerEvent("CHALLENGE_MODE_RESET")
  ctx.handleDeathWatchEvent("CHALLENGE_MODE_RESET")
  ctx.updateCdTracker({
    suppressBattleResReadySound = true,
    suppressLustReadySound = true,
    resetRuntimeTimers = true,
  })
  if ctx.isMainFrameShown() then
    ctx.updateUI()
  end
  return true
end

local function BuildPlayerEnteringWorldCdTrackerOptions(wasInPartyInstance, inPartyInstance)
  if inPartyInstance == true and wasInPartyInstance ~= true then
    return {
      suppressBattleResReadySound = true,
      suppressLustReadySound = true,
    }
  end
  return nil
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

-- The peer-state fan-out is a group broadcast, so one per window serves every
-- peer. Before, every client answered every HELLO and every REQSYNC with a
-- full fan-out: on a roster change in a five-player isiLive group that was one
-- fan-out per peer pair (N squared), and a join drew a second round from the
-- joiner's REQSYNC half a second later.
--   * HELLO from a peer never synced with: always answered (it needs the data).
--   * HELLO from a known peer: skipped when this client fanned out within the
--     last PEER_FAN_OUT_KNOWN_PEER_SECONDS.
--   * REQSYNC: skipped when this client fanned out within the last
--     PEER_FAN_OUT_REQSYNC_SECONDS (typically the joiner's own HELLO).
-- LibKeystone "R" requests are answered with a group broadcast too, so one
-- reply per LIBKEYSTONE_REPLY_MIN_INTERVAL_SECONDS serves every requester.
-- Without a time source every request is answered as before.
local PEER_FAN_OUT_KNOWN_PEER_SECONDS = 10
local PEER_FAN_OUT_REQSYNC_SECONDS = 3
local LIBKEYSTONE_REPLY_MIN_INTERVAL_SECONDS = 2

local function BuildSyncReplyThrottles(ctx)
  local lastPeerFanOutAt = nil
  local lastLibKeystoneReplyAt = nil

  local function Now()
    return type(ctx.getTime) == "function" and tonumber(ctx.getTime()) or nil
  end

  local function IsInsideWindow(lastAt, now, window)
    return window ~= nil and lastAt ~= nil and now >= lastAt and now - lastAt < window
  end

  local function ShouldSendPeerFanOut(kind, senderWasKnown)
    local now = Now()
    if not now then
      return true
    end
    local window = nil
    if kind == "reqsync" then
      window = PEER_FAN_OUT_REQSYNC_SECONDS
    elseif senderWasKnown then
      window = PEER_FAN_OUT_KNOWN_PEER_SECONDS
    end
    if IsInsideWindow(lastPeerFanOutAt, now, window) then
      return false
    end
    lastPeerFanOutAt = now
    return true
  end

  local function ShouldReplyLibKeystone()
    local now = Now()
    if not now then
      return true
    end
    if IsInsideWindow(lastLibKeystoneReplyAt, now, LIBKEYSTONE_REPLY_MIN_INTERVAL_SECONDS) then
      return false
    end
    lastLibKeystoneReplyAt = now
    return true
  end

  return ShouldSendPeerFanOut, ShouldReplyLibKeystone
end

-- A running peer kick cooldown changes the roster on every packet (and on
-- every decay step a later packet observes). Kick state is neither part of the
-- reload mirror nor of the status line or teleport button, so a change that
-- touches only kick fields refreshes just the kick column. Everything else --
-- target, isiLive marker, key, stats, DPS, location -- keeps the full refresh.
local function ApplySyncRosterChanges(ctx, syncResult)
  local fullRefresh = syncResult.targetUpdated == true
  local kickChanged = syncResult.kickUpdated == true
  ctx.forEachRosterInfo(function(info)
    if not info.hasIsiLive and ctx.isSyncUserKnown(info.name, info.realm) then
      info.hasIsiLive = true
      fullRefresh = true
    end
    local anyChanged, nonKickChanged = ctx.applyKnownKeyToRosterEntry(info)
    if anyChanged then
      if nonKickChanged == false then
        kickChanged = true
      else
        fullRefresh = true
      end
    end
  end)
  if not fullRefresh and kickChanged and ctx.refreshKickColumn() ~= true then
    fullRefresh = true
  end
  if fullRefresh then
    ctx.updateStatusLine()
    ctx.updateMPlusTeleportButton()
    if type(ctx.saveReloadRosterMirror) == "function" then
      ctx.saveReloadRosterMirror()
    end
    ctx.updateUI()
  end
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

-- Mirrors the current raid state onto the dispatcher's event registration.
-- The per-handler early-outs stay in place as the correctness contract; this
-- only removes the dispatch traffic that would reach them. Called from the two
-- events that survive the hard-off, so the addon can always wake up again.
local function ApplyRaidEventSuppression(ctx)
  local bootstrap = addonTable.Bootstrap
  if type(bootstrap) ~= "table" or type(bootstrap.ApplyRaidEventSuppression) ~= "function" then
    return false
  end
  local ok, changed = pcall(bootstrap.ApplyRaidEventSuppression, IsRaidModeActive(ctx))
  return ok and changed == true
end

local function BuildNonRaidEventForwarder(ctx, handlerName, eventName)
  return function(_self, ...)
    if not IsRaidModeActive(ctx) then
      ctx[handlerName](eventName, ...)
    end
  end
end

-- The M+ timer needs Blizzard's own death count; DeathWatch uses the same tick
-- as an extra sampling point for the per-player attribution, which the
-- UNIT_HEALTH stream alone can miss.
local function BuildChallengeModeDeathCountForwarder(ctx)
  return function(_self, ...)
    if not IsRaidModeActive(ctx) then
      ctx.handleMplusTimerEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED", ...)
      ctx.handleDeathWatchEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED", ...)
    end
  end
end

local function BuildUnitSpellcastSucceededForwarder(ctx)
  return function(_self, ...)
    if not IsRaidModeActive(ctx) then
      ctx.handleKickTrackerEvent("UNIT_SPELLCAST_SUCCEEDED", ...)
      ctx.handleCombatEventsEvent("UNIT_SPELLCAST_SUCCEEDED", ...)
      ctx.handleVipDkAssistEvent("UNIT_SPELLCAST_SUCCEEDED", ...)
    end
  end
end

local function BuildUnitPetForwarder(ctx)
  return function(_self, ...)
    if not IsRaidModeActive(ctx) then
      ctx.handleKickTrackerEvent("UNIT_PET", ...)
      ctx.handleVipDkAssistEvent("UNIT_PET", ...)
    end
  end
end

local function BuildPartyLeaderChangedForwarder(ctx)
  return function(_self, ...)
    if IsRaidModeActive(ctx) then
      -- Only the gate exception for the raid lead-transfer opt-in lets this
      -- event through in a raid (rule 144). The leader watch gates its sound
      -- itself; the M+ target pipeline in LFGDetect stays closed.
      ctx.handleLeaderWatchEvent("PARTY_LEADER_CHANGED", ...)
    else
      ctx.handleLeaderWatchEvent("PARTY_LEADER_CHANGED", ...)
      -- Forward to LFGDetect so the stale activeInviteLeader / -TitleLevel
      -- (captured when the previous leader's listing was accepted) is
      -- dropped; the new leader is its own authority and must be resolved via
      -- UnitIsGroupLeader by downstream consumers.
      ctx.handleLFGDetectEvent("PARTY_LEADER_CHANGED")
    end
  end
end

local function ApplyPendingMainFrameSize(ctx)
  local pendingMainFrameHeight = ctx.getPendingMainFrameHeight()
  if pendingMainFrameHeight then
    ctx.setMainFrameHeightSafe(pendingMainFrameHeight)
  end
  local pendingMainFrameWidth = ctx.getPendingMainFrameWidth()
  if pendingMainFrameWidth then
    ctx.setMainFrameWidthSafe(pendingMainFrameWidth)
  end
  -- Scale and position changes requested during combat (UI-scale slider,
  -- /isilive resetui) are queued by the main frame and applied here.
  if type(ctx.applyPendingMainFrameGeometry) == "function" then
    ctx.applyPendingMainFrameGeometry()
  end
end

--- Restores the main frame geometry that only becomes readable once WoW has
--- handed back SavedVariables. Split out of HandleAddonLoaded purely to keep
--- RuntimeLifecycle.BuildHandlers under the 420-line metrics gate.
local function RestoreMainFrameFromSavedVariables(ctx)
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
end

--- ADDON_LOADED body. Lives outside BuildHandlers so the handler table stays
--- under the 420-line metrics gate; it closes over nothing but its arguments.
local function HandleAddonLoaded(ctx, loadedAddon)
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

  RestoreMainFrameFromSavedVariables(ctx)

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

function RuntimeLifecycle.BuildHandlers(ctx)
  ctx.handleLFGDetectEvent = ResolveEventHandler(ctx.handleLFGDetectEvent)
  ctx.handleKillTrackEvent = ResolveEventHandler(ctx.handleKillTrackEvent)
  ctx.handleCombatEventsEvent = ResolveEventHandler(ctx.handleCombatEventsEvent)
  ctx.handleDeathWatchEvent = ResolveEventHandler(ctx.handleDeathWatchEvent)
  ctx.handleKickTrackerEvent = ResolveEventHandler(ctx.handleKickTrackerEvent)
  ctx.handleBloodlustButtonWarningEvent = ResolveEventHandler(ctx.handleBloodlustButtonWarningEvent)
  ctx.handleVipDkAssistEvent = ResolveEventHandler(ctx.handleVipDkAssistEvent)
  ctx.handleMplusTimerEvent = ResolveEventHandler(ctx.handleMplusTimerEvent)
  ctx.handleLeaderWatchEvent = ResolveEventHandler(ctx.handleLeaderWatchEvent)

  -- Raid state seen by the previous GROUP_ROSTER_UPDATE. A forming or running
  -- raid fires this event for every join, leave and subgroup move; once the
  -- transition into the raid has been handled, the hard-off (rule 11) leaves
  -- only the roster hide and the leader watch (raid lead-transfer alert) with
  -- work to do.
  local lastRosterUpdateInRaid = false

  local function HandleGroupRosterUpdateEvent(frame)
    ApplyRaidEventSuppression(ctx)
    if ctx.isInGroup() and (ctx.isTestMode() or ctx.isTestAllMode()) then
      ctx.exitTestMode()
      return
    end

    local inRaidNow = IsRaidModeActive(ctx)
    local steadyRaid = inRaidNow and lastRosterUpdateInRaid
    lastRosterUpdateInRaid = inRaidNow
    if steadyRaid then
      ctx.handleGroupRosterUpdate()
      ctx.handleLeaderWatchEvent("GROUP_ROSTER_UPDATE")
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
    ctx.handleKickTrackerEvent("GROUP_ROSTER_UPDATE")
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
    HandleAddonLoaded(ctx, loadedAddon)
  end

  local function HandlePlayerLoginEvent(_self)
    ctx.refreshActiveSeasonFromBlizzard("PLAYER_LOGIN")
    ApplyBindingStartupRefresh(ctx)
    ctx.handleLFGDetectEvent("PLAYER_LOGIN")
    ApplyStartupMainFrameVisibility(ctx)
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
    ApplyRaidEventSuppression(ctx)
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
      ClearTrackedPartyRunState(ctx)
      ctx.wasInPartyInstance = inPartyInstance
      return
    end
    ctx.handleBloodlustButtonWarningEvent("PLAYER_ENTERING_WORLD")
    ctx.handleKillTrackEvent("PLAYER_ENTERING_WORLD")
    ctx.handleMplusTimerEvent("PLAYER_ENTERING_WORLD")
    local didResetChallengeRuntime =
      ResetChallengeRuntimeOnInactiveInstanceEntry(ctx, wasInPartyInstance, inPartyInstance)
    if not didResetChallengeRuntime then
      didResetChallengeRuntime = ResetChallengeRuntimeOnPartyInstanceExit(ctx, wasInPartyInstance, inPartyInstance)
    end
    if not didResetChallengeRuntime then
      ctx.updateCdTracker(BuildPlayerEnteringWorldCdTrackerOptions(wasInPartyInstance, inPartyInstance))
    end
    UpdateTrackedMythicZeroRun(ctx)
    -- Leaving the group or the instance mid-key produces no completion info and
    -- no CHALLENGE_MODE_RESET, so this is the only moment an abandoned run can
    -- still be recorded -- the damage meter keeps the session past the exit.
    if type(ChallengeLifecycle) == "table" and type(ChallengeLifecycle.TryRecordAbandonedRun) == "function" then
      ChallengeLifecycle.TryRecordAbandonedRun(ctx)
    end
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
    -- True when the deferred show just ran its own post-combat roster refresh
    -- (OnShow render plus the in-group show callback); the full update below
    -- would only repeat it in the same frame.
    local shownWithRefresh = false
    if pendingVisible ~= nil then
      if IsRaidModeActive(ctx) then
        ctx.setMainFrameVisible(false)
      else
        shownWithRefresh = ctx.setMainFrameVisible(pendingVisible) == true
          and pendingVisible == true
          and ctx.isInGroup() == true
      end
    end
    ctx.handleKickTrackerEvent("PLAYER_REGEN_ENABLED")
    ctx.handleBloodlustButtonWarningEvent("PLAYER_REGEN_ENABLED")
    ctx.handleVipDkAssistEvent("PLAYER_REGEN_ENABLED")
    ctx.handleKillTrackEvent("PLAYER_REGEN_ENABLED")
    ApplyCombatFade(ctx, 1)
    if IsRaidModeActive(ctx) then
      return
    end
    ctx.refreshActiveSeasonFromBlizzard("PLAYER_REGEN_ENABLED")
    ApplyPendingMainFrameSize(ctx)
    ApplyPendingLeaderButtonUpdates(ctx)
    if ctx.isMainFrameShown() then
      -- Out of combat again: this render rewrites role-button macros that went
      -- stale during lockdown, unless the deferred show above already did.
      if not shownWithRefresh then
        ctx.updateUI()
      end
      ctx.updateMPlusTeleportButton()
      ctx.tryRestoreCenterNoticeTeleportButton()
    end
  end

  local function HandleInstanceContextChangedEvent(_self)
    -- Before the raid gate: a cached in-key answer from before the raid must
    -- not outlive the zone it was read in.
    ctx.handleCombatEventsEvent("INSTANCE_CONTEXT_CHANGED")
    if IsRaidModeActive(ctx) then
      return
    end
    ctx.updateCdTracker()
    UpdateTrackedMythicZeroRun(ctx)
    -- The line above can start or clear the tracked party run, which is one of
    -- the inputs to DeathWatch's cached in-key answer. Invalidate it here; a
    -- full CHALLENGE_MODE_RESET would also wipe the run's death counts.
    ctx.handleDeathWatchEvent("INSTANCE_CONTEXT_CHANGED")
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

  local function HandleChallengeModeMapsUpdateEvent(self)
    ctx.refreshActiveSeasonFromBlizzard("CHALLENGE_MODE_MAPS_UPDATE")
    HandleOwnedKeyContextEvent(self)
  end

  local function HandlePlayerSpecializationChangedEvent(_self, unit)
    if unit ~= nil and unit ~= "player" then
      return
    end
    if IsRaidModeActive(ctx) then
      return
    end
    ctx.handleKickTrackerEvent("PLAYER_SPECIALIZATION_CHANGED", unit)
    ctx.handleBloodlustButtonWarningEvent("PLAYER_SPECIALIZATION_CHANGED", unit)
    ctx.handleVipDkAssistEvent("PLAYER_SPECIALIZATION_CHANGED", unit)
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

  local ShouldSendPeerFanOut, ShouldReplyLibKeystone = BuildSyncReplyThrottles(ctx)

  local function HandleChatMsgAddonEvent(_self, prefix, message, channel, sender)
    -- Boss mods, meters and WeakAuras share the group addon channel; their
    -- messages are dropped before the raid check and the player-name lookup.
    if type(ctx.isSyncPrefix) == "function" and not ctx.isSyncPrefix(prefix) then
      return
    end
    if IsRaidModeActive(ctx) then
      return
    end
    local syncResult = ctx.processAddonMessage(prefix, message, sender, channel)
    if not syncResult then
      return
    end

    if syncResult.shouldReplyLibKeystone and ShouldReplyLibKeystone() then
      ctx.sendLibKeystonePartyData(true)
    end
    if syncResult.shouldAck then
      ctx.sendAck(syncResult.sender)
      -- New peer detected: send the full own-state fan-out immediately.
      if ShouldSendPeerFanOut("hello", syncResult.senderWasKnown == true) then
        SendPeerStateFanOut(ctx, "hello-ack", "hello")
      end
    end
    if syncResult.shouldRequestRefresh and ShouldSendPeerFanOut("reqsync", false) then
      SendPeerStateFanOut(ctx, "reqsync-ack", "reqsync")
    end
    if syncResult.shouldShareKeys then
      HandleShareKeysRequest(ctx, syncResult, sender)
    end
    ApplyMirroredShareKeysCooldown(ctx, syncResult)
    if syncResult.combatAnnounce then
      ctx.showCombatAnnounce(syncResult.combatAnnounce)
    end
    if syncResult.powerInfusionAnnounce then
      ctx.showPowerInfusionAnnounce(syncResult.powerInfusionAnnounce)
    end

    if type(ctx.registerVerifiedSyncAliasForRoster) == "function" then
      ctx.registerVerifiedSyncAliasForRoster(ctx.getRoster(), syncResult.sender)
    end

    ApplySyncRosterChanges(ctx, syncResult)
  end

  local function IsCoalescerRaidActive()
    return IsRaidModeActive(ctx)
  end
  local HandleSpellUpdateCooldownEvent, HandleSpellUpdateChargesEvent, SchedulePlayerAuraCdScan =
    BuildSpellCooldownCoalescer(ctx, IsCoalescerRaidActive)

  local function HandleUnitAuraEvent(_self, unit, unitAuraUpdateInfo)
    if IsRaidModeActive(ctx) then
      return
    end
    ctx.handlePiTrackerEvent("UNIT_AURA", unit, unitAuraUpdateInfo)
    if unit ~= "player" then
      return
    end
    if not UnitAuraUpdateRequiresCdScan(unitAuraUpdateInfo) then
      return
    end
    SchedulePlayerAuraCdScan()
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
    CHALLENGE_MODE_MAPS_UPDATE = HandleChallengeModeMapsUpdateEvent,
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
    UI_ERROR_MESSAGE = function(_self, _errorType, message)
      HandlePetStuckErrorSound(ctx, message)
    end,
    CHAT_MSG_SYSTEM = function(_self, message)
      HandleGroupRemovedSystemMessage(ctx, message)
    end,
    SPELL_UPDATE_COOLDOWN = HandleSpellUpdateCooldownEvent,
    SPELL_UPDATE_CHARGES = HandleSpellUpdateChargesEvent,
    UNIT_AURA = HandleUnitAuraEvent,
    SPELLS_CHANGED = BuildNonRaidEventForwarder(ctx, "handleKickTrackerEvent", "SPELLS_CHANGED"),
    UNIT_PET = BuildUnitPetForwarder(ctx),
    UNIT_SPELLCAST_SUCCEEDED = BuildUnitSpellcastSucceededForwarder(ctx),
    UNIT_HEALTH = BuildNonRaidEventForwarder(ctx, "handleDeathWatchEvent", "UNIT_HEALTH"),
    PLAYER_DEAD = BuildNonRaidEventForwarder(ctx, "handleDeathWatchEvent", "PLAYER_DEAD"),
    PLAYER_ALIVE = BuildNonRaidEventForwarder(ctx, "handleDeathWatchEvent", "PLAYER_ALIVE"),
    PLAYER_UNGHOST = BuildNonRaidEventForwarder(ctx, "handleDeathWatchEvent", "PLAYER_UNGHOST"),
    SCENARIO_CRITERIA_UPDATE = BuildNonRaidEventForwarder(ctx, "handleKillTrackEvent", "SCENARIO_CRITERIA_UPDATE"),
    CHALLENGE_MODE_DEATH_COUNT_UPDATED = BuildChallengeModeDeathCountForwarder(ctx),
    PARTY_LEADER_CHANGED = BuildPartyLeaderChangedForwarder(ctx),
  }
end
