local _, addonTable = ...
addonTable = addonTable or {}

-- Copy window for the bug report export (rule 254). Shows the page URL and
-- the export string; the string box is focused and fully selected, so the
-- player only presses Ctrl+C, opens the page and pastes. WoW offers no
-- clipboard or HTTP API, so this is the shortest possible path.
local BugReportWindow = {}
addonTable.BugReportWindow = BugReportWindow

local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

local WINDOW_WIDTH = 520
local WINDOW_HEIGHT = 200
local PADDING = 16
local BOX_WIDTH = WINDOW_WIDTH - (PADDING * 2) - 8

local frame = nil

local function Colors()
  return addonTable.UICommon and addonTable.UICommon.Colors or {}
end

-- A single-line box whose text the player cannot change: every edit restores
-- the original text and selects it again.
local function CreateReadOnlyBox(parent)
  local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  box:SetSize(BOX_WIDTH, 20)
  box:SetAutoFocus(false)
  if type(box.SetMaxLetters) == "function" then
    box:SetMaxLetters(0)
  end
  box:SetFontObject("ChatFontNormal")
  box:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    parent:Hide()
  end)
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput and self._readOnlyText and self:GetText() ~= self._readOnlyText then
      self:SetText(self._readOnlyText)
      self:HighlightText()
    end
  end)
  box:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
  end)
  box:SetScript("OnMouseUp", function(self)
    self:HighlightText()
  end)
  return box
end

local function SetReadOnlyText(box, text)
  box._readOnlyText = text
  box:SetText(text)
  box:SetCursorPosition(0)
end

local function CreateWindow()
  local uiCommon = addonTable.UICommon
  local window = CreateFrame("Frame", "isiLiveBugReportFrame", rawget(_G, "UIParent"), "BackdropTemplate")
  window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
  window:SetPoint("CENTER")
  window:SetFrameStrata("DIALOG")
  window:SetClampedToScreen(true)
  window:EnableMouse(true)
  window:SetMovable(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  if uiCommon and type(uiCommon.ApplyBackdrop) == "function" then
    uiCommon.ApplyBackdrop(window, "MAIN_FRAME")
  end
  local specialFrames = rawget(_G, "UISpecialFrames")
  if type(specialFrames) == "table" then
    specialFrames[#specialFrames + 1] = "isiLiveBugReportFrame"
  end

  local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", window, "TOP", 0, -12)
  window.title = title

  if uiCommon and type(uiCommon.CreateCloseButton) == "function" then
    window.closeButton = uiCommon.CreateCloseButton(window, {
      point = { "TOPRIGHT", window, "TOPRIGHT", -6, -6 },
    })
    window.closeButton:SetScript("OnClick", function()
      window:Hide()
    end)
  end

  local urlLabel = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  urlLabel:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING, -42)
  urlLabel:SetJustifyH("LEFT")
  window.urlLabel = urlLabel

  local urlBox = CreateReadOnlyBox(window)
  urlBox:SetPoint("TOPLEFT", urlLabel, "BOTTOMLEFT", 6, -4)
  window.urlBox = urlBox

  local codeLabel = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  codeLabel:SetPoint("TOPLEFT", urlBox, "BOTTOMLEFT", -6, -10)
  codeLabel:SetJustifyH("LEFT")
  window.codeLabel = codeLabel

  local codeBox = CreateReadOnlyBox(window)
  codeBox:SetPoint("TOPLEFT", codeLabel, "BOTTOMLEFT", 6, -4)
  window.codeBox = codeBox

  local statsText = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  statsText:SetPoint("TOPLEFT", codeBox, "BOTTOMLEFT", -6, -10)
  statsText:SetWidth(WINDOW_WIDTH - (PADDING * 2))
  statsText:SetJustifyH("LEFT")
  if type(statsText.SetWordWrap) == "function" then
    statsText:SetWordWrap(true)
  end
  statsText:SetTextColor(unpack(Colors().TEXT_DIM or { 0.5, 0.5, 0.6 }))
  window.statsText = statsText

  window:Hide()
  return window
end

-- exportString: the encoded report. stats: from BugReport.Build. L: texts.
function BugReportWindow.Show(exportString, stats, L)
  L = type(L) == "table" and L or {}
  stats = type(stats) == "table" and stats or {}
  if not frame then
    frame = CreateWindow()
  end
  local bugReport = addonTable.BugReport or {}

  frame.title:SetText(L.BUG_REPORT_TITLE or "isiLive bug report")
  frame.urlLabel:SetText(L.BUG_REPORT_STEP_URL or "1. Open this page in your browser:")
  frame.codeLabel:SetText(L.BUG_REPORT_STEP_COPY or "2. Copy this text (Ctrl+C) and paste it on the page:")
  SetReadOnlyText(frame.urlBox, tostring(bugReport.REPORT_URL or ""))
  SetReadOnlyText(frame.codeBox, tostring(exportString or ""))

  local statsLine = string.format(
    L.BUG_REPORT_STATS or "%d errors, %d of %d log lines. Character names are replaced (SELF, P1, P2, ...).",
    tonumber(stats.errors) or 0,
    tonumber(stats.runtimeLines) or 0,
    tonumber(stats.runtimeLinesTotal) or 0
  )
  if stats.runtimeLogEnabled == false then
    statsLine = statsLine .. "\n" .. (L.BUG_REPORT_LOG_OFF or "Runtime log is off.")
  end
  frame.statsText:SetText(statsLine)

  frame:Show()
  frame.codeBox:SetFocus()
  frame.codeBox:HighlightText()
  return frame
end

function BugReportWindow.Hide()
  if frame then
    frame:Hide()
  end
end

-- Test surface: the window frame once created (nil before the first Show).
function BugReportWindow.GetFrame()
  return frame
end

return BugReportWindow
