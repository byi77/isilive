local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

-- Settings panel wiring of the composition root. The panel options are
-- composed from one callback group per feature; Compose rejects a callback
-- that two groups would both provide.

local Contracts = FI.FactoryContracts
local Compose = Contracts.Compose

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

  -- mainUI.ApplyScale / ResetPosition queue the change for
  -- PLAYER_REGEN_ENABLED while the protected main frame is combat-locked; the
  -- bare SetScale stays as the fallback without a mainUI.
  local mainFrame = ctx.mainFrame
  local mainUI = ctx.mainUI
  if mainUI and type(mainUI.ApplyScale) == "function" then
    mainUI.ApplyScale(1.0)
  elseif mainFrame and type(mainFrame.SetScale) == "function" then
    mainFrame:SetScale(1.0)
  end

  if mainUI and type(mainUI.ResetPosition) == "function" then
    mainUI.ResetPosition()
  end

  if type(uiCommon) == "table" and type(uiCommon.ApplyBgAlpha) == "function" then
    uiCommon.ApplyBgAlpha({
      mainFrame = mainFrame,
      panelFrame = ctx.panelUI and ctx.panelUI.panelFrame,
      settingsWindow = ctx.settingsPanel and ctx.settingsPanel.windowFrame,
    }, defaultBgAlpha)
  end

  if ctx.settingsPanel and type(ctx.settingsPanel.Refresh) == "function" then
    ctx.settingsPanel.Refresh()
  end
end

local function RenderRoster(ctx)
  if ctx.rosterPanelController and type(ctx.rosterPanelController.RenderRoster) == "function" then
    ctx.rosterPanelController.RenderRoster(ctx.GetRoster())
  end
end

local function NoAction() end

--- Panel identity: locale, DB access, reset.
local function CoreOptions(ctx)
  return {
    -- The category registers now; sections build on the first display.
    deferBuild = true,
    getL = ctx.GetL,
    setLanguage = ctx.SetLanguage,
    getCurrentLocale = function()
      return IsiLiveDB and IsiLiveDB.locale or ctx.locale
    end,
    getDB = function()
      return IsiLiveDB or {}
    end,
    onResetDB = function()
      ctx.resetDB()
    end,
  }
end

--- ESC panel strips (tooling, travel, mounts, addons).
local function EscPanelCallbacks(ctx)
  return {
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
    onHearthstoneChoiceChange = function()
      if ctx.panelUI and type(ctx.panelUI.SyncVisibility) == "function" then
        ctx.panelUI.SyncVisibility()
      end
      if ctx.secondPanelUI and type(ctx.secondPanelUI.SyncVisibility) == "function" then
        ctx.secondPanelUI.SyncVisibility()
      end
    end,
  }
end

--- Queue-debug and runtime-log toggles.
local function DebugLogCallbacks(ctx)
  return {
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
  }
end

--- Stats box window.
local function StatsBoxCallbacks(ctx)
  local function StatsBoxCall(method, ...)
    local statsBox = ctx.addonTable and ctx.addonTable.StatsBox
    if type(statsBox) == "table" and type(statsBox[method]) == "function" then
      statsBox[method](...)
    end
  end
  return {
    onStatsBoxToggle = function(enabled)
      StatsBoxCall("SetEnabled", enabled)
    end,
    onStatsBoxLockToggle = function(locked)
      StatsBoxCall("SetLocked", locked)
    end,
    onStatsBoxBgAlphaChange = function(val)
      StatsBoxCall("SetBackgroundAlpha", val)
    end,
    onStatsBoxFontSizeOffsetChange = function(offset)
      StatsBoxCall("SetFontSizeOffset", offset)
    end,
    onStatsBoxOptionsChange = function()
      StatsBoxCall("ApplySettings")
    end,
  }
end

--- Main window appearance: scale, background, fonts, motion, design.
local function AppearanceCallbacks(ctx)
  return {
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
          settingsWindow = ctx.settingsPanel and ctx.settingsPanel.windowFrame,
        }, val)
      end
    end,
    onUiScaleChange = function(val)
      local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
      if logf then
        logf("[SETTINGS] ui_scale val=%s", tostring(val))
      end
      -- Goes through mainUI so the frame keeps its on-screen position across
      -- the scale change; the bare SetScale stays as the fallback.
      if ctx.mainUI and type(ctx.mainUI.ApplyScale) == "function" then
        ctx.mainUI.ApplyScale(val)
      elseif ctx.mainFrame and type(ctx.mainFrame.SetScale) == "function" then
        ctx.mainFrame:SetScale(val)
      end
      if type(ctx.RefreshSimulationTabletDock) == "function" then
        ctx.RefreshSimulationTabletDock()
      end
    end,
    onUiFontFamilyChange = function(_key)
      -- The ApplyLocaleFont call sites sit in row/label creation, and rows
      -- are pooled -- a re-render alone would not change a single existing
      -- FontString. RefreshTrackedFonts walks the strings themselves.
      local common = ctx.addonTable and ctx.addonTable.UICommon
      if type(common) == "table" and type(common.RefreshTrackedFonts) == "function" then
        common.RefreshTrackedFonts()
      end
      RenderRoster(ctx)
    end,
    onReduceMotionChange = function(enabled)
      local common = ctx.addonTable and ctx.addonTable.UICommon
      if type(common) == "table" and type(common.SetReducedMotionEnabled) == "function" then
        common.SetReducedMotionEnabled(enabled)
      end
      if ctx.teleportUIController and type(ctx.teleportUIController.SetReducedMotionEnabled) == "function" then
        ctx.teleportUIController.SetReducedMotionEnabled(enabled)
      end
    end,
    onUiDesignChange = function(design)
      FI.ApplyUiDesignChange(ctx, design)
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
  }
end

--- Main window position, layout and roster rendering options.
local function LayoutCallbacks(ctx)
  return {
    onMainFramePositionLockToggle = function(enabled)
      if ctx.mainUI and type(ctx.mainUI.SetDragLocked) == "function" then
        ctx.mainUI.SetDragLocked(enabled)
      end
    end,
    onResetMainFramePosition = function()
      ResetMainFrameDefaults(ctx)
    end,
    onDefaultLayoutModeChange = function(_layoutMode)
      ctx.RestoreLayoutState()
    end,
    onRosterColumnGuidesToggle = function(_enabled)
      if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshLayoutState) == "function" then
        ctx.rosterPanelController.RefreshLayoutState()
      else
        RenderRoster(ctx)
      end
    end,
    onNameMaxCharsChange = function(_maxChars)
      RenderRoster(ctx)
    end,
    onTeleportColumnsChange = function(_columns)
      if ctx.teleportUIController and type(ctx.teleportUIController.UpdateButtons) == "function" then
        ctx.UpdateMPlusTeleportButton()
      end
    end,
    onPortalNavigatorToggle = function(_enabled)
      if ctx.statusController and type(ctx.statusController.MaybeShowPortalNavigatorNotice) == "function" then
        ctx.statusController.MaybeShowPortalNavigatorNotice()
      end
    end,
    -- Live-applies a display toggle that only changes the M+ killtracker row.
    onForcesPaceToggle = function()
      if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshKillTrackRow) == "function" then
        ctx.rosterPanelController.RefreshKillTrackRow()
      end
    end,
  }
end

--- LFG flags, group bonuses, tooltip flags, M+ forces tooltip and nameplate.
local function LfgAndForcesCallbacks(ctx)
  return {
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
      RenderRoster(ctx)
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
      FI.ApplyMobNameplateDisplaySettings(mobNameplate, db)
      if type(mobNameplate.SetEnabled) == "function" then
        mobNameplate.SetEnabled(db.mobNameplateEnabled == true)
      end
    end,
  }
end

--- Toggles the runtime reads straight from IsiLiveDB; nothing to apply live.
local function DbReadToggleCallbacks()
  return {
    onSyncToggle = NoAction,
    onAutoOpenQueueToggle = NoAction,
    onAutoCloseOnKeyStartToggle = NoAction,
    onAutoCloseOnSoloChangeToggle = NoAction,
    onCombatFadeMMToggle = NoAction,
    onAutoShowMainFrameOnStartupToggle = NoAction,
    onAutoOpenMainFrameOnKeyEndToggle = NoAction,
    onRaidTransitionBehaviorChange = NoAction,
  }
end

local function BuildSettingsPanelOptions(ctx)
  return Compose(
    "settingsPanelOptions",
    CoreOptions(ctx),
    EscPanelCallbacks(ctx),
    DebugLogCallbacks(ctx),
    StatsBoxCallbacks(ctx),
    AppearanceCallbacks(ctx),
    LayoutCallbacks(ctx),
    LfgAndForcesCallbacks(ctx),
    DbReadToggleCallbacks()
  )
end

--- Creates the settings panel, ctx.ApplyDBSettings, the minimap button and
-- the addon compartment entry.
local function FinalizeFactorySettings(ctx)
  local modules = ctx.modules

  if modules.settingsPanel and type(modules.settingsPanel.Create) == "function" then
    ctx.settingsPanel = modules.settingsPanel.Create(BuildSettingsPanelOptions(ctx))

    -- Apply initial DB values for flag features and re-apply them on every
    -- ADDON_LOADED (see BuildApplyDBSettings).
    ctx.ApplyDBSettings = FI.BuildApplyDBSettings(ctx)
    ctx.ApplyDBSettings()
  end

  -- Minimap Button: create with correct initial visibility so MinimapButtonButton
  -- sees the right shown-state when it scans on PLAYER_LOGIN.
  -- Create always hidden; ADDON_LOADED handler shows it if the setting is enabled.
  -- SavedVariables (IsiLiveDB) are not yet available at file-load time.
  ctx.minimapButton = FI.CreateFactoryMinimapButton(ctx)
  if ctx.minimapButton then
    ctx.minimapButton:Hide()
  end
  -- Addon list entry behind the minimap's addon button (TOC AddonCompartment*).
  FI.RegisterAddonCompartmentHandlers(ctx)
end

FI.FinalizeFactorySettings = FinalizeFactorySettings
FI.BuildSettingsPanelOptions = BuildSettingsPanelOptions
