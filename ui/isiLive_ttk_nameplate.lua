local _, addonTable = ...

addonTable = addonTable or {}

-- TTK text above the target's nameplate (see game/isiLive_ttk.lua), centred
-- over the health bar and clear of the mob name, so isiLive's forces text
-- beside the bar stays untouched. MobNameplate resolves the health bar and
-- lends its overlay font.
local TTKNameplate = {}
addonTable.TTKNameplate = TTKNameplate

-- Above the bar top, past the name line nameplate addons draw there.
local ABOVE_BAR_OFFSET = 18
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
  frame:SetPoint("BOTTOM", anchor, "TOP", 0, ABOVE_BAR_OFFSET)
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
  if type(mobNameplate.ApplyOverlayFont) == "function" then
    mobNameplate.ApplyOverlayFont(frame.text)
  end
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
  frame:SetSize(1, 1)
  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
  text:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
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
