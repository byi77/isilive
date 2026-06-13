local _, addonTable = ...

addonTable = addonTable or {}

local RosterPanel = {}
addonTable.RosterPanel = RosterPanel

addonTable._RosterInternal = addonTable._RosterInternal or {}

-- Trace logger for debug output
local runtimeLog = nil

--- Set trace logger for debug output
function RosterPanel.SetTraceLogger(logger)
  runtimeLog = logger
  -- Share with split render module so it can emit RosterPanel-prefixed traces.
  addonTable._RosterInternal._rosterPanelLogger = logger
end

local function Trace(msg)
  if runtimeLog then
    runtimeLog("RosterPanel: " .. msg)
  end
end

-- Imports from _RosterInternal (set by roster_tooltip.lua and roster_layout.lua).
-- Load-order dependency: isiLive_roster_tooltip.lua and isiLive_roster_layout.lua
-- must appear before this file in isiLive.toc (currently lines 49-50 vs 53).
-- All imports below carry hardcoded fallbacks so a load-order mistake fails
-- gracefully rather than with a nil-dereference crash.
local RI = addonTable._RosterInternal or {}
local ContextHelpers = addonTable.ContextHelpers or {}
local UICommon = addonTable.UICommon or {}

local function GetDB()
  return rawget(_G, "IsiLiveDB")
end

-- Tooltip imports
local CreateRosterHoverTooltip = RI.CreateRosterHoverTooltip or function(...)
  local _ = ...
  return nil
end

-- Layout imports
local LAYOUT_MODE_EXPANDED = RI.LAYOUT_MODE_EXPANDED or "expanded"
local LAYOUT_MODE_COMPACT_VERTICAL = RI.LAYOUT_MODE_COMPACT_VERTICAL or "compact_vertical"
local LAYOUT_MODE_COMPACT_HORIZONTAL = RI.LAYOUT_MODE_COMPACT_HORIZONTAL or "compact_horizontal"
local LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL = RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL or "compact_main_horizontal"
local DEFAULT_LAYOUT_MODE_LAST_USED = "last_used"
local LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL_LEGACY = "compact_horizontal_2"
local FULL_FRAME_WIDTH = RI.FULL_FRAME_WIDTH or 755
local DEFAULT_MIN_FRAME_HEIGHT = RI.DEFAULT_MIN_FRAME_HEIGHT or 236
local NormalizeLayoutMode = RI.NormalizeLayoutMode
  or function(mode)
    if mode == LAYOUT_MODE_COMPACT_VERTICAL then
      return LAYOUT_MODE_COMPACT_VERTICAL
    end
    if mode == LAYOUT_MODE_COMPACT_HORIZONTAL then
      return LAYOUT_MODE_COMPACT_HORIZONTAL
    end
    if mode == LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL or mode == LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL_LEGACY then
      return LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
    end
    return LAYOUT_MODE_EXPANDED
  end
local function ResolveConfiguredDefaultOpenLayoutMode()
  local db = GetDB()
  if type(db) ~= "table" then
    return LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
  end

  local layoutMode = db.rosterDefaultLayoutMode
  if layoutMode == nil or layoutMode == false or layoutMode == "" then
    return LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
  end

  if layoutMode == DEFAULT_LAYOUT_MODE_LAST_USED then
    return DEFAULT_LAYOUT_MODE_LAST_USED
  end

  if layoutMode == LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL_LEGACY then
    return LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
  end

  if
    layoutMode == LAYOUT_MODE_EXPANDED
    or layoutMode == LAYOUT_MODE_COMPACT_VERTICAL
    or layoutMode == LAYOUT_MODE_COMPACT_HORIZONTAL
    or layoutMode == LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
  then
    return layoutMode
  end

  return LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
end
local IsHorizontalCompactLayoutMode = RI.IsHorizontalCompactLayoutMode or function(_mode)
  return false
end
local CreateSystemOptionToggles = RI.CreateSystemOptionToggles
local RefreshSystemOptionToggles = RI.RefreshSystemOptionToggles
local LayoutSystemOptionToggles = RI.LayoutSystemOptionToggles
local AttachSystemOptionToggleWatcher = RI.AttachSystemOptionToggleWatcher
local SetFlatButtonText = RI.SetFlatButtonText or function(_btn, _text) end
local UpdateCollapseState = RI.UpdateCollapseState
local NotifyCollapseChanged = RI.NotifyCollapseChanged
local NotifyLayoutChanged = RI.NotifyLayoutChanged or function(_ui, _layoutMode) end
local CreateModeButton = RI.CreateModeButton
local ApplyFontStringSize = RI.ApplyFontStringSize
local CreateCdTrackerRow = RI.CreateCdTrackerRow
local UpdateCdTrackerRow = RI.UpdateCdTrackerRow
local CreateKillTrackRow = RI.CreateKillTrackRow
local UpdateKillTrackRow = RI.UpdateKillTrackRow
local CreateFlatButton = RI.CreateFlatButton
local CreatePanelHeaders = RI.CreatePanelHeaders
local SetPanelHeaderText = RI.SetPanelHeaderText
  or function(fontString, text)
    if type(fontString) == "table" and type(fontString.SetText) == "function" then
      fontString:SetText(tostring(text or ""))
    end
  end
local CreateM2ColumnGuides = RI.CreateM2ColumnGuides
local AttachPanelButtonTooltip = RI.AttachPanelButtonTooltip
local AttachModeButtonTooltip = RI.AttachModeButtonTooltip
local CreateTankHelperButtons = RI.CreateTankHelperButtons

-- Render imports (defined in isiLive_roster_panel_render.lua).
local RenderRosterImpl = RI.RenderRosterImpl or function(_state, _roster) end
local RefreshReadyCheckStateImpl = RI.RefreshReadyCheckStateImpl or function(_state, _roster) end
local SetKickCellText = RI.SetKickCellText or function(_cell, _info, _getL) end

-- These settings are temporarily hidden from Blizzard Settings.
-- Keep the runtime behavior hard-forced until the controls are re-enabled.
local FORCE_MARKERS_LEADER_ONLY = false

local function RequireFunction(value, name)
  return addonTable.Validators.RequireFunction(value, name, "RosterPanel")
end

local function CreateStatusLine(mainFrame)
  local statusLine = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  statusLine:SetPoint("BOTTOMLEFT", 10, 6)
  statusLine:SetJustifyH("LEFT")
  statusLine:SetText("")
  return statusLine
end

local function AttachControllerAccessors(controller, deps)
  function controller.GetRefreshButton()
    return deps.refreshButton
  end

  function controller.GetCountdownCancelButton()
    return deps.countdownCancelButton
  end

  function controller.GetStatusLine()
    return deps.statusLine
  end

  function controller.SetCountdownCancelText(text)
    SetFlatButtonText(deps.countdownCancelButton, tostring(text or ""))
  end

  function controller.TriggerShareKeysCooldown(seconds)
    local btn = deps.shareKeysButton
    if btn and type(btn.TriggerRemoteCooldown) == "function" then
      btn.TriggerRemoteCooldown(seconds)
    end
  end

  function controller.GetShareKeysCooldownRemaining()
    local btn = deps.shareKeysButton
    if btn and type(btn.GetRemainingCooldown) == "function" then
      return btn.GetRemainingCooldown()
    end
    return 0
  end

  function controller.GetShareKeysLocalCooldownRemaining()
    local btn = deps.shareKeysButton
    if btn and type(btn.GetLocallyOwnedCooldownRemaining) == "function" then
      return btn.GetLocallyOwnedCooldownRemaining()
    end
    return 0
  end

  function controller.ClearShareKeysCooldown()
    local btn = deps.shareKeysButton
    if btn and type(btn.ClearCooldown) == "function" then
      btn.ClearCooldown()
    end
  end
end

local function CreateShareKeysButton(mainFrame, deps)
  local button = CreateFlatButton(mainFrame, 120, 24)
  button:SetPoint("TOPRIGHT", -10, -150)
  button._verticalY = -150
  local countdownTicker = nil
  local cooldownEndAt = nil
  local cooldownLocallyOwned = false
  local shareKeysAvailable = false
  local debounceSeconds = tonumber(deps.shareKeysDebounceSeconds) or 0
  if debounceSeconds < 0 then
    debounceSeconds = 0
  end

  local function GetCurrentTime()
    return type(deps.getTime) == "function" and tonumber(deps.getTime()) or nil
  end

  local function IsCooldownActive(now)
    if debounceSeconds <= 0 then
      return false
    end
    if not now then
      now = GetCurrentTime()
    end
    return now ~= nil and cooldownEndAt ~= nil and cooldownEndAt > now
  end

  local function RefreshShareKeysButton()
    local now = GetCurrentTime()
    local cooldownActive = IsCooldownActive(now)
    if not cooldownActive then
      cooldownEndAt = nil
      cooldownLocallyOwned = false
    end

    if cooldownActive then
      local remaining = math.max(1, math.ceil((cooldownEndAt or 0) - now))
      local label = button._fullText or ""
      SetFlatButtonText(button, string.format("%s (%ds)", label, remaining))
    else
      SetFlatButtonText(button, button._fullText or "")
    end

    local enabled = shareKeysAvailable and not cooldownActive
    button:SetEnabled(enabled)
    if cooldownActive then
      button:SetAlpha(0.5)
    else
      button:SetAlpha(shareKeysAvailable and 1.0 or 0.45)
    end

    if not cooldownActive and countdownTicker then
      countdownTicker:Cancel()
      countdownTicker = nil
    end
  end

  local function StartCooldownDisplay(cooldownEnd)
    if debounceSeconds <= 0 then
      return
    end
    cooldownEndAt = cooldownEnd
    if countdownTicker then
      countdownTicker:Cancel()
      countdownTicker = nil
    end
    local C_Timer_ref = rawget(_G, "C_Timer")
    if not C_Timer_ref or type(C_Timer_ref.NewTicker) ~= "function" then
      RefreshShareKeysButton()
      return
    end
    countdownTicker = C_Timer_ref.NewTicker(1.0, function()
      RefreshShareKeysButton()
    end, debounceSeconds)
    RefreshShareKeysButton()
  end

  function button.TriggerRemoteCooldown(seconds)
    local now = GetCurrentTime()
    if not now or debounceSeconds <= 0 then
      return
    end
    local isRemoteMirror = tonumber(seconds) ~= nil
    local cooldownSeconds = tonumber(seconds) or debounceSeconds
    if cooldownSeconds <= 0 then
      return
    end
    if cooldownSeconds > debounceSeconds then
      cooldownSeconds = debounceSeconds
    end
    -- Max-merge: a remote cooldown may extend the lock but never shorten an
    -- already-running one (multiple peers mirror their remaining time; the
    -- longest lock wins).
    local newCooldownEnd = now + cooldownSeconds
    if IsCooldownActive(now) and cooldownEndAt and cooldownEndAt >= newCooldownEnd then
      return
    end
    -- A lock set or extended by a remote SKCD mirror is not locally owned
    -- and must never be re-broadcast (see GetLocallyOwnedCooldownRemaining).
    cooldownLocallyOwned = not isRemoteMirror
    StartCooldownDisplay(newCooldownEnd)
  end

  function button.GetRemainingCooldown()
    local now = GetCurrentTime()
    if not now or not IsCooldownActive(now) then
      return 0
    end
    return math.max(0, (cooldownEndAt or 0) - now)
  end

  -- Only locally owned locks (own click or received SHAREKEYS request) may
  -- be mirrored to peers via SKCD. Re-broadcasting a lock that itself came
  -- from a remote SKCD mirror would reflect the cooldown between peers
  -- indefinitely once send queues add latency.
  function button.GetLocallyOwnedCooldownRemaining()
    if not cooldownLocallyOwned then
      return 0
    end
    return button.GetRemainingCooldown()
  end

  function button.ClearCooldown()
    cooldownEndAt = nil
    cooldownLocallyOwned = false
    if countdownTicker then
      countdownTicker:Cancel()
      countdownTicker = nil
    end
    RefreshShareKeysButton()
  end

  function button.SetShareKeysAvailable(isAvailable)
    shareKeysAvailable = isAvailable == true
    RefreshShareKeysButton()
  end

  function button.RefreshDisplayText()
    RefreshShareKeysButton()
  end

  button:SetScript("OnClick", function()
    local now = GetCurrentTime()
    if IsCooldownActive(now) then
      return
    end
    local announcedOwnKey = false
    local ownLine = nil
    local inGroup = deps.isInGroup() == true
    local requestedPeers = false
    if inGroup and type(deps.sendShareKeysRequest) == "function" then
      requestedPeers = deps.sendShareKeysRequest() == true
    end
    if type(ContextHelpers.BuildOwnKeystoneAnnounceLine) == "function" then
      ownLine = ContextHelpers.BuildOwnKeystoneAnnounceLine({
        getL = deps.getL,
        getRoster = deps.getRoster,
        getOwnedKeystoneSnapshot = deps.getOwnedKeystoneSnapshot,
        getDungeonShortCode = deps.getDungeonShortCode,
      })
    end
    if ownLine then
      if inGroup then
        local sentOwnKey = ContextHelpers.SendPartyChatMessage(ownLine)
        if not sentOwnKey then
          print(ownLine)
        end
        announcedOwnKey = sentOwnKey == true
      else
        print(ownLine)
        announcedOwnKey = true
      end
    end
    Trace(
      string.format(
        "share_keys_click inGroup=%s requestedPeers=%s announcedOwnKey=%s",
        tostring(inGroup),
        tostring(requestedPeers),
        tostring(announcedOwnKey)
      )
    )
    if not announcedOwnKey and not requestedPeers then
      return
    end
    if now and debounceSeconds > 0 then
      cooldownLocallyOwned = true
      StartCooldownDisplay(now + debounceSeconds)
    end
  end)
  AttachPanelButtonTooltip(deps.tooltipFrame, button, deps.getL, "BTN_SHARE_KEYS", "TOOLTIP_ANNOUNCE_KEYS", nil)
  return button
end

local function CreatePanelButtons(mainFrame, deps)
  local getL = deps.getL
  local isPlayerLeader = deps.isPlayerLeader

  local readyCheckButton = CreateFlatButton(mainFrame, 120, 24, "SecureActionButtonTemplate,BackdropTemplate")
  readyCheckButton:SetPoint("TOPRIGHT", -10, -60)
  readyCheckButton._verticalY = -60
  if type(readyCheckButton.RegisterForClicks) == "function" then
    readyCheckButton:RegisterForClicks("AnyUp", "AnyDown")
  end
  if type(readyCheckButton.SetAttribute) == "function" then
    readyCheckButton:SetAttribute("type", "macro")
    readyCheckButton:SetAttribute("macrotext", "/readycheck")
    readyCheckButton:SetAttribute("type1", "macro")
    readyCheckButton:SetAttribute("macrotext1", "/readycheck")
    readyCheckButton:SetAttribute("type2", "macro")
    readyCheckButton:SetAttribute("macrotext2", "/readycheck")
  end
  if type(readyCheckButton.HookScript) == "function" then
    readyCheckButton:HookScript("OnClick", function()
      if not isPlayerLeader() then
        return
      end
      if type(deps.logRuntimeTrace) == "function" then
        deps.logRuntimeTrace("[UI] btn_click name=readycheck")
      end
    end)
  end
  AttachPanelButtonTooltip(deps.tooltipFrame, readyCheckButton, getL, "BTN_READYCHECK", "TOOLTIP_READY", isPlayerLeader)

  local countdownButton = CreateFlatButton(mainFrame, 120, 24)
  countdownButton:SetPoint("TOPRIGHT", -10, -90)
  countdownButton._verticalY = -90
  countdownButton:SetScript("OnClick", function()
    if not isPlayerLeader() then
      return
    end
    if type(deps.logRuntimeTrace) == "function" then
      deps.logRuntimeTrace("[UI] btn_click name=countdown")
    end
    local partyInfo = rawget(_G, "C_PartyInfo")
    local doCountdown = partyInfo and partyInfo.DoCountdown or nil
    if type(doCountdown) == "function" then
      pcall(doCountdown, 10)
    end
  end)
  AttachPanelButtonTooltip(deps.tooltipFrame, countdownButton, getL, "BTN_COUNTDOWN10", "TOOLTIP_CD10", isPlayerLeader)

  local refreshButton = CreateFlatButton(mainFrame, 120, 24)
  refreshButton:SetPoint("TOPRIGHT", -10, -180)
  refreshButton._verticalY = -180
  AttachPanelButtonTooltip(deps.tooltipFrame, refreshButton, getL, "BTN_REFRESH", "TOOLTIP_REFRESH", nil)

  local shareKeysButton = CreateShareKeysButton(mainFrame, deps)

  local countdownCancelButton = CreateFlatButton(mainFrame, 120, 24)
  countdownCancelButton:SetPoint("TOPRIGHT", -10, -120)
  countdownCancelButton._verticalY = -120
  AttachPanelButtonTooltip(
    deps.tooltipFrame,
    countdownCancelButton,
    getL,
    "BTN_COUNTDOWN_CANCEL",
    "TOOLTIP_CD_CANCEL",
    isPlayerLeader
  )

  return {
    readyCheckButton = readyCheckButton,
    countdownButton = countdownButton,
    refreshButton = refreshButton,
    shareKeysButton = shareKeysButton,
    countdownCancelButton = countdownCancelButton,
  }
end

local function ConstructPanelUI(mainFrame, uiDeps)
  Trace("constructing UI, row_count=5")
  local isRaidGroupFn = uiDeps.isRaidGroup

  -- Background for visibility
  do
    local uiCommon = addonTable and addonTable.UICommon
    if type(uiCommon) == "table" and type(uiCommon.ApplyBackdrop) == "function" then
      uiCommon.ApplyBackdrop(mainFrame, "MAIN_FRAME")
    end
  end
  if mainFrame.SetWidth then
    mainFrame:SetWidth(FULL_FRAME_WIDTH)
  end

  -- All three title elements share the same Y so they sit on one horizontal line.
  local TITLE_Y = -10

  local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 10, TITLE_Y)
  title:SetJustifyH("LEFT")
  title:SetTextColor(1, 0.85, 0)
  title:SetShadowOffset(1, -1)
  if type(title.SetShadowColor) == "function" then
    title:SetShadowColor(0, 0, 0, 0.8)
  end
  ApplyFontStringSize(title, 14)

  local titleVersion = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titleVersion:SetPoint("LEFT", title, "RIGHT", 5, 0)
  titleVersion:SetTextColor(0.55, 0.75, 1.0)
  if type(titleVersion.SetShadowOffset) == "function" then
    titleVersion:SetShadowOffset(1, -1)
  end
  if type(titleVersion.SetShadowColor) == "function" then
    titleVersion:SetShadowColor(0, 0, 0, 0.9)
  end
  ApplyFontStringSize(titleVersion, 14)

  local titleHint = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titleHint:SetPoint("LEFT", titleVersion, "RIGHT", 6, 0)
  titleHint:SetTextColor(0.45, 0.85, 0.45)
  if type(titleHint.SetShadowOffset) == "function" then
    titleHint:SetShadowOffset(1, -1)
  end
  if type(titleHint.SetShadowColor) == "function" then
    titleHint:SetShadowColor(0, 0, 0, 0.9)
  end
  ApplyFontStringSize(titleHint, 14)

  local headers = CreatePanelHeaders(mainFrame)
  local m2ColumnGuides = CreateM2ColumnGuides(mainFrame)
  local panelTooltip = CreateRosterHoverTooltip(mainFrame)
  local getL = type(uiDeps.getL) == "function" and uiDeps.getL or function()
    return {}
  end
  local L = getL()
  local buttonDeps = {}
  for key, value in pairs(uiDeps) do
    buttonDeps[key] = value
  end
  buttonDeps.tooltipFrame = panelTooltip
  local buttons = CreatePanelButtons(mainFrame, buttonDeps)
  local rosterTooltip = CreateRosterHoverTooltip(mainFrame)
  local tankButtons, tankHeader = CreateTankHelperButtons(mainFrame, panelTooltip, uiDeps.getL)

  local cdTrackerRow = CreateCdTrackerRow(mainFrame)
  local killTrackRow = CreateKillTrackRow(mainFrame)
  local statusLine = CreateStatusLine(mainFrame)
  local optionToggles = CreateSystemOptionToggles(mainFrame)
  local raidNoticeLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  raidNoticeLabel:SetPoint("TOP", 0, -100)
  local frameWidth = type(mainFrame.GetWidth) == "function" and mainFrame:GetWidth() or 400
  raidNoticeLabel:SetWidth(frameWidth - 16)
  raidNoticeLabel:SetJustifyH("CENTER")
  raidNoticeLabel:SetTextColor(1, 0.5, 0)
  raidNoticeLabel:SetWordWrap(true)
  raidNoticeLabel:Hide()

  local ui = {
    panelTooltip = panelTooltip,
    rosterTooltip = rosterTooltip,
    title = title,
    cdTrackerRow = cdTrackerRow,
    killTrackRow = killTrackRow,
    statusLine = statusLine,
    titleVersion = titleVersion,
    titleHint = titleHint,
    raidNoticeLabel = raidNoticeLabel,
    m2ColumnGuides = m2ColumnGuides,
    tankButtons = tankButtons,
    tankHeader = tankHeader,
    setMainFrameHeightSafe = uiDeps.setMainFrameHeightSafe,
    setMainFrameWidthSafe = uiDeps.setMainFrameWidthSafe,
    minFrameHeight = uiDeps.minFrameHeight,
    isPlayerLeader = uiDeps.isPlayerLeader,
    forceMarkersLeaderOnly = FORCE_MARKERS_LEADER_ONLY,
  }
  for k, v in pairs(headers) do
    ui[k] = v
  end
  for k, v in pairs(buttons) do
    ui[k] = v
  end
  for k, v in pairs(optionToggles) do
    ui[k] = v
  end

  ui.managementButtons = {
    ui.readyCheckButton,
    ui.countdownButton,
    ui.countdownCancelButton,
  }
  -- Buttons that always stay anchored at leadX (not visible in H mode)
  ui.columnButtons = {
    ui.shareKeysButton,
    ui.refreshButton,
  }
  ui.toolbarButtons = {
    ui.readyCheckButton,
    ui.countdownButton,
    ui.countdownCancelButton,
    ui.shareKeysButton,
    ui.refreshButton,
  }

  -- Three static mode buttons [M+][H][V] laid out left-to-right at the top-right.
  -- Each button sets the mode directly; the active mode is highlighted gold.
  ui.layoutMode = LAYOUT_MODE_EXPANDED
  ui.isCollapsed = false
  ui.modeButtons = {}
  local modeButtonDefs = {
    {
      xOffset = -132,
      label = "M+",
      target = LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL,
      width = 24,
      descriptionKey = "MODE_LAYOUT_M2",
      descriptionFallback = L.MODE_LAYOUT_M2 or "Main horizontal layout.",
    },
    {
      xOffset = -108,
      label = "H",
      target = LAYOUT_MODE_COMPACT_HORIZONTAL,
      descriptionKey = "MODE_LAYOUT_H",
      descriptionFallback = L.MODE_LAYOUT_H or "Compact horizontal layout.",
    },
    {
      xOffset = -88,
      label = "V",
      target = LAYOUT_MODE_COMPACT_VERTICAL,
      descriptionKey = "MODE_LAYOUT_V",
      descriptionFallback = L.MODE_LAYOUT_V or "Compact vertical layout.",
    },
  }
  for _, def in ipairs(modeButtonDefs) do
    local target = def.target
    local raidLockedTarget = target ~= LAYOUT_MODE_COMPACT_HORIZONTAL
    local function ApplyRequestedLayoutMode()
      if raidLockedTarget and isRaidGroupFn() then
        return
      end
      Trace(string.format("layout mode changed to %s", tostring(target)))
      ui.layoutMode = target
      local db = GetDB()
      if db then
        db.rosterLayoutMode = target
      end
      UpdateCollapseState(ui, target, mainFrame)
      NotifyCollapseChanged(ui, ui.isCollapsed)
      NotifyLayoutChanged(ui, ui.layoutMode)
    end
    local btn = CreateModeButton(mainFrame, def.xOffset, def.label, target, function()
      ApplyRequestedLayoutMode()
    end, def.width)
    -- Mode buttons that are not COMPACT_HORIZONTAL silently no-op while the
    -- player is in a raid (ApplyRequestedLayoutMode early-returns). Surface the
    -- reason in the hover tooltip so the click-does-nothing case is obvious.
    local getLockReason = raidLockedTarget
        and function()
          if not isRaidGroupFn() then
            return nil
          end
          local locales = type(getL) == "function" and getL() or {}
          return locales.TOOLTIP_LAYOUT_RAID_LOCK or "Not available in raids."
        end
      or nil
    AttachModeButtonTooltip(
      panelTooltip,
      btn,
      getL,
      def.label,
      def.descriptionKey,
      def.descriptionFallback,
      "TOOLTIP_LAYOUT_SWITCH",
      L.TOOLTIP_LAYOUT_SWITCH or "Click to switch layout.",
      getLockReason
    )
    table.insert(ui.modeButtons, btn)
  end
  UpdateCollapseState(ui, LAYOUT_MODE_EXPANDED, mainFrame)

  AttachSystemOptionToggleWatcher(mainFrame, ui)
  return ui
end

function RosterPanel.CreateController(opts)
  Trace("creating controller")
  opts = opts or {}

  local mainFrame = assert(opts.mainFrame, "isiLive: RosterPanel requires mainFrame")
  local getL = RequireFunction(opts.getL, "getL")
  local isPlayerLeader = RequireFunction(opts.isPlayerLeader, "isPlayerLeader")
  local getAddonVersionText = RequireFunction(opts.getAddonVersionText, "getAddonVersionText")
  local updateStatusLine = RequireFunction(opts.updateStatusLine, "updateStatusLine")
  local setMainFrameHeightSafe = RequireFunction(opts.setMainFrameHeightSafe, "setMainFrameHeightSafe")
  local setMainFrameWidthSafe = RequireFunction(opts.setMainFrameWidthSafe, "setMainFrameWidthSafe")
  local minFrameHeight = tonumber(opts.minFrameHeight) or DEFAULT_MIN_FRAME_HEIGHT

  local buildOrderedRoster = RequireFunction(opts.buildOrderedRoster, "buildOrderedRoster")
  local buildDisplayData = RequireFunction(opts.buildDisplayData, "buildDisplayData")
  local truncateName = RequireFunction(opts.truncateName, "truncateName")
  local getShortSpecLabel = RequireFunction(opts.getShortSpecLabel, "getShortSpecLabel")
  local getLanguageFlagMarkup = RequireFunction(opts.getLanguageFlagMarkup, "getLanguageFlagMarkup")
  local getLanguageTooltipMarkup = type(opts.getLanguageTooltipMarkup) == "function" and opts.getLanguageTooltipMarkup
    or nil
  if not getLanguageTooltipMarkup then
    local localeModule = addonTable and addonTable.Locale
    if type(localeModule) == "table" and type(localeModule.GetLanguageTooltipMarkup) == "function" then
      local locale = rawget(_G, "GetLocale") and GetLocale() or nil
      getLanguageTooltipMarkup = function(languageTag)
        return localeModule.GetLanguageTooltipMarkup(languageTag, locale)
      end
    else
      getLanguageTooltipMarkup = function(languageTag)
        return getLanguageFlagMarkup(languageTag)
      end
    end
  end
  local getDungeonShortCode = RequireFunction(opts.getDungeonShortCode, "getDungeonShortCode")
  local getDungeonName = type(opts.getDungeonName) == "function" and opts.getDungeonName or nil
  local getOwnedKeystoneSnapshot = type(opts.getOwnedKeystoneSnapshot) == "function" and opts.getOwnedKeystoneSnapshot
    or nil
  local getRioDelta = type(opts.getRioDelta) == "function" and opts.getRioDelta or nil
  local getPlayerSyncSummary = type(opts.getPlayerSyncSummary) == "function" and opts.getPlayerSyncSummary or nil
  local resolveActiveKeyOwnerUnit = RequireFunction(opts.resolveActiveKeyOwnerUnit, "resolveActiveKeyOwnerUnit")
  local getRoster = RequireFunction(opts.getRoster, "getRoster")
  local isReadyCheckActive = opts.isReadyCheckActive
  if type(isReadyCheckActive) ~= "function" and type(isReadyCheckActive) ~= "boolean" then
    isReadyCheckActive = nil
  end
  local getReadyCheckReadyUntil = type(opts.getReadyCheckReadyUntil) == "function" and opts.getReadyCheckReadyUntil
    or nil
  local getReadyCheckDeclinedUntil = type(opts.getReadyCheckDeclinedUntil) == "function"
      and opts.getReadyCheckDeclinedUntil
    or nil
  local resolveTargetMapID = type(opts.resolveTargetMapID) == "function" and opts.resolveTargetMapID or nil
  local isInGroup = RequireFunction(opts.isInGroup, "isInGroup")
  local isRaidGroup = type(opts.isRaidGroup) == "function" and opts.isRaidGroup or function()
    return false
  end
  local rolePriority = assert(opts.rolePriority, "isiLive: RosterPanel requires rolePriority")
  local unitPriority = assert(opts.unitPriority, "isiLive: RosterPanel requires unitPriority")
  local syncMarker = tostring(opts.syncMarker or "")
  local syncBadge = tostring(opts.syncBadge or "")
  local applyKnownKeyToRosterEntry = type(opts.applyKnownKeyToRosterEntry) == "function"
      and opts.applyKnownKeyToRosterEntry
    or nil
  local getTime = type(opts.getTime) == "function" and opts.getTime
    or function()
      if type(GetTime) == "function" then
        return GetTime()
      end
      return nil
    end
  local shareKeysDebounceSeconds = tonumber(opts.shareKeysDebounceSeconds) or 1
  if shareKeysDebounceSeconds < 0 then
    shareKeysDebounceSeconds = 0
  end
  local sendShareKeysRequest = type(opts.sendShareKeysRequest) == "function" and opts.sendShareKeysRequest or nil
  local getPlayerLastRunDps = type(opts.getPlayerLastRunDps) == "function" and opts.getPlayerLastRunDps or nil
  local getTargetDungeonInfo = type(opts.getTargetDungeonInfo) == "function" and opts.getTargetDungeonInfo or nil
  local isInChallengeMode = type(opts.isInChallengeMode) == "function" and opts.isInChallengeMode or nil
  local logRuntimeTrace = type(opts.logRuntimeTrace) == "function" and opts.logRuntimeTrace or nil
  local logRuntimeTraceDeep = type(opts.logRuntimeTraceDeep) == "function" and opts.logRuntimeTraceDeep or nil
  local ui = ConstructPanelUI(mainFrame, {
    getL = getL,
    isPlayerLeader = isPlayerLeader,
    getAddonVersionText = getAddonVersionText,
    updateStatusLine = updateStatusLine,
    setMainFrameHeightSafe = setMainFrameHeightSafe,
    setMainFrameWidthSafe = setMainFrameWidthSafe,
    minFrameHeight = minFrameHeight,
    getRoster = getRoster,
    buildOrderedRoster = buildOrderedRoster,
    rolePriority = rolePriority,
    unitPriority = unitPriority,
    getDungeonShortCode = getDungeonShortCode,
    getOwnedKeystoneSnapshot = getOwnedKeystoneSnapshot,
    applyKnownKeyToRosterEntry = applyKnownKeyToRosterEntry,
    isInGroup = isInGroup,
    getTime = getTime,
    shareKeysDebounceSeconds = shareKeysDebounceSeconds,
    sendShareKeysRequest = sendShareKeysRequest,
    isRaidGroup = isRaidGroup,
    logRuntimeTrace = logRuntimeTrace,
  })

  local readyCheckButton = ui.readyCheckButton
  local countdownButton = ui.countdownButton
  local refreshButton = ui.refreshButton
  local shareKeysButton = ui.shareKeysButton
  local countdownCancelButton = ui.countdownCancelButton

  local memberRows = {}
  local cdController = nil
  local cdTrackerNeedsVisibleRescan = true
  local pendingLeaderButtonUpdate = false

  local function IsMainFrameShown()
    return type(mainFrame.IsShown) == "function" and mainFrame:IsShown() == true
  end

  local function IsInCombatLockdown()
    local inCombatFn = rawget(_G, "InCombatLockdown")
    return type(inCombatFn) == "function" and inCombatFn() == true
  end

  local function MarkCdTrackerDirty()
    cdTrackerNeedsVisibleRescan = true
  end

  local function MaybeRescanCdTrackerForVisibleRender()
    if not cdController or type(cdController.Scan) ~= "function" then
      return
    end
    if not IsMainFrameShown() then
      MarkCdTrackerDirty()
      return
    end
    if cdTrackerNeedsVisibleRescan then
      cdController.Scan()
      cdTrackerNeedsVisibleRescan = false
    end
  end

  local controller = {}

  function controller.ApplyLocalization()
    local L = getL()
    local function ApplyLocaleFont(fontString)
      if type(UICommon.ApplyLocaleFont) == "function" then
        UICommon.ApplyLocaleFont(fontString)
      end
    end
    local titleName = tostring(L.TITLE or "isiLive")
    local addonVer = rawget(_G, "C_AddOns")
        and type(C_AddOns.GetAddOnMetadata) == "function"
        and C_AddOns.GetAddOnMetadata("isiLive", "Version")
      or nil
    local titleVer = addonVer and ("v" .. addonVer) or ""
    ui.title:SetText(titleName)
    ApplyLocaleFont(ui.title)
    if ui.titleVersion then
      ui.titleVersion:SetText(titleVer)
      ApplyLocaleFont(ui.titleVersion)
    end
    if ui.titleHint then
      ui.titleHint:SetText(tostring(L.TITLE_HINT or ""))
      ApplyLocaleFont(ui.titleHint)
    end
    SetPanelHeaderText(ui.specHeader, L.COL_SPEC)
    SetPanelHeaderText(ui.nameHeader, L.COL_NAME)
    SetPanelHeaderText(ui.serverHeader, L.COL_LANGUAGE)
    SetPanelHeaderText(ui.keyHeader, L.COL_KEY)
    SetPanelHeaderText(ui.ilvlHeader, L.COL_ILVL)
    SetPanelHeaderText(ui.rioHeader, L.COL_RIO)
    SetPanelHeaderText(ui.dpsHeader, L.COL_DPS)
    if ui.kickHeader then
      SetPanelHeaderText(ui.kickHeader, L.COL_KICK or "Kick")
    end
    SetPanelHeaderText(ui.leadOptionsHeader, L.LEAD_OPTIONS)
    SetPanelHeaderText(ui.mplusManagementHeader, L.MPLUS_MANAGEMENT)
    readyCheckButton._fullText = L.BTN_READYCHECK
    readyCheckButton._hModeText = L.BTN_READYCHECK_SHORT
    countdownButton._fullText = L.BTN_COUNTDOWN10
    countdownButton._hModeText = L.BTN_COUNTDOWN10_SHORT
    countdownCancelButton._fullText = L.BTN_COUNTDOWN_CANCEL
    countdownCancelButton._hModeText = L.BTN_COUNTDOWN_CANCEL_SHORT
    shareKeysButton._fullText = L.BTN_SHARE_KEYS
    refreshButton._fullText = L.BTN_REFRESH
    local isH = IsHorizontalCompactLayoutMode(ui and ui.layoutMode)
    SetFlatButtonText(readyCheckButton, isH and readyCheckButton._hModeText or readyCheckButton._fullText)
    SetFlatButtonText(countdownButton, isH and countdownButton._hModeText or countdownButton._fullText)
    SetFlatButtonText(
      countdownCancelButton,
      isH and countdownCancelButton._hModeText or countdownCancelButton._fullText
    )
    SetFlatButtonText(refreshButton, refreshButton._fullText)
    if type(shareKeysButton.RefreshDisplayText) == "function" then
      shareKeysButton.RefreshDisplayText()
    else
      SetFlatButtonText(shareKeysButton, shareKeysButton._fullText)
    end
    ApplyLocaleFont(ui.advancedCombatLoggingToggle.label)
    ApplyLocaleFont(ui.damageMeterResetToggle.label)
    ui.advancedCombatLoggingToggle.label:SetText(L.OPT_ADVANCED_COMBAT_LOGGING)
    ui.damageMeterResetToggle.label:SetText(L.OPT_DAMAGE_METER_RESET)
    LayoutSystemOptionToggles(ui)
    RefreshSystemOptionToggles(ui)
  end

  function controller.IsCollapsed()
    return ui.isCollapsed
  end

  function controller.GetLayoutMode()
    return ui.layoutMode
  end

  function controller.RestoreSavedState()
    local savedLayoutMode = ResolveConfiguredDefaultOpenLayoutMode()
    if savedLayoutMode == DEFAULT_LAYOUT_MODE_LAST_USED then
      local db = GetDB()
      local lastUsedLayoutMode = type(db) == "table" and db.rosterLayoutMode or nil
      if lastUsedLayoutMode == nil or lastUsedLayoutMode == false or lastUsedLayoutMode == "" then
        savedLayoutMode = LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
      else
        savedLayoutMode = lastUsedLayoutMode
      end
    end
    local db = GetDB()
    if savedLayoutMode == nil then
      savedLayoutMode = db and db.rosterLayoutMode or nil
    end
    if savedLayoutMode == nil and db and db.rosterCollapsed ~= nil then
      savedLayoutMode = db.rosterCollapsed and LAYOUT_MODE_COMPACT_VERTICAL or LAYOUT_MODE_EXPANDED
    end
    if savedLayoutMode ~= nil then
      ui.layoutMode = NormalizeLayoutMode(savedLayoutMode)
      UpdateCollapseState(ui, ui.layoutMode, mainFrame)
      NotifyCollapseChanged(ui, ui.isCollapsed)
      NotifyLayoutChanged(ui, ui.layoutMode)
    end
  end

  function controller.RefreshLayoutState()
    if type(ui) == "table" then
      UpdateCollapseState(ui, ui.layoutMode, mainFrame)
    end
  end

  function controller.SetCollapseChangedHandler(handler)
    ui.onCollapseChanged = type(handler) == "function" and handler or nil
  end

  function controller.SetLayoutChangedHandler(handler)
    ui.onLayoutChanged = type(handler) == "function" and handler or nil
  end

  function controller.UpdateLeaderButtons()
    local enabled = isPlayerLeader()
    Trace(string.format("updating leader buttons, isLeader=%s", tostring(enabled)))
    if logRuntimeTraceDeep then
      logRuntimeTraceDeep(function()
        return string.format("[ROSTER_UI] leader_buttons enabled=%s", tostring(enabled))
      end)
    end
    if IsInCombatLockdown() then
      pendingLeaderButtonUpdate = true
      updateStatusLine()
      return
    end
    pendingLeaderButtonUpdate = false
    readyCheckButton:SetEnabled(enabled)
    countdownButton:SetEnabled(enabled)
    countdownCancelButton:SetEnabled(enabled)
    readyCheckButton:SetAlpha(enabled and 1 or 0.45)
    countdownButton:SetAlpha(enabled and 1 or 0.45)
    countdownCancelButton:SetAlpha(enabled and 1 or 0.45)
    RefreshSystemOptionToggles(ui)
    updateStatusLine()
  end

  function controller.ApplyPendingLeaderButtonUpdates()
    if not pendingLeaderButtonUpdate or IsInCombatLockdown() then
      return
    end
    controller.UpdateLeaderButtons()
  end

  function controller.RenderRoster(roster)
    MaybeRescanCdTrackerForVisibleRender()
    if logRuntimeTraceDeep then
      logRuntimeTraceDeep(function()
        local count = 0
        for _ in pairs(roster or {}) do
          count = count + 1
        end
        return string.format(
          "[ROSTER_UI] render_roster entries=%s frameShown=%s layout=%s raid=%s",
          tostring(count),
          tostring(IsMainFrameShown()),
          tostring(ui.layoutMode),
          tostring(isRaidGroup())
        )
      end)
    end
    RenderRosterImpl({
      memberRows = memberRows,
      mainFrame = mainFrame,
      shareKeysButton = shareKeysButton,
      rosterTooltip = ui.rosterTooltip,
      setMainFrameHeightSafe = setMainFrameHeightSafe,
      minFrameHeight = minFrameHeight,
      buildOrderedRoster = buildOrderedRoster,
      rolePriority = rolePriority,
      unitPriority = unitPriority,
      resolveActiveKeyOwnerUnit = resolveActiveKeyOwnerUnit,
      isReadyCheckActive = isReadyCheckActive,
      resolveTargetMapID = resolveTargetMapID,
      buildDisplayData = buildDisplayData,
      truncateName = truncateName,
      getShortSpecLabel = getShortSpecLabel,
      getLanguageFlagMarkup = getLanguageFlagMarkup,
      getLanguageTooltipMarkup = getLanguageTooltipMarkup,
      getDungeonShortCode = getDungeonShortCode,
      getOwnedKeystoneSnapshot = getOwnedKeystoneSnapshot,
      getDungeonName = getDungeonName,
      getRioDelta = getRioDelta,
      syncMarker = syncMarker,
      syncBadge = syncBadge,
      getPlayerSyncSummary = getPlayerSyncSummary,
      getPlayerLastRunDps = getPlayerLastRunDps,
      getReadyCheckReadyUntil = getReadyCheckReadyUntil,
      getReadyCheckDeclinedUntil = getReadyCheckDeclinedUntil,
      getTime = getTime,
      getL = getL,
      isRaidGroup = isRaidGroup,
      raidNoticeLabel = ui.raidNoticeLabel,
      uiRef = ui,
      applyKnownKeyToRosterEntry = applyKnownKeyToRosterEntry,
    }, roster)
    RefreshSystemOptionToggles(ui)
    UpdateCdTrackerRow(ui.cdTrackerRow, cdController)
    UpdateKillTrackRow(ui.killTrackRow, {
      getTargetDungeonInfo = getTargetDungeonInfo,
      isInChallengeMode = isInChallengeMode,
    })
  end

  function controller.RefreshReadyCheckState(roster)
    RefreshReadyCheckStateImpl({
      memberRows = memberRows,
      buildOrderedRoster = buildOrderedRoster,
      rolePriority = rolePriority,
      unitPriority = unitPriority,
      isReadyCheckActive = isReadyCheckActive,
      resolveTargetMapID = resolveTargetMapID,
      buildDisplayData = buildDisplayData,
      truncateName = truncateName,
      getShortSpecLabel = getShortSpecLabel,
      getLanguageFlagMarkup = getLanguageFlagMarkup,
      getDungeonShortCode = getDungeonShortCode,
      getDungeonName = getDungeonName,
      getRioDelta = getRioDelta,
      syncMarker = syncMarker,
      syncBadge = syncBadge,
      getPlayerSyncSummary = getPlayerSyncSummary,
      getReadyCheckReadyUntil = getReadyCheckReadyUntil,
      getReadyCheckDeclinedUntil = getReadyCheckDeclinedUntil,
      getTime = getTime,
    }, roster or getRoster())
  end

  function controller.RefreshSystemOptionToggles()
    RefreshSystemOptionToggles(ui)
  end

  function controller.RefreshKickColumn()
    for _, row in pairs(memberRows) do
      if row.kick and row.tooltipInfo then
        local info = row.tooltipInfo
        if type(applyKnownKeyToRosterEntry) == "function" then
          applyKnownKeyToRosterEntry(info)
        end
        SetKickCellText(row.kick, info, getL)
      end
    end
  end

  function controller.SetCdController(ctrl)
    cdController = ctrl
    MarkCdTrackerDirty()
  end

  function controller.RefreshCdTracker()
    cdTrackerNeedsVisibleRescan = false
    UpdateCdTrackerRow(ui.cdTrackerRow, cdController)
  end

  function controller.RefreshKillTrackRow()
    UpdateKillTrackRow(ui.killTrackRow, {
      getTargetDungeonInfo = getTargetDungeonInfo,
      isInChallengeMode = isInChallengeMode,
    })
  end

  function controller.MarkCdTrackerDirty()
    MarkCdTrackerDirty()
  end

  AttachControllerAccessors(controller, {
    refreshButton = refreshButton,
    countdownCancelButton = countdownCancelButton,
    statusLine = ui.statusLine,
    shareKeysButton = shareKeysButton,
  })

  return controller
end
