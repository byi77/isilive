local _, addonTable = ...
addonTable = addonTable or {}

local SimulationTablet = {}
addonTable.SimulationTablet = SimulationTablet

local UICommon = addonTable.UICommon or {}
local ApplyBackdrop = UICommon.ApplyBackdrop
local CreateRedCloseButton = UICommon.CreateRedCloseButton
local PreparePrivateTooltip = UICommon.PreparePrivateTooltip
local HidePrivateTooltip = UICommon.HidePrivateTooltip

local FRAME_WIDTH = 438
local FRAME_HEIGHT = 360
local HEADER_HEIGHT = 32
local BUTTON_SIZE = 42
local BUTTON_GAP = 8
local COLUMNS = 7
local STATUS_SIZE = 8

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
  if fontString and type(fontString.SetText) == "function" then
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
    return L.SIM_STATUS_RED or "Red: blocked by rule"
  end
  return L.SIM_STATUS_UNKNOWN or "Unknown status"
end

local function ApplyButtonStatus(button, status)
  local color = STATUS_COLORS[status] or STATUS_COLORS.yellow
  if button.statusDot and type(button.statusDot.SetColorTexture) == "function" then
    button.statusDot:SetColorTexture(color[1], color[2], color[3], color[4])
  end
end

local function ShowTooltip(opts, owner, action)
  if not action then
    return
  end
  local L = ResolveL(opts)
  local tooltip = type(PreparePrivateTooltip) == "function" and PreparePrivateTooltip(owner)
    or rawget(_G, "GameTooltip")
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

local function HideTooltip()
  if type(HidePrivateTooltip) == "function" then
    HidePrivateTooltip()
    return
  end
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end

local function CreateButton(parent, opts, index)
  local createFrame = opts.CreateFrame or rawget(_G, "CreateFrame")
  local button = createFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
  if type(ApplyBackdrop) == "function" then
    ApplyBackdrop(button, "BUTTON_BG")
  elseif type(button.SetBackdrop) == "function" then
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    button:SetBackdropColor(0, 0, 0, 0.55)
  end

  local row = math.floor((index - 1) / COLUMNS)
  local column = (index - 1) % COLUMNS
  button:SetPoint(
    "TOPLEFT",
    parent,
    "TOPLEFT",
    18 + (column * (BUTTON_SIZE + BUTTON_GAP)),
    -(HEADER_HEIGHT + 46 + (row * (BUTTON_SIZE + BUTTON_GAP)))
  )

  button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.label:SetJustifyH("CENTER")
  button.label:SetText("")

  button.statusDot = button:CreateTexture(nil, "OVERLAY")
  button.statusDot:SetSize(STATUS_SIZE, STATUS_SIZE)
  button.statusDot:SetPoint("TOPRIGHT", button, "TOPRIGHT", -4, -4)
  ApplyButtonStatus(button, "yellow")
  return button
end

function SimulationTablet.CreateController(opts)
  opts = opts or {}
  local parent = opts.parent or rawget(_G, "UIParent")
  local createFrame = opts.CreateFrame or rawget(_G, "CreateFrame")
  if type(parent) ~= "table" or type(createFrame) ~= "function" then
    return nil
  end

  local frame = createFrame("Frame", "isiLiveSimulationTablet", parent, "BackdropTemplate")
  frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
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
    frame:SetBackdropColor(0.02, 0.02, 0.02, 0.92)
  end

  frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
  end)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -10)
  title:SetJustifyH("LEFT")

  local statusLine = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -34)
  statusLine:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
  statusLine:SetJustifyH("LEFT")

  local controller = {
    frame = frame,
    buttons = {},
    actions = {},
  }

  if type(CreateRedCloseButton) == "function" then
    local closeButton = CreateRedCloseButton(frame, {
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

  local function RefreshLabels()
    local L = ResolveL(opts)
    SetText(title, L.SIM_TABLET_TITLE or "Demo simulator")
    SetText(statusLine, L.SIM_TABLET_READY or "Ready: buttons run local previews only.")
  end

  local function Refresh()
    RefreshLabels()
    local actions = type(opts.getActions) == "function" and opts.getActions() or controller.actions
    if type(actions) ~= "table" then
      actions = {}
    end
    controller.actions = actions
    for index, action in ipairs(actions) do
      local button = controller.buttons[index]
      if not button then
        button = CreateButton(frame, opts, index)
        controller.buttons[index] = button
      end
      button._isiLiveAction = action
      SetText(button.label, action.id or tostring(index))
      ApplyButtonStatus(button, action.status)
      button:SetScript("OnEnter", function(self)
        ShowTooltip(opts, self, self._isiLiveAction)
      end)
      button:SetScript("OnLeave", HideTooltip)
      button:SetScript("OnClick", function(self)
        local currentAction = self._isiLiveAction
        if type(currentAction) ~= "table" or type(currentAction.run) ~= "function" then
          local L = ResolveL(opts)
          SetText(statusLine, L.SIM_ACTION_BLOCKED or "Blocked by active rule.")
          return
        end
        local ok, message = pcall(currentAction.run)
        local L = ResolveL(opts)
        if ok then
          SetText(statusLine, message or ResolveActionText(L, currentAction, "title", currentAction.title))
        else
          SetText(statusLine, L.SIM_ACTION_FAILED or "Simulation failed.")
        end
      end)
      button:Show()
    end
    for index = #actions + 1, #controller.buttons do
      controller.buttons[index]:Hide()
      controller.buttons[index]._isiLiveAction = nil
    end
  end

  function controller.SetActions(actions)
    controller.actions = type(actions) == "table" and actions or {}
    Refresh()
  end

  function controller.Refresh()
    Refresh()
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
