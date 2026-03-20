local _, addonTable = ...

addonTable = addonTable or {}

local RI = addonTable._RosterInternal or {}
addonTable._RosterInternal = RI

local TOOLTIP_HORIZONTAL_PADDING = 10
local TOOLTIP_VERTICAL_PADDING = 10
local TOOLTIP_LINE_SPACING = 3
local TOOLTIP_MIN_HEIGHT = 28
local TOOLTIP_MIN_WIDTH = 220
local TOOLTIP_MAX_WIDTH = 280
local TOOLTIP_TEXT_WIDTH = TOOLTIP_MAX_WIDTH - (TOOLTIP_HORIZONTAL_PADDING * 2)

local function DisableFontStringWrapping(fontString)
  if fontString.SetWordWrap then
    fontString:SetWordWrap(false)
  end
  if fontString.SetNonSpaceWrap then
    fontString:SetNonSpaceWrap(false)
  end
  if fontString.SetMaxLines then
    fontString:SetMaxLines(1)
  end
end
RI.DisableFontStringWrapping = DisableFontStringWrapping

local function AcquireSimpleTooltipLine(tooltip, index)
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

local function LayoutSimpleTooltip(tooltip)
  if type(tooltip) ~= "table" then
    return
  end

  local lines = tooltip._isiLiveTooltipLines or {}
  local lineCount = tonumber(tooltip._isiLiveTooltipLineCount) or 0
  local tooltipHeight = TOOLTIP_VERTICAL_PADDING
  local tooltipWidth = TOOLTIP_MIN_WIDTH
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
        local measuredHeightNumber = ok and tonumber(measuredHeight) or nil
        if measuredHeightNumber and measuredHeightNumber > 0 then
          lineHeight = math.max(measuredHeightNumber, 14)
        end
      end
      tooltipHeight = tooltipHeight + lineHeight
      if previousLine ~= nil then
        tooltipHeight = tooltipHeight + TOOLTIP_LINE_SPACING
      end
      if type(line) == "table" and type(line.GetStringWidth) == "function" then
        local ok, measuredWidth = pcall(line.GetStringWidth, line)
        local measuredWidthNumber = ok and tonumber(measuredWidth) or nil
        if measuredWidthNumber and measuredWidthNumber > 0 then
          local paddedWidth = measuredWidthNumber + (TOOLTIP_HORIZONTAL_PADDING * 2)
          tooltipWidth = math.max(tooltipWidth, math.min(TOOLTIP_MAX_WIDTH, paddedWidth))
        end
      end
      previousLine = line
    end
  end
  tooltipHeight = tooltipHeight + TOOLTIP_VERTICAL_PADDING

  if type(tooltip.SetSize) == "function" then
    tooltip:SetSize(tooltipWidth, math.max(TOOLTIP_MIN_HEIGHT, tooltipHeight))
  elseif type(tooltip.SetWidth) == "function" and type(tooltip.SetHeight) == "function" then
    tooltip:SetWidth(tooltipWidth)
    tooltip:SetHeight(math.max(TOOLTIP_MIN_HEIGHT, tooltipHeight))
  elseif type(tooltip.SetHeight) == "function" then
    tooltip:SetHeight(math.max(TOOLTIP_MIN_HEIGHT, tooltipHeight))
  end
end

local function PositionSimpleTooltip(tooltip)
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

  if anchor == "ANCHOR_CURSOR" and type(rawget(_G, "GetCursorPosition")) == "function" then
    local tooltipParent = rawget(_G, "UIParent") or owner
    local x, y = rawget(_G, "GetCursorPosition")()
    local scale = 1
    if type(tooltipParent) == "table" and type(tooltipParent.GetEffectiveScale) == "function" then
      local ok, tooltipScale = pcall(tooltipParent.GetEffectiveScale, tooltipParent)
      local tooltipScaleNumber = ok and tonumber(tooltipScale) or nil
      if tooltipScaleNumber and tooltipScaleNumber > 0 then
        scale = tooltipScaleNumber
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

local function EnsureSimpleTooltipAPI(tooltip)
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
    PositionSimpleTooltip(self)
  end

  function tooltip:SetText(text, r, g, b)
    self:ClearLines()
    local line = AcquireSimpleTooltipLine(self, 1)
    if type(line) ~= "table" then
      return
    end
    if type(line.SetTextColor) == "function" then
      line:SetTextColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1)
    end
    if type(line.SetText) == "function" then
      line:SetText(tostring(text or ""))
    end
    if type(line.Show) == "function" then
      line:Show()
    end
    self._isiLiveTooltipLineCount = 1
    LayoutSimpleTooltip(self)
  end

  function tooltip:AddLine(text, r, g, b)
    local index = (tonumber(self._isiLiveTooltipLineCount) or 0) + 1
    local line = AcquireSimpleTooltipLine(self, index)
    if type(line) ~= "table" then
      return
    end
    if type(line.SetTextColor) == "function" then
      line:SetTextColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1)
    end
    if type(line.SetText) == "function" then
      line:SetText(tostring(text or ""))
    end
    if type(line.Show) == "function" then
      line:Show()
    end
    self._isiLiveTooltipLineCount = index
    LayoutSimpleTooltip(self)
  end

  function tooltip:Show()
    self._isiLiveTooltipShown = true
    PositionSimpleTooltip(self)
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
RI.EnsureSimpleTooltipAPI = EnsureSimpleTooltipAPI

local function CreateRosterHoverTooltip(mainFrame)
  local tooltipParent = rawget(_G, "UIParent") or mainFrame
  local tooltipFrame = CreateFrame("Frame", nil, tooltipParent, "BackdropTemplate")
  local tooltip = EnsureSimpleTooltipAPI(tooltipFrame)
  if type(tooltip) ~= "table" then
    return nil
  end

  local UICommon = addonTable and addonTable.UICommon
  if not (type(UICommon) == "table" and UICommon.ApplyBackdrop and UICommon.ApplyBackdrop(tooltip, "TOOLTIP")) then
    if type(tooltip.CreateTexture) == "function" then
      tooltip._isiLiveTooltipBackground = tooltip._isiLiveTooltipBackground or tooltip:CreateTexture(nil, "BACKGROUND")
      if type(tooltip._isiLiveTooltipBackground.SetAllPoints) == "function" then
        tooltip._isiLiveTooltipBackground:SetAllPoints()
      end
      if type(tooltip._isiLiveTooltipBackground.SetColorTexture) == "function" then
        tooltip._isiLiveTooltipBackground:SetColorTexture(0, 0, 0, 0.92)
      end
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
RI.CreateRosterHoverTooltip = CreateRosterHoverTooltip

local function HideRosterHoverTooltip(tooltip)
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end
RI.HideRosterHoverTooltip = HideRosterHoverTooltip

local function AnchorRosterHoverTooltip(tooltip, anchorFrame)
  tooltip = EnsureSimpleTooltipAPI(tooltip)
  if type(tooltip) ~= "table" then
    return nil
  end

  if type(tooltip.ClearLines) == "function" then
    tooltip:ClearLines()
  end
  if type(tooltip.SetOwner) == "function" then
    tooltip:SetOwner(anchorFrame, "ANCHOR_CURSOR")
  end
  tooltip._isiLiveTooltipOwner = anchorFrame
  tooltip._isiLiveTooltipAnchor = "ANCHOR_CURSOR"

  return tooltip
end
RI.AnchorRosterHoverTooltip = AnchorRosterHoverTooltip

local function BuildFallbackTooltipPlayerName(name, realm)
  local playerName = type(name) == "string" and name or nil
  if not playerName or playerName == "" then
    return nil
  end

  local playerRealm = type(realm) == "string" and realm or nil
  if playerRealm and playerRealm ~= "" then
    return string.format("%s-%s", playerName, playerRealm)
  end

  return playerName
end

local function FormatCompactTooltipNumber(value)
  local numericValue = tonumber(value)
  if not numericValue then
    return nil
  end

  local roundedValue = math.floor(numericValue + 0.5)
  local abbreviateNumbers = rawget(_G, "AbbreviateNumbers")
  if type(abbreviateNumbers) == "function" then
    local ok, abbreviated = pcall(abbreviateNumbers, roundedValue)
    if ok and type(abbreviated) == "string" and abbreviated ~= "" then
      return abbreviated
    end
  end

  local absoluteValue = math.abs(roundedValue)
  local units = {
    { limit = 1000000000, suffix = "B" },
    { limit = 1000000, suffix = "M" },
    { limit = 1000, suffix = "K" },
  }

  for _, unit in ipairs(units) do
    if absoluteValue >= unit.limit then
      local scaled = roundedValue / unit.limit
      local formatted = string.format("%.1f%s", scaled, unit.suffix)
      return formatted:gsub("%.0([KMB])$", "%1")
    end
  end

  return tostring(roundedValue)
end
RI.FormatCompactTooltipNumber = FormatCompactTooltipNumber

local function ShowRosterNameFallbackTooltip(tooltipFrame, anchorFrame, name, realm)
  local tooltipName = BuildFallbackTooltipPlayerName(name, realm)
  if not tooltipName then
    return false
  end

  local tooltip = AnchorRosterHoverTooltip(tooltipFrame, anchorFrame)
  if type(tooltip) ~= "table" or type(tooltip.SetText) ~= "function" then
    return false
  end

  tooltip:SetText(tooltipName)
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
  return true
end
RI.ShowRosterNameFallbackTooltip = ShowRosterNameFallbackTooltip

local function ResolveTooltipUnitLevel(unit, info)
  if type(unit) == "string" and unit ~= "" then
    local unitExists = rawget(_G, "UnitExists")
    if type(unitExists) == "function" then
      local okExists, exists = pcall(unitExists, unit)
      if okExists and exists then
        local unitLevel = rawget(_G, "UnitLevel")
        if type(unitLevel) == "function" then
          local ok, level = pcall(unitLevel, unit)
          local levelNumber = ok and tonumber(level) or nil
          if levelNumber and levelNumber > 0 then
            return math.floor(levelNumber)
          end
        end
      end
    end
  end

  local infoLevelNumber = type(info) == "table" and tonumber(info.level) or nil
  if infoLevelNumber and infoLevelNumber > 0 then
    return math.floor(infoLevelNumber)
  end

  return nil
end

local ENGLISH_CLASS_NAME_BY_TAG = {
  DEATHKNIGHT = "Death Knight",
  DEMONHUNTER = "Demon Hunter",
  DRUID = "Druid",
  EVOKER = "Evoker",
  HUNTER = "Hunter",
  MAGE = "Mage",
  MONK = "Monk",
  PALADIN = "Paladin",
  PRIEST = "Priest",
  ROGUE = "Rogue",
  SHAMAN = "Shaman",
  WARLOCK = "Warlock",
  WARRIOR = "Warrior",
}

local function ResolveTooltipClassName(info)
  if type(info) ~= "table" or type(info.class) ~= "string" or info.class == "" then
    return nil
  end

  local classTag = tostring(info.class):upper()
  local localizedMale = rawget(_G, "LOCALIZED_CLASS_NAMES_MALE")
  if type(localizedMale) == "table" and type(localizedMale[classTag]) == "string" and localizedMale[classTag] ~= "" then
    return localizedMale[classTag]
  end

  local localizedFemale = rawget(_G, "LOCALIZED_CLASS_NAMES_FEMALE")
  if
    type(localizedFemale) == "table"
    and type(localizedFemale[classTag]) == "string"
    and localizedFemale[classTag] ~= ""
  then
    return localizedFemale[classTag]
  end

  return ENGLISH_CLASS_NAME_BY_TAG[classTag] or info.class
end

local function ShowRosterInfoTooltip(
  tooltipFrame,
  anchorFrame,
  unit,
  info,
  getDungeonShortCode,
  getPlayerLastRunDps,
  getL
)
  if type(info) ~= "table" then
    return false
  end
  local name = type(info.name) == "string" and info.name ~= "" and info.name or nil
  if not name then
    return false
  end

  local lastRunDps = type(getPlayerLastRunDps) == "function" and getPlayerLastRunDps(info.name, info.realm) or nil
  local unitLevel = ResolveTooltipUnitLevel(unit, info)
  local className = ResolveTooltipClassName(info)
  local languageCode = type(info.language) == "string"
      and info.language ~= ""
      and tostring(info.language):upper():sub(1, 2)
    or nil

  -- Only show rich tooltip when actual addon-synced data is present beyond name/key
  local hasRichInfo = (type(info.class) == "string" and info.class ~= "")
    or (type(info.spec) == "string" and info.spec ~= "")
    or (tonumber(info.ilvl) and tonumber(info.ilvl) > 0)
    or (tonumber(info.rio) and tonumber(info.rio) > 0)
    or (tonumber(lastRunDps) and tonumber(lastRunDps) > 0)
    or (unitLevel and unitLevel > 0)
    or (languageCode and languageCode ~= "")
  if not hasRichInfo then
    return false
  end

  local tooltip = AnchorRosterHoverTooltip(tooltipFrame, anchorFrame)
  if type(tooltip) ~= "table" or type(tooltip.SetText) ~= "function" then
    return false
  end

  local classColors = rawget(_G, "RAID_CLASS_COLORS")
  local classColor = classColors and info.class and classColors[info.class]
  local titleText
  if classColor then
    local r = math.floor((classColor.r or 1) * 255)
    local g = math.floor((classColor.g or 1) * 255)
    local b = math.floor((classColor.b or 1) * 255)
    titleText = string.format("|cff%02x%02x%02x%s|r", r, g, b, name)
  else
    titleText = name
  end
  tooltip:SetText(titleText, 1, 1, 1)

  if type(tooltip.AddLine) == "function" then
    local realm = type(info.realm) == "string" and info.realm ~= "" and info.realm or nil
    if realm then
      tooltip:AddLine(realm, 0.7, 0.7, 0.7)
    end
    if unitLevel then
      tooltip:AddLine("Level: " .. tostring(unitLevel), 0.9, 0.9, 0.9)
    end
    if languageCode then
      tooltip:AddLine("Lang: " .. languageCode, 0.9, 0.9, 0.9)
    end
    if className then
      tooltip:AddLine("Class: " .. className, 0.9, 0.9, 0.9)
    elseif type(info.spec) == "string" and info.spec ~= "" then
      tooltip:AddLine(info.spec, 0.9, 0.9, 0.9)
    end
    if info.ilvl then
      tooltip:AddLine("iLvl: " .. tostring(math.floor(tonumber(info.ilvl) or 0)), 0.9, 0.9, 0.9)
    end
    if info.rio then
      tooltip:AddLine("Rio: " .. tostring(math.floor(tonumber(info.rio) or 0)), 0.9, 0.9, 0.9)
    end
    local keyMapID = tonumber(info.keyMapID)
    local keyLevel = tonumber(info.keyLevel)
    if keyMapID and keyMapID > 0 and keyLevel and keyLevel > 0 then
      local shortCode = type(getDungeonShortCode) == "function" and getDungeonShortCode(keyMapID) or nil
      if type(shortCode) ~= "string" or shortCode == "" then
        shortCode = "?"
      end
      tooltip:AddLine(string.format("Key: %s +%d", tostring(shortCode), keyLevel), 1, 0.85, 0)
    end

    if lastRunDps and lastRunDps > 0 then
      local L = type(getL) == "function" and getL() or {}
      local label = type(L.TOOLTIP_LAST_RUN_DPS) == "string" and L.TOOLTIP_LAST_RUN_DPS or "Last run DPS: %s"
      local formattedDps = FormatCompactTooltipNumber(lastRunDps) or tostring(math.floor(lastRunDps + 0.5))
      tooltip:AddLine(string.format(label, formattedDps), 0.4, 0.8, 1)
    end
  end

  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
  return true
end
RI.ShowRosterInfoTooltip = ShowRosterInfoTooltip
