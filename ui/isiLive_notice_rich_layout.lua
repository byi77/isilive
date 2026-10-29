local _, addonTable = ...

addonTable = addonTable or {}

-- Lua 5.1 (WoW client) exposes global `unpack`; Lua 5.4 (local tooling) only
-- has `table.unpack`. Bridge locally so this file works under both without
-- depending on the entrypoint script to have set up a global compat shim.
local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

-- Rich info-card layout for the center notice (post-accept invite card,
-- dungeon-entered card). Owns the pre-allocated title / separator / eyebrow /
-- field-row / teleport-header primitives and their anchoring. The secure
-- teleport button itself stays in the Notice facade; the layout only receives
-- its combat-deferred size/anchor setters through Create(deps).
local NoticeRichLayout = {}
addonTable.NoticeRichLayout = NoticeRichLayout
local NoticeCommon = assert(addonTable.NoticeCommon, "isiLive: NoticeCommon missing")
local Colors = addonTable.UICommon and addonTable.UICommon.Colors or {}
local IncreaseFontSize = NoticeCommon.IncreaseFontSize
local SetReadableText = NoticeCommon.SetReadableText
-- Test harnesses may load this file without Validators; treat nothing as secret there.
local IsSecretValue = addonTable.Validators and addonTable.Validators.IsSecretValue
  or function(_value)
    return false
  end

local NOTICE_GOLD_ACCENT_R, NOTICE_GOLD_ACCENT_G, NOTICE_GOLD_ACCENT_B = 1, 0.82, 0.25
local SUBLINE_GAP = 4

local FIELD_LABEL_WIDTH = 144
-- Largest cards: accepted invite (dungeon, title, leader, source, navigation)
-- and accepted raid invite (up to six rows). Surplus fields are dropped.
-- Invite card: five rows, the Loadout label row and its two sub-rows.
local MAX_FIELD_ROWS = 8
-- Field labels and values follow the shared supporting and heading text roles.
local FIELD_LABEL_COLOR = Colors.TEXT_SUPPORTING or { 0.58, 0.65, 0.74 }
local FIELD_VALUE_COLOR = Colors.TEXT_HEADING or { 0.93, 0.96, 1 }
local FIELD_LABEL_R, FIELD_LABEL_G, FIELD_LABEL_B = FIELD_LABEL_COLOR[1], FIELD_LABEL_COLOR[2], FIELD_LABEL_COLOR[3]
local FIELD_VALUE_R, FIELD_VALUE_G, FIELD_VALUE_B = FIELD_VALUE_COLOR[1], FIELD_VALUE_COLOR[2], FIELD_VALUE_COLOR[3]
local FIELD_WARNING_R, FIELD_WARNING_G, FIELD_WARNING_B = 1, 0.16, 0.12
local RICH_TELEPORT_BUTTON_WIDTH = 170
local RICH_TELEPORT_BUTTON_MIN_HEIGHT = 104
local RICH_TELEPORT_ICON_INSET = 14
local RICH_TELEPORT_BUTTON_RIGHT_INSET = 24
-- Header band: kind chip (icon + eyebrow), brand mark on the right, title
-- below, closed off by a full-width hairline.
local HEADER_CHIP_HEIGHT = 20
local HEADER_CHIP_ICON_SIZE = 14
local HEADER_CHIP_PAD_X = 6
local HEADER_CHIP_ICON_GAP = 5
local HEADER_CHIP_BG_ALPHA = 0.16
local HEADER_TITLE_GAP = 6
local HEADER_BOTTOM_GAP = 10
-- Room for the shared 20 px close button in the top-right corner.
local HEADER_CLOSE_RESERVE = 28
-- Field rows sit on a hairline grid; the padding is above and below the text.
local FIELD_ROW_PAD_Y = 5
-- A grouped field is a sub-row of the field above it: its label is indented
-- in the label column and no hairline separates it from that field.
local FIELD_GROUPED_LABEL_INDENT = 10
-- UICommon.ApplyNoticeKind's own icon anchor, restored outside rich mode.
local KIND_ICON_DEFAULT_SIZE = 16
local KIND_ICON_DEFAULT_X, KIND_ICON_DEFAULT_Y = 9, -7
local BRAND_TEXT = "isiLive"

-- Single source for the constants the Notice facade still needs.
NoticeRichLayout.TITLE_COLOR = { FIELD_VALUE_R, FIELD_VALUE_G, FIELD_VALUE_B }
NoticeRichLayout.GOLD_ACCENT = { NOTICE_GOLD_ACCENT_R, NOTICE_GOLD_ACCENT_G, NOTICE_GOLD_ACCENT_B }
NoticeRichLayout.FIELD_WARNING_COLOR = { FIELD_WARNING_R, FIELD_WARNING_G, FIELD_WARNING_B }
NoticeRichLayout.SUBLINE_GAP = SUBLINE_GAP
NoticeRichLayout.MAX_FIELD_ROWS = MAX_FIELD_ROWS

-- Rich-layout primitives for the post-accept invite info card. Pre-allocated
-- at frame creation; hidden by default. Show paths set their text and
-- visibility per-Show call. Anchored dynamically inside ApplyLayout.

local function CreateCenterNoticeTitle(frame, config)
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  -- Title sits above the separator and announces the notice category. Sized
  -- a touch larger than the body fontDelta so it reads as the dominant header.
  IncreaseFontSize(title, tonumber(config.fontDelta) or 0)
  title:SetJustifyH("CENTER")
  title:SetJustifyV("MIDDLE")
  title:SetWordWrap(false)
  if title.SetNonSpaceWrap then
    title:SetNonSpaceWrap(false)
  end
  title:SetTextColor(FIELD_VALUE_R, FIELD_VALUE_G, FIELD_VALUE_B)
  title:Hide()
  return title
end

local function CreateCenterNoticeTitleSeparator(frame)
  if type(frame.CreateTexture) ~= "function" then
    return nil
  end
  local sep = frame:CreateTexture(nil, "ARTWORK")
  sep:SetHeight(1)
  sep:SetColorTexture(unpack(Colors.BORDER_NOTICE or { 0.24, 0.55, 0.82, 0.58 }))
  sep:Hide()
  return sep
end

local function CreateCenterNoticeEyebrow(frame, config)
  local eyebrow = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  IncreaseFontSize(eyebrow, math.max(0, math.floor((tonumber(config.fontDelta) or 0) / 3)))
  eyebrow:SetJustifyH("LEFT")
  eyebrow:SetJustifyV("TOP")
  eyebrow:SetWordWrap(false)
  if eyebrow.SetNonSpaceWrap then
    eyebrow:SetNonSpaceWrap(false)
  end
  eyebrow:SetTextColor(unpack(Colors.CYAN_EYEBROW or { 0.46, 0.94, 1 }))
  eyebrow:Hide()
  return eyebrow
end

local function CreateCenterNoticeFieldRow(frame, config)
  local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  IncreaseFontSize(label, math.max(0, math.floor((tonumber(config.fontDelta) or 0) / 2)))
  label:SetJustifyH("LEFT")
  label:SetJustifyV("TOP")
  label:SetWordWrap(false)
  if label.SetNonSpaceWrap then
    label:SetNonSpaceWrap(false)
  end
  label:SetTextColor(FIELD_LABEL_R, FIELD_LABEL_G, FIELD_LABEL_B)
  label:SetWidth(FIELD_LABEL_WIDTH)
  label:Hide()

  local value = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  IncreaseFontSize(value, math.max(0, math.floor((tonumber(config.fontDelta) or 0) / 2)))
  value:SetJustifyH("LEFT")
  value:SetJustifyV("TOP")
  value:SetWordWrap(true)
  if value.SetNonSpaceWrap then
    value:SetNonSpaceWrap(false)
  end
  value:SetTextColor(FIELD_VALUE_R, FIELD_VALUE_G, FIELD_VALUE_B)
  value:Hide()

  local divider, warningBg, warningBar
  if type(frame.CreateTexture) == "function" then
    divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetColorTexture(unpack(Colors.NOTICE_ROW_DIVIDER or { 0.58, 0.65, 0.74, 0.14 }))
    divider:Hide()
    warningBg = frame:CreateTexture(nil, "BORDER")
    warningBg:SetColorTexture(unpack(Colors.NOTICE_WARNING_ROW_BG or { 1, 0.16, 0.12, 0.13 }))
    warningBg:Hide()
    warningBar = frame:CreateTexture(nil, "ARTWORK")
    warningBar:SetWidth(2)
    warningBar:SetColorTexture(FIELD_WARNING_R, FIELD_WARNING_G, FIELD_WARNING_B, 1)
    warningBar:Hide()
  end

  return { label = label, value = value, divider = divider, warningBg = warningBg, warningBar = warningBar }
end

local function CreateCenterNoticeHeaderBand(frame)
  if type(frame.CreateTexture) ~= "function" then
    return nil
  end
  local band = frame:CreateTexture(nil, "BACKGROUND")
  band:SetColorTexture(unpack(Colors.SURFACE_TITLE_BAR or { 0.025, 0.055, 0.085, 0.82 }))
  band:Hide()
  return band
end

local function CreateCenterNoticeKindChip(frame)
  if type(frame.CreateTexture) ~= "function" then
    return nil
  end
  local chip = frame:CreateTexture(nil, "ARTWORK")
  chip:SetHeight(HEADER_CHIP_HEIGHT)
  chip:Hide()
  return chip
end

local function CreateCenterNoticeBrand(frame)
  local brand = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  brand:SetJustifyH("RIGHT")
  brand:SetWordWrap(false)
  brand:SetTextColor(FIELD_LABEL_R, FIELD_LABEL_G, FIELD_LABEL_B)
  brand:SetText(BRAND_TEXT)
  brand:Hide()
  return brand
end

local function CreateCenterNoticeTeleportHeader(frame, config)
  local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  IncreaseFontSize(header, math.max(0, math.floor((tonumber(config.fontDelta) or 0) / 2)))
  header:SetJustifyH("CENTER")
  header:SetJustifyV("MIDDLE")
  header:SetWordWrap(false)
  if header.SetNonSpaceWrap then
    header:SetNonSpaceWrap(false)
  end
  header:SetTextColor(NOTICE_GOLD_ACCENT_R, NOTICE_GOLD_ACCENT_G, NOTICE_GOLD_ACCENT_B)
  header:Hide()
  return header
end

-- Creates every rich primitive in the original order (eyebrow, title,
-- separator, teleport header, field rows) so FontString layering is unchanged;
-- the header band, kind chip and brand mark follow after them.
function NoticeRichLayout.CreateElements(frame, config)
  local eyebrowText = CreateCenterNoticeEyebrow(frame, config)
  local titleText = CreateCenterNoticeTitle(frame, config)
  local titleSeparator = CreateCenterNoticeTitleSeparator(frame)
  local teleportHeader = CreateCenterNoticeTeleportHeader(frame, config)
  local fieldRows = {}
  for i = 1, MAX_FIELD_ROWS do
    fieldRows[i] = CreateCenterNoticeFieldRow(frame, config)
  end
  return {
    eyebrowText = eyebrowText,
    titleText = titleText,
    titleSeparator = titleSeparator,
    teleportHeader = teleportHeader,
    fieldRows = fieldRows,
    headerBand = CreateCenterNoticeHeaderBand(frame),
    kindChip = CreateCenterNoticeKindChip(frame),
    brandText = CreateCenterNoticeBrand(frame),
  }
end

-- The card names isiLive once in its header, so the shared "isiLive - "
-- title prefix of every locale would only repeat it.
local function StripBrandPrefix(title)
  return title:match("^" .. BRAND_TEXT .. "%s+%-%s+(.+)$") or title
end

-- Labels are localized with a trailing colon ("Dungeon:", frFR "Donjon :");
-- the label column already separates them from the value.
local function StripLabelColon(label)
  return (label:gsub("%s*:%s*$", ""))
end

local function GetKindIcon(state)
  return state.frame and state.frame._isiLiveNoticeKindIcon
end

local function RestoreKindIconAnchor(state)
  local icon = GetKindIcon(state)
  if type(icon) ~= "table" or type(icon.ClearAllPoints) ~= "function" then
    return
  end
  icon:ClearAllPoints()
  icon:SetSize(KIND_ICON_DEFAULT_SIZE, KIND_ICON_DEFAULT_SIZE)
  icon:SetPoint("TOPLEFT", state.frame, "TOPLEFT", KIND_ICON_DEFAULT_X, KIND_ICON_DEFAULT_Y)
end

local function GetStringWidthSafe(fontString)
  if type(fontString) ~= "table" or type(fontString.GetStringWidth) ~= "function" then
    return 0
  end
  local ok, width = pcall(fontString.GetStringWidth, fontString)
  if not ok or IsSecretValue(width) then
    return 0
  end
  return tonumber(width) or 0
end

-- Hides every rich-layout primitive. Called on every Show invocation so that
-- subsequent stack-mode / legacy-mode renders do not leak title/separator/
-- field/teleport-header fragments from a previous rich render.
local function HideRichCenterNoticeElements(state)
  state.warningFieldRows = nil
  for _, key in ipairs({ "headerBand", "kindChip", "brandText" }) do
    if state[key] then
      state[key]:Hide()
    end
  end
  RestoreKindIconAnchor(state)
  if state.titleText then
    state.titleText:Hide()
  end
  if state.titleSeparator then
    state.titleSeparator:Hide()
  end
  if state.eyebrowText then
    state.eyebrowText:Hide()
  end
  if state.teleportHeader then
    state.teleportHeader:Hide()
  end
  if type(state.fieldRows) == "table" then
    for _, row in ipairs(state.fieldRows) do
      if row.label then
        row.label:SetTextColor(FIELD_LABEL_R, FIELD_LABEL_G, FIELD_LABEL_B, 1)
        row.label:Hide()
      end
      if row.value then
        row.value:SetTextColor(FIELD_VALUE_R, FIELD_VALUE_G, FIELD_VALUE_B, 1)
        row.value:Hide()
      end
      for _, key in ipairs({ "divider", "warningBg", "warningBar" }) do
        if row[key] then
          row[key]:Hide()
        end
      end
      if row.warningBg then
        row.warningBg:SetAlpha(1)
      end
    end
  end
end

-- Top offset that centers a single-line text vertically in the chip row.
local function ChipTextY(fontString, chipTopY)
  local textHeight = tonumber(fontString:GetStringHeight()) or 0
  return chipTopY + math.max(0, math.floor((HEADER_CHIP_HEIGHT - textHeight) / 2))
end

-- Header: kind chip (state icon + eyebrow) with the brand mark opposite it,
-- the title below, and a full-width hairline that closes the header band.
-- Returns the y offset below the header.
local function ApplyRichHeader(state, payload, innerWidth)
  local frame = state.frame
  local paddingX = state.config.paddingX
  local cursorY = state.config.paddingY
  local kindColor = frame._isiLiveNoticeKindColor or Colors.ACCENT_NOTICE_TOP or { 0.24, 0.72, 1, 0.72 }

  local chipRight = paddingX - HEADER_CHIP_PAD_X
  local icon = GetKindIcon(state)
  if type(icon) == "table" and type(icon.ClearAllPoints) == "function" then
    icon:ClearAllPoints()
    icon:SetSize(HEADER_CHIP_ICON_SIZE, HEADER_CHIP_ICON_SIZE)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", paddingX, -(cursorY + (HEADER_CHIP_HEIGHT - HEADER_CHIP_ICON_SIZE) / 2))
    chipRight = paddingX + HEADER_CHIP_ICON_SIZE
  end

  if type(payload.eyebrow) == "string" and payload.eyebrow ~= "" and state.eyebrowText then
    local eyebrowX = chipRight > paddingX and (chipRight + HEADER_CHIP_ICON_GAP) or paddingX
    state.eyebrowText:SetWidth(math.max(40, innerWidth - (eyebrowX - paddingX) - HEADER_CLOSE_RESERVE - 60))
    SetReadableText(state.eyebrowText, payload.eyebrow)
    state.eyebrowText:ClearAllPoints()
    state.eyebrowText:SetPoint("TOPLEFT", frame, "TOPLEFT", eyebrowX, -ChipTextY(state.eyebrowText, cursorY))
    state.eyebrowText:SetTextColor(kindColor[1], kindColor[2], kindColor[3], 1)
    state.eyebrowText:Show()
    chipRight = eyebrowX + GetStringWidthSafe(state.eyebrowText)
  elseif state.eyebrowText then
    state.eyebrowText:SetText("")
    state.eyebrowText:Hide()
  end

  if state.kindChip and chipRight > paddingX then
    state.kindChip:ClearAllPoints()
    state.kindChip:SetPoint("TOPLEFT", frame, "TOPLEFT", paddingX - HEADER_CHIP_PAD_X, -cursorY)
    state.kindChip:SetWidth(math.ceil(chipRight - paddingX + (HEADER_CHIP_PAD_X * 2)))
    state.kindChip:SetColorTexture(kindColor[1], kindColor[2], kindColor[3], HEADER_CHIP_BG_ALPHA)
    state.kindChip:Show()
  end

  if state.brandText then
    state.brandText:ClearAllPoints()
    state.brandText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -HEADER_CLOSE_RESERVE, -ChipTextY(state.brandText, cursorY))
    state.brandText:Show()
  end
  cursorY = cursorY + HEADER_CHIP_HEIGHT + HEADER_TITLE_GAP

  if type(payload.title) == "string" and payload.title ~= "" and state.titleText then
    state.titleText:ClearAllPoints()
    state.titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", paddingX, -cursorY)
    state.titleText:SetWidth(innerWidth - HEADER_CLOSE_RESERVE)
    state.titleText:SetJustifyH("LEFT")
    SetReadableText(state.titleText, StripBrandPrefix(payload.title))
    state.titleText:Show()
    cursorY = cursorY + (state.titleText:GetStringHeight() or 0)
  end
  cursorY = cursorY + HEADER_BOTTOM_GAP

  if state.headerBand then
    state.headerBand:ClearAllPoints()
    state.headerBand:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    state.headerBand:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -1, -cursorY)
    state.headerBand:Show()
  end
  if state.titleSeparator then
    state.titleSeparator:ClearAllPoints()
    state.titleSeparator:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -cursorY)
    state.titleSeparator:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -cursorY)
    state.titleSeparator:Show()
  end
  return cursorY + 1
end

-- One field row on the hairline grid: label column, wrapping value, and for a
-- warning field a tinted strip with a warning bar on its left edge. Returns
-- the row height.
local function ApplyRichFieldRow(state, row, field, contentWidth, rowTopY, showDivider)
  local frame = state.frame
  local paddingX = state.config.paddingX
  local lineGap = math.max(SUBLINE_GAP, 6)
  local valueWidth = math.max(40, contentWidth - FIELD_LABEL_WIDTH - lineGap)
  local textY = rowTopY + FIELD_ROW_PAD_Y
  local isWarning = field.warning == true
  local labelR, labelG, labelB = FIELD_LABEL_R, FIELD_LABEL_G, FIELD_LABEL_B
  local valueR, valueG, valueB = FIELD_VALUE_R, FIELD_VALUE_G, FIELD_VALUE_B
  if isWarning then
    labelR, labelG, labelB = FIELD_WARNING_R, FIELD_WARNING_G, FIELD_WARNING_B
    valueR, valueG, valueB = FIELD_WARNING_R, FIELD_WARNING_G, FIELD_WARNING_B
  end

  row.label:ClearAllPoints()
  local labelIndent = field.grouped == true and FIELD_GROUPED_LABEL_INDENT or 0
  row.label:SetPoint("TOPLEFT", frame, "TOPLEFT", paddingX + labelIndent, -textY)
  SetReadableText(row.label, StripLabelColon(field.label))
  row.label:SetTextColor(labelR, labelG, labelB, 1)
  row.label:Show()

  row.value:ClearAllPoints()
  row.value:SetPoint("TOPLEFT", frame, "TOPLEFT", paddingX + FIELD_LABEL_WIDTH + lineGap, -textY)
  row.value:SetWidth(valueWidth)
  SetReadableText(row.value, type(field.value) == "string" and field.value or "")
  row.value:SetTextColor(valueR, valueG, valueB, 1)
  row.value:Show()

  local textHeight = math.max(row.label:GetStringHeight() or 0, row.value:GetStringHeight() or 0)
  local rowHeight = textHeight + (FIELD_ROW_PAD_Y * 2)

  if isWarning and row.warningBg then
    row.warningBg:ClearAllPoints()
    row.warningBg:SetPoint("TOPLEFT", frame, "TOPLEFT", paddingX - 8, -rowTopY)
    row.warningBg:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", paddingX + contentWidth, -(rowTopY + rowHeight))
    row.warningBg:SetAlpha(1)
    row.warningBg:Show()
    row.warningBar:ClearAllPoints()
    row.warningBar:SetPoint("TOPLEFT", row.warningBg, "TOPLEFT", 0, 0)
    row.warningBar:SetPoint("BOTTOMLEFT", row.warningBg, "BOTTOMLEFT", 0, 0)
    row.warningBar:Show()
  end
  if isWarning and field.blink == true then
    state.warningFieldRows = state.warningFieldRows or {}
    state.warningFieldRows[#state.warningFieldRows + 1] = row
  end

  if showDivider and row.divider then
    row.divider:ClearAllPoints()
    row.divider:SetPoint("TOPLEFT", frame, "TOPLEFT", paddingX, -(rowTopY + rowHeight))
    row.divider:SetPoint("TOPRIGHT", frame, "TOPLEFT", paddingX + contentWidth, -(rowTopY + rowHeight))
    row.divider:Show()
  end
  return rowHeight
end

-- Rich info-card layout: header band across the full width, structured field
-- rows on the left and the teleport button as a framed tile in the free
-- right-side action area. Used by the post-accept invite notice; the regular
-- text body is hidden in this mode because the field rows carry the payload.
local function ApplyCenterNoticeRichLayout(deps, state, payload, hasTeleportButton)
  -- Start from a clean card: a previous rich render with more rows or a
  -- warning strip must not leak into this one.
  HideRichCenterNoticeElements(state)
  state.warningBlinkTime = 0

  local innerWidth = state.frame:GetWidth() - (state.config.paddingX * 2)
  local paddingX = state.config.paddingX
  local paddingY = state.config.paddingY
  local lineGap = math.max(SUBLINE_GAP, 6)
  local actionReserve = hasTeleportButton and (RICH_TELEPORT_BUTTON_WIDTH + 28) or 0
  local contentWidth = math.max(220, innerWidth - actionReserve)

  -- Hide the regular text body; rich mode renders payload via field rows.
  state.text:ClearAllPoints()
  state.text:SetText("")
  state.text:Hide()

  local cursorY = ApplyRichHeader(state, payload, innerWidth) + lineGap
  local actionTopY = cursorY
  local actionBottomY = nil

  if type(payload.fields) == "table" then
    local visibleFields = {}
    for i = 1, math.min(#payload.fields, MAX_FIELD_ROWS) do
      local field = payload.fields[i]
      if type(field) == "table" and type(field.label) == "string" and field.label ~= "" then
        visibleFields[#visibleFields + 1] = field
      end
    end
    for i, field in ipairs(visibleFields) do
      local nextField = visibleFields[i + 1]
      local showDivider = nextField ~= nil and nextField.grouped ~= true
      cursorY = cursorY + ApplyRichFieldRow(state, state.fieldRows[i], field, contentWidth, cursorY, showDivider)
      actionBottomY = cursorY
    end
    cursorY = cursorY + lineGap
  end

  if type(payload.teleportLabel) == "string" and payload.teleportLabel ~= "" and state.teleportHeader then
    state.teleportHeader:ClearAllPoints()
    state.teleportHeader:SetPoint("TOPLEFT", state.frame, "TOPLEFT", paddingX, -cursorY)
    state.teleportHeader:SetWidth(contentWidth)
    SetReadableText(state.teleportHeader, payload.teleportLabel)
    state.teleportHeader:Show()
    cursorY = cursorY + (state.teleportHeader:GetStringHeight() or 0) + lineGap
  end

  actionBottomY = actionBottomY or cursorY
  local richButtonHeight = math.max(RICH_TELEPORT_BUTTON_MIN_HEIGHT, math.ceil(actionBottomY - actionTopY))
  local richButtonCenterY = -(actionTopY + math.ceil(richButtonHeight / 2))
  local richIconSize = math.max(1, math.min(RICH_TELEPORT_BUTTON_WIDTH, richButtonHeight) - RICH_TELEPORT_ICON_INSET)
  local richButtonRequiredHeight = hasTeleportButton
      and math.abs(richButtonCenterY) + math.ceil(richButtonHeight / 2) + paddingY
    or 0
  local requiredHeight = math.max(state.config.minHeight, richButtonRequiredHeight, math.ceil(cursorY + paddingY))
  local richMaxHeight = math.max(tonumber(payload.maxHeight) or 0, state.config.maxHeight, requiredHeight)
  local frameHeight = math.min(richMaxHeight, requiredHeight)
  state.frame:SetHeight(frameHeight)

  if hasTeleportButton then
    deps.setTeleportButtonSize(state, RICH_TELEPORT_BUTTON_WIDTH, richButtonHeight, richIconSize)
    deps.setTeleportButtonAnchor(
      state,
      richButtonCenterY,
      "CENTER",
      "TOPRIGHT",
      -(RICH_TELEPORT_BUTTON_RIGHT_INSET + math.ceil(RICH_TELEPORT_BUTTON_WIDTH / 2))
    )
  end
end

-- deps.setTeleportButtonSize(state, width, height, iconSize) and
-- deps.setTeleportButtonAnchor(state, yOffset, point, relativePoint, xOffset)
-- are the facade's combat-deferred setters for the secure teleport button.
-- The card header is shared with the portal navigator, so both notice cards
-- open with the same band, kind chip, brand mark and headline.
function NoticeRichLayout.CreateHeaderElements(frame)
  return {
    headerBand = CreateCenterNoticeHeaderBand(frame),
    kindChip = CreateCenterNoticeKindChip(frame),
    brandText = CreateCenterNoticeBrand(frame),
  }
end
NoticeRichLayout.ApplyHeader = ApplyRichHeader

function NoticeRichLayout.Create(deps)
  return {
    ApplyLayout = function(state, payload, hasTeleportButton)
      ApplyCenterNoticeRichLayout(deps, state, payload, hasTeleportButton)
    end,
    HideElements = HideRichCenterNoticeElements,
  }
end
