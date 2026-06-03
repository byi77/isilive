local _, addonTable = ...
addonTable = addonTable or {}

local RI = addonTable._RosterInternal or {}
addonTable._RosterInternal = RI

local ApplyFontStringSize = RI.ApplyFontStringSize
local FormatMplusTime = RI.FormatMplusTime
local SetFontStringTextColorSafe = RI.SetFontStringTextColorSafe

local CD_TRACKER_ROW_HEIGHT = RI.CD_TRACKER_ROW_HEIGHT or 20
local CD_TRACKER_ROW_BOTTOM_OFFSET = RI.CD_TRACKER_ROW_BOTTOM_OFFSET or 20
local CD_TRACKER_ICON_SIZE = 16
local CD_TRACKER_TEXT_GAP = 6
local CD_TRACKER_FONT_SIZE = 12

-- Shared shape for the +3 / +2 / +1 timer badges (16x12 colored frame with a
-- centred colour-coded label). Used three times below; the previous revision
-- inlined three near-identical do/end blocks.
local function CreateMplusGradeBadge(parent, leftOffset, bgR, bgG, bgB, labelText)
  local badge = CreateFrame("Frame", nil, parent)
  badge:SetSize(16, 12)
  badge:SetPoint("LEFT", parent, "LEFT", leftOffset, 0)
  local bg = badge:CreateTexture(nil, "BACKGROUND")
  if type(bg.SetAllPoints) == "function" then
    bg:SetAllPoints(badge)
  end
  if type(bg.SetTexture) == "function" then
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  end
  if type(bg.SetVertexColor) == "function" then
    bg:SetVertexColor(bgR, bgG, bgB)
  end
  local label = badge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  if type(label.SetAllPoints) == "function" then
    label:SetAllPoints(badge)
  end
  if type(label.SetJustifyH) == "function" then
    label:SetJustifyH("CENTER")
  end
  if type(label.SetJustifyV) == "function" then
    label:SetJustifyV("MIDDLE")
  end
  if type(label.SetText) == "function" then
    label:SetText(labelText)
  end
  ApplyFontStringSize(label, CD_TRACKER_FONT_SIZE)
  return badge
end

local function CreateCdTrackerRow(mainFrame)
  local UICommon = addonTable.UICommon or {}
  local row = CreateFrame("Frame", nil, mainFrame)
  if type(row.CreateTexture) ~= "function" or type(row.CreateFontString) ~= "function" then
    return nil
  end
  if type(row.SetHeight) == "function" then
    row:SetHeight(CD_TRACKER_ROW_HEIGHT)
  end
  if type(row.SetPoint) == "function" then
    row:SetPoint("BOTTOMLEFT", 10, CD_TRACKER_ROW_BOTTOM_OFFSET)
    row:SetPoint("BOTTOMRIGHT", -10, CD_TRACKER_ROW_BOTTOM_OFFSET)
  end

  -- BR/BL box: left-aligned, framed together
  local cdBox = CreateFrame("Frame", nil, row, "BackdropTemplate")
  if type(cdBox.SetHeight) == "function" then
    cdBox:SetHeight(CD_TRACKER_ROW_HEIGHT)
  end
  if type(cdBox.SetPoint) == "function" then
    cdBox:SetPoint("LEFT", row, "LEFT", 0, 0)
  end
  if type(cdBox.SetWidth) == "function" then
    cdBox:SetWidth(170)
  end
  if type(UICommon.ApplyBackdrop) == "function" then
    UICommon.ApplyBackdrop(cdBox, "CD_BOX")
  end
  row.cdBox = cdBox

  -- BR icon + text inside cdBox
  row.bresIcon = cdBox:CreateTexture(nil, "OVERLAY")
  if type(row.bresIcon.SetSize) == "function" then
    row.bresIcon:SetSize(CD_TRACKER_ICON_SIZE, CD_TRACKER_ICON_SIZE)
  end
  if type(row.bresIcon.SetPoint) == "function" then
    row.bresIcon:SetPoint("LEFT", cdBox, "LEFT", 6, 0)
  end
  if type(row.bresIcon.SetTexCoord) == "function" then
    row.bresIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  row.bresIcon:Hide()

  row.bresText = cdBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.bresText:SetPoint("LEFT", row.bresIcon, "RIGHT", CD_TRACKER_TEXT_GAP, 0)
  row.bresText:SetJustifyH("LEFT")
  row.bresText:SetText("")
  ApplyFontStringSize(row.bresText, CD_TRACKER_FONT_SIZE)

  row.lustIcon = cdBox:CreateTexture(nil, "OVERLAY")
  if type(row.lustIcon.SetSize) == "function" then
    row.lustIcon:SetSize(CD_TRACKER_ICON_SIZE, CD_TRACKER_ICON_SIZE)
  end
  if type(row.lustIcon.SetPoint) == "function" then
    row.lustIcon:SetPoint("LEFT", row.bresText, "RIGHT", 12, 0)
  end
  if type(row.lustIcon.SetTexCoord) == "function" then
    row.lustIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  row.lustIcon:Hide()

  row.lustText = cdBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.lustText:SetPoint("LEFT", row.lustIcon, "RIGHT", CD_TRACKER_TEXT_GAP, 0)
  row.lustText:SetJustifyH("LEFT")
  row.lustText:SetText("")
  ApplyFontStringSize(row.lustText, CD_TRACKER_FONT_SIZE)

  -- Cache spell icons once at creation time to avoid repeated API calls on every refresh.
  local C_Spell_ref = rawget(_G, "C_Spell")
  if type(C_Spell_ref) == "table" and type(C_Spell_ref.GetSpellTexture) == "function" then
    local ok, tex = pcall(C_Spell_ref.GetSpellTexture, 20484)
    if ok and tex then
      row.bresIcon:SetTexture(tex)
      row._bresIconReady = true
    end
    ok, tex = pcall(C_Spell_ref.GetSpellTexture, 2825)
    if ok and tex then
      row.lustIcon:SetTexture(tex)
      row._lustDefaultIcon = tex
      row._lustIconReady = true
    end
  end

  -- M+ timer box: right of cdBox, framed with blue accent
  local mplusBox = CreateFrame("Frame", nil, row, "BackdropTemplate")
  if type(mplusBox.SetHeight) == "function" then
    mplusBox:SetHeight(CD_TRACKER_ROW_HEIGHT)
  end
  if type(mplusBox.SetPoint) == "function" then
    mplusBox:SetPoint("LEFT", cdBox, "RIGHT", 6, 0)
    mplusBox:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  end
  if type(UICommon.ApplyBackdrop) == "function" then
    UICommon.ApplyBackdrop(mplusBox, "MPLUS_BOX")
  end
  mplusBox:Hide()
  row.mplusBox = mplusBox

  -- M+ label + stopwatch icon badge
  do
    local badge = CreateFrame("Frame", nil, mplusBox)
    badge:SetSize(16, 12)
    badge:SetPoint("LEFT", mplusBox, "LEFT", 6, 0)
    local label = badge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if type(label.SetPoint) == "function" then
      label:SetPoint("LEFT", badge, "LEFT", 0, 0)
    end
    if type(label.SetJustifyH) == "function" then
      label:SetJustifyH("LEFT")
    end
    if type(label.SetJustifyV) == "function" then
      label:SetJustifyV("MIDDLE")
    end
    if type(label.SetText) == "function" then
      label:SetText("|cffffd700M+|r")
    end
    ApplyFontStringSize(label, CD_TRACKER_FONT_SIZE)
    row.mplusLabel = badge
  end

  row.mp3Icon = CreateMplusGradeBadge(mplusBox, 32, 0.15, 0.45, 0.15, "|cff44ff44+3|r")
  row.mp3Text = mplusBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.mp3Text:SetPoint("LEFT", mplusBox, "LEFT", 50, 0)
  row.mp3Text:SetWidth(36)
  row.mp3Text:SetJustifyH("LEFT")
  row.mp3Text:SetText("--:--")
  ApplyFontStringSize(row.mp3Text, CD_TRACKER_FONT_SIZE)

  row.mp2Icon = CreateMplusGradeBadge(mplusBox, 90, 0.45, 0.38, 0.05, "|cffffd91a+2|r")
  row.mp2Text = mplusBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.mp2Text:SetPoint("LEFT", mplusBox, "LEFT", 108, 0)
  row.mp2Text:SetWidth(36)
  row.mp2Text:SetJustifyH("LEFT")
  row.mp2Text:SetText("--:--")
  ApplyFontStringSize(row.mp2Text, CD_TRACKER_FONT_SIZE)

  row.mp1Icon = CreateMplusGradeBadge(mplusBox, 148, 0.3, 0.3, 0.3, "|cffdddddd+1|r")
  row.mp1Text = mplusBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.mp1Text:SetPoint("LEFT", mplusBox, "LEFT", 166, 0)
  row.mp1Text:SetWidth(36)
  row.mp1Text:SetJustifyH("LEFT")
  row.mp1Text:SetText("--:--")
  ApplyFontStringSize(row.mp1Text, CD_TRACKER_FONT_SIZE)

  -- death icon + label
  row.mpDeathIcon = mplusBox:CreateTexture(nil, "OVERLAY")
  if type(row.mpDeathIcon.SetSize) == "function" then
    row.mpDeathIcon:SetSize(12, 12)
  end
  if type(row.mpDeathIcon.SetPoint) == "function" then
    row.mpDeathIcon:SetPoint("LEFT", mplusBox, "LEFT", 206, 0)
  end
  if type(row.mpDeathIcon.SetTexture) == "function" then
    row.mpDeathIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
  end

  row.mpDeathText = mplusBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.mpDeathText:SetPoint("LEFT", row.mpDeathIcon, "RIGHT", 4, 0)
  row.mpDeathText:SetJustifyH("LEFT")
  row.mpDeathText:SetText("")
  ApplyFontStringSize(row.mpDeathText, CD_TRACKER_FONT_SIZE)

  return row
end

local function UpdateCdTrackerRow(row, cdController)
  if not row then
    return
  end

  -- BRes: always show icon + text; if spell unavailable show "--"
  do
    if row._bresIconReady then
      row.bresIcon:Show()
    end
    local bres = cdController and cdController.GetBResInfo()
    if bres then
      local charges = bres.charges or 0
      local maxCharges = bres.maxCharges or 0
      local remain = bres.cooldownRemain or 0
      if remain > 0 then
        local mins = math.floor(remain / 60)
        local secs = math.floor(remain % 60)
        row.bresText:SetText(string.format("%d/%d  %d:%02d", charges, maxCharges, mins, secs))
      else
        row.bresText:SetText(string.format("%d/%d", charges, maxCharges))
      end
    else
      row.bresText:SetText("BR: --")
    end
  end

  -- BL: always show icon + text; show countdown when active, "--" when inactive.
  -- Use the aura's own icon when lust is active (covers Heroism, Time Warp variants),
  -- fall back to the cached Bloodlust icon when inactive.
  do
    local lust = cdController and cdController.GetLustInfo()
    local lustRemain = lust and tonumber(lust.remain) or nil
    if lustRemain ~= nil then
      if lust.icon then
        row.lustIcon:SetTexture(lust.icon)
      elseif row._lustDefaultIcon then
        row.lustIcon:SetTexture(row._lustDefaultIcon)
      end
      if row._lustIconReady or lust.icon then
        row.lustIcon:Show()
      end
      local remain = math.max(0, lustRemain)
      local mins = math.floor(remain / 60)
      local secs = math.floor(remain % 60)
      row.lustText:SetText(string.format("%02d:%02d", mins, secs))
    else
      if row._lustDefaultIcon then
        row.lustIcon:SetTexture(row._lustDefaultIcon)
      end
      if row._lustIconReady then
        row.lustIcon:Show()
      end
      row.lustText:SetText("BL: --")
    end
  end

  -- M+ timer box
  if row.mplusBox then
    local MplusTimer = addonTable.MplusTimer
    local data = type(MplusTimer) == "table"
        and type(MplusTimer.GetTimerData) == "function"
        and MplusTimer.GetTimerData()
      or nil

    row.mplusBox:Show()

    if data and (data.running or data.completed) then
      -- +3
      if data.timeRemaining3 >= 0 then
        SetFontStringTextColorSafe(row.mp3Text, 0.4, 1.0, 0.4)
        row.mp3Text:SetText(FormatMplusTime(data.timeRemaining3))
      else
        SetFontStringTextColorSafe(row.mp3Text, 0.5, 0.5, 0.5)
        row.mp3Text:SetText("--:--")
      end

      -- +2
      if data.timeRemaining2 >= 0 then
        SetFontStringTextColorSafe(row.mp2Text, 1.0, 0.85, 0.1)
        row.mp2Text:SetText(FormatMplusTime(data.timeRemaining2))
      else
        SetFontStringTextColorSafe(row.mp2Text, 0.5, 0.5, 0.5)
        row.mp2Text:SetText("--:--")
      end

      -- +1: white when time remains, red when exceeded
      if data.timeRemaining1 >= 0 then
        SetFontStringTextColorSafe(row.mp1Text, 1.0, 1.0, 1.0)
        row.mp1Text:SetText(FormatMplusTime(data.timeRemaining1))
      else
        SetFontStringTextColorSafe(row.mp1Text, 1.0, 0.2, 0.2)
        row.mp1Text:SetText("-" .. FormatMplusTime(data.timeRemaining1))
      end

      -- Tode
      if data.deaths and data.deaths > 0 then
        local deathStr
        if data.deathTimeLost and data.deathTimeLost > 0 then
          deathStr = string.format("|cffff6060%d (+%ds)|r", data.deaths, data.deathTimeLost)
        else
          deathStr = string.format("|cffff6060%d|r", data.deaths)
        end
        row.mpDeathText:SetText(deathStr)
      else
        row.mpDeathText:SetText("")
      end
    else
      -- no active key: show --:-- for all
      SetFontStringTextColorSafe(row.mp3Text, 0.4, 0.4, 0.5)
      row.mp3Text:SetText("--:--")
      SetFontStringTextColorSafe(row.mp2Text, 0.4, 0.4, 0.5)
      row.mp2Text:SetText("--:--")
      SetFontStringTextColorSafe(row.mp1Text, 0.4, 0.4, 0.5)
      row.mp1Text:SetText("--:--")
      SetFontStringTextColorSafe(row.mpDeathText, 0.4, 0.4, 0.5)
      row.mpDeathText:SetText("--")
    end
  end
end

RI.CreateCdTrackerRow = CreateCdTrackerRow
RI.UpdateCdTrackerRow = UpdateCdTrackerRow
