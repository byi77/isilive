local _, addonTable = ...

addonTable = addonTable or {}

-- Shared card stack (rule 242). Every isiLive card -- the center notice, the
-- portal navigator and the talent & loot check -- is one section of a single
-- stack at the screen center. Several cards read as ONE card: the stack owns
-- the one frame, border and background; the first section carries the card
-- header (top accent, header band, brand mark), every further section is
-- separated by a hairline and keeps only its own chip and headline. A section
-- is registered once per card frame under a `kind`; showing the same kind
-- again replaces its content in place, a new kind slides in as a further
-- section. Sections are ordered by priority, then by the order they appeared.
--
-- Free dragging stays until the edit mode integration exists: dragging any
-- section moves the whole stack. The position is not saved; an empty stack
-- returns to its default anchor the next time a card appears.
local CardStack = {}
addonTable.CardStack = CardStack

local UICommon = assert(addonTable.UICommon, "isiLive: UICommon missing")
local Colors = UICommon.Colors or {}

-- Lower priority = higher in the stack. The center notice (group and dungeon
-- news) leads, the pre-key talent & loot check follows, the large portal
-- navigator closes the stack. In the usual flow a later card therefore slides
-- in below the earlier ones.
CardStack.KIND_PRIORITY = {
  notice = 10,
  demoNoticeTarget = 11,
  demoNoticeDifficulty = 12,
  loadout = 20,
  portal = 30,
}
local DEFAULT_PRIORITY = 50

-- The stack's top edge sits this far above the screen center, so a typical
-- card is centered and further sections grow downwards.
CardStack.TOP_OFFSET = 200
-- A stack taller than the room below its default place moves up until its
-- bottom keeps this gap to the screen edge (never past the top edge).
CardStack.SCREEN_MARGIN = 16
-- Above the main window, below the simulation tablet (DIALOG).
CardStack.FRAME_STRATA = "HIGH"
CardStack.FRAME_NAME = "isiLiveCardStack"

local function CallMethod(target, methodName, ...)
  local method = type(target) == "table" and target[methodName] or nil
  if type(method) == "function" then
    return method(target, ...)
  end
  return nil
end

local function FrameHeight(frame)
  local height = tonumber(CallMethod(frame, "GetHeight"))
  return height and height > 0 and height or 0
end

-- ---------------------------------------------------------------------------
-- Stack container
-- ---------------------------------------------------------------------------

local function CreateContainer(stack)
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return nil
  end
  local container = createFrame("Frame", CardStack.FRAME_NAME, stack.parent, "BackdropTemplate")
  if type(container) ~= "table" then
    return nil
  end
  CallMethod(container, "SetSize", 1, 1)
  CallMethod(container, "SetFrameStrata", CardStack.FRAME_STRATA)
  CallMethod(container, "SetMovable", true)
  CallMethod(container, "SetClampedToScreen", true)
  CallMethod(container, "SetClampRectInsets", 0, 0, 0, 0)
  CallMethod(container, "Hide")
  -- The one surface of the whole stack: Modern and Classic both paint it
  -- through the shared NOTICE preset.
  UICommon.ApplyBackdrop(container, "NOTICE")
  return container
end

local function AnchorContainer(stack)
  local container = stack.container
  CallMethod(container, "ClearAllPoints")
  CallMethod(container, "SetPoint", "TOP", stack.parent, "CENTER", 0, stack.topOffset)
end

local function ResetContainerPosition(stack)
  stack.moved = false
  stack.topOffset = CardStack.TOP_OFFSET
  AnchorContainer(stack)
end

-- Top offset at which a stack of `height` ends SCREEN_MARGIN above the screen
-- bottom, or the default when it fits; capped so the top stays on screen.
local function FittingTopOffset(stack, height)
  local screenHeight = tonumber(CallMethod(stack.parent, "GetHeight"))
  if not screenHeight or screenHeight <= 0 then
    return CardStack.TOP_OFFSET
  end
  local half = screenHeight / 2
  local needed = height - half + CardStack.SCREEN_MARGIN
  return math.min(math.max(CardStack.TOP_OFFSET, needed), half - CardStack.SCREEN_MARGIN)
end

-- A stack at its default place moves up when a new section would push its
-- bottom off screen, sliding from its old place. It only moves up while it
-- is shown: a card leaving never makes the rest jump down; an empty stack
-- starts at the default place again. A dragged stack stays where it was put.
local function FitContainerToScreen(stack, height)
  if stack.moved then
    return
  end
  local offset = FittingTopOffset(stack, height)
  local current = stack.topOffset or CardStack.TOP_OFFSET
  if offset <= current then
    return
  end
  stack.topOffset = offset
  AnchorContainer(stack)
  if CallMethod(stack.container, "IsShown") == true then
    UICommon.PlaySlide(stack.container, current - offset)
  end
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

local function SortSections(a, b)
  if a.priority ~= b.priority then
    return a.priority < b.priority
  end
  return a.sequence < b.sequence
end

-- Sections that take room in the stack: visible ones and the ones still
-- fading out (they keep their slot until the fade has finished).
local function CollectLaidOut(stack)
  local list = {}
  for _, section in pairs(stack.sections) do
    if section.state ~= "hidden" then
      list[#list + 1] = section
    end
  end
  table.sort(list, SortSections)
  return list
end

local function ResolveWidth(stack, list)
  local width = 0
  for _, section in ipairs(list) do
    if section.state == "visible" then
      width = math.max(width, tonumber(section.preferredWidth) or 0)
    end
  end
  if width <= 0 then
    for _, section in ipairs(list) do
      width = math.max(width, tonumber(section.preferredWidth) or 0)
    end
  end
  return width > 0 and width or stack.width or 1
end

local function EnsureDivider(section)
  if section.divider or type(section.frame.CreateTexture) ~= "function" then
    return section.divider
  end
  local divider = section.frame:CreateTexture(nil, "ARTWORK")
  CallMethod(divider, "SetHeight", 1)
  CallMethod(divider, "SetPoint", "TOPLEFT", section.frame, "TOPLEFT", 1, 0)
  CallMethod(divider, "SetPoint", "TOPRIGHT", section.frame, "TOPRIGHT", -1, 0)
  local color = Colors.BORDER_NOTICE or { 0.24, 0.55, 0.82, 0.58 }
  CallMethod(divider, "SetColorTexture", color[1], color[2], color[3], color[4] or 1)
  section.divider = divider
  return divider
end

-- The lead section carries the card header; the others a hairline on top.
local function ApplyRole(section, isLead)
  local frame = section.frame
  frame._isiLiveCardLead = isLead
  local accent = frame._isiLiveNoticeAccent
  if accent then
    CallMethod(accent, isLead and "Show" or "Hide")
  end
  local divider = EnsureDivider(section)
  if divider then
    CallMethod(divider, isLead and "Hide" or "Show")
  end
  if section.isLead ~= isLead then
    section.isLead = isLead
    if type(section.onRoleChanged) == "function" then
      section.onRoleChanged(isLead)
    end
  end
end

-- Re-anchors every section below the previous one, sizes the stack, and
-- lets a section that moved slide from its old place to the new one.
local function Reflow(stack)
  local container = stack.container
  if not container then
    return
  end
  local list = CollectLaidOut(stack)
  local width = ResolveWidth(stack, list)
  stack.width = width
  stack.reflowing = true
  for _, section in ipairs(list) do
    if section.appliedWidth ~= width then
      section.appliedWidth = width
      CallMethod(section.frame, "SetWidth", width)
      if type(section.relayout) == "function" then
        section.relayout(width)
      end
    end
  end
  stack.reflowing = false

  local top = 0
  for index, section in ipairs(list) do
    ApplyRole(section, index == 1)
    local frame = section.frame
    CallMethod(frame, "ClearAllPoints")
    CallMethod(frame, "SetPoint", "TOPLEFT", container, "TOPLEFT", 0, -top)
    if section.top ~= nil and section.top ~= top and section.state == "visible" then
      -- Positive offset = above the anchor: a section that moved up starts
      -- at its old, lower place (negative offset) and slides up.
      UICommon.PlaySlide(frame, top - section.top)
    end
    section.top = top
    top = top + FrameHeight(frame)
  end
  CallMethod(container, "SetSize", width, math.max(1, top))
  FitContainerToScreen(stack, top)
end

-- ---------------------------------------------------------------------------
-- Visibility
-- ---------------------------------------------------------------------------

local function HasVisible(stack, except)
  for _, section in pairs(stack.sections) do
    if section ~= except and section.state == "visible" then
      return true
    end
  end
  return false
end

local function FinishSectionHidden(section)
  section.state = "hidden"
  section.top = nil
  section.viaContainer = nil
  if type(section.onHidden) == "function" then
    section.onHidden()
  end
end

-- Last card gone: the whole stack fades out, then its sections hide.
local function HideContainer(stack)
  UICommon.HideAnimated(stack.container, "card", {
    onHidden = function()
      for _, section in pairs(stack.sections) do
        if section.state == "leaving" then
          stack.hidingSection = section
          CallMethod(section.frame, "Hide")
          stack.hidingSection = nil
          FinishSectionHidden(section)
        end
      end
      Reflow(stack)
    end,
  })
end

local function HideSection(stack, section)
  if section.state ~= "visible" then
    return
  end
  section.state = "leaving"
  if not HasVisible(stack, section) then
    section.viaContainer = true
    HideContainer(stack)
    return
  end
  UICommon.HideAnimated(section.frame, "card", {
    onHidden = function()
      if section.state ~= "leaving" then
        return
      end
      FinishSectionHidden(section)
      Reflow(stack)
    end,
  })
end

-- A stack fading out gets a new card: it fades back in, and sections that
-- were leaving with it now fade out on their own.
local function ReviveContainer(stack)
  UICommon.ShowAnimated(stack.container, "card")
  for _, section in pairs(stack.sections) do
    if section.state == "leaving" and section.viaContainer then
      section.viaContainer = nil
      UICommon.HideAnimated(section.frame, "card", {
        onHidden = function()
          if section.state ~= "leaving" then
            return
          end
          FinishSectionHidden(section)
          Reflow(stack)
        end,
      })
    end
  end
end

local function ShowSection(stack, section)
  local container = stack.container
  if section.state == "visible" then
    -- Same kind again: new content in place, no entrance.
    Reflow(stack)
    return
  end
  local containerShown = CallMethod(container, "IsShown") == true and not UICommon.IsHiding(container)
  if section.state == "leaving" then
    section.state = "visible"
    if section.viaContainer then
      section.viaContainer = nil
      UICommon.ShowAnimated(container, "card")
    else
      UICommon.ShowAnimated(section.frame, "card")
    end
    Reflow(stack)
    return
  end

  stack.sequence = stack.sequence + 1
  section.sequence = stack.sequence
  section.state = "visible"
  section.top = nil
  if CallMethod(container, "IsShown") ~= true then
    -- First card: the stack appears at its default place and carries the
    -- entrance; the section itself is simply there.
    ResetContainerPosition(stack)
    UICommon.ShowAnimated(section.frame, "card", { instant = true })
    Reflow(stack)
    UICommon.ShowAnimated(container, "card")
    return
  end
  Reflow(stack)
  if containerShown then
    UICommon.ShowAnimated(section.frame, "card")
  else
    UICommon.ShowAnimated(section.frame, "card", { instant = true })
    ReviveContainer(stack)
  end
end

-- A card frame hidden by other code (a test, a scenario, Blizzard ESC)
-- leaves the stack at once, so the stack never keeps an empty slot.
local function HandleExternalHide(stack, section)
  if stack.hidingSection == section or section.state == "hidden" then
    return
  end
  -- A parent hide (the stack itself) leaves the section's own flag set.
  if CallMethod(section.frame, "IsShown") == true then
    return
  end
  if section.state == "leaving" and not section.viaContainer then
    -- Its own fade-out ended with the real Hide(); onHidden follows.
    return
  end
  FinishSectionHidden(section)
  if not HasVisible(stack) then
    for _, other in pairs(stack.sections) do
      if other.state == "leaving" then
        stack.hidingSection = other
        CallMethod(other.frame, "Hide")
        stack.hidingSection = nil
        FinishSectionHidden(other)
      end
    end
    CallMethod(stack.container, "Hide")
  end
  Reflow(stack)
end

-- ---------------------------------------------------------------------------
-- Drag: any section moves the whole stack (not saved, rule 242).
-- ---------------------------------------------------------------------------

local function AttachDrag(stack, frame)
  CallMethod(frame, "SetMovable", true)
  CallMethod(frame, "EnableMouse", true)
  CallMethod(frame, "RegisterForDrag", "LeftButton")
  CallMethod(frame, "SetScript", "OnDragStart", function()
    CallMethod(stack.container, "StartMoving")
  end)
  CallMethod(frame, "SetScript", "OnDragStop", function()
    CallMethod(stack.container, "StopMovingOrSizing")
    -- The player chose this place: no screen fit moves it any more.
    stack.moved = true
  end)
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

-- The card and every child that sat on the card's old strata (close button,
-- teleport tile, option buttons) move to the stack's strata; otherwise they
-- would render below the stack's background.
local function MoveChildrenToStackStrata(frame, previousStrata)
  if previousStrata == nil or type(frame.GetChildren) ~= "function" then
    return
  end
  for _, child in ipairs({ frame:GetChildren() }) do
    if type(child) == "table" and CallMethod(child, "GetFrameStrata") == previousStrata then
      CallMethod(child, "SetFrameStrata", CardStack.FRAME_STRATA)
      MoveChildrenToStackStrata(child, previousStrata)
    end
  end
end

-- The card and all its children rise above the stack's background by the
-- same amount, so their order inside the card stays as it was.
local function ShiftFrameLevels(frame, delta)
  local level = tonumber(CallMethod(frame, "GetFrameLevel"))
  if level then
    CallMethod(frame, "SetFrameLevel", level + delta)
  end
  if type(frame.GetChildren) ~= "function" then
    return
  end
  for _, child in ipairs({ frame:GetChildren() }) do
    if type(child) == "table" then
      ShiftFrameLevels(child, delta)
    end
  end
end

local function RaiseAboveContainer(frame, container)
  local containerLevel = tonumber(CallMethod(container, "GetFrameLevel"))
  local level = tonumber(CallMethod(frame, "GetFrameLevel"))
  if containerLevel and level and level <= containerLevel then
    ShiftFrameLevels(frame, containerLevel + 1 - level)
  end
end

local function NewStack(parent)
  return {
    parent = parent,
    container = nil,
    sections = {},
    sequence = 0,
    width = nil,
    topOffset = CardStack.TOP_OFFSET,
    moved = false,
  }
end

local sharedStack = nil

--- The one stack every card joins. Created with its container on first use.
function CardStack.GetShared()
  if not sharedStack then
    sharedStack = NewStack(rawget(_G, "UIParent"))
  end
  return sharedStack
end

local function EnsureContainer(stack, frame)
  if stack.container then
    return stack.container
  end
  if stack.parent == nil then
    stack.parent = CallMethod(frame, "GetParent")
  end
  stack.container = CreateContainer(stack)
  if stack.container then
    ResetContainerPosition(stack)
  end
  return stack.container
end

--- Registers `frame` as the section `kind` of the shared stack.
--- opts: priority, preferredWidth, relayout(width), onRoleChanged(isLead),
--- onHidden(). Returns the section handle (Show, Hide, IsActive,
--- NotifyLayout, SetPreferredWidth, GetWidth) or nil without a container.
function CardStack.Register(kind, frame, opts)
  opts = opts or {}
  local stack = CardStack.GetShared()
  if type(frame) ~= "table" or type(kind) ~= "string" then
    return nil
  end
  local container = EnsureContainer(stack, frame)
  if not container then
    return nil
  end
  local section = {
    kind = kind,
    frame = frame,
    priority = tonumber(opts.priority) or CardStack.KIND_PRIORITY[kind] or DEFAULT_PRIORITY,
    preferredWidth = tonumber(opts.preferredWidth) or tonumber(CallMethod(frame, "GetWidth")) or 1,
    relayout = opts.relayout,
    onRoleChanged = opts.onRoleChanged,
    onHidden = opts.onHidden,
    state = "hidden",
    sequence = 0,
  }
  stack.sections[kind] = section
  local previousStrata = CallMethod(frame, "GetFrameStrata")
  CallMethod(frame, "SetParent", container)
  CallMethod(frame, "SetFrameStrata", CardStack.FRAME_STRATA)
  MoveChildrenToStackStrata(frame, previousStrata)
  RaiseAboveContainer(frame, container)
  CallMethod(frame, "Hide")
  AttachDrag(stack, frame)
  if type(frame.HookScript) == "function" then
    frame:HookScript("OnHide", function()
      HandleExternalHide(stack, section)
    end)
  end

  local handle = {}
  function handle.Show()
    ShowSection(stack, section)
  end
  function handle.Hide()
    HideSection(stack, section)
  end
  -- Visible or about to be (a fading-out section counts as gone).
  function handle.IsActive()
    return section.state == "visible"
  end
  -- The section's content changed its height (or width): re-stack.
  function handle.NotifyLayout()
    if not stack.reflowing and section.state ~= "hidden" then
      Reflow(stack)
    end
  end
  function handle.SetPreferredWidth(width)
    section.preferredWidth = tonumber(width) or section.preferredWidth
  end
  -- Width the section lays itself out with: the widest active card wins.
  function handle.GetWidth()
    local width = tonumber(section.preferredWidth) or 1
    for _, other in pairs(stack.sections) do
      if other ~= section and other.state == "visible" then
        width = math.max(width, tonumber(other.preferredWidth) or 0)
      end
    end
    section.appliedWidth = width
    return width
  end
  handle.frame = frame
  handle.kind = kind
  handle.container = container
  return handle
end

--- Kinds of the stacked sections from top to bottom (visible and leaving).
function CardStack.GetOrder()
  local stack = CardStack.GetShared()
  local order = {}
  for _, section in ipairs(CollectLaidOut(stack)) do
    order[#order + 1] = section.kind
  end
  return order
end

--- The stack container frame (nil before the first card registered).
function CardStack.GetContainer()
  return CardStack.GetShared().container
end

return CardStack
