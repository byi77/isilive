local _, addonTable = ...

addonTable = addonTable or {}

local Notice = {}
addonTable.Notice = Notice
local createRedCloseButton = assert(
  addonTable.UICommon and addonTable.UICommon.CreateRedCloseButton,
  "isiLive: UICommon.CreateRedCloseButton missing"
)

local function BuildCenterNoticeConfig(opts)
  opts = opts or {}
  return {
    parent = opts.parent or UIParent,
    minHeight = tonumber(opts.minHeight) or 70,
    maxHeight = tonumber(opts.maxHeight) or 220,
    paddingX = tonumber(opts.paddingX) or 20,
    paddingY = tonumber(opts.paddingY) or 12,
    buttonHeight = tonumber(opts.buttonHeight) or 36,
    buttonGap = tonumber(opts.buttonGap) or 8,
    isInCombat = opts.isInCombat or function()
      return InCombatLockdown and InCombatLockdown()
    end,
    resolveTeleportSpellID = opts.resolveTeleportSpellID or function(_activityID, _dungeonName)
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
    getL = opts.getL or function()
      return {}
    end,
  }
end

local function CreateCenterNoticeFrame(config)
  local frame = CreateFrame("Frame", "isiLiveCenterNotice", config.parent)
  frame:SetSize(680, config.minHeight)
  frame:SetPoint("CENTER", config.parent, "CENTER", 0, 0)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:Hide()
  frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
  end)

  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.55)
  return frame
end

local function CreateCenterNoticeText(frame, config)
  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  text:SetPoint("TOPLEFT", frame, "TOPLEFT", config.paddingX, -config.paddingY)
  text:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -config.paddingX, -config.paddingY)
  text:SetJustifyH("CENTER")
  text:SetJustifyV("TOP")
  text:SetWordWrap(true)
  if text.SetNonSpaceWrap then
    text:SetNonSpaceWrap(true)
  end
  text:SetTextColor(1, 0.82, 0)
  return text
end

local function CreateCenterNoticeCloseButton(frame)
  return createRedCloseButton(frame, {
    point = { "TOPRIGHT", frame, "TOPRIGHT", -2, -2 },
    frameLevel = frame:GetFrameLevel() + 20,
  })
end

local function CreateCenterNoticeTeleportButton(frame, config)
  local button = CreateFrame("Button", "isiLiveCenterNoticeTeleportButton", frame, "SecureActionButtonTemplate")
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
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints()
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  button.overlay = button:CreateTexture(nil, "OVERLAY")
  button.overlay:SetAllPoints()
  button.overlay:SetColorTexture(0, 0, 0, 0)
  button.cooldownText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.cooldownText:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.cooldownText:SetTextColor(1, 1, 1)
  button.cooldownText:Hide()
  return button
end

local function ResetCenterNoticeToDefaultPosition(state)
  state.frame:ClearAllPoints()
  state.frame:SetPoint("CENTER", state.config.parent, "CENTER", 0, 0)
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

local function SetCenterNoticeTeleportButtonAnchor(state, yOffset)
  if state.config.isInCombat() then
    state.pendingTeleportButtonOffsetY = yOffset
    return
  end

  state.pendingTeleportButtonOffsetY = nil
  state.teleportButton:ClearAllPoints()
  state.teleportButton:SetPoint("TOP", state.frame, "TOP", 0, yOffset)
end

local function ClearCenterNoticeTeleportButton(state)
  SetCenterNoticeTeleportButtonVisible(state, false)
  state.pendingTeleportButtonOffsetY = nil
  state.teleportButton.spellID = nil
  state.teleportButton.dungeonName = nil
  state.teleportButton.inCombatBlocked = false
  SetCenterNoticeTeleportButtonMouseEnabled(state, true)
end

local function ConfigureCenterNoticeTeleportButton(state, dungeonName, activityID)
  local hasDungeonName = type(dungeonName) == "string" and dungeonName ~= ""
  local numericActivityID = tonumber(activityID)
  if numericActivityID and numericActivityID <= 0 then
    numericActivityID = nil
  end

  if not hasDungeonName and not numericActivityID then
    ClearCenterNoticeTeleportButton(state)
    return false
  end

  local spellID = state.config.resolveTeleportSpellID(numericActivityID, hasDungeonName and dungeonName or nil)
  if not spellID then
    ClearCenterNoticeTeleportButton(state)
    return false
  end

  if state.config.isInCombat() then
    state.teleportButton.spellID = spellID
    state.teleportButton.dungeonName = hasDungeonName and dungeonName or nil
    state.teleportButton.inCombatBlocked = true
    SetCenterNoticeTeleportButtonMouseEnabled(state, false)
    UpdateCenterNoticeTeleportButtonVisual(state, spellID, false, true)
    SetCenterNoticeTeleportButtonVisible(state, true)
    return true
  end

  state.config.applySecureSpellToButton(state.teleportButton, spellID)
  state.teleportButton.spellID = spellID
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

  local fontPath, baseSize, fontFlags = state.text:GetFont()
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
    state.baseTextR, state.baseTextG, state.baseTextB = 1, 0.82, 0
  end
  state.text:SetTextColor(state.baseTextR, state.baseTextG, state.baseTextB)
end

local function ShowCenterNotice(state, message, durationSeconds, dungeonName, activityID, showOptions)
  showOptions = showOptions or {}
  state.isPersistent = showOptions.persistent == true
  state.isBlinking = showOptions.blink == true
  state.blinkTime = 0

  ApplyCenterNoticeFontScale(state, showOptions)
  ApplyCenterNoticeTextColor(state, showOptions)

  local hasTeleportButton = ConfigureCenterNoticeTeleportButton(state, dungeonName, activityID)
  state.text:SetText(message)
  state.text:SetWidth(state.frame:GetWidth() - (state.config.paddingX * 2))
  local textHeight = state.text:GetStringHeight() or 0
  if hasTeleportButton then
    SetCenterNoticeTeleportButtonAnchor(
      state,
      -(state.config.paddingY + math.ceil(textHeight) + state.config.buttonGap)
    )
  end

  local extraHeight = hasTeleportButton and (state.config.buttonHeight + state.config.buttonGap) or 0
  local frameHeight = math.min(
    state.config.maxHeight,
    math.max(state.config.minHeight, math.ceil(textHeight + (state.config.paddingY * 2) + extraHeight))
  )
  state.frame:SetHeight(frameHeight)
  state.endsAt = state.isPersistent and math.huge or (GetTime() + (durationSeconds or 20))
  SetCenterNoticeVisible(state, true)
end

local function AttachCenterNoticeTeleportButtonScripts(state)
  state.teleportButton:SetScript("OnEnter", function(self)
    local L = state.config.getL() or {}
    GameTooltip:SetOwner(self, "ANCHOR_TOP")

    if self.inCombatBlocked then
      GameTooltip:SetText(L.BTN_TELEPORT, 1, 1, 1)
      GameTooltip:AddLine(L.TOOLTIP_TELEPORT_COMBAT, 1, 0.25, 0.25, true)
    elseif self.spellID and state.config.isSpellKnown(self.spellID) then
      GameTooltip:SetSpellByID(self.spellID)
      GameTooltip:AddLine(L.TOOLTIP_TELEPORT_CAST, 1, 1, 1, true)
      local remaining = state.config.getTeleportCooldownRemaining(self.spellID)
      if remaining > 0 then
        GameTooltip:AddLine(
          string.format(L.TOOLTIP_TELEPORT_COOLDOWN, state.config.formatCooldownSeconds(remaining)),
          1,
          0.82,
          0,
          true
        )
      else
        GameTooltip:AddLine(L.TOOLTIP_TELEPORT_READY, 0.3, 1, 0.3, true)
      end
    else
      GameTooltip:SetText(L.BTN_TELEPORT_LOCKED, 1, 1, 1)
      GameTooltip:AddLine(L.TOOLTIP_TELEPORT_LOCKED, 1, 0.25, 0.25, true)
    end
    GameTooltip:Show()
  end)

  state.teleportButton:SetScript("OnUpdate", function(self)
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
    self.cooldownText:Hide()
  end)

  state.teleportButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

local function AttachCenterNoticeFrameScripts(state)
  state.frame:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then
      SetCenterNoticeVisible(state, false)
    end
  end)

  state.frame:SetScript("OnUpdate", function(_, elapsed)
    if not state.config.isInCombat() then
      if state.pendingTeleportButtonOffsetY ~= nil then
        SetCenterNoticeTeleportButtonAnchor(state, state.pendingTeleportButtonOffsetY)
      end
      if state.pendingTeleportButtonMouseEnabled ~= nil then
        SetCenterNoticeTeleportButtonMouseEnabled(state, state.pendingTeleportButtonMouseEnabled)
      end
      if state.pendingTeleportButtonVisible ~= nil then
        SetCenterNoticeTeleportButtonVisible(state, state.pendingTeleportButtonVisible)
      end
    end

    if state.isBlinking and state.frame:IsShown() then
      state.blinkTime = state.blinkTime + (elapsed or 0)
      local wave = (math.sin(state.blinkTime * 8) + 1) * 0.5
      local alpha = 0.55 + (wave * 0.45)
      state.text:SetTextColor(state.baseTextR, state.baseTextG, state.baseTextB, alpha)
    elseif state.frame:IsShown() then
      state.text:SetTextColor(state.baseTextR, state.baseTextG, state.baseTextB, 1)
    end

    if not state.isPersistent and GetTime() >= state.endsAt then
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

  local function ConfigureTeleportButton(dungeonName, activityID)
    return ConfigureCenterNoticeTeleportButton(state, dungeonName, activityID)
  end

  local function UpdateTeleportButtonVisual(spellID, isEnabled, inCombatBlocked)
    UpdateCenterNoticeTeleportButtonVisual(state, spellID, isEnabled, inCombatBlocked)
  end

  return {
    frame = state.frame,
    text = state.text,
    closeButton = state.closeButton,
    teleportButton = state.teleportButton,
    SetVisible = SetVisible,
    Show = Show,
    ConfigureTeleportButton = ConfigureTeleportButton,
    UpdateTeleportButtonVisual = UpdateTeleportButtonVisual,
  }
end

function Notice.CreateCenterNotice(opts)
  local config = BuildCenterNoticeConfig(opts)
  local frame = CreateCenterNoticeFrame(config)
  local text = CreateCenterNoticeText(frame, config)
  local closeButton = CreateCenterNoticeCloseButton(frame)
  local teleportButton = CreateCenterNoticeTeleportButton(frame, config)
  local state = {
    config = config,
    frame = frame,
    text = text,
    closeButton = closeButton,
    teleportButton = teleportButton,
    endsAt = 0,
    isPersistent = false,
    isBlinking = false,
    blinkTime = 0,
    baseTextR = 1,
    baseTextG = 0.82,
    baseTextB = 0,
    pendingTeleportButtonMouseEnabled = nil,
    pendingTeleportButtonOffsetY = nil,
    pendingTeleportButtonVisible = nil,
  }

  AttachCenterNoticeTeleportButtonScripts(state)
  AttachCenterNoticeFrameScripts(state)
  closeButton:SetScript("OnClick", function()
    SetCenterNoticeVisible(state, false)
  end)
  return BuildCenterNoticeController(state)
end

function Notice.CreateInviteHint(opts)
  opts = opts or {}
  local parent = opts.parent or UIParent
  local mainFrameGlobalName = opts.mainFrameGlobalName or "isiLiveMainFrame"

  local frame = CreateFrame("Frame", "isiLiveInviteHintFrame", parent)
  frame:SetSize(420, 46)
  frame:Hide()
  frame:SetFrameStrata("DIALOG")

  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.65)

  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  text:SetPoint("CENTER", 0, 0)
  text:SetJustifyH("CENTER")
  text:SetTextColor(1, 0.82, 0)

  local endsAt = 0

  local function GetInviteAnchorFrame()
    local lfgListInviteDialog = rawget(_G, "LFGListInviteDialog")
    if lfgListInviteDialog and lfgListInviteDialog:IsShown() then
      return lfgListInviteDialog
    end
    local lfgDungeonReadyDialog = rawget(_G, "LFGDungeonReadyDialog")
    if lfgDungeonReadyDialog and lfgDungeonReadyDialog:IsShown() then
      return lfgDungeonReadyDialog
    end
    return nil
  end

  local function Position()
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

  local function Show(message, durationSeconds)
    text:SetText(message)
    Position()
    endsAt = GetTime() + (durationSeconds or 10)
    frame:Show()
  end

  frame:SetScript("OnUpdate", function(self)
    if GetTime() >= endsAt then
      self:Hide()
      return
    end
    Position()
  end)

  return {
    frame = frame,
    Show = Show,
    Position = Position,
  }
end
