local _, addonTable = ...

addonTable = addonTable or {}

-- Lua 5.1 (WoW client) exposes global `unpack`; Lua 5.4 (local tooling) only
-- has `table.unpack`. Bridge locally so this file works under both without
-- depending on the entrypoint script to have set up a global compat shim.
local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

local Notice = {}
addonTable.Notice = Notice
local NoticeCommon = assert(addonTable.NoticeCommon, "isiLive: NoticeCommon missing")
local PortalNavigatorNotice = assert(addonTable.PortalNavigatorNotice, "isiLive: PortalNavigatorNotice missing")
local NoticeRichLayout = assert(addonTable.NoticeRichLayout, "isiLive: NoticeRichLayout missing")
local createCloseButton =
  assert(addonTable.UICommon and addonTable.UICommon.CreateCloseButton, "isiLive: UICommon.CreateCloseButton missing")
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
local Colors = addonTable.UICommon and addonTable.UICommon.Colors or {}
local SemanticUICommon = addonTable.UICommon
local ClampMovableFrameToScreen = NoticeCommon.ClampMovableFrameToScreen
local ApplyNoticeFrameLayer = NoticeCommon.ApplyFrameLayer
local IncreaseFontSize = NoticeCommon.IncreaseFontSize
local SetReadableText = NoticeCommon.SetReadableText
local CreatePortalStyleBodyText = NoticeCommon.CreateBodyText

-- Shared notice palette and layout constants live in NoticeRichLayout.
local NOTICE_TITLE_COLOR_R, NOTICE_TITLE_COLOR_G, NOTICE_TITLE_COLOR_B = unpack(NoticeRichLayout.TITLE_COLOR)
local NOTICE_GOLD_ACCENT_R, NOTICE_GOLD_ACCENT_G, NOTICE_GOLD_ACCENT_B = unpack(NoticeRichLayout.GOLD_ACCENT)
local FIELD_WARNING_R, FIELD_WARNING_G, FIELD_WARNING_B = unpack(NoticeRichLayout.FIELD_WARNING_COLOR)
local SUBLINE_GAP = NoticeRichLayout.SUBLINE_GAP
local RICH_TELEPORT_STATUS_FONT_DELTA = 4

-- Sandbox-safe GetTime read: WoW always exposes the global, but the test
-- _G can omit it. Falling back to 0 keeps endsAt arithmetic numeric on a
-- mocked _G; in WoW the function path is always taken.
local function CallIfPresent(target, methodName, ...)
  local method = type(target) == "table" and target[methodName] or nil
  if type(method) == "function" then
    return method(target, ...)
  end
  return nil
end

local function CurrentTime()
  local getTimeFn = rawget(_G, "GetTime")
  return type(getTimeFn) == "function" and getTimeFn() or 0
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
    frameStrata = type(opts.frameStrata) == "string" and opts.frameStrata ~= "" and opts.frameStrata or nil,
    frameLevel = tonumber(opts.frameLevel),
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
    -- Optional: without them the teleport button keeps its text-only cooldown.
    getCooldownFrameStartForRemaining = opts.getCooldownFrameStartForRemaining,
    applyCooldownFrameSafe = opts.applyCooldownFrameSafe,
    getDungeonName = opts.getDungeonName or function(_mapID, _localeTag)
      return nil
    end,
    getL = opts.getL or function()
      return {}
    end,
  }
end

local function CreateCenterNoticeFrame(config)
  local frame = CreateFrame("Frame", config.frameName, config.parent, "BackdropTemplate")
  frame:SetSize(680, config.minHeight)
  frame:SetPoint("CENTER", config.parent, "CENTER", 0, config.yOffset)
  ApplyNoticeFrameLayer(frame, config)
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
      bg:SetColorTexture(unpack(Colors.BG_NOTICE_CARD or { 0.05, 0.05, 0.08, 0.75 }))
    end
  end
  if type(UICommon) == "table" and type(UICommon.CreateNoticeChrome) == "function" then
    frame._isiLiveNoticeAccent = UICommon.CreateNoticeChrome(frame)
  end
  return frame
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
    subline:SetTextColor(unpack(Colors.GRAY_SUBLINE or { 0.7, 0.7, 0.7 }))
  end
  subline:Hide()
  return subline
end

local function CreateCenterNoticeCloseButton(frame)
  return createCloseButton(frame, {
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
  if type(button.SetFrameStrata) == "function" and type(frame.GetFrameStrata) == "function" then
    button:SetFrameStrata(frame:GetFrameStrata())
  end
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
  button.actionBg:SetColorTexture(unpack(Colors.BLUE_ACTION_BG or { 0.04, 0.18, 0.32, 0.62 }))
  button.icon = button:CreateTexture(nil, "ARTWORK")
  if type(button.icon.SetSize) == "function" then
    button.icon:SetSize(config.buttonHeight, config.buttonHeight)
  end
  button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  button.overlay = button:CreateTexture(nil, "OVERLAY")
  button.overlay:SetAllPoints()
  button.overlay:SetColorTexture(unpack(Colors.TRANSPARENT or { 0, 0, 0, 0 }))

  -- Cooldown swipe over the icon, like the portal grid. The status text sits
  -- on its own layer above the swipe, otherwise the swipe would cover it.
  local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  if type(cooldown) == "table" then
    CallIfPresent(cooldown, "SetAllPoints", button.icon)
    CallIfPresent(cooldown, "SetDrawEdge", false)
    CallIfPresent(cooldown, "SetHideCountdownNumbers", true)
    button.cooldown = cooldown
  end
  local textLayer = CreateFrame("Frame", nil, button)
  CallIfPresent(textLayer, "SetAllPoints", button)
  local cooldownLevel = CallIfPresent(cooldown, "GetFrameLevel")
  if type(cooldownLevel) == "number" then
    CallIfPresent(textLayer, "SetFrameLevel", cooldownLevel + 1)
  end
  local textParent = type(textLayer) == "table" and type(textLayer.CreateFontString) == "function" and textLayer
    or button
  button.cooldownText = textParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  IncreaseFontSize(button.cooldownText, RICH_TELEPORT_STATUS_FONT_DELTA)
  button.cooldownText:SetPoint("TOP", button, "TOP", 0, -4)
  button.cooldownText:SetTextColor(unpack(Colors.WHITE_RGB or { 1, 1, 1 }))
  button.cooldownText:Hide()

  button.hoverGlow = button:CreateTexture(nil, "BACKGROUND")
  if type(button.hoverGlow.SetPoint) == "function" then
    button.hoverGlow:SetPoint("TOPLEFT", button, "TOPLEFT", -4, 4)
    button.hoverGlow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, -4)
  end
  if type(button.hoverGlow.SetColorTexture) == "function" then
    button.hoverGlow:SetColorTexture(unpack(Colors.BLUE_HOVER_GLOW or { 0.3, 0.65, 1, 0.2 }))
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
    if state.centerNoticeOnUpdate then
      state.frame:SetScript("OnUpdate", state.centerNoticeOnUpdate)
    end
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
  state.frame:SetScript("OnUpdate", nil)
  if state.teleportButton:IsShown() then
    state.teleportButton:Hide()
  end
  if state.teleportButton.cooldownText then
    state.teleportButton.cooldownText:Hide()
  end
end

local function UpdateCenterNoticeTeleportButtonVisual(state, spellID, isEnabled, inCombatBlocked)
  local icon
  local spellApi = rawget(_G, "C_Spell")
  if spellID and type(spellApi) == "table" and type(spellApi.GetSpellTexture) == "function" then
    icon = spellApi.GetSpellTexture(spellID)
  end
  if not icon then
    icon = "Interface\\Icons\\INV_Misc_QuestionMark"
  end
  state.teleportButton.icon:SetTexture(icon)

  if inCombatBlocked then
    state.teleportButton.overlay:SetColorTexture(unpack(Colors.RED_DANGER_OVERLAY or { 0.4, 0.05, 0.05, 0.55 }))
  elseif not isEnabled then
    state.teleportButton.overlay:SetColorTexture(unpack(Colors.BLACK_OVERLAY_60 or { 0, 0, 0, 0.6 }))
  else
    state.teleportButton.overlay:SetColorTexture(unpack(Colors.TRANSPARENT or { 0, 0, 0, 0 }))
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
    if state.teleportButtonOnUpdate then
      state.teleportButton:SetScript("OnUpdate", state.teleportButtonOnUpdate)
    end
    if not state.teleportButton:IsShown() then
      state.teleportButton:Show()
    end
    return
  end

  if state.teleportButton:IsShown() then
    state.teleportButton:Hide()
  end
  state.teleportButton:SetScript("OnUpdate", nil)
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

local RichLayout = NoticeRichLayout.Create({
  setTeleportButtonSize = SetCenterNoticeTeleportButtonSize,
  setTeleportButtonAnchor = SetCenterNoticeTeleportButtonAnchor,
})

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
  -- Explicit full alpha: this is also what ends a previous notice's blink.
  state.text:SetTextColor(state.baseTextR, state.baseTextG, state.baseTextB, 1)
end

local function ApplyCenterNoticeSubline(fontString, content)
  if type(content) == "string" and content ~= "" then
    SetReadableText(fontString, content)
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
  SetReadableText(state.text, message)
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
  SetReadableText(state.text, message)
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
  local wasShown = state.frame:IsShown()
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

  local noticeKind = showOptions.noticeKind
  if noticeKind ~= "info" and noticeKind ~= "warning" and noticeKind ~= "action" then
    noticeKind = hasTeleportButton and "action" or "info"
    for _, field in ipairs(type(showOptions.fields) == "table" and showOptions.fields or {}) do
      if type(field) == "table" and field.warning == true then
        noticeKind = "warning"
        break
      end
    end
  end
  local kindChanged = false
  if type(SemanticUICommon) == "table" and type(SemanticUICommon.ApplyNoticeKind) == "function" then
    local _, changed = SemanticUICommon.ApplyNoticeKind(state.frame, noticeKind)
    kindChanged = changed == true
  end

  if hasRich then
    -- Rich mode replaces sublines and the body text. Hide them explicitly so
    -- a previous Show in stack/legacy mode does not leak fragments through.
    ApplyCenterNoticeSubline(state.sublineTop, nil)
    ApplyCenterNoticeSubline(state.sublineBottom, nil)
    RichLayout.ApplyLayout(state, showOptions, hasTeleportButton)
  else
    -- Non-rich modes never use the rich primitives; clear them defensively.
    RichLayout.HideElements(state)
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
  if type(SemanticUICommon) ~= "table" then
    return
  end
  if not wasShown and type(SemanticUICommon.PlayNoticeEntrance) == "function" then
    SemanticUICommon.PlayNoticeEntrance(state.frame)
  elseif kindChanged and type(SemanticUICommon.PlayNoticeTransition) == "function" then
    SemanticUICommon.PlayNoticeTransition(state.frame)
  end
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

  -- Mirrors the portal grid: the swipe starts now and runs over the remaining
  -- time (GetCooldownFrameStartForRemaining + ApplyCooldownFrameSafe). It is
  -- only re-applied when the end time moves by more than half a second, so the
  -- 0.1 s text refresh does not restart the swipe every tick.
  local function SyncTeleportSwipe(button, remaining)
    local apply = state.config.applyCooldownFrameSafe
    if not button.cooldown or type(apply) ~= "function" then
      return
    end
    local startFor = state.config.getCooldownFrameStartForRemaining
    if remaining > 0 and type(startFor) == "function" then
      local start, duration = startFor(remaining)
      local endTime = (tonumber(start) or 0) + (tonumber(duration) or 0)
      if button._swipeEnd == nil or math.abs(button._swipeEnd - endTime) > 0.5 then
        apply(button.cooldown, start, duration, true)
        button._swipeEnd = endTime
      end
    elseif button._swipeEnd ~= nil then
      apply(button.cooldown, 0, 0, false)
      button._swipeEnd = nil
    end
  end

  -- The 0.1 s tick mostly lands on an unchanged label ("Portal", or the same
  -- displayed second); SetText would re-layout the FontString every time.
  local function ShowCooldownText(button, text)
    if button._cooldownTextValue ~= text then
      button._cooldownTextValue = text
      button.cooldownText:SetText(text)
    end
    button.cooldownText:Show()
  end

  local function UpdateTeleportCooldownText(self, elapsed)
    self._cooldownTextAccum = (self._cooldownTextAccum or 0) + (elapsed or 0)
    if self._cooldownTextAccum < 0.1 then
      return
    end
    self._cooldownTextAccum = 0

    if not self.spellID or not self:IsShown() then
      self.cooldownText:Hide()
      SyncTeleportSwipe(self, 0)
      return
    end

    local remaining = state.config.getTeleportCooldownRemaining(self.spellID)
    SyncTeleportSwipe(self, remaining)
    if remaining > 0 then
      ShowCooldownText(self, state.config.formatCooldownSeconds(remaining))
      return
    end
    local L = state.config.getL() or {}
    ShowCooldownText(self, L.CENTER_NOTICE_PORTAL_READY_LABEL or "Portal")
  end
  state.teleportButtonOnUpdate = UpdateTeleportCooldownText
  state.teleportButton:SetScript("OnShow", function(self)
    self:SetScript("OnUpdate", UpdateTeleportCooldownText)
  end)
  state.teleportButton:SetScript("OnHide", function(self)
    self:SetScript("OnUpdate", nil)
    self._cooldownTextAccum = 0
    SyncTeleportSwipe(self, 0)
  end)
  if state.teleportButton:IsShown() then
    state.teleportButton:SetScript("OnUpdate", UpdateTeleportCooldownText)
  end

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

  local function UpdateCenterNotice(_, elapsed)
    if state.isBlinking then
      state.blinkTime = state.blinkTime + (elapsed or 0)
      local wave = (math.sin(state.blinkTime * 3) + 1) * 0.5
      local alpha = 0.65 + (wave * 0.35)
      state.text:SetTextColor(state.baseTextR, state.baseTextG, state.baseTextB, alpha)
    end
    -- No steady-state repaint: isBlinking only changes in ShowCenterNotice,
    -- which re-applies the base color at full alpha itself.
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

    if not state.isPersistent and CurrentTime() >= state.endsAt then
      SetCenterNoticeVisible(state, false)
    end
  end
  state.centerNoticeOnUpdate = UpdateCenterNotice
  state.frame:SetScript("OnShow", function(self)
    self:SetScript("OnUpdate", UpdateCenterNotice)
  end)
  state.frame:SetScript("OnHide", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  if state.frame:IsShown() then
    state.frame:SetScript("OnUpdate", UpdateCenterNotice)
  end
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
  local rich = NoticeRichLayout.CreateElements(frame, config)
  local state = {
    config = config,
    frame = frame,
    text = text,
    sublineTop = sublineTop,
    sublineBottom = sublineBottom,
    eyebrowText = rich.eyebrowText,
    titleText = rich.titleText,
    titleSeparator = rich.titleSeparator,
    teleportHeader = rich.teleportHeader,
    fieldRows = rich.fieldRows,
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

function Notice.CreatePortalNavigatorNotice(opts)
  return PortalNavigatorNotice.Create(opts, {
    colors = Colors,
    titleColor = { NOTICE_TITLE_COLOR_R, NOTICE_TITLE_COLOR_G, NOTICE_TITLE_COLOR_B },
    applyFrameLayer = ApplyNoticeFrameLayer,
    clampMovableFrameToScreen = ClampMovableFrameToScreen,
    increaseFontSize = IncreaseFontSize,
    setReadableText = SetReadableText,
    createBodyText = CreatePortalStyleBodyText,
    createCloseButton = CreateCenterNoticeCloseButton,
  })
end
