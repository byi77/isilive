local _, addonTable = ...
addonTable = addonTable or {}

-- Composition root. Builds the factory context, runs the controller
-- initializers in order and hands the assembled RuntimeSetup context to
-- RuntimeSetup.Configure. The feature dependency contracts live in
-- factory/isiLive_factory_contracts.lua, the RuntimeSetup contexts built from
-- them in factory/isiLive_factory_runtime_contexts.lua, the settings panel in
-- factory/isiLive_factory_settings_wiring.lua and the IsiLiveDB migrations in
-- factory/isiLive_factory_db_settings.lua.

---@class IsiLiveFactoryContext
---@field addonName string
---@field addonTable table Shared addon namespace.
---@field modules table Module handles (sync, events, inspect, group, ...); see isiLive_factory_frame_bridge.lua.
---@field runtimeState table RuntimeState controller (flags, pending queue join, party run).
---@field mainFrame table Main window frame.
---@field mainUI table|nil Main window controller.
---@field eventFrame table Event dispatcher frame (set in FinalizeFactoryRuntime).
---@field eventHandlersController table EventHandlers controller (set by RuntimeSetup).
---@field inspectController table Inspect queue controller.
---@field openRaidBridge table|nil LibOpenRaid item-level bridge.
---@field rosterPanelController table|nil Roster panel controller (after wiring).
---@field runtimeLogController table Runtime trace log controller.
---@field queueDebugController table Queue debug log controller.
---@field settingsPanel table|nil Settings panel (after FinalizeFactorySettings).
---@field minimapButton table|nil Minimap launcher button.
---@field OnEvent fun(self: table, event: string, ...): nil Factory event entry point.
---@field InspectLoop fun(self: table, elapsed: number): nil Inspect OnUpdate handler.
---@field ApplyDBSettings fun(): nil Migrates IsiLiveDB and pushes it into the modules.
---@field resetDB fun(): nil Wipes IsiLiveDB and reloads the UI.
---@field GetL fun(): table Active locale table.
---@field Print fun(message: string): nil Addon chat output.

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
local BuildRuntimeSetupContext = FI.BuildRuntimeSetupContext
local FinalizeFactorySettings = FI.FinalizeFactorySettings

---@param ctx IsiLiveFactoryContext
local function FinalizeFactoryRuntime(ctx)
  local modules = ctx.modules
  local isiLiveRuntimeSetup = modules.runtimeSetup

  ctx.inspectController = modules.inspect.CreateController({
    inspectTimeout = ctx.INSPECT_TIMEOUT,
    retryInterval = ctx.RETRY_INTERVAL,
    inspectDelay = ctx.INSPECT_DELAY,
    sendOwnKeySnapshot = ctx.SendOwnKeySnapshot,
    logRuntimeTracef = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil,
    logRuntimeTracefDeep = ctx.runtimeLogController and ctx.runtimeLogController.LogfDeep or nil,
    -- Rule 168: new inspect work re-attaches the idle-detached inspect loop.
    onWorkQueued = function()
      if type(ctx.RefreshInspectLoop) == "function" then
        ctx.RefreshInspectLoop()
      end
    end,
  })
  -- LibOpenRaid item levels: party only (isiLive is inactive in a raid), and
  -- a hidden window defers the render itself (rule 152).
  ctx.openRaidBridge = type(modules.inspect.CreateOpenRaidBridge) == "function"
      and modules.inspect.CreateOpenRaidBridge({
        inspectController = ctx.inspectController,
        getRoster = ctx.GetRoster,
        isActive = function()
          return ctx.IsRaidGroup() ~= true
        end,
        onChanged = function()
          local groupController = ctx.groupController
          if type(groupController) == "table" and type(groupController.SaveReloadRosterMirror) == "function" then
            groupController.SaveReloadRosterMirror()
          end
          ctx.UpdateUI()
        end,
      })
    or nil
  -- Raid state of the previous GROUP_ROSTER_UPDATE: inside a running raid the
  -- polling and processing switches below are already off, so repeated
  -- roster updates (every join, leave and subgroup move) skip them.
  local lastPostDispatchRaid = false
  ctx.OnEvent = function(self, event, ...)
    ctx.eventHandlersController.Dispatch(self, event, ...)
    if ctx.openRaidBridge then
      if event == "PLAYER_LOGIN" then
        ctx.openRaidBridge.Attach()
      elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        ctx.openRaidBridge.ScheduleSweep()
      end
    end
    if event == "GROUP_ROSTER_UPDATE" then
      local raidNow = ctx.IsRaidGroup() == true
      local steadyRaid = raidNow and lastPostDispatchRaid
      lastPostDispatchRaid = raidNow
      if steadyRaid then
        return
      end
    end
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
      if modules.killTrack and type(modules.killTrack.SetPollingSuspended) == "function" then
        modules.killTrack.SetPollingSuspended(ctx.IsRaidGroup())
      end
      ctx.SetProcessingActive(ctx.mainFrame:IsShown())
      if type(ctx.RefreshCdTrackerPolling) == "function" then
        ctx.RefreshCdTrackerPolling()
      end
    end
  end
  ctx.InspectLoop = function(_self, elapsed)
    ctx.inspectLoopTimer = ctx.inspectLoopTimer + (elapsed or 0)
    if ctx.inspectLoopTimer >= 0.25 then
      ctx.inspectLoopTimer = 0
      -- Rule 168: with nothing queued, in flight or awaiting a retry the loop
      -- detaches itself; EnqueueInspect attaches it again.
      if not ctx.inspectController.HasPendingWork() then
        ctx.RefreshInspectLoop()
        return
      end
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
      ctx.RefreshInspectLoop()
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
      -- First: renders requested while hidden were deferred (rule 152); bring
      -- the roster up to date before the window is drawn.
      if ctx.rosterPanelController and type(ctx.rosterPanelController.FlushHiddenRender) == "function" then
        ctx.rosterPanelController.FlushHiddenRender()
      end
      if ctx.teleportUpdatePending == true and type(ctx.UpdateMPlusTeleportButton) == "function" then
        ctx.UpdateMPlusTeleportButton()
      end
      ctx.SetProcessingActive(true)
      if type(ctx.RefreshCdTrackerPolling) == "function" then
        ctx.RefreshCdTrackerPolling()
      end
      if ctx.rosterPanelController and ctx.rosterPanelController.RefreshSystemOptionToggles then
        ctx.rosterPanelController.RefreshSystemOptionToggles()
      end
      if IsInGroup() and ctx.SendOwnKeySnapshot then
        ctx.SendOwnKeySnapshot(true, "show")
      end
    end,
    onHide = function()
      ctx.SetProcessingActive(false)
      if type(ctx.RefreshCdTrackerPolling) == "function" then
        ctx.RefreshCdTrackerPolling()
      end
    end,
  })

  local runtimeSetupContext = BuildRuntimeSetupContext(ctx)
  local runtimeSetupResult = isiLiveRuntimeSetup.Configure(runtimeSetupContext)

  ctx.eventHandlersController = runtimeSetupResult.eventHandlersController
  -- No init line or loaded hint here: file load runs before SavedVariables and
  -- the saved locale exist (session_start header; ADDON_LOADED prints the hint).

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
  -- Edit Mode (rule 243) and live kicks (rule 245), after every window exists.
  local lateFeatures = addonTable.FactoryEditMode
  if type(lateFeatures) == "table" and type(lateFeatures.InstallLate) == "function" then
    lateFeatures.InstallLate(ctx)
  end
  if type(testOptions) == "table" and testOptions.returnContext == true then
    return ctx
  end
  return true
end
