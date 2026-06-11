local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local function InitializeFactorySecondaryKickTracker(
  ctx,
  modules,
  getTime,
  getUnitName,
  getRealmName,
  IsMainFrameShown,
  IsRaidModeActive
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

  local function ClearOwnKickSyncCache()
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

  local function SyncOwnKickState(force)
    if IsRaidModeActive() then
      EnterRaidKickSuppression()
      return false
    end
    if kickTrackerSuppressedByRaid then
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
    if modules.sync and type(modules.sync.SetPlayerKickInfo) == "function" then
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
      end
    end
    local now = getTime()
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

  ctx.SendOwnKickState = function(force)
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

  ctx.HandleKickTrackerEvent = function(event, unit, _, spellID)
    if IsRaidModeActive() then
      EnterRaidKickSuppression()
      return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      if ctx.kickTrackerController then
        local observedKick = ctx.kickTrackerController.OnCast(unit, spellID) == true
        if observedKick then
          ScheduleObservedKickCooldownReconcile()
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

  -- Ticker: scan own kick state + refresh kick column every 0.5s.
  if type(C_Timer_ref) == "table" and type(C_Timer_ref.NewTicker) == "function" then
    C_Timer_ref.NewTicker(0.5, function()
      if IsRaidModeActive() then
        EnterRaidKickSuppression()
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
    end)
  end
end
FI.InitializeFactorySecondaryKickTracker = InitializeFactorySecondaryKickTracker
