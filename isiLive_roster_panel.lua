local _, addonTable = ...

addonTable = addonTable or {}

local RosterPanel = {}
addonTable.RosterPanel = RosterPanel

local SPEC_COL_X = 10
local NAME_COL_X = 110
local SERVER_COL_X = 240
local KEY_COL_X = 292
local ILVL_COL_X = 370
local RIO_COL_X = 396
local SPEC_COL_WIDTH = 92
local NAME_COL_WIDTH = 125
local SERVER_COL_WIDTH = 50
local KEY_COL_WIDTH = 72
local ILVL_COL_WIDTH = 35
local RIO_COL_WIDTH = 88

local function RequireFunction(value, name)
  assert(type(value) == "function", "isiLive: RosterPanel requires " .. name)
  return value
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
        local keyText = BuildKeystoneLinkText(short or keyMapID, keyLevel)
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

local function CreateSystemOptionToggle(mainFrame, cvarName, xOffset)
  local button = CreateFrame("CheckButton", nil, mainFrame, "UICheckButtonTemplate")
  button:SetSize(18, 18)
  button:SetPoint("BOTTOMLEFT", xOffset, 24)
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

local function CreateSystemOptionToggles(mainFrame)
  local advancedCombatLoggingToggle = CreateSystemOptionToggle(mainFrame, "advancedCombatLogging", 10)
  local damageMeterResetToggle = CreateSystemOptionToggle(mainFrame, "damageMeterResetOnNewInstance", 220)

  return {
    advancedCombatLoggingToggle = advancedCombatLoggingToggle,
    damageMeterResetToggle = damageMeterResetToggle,
  }
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

local function HideGlobalGameTooltip()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end

local function AnchorGlobalGameTooltip(anchorFrame)
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" then
    return nil
  end

  local setDefaultAnchor = rawget(_G, "GameTooltip_SetDefaultAnchor")
  if type(setDefaultAnchor) == "function" then
    setDefaultAnchor(tooltip, anchorFrame)
  elseif type(tooltip.SetOwner) == "function" then
    tooltip:SetOwner(anchorFrame, "ANCHOR_CURSOR_RIGHT")
  end

  return tooltip
end

local function ShowRosterUnitTooltip(anchorFrame, unit)
  if type(unit) ~= "string" or unit == "" then
    return false
  end

  if type(UnitExists) == "function" and not UnitExists(unit) then
    return false
  end

  local tooltip = AnchorGlobalGameTooltip(anchorFrame)
  if type(tooltip) ~= "table" or type(tooltip.SetUnit) ~= "function" then
    return false
  end

  tooltip:SetUnit(unit)
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
  return true
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

local function ShowRosterNameFallbackTooltip(anchorFrame, name, realm)
  local tooltipName = BuildFallbackTooltipPlayerName(name, realm)
  if not tooltipName then
    return false
  end

  local tooltip = AnchorGlobalGameTooltip(anchorFrame)
  if type(tooltip) ~= "table" or type(tooltip.SetText) ~= "function" then
    return false
  end

  tooltip:SetText(tooltipName)
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
  return true
end

local function CreateMemberRow(mainFrame, index)
  local yOffset = -52 - (index - 1) * 16
  local row = {}

  row.hoverFrame = CreateFrame("Frame", nil, mainFrame)
  row.hoverFrame:SetPoint("TOPLEFT", 4, yOffset + 2)
  row.hoverFrame:SetPoint("RIGHT", -4, 0)
  row.hoverFrame:SetHeight(16)
  if row.hoverFrame.EnableMouse then
    row.hoverFrame:EnableMouse(true)
  end

  row.highlight = row.hoverFrame:CreateTexture(nil, "BACKGROUND")
  row.highlight:SetAllPoints()
  row.highlight:SetColorTexture(1, 1, 1, 0.05)
  row.highlight:Hide()

  row.hoverFrame:SetScript("OnEnter", function()
    row.highlight:Show()
    if not ShowRosterUnitTooltip(row.hoverFrame, row.unit) then
      ShowRosterNameFallbackTooltip(row.hoverFrame, row.tooltipName, row.tooltipRealm)
    end
  end)
  row.hoverFrame:SetScript("OnLeave", function()
    row.highlight:Hide()
    HideGlobalGameTooltip()
  end)

  row.spec = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.spec:SetPoint("TOPLEFT", SPEC_COL_X, yOffset)
  row.spec:SetJustifyH("RIGHT")
  row.spec:SetWidth(SPEC_COL_WIDTH)
  DisableFontStringWrapping(row.spec)

  row.name = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.name:SetPoint("TOPLEFT", NAME_COL_X, yOffset)
  row.name:SetJustifyH("LEFT")
  row.name:SetWidth(NAME_COL_WIDTH)
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
    leadOptionsHeader = leadOptionsHeader,
    mplusManagementHeader = mplusManagementHeader,
  }
end

local function AttachPanelButtonTooltip(button, getL, titleKey, descriptionKey, isPlayerLeader)
  button:SetScript("OnEnter", function(self)
    local L = getL()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L[titleKey], 1, 1, 1)
    GameTooltip:AddLine(L[descriptionKey], 1, 1, 1, true)
    if isPlayerLeader and not isPlayerLeader() then
      GameTooltip:AddLine(L.TOOLTIP_LEAD_REQUIRED, 1, 0.2, 0.2, true)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
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
  AttachPanelButtonTooltip(button, deps.getL, "BTN_SHARE_KEYS", "TOOLTIP_ANNOUNCE_KEYS", nil)
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
    DoReadyCheck()
  end)
  AttachPanelButtonTooltip(readyCheckButton, getL, "BTN_READYCHECK", "TOOLTIP_READY", isPlayerLeader)

  local countdownButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  countdownButton:SetSize(120, 24)
  countdownButton:SetPoint("TOPRIGHT", -136, -90)
  countdownButton:SetScript("OnClick", function()
    if not isPlayerLeader() then
      return
    end
    C_PartyInfo.DoCountdown(10)
  end)
  AttachPanelButtonTooltip(countdownButton, getL, "BTN_COUNTDOWN10", "TOOLTIP_CD10", isPlayerLeader)

  local refreshButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  refreshButton:SetSize(120, 24)
  refreshButton:SetPoint("TOPRIGHT", -136, -150)
  AttachPanelButtonTooltip(refreshButton, getL, "BTN_REFRESH", "TOOLTIP_REFRESH", nil)

  local shareKeysButton = CreateShareKeysButton(mainFrame, deps)

  local countdownCancelButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  countdownCancelButton:SetSize(120, 24)
  countdownCancelButton:SetPoint("TOPRIGHT", -136, -120)
  AttachPanelButtonTooltip(countdownCancelButton, getL, "BTN_COUNTDOWN_CANCEL", "TOOLTIP_CD_CANCEL", isPlayerLeader)

  return {
    readyCheckButton = readyCheckButton,
    countdownButton = countdownButton,
    refreshButton = refreshButton,
    shareKeysButton = shareKeysButton,
    countdownCancelButton = countdownCancelButton,
  }
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
  local buttons = CreatePanelButtons(mainFrame, uiDeps)
  local statusLine = CreateStatusLine(mainFrame)
  local optionToggles = CreateSystemOptionToggles(mainFrame)
  CreateVersionLine(mainFrame, uiDeps.getAddonVersionText)

  local ui = {
    title = title,
    statusLine = statusLine,
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
  AttachSystemOptionToggleWatcher(mainFrame, ui)
  return ui
end

local function RenderRosterImpl(state, roster)
  local memberRows = state.memberRows
  local mainFrame = state.mainFrame
  local shareKeysButton = state.shareKeysButton
  local setMainFrameHeightSafe = state.setMainFrameHeightSafe
  local minFrameHeight = state.minFrameHeight

  for _, row in pairs(memberRows) do
    row.spec:SetText("")
    row.name:SetText("")
    row.realm:SetText("")
    row.key:SetText("")
    row.ilvl:SetText("")
    row.rio:SetText("")
    row.unit = nil
    row.tooltipName = nil
    row.tooltipRealm = nil
    if row.hoverFrame then
      row.hoverFrame.unit = nil
      row.hoverFrame:Hide()
    end
  end

  local index = 1
  local orderedRoster = state.buildOrderedRoster(roster, state.rolePriority, state.unitPriority)
  local hasFullSync = state.hasFullSyncFn(roster)
  local activeKeyOwnerUnit = state.resolveActiveKeyOwnerUnit()
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
      row = CreateMemberRow(mainFrame, index)
      memberRows[index] = row
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
    })

    row.spec:SetText("|c" .. displayData.colorHex .. displayData.specText .. "|r")
    row.name:SetText(
      displayData.roleIconMarkup
        .. " |c"
        .. displayData.colorHex
        .. displayData.displayName
        .. "|r"
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
    row.unit = entry.unit
    row.tooltipName = info and info.name or nil
    row.tooltipRealm = info and info.realm or nil
    if row.hoverFrame then
      row.hoverFrame.unit = entry.unit
      row.hoverFrame:Show()
    end
    index = index + 1
  end

  shareKeysButton:SetEnabled(hasAnyKey)
  shareKeysButton:SetAlpha(hasAnyKey and 1 or 0.45)

  setMainFrameHeightSafe(math.max(minFrameHeight, 45 + index * 16))
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
  local isInGroup = RequireFunction(opts.isInGroup, "isInGroup")
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
    ui.leadOptionsHeader:SetText(L.LEAD_OPTIONS)
    ui.mplusManagementHeader:SetText(L.MPLUS_MANAGEMENT)
    readyCheckButton:SetText(L.BTN_READYCHECK)
    countdownButton:SetText(L.BTN_COUNTDOWN10)
    countdownCancelButton:SetText(L.BTN_COUNTDOWN_CANCEL)
    refreshButton:SetText(L.BTN_REFRESH)
    shareKeysButton:SetText(L.BTN_SHARE_KEYS)
    ui.advancedCombatLoggingToggle.label:SetText(L.OPT_ADVANCED_COMBAT_LOGGING)
    ui.damageMeterResetToggle.label:SetText(L.OPT_DAMAGE_METER_RESET)
    RefreshSystemOptionToggles(ui)
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
      setMainFrameHeightSafe = setMainFrameHeightSafe,
      minFrameHeight = minFrameHeight,
      buildOrderedRoster = buildOrderedRoster,
      rolePriority = rolePriority,
      unitPriority = unitPriority,
      hasFullSyncFn = hasFullSyncFn,
      resolveActiveKeyOwnerUnit = resolveActiveKeyOwnerUnit,
      buildDisplayData = buildDisplayData,
      truncateName = truncateName,
      getShortSpecLabel = getShortSpecLabel,
      getLanguageFlagMarkup = getLanguageFlagMarkup,
      getDungeonShortCode = getDungeonShortCode,
      getRioDelta = getRioDelta,
      syncMarker = syncMarker,
      fullSyncMarker = fullSyncMarker,
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
