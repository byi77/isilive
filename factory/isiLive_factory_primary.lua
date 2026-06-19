local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local InitializeFactoryCombatAnnounceControllers = FI.InitializeFactoryCombatAnnounceControllers
local InitializeFactoryDeathAlertControllers = FI.InitializeFactoryDeathAlertControllers
local InitializeFactoryLfgWiringControllers = FI.InitializeFactoryLfgWiringControllers

local FactoryNotices = FI.FactoryNotices or {}
local ShowJoinedTargetNotice = FactoryNotices.ShowJoinedTargetNotice
local InitializeInviteControllers = FactoryNotices.InitializeInviteControllers
local FactoryDemo = FI.FactoryDemo or {}

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
    getDeathSummaryForPlayer = ctx.GetDeathSummaryForPlayer,
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
    getCooldownFrameStartForRemaining = ctx.GetCooldownFrameStartForRemaining,
    applyCooldownFrameSafe = ctx.ApplyCooldownFrameSafe,
    getSpellTexture = function(spellID)
      local spellApi = rawget(_G, "C_Spell")
      if spellID and type(spellApi) == "table" and type(spellApi.GetSpellTexture) == "function" then
        return spellApi.GetSpellTexture(spellID)
      end
      return nil
    end,
    getDungeonName = function(mapID, localeTag)
      local db = rawget(_G, "IsiLiveDB")
      local activeLocale = (db and db.locale) or ctx.locale
      return modules.teleport.GetDungeonName(mapID, localeTag or activeLocale)
    end,
    getTime = rawget(_G, "GetTime"),
    shareKeysDebounceSeconds = 30,
    getTargetDungeonInfo = ctx.GetStatusTargetDungeonInfo,
    isInChallengeMode = function()
      return ctx.GetActiveChallengeMapID() ~= nil -- secret-value-ok: protected wrapper
    end,
    sendShareKeysRequest = function()
      return modules.sync.SendShareKeysRequest()
    end,
    isSyncUserKnown = function(name, realm)
      return modules.sync.IsUserKnown(name, realm)
    end,
    logRuntimeTrace = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil,
    logRuntimeTracef = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil,
    logRuntimeTraceDeep = ctx.runtimeLogController and ctx.runtimeLogController.TraceDeep or nil,
  })

  if type(modules.sync.SetTraceLogger) == "function" then
    modules.sync.SetTraceLogger(ctx.runtimeLogController and ctx.runtimeLogController.Trace or nil)
  end
  if type(modules.sync.SetDeepTraceLogger) == "function" then
    modules.sync.SetDeepTraceLogger(ctx.runtimeLogController and ctx.runtimeLogController.TraceDeep or nil)
  end
  if type(modules.sync.SetLogger) == "function" then
    modules.sync.SetLogger(nil)
  end
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
  ctx.RegisterVerifiedSyncAliasForRoster = initResult.registerVerifiedSyncAliasForRoster
  ctx.RecordRun = initResult.recordRun
  ctx.highlightController = initResult.highlightController
  ctx.rosterPanelController = initResult.rosterPanelController
  ctx.refreshButton = initResult.refreshButton
  ctx.countdownCancelButton = initResult.countdownCancelButton
  ctx.statusLine = initResult.statusLine
  ctx.TriggerShareKeysCooldown = initResult.triggerShareKeysCooldown
  ctx.GetShareKeysCooldownRemaining = initResult.getShareKeysCooldownRemaining
  ctx.GetShareKeysLocalCooldownRemaining = initResult.getShareKeysLocalCooldownRemaining
  ctx.ClearShareKeysCooldown = function()
    if ctx.rosterPanelController and type(ctx.rosterPanelController.ClearShareKeysCooldown) == "function" then
      ctx.rosterPanelController.ClearShareKeysCooldown()
    end
  end
  ctx.teleportUIController = initResult.teleportUIController
  ctx.mplusTeleportButtons = initResult.mplusTeleportButtons
  ctx.UpdateLeaderButtons = function()
    ctx.rosterPanelController.UpdateLeaderButtons()
  end
  ctx.ApplyPendingLeaderButtonUpdates = function()
    if ctx.rosterPanelController and type(ctx.rosterPanelController.ApplyPendingLeaderButtonUpdates) == "function" then
      ctx.rosterPanelController.ApplyPendingLeaderButtonUpdates()
    end
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
  InitializeFactoryLfgWiringControllers(ctx, modules)
  ctx.ShowJoinedTargetNotice = function()
    ShowJoinedTargetNotice(ctx, modules)
  end

  InitializeInviteControllers(ctx, modules)

  InitializeFactoryCombatAnnounceControllers(ctx)

  InitializeFactoryDeathAlertControllers(ctx)

  if type(FactoryDemo.InitializeSimulationTablet) == "function" then
    FactoryDemo.InitializeSimulationTablet(ctx)
  end
end

FI.InitializeFactoryPrimaryControllers = InitializeFactoryPrimaryControllers

return {
  InitializeFactoryPrimaryControllers = InitializeFactoryPrimaryControllers,
}
