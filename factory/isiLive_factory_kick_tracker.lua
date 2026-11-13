local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

-- Missed kick ("Kick ins Leere", rule 236), wired by the kick tracker below.
-- After the own interrupt cast the controller arms a short window; a hostile
-- interrupt event inside it means the kick landed, none means it went into the
-- void. Only the event timestamp counts -- interruptedBy is secret inside keys
-- and is never compared or converted.
-- Probe mode (rule 239): looked up per call; off costs one boolean check.
local function ActiveProbe()
  local probe = addonTable.ProbeLog
  if type(probe) == "table" and probe.IsEnabled() then
    return probe
  end
  return nil
end

local function CreateMissedKickAlert(ctx, IsRaidModeActive, HasActiveChallengeFromBridge, timerAfter)
  local function IsMissedKickAlertEnabled()
    local db = rawget(_G, "IsiLiveDB")
    return type(db) == "table" and db.missedKickAlertEnabled == true
  end

  local function IsPlayerInCombat()
    local inCombatLockdown = rawget(_G, "InCombatLockdown")
    if type(inCombatLockdown) ~= "function" then
      return false
    end
    local ok, inCombat = pcall(inCombatLockdown)
    return ok and not addonTable.Validators.IsSecretValue(inCombat) and inCombat == true
  end

  local function IsMissedKickAlertContextActive()
    if not IsMissedKickAlertEnabled() or IsRaidModeActive() or not IsPlayerInCombat() then
      return false
    end
    local db = rawget(_G, "IsiLiveDB")
    -- missedKickOnlyInKey is Pattern A (default on): restricting a combat
    -- alert to keystones is the expected default once the alert is enabled.
    if db.missedKickOnlyInKey ~= false and not HasActiveChallengeFromBridge() then
      return false
    end
    return true
  end

  local function IsHostileInterruptUnitToken(unit)
    return unit == "target"
      or unit == "focus"
      or string.find(unit, "^nameplate%d+$") ~= nil
      or string.find(unit, "^boss%d+$") ~= nil
  end

  -- Unreadable data counts as hostile: a counted interrupt can only suppress
  -- an alert, never raise a false one.
  local function IsHostileInterruptUnit(unit)
    if addonTable.Validators.IsSecretValue(unit) then
      return true
    end
    if type(unit) ~= "string" or not IsHostileInterruptUnitToken(unit) then
      return false
    end
    local unitCanAttack = rawget(_G, "UnitCanAttack")
    if type(unitCanAttack) ~= "function" then
      return true
    end
    local ok, canAttack = pcall(unitCanAttack, "player", unit)
    if not ok or addonTable.Validators.IsSecretValue(canAttack) then
      return true
    end
    return canAttack == true
  end

  -- UNIT_SPELLCAST_CHANNEL_STOP also fires for channels that simply end; the
  -- 12.0 interruptedBy argument is only present for an interrupted one. A
  -- secret value is present but masked and counts; it is never read further.
  local function IsInterruptedChannelStop(interruptedBy)
    if addonTable.Validators.IsSecretValue(interruptedBy) then
      return true
    end
    return type(interruptedBy) == "string" and interruptedBy ~= ""
  end

  -- The run's missed-kick count (rule 240) needs a verdict for every own
  -- kick of a running key, also with the alert off. The cheap counter check
  -- comes first; the challenge map is read only while a run count is active.
  local function IsRunMissedCountActive(controller)
    return controller ~= nil
      and type(controller.IsRunKickCounting) == "function"
      and controller.IsRunKickCounting()
      and HasActiveChallengeFromBridge()
  end

  -- Probe mode (rule 239) records the same filtered interrupts for the kick
  -- calibration, also while the alert itself is off.
  local function HandleHostileInterruptEvent(event, unit, interruptedBy)
    local controller = ctx.kickTrackerController
    local recordOn = controller ~= nil
      and type(controller.OnHostileInterrupt) == "function"
      and (IsMissedKickAlertEnabled() or IsRunMissedCountActive(controller))
    local probe = ActiveProbe()
    if not recordOn and not probe then
      return
    end
    local isChannelStop = event == "UNIT_SPELLCAST_CHANNEL_STOP"
    if isChannelStop and probe and IsHostileInterruptUnit(unit) then
      -- Every hostile channel end, kicked or not: is interruptedBy set?
      probe.OnChannelStop(unit, interruptedBy)
    end
    if isChannelStop and not IsInterruptedChannelStop(interruptedBy) then
      return
    end
    if not IsHostileInterruptUnit(unit) then
      return
    end
    if probe then
      probe.OnHostileInterrupt(event)
    end
    if recordOn then
      controller.OnHostileInterrupt()
    end
  end

  -- Probe mode (rule 239): the own cast's readability and, for a kick, the
  -- calibration record. Reads the armed kick before ScheduleMissedKickCheck
  -- may cancel it (alert off).
  local function ProbeOwnCast(unit, castGUID, spellID, observedKick)
    local probe = ActiveProbe()
    if not probe then
      return
    end
    probe.OnOwnCast(unit, castGUID, spellID, observedKick)
    local controller = ctx.kickTrackerController
    if observedKick and controller and type(controller.GetPendingMissedKick) == "function" then
      probe.OnOwnKick(spellID, controller.GetPendingMissedKick(), IsMissedKickAlertEnabled())
    end
  end

  local function ScheduleMissedKickCheck()
    local controller = ctx.kickTrackerController
    if not controller or type(controller.GetPendingMissedKick) ~= "function" then
      return
    end
    local pending = controller.GetPendingMissedKick()
    if type(pending) ~= "table" then
      return
    end
    -- The alert needs its context at the kick and at the verdict; the run
    -- count (rule 240) only needs a running key at the kick.
    local alertAtKick = IsMissedKickAlertContextActive()
    local countAtKick = IsRunMissedCountActive(controller)
    if type(timerAfter) ~= "function" then
      if countAtKick then
        controller.MarkRunMissedUnknown()
      end
      controller.CancelMissedKick()
      return
    end
    if not alertAtKick and not countAtKick then
      controller.CancelMissedKick()
      return
    end
    local seq = pending.seq
    timerAfter(pending.window, function()
      local current = ctx.kickTrackerController
      if not current or current.ResolveMissedKick(seq) ~= "missed" then
        return
      end
      if alertAtKick and IsMissedKickAlertContextActive() and type(ctx.ShowMissedKickAlert) == "function" then
        ctx.ShowMissedKickAlert()
      end
    end)
  end

  return {
    HandleHostileInterruptEvent = HandleHostileInterruptEvent,
    ScheduleMissedKickCheck = ScheduleMissedKickCheck,
    ProbeOwnCast = ProbeOwnCast,
  }
end

-- Run kicks (rule 238), published on the shared modules table that the
-- event-handler wiring reads: the key start resets the own cast count and
-- hides the previous run's kicks; the key end reads the count for the
-- snapshot.
local function InstallRunKickHooks(ctx, modules)
  modules.runKicks = {
    -- kind "m0": an M0 run only hides the last key's run kicks; the own cast
    -- count stays a key-only value and is not reset there.
    ResetForKey = function(kind)
      if kind ~= "m0" then
        ctx.kickTrackerController.ResetRunKickAttempts()
      end
      local stats = ctx.statsController
      if type(stats) == "table" and type(stats.MarkRunStarted) == "function" then
        stats.MarkRunStarted()
      end
    end,
    -- Returns the own casts and the own missed kicks (rule 240) of the run.
    GetAttempts = function()
      local controller = ctx.kickTrackerController
      return controller.GetRunKickAttempts(), controller.GetRunKickMissed()
    end,
  }
end

local function InitializeFactorySecondaryKickTracker(
  ctx,
  modules,
  getTime,
  getUnitName,
  getRealmName,
  IsMainFrameShown,
  IsRaidModeActive,
  IsGroupSyncActive
)
  local kickTrackerModule = ctx.addonTable and ctx.addonTable.KickTracker
  if not (kickTrackerModule and type(kickTrackerModule.CreateController) == "function") then
    return
  end

  local KICK_HEARTBEAT_INTERVAL = 15
  local kickReadyBroadcastUntil = 0
  local kickHeartbeatAt = 0
  local kickTrackerSuppressedByRaid = false
  local kickTrackerRecoveryInProgress = false
  local C_Timer_ref = rawget(_G, "C_Timer")
  local timerAfter = type(C_Timer_ref) == "table" and C_Timer_ref.After or nil

  -- Own kick state as last written to Sync. The 0.5 s poll used to rewrite it
  -- every tick (key normalization plus a fresh entry table) although the
  -- stored remain decays on its own. It is rewritten on a real change, after
  -- the entry was dropped elsewhere (Sync's kick generation moved), and at
  -- least every OWN_KICK_REFRESH_SECONDS so it never ages past the 45 s
  -- stale window of rule 50. Extras-carrying states are always written.
  local OWN_KICK_REFRESH_SECONDS = 10
  local ownKickWritten = { valid = false }

  local function GetKickInfoGeneration()
    if modules.sync and type(modules.sync.GetKickInfoGeneration) == "function" then
      return modules.sync.GetKickInfoGeneration()
    end
    return nil
  end

  local function OwnKickCooldownEnd(info, now)
    if info.onCooldown ~= true then
      return 0
    end
    return now + (tonumber(info.cooldownRemain) or 0)
  end

  local function OwnKickNeedsWrite(info, now)
    local written = ownKickWritten
    if not written.valid or written.extras or info.extras ~= nil then
      return true
    end
    if written.generation ~= GetKickInfoGeneration() or now - written.at >= OWN_KICK_REFRESH_SECONDS then
      return true
    end
    if
      written.hasKick ~= info.hasKick
      or written.onCooldown ~= (info.onCooldown == true)
      or written.spellID ~= info.spellID
    then
      return true
    end
    return math.abs(written.cooldownEnd - OwnKickCooldownEnd(info, now)) > 0.1
  end

  local function RememberOwnKickWrite(info, now)
    local written = ownKickWritten
    written.valid = true
    written.hasKick = info.hasKick
    written.onCooldown = info.onCooldown == true
    written.spellID = info.spellID
    written.extras = info.extras ~= nil
    written.cooldownEnd = OwnKickCooldownEnd(info, now)
    written.at = now
    written.generation = GetKickInfoGeneration()
  end

  local function ClearOwnKickSyncCache()
    ownKickWritten.valid = false
    if not (modules.sync and type(modules.sync.ClearPlayerKickInfo) == "function") then
      return false
    end
    local selfName = getUnitName and getUnitName("player") or nil
    local selfRealm = getRealmName and getRealmName() or nil
    if addonTable.StringUtils.IsBlank(selfName) then
      return false
    end
    return modules.sync.ClearPlayerKickInfo(selfName, selfRealm)
  end

  local function EnterRaidKickSuppression()
    kickTrackerSuppressedByRaid = true
    ClearOwnKickSyncCache()
  end

  local function RefreshKickColumnIfVisible()
    if
      IsMainFrameShown()
      and ctx.rosterPanelController
      and type(ctx.rosterPanelController.RefreshKickColumn) == "function"
    then
      ctx.rosterPanelController.RefreshKickColumn()
    end
  end

  -- Kick tracking is a Mythic+ utility. It only runs in the full runtime
  -- profile (active keystone or M0); in the reduced profile -- open world,
  -- normal, heroic, timewalking, delves, torghast, follower dungeons -- the
  -- 0.5s poll and its 15s sync heartbeats would keep running for a roster
  -- column nobody is looking at. Fails closed when the resolver is missing.
  local function HasActiveChallengeFromBridge()
    if type(ctx.GetActiveChallengeMapID) ~= "function" then
      return false
    end
    local ok, mapID = pcall(ctx.GetActiveChallengeMapID)
    if not ok or addonTable.Validators.IsSecretValue(mapID) then
      return false
    end
    local numeric = tonumber(mapID)
    return numeric ~= nil and numeric > 0
  end

  local function IsKickProfileActive()
    -- Running keystone: answered by the injected bridge, which stays valid in
    -- every call context. The wider M0 / pre-insert case can only be read from
    -- live instance data, so it goes through the central resolver.
    if HasActiveChallengeFromBridge() then
      return true
    end
    local runtimeMode = addonTable.RuntimeMode
    if type(runtimeMode) ~= "table" or type(runtimeMode.IsFullProfileContext) ~= "function" then
      return false
    end
    local ok, isFullProfile = pcall(runtimeMode.IsFullProfileContext)
    return ok and isFullProfile == true
  end

  local function IsKickSyncContextActive()
    if type(IsGroupSyncActive) ~= "function" then
      return false
    end
    if IsGroupSyncActive() ~= true then
      return false
    end
    return IsKickProfileActive()
  end

  local function SyncOwnKickState(force)
    if IsRaidModeActive() then
      EnterRaidKickSuppression()
      return false
    end
    if kickTrackerSuppressedByRaid then
      return false
    end
    -- Guards the paths that do not come through RunKickTrackerPoll:
    -- SendOwnKickState, the cooldown-changed callback and post-raid recovery.
    if not IsKickProfileActive() then
      return false
    end
    if not ctx.kickTrackerController then
      return false
    end
    local info = ctx.kickTrackerController.GetKickInfo()
    if type(info) ~= "table" or info.availabilityResolved ~= true then
      ClearOwnKickSyncCache()
      return false
    end
    local hasKick = info.hasKick
    local now = getTime()
    if
      modules.sync
      and type(modules.sync.SetPlayerKickInfo) == "function"
      and (force == true or OwnKickNeedsWrite(info, now))
    then
      local selfName = getUnitName and getUnitName("player") or nil
      local selfRealm = getRealmName and getRealmName() or nil
      if not addonTable.StringUtils.IsBlank(selfName) then
        modules.sync.SetPlayerKickInfo(
          selfName,
          selfRealm,
          info.onCooldown,
          info.cooldownRemain,
          nil,
          hasKick,
          info.extras,
          info.spellID
        )
        RememberOwnKickWrite(info, now)
      end
    end
    local heartbeatDue = now >= kickHeartbeatAt
    if heartbeatDue then
      kickHeartbeatAt = now + KICK_HEARTBEAT_INTERVAL
    end
    if
      modules.sync
      and type(modules.sync.SendKick) == "function"
      and (force == true or info.onCooldown or now < kickReadyBroadcastUntil or heartbeatDue or info.extras)
    then
      modules.sync.SendKick({
        hasKick = hasKick,
        onCooldown = info.onCooldown,
        cooldownRemain = info.cooldownRemain,
        spellID = info.spellID,
        extras = info.extras,
        force = force == true or heartbeatDue,
      })
    end
    return true
  end

  local function RecoverKickTrackerAfterRaid()
    if not kickTrackerSuppressedByRaid or not ctx.kickTrackerController then
      return false
    end
    kickTrackerRecoveryInProgress = true
    local resolvedState = ctx.kickTrackerController.ResolveKickState()
    kickTrackerRecoveryInProgress = false
    if type(resolvedState) ~= "table" or resolvedState.availabilityResolved ~= true then
      ClearOwnKickSyncCache()
      RefreshKickColumnIfVisible()
      return false
    end
    if resolvedState.hasKick ~= true then
      kickTrackerSuppressedByRaid = false
      SyncOwnKickState(true)
      RefreshKickColumnIfVisible()
      return true
    end
    if resolvedState.exactCooldownKnown ~= true then
      ClearOwnKickSyncCache()
      RefreshKickColumnIfVisible()
      return false
    end
    kickTrackerSuppressedByRaid = false
    SyncOwnKickState(true)
    RefreshKickColumnIfVisible()
    return true
  end

  ctx.kickTrackerController = kickTrackerModule.CreateController({
    getTime = getTime,
    onCooldownChanged = function(onCooldown, _cooldownRemain)
      if IsRaidModeActive() then
        EnterRaidKickSuppression()
        return
      end
      if kickTrackerRecoveryInProgress or kickTrackerSuppressedByRaid then
        return
      end
      -- When transitioning to ready, keep broadcasting for 3s to ensure delivery.
      if not onCooldown then
        kickReadyBroadcastUntil = getTime() + 3
      end
      SyncOwnKickState(true)
      RefreshKickColumnIfVisible()
    end,
  })

  local missedKickAlert = CreateMissedKickAlert(ctx, IsRaidModeActive, HasActiveChallengeFromBridge, timerAfter)

  local function ScheduleObservedKickCooldownReconcile()
    if not ctx.kickTrackerController or type(ctx.kickTrackerController.ReconcileObservedCooldown) ~= "function" then
      return
    end
    if type(timerAfter) ~= "function" then
      return
    end
    timerAfter(0.05, function()
      if IsRaidModeActive() or kickTrackerSuppressedByRaid or not ctx.kickTrackerController then
        return
      end
      if ctx.kickTrackerController.ReconcileObservedCooldown() == true then
        SyncOwnKickState(true)
        RefreshKickColumnIfVisible()
      end
    end)
  end

  local kickPollingTicker = nil
  local function StopKickTrackerPolling()
    if kickPollingTicker and type(kickPollingTicker.Cancel) == "function" then
      kickPollingTicker:Cancel()
    end
    kickPollingTicker = nil
  end

  local function RunKickTrackerPoll()
    if IsRaidModeActive() then
      StopKickTrackerPolling()
      EnterRaidKickSuppression()
      return
    end
    if not IsKickSyncContextActive() then
      StopKickTrackerPolling()
      ClearOwnKickSyncCache()
      return
    end
    local recoveredFromRaid = RecoverKickTrackerAfterRaid()
    if kickTrackerSuppressedByRaid or recoveredFromRaid then
      return
    end
    if ctx.kickTrackerController then
      ctx.kickTrackerController.Scan()
      SyncOwnKickState(false)
    end
    -- Hidden mode keeps kick sync alive for peers but avoids polling-driven UI updates.
    RefreshKickColumnIfVisible()
  end

  local function RefreshKickTrackerPolling()
    if not IsKickSyncContextActive() then
      StopKickTrackerPolling()
      return false
    end
    if kickPollingTicker then
      return true
    end
    if type(C_Timer_ref) ~= "table" or type(C_Timer_ref.NewTicker) ~= "function" then
      return false
    end
    kickPollingTicker = C_Timer_ref.NewTicker(0.5, RunKickTrackerPoll)
    return kickPollingTicker ~= nil
  end

  ctx.RefreshKickTrackerPolling = RefreshKickTrackerPolling
  ctx.StopKickTrackerPolling = StopKickTrackerPolling
  InstallRunKickHooks(ctx, modules)

  ctx.SendOwnKickState = function(force)
    RefreshKickTrackerPolling()
    if IsRaidModeActive() then
      EnterRaidKickSuppression()
      return false
    end
    if not ctx.kickTrackerController then
      return false
    end
    if kickTrackerSuppressedByRaid then
      return RecoverKickTrackerAfterRaid()
    end

    return SyncOwnKickState(force ~= false)
  end

  ctx.HandleKickTrackerEvent = function(event, unit, castGUID, spellID, interruptedBy)
    if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
      missedKickAlert.HandleHostileInterruptEvent(event, unit, interruptedBy)
      return
    end
    if event == "GROUP_ROSTER_UPDATE" then
      RefreshKickTrackerPolling()
      return
    end
    if IsRaidModeActive() then
      StopKickTrackerPolling()
      EnterRaidKickSuppression()
      return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      if ctx.kickTrackerController then
        local observedKick = ctx.kickTrackerController.OnCast(unit, spellID) == true
        missedKickAlert.ProbeOwnCast(unit, castGUID, spellID, observedKick)
        if observedKick then
          ScheduleObservedKickCooldownReconcile()
          missedKickAlert.ScheduleMissedKickCheck()
        end
        if kickTrackerSuppressedByRaid then
          if observedKick then
            kickTrackerSuppressedByRaid = false
            SyncOwnKickState(true)
            RefreshKickColumnIfVisible()
          end
          return
        end
      end
      return
    end

    local recoveredFromRaid = RecoverKickTrackerAfterRaid()
    if kickTrackerSuppressedByRaid or recoveredFromRaid then
      return
    end

    if event == "SPELL_UPDATE_COOLDOWN" or event == "PLAYER_REGEN_ENABLED" then
      -- Cache real CD outside of combat (talent reductions).
      if ctx.kickTrackerController then
        ctx.kickTrackerController.CacheCooldown()
      end
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UNIT_PET" then
      if ctx.kickTrackerController then
        local previousInfo = ctx.kickTrackerController.GetKickInfo()
        local resolvedState = ctx.kickTrackerController.ResolveKickState()
        local previousSpellID = type(previousInfo) == "table" and previousInfo.spellID or nil
        local previousAvailabilityResolved = type(previousInfo) == "table" and previousInfo.availabilityResolved == true
        local previousHasKick = type(previousInfo) == "table" and previousInfo.hasKick == true
        local nextSpellID = type(resolvedState) == "table" and resolvedState.spellID or nil
        if type(resolvedState) ~= "table" or resolvedState.availabilityResolved ~= true then
          ClearOwnKickSyncCache()
          RefreshKickColumnIfVisible()
          return
        end
        if
          previousAvailabilityResolved ~= true
          or previousHasKick ~= (resolvedState.hasKick == true)
          or previousSpellID ~= nextSpellID
        then
          kickReadyBroadcastUntil = getTime() + 3
          SyncOwnKickState(true)
          RefreshKickColumnIfVisible()
        end
      end
    end
  end

  RefreshKickTrackerPolling()
end
FI.InitializeFactorySecondaryKickTracker = InitializeFactorySecondaryKickTracker
