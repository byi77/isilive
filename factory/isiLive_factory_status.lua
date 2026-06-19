local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local InitializeFactoryLocalizationControllers = FI.InitializeFactoryLocalizationControllers
local InitializeFactoryRefreshControllers = FI.InitializeFactoryRefreshControllers

local FactoryNotices = FI.FactoryNotices or {}
local HandleTargetDungeonChatPayload = FactoryNotices.HandleTargetDungeonChatPayload

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

  InitializeFactoryLocalizationControllers(ctx, modules)

  ctx.countdownCancelButton:SetScript("OnClick", function()
    if not ctx.IsPlayerLeader() then
      return
    end
    if C_PartyInfo and C_PartyInfo.DoCountdown then
      pcall(C_PartyInfo.DoCountdown, 0)
    end
  end)

  local function SetProcessingActive(isActive)
    local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
    if logf then
      logf("[UI] processing_active isActive=%s", tostring(isActive))
    end
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
    getTeleportInfoByMapID = modules.teleport and modules.teleport.GetTeleportInfoByMapID or nil,
    timerAfter = function(seconds, callback)
      local timer = rawget(_G, "C_Timer")
      if type(timer) == "table" and type(timer.After) == "function" then
        timer.After(seconds, function()
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
    -- Chat-announce gate: ResolveLocalStatusTargetMapID is non-nil only
    -- when the local player has an own queue, an active joined key, or
    -- a fresh LFG accept (detectedMapID via LFGDetect). A synced-only
    -- target, one that comes purely from another member's published
    -- snapshot, does not light up the local resolver and must not
    -- trigger a chat announce, even though the status frame still
    -- surfaces it as informational.
    hasLocalTargetSource = function()
      if type(ctx.ResolveLocalStatusTargetMapID) ~= "function" then
        return false
      end
      local localMapID = ctx.ResolveLocalStatusTargetMapID()
      return type(localMapID) == "number" and localMapID > 0
    end,
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
    printHighlighted = ctx.PrintHighlighted,
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

  -- Direct-push: route the LFG-accept payload (mapID + listing titleLevel)
  -- straight to the status controller's AnnounceTargetDungeonFromPayload
  -- entry point. The chat line then renders with exactly the same "+N"
  -- the Center Notice already drew from entry.titleLevel; the resolver
  -- chain inside MaybeAnnounceTargetDungeonChat is skipped for this path
  -- so race conditions on the LFG-title hint / roster-owner / synced-
  -- target sources cannot surface a wrong "+N" anymore. The
  -- levelAnnouncedTargetDungeonName lock-in is set as a side effect of
  -- EmitTargetDungeonAnnouncement, so the subsequent
  -- UpdateStatusLine-driven re-evaluation stays silent.
  --
  -- No IsInGroup gate: the LFG_LIST_APPLICATION_STATUS_UPDATED=inviteaccepted
  -- event fires before the matching GROUP_ROSTER_UPDATE, so IsInGroup() can
  -- transiently return false in this window (see isiLive_lfg_detect.lua's
  -- "ClearDetectedState" guard which explicitly documents the same race).
  -- The Center Notice path has no such gate and surfaces correctly; the
  -- chat line is a local print() (not SendChatMessage), so there is no
  -- protocol-level reason to require group membership for the announce.
  local lfgDetectForChat = addonTable.LFGDetect
  if type(lfgDetectForChat) == "table" and type(lfgDetectForChat.SetTargetDungeonChatCallback) == "function" then
    lfgDetectForChat.SetTargetDungeonChatCallback(function(payload)
      HandleTargetDungeonChatPayload(ctx, modules, statusController, payload)
    end)
  end

  InitializeFactoryRefreshControllers(ctx, modules, runtimeState)

  ctx.SetProcessingActive = SetProcessingActive
end

FI.InitializeFactoryRefreshAndStatusControllers = InitializeFactoryRefreshAndStatusControllers

return {
  InitializeFactoryRefreshAndStatusControllers = InitializeFactoryRefreshAndStatusControllers,
}
