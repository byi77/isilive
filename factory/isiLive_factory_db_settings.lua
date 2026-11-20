local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

-- SavedVariables settings of the composition root: the one-time IsiLiveDB
-- migrations (settings Pattern C, see CLAUDE.md) and the push of the stored
-- values into the feature modules. tools/check_settings_default_pattern.lua
-- reads the migrations from this file.

-- Pushes the persisted nameplate format and appearance into MobNameplate;
-- shared by the ADDON_LOADED re-apply and the live settings callback.
local function ApplyMobNameplateDisplaySettings(mobNameplate, db)
  if type(mobNameplate.SetFormat) == "function" then
    mobNameplate.SetFormat({
      showPercent = db.mobNameplateShowPercent ~= false,
      showRemaining = db.mobNameplateShowRemaining == true,
    })
  end
  if type(mobNameplate.SetAppearance) == "function" then
    mobNameplate.SetAppearance({
      fontSize = tonumber(db.mobNameplateFontSize) or 14,
      position = type(db.mobNameplatePosition) == "string" and db.mobNameplatePosition or "RIGHT",
      xOffset = tonumber(db.mobNameplateXOffset) or 0,
      yOffset = tonumber(db.mobNameplateYOffset) or 0,
    })
  end
end

-- One-time migrations and persisted defaults. Mutates db in place.
local function MigrateDBSettings(db)
  -- Legacy cascade fix: pre-nameplate users only ever persisted
  -- mplusForcesEstimate=true. DBSchema.Sanitize now fills the schema
  -- default mobNameplateEnabled=true before this runs, so both flags
  -- end up true and the nameplate + tooltip modules both activate.
  -- The settings UI enforces mutual exclusion (only one of the two
  -- can become true via the display-mode selector), so both=true is
  -- only reachable from the legacy path. Disambiguate to tooltip-only
  -- to honour the user's prior choice.
  if db.mobNameplateEnabled == true and db.mplusForcesEstimate == true then
    db.mobNameplateEnabled = false
  end

  -- Fallback for callers that exercise ApplyDBSettings without the
  -- ADDON_LOADED schema pass. Production migration runs in DBSchema
  -- before default values fill the split fields.
  if db.autoCloseMainFrame == true and db.autoCloseOnKeyStart == nil and db.autoCloseOnSoloChange == nil then
    db.autoCloseOnKeyStart = true
    db.autoCloseOnSoloChange = true
    db.autoCloseMainFrame = false
  end

  -- M+ forces display-mode migration: if mobNameplateEnabled has never
  -- been set, default to "nameplate" mode. This covers fresh installs
  -- AND legacy users whose only persisted key was mplusForcesEstimate
  -- (the pre-nameplate tooltip-only era). The three display modes are
  -- mutually exclusive in the settings UI, so mplusForcesEstimate is
  -- forced off here to avoid both modules running in parallel.
  if db.mobNameplateEnabled == nil then
    db.mobNameplateEnabled = true
    db.mplusForcesEstimate = false
  end

  -- Persist sensible nameplate defaults into the DB on first run. Without
  -- this the slider / position selector / X+Y offsets show "nil" as their
  -- initial state until the user manually nudges each control.
  if db.mobNameplateShowPercent == nil then
    db.mobNameplateShowPercent = true
  end
  if db.mobNameplateRemainingDefaultMigrated ~= true then
    if db.mobNameplateShowRemaining == true then
      db.mobNameplateShowRemaining = false
    end
    db.mobNameplateRemainingDefaultMigrated = true
  end
  if db.mobNameplateShowRemaining == nil then
    db.mobNameplateShowRemaining = false
  end
  if db.mobNameplateFontSize == nil then
    db.mobNameplateFontSize = 14
  end
  if db.mobNameplatePosition == nil then
    db.mobNameplatePosition = "RIGHT"
  end
  if db.mobNameplateXOffset == nil then
    db.mobNameplateXOffset = 0
  end
  if db.mobNameplateYOffset == nil then
    db.mobNameplateYOffset = 0
  end
  if db.lfgGroupBonusesEnabled == nil then
    db.lfgGroupBonusesEnabled = true
  end
end

-- Pushes the stored values into LFGFlags, RosterUI, MobTooltip,
-- MobNameplate, StatsBox and the UI design.
local function ApplyDBSettingsToModules(ctx, db)
  local lfgFlags = ctx.addonTable and ctx.addonTable.LFGFlags
  if type(lfgFlags) == "table" and type(lfgFlags.SetEnabled) == "function" then
    lfgFlags.SetEnabled(db.lfgFlagsEnabled ~= false)
  end
  if type(lfgFlags) == "table" and type(lfgFlags.SetGroupBonusesEnabled) == "function" then
    lfgFlags.SetGroupBonusesEnabled(db.lfgGroupBonusesEnabled ~= false)
  end
  local rosterUI = ctx.addonTable and ctx.addonTable.RosterUI
  if type(rosterUI) == "table" and type(rosterUI.SetTooltipFlagsEnabled) == "function" then
    rosterUI.SetTooltipFlagsEnabled(db.tooltipFlagsEnabled ~= false)
  end
  local mobTooltip = ctx.addonTable and ctx.addonTable.MobTooltip
  if type(mobTooltip) == "table" then
    if type(mobTooltip.SetLocaleGetter) == "function" and type(ctx.GetL) == "function" then
      mobTooltip.SetLocaleGetter(ctx.GetL)
    end
    if type(mobTooltip.Register) == "function" then
      mobTooltip.Register()
    end
    if type(mobTooltip.SetEnabled) == "function" then
      mobTooltip.SetEnabled(db.mplusForcesEstimate == true)
    end
  end

  local mobNameplate = ctx.addonTable and ctx.addonTable.MobNameplate
  if type(mobNameplate) == "table" then
    ApplyMobNameplateDisplaySettings(mobNameplate, db)
    if type(mobNameplate.Register) == "function" then
      mobNameplate.Register()
    end
    if type(mobNameplate.SetEnabled) == "function" then
      mobNameplate.SetEnabled(db.mobNameplateEnabled == true)
    end
  end

  local statsBox = ctx.addonTable and ctx.addonTable.StatsBox
  if type(statsBox) == "table" and type(statsBox.ApplySettings) == "function" then
    statsBox.ApplySettings()
  end

  FI.ApplyStoredUiDesign(ctx, db)
end

-- Builds ctx.ApplyDBSettings. The first invocation (at file-load time) runs
-- BEFORE the WoW SavedVariables loader has restored IsiLiveDB, so it only
-- sees nil values and writes defaults into a local table. The second
-- invocation, dispatched from event_handlers_runtime when ADDON_LOADED
-- fires, reads the now-restored IsiLiveDB and re-applies the user's actual
-- saved values to MobNameplate/MobTooltip/LFGFlags/RosterInternal -- without
-- this re-apply step, the modules stay locked to the file-load defaults
-- regardless of what the user saved last session.
local function BuildApplyDBSettings(ctx)
  return function()
    local db = IsiLiveDB or {}
    MigrateDBSettings(db)
    if not IsiLiveDB then
      IsiLiveDB = db
    end
    ApplyDBSettingsToModules(ctx, db)
  end
end

FI.ApplyMobNameplateDisplaySettings = ApplyMobNameplateDisplaySettings
FI.MigrateDBSettings = MigrateDBSettings
FI.BuildApplyDBSettings = BuildApplyDBSettings
