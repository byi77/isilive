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

local NOTICE_TITLE_COLOR_R, NOTICE_TITLE_COLOR_G, NOTICE_TITLE_COLOR_B = 1, 0.9, 0.45
local NOTICE_GOLD_ACCENT_R, NOTICE_GOLD_ACCENT_G, NOTICE_GOLD_ACCENT_B = 1, 0.82, 0.25
local SUBLINE_GAP = 4

local FIELD_LABEL_WIDTH = 144
local MAX_FIELD_ROWS = 4
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

-- Single source for the constants the Notice facade still needs.
NoticeRichLayout.TITLE_COLOR = { NOTICE_TITLE_COLOR_R, NOTICE_TITLE_COLOR_G, NOTICE_TITLE_COLOR_B }
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
  title:SetTextColor(NOTICE_TITLE_COLOR_R, NOTICE_TITLE_COLOR_G, NOTICE_TITLE_COLOR_B)
  title:Hide()
  return title
end

local function CreateCenterNoticeTitleSeparator(frame)
  if type(frame.CreateTexture) ~= "function" then
    return nil
  end
  local sep = frame:CreateTexture(nil, "ARTWORK")
  sep:SetHeight(1)
  sep:SetColorTexture(unpack(Colors.BLUE_SEPARATOR or { 0.36, 0.71, 1, 0.55 }))
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

  return { label = label, value = value }
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
-- separator, teleport header, field rows) so FontString layering is unchanged.
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
  }
end

-- Hides every rich-layout primitive. Called on every Show invocation so that
-- subsequent stack-mode / legacy-mode renders do not leak title/separator/
-- field/teleport-header fragments from a previous rich render.
local function HideRichCenterNoticeElements(state)
  state.warningFieldRows = nil
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
    end
  end
end

-- Rich info-card layout: structured text stays left/center while the teleport
-- button sits larger in the free right-side action area. Used by the post-accept
-- invite notice; the regular text body is hidden in this mode because the field
-- rows carry the structured payload instead.
local function ApplyCenterNoticeRichLayout(deps, state, payload, hasTeleportButton)
  local innerWidth = state.frame:GetWidth() - (state.config.paddingX * 2)
  local paddingX = state.config.paddingX
  local paddingY = state.config.paddingY
  local lineGap = math.max(SUBLINE_GAP, 6)
  local sectionGap = lineGap * 2
  local actionReserve = hasTeleportButton and (RICH_TELEPORT_BUTTON_WIDTH + 28) or 0
  local contentWidth = math.max(220, innerWidth - actionReserve)

  -- Hide the regular text body — rich mode renders payload via field rows.
  state.text:ClearAllPoints()
  state.text:SetText("")
  state.text:Hide()

  local cursorY = paddingY + 2
  local actionTopY = nil
  local actionBottomY = nil
  state.warningFieldRows = nil
  state.warningBlinkTime = 0

  if type(payload.eyebrow) == "string" and payload.eyebrow ~= "" and state.eyebrowText then
    state.eyebrowText:ClearAllPoints()
    state.eyebrowText:SetPoint("TOPLEFT", state.frame, "TOPLEFT", paddingX, -cursorY)
    state.eyebrowText:SetWidth(contentWidth)
    SetReadableText(state.eyebrowText, payload.eyebrow)
    state.eyebrowText:Show()
    cursorY = cursorY + (state.eyebrowText:GetStringHeight() or 0) + 2
  elseif state.eyebrowText then
    state.eyebrowText:SetText("")
    state.eyebrowText:Hide()
  end

  if type(payload.title) == "string" and payload.title ~= "" and state.titleText then
    actionTopY = cursorY
    state.titleText:ClearAllPoints()
    state.titleText:SetPoint("TOPLEFT", state.frame, "TOPLEFT", paddingX, -cursorY)
    state.titleText:SetWidth(contentWidth)
    state.titleText:SetJustifyH("LEFT")
    SetReadableText(state.titleText, payload.title)
    state.titleText:Show()
    cursorY = cursorY + (state.titleText:GetStringHeight() or 0) + lineGap

    if state.titleSeparator then
      state.titleSeparator:ClearAllPoints()
      state.titleSeparator:SetPoint("TOPLEFT", state.frame, "TOPLEFT", paddingX, -cursorY)
      state.titleSeparator:SetPoint("TOPRIGHT", state.frame, "TOPLEFT", paddingX + contentWidth, -cursorY)
      state.titleSeparator:Show()
      cursorY = cursorY + 1 + sectionGap
    else
      cursorY = cursorY + sectionGap
    end
  end

  if type(payload.fields) == "table" then
    local valueWidth = math.max(40, contentWidth - FIELD_LABEL_WIDTH - lineGap)
    for i, row in ipairs(state.fieldRows) do
      local field = payload.fields[i]
      if i > MAX_FIELD_ROWS then
        break
      end
      if type(field) == "table" and type(field.label) == "string" and field.label ~= "" then
        local valueText = type(field.value) == "string" and field.value or ""
        local isWarning = field.warning == true
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", state.frame, "TOPLEFT", paddingX, -cursorY)
        SetReadableText(row.label, field.label)
        if isWarning then
          row.label:SetTextColor(FIELD_WARNING_R, FIELD_WARNING_G, FIELD_WARNING_B, 1)
        else
          row.label:SetTextColor(FIELD_LABEL_R, FIELD_LABEL_G, FIELD_LABEL_B, 1)
        end
        row.label:Show()

        row.value:ClearAllPoints()
        row.value:SetPoint("TOPLEFT", state.frame, "TOPLEFT", paddingX + FIELD_LABEL_WIDTH + lineGap, -cursorY)
        row.value:SetWidth(valueWidth)
        SetReadableText(row.value, valueText)
        if isWarning then
          row.value:SetTextColor(FIELD_WARNING_R, FIELD_WARNING_G, FIELD_WARNING_B, 1)
          if field.blink == true then
            state.warningFieldRows = state.warningFieldRows or {}
            state.warningFieldRows[#state.warningFieldRows + 1] = row
          end
        else
          row.value:SetTextColor(FIELD_VALUE_R, FIELD_VALUE_G, FIELD_VALUE_B, 1)
        end
        row.value:Show()

        local rowHeight = math.max(row.label:GetStringHeight() or 0, row.value:GetStringHeight() or 0)
        actionBottomY = cursorY + rowHeight
        cursorY = cursorY + rowHeight + lineGap
      end
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

  actionTopY = actionTopY or paddingY
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
function NoticeRichLayout.Create(deps)
  return {
    ApplyLayout = function(state, payload, hasTeleportButton)
      ApplyCenterNoticeRichLayout(deps, state, payload, hasTeleportButton)
    end,
    HideElements = HideRichCenterNoticeElements,
  }
end
