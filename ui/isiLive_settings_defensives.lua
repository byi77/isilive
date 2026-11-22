-- Defensives column settings (rules 267-269), part of the display section:
-- the feature switch and, indented below it, the DEF sync between isiLive
-- users and the sensor estimate for members without isiLive. All three are
-- Pattern B (default off, schema default false). Every switch re-applies the
-- runtime at once (DefensiveRuntime.ApplySettings -> ctx.RefreshDefensiveTracker
-- and a roster render).
local _, addonTable = ...
addonTable = addonTable or {}

local SettingsDefensives = {}
addonTable.SettingsDefensives = SettingsDefensives

local CreateSettingsCheckbox = addonTable.SettingsControls.CreateSettingsCheckbox
local CreateChildSeparator = addonTable.SettingsControls.CreateChildSeparator

local OPTIONS = {
  {
    control = "defensiveTracker",
    field = "defensiveTrackerEnabled",
    labelKey = "SETTINGS_DEFENSIVE_TRACKER",
    label = "M+: Defensives column",
    descKey = "SETTINGS_DEFENSIVE_TRACKER_DESC",
    desc = "While a key runs, shows the group's defensives and externals in place of the DPS column.",
  },
  {
    control = "defensiveSync",
    field = "defensiveSyncEnabled",
    labelKey = "SETTINGS_DEFENSIVE_SYNC",
    label = "Share with isiLive users",
    descKey = "SETTINGS_DEFENSIVE_SYNC_DESC",
    desc = "Exchanges exact cooldowns with other isiLive users in the group.",
    child = true,
  },
  {
    control = "defensiveEstimate",
    field = "defensiveEstimateEnabled",
    labelKey = "SETTINGS_DEFENSIVE_ESTIMATE",
    label = "Estimate for players without isiLive",
    descKey = "SETTINGS_DEFENSIVE_ESTIMATE_DESC",
    desc = "Estimates from the buff start, marked with ~.",
    child = true,
  },
}
SettingsDefensives.OPTIONS = OPTIONS

-- Restore-defaults values (all Pattern B).
SettingsDefensives.DEFAULTS = {
  defensiveTrackerEnabled = false,
  defensiveSyncEnabled = false,
  defensiveEstimateEnabled = false,
}

--- Runs the runtime refresh after a switch (no-op before the factory wired it).
function SettingsDefensives.ApplyRuntime()
  local runtime = addonTable.DefensiveRuntime
  if type(runtime) == "table" and type(runtime.ApplySettings) == "function" then
    pcall(runtime.ApplySettings)
  end
end

local function Indent(canvas, checkbox, yOffset)
  local settingsSound = addonTable.SettingsSound
  if type(settingsSound) == "table" and type(settingsSound.IndentChildCheckbox) == "function" then
    settingsSound.IndentChildCheckbox(canvas, checkbox, yOffset)
  end
end

-- Literal Pattern B reads and writes per field (tools/check_settings_default_pattern.lua).
local READERS = {
  defensiveTrackerEnabled = function(db)
    return db.defensiveTrackerEnabled == true
  end,
  defensiveSyncEnabled = function(db)
    return db.defensiveSyncEnabled == true
  end,
  defensiveEstimateEnabled = function(db)
    return db.defensiveEstimateEnabled == true
  end,
}

local WRITERS = {
  defensiveTrackerEnabled = function(db, checked)
    db.defensiveTrackerEnabled = checked
  end,
  defensiveSyncEnabled = function(db, checked)
    db.defensiveSyncEnabled = checked
  end,
  defensiveEstimateEnabled = function(db, checked)
    db.defensiveEstimateEnabled = checked
  end,
}

--- Builds the block (separator + three checkboxes) into `controls`;
-- `describe(text)` returns the description options of the hosting section.
-- Returns the next yOffset.
function SettingsDefensives.Build(canvas, yOffset, labels, config, controls, describe)
  controls.defensiveSeparator, yOffset = CreateChildSeparator(canvas, yOffset)
  for _, option in ipairs(OPTIONS) do
    local rowY = yOffset
    local checkbox
    checkbox, yOffset = CreateSettingsCheckbox(canvas, yOffset, labels[option.labelKey] or option.label, function()
      return READERS[option.field](config.getDB())
    end, function(checked)
      WRITERS[option.field](config.getDB(), checked == true)
      SettingsDefensives.ApplyRuntime()
    end, option.labelKey, describe(labels[option.descKey] or option.desc))
    if option.child then
      Indent(canvas, checkbox, rowY)
    end
    controls[option.control] = checkbox
  end
  return yOffset
end

--- Repaints labels, descriptions and states (language switch, reset).
function SettingsDefensives.Refresh(controls, labels, db)
  for _, option in ipairs(OPTIONS) do
    local control = controls[option.control]
    if control then
      control.label:SetText(labels[option.labelKey] or option.label)
      if control.description and type(control.description.SetText) == "function" then
        control.description:SetText(labels[option.descKey] or option.desc)
      end
      control.check:SetChecked(READERS[option.field](db))
    end
  end
end
