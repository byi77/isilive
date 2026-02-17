local _, addonTable = ...

addonTable = addonTable or {}

local TeleportUI = {}
addonTable.TeleportUI = TeleportUI

function TeleportUI.CreateController(opts)
  opts = opts or {}

  local mainFrame = opts.mainFrame
  local applySecureSpellToButton = opts.applySecureSpellToButton or function(_button, _spellID)
    return false
  end
  local getEntries = opts.getEntries or function()
    return {}
  end
  local getL = opts.getL or function()
    return {}
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
  local getSpellCooldownSafe = opts.getSpellCooldownSafe or function(_spellID)
    return 0, 0, true
  end
  local applyCooldownFrameSafe = opts.applyCooldownFrameSafe or function(_frame, _start, _duration, _enabled) end
  local getSpellTexture = opts.getSpellTexture or function(_spellID)
    return nil
  end

  assert(mainFrame and mainFrame.GetFrameLevel, "isiLive: TeleportUI requires mainFrame")
  assert(type(applySecureSpellToButton) == "function", "isiLive: TeleportUI requires applySecureSpellToButton")
  assert(type(getEntries) == "function", "isiLive: TeleportUI requires getEntries")
  assert(type(getL) == "function", "isiLive: TeleportUI requires getL")
  assert(type(isSpellKnown) == "function", "isiLive: TeleportUI requires isSpellKnown")
  assert(type(getTeleportCooldownRemaining) == "function", "isiLive: TeleportUI requires getTeleportCooldownRemaining")
  assert(type(formatCooldownSeconds) == "function", "isiLive: TeleportUI requires formatCooldownSeconds")
  assert(type(getSpellCooldownSafe) == "function", "isiLive: TeleportUI requires getSpellCooldownSafe")
  assert(type(applyCooldownFrameSafe) == "function", "isiLive: TeleportUI requires applyCooldownFrameSafe")
  assert(type(getSpellTexture) == "function", "isiLive: TeleportUI requires getSpellTexture")

  local controller = {}
  local buttons = {}

  local function CreateTeleportButton(index, entry)
    local size = 28
    local colCount = 2
    local col = (index - 1) % colCount
    local row = math.floor((index - 1) / colCount)
    local x = (col == 0) and -85 or -53
    local y = -60 - (row * (size + 4))

    local button = CreateFrame("Button", nil, mainFrame, "SecureActionButtonTemplate")
    button:SetSize(size, size)
    button:SetPoint("TOPRIGHT", x, y)
    button:EnableMouse(true)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
    button.spellID = entry.spellID
    button.mapID = entry.mapID
    button.mapName = entry.mapName
    button.defaultIcon = entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    button.isActiveTarget = false
    applySecureSpellToButton(button, entry.spellID)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon:SetTexture(button.defaultIcon)

    -- Cooldown frame (visualize CD)
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints()
    button.cooldown:SetDrawEdge(false)

    -- Overlay frame (ensure highlight is above cooldown)
    button.overlayFrame = CreateFrame("Frame", nil, button)
    button.overlayFrame:SetAllPoints()
    button.overlayFrame:SetFrameLevel(button.cooldown:GetFrameLevel() + 1)

    button.overlay = button.overlayFrame:CreateTexture(nil, "OVERLAY")
    button.overlay:SetAllPoints()
    button.overlay:SetColorTexture(0, 0, 0, 0.35)

    button.activeBorder = button.overlayFrame:CreateTexture(nil, "OVERLAY")
    button.activeBorder:SetAllPoints()
    button.activeBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    button.activeBorder:SetBlendMode("ADD")
    button.activeBorder:SetVertexColor(1, 0.85, 0.1, 1)
    button.activeBorder:Hide()

    button.activeGlow = button.overlayFrame:CreateTexture(nil, "OVERLAY")
    button.activeGlow:SetAllPoints()
    button.activeGlow:SetTexture("Interface\\AddOns\\Blizzard_SharedXML\\Shared\\CircularGlow")
    button.activeGlow:SetBlendMode("ADD")
    button.activeGlow:SetVertexColor(1, 0.78, 0.08, 0.9)
    button.activeGlow:Hide()

    -- Performance: Use AnimationGroup instead of OnUpdate for pulsing
    button.animGroup = button:CreateAnimationGroup()
    button.animGroup:SetLooping("BOUNCE")

    local scaleAnim = button.animGroup:CreateAnimation("Scale")
    scaleAnim:SetScale(1.2, 1.2)
    scaleAnim:SetDuration(0.8)
    scaleAnim:SetSmoothing("IN_OUT")
    scaleAnim:SetOrder(1)

    local alphaAnim = button.animGroup:CreateAnimation("Alpha")
    alphaAnim:SetFromAlpha(0.5)
    alphaAnim:SetToAlpha(1.0)
    alphaAnim:SetDuration(0.8)
    alphaAnim:SetSmoothing("IN_OUT")
    alphaAnim:SetOrder(1)
    if alphaAnim.SetTarget then
      alphaAnim:SetTarget(button.activeGlow)
    end

    button:SetScript("OnEnter", function(self)
      local L = getL()
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if self.spellID and isSpellKnown(self.spellID) then
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
      if self.isActiveTarget then
        GameTooltip:AddLine(L.TOOLTIP_TELEPORT_ACTIVE_TARGET, 1, 0.85, 0.2, true)
      end
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    return button
  end

  function controller.BuildButtons()
    buttons = {}
    for i, entry in ipairs(getEntries()) do
      table.insert(buttons, CreateTeleportButton(i, entry))
    end
  end

  function controller.GetButtons()
    return buttons
  end

  function controller.UpdateButtons(resolvedSpellID)
    for _, button in ipairs(buttons) do
      local known = isSpellKnown(button.spellID)
      local icon = getSpellTexture(button.spellID)
      button.icon:SetTexture(icon or button.defaultIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
      button.isActiveTarget = (resolvedSpellID and button.spellID == resolvedSpellID) and true or false

      local start, duration, enabled = getSpellCooldownSafe(button.spellID)
      applyCooldownFrameSafe(button.cooldown, start, duration, enabled)

      if known then
        if button.isActiveTarget then
          button.overlay:SetColorTexture(1, 0.5, 0.0, 0.5)
          button.activeBorder:Show()
          button.activeGlow:Show()
          if not button.animGroup:IsPlaying() then
            button.animGroup:Play()
          end
        else
          button.overlay:SetColorTexture(0, 0, 0, 0.28)
          button.activeBorder:Hide()
          button.activeGlow:Hide()
          button.animGroup:Stop()
          button:SetScale(1) -- Reset scale
        end
      else
        button.overlay:SetColorTexture(0, 0, 0, 0.62)
        button.activeBorder:Hide()
        button.activeGlow:Hide()
        button.animGroup:Stop()
        button:SetScale(1)
      end
    end
  end

  return controller
end
