local _, addonTable = ...

addonTable = addonTable or {}

local Bootstrap = {}
addonTable.Bootstrap = Bootstrap

local function RequireFunction(value, name)
  assert(type(value) == "function", "isiLive: Bootstrap requires " .. name)
  return value
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
  local updateLeaderButtons = RequireFunction(opts.updateLeaderButtons, "updateLeaderButtons")
  local isPlayerLeader = RequireFunction(opts.isPlayerLeader, "isPlayerLeader")
  local setLanguage = RequireFunction(opts.setLanguage, "setLanguage")

  local teleportDebugController =
    assert(opts.teleportDebugController, "isiLive: Bootstrap.RegisterSlashCommands requires teleportDebugController")
  local queueDebugController =
    assert(opts.queueDebugController, "isiLive: Bootstrap.RegisterSlashCommands requires queueDebugController")

  commands.RegisterSlashCommands({
    printFn = printFn,
    getL = getL,
    getState = getState,
    setState = setState,
    triggerGroupRosterUpdate = triggerGroupRosterUpdate,
    toggleStandardTestMode = toggleStandardTestMode,
    enterFullDummyPreview = enterFullDummyPreview,
    setMainFrameVisible = setMainFrameVisible,
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
  })
end

function Bootstrap.CreateGatedOnEvent(opts)
  opts = opts or {}

  local events = assert(opts.events, "isiLive: Bootstrap.CreateGatedOnEvent requires events")
  local dispatch = RequireFunction(opts.dispatch, "dispatch")
  local isStopped = RequireFunction(opts.isStopped, "isStopped")
  local isPaused = RequireFunction(opts.isPaused, "isPaused")
  local isTestMode = RequireFunction(opts.isTestMode, "isTestMode")
  local isInGroup = RequireFunction(opts.isInGroup, "isInGroup")
  local getNumGroupMembers = RequireFunction(opts.getNumGroupMembers, "getNumGroupMembers")
  local getActiveChallengeMapID = RequireFunction(opts.getActiveChallengeMapID, "getActiveChallengeMapID")

  return events.CreateGate({
    dispatch = dispatch,
    isStopped = isStopped,
    isPaused = isPaused,
    isTestMode = isTestMode,
    allowWhenHidden = {
      ADDON_LOADED = true,
      PLAYER_LOGIN = true,
      PLAYER_ENTERING_WORLD = true,
      UPDATE_BINDINGS = true,
      PLAYER_REGEN_ENABLED = true,
      LFG_LIST_APPLICATION_STATUS_UPDATED = true,
      LFG_LIST_SEARCH_RESULT_UPDATED = true,
      LFG_LIST_ACTIVE_ENTRY_UPDATE = true,
      CHALLENGE_MODE_COMPLETED = true,
      CHALLENGE_MODE_RESET = true,
    },
    shouldAllowWhenHidden = function(_, event)
      if event ~= "GROUP_ROSTER_UPDATE" then
        return false
      end
      local inChallenge = getActiveChallengeMapID()
      local inSmallGroup = isInGroup() and getNumGroupMembers() <= 5
      return inSmallGroup and not inChallenge
    end,
    allowInTestMode = {
      ADDON_LOADED = true,
      PLAYER_REGEN_ENABLED = true,
      INSPECT_READY = true,
    },
  })
end

function Bootstrap.RegisterMainFrameEvents(mainFrame)
  assert(mainFrame, "isiLive: Bootstrap.RegisterMainFrameEvents requires mainFrame")

  mainFrame:RegisterEvent("ADDON_LOADED")
  mainFrame:RegisterEvent("PLAYER_LOGIN")
  mainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  mainFrame:RegisterEvent("UPDATE_BINDINGS")
  mainFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  mainFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
  mainFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  mainFrame:RegisterEvent("UPDATE_INSTANCE_INFO")
  mainFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
  mainFrame:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
  mainFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
  mainFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
  mainFrame:RegisterEvent("CHAT_MSG_ADDON")
  mainFrame:RegisterEvent("INSPECT_READY")
  mainFrame:RegisterEvent("CHALLENGE_MODE_START")
  mainFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
  mainFrame:RegisterEvent("CHALLENGE_MODE_RESET")
  mainFrame:RegisterEvent("BAG_UPDATE_DELAYED")
  mainFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
  mainFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
end

function Bootstrap.BindMainFrameScripts(mainFrame, opts)
  opts = opts or {}

  assert(mainFrame, "isiLive: Bootstrap.BindMainFrameScripts requires mainFrame")
  local onEvent = opts.onEvent
  local onShow = RequireFunction(opts.onShow, "onShow")
  local onHide = RequireFunction(opts.onHide, "onHide")

  if onEvent ~= nil then
    mainFrame:SetScript("OnEvent", RequireFunction(onEvent, "onEvent"))
  end
  mainFrame:SetScript("OnShow", onShow)
  mainFrame:SetScript("OnHide", onHide)
end
