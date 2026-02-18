local _, addonTable = ...

addonTable = addonTable or {}

local RosterPanel = {}
addonTable.RosterPanel = RosterPanel

local SPEC_COL_X = 10
local NAME_COL_X = 110
local SERVER_COL_X = 240
local KEY_COL_X = 304
local ILVL_COL_X = 372
local RIO_COL_X = 414
local SPEC_COL_WIDTH = 92
local NAME_COL_WIDTH = 125
local SERVER_COL_WIDTH = 62
local KEY_COL_WIDTH = 62
local ILVL_COL_WIDTH = 35
local RIO_COL_WIDTH = 55

local function RequireFunction(value, name)
  assert(type(value) == "function", "isiLive: RosterPanel requires " .. name)
  return value
end

local function CreateAnnounceButton(opts)
  local mainFrame = opts.mainFrame
  local getL = opts.getL
  local getRoster = opts.getRoster
  local buildOrderedRoster = opts.buildOrderedRoster
  local rolePriority = opts.rolePriority
  local unitPriority = opts.unitPriority
  local getDungeonShortCode = opts.getDungeonShortCode
  local isInGroup = opts.isInGroup

  local button = CreateFrame("Button", nil, mainFrame)
  button:SetSize(14, 14)
  button:SetPoint("TOPLEFT", KEY_COL_X + 2, -34)
  button:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicSpeaking-Up")
  button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  button:SetScript("OnEnter", function(self)
    local L = getL()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.TOOLTIP_ANNOUNCE_KEYS)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  button:SetScript("OnClick", function()
    local L = getL()
    local roster = getRoster()
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
      return
    end
    local msg = L.ANNOUNCE_PREFIX .. " " .. table.concat(parts, ", ")
    if isInGroup() then
      SendChatMessage(msg, "PARTY")
    else
      print(msg)
    end
  end)

  return button
end

function RosterPanel.CreateController(opts)
  opts = opts or {}

  local mainFrame = assert(opts.mainFrame, "isiLive: RosterPanel requires mainFrame")
  local getL = RequireFunction(opts.getL, "getL")
  local isPlayerLeader = RequireFunction(opts.isPlayerLeader, "isPlayerLeader")
  local getAddonVersionText = RequireFunction(opts.getAddonVersionText, "getAddonVersionText")
  local updateStatusLine = RequireFunction(opts.updateStatusLine, "updateStatusLine")
  local setMainFrameHeightSafe = RequireFunction(opts.setMainFrameHeightSafe, "setMainFrameHeightSafe")
  local minFrameHeight = tonumber(opts.minFrameHeight) or 200

  local buildOrderedRoster = RequireFunction(opts.buildOrderedRoster, "buildOrderedRoster")
  local hasFullSyncFn = RequireFunction(opts.hasFullSync, "hasFullSync")
  local buildDisplayData = RequireFunction(opts.buildDisplayData, "buildDisplayData")
  local truncateName = RequireFunction(opts.truncateName, "truncateName")
  local getShortSpecLabel = RequireFunction(opts.getShortSpecLabel, "getShortSpecLabel")
  local getLanguageFlagMarkup = RequireFunction(opts.getLanguageFlagMarkup, "getLanguageFlagMarkup")
  local getDungeonShortCode = RequireFunction(opts.getDungeonShortCode, "getDungeonShortCode")
  local resolveActiveKeyOwnerUnit = RequireFunction(opts.resolveActiveKeyOwnerUnit, "resolveActiveKeyOwnerUnit")
  local getRoster = RequireFunction(opts.getRoster, "getRoster")
  local isInGroup = RequireFunction(opts.isInGroup, "isInGroup")
  local rolePriority = assert(opts.rolePriority, "isiLive: RosterPanel requires rolePriority")
  local unitPriority = assert(opts.unitPriority, "isiLive: RosterPanel requires unitPriority")
  local syncMarker = tostring(opts.syncMarker or "")
  local fullSyncMarker = tostring(opts.fullSyncMarker or "")

  -- Background for visibility
  -- Visuals: Add Backdrop for a more native WoW look
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

  CreateAnnounceButton({
    mainFrame = mainFrame,
    getL = getL,
    getRoster = getRoster,
    buildOrderedRoster = buildOrderedRoster,
    rolePriority = rolePriority,
    unitPriority = unitPriority,
    getDungeonShortCode = getDungeonShortCode,
    isInGroup = isInGroup,
  })

  local rioHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  rioHeader:SetPoint("TOPLEFT", RIO_COL_X, -34)
  rioHeader:SetWidth(RIO_COL_WIDTH)
  rioHeader:SetJustifyH("RIGHT")

  local leadOptionsHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  leadOptionsHeader:SetPoint("TOPRIGHT", -150, -34)
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

  local readyCheckButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  readyCheckButton:SetSize(120, 24)
  readyCheckButton:SetPoint("TOPRIGHT", -146, -60)
  readyCheckButton:SetScript("OnClick", function()
    if not isPlayerLeader() then
      return
    end
    DoReadyCheck()
  end)
  readyCheckButton:SetScript("OnEnter", function(self)
    local L = getL()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.BTN_READYCHECK)
    GameTooltip:AddLine(L.TOOLTIP_READY, 1, 1, 1, true)
    if not isPlayerLeader() then
      GameTooltip:AddLine(L.TOOLTIP_LEAD_REQUIRED, 1, 0.2, 0.2, true)
    end
    GameTooltip:Show()
  end)
  readyCheckButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local countdownButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  countdownButton:SetSize(120, 24)
  countdownButton:SetPoint("TOPRIGHT", -146, -90)
  countdownButton:SetScript("OnClick", function()
    if not isPlayerLeader() then
      return
    end
    C_PartyInfo.DoCountdown(10)
  end)
  countdownButton:SetScript("OnEnter", function(self)
    local L = getL()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.BTN_COUNTDOWN10)
    GameTooltip:AddLine(L.TOOLTIP_CD10, 1, 1, 1, true)
    if not isPlayerLeader() then
      GameTooltip:AddLine(L.TOOLTIP_LEAD_REQUIRED, 1, 0.2, 0.2, true)
    end
    GameTooltip:Show()
  end)
  countdownButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local refreshButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  refreshButton:SetSize(120, 24)
  refreshButton:SetPoint("TOPRIGHT", -146, -120)
  refreshButton:SetScript("OnEnter", function(self)
    local L = getL()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.BTN_REFRESH)
    GameTooltip:AddLine(L.TOOLTIP_REFRESH, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  refreshButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local dmResetToggleButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  dmResetToggleButton:SetSize(120, 24)
  dmResetToggleButton:SetPoint("TOPRIGHT", -146, -150)
  dmResetToggleButton:SetScript("OnEnter", function(self)
    local L = getL()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.TOOLTIP_DMRESET)
    GameTooltip:Show()
  end)
  dmResetToggleButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local statusLine = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  statusLine:SetPoint("BOTTOMLEFT", 10, 10)
  statusLine:SetJustifyH("LEFT")
  statusLine:SetText("")

  local versionLine = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  versionLine:SetPoint("BOTTOMRIGHT", -10, 10)
  versionLine:SetJustifyH("RIGHT")
  versionLine:SetText(getAddonVersionText())

  local memberRows = {}
  local function CreateMemberRow(index)
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

    row.rio = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.rio:SetPoint("TOPLEFT", RIO_COL_X, yOffset)
    row.rio:SetWidth(RIO_COL_WIDTH)
    row.rio:SetJustifyH("RIGHT")

    row.realm = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.realm:SetPoint("TOPLEFT", SERVER_COL_X, yOffset)
    row.realm:SetWidth(SERVER_COL_WIDTH)
    row.realm:SetJustifyH("LEFT")

    memberRows[index] = row
    return row
  end

  local controller = {}

  function controller.ApplyLocalization()
    local L = getL()
    title:SetText(L.TITLE)
    specHeader:SetText(L.COL_SPEC)
    nameHeader:SetText(L.COL_NAME)
    serverHeader:SetText(L.COL_LANGUAGE)
    keyHeader:SetText(L.COL_KEY)
    ilvlHeader:SetText(L.COL_ILVL)
    rioHeader:SetText(L.COL_RIO)
    leadOptionsHeader:SetText(L.LEAD_OPTIONS)
    mplusManagementHeader:SetText(L.MPLUS_MANAGEMENT)
    readyCheckButton:SetText(L.BTN_READYCHECK)
    countdownButton:SetText(L.BTN_COUNTDOWN10)
    refreshButton:SetText(L.BTN_REFRESH)
  end

  function controller.UpdateLeaderButtons()
    local enabled = isPlayerLeader()
    readyCheckButton:SetEnabled(enabled)
    countdownButton:SetEnabled(enabled)
    readyCheckButton:SetAlpha(enabled and 1 or 0.45)
    countdownButton:SetAlpha(enabled and 1 or 0.45)
    updateStatusLine()
  end

  function controller.RenderRoster(roster)
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
    local orderedRoster = buildOrderedRoster(roster, rolePriority, unitPriority)
    local hasFullSync = hasFullSyncFn(roster)
    local activeKeyOwnerUnit = resolveActiveKeyOwnerUnit()

    for _, entry in ipairs(orderedRoster) do
      local info = entry.info
      local row = memberRows[index] or CreateMemberRow(index)

      local displayData = buildDisplayData(info, {
        truncateName = truncateName,
        getShortSpecLabel = getShortSpecLabel,
        getLanguageFlagMarkup = getLanguageFlagMarkup,
        getDungeonShortCode = getDungeonShortCode,
        syncMarker = syncMarker,
        fullSyncMarker = fullSyncMarker,
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

    setMainFrameHeightSafe(math.max(minFrameHeight, 45 + index * 16))
  end

  function controller.GetRefreshButton()
    return refreshButton
  end

  function controller.GetDMResetToggleButton()
    return dmResetToggleButton
  end

  function controller.GetStatusLine()
    return statusLine
  end

  function controller.SetDMResetText(text)
    dmResetToggleButton:SetText(tostring(text or ""))
  end

  return controller
end
