local _, addonTable = ...
addonTable = addonTable or {}

local SettingsNameplates = {}
addonTable.SettingsNameplates = SettingsNameplates

local Colors = addonTable.UICommon and addonTable.UICommon.Colors or {}
local PADDING_X = 16
local LINE_HEIGHT = 28
local DESCRIPTION_WIDTH = 620

local CreateSectionHeader = addonTable.SettingsControls.CreateSectionHeader
local CreateSectionNote = addonTable.SettingsControls.CreateSectionNote
local CreateSettingsCheckbox = addonTable.SettingsControls.CreateSettingsCheckbox
local CreateSettingsSlider = addonTable.SettingsControls.CreateSettingsSlider
local CreateSettingsOptionSelector = addonTable.SettingsControls.CreateSettingsOptionSelector

local NAMEPLATE_POSITIONS = { "LEFT", "RIGHT", "TOP", "BOTTOM" }

local function DescriptionOptions(descriptionText, descriptionKey)
  return {
    descriptionKey = descriptionKey,
    descriptionText = descriptionText,
    descriptionWidth = DESCRIPTION_WIDTH,
    descriptionWordWrap = true,
  }
end

local function NormalizeNameplatePosition(val)
  if type(val) == "string" then
    for _, p in ipairs(NAMEPLATE_POSITIONS) do
      if val == p then
        return p
      end
    end
  end
  return "RIGHT"
end

local MPLUS_FORCES_MODES = { "off", "tooltip", "nameplate" }

local function NormalizeMplusForcesMode(val)
  if type(val) == "string" then
    for _, m in ipairs(MPLUS_FORCES_MODES) do
      if val == m then
        return m
      end
    end
  end
  -- Default aligned with ResolveMplusForcesModeFromDB fresh-install branch.
  return "nameplate"
end

local function ResolveMplusForcesModeFromDB(db)
  if type(db) ~= "table" then
    return "nameplate"
  end
  if db.mobNameplateEnabled == true then
    return "nameplate"
  end
  if db.mplusForcesEstimate == true then
    return "tooltip"
  end
  if db.mobNameplateEnabled == nil and db.mplusForcesEstimate == nil then
    -- Fresh install: nameplate overlay is ON by default so the M+ forces
    -- percent appears in keys without a manual setup step.
    -- The factory migration writes the same default into the DB once.
    return "nameplate"
  end
  return "off"
end

local function IsExternalNameplateAddonLoaded()
  local cAddOns = rawget(_G, "C_AddOns")
  local isLoaded = nil
  if type(cAddOns) == "table" and type(cAddOns.IsAddOnLoaded) == "function" then
    isLoaded = function(name)
      local ok, loaded = pcall(cAddOns.IsAddOnLoaded, name)
      return ok and loaded == true
    end
  else
    local legacy = rawget(_G, "IsAddOnLoaded")
    if type(legacy) == "function" then
      isLoaded = function(name)
        local ok, loaded = pcall(legacy, name)
        return ok and loaded == true
      end
    end
  end
  if not isLoaded then
    return false
  end
  return isLoaded("Plater") or isLoaded("Platynator")
end

function SettingsNameplates.BuildSection(canvas, yOffset, labels, config, controls)
  controls.nameplatesHeader, yOffset =
    CreateSectionHeader(canvas, yOffset, labels.SETTINGS_SECTION_NAMEPLATES or "Nameplates")
  controls.nameplatesHint, yOffset = CreateSectionNote(
    canvas,
    yOffset,
    labels.SETTINGS_SECTION_NAMEPLATES_HINT or "Enemy forces overlay on Mythic+ nameplates."
  )
  if controls.nameplatesHint then
    controls.nameplatesHint._sectionKey = "SETTINGS_SECTION_NAMEPLATES"
  end

  if IsExternalNameplateAddonLoaded() then
    controls.nameplatesExternalWarn, yOffset = CreateSectionNote(
      canvas,
      yOffset,
      labels.SETTINGS_NAMEPLATE_EXTERNAL_WARN
        or "Plater or Platynator detected: if that addon already shows M+ count, leave this off."
    )
    if controls.nameplatesExternalWarn then
      controls.nameplatesExternalWarn._sectionKey = "SETTINGS_NAMEPLATE_EXTERNAL_WARN"
    end
  end

  controls.nameplateDisplayMode, yOffset = CreateSettingsOptionSelector(
    canvas,
    yOffset,
    "SETTINGS_MPLUS_FORCES_DISPLAY_MODE",
    labels.SETTINGS_MPLUS_FORCES_DISPLAY_MODE or "Display mode",
    {
      {
        value = "off",
        labelKey = "SETTINGS_MPLUS_FORCES_MODE_OFF",
        fallback = labels.SETTINGS_MPLUS_FORCES_MODE_OFF or "Off",
        width = 70,
      },
      {
        value = "tooltip",
        labelKey = "SETTINGS_MPLUS_FORCES_MODE_TOOLTIP",
        fallback = labels.SETTINGS_MPLUS_FORCES_MODE_TOOLTIP or "Tooltip",
        width = 90,
      },
      {
        value = "nameplate",
        labelKey = "SETTINGS_MPLUS_FORCES_MODE_NAMEPLATE",
        fallback = labels.SETTINGS_MPLUS_FORCES_MODE_NAMEPLATE or "Nameplate",
        width = 100,
      },
    },
    config.getL,
    function()
      return ResolveMplusForcesModeFromDB(config.getDB())
    end,
    function(mode)
      mode = NormalizeMplusForcesMode(mode)
      local db = config.getDB()
      db.mplusForcesEstimate = (mode == "tooltip")
      db.mobNameplateEnabled = (mode == "nameplate")
      if type(config.onMplusForcesToggle) == "function" then
        config.onMplusForcesToggle(db.mplusForcesEstimate == true)
      end
      if type(config.onMobNameplateChange) == "function" then
        config.onMobNameplateChange()
      end
      if type(controls.nameplatePreviewUpdate) == "function" then
        controls.nameplatePreviewUpdate()
      end
    end,
    NormalizeMplusForcesMode,
    true,
    DescriptionOptions(
      labels.SETTINGS_MPLUS_FORCES_DISPLAY_MODE_DESC or "Chooses where Mythic+ enemy forces progress is shown.",
      "SETTINGS_MPLUS_FORCES_DISPLAY_MODE_DESC"
    )
  )

  controls.nameplateShowPercent, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_NAMEPLATE_SHOW_PERCENT or "Show percentage",
    function()
      return config.getDB().mobNameplateShowPercent ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.mobNameplateShowPercent = checked
      if type(config.onMobNameplateChange) == "function" then
        config.onMobNameplateChange()
      end
      if type(controls.nameplatePreviewUpdate) == "function" then
        controls.nameplatePreviewUpdate()
      end
    end,
    "SETTINGS_NAMEPLATE_SHOW_PERCENT",
    DescriptionOptions(
      labels.SETTINGS_NAMEPLATE_SHOW_PERCENT_DESC or "Shows each mob's contribution as a percentage.",
      "SETTINGS_NAMEPLATE_SHOW_PERCENT_DESC"
    )
  )

  controls.nameplateShowRemaining, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_NAMEPLATE_SHOW_REMAINING or "Show remaining needed",
    function()
      return config.getDB().mobNameplateShowRemaining ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.mobNameplateShowRemaining = checked
      if type(config.onMobNameplateChange) == "function" then
        config.onMobNameplateChange()
      end
      if type(controls.nameplatePreviewUpdate) == "function" then
        controls.nameplatePreviewUpdate()
      end
    end,
    "SETTINGS_NAMEPLATE_SHOW_REMAINING",
    DescriptionOptions(
      labels.SETTINGS_NAMEPLATE_SHOW_REMAINING_DESC
        or "Adds the remaining enemy forces needed when live dungeon data is available.",
      "SETTINGS_NAMEPLATE_SHOW_REMAINING_DESC"
    )
  )

  controls.nameplateFontSize, yOffset = CreateSettingsSlider(
    canvas,
    yOffset,
    labels.SETTINGS_NAMEPLATE_FONT_SIZE or "Font size",
    8,
    28,
    1,
    function()
      return tonumber(config.getDB().mobNameplateFontSize) or 14
    end,
    function(val)
      local db = config.getDB()
      db.mobNameplateFontSize = tonumber(val) or 14
      if type(config.onMobNameplateChange) == "function" then
        config.onMobNameplateChange()
      end
      if type(controls.nameplatePreviewUpdate) == "function" then
        controls.nameplatePreviewUpdate()
      end
    end,
    function(val)
      return string.format("%d", val)
    end,
    "SETTINGS_NAMEPLATE_FONT_SIZE",
    DescriptionOptions(
      labels.SETTINGS_NAMEPLATE_FONT_SIZE_DESC or "Adjusts the enemy forces text size on nameplates.",
      "SETTINGS_NAMEPLATE_FONT_SIZE_DESC"
    )
  )

  controls.nameplatePosition, yOffset = CreateSettingsOptionSelector(
    canvas,
    yOffset,
    "SETTINGS_NAMEPLATE_POSITION",
    labels.SETTINGS_NAMEPLATE_POSITION or "Position",
    {
      {
        value = "LEFT",
        labelKey = "SETTINGS_NAMEPLATE_POS_LEFT",
        fallback = labels.SETTINGS_NAMEPLATE_POS_LEFT or "Left",
        width = 70,
      },
      {
        value = "RIGHT",
        labelKey = "SETTINGS_NAMEPLATE_POS_RIGHT",
        fallback = labels.SETTINGS_NAMEPLATE_POS_RIGHT or "Right",
        width = 70,
      },
      {
        value = "TOP",
        labelKey = "SETTINGS_NAMEPLATE_POS_TOP",
        fallback = labels.SETTINGS_NAMEPLATE_POS_TOP or "Top",
        width = 70,
      },
      {
        value = "BOTTOM",
        labelKey = "SETTINGS_NAMEPLATE_POS_BOTTOM",
        fallback = labels.SETTINGS_NAMEPLATE_POS_BOTTOM or "Bottom",
        width = 70,
      },
    },
    config.getL,
    function()
      return NormalizeNameplatePosition(config.getDB().mobNameplatePosition)
    end,
    function(pos)
      local db = config.getDB()
      db.mobNameplatePosition = NormalizeNameplatePosition(pos)
      if type(config.onMobNameplateChange) == "function" then
        config.onMobNameplateChange()
      end
      if type(controls.nameplatePreviewUpdate) == "function" then
        controls.nameplatePreviewUpdate()
      end
    end,
    NormalizeNameplatePosition,
    true,
    DescriptionOptions(
      labels.SETTINGS_NAMEPLATE_POSITION_DESC or "Places the enemy forces text around each nameplate.",
      "SETTINGS_NAMEPLATE_POSITION_DESC"
    )
  )

  controls.nameplateXOffset, yOffset = CreateSettingsSlider(
    canvas,
    yOffset,
    labels.SETTINGS_NAMEPLATE_X_OFFSET or "X offset",
    -50,
    50,
    1,
    function()
      return tonumber(config.getDB().mobNameplateXOffset) or 0
    end,
    function(val)
      local db = config.getDB()
      db.mobNameplateXOffset = tonumber(val) or 0
      if type(config.onMobNameplateChange) == "function" then
        config.onMobNameplateChange()
      end
      if type(controls.nameplatePreviewUpdate) == "function" then
        controls.nameplatePreviewUpdate()
      end
    end,
    function(val)
      return string.format("%d", val)
    end,
    "SETTINGS_NAMEPLATE_X_OFFSET",
    DescriptionOptions(
      labels.SETTINGS_NAMEPLATE_X_OFFSET_DESC or "Moves the nameplate enemy forces text horizontally.",
      "SETTINGS_NAMEPLATE_X_OFFSET_DESC"
    )
  )

  controls.nameplateYOffset, yOffset = CreateSettingsSlider(
    canvas,
    yOffset,
    labels.SETTINGS_NAMEPLATE_Y_OFFSET or "Y offset",
    -50,
    50,
    1,
    function()
      return tonumber(config.getDB().mobNameplateYOffset) or 0
    end,
    function(val)
      local db = config.getDB()
      db.mobNameplateYOffset = tonumber(val) or 0
      if type(config.onMobNameplateChange) == "function" then
        config.onMobNameplateChange()
      end
      if type(controls.nameplatePreviewUpdate) == "function" then
        controls.nameplatePreviewUpdate()
      end
    end,
    function(val)
      return string.format("%d", val)
    end,
    "SETTINGS_NAMEPLATE_Y_OFFSET",
    DescriptionOptions(
      labels.SETTINGS_NAMEPLATE_Y_OFFSET_DESC or "Moves the nameplate enemy forces text vertically.",
      "SETTINGS_NAMEPLATE_Y_OFFSET_DESC"
    )
  )

  yOffset = yOffset - 4

  local previewLabel = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local tnPreview = Colors.TEXT_NORMAL or { 0.85, 0.85, 0.9 }
  previewLabel:SetTextColor(tnPreview[1], tnPreview[2], tnPreview[3], 1)
  previewLabel:SetPoint("TOPLEFT", canvas, "TOPLEFT", PADDING_X, yOffset - 6)
  previewLabel:SetText(labels.SETTINGS_NAMEPLATE_PREVIEW or "Preview")
  controls.nameplatePreviewLabel = previewLabel

  local preview = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
  preview:SetSize(140, 24)
  preview:SetPoint("TOPLEFT", canvas, "TOPLEFT", PADDING_X + 160, yOffset - 4)
  if type(preview.SetBackdrop) == "function" then
    preview:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    if type(preview.SetBackdropColor) == "function" then
      preview:SetBackdropColor(0.55, 0.12, 0.12, 0.75)
    end
    if type(preview.SetBackdropBorderColor) == "function" then
      preview:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.9)
    end
  end

  preview.name = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmallOutline")
  preview.name:SetPoint("CENTER", preview, "CENTER", 0, 0)
  preview.name:SetText(labels.SETTINGS_NAMEPLATE_PREVIEW_MOB or "Test Mob")
  if type(preview.name.SetTextColor) == "function" then
    preview.name:SetTextColor(1, 1, 1, 1)
  end

  preview.overlay = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
  if type(preview.overlay.SetTextColor) == "function" then
    preview.overlay:SetTextColor(1, 1, 1, 1)
  end
  controls.nameplatePreview = preview

  local function UpdatePreview()
    local db = config.getDB()
    local enabled = db.mobNameplateEnabled == true
    if not enabled then
      preview.overlay:SetText("")
      if type(preview.overlay.Hide) == "function" then
        preview.overlay:Hide()
      end
      return
    end

    local showPercent = db.mobNameplateShowPercent ~= false
    local parts = {}
    if showPercent then
      local text = "1.16%"
      if db.mobNameplateShowRemaining ~= false then
        text = text .. "/24.34%"
      end
      parts[#parts + 1] = text
    end
    if #parts == 0 then
      preview.overlay:SetText("")
      if type(preview.overlay.Hide) == "function" then
        preview.overlay:Hide()
      end
      return
    end

    preview.overlay:SetText(table.concat(parts, " | "))
    if type(preview.overlay.Show) == "function" then
      preview.overlay:Show()
    end

    local pos = NormalizeNameplatePosition(db.mobNameplatePosition)
    local xo = tonumber(db.mobNameplateXOffset) or 0
    local yo = tonumber(db.mobNameplateYOffset) or 0
    if type(preview.overlay.ClearAllPoints) == "function" then
      preview.overlay:ClearAllPoints()
    end
    if pos == "LEFT" then
      preview.overlay:SetPoint("RIGHT", preview, "LEFT", xo, yo)
    elseif pos == "TOP" then
      preview.overlay:SetPoint("BOTTOM", preview, "TOP", xo, yo)
    elseif pos == "BOTTOM" then
      preview.overlay:SetPoint("TOP", preview, "BOTTOM", xo, yo)
    else
      preview.overlay:SetPoint("LEFT", preview, "RIGHT", xo, yo)
    end

    local fontSize = tonumber(db.mobNameplateFontSize) or 14
    if type(preview.overlay.GetFont) == "function" and type(preview.overlay.SetFont) == "function" then
      local fontPath, _, flags = preview.overlay:GetFont()
      if type(fontPath) ~= "string" or fontPath == "" then
        fontPath = "Fonts\\FRIZQT__.TTF"
      end
      preview.overlay:SetFont(fontPath, fontSize, flags or "OUTLINE")
    end
  end

  controls.nameplatePreviewUpdate = UpdatePreview
  UpdatePreview()

  yOffset = yOffset - (LINE_HEIGHT + 16)

  return yOffset
end
