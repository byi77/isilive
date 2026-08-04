local _, addonTable = ...

addonTable = addonTable or {}

local Bootstrap = {}
addonTable.Bootstrap = Bootstrap

-- Lua 5.1 exposes unpack as a global; Lua 5.4 only via table.unpack. Pick
-- whichever the host runtime publishes, going through rawget so a
-- sandboxed _G can't smuggle nil through the bare global lookup.
local unpack = rawget(_G, "unpack") or rawget(table, "unpack")

local function RequireFunction(value, name)
  return addonTable.Validators.RequireFunction(value, name, "Bootstrap")
end

function Bootstrap.RegisterSlashCommands(opts)
  opts = opts or {}

  local commands = assert(opts.commands, "isiLive: Bootstrap.RegisterSlashCommands requires commands")
  local printFn = RequireFunction(opts.printFn, "printFn")
  local getL = RequireFunction(opts.getL, "getL")
  local getState = RequireFunction(opts.getState, "getState")
  local setState = RequireFunction(opts.setState, "setState")
  local triggerGroupRosterUpdate = RequireFunction(opts.triggerGroupRosterUpdate, "triggerGroupRosterUpdate")
  local toggleStandardTestMode = RequireFunction(opts.toggleStandardTestMode, "toggleStandardTestMode")
  local enterFullDummyPreview = RequireFunction(opts.enterFullDummyPreview, "enterFullDummyPreview")
  local toggleSimulationTablet = type(opts.toggleSimulationTablet) == "function" and opts.toggleSimulationTablet
    or function()
      return false
    end
  local setMainFrameVisible = RequireFunction(opts.setMainFrameVisible, "setMainFrameVisible")
  local getMainFrameLocked = RequireFunction(opts.getMainFrameLocked, "getMainFrameLocked")
  local setMainFrameLocked = RequireFunction(opts.setMainFrameLocked, "setMainFrameLocked")
  local resetMainFramePosition = RequireFunction(opts.resetMainFramePosition, "resetMainFramePosition")
  local updateLeaderButtons = RequireFunction(opts.updateLeaderButtons, "updateLeaderButtons")
  local isPlayerLeader = RequireFunction(opts.isPlayerLeader, "isPlayerLeader")
  local setLanguage = RequireFunction(opts.setLanguage, "setLanguage")

  local teleportDebugController =
    assert(opts.teleportDebugController, "isiLive: Bootstrap.RegisterSlashCommands requires teleportDebugController")
  local queueDebugController =
    assert(opts.queueDebugController, "isiLive: Bootstrap.RegisterSlashCommands requires queueDebugController")
  local runtimeLogController =
    assert(opts.runtimeLogController, "isiLive: Bootstrap.RegisterSlashCommands requires runtimeLogController")
  local traceChatFrameController = opts.traceChatFrameController
  local resetDB = RequireFunction(opts.resetDB, "resetDB")
  local openSettings = type(opts.openSettings) == "function" and opts.openSettings or nil
  local toggleNameplateTestMode = type(opts.toggleNameplateTestMode) == "function" and opts.toggleNameplateTestMode
    or function()
      return false
    end
  local dumpNameplateState = type(opts.dumpNameplateState) == "function" and opts.dumpNameplateState or function() end
  local printSeasonDebug = type(opts.printSeasonDebug) == "function" and opts.printSeasonDebug or function() end
  local printHearthstoneDebug = type(opts.printHearthstoneDebug) == "function" and opts.printHearthstoneDebug
    or function() end

  commands.RegisterSlashCommands({
    printFn = printFn,
    getL = getL,
    getState = getState,
    setState = setState,
    triggerGroupRosterUpdate = triggerGroupRosterUpdate,
    toggleStandardTestMode = toggleStandardTestMode,
    enterFullDummyPreview = enterFullDummyPreview,
    toggleSimulationTablet = toggleSimulationTablet,
    setMainFrameVisible = setMainFrameVisible,
    getMainFrameLocked = getMainFrameLocked,
    setMainFrameLocked = setMainFrameLocked,
    resetMainFramePosition = resetMainFramePosition,
    updateLeaderButtons = updateLeaderButtons,
    isPlayerLeader = isPlayerLeader,
    setLanguage = setLanguage,
    forceTeleportTestTarget = teleportDebugController.ForceTeleportTestTarget,
    printTeleportDebug = teleportDebugController.PrintTeleportDebug,
    setQueueDebugEnabled = queueDebugController.SetEnabled,
    getQueueDebugEnabled = queueDebugController.IsEnabled,
    clearQueueDebugLog = queueDebugController.ClearLog,
    getQueueDebugLogCount = queueDebugController.GetLogCount,
    getQueueDebugLogTail = queueDebugController.GetLogTail,
    setRuntimeLogEnabled = runtimeLogController.SetEnabled,
    getRuntimeLogEnabled = runtimeLogController.IsEnabled,
    setRuntimeLogLevel = runtimeLogController.SetLevel,
    getRuntimeLogLevel = runtimeLogController.GetLevel,
    clearRuntimeLog = runtimeLogController.ClearLog,
    getRuntimeLogCount = runtimeLogController.GetLogCount,
    getRuntimeLogTail = runtimeLogController.GetLogTail,
    getRuntimeLogTailFiltered = runtimeLogController.GetLogTailFiltered,
    setRuntimeLogWatch = runtimeLogController.SetWatchFn,
    getRuntimeLogWatchActive = runtimeLogController.IsWatchActive,
    openTraceChatFrame = traceChatFrameController and traceChatFrameController.Open or nil,
    closeTraceChatFrame = traceChatFrameController and traceChatFrameController.Close or nil,
    isTraceChatFrameOpen = traceChatFrameController and traceChatFrameController.IsOpen or nil,
    addTraceChatFrameMessage = traceChatFrameController and traceChatFrameController.AddMessage or nil,
    resetDB = resetDB,
    openSettings = openSettings,
    toggleNameplateTestMode = toggleNameplateTestMode,
    dumpNameplateState = dumpNameplateState,
    printSeasonDebug = printSeasonDebug,
    printHearthstoneDebug = printHearthstoneDebug,
    logRuntimeTracef = runtimeLogController.Logf,
  })
end

-- Declarative event registry: { event, combat, hidden, test }
-- hidden = true (always allowed), "cond" (via callback), false (blocked)
local EVENT_REGISTRY = {
  { "ADDON_LOADED", true, true, true },
  { "PLAYER_LOGIN", true, true, false },
  { "PLAYER_ENTERING_WORLD", true, true, false },
  { "UPDATE_BINDINGS", true, true, false },
  { "PLAYER_REGEN_ENABLED", true, true, true },
  { "PLAYER_REGEN_DISABLED", true, true, true },
  { "PLAYER_DIFFICULTY_CHANGED", false, false, false },
  { "ZONE_CHANGED", false, true, false },
  { "ZONE_CHANGED_INDOORS", false, true, false },
  { "ZONE_CHANGED_NEW_AREA", false, true, false },
  { "UPDATE_INSTANCE_INFO", false, false, false },
  -- combat=true: in Delves (and in any sustained combat instance) Blizzard
  -- only fires GROUP_ROSTER_UPDATE once when a member joins. If the gate
  -- drops it because of InCombatLockdown, no later event re-issues the
  -- update — the new member stays missing from the roster until something
  -- else (often the post-boss combat-end follow-up) happens to trigger a
  -- fresh GROUP_ROSTER_UPDATE. HandleGroupRosterUpdate touches only Lua
  -- state plus the FontString-driven main frame, no secure / taint-
  -- sensitive code, so it is safe to run during combat.
  { "GROUP_ROSTER_UPDATE", true, "cond", false },
  { "PARTY_LEADER_CHANGED", false, "cond", false },
  { "PLAYER_ROLES_ASSIGNED", false, true, false },
  { "ROLE_CHANGED_INFORM", false, true, false },
  { "LFG_LIST_SEARCH_RESULT_UPDATED", false, false, false },
  { "LFG_LIST_APPLICATION_STATUS_UPDATED", false, false, false },
  { "LFG_LIST_ACTIVE_ENTRY_UPDATE", false, false, false },
  -- Addon sync payloads include in-key BR/Lust combat announces and must not
  -- be dropped while the receiver is in combat.
  { "CHAT_MSG_ADDON", true, false, false },
  { "CONFIRM_SUMMON", true, true, false },
  { "INCOMING_SUMMON_CHANGED", true, true, false },
  { "INSPECT_READY", false, false, true },
  { "CHALLENGE_MODE_START", true, true, false },
  { "CHALLENGE_MODE_COMPLETED", true, true, false },
  { "CHALLENGE_MODE_RESET", true, true, false },
  { "CHALLENGE_MODE_DEATH_COUNT_UPDATED", true, true, false },
  { "SCENARIO_CRITERIA_UPDATE", false, true, false },
  { "BAG_UPDATE_DELAYED", false, true, false },
  { "CHALLENGE_MODE_MAPS_UPDATE", false, true, false },
  { "PLAYER_EQUIPMENT_CHANGED", false, true, false },
  { "PLAYER_SPECIALIZATION_CHANGED", false, true, false },
  { "SPELL_UPDATE_COOLDOWN", false, false, false },
  { "SPELL_UPDATE_CHARGES", true, true, false },
  { "SPELLS_CHANGED", false, true, false },
  { "UNIT_AURA", true, true, false },
  -- Death watch (tank / healer death alert): needs player + party1-4, which
  -- exceeds the two-unit RegisterUnitEvent limit, so it registers unfiltered
  -- and DeathWatch drops non-party units on the first lookup. combat=true
  -- because deaths happen mid-combat; hidden=true because the alert is an
  -- event-driven cue independent of main-UI visibility (rule 80).
  { "UNIT_HEALTH", true, true, false },
  { "UNIT_PET", false, true, false, "player" },
  { "UNIT_SPELLCAST_SUCCEEDED", true, true, false, { "player", "pet" } },
  { "READY_CHECK", true, false, false },
  { "READY_CHECK_CONFIRM", true, false, false },
  { "READY_CHECK_FINISHED", true, false, false },
}
Bootstrap.EVENT_REGISTRY = EVENT_REGISTRY

local function BuildGateTables()
  local allowInCombat = {}
  local allowWhenHidden = {}
  local allowInTestMode = {}
  for _, entry in ipairs(EVENT_REGISTRY) do
    local event, combat, hidden, test = entry[1], entry[2], entry[3], entry[4]
    if combat then
      allowInCombat[event] = true
    end
    if hidden == true then
      allowWhenHidden[event] = true
    end
    if test then
      allowInTestMode[event] = true
    end
  end
  return allowInCombat, allowWhenHidden, allowInTestMode
end

function Bootstrap.CreateGatedOnEvent(opts)
  opts = opts or {}

  local events = assert(opts.events, "isiLive: Bootstrap.CreateGatedOnEvent requires events")
  local dispatch = RequireFunction(opts.dispatch, "dispatch")
  local isStopped = RequireFunction(opts.isStopped, "isStopped")
  local isPaused = RequireFunction(opts.isPaused, "isPaused")
  local isTestMode = RequireFunction(opts.isTestMode, "isTestMode")
  local isInCombat = RequireFunction(opts.isInCombat, "isInCombat")
  local onDispatchError = type(opts.onDispatchError) == "function" and opts.onDispatchError or nil

  local allowInCombat, allowWhenHidden, allowInTestMode = BuildGateTables()
  if type(opts.allowWhenHidden) == "table" then
    for k, v in pairs(opts.allowWhenHidden) do
      allowWhenHidden[k] = v
    end
  end

  return events.CreateGate({
    dispatch = dispatch,
    onDispatchError = onDispatchError,
    isStopped = isStopped,
    isPaused = isPaused,
    isTestMode = isTestMode,
    isInCombat = isInCombat,
    -- isShown decouples the visibility check from the dispatch frame so the
    -- gate can be bound to a hidden event-dispatcher frame while still
    -- honouring "suppress when the addon UI is hidden".
    isShown = type(opts.isShown) == "function" and opts.isShown or nil,
    allowInCombat = allowInCombat,
    allowWhenHidden = allowWhenHidden,
    allowInTestMode = allowInTestMode,
  })
end

-- Events that must survive the raid hard-off. Without them the addon can never
-- learn that the raid ended and stays dark until the next /reload:
-- GROUP_ROSTER_UPDATE reports the group dropping back below six,
-- PLAYER_ENTERING_WORLD covers instance changes and reloads. Both fire rarely,
-- so keeping them registered costs nothing measurable.
local RAID_WAKE_EVENTS = {
  GROUP_ROSTER_UPDATE = true,
  PLAYER_ENTERING_WORLD = true,
}
Bootstrap.RAID_WAKE_EVENTS = RAID_WAKE_EVENTS

local dispatcherEventFrame = nil
local dispatcherEventsSuppressed = false

local function RegisterDispatcherEntry(eventFrame, entry)
  local unitFilter = entry[5]
  if unitFilter and type(eventFrame.RegisterUnitEvent) == "function" then
    if type(unitFilter) == "table" then
      eventFrame:RegisterUnitEvent(entry[1], unpack(unitFilter))
    else
      eventFrame:RegisterUnitEvent(entry[1], unitFilter)
    end
  elseif type(eventFrame.RegisterEvent) == "function" then
    eventFrame:RegisterEvent(entry[1])
  end
end

function Bootstrap.RegisterDispatcherEvents(eventFrame)
  assert(eventFrame, "isiLive: Bootstrap.RegisterDispatcherEvents requires eventFrame")

  dispatcherEventFrame = eventFrame
  dispatcherEventsSuppressed = false
  for _, entry in ipairs(EVENT_REGISTRY) do
    RegisterDispatcherEntry(eventFrame, entry)
  end
end

--- Applies or lifts the raid hard-off at the event-registration level.
-- Handler-side early-outs still pay a full dispatch per event, and the two
-- unfiltered high-frequency entries (UNIT_HEALTH, UNIT_AURA) fire for every
-- raid member on every tick. Unregistering removes that traffic outright.
--
-- Re-registration is deferred through C_Timer.After(0) so RegisterEvent never
-- runs inside the dispatch stack that requested it: patch 12.0 raises
-- ADDON_ACTION_FORBIDDEN for RegisterEvent called from a protected dispatch.
-- @param suppressed boolean true to unregister, false to restore
-- @return boolean true when the suppression state actually changed
function Bootstrap.ApplyRaidEventSuppression(suppressed)
  local eventFrame = dispatcherEventFrame
  if not eventFrame then
    return false
  end

  local shouldSuppress = suppressed == true
  if shouldSuppress == dispatcherEventsSuppressed then
    return false
  end
  dispatcherEventsSuppressed = shouldSuppress

  if shouldSuppress then
    if type(eventFrame.UnregisterEvent) ~= "function" then
      dispatcherEventsSuppressed = false
      return false
    end
    for _, entry in ipairs(EVENT_REGISTRY) do
      if not RAID_WAKE_EVENTS[entry[1]] then
        pcall(eventFrame.UnregisterEvent, eventFrame, entry[1])
      end
    end
    return true
  end

  local function RestoreDispatcherEvents()
    for _, entry in ipairs(EVENT_REGISTRY) do
      if not RAID_WAKE_EVENTS[entry[1]] then
        pcall(RegisterDispatcherEntry, eventFrame, entry)
      end
    end
  end

  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    timer.After(0, RestoreDispatcherEvents)
  else
    RestoreDispatcherEvents()
  end
  return true
end

--- True while the dispatcher runs with raid-suppressed event registration.
-- @return boolean
function Bootstrap.IsRaidEventSuppressionActive()
  return dispatcherEventsSuppressed == true
end

function Bootstrap.BindMainFrameScripts(mainFrame, opts)
  opts = opts or {}

  assert(mainFrame, "isiLive: Bootstrap.BindMainFrameScripts requires mainFrame")
  local onShow = RequireFunction(opts.onShow, "onShow")
  local onHide = RequireFunction(opts.onHide, "onHide")

  -- The OnEvent script is set centrally by RuntimeSetup.Configure via
  -- Bootstrap.CreateGatedOnEvent on both eventFrame (natural dispatch) and
  -- mainFrame (synthetic re-dispatches). This helper covers only the show
  -- and hide hooks.
  mainFrame:SetScript("OnShow", onShow)
  mainFrame:SetScript("OnHide", onHide)
end
