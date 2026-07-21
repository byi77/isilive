local _, addonTable = ...
addonTable = addonTable or {}

local Factory = {}
addonTable.Factory = Factory

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI
local CreateFactoryContext = FI.CreateFactoryContext
local InitializeFactoryFrameBridge = FI.InitializeFactoryFrameBridge
local InitializeFactoryRuntimeHelpers = FI.InitializeFactoryRuntimeHelpers
local InitializeFactoryPrimaryControllers = FI.InitializeFactoryPrimaryControllers
local InitializeFactoryRefreshAndStatusControllers = FI.InitializeFactoryRefreshAndStatusControllers
local InitializeFactorySecondaryControllers = FI.InitializeFactorySecondaryControllers
local CreateFactoryMinimapButton = FI.CreateFactoryMinimapButton

-- Auto-close when the M+ keystone starts. Default OFF: only an explicit
-- user-enabled boolean true may close the main UI on key start.
local function ResolveAutoCloseOnKeyStartEnabled(dbRef)
  return type(dbRef) == "table" and dbRef.autoCloseOnKeyStart == true
end

local function ResolveAutoCloseOnSoloChangeEnabled(dbRef)
  return type(dbRef) == "table" and dbRef.autoCloseOnSoloChange == true
end

local function ResolveAutoShowMainFrameOnStartupEnabled(dbRef)
  return not (type(dbRef) == "table" and dbRef.autoShowMainFrameOnStartup == false)
end

local function ResolveAutoOpenMainFrameOnKeyEndEnabled(dbRef)
  return not (type(dbRef) == "table" and dbRef.autoOpenMainFrameOnKeyEnd == false)
end

local function ResolveMainFramePositionLockEnabled(dbRef)
  return not (type(dbRef) == "table" and dbRef.lockMainFramePosition == false)
end

local function ResolveRaidTransitionBehavior(dbRef)
  if type(dbRef) ~= "table" then
    return "hide"
  end

  return "hide"
end

local function ResetMainFrameDefaults(ctx)
  local uiCommon = ctx.addonTable and ctx.addonTable.UICommon
  local defaultBgAlpha = uiCommon and uiCommon.DEFAULT_BG_ALPHA or 0.50
  -- onResetMainFramePosition is wired to the settings panel, which only opens
  -- after ADDON_LOADED, so IsiLiveDB is always restored by the time we get
  -- here. Lazy-allocating it pre-load would race the SavedVariables restore
  -- and wipe other settings, so skip persistence when the DB is missing and
  -- still apply the in-memory UI resets below.
  local db = rawget(_G, "IsiLiveDB")
  if type(db) == "table" then
    db.uiScale = 1.0
    db.bgAlpha = defaultBgAlpha
  end

  local mainFrame = ctx.mainFrame
  if mainFrame and type(mainFrame.SetScale) == "function" then
    mainFrame:SetScale(1.0)
  end

  local mainUI = ctx.mainUI
  if mainUI and type(mainUI.ResetPosition) == "function" then
    mainUI.ResetPosition()
  end

  if type(uiCommon) == "table" and type(uiCommon.ApplyBgAlpha) == "function" then
    uiCommon.ApplyBgAlpha({
      mainFrame = mainFrame,
      panelFrame = ctx.panelUI and ctx.panelUI.panelFrame,
      settingsCanvas = ctx.settingsPanel and ctx.settingsPanel.canvas,
    }, defaultBgAlpha)
  end

  if ctx.settingsPanel and type(ctx.settingsPanel.Refresh) == "function" then
    ctx.settingsPanel.Refresh()
  end
end

FI.ResolveAutoCloseOnKeyStartEnabled = ResolveAutoCloseOnKeyStartEnabled
FI.ResolveAutoCloseOnSoloChangeEnabled = ResolveAutoCloseOnSoloChangeEnabled
FI.ResolveAutoShowMainFrameOnStartupEnabled = ResolveAutoShowMainFrameOnStartupEnabled
FI.ResolveAutoOpenMainFrameOnKeyEndEnabled = ResolveAutoOpenMainFrameOnKeyEndEnabled
FI.ResolveMainFramePositionLockEnabled = ResolveMainFramePositionLockEnabled
FI.ResolveRaidTransitionBehavior = ResolveRaidTransitionBehavior

local function FinalizeFactorySettings(ctx)
  local modules = ctx.modules

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
      onEscPanelToggle = function(_enabled)
        if ctx.panelUI and type(ctx.panelUI.SyncVisibility) == "function" then
          ctx.panelUI.SyncVisibility()
        end
        if ctx.secondPanelUI and type(ctx.secondPanelUI.SyncVisibility) == "function" then
          ctx.secondPanelUI.SyncVisibility()
        end
        if ctx.mountPanelUI and type(ctx.mountPanelUI.SyncVisibility) == "function" then
          ctx.mountPanelUI.SyncVisibility()
        end
        if ctx.thirdPanelUI and type(ctx.thirdPanelUI.SyncVisibility) == "function" then
          ctx.thirdPanelUI.SyncVisibility()
        end
      end,
      getQueueDebugEnabled = function()
        if ctx.queueDebugController and type(ctx.queueDebugController.IsEnabled) == "function" then
          return ctx.queueDebugController.IsEnabled()
        end
        return false
      end,
      onQueueDebugToggle = function(enabled)
        if ctx.queueDebugController and type(ctx.queueDebugController.SetEnabled) == "function" then
          ctx.queueDebugController.SetEnabled(enabled)
        end
      end,
      getRuntimeLogEnabled = function()
        if ctx.runtimeLogController and type(ctx.runtimeLogController.IsEnabled) == "function" then
          return ctx.runtimeLogController.IsEnabled()
        end
        return false
      end,
      onRuntimeLogToggle = function(enabled)
        if ctx.runtimeLogController and type(ctx.runtimeLogController.SetEnabled) == "function" then
          ctx.runtimeLogController.SetEnabled(enabled)
        end
      end,
      onClearRuntimeLog = function()
        if type(ctx.clearRuntimeLog) == "function" then
          ctx.clearRuntimeLog()
        end
      end,
      onClearQueueDebugLog = function()
        if type(ctx.clearQueueDebugLog) == "function" then
          ctx.clearQueueDebugLog()
        end
      end,
      onPortalNavigatorToggle = function(_enabled)
        if ctx.statusController and type(ctx.statusController.MaybeShowPortalNavigatorNotice) == "function" then
          ctx.statusController.MaybeShowPortalNavigatorNotice()
        end
      end,
      onHearthstoneChoiceChange = function()
        if ctx.panelUI and type(ctx.panelUI.SyncVisibility) == "function" then
          ctx.panelUI.SyncVisibility()
        end
        if ctx.secondPanelUI and type(ctx.secondPanelUI.SyncVisibility) == "function" then
          ctx.secondPanelUI.SyncVisibility()
        end
      end,
      onBgAlphaChange = function(val)
        local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
        if logf then
          logf("[SETTINGS] bg_alpha val=%s", tostring(val))
        end
        local uiCommon = ctx.addonTable and ctx.addonTable.UICommon
        if type(uiCommon) == "table" and type(uiCommon.ApplyBgAlpha) == "function" then
          uiCommon.ApplyBgAlpha({
            mainFrame = ctx.mainFrame,
            panelFrame = ctx.panelUI and ctx.panelUI.panelFrame,
            settingsCanvas = ctx.settingsPanel and ctx.settingsPanel.canvas,
          }, val)
        end
      end,
      onStatsBoxToggle = function(enabled)
        local statsBox = ctx.addonTable and ctx.addonTable.StatsBox
        if type(statsBox) == "table" and type(statsBox.SetEnabled) == "function" then
          statsBox.SetEnabled(enabled)
        end
      end,
      onStatsBoxLockToggle = function(locked)
        local statsBox = ctx.addonTable and ctx.addonTable.StatsBox
        if type(statsBox) == "table" and type(statsBox.SetLocked) == "function" then
          statsBox.SetLocked(locked)
        end
      end,
      onStatsBoxBgAlphaChange = function(val)
        local statsBox = ctx.addonTable and ctx.addonTable.StatsBox
        if type(statsBox) == "table" and type(statsBox.SetBackgroundAlpha) == "function" then
          statsBox.SetBackgroundAlpha(val)
        end
      end,
      onStatsBoxFontSizeOffsetChange = function(offset)
        local statsBox = ctx.addonTable and ctx.addonTable.StatsBox
        if type(statsBox) == "table" and type(statsBox.SetFontSizeOffset) == "function" then
          statsBox.SetFontSizeOffset(offset)
        end
      end,
      onStatsBoxOptionsChange = function()
        local statsBox = ctx.addonTable and ctx.addonTable.StatsBox
        if type(statsBox) == "table" and type(statsBox.ApplySettings) == "function" then
          statsBox.ApplySettings()
        end
      end,
      onUiScaleChange = function(val)
        local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
        if logf then
          logf("[SETTINGS] ui_scale val=%s", tostring(val))
        end
        if ctx.mainFrame and type(ctx.mainFrame.SetScale) == "function" then
          ctx.mainFrame:SetScale(val)
        end
      end,
      onSyncToggle = function(_enabled)
        -- Runtime reads IsiLiveDB.syncEnabled directly; no additional action needed
      end,
      onRosterColumnGuidesToggle = function(_enabled)
        if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshLayoutState) == "function" then
          ctx.rosterPanelController.RefreshLayoutState()
        elseif ctx.rosterPanelController and type(ctx.rosterPanelController.RenderRoster) == "function" then
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
      onAutoCloseOnKeyStartToggle = function(_enabled)
        -- Runtime reads IsiLiveDB.autoCloseOnKeyStart directly; no action needed.
      end,
      onAutoCloseOnSoloChangeToggle = function(_enabled)
        -- Runtime reads IsiLiveDB.autoCloseOnSoloChange directly; no action needed.
      end,
      onMainFramePositionLockToggle = function(enabled)
        if ctx.mainUI and type(ctx.mainUI.SetDragLocked) == "function" then
          ctx.mainUI.SetDragLocked(enabled)
        end
      end,
      onResetMainFramePosition = function()
        ResetMainFrameDefaults(ctx)
      end,
      onCombatFadeMMToggle = function(_enabled)
        -- Runtime reads IsiLiveDB.combatFadeMM directly; no additional action needed.
      end,
      onAutoShowMainFrameOnStartupToggle = function(_enabled)
        -- Runtime reads IsiLiveDB.autoShowMainFrameOnStartup directly; no additional action needed.
      end,
      onAutoOpenMainFrameOnKeyEndToggle = function(_enabled)
        -- Runtime reads IsiLiveDB.autoOpenMainFrameOnKeyEnd directly; no additional action needed.
      end,
      onRaidTransitionBehaviorChange = function(_behavior)
        -- Runtime reads IsiLiveDB.raidTransitionBehavior directly; no additional action needed.
      end,
      onDefaultLayoutModeChange = function(_layoutMode)
        ctx.RestoreLayoutState()
      end,
      onNameMaxCharsChange = function(_maxChars)
        if ctx.rosterPanelController and type(ctx.rosterPanelController.RenderRoster) == "function" then
          ctx.rosterPanelController.RenderRoster(ctx.GetRoster())
        end
      end,
      onTeleportColumnsChange = function(_columns)
        if ctx.teleportUIController and type(ctx.teleportUIController.UpdateButtons) == "function" then
          ctx.UpdateMPlusTeleportButton()
        end
      end,
      onLfgFlagsToggle = function(enabled)
        local lfgFlags = ctx.addonTable and ctx.addonTable.LFGFlags
        if type(lfgFlags) == "table" and type(lfgFlags.SetEnabled) == "function" then
          lfgFlags.SetEnabled(enabled)
        end
      end,
      onLfgGroupBonusesToggle = function(enabled)
        local lfgFlags = ctx.addonTable and ctx.addonTable.LFGFlags
        if type(lfgFlags) == "table" and type(lfgFlags.SetGroupBonusesEnabled) == "function" then
          lfgFlags.SetGroupBonusesEnabled(enabled)
        end
        if ctx.rosterPanelController and type(ctx.rosterPanelController.RenderRoster) == "function" then
          ctx.rosterPanelController.RenderRoster(ctx.GetRoster())
        end
      end,
      onTooltipFlagsToggle = function(enabled)
        local rosterUI = ctx.addonTable and ctx.addonTable.RosterUI
        if type(rosterUI) == "table" and type(rosterUI.SetTooltipFlagsEnabled) == "function" then
          rosterUI.SetTooltipFlagsEnabled(enabled)
        end
      end,
      onMplusForcesToggle = function(enabled)
        local mobTooltip = ctx.addonTable and ctx.addonTable.MobTooltip
        if type(mobTooltip) == "table" and type(mobTooltip.SetEnabled) == "function" then
          mobTooltip.SetEnabled(enabled)
        end
      end,
      onMobNameplateChange = function()
        local mobNameplate = ctx.addonTable and ctx.addonTable.MobNameplate
        if type(mobNameplate) ~= "table" then
          return
        end
        local db = rawget(_G, "IsiLiveDB") or {}
        if type(mobNameplate.SetFormat) == "function" then
          mobNameplate.SetFormat({
            showPercent = db.mobNameplateShowPercent ~= false,
            showRemaining = db.mobNameplateShowRemaining == true,
          })
        end
        if type(mobNameplate.SetAppearance) == "function" then
          mobNameplate.SetAppearance({
            fontSize = tonumber(db.mobNameplateFontSize) or 14,
            position = type(db.mobNameplatePosition) == "string" and db.mobNameplatePosition or "RIGHT",
            xOffset = tonumber(db.mobNameplateXOffset) or 0,
            yOffset = tonumber(db.mobNameplateYOffset) or 0,
          })
        end
        if type(mobNameplate.SetEnabled) == "function" then
          mobNameplate.SetEnabled(db.mobNameplateEnabled == true)
        end
      end,
      onResetDB = function()
        ctx.resetDB()
      end,
    })

    -- Apply initial DB values for flag features and re-apply them on every
    -- ADDON_LOADED. The first invocation (here, at file-load time) runs
    -- BEFORE the WoW SavedVariables loader has restored IsiLiveDB, so it
    -- only sees nil values and writes defaults into a local table. The
    -- second invocation, dispatched from event_handlers_runtime when
    -- ADDON_LOADED fires, reads the now-restored IsiLiveDB and re-applies
    -- the user's actual saved values to MobNameplate/MobTooltip/LFGFlags/
    -- RosterInternal — without this re-apply step, the modules stay locked
    -- to the file-load defaults regardless of what the user saved last
    -- session.
    ctx.ApplyDBSettings = function()
      local db = IsiLiveDB or {}

      -- Legacy cascade fix: pre-nameplate users only ever persisted
      -- mplusForcesEstimate=true. DBSchema.Sanitize now fills the schema
      -- default mobNameplateEnabled=true before this runs, so both flags
      -- end up true and the nameplate + tooltip modules both activate.
      -- The settings UI enforces mutual exclusion (only one of the two
      -- can become true via the display-mode selector), so both=true is
      -- only reachable from the legacy path. Disambiguate to tooltip-only
      -- to honour the user's prior choice.
      if db.mobNameplateEnabled == true and db.mplusForcesEstimate == true then
        db.mobNameplateEnabled = false
      end

      -- Fallback for callers that exercise ApplyDBSettings without the
      -- ADDON_LOADED schema pass. Production migration runs in DBSchema
      -- before default values fill the split fields.
      if db.autoCloseMainFrame == true and db.autoCloseOnKeyStart == nil and db.autoCloseOnSoloChange == nil then
        db.autoCloseOnKeyStart = true
        db.autoCloseOnSoloChange = true
        db.autoCloseMainFrame = false
      end

      -- M+ forces display-mode migration: if mobNameplateEnabled has never
      -- been set, default to "nameplate" mode. This covers fresh installs
      -- AND legacy users whose only persisted key was mplusForcesEstimate
      -- (the pre-nameplate tooltip-only era). The three display modes are
      -- mutually exclusive in the settings UI, so mplusForcesEstimate is
      -- forced off here to avoid both modules running in parallel.
      if db.mobNameplateEnabled == nil then
        db.mobNameplateEnabled = true
        db.mplusForcesEstimate = false
      end

      -- Persist sensible nameplate defaults into the DB on first run. Without
      -- this the slider / position selector / X+Y offsets show "nil" as their
      -- initial state until the user manually nudges each control.
      if db.mobNameplateShowPercent == nil then
        db.mobNameplateShowPercent = true
      end
      if db.mobNameplateRemainingDefaultMigrated ~= true then
        if db.mobNameplateShowRemaining == true then
          db.mobNameplateShowRemaining = false
        end
        db.mobNameplateRemainingDefaultMigrated = true
      end
      if db.mobNameplateShowRemaining == nil then
        db.mobNameplateShowRemaining = false
      end
      if db.mobNameplateFontSize == nil then
        db.mobNameplateFontSize = 14
      end
      if db.mobNameplatePosition == nil then
        db.mobNameplatePosition = "RIGHT"
      end
      if db.mobNameplateXOffset == nil then
        db.mobNameplateXOffset = 0
      end
      if db.mobNameplateYOffset == nil then
        db.mobNameplateYOffset = 0
      end
      if db.lfgGroupBonusesEnabled == nil then
        db.lfgGroupBonusesEnabled = true
      end

      if not IsiLiveDB then
        IsiLiveDB = db
      end

      local lfgFlags = ctx.addonTable and ctx.addonTable.LFGFlags
      if type(lfgFlags) == "table" and type(lfgFlags.SetEnabled) == "function" then
        lfgFlags.SetEnabled(db.lfgFlagsEnabled ~= false)
      end
      if type(lfgFlags) == "table" and type(lfgFlags.SetGroupBonusesEnabled) == "function" then
        lfgFlags.SetGroupBonusesEnabled(db.lfgGroupBonusesEnabled ~= false)
      end
      local rosterUI = ctx.addonTable and ctx.addonTable.RosterUI
      if type(rosterUI) == "table" and type(rosterUI.SetTooltipFlagsEnabled) == "function" then
        rosterUI.SetTooltipFlagsEnabled(db.tooltipFlagsEnabled ~= false)
      end
      local mobTooltip = ctx.addonTable and ctx.addonTable.MobTooltip
      if type(mobTooltip) == "table" then
        if type(mobTooltip.SetLocaleGetter) == "function" and type(ctx.GetL) == "function" then
          mobTooltip.SetLocaleGetter(ctx.GetL)
        end
        if type(mobTooltip.Register) == "function" then
          mobTooltip.Register()
        end
        if type(mobTooltip.SetEnabled) == "function" then
          mobTooltip.SetEnabled(db.mplusForcesEstimate == true)
        end
      end

      local mobNameplate = ctx.addonTable and ctx.addonTable.MobNameplate
      if type(mobNameplate) == "table" then
        if type(mobNameplate.SetFormat) == "function" then
          mobNameplate.SetFormat({
            showPercent = db.mobNameplateShowPercent ~= false,
            showRemaining = db.mobNameplateShowRemaining == true,
          })
        end
        if type(mobNameplate.SetAppearance) == "function" then
          mobNameplate.SetAppearance({
            fontSize = tonumber(db.mobNameplateFontSize) or 14,
            position = type(db.mobNameplatePosition) == "string" and db.mobNameplatePosition or "RIGHT",
            xOffset = tonumber(db.mobNameplateXOffset) or 0,
            yOffset = tonumber(db.mobNameplateYOffset) or 0,
          })
        end
        if type(mobNameplate.Register) == "function" then
          mobNameplate.Register()
        end
        if type(mobNameplate.SetEnabled) == "function" then
          mobNameplate.SetEnabled(db.mobNameplateEnabled == true)
        end
      end

      local statsBox = ctx.addonTable and ctx.addonTable.StatsBox
      if type(statsBox) == "table" and type(statsBox.ApplySettings) == "function" then
        statsBox.ApplySettings()
      end
    end

    ctx.ApplyDBSettings()
  end

  -- Minimap Button: create with correct initial visibility so MinimapButtonButton
  -- sees the right shown-state when it scans on PLAYER_LOGIN.
  -- IsiLiveDB is already populated from SavedVariables at file-load time.
  -- Create always hidden; ADDON_LOADED handler shows it if the setting is enabled.
  -- SavedVariables (IsiLiveDB) are not yet available at file-load time.
  ctx.minimapButton = CreateFactoryMinimapButton(ctx)
  if ctx.minimapButton then
    ctx.minimapButton:Hide()
  end
end

local function BuildRuntimeSetupGroupContext(ctx, runtimeState)
  return {
    sync = ctx.modules.sync,
    isInGroup = IsInGroup,
    getNumGroupMembers = GetNumGroupMembers,
    getActiveChallengeMapID = ctx.GetActiveChallengeMapID,
    getWasInGroup = ctx.GetWasInGroup,
    setWasInGroup = ctx.SetWasInGroup,
    getWasRaidGroup = ctx.GetWasRaidGroup,
    setWasRaidGroup = ctx.SetWasRaidGroup,
    isRosterCollapsed = ctx.IsRosterCollapsed,
    setWasGroupLeader = ctx.SetWasGroupLeader,
    getRoster = ctx.GetRoster,
    setRoster = ctx.SetRoster,
    captureQueueJoinCandidate = ctx.CaptureQueueJoinCandidate,
    announceQueuedGroupJoin = ctx.AnnounceQueuedGroupJoin,
    setMainFrameVisible = ctx.SetMainFrameVisible,
    isMainFrameVisible = ctx.IsMainFrameVisible,
    updateLeaderButtons = ctx.UpdateLeaderButtons,
    clearLatestQueueTarget = ctx.ClearLatestQueueTarget,
    clearRioBaselineSnapshot = ctx.ClearRioBaselineSnapshot,
    clearPendingQueueJoinInfo = function()
      runtimeState.SetPendingQueueJoinInfo(nil)
    end,
    onGroupJoined = function()
      if type(ctx.ShowJoinedTargetNotice) == "function" then
        ctx.ShowJoinedTargetNotice()
      end
    end,
    resetInspectAll = ctx.ResetInspectAll,
    resetInspectQueues = ctx.ResetInspectQueues,
    updateUI = ctx.UpdateUI,
    updateMPlusTeleportButton = ctx.UpdateMPlusTeleportButton,
    getUnitNameAndRealm = ctx.GetUnitNameAndRealm,
    getUnitClass = ctx.GetUnitClass,
    getUnitServerLanguage = ctx.GetUnitServerLanguage,
    getOwnedKeystoneSnapshot = ctx.GetOwnedKeystoneSnapshot,
    markIsiLiveUser = ctx.MarkIsiLiveUser,
    getUnitRole = ctx.GetUnitRole,
    getPlayerSpecName = ctx.GetPlayerSpecName,
    getUnitRio = ctx.GetUnitRio,
    getOwnAverageItemLevel = ctx.GetOwnAverageItemLevel,
    unitHasIsiLive = ctx.UnitHasIsiLive,
    applyKnownKeyToRosterEntry = ctx.ApplyKnownKeyToRosterEntry,
    enqueueInspect = ctx.EnqueueInspect,
    sendOwnKeySnapshot = ctx.SendOwnKeySnapshot,
    sendIsiLiveHello = ctx.SendIsiLiveHello,
    sendRefreshRequest = ctx.SendRefreshRequest,
    getReloadRosterMirror = function()
      local dbRef = rawget(_G, "IsiLiveDB")
      return type(dbRef) == "table" and dbRef.reloadRosterMirror or nil
    end,
    setReloadRosterMirror = function(snapshot)
      local dbRef = rawget(_G, "IsiLiveDB")
      if type(dbRef) == "table" then
        dbRef.reloadRosterMirror = snapshot
      end
    end,
    clearReloadRosterMirror = function()
      local dbRef = rawget(_G, "IsiLiveDB")
      if type(dbRef) == "table" then
        dbRef.reloadRosterMirror = {}
      end
    end,
    getReloadRosterTargetSnapshot = ctx.GetReloadRosterTargetSnapshot,
    restoreReloadRosterTargetSnapshot = ctx.RestoreReloadRosterTargetSnapshot,
    shouldAutoCloseOnSoloChange = function()
      local dbRef = rawget(_G, "IsiLiveDB")
      return ResolveAutoCloseOnSoloChangeEnabled(dbRef)
    end,
    getRaidTransitionBehavior = function()
      local dbRef = rawget(_G, "IsiLiveDB")
      return ResolveRaidTransitionBehavior(dbRef)
    end,
    autoCloseMainFrame = function()
      if ctx.mainFrame:IsShown() then
        ctx.SetMainFrameVisible(false)
      end
    end,
    unitIsGroupLeader = function(unit)
      if type(unit) ~= "string" or unit == "" then
        return false
      end

      local unitExists = rawget(_G, "UnitExists")
      if type(unitExists) ~= "function" then
        return false
      end

      local okExists, exists = pcall(unitExists, unit)
      if not okExists or not exists then
        return false
      end

      local unitIsGroupLeader = rawget(_G, "UnitIsGroupLeader")
      if type(unitIsGroupLeader) ~= "function" then
        return false
      end

      local okLeader, isLeader = pcall(unitIsGroupLeader, unit)
      return okLeader and isLeader == true
    end,
    runtimeLogController = ctx.runtimeLogController,
    getL = ctx.GetL,
    printFn = ctx.Print,
  }
end

local function BuildRuntimeSetupLeaderWatchContext(ctx, runtimeState)
  return {
    isPlayerLeader = ctx.IsPlayerLeader,
    getWasGroupLeader = ctx.GetWasGroupLeader,
    setWasGroupLeader = ctx.SetWasGroupLeader,
    isStopped = runtimeState.IsStopped,
    isMainFrameShown = function()
      return ctx.mainFrame and ctx.mainFrame:IsShown()
    end,
    showCenterNotice = ctx.ShowCenterNotice,
    printFn = ctx.Print,
    getL = ctx.GetL,
    updateLeaderButtons = ctx.UpdateLeaderButtons,
    runtimeLogController = ctx.runtimeLogController,
  }
end

local function BuildRuntimeSetupSlashCommandsContext(ctx, runtimeState)
  return {
    commands = ctx.modules.commands,
    printFn = ctx.Print,
    getL = ctx.GetL,
    getState = runtimeState.GetRuntimeFlags,
    setState = runtimeState.PatchRuntimeFlags,
    triggerGroupRosterUpdate = ctx.TriggerGroupRosterUpdate,
    toggleStandardTestMode = ctx.ToggleStandardTestMode,
    enterFullDummyPreview = ctx.EnterFullDummyPreview,
    toggleSimulationTablet = ctx.ToggleSimulationTablet,
    setMainFrameVisible = ctx.SetMainFrameVisible,
    mainFrame = ctx.mainFrame,
    mainUI = ctx.mainUI,
    panelUI = ctx.panelUI,
    settingsPanel = ctx.settingsPanel,
    updateLeaderButtons = ctx.UpdateLeaderButtons,
    isPlayerLeader = ctx.IsPlayerLeader,
    setLanguage = ctx.SetLanguage,
    teleportDebugController = ctx.teleportDebugController,
    queueDebugController = ctx.queueDebugController,
    traceChatFrameController = ctx.traceChatFrameController,
    runtimeLogController = ctx.runtimeLogController,
    resetDB = ctx.resetDB,
    logRuntimeTrace = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil,
    logRuntimeTracef = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil,
  }
end

local function BuildRuntimeSetupGateContext(ctx, runtimeState)
  return {
    events = ctx.modules.events,
    onEvent = ctx.OnEvent,
    onDispatchError = function(_frame, event, err)
      ctx.Print(string.format("Event dispatch failed (%s): %s", tostring(event), tostring(err)))
    end,
    isStopped = runtimeState.IsStopped,
    isPaused = runtimeState.IsPaused,
    isTestMode = runtimeState.IsTestMode,
    isInCombat = ctx.IsInCombat,
    isMainFrameShown = function()
      return ctx.mainFrame and ctx.mainFrame:IsShown()
    end,
  }
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
    logRuntimeTrace = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil,
    logRuntimeTracef = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil,
    logRuntimeTracefDeep = ctx.runtimeLogController and ctx.runtimeLogController.LogfDeep or nil,
  })
  ctx.OnEvent = function(self, event, ...)
    ctx.eventHandlersController.Dispatch(self, event, ...)
  end
  ctx.InspectLoop = function(_self, elapsed)
    ctx.inspectLoopTimer = ctx.inspectLoopTimer + (elapsed or 0)
    if ctx.inspectLoopTimer >= 0.25 then
      ctx.inspectLoopTimer = 0
      -- Inspects are rate-limited to one per second internally; the only real
      -- cost is the NotifyInspect call. Pause during combat to avoid frame
      -- impact on pulls, but keep dispatching during dungeon downtime so a
      -- /reload mid-key can populate ilvl/RIO/spec without waiting for the
      -- key to end.
      local inCombatFn = rawget(_G, "InCombatLockdown")
      if type(inCombatFn) == "function" and inCombatFn() then
        return
      end
      ctx.inspectController.OnUpdate()
    end
  end

  ctx.resetDB = function()
    local reloadUI = rawget(_G, "ReloadUI")
    IsiLiveDB = nil
    ctx.Print((ctx.GetL() or {}).RESET_DB_DONE or "Settings reset. Reloading UI...")
    if type(reloadUI) == "function" then
      reloadUI()
    end
  end

  ctx.eventFrame = CreateFrame("Frame")
  ctx.eventFrame:SetScript("OnEvent", ctx.OnEvent)
  modules.bootstrap.RegisterDispatcherEvents(ctx.eventFrame)
  modules.bootstrap.BindMainFrameScripts(ctx.mainFrame, {
    onShow = function()
      ctx.SetProcessingActive(true)
      if ctx.rosterPanelController and ctx.rosterPanelController.RefreshSystemOptionToggles then
        ctx.rosterPanelController.RefreshSystemOptionToggles()
      end
      if IsInGroup() and ctx.SendOwnKeySnapshot then
        ctx.SendOwnKeySnapshot(true, "show")
      end
    end,
    onHide = function()
      ctx.SetProcessingActive(false)
    end,
  })

  -- This is the explicit adapter surface consumed by ControllerWiring.
  -- Keep it separate from RuntimeSetup's own small composition context so a
  -- missing dependency cannot be masked by falling back to the factory root.
  local eventHandlersContext = {
    modules = ctx.modules,
    HandleKickTrackerEvent = ctx.HandleKickTrackerEvent,
    GetReadyCheckReadyUntil = ctx.GetReadyCheckReadyUntil,
    SetReadyCheckReadyUntil = ctx.SetReadyCheckReadyUntil,
    ClearAllReadyCheckReady = ctx.ClearAllReadyCheckReady,
    ClearExpiredReadyCheckReady = ctx.ClearExpiredReadyCheckReady,
    GetReadyCheckDeclinedUntil = ctx.GetReadyCheckDeclinedUntil,
    SetReadyCheckDeclinedUntil = ctx.SetReadyCheckDeclinedUntil,
    ClearAllReadyCheckDeclined = ctx.ClearAllReadyCheckDeclined,
    ClearExpiredReadyCheckDeclined = ctx.ClearExpiredReadyCheckDeclined,
    ShowCombatAnnounce = ctx.ShowCombatAnnounce,
    TriggerShareKeysCooldown = ctx.TriggerShareKeysCooldown,
    GetShareKeysCooldownRemaining = ctx.GetShareKeysCooldownRemaining,
    GetShareKeysLocalCooldownRemaining = ctx.GetShareKeysLocalCooldownRemaining,
    RestoreBgAlpha = ctx.RestoreBgAlpha,
    UpdateCdTracker = ctx.UpdateCdTracker,
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
    isRaidGroup = ctx.IsRaidGroup,
    setWasGroupLeader = ctx.SetWasGroupLeader,
    getWasGroupLeader = ctx.GetWasGroupLeader,
    getRoster = ctx.GetRoster,
    setRoster = ctx.SetRoster,
    captureQueueJoinCandidate = ctx.CaptureQueueJoinCandidate,
    announceQueuedGroupJoin = ctx.AnnounceQueuedGroupJoin,
    setMainFrameVisible = ctx.SetMainFrameVisible,
    isMainFrameVisible = ctx.IsMainFrameVisible,
    setMainFrameHeightSafe = ctx.SetMainFrameHeightSafe,
    setMainFrameWidthSafe = ctx.SetMainFrameWidthSafe,
    updateLeaderButtons = ctx.UpdateLeaderButtons,
    clearLatestQueueTarget = ctx.ClearLatestQueueTarget,
    clearRioBaselineSnapshot = ctx.ClearRioBaselineSnapshot,
    clearPendingQueueJoinInfo = function()
      runtimeState.SetPendingQueueJoinInfo(nil)
    end,
    resetInspectAll = ctx.ResetInspectAll,
    resetInspectQueues = ctx.ResetInspectQueues,
    updateUI = ctx.UpdateUI,
    refreshReadyCheckUI = ctx.RefreshReadyCheckUI,
    updateMPlusTeleportButton = ctx.UpdateMPlusTeleportButton,
    getUnitNameAndRealm = ctx.GetUnitNameAndRealm,
    getUnitClass = ctx.GetUnitClass,
    getUnitServerLanguage = ctx.GetUnitServerLanguage,
    getOwnedKeystoneSnapshot = ctx.GetOwnedKeystoneSnapshot,
    markIsiLiveUser = ctx.MarkIsiLiveUser,
    getUnitRole = ctx.GetUnitRole,
    getPlayerSpecName = ctx.GetPlayerSpecName,
    getUnitRio = ctx.GetUnitRio,
    getOwnAverageItemLevel = ctx.GetOwnAverageItemLevel,
    getInspectSpecName = ctx.GetInspectSpecName,
    getInspectSpecRole = ctx.GetInspectSpecRole,
    unitHasIsiLive = ctx.UnitHasIsiLive,
    applyKnownKeyToRosterEntry = ctx.ApplyKnownKeyToRosterEntry,
    registerVerifiedSyncAliasForRoster = ctx.RegisterVerifiedSyncAliasForRoster,
    enqueueInspect = ctx.EnqueueInspect,
    sendOwnKeySnapshot = ctx.SendOwnKeySnapshot,
    sendOwnBackgroundSnapshot = ctx.SendOwnBackgroundSnapshot,
    sendRefreshRequest = ctx.SendRefreshRequest,
    sendOwnTargetSnapshot = ctx.SendOwnTargetSnapshot,
    sendOwnKickState = ctx.SendOwnKickState,
    sendRefreshResponse = ctx.SendRefreshResponse,
    sendIsiLiveHello = ctx.SendIsiLiveHello,
    sendLibKeystonePartyData = ctx.SendLibKeystonePartyData,
    getReloadRosterMirror = function()
      local dbRef = rawget(_G, "IsiLiveDB")
      return type(dbRef) == "table" and dbRef.reloadRosterMirror or nil
    end,
    setReloadRosterMirror = function(snapshot)
      local dbRef = rawget(_G, "IsiLiveDB")
      if type(dbRef) == "table" then
        dbRef.reloadRosterMirror = snapshot
      end
    end,
    clearReloadRosterMirror = function()
      local dbRef = rawget(_G, "IsiLiveDB")
      if type(dbRef) == "table" then
        dbRef.reloadRosterMirror = {}
      end
    end,
    getReloadRosterTargetSnapshot = ctx.GetReloadRosterTargetSnapshot,
    restoreReloadRosterTargetSnapshot = ctx.RestoreReloadRosterTargetSnapshot,
    shouldAutoCloseOnKeyStart = function()
      local dbRef = rawget(_G, "IsiLiveDB")
      return ResolveAutoCloseOnKeyStartEnabled(dbRef)
    end,
    shouldAutoCloseOnSoloChange = function()
      local dbRef = rawget(_G, "IsiLiveDB")
      return ResolveAutoCloseOnSoloChangeEnabled(dbRef)
    end,
    shouldShowMainFrameOnStartup = function()
      local dbRef = rawget(_G, "IsiLiveDB")
      return ResolveAutoShowMainFrameOnStartupEnabled(dbRef)
    end,
    shouldAutoOpenMainFrameOnKeyEnd = function()
      local dbRef = rawget(_G, "IsiLiveDB")
      return ResolveAutoOpenMainFrameOnKeyEndEnabled(dbRef)
    end,
    getRaidTransitionBehavior = function()
      local dbRef = rawget(_G, "IsiLiveDB")
      return ResolveRaidTransitionBehavior(dbRef)
    end,
    autoCloseMainFrame = function()
      if ctx.mainFrame:IsShown() then
        ctx.SetMainFrameVisible(false)
      end
    end,
    unitIsGroupLeader = function(unit)
      if type(unit) ~= "string" or unit == "" then
        return false
      end

      local unitExists = rawget(_G, "UnitExists")
      if type(unitExists) ~= "function" then
        return false
      end

      local okExists, exists = pcall(unitExists, unit)
      if not okExists or not exists then
        return false
      end

      local unitIsGroupLeader = rawget(_G, "UnitIsGroupLeader")
      if type(unitIsGroupLeader) ~= "function" then
        return false
      end

      local okLeader, isLeader = pcall(unitIsGroupLeader, unit)
      return okLeader and isLeader == true
    end,
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
    getPendingPostChallengeRefresh = runtimeState.GetPendingPostChallengeRefresh,
    setPendingPostChallengeRefresh = runtimeState.SetPendingPostChallengeRefresh,
    setTrackedPartyRunInfo = runtimeState.SetTrackedPartyRunInfo,
    clearTrackedPartyRunInfo = runtimeState.ClearTrackedPartyRunInfo,
    isTrackedPartyRunActive = runtimeState.IsTrackedPartyRunActive,
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
    applyDBSettings = function()
      if type(ctx.ApplyDBSettings) == "function" then
        return ctx.ApplyDBSettings()
      end
    end,
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
    toggleSimulationTablet = ctx.ToggleSimulationTablet,
    setLanguage = ctx.SetLanguage,
    teleportDebugController = ctx.teleportDebugController,
    queueDebugController = ctx.queueDebugController,
    runtimeLogController = ctx.runtimeLogController,
    recordRun = ctx.RecordRun,
    addonName = ctx.addonName,
    resetDB = ctx.resetDB,
  }
  local runtimeSetupContext = {
    controllerWiring = modules.controllerWiring,
    configBuilders = modules.configBuilders,
    bootstrap = modules.bootstrap,
    leaderWatchModule = modules.leaderWatch,
    groupModule = modules.group,
    eventHandlersModule = modules.eventHandlers,
    mainFrame = ctx.mainFrame,
    eventFrame = ctx.eventFrame,
    onEvent = ctx.OnEvent,
    groupControllerContext = BuildRuntimeSetupGroupContext(ctx, runtimeState),
    eventHandlersContext = eventHandlersContext,
    leaderWatchContext = BuildRuntimeSetupLeaderWatchContext(ctx, runtimeState),
    slashCommandsContext = BuildRuntimeSetupSlashCommandsContext(ctx, runtimeState),
    gateContext = BuildRuntimeSetupGateContext(ctx, runtimeState),
  }

  local runtimeSetupResult = isiLiveRuntimeSetup.Configure(runtimeSetupContext)

  ctx.eventHandlersController = runtimeSetupResult.eventHandlersController
  ctx.Print(string.format(ctx.L.LOADED_HINT, ctx.GetAddonVersionRaw()))

  if ctx.runtimeLogController and ctx.runtimeLogController.IsEnabled and ctx.runtimeLogController.IsEnabled() then
    local db = rawget(_G, "IsiLiveDB") or {}
    ctx.runtimeLogController.Log(
      string.format(
        "[INIT] addon_loaded version=%s locale=%s syncEnabled=%s "
          .. "autoOpenOnQueue=%s autoCloseOnKeyStart=%s autoCloseOnSoloChange=%s autoShowOnStartup=%s",
        tostring(ctx.GetAddonVersionRaw()),
        tostring(db.locale or "default"),
        tostring(db.syncEnabled),
        tostring(db.autoOpenOnQueue),
        tostring(db.autoCloseOnKeyStart),
        tostring(db.autoCloseOnSoloChange),
        tostring(db.autoShowMainFrameOnStartup)
      )
    )
  end

  FinalizeFactorySettings(ctx)
end

function Factory.InitializeAddon(addonName, tbl, testOptions)
  local ctx = CreateFactoryContext(addonName, tbl)
  if not ctx then
    return
  end

  InitializeFactoryFrameBridge(ctx)
  InitializeFactoryRuntimeHelpers(ctx)
  InitializeFactoryPrimaryControllers(ctx)
  InitializeFactoryRefreshAndStatusControllers(ctx)
  InitializeFactorySecondaryControllers(ctx)
  FinalizeFactoryRuntime(ctx)
  if type(testOptions) == "table" and testOptions.returnContext == true then
    return ctx
  end
  return true
end
