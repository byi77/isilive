local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

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

local function InitializeQueueOperationalHelpers(ctx, modules, runtimeState)
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
end

-- Status target resolution and sync helpers. Queue/inspect operational setup
-- lives in the bounded initializer above so this composition step stays below
-- the architecture function-size ceiling.
local function InitializeStatusAndOperationalHelpers(ctx, modules, runtimeState)
  InitializeQueueOperationalHelpers(ctx, modules, runtimeState)
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
    -- explicit target announcement counts for this branch. Leadership is not
    -- proof of key ownership; if the leader has no verified target payload, we
    -- fail closed instead of using a conflicting member broadcast.
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
    local _, _, _, latestQueueMapID = runtimeState.GetLatestQueueState()
    local roster = ctx.GetRoster()

    local numericTargetMapID = tonumber(targetMapID)
    local latestQueueMatchesTarget = false
    local numericLatestQueueMapID = tonumber(latestQueueMapID)
    if numericTargetMapID and numericLatestQueueMapID and numericLatestQueueMapID == numericTargetMapID then
      latestQueueMatchesTarget = true
    elseif numericTargetMapID and latestQueueActivityID then
      local resolvedActivityMapID = tonumber(ctx.ResolveMapIDByActivityID(latestQueueActivityID))
      latestQueueMatchesTarget = resolvedActivityMapID and resolvedActivityMapID == numericTargetMapID or false
    end

    local targetName = nil
    if latestQueueMatchesTarget then
      targetName = ctx.NormalizeConcreteStatusTargetName(latestQueueDungeonName, targetMapID)
    end
    if not targetName and targetMapID and modules.teleport and modules.teleport.GetTeleportInfoByMapID then
      local info = modules.teleport.GetTeleportInfoByMapID(targetMapID)
      if type(info) == "table" then
        targetName = ctx.NormalizeConcreteStatusTargetName(info.mapName, targetMapID)
      end
    end
    if
      not targetName
      and latestQueueMatchesTarget
      and latestQueueActivityID
      and modules.queue
      and modules.queue.GetActivityName
    then
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

FI.InitializeStatusAndOperationalHelpers = InitializeStatusAndOperationalHelpers

return {
  InitializeStatusAndOperationalHelpers = InitializeStatusAndOperationalHelpers,
}
