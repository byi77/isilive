---@diagnostic disable: undefined-global
local helpers = dofile("testmodul/isilive_test_ui_helpers.lua")
local BuildCreateFrameStub = helpers.BuildCreateFrameStub
local BuildBlizzardSettingsStub = helpers.BuildBlizzardSettingsStub

-- Rule 237: isiLive's own config window hosts the settings canvas; Blizzard
-- keeps a searchable vertical-layout stub. The tests drive the real
-- SettingsPanel.Create / ConfigWindow code; the Blizzard Settings side is the
-- COMPONENT-ONLY stub from isilive_test_ui_helpers.lua (no addon event path).
return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local GERMAN = {
    CONFIG_WINDOW_TITLE = "Konfiguration",
    SETTINGS_STUB_LABEL = "isiLive-Konfiguration",
    SETTINGS_STUB_HINT = "Alle isiLive-Optionen liegen in einem eigenen Fenster.",
    BTN_OPEN_CONFIG = "Konfig öffnen",
    SETTINGS_NAV_GENERAL = "Allgemein",
  }
  local ENGLISH = {
    CONFIG_WINDOW_TITLE = "Configuration",
    SETTINGS_STUB_LABEL = "isiLive configuration",
    SETTINGS_STUB_HINT = "All isiLive options are in their own window.",
    BTN_OPEN_CONFIG = "Open config",
    SETTINGS_NAV_GENERAL = "General",
  }

  -- Builds the real settings panel (deferBuild as in production) inside the
  -- Blizzard settings stub. opts.db, opts.labels (table, mutable),
  -- opts.inCombat (function), opts.frameStubOpts, opts.specialFrames.
  local function WithConfigPanel(opts, body)
    opts = opts or {}
    local createFrameStub, frames = BuildCreateFrameStub(opts.frameStubOpts)
    local named = {}
    local raised = 0
    local function CreateFrame(frameType, name, parent, template)
      local frame = createFrameStub(frameType, name, parent, template)
      frame.Raise = function()
        raised = raised + 1
      end
      if name then
        named[name] = frame
      end
      return frame
    end
    local labels = opts.labels or GERMAN
    local inCombat = opts.inCombat or function()
      return false
    end
    local blizzardGlobals, blizzard = BuildBlizzardSettingsStub({ isInCombat = inCombat })
    local db = opts.db or {}
    local globals = {
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = CreateFrame,
      UISpecialFrames = opts.specialFrames or {},
      InCombatLockdown = inCombat,
      C_Timer = { After = function() end },
    }
    for key, value in pairs(blizzardGlobals) do
      globals[key] = value
    end
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_design.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        deferBuild = true,
        getL = function()
          return opts.currentLabels and opts.currentLabels() or labels
        end,
        getDB = function()
          return db
        end,
        setLanguage = function() end,
      })
      body({
        addon = addon,
        panel = panel,
        frames = frames,
        named = named,
        blizzard = blizzard,
        globals = globals,
        db = db,
        Raised = function()
          return raised
        end,
      })
    end)
  end

  local function FindDragHandle(env)
    local window = env.panel.windowFrame
    for _, frame in ipairs(env.frames) do
      if frame._parent == window and frame._scripts.OnDragStart and frame._scripts.OnDragStop then
        return frame
      end
    end
    return nil
  end

  test("Config window opens builds and closes without touching Blizzard settings", function()
    WithConfigPanel({}, function(env)
      local panel = env.panel
      local window = Assert.NotNil(env.named.isiLiveConfigWindow, "the window must be the named isiLiveConfigWindow")
      Assert.Equal(panel.windowFrame, window, "the panel must expose the window frame")
      Assert.False(panel.IsOpen(), "the config window starts closed")
      Assert.False(panel.IsBuilt(), "deferBuild creates no section before the first open")
      Assert.Equal(window._frameStrata, "HIGH", "the window sits above the main frame (MEDIUM)")
      Assert.Equal(panel.canvas._parent, window, "the settings canvas is docked into the window")
      Assert.True(panel.canvas:IsShown(), "the canvas stays shown inside the window")

      Assert.True(panel.Open(), "Open reports success")
      Assert.True(panel.IsOpen(), "Open shows the window")
      Assert.True(panel.IsBuilt(), "the first open builds the sections")
      Assert.Equal(env.Raised(), 1, "Open raises the window above other HIGH frames")
      Assert.Equal(env.blizzard.openCalls, 0, "opening isiLive's config never opens Blizzard's Settings panel")

      Assert.True(panel.Close(), "Close reports that it hid an open window")
      Assert.False(panel.IsOpen(), "Close hides the window")
      Assert.False(panel.Close(), "Close on a closed window is a no-op")
      Assert.True(panel.Toggle(), "Toggle opens a closed window")
      Assert.True(panel.IsOpen(), "Toggle shows the window")
      Assert.False(panel.Toggle(), "Toggle closes an open window")
      Assert.False(panel.IsOpen(), "Toggle hid the window")
    end)
  end)

  test("Config window registers with UISpecialFrames so ESC closes it", function()
    local specialFrames = { "SomeOtherFrame" }
    WithConfigPanel({ specialFrames = specialFrames }, function(env)
      local count = 0
      for _, name in ipairs(specialFrames) do
        if name == "isiLiveConfigWindow" then
          count = count + 1
        end
      end
      Assert.Equal(count, 1, "the window name is registered once for ESC")
      Assert.Equal(specialFrames[1], "SomeOtherFrame", "existing entries stay untouched")
      -- A second creation (e.g. a test or reload path) must not duplicate it.
      env.addon.ConfigWindow.Create({
        getL = function()
          return {}
        end,
      })
      count = 0
      for _, name in ipairs(specialFrames) do
        if name == "isiLiveConfigWindow" then
          count = count + 1
        end
      end
      Assert.Equal(count, 1, "the window name is never registered twice")
    end)
  end)

  test("Config window stores the dragged position and reopens there after a reload", function()
    local db = {}
    WithConfigPanel({ db = db }, function(env)
      env.panel.Open()
      local handle = Assert.NotNil(FindDragHandle(env), "the title band must be a drag handle")
      local window = env.panel.windowFrame
      handle._scripts.OnDragStart(handle)
      Assert.Equal(window._startMovingCalls, 1, "dragging the title band moves the window")
      window:ClearAllPoints()
      window:SetPoint("TOPLEFT", env.globals.UIParent, "TOPLEFT", 140, -75)
      handle._scripts.OnDragStop(handle)
      Assert.Equal(window._stopMovingCalls, 1, "the drop ends the move")
      local pos = Assert.NotNil(db.configWindowPosition, "the drop point is stored")
      Assert.Equal(pos.point, "TOPLEFT", "stored anchor point")
      Assert.Equal(pos.relativePoint, "TOPLEFT", "stored relative point")
      Assert.Equal(pos.x, 140, "stored x")
      Assert.Equal(pos.y, -75, "stored y")
    end)
    -- Reload: a fresh panel on the same SavedVariables opens at the drop point.
    WithConfigPanel({ db = db }, function(env)
      env.panel.Open()
      local point, _, relativePoint, x, y = env.panel.windowFrame:GetPoint()
      Assert.Equal(point, "TOPLEFT", "reopened anchor point")
      Assert.Equal(relativePoint, "TOPLEFT", "reopened relative point")
      Assert.Equal(x, 140, "reopened x")
      Assert.Equal(y, -75, "reopened y")
    end)
    -- A broken stored anchor falls back to the centre instead of guessing.
    WithConfigPanel(
      { db = { configWindowPosition = { point = "NOWHERE", relativePoint = "CENTER", x = 1, y = 2 } } },
      function(env)
        env.panel.Open()
        local point, _, relativePoint, x, y = env.panel.windowFrame:GetPoint()
        Assert.Equal(point, "CENTER", "an invalid stored anchor opens centred")
        Assert.Equal(relativePoint, "CENTER", "centred relative point")
        Assert.Equal(x, 0, "centred x")
        Assert.Equal(y, 0, "centred y")
      end
    )
  end)

  test("Config window Blizzard stub is searchable and its button opens the window", function()
    WithConfigPanel({}, function(env)
      local panel, blizzard = env.panel, env.blizzard
      local category = Assert.NotNil(panel.category, "the stub category is registered")
      Assert.True(category.registered == true, "the stub is registered as an addon category")
      Assert.Equal(#blizzard.categories, 1, "exactly one Blizzard category exists for isiLive")
      Assert.True(#blizzard.Search("isilive") >= 1, "Blizzard search finds isiLive by its plain name")
      Assert.True(#blizzard.Search("konfiguration") >= 1, "Blizzard search finds the localized label")
      Assert.True(#blizzard.Search("konfig öffnen") >= 1, "Blizzard search finds the button text")
      Assert.Equal(#blizzard.Search("nameplates"), 0, "the canvas content is not part of Blizzard's search")

      local header = category.layout.initializers[1]
      Assert.True(
        header.data.name:find("Alle isiLive-Optionen", 1, true) ~= nil,
        "the stub header shows the short hint"
      )
      Assert.True(header.data.name:find("|T", 1, true) == 1, "the stub header starts with the logo")
      local button = Assert.NotNil(blizzard.FindButton(), "the stub carries a button row")
      Assert.Equal(button.data.buttonText, "Konfig öffnen", "localized button text")
      Assert.Equal(button.data.name, "isiLive-Konfiguration", "localized button label")

      env.globals.Settings.OpenToCategory(category.ID)
      Assert.True(blizzard.settingsPanel:IsShown(), "setup: Blizzard's Settings panel is open on the stub")
      button.data.buttonClick()
      Assert.Equal(blizzard.hideCalls, 1, "the stub button hides Blizzard's Settings panel via HideUIPanel")
      Assert.False(blizzard.settingsPanel:IsShown(), "Blizzard's Settings panel is closed")
      Assert.True(panel.IsOpen(), "the config window is open")
      Assert.True(panel.IsBuilt(), "the stub path builds the sections on first use")
    end)
  end)

  test("Config window stub button in combat keeps the Blizzard panel and still opens", function()
    local inCombat = true
    WithConfigPanel({
      inCombat = function()
        return inCombat
      end,
    }, function(env)
      local blizzard = env.blizzard
      env.globals.Settings.OpenToCategory(env.panel.category.ID)
      blizzard.FindButton().data.buttonClick()
      Assert.Equal(blizzard.hideCalls, 0, "no HideUIPanel from addon code in combat (it would be refused)")
      Assert.True(blizzard.settingsPanel:IsShown(), "Blizzard's Settings panel stays open in combat")
      Assert.True(env.panel.IsOpen(), "the config window opens in combat")
      Assert.True(env.Raised() >= 1, "the window is raised above the Settings panel")
    end)
  end)

  test("Config window opens and closes in combat without protected calls", function()
    -- The frame stub raises ADDON_ACTION_BLOCKED on Show/Hide of a protected
    -- frame in combat; the config window and the settings tree hold no secure
    -- template, so nothing may raise.
    WithConfigPanel({
      inCombat = function()
        return true
      end,
      frameStubOpts = {
        simulateProtectedFrames = true,
        isInCombat = function()
          return true
        end,
      },
    }, function(env)
      Assert.False(env.panel.windowFrame._isProtected, "the config window is not a protected frame")
      Assert.True(env.panel.Open(), "Open works in combat")
      Assert.True(env.panel.IsOpen(), "the window is shown in combat")
      for _, frame in ipairs(env.frames) do
        Assert.False(frame._isProtected, "no settings frame may be protected")
      end
      Assert.True(env.panel.Close(), "Close works in combat")
    end)
  end)

  test("Config window relabels title and stub on a language switch while open", function()
    local current = GERMAN
    WithConfigPanel({
      currentLabels = function()
        return current
      end,
    }, function(env)
      local panel, blizzard = env.panel, env.blizzard
      panel.Open()
      Assert.Equal(panel.window.subtitle:GetText(), "Konfiguration", "German window title")
      current = ENGLISH
      panel.Refresh()
      Assert.True(panel.IsOpen(), "the window stays open across the language switch")
      Assert.Equal(panel.window.subtitle:GetText(), "Configuration", "the window title follows at once")
      Assert.Equal(panel.navigation.buttons.general._flatLabel:GetText(), "General", "navigation relabels")
      local button = blizzard.FindButton()
      Assert.Equal(button.data.buttonText, "Open config", "the stub button text follows the language")
      Assert.Equal(button.data.name, "isiLive configuration", "the stub label follows the language")
      Assert.True(#blizzard.Search("configuration") >= 1, "the new label is searchable")
      local tagCount = #button.searchTags
      panel.Refresh()
      panel.Refresh()
      Assert.Equal(#button.searchTags, tagCount, "repeated refreshes never grow the search tags")
    end)
  end)

  test("Config window follows the design switch and the background opacity", function()
    WithConfigPanel({}, function(env)
      local UICommon = env.addon.UICommon
      local panel = env.panel
      panel.Open()
      local window = panel.windowFrame
      UICommon.ApplyDesign("modern")
      Assert.True(window._isiLiveRoundedFill == true, "modern draws the rounded window fill")
      UICommon.ApplyBgAlpha({ settingsWindow = window }, 0.2)
      Assert.Equal(panel.canvas._backdropColor[4], UICommon.CONFIG_CANVAS_ALPHA, "the body keeps its fixed opacity")
      UICommon.ApplyDesign("classic")
      Assert.False(window._isiLiveRoundedFill == true, "classic restores the square window")
      UICommon.ApplyBgAlpha({ settingsWindow = window }, 0.4)
      Assert.Equal(window._backdropColor[4], 0.4, "classic paints the window backdrop with the opacity")
      Assert.Equal(
        panel.canvas._backdropColor[4],
        UICommon.CONFIG_CANVAS_ALPHA,
        "the body repaints with its fixed opacity after the design switch"
      )
      Assert.True(panel.IsOpen(), "design switches keep the window open")
    end)
  end)

  test("Settings panel exposes labelled search entries for the config window search", function()
    WithConfigPanel({ labels = {} }, function(env)
      local panel = env.panel
      Assert.Equal(#panel.GetSearchEntries(), 0, "no entries before the sections are built")
      panel.Open()
      local entries = panel.GetSearchEntries()
      Assert.True(#entries >= 20, "every labelled control is listed (got " .. tostring(#entries) .. ")")
      for index, entry in ipairs(entries) do
        Assert.True(type(entry.label) == "string" and entry.label ~= "", "entry " .. entry.key .. " has a label")
        Assert.NotNil(entry.region, "entry " .. entry.key .. " has a region to scroll to")
        if index > 1 then
          Assert.True(entries[index - 1].key < entry.key, "entries are sorted by key")
        end
      end
    end)
  end)

  test("DBSchema fills the config window position default and repairs a broken anchor", function()
    local addon = LoadAddonModules({ "isiLive_db_schema.lua" })
    local db = {}
    addon.DBSchema.Sanitize(db)
    local pos = Assert.NotNil(db.configWindowPosition, "the config window position is filled")
    Assert.Equal(pos.point, "CENTER", "default point")
    Assert.Equal(pos.relativePoint, "CENTER", "default relative point")
    Assert.Equal(pos.x, 0, "default x")
    Assert.Equal(pos.y, 0, "default y")
    local broken = { configWindowPosition = { point = "TOPLEFT", relativePoint = "BROKEN", x = 50, y = "x" } }
    addon.DBSchema.Sanitize(broken)
    Assert.Equal(broken.configWindowPosition.point, "TOPLEFT", "a valid point is kept")
    Assert.Equal(broken.configWindowPosition.relativePoint, "CENTER", "an invalid relative point is reset")
    Assert.Equal(broken.configWindowPosition.x, 50, "a valid x is kept")
    Assert.Equal(broken.configWindowPosition.y, 0, "an invalid y is reset")
  end)
end
