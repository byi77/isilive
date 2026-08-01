local _, addonTable = ...

addonTable = addonTable or {}

local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

local PortalNavigatorNotice = {}
addonTable.PortalNavigatorNotice = PortalNavigatorNotice

local PORTAL_NAVIGATOR_SLOT_POINTS = {
  left = { point = "TOPLEFT", x = 36, y = -142, iconX = 0, iconY = -6 },
  half_left = { point = "TOPLEFT", x = 178, y = -102, iconX = 0, iconY = -6 },
  center = { point = "TOP", x = 0, y = -82, iconX = 0, iconY = -6 },
  half_right = { point = "TOPRIGHT", x = -178, y = -102, iconX = 0, iconY = -6 },
  right = { point = "TOPRIGHT", x = -36, y = -142, iconX = 0, iconY = -6 },
}

local PORTAL_NAVIGATOR_SLOT_ORDER = { "left", "half_left", "center", "half_right", "right" }

local function BuildConfig(opts)
  opts = opts or {}
  local frameName = type(opts.frameName) == "string" and opts.frameName ~= "" and opts.frameName
    or "isiLivePortalNavigatorNotice"
  return {
    parent = opts.parent or UIParent,
    frameName = frameName,
    width = tonumber(opts.width) or 760,
    height = tonumber(opts.height) or 220,
    yOffset = tonumber(opts.yOffset) or 190,
    frameAlpha = tonumber(opts.frameAlpha) or 1,
    backgroundAlpha = tonumber(opts.backgroundAlpha) or 0.62,
    fontDelta = tonumber(opts.fontDelta) or 2,
    headerFontDelta = tonumber(opts.headerFontDelta) or 10,
    paddingX = tonumber(opts.paddingX) or 24,
    paddingY = tonumber(opts.paddingY) or 14,
    entryWidth = tonumber(opts.entryWidth) or 180,
    frameStrata = type(opts.frameStrata) == "string" and opts.frameStrata ~= "" and opts.frameStrata or nil,
    frameLevel = tonumber(opts.frameLevel),
  }
end

local function CreateFrameRoot(config, deps)
  local frame = CreateFrame("Frame", config.frameName, config.parent, "BackdropTemplate")
  frame:SetSize(config.width, config.height)
  frame:SetPoint("CENTER", config.parent, "CENTER", 0, config.yOffset)
  deps.applyFrameLayer(frame, config)
  frame:SetMovable(true)
  deps.clampMovableFrameToScreen(frame)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:Hide()
  frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
  end)

  local colors = deps.colors
  local UICommon = addonTable and addonTable.UICommon
  if not (type(UICommon) == "table" and UICommon.ApplyBackdrop and UICommon.ApplyBackdrop(frame, "NOTICE")) then
    if type(frame.CreateTexture) == "function" then
      local bg = frame:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      local base = colors.BG_NOTICE_CARD_BASE or { 0.05, 0.05, 0.08 }
      bg:SetColorTexture(base[1], base[2], base[3], config.backgroundAlpha)
    end
  elseif type(frame.SetBackdropColor) == "function" then
    local base = colors.BG_NOTICE_CARD_BASE or { 0.05, 0.05, 0.08 }
    frame:SetBackdropColor(base[1], base[2], base[3], config.backgroundAlpha)
  end
  if type(frame.SetAlpha) == "function" then
    frame:SetAlpha(config.frameAlpha)
  end
  return frame
end

local function CreateEyebrow(frame, config, deps)
  local eyebrow = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  deps.increaseFontSize(eyebrow, math.max(0, math.floor((tonumber(config.headerFontDelta) or 0) / 3)))
  eyebrow:SetPoint("TOPLEFT", frame, "TOPLEFT", config.paddingX, -config.paddingY)
  eyebrow:SetJustifyH("LEFT")
  eyebrow:SetJustifyV("TOP")
  eyebrow:SetWordWrap(false)
  if eyebrow.SetNonSpaceWrap then
    eyebrow:SetNonSpaceWrap(false)
  end
  eyebrow:SetTextColor(unpack(deps.colors.CYAN_EYEBROW or { 0.46, 0.94, 1 }))
  return eyebrow
end

local function CreateTitle(frame, config, deps)
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  deps.increaseFontSize(title, config.headerFontDelta)
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", config.paddingX, -(config.paddingY + 18))
  title:SetJustifyH("LEFT")
  title:SetJustifyV("MIDDLE")
  title:SetWidth(config.width - (config.paddingX * 2))
  title:SetTextColor(unpack(deps.titleColor))
  return title
end

local function CreateSeparator(frame, colors)
  if type(frame.CreateTexture) ~= "function" then
    return
  end
  local sep = frame:CreateTexture(nil, "ARTWORK")
  sep:SetHeight(1)
  sep:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -68)
  sep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -68)
  sep:SetColorTexture(unpack(colors.BLUE_SEPARATOR or { 0.36, 0.71, 1, 0.55 }))
  return sep
end

local function CreateEntry(frame, config, slot, deps)
  local text = deps.createBodyText(frame, config)
  local pointDef = PORTAL_NAVIGATOR_SLOT_POINTS[slot] or PORTAL_NAVIGATOR_SLOT_POINTS.left
  local colors = deps.colors

  local direction = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  deps.increaseFontSize(direction, math.max(0, math.floor((tonumber(config.fontDelta) or 0) / 2)))
  direction:SetWidth(config.entryWidth)
  direction:SetJustifyH("CENTER")
  direction:SetJustifyV("TOP")
  direction:SetWordWrap(false)
  if direction.SetNonSpaceWrap then
    direction:SetNonSpaceWrap(false)
  end
  direction:SetTextColor(unpack(colors.CYAN_DIRECTION or { 0.38, 0.92, 1 }))
  direction:SetPoint(pointDef.point, frame, pointDef.point, pointDef.x, pointDef.y)

  local iconBg = frame:CreateTexture(nil, "BACKGROUND")
  if type(iconBg.SetSize) == "function" then
    iconBg:SetSize(44, 44)
  end
  iconBg:SetPoint("TOP", direction, "BOTTOM", pointDef.iconX, pointDef.iconY)
  iconBg:SetColorTexture(unpack(colors.DEEP_BLUE_ICON_BG or { 0.05, 0.2, 0.34, 0.65 }))

  local iconCore = frame:CreateTexture(nil, "ARTWORK")
  if type(iconCore.SetSize) == "function" then
    iconCore:SetSize(40, 40)
  end
  iconCore:SetPoint("CENTER", iconBg, "CENTER", 0, 0)
  iconCore:SetColorTexture(unpack(colors.BLUE_ICON_CORE or { 0.1, 0.45, 1, 0.92 }))

  text:SetWidth(config.entryWidth)
  text:SetJustifyH("CENTER")
  text:SetJustifyV("MIDDLE")
  text:SetWordWrap(false)
  if text.SetNonSpaceWrap then
    text:SetNonSpaceWrap(false)
  end
  text:SetPoint("TOP", iconBg, "BOTTOM", 0, -6)

  local detail = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  detail:SetWidth(config.entryWidth)
  detail:SetJustifyH("CENTER")
  detail:SetJustifyV("TOP")
  detail:SetWordWrap(false)
  if detail.SetNonSpaceWrap then
    detail:SetNonSpaceWrap(false)
  end
  detail:SetTextColor(unpack(colors.SLATE_DETAIL_TEXT or { 0.62, 0.68, 0.76 }))
  detail:SetPoint("TOP", text, "BOTTOM", 0, -2)

  return {
    direction = direction,
    destination = text,
    detail = detail,
    iconBg = iconBg,
    iconCore = iconCore,
  }
end

local function SetIconTexture(iconFrame, icon)
  if type(iconFrame) ~= "table" then
    return
  end
  if type(iconFrame.SetTexture) == "function" then
    iconFrame:SetTexture(icon)
  end
  if icon ~= nil and type(iconFrame.SetTexCoord) == "function" then
    iconFrame:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
end

local function SetIconColor(iconFrame, r, g, b, a)
  if type(iconFrame) ~= "table" then
    return
  end
  SetIconTexture(iconFrame, nil)
  if type(iconFrame.SetColorTexture) == "function" then
    iconFrame:SetColorTexture(r, g, b, a)
  end
end

local function ClearEntries(state)
  local colors = state.deps.colors
  state.eyebrowText:SetText("")
  state.titleText:SetText("")
  for _, slot in ipairs(PORTAL_NAVIGATOR_SLOT_ORDER) do
    local entry = state.nodes[slot]
    if entry then
      entry.direction:SetText("")
      entry.destination:SetText("")
      entry.detail:SetText("")
      entry.iconBg:SetColorTexture(unpack(colors.DEEP_BLUE_ICON_BG or { 0.05, 0.2, 0.34, 0.65 }))
      SetIconColor(entry.iconCore, 0.1, 0.45, 1, 0.92)
    end
  end
end

local function ApplyLayout(state, layout)
  if type(layout) ~= "table" then
    ClearEntries(state)
    return false
  end

  local title = type(layout.title) == "string" and layout.title or ""
  if title == "" then
    ClearEntries(state)
    return false
  end

  local eyebrow = type(layout.eyebrow) == "string" and layout.eyebrow or ""
  if eyebrow ~= "" then
    state.deps.setReadableText(state.eyebrowText, eyebrow)
  else
    state.eyebrowText:SetText("")
  end

  state.deps.setReadableText(state.titleText, title)

  local entryMap = {}
  for _, entry in ipairs(layout.entries or {}) do
    if type(entry) == "table" and type(entry.slot) == "string" then
      entryMap[entry.slot] = entry
    end
  end

  local colors = state.deps.colors
  for _, slot in ipairs(PORTAL_NAVIGATOR_SLOT_ORDER) do
    local node = state.nodes[slot]
    local entry = entryMap[slot]
    if node and entry then
      node.direction:SetText("")
      state.deps.setReadableText(node.destination, entry.destination or "")
      node.detail:SetText("")
      if entry.isEmpty == true then
        node.iconBg:SetColorTexture(unpack(colors.DARK_SLATE_ICON_BG or { 0.13, 0.15, 0.18, 0.55 }))
        SetIconColor(node.iconCore, 0.36, 0.4, 0.46, 0.78)
      else
        node.iconBg:SetColorTexture(unpack(colors.DEEP_BLUE_ICON_BG or { 0.05, 0.2, 0.34, 0.65 }))
        if type(entry.icon) == "string" or type(entry.icon) == "number" then
          SetIconTexture(node.iconCore, entry.icon)
        else
          SetIconColor(node.iconCore, 0.1, 0.45, 1, 0.92)
        end
      end
    elseif node then
      node.direction:SetText("")
      node.destination:SetText("")
      node.detail:SetText("")
    end
  end

  return true
end

local function BuildController(state)
  local function ResetToConfiguredPosition()
    state.frame:ClearAllPoints()
    state.frame:SetPoint("CENTER", state.config.parent, "CENTER", 0, state.config.yOffset)
  end

  local function SetVisible(visible)
    if visible then
      if not state.frame:IsShown() then
        ResetToConfiguredPosition()
        state.frame:Show()
      end
      return
    end
    if state.frame:IsShown() then
      state.frame:Hide()
    end
  end

  local function Show(layout)
    if not ApplyLayout(state, layout) then
      SetVisible(false)
      return false
    end
    SetVisible(true)
    return true
  end

  return {
    frame = state.frame,
    eyebrowText = state.eyebrowText,
    titleText = state.titleText,
    titleSeparator = state.titleSeparator,
    entries = state.entries,
    nodes = state.nodes,
    closeButton = state.closeButton,
    SetVisible = SetVisible,
    Show = Show,
  }
end

function PortalNavigatorNotice.Create(opts, deps)
  assert(type(deps) == "table", "isiLive: portal navigator dependencies missing")
  local config = BuildConfig(opts)
  local frame = CreateFrameRoot(config, deps)
  local eyebrowText = CreateEyebrow(frame, config, deps)
  local titleText = CreateTitle(frame, config, deps)
  local titleSeparator = CreateSeparator(frame, deps.colors)
  local closeButton = deps.createCloseButton(frame)
  local nodes = {
    left = CreateEntry(frame, config, "left", deps),
    half_left = CreateEntry(frame, config, "half_left", deps),
    center = CreateEntry(frame, config, "center", deps),
    half_right = CreateEntry(frame, config, "half_right", deps),
    right = CreateEntry(frame, config, "right", deps),
  }
  local state = {
    config = config,
    deps = deps,
    frame = frame,
    eyebrowText = eyebrowText,
    titleText = titleText,
    titleSeparator = titleSeparator,
    closeButton = closeButton,
    nodes = nodes,
    entries = {
      left = nodes.left.destination,
      half_left = nodes.half_left.destination,
      center = nodes.center.destination,
      half_right = nodes.half_right.destination,
      right = nodes.right.destination,
    },
  }

  local function Hide()
    state.frame:Hide()
  end

  frame:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then
      Hide()
    end
  end)
  closeButton:SetScript("OnClick", Hide)

  ClearEntries(state)
  return BuildController(state)
end
