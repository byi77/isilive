local _, addonTable = ...
addonTable = addonTable or {}

local SettingsSupport = {}
addonTable.SettingsSupport = SettingsSupport

local Colors = addonTable.UICommon and addonTable.UICommon.Colors or {}
local CreateSectionHeader = addonTable.SettingsControls.CreateSectionHeader
local MeasureWrappedTextHeight = addonTable.SettingsControls.MeasureWrappedTextHeight
local CreateSectionNote = addonTable.SettingsControls.CreateSectionNote
local CreateSettingsCheckbox = addonTable.SettingsControls.CreateSettingsCheckbox
local CreateSettingsActionButton = addonTable.SettingsControls.CreateSettingsActionButton

local PADDING_X = 16
local LINE_HEIGHT = 28
local SETTINGS_CONTENT_WIDTH = 700
local DESCRIPTION_WIDTH = 620
local BETA_ISSUES_URL = "https://github.com/byi77/isilive/issues"

local function SetLocalizedText(control, labels, key, fallback)
  if control and type(control.SetText) == "function" then
    control:SetText(labels[key] or fallback)
  end
end

local function DescriptionOptions(descriptionText)
  return {
    descriptionText = descriptionText,
    descriptionWidth = DESCRIPTION_WIDTH,
    descriptionWordWrap = true,
  }
end

local function SetDescription(control, text)
  if type(control) == "table" and control.description and type(control.description.SetText) == "function" then
    control.description:SetText(text or "")
  end
end

local function GetCVarEnabled(name)
  local getCVar = rawget(_G, "GetCVar")
  if type(getCVar) == "function" then
    return getCVar(name) == "1"
  end

  return false
end

local function SetCVarEnabled(name, checked)
  local setCVar = rawget(_G, "SetCVar")
  if type(setCVar) == "function" then
    setCVar(name, checked and "1" or "0")
  end
end

local function AttachResetUiHint(canvas, control, labels)
  if type(control) ~= "table" or type(control.button) ~= "table" then
    return nil
  end

  local resetUiHint = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  local td = Colors.TEXT_DIM or { 0.5, 0.5, 0.6 }
  resetUiHint:SetTextColor(td[1], td[2], td[3], 1)
  resetUiHint:SetPoint("TOPLEFT", control.button, "BOTTOMLEFT", 8, -4)
  resetUiHint:SetWidth(304)
  resetUiHint:SetJustifyH("CENTER")
  if type(resetUiHint.SetWordWrap) == "function" then
    resetUiHint:SetWordWrap(true)
  end
  if type(resetUiHint.SetNonSpaceWrap) == "function" then
    resetUiHint:SetNonSpaceWrap(true)
  end
  resetUiHint:SetText(
    labels.SETTINGS_RESET_UI_POSITION_HINT or "Default: position center, UI scale 100%, background opacity 50%"
  )
  control.hint = resetUiHint
  control.button.hint = resetUiHint

  return resetUiHint
end

function SettingsSupport.BuildChatSection(canvas, yOffset, labels, config, controls)
  controls.chatHeader, yOffset =
    CreateSectionHeader(canvas, yOffset, labels.SETTINGS_SECTION_CHAT or "Chat Announcements")
  if controls.chatHeader then
    controls.chatHeader._sectionKey = "SETTINGS_SECTION_CHAT"
  end

  controls.chatHint, yOffset = CreateSectionNote(
    canvas,
    yOffset,
    labels.SETTINGS_SECTION_CHAT_HINT or "Toggle automatic chat messages during Mythic+ runs."
  )
  if controls.chatHint then
    controls.chatHint._sectionKey = "SETTINGS_SECTION_CHAT"
  end

  controls.chatAnnounceBR, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_CHAT_BR_ANNOUNCE or "Chat: Announce Battle Res usage in M+",
    function()
      local db = config.getDB()
      return db.chatAnnounceBR ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.chatAnnounceBR = checked
    end,
    "SETTINGS_CHAT_BR_ANNOUNCE",
    DescriptionOptions(
      labels.SETTINGS_CHAT_BR_ANNOUNCE_DESC or "Announces Battle Resurrection usage in party chat during Mythic+ runs."
    )
  )

  controls.chatAnnounceLust, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_CHAT_LUST_ANNOUNCE or "Chat: Announce Bloodlust casts in M+",
    function()
      local db = config.getDB()
      return db.chatAnnounceLust ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.chatAnnounceLust = checked
    end,
    "SETTINGS_CHAT_LUST_ANNOUNCE",
    DescriptionOptions(
      labels.SETTINGS_CHAT_LUST_ANNOUNCE_DESC or "Announces Bloodlust casts in party chat during Mythic+ runs."
    )
  )

  controls.powerInfusionTextAlert, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_TEXT_POWER_INFUSION_ALERT or "Text alert on Power Infusion",
    function()
      local db = config.getDB()
      return db.powerInfusionTextEnabled ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.powerInfusionTextEnabled = checked
    end,
    "SETTINGS_TEXT_POWER_INFUSION_ALERT",
    DescriptionOptions(
      labels.SETTINGS_TEXT_POWER_INFUSION_ALERT_DESC
        or "Shows the local PI chat line and center alert when Power Infusion is detected."
    )
  )

  return yOffset
end

function SettingsSupport.BuildDebugSection(canvas, yOffset, labels, config, controls)
  controls.debugHeader, yOffset =
    CreateSectionHeader(canvas, yOffset, labels.SETTINGS_SECTION_DEBUG or "Administrative")
  controls.debugHint, yOffset = CreateSectionNote(
    canvas,
    yOffset,
    labels.SETTINGS_SECTION_DEBUG_HINT or "System toggles, diagnostics, reset actions, and support links."
  )
  if controls.debugHint then
    controls.debugHint._sectionKey = "SETTINGS_SECTION_DEBUG"
  end

  controls.combatLog, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_COMBAT_LOGGING or "Advanced Combat Logging",
    function()
      return GetCVarEnabled("advancedCombatLogging")
    end,
    function(checked)
      SetCVarEnabled("advancedCombatLogging", checked)
    end,
    "SETTINGS_COMBAT_LOGGING",
    DescriptionOptions(
      labels.SETTINGS_COMBAT_LOGGING_DESC or "Enables Blizzard's advanced combat log for external log analysis."
    )
  )

  controls.dmReset, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_DM_RESET or "Reset Blizzard Damage Meter on dungeon entry",
    function()
      return GetCVarEnabled("damageMeterResetOnNewInstance")
    end,
    function(checked)
      SetCVarEnabled("damageMeterResetOnNewInstance", checked)
    end,
    "SETTINGS_DM_RESET",
    DescriptionOptions(
      labels.SETTINGS_DM_RESET_DESC or "Clears Blizzard's built-in damage meter when you enter a new dungeon."
    )
  )

  controls.queueDebug, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_QUEUE_DEBUG or "Queue Debug Log (resets on reload)",
    function()
      if type(config.getQueueDebugEnabled) == "function" then
        return config.getQueueDebugEnabled()
      end
      return false
    end,
    function(checked)
      if type(config.onQueueDebugToggle) == "function" then
        config.onQueueDebugToggle(checked)
      end
    end,
    "SETTINGS_QUEUE_DEBUG",
    DescriptionOptions(labels.SETTINGS_QUEUE_DEBUG_DESC or "Records queue detection events until the next UI reload.")
  )

  controls.clearQueueDebugBtn, yOffset = CreateSettingsActionButton(
    canvas,
    yOffset,
    labels.SETTINGS_QUEUE_DEBUG_CLEAR or "Clear Queue Debug Log",
    240,
    function()
      if type(config.onClearQueueDebugLog) == "function" then
        config.onClearQueueDebugLog()
      end
    end,
    "SETTINGS_QUEUE_DEBUG_CLEAR",
    nil
  )

  controls.runtimeLog, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_RUNTIME_LOG or "Runtime Log (resets on reload)",
    function()
      if type(config.getRuntimeLogEnabled) == "function" then
        return config.getRuntimeLogEnabled()
      end
      return false
    end,
    function(checked)
      if type(config.onRuntimeLogToggle) == "function" then
        config.onRuntimeLogToggle(checked)
      end
    end,
    "SETTINGS_RUNTIME_LOG",
    DescriptionOptions(
      labels.SETTINGS_RUNTIME_LOG_DESC or "Records runtime diagnostic events until the next UI reload."
    )
  )

  controls.clearRuntimeLogBtn, yOffset = CreateSettingsActionButton(
    canvas,
    yOffset,
    labels.SETTINGS_RUNTIME_LOG_CLEAR or "Clear Runtime Log",
    240,
    function()
      if type(config.onClearRuntimeLog) == "function" then
        config.onClearRuntimeLog()
      end
    end,
    "SETTINGS_RUNTIME_LOG_CLEAR",
    nil
  )

  return yOffset
end

function SettingsSupport.BuildResetSection(canvas, yOffset, labels, config, controls)
  controls.resetHint, yOffset = CreateSectionNote(
    canvas,
    yOffset,
    labels.SETTINGS_SECTION_RESET_HINT or "Use these actions to restore the frame or all settings."
  )
  if controls.resetHint then
    controls.resetHint._sectionKey = "SETTINGS_SECTION_RESET"
  end
  controls.resetUiBtn, yOffset = CreateSettingsActionButton(
    canvas,
    yOffset,
    labels.SETTINGS_RESET_UI_POSITION or "/isilive resetui",
    320,
    function()
      if type(config.onResetMainFramePosition) == "function" then
        config.onResetMainFramePosition()
      end
    end,
    {
      settingKey = "SETTINGS_RESET_UI_POSITION",
      confirmText = labels.SETTINGS_RESET_CONFIRM_TEXT or "Do you really want to reset?",
    }
  )
  controls.resetUiHint = AttachResetUiHint(canvas, controls.resetUiBtn, labels)
  yOffset = yOffset - 18

  controls.resetDBBtn, yOffset = CreateSettingsActionButton(
    canvas,
    yOffset,
    labels.SETTINGS_RESET_DB or "Reset All Settings",
    320,
    function()
      if type(config.onResetDB) == "function" then
        config.onResetDB()
      end
    end,
    {
      settingKey = "SETTINGS_RESET_DB",
      confirmText = labels.SETTINGS_RESET_CONFIRM_TEXT or "Do you really want to reset?",
    }
  )

  return yOffset
end

function SettingsSupport.BuildBetaSection(canvas, yOffset, labels, controls)
  controls.betaHeader, yOffset = CreateSectionHeader(canvas, yOffset, labels.SETTINGS_BETA_NOTICE or "Beta")

  local noticeText = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  noticeText:SetTextColor(1, 0.75, 0.2, 1)
  noticeText:SetPoint("TOPLEFT", canvas, "TOPLEFT", PADDING_X, yOffset - 4)
  noticeText:SetJustifyH("LEFT")
  noticeText:SetWidth(math.max(240, SETTINGS_CONTENT_WIDTH - (PADDING_X * 2)))
  if type(noticeText.SetWordWrap) == "function" then
    noticeText:SetWordWrap(true)
  end
  noticeText:SetText(labels.BETA_NOTICE_TEXT or "This addon is in BETA status. Please report bugs at:")
  controls.betaNoticeText = noticeText

  yOffset = yOffset - MeasureWrappedTextHeight(noticeText, LINE_HEIGHT, 6)

  local function CreateBetaUrlBox(text, offsetY)
    local urlBox = CreateFrame("EditBox", nil, canvas, "InputBoxTemplate")
    urlBox:SetSize(SETTINGS_CONTENT_WIDTH - (PADDING_X * 2) - 12, 20)
    urlBox:SetPoint("TOPLEFT", canvas, "TOPLEFT", PADDING_X + 6, offsetY - 4)
    urlBox:SetAutoFocus(false)
    urlBox:SetText(text)
    urlBox:SetCursorPosition(0)
    urlBox:SetScript("OnEscapePressed", function(self)
      self:ClearFocus()
    end)
    urlBox:SetScript("OnEditFocusGained", function(self)
      self:HighlightText()
    end)
    return urlBox
  end

  local urlBox = CreateFrame("EditBox", nil, canvas, "InputBoxTemplate")
  urlBox:SetSize(SETTINGS_CONTENT_WIDTH - (PADDING_X * 2) - 12, 20)
  urlBox:SetPoint("TOPLEFT", canvas, "TOPLEFT", PADDING_X + 6, yOffset - 4)
  urlBox:SetAutoFocus(false)
  urlBox:SetText(BETA_ISSUES_URL)
  urlBox:SetCursorPosition(0)
  urlBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  urlBox:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
  end)
  controls.betaUrlBox = urlBox

  yOffset = yOffset - LINE_HEIGHT

  local betaCommentsUrl = "https://www.curseforge.com/wow/addons/isilive/comments"
  controls.betaCommentsUrlBox = CreateBetaUrlBox(betaCommentsUrl, yOffset)

  return yOffset - LINE_HEIGHT
end

function SettingsSupport.RefreshControls(controls, labels, db, config)
  SetLocalizedText(controls.chatHeader, labels, "SETTINGS_SECTION_CHAT", "Chat Announcements")
  SetLocalizedText(
    controls.chatHint,
    labels,
    "SETTINGS_SECTION_CHAT_HINT",
    "Toggle automatic chat messages during Mythic+ runs."
  )
  if controls.chatAnnounceBR and controls.chatAnnounceBR.label then
    controls.chatAnnounceBR.label:SetText(labels.SETTINGS_CHAT_BR_ANNOUNCE or "Chat: Announce Battle Res usage in M+")
    SetDescription(
      controls.chatAnnounceBR,
      labels.SETTINGS_CHAT_BR_ANNOUNCE_DESC or "Announces Battle Resurrection usage in party chat during Mythic+ runs."
    )
    controls.chatAnnounceBR.check:SetChecked(db.chatAnnounceBR ~= false)
  end
  if controls.chatAnnounceLust and controls.chatAnnounceLust.label then
    controls.chatAnnounceLust.label:SetText(
      labels.SETTINGS_CHAT_LUST_ANNOUNCE or "Chat: Announce Bloodlust casts in M+"
    )
    SetDescription(
      controls.chatAnnounceLust,
      labels.SETTINGS_CHAT_LUST_ANNOUNCE_DESC or "Announces Bloodlust casts in party chat during Mythic+ runs."
    )
    controls.chatAnnounceLust.check:SetChecked(db.chatAnnounceLust ~= false)
  end
  if controls.powerInfusionTextAlert and controls.powerInfusionTextAlert.label then
    controls.powerInfusionTextAlert.label:SetText(
      labels.SETTINGS_TEXT_POWER_INFUSION_ALERT or "Text alert on Power Infusion"
    )
    SetDescription(
      controls.powerInfusionTextAlert,
      labels.SETTINGS_TEXT_POWER_INFUSION_ALERT_DESC
        or "Shows the local PI chat line and center alert when Power Infusion is detected."
    )
    controls.powerInfusionTextAlert.check:SetChecked(db.powerInfusionTextEnabled ~= false)
  end

  if controls.debugHeader then
    controls.debugHeader:SetText(labels.SETTINGS_SECTION_DEBUG or "Administrative")
  end
  if controls.debugHint then
    controls.debugHint:SetText(
      labels.SETTINGS_SECTION_DEBUG_HINT or "System toggles, diagnostics, reset actions, and support links."
    )
  end
  if controls.combatLog then
    controls.combatLog.label:SetText(labels.SETTINGS_COMBAT_LOGGING or "Advanced Combat Logging")
    SetDescription(
      controls.combatLog,
      labels.SETTINGS_COMBAT_LOGGING_DESC or "Enables Blizzard's advanced combat log for external log analysis."
    )
    controls.combatLog.check:SetChecked(GetCVarEnabled("advancedCombatLogging"))
  end
  if controls.dmReset then
    controls.dmReset.label:SetText(labels.SETTINGS_DM_RESET or "Reset Blizzard Damage Meter on dungeon entry")
    SetDescription(
      controls.dmReset,
      labels.SETTINGS_DM_RESET_DESC or "Clears Blizzard's built-in damage meter when you enter a new dungeon."
    )
    controls.dmReset.check:SetChecked(GetCVarEnabled("damageMeterResetOnNewInstance"))
  end
  if controls.queueDebug then
    controls.queueDebug.label:SetText(labels.SETTINGS_QUEUE_DEBUG or "Queue Debug Log")
    SetDescription(
      controls.queueDebug,
      labels.SETTINGS_QUEUE_DEBUG_DESC or "Records queue detection events until the next UI reload."
    )
    controls.queueDebug.check:SetChecked(
      type(config.getQueueDebugEnabled) == "function" and config.getQueueDebugEnabled() or false
    )
  end
  if controls.runtimeLog then
    controls.runtimeLog.label:SetText(labels.SETTINGS_RUNTIME_LOG or "Runtime Log")
    SetDescription(
      controls.runtimeLog,
      labels.SETTINGS_RUNTIME_LOG_DESC or "Records runtime diagnostic events until the next UI reload."
    )
    controls.runtimeLog.check:SetChecked(
      type(config.getRuntimeLogEnabled) == "function" and config.getRuntimeLogEnabled() or false
    )
  end
  if controls.clearQueueDebugBtn and controls.clearQueueDebugBtn.label then
    controls.clearQueueDebugBtn.label:SetText(labels.SETTINGS_QUEUE_DEBUG_CLEAR or "Clear Queue Debug Log")
  end
  if controls.clearRuntimeLogBtn and controls.clearRuntimeLogBtn.label then
    controls.clearRuntimeLogBtn.label:SetText(labels.SETTINGS_RUNTIME_LOG_CLEAR or "Clear Runtime Log")
  end
  if controls.resetDBBtn then
    controls.resetDBBtn.label:SetText(labels.SETTINGS_RESET_DB or "Reset All Settings")
  end
  if controls.resetUiBtn then
    controls.resetUiBtn.label:SetText(labels.SETTINGS_RESET_UI_POSITION or "/isilive resetui")
  end
  if controls.resetUiHint then
    controls.resetUiHint:SetText(
      labels.SETTINGS_RESET_UI_POSITION_HINT or "Default: position center, UI scale 100%, background opacity 50%"
    )
    if type(controls.resetUiHint.SetWidth) == "function" then
      controls.resetUiHint:SetWidth(304)
    end
  end
  if controls.resetHint then
    controls.resetHint:SetText(
      labels.SETTINGS_SECTION_RESET_HINT or "Use these actions to restore the frame or all settings."
    )
  end

  if controls.betaHeader then
    controls.betaHeader:SetText(labels.SETTINGS_BETA_NOTICE or "Beta")
  end
  if controls.betaNoticeText then
    controls.betaNoticeText:SetText(labels.BETA_NOTICE_TEXT or "This addon is in BETA status. Please report bugs at:")
  end
end
