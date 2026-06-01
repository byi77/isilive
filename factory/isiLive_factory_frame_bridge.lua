local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local function BuildFactoryModules(tbl)
  return {
    sync = tbl and tbl.Sync,
    keySync = tbl and tbl.KeySync,
    refresh = tbl and tbl.Refresh,
    highlight = tbl and tbl.Highlight,
    group = tbl and tbl.Group,
    queue = tbl and tbl.Queue,
    inspect = tbl and tbl.Inspect,
    roster = tbl and tbl.Roster,
    events = tbl and tbl.Events,
    eventHandlers = tbl and tbl.EventHandlers,
    commands = tbl and tbl.Commands,
    locale = tbl and tbl.Locale,
    texts = tbl and tbl.Texts,
    ui = tbl and tbl.UI,
    teleport = tbl and tbl.Teleport,
    teleportUI = tbl and tbl.TeleportUI,
    teleportDebug = tbl and tbl.TeleportDebug,
    traceChatFrame = tbl and tbl.TraceChatFrame,
    notice = tbl and tbl.Notice,
    status = tbl and tbl.Status,
    units = tbl and tbl.Units,
    demo = tbl and tbl.Demo,
    testMode = tbl and tbl.TestMode,
    queueDebug = tbl and tbl.QueueDebug,
    runtimeLog = tbl and tbl.RuntimeLog,
    rosterPanel = tbl and tbl.RosterPanel,
    spellUtils = tbl and tbl.SpellUtils,
    cdTracker = tbl and tbl.CdTracker,
    lfgDetect = tbl and tbl.LFGDetect,
    lfgFlags = tbl and tbl.LFGFlags,
    mobTooltip = tbl and tbl.MobTooltip,
    mobNameplate = tbl and tbl.MobNameplate,
    mplusTimer = tbl and tbl.MplusTimer,
    killTrack = tbl and tbl.KillTrack,
    kickTracker = tbl and tbl.KickTracker,
    combatEvents = tbl and tbl.CombatEvents,
    bindings = tbl and tbl.Bindings,
    eventUtils = tbl and tbl.EventUtils,
    bootstrap = tbl and tbl.Bootstrap,
    controllerWiring = tbl and tbl.ControllerWiring,
    leaderWatch = tbl and tbl.LeaderWatch,
    configBuilders = tbl and tbl.ConfigBuilders,
    frameBridge = tbl and tbl.FrameBridge,
    contextHelpers = tbl and tbl.ContextHelpers,
    runtimeSetup = tbl and tbl.RuntimeSetup,
    controllerInit = tbl and tbl.ControllerInit,
    guards = tbl and tbl.Guards,
    stats = tbl and tbl.Stats,
    runtimeState = tbl and tbl.RuntimeState,
    settingsPanel = tbl and tbl.SettingsPanel,
  }
end
FI.BuildFactoryModules = BuildFactoryModules

local function CreateFactoryContext(addonName, tbl)
  local modules = BuildFactoryModules(tbl)
  local isiLiveRuntimeState = modules.runtimeState
  local ctx = {
    addonName = addonName,
    addonTable = tbl,
    modules = modules,
    INSPECT_TIMEOUT = 2,
    RETRY_INTERVAL = 5,
    INSPECT_DELAY = 1,
    MIN_FRAME_HEIGHT = 236,
    locale = GetLocale(),
  }

  ctx.isInGroup = function()
    local isInGroup = rawget(_G, "IsInGroup")
    return type(isInGroup) == "function" and isInGroup() == true
  end

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

  -- Styled variant for user-visible highlights (target-dungeon announce etc.).
  -- Blue "isiLive" brand prefix, rest passes through -- callers colour their
  -- own payload via |cff......|r so each announcement can pick its own palette.
  ctx.PrintHighlighted = function(msg)
    local text = tostring(msg or "")
    print("|cff4da6ffisiLive|r: " .. text)
    if ctx.runtimeLogController and ctx.runtimeLogController.Log then
      ctx.runtimeLogController.Log(text)
    end
  end

  if not (modules.guards and type(modules.guards.Validate) == "function") then
    print("|cffff0000isiLive: missing module Guards (isiLive_guards.lua)|r")
    return nil
  end

  local guardsOk, guardsErr = pcall(modules.guards.Validate, tbl)
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
    maxEntries = 10000,
    buildSessionHeader = function()
      local db = rawget(_G, "IsiLiveDB")
      return string.format(
        "version=%s locale=%s level=%s maxEntries=%s",
        tostring(ctx.GetAddonVersionRaw and ctx.GetAddonVersionRaw() or "unknown"),
        tostring(db and db.locale or ctx.locale or "unknown"),
        tostring(db and db.runtimeLogLevel or "normal"),
        "10000"
      )
    end,
  })

  if modules.traceChatFrame and type(modules.traceChatFrame.CreateController) == "function" then
    ctx.traceChatFrameController = modules.traceChatFrame.CreateController()
  end

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
    modules.queue.SetDebugLogger(function(msg)
      ctx.queueDebugController.Log(msg)
      local runtimeLog = ctx.runtimeLogController
      if runtimeLog then
        runtimeLog.Log(msg)
      end
    end)
  end

  local runtimeState = isiLiveRuntimeState.CreateController()
  ctx.runtimeState = runtimeState
  ctx.GetSpellCooldownSafe = modules.spellUtils.GetSpellCooldownSafe
  ctx.ApplyCooldownFrameSafe = modules.spellUtils.ApplyCooldownFrameSafe
  ctx.IsSpellKnownSafe = modules.spellUtils.IsSpellKnownSafe
  ctx.GetTeleportCooldownRemaining = modules.spellUtils.GetTeleportCooldownRemaining
  ctx.GetCooldownFrameStartForRemaining = modules.spellUtils.GetCooldownFrameStartForRemaining
  ctx.FormatCooldownSeconds = modules.spellUtils.FormatCooldownSeconds
  ctx.IsNegativeApplicationStatusEvent = modules.eventUtils.IsNegativeApplicationStatusEvent
  ctx.IsPlayerLeader = function()
    if ctx.runtimeState.IsTestAllMode() then
      return true
    end
    local unitExists = rawget(_G, "UnitExists")
    if type(unitExists) ~= "function" then
      return false
    end
    local okUnit, playerExists = pcall(unitExists, "player")
    if not (okUnit and playerExists) then
      return false
    end
    -- secret-value-ok: IsInGroup short-circuits in solo, UnitIsGroupLeader is the leader query itself
    return IsInGroup() and UnitIsGroupLeader("player")
  end

  ctx.GetRealmInfoLib = modules.contextHelpers.CreateRealmInfoGetter()
  ctx.GetLanguageTooltipMarkup = function(languageTag)
    return modules.locale.GetLanguageTooltipMarkup(languageTag, ctx.locale)
  end
  ctx.GetUnitRole = modules.units.GetUnitRole
  ctx.GetUnitClass = modules.units.GetUnitClass
  ctx.TruncateName = modules.units.TruncateName
  ctx.GetUnitNameAndRealm = modules.units.GetUnitNameAndRealm
  ctx.GetPlayerSpecName = modules.units.GetPlayerSpecName
  ctx.GetInspectSpecName = modules.units.GetInspectSpecName
  ctx.GetShortSpecLabel = modules.units.GetShortSpecLabel
  ctx.GetUnitRio = modules.units.GetUnitRio
  ctx.GetOwnAverageItemLevel = modules.keySync and modules.keySync.ResolveAverageItemLevel
    or function()
      return nil
    end
  ctx.GetNumGroupMembers = function()
    local getNumGroupMembers = rawget(_G, "GetNumGroupMembers")
    if type(getNumGroupMembers) ~= "function" then
      return 0
    end
    local ok, groupMembers = pcall(getNumGroupMembers)
    groupMembers = ok and tonumber(groupMembers) or nil
    if not groupMembers then
      return 0
    end
    return math.max(0, math.floor(groupMembers))
  end
  ctx.IsRaidGroup = function()
    local isInRaid = rawget(_G, "IsInRaid")
    if type(isInRaid) == "function" then
      local ok, raid = pcall(isInRaid)
      if ok and raid == true then
        return true
      end
    end
    return IsInGroup() and ctx.GetNumGroupMembers() > 5
  end
  ctx.GetSubZoneText = function()
    local getSubZoneText = rawget(_G, "GetSubZoneText")
    if type(getSubZoneText) ~= "function" then
      return nil
    end
    local ok, text = pcall(getSubZoneText)
    if not ok then
      return nil
    end
    return text
  end
  ctx.GetZoneText = function()
    local getZoneText = rawget(_G, "GetZoneText")
    if type(getZoneText) ~= "function" then
      return nil
    end
    local ok, text = pcall(getZoneText)
    if not ok then
      return nil
    end
    return text
  end
  ctx.GetRealZoneText = function()
    local getRealZoneText = rawget(_G, "GetRealZoneText")
    if type(getRealZoneText) ~= "function" then
      return nil
    end
    local ok, text = pcall(getRealZoneText)
    if not ok then
      return nil
    end
    return text
  end
  ctx.GetPlayerMapID = function()
    local unitExists = rawget(_G, "UnitExists")
    if type(unitExists) ~= "function" then
      return nil
    end
    local okExists, exists = pcall(unitExists, "player")
    if not okExists or not exists then
      return nil
    end
    local mapApi = rawget(_G, "C_Map")
    local getBestMapForUnit = mapApi and rawget(mapApi, "GetBestMapForUnit") or nil
    if type(getBestMapForUnit) ~= "function" then
      return nil
    end
    local ok, mapID = pcall(getBestMapForUnit, "player")
    mapID = ok and tonumber(mapID) or nil
    if not mapID or mapID <= 0 then
      return nil
    end
    return math.floor(mapID)
  end
  ctx.GetMapInfoName = function(mapID)
    local numericMapID = tonumber(mapID)
    if not numericMapID or numericMapID <= 0 then
      return nil
    end
    local mapApi = rawget(_G, "C_Map")
    local getMapInfo = mapApi and rawget(mapApi, "GetMapInfo") or nil
    if type(getMapInfo) ~= "function" then
      return nil
    end
    local ok, mapInfo = pcall(getMapInfo, numericMapID)
    if not ok or type(mapInfo) ~= "table" then
      return nil
    end
    if type(mapInfo.name) ~= "string" then
      return nil
    end
    return mapInfo.name
  end

  ctx.BuildDummyRoster = function(opts)
    opts = opts or {}
    return modules.contextHelpers.BuildDummyRoster({
      demoBuildDummyRoster = modules.demo.BuildDummyRoster,
      previewVariant = opts.previewVariant,
      includeGhostMember = opts.includeGhostMember,
      getUnitNameAndRealm = ctx.GetUnitNameAndRealm,
      getUnitClass = ctx.GetUnitClass,
      getUnitServerLanguage = function(unit, realm)
        return modules.contextHelpers.GetUnitServerLanguage(modules.locale, ctx.GetRealmInfoLib, unit, realm)
      end,
      getUnitRole = ctx.GetUnitRole,
      getPlayerSpecName = ctx.GetPlayerSpecName,
      getUnitRio = ctx.GetUnitRio,
    })
  end

  ctx.ResolveMainFramePositionLockEnabled = function(dbRef)
    return not (type(dbRef) == "table" and dbRef.lockMainFramePosition == false)
  end

  return ctx
end
FI.CreateFactoryContext = CreateFactoryContext

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

    local _, class = ctx.GetUnitClass("player")
    local language = modules.contextHelpers.GetUnitServerLanguage(modules.locale, ctx.GetRealmInfoLib, "player", realm)
    local keyMapID, keyLevel
    if type(ctx.GetOwnedKeystoneSnapshot) == "function" then
      keyMapID, keyLevel = ctx.GetOwnedKeystoneSnapshot()
    end

    -- Solo player ilvl comes from C_Item.GetAverageItemLevel directly:
    -- this path bypasses UpdatePlayerEntry entirely, so without filling ilvl
    -- here the local row stays blank until a Re-Sync forces an inspect cycle.
    local ownIlvl = type(ctx.GetOwnAverageItemLevel) == "function" and ctx.GetOwnAverageItemLevel() or nil

    ctx.runtimeState.SetRoster({
      player = {
        name = name,
        realm = realm,
        language = language,
        class = class,
        role = ctx.GetUnitRole("player"),
        spec = ctx.GetPlayerSpecName(),
        ilvl = ownIlvl,
        _localIlvlFresh = ownIlvl ~= nil or nil,
        rio = ctx.GetUnitRio("player"),
        hasIsiLive = true,
        keyMapID = keyMapID,
        keyLevel = keyLevel,
      },
    })
  end

  ctx.ResolveTeleportSpellIDByActivityID = modules.teleport.ResolveTeleportSpellIDByActivityID
  ctx.ResolveTeleportSpellIDByMapID = modules.teleport.ResolveTeleportSpellIDByMapID
  ctx.ResolveMapIDByActivityID = modules.teleport.ResolveMapIDByActivityID
  ctx.ResolveMapIDBySpellID = modules.teleport.ResolveMapIDBySpellID
  ctx.ResolveTeleportSpellID = modules.teleport.ResolveTeleportSpellID
  ctx.GetDungeonName = function(mapID, localeTag)
    local db = rawget(_G, "IsiLiveDB")
    local activeLocale = (db and db.locale) or ctx.locale
    return modules.teleport.GetDungeonName(mapID, localeTag or activeLocale)
  end
  ctx.ApplySecureSpellToButton = modules.teleport.ApplySecureSpellToButton
  ctx.IsInCombat = function()
    local inCombatFn = rawget(_G, "InCombatLockdown")
    return type(inCombatFn) == "function" and inCombatFn() == true
  end

  ctx.portalNavigatorNotice = modules.notice.CreatePortalNavigatorNotice({
    parent = UIParent,
    frameName = "isiLivePortalNavigatorNotice",
  })

  local frameBridgeContext = modules.frameBridge.CreateContext({
    createCenterNotice = modules.notice.CreateCenterNotice,
    createInviteHint = modules.notice.CreateInviteHint,
    createMainFrame = modules.ui.CreateMainFrame,
    parent = UIParent,
    mainFrameGlobalName = "isiLiveMainFrame",
    mainFrameMinHeight = ctx.MIN_FRAME_HEIGHT,
    isMainFrameDragLocked = function()
      local db = rawget(_G, "IsiLiveDB")
      return ctx.ResolveMainFramePositionLockEnabled(db)
    end,
    isInGroup = IsInGroup,
    isInCombat = ctx.IsInCombat,
    isRaidGroup = ctx.IsRaidGroup,
    onShownInGroup = function()
      if type(ctx.RestoreLayoutState) == "function" then
        ctx.RestoreLayoutState()
      end
      if ctx.rosterPanelController and type(ctx.rosterPanelController.MarkCdTrackerDirty) == "function" then
        ctx.rosterPanelController.MarkCdTrackerDirty()
      end
      local onEventHandler = ctx.mainFrame and ctx.mainFrame:GetScript("OnEvent")
      if onEventHandler then
        onEventHandler(ctx.mainFrame, "GROUP_ROSTER_UPDATE")
      end
    end,
    onShownNoGroup = function()
      if type(ctx.RestoreLayoutState) == "function" then
        ctx.RestoreLayoutState()
      end
      if ctx.rosterPanelController and type(ctx.rosterPanelController.MarkCdTrackerDirty) == "function" then
        ctx.rosterPanelController.MarkCdTrackerDirty()
      end
      ctx.EnsureSoloPlayerRoster()
      ctx.UpdateUI()
      ctx.UpdateLeaderButtons()
      ctx.UpdateMPlusTeleportButton()
    end,
    resolveTeleportSpellID = ctx.ResolveTeleportSpellID,
    resolveTeleportSpellIDByMapID = ctx.ResolveTeleportSpellIDByMapID,
    resolveMapIDBySpellID = ctx.ResolveMapIDBySpellID,
    resolveMapIDByActivityID = ctx.ResolveMapIDByActivityID,
    applySecureSpellToButton = ctx.ApplySecureSpellToButton,
    isSpellKnown = ctx.IsSpellKnownSafe,
    getTeleportCooldownRemaining = ctx.GetTeleportCooldownRemaining,
    formatCooldownSeconds = ctx.FormatCooldownSeconds,
    getDungeonName = ctx.GetDungeonName,
    getL = ctx.GetL,
    onOpenSettings = function()
      local blizzardSettings = rawget(_G, "Settings")
      if type(blizzardSettings) ~= "table" or type(blizzardSettings.OpenToCategory) ~= "function" then
        return
      end
      if ctx.settingsPanel and ctx.settingsPanel.category then
        blizzardSettings.OpenToCategory(ctx.settingsPanel.category.ID)
      end
    end,
  })

  ctx.centerNotice = frameBridgeContext.centerNotice
  ctx.centerNoticeFrame = frameBridgeContext.centerNoticeFrame
  ctx.centerNoticeTeleportButton = frameBridgeContext.centerNoticeTeleportButton
  ctx.demoCenterNotices = {
    modules.notice.CreateCenterNotice({
      parent = UIParent,
      frameName = "isiLiveDemoCenterNoticeTarget",
      teleportButtonName = "isiLiveDemoCenterNoticeTargetTeleportButton",
      minHeight = 70,
      maxHeight = 220,
      paddingX = 20,
      paddingY = 12,
      buttonHeight = 36,
      buttonGap = 8,
      yOffset = -20,
      isInCombat = ctx.IsInCombat,
      resolveTeleportSpellID = ctx.ResolveTeleportSpellID,
      resolveTeleportSpellIDByMapID = ctx.ResolveTeleportSpellIDByMapID,
      resolveMapIDBySpellID = ctx.ResolveMapIDBySpellID,
      resolveMapIDByActivityID = ctx.ResolveMapIDByActivityID,
      applySecureSpellToButton = ctx.ApplySecureSpellToButton,
      isSpellKnown = ctx.IsSpellKnownSafe,
      getTeleportCooldownRemaining = ctx.GetTeleportCooldownRemaining,
      formatCooldownSeconds = ctx.FormatCooldownSeconds,
      getDungeonName = ctx.GetDungeonName,
      getL = ctx.GetL,
    }),
    modules.notice.CreateCenterNotice({
      parent = UIParent,
      frameName = "isiLiveDemoCenterNoticeDifficulty",
      teleportButtonName = "isiLiveDemoCenterNoticeDifficultyTeleportButton",
      minHeight = 70,
      maxHeight = 220,
      paddingX = 20,
      paddingY = 12,
      buttonHeight = 36,
      buttonGap = 8,
      yOffset = -245,
      isInCombat = ctx.IsInCombat,
      resolveTeleportSpellID = ctx.ResolveTeleportSpellID,
      resolveTeleportSpellIDByMapID = ctx.ResolveTeleportSpellIDByMapID,
      resolveMapIDBySpellID = ctx.ResolveMapIDBySpellID,
      resolveMapIDByActivityID = ctx.ResolveMapIDByActivityID,
      applySecureSpellToButton = ctx.ApplySecureSpellToButton,
      isSpellKnown = ctx.IsSpellKnownSafe,
      getTeleportCooldownRemaining = ctx.GetTeleportCooldownRemaining,
      formatCooldownSeconds = ctx.FormatCooldownSeconds,
      getDungeonName = ctx.GetDungeonName,
      getL = ctx.GetL,
    }),
  }
  ctx.portalNavigatorNoticeFrame = ctx.portalNavigatorNotice.frame
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
    local hasMapID = type(showOptions) == "table" and tonumber(showOptions.teleportMapID) ~= nil
    if (type(dungeonName) == "string" and dungeonName ~= "") or tonumber(activityID) or hasMapID then
      ctx.centerNotice.Show(message, durationSeconds, dungeonName, activityID, showOptions)
      return
    end
    frameBridgeContext.ShowCenterNotice(message, durationSeconds, dungeonName, activityID, showOptions)
  end
  ctx.ShowDemoCenterNotices = function(notices)
    ctx.centerNotice.SetVisible(false)
    for index, notice in ipairs(ctx.demoCenterNotices or {}) do
      local payload = type(notices) == "table" and notices[index] or nil
      if type(payload) == "table" then
        notice.Show(
          payload.message,
          payload.durationSeconds,
          payload.dungeonName,
          payload.activityID,
          payload.showOptions
        )
      else
        notice.SetVisible(false)
      end
    end
  end
  ctx.SetDemoCenterNoticesVisible = function(visible)
    for _, notice in ipairs(ctx.demoCenterNotices or {}) do
      notice.SetVisible(visible)
    end
  end
  ctx.SetPortalNavigatorVisible = function(visible)
    ctx.portalNavigatorNotice.SetVisible(visible)
  end
  ctx.ShowPortalNavigatorNotice = function(layout)
    ctx.portalNavigatorNotice.Show(layout)
  end
  ctx.ShowInviteHint = function(message, durationSeconds, searchResultID)
    frameBridgeContext.ShowInviteHint(message, durationSeconds, searchResultID)
  end
  ctx.SetMainFrameVisible = function(visible, reasonOrOpts)
    local opts = type(reasonOrOpts) == "table" and reasonOrOpts or {}
    local reason = type(reasonOrOpts) == "string" and reasonOrOpts or opts.reason
    local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
    if logf then
      logf(
        "[FRAME] set_visible visible=%s reason=%s skipShowCallbacks=%s",
        tostring(visible),
        tostring(reason),
        tostring(opts.skipShowCallbacks)
      )
    end
    if visible and reason == "queue" then
      local dbRef = rawget(_G, "IsiLiveDB")
      if dbRef and dbRef.autoOpenOnQueue == false then
        if ctx.runtimeLogController and ctx.runtimeLogController.Log then
          ctx.runtimeLogController.Log("[FRAME] blocked reason=autoOpenOnQueue_disabled")
        end
        return false
      end
    end
    return frameBridgeContext.SetMainFrameVisible(visible, opts)
  end
  ctx.SetMainFrameHeightSafe = function(height)
    frameBridgeContext.SetMainFrameHeightSafe(height)
  end
  ctx.SetMainFrameWidthSafe = function(width)
    frameBridgeContext.SetMainFrameWidthSafe(width)
  end
  ctx.RestoreBgAlpha = function(alpha)
    local uiCommon = ctx.addonTable and ctx.addonTable.UICommon
    if type(uiCommon) ~= "table" or type(uiCommon.ApplyBgAlpha) ~= "function" then
      return
    end
    uiCommon.ApplyBgAlpha({
      mainFrame = ctx.mainFrame,
      panelFrame = ctx.panelUI and ctx.panelUI.panelFrame,
      settingsCanvas = ctx.settingsPanel and ctx.settingsPanel.canvas,
    }, alpha)
  end
  ctx.ToggleMainFrameVisibility = function()
    frameBridgeContext.ToggleMainFrameVisibility()
    local isNowVisible = frameBridgeContext.IsMainFrameVisible and frameBridgeContext.IsMainFrameVisible()
    local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
    if logf then
      logf("[UI] toggle_main_frame isNowVisible=%s", tostring(isNowVisible))
    end
    if not isNowVisible and type(ctx.ExitTestMode) == "function" then
      ctx.ExitTestMode()
    end
  end
  ctx.inspectLoopTimer = 0
end
FI.InitializeFactoryFrameBridge = InitializeFactoryFrameBridge
