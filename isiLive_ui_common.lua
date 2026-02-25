local _, addonTable = ...

addonTable = addonTable or {}

local UICommon = {}
addonTable.UICommon = UICommon

function UICommon.CreateRedCloseButton(parent, opts)
  opts = opts or {}
  local button = CreateFrame("Button", opts.name, parent, "UIPanelCloseButton")
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

  local normalTexture = button.GetNormalTexture and button:GetNormalTexture() or nil
  local pushedTexture = button.GetPushedTexture and button:GetPushedTexture() or nil
  local highlightTexture = button.GetHighlightTexture and button:GetHighlightTexture() or nil

  if normalTexture and normalTexture.SetVertexColor then
    normalTexture:SetVertexColor(1, 0.2, 0.2, 1)
  end
  if pushedTexture and pushedTexture.SetVertexColor then
    pushedTexture:SetVertexColor(0.9, 0.15, 0.15, 1)
  end
  if highlightTexture and highlightTexture.SetVertexColor then
    highlightTexture:SetVertexColor(1, 0.45, 0.45, 1)
  end

  return button
end
