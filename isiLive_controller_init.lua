local _, addonTable = ...

addonTable = addonTable or {}

local ControllerInit = {}
addonTable.ControllerInit = ControllerInit

local function CreateKeySyncController(ctx)
  local controller = ctx.keySyncModule.CreateController({
    sync = ctx.sync,
    getUnitNameAndRealm = ctx.getUnitNameAndRealm,
    getAddonVersionRaw = ctx.getAddonVersionRaw,
    isFrameVisible = ctx.isFrameVisible,
  })
  return {
    keySyncController = controller,
    markIsiLiveUser = controller.MarkIsiLiveUser,
    unitHasIsiLive = controller.UnitHasIsiLive,
    registerIsiLiveSyncPrefix = controller.RegisterIsiLiveSyncPrefix,
    sendIsiLiveHello = controller.SendIsiLiveHello,
    getOwnedKeystoneSnapshot = controller.GetOwnedKeystoneSnapshot,
    sendOwnKeySnapshot = controller.SendOwnKeySnapshot,
    applyKnownKeyToRosterEntry = controller.ApplyKnownKeyToRosterEntry,
  }
end

local function CreateHighlightController(ctx)
  return ctx.highlightModule.CreateController({
    isInGroup = ctx.isInGroup,
    resolveSeason3TeleportSpellIDByMapID = ctx.resolveSeason3TeleportSpellIDByMapID,
    resolveSeason3MapIDByActivityID = ctx.resolveSeason3MapIDByActivityID,
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
    getRoster = ctx.getRoster,
    isInGroup = ctx.isInGroup,
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
    syncMarker = " |cff33aaff<3|r",
    fullSyncMarker = " |cff00e68a[fullsync]|r",
    applyKnownKeyToRosterEntry = keySyncResult and keySyncResult.applyKnownKeyToRosterEntry or nil,
    getTime = ctx.getTime,
    shareKeysDebounceSeconds = ctx.shareKeysDebounceSeconds,
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
  })
  controller.BuildButtons()
  return {
    teleportUIController = controller,
    mplusTeleportButtons = controller.GetButtons(),
  }
end

function ControllerInit.CreateControllers(ctx)
  local result = {}

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

  return result
end
