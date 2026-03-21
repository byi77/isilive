local _, addonTable = ...

addonTable = addonTable or {}

local UI = {}
addonTable.UI = UI
local createRedCloseButton = assert(
  addonTable.UICommon and addonTable.UICommon.CreateRedCloseButton,
  "isiLive: UICommon.CreateRedCloseButton missing"
)
local Colors = addonTable.UICommon.Colors or {}
local DEFAULT_GAME_MENU_BUTTON_WIDTH = 120
local DEFAULT_GAME_MENU_BUTTON_HEIGHT = 30
local PANEL_UI_BUTTON_GAP = 1
local PANEL_UI_SECTION_BREAK_GAP = 10
local PANEL_UI_OFFSET_X = -60
local PANEL_UI_OFFSET_Y = 0
local PANEL_UI_PADDING_X = 10
local PANEL_UI_PADDING_TOP = 10
local PANEL_UI_PADDING_BOTTOM = 10
local PANEL_UI_SECTION_HEADER_HEIGHT = 16
local PANEL_UI_SECTION_HEADER_GAP = 3
local PANEL_UI_ICON_SIZE = 18
local PANEL_UI_ICON_PADDING = 6
local ApplyBackdrop = addonTable.UICommon.ApplyBackdrop
local PANEL_UI_ENTRIES = {
  {
    id = "professions",
    labelKey = "BTN_GAMEMENU_PROFESSIONS",
    fallbackText = "Professions",
    icon = "Interface\\Icons\\Trade_Engineering",
  },
  {
    id = "talents",
    labelKey = "BTN_GAMEMENU_TALENTS",
    fallbackText = "Talents",
    icon = "Interface\\Icons\\Ability_Marksmanship",
  },
  {
    id = "spellbook",
    labelKey = "BTN_GAMEMENU_SPELLBOOK",
    fallbackText = "Spells",
    icon = "Interface\\Icons\\INV_Misc_Book_09",
  },
  {
    id = "achievements",
    labelKey = "BTN_GAMEMENU_ACHIEVEMENTS",
    fallbackText = "Achievements",
    icon = "Interface\\Icons\\Achievement_Boss_CThun",
  },
  {
    id = "quests",
    labelKey = "BTN_GAMEMENU_QUESTS",
    fallbackText = "Quests",
    icon = "Interface\\Icons\\INV_Misc_Map_01",
  },
  {
    id = "dungeons",
    labelKey = "BTN_GAMEMENU_DUNGEONS",
    fallbackText = "Dungeons",
    icon = "Interface\\Icons\\INV_Misc_Key_04",
  },
  {
    id = "journal",
    labelKey = "BTN_GAMEMENU_JOURNAL",
    fallbackText = "Journal",
    icon = "Interface\\Icons\\INV_Misc_Book_11",
  },
  {
    id = "collections",
    labelKey = "BTN_GAMEMENU_COLLECTIONS",
    fallbackText = "Collections",
    icon = "Interface\\Icons\\MountJournalPortrait",
  },
  {
    id = "guild",
    labelKey = "BTN_GAMEMENU_GUILD",
    fallbackText = "Guild",
    icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
  },
  {
    id = "reloadui",
    labelKey = "BTN_GAMEMENU_RELOADUI",
    fallbackText = "ReloadUI",
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    gapBefore = PANEL_UI_SECTION_BREAK_GAP,
    secureMacroText = "/click GameMenuButtonContinue\n/reload",
  },
}
local panelUIState = nil
local PositionPanelUIButtons
local ApplyPanelUISecureState
local panelUISecureRetryFrame
local pendingPanelUISecureStateRefresh = {}
local GAME_MENU_BUTTON_SIZE_CANDIDATE_NAMES = {
  "GameMenuButtonContinue",
  "GameMenuButtonOptions",
  "GameMenuButtonMacros",
  "GameMenuButtonAddons",
  "GameMenuButtonLogout",
  "GameMenuButtonQuit",
}
local GAME_MENU_BUTTON_SIZE_CANDIDATE_FIELDS = {
  "ContinueButton",
  "OptionsButton",
  "MacrosButton",
  "AddOnsButton",
  "LogoutButton",
  "QuitButton",
}

local function IsPanelUISecureMacroButton(button)
  return type(button) == "table" and type(button._secureMacroText) == "string" and button._secureMacroText ~= ""
end

local function IsPanelUISecureUpdateBlocked(state)
  return type(state) == "table" and type(state.isInCombat) == "function" and state.isInCombat() == true
end

local function ClearQueuedPanelUISecureState(state)
  if pendingPanelUISecureStateRefresh[state] ~= true then
    return
  end

  pendingPanelUISecureStateRefresh[state] = nil
  if panelUISecureRetryFrame and next(pendingPanelUISecureStateRefresh) == nil then
    panelUISecureRetryFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end
end

local function QueuePanelUISecureStateRefresh(state)
  if type(state) ~= "table" then
    return
  end

  pendingPanelUISecureStateRefresh[state] = true
  if panelUISecureRetryFrame then
    panelUISecureRetryFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  end
end

panelUISecureRetryFrame = CreateFrame("Frame")
panelUISecureRetryFrame:SetScript("OnEvent", function(self, event)
  if event ~= "PLAYER_REGEN_ENABLED" then
    return
  end

  local queuedStates = {}
  for state in pairs(pendingPanelUISecureStateRefresh) do
    queuedStates[#queuedStates + 1] = state
    pendingPanelUISecureStateRefresh[state] = nil
  end
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")

  for _, state in ipairs(queuedStates) do
    ApplyPanelUISecureState(state, true)
  end
end)

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then
    return false
  end

  local secureCall = rawget(_G, "securecallfunction")
  if type(secureCall) == "function" then
    local ok = pcall(secureCall, fn, ...)
    return ok
  end

  local ok = pcall(fn, ...)
  return ok
end

local function EnsureAddOnLoaded(addOnName)
  if type(addOnName) ~= "string" or addOnName == "" then
    return false
  end

  local cAddOns = rawget(_G, "C_AddOns")
  if
    type(cAddOns) == "table"
    and type(cAddOns.IsAddOnLoaded) == "function"
    and type(cAddOns.LoadAddOn) == "function"
  then
    local loadedOk, isLoaded = pcall(cAddOns.IsAddOnLoaded, addOnName)
    if loadedOk and isLoaded then
      return true
    end
    pcall(cAddOns.LoadAddOn, addOnName)
    return true
  end

  local loadAddOn = rawget(_G, "UIParentLoadAddOn")
  if type(loadAddOn) == "function" then
    pcall(loadAddOn, addOnName)
    return true
  end

  return false
end

local function ClickButtonSecure(button)
  if type(button) ~= "table" or type(button.Click) ~= "function" then
    return false
  end

  return SafeCall(button.Click, button, "LeftButton", true)
end

local function ClickNamedButtonSecure(buttonName)
  if type(buttonName) ~= "string" or buttonName == "" then
    return false
  end

  return ClickButtonSecure(rawget(_G, buttonName))
end

local function IsNamedFrameShown(frameName)
  if type(frameName) ~= "string" or frameName == "" then
    return false
  end

  local frame = rawget(_G, frameName)
  return type(frame) == "table" and type(frame.IsShown) == "function" and frame:IsShown() == true
end

local function IsAnyNamedFrameShown(frameNames)
  if type(frameNames) ~= "table" then
    return false
  end

  for _, frameName in ipairs(frameNames) do
    if IsNamedFrameShown(frameName) then
      return true
    end
  end

  return false
end

local function ResolveFrameSize(frame)
  if type(frame) ~= "table" or type(frame.GetWidth) ~= "function" or type(frame.GetHeight) ~= "function" then
    return nil, nil
  end

  local width = tonumber(frame:GetWidth())
  local height = tonumber(frame:GetHeight())
  if width == nil or height == nil or width <= 0 or height <= 0 then
    return nil, nil
  end

  return width, height
end

local function ResolvePanelUIButtonSize(gameMenuFrame)
  for _, buttonName in ipairs(GAME_MENU_BUTTON_SIZE_CANDIDATE_NAMES) do
    local width, height = ResolveFrameSize(rawget(_G, buttonName))
    if width ~= nil and height ~= nil then
      return width, height
    end
  end

  if type(gameMenuFrame) == "table" then
    for _, fieldName in ipairs(GAME_MENU_BUTTON_SIZE_CANDIDATE_FIELDS) do
      local width, height = ResolveFrameSize(rawget(gameMenuFrame, fieldName))
      if width ~= nil and height ~= nil then
        return width, height
      end
    end
  end

  return DEFAULT_GAME_MENU_BUTTON_WIDTH, DEFAULT_GAME_MENU_BUTTON_HEIGHT
end

local function ResolveSecureClickBinding()
  local getCVarBool = rawget(_G, "GetCVarBool")
  local useOnKeyDown = type(getCVarBool) == "function" and getCVarBool("ActionButtonUseKeyDown") == true
  return useOnKeyDown and "LeftButtonDown" or "LeftButtonUp", useOnKeyDown
end

local function IsPanelUIEnabled(state)
  if type(state) ~= "table" then
    return false
  end

  if type(state.isEnabled) == "function" then
    return state.isEnabled() ~= false
  end

  return true
end

local function RefreshPanelUISecureButton(button)
  if type(button) ~= "table" or not IsPanelUISecureMacroButton(button) or type(button.SetAttribute) ~= "function" then
    return
  end

  local clickBinding, useOnKeyDown = ResolveSecureClickBinding()
  if type(button.RegisterForClicks) == "function" then
    button:RegisterForClicks(clickBinding)
  end
  button:SetAttribute("type", "macro")
  button:SetAttribute("type1", "macro")
  button:SetAttribute("*type1", "macro")
  button:SetAttribute("useOnKeyDown", useOnKeyDown)
  button:SetAttribute("macrotext", button._secureMacroText)
  button:SetAttribute("macrotext1", button._secureMacroText)
end

local function RefreshPanelUISecureButtons(state)
  if type(state) ~= "table" then
    return
  end

  if IsPanelUISecureUpdateBlocked(state) then
    QueuePanelUISecureStateRefresh(state)
    return
  end

  for _, button in ipairs(state.buttons or {}) do
    RefreshPanelUISecureButton(button)
  end

  ClearQueuedPanelUISecureState(state)
end

local function SyncPanelUIButtonVisibility(button, visible)
  if type(button) ~= "table" then
    return
  end

  if visible then
    if type(button.Show) == "function" then
      button:Show()
    end
    return
  end

  if type(button.Hide) == "function" then
    button:Hide()
  end
end

local function SyncPanelUISecureButtonVisibility(state)
  if type(state) ~= "table" then
    return
  end

  if IsPanelUISecureUpdateBlocked(state) then
    QueuePanelUISecureStateRefresh(state)
    return
  end

  local visible = IsPanelUIEnabled(state)
  for _, button in ipairs(state.buttons or {}) do
    if IsPanelUISecureMacroButton(button) then
      SyncPanelUIButtonVisibility(button, visible)
    end
  end

  ClearQueuedPanelUISecureState(state)
end

local function CreatePanelUIButton(
  parent,
  frameStrata,
  baseFrameLevel,
  frameLevelOffset,
  iconPath,
  buttonTemplate,
  skipInitialClickRegistration
)
  local button = CreateFrame("Button", nil, parent, buttonTemplate or "BackdropTemplate")
  ApplyBackdrop(button, "BUTTON_BG")
  if type(button.EnableMouse) == "function" then
    button:EnableMouse(true)
  end
  if not skipInitialClickRegistration and type(button.RegisterForClicks) == "function" then
    button:RegisterForClicks("LeftButtonUp")
  end
  if frameStrata ~= nil and type(button.SetFrameStrata) == "function" then
    button:SetFrameStrata(frameStrata)
  end
  if type(button.SetFrameLevel) == "function" then
    button:SetFrameLevel(baseFrameLevel + frameLevelOffset)
  end

  if iconPath and type(button.CreateTexture) == "function" then
    local iconBorder = button:CreateTexture(nil, "ARTWORK", nil, -1)
    if type(iconBorder.SetSize) == "function" then
      iconBorder:SetSize(PANEL_UI_ICON_SIZE + 2, PANEL_UI_ICON_SIZE + 2)
    end
    if type(iconBorder.SetPoint) == "function" then
      iconBorder:SetPoint("LEFT", PANEL_UI_ICON_PADDING - 1, 0)
    end
    if type(iconBorder.SetColorTexture) == "function" then
      iconBorder:SetColorTexture(0, 0, 0, 0.5)
    end
    local icon = button:CreateTexture(nil, "ARTWORK")
    if type(icon.SetSize) == "function" then
      icon:SetSize(PANEL_UI_ICON_SIZE, PANEL_UI_ICON_SIZE)
    end
    if type(icon.SetPoint) == "function" then
      icon:SetPoint("LEFT", PANEL_UI_ICON_PADDING, 0)
    end
    if type(icon.SetTexCoord) == "function" then
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    if type(icon.SetTexture) == "function" then
      icon:SetTexture(iconPath)
    end
    button._panelIcon = icon
  end

  if type(button.CreateFontString) == "function" then
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local textOffsetX = iconPath and ((PANEL_UI_ICON_PADDING * 2) + PANEL_UI_ICON_SIZE) or PANEL_UI_ICON_PADDING
    if type(label.SetPoint) == "function" then
      label:SetPoint("LEFT", textOffsetX, 0)
    end
    if type(label.SetJustifyH) == "function" then
      label:SetJustifyH("LEFT")
    end
    button._panelLabel = label
  end

  button._panelText = ""
  button.SetText = function(self, text)
    self._panelText = text or ""
    if self._panelLabel and type(self._panelLabel.SetText) == "function" then
      self._panelLabel:SetText(self._panelText)
    end
  end
  button.GetText = function(self)
    return self._panelText or ""
  end

  if type(button.CreateTexture) == "function" then
    local hl = Colors.HOVER_HIGHLIGHT
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    if type(highlight.SetAllPoints) == "function" then
      highlight:SetAllPoints()
    end
    if type(highlight.SetColorTexture) == "function" then
      highlight:SetColorTexture(hl[1], hl[2], hl[3], hl[4])
    end
  end

  if type(button.SetScript) == "function" then
    button:SetScript("OnEnter", function(self)
      if type(self.SetBackdropColor) == "function" then
        self:SetBackdropColor(0.14, 0.14, 0.20, 0.7)
      end
    end)
    button:SetScript("OnLeave", function(self)
      if type(self.SetBackdropColor) == "function" then
        local bg = Colors.BG_SECONDARY
        self:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
      end
    end)
  end

  return button
end

local function ResolvePanelUIWidth(buttonWidth)
  return buttonWidth + (PANEL_UI_PADDING_X * 2)
end

local function ApplyPanelUIBackdrop(panelFrame)
  ApplyBackdrop(panelFrame, "PRIMARY")
end

local function OpenViaMicroButton(buttonName, targetFrameNames, fallbackFn, ...)
  if IsAnyNamedFrameShown(targetFrameNames) then
    return true
  end

  ClickNamedButtonSecure(buttonName)
  if IsAnyNamedFrameShown(targetFrameNames) then
    return true
  end

  SafeCall(fallbackFn, ...)
  return IsAnyNamedFrameShown(targetFrameNames)
end

local function BuildDefaultPanelUIActions(isInCombat)
  local function IsBlockedInCombat()
    return type(isInCombat) == "function" and isInCombat() == true
  end

  local function OpenProfessions()
    return OpenViaMicroButton(
      "ProfessionMicroButton",
      { "ProfessionsFrame", "ProfessionsBookFrame", "TradeSkillFrame" },
      rawget(_G, "ToggleProfessionsBook")
    )
  end

  local function OpenTalents()
    if IsBlockedInCombat() then
      return false
    end
    if ClickNamedButtonSecure("PlayerSpellsMicroButton") then
      return true
    end
    if ClickNamedButtonSecure("TalentMicroButton") then
      return true
    end

    EnsureAddOnLoaded("Blizzard_PlayerSpells")
    local playerSpellsUtil = rawget(_G, "PlayerSpellsUtil")
    if type(playerSpellsUtil) == "table" then
      if SafeCall(playerSpellsUtil.ToggleClassTalentFrame) then
        return true
      end

      local frameTabs = rawget(playerSpellsUtil, "FrameTabs")
      local classTalentsTab = type(frameTabs) == "table" and rawget(frameTabs, "ClassTalents") or nil
      if classTalentsTab ~= nil and SafeCall(rawget(_G, "TogglePlayerSpellsFrame"), classTalentsTab) then
        return true
      end

      if SafeCall(playerSpellsUtil.ToggleClassTalentOrSpecFrame) then
        return true
      end
    end

    return false
  end

  local function OpenSpellbook()
    if IsBlockedInCombat() then
      return false
    end

    EnsureAddOnLoaded("Blizzard_PlayerSpells")
    local playerSpellsUtil = rawget(_G, "PlayerSpellsUtil")
    if type(playerSpellsUtil) == "table" then
      local toggleSpellBookFrame = rawget(playerSpellsUtil, "ToggleSpellBookFrame")
      if type(toggleSpellBookFrame) == "function" and SafeCall(toggleSpellBookFrame) then
        return true
      end

      local frameTabs = rawget(playerSpellsUtil, "FrameTabs")
      local spellBookTab = type(frameTabs) == "table" and rawget(frameTabs, "SpellBook") or nil
      local togglePlayerSpellsFrame = rawget(_G, "TogglePlayerSpellsFrame")
      if
        spellBookTab ~= nil
        and type(togglePlayerSpellsFrame) == "function"
        and SafeCall(togglePlayerSpellsFrame, spellBookTab)
      then
        return true
      end
    end

    return ClickNamedButtonSecure("SpellbookMicroButton")
  end

  local function OpenAchievements()
    return OpenViaMicroButton("AchievementMicroButton", { "AchievementFrame" }, rawget(_G, "ToggleAchievementFrame"))
  end

  local function OpenQuestLog()
    EnsureAddOnLoaded("Blizzard_WorldMap")
    return OpenViaMicroButton("QuestLogMicroButton", { "QuestLogFrame", "WorldMapFrame" }, rawget(_G, "ToggleQuestLog"))
  end

  local function OpenDungeons()
    EnsureAddOnLoaded("Blizzard_GroupFinder")
    return OpenViaMicroButton("LFDMicroButton", { "PVEFrame" }, rawget(_G, "PVEFrame_ToggleFrame"))
  end

  local function OpenJournal()
    return OpenViaMicroButton("EJMicroButton", { "EncounterJournal" }, rawget(_G, "ToggleEncounterJournal"))
  end

  local function OpenCollections()
    return OpenViaMicroButton(
      "CollectionsMicroButton",
      { "CollectionsJournal" },
      rawget(_G, "ToggleCollectionsJournal")
    )
  end

  local function OpenGuild()
    EnsureAddOnLoaded("Blizzard_Communities")
    return OpenViaMicroButton("GuildMicroButton", { "CommunitiesFrame", "GuildFrame" }, rawget(_G, "ToggleGuildFrame"))
  end

  return {
    professions = OpenProfessions,
    talents = OpenTalents,
    spellbook = OpenSpellbook,
    achievements = OpenAchievements,
    quests = OpenQuestLog,
    dungeons = OpenDungeons,
    journal = OpenJournal,
    collections = OpenCollections,
    guild = OpenGuild,
  }
end

local function MergePanelUIActions(isInCombat, overrides)
  local actions = BuildDefaultPanelUIActions(isInCombat)
  if type(overrides) ~= "table" then
    return actions
  end

  for key, value in pairs(overrides) do
    if type(value) == "function" then
      actions[key] = value
    end
  end

  return actions
end

local function ResolvePanelUICloseAnchor(gameMenuFrame)
  if type(gameMenuFrame) ~= "table" then
    return nil
  end

  local header = rawget(gameMenuFrame, "Header")
  if type(header) == "table" then
    local headerCloseButton = rawget(header, "CloseButton")
    if type(headerCloseButton) == "table" then
      return headerCloseButton
    end
  end

  local closeButton = rawget(gameMenuFrame, "CloseButton")
  if type(closeButton) == "table" then
    return closeButton
  end

  local globalCloseButton = rawget(_G, "GameMenuFrameCloseButton")
  if type(globalCloseButton) == "table" then
    return globalCloseButton
  end

  return nil
end

local ApplyPanelUILocalization
local HideGameMenuFrame
local RunAfterGameMenuClose

local function GetPanelUIButtonStackHeight(buttons, buttonHeight)
  if type(buttons) ~= "table" then
    return 0
  end

  local resolvedButtonCount = #buttons
  if resolvedButtonCount == 0 then
    return 0
  end

  local totalHeight = resolvedButtonCount * buttonHeight
  for index = 2, resolvedButtonCount do
    local button = buttons[index]
    local gapBefore = type(button) == "table" and tonumber(button._gapBefore) or nil
    totalHeight = totalHeight + math.max(0, gapBefore or PANEL_UI_BUTTON_GAP)
  end

  return totalHeight
end

PositionPanelUIButtons = function(state)
  if type(state) ~= "table" then
    return
  end

  local gameMenuFrame = state.gameMenuFrame
  local hostFrame = state.hostFrame
  local panelFrame = state.panelFrame
  if type(gameMenuFrame) ~= "table" or type(hostFrame) ~= "table" then
    return
  end
  local buttonWidth, buttonHeight = ResolvePanelUIButtonSize(gameMenuFrame)
  local buttons = state.buttons or {}
  local hasShortcutsHeader = type(state.shortcutsHeader) == "table"
  local stackHeight = GetPanelUIButtonStackHeight(buttons, buttonHeight)
  if hasShortcutsHeader then
    stackHeight = stackHeight + PANEL_UI_SECTION_HEADER_HEIGHT + PANEL_UI_SECTION_HEADER_GAP
  end
  local panelWidth = ResolvePanelUIWidth(buttonWidth)
  local panelHeight = stackHeight + PANEL_UI_PADDING_TOP + PANEL_UI_PADDING_BOTTOM
  state.buttonWidth = buttonWidth
  state.buttonHeight = buttonHeight
  state.panelWidth = panelWidth
  state.panelHeight = panelHeight

  state.anchor = ResolvePanelUICloseAnchor(gameMenuFrame)

  if type(hostFrame.ClearAllPoints) == "function" then
    hostFrame:ClearAllPoints()
  end
  hostFrame:SetPoint("TOPRIGHT", gameMenuFrame, "TOPLEFT", PANEL_UI_OFFSET_X, PANEL_UI_OFFSET_Y)
  hostFrame:SetSize(panelWidth, panelHeight)
  if gameMenuFrame.IsShown and gameMenuFrame:IsShown() then
    hostFrame:Show()
  else
    hostFrame:Hide()
  end

  if type(panelFrame) == "table" then
    if type(panelFrame.ClearAllPoints) == "function" then
      panelFrame:ClearAllPoints()
    end
    if type(panelFrame.SetPoint) == "function" then
      panelFrame:SetPoint("TOPLEFT", hostFrame, "TOPLEFT", 0, 0)
    end
    if type(panelFrame.SetSize) == "function" then
      panelFrame:SetSize(panelWidth, panelHeight)
    end
  end

  local L = type(state.getL) == "function" and state.getL() or {}
  if hasShortcutsHeader then
    local header = state.shortcutsHeader
    if type(header.ClearAllPoints) == "function" then
      header:ClearAllPoints()
    end
    if type(header.SetPoint) == "function" then
      header:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", PANEL_UI_PADDING_X, -PANEL_UI_PADDING_TOP)
    end
    if type(header.SetText) == "function" then
      local headerText = type(L.PANEL_HEADER_SHORTCUTS) == "string" and L.PANEL_HEADER_SHORTCUTS or "Shortcuts"
      header:SetText(headerText)
    end
    if type(header.Show) == "function" then
      header:Show()
    end
  end

  if type(state.shortcutsHeaderLine) == "table" then
    local line = state.shortcutsHeaderLine
    if type(line.ClearAllPoints) == "function" then
      line:ClearAllPoints()
    end
    if type(line.SetPoint) == "function" then
      line:SetPoint(
        "TOPLEFT",
        panelFrame,
        "TOPLEFT",
        PANEL_UI_PADDING_X,
        -(PANEL_UI_PADDING_TOP + PANEL_UI_SECTION_HEADER_HEIGHT)
      )
      line:SetPoint(
        "TOPRIGHT",
        panelFrame,
        "TOPRIGHT",
        -PANEL_UI_PADDING_X,
        -(PANEL_UI_PADDING_TOP + PANEL_UI_SECTION_HEADER_HEIGHT)
      )
    end
    if type(line.Show) == "function" then
      line:Show()
    end
  end

  local firstButtonTopOffset = -(
    PANEL_UI_PADDING_TOP
    + (hasShortcutsHeader and (PANEL_UI_SECTION_HEADER_HEIGHT + PANEL_UI_SECTION_HEADER_GAP) or 0)
  )
  local secureUpdatesBlocked = IsPanelUISecureUpdateBlocked(state)
  local needsSecureRetry = false

  local previousButton = nil
  for _, button in ipairs(buttons) do
    if IsPanelUISecureMacroButton(button) and secureUpdatesBlocked then
      needsSecureRetry = true
    else
      if type(button.SetSize) == "function" then
        button:SetSize(buttonWidth, buttonHeight)
      end
      if type(button.ClearAllPoints) == "function" then
        button:ClearAllPoints()
      end

      if previousButton ~= nil then
        local gapBefore = math.max(0, tonumber(button._gapBefore) or PANEL_UI_BUTTON_GAP)
        button:SetPoint("TOP", previousButton, "BOTTOM", 0, -gapBefore)
      else
        button:SetPoint("TOP", panelFrame or hostFrame, "TOP", 0, firstButtonTopOffset)
      end
    end

    previousButton = button
  end

  if needsSecureRetry then
    QueuePanelUISecureStateRefresh(state)
  else
    ClearQueuedPanelUISecureState(state)
  end
end

ApplyPanelUISecureState = function(state, force)
  if type(state) ~= "table" then
    return false
  end

  if not force and IsPanelUISecureUpdateBlocked(state) then
    QueuePanelUISecureStateRefresh(state)
    return false
  end

  PositionPanelUIButtons(state)
  RefreshPanelUISecureButtons(state)
  SyncPanelUISecureButtonVisibility(state)
  ClearQueuedPanelUISecureState(state)
  return true
end

HideGameMenuFrame = function(gameMenuFrame)
  if type(gameMenuFrame) ~= "table" then
    return false
  end

  local hideUIPanel = rawget(_G, "HideUIPanel")
  if type(hideUIPanel) == "function" then
    local ok = pcall(hideUIPanel, gameMenuFrame)
    if ok then
      return true
    end
  end

  if type(gameMenuFrame.Hide) == "function" then
    gameMenuFrame:Hide()
    return true
  end

  return false
end

RunAfterGameMenuClose = function(callback)
  if type(callback) ~= "function" then
    return
  end

  local timer = rawget(_G, "C_Timer")
  local after = type(timer) == "table" and rawget(timer, "After") or nil
  if type(after) == "function" then
    after(0, callback)
    return
  end

  callback()
end

ApplyPanelUILocalization = function(state)
  if type(state) ~= "table" then
    return
  end

  local L = type(state.getL) == "function" and state.getL() or {}
  for _, button in ipairs(state.buttons or {}) do
    local text = type(L[button._labelKey]) == "string" and L[button._labelKey] or button._fallbackText
    if type(button.SetText) == "function" then
      button:SetText(text)
    end
  end
end

function UI.EnsurePanelUI(opts)
  opts = opts or {}

  local gameMenuFrame = opts.gameMenuFrame or rawget(_G, "GameMenuFrame")
  if type(gameMenuFrame) ~= "table" then
    return nil
  end

  local actionOverrides = opts.panelActions or opts.microMenuActions

  if type(panelUIState) == "table" and panelUIState.gameMenuFrame == gameMenuFrame then
    if type(opts.getL) == "function" then
      panelUIState.getL = opts.getL
    end
    panelUIState.isEnabled = opts.isEnabled
    panelUIState.isInCombat = type(opts.isInCombat) == "function" and opts.isInCombat or nil
    panelUIState.actions = MergePanelUIActions(opts.isInCombat, actionOverrides)
    ApplyPanelUISecureState(panelUIState)
    ApplyPanelUILocalization(panelUIState)
    return panelUIState
  end

  local state = {
    gameMenuFrame = gameMenuFrame,
    getL = type(opts.getL) == "function" and opts.getL or function()
      return {}
    end,
    actions = MergePanelUIActions(opts.isInCombat, actionOverrides),
    isEnabled = opts.isEnabled,
    isInCombat = type(opts.isInCombat) == "function" and opts.isInCombat or nil,
    buttons = {},
    buttonsById = {},
    anchor = nil,
  }

  local hostParent = opts.parent or rawget(_G, "UIParent") or gameMenuFrame
  local frameStrata = type(gameMenuFrame.GetFrameStrata) == "function" and gameMenuFrame:GetFrameStrata() or nil
  local baseFrameLevel = type(gameMenuFrame.GetFrameLevel) == "function" and gameMenuFrame:GetFrameLevel() or 1
  state.frameStrata = frameStrata
  state.baseFrameLevel = baseFrameLevel
  local hostFrame = CreateFrame("Frame", nil, hostParent)
  if frameStrata ~= nil and type(hostFrame.SetFrameStrata) == "function" then
    hostFrame:SetFrameStrata(frameStrata)
  end
  if type(hostFrame.SetFrameLevel) == "function" then
    hostFrame:SetFrameLevel(baseFrameLevel + 10)
  end
  if type(hostFrame.EnableMouse) == "function" then
    hostFrame:EnableMouse(true)
  end
  state.hostFrame = hostFrame
  state.buttonWidth, state.buttonHeight = ResolvePanelUIButtonSize(gameMenuFrame)
  local panelFrame = CreateFrame("Frame", nil, hostFrame, "BackdropTemplate")
  if frameStrata ~= nil and type(panelFrame.SetFrameStrata) == "function" then
    panelFrame:SetFrameStrata(frameStrata)
  end
  if type(panelFrame.SetFrameLevel) == "function" then
    panelFrame:SetFrameLevel(baseFrameLevel + 10)
  end
  ApplyPanelUIBackdrop(panelFrame)
  state.panelFrame = panelFrame

  if type(gameMenuFrame.HookScript) == "function" then
    gameMenuFrame:HookScript("OnShow", function()
      if type(state.isEnabled) == "function" and not state.isEnabled() then
        return
      end
      ApplyPanelUISecureState(state)
      if state.hostFrame and type(state.hostFrame.Show) == "function" then
        state.hostFrame:Show()
      end
    end)
    gameMenuFrame:HookScript("OnHide", function()
      RunAfterGameMenuClose(function()
        if type(state.gameMenuFrame) == "table" and state.gameMenuFrame.IsShown and state.gameMenuFrame:IsShown() then
          return
        end
        if state.hostFrame and type(state.hostFrame.Hide) == "function" then
          state.hostFrame:Hide()
        end
      end)
    end)
  end

  if type(panelFrame.CreateFontString) == "function" then
    state.shortcutsHeader = panelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if type(state.shortcutsHeader.SetTextColor) == "function" then
      local td = Colors.TEXT_DIM
      state.shortcutsHeader:SetTextColor(td[1], td[2], td[3], 1)
    end
    if type(state.shortcutsHeader.SetJustifyH) == "function" then
      state.shortcutsHeader:SetJustifyH("LEFT")
    end
  end

  if type(panelFrame.CreateTexture) == "function" then
    state.shortcutsHeaderLine = panelFrame:CreateTexture(nil, "ARTWORK")
    if type(state.shortcutsHeaderLine.SetHeight) == "function" then
      state.shortcutsHeaderLine:SetHeight(1)
    end
    if type(state.shortcutsHeaderLine.SetColorTexture) == "function" then
      local ab = Colors.ACCENT_BLUE
      state.shortcutsHeaderLine:SetColorTexture(ab[1], ab[2], ab[3], 0.3)
    end
  end

  for index, entry in ipairs(PANEL_UI_ENTRIES) do
    local buttonTemplate = type(entry.secureMacroText) == "string" and "SecureActionButtonTemplate,BackdropTemplate"
      or "BackdropTemplate"
    local buttonParent = type(entry.secureMacroText) == "string" and gameMenuFrame or panelFrame
    local button = CreatePanelUIButton(
      buttonParent,
      frameStrata,
      baseFrameLevel,
      10 + index,
      entry.icon,
      buttonTemplate,
      type(entry.secureMacroText) == "string"
    )

    button._actionId = entry.id
    button._labelKey = entry.labelKey
    button._fallbackText = entry.fallbackText
    button._gapBefore = math.max(0, tonumber(entry.gapBefore) or PANEL_UI_BUTTON_GAP)
    button._verticalIndex = index
    button._secureMacroText = entry.secureMacroText

    if type(entry.secureMacroText) == "string" and type(button.SetAttribute) == "function" then
      button._secureMacroText = entry.secureMacroText
    else
      button:SetScript("OnClick", function(self)
        local action = state.actions[self._actionId]
        if type(action) ~= "function" then
          return
        end

        HideGameMenuFrame(state.gameMenuFrame)
        RunAfterGameMenuClose(action)
      end)
    end

    state.buttons[index] = button
    state.buttonsById[entry.id] = button
  end

  function state.ApplyLocalization()
    ApplyPanelUISecureState(state)
    ApplyPanelUILocalization(state)
  end

  state.SyncVisibility = function()
    ApplyPanelUISecureState(state)
  end

  panelUIState = state
  ApplyPanelUISecureState(state)
  ApplyPanelUILocalization(state)
  return state
end

UI.EnsureGameMenuMicroButtons = UI.EnsurePanelUI

local function SavePosition(target)
  if not IsiLiveDB then
    IsiLiveDB = {}
  end
  local point, _, relativePoint, x, y = target:GetPoint()
  IsiLiveDB.position = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function CreateDragHandle(frame)
  local dragHandle = CreateFrame("Frame", nil, frame)
  dragHandle:SetPoint("TOPLEFT", 0, 0)
  dragHandle:SetPoint("TOPRIGHT", 0, 0)
  dragHandle:SetHeight(26)
  dragHandle:SetFrameStrata(frame:GetFrameStrata())
  dragHandle:SetFrameLevel(frame:GetFrameLevel() + 100)
  dragHandle:EnableMouse(true)
  dragHandle:RegisterForDrag("LeftButton")
  dragHandle:SetScript("OnDragStart", function()
    frame:StartMoving()
  end)
  dragHandle:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    SavePosition(frame)
  end)

  if type(dragHandle.CreateTexture) == "function" then
    local gripColor = Colors.TEXT_DIM
    for i = 0, 2 do
      local grip = dragHandle:CreateTexture(nil, "ARTWORK")
      if type(grip.SetSize) == "function" then
        grip:SetSize(20, 1)
      end
      if type(grip.SetPoint) == "function" then
        grip:SetPoint("CENTER", dragHandle, "CENTER", 0, (1 - i) * 3)
      end
      if type(grip.SetColorTexture) == "function" then
        grip:SetColorTexture(gripColor[1], gripColor[2], gripColor[3], 0.3)
      end
    end
  end

  return dragHandle
end

local function CreateVisibilityController(frame, onShownInGroup, onShownNoGroup, isInCombat)
  local pendingVisible = nil

  local function SetVisible(visible)
    if isInCombat and isInCombat() then
      pendingVisible = visible and true or false
      return false
    end
    pendingVisible = nil

    if visible then
      if not frame:IsShown() then
        frame:Show()
        return true
      end
      return false
    end

    if frame:IsShown() then
      frame:Hide()
      return true
    end
    return false
  end

  local function ToggleVisibility(isInGroup)
    if isInCombat and isInCombat() then
      local wantVisible = not frame:IsShown()
      pendingVisible = wantVisible
      return
    end

    if frame:IsShown() then
      SetVisible(false)
      return
    end

    local didShow = SetVisible(true)
    if didShow then
      if isInGroup then
        onShownInGroup()
      else
        onShownNoGroup()
      end
    end
  end

  local function GetPendingVisible()
    return pendingVisible
  end

  return SetVisible, ToggleVisibility, GetPendingVisible
end

local function CreateHeightController(frame, isInCombat)
  local pendingHeight = nil
  local function SetHeightSafe(height)
    if isInCombat() then
      pendingHeight = height
      return
    end
    pendingHeight = nil
    frame:SetHeight(height)
  end
  local function GetPendingHeight()
    return pendingHeight
  end
  return SetHeightSafe, GetPendingHeight
end

function UI.CreateMainFrame(opts)
  opts = opts or {}
  local minHeight = tonumber(opts.minHeight) or 236
  local parent = opts.parent or UIParent
  local isInCombat = opts.isInCombat or function()
    return InCombatLockdown and InCombatLockdown()
  end
  local onShownInGroup = opts.onShownInGroup or function() end
  local onShownNoGroup = opts.onShownNoGroup or function() end

  local frame = CreateFrame("Frame", "isiLiveMainFrame", parent, "BackdropTemplate")
  frame:SetSize(755, minHeight)
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  frame:Hide()

  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(self)
  end)

  local dragHandle = CreateDragHandle(frame)

  local closeButton = createRedCloseButton(frame, {
    point = { "TOPRIGHT", frame, "TOPRIGHT", -2, -2 },
    frameLevel = dragHandle:GetFrameLevel() + 2,
  })

  local SetVisible, ToggleVisibility, GetPendingVisible =
    CreateVisibilityController(frame, onShownInGroup, onShownNoGroup, isInCombat)
  local SetHeightSafe, GetPendingHeight = CreateHeightController(frame, isInCombat)

  local function ApplyStoredPosition(pos)
    if not pos then
      return
    end
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, parent, pos.relativePoint, pos.x, pos.y)
  end

  closeButton:SetScript("OnClick", function()
    -- Always hide immediately, even during combat (normal frames allow Hide)
    frame:Hide()
  end)

  return {
    frame = frame,
    closeButton = closeButton,
    SetVisible = SetVisible,
    SetHeightSafe = SetHeightSafe,
    ToggleVisibility = ToggleVisibility,
    ApplyStoredPosition = ApplyStoredPosition,
    GetPendingHeight = GetPendingHeight,
    GetPendingVisible = GetPendingVisible,
  }
end
