local _, addonTable = ...
addonTable = addonTable or {}

-- isiLive's own configuration window (rule 237). It hosts the settings canvas
-- built by ui/isiLive_settings.lua instead of Blizzard's Settings panel, so
-- the window can carry its own search (stage 2, rule 241). Blizzard only keeps a
-- small vertical-layout stub category: Blizzard's settings search walks the
-- initializers of vertical layouts only (SettingsPanelMixin:
-- FindInitializersMatchingSearchText, 12.1.5), so a canvas category is never
-- found, while the stub's button initializer with search tags is.
--
-- The window is a plain frame without any secure child: opening, closing and
-- moving it are allowed in combat. Controls that reach protected frames keep
-- their own combat deferral (main-frame scale/position, bindings).
local ConfigWindow = {}
addonTable.ConfigWindow = ConfigWindow

local UICommon = addonTable.UICommon or {}

ConfigWindow.FRAME_NAME = "isiLiveConfigWindow"
ConfigWindow.WIDTH = 780
ConfigWindow.HEIGHT = 640
-- Matches the default 27 px band of UICommon.CreatePanelChrome.
ConfigWindow.TITLE_HEIGHT = 27
-- Keeps the square body fill clear of the modern window's rounded bottom
-- corners (WINDOW_RADIUS 6 in ui/isiLive_ui_design.lua).
ConfigWindow.BODY_BOTTOM_INSET = 6
-- Above the main frame (MEDIUM) and level with Blizzard's SettingsPanel
-- (HIGH); the settings dropdown menus use DIALOG and stay on top of it.
ConfigWindow.FRAME_STRATA = "HIGH"
ConfigWindow.POSITION_DB_KEY = "configWindowPosition"
ConfigWindow.LOGO_TEXTURE = "Interface\\Icons\\INV_Misc_GroupLooking"
-- Plain-text search tags for Blizzard's settings search. The category name
-- carries a color code, which a plain substring search never matches.
ConfigWindow.STUB_SEARCH_TAGS = { "isiLive", "isi Live" }
-- Search box in the title band (rule 241), left of the close button.
ConfigWindow.SEARCH_WIDTH = 220
ConfigWindow.SEARCH_HEIGHT = 19
ConfigWindow.SEARCH_RIGHT_INSET = 32
ConfigWindow.SEARCH_MAX_LETTERS = 64
-- Delay between the last keystroke and the filter pass.
ConfigWindow.SEARCH_DEBOUNCE_SECONDS = 0.15

local BRAND_TITLE = "isi|cff1e90ffLive|r"
local VALID_ANCHOR_POINTS = {
  TOPLEFT = true,
  TOP = true,
  TOPRIGHT = true,
  LEFT = true,
  CENTER = true,
  RIGHT = true,
  BOTTOMLEFT = true,
  BOTTOM = true,
  BOTTOMRIGHT = true,
}

local function ResolveText(getL, key, fallback)
  local labels = type(getL) == "function" and getL() or nil
  local value = type(labels) == "table" and labels[key] or nil
  if type(value) == "string" and value ~= "" then
    return value
  end
  return fallback
end

local function ReadStoredPosition(getDB)
  local db = type(getDB) == "function" and getDB() or nil
  local pos = type(db) == "table" and db[ConfigWindow.POSITION_DB_KEY] or nil
  if
    type(pos) ~= "table"
    or not VALID_ANCHOR_POINTS[pos.point]
    or not VALID_ANCHOR_POINTS[pos.relativePoint]
    or type(pos.x) ~= "number"
    or type(pos.y) ~= "number"
  then
    return nil
  end
  return pos
end

-- Registers the frame name with UISpecialFrames once, so ESC closes it.
local function RegisterEscapeClose(frameName)
  local specialFrames = rawget(_G, "UISpecialFrames")
  if type(specialFrames) ~= "table" then
    return false
  end
  for _, name in ipairs(specialFrames) do
    if name == frameName then
      return true
    end
  end
  specialFrames[#specialFrames + 1] = frameName
  return true
end

local function ShowTooltip(owner, title, body)
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return
  end
  tooltip:SetOwner(owner, "ANCHOR_BOTTOM")
  if type(tooltip.AddLine) == "function" then
    tooltip:AddLine(title)
    tooltip:AddLine(body, 0.8, 0.8, 0.8, true)
  end
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
end

local function HideTooltip()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end

-- Search box (rule 241) in the title band of `window`; adds
-- window.SetSearchText / GetSearchText / UpdateSearchPlaceholder /
-- EndSearch. onSearch(text) receives the debounced text.
local function AttachSearchBox(window, getL, onSearch)
  -- A plain EditBox without template, painted with the
  -- design-aware FLAT_BUTTON backdrop; above the drag handle so it takes the
  -- clicks in the title band. It never takes focus on its own: a focused box
  -- swallows the movement keys.
  local frame, dragHandle = window.frame, window.dragHandle
  local searchBox = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
  searchBox:SetSize(ConfigWindow.SEARCH_WIDTH, ConfigWindow.SEARCH_HEIGHT)
  searchBox:SetPoint(
    "TOPRIGHT",
    frame,
    "TOPRIGHT",
    -ConfigWindow.SEARCH_RIGHT_INSET,
    -math.floor((ConfigWindow.TITLE_HEIGHT - ConfigWindow.SEARCH_HEIGHT) / 2) - 1
  )
  if type(searchBox.SetFrameLevel) == "function" and type(dragHandle.GetFrameLevel) == "function" then
    searchBox:SetFrameLevel((tonumber(dragHandle:GetFrameLevel()) or 1) + 2)
  end
  if type(searchBox.SetAutoFocus) == "function" then
    searchBox:SetAutoFocus(false)
  end
  if type(searchBox.SetFontObject) == "function" then
    searchBox:SetFontObject("GameFontHighlightSmall")
  end
  if type(searchBox.SetTextInsets) == "function" then
    searchBox:SetTextInsets(6, 6, 0, 0)
  end
  if type(searchBox.SetMaxLetters) == "function" then
    searchBox:SetMaxLetters(ConfigWindow.SEARCH_MAX_LETTERS)
  end
  if type(UICommon.ApplyBackdrop) == "function" then
    UICommon.ApplyBackdrop(searchBox, "FLAT_BUTTON")
  end
  local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  placeholder:SetPoint("LEFT", searchBox, "LEFT", 6, 0)
  placeholder:SetPoint("RIGHT", searchBox, "RIGHT", -6, 0)
  placeholder:SetJustifyH("LEFT")
  if type(UICommon.PaintToken) == "function" then
    UICommon.PaintToken(placeholder, "SetTextColor", "TEXT_DIM")
  end
  window.searchBox = searchBox
  window.searchPlaceholder = placeholder

  local appliedSearch = ""
  local searchGeneration = 0
  local suppressTextChanged = false

  local function ReadSearchText()
    local text = searchBox:GetText()
    return type(text) == "string" and text or ""
  end

  local function UpdatePlaceholder()
    local focused = type(searchBox.HasFocus) == "function" and searchBox:HasFocus() == true
    if ReadSearchText() == "" and not focused then
      placeholder:Show()
    else
      placeholder:Hide()
    end
  end

  local function FlushSearch()
    searchGeneration = searchGeneration + 1
    local text = ReadSearchText()
    if text == appliedSearch then
      return
    end
    appliedSearch = text
    onSearch(text)
  end

  -- Debounced: only the last keystroke of a burst filters, and only while
  -- the window is open.
  local function ScheduleSearch()
    searchGeneration = searchGeneration + 1
    local generation = searchGeneration
    local timer = rawget(_G, "C_Timer")
    if type(timer) ~= "table" or type(timer.After) ~= "function" then
      FlushSearch()
      return
    end
    timer.After(ConfigWindow.SEARCH_DEBOUNCE_SECONDS, function()
      if generation ~= searchGeneration or not window.IsOpen() then
        return
      end
      FlushSearch()
    end)
  end

  -- Sets the search text and filters at once (no debounce).
  function window.SetSearchText(text)
    local value = text
    if type(value) ~= "string" then
      value = ""
    end
    suppressTextChanged = true
    searchBox:SetText(value)
    suppressTextChanged = false
    UpdatePlaceholder()
    FlushSearch()
  end

  -- The text the last filter pass used ("" = no search).
  function window.GetSearchText()
    return appliedSearch
  end

  searchBox:SetScript("OnTextChanged", function()
    UpdatePlaceholder()
    if suppressTextChanged then
      return
    end
    ScheduleSearch()
  end)
  -- ESC in the box: the first clears the search, the next one (empty box)
  -- closes the window. Without focus ESC reaches UISpecialFrames and closes
  -- the window directly; closing clears the search as well.
  searchBox:SetScript("OnEscapePressed", function(self)
    if ReadSearchText() ~= "" then
      window.SetSearchText("")
      return
    end
    self:ClearFocus()
    window.Close()
  end)
  searchBox:SetScript("OnEnterPressed", function(self)
    FlushSearch()
    self:ClearFocus()
  end)
  searchBox:SetScript("OnEditFocusGained", UpdatePlaceholder)
  searchBox:SetScript("OnEditFocusLost", UpdatePlaceholder)
  searchBox:SetScript("OnEnter", function(self)
    ShowTooltip(
      self,
      ResolveText(getL, "CONFIG_SEARCH_TOOLTIP_TITLE", "Search options"),
      ResolveText(
        getL,
        "CONFIG_SEARCH_TOOLTIP_BODY",
        "Matches names, descriptions and keywords; all words must match. ESC clears the search."
      )
    )
  end)
  searchBox:SetScript("OnLeave", HideTooltip)

  window.UpdateSearchPlaceholder = UpdatePlaceholder

  -- Closing ends the search: the next open shows every option again.
  function window.EndSearch()
    if type(searchBox.ClearFocus) == "function" then
      searchBox:ClearFocus()
    end
    if ReadSearchText() ~= "" or appliedSearch ~= "" then
      window.SetSearchText("")
    end
  end
end

-- opts.getL, opts.getDB, opts.onOpen (called after every open; the settings
-- panel builds and repaints there), opts.onSearch(text) (search text after
-- the debounce, "" when the search is cleared), opts.parent (default UIParent).
function ConfigWindow.Create(opts)
  opts = opts or {}
  local getL = opts.getL
  local getDB = opts.getDB
  local onOpen = type(opts.onOpen) == "function" and opts.onOpen or function() end
  local onSearch = type(opts.onSearch) == "function" and opts.onSearch or function() end
  local parent = opts.parent or rawget(_G, "UIParent")

  local frame = CreateFrame("Frame", ConfigWindow.FRAME_NAME, parent, "BackdropTemplate")
  frame:SetSize(ConfigWindow.WIDTH, ConfigWindow.HEIGHT)
  frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
  frame:SetFrameStrata(ConfigWindow.FRAME_STRATA)
  if type(frame.SetToplevel) == "function" then
    frame:SetToplevel(true)
  end
  frame:SetMovable(true)
  frame:EnableMouse(true)
  if type(frame.SetClampedToScreen) == "function" then
    frame:SetClampedToScreen(true)
  end
  frame:Hide()

  -- Title band first: the modern window decoration reads it when it builds.
  local chrome = type(UICommon.CreatePanelChrome) == "function"
      and UICommon.CreatePanelChrome(frame, { height = ConfigWindow.TITLE_HEIGHT })
    or nil
  if type(UICommon.ApplyBackdrop) == "function" then
    UICommon.ApplyBackdrop(frame, "MAIN_FRAME")
  end

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("LEFT", frame, "TOPLEFT", 12, -(ConfigWindow.TITLE_HEIGHT / 2) - 1)
  if type(UICommon.PaintToken) == "function" then
    UICommon.PaintToken(title, "SetTextColor", "GOLD_TITLE")
  end
  title:SetText(BRAND_TITLE)

  local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  subtitle:SetPoint("LEFT", title, "RIGHT", 8, 0)
  if type(UICommon.PaintToken) == "function" then
    UICommon.PaintToken(subtitle, "SetTextColor", "TEXT_SECTION")
  end

  local window = {
    frame = frame,
    chrome = chrome,
    title = title,
    subtitle = subtitle,
  }

  local function SavePosition()
    local db = type(getDB) == "function" and getDB() or nil
    if type(db) ~= "table" or type(frame.GetPoint) ~= "function" then
      return
    end
    local point, _, relativePoint, x, y = frame:GetPoint()
    if not VALID_ANCHOR_POINTS[point] or not VALID_ANCHOR_POINTS[relativePoint] then
      return
    end
    db[ConfigWindow.POSITION_DB_KEY] = {
      point = point,
      relativePoint = relativePoint,
      x = tonumber(x) or 0,
      y = tonumber(y) or 0,
    }
  end

  local function ApplyStoredPosition()
    local pos = ReadStoredPosition(getDB)
    frame:ClearAllPoints()
    if pos then
      frame:SetPoint(pos.point, parent, pos.relativePoint, pos.x, pos.y)
    else
      frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
    end
  end
  window.ApplyStoredPosition = ApplyStoredPosition

  -- Only the title band moves the window; the content keeps its clicks,
  -- slider drags and mouse wheel.
  local dragHandle = CreateFrame("Frame", nil, frame)
  dragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  dragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -1)
  dragHandle:SetHeight(ConfigWindow.TITLE_HEIGHT)
  dragHandle:EnableMouse(true)
  dragHandle:RegisterForDrag("LeftButton")
  local dragging = false
  dragHandle:SetScript("OnDragStart", function()
    dragging = true
    frame:StartMoving()
  end)
  local function EndDrag()
    if not dragging then
      return
    end
    dragging = false
    frame:StopMovingOrSizing()
    SavePosition()
  end
  dragHandle:SetScript("OnDragStop", EndDrag)
  window.dragHandle = dragHandle

  local closeButton = nil
  if type(UICommon.CreateCloseButton) == "function" then
    closeButton = UICommon.CreateCloseButton(frame, {
      point = { "TOPRIGHT", frame, "TOPRIGHT", -4, -4 },
      tooltipTitleKey = "CONFIG_CLOSE_TOOLTIP_TITLE",
      tooltipBodyKey = "CONFIG_CLOSE_TOOLTIP_BODY",
      tooltipTitle = "Close configuration",
      tooltipBody = "ESC closes the window as well.",
    })
    closeButton:SetScript("OnClick", function()
      window.Close()
    end)
  end
  window.closeButton = closeButton

  window.escapeRegistered = RegisterEscapeClose(ConfigWindow.FRAME_NAME)

  AttachSearchBox(window, getL, onSearch)

  -- Closing (button, ESC, /il settings) ends the search. A window hidden
  -- mid-drag still stores its drop point.
  frame:SetScript("OnHide", function()
    EndDrag()
    window.EndSearch()
  end)

  -- Docks the settings canvas below the title band.
  function window.AttachCanvas(canvas)
    if type(canvas) ~= "table" then
      return false
    end
    canvas:SetParent(frame)
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -(ConfigWindow.TITLE_HEIGHT + 2))
    canvas:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, ConfigWindow.BODY_BOTTOM_INSET)
    canvas:Show()
    window.canvas = canvas
    return true
  end

  function window.RefreshTexts()
    -- One label read per repaint for both texts.
    local labels = type(getL) == "function" and getL() or nil
    local function Labels()
      return labels
    end
    local titleText = ResolveText(Labels, "CONFIG_WINDOW_TITLE", "Configuration")
    local placeholderText = ResolveText(Labels, "CONFIG_SEARCH_PLACEHOLDER", "Search options...")
    subtitle:SetText(titleText)
    window.searchPlaceholder:SetText(placeholderText)
    window.UpdateSearchPlaceholder()
  end

  function window.IsOpen()
    return frame:IsShown() == true
  end

  function window.Open()
    ApplyStoredPosition()
    window.RefreshTexts()
    frame:Show()
    if type(frame.Raise) == "function" then
      frame:Raise()
    end
    onOpen()
    return true
  end

  function window.Close()
    if not window.IsOpen() then
      return false
    end
    frame:Hide()
    return true
  end

  function window.Toggle()
    if window.IsOpen() then
      window.Close()
      return false
    end
    return window.Open()
  end

  window.RefreshTexts()
  return window
end

-- Updates a Blizzard initializer's display data in place; the settings list
-- reads it on its next display. Returns the data table or nil.
local function GetInitializerData(initializer)
  if type(initializer) ~= "table" then
    return nil
  end
  if type(initializer.GetData) == "function" then
    local data = initializer:GetData()
    if type(data) == "table" then
      return data
    end
  end
  return type(initializer.data) == "table" and initializer.data or nil
end

local function BuildStubHeaderText(hint)
  return "|T" .. ConfigWindow.LOGO_TEXTURE .. ":20:20|t " .. hint
end

-- Blizzard settings stub: a vertical-layout category with a header (logo and
-- a short hint) and one button that closes the Settings panel and opens the
-- config window. Returns nil when the 12.x vertical-layout API is missing.
-- opts.getL, opts.open (opens the config window).
function ConfigWindow.RegisterBlizzardStub(opts)
  opts = opts or {}
  local getL = opts.getL
  local open = type(opts.open) == "function" and opts.open or function() end
  local settings = rawget(_G, "Settings")
  local createButton = rawget(_G, "CreateSettingsButtonInitializer")
  local createHeader = rawget(_G, "CreateSettingsListSectionHeaderInitializer")
  if
    type(settings) ~= "table"
    or type(settings.RegisterVerticalLayoutCategory) ~= "function"
    or type(createButton) ~= "function"
  then
    return nil
  end

  local function Texts()
    return {
      label = ResolveText(getL, "SETTINGS_STUB_LABEL", "isiLive configuration"),
      hint = ResolveText(getL, "SETTINGS_STUB_HINT", "All isiLive options are in their own window."),
      button = ResolveText(getL, "BTN_OPEN_CONFIG", "Open config"),
    }
  end

  -- Out of combat the stub hides Blizzard's Settings panel first. In combat
  -- HideUIPanel from addon code is refused (CheckProtectedFunctionsAllowed),
  -- so the panel stays and the config window is raised above it.
  local function OnClick()
    local inCombat = rawget(_G, "InCombatLockdown")
    local locked = type(inCombat) == "function" and inCombat() == true
    local blizzardPanel = rawget(_G, "SettingsPanel")
    local hidePanel = rawget(_G, "HideUIPanel")
    if
      not locked
      and type(blizzardPanel) == "table"
      and type(blizzardPanel.IsShown) == "function"
      and blizzardPanel:IsShown()
      and type(hidePanel) == "function"
    then
      hidePanel(blizzardPanel)
    end
    open()
  end

  local texts = Texts()
  local category, layout = settings.RegisterVerticalLayoutCategory(BRAND_TITLE)
  if type(category) ~= "table" or type(layout) ~= "table" or type(layout.AddInitializer) ~= "function" then
    return nil
  end

  local stub = { category = category, layout = layout, onClick = OnClick }
  if type(createHeader) == "function" then
    stub.header = createHeader(BuildStubHeaderText(texts.hint), texts.hint)
    if stub.header then
      layout:AddInitializer(stub.header)
    end
  end
  -- addSearchTags = true tags the label and the button text; the plain brand
  -- tags make "isilive" match in every language.
  stub.button = createButton(texts.label, texts.button, OnClick, texts.hint, true)
  -- Blizzard appends every tag; remember what is tagged so repeated refreshes
  -- (language, opacity, reset) never grow the list.
  local taggedWords = { [texts.label] = true, [texts.button] = true }
  local function TagOnce(word)
    if type(word) ~= "string" or word == "" or taggedWords[word] then
      return
    end
    if type(stub.button) == "table" and type(stub.button.AddSearchTags) == "function" then
      stub.button:AddSearchTags(word)
      taggedWords[word] = true
    end
  end
  for _, tag in ipairs(ConfigWindow.STUB_SEARCH_TAGS) do
    TagOnce(tag)
  end
  layout:AddInitializer(stub.button)
  if type(settings.RegisterAddOnCategory) == "function" then
    settings.RegisterAddOnCategory(category)
  end

  -- Language switch: relabels the stub and tags the new words for search.
  function stub.Refresh()
    local fresh = Texts()
    local headerData = GetInitializerData(stub.header)
    if headerData then
      headerData.name = BuildStubHeaderText(fresh.hint)
      headerData.tooltip = fresh.hint
    end
    local buttonData = GetInitializerData(stub.button)
    if buttonData then
      buttonData.name = fresh.label
      buttonData.buttonText = fresh.button
      buttonData.tooltip = fresh.hint
    end
    TagOnce(fresh.label)
    TagOnce(fresh.button)
  end

  return stub
end
