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
    getPlayerSyncSummary = ctx.getPlayerSyncSummary,
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
    sendOwnBackgroundSnapshot = controller.SendOwnBackgroundSnapshot,
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
    setMainFrameWidthSafe = ctx.setMainFrameWidthSafe,
    minFrameHeight = ctx.minFrameHeight,
    buildOrderedRoster = ctx.buildOrderedRoster,
    hasFullSync = ctx.hasFullSync,
    buildDisplayData = ctx.buildDisplayData,
    truncateName = ctx.truncateName,
    getShortSpecLabel = ctx.getShortSpecLabel,
    getLanguageFlagMarkup = ctx.getLanguageFlagMarkup,
    getLanguageTooltipMarkup = ctx.getLanguageTooltipMarkup,
    getDungeonShortCode = ctx.getDungeonShortCode,
    getDungeonName = ctx.getDungeonName,
    getRioDelta = ctx.getRioDelta,
    getPlayerSyncSummary = ctx.getPlayerSyncSummary,
    resolveActiveKeyOwnerUnit = ctx.resolveActiveKeyOwnerUnit,
    resolveTargetMapID = ctx.resolveTargetMapID,
    isReadyCheckActive = ctx.isReadyCheckActive,
    getReadyCheckDeclinedUntil = ctx.getReadyCheckDeclinedUntil,
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
    syncBadge = " |TInterface\\Buttons\\UI-RefreshButton:12:12|t",
    applyKnownKeyToRosterEntry = keySyncResult.applyKnownKeyToRosterEntry,
    getTime = ctx.getTime,
    shareKeysDebounceSeconds = ctx.shareKeysDebounceSeconds,
    getPlayerLastRunDps = ctx.getPlayerLastRunDps,
    sendShareKeysRequest = ctx.sendShareKeysRequest,
    isSyncUserKnown = ctx.isSyncUserKnown,
    showRosterColumnGuides = function()
      local db = rawget(_G, "IsiLiveDB")
      return type(db) == "table" and db.showRosterColumnGuides == true
    end,
  })

  return {
    rosterPanelController = controller,
    refreshButton = controller.GetRefreshButton(),
    countdownCancelButton = controller.GetCountdownCancelButton(),
    statusLine = controller.GetStatusLine(),
    triggerShareKeysCooldown = function()
      controller.TriggerShareKeysCooldown()
    end,
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
    getDungeonShortCode = ctx.getDungeonShortCode,
    getDungeonName = ctx.getDungeonName,
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
        if ctx.mainUI and type(ctx.mainUI.SetDragGripVisible) == "function" then
          ctx.mainUI.SetDragGripVisible(layoutMode ~= "compact_vertical" and layoutMode ~= "compact_horizontal")
        end
      end)
    end
    if type(result.rosterPanelController.GetLayoutMode) == "function" then
      local currentLayoutMode = result.rosterPanelController.GetLayoutMode()
      result.teleportUIController.SetLayoutMode(currentLayoutMode)
      if ctx.mainUI and type(ctx.mainUI.SetDragGripVisible) == "function" then
        ctx.mainUI.SetDragGripVisible(
          currentLayoutMode ~= "compact_vertical" and currentLayoutMode ~= "compact_horizontal"
        )
      end
    end
    result.teleportUIController.SetVisible(not result.rosterPanelController.IsCollapsed())
  end

  return result
end
