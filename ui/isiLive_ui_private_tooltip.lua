local _, addonTable = ...

addonTable = addonTable or {}

-- Lua 5.1 (WoW client) exposes global `unpack`; Lua 5.4 (local tooling) only
-- has `table.unpack`. Bridge locally so this file works under both without
-- depending on the entrypoint script to have set up a global compat shim.
local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

-- Addon-owned private tooltip for UICommon: a plain BackdropTemplate frame
-- that mimics the small GameTooltip surface isiLive needs (SetOwner, SetText,
-- AddLine, SetSpellByID, Show, Hide) without touching the shared GameTooltip.
--
-- Extracted from `ui/isiLive_ui_common.lua` along a clear UI responsibility.
-- Loaded before ui_common (TOC order); ui_common calls
-- `UIPrivateTooltip.Install(UICommon)` at the point where this block used to
-- live, so `UICommon.CreatePrivateTooltip` & co. exist at the same time as
-- before (notice.lua asserts it at load time) and no caller changes. Helpers
-- read `UICommon.*` lazily at call time.
local UIPrivateTooltip = {}
addonTable.UIPrivateTooltip = UIPrivateTooltip

-- Bound by Install; every helper below runs only after that.
local UICommon

local TOOLTIP_HORIZONTAL_PADDING = 10
local TOOLTIP_VERTICAL_PADDING = 10
local TOOLTIP_LINE_SPACING = 3
local TOOLTIP_MIN_HEIGHT = 28
local TOOLTIP_WIDTH = 220
local TOOLTIP_TEXT_WIDTH = TOOLTIP_WIDTH - (TOOLTIP_HORIZONTAL_PADDING * 2)

local function AcquireTooltipLine(tooltip, index)
  if type(tooltip) ~= "table" or type(index) ~= "number" or index < 1 then
    return nil
  end

  tooltip._isiLiveTooltipLines = tooltip._isiLiveTooltipLines or {}
  local line = tooltip._isiLiveTooltipLines[index]
  if line or type(tooltip.CreateFontString) ~= "function" then
    return line
  end

  line = tooltip:CreateFontString(nil, "OVERLAY", index == 1 and "GameTooltipHeaderText" or "GameTooltipText")
  if type(line.SetWidth) == "function" then
    line:SetWidth(TOOLTIP_TEXT_WIDTH)
  end
  if type(line.SetJustifyH) == "function" then
    line:SetJustifyH("LEFT")
  end
  if type(line.SetWordWrap) == "function" then
    line:SetWordWrap(true)
  end
  if type(line.SetNonSpaceWrap) == "function" then
    line:SetNonSpaceWrap(true)
  end
  if type(line.SetMaxLines) == "function" then
    line:SetMaxLines(0)
  end
  tooltip._isiLiveTooltipLines[index] = line
  return line
end

local function LayoutTooltipLines(tooltip)
  if type(tooltip) ~= "table" then
    return
  end

  local lines = tooltip._isiLiveTooltipLines or {}
  local lineCount = tonumber(tooltip._isiLiveTooltipLineCount) or 0
  local tooltipHeight = TOOLTIP_VERTICAL_PADDING
  local previousLine = nil
  for index, line in ipairs(lines) do
    local isActiveLine = index <= lineCount
    if type(line) == "table" and type(line.SetPoint) == "function" then
      if type(line.ClearAllPoints) == "function" then
        line:ClearAllPoints()
      end
      if previousLine == nil then
        line:SetPoint("TOPLEFT", tooltip, "TOPLEFT", TOOLTIP_HORIZONTAL_PADDING, -TOOLTIP_VERTICAL_PADDING)
      else
        line:SetPoint("TOPLEFT", previousLine, "BOTTOMLEFT", 0, -TOOLTIP_LINE_SPACING)
      end
    end
    if isActiveLine then
      local lineHeight = 16
      if type(line) == "table" and type(line.GetStringHeight) == "function" then
        local ok, measuredHeight = pcall(line.GetStringHeight, line)
        local measuredHeightValue = tonumber(measuredHeight)
        if ok and measuredHeightValue and measuredHeightValue > 0 then
          lineHeight = math.max(measuredHeightValue, 14)
        end
      end
      tooltipHeight = tooltipHeight + lineHeight
      if previousLine ~= nil then
        tooltipHeight = tooltipHeight + TOOLTIP_LINE_SPACING
      end
      previousLine = line
    end
  end
  tooltipHeight = tooltipHeight + TOOLTIP_VERTICAL_PADDING

  if type(tooltip.SetSize) == "function" then
    tooltip:SetSize(TOOLTIP_WIDTH, math.max(TOOLTIP_MIN_HEIGHT, tooltipHeight))
  elseif type(tooltip.SetWidth) == "function" and type(tooltip.SetHeight) == "function" then
    tooltip:SetWidth(TOOLTIP_WIDTH)
    tooltip:SetHeight(math.max(TOOLTIP_MIN_HEIGHT, tooltipHeight))
  elseif type(tooltip.SetHeight) == "function" then
    tooltip:SetHeight(math.max(TOOLTIP_MIN_HEIGHT, tooltipHeight))
  end
end

local function PositionPrivateTooltip(tooltip)
  if type(tooltip) ~= "table" then
    return
  end

  if type(tooltip.ClearAllPoints) == "function" then
    tooltip:ClearAllPoints()
  end

  local owner = tooltip._isiLiveTooltipOwner
  local anchor = tooltip._isiLiveTooltipAnchor or "ANCHOR_CURSOR"
  if type(tooltip.SetPoint) ~= "function" then
    return
  end

  if anchor == "ANCHOR_TOP" and owner then
    tooltip:SetPoint("BOTTOM", owner, "TOP", 0, 8)
    return
  end

  if anchor == "ANCHOR_CURSOR" and type(rawget(_G, "GetCursorPosition")) == "function" then
    local tooltipParent = rawget(_G, "UIParent") or owner
    local x, y = rawget(_G, "GetCursorPosition")()
    local scale = 1
    if type(tooltipParent) == "table" and type(tooltipParent.GetEffectiveScale) == "function" then
      local ok, tooltipScale = pcall(tooltipParent.GetEffectiveScale, tooltipParent)
      local tooltipScaleValue = tonumber(tooltipScale)
      if ok and tooltipScaleValue and tooltipScaleValue > 0 then
        scale = tooltipScaleValue
      end
    end

    if tooltipParent then
      tooltip:SetPoint("BOTTOMLEFT", tooltipParent, "BOTTOMLEFT", (x / scale) + 16, (y / scale) + 16)
      return
    end
  end

  if owner then
    tooltip:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
  end
end

-- Modern API first, legacy global last. The order matters: the global
-- GetSpellInfo is the deprecated pre-11.0 signature and only survives as a
-- compatibility shim, so it must never win over C_Spell. Mirrors
-- ResolveSpellNameByID in isiLive_ui_game_menu_mounts.lua -- keep the two in
-- step if either changes.
local function ResolveSpellName(spellID)
  local spellAPI = rawget(_G, "C_Spell")

  local getSpellName = type(spellAPI) == "table" and spellAPI.GetSpellName or nil
  if type(getSpellName) == "function" then
    local ok, spellName = pcall(getSpellName, spellID)
    if ok and type(spellName) == "string" and spellName ~= "" then
      return spellName
    end
  end

  local getSpellInfo = type(spellAPI) == "table" and spellAPI.GetSpellInfo or nil
  if type(getSpellInfo) == "function" then
    local ok, spellInfo = pcall(getSpellInfo, spellID)
    if ok and type(spellInfo) == "table" and type(spellInfo.name) == "string" and spellInfo.name ~= "" then
      return spellInfo.name
    end
  end

  local legacyGetSpellInfo = rawget(_G, "GetSpellInfo")
  if type(legacyGetSpellInfo) == "function" then
    local ok, spellName = pcall(legacyGetSpellInfo, spellID)
    if ok and type(spellName) == "string" and spellName ~= "" then
      return spellName
    end
  end

  return nil
end

local function EnsurePrivateTooltipAPI(tooltip)
  if type(tooltip) ~= "table" then
    return nil
  end
  if tooltip._isiLiveTooltipReady == true then
    return tooltip
  end

  tooltip._isiLiveTooltipReady = true
  tooltip._isIsiLiveTooltip = true
  tooltip._isiLiveTooltipNativeShow = tooltip.Show
  tooltip._isiLiveTooltipNativeHide = tooltip.Hide

  function tooltip:ClearLines()
    local lines = self._isiLiveTooltipLines or {}
    for _, line in ipairs(lines) do
      if type(line) == "table" and type(line.Hide) == "function" then
        line:Hide()
      end
    end
    self._isiLiveTooltipLineCount = 0
  end

  function tooltip:SetOwner(anchorFrame, anchor)
    self._isiLiveTooltipOwner = anchorFrame
    self._isiLiveTooltipAnchor = anchor
    PositionPrivateTooltip(self)
  end

  function tooltip:SetText(text, r, g, b)
    self:ClearLines()
    local line = AcquireTooltipLine(self, 1)
    if type(line) ~= "table" then
      return
    end
    if type(line.SetTextColor) == "function" then
      line:SetTextColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1)
    end
    UICommon.SetReadableText(line, text)
    if type(line.Show) == "function" then
      line:Show()
    end
    self._isiLiveTooltipLineCount = 1
    LayoutTooltipLines(self)
  end

  function tooltip:AddLine(text, r, g, b)
    local index = (tonumber(self._isiLiveTooltipLineCount) or 0) + 1
    local line = AcquireTooltipLine(self, index)
    if type(line) ~= "table" then
      return
    end
    if type(line.SetTextColor) == "function" then
      line:SetTextColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1)
    end
    UICommon.SetReadableText(line, text)
    if type(line.Show) == "function" then
      line:Show()
    end
    self._isiLiveTooltipLineCount = index
    LayoutTooltipLines(self)
  end

  function tooltip:SetSpellByID(spellID)
    local spellName = ResolveSpellName(spellID) or ("Spell " .. tostring(spellID or "?"))
    self:SetText(spellName, 1, 1, 1)
  end

  function tooltip:Show()
    self._isiLiveTooltipShown = true
    PositionPrivateTooltip(self)
    if type(self._isiLiveTooltipNativeShow) == "function" then
      pcall(self._isiLiveTooltipNativeShow, self)
    end
  end

  function tooltip:Hide()
    self._isiLiveTooltipShown = false
    self:ClearLines()
    if type(self._isiLiveTooltipNativeHide) == "function" then
      pcall(self._isiLiveTooltipNativeHide, self)
    end
  end

  return tooltip
end

local function CreatePrivateTooltip(parent)
  local tooltipParent = rawget(_G, "UIParent") or parent
  local tooltipFrame = CreateFrame("Frame", nil, tooltipParent, "BackdropTemplate")
  local tooltip = EnsurePrivateTooltipAPI(tooltipFrame)
  if type(tooltip) ~= "table" then
    return nil
  end

  if not UICommon.ApplyBackdrop(tooltip, "TOOLTIP") and type(tooltip.CreateTexture) == "function" then
    tooltip._isiLiveTooltipBackground = tooltip._isiLiveTooltipBackground or tooltip:CreateTexture(nil, "BACKGROUND")
    if type(tooltip._isiLiveTooltipBackground.SetAllPoints) == "function" then
      tooltip._isiLiveTooltipBackground:SetAllPoints()
    end
    if type(tooltip._isiLiveTooltipBackground.SetColorTexture) == "function" then
      tooltip._isiLiveTooltipBackground:SetColorTexture(unpack(UICommon.Colors.TOOLTIP_BG_BLACK))
    end
  end

  if type(tooltip.SetFrameStrata) == "function" then
    tooltip:SetFrameStrata("TOOLTIP")
  end
  if type(tooltip.SetClampedToScreen) == "function" then
    tooltip:SetClampedToScreen(true)
  end
  if type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end

  return tooltip
end

local function PreparePrivateTooltip(tooltip, anchorFrame, anchor)
  tooltip = EnsurePrivateTooltipAPI(tooltip)
  if type(tooltip) ~= "table" then
    return nil
  end

  if type(tooltip.ClearLines) == "function" then
    tooltip:ClearLines()
  end

  local resolvedAnchor = type(anchor) == "string" and anchor or "ANCHOR_CURSOR"
  if type(tooltip.SetOwner) == "function" then
    tooltip:SetOwner(anchorFrame, resolvedAnchor)
  end
  tooltip._isiLiveTooltipOwner = anchorFrame
  tooltip._isiLiveTooltipAnchor = resolvedAnchor

  return tooltip
end

local function HidePrivateTooltip(tooltip)
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end

-- Attaches the private tooltip surface to the UICommon facade. Called exactly
-- once by ui/isiLive_ui_common.lua while that file loads.
function UIPrivateTooltip.Install(target)
  UICommon = target
  target.CreatePrivateTooltip = CreatePrivateTooltip
  target.PreparePrivateTooltip = PreparePrivateTooltip
  target.HidePrivateTooltip = HidePrivateTooltip
end
