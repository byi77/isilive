local _, addonTable = ...

addonTable = addonTable or {}

-- Centre-screen panel of /isilive ttktest (see game/isiLive_ttk.lua): the
-- target's TTK plus the plain state behind it (clock, measured time, target
-- nameplate, reason, evaluation), so a training-dummy test needs no logs.
-- Shown only while the test mode is on.
local TTKTestPanel = {}
addonTable.TTKTestPanel = TTKTestPanel

local PANEL_Y = 220
local LINE_GAP = 22
local LINE_COUNT = 4

local frame = nil
local lines = {}

-- Debug panel of a test command: fixed English/German technical labels.
local CLOCK_LABEL = { boss = "Boss", nameplate = "Nameplate", combat = "Kampf" } -- i18n-ok: test panel
local REASON_LABEL = { -- i18n-ok: test panel
  preview = "Beispielwert (kein Kampf)",
  shown = "angezeigt",
  pending = "wartet (unter 3 s Trefferzeit)",
  notarget = "kein lebendes Ziel",
  nocombat = "kein Kampf",
  nokey = "kein Key",
  off = "TTK ausgeschaltet",
  noclock = "keine Uhr",
}

local function Seconds(value)
  if type(value) ~= "number" then
    return "-"
  end
  return string.format("%.1fs", value)
end

local function OnStatus(status)
  if not frame then
    return
  end
  if status == nil then
    frame:Hide()
    return
  end
  frame:Show()
  lines[3]:SetText(string.format( -- i18n-ok: test panel
    "Uhr: %s | Trefferzeit %s | seit Treffer %s",
    CLOCK_LABEL[status.clock] or "-",
    Seconds(status.elapsedAtHit),
    Seconds(status.sinceHit)
  ))
  lines[4]:SetText(string.format( -- i18n-ok: test panel
    "Ziel: %s | %s | Auswertung: %s",
    tostring(status.token or "-"),
    REASON_LABEL[status.reason] or tostring(status.reason),
    status.evaluated and "ok" or "nein"
  ))
end

--- Creates the panel once and wires it to TTK. Called from the factory.
function TTKTestPanel.Install()
  local ttk = addonTable.TTK
  if frame or type(ttk) ~= "table" or type(ttk.RegisterDisplay) ~= "function" then
    return frame ~= nil
  end
  local createFrame = rawget(_G, "CreateFrame")
  local uiParent = rawget(_G, "UIParent")
  if type(createFrame) ~= "function" then
    return false
  end
  local ok, created = pcall(createFrame, "Frame", nil, uiParent)
  if not ok or type(created) ~= "table" then
    return false
  end
  frame = created
  frame:SetSize(460, LINE_GAP * LINE_COUNT)
  frame:SetPoint("CENTER", uiParent, "CENTER", 0, PANEL_Y)
  for i = 1, LINE_COUNT do
    local text = frame:CreateFontString(nil, "OVERLAY", i <= 2 and "GameFontNormalLarge" or "GameFontHighlight")
    text:SetPoint("TOP", frame, "TOP", 0, -(i - 1) * LINE_GAP)
    text:SetText("")
    lines[i] = text
  end
  lines[1]:SetText("isiLive TTK-Test") -- i18n-ok: test panel title
  frame:Hide()
  ttk.RegisterDisplay(lines[2], {
    format = "TTK Ziel: %.0f s", -- i18n-ok: test panel
    placeholder = "TTK Ziel: …", -- i18n-ok: test panel
    onShow = function()
      return type(ttk.IsTestMode) == "function" and ttk.IsTestMode() == true
    end,
  })
  if type(ttk.SetStatusListener) == "function" then
    ttk.SetStatusListener(OnStatus)
  end
  return true
end
