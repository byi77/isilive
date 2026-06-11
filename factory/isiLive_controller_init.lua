local _, addonTable = ...

addonTable = addonTable or {}

local ControllerInit = {}
addonTable.ControllerInit = ControllerInit

-- The drag grip is shown for every layout mode EXCEPT the compact ones
-- (vertical / horizontal). Route the predicate through _RosterInternal so the
-- magic strings live in exactly one place (isiLive_roster_layout.lua).
local function ShouldShowDragGrip(layoutMode)
  local RI = addonTable._RosterInternal
  if type(RI) == "table" and type(RI.IsCompactLayoutMode) == "function" then
    return not RI.IsCompactLayoutMode(layoutMode)
  end
  -- Fallback for load-order edge cases: hard-coded recognition of the two
  -- compact modes. Matches the legacy literal-string check this helper
  -- replaces.
  return layoutMode ~= "compact_vertical" and layoutMode ~= "compact_horizontal"
end

local function UpdateMainUIDragGrip(mainUI, layoutMode)
  if not (mainUI and type(mainUI.SetDragGripVisible) == "function") then
    return
  end
  mainUI.SetDragGripVisible(ShouldShowDragGrip(layoutMode))
end

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
    logRuntimeTrace = ctx.logRuntimeTrace,
  })
  return {
    keySyncController = controller,
    markIsiLiveUser = controller.MarkIsiLiveUser,
    unitHasIsiLive = controller.UnitHasIsiLive,
    registerIsiLiveSyncPrefix = controller.RegisterIsiLiveSyncPrefix,
    sendIsiLiveHello = controller.SendIsiLiveHello,
    sendRefreshRequest = controller.SendRefreshRequest,
    sendLibKeystonePartyData = controller.SendLibKeystonePartyData,
    getOwnedKeystoneSnapshot = controller.GetOwnedKeystoneSnapshot,
    sendOwnKeySnapshot = controller.SendOwnKeySnapshot,
    sendOwnBackgroundSnapshot = controller.SendOwnBackgroundSnapshot,
    sendRefreshResponse = controller.SendRefreshResponse,
    applyKnownKeyToRosterEntry = controller.ApplyKnownKeyToRosterEntry,
    registerVerifiedSyncAliasForRoster = controller.RegisterVerifiedSyncAliasForRoster,
  }
end

local function CreateHighlightController(ctx)
  return ctx.highlightModule.CreateController({
    isInGroup = ctx.isInGroup,
    resolveTeleportSpellIDByMapID = ctx.resolveTeleportSpellIDByMapID,
    resolveMapIDByActivityID = ctx.resolveMapIDByActivityID,
    logRuntimeTrace = ctx.logRuntimeTrace,
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
    buildDisplayData = ctx.buildDisplayData,
    truncateName = ctx.truncateName,
    getShortSpecLabel = ctx.getShortSpecLabel,
    getLanguageFlagMarkup = ctx.getLanguageFlagMarkup,
    getLanguageTooltipMarkup = ctx.getLanguageTooltipMarkup,
    getDungeonShortCode = ctx.getDungeonShortCode,
    getDungeonName = ctx.getDungeonName,
    getOwnedKeystoneSnapshot = keySyncResult.getOwnedKeystoneSnapshot,
    getRioDelta = ctx.getRioDelta,
    getPlayerSyncSummary = ctx.getPlayerSyncSummary,
    resolveActiveKeyOwnerUnit = ctx.resolveActiveKeyOwnerUnit,
    resolveTargetMapID = ctx.resolveTargetMapID,
    isReadyCheckActive = ctx.isReadyCheckActive,
    getReadyCheckReadyUntil = ctx.getReadyCheckReadyUntil,
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
    getTargetDungeonInfo = ctx.getTargetDungeonInfo,
    isInChallengeMode = ctx.isInChallengeMode,
    sendShareKeysRequest = ctx.sendShareKeysRequest,
    isSyncUserKnown = ctx.isSyncUserKnown,
    logRuntimeTrace = ctx.logRuntimeTrace,
    logRuntimeTraceDeep = ctx.logRuntimeTraceDeep,
  })

  return {
    rosterPanelController = controller,
    refreshButton = controller.GetRefreshButton(),
    countdownCancelButton = controller.GetCountdownCancelButton(),
    statusLine = controller.GetStatusLine(),
    triggerShareKeysCooldown = function(seconds)
      controller.TriggerShareKeysCooldown(seconds)
    end,
    getShareKeysCooldownRemaining = function()
      return controller.GetShareKeysCooldownRemaining()
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
    getCooldownFrameStartForRemaining = ctx.getCooldownFrameStartForRemaining,
    applyCooldownFrameSafe = ctx.applyCooldownFrameSafe,
    getSpellTexture = ctx.getSpellTexture,
    getDungeonShortCode = ctx.getDungeonShortCode,
    getDungeonName = ctx.getDungeonName,
    getEmptyStateText = ctx.getTeleportEmptyStateText,
    logRuntimeTraceDeep = ctx.logRuntimeTraceDeep,
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
        UpdateMainUIDragGrip(ctx.mainUI, layoutMode)
      end)
    end
    if type(result.rosterPanelController.GetLayoutMode) == "function" then
      local currentLayoutMode = result.rosterPanelController.GetLayoutMode()
      result.teleportUIController.SetLayoutMode(currentLayoutMode)
      UpdateMainUIDragGrip(ctx.mainUI, currentLayoutMode)
    end
    result.teleportUIController.SetVisible(not result.rosterPanelController.IsCollapsed())
  end

  return result
end
