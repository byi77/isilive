local _, addonTable = ...

addonTable = addonTable or {}

-- TTK text centred inside the target's health bar (see game/isiLive_ttk.lua),
-- on a dark plate: floating damage numbers rise above the nameplate and never
-- have a background, so the plate keeps the TTK readable among them.
-- isiLive's forces text beside the bar stays untouched. MobNameplate resolves
-- the health bar and lends its overlay font, two points larger here.
local TTKNameplate = {}
addonTable.TTKNameplate = TTKNameplate

local FONT_SIZE_BONUS = 2
-- Plate size from the font size alone: the text width of a secret value can
-- not be measured, and a fixed plate also keeps it from jittering.
local PLATE_WIDTH_PER_POINT = 2.6
local PLATE_HEIGHT_PADDING = 4
local PLATE_ALPHA = 0.65
local LEVEL_ABOVE_ANCHOR = 21

local frame = nil
local anchoredTo = nil

local function TextColor()
  local colors = addonTable.UICommon and addonTable.UICommon.Colors or {}
  return colors.LIGHT_BLUE_LEVEL_TEXT or { 0.65, 0.85, 1.0 }
end

local function AnchorTo(anchor)
  if anchoredTo == anchor then
    return
  end
  anchoredTo = anchor
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", anchor, "CENTER", 0, 0)
  -- Nameplates draw in their own strata; follow the anchor so the text is
  -- neither hidden behind nor drawn above unrelated UI. A region anchor
  -- without strata of its own (a texture bar) lends its frame's.
  local layerSource = anchor
  if type(anchor.GetFrameStrata) ~= "function" and type(anchor.GetParent) == "function" then
    layerSource = anchor:GetParent() or anchor
  end
  if type(layerSource.GetFrameStrata) == "function" then
    local ok, strata = pcall(layerSource.GetFrameStrata, layerSource)
    if ok and type(strata) == "string" and strata ~= "" then
      pcall(frame.SetFrameStrata, frame, strata)
    end
  end
  if type(layerSource.GetFrameLevel) == "function" then
    local ok, level = pcall(layerSource.GetFrameLevel, layerSource)
    if ok and type(level) == "number" then
      pcall(frame.SetFrameLevel, frame, level + LEVEL_ABOVE_ANCHOR)
    end
  end
end

-- Overlay font plus FONT_SIZE_BONUS, and the plate sized to it. Only re-done
-- when the overlay font size changes.
local function ApplyFontAndPlate(mobNameplate)
  local text = frame.text
  if type(mobNameplate.ApplyOverlayFont) == "function" then
    mobNameplate.ApplyOverlayFont(text, FONT_SIZE_BONUS)
  end
  if type(text.GetFont) ~= "function" or type(text.SetFont) ~= "function" then
    return
  end
  local _, size = text:GetFont()
  if type(size) ~= "number" or size <= 0 then
    return
  end
  if size ~= frame._baseSize then
    frame._baseSize = size
    frame:SetSize(math.floor(size * PLATE_WIDTH_PER_POINT + 0.5), size + PLATE_HEIGHT_PADDING)
  end
end

local function OnShow()
  local mobNameplate = addonTable.MobNameplate
  local ttk = addonTable.TTK
  local token = type(ttk) == "table" and type(ttk.GetTargetPlateToken) == "function" and ttk.GetTargetPlateToken()
    or nil
  local anchor = type(mobNameplate) == "table"
      and type(mobNameplate.ResolveTtkAnchor) == "function"
      and mobNameplate.ResolveTtkAnchor(token)
    or nil
  if type(anchor) ~= "table" then
    frame:Hide()
    anchoredTo = nil
    return false
  end
  AnchorTo(anchor)
  ApplyFontAndPlate(mobNameplate)
  frame:Show()
  return true
end

local function OnHide()
  frame:Hide()
  anchoredTo = nil
end

--- Creates the frame once and registers it with TTK. Called from the factory.
function TTKNameplate.Install()
  local ttk = addonTable.TTK
  if frame or type(ttk) ~= "table" or type(ttk.RegisterDisplay) ~= "function" then
    return frame ~= nil
  end
  local createFrame = rawget(_G, "CreateFrame")
  local uiParent = rawget(_G, "UIParent")
  if type(createFrame) ~= "function" then
    return false
  end
  local ok, created = pcall(createFrame, "Frame", nil, uiParent)
  if not ok or type(created) ~= "table" then
    return false
  end
  frame = created
  frame:SetSize(40, 18)
  local plate = frame:CreateTexture(nil, "BACKGROUND")
  plate:SetAllPoints(frame)
  plate:SetTexture("Interface\\Buttons\\WHITE8X8")
  local plateColor = (
    addonTable.UICommon
    and addonTable.UICommon.Colors
    and addonTable.UICommon.Colors.BLACK_OVERLAY_50
  ) or { 0, 0, 0, 0.5 }
  plate:SetVertexColor(plateColor[1], plateColor[2], plateColor[3], PLATE_ALPHA)
  frame.plate = plate
  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
  text:SetPoint("CENTER", frame, "CENTER", 0, 0)
  text:SetJustifyH("CENTER")
  local color = TextColor()
  text:SetTextColor(color[1], color[2], color[3])
  frame.text = text
  frame:Hide()
  ttk.RegisterDisplay(text, {
    format = "%.0fs",
    placeholder = "…",
    onShow = OnShow,
    onHide = OnHide,
  })
  return true
end
