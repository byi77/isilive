local _, addonTable = ...

addonTable = addonTable or {}

local RosterPanel = {}
addonTable.RosterPanel = RosterPanel

local SPEC_COL_X = 10
local NAME_COL_X = 110
local SERVER_COL_X = 240
local KEY_COL_X = 292
local ILVL_COL_X = 370
local RIO_COL_X = 408
local SPEC_COL_WIDTH = 92
local NAME_COL_WIDTH = 125
local SERVER_COL_WIDTH = 50
local KEY_COL_WIDTH = 72
local ILVL_COL_WIDTH = 35
local RIO_COL_WIDTH = 104

local function RequireFunction(value, name)
  assert(type(value) == "function", "isiLive: RosterPanel requires " .. name)
  return value
end

local function SendPartyChatMessage(message)
  if type(message) ~= "string" or message == "" then
    return false
  end

  if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
    local ok = pcall(C_ChatInfo.SendChatMessage, message, "PARTY")
    if ok then
      return true
    end
  end

  return false
end

local function BuildKeyAnnouncement(opts)
  local L = opts.getL()
  local roster = opts.getRoster()
  local buildOrderedRoster = opts.buildOrderedRoster
  local rolePriority = opts.rolePriority
  local unitPriority = opts.unitPriority
  local getDungeonShortCode = opts.getDungeonShortCode
  local parts = {}
  local ordered = buildOrderedRoster(roster, rolePriority, unitPriority)
  for _, entry in ipairs(ordered) do
    local info = entry.info
    if info.keyMapID and info.keyLevel and tonumber(info.keyLevel) > 0 then
      local short = getDungeonShortCode(info.keyMapID)
      table.insert(parts, string.format("%s: %s +%s", info.name, short, info.keyLevel))
    end
  end

  if #parts == 0 then
    return nil
  end

  return L.ANNOUNCE_PREFIX .. " " .. table.concat(parts, ", ")
end

local function CreateStatusLine(mainFrame)
  local statusLine = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  statusLine:SetPoint("BOTTOMLEFT", 10, 10)
  statusLine:SetJustifyH("LEFT")
  statusLine:SetText("")
  return statusLine
end

local function CreateVersionLine(mainFrame, getAddonVersionText)
  local versionLine = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  versionLine:SetPoint("TOPRIGHT", -10, -10)
  versionLine:SetJustifyH("RIGHT")
  versionLine:SetText(getAddonVersionText())
  return versionLine
end

local function CreateMemberRow(mainFrame, index)
  local yOffset = -52 - (index - 1) * 16
  local row = {}

  row.hoverFrame = CreateFrame("Frame", nil, mainFrame)
  row.hoverFrame:SetPoint("TOPLEFT", 4, yOffset + 2)
  row.hoverFrame:SetPoint("RIGHT", -4, 0)
  row.hoverFrame:SetHeight(16)

  row.highlight = row.hoverFrame:CreateTexture(nil, "BACKGROUND")
  row.highlight:SetAllPoints()
  row.highlight:SetColorTexture(1, 1, 1, 0.05)
  row.highlight:Hide()

  row.hoverFrame:SetScript("OnEnter", function()
    row.highlight:Show()
  end)
  row.hoverFrame:SetScript("OnLeave", function()
    row.highlight:Hide()
  end)

  row.spec = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.spec:SetPoint("TOPLEFT", SPEC_COL_X, yOffset)
  row.spec:SetJustifyH("RIGHT")
  row.spec:SetWidth(SPEC_COL_WIDTH)

  row.name = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.name:SetPoint("TOPLEFT", NAME_COL_X, yOffset)
  row.name:SetJustifyH("LEFT")
  row.name:SetWidth(NAME_COL_WIDTH)

  row.ilvl = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.ilvl:SetPoint("TOPLEFT", ILVL_COL_X, yOffset)
  row.ilvl:SetWidth(ILVL_COL_WIDTH)
  row.ilvl:SetJustifyH("RIGHT")

  row.key = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.key:SetPoint("TOPLEFT", KEY_COL_X, yOffset)
  row.key:SetWidth(KEY_COL_WIDTH)
  row.key:SetJustifyH("RIGHT")
  if row.key.SetWordWrap then
    row.key:SetWordWrap(false)
  end
  if row.key.SetNonSpaceWrap then
    row.key:SetNonSpaceWrap(false)
  end
  if row.key.SetMaxLines then
    row.key:SetMaxLines(1)
  end

  row.rio = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.rio:SetPoint("TOPLEFT", RIO_COL_X, yOffset)
  row.rio:SetWidth(RIO_COL_WIDTH)
  row.rio:SetJustifyH("RIGHT")
  if row.rio.SetWordWrap then
    row.rio:SetWordWrap(false)
  end
  if row.rio.SetNonSpaceWrap then
    row.rio:SetNonSpaceWrap(false)
  end
  if row.rio.SetMaxLines then
    row.rio:SetMaxLines(1)
  end

  row.realm = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.realm:SetPoint("TOPLEFT", SERVER_COL_X, yOffset)
  row.realm:SetWidth(SERVER_COL_WIDTH)
  row.realm:SetJustifyH("LEFT")

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
    GameTooltip:SetText(L[titleKey])
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
  button:SetScript("OnClick", function()
    local msg = BuildKeyAnnouncement({
      getL = deps.getL,
      getRoster = deps.getRoster,
      buildOrderedRoster = deps.buildOrderedRoster,
      rolePriority = deps.rolePriority,
      unitPriority = deps.unitPriority,
      getDungeonShortCode = deps.getDungeonShortCode,
    })
    if not msg then
      return
    end
    if deps.isInGroup() then
      if not SendPartyChatMessage(msg) then
        print(msg)
      end
    else
      print(msg)
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
    if row.hoverFrame then
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
    if row.hoverFrame then
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
    isInGroup = isInGroup,
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
  end

  function controller.UpdateLeaderButtons()
    local enabled = isPlayerLeader()
    readyCheckButton:SetEnabled(enabled)
    countdownButton:SetEnabled(enabled)
    countdownCancelButton:SetEnabled(enabled)
    readyCheckButton:SetAlpha(enabled and 1 or 0.45)
    countdownButton:SetAlpha(enabled and 1 or 0.45)
    countdownCancelButton:SetAlpha(enabled and 1 or 0.45)
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
  end

  AttachControllerAccessors(controller, {
    refreshButton = refreshButton,
    countdownCancelButton = countdownCancelButton,
    statusLine = ui.statusLine,
  })

  return controller
end
