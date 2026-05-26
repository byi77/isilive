local _, addonTable = ...
addonTable = addonTable or {}

local SettingsControls = {}
addonTable.SettingsControls = SettingsControls

local Colors = addonTable.UICommon and addonTable.UICommon.Colors or {}
local MeasureFontStringWidthSafe = addonTable.UICommon and addonTable.UICommon.MeasureFontStringWidthSafe
local ShowResetConfirmation = addonTable.SettingsReset
    and type(addonTable.SettingsReset.ShowResetConfirmation) == "function"
    and addonTable.SettingsReset.ShowResetConfirmation
  or function(_dialogKey, _confirmText, onAccept)
    if type(onAccept) == "function" then
      onAccept()
    end
  end

local PADDING_X = 16
local LINE_HEIGHT = 28
local HEADER_HEIGHT = 20
local HEADER_LINE_GAP = 4
local LANG_BUTTON_WIDTH = 90
local LANG_BUTTON_HEIGHT = 22
local SLIDER_WIDTH = 180
local SLIDER_HEIGHT = 16
local SETTINGS_CONTENT_WIDTH = 700
local SLIDER_LABEL_WIDTH = 150
local CHECKBOX_LABEL_WIDTH = SETTINGS_CONTENT_WIDTH - (PADDING_X * 2) - 28
local FULL_ROW_TEXT_WIDTH = SETTINGS_CONTENT_WIDTH - (PADDING_X * 2)
local INLINE_CONTROL_X = PADDING_X + 160
local INLINE_CONTROL_WIDTH = SETTINGS_CONTENT_WIDTH - INLINE_CONTROL_X - PADDING_X
local LANG_BUTTONS_PER_ROW = 5

local function ConfigureWrappingText(region, width, wordWrap)
  if type(region) ~= "table" then
    return
  end
  if type(region.SetWidth) == "function" and tonumber(width) and tonumber(width) > 0 then
    region:SetWidth(width)
  end
  if type(region.SetJustifyH) == "function" then
    region:SetJustifyH("LEFT")
  end
  if type(region.SetWordWrap) == "function" then
    region:SetWordWrap(wordWrap ~= false)
  end
  if type(region.SetNonSpaceWrap) == "function" then
    region:SetNonSpaceWrap(wordWrap ~= false)
  end
end

function SettingsControls.CreateSectionHeader(parent, yOffset, text)
  local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  local td = Colors.TEXT_DIM or { 0.5, 0.5, 0.6 }
  header:SetTextColor(td[1], td[2], td[3], 1)
  header:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset)
  header:SetJustifyH("LEFT")
  header:SetText(text or "")
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetHeight(2)
  line:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset - HEADER_HEIGHT)
  line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PADDING_X, yOffset - HEADER_HEIGHT)
  local ab = Colors.ACCENT_BLUE or { 0.3, 0.65, 1 }
  line:SetColorTexture(ab[1], ab[2], ab[3], 0.42)
  return header, yOffset - HEADER_HEIGHT - HEADER_LINE_GAP
end

function SettingsControls.MeasureWrappedTextHeight(textRegion, fallbackHeight, padding)
  local height = tonumber(fallbackHeight) or 0
  local measured = nil
  if type(textRegion) == "table" and type(textRegion.GetStringHeight) == "function" then
    measured = tonumber(textRegion:GetStringHeight())
  end
  if measured and measured > 0 then
    height = math.max(height, math.ceil(measured) + (tonumber(padding) or 0))
  end
  return height
end

local function GetTextBlockHeight(textRegion, fallbackHeight)
  local height = tonumber(fallbackHeight) or LINE_HEIGHT
  if type(textRegion) == "table" and type(textRegion.GetStringHeight) == "function" then
    local measured = tonumber(textRegion:GetStringHeight())
    if measured and measured > 0 then
      height = math.max(height, math.ceil(measured))
    end
  end
  return height
end

local function GetDescriptionTopYOffset(yOffset, label, fallbackLabelHeight)
  return yOffset - GetTextBlockHeight(label, fallbackLabelHeight) - 8
end

local function GetRowHeight(label, description, fallbackLabelHeight)
  local labelHeight = GetTextBlockHeight(label, fallbackLabelHeight)
  if description then
    return labelHeight + GetTextBlockHeight(description, 16) + 14
  end
  return math.max(LINE_HEIGHT, labelHeight + 8)
end

function SettingsControls.CreateSettingsIntro(parent, yOffset, text)
  local intro = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local td = Colors.TEXT_DIM or { 0.5, 0.5, 0.6 }
  intro:SetTextColor(td[1], td[2], td[3], 1)
  intro:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset)
  intro:SetWidth(math.max(240, SETTINGS_CONTENT_WIDTH - (PADDING_X * 2)))
  intro:SetJustifyH("LEFT")
  if type(intro.SetWordWrap) == "function" then
    intro:SetWordWrap(true)
  end
  intro:SetText(text or "")
  local height = SettingsControls.MeasureWrappedTextHeight(intro, 28, 8)
  return intro, yOffset - height
end

function SettingsControls.CreateSectionNote(parent, yOffset, text)
  local note = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  local td = Colors.TEXT_DIM or { 0.5, 0.5, 0.6 }
  note:SetTextColor(td[1], td[2], td[3], 1)
  note:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset)
  note:SetWidth(math.max(120, SETTINGS_CONTENT_WIDTH - (PADDING_X * 2)))
  note:SetJustifyH("LEFT")
  if type(note.SetWordWrap) == "function" then
    note:SetWordWrap(true)
  end
  note:SetText(text or "")
  local height = SettingsControls.MeasureWrappedTextHeight(note, 16, 6)
  return note, yOffset - height
end

function SettingsControls.CreateSettingsCheckbox(parent, yOffset, labelText, getter, setter, settingKey, options)
  options = type(options) == "table" and options or {}
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
  local labelWidth = tonumber(options.width) or CHECKBOX_LABEL_WIDTH
  ConfigureWrappingText(label, labelWidth, options.wordWrap ~= false)
  if type(options.justifyH) == "string" and type(label.SetJustifyH) == "function" then
    label:SetJustifyH(options.justifyH)
  end
  label:SetText(labelText or "")
  check.label = label
  local description = nil
  local descriptionText = type(options.descriptionText) == "string" and options.descriptionText or nil
  if descriptionText and descriptionText ~= "" then
    description = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local td = Colors.TEXT_DIM or { 0.5, 0.5, 0.6 }
    description:SetTextColor(td[1], td[2], td[3], 1)
    local descriptionWidth = tonumber(options.descriptionWidth)
      or math.max(120, SETTINGS_CONTENT_WIDTH - (PADDING_X * 2))
    ConfigureWrappingText(description, descriptionWidth, options.descriptionWordWrap ~= false)
    description:SetText(descriptionText)
    description:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, GetDescriptionTopYOffset(yOffset, label, 24))
    check.description = description
  end
  if type(getter) == "function" then
    check:SetChecked(getter())
  end
  check:SetScript("OnClick", function(self)
    if type(setter) == "function" then
      setter(self:GetChecked() and true or false)
    end
  end)
  local rowHeight = tonumber(options.rowHeight) or LINE_HEIGHT
  if options.rowHeight == nil and type(label.GetStringHeight) == "function" then
    local textHeight = tonumber(label:GetStringHeight()) or 0
    if textHeight > 0 then
      rowHeight = math.max(rowHeight, math.ceil(textHeight) + 8)
    end
  end
  if options.rowHeight == nil and description and type(description.GetStringHeight) == "function" then
    rowHeight = math.max(rowHeight, GetRowHeight(label, description, 24))
  end
  return { check = check, label = label, description = description }, yOffset - rowHeight
end

function SettingsControls.CreateSettingsSlider(
  parent,
  yOffset,
  labelText,
  minVal,
  maxVal,
  step,
  getter,
  setter,
  formatFunc,
  settingKey,
  controlOptions
)
  controlOptions = type(controlOptions) == "table" and controlOptions or {}
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local tn = Colors.TEXT_NORMAL or { 0.85, 0.85, 0.9 }
  label:SetTextColor(tn[1], tn[2], tn[3], 1)
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset - 3)
  label:SetText(labelText or "")
  ConfigureWrappingText(label, SLIDER_LABEL_WIDTH, true)
  local slider = CreateFrame("Slider", nil, parent, "BackdropTemplate")
  slider:SetSize(SLIDER_WIDTH, SLIDER_HEIGHT)
  slider:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X + 160, yOffset - 2)
  slider.label = label
  slider:SetOrientation("HORIZONTAL")
  slider:SetMinMaxValues(minVal, maxVal)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  if type(settingKey) == "string" and settingKey ~= "" then
    slider._settingKey = settingKey
  end
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
  local description = nil
  local descriptionText = type(controlOptions.descriptionText) == "string" and controlOptions.descriptionText or nil
  if descriptionText and descriptionText ~= "" then
    description = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local td = Colors.TEXT_DIM or { 0.5, 0.5, 0.6 }
    description:SetTextColor(td[1], td[2], td[3], 1)
    local descriptionWidth = tonumber(controlOptions.descriptionWidth)
      or math.max(120, SETTINGS_CONTENT_WIDTH - (PADDING_X * 2))
    ConfigureWrappingText(description, descriptionWidth, controlOptions.descriptionWordWrap ~= false)
    description:SetText(descriptionText)
    description:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, GetDescriptionTopYOffset(yOffset, label, 20))
    slider.description = description
  end
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

  local rowHeight = LINE_HEIGHT
  if type(label.GetStringHeight) == "function" then
    local textHeight = tonumber(label:GetStringHeight()) or 0
    if textHeight > 0 then
      rowHeight = math.max(rowHeight, math.ceil(textHeight) + 8)
    end
  end
  if description and type(description.GetStringHeight) == "function" then
    rowHeight = math.max(rowHeight, GetRowHeight(label, description, 20))
  end

  return {
    label = label,
    slider = slider,
    valueLabel = valueLabel,
    description = description,
    UpdateValueLabel = UpdateValueLabel,
    SetValueSilently = SetValueSilently,
  },
    yOffset - rowHeight
end

function SettingsControls.CreateSettingsActionButton(
  parent,
  yOffset,
  labelText,
  width,
  onClick,
  settingKey,
  subtitleText
)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  local buttonWidth = tonumber(width) or 200
  local hasSubtitle = type(subtitleText) == "string" and subtitleText ~= ""
  local confirmText = nil
  if type(settingKey) == "table" then
    confirmText = settingKey.confirmText
    settingKey = settingKey.settingKey
  end
  local buttonHeight = hasSubtitle and 40 or 30
  button:SetSize(buttonWidth, buttonHeight)
  button:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset)
  if type(settingKey) == "string" and settingKey ~= "" then
    button._settingKey = settingKey
  end

  if type(button.SetBackdrop) == "function" then
    button:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    local bgSec = Colors.BG_SECONDARY or { 0.12, 0.12, 0.18, 0.7 }
    button:SetBackdropColor(bgSec[1], bgSec[2], bgSec[3], bgSec[4])
    local bd = Colors.BORDER_DEFAULT or { 0.25, 0.25, 0.35, 0.5 }
    button:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
  end

  local hoverGlow = button:CreateTexture(nil, "BACKGROUND", nil, -1)
  if type(hoverGlow.SetAllPoints) == "function" then
    hoverGlow:SetAllPoints()
  end
  if type(hoverGlow.SetColorTexture) == "function" then
    local acBlue = Colors.ACCENT_BLUE or { 0.3, 0.65, 1 }
    hoverGlow:SetColorTexture(acBlue[1], acBlue[2], acBlue[3], 0.16)
  end
  if type(hoverGlow.Hide) == "function" then
    hoverGlow:Hide()
  end
  button.hoverGlow = hoverGlow

  local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local tn = Colors.TEXT_NORMAL or { 0.85, 0.85, 0.9 }
  local hoverLabelColor = Colors.ACCENT_BLUE or { 0.3, 0.65, 1 }
  if hasSubtitle then
    label:SetPoint("TOPLEFT", button, "TOPLEFT", 8, -6)
    ConfigureWrappingText(label, buttonWidth - 16, true)
    if type(label.SetJustifyH) == "function" then
      label:SetJustifyH("CENTER")
    end
  else
    label:SetPoint("CENTER", 0, 0)
    ConfigureWrappingText(label, buttonWidth - 12, true)
    if type(label.SetJustifyH) == "function" then
      label:SetJustifyH("CENTER")
    end
  end
  label:SetTextColor(tn[1], tn[2], tn[3], 1)
  label:SetText(labelText or "")
  button.label = label

  local labelHeight = 0
  if type(label.GetStringHeight) == "function" then
    labelHeight = tonumber(label:GetStringHeight()) or 0
  end
  if labelHeight > 0 then
    local desiredHeight = math.ceil(labelHeight) + (hasSubtitle and 18 or 14)
    if desiredHeight > buttonHeight then
      buttonHeight = desiredHeight
      button:SetSize(buttonWidth, buttonHeight)
    end
  end

  local subtitle = nil
  if hasSubtitle then
    subtitle = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local td = Colors.TEXT_DIM or { 0.5, 0.5, 0.6 }
    subtitle:SetTextColor(td[1], td[2], td[3], 1)
    subtitle:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 8, 5)
    ConfigureWrappingText(subtitle, buttonWidth - 16, true)
    if type(subtitle.SetJustifyH) == "function" then
      subtitle:SetJustifyH("CENTER")
    end
    subtitle:SetText(subtitleText)
  end
  button.subtitle = subtitle

  local function SetHoverState(isHover)
    local bgSec = Colors.BG_SECONDARY or { 0.12, 0.12, 0.18, 0.7 }
    local bd = Colors.BORDER_DEFAULT or { 0.25, 0.25, 0.35, 0.5 }
    if isHover then
      if type(button.SetBackdropColor) == "function" then
        button:SetBackdropColor(0.14, 0.14, 0.20, 0.92)
      end
      if type(button.SetBackdropBorderColor) == "function" then
        button:SetBackdropBorderColor(hoverLabelColor[1], hoverLabelColor[2], hoverLabelColor[3], 0.95)
      end
      if type(label.SetTextColor) == "function" then
        label:SetTextColor(1, 1, 1, 1)
      end
      if subtitle and type(subtitle.SetTextColor) == "function" then
        subtitle:SetTextColor(0.88, 0.92, 1, 1)
      end
      if hoverGlow and type(hoverGlow.Show) == "function" then
        hoverGlow:Show()
      end
    else
      if type(button.SetBackdropColor) == "function" then
        button:SetBackdropColor(bgSec[1], bgSec[2], bgSec[3], bgSec[4])
      end
      if type(button.SetBackdropBorderColor) == "function" then
        button:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
      end
      if type(label.SetTextColor) == "function" then
        label:SetTextColor(tn[1], tn[2], tn[3], 1)
      end
      if subtitle and type(subtitle.SetTextColor) == "function" then
        local td = Colors.TEXT_DIM or { 0.5, 0.5, 0.6 }
        subtitle:SetTextColor(td[1], td[2], td[3], 1)
      end
      if hoverGlow and type(hoverGlow.Hide) == "function" then
        hoverGlow:Hide()
      end
    end
  end

  button:SetScript("OnEnter", function()
    SetHoverState(true)
  end)
  button:SetScript("OnLeave", function()
    SetHoverState(false)
  end)

  button:SetScript("OnClick", function()
    if type(onClick) == "function" then
      if type(confirmText) == "string" and confirmText ~= "" then
        ShowResetConfirmation(settingKey, confirmText, onClick)
      else
        onClick()
      end
    end
  end)

  return {
    button = button,
    label = label,
    subtitle = subtitle,
  }, yOffset - buttonHeight - LINE_HEIGHT
end

function SettingsControls.CreateLanguageSelector(
  parent,
  yOffset,
  labelText,
  getCurrentLocale,
  setLanguage,
  controlOptions
)
  controlOptions = type(controlOptions) == "table" and controlOptions or {}
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local tn = Colors.TEXT_NORMAL or { 0.85, 0.85, 0.9 }
  label:SetTextColor(tn[1], tn[2], tn[3], 1)
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset - 3)
  label:SetText(labelText or "")
  local description = nil
  local descriptionText = type(controlOptions.descriptionText) == "string" and controlOptions.descriptionText or nil
  if descriptionText and descriptionText ~= "" then
    description = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local td = Colors.TEXT_DIM or { 0.5, 0.5, 0.6 }
    description:SetTextColor(td[1], td[2], td[3], 1)
    ConfigureWrappingText(
      description,
      tonumber(controlOptions.descriptionWidth) or math.max(120, FULL_ROW_TEXT_WIDTH),
      controlOptions.descriptionWordWrap ~= false
    )
    description:SetText(descriptionText)
    description:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, GetDescriptionTopYOffset(yOffset, label, 20))
  end

  local bgSec = Colors.BG_SECONDARY or { 0.12, 0.12, 0.18, 0.7 }
  local acBlue = Colors.ACCENT_BLUE or { 0.3, 0.65, 1 }

  local supported = addonTable.Languages and addonTable.Languages.SUPPORTED or {}
  local buttons = {}
  local rowIndex = 0

  for i, lang in ipairs(supported) do
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(LANG_BUTTON_WIDTH, LANG_BUTTON_HEIGHT)
    local posInRow = (i - 1) % LANG_BUTTONS_PER_ROW
    if posInRow == 0 then
      local rowYOffset = description and (GetRowHeight(label, description, 20) - LINE_HEIGHT + 5) or 0
      local rowY = yOffset - 1 - rowYOffset - (math.floor((i - 1) / LANG_BUTTONS_PER_ROW) * (LANG_BUTTON_HEIGHT + 3))
      btn:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X + 120, rowY)
    else
      btn:SetPoint("LEFT", buttons[#buttons].btn, "RIGHT", 2, 0)
    end
    if type(btn.SetBackdrop) == "function" then
      btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    end
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("CENTER", 0, 0)
    lbl:SetWidth(LANG_BUTTON_WIDTH - 4)
    if type(lbl.SetWordWrap) == "function" then
      lbl:SetWordWrap(false)
    end
    if type(lbl.SetNonSpaceWrap) == "function" then
      lbl:SetNonSpaceWrap(false)
    end
    lbl:SetText(lang.buttonLabel)

    local tag = lang.tag
    btn:SetScript("OnClick", function()
      if type(setLanguage) == "function" then
        setLanguage(tag)
      end
    end)

    buttons[#buttons + 1] = { btn = btn, tag = tag }
    rowIndex = math.floor((i - 1) / LANG_BUTTONS_PER_ROW)
  end

  local numRows = rowIndex + 1
  local totalHeight = (numRows * LINE_HEIGHT)
    + (description and GetRowHeight(label, description, 20) - LINE_HEIGHT or 0)

  local function UpdateHighlight()
    local current = type(getCurrentLocale) == "function" and getCurrentLocale() or "enUS"
    local resolved = addonTable.Languages and addonTable.Languages.ResolveTag(current) or current
    for _, entry in ipairs(buttons) do
      if type(entry.btn.SetBackdropColor) == "function" then
        if entry.tag == resolved then
          entry.btn:SetBackdropColor(acBlue[1], acBlue[2], acBlue[3], 0.25)
        else
          entry.btn:SetBackdropColor(bgSec[1], bgSec[2], bgSec[3], bgSec[4])
        end
      end
    end
  end

  for _, entry in ipairs(buttons) do
    local existingScript = entry.btn:GetScript("OnClick")
    entry.btn:SetScript("OnClick", function()
      if existingScript then
        existingScript()
      end
      UpdateHighlight()
    end)
  end

  UpdateHighlight()

  return { label = label, description = description, buttons = buttons, UpdateHighlight = UpdateHighlight },
    yOffset - totalHeight
end

function SettingsControls.CreateSettingsOptionSelector(
  parent,
  yOffset,
  labelKey,
  fallbackLabel,
  options,
  getLabels,
  getter,
  setter,
  normalizeValue,
  labelOnTop,
  controlOptions
)
  controlOptions = type(controlOptions) == "table" and controlOptions or {}
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local tn = Colors.TEXT_NORMAL or { 0.85, 0.85, 0.9 }
  label:SetTextColor(tn[1], tn[2], tn[3], 1)
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset - 3)
  ConfigureWrappingText(label, labelOnTop and math.max(240, FULL_ROW_TEXT_WIDTH) or SLIDER_LABEL_WIDTH, true)
  label:SetText(fallbackLabel or "")

  local description = nil
  local descriptionText = type(controlOptions.descriptionText) == "string" and controlOptions.descriptionText or nil
  if descriptionText and descriptionText ~= "" then
    description = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local td = Colors.TEXT_DIM or { 0.5, 0.5, 0.6 }
    description:SetTextColor(td[1], td[2], td[3], 1)
    local descriptionWidth = tonumber(controlOptions.descriptionWidth)
      or math.max(120, SETTINGS_CONTENT_WIDTH - (PADDING_X * 2))
    ConfigureWrappingText(description, descriptionWidth, controlOptions.descriptionWordWrap ~= false)
    description:SetText(descriptionText)
    description:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, GetDescriptionTopYOffset(yOffset, label, 20))
  end

  local buttons = {}
  local buttonX = labelOnTop and PADDING_X or INLINE_CONTROL_X
  local labelBlockHeight = GetTextBlockHeight(label, labelOnTop and 20 or LINE_HEIGHT)
  local descriptionBlockHeight = description and GetTextBlockHeight(description, 16) or 0
  local buttonYOffset = labelOnTop
      and (description and (yOffset - labelBlockHeight - descriptionBlockHeight - 14) or (yOffset - labelBlockHeight - 8))
    or yOffset
  local bgSec = Colors.BG_SECONDARY or { 0.12, 0.12, 0.18, 0.7 }
  local acBlue = Colors.ACCENT_BLUE or { 0.3, 0.65, 1 }
  local borderDefault = Colors.BORDER_DEFAULT or { 0.25, 0.25, 0.35, 0.5 }
  local buttonPadding = 22
  local currentOptions = {}
  local buttonRowCount = 1

  local function ResolveButtonWidth(button)
    local minWidth = tonumber(button._optionMinWidth) or 40
    local measuredWidth = nil
    if button.label and type(MeasureFontStringWidthSafe) == "function" then
      measuredWidth = MeasureFontStringWidthSafe(button.label)
    end
    if measuredWidth and measuredWidth > 0 then
      return math.max(minWidth, math.ceil(measuredWidth) + buttonPadding)
    end
    return minWidth
  end

  local function UpdateButtonLayout()
    local x = labelOnTop and PADDING_X or INLINE_CONTROL_X
    local row = 0
    local maxRight = PADDING_X + FULL_ROW_TEXT_WIDTH
    for _, button in ipairs(buttons) do
      local width = ResolveButtonWidth(button)
      if x > PADDING_X and x + width > maxRight then
        x = PADDING_X
        row = row + 1
      end
      if type(button.SetSize) == "function" then
        button:SetSize(width, LANG_BUTTON_HEIGHT)
      end
      if type(button.ClearAllPoints) == "function" then
        button:ClearAllPoints()
      end
      button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, buttonYOffset - 1 - (row * (LANG_BUTTON_HEIGHT + 4)))
      x = x + width + 4
    end
    buttonRowCount = row + 1
  end

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

  local function UpdateHighlight()
    local freshL = type(getLabels) == "function" and getLabels() or {}
    label:SetText((freshL and freshL[labelKey]) or fallbackLabel or "")
    if description and type(description.SetText) == "function" then
      local freshDescription = freshL and freshL[controlOptions.descriptionKey] or controlOptions.descriptionText or ""
      description:SetText(freshDescription)
    end
    local selectedMode = type(normalizeValue) == "function"
        and normalizeValue(type(getter) == "function" and getter() or nil)
      or (type(getter) == "function" and getter() or nil)
    for _, button in ipairs(buttons) do
      local buttonText = freshL and freshL[button._optionLabelKey] or button._optionFallback or ""
      if button.label and type(button.label.SetText) == "function" then
        button.label:SetText(buttonText)
      end
      ApplyButtonStyle(button, selectedMode == button._optionValue)
    end
    UpdateButtonLayout()
  end

  local function CreateOptionButton(option)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    local buttonWidth = tonumber(option.width) or 40
    button:SetSize(buttonWidth, LANG_BUTTON_HEIGHT)
    if type(button.SetBackdrop) == "function" then
      button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    end

    local buttonLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buttonLabel:SetPoint("CENTER", 0, 0)
    ConfigureWrappingText(buttonLabel, math.max(28, buttonWidth - 8), false)
    if type(buttonLabel.SetJustifyH) == "function" then
      buttonLabel:SetJustifyH("CENTER")
    end
    button.label = buttonLabel
    button._optionValue = option.value
    button._optionLabelKey = option.labelKey
    button._optionFallback = option.fallback or ""
    button._optionMinWidth = buttonWidth

    button:SetScript("OnClick", function()
      if type(setter) == "function" then
        setter(option.value)
      end
      if type(getLabels) == "function" then
        local freshL = getLabels()
        label:SetText((freshL and freshL[labelKey]) or fallbackLabel or "")
      end
      UpdateHighlight()
    end)

    return button
  end

  local function UpdateOptions(newOptions)
    currentOptions = type(newOptions) == "table" and newOptions or {}
    for _, button in ipairs(buttons) do
      if type(button.Hide) == "function" then
        button:Hide()
      end
    end
    buttons = {}
    buttonX = labelOnTop and PADDING_X or INLINE_CONTROL_X
    for _, option in ipairs(currentOptions) do
      local button = CreateOptionButton(option)
      button:SetPoint("TOPLEFT", parent, "TOPLEFT", buttonX, buttonYOffset - 1)
      table.insert(buttons, button)
      buttonX = buttonX + ResolveButtonWidth(button) + 4
    end
    UpdateHighlight()
  end

  UpdateOptions(options)

  local buttonRowsHeight = math.max(1, buttonRowCount) * (LANG_BUTTON_HEIGHT + 4)
  local totalHeight = labelOnTop
      and (labelBlockHeight + (description and descriptionBlockHeight + 8 or 0) + buttonRowsHeight + 10)
    or math.max(description and (LINE_HEIGHT * 2) or LINE_HEIGHT, buttonRowsHeight + 4)

  return {
    label = label,
    buttons = buttons,
    description = description,
    UpdateHighlight = UpdateHighlight,
    UpdateOptions = UpdateOptions,
  },
    yOffset - totalHeight
end

function SettingsControls.CreateSettingsDropdownSelector(
  parent,
  yOffset,
  labelKey,
  fallbackLabel,
  options,
  getLabels,
  getter,
  setter,
  normalizeValue,
  labelOnTop,
  controlOptions
)
  controlOptions = type(controlOptions) == "table" and controlOptions or {}
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local tn = Colors.TEXT_NORMAL or { 0.85, 0.85, 0.9 }
  label:SetTextColor(tn[1], tn[2], tn[3], 1)
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset - 3)
  ConfigureWrappingText(label, labelOnTop and math.max(240, FULL_ROW_TEXT_WIDTH) or SLIDER_LABEL_WIDTH, true)
  local initialLabels = type(getLabels) == "function" and getLabels() or {}
  label:SetText((initialLabels and initialLabels[labelKey]) or fallbackLabel or "")

  local description = nil
  local descriptionText = type(controlOptions.descriptionText) == "string" and controlOptions.descriptionText or nil
  if descriptionText and descriptionText ~= "" then
    description = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local td = Colors.TEXT_DIM or { 0.5, 0.5, 0.6 }
    description:SetTextColor(td[1], td[2], td[3], 1)
    local descriptionWidth = tonumber(controlOptions.descriptionWidth)
      or math.max(120, SETTINGS_CONTENT_WIDTH - (PADDING_X * 2))
    ConfigureWrappingText(description, descriptionWidth, controlOptions.descriptionWordWrap ~= false)
    description:SetText(descriptionText)
    description:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, GetDescriptionTopYOffset(yOffset, label, 20))
  end

  local buttonWidth = math.min(420, INLINE_CONTROL_WIDTH)
  local buttonHeight = 24
  local labelBlockHeight = GetTextBlockHeight(label, labelOnTop and 20 or LINE_HEIGHT)
  local descriptionBlockHeight = description and GetTextBlockHeight(description, 16) or 0
  local dropdownButton = CreateFrame("Button", nil, parent, "BackdropTemplate")
  dropdownButton._settingKey = labelKey
  dropdownButton._label = label
  dropdownButton.description = description
  dropdownButton:SetSize(buttonWidth, buttonHeight)
  dropdownButton:SetPoint(
    "TOPLEFT",
    parent,
    "TOPLEFT",
    labelOnTop and PADDING_X or INLINE_CONTROL_X,
    labelOnTop
        and (description and (yOffset - labelBlockHeight - descriptionBlockHeight - 14) or (yOffset - labelBlockHeight - 8))
      or yOffset
  )

  if type(dropdownButton.SetBackdrop) == "function" then
    dropdownButton:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    local bgSec = Colors.BG_SECONDARY or { 0.12, 0.12, 0.18, 0.7 }
    local bd = Colors.BORDER_DEFAULT or { 0.25, 0.25, 0.35, 0.5 }
    dropdownButton:SetBackdropColor(bgSec[1], bgSec[2], bgSec[3], bgSec[4])
    dropdownButton:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
  end

  local dropdownLabel = dropdownButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  dropdownLabel:SetPoint("LEFT", dropdownButton, "LEFT", 8, 0)
  dropdownLabel:SetPoint("RIGHT", dropdownButton, "RIGHT", -24, 0)
  dropdownLabel:SetJustifyH("LEFT")
  ConfigureWrappingText(dropdownLabel, buttonWidth - 32, false)
  dropdownLabel:SetTextColor(tn[1], tn[2], tn[3], 1)
  dropdownLabel:SetText(fallbackLabel or "")
  dropdownButton._dropdownLabel = dropdownLabel

  local arrow = dropdownButton:CreateTexture(nil, "ARTWORK")
  arrow:SetSize(12, 12)
  arrow:SetPoint("RIGHT", dropdownButton, "RIGHT", -8, 0)
  arrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
  arrow:SetVertexColor(0.8, 0.8, 0.8)

  local menuParent = rawget(_G, "UIParent") or parent
  local menuFrame = CreateFrame("Frame", nil, menuParent, "BackdropTemplate")
  menuFrame:SetSize(buttonWidth, 0)
  menuFrame:SetFrameStrata("DIALOG")
  menuFrame:Hide()
  menuFrame:SetClampedToScreen(true)

  if type(menuFrame.SetBackdrop) == "function" then
    menuFrame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    local bg = Colors.BG_SECONDARY or { 0.12, 0.12, 0.18, 0.88 }
    local bd = Colors.BORDER_DEFAULT or { 0.25, 0.25, 0.35, 0.85 }
    menuFrame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    menuFrame:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
  end

  local clickCatcher = CreateFrame("Button", nil, menuParent)
  clickCatcher:SetAllPoints(menuParent)
  clickCatcher:SetFrameStrata("BACKGROUND")
  clickCatcher:Hide()
  clickCatcher:SetScript("OnMouseDown", function()
    menuFrame:Hide()
    clickCatcher:Hide()
  end)

  local currentOptions = type(options) == "table" and options or {}
  local labelsCache = {}

  local function ResolveOptionLabel(option, freshL)
    return (freshL and freshL[option.labelKey]) or option.fallback or tostring(option.value or "")
  end

  local function GetSelectedValue()
    local value = type(getter) == "function" and getter() or nil
    if type(normalizeValue) == "function" then
      return normalizeValue(value)
    end
    return value
  end

  local optionButtons = {}

  local function RefreshDropdown()
    labelsCache = type(getLabels) == "function" and getLabels() or {}
    label:SetText((labelsCache and labelsCache[labelKey]) or fallbackLabel or "")
    if description then
      local descriptionKey = controlOptions.descriptionKey
      description:SetText((descriptionKey and labelsCache and labelsCache[descriptionKey]) or descriptionText or "")
    end
    local selectedValue = GetSelectedValue()
    local selectedText = fallbackLabel or ""
    for _, option in ipairs(currentOptions) do
      if option.value == selectedValue then
        selectedText = ResolveOptionLabel(option, labelsCache)
        break
      end
    end
    dropdownLabel:SetText(selectedText)
    for index, option in ipairs(currentOptions) do
      local btn = optionButtons[index]
      if btn and btn.label then
        btn.label:SetText(ResolveOptionLabel(option, labelsCache))
      end
    end
  end

  local function HideMenu()
    if menuFrame:IsShown() then
      menuFrame:Hide()
      clickCatcher:Hide()
    end
  end

  local function ShowMenu()
    if #currentOptions == 0 then
      return
    end
    local menuHeight = 0
    for index, option in ipairs(currentOptions) do
      local btn = optionButtons[index]
      if not btn then
        btn = CreateFrame("Button", nil, menuFrame, "BackdropTemplate")
        btn:SetSize(buttonWidth - 2, buttonHeight)
        btn:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 1, -((index - 1) * buttonHeight) - 1)
        if type(btn.SetBackdrop) == "function" then
          btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
          })
          local bgItem = Colors.BG_SECONDARY or { 0.12, 0.12, 0.18, 0.65 }
          local bdItem = Colors.BORDER_DEFAULT or { 0.25, 0.25, 0.35, 0.5 }
          btn:SetBackdropColor(bgItem[1], bgItem[2], bgItem[3], bgItem[4])
          btn:SetBackdropBorderColor(bdItem[1], bdItem[2], bdItem[3], bdItem[4])
        end
        local btnLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btnLabel:SetPoint("LEFT", btn, "LEFT", 8, 0)
        btnLabel:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        btnLabel:SetJustifyH("LEFT")
        ConfigureWrappingText(btnLabel, buttonWidth - 16, false)
        if type(btnLabel.SetTextColor) == "function" then
          btnLabel:SetTextColor(tn[1], tn[2], tn[3], 1)
        end
        btn.label = btnLabel
        btn:SetScript("OnEnter", function(self)
          if type(self.SetBackdropColor) == "function" then
            local acBlue = Colors.ACCENT_BLUE or { 0.3, 0.65, 1 }
            self:SetBackdropColor(acBlue[1], acBlue[2], acBlue[3], 0.18)
          end
        end)
        btn:SetScript("OnLeave", function(self)
          if type(self.SetBackdropColor) == "function" then
            local bgItem = Colors.BG_SECONDARY or { 0.12, 0.12, 0.18, 0.65 }
            self:SetBackdropColor(bgItem[1], bgItem[2], bgItem[3], bgItem[4])
          end
        end)
        optionButtons[index] = btn
      end
      local optionText = ResolveOptionLabel(option, labelsCache)
      btn.label:SetText(optionText)
      btn:SetScript("OnClick", function()
        if type(setter) == "function" then
          setter(option.value)
        end
        RefreshDropdown()
        HideMenu()
      end)
      optionButtons[index] = btn
      menuHeight = menuHeight + buttonHeight
    end
    menuFrame:SetHeight(menuHeight + 2)
    menuFrame:SetPoint("TOPLEFT", dropdownButton, "BOTTOMLEFT", 0, -2)
    menuFrame:Show()
    clickCatcher:Show()
  end

  dropdownButton:SetScript("OnClick", function()
    if menuFrame:IsShown() then
      HideMenu()
    else
      ShowMenu()
    end
  end)

  dropdownButton:SetScript("OnEnter", function(self)
    if type(self.SetBackdropColor) == "function" then
      self:SetBackdropColor(0.14, 0.14, 0.20, 0.92)
    end
  end)
  dropdownButton:SetScript("OnLeave", function(self)
    if type(self.SetBackdropColor) == "function" then
      local bgSec = Colors.BG_SECONDARY or { 0.12, 0.12, 0.18, 0.7 }
      self:SetBackdropColor(bgSec[1], bgSec[2], bgSec[3], bgSec[4])
    end
  end)

  local function UpdateOptions(newOptions)
    for _, btn in ipairs(optionButtons) do
      if type(btn) == "table" and type(btn.Hide) == "function" then
        btn:Hide()
      end
    end
    currentOptions = type(newOptions) == "table" and newOptions or {}
    dropdownButton._options = currentOptions
    optionButtons = {}
    HideMenu()
    RefreshDropdown()
  end

  dropdownButton._options = currentOptions
  RefreshDropdown()

  local dropdownRowHeight = labelOnTop
      and (labelBlockHeight + (description and descriptionBlockHeight + 8 or 0) + buttonHeight + 10)
    or math.max(
      LINE_HEIGHT,
      description and (LINE_HEIGHT + math.ceil(tonumber(description:GetStringHeight()) or 0) + 6) or 0
    )

  return {
    label = label,
    description = description,
    button = dropdownButton,
    UpdateHighlight = RefreshDropdown,
    UpdateOptions = UpdateOptions,
  },
    yOffset - dropdownRowHeight
end
