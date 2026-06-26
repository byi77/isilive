local _, addonTable = ...
addonTable = addonTable or {}

local VipDkAssist = {}
addonTable.VipDkAssist = VipDkAssist

local DARK_TRANSFORMATION_SPELL_ID = 1233448
local SOUL_REAPER_SPELL_ID = 343294
local PUTREFY_SPELL_ID = 1247378
local UNHOLY_DEATH_KNIGHT_SPEC_ID = 252
local WARNING_DELAY_SECONDS = 30
local WARNING_DURATION_SECONDS = 15

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

local function DefaultTimerAfter(delaySeconds, callback)
  local timer = rawget(_G, "C_Timer")
  local newTimer = type(timer) == "table" and timer.NewTimer or nil
  if type(newTimer) == "function" then
    return newTimer(delaySeconds, callback)
  end
  local after = type(timer) == "table" and timer.After or nil
  if type(after) == "function" then
    after(delaySeconds, callback)
  end
  return nil
end

local function DefaultGetDB()
  return rawget(_G, "IsiLiveDB") or {}
end

local function DefaultIsLocalUnholyDeathKnight()
  local unitClass = rawget(_G, "UnitClass")
  if type(unitClass) ~= "function" then
    return false
  end
  local okClass, _, classToken = pcall(unitClass, "player")
  if not okClass or classToken ~= "DEATHKNIGHT" then
    return false
  end

  local specApi = rawget(_G, "C_SpecializationInfo")
  local getSpecialization = type(specApi) == "table" and specApi.GetSpecialization or rawget(_G, "GetSpecialization")
  local getSpecializationInfo = type(specApi) == "table" and specApi.GetSpecializationInfo
    or rawget(_G, "GetSpecializationInfo")
  if type(getSpecialization) ~= "function" or type(getSpecializationInfo) ~= "function" then
    return false
  end

  local okSpecIndex, specIndex = pcall(getSpecialization)
  if not okSpecIndex or not specIndex then
    return false
  end
  local okSpecInfo, specID = pcall(getSpecializationInfo, specIndex)
  return okSpecInfo and tonumber(specID) == UNHOLY_DEATH_KNIGHT_SPEC_ID
end

local function DefaultGetActionSpellID(button)
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

local function DefaultScanButtonsForSpellID(getActionSpellID, targetSpellID)
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

local function AttachCross(overlay)
  if overlay._isiLiveDkAssistCrossH then
    return
  end
  local h = overlay:CreateTexture(nil, "OVERLAY")
  h:SetColorTexture(1, 0, 0, 0.88)
  overlay._isiLiveDkAssistCrossH = h
  local v = overlay:CreateTexture(nil, "OVERLAY")
  v:SetColorTexture(1, 0, 0, 0.88)
  overlay._isiLiveDkAssistCrossV = v
end

local function UpdateCross(overlay)
  local h = overlay._isiLiveDkAssistCrossH
  local v = overlay._isiLiveDkAssistCrossV
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

local function DefaultCreateOverlay(button)
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

function VipDkAssist.CreateController(opts)
  opts = opts or {}
  local getDB = type(opts.getDB) == "function" and opts.getDB or DefaultGetDB
  local isLocalUnholyDeathKnight = type(opts.isLocalUnholyDeathKnight) == "function" and opts.isLocalUnholyDeathKnight
    or DefaultIsLocalUnholyDeathKnight
  local getActionSpellID = type(opts.getActionSpellID) == "function" and opts.getActionSpellID
    or DefaultGetActionSpellID
  local scanSoulReaperButtons = type(opts.scanSoulReaperButtons) == "function" and opts.scanSoulReaperButtons
    or function()
      return DefaultScanButtonsForSpellID(getActionSpellID, SOUL_REAPER_SPELL_ID)
    end
  local scanPutrefyButtons = type(opts.scanPutrefyButtons) == "function" and opts.scanPutrefyButtons
    or function()
      return DefaultScanButtonsForSpellID(getActionSpellID, PUTREFY_SPELL_ID)
    end
  local createOverlay = type(opts.createOverlay) == "function" and opts.createOverlay or DefaultCreateOverlay
  local timerAfter = type(opts.timerAfter) == "function" and opts.timerAfter or DefaultTimerAfter

  local controller = {}
  local warningTimer = nil
  local hideTimer = nil
  local overlays = {}
  local warningActive = false

  local function CancelTimer(timer)
    if timer and type(timer.Cancel) == "function" then
      timer:Cancel()
    end
  end

  local function IsEnabled()
    local db = getDB() or {}
    return (db.vipDkSoulReaperWarningEnabled == true or db.vipDkPutrefyWarningEnabled == true)
      and isLocalUnholyDeathKnight() == true
  end

  local function GetEnabledScanners()
    local db = getDB() or {}
    local scanners = {}
    if db.vipDkSoulReaperWarningEnabled == true then
      scanners[#scanners + 1] = scanSoulReaperButtons
    end
    if db.vipDkPutrefyWarningEnabled == true then
      scanners[#scanners + 1] = scanPutrefyButtons
    end
    return scanners
  end

  local function HideWarning()
    warningActive = false
    for _, overlay in ipairs(overlays) do
      if type(overlay.Hide) == "function" then
        overlay:Hide()
      end
    end
  end

  local function RebuildOverlays()
    HideWarning()
    overlays = {}
    for _, scanner in ipairs(GetEnabledScanners()) do
      local buttons = scanner() or {}
      for _, button in ipairs(buttons) do
        local overlay = createOverlay(button)
        if overlay then
          overlays[#overlays + 1] = overlay
        end
      end
    end
  end

  local function ShowWarning()
    hideTimer = nil
    if not IsEnabled() then
      HideWarning()
      return
    end

    RebuildOverlays()
    warningActive = true
    for _, overlay in ipairs(overlays) do
      if type(overlay.Show) == "function" then
        overlay:Show()
      end
    end

    hideTimer = timerAfter(WARNING_DURATION_SECONDS, function()
      hideTimer = nil
      HideWarning()
    end)
  end

  function controller.HandleUnitSpellcastSucceeded(unit, _, spellID)
    if unit ~= "player" then
      return
    end
    if tonumber(spellID) ~= DARK_TRANSFORMATION_SPELL_ID then
      return
    end

    CancelTimer(warningTimer)
    CancelTimer(hideTimer)
    warningTimer = nil
    hideTimer = nil
    HideWarning()

    if not IsEnabled() then
      return
    end

    warningTimer = timerAfter(WARNING_DELAY_SECONDS, function()
      warningTimer = nil
      ShowWarning()
    end)
  end

  function controller.Refresh()
    if warningActive then
      HideWarning()
      ShowWarning()
    end
  end

  function controller.Stop()
    CancelTimer(warningTimer)
    CancelTimer(hideTimer)
    warningTimer = nil
    hideTimer = nil
    HideWarning()
  end

  function controller.IsWarningActive()
    return warningActive
  end

  return controller
end

local controllerInstance = nil

function VipDkAssist.SetDependencies(deps)
  if type(deps) ~= "table" then
    return
  end
  controllerInstance = VipDkAssist.CreateController(deps)
end

function VipDkAssist.HandleEvent(event, ...)
  if not controllerInstance then
    return
  end
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    controllerInstance.HandleUnitSpellcastSucceeded(...)
  elseif event == "PLAYER_REGEN_ENABLED" then
    controllerInstance.Stop()
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    controllerInstance.Stop()
  end
end
