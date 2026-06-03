-- Standalone CLI tool: pins the live-apply contract for the settings panel.
-- Every checkbox / slider / dropdown the user toggles must trigger the matching
-- production callback (onMobNameplateChange, onLfgFlagsToggle, ...) without
-- requiring a /reload.
--
-- This is the runtime sibling of simulate_savedvariables_reload.lua: where
-- that one tests "value persists across /reload", this one tests "value
-- reaches the live module on the same frame the user clicks".
--
-- The X/Y offset slider regression from v0.9.211 is the canonical bug class
-- here: those sliders were silently inert because their OnValueChanged hooks
-- only called config.onMobNameplateChange() and skipped the panel-internal
-- nameplatePreviewUpdate() — meaning the live module DID get the new value,
-- but the in-panel preview did not. This simulator pins the EXTERNAL callback
-- (production live-apply); the preview-update wiring is covered by the
-- testmodul/isilive_test_scenarios_ui_settings.lua scenarios.
--
-- Verifies for every nameplate control:
--   * checkbox click -> onMobNameplateChange fires
--   * slider drag -> onMobNameplateChange fires
--   * dropdown option click -> onMobNameplateChange fires
-- Plus the standalone callbacks:
--   * SETTINGS_LFG_FLAGS checkbox -> onLfgFlagsToggle(checked)
--   * SETTINGS_TOOLTIP_FLAGS checkbox -> onTooltipFlagsToggle(checked)
--
-- End-to-end discipline (CLAUDE.md "Tests & simulators: end-to-end by default"):
-- the real SettingsPanel.Create is loaded; every interaction goes through the
-- production OnClick / OnValueChanged scripts the panel registers on its
-- frames. The only stub is the WoW UI surface (CreateFrame + Settings global)
-- that we cannot drive from a standalone Lua process.
---@diagnostic disable: undefined-global
local io = io
---@diagnostic disable-next-line: undefined-global
local load = load
---@diagnostic disable-next-line: undefined-global
local os = os

local function LoadLocal(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  local chunk, err = (loadstring or load)(source, "@" .. path)
  assert(chunk, err)
  return chunk()
end

local Harness = LoadLocal("testmodul/isilive_test_harness.lua")
local UIHelpers = LoadLocal("testmodul/isilive_test_ui_helpers.lua")

local failures = 0

local function Check(condition, message)
  if condition then
    print("  [CHECK PASS] " .. message)
    return
  end
  failures = failures + 1
  print("  [CHECK FAIL] " .. message)
end

-- ----------------------------------------------------------------------
-- Frame-finder helpers (shared with simulate_savedvariables_reload.lua).
-- ----------------------------------------------------------------------
local function FindFrame(frames, frameType, settingKey)
  for _, frame in ipairs(frames or {}) do
    if frame._frameType == frameType and frame._settingKey == settingKey then
      return frame
    end
  end
  return nil
end

local function FindOptionButton(frames, value)
  for _, frame in ipairs(frames or {}) do
    if frame._frameType == "Button" and frame._optionValue == value and frame._scripts and frame._scripts.OnClick then
      return frame
    end
  end
  return nil
end

local function ClickCheckbox(frames, settingKey, checked)
  local check = assert(FindFrame(frames, "CheckButton", settingKey), "missing checkbox " .. settingKey)
  check:SetChecked(checked == true)
  assert(check._scripts and check._scripts.OnClick, "checkbox has no OnClick: " .. settingKey)(check)
  return check
end

local function SetSlider(frames, settingKey, value)
  local slider = assert(FindFrame(frames, "Slider", settingKey), "missing slider " .. settingKey)
  assert(slider._scripts and slider._scripts.OnValueChanged, "slider has no OnValueChanged: " .. settingKey)(
    slider,
    value
  )
  return slider
end

local function ClickOption(frames, value)
  local button = assert(FindOptionButton(frames, value), "missing option button " .. tostring(value))
  button._scripts.OnClick(button)
  return button
end

-- ----------------------------------------------------------------------
-- Build a fresh panel session with spy callbacks for every external hook.
-- The DB is a plain table the panel reads from / writes to via getDB().
-- ----------------------------------------------------------------------
local function ApplySettingsDefaults(db)
  if db.mobNameplateEnabled == nil then
    db.mobNameplateEnabled = true
    db.mplusForcesEstimate = false
  end
  if db.mobNameplateShowPercent == nil then
    db.mobNameplateShowPercent = true
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
end

local function Labels()
  return {
    SETTINGS_SECTION_GENERAL = "General",
    SETTINGS_SECTION_DISPLAY = "Display",
    SETTINGS_SECTION_NAMEPLATES = "Nameplates",
    SETTINGS_SECTION_BEHAVIOR = "Behavior",
    SETTINGS_SECTION_SOUND = "Sound",
    SETTINGS_SECTION_CHAT = "Chat",
    SETTINGS_SECTION_DEBUG = "Debug",
    SETTINGS_LANGUAGE = "Language",
    SETTINGS_BG_ALPHA = "Background Opacity",
    SETTINGS_UI_SCALE = "UI Scale",
    SETTINGS_LFG_FLAGS = "LFG Flags",
    SETTINGS_TOOLTIP_FLAGS = "Tooltip Flags",
    SETTINGS_LOCK_MAIN_FRAME_POSITION = "Lock main frame position",
    SETTINGS_MPLUS_FORCES_DISPLAY_MODE = "M+ forces display",
    SETTINGS_MPLUS_FORCES_MODE_OFF = "Off",
    SETTINGS_MPLUS_FORCES_MODE_TOOLTIP = "Tooltip",
    SETTINGS_MPLUS_FORCES_MODE_NAMEPLATE = "Nameplate",
    SETTINGS_NAMEPLATE_SHOW_PERCENT = "Show percentage",
    SETTINGS_NAMEPLATE_SHOW_REMAINING = "Show remaining needed",
    SETTINGS_NAMEPLATE_FONT_SIZE = "Font size",
    SETTINGS_NAMEPLATE_POSITION = "Position",
    SETTINGS_NAMEPLATE_POS_LEFT = "Left",
    SETTINGS_NAMEPLATE_POS_RIGHT = "Right",
    SETTINGS_NAMEPLATE_POS_TOP = "Top",
    SETTINGS_NAMEPLATE_POS_BOTTOM = "Bottom",
    SETTINGS_NAMEPLATE_X_OFFSET = "X offset",
    SETTINGS_NAMEPLATE_Y_OFFSET = "Y offset",
  }
end

local function BuildPanelSession()
  local db = {}
  ApplySettingsDefaults(db)

  -- Spy table: every external production callback that the panel can call
  -- bumps the matching counter and records its last-seen argument.
  local spy = {
    mobNameplateChanges = 0,
    lfgFlagsToggle = { calls = 0, lastValue = nil },
    tooltipFlagsToggle = { calls = 0, lastValue = nil },
    mplusForcesToggle = { calls = 0, lastValue = nil },
  }

  local createFrame, frames = UIHelpers.BuildCreateFrameStub()

  Harness.WithGlobals({
    UIParent = {},
    IsiLiveDB = db,
    CreateFrame = createFrame,
    Settings = {
      RegisterCanvasLayoutCategory = function(canvas, name)
        return { canvas = canvas, name = name }
      end,
      RegisterAddOnCategory = function() end,
    },
    C_AddOns = {
      IsAddOnLoaded = function()
        return false
      end,
    },
  }, function()
    local addon = Harness.LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
    local panel = addon.SettingsPanel.Create({
      getL = Labels,
      getCurrentLocale = function()
        return "enUS"
      end,
      setLanguage = function() end,
      getDB = function()
        return db
      end,
      onBgAlphaChange = function() end,
      onUiScaleChange = function() end,
      onLfgFlagsToggle = function(enabled)
        spy.lfgFlagsToggle.calls = spy.lfgFlagsToggle.calls + 1
        spy.lfgFlagsToggle.lastValue = enabled
      end,
      onTooltipFlagsToggle = function(enabled)
        spy.tooltipFlagsToggle.calls = spy.tooltipFlagsToggle.calls + 1
        spy.tooltipFlagsToggle.lastValue = enabled
      end,
      onMplusForcesToggle = function(enabled)
        spy.mplusForcesToggle.calls = spy.mplusForcesToggle.calls + 1
        spy.mplusForcesToggle.lastValue = enabled
      end,
      onMainFramePositionLockToggle = function() end,
      onMobNameplateChange = function()
        spy.mobNameplateChanges = spy.mobNameplateChanges + 1
      end,
    })
    assert(panel ~= nil, "settings panel must build")
  end)

  return { db = db, frames = frames, spy = spy }
end

-- ----------------------------------------------------------------------
-- Phase 1: nameplate "show percent" checkbox -> onMobNameplateChange.
-- ----------------------------------------------------------------------
local function ScenarioShowPercentCheckbox()
  print("\n========== Scenario 1: SETTINGS_NAMEPLATE_SHOW_PERCENT checkbox ==========")
  local session = BuildPanelSession()
  local before = session.spy.mobNameplateChanges
  ClickCheckbox(session.frames, "SETTINGS_NAMEPLATE_SHOW_PERCENT", false)
  Check(
    session.spy.mobNameplateChanges == before + 1,
    "show-percent checkbox click triggers onMobNameplateChange exactly once"
  )
  Check(session.db.mobNameplateShowPercent == false, "DB field updated to false")
end

-- ----------------------------------------------------------------------
-- Phase 2: nameplate "show remaining" checkbox -> onMobNameplateChange.
-- ----------------------------------------------------------------------
local function ScenarioShowRemainingCheckbox()
  print("\n========== Scenario 2: SETTINGS_NAMEPLATE_SHOW_REMAINING checkbox ==========")
  local session = BuildPanelSession()
  local before = session.spy.mobNameplateChanges
  ClickCheckbox(session.frames, "SETTINGS_NAMEPLATE_SHOW_REMAINING", false)
  Check(
    session.spy.mobNameplateChanges == before + 1,
    "show-remaining checkbox click triggers onMobNameplateChange exactly once"
  )
  Check(session.db.mobNameplateShowRemaining == false, "DB field updated to false")
end

-- ----------------------------------------------------------------------
-- Phase 3: nameplate font-size slider -> onMobNameplateChange.
-- ----------------------------------------------------------------------
local function ScenarioFontSizeSlider()
  print("\n========== Scenario 3: SETTINGS_NAMEPLATE_FONT_SIZE slider ==========")
  local session = BuildPanelSession()
  local before = session.spy.mobNameplateChanges
  SetSlider(session.frames, "SETTINGS_NAMEPLATE_FONT_SIZE", 18)
  Check(
    session.spy.mobNameplateChanges == before + 1,
    "font-size slider drag triggers onMobNameplateChange exactly once"
  )
  Check(session.db.mobNameplateFontSize == 18, "DB field updated to 18")
end

-- ----------------------------------------------------------------------
-- Phase 4: position dropdown (TOP) -> onMobNameplateChange.
-- ----------------------------------------------------------------------
local function ScenarioPositionDropdown()
  print("\n========== Scenario 4: SETTINGS_NAMEPLATE_POSITION dropdown -> TOP ==========")
  local session = BuildPanelSession()
  local before = session.spy.mobNameplateChanges
  ClickOption(session.frames, "TOP")
  Check(
    session.spy.mobNameplateChanges == before + 1,
    "position dropdown click triggers onMobNameplateChange exactly once"
  )
  Check(session.db.mobNameplatePosition == "TOP", "DB field updated to TOP")
end

-- ----------------------------------------------------------------------
-- Phase 5: nameplate X-offset slider -> onMobNameplateChange.
-- This is the v0.9.211 regression pin: the slider was silently inert
-- because its OnValueChanged skipped the live-apply callback.
-- ----------------------------------------------------------------------
local function ScenarioXOffsetSlider()
  print("\n========== Scenario 5: SETTINGS_NAMEPLATE_X_OFFSET slider (v0.9.211 regression pin) ==========")
  local session = BuildPanelSession()
  local before = session.spy.mobNameplateChanges
  SetSlider(session.frames, "SETTINGS_NAMEPLATE_X_OFFSET", 10)
  Check(
    session.spy.mobNameplateChanges == before + 1,
    "X-offset slider drag triggers onMobNameplateChange (was silent inert in v0.9.210)"
  )
  Check(session.db.mobNameplateXOffset == 10, "DB field updated to 10")
end

-- ----------------------------------------------------------------------
-- Phase 6: nameplate Y-offset slider -> onMobNameplateChange.
-- Sibling regression pin to phase 5.
-- ----------------------------------------------------------------------
local function ScenarioYOffsetSlider()
  print("\n========== Scenario 6: SETTINGS_NAMEPLATE_Y_OFFSET slider (v0.9.211 regression pin) ==========")
  local session = BuildPanelSession()
  local before = session.spy.mobNameplateChanges
  SetSlider(session.frames, "SETTINGS_NAMEPLATE_Y_OFFSET", -5)
  Check(
    session.spy.mobNameplateChanges == before + 1,
    "Y-offset slider drag triggers onMobNameplateChange (was silent inert in v0.9.210)"
  )
  Check(session.db.mobNameplateYOffset == -5, "DB field updated to -5")
end

-- ----------------------------------------------------------------------
-- Phase 7: SETTINGS_LFG_FLAGS checkbox -> onLfgFlagsToggle(checked).
-- Standalone callback (NOT routed through onMobNameplateChange).
-- ----------------------------------------------------------------------
local function ScenarioLfgFlagsCheckbox()
  print("\n========== Scenario 7: SETTINGS_LFG_FLAGS checkbox ==========")
  local session = BuildPanelSession()
  ClickCheckbox(session.frames, "SETTINGS_LFG_FLAGS", false)
  Check(session.spy.lfgFlagsToggle.calls == 1, "LFG-flags checkbox click triggers onLfgFlagsToggle")
  Check(session.spy.lfgFlagsToggle.lastValue == false, "callback receives the new checked state (false)")
  Check(session.db.lfgFlagsEnabled == false, "DB field updated")
end

-- ----------------------------------------------------------------------
-- Phase 8: SETTINGS_TOOLTIP_FLAGS checkbox -> onTooltipFlagsToggle.
-- ----------------------------------------------------------------------
local function ScenarioTooltipFlagsCheckbox()
  print("\n========== Scenario 8: SETTINGS_TOOLTIP_FLAGS checkbox ==========")
  local session = BuildPanelSession()
  ClickCheckbox(session.frames, "SETTINGS_TOOLTIP_FLAGS", false)
  Check(session.spy.tooltipFlagsToggle.calls == 1, "tooltip-flags checkbox click triggers onTooltipFlagsToggle")
  Check(session.spy.tooltipFlagsToggle.lastValue == false, "callback receives the new checked state (false)")
  Check(session.db.tooltipFlagsEnabled == false, "DB field updated")
end

-- ----------------------------------------------------------------------
-- Phase 9: each nameplate control fires the callback ON EVERY DRAG, not
-- just the first one. Drag the font slider three times -> 3 callback fires.
-- ----------------------------------------------------------------------
local function ScenarioRepeatedDragsAllFire()
  print("\n========== Scenario 9: repeated slider drags each fire onMobNameplateChange ==========")
  local session = BuildPanelSession()
  local before = session.spy.mobNameplateChanges
  for _, value in ipairs({ 12, 14, 16, 18 }) do
    SetSlider(session.frames, "SETTINGS_NAMEPLATE_FONT_SIZE", value)
  end
  Check(
    session.spy.mobNameplateChanges == before + 4,
    "four slider drags fire four onMobNameplateChange callbacks (no debounce, no last-only-write)"
  )
  Check(session.db.mobNameplateFontSize == 18, "final DB value is 18 (last drag wins)")
end

ScenarioShowPercentCheckbox()
ScenarioShowRemainingCheckbox()
ScenarioFontSizeSlider()
ScenarioPositionDropdown()
ScenarioXOffsetSlider()
ScenarioYOffsetSlider()
ScenarioLfgFlagsCheckbox()
ScenarioTooltipFlagsCheckbox()
ScenarioRepeatedDragsAllFire()

if failures > 0 then
  print(string.format("\nSettings live-apply simulator failed: %d check(s) failed", failures))
  os.exit(1)
end

print("\nSettings live-apply simulator passed.")
