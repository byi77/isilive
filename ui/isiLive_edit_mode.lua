local _, addonTable = ...
addonTable = addonTable or {}

-- Blizzard Edit Mode integration for the main window (rule 243), through the
-- embedded LibEditMode (libs/LibEditMode, unmodified, namespaced). Stage 1:
-- the main window only; the cards follow as their own element later.
--
-- Data model: db.position, db.uiScale and db.rosterLayoutMode stay the live
-- values every other part of isiLive reads and writes (drag, resize grip,
-- settings sliders, layout buttons). Per Edit Mode layout, a snapshot of the
-- three lives in db.editModeLayouts[layoutName]. On a layout change the live
-- values are stored under the layout they belong to
-- (db.editModeActiveLayout) and the new layout's snapshot, if there is one,
-- becomes live; a layout without a snapshot keeps the current values, which
-- are the fallback. LibEditMode names layouts only by name: an account and a
-- character layout with the same name share one snapshot.
--
-- Setting db.editModeIntegration (Pattern A, default on). Off: no profile
-- switch, no forced window, and the selection overlay stays hidden, so
-- isiLive behaves as before; the switch acts at once.
local EditMode = {}
addonTable.EditMode = EditMode

local DEFAULT_POSITION = { point = "CENTER", x = 0, y = 0 }

local LAYOUT_OPTIONS = {
  { text = "M+", value = "compact_main_horizontal" },
  { text = "M", value = "expanded" },
  { text = "H", value = "compact_horizontal" },
  { text = "V", value = "compact_vertical" },
}

local function GetDB()
  local db = rawget(_G, "IsiLiveDB")
  return type(db) == "table" and db or nil
end

--- True while the Edit Mode integration is switched on (Pattern A).
function EditMode.IsEnabled()
  local db = GetDB()
  return db == nil or db.editModeIntegration ~= false
end

local function CopyPosition(position)
  if type(position) ~= "table" or type(position.point) ~= "string" then
    return nil
  end
  local x, y = tonumber(position.x), tonumber(position.y)
  if not x or not y then
    return nil
  end
  return {
    point = position.point,
    relativePoint = type(position.relativePoint) == "string" and position.relativePoint or position.point,
    x = x,
    y = y,
  }
end

local function IsLayoutName(name)
  return type(name) == "string" and name ~= ""
end

local function LayoutStore(db)
  if type(db.editModeLayouts) ~= "table" then
    db.editModeLayouts = {}
  end
  return db.editModeLayouts
end

-- Snapshot of the live values for one layout.
local function Snapshot(db)
  return {
    position = CopyPosition(db.position),
    uiScale = tonumber(db.uiScale),
    rosterLayoutMode = type(db.rosterLayoutMode) == "string" and db.rosterLayoutMode or nil,
  }
end

--- Installs the integration. Returns the controller, or nil without the
-- library (a client without Edit Mode) or without a main window.
-- opts: lib, frame, mainUI (ApplyStoredPosition, ApplyScale, ResetPosition,
-- SetVisible, IsVisibleForEditMode), setLayoutMode(mode), getLayoutMode(),
-- applyBgAlpha(value), setLocked(locked), isLocked(), isInCombat(),
-- getText(key, fallback), onValuesChanged().
function EditMode.Install(opts)
  opts = type(opts) == "table" and opts or {}
  local lib = opts.lib
  local frame = opts.frame
  local mainUI = opts.mainUI
  if type(lib) ~= "table" or type(lib.AddFrame) ~= "function" or type(frame) ~= "table" or type(mainUI) ~= "table" then
    return nil
  end
  local function Text(key, fallback)
    if type(opts.getText) == "function" then
      return opts.getText(key, fallback)
    end
    return fallback
  end
  local function InCombat()
    return type(opts.isInCombat) == "function" and opts.isInCombat() == true
  end
  local function ValuesChanged()
    if type(opts.onValuesChanged) == "function" then
      opts.onValuesChanged()
    end
  end

  local controller = { shownForEditMode = false }
  -- A profile that arrived in combat; applied at PLAYER_REGEN_ENABLED.
  local pendingProfile = nil

  -- Makes a snapshot live: scale first (ApplyScale rewrites the anchor around
  -- the old one), then the exact stored position, then the layout mode.
  local function ApplyProfile(profile)
    local db = GetDB()
    if not db or type(profile) ~= "table" then
      return
    end
    if InCombat() then
      pendingProfile = profile
      if controller.eventFrame then
        controller.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
      end
      return
    end
    pendingProfile = nil
    if profile.uiScale then
      db.uiScale = profile.uiScale
      mainUI.ApplyScale(profile.uiScale)
    end
    local position = CopyPosition(profile.position)
    if position then
      db.position = position
      mainUI.ApplyStoredPosition(position)
    end
    if profile.rosterLayoutMode and type(opts.setLayoutMode) == "function" then
      opts.setLayoutMode(profile.rosterLayoutMode)
    end
    ValuesChanged()
  end

  -- Edit Mode layout became active (also at login, and right after the
  -- callback is registered when the layout is already known).
  function controller.OnLayout(layoutName)
    local db = GetDB()
    if not db or not IsLayoutName(layoutName) or not EditMode.IsEnabled() then
      return
    end
    local previous = db.editModeActiveLayout
    if previous == layoutName then
      return
    end
    local store = LayoutStore(db)
    if IsLayoutName(previous) then
      store[previous] = Snapshot(db)
    end
    db.editModeActiveLayout = layoutName
    if store[layoutName] then
      ApplyProfile(store[layoutName])
    end
  end

  function controller.OnRename(oldName, newName)
    local db = GetDB()
    if not db or not IsLayoutName(oldName) or not IsLayoutName(newName) then
      return
    end
    local store = LayoutStore(db)
    if store[oldName] then
      store[newName] = store[oldName]
      store[oldName] = nil
    end
    if db.editModeActiveLayout == oldName then
      db.editModeActiveLayout = newName
    end
  end

  function controller.OnDelete(layoutName)
    local db = GetDB()
    if not db or not IsLayoutName(layoutName) then
      return
    end
    LayoutStore(db)[layoutName] = nil
    if db.editModeActiveLayout == layoutName then
      db.editModeActiveLayout = nil
    end
  end

  -- LibEditMode moved the window (drag or nudge in its dialog). The offsets
  -- are relative to the same point of the parent.
  function controller.OnMoved(_, _layoutName, point, x, y)
    local db = GetDB()
    if not db or not EditMode.IsEnabled() then
      return
    end
    local position = CopyPosition({ point = point, relativePoint = point, x = x, y = y })
    if position then
      db.position = position
    end
  end

  local function Selection()
    return type(lib.frameSelections) == "table" and lib.frameSelections[frame] or nil
  end

  -- Edit Mode opened: the window is shown even without a group or in a raid
  -- (as a placeholder), and its old state comes back on exit.
  function controller.OnEnter()
    if not EditMode.IsEnabled() then
      local selection = Selection()
      if selection and type(selection.Hide) == "function" then
        selection:Hide()
      end
      return
    end
    if InCombat() then
      return
    end
    controller.shownForEditMode = false
    if frame:IsShown() ~= true then
      if mainUI.SetVisible(true, { ignoreRaid = true }) ~= false then
        controller.shownForEditMode = true
      end
    end
  end

  function controller.OnExit()
    if controller.shownForEditMode then
      controller.shownForEditMode = false
      mainUI.SetVisible(false)
    end
  end

  function controller.HandleEvent(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
      if controller.eventFrame then
        controller.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
      end
      if pendingProfile then
        ApplyProfile(pendingProfile)
      end
    end
  end

  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) == "function" then
    controller.eventFrame = createFrame("Frame")
    controller.eventFrame:SetScript("OnEvent", controller.HandleEvent)
  end

  frame.editModeName = "isiLive"
  lib:AddFrame(frame, controller.OnMoved, DEFAULT_POSITION, "isiLive")

  local settingType = lib.SettingType or {}
  local function ReadNumber(key, fallback)
    local db = GetDB()
    return db and tonumber(db[key]) or fallback
  end
  local settings = {
    {
      kind = settingType.Dropdown,
      name = Text("EDIT_MODE_LAYOUT", "Layout"),
      default = "compact_main_horizontal",
      values = LAYOUT_OPTIONS,
      -- Layout lock (rule 249): the choice stays visible on M+ but disabled.
      disabled = function()
        local RI = addonTable._RosterInternal
        return type(RI) == "table" and type(RI.IsLayoutLocked) == "function" and RI.IsLayoutLocked() == true
      end,
      get = function()
        return type(opts.getLayoutMode) == "function" and opts.getLayoutMode() or "compact_main_horizontal"
      end,
      set = function(_, value)
        if type(opts.setLayoutMode) == "function" then
          opts.setLayoutMode(value)
        end
        ValuesChanged()
      end,
    },
    {
      kind = settingType.Slider,
      name = Text("SETTINGS_UI_SCALE", "UI scale"),
      default = 1,
      minValue = 0.5,
      maxValue = 2,
      valueStep = 0.05,
      formatter = function(value)
        return math.floor(value * 100 + 0.5)
      end,
      get = function()
        return ReadNumber("uiScale", 1)
      end,
      set = function(_, value)
        local db = GetDB()
        if db then
          db.uiScale = value
        end
        mainUI.ApplyScale(value)
        ValuesChanged()
      end,
    },
    {
      kind = settingType.Slider,
      name = Text("SETTINGS_BG_ALPHA", "Background opacity"),
      default = 0.5,
      minValue = 0,
      maxValue = 1,
      valueStep = 0.05,
      formatter = function(value)
        return math.floor(value * 100 + 0.5)
      end,
      get = function()
        return ReadNumber("bgAlpha", 0.5)
      end,
      set = function(_, value)
        local db = GetDB()
        if db then
          db.bgAlpha = value
        end
        if type(opts.applyBgAlpha) == "function" then
          opts.applyBgAlpha(value)
        end
        ValuesChanged()
      end,
    },
    {
      kind = settingType.Checkbox,
      name = Text("SETTINGS_LOCK_MAIN_FRAME_POSITION", "Lock main frame position"),
      default = true,
      get = function()
        return type(opts.isLocked) == "function" and opts.isLocked() == true
      end,
      set = function(_, value)
        if type(opts.setLocked) == "function" then
          opts.setLocked(value == true)
        end
        ValuesChanged()
      end,
    },
  }
  if type(lib.AddFrameSettings) == "function" then
    lib:AddFrameSettings(frame, settings)
  end
  if type(lib.AddFrameSettingsButtons) == "function" then
    lib:AddFrameSettingsButtons(frame, {
      {
        text = Text("EDIT_MODE_RESET_POSITION", "Reset position"),
        click = function()
          mainUI.ResetPosition()
          ValuesChanged()
        end,
      },
    })
  end

  if type(lib.RegisterCallback) == "function" then
    lib:RegisterCallback("enter", controller.OnEnter)
    lib:RegisterCallback("exit", controller.OnExit)
    lib:RegisterCallback("layout", controller.OnLayout)
    lib:RegisterCallback("rename", controller.OnRename)
    lib:RegisterCallback("delete", controller.OnDelete)
  end
  controller.settings = settings
  EditMode.controller = controller
  return controller
end
