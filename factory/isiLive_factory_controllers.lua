local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

-- Sub-function: Game API safe wrappers and instance helpers.
local function InitializeGameAPIHelpers(ctx, runtimeState)
  ctx.GetActiveChallengeMapID = function()
    if not (C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID) then
      return nil
    end
    local ok, mapID = pcall(C_ChallengeMode.GetActiveChallengeMapID)
    if not ok then
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
    local _, instanceType = GetInstanceInfo()
    return instanceType == "party"
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
    if ctx.GetActiveChallengeMapID() then
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
        return
      end

      local capturedAt = nil
      if type(GetTime) == "function" then
        capturedAt = GetTime()
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

    local resolvedMapID = nil
    local resolvedLevel = nil
    local levelConflict = false

    for _, info in pairs(ctx.GetRoster() or {}) do
      if type(info) == "table" then
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

    local targetLevel = nil
    local ownerUnit = ctx.ResolveActiveKeyOwnerUnit and ctx.ResolveActiveKeyOwnerUnit() or nil
    if ownerUnit and type(roster[ownerUnit]) == "table" then
      targetLevel = tonumber(roster[ownerUnit].keyLevel)
    end

    if not targetLevel or targetLevel <= 0 then
      local syncedTargetInfo = ctx.ResolveSyncedTargetInfo and ctx.ResolveSyncedTargetInfo() or nil
      if type(syncedTargetInfo) == "table" and tonumber(syncedTargetInfo.mapID) == tonumber(targetMapID) then
        targetLevel = tonumber(syncedTargetInfo.level)
      end
    end

    if targetLevel and targetLevel <= 0 then
      targetLevel = nil
    end

    return {
      name = targetName,
      level = targetLevel,
    }
  end
  ctx.SendOwnTargetSnapshot = function(force, source, allowHidden)
    if not modules.sync or type(modules.sync.SendTarget) ~= "function" then
      return
    end

    local isVisible = ctx.mainFrame and ctx.mainFrame:IsShown() or false
    local targetMapID = ctx.ResolveLocalStatusTargetMapID()
    local targetLevel = nil
    if
      targetMapID
      and ctx.keySyncController
      and type(ctx.keySyncController.ResolveActiveKeyOwnerUnit) == "function"
    then
      local ownerUnit = ctx.keySyncController.ResolveActiveKeyOwnerUnit(ctx.GetRoster(), targetMapID)
      local roster = ctx.GetRoster()
      if ownerUnit and type(roster[ownerUnit]) == "table" then
        targetLevel = tonumber(roster[ownerUnit].keyLevel)
      end
    end

    modules.sync.SendTarget({
      force = force and true or false,
      isVisible = isVisible,
      allowHidden = (allowHidden and true or false) or not isVisible,
      mapID = targetMapID,
      level = targetLevel,
      source = source,
    })
  end
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
end
FI.InitializeFactoryRuntimeHelpers = InitializeFactoryRuntimeHelpers

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
    hasFullSync = modules.roster.HasFullSync,
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
    getTime = GetTime,
    shareKeysDebounceSeconds = 30,
    sendShareKeysRequest = function()
      modules.sync.SendShareKeysRequest()
    end,
    isSyncUserKnown = function(name, realm)
      return modules.sync.IsUserKnown(name, realm)
    end,
  })

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
    if not localTargetMapID then
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

    return ctx.keySyncController.ResolveActiveKeyOwnerUnit(ctx.GetRoster(), targetMapID)
  end
  ctx.UpdateMPlusTeleportButton = function(soundContext)
    local resolvedSpellID = ctx.ResolveActiveTeleportSpellID()
    if not resolvedSpellID then
      local lfgDetect = addonTable.LFGDetect
      local detectedMapID = type(lfgDetect) == "table"
          and type(lfgDetect.GetDetectedMapID) == "function"
          and lfgDetect.GetDetectedMapID()
        or nil
      if detectedMapID then
        resolvedSpellID = modules.teleport.ResolveTeleportSpellIDByMapID(detectedMapID)
      end
    end
    ctx.teleportUIController.UpdateButtons(resolvedSpellID, soundContext)
  end

  -- ARCH-1 fix: inject UpdateMPlusTeleportButton into LFGDetect so the game-layer
  -- module no longer needs to reach into _factoryCtx directly.
  -- MINOR-1 fix: inject locale getter so chat messages follow the player's locale.
  local lfgDetect = addonTable.LFGDetect
  if type(lfgDetect) == "table" then
    if type(lfgDetect.SetHighlightCallback) == "function" then
      lfgDetect.SetHighlightCallback(ctx.UpdateMPlusTeleportButton)
    end
    if type(lfgDetect.SetLocaleGetter) == "function" then
      lfgDetect.SetLocaleGetter(ctx.GetL)
    end
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
    getTime = GetTime,
    refreshDebounceSeconds = 10,
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
    local now = GetTime and GetTime() or 0
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
    local now = GetTime and GetTime() or 0
    if now < resyncCooldownEnd then
      return
    end
    ctx.refreshController.RunFullRefresh()
    resyncCooldownEnd = now + RESYNC_COOLDOWN
    if resyncTicker then
      resyncTicker:Cancel()
    end
    resyncTicker = C_Timer.NewTicker(1.0, UpdateResyncButton, RESYNC_COOLDOWN)
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
      if ctx.cdTrackerController and type(ctx.cdTrackerController.ClearDemoData) == "function" then
        ctx.cdTrackerController.ClearDemoData()
      end
      if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshCdTracker) == "function" then
        ctx.rosterPanelController.RefreshCdTracker()
      end
    end,
    updateMPlusTeleportButton = ctx.UpdateMPlusTeleportButton,
    setCenterNoticeVisible = ctx.SetCenterNoticeVisible,
    hideInviteHint = function()
      ctx.inviteHint.frame:Hide()
    end,
    triggerGroupRosterUpdate = ctx.TriggerGroupRosterUpdate,
  }))

  ctx.EnterFullDummyPreview = function()
    ctx.testModeController.EnterFullDummyPreview()
  end
  ctx.ExitTestMode = function()
    ctx.testModeController.ExitTestMode()
  end
  ctx.ToggleStandardTestMode = function()
    ctx.testModeController.ToggleStandardTestMode()
  end
  ctx.ToggleDemoMode = function()
    local wasTestMode = runtimeState.IsTestMode() or runtimeState.IsTestAllMode()
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
    local targetMapID = ctx.ResolveStatusTargetMapID()
    if not targetMapID then
      return
    end

    local currentMapID = nil
    if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
      local challengeMapID = C_ChallengeMode.GetActiveChallengeMapID()
      if type(challengeMapID) == "number" and challengeMapID > 0 then
        currentMapID = challengeMapID
      end
    end
    if
      not currentMapID
      and C_Map
      and C_Map.GetBestMapForUnit
      and type(UnitExists) == "function"
      and UnitExists("player")
    then
      local mapID = C_Map.GetBestMapForUnit("player")
      if type(mapID) == "number" and mapID > 0 then
        currentMapID = mapID
      end
    end
    if not currentMapID then
      return
    end

    if targetMapID and currentMapID == targetMapID then
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
  ctx.UpdateCdTracker = function()
    if IsRaidModeActive() then
      return
    end
    ctx.cdTrackerController.Scan()
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
  -- Ticker: scan + UI refresh every second for countdown timers (BL remaining time).
  local C_Timer_ref = rawget(_G, "C_Timer")
  if type(C_Timer_ref) == "table" and type(C_Timer_ref.NewTicker) == "function" then
    C_Timer_ref.NewTicker(1.0, function()
      if not IsMainFrameShown() then
        return
      end
      ctx.UpdateCdTracker()
    end)
  end
end

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

  local function ClearOwnKickSyncCache()
    if not (modules.sync and type(modules.sync.ClearPlayerKickInfo) == "function") then
      return false
    end
    local selfName = getUnitName and getUnitName("player") or nil
    local selfRealm = getRealmName and getRealmName() or nil
    if not selfName or selfName == "" then
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
      if selfName and selfName ~= "" then
        modules.sync.SetPlayerKickInfo(selfName, selfRealm, info.onCooldown, info.cooldownRemain, nil, hasKick)
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
      and (force == true or info.onCooldown or now < kickReadyBroadcastUntil or heartbeatDue)
    then
      modules.sync.SendKick({
        hasKick = hasKick,
        onCooldown = info.onCooldown,
        cooldownRemain = info.cooldownRemain,
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

  -- Event frame: UNIT_SPELLCAST_SUCCEEDED for player/pet is untainted.
  local castFrame = CreateFrame("Frame")
  castFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
  castFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  castFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  castFrame:RegisterEvent("SPELLS_CHANGED")
  castFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  castFrame:RegisterUnitEvent("UNIT_PET", "player")
  castFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if IsRaidModeActive() then
      EnterRaidKickSuppression()
      return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      if ctx.kickTrackerController then
        local observedKick = ctx.kickTrackerController.OnCast(unit, spellID) == true
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
  end)

  -- Ticker: scan own kick state + refresh kick column every 0.5s.
  local C_Timer_ref = rawget(_G, "C_Timer")
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

local function InitializeFactorySecondaryControllers(ctx)
  local modules = ctx.modules
  local runtimeState = ctx.runtimeState
  local getTime = GetTime
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
  InitializeFactorySecondaryKickTracker(
    ctx,
    modules,
    getTime,
    getUnitName,
    getRealmName,
    IsMainFrameShown,
    IsRaidModeActive
  )
end
FI.InitializeFactorySecondaryControllers = InitializeFactorySecondaryControllers

local function CreateFactoryMinimapButton(ctx)
  local Minimap = rawget(_G, "Minimap")
  if not Minimap then
    return nil
  end

  local btn = CreateFrame("Button", "isiLiveMinimapButton", Minimap)
  btn:SetSize(28, 28)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)

  local overlay = btn:CreateTexture(nil, "OVERLAY")
  overlay:SetSize(53, 53)
  overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  overlay:SetPoint("TOPLEFT")

  local bg = btn:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("TOPLEFT", 7, -5)

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetTexture("Interface\\Icons\\inv_misc_key_15")
  icon:SetPoint("TOPLEFT", 7, -6)

  local db = IsiLiveDB or {}
  local minimapAngle = type(db.minimapAngle) == "number" and db.minimapAngle or 225
  local radius = 80
  local getCursorPosition = rawget(_G, "GetCursorPosition")

  local function UpdatePosition()
    local rad = math.rad(minimapAngle)
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
  end

  UpdatePosition()

  local isDragging = false
  btn:RegisterForDrag("LeftButton")
  btn:SetScript("OnDragStart", function()
    isDragging = true
  end)
  btn:SetScript("OnDragStop", function()
    if type(getCursorPosition) ~= "function" then
      isDragging = false
      return
    end
    isDragging = false
    local mx, my = Minimap:GetCenter()
    local cx, cy = getCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    if IsiLiveDB then
      IsiLiveDB.minimapAngle = minimapAngle
    end
    UpdatePosition()
  end)
  btn:SetScript("OnUpdate", function()
    if isDragging and type(getCursorPosition) == "function" then
      local mx, my = Minimap:GetCenter()
      local cx, cy = getCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      cx, cy = cx / scale, cy / scale
      minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
      UpdatePosition()
    end
  end)

  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      local blizzardSettings = rawget(_G, "Settings")
      if type(blizzardSettings) == "table" and type(blizzardSettings.OpenToCategory) == "function" then
        if ctx.settingsPanel and ctx.settingsPanel.category then
          blizzardSettings.OpenToCategory(ctx.settingsPanel.category.ID)
        end
      end
    elseif ctx.ToggleMainFrameVisibility then
      ctx.ToggleMainFrameVisibility()
    end
  end)
  btn:SetScript("OnEnter", function(self)
    local GameTooltip = rawget(_G, "GameTooltip")
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:AddLine("isiLive")
      GameTooltip:AddLine("Left-click to toggle window", 0.8, 0.8, 0.8)
      GameTooltip:AddLine("Right-click to open settings", 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end
  end)
  btn:SetScript("OnLeave", function()
    local GameTooltip = rawget(_G, "GameTooltip")
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)

  -- Apply visibility on PLAYER_LOGIN when SavedVariables are available.
  -- Mimics LibDBIcon pattern: register once, then show/hide based on db setting.
  local loginFrame = CreateFrame("Frame")
  loginFrame:RegisterEvent("PLAYER_LOGIN")
  loginFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    local savedDb = rawget(_G, "IsiLiveDB")
    if savedDb and savedDb.showMinimapButton then
      btn:Show()
    else
      btn:Hide()
    end
  end)

  return btn
end
FI.CreateFactoryMinimapButton = CreateFactoryMinimapButton
