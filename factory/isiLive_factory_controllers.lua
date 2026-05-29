local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

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

-- Sub-function: Game API safe wrappers and instance helpers.
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

-- Sub-function: Runtime state getter/setter delegates.
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

-- Sub-function: Player key resolution and RIO baseline/delta pipeline.
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

local function ResolveActiveInviteLevelHint(lfgDetect)
  if type(lfgDetect) ~= "table" then
    return nil, nil
  end

  if type(lfgDetect.GetActiveInviteTitleLevel) == "function" then
    local hint = tonumber(lfgDetect.GetActiveInviteTitleLevel())
    if hint and hint > 0 then
      return math.floor(hint), nil
    end
  end

  if type(lfgDetect.GetActiveInviteTitleLevelText) == "function" then
    local hintText = lfgDetect.GetActiveInviteTitleLevelText()
    if type(hintText) == "string" and hintText ~= "" then
      return nil, hintText
    end
  end

  return nil, nil
end

local function BuildReloadRosterTargetSnapshot(ctx)
  if type(ctx.GetStatusTargetDungeonInfo) ~= "function" or type(ctx.ResolveStatusTargetMapID) ~= "function" then
    return nil
  end
  local mapID = tonumber(ctx.ResolveStatusTargetMapID())
  if not mapID or mapID <= 0 then
    return nil
  end
  local info = ctx.GetStatusTargetDungeonInfo()
  if type(info) ~= "table" then
    return nil
  end
  local name = ctx.NormalizeConcreteStatusTargetName(info.name, mapID)
  if not name then
    return nil
  end

  local snapshot = {
    mapID = math.floor(mapID),
    name = name,
  }
  local level = tonumber(info.level)
  if level and level > 0 then
    snapshot.level = math.floor(level)
  end
  if type(info.levelText) == "string" and info.levelText ~= "" then
    snapshot.levelText = info.levelText
  end
  return snapshot
end

local function RestoreReloadRosterTargetSnapshot(ctx, runtimeState, snapshot)
  if type(snapshot) ~= "table" then
    return false
  end
  local mapID = tonumber(snapshot.mapID)
  if not mapID or mapID <= 0 then
    return false
  end
  local name = ctx.NormalizeConcreteStatusTargetName(snapshot.name, mapID)
  if not name then
    return false
  end

  local restored = {
    mapID = math.floor(mapID),
    name = name,
  }
  local level = tonumber(snapshot.level)
  if level and level > 0 then
    restored.level = math.floor(level)
  end
  if type(snapshot.levelText) == "string" and snapshot.levelText ~= "" then
    restored.levelText = snapshot.levelText
  end
  ctx.reloadRosterTargetSnapshot = restored
  runtimeState.SetLatestQueueState(name, nil, nil, restored.mapID)
  return true
end

-- Sub-function: Status target resolution, dungeon info, and operational helpers.
local function InitializeStatusAndOperationalHelpers(ctx, modules, runtimeState)
  ctx.getPlayerSyncSummary = function(name, realm)
    if modules.sync and type(modules.sync.GetPlayerSyncSummary) == "function" then
      return modules.sync.GetPlayerSyncSummary(name, realm)
    end
    return nil
  end
  ctx.ResetInspectAll = function()
    ctx.inspectController.ResetAll()
  end
  ctx.ResetInspectQueues = function()
    ctx.inspectController.ResetQueues()
  end
  ctx.GetPendingBindingApply = function()
    if not ctx.bindingController then
      return false
    end
    return ctx.bindingController.GetPendingBindingApply()
  end
  ctx.ClearLatestQueueTarget = function()
    ctx.reloadRosterTargetSnapshot = nil
    runtimeState.ClearLatestQueueTarget()
    if ctx.UpdateStatusLine then
      ctx.UpdateStatusLine()
    end
  end
  ctx.AnnounceQueuedGroupJoin = function()
    local pending = runtimeState.GetPendingQueueJoinInfo()
    if type(pending) ~= "table" then
      return
    end

    if ctx.IsPlayerLeader() then
      runtimeState.SetPendingQueueJoinInfo(nil)
      return
    end

    local L = ctx.GetL()
    local groupName = pending.groupName or L.UNKNOWN_GROUP
    local separator = "|cffffffff----------------------------------------|r"
    ctx.Print(separator)
    ctx.Print("|cffffffff" .. L.CHAT_QUEUE_PREFIX .. " | " .. string.format(L.JOINED_FROM_QUEUE, groupName) .. "|r")
    ctx.Print(separator)
    runtimeState.SetPendingQueueJoinInfo(nil)
  end
  ctx.CaptureQueueJoinCandidate = function(...)
    local logFn = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil
    if ctx.GetActiveChallengeMapID() then -- secret-value-ok: ctx wrapper is pcall-protected
      if logFn then
        logFn("[QUEUE_FLOW] capture_candidate blocked reason=challenge_active")
      end
      return
    end

    if not IsInGroup() then
      runtimeState.SetPendingQueueJoinInfo(nil)
    end

    local args = { ... }
    local groupName = nil
    if type(args[1]) == "table" then
      local data = args[1]
      groupName = data.groupName or data.name
    elseif type(args[1]) == "string" then
      local value = args[1]
      local low = string.lower(value)
      if not (low:find("invite") or low:find("accept") or low == "applied" or low:find("declin")) then
        groupName = value
      end
    end

    if groupName == "" then
      groupName = nil
    end

    if not runtimeState.GetPendingQueueJoinInfo() then
      if not groupName then
        if logFn then
          logFn("[QUEUE_FLOW] capture_candidate skipped reason=no_group_name")
        end
        return
      end

      local capturedAt = nil
      local getTimeFn = rawget(_G, "GetTime")
      if type(getTimeFn) == "function" then
        capturedAt = getTimeFn()
      end

      if logFn then
        logFn(
          string.format(
            "[QUEUE_FLOW] capture_candidate groupName=%s capturedAt=%s isInGroup=%s",
            tostring(groupName),
            tostring(capturedAt),
            tostring(IsInGroup())
          )
        )
      end
      runtimeState.SetPendingQueueJoinInfo({
        groupName = groupName,
        capturedAt = capturedAt,
      })
    end

    if IsInGroup() then
      ctx.AnnounceQueuedGroupJoin()
    end
  end
  ctx.RefreshLocalPlayerKey = function()
    return ctx.keySyncController.RefreshLocalPlayerKey(ctx.GetRoster())
  end
  ctx.NormalizeStatusTargetName = function(value)
    if type(value) ~= "string" then
      return nil
    end
    local normalized = addonTable.StringUtils.Trim(value)
    if normalized == "" then
      return nil
    end
    return normalized
  end
  ctx.NormalizeConcreteStatusTargetName = function(value, targetMapID)
    local normalized = ctx.NormalizeStatusTargetName(value)
    if not normalized then
      return nil
    end

    local numericName = tonumber(normalized)
    local numericTargetMapID = tonumber(targetMapID)
    if numericName and numericTargetMapID and numericName == numericTargetMapID then
      return nil
    end

    return normalized
  end
  ctx.ResolveLocalStatusTargetMapID = function()
    -- Priority 0: LFGDetect (invite accepted / own active listing). Keeps
    -- status line, center notice and highlight target resolution aligned
    -- so peers' synced target cannot surface a different dungeon than the
    -- one the player just accepted.
    local lfgDetect = addonTable.LFGDetect
    local detectedMapID = type(lfgDetect) == "table"
        and type(lfgDetect.GetDetectedMapID) == "function"
        and lfgDetect.GetDetectedMapID()
      or nil
    if detectedMapID then
      local numericDetected = tonumber(detectedMapID)
      if numericDetected and numericDetected > 0 then
        return numericDetected
      end
    end

    local _, latestQueueActivityID, _, latestQueueMapID = runtimeState.GetLatestQueueState()
    local activeMapID = tonumber(runtimeState.GetActiveJoinedKeyMapID())
    if activeMapID and activeMapID > 0 then
      return activeMapID
    end

    local queueMapID = tonumber(latestQueueMapID)
    if queueMapID and queueMapID > 0 then
      return queueMapID
    end

    if latestQueueActivityID then
      local resolvedMapID = ctx.ResolveMapIDByActivityID(latestQueueActivityID)
      if type(resolvedMapID) == "number" and resolvedMapID > 0 then
        return resolvedMapID
      end
    end

    return nil
  end
  ctx.ResolveSyncedTargetInfo = function()
    if not modules.sync or type(modules.sync.GetPlayerTargetInfo) ~= "function" then
      return nil
    end

    local roster = ctx.GetRoster() or {}
    local unitIsGroupLeaderFn = rawget(_G, "UnitIsGroupLeader")

    -- Leader-only path: when we can identify the group leader, only their
    -- target announcement counts. The played key always belongs to the
    -- leader, so any conflicting broadcast from a member who happens to
    -- carry a higher-level key for the same dungeon must be ignored.
    if type(unitIsGroupLeaderFn) == "function" then
      for unit, info in pairs(roster) do
        if type(unit) == "string" and unit ~= "" and type(info) == "table" and not info.isGhost then
          local okLeader, isLeader = pcall(unitIsGroupLeaderFn, unit)
          if okLeader and isLeader == true then
            local targetInfo = modules.sync.GetPlayerTargetInfo(info.name, info.realm)
            if type(targetInfo) == "table" then
              local mapID = tonumber(targetInfo.mapID)
              if mapID and mapID > 0 then
                local level = tonumber(targetInfo.level)
                if level and level <= 0 then
                  level = nil
                end
                return {
                  mapID = math.floor(mapID),
                  level = level and math.floor(level) or nil,
                }
              end
            end
            -- Leader resolved but has no synced target → fail closed rather
            -- than fall back to other members' announcements.
            return nil
          end
        end
      end
    end

    -- No group leader resolvable (e.g. solo, or UnitIsGroupLeader unavailable):
    -- fall back to the legacy any-member consensus with the conflict guard.
    local resolvedMapID = nil
    local resolvedLevel = nil
    local levelConflict = false

    for _, info in pairs(roster) do
      if type(info) == "table" and not info.isGhost then
        local targetInfo = modules.sync.GetPlayerTargetInfo(info.name, info.realm)
        if type(targetInfo) == "table" then
          local mapID = tonumber(targetInfo.mapID)
          if mapID and mapID > 0 then
            mapID = math.floor(mapID)
            if not resolvedMapID then
              resolvedMapID = mapID
            elseif resolvedMapID ~= mapID then
              return nil
            end

            local level = tonumber(targetInfo.level)
            if level and level > 0 then
              level = math.floor(level)
              if resolvedLevel == nil then
                resolvedLevel = level
              elseif resolvedLevel ~= level then
                levelConflict = true
              end
            end
          end
        end
      end
    end

    if not resolvedMapID then
      return nil
    end

    if levelConflict then
      resolvedLevel = nil
    end

    return {
      mapID = resolvedMapID,
      level = resolvedLevel,
    }
  end
  ctx.ResolveStatusTargetMapID = function()
    local localMapID = ctx.ResolveLocalStatusTargetMapID()
    if localMapID then
      return localMapID
    end

    local syncedTargetInfo = ctx.ResolveSyncedTargetInfo and ctx.ResolveSyncedTargetInfo() or nil
    if type(syncedTargetInfo) == "table" then
      local syncedMapID = tonumber(syncedTargetInfo.mapID)
      if syncedMapID and syncedMapID > 0 then
        return math.floor(syncedMapID)
      end
    end

    return nil
  end
  ctx.GetReloadRosterTargetSnapshot = function()
    return BuildReloadRosterTargetSnapshot(ctx)
  end
  ctx.RestoreReloadRosterTargetSnapshot = function(snapshot)
    return RestoreReloadRosterTargetSnapshot(ctx, runtimeState, snapshot)
  end
  ctx.GetStatusTargetDungeonInfo = function()
    local targetMapID = ctx.ResolveStatusTargetMapID()
    local latestQueueDungeonName, latestQueueActivityID = runtimeState.GetLatestQueueState()
    local roster = ctx.GetRoster()

    local targetName = ctx.NormalizeConcreteStatusTargetName(latestQueueDungeonName, targetMapID)
    if not targetName and targetMapID and modules.teleport and modules.teleport.GetTeleportInfoByMapID then
      local info = modules.teleport.GetTeleportInfoByMapID(targetMapID)
      if type(info) == "table" then
        targetName = ctx.NormalizeConcreteStatusTargetName(info.mapName, targetMapID)
      end
    end
    if not targetName and latestQueueActivityID and modules.queue and modules.queue.GetActivityName then
      targetName =
        ctx.NormalizeConcreteStatusTargetName(modules.queue.GetActivityName(latestQueueActivityID), targetMapID)
    end
    if not targetName then
      return nil
    end

    -- Level resolution priority:
    --   1. LFG group title "+N" (authoritative): the listing title carries the
    --      played key level independent of who owns it. Leader != key owner is
    --      common (boost runs, weak-aura groups). Once the invite is accepted
    --      the level is locked-in and must not be overridden by later
    --      roster/sync updates that would otherwise flip the announce mid-flight.
    --   2. Roster owner key level: fallback when no title hint exists (manual
    --      /invite, no LFG context).
    --   3. Synced target level: last fallback for peers that publish a target.
    local lfgDetect = addonTable.LFGDetect
    local targetLevel, targetLevelText = ResolveActiveInviteLevelHint(lfgDetect)

    if not targetLevel or targetLevel <= 0 then
      local restoredTarget = ctx.reloadRosterTargetSnapshot
      if type(restoredTarget) == "table" and tonumber(restoredTarget.mapID) == tonumber(targetMapID) then
        targetLevel = tonumber(restoredTarget.level)
        if targetLevel and targetLevel > 0 then
          targetLevelText = nil
        elseif type(restoredTarget.levelText) == "string" and restoredTarget.levelText ~= "" then
          targetLevelText = restoredTarget.levelText
        end
      end
    end

    if not targetLevel or targetLevel <= 0 then
      local ownerUnit = ctx.ResolveActiveKeyOwnerUnit and ctx.ResolveActiveKeyOwnerUnit() or nil
      if ownerUnit and type(roster[ownerUnit]) == "table" then
        targetLevel = tonumber(roster[ownerUnit].keyLevel)
        if targetLevel and targetLevel > 0 then
          targetLevelText = nil
        end
      end
    end

    if not targetLevel or targetLevel <= 0 then
      local syncedTargetInfo = ctx.ResolveSyncedTargetInfo and ctx.ResolveSyncedTargetInfo() or nil
      if type(syncedTargetInfo) == "table" and tonumber(syncedTargetInfo.mapID) == tonumber(targetMapID) then
        targetLevel = tonumber(syncedTargetInfo.level)
        if targetLevel and targetLevel > 0 then
          targetLevelText = nil
        end
      end
    end

    if targetLevel and targetLevel <= 0 then
      targetLevel = nil
    end

    return {
      name = targetName,
      level = targetLevel,
      levelText = targetLevelText,
    }
  end
  ctx.SendOwnTargetSnapshot = function(force, source, allowHidden)
    if not modules.sync or type(modules.sync.SendTarget) ~= "function" then
      return
    end

    local isVisible = ctx.mainFrame and ctx.mainFrame:IsShown() or false
    local targetMapID = ctx.ResolveLocalStatusTargetMapID()

    -- Mirror GetStatusTargetDungeonInfo's level-resolution priority so the
    -- payload broadcast to peers matches the local announce: LFG-title hint
    -- (authoritative) wins over the roster-owner key level.
    local lfgDetect = addonTable.LFGDetect
    local targetLevel, targetLevelText = ResolveActiveInviteLevelHint(lfgDetect)

    if
      (not targetLevel or targetLevel <= 0)
      and targetMapID
      and ctx.keySyncController
      and type(ctx.keySyncController.ResolveActiveKeyOwnerUnit) == "function"
    then
      local preferredOwnerName = nil
      if type(lfgDetect) == "table" and type(lfgDetect.GetActiveInviteLeader) == "function" then
        preferredOwnerName = lfgDetect.GetActiveInviteLeader()
      end
      local ownerUnit =
        ctx.keySyncController.ResolveActiveKeyOwnerUnit(ctx.GetRoster(), targetMapID, preferredOwnerName)
      local roster = ctx.GetRoster()
      if ownerUnit and type(roster[ownerUnit]) == "table" then
        targetLevel = tonumber(roster[ownerUnit].keyLevel)
        if targetLevel and targetLevel > 0 then
          targetLevelText = nil
        end
      end
    end

    modules.sync.SendTarget({
      force = force and true or false,
      isVisible = isVisible,
      allowHidden = (allowHidden and true or false) or not isVisible,
      mapID = targetMapID,
      level = targetLevel,
      levelText = targetLevelText,
      source = source,
    })
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

-- Orchestrator: composes the runtime helper sub-functions above.
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

-- Maps the canonical role token returned by Units.GetUnitRole("player") to a
-- localized label. Any unexpected token (or "NONE") returns nil so the caller
-- can omit the row entirely instead of rendering an empty value.
local function ResolveAcceptedInviteRoleName(ctx, role)
  if type(role) ~= "string" or role == "" or role == "NONE" then
    return nil
  end
  local L = ctx.GetL and ctx.GetL() or {}
  if role == "TANK" then
    return L.ROLE_NAME_TANK
  end
  if role == "HEALER" then
    return L.ROLE_NAME_HEALER
  end
  if role == "DAMAGER" then
    return L.ROLE_NAME_DAMAGE
  end
  return nil
end

-- Resolves the dungeon name for the post-accept notice. Same source as the
-- Status chat announce (modules.teleport.GetTeleportInfoByMapID) so both
-- channels stay in lockstep. Falls back to the localized "Unknown dungeon"
-- string when the lookup misses — never invents a name.
local function ResolveAcceptedInviteDungeonName(ctx, modules, mapID)
  if modules.teleport and type(modules.teleport.GetTeleportInfoByMapID) == "function" and mapID then
    local info = modules.teleport.GetTeleportInfoByMapID(mapID)
    if type(info) == "table" then
      if type(info.mapName) == "string" and info.mapName ~= "" then
        return info.mapName
      end
      if type(info.name) == "string" and info.name ~= "" then
        return info.name
      end
    end
  end
  local L = ctx.GetL and ctx.GetL() or {}
  return L.INVITE_HINT_UNKNOWN_DUNGEON or "Unknown dungeon"
end

-- Builds the rich-layout field rows for the post-accept notice from the
-- payload. Order is fixed (Dungeon, Group, Leader, Source) so the visual
-- hierarchy matches the center-notice mockup and stays stable across invites.
-- Optional rows are dropped when their source is missing — never filled with
-- "-" or "Unknown" placeholders.
local function BuildAcceptedInviteFields(ctx, mapName, payload)
  local L = ctx.GetL and ctx.GetL() or {}
  local fields = {}

  local level = tonumber(payload.level)
  local dungeonValue
  if level and level > 0 then
    dungeonValue = string.format(L.INVITE_ACCEPTED_NOTICE_HEADLINE_WITH_LEVEL or "%s +%d", mapName, math.floor(level))
  else
    dungeonValue = string.format(L.INVITE_ACCEPTED_NOTICE_HEADLINE_NO_LEVEL or "%s", mapName)
  end
  fields[#fields + 1] = { label = L.INVITE_ACCEPTED_NOTICE_LABEL_DUNGEON or "Dungeon:", value = dungeonValue }

  if type(payload.groupName) == "string" and payload.groupName ~= "" then
    fields[#fields + 1] = { label = L.INVITE_ACCEPTED_NOTICE_LABEL_GROUP or "Group:", value = payload.groupName }
  end

  if type(payload.leaderName) == "string" and payload.leaderName ~= "" then
    fields[#fields + 1] = { label = L.INVITE_ACCEPTED_NOTICE_LABEL_LEADER or "Leader:", value = payload.leaderName }
  end

  fields[#fields + 1] = {
    label = L.INVITE_ACCEPTED_NOTICE_LABEL_SOURCE or "Source:",
    value = payload.sourceText or L.INVITE_ACCEPTED_NOTICE_SOURCE_LFG_ACCEPTED or "LFG accepted invite",
  }

  return fields
end

local function IsAcceptedInviteNoticeEnabled()
  local db = rawget(_G, "IsiLiveDB")
  if type(db) ~= "table" then
    return true
  end
  return db.acceptedInviteNoticeEnabled ~= false
end

local function IsGroupJoinNoticeEnabled()
  local db = rawget(_G, "IsiLiveDB")
  if type(db) ~= "table" then
    return true
  end
  return db.groupJoinNoticeEnabled ~= false
end

-- Builds the acceptedInviteNotice payload renderer. Extracted so the wiring
-- block in InitializeFactoryPrimaryControllers stays under the function-line
-- metrics gate. Pulls ALL data from the supplied payload (the pendingInvites
-- snapshot of the accepted searchResultID); never reads roster/sync state.
-- payload.level may legitimately be nil when the LFG group title carries no
-- "+N" marker; we render the dungeon row without "+N" rather than guess.
local function RenderAcceptedInviteNotice(ctx, modules, payload, useAcceptedNoticeGate)
  if type(payload) ~= "table" or type(ctx.ShowCenterNotice) ~= "function" then
    return
  end
  if useAcceptedNoticeGate ~= false and not IsAcceptedInviteNoticeEnabled() then
    return
  end
  local L = ctx.GetL and ctx.GetL() or {}

  local mapName = ResolveAcceptedInviteDungeonName(ctx, modules, payload.mapID)
  local fields = BuildAcceptedInviteFields(ctx, mapName, payload)
  local activityID = tonumber(payload.activityID)
  if activityID and activityID <= 0 then
    activityID = nil
  end
  local mapID = tonumber(payload.mapID)
  if mapID and mapID <= 0 then
    mapID = nil
  end
  local hasTeleportContext = activityID ~= nil or mapID ~= nil

  -- Forward the accepted listing map/activity context into the center notice
  -- so the embedded teleport button uses the same strict map/activity -> spell
  -- resolver as the highlighted M+ portal row. Without verified context the
  -- notice stays informational and no name-based fallback is attempted.
  ctx.ShowCenterNotice(nil, nil, hasTeleportContext and mapName or nil, activityID, {
    eyebrow = L.INVITE_ACCEPTED_NOTICE_EYEBROW or "M+ Target",
    title = payload.title or L.INVITE_ACCEPTED_NOTICE_TITLE or "isiLive - Invite accepted",
    fields = fields,
    teleportMapID = mapID,
    -- Keep the rich card at the default notice width so the accepted-invite
    -- title and four mockup field rows do not collapse beside the portal icon.
    frameWidth = 680,
    -- Persistent (no auto-hide): the notice stays until the user right-clicks
    -- it or presses the close button. The auto-timer kept producing too-short
    -- visibility windows in live testing (12 s missed during a busy invite
    -- sequence). Right-click / red-X / next ShowCenterNotice still close it.
    persistent = true,
    -- No blink/fontScale — the rich layout already carries its own visual
    -- hierarchy through the title bar, separator, and color-coded labels.
  })
end

local function ShowJoinedTargetNotice(ctx, modules)
  if type(ctx) ~= "table" then
    return
  end
  if ctx.acceptedInviteNoticeRenderedForCurrentJoin == true then
    ctx.acceptedInviteNoticeRenderedForCurrentJoin = false
    return
  end
  if type(ctx.ResolveLocalStatusTargetMapID) ~= "function" or type(ctx.GetStatusTargetDungeonInfo) ~= "function" then
    return
  end
  if not IsGroupJoinNoticeEnabled() then
    return
  end

  local mapID = tonumber(ctx.ResolveLocalStatusTargetMapID())
  if not mapID or mapID <= 0 then
    return
  end

  local targetInfo = ctx.GetStatusTargetDungeonInfo()
  if type(targetInfo) ~= "table" or type(targetInfo.name) ~= "string" or targetInfo.name == "" then
    return
  end

  local activityID = nil
  if ctx.runtimeState and type(ctx.runtimeState.GetLatestQueueState) == "function" then
    local _, latestQueueActivityID = ctx.runtimeState.GetLatestQueueState()
    activityID = latestQueueActivityID
  end
  local lfgDetect = addonTable.LFGDetect
  local leaderName = nil
  local groupName = nil
  local sourceText = nil
  local title = nil
  local usedQueueListingIdentity = false
  if type(lfgDetect) == "table" then
    if type(lfgDetect.GetActiveInviteLeader) == "function" then
      leaderName = lfgDetect.GetActiveInviteLeader()
    end
    if type(lfgDetect.GetActiveInviteGroupName) == "function" then
      groupName = lfgDetect.GetActiveInviteGroupName()
    end
    if not leaderName and type(lfgDetect.GetActiveQueueListingLeaderName) == "function" then
      leaderName = lfgDetect.GetActiveQueueListingLeaderName()
      usedQueueListingIdentity = leaderName ~= nil
    end
    if not groupName and type(lfgDetect.GetActiveQueueListingGroupName) == "function" then
      groupName = lfgDetect.GetActiveQueueListingGroupName()
      usedQueueListingIdentity = usedQueueListingIdentity or groupName ~= nil
    end
  end
  if usedQueueListingIdentity then
    local L = ctx.GetL and ctx.GetL() or {}
    sourceText = L.INVITE_ACCEPTED_NOTICE_SOURCE_OWN_LFG_LISTING or "Own LFG key search"
    title = L.INVITE_ACCEPTED_NOTICE_TITLE_OWN_LFG_LISTING or "isiLive - LFG key search"
  end

  RenderAcceptedInviteNotice(ctx, modules, {
    mapID = math.floor(mapID),
    activityID = activityID,
    level = targetInfo.level,
    leaderName = leaderName,
    groupName = groupName,
    sourceText = sourceText,
    title = title,
  }, false)
end

-- Raid mirror of BuildAcceptedInviteFields. No level field (Raid listings have
-- no keystone level), no teleport button (no Raid teleport spells), but the
-- group title / description / player role rows stay so the player sees the
-- same context they signed up for.
local function BuildAcceptedRaidInviteFields(ctx, mapName, payload)
  local L = ctx.GetL and ctx.GetL() or {}
  local fields = {}
  fields[#fields + 1] = {
    label = L.INVITE_ACCEPTED_NOTICE_LABEL_DUNGEON or "Dungeon:",
    value = mapName,
  }
  if type(payload.groupName) == "string" and payload.groupName ~= "" then
    fields[#fields + 1] = { label = L.INVITE_ACCEPTED_NOTICE_LABEL_GROUP or "Group:", value = payload.groupName }
  end
  if type(payload.comment) == "string" and payload.comment ~= "" then
    fields[#fields + 1] =
      { label = L.INVITE_ACCEPTED_NOTICE_LABEL_DESCRIPTION or "Description:", value = payload.comment }
  end
  local role = type(ctx.GetUnitRole) == "function" and ctx.GetUnitRole("player") or nil
  local roleName = ResolveAcceptedInviteRoleName(ctx, role)
  if roleName then
    fields[#fields + 1] = { label = L.INVITE_ACCEPTED_NOTICE_LABEL_ROLE or "Role:", value = roleName }
  end
  return fields
end

-- Raid mirror of RenderAcceptedInviteNotice. Same Center Notice surface and
-- layout, no teleport-button configuration (dungeonName / activityID stay nil
-- so ConfigureCenterNoticeTeleportButton early-returns), separate title key
-- so the user can tell Raid and M+ invites apart at a glance.
local function RenderAcceptedRaidInviteNotice(ctx, modules, payload)
  if type(payload) ~= "table" or type(ctx.ShowCenterNotice) ~= "function" then
    return
  end
  if not IsAcceptedInviteNoticeEnabled() then
    return
  end
  local L = ctx.GetL and ctx.GetL() or {}
  local mapName = ResolveAcceptedInviteDungeonName(ctx, modules, payload.mapID)
  local fields = BuildAcceptedRaidInviteFields(ctx, mapName, payload)
  ctx.ShowCenterNotice(nil, nil, nil, nil, {
    eyebrow = L.INVITE_ACCEPTED_RAID_NOTICE_EYEBROW or "Raid Target",
    title = L.INVITE_ACCEPTED_RAID_NOTICE_TITLE or "isiLive - Raid invite accepted",
    fields = fields,
    frameWidth = 540,
    persistent = true,
  })
end

-- Internal test surface: the four helpers above are wired together inside
-- InitializeFactoryPrimaryControllers via a single closure, so the only
-- realistic way to cover their branches in isolation is to expose them on
-- the _FactoryInternal table the same way the four Initialize* entry
-- points are. Not part of the public addon API.
FI.ResolveAcceptedInviteRoleName = ResolveAcceptedInviteRoleName
FI.ResolveAcceptedInviteDungeonName = ResolveAcceptedInviteDungeonName
FI.BuildAcceptedInviteFields = BuildAcceptedInviteFields
FI.RenderAcceptedInviteNotice = RenderAcceptedInviteNotice
FI.ShowJoinedTargetNotice = ShowJoinedTargetNotice
FI.BuildAcceptedRaidInviteFields = BuildAcceptedRaidInviteFields
FI.RenderAcceptedRaidInviteNotice = RenderAcceptedRaidInviteNotice

-- Wires the four accepted-invite callbacks on lfgDetect (M+ render + enabled
-- gate, Raid render + enabled gate). Extracted from InitializeFactoryPrimary-
-- Controllers so that function stays under the metrics gate; behaviour is
-- identical to inline wiring.
local function WireAcceptedInviteNoticeCallbacks(ctx, modules, lfgDetect)
  local function noticeEnabled()
    return IsAcceptedInviteNoticeEnabled()
  end
  if type(lfgDetect.SetAcceptedInviteNoticeCallback) == "function" then
    lfgDetect.SetAcceptedInviteNoticeCallback(function(payload)
      ctx.acceptedInviteNoticeRenderedForCurrentJoin = true
      RenderAcceptedInviteNotice(ctx, modules, payload)
    end)
  end
  if type(lfgDetect.SetAcceptedInviteNoticeEnabledFn) == "function" then
    lfgDetect.SetAcceptedInviteNoticeEnabledFn(noticeEnabled)
  end
  -- Raid-only mirror: separate callback so the Raid notice never traverses
  -- the M+ pipeline (no detectedMapID, no chat announce, no teleport
  -- highlight). Shares the IsiLiveDB.acceptedInviteNoticeEnabled gate so a
  -- single user-facing toggle controls both notices.
  if type(lfgDetect.SetAcceptedRaidInviteNoticeCallback) == "function" then
    lfgDetect.SetAcceptedRaidInviteNoticeCallback(function(payload)
      RenderAcceptedRaidInviteNotice(ctx, modules, payload)
    end)
  end
  if type(lfgDetect.SetAcceptedRaidInviteNoticeEnabledFn) == "function" then
    lfgDetect.SetAcceptedRaidInviteNoticeEnabledFn(noticeEnabled)
  end
end
FI.WireAcceptedInviteNoticeCallbacks = WireAcceptedInviteNoticeCallbacks

local function HandleTargetDungeonChatPayload(ctx, modules, statusController, payload)
  if type(payload) ~= "table" then
    return
  end
  local mapID = tonumber(payload.mapID)
  if not mapID or mapID <= 0 then
    return
  end
  local resolvedName = ResolveAcceptedInviteDungeonName(ctx, modules, mapID)
  if type(resolvedName) ~= "string" or resolvedName == "" then
    return
  end
  if ctx.runtimeState and type(ctx.runtimeState.SetLatestQueueState) == "function" then
    ctx.runtimeState.SetLatestQueueState(resolvedName, payload.activityID, nil, mapID)
  end
  -- Debug trace consumes the descriptive payload fields (leaderName,
  -- groupName, searchResultID) that lfg_detect carries through. The
  -- announce itself only needs name+level, but the trace keeps the
  -- full listing identity visible when diagnosing chat / notice
  -- divergence reports (e.g. 0.9.240 follow-ups).
  local logRuntimeTracef = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
  if logRuntimeTracef then
    logRuntimeTracef(
      "[TARGET_DUNGEON_CHAT] direct_push mapID=%s level=%s leader=%s group=%s searchResultID=%s",
      tostring(mapID),
      tostring(payload.level),
      tostring(payload.leaderName),
      tostring(payload.groupName),
      tostring(payload.searchResultID)
    )
  end
  statusController.AnnounceTargetDungeonFromPayload({
    name = resolvedName,
    level = payload.level,
    levelText = payload.levelText,
  })
  if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshKillTrackRow) == "function" then
    ctx.rosterPanelController.RefreshKillTrackRow()
  end
end
FI.HandleTargetDungeonChatPayload = HandleTargetDungeonChatPayload

local function InitializeInviteControllers(_ctx, _modules)
  -- Disabled: there is no proven stable Blizzard multi-invite list surface.
end
FI.InitializeInviteControllers = InitializeInviteControllers

local function InitializeFactoryPrimaryControllers(ctx)
  local modules = ctx.modules
  local initResult = modules.controllerInit.CreateControllers({
    sync = modules.sync,
    keySyncModule = modules.keySync,
    highlightModule = modules.highlight,
    rosterPanelModule = modules.rosterPanel,
    teleportUIModule = modules.teleportUI,
    statsModule = modules.stats,
    isInGroup = IsInGroup,
    getUnitNameAndRealm = ctx.GetUnitNameAndRealm,
    getAddonVersionRaw = ctx.GetAddonVersionRaw,
    isFrameVisible = function()
      return ctx.mainFrame and ctx.mainFrame:IsShown()
    end,
    canRespondToRefreshRequest = function()
      return not ctx.runtimeState.IsStopped() and not ctx.runtimeState.IsPaused()
    end,
    resolveTeleportSpellID = ctx.ResolveTeleportSpellID,
    resolveTeleportSpellIDByMapID = modules.teleport.ResolveTeleportSpellIDByMapID,
    resolveMapIDByActivityID = modules.teleport.ResolveMapIDByActivityID,
    resolveMapIDBySpellID = modules.teleport.ResolveMapIDBySpellID,
    resolveMapIDsBySpellID = modules.teleport.ResolveMapIDsBySpellID,
    mainUI = ctx.mainUI,
    mainFrame = ctx.mainFrame,
    getL = ctx.GetL,
    isPlayerLeader = ctx.IsPlayerLeader,
    getAddonVersionText = function()
      return "V." .. ctx.GetAddonVersionRaw()
    end,
    getUnitRio = ctx.GetUnitRio,
    updateStatusLine = function()
      if ctx.UpdateStatusLine then
        ctx.UpdateStatusLine()
      end
    end,
    setMainFrameHeightSafe = ctx.SetMainFrameHeightSafe,
    setMainFrameWidthSafe = ctx.SetMainFrameWidthSafe,
    minFrameHeight = ctx.MIN_FRAME_HEIGHT,
    buildOrderedRoster = modules.roster.BuildOrderedRoster,
    buildDisplayData = modules.roster.BuildDisplayData,
    truncateName = function(name, maxChars)
      return ctx.TruncateName(name, maxChars)
    end,
    getShortSpecLabel = ctx.GetShortSpecLabel,
    getLanguageFlagMarkup = modules.locale.GetLanguageFlagMarkup,
    getLanguageTooltipMarkup = ctx.GetLanguageTooltipMarkup,
    getDungeonShortCode = function(mapID)
      local db = rawget(_G, "IsiLiveDB")
      local activeLocale = (db and db.locale) or ctx.locale
      return modules.teleport.GetDungeonShortCode(mapID, activeLocale)
    end,
    getRioDelta = ctx.GetRioDeltaForRosterInfo,
    resolveActiveKeyOwnerUnit = function()
      if ctx.ResolveActiveKeyOwnerUnit then
        return ctx.ResolveActiveKeyOwnerUnit()
      end
      return nil
    end,
    resolveTargetMapID = function()
      return ctx.ResolveStatusTargetMapID()
    end,
    isReadyCheckActive = function()
      return ctx.IsReadyCheckActive()
    end,
    getReadyCheckReadyUntil = function(unit)
      return ctx.GetReadyCheckReadyUntil(unit)
    end,
    getReadyCheckDeclinedUntil = function(unit)
      return ctx.GetReadyCheckDeclinedUntil(unit)
    end,
    getRoster = ctx.GetRoster,
    applySecureSpellToButton = ctx.ApplySecureSpellToButton,
    getEntries = modules.teleport.BuildTeleportEntries,
    getTeleportEmptyStateText = ctx.GetTeleportEmptyStateText,
    isSpellKnown = ctx.IsSpellKnownSafe,
    getTeleportCooldownRemaining = ctx.GetTeleportCooldownRemaining,
    formatCooldownSeconds = ctx.FormatCooldownSeconds,
    getSpellCooldownSafe = ctx.GetSpellCooldownSafe,
    getCooldownFrameStartForRemaining = ctx.GetCooldownFrameStartForRemaining,
    applyCooldownFrameSafe = ctx.ApplyCooldownFrameSafe,
    getSpellTexture = function(spellID)
      if spellID and C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID)
      end
      return nil
    end,
    getDungeonName = function(mapID, localeTag)
      local db = rawget(_G, "IsiLiveDB")
      local activeLocale = (db and db.locale) or ctx.locale
      return modules.teleport.GetDungeonName(mapID, localeTag or activeLocale)
    end,
    getTime = rawget(_G, "GetTime"),
    shareKeysDebounceSeconds = 30,
    getTargetDungeonInfo = ctx.GetStatusTargetDungeonInfo,
    isInChallengeMode = function()
      return ctx.GetActiveChallengeMapID() ~= nil -- secret-value-ok: ctx wrapper is pcall- and IsSecretValue-protected
    end,
    sendShareKeysRequest = function()
      return modules.sync.SendShareKeysRequest()
    end,
    isSyncUserKnown = function(name, realm)
      return modules.sync.IsUserKnown(name, realm)
    end,
    logRuntimeTrace = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil,
    logRuntimeTracef = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil,
    logRuntimeTraceDeep = ctx.runtimeLogController and ctx.runtimeLogController.TraceDeep or nil,
  })

  if type(modules.sync.SetTraceLogger) == "function" then
    modules.sync.SetTraceLogger(ctx.runtimeLogController and ctx.runtimeLogController.Trace or nil)
  end
  if type(modules.sync.SetDeepTraceLogger) == "function" then
    modules.sync.SetDeepTraceLogger(ctx.runtimeLogController and ctx.runtimeLogController.TraceDeep or nil)
  end
  if type(modules.sync.SetLogger) == "function" then
    modules.sync.SetLogger(nil)
  end
  ctx.keySyncController = initResult.keySyncController
  ctx.MarkIsiLiveUser = initResult.markIsiLiveUser
  ctx.UnitHasIsiLive = initResult.unitHasIsiLive
  ctx.RegisterIsiLiveSyncPrefix = initResult.registerIsiLiveSyncPrefix
  ctx.SendIsiLiveHello = initResult.sendIsiLiveHello
  ctx.SendRefreshRequest = initResult.sendRefreshRequest
  ctx.SendLibKeystonePartyData = initResult.sendLibKeystonePartyData
  ctx.GetOwnedKeystoneSnapshot = initResult.getOwnedKeystoneSnapshot
  ctx.SendOwnKeySnapshot = initResult.sendOwnKeySnapshot
  ctx.SendOwnBackgroundSnapshot = initResult.sendOwnBackgroundSnapshot
  ctx.SendRefreshResponse = initResult.sendRefreshResponse
  ctx.ApplyKnownKeyToRosterEntry = initResult.applyKnownKeyToRosterEntry
  ctx.RegisterVerifiedSyncAliasForRoster = initResult.registerVerifiedSyncAliasForRoster
  ctx.RecordRun = initResult.recordRun
  ctx.highlightController = initResult.highlightController
  ctx.rosterPanelController = initResult.rosterPanelController
  ctx.refreshButton = initResult.refreshButton
  ctx.countdownCancelButton = initResult.countdownCancelButton
  ctx.statusLine = initResult.statusLine
  ctx.TriggerShareKeysCooldown = initResult.triggerShareKeysCooldown
  ctx.teleportUIController = initResult.teleportUIController
  ctx.mplusTeleportButtons = initResult.mplusTeleportButtons
  ctx.UpdateLeaderButtons = function()
    ctx.rosterPanelController.UpdateLeaderButtons()
  end
  ctx.ApplyPendingLeaderButtonUpdates = function()
    if ctx.rosterPanelController and type(ctx.rosterPanelController.ApplyPendingLeaderButtonUpdates) == "function" then
      ctx.rosterPanelController.ApplyPendingLeaderButtonUpdates()
    end
  end
  ctx.IsRosterCollapsed = function()
    if not ctx.rosterPanelController then
      return false
    end
    return ctx.rosterPanelController.IsCollapsed()
  end
  ctx.RestoreLayoutState = function()
    ctx.rosterPanelController.RestoreSavedState()
  end
  ctx.UpdateUI = function()
    ctx.rosterPanelController.RenderRoster(ctx.GetRoster())
  end
  ctx.RefreshReadyCheckUI = function()
    ctx.rosterPanelController.RefreshReadyCheckState(ctx.GetRoster())
  end
  ctx.GetNormalizedActiveEntryInfo = function()
    return ctx.highlightController.GetNormalizedActiveEntryInfo()
  end
  ctx.ResolveActiveTeleportSpellID = function()
    local _, latestQueueActivityID, _, latestQueueMapID = ctx.runtimeState.GetLatestQueueState()
    local effectiveQueueMapID = latestQueueMapID
    local localTargetMapID = ctx.ResolveLocalStatusTargetMapID and ctx.ResolveLocalStatusTargetMapID() or nil
    if localTargetMapID then
      effectiveQueueMapID = localTargetMapID
    else
      local syncedTargetInfo = ctx.ResolveSyncedTargetInfo and ctx.ResolveSyncedTargetInfo() or nil
      if type(syncedTargetInfo) == "table" then
        effectiveQueueMapID = tonumber(syncedTargetInfo.mapID) or effectiveQueueMapID
      end
    end

    return ctx.highlightController.ResolveActiveTeleportSpellID(latestQueueActivityID, effectiveQueueMapID)
  end
  ctx.ResolveJoinedKeyMapID = function(activityID, spellID)
    return ctx.highlightController.ResolveJoinedKeyMapID(activityID, spellID)
  end
  ctx.ResolveActiveKeyOwnerUnit = function()
    local targetMapID = nil
    if type(ctx.ResolveStatusTargetMapID) == "function" then
      targetMapID = ctx.ResolveStatusTargetMapID()
    end

    local preferredOwnerName = nil
    local lfgDetect = addonTable.LFGDetect
    if type(lfgDetect) == "table" and type(lfgDetect.GetActiveInviteLeader) == "function" then
      preferredOwnerName = lfgDetect.GetActiveInviteLeader()
    end

    -- Fallback: when no LFG-leader hint is available (pre-formed group, or
    -- after invite-accepted state was cleared), use the current group leader
    -- as the hint. The played key always belongs to the leader, so without
    -- this fallback the unique-owner scan can pick a random group member who
    -- happens to hold a higher-level key for the same dungeon.
    if type(preferredOwnerName) ~= "string" or preferredOwnerName == "" then
      local roster = ctx.GetRoster() or {}
      local unitIsGroupLeaderFn = rawget(_G, "UnitIsGroupLeader")
      if type(unitIsGroupLeaderFn) == "function" then
        for unit, info in pairs(roster) do
          if type(unit) == "string" and unit ~= "" and type(info) == "table" and not info.isGhost then
            local okLeader, isLeader = pcall(unitIsGroupLeaderFn, unit)
            if okLeader and isLeader == true then
              preferredOwnerName = addonTable.StringUtils.BuildQualifiedName(info.name, info.realm)
              break
            end
          end
        end
      end
    end

    return ctx.keySyncController.ResolveActiveKeyOwnerUnit(ctx.GetRoster(), targetMapID, preferredOwnerName)
  end
  ctx.UpdateMPlusTeleportButton = function(soundContext)
    local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
    local logfDeep = ctx.runtimeLogController and ctx.runtimeLogController.LogfDeep or nil
    local traceDeep = ctx.runtimeLogController and ctx.runtimeLogController.TraceDeep or nil
    if soundContext and logf then
      logf("[TP] update_button_called soundContext=%s", tostring(soundContext))
    elseif logfDeep then
      logfDeep("[TP] update_button_called soundContext=%s", tostring(soundContext))
    end
    -- Priority 1: LFGDetect (invite accepted / own active listing). This is
    -- the strongest direct signal from the current LFG flow and must
    -- outrank sync/queue/listing resolution, which can otherwise surface a
    -- stale or peer-synced mapID that overrides the just-accepted invite.
    local resolvedSpellID = nil
    local lfgDetect = addonTable.LFGDetect
    local detectedMapID = type(lfgDetect) == "table"
        and type(lfgDetect.GetDetectedMapID) == "function"
        and lfgDetect.GetDetectedMapID()
      or nil
    if traceDeep then
      traceDeep(function()
        return string.format("[TP] lfg_detected_map detectedMapID=%s", tostring(detectedMapID))
      end)
    end
    if detectedMapID then
      resolvedSpellID = modules.teleport.ResolveTeleportSpellIDByMapID(detectedMapID)
      if traceDeep then
        traceDeep(function()
          return string.format(
            "[TP] spell_from_lfg mapID=%s resolvedSpellID=%s",
            tostring(detectedMapID),
            tostring(resolvedSpellID)
          )
        end)
      end
    end
    if not resolvedSpellID then
      resolvedSpellID = ctx.ResolveActiveTeleportSpellID()
      if traceDeep then
        traceDeep(function()
          return string.format("[TP] spell_from_active resolvedSpellID=%s", tostring(resolvedSpellID))
        end)
      end
    end
    if traceDeep then
      traceDeep(function()
        return string.format(
          "[TP] frame_show_check spellFound=%s soundContext=%s frameShown=%s",
          tostring(resolvedSpellID ~= nil),
          tostring(soundContext),
          tostring(ctx.mainFrame and ctx.mainFrame:IsShown())
        )
      end)
    end
    if
      resolvedSpellID
      and (soundContext == "queue" or soundContext == "invite")
      and type(ctx.mainFrame) == "table"
      and type(ctx.mainFrame.IsShown) == "function"
      and ctx.mainFrame:IsShown() ~= true
      and type(ctx.SetMainFrameVisible) == "function"
    then
      ctx.SetMainFrameVisible(true, {
        reason = "lfg-highlight",
        skipShowCallbacks = true,
      })
    end
    if traceDeep then
      traceDeep(function()
        return string.format("[TP] update_buttons_called resolvedSpellID=%s", tostring(resolvedSpellID))
      end)
    end
    ctx.teleportUIController.UpdateButtons(resolvedSpellID, soundContext)
  end

  -- ARCH-1 fix: inject UpdateMPlusTeleportButton into LFGDetect so the game-layer
  -- module no longer needs to reach into _factoryCtx directly.
  local lfgDetect = addonTable.LFGDetect
  if type(lfgDetect) == "table" then
    if type(lfgDetect.SetHighlightCallback) == "function" then
      lfgDetect.SetHighlightCallback(ctx.UpdateMPlusTeleportButton)
    end
    if type(lfgDetect.SetGroupRosterTraceLogger) == "function" then
      lfgDetect.SetGroupRosterTraceLogger(BuildLFGGroupRosterTraceLogger(ctx, modules))
    end
    if type(lfgDetect.SetTraceLogger) == "function" then
      lfgDetect.SetTraceLogger(ctx.runtimeLogController and ctx.runtimeLogController.Trace or nil)
    end
    if type(lfgDetect.SetDeepTraceLogger) == "function" then
      lfgDetect.SetDeepTraceLogger(ctx.runtimeLogController and ctx.runtimeLogController.TraceDeep or nil)
    end
    if type(lfgDetect.SetLogger) == "function" then
      lfgDetect.SetLogger(nil)
    end
    -- Pre-accept InviteHint plumbing: hand the floating-yellow-popup callback,
    -- the DB toggle reader, and the dungeon-name lookup over to LFGDetect.
    -- All three are nil-safe on the LFGDetect side, so partial wiring (early
    -- ADDON_LOADED state, tests) stays safe.
    if type(lfgDetect.SetInviteHintCallback) == "function" then
      lfgDetect.SetInviteHintCallback(ctx.ShowInviteHint)
    end
    if type(lfgDetect.SetInviteHintEnabledFn) == "function" then
      lfgDetect.SetInviteHintEnabledFn(function()
        local db = rawget(_G, "IsiLiveDB")
        if type(db) ~= "table" then
          return true
        end
        return db.inviteHintEnabled ~= false
      end)
    end
    if type(lfgDetect.SetTeleportLookupByMapID) == "function" and modules.teleport then
      lfgDetect.SetTeleportLookupByMapID(modules.teleport.GetTeleportInfoByMapID)
    end
    if type(lfgDetect.SetInviteHintLocaleFn) == "function" then
      lfgDetect.SetInviteHintLocaleFn(ctx.GetL)
    end

    -- Post-accept Center Notice plumbing. Triggered from OnInviteAccepted with
    -- a payload extracted exclusively from the accepted searchResultID's
    -- pendingInvites entry. Sibling listings (different searchResultID) cannot
    -- influence the rendered content. Level is taken straight from
    -- entry.titleLevel — when nil (group title without "+N"), the headline is
    -- rendered without a level suffix; never inferred from roster/sync data.
    -- Raid-only mirror is wired in the same helper so the M+ pipeline stays
    -- untouched for Raid invites.
    WireAcceptedInviteNoticeCallbacks(ctx, modules, lfgDetect)
  end
  ctx.ShowJoinedTargetNotice = function()
    ShowJoinedTargetNotice(ctx, modules)
  end

  InitializeInviteControllers(ctx, modules)

  -- Strips the "-Realm" suffix from a player name so the chat output reads
  -- naturally on the local realm. Cross-realm names keep their realm segment.
  local function FormatDisplayName(name)
    if type(name) ~= "string" or name == "" then
      return "?"
    end
    local dash = string.find(name, "-", 1, true)
    if not dash then
      return name
    end
    return string.sub(name, 1, dash - 1)
  end

  -- Renders a BR/Lust combat announcement locally via ctx.Print. Used both for
  -- the local self-cast (Ego-User) and for incoming addon-message broadcasts
  -- from isiLive peers. Locale-resolved so each receiver renders in its own
  -- client locale.
  ctx.ShowCombatAnnounce = function(info)
    if type(info) ~= "table" then
      return
    end
    local L = ctx.GetL and ctx.GetL() or {}
    local template
    if info.kind == "BR" then
      template = L.COMBAT_CHAT_BR_USED or "%s used BR"
      local soundUtils = addonTable.SoundUtils
      if type(soundUtils) == "table" and type(soundUtils.PlayBattleRes) == "function" then
        soundUtils.PlayBattleRes()
      end
    elseif info.kind == "LUST" then
      template = L.COMBAT_CHAT_LUST_STARTED or "%s started Bloodlust"
      local soundUtils = addonTable.SoundUtils
      if type(soundUtils) == "table" and type(soundUtils.PlayBloodlust) == "function" then
        soundUtils.PlayBloodlust()
      end
    else
      return
    end
    ctx.Print(string.format(template, FormatDisplayName(info.caster)))
  end

  -- Self-cast detected by combat_events: render locally and broadcast to all
  -- isiLive peers via the addon-message channel. Non-isiLive players see
  -- nothing (intentional - 12.0 SendChatMessage taint blocks the previous
  -- group-chat broadcast).
  ctx.BroadcastCombatAnnounce = function(kind, sourceName, spellID)
    local info = { kind = kind, caster = sourceName, spellID = spellID }
    ctx.ShowCombatAnnounce(info)
    if ctx.modules and ctx.modules.sync and type(ctx.modules.sync.SendCombatAnnounce) == "function" then
      ctx.modules.sync.SendCombatAnnounce(info)
    end
  end

  local combatEvents = addonTable.CombatEvents
  if type(combatEvents) == "table" and type(combatEvents.SetDependencies) == "function" then
    combatEvents.SetDependencies({
      getDB = function()
        return rawget(_G, "IsiLiveDB") or {}
      end,
      broadcastCombatAnnounce = ctx.BroadcastCombatAnnounce,
    })
  end
end
FI.InitializeFactoryPrimaryControllers = InitializeFactoryPrimaryControllers

local function InitializeFactoryRefreshAndStatusControllers(ctx)
  local modules = ctx.modules
  local runtimeState = ctx.runtimeState

  ctx.teleportDebugController = modules.teleportDebug.CreateController({
    printFn = ctx.Print,
    getL = ctx.GetL,
    updateMPlusTeleportButton = ctx.UpdateMPlusTeleportButton,
    resolveActiveTeleportSpellID = ctx.ResolveActiveTeleportSpellID,
    isSpellKnownSafe = ctx.IsSpellKnownSafe,
    getTeleportCooldownRemaining = ctx.GetTeleportCooldownRemaining,
    getSpellCooldownSafe = ctx.GetSpellCooldownSafe,
    formatCooldownSeconds = ctx.FormatCooldownSeconds,
    getLatestQueueState = function()
      return runtimeState.GetLatestQueueState()
    end,
    resolveMapIDByActivityID = ctx.ResolveMapIDByActivityID,
    resolveTeleportSpellIDByActivityID = ctx.ResolveTeleportSpellIDByActivityID,
    resolveTeleportSpellIDByMapID = modules.teleport.ResolveTeleportSpellIDByMapID,
    getNormalizedActiveEntryInfo = ctx.GetNormalizedActiveEntryInfo,
    resolveTeleportSpellID = ctx.ResolveTeleportSpellID,
    getCenterNoticeTeleportButton = function()
      return ctx.centerNoticeTeleportButton
    end,
    getMplusTeleportButtons = function()
      return ctx.mplusTeleportButtons
    end,
    showCenterNotice = ctx.ShowCenterNotice,
    setLatestQueueState = function(dungeonName, activityID, spellID, mapID)
      runtimeState.SetLatestQueueState(dungeonName, activityID, spellID, mapID)
      if ctx.UpdateStatusLine then
        ctx.UpdateStatusLine()
      end
    end,
  })

  ctx.ApplyLocalizationToUI = function()
    if modules.ui and type(modules.ui.EnsurePanelUI) == "function" then
      ctx.panelUI = modules.ui.EnsurePanelUI({
        getL = ctx.GetL,
        isInCombat = ctx.IsInCombat,
        isEnabled = function()
          return not IsiLiveDB or IsiLiveDB.showEscPanel ~= false
        end,
      })
    end
    if modules.ui and type(modules.ui.EnsureSecondPanelUI) == "function" then
      ctx.secondPanelUI = modules.ui.EnsureSecondPanelUI({
        getL = ctx.GetL,
        isInCombat = ctx.IsInCombat,
        isEnabled = function()
          return not IsiLiveDB or IsiLiveDB.showEscPanel ~= false
        end,
        firstPanelState = ctx.panelUI,
      })
    end
    if modules.ui and type(modules.ui.EnsureMountPanelUI) == "function" then
      ctx.mountPanelUI = modules.ui.EnsureMountPanelUI({
        getL = ctx.GetL,
        isInCombat = ctx.IsInCombat,
        isEnabled = function()
          return not IsiLiveDB or IsiLiveDB.showEscPanel ~= false
        end,
        travelPanelState = ctx.secondPanelUI,
      })
    end
    if modules.ui and type(modules.ui.EnsureThirdPanelUI) == "function" then
      ctx.thirdPanelUI = modules.ui.EnsureThirdPanelUI({
        getL = ctx.GetL,
        isInCombat = ctx.IsInCombat,
        isEnabled = function()
          return not IsiLiveDB or IsiLiveDB.showEscPanel ~= false
        end,
        secondPanelState = ctx.secondPanelUI,
        panelActions = {
          isilive = function()
            local blizzardSettings = rawget(_G, "Settings")
            if type(blizzardSettings) ~= "table" or type(blizzardSettings.OpenToCategory) ~= "function" then
              return false
            end
            if ctx.settingsPanel and ctx.settingsPanel.category then
              blizzardSettings.OpenToCategory(ctx.settingsPanel.category.ID)
              return true
            end
            return false
          end,
        },
      })
    end
    ctx.rosterPanelController.ApplyLocalization()
    ctx.UpdateCountdownCancelButton()
    if ctx.centerNoticeTeleportButton and ctx.centerNoticeTeleportButton:IsShown() then
      local spellID = ctx.centerNoticeTeleportButton.spellID
      local enabled = spellID and ctx.IsSpellKnownSafe(spellID) and not ctx.centerNoticeTeleportButton.inCombatBlocked
      ctx.UpdateCenterTeleportButtonVisual(spellID, enabled, ctx.centerNoticeTeleportButton.inCombatBlocked)
    end
    ctx.UpdateMPlusTeleportButton()
    ctx.UpdateStatusLine()
    if ctx.settingsPanel and type(ctx.settingsPanel.Refresh) == "function" then
      ctx.settingsPanel.Refresh()
    end
  end

  ctx.countdownCancelButton:SetScript("OnClick", function()
    if not ctx.IsPlayerLeader() then
      return
    end
    if C_PartyInfo and C_PartyInfo.DoCountdown then
      pcall(C_PartyInfo.DoCountdown, 0)
    end
  end)

  local function SetProcessingActive(isActive)
    local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
    if logf then
      logf("[UI] processing_active isActive=%s", tostring(isActive))
    end
    if isActive then
      ctx.mainFrame:SetScript("OnUpdate", ctx.InspectLoop)
      return
    end

    ctx.mainFrame:SetScript("OnUpdate", nil)
    ctx.inspectController.ResetQueues()
  end

  local statusController = modules.status.CreateController({
    getL = ctx.GetL,
    getSubZoneText = ctx.GetSubZoneText,
    getZoneText = ctx.GetZoneText,
    getRealZoneText = ctx.GetRealZoneText,
    getPlayerMapID = ctx.GetPlayerMapID,
    getMapInfoName = ctx.GetMapInfoName,
    getTeleportInfoByMapID = modules.teleport and modules.teleport.GetTeleportInfoByMapID or nil,
    timerAfter = function(seconds, callback)
      if C_Timer and C_Timer.After then
        C_Timer.After(seconds, function()
          pcall(callback)
        end)
      end
    end,
    showCenterNotice = ctx.ShowCenterNotice,
    hideCenterNotice = function()
      ctx.centerNotice.SetVisible(false)
    end,
    showPortalNavigatorNotice = ctx.ShowPortalNavigatorNotice,
    hidePortalNavigatorNotice = function()
      ctx.SetPortalNavigatorVisible(false)
    end,
    isPortalNavigatorEnabled = ctx.IsPortalNavigatorEnabled,
    isPlayerLeader = ctx.IsPlayerLeader,
    isInGroup = IsInGroup,
    getTargetDungeonInfo = ctx.GetStatusTargetDungeonInfo,
    -- Chat-announce gate: ResolveLocalStatusTargetMapID is non-nil only
    -- when the local player has an own queue, an active joined key, or
    -- a fresh LFG accept (detectedMapID via LFGDetect). A synced-only
    -- target — one that comes purely from another member's published
    -- snapshot — does NOT light up the local resolver and must not
    -- trigger a chat announce, even though the status frame still
    -- surfaces it as informational.
    hasLocalTargetSource = function()
      if type(ctx.ResolveLocalStatusTargetMapID) ~= "function" then
        return false
      end
      local localMapID = ctx.ResolveLocalStatusTargetMapID()
      return type(localMapID) == "number" and localMapID > 0
    end,
    hasActiveDungeons = function()
      local seasonData = ctx.addonTable.SeasonData
      if type(seasonData) == "table" and type(seasonData.HasActiveDungeons) == "function" then
        return seasonData.HasActiveDungeons()
      end
      return true
    end,
    getActiveSeasonLabel = function()
      local seasonData = ctx.addonTable.SeasonData
      if type(seasonData) == "table" and type(seasonData.GetSeasonLabel) == "function" then
        return seasonData.GetSeasonLabel()
      end
      return nil
    end,
    printFn = ctx.Print,
    printHighlighted = ctx.PrintHighlighted,
  })

  ctx.statusController = statusController
  ctx.UpdateStatusLine = function()
    local flags = runtimeState.GetRuntimeFlags()
    ctx.statusLine:SetText(statusController.BuildStatusLineText({
      isStopped = flags.isStopped,
      isPaused = flags.isPaused,
      isTestMode = flags.isTestMode,
    }))
    ctx.SendOwnTargetSnapshot(false, "status", true)
    statusController.MaybeAnnounceTargetDungeonChat()
  end

  -- Direct-push: route the LFG-accept payload (mapID + listing titleLevel)
  -- straight to the status controller's AnnounceTargetDungeonFromPayload
  -- entry point. The chat line then renders with exactly the same "+N"
  -- the Center Notice already drew from entry.titleLevel; the resolver
  -- chain inside MaybeAnnounceTargetDungeonChat is skipped for this path
  -- so race conditions on the LFG-title hint / roster-owner / synced-
  -- target sources cannot surface a wrong "+N" anymore. The
  -- levelAnnouncedTargetDungeonName lock-in is set as a side effect of
  -- EmitTargetDungeonAnnouncement, so the subsequent
  -- UpdateStatusLine-driven re-evaluation stays silent.
  --
  -- No IsInGroup gate: the LFG_LIST_APPLICATION_STATUS_UPDATED=inviteaccepted
  -- event fires before the matching GROUP_ROSTER_UPDATE, so IsInGroup() can
  -- transiently return false in this window (see isiLive_lfg_detect.lua's
  -- "ClearDetectedState" guard which explicitly documents the same race).
  -- The Center Notice path has no such gate and surfaces correctly; the
  -- chat line is a local print() (not SendChatMessage), so there is no
  -- protocol-level reason to require group membership for the announce.
  local lfgDetectForChat = addonTable.LFGDetect
  if type(lfgDetectForChat) == "table" and type(lfgDetectForChat.SetTargetDungeonChatCallback) == "function" then
    lfgDetectForChat.SetTargetDungeonChatCallback(function(payload)
      HandleTargetDungeonChatPayload(ctx, modules, statusController, payload)
    end)
  end

  local function QueueForceRefreshData()
    ctx.inspectController.QueueForceRefreshData(ctx.GetRoster())
  end

  local function ForceRefreshSyncState()
    ctx.keySyncController.ForceRefreshSyncState(ctx.GetRoster())
  end

  local function TriggerGroupRosterUpdate()
    local onEventHandler = ctx.mainFrame:GetScript("OnEvent")
    if onEventHandler then
      onEventHandler(ctx.mainFrame, "GROUP_ROSTER_UPDATE")
    end
  end

  ctx.TriggerGroupRosterUpdate = TriggerGroupRosterUpdate

  ctx.refreshController = modules.refresh.CreateController(modules.configBuilders.BuildRefreshControllerOpts({
    isStopped = runtimeState.IsStopped,
    isPaused = runtimeState.IsPaused,
    isTestMode = runtimeState.IsTestMode,
    isTestAllMode = runtimeState.IsTestAllMode,
    isInGroup = IsInGroup,
    isRosterEmpty = function()
      return next(ctx.GetRoster()) == nil
    end,
    triggerGroupRosterUpdate = ctx.TriggerGroupRosterUpdate,
    refreshTestModeRoster = function()
      if not ctx.testModeController then
        return false
      end
      return ctx.testModeController.RefreshActivePreview()
    end,
    forceRefreshSyncState = ForceRefreshSyncState,
    sendIsiLiveHello = ctx.SendIsiLiveHello,
    sendOwnKeySnapshot = ctx.SendOwnKeySnapshot,
    sendOwnBackgroundSnapshot = ctx.SendOwnBackgroundSnapshot,
    sendRefreshRequest = ctx.SendRefreshRequest,
    queueForceRefreshData = QueueForceRefreshData,
    updateUI = ctx.UpdateUI,
    refreshLocalPlayerKey = ctx.RefreshLocalPlayerKey,
    getActiveChallengeMapID = ctx.GetActiveChallengeMapID,
    getTime = rawget(_G, "GetTime"),
    refreshDebounceSeconds = 10,
    logRuntimeTrace = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil,
    logRuntimeTracef = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil,
  }))

  local RESYNC_COOLDOWN = 10
  local resyncCooldownEnd = 0
  local resyncTicker = nil

  local RI = ctx.addonTable and ctx.addonTable._RosterInternal or {}
  local setFlatButtonText = type(RI.SetFlatButtonText) == "function" and RI.SetFlatButtonText
    or function(btn, text)
      if btn and btn.SetText then
        btn:SetText(text)
      end
    end

  local function UpdateResyncButton()
    local btn = ctx.refreshButton
    if not btn then
      return
    end
    local getTimeFn = rawget(_G, "GetTime")
    local now = type(getTimeFn) == "function" and getTimeFn() or 0
    local remaining = math.ceil(resyncCooldownEnd - now)
    if remaining > 0 then
      btn:SetEnabled(false)
      btn:SetAlpha(0.5)
      local label = btn._baseText or btn._fullText or "Re-Sync"
      btn._baseText = label
      local cooldownText = string.format("%s (%ds)", label, remaining)
      btn._fullText = cooldownText
      setFlatButtonText(btn, cooldownText)
    else
      btn:SetEnabled(true)
      btn:SetAlpha(1.0)
      if btn._baseText then
        btn._fullText = btn._baseText
        btn._baseText = nil
      end
      local label = btn._fullText or "Re-Sync"
      setFlatButtonText(btn, label)
      if resyncTicker then
        resyncTicker:Cancel()
        resyncTicker = nil
      end
    end
  end

  ctx.refreshButton:SetScript("OnClick", function()
    local getTimeFn = rawget(_G, "GetTime")
    local now = type(getTimeFn) == "function" and getTimeFn() or 0
    if now < resyncCooldownEnd then
      return
    end
    local logFn = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil
    if logFn then
      logFn("[UI] btn_click name=refresh")
    end
    ctx.refreshController.RunFullRefresh()
    resyncCooldownEnd = now + RESYNC_COOLDOWN
    if resyncTicker then
      resyncTicker:Cancel()
    end
    if C_Timer and C_Timer.NewTicker then
      resyncTicker = C_Timer.NewTicker(1.0, UpdateResyncButton, RESYNC_COOLDOWN)
    end
    UpdateResyncButton()
  end)

  ctx.SetProcessingActive = SetProcessingActive
end
FI.InitializeFactoryRefreshAndStatusControllers = InitializeFactoryRefreshAndStatusControllers

local function RegisterBlizzardUnitLanguageTooltip(ctx, modules)
  ctx.GetUnitServerLanguage = function(unit, realm)
    return modules.contextHelpers.GetUnitServerLanguage(modules.locale, ctx.GetRealmInfoLib, unit, realm)
  end

  local rosterTooltip = ctx.addonTable and ctx.addonTable._RosterInternal
  if type(rosterTooltip) == "table" and type(rosterTooltip.RegisterBlizzardUnitLanguageTooltip) == "function" then
    rosterTooltip.RegisterBlizzardUnitLanguageTooltip({
      getUnitNameAndRealm = ctx.GetUnitNameAndRealm,
      getUnitServerLanguage = ctx.GetUnitServerLanguage,
      getRealmInfoLib = ctx.GetRealmInfoLib,
      getLanguageTooltipMarkup = ctx.GetLanguageTooltipMarkup,
    })
  end

  local lfgFlags = ctx.addonTable and ctx.addonTable.LFGFlags
  if type(lfgFlags) == "table" and type(lfgFlags.Register) == "function" then
    lfgFlags.Register({
      getRealmInfoLib = ctx.GetRealmInfoLib,
      localeModule = modules.locale,
    })
  end
end

local DEMO_FEATURE_NIL = {}
local DEMO_FEATURE_TARGET_DUNGEON_NAME = "Nexus-Point Xenas"
local DEMO_FEATURE_TARGET_MAP_ID = 559
local DEMO_FEATURE_NON_MYTHIC_DUNGEON_NAME = "Priorei der Heiligen Flamme"
local DEMO_FEATURE_NON_MYTHIC_NOTICE_DELAY_SECONDS = 8
local DEMO_FEATURE_PORTAL_NAVIGATOR_MAP_IDS = {
  left = 161,
  half_left = 556,
  half_right = 402,
  right = 239,
}
local DEMO_FEATURE_DB_KEYS = {
  "acceptedInviteNoticeEnabled",
  "groupJoinNoticeEnabled",
  "statsBoxEnabled",
  "statsBoxBgAlpha",
  "statsBoxFontSizeOffset",
  "lfgFlagsEnabled",
  "lfgGroupBonusesEnabled",
  "mobNameplateEnabled",
  "mplusForcesEstimate",
  "mobNameplateShowPercent",
  "mobNameplateShowRemaining",
  "mobNameplateFontSize",
  "mobNameplatePosition",
  "mobNameplateXOffset",
  "mobNameplateYOffset",
}

local function CaptureDemoFeatureSnapshot(db)
  local snapshot = {}
  for _, key in ipairs(DEMO_FEATURE_DB_KEYS) do
    local value = db[key]
    if value == nil then
      snapshot[key] = DEMO_FEATURE_NIL
    else
      snapshot[key] = value
    end
  end
  return snapshot
end

local function RestoreDemoFeatureSnapshot(db, snapshot)
  for _, key in ipairs(DEMO_FEATURE_DB_KEYS) do
    local value = snapshot[key]
    if value == DEMO_FEATURE_NIL then
      db[key] = nil
    elseif value ~= nil then
      db[key] = value
    end
  end
end

local function ApplyDemoFeatureDbOverrides(ctx)
  local db = rawget(_G, "IsiLiveDB")
  if type(db) ~= "table" then
    return nil
  end

  if type(ctx._demoFeatureSnapshot) ~= "table" then
    ctx._demoFeatureSnapshot = CaptureDemoFeatureSnapshot(db)
  end

  db.statsBoxEnabled = true
  db.statsBoxBgAlpha = 0.35
  db.acceptedInviteNoticeEnabled = true
  db.groupJoinNoticeEnabled = true
  db.lfgFlagsEnabled = true
  db.lfgGroupBonusesEnabled = true
  db.mobNameplateEnabled = true
  db.mplusForcesEstimate = true

  return db
end

local function ApplyDemoStatsBox(ctx)
  local statsBox = ctx.addonTable and ctx.addonTable.StatsBox
  if type(statsBox) ~= "table" then
    return
  end

  if type(statsBox.SetDemoData) == "function" then
    statsBox.SetDemoData({
      { key = "strength", label = "Str", value = 4210 },
      { key = "stamina", label = "Stam", value = 6812 },
      { key = "crit", label = "Crit", value = 1824, percent = 24.85 },
      { key = "haste", label = "Haste", value = 1492, percent = 18.42 },
      { key = "mastery", label = "Mast", value = 2108, percent = 37.66 },
      { key = "versatility", label = "Vers", value = 1154, percent = 14.12 },
      { key = "leech", label = "Leech", value = 238, percent = 3.27 },
      { key = "speed", label = "Speed", value = 326, percent = 6.44 },
      { key = "durability", label = "Dur", valueText = "483", percent = 96.60 },
      { key = "avoidance", label = "Avoid", value = 412, percent = 5.18 },
    })
  end
  if type(statsBox.SetEnabled) == "function" then
    statsBox.SetEnabled(true)
  end
end

local function ApplyDemoLfgFlags(ctx)
  local lfgFlags = ctx.addonTable and ctx.addonTable.LFGFlags
  if type(lfgFlags) ~= "table" then
    return
  end

  if type(lfgFlags.SetEnabled) == "function" then
    lfgFlags.SetEnabled(true)
  end
  if type(lfgFlags.SetGroupBonusesEnabled) == "function" then
    lfgFlags.SetGroupBonusesEnabled(true)
  end
end

local function ApplyDemoMobForces(ctx)
  local mobTooltip = ctx.addonTable and ctx.addonTable.MobTooltip
  if type(mobTooltip) == "table" and type(mobTooltip.SetEnabled) == "function" then
    mobTooltip.SetEnabled(true)
  end

  local mobNameplate = ctx.addonTable and ctx.addonTable.MobNameplate
  if type(mobNameplate) ~= "table" then
    return
  end

  if type(mobNameplate.SetTestMode) == "function" then
    mobNameplate.SetTestMode(true, "12.34")
  elseif type(mobNameplate.SetEnabled) == "function" then
    mobNameplate.SetEnabled(true)
  end
end

local function ApplyDemoPortalNavigatorTeleportInfo(ctx, entry, mapID)
  entry.mapID = mapID
  local teleport = ctx.modules and ctx.modules.teleport
  if type(teleport) ~= "table" or type(teleport.GetTeleportInfoByMapID) ~= "function" then
    return
  end

  local ok, info = pcall(teleport.GetTeleportInfoByMapID, mapID)
  if not ok or type(info) ~= "table" then
    return
  end

  local spellID = tonumber(info.spellID)
  if spellID and spellID > 0 then
    entry.spellID = math.floor(spellID)
  end
  if type(info.icon) == "string" or type(info.icon) == "number" then
    entry.icon = info.icon
  end
end

local function BuildDemoPortalNavigatorEntry(ctx, slot, direction, destination, opts)
  local entry = {
    slot = slot,
    direction = direction,
    destination = destination,
  }
  if type(opts) == "table" then
    entry.detail = opts.detail
    entry.isEmpty = opts.isEmpty == true
  end

  local mapID = DEMO_FEATURE_PORTAL_NAVIGATOR_MAP_IDS[slot]
  if mapID then
    ApplyDemoPortalNavigatorTeleportInfo(ctx, entry, mapID)
  end
  return entry
end

local function ShowDemoPortalNavigator(ctx, L)
  if type(ctx.ShowPortalNavigatorNotice) ~= "function" then
    return
  end

  ctx.ShowPortalNavigatorNotice({
    title = L.PORTAL_NAVIGATOR_TITLE or "Timeways Portal Navigator",
    entries = {
      BuildDemoPortalNavigatorEntry(
        ctx,
        "left",
        L.PORTAL_NAVIGATOR_LEFT or "Left",
        L.PORTAL_NAVIGATOR_SKYREACH or "Skyreach"
      ),
      BuildDemoPortalNavigatorEntry(
        ctx,
        "half_left",
        L.PORTAL_NAVIGATOR_HALF_LEFT or "Half-left",
        L.PORTAL_NAVIGATOR_PIT_OF_SARON or "Pit of Saron"
      ),
      BuildDemoPortalNavigatorEntry(
        ctx,
        "center",
        L.PORTAL_NAVIGATOR_CENTER or "Straight ahead",
        L.PORTAL_NAVIGATOR_HEAVEN or "Heaven",
        { detail = L.PORTAL_NAVIGATOR_UNOCCUPIED or "Unoccupied", isEmpty = true }
      ),
      BuildDemoPortalNavigatorEntry(
        ctx,
        "half_right",
        L.PORTAL_NAVIGATOR_HALF_RIGHT or "Half-right",
        L.PORTAL_NAVIGATOR_ALGETHAR or "Algeth'ar Academy"
      ),
      BuildDemoPortalNavigatorEntry(
        ctx,
        "right",
        L.PORTAL_NAVIGATOR_RIGHT or "Right",
        L.PORTAL_NAVIGATOR_TRIUMVIRATE or "Seat of the Triumvirate"
      ),
    },
  })
end

local function BuildDemoAcceptedInviteNoticePayload(L)
  return {
    message = nil,
    durationSeconds = nil,
    dungeonName = DEMO_FEATURE_TARGET_DUNGEON_NAME,
    activityID = nil,
    showOptions = {
      eyebrow = L.INVITE_ACCEPTED_NOTICE_EYEBROW or "M+ Target",
      title = L.INVITE_ACCEPTED_NOTICE_TITLE or "isiLive - Invite accepted",
      fields = {
        { label = L.INVITE_ACCEPTED_NOTICE_LABEL_DUNGEON or "Dungeon:", value = "Nexus-Point Xenas +15" },
        { label = L.INVITE_ACCEPTED_NOTICE_LABEL_GROUP or "Group:", value = "+15 Demo Preview" },
        { label = L.INVITE_ACCEPTED_NOTICE_LABEL_LEADER or "Leader:", value = "isiLive-Demo" },
        {
          label = L.INVITE_ACCEPTED_NOTICE_LABEL_SOURCE or "Source:",
          value = L.INVITE_ACCEPTED_NOTICE_SOURCE_LFG_ACCEPTED or "LFG accepted invite",
        },
      },
      teleportMapID = DEMO_FEATURE_TARGET_MAP_ID,
      frameWidth = 680,
      persistent = true,
    },
  }
end

local function ShowDemoAcceptedInviteNotice(ctx, L)
  if type(ctx.ShowCenterNotice) ~= "function" then
    return
  end

  local payload = BuildDemoAcceptedInviteNoticePayload(L)
  ctx.ShowCenterNotice(
    payload.message,
    payload.durationSeconds,
    payload.dungeonName,
    payload.activityID,
    payload.showOptions
  )
end

local function BuildDemoNonMythicDungeonNoticePayload(L)
  return {
    message = string.format(
      L.NON_MYTHIC_ENTERED or "Warning: Entered non-Mythic dungeon (%s).",
      L.DUNGEON_DIFF_NORMAL or "Normal"
    ),
    durationSeconds = 120,
    dungeonName = nil,
    activityID = nil,
    showOptions = {
      eyebrow = L.NON_MYTHIC_NOTICE_DUNGEON_EYEBROW or "Dungeon",
      title = L.NON_MYTHIC_NOTICE_DUNGEON_TITLE or "isiLive - Dungeon entered",
      fields = {
        {
          label = L.NON_MYTHIC_NOTICE_LABEL_DUNGEON or "Dungeon:",
          value = L.NON_MYTHIC_NOTICE_DEMO_DUNGEON or DEMO_FEATURE_NON_MYTHIC_DUNGEON_NAME,
        },
        {
          label = L.NON_MYTHIC_NOTICE_LABEL_DIFFICULTY or "Difficulty:",
          value = L.DUNGEON_DIFF_NORMAL or "Normal",
        },
        {
          label = L.NON_MYTHIC_NOTICE_LABEL_HINT or "Hint:",
          value = L.NON_MYTHIC_NOTICE_HINT_NON_MYTHIC or "Not a Mythic+ dungeon",
          warning = true,
          blink = true,
        },
        {
          label = L.NON_MYTHIC_NOTICE_LABEL_SOURCE or "Source:",
          value = L.NON_MYTHIC_NOTICE_SOURCE_INSTANCE_ENTERED or "Instance entered",
        },
      },
      frameWidth = 680,
      persistent = true,
    },
  }
end

local function ShowDemoNonMythicDungeonNotice(ctx, L)
  if type(ctx.ShowCenterNotice) ~= "function" then
    return
  end

  local payload = BuildDemoNonMythicDungeonNoticePayload(L)
  ctx.ShowCenterNotice(
    payload.message,
    payload.durationSeconds,
    payload.dungeonName,
    payload.activityID,
    payload.showOptions
  )
end

local function ApplyDemoFeatureData(ctx)
  ctx._demoFeatureActive = true
  ApplyDemoFeatureDbOverrides(ctx)
  ApplyDemoStatsBox(ctx)
  ApplyDemoLfgFlags(ctx)
  ApplyDemoMobForces(ctx)

  local L = ctx.GetL and ctx.GetL() or {}
  ShowDemoPortalNavigator(ctx, L)
  if type(ctx.ShowDemoCenterNotices) == "function" then
    ctx.ShowDemoCenterNotices({
      BuildDemoAcceptedInviteNoticePayload(L),
      BuildDemoNonMythicDungeonNoticePayload(L),
    })
  else
    ShowDemoAcceptedInviteNotice(ctx, L)
    if C_Timer and C_Timer.After then
      C_Timer.After(DEMO_FEATURE_NON_MYTHIC_NOTICE_DELAY_SECONDS, function()
        if ctx._demoFeatureActive == true then
          ShowDemoNonMythicDungeonNotice(ctx, ctx.GetL and ctx.GetL() or L)
        end
      end)
    else
      ShowDemoNonMythicDungeonNotice(ctx, L)
    end
  end
end

local function RestoreDemoStatsBox(ctx)
  local statsBox = ctx.addonTable and ctx.addonTable.StatsBox
  if type(statsBox) ~= "table" then
    return
  end

  if type(statsBox.ClearDemoData) == "function" then
    statsBox.ClearDemoData()
  end
  if type(statsBox.ApplySettings) == "function" then
    statsBox.ApplySettings()
  end
end

local function RestoreDemoMobForces(ctx, db)
  local mobTooltip = ctx.addonTable and ctx.addonTable.MobTooltip
  if type(mobTooltip) == "table" and type(mobTooltip.SetEnabled) == "function" then
    mobTooltip.SetEnabled(type(db) == "table" and db.mplusForcesEstimate == true)
  end

  local mobNameplate = ctx.addonTable and ctx.addonTable.MobNameplate
  if type(mobNameplate) ~= "table" then
    return
  end

  if type(mobNameplate.SetTestMode) == "function" then
    mobNameplate.SetTestMode(false)
  end
  if type(mobNameplate.SetFormat) == "function" then
    mobNameplate.SetFormat({
      showPercent = type(db) ~= "table" or db.mobNameplateShowPercent ~= false,
      showRemaining = type(db) ~= "table" or db.mobNameplateShowRemaining ~= false,
    })
  end
  if type(mobNameplate.SetAppearance) == "function" then
    mobNameplate.SetAppearance({
      fontSize = type(db) == "table" and tonumber(db.mobNameplateFontSize) or 14,
      position = type(db) == "table" and db.mobNameplatePosition or "RIGHT",
      xOffset = type(db) == "table" and tonumber(db.mobNameplateXOffset) or 0,
      yOffset = type(db) == "table" and tonumber(db.mobNameplateYOffset) or 0,
    })
  end
  if type(mobNameplate.SetEnabled) == "function" then
    mobNameplate.SetEnabled(type(db) == "table" and db.mobNameplateEnabled == true)
  end
end

local function RestoreDemoLfgFlags(ctx, db)
  local lfgFlags = ctx.addonTable and ctx.addonTable.LFGFlags
  if type(lfgFlags) ~= "table" then
    return
  end

  if type(lfgFlags.SetEnabled) == "function" then
    lfgFlags.SetEnabled(type(db) ~= "table" or db.lfgFlagsEnabled ~= false)
  end
  if type(lfgFlags.SetGroupBonusesEnabled) == "function" then
    lfgFlags.SetGroupBonusesEnabled(type(db) ~= "table" or db.lfgGroupBonusesEnabled ~= false)
  end
end

local function ClearDemoFeatureData(ctx)
  ctx._demoFeatureActive = false
  if type(ctx.SetDemoCenterNoticesVisible) == "function" then
    ctx.SetDemoCenterNoticesVisible(false)
  end
  local db = rawget(_G, "IsiLiveDB")
  local snapshot = ctx._demoFeatureSnapshot
  if type(db) == "table" and type(snapshot) == "table" then
    RestoreDemoFeatureSnapshot(db, snapshot)
  end
  ctx._demoFeatureSnapshot = nil

  RestoreDemoStatsBox(ctx)
  RestoreDemoLfgFlags(ctx, db)
  RestoreDemoMobForces(ctx, db)

  if type(ctx.SetPortalNavigatorVisible) == "function" then
    ctx.SetPortalNavigatorVisible(false)
  end
end

local function InitializeFactorySecondaryTestModeAndBindings(ctx, modules, runtimeState)
  ctx.testModeController = modules.testMode.CreateController(modules.configBuilders.BuildTestModeControllerOpts({
    getL = ctx.GetL,
    printFn = ctx.Print,
    getState = runtimeState.GetRuntimeFlags,
    setState = runtimeState.PatchRuntimeFlags,
    buildDummyRoster = ctx.BuildDummyRoster,
    setRoster = ctx.SetRoster,
    setMainFrameVisible = ctx.SetMainFrameVisible,
    updateUI = ctx.UpdateUI,
    updateLeaderButtons = ctx.UpdateLeaderButtons,
    showCenterNotice = ctx.ShowCenterNotice,
    resetInspectAll = ctx.ResetInspectAll,
    clearLatestQueueState = function()
      runtimeState.ClearLatestQueueTarget({ keepActiveJoinedKey = true })
    end,
    captureRioBaselineSnapshot = ctx.CaptureRioBaselineSnapshot,
    clearRioBaselineSnapshot = ctx.ClearRioBaselineSnapshot,
    enableRioDeltaDisplay = ctx.EnableRioDeltaDisplay,
    setDemoTimerData = function()
      local MplusTimer = ctx.addonTable and ctx.addonTable.MplusTimer
      if type(MplusTimer) == "table" and type(MplusTimer.SetDemoData) == "function" then
        MplusTimer.SetDemoData({
          running = true,
          completed = false,
          timer = 780,
          timeLimit = 1800,
          keyLevel = 15,
          timeRemaining1 = 1020,
          timeRemaining2 = 660,
          timeRemaining3 = 300,
          deaths = 2,
          deathTimeLost = 8,
        })
      end
      if type(runtimeState.SetLatestQueueState) == "function" then
        runtimeState.SetLatestQueueState(DEMO_FEATURE_TARGET_DUNGEON_NAME, nil, nil, DEMO_FEATURE_TARGET_MAP_ID)
      end
      local KillTrack = ctx.addonTable and ctx.addonTable.KillTrack
      if type(KillTrack) == "table" and type(KillTrack.SetDemoData) == "function" then
        KillTrack.SetDemoData({
          active = true,
          percent = 47.34,
          rawCount = 204,
          total = 431,
          mapID = DEMO_FEATURE_TARGET_MAP_ID,
          inCombat = true,
          pullPercent = 3.21,
        })
      end
      -- cdTrackerController is created after testModeController, so always defer.
      local C_Timer_ref = rawget(_G, "C_Timer")
      if type(C_Timer_ref) == "table" and type(C_Timer_ref.After) == "function" then
        C_Timer_ref.After(0.2, function()
          if ctx.cdTrackerController and type(ctx.cdTrackerController.SetDemoData) == "function" then
            ctx.cdTrackerController.SetDemoData({
              bres = { charges = 0, maxCharges = 1, cooldownRemain = 112 },
              lust = { remain = 23, icon = nil },
            })
          end
          if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshCdTracker) == "function" then
            ctx.rosterPanelController.RefreshCdTracker()
          end
        end)
      end
    end,
    clearDemoTimerData = function()
      local MplusTimer = ctx.addonTable and ctx.addonTable.MplusTimer
      if type(MplusTimer) == "table" and type(MplusTimer.ClearDemoData) == "function" then
        MplusTimer.ClearDemoData()
      end
      local KillTrack = ctx.addonTable and ctx.addonTable.KillTrack
      if type(KillTrack) == "table" and type(KillTrack.ClearDemoData) == "function" then
        KillTrack.ClearDemoData()
      end
      if ctx.cdTrackerController and type(ctx.cdTrackerController.ClearDemoData) == "function" then
        ctx.cdTrackerController.ClearDemoData()
      end
      if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshCdTracker) == "function" then
        ctx.rosterPanelController.RefreshCdTracker()
      end
    end,
    setDemoFeatureData = function()
      ApplyDemoFeatureData(ctx)
    end,
    clearDemoFeatureData = function()
      ClearDemoFeatureData(ctx)
    end,
    updateMPlusTeleportButton = ctx.UpdateMPlusTeleportButton,
    setCenterNoticeVisible = ctx.SetCenterNoticeVisible,
    hideInviteHint = function()
      ctx.inviteHint.frame:Hide()
    end,
    triggerGroupRosterUpdate = ctx.TriggerGroupRosterUpdate,
  }))

  ctx.EnterFullDummyPreview = function()
    local logFn = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil
    if logFn then
      logFn("[TESTMODE] enter_full_dummy_preview")
    end
    ctx.testModeController.EnterFullDummyPreview()
  end
  ctx.ExitTestMode = function()
    local logFn = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil
    if logFn then
      logFn("[TESTMODE] exit")
    end
    ctx.testModeController.ExitTestMode()
  end
  ctx.ToggleStandardTestMode = function()
    local logFn = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil
    if logFn then
      logFn("[TESTMODE] toggle_standard")
    end
    ctx.testModeController.ToggleStandardTestMode()
  end
  ctx.ToggleDemoMode = function()
    local wasTestMode = runtimeState.IsTestMode() or runtimeState.IsTestAllMode()
    local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
    if logf then
      logf("[TESTMODE] toggle_demo wasTestMode=%s", tostring(wasTestMode))
    end
    ctx.testModeController.ToggleDemoMode()
    -- After demo exit, pretend we just left a group so HandleNoGroup rebuilds
    -- the player entry correctly even when the player is solo.
    if wasTestMode then
      ctx.SetWasInGroup(true)
      ctx.TriggerGroupRosterUpdate()
    end
  end

  ctx.bindingController = modules.bindings.CreateController({
    onToggleMainFrame = ctx.ToggleMainFrameVisibility,
    onToggleTestMode = ctx.ToggleDemoMode,
  })
  ctx.ApplyHotkeyBindings()
end

local function InitializeFactorySecondaryRuntimeMethods(ctx, modules)
  ctx.SetLanguage = function(tag)
    local resolved = modules.locale.ResolveLocaleTag(tag)
    local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
    if logf then
      logf("[SETTINGS] set_language tag=%s resolved=%s", tostring(tag), tostring(resolved))
    end
    ctx.L = ctx.locales[resolved] or ctx.locales.enUS
    if IsiLiveDB then
      IsiLiveDB.locale = resolved
    end
    ctx.ApplyLocalizationToUI()
    local langMsgKey = "LANG_SET_EN"
    if resolved == "deDE" then
      langMsgKey = "LANG_SET_DE"
    elseif resolved == "frFR" then
      langMsgKey = "LANG_SET_FR"
    elseif resolved == "esES" then
      langMsgKey = "LANG_SET_ES"
    elseif resolved == "ptBR" then
      langMsgKey = "LANG_SET_PT"
    elseif resolved == "itIT" then
      langMsgKey = "LANG_SET_IT"
    elseif resolved == "ruRU" then
      langMsgKey = "LANG_SET_RU"
    elseif resolved == "trTR" then
      langMsgKey = "LANG_SET_TR"
    end
    ctx.Print(ctx.L[langMsgKey])
  end
  ctx.SetLocaleTable = function(value)
    ctx.L = value
  end
  ctx.EnqueueInspect = function(unit)
    ctx.inspectController.EnqueueInspect(unit, ctx.GetRoster())
  end
  ctx.CheckIfEnteredTargetDungeon = function()
    local logFn = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil
    local logDeepFn = ctx.runtimeLogController and ctx.runtimeLogController.LogDeep or nil
    local targetMapID = ctx.ResolveStatusTargetMapID()
    if not targetMapID then
      return
    end

    local currentMapID = nil
    if not currentMapID and C_Map and C_Map.GetBestMapForUnit and type(UnitExists) == "function" then
      local okUnit, playerExists = pcall(UnitExists, "player")
      if okUnit and playerExists then
        local okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        if okMap and type(mapID) == "number" and mapID > 0 then
          currentMapID = mapID
        end
      end
    end
    if not currentMapID then
      return
    end

    local matched = currentMapID == targetMapID
    local logTarget = matched and logFn or logDeepFn
    if logTarget then
      logTarget(
        string.format(
          "[STATE] check_entered_target_dungeon targetMapID=%s currentMapID=%s match=%s",
          tostring(targetMapID),
          tostring(currentMapID),
          tostring(matched)
        )
      )
    end
    if targetMapID and currentMapID == targetMapID then
      local lfgDetect = addonTable.LFGDetect
      if type(lfgDetect) == "table" and type(lfgDetect.ClearAllState) == "function" then
        lfgDetect.ClearAllState()
      end
      ctx.ClearLatestQueueTarget()
      ctx.UpdateMPlusTeleportButton()
      return
    end
  end
end

local function InitializeFactorySecondaryCdTracker(
  ctx,
  modules,
  runtimeState,
  getTime,
  IsMainFrameShown,
  IsRaidModeActive
)
  if not (modules.cdTracker and type(modules.cdTracker.CreateController) == "function") then
    return
  end

  ctx.cdTrackerController = modules.cdTracker.CreateController({
    getTime = getTime,
  })
  local lastLustActive = false
  ctx.UpdateCdTracker = function(opts)
    if IsRaidModeActive() then
      return
    end
    ctx.cdTrackerController.Scan()
    local lustInfo = type(ctx.cdTrackerController.GetLustInfo) == "function" and ctx.cdTrackerController.GetLustInfo()
      or nil
    local lustActive = type(lustInfo) == "table" and tonumber(lustInfo.remain) ~= nil and lustInfo.remain > 0
    if
      lustActive
      and not lastLustActive
      and type(opts) == "table"
      and opts.playLustSoundOnStart == true
      and ctx.addonTable
      and type(ctx.addonTable.SoundUtils) == "table"
      and type(ctx.addonTable.SoundUtils.PlayBloodlust) == "function"
    then
      ctx.addonTable.SoundUtils.PlayBloodlust()
    end
    lastLustActive = lustActive
    if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshCdTracker) == "function" then
      ctx.rosterPanelController.RefreshCdTracker()
    end
    if
      runtimeState
      and type(runtimeState.IsReadyCheckActive) == "function"
      and type(runtimeState.HasReadyCheckHold) == "function"
      and (runtimeState.IsReadyCheckActive() or runtimeState.HasReadyCheckHold())
      and ctx.rosterPanelController
      and type(ctx.rosterPanelController.RefreshReadyCheckState) == "function"
    then
      ctx.rosterPanelController.RefreshReadyCheckState(ctx.GetRoster())
    end
    -- Also refresh full UI if M+ key is running so the timer counts down.
    local MplusTimer = ctx.addonTable and ctx.addonTable.MplusTimer
    if type(MplusTimer) == "table" and type(MplusTimer.GetTimerData) == "function" then
      local timerData = MplusTimer.GetTimerData()
      if timerData and timerData.running then
        if ctx.UpdateUI then
          ctx.UpdateUI()
        end
      end
    end
  end
  if ctx.rosterPanelController and type(ctx.rosterPanelController.SetCdController) == "function" then
    ctx.rosterPanelController.SetCdController(ctx.cdTrackerController)
  end

  -- Subscribe the kill-track row to state updates so the pull bar refreshes
  -- on every scenario tick / combat transition instead of only on roster
  -- renders (which fire on sync events, not on scenario progress).
  local killTrack = ctx.addonTable and ctx.addonTable.KillTrack
  if type(killTrack) == "table" then
    if type(killTrack.OnUpdate) == "function" then
      killTrack.OnUpdate(function()
        if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshKillTrackRow) == "function" then
          ctx.rosterPanelController.RefreshKillTrackRow()
        end
        local mobNameplate = ctx.addonTable and ctx.addonTable.MobNameplate
        if type(mobNameplate) == "table" and type(mobNameplate.RefreshAll) == "function" then
          mobNameplate.RefreshAll()
        end
      end)
    end
    -- Forward API-vs-DB total drift warnings into the runtime log so they
    -- surface in /isilive log dump without spamming chat.
    if type(killTrack.SetDebugLogger) == "function" then
      killTrack.SetDebugLogger(function(fmt, ...)
        if ctx.runtimeLogController and type(ctx.runtimeLogController.Logf) == "function" then
          ctx.runtimeLogController.Logf(fmt, ...)
        end
      end)
    end
  end
  -- Ticker: scan + UI refresh every second for countdown timers (BL remaining time).
  -- Gated on the M+ key being active OR a Bloodlust countdown still running, so
  -- a freshly opened main frame in town does not burn 40 pcall(GetAuraDataByIndex)
  -- and a full roster render every second for state that cannot change.
  local C_Timer_ref = rawget(_G, "C_Timer")
  if type(C_Timer_ref) == "table" and type(C_Timer_ref.NewTicker) == "function" then
    C_Timer_ref.NewTicker(1.0, function()
      if not IsMainFrameShown() then
        return
      end
      local needsTick = false
      local MplusTimer = ctx.addonTable and ctx.addonTable.MplusTimer
      if type(MplusTimer) == "table" and type(MplusTimer.GetTimerData) == "function" then
        local timerData = MplusTimer.GetTimerData()
        if timerData and timerData.running then
          needsTick = true
        end
      end
      if not needsTick and ctx.cdTrackerController and type(ctx.cdTrackerController.GetLustInfo) == "function" then
        local lustInfo = ctx.cdTrackerController.GetLustInfo()
        if lustInfo and tonumber(lustInfo.remain) and lustInfo.remain > 0 then
          needsTick = true
        end
      end
      if needsTick then
        ctx.UpdateCdTracker()
      end
    end)
  end
end

local function InitializeFactorySecondaryControllers(ctx)
  local modules = ctx.modules
  local runtimeState = ctx.runtimeState
  local getTime = rawget(_G, "GetTime")
  local getUnitName = UnitName
  local getRealmName = GetRealmName

  local function IsMainFrameShown()
    return ctx.mainFrame and type(ctx.mainFrame.IsShown) == "function" and ctx.mainFrame:IsShown() == true
  end

  local function IsRaidModeActive()
    return type(ctx.IsRaidGroup) == "function" and ctx.IsRaidGroup() == true
  end

  RegisterBlizzardUnitLanguageTooltip(ctx, modules)
  InitializeFactorySecondaryTestModeAndBindings(ctx, modules, runtimeState)
  InitializeFactorySecondaryRuntimeMethods(ctx, modules)
  InitializeFactorySecondaryCdTracker(ctx, modules, runtimeState, getTime, IsMainFrameShown, IsRaidModeActive)
  if type(FI.InitializeFactorySecondaryKickTracker) == "function" then
    FI.InitializeFactorySecondaryKickTracker(
      ctx,
      modules,
      getTime,
      getUnitName,
      getRealmName,
      IsMainFrameShown,
      IsRaidModeActive
    )
  end
end
FI.InitializeFactorySecondaryControllers = InitializeFactorySecondaryControllers
