local _, addonTable = ...

addonTable = addonTable or {}

local RosterPanel = {}
addonTable.RosterPanel = RosterPanel

local SPEC_COL_X = 4
local NAME_COL_X = 80
local SERVER_COL_X = 202
local KEY_COL_X = 222
local ILVL_COL_X = 284
local RIO_COL_X = 314
local DPS_COL_X = 388
local SPEC_COL_WIDTH = 52
local NAME_COL_WIDTH = 134
local SERVER_COL_WIDTH = 14
local KEY_COL_WIDTH = 56
local ILVL_COL_WIDTH = 24
local RIO_COL_WIDTH = 70
local DPS_COL_WIDTH = 58
local TOOLTIP_HORIZONTAL_PADDING = 10
local TOOLTIP_VERTICAL_PADDING = 10
local TOOLTIP_LINE_SPACING = 3
local TOOLTIP_MIN_HEIGHT = 28
local TOOLTIP_WIDTH = 200
local TOOLTIP_TEXT_WIDTH = TOOLTIP_WIDTH - (TOOLTIP_HORIZONTAL_PADDING * 2)
local SYSTEM_OPTION_TOGGLE_LEFT_MARGIN = 10
local SYSTEM_OPTION_TOGGLE_BOTTOM_OFFSET = 24
local SYSTEM_OPTION_TOGGLE_GAP = 18

-- Layout Konstanten
local FULL_FRAME_WIDTH = 780
local MINI_FRAME_WIDTH = 320 -- Tank Helfer (-275) + M+ Buttons (-136) + Teleport

local function RequireFunction(value, name)
  assert(type(value) == "function", "isiLive: RosterPanel requires " .. name)
  return value
end

local function IsCombatLockdownActive()
  return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function SendPartyChatMessage(message)
  if type(message) ~= "string" or message == "" then
    return false
  end

  local sendChatMessage = C_ChatInfo and C_ChatInfo.SendChatMessage or nil

  if type(sendChatMessage) == "function" then
    local ok = pcall(sendChatMessage, message, "PARTY")
    if ok then
      return true
    end
  end

  return false
end

local function BuildKeystoneLinkText(shortCode, keyLevel)
  local level = math.floor(tonumber(keyLevel) or 0)
  return string.format("%s +%d", tostring(shortCode or "?"), level)
end

local function TryGetOwnedKeystoneLink(getOwnedKeystoneLink, keyLevel)
  if type(getOwnedKeystoneLink) ~= "function" then
    return nil
  end

  local ok, ownedLink = pcall(getOwnedKeystoneLink)
  if not ok or type(ownedLink) ~= "string" or ownedLink == "" then
    return nil
  end
  if ownedLink:find("|Hkeystone:", 1, true) == nil then
    return nil
  end

  local linkLevel = tonumber(string.match(ownedLink, "|Hkeystone:%d+:%d+:(%-?%d+):"))
  local expectedLevel = tonumber(keyLevel)
  if linkLevel and expectedLevel and linkLevel ~= math.floor(expectedLevel) then
    return nil
  end

  return ownedLink
end

local function BuildKeyAnnouncement(opts)
  local L = opts.getL()
  local roster = opts.getRoster()
  local buildOrderedRoster = opts.buildOrderedRoster
  local rolePriority = opts.rolePriority
  local unitPriority = opts.unitPriority
  local getDungeonShortCode = opts.getDungeonShortCode
  local applyKnownKeyToRosterEntry = opts.applyKnownKeyToRosterEntry
  local getOwnedKeystoneLink = opts.getOwnedKeystoneLink
  local lines = {}
  local ordered = buildOrderedRoster(roster, rolePriority, unitPriority)
  for _, entry in ipairs(ordered) do
    local info = entry.info
    if type(info) == "table" then
      local currentMapID = tonumber(info.keyMapID)
      local currentLevel = tonumber(info.keyLevel)
      local hasCurrentKey = currentMapID and currentMapID > 0 and currentLevel and currentLevel > 0

      if type(applyKnownKeyToRosterEntry) == "function" then
        -- Only backfill missing keys from sync cache.
        -- Never overwrite already-visible key data with empty cache state.
        if not hasCurrentKey then
          applyKnownKeyToRosterEntry(info)
        end
      end

      local keyMapID = tonumber(info.keyMapID)
      local keyLevel = tonumber(info.keyLevel)
      if keyMapID and keyMapID > 0 and keyLevel and keyLevel > 0 then
        local short = getDungeonShortCode(keyMapID)
        local announcePrefix = tostring(L.ANNOUNCE_PREFIX or "PartyKeys:")
        announcePrefix = announcePrefix:gsub("%s+", "")
        local prefixText = string.format("%s %s", tostring(L.TITLE or "isiKeyMPlus"), announcePrefix)
        local nameText = tostring(info.name or "?")
        local keyText = BuildKeystoneLinkText(short, keyLevel)
        local keyLink = nil
        if entry.unit == "player" then
          keyLink = TryGetOwnedKeystoneLink(getOwnedKeystoneLink, keyLevel)
        end
        table.insert(lines, string.format("%s %s -> %s", prefixText, nameText, tostring(keyLink or keyText)))
      end
    end
  end

  if #lines == 0 then
    return nil
  end

  return lines
end

local function CreateStatusLine(mainFrame)
  local statusLine = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  statusLine:SetPoint("BOTTOMLEFT", 10, 6)
  statusLine:SetJustifyH("LEFT")
  statusLine:SetText("")
  return statusLine
end

local function CreateVersionLine(mainFrame, getAddonVersionText)
  local versionLine = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  versionLine:SetPoint("BOTTOMRIGHT", -10, 6)
  versionLine:SetJustifyH("RIGHT")
  versionLine:SetText(getAddonVersionText())
  return versionLine
end

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

local function ResolveGetCVar()
  local cvarAPI = rawget(_G, "C_CVar")
  if type(cvarAPI) == "table" and type(cvarAPI.GetCVar) == "function" then
    return cvarAPI.GetCVar
  end
  if type(_G.GetCVar) == "function" then
    return _G.GetCVar
  end
  return nil
end

local function ResolveSetCVar()
  local cvarAPI = rawget(_G, "C_CVar")
  if type(cvarAPI) == "table" and type(cvarAPI.SetCVar) == "function" then
    return cvarAPI.SetCVar
  end
  if type(_G.SetCVar) == "function" then
    return _G.SetCVar
  end
  return nil
end

local function ReadCVarEnabled(cvarName)
  if type(cvarName) ~= "string" or cvarName == "" then
    return false
  end
  local getCVar = ResolveGetCVar()
  if not getCVar then
    return false
  end
  local ok, value = pcall(getCVar, cvarName)
  if not ok then
    return false
  end
  return tostring(value or "") == "1"
end

local function WriteCVarEnabled(cvarName, enabled)
  if type(cvarName) ~= "string" or cvarName == "" then
    return false
  end
  local setCVar = ResolveSetCVar()
  if not setCVar then
    return false
  end
  local ok = pcall(setCVar, cvarName, enabled and "1" or "0")
  return ok
end

local function RefreshSystemOptionToggle(button)
  if type(button) ~= "table" or type(button._cvarName) ~= "string" then
    return false
  end
  local enabled = ReadCVarEnabled(button._cvarName)
  if button.SetChecked then
    button:SetChecked(enabled)
  end
  return enabled
end

local function CreateSystemOptionToggle(mainFrame, cvarName)
  local button = CreateFrame("CheckButton", nil, mainFrame, "UICheckButtonTemplate")
  button:SetSize(18, 18)
  button._cvarName = cvarName

  local label = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("LEFT", button, "RIGHT", 4, 0)
  label:SetJustifyH("LEFT")
  DisableFontStringWrapping(label)
  button.label = label

  button:SetScript("OnClick", function(self)
    local enabled = self.GetChecked and self:GetChecked() or false
    WriteCVarEnabled(self._cvarName, enabled)
    RefreshSystemOptionToggle(self)
  end)

  RefreshSystemOptionToggle(button)
  return button
end

local function CreateCustomOptionToggle(mainFrame, getterFn, setterFn)
  local button = CreateFrame("CheckButton", nil, mainFrame, "UICheckButtonTemplate")
  button:SetSize(18, 18)

  local label = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("LEFT", button, "RIGHT", 4, 0)
  label:SetJustifyH("LEFT")
  DisableFontStringWrapping(label)
  button.label = label

  if button.SetChecked then
    button:SetChecked(getterFn())
  end

  button:SetScript("OnClick", function(self)
    local enabled = self.GetChecked and self:GetChecked() or false
    setterFn(enabled)
  end)

  return button
end

local function LayoutSystemOptionToggles(ui)
  if type(ui) ~= "table" then
    return
  end

  local advancedCombatLoggingToggle = ui.advancedCombatLoggingToggle
  local damageMeterResetToggle = ui.damageMeterResetToggle

  if advancedCombatLoggingToggle and advancedCombatLoggingToggle.SetPoint then
    if advancedCombatLoggingToggle.ClearAllPoints then
      advancedCombatLoggingToggle:ClearAllPoints()
    end
    advancedCombatLoggingToggle:SetPoint(
      "BOTTOMLEFT",
      SYSTEM_OPTION_TOGGLE_LEFT_MARGIN,
      SYSTEM_OPTION_TOGGLE_BOTTOM_OFFSET
    )
  end

  if damageMeterResetToggle and damageMeterResetToggle.SetPoint then
    if damageMeterResetToggle.ClearAllPoints then
      damageMeterResetToggle:ClearAllPoints()
    end
    damageMeterResetToggle:SetPoint(
      "LEFT",
      advancedCombatLoggingToggle and advancedCombatLoggingToggle.label or nil,
      "RIGHT",
      SYSTEM_OPTION_TOGGLE_GAP,
      0
    )
  end
end

local function CreateSystemOptionToggles(mainFrame)
  local ui = {
    advancedCombatLoggingToggle = CreateSystemOptionToggle(mainFrame, "advancedCombatLogging"),
    damageMeterResetToggle = CreateSystemOptionToggle(mainFrame, "damageMeterResetOnNewInstance"),
  }

  LayoutSystemOptionToggles(ui)
  return ui
end

local function RefreshSystemOptionToggles(ui)
  if type(ui) ~= "table" then
    return
  end
  RefreshSystemOptionToggle(ui.advancedCombatLoggingToggle)
  RefreshSystemOptionToggle(ui.damageMeterResetToggle)
end

local function AttachSystemOptionToggleWatcher(mainFrame, ui)
  local watcher = CreateFrame("Frame", nil, mainFrame)
  local elapsedSinceRefresh = 0

  watcher:SetScript("OnUpdate", function(_, elapsed)
    local isShown = true
    if type(mainFrame) == "table" and type(mainFrame.IsShown) == "function" then
      isShown = mainFrame:IsShown()
    end
    if not isShown then
      elapsedSinceRefresh = 0
      return
    end

    elapsedSinceRefresh = elapsedSinceRefresh + (tonumber(elapsed) or 0)
    if elapsedSinceRefresh < 5 then
      return
    end

    elapsedSinceRefresh = 0
    RefreshSystemOptionToggles(ui)
  end)

  ui.systemOptionWatcher = watcher
end

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
        if ok and tonumber(measuredHeight) and tonumber(measuredHeight) > 0 then
          lineHeight = math.max(tonumber(measuredHeight), 14)
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
      if ok and tonumber(tooltipScale) and tonumber(tooltipScale) > 0 then
        scale = tonumber(tooltipScale)
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

local function CreateRosterHoverTooltip(mainFrame)
  local tooltipParent = rawget(_G, "UIParent") or mainFrame
  local tooltip = CreateFrame("Frame", nil, tooltipParent, "BackdropTemplate")
  tooltip = EnsureSimpleTooltipAPI(tooltip)
  if type(tooltip) ~= "table" then
    return nil
  end

  if type(tooltip.SetBackdrop) == "function" then
    tooltip:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    if type(tooltip.SetBackdropColor) == "function" then
      tooltip:SetBackdropColor(0, 0, 0, 0.92)
    end
  elseif type(tooltip.CreateTexture) == "function" then
    tooltip._isiLiveTooltipBackground = tooltip._isiLiveTooltipBackground or tooltip:CreateTexture(nil, "BACKGROUND")
    if type(tooltip._isiLiveTooltipBackground.SetAllPoints) == "function" then
      tooltip._isiLiveTooltipBackground:SetAllPoints()
    end
    if type(tooltip._isiLiveTooltipBackground.SetColorTexture) == "function" then
      tooltip._isiLiveTooltipBackground:SetColorTexture(0, 0, 0, 0.92)
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

local function HideRosterHoverTooltip(tooltip)
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end

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

local function ResolveTooltipUnitLevel(unit, info)
  if type(unit) == "string" and unit ~= "" then
    local unitLevel = rawget(_G, "UnitLevel")
    if type(unitLevel) == "function" then
      local ok, level = pcall(unitLevel, unit)
      if ok and tonumber(level) and tonumber(level) > 0 then
        return math.floor(tonumber(level))
      end
    end
  end

  if type(info) == "table" and tonumber(info.level) and tonumber(info.level) > 0 then
    return math.floor(tonumber(info.level))
  end

  return nil
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
    if type(info.spec) == "string" and info.spec ~= "" then
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

local function CreateMemberRow(mainFrame, index, rosterTooltip)
  local yOffset = -52 - (index - 1) * 16
  local row = {}

  row.hoverFrame = CreateFrame("Frame", nil, mainFrame)
  row.hoverFrame:SetPoint("TOPLEFT", 4, yOffset + 2)
  -- Hover-Bereich endet an der rechten Kante der DPS-Spalte (DPS_COL_X + DPS_COL_WIDTH).
  -- Die Buttons (Readycheck, Countdown etc.) rechts davon lösen den Tooltip nicht aus.
  row.hoverFrame:SetWidth(DPS_COL_X + DPS_COL_WIDTH - 4)
  row.hoverFrame:SetHeight(16)
  if row.hoverFrame.EnableMouse then
    row.hoverFrame:EnableMouse(true)
  end

  row.hoverFrame:SetScript("OnMouseUp", function(_, button)
    if not row.unit then
      return
    end

    if button == "RightButton" then
      local name = row.tooltipName
      if name then
        local target = (row.tooltipRealm and row.tooltipRealm ~= "") and (name .. "-" .. row.tooltipRealm) or name
        local openChat = _G.ChatFrame_OpenChat
        if type(openChat) == "function" then
          pcall(openChat, "/w " .. target .. " ")
        end
      end
    end
  end)

  row.highlight = row.hoverFrame:CreateTexture(nil, "BACKGROUND")
  row.highlight:SetAllPoints()
  row.highlight:SetColorTexture(1, 1, 1, 0.05)
  row.highlight:Hide()

  row.hoverFrame:SetScript("OnEnter", function()
    row.highlight:Show()
    if
      not ShowRosterInfoTooltip(
        rosterTooltip,
        row.hoverFrame,
        row.unit,
        row.tooltipInfo,
        row.getDungeonShortCode,
        row.getPlayerLastRunDps,
        row.getL
      )
    then
      ShowRosterNameFallbackTooltip(rosterTooltip, row.hoverFrame, row.tooltipName, row.tooltipRealm)
    end
  end)
  row.hoverFrame:SetScript("OnLeave", function()
    row.highlight:Hide()
    HideRosterHoverTooltip(rosterTooltip)
  end)

  row.roleButton = CreateFrame("Button", nil, mainFrame, "SecureActionButtonTemplate")
  row.roleButton:SetSize(14, 14)
  row.roleButton:SetPoint("TOPLEFT", NAME_COL_X, yOffset - 1)
  row.roleButton.icon = row.roleButton:CreateTexture(nil, "ARTWORK")
  row.roleButton.icon:SetAllPoints()
  row.roleButton.icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
  row.roleButton:SetScript("OnEnter", function(self)
    local tooltip = AnchorRosterHoverTooltip(rosterTooltip, self)
    if type(tooltip) == "table" and type(tooltip.SetText) == "function" then
      tooltip:SetText("Role Marker", 1, 1, 1)
      if type(tooltip.AddLine) == "function" then
        tooltip:AddLine("Click to mark unit", 1, 1, 1, true)
        tooltip:AddLine("Tank: Blue Square", 0.2, 0.4, 1, true)
        tooltip:AddLine("Healer: Green Triangle", 0.2, 1, 0.2, true)
      end
      tooltip:Show()
    end
  end)
  row.roleButton:SetScript("OnLeave", function()
    HideRosterHoverTooltip(rosterTooltip)
  end)

  row.spec = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.spec:SetPoint("TOPLEFT", SPEC_COL_X, yOffset)
  row.spec:SetJustifyH("RIGHT")
  row.spec:SetWidth(SPEC_COL_WIDTH)
  DisableFontStringWrapping(row.spec)

  row.name = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.name:SetPoint("TOPLEFT", NAME_COL_X + 16, yOffset)
  row.name:SetJustifyH("LEFT")
  row.name:SetWidth(NAME_COL_WIDTH - 16)
  DisableFontStringWrapping(row.name)

  row.ilvl = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.ilvl:SetPoint("TOPLEFT", ILVL_COL_X, yOffset)
  row.ilvl:SetWidth(ILVL_COL_WIDTH)
  row.ilvl:SetJustifyH("RIGHT")
  DisableFontStringWrapping(row.ilvl)

  row.key = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.key:SetPoint("TOPLEFT", KEY_COL_X, yOffset)
  row.key:SetWidth(KEY_COL_WIDTH)
  row.key:SetJustifyH("RIGHT")
  DisableFontStringWrapping(row.key)

  row.rio = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.rio:SetPoint("TOPLEFT", RIO_COL_X, yOffset)
  row.rio:SetWidth(RIO_COL_WIDTH)
  row.rio:SetJustifyH("RIGHT")
  DisableFontStringWrapping(row.rio)

  row.dps = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.dps:SetPoint("TOPLEFT", DPS_COL_X, yOffset)
  row.dps:SetWidth(DPS_COL_WIDTH)
  row.dps:SetJustifyH("RIGHT")
  DisableFontStringWrapping(row.dps)

  row.realm = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.realm:SetPoint("TOPLEFT", SERVER_COL_X, yOffset)
  row.realm:SetWidth(SERVER_COL_WIDTH)
  row.realm:SetJustifyH("LEFT")
  DisableFontStringWrapping(row.realm)

  return row
end

local function AttachControllerAccessors(controller, deps)
  function controller.GetRefreshButton()
    return deps.refreshButton
  end

  function controller.GetCountdownCancelButton()
    return deps.countdownCancelButton
  end

  function controller.GetStatusLine()
    return deps.statusLine
  end

  function controller.SetCountdownCancelText(text)
    deps.countdownCancelButton:SetText(tostring(text or ""))
  end
end

local function CreatePanelHeaders(mainFrame)
  local specHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  specHeader:SetPoint("TOPLEFT", SPEC_COL_X, -34)
  specHeader:SetWidth(SPEC_COL_WIDTH)
  specHeader:SetJustifyH("RIGHT")

  local nameHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  nameHeader:SetPoint("TOPLEFT", NAME_COL_X, -34)
  nameHeader:SetWidth(NAME_COL_WIDTH)
  nameHeader:SetJustifyH("LEFT")

  local ilvlHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ilvlHeader:SetPoint("TOPLEFT", ILVL_COL_X, -34)
  ilvlHeader:SetWidth(ILVL_COL_WIDTH)
  ilvlHeader:SetJustifyH("RIGHT")

  local serverHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  serverHeader:SetPoint("TOPLEFT", SERVER_COL_X, -34)
  serverHeader:SetWidth(SERVER_COL_WIDTH)
  serverHeader:SetJustifyH("LEFT")

  local keyHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  keyHeader:SetPoint("TOPLEFT", KEY_COL_X, -34)
  keyHeader:SetWidth(KEY_COL_WIDTH)
  keyHeader:SetJustifyH("RIGHT")
  if keyHeader.SetWordWrap then
    keyHeader:SetWordWrap(false)
  end
  if keyHeader.SetNonSpaceWrap then
    keyHeader:SetNonSpaceWrap(false)
  end
  if keyHeader.SetMaxLines then
    keyHeader:SetMaxLines(1)
  end

  local rioHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  rioHeader:SetPoint("TOPLEFT", RIO_COL_X, -34)
  rioHeader:SetWidth(RIO_COL_WIDTH)
  rioHeader:SetJustifyH("RIGHT")
  if rioHeader.SetWordWrap then
    rioHeader:SetWordWrap(false)
  end
  if rioHeader.SetNonSpaceWrap then
    rioHeader:SetNonSpaceWrap(false)
  end
  if rioHeader.SetMaxLines then
    rioHeader:SetMaxLines(1)
  end

  local dpsHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  dpsHeader:SetPoint("TOPLEFT", DPS_COL_X, -34)
  dpsHeader:SetWidth(DPS_COL_WIDTH)
  dpsHeader:SetJustifyH("RIGHT")
  if dpsHeader.SetWordWrap then
    dpsHeader:SetWordWrap(false)
  end
  if dpsHeader.SetNonSpaceWrap then
    dpsHeader:SetNonSpaceWrap(false)
  end
  if dpsHeader.SetMaxLines then
    dpsHeader:SetMaxLines(1)
  end

  local leadOptionsHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  leadOptionsHeader:SetPoint("TOPRIGHT", -136, -34)
  leadOptionsHeader:SetWidth(120)
  leadOptionsHeader:SetJustifyH("CENTER")

  local mplusManagementHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mplusManagementHeader:SetPoint("TOPRIGHT", -16, -34)
  mplusManagementHeader:SetWidth(110)
  mplusManagementHeader:SetJustifyH("CENTER")

  local headerSeparator = mainFrame:CreateTexture(nil, "ARTWORK")
  headerSeparator:SetHeight(1)
  headerSeparator:SetPoint("TOPLEFT", 8, -48)
  headerSeparator:SetPoint("TOPRIGHT", -8, -48)
  headerSeparator:SetColorTexture(1, 1, 1, 0.2)

  return {
    specHeader = specHeader,
    nameHeader = nameHeader,
    ilvlHeader = ilvlHeader,
    serverHeader = serverHeader,
    keyHeader = keyHeader,
    rioHeader = rioHeader,
    dpsHeader = dpsHeader,
    leadOptionsHeader = leadOptionsHeader,
    mplusManagementHeader = mplusManagementHeader,
  }
end

local function AttachPanelButtonTooltip(tooltipFrame, button, getL, titleKey, descriptionKey, isPlayerLeader)
  button:SetScript("OnEnter", function(self)
    local tooltip = AnchorRosterHoverTooltip(tooltipFrame, self)
    if type(tooltip) ~= "table" then
      return
    end

    local L = getL()
    if type(tooltip.SetText) == "function" then
      tooltip:SetText(L[titleKey], 1, 1, 1)
    end
    if type(tooltip.AddLine) == "function" then
      tooltip:AddLine(L[descriptionKey], 1, 1, 1, true)
      if isPlayerLeader and not isPlayerLeader() then
        tooltip:AddLine(L.TOOLTIP_LEAD_REQUIRED, 1, 0.2, 0.2, true)
      end
    end
    if type(tooltip.Show) == "function" then
      tooltip:Show()
    end
  end)
  button:SetScript("OnLeave", function()
    HideRosterHoverTooltip(tooltipFrame)
  end)
end

local function CreateShareKeysButton(mainFrame, deps)
  local button = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  button:SetSize(120, 24)
  button:SetPoint("TOPRIGHT", -136, -180)
  local lastShareKeysClickAt = nil
  local debounceSeconds = tonumber(deps.shareKeysDebounceSeconds) or 0
  if debounceSeconds < 0 then
    debounceSeconds = 0
  end
  button:SetScript("OnClick", function()
    local now = type(deps.getTime) == "function" and tonumber(deps.getTime()) or nil
    if now and debounceSeconds > 0 and lastShareKeysClickAt and (now - lastShareKeysClickAt) < debounceSeconds then
      return
    end
    if now then
      lastShareKeysClickAt = now
    end

    local lines = BuildKeyAnnouncement({
      getL = deps.getL,
      getRoster = deps.getRoster,
      buildOrderedRoster = deps.buildOrderedRoster,
      rolePriority = deps.rolePriority,
      unitPriority = deps.unitPriority,
      getDungeonShortCode = deps.getDungeonShortCode,
      applyKnownKeyToRosterEntry = deps.applyKnownKeyToRosterEntry,
      getOwnedKeystoneLink = deps.getOwnedKeystoneLink,
    })
    if not lines then
      return
    end
    if deps.isInGroup() then
      for _, line in ipairs(lines) do
        if not SendPartyChatMessage(line) then
          print(line)
        end
      end
    else
      for _, line in ipairs(lines) do
        print(line)
      end
    end
  end)
  AttachPanelButtonTooltip(deps.tooltipFrame, button, deps.getL, "BTN_SHARE_KEYS", "TOOLTIP_ANNOUNCE_KEYS", nil)
  return button
end

local function CreatePanelButtons(mainFrame, deps)
  local getL = deps.getL
  local isPlayerLeader = deps.isPlayerLeader

  local readyCheckButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  readyCheckButton:SetSize(120, 24)
  readyCheckButton:SetPoint("TOPRIGHT", -136, -60)
  readyCheckButton:SetScript("OnClick", function()
    if not isPlayerLeader() then
      return
    end
    local doReadyCheck = _G.DoReadyCheck
    if type(doReadyCheck) == "function" then
      pcall(doReadyCheck)
    end
  end)
  AttachPanelButtonTooltip(deps.tooltipFrame, readyCheckButton, getL, "BTN_READYCHECK", "TOOLTIP_READY", isPlayerLeader)

  local countdownButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  countdownButton:SetSize(120, 24)
  countdownButton:SetPoint("TOPRIGHT", -136, -90)
  countdownButton:SetScript("OnClick", function()
    if not isPlayerLeader() then
      return
    end

    local partyInfo = rawget(_G, "C_PartyInfo")
    local doCountdown = partyInfo and partyInfo.DoCountdown or nil
    if type(doCountdown) == "function" then
      pcall(doCountdown, 10)
    end
  end)
  AttachPanelButtonTooltip(deps.tooltipFrame, countdownButton, getL, "BTN_COUNTDOWN10", "TOOLTIP_CD10", isPlayerLeader)

  local refreshButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  refreshButton:SetSize(120, 24)
  refreshButton:SetPoint("TOPRIGHT", -136, -150)
  AttachPanelButtonTooltip(deps.tooltipFrame, refreshButton, getL, "BTN_REFRESH", "TOOLTIP_REFRESH", nil)

  local shareKeysButton = CreateShareKeysButton(mainFrame, deps)

  local countdownCancelButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  countdownCancelButton:SetSize(120, 24)
  countdownCancelButton:SetPoint("TOPRIGHT", -136, -120)
  AttachPanelButtonTooltip(
    deps.tooltipFrame,
    countdownCancelButton,
    getL,
    "BTN_COUNTDOWN_CANCEL",
    "TOOLTIP_CD_CANCEL",
    isPlayerLeader
  )

  return {
    readyCheckButton = readyCheckButton,
    countdownButton = countdownButton,
    refreshButton = refreshButton,
    shareKeysButton = shareKeysButton,
    countdownCancelButton = countdownCancelButton,
  }
end

local function CreateTankHelperButtons(mainFrame, tooltipFrame, getL)
  local markers = {
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6", id = 6, name = "Square (Blue)" }, -- Blue
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4", id = 4, name = "Triangle (Green)" }, -- Green
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", id = 3, name = "Diamond (Purple)" }, -- Purple
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7", id = 7, name = "Cross (Red)" }, -- Red
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", id = 1, name = "Star (Yellow)" }, -- Yellow
  }

  local buttons = {}
  local startY = -60
  local size = 24
  local gap = 6

  -- Position: Rechts von der DPS-Spalte, links von den M+ Management Buttons
  local xPos = -275

  for i, marker in ipairs(markers) do
    local btn = CreateFrame("Button", nil, mainFrame, "SecureActionButtonTemplate")
    btn:SetSize(size, size)
    btn:SetPoint("TOPRIGHT", xPos, startY - ((i - 1) * (size + gap)))

    if btn.SetNormalTexture then
      btn:SetNormalTexture(marker.icon)
    end
    if btn.SetAttribute then
      btn:SetAttribute("type1", "macro") -- Left click
      btn:SetAttribute("macrotext1", "/wm " .. marker.id)
      btn:SetAttribute("type2", "macro") -- Right click
      btn:SetAttribute("macrotext2", "/cwm " .. marker.id)
    end
    if btn.RegisterForClicks then
      btn:RegisterForClicks("AnyUp", "AnyDown")
    end

    btn:SetScript("OnEnter", function(self)
      local tooltip = AnchorRosterHoverTooltip(tooltipFrame, self)
      if type(tooltip) == "table" and type(tooltip.SetText) == "function" then
        tooltip:SetText("World Marker: " .. marker.name, 1, 1, 1)
        if type(tooltip.AddLine) == "function" then
          tooltip:AddLine("Left-Click: Place", 0, 1, 0)
          tooltip:AddLine("Right-Click: Clear", 1, 0.2, 0.2)
        end
        tooltip:Show()
      end
    end)
    btn:SetScript("OnLeave", function()
      HideRosterHoverTooltip(tooltipFrame)
    end)

    table.insert(buttons, btn)
  end

  local header = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  header:SetPoint("TOPRIGHT", xPos - 15, -34)
  header:SetWidth(60)
  header:SetJustifyH("CENTER")
  local L = getL()
  header:SetText(L.TANK_HELPER_HEADER or "Tank Helper")

  return buttons, header
end

local function UpdateCollapseState(ui, isCollapsed, mainFrame)
  if mainFrame.SetWidth then
    mainFrame:SetWidth(isCollapsed and MINI_FRAME_WIDTH or FULL_FRAME_WIDTH)
  end

  if ui.collapseButton then
    local tex = isCollapsed and "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
      or "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up"
    if ui.collapseButton.SetNormalTexture then
      ui.collapseButton:SetNormalTexture(tex)
    end
    if ui.collapseButton.SetPushedTexture then
      ui.collapseButton:SetPushedTexture(tex)
    end
  end

  local function SetVisible(obj, show)
    if obj and obj.SetShown then
      obj:SetShown(show)
    end
  end
  local show = not isCollapsed

  SetVisible(ui.specHeader, show)
  SetVisible(ui.nameHeader, show)
  SetVisible(ui.ilvlHeader, show)
  SetVisible(ui.serverHeader, show)
  SetVisible(ui.keyHeader, show)
  SetVisible(ui.rioHeader, show)
  SetVisible(ui.dpsHeader, show)
  SetVisible(ui.statusLine, show)

  if ui.advancedCombatLoggingToggle then
    SetVisible(ui.advancedCombatLoggingToggle, show)
    SetVisible(ui.advancedCombatLoggingToggle.label, show)
  end
  if ui.damageMeterResetToggle then
    SetVisible(ui.damageMeterResetToggle, show)
    SetVisible(ui.damageMeterResetToggle.label, show)
  end

  if ui.memberRows then
    for _, row in pairs(ui.memberRows) do
      SetVisible(row.spec, show)
      SetVisible(row.name, show)
      SetVisible(row.ilvl, show)
      SetVisible(row.key, show)
      SetVisible(row.rio, show)
      SetVisible(row.dps, show)
      SetVisible(row.realm, show)
      if row.roleButton and not IsCombatLockdownActive() then
        SetVisible(row.roleButton, show)
      end
    end
  end
end

local function NotifyCollapseChanged(ui, isCollapsed)
  if type(ui) == "table" and type(ui.onCollapseChanged) == "function" then
    ui.onCollapseChanged(isCollapsed and true or false)
  end
end

local function CreateCollapseButton(mainFrame, onClick)
  local btn = CreateFrame("Button", nil, mainFrame)
  btn:SetSize(20, 20)
  btn:SetPoint("TOPRIGHT", -24, -2)
  if btn.SetNormalTexture then
    btn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
  end
  if btn.SetHighlightTexture then
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
  end
  btn:SetScript("OnClick", onClick)
  return btn
end

local function ConstructPanelUI(mainFrame, uiDeps)
  -- Background for visibility
  mainFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  mainFrame:SetBackdropColor(0, 0, 0, 0.85)
  if mainFrame.SetWidth then
    mainFrame:SetWidth(FULL_FRAME_WIDTH)
  end

  local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
  title:SetPoint("TOP", 0, -4)
  do
    local fontPath, fontSize, fontFlags = title:GetFont()
    if fontPath and fontSize then
      title:SetFont(fontPath, math.max(fontSize - 2, 8), fontFlags)
    end
  end
  title:SetTextColor(1, 0.85, 0)
  title:SetShadowOffset(1, -1)

  local headers = CreatePanelHeaders(mainFrame)
  local panelTooltip = CreateRosterHoverTooltip(mainFrame)
  local buttonDeps = {}
  for key, value in pairs(uiDeps) do
    buttonDeps[key] = value
  end
  buttonDeps.tooltipFrame = panelTooltip
  local buttons = CreatePanelButtons(mainFrame, buttonDeps)
  local rosterTooltip = CreateRosterHoverTooltip(mainFrame)
  local tankButtons, tankHeader = CreateTankHelperButtons(mainFrame, panelTooltip, uiDeps.getL)

  local statusLine = CreateStatusLine(mainFrame)
  local optionToggles = CreateSystemOptionToggles(mainFrame)
  CreateVersionLine(mainFrame, uiDeps.getAddonVersionText)

  local raidNoticeLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  raidNoticeLabel:SetPoint("TOP", 0, -100)
  local frameWidth = type(mainFrame.GetWidth) == "function" and mainFrame:GetWidth() or 400
  raidNoticeLabel:SetWidth(frameWidth - 16)
  raidNoticeLabel:SetJustifyH("CENTER")
  raidNoticeLabel:SetTextColor(1, 0.5, 0)
  raidNoticeLabel:SetWordWrap(true)
  raidNoticeLabel:Hide()

  local ui = {
    panelTooltip = panelTooltip,
    rosterTooltip = rosterTooltip,
    title = title,
    statusLine = statusLine,
    raidNoticeLabel = raidNoticeLabel,
    tankButtons = tankButtons,
    tankHeader = tankHeader,
  }
  for k, v in pairs(headers) do
    ui[k] = v
  end
  for k, v in pairs(buttons) do
    ui[k] = v
  end
  for k, v in pairs(optionToggles) do
    ui[k] = v
  end

  ui.isCollapsed = false
  ui.collapseButton = CreateCollapseButton(mainFrame, function()
    if IsCombatLockdownActive() then
      return
    end
    ui.isCollapsed = not ui.isCollapsed
    if IsiLiveDB then
      IsiLiveDB.rosterCollapsed = ui.isCollapsed
    end
    UpdateCollapseState(ui, ui.isCollapsed, mainFrame)
    NotifyCollapseChanged(ui, ui.isCollapsed)
  end)
  UpdateCollapseState(ui, false, mainFrame)

  AttachSystemOptionToggleWatcher(mainFrame, ui)
  return ui
end

local function RenderRosterImpl(state, roster)
  local memberRows = state.memberRows
  local mainFrame = state.mainFrame
  local shareKeysButton = state.shareKeysButton
  local rosterTooltip = state.rosterTooltip
  local setMainFrameHeightSafe = state.setMainFrameHeightSafe
  local minFrameHeight = state.minFrameHeight
  local raidNoticeLabel = state.raidNoticeLabel

  if state.uiRef then
    state.uiRef.memberRows = memberRows
  end
  local isCollapsed = state.uiRef and state.uiRef.isCollapsed

  -- If in a raid group, show the notice and hide rows
  if state.isRaidGroup and state.isRaidGroup() then
    for _, row in pairs(memberRows) do
      row.spec:SetText("")
      row.name:SetText("")
      row.realm:SetText("")
      row.key:SetText("")
      row.ilvl:SetText("")
      row.rio:SetText("")
      row.dps:SetText("")
      if row.hoverFrame then
        row.hoverFrame:Hide()
      end
      if row.roleButton then
        if not IsCombatLockdownActive() then
          row.roleButton:Hide()
        else
          -- Combat deferral handled by secure driver usually, but here we just accept state until regen
        end
      end
    end
    if raidNoticeLabel then
      local L = state.getL and state.getL() or {}
      raidNoticeLabel:SetText(L.RAID_GROUP_HIDDEN or "Raid group detected. Addon paused.")
      raidNoticeLabel:Show()
    end
    setMainFrameHeightSafe(minFrameHeight)
    return
  end

  -- Normal case: hide notice, show rows
  if raidNoticeLabel then
    raidNoticeLabel:Hide()
  end

  if isCollapsed then
    -- No need to render rows if collapsed
  end

  for _, row in pairs(memberRows) do
    row.spec:SetText("")
    row.name:SetText("")
    row.realm:SetText("")
    row.key:SetText("")
    row.ilvl:SetText("")
    row.rio:SetText("")
    row.dps:SetText("")
    row.unit = nil
    row.tooltipName = nil
    row.tooltipRealm = nil
    row.tooltipInfo = nil
    row.getDungeonShortCode = nil
    row.getPlayerLastRunDps = nil
    row.getL = nil
    if row.hoverFrame then
      HideRosterHoverTooltip(rosterTooltip)
      row.hoverFrame.unit = nil
      row.hoverFrame:Hide()
    end

    if row.roleButton then
      if not IsCombatLockdownActive() then
        row.roleButton:Hide()
      else
        -- Defer hide if needed or accept stale state in combat
      end
    end
  end

  local index = 1
  local orderedRoster = state.buildOrderedRoster(roster, state.rolePriority, state.unitPriority)
  local hasFullSync = state.hasFullSyncFn(roster)
  local activeKeyOwnerUnit = state.resolveActiveKeyOwnerUnit()
  local isReadyCheckActive = state.isReadyCheckActive and state.isReadyCheckActive() or false
  local targetMapID = state.resolveTargetMapID and state.resolveTargetMapID() or nil
  local hasAnyKey = false

  for _, entry in ipairs(orderedRoster) do
    if index > 5 then
      break
    end

    local info = entry.info
    if info.keyLevel and tonumber(info.keyLevel) > 0 then
      hasAnyKey = true
    end

    local row = memberRows[index]
    if not row then
      row = CreateMemberRow(mainFrame, index, rosterTooltip)
      memberRows[index] = row
    end

    local isAtDungeon = false
    if targetMapID and entry.unit then
      local mapApi = rawget(_G, "C_Map")
      local getBestMapForUnit = mapApi and mapApi.GetBestMapForUnit or nil
      if type(getBestMapForUnit) == "function" then
        local ok, playerMapID = pcall(getBestMapForUnit, entry.unit)
        if ok and playerMapID and tonumber(playerMapID) == tonumber(targetMapID) then
          isAtDungeon = true
        end
      end
    end

    if row.roleButton then
      local role = info.role
      local icon = row.roleButton.icon
      local showButton = false

      if role == "TANK" then
        icon:SetTexCoord(0, 19 / 64, 22 / 64, 41 / 64)
        showButton = true
      elseif role == "HEALER" then
        icon:SetTexCoord(20 / 64, 39 / 64, 1 / 64, 20 / 64)
        showButton = true
      elseif role == "DAMAGER" then
        icon:SetTexCoord(20 / 64, 39 / 64, 22 / 64, 41 / 64)
        showButton = true
      end

      if not IsCombatLockdownActive() then
        if showButton and not isCollapsed then
          row.roleButton:Show()
          row.roleButton:SetAttribute("unit", entry.unit)
          row.roleButton:SetAttribute("type", "macro")
          if role == "TANK" then
            -- Blue Square = 6
            row.roleButton:SetAttribute("macrotext", "/tm @" .. entry.unit .. " 6")
          elseif role == "HEALER" then
            -- Green Triangle = 4
            row.roleButton:SetAttribute("macrotext", "/tm @" .. entry.unit .. " 4")
          else
            row.roleButton:SetAttribute("macrotext", nil)
          end
        else
          row.roleButton:Hide()
        end
      end
    end

    local displayData = state.buildDisplayData(info, {
      unit = entry.unit,
      truncateName = state.truncateName,
      getShortSpecLabel = state.getShortSpecLabel,
      getLanguageFlagMarkup = state.getLanguageFlagMarkup,
      getDungeonShortCode = state.getDungeonShortCode,
      getRioDelta = state.getRioDelta,
      syncMarker = state.syncMarker,
      fullSyncMarker = state.fullSyncMarker,
      hasFullSync = hasFullSync,
      isReadyCheckActive = isReadyCheckActive,
      isAtDungeon = isAtDungeon,
    })

    row.spec:SetText("|c" .. displayData.colorHex .. displayData.specText .. "|r")
    -- Skip displayData.roleIconMarkup since we render it as a secure button
    row.name:SetText(
      (displayData.readyCheckMarkup or "")
        .. " |c"
        .. displayData.colorHex
        .. displayData.displayName
        .. "|r"
        .. displayData.atDungeonMarker
        .. displayData.addonMarker
    )
    row.realm:SetText(displayData.languageDisplay)
    if displayData.keyText ~= "-" and activeKeyOwnerUnit and entry.unit == activeKeyOwnerUnit then
      row.key:SetText("|cffff4040" .. displayData.keyText .. "|r")
    else
      row.key:SetText(displayData.keyText)
    end
    row.ilvl:SetText(displayData.ilvlText)
    row.rio:SetText(displayData.rioText)
    row.dps:SetText(
      type(state.getPlayerLastRunDps) == "function"
          and (FormatCompactTooltipNumber(state.getPlayerLastRunDps(info.name, info.realm)) or "-")
        or "-"
    )
    row.unit = entry.unit
    row.tooltipName = info and info.name or nil
    row.tooltipRealm = info and info.realm or nil
    row.tooltipInfo = info
    row.getDungeonShortCode = state.getDungeonShortCode
    row.getPlayerLastRunDps = state.getPlayerLastRunDps
    row.getL = state.getL
    if row.hoverFrame then
      row.hoverFrame.unit = entry.unit
      row.hoverFrame:Show()
      if isCollapsed then
        row.hoverFrame:Hide()
      end
    end
    index = index + 1
  end

  shareKeysButton:SetEnabled(hasAnyKey)
  shareKeysButton:SetAlpha(hasAnyKey and 1 or 0.45)

  local desiredHeight = math.max(minFrameHeight, 45 + index * 16)
  setMainFrameHeightSafe(desiredHeight)

  if state.uiRef then
    UpdateCollapseState(state.uiRef, isCollapsed, mainFrame)
  end
end

function RosterPanel.CreateController(opts)
  opts = opts or {}

  local mainFrame = assert(opts.mainFrame, "isiLive: RosterPanel requires mainFrame")
  local getL = RequireFunction(opts.getL, "getL")
  local isPlayerLeader = RequireFunction(opts.isPlayerLeader, "isPlayerLeader")
  local getAddonVersionText = RequireFunction(opts.getAddonVersionText, "getAddonVersionText")
  local updateStatusLine = RequireFunction(opts.updateStatusLine, "updateStatusLine")
  local setMainFrameHeightSafe = RequireFunction(opts.setMainFrameHeightSafe, "setMainFrameHeightSafe")
  local minFrameHeight = tonumber(opts.minFrameHeight) or 212

  local buildOrderedRoster = RequireFunction(opts.buildOrderedRoster, "buildOrderedRoster")
  local hasFullSyncFn = RequireFunction(opts.hasFullSync, "hasFullSync")
  local buildDisplayData = RequireFunction(opts.buildDisplayData, "buildDisplayData")
  local truncateName = RequireFunction(opts.truncateName, "truncateName")
  local getShortSpecLabel = RequireFunction(opts.getShortSpecLabel, "getShortSpecLabel")
  local getLanguageFlagMarkup = RequireFunction(opts.getLanguageFlagMarkup, "getLanguageFlagMarkup")
  local getDungeonShortCode = RequireFunction(opts.getDungeonShortCode, "getDungeonShortCode")
  local getRioDelta = type(opts.getRioDelta) == "function" and opts.getRioDelta or nil
  local resolveActiveKeyOwnerUnit = RequireFunction(opts.resolveActiveKeyOwnerUnit, "resolveActiveKeyOwnerUnit")
  local getRoster = RequireFunction(opts.getRoster, "getRoster")
  local isReadyCheckActive = type(opts.isReadyCheckActive) == "function" and opts.isReadyCheckActive or nil
  local resolveTargetMapID = type(opts.resolveTargetMapID) == "function" and opts.resolveTargetMapID or nil
  local isInGroup = RequireFunction(opts.isInGroup, "isInGroup")
  local isRaidGroup = type(opts.isRaidGroup) == "function" and opts.isRaidGroup or function()
    return false
  end
  local rolePriority = assert(opts.rolePriority, "isiLive: RosterPanel requires rolePriority")
  local unitPriority = assert(opts.unitPriority, "isiLive: RosterPanel requires unitPriority")
  local syncMarker = tostring(opts.syncMarker or "")
  local fullSyncMarker = tostring(opts.fullSyncMarker or "")
  local applyKnownKeyToRosterEntry = type(opts.applyKnownKeyToRosterEntry) == "function"
      and opts.applyKnownKeyToRosterEntry
    or nil
  local getOwnedKeystoneLink = type(opts.getOwnedKeystoneLink) == "function" and opts.getOwnedKeystoneLink
    or function()
      local mythicPlusApi = rawget(_G, "C_MythicPlus")
      local linkFn = mythicPlusApi and mythicPlusApi.GetOwnedKeystoneLink
      if type(linkFn) == "function" then
        return linkFn()
      end
      return nil
    end
  local getTime = type(opts.getTime) == "function" and opts.getTime
    or function()
      if type(GetTime) == "function" then
        return GetTime()
      end
      return nil
    end
  local shareKeysDebounceSeconds = tonumber(opts.shareKeysDebounceSeconds) or 1
  if shareKeysDebounceSeconds < 0 then
    shareKeysDebounceSeconds = 0
  end
  local getPlayerLastRunDps = type(opts.getPlayerLastRunDps) == "function" and opts.getPlayerLastRunDps or nil

  local ui = ConstructPanelUI(mainFrame, {
    getL = getL,
    isPlayerLeader = isPlayerLeader,
    getAddonVersionText = getAddonVersionText,
    updateStatusLine = updateStatusLine,
    getRoster = getRoster,
    buildOrderedRoster = buildOrderedRoster,
    rolePriority = rolePriority,
    unitPriority = unitPriority,
    getDungeonShortCode = getDungeonShortCode,
    applyKnownKeyToRosterEntry = applyKnownKeyToRosterEntry,
    getOwnedKeystoneLink = getOwnedKeystoneLink,
    isInGroup = isInGroup,
    getTime = getTime,
    shareKeysDebounceSeconds = shareKeysDebounceSeconds,
  })

  local readyCheckButton = ui.readyCheckButton
  local countdownButton = ui.countdownButton
  local refreshButton = ui.refreshButton
  local shareKeysButton = ui.shareKeysButton
  local countdownCancelButton = ui.countdownCancelButton

  local memberRows = {}

  local controller = {}

  function controller.ApplyLocalization()
    local L = getL()
    ui.title:SetText(L.TITLE)
    ui.specHeader:SetText(L.COL_SPEC)
    ui.nameHeader:SetText(L.COL_NAME)
    ui.serverHeader:SetText(L.COL_LANGUAGE)
    ui.keyHeader:SetText(L.COL_KEY)
    ui.ilvlHeader:SetText(L.COL_ILVL)
    ui.rioHeader:SetText(L.COL_RIO)
    ui.dpsHeader:SetText(L.COL_DPS)
    ui.leadOptionsHeader:SetText(L.LEAD_OPTIONS)
    ui.mplusManagementHeader:SetText(L.MPLUS_MANAGEMENT)
    readyCheckButton:SetText(L.BTN_READYCHECK)
    countdownButton:SetText(L.BTN_COUNTDOWN10)
    countdownCancelButton:SetText(L.BTN_COUNTDOWN_CANCEL)
    refreshButton:SetText(L.BTN_REFRESH)
    shareKeysButton:SetText(L.BTN_SHARE_KEYS)
    ui.advancedCombatLoggingToggle.label:SetText(L.OPT_ADVANCED_COMBAT_LOGGING)
    ui.damageMeterResetToggle.label:SetText(L.OPT_DAMAGE_METER_RESET)
    LayoutSystemOptionToggles(ui)
    RefreshSystemOptionToggles(ui)
  end

  function controller.IsCollapsed()
    return ui.isCollapsed
  end

  function controller.RestoreSavedState()
    if IsiLiveDB and IsiLiveDB.rosterCollapsed ~= nil then
      ui.isCollapsed = IsiLiveDB.rosterCollapsed
      UpdateCollapseState(ui, ui.isCollapsed, mainFrame)
      NotifyCollapseChanged(ui, ui.isCollapsed)
    end
  end

  function controller.SetCollapseChangedHandler(handler)
    ui.onCollapseChanged = type(handler) == "function" and handler or nil
  end

  function controller.UpdateLeaderButtons()
    local enabled = isPlayerLeader()
    readyCheckButton:SetEnabled(enabled)
    countdownButton:SetEnabled(enabled)
    countdownCancelButton:SetEnabled(enabled)
    readyCheckButton:SetAlpha(enabled and 1 or 0.45)
    countdownButton:SetAlpha(enabled and 1 or 0.45)
    countdownCancelButton:SetAlpha(enabled and 1 or 0.45)
    RefreshSystemOptionToggles(ui)
    updateStatusLine()
  end

  function controller.RenderRoster(roster)
    RenderRosterImpl({
      memberRows = memberRows,
      mainFrame = mainFrame,
      shareKeysButton = shareKeysButton,
      rosterTooltip = ui.rosterTooltip,
      setMainFrameHeightSafe = setMainFrameHeightSafe,
      minFrameHeight = minFrameHeight,
      buildOrderedRoster = buildOrderedRoster,
      rolePriority = rolePriority,
      unitPriority = unitPriority,
      hasFullSyncFn = hasFullSyncFn,
      resolveActiveKeyOwnerUnit = resolveActiveKeyOwnerUnit,
      isReadyCheckActive = isReadyCheckActive,
      resolveTargetMapID = resolveTargetMapID,
      buildDisplayData = buildDisplayData,
      truncateName = truncateName,
      getShortSpecLabel = getShortSpecLabel,
      getLanguageFlagMarkup = getLanguageFlagMarkup,
      getDungeonShortCode = getDungeonShortCode,
      getRioDelta = getRioDelta,
      syncMarker = syncMarker,
      fullSyncMarker = fullSyncMarker,
      getPlayerLastRunDps = getPlayerLastRunDps,
      getL = getL,
      isRaidGroup = isRaidGroup,
      raidNoticeLabel = ui.raidNoticeLabel,
      uiRef = ui,
    }, roster)
    RefreshSystemOptionToggles(ui)
  end

  function controller.RefreshSystemOptionToggles()
    RefreshSystemOptionToggles(ui)
  end

  AttachControllerAccessors(controller, {
    refreshButton = refreshButton,
    countdownCancelButton = countdownCancelButton,
    statusLine = ui.statusLine,
  })

  return controller
end
