-- Defensives column setting (rules 267-269), part of the display section: one
-- switch (Pattern B, schema default false) for the column, the DEF sync
-- between isiLive users and the estimate. It re-applies the runtime at once
-- (DefensiveRuntime.ApplySettings -> ctx.RefreshDefensiveTracker and a roster
-- render).
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
    desc = "Shows the group's defensives and externals in the key instead of DPS, shares yours with "
      .. "isiLive users and estimates the others (~).",
  },
}
SettingsDefensives.OPTIONS = OPTIONS

-- Restore-defaults value (Pattern B).
SettingsDefensives.DEFAULTS = {
  defensiveTrackerEnabled = false,
}

--- Runs the runtime refresh after a switch (no-op before the factory wired it).
function SettingsDefensives.ApplyRuntime()
  local runtime = addonTable.DefensiveRuntime
  if type(runtime) == "table" and type(runtime.ApplySettings) == "function" then
    pcall(runtime.ApplySettings)
  end
end

-- Literal Pattern B reads and writes per field (tools/check_settings_default_pattern.lua).
local READERS = {
  defensiveTrackerEnabled = function(db)
    return db.defensiveTrackerEnabled == true
  end,
}

local WRITERS = {
  defensiveTrackerEnabled = function(db, checked)
    db.defensiveTrackerEnabled = checked
  end,
}

--- Builds the block (separator + checkbox) into `controls`;
-- `describe(text)` returns the description options of the hosting section.
-- Returns the next yOffset.
function SettingsDefensives.Build(canvas, yOffset, labels, config, controls, describe)
  controls.defensiveSeparator, yOffset = CreateChildSeparator(canvas, yOffset)
  for _, option in ipairs(OPTIONS) do
    local checkbox
    checkbox, yOffset = CreateSettingsCheckbox(canvas, yOffset, labels[option.labelKey] or option.label, function()
      return READERS[option.field](config.getDB())
    end, function(checked)
      WRITERS[option.field](config.getDB(), checked == true)
      SettingsDefensives.ApplyRuntime()
    end, option.labelKey, describe(labels[option.descKey] or option.desc))
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
