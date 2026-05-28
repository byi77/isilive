local _, addonTable = ...

addonTable = addonTable or {}

local StatsBox = {}
addonTable.StatsBox = StatsBox

local ApplyBackdrop = addonTable.UICommon and addonTable.UICommon.ApplyBackdrop

local BOX_WIDTH = 177
local BOX_HEIGHT = 158
local LINE_HEIGHT = 16
local UPDATE_INTERVAL = 1
local DEFAULT_BG_ALPHA = 0
local BASE_FONT_SIZE = 14
local FONT_FLAGS = ""
local TEXT_SHADOW_COLOR = { 0, 0, 0, 0.9 }
local TEXT_SHADOW_OFFSET_X = 1
local TEXT_SHADOW_OFFSET_Y = -1
local LABEL_COLUMN_WIDTH = 35
local VALUE_COLUMN_WIDTH = 42
local PERCENT_COLUMN_WIDTH = 70
local LEFT_PADDING = 8
local RIGHT_PADDING = 8
local TOP_PADDING = 6
local BOTTOM_PADDING = 6
local COLUMN_GAP = 8
local VALUE_PERCENT_GAP = 6
local VALUE_ONLY_RIGHT_OFFSET = -(RIGHT_PADDING + PERCENT_COLUMN_WIDTH + VALUE_PERCENT_GAP)
local demoRows = nil

local STAT_STRENGTH = 1
local STAT_AGILITY = 2
local STAT_INTELLECT = 4

local PRIMARY_BY_CLASS = {
  DEATHKNIGHT = "strength",
  DEMONHUNTER = "agility",
  EVOKER = "intellect",
  HUNTER = "agility",
  MAGE = "intellect",
  PRIEST = "intellect",
  ROGUE = "agility",
  WARLOCK = "intellect",
  WARRIOR = "strength",
}

local PRIMARY_BY_SPEC_ID = {
  [65] = "intellect", -- Paladin: Holy
  [66] = "strength", -- Paladin: Protection
  [70] = "strength", -- Paladin: Retribution
  [102] = "intellect", -- Druid: Balance
  [103] = "agility", -- Druid: Feral
  [104] = "agility", -- Druid: Guardian
  [105] = "intellect", -- Druid: Restoration
  [262] = "intellect", -- Shaman: Elemental
  [263] = "agility", -- Shaman: Enhancement
  [264] = "intellect", -- Shaman: Restoration
  [268] = "agility", -- Monk: Brewmaster
  [269] = "agility", -- Monk: Windwalker
  [270] = "intellect", -- Monk: Mistweaver
}

local PRIMARY_STAT_INDEX = {
  strength = STAT_STRENGTH,
  agility = STAT_AGILITY,
  intellect = STAT_INTELLECT,
}

local LABELS = {
  strength = "Str",
  agility = "Agi",
  intellect = "Int",
  stamina = "Stam",
  crit = "Crit",
  haste = "Haste",
  mastery = "Mast",
  versatility = "Vers",
  leech = "Leech",
  speed = "Speed",
  durability = "Dur",
  avoidance = "Avoid",
}

local COLORS = {
  strength = { 1.00, 0.82, 0.00, 1 },
  agility = { 1.00, 0.82, 0.00, 1 },
  intellect = { 1.00, 0.82, 0.00, 1 },
  stamina = { 0.95, 0.95, 0.92, 1 },
  crit = { 1.00, 0.25, 0.25, 1 },
  haste = { 0.00, 0.44, 0.87, 1 },
  mastery = { 0.10, 1.00, 0.10, 1 },
  versatility = { 0.64, 0.21, 0.93, 1 },
  leech = { 1.00, 0.50, 0.00, 1 },
  speed = { 1.00, 0.82, 0.00, 1 },
  durability = { 0.25, 0.85, 1.00, 1 },
  avoidance = { 0.95, 0.95, 0.92, 1 },
}

local function GetDB()
  return rawget(_G, "IsiLiveDB")
end

local function ResolveEnabled()
  local db = GetDB()
  return type(db) == "table" and db.statsBoxEnabled == true
end

local function ResolveLocked()
  local db = GetDB()
  return type(db) == "table" and db.statsBoxLocked == true
end

local function ResolveBgAlpha()
  local db = GetDB()
  local alpha = type(db) == "table" and tonumber(db.statsBoxBgAlpha) or DEFAULT_BG_ALPHA
  if alpha == nil then
    return DEFAULT_BG_ALPHA
  end
  if alpha < 0 then
    return 0
  end
  if alpha > 1 then
    return 1
  end
  return alpha
end

local function ResolveFontSizeOffset()
  local db = GetDB()
  local offset = type(db) == "table" and tonumber(db.statsBoxFontSizeOffset) or 0
  if offset == nil then
    return 0
  end
  if offset < -3 then
    return -3
  end
  if offset > 3 then
    return 3
  end
  return math.floor(offset + 0.5)
end

local function ResolveDisplayMode()
  local db = GetDB()
  local mode = type(db) == "table" and db.statsBoxDisplayMode or nil
  if mode == "value" or mode == "percent" or mode == "both" then
    return mode
  end
  return "both"
end

local function ResolveOptionalRowEnabled(key)
  local db = GetDB()
  local option = ({
    leech = { field = "statsBoxShowLeech", default = true },
    speed = { field = "statsBoxShowSpeed", default = true },
    durability = { field = "statsBoxShowDurability", default = true },
    stamina = { field = "statsBoxShowStamina", default = false },
    avoidance = { field = "statsBoxShowAvoidance", default = false },
  })[key]
  if not option then
    return true
  end
  if type(db) ~= "table" then
    return option.default == true
  end
  local value = db[option.field]
  if value == nil then
    return option.default == true
  end
  return value == true
end

local function ScaleDimension(value, scale)
  return math.floor((value * scale) + 0.5)
end

local function ResolveLayout()
  local fontSize = BASE_FONT_SIZE + ResolveFontSizeOffset()
  local scale = fontSize / BASE_FONT_SIZE
  return {
    fontSize = fontSize,
    width = ScaleDimension(BOX_WIDTH, scale),
    height = ScaleDimension(BOX_HEIGHT, scale),
    lineHeight = ScaleDimension(LINE_HEIGHT, scale),
    labelWidth = ScaleDimension(LABEL_COLUMN_WIDTH, scale),
    valueWidth = ScaleDimension(VALUE_COLUMN_WIDTH, scale),
    percentWidth = ScaleDimension(PERCENT_COLUMN_WIDTH, scale),
    leftPadding = ScaleDimension(LEFT_PADDING, scale),
    rightPadding = ScaleDimension(RIGHT_PADDING, scale),
    topPadding = ScaleDimension(TOP_PADDING, scale),
    bottomPadding = ScaleDimension(BOTTOM_PADDING, scale),
    columnGap = ScaleDimension(COLUMN_GAP, scale),
    valuePercentGap = ScaleDimension(VALUE_PERCENT_GAP, scale),
  }
end

local function IsSecretValue(value)
  local isSecretValue = rawget(_G, "issecretvalue")
  if type(isSecretValue) ~= "function" then
    return false
  end
  local ok, result = pcall(isSecretValue, value)
  return ok and result == true
end

local function FormatPercent(value)
  if value == nil then
    return nil
  end
  local ok, formatted = pcall(string.format, "%.2f%%", value)
  if not ok then
    return nil
  end
  return formatted
end

local function ResolveLabel(key)
  return LABELS[key] or key
end

local function ReadPlainNumber(value)
  if IsSecretValue(value) then
    return nil
  end
  local ok, numberValue = pcall(tonumber, value)
  if not ok or IsSecretValue(numberValue) or type(numberValue) ~= "number" then
    return nil
  end
  return numberValue
end

local function ReadDisplayNumber(value, shouldRound)
  if IsSecretValue(value) then
    return value
  end
  value = ReadPlainNumber(value)
  if value == nil then
    return nil
  end
  if not shouldRound then
    return value
  end
  local ok, rounded = pcall(function()
    return math.floor(value + 0.5)
  end)
  if not ok or type(rounded) ~= "number" then
    return nil
  end
  return rounded
end

local function ReadUnitStat(statIndex, opts)
  local unitStat = opts.UnitStat or rawget(_G, "UnitStat")
  if type(unitStat) ~= "function" then
    return nil
  end
  local ok, _, effective = pcall(unitStat, "player", statIndex)
  if not ok then
    return nil
  end
  return ReadDisplayNumber(effective, true)
end

local function ReadCombatRatingBonus(globalName, opts)
  local ratingID = opts[globalName]
  if ratingID == nil then
    ratingID = rawget(_G, globalName)
  end
  local getCombatRatingBonus = opts.GetCombatRatingBonus or rawget(_G, "GetCombatRatingBonus")
  if type(getCombatRatingBonus) ~= "function" or ratingID == nil then
    return nil
  end
  local ok, value = pcall(getCombatRatingBonus, ratingID)
  if not ok then
    return nil
  end
  return ReadDisplayNumber(value, false)
end

local function ReadCombatRating(globalName, opts)
  local ratingID = opts[globalName]
  if ratingID == nil then
    ratingID = rawget(_G, globalName)
  end
  local getCombatRating = opts.GetCombatRating or rawget(_G, "GetCombatRating")
  if type(getCombatRating) ~= "function" or ratingID == nil then
    return nil
  end
  local ok, value = pcall(getCombatRating, ratingID)
  if not ok then
    return nil
  end
  return ReadDisplayNumber(value, true)
end

local function ReadNoArgNumber(fnName, opts)
  local fn = opts[fnName] or rawget(_G, fnName)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn)
  if not ok then
    return nil
  end
  return ReadDisplayNumber(value, false)
end

local function ReadDurabilityRow(opts)
  if not ResolveOptionalRowEnabled("durability") then
    return nil
  end
  local getInventoryItemDurability = opts.GetInventoryItemDurability or rawget(_G, "GetInventoryItemDurability")
  if type(getInventoryItemDurability) ~= "function" then
    return nil
  end

  local currentTotal = 0
  local maxTotal = 0
  for slot = 1, 19 do
    local ok, current, maximum = pcall(getInventoryItemDurability, slot)
    current = ok and ReadPlainNumber(current) or nil
    maximum = ok and ReadPlainNumber(maximum) or nil
    if current and maximum and maximum > 0 then
      currentTotal = currentTotal + current
      maxTotal = maxTotal + maximum
    end
  end
  if maxTotal <= 0 then
    return nil
  end
  return {
    key = "durability",
    label = ResolveLabel("durability"),
    valueText = string.format("%d", currentTotal),
    percent = (currentTotal / maxTotal) * 100,
  }
end

local function ReadPlayerSpellHaste(opts)
  local unitSpellHaste = opts.UnitSpellHaste or rawget(_G, "UnitSpellHaste")
  if type(unitSpellHaste) ~= "function" then
    return nil
  end
  local ok, value = pcall(unitSpellHaste, "player")
  value = ok and ReadDisplayNumber(value, false) or nil
  if value ~= nil then
    return value
  end
  ok, value = pcall(unitSpellHaste)
  if not ok then
    return nil
  end
  return ReadDisplayNumber(value, false)
end

local function ResolvePlayerClassToken(opts)
  local unitClass = opts.UnitClass or rawget(_G, "UnitClass")
  if type(unitClass) ~= "function" then
    return nil
  end
  local ok, _, classToken = pcall(unitClass, "player")
  if not ok or IsSecretValue(classToken) then
    return nil
  end
  classToken = ok and type(classToken) == "string" and classToken or nil
  if classToken == "" then
    return nil
  end
  return classToken
end

local function ResolvePlayerSpecID(opts)
  local getSpecialization = opts.GetSpecialization or rawget(_G, "GetSpecialization")
  local getSpecializationInfo = opts.GetSpecializationInfo or rawget(_G, "GetSpecializationInfo")
  if type(getSpecialization) ~= "function" or type(getSpecializationInfo) ~= "function" then
    return nil
  end
  local okSpec, specIndex = pcall(getSpecialization)
  specIndex = okSpec and ReadPlainNumber(specIndex) or nil
  if specIndex == nil then
    return nil
  end
  local okInfo, specID = pcall(getSpecializationInfo, specIndex)
  specID = okInfo and ReadPlainNumber(specID) or nil
  return specID
end

local function ResolvePrimaryStatKey(opts)
  local specID = ResolvePlayerSpecID(opts)
  if specID and PRIMARY_BY_SPEC_ID[specID] then
    return PRIMARY_BY_SPEC_ID[specID]
  end
  local classToken = ResolvePlayerClassToken(opts)
  return classToken and PRIMARY_BY_CLASS[classToken] or nil
end

local function BuildPrimaryStatRow(opts)
  local primaryKey = ResolvePrimaryStatKey(opts)
  local statIndex = primaryKey and PRIMARY_STAT_INDEX[primaryKey] or nil
  if not statIndex then
    return nil
  end
  local value = ReadUnitStat(statIndex, opts)
  if value == nil then
    return nil
  end
  return {
    key = primaryKey,
    label = ResolveLabel(primaryKey),
    value = value,
  }
end

function StatsBox.CollectPlayerStats(opts)
  opts = opts or {}
  if type(demoRows) == "table" then
    local rows = {}
    for index, row in ipairs(demoRows) do
      rows[index] = {
        key = row.key,
        label = row.label,
        value = row.value,
        valueText = row.valueText,
        percent = row.percent,
      }
    end
    return rows
  end

  local rows = {}
  local primaryRow = BuildPrimaryStatRow(opts)
  if primaryRow then
    rows[#rows + 1] = primaryRow
  end
  if ResolveOptionalRowEnabled("stamina") then
    local staminaValue = ReadUnitStat(3, opts)
    if staminaValue ~= nil then
      rows[#rows + 1] = {
        key = "stamina",
        label = ResolveLabel("stamina"),
        value = staminaValue,
      }
    end
  end

  local secondaryRows = {
    {
      key = "crit",
      label = ResolveLabel("crit"),
      value = ReadCombatRating("CR_CRIT_MELEE", opts),
      percent = ReadNoArgNumber("GetCritChance", opts),
    },
    {
      key = "haste",
      label = ResolveLabel("haste"),
      value = ReadCombatRating("CR_HASTE_MELEE", opts),
      percent = ReadPlayerSpellHaste(opts),
    },
    {
      key = "mastery",
      label = ResolveLabel("mastery"),
      value = ReadCombatRating("CR_MASTERY", opts),
      percent = ReadNoArgNumber("GetMasteryEffect", opts),
    },
    {
      key = "versatility",
      label = ResolveLabel("versatility"),
      value = ReadCombatRating("CR_VERSATILITY_DAMAGE_DONE", opts),
      percent = ReadCombatRatingBonus("CR_VERSATILITY_DAMAGE_DONE", opts),
    },
    {
      key = "leech",
      label = ResolveLabel("leech"),
      value = ResolveOptionalRowEnabled("leech") and ReadCombatRating("CR_LIFESTEAL", opts) or nil,
      percent = ResolveOptionalRowEnabled("leech") and ReadCombatRatingBonus("CR_LIFESTEAL", opts) or nil,
    },
    {
      key = "speed",
      label = ResolveLabel("speed"),
      value = ResolveOptionalRowEnabled("speed") and ReadCombatRating("CR_SPEED", opts) or nil,
      percent = ResolveOptionalRowEnabled("speed") and ReadCombatRatingBonus("CR_SPEED", opts) or nil,
    },
  }

  for _, row in ipairs(secondaryRows) do
    if row.value ~= nil then
      rows[#rows + 1] = row
    end
  end
  local durabilityRow = ReadDurabilityRow(opts)
  if durabilityRow then
    rows[#rows + 1] = durabilityRow
  end
  if ResolveOptionalRowEnabled("avoidance") then
    local avoidanceValue = ReadCombatRating("CR_AVOIDANCE", opts)
    if avoidanceValue ~= nil then
      rows[#rows + 1] = {
        key = "avoidance",
        label = ResolveLabel("avoidance"),
        value = avoidanceValue,
        percent = ReadCombatRatingBonus("CR_AVOIDANCE", opts),
      }
    end
  end
  return rows
end

local function FormatValue(value)
  if value == nil then
    return nil
  end
  if type(value) == "string" then
    return value
  end
  local ok, formatted = pcall(string.format, "%d", value)
  if not ok then
    return nil
  end
  return formatted
end

local function FormatRow(row)
  local mode = ResolveDisplayMode()
  local valueText = mode ~= "percent" and (row.valueText or FormatValue(row.value)) or nil
  local percentText = mode ~= "value" and FormatPercent(row.percent) or nil
  return valueText, percentText
end

local function MeasureFontStringWidth(fontString)
  if type(fontString) ~= "table" or type(fontString.GetStringWidth) ~= "function" then
    return nil
  end
  local ok, width = pcall(fontString.GetStringWidth, fontString)
  if not ok or width == nil or IsSecretValue(width) then
    return nil
  end

  local numberOk, numericWidth = pcall(tonumber, width)
  if not numberOk or numericWidth == nil or IsSecretValue(numericWidth) then
    return nil
  end

  local positiveOk, isPositive = pcall(function()
    return numericWidth > 0
  end)
  if positiveOk and isPositive then
    local ceilOk, ceiledWidth = pcall(math.ceil, numericWidth)
    if ceilOk and type(ceiledWidth) == "number" then
      return ceiledWidth
    end
  end
  return nil
end

local function ResolveFallbackColumnWidth(previousLayout, baseLayout, key)
  if type(previousLayout) == "table" and previousLayout.fontSize == baseLayout.fontSize then
    local width = previousLayout[key]
    if type(width) == "number" and width > 0 then
      return width
    end
  end
  return baseLayout[key]
end

local function ResolveContentFitLayout(baseLayout, lines, visibleCount, previousLayout)
  local labelWidth = 0
  local valueWidth = 0
  local percentWidth = 0
  local hasPercent = false
  for index = 1, visibleCount do
    local rowFrame = lines[index]
    if rowFrame then
      labelWidth = math.max(labelWidth, MeasureFontStringWidth(rowFrame.label) or 0)
      valueWidth = math.max(valueWidth, MeasureFontStringWidth(rowFrame.value) or 0)
      if rowFrame.percent and type(rowFrame.percent.IsShown) == "function" and rowFrame.percent:IsShown() then
        hasPercent = true
        percentWidth = math.max(percentWidth, MeasureFontStringWidth(rowFrame.percent) or 0)
      end
    end
  end

  if visibleCount <= 0 then
    labelWidth = 0
    valueWidth = 0
    percentWidth = 0
  else
    labelWidth = labelWidth > 0 and labelWidth or ResolveFallbackColumnWidth(previousLayout, baseLayout, "labelWidth")
    valueWidth = math.max(
      valueWidth > 0 and valueWidth or ResolveFallbackColumnWidth(previousLayout, baseLayout, "valueWidth"),
      baseLayout.valueWidth
    )
    if hasPercent then
      percentWidth = math.max(
        percentWidth > 0 and percentWidth or ResolveFallbackColumnWidth(previousLayout, baseLayout, "percentWidth"),
        baseLayout.percentWidth
      )
    else
      percentWidth = 0
    end
  end

  local width = baseLayout.leftPadding
    + labelWidth
    + baseLayout.columnGap
    + valueWidth
    + (hasPercent and (baseLayout.valuePercentGap + percentWidth) or 0)
    + baseLayout.rightPadding
  local height = baseLayout.topPadding + math.max(1, visibleCount) * baseLayout.lineHeight + baseLayout.bottomPadding

  local layout = {}
  for key, value in pairs(baseLayout) do
    layout[key] = value
  end
  layout.width = width
  layout.height = height
  layout.labelWidth = labelWidth
  layout.valueWidth = valueWidth
  layout.percentWidth = percentWidth
  layout.hasPercent = hasPercent
  return layout
end

local function SavePosition(frame)
  local db = GetDB()
  if type(db) ~= "table" or type(frame) ~= "table" or type(frame.GetPoint) ~= "function" then
    return
  end
  local point, _, relativePoint, x, y = frame:GetPoint()
  db.statsBoxPosition = {
    point = point or "CENTER",
    relativePoint = relativePoint or "CENTER",
    x = tonumber(x) or 320,
    y = tonumber(y) or 120,
  }
end

local function ApplyStoredPosition(frame, parent)
  local db = GetDB()
  local pos = type(db) == "table" and db.statsBoxPosition or nil
  if type(pos) ~= "table" or type(frame.ClearAllPoints) ~= "function" or type(frame.SetPoint) ~= "function" then
    return
  end
  if
    type(pos.point) ~= "string"
    or pos.point == ""
    or type(pos.relativePoint) ~= "string"
    or pos.relativePoint == ""
    or type(pos.x) ~= "number"
    or type(pos.y) ~= "number"
  then
    return
  end
  frame:ClearAllPoints()
  frame:SetPoint(pos.point, parent, pos.relativePoint, pos.x, pos.y)
end

local ApplyLayout

local function ResolveRenderableRow(rows, sourceIndex)
  while type(rows) == "table" and sourceIndex <= #rows do
    local row = rows[sourceIndex]
    if row then
      local valueText, percentText = FormatRow(row)
      if valueText ~= nil or percentText ~= nil then
        return row, valueText, percentText, sourceIndex + 1
      end
    end
    sourceIndex = sourceIndex + 1
  end
  return nil, nil, nil, sourceIndex
end

local function RenderRows(state, rows)
  rows = type(rows) == "table" and rows or {}
  local layout = state.baseLayout or ResolveLayout()
  local visibleCount = 0
  local sourceIndex = 1
  for index, rowFrame in ipairs(state.lines) do
    local row, valueText, percentText, nextSourceIndex = ResolveRenderableRow(rows, sourceIndex)
    sourceIndex = nextSourceIndex
    if row and (valueText ~= nil or percentText ~= nil) then
      visibleCount = index
      rowFrame.label:SetText(row.label)
      rowFrame.value:SetText(valueText or "")
      local c = COLORS[row.key] or COLORS.strength
      rowFrame.label:SetTextColor(c[1], c[2], c[3], c[4])
      rowFrame.value:SetTextColor(c[1], c[2], c[3], c[4])
      rowFrame.percent:SetTextColor(c[1], c[2], c[3], c[4])
      if percentText then
        rowFrame.percent:SetText("(" .. percentText .. ")")
        rowFrame.percent:Show()
      else
        rowFrame.percent:SetText("")
        rowFrame.percent:Hide()
      end
      rowFrame.label:Show()
      rowFrame.value:Show()
    else
      rowFrame.label:SetText("")
      rowFrame.value:SetText("")
      rowFrame.percent:SetText("")
      rowFrame.label:Hide()
      rowFrame.value:Hide()
      rowFrame.percent:Hide()
    end
  end
  ApplyLayout(state, ResolveContentFitLayout(layout, state.lines, visibleCount, state.layout))
end

ApplyLayout = function(state, layout)
  state.layout = layout
  state.frame:SetSize(layout.width, layout.height)
  for index, rowFrame in ipairs(state.lines) do
    local yOffset = -layout.topPadding - ((index - 1) * layout.lineHeight)
    rowFrame.label:ClearAllPoints()
    rowFrame.label:SetPoint("TOPLEFT", state.frame, "TOPLEFT", layout.leftPadding, yOffset)
    rowFrame.label:SetWidth(layout.labelWidth)
    rowFrame.value:ClearAllPoints()
    rowFrame.value:SetPoint(
      "TOPLEFT",
      state.frame,
      "TOPLEFT",
      layout.leftPadding + layout.labelWidth + layout.columnGap,
      yOffset
    )
    rowFrame.value:SetWidth(layout.valueWidth)
    rowFrame.percent:ClearAllPoints()
    rowFrame.percent:SetPoint(
      "TOPLEFT",
      state.frame,
      "TOPLEFT",
      layout.leftPadding + layout.labelWidth + layout.columnGap + layout.valueWidth + layout.valuePercentGap,
      yOffset
    )
    rowFrame.percent:SetWidth(layout.percentWidth)
  end
end

local function ApplyLineTextStyle(line, fontSize)
  if type(line.GetFont) == "function" and type(line.SetFont) == "function" then
    local fontPath = line:GetFont()
    if type(fontPath) == "string" and fontPath ~= "" then
      line:SetFont(fontPath, fontSize, FONT_FLAGS)
    end
  end
  if type(line.SetShadowColor) == "function" then
    line:SetShadowColor(TEXT_SHADOW_COLOR[1], TEXT_SHADOW_COLOR[2], TEXT_SHADOW_COLOR[3], TEXT_SHADOW_COLOR[4])
  end
  if type(line.SetShadowOffset) == "function" then
    line:SetShadowOffset(TEXT_SHADOW_OFFSET_X, TEXT_SHADOW_OFFSET_Y)
  end
end

function StatsBox.Create(opts)
  opts = opts or {}
  local parent = opts.parent or rawget(_G, "UIParent")
  if type(parent) ~= "table" then
    return nil
  end

  local createFrame = opts.CreateFrame or rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return nil
  end

  local frame = createFrame("Frame", "isiLiveStatsBox", parent, "BackdropTemplate")
  frame:SetSize(BOX_WIDTH, BOX_HEIGHT)
  frame:SetPoint("CENTER", parent, "CENTER", 320, 120)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetFrameStrata("MEDIUM")
  if type(frame.SetClampedToScreen) == "function" then
    frame:SetClampedToScreen(true)
  end
  if type(frame.SetClampRectInsets) == "function" then
    frame:SetClampRectInsets(0, 0, 0, 0)
  end
  if type(frame.SetBackdrop) == "function" then
    frame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    frame:SetBackdropColor(0, 0, 0, ResolveBgAlpha())
  elseif type(ApplyBackdrop) == "function" then
    ApplyBackdrop(frame, "BUTTON_BG")
  end

  local state = {
    frame = frame,
    lines = {},
    elapsed = 0,
    collectStats = opts.collectStats or StatsBox.CollectPlayerStats,
  }

  for index = 1, 10 do
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6 - ((index - 1) * LINE_HEIGHT))
    label:SetWidth(LABEL_COLUMN_WIDTH)
    label:SetJustifyH("RIGHT")
    label:SetText("")

    local value = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    value:SetPoint("TOPRIGHT", frame, "TOPRIGHT", VALUE_ONLY_RIGHT_OFFSET, -6 - ((index - 1) * LINE_HEIGHT))
    value:SetWidth(VALUE_COLUMN_WIDTH)
    value:SetJustifyH("RIGHT")
    value:SetText("")

    local percent = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    percent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -6 - ((index - 1) * LINE_HEIGHT))
    percent:SetWidth(PERCENT_COLUMN_WIDTH)
    percent:SetJustifyH("RIGHT")
    percent:SetText("")

    state.lines[index] = {
      label = label,
      value = value,
      percent = percent,
    }
  end

  local function Refresh()
    RenderRows(state, state.collectStats(opts))
  end

  local function ApplySettings()
    if type(frame.SetBackdropColor) == "function" then
      frame:SetBackdropColor(0, 0, 0, ResolveBgAlpha())
    end
    if type(frame.SetMovable) == "function" then
      frame:SetMovable(not ResolveLocked())
    end
    state.baseLayout = ResolveLayout()
    for _, rowFrame in ipairs(state.lines) do
      for _, line in ipairs({ rowFrame.label, rowFrame.value, rowFrame.percent }) do
        ApplyLineTextStyle(line, state.baseLayout.fontSize)
      end
    end
    Refresh()
    if ResolveEnabled() then
      frame:Show()
    else
      frame:Hide()
    end
  end

  frame:SetScript("OnDragStart", function(self)
    if ResolveLocked() then
      return
    end
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    if ResolveLocked() then
      return
    end
    self:StopMovingOrSizing()
    SavePosition(self)
  end)
  frame:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" then
      ApplyStoredPosition(frame, parent)
    end
    ApplySettings()
  end)
  frame:SetScript("OnUpdate", function(_, elapsed)
    state.elapsed = state.elapsed + (tonumber(elapsed) or 0)
    if state.elapsed < UPDATE_INTERVAL then
      return
    end
    state.elapsed = 0
    if frame:IsShown() then
      Refresh()
    end
  end)

  for _, event in ipairs({
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "UNIT_STATS",
    "COMBAT_RATING_UPDATE",
    "PLAYER_EQUIPMENT_CHANGED",
    "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED",
  }) do
    frame:RegisterEvent(event)
  end

  function state.SetEnabled(enabled)
    local db = GetDB()
    if type(db) == "table" then
      db.statsBoxEnabled = enabled ~= false
    end
    ApplySettings()
  end

  function state.SetLocked(locked)
    local db = GetDB()
    if type(db) == "table" then
      db.statsBoxLocked = locked == true
    end
    ApplySettings()
  end

  function state.SetBackgroundAlpha(alpha)
    local db = GetDB()
    if type(db) == "table" then
      db.statsBoxBgAlpha = tonumber(alpha) or DEFAULT_BG_ALPHA
    end
    ApplySettings()
  end

  function state.SetFontSizeOffset(offset)
    local db = GetDB()
    if type(db) == "table" then
      db.statsBoxFontSizeOffset = tonumber(offset) or 0
    end
    ApplySettings()
  end

  function state.ApplySettings()
    ApplySettings()
  end

  ApplySettings()

  return state
end

function StatsBox.SetEnabled(enabled)
  if StatsBox.instance and type(StatsBox.instance.SetEnabled) == "function" then
    StatsBox.instance.SetEnabled(enabled)
  end
end

function StatsBox.SetLocked(locked)
  if StatsBox.instance and type(StatsBox.instance.SetLocked) == "function" then
    StatsBox.instance.SetLocked(locked)
  end
end

function StatsBox.SetBackgroundAlpha(alpha)
  if StatsBox.instance and type(StatsBox.instance.SetBackgroundAlpha) == "function" then
    StatsBox.instance.SetBackgroundAlpha(alpha)
  end
end

function StatsBox.SetFontSizeOffset(offset)
  if StatsBox.instance and type(StatsBox.instance.SetFontSizeOffset) == "function" then
    StatsBox.instance.SetFontSizeOffset(offset)
  end
end

function StatsBox.ApplySettings()
  if StatsBox.instance and type(StatsBox.instance.ApplySettings) == "function" then
    StatsBox.instance.ApplySettings()
  end
end

function StatsBox.SetDemoData(rows)
  demoRows = type(rows) == "table" and rows or nil
  StatsBox.ApplySettings()
end

function StatsBox.ClearDemoData()
  demoRows = nil
  StatsBox.ApplySettings()
end

StatsBox.instance = StatsBox.Create()

return StatsBox
