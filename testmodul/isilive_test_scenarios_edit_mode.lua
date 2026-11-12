---@diagnostic disable: undefined-global

-- Rule 243: Blizzard Edit Mode integration of the main window
-- (ui/isiLive_edit_mode.lua).
-- COMPONENT-ONLY: Blizzard's Edit Mode (EditModeManagerFrame, its selection
-- template and dialogs) does not exist in the test harness, so the embedded
-- LibEditMode is replaced by a recorder with its public API (AddFrame,
-- AddFrameSettings, AddFrameSettingsButtons, RegisterCallback,
-- frameSelections, SettingType) and the main window by a recorder of the
-- mainUI calls. The real library, factory and main window run end-to-end in
-- the wowsim scenario `edit_mode`.

local function NewLib()
  local lib = {
    frameSelections = {},
    callbacks = {},
    SettingType = { Dropdown = 0, Checkbox = 1, Slider = 2 },
  }
  function lib:AddFrame(frame, callback, default, name)
    self.frame, self.onMoved, self.default, self.name = frame, callback, default, name
    self.frameSelections[frame] = {
      shown = true,
      Hide = function(selection)
        selection.shown = false
      end,
    }
  end
  function lib:AddFrameSettings(_, settings)
    self.settings = settings
  end
  function lib:AddFrameSettingsButtons(_, buttons)
    self.buttons = buttons
  end
  function lib:RegisterCallback(event, callback)
    self.callbacks[event] = callback
  end
  return lib
end

local function NewMainUI(frame)
  local calls = {}
  local mainUI = { calls = calls }
  local function Record(name, ...)
    calls[#calls + 1] = { name = name, args = { ... } }
  end
  function mainUI.ApplyScale(scale)
    Record("ApplyScale", scale)
    frame.scale = scale
    return true
  end
  function mainUI.ApplyStoredPosition(position)
    Record("ApplyStoredPosition", position)
  end
  function mainUI.ResetPosition()
    Record("ResetPosition")
  end
  function mainUI.SetVisible(visible, options)
    Record("SetVisible", visible, options)
    frame.shown = visible == true
    return true
  end
  return mainUI
end

local function NewFrame(shown)
  local frame = { shown = shown == true }
  function frame.IsShown(self)
    return self.shown
  end
  return frame
end

local function Globals(db, combat)
  local eventFrames = {}
  return {
    IsiLiveDB = db,
    CreateFrame = function()
      local eventFrame = { events = {} }
      function eventFrame.RegisterEvent(self, event)
        self.events[event] = true
      end
      function eventFrame.UnregisterEvent(self, event)
        self.events[event] = nil
      end
      function eventFrame.SetScript(self, _, handler)
        self.handler = handler
      end
      eventFrames[#eventFrames + 1] = eventFrame
      return eventFrame
    end,
  },
    eventFrames,
    combat
end

local function Names(calls)
  local names = {}
  for _, call in ipairs(calls) do
    names[#names + 1] = call.name
  end
  return table.concat(names, ",")
end

return function(test, ctx)
  local Assert = ctx.assert

  local function Setup(fn, opts)
    opts = opts or {}
    local db = opts.db or {}
    local combat = { value = false }
    local globals, eventFrames = Globals(db, combat)
    ctx.with_globals(globals, function()
      local addon = ctx.load_modules({ "isiLive_edit_mode.lua" })
      local lib = NewLib()
      local frame = NewFrame(opts.shown)
      local mainUI = NewMainUI(frame)
      local layoutModes = {}
      local env = { db = db, lib = lib, frame = frame, mainUI = mainUI, combat = combat, layoutModes = layoutModes }
      env.controller = addon.EditMode.Install({
        lib = lib,
        frame = frame,
        mainUI = mainUI,
        getLayoutMode = function()
          return layoutModes[#layoutModes] or "compact_main_horizontal"
        end,
        setLayoutMode = function(mode)
          layoutModes[#layoutModes + 1] = mode
          db.rosterLayoutMode = mode
        end,
        isInCombat = function()
          return combat.value
        end,
        getText = function(_, fallback)
          return fallback
        end,
      })
      env.eventFrame = eventFrames[1]
      env.addon = addon
      fn(env)
    end)
  end

  test("Edit Mode registers the main window with its dialog settings and every layout callback", function()
    Setup(function(env)
      Assert.NotNil(env.controller, "the integration installs with the library and a main window")
      Assert.Equal(env.lib.frame, env.frame, "the main window is the Edit Mode element")
      Assert.Equal(env.lib.name, "isiLive", "the element is named isiLive")
      Assert.Equal(env.lib.default.point, "CENTER", "its default position is the screen center")
      local names = {}
      for _, setting in ipairs(env.lib.settings) do
        names[#names + 1] = setting.name
      end
      Assert.Equal(
        table.concat(names, ","),
        "Layout,UI scale,Background opacity,Lock main frame position",
        "the dialog offers layout, scale, background and lock"
      )
      Assert.Equal(env.lib.buttons[1].text, "Reset position", "plus a reset button")
      for _, event in ipairs({ "enter", "exit", "layout", "rename", "delete" }) do
        Assert.NotNil(env.lib.callbacks[event], "callback registered: " .. event)
      end

      env.lib.settings[2].set("Modern", 1.25)
      Assert.Equal(env.db.uiScale, 1.25, "the scale slider writes the shared uiScale")
      env.lib.settings[1].set("Modern", "compact_vertical")
      Assert.Equal(env.layoutModes[1], "compact_vertical", "the layout dropdown switches the layout")
      env.lib.buttons[1].click()
      Assert.Equal(Names(env.mainUI.calls), "ApplyScale,ResetPosition", "slider and reset go through mainUI")
    end)
  end)

  test("Edit Mode keeps position scale and layout per Edit Mode layout and applies scale before position", function()
    Setup(function(env)
      local db = env.db
      env.lib.callbacks.layout("Modern", 1)
      Assert.Equal(db.editModeActiveLayout, "Modern", "the first layout only marks the live values")
      Assert.Equal(#env.mainUI.calls, 0, "nothing is applied for a layout without a snapshot")

      env.lib.onMoved(env.frame, "Modern", "TOPLEFT", 120, -80)
      Assert.Equal(db.position.point, "TOPLEFT", "a move in the Edit Mode writes the live position")
      Assert.Equal(db.position.relativePoint, "TOPLEFT", "relative to the same point of the parent")
      db.uiScale = 0.9
      db.rosterLayoutMode = "compact_main_horizontal"

      env.lib.callbacks.layout("Classic", 2)
      Assert.Equal(db.editModeLayouts.Modern.position.x, 120, "the old layout keeps its position")
      Assert.Equal(db.editModeLayouts.Modern.uiScale, 0.9, "and its scale")
      Assert.Equal(db.position.x, 120, "a layout without a snapshot keeps the current values")

      env.lib.onMoved(env.frame, "Classic", "BOTTOM", 0, 40)
      db.uiScale = 1.3
      db.rosterLayoutMode = "compact_vertical"
      env.lib.callbacks.layout("Modern", 1)
      Assert.Equal(db.editModeLayouts.Classic.position.point, "BOTTOM", "Classic keeps its own place")
      Assert.Equal(db.position.point, "TOPLEFT", "back in Modern its position is live again")
      Assert.Equal(db.uiScale, 0.9, "with its scale")
      Assert.Equal(db.rosterLayoutMode, "compact_main_horizontal", "and its layout")
      Assert.Equal(
        Names(env.mainUI.calls),
        "ApplyScale,ApplyStoredPosition",
        "the scale is applied before the exact stored position"
      )
      Assert.Equal(env.layoutModes[#env.layoutModes], "compact_main_horizontal", "the roster layout follows")
    end)
  end)

  test("Edit Mode defers a layout profile in combat until PLAYER_REGEN_ENABLED", function()
    Setup(function(env)
      local db = env.db
      env.lib.callbacks.layout("Modern", 1)
      env.lib.onMoved(env.frame, "Modern", "LEFT", 30, 0)
      env.lib.callbacks.layout("Classic", 2)
      env.lib.onMoved(env.frame, "Classic", "RIGHT", -30, 0)
      env.combat.value = true
      env.lib.callbacks.layout("Modern", 1)
      Assert.Equal(#env.mainUI.calls, 0, "nothing touches the protected window in combat")
      Assert.True(env.eventFrame.events.PLAYER_REGEN_ENABLED, "the profile waits for the end of combat")
      env.combat.value = false
      env.eventFrame.handler(env.eventFrame, "PLAYER_REGEN_ENABLED")
      Assert.Equal(db.position.point, "LEFT", "the deferred profile is applied after combat")
      Assert.Nil(env.eventFrame.events.PLAYER_REGEN_ENABLED, "and the event is released again")
    end)
  end)

  test("Edit Mode follows renamed and deleted layouts", function()
    Setup(function(env)
      local db = env.db
      env.lib.callbacks.layout("Raid", 3)
      env.lib.onMoved(env.frame, "Raid", "TOP", 0, -20)
      env.lib.callbacks.layout("Modern", 1)
      env.lib.callbacks.rename("Raid", "Raid 2")
      Assert.Nil(db.editModeLayouts.Raid, "the old name is gone")
      Assert.Equal(db.editModeLayouts["Raid 2"].position.point, "TOP", "the snapshot moved to the new name")
      env.lib.callbacks.rename("Modern", "Main")
      Assert.Equal(db.editModeActiveLayout, "Main", "renaming the active layout keeps the live values with it")
      env.lib.callbacks.delete("Raid 2")
      Assert.Nil(db.editModeLayouts["Raid 2"], "a deleted layout drops its snapshot")
    end)
  end)

  test("Edit Mode shows a hidden main window as a raid-safe placeholder and hides it again on exit", function()
    Setup(function(env)
      env.lib.callbacks.enter()
      Assert.True(env.frame.shown, "the hidden window appears in the Edit Mode")
      local show = env.mainUI.calls[1]
      Assert.True(show.args[1], "it is shown")
      Assert.True(show.args[2].ignoreRaid, "also in a raid, as a placeholder")
      env.lib.callbacks.exit()
      Assert.False(env.frame.shown, "it hides again when the Edit Mode closes")
    end, { shown = false })

    Setup(function(env)
      env.lib.callbacks.enter()
      env.lib.callbacks.exit()
      Assert.Equal(#env.mainUI.calls, 0, "an open window is left as it was")
    end, { shown = true })
  end)

  test("Edit Mode integration switched off keeps isiLive as before", function()
    Setup(function(env)
      local db = env.db
      env.lib.callbacks.layout("Modern", 1)
      env.lib.callbacks.layout("Classic", 2)
      Assert.Nil(db.editModeLayouts, "no snapshots are kept")
      env.lib.onMoved(env.frame, "Classic", "TOP", 0, 0)
      Assert.Nil(db.position, "the Edit Mode does not write the position")
      env.lib.callbacks.enter()
      Assert.False(env.lib.frameSelections[env.frame].shown, "the isiLive element stays hidden in the Edit Mode")
      Assert.False(env.frame.shown, "the window is not forced open")
      Assert.False(env.addon.EditMode.IsEnabled(), "the switch reads false")
    end, { db = { editModeIntegration = false }, shown = false })
  end)
end
