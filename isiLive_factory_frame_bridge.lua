local _, moduleAddonTable = ...
moduleAddonTable = moduleAddonTable or {}

local FI = moduleAddonTable._FactoryInternal or {}
moduleAddonTable._FactoryInternal = FI

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
    cdTracker = addonTable and addonTable.CdTracker,
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
FI.BuildFactoryModules = BuildFactoryModules

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
    local unitExists = rawget(_G, "UnitExists")
    if type(unitExists) ~= "function" or not unitExists("player") then
      return false
    end
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
    isInGroup = IsInGroup,
    isInCombat = ctx.IsInCombat,
    onShownInGroup = function()
      if type(ctx.RestoreLayoutState) == "function" then
        ctx.RestoreLayoutState()
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
    frameBridgeContext.ShowCenterNotice(message, durationSeconds, dungeonName, activityID, showOptions)
  end
  ctx.SetPortalNavigatorVisible = function(visible)
    ctx.portalNavigatorNotice.SetVisible(visible)
  end
  ctx.ShowPortalNavigatorNotice = function(layout)
    ctx.portalNavigatorNotice.Show(layout)
  end
  ctx.ShowInviteHint = function(message, durationSeconds)
    frameBridgeContext.ShowInviteHint(message, durationSeconds)
  end
  ctx.SetMainFrameVisible = function(visible, reason)
    if visible and reason == "queue" then
      local dbRef = rawget(_G, "IsiLiveDB")
      if dbRef and dbRef.autoOpenOnQueue == false then
        return false
      end
    end
    return frameBridgeContext.SetMainFrameVisible(visible)
  end
  ctx.SetMainFrameHeightSafe = function(height)
    frameBridgeContext.SetMainFrameHeightSafe(height)
  end
  ctx.ToggleMainFrameVisibility = function()
    frameBridgeContext.ToggleMainFrameVisibility()
  end
  ctx.inspectLoopTimer = 0
end
FI.InitializeFactoryFrameBridge = InitializeFactoryFrameBridge
