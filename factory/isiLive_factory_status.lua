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
    local partyInfo = rawget(_G, "C_PartyInfo")
    if type(partyInfo) == "table" and type(partyInfo.DoCountdown) == "function" then
      pcall(partyInfo.DoCountdown, 0)
    end
  end)

  -- Rule 168: the inspect OnUpdate is attached only while processing is wanted
  -- (shown, grouped, no raid) AND the inspect controller holds work. An empty
  -- queue costs no per-frame call; EnqueueInspect re-attaches it.
  -- Deferred retries alone (members offline or out of range) do not keep the
  -- per-frame loop attached: the loop detaches and a one-shot timer re-attaches
  -- it when the earliest retry is due. Without a timer API the loop stays
  -- attached while retries wait, as before.
  local inspectLoopWanted = false
  local inspectLoopAttached = false
  local inspectWakeTimer = nil
  local inspectWakeAt = nil
  local inspectWakeGeneration = 0
  local RefreshInspectLoop
  local function CancelInspectWake()
    inspectWakeGeneration = inspectWakeGeneration + 1
    if inspectWakeTimer ~= nil and type(inspectWakeTimer.Cancel) == "function" then
      inspectWakeTimer:Cancel()
    end
    inspectWakeTimer = nil
    inspectWakeAt = nil
  end
  local function ScheduleInspectWake(delay)
    local timerApi = rawget(_G, "C_Timer")
    if type(timerApi) ~= "table" then
      return false
    end
    local getTimeFn = rawget(_G, "GetTime")
    local wakeAt = (type(getTimeFn) == "function" and tonumber(getTimeFn()) or 0) + delay
    if inspectWakeAt ~= nil and inspectWakeAt <= wakeAt then
      return true
    end
    CancelInspectWake()
    local generation = inspectWakeGeneration
    local function Wake()
      if generation ~= inspectWakeGeneration then
        return
      end
      inspectWakeTimer = nil
      inspectWakeAt = nil
      RefreshInspectLoop()
    end
    if type(timerApi.NewTimer) == "function" then
      inspectWakeTimer = timerApi.NewTimer(delay, Wake)
    elseif type(timerApi.After) == "function" then
      timerApi.After(delay, Wake)
    else
      return false
    end
    inspectWakeAt = wakeAt
    return true
  end
  local function HasInspectWork()
    local controller = ctx.inspectController
    if type(controller) ~= "table" or type(controller.HasPendingWork) ~= "function" then
      return true
    end
    if controller.HasPendingWork() ~= true then
      return false
    end
    if type(controller.HasDueWork) ~= "function" or type(controller.GetNextRetryDelay) ~= "function" then
      return true
    end
    if controller.HasDueWork() == true then
      return true
    end
    local delay = controller.GetNextRetryDelay()
    return delay == nil or not ScheduleInspectWake(delay)
  end
  RefreshInspectLoop = function()
    local attach = inspectLoopWanted and HasInspectWork()
    if attach == inspectLoopAttached then
      return
    end
    inspectLoopAttached = attach
    ctx.mainFrame:SetScript("OnUpdate", attach and ctx.InspectLoop or nil)
  end

  local function SetProcessingActive(isActive)
    local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
    if logf then
      logf("[UI] processing_active isActive=%s", tostring(isActive))
    end
    local grouped = ctx.isInGroup() or ctx.isInInstanceGroup()
    if isActive and grouped and not ctx.IsRaidGroup() then
      inspectLoopWanted = true
      RefreshInspectLoop()
      return
    end

    inspectLoopWanted = false
    inspectLoopAttached = false
    CancelInspectWake()
    ctx.mainFrame:SetScript("OnUpdate", nil)
    ctx.inspectController.ResetQueues()
  end

  local statusController = modules.status.CreateController({
    getL = ctx.GetL,
    getLocaleTag = function()
      return ctx.locale
    end,
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
  ctx.RefreshInspectLoop = RefreshInspectLoop
end

FI.InitializeFactoryRefreshAndStatusControllers = InitializeFactoryRefreshAndStatusControllers

return {
  InitializeFactoryRefreshAndStatusControllers = InitializeFactoryRefreshAndStatusControllers,
}
