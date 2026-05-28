local _, addonTable = ...
addonTable = addonTable or {}

local SettingsSections = {}
addonTable.SettingsSections = SettingsSections

local LFG_GROUP_BONUS_HEART_ICON = "|TInterface\\AddOns\\isiLive\\media\\heart_bonus_green:10:10:0:0|t"
local FALLBACK_LFG_GROUP_BONUSES_DESC = "Shows green hearts for relevant non-stacking class buffs:\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = one useful buff\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = two useful buffs\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = three useful buffs\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = four or more useful buffs\n"
  .. "Utility stays tooltip-only: BL, BR, PI, Devotion Aura,\n"
  .. "Atrophic Poison."

local DEFAULT_BG_ALPHA = addonTable.UICommon and addonTable.UICommon.DEFAULT_BG_ALPHA or 0.50

local CreateSectionHeader = addonTable.SettingsControls.CreateSectionHeader
local CreateChildSeparator = addonTable.SettingsControls.CreateChildSeparator
local CreateSectionNote = addonTable.SettingsControls.CreateSectionNote
local CreateSettingsCheckbox = addonTable.SettingsControls.CreateSettingsCheckbox
local CreateSettingsSlider = addonTable.SettingsControls.CreateSettingsSlider
local CreateLanguageSelector = addonTable.SettingsControls.CreateLanguageSelector
local CreateSettingsOptionSelector = addonTable.SettingsControls.CreateSettingsOptionSelector
local CreateSettingsDropdownSelector = addonTable.SettingsControls.CreateSettingsDropdownSelector

local SHOW_NAME_MAX_CHARS_SETTING = false
local SHOW_TELEPORT_COLUMNS_SETTING = false
local DEFAULT_LAYOUT_MODE_EXPANDED = "expanded"
local DEFAULT_LAYOUT_MODE_COMPACT_VERTICAL = "compact_vertical"
local DEFAULT_LAYOUT_MODE_COMPACT_HORIZONTAL = "compact_horizontal"
local DEFAULT_LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL = "compact_main_horizontal"
local DEFAULT_LAYOUT_MODE_COMPACT_HORIZONTAL_2_LEGACY = "compact_horizontal_2"
local DEFAULT_LAYOUT_MODE_LAST_USED = "last_used"
local DISPLAY_CHECKBOX_LABEL_WIDTH = 640
local DISPLAY_CHECKBOX_DESCRIPTION_WIDTH = 620

local function SettingDescriptionOptions(descriptionText, extra)
  extra = type(extra) == "table" and extra or {}
  return {
    width = extra.width or DISPLAY_CHECKBOX_LABEL_WIDTH,
    descriptionKey = extra.descriptionKey,
    descriptionText = descriptionText,
    descriptionWidth = DISPLAY_CHECKBOX_DESCRIPTION_WIDTH,
    descriptionWordWrap = true,
  }
end

local function SetControlDescription(control, text)
  if
    type(control) == "table"
    and type(control.description) == "table"
    and type(control.description.SetText) == "function"
  then
    control.description:SetText(text or "")
  end
end

local CheckboxDescriptionOptions = SettingDescriptionOptions
local SetCheckboxDescription = SetControlDescription

local STATS_BOX_SETTING_LABELS = {
  enUS = {
    enabled = "Show player stats box",
    locked = "Lock player stats box position",
    alpha = "Stats box background opacity",
    fontSize = "Stats box font size",
    displayMode = "Stats box numbers",
    leech = "Leech",
    speed = "Speed",
    durability = "Durability",
    stamina = "Stamina",
    avoidance = "Avoidance",
  },
  deDE = {
    enabled = "Statsbox anzeigen",
    locked = "Position der Statsbox sperren",
    alpha = "Hintergrund-Deckkraft der Statsbox",
    fontSize = "Schriftgroesse der Statsbox",
    displayMode = "Statsbox-Zahlen",
    leech = "Leech",
    speed = "Speed",
    durability = "Haltbarkeit",
    stamina = "Ausdauer",
    avoidance = "Vermeidung",
  },
}

local STATS_BOX_DISPLAY_MODE_OPTIONS = {
  {
    value = "both",
    labelKey = "SETTINGS_STATS_BOX_DISPLAY_MODE_BOTH",
    fallback = "Values + percentages",
    width = 142,
  },
  {
    value = "value",
    labelKey = "SETTINGS_STATS_BOX_DISPLAY_MODE_VALUE",
    fallback = "Values only",
    width = 94,
  },
  {
    value = "percent",
    labelKey = "SETTINGS_STATS_BOX_DISPLAY_MODE_PERCENT",
    fallback = "Percentages only",
    width = 122,
  },
}

local STATS_BOX_OPTIONAL_ROWS = {
  {
    control = "statsBoxShowLeech",
    field = "statsBoxShowLeech",
    labelKey = "leech",
    settingKey = "SETTINGS_STATS_BOX_SHOW_LEECH",
    default = true,
  },
  {
    control = "statsBoxShowSpeed",
    field = "statsBoxShowSpeed",
    labelKey = "speed",
    settingKey = "SETTINGS_STATS_BOX_SHOW_SPEED",
    default = true,
  },
  {
    control = "statsBoxShowDurability",
    field = "statsBoxShowDurability",
    labelKey = "durability",
    settingKey = "SETTINGS_STATS_BOX_SHOW_DURABILITY",
    default = true,
  },
  {
    control = "statsBoxShowStamina",
    field = "statsBoxShowStamina",
    labelKey = "stamina",
    settingKey = "SETTINGS_STATS_BOX_SHOW_STAMINA",
    default = false,
  },
  {
    control = "statsBoxShowAvoidance",
    field = "statsBoxShowAvoidance",
    labelKey = "avoidance",
    settingKey = "SETTINGS_STATS_BOX_SHOW_AVOIDANCE",
    default = false,
  },
}

local BuildHearthstoneSettingsOptions = addonTable.SettingsHearthstone
    and type(addonTable.SettingsHearthstone.BuildOptions) == "function"
    and addonTable.SettingsHearthstone.BuildOptions
  or function(_config, labels)
    labels = type(labels) == "table" and labels or {}
    return {
      {
        value = "random",
        fallback = labels.SETTINGS_HEARTHSTONE_RANDOM or "Random owned Hearthstone",
      },
      {
        value = "item:6948",
        fallback = labels.SETTINGS_HEARTHSTONE_DEFAULT or "Default Hearthstone (6948)",
      },
    }
  end

local function NormalizeStoredLayoutMode(layoutMode)
  if layoutMode == nil or layoutMode == false or layoutMode == "" then
    return DEFAULT_LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
  end
  if layoutMode == DEFAULT_LAYOUT_MODE_LAST_USED then
    return DEFAULT_LAYOUT_MODE_LAST_USED
  end
  if layoutMode == DEFAULT_LAYOUT_MODE_EXPANDED then
    return DEFAULT_LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
  end
  if layoutMode == DEFAULT_LAYOUT_MODE_COMPACT_HORIZONTAL_2_LEGACY then
    return DEFAULT_LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
  end
  if
    layoutMode == DEFAULT_LAYOUT_MODE_COMPACT_VERTICAL
    or layoutMode == DEFAULT_LAYOUT_MODE_COMPACT_HORIZONTAL
    or layoutMode == DEFAULT_LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
  then
    return layoutMode
  end
  return nil
end

local function ResolveSettingsLocale(config)
  local db = type(config.getDB) == "function" and config.getDB() or nil
  if type(db) == "table" and STATS_BOX_SETTING_LABELS[db.locale] then
    return db.locale
  end
  if type(config.getCurrentLocale) == "function" then
    local locale = config.getCurrentLocale()
    if STATS_BOX_SETTING_LABELS[locale] then
      return locale
    end
  end
  return "enUS"
end

local function GetStatsBoxSettingLabel(config, key)
  local labels = STATS_BOX_SETTING_LABELS[ResolveSettingsLocale(config)] or STATS_BOX_SETTING_LABELS.enUS
  return labels[key] or STATS_BOX_SETTING_LABELS.enUS[key] or key
end

local function NormalizeStatsBoxDisplayMode(mode)
  if mode == "value" or mode == "percent" or mode == "both" then
    return mode
  end
  return "both"
end

local function NotifyStatsBoxOptionsChanged(config)
  if type(config.onStatsBoxOptionsChange) == "function" then
    config.onStatsBoxOptionsChange()
  end
end

local function GetCVarEnabled(name)
  local getCVar = rawget(_G, "GetCVar")
  if type(getCVar) == "function" then
    return getCVar(name) == "1"
  end

  return false
end

local function SetCVarEnabled(name, checked)
  local setCVar = rawget(_G, "SetCVar")
  if type(setCVar) == "function" then
    setCVar(name, checked and "1" or "0")
  end
end

local function SetLocalizedText(control, labels, key, fallback)
  if control and type(control.SetText) == "function" then
    control:SetText(labels[key] or fallback)
  end
end

function SettingsSections.BuildGeneralSection(canvas, yOffset, labels, config, controls)
  controls.generalHeader, yOffset = CreateSectionHeader(canvas, yOffset, labels.SETTINGS_SECTION_GENERAL or "General")
  controls.generalHint, yOffset = CreateSectionNote(
    canvas,
    yOffset,
    labels.SETTINGS_SECTION_GENERAL_HINT or "Language, startup behavior, and utility links."
  )
  if controls.generalHint then
    controls.generalHint._sectionKey = "SETTINGS_SECTION_GENERAL"
  end

  controls.lang, yOffset = CreateLanguageSelector(
    canvas,
    yOffset,
    labels.SETTINGS_LANGUAGE or "Language",
    config.getCurrentLocale,
    config.setLanguage,
    SettingDescriptionOptions(labels.SETTINGS_LANGUAGE_DESC or "Changes the isiLive addon language.")
  )

  controls.defaultLayout, yOffset = CreateSettingsOptionSelector(
    canvas,
    yOffset,
    "SETTINGS_DEFAULT_OPEN_UI",
    labels.SETTINGS_DEFAULT_OPEN_UI or "Default UI on Open",
    {
      {
        value = DEFAULT_LAYOUT_MODE_LAST_USED,
        labelKey = "SETTINGS_DEFAULT_OPEN_UI_LAST",
        fallback = labels.SETTINGS_DEFAULT_OPEN_UI_LAST or "Last Used",
        width = 78,
      },
      {
        value = DEFAULT_LAYOUT_MODE_COMPACT_VERTICAL,
        labelKey = "SETTINGS_DEFAULT_OPEN_UI_V",
        fallback = labels.SETTINGS_DEFAULT_OPEN_UI_V or "V",
        width = 34,
      },
      {
        value = DEFAULT_LAYOUT_MODE_COMPACT_HORIZONTAL,
        labelKey = "SETTINGS_DEFAULT_OPEN_UI_H",
        fallback = labels.SETTINGS_DEFAULT_OPEN_UI_H or "H",
        width = 34,
      },
      {
        value = DEFAULT_LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL,
        labelKey = "SETTINGS_DEFAULT_OPEN_UI_M2",
        fallback = labels.SETTINGS_DEFAULT_OPEN_UI_M2 or "M+",
        width = 40,
      },
    },
    config.getL,
    function()
      local db = config.getDB()
      return NormalizeStoredLayoutMode(db.rosterDefaultLayoutMode)
    end,
    function(mode)
      local db = config.getDB()
      db.rosterDefaultLayoutMode = NormalizeStoredLayoutMode(mode)
      if type(config.onDefaultLayoutModeChange) == "function" then
        local callbackMode = db.rosterDefaultLayoutMode
        if callbackMode == DEFAULT_LAYOUT_MODE_LAST_USED then
          callbackMode = nil
        end
        config.onDefaultLayoutModeChange(callbackMode)
      end
    end,
    NormalizeStoredLayoutMode,
    true,
    SettingDescriptionOptions(
      labels.SETTINGS_DEFAULT_OPEN_UI_DESC or "Chooses which main layout opens when isiLive is shown.",
      { descriptionKey = "SETTINGS_DEFAULT_OPEN_UI_DESC" }
    )
  )

  controls.combatLog, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_COMBAT_LOGGING or "Advanced Combat Logging",
    function()
      return GetCVarEnabled("advancedCombatLogging")
    end,
    function(checked)
      SetCVarEnabled("advancedCombatLogging", checked)
    end,
    "SETTINGS_COMBAT_LOGGING",
    CheckboxDescriptionOptions(
      labels.SETTINGS_COMBAT_LOGGING_DESC or "Enables Blizzard's advanced combat log for external log analysis."
    )
  )

  controls.dmReset, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_DM_RESET or "Reset Blizzard Damage Meter on dungeon entry",
    function()
      return GetCVarEnabled("damageMeterResetOnNewInstance")
    end,
    function(checked)
      SetCVarEnabled("damageMeterResetOnNewInstance", checked)
    end,
    "SETTINGS_DM_RESET",
    CheckboxDescriptionOptions(
      labels.SETTINGS_DM_RESET_DESC or "Clears Blizzard's built-in damage meter when you enter a new dungeon."
    )
  )

  controls.escPanel, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_ESC_PANEL or "Show ESC Menu Shortcuts",
    function()
      local db = config.getDB()
      return db.showEscPanel ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.showEscPanel = checked
      if type(config.onEscPanelToggle) == "function" then
        config.onEscPanelToggle(checked)
      end
    end,
    "SETTINGS_ESC_PANEL",
    CheckboxDescriptionOptions(
      labels.SETTINGS_ESC_PANEL_DESC or "Adds isiLive's shortcut panel to the ESC menu for quick access."
    )
  )

  controls.portalNavigator, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_SHOW_TIMEWAYS_NAVIGATOR or "Show Timeways Navigator",
    function()
      local db = config.getDB()
      return db.showPortalNavigator ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.showPortalNavigator = checked
      if type(config.onPortalNavigatorToggle) == "function" then
        config.onPortalNavigatorToggle(checked)
      end
    end,
    "SETTINGS_SHOW_TIMEWAYS_NAVIGATOR",
    CheckboxDescriptionOptions(
      labels.SETTINGS_SHOW_TIMEWAYS_NAVIGATOR_DESC
        or "Shows the Timeways portal navigator when a known target dungeon can be resolved."
    )
  )

  controls.hearthstoneSelect, yOffset = CreateSettingsDropdownSelector(
    canvas,
    yOffset,
    "SETTINGS_HEARTHSTONE_SELECT",
    labels.SETTINGS_HEARTHSTONE_SELECT or "Hearthstone",
    BuildHearthstoneSettingsOptions(config, labels),
    config.getL,
    function()
      local db = config.getDB()
      return db.hearthstoneChoice or "random"
    end,
    function(val)
      local db = config.getDB()
      db.hearthstoneChoice = val
      if type(config.onHearthstoneChoiceChange) == "function" then
        config.onHearthstoneChoiceChange()
      end
    end,
    nil,
    false,
    {
      descriptionKey = "SETTINGS_HEARTHSTONE_SELECT_DESC",
      descriptionText = labels.SETTINGS_HEARTHSTONE_SELECT_DESC
        or "Choose which Hearthstone the ESC menu shortcut should use.",
      descriptionWidth = DISPLAY_CHECKBOX_DESCRIPTION_WIDTH,
      descriptionWordWrap = true,
    }
  )

  return yOffset
end

function SettingsSections.BuildDisplaySection(canvas, yOffset, labels, config, controls)
  controls.displayHeader, yOffset = CreateSectionHeader(canvas, yOffset, labels.SETTINGS_SECTION_DISPLAY or "Display")
  controls.displayHint, yOffset =
    CreateSectionNote(canvas, yOffset, labels.SETTINGS_SECTION_DISPLAY_HINT or "Scale, opacity, and UI recovery tools.")
  if controls.displayHint then
    controls.displayHint._sectionKey = "SETTINGS_SECTION_DISPLAY"
  end

  controls.uiScale, yOffset = CreateSettingsSlider(
    canvas,
    yOffset,
    labels.SETTINGS_UI_SCALE or "UI Scale",
    0.5,
    2.0,
    0.05,
    function()
      local db = config.getDB()
      return type(db.uiScale) == "number" and db.uiScale or 1.0
    end,
    function(val)
      local db = config.getDB()
      db.uiScale = val
      if type(config.onUiScaleChange) == "function" then
        config.onUiScaleChange(val)
      end
    end,
    function(val)
      return string.format("%.0f%%", val * 100)
    end,
    "SETTINGS_UI_SCALE",
    SettingDescriptionOptions(labels.SETTINGS_UI_SCALE_DESC or "Scales the main isiLive interface.")
  )

  controls.bgAlpha, yOffset = CreateSettingsSlider(
    canvas,
    yOffset,
    labels.SETTINGS_BG_ALPHA or "Background Opacity",
    0.3,
    1.0,
    0.05,
    function()
      local db = config.getDB()
      return type(db.bgAlpha) == "number" and db.bgAlpha or DEFAULT_BG_ALPHA
    end,
    function(val)
      local db = config.getDB()
      db.bgAlpha = val
      if type(config.onBgAlphaChange) == "function" then
        config.onBgAlphaChange(val)
      end
    end,
    function(val)
      return string.format("%.0f%%", val * 100)
    end,
    "SETTINGS_BG_ALPHA",
    SettingDescriptionOptions(labels.SETTINGS_BG_ALPHA_DESC or "Adjusts the background opacity of the main window.")
  )

  controls.statsBoxSeparator, yOffset = CreateChildSeparator(canvas, yOffset)

  controls.statsBoxEnabled, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    GetStatsBoxSettingLabel(config, "enabled"),
    function()
      local db = config.getDB()
      return db.statsBoxEnabled == true
    end,
    function(checked)
      local db = config.getDB()
      db.statsBoxEnabled = checked
      if type(config.onStatsBoxToggle) == "function" then
        config.onStatsBoxToggle(checked)
      end
    end,
    "SETTINGS_STATS_BOX_ENABLED",
    CheckboxDescriptionOptions(
      labels.SETTINGS_STATS_BOX_ENABLED_DESC or "Shows a separate movable box with your live player stats."
    )
  )

  controls.statsBoxLocked, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    GetStatsBoxSettingLabel(config, "locked"),
    function()
      local db = config.getDB()
      return db.statsBoxLocked == true
    end,
    function(checked)
      local db = config.getDB()
      db.statsBoxLocked = checked == true
      if type(config.onStatsBoxLockToggle) == "function" then
        config.onStatsBoxLockToggle(db.statsBoxLocked)
      end
    end,
    "SETTINGS_STATS_BOX_LOCKED",
    CheckboxDescriptionOptions(labels.SETTINGS_STATS_BOX_LOCKED_DESC or "Prevents dragging the player stats box.")
  )

  controls.statsBoxBgAlpha, yOffset = CreateSettingsSlider(
    canvas,
    yOffset,
    GetStatsBoxSettingLabel(config, "alpha"),
    0.0,
    1.0,
    0.05,
    function()
      local db = config.getDB()
      return type(db.statsBoxBgAlpha) == "number" and db.statsBoxBgAlpha or 0
    end,
    function(val)
      local db = config.getDB()
      db.statsBoxBgAlpha = val
      if type(config.onStatsBoxBgAlphaChange) == "function" then
        config.onStatsBoxBgAlphaChange(val)
      end
    end,
    function(val)
      return string.format("%.0f%%", val * 100)
    end,
    "SETTINGS_STATS_BOX_BG_ALPHA",
    SettingDescriptionOptions(
      labels.SETTINGS_STATS_BOX_BG_ALPHA_DESC or "Adjusts the player stats box background opacity."
    )
  )

  controls.statsBoxFontSizeOffset, yOffset = CreateSettingsSlider(
    canvas,
    yOffset,
    GetStatsBoxSettingLabel(config, "fontSize"),
    -3,
    3,
    1,
    function()
      local db = config.getDB()
      return type(db.statsBoxFontSizeOffset) == "number" and db.statsBoxFontSizeOffset or 0
    end,
    function(val)
      local db = config.getDB()
      db.statsBoxFontSizeOffset = math.floor((tonumber(val) or 0) + 0.5)
      if type(config.onStatsBoxFontSizeOffsetChange) == "function" then
        config.onStatsBoxFontSizeOffsetChange(db.statsBoxFontSizeOffset)
      end
    end,
    function(val)
      val = tonumber(val) or 0
      if val > 0 then
        return string.format("+%d", val)
      end
      return tostring(math.floor(val + 0.5))
    end,
    "SETTINGS_STATS_BOX_FONT_SIZE_OFFSET",
    SettingDescriptionOptions(
      labels.SETTINGS_STATS_BOX_FONT_SIZE_OFFSET_DESC or "Adjusts the player stats box text size."
    )
  )

  controls.statsBoxDisplayMode, yOffset = CreateSettingsOptionSelector(
    canvas,
    yOffset,
    "SETTINGS_STATS_BOX_DISPLAY_MODE",
    GetStatsBoxSettingLabel(config, "displayMode"),
    STATS_BOX_DISPLAY_MODE_OPTIONS,
    config.getL,
    function()
      local db = config.getDB()
      return NormalizeStatsBoxDisplayMode(db.statsBoxDisplayMode)
    end,
    function(mode)
      local db = config.getDB()
      db.statsBoxDisplayMode = NormalizeStatsBoxDisplayMode(mode)
      NotifyStatsBoxOptionsChanged(config)
    end,
    NormalizeStatsBoxDisplayMode,
    true,
    SettingDescriptionOptions(
      labels.SETTINGS_STATS_BOX_DISPLAY_MODE_DESC
        or "Chooses whether the stats box shows stat values, percentages, or both.",
      { descriptionKey = "SETTINGS_STATS_BOX_DISPLAY_MODE_DESC" }
    )
  )

  for _, option in ipairs(STATS_BOX_OPTIONAL_ROWS) do
    controls[option.control], yOffset = CreateSettingsCheckbox(
      canvas,
      yOffset,
      GetStatsBoxSettingLabel(config, option.labelKey),
      function()
        local db = config.getDB()
        local value = db[option.field]
        if value == nil then
          return option.default == true
        end
        return value == true
      end,
      function(checked)
        local db = config.getDB()
        db[option.field] = checked == true
        NotifyStatsBoxOptionsChanged(config)
      end,
      option.settingKey
    )
  end

  controls.displayExtrasSeparator, yOffset = CreateChildSeparator(canvas, yOffset)

  if SHOW_NAME_MAX_CHARS_SETTING then
    controls.nameMaxChars, yOffset = CreateSettingsSlider(
      canvas,
      yOffset,
      labels.SETTINGS_NAME_MAX_CHARS or "Name Length",
      4,
      20,
      1,
      function()
        local db = config.getDB()
        return type(db.nameMaxChars) == "number" and db.nameMaxChars or 10
      end,
      function(val)
        local db = config.getDB()
        db.nameMaxChars = math.floor(val + 0.5)
        if type(config.onNameMaxCharsChange) == "function" then
          config.onNameMaxCharsChange(db.nameMaxChars)
        end
      end,
      function(val)
        return string.format("%.0f", val)
      end,
      "SETTINGS_NAME_MAX_CHARS",
      SettingDescriptionOptions(labels.SETTINGS_NAME_MAX_CHARS_DESC or "Limits the displayed roster name length.")
    )
  end

  if SHOW_TELEPORT_COLUMNS_SETTING then
    controls.tpColumns, yOffset = CreateSettingsSlider(
      canvas,
      yOffset,
      labels.SETTINGS_TELEPORT_COLUMNS or "Teleport Grid Columns",
      2,
      8,
      1,
      function()
        local db = config.getDB()
        return type(db.teleportColumns) == "number" and db.teleportColumns or 4
      end,
      function(val)
        local db = config.getDB()
        db.teleportColumns = math.floor(val + 0.5)
        if type(config.onTeleportColumnsChange) == "function" then
          config.onTeleportColumnsChange(db.teleportColumns)
        end
      end,
      function(val)
        return string.format("%.0f", val)
      end,
      "SETTINGS_TELEPORT_COLUMNS",
      SettingDescriptionOptions(
        labels.SETTINGS_TELEPORT_COLUMNS_DESC or "Sets the number of columns in the teleport portal grid."
      )
    )
  end

  controls.minimapBtn, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_MINIMAP_BUTTON or "Minimap Button",
    function()
      local db = config.getDB()
      return db.showMinimapButton == true
    end,
    function(checked)
      local db = config.getDB()
      db.showMinimapButton = checked
      if type(config.onMinimapButtonToggle) == "function" then
        config.onMinimapButtonToggle(checked)
      end
    end,
    "SETTINGS_MINIMAP_BUTTON",
    CheckboxDescriptionOptions(labels.SETTINGS_MINIMAP_BUTTON_DESC or "Shows the isiLive minimap button.")
  )

  controls.lfgFlags, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_LFG_FLAGS or "Group Finder: Language Flags",
    function()
      local db = config.getDB()
      return db.lfgFlagsEnabled ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.lfgFlagsEnabled = checked
      if type(config.onLfgFlagsToggle) == "function" then
        config.onLfgFlagsToggle(checked)
      end
    end,
    "SETTINGS_LFG_FLAGS",
    CheckboxDescriptionOptions(labels.SETTINGS_LFG_FLAGS_DESC or "Shows leader language flags in Group Finder rows.")
  )

  controls.lfgGroupBonuses, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_LFG_GROUP_BONUSES or "Group Finder: Buff rating hearts",
    function()
      local db = config.getDB()
      return db.lfgGroupBonusesEnabled ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.lfgGroupBonusesEnabled = checked
      if type(config.onLfgGroupBonusesToggle) == "function" then
        config.onLfgGroupBonusesToggle(checked)
      end
    end,
    "SETTINGS_LFG_GROUP_BONUSES",
    CheckboxDescriptionOptions(labels.SETTINGS_LFG_GROUP_BONUSES_DESC or FALLBACK_LFG_GROUP_BONUSES_DESC)
  )

  controls.tooltipFlags, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_TOOLTIP_FLAGS or "Tooltip: Language Flags",
    function()
      local db = config.getDB()
      return db.tooltipFlagsEnabled ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.tooltipFlagsEnabled = checked
      if type(config.onTooltipFlagsToggle) == "function" then
        config.onTooltipFlagsToggle(checked)
      end
    end,
    "SETTINGS_TOOLTIP_FLAGS",
    CheckboxDescriptionOptions(labels.SETTINGS_TOOLTIP_FLAGS_DESC or "Shows language flags in player tooltips.")
  )

  controls.inviteHint, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_INVITE_HINT_ENABLED or "LFG invite hint",
    function()
      local db = config.getDB()
      return db.inviteHintEnabled ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.inviteHintEnabled = checked
    end,
    "SETTINGS_INVITE_HINT_ENABLED",
    CheckboxDescriptionOptions(
      labels.SETTINGS_INVITE_HINT_ENABLED_DESC or "Shows dungeon and group details when an LFG invite arrives."
    )
  )

  controls.acceptedInviteNotice, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_ACCEPTED_INVITE_NOTICE_ENABLED or "Accepted-invite notice",
    function()
      local db = config.getDB()
      return db.acceptedInviteNoticeEnabled ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.acceptedInviteNoticeEnabled = checked
    end,
    "SETTINGS_ACCEPTED_INVITE_NOTICE_ENABLED",
    CheckboxDescriptionOptions(
      labels.SETTINGS_ACCEPTED_INVITE_NOTICE_ENABLED_DESC or "Opens a compact reminder after accepting an invite."
    )
  )

  controls.groupJoinNotice, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_GROUP_JOIN_NOTICE_ENABLED or "Group-join target notice",
    function()
      local db = config.getDB()
      return db.groupJoinNoticeEnabled ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.groupJoinNoticeEnabled = checked
    end,
    "SETTINGS_GROUP_JOIN_NOTICE_ENABLED",
    CheckboxDescriptionOptions(
      labels.SETTINGS_GROUP_JOIN_NOTICE_ENABLED_DESC
        or "Shows the compact dungeon reminder when joining a group after an invite."
    )
  )

  return yOffset
end

function SettingsSections.RefreshGeneralControls(controls, labels, db, config)
  if controls.generalHeader then
    controls.generalHeader:SetText(labels.SETTINGS_SECTION_GENERAL or "General")
  end
  SetLocalizedText(
    controls.generalHint,
    labels,
    "SETTINGS_SECTION_GENERAL_HINT",
    "Language, startup behavior, and utility links."
  )
  if controls.lang then
    controls.lang.label:SetText(labels.SETTINGS_LANGUAGE or "Language")
    SetControlDescription(controls.lang, labels.SETTINGS_LANGUAGE_DESC or "Changes the isiLive addon language.")
    controls.lang.UpdateHighlight()
  end
  if controls.combatLog then
    controls.combatLog.label:SetText(labels.SETTINGS_COMBAT_LOGGING or "Advanced Combat Logging")
    SetCheckboxDescription(
      controls.combatLog,
      labels.SETTINGS_COMBAT_LOGGING_DESC or "Enables Blizzard's advanced combat log for external log analysis."
    )
    controls.combatLog.check:SetChecked(GetCVarEnabled("advancedCombatLogging"))
  end
  if controls.dmReset then
    controls.dmReset.label:SetText(labels.SETTINGS_DM_RESET or "Reset Blizzard Damage Meter on dungeon entry")
    SetCheckboxDescription(
      controls.dmReset,
      labels.SETTINGS_DM_RESET_DESC or "Clears Blizzard's built-in damage meter when you enter a new dungeon."
    )
    controls.dmReset.check:SetChecked(GetCVarEnabled("damageMeterResetOnNewInstance"))
  end
  if controls.escPanel then
    controls.escPanel.label:SetText(labels.SETTINGS_ESC_PANEL or "Show ESC Menu Shortcuts")
    SetCheckboxDescription(
      controls.escPanel,
      labels.SETTINGS_ESC_PANEL_DESC or "Adds isiLive's shortcut panel to the ESC menu for quick access."
    )
    controls.escPanel.check:SetChecked(db.showEscPanel ~= false)
  end
  if controls.portalNavigator then
    controls.portalNavigator.label:SetText(labels.SETTINGS_SHOW_TIMEWAYS_NAVIGATOR or "Show Timeways Navigator")
    SetCheckboxDescription(
      controls.portalNavigator,
      labels.SETTINGS_SHOW_TIMEWAYS_NAVIGATOR_DESC
        or "Shows the Timeways portal navigator when a known target dungeon can be resolved."
    )
    controls.portalNavigator.check:SetChecked(db.showPortalNavigator ~= false)
  end
  if controls.hearthstoneSelect then
    controls.hearthstoneSelect.UpdateOptions(BuildHearthstoneSettingsOptions(config, labels))
  end
  if controls.defaultLayout then
    SetControlDescription(
      controls.defaultLayout,
      labels.SETTINGS_DEFAULT_OPEN_UI_DESC or "Chooses which main layout opens when isiLive is shown."
    )
    controls.defaultLayout.UpdateHighlight()
  end
end

function SettingsSections.RefreshDisplayControls(controls, labels, db, config)
  if controls.displayHeader then
    controls.displayHeader:SetText(labels.SETTINGS_SECTION_DISPLAY or "Display")
  end
  SetLocalizedText(
    controls.displayHint,
    labels,
    "SETTINGS_SECTION_DISPLAY_HINT",
    "Scale, opacity, and UI recovery tools."
  )

  if controls.bgAlpha then
    controls.bgAlpha.label:SetText(labels.SETTINGS_BG_ALPHA or "Background Opacity")
    SetControlDescription(
      controls.bgAlpha,
      labels.SETTINGS_BG_ALPHA_DESC or "Adjusts the background opacity of the main window."
    )
    controls.bgAlpha.SetValueSilently(type(db.bgAlpha) == "number" and db.bgAlpha or DEFAULT_BG_ALPHA)
  end
  if controls.statsBoxEnabled and controls.statsBoxEnabled.label then
    controls.statsBoxEnabled.label:SetText(GetStatsBoxSettingLabel(config, "enabled")) -- i18n-ok
    SetControlDescription(
      controls.statsBoxEnabled,
      labels.SETTINGS_STATS_BOX_ENABLED_DESC or "Shows a separate movable box with your live player stats."
    )
    controls.statsBoxEnabled.check:SetChecked(db.statsBoxEnabled == true)
  end
  if controls.statsBoxLocked and controls.statsBoxLocked.label then
    controls.statsBoxLocked.label:SetText(GetStatsBoxSettingLabel(config, "locked")) -- i18n-ok
    SetControlDescription(
      controls.statsBoxLocked,
      labels.SETTINGS_STATS_BOX_LOCKED_DESC or "Prevents dragging the player stats box."
    )
    controls.statsBoxLocked.check:SetChecked(db.statsBoxLocked == true)
  end
  if controls.statsBoxBgAlpha and controls.statsBoxBgAlpha.label then
    controls.statsBoxBgAlpha.label:SetText(GetStatsBoxSettingLabel(config, "alpha")) -- i18n-ok
    SetControlDescription(
      controls.statsBoxBgAlpha,
      labels.SETTINGS_STATS_BOX_BG_ALPHA_DESC or "Adjusts the player stats box background opacity."
    )
    controls.statsBoxBgAlpha.SetValueSilently(type(db.statsBoxBgAlpha) == "number" and db.statsBoxBgAlpha or 0)
  end
  if controls.statsBoxFontSizeOffset and controls.statsBoxFontSizeOffset.label then
    controls.statsBoxFontSizeOffset.label:SetText(GetStatsBoxSettingLabel(config, "fontSize")) -- i18n-ok
    SetControlDescription(
      controls.statsBoxFontSizeOffset,
      labels.SETTINGS_STATS_BOX_FONT_SIZE_OFFSET_DESC or "Adjusts the player stats box text size."
    )
    controls.statsBoxFontSizeOffset.SetValueSilently(
      type(db.statsBoxFontSizeOffset) == "number" and db.statsBoxFontSizeOffset or 0
    )
  end
  if controls.statsBoxDisplayMode then
    SetControlDescription(
      controls.statsBoxDisplayMode,
      labels.SETTINGS_STATS_BOX_DISPLAY_MODE_DESC
        or "Chooses whether the stats box shows stat values, percentages, or both."
    )
    controls.statsBoxDisplayMode.UpdateHighlight()
  end
  for _, option in ipairs(STATS_BOX_OPTIONAL_ROWS) do
    local control = controls[option.control]
    if control and control.label then
      control.label:SetText(GetStatsBoxSettingLabel(config, option.labelKey)) -- i18n-ok
      local value = db[option.field]
      if value == nil then
        control.check:SetChecked(option.default == true)
      else
        control.check:SetChecked(value == true)
      end
    end
  end
  if controls.uiScale then
    controls.uiScale.label:SetText(labels.SETTINGS_UI_SCALE or "UI Scale")
    SetControlDescription(controls.uiScale, labels.SETTINGS_UI_SCALE_DESC or "Scales the main isiLive interface.")
    controls.uiScale.SetValueSilently(type(db.uiScale) == "number" and db.uiScale or 1.0)
  end
  if controls.minimapBtn then
    controls.minimapBtn.label:SetText(labels.SETTINGS_MINIMAP_BUTTON or "Minimap Button")
    SetCheckboxDescription(
      controls.minimapBtn,
      labels.SETTINGS_MINIMAP_BUTTON_DESC or "Shows the isiLive minimap button."
    )
    controls.minimapBtn.check:SetChecked(db.showMinimapButton == true)
  end
  if controls.nameMaxChars then
    controls.nameMaxChars.label:SetText(labels.SETTINGS_NAME_MAX_CHARS or "Name Length")
    SetControlDescription(
      controls.nameMaxChars,
      labels.SETTINGS_NAME_MAX_CHARS_DESC or "Limits the displayed roster name length."
    )
    controls.nameMaxChars.SetValueSilently(type(db.nameMaxChars) == "number" and db.nameMaxChars or 10)
  end
  if controls.tpColumns then
    controls.tpColumns.label:SetText(labels.SETTINGS_TELEPORT_COLUMNS or "Teleport Grid Columns")
    SetControlDescription(
      controls.tpColumns,
      labels.SETTINGS_TELEPORT_COLUMNS_DESC or "Sets the number of columns in the teleport portal grid."
    )
    controls.tpColumns.SetValueSilently(type(db.teleportColumns) == "number" and db.teleportColumns or 4)
  end
  if controls.lfgFlags then
    controls.lfgFlags.label:SetText(labels.SETTINGS_LFG_FLAGS or "Group Finder: Language Flags")
    SetCheckboxDescription(
      controls.lfgFlags,
      labels.SETTINGS_LFG_FLAGS_DESC or "Shows leader language flags in Group Finder rows."
    )
    controls.lfgFlags.check:SetChecked(db.lfgFlagsEnabled ~= false)
  end
  if controls.lfgGroupBonuses then
    controls.lfgGroupBonuses.label:SetText(labels.SETTINGS_LFG_GROUP_BONUSES or "Group Finder: Buff rating hearts")
    SetCheckboxDescription(
      controls.lfgGroupBonuses,
      labels.SETTINGS_LFG_GROUP_BONUSES_DESC or FALLBACK_LFG_GROUP_BONUSES_DESC
    )
    controls.lfgGroupBonuses.check:SetChecked(db.lfgGroupBonusesEnabled ~= false)
  end
  if controls.tooltipFlags then
    controls.tooltipFlags.label:SetText(labels.SETTINGS_TOOLTIP_FLAGS or "Tooltip: Language Flags")
    SetCheckboxDescription(
      controls.tooltipFlags,
      labels.SETTINGS_TOOLTIP_FLAGS_DESC or "Shows language flags in player tooltips."
    )
    controls.tooltipFlags.check:SetChecked(db.tooltipFlagsEnabled ~= false)
  end
  if controls.inviteHint then
    controls.inviteHint.label:SetText(labels.SETTINGS_INVITE_HINT_ENABLED or "LFG invite hint")
    SetCheckboxDescription(
      controls.inviteHint,
      labels.SETTINGS_INVITE_HINT_ENABLED_DESC or "Shows dungeon and group details when an LFG invite arrives."
    )
    controls.inviteHint.check:SetChecked(db.inviteHintEnabled ~= false)
  end
  if controls.acceptedInviteNotice then
    controls.acceptedInviteNotice.label:SetText(
      labels.SETTINGS_ACCEPTED_INVITE_NOTICE_ENABLED or "Accepted-invite notice"
    )
    SetCheckboxDescription(
      controls.acceptedInviteNotice,
      labels.SETTINGS_ACCEPTED_INVITE_NOTICE_ENABLED_DESC or "Opens a compact reminder after accepting an invite."
    )
    controls.acceptedInviteNotice.check:SetChecked(db.acceptedInviteNoticeEnabled ~= false)
  end
  if controls.groupJoinNotice then
    controls.groupJoinNotice.label:SetText(labels.SETTINGS_GROUP_JOIN_NOTICE_ENABLED or "Group-join target notice")
    SetCheckboxDescription(
      controls.groupJoinNotice,
      labels.SETTINGS_GROUP_JOIN_NOTICE_ENABLED_DESC
        or "Shows the compact dungeon reminder when joining a group after an invite."
    )
    controls.groupJoinNotice.check:SetChecked(db.groupJoinNoticeEnabled ~= false)
  end
end
