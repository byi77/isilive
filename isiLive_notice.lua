local _, addonTable = ...

addonTable = addonTable or {}

local Notice = {}
addonTable.Notice = Notice

function Notice.CreateCenterNotice(opts)
  opts = opts or {}
  local parent = opts.parent or UIParent
  local minHeight = tonumber(opts.minHeight) or 70
  local maxHeight = tonumber(opts.maxHeight) or 220
  local paddingX = tonumber(opts.paddingX) or 20
  local paddingY = tonumber(opts.paddingY) or 12
  local buttonHeight = tonumber(opts.buttonHeight) or 36
  local buttonGap = tonumber(opts.buttonGap) or 8
  local isInCombat = opts.isInCombat or function()
    return InCombatLockdown and InCombatLockdown()
  end
  local resolveTeleportSpellID = opts.resolveTeleportSpellID or function(_activityID, _dungeonName)
    return nil
  end
  local applySecureSpellToButton = opts.applySecureSpellToButton or function(_button, _spellID)
    return false
  end
  local isSpellKnown = opts.isSpellKnown or function(_spellID)
    return false
  end
  local getTeleportCooldownRemaining = opts.getTeleportCooldownRemaining or function(_spellID)
    return 0
  end
  local formatCooldownSeconds = opts.formatCooldownSeconds or function(sec)
    return tostring(sec or 0)
  end
  local getL = opts.getL or function()
    return {}
  end

  local frame = CreateFrame("Frame", "isiLiveCenterNotice", parent)
  frame:SetSize(680, minHeight)
  frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:Hide()
  frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if IsiLiveDB then
      local point, _, relativePoint, x, y = self:GetPoint()
      IsiLiveDB.centerNoticePosition = { point = point, relativePoint = relativePoint, x = x, y = y }
    end
  end)

  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.55)

  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  text:SetPoint("TOPLEFT", frame, "TOPLEFT", paddingX, -paddingY)
  text:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -paddingX, -paddingY)
  text:SetJustifyH("CENTER")
  text:SetJustifyV("TOP")
  text:SetWordWrap(true)
  if text.SetNonSpaceWrap then
    text:SetNonSpaceWrap(true)
  end
  text:SetTextColor(1, 0.82, 0)

  local teleportButton = CreateFrame("Button", "isiLiveCenterNoticeTeleportButton", frame, "SecureActionButtonTemplate")
  teleportButton:SetSize(buttonHeight, buttonHeight)
  teleportButton:SetPoint("TOP", frame, "TOP", 0, -(paddingY + 26 + buttonGap))
  teleportButton:Hide()
  teleportButton:EnableMouse(true)
  teleportButton.spellID = nil
  teleportButton.inCombatBlocked = false
  teleportButton:RegisterForClicks("AnyDown", "AnyUp")
  teleportButton:SetFrameStrata("HIGH")
  teleportButton:SetFrameLevel(frame:GetFrameLevel() + 10)
  teleportButton:SetAttribute("type", "spell")
  teleportButton:SetAttribute("type1", "spell")
  teleportButton:SetAttribute("*type1", "spell")
  teleportButton:SetAttribute("useOnKeyDown", true)
  teleportButton:SetAttribute("spell", 0)
  teleportButton:SetAttribute("spell1", 0)
  teleportButton.icon = teleportButton:CreateTexture(nil, "ARTWORK")
  teleportButton.icon:SetAllPoints()
  teleportButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  teleportButton.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  teleportButton.overlay = teleportButton:CreateTexture(nil, "OVERLAY")
  teleportButton.overlay:SetAllPoints()
  teleportButton.overlay:SetColorTexture(0, 0, 0, 0)
  teleportButton.cooldownText = teleportButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  teleportButton.cooldownText:SetPoint("CENTER", teleportButton, "CENTER", 0, 0)
  teleportButton.cooldownText:SetTextColor(1, 1, 1)
  teleportButton.cooldownText:Hide()

  local pendingVisible = nil
  local endsAt = 0

  local function SetVisible(visible)
    if isInCombat() then
      pendingVisible = visible and true or false
      return
    end
    pendingVisible = nil
    if visible then
      if not frame:IsShown() then
        frame:Show()
      end
    else
      if frame:IsShown() then
        frame:Hide()
      end
    end
  end

  local function UpdateTeleportButtonVisual(spellID, isEnabled, inCombatBlocked)
    local icon
    if spellID and C_Spell and C_Spell.GetSpellTexture then
      icon = C_Spell.GetSpellTexture(spellID)
    end
    if not icon then
      icon = "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    teleportButton.icon:SetTexture(icon)

    if inCombatBlocked then
      teleportButton.overlay:SetColorTexture(0.4, 0.05, 0.05, 0.55)
    elseif not isEnabled then
      teleportButton.overlay:SetColorTexture(0, 0, 0, 0.6)
    else
      teleportButton.overlay:SetColorTexture(0, 0, 0, 0)
    end
  end

  local function ConfigureTeleportButton(dungeonName, activityID)
    if not dungeonName or dungeonName == "" then
      teleportButton:Hide()
      teleportButton.spellID = nil
      teleportButton.dungeonName = nil
      teleportButton.inCombatBlocked = false
      return false
    end

    local spellID = resolveTeleportSpellID(activityID, dungeonName)
    if not spellID then
      teleportButton:Hide()
      teleportButton.spellID = nil
      teleportButton.dungeonName = nil
      teleportButton.inCombatBlocked = false
      return false
    end

    if isInCombat() then
      teleportButton.spellID = spellID
      teleportButton.dungeonName = dungeonName
      teleportButton.inCombatBlocked = true
      UpdateTeleportButtonVisual(spellID, false, true)
      teleportButton:Show()
      return true
    end

    applySecureSpellToButton(teleportButton, spellID)
    teleportButton.spellID = spellID
    teleportButton.dungeonName = dungeonName
    teleportButton.inCombatBlocked = false

    local known = isSpellKnown(spellID)
    teleportButton:Enable()
    UpdateTeleportButtonVisual(spellID, known, false)
    teleportButton:Show()
    return true
  end

  local function Show(message, durationSeconds, dungeonName, activityID)
    local hasTeleportButton = ConfigureTeleportButton(dungeonName, activityID)
    text:SetText(message)
    text:SetWidth(frame:GetWidth() - (paddingX * 2))
    local textHeight = text:GetStringHeight() or 0
    if hasTeleportButton then
      teleportButton:ClearAllPoints()
      teleportButton:SetPoint("TOP", frame, "TOP", 0, -(paddingY + math.ceil(textHeight) + buttonGap))
    end
    local extraHeight = hasTeleportButton and (buttonHeight + buttonGap) or 0
    local frameHeight = math.min(maxHeight, math.max(minHeight, math.ceil(textHeight + (paddingY * 2) + extraHeight)))
    frame:SetHeight(frameHeight)
    endsAt = GetTime() + (durationSeconds or 20)
    SetVisible(true)
  end

  teleportButton:SetScript("OnEnter", function(self)
    local L = getL() or {}
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if self.inCombatBlocked then
      GameTooltip:SetText(L.BTN_TELEPORT)
      GameTooltip:AddLine(L.TOOLTIP_TELEPORT_COMBAT, 1, 0.25, 0.25, true)
    elseif self.spellID and isSpellKnown(self.spellID) then
      GameTooltip:SetSpellByID(self.spellID)
      GameTooltip:AddLine(L.TOOLTIP_TELEPORT_CAST, 1, 1, 1, true)
      local remaining = getTeleportCooldownRemaining(self.spellID)
      if remaining > 0 then
        GameTooltip:AddLine(
          string.format(L.TOOLTIP_TELEPORT_COOLDOWN, formatCooldownSeconds(remaining)),
          1,
          0.82,
          0,
          true
        )
      else
        GameTooltip:AddLine(L.TOOLTIP_TELEPORT_READY, 0.3, 1, 0.3, true)
      end
    else
      GameTooltip:SetText(L.BTN_TELEPORT_LOCKED)
      GameTooltip:AddLine(L.TOOLTIP_TELEPORT_LOCKED, 1, 0.25, 0.25, true)
    end
    GameTooltip:Show()
  end)
  teleportButton:SetScript("OnUpdate", function(self)
    if not self.spellID or not self:IsShown() then
      self.cooldownText:Hide()
      return
    end
    local remaining = getTeleportCooldownRemaining(self.spellID)
    if remaining > 0 then
      self.cooldownText:SetText(formatCooldownSeconds(remaining))
      self.cooldownText:Show()
    else
      self.cooldownText:Hide()
    end
  end)
  teleportButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  frame:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then
      SetVisible(false)
    end
  end)
  frame:SetScript("OnUpdate", function()
    if GetTime() >= endsAt then
      SetVisible(false)
    end
  end)

  local function ApplyStoredPosition(pos)
    if not pos then
      return
    end
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, parent, pos.relativePoint, pos.x, pos.y)
  end

  return {
    frame = frame,
    text = text,
    teleportButton = teleportButton,
    SetVisible = SetVisible,
    GetPendingVisible = function()
      return pendingVisible
    end,
    Show = Show,
    ConfigureTeleportButton = ConfigureTeleportButton,
    UpdateTeleportButtonVisual = UpdateTeleportButtonVisual,
    ApplyStoredPosition = ApplyStoredPosition,
  }
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
