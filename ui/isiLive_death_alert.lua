local _, addonTable = ...
addonTable = addonTable or {}

local DeathAlert = {}
addonTable.DeathAlert = DeathAlert

-- Frameless full-screen death warning: a single huge red outlined FontString
-- anchored above screen center, no window chrome and no backdrop. The scale
-- punch (oversized -> normal) gives the "text flies toward you" impression
-- the alert is meant to have; it then fades out after roughly 1.7 seconds.
local FONT_PATH = "Fonts\\FRIZQT__.TTF"
local FONT_SIZE = 56
local FONT_FLAGS = "THICKOUTLINE"
local TEXT_COLOR = { r = 1, g = 0.1, b = 0.1 }
local PUNCH_START_SCALE = 2.6
local PUNCH_DURATION = 0.35
local FADE_IN_DURATION = 0.12
local HOLD_SECONDS = 1.2
local FADE_OUT_DURATION = 0.45

local FALLBACK_TEXTS = {
  TANK = "Tank died",
  HEALER = "Healer died",
}

local function ResolveAlertText(getL, role)
  local L = type(getL) == "function" and getL() or nil
  if type(L) == "table" then
    local key = role == "TANK" and "DEATH_ALERT_TANK" or "DEATH_ALERT_HEALER"
    local text = L[key]
    if type(text) == "string" and text ~= "" then
      return text
    end
  end
  return FALLBACK_TEXTS[role]
end

local function ApplyAlertText(fontString, text)
  local uiCommon = addonTable.UICommon
  if type(uiCommon) == "table" and type(uiCommon.SetReadableText) == "function" then
    -- Rule 62: visible FontStrings must swap to a cyrillic-capable font when
    -- the payload needs it (ruRU translations of the alert text).
    uiCommon.SetReadableText(fontString, text)
    return
  end
  if type(fontString.SetText) == "function" then
    fontString:SetText(text)
  end
end

local function BuildAlertFrame(createFrame)
  local parent = rawget(_G, "UIParent")
  local frame = createFrame("Frame", nil, parent)
  frame:SetSize(64, 64)
  frame:SetPoint("CENTER", parent, "CENTER", 0, 220)
  if type(frame.SetFrameStrata) == "function" then
    frame:SetFrameStrata("HIGH")
  end
  frame:Hide()

  local text = frame:CreateFontString(nil, "OVERLAY")
  if type(text.SetFont) == "function" then
    text:SetFont(FONT_PATH, FONT_SIZE, FONT_FLAGS)
  end
  if type(text.SetTextColor) == "function" then
    text:SetTextColor(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, 1)
  end
  text:SetPoint("CENTER", frame, "CENTER", 0, 0)
  frame.text = text

  if type(frame.CreateAnimationGroup) == "function" then
    local animGroup = frame:CreateAnimationGroup()

    local punch = animGroup:CreateAnimation("Scale")
    if type(punch.SetScaleFrom) == "function" then
      punch:SetScaleFrom(PUNCH_START_SCALE, PUNCH_START_SCALE)
      punch:SetScaleTo(1, 1)
    end
    punch:SetDuration(PUNCH_DURATION)
    punch:SetSmoothing("OUT")
    punch:SetOrder(1)

    local fadeIn = animGroup:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(FADE_IN_DURATION)
    fadeIn:SetOrder(1)

    local fadeOut = animGroup:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetStartDelay(HOLD_SECONDS)
    fadeOut:SetDuration(FADE_OUT_DURATION)
    fadeOut:SetSmoothing("IN")
    fadeOut:SetOrder(2)

    animGroup:SetScript("OnFinished", function()
      frame:Hide()
    end)
    frame.animGroup = animGroup
  end

  return frame
end

function DeathAlert.CreateController(opts)
  opts = opts or {}
  local createFrame = type(opts.createFrame) == "function" and opts.createFrame or rawget(_G, "CreateFrame")
  local getL = opts.getL

  local controller = {}
  local frame = nil

  function controller.ShowRoleDeath(role)
    if role ~= "TANK" and role ~= "HEALER" then
      return false
    end
    if type(createFrame) ~= "function" then
      return false
    end
    if not frame then
      frame = BuildAlertFrame(createFrame)
    end
    ApplyAlertText(frame.text, ResolveAlertText(getL, role))
    if frame.animGroup and type(frame.animGroup.Stop) == "function" then
      -- Restart cleanly when a second death lands mid-animation.
      frame.animGroup:Stop()
    end
    frame:Show()
    if frame.animGroup and type(frame.animGroup.Play) == "function" then
      frame.animGroup:Play()
    end
    return true
  end

  -- Test-only hook: exposes the lazily created frame so deterministic tests
  -- can assert text and visibility without reaching into module locals.
  function controller._Test_GetFrame()
    return frame
  end

  return controller
end

local controllerInstance = nil

function DeathAlert.SetDependencies(deps)
  if type(deps) ~= "table" then
    return
  end
  controllerInstance = DeathAlert.CreateController(deps)
end

function DeathAlert.ShowRoleDeath(role)
  if not controllerInstance then
    controllerInstance = DeathAlert.CreateController({})
  end
  return controllerInstance.ShowRoleDeath(role)
end
