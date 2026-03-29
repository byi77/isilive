local _, moduleAddonTable = ...
moduleAddonTable = moduleAddonTable or {}

local FI = moduleAddonTable._FactoryInternal or {}
moduleAddonTable._FactoryInternal = FI

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
local function InitializeStatusAndOperationalHelpers(ctx, modules, runtimeState, addonTable)
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
    local normalized = moduleAddonTable.StringUtils.Trim(value)
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
      isVisible = ctx.mainFrame and ctx.mainFrame:IsShown() or false,
      allowHidden = allowHidden and true or false,
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
  local addonTable = ctx.addonTable

  InitializeGameAPIHelpers(ctx, runtimeState)
  InitializeRuntimeStateDelegates(ctx, modules, runtimeState)
  InitializeRioHelpers(ctx, runtimeState)
  InitializeStatusAndOperationalHelpers(ctx, modules, runtimeState, addonTable)
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
      return not ctx.runtimeState.IsStopped() and not ctx.runtimeState.IsPaused() and not ctx.GetActiveChallengeMapID()
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
  ctx.SwitchToRaidMode = function()
    if ctx.rosterPanelController then
      ctx.rosterPanelController.SwitchToRaidMode()
    end
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
  ctx.UpdateMPlusTeleportButton = function()
    local resolvedSpellID = ctx.ResolveActiveTeleportSpellID()
    ctx.teleportUIController.UpdateButtons(resolvedSpellID)
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
    ctx.SendOwnTargetSnapshot(false, "status")
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

local function InitializeFactorySecondaryControllers(ctx)
  local modules = ctx.modules
  local runtimeState = ctx.runtimeState

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

  ctx.bindingController = modules.bindings.CreateController({
    onToggleMainFrame = ctx.ToggleMainFrameVisibility,
    onToggleTestMode = ctx.ToggleStandardTestMode,
  })
  ctx.ApplyHotkeyBindings()

  ctx.SetLanguage = function(tag)
    local resolved = modules.locale.ResolveLocaleTag(tag)
    ctx.L = ctx.locales[resolved] or ctx.locales.enUS
    if IsiLiveDB then
      IsiLiveDB.locale = resolved
    end
    ctx.ApplyLocalizationToUI()
    ctx.Print(resolved == "deDE" and ctx.L.LANG_SET_DE or ctx.L.LANG_SET_EN)
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
    if not currentMapID and C_Map and C_Map.GetBestMapForUnit then
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

  if modules.cdTracker and type(modules.cdTracker.CreateController) == "function" then
    ctx.cdTrackerController = modules.cdTracker.CreateController({
      getTime = GetTime,
    })
    ctx.UpdateCdTracker = function()
      ctx.cdTrackerController.Scan()
      if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshCdTracker) == "function" then
        ctx.rosterPanelController.RefreshCdTracker()
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
        ctx.UpdateCdTracker()
      end)
    end
  end

  local kickTrackerModule = ctx.addonTable and ctx.addonTable.KickTracker
  if kickTrackerModule and type(kickTrackerModule.CreateController) == "function" then
    local kickReadyBroadcastUntil = 0
    ctx.kickTrackerController = kickTrackerModule.CreateController({
      getTime = GetTime,
      onCooldownChanged = function(onCooldown, cooldownRemain)
        if modules.sync and type(modules.sync.SendKick) == "function" then
          modules.sync.SendKick({
            onCooldown = onCooldown,
            cooldownRemain = cooldownRemain,
            force = true,
          })
        end
        -- When transitioning to ready, keep broadcasting for 3s to ensure delivery.
        if not onCooldown then
          kickReadyBroadcastUntil = GetTime() + 3
        end
        if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshKickColumn) == "function" then
          ctx.rosterPanelController.RefreshKickColumn()
        end
      end,
    })
    -- Event frame: UNIT_SPELLCAST_SUCCEEDED for player is untainted.
    local castFrame = CreateFrame("Frame")
    castFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    castFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    castFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    castFrame:RegisterEvent("SPELLS_CHANGED")
    castFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    castFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
      if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit ~= "player" then
          return
        end
        if ctx.kickTrackerController then
          ctx.kickTrackerController.OnPlayerCast(spellID)
        end
      elseif event == "SPELL_UPDATE_COOLDOWN" or event == "PLAYER_REGEN_ENABLED" then
        -- Cache real CD outside of combat (talent reductions).
        if ctx.kickTrackerController then
          ctx.kickTrackerController.CacheCooldown()
        end
      elseif event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        if ctx.kickTrackerController then
          ctx.kickTrackerController.ResolveSpellID()
        end
      end
    end)

    -- Ticker: scan own kick state + refresh kick column every 0.5s.
    local C_Timer_ref = rawget(_G, "C_Timer")
    if type(C_Timer_ref) == "table" and type(C_Timer_ref.NewTicker) == "function" then
      C_Timer_ref.NewTicker(0.5, function()
        if ctx.kickTrackerController then
          ctx.kickTrackerController.Scan()
          if modules.sync and type(modules.sync.SetPlayerKickInfo) == "function" then
            local selfName = UnitName and UnitName("player") or nil
            local selfRealm = GetRealmName and GetRealmName() or nil
            if selfName and selfName ~= "" then
              local info = ctx.kickTrackerController.GetKickInfo()
              modules.sync.SetPlayerKickInfo(selfName, selfRealm, info.onCooldown, info.cooldownRemain)
              -- Broadcast kick state to group members every tick while on CD,
              -- and for 3s after transitioning to ready (ensures delivery).
              local now = GetTime()
              if (info.onCooldown or now < kickReadyBroadcastUntil) and type(modules.sync.SendKick) == "function" then
                modules.sync.SendKick({ onCooldown = info.onCooldown, cooldownRemain = info.cooldownRemain })
              end
            end
          end
        end
        -- Refresh only the kick column in the roster (lightweight, no full re-render).
        if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshKickColumn) == "function" then
          ctx.rosterPanelController.RefreshKickColumn()
        end
      end)
    end
  end
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

  btn:SetScript("OnClick", function()
    if ctx.ToggleMainFrameVisibility then
      ctx.ToggleMainFrameVisibility()
    end
  end)
  btn:SetScript("OnEnter", function(self)
    local GameTooltip = rawget(_G, "GameTooltip")
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:AddLine("isiLive")
      GameTooltip:AddLine("Click to toggle window", 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end
  end)
  btn:SetScript("OnLeave", function()
    local GameTooltip = rawget(_G, "GameTooltip")
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)

  return btn
end
FI.CreateFactoryMinimapButton = CreateFactoryMinimapButton
