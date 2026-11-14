local _, addonTable = ...
addonTable = addonTable or {}

-- Title-bar switch for the run focus (rule 248): a 20 px title button between
-- the V mode button and Re-Sync that turns runFocusEnabled on and off, styled
-- like the mode buttons (active = primary surface, inactive = greyed). Only
-- the M+ layout shows it; with the layout locked to M+ (rule 249) it takes
-- the place of the hidden mode buttons left of Re-Sync. The run focus hides it with the rest of the title bar while
-- collapsed, so it is reachable while the window is open.
local RunFocus = addonTable.RunFocus or {}
addonTable.RunFocus = RunFocus

local RI = addonTable._RosterInternal or {}
addonTable._RosterInternal = RI

local UICommon = addonTable.UICommon or {}

local LAYOUT_MODE_RUN = "compact_main_horizontal"
local BUTTON_SIZE = 20
local ICON_SIZE = 14
local TITLE_BUTTON_Y = -4
local ICON_KEY = "cooldown"

local function SlotX(slot)
  local first = tonumber(RI.TITLE_BUTTON_FIRST_SLOT_X) or -74
  local width = tonumber(RI.TITLE_BUTTON_SLOT_WIDTH) or 22
  return first - slot * width
end

local function ShowTooltip(button, getText, isEnabled)
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return
  end
  local enabled = isEnabled()
  local title = enabled and getText("RUN_FOCUS_TOGGLE_TITLE_ON", "Run focus: on")
    or getText("RUN_FOCUS_TOGGLE_TITLE_OFF", "Run focus: off")
  local body = getText(
    "RUN_FOCUS_TOGGLE_BODY",
    "On: while a key runs, the M+ window shows only battle res, Bloodlust, timer and killtracker. Click to switch."
  )
  tooltip:SetOwner(button, "ANCHOR_BOTTOM")
  tooltip:SetText(title)
  tooltip:AddLine(body, 1, 1, 1, true)
  tooltip:Show()
end

local function HideTooltip()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end

local function CreateButton(frame)
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return nil
  end
  local button = createFrame("Button", nil, frame, "BackdropTemplate")
  button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
  button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", SlotX(1), TITLE_BUTTON_Y)
  -- The drag handle sits at frame level + 100; the title buttons above it.
  if type(button.SetFrameLevel) == "function" and type(frame.GetFrameLevel) == "function" then
    button:SetFrameLevel(frame:GetFrameLevel() + 102)
  end
  if type(UICommon.ApplyBackdrop) == "function" then
    UICommon.ApplyBackdrop(button, "TITLE_BUTTON")
  end
  local icon = button:CreateTexture(nil, "OVERLAY")
  icon:SetSize(ICON_SIZE, ICON_SIZE)
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  if type(UICommon.ApplyStateIcon) == "function" then
    UICommon.ApplyStateIcon(icon, ICON_KEY)
  end
  button.icon = icon
  button:Hide()
  return button
end

--- Creates the switch on the main frame. deps: frame, ui (roster panel ui),
--- getText(key, fallback), isEnabled(), onToggle(). Returns { button,
--- Layout(phase), Refresh() } or nil.
function RunFocus.CreateTitleToggle(deps)
  deps = type(deps) == "table" and deps or {}
  local frame, ui = deps.frame, deps.ui
  if type(frame) ~= "table" or type(ui) ~= "table" then
    return nil
  end
  local button = CreateButton(frame)
  if not button then
    return nil
  end
  local isEnabled = deps.isEnabled
  local getText = deps.getText
  local toggle = { button = button }

  function toggle.Refresh()
    local enabled = isEnabled() == true
    button._isiLiveRunFocusActive = enabled
    if type(UICommon.ApplyActionButtonVisual) == "function" then
      UICommon.ApplyActionButtonVisual(button, enabled and "primary" or "title", "default")
    end
    if type(button.icon.SetDesaturated) == "function" then
      button.icon:SetDesaturated(not enabled)
    end
    button.icon:SetAlpha(enabled and 1 or 0.45)
  end

  -- Runs after every layout pass and render (RunFocus Pass). While the layout
  -- is locked to M+ (rule 249) the mode buttons stay hidden and the switch
  -- takes their place left of Re-Sync; unlocked, the mode buttons move one
  -- more slot to the left in M+ and the switch sits between V and Re-Sync.
  function toggle.Layout(phase)
    if ui.layoutMode ~= LAYOUT_MODE_RUN then
      button:Hide()
      return
    end
    local locked = type(RI.IsLayoutLocked) == "function" and RI.IsLayoutLocked()
    local shift = (tonumber(RI.TITLE_BUTTON_SLOT_WIDTH) or 22) * 2
    for _, modeButton in ipairs(ui.modeButtons or {}) do
      local baseX = tonumber(modeButton._titleBaseX)
      if locked then
        modeButton:Hide()
      elseif baseX and modeButton.ClearAllPoints and modeButton.SetPoint then
        modeButton:ClearAllPoints()
        modeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", baseX - shift, TITLE_BUTTON_Y)
        if phase == "idle" and not modeButton:IsShown() then
          modeButton:Show()
        end
      end
    end
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", SlotX(1), TITLE_BUTTON_Y)
    if phase == "idle" and not button:IsShown() then
      button:Show()
    end
  end

  button:SetScript("OnClick", function(self)
    deps.onToggle()
    toggle.Refresh()
    if type(self.IsMouseOver) == "function" and self:IsMouseOver() then
      ShowTooltip(self, getText, isEnabled)
    end
  end)
  button:SetScript("OnEnter", function(self)
    if type(UICommon.ApplyActionButtonVisual) == "function" then
      UICommon.ApplyActionButtonVisual(self, self._isiLiveRunFocusActive and "primary" or "title", "hover")
    end
    ShowTooltip(self, getText, isEnabled)
  end)
  button:SetScript("OnLeave", function()
    toggle.Refresh()
    HideTooltip()
  end)
  toggle.Refresh()
  return toggle
end
