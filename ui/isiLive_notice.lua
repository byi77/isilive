local _, addonTable = ...

addonTable = addonTable or {}

local Notice = {}
addonTable.Notice = Notice
local createRedCloseButton = assert(
  addonTable.UICommon and addonTable.UICommon.CreateRedCloseButton,
  "isiLive: UICommon.CreateRedCloseButton missing"
)
local createPrivateTooltip = assert(
  addonTable.UICommon and addonTable.UICommon.CreatePrivateTooltip,
  "isiLive: UICommon.CreatePrivateTooltip missing"
)
local preparePrivateTooltip = assert(
  addonTable.UICommon and addonTable.UICommon.PreparePrivateTooltip,
  "isiLive: UICommon.PreparePrivateTooltip missing"
)
local hidePrivateTooltip =
  assert(addonTable.UICommon and addonTable.UICommon.HidePrivateTooltip, "isiLive: UICommon.HidePrivateTooltip missing")

local NOTICE_TITLE_COLOR_R, NOTICE_TITLE_COLOR_G, NOTICE_TITLE_COLOR_B = 1, 0.9, 0.45
local NOTICE_GOLD_ACCENT_R, NOTICE_GOLD_ACCENT_G, NOTICE_GOLD_ACCENT_B = 1, 0.82, 0.25

-- Sandbox-safe GetTime read: WoW always exposes the global, but the test
-- _G can omit it. Falling back to 0 keeps endsAt arithmetic numeric on a
-- mocked _G; in WoW the function path is always taken.
local function CurrentTime()
  local getTimeFn = rawget(_G, "GetTime")
  return type(getTimeFn) == "function" and getTimeFn() or 0
end

local function ClampMovableFrameToScreen(frame)
  if type(frame) ~= "table" then
    return
  end
  if type(frame.SetClampedToScreen) == "function" then
    frame:SetClampedToScreen(true)
  end
  if type(frame.SetClampRectInsets) == "function" then
    frame:SetClampRectInsets(0, 0, 0, 0)
  end
end

local function BuildCenterNoticeConfig(opts)
  opts = opts or {}
  local frameName = type(opts.frameName) == "string" and opts.frameName ~= "" and opts.frameName
    or "isiLiveCenterNotice"
  return {
    parent = opts.parent or UIParent,
    frameName = frameName,
    teleportButtonName = type(opts.teleportButtonName) == "string"
        and opts.teleportButtonName ~= ""
        and opts.teleportButtonName
      or (frameName .. "TeleportButton"),
    minHeight = tonumber(opts.minHeight) or 70,
    maxHeight = tonumber(opts.maxHeight) or 220,
    yOffset = tonumber(opts.yOffset) or 0,
    paddingX = tonumber(opts.paddingX) or 20,
    paddingY = tonumber(opts.paddingY) or 12,
    buttonHeight = tonumber(opts.buttonHeight) or 56,
    buttonGap = tonumber(opts.buttonGap) or 8,
    fontDelta = tonumber(opts.fontDelta) or 10,
    isInCombat = opts.isInCombat or function()
      local inCombatFn = rawget(_G, "InCombatLockdown")
      return type(inCombatFn) == "function" and inCombatFn() == true
    end,
    resolveTeleportSpellID = opts.resolveTeleportSpellID or function(_activityID, _dungeonName)
      return nil
    end,
    resolveTeleportSpellIDByMapID = opts.resolveTeleportSpellIDByMapID or function(_mapID)
      return nil
    end,
    resolveMapIDBySpellID = opts.resolveMapIDBySpellID or function(_spellID)
      return nil
    end,
    resolveMapIDByActivityID = opts.resolveMapIDByActivityID or function(_activityID)
      return nil
    end,
    applySecureSpellToButton = opts.applySecureSpellToButton or function(_button, _spellID)
      return false
    end,
    isSpellKnown = opts.isSpellKnown or function(_spellID)
      return false
    end,
    getTeleportCooldownRemaining = opts.getTeleportCooldownRemaining or function(_spellID)
      return 0
    end,
    formatCooldownSeconds = opts.formatCooldownSeconds or function(sec)
      return tostring(sec or 0)
    end,
    getDungeonName = opts.getDungeonName or function(_mapID, _localeTag)
      return nil
    end,
    getL = opts.getL or function()
      return {}
    end,
  }
end

local function BuildPortalNavigatorConfig(opts)
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
    paddingX = tonumber(opts.paddingX) or 24,
    paddingY = tonumber(opts.paddingY) or 14,
    entryWidth = tonumber(opts.entryWidth) or 180,
  }
end

local function CreateCenterNoticeFrame(config)
  local frame = CreateFrame("Frame", config.frameName, config.parent, "BackdropTemplate")
  frame:SetSize(680, config.minHeight)
  frame:SetPoint("CENTER", config.parent, "CENTER", 0, config.yOffset)
  frame:SetMovable(true)
  ClampMovableFrameToScreen(frame)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:Hide()
  frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
  end)

  local UICommon = addonTable and addonTable.UICommon
  if not (type(UICommon) == "table" and UICommon.ApplyBackdrop and UICommon.ApplyBackdrop(frame, "NOTICE")) then
    if type(frame.CreateTexture) == "function" then
      local bg = frame:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      bg:SetColorTexture(0.05, 0.05, 0.08, 0.75)
    end
  end
  return frame
end

local function CreatePortalNavigatorFrame(config)
  local frame = CreateFrame("Frame", config.frameName, config.parent, "BackdropTemplate")
  frame:SetSize(config.width, config.height)
  frame:SetPoint("CENTER", config.parent, "CENTER", 0, config.yOffset)
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  ClampMovableFrameToScreen(frame)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:Hide()
  frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
  end)

  local UICommon = addonTable and addonTable.UICommon
  if not (type(UICommon) == "table" and UICommon.ApplyBackdrop and UICommon.ApplyBackdrop(frame, "NOTICE")) then
    if type(frame.CreateTexture) == "function" then
      local bg = frame:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      bg:SetColorTexture(0.05, 0.05, 0.08, config.backgroundAlpha)
    end
  elseif type(frame.SetBackdropColor) == "function" then
    frame:SetBackdropColor(0.05, 0.05, 0.08, config.backgroundAlpha)
  end
  if type(frame.SetAlpha) == "function" then
    frame:SetAlpha(config.frameAlpha)
  end
  return frame
end

local function IncreaseFontSize(fontString, delta)
  local numericDelta = tonumber(delta) or 0
  if numericDelta <= 0 then
    return
  end
  if
    type(fontString) ~= "table"
    or type(fontString.GetFont) ~= "function"
    or type(fontString.SetFont) ~= "function"
  then
    return
  end

  local fontPath, fontSize, fontFlags = fontString:GetFont()
  local numericSize = tonumber(fontSize)
  if not fontPath or not numericSize then
    return
  end

  fontString:SetFont(fontPath, numericSize + numericDelta, fontFlags)
end

local function CreatePortalNavigatorTitle(frame, config)
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  IncreaseFontSize(title, config.fontDelta)
  title:SetPoint("TOP", frame, "TOP", 0, -12)
  title:SetJustifyH("CENTER")
  title:SetJustifyV("TOP")
  title:SetTextColor(NOTICE_TITLE_COLOR_R, NOTICE_TITLE_COLOR_G, NOTICE_TITLE_COLOR_B)
  return title
end

local function CreatePortalNavigatorSeparator(frame)
  if type(frame.CreateTexture) ~= "function" then
    return
  end
  local sep = frame:CreateTexture(nil, "ARTWORK")
  sep:SetHeight(1)
  sep:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -46)
  sep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -46)
  sep:SetColorTexture(NOTICE_GOLD_ACCENT_R, NOTICE_GOLD_ACCENT_G, NOTICE_GOLD_ACCENT_B, 0.35)
end

local PORTAL_NAVIGATOR_SLOT_POINTS = {
  left = { point = "TOPLEFT", x = 36, y = -126, iconX = 0, iconY = -6 },
  half_left = { point = "TOPLEFT", x = 178, y = -86, iconX = 0, iconY = -6 },
  center = { point = "TOP", x = 0, y = -66, iconX = 0, iconY = -6 },
  half_right = { point = "TOPRIGHT", x = -178, y = -86, iconX = 0, iconY = -6 },
  right = { point = "TOPRIGHT", x = -36, y = -126, iconX = 0, iconY = -6 },
}

local PORTAL_NAVIGATOR_SLOT_ORDER = { "left", "half_left", "center", "half_right", "right" }

local function CreatePortalStyleBodyText(frame, config)
  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  IncreaseFontSize(text, config.fontDelta)
  text:SetTextColor(1, 0.92, 0.7)
  return text
end

local function CreatePortalNavigatorEntry(frame, config, slot)
  local text = CreatePortalStyleBodyText(frame, config)
  local pointDef = PORTAL_NAVIGATOR_SLOT_POINTS[slot] or PORTAL_NAVIGATOR_SLOT_POINTS.left

  local direction = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  IncreaseFontSize(direction, math.max(0, math.floor((tonumber(config.fontDelta) or 0) / 2)))
  direction:SetWidth(config.entryWidth)
  direction:SetJustifyH("CENTER")
  direction:SetJustifyV("TOP")
  direction:SetWordWrap(false)
  if direction.SetNonSpaceWrap then
    direction:SetNonSpaceWrap(false)
  end
  direction:SetTextColor(0.38, 0.92, 1)
  direction:SetPoint(pointDef.point, frame, pointDef.point, pointDef.x, pointDef.y)

  local iconBg = frame:CreateTexture(nil, "BACKGROUND")
  if type(iconBg.SetSize) == "function" then
    iconBg:SetSize(44, 44)
  end
  iconBg:SetPoint("TOP", direction, "BOTTOM", pointDef.iconX, pointDef.iconY)
  iconBg:SetColorTexture(0.05, 0.2, 0.34, 0.65)

  local iconCore = frame:CreateTexture(nil, "ARTWORK")
  if type(iconCore.SetSize) == "function" then
    iconCore:SetSize(40, 40)
  end
  iconCore:SetPoint("CENTER", iconBg, "CENTER", 0, 0)
  iconCore:SetColorTexture(0.1, 0.45, 1, 0.92)

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
  detail:SetTextColor(0.62, 0.68, 0.76)
  detail:SetPoint("TOP", text, "BOTTOM", 0, -2)

  return {
    direction = direction,
    destination = text,
    detail = detail,
    iconBg = iconBg,
    iconCore = iconCore,
  }
end

local function SetPortalNavigatorIconTexture(iconFrame, icon)
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

local function SetPortalNavigatorIconColor(iconFrame, r, g, b, a)
  if type(iconFrame) ~= "table" then
    return
  end
  SetPortalNavigatorIconTexture(iconFrame, nil)
  if type(iconFrame.SetColorTexture) == "function" then
    iconFrame:SetColorTexture(r, g, b, a)
  end
end

local function ClearPortalNavigatorEntries(state)
  state.titleText:SetText("")
  for _, slot in ipairs(PORTAL_NAVIGATOR_SLOT_ORDER) do
    local entry = state.nodes[slot]
    if entry then
      entry.direction:SetText("")
      entry.destination:SetText("")
      entry.detail:SetText("")
      entry.iconBg:SetColorTexture(0.05, 0.2, 0.34, 0.65)
      SetPortalNavigatorIconColor(entry.iconCore, 0.1, 0.45, 1, 0.92)
    end
  end
end

local function ApplyPortalNavigatorLayout(state, layout)
  if type(layout) ~= "table" then
    ClearPortalNavigatorEntries(state)
    return false
  end

  local title = type(layout.title) == "string" and layout.title or ""
  if title == "" then
    ClearPortalNavigatorEntries(state)
    return false
  end

  state.titleText:SetText(title)

  local entryMap = {}
  for _, entry in ipairs(layout.entries or {}) do
    if type(entry) == "table" and type(entry.slot) == "string" then
      entryMap[entry.slot] = entry
    end
  end

  for _, slot in ipairs(PORTAL_NAVIGATOR_SLOT_ORDER) do
    local node = state.nodes[slot]
    local entry = entryMap[slot]
    if node and entry then
      node.direction:SetText("")
      node.destination:SetText(tostring(entry.destination or ""))
      node.detail:SetText("")
      if entry.isEmpty == true then
        node.iconBg:SetColorTexture(0.13, 0.15, 0.18, 0.55)
        SetPortalNavigatorIconColor(node.iconCore, 0.36, 0.4, 0.46, 0.78)
      else
        node.iconBg:SetColorTexture(0.05, 0.2, 0.34, 0.65)
        if type(entry.icon) == "string" or type(entry.icon) == "number" then
          SetPortalNavigatorIconTexture(node.iconCore, entry.icon)
        else
          SetPortalNavigatorIconColor(node.iconCore, 0.1, 0.45, 1, 0.92)
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

local function CreateCenterNoticeText(frame, config)
  local text = CreatePortalStyleBodyText(frame, config)
  text:SetPoint("TOPLEFT", frame, "TOPLEFT", config.paddingX, -config.paddingY)
  text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -config.paddingX, config.paddingY)
  text:SetJustifyH("CENTER")
  text:SetJustifyV("MIDDLE")
  text:SetWordWrap(true)
  if text.SetNonSpaceWrap then
    text:SetNonSpaceWrap(true)
  end
  return text
end

local function CreateCenterNoticeSubline(frame, config, position)
  local subline = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  -- Subline font is intentionally smaller than the main text: only half the
  -- standard fontDelta is applied so the subline reads as secondary metadata,
  -- not a competing headline.
  IncreaseFontSize(subline, math.max(0, math.floor((tonumber(config.fontDelta) or 0) / 2)))
  subline:SetJustifyH("CENTER")
  subline:SetJustifyV("MIDDLE")
  subline:SetWordWrap(false)
  if subline.SetNonSpaceWrap then
    subline:SetNonSpaceWrap(false)
  end
  if position == "top" then
    -- Warm gold for "Joined" / status banners — matches PortalNavigator title color.
    subline:SetTextColor(NOTICE_GOLD_ACCENT_R, NOTICE_GOLD_ACCENT_G, NOTICE_GOLD_ACCENT_B)
  else
    -- Muted grey for secondary context (group name, etc.).
    subline:SetTextColor(0.7, 0.7, 0.7)
  end
  subline:Hide()
  return subline
end

-- Rich-layout primitives for the post-accept invite info card. Pre-allocated
-- at frame creation; hidden by default. Show paths set their text and
-- visibility per-Show call. Anchored dynamically inside
-- ApplyCenterNoticeRichLayout.

local function CreateCenterNoticeTitle(frame, config)
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  -- Title sits above the separator and announces the notice category. Sized
  -- a touch larger than the body fontDelta so it reads as the dominant header.
  IncreaseFontSize(title, tonumber(config.fontDelta) or 0)
  title:SetJustifyH("CENTER")
  title:SetJustifyV("MIDDLE")
  title:SetWordWrap(false)
  if title.SetNonSpaceWrap then
    title:SetNonSpaceWrap(false)
  end
  title:SetTextColor(NOTICE_TITLE_COLOR_R, NOTICE_TITLE_COLOR_G, NOTICE_TITLE_COLOR_B)
  title:Hide()
  return title
end

local function CreateCenterNoticeTitleSeparator(frame)
  if type(frame.CreateTexture) ~= "function" then
    return nil
  end
  local sep = frame:CreateTexture(nil, "ARTWORK")
  sep:SetHeight(1)
  sep:SetColorTexture(0.36, 0.71, 1, 0.55)
  sep:Hide()
  return sep
end

local function CreateCenterNoticeEyebrow(frame, config)
  local eyebrow = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  IncreaseFontSize(eyebrow, math.max(0, math.floor((tonumber(config.fontDelta) or 0) / 3)))
  eyebrow:SetJustifyH("LEFT")
  eyebrow:SetJustifyV("TOP")
  eyebrow:SetWordWrap(false)
  if eyebrow.SetNonSpaceWrap then
    eyebrow:SetNonSpaceWrap(false)
  end
  eyebrow:SetTextColor(0.46, 0.94, 1)
  eyebrow:Hide()
  return eyebrow
end

local FIELD_LABEL_WIDTH = 144
local MAX_FIELD_ROWS = 4
local FIELD_LABEL_R, FIELD_LABEL_G, FIELD_LABEL_B = 0.62, 0.68, 0.76
local FIELD_VALUE_R, FIELD_VALUE_G, FIELD_VALUE_B = 0.94, 0.96, 0.99
local FIELD_WARNING_R, FIELD_WARNING_G, FIELD_WARNING_B = 1, 0.16, 0.12
local RICH_TELEPORT_BUTTON_WIDTH = 170
local RICH_TELEPORT_BUTTON_MIN_HEIGHT = 104
local RICH_TELEPORT_ICON_INSET = 14
local RICH_TELEPORT_BUTTON_RIGHT_INSET = 24

local function CreateCenterNoticeFieldRow(frame, config)
  local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  IncreaseFontSize(label, math.max(0, math.floor((tonumber(config.fontDelta) or 0) / 2)))
  label:SetJustifyH("LEFT")
  label:SetJustifyV("TOP")
  label:SetWordWrap(false)
  if label.SetNonSpaceWrap then
    label:SetNonSpaceWrap(false)
  end
  label:SetTextColor(FIELD_LABEL_R, FIELD_LABEL_G, FIELD_LABEL_B)
  label:SetWidth(FIELD_LABEL_WIDTH)
  label:Hide()

  local value = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  IncreaseFontSize(value, math.max(0, math.floor((tonumber(config.fontDelta) or 0) / 2)))
  value:SetJustifyH("LEFT")
  value:SetJustifyV("TOP")
  value:SetWordWrap(true)
  if value.SetNonSpaceWrap then
    value:SetNonSpaceWrap(false)
  end
  value:SetTextColor(FIELD_VALUE_R, FIELD_VALUE_G, FIELD_VALUE_B)
  value:Hide()

  return { label = label, value = value }
end

local function CreateCenterNoticeTeleportHeader(frame, config)
  local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  IncreaseFontSize(header, math.max(0, math.floor((tonumber(config.fontDelta) or 0) / 2)))
  header:SetJustifyH("CENTER")
  header:SetJustifyV("MIDDLE")
  header:SetWordWrap(false)
  if header.SetNonSpaceWrap then
    header:SetNonSpaceWrap(false)
  end
  header:SetTextColor(NOTICE_GOLD_ACCENT_R, NOTICE_GOLD_ACCENT_G, NOTICE_GOLD_ACCENT_B)
  header:Hide()
  return header
end

local function CreateCenterNoticeCloseButton(frame)
  return createRedCloseButton(frame, {
    point = { "TOPRIGHT", frame, "TOPRIGHT", -2, -2 },
    frameLevel = frame:GetFrameLevel() + 20,
  })
end

local function CreateCenterNoticeTeleportButton(frame, config)
  -- Use insecure action template so center notice can still be shown/hidden in combat.
  local button = CreateFrame("Button", config.teleportButtonName, frame, "InsecureActionButtonTemplate")
  button:SetSize(config.buttonHeight, config.buttonHeight)
  button:SetPoint("TOP", frame, "TOP", 0, -(config.paddingY + 26 + config.buttonGap))
  button:Hide()
  button:EnableMouse(true)
  button.spellID = nil
  button.inCombatBlocked = false
  button:RegisterForClicks("AnyDown", "AnyUp")
  button:SetFrameStrata("HIGH")
  button:SetFrameLevel(frame:GetFrameLevel() + 10)
  button:SetAttribute("type", "spell")
  button:SetAttribute("type1", "spell")
  button:SetAttribute("*type1", "spell")
  button:SetAttribute("useOnKeyDown", true)
  button:SetAttribute("spell", 0)
  button:SetAttribute("spell1", 0)
  button.actionBg = button:CreateTexture(nil, "BACKGROUND")
  if type(button.actionBg.SetSize) == "function" then
    button.actionBg:SetSize(config.buttonHeight + 8, config.buttonHeight + 8)
  end
  button.actionBg:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.actionBg:SetColorTexture(0.04, 0.18, 0.32, 0.62)
  button.icon = button:CreateTexture(nil, "ARTWORK")
  if type(button.icon.SetSize) == "function" then
    button.icon:SetSize(config.buttonHeight, config.buttonHeight)
  end
  button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  button.overlay = button:CreateTexture(nil, "OVERLAY")
  button.overlay:SetAllPoints()
  button.overlay:SetColorTexture(0, 0, 0, 0)
  button.cooldownText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.cooldownText:SetPoint("TOP", button, "TOP", 0, -4)
  button.cooldownText:SetTextColor(1, 1, 1)
  button.cooldownText:Hide()

  button.hoverGlow = button:CreateTexture(nil, "BACKGROUND")
  if type(button.hoverGlow.SetPoint) == "function" then
    button.hoverGlow:SetPoint("TOPLEFT", button, "TOPLEFT", -4, 4)
    button.hoverGlow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, -4)
  end
  if type(button.hoverGlow.SetColorTexture) == "function" then
    button.hoverGlow:SetColorTexture(0.3, 0.65, 1, 0.2)
  end
  if type(button.hoverGlow.Hide) == "function" then
    button.hoverGlow:Hide()
  end

  return button
end

local function ResetCenterNoticeToDefaultPosition(state)
  state.frame:ClearAllPoints()
  state.frame:SetPoint("CENTER", state.config.parent, "CENTER", 0, state.config.yOffset)
end

local function SetCenterNoticeVisible(state, visible)
  -- Opening/closing must always be possible, even in combat/in-key.
  if visible then
    if not state.frame:IsShown() then
      -- Center notice position is intentionally non-persistent.
      ResetCenterNoticeToDefaultPosition(state)
      state.frame:Show()
    end
    return
  end
  if state.frame:IsShown() then
    state.frame:Hide()
  end
  if state.teleportButton:IsShown() then
    state.teleportButton:Hide()
  end
  if state.teleportButton.cooldownText then
    state.teleportButton.cooldownText:Hide()
  end
end

local function UpdateCenterNoticeTeleportButtonVisual(state, spellID, isEnabled, inCombatBlocked)
  local icon
  if spellID and C_Spell and C_Spell.GetSpellTexture then
    icon = C_Spell.GetSpellTexture(spellID)
  end
  if not icon then
    icon = "Interface\\Icons\\INV_Misc_QuestionMark"
  end
  state.teleportButton.icon:SetTexture(icon)

  if inCombatBlocked then
    state.teleportButton.overlay:SetColorTexture(0.4, 0.05, 0.05, 0.55)
  elseif not isEnabled then
    state.teleportButton.overlay:SetColorTexture(0, 0, 0, 0.6)
  else
    state.teleportButton.overlay:SetColorTexture(0, 0, 0, 0)
  end
end

local function SetCenterNoticeTeleportButtonVisible(state, visible)
  local shouldShow = visible and true or false

  if state.config.isInCombat() then
    state.pendingTeleportButtonVisible = shouldShow
    return
  end

  state.pendingTeleportButtonVisible = nil
  if shouldShow then
    if not state.teleportButton:IsShown() then
      state.teleportButton:Show()
    end
    return
  end

  if state.teleportButton:IsShown() then
    state.teleportButton:Hide()
  end
end

local function SetCenterNoticeTeleportButtonMouseEnabled(state, enabled)
  local shouldEnableMouse = enabled and true or false

  if state.config.isInCombat() then
    state.pendingTeleportButtonMouseEnabled = shouldEnableMouse
    return
  end

  state.pendingTeleportButtonMouseEnabled = nil
  state.teleportButton:EnableMouse(shouldEnableMouse)
end

local function SetCenterNoticeTeleportButtonAnchor(state, yOffset, point, relativePoint, xOffset)
  if state.config.isInCombat() then
    state.pendingTeleportButtonAnchor = {
      point = point or "TOP",
      relativePoint = relativePoint or "TOP",
      xOffset = tonumber(xOffset) or 0,
      yOffset = yOffset,
    }
    return
  end

  state.pendingTeleportButtonAnchor = nil
  state.teleportButton:ClearAllPoints()
  state.teleportButton:SetPoint(point or "TOP", state.frame, relativePoint or "TOP", tonumber(xOffset) or 0, yOffset)
end

local function SetCenterNoticeTeleportButtonSize(state, width, height, iconSize)
  local buttonWidth = math.max(1, tonumber(width) or state.config.buttonHeight)
  local buttonHeight = math.max(1, tonumber(height) or buttonWidth)
  local iconDimension = math.max(1, tonumber(iconSize) or math.min(buttonWidth, buttonHeight))
  if state.config.isInCombat() then
    state.pendingTeleportButtonSize = {
      width = buttonWidth,
      height = buttonHeight,
      iconSize = iconDimension,
    }
    return
  end

  state.pendingTeleportButtonSize = nil
  state.teleportButton:SetSize(buttonWidth, buttonHeight)
  if state.teleportButton.actionBg and type(state.teleportButton.actionBg.ClearAllPoints) == "function" then
    state.teleportButton.actionBg:ClearAllPoints()
    state.teleportButton.actionBg:SetPoint("CENTER", state.teleportButton, "CENTER", 0, 0)
  end
  if state.teleportButton.actionBg and type(state.teleportButton.actionBg.SetSize) == "function" then
    state.teleportButton.actionBg:SetSize(iconDimension + 8, iconDimension + 8)
  end
  if state.teleportButton.icon and type(state.teleportButton.icon.ClearAllPoints) == "function" then
    state.teleportButton.icon:ClearAllPoints()
    state.teleportButton.icon:SetPoint("CENTER", state.teleportButton, "CENTER", 0, 0)
  end
  if state.teleportButton.icon and type(state.teleportButton.icon.SetSize) == "function" then
    state.teleportButton.icon:SetSize(iconDimension, iconDimension)
  end
  if state.teleportButton.overlay and type(state.teleportButton.overlay.ClearAllPoints) == "function" then
    state.teleportButton.overlay:ClearAllPoints()
    state.teleportButton.overlay:SetPoint("TOPLEFT", state.teleportButton, "TOPLEFT", 0, 0)
    state.teleportButton.overlay:SetPoint("BOTTOMRIGHT", state.teleportButton, "BOTTOMRIGHT", 0, 0)
  end
  if state.teleportButton.cooldownText and type(state.teleportButton.cooldownText.ClearAllPoints) == "function" then
    state.teleportButton.cooldownText:ClearAllPoints()
    state.teleportButton.cooldownText:SetPoint("TOP", state.teleportButton.icon or state.teleportButton, "TOP", 0, -4)
  end
end

local function ClearCenterNoticeTeleportButton(state)
  SetCenterNoticeTeleportButtonVisible(state, false)
  state.pendingTeleportButtonAnchor = nil
  state.pendingTeleportButtonSize = nil
  SetCenterNoticeTeleportButtonSize(
    state,
    state.config.buttonHeight,
    state.config.buttonHeight,
    state.config.buttonHeight
  )
  state.teleportButton.spellID = nil
  state.teleportButton.mapID = nil
  state.teleportButton.dungeonName = nil
  state.teleportButton.inCombatBlocked = false
  SetCenterNoticeTeleportButtonMouseEnabled(state, true)
end

local function ConfigureCenterNoticeTeleportButton(state, dungeonName, activityID, mapID)
  local hasDungeonName = type(dungeonName) == "string" and dungeonName ~= ""
  local numericActivityID = tonumber(activityID)
  if numericActivityID and numericActivityID <= 0 then
    numericActivityID = nil
  end
  local numericMapID = tonumber(mapID)
  if numericMapID and numericMapID <= 0 then
    numericMapID = nil
  end

  if not hasDungeonName and not numericActivityID and not numericMapID then
    ClearCenterNoticeTeleportButton(state)
    return false
  end

  local spellID
  if numericMapID then
    spellID = state.config.resolveTeleportSpellIDByMapID(numericMapID)
  elseif numericActivityID then
    spellID = state.config.resolveTeleportSpellID(numericActivityID, hasDungeonName and dungeonName or nil)
  else
    spellID = state.config.resolveTeleportSpellID(nil, hasDungeonName and dungeonName or nil)
  end
  if not spellID then
    ClearCenterNoticeTeleportButton(state)
    return false
  end
  local resolvedMapID
  if numericMapID then
    resolvedMapID = numericMapID
  elseif numericActivityID then
    resolvedMapID = state.config.resolveMapIDByActivityID(numericActivityID)
  else
    resolvedMapID = state.config.resolveMapIDBySpellID(spellID)
  end

  if state.config.isInCombat() then
    state.teleportButton.spellID = spellID
    state.teleportButton.mapID = tonumber(resolvedMapID)
    state.teleportButton.dungeonName = hasDungeonName and dungeonName or nil
    state.teleportButton.inCombatBlocked = true
    SetCenterNoticeTeleportButtonMouseEnabled(state, false)
    UpdateCenterNoticeTeleportButtonVisual(state, spellID, false, true)
    SetCenterNoticeTeleportButtonVisible(state, true)
    return true
  end

  state.config.applySecureSpellToButton(state.teleportButton, spellID)
  state.teleportButton.spellID = spellID
  state.teleportButton.mapID = tonumber(resolvedMapID)
  state.teleportButton.dungeonName = hasDungeonName and dungeonName or nil
  state.teleportButton.inCombatBlocked = false
  SetCenterNoticeTeleportButtonMouseEnabled(state, true)
  local known = state.config.isSpellKnown(spellID)
  state.teleportButton:Enable()
  UpdateCenterNoticeTeleportButtonVisual(state, spellID, known, false)
  SetCenterNoticeTeleportButtonVisible(state, true)
  return true
end

local function ApplyCenterNoticeFontScale(state, showOptions)
  local fontScale = tonumber(showOptions.fontScale) or 1
  if fontScale < 0.8 then
    fontScale = 0.8
  elseif fontScale > 2 then
    fontScale = 2
  end

  local fontPath = state.baseFontPath
  local baseSize = state.baseFontSize
  local fontFlags = state.baseFontFlags
  if not fontPath or not baseSize then
    fontPath, baseSize, fontFlags = state.text:GetFont()
    baseSize = tonumber(baseSize)
  end
  if fontPath and baseSize then
    state.text:SetFont(fontPath, math.floor(baseSize * fontScale), fontFlags)
  end
end

local function ApplyCenterNoticeTextColor(state, showOptions)
  if type(showOptions.textColor) == "table" then
    state.baseTextR = tonumber(showOptions.textColor[1]) or state.baseTextR
    state.baseTextG = tonumber(showOptions.textColor[2]) or state.baseTextG
    state.baseTextB = tonumber(showOptions.textColor[3]) or state.baseTextB
  else
    state.baseTextR, state.baseTextG, state.baseTextB = 1, 0.92, 0.7
  end
  state.text:SetTextColor(state.baseTextR, state.baseTextG, state.baseTextB)
end

local SUBLINE_GAP = 4

local function ApplyCenterNoticeSubline(fontString, content)
  if type(content) == "string" and content ~= "" then
    fontString:SetText(content)
    fontString:Show()
    return true
  end
  fontString:SetText("")
  fontString:Hide()
  return false
end

local function ApplyLegacyCenterNoticeLayout(state, message, hasTeleportButton)
  state.text:ClearAllPoints()
  state.text:SetPoint("TOPLEFT", state.frame, "TOPLEFT", state.config.paddingX, -state.config.paddingY)
  state.text:SetPoint("BOTTOMRIGHT", state.frame, "BOTTOMRIGHT", -state.config.paddingX, state.config.paddingY)
  state.text:SetText(message)
  state.text:SetWidth(state.frame:GetWidth() - (state.config.paddingX * 2))
  local textHeight = state.text:GetStringHeight() or 0

  local extraHeight = hasTeleportButton and (state.config.buttonHeight + state.config.buttonGap) or 0
  local frameHeight = math.min(
    state.config.maxHeight,
    math.max(state.config.minHeight, math.ceil(textHeight + (state.config.paddingY * 2) + extraHeight))
  )
  state.frame:SetHeight(frameHeight)

  if hasTeleportButton then
    SetCenterNoticeTeleportButtonSize(state, state.config.buttonHeight)
    -- Place button below center: half text height down + gap
    local textOffsetDown = math.ceil(textHeight / 2) + state.config.buttonGap
    SetCenterNoticeTeleportButtonAnchor(state, -textOffsetDown)
  end
end

-- Stack layout for sublines: vertical pile of [paddingY] [topSubline] [text]
-- [bottomSubline] [teleport button]. Each item has its own anchor relative to
-- frame TOP, so the stack is stable when the frame height is recomputed.
local function ApplyCenterNoticeStackLayout(state, message, hasSublineTop, hasSublineBottom, hasTeleportButton)
  local innerWidth = state.frame:GetWidth() - (state.config.paddingX * 2)

  if hasSublineTop then
    state.sublineTop:ClearAllPoints()
    state.sublineTop:SetPoint("TOP", state.frame, "TOP", 0, -state.config.paddingY)
    state.sublineTop:SetWidth(innerWidth)
  end

  state.text:ClearAllPoints()
  state.text:SetText(message)
  state.text:SetWidth(innerWidth)
  local sublineTopHeight = hasSublineTop and (state.sublineTop:GetStringHeight() or 0) or 0
  local textTopOffset = state.config.paddingY + (hasSublineTop and (sublineTopHeight + SUBLINE_GAP) or 0)
  state.text:SetPoint("TOP", state.frame, "TOP", 0, -textTopOffset)
  local textHeight = state.text:GetStringHeight() or 0

  local sublineBottomHeight = 0
  if hasSublineBottom then
    state.sublineBottom:ClearAllPoints()
    state.sublineBottom:SetPoint("TOP", state.text, "BOTTOM", 0, -SUBLINE_GAP)
    state.sublineBottom:SetWidth(innerWidth)
    sublineBottomHeight = state.sublineBottom:GetStringHeight() or 0
  end

  local stackHeight = textTopOffset + textHeight + (hasSublineBottom and (SUBLINE_GAP + sublineBottomHeight) or 0)
  local extraHeight = hasTeleportButton and (state.config.buttonHeight + state.config.buttonGap) or 0
  local frameHeight = math.min(
    state.config.maxHeight,
    math.max(state.config.minHeight, math.ceil(stackHeight + state.config.paddingY + extraHeight))
  )
  state.frame:SetHeight(frameHeight)

  if hasTeleportButton then
    SetCenterNoticeTeleportButtonSize(state, state.config.buttonHeight)
    local buttonOffset = stackHeight + state.config.buttonGap
    SetCenterNoticeTeleportButtonAnchor(state, -buttonOffset)
  end
end

-- Hides every rich-layout primitive. Called on every Show invocation so that
-- subsequent stack-mode / legacy-mode renders do not leak title/separator/
-- field/teleport-header fragments from a previous rich render.
local function HideRichCenterNoticeElements(state)
  state.warningFieldRows = nil
  if state.titleText then
    state.titleText:Hide()
  end
  if state.titleSeparator then
    state.titleSeparator:Hide()
  end
  if state.eyebrowText then
    state.eyebrowText:Hide()
  end
  if state.teleportHeader then
    state.teleportHeader:Hide()
  end
  if type(state.fieldRows) == "table" then
    for _, row in ipairs(state.fieldRows) do
      if row.label then
        row.label:SetTextColor(FIELD_LABEL_R, FIELD_LABEL_G, FIELD_LABEL_B, 1)
        row.label:Hide()
      end
      if row.value then
        row.value:SetTextColor(FIELD_VALUE_R, FIELD_VALUE_G, FIELD_VALUE_B, 1)
        row.value:Hide()
      end
    end
  end
end

-- Rich info-card layout: structured text stays left/center while the teleport
-- button sits larger in the free right-side action area. Used by the post-accept
-- invite notice; the regular text body is hidden in this mode because the field
-- rows carry the structured payload instead.
local function ApplyCenterNoticeRichLayout(state, payload, hasTeleportButton)
  local innerWidth = state.frame:GetWidth() - (state.config.paddingX * 2)
  local paddingX = state.config.paddingX
  local paddingY = state.config.paddingY
  local lineGap = math.max(SUBLINE_GAP, 6)
  local sectionGap = lineGap * 2
  local actionReserve = hasTeleportButton and (RICH_TELEPORT_BUTTON_WIDTH + 28) or 0
  local contentWidth = math.max(220, innerWidth - actionReserve)

  -- Hide the regular text body — rich mode renders payload via field rows.
  state.text:ClearAllPoints()
  state.text:SetText("")
  state.text:Hide()

  local cursorY = paddingY + 2
  local actionTopY = nil
  local actionBottomY = nil
  state.warningFieldRows = nil
  state.warningBlinkTime = 0

  if type(payload.eyebrow) == "string" and payload.eyebrow ~= "" and state.eyebrowText then
    state.eyebrowText:ClearAllPoints()
    state.eyebrowText:SetPoint("TOPLEFT", state.frame, "TOPLEFT", paddingX, -cursorY)
    state.eyebrowText:SetWidth(contentWidth)
    state.eyebrowText:SetText(payload.eyebrow)
    state.eyebrowText:Show()
    cursorY = cursorY + (state.eyebrowText:GetStringHeight() or 0) + 2
  elseif state.eyebrowText then
    state.eyebrowText:SetText("")
    state.eyebrowText:Hide()
  end

  if type(payload.title) == "string" and payload.title ~= "" and state.titleText then
    actionTopY = cursorY
    state.titleText:ClearAllPoints()
    state.titleText:SetPoint("TOPLEFT", state.frame, "TOPLEFT", paddingX, -cursorY)
    state.titleText:SetWidth(contentWidth)
    state.titleText:SetJustifyH("LEFT")
    state.titleText:SetText(payload.title)
    state.titleText:Show()
    cursorY = cursorY + (state.titleText:GetStringHeight() or 0) + lineGap

    if state.titleSeparator then
      state.titleSeparator:ClearAllPoints()
      state.titleSeparator:SetPoint("TOPLEFT", state.frame, "TOPLEFT", paddingX, -cursorY)
      state.titleSeparator:SetPoint("TOPRIGHT", state.frame, "TOPLEFT", paddingX + contentWidth, -cursorY)
      state.titleSeparator:Show()
      cursorY = cursorY + 1 + sectionGap
    else
      cursorY = cursorY + sectionGap
    end
  end

  if type(payload.fields) == "table" then
    local valueWidth = math.max(40, contentWidth - FIELD_LABEL_WIDTH - lineGap)
    for i, row in ipairs(state.fieldRows) do
      local field = payload.fields[i]
      if i > MAX_FIELD_ROWS then
        break
      end
      if type(field) == "table" and type(field.label) == "string" and field.label ~= "" then
        local valueText = type(field.value) == "string" and field.value or ""
        local isWarning = field.warning == true
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", state.frame, "TOPLEFT", paddingX, -cursorY)
        row.label:SetText(field.label)
        if isWarning then
          row.label:SetTextColor(FIELD_WARNING_R, FIELD_WARNING_G, FIELD_WARNING_B, 1)
        else
          row.label:SetTextColor(FIELD_LABEL_R, FIELD_LABEL_G, FIELD_LABEL_B, 1)
        end
        row.label:Show()

        row.value:ClearAllPoints()
        row.value:SetPoint("TOPLEFT", state.frame, "TOPLEFT", paddingX + FIELD_LABEL_WIDTH + lineGap, -cursorY)
        row.value:SetWidth(valueWidth)
        row.value:SetText(valueText)
        if isWarning then
          row.value:SetTextColor(FIELD_WARNING_R, FIELD_WARNING_G, FIELD_WARNING_B, 1)
          if field.blink == true then
            state.warningFieldRows = state.warningFieldRows or {}
            state.warningFieldRows[#state.warningFieldRows + 1] = row
          end
        else
          row.value:SetTextColor(FIELD_VALUE_R, FIELD_VALUE_G, FIELD_VALUE_B, 1)
        end
        row.value:Show()

        local rowHeight = math.max(row.label:GetStringHeight() or 0, row.value:GetStringHeight() or 0)
        actionBottomY = cursorY + rowHeight
        cursorY = cursorY + rowHeight + lineGap
      end
    end
    cursorY = cursorY + lineGap
  end

  if type(payload.teleportLabel) == "string" and payload.teleportLabel ~= "" and state.teleportHeader then
    state.teleportHeader:ClearAllPoints()
    state.teleportHeader:SetPoint("TOPLEFT", state.frame, "TOPLEFT", paddingX, -cursorY)
    state.teleportHeader:SetWidth(contentWidth)
    state.teleportHeader:SetText(payload.teleportLabel)
    state.teleportHeader:Show()
    cursorY = cursorY + (state.teleportHeader:GetStringHeight() or 0) + lineGap
  end

  actionTopY = actionTopY or paddingY
  actionBottomY = actionBottomY or cursorY
  local richButtonHeight = math.max(RICH_TELEPORT_BUTTON_MIN_HEIGHT, math.ceil(actionBottomY - actionTopY))
  local richButtonCenterY = -(actionTopY + math.ceil(richButtonHeight / 2))
  local richIconSize = math.max(1, math.min(RICH_TELEPORT_BUTTON_WIDTH, richButtonHeight) - RICH_TELEPORT_ICON_INSET)
  local richButtonRequiredHeight = hasTeleportButton
      and math.abs(richButtonCenterY) + math.ceil(richButtonHeight / 2) + paddingY
    or 0
  local frameHeight = math.min(
    state.config.maxHeight,
    math.max(state.config.minHeight, richButtonRequiredHeight, math.ceil(cursorY + paddingY))
  )
  state.frame:SetHeight(frameHeight)

  if hasTeleportButton then
    SetCenterNoticeTeleportButtonSize(state, RICH_TELEPORT_BUTTON_WIDTH, richButtonHeight, richIconSize)
    SetCenterNoticeTeleportButtonAnchor(
      state,
      richButtonCenterY,
      "CENTER",
      "TOPRIGHT",
      -(RICH_TELEPORT_BUTTON_RIGHT_INSET + math.ceil(RICH_TELEPORT_BUTTON_WIDTH / 2))
    )
  end
end

local function ApplyCenterNoticeFrameWidth(state, showOptions)
  local requestedWidth = tonumber(showOptions.frameWidth)
  if requestedWidth and requestedWidth > 0 then
    state.frame:SetWidth(requestedWidth)
  else
    state.frame:SetWidth(680)
  end
end

local function ShowCenterNotice(state, message, durationSeconds, dungeonName, activityID, showOptions)
  showOptions = showOptions or {}
  state.isPersistent = showOptions.persistent == true
  state.isBlinking = showOptions.blink == true
  state.blinkTime = 0

  ApplyCenterNoticeFrameWidth(state, showOptions)
  ApplyCenterNoticeFontScale(state, showOptions)
  ApplyCenterNoticeTextColor(state, showOptions)

  local hasRich = (type(showOptions.title) == "string" and showOptions.title ~= "")
    or (type(showOptions.fields) == "table" and #showOptions.fields > 0)

  local hasTeleportButton =
    ConfigureCenterNoticeTeleportButton(state, dungeonName, activityID, showOptions.teleportMapID)

  if hasRich then
    -- Rich mode replaces sublines and the body text. Hide them explicitly so
    -- a previous Show in stack/legacy mode does not leak fragments through.
    ApplyCenterNoticeSubline(state.sublineTop, nil)
    ApplyCenterNoticeSubline(state.sublineBottom, nil)
    ApplyCenterNoticeRichLayout(state, showOptions, hasTeleportButton)
  else
    -- Non-rich modes never use the rich primitives; clear them defensively.
    HideRichCenterNoticeElements(state)
    if not state.text:IsShown() then
      state.text:Show()
    end

    local hasSublineTop = ApplyCenterNoticeSubline(state.sublineTop, showOptions.sublineTop)
    local hasSublineBottom = ApplyCenterNoticeSubline(state.sublineBottom, showOptions.sublineBottom)

    if hasSublineTop or hasSublineBottom then
      ApplyCenterNoticeStackLayout(state, message, hasSublineTop, hasSublineBottom, hasTeleportButton)
    else
      ApplyLegacyCenterNoticeLayout(state, message, hasTeleportButton)
    end
  end

  state.endsAt = state.isPersistent and math.huge or (CurrentTime() + (durationSeconds or 20))
  SetCenterNoticeVisible(state, true)
end

local function AttachCenterNoticeTeleportButtonScripts(state)
  state.teleportButton:SetScript("OnEnter", function(self)
    if self.hoverGlow and type(self.hoverGlow.Show) == "function" then
      self.hoverGlow:Show()
    end
    local L = state.config.getL() or {}
    local tooltip = preparePrivateTooltip(state.tooltip, self, "ANCHOR_TOP")
    if type(tooltip) ~= "table" then
      return
    end

    if self.inCombatBlocked then
      tooltip:SetText(L.BTN_TELEPORT, 1, 1, 1)
      tooltip:AddLine(L.TOOLTIP_TELEPORT_COMBAT, 1, 0.25, 0.25, true)
    elseif self.spellID and state.config.isSpellKnown(self.spellID) then
      if type(self.dungeonName) == "string" and self.dungeonName ~= "" then
        tooltip:SetText(self.dungeonName, 1, 1, 1)
        local englishDungeonName = nil
        if type(self.mapID) == "number" then
          englishDungeonName = state.config.getDungeonName(self.mapID, "enUS")
        end
        if
          type(englishDungeonName) == "string"
          and englishDungeonName ~= ""
          and englishDungeonName ~= self.dungeonName
        then
          tooltip:AddLine(englishDungeonName, 1, 1, 1, true)
        end
      else
        tooltip:SetSpellByID(self.spellID)
      end
      local remaining = state.config.getTeleportCooldownRemaining(self.spellID)
      if remaining > 0 then
        tooltip:AddLine(
          string.format(L.TOOLTIP_TELEPORT_COOLDOWN, state.config.formatCooldownSeconds(remaining)),
          1,
          0.82,
          0,
          true
        )
      else
        tooltip:AddLine(L.TOOLTIP_TELEPORT_READY, 0.3, 1, 0.3, true)
      end
    else
      tooltip:SetText(L.BTN_TELEPORT_LOCKED, 1, 1, 1)
      tooltip:AddLine(L.TOOLTIP_TELEPORT_LOCKED, 1, 0.25, 0.25, true)
    end
    tooltip:Show()
  end)

  -- The teleport-button cooldown text only needs sub-second resolution. Pre-throttle:
  -- this ran on every render frame (60–144 Hz) and called getTeleportCooldownRemaining
  -- + formatCooldownSeconds + SetText each time. 0.1s accumulator matches the same
  -- pattern as game/isiLive_mplus_timer.lua.
  state.teleportButton._cooldownTextAccum = 0
  state.teleportButton:SetScript("OnUpdate", function(self, elapsed)
    self._cooldownTextAccum = (self._cooldownTextAccum or 0) + (elapsed or 0)
    if self._cooldownTextAccum < 0.1 then
      return
    end
    self._cooldownTextAccum = 0

    if not self.spellID or not self:IsShown() then
      self.cooldownText:Hide()
      return
    end

    local remaining = state.config.getTeleportCooldownRemaining(self.spellID)
    if remaining > 0 then
      self.cooldownText:SetText(state.config.formatCooldownSeconds(remaining))
      self.cooldownText:Show()
      return
    end
    local L = state.config.getL() or {}
    self.cooldownText:SetText(L.CENTER_NOTICE_PORTAL_READY_LABEL or "Portal")
    self.cooldownText:Show()
  end)

  state.teleportButton:SetScript("OnLeave", function()
    if state.teleportButton.hoverGlow and type(state.teleportButton.hoverGlow.Hide) == "function" then
      state.teleportButton.hoverGlow:Hide()
    end
    hidePrivateTooltip(state.tooltip)
  end)
end

-- Apply the deferred teleport-button mutations that SetCenterNoticeTeleportButton*
-- captured while combat lockdown was active. Called from PLAYER_REGEN_ENABLED via
-- the controller's ApplyPendingTeleportButtonState entry point, NOT from OnUpdate
-- — the previous OnUpdate poll burned 60–144 nil-checks per second for state that
-- only changes at the combat-end edge.
local function ApplyPendingCenterNoticeTeleportButtonState(state)
  if state.config.isInCombat() then
    return
  end
  if state.pendingTeleportButtonAnchor ~= nil then
    local anchor = state.pendingTeleportButtonAnchor
    SetCenterNoticeTeleportButtonAnchor(state, anchor.yOffset, anchor.point, anchor.relativePoint, anchor.xOffset)
  end
  if state.pendingTeleportButtonSize ~= nil then
    local size = state.pendingTeleportButtonSize
    SetCenterNoticeTeleportButtonSize(state, size.width, size.height, size.iconSize)
  end
  if state.pendingTeleportButtonMouseEnabled ~= nil then
    SetCenterNoticeTeleportButtonMouseEnabled(state, state.pendingTeleportButtonMouseEnabled)
  end
  if state.pendingTeleportButtonVisible ~= nil then
    SetCenterNoticeTeleportButtonVisible(state, state.pendingTeleportButtonVisible)
  end
end

local function AttachCenterNoticeFrameScripts(state)
  state.frame:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then
      SetCenterNoticeVisible(state, false)
    end
  end)

  state.frame:SetScript("OnUpdate", function(_, elapsed)
    local isShown = state.frame:IsShown()
    if isShown then
      if state.isBlinking then
        state.blinkTime = state.blinkTime + (elapsed or 0)
        local wave = (math.sin(state.blinkTime * 3) + 1) * 0.5
        local alpha = 0.65 + (wave * 0.35)
        state.text:SetTextColor(state.baseTextR, state.baseTextG, state.baseTextB, alpha)
      else
        state.text:SetTextColor(state.baseTextR, state.baseTextG, state.baseTextB, 1)
      end
      if type(state.warningFieldRows) == "table" then
        state.warningBlinkTime = (state.warningBlinkTime or 0) + (elapsed or 0)
        local wave = (math.sin(state.warningBlinkTime * 6) + 1) * 0.5
        local alpha = 0.35 + (wave * 0.65)
        for _, row in ipairs(state.warningFieldRows) do
          if row.label then
            row.label:SetTextColor(FIELD_WARNING_R, FIELD_WARNING_G, FIELD_WARNING_B, alpha)
          end
          if row.value then
            row.value:SetTextColor(FIELD_WARNING_R, FIELD_WARNING_G, FIELD_WARNING_B, alpha)
          end
        end
      end
    end

    if not state.isPersistent and CurrentTime() >= state.endsAt then
      SetCenterNoticeVisible(state, false)
    end
  end)
end

local function BuildCenterNoticeController(state)
  local function SetVisible(visible)
    SetCenterNoticeVisible(state, visible)
  end

  local function Show(message, durationSeconds, dungeonName, activityID, showOptions)
    ShowCenterNotice(state, message, durationSeconds, dungeonName, activityID, showOptions)
  end

  local function ConfigureTeleportButton(dungeonName, activityID, mapID)
    return ConfigureCenterNoticeTeleportButton(state, dungeonName, activityID, mapID)
  end

  local function UpdateTeleportButtonVisual(spellID, isEnabled, inCombatBlocked)
    UpdateCenterNoticeTeleportButtonVisual(state, spellID, isEnabled, inCombatBlocked)
  end

  local function ApplyPendingTeleportButtonState()
    ApplyPendingCenterNoticeTeleportButtonState(state)
  end

  return {
    frame = state.frame,
    text = state.text,
    sublineTop = state.sublineTop,
    sublineBottom = state.sublineBottom,
    eyebrowText = state.eyebrowText,
    titleText = state.titleText,
    titleSeparator = state.titleSeparator,
    teleportHeader = state.teleportHeader,
    fieldRows = state.fieldRows,
    closeButton = state.closeButton,
    teleportButton = state.teleportButton,
    SetVisible = SetVisible,
    Show = Show,
    ConfigureTeleportButton = ConfigureTeleportButton,
    UpdateTeleportButtonVisual = UpdateTeleportButtonVisual,
    ApplyPendingTeleportButtonState = ApplyPendingTeleportButtonState,
  }
end

function Notice.CreateCenterNotice(opts)
  local config = BuildCenterNoticeConfig(opts)
  local frame = CreateCenterNoticeFrame(config)
  local text = CreateCenterNoticeText(frame, config)
  local baseFontPath, baseFontSize, baseFontFlags = text:GetFont()
  local closeButton = CreateCenterNoticeCloseButton(frame)
  local teleportButton = CreateCenterNoticeTeleportButton(frame, config)
  local sublineTop = CreateCenterNoticeSubline(frame, config, "top")
  local sublineBottom = CreateCenterNoticeSubline(frame, config, "bottom")
  local eyebrowText = CreateCenterNoticeEyebrow(frame, config)
  local titleText = CreateCenterNoticeTitle(frame, config)
  local titleSeparator = CreateCenterNoticeTitleSeparator(frame)
  local teleportHeader = CreateCenterNoticeTeleportHeader(frame, config)
  local fieldRows = {}
  for i = 1, MAX_FIELD_ROWS do
    fieldRows[i] = CreateCenterNoticeFieldRow(frame, config)
  end
  local state = {
    config = config,
    frame = frame,
    text = text,
    sublineTop = sublineTop,
    sublineBottom = sublineBottom,
    eyebrowText = eyebrowText,
    titleText = titleText,
    titleSeparator = titleSeparator,
    teleportHeader = teleportHeader,
    fieldRows = fieldRows,
    closeButton = closeButton,
    teleportButton = teleportButton,
    tooltip = createPrivateTooltip(frame),
    endsAt = 0,
    isPersistent = false,
    isBlinking = false,
    blinkTime = 0,
    baseTextR = 1,
    baseTextG = 0.82,
    baseTextB = 0,
    baseFontPath = baseFontPath,
    baseFontSize = tonumber(baseFontSize),
    baseFontFlags = baseFontFlags,
    pendingTeleportButtonMouseEnabled = nil,
    pendingTeleportButtonAnchor = nil,
    pendingTeleportButtonVisible = nil,
  }

  AttachCenterNoticeTeleportButtonScripts(state)
  AttachCenterNoticeFrameScripts(state)
  closeButton:SetScript("OnClick", function()
    SetCenterNoticeVisible(state, false)
  end)
  return BuildCenterNoticeController(state)
end

local function BuildPortalNavigatorController(state)
  local function ResetPortalNavigatorToConfiguredPosition()
    state.frame:ClearAllPoints()
    state.frame:SetPoint("CENTER", state.config.parent, "CENTER", 0, state.config.yOffset)
  end

  local function SetVisible(visible)
    if visible then
      if not state.frame:IsShown() then
        ResetPortalNavigatorToConfiguredPosition()
        state.frame:Show()
      end
      return
    end
    if state.frame:IsShown() then
      state.frame:Hide()
    end
  end

  local function Show(layout)
    if not ApplyPortalNavigatorLayout(state, layout) then
      SetVisible(false)
      return false
    end
    SetVisible(true)
    return true
  end

  return {
    frame = state.frame,
    titleText = state.titleText,
    entries = state.entries,
    nodes = state.nodes,
    closeButton = state.closeButton,
    SetVisible = SetVisible,
    Show = Show,
  }
end

function Notice.CreatePortalNavigatorNotice(opts)
  local config = BuildPortalNavigatorConfig(opts)
  local frame = CreatePortalNavigatorFrame(config)
  local titleText = CreatePortalNavigatorTitle(frame, config)
  CreatePortalNavigatorSeparator(frame)
  local closeButton = CreateCenterNoticeCloseButton(frame)
  local nodes = {
    left = CreatePortalNavigatorEntry(frame, config, "left"),
    half_left = CreatePortalNavigatorEntry(frame, config, "half_left"),
    center = CreatePortalNavigatorEntry(frame, config, "center"),
    half_right = CreatePortalNavigatorEntry(frame, config, "half_right"),
    right = CreatePortalNavigatorEntry(frame, config, "right"),
  }
  local entries = {
    left = nodes.left.destination,
    half_left = nodes.half_left.destination,
    center = nodes.center.destination,
    half_right = nodes.half_right.destination,
    right = nodes.right.destination,
  }
  local state = {
    config = config,
    frame = frame,
    titleText = titleText,
    closeButton = closeButton,
    nodes = nodes,
    entries = entries,
  }

  local function hidePortalNavigator()
    state.frame:Hide()
  end

  frame:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then
      hidePortalNavigator()
    end
  end)

  closeButton:SetScript("OnClick", hidePortalNavigator)

  ClearPortalNavigatorEntries(state)
  return BuildPortalNavigatorController(state)
end

function Notice.CreateInviteHint(opts)
  opts = opts or {}
  local parent = opts.parent or UIParent
  local mainFrameGlobalName = opts.mainFrameGlobalName or "isiLiveMainFrame"

  local frame = CreateFrame("Frame", "isiLiveInviteHintFrame", parent, "BackdropTemplate")
  frame:SetSize(420, 64)
  frame:Hide()
  frame:SetFrameStrata("DIALOG")

  local UICommon = addonTable and addonTable.UICommon
  if not (type(UICommon) == "table" and UICommon.ApplyBackdrop and UICommon.ApplyBackdrop(frame, "NOTICE")) then
    if type(frame.CreateTexture) == "function" then
      local bg = frame:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      bg:SetColorTexture(0.05, 0.05, 0.08, 0.75)
    end
  end

  -- Two-line layout: headline (dungeon + level) on top in larger / brighter
  -- gold, group title underneath in muted gold. Both share the same FontString
  -- with a "\n"-separated message so the caller stays simple.
  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  text:SetPoint("CENTER", 0, 0)
  text:SetJustifyH("CENTER")
  text:SetTextColor(1, 0.82, 0)
  if type(text.SetSpacing) == "function" then
    text:SetSpacing(2)
  end

  local endsAt = 0
  -- searchResultID this hint was rendered for. When the visible LFGListInviteDialog
  -- shows a *different* resultID (multiple parallel invites for the same dungeon,
  -- e.g. "+12/+13/+14" push-lobby variants), hide instead of confidently labeling
  -- the wrong listing. nil = hint is dialog-agnostic (legacy callers).
  local currentResultID = nil

  local function GetInviteDialog()
    local lfgListInviteDialog = rawget(_G, "LFGListInviteDialog")
    if lfgListInviteDialog and lfgListInviteDialog:IsShown() then
      return lfgListInviteDialog
    end
    return nil
  end

  local function GetInviteAnchorFrame()
    local lfgListInviteDialog = GetInviteDialog()
    if lfgListInviteDialog then
      return lfgListInviteDialog
    end
    local lfgDungeonReadyDialog = rawget(_G, "LFGDungeonReadyDialog")
    if lfgDungeonReadyDialog and lfgDungeonReadyDialog:IsShown() then
      return lfgDungeonReadyDialog
    end
    return nil
  end

  -- True when the visible LFGListInviteDialog references a *different*
  -- searchResultID than the one this hint was rendered for. Returns false in
  -- the dialog-agnostic case (currentResultID == nil) and when the dialog is
  -- not visible (other anchors like LFGDungeonReadyDialog or the main frame).
  local function IsHintMismatchedToVisibleDialog()
    if currentResultID == nil then
      return false
    end
    local dialog = GetInviteDialog()
    if not dialog then
      return false
    end
    local dialogResultID = rawget(dialog, "resultID") or rawget(dialog, "selectedResult")
    if dialogResultID == nil then
      return false
    end
    return dialogResultID ~= currentResultID
  end

  local function Position()
    if IsHintMismatchedToVisibleDialog() then
      frame:Hide()
      return
    end

    local anchor = GetInviteAnchorFrame()
    frame:ClearAllPoints()

    if anchor then
      frame:SetPoint("TOP", anchor, "BOTTOM", 0, -8)
      return
    end

    local globalMainFrame = rawget(_G, mainFrameGlobalName)
    if globalMainFrame and globalMainFrame:IsShown() then
      frame:SetPoint("TOP", globalMainFrame, "BOTTOM", 0, -8)
      return
    end

    frame:SetPoint("TOP", parent, "TOP", 0, -220)
  end

  local function Show(message, durationSeconds, searchResultID)
    currentResultID = searchResultID
    text:SetText(message)
    Position()
    endsAt = CurrentTime() + (durationSeconds or 10)
    if not IsHintMismatchedToVisibleDialog() then
      frame:Show()
    end
  end

  -- Position() reanchors the hint to the LFG dialog. It does not need to run at
  -- 60+ Hz — the dialog itself never moves faster than the user can drag it.
  -- endsAt + dialog-mismatch checks stay per-frame so the hint hides snappily.
  --
  -- Slice-race note: if Blizzard remounts LFGListInviteDialog between frames,
  -- IsHintMismatchedToVisibleDialog() can see a transient nil dialog.resultID
  -- and return false (no mismatch). The hint then stays visible for one frame
  -- on a dialog it might not actually belong to. This is acceptable: a 1-frame
  -- false-positive "show" is less disruptive than a 1-frame false-positive
  -- "hide" would be, and the next frame re-evaluates with the settled dialog.
  -- Do not throttle these checks under 0.2 s without first solving the race.
  local repositionAccum = 0
  frame:SetScript("OnUpdate", function(self, elapsed)
    if CurrentTime() >= endsAt then
      currentResultID = nil
      self:Hide()
      return
    end
    if IsHintMismatchedToVisibleDialog() then
      self:Hide()
      return
    end
    repositionAccum = repositionAccum + (elapsed or 0)
    if repositionAccum >= 0.2 then
      repositionAccum = 0
      Position()
    end
  end)

  return {
    frame = frame,
    Show = Show,
    Position = Position,
  }
end
