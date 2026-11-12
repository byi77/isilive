local _, addonTable = ...
addonTable = addonTable or {}

local LoadoutCheckCard = {}
addonTable.LoadoutCheckCard = LoadoutCheckCard

-- Compact card for the pre-key loadout check (game/isiLive_loadout_check.lua).
-- Two sections, talents and loot spec, each with a status line and one button
-- per choice; a confirm button stores the current state as the target. The
-- card only renders the model it gets and forwards clicks to the controller.

local UICommon = assert(addonTable.UICommon, "isiLive: UICommon missing")
local Colors = UICommon.Colors
local IsSecretValue = addonTable.Validators and addonTable.Validators.IsSecretValue or function()
  return false
end

local CARD_WIDTH = 444
-- Same insets and type scale as the rich center notice (rule 242: the cards
-- of the stack share one card header and the label/value grid).
local PADDING = 20
local PADDING_Y = 12
local HEADER_FONT_DELTA = 10
local BODY_FONT_DELTA = 5
local LABEL_COLUMN_WIDTH = 144
local COLUMN_GAP = 6
local OPTION_WIDTH = 134
local OPTION_HEIGHT = 24
local OPTION_GAP = 6
-- In the card stack the card takes the stack width; the option buttons
-- fill the value column of that width (at least this many per row).
local MIN_OPTIONS_PER_ROW = 3
local ROW_PAD_Y = 5
local CONFIRM_WIDTH = 180
local CONFIRM_HEIGHT = 26
local TARGET_MARKER = "» "
-- Button labels in the body size of the card; a label that would be clipped
-- in its button falls back to the small font instead of showing "...".
local BUTTON_FONT = "GameFontHighlight"
local BUTTON_FONT_FALLBACK = "GameFontNormalSmall"

local STATUS_COLORS = {
  ok = Colors.SUCCESS_GREEN_BAR,
  mismatch = Colors.TEXT_ALERT_DANGER,
  unknown = Colors.TEXT_SUPPORTING,
  pending = Colors.MUTED_GOLD_PCT_TEXT,
  -- Nothing remembered to judge against: the active state in plain white.
  current = Colors.WHITE_RGB,
}

-- Status colour key of a section: without remembered targets the active
-- state is shown neutral, a running switch keeps its own colour.
local function StatusColorKey(section, remembers)
  if not remembers and section.status == "unknown" then
    return "current"
  end
  return section.status
end

-- Controller of the current render; its GetText follows the isiLive language
-- setting, which can differ from the client locale.
local activeController = nil

local function Text(key, fallback)
  if activeController and type(activeController.GetText) == "function" then
    return activeController.GetText(key, fallback)
  end
  return UICommon.GetLocalizedText(key, fallback)
end

local function SetColor(fontString, color)
  if type(color) == "table" then
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  end
end

local function SetColorTexture(texture, color)
  if type(color) == "table" then
    texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
  end
end

local function SetReadable(fontString, text)
  UICommon.SetReadableText(fontString, text or "")
end

local function IncreaseFontSize(fontString, delta)
  local common = addonTable.NoticeCommon
  if type(common) == "table" and type(common.IncreaseFontSize) == "function" then
    common.IncreaseFontSize(fontString, delta)
  end
end

local function CreateLine(parent, fontObject, color, fontDelta)
  local line = parent:CreateFontString(nil, "OVERLAY", fontObject)
  line:SetJustifyH("LEFT")
  line:SetWordWrap(false)
  line:SetWidth(CARD_WIDTH - 2 * PADDING)
  if fontDelta then
    IncreaseFontSize(line, fontDelta)
  end
  SetColor(line, color)
  return line
end

local function CreateHairline(frame, color)
  local line = frame:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  SetColorTexture(line, color)
  line:Hide()
  return line
end

-- Option buttons fill the value column, right of the label column. The
-- label column is as wide as on the invite card and grows with the longest
-- section label of the current language ("Spécialisation de butin").
local function ValueColumnX(frame)
  return PADDING + (frame._labelColumnWidth or LABEL_COLUMN_WIDTH) + COLUMN_GAP
end

local function OptionsPerRow(frame, width)
  local fit = math.floor((width - ValueColumnX(frame) - PADDING + OPTION_GAP) / (OPTION_WIDTH + OPTION_GAP))
  return math.max(MIN_OPTIONS_PER_ROW, fit)
end

local function MeasureText(fontString, text)
  SetReadable(fontString, text)
  local measure = fontString.GetUnboundedStringWidth or fontString.GetStringWidth
  if type(measure) ~= "function" then
    return 0
  end
  local ok, value = pcall(measure, fontString)
  if not ok or IsSecretValue(value) then
    return 0
  end
  return tonumber(value) or 0
end

local function ResolveLabelColumnWidth(frame, talentLabel, lootLabel)
  local widest = math.max(MeasureText(frame.talentHeader, talentLabel), MeasureText(frame.lootHeader, lootLabel))
  return math.max(LABEL_COLUMN_WIDTH, math.ceil(widest) + 4)
end

-- Measures the section labels of the current language into the label column
-- and returns the width the card needs: label column plus at least
-- MIN_OPTIONS_PER_ROW option buttons. Alone (no wider card in the stack) the
-- card takes this width, otherwise the buttons ran past its right edge.
local function PrepareColumns(frame)
  local talentLabel = Text("LOADOUT_CHECK_TALENTS", "Talents")
  local lootLabel = Text("LOADOUT_CHECK_LOOT", "Loot specialization")
  -- Measured unclipped before the column width is applied.
  frame.talentHeader:SetWidth(0)
  frame.lootHeader:SetWidth(0)
  frame._labelColumnWidth = ResolveLabelColumnWidth(frame, talentLabel, lootLabel)
  local optionsWidth = MIN_OPTIONS_PER_ROW * OPTION_WIDTH + (MIN_OPTIONS_PER_ROW - 1) * OPTION_GAP
  return math.max(CARD_WIDTH, ValueColumnX(frame) + optionsWidth + PADDING), talentLabel, lootLabel
end

local TEXT_LINE_KEYS = {
  "hint",
  "combatHint",
}

local function LootOptionLabel(option)
  if option.isCurrentSpec then
    return string.format(Text("LOADOUT_CHECK_LOOT_CURRENT_SPEC", "Current spec (%s)"), option.name or "?")
  end
  return option.name or "?"
end

local function TalentStatusText(talents, remembers)
  if talents.status == "pending" then
    return string.format(Text("LOADOUT_CHECK_STATUS_PENDING", "Switching to %s ..."), talents.pendingName or "?")
  end
  local current = talents.currentName or Text("LOADOUT_CHECK_NO_LOADOUT", "no saved loadout")
  if not remembers and talents.status == "unknown" then
    return current
  end
  if talents.status == "ok" then
    return string.format(Text("LOADOUT_CHECK_STATUS_OK", "OK: %s"), current)
  elseif talents.status == "mismatch" then
    return string.format(Text("LOADOUT_CHECK_STATUS_MISMATCH", "%s - expected: %s"), current, talents.targetName or "?")
  end
  return string.format(Text("LOADOUT_CHECK_STATUS_UNKNOWN", "%s (not remembered yet)"), current)
end

local function LootStatusText(loot, remembers)
  local function Name(isSpecDefault, name)
    if isSpecDefault then
      return string.format(Text("LOADOUT_CHECK_LOOT_CURRENT_SPEC", "Current spec (%s)"), name or "?")
    end
    return name or "?"
  end
  local current = Name(loot.currentIsSpecDefault, loot.currentName)
  if not remembers and loot.status == "unknown" then
    return current
  end
  if loot.status == "ok" then
    return string.format(Text("LOADOUT_CHECK_STATUS_OK", "OK: %s"), current)
  elseif loot.status == "mismatch" then
    return string.format(
      Text("LOADOUT_CHECK_STATUS_MISMATCH", "%s - expected: %s"),
      current,
      Name(loot.targetIsSpecDefault, loot.targetName)
    )
  end
  return string.format(Text("LOADOUT_CHECK_STATUS_UNKNOWN", "%s (not remembered yet)"), current)
end

local function ConfirmLabel(model)
  if not model.remembers then
    return Text("LOADOUT_CHECK_CONFIRM_CLOSE", "OK")
  end
  if model.allOk then
    return Text("LOADOUT_CHECK_CONFIRM_OK", "All OK")
  elseif not model.hasTarget then
    return Text("LOADOUT_CHECK_CONFIRM_REMEMBER", "OK - remember")
  end
  return Text("LOADOUT_CHECK_CONFIRM_KEEP", "Keep current")
end

-- The card is a section of the shared card stack (rule 242): the stack owns
-- position (screen center), surface, drag and motion; the card keeps its
-- top accent for the lead role.
local function BuildFrame()
  local parent = rawget(_G, "UIParent")
  local frame = CreateFrame("Frame", "IsiLiveLoadoutCheckCard", parent, "BackdropTemplate")
  frame:SetWidth(CARD_WIDTH)
  frame:SetPoint("TOP", parent, "TOP", 0, -140)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame._isiLiveNoticeAccent = UICommon.CreateNoticeChrome(frame)
  UICommon.ApplyNoticeKind(frame, "info")
  frame:Hide()

  -- Card header shared with the center notice and the portal navigator:
  -- kind chip with the eyebrow, brand mark, headline, hairline.
  frame.eyebrow = CreateLine(frame, "GameFontNormalSmall", Colors.CYAN_EYEBROW, math.floor(HEADER_FONT_DELTA / 3))
  frame.title = CreateLine(frame, "GameFontNormalLarge", Colors.TEXT_HEADING, HEADER_FONT_DELTA)
  frame.titleSeparator = CreateHairline(frame, Colors.BORDER_NOTICE or { 0.24, 0.55, 0.82, 0.58 })
  local richLayout = addonTable.NoticeRichLayout
  if type(richLayout) == "table" and type(richLayout.CreateHeaderElements) == "function" then
    frame.header = richLayout.CreateHeaderElements(frame)
  end

  -- Body on the label/value grid of the invite card.
  frame.talentHeader = CreateLine(frame, "GameFontNormal", Colors.TEXT_SUPPORTING, BODY_FONT_DELTA)
  frame.talentStatus = CreateLine(frame, "GameFontNormal", nil, BODY_FONT_DELTA)
  frame.lootHeader = CreateLine(frame, "GameFontNormal", Colors.TEXT_SUPPORTING, BODY_FONT_DELTA)
  frame.lootStatus = CreateLine(frame, "GameFontNormal", nil, BODY_FONT_DELTA)
  frame.lootDivider = CreateHairline(frame, Colors.NOTICE_ROW_DIVIDER or { 0.58, 0.65, 0.74, 0.14 })
  frame.hint = CreateLine(frame, "GameFontHighlight", Colors.TEXT_SUPPORTING, 2)
  frame.hint:SetWordWrap(true)
  frame.combatHint = CreateLine(frame, "GameFontHighlight", Colors.ORANGE_WARNING_LABEL, 2)

  frame.closeButton = UICommon.CreateCloseButton(frame, {
    point = { "TOPRIGHT", frame, "TOPRIGHT", -6, -6 },
  })

  frame.confirmButton = UICommon.CreateActionButton(frame, {
    width = CONFIRM_WIDTH,
    height = CONFIRM_HEIGHT,
    role = "primary",
    fontObject = BUTTON_FONT,
  })

  frame.talentButtons = {}
  frame.lootButtons = {}
  return frame
end

local function SetButtonLabel(fontString, text)
  if type(fontString.SetFontObject) == "function" then
    fontString:SetFontObject(BUTTON_FONT)
  end
  SetReadable(fontString, text)
  if type(fontString.IsTruncated) == "function" and fontString:IsTruncated() == true then
    if type(fontString.SetFontObject) == "function" then
      fontString:SetFontObject(BUTTON_FONT_FALLBACK)
    end
  end
end

local function GetOptionButton(frame, pool, index)
  local button = pool[index]
  if not button then
    button =
      UICommon.CreateActionButton(frame, { width = OPTION_WIDTH, height = OPTION_HEIGHT, fontObject = BUTTON_FONT })
    if button._flatLabel then
      button._flatLabel:SetWidth(OPTION_WIDTH - 8)
      button._flatLabel:SetWordWrap(false)
    end
    pool[index] = button
  end
  return button
end

-- Lays out one button per option below `anchorY` and returns the new y.
-- `availability`: nil for clickable buttons, "combat" in combat, "cooldown"
-- while a talent switch is still committing.
local function LayoutOptions(frame, pool, options, anchorY, labelFor, onClick, availability)
  local y = anchorY
  local perRow = frame._optionsPerRow or MIN_OPTIONS_PER_ROW
  for index, option in ipairs(options) do
    local button = GetOptionButton(frame, pool, index)
    local column = (index - 1) % perRow
    if column == 0 and index > 1 then
      y = y - OPTION_HEIGHT - OPTION_GAP
    end
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", ValueColumnX(frame) + column * (OPTION_WIDTH + OPTION_GAP), y)
    local label = labelFor(option)
    if option.target then
      label = TARGET_MARKER .. label
    end
    if button._flatLabel then
      SetButtonLabel(button._flatLabel, label)
    end
    -- The active option is marked as selected, not by the primary role: the
    -- Modern design draws primary like secondary, which hid the active choice.
    button:SetSemanticRole("secondary")
    button:SetSelected(option.active == true)
    button:SetAvailabilityState(availability or "available")
    button:SetScript("OnClick", function()
      onClick(option)
    end)
    button:Show()
  end
  for index = #options + 1, #pool do
    pool[index]:Hide()
  end
  if #options == 0 then
    return y
  end
  return y - OPTION_HEIGHT - OPTION_GAP
end

local function FontHeight(fontString)
  local height = tonumber(fontString:GetStringHeight())
  if height and height > 0 then
    return height
  end
  local _, size = fontString:GetFont()
  return tonumber(size) or 14
end

-- Header through the shared notice header (chip, brand, headline, hairline);
-- returns the y offset below it. Without the notice layout module the card
-- falls back to a plain eyebrow and headline. A mismatch turns the kind (chip,
-- rail, top accent) to the warning colour.
local function RenderHeader(frame, model, width)
  local hasMismatch = model.talents.status == "mismatch" or model.loot.status == "mismatch"
  UICommon.ApplyNoticeKind(frame, hasMismatch and "warning" or "info")
  local title = Text("LOADOUT_CHECK_TITLE", "Talents & loot check")
  local richLayout = addonTable.NoticeRichLayout
  if frame.header and type(richLayout) == "table" and type(richLayout.ApplyHeader) == "function" then
    frame.headerState = frame.headerState
      or {
        frame = frame,
        config = { paddingX = PADDING, paddingY = PADDING_Y },
        eyebrowText = frame.eyebrow,
        titleText = frame.title,
        titleSeparator = frame.titleSeparator,
        headerBand = frame.header.headerBand,
        kindChip = frame.header.kindChip,
        brandText = frame.header.brandText,
      }
    local below =
      richLayout.ApplyHeader(frame.headerState, { eyebrow = model.dungeonName, title = title }, width - 2 * PADDING)
    return -below
  end
  local y = -PADDING_Y
  for _, entry in ipairs({ { frame.eyebrow, model.dungeonName or "" }, { frame.title, title } }) do
    entry[1]:ClearAllPoints()
    entry[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, y)
    entry[1]:SetWidth(width - 2 * PADDING)
    SetReadable(entry[1], entry[2])
    entry[1]:Show()
    y = y - FontHeight(entry[1]) - 4
  end
  return y - 6
end

-- One section on the label/value grid: label left, status right of it; the
-- option buttons follow below the status in the value column. Returns the y
-- below the row.
local function RenderSectionRow(frame, label, status, texts, statusColor, y, width)
  local valueX = ValueColumnX(frame)
  y = y - ROW_PAD_Y
  label:ClearAllPoints()
  label:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, y)
  label:SetWidth(frame._labelColumnWidth or LABEL_COLUMN_WIDTH)
  SetReadable(label, texts.label)
  label:Show()
  status:ClearAllPoints()
  status:SetPoint("TOPLEFT", frame, "TOPLEFT", valueX, y)
  status:SetWidth(math.max(40, width - valueX - PADDING))
  SetColor(status, statusColor)
  SetReadable(status, texts.status)
  status:Show()
  return y - math.max(FontHeight(label), FontHeight(status)) - 6
end

local function Render(frame, model, controller, width)
  activeController = controller
  local requiredWidth, talentLabel, lootLabel = PrepareColumns(frame)
  width = math.max(tonumber(width) or CARD_WIDTH, requiredWidth)
  frame:SetWidth(width)
  frame._optionsPerRow = OptionsPerRow(frame, width)
  for _, key in ipairs(TEXT_LINE_KEYS) do
    frame[key]:SetWidth(width - 2 * PADDING)
  end
  local y = RenderHeader(frame, model, width)
  local function Place(line, text)
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, y)
    SetReadable(line, text)
    line:Show()
    y = y - FontHeight(line) - 4
  end

  -- The active loadout name stands out in the target gold, as on the invite card.
  local talentColorKey = StatusColorKey(model.talents, model.remembers)
  y = RenderSectionRow(frame, frame.talentHeader, frame.talentStatus, {
    label = talentLabel,
    status = TalentStatusText(model.talents, model.remembers),
  }, talentColorKey == "current" and Colors.GOLD_TARGET_TEXT or STATUS_COLORS[talentColorKey], y, width)
  y = LayoutOptions(frame, frame.talentButtons, model.talents.options, y, function(option)
    return option.name
  end, function(option)
    controller.SelectLoadout(option.id)
  end, model.inCombat and "combat" or (model.talents.status == "pending" and "cooldown" or nil))

  -- Hairline between the two sections, as between the invite card's fields.
  frame.lootDivider:ClearAllPoints()
  frame.lootDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, y)
  frame.lootDivider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, y)
  frame.lootDivider:Show()
  y = y - 1

  y = RenderSectionRow(frame, frame.lootHeader, frame.lootStatus, {
    label = lootLabel,
    status = LootStatusText(model.loot, model.remembers),
  }, STATUS_COLORS[StatusColorKey(model.loot, model.remembers)], y, width)
  y = LayoutOptions(frame, frame.lootButtons, model.loot.options, y, LootOptionLabel, function(option)
    controller.SelectLootSpec(option.id)
  end, model.inCombat and "combat" or nil)

  if model.inCombat then
    Place(frame.combatHint, Text("LOADOUT_CHECK_COMBAT_BLOCKED", "Talents and loot spec cannot be changed in combat."))
  else
    frame.combatHint:Hide()
  end

  -- The "confirming remembers" hint only while targets are remembered.
  if model.remembers then
    local hint = string.format(
      Text("LOADOUT_CHECK_HINT", "Confirming remembers the current state for %s with %s."),
      model.dungeonName or "?",
      model.specName or "?"
    )
    frame.hint:ClearAllPoints()
    frame.hint:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, y - 2)
    SetReadable(frame.hint, hint)
    frame.hint:Show()
    local hintHeight = FontHeight(frame.hint)
    y = y - 2 - hintHeight - 10
  else
    frame.hint:Hide()
    y = y - 6
  end

  frame.confirmButton:ClearAllPoints()
  frame.confirmButton:SetPoint("TOP", frame, "TOP", 0, y)
  if frame.confirmButton._flatLabel then
    SetButtonLabel(frame.confirmButton._flatLabel, ConfirmLabel(model))
  end
  -- Confirming mid-switch would remember the old loadout.
  frame.confirmButton:SetAvailabilityState(model.talents.status == "pending" and "cooldown" or "available")
  frame.confirmButton:SetScript("OnClick", function()
    controller.Confirm()
  end)
  y = y - CONFIRM_HEIGHT - PADDING

  frame.closeButton:SetScript("OnClick", function()
    controller.Dismiss()
  end)
  frame:SetHeight(-y)
end

--- Creates the card object. The WoW frame itself is built on first Show.
function LoadoutCheckCard.Create()
  local card = {}
  local frame = nil
  local section = nil
  local lastModel, lastController = nil, nil

  local function EnsureFrame()
    if frame then
      return
    end
    frame = BuildFrame()
    local cardStack = addonTable.CardStack
    if type(cardStack) == "table" and type(cardStack.Register) == "function" then
      section = cardStack.Register("loadout", frame, {
        preferredWidth = CARD_WIDTH,
        onRoleChanged = function(isLead)
          local richLayout = addonTable.NoticeRichLayout
          if frame.headerState and type(richLayout) == "table" and type(richLayout.ApplyHeaderRole) == "function" then
            richLayout.ApplyHeaderRole(frame.headerState, isLead)
          end
        end,
        relayout = function(width)
          if lastModel and lastController then
            Render(frame, lastModel, lastController, width)
          end
        end,
      })
    end
  end

  function card.Show(_, model, controller)
    if type(model) ~= "table" or type(controller) ~= "table" then
      return false
    end
    EnsureFrame()
    lastModel, lastController = model, controller
    if section then
      -- Report the needed width before asking the stack for the shared one.
      activeController = controller
      local requiredWidth = PrepareColumns(frame)
      if type(section.SetPreferredWidth) == "function" then
        section.SetPreferredWidth(requiredWidth)
      end
      Render(frame, model, controller, section.GetWidth())
      section.Show()
    else
      Render(frame, model, controller, CARD_WIDTH)
      frame:Show()
    end
    return true
  end

  function card.Hide()
    if section then
      section.Hide()
    elseif frame then
      frame:Hide()
    end
  end

  -- A card that is fading out already counts as closed.
  function card.IsShown()
    if section then
      return section.IsActive()
    end
    return frame ~= nil and frame:IsShown() == true
  end

  return card
end
