local _, addonTable = ...
addonTable = addonTable or {}
local SettingsLayout = {}
addonTable.SettingsLayout = SettingsLayout

local Colors = addonTable.UICommon and addonTable.UICommon.Colors or {}
local PADDING_X = 16
local HEADER_HEIGHT = 24
local HEADER_LINE_GAP = 6
local SETTINGS_CONTENT_WIDTH = 700

-- Keep the original row boundaries so refreshes preserve explicit section gaps
-- while measuring the current text on the existing widgets.
function SettingsLayout.RegisterLayout(parent, yOffset, layout)
  parent._isiLiveSettingsRows = parent._isiLiveSettingsRows or {}
  local nextY = layout(yOffset)
  table.insert(parent._isiLiveSettingsRows, { startY = yOffset, endY = nextY, layout = layout })
  return nextY
end

function SettingsLayout.Relayout(parent, offsets, originalOffsets, finalY)
  local shift = 0
  for _, row in ipairs(parent._isiLiveSettingsRows or {}) do
    for key, offset in pairs(originalOffsets) do
      if -offset == row.startY then
        offsets[key] = offset - shift
      end
    end
    local nextY = row.layout(row.startY + shift)
    shift = nextY - row.endY
  end
  return finalY + shift
end

local function Position(region, parent, x, y)
  if type(region.ClearAllPoints) == "function" then
    region:ClearAllPoints()
  end
  region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
end

local function ReadAnchorX(region, defaultX, index)
  if type(region.GetPoint) == "function" then
    local _, _, _, x = region:GetPoint(index or 1)
    return tonumber(x) or defaultX
  end
  return defaultX
end

function SettingsLayout.CreateSectionHeader(parent, yOffset, text)
  local surface = parent:CreateTexture(nil, "BACKGROUND")
  surface:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X - 6, yOffset + 4)
  surface:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", -(PADDING_X - 6), yOffset - HEADER_HEIGHT + 4)
  local sectionSurface = Colors.SURFACE_TITLE_BAR or { 0.025, 0.055, 0.085, 0.82 }
  surface:SetColorTexture(sectionSurface[1], sectionSurface[2], sectionSurface[3], 0.52)

  local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local sectionText = Colors.TEXT_SECTION or { 0.64, 0.80, 0.96 }
  header:SetTextColor(sectionText[1], sectionText[2], sectionText[3], 1)
  header:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset)
  header:SetJustifyH("LEFT")
  header:SetText(text or "")
  local line = parent:CreateTexture(nil, "ARTWORK") ---@type IsiLiveSeparatorTexture
  line:SetHeight(2)
  line:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset - HEADER_HEIGHT)
  line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PADDING_X, yOffset - HEADER_HEIGHT)
  local border = Colors.BORDER_TITLE_BAR or { 0.26, 0.62, 0.92, 0.38 }
  line:SetColorTexture(border[1], border[2], border[3], 0.55)
  line._isiLiveSettingsSeparator = "section"
  header._isiLiveSectionSurface = surface
  header._isiLiveSurfaceRole = "settings_section"
  local nextY = SettingsLayout.RegisterLayout(parent, yOffset, function(y)
    Position(header, parent, PADDING_X, y)
    Position(surface, parent, PADDING_X - 6, y + 4)
    surface:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", -(PADDING_X - 6), y - HEADER_HEIGHT + 4)
    Position(line, parent, PADDING_X, y - HEADER_HEIGHT)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PADDING_X, y - HEADER_HEIGHT)
    return y - HEADER_HEIGHT - HEADER_LINE_GAP
  end)
  return header, nextY
end

function SettingsLayout.CreateChildSeparator(parent, yOffset)
  local line = parent:CreateTexture(nil, "ARTWORK") ---@type IsiLiveSeparatorTexture
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset - 5)
  line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PADDING_X, yOffset - 5)
  local bd = Colors.BORDER_ACTION_SECONDARY or { 0.32, 0.4, 0.52, 0.62 }
  line:SetColorTexture(bd[1], bd[2], bd[3], 0.28)
  line._isiLiveSettingsSeparator = "child"
  local nextY = SettingsLayout.RegisterLayout(parent, yOffset, function(y)
    local left = ReadAnchorX(line, PADDING_X)
    local right = ReadAnchorX(line, -PADDING_X, 2)
    Position(line, parent, left, y - 5)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", right, y - 5)
    return y - 14
  end)
  return line, nextY
end

function SettingsLayout.MeasureWrappedTextHeight(textRegion, fallbackHeight, padding)
  local height = tonumber(fallbackHeight) or 0
  local measured = nil
  if type(textRegion) == "table" and type(textRegion.GetStringHeight) == "function" then
    measured = tonumber(textRegion:GetStringHeight())
  end
  if measured and measured > 0 then
    height = math.max(height, math.ceil(measured) + (tonumber(padding) or 0))
  end
  return height
end

function SettingsLayout.CreateSettingsIntro(parent, yOffset, text)
  local intro = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local td = Colors.TEXT_DIM or { 0.5, 0.5, 0.6 }
  intro:SetTextColor(td[1], td[2], td[3], 1)
  intro:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset)
  intro:SetWidth(math.max(240, SETTINGS_CONTENT_WIDTH - (PADDING_X * 2)))
  intro:SetJustifyH("LEFT")
  if type(intro.SetWordWrap) == "function" then
    intro:SetWordWrap(true)
  end
  intro:SetText(text or "")
  local nextY = SettingsLayout.RegisterLayout(parent, yOffset, function(y)
    Position(intro, parent, PADDING_X, y)
    return y - SettingsLayout.MeasureWrappedTextHeight(intro, 28, 8)
  end)
  return intro, nextY
end

function SettingsLayout.CreateSectionNote(parent, yOffset, text)
  local note = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  local td = Colors.TEXT_DIM or { 0.5, 0.5, 0.6 }
  note:SetTextColor(td[1], td[2], td[3], 1)
  note:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING_X, yOffset)
  note:SetWidth(math.max(120, SETTINGS_CONTENT_WIDTH - (PADDING_X * 2)))
  note:SetJustifyH("LEFT")
  if type(note.SetWordWrap) == "function" then
    note:SetWordWrap(true)
  end
  note:SetText(text or "")
  local nextY = SettingsLayout.RegisterLayout(parent, yOffset, function(y)
    Position(note, parent, PADDING_X, y)
    return y - SettingsLayout.MeasureWrappedTextHeight(note, 16, 6)
  end)
  return note, nextY
end

SettingsLayout.Position = Position
SettingsLayout.ReadAnchorX = ReadAnchorX
