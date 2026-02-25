local _, addonTable = ...

addonTable = addonTable or {}

local UICommon = {}
addonTable.UICommon = UICommon

local function ApplyCloseButtonBackdrop(button)
  if type(button.SetBackdrop) ~= "function" then
    return
  end

  button:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })

  if type(button.SetBackdropColor) == "function" then
    button:SetBackdropColor(0, 0, 0, 0.85)
  end
end

local function CreateCloseButtonLabel(button)
  if type(button.CreateFontString) ~= "function" then
    return nil
  end

  local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  label:SetPoint("CENTER", button, "CENTER", 0, -1)
  label:SetText("X")
  label:SetTextColor(1, 0.2, 0.2, 1)
  return label
end

local function AttachCloseButtonVisualStates(button, label)
  if not label then
    return
  end

  button:SetScript("OnEnter", function()
    label:SetTextColor(1, 0.35, 0.35, 1)
  end)

  button:SetScript("OnLeave", function()
    label:SetTextColor(1, 0.2, 0.2, 1)
  end)

  button:SetScript("OnMouseDown", function()
    label:SetTextColor(0.9, 0.12, 0.12, 1)
  end)

  button:SetScript("OnMouseUp", function()
    label:SetTextColor(1, 0.35, 0.35, 1)
  end)
end

function UICommon.CreateRedCloseButton(parent, opts)
  opts = opts or {}
  local button = CreateFrame("Button", opts.name, parent, "BackdropTemplate")
  local size = tonumber(opts.size) or 20
  button:SetSize(size, size)

  local point = opts.point
  if type(point) == "table" then
    button:SetPoint(point[1], point[2], point[3], point[4], point[5])
  else
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, -2)
  end

  local strata = opts.frameStrata or (parent and parent.GetFrameStrata and parent:GetFrameStrata()) or "MEDIUM"
  button:SetFrameStrata(strata)

  local level = tonumber(opts.frameLevel) or ((parent and parent.GetFrameLevel and parent:GetFrameLevel()) or 1) + 20
  button:SetFrameLevel(level)

  ApplyCloseButtonBackdrop(button)
  local label = CreateCloseButtonLabel(button)
  AttachCloseButtonVisualStates(button, label)

  return button
end
