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

local CARD_WIDTH = 444
local PADDING = 14
local OPTION_WIDTH = 134
local OPTION_HEIGHT = 22
local OPTION_GAP = 6
-- In the card stack the card takes the stack width; the option buttons
-- fill the rows of that width (at least this many per row).
local MIN_OPTIONS_PER_ROW = 3
local LINE_HEIGHT = 16
local CONFIRM_WIDTH = 180
local CONFIRM_HEIGHT = 26
local TARGET_MARKER = "» "

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

local function SetReadable(fontString, text)
  UICommon.SetReadableText(fontString, text or "")
end

local function CreateLine(parent, fontObject, color)
  local line = parent:CreateFontString(nil, "OVERLAY", fontObject)
  line:SetJustifyH("LEFT")
  line:SetWordWrap(false)
  line:SetWidth(CARD_WIDTH - 2 * PADDING)
  SetColor(line, color)
  return line
end

local function OptionsPerRow(width)
  local fit = math.floor((width - 2 * PADDING + OPTION_GAP) / (OPTION_WIDTH + OPTION_GAP))
  return math.max(MIN_OPTIONS_PER_ROW, fit)
end

local TEXT_LINE_KEYS = {
  "eyebrow",
  "title",
  "talentHeader",
  "talentStatus",
  "lootHeader",
  "lootStatus",
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
  frame:Hide()

  frame.eyebrow = CreateLine(frame, "GameFontNormalSmall", Colors.CYAN_EYEBROW)
  frame.title = CreateLine(frame, UICommon.Theme.typography.title, Colors.TEXT_HEADING)
  frame.talentHeader = CreateLine(frame, "GameFontNormal", Colors.TEXT_SECTION)
  frame.talentStatus = CreateLine(frame, "GameFontHighlightSmall")
  frame.lootHeader = CreateLine(frame, "GameFontNormal", Colors.TEXT_SECTION)
  frame.lootStatus = CreateLine(frame, "GameFontHighlightSmall")
  frame.hint = CreateLine(frame, "GameFontHighlightSmall", Colors.TEXT_SUPPORTING)
  frame.hint:SetWordWrap(true)
  frame.combatHint = CreateLine(frame, "GameFontHighlightSmall", Colors.ORANGE_WARNING_LABEL)

  frame.closeButton = UICommon.CreateCloseButton(frame, {
    point = { "TOPRIGHT", frame, "TOPRIGHT", -6, -6 },
  })

  frame.confirmButton = UICommon.CreateActionButton(frame, {
    width = CONFIRM_WIDTH,
    height = CONFIRM_HEIGHT,
    role = "primary",
  })

  frame.talentButtons = {}
  frame.lootButtons = {}
  return frame
end

local function GetOptionButton(frame, pool, index)
  local button = pool[index]
  if not button then
    button = UICommon.CreateActionButton(frame, { width = OPTION_WIDTH, height = OPTION_HEIGHT })
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
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING + column * (OPTION_WIDTH + OPTION_GAP), y)
    local label = labelFor(option)
    if option.target then
      label = TARGET_MARKER .. label
    end
    if button._flatLabel then
      SetReadable(button._flatLabel, label)
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

local function Render(frame, model, controller, width)
  activeController = controller
  width = tonumber(width) or CARD_WIDTH
  frame:SetWidth(width)
  frame._optionsPerRow = OptionsPerRow(width)
  for _, key in ipairs(TEXT_LINE_KEYS) do
    frame[key]:SetWidth(width - 2 * PADDING)
  end
  local y = -PADDING
  local function Place(line, text, height)
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, y)
    SetReadable(line, text)
    line:Show()
    y = y - (height or LINE_HEIGHT)
  end

  Place(frame.eyebrow, model.dungeonName or "")
  Place(frame.title, Text("LOADOUT_CHECK_TITLE", "Talents & loot check"), LINE_HEIGHT + 8)

  Place(frame.talentHeader, Text("LOADOUT_CHECK_TALENTS", "Talents"))
  -- The active loadout name stands out in the target gold, as on the invite card.
  local talentColorKey = StatusColorKey(model.talents, model.remembers)
  SetColor(frame.talentStatus, talentColorKey == "current" and Colors.GOLD_TARGET_TEXT or STATUS_COLORS[talentColorKey])
  Place(frame.talentStatus, TalentStatusText(model.talents, model.remembers), LINE_HEIGHT + 4)
  y = LayoutOptions(frame, frame.talentButtons, model.talents.options, y, function(option)
    return option.name
  end, function(option)
    controller.SelectLoadout(option.id)
  end, model.inCombat and "combat" or (model.talents.status == "pending" and "cooldown" or nil))
  y = y - 4

  Place(frame.lootHeader, Text("LOADOUT_CHECK_LOOT", "Loot specialization"))
  SetColor(frame.lootStatus, STATUS_COLORS[StatusColorKey(model.loot, model.remembers)])
  Place(frame.lootStatus, LootStatusText(model.loot, model.remembers), LINE_HEIGHT + 4)
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
    local hintHeight = tonumber(frame.hint:GetStringHeight()) or LINE_HEIGHT
    y = y - 2 - hintHeight - 10
  else
    frame.hint:Hide()
    y = y - 6
  end

  frame.confirmButton:ClearAllPoints()
  frame.confirmButton:SetPoint("TOP", frame, "TOP", 0, y)
  if frame.confirmButton._flatLabel then
    SetReadable(frame.confirmButton._flatLabel, ConfirmLabel(model))
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
