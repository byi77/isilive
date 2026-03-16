local _, moduleAddonTable = ...
moduleAddonTable = moduleAddonTable or {}

local Factory = {}
moduleAddonTable.Factory = Factory

local function BuildFactoryModules(addonTable)
  return {
    sync = addonTable and addonTable.Sync,
    keySync = addonTable and addonTable.KeySync,
    refresh = addonTable and addonTable.Refresh,
    highlight = addonTable and addonTable.Highlight,
    group = addonTable and addonTable.Group,
    queue = addonTable and addonTable.Queue,
    queueFlow = addonTable and addonTable.QueueFlow,
    inspect = addonTable and addonTable.Inspect,
    roster = addonTable and addonTable.Roster,
    events = addonTable and addonTable.Events,
    eventHandlers = addonTable and addonTable.EventHandlers,
    commands = addonTable and addonTable.Commands,
    locale = addonTable and addonTable.Locale,
    texts = addonTable and addonTable.Texts,
    ui = addonTable and addonTable.UI,
    teleport = addonTable and addonTable.Teleport,
    teleportUI = addonTable and addonTable.TeleportUI,
    teleportDebug = addonTable and addonTable.TeleportDebug,
    notice = addonTable and addonTable.Notice,
    status = addonTable and addonTable.Status,
    units = addonTable and addonTable.Units,
    demo = addonTable and addonTable.Demo,
    testMode = addonTable and addonTable.TestMode,
    queueDebug = addonTable and addonTable.QueueDebug,
    runtimeLog = addonTable and addonTable.RuntimeLog,
    rosterPanel = addonTable and addonTable.RosterPanel,
    spellUtils = addonTable and addonTable.SpellUtils,
    bindings = addonTable and addonTable.Bindings,
    eventUtils = addonTable and addonTable.EventUtils,
    bootstrap = addonTable and addonTable.Bootstrap,
    controllerWiring = addonTable and addonTable.ControllerWiring,
    leaderWatch = addonTable and addonTable.LeaderWatch,
    configBuilders = addonTable and addonTable.ConfigBuilders,
    frameBridge = addonTable and addonTable.FrameBridge,
    contextHelpers = addonTable and addonTable.ContextHelpers,
    runtimeSetup = addonTable and addonTable.RuntimeSetup,
    controllerInit = addonTable and addonTable.ControllerInit,
    guards = addonTable and addonTable.Guards,
    stats = addonTable and addonTable.Stats,
    runtimeState = addonTable and addonTable.RuntimeState,
    settingsPanel = addonTable and addonTable.SettingsPanel,
  }
end

local function CreateFactoryContext(addonName, addonTable)
  local modules = BuildFactoryModules(addonTable)
  local isiLiveRuntimeState = modules.runtimeState
  local ctx = {
    addonName = addonName,
    addonTable = addonTable,
    modules = modules,
    INSPECT_TIMEOUT = 2,
    RETRY_INTERVAL = 5,
    INSPECT_DELAY = 1,
    MIN_FRAME_HEIGHT = 236,
    locale = GetLocale(),
  }

  ctx.GetL = function()
    return ctx.L
  end

  ctx.Print = function(msg)
    local text = tostring(msg or "")
    print("isiLive: " .. text)
    if ctx.runtimeLogController and ctx.runtimeLogController.Log then
      ctx.runtimeLogController.Log(text)
    end
  end

  if not (modules.guards and type(modules.guards.Validate) == "function") then
    print("|cffff0000isiLive: missing module Guards (isiLive_guards.lua)|r")
    return nil
  end

  local guardsOk, guardsErr = pcall(modules.guards.Validate, addonTable)
  if not guardsOk then
    print("|cffff0000isiLive: " .. tostring(guardsErr) .. "|r")
    return nil
  end

  ctx.locales = modules.texts.GetLocaleTables()
  ctx.L = ctx.locales.enUS
  ctx.GetAddonVersionRaw = function()
    return modules.contextHelpers.GetAddonVersionRaw(addonName)
  end

  ctx.runtimeLogController = modules.runtimeLog.CreateController({
    maxEntries = 800,
  })

  ctx.queueDebugController = modules.queueDebug.CreateController({
    printFn = ctx.Print,
    queueSetDebugEnabled = function(enabled)
      if modules.queue and modules.queue.SetDebugEnabled then
        modules.queue.SetDebugEnabled(enabled)
      end
    end,
    queueIsDebugEnabled = function()
      if modules.queue and modules.queue.IsDebugEnabled then
        return modules.queue.IsDebugEnabled() == true
      end
      return nil
    end,
    maxEntries = 400,
  })

  if modules.queue and modules.queue.SetDebugLogger then
    modules.queue.SetDebugLogger(ctx.queueDebugController.Log)
  end

  local runtimeState = isiLiveRuntimeState.CreateController()
  ctx.runtimeState = runtimeState
  ctx.GetSpellCooldownSafe = modules.spellUtils.GetSpellCooldownSafe
  ctx.ApplyCooldownFrameSafe = modules.spellUtils.ApplyCooldownFrameSafe
  ctx.IsSpellKnownSafe = modules.spellUtils.IsSpellKnownSafe
  ctx.GetTeleportCooldownRemaining = modules.spellUtils.GetTeleportCooldownRemaining
  ctx.FormatCooldownSeconds = modules.spellUtils.FormatCooldownSeconds
  ctx.IsNegativeApplicationStatusEvent = modules.eventUtils.IsNegativeApplicationStatusEvent
  ctx.IsPlayerLeader = function()
    if ctx.runtimeState.IsTestAllMode() then
      return true
    end
    return IsInGroup() and UnitIsGroupLeader("player")
  end

  ctx.GetRealmInfoLib = modules.contextHelpers.CreateRealmInfoGetter()
  ctx.GetUnitRole = modules.units.GetUnitRole
  ctx.TruncateName = modules.units.TruncateName
  ctx.GetUnitNameAndRealm = modules.units.GetUnitNameAndRealm
  ctx.GetPlayerSpecName = modules.units.GetPlayerSpecName
  ctx.GetInspectSpecName = modules.units.GetInspectSpecName
  ctx.GetShortSpecLabel = modules.units.GetShortSpecLabel
  ctx.GetUnitRio = modules.units.GetUnitRio

  ctx.BuildDummyRoster = function(opts)
    opts = opts or {}
    return modules.contextHelpers.BuildDummyRoster({
      demoBuildDummyRoster = modules.demo.BuildDummyRoster,
      previewVariant = opts.previewVariant,
      includeGhostMember = opts.includeGhostMember,
      getUnitNameAndRealm = ctx.GetUnitNameAndRealm,
      getUnitServerLanguage = function(unit, realm)
        return modules.contextHelpers.GetUnitServerLanguage(modules.locale, ctx.GetRealmInfoLib, unit, realm)
      end,
      getUnitRole = ctx.GetUnitRole,
      getPlayerSpecName = ctx.GetPlayerSpecName,
      getUnitRio = ctx.GetUnitRio,
    })
  end

  return ctx
end

local function InitializeFactoryFrameBridge(ctx)
  local modules = ctx.modules

  ctx.ApplyHotkeyBindings = function()
    if ctx.bindingController then
      ctx.bindingController.ApplyHotkeyBindings()
    end
  end

  ctx.StartBindingWatchdog = function()
    if ctx.bindingController then
      ctx.bindingController.StartBindingWatchdog()
    end
  end

  ctx.EnsureSoloPlayerRoster = function()
    if IsInGroup() then
      return
    end

    local name, realm = ctx.GetUnitNameAndRealm("player")
    if type(name) ~= "string" or name == "" then
      return
    end

    local _, class = UnitClass("player")
    local language = modules.contextHelpers.GetUnitServerLanguage(modules.locale, ctx.GetRealmInfoLib, "player", realm)
    local keyMapID, keyLevel
    if type(ctx.GetOwnedKeystoneSnapshot) == "function" then
      keyMapID, keyLevel = ctx.GetOwnedKeystoneSnapshot()
    end

    ctx.runtimeState.SetRoster({
      player = {
        name = name,
        realm = realm,
        language = language,
        class = class,
        role = ctx.GetUnitRole("player"),
        spec = ctx.GetPlayerSpecName(),
        ilvl = nil,
        rio = ctx.GetUnitRio("player"),
        hasIsiLive = true,
        keyMapID = keyMapID,
        keyLevel = keyLevel,
      },
    })
  end

  ctx.ResolveTeleportSpellIDByActivityID = modules.teleport.ResolveTeleportSpellIDByActivityID
  ctx.ResolveMapIDByActivityID = modules.teleport.ResolveMapIDByActivityID
  ctx.ResolveTeleportSpellID = modules.teleport.ResolveTeleportSpellID
  ctx.ApplySecureSpellToButton = modules.teleport.ApplySecureSpellToButton
  ctx.IsInCombat = function()
    return InCombatLockdown and InCombatLockdown()
  end

  local frameBridgeContext = modules.frameBridge.CreateContext({
    createCenterNotice = modules.notice.CreateCenterNotice,
    createInviteHint = modules.notice.CreateInviteHint,
    createMainFrame = modules.ui.CreateMainFrame,
    parent = UIParent,
    mainFrameGlobalName = "isiLiveMainFrame",
    mainFrameMinHeight = ctx.MIN_FRAME_HEIGHT,
    isInGroup = IsInGroup,
    isInCombat = ctx.IsInCombat,
    onShownInGroup = function()
      local onEventHandler = ctx.mainFrame and ctx.mainFrame:GetScript("OnEvent")
      if onEventHandler then
        onEventHandler(ctx.mainFrame, "GROUP_ROSTER_UPDATE")
      end
    end,
    onShownNoGroup = function()
      ctx.EnsureSoloPlayerRoster()
      ctx.UpdateUI()
      ctx.UpdateLeaderButtons()
    end,
    resolveTeleportSpellID = ctx.ResolveTeleportSpellID,
    applySecureSpellToButton = ctx.ApplySecureSpellToButton,
    isSpellKnown = ctx.IsSpellKnownSafe,
    getTeleportCooldownRemaining = ctx.GetTeleportCooldownRemaining,
    formatCooldownSeconds = ctx.FormatCooldownSeconds,
    getL = ctx.GetL,
  })

  ctx.centerNotice = frameBridgeContext.centerNotice
  ctx.centerNoticeFrame = frameBridgeContext.centerNoticeFrame
  ctx.centerNoticeTeleportButton = frameBridgeContext.centerNoticeTeleportButton
  ctx.inviteHint = frameBridgeContext.inviteHint
  ctx.mainUI = frameBridgeContext.mainUI
  ctx.mainFrame = frameBridgeContext.mainFrame
  ctx.SetCenterNoticeVisible = function(visible)
    frameBridgeContext.SetCenterNoticeVisible(visible)
  end
  ctx.UpdateCenterTeleportButtonVisual = function(spellID, isEnabled, inCombatBlocked)
    frameBridgeContext.UpdateCenterTeleportButtonVisual(spellID, isEnabled, inCombatBlocked)
  end
  ctx.ShowCenterNotice = function(message, durationSeconds, dungeonName, activityID, showOptions)
    frameBridgeContext.ShowCenterNotice(message, durationSeconds, dungeonName, activityID, showOptions)
  end
  ctx.ShowInviteHint = function(message, durationSeconds)
    frameBridgeContext.ShowInviteHint(message, durationSeconds)
  end
  ctx.SetMainFrameVisible = function(visible)
    if visible then
      -- Respect autoOpenOnQueue setting (default: true)
      local dbRef = rawget(_G, "IsiLiveDB")
      if dbRef and dbRef.autoOpenOnQueue == false then
        return
      end
    end
    frameBridgeContext.SetMainFrameVisible(visible)
  end
  ctx.SetMainFrameHeightSafe = function(height)
    frameBridgeContext.SetMainFrameHeightSafe(height)
  end
  ctx.ToggleMainFrameVisibility = function()
    frameBridgeContext.ToggleMainFrameVisibility()
  end
  ctx.inspectLoopTimer = 0
end

local function InitializeFactoryRuntimeHelpers(ctx)
  local modules = ctx.modules
  local runtimeState = ctx.runtimeState
  local addonTable = ctx.addonTable

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
  ctx.IsInPartyInstance = function()
    if type(GetInstanceInfo) ~= "function" then
      return false
    end
    local _, instanceType = GetInstanceInfo()
    return instanceType == "party"
  end
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
    if modules.sync and type(modules.sync.NormalizePlayerKey) == "function" then
      return modules.sync.NormalizePlayerKey(name, realm)
    end

    local normalizedName = name and tostring(name) or ""
    local normalizedRealm = realm and tostring(realm) or ""
    if normalizedRealm == "" then
      normalizedRealm = GetRealmName() or ""
    end
    return string.lower(normalizedName .. "-" .. normalizedRealm)
  end
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
  ctx.RefreshLocalPlayerKey = function()
    return ctx.keySyncController.RefreshLocalPlayerKey(ctx.GetRoster())
  end
  ctx.NormalizeStatusTargetName = function(value)
    if type(value) ~= "string" then
      return nil
    end
    local normalized = value:gsub("^%s+", ""):gsub("%s+$", "")
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
  ctx.ResolveStatusTargetMapID = function()
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

    if (not targetLevel or targetLevel <= 0) and targetMapID and type(roster.player) == "table" then
      local playerInfo = roster.player
      if tonumber(playerInfo.keyMapID) == targetMapID then
        targetLevel = tonumber(playerInfo.keyLevel)
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

    local activeLocale = (IsiLiveDB and IsiLiveDB.locale) or ctx.locale
    return seasonData.GetInactivePortalMessage(activeLocale)
  end
end

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
    minFrameHeight = ctx.MIN_FRAME_HEIGHT,
    buildOrderedRoster = modules.roster.BuildOrderedRoster,
    hasFullSync = modules.roster.HasFullSync,
    buildDisplayData = modules.roster.BuildDisplayData,
    truncateName = function(name, maxChars)
      return ctx.TruncateName(name, maxChars)
    end,
    getShortSpecLabel = ctx.GetShortSpecLabel,
    getLanguageFlagMarkup = modules.locale.GetLanguageFlagMarkup,
    getDungeonShortCode = function(mapID)
      local activeLocale = (IsiLiveDB and IsiLiveDB.locale) or ctx.locale
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
    getTime = GetTime,
    shareKeysDebounceSeconds = 1,
  })

  ctx.keySyncController = initResult.keySyncController
  ctx.MarkIsiLiveUser = initResult.markIsiLiveUser
  ctx.UnitHasIsiLive = initResult.unitHasIsiLive
  ctx.RegisterIsiLiveSyncPrefix = initResult.registerIsiLiveSyncPrefix
  ctx.SendIsiLiveHello = initResult.sendIsiLiveHello
  ctx.SendRefreshRequest = initResult.sendRefreshRequest
  ctx.GetOwnedKeystoneSnapshot = initResult.getOwnedKeystoneSnapshot
  ctx.SendOwnKeySnapshot = initResult.sendOwnKeySnapshot
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
  ctx.GetNormalizedActiveEntryInfo = function()
    return ctx.highlightController.GetNormalizedActiveEntryInfo()
  end
  ctx.ResolveActiveTeleportSpellID = function()
    local _, latestQueueActivityID, _, latestQueueMapID = ctx.runtimeState.GetLatestQueueState()
    return ctx.highlightController.ResolveActiveTeleportSpellID(latestQueueActivityID, latestQueueMapID)
  end
  ctx.ResolveJoinedKeyMapID = function(activityID, spellID)
    return ctx.highlightController.ResolveJoinedKeyMapID(activityID, spellID)
  end
  ctx.ResolveActiveKeyOwnerUnit = function()
    return ctx.keySyncController.ResolveActiveKeyOwnerUnit(ctx.GetRoster(), ctx.runtimeState.GetActiveJoinedKeyMapID())
  end
  ctx.UpdateMPlusTeleportButton = function()
    local resolvedSpellID = ctx.ResolveActiveTeleportSpellID()
    ctx.teleportUIController.UpdateButtons(resolvedSpellID)
  end
end

local function InitializeFactorySecondaryControllers(ctx)
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
    showCenterNotice = ctx.ShowCenterNotice,
    hideCenterNotice = function()
      ctx.centerNotice.SetVisible(false)
    end,
    isPlayerLeader = ctx.IsPlayerLeader,
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
  })

  ctx.statusController = statusController
  ctx.UpdateStatusLine = function()
    local flags = runtimeState.GetRuntimeFlags()
    ctx.statusLine:SetText(statusController.BuildStatusLineText({
      isStopped = flags.isStopped,
      isPaused = flags.isPaused,
      isTestMode = flags.isTestMode,
    }))
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
    sendRefreshRequest = ctx.SendRefreshRequest,
    queueForceRefreshData = QueueForceRefreshData,
    updateUI = ctx.UpdateUI,
    refreshLocalPlayerKey = ctx.RefreshLocalPlayerKey,
    getActiveChallengeMapID = ctx.GetActiveChallengeMapID,
    getTime = GetTime,
    refreshDebounceSeconds = 1,
  }))

  ctx.refreshButton:SetScript("OnClick", function()
    ctx.refreshController.RunFullRefresh()
  end)

  ctx.GetUnitServerLanguage = function(unit, realm)
    return modules.contextHelpers.GetUnitServerLanguage(modules.locale, ctx.GetRealmInfoLib, unit, realm)
  end

  ctx.queueFlowController = modules.queueFlow.CreateController(modules.configBuilders.BuildQueueFlowControllerOpts({
    getL = ctx.GetL,
    getPendingQueueJoinInfo = function()
      return runtimeState.GetPendingQueueJoinInfo()
    end,
    setPendingQueueJoinInfo = function(value)
      runtimeState.SetPendingQueueJoinInfo(value)
    end,
    resolveMapIDByActivityID = ctx.ResolveMapIDByActivityID,
    resolveTeleportSpellIDByMapID = modules.teleport.ResolveTeleportSpellIDByMapID,
    resolveJoinedKeyMapID = ctx.ResolveJoinedKeyMapID,
    updateMPlusTeleportButton = ctx.UpdateMPlusTeleportButton,
    showInviteHint = ctx.ShowInviteHint,
    updateUI = ctx.UpdateUI,
    printFn = ctx.Print,
    setQueueTargetState = function(dungeonName, activityID, spellID, joinedKeyMapID, mapID)
      runtimeState.SetLatestQueueState(dungeonName, activityID, spellID, mapID)
      runtimeState.SetActiveJoinedKeyMapID(joinedKeyMapID)
      if ctx.UpdateStatusLine then
        ctx.UpdateStatusLine()
      end
    end,
    queueCaptureQueueJoinCandidate = modules.queue.CaptureQueueJoinCandidate,
    isInChallengeMode = ctx.GetActiveChallengeMapID,
    isInGroup = IsInGroup,
    isPlayerLeader = ctx.IsPlayerLeader,
    getTimeFn = GetTime,
  }))

  ctx.CaptureQueueJoinCandidate = function(...)
    ctx.queueFlowController.CaptureQueueJoinCandidate(...)
  end
  ctx.AnnounceQueuedGroupJoin = function()
    ctx.queueFlowController.AnnounceQueuedGroupJoin()
  end
  ctx.ShowQueueJoinPreview = function(groupName, dungeonName, activityID)
    ctx.queueFlowController.ShowQueueJoinPreview(groupName, dungeonName, activityID)
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
    showQueueJoinPreview = ctx.ShowQueueJoinPreview,
    resetInspectAll = ctx.ResetInspectAll,
    clearLatestQueueState = function()
      runtimeState.ClearLatestQueueTarget({ keepActiveJoinedKey = true })
    end,
    captureRioBaselineSnapshot = ctx.CaptureRioBaselineSnapshot,
    clearRioBaselineSnapshot = ctx.ClearRioBaselineSnapshot,
    enableRioDeltaDisplay = ctx.EnableRioDeltaDisplay,
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

  ctx.SetProcessingActive = SetProcessingActive
end

local function CreateFactoryMinimapButton(ctx)
  local Minimap = rawget(_G, "Minimap")
  if not Minimap then
    return nil
  end

  local btn = CreateFrame("Button", "isiKeyMPlusMinimapButton", Minimap)
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
      GameTooltip:AddLine("isiKeyMPlus")
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

local function FinalizeFactoryRuntime(ctx)
  local modules = ctx.modules
  local runtimeState = ctx.runtimeState
  local isiLiveRuntimeSetup = modules.runtimeSetup

  ctx.inspectController = modules.inspect.CreateController({
    inspectTimeout = ctx.INSPECT_TIMEOUT,
    retryInterval = ctx.RETRY_INTERVAL,
    inspectDelay = ctx.INSPECT_DELAY,
    sendOwnKeySnapshot = ctx.SendOwnKeySnapshot,
  })
  ctx.OnEvent = function(self, event, ...)
    ctx.eventHandlersController.Dispatch(self, event, ...)
  end
  ctx.InspectLoop = function(_self, elapsed)
    ctx.inspectLoopTimer = ctx.inspectLoopTimer + (elapsed or 0)
    if ctx.inspectLoopTimer >= 0.25 then
      ctx.inspectLoopTimer = 0
      if ctx.GetActiveChallengeMapID() then
        return
      end
      ctx.inspectController.OnUpdate()
    end
  end

  modules.bootstrap.RegisterMainFrameEvents(ctx.mainFrame)
  modules.bootstrap.BindMainFrameScripts(ctx.mainFrame, {
    onShow = function()
      ctx.SetProcessingActive(true)
      if ctx.rosterPanelController and ctx.rosterPanelController.RefreshSystemOptionToggles then
        ctx.rosterPanelController.RefreshSystemOptionToggles()
      end
      if IsInGroup() and ctx.SendOwnKeySnapshot then
        ctx.SendOwnKeySnapshot(true)
      end
    end,
    onHide = function()
      ctx.SetProcessingActive(false)
    end,
  })

  local runtimeSetupResult = isiLiveRuntimeSetup.Configure({
    controllerWiring = modules.controllerWiring,
    configBuilders = modules.configBuilders,
    bootstrap = modules.bootstrap,
    leaderWatchModule = modules.leaderWatch,
    groupModule = modules.group,
    eventHandlersModule = modules.eventHandlers,
    mainFrame = ctx.mainFrame,
    onEvent = ctx.OnEvent,
    onDispatchError = function(_frame, event, err)
      ctx.Print(string.format("Event dispatch failed (%s): %s", tostring(event), tostring(err)))
    end,
    sync = modules.sync,
    events = modules.events,
    commands = modules.commands,
    isInGroup = IsInGroup,
    getNumGroupMembers = GetNumGroupMembers,
    getActiveChallengeMapID = ctx.GetActiveChallengeMapID,
    getWasInGroup = ctx.GetWasInGroup,
    setWasInGroup = ctx.SetWasInGroup,
    getWasRaidGroup = ctx.GetWasRaidGroup,
    setWasRaidGroup = ctx.SetWasRaidGroup,
    isRosterCollapsed = ctx.IsRosterCollapsed,
    switchToRaidMode = ctx.SwitchToRaidMode,
    isRaidGroup = ctx.GetWasRaidGroup,
    setWasGroupLeader = ctx.SetWasGroupLeader,
    getWasGroupLeader = ctx.GetWasGroupLeader,
    getRoster = ctx.GetRoster,
    setRoster = ctx.SetRoster,
    captureQueueJoinCandidate = ctx.CaptureQueueJoinCandidate,
    announceQueuedGroupJoin = ctx.AnnounceQueuedGroupJoin,
    setMainFrameVisible = ctx.SetMainFrameVisible,
    setMainFrameHeightSafe = ctx.SetMainFrameHeightSafe,
    updateLeaderButtons = ctx.UpdateLeaderButtons,
    clearLatestQueueTarget = ctx.ClearLatestQueueTarget,
    clearRioBaselineSnapshot = ctx.ClearRioBaselineSnapshot,
    resetInspectAll = ctx.ResetInspectAll,
    resetInspectQueues = ctx.ResetInspectQueues,
    updateUI = ctx.UpdateUI,
    updateMPlusTeleportButton = ctx.UpdateMPlusTeleportButton,
    getUnitNameAndRealm = ctx.GetUnitNameAndRealm,
    getUnitClass = UnitClass,
    getUnitServerLanguage = ctx.GetUnitServerLanguage,
    getOwnedKeystoneSnapshot = ctx.GetOwnedKeystoneSnapshot,
    markIsiLiveUser = ctx.MarkIsiLiveUser,
    getUnitRole = ctx.GetUnitRole,
    getPlayerSpecName = ctx.GetPlayerSpecName,
    getUnitRio = ctx.GetUnitRio,
    getInspectSpecName = ctx.GetInspectSpecName,
    unitHasIsiLive = ctx.UnitHasIsiLive,
    applyKnownKeyToRosterEntry = ctx.ApplyKnownKeyToRosterEntry,
    enqueueInspect = ctx.EnqueueInspect,
    sendOwnKeySnapshot = ctx.SendOwnKeySnapshot,
    sendRefreshResponse = ctx.SendRefreshResponse,
    sendIsiLiveHello = ctx.SendIsiLiveHello,
    autoHideSolo = function()
      local dbRef = rawget(_G, "IsiLiveDB")
      if dbRef and dbRef.autoHideSolo and ctx.mainFrame and ctx.mainFrame:IsShown() then
        ctx.mainFrame:Hide()
      end
    end,
    canApplyRaidMarkers = function()
      return false
    end,
    unitIsGroupLeader = UnitIsGroupLeader,
    unitExists = UnitExists,
    getRaidTargetIndex = rawget(_G, "GetRaidTargetIndex"),
    setRaidTarget = rawget(_G, "SetRaidTarget"),
    isPlayerLeader = ctx.IsPlayerLeader,
    isStopped = runtimeState.IsStopped,
    isPaused = runtimeState.IsPaused,
    isTestMode = runtimeState.IsTestMode,
    isInCombat = ctx.IsInCombat,
    isInPartyInstance = ctx.IsInPartyInstance,
    isTestAllMode = runtimeState.IsTestAllMode,
    getL = ctx.GetL,
    printFn = ctx.Print,
    showCenterNotice = ctx.ShowCenterNotice,
    isMainFrameShown = function()
      return ctx.mainFrame and ctx.mainFrame:IsShown()
    end,
    defaultLocale = ctx.locale,
    locales = ctx.locales,
    resolveLocaleTag = modules.locale.ResolveLocaleTag,
    setLocaleTable = ctx.SetLocaleTable,
    isInChallengeMode = ctx.GetActiveChallengeMapID,
    isNegativeApplicationStatusEvent = ctx.IsNegativeApplicationStatusEvent,
    getNormalizedActiveEntryInfo = ctx.GetNormalizedActiveEntryInfo,
    ensureQueueDebugStorage = ctx.queueDebugController.EnsureStorage,
    setQueueDebugEnabled = ctx.queueDebugController.SetEnabled,
    ensureRuntimeLogStorage = ctx.runtimeLogController.EnsureStorage,
    setRuntimeLogEnabled = ctx.runtimeLogController.SetEnabled,
    registerIsiLiveSyncPrefix = ctx.RegisterIsiLiveSyncPrefix,
    applyHotkeyBindings = ctx.ApplyHotkeyBindings,
    startBindingWatchdog = ctx.StartBindingWatchdog,
    getAddonVersionRaw = ctx.GetAddonVersionRaw,
    getTime = GetTime,
    getPendingQueueJoinInfo = runtimeState.GetPendingQueueJoinInfo,
    setPendingQueueJoinInfo = runtimeState.SetPendingQueueJoinInfo,
    getActiveJoinedKeyMapID = runtimeState.GetActiveJoinedKeyMapID,
    setActiveJoinedKeyMapID = runtimeState.SetActiveJoinedKeyMapID,
    getPendingBindingApply = ctx.GetPendingBindingApply,
    mainUI = ctx.mainUI,
    centerNotice = ctx.centerNotice,
    centerNoticeFrame = ctx.centerNoticeFrame,
    centerNoticeTeleportButton = ctx.centerNoticeTeleportButton,
    applySecureSpellToButton = ctx.ApplySecureSpellToButton,
    refreshController = ctx.refreshController,
    inspectController = ctx.inspectController,
    statusController = ctx.statusController,
    exitTestMode = ctx.ExitTestMode,
    updateStatusLine = ctx.UpdateStatusLine,
    applyLocalizationToUI = ctx.ApplyLocalizationToUI,
    updateCountdownCancelButton = ctx.UpdateCountdownCancelButton,
    restoreLayoutState = ctx.RestoreLayoutState,
    checkIfEnteredTargetDungeon = ctx.CheckIfEnteredTargetDungeon,
    captureRioBaselineSnapshot = ctx.CaptureRioBaselineSnapshot,
    restoreRioBaseline = ctx.RestoreRioBaseline,
    isReadyCheckActive = ctx.IsReadyCheckActive,
    setReadyCheckActive = ctx.SetReadyCheckActive,
    enableRioDeltaDisplay = ctx.EnableRioDeltaDisplay,
    setCenterNoticeVisible = ctx.SetCenterNoticeVisible,
    getState = runtimeState.GetRuntimeFlags,
    setState = runtimeState.PatchRuntimeFlags,
    triggerGroupRosterUpdate = ctx.TriggerGroupRosterUpdate,
    toggleStandardTestMode = ctx.ToggleStandardTestMode,
    enterFullDummyPreview = ctx.EnterFullDummyPreview,
    setLanguage = ctx.SetLanguage,
    teleportDebugController = ctx.teleportDebugController,
    queueDebugController = ctx.queueDebugController,
    runtimeLogController = ctx.runtimeLogController,
    recordRun = ctx.RecordRun,
    addonName = ctx.addonName,
  })

  ctx.eventHandlersController = runtimeSetupResult.eventHandlersController
  ctx.Print(string.format(ctx.L.LOADED_HINT, ctx.GetAddonVersionRaw()))

  if modules.settingsPanel and type(modules.settingsPanel.Create) == "function" then
    ctx.settingsPanel = modules.settingsPanel.Create({
      getL = ctx.GetL,
      setLanguage = ctx.SetLanguage,
      getCurrentLocale = function()
        return IsiLiveDB and IsiLiveDB.locale or ctx.locale
      end,
      getDB = function()
        return IsiLiveDB or {}
      end,
      onEscPanelToggle = function(enabled)
        if ctx.panelUI and type(ctx.panelUI.SyncVisibility) == "function" then
          ctx.panelUI.SyncVisibility()
        end
        if ctx.panelUI and ctx.panelUI.hostFrame then
          if enabled then
            local gmf = rawget(_G, "GameMenuFrame")
            if gmf and type(gmf.IsShown) == "function" and gmf:IsShown() then
              ctx.panelUI.hostFrame:Show()
            end
          else
            ctx.panelUI.hostFrame:Hide()
          end
        end
      end,
      onQueueDebugToggle = function(enabled)
        if ctx.queueDebugController and type(ctx.queueDebugController.SetEnabled) == "function" then
          ctx.queueDebugController.SetEnabled(enabled)
        end
      end,
      onRuntimeLogToggle = function(enabled)
        if ctx.runtimeLogController and type(ctx.runtimeLogController.SetEnabled) == "function" then
          ctx.runtimeLogController.SetEnabled(enabled)
        end
      end,
      onBgAlphaChange = function(val)
        local uiCommon = ctx.addonTable and ctx.addonTable.UICommon
        if type(uiCommon) == "table" and type(uiCommon.Colors) == "table" then
          uiCommon.Colors.BG_PRIMARY[4] = val
        end
        if ctx.mainFrame and type(ctx.mainFrame.SetBackdropColor) == "function" then
          ctx.mainFrame:SetBackdropColor(0, 0, 0, val)
        end
        if ctx.panelUI and ctx.panelUI.panelFrame and type(ctx.panelUI.panelFrame.SetBackdropColor) == "function" then
          local bg = uiCommon and uiCommon.Colors and uiCommon.Colors.BG_PRIMARY or { 0.08, 0.08, 0.12, val }
          ctx.panelUI.panelFrame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        end
        if
          ctx.settingsPanel
          and ctx.settingsPanel.canvas
          and type(ctx.settingsPanel.canvas.SetBackdropColor) == "function"
        then
          local bg = uiCommon and uiCommon.Colors and uiCommon.Colors.BG_PRIMARY or { 0.08, 0.08, 0.12, val }
          ctx.settingsPanel.canvas:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        end
      end,
      onUiScaleChange = function(val)
        if ctx.mainFrame and type(ctx.mainFrame.SetScale) == "function" then
          ctx.mainFrame:SetScale(val)
        end
      end,
      onSyncToggle = function(_enabled)
        -- Runtime reads IsiLiveDB.syncEnabled directly; no additional action needed
      end,
      onShowDpsColumnToggle = function(_enabled)
        if ctx.rosterPanelController and type(ctx.rosterPanelController.RenderRoster) == "function" then
          ctx.rosterPanelController.RenderRoster(ctx.GetRoster())
        end
      end,
      onMinimapButtonToggle = function(enabled)
        if ctx.minimapButton then
          if enabled then
            ctx.minimapButton:Show()
          else
            ctx.minimapButton:Hide()
          end
        end
      end,
      onAutoOpenQueueToggle = function(_enabled)
        -- Runtime reads IsiLiveDB.autoOpenOnQueue directly; no additional action needed
      end,
      onAutoHideSoloToggle = function(enabled)
        if enabled and not IsInGroup() and ctx.mainFrame and ctx.mainFrame:IsShown() then
          ctx.mainFrame:Hide()
        end
      end,
      onNameMaxCharsChange = function(_maxChars)
        if ctx.rosterPanelController and type(ctx.rosterPanelController.RenderRoster) == "function" then
          ctx.rosterPanelController.RenderRoster(ctx.GetRoster())
        end
      end,
      onMarkersLeaderOnlyToggle = function(_enabled)
        if ctx.rosterPanelController and type(ctx.rosterPanelController.RenderRoster) == "function" then
          ctx.rosterPanelController.RenderRoster(ctx.GetRoster())
        end
      end,
      onTeleportColumnsChange = function(_columns)
        if ctx.teleportUIController and type(ctx.teleportUIController.UpdateButtons) == "function" then
          ctx.teleportUIController.UpdateButtons(ctx.ResolveTeleportSpellID())
        end
      end,
      onSoundToggle = function(_enabled)
        -- Runtime reads IsiLiveDB.soundEnabled directly; no additional action needed
      end,
    })
  end

  -- Restore saved UI Scale
  if IsiLiveDB and type(IsiLiveDB.uiScale) == "number" and IsiLiveDB.uiScale ~= 1.0 then
    if ctx.mainFrame and type(ctx.mainFrame.SetScale) == "function" then
      ctx.mainFrame:SetScale(IsiLiveDB.uiScale)
    end
  end

  -- Minimap Button
  if IsiLiveDB and IsiLiveDB.showMinimapButton then
    ctx.minimapButton = CreateFactoryMinimapButton(ctx)
  end
end

function Factory.InitializeAddon(addonName, addonTable)
  local ctx = CreateFactoryContext(addonName, addonTable)
  if not ctx then
    return
  end

  InitializeFactoryFrameBridge(ctx)
  InitializeFactoryRuntimeHelpers(ctx)
  InitializeFactoryPrimaryControllers(ctx)
  InitializeFactorySecondaryControllers(ctx)
  FinalizeFactoryRuntime(ctx)
end
