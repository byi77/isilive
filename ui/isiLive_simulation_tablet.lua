local _, addonTable = ...
addonTable = addonTable or {}

local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

local SimulationTablet = {}
addonTable.SimulationTablet = SimulationTablet

local UICommon = addonTable.UICommon or {}
local ApplyBackdrop = UICommon.ApplyBackdrop
local CreateCloseButton = UICommon.CreateCloseButton
local CreatePrivateTooltip = UICommon.CreatePrivateTooltip
local PreparePrivateTooltip = UICommon.PreparePrivateTooltip
local HidePrivateTooltip = UICommon.HidePrivateTooltip
local SetReadableText = UICommon.SetReadableText

local FRAME_WIDTH = 420
local FRAME_MIN_HEIGHT = 326
local FRAME_PADDING = 14
local DOCK_GAP = 12
local HEADER_HEIGHT = 48
local PRIMARY_HEIGHT = 30
local TAB_HEIGHT = 22
local ACTION_HEIGHT = 24
local ACTION_GAP = 4
local COLUMN_GAP = 8
local RESET_HEIGHT = 26
local FOOTER_HEIGHT = 38
local CONTENT_TOP = HEADER_HEIGHT + PRIMARY_HEIGHT + TAB_HEIGHT + 28
local CATEGORY_ORDER = { "group", "mplus", "alerts", "extras", "general" }

local STATUS_COLORS = {
  green = { 0.12, 0.86, 0.28, 1 },
  yellow = { 1.00, 0.76, 0.16, 1 },
  red = { 1.00, 0.18, 0.18, 1 },
}

local function ResolveL(opts)
  local getL = opts and opts.getL
  if type(getL) == "function" then
    return getL() or {}
  end
  return {}
end

local function SetText(fontString, text)
  if type(SetReadableText) == "function" then
    SetReadableText(fontString, text or "")
  elseif fontString and type(fontString.SetText) == "function" then
    fontString:SetText(text or "")
  end
end

local function ResolveActionText(L, action, field, fallback)
  local key = action and action[field .. "Key"]
  if type(key) == "string" and type(L[key]) == "string" and L[key] ~= "" then
    return L[key]
  end
  return fallback or ""
end

local function ResolveStatusText(L, status)
  if status == "green" then
    return L.SIM_STATUS_GREEN or "Green: deterministic preview"
  end
  if status == "yellow" then
    return L.SIM_STATUS_YELLOW or "Yellow: synthetic preview"
  end
  if status == "red" then
    return L.SIM_STATUS_RED or "Red: blocked by active rule"
  end
  return L.SIM_STATUS_UNKNOWN or "Unknown status"
end

local function ResolveStatusBadge(L, status)
  if status == "green" then
    return L.SIM_BADGE_READY or "READY"
  end
  if status == "yellow" then
    return L.SIM_BADGE_LOCAL or "LOCAL"
  end
  if status == "red" then
    return L.SIM_BADGE_BLOCKED or "BLOCKED"
  end
  return L.SIM_BADGE_UNKNOWN or "?"
end

local function ResolveCategoryText(L, category)
  local keyByCategory = {
    group = "SIM_CATEGORY_GROUP",
    mplus = "SIM_CATEGORY_MPLUS",
    alerts = "SIM_CATEGORY_ALERTS",
    extras = "SIM_CATEGORY_EXTRAS",
    general = "SIM_CATEGORY_GENERAL",
  }
  local fallbackByCategory = {
    group = "Group",
    mplus = "M+",
    alerts = "Alerts",
    extras = "Extras",
    general = "Actions",
  }
  local key = keyByCategory[category]
  return (key and L[key]) or fallbackByCategory[category] or category
end

local function ApplyButtonStatus(button, status, L)
  local color = STATUS_COLORS[status] or STATUS_COLORS.yellow
  if button.statusBar and type(button.statusBar.SetColorTexture) == "function" then
    button.statusBar:SetColorTexture(color[1], color[2], color[3], color[4])
  end
  SetText(button.statusLabel, ResolveStatusBadge(L, status))
  if button.statusLabel and type(button.statusLabel.SetTextColor) == "function" then
    button.statusLabel:SetTextColor(color[1], color[2], color[3])
  end
end

local function ShowTooltip(opts, tooltipFrame, owner, action)
  if not action then
    return
  end
  local L = ResolveL(opts)
  local tooltip = nil
  if type(PreparePrivateTooltip) == "function" and type(tooltipFrame) == "table" then
    tooltip = PreparePrivateTooltip(tooltipFrame, owner, "ANCHOR_CURSOR")
  end
  tooltip = tooltip or rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" then
    return
  end
  if type(tooltip.SetOwner) == "function" then
    tooltip:SetOwner(owner, "ANCHOR_RIGHT")
  end
  local title = ResolveActionText(L, action, "title", action.title or action.id)
  local desc = ResolveActionText(L, action, "desc", action.description)
  local statusText = ResolveStatusText(L, action.status)
  if type(tooltip.AddLine) == "function" then
    tooltip:AddLine(title, 1, 0.92, 0.55, true)
    tooltip:AddLine(desc, 0.92, 0.92, 0.92, true)
    tooltip:AddLine(statusText, 0.78, 0.78, 0.78, true)
  end
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
end

local function HideTooltip(tooltipFrame)
  if type(HidePrivateTooltip) == "function" and type(tooltipFrame) == "table" then
    HidePrivateTooltip(tooltipFrame)
    return
  end
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end

local function CreateActionButton(parent, opts)
  local createFrame = opts.CreateFrame or rawget(_G, "CreateFrame")
  local button = createFrame("Button", nil, parent, "BackdropTemplate")
  if type(ApplyBackdrop) == "function" then
    ApplyBackdrop(button, "BUTTON_BG")
  elseif type(button.SetBackdrop) == "function" then
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    button:SetBackdropColor(0.03, 0.05, 0.08, 0.86)
  end

  button.statusBar = button:CreateTexture(nil, "OVERLAY")
  button.statusBar:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  button.statusBar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
  button.statusBar:SetSize(3, ACTION_HEIGHT)

  button.codeLabel = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  button.codeLabel:SetPoint("LEFT", button, "LEFT", 9, 0)
  button.codeLabel:SetJustifyH("LEFT")
  if type(button.codeLabel.SetTextColor) == "function" then
    button.codeLabel:SetTextColor(
      unpack((UICommon.Colors and UICommon.Colors.BLUE_VERSION_TEXT) or { 0.55, 0.75, 1.0 })
    )
  end

  button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  button.label:SetPoint("LEFT", button, "LEFT", 36, 0)
  button.label:SetPoint("RIGHT", button, "RIGHT", -46, 0)
  button.label:SetJustifyH("LEFT")

  button.statusLabel = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  button.statusLabel:SetPoint("RIGHT", button, "RIGHT", -7, 0)
  button.statusLabel:SetJustifyH("RIGHT")

  button:SetScript("OnEnter", function(self)
    if type(self.SetBackdropColor) == "function" then
      self:SetBackdropColor(0.08, 0.16, 0.24, 0.94)
    end
    ShowTooltip(opts, opts.tooltipFrame, self, self._isiLiveAction)
  end)
  button:SetScript("OnLeave", function(self)
    if type(self.SetBackdropColor) == "function" then
      local action = self._isiLiveAction or {}
      if action.kind == "primary" then
        self:SetBackdropColor(0.04, 0.18, 0.32, 0.92)
      elseif action.kind == "reset" then
        self:SetBackdropColor(0.10, 0.10, 0.14, 0.90)
      else
        self:SetBackdropColor(0.03, 0.05, 0.08, 0.86)
      end
    end
    HideTooltip(opts.tooltipFrame)
  end)
  return button
end

local function SafeRegionNumber(region, methodName)
  local method = region and region[methodName]
  if type(method) ~= "function" then
    return nil
  end
  local ok, value = pcall(method, region)
  if not ok or type(value) ~= "number" then
    return nil
  end
  return value
end

local function GetEffectiveScale(region)
  return SafeRegionNumber(region, "GetEffectiveScale") or 1
end

local function GetPhysicalBounds(region)
  local left = SafeRegionNumber(region, "GetLeft")
  local right = SafeRegionNumber(region, "GetRight")
  local top = SafeRegionNumber(region, "GetTop")
  local bottom = SafeRegionNumber(region, "GetBottom")
  if not (left and right and top and bottom) then
    return nil
  end
  local scale = GetEffectiveScale(region)
  return {
    left = left * scale,
    right = right * scale,
    top = top * scale,
    bottom = bottom * scale,
    scale = scale,
  }
end

local function ResolveDockSide(frame, anchorFrame, screenParent)
  local anchorBounds = GetPhysicalBounds(anchorFrame)
  local screenBounds = GetPhysicalBounds(screenParent)
  if not (anchorBounds and screenBounds) then
    return "right"
  end

  local frameScale = GetEffectiveScale(frame)
  local width = (SafeRegionNumber(frame, "GetWidth") or FRAME_WIDTH) * frameScale
  local height = (SafeRegionNumber(frame, "GetHeight") or FRAME_MIN_HEIGHT) * frameScale
  local gap = DOCK_GAP * anchorBounds.scale
  local rightSpace = screenBounds.right - anchorBounds.right
  local leftSpace = anchorBounds.left - screenBounds.left
  local belowSpace = anchorBounds.bottom - screenBounds.bottom
  local aboveSpace = screenBounds.top - anchorBounds.top

  if rightSpace >= width + gap then
    return "right"
  end
  if leftSpace >= width + gap then
    return "left"
  end
  if belowSpace >= height + gap then
    return "below"
  end
  if aboveSpace >= height + gap then
    return "above"
  end
  return "right"
end

local function ResolveDockOffsets(frame, anchorFrame, screenParent, side)
  local anchorBounds = GetPhysicalBounds(anchorFrame)
  local screenBounds = GetPhysicalBounds(screenParent)
  if not (anchorBounds and screenBounds) then
    return 0, 0
  end

  local frameScale = GetEffectiveScale(frame)
  local width = (SafeRegionNumber(frame, "GetWidth") or FRAME_WIDTH) * frameScale
  local height = (SafeRegionNumber(frame, "GetHeight") or FRAME_MIN_HEIGHT) * frameScale
  local xOffset = 0
  local yOffset = 0

  if side == "right" or side == "left" then
    local desiredTop = anchorBounds.top
    local minimumTop = screenBounds.bottom + height
    local maximumTop = screenBounds.top
    local fittedTop = height <= (screenBounds.top - screenBounds.bottom)
        and math.max(minimumTop, math.min(maximumTop, desiredTop))
      or maximumTop
    yOffset = (fittedTop - desiredTop) / anchorBounds.scale
  else
    local desiredLeft = anchorBounds.left
    local minimumLeft = screenBounds.left
    local maximumLeft = screenBounds.right - width
    local fittedLeft = width <= (screenBounds.right - screenBounds.left)
        and math.max(minimumLeft, math.min(maximumLeft, desiredLeft))
      or minimumLeft
    xOffset = (fittedLeft - desiredLeft) / anchorBounds.scale
  end

  return xOffset, yOffset
end

local function AnchorDockedFrame(frame, anchorFrame, screenParent)
  if not (frame and type(frame.SetPoint) == "function") then
    return nil
  end
  if type(frame.ClearAllPoints) == "function" then
    frame:ClearAllPoints()
  end
  if type(anchorFrame) ~= "table" then
    frame:SetPoint("CENTER", screenParent, "CENTER", 0, 30)
    return "center"
  end

  local side = ResolveDockSide(frame, anchorFrame, screenParent)
  local xOffset, yOffset = ResolveDockOffsets(frame, anchorFrame, screenParent, side)
  if side == "left" then
    frame:SetPoint("TOPRIGHT", anchorFrame, "TOPLEFT", -DOCK_GAP, yOffset)
  elseif side == "below" then
    frame:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", xOffset, -DOCK_GAP)
  elseif side == "above" then
    frame:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", xOffset, DOCK_GAP)
  else
    frame:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", DOCK_GAP, yOffset)
  end
  return side
end

function SimulationTablet.CreateController(opts)
  opts = opts or {}
  local parent = opts.parent or rawget(_G, "UIParent")
  local anchorFrame = opts.anchorFrame
  local createFrame = opts.CreateFrame or rawget(_G, "CreateFrame")
  if type(parent) ~= "table" or type(createFrame) ~= "function" then
    return nil
  end

  local frame = createFrame("Frame", "isiLiveSimulationTablet", parent, "BackdropTemplate")
  frame:SetSize(FRAME_WIDTH, FRAME_MIN_HEIGHT)
  frame:SetPoint("CENTER", parent, "CENTER", 0, 30)
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  if type(frame.SetClampedToScreen) == "function" then
    frame:SetClampedToScreen(true)
  end
  if type(frame.SetClampRectInsets) == "function" then
    frame:SetClampRectInsets(0, 0, 0, 0)
  end
  if type(ApplyBackdrop) == "function" then
    ApplyBackdrop(frame, "PANEL")
  elseif type(frame.SetBackdrop) == "function" then
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    frame:SetBackdropColor(0.02, 0.02, 0.02, 0.94)
  end

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", FRAME_PADDING, -9)
  title:SetJustifyH("LEFT")

  local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", frame, "TOPLEFT", FRAME_PADDING, -29)
  subtitle:SetPoint("RIGHT", frame, "RIGHT", -100, 0)
  subtitle:SetJustifyH("LEFT")
  if type(subtitle.SetTextColor) == "function" then
    subtitle:SetTextColor(unpack((UICommon.Colors and UICommon.Colors.BLUE_VERSION_TEXT) or { 0.55, 0.75, 1.0 }))
  end

  local tooltipFrame = type(CreatePrivateTooltip) == "function" and CreatePrivateTooltip(frame) or nil
  opts.tooltipFrame = tooltipFrame

  local controller = {
    frame = frame,
    tooltipFrame = tooltipFrame,
    buttons = {},
    tabButtons = {},
    actions = {},
    activeCategory = "mplus",
    isDocked = true,
  }

  local function RefreshDockIfVisible()
    if
      controller.isDocked
      and type(frame.IsShown) == "function"
      and frame:IsShown()
      and type(controller.Dock) == "function"
    then
      controller.Dock()
    end
  end

  if type(anchorFrame) == "table" and type(anchorFrame.HookScript) == "function" then
    anchorFrame:HookScript("OnSizeChanged", RefreshDockIfVisible)
    anchorFrame:HookScript("OnDragStop", RefreshDockIfVisible)
  end
  if parent ~= anchorFrame and type(parent.HookScript) == "function" then
    parent:HookScript("OnSizeChanged", RefreshDockIfVisible)
  end

  frame:SetScript("OnDragStart", function(self)
    controller.isDocked = false
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if type(self.SetClampedToScreen) == "function" then
      self:SetClampedToScreen(true)
    end
  end)

  local closeButton = nil
  if type(CreateCloseButton) == "function" then
    closeButton = CreateCloseButton(frame, {
      point = { "TOPRIGHT", frame, "TOPRIGHT", -8, -8 },
      tooltipTitleKey = "SIM_CLOSE_TOOLTIP_TITLE",
      tooltipBodyKey = "SIM_CLOSE_TOOLTIP_BODY",
    })
    closeButton:SetScript("OnClick", function()
      controller.Hide()
      if type(opts.onClose) == "function" then
        opts.onClose()
      end
    end)
  end

  local dockButton = createFrame("Button", nil, frame, "BackdropTemplate")
  dockButton:SetSize(50, 20)
  dockButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", closeButton and -36 or -8, -7)
  if type(ApplyBackdrop) == "function" then
    ApplyBackdrop(dockButton, "BUTTON_BG")
  end
  dockButton.label = dockButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  dockButton.label:SetPoint("CENTER", dockButton, "CENTER", 0, 0)
  dockButton:SetScript("OnClick", function()
    controller.Dock()
  end)
  controller.dockButton = dockButton

  local primaryButton = CreateActionButton(frame, opts)
  primaryButton:SetPoint("TOPLEFT", frame, "TOPLEFT", FRAME_PADDING, -HEADER_HEIGHT)
  primaryButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -FRAME_PADDING, -HEADER_HEIGHT)
  primaryButton:SetSize(FRAME_WIDTH - (FRAME_PADDING * 2), PRIMARY_HEIGHT)
  controller.primaryButton = primaryButton

  local resetButton = CreateActionButton(frame, opts)
  controller.resetButton = resetButton

  local statusLine = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", FRAME_PADDING, 10)
  statusLine:SetPoint("RIGHT", frame, "RIGHT", -FRAME_PADDING, 0)
  statusLine:SetJustifyH("LEFT")
  controller.statusLine = statusLine

  local function RunAction(button)
    local currentAction = button and button._isiLiveAction
    local L = ResolveL(opts)
    if type(currentAction) ~= "table" or type(currentAction.run) ~= "function" then
      SetText(statusLine, L.SIM_ACTION_BLOCKED or "Blocked by active rule.")
      return
    end
    local ok, message = pcall(currentAction.run)
    if ok then
      SetText(statusLine, message or ResolveActionText(L, currentAction, "title", currentAction.title))
    else
      SetText(statusLine, L.SIM_ACTION_FAILED or "Simulation failed.")
    end
  end

  local function ConfigureButton(button, action, width, height)
    local L = ResolveL(opts)
    button:SetSize(width, height)
    button._isiLiveAction = action
    SetText(button.codeLabel, action.id or "")
    SetText(button.label, ResolveActionText(L, action, "title", action.title or action.id))
    ApplyButtonStatus(button, action.status, L)
    if type(button.SetBackdropColor) == "function" then
      if action.kind == "primary" then
        button:SetBackdropColor(0.04, 0.18, 0.32, 0.92)
      elseif action.kind == "reset" then
        button:SetBackdropColor(0.10, 0.10, 0.14, 0.90)
      else
        button:SetBackdropColor(0.03, 0.05, 0.08, 0.86)
      end
    end
    if type(button.SetAlpha) == "function" then
      button:SetAlpha(type(action.run) == "function" and 1 or 0.55)
    end
    button:SetScript("OnClick", function(self)
      RunAction(self)
    end)
    button:Show()
  end

  local function CollectLayoutActions(actions)
    local primary = nil
    local reset = nil
    local categories = {}
    local categorySeen = {}
    for _, action in ipairs(actions) do
      if action.kind == "primary" and not primary then
        primary = action
      elseif action.kind == "reset" and not reset then
        reset = action
      else
        local category = type(action.category) == "string" and action.category or "general"
        categories[category] = categories[category] or {}
        table.insert(categories[category], action)
        categorySeen[category] = true
      end
    end
    local orderedCategories = {}
    for _, category in ipairs(CATEGORY_ORDER) do
      if categorySeen[category] then
        table.insert(orderedCategories, category)
        categorySeen[category] = nil
      end
    end
    for category in pairs(categorySeen) do
      table.insert(orderedCategories, category)
    end
    return primary, reset, categories, orderedCategories
  end

  local function Refresh()
    local L = ResolveL(opts)
    SetText(title, L.SIM_TABLET_TITLE or "Demo simulator")
    SetText(subtitle, L.SIM_TABLET_SUBTITLE or "Local sandbox - no chat or group actions")
    SetText(dockButton.label, L.SIM_DOCK or "Dock")

    local actions = type(opts.getActions) == "function" and opts.getActions() or controller.actions
    if type(actions) ~= "table" then
      actions = {}
    end
    controller.actions = actions
    local primary, reset, categories, orderedCategories = CollectLayoutActions(actions)
    if #orderedCategories > 0 and not categories[controller.activeCategory] then
      controller.activeCategory = categories.mplus and "mplus" or orderedCategories[1]
    end

    if primary then
      ConfigureButton(primaryButton, primary, FRAME_WIDTH - (FRAME_PADDING * 2), PRIMARY_HEIGHT)
    else
      primaryButton:Hide()
      primaryButton._isiLiveAction = nil
    end

    local tabCount = #orderedCategories
    local tabAvailableWidth = FRAME_WIDTH - (FRAME_PADDING * 2) - math.max(0, tabCount - 1) * 4
    local tabWidth = tabCount > 0 and math.floor(tabAvailableWidth / tabCount) or tabAvailableWidth
    for index, category in ipairs(orderedCategories) do
      local tab = controller.tabButtons[index]
      if not tab then
        tab = createFrame("Button", nil, frame, "BackdropTemplate")
        if type(ApplyBackdrop) == "function" then
          ApplyBackdrop(tab, "BUTTON_BG")
        end
        tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tab.label:SetPoint("CENTER", tab, "CENTER", 0, 0)
        controller.tabButtons[index] = tab
      end
      if type(tab.ClearAllPoints) == "function" then
        tab:ClearAllPoints()
      end
      tab:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        FRAME_PADDING + ((index - 1) * (tabWidth + 4)),
        -(HEADER_HEIGHT + PRIMARY_HEIGHT + 8)
      )
      tab:SetSize(tabWidth, TAB_HEIGHT)
      tab._isiLiveCategory = category
      SetText(tab.label, ResolveCategoryText(L, category))
      if type(tab.SetAlpha) == "function" then
        tab:SetAlpha(category == controller.activeCategory and 1 or 0.58)
      end
      tab:SetScript("OnClick", function(self)
        controller.activeCategory = self._isiLiveCategory
        Refresh()
      end)
      tab:Show()
    end
    for index = tabCount + 1, #controller.tabButtons do
      controller.tabButtons[index]:Hide()
    end

    local visibleActions = categories[controller.activeCategory] or {}
    local columnWidth = math.floor((FRAME_WIDTH - (FRAME_PADDING * 2) - COLUMN_GAP) / 2)
    for index, action in ipairs(visibleActions) do
      local button = controller.buttons[index]
      if not button then
        button = CreateActionButton(frame, opts)
        controller.buttons[index] = button
      end
      if type(button.ClearAllPoints) == "function" then
        button:ClearAllPoints()
      end
      local row = math.floor((index - 1) / 2)
      local column = (index - 1) % 2
      button:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        FRAME_PADDING + (column * (columnWidth + COLUMN_GAP)),
        -(CONTENT_TOP + (row * (ACTION_HEIGHT + ACTION_GAP)))
      )
      ConfigureButton(button, action, columnWidth, ACTION_HEIGHT)
    end
    for index = #visibleActions + 1, #controller.buttons do
      controller.buttons[index]:Hide()
      controller.buttons[index]._isiLiveAction = nil
    end

    local rowCount = math.max(1, math.ceil(#visibleActions / 2))
    local contentBottom = CONTENT_TOP + (rowCount * ACTION_HEIGHT) + ((rowCount - 1) * ACTION_GAP)
    local minimumResetTop = FRAME_MIN_HEIGHT - FOOTER_HEIGHT - RESET_HEIGHT
    local resetTop = math.max(contentBottom + 10, minimumResetTop)
    if reset then
      if type(resetButton.ClearAllPoints) == "function" then
        resetButton:ClearAllPoints()
      end
      resetButton:SetPoint("TOPLEFT", frame, "TOPLEFT", FRAME_PADDING, -resetTop)
      ConfigureButton(resetButton, reset, FRAME_WIDTH - (FRAME_PADDING * 2), RESET_HEIGHT)
    else
      resetButton:Hide()
      resetButton._isiLiveAction = nil
    end

    local desiredHeight = math.max(FRAME_MIN_HEIGHT, resetTop + (reset and RESET_HEIGHT or 0) + FOOTER_HEIGHT)
    frame:SetSize(FRAME_WIDTH, desiredHeight)
    if type(frame.SetClampedToScreen) == "function" then
      frame:SetClampedToScreen(true)
    end
    if controller.isDocked then
      controller.Dock()
    end
  end

  function controller.SetActions(actions)
    controller.actions = type(actions) == "table" and actions or {}
    Refresh()
  end

  function controller.Refresh()
    Refresh()
  end

  function controller.Dock()
    controller.isDocked = true
    controller.dockSide = AnchorDockedFrame(frame, anchorFrame, parent)
    if type(frame.SetClampedToScreen) == "function" then
      frame:SetClampedToScreen(true)
    end
    return controller.dockSide
  end

  function controller.RefreshDock()
    RefreshDockIfVisible()
    return controller.dockSide
  end

  function controller.Show()
    Refresh()
    frame:Show()
  end

  function controller.Hide()
    frame:Hide()
  end

  function controller.Toggle()
    if frame:IsShown() then
      controller.Hide()
    else
      controller.Show()
    end
  end

  function controller.IsShown()
    return frame:IsShown()
  end

  frame:Hide()
  Refresh()
  return controller
end

return SimulationTablet
