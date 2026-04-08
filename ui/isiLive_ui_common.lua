local _, addonTable = ...

addonTable = addonTable or {}

local UICommon = {}
addonTable.UICommon = UICommon

UICommon.DEFAULT_BG_ALPHA = 0.50

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

function UICommon.GetBackgroundAlpha()
  local db = rawget(_G, "IsiLiveDB")
  if type(db) == "table" and type(db.bgAlpha) == "number" then
    return db.bgAlpha
  end
  return UICommon.DEFAULT_BG_ALPHA
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
    bgColor = { 0, 0, 0, 0.85 },
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
        if ok and tonumber(measuredHeight) and tonumber(measuredHeight) > 0 then
          lineHeight = math.max(tonumber(measuredHeight), 14)
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
      if ok and tonumber(tooltipScale) and tonumber(tooltipScale) > 0 then
        scale = tonumber(tooltipScale)
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
    if type(line.SetText) == "function" then
      line:SetText(tostring(text or ""))
    end
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
    if type(line.SetText) == "function" then
      line:SetText(tostring(text or ""))
    end
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

local function CreateCloseButtonLabel(button)
  if type(button.CreateFontString) ~= "function" then
    return nil
  end

  local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  label:SetPoint("CENTER", button, "CENTER", 0, -1)
  label:SetText("X")
  label:SetTextColor(1, 0.2, 0.2, 1)
  return label
end

local function AttachCloseButtonVisualStates(button, label)
  if not label then
    return
  end

  button:SetScript("OnEnter", function()
    label:SetTextColor(1, 0.35, 0.35, 1)
  end)

  button:SetScript("OnLeave", function()
    label:SetTextColor(1, 0.2, 0.2, 1)
  end)

  button:SetScript("OnMouseDown", function()
    label:SetTextColor(0.9, 0.12, 0.12, 1)
  end)

  button:SetScript("OnMouseUp", function()
    label:SetTextColor(1, 0.35, 0.35, 1)
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
  local label = CreateCloseButtonLabel(button)
  AttachCloseButtonVisualStates(button, label)

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
