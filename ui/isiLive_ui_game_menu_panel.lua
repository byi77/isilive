local _, addonTable = ...

addonTable = addonTable or {}

local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

local Panel = {}
addonTable.UIGameMenuPanel = Panel

local UICommon = assert(addonTable.UICommon, "isiLive: UICommon missing")
local Colors = UICommon.Colors or {}
local ApplyBackdrop = assert(UICommon.ApplyBackdrop, "isiLive: UICommon.ApplyBackdrop missing")

local DEFAULT_BUTTON_WIDTH = 120
local DEFAULT_BUTTON_HEIGHT = 30
local BUTTON_GAP = 1
local SECTION_BREAK_GAP = 10
local OFFSET_X = -60
local OFFSET_Y = 0
local PADDING_X = 10
local PADDING_TOP = 10
local PADDING_BOTTOM = 10
local SECTION_HEADER_HEIGHT = 16
local SECTION_HEADER_GAP = 3
local ICON_SIZE = 18
local ICON_PADDING = 6

Panel.BUTTON_GAP = BUTTON_GAP
Panel.SECTION_BREAK_GAP = SECTION_BREAK_GAP

local BUTTON_SIZE_CANDIDATE_NAMES = {
  "GameMenuButtonContinue",
  "GameMenuButtonOptions",
  "GameMenuButtonMacros",
  "GameMenuButtonAddons",
  "GameMenuButtonLogout",
  "GameMenuButtonQuit",
}
local BUTTON_SIZE_CANDIDATE_FIELDS = {
  "ContinueButton",
  "OptionsButton",
  "MacrosButton",
  "AddOnsButton",
  "LogoutButton",
  "QuitButton",
}

local function ResolveFrameSize(frame)
  if type(frame) ~= "table" or type(frame.GetWidth) ~= "function" or type(frame.GetHeight) ~= "function" then
    return nil, nil
  end

  local width = tonumber(frame:GetWidth())
  local height = tonumber(frame:GetHeight())
  if width == nil or height == nil or width <= 0 or height <= 0 then
    return nil, nil
  end

  return width, height
end

function Panel.ResolveButtonSize(gameMenuFrame)
  for _, buttonName in ipairs(BUTTON_SIZE_CANDIDATE_NAMES) do
    local width, height = ResolveFrameSize(rawget(_G, buttonName))
    if width ~= nil and height ~= nil then
      return width, height
    end
  end

  if type(gameMenuFrame) == "table" then
    for _, fieldName in ipairs(BUTTON_SIZE_CANDIDATE_FIELDS) do
      local width, height = ResolveFrameSize(rawget(gameMenuFrame, fieldName))
      if width ~= nil and height ~= nil then
        return width, height
      end
    end
  end

  return DEFAULT_BUTTON_WIDTH, DEFAULT_BUTTON_HEIGHT
end

function Panel.CreateButton(
  parent,
  frameStrata,
  baseFrameLevel,
  frameLevelOffset,
  iconSpec,
  buttonTemplate,
  skipInitialClickRegistration
)
  local isAtlas = type(iconSpec) == "string" and not iconSpec:find("\\", 1, true)
  local button = CreateFrame("Button", nil, parent, buttonTemplate or "BackdropTemplate")
  ApplyBackdrop(button, "BUTTON_BG")
  if type(button.EnableMouse) == "function" then
    button:EnableMouse(true)
  end
  if not skipInitialClickRegistration and type(button.RegisterForClicks) == "function" then
    button:RegisterForClicks("LeftButtonUp")
  end
  if frameStrata ~= nil and type(button.SetFrameStrata) == "function" then
    button:SetFrameStrata(frameStrata)
  end
  if type(button.SetFrameLevel) == "function" then
    button:SetFrameLevel(baseFrameLevel + frameLevelOffset)
  end

  if iconSpec and type(button.CreateTexture) == "function" then
    local iconBorder = button:CreateTexture(nil, "ARTWORK", nil, -1)
    if type(iconBorder.SetSize) == "function" then
      iconBorder:SetSize(ICON_SIZE + 2, ICON_SIZE + 2)
    end
    if type(iconBorder.SetPoint) == "function" then
      iconBorder:SetPoint("LEFT", ICON_PADDING - 1, 0)
    end
    if type(iconBorder.SetColorTexture) == "function" then
      iconBorder:SetColorTexture(unpack(Colors.BLACK_OVERLAY_50 or { 0, 0, 0, 0.5 }))
    end
    local icon = button:CreateTexture(nil, "ARTWORK")
    if type(icon.SetSize) == "function" then
      icon:SetSize(ICON_SIZE, ICON_SIZE)
    end
    if type(icon.SetPoint) == "function" then
      icon:SetPoint("LEFT", ICON_PADDING, 0)
    end
    if isAtlas and type(icon.SetAtlas) == "function" then
      icon:SetAtlas(iconSpec)
    elseif type(icon.SetTexture) == "function" then
      if type(icon.SetTexCoord) == "function" then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      end
      icon:SetTexture(iconSpec)
    end
    button._panelIcon = icon
  end

  if type(button.CreateFontString) == "function" then
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local textOffsetX = iconSpec and ((ICON_PADDING * 2) + ICON_SIZE) or ICON_PADDING
    if type(label.SetPoint) == "function" then
      label:SetPoint("LEFT", textOffsetX, 0)
    end
    if type(label.SetJustifyH) == "function" then
      label:SetJustifyH("LEFT")
    end
    button._panelLabel = label
  end

  button._panelText = ""
  button.SetText = function(self, text)
    self._panelText = text or ""
    if self._panelLabel and type(self._panelLabel.SetText) == "function" then
      self._panelLabel:SetText(self._panelText)
    end
  end
  button.GetText = function(self)
    return self._panelText or ""
  end

  if type(button.CreateTexture) == "function" then
    local highlightColor = Colors.HOVER_HIGHLIGHT
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    if type(highlight.SetAllPoints) == "function" then
      highlight:SetAllPoints()
    end
    if type(highlight.SetColorTexture) == "function" then
      highlight:SetColorTexture(highlightColor[1], highlightColor[2], highlightColor[3], highlightColor[4])
    end
  end

  if type(button.SetScript) == "function" then
    button:SetScript("OnEnter", function(self)
      if type(self.SetBackdropColor) == "function" then
        self:SetBackdropColor(0.14, 0.14, 0.20, 0.7)
      end
    end)
    button:SetScript("OnLeave", function(self)
      if type(self.SetBackdropColor) == "function" then
        local backgroundColor = Colors.BG_SECONDARY
        self:SetBackdropColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])
      end
    end)
  end

  return button
end

function Panel.ApplyBackdrop(panelFrame)
  ApplyBackdrop(panelFrame, "PRIMARY")
end

function Panel.CreateHeaderChrome(state)
  local panelFrame = state and state.panelFrame or nil
  if type(panelFrame) ~= "table" then
    return
  end

  if type(panelFrame.CreateFontString) == "function" then
    state.shortcutsHeader = panelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if type(state.shortcutsHeader.SetTextColor) == "function" then
      local textDim = Colors.TEXT_DIM
      state.shortcutsHeader:SetTextColor(textDim[1], textDim[2], textDim[3], 1)
    end
    if type(state.shortcutsHeader.SetJustifyH) == "function" then
      state.shortcutsHeader:SetJustifyH("LEFT")
    end
  end

  if type(panelFrame.CreateTexture) == "function" then
    state.shortcutsHeaderLine = panelFrame:CreateTexture(nil, "ARTWORK")
    if type(state.shortcutsHeaderLine.SetHeight) == "function" then
      state.shortcutsHeaderLine:SetHeight(1)
    end
    if type(state.shortcutsHeaderLine.SetColorTexture) == "function" then
      local accentBlue = Colors.ACCENT_BLUE
      state.shortcutsHeaderLine:SetColorTexture(accentBlue[1], accentBlue[2], accentBlue[3], 0.3)
    end
  end
end

local function ResolvePanelCloseAnchor(gameMenuFrame)
  if type(gameMenuFrame) ~= "table" then
    return nil
  end

  local header = rawget(gameMenuFrame, "Header")
  if type(header) == "table" then
    local headerCloseButton = rawget(header, "CloseButton")
    if type(headerCloseButton) == "table" then
      return headerCloseButton
    end
  end

  local closeButton = rawget(gameMenuFrame, "CloseButton")
  if type(closeButton) == "table" then
    return closeButton
  end

  local globalCloseButton = rawget(_G, "GameMenuFrameCloseButton")
  if type(globalCloseButton) == "table" then
    return globalCloseButton
  end

  return nil
end

local function GetAvailableButtons(buttons, isButtonAvailable)
  local available = {}
  if type(buttons) ~= "table" then
    return available
  end
  for _, button in ipairs(buttons) do
    if isButtonAvailable(button) then
      available[#available + 1] = button
    end
  end
  return available
end

local function GetButtonStackHeight(buttons, buttonHeight, isButtonAvailable)
  local resolvedButtonCount = 0
  for _, button in ipairs(buttons or {}) do
    if isButtonAvailable(button) then
      resolvedButtonCount = resolvedButtonCount + 1
    end
  end
  if resolvedButtonCount == 0 then
    return 0
  end

  local totalHeight = resolvedButtonCount * buttonHeight
  local visibleIndex = 0
  for _, button in ipairs(buttons) do
    if isButtonAvailable(button) then
      visibleIndex = visibleIndex + 1
      if visibleIndex >= 2 then
        totalHeight = totalHeight + math.max(0, tonumber(button._gapBefore) or BUTTON_GAP)
      end
    end
  end
  return totalHeight
end

function Panel.PositionButtons(state, deps, opts)
  if type(state) ~= "table" or type(deps) ~= "table" then
    return
  end
  opts = opts or {}

  local gameMenuFrame = state.gameMenuFrame
  local panelFrame = state.panelFrame
  if type(gameMenuFrame) ~= "table" or type(panelFrame) ~= "table" then
    return
  end
  local buttonWidth, buttonHeight = Panel.ResolveButtonSize(gameMenuFrame)
  local buttons = state.buttons or {}
  local availableButtons = GetAvailableButtons(buttons, deps.isButtonAvailable)
  local hasShortcutsHeader = type(state.shortcutsHeader) == "table"
  local stackHeight = GetButtonStackHeight(availableButtons, buttonHeight, deps.isButtonAvailable)
  local hasAvailableButtons = #availableButtons > 0
  if hasShortcutsHeader then
    stackHeight = stackHeight + SECTION_HEADER_HEIGHT + SECTION_HEADER_GAP
  end
  local panelWidth = buttonWidth + (PADDING_X * 2)
  local panelHeight = stackHeight + PADDING_TOP + PADDING_BOTTOM
  state.buttonWidth = buttonWidth
  state.buttonHeight = buttonHeight
  state.panelWidth = panelWidth
  state.panelHeight = panelHeight
  local secureUpdatesBlocked = deps.isSecureUpdateBlocked(state)

  if secureUpdatesBlocked then
    deps.queueSecureStateRefresh(state)
    return
  end

  state.anchor = ResolvePanelCloseAnchor(gameMenuFrame)
  local anchorFrame = state.positionAnchorFrame or gameMenuFrame
  local anchorOffsetX = type(state.positionOffsetX) == "number" and state.positionOffsetX or OFFSET_X
  local anchorOffsetY = type(state.positionOffsetY) == "number" and state.positionOffsetY or OFFSET_Y
  local point = type(state.positionPoint) == "string" and state.positionPoint or "TOPRIGHT"
  local relativePoint = type(state.positionRelativePoint) == "string" and state.positionRelativePoint or "TOPLEFT"
  if type(panelFrame.ClearAllPoints) == "function" then
    panelFrame:ClearAllPoints()
  end
  if type(panelFrame.SetPoint) == "function" then
    panelFrame:SetPoint(point, anchorFrame, relativePoint, anchorOffsetX, anchorOffsetY)
  end
  if type(panelFrame.SetSize) == "function" then
    panelFrame:SetSize(panelWidth, panelHeight)
  end
  if deps.isEnabled(state) and hasAvailableButtons then
    if type(panelFrame.Show) == "function" then
      panelFrame:Show()
    end
  elseif type(panelFrame.Hide) == "function" then
    panelFrame:Hide()
  end

  local locale = type(state.getL) == "function" and state.getL() or {}
  if hasShortcutsHeader then
    local header = state.shortcutsHeader
    if type(header.ClearAllPoints) == "function" then
      header:ClearAllPoints()
    end
    if type(header.SetPoint) == "function" then
      header:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", PADDING_X, -PADDING_TOP)
    end
    if type(header.SetText) == "function" then
      local headerLKey = type(state.headerLKey) == "string" and state.headerLKey or "PANEL_HEADER_SHORTCUTS"
      local headerText = type(locale[headerLKey]) == "string" and locale[headerLKey] or "Shortcuts"
      header:SetText(headerText)
    end
    if type(header.Show) == "function" then
      header:Show()
    end
  end

  if type(state.shortcutsHeaderLine) == "table" then
    local line = state.shortcutsHeaderLine
    if type(line.ClearAllPoints) == "function" then
      line:ClearAllPoints()
    end
    if type(line.SetPoint) == "function" then
      line:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", PADDING_X, -(PADDING_TOP + SECTION_HEADER_HEIGHT))
      line:SetPoint("TOPRIGHT", panelFrame, "TOPRIGHT", -PADDING_X, -(PADDING_TOP + SECTION_HEADER_HEIGHT))
    end
    if type(line.Show) == "function" then
      line:Show()
    end
  end

  local firstButtonTopOffset = -(
    PADDING_TOP + (hasShortcutsHeader and (SECTION_HEADER_HEIGHT + SECTION_HEADER_GAP) or 0)
  )
  local needsSecureRetry = false
  local previousButton = nil
  for _, button in ipairs(buttons) do
    local buttonAvailable = deps.isButtonAvailable(button)
    local skipProtectedLayout = secureUpdatesBlocked
      and opts.allowSecureButtonMutations ~= true
      and button._isSecurePanelAction == true
    if not buttonAvailable then
      if type(button.Hide) == "function" then
        button:Hide()
      end
    elseif skipProtectedLayout then
      needsSecureRetry = true
    else
      if type(button.SetSize) == "function" then
        button:SetSize(buttonWidth, buttonHeight)
      end
      if type(button.ClearAllPoints) == "function" then
        button:ClearAllPoints()
      end
      if previousButton ~= nil then
        local gapBefore = math.max(0, tonumber(button._gapBefore) or BUTTON_GAP)
        button:SetPoint("TOP", previousButton, "BOTTOM", 0, -gapBefore)
      else
        button:SetPoint("TOP", panelFrame, "TOP", 0, firstButtonTopOffset)
      end
    end
    if buttonAvailable then
      previousButton = button
    end
  end

  if needsSecureRetry then
    deps.queueSecureStateRefresh(state)
  else
    deps.clearQueuedState(state)
  end
end
