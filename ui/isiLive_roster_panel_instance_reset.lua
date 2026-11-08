local _, addonTable = ...
addonTable = addonTable or {}

-- Instance reset button of the main window (rule 235): construction, the
-- visibility pass run with every leader-button update, and its place per
-- layout. The decision whether it shows lives in
-- logic/isiLive_instance_reset.lua; this file only renders it.
--
-- Placement: M puts it into the leader column below Mark-T/H; M+ adds it as a
-- sixth button to the toolbar row, which then splits its width six ways; H
-- and V keep their three management buttons and hide it (like Keys teilen
-- and Mark-T/H).
--
-- Layout helpers and constants come from ui/isiLive_roster_layout.lua through
-- _RosterInternal and are read at call time, so the load order between the
-- two files does not matter.

addonTable._RosterInternal = addonTable._RosterInternal or {}
local RI = addonTable._RosterInternal

-- Next free slot of the M leader column (Mark-T/H sits at -180).
local LEADER_COLUMN_Y = -210
local LEADER_BUTTON_WIDTH = 120
local LEADER_BUTTON_HEIGHT = 24

local function NormalizedLayoutMode(ui)
  local normalize = RI.NormalizeLayoutMode
  if type(normalize) == "function" then
    return normalize(ui.layoutMode)
  end
  return ui.layoutMode
end

local function IsExpanded(layoutMode)
  return layoutMode == (RI.LAYOUT_MODE_EXPANDED or "expanded")
end

local function IsMainHorizontal(layoutMode)
  return layoutMode == (RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL or "compact_main_horizontal")
end

local function IsInstanceResetShown(ui)
  if type(ui) ~= "table" or not ui.instanceResetButton or ui.instanceResetVisible ~= true then
    return false
  end
  local layoutMode = NormalizedLayoutMode(ui)
  return IsExpanded(layoutMode) or IsMainHorizontal(layoutMode)
end
RI.IsInstanceResetShown = IsInstanceResetShown

local function M2RowWidth()
  local width = RI.M2_TOOLBAR_BUTTON_WIDTH or 92
  local gap = RI.M2_TOOLBAR_BUTTON_GAP or 6
  return (5 * width) + (4 * gap), gap
end

--- Left offset and width of slot `index` among `count` M+ toolbar slots.
--- Rounded edges keep the row exactly as wide as five standard buttons; five
--- slots reproduce the 92 px buttons at a 98 px pitch.
function RI.GetM2ToolbarSlot(index, count)
  local rowWidth, gap = M2RowWidth()
  local pitch = (rowWidth + gap) / math.max(1, count)
  local left = math.floor(((index - 1) * pitch) + 0.5)
  local right = math.floor((index * pitch) + 0.5) - gap
  return left, right - left
end

local function CallLayout(name, ...)
  local fn = RI[name]
  if type(fn) == "function" then
    fn(...)
  end
end

local function LayoutM2Toolbar(ui, includeReset)
  local buttons = {}
  for _, btn in ipairs(ui.toolbarButtons or {}) do
    buttons[#buttons + 1] = btn
  end
  if includeReset then
    buttons[#buttons + 1] = ui.instanceResetButton
  end
  local margin = RI.M2_ROW_LEFT_MARGIN or 8
  local rowY = RI.M2_MANAGEMENT_ROW_Y or 104
  local height = RI.M2_TOOLBAR_BUTTON_HEIGHT or 22
  for index, btn in ipairs(buttons) do
    local left, width = RI.GetM2ToolbarSlot(index, #buttons)
    -- Both helpers skip secure buttons in combat; the post-combat layout
    -- replay of the roster panel restores them.
    CallLayout("SetFrameSizeSafe", btn, width, height)
    CallLayout("ReanchorFrame", btn, "BOTTOMLEFT", margin + left, rowY)
    local text = btn._m2ToolbarText or btn._fullText
    if text then
      -- The reset button has no RefreshDisplayText of its own.
      CallLayout(btn == ui.instanceResetButton and "SetFlatButtonText" or "RefreshButtonDisplayText", btn, text)
    end
  end
end

--- Applies visibility and slot of the reset button for the current layout.
--- Called at the end of every UpdateCollapseState and after a visibility
--- change; the reset button itself is a plain frame.
function RI.ApplyInstanceResetLayout(ui)
  local btn = type(ui) == "table" and ui.instanceResetButton or nil
  if not btn then
    return
  end
  local layoutMode = NormalizedLayoutMode(ui)
  local shown = IsInstanceResetShown(ui)
  if IsMainHorizontal(layoutMode) then
    LayoutM2Toolbar(ui, shown)
  elseif IsExpanded(layoutMode) then
    CallLayout("SetFrameSizeSafe", btn, LEADER_BUTTON_WIDTH, LEADER_BUTTON_HEIGHT)
    CallLayout("ReanchorFrame", btn, "TOPRIGHT", RI.MANAGEMENT_COLUMN_X or -145, LEADER_COLUMN_Y)
    if btn._fullText then
      CallLayout("SetFlatButtonText", btn, btn._fullText)
    end
  end
  if btn.SetShown then
    btn:SetShown(shown)
  elseif shown and btn.Show then
    btn:Show()
  elseif not shown and btn.Hide then
    btn:Hide()
  end
end

--- Creates the reset button and adds it to the panel's button table.
--- ResetInstances() carries no protection flag and the click is a hardware
--- event, so a plain button is enough.
function RI.AddInstanceResetButton(buttons, mainFrame, deps)
  local button = RI.CreateFlatButton(mainFrame, LEADER_BUTTON_WIDTH, LEADER_BUTTON_HEIGHT)
  if type(button.SetSemanticRole) == "function" then
    button:SetSemanticRole("primary")
  end
  button:SetPoint("TOPRIGHT", RI.MANAGEMENT_COLUMN_X or -145, LEADER_COLUMN_Y)
  button._verticalY = LEADER_COLUMN_Y
  button:SetScript("OnClick", function()
    local instanceReset = addonTable.InstanceReset
    local requested = type(instanceReset) == "table"
      and type(instanceReset.RequestReset) == "function"
      and instanceReset.RequestReset() == true
    if type(deps.logRuntimeTrace) == "function" then
      deps.logRuntimeTrace(string.format("[UI] btn_click name=instance_reset requested=%s", tostring(requested)))
    end
  end)
  if type(RI.AttachPanelButtonTooltip) == "function" then
    RI.AttachPanelButtonTooltip(
      deps.tooltipFrame,
      button,
      deps.getL,
      "BTN_INSTANCE_RESET",
      "TOOLTIP_INSTANCE_RESET",
      deps.isPlayerLeader
    )
  end
  button:Hide()
  buttons.instanceResetButton = button
  return buttons
end

--- Re-evaluates the button with every leader-button pass (roster, leader and
--- instance changes, the reset module's own state changes, settings toggle).
function RI.UpdateInstanceResetButton(ui, logRuntimeTraceDeep)
  if type(ui) ~= "table" or not ui.instanceResetButton then
    return
  end
  local instanceReset = addonTable.InstanceReset
  local visible = type(instanceReset) == "table"
    and type(instanceReset.ShouldShowButton) == "function"
    and instanceReset.ShouldShowButton() == true
  if visible == (ui.instanceResetVisible == true) then
    return
  end
  ui.instanceResetVisible = visible
  if type(logRuntimeTraceDeep) == "function" then
    logRuntimeTraceDeep(function()
      return string.format("[ROSTER_UI] instance_reset_button visible=%s", tostring(visible))
    end)
  end
  RI.ApplyInstanceResetLayout(ui)
end
