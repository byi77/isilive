local _, addonTable = ...

addonTable = addonTable or {}

local UICommon = {}
addonTable.UICommon = UICommon

UICommon.DEFAULT_BG_ALPHA = 0.50
UICommon.CYRILLIC_FONT_PATH = "Fonts\\ARIALN.TTF"
UICommon.LOCALE_FONT_OVERRIDES = {
  ruRU = UICommon.CYRILLIC_FONT_PATH,
}

UICommon.Colors = {
  BG_PRIMARY = { 0.08, 0.08, 0.12, UICommon.DEFAULT_BG_ALPHA },
  BG_SECONDARY = { 0.12, 0.12, 0.18, 0.7 },
  BORDER_DEFAULT = { 0.35, 0.35, 0.50, 0.65 },
  ACCENT_GOLD = { 1, 0.82, 0 },
  ACCENT_BLUE = { 0.3, 0.65, 1 },
  TEXT_NORMAL = { 0.85, 0.85, 0.9 },
  TEXT_DIM = { 0.5, 0.5, 0.6 },
  HOVER_HIGHLIGHT = { 1, 1, 1, 0.10 },
  ROW_ALT = { 1, 1, 1, 0.03 },
}

function UICommon.GetLocalizedText(key, fallback)
  if type(key) ~= "string" or key == "" then
    return fallback or ""
  end

  local textTables = addonTable.Texts
      and type(addonTable.Texts.GetLocaleTables) == "function"
      and addonTable.Texts.GetLocaleTables()
    or nil
  local getLocale = rawget(_G, "GetLocale")
  local localeKey = type(getLocale) == "function" and getLocale() or "enUS"
  local labels = type(textTables) == "table" and (textTables[localeKey] or textTables.enUS) or nil
  if type(labels) == "table" then
    local value = labels[key]
    if type(value) == "string" and value ~= "" then
      return value
    end
  end

  return fallback or ""
end

local function ResolveActiveLocale(localeTag)
  if type(localeTag) == "string" and localeTag ~= "" then
    return localeTag
  end

  local db = rawget(_G, "IsiLiveDB")
  if type(db) == "table" and type(db.locale) == "string" and db.locale ~= "" then
    return db.locale
  end

  local getLocale = rawget(_G, "GetLocale")
  if type(getLocale) == "function" then
    local ok, locale = pcall(getLocale)
    if ok and type(locale) == "string" and locale ~= "" then
      return locale
    end
  end

  return "enUS"
end

function UICommon.GetLocaleFontPath(localeTag)
  return UICommon.LOCALE_FONT_OVERRIDES[ResolveActiveLocale(localeTag)]
end

local function ApplyFontPath(fontString, fontPath)
  if
    type(fontString) ~= "table"
    or type(fontString.GetFont) ~= "function"
    or type(fontString.SetFont) ~= "function"
  then
    return false
  end

  if type(fontPath) ~= "string" or fontPath == "" then
    return false
  end

  local _, fontSize, fontFlags = fontString:GetFont()
  if type(fontSize) ~= "number" then
    return false
  end

  fontString:SetFont(fontPath, fontSize, fontFlags)
  return true
end

local function CaptureReadableFontBaseline(fontString)
  if
    type(fontString) ~= "table"
    or type(fontString.GetFont) ~= "function"
    or type(fontString.SetFont) ~= "function"
  then
    return nil
  end

  if type(fontString._isiLiveReadableFontBaseline) == "table" then
    return fontString._isiLiveReadableFontBaseline
  end

  local fontPath, fontSize, fontFlags = fontString:GetFont()
  if type(fontPath) ~= "string" or type(fontSize) ~= "number" then
    return nil
  end

  fontString._isiLiveReadableFontBaseline = {
    path = fontPath,
    size = fontSize,
    flags = fontFlags,
  }
  return fontString._isiLiveReadableFontBaseline
end

function UICommon.ApplyLocaleFont(fontString, localeTag)
  return ApplyFontPath(fontString, UICommon.GetLocaleFontPath(localeTag))
end

function UICommon.TextNeedsCyrillicFont(text)
  if type(text) ~= "string" or text == "" then
    return false
  end

  return text:find("[\208-\211][\128-\191]") ~= nil
end

function UICommon.ApplyReadableFontForText(fontString, text, localeTag)
  local baseline = CaptureReadableFontBaseline(fontString)
  if UICommon.TextNeedsCyrillicFont(text) then
    return ApplyFontPath(fontString, UICommon.CYRILLIC_FONT_PATH)
  end

  if UICommon.ApplyLocaleFont(fontString, localeTag) then
    return true
  end

  if baseline then
    return ApplyFontPath(fontString, baseline.path)
  end

  return false
end

function UICommon.SetReadableText(fontString, text, localeTag)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end

  local value = tostring(text or "")
  UICommon.ApplyReadableFontForText(fontString, value, localeTag)
  fontString:SetText(value)
  return true
end

function UICommon.IsSecretValue(value)
  local isSecretValue = rawget(_G, "issecretvalue")
  if type(isSecretValue) ~= "function" then
    return false
  end

  local ok, result = pcall(isSecretValue, value)
  return ok and result == true
end

function UICommon.MeasureFontStringWidthSafe(fontString)
  if type(fontString) ~= "table" or type(fontString.GetStringWidth) ~= "function" then
    return nil
  end

  local ok, width = pcall(fontString.GetStringWidth, fontString)
  if not ok or width == nil or UICommon.IsSecretValue(width) then
    return nil
  end

  local numberOk, numericWidth = pcall(tonumber, width)
  if not numberOk or numericWidth == nil or UICommon.IsSecretValue(numericWidth) then
    return nil
  end

  local positiveOk, isPositive = pcall(function()
    return numericWidth > 0
  end)
  if not positiveOk or not isPositive then
    return nil
  end

  local ceilOk, ceiledWidth = pcall(math.ceil, numericWidth)
  if ceilOk and type(ceiledWidth) == "number" then
    return ceiledWidth
  end
  return nil
end

function UICommon.GetBackgroundAlpha()
  local db = rawget(_G, "IsiLiveDB")
  if type(db) == "table" and type(db.bgAlpha) == "number" then
    return db.bgAlpha
  end
  return UICommon.DEFAULT_BG_ALPHA
end

-- Apply the configured background alpha to the BG_PRIMARY palette and to the
-- main / panel / settings frames in one place. Used by the ADDON_LOADED
-- restore path as well as the live settings slider and the reset-defaults
-- action — keeping the palette mutation and the frame paints in sync.
function UICommon.ApplyBgAlpha(frames, alpha)
  if type(alpha) ~= "number" then
    return
  end

  if type(UICommon.Colors) == "table" and type(UICommon.Colors.BG_PRIMARY) == "table" then
    UICommon.Colors.BG_PRIMARY[4] = alpha
  end

  frames = type(frames) == "table" and frames or {}

  local mainFrame = frames.mainFrame
  if mainFrame and type(mainFrame.SetBackdropColor) == "function" then
    mainFrame:SetBackdropColor(0, 0, 0, alpha)
  end

  local bg = UICommon.Colors and UICommon.Colors.BG_PRIMARY or { 0.08, 0.08, 0.12, alpha }

  local panelFrame = frames.panelFrame
  if panelFrame and type(panelFrame.SetBackdropColor) == "function" then
    panelFrame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
  end

  local settingsCanvas = frames.settingsCanvas
  if settingsCanvas and type(settingsCanvas.SetBackdropColor) == "function" then
    settingsCanvas:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
  end
end

local BACKDROP_PANEL = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8",
  edgeSize = 1,
  insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local BACKDROP_FLAT_BUTTON = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8",
  edgeSize = 1,
  insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

local BACKDROP_BG_ONLY = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
}

UICommon.BACKDROP_PRESETS = {
  PRIMARY = {
    backdrop = BACKDROP_PANEL,
    bgColor = function()
      local bg = UICommon.Colors.BG_PRIMARY
      return bg[1], bg[2], bg[3], UICommon.GetBackgroundAlpha()
    end,
    borderColor = UICommon.Colors.BORDER_DEFAULT,
  },
  MAIN_FRAME = {
    backdrop = BACKDROP_PANEL,
    bgColor = function()
      return 0, 0, 0, UICommon.GetBackgroundAlpha()
    end,
    borderColor = { 0.3, 0.65, 1, 0.25 },
  },
  NOTICE = {
    backdrop = BACKDROP_PANEL,
    bgColor = { 0.05, 0.05, 0.08, 0.75 },
    borderColor = { 1, 0.82, 0, 0.45 },
  },
  TOOLTIP = {
    backdrop = BACKDROP_PANEL,
    bgColor = { 0, 0, 0, 0.92 },
    borderColor = UICommon.Colors.BORDER_DEFAULT,
  },
  CLOSE_BUTTON = {
    backdrop = BACKDROP_PANEL,
    bgColor = { 0.08, 0.015, 0.012, 0.92 },
    borderColor = { 1.0, 0.68, 0.16, 0.85 },
  },
  FLAT_BUTTON = {
    backdrop = BACKDROP_FLAT_BUTTON,
    bgColor = UICommon.Colors.BG_SECONDARY,
    borderColor = UICommon.Colors.BORDER_DEFAULT,
  },
  BUTTON_BG = {
    backdrop = BACKDROP_BG_ONLY,
    bgColor = UICommon.Colors.BG_SECONDARY,
  },
  CD_BOX = {
    backdrop = BACKDROP_FLAT_BUTTON,
    bgColor = { 0.10, 0.10, 0.16, 0.80 },
    borderColor = { 0.30, 0.30, 0.45, 0.70 },
  },
  MPLUS_BOX = {
    backdrop = BACKDROP_FLAT_BUTTON,
    bgColor = { 0.06, 0.10, 0.18, 0.85 },
    borderColor = { 0.20, 0.50, 0.90, 0.60 },
  },
}

function UICommon.ApplyBackdrop(frame, presetName)
  if type(frame) ~= "table" or type(frame.SetBackdrop) ~= "function" then
    return false
  end
  local preset = UICommon.BACKDROP_PRESETS[presetName]
  if not preset then
    return false
  end
  frame:SetBackdrop(preset.backdrop)
  if preset.bgColor and type(frame.SetBackdropColor) == "function" then
    if type(preset.bgColor) == "function" then
      frame:SetBackdropColor(preset.bgColor())
    else
      local c = preset.bgColor
      frame:SetBackdropColor(c[1], c[2], c[3], c[4])
    end
  end
  if preset.borderColor and type(frame.SetBackdropBorderColor) == "function" then
    local bc = preset.borderColor
    frame:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4])
  end
  return true
end

local TOOLTIP_HORIZONTAL_PADDING = 10
local TOOLTIP_VERTICAL_PADDING = 10
local TOOLTIP_LINE_SPACING = 3
local TOOLTIP_MIN_HEIGHT = 28
local TOOLTIP_WIDTH = 200
local TOOLTIP_TEXT_WIDTH = TOOLTIP_WIDTH - (TOOLTIP_HORIZONTAL_PADDING * 2)

local function AcquireTooltipLine(tooltip, index)
  if type(tooltip) ~= "table" or type(index) ~= "number" or index < 1 then
    return nil
  end

  tooltip._isiLiveTooltipLines = tooltip._isiLiveTooltipLines or {}
  local line = tooltip._isiLiveTooltipLines[index]
  if line or type(tooltip.CreateFontString) ~= "function" then
    return line
  end

  line = tooltip:CreateFontString(nil, "OVERLAY", index == 1 and "GameTooltipHeaderText" or "GameTooltipText")
  if type(line.SetWidth) == "function" then
    line:SetWidth(TOOLTIP_TEXT_WIDTH)
  end
  if type(line.SetJustifyH) == "function" then
    line:SetJustifyH("LEFT")
  end
  if type(line.SetWordWrap) == "function" then
    line:SetWordWrap(true)
  end
  if type(line.SetNonSpaceWrap) == "function" then
    line:SetNonSpaceWrap(true)
  end
  if type(line.SetMaxLines) == "function" then
    line:SetMaxLines(0)
  end
  tooltip._isiLiveTooltipLines[index] = line
  return line
end

local function LayoutTooltipLines(tooltip)
  if type(tooltip) ~= "table" then
    return
  end

  local lines = tooltip._isiLiveTooltipLines or {}
  local lineCount = tonumber(tooltip._isiLiveTooltipLineCount) or 0
  local tooltipHeight = TOOLTIP_VERTICAL_PADDING
  local previousLine = nil
  for index, line in ipairs(lines) do
    local isActiveLine = index <= lineCount
    if type(line) == "table" and type(line.SetPoint) == "function" then
      if type(line.ClearAllPoints) == "function" then
        line:ClearAllPoints()
      end
      if previousLine == nil then
        line:SetPoint("TOPLEFT", tooltip, "TOPLEFT", TOOLTIP_HORIZONTAL_PADDING, -TOOLTIP_VERTICAL_PADDING)
      else
        line:SetPoint("TOPLEFT", previousLine, "BOTTOMLEFT", 0, -TOOLTIP_LINE_SPACING)
      end
    end
    if isActiveLine then
      local lineHeight = 16
      if type(line) == "table" and type(line.GetStringHeight) == "function" then
        local ok, measuredHeight = pcall(line.GetStringHeight, line)
        local measuredHeightValue = tonumber(measuredHeight)
        if ok and measuredHeightValue and measuredHeightValue > 0 then
          lineHeight = math.max(measuredHeightValue, 14)
        end
      end
      tooltipHeight = tooltipHeight + lineHeight
      if previousLine ~= nil then
        tooltipHeight = tooltipHeight + TOOLTIP_LINE_SPACING
      end
      previousLine = line
    end
  end
  tooltipHeight = tooltipHeight + TOOLTIP_VERTICAL_PADDING

  if type(tooltip.SetSize) == "function" then
    tooltip:SetSize(TOOLTIP_WIDTH, math.max(TOOLTIP_MIN_HEIGHT, tooltipHeight))
  elseif type(tooltip.SetWidth) == "function" and type(tooltip.SetHeight) == "function" then
    tooltip:SetWidth(TOOLTIP_WIDTH)
    tooltip:SetHeight(math.max(TOOLTIP_MIN_HEIGHT, tooltipHeight))
  elseif type(tooltip.SetHeight) == "function" then
    tooltip:SetHeight(math.max(TOOLTIP_MIN_HEIGHT, tooltipHeight))
  end
end

local function PositionPrivateTooltip(tooltip)
  if type(tooltip) ~= "table" then
    return
  end

  if type(tooltip.ClearAllPoints) == "function" then
    tooltip:ClearAllPoints()
  end

  local owner = tooltip._isiLiveTooltipOwner
  local anchor = tooltip._isiLiveTooltipAnchor or "ANCHOR_CURSOR"
  if type(tooltip.SetPoint) ~= "function" then
    return
  end

  if anchor == "ANCHOR_TOP" and owner then
    tooltip:SetPoint("BOTTOM", owner, "TOP", 0, 8)
    return
  end

  if anchor == "ANCHOR_CURSOR" and type(rawget(_G, "GetCursorPosition")) == "function" then
    local tooltipParent = rawget(_G, "UIParent") or owner
    local x, y = rawget(_G, "GetCursorPosition")()
    local scale = 1
    if type(tooltipParent) == "table" and type(tooltipParent.GetEffectiveScale) == "function" then
      local ok, tooltipScale = pcall(tooltipParent.GetEffectiveScale, tooltipParent)
      local tooltipScaleValue = tonumber(tooltipScale)
      if ok and tooltipScaleValue and tooltipScaleValue > 0 then
        scale = tooltipScaleValue
      end
    end

    if tooltipParent then
      tooltip:SetPoint("BOTTOMLEFT", tooltipParent, "BOTTOMLEFT", (x / scale) + 16, (y / scale) + 16)
      return
    end
  end

  if owner then
    tooltip:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
  end
end

local function ResolveSpellName(spellID)
  if type(rawget(_G, "GetSpellInfo")) == "function" then
    local ok, spellName = pcall(rawget(_G, "GetSpellInfo"), spellID)
    if ok and type(spellName) == "string" and spellName ~= "" then
      return spellName
    end
  end

  local spellAPI = rawget(_G, "C_Spell")
  local getSpellName = spellAPI and spellAPI.GetSpellName or nil
  if type(getSpellName) == "function" then
    local ok, spellName = pcall(getSpellName, spellID)
    if ok and type(spellName) == "string" and spellName ~= "" then
      return spellName
    end
  end

  return nil
end

local function EnsurePrivateTooltipAPI(tooltip)
  if type(tooltip) ~= "table" then
    return nil
  end
  if tooltip._isiLiveTooltipReady == true then
    return tooltip
  end

  tooltip._isiLiveTooltipReady = true
  tooltip._isIsiLiveTooltip = true
  tooltip._isiLiveTooltipNativeShow = tooltip.Show
  tooltip._isiLiveTooltipNativeHide = tooltip.Hide

  function tooltip:ClearLines()
    local lines = self._isiLiveTooltipLines or {}
    for _, line in ipairs(lines) do
      if type(line) == "table" and type(line.Hide) == "function" then
        line:Hide()
      end
    end
    self._isiLiveTooltipLineCount = 0
  end

  function tooltip:SetOwner(anchorFrame, anchor)
    self._isiLiveTooltipOwner = anchorFrame
    self._isiLiveTooltipAnchor = anchor
    PositionPrivateTooltip(self)
  end

  function tooltip:SetText(text, r, g, b)
    self:ClearLines()
    local line = AcquireTooltipLine(self, 1)
    if type(line) ~= "table" then
      return
    end
    if type(line.SetTextColor) == "function" then
      line:SetTextColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1)
    end
    UICommon.SetReadableText(line, text)
    if type(line.Show) == "function" then
      line:Show()
    end
    self._isiLiveTooltipLineCount = 1
    LayoutTooltipLines(self)
  end

  function tooltip:AddLine(text, r, g, b)
    local index = (tonumber(self._isiLiveTooltipLineCount) or 0) + 1
    local line = AcquireTooltipLine(self, index)
    if type(line) ~= "table" then
      return
    end
    if type(line.SetTextColor) == "function" then
      line:SetTextColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1)
    end
    UICommon.SetReadableText(line, text)
    if type(line.Show) == "function" then
      line:Show()
    end
    self._isiLiveTooltipLineCount = index
    LayoutTooltipLines(self)
  end

  function tooltip:SetSpellByID(spellID)
    local spellName = ResolveSpellName(spellID) or ("Spell " .. tostring(spellID or "?"))
    self:SetText(spellName, 1, 1, 1)
  end

  function tooltip:Show()
    self._isiLiveTooltipShown = true
    PositionPrivateTooltip(self)
    if type(self._isiLiveTooltipNativeShow) == "function" then
      pcall(self._isiLiveTooltipNativeShow, self)
    end
  end

  function tooltip:Hide()
    self._isiLiveTooltipShown = false
    self:ClearLines()
    if type(self._isiLiveTooltipNativeHide) == "function" then
      pcall(self._isiLiveTooltipNativeHide, self)
    end
  end

  return tooltip
end

local function ApplyCloseButtonBackdrop(button)
  UICommon.ApplyBackdrop(button, "CLOSE_BUTTON")
end

local CLOSE_TEXTURE_NORMAL = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up"
local CLOSE_TEXTURE_PRESSED = "Interface\\Buttons\\UI-Panel-MinimizeButton-Down"
local CLOSE_TEXTURE_HIGHLIGHT = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight"

local function SetTextureColor(texture, r, g, b, a)
  if type(texture) == "table" and type(texture.SetColorTexture) == "function" then
    texture:SetColorTexture(r, g, b, a)
  end
end

local function SetTexturePath(texture, path)
  if type(texture) == "table" and type(texture.SetTexture) == "function" then
    texture:SetTexture(path)
  end
end

local function AnchorTextureInset(texture, owner, inset)
  if type(texture) ~= "table" then
    return
  end
  if type(texture.ClearAllPoints) == "function" then
    texture:ClearAllPoints()
  end
  if type(texture.SetPoint) == "function" then
    texture:SetPoint("TOPLEFT", owner, "TOPLEFT", inset, -inset)
    texture:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -inset, inset)
  elseif type(texture.SetAllPoints) == "function" then
    texture:SetAllPoints(owner)
  end
end

local function CreateCloseButtonArt(button)
  if type(button.CreateTexture) ~= "function" then
    return nil
  end

  local glow = button:CreateTexture(nil, "BACKGROUND")
  if type(glow.SetAllPoints) == "function" then
    glow:SetAllPoints(button)
  end
  SetTextureColor(glow, 0.55, 0.03, 0.015, 0.42)

  local inner = button:CreateTexture(nil, "BORDER")
  AnchorTextureInset(inner, button, 2)
  SetTextureColor(inner, 0.18, 0.015, 0.012, 0.88)

  local icon = button:CreateTexture(nil, "ARTWORK")
  AnchorTextureInset(icon, button, 1)
  SetTexturePath(icon, CLOSE_TEXTURE_NORMAL)
  if type(icon.SetTexCoord) == "function" then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end

  local highlight = button:CreateTexture(nil, "HIGHLIGHT")
  AnchorTextureInset(highlight, button, 0)
  SetTexturePath(highlight, CLOSE_TEXTURE_HIGHLIGHT)
  if type(highlight.SetBlendMode) == "function" then
    highlight:SetBlendMode("ADD")
  end
  if type(highlight.SetAlpha) == "function" then
    highlight:SetAlpha(0.7)
  end

  local art = {
    glow = glow,
    inner = inner,
    icon = icon,
    highlight = highlight,
  }
  button._isiLiveCloseButtonArt = art
  return art
end

local function CreateCloseButtonLabel(button)
  if type(button.CreateFontString) ~= "function" then
    return nil
  end

  local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  label:SetPoint("CENTER", button, "CENTER", 0, -1)
  label:SetText("X")
  label:SetTextColor(1, 0.83, 0.35, 0.95)
  button._isiLiveCloseButtonLabel = label
  return label
end

local function AttachCloseButtonVisualStates(button, label, art, opts)
  if not label and not art then
    return
  end

  opts = opts or {}
  local titleText = UICommon.GetLocalizedText(opts.tooltipTitleKey, opts.tooltipTitle or "")
  local bodyText = UICommon.GetLocalizedText(opts.tooltipBodyKey, opts.tooltipBody or "")
  local anchor = type(opts.tooltipAnchor) == "string" and opts.tooltipAnchor or "ANCHOR_LEFT"

  button:SetScript("OnEnter", function()
    if label then
      label:SetTextColor(1, 0.92, 0.45, 1)
    end
    if art then
      SetTextureColor(art.glow, 0.95, 0.05, 0.025, 0.72)
      SetTextureColor(art.inner, 0.28, 0.02, 0.015, 0.95)
      SetTexturePath(art.icon, CLOSE_TEXTURE_NORMAL)
    end
    local tooltip = rawget(_G, "GameTooltip")
    if tooltip and type(tooltip.SetOwner) == "function" and (titleText ~= "" or bodyText ~= "") then
      tooltip:SetOwner(button, anchor)
      if titleText ~= "" then
        tooltip:AddLine(titleText)
      end
      if bodyText ~= "" then
        tooltip:AddLine(bodyText, 0.8, 0.8, 0.8)
      end
      tooltip:Show()
    end
  end)

  button:SetScript("OnLeave", function()
    if label then
      label:SetTextColor(1, 0.83, 0.35, 0.95)
    end
    if art then
      SetTextureColor(art.glow, 0.55, 0.03, 0.015, 0.42)
      SetTextureColor(art.inner, 0.18, 0.015, 0.012, 0.88)
      SetTexturePath(art.icon, CLOSE_TEXTURE_NORMAL)
    end
    local tooltip = rawget(_G, "GameTooltip")
    if tooltip and type(tooltip.Hide) == "function" then
      tooltip:Hide()
    end
  end)

  button:SetScript("OnMouseDown", function()
    if label then
      label:SetTextColor(1, 0.55, 0.2, 1)
    end
    if art then
      SetTextureColor(art.glow, 0.75, 0.025, 0.015, 0.48)
      SetTextureColor(art.inner, 0.11, 0.01, 0.008, 0.96)
      SetTexturePath(art.icon, CLOSE_TEXTURE_PRESSED)
    end
  end)

  button:SetScript("OnMouseUp", function()
    if label then
      label:SetTextColor(1, 0.92, 0.45, 1)
    end
    if art then
      SetTextureColor(art.glow, 0.95, 0.05, 0.025, 0.72)
      SetTextureColor(art.inner, 0.28, 0.02, 0.015, 0.95)
      SetTexturePath(art.icon, CLOSE_TEXTURE_NORMAL)
    end
  end)
end

function UICommon.CreateRedCloseButton(parent, opts)
  opts = opts or {}
  local button = CreateFrame("Button", opts.name, parent, "BackdropTemplate")
  local size = tonumber(opts.size) or 20
  button:SetSize(size, size)

  local point = opts.point
  if type(point) == "table" then
    button:SetPoint(point[1], point[2], point[3], point[4], point[5])
  else
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, -2)
  end

  local strata = opts.frameStrata or (parent and parent.GetFrameStrata and parent:GetFrameStrata()) or "MEDIUM"
  button:SetFrameStrata(strata)

  local level = tonumber(opts.frameLevel) or ((parent and parent.GetFrameLevel and parent:GetFrameLevel()) or 1) + 20
  button:SetFrameLevel(level)

  ApplyCloseButtonBackdrop(button)
  local art = CreateCloseButtonArt(button)
  local label = CreateCloseButtonLabel(button)
  if art and label then
    label:SetText("")
  end
  AttachCloseButtonVisualStates(button, label, art, {
    tooltipTitleKey = opts.tooltipTitleKey,
    tooltipTitle = opts.tooltipTitle,
    tooltipBodyKey = opts.tooltipBodyKey,
    tooltipBody = opts.tooltipBody,
    tooltipAnchor = opts.tooltipAnchor,
  })

  return button
end

function UICommon.CreatePrivateTooltip(parent)
  local tooltipParent = rawget(_G, "UIParent") or parent
  local tooltipFrame = CreateFrame("Frame", nil, tooltipParent, "BackdropTemplate")
  local tooltip = EnsurePrivateTooltipAPI(tooltipFrame)
  if type(tooltip) ~= "table" then
    return nil
  end

  if not UICommon.ApplyBackdrop(tooltip, "TOOLTIP") and type(tooltip.CreateTexture) == "function" then
    tooltip._isiLiveTooltipBackground = tooltip._isiLiveTooltipBackground or tooltip:CreateTexture(nil, "BACKGROUND")
    if type(tooltip._isiLiveTooltipBackground.SetAllPoints) == "function" then
      tooltip._isiLiveTooltipBackground:SetAllPoints()
    end
    if type(tooltip._isiLiveTooltipBackground.SetColorTexture) == "function" then
      tooltip._isiLiveTooltipBackground:SetColorTexture(0, 0, 0, 0.92)
    end
  end

  if type(tooltip.SetFrameStrata) == "function" then
    tooltip:SetFrameStrata("TOOLTIP")
  end
  if type(tooltip.SetClampedToScreen) == "function" then
    tooltip:SetClampedToScreen(true)
  end
  if type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end

  return tooltip
end

function UICommon.PreparePrivateTooltip(tooltip, anchorFrame, anchor)
  tooltip = EnsurePrivateTooltipAPI(tooltip)
  if type(tooltip) ~= "table" then
    return nil
  end

  if type(tooltip.ClearLines) == "function" then
    tooltip:ClearLines()
  end

  local resolvedAnchor = type(anchor) == "string" and anchor or "ANCHOR_CURSOR"
  if type(tooltip.SetOwner) == "function" then
    tooltip:SetOwner(anchorFrame, resolvedAnchor)
  end
  tooltip._isiLiveTooltipOwner = anchorFrame
  tooltip._isiLiveTooltipAnchor = resolvedAnchor

  return tooltip
end

function UICommon.HidePrivateTooltip(tooltip)
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end
