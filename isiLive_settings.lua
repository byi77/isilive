local _, addonTable = ...

addonTable = addonTable or {}

local SettingsPanel = {}
addonTable.SettingsPanel = SettingsPanel

local Colors = addonTable.UICommon and addonTable.UICommon.Colors or {}
local DEFAULT_BG_ALPHA = addonTable.UICommon and addonTable.UICommon.DEFAULT_BG_ALPHA or 0.50
local ApplyBackdrop = addonTable.UICommon and addonTable.UICommon.ApplyBackdrop

local PADDING_X = 16
local PADDING_TOP = 16
local LINE_HEIGHT = 28
local SECTION_GAP = 16
local HEADER_HEIGHT = 20
local HEADER_LINE_GAP = 4
local LANG_BUTTON_WIDTH = 90
local LANG_BUTTON_HEIGHT = 22
local SLIDER_WIDTH = 180
local SLIDER_HEIGHT = 16
local SHOW_NAME_MAX_CHARS_SETTING = false
local SHOW_TELEPORT_COLUMNS_SETTING = false
-- Temporarily hidden from Settings while live runtime keeps these defaults hard-forced.
local SHOW_DPS_COLUMN_SETTING = false
local SHOW_MARKERS_LEADER_ONLY_SETTING = false
local SHOW_SOUND_ENABLED_SETTING = false
local DEFAULT_LAYOUT_MODE_EXPANDED = "expanded"
local DEFAULT_LAYOUT_MODE_COMPACT_VERTICAL = "compact_vertical"
local DEFAULT_LAYOUT_MODE_COMPACT_HORIZONTAL = "compact_horizontal"
local DEFAULT_LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL = "compact_main_horizontal"
local DEFAULT_LAYOUT_MODE_COMPACT_HORIZONTAL_2_LEGACY = "compact_horizontal_2"
local DEFAULT_LAYOUT_MODE_LAST_USED = "last_used"

local function ApplySettingsBackdrop(frame)
  if type(ApplyBackdrop) == "function" then
    ApplyBackdrop(frame, "PRIMARY")
  end
end

local function CreateSectionHeader(parent, yOffset, text)
  local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  local td = Colors.TEXT_DIM or { 0.5, 0.5, 0.6 }
  header:SetTextColor(td[1], td[2], td[3], 1)
  header:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset)
  header:SetJustifyH("LEFT")
  header:SetText(text or "")

  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset - HEADER_HEIGHT)
  line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PADDING_X, yOffset - HEADER_HEIGHT)
  local ab = Colors.ACCENT_BLUE or { 0.3, 0.65, 1 }
  line:SetColorTexture(ab[1], ab[2], ab[3], 0.3)

  return header, yOffset - HEADER_HEIGHT - HEADER_LINE_GAP
end

local function CreateSettingsCheckbox(parent, yOffset, labelText, getter, setter, settingKey)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset)
  if type(check.SetSize) == "function" then
    check:SetSize(24, 24)
  end
  if type(settingKey) == "string" and settingKey ~= "" then
    check._settingKey = settingKey
  end

  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local tn = Colors.TEXT_NORMAL or { 0.85, 0.85, 0.9 }
  label:SetTextColor(tn[1], tn[2], tn[3], 1)
  label:SetPoint("LEFT", check, "RIGHT", 4, 0)
  label:SetText(labelText or "")
  check.label = label

  if type(getter) == "function" then
    check:SetChecked(getter())
  end

  check:SetScript("OnClick", function(self)
    if type(setter) == "function" then
      setter(self:GetChecked() and true or false)
    end
  end)

  return { check = check, label = label }, yOffset - LINE_HEIGHT
end

local function CreateSettingsSlider(parent, yOffset, labelText, minVal, maxVal, step, getter, setter, formatFunc)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local tn = Colors.TEXT_NORMAL or { 0.85, 0.85, 0.9 }
  label:SetTextColor(tn[1], tn[2], tn[3], 1)
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset - 3)
  label:SetText(labelText or "")

  local slider = CreateFrame("Slider", nil, parent, "BackdropTemplate")
  slider:SetSize(SLIDER_WIDTH, SLIDER_HEIGHT)
  slider:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X + 160, yOffset - 2)
  slider:SetOrientation("HORIZONTAL")
  slider:SetMinMaxValues(minVal, maxVal)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)

  if type(slider.SetBackdrop) == "function" then
    slider:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    local bgSec = Colors.BG_SECONDARY or { 0.12, 0.12, 0.18, 0.7 }
    slider:SetBackdropColor(bgSec[1], bgSec[2], bgSec[3], bgSec[4])
    local bd = Colors.BORDER_DEFAULT or { 0.25, 0.25, 0.35, 0.5 }
    slider:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
  end

  if type(slider.SetThumbTexture) == "function" then
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    if type(thumb.SetSize) == "function" then
      thumb:SetSize(10, SLIDER_HEIGHT)
    end
    local acBlue = Colors.ACCENT_BLUE or { 0.3, 0.65, 1 }
    if type(thumb.SetColorTexture) == "function" then
      thumb:SetColorTexture(acBlue[1], acBlue[2], acBlue[3], 0.8)
    end
    slider:SetThumbTexture(thumb)
  end

  local valueLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  valueLabel:SetTextColor(tn[1], tn[2], tn[3], 1)
  valueLabel:SetPoint("LEFT", slider, "RIGHT", 8, 0)
  local suppressValueChanged = false

  local function UpdateValueLabel(val)
    if type(formatFunc) == "function" then
      valueLabel:SetText(formatFunc(val))
    else
      valueLabel:SetText(string.format("%.0f%%", val * 100))
    end
  end

  local function SetValueSilently(val)
    suppressValueChanged = true
    slider:SetValue(val)
    suppressValueChanged = false
    UpdateValueLabel(val)
  end

  if type(getter) == "function" then
    local currentVal = getter()
    SetValueSilently(currentVal)
  end

  slider:SetScript("OnValueChanged", function(_, val)
    UpdateValueLabel(val)
    if suppressValueChanged then
      return
    end
    if type(setter) == "function" then
      setter(val)
    end
  end)

  return {
    label = label,
    slider = slider,
    valueLabel = valueLabel,
    UpdateValueLabel = UpdateValueLabel,
    SetValueSilently = SetValueSilently,
  },
    yOffset - LINE_HEIGHT
end

local function CreateLanguageSelector(parent, yOffset, labelText, getCurrentLocale, setLanguage)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local tn = Colors.TEXT_NORMAL or { 0.85, 0.85, 0.9 }
  label:SetTextColor(tn[1], tn[2], tn[3], 1)
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset - 3)
  label:SetText(labelText or "")

  local btnEn = CreateFrame("Button", nil, parent, "BackdropTemplate")
  btnEn:SetSize(LANG_BUTTON_WIDTH, LANG_BUTTON_HEIGHT)
  btnEn:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X + 120, yOffset - 1)
  if type(btnEn.SetBackdrop) == "function" then
    btnEn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
  end

  local labelEn = btnEn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  labelEn:SetPoint("CENTER", 0, 0)
  labelEn:SetText("English")

  local btnDe = CreateFrame("Button", nil, parent, "BackdropTemplate")
  btnDe:SetSize(LANG_BUTTON_WIDTH, LANG_BUTTON_HEIGHT)
  btnDe:SetPoint("LEFT", btnEn, "RIGHT", 2, 0)
  if type(btnDe.SetBackdrop) == "function" then
    btnDe:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
  end

  local labelDe = btnDe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  labelDe:SetPoint("CENTER", 0, 0)
  labelDe:SetText("Deutsch")

  local bgSec = Colors.BG_SECONDARY or { 0.12, 0.12, 0.18, 0.7 }
  local acBlue = Colors.ACCENT_BLUE or { 0.3, 0.65, 1 }

  local function UpdateHighlight()
    local current = type(getCurrentLocale) == "function" and getCurrentLocale() or "enUS"
    local isEN = current == "enUS" or current == "en"
    if type(btnEn.SetBackdropColor) == "function" then
      if isEN then
        btnEn:SetBackdropColor(acBlue[1], acBlue[2], acBlue[3], 0.25)
      else
        btnEn:SetBackdropColor(bgSec[1], bgSec[2], bgSec[3], bgSec[4])
      end
    end
    if type(btnDe.SetBackdropColor) == "function" then
      if not isEN then
        btnDe:SetBackdropColor(acBlue[1], acBlue[2], acBlue[3], 0.25)
      else
        btnDe:SetBackdropColor(bgSec[1], bgSec[2], bgSec[3], bgSec[4])
      end
    end
  end

  btnEn:SetScript("OnClick", function()
    if type(setLanguage) == "function" then
      setLanguage("en")
    end
    UpdateHighlight()
  end)

  btnDe:SetScript("OnClick", function()
    if type(setLanguage) == "function" then
      setLanguage("de")
    end
    UpdateHighlight()
  end)

  UpdateHighlight()

  return { label = label, btnEn = btnEn, btnDe = btnDe, UpdateHighlight = UpdateHighlight }, yOffset - LINE_HEIGHT
end

local function NormalizeStoredLayoutMode(layoutMode)
  if layoutMode == nil or layoutMode == false or layoutMode == "" then
    return DEFAULT_LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
  end
  if layoutMode == DEFAULT_LAYOUT_MODE_LAST_USED then
    return DEFAULT_LAYOUT_MODE_LAST_USED
  end
  if layoutMode == DEFAULT_LAYOUT_MODE_COMPACT_HORIZONTAL_2_LEGACY then
    return DEFAULT_LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
  end
  if
    layoutMode == DEFAULT_LAYOUT_MODE_EXPANDED
    or layoutMode == DEFAULT_LAYOUT_MODE_COMPACT_VERTICAL
    or layoutMode == DEFAULT_LAYOUT_MODE_COMPACT_HORIZONTAL
    or layoutMode == DEFAULT_LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
  then
    return layoutMode
  end
  return nil
end

local function CreateSettingsOptionSelector(
  parent,
  yOffset,
  labelKey,
  fallbackLabel,
  options,
  getLabels,
  getter,
  setter
)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local tn = Colors.TEXT_NORMAL or { 0.85, 0.85, 0.9 }
  label:SetTextColor(tn[1], tn[2], tn[3], 1)
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset - 3)
  label:SetText(fallbackLabel or "")

  local buttons = {}
  local buttonX = PADDING_X + 160
  local bgSec = Colors.BG_SECONDARY or { 0.12, 0.12, 0.18, 0.7 }
  local acBlue = Colors.ACCENT_BLUE or { 0.3, 0.65, 1 }
  local borderDefault = Colors.BORDER_DEFAULT or { 0.25, 0.25, 0.35, 0.5 }

  local function ApplyButtonStyle(button, selected)
    if type(button.SetBackdropColor) == "function" then
      if selected then
        button:SetBackdropColor(acBlue[1], acBlue[2], acBlue[3], 0.25)
      else
        button:SetBackdropColor(bgSec[1], bgSec[2], bgSec[3], bgSec[4])
      end
    end
    if type(button.SetBackdropBorderColor) == "function" then
      if selected then
        button:SetBackdropBorderColor(acBlue[1], acBlue[2], acBlue[3], 0.9)
      else
        button:SetBackdropBorderColor(borderDefault[1], borderDefault[2], borderDefault[3], borderDefault[4])
      end
    end
    if button.label and type(button.label.SetTextColor) == "function" then
      if selected then
        button.label:SetTextColor(1, 0.85, 0, 1)
      else
        button.label:SetTextColor(tn[1], tn[2], tn[3], 1)
      end
    end
  end

  for _, option in ipairs(options or {}) do
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    local buttonWidth = tonumber(option.width) or 40
    button:SetSize(buttonWidth, LANG_BUTTON_HEIGHT)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", buttonX, yOffset - 1)
    if type(button.SetBackdrop) == "function" then
      button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    end

    local buttonLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buttonLabel:SetPoint("CENTER", 0, 0)
    button.label = buttonLabel
    button._optionValue = option.value
    button._optionLabelKey = option.labelKey
    button._optionFallback = option.fallback or ""

    button:SetScript("OnClick", function()
      if type(setter) == "function" then
        setter(option.value)
      end
      local freshL = type(getLabels) == "function" and getLabels() or {}
      label:SetText((freshL and freshL[labelKey]) or fallbackLabel or "")
      local selectedMode = NormalizeStoredLayoutMode(type(getter) == "function" and getter() or nil)
      for _, btn in ipairs(buttons) do
        local btnText = freshL and freshL[btn._optionLabelKey] or btn._optionFallback or ""
        if btn.label and type(btn.label.SetText) == "function" then
          btn.label:SetText(btnText)
        end
        ApplyButtonStyle(btn, selectedMode == btn._optionValue)
      end
    end)

    table.insert(buttons, button)
    buttonX = buttonX + buttonWidth + 4
  end

  local function UpdateHighlight()
    local freshL = type(getLabels) == "function" and getLabels() or {}
    label:SetText((freshL and freshL[labelKey]) or fallbackLabel or "")
    local selectedMode = NormalizeStoredLayoutMode(type(getter) == "function" and getter() or nil)
    for _, button in ipairs(buttons) do
      local buttonText = freshL and freshL[button._optionLabelKey] or button._optionFallback or ""
      if button.label and type(button.label.SetText) == "function" then
        button.label:SetText(buttonText)
      end
      ApplyButtonStyle(button, selectedMode == button._optionValue)
    end
  end

  UpdateHighlight()

  return {
    label = label,
    buttons = buttons,
    UpdateHighlight = UpdateHighlight,
  }, yOffset - LINE_HEIGHT
end

local function ResolveSettingsOptions(opts)
  opts = opts or {}

  return {
    getL = type(opts.getL) == "function" and opts.getL or function()
      return {}
    end,
    setLanguage = opts.setLanguage,
    getCurrentLocale = opts.getCurrentLocale,
    getDB = type(opts.getDB) == "function" and opts.getDB or function()
      return {}
    end,
    onEscPanelToggle = opts.onEscPanelToggle,
    onBgAlphaChange = opts.onBgAlphaChange,
    onUiScaleChange = opts.onUiScaleChange,
    onSyncToggle = opts.onSyncToggle,
    onShowDpsColumnToggle = opts.onShowDpsColumnToggle,
    onMinimapButtonToggle = opts.onMinimapButtonToggle,
    onAutoOpenQueueToggle = opts.onAutoOpenQueueToggle,
    onAutoHideSoloToggle = opts.onAutoHideSoloToggle,
    onPortalNavigatorToggle = opts.onPortalNavigatorToggle,
    onDefaultLayoutModeChange = opts.onDefaultLayoutModeChange,
    onNameMaxCharsChange = opts.onNameMaxCharsChange,
    onMarkersLeaderOnlyToggle = opts.onMarkersLeaderOnlyToggle,
    onRosterColumnGuidesToggle = opts.onRosterColumnGuidesToggle,
    onTeleportColumnsChange = opts.onTeleportColumnsChange,
    onSoundToggle = opts.onSoundToggle,
    onQueueDebugToggle = opts.onQueueDebugToggle,
    onRuntimeLogToggle = opts.onRuntimeLogToggle,
  }
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

local function CreateSettingsTitle(canvas)
  local title = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  local ag = Colors.ACCENT_GOLD or { 1, 0.82, 0 }
  title:SetTextColor(ag[1], ag[2], ag[3], 1)
  title:SetPoint("TOPLEFT", canvas, "TOPLEFT", PADDING_X, -PADDING_TOP)
  title:SetText("isiLive")

  return title
end

local function BuildGeneralSettingsSection(canvas, yOffset, labels, config, controls)
  controls.generalHeader, yOffset = CreateSectionHeader(canvas, yOffset, labels.SETTINGS_SECTION_GENERAL or "General")

  controls.lang, yOffset = CreateLanguageSelector(
    canvas,
    yOffset,
    labels.SETTINGS_LANGUAGE or "Language",
    config.getCurrentLocale,
    config.setLanguage
  )

  controls.combatLog, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_COMBAT_LOGGING or "Advanced Combat Logging",
    function()
      return GetCVarEnabled("advancedCombatLogging")
    end,
    function(checked)
      SetCVarEnabled("advancedCombatLogging", checked)
    end
  )

  controls.dmReset, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_DM_RESET or "DM Reset on Dungeon Entry",
    function()
      return GetCVarEnabled("damageMeterResetOnNewInstance")
    end,
    function(checked)
      SetCVarEnabled("damageMeterResetOnNewInstance", checked)
    end
  )

  controls.escPanel, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_ESC_PANEL or "Show ESC Menu Shortcuts",
    function()
      local db = config.getDB()
      return db.showEscPanel ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.showEscPanel = checked
      if type(config.onEscPanelToggle) == "function" then
        config.onEscPanelToggle(checked)
      end
    end
  )

  controls.bgAlpha, yOffset = CreateSettingsSlider(
    canvas,
    yOffset,
    labels.SETTINGS_BG_ALPHA or "Background Opacity",
    0.3,
    1.0,
    0.05,
    function()
      local db = config.getDB()
      return type(db.bgAlpha) == "number" and db.bgAlpha or DEFAULT_BG_ALPHA
    end,
    function(val)
      local db = config.getDB()
      db.bgAlpha = val
      if type(config.onBgAlphaChange) == "function" then
        config.onBgAlphaChange(val)
      end
    end
  )

  return yOffset
end

local function BuildDisplaySettingsSection(canvas, yOffset, labels, config, controls)
  controls.displayHeader, yOffset = CreateSectionHeader(canvas, yOffset, labels.SETTINGS_SECTION_DISPLAY or "Display")

  controls.uiScale, yOffset = CreateSettingsSlider(
    canvas,
    yOffset,
    labels.SETTINGS_UI_SCALE or "UI Scale",
    0.5,
    2.0,
    0.05,
    function()
      local db = config.getDB()
      return type(db.uiScale) == "number" and db.uiScale or 1.0
    end,
    function(val)
      local db = config.getDB()
      db.uiScale = val
      if type(config.onUiScaleChange) == "function" then
        config.onUiScaleChange(val)
      end
    end,
    function(val)
      return string.format("%.0f%%", val * 100)
    end
  )

  if SHOW_DPS_COLUMN_SETTING then
    controls.showDps, yOffset = CreateSettingsCheckbox(
      canvas,
      yOffset,
      labels.SETTINGS_SHOW_DPS_COLUMN or "Show DPS Column",
      function()
        local db = config.getDB()
        return db.showDpsColumn ~= false
      end,
      function(checked)
        local db = config.getDB()
        db.showDpsColumn = checked
        if type(config.onShowDpsColumnToggle) == "function" then
          config.onShowDpsColumnToggle(checked)
        end
      end
    )
  end

  if SHOW_NAME_MAX_CHARS_SETTING then
    controls.nameMaxChars, yOffset = CreateSettingsSlider(
      canvas,
      yOffset,
      labels.SETTINGS_NAME_MAX_CHARS or "Name Length",
      4,
      20,
      1,
      function()
        local db = config.getDB()
        return type(db.nameMaxChars) == "number" and db.nameMaxChars or 10
      end,
      function(val)
        local db = config.getDB()
        db.nameMaxChars = math.floor(val + 0.5)
        if type(config.onNameMaxCharsChange) == "function" then
          config.onNameMaxCharsChange(db.nameMaxChars)
        end
      end,
      function(val)
        return string.format("%.0f", val)
      end
    )
  end

  if SHOW_TELEPORT_COLUMNS_SETTING then
    controls.tpColumns, yOffset = CreateSettingsSlider(
      canvas,
      yOffset,
      labels.SETTINGS_TELEPORT_COLUMNS or "Teleport Grid Columns",
      2,
      8,
      1,
      function()
        local db = config.getDB()
        return type(db.teleportColumns) == "number" and db.teleportColumns or 4
      end,
      function(val)
        local db = config.getDB()
        db.teleportColumns = math.floor(val + 0.5)
        if type(config.onTeleportColumnsChange) == "function" then
          config.onTeleportColumnsChange(db.teleportColumns)
        end
      end,
      function(val)
        return string.format("%.0f", val)
      end
    )
  end

  controls.minimapBtn, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_MINIMAP_BUTTON or "Minimap Button",
    function()
      local db = config.getDB()
      return db.showMinimapButton == true
    end,
    function(checked)
      local db = config.getDB()
      db.showMinimapButton = checked
      if type(config.onMinimapButtonToggle) == "function" then
        config.onMinimapButtonToggle(checked)
      end
    end
  )

  return yOffset
end

local function BuildBehaviorSettingsSection(canvas, yOffset, labels, config, controls)
  controls.behaviorHeader, yOffset =
    CreateSectionHeader(canvas, yOffset, labels.SETTINGS_SECTION_BEHAVIOR or "Behavior")

  controls.sync, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_SYNC_ENABLED or "Addon Sync",
    function()
      local db = config.getDB()
      return db.syncEnabled ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.syncEnabled = checked
      if type(config.onSyncToggle) == "function" then
        config.onSyncToggle(checked)
      end
    end
  )

  controls.autoOpen, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_AUTO_OPEN_QUEUE or "Auto-Open on M+ Queue",
    function()
      local db = config.getDB()
      return db.autoOpenOnQueue ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.autoOpenOnQueue = checked
      if type(config.onAutoOpenQueueToggle) == "function" then
        config.onAutoOpenQueueToggle(checked)
      end
    end
  )

  controls.autoHide, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_AUTO_HIDE_SOLO or "Auto-Hide when Solo",
    function()
      local db = config.getDB()
      return db.autoHideSolo ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.autoHideSolo = checked
      if type(config.onAutoHideSoloToggle) == "function" then
        config.onAutoHideSoloToggle(checked)
      end
    end
  )

  controls.defaultLayout, yOffset = CreateSettingsOptionSelector(
    canvas,
    yOffset,
    "SETTINGS_DEFAULT_OPEN_UI",
    labels.SETTINGS_DEFAULT_OPEN_UI or "Default UI on Open",
    {
      {
        value = DEFAULT_LAYOUT_MODE_LAST_USED,
        labelKey = "SETTINGS_DEFAULT_OPEN_UI_LAST",
        fallback = labels.SETTINGS_DEFAULT_OPEN_UI_LAST or "Last Used",
        width = 78,
      },
      {
        value = DEFAULT_LAYOUT_MODE_EXPANDED,
        labelKey = "SETTINGS_DEFAULT_OPEN_UI_M",
        fallback = labels.SETTINGS_DEFAULT_OPEN_UI_M or "M",
        width = 34,
      },
      {
        value = DEFAULT_LAYOUT_MODE_COMPACT_VERTICAL,
        labelKey = "SETTINGS_DEFAULT_OPEN_UI_V",
        fallback = labels.SETTINGS_DEFAULT_OPEN_UI_V or "V",
        width = 34,
      },
      {
        value = DEFAULT_LAYOUT_MODE_COMPACT_HORIZONTAL,
        labelKey = "SETTINGS_DEFAULT_OPEN_UI_H",
        fallback = labels.SETTINGS_DEFAULT_OPEN_UI_H or "H",
        width = 34,
      },
      {
        value = DEFAULT_LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL,
        labelKey = "SETTINGS_DEFAULT_OPEN_UI_M2",
        fallback = labels.SETTINGS_DEFAULT_OPEN_UI_M2 or "M2",
        width = 40,
      },
    },
    config.getL,
    function()
      local db = config.getDB()
      return NormalizeStoredLayoutMode(db.rosterDefaultLayoutMode)
    end,
    function(mode)
      local db = config.getDB()
      db.rosterDefaultLayoutMode = NormalizeStoredLayoutMode(mode)
      if type(config.onDefaultLayoutModeChange) == "function" then
        local callbackMode = db.rosterDefaultLayoutMode
        if callbackMode == DEFAULT_LAYOUT_MODE_LAST_USED then
          callbackMode = nil
        end
        config.onDefaultLayoutModeChange(callbackMode)
      end
    end
  )

  if SHOW_MARKERS_LEADER_ONLY_SETTING then
    controls.markers, yOffset = CreateSettingsCheckbox(
      canvas,
      yOffset,
      labels.SETTINGS_MARKERS_LEADER_ONLY or "Markers: Leader Only",
      function()
        local db = config.getDB()
        return db.markersLeaderOnly == true
      end,
      function(checked)
        local db = config.getDB()
        db.markersLeaderOnly = checked
        if type(config.onMarkersLeaderOnlyToggle) == "function" then
          config.onMarkersLeaderOnlyToggle(checked)
        end
      end
    )
  end

  controls.portalNavigator, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_SHOW_TIMEWAYS_NAVIGATOR or "Show Timeways Navigator",
    function()
      local db = config.getDB()
      return db.showPortalNavigator ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.showPortalNavigator = checked
      if type(config.onPortalNavigatorToggle) == "function" then
        config.onPortalNavigatorToggle(checked)
      end
    end,
    "SETTINGS_SHOW_TIMEWAYS_NAVIGATOR"
  )

  if SHOW_SOUND_ENABLED_SETTING then
    controls.sound, yOffset = CreateSettingsCheckbox(
      canvas,
      yOffset,
      labels.SETTINGS_SOUND_ENABLED or "Sound Notifications",
      function()
        local db = config.getDB()
        return db.soundEnabled == true
      end,
      function(checked)
        local db = config.getDB()
        db.soundEnabled = checked
        if type(config.onSoundToggle) == "function" then
          config.onSoundToggle(checked)
        end
      end
    )
  end

  return yOffset
end

local function BuildDebugSettingsSection(canvas, yOffset, labels, config, controls)
  controls.debugHeader, yOffset = CreateSectionHeader(canvas, yOffset, labels.SETTINGS_SECTION_DEBUG or "Debug")

  controls.queueDebug, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_QUEUE_DEBUG or "Queue Debug Log",
    function()
      local db = config.getDB()
      return db.queueDebug == true
    end,
    function(checked)
      local db = config.getDB()
      db.queueDebug = checked
      if type(config.onQueueDebugToggle) == "function" then
        config.onQueueDebugToggle(checked)
      end
    end
  )

  controls.runtimeLog, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_RUNTIME_LOG or "Runtime Log",
    function()
      local db = config.getDB()
      return db.runtimeLogEnabled == true
    end,
    function(checked)
      local db = config.getDB()
      db.runtimeLogEnabled = checked
      if type(config.onRuntimeLogToggle) == "function" then
        config.onRuntimeLogToggle(checked)
      end
    end
  )

  controls.columnGuides, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_ROSTER_COLUMN_GUIDES or "Column Guides",
    function()
      local db = config.getDB()
      return db.showRosterColumnGuides == true
    end,
    function(checked)
      local db = config.getDB()
      db.showRosterColumnGuides = checked
      if type(config.onRosterColumnGuidesToggle) == "function" then
        config.onRosterColumnGuidesToggle(checked)
      end
    end,
    "SETTINGS_ROSTER_COLUMN_GUIDES"
  )

  return yOffset
end

local function RefreshSettingsControls(controls, config)
  local freshL = config.getL()
  local db = config.getDB()

  controls.generalHeader:SetText(freshL.SETTINGS_SECTION_GENERAL or "General")
  controls.displayHeader:SetText(freshL.SETTINGS_SECTION_DISPLAY or "Display")
  controls.behaviorHeader:SetText(freshL.SETTINGS_SECTION_BEHAVIOR or "Behavior")
  controls.debugHeader:SetText(freshL.SETTINGS_SECTION_DEBUG or "Debug")
  controls.lang.label:SetText(freshL.SETTINGS_LANGUAGE or "Language")
  controls.combatLog.label:SetText(freshL.SETTINGS_COMBAT_LOGGING or "Advanced Combat Logging")
  controls.dmReset.label:SetText(freshL.SETTINGS_DM_RESET or "DM Reset on Dungeon Entry")
  controls.escPanel.label:SetText(freshL.SETTINGS_ESC_PANEL or "Show ESC Menu Shortcuts")
  controls.bgAlpha.label:SetText(freshL.SETTINGS_BG_ALPHA or "Background Opacity")
  controls.uiScale.label:SetText(freshL.SETTINGS_UI_SCALE or "UI Scale")
  controls.minimapBtn.label:SetText(freshL.SETTINGS_MINIMAP_BUTTON or "Minimap Button")
  controls.sync.label:SetText(freshL.SETTINGS_SYNC_ENABLED or "Addon Sync")
  controls.autoOpen.label:SetText(freshL.SETTINGS_AUTO_OPEN_QUEUE or "Auto-Open on M+ Queue")
  controls.autoHide.label:SetText(freshL.SETTINGS_AUTO_HIDE_SOLO or "Auto-Hide when Solo")
  if controls.defaultLayout then
    controls.defaultLayout.UpdateHighlight()
  end
  controls.queueDebug.label:SetText(freshL.SETTINGS_QUEUE_DEBUG or "Queue Debug Log")
  controls.runtimeLog.label:SetText(freshL.SETTINGS_RUNTIME_LOG or "Runtime Log")

  if controls.showDps then
    controls.showDps.label:SetText(freshL.SETTINGS_SHOW_DPS_COLUMN or "Show DPS Column")
  end
  if controls.nameMaxChars then
    controls.nameMaxChars.label:SetText(freshL.SETTINGS_NAME_MAX_CHARS or "Name Length")
  end
  if controls.tpColumns then
    controls.tpColumns.label:SetText(freshL.SETTINGS_TELEPORT_COLUMNS or "Teleport Grid Columns")
  end
  if controls.markers then
    controls.markers.label:SetText(freshL.SETTINGS_MARKERS_LEADER_ONLY or "Markers: Leader Only")
  end
  if controls.columnGuides then
    controls.columnGuides.label:SetText(freshL.SETTINGS_ROSTER_COLUMN_GUIDES or "Column Guides")
  end
  if controls.portalNavigator then
    controls.portalNavigator.label:SetText(freshL.SETTINGS_SHOW_TIMEWAYS_NAVIGATOR or "Show Timeways Navigator")
  end
  if controls.sound then
    controls.sound.label:SetText(freshL.SETTINGS_SOUND_ENABLED or "Sound Notifications")
  end

  controls.lang.UpdateHighlight()
  controls.combatLog.check:SetChecked(GetCVarEnabled("advancedCombatLogging"))
  controls.dmReset.check:SetChecked(GetCVarEnabled("damageMeterResetOnNewInstance"))
  controls.escPanel.check:SetChecked(db.showEscPanel ~= false)
  controls.bgAlpha.SetValueSilently(type(db.bgAlpha) == "number" and db.bgAlpha or DEFAULT_BG_ALPHA)
  controls.uiScale.SetValueSilently(type(db.uiScale) == "number" and db.uiScale or 1.0)
  controls.minimapBtn.check:SetChecked(db.showMinimapButton == true)
  controls.sync.check:SetChecked(db.syncEnabled ~= false)
  controls.autoOpen.check:SetChecked(db.autoOpenOnQueue ~= false)
  controls.autoHide.check:SetChecked(db.autoHideSolo ~= false)
  controls.queueDebug.check:SetChecked(db.queueDebug == true)
  controls.runtimeLog.check:SetChecked(db.runtimeLogEnabled == true)
  if controls.columnGuides then
    controls.columnGuides.check:SetChecked(db.showRosterColumnGuides == true)
  end
  if controls.portalNavigator then
    controls.portalNavigator.check:SetChecked(db.showPortalNavigator ~= false)
  end

  if controls.showDps then
    controls.showDps.check:SetChecked(db.showDpsColumn ~= false)
  end
  if controls.nameMaxChars then
    controls.nameMaxChars.SetValueSilently(type(db.nameMaxChars) == "number" and db.nameMaxChars or 10)
  end
  if controls.tpColumns then
    controls.tpColumns.SetValueSilently(type(db.teleportColumns) == "number" and db.teleportColumns or 4)
  end
  if controls.markers then
    controls.markers.check:SetChecked(db.markersLeaderOnly == true)
  end
  if controls.sound then
    controls.sound.check:SetChecked(db.soundEnabled == true)
  end
end

function SettingsPanel.Create(opts)
  local config = ResolveSettingsOptions(opts)

  local blizzardSettings = rawget(_G, "Settings")
  if type(blizzardSettings) ~= "table" or type(blizzardSettings.RegisterCanvasLayoutCategory) ~= "function" then
    return nil
  end

  local canvas = CreateFrame("Frame", nil, rawget(_G, "UIParent"), "BackdropTemplate")
  ApplySettingsBackdrop(canvas)

  local L = config.getL()
  local controls = {}

  CreateSettingsTitle(canvas)

  local y = -PADDING_TOP - 30
  y = BuildGeneralSettingsSection(canvas, y, L, config, controls)
  y = y - SECTION_GAP
  y = BuildDisplaySettingsSection(canvas, y, L, config, controls)
  y = y - SECTION_GAP
  y = BuildBehaviorSettingsSection(canvas, y, L, config, controls)
  y = y - SECTION_GAP
  y = BuildDebugSettingsSection(canvas, y, L, config, controls)

  local finalYOffset = tonumber(y) or 0
  local contentHeight = math.max(212, math.ceil((-finalYOffset) + PADDING_TOP))
  if type(canvas.SetHeight) == "function" then
    canvas:SetHeight(contentHeight)
  elseif type(canvas.SetSize) == "function" then
    local currentWidth = type(canvas.GetWidth) == "function" and canvas:GetWidth() or 680
    canvas:SetSize(currentWidth, contentHeight)
  end

  local category = blizzardSettings.RegisterCanvasLayoutCategory(canvas, "isiLive")
  if type(blizzardSettings.RegisterAddOnCategory) == "function" then
    blizzardSettings.RegisterAddOnCategory(category)
  end

  local function Refresh()
    RefreshSettingsControls(controls, config)
  end

  return {
    category = category,
    canvas = canvas,
    Refresh = Refresh,
  }
end
