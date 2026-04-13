local _, addonTable = ...

addonTable = addonTable or {}

local Bootstrap = {}
addonTable.Bootstrap = Bootstrap

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
  local resetDB = RequireFunction(opts.resetDB, "resetDB")

  commands.RegisterSlashCommands({
    printFn = printFn,
    getL = getL,
    getState = getState,
    setState = setState,
    triggerGroupRosterUpdate = triggerGroupRosterUpdate,
    toggleStandardTestMode = toggleStandardTestMode,
    enterFullDummyPreview = enterFullDummyPreview,
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
    clearRuntimeLog = runtimeLogController.ClearLog,
    getRuntimeLogCount = runtimeLogController.GetLogCount,
    getRuntimeLogTail = runtimeLogController.GetLogTail,
    resetDB = resetDB,
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
  { "GROUP_ROSTER_UPDATE", false, "cond", false },
  { "LFG_LIST_SEARCH_RESULT_UPDATED", false, false, false },
  { "LFG_LIST_APPLICATION_STATUS_UPDATED", false, false, false },
  { "LFG_LIST_ACTIVE_ENTRY_UPDATE", false, false, false },
  { "CHAT_MSG_ADDON", false, false, false },
  { "INSPECT_READY", false, false, true },
  { "CHALLENGE_MODE_START", true, false, false },
  { "CHALLENGE_MODE_COMPLETED", true, true, false },
  { "CHALLENGE_MODE_RESET", true, true, false },
  { "BAG_UPDATE_DELAYED", false, true, false },
  { "CHALLENGE_MODE_MAPS_UPDATE", false, true, false },
  { "PLAYER_EQUIPMENT_CHANGED", false, true, false },
  { "PLAYER_SPECIALIZATION_CHANGED", false, true, false },
  { "SPELL_UPDATE_COOLDOWN", false, false, false },
  { "SPELL_UPDATE_CHARGES", true, false, false },
  { "UNIT_AURA", true, false, false, "player" },
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
  local isInGroup = RequireFunction(opts.isInGroup, "isInGroup")
  local isInPartyInstance = RequireFunction(opts.isInPartyInstance, "isInPartyInstance")
  local getActiveChallengeMapID = RequireFunction(opts.getActiveChallengeMapID, "getActiveChallengeMapID")
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
    allowInCombat = allowInCombat,
    allowWhenHidden = allowWhenHidden,
    shouldAllowWhenHidden = function(_, event)
      if event ~= "GROUP_ROSTER_UPDATE" then
        return false
      end
      local inChallenge = getActiveChallengeMapID()
      if not inChallenge and isInPartyInstance() then
        return false
      end
      return isInGroup() and not inChallenge
    end,
    allowInTestMode = allowInTestMode,
  })
end

function Bootstrap.RegisterDispatcherEvents(eventFrame)
  assert(eventFrame, "isiLive: Bootstrap.RegisterDispatcherEvents requires eventFrame")

  for _, entry in ipairs(EVENT_REGISTRY) do
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
end

function Bootstrap.BindMainFrameScripts(mainFrame, opts)
  opts = opts or {}

  assert(mainFrame, "isiLive: Bootstrap.BindMainFrameScripts requires mainFrame")
  local onEvent = opts.onEvent
  local onShow = RequireFunction(opts.onShow, "onShow")
  local onHide = RequireFunction(opts.onHide, "onHide")

  -- onEvent is intentionally optional: the OnEvent script is normally
  -- set separately via Bootstrap.CreateGatedOnEvent().
  -- If passed anyway, it must be a function.
  if onEvent ~= nil then
    assert(type(onEvent) == "function", "isiLive: Bootstrap.BindMainFrameScripts – onEvent must be a function")
    mainFrame:SetScript("OnEvent", onEvent)
  end
  mainFrame:SetScript("OnShow", onShow)
  mainFrame:SetScript("OnHide", onHide)
end
