local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local InitializeStatusAndOperationalHelpers = FI.InitializeStatusAndOperationalHelpers

local function FormatTraceValue(value)
  if value == nil then
    return "nil"
  end
  return tostring(value)
end

local function IsSecretValue(value)
  local checker = rawget(_G, "issecretvalue")
  if type(checker) ~= "function" then
    return false
  end
  local ok, result = pcall(checker, value)
  return ok and result == true
end

local function BuildLFGGroupRosterTraceLogger(ctx, modules)
  local lastSignature = nil
  return function(snapshot)
    local runtimeLogController = ctx.runtimeLogController
    local logFn = runtimeLogController and runtimeLogController.Log or nil
    local logDeepFn = runtimeLogController and runtimeLogController.LogDeep or nil
    if type(snapshot) ~= "table" then
      return
    end
    if type(logFn) ~= "function" and type(logDeepFn) ~= "function" then
      return
    end

    local resolvedSpellID = nil
    local detectedAfter = tonumber(snapshot.detectedAfter)
    if detectedAfter and modules.teleport and type(modules.teleport.ResolveTeleportSpellIDByMapID) == "function" then
      resolvedSpellID = modules.teleport.ResolveTeleportSpellIDByMapID(detectedAfter)
    end
    if not resolvedSpellID and type(ctx.ResolveActiveTeleportSpellID) == "function" then
      resolvedSpellID = ctx.ResolveActiveTeleportSpellID()
    end

    local localTargetMapID = type(ctx.ResolveLocalStatusTargetMapID) == "function"
        and ctx.ResolveLocalStatusTargetMapID()
      or nil
    local getTimeFn = rawget(_G, "GetTime")
    local now = type(getTimeFn) == "function" and (tonumber(getTimeFn()) or 0) or 0

    local signature = string.format(
      "%s|%s|%s|%s|%s|%s|%s|%s|%s",
      FormatTraceValue(snapshot.event),
      FormatTraceValue(snapshot.inGroup),
      FormatTraceValue(snapshot.members),
      FormatTraceValue(snapshot.detectedBefore),
      FormatTraceValue(snapshot.detectedAfter),
      FormatTraceValue(snapshot.pendingAccept),
      FormatTraceValue(snapshot.latestQueueMap),
      FormatTraceValue(localTargetMapID),
      FormatTraceValue(resolvedSpellID)
    )
    local isDuplicate = signature == lastSignature
    lastSignature = signature
    local targetLogFn = isDuplicate and logDeepFn or logFn
    if type(targetLogFn) ~= "function" then
      return
    end

    targetLogFn(
      string.format(
        "[LFG_GROUP5] ts=%s event=%s in_group=%s members=%s "
          .. "detected_before=%s detected_after=%s pending_accept=%s "
          .. "latest_queue_map=%s local_target_map=%s resolved_spell=%s",
        tostring(now),
        FormatTraceValue(snapshot.event),
        FormatTraceValue(snapshot.inGroup),
        FormatTraceValue(snapshot.members),
        FormatTraceValue(snapshot.detectedBefore),
        FormatTraceValue(snapshot.detectedAfter),
        FormatTraceValue(snapshot.pendingAccept),
        FormatTraceValue(snapshot.latestQueueMap),
        FormatTraceValue(localTargetMapID),
        FormatTraceValue(resolvedSpellID)
      )
    )
  end
end

local function InitializeGameAPIHelpers(ctx, runtimeState)
  ctx.GetActiveChallengeMapID = function()
    local challengeMode = rawget(_G, "C_ChallengeMode")
    if type(challengeMode) ~= "table" or type(challengeMode.GetActiveChallengeMapID) ~= "function" then
      return nil
    end
    local ok, mapID = pcall(challengeMode.GetActiveChallengeMapID)
    if not ok or IsSecretValue(mapID) or type(mapID) ~= "number" or mapID <= 0 then
      return nil
    end
    return mapID
  end
  ctx.IsReadyCheckActive = function()
    return runtimeState.IsReadyCheckActive()
  end
  ctx.SetReadyCheckActive = function(value)
    runtimeState.SetReadyCheckActive(value)
  end
  ctx.GetReadyCheckReadyUntil = function(unit)
    return runtimeState.GetReadyCheckReadyUntil(unit)
  end
  ctx.SetReadyCheckReadyUntil = function(unit, value)
    runtimeState.SetReadyCheckReadyUntil(unit, value)
  end
  ctx.ClearAllReadyCheckReady = function()
    runtimeState.ClearAllReadyCheckReady()
  end
  ctx.ClearExpiredReadyCheckReady = function(now)
    return runtimeState.ClearExpiredReadyCheckReady(now)
  end
  ctx.GetReadyCheckDeclinedUntil = function(unit)
    return runtimeState.GetReadyCheckDeclinedUntil(unit)
  end
  ctx.SetReadyCheckDeclinedUntil = function(unit, value)
    runtimeState.SetReadyCheckDeclinedUntil(unit, value)
  end
  ctx.ClearAllReadyCheckDeclined = function()
    runtimeState.ClearAllReadyCheckDeclined()
  end
  ctx.ClearExpiredReadyCheckDeclined = function(now)
    return runtimeState.ClearExpiredReadyCheckDeclined(now)
  end
  ctx.IsInPartyInstance = function()
    local ok, _, instanceType = pcall(GetInstanceInfo)
    return ok and instanceType == "party"
  end
  ctx.IsPortalNavigatorEnabled = function()
    local dbRef = rawget(_G, "IsiLiveDB")
    return dbRef == nil or dbRef.showPortalNavigator ~= false
  end
end

local function InitializeRuntimeStateDelegates(ctx, modules, runtimeState)
  ctx.GetWasInGroup = function()
    return runtimeState.GetWasInGroup()
  end
  ctx.SetWasInGroup = function(value)
    runtimeState.SetWasInGroup(value)
  end
  ctx.GetWasRaidGroup = function()
    return runtimeState.GetWasRaidGroup()
  end
  ctx.SetWasRaidGroup = function(value)
    runtimeState.SetWasRaidGroup(value)
  end
  ctx.SetWasGroupLeader = function(value)
    runtimeState.SetWasGroupLeader(value)
  end
  ctx.GetWasGroupLeader = function()
    return runtimeState.GetWasGroupLeader()
  end
  ctx.GetRoster = function()
    return runtimeState.GetRoster()
  end
  ctx.SetRoster = function(value)
    runtimeState.SetRoster(value)
  end
  ctx.NormalizePlayerKey = function(name, realm)
    return modules.sync.NormalizePlayerKey(name, realm)
  end
end

local function InitializeRioHelpers(ctx, runtimeState)
  ctx.BuildRosterInfoPlayerKey = function(info)
    if type(info) ~= "table" then
      return nil
    end

    local name = info.name
    if type(name) ~= "string" or name == "" then
      return nil
    end

    return ctx.NormalizePlayerKey(name, info.realm)
  end
  ctx.RestoreRioBaseline = function()
    if IsiLiveDB and type(IsiLiveDB.rioBaseline) == "table" then
      runtimeState.SetRioBaselineByPlayerKey(IsiLiveDB.rioBaseline)
      if runtimeState.HasRioBaselineSnapshot() then
        runtimeState.SetRioDeltaDisplayEnabled(true)
      end
    end
  end
  ctx.ClearRioBaselineSnapshot = function()
    runtimeState.ClearRioBaseline()
    if IsiLiveDB then
      IsiLiveDB.rioBaseline = nil
    end
  end
  ctx.CaptureRioBaselineSnapshot = function()
    local snapshot = {}
    local hasSnapshotData = false
    local roster = ctx.GetRoster()

    for unit, info in pairs(roster) do
      if type(info) == "table" and not info.isGhost then
        local playerKey = ctx.BuildRosterInfoPlayerKey(info)
        if playerKey and playerKey ~= "" then
          local rioValue = tonumber(info and info.rio)
          if not rioValue then
            rioValue = tonumber(ctx.GetUnitRio(unit))
          end
          if rioValue then
            snapshot[playerKey] = math.floor(rioValue)
            hasSnapshotData = true
          end
        end
      end
    end

    runtimeState.SetRioBaselineByPlayerKey(snapshot)
    runtimeState.SetHasRioBaselineSnapshot(hasSnapshotData)
    runtimeState.SetRioDeltaDisplayEnabled(false)
    if IsiLiveDB then
      IsiLiveDB.rioBaseline = snapshot
    end
  end
  ctx.EnableRioDeltaDisplay = function()
    if not runtimeState.HasRioBaselineSnapshot() then
      return
    end
    runtimeState.SetRioDeltaDisplayEnabled(true)
  end
  ctx.GetRioDeltaForRosterInfo = function(info, unit)
    if not runtimeState.HasRioBaselineSnapshot() then
      return nil
    end
    if not runtimeState.IsRioDeltaDisplayEnabled() then
      return nil
    end

    local playerKey = ctx.BuildRosterInfoPlayerKey(info)
    if not playerKey then
      return nil
    end

    local baselineRio = runtimeState.GetRioBaselineByPlayerKey()[playerKey]
    if baselineRio == nil then
      return nil
    end

    local currentRio = tonumber(info and info.rio)
    if unit then
      local liveRio = tonumber(ctx.GetUnitRio(unit))
      if liveRio then
        currentRio = liveRio
        if type(info) == "table" then
          info.rio = liveRio
        end
      end
    end
    if not currentRio then
      return nil
    end

    local delta = math.floor(currentRio) - baselineRio
    if delta < 0 then
      return 0
    end
    return delta
  end
end

local function InitializeOperationalUIHelpers(ctx)
  ctx.UpdateCountdownCancelButton = function()
    if not ctx.rosterPanelController then
      return
    end
    ctx.rosterPanelController.SetCountdownCancelText(ctx.L.BTN_COUNTDOWN_CANCEL)
  end
  ctx.GetTeleportEmptyStateText = function()
    local seasonData = addonTable.SeasonData
    if type(seasonData) ~= "table" then
      return nil
    end
    if type(seasonData.HasActiveDungeons) == "function" and seasonData.HasActiveDungeons() then
      return nil
    end
    if type(seasonData.GetInactivePortalMessage) ~= "function" then
      return nil
    end

    local db = rawget(_G, "IsiLiveDB")
    local activeLocale = (db and db.locale) or ctx.locale
    return seasonData.GetInactivePortalMessage(activeLocale)
  end
end

local function InitializeFactoryRuntimeHelpers(ctx)
  local modules = ctx.modules
  local runtimeState = ctx.runtimeState
  InitializeGameAPIHelpers(ctx, runtimeState)
  InitializeRuntimeStateDelegates(ctx, modules, runtimeState)
  InitializeRioHelpers(ctx, runtimeState)
  InitializeStatusAndOperationalHelpers(ctx, modules, runtimeState)
  InitializeOperationalUIHelpers(ctx)
end

FI.InitializeFactoryRuntimeHelpers = InitializeFactoryRuntimeHelpers
FI.BuildLFGGroupRosterTraceLogger = BuildLFGGroupRosterTraceLogger

return {
  InitializeFactoryRuntimeHelpers = InitializeFactoryRuntimeHelpers,
  BuildLFGGroupRosterTraceLogger = BuildLFGGroupRosterTraceLogger,
}
