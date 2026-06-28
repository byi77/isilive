local _, addonTable = ...
addonTable = addonTable or {}

local ActionButtonOverlay = {}
addonTable.ActionButtonOverlay = ActionButtonOverlay

local BUTTON_NAMES = {}
do
  for i = 1, 12 do
    BUTTON_NAMES[#BUTTON_NAMES + 1] = "ActionButton" .. i
    BUTTON_NAMES[#BUTTON_NAMES + 1] = "MultiBarBottomLeftButton" .. i
    BUTTON_NAMES[#BUTTON_NAMES + 1] = "MultiBarBottomRightButton" .. i
    BUTTON_NAMES[#BUTTON_NAMES + 1] = "MultiBarRightButton" .. i
    BUTTON_NAMES[#BUTTON_NAMES + 1] = "MultiBarLeftButton" .. i
    BUTTON_NAMES[#BUTTON_NAMES + 1] = "MultiBar5Button" .. i
    BUTTON_NAMES[#BUTTON_NAMES + 1] = "MultiBar6Button" .. i
    BUTTON_NAMES[#BUTTON_NAMES + 1] = "MultiBar7Button" .. i
  end
  for i = 1, 180 do
    BUTTON_NAMES[#BUTTON_NAMES + 1] = "BT4Button" .. i
  end
  for bar = 1, 10 do
    for button = 1, 12 do
      BUTTON_NAMES[#BUTTON_NAMES + 1] = "ElvUI_Bar" .. bar .. "Button" .. button
    end
  end
  for i = 1, 168 do
    BUTTON_NAMES[#BUTTON_NAMES + 1] = "DominosActionButton" .. i
  end
end

function ActionButtonOverlay.GetActionSpellID(button)
  if type(button) ~= "table" then
    return nil
  end
  if type(button.GetSpellId) == "function" then
    local ok, spellID = pcall(button.GetSpellId, button)
    if ok and spellID then
      return tonumber(spellID)
    end
  end

  local actionSlot
  if type(button.GetAction) == "function" then
    local ok, action = pcall(button.GetAction, button)
    if ok and type(action) == "number" then
      actionSlot = action
    end
  end
  if not actionSlot and type(button.GetAttribute) == "function" then
    local ok, action = pcall(button.GetAttribute, button, "action")
    if ok and type(action) == "number" then
      actionSlot = action
    end
  end
  if not actionSlot and type(button._state_action) == "number" then
    actionSlot = button._state_action
  end
  if not actionSlot and type(button.action) == "number" then
    actionSlot = button.action
  end
  if not actionSlot then
    return nil
  end

  local getActionInfo = rawget(_G, "GetActionInfo")
  if type(getActionInfo) ~= "function" then
    return nil
  end
  local okAction, actionType, actionID = pcall(getActionInfo, actionSlot)
  if not okAction then
    return nil
  end
  if actionType == "spell" then
    return tonumber(actionID)
  end
  if actionType == "macro" and actionID then
    local getMacroSpell = rawget(_G, "GetMacroSpell")
    if type(getMacroSpell) ~= "function" then
      return nil
    end
    local okMacro, macroSpellID = pcall(getMacroSpell, actionID)
    if okMacro then
      return tonumber(macroSpellID)
    end
  end
  return nil
end

function ActionButtonOverlay.ScanButtonsForSpellID(getActionSpellID, targetSpellID)
  local buttons = {}
  for _, name in ipairs(BUTTON_NAMES) do
    local button = rawget(_G, name)
    if type(button) == "table" and type(button.IsVisible) == "function" and button:IsVisible() then
      local width, height = 0, 0
      if type(button.GetSize) == "function" then
        width, height = button:GetSize()
      end
      if (tonumber(width) or 0) > 1 and (tonumber(height) or 0) > 1 then
        local spellID = getActionSpellID(button)
        if spellID == targetSpellID then
          buttons[#buttons + 1] = button
        end
      end
    end
  end
  return buttons
end

function ActionButtonOverlay.ScanButtonsForSpellIDs(getActionSpellID, targetSpellIDs)
  local buttons = {}
  if type(targetSpellIDs) ~= "table" then
    return buttons
  end
  for _, name in ipairs(BUTTON_NAMES) do
    local button = rawget(_G, name)
    if type(button) == "table" and type(button.IsVisible) == "function" and button:IsVisible() then
      local width, height = 0, 0
      if type(button.GetSize) == "function" then
        width, height = button:GetSize()
      end
      if (tonumber(width) or 0) > 1 and (tonumber(height) or 0) > 1 then
        local spellID = getActionSpellID(button)
        if spellID and targetSpellIDs[spellID] == true then
          buttons[#buttons + 1] = button
        end
      end
    end
  end
  return buttons
end

local function AttachCross(overlay)
  if overlay._isiLiveActionCrossH then
    return
  end
  local h = overlay:CreateTexture(nil, "OVERLAY")
  h:SetColorTexture(1, 0, 0, 0.88)
  overlay._isiLiveActionCrossH = h
  local v = overlay:CreateTexture(nil, "OVERLAY")
  v:SetColorTexture(1, 0, 0, 0.88)
  overlay._isiLiveActionCrossV = v
end

local function UpdateCross(overlay)
  local h = overlay._isiLiveActionCrossH
  local v = overlay._isiLiveActionCrossV
  if not h or not v then
    return
  end
  h:ClearAllPoints()
  h:SetPoint("LEFT", overlay, "LEFT", 0, 0)
  h:SetPoint("RIGHT", overlay, "RIGHT", 0, 0)
  v:ClearAllPoints()
  v:SetPoint("TOP", overlay, "TOP", 0, 0)
  v:SetPoint("BOTTOM", overlay, "BOTTOM", 0, 0)
  local width, height = overlay:GetSize()
  h:SetHeight(math.max(2, (tonumber(height) or 0) * 0.24))
  v:SetWidth(math.max(2, (tonumber(width) or 0) * 0.24))
end

function ActionButtonOverlay.CreateCrossOverlay(button)
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return nil
  end
  local overlay = createFrame("Frame", nil, button)
  overlay:SetFrameStrata("HIGH")
  overlay:SetAllPoints(button)
  if type(button.GetFrameLevel) == "function" and type(overlay.SetFrameLevel) == "function" then
    overlay:SetFrameLevel((button:GetFrameLevel() or 0) + 10)
  end
  overlay._targetFrame = button
  AttachCross(overlay)
  UpdateCross(overlay)
  overlay:Hide()
  return overlay
end

