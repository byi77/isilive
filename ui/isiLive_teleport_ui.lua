local _, addonTable = ...

addonTable = addonTable or {}

-- Lua 5.1 (WoW client) exposes global `unpack`; Lua 5.4 (local tooling) only
-- has `table.unpack`. Bridge locally so this file works under both without
-- depending on the entrypoint script to have set up a global compat shim.
local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

local TeleportUI = {}
addonTable.TeleportUI = TeleportUI
local RI = addonTable._RosterInternal or {}
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
local setReadableText = addonTable.UICommon and addonTable.UICommon.SetReadableText
local Colors = addonTable.UICommon and addonTable.UICommon.Colors or {}
local LAYOUT_MODE_EXPANDED = RI.LAYOUT_MODE_EXPANDED or "expanded"
local LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL = RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL or "compact_main_horizontal"
local M2_ROW_LEFT_MARGIN = RI.M2_ROW_LEFT_MARGIN or 10
local M2_TELEPORT_ROW_Y_DEFAULT = 70
local function GetM2TeleportRowY()
  return RI.M2_TELEPORT_ROW_Y or M2_TELEPORT_ROW_Y_DEFAULT
end
local M2_TELEPORT_BUTTON_WIDTH = RI.M2_TELEPORT_BUTTON_WIDTH or RI.M2_TELEPORT_BUTTON_SIZE or 57
local M2_TELEPORT_BUTTON_HEIGHT = RI.M2_TELEPORT_BUTTON_HEIGHT or RI.M2_TELEPORT_BUTTON_SIZE or 32
local M2_TELEPORT_BUTTON_GAP = RI.M2_TELEPORT_BUTTON_GAP or 4
local NormalizeLayoutMode = RI.NormalizeLayoutMode
  or function(layoutMode)
    if layoutMode == LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL or layoutMode == "compact_horizontal_2" then
      return LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
    end
    return LAYOUT_MODE_EXPANDED
  end

local function IsM2LayoutMode(layoutMode)
  return NormalizeLayoutMode(layoutMode) == LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
end

local function ResolveTeleportLevelBlocked(button, deps)
  local minimumPlayerLevel = tonumber(button and button.minimumPlayerLevel)
  if not minimumPlayerLevel then
    return false
  end

  local playerLevel = tonumber(deps.getPlayerLevel())
  if not playerLevel then
    return nil
  end
  return playerLevel < minimumPlayerLevel
end

local function ResolveTeleportButtonShortCode(deps, mapID)
  if type(deps.getDungeonShortCode) ~= "function" then
    return nil
  end

  local shortCode = deps.getDungeonShortCode(mapID)
  if type(shortCode) ~= "string" or shortCode == "" then
    return nil
  end

  return shortCode
end

local function EnsureTeleportButtonShortCodeLabel(button)
  if button.shortCodeText or not (button.overlayFrame and button.overlayFrame.CreateFontString) then
    return button.shortCodeText
  end

  local label = button.overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  label:SetPoint("CENTER", button, "CENTER", 0, 0)
  if label.SetJustifyH then
    label:SetJustifyH("CENTER")
  end
  if label.SetJustifyV then
    label:SetJustifyV("MIDDLE")
  end
  if label.SetTextColor then
    label:SetTextColor(unpack(Colors.WHITE_RGB or { 1, 1, 1 }))
  end
  if label.SetShadowColor then
    label:SetShadowColor(0, 0, 0, 1)
  end
  if label.SetShadowOffset then
    label:SetShadowOffset(1, -1)
  end
  if label.SetText then
    label:SetText("")
  end
  if label.Hide then
    label:Hide()
  end
  button.shortCodeText = label
  return label
end

local function UpdateTeleportButtonShortCodeLabel(button, deps)
  local label = EnsureTeleportButtonShortCodeLabel(button)
  if not label then
    return
  end

  local layoutIsM2 = IsM2LayoutMode(deps.layoutMode)
  local shortCode = button.shortCode or ResolveTeleportButtonShortCode(deps, button.mapID)
  button.shortCode = shortCode

  local cooldownRemaining = tonumber(button.cooldownRemainingSeconds) or 0
  local shouldShow = layoutIsM2 and type(shortCode) == "string" and shortCode ~= "" and cooldownRemaining <= 0

  if not shouldShow then
    if label.SetText then
      label:SetText("")
    end
    if label.Hide then
      label:Hide()
    end
    return
  end

  if label.SetText then
    label:SetText(shortCode)
  end
  if label.Show then
    label:Show()
  end
end

local function SyncButtonLayer(button, mainFrame, isInCombat)
  if
    not (
      button
      and mainFrame
      and button.SetFrameStrata
      and button.SetFrameLevel
      and mainFrame.GetFrameStrata
      and mainFrame.GetFrameLevel
    )
  then
    return
  end

  if type(isInCombat) == "function" and isInCombat() then
    return
  end

  local targetStrata = mainFrame:GetFrameStrata()
  local targetLevel = mainFrame:GetFrameLevel() + 10

  if button.GetFrameStrata and button:GetFrameStrata() ~= targetStrata then
    button:SetFrameStrata(targetStrata)
  end

  if button.GetFrameLevel and button:GetFrameLevel() ~= targetLevel then
    button:SetFrameLevel(targetLevel)
  end
end

local function ApplyTeleportButtonLayout(button, slotIndex, layoutMode)
  if not (button and button.SetPoint) then
    return
  end

  local slot = math.max(0, (tonumber(slotIndex) or 1) - 1)
  if button.ClearAllPoints then
    button:ClearAllPoints()
  end

  if IsM2LayoutMode(layoutMode) then
    local width = M2_TELEPORT_BUTTON_WIDTH
    local height = M2_TELEPORT_BUTTON_HEIGHT
    if button.SetSize then
      button:SetSize(width, height)
    end
    local x = M2_ROW_LEFT_MARGIN + (slot * (width + M2_TELEPORT_BUTTON_GAP))
    button:SetPoint("BOTTOMLEFT", x, GetM2TeleportRowY())
    return
  end

  local size = 28
  if button.SetSize then
    button:SetSize(size, size)
  end
  local colCount = 2
  local col = slot % colCount
  local row = math.floor(slot / colCount)
  local x = (col == 0) and -60 or -28
  local y = -60 - (row * (size + 4))
  button:SetPoint("TOPRIGHT", x, y)
end

local function CreateTeleportButton(mainFrame, deps, index, entry)
  local size = 28
  local slotIndex = entry.slotIndex or index

  -- Keep cast attributes working out of combat, but avoid promoting the parent to a protected frame.
  local button = CreateFrame("Button", nil, mainFrame, "InsecureActionButtonTemplate")
  button:SetSize(size, size)
  button.slotIndex = slotIndex
  ApplyTeleportButtonLayout(button, slotIndex, deps.layoutMode)
  button:EnableMouse(true)
  button:RegisterForClicks("AnyDown", "AnyUp")
  SyncButtonLayer(button, mainFrame, deps.isInCombat)
  button.spellID = entry.spellID
  button.mapID = entry.mapID
  button.mapName = entry.mapName
  button.minimumPlayerLevel = tonumber(entry.minimumPlayerLevel)
  button.shortCode = ResolveTeleportButtonShortCode(deps, entry.mapID)
  button.defaultIcon = entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
  button.isActiveTarget = false
  button._lastObservedActiveTarget = false
  button._portalSoundPrimed = false
  deps.applySecureSpellToButton(button, entry.spellID)

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints()
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.icon:SetTexture(button.defaultIcon)

  button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  button.cooldown:SetAllPoints()
  button.cooldown:SetDrawEdge(false)

  button.overlayFrame = CreateFrame("Frame", nil, button)
  button.overlayFrame:SetAllPoints()
  button.overlayFrame:SetFrameLevel(button.cooldown:GetFrameLevel() + 1)

  button.overlay = button.overlayFrame:CreateTexture(nil, "OVERLAY")
  button.overlay:SetAllPoints()
  button.overlay:SetColorTexture(unpack(Colors.BLACK_OVERLAY_35 or { 0, 0, 0, 0.35 }))

  -- Hatched active-target border: a container frame holding dashed segments
  -- along the four edges. The Show/Hide of the container propagates to the
  -- dashes, and a slow alpha pulse animates the whole container so the icon
  -- is highlighted without goldish blinking or scale bounce.
  button.activeBorder = CreateFrame("Frame", nil, button.overlayFrame)
  button.activeBorder:SetAllPoints()
  button.activeBorder:Hide()
  do
    local DASH_THICKNESS = 2
    local DASH_LENGTH = 4
    local DASH_GAP = 2
    local HATCH_COLOR = { 0.55, 0.85, 1.0, 0.95 }
    local function CreateEdgeDashes()
      local dashes = {}
      local total = 60 -- logical length used for layout math; actual sizing uses relative anchors
      local step = DASH_LENGTH + DASH_GAP
      local count = math.max(2, math.floor(total / step))
      for i = 1, count do
        local tex = button.activeBorder:CreateTexture(nil, "OVERLAY")
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        tex:SetVertexColor(HATCH_COLOR[1], HATCH_COLOR[2], HATCH_COLOR[3], HATCH_COLOR[4])
        tex:SetBlendMode("ADD")
        dashes[i] = tex
      end
      return dashes, count
    end
    local topDashes, countH = CreateEdgeDashes()
    local bottomDashes = CreateEdgeDashes()
    local leftDashes, countV = CreateEdgeDashes()
    local rightDashes = CreateEdgeDashes()
    button.activeBorder:SetScript("OnSizeChanged", function(self, width, height)
      local hStep = (width - DASH_GAP) / countH
      for i, tex in ipairs(topDashes) do
        tex:ClearAllPoints()
        tex:SetSize(hStep - DASH_GAP, DASH_THICKNESS)
        tex:SetPoint("TOPLEFT", self, "TOPLEFT", (i - 1) * hStep + DASH_GAP / 2, 0)
      end
      for i, tex in ipairs(bottomDashes) do
        tex:ClearAllPoints()
        tex:SetSize(hStep - DASH_GAP, DASH_THICKNESS)
        tex:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", (i - 1) * hStep + DASH_GAP / 2, 0)
      end
      local vStep = (height - DASH_GAP) / countV
      for i, tex in ipairs(leftDashes) do
        tex:ClearAllPoints()
        tex:SetSize(DASH_THICKNESS, vStep - DASH_GAP)
        tex:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -((i - 1) * vStep + DASH_GAP / 2))
      end
      for i, tex in ipairs(rightDashes) do
        tex:ClearAllPoints()
        tex:SetSize(DASH_THICKNESS, vStep - DASH_GAP)
        tex:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -((i - 1) * vStep + DASH_GAP / 2))
      end
    end)
  end

  button.cooldownRemainingSeconds = tonumber(deps.getTeleportCooldownRemaining(button.spellID)) or 0
  UpdateTeleportButtonShortCodeLabel(button, deps)

  button.animGroup = button.activeBorder:CreateAnimationGroup()
  button.animGroup:SetLooping("BOUNCE")

  local alphaAnim = button.animGroup:CreateAnimation("Alpha")
  alphaAnim:SetFromAlpha(0.55)
  alphaAnim:SetToAlpha(1.0)
  alphaAnim:SetDuration(1.2)
  alphaAnim:SetSmoothing("IN_OUT")
  alphaAnim:SetOrder(1)

  button:SetScript("OnEnter", function(self)
    local L = deps.getL()
    local tooltip = preparePrivateTooltip(deps.tooltip, self, "ANCHOR_CURSOR")
    if type(tooltip) ~= "table" then
      return
    end
    local hasMapName = type(self.mapName) == "string" and self.mapName ~= ""
    if hasMapName then
      tooltip:SetText(self.mapName, 1, 1, 1)
      local englishMapName = type(deps.getDungeonName) == "function" and deps.getDungeonName(self.mapID, "enUS") or nil
      if type(englishMapName) == "string" and englishMapName ~= "" and englishMapName ~= self.mapName then
        tooltip:AddLine(englishMapName, 1, 1, 1, true)
      end
    end
    local levelBlocked = ResolveTeleportLevelBlocked(self, deps)
    if self.spellID and deps.isSpellKnown(self.spellID) and levelBlocked == false then
      if not hasMapName then
        tooltip:SetSpellByID(self.spellID)
      end
      local remaining = deps.getTeleportCooldownRemaining(self.spellID)
      if remaining > 0 then
        tooltip:AddLine(
          string.format(L.TOOLTIP_TELEPORT_COOLDOWN, deps.formatCooldownSeconds(remaining)),
          1,
          0.82,
          0,
          true
        )
      else
        tooltip:AddLine(L.TOOLTIP_TELEPORT_READY, 0.3, 1, 0.3, true)
      end
    else
      if not hasMapName then
        tooltip:SetText(L.BTN_TELEPORT_LOCKED, 1, 1, 1)
      end
      local minimumPlayerLevel = tonumber(self.minimumPlayerLevel)
      if levelBlocked == true and type(L.TOOLTIP_TELEPORT_LEVEL_REQUIRED) == "string" then
        tooltip:AddLine(string.format(L.TOOLTIP_TELEPORT_LEVEL_REQUIRED, minimumPlayerLevel), 1, 0.25, 0.25, true)
      else
        tooltip:AddLine(L.TOOLTIP_TELEPORT_LOCKED, 1, 0.25, 0.25, true)
      end
    end
    if self.isActiveTarget then
      tooltip:AddLine(L.TOOLTIP_TELEPORT_ACTIVE_TARGET, 1, 0.85, 0.2, true)
    end
    tooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    hidePrivateTooltip(deps.tooltip)
  end)

  return button
end

function TeleportUI.CreateController(opts)
  opts = opts or {}

  local mainFrame = opts.mainFrame
  local deps = {
    applySecureSpellToButton = opts.applySecureSpellToButton or function(_button, _spellID)
      return false
    end,
    getEntries = opts.getEntries or function()
      return {}
    end,
    getL = opts.getL or function()
      return {}
    end,
    getPlayerLevel = opts.getPlayerLevel or function()
      local unitLevel = rawget(_G, "UnitLevel")
      if type(unitLevel) ~= "function" then
        return nil
      end
      return unitLevel("player")
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
    getSpellCooldownSafe = opts.getSpellCooldownSafe or function(_spellID)
      return 0, 0, true
    end,
    getCooldownFrameStartForRemaining = opts.getCooldownFrameStartForRemaining,
    applyCooldownFrameSafe = opts.applyCooldownFrameSafe or function(_frame, _start, _duration, _enabled) end,
    getSpellTexture = opts.getSpellTexture or function(_spellID)
      return nil
    end,
    getDungeonShortCode = opts.getDungeonShortCode or function(_mapID)
      return nil
    end,
    getDungeonName = opts.getDungeonName or function(_mapID, _localeTag)
      return nil
    end,
    getEmptyStateText = opts.getEmptyStateText or function()
      return nil
    end,
    isInCombat = opts.isInCombat or function()
      local inCombatFn = rawget(_G, "InCombatLockdown")
      return type(inCombatFn) == "function" and inCombatFn() == true
    end,
    logRuntimeTraceDeep = type(opts.logRuntimeTraceDeep) == "function" and opts.logRuntimeTraceDeep or nil,
    layoutMode = NormalizeLayoutMode(opts.layoutMode or LAYOUT_MODE_EXPANDED),
  }

  assert(mainFrame and mainFrame.GetFrameLevel and mainFrame.GetFrameStrata, "isiLive: TeleportUI requires mainFrame")
  assert(type(deps.applySecureSpellToButton) == "function", "isiLive: TeleportUI requires applySecureSpellToButton")
  assert(type(deps.getEntries) == "function", "isiLive: TeleportUI requires getEntries")
  assert(type(deps.getL) == "function", "isiLive: TeleportUI requires getL")
  assert(type(deps.isSpellKnown) == "function", "isiLive: TeleportUI requires isSpellKnown")
  assert(
    type(deps.getTeleportCooldownRemaining) == "function",
    "isiLive: TeleportUI requires getTeleportCooldownRemaining"
  )
  assert(type(deps.formatCooldownSeconds) == "function", "isiLive: TeleportUI requires formatCooldownSeconds")
  assert(type(deps.getSpellCooldownSafe) == "function", "isiLive: TeleportUI requires getSpellCooldownSafe")
  assert(type(deps.applyCooldownFrameSafe) == "function", "isiLive: TeleportUI requires applyCooldownFrameSafe")
  assert(type(deps.getSpellTexture) == "function", "isiLive: TeleportUI requires getSpellTexture")
  assert(type(deps.getEmptyStateText) == "function", "isiLive: TeleportUI requires getEmptyStateText")
  assert(type(deps.isInCombat) == "function", "isiLive: TeleportUI requires isInCombat")

  local controller = {}
  local buttons = {}
  ---@type table|nil
  local emptyStateLabel = nil
  local isVisible = true
  deps.tooltip = createPrivateTooltip(mainFrame)

  local function RelayoutButtons()
    for _, button in ipairs(buttons) do
      ApplyTeleportButtonLayout(button, button.slotIndex, deps.layoutMode)
      UpdateTeleportButtonShortCodeLabel(button, deps)
    end
  end

  local function EnsureEmptyStateLabel()
    if emptyStateLabel or type(mainFrame.CreateFontString) ~= "function" then
      return
    end

    emptyStateLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ---@type table|nil
    local label = emptyStateLabel
    if type(label) ~= "table" then
      return
    end
    if type(label.SetPoint) == "function" then
      label:SetPoint("TOPRIGHT", 0, -58)
    end
    if type(label.SetWidth) == "function" then
      label:SetWidth(116)
    end
    if type(label.SetJustifyH) == "function" then
      label:SetJustifyH("RIGHT")
    end
    if type(label.SetTextColor) == "function" then
      label:SetTextColor(unpack(Colors.GOLD_LABEL_ALT or { 1, 0.82, 0.18 }))
    end
    if type(label.SetWordWrap) == "function" then
      label:SetWordWrap(true)
    end
    if type(label.SetNonSpaceWrap) == "function" then
      label:SetNonSpaceWrap(true)
    end
    if type(label.SetText) == "function" then
      label:SetText("")
    end
    if type(label.Hide) == "function" then
      label:Hide()
    end
  end

  local function UpdateEmptyState(entries)
    EnsureEmptyStateLabel()
    ---@type table|nil
    local label = emptyStateLabel
    if type(label) ~= "table" then
      return
    end

    if not isVisible then
      if type(label.SetText) == "function" then
        label:SetText("")
      end
      if type(label.Hide) == "function" then
        label:Hide()
      end
      return
    end

    local hasEntries = type(entries) == "table" and #entries > 0
    local emptyText = nil
    if not hasEntries then
      emptyText = deps.getEmptyStateText()
    end

    if type(emptyText) == "string" and emptyText ~= "" then
      if type(label.SetText) == "function" then
        if type(setReadableText) == "function" then
          setReadableText(label, emptyText)
        else
          label:SetText(emptyText)
        end
      end
      if type(label.Show) == "function" then
        label:Show()
      end
      return
    end

    if type(label.SetText) == "function" then
      label:SetText("")
    end
    if type(label.Hide) == "function" then
      label:Hide()
    end
  end

  local function HideExistingButtons()
    for _, button in ipairs(buttons) do
      if button and button.Hide then
        button:Hide()
      end
    end
  end

  local function ApplyVisibility()
    if isVisible then
      for _, button in ipairs(buttons) do
        if button and button.Show then
          button:Show()
        end
      end
    else
      HideExistingButtons()
      if emptyStateLabel and emptyStateLabel.Hide then
        emptyStateLabel:Hide()
      end
    end
  end

  local function BuildButtonsInternal()
    -- Hide old buttons before re-creating; CreateTeleportButton always builds
    -- a fresh frame, so the previous ones would otherwise stay parented to
    -- mainFrame with their secure attributes intact.
    HideExistingButtons()
    buttons = {}
    local entries = deps.getEntries()
    UpdateEmptyState(entries)
    for i, entry in ipairs(entries) do
      table.insert(buttons, CreateTeleportButton(mainFrame, deps, i, entry))
    end
    RelayoutButtons()
    ApplyVisibility()
  end

  function controller.BuildButtons()
    BuildButtonsInternal()
  end

  function controller.SetLayoutMode(layoutMode)
    deps.layoutMode = NormalizeLayoutMode(layoutMode or deps.layoutMode)
    RelayoutButtons()
  end

  function controller.GetLayoutMode()
    return deps.layoutMode
  end

  function controller.GetButtons()
    return buttons
  end

  function controller.SetVisible(visible)
    isVisible = visible and true or false
    if deps.logRuntimeTraceDeep then
      deps.logRuntimeTraceDeep(function()
        return string.format("[TP_UI] set_visible visible=%s buttonCount=%s", tostring(isVisible), tostring(#buttons))
      end)
    end
    if isVisible then
      UpdateEmptyState(deps.getEntries())
    end
    ApplyVisibility()
  end

  function controller.UpdateButtons(resolvedSpellID, soundContext)
    if deps.logRuntimeTraceDeep then
      deps.logRuntimeTraceDeep(function()
        return string.format(
          "[TP_UI] update_buttons resolvedSpellID=%s soundContext=%s visible=%s buttonCount=%s combat=%s",
          tostring(resolvedSpellID),
          tostring(soundContext),
          tostring(isVisible),
          tostring(#buttons),
          tostring(deps.isInCombat())
        )
      end)
    end
    if not isVisible then
      ApplyVisibility()
      return
    end

    for _, button in ipairs(buttons) do
      SyncButtonLayer(button, mainFrame, deps.isInCombat)

      -- Retry secure setup if missing (e.g. loaded in combat)
      if not button:GetAttribute("type") then
        deps.applySecureSpellToButton(button, button.spellID)
      end

      local known = deps.isSpellKnown(button.spellID)
      local levelBlocked = ResolveTeleportLevelBlocked(button, deps)
      local available = known and levelBlocked == false
      local icon = deps.getSpellTexture(button.spellID)
      button.icon:SetTexture(icon or button.defaultIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
      button.isActiveTarget = (resolvedSpellID and button.spellID == resolvedSpellID) and true or false
      button.cooldownRemainingSeconds = tonumber(deps.getTeleportCooldownRemaining(button.spellID)) or 0
      if deps.logRuntimeTraceDeep and button.isActiveTarget then
        deps.logRuntimeTraceDeep(function()
          return string.format(
            "[TP_UI] button_decision spellID=%s available=%s active=%s cooldown=%s soundContext=%s",
            tostring(button.spellID),
            tostring(available),
            tostring(button.isActiveTarget),
            tostring(button.cooldownRemainingSeconds),
            tostring(soundContext)
          )
        end)
      end

      if button.cooldownRemainingSeconds > 0 then
        local start, duration = 0, button.cooldownRemainingSeconds
        if type(deps.getCooldownFrameStartForRemaining) == "function" then
          start, duration = deps.getCooldownFrameStartForRemaining(button.cooldownRemainingSeconds)
        end
        deps.applyCooldownFrameSafe(button.cooldown, start, duration, true)
      else
        deps.applyCooldownFrameSafe(button.cooldown, 0, 0, false)
      end

      -- Show the active border even when the portal is unavailable,
      -- so the user knows which dungeon is the current target.
      if button.isActiveTarget then
        button.activeBorder:Show()
      else
        button.activeBorder:Hide()
      end

      if available then
        if button.isActiveTarget then
          button.overlay:SetColorTexture(unpack(Colors.STEEL_BLUE_OVERLAY or { 0.15, 0.35, 0.55, 0.25 }))
          if not button.animGroup:IsPlaying() then
            button.animGroup:Play()
          end
        else
          button.overlay:SetColorTexture(unpack(Colors.BLACK_OVERLAY_28 or { 0, 0, 0, 0.28 }))
          button.animGroup:Stop()
        end
      else
        button.overlay:SetColorTexture(unpack(Colors.BLACK_OVERLAY_62 or { 0, 0, 0, 0.62 }))
        button.animGroup:Stop()
      end

      button._portalSoundPrimed = true
      button._lastObservedActiveTarget = button.isActiveTarget and true or false

      UpdateTeleportButtonShortCodeLabel(button, deps)
    end
    UpdateEmptyState(deps.getEntries())
  end

  return controller
end
