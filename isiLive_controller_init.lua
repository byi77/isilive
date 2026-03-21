local _, addonTable = ...

addonTable = addonTable or {}

local ControllerInit = {}
addonTable.ControllerInit = ControllerInit

local function CreateKeySyncController(ctx)
  local controller = ctx.keySyncModule.CreateController({
    sync = ctx.sync,
    getUnitNameAndRealm = ctx.getUnitNameAndRealm,
    getAddonVersionRaw = ctx.getAddonVersionRaw,
    getUnitRio = ctx.getUnitRio,
    isFrameVisible = ctx.isFrameVisible,
    canRespondToRefreshRequest = ctx.canRespondToRefreshRequest,
    getPlayerLastRunDps = ctx.getPlayerLastRunDps,
  })
  return {
    keySyncController = controller,
    markIsiLiveUser = controller.MarkIsiLiveUser,
    unitHasIsiLive = controller.UnitHasIsiLive,
    registerIsiLiveSyncPrefix = controller.RegisterIsiLiveSyncPrefix,
    sendIsiLiveHello = controller.SendIsiLiveHello,
    sendRefreshRequest = controller.SendRefreshRequest,
    getOwnedKeystoneSnapshot = controller.GetOwnedKeystoneSnapshot,
    sendOwnKeySnapshot = controller.SendOwnKeySnapshot,
    sendRefreshResponse = controller.SendRefreshResponse,
    applyKnownKeyToRosterEntry = controller.ApplyKnownKeyToRosterEntry,
  }
end

local function CreateHighlightController(ctx)
  return ctx.highlightModule.CreateController({
    isInGroup = ctx.isInGroup,
    resolveTeleportSpellIDByMapID = ctx.resolveTeleportSpellIDByMapID,
    resolveMapIDByActivityID = ctx.resolveMapIDByActivityID,
  })
end

local function CreateStatsController(ctx)
  return ctx.statsModule.CreateController({
    getRoster = ctx.getRoster,
    getUnitNameAndRealm = ctx.getUnitNameAndRealm,
  })
end

local function CreateRosterPanelController(ctx, keySyncResult)
  local controller = ctx.rosterPanelModule.CreateController({
    mainFrame = ctx.mainFrame,
    getL = ctx.getL,
    isPlayerLeader = ctx.isPlayerLeader,
    getAddonVersionText = ctx.getAddonVersionText,
    updateStatusLine = ctx.updateStatusLine,
    setMainFrameHeightSafe = ctx.setMainFrameHeightSafe,
    minFrameHeight = ctx.minFrameHeight,
    buildOrderedRoster = ctx.buildOrderedRoster,
    hasFullSync = ctx.hasFullSync,
    buildDisplayData = ctx.buildDisplayData,
    truncateName = ctx.truncateName,
    getShortSpecLabel = ctx.getShortSpecLabel,
    getLanguageFlagMarkup = ctx.getLanguageFlagMarkup,
    getDungeonShortCode = ctx.getDungeonShortCode,
    getRioDelta = ctx.getRioDelta,
    resolveActiveKeyOwnerUnit = ctx.resolveActiveKeyOwnerUnit,
    resolveTargetMapID = ctx.resolveTargetMapID,
    isReadyCheckActive = ctx.isReadyCheckActive,
    getRoster = ctx.getRoster,
    isInGroup = ctx.isInGroup,
    isRaidGroup = ctx.isRaidGroup,
    rolePriority = {
      TANK = 1,
      HEALER = 2,
      DAMAGER = 3,
      NONE = 4,
    },
    unitPriority = {
      player = 1,
      party1 = 2,
      party2 = 3,
      party3 = 4,
      party4 = 5,
    },
    syncMarker = " |TInterface\\AddOns\\isiLive\\media\\heart_sync:12:12|t",
    fullSyncMarker = " |cff00e68a[fullsync]|r",
    applyKnownKeyToRosterEntry = keySyncResult and keySyncResult.applyKnownKeyToRosterEntry or nil,
    getTime = ctx.getTime,
    shareKeysDebounceSeconds = ctx.shareKeysDebounceSeconds,
    getPlayerLastRunDps = ctx.getPlayerLastRunDps,
  })

  return {
    rosterPanelController = controller,
    refreshButton = controller.GetRefreshButton(),
    countdownCancelButton = controller.GetCountdownCancelButton(),
    statusLine = controller.GetStatusLine(),
  }
end

local function CreateTeleportUIController(ctx)
  local controller = ctx.teleportUIModule.CreateController({
    mainFrame = ctx.mainFrame,
    applySecureSpellToButton = ctx.applySecureSpellToButton,
    getEntries = ctx.getEntries,
    getL = ctx.getL,
    isSpellKnown = ctx.isSpellKnown,
    getTeleportCooldownRemaining = ctx.getTeleportCooldownRemaining,
    formatCooldownSeconds = ctx.formatCooldownSeconds,
    getSpellCooldownSafe = ctx.getSpellCooldownSafe,
    applyCooldownFrameSafe = ctx.applyCooldownFrameSafe,
    getSpellTexture = ctx.getSpellTexture,
    getEmptyStateText = ctx.getTeleportEmptyStateText,
    layoutMode = ctx.rosterPanelController
        and type(ctx.rosterPanelController.GetLayoutMode) == "function"
        and ctx.rosterPanelController.GetLayoutMode()
      or nil,
  })
  controller.BuildButtons()
  return {
    teleportUIController = controller,
    mplusTeleportButtons = controller.GetButtons(),
  }
end

function ControllerInit.CreateControllers(ctx)
  local result = {}

  local statsController = CreateStatsController(ctx)
  result.statsController = statsController
  -- Inject stats getters into context for downstream consumers
  ctx.getPlayerLastRunDps = statsController.GetPlayerLastRunDps
  result.recordRun = statsController.RecordRun

  local keySyncResult = CreateKeySyncController(ctx)
  for key, value in pairs(keySyncResult) do
    result[key] = value
  end

  result.highlightController = CreateHighlightController(ctx)

  local rosterPanelResult = CreateRosterPanelController(ctx, keySyncResult)
  for key, value in pairs(rosterPanelResult) do
    result[key] = value
  end
  result.rosterPanelController.ApplyLocalization()

  local teleportUIResult = CreateTeleportUIController(ctx)
  for key, value in pairs(teleportUIResult) do
    result[key] = value
  end

  if result.rosterPanelController and result.teleportUIController then
    result.rosterPanelController.SetCollapseChangedHandler(function(isCollapsed)
      result.teleportUIController.SetVisible(not isCollapsed)
    end)
    if type(result.rosterPanelController.SetLayoutChangedHandler) == "function" then
      result.rosterPanelController.SetLayoutChangedHandler(function(layoutMode)
        result.teleportUIController.SetLayoutMode(layoutMode)
      end)
    end
    if type(result.rosterPanelController.GetLayoutMode) == "function" then
      result.teleportUIController.SetLayoutMode(result.rosterPanelController.GetLayoutMode())
    end
    result.teleportUIController.SetVisible(not result.rosterPanelController.IsCollapsed())
  end

  return result
end
