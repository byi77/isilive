local addonName, addonTable = ...
local isiLiveSync = addonTable and addonTable.Sync
local isiLiveKeySync = addonTable and addonTable.KeySync
local isiLiveRefresh = addonTable and addonTable.Refresh
local isiLiveHighlight = addonTable and addonTable.Highlight
local isiLiveGroup = addonTable and addonTable.Group
local isiLiveQueue = addonTable and addonTable.Queue
local isiLiveQueueFlow = addonTable and addonTable.QueueFlow
local isiLiveInspect = addonTable and addonTable.Inspect
local isiLiveRoster = addonTable and addonTable.Roster
local isiLiveEvents = addonTable and addonTable.Events
local isiLiveEventHandlers = addonTable and addonTable.EventHandlers
local isiLiveCommands = addonTable and addonTable.Commands
local isiLiveLocale = addonTable and addonTable.Locale
local isiLiveTexts = addonTable and addonTable.Texts
local isiLiveUI = addonTable and addonTable.UI
local isiLiveTeleport = addonTable and addonTable.Teleport
local isiLiveTeleportUI = addonTable and addonTable.TeleportUI
local isiLiveTeleportDebug = addonTable and addonTable.TeleportDebug
local isiLiveNotice = addonTable and addonTable.Notice
local isiLiveStatus = addonTable and addonTable.Status
local isiLiveUnits = addonTable and addonTable.Units
local isiLiveDemo = addonTable and addonTable.Demo
local isiLiveTestMode = addonTable and addonTable.TestMode
local isiLiveQueueDebug = addonTable and addonTable.QueueDebug
local isiLiveRosterPanel = addonTable and addonTable.RosterPanel
local isiLiveSpellUtils = addonTable and addonTable.SpellUtils
local isiLiveBindings = addonTable and addonTable.Bindings
local isiLiveEventUtils = addonTable and addonTable.EventUtils
local isiLiveBootstrap = addonTable and addonTable.Bootstrap
local isiLiveControllerWiring = addonTable and addonTable.ControllerWiring
local isiLiveLeaderWatch = addonTable and addonTable.LeaderWatch
local isiLiveConfigBuilders = addonTable and addonTable.ConfigBuilders
local isiLiveFrameBridge = addonTable and addonTable.FrameBridge
local isiLiveContextHelpers = addonTable and addonTable.ContextHelpers
local isiLiveRuntimeSetup = addonTable and addonTable.RuntimeSetup
local isiLiveControllerInit = addonTable and addonTable.ControllerInit
local isiLiveGuards = addonTable and addonTable.Guards

-- --- Configuration & Constants ---
local INSPECT_TIMEOUT = 2 -- seconds
local RETRY_INTERVAL = 5 -- seconds
local INSPECT_DELAY = 1 -- seconds between inspects to avoid throttle
local MIN_FRAME_HEIGHT = 212

-- --- Localization ---
local locale = GetLocale()
local locales
local L

local isTestAllMode = false

local function Print(msg)
  print("isiLive: " .. msg)
end

if not (isiLiveGuards and type(isiLiveGuards.Validate) == "function") then
  print("|cffff0000isiLive: missing module Guards (isiLive_guards.lua)|r")
  return
end

local guardsOk, guardsErr = pcall(isiLiveGuards.Validate, addonTable)
if not guardsOk then
  print("|cffff0000isiLive: " .. tostring(guardsErr) .. "|r")
  return
end

locales = isiLiveTexts.GetLocaleTables()
L = locales.enUS

local GetAddonVersionRaw = function()
  return isiLiveContextHelpers.GetAddonVersionRaw(addonName)
end

local queueDebugController = isiLiveQueueDebug.CreateController({
  printFn = Print,
  queueSetDebugEnabled = function(enabled)
    if isiLiveQueue and isiLiveQueue.SetDebugEnabled then
      isiLiveQueue.SetDebugEnabled(enabled)
    end
  end,
  queueIsDebugEnabled = function()
    if isiLiveQueue and isiLiveQueue.IsDebugEnabled then
      return isiLiveQueue.IsDebugEnabled() == true
    end
    return nil
  end,
  maxEntries = 400,
})

if isiLiveQueue and isiLiveQueue.SetDebugLogger then
  isiLiveQueue.SetDebugLogger(queueDebugController.Log)
end

local GetSpellCooldownSafe = isiLiveSpellUtils.GetSpellCooldownSafe
local ApplyCooldownFrameSafe = isiLiveSpellUtils.ApplyCooldownFrameSafe
local IsSpellKnownSafe = isiLiveSpellUtils.IsSpellKnownSafe
local GetTeleportCooldownRemaining = isiLiveSpellUtils.GetTeleportCooldownRemaining
local FormatCooldownSeconds = isiLiveSpellUtils.FormatCooldownSeconds
local IsNegativeApplicationStatusEvent = isiLiveEventUtils.IsNegativeApplicationStatusEvent

local function IsPlayerLeader()
  if isTestAllMode then
    return true
  end
  return IsInGroup() and UnitIsGroupLeader("player")
end

local GetRealmInfoLib = isiLiveContextHelpers.CreateRealmInfoGetter()

local GetUnitRole = isiLiveUnits.GetUnitRole
local TruncateName = isiLiveUnits.TruncateName
local GetUnitNameAndRealm = isiLiveUnits.GetUnitNameAndRealm
local GetPlayerSpecName = isiLiveUnits.GetPlayerSpecName
local GetInspectSpecName = isiLiveUnits.GetInspectSpecName
local GetShortSpecLabel = isiLiveUnits.GetShortSpecLabel
local GetUnitRio = isiLiveUnits.GetUnitRio

local function BuildDummyRoster()
  return isiLiveContextHelpers.BuildDummyRoster({
    demoBuildDummyRoster = isiLiveDemo.BuildDummyRoster,
    getUnitNameAndRealm = GetUnitNameAndRealm,
    getUnitServerLanguage = function(unit, realm)
      return isiLiveContextHelpers.GetUnitServerLanguage(isiLiveLocale, GetRealmInfoLib, unit, realm)
    end,
    getUnitRole = GetUnitRole,
    getPlayerSpecName = GetPlayerSpecName,
    getUnitRio = GetUnitRio,
  })
end

local UpdateStatusLine
local UpdateUI
local ShowQueueJoinPreview
local UpdateCountdownCancelButton
local UpdateLeaderButtons
local OnEvent
local ResolveActiveKeyOwnerUnit
local MarkIsiLiveUser
local UnitHasIsiLive
local RegisterIsiLiveSyncPrefix
local SendIsiLiveHello
local GetOwnedKeystoneSnapshot
local SendOwnKeySnapshot
local ApplyKnownKeyToRosterEntry
local latestQueueDungeonName
local latestQueueActivityID
local latestQueueTeleportSpellID
local latestQueueMapID
local ApplyLocalizationToUI
local bindingController
local keySyncController
local refreshController
local highlightController
local queueFlowController
local testModeController
local eventHandlersController
local teleportUIController
local teleportDebugController
local rosterPanelController
local refreshButton
local countdownCancelButton
local statusLine
local mplusTeleportButtons
local roster = {}
local activeJoinedKeyMapID = nil
local rioBaselineByPlayerKey = {}
local hasRioBaselineSnapshot = false

local function ApplyHotkeyBindings()
  if bindingController then
    bindingController.ApplyHotkeyBindings()
  end
end

local function StartBindingWatchdog()
  if bindingController then
    bindingController.StartBindingWatchdog()
  end
end

local ResolveSeason3TeleportSpellIDByActivityID = isiLiveTeleport.ResolveSeason3TeleportSpellIDByActivityID
local ResolveSeason3MapIDByActivityID = isiLiveTeleport.ResolveSeason3MapIDByActivityID
local ResolveSeason3TeleportSpellID = isiLiveTeleport.ResolveSeason3TeleportSpellID
local ApplySecureSpellToButton = isiLiveTeleport.ApplySecureSpellToButton

-- --- UI Elements ---
local mainFrame
local mainUI
local centerNotice
local centerNoticeFrame
local centerNoticeTeleportButton
local inviteHint

local frameBridgeContext = isiLiveFrameBridge.CreateContext({
  createCenterNotice = isiLiveNotice.CreateCenterNotice,
  createInviteHint = isiLiveNotice.CreateInviteHint,
  createMainFrame = isiLiveUI.CreateMainFrame,
  parent = UIParent,
  mainFrameGlobalName = "isiLiveMainFrame",
  mainFrameMinHeight = MIN_FRAME_HEIGHT,
  isInGroup = IsInGroup,
  isInCombat = function()
    return InCombatLockdown and InCombatLockdown()
  end,
  onShownInGroup = function()
    local onEventHandler = mainFrame and mainFrame:GetScript("OnEvent")
    if onEventHandler then
      onEventHandler(mainFrame, "GROUP_ROSTER_UPDATE")
    end
  end,
  onShownNoGroup = function()
    UpdateUI()
    UpdateLeaderButtons()
  end,
  resolveTeleportSpellID = ResolveSeason3TeleportSpellID,
  applySecureSpellToButton = ApplySecureSpellToButton,
  isSpellKnown = IsSpellKnownSafe,
  getTeleportCooldownRemaining = GetTeleportCooldownRemaining,
  formatCooldownSeconds = FormatCooldownSeconds,
  getL = function()
    return L
  end,
})
centerNotice = frameBridgeContext.centerNotice
centerNoticeFrame = frameBridgeContext.centerNoticeFrame
centerNoticeTeleportButton = frameBridgeContext.centerNoticeTeleportButton
inviteHint = frameBridgeContext.inviteHint
mainUI = frameBridgeContext.mainUI
mainFrame = frameBridgeContext.mainFrame

local function SetCenterNoticeVisible(visible)
  frameBridgeContext.SetCenterNoticeVisible(visible)
end
local function UpdateCenterTeleportButtonVisual(spellID, isEnabled, inCombatBlocked)
  frameBridgeContext.UpdateCenterTeleportButtonVisual(spellID, isEnabled, inCombatBlocked)
end
local function ShowCenterNotice(message, durationSeconds, dungeonName, activityID, showOptions)
  frameBridgeContext.ShowCenterNotice(message, durationSeconds, dungeonName, activityID, showOptions)
end
local function ShowInviteHint(message, durationSeconds)
  frameBridgeContext.ShowInviteHint(message, durationSeconds)
end

local function SetMainFrameVisible(visible)
  frameBridgeContext.SetMainFrameVisible(visible)
end
local function SetMainFrameHeightSafe(height)
  frameBridgeContext.SetMainFrameHeightSafe(height)
end

local function ToggleMainFrameVisibility()
  frameBridgeContext.ToggleMainFrameVisibility()
end

-- --- Data & State ---
-- Stores current group members keyed by unit token.
local inspectController = isiLiveInspect.CreateController({
  inspectTimeout = INSPECT_TIMEOUT,
  retryInterval = RETRY_INTERVAL,
  inspectDelay = INSPECT_DELAY,
})
local inspectLoopTimer = 0
local InspectLoop
local wasGroupLeader = nil
local wasInGroup = false
local wasRaidGroup = false
local pendingQueueJoinInfo = nil
latestQueueDungeonName = nil
latestQueueActivityID = nil
latestQueueTeleportSpellID = nil
latestQueueMapID = nil
local isTestMode = false
local isStopped = false
local isPaused = false

local function GetActiveChallengeMapID()
  return C_ChallengeMode.GetActiveChallengeMapID()
end

local function GetWasInGroup()
  return wasInGroup
end

local function SetWasInGroup(value)
  wasInGroup = value and true or false
end

local function GetWasRaidGroup()
  return wasRaidGroup
end

local function SetWasRaidGroup(value)
  wasRaidGroup = value and true or false
end

local function SetWasGroupLeader(value)
  wasGroupLeader = value
end

local function GetRoster()
  return roster
end

local function SetRoster(value)
  roster = value or {}
end

local function NormalizePlayerKey(name, realm)
  if isiLiveSync and type(isiLiveSync.NormalizePlayerKey) == "function" then
    return isiLiveSync.NormalizePlayerKey(name, realm)
  end

  local normalizedName = name and tostring(name) or ""
  local normalizedRealm = realm and tostring(realm) or ""
  if normalizedRealm == "" then
    normalizedRealm = GetRealmName() or ""
  end
  return string.lower(normalizedName .. "-" .. normalizedRealm)
end

local function BuildRosterInfoPlayerKey(info)
  if type(info) ~= "table" then
    return nil
  end

  local name = info.name
  if type(name) ~= "string" or name == "" then
    return nil
  end

  return NormalizePlayerKey(name, info.realm)
end

local function ClearRioBaselineSnapshot()
  rioBaselineByPlayerKey = {}
  hasRioBaselineSnapshot = false
end

local function CaptureRioBaselineSnapshot()
  local snapshot = {}
  local hasSnapshotData = false

  for unit, info in pairs(roster) do
    local playerKey = BuildRosterInfoPlayerKey(info)
    if playerKey and playerKey ~= "" then
      local rioValue = tonumber(info and info.rio)
      if not rioValue then
        rioValue = tonumber(GetUnitRio(unit))
      end
      if rioValue then
        snapshot[playerKey] = math.floor(rioValue)
        hasSnapshotData = true
      end
    end
  end

  rioBaselineByPlayerKey = snapshot
  hasRioBaselineSnapshot = hasSnapshotData
end

local function GetRioDeltaForRosterInfo(info)
  if not hasRioBaselineSnapshot then
    return nil
  end

  local playerKey = BuildRosterInfoPlayerKey(info)
  if not playerKey then
    return nil
  end

  local baselineRio = rioBaselineByPlayerKey[playerKey]
  if baselineRio == nil then
    return nil
  end

  local currentRio = tonumber(info and info.rio)
  if not currentRio then
    return nil
  end

  local delta = math.floor(currentRio) - baselineRio
  if delta < 0 then
    return 0
  end
  return delta
end

local function ResetInspectAll()
  inspectController.ResetAll()
end

local function ResetInspectQueues()
  inspectController.ResetQueues()
end

local function GetPendingBindingApply()
  if not bindingController then
    return false
  end
  return bindingController.GetPendingBindingApply()
end

local function ClearLatestQueueTarget()
  latestQueueDungeonName = nil
  latestQueueActivityID = nil
  latestQueueTeleportSpellID = nil
  latestQueueMapID = nil
  activeJoinedKeyMapID = nil
end

local function RefreshLocalPlayerKey()
  return keySyncController.RefreshLocalPlayerKey(roster)
end

UpdateCountdownCancelButton = function()
  if not rosterPanelController then
    return
  end
  rosterPanelController.SetCountdownCancelText(L.BTN_COUNTDOWN_CANCEL)
end

local initResult = isiLiveControllerInit.CreateControllers({
  sync = isiLiveSync,
  keySyncModule = isiLiveKeySync,
  highlightModule = isiLiveHighlight,
  rosterPanelModule = isiLiveRosterPanel,
  teleportUIModule = isiLiveTeleportUI,
  isInGroup = IsInGroup,
  getUnitNameAndRealm = GetUnitNameAndRealm,
  getAddonVersionRaw = GetAddonVersionRaw,
  isFrameVisible = function()
    return mainFrame and mainFrame:IsShown()
  end,
  resolveSeason3TeleportSpellID = ResolveSeason3TeleportSpellID,
  resolveSeason3TeleportSpellIDByMapID = function(mapID)
    if isiLiveTeleport and isiLiveTeleport.ResolveSeason3TeleportSpellIDByMapID then
      return isiLiveTeleport.ResolveSeason3TeleportSpellIDByMapID(mapID)
    end
    return nil
  end,
  resolveSeason3MapIDByActivityID = function(activityID)
    if isiLiveTeleport and isiLiveTeleport.ResolveSeason3MapIDByActivityID then
      return isiLiveTeleport.ResolveSeason3MapIDByActivityID(activityID)
    end
    return nil
  end,
  resolveSeason3MapIDBySpellID = function(spellID)
    if isiLiveTeleport and isiLiveTeleport.ResolveSeason3MapIDBySpellID then
      return isiLiveTeleport.ResolveSeason3MapIDBySpellID(spellID)
    end
    return nil
  end,
  resolveSeason3MapIDsBySpellID = function(spellID)
    if isiLiveTeleport and isiLiveTeleport.ResolveSeason3MapIDsBySpellID then
      return isiLiveTeleport.ResolveSeason3MapIDsBySpellID(spellID)
    end
    return nil
  end,
  mainFrame = mainFrame,
  getL = function()
    return L
  end,
  isPlayerLeader = IsPlayerLeader,
  getAddonVersionText = function()
    return "V." .. GetAddonVersionRaw()
  end,
  updateStatusLine = function()
    if UpdateStatusLine then
      UpdateStatusLine()
    end
  end,
  setMainFrameHeightSafe = SetMainFrameHeightSafe,
  minFrameHeight = MIN_FRAME_HEIGHT,
  buildOrderedRoster = isiLiveRoster.BuildOrderedRoster,
  hasFullSync = isiLiveRoster.HasFullSync,
  buildDisplayData = isiLiveRoster.BuildDisplayData,
  truncateName = TruncateName,
  getShortSpecLabel = GetShortSpecLabel,
  getLanguageFlagMarkup = isiLiveLocale.GetLanguageFlagMarkup,
  getDungeonShortCode = isiLiveTeleport.GetSeason3DungeonShortCode,
  getRioDelta = GetRioDeltaForRosterInfo,
  resolveActiveKeyOwnerUnit = function()
    if ResolveActiveKeyOwnerUnit then
      return ResolveActiveKeyOwnerUnit()
    end
    return nil
  end,
  getRoster = GetRoster,
  applySecureSpellToButton = ApplySecureSpellToButton,
  getEntries = isiLiveTeleport.BuildSeason3TeleportEntries,
  isSpellKnown = IsSpellKnownSafe,
  getTeleportCooldownRemaining = GetTeleportCooldownRemaining,
  formatCooldownSeconds = FormatCooldownSeconds,
  getSpellCooldownSafe = GetSpellCooldownSafe,
  applyCooldownFrameSafe = ApplyCooldownFrameSafe,
  getSpellTexture = function(spellID)
    if spellID and C_Spell and C_Spell.GetSpellTexture then
      return C_Spell.GetSpellTexture(spellID)
    end
    return nil
  end,
})
keySyncController = initResult.keySyncController
MarkIsiLiveUser = initResult.markIsiLiveUser
UnitHasIsiLive = initResult.unitHasIsiLive
RegisterIsiLiveSyncPrefix = initResult.registerIsiLiveSyncPrefix
SendIsiLiveHello = initResult.sendIsiLiveHello
GetOwnedKeystoneSnapshot = initResult.getOwnedKeystoneSnapshot
SendOwnKeySnapshot = initResult.sendOwnKeySnapshot
ApplyKnownKeyToRosterEntry = initResult.applyKnownKeyToRosterEntry
highlightController = initResult.highlightController
rosterPanelController = initResult.rosterPanelController
refreshButton = initResult.refreshButton
countdownCancelButton = initResult.countdownCancelButton
statusLine = initResult.statusLine
teleportUIController = initResult.teleportUIController
mplusTeleportButtons = initResult.mplusTeleportButtons

UpdateLeaderButtons = function()
  rosterPanelController.UpdateLeaderButtons()
end

UpdateUI = function()
  rosterPanelController.RenderRoster(roster)
end

local function GetNormalizedActiveEntryInfo()
  return highlightController.GetNormalizedActiveEntryInfo()
end

local function ResolveActiveTeleportSpellID()
  return highlightController.ResolveActiveTeleportSpellID(latestQueueActivityID, latestQueueMapID)
end

local function ResolveJoinedKeyMapID(activityID, spellID)
  return highlightController.ResolveJoinedKeyMapID(activityID, spellID)
end

ResolveActiveKeyOwnerUnit = function()
  return keySyncController.ResolveActiveKeyOwnerUnit(roster, activeJoinedKeyMapID)
end

local function UpdateMPlusTeleportButton()
  local resolvedSpellID = ResolveActiveTeleportSpellID()
  teleportUIController.UpdateButtons(resolvedSpellID)
end

teleportDebugController = isiLiveTeleportDebug.CreateController({
  printFn = Print,
  getL = function()
    return L
  end,
  updateMPlusTeleportButton = UpdateMPlusTeleportButton,
  resolveActiveTeleportSpellID = ResolveActiveTeleportSpellID,
  isSpellKnownSafe = IsSpellKnownSafe,
  getTeleportCooldownRemaining = GetTeleportCooldownRemaining,
  formatCooldownSeconds = FormatCooldownSeconds,
  getLatestQueueState = function()
    return latestQueueDungeonName, latestQueueActivityID, latestQueueTeleportSpellID, latestQueueMapID
  end,
  resolveSeason3MapIDByActivityID = ResolveSeason3MapIDByActivityID,
  resolveSeason3TeleportSpellIDByActivityID = ResolveSeason3TeleportSpellIDByActivityID,
  resolveSeason3TeleportSpellIDByMapID = isiLiveTeleport.ResolveSeason3TeleportSpellIDByMapID,
  getNormalizedActiveEntryInfo = GetNormalizedActiveEntryInfo,
  resolveSeason3TeleportSpellID = ResolveSeason3TeleportSpellID,
  getCenterNoticeTeleportButton = function()
    return centerNoticeTeleportButton
  end,
  getMplusTeleportButtons = function()
    return mplusTeleportButtons
  end,
  showCenterNotice = ShowCenterNotice,
  setLatestQueueState = function(dungeonName, activityID, spellID, mapID)
    latestQueueDungeonName = dungeonName
    latestQueueActivityID = activityID
    latestQueueTeleportSpellID = spellID
    latestQueueMapID = mapID
  end,
})

ApplyLocalizationToUI = function()
  rosterPanelController.ApplyLocalization()
  UpdateCountdownCancelButton()
  if centerNoticeTeleportButton and centerNoticeTeleportButton:IsShown() then
    local spellID = centerNoticeTeleportButton.spellID
    local enabled = spellID and IsSpellKnownSafe(spellID) and not centerNoticeTeleportButton.inCombatBlocked
    UpdateCenterTeleportButtonVisual(spellID, enabled, centerNoticeTeleportButton.inCombatBlocked)
  end
  UpdateMPlusTeleportButton()
  UpdateStatusLine()
end

countdownCancelButton:SetScript("OnClick", function()
  if not IsPlayerLeader() then
    return
  end
  if C_PartyInfo and C_PartyInfo.DoCountdown then
    pcall(C_PartyInfo.DoCountdown, 0)
  end
end)

local function SetProcessingActive(isActive)
  if isActive then
    mainFrame:SetScript("OnUpdate", InspectLoop)
    return
  end

  mainFrame:SetScript("OnUpdate", nil)
  inspectController.ResetQueues()
end

local statusController = isiLiveStatus.CreateController({
  getL = function()
    return L
  end,
  showCenterNotice = ShowCenterNotice,
  hideCenterNotice = function()
    centerNotice.SetVisible(false)
  end,
  isPlayerLeader = IsPlayerLeader,
})

UpdateStatusLine = function()
  statusLine:SetText(statusController.BuildStatusLineText({
    isStopped = isStopped,
    isPaused = isPaused,
    isTestMode = isTestMode,
  }))
end

local function QueueForceRefreshData()
  inspectController.QueueForceRefreshData(roster)
end

local function ForceRefreshSyncState()
  keySyncController.ForceRefreshSyncState(roster)
end

refreshController = isiLiveRefresh.CreateController(isiLiveConfigBuilders.BuildRefreshControllerOpts({
  isStopped = function()
    return isStopped
  end,
  isPaused = function()
    return isPaused
  end,
  isInGroup = IsInGroup,
  isRosterEmpty = function()
    return next(roster) == nil
  end,
  triggerGroupRosterUpdate = function()
    local onEventHandler = mainFrame:GetScript("OnEvent")
    if onEventHandler then
      onEventHandler(mainFrame, "GROUP_ROSTER_UPDATE")
    end
  end,
  forceRefreshSyncState = ForceRefreshSyncState,
  sendIsiLiveHello = SendIsiLiveHello,
  sendOwnKeySnapshot = SendOwnKeySnapshot,
  queueForceRefreshData = QueueForceRefreshData,
  updateUI = UpdateUI,
  refreshLocalPlayerKey = RefreshLocalPlayerKey,
  getActiveChallengeMapID = GetActiveChallengeMapID,
}))

refreshButton:SetScript("OnClick", function()
  refreshController.RunFullRefresh()
end)

local function GetUnitServerLanguage(unit, realm)
  return isiLiveContextHelpers.GetUnitServerLanguage(isiLiveLocale, GetRealmInfoLib, unit, realm)
end

queueFlowController = isiLiveQueueFlow.CreateController(isiLiveConfigBuilders.BuildQueueFlowControllerOpts({
  getL = function()
    return L
  end,
  getPendingQueueJoinInfo = function()
    return pendingQueueJoinInfo
  end,
  setPendingQueueJoinInfo = function(value)
    pendingQueueJoinInfo = value
  end,
  resolveSeason3MapIDByActivityID = ResolveSeason3MapIDByActivityID,
  resolveSeason3TeleportSpellIDByMapID = isiLiveTeleport.ResolveSeason3TeleportSpellIDByMapID,
  resolveJoinedKeyMapID = ResolveJoinedKeyMapID,
  updateMPlusTeleportButton = UpdateMPlusTeleportButton,
  showInviteHint = ShowInviteHint,
  showCenterNotice = ShowCenterNotice,
  updateUI = UpdateUI,
  printFn = Print,
  setQueueTargetState = function(dungeonName, activityID, spellID, joinedKeyMapID, mapID)
    latestQueueDungeonName = dungeonName
    latestQueueActivityID = activityID
    latestQueueTeleportSpellID = spellID
    latestQueueMapID = mapID
    activeJoinedKeyMapID = joinedKeyMapID
  end,
  queueCaptureQueueJoinCandidate = isiLiveQueue.CaptureQueueJoinCandidate,
  isInChallengeMode = GetActiveChallengeMapID,
  isInGroup = IsInGroup,
  isPlayerLeader = IsPlayerLeader,
  getTimeFn = GetTime,
}))

local function CaptureQueueJoinCandidate(...)
  queueFlowController.CaptureQueueJoinCandidate(...)
end

local function AnnounceQueuedGroupJoin()
  queueFlowController.AnnounceQueuedGroupJoin()
end

ShowQueueJoinPreview = function(groupName, dungeonName, activityID)
  queueFlowController.ShowQueueJoinPreview(groupName, dungeonName, activityID)
end

testModeController = isiLiveTestMode.CreateController(isiLiveConfigBuilders.BuildTestModeControllerOpts({
  getL = function()
    return L
  end,
  printFn = Print,
  getState = function()
    return {
      isStopped = isStopped,
      isPaused = isPaused,
      isTestMode = isTestMode,
      isTestAllMode = isTestAllMode,
    }
  end,
  setState = function(patch)
    if patch.isTestMode ~= nil then
      isTestMode = patch.isTestMode and true or false
    end
    if patch.isTestAllMode ~= nil then
      isTestAllMode = patch.isTestAllMode and true or false
    end
  end,
  buildDummyRoster = BuildDummyRoster,
  setRoster = SetRoster,
  setMainFrameVisible = SetMainFrameVisible,
  updateUI = UpdateUI,
  updateLeaderButtons = UpdateLeaderButtons,
  showCenterNotice = ShowCenterNotice,
  showQueueJoinPreview = ShowQueueJoinPreview,
  resetInspectAll = ResetInspectAll,
  clearLatestQueueState = function()
    latestQueueDungeonName = nil
    latestQueueActivityID = nil
    latestQueueTeleportSpellID = nil
    latestQueueMapID = nil
  end,
  captureRioBaselineSnapshot = CaptureRioBaselineSnapshot,
  clearRioBaselineSnapshot = ClearRioBaselineSnapshot,
  updateMPlusTeleportButton = UpdateMPlusTeleportButton,
  setCenterNoticeVisible = SetCenterNoticeVisible,
  hideInviteHint = function()
    inviteHint.frame:Hide()
  end,
  triggerGroupRosterUpdate = function()
    local onEventHandler = mainFrame:GetScript("OnEvent")
    if onEventHandler then
      onEventHandler(mainFrame, "GROUP_ROSTER_UPDATE")
    end
  end,
}))

local function EnterFullDummyPreview()
  testModeController.EnterFullDummyPreview()
end

local function ExitTestMode()
  testModeController.ExitTestMode()
end

local function ToggleStandardTestMode()
  testModeController.ToggleStandardTestMode()
end

bindingController = isiLiveBindings.CreateController({
  onToggleMainFrame = ToggleMainFrameVisibility,
  onToggleTestMode = ToggleStandardTestMode,
})
ApplyHotkeyBindings()

local function SetLanguage(tag)
  local resolved = isiLiveLocale.ResolveLocaleTag(tag)
  L = locales[resolved] or locales.enUS
  if IsiLiveDB then
    IsiLiveDB.locale = resolved
  end
  ApplyLocalizationToUI()
  Print(resolved == "deDE" and L.LANG_SET_DE or L.LANG_SET_EN)
end

local function SetLocaleTable(value)
  L = value
end

local function EnqueueInspect(unit)
  inspectController.EnqueueInspect(unit, roster)
end

local function CheckIfEnteredTargetDungeon()
  if not latestQueueMapID and not latestQueueActivityID and not activeJoinedKeyMapID then
    return
  end

  local currentMapID = nil
  if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
    local challengeMapID = C_ChallengeMode.GetActiveChallengeMapID()
    if type(challengeMapID) == "number" and challengeMapID > 0 then
      currentMapID = challengeMapID
    end
  end
  if not currentMapID and C_Map and C_Map.GetBestMapForUnit then
    local mapID = C_Map.GetBestMapForUnit("player")
    if type(mapID) == "number" and mapID > 0 then
      currentMapID = mapID
    end
  end
  if not currentMapID then
    return
  end

  local targetMapID = activeJoinedKeyMapID
  if not targetMapID and latestQueueMapID then
    targetMapID = latestQueueMapID
  end
  if not targetMapID and latestQueueActivityID then
    targetMapID = ResolveJoinedKeyMapID(latestQueueActivityID, nil)
  end

  if targetMapID and currentMapID == targetMapID then
    ClearLatestQueueTarget()
    UpdateMPlusTeleportButton()
    return
  end
end

OnEvent = function(self, event, ...)
  eventHandlersController.Dispatch(self, event, ...)
end

-- --- Inspect Loop ---
InspectLoop = function(_self, elapsed)
  inspectLoopTimer = inspectLoopTimer + (elapsed or 0)
  if inspectLoopTimer >= 0.25 then
    inspectLoopTimer = 0
    if GetActiveChallengeMapID() then
      return
    end
    inspectController.OnUpdate()
  end
end

isiLiveBootstrap.RegisterMainFrameEvents(mainFrame)
isiLiveBootstrap.BindMainFrameScripts(mainFrame, {
  onEvent = OnEvent,
  onShow = function()
    SetProcessingActive(true)
  end,
  onHide = function()
    SetProcessingActive(false)
  end,
})

local runtimeSetupResult = isiLiveRuntimeSetup.Configure({
  controllerWiring = isiLiveControllerWiring,
  configBuilders = isiLiveConfigBuilders,
  bootstrap = isiLiveBootstrap,
  leaderWatchModule = isiLiveLeaderWatch,
  groupModule = isiLiveGroup,
  eventHandlersModule = isiLiveEventHandlers,
  mainFrame = mainFrame,
  onEvent = OnEvent,
  sync = isiLiveSync,
  events = isiLiveEvents,
  commands = isiLiveCommands,
  isInGroup = IsInGroup,
  getNumGroupMembers = GetNumGroupMembers,
  getActiveChallengeMapID = GetActiveChallengeMapID,
  getWasInGroup = GetWasInGroup,
  setWasInGroup = SetWasInGroup,
  getWasRaidGroup = GetWasRaidGroup,
  setWasRaidGroup = SetWasRaidGroup,
  setWasGroupLeader = SetWasGroupLeader,
  getWasGroupLeader = function()
    return wasGroupLeader
  end,
  getRoster = GetRoster,
  setRoster = SetRoster,
  captureQueueJoinCandidate = CaptureQueueJoinCandidate,
  announceQueuedGroupJoin = AnnounceQueuedGroupJoin,
  setMainFrameVisible = SetMainFrameVisible,
  setMainFrameHeightSafe = SetMainFrameHeightSafe,
  updateLeaderButtons = UpdateLeaderButtons,
  clearLatestQueueTarget = ClearLatestQueueTarget,
  clearRioBaselineSnapshot = ClearRioBaselineSnapshot,
  resetInspectAll = ResetInspectAll,
  resetInspectQueues = ResetInspectQueues,
  updateUI = UpdateUI,
  updateMPlusTeleportButton = UpdateMPlusTeleportButton,
  getUnitNameAndRealm = GetUnitNameAndRealm,
  getUnitClass = UnitClass,
  getUnitServerLanguage = GetUnitServerLanguage,
  getOwnedKeystoneSnapshot = GetOwnedKeystoneSnapshot,
  markIsiLiveUser = MarkIsiLiveUser,
  getUnitRole = GetUnitRole,
  getPlayerSpecName = GetPlayerSpecName,
  getUnitRio = GetUnitRio,
  getInspectSpecName = GetInspectSpecName,
  unitHasIsiLive = UnitHasIsiLive,
  applyKnownKeyToRosterEntry = ApplyKnownKeyToRosterEntry,
  enqueueInspect = EnqueueInspect,
  sendOwnKeySnapshot = SendOwnKeySnapshot,
  sendIsiLiveHello = SendIsiLiveHello,
  isPlayerLeader = IsPlayerLeader,
  isStopped = function()
    return isStopped
  end,
  isPaused = function()
    return isPaused
  end,
  isTestMode = function()
    return isTestMode
  end,
  isTestAllMode = function()
    return isTestAllMode
  end,
  getL = function()
    return L
  end,
  printFn = Print,
  showCenterNotice = ShowCenterNotice,
  isMainFrameShown = function()
    return mainFrame and mainFrame:IsShown()
  end,
  defaultLocale = locale,
  locales = locales,
  resolveLocaleTag = isiLiveLocale.ResolveLocaleTag,
  setLocaleTable = SetLocaleTable,
  isInChallengeMode = GetActiveChallengeMapID,
  isNegativeApplicationStatusEvent = IsNegativeApplicationStatusEvent,
  getNormalizedActiveEntryInfo = GetNormalizedActiveEntryInfo,
  ensureQueueDebugStorage = queueDebugController.EnsureStorage,
  setQueueDebugEnabled = queueDebugController.SetEnabled,
  registerIsiLiveSyncPrefix = RegisterIsiLiveSyncPrefix,
  applyHotkeyBindings = ApplyHotkeyBindings,
  startBindingWatchdog = StartBindingWatchdog,
  getAddonVersionRaw = GetAddonVersionRaw,
  setPendingQueueJoinInfo = function(value)
    pendingQueueJoinInfo = value
  end,
  getActiveJoinedKeyMapID = function()
    return activeJoinedKeyMapID
  end,
  setActiveJoinedKeyMapID = function(value)
    activeJoinedKeyMapID = value
  end,
  getPendingBindingApply = GetPendingBindingApply,
  mainUI = mainUI,
  centerNotice = centerNotice,
  centerNoticeFrame = centerNoticeFrame,
  centerNoticeTeleportButton = centerNoticeTeleportButton,
  applySecureSpellToButton = ApplySecureSpellToButton,
  refreshController = refreshController,
  inspectController = inspectController,
  statusController = statusController,
  exitTestMode = ExitTestMode,
  updateStatusLine = UpdateStatusLine,
  applyLocalizationToUI = ApplyLocalizationToUI,
  updateCountdownCancelButton = UpdateCountdownCancelButton,
  checkIfEnteredTargetDungeon = CheckIfEnteredTargetDungeon,
  captureRioBaselineSnapshot = CaptureRioBaselineSnapshot,
  setCenterNoticeVisible = SetCenterNoticeVisible,
  getState = function()
    return {
      isStopped = isStopped,
      isPaused = isPaused,
      isTestMode = isTestMode,
      isTestAllMode = isTestAllMode,
      wasGroupLeader = wasGroupLeader,
    }
  end,
  setState = function(patch)
    if patch.isStopped ~= nil then
      isStopped = patch.isStopped
    end
    if patch.isPaused ~= nil then
      isPaused = patch.isPaused
    end
    if patch.isTestMode ~= nil then
      isTestMode = patch.isTestMode
    end
    if patch.isTestAllMode ~= nil then
      isTestAllMode = patch.isTestAllMode
    end
    if patch.wasGroupLeader ~= nil then
      wasGroupLeader = patch.wasGroupLeader
    end
  end,
  triggerGroupRosterUpdate = function()
    local onEventHandler = mainFrame:GetScript("OnEvent")
    if onEventHandler then
      onEventHandler(mainFrame, "GROUP_ROSTER_UPDATE")
    end
  end,
  toggleStandardTestMode = ToggleStandardTestMode,
  enterFullDummyPreview = EnterFullDummyPreview,
  setLanguage = SetLanguage,
  teleportDebugController = teleportDebugController,
  queueDebugController = queueDebugController,
  addonName = addonName,
})
eventHandlersController = runtimeSetupResult.eventHandlersController

Print(string.format(L.LOADED_HINT, GetAddonVersionRaw()))
