local _, addonTable = ...
addonTable = addonTable or {}

-- General and ESC-menu settings sections, split out of
-- ui/isiLive_settings_sections.lua. SettingsSections re-exports the four
-- functions below under their original names, so ui/isiLive_settings.lua and
-- every other caller keep binding them through the SettingsSections facade.
local SettingsGeneral = {}
addonTable.SettingsGeneral = SettingsGeneral

local CreateSectionHeader = addonTable.SettingsControls.CreateSectionHeader
local CreateSectionNote = addonTable.SettingsControls.CreateSectionNote
local CreateSettingsCheckbox = addonTable.SettingsControls.CreateSettingsCheckbox
local CreateLanguageSelector = addonTable.SettingsControls.CreateLanguageSelector
local CreateSettingsOptionSelector = addonTable.SettingsControls.CreateSettingsOptionSelector
local CreateSettingsDropdownSelector = addonTable.SettingsControls.CreateSettingsDropdownSelector

local DEFAULT_LAYOUT_MODE_EXPANDED = "expanded"
local DEFAULT_LAYOUT_MODE_COMPACT_VERTICAL = "compact_vertical"
local DEFAULT_LAYOUT_MODE_COMPACT_HORIZONTAL = "compact_horizontal"
local DEFAULT_LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL = "compact_main_horizontal"
local DEFAULT_LAYOUT_MODE_COMPACT_HORIZONTAL_2_LEGACY = "compact_horizontal_2"
local DEFAULT_LAYOUT_MODE_LAST_USED = "last_used"
-- Same widths as the display section; every settings section module keeps its
-- own copy of these description helpers.
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

local function SetLocalizedText(control, labels, key, fallback)
  if control and type(control.SetText) == "function" then
    control:SetText(labels[key] or fallback)
  end
end

function SettingsGeneral.BuildGeneralSection(canvas, yOffset, labels, config, controls)
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

  return yOffset
end

function SettingsGeneral.BuildEscMenuSection(canvas, yOffset, labels, config, controls)
  controls.escMenuHeader, yOffset = CreateSectionHeader(canvas, yOffset, labels.SETTINGS_ESC_PANEL or "ESC Menu")
  if controls.escMenuHeader then
    controls.escMenuHeader._sectionKey = "SETTINGS_ESC_PANEL"
  end

  controls.escMenuHint, yOffset = CreateSectionNote(
    canvas,
    yOffset,
    labels.SETTINGS_ESC_PANEL_DESC or "Adds isiLive's shortcut panel to the ESC menu for quick access."
  )
  if controls.escMenuHint then
    controls.escMenuHint._sectionKey = "SETTINGS_ESC_PANEL"
  end

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

function SettingsGeneral.RefreshGeneralControls(controls, labels)
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
  if controls.defaultLayout then
    SetControlDescription(
      controls.defaultLayout,
      labels.SETTINGS_DEFAULT_OPEN_UI_DESC or "Chooses which main layout opens when isiLive is shown."
    )
    controls.defaultLayout.UpdateHighlight()
  end
end

function SettingsGeneral.RefreshEscMenuControls(controls, labels, db, config)
  if controls.escMenuHeader then
    controls.escMenuHeader:SetText(labels.SETTINGS_ESC_PANEL or "ESC Menu")
  end
  SetLocalizedText(
    controls.escMenuHint,
    labels,
    "SETTINGS_ESC_PANEL_DESC",
    "Adds isiLive's shortcut panel to the ESC menu for quick access."
  )
  if controls.escPanel then
    controls.escPanel.label:SetText(labels.SETTINGS_ESC_PANEL or "Show ESC Menu Shortcuts")
    SetCheckboxDescription(
      controls.escPanel,
      labels.SETTINGS_ESC_PANEL_DESC or "Adds isiLive's shortcut panel to the ESC menu for quick access."
    )
    controls.escPanel.check:SetChecked(db.showEscPanel ~= false)
  end
  if controls.hearthstoneSelect then
    controls.hearthstoneSelect.UpdateOptions(BuildHearthstoneSettingsOptions(config, labels))
  end
end
