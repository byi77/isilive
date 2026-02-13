local addonName, addonTable = ...
local isiLiveSync = addonTable and addonTable.Sync
local isiLiveQueue = addonTable and addonTable.Queue
local isiLiveInspect = addonTable and addonTable.Inspect
local isiLiveRoster = addonTable and addonTable.Roster
local isiLiveEvents = addonTable and addonTable.Events
local isiLiveCommands = addonTable and addonTable.Commands
local isiLiveLocale = addonTable and addonTable.Locale
local isiLiveUI = addonTable and addonTable.UI
local isiLiveTeleport = addonTable and addonTable.Teleport
local isiLiveNotice = addonTable and addonTable.Notice
local isiLiveStatus = addonTable and addonTable.Status
local isiLiveUnits = addonTable and addonTable.Units
local isiLiveDemo = addonTable and addonTable.Demo

-- --- Configuration & Constants ---
local INSPECT_TIMEOUT = 2 -- seconds
local RETRY_INTERVAL = 5 -- seconds
local INSPECT_DELAY = 1 -- seconds between inspects to avoid throttle
local MIN_FRAME_HEIGHT = 200

-- --- Localization ---
local locale = GetLocale()
local locales = {
  enUS = {
    TITLE = "isiLive",
    COL_SPEC = "Spec",
    COL_NAME = "Name",
    COL_LANGUAGE = "Flag",
    COL_ILVL = "iLvl",
    COL_RIO = "RIO",
    LEAD_OPTIONS = "Lead Options",
    MPLUS_MANAGEMENT = "M+ Management",
    BTN_READYCHECK = "Readycheck",
    BTN_COUNTDOWN10 = "Countdown10",
    BTN_REFRESH = "Refresh",
    BTN_DMRESET_ON = "DM Reset: ON",
    BTN_DMRESET_OFF = "DM Reset: OFF",
    BTN_TELEPORT = "Teleport",
    BTN_TELEPORT_LOCKED = "Teleport (Locked)",
    TOOLTIP_READY = "Start a ready check.",
    TOOLTIP_CD10 = "Start a 10-second countdown.",
    TOOLTIP_REFRESH = "Force refresh all iLvl/RIO values.",
    TOOLTIP_DMRESET = "Auto-reset Blizzard Damage Meter at key start.",
    TOOLTIP_TELEPORT_CAST = "Teleport to the invited dungeon.",
    TOOLTIP_TELEPORT_LOCKED = "Teleport not unlocked yet (requires +10 completion).",
    TOOLTIP_TELEPORT_COMBAT = "Teleport button setup is blocked in combat.",
    TOOLTIP_TELEPORT_NO_TARGET = "No queued dungeon available yet.",
    TOOLTIP_TELEPORT_ACTIVE_TARGET = "Current queue target.",
    TOOLTIP_TELEPORT_READY = "Teleport is ready.",
    TOOLTIP_TELEPORT_COOLDOWN = "Teleport cooldown: %s",
    TELEPORT_ERR_NO_TARGET = "No dungeon teleport target available.",
    TELEPORT_ERR_COMBAT = "Teleport is blocked in combat.",
    TELEPORT_ERR_FAILED = "Teleport cast failed.",
    TOOLTIP_LEAD_REQUIRED = "Requires group leader.",
    STATUS_LEAD_YES = "Lead: Yes",
    STATUS_LEAD_NO = "Lead: No",
    STATUS_MPLUS_YES = "M+: Active",
    STATUS_MPLUS_NO = "M+: Inactive",
    STATUS_STATE_RUNNING = "State: Running",
    STATUS_STATE_PAUSED = "State: Paused",
    STATUS_STATE_STOPPED = "State: Stopped",
    STATUS_STATE_TEST = "State: Test",
    DUNGEON_DIFF_TEXT = "Dungeon: %s",
    DUNGEON_DIFF_OUTSIDE = "Outside",
    DUNGEON_DIFF_UNKNOWN = "Unknown",
    DUNGEON_DIFF_NORMAL = "Normal",
    DUNGEON_DIFF_HEROIC = "Heroic",
    DUNGEON_DIFF_MYTHIC = "Mythic",
    NON_MYTHIC_ENTERED = "Warning: Entered non-Mythic dungeon (%s).",
    TIMEOUT_INSPECT = "Timeout inspecting",
    ERR_STOPPED_TEST = "Addon is stopped (/isilive start). Test mode unavailable.",
    ERR_PAUSED_TEST = "Addon is paused (/isilive resume). Test mode unavailable.",
    TEST_ENABLED = "Test mode enabled (M+ preview).",
    TEST_DISABLED = "Test mode disabled.",
    STOPPED = "Addon manually stopped.",
    ERR_STOPPED_USE_START = "Addon is stopped. Use /isilive start.",
    PAUSED = "Addon paused.",
    RESUMED = "Addon resumed.",
    STARTED = "Addon started.",
    HELP_HEADER = "Commands:",
    HELP_TEST = "  /isilive test   - Toggle test mode",
    HELP_TESTALL = "  /isilive testall - Show full dummy preview",
    HELP_TPTEST = "  /isilive tptest - Force dummy teleport target",
    HELP_TPDEBUG = "  /isilive tpdebug - Show teleport button debug info",
    HELP_BINDCHECK = "  /isilive bindcheck - Show key binding actions",
    HELP_PAUSE = "  /isilive pause  - Pause addon (standby)",
    HELP_RESUME = "  /isilive resume - Resume after pause",
    HELP_STOP = "  /isilive stop   - Fully disable addon",
    HELP_START = "  /isilive start  - Re-enable addon",
    HELP_LANG = "  /isilive lang [en|de] - Switch language",
    LOADED_HINT = "Loaded Version %s Press STRG+F9 to open",
    LEAD_GAINED = "You are now the group leader.",
    LEAD_LOST = "You are no longer the group leader.",
    LEAD_TRANSFERRED = "Lead was transferred to you.",
    LEAD_TRANSFERRED_CENTER = "You are now the group leader!",
    LEAD_STATUS_YES = "Current status: you are group leader.",
    LEAD_STATUS_NO = "Current status: you are not group leader.",
    HELP_LEAD = "  /isilive lead   - Show current lead status",
    JOINED_FROM_QUEUE = "Joined from queue: %s",
    JOINED_FROM_QUEUE_DUNGEON = "Joined from queue: %s (%s)",
    UNKNOWN_GROUP = "Unknown group",
    INVITE_HINT_TITLE = "Queue Invite",
    INVITE_HINT_GROUP = "Group: %s",
    INVITE_HINT_DUNGEON = "Dungeon: %s",
    INVITE_HINT_UNKNOWN_DUNGEON = "Dungeon: Unknown",
    CHAT_QUEUE_PREFIX = "|cff33ff99Queue Join|r",
    TESTALL_DUMMY_GROUP = "Dummy Keys",
    TESTALL_DUMMY_DUNGEON = "The Dawnbreaker",
    TESTALL_CHAT_ACTIVE = "Dummy preview active (full UI).",
    DMRESET_ENABLED = "Auto Damage Meter reset enabled.",
    DMRESET_DISABLED = "Auto Damage Meter reset disabled.",
    LANG_SET_EN = "Language set to English.",
    LANG_SET_DE = "Language set to German.",
    LANG_USAGE = "Usage: /isilive lang [en|de]",
  },
  deDE = {
    TITLE = "isiLive",
    COL_SPEC = "Spec",
    COL_NAME = "Name",
    COL_LANGUAGE = "Sprache",
    COL_ILVL = "iLvl",
    COL_RIO = "RIO",
    LEAD_OPTIONS = "Lead Optionen",
    MPLUS_MANAGEMENT = "M+ Management",
    BTN_READYCHECK = "Readycheck",
    BTN_COUNTDOWN10 = "Countdown10",
    BTN_REFRESH = "Refresh",
    BTN_DMRESET_ON = "DM Reset: AN",
    BTN_DMRESET_OFF = "DM Reset: AUS",
    BTN_TELEPORT = "Teleport",
    BTN_TELEPORT_LOCKED = "Teleport (Gesperrt)",
    TOOLTIP_READY = "Startet einen Readycheck.",
    TOOLTIP_CD10 = "Startet einen 10-Sekunden-Countdown.",
    TOOLTIP_REFRESH = "Alle iLvl/RIO-Werte neu einlesen.",
    TOOLTIP_DMRESET = "Blizzard Damage Meter bei Key-Start automatisch zuruecksetzen.",
    TOOLTIP_TELEPORT_CAST = "Teleportiert zum eingeladenen Dungeon.",
    TOOLTIP_TELEPORT_LOCKED = "Teleport noch nicht freigeschaltet (benoetigt +10 Abschluss).",
    TOOLTIP_TELEPORT_COMBAT = "Teleport-Button kann im Kampf nicht vorbereitet werden.",
    TOOLTIP_TELEPORT_NO_TARGET = "Noch kein Queue-Dungeon verfuegbar.",
    TOOLTIP_TELEPORT_ACTIVE_TARGET = "Aktuelles Queue-Ziel.",
    TOOLTIP_TELEPORT_READY = "Teleport ist bereit.",
    TOOLTIP_TELEPORT_COOLDOWN = "Teleport Cooldown: %s",
    TELEPORT_ERR_NO_TARGET = "Kein Dungeon-Teleportziel verfuegbar.",
    TELEPORT_ERR_COMBAT = "Teleport ist im Kampf blockiert.",
    TELEPORT_ERR_FAILED = "Teleport-Cast fehlgeschlagen.",
    TOOLTIP_LEAD_REQUIRED = "Nur als Gruppenleiter nutzbar.",
    STATUS_LEAD_YES = "Lead: Ja",
    STATUS_LEAD_NO = "Lead: Nein",
    STATUS_MPLUS_YES = "M+: Aktiv",
    STATUS_MPLUS_NO = "M+: Inaktiv",
    STATUS_STATE_RUNNING = "Status: Aktiv",
    STATUS_STATE_PAUSED = "Status: Pausiert",
    STATUS_STATE_STOPPED = "Status: Gestoppt",
    STATUS_STATE_TEST = "Status: Test",
    DUNGEON_DIFF_TEXT = "Dungeon: %s",
    DUNGEON_DIFF_OUTSIDE = "Draussen",
    DUNGEON_DIFF_UNKNOWN = "Unbekannt",
    DUNGEON_DIFF_NORMAL = "Normal",
    DUNGEON_DIFF_HEROIC = "Heroisch",
    DUNGEON_DIFF_MYTHIC = "Mythisch",
    NON_MYTHIC_ENTERED = "Achtung: Nicht-mythischen Dungeon betreten (%s).",
    TIMEOUT_INSPECT = "Timeout beim Inspizieren von",
    ERR_STOPPED_TEST = "Addon ist gestoppt (/isilive start). Testmodus nicht verfuegbar.",
    ERR_PAUSED_TEST = "Addon ist pausiert (/isilive resume). Testmodus nicht verfuegbar.",
    TEST_ENABLED = "Testmodus aktiviert (M+ Vorschau).",
    TEST_DISABLED = "Testmodus deaktiviert.",
    STOPPED = "Addon manuell gestoppt.",
    ERR_STOPPED_USE_START = "Addon ist gestoppt. Nutze /isilive start.",
    PAUSED = "Addon pausiert.",
    RESUMED = "Addon fortgesetzt.",
    STARTED = "Addon gestartet.",
    HELP_HEADER = "Befehle:",
    HELP_TEST = "  /isilive test   - Testmodus an/aus",
    HELP_TESTALL = "  /isilive testall - Vollstaendige Dummy-Vorschau",
    HELP_TPTEST = "  /isilive tptest - Dummy-Teleportziel setzen",
    HELP_TPDEBUG = "  /isilive tpdebug - Teleport-Button Debug anzeigen",
    HELP_BINDCHECK = "  /isilive bindcheck - Key-Binding-Aktionen anzeigen",
    HELP_PAUSE = "  /isilive pause  - Addon pausieren (Standby)",
    HELP_RESUME = "  /isilive resume - Addon nach Pause fortsetzen",
    HELP_STOP = "  /isilive stop   - Addon komplett deaktivieren",
    HELP_START = "  /isilive start  - Addon wieder aktivieren",
    HELP_LANG = "  /isilive lang [en|de] - Sprache wechseln",
    LOADED_HINT = "Loaded Version %s Press STRG+F9 to open",
    LEAD_GAINED = "Du bist jetzt Gruppenleiter.",
    LEAD_LOST = "Du bist nicht mehr Gruppenleiter.",
    LEAD_TRANSFERRED = "Lead wurde auf dich uebertragen.",
    LEAD_TRANSFERRED_CENTER = "Du bist jetzt Groupenfuehrer !",
    LEAD_STATUS_YES = "Aktueller Status: du bist Gruppenleiter.",
    LEAD_STATUS_NO = "Aktueller Status: du bist nicht Gruppenleiter.",
    HELP_LEAD = "  /isilive lead   - Aktuellen Lead-Status anzeigen",
    JOINED_FROM_QUEUE = "Aus Queue beigetreten: %s",
    JOINED_FROM_QUEUE_DUNGEON = "Aus Queue beigetreten: %s (%s)",
    UNKNOWN_GROUP = "Unbekannte Gruppe",
    INVITE_HINT_TITLE = "Queue Einladung",
    INVITE_HINT_GROUP = "Gruppe: %s",
    INVITE_HINT_DUNGEON = "Dungeon: %s",
    INVITE_HINT_UNKNOWN_DUNGEON = "Dungeon: Unbekannt",
    CHAT_QUEUE_PREFIX = "|cff33ff99Queue Join|r",
    TESTALL_DUMMY_GROUP = "Dummy Schluessel",
    TESTALL_DUMMY_DUNGEON = "The Dawnbreaker",
    TESTALL_CHAT_ACTIVE = "Dummy-Vorschau aktiv (volle UI).",
    DMRESET_ENABLED = "Auto Damage Meter Reset aktiviert.",
    DMRESET_DISABLED = "Auto Damage Meter Reset deaktiviert.",
    LANG_SET_EN = "Sprache auf Englisch gesetzt.",
    LANG_SET_DE = "Sprache auf Deutsch gesetzt.",
    LANG_USAGE = "Nutzung: /isilive lang [en|de]",
  },
}
local L = locales.enUS

local isTestAllMode = false

local function Print(msg)
  print("isiLive: " .. msg)
end

if not isiLiveSync then
  isiLiveSync = {
    GetPrefix = function()
      return "ISILIVE"
    end,
    RegisterPrefix = function(_prefix) end,
    MarkUser = function(_name, _realm) end,
    IsUserKnown = function(_name, _realm)
      return false
    end,
    IsUnitKnown = function(_getUnitNameAndRealm, _unit)
      return false
    end,
    SendHello = function(_options) end,
    ProcessAddonMessage = function(_prefix, _message, _sender, _localName, _localRealm)
      return nil
    end,
  }
end

if not isiLiveQueue then
  isiLiveQueue = {
    CaptureQueueJoinCandidate = function(
      _updatePendingQueueJoin,
      _resolveTeleportSpellIDByActivityID,
      _event,
      _groupName,
      _activityID,
      _searchResultInfo
    )
    end,
  }
end

if not isiLiveInspect then
  isiLiveInspect = {
    CreateController = function(_opts)
      return {
        ResetQueues = function() end,
        ResetAll = function() end,
        QueueForceRefreshData = function(_roster) end,
        EnqueueInspect = function(_unit, _roster) end,
        OnInspectReady = function(_guid, _roster, _getUnitRio, _getInspectSpecName, _getPlayerSpecName)
          return false
        end,
        OnUpdate = function() end,
      }
    end,
  }
end

if not isiLiveRoster then
  isiLiveRoster = {
    BuildOrderedRoster = function(_roster, _rolePriority, _unitPriority)
      return {}
    end,
    HasFullSync = function(_roster)
      return false
    end,
    BuildDisplayData = function(_info, _opts)
      return {
        colorHex = "ffffffff",
        displayName = "",
        languageDisplay = "|cffbfbfbf??|r |cffd9d9d9??|r",
        specText = "-",
        ilvlText = "-",
        rioText = "-",
        addonMarker = "",
      }
    end,
  }
end

if not isiLiveEvents then
  isiLiveEvents = {
    CreateGate = function(config)
      return function(frame, event, ...)
        (config and config.dispatch or function(_frame, _event, ...)
          local _ = ...
        end)(frame, event, ...)
      end
    end,
  }
end

if not isiLiveCommands then
  isiLiveCommands = {
    RegisterSlashCommands = function(_opts) end,
  }
end

if not isiLiveLocale then
  isiLiveLocale = {
    ResolveLocaleTag = function(_tag)
      return "enUS"
    end,
    GetLanguageFlagMarkup = function(_langTag, _small)
      return "|cffbfbfbf??|r"
    end,
    GetUnitServerLanguage = function(_unit, _realm, _getRealmInfoLib)
      return "??"
    end,
  }
end

if not isiLiveUI then
  isiLiveUI = {
    CreateMainFrame = function(opts)
      local frame = CreateFrame("Frame", "isiLiveMainFrame", UIParent)
      frame:SetSize(700, tonumber(opts and opts.minHeight) or 200)
      frame:SetPoint("CENTER")
      frame:Hide()
      return {
        frame = frame,
        SetVisible = function(_visible) end,
        SetHeightSafe = function(_height) end,
        ToggleVisibility = function(_isInGroup) end,
        ApplyStoredPosition = function(_pos) end,
        GetPendingVisible = function()
          return nil
        end,
        GetPendingHeight = function()
          return nil
        end,
      }
    end,
  }
end

if not isiLiveTeleport then
  isiLiveTeleport = {
    GetSeason3TeleportInfoByMapID = function()
      return nil
    end,
    ResolveSeason3TeleportSpellIDByMapID = function()
      return nil
    end,
    ResolveSeason3TeleportSpellIDByActivityID = function(_activityID)
      return nil
    end,
    ResolveSeason3TeleportSpellID = function(_activityID, _dungeonName)
      return nil
    end,
    ApplySecureSpellToButton = function(_button, _spellID)
      return false
    end,
    BuildSeason3TeleportEntries = function()
      return {}
    end,
  }
end

if not isiLiveNotice then
  isiLiveNotice = {
    CreateCenterNotice = function(_opts)
      return {
        frame = nil,
        teleportButton = nil,
        Show = function(_message, _durationSeconds, _dungeonName, _activityID) end,
        SetVisible = function(_visible) end,
        UpdateTeleportButtonVisual = function(_spellID, _isEnabled, _inCombatBlocked) end,
        GetPendingVisible = function()
          return nil
        end,
        ApplyStoredPosition = function(_pos) end,
      }
    end,
    CreateInviteHint = function(_opts)
      return {
        frame = nil,
        Show = function(_message, _durationSeconds) end,
        Position = function(_anchorFrame) end,
      }
    end,
  }
end

if not isiLiveStatus then
  isiLiveStatus = {
    CreateController = function(_opts)
      return {
        GetAddonStateText = function(_flags)
          return ""
        end,
        GetDungeonDifficultyLabel = function()
          return "", false, false
        end,
        MaybeShowNonMythicDungeonEntryNotice = function() end,
        BuildStatusLineText = function(_flags)
          return ""
        end,
      }
    end,
  }
end

if not isiLiveUnits then
  isiLiveUnits = {
    GetUnitRole = function(_unit)
      return "NONE"
    end,
    TruncateName = function(_name, _maxChars)
      return ""
    end,
    GetUnitNameAndRealm = function(_unit)
      return nil, ""
    end,
    GetPlayerSpecName = function()
      return nil
    end,
    GetInspectSpecName = function(_unit)
      return nil
    end,
    GetUnitRio = function(_unit)
      return nil
    end,
  }
end

if not isiLiveDemo then
  isiLiveDemo = {
    BuildDummyRoster = function(_opts)
      return {}
    end,
  }
end

local function GetAddonVersionRaw()
  local legacyGetAddOnMetadata = rawget(_G, "GetAddOnMetadata")
  local version = nil
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    version = C_AddOns.GetAddOnMetadata(addonName, "Version")
  elseif legacyGetAddOnMetadata then
    version = legacyGetAddOnMetadata(addonName, "Version")
  end
  return tostring(version or "?")
end

local function IsSpellKnownSafe(spellID)
  if not spellID then
    return false
  end

  if C_SpellBook and C_SpellBook.IsSpellKnownOrOverridesKnown then
    return C_SpellBook.IsSpellKnownOrOverridesKnown(spellID) == true
  end
  if C_SpellBook and C_SpellBook.IsSpellKnown then
    return C_SpellBook.IsSpellKnown(spellID) == true
  end
  return false
end

local function GetTeleportCooldownRemaining(spellID)
  if not spellID or not (C_Spell and C_Spell.GetSpellCooldown) then
    return 0
  end
  local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
  if not ok or type(info) ~= "table" then
    return 0
  end
  local start = info.startTime or 0
  local duration = info.duration or 0
  local enabled = info.isEnabled
  if enabled == false or enabled == 0 then
    return 0
  end
  if duration <= 0 or start <= 0 then
    return 0
  end
  local remaining = (start + duration) - GetTime()
  if remaining < 0 then
    remaining = 0
  end
  return remaining
end

local function FormatCooldownSeconds(sec)
  sec = math.ceil(sec or 0)
  local totalMinutes = math.floor(sec / 60)
  local h = math.floor(totalMinutes / 60)
  local m = totalMinutes % 60
  return string.format("%02d:%02d", h, m)
end

local function IsPlayerLeader()
  if isTestAllMode then
    return true
  end
  return IsInGroup() and UnitIsGroupLeader("player")
end

local realmInfoLib
local function GetRealmInfoLib()
  if realmInfoLib ~= nil then
    return realmInfoLib
  end
  if LibStub and LibStub.GetLibrary then
    realmInfoLib = LibStub:GetLibrary("LibRealmInfo", true)
  else
    realmInfoLib = false
  end
  return realmInfoLib or nil
end

local function GetUnitRole(unit)
  return isiLiveUnits.GetUnitRole(unit)
end

local function TruncateName(name, maxChars)
  return isiLiveUnits.TruncateName(name, maxChars)
end

local function GetUnitNameAndRealm(unit)
  return isiLiveUnits.GetUnitNameAndRealm(unit)
end

local function GetPlayerSpecName()
  return isiLiveUnits.GetPlayerSpecName()
end

local function GetInspectSpecName(unit)
  return isiLiveUnits.GetInspectSpecName(unit)
end

local function GetUnitRio(unit)
  return isiLiveUnits.GetUnitRio(unit)
end

local function BuildDummyRoster()
  return isiLiveDemo.BuildDummyRoster({
    getUnitNameAndRealm = GetUnitNameAndRealm,
    getUnitServerLanguage = function(unit, realm)
      return isiLiveLocale.GetUnitServerLanguage(unit, realm, GetRealmInfoLib)
    end,
    getUnitRole = GetUnitRole,
    getPlayerSpecName = GetPlayerSpecName,
    getUnitRio = GetUnitRio,
  })
end

local UpdateStatusLine
local UpdateUI
local ShowQueueJoinPreview
local UpdateDMResetButton
local UpdateLeaderButtons
local OnEvent
local ApplyLocalizationToUI
local toggleBindingButton
local testModeBindingButton
local pendingBindingApply = false
local bindingOwnerFrame = CreateFrame("Frame", "isiLiveBindingOwnerFrame", UIParent)
local bindingWatchTicker

local function ApplyHotkeyBindings()
  if not (toggleBindingButton and testModeBindingButton) then
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    pendingBindingApply = true
    return
  end

  if ClearOverrideBindings then
    ClearOverrideBindings(bindingOwnerFrame)
  end
  SetOverrideBindingClick(bindingOwnerFrame, true, "CTRL-F9", "isiLiveToggleBindingButton", "LeftButton")
  SetOverrideBindingClick(bindingOwnerFrame, true, "CTRL-ALT-F9", "isiLiveTestModeBindingButton", "LeftButton")
  SetOverrideBindingClick(bindingOwnerFrame, true, "ALT-CTRL-F9", "isiLiveTestModeBindingButton", "LeftButton")
  pendingBindingApply = false
end

local function ExpectedBindingPresent()
  local a1 = GetBindingAction("CTRL-F9", true)
  local a2 = GetBindingAction("CTRL-ALT-F9", true)
  local a3 = GetBindingAction("ALT-CTRL-F9", true)
  local ok1 = a1 and a1:find("isiLiveToggleBindingButton", 1, true)
  local ok2 = (a2 and a2:find("isiLiveTestModeBindingButton", 1, true))
    or (a3 and a3:find("isiLiveTestModeBindingButton", 1, true))
  return ok1 and ok2
end

local function StartBindingWatchdog()
  if bindingWatchTicker or not C_Timer or not C_Timer.NewTicker then
    return
  end
  bindingWatchTicker = C_Timer.NewTicker(5, function()
    if not ExpectedBindingPresent() then
      if InCombatLockdown and InCombatLockdown() then
        pendingBindingApply = true
      else
        ApplyHotkeyBindings()
      end
    end
  end)
end

local CENTER_NOTICE_MIN_HEIGHT = 70
local CENTER_NOTICE_MAX_HEIGHT = 220
local CENTER_NOTICE_PADDING_X = 20
local CENTER_NOTICE_PADDING_Y = 12
local CENTER_NOTICE_BUTTON_HEIGHT = 36
local CENTER_NOTICE_BUTTON_GAP = 8
local ResolveSeason3TeleportSpellIDByActivityID = isiLiveTeleport.ResolveSeason3TeleportSpellIDByActivityID
local ResolveSeason3TeleportSpellID = isiLiveTeleport.ResolveSeason3TeleportSpellID
local ApplySecureSpellToButton = isiLiveTeleport.ApplySecureSpellToButton

local centerNotice = isiLiveNotice.CreateCenterNotice({
  parent = UIParent,
  minHeight = CENTER_NOTICE_MIN_HEIGHT,
  maxHeight = CENTER_NOTICE_MAX_HEIGHT,
  paddingX = CENTER_NOTICE_PADDING_X,
  paddingY = CENTER_NOTICE_PADDING_Y,
  buttonHeight = CENTER_NOTICE_BUTTON_HEIGHT,
  buttonGap = CENTER_NOTICE_BUTTON_GAP,
  isInCombat = function()
    return InCombatLockdown and InCombatLockdown()
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
local centerNoticeFrame = centerNotice.frame
local centerNoticeTeleportButton = centerNotice.teleportButton
local function SetCenterNoticeVisible(visible)
  centerNotice.SetVisible(visible)
end
local function UpdateCenterTeleportButtonVisual(spellID, isEnabled, inCombatBlocked)
  centerNotice.UpdateTeleportButtonVisual(spellID, isEnabled, inCombatBlocked)
end
local function ShowCenterNotice(message, durationSeconds, dungeonName, activityID)
  centerNotice.Show(message, durationSeconds, dungeonName, activityID)
end

local inviteHint = isiLiveNotice.CreateInviteHint({
  parent = UIParent,
  mainFrameGlobalName = "isiLiveMainFrame",
})

local function ShowInviteHint(message, durationSeconds)
  inviteHint.Show(message, durationSeconds)
end

-- --- UI Elements ---
local mainFrame
local mainUI = isiLiveUI.CreateMainFrame({
  minHeight = MIN_FRAME_HEIGHT,
  parent = UIParent,
  isInCombat = function()
    return InCombatLockdown and InCombatLockdown()
  end,
  onShownInGroup = function()
    local onEventHandler = mainFrame:GetScript("OnEvent")
    if onEventHandler then
      onEventHandler(mainFrame, "GROUP_ROSTER_UPDATE")
    end
  end,
  onShownNoGroup = function()
    UpdateUI()
    UpdateLeaderButtons()
  end,
})
mainFrame = mainUI.frame
local function SetMainFrameVisible(visible)
  mainUI.SetVisible(visible)
end
local function SetMainFrameHeightSafe(height)
  mainUI.SetHeightSafe(height)
end

local function ToggleMainFrameVisibility()
  mainUI.ToggleVisibility(IsInGroup())
end

-- Background for visibility
local bg = mainFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.5)

-- Title
local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
title:SetPoint("TOP", 0, -4)
title:SetTextColor(1, 0.85, 0)
title:SetShadowOffset(1, -1)
title:SetText(L.TITLE)

-- Column headers
local SPEC_COL_X = 10
local NAME_COL_X = 118
local SERVER_COL_X = 245
local ILVL_COL_X = 315
local RIO_COL_X = 352
local SPEC_COL_WIDTH = 100
local NAME_COL_WIDTH = 120
local SERVER_COL_WIDTH = 62
local ILVL_COL_WIDTH = 35
local RIO_COL_WIDTH = 55

local specHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
specHeader:SetPoint("TOPLEFT", SPEC_COL_X, -34)
specHeader:SetWidth(SPEC_COL_WIDTH)
specHeader:SetJustifyH("RIGHT")
specHeader:SetText(L.COL_SPEC)

local nameHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameHeader:SetPoint("TOPLEFT", NAME_COL_X, -34)
nameHeader:SetWidth(NAME_COL_WIDTH)
nameHeader:SetJustifyH("LEFT")
nameHeader:SetText(L.COL_NAME)

local ilvlHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ilvlHeader:SetPoint("TOPLEFT", ILVL_COL_X, -34)
ilvlHeader:SetWidth(ILVL_COL_WIDTH)
ilvlHeader:SetJustifyH("RIGHT")
ilvlHeader:SetText(L.COL_ILVL)

local serverHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
serverHeader:SetPoint("TOPLEFT", SERVER_COL_X, -34)
serverHeader:SetWidth(SERVER_COL_WIDTH)
serverHeader:SetJustifyH("LEFT")
serverHeader:SetText(L.COL_LANGUAGE)

local rioHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rioHeader:SetPoint("TOPLEFT", RIO_COL_X, -34)
rioHeader:SetWidth(RIO_COL_WIDTH)
rioHeader:SetJustifyH("RIGHT")
rioHeader:SetText(L.COL_RIO)

local leadOptionsHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
leadOptionsHeader:SetPoint("TOPRIGHT", -150, -34)
leadOptionsHeader:SetWidth(120)
leadOptionsHeader:SetJustifyH("CENTER")
leadOptionsHeader:SetText(L.LEAD_OPTIONS)

local mplusManagementHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
mplusManagementHeader:SetPoint("TOPRIGHT", -16, -34)
mplusManagementHeader:SetWidth(110)
mplusManagementHeader:SetJustifyH("CENTER")
mplusManagementHeader:SetText(L.MPLUS_MANAGEMENT)

local readyCheckButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
readyCheckButton:SetSize(120, 24)
readyCheckButton:SetPoint("TOPRIGHT", -146, -60)
readyCheckButton:SetText(L.BTN_READYCHECK)
readyCheckButton:SetScript("OnClick", function()
  if not IsPlayerLeader() then
    return
  end
  DoReadyCheck()
end)
readyCheckButton:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(L.BTN_READYCHECK)
  GameTooltip:AddLine(L.TOOLTIP_READY, 1, 1, 1, true)
  if not IsPlayerLeader() then
    GameTooltip:AddLine(L.TOOLTIP_LEAD_REQUIRED, 1, 0.2, 0.2, true)
  end
  GameTooltip:Show()
end)
readyCheckButton:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

local countdownButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
countdownButton:SetSize(120, 24)
countdownButton:SetPoint("TOPRIGHT", -146, -90)
countdownButton:SetText(L.BTN_COUNTDOWN10)
countdownButton:SetScript("OnClick", function()
  if not IsPlayerLeader() then
    return
  end
  C_PartyInfo.DoCountdown(10)
end)
countdownButton:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(L.BTN_COUNTDOWN10)
  GameTooltip:AddLine(L.TOOLTIP_CD10, 1, 1, 1, true)
  if not IsPlayerLeader() then
    GameTooltip:AddLine(L.TOOLTIP_LEAD_REQUIRED, 1, 0.2, 0.2, true)
  end
  GameTooltip:Show()
end)
countdownButton:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

local refreshButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
refreshButton:SetSize(120, 24)
refreshButton:SetPoint("TOPRIGHT", -146, -120)
refreshButton:SetText(L.BTN_REFRESH)
refreshButton:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(L.BTN_REFRESH)
  GameTooltip:AddLine(L.TOOLTIP_REFRESH, 1, 1, 1, true)
  GameTooltip:Show()
end)
refreshButton:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

local dmResetToggleButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
dmResetToggleButton:SetSize(120, 24)
dmResetToggleButton:SetPoint("TOPRIGHT", -146, -150)
dmResetToggleButton:SetText(L.BTN_DMRESET_OFF)
dmResetToggleButton:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(L.TOOLTIP_DMRESET)
  GameTooltip:Show()
end)
dmResetToggleButton:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

local mplusTeleportButtons = {}

local function CreateMPlusTeleportButton(index, entry)
  local size = 28
  local colCount = 2
  local col = (index - 1) % colCount
  local row = math.floor((index - 1) / colCount)
  local x = (col == 0) and -85 or -53
  local y = -60 - (row * (size + 4))

  local button = CreateFrame("Button", nil, mainFrame, "SecureActionButtonTemplate")
  button:SetSize(size, size)
  button:SetPoint("TOPRIGHT", x, y)
  button:EnableMouse(true)
  button:RegisterForClicks("AnyDown", "AnyUp")
  button:SetFrameStrata("HIGH")
  button:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
  button.spellID = entry.spellID
  button.mapID = entry.mapID
  button.mapName = entry.mapName
  button.isActiveTarget = false
  ApplySecureSpellToButton(button, entry.spellID)

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints()
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

  button.overlay = button:CreateTexture(nil, "OVERLAY")
  button.overlay:SetAllPoints()
  button.overlay:SetColorTexture(0, 0, 0, 0.35)

  button.activeBorder = button:CreateTexture(nil, "OVERLAY")
  button.activeBorder:SetAllPoints()
  button.activeBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  button.activeBorder:SetBlendMode("ADD")
  button.activeBorder:SetVertexColor(1, 0.85, 0.1, 1)
  button.activeBorder:Hide()

  button.activeGlow = button:CreateTexture(nil, "OVERLAY")
  button.activeGlow:SetAllPoints()
  button.activeGlow:SetTexture("Interface\\AddOns\\Blizzard_SharedXML\\Shared\\CircularGlow")
  button.activeGlow:SetBlendMode("ADD")
  button.activeGlow:SetVertexColor(1, 0.78, 0.08, 0.9)
  button.activeGlow:Hide()

  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.spellID and IsSpellKnownSafe(self.spellID) then
      GameTooltip:SetSpellByID(self.spellID)
      GameTooltip:AddLine(L.TOOLTIP_TELEPORT_CAST, 1, 1, 1, true)
      local remaining = GetTeleportCooldownRemaining(self.spellID)
      if remaining > 0 then
        GameTooltip:AddLine(
          string.format(L.TOOLTIP_TELEPORT_COOLDOWN, FormatCooldownSeconds(remaining)),
          1,
          0.82,
          0,
          true
        )
      else
        GameTooltip:AddLine(L.TOOLTIP_TELEPORT_READY, 0.3, 1, 0.3, true)
      end
    else
      GameTooltip:SetText(L.BTN_TELEPORT_LOCKED)
      GameTooltip:AddLine(L.TOOLTIP_TELEPORT_LOCKED, 1, 0.25, 0.25, true)
    end
    if self.isActiveTarget then
      GameTooltip:AddLine(L.TOOLTIP_TELEPORT_ACTIVE_TARGET, 1, 0.85, 0.2, true)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  button:SetScript("OnUpdate", function(self, elapsed)
    if not self.isActiveTarget then
      self.activeBorder:Hide()
      self.activeGlow:Hide()
      self:SetScale(1)
      return
    end
    self.activeBorder:Show()
    self.activeGlow:Show()
    self._pulse = ((self._pulse or 0) + elapsed * 4) % (math.pi * 2)
    local wave = math.sin(self._pulse)
    self.activeBorder:SetAlpha(0.6 + (wave * 0.35))
    self.activeGlow:SetAlpha(0.5 + (wave * 0.4))
    self:SetScale(1.03 + (wave * 0.03))
  end)

  return button
end

for i, entry in ipairs(isiLiveTeleport.BuildSeason3TeleportEntries()) do
  table.insert(mplusTeleportButtons, CreateMPlusTeleportButton(i, entry))
end

local statusLine = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statusLine:SetPoint("BOTTOMLEFT", 10, 10)
statusLine:SetJustifyH("LEFT")
statusLine:SetText("")

local function GetAddonVersionText()
  return "V." .. GetAddonVersionRaw()
end

local ISILIVE_SYNC_MARKER = " |cff33aaff<3|r"
local ISILIVE_SYNC_FULL_MARKER = " |cff00e68a[fullsync]|r"

local versionLine = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
versionLine:SetPoint("BOTTOMRIGHT", -10, 10)
versionLine:SetJustifyH("RIGHT")
versionLine:SetText(GetAddonVersionText())

UpdateLeaderButtons = function()
  local enabled = IsPlayerLeader()
  readyCheckButton:SetEnabled(enabled)
  countdownButton:SetEnabled(enabled)
  readyCheckButton:SetAlpha(enabled and 1 or 0.45)
  countdownButton:SetAlpha(enabled and 1 or 0.45)
  UpdateStatusLine()
end

-- Member Rows (Reuse pool or fixed list)
local memberRows = {}

local function CreateMemberRow(index)
  local yOffset = -52 - (index - 1) * 16
  local row = {}

  row.spec = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.spec:SetPoint("TOPLEFT", SPEC_COL_X, yOffset)
  row.spec:SetJustifyH("RIGHT")
  row.spec:SetWidth(SPEC_COL_WIDTH)

  row.name = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.name:SetPoint("TOPLEFT", NAME_COL_X, yOffset)
  row.name:SetJustifyH("LEFT")
  row.name:SetWidth(NAME_COL_WIDTH)

  row.ilvl = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.ilvl:SetPoint("TOPLEFT", ILVL_COL_X, yOffset)
  row.ilvl:SetWidth(ILVL_COL_WIDTH)
  row.ilvl:SetJustifyH("RIGHT")

  row.rio = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.rio:SetPoint("TOPLEFT", RIO_COL_X, yOffset)
  row.rio:SetWidth(RIO_COL_WIDTH)
  row.rio:SetJustifyH("RIGHT")

  row.realm = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.realm:SetPoint("TOPLEFT", SERVER_COL_X, yOffset)
  row.realm:SetWidth(SERVER_COL_WIDTH)
  row.realm:SetJustifyH("LEFT")

  memberRows[index] = row
  return row
end

-- --- Data & State ---
-- Stores current group members keyed by unit token.
local roster = {}
local inspectController = isiLiveInspect.CreateController({
  inspectTimeout = INSPECT_TIMEOUT,
  retryInterval = RETRY_INTERVAL,
  inspectDelay = INSPECT_DELAY,
})
local InspectLoop
local wasGroupLeader = nil
local wasInGroup = false
local pendingQueueJoinInfo = nil
local latestQueueDungeonName = nil
local latestQueueActivityID = nil
local latestQueueTeleportSpellID = nil
local isTestMode = false
local isStopped = false
local isPaused = false

local function MarkIsiLiveUser(name, realm)
  isiLiveSync.MarkUser(name, realm)
end

local function UnitHasIsiLive(unit)
  return isiLiveSync.IsUnitKnown(GetUnitNameAndRealm, unit)
end

local function RegisterIsiLiveSyncPrefix()
  isiLiveSync.RegisterPrefix()
end

local function SendIsiLiveHello(force)
  isiLiveSync.SendHello({
    force = force and true or false,
    isVisible = mainFrame and mainFrame:IsShown(),
    version = GetAddonVersionRaw(),
  })
end

local function IsAutoDamageMeterResetEnabled()
  return IsiLiveDB and IsiLiveDB.autoDamageMeterReset == true
end

local function SetAutoDamageMeterResetEnabled(enabled)
  if not IsiLiveDB then
    IsiLiveDB = {}
  end
  IsiLiveDB.autoDamageMeterReset = enabled and true or false
end

UpdateDMResetButton = function()
  if not dmResetToggleButton then
    return
  end
  local enabled = IsAutoDamageMeterResetEnabled()
  dmResetToggleButton:SetText(enabled and L.BTN_DMRESET_ON or L.BTN_DMRESET_OFF)
end

local function ResolveActiveTeleportSpellID()
  if latestQueueTeleportSpellID then
    return latestQueueTeleportSpellID
  end

  if pendingQueueJoinInfo and pendingQueueJoinInfo.teleportSpellID then
    return pendingQueueJoinInfo.teleportSpellID
  end

  local queueSpellID = ResolveSeason3TeleportSpellID(latestQueueActivityID, latestQueueDungeonName)
  if queueSpellID then
    return queueSpellID
  end

  return nil
end

local function UpdateMPlusTeleportButton()
  local resolvedSpellID = ResolveActiveTeleportSpellID()

  for _, button in ipairs(mplusTeleportButtons) do
    local known = IsSpellKnownSafe(button.spellID)
    button.isActiveTarget = (resolvedSpellID and button.spellID == resolvedSpellID) and true or false
    button:Enable()

    if known then
      if button.isActiveTarget then
        button.overlay:SetColorTexture(1, 0.72, 0.05, 0.22)
      else
        button.overlay:SetColorTexture(0, 0, 0, 0.28)
      end
    else
      button.overlay:SetColorTexture(0, 0, 0, 0.62)
    end
  end
end

ApplyLocalizationToUI = function()
  title:SetText(L.TITLE)
  specHeader:SetText(L.COL_SPEC)
  nameHeader:SetText(L.COL_NAME)
  serverHeader:SetText(L.COL_LANGUAGE)
  ilvlHeader:SetText(L.COL_ILVL)
  rioHeader:SetText(L.COL_RIO)
  leadOptionsHeader:SetText(L.LEAD_OPTIONS)
  mplusManagementHeader:SetText(L.MPLUS_MANAGEMENT)
  readyCheckButton:SetText(L.BTN_READYCHECK)
  countdownButton:SetText(L.BTN_COUNTDOWN10)
  refreshButton:SetText(L.BTN_REFRESH)
  UpdateDMResetButton()
  if centerNoticeTeleportButton and centerNoticeTeleportButton:IsShown() then
    local spellID = centerNoticeTeleportButton.spellID
    local enabled = spellID and IsSpellKnownSafe(spellID) and not centerNoticeTeleportButton.inCombatBlocked
    UpdateCenterTeleportButtonVisual(spellID, enabled, centerNoticeTeleportButton.inCombatBlocked)
  end
  UpdateMPlusTeleportButton()
  UpdateStatusLine()
end

dmResetToggleButton:SetScript("OnClick", function()
  local newValue = not IsAutoDamageMeterResetEnabled()
  SetAutoDamageMeterResetEnabled(newValue)
  UpdateDMResetButton()
  Print(newValue and L.DMRESET_ENABLED or L.DMRESET_DISABLED)
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

local function PlayLeadTransferSound()
  if not PlaySound then
    return
  end
  if SOUNDKIT and SOUNDKIT.RAID_WARNING then
    PlaySound(SOUNDKIT.RAID_WARNING, "Master")
    return
  end
  if SOUNDKIT and SOUNDKIT.READY_CHECK then
    PlaySound(SOUNDKIT.READY_CHECK, "Master")
  end
end

refreshButton:SetScript("OnClick", function()
  if isStopped or isPaused then
    return
  end
  if IsInGroup() and next(roster) == nil then
    local onEventHandler = mainFrame:GetScript("OnEvent")
    if onEventHandler then
      onEventHandler(mainFrame, "GROUP_ROSTER_UPDATE")
    end
  end
  QueueForceRefreshData()
  UpdateUI()
end)

local ROLE_PRIORITY = {
  TANK = 1,
  HEALER = 2,
  DAMAGER = 3,
  NONE = 4,
}

local UNIT_PRIORITY = {
  player = 1,
  party1 = 2,
  party2 = 3,
  party3 = 4,
  party4 = 5,
}

local function GetUnitServerLanguage(unit, realm)
  return isiLiveLocale.GetUnitServerLanguage(unit, realm, GetRealmInfoLib)
end

local function UpdatePendingQueueJoin(groupName, dungeonName, priority, activityID)
  local oldPriority = pendingQueueJoinInfo and pendingQueueJoinInfo.priority or 0
  if priority < oldPriority then
    return
  end

  local previous = pendingQueueJoinInfo

  -- Only carry dungeon forward when it is clearly the same group to avoid cross-application mixups.
  if
    previous
    and previous.dungeonName
    and not dungeonName
    and groupName
    and previous.groupName
    and groupName == previous.groupName
  then
    dungeonName = previous.dungeonName
  end

  if not activityID and groupName and previous and previous.groupName and groupName == previous.groupName then
    activityID = previous.activityID
  end

  local resolvedTeleportSpellID = ResolveSeason3TeleportSpellID(activityID, dungeonName)
  if not resolvedTeleportSpellID and previous then
    local sameGroup = (not groupName) or not previous.groupName or (groupName == previous.groupName)
    if sameGroup then
      dungeonName = dungeonName or previous.dungeonName
      activityID = activityID or previous.activityID
      resolvedTeleportSpellID = previous.teleportSpellID
    end
  end

  pendingQueueJoinInfo = {
    groupName = groupName or (previous and previous.groupName) or nil,
    dungeonName = dungeonName,
    activityID = activityID,
    teleportSpellID = resolvedTeleportSpellID,
    priority = priority,
    capturedAt = GetTime(),
  }

  -- Update highlight target immediately when an invite-like queue signal is captured.
  latestQueueDungeonName = pendingQueueJoinInfo.dungeonName
  latestQueueActivityID = pendingQueueJoinInfo.activityID
  latestQueueTeleportSpellID = pendingQueueJoinInfo.teleportSpellID

  local groupText = string.format(L.INVITE_HINT_GROUP, pendingQueueJoinInfo.groupName or L.UNKNOWN_GROUP)
  local dungeonText = pendingQueueJoinInfo.dungeonName
      and string.format(L.INVITE_HINT_DUNGEON, pendingQueueJoinInfo.dungeonName)
    or L.INVITE_HINT_UNKNOWN_DUNGEON
  ShowInviteHint(groupText .. "\n" .. dungeonText, 10)
  UpdateMPlusTeleportButton()
end

local function CaptureQueueJoinCandidate(...)
  isiLiveQueue.CaptureQueueJoinCandidate(UpdatePendingQueueJoin, ResolveSeason3TeleportSpellIDByActivityID, ...)
end

local function AnnounceQueuedGroupJoin()
  if not pendingQueueJoinInfo then
    return
  end

  local groupName = pendingQueueJoinInfo.groupName or L.UNKNOWN_GROUP
  local dungeonName = pendingQueueJoinInfo.dungeonName
  local activityID = pendingQueueJoinInfo.activityID
  ShowQueueJoinPreview(groupName, dungeonName, activityID)

  pendingQueueJoinInfo = nil
end

ShowQueueJoinPreview = function(groupName, dungeonName, activityID)
  local group = groupName or L.UNKNOWN_GROUP
  local dungeon = dungeonName

  latestQueueDungeonName = dungeon
  latestQueueActivityID = activityID
  latestQueueTeleportSpellID = ResolveSeason3TeleportSpellID(activityID, dungeon)
  UpdateMPlusTeleportButton()

  local msg
  if dungeon and dungeon ~= "" then
    msg = string.format(L.JOINED_FROM_QUEUE_DUNGEON, group, dungeon)
  else
    msg = string.format(L.JOINED_FROM_QUEUE, group)
  end

  local separator = "|cffffffff----------------------------------------|r"
  Print(separator)
  Print("|cffffffff" .. L.CHAT_QUEUE_PREFIX .. " | " .. msg .. "|r")
  Print(separator)
  ShowCenterNotice(msg, 20, dungeon, activityID)
  ShowInviteHint(
    string.format(L.INVITE_HINT_GROUP, group)
      .. "\n"
      .. (dungeon and string.format(L.INVITE_HINT_DUNGEON, dungeon) or L.INVITE_HINT_UNKNOWN_DUNGEON),
    10
  )
end

local function EnterFullDummyPreview()
  isTestMode = true
  isTestAllMode = true
  roster = BuildDummyRoster()
  SetMainFrameVisible(true)
  UpdateUI()
  UpdateLeaderButtons()

  ShowCenterNotice(L.LEAD_TRANSFERRED_CENTER, 20)
  ShowQueueJoinPreview(L.TESTALL_DUMMY_GROUP, L.TESTALL_DUMMY_DUNGEON)
  Print(L.CHAT_QUEUE_PREFIX .. " | " .. L.TESTALL_CHAT_ACTIVE)
end

local function ToggleStandardTestMode()
  if isStopped then
    Print(L.ERR_STOPPED_TEST)
    return
  end
  if isPaused then
    Print(L.ERR_PAUSED_TEST)
    return
  end

  isTestAllMode = false
  isTestMode = not isTestMode
  if isTestMode then
    Print(L.TEST_ENABLED)
    roster = BuildDummyRoster()
    SetMainFrameVisible(true)
    UpdateUI()
    UpdateLeaderButtons()
    ShowQueueJoinPreview(L.TESTALL_DUMMY_GROUP, L.TESTALL_DUMMY_DUNGEON)
  else
    Print(L.TEST_DISABLED)
    SetMainFrameVisible(false)
    local onEventHandler = mainFrame:GetScript("OnEvent")
    if onEventHandler then
      onEventHandler(mainFrame, "GROUP_ROSTER_UPDATE")
    end
  end
end

local function SetLanguage(tag)
  local resolved = isiLiveLocale.ResolveLocaleTag(tag)
  L = locales[resolved] or locales.enUS
  if IsiLiveDB then
    IsiLiveDB.locale = resolved
  end
  ApplyLocalizationToUI()
  Print(resolved == "deDE" and L.LANG_SET_DE or L.LANG_SET_EN)
end

local function PrintTeleportDebug()
  local resolvedSpellID = ResolveActiveTeleportSpellID()
  local resolvedKnown = resolvedSpellID and IsSpellKnownSafe(resolvedSpellID) or false
  local resolvedCooldown = resolvedSpellID and GetTeleportCooldownRemaining(resolvedSpellID) or 0

  local function DumpButtonState(label, button)
    if not button then
      Print(label .. ": <missing>")
      return
    end
    local attrType = button:GetAttribute("type")
    local attrSpell = button:GetAttribute("spell")
    local spellID = button.spellID
    local known = spellID and IsSpellKnownSafe(spellID) or false
    local cooldown = spellID and GetTeleportCooldownRemaining(spellID) or 0
    Print(
      string.format(
        "%s shown=%s spellID=%s attr(type=%s spell=%s) known=%s cd=%s active=%s map=%s",
        label,
        tostring(button:IsShown()),
        tostring(spellID),
        tostring(attrType),
        tostring(attrSpell),
        tostring(known),
        FormatCooldownSeconds(cooldown),
        tostring(button.isActiveTarget == true),
        tostring(button.mapName)
      )
    )
  end

  Print(
    string.format(
      "TP target dungeon=%s activityID=%s queueSpellID=%s resolvedSpellID=%s known=%s cd=%s inCombat=%s",
      tostring(latestQueueDungeonName),
      tostring(latestQueueActivityID),
      tostring(latestQueueTeleportSpellID),
      tostring(resolvedSpellID),
      tostring(resolvedKnown),
      FormatCooldownSeconds(resolvedCooldown),
      tostring(InCombatLockdown and InCombatLockdown())
    )
  )
  DumpButtonState("TP center", centerNoticeTeleportButton)
  for i, button in ipairs(mplusTeleportButtons) do
    DumpButtonState("TP grid[" .. i .. "]", button)
  end
end

local function ForceTeleportTestTarget()
  local dungeon = L.TESTALL_DUMMY_DUNGEON or "The Dawnbreaker"
  latestQueueDungeonName = dungeon
  latestQueueActivityID = nil
  latestQueueTeleportSpellID = ResolveSeason3TeleportSpellID(nil, dungeon)
  UpdateMPlusTeleportButton()
  local msg = string.format(L.JOINED_FROM_QUEUE_DUNGEON, L.TESTALL_DUMMY_GROUP or L.UNKNOWN_GROUP, dungeon)
  ShowCenterNotice(msg, 20, dungeon, nil)
  Print("Teleport test target set: " .. tostring(dungeon))
end

UpdateUI = function()
  -- Hide all rows first
  for _, row in pairs(memberRows) do
    row.spec:SetText("")
    row.name:SetText("")
    row.realm:SetText("")
    row.ilvl:SetText("")
    row.rio:SetText("")
  end

  local index = 1
  local orderedRoster = isiLiveRoster.BuildOrderedRoster(roster, ROLE_PRIORITY, UNIT_PRIORITY)
  local hasFullSync = isiLiveRoster.HasFullSync(roster)

  for _, entry in ipairs(orderedRoster) do
    local info = entry.info
    local row = memberRows[index] or CreateMemberRow(index)

    local displayData = isiLiveRoster.BuildDisplayData(info, {
      truncateName = TruncateName,
      getLanguageFlagMarkup = isiLiveLocale.GetLanguageFlagMarkup,
      syncMarker = ISILIVE_SYNC_MARKER,
      fullSyncMarker = ISILIVE_SYNC_FULL_MARKER,
      hasFullSync = hasFullSync,
    })

    row.spec:SetText("|c" .. displayData.colorHex .. displayData.specText .. "|r")
    row.name:SetText("|c" .. displayData.colorHex .. displayData.displayName .. "|r" .. displayData.addonMarker)
    row.realm:SetText(displayData.languageDisplay)
    row.ilvl:SetText(displayData.ilvlText)
    row.rio:SetText(displayData.rioText)

    index = index + 1
  end

  -- Resize frame based on members
  SetMainFrameHeightSafe(math.max(MIN_FRAME_HEIGHT, 45 + index * 16))
end

local function EnqueueInspect(unit)
  inspectController.EnqueueInspect(unit, roster)
end

local function UpdateLeaderState(event)
  local isLeader = IsPlayerLeader()

  if wasGroupLeader == nil then
    wasGroupLeader = isLeader
    return
  end

  if isLeader ~= wasGroupLeader then
    if isLeader then
      if event == "PARTY_LEADER_CHANGED" then
        ShowCenterNotice(L.LEAD_TRANSFERRED_CENTER, 20)
        PlayLeadTransferSound()
      else
        Print(L.LEAD_GAINED)
      end
    else
      Print(L.LEAD_LOST)
    end
    wasGroupLeader = isLeader
  end
  UpdateLeaderButtons()
end

local leaderWatchFrame = CreateFrame("Frame")
leaderWatchFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
leaderWatchFrame:RegisterEvent("PARTY_LEADER_CHANGED")
leaderWatchFrame:SetScript("OnEvent", function(_, event)
  if isStopped then
    wasGroupLeader = nil
    return
  end
  if not mainFrame:IsShown() then
    return
  end
  UpdateLeaderState(event)
end)

-- --- Event Handlers ---
OnEvent = function(self, event, ...)
  if event == "GROUP_ROSTER_UPDATE" then
    local inGroupNow = IsInGroup()
    if inGroupNow and not wasInGroup then
      AnnounceQueuedGroupJoin()
    end
    wasInGroup = inGroupNow

    if C_ChallengeMode.GetActiveChallengeMapID() then
      -- M+ Aktiv: Fenster versteckt lassen
      SetMainFrameVisible(false)
      UpdateLeaderButtons()
      return
    end

    if not IsInGroup() then
      wasGroupLeader = nil
      latestQueueDungeonName = nil
      latestQueueActivityID = nil
      latestQueueTeleportSpellID = nil
      roster = {}
      inspectController.ResetAll()
      UpdateUI() -- Clear the visual list
      UpdateMPlusTeleportButton()
      SetMainFrameVisible(false) -- Hide frame when not in a group
      UpdateLeaderButtons()
      return
    end

    local numMembers = GetNumGroupMembers()
    if numMembers > 5 then
      -- Raid detected (or > 5 members), hide addon
      SetMainFrameVisible(false)
      UpdateLeaderButtons()
      return
    end

    SetMainFrameVisible(true) -- Show frame when in a group
    roster = {}
    inspectController.ResetQueues()

    -- Add player
    local name, realm = GetUnitNameAndRealm("player")
    local _, class = UnitClass("player")
    local language = GetUnitServerLanguage("player", realm)
    MarkIsiLiveUser(name, realm)
    roster["player"] = {
      name = name,
      realm = realm,
      language = language,
      class = class,
      role = GetUnitRole("player"),
      spec = GetPlayerSpecName(),
      ilvl = nil,
      rio = GetUnitRio("player"),
      hasIsiLive = true,
    }
    EnqueueInspect("player")

    -- Add party members
    local members = GetNumGroupMembers()
    for i = 1, members - 1 do
      local unit = "party" .. i
      local memberName, memberRealm = GetUnitNameAndRealm(unit)
      if memberName then
        local _, memberClass = UnitClass(unit)
        local memberLanguage = GetUnitServerLanguage(unit, memberRealm)
        roster[unit] = {
          name = memberName,
          realm = memberRealm,
          language = memberLanguage,
          class = memberClass,
          role = GetUnitRole(unit),
          spec = nil,
          ilvl = nil,
          rio = nil,
          hasIsiLive = UnitHasIsiLive(unit),
        }
        EnqueueInspect(unit)
      end
    end
    UpdateUI()
    UpdateLeaderButtons()
    SendIsiLiveHello(false)
  elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
    CaptureQueueJoinCandidate(...)
  elseif event == "CHALLENGE_MODE_START" then
    local damageMeterApi = _G and _G.C_DamageMeter
    if
      IsAutoDamageMeterResetEnabled()
      and damageMeterApi
      and damageMeterApi.IsDamageMeterAvailable
      and damageMeterApi.ResetAllCombatSessions
    then
      local okAvailable, isAvailable = pcall(damageMeterApi.IsDamageMeterAvailable)
      if okAvailable and isAvailable then
        pcall(damageMeterApi.ResetAllCombatSessions)
      end
    end
    SetMainFrameVisible(false)
    UpdateLeaderButtons()
  elseif event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
    if IsInGroup() then
      SetMainFrameVisible(true)
      local onEventHandler = self:GetScript("OnEvent")
      if onEventHandler then
        onEventHandler(self, "GROUP_ROSTER_UPDATE") -- Refresh roster
      end
    else
      UpdateLeaderButtons()
    end
  elseif event == "ADDON_LOADED" then
    local loadedAddon = ...
    if loadedAddon == addonName then
      -- Initialize DB
      IsiLiveDB = IsiLiveDB or {}
      IsiLiveDB.position = IsiLiveDB.position or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
      IsiLiveDB.centerNoticePosition = IsiLiveDB.centerNoticePosition
        or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
      IsiLiveDB.locale = isiLiveLocale.ResolveLocaleTag(IsiLiveDB.locale or locale)
      L = locales[IsiLiveDB.locale] or locales.enUS
      if IsiLiveDB.autoDamageMeterReset == nil then
        IsiLiveDB.autoDamageMeterReset = false
      end

      -- Restore position
      local pos = IsiLiveDB.position
      mainFrame:ClearAllPoints()
      mainFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)

      local centerPos = IsiLiveDB.centerNoticePosition
      centerNotice.ApplyStoredPosition(centerPos)
      RegisterIsiLiveSyncPrefix()
      ApplyHotkeyBindings()
      StartBindingWatchdog()
      ApplyLocalizationToUI()
      UpdateDMResetButton()
      UpdateLeaderButtons()
    end
  elseif event == "PLAYER_LOGIN" then
    RegisterIsiLiveSyncPrefix()
    local playerName, playerRealm = GetUnitNameAndRealm("player")
    MarkIsiLiveUser(playerName, playerRealm)
    ApplyHotkeyBindings()
    StartBindingWatchdog()
  elseif event == "PLAYER_ENTERING_WORLD" then
    ApplyHotkeyBindings()
    StartBindingWatchdog()
    if C_Timer and C_Timer.After then
      C_Timer.After(1, ApplyHotkeyBindings)
      C_Timer.After(3, ApplyHotkeyBindings)
      C_Timer.After(2, function()
        SendIsiLiveHello(true)
      end)
    end
    statusController.MaybeShowNonMythicDungeonEntryNotice()
  elseif event == "UPDATE_BINDINGS" then
    ApplyHotkeyBindings()
  elseif event == "PLAYER_REGEN_ENABLED" then
    if pendingBindingApply then
      ApplyHotkeyBindings()
    end
    local pendingMainFrameHeight = mainUI.GetPendingHeight()
    if pendingMainFrameHeight then
      SetMainFrameHeightSafe(pendingMainFrameHeight)
    end
    local pendingMainFrameVisible = mainUI.GetPendingVisible()
    if pendingMainFrameVisible ~= nil then
      SetMainFrameVisible(pendingMainFrameVisible)
    end
    local pendingCenterNoticeVisible = centerNotice.GetPendingVisible()
    if pendingCenterNoticeVisible ~= nil then
      SetCenterNoticeVisible(pendingCenterNoticeVisible)
    end
    UpdateMPlusTeleportButton()
    if
      centerNoticeFrame
      and centerNoticeFrame:IsShown()
      and centerNoticeTeleportButton
      and centerNoticeTeleportButton.spellID
    then
      ApplySecureSpellToButton(centerNoticeTeleportButton, centerNoticeTeleportButton.spellID)
      centerNoticeTeleportButton:Enable()
    end
  elseif
    event == "PLAYER_DIFFICULTY_CHANGED"
    or event == "ZONE_CHANGED_NEW_AREA"
    or event == "UPDATE_INSTANCE_INFO"
  then
    UpdateStatusLine()
    statusController.MaybeShowNonMythicDungeonEntryNotice()
  elseif event == "INSPECT_READY" then
    if not mainFrame:IsShown() then
      return
    end

    local guid = ...
    if inspectController.OnInspectReady(guid, roster, GetUnitRio, GetInspectSpecName, GetPlayerSpecName) then
      UpdateUI()
    end
  elseif event == "CHAT_MSG_ADDON" then
    local prefix, message, _, sender = ...
    local localName, localRealm = GetUnitNameAndRealm("player")
    local syncResult = isiLiveSync.ProcessAddonMessage(prefix, message, sender, localName, localRealm)
    if not syncResult then
      return
    end

    if syncResult.shouldAck then
      if
        C_ChatInfo
        and C_ChatInfo.SendAddonMessage
        and type(syncResult.sender) == "string"
        and syncResult.sender ~= ""
      then
        C_ChatInfo.SendAddonMessage(
          isiLiveSync.GetPrefix(),
          "ACK:" .. GetAddonVersionRaw(),
          "WHISPER",
          syncResult.sender
        )
      end
    end

    local changed = false
    for _, info in pairs(roster) do
      if not info.hasIsiLive and isiLiveSync.IsUserKnown(info.name, info.realm) then
        info.hasIsiLive = true
        changed = true
      end
    end
    if changed then
      UpdateUI()
    end
  end
end

-- --- Inspect Loop ---
InspectLoop = function()
  inspectController.OnUpdate()
end

mainFrame:RegisterEvent("ADDON_LOADED")
mainFrame:RegisterEvent("PLAYER_LOGIN")
mainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mainFrame:RegisterEvent("UPDATE_BINDINGS")
mainFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
mainFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
mainFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
mainFrame:RegisterEvent("UPDATE_INSTANCE_INFO")
mainFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
mainFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
mainFrame:RegisterEvent("CHAT_MSG_ADDON")
mainFrame:RegisterEvent("INSPECT_READY")
mainFrame:RegisterEvent("CHALLENGE_MODE_START")
mainFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
mainFrame:RegisterEvent("CHALLENGE_MODE_RESET")
mainFrame:SetScript("OnEvent", OnEvent)
mainFrame:SetScript("OnShow", function()
  SetProcessingActive(true)
end)
mainFrame:SetScript("OnHide", function()
  SetProcessingActive(false)
end)

toggleBindingButton = CreateFrame("Button", "isiLiveToggleBindingButton", UIParent)
toggleBindingButton:SetSize(1, 1)
toggleBindingButton:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -100, -100)
toggleBindingButton:SetAlpha(0)
toggleBindingButton:EnableMouse(true)
toggleBindingButton:RegisterForClicks("AnyDown", "AnyUp")
toggleBindingButton:SetScript("OnClick", function(_, _, down)
  if down == false then
    return
  end
  ToggleMainFrameVisibility()
end)

testModeBindingButton = CreateFrame("Button", "isiLiveTestModeBindingButton", UIParent)
testModeBindingButton:SetSize(1, 1)
testModeBindingButton:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -100, -102)
testModeBindingButton:SetAlpha(0)
testModeBindingButton:EnableMouse(true)
testModeBindingButton:RegisterForClicks("AnyDown", "AnyUp")
testModeBindingButton:SetScript("OnClick", function(_, _, down)
  if down == false then
    return
  end
  ToggleStandardTestMode()
end)

ApplyHotkeyBindings()

isiLiveCommands.RegisterSlashCommands({
  printFn = Print,
  getL = function()
    return L
  end,
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
  setMainFrameVisible = SetMainFrameVisible,
  updateLeaderButtons = UpdateLeaderButtons,
  isPlayerLeader = IsPlayerLeader,
  setLanguage = SetLanguage,
  forceTeleportTestTarget = ForceTeleportTestTarget,
  printTeleportDebug = PrintTeleportDebug,
})

local gatedOnEvent = isiLiveEvents.CreateGate({
  dispatch = OnEvent,
  isStopped = function()
    return isStopped
  end,
  isPaused = function()
    return isPaused
  end,
  isTestMode = function()
    return isTestMode
  end,
  allowWhenHidden = {
    ADDON_LOADED = true,
    PLAYER_LOGIN = true,
    PLAYER_ENTERING_WORLD = true,
    UPDATE_BINDINGS = true,
    PLAYER_REGEN_ENABLED = true,
  },
  shouldAllowWhenHidden = function(_, event)
    if event ~= "GROUP_ROSTER_UPDATE" then
      return false
    end
    local inChallenge = C_ChallengeMode
      and C_ChallengeMode.GetActiveChallengeMapID
      and C_ChallengeMode.GetActiveChallengeMapID()
    local inSmallGroup = IsInGroup() and GetNumGroupMembers() <= 5
    return inSmallGroup and not inChallenge
  end,
})
mainFrame:SetScript("OnEvent", gatedOnEvent)

Print(string.format(L.LOADED_HINT, GetAddonVersionRaw()))
