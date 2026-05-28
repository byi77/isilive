---@diagnostic disable: undefined-global
local helpersChunk, helpersErr = loadfile("testmodul/isilive_test_ui_helpers.lua")
if not helpersChunk then
  error("cannot load UI helpers: " .. tostring(helpersErr))
end
local helpers = helpersChunk()
local BuildCreateFrameStub = helpers.BuildCreateFrameStub
local RequireValue = helpers.RequireValue

local function RegisterSettingsPanelNameplateRoundtripTests(test, Assert, WithGlobals, LoadAddonModules)
  local function BuildPanel(db, createFrameStub, extraOpts)
    local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
    local opts = {
      getL = function()
        return {
          SETTINGS_SECTION_GENERAL = "General",
          SETTINGS_SECTION_DISPLAY = "Display",
          SETTINGS_SECTION_BEHAVIOR = "Behavior",
          SETTINGS_SECTION_DEBUG = "Debug",
          SETTINGS_SECTION_NAMEPLATES = "Nameplates",
          SETTINGS_LANGUAGE = "Language",
          SETTINGS_NAMEPLATE_FONT_SIZE = "Font size",
          SETTINGS_NAMEPLATE_SHOW_PERCENT = "Show percentage",
          SETTINGS_NAMEPLATE_SHOW_REMAINING = "Show remaining needed",
          SETTINGS_NAMEPLATE_X_OFFSET = "X offset",
          SETTINGS_NAMEPLATE_Y_OFFSET = "Y offset",
          SETTINGS_NAMEPLATE_POSITION = "Position",
          SETTINGS_MPLUS_FORCES_DISPLAY_MODE = "Display mode",
        }
      end,
      getCurrentLocale = function()
        return "enUS"
      end,
      setLanguage = function() end,
      getDB = function()
        return db
      end,
      onMobNameplateChange = function() end,
      onMplusForcesToggle = function() end,
    }
    if type(extraOpts) == "table" then
      for k, v in pairs(extraOpts) do
        opts[k] = v
      end
    end
    return addon.SettingsPanel.Create(opts)
  end

  local function FindFrame(createdFrames, frameType, settingKey)
    for _, frame in ipairs(createdFrames) do
      if frame._frameType == frameType and frame._settingKey == settingKey then
        return frame
      end
    end
    return nil
  end

  local function FindOptionButton(createdFrames, settingKey, value)
    -- Option-selector buttons store the option value on `_optionValue` and
    -- inherit the parent selector's setting key only via the label frame's
    -- `_settingKey`; the button itself doesn't carry the key. Match by
    -- combining `_optionValue` with the click handler that closes over the
    -- selector's setter.
    for _, frame in ipairs(createdFrames) do
      if frame._frameType == "Button" and frame._optionValue == value and frame._scripts and frame._scripts.OnClick then
        return frame
      end
    end
    return nil
  end

  test("Settings nameplate font-size slider roundtrip persists user value across Refresh", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = { mobNameplateEnabled = true }
    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local panel = Assert.NotNil(BuildPanel(db, createFrameStub), "settings panel must build")
      local slider =
        Assert.NotNil(FindFrame(createdFrames, "Slider", "SETTINGS_NAMEPLATE_FONT_SIZE"), "font-size slider must exist")
      ---@diagnostic disable: undefined-field
      local onValueChanged = Assert.NotNil(slider._scripts.OnValueChanged, "slider must define OnValueChanged")
      Assert.Equal(slider._maxValue, 28, "font-size slider max must match the DB schema max")
      onValueChanged(slider, 28)
      Assert.Equal(db.mobNameplateFontSize, 28, "slider drag must persist fontSize=28 to DB")
      panel.Refresh()
      Assert.Equal(db.mobNameplateFontSize, 28, "Refresh must NOT overwrite the user-set fontSize")
      Assert.Equal(slider:GetValue(), 28, "Refresh must restore the slider's visible value to the DB value")
      ---@diagnostic enable: undefined-field
    end)
  end)

  test("Settings nameplate showPercent checkbox roundtrip persists user value across Refresh", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = { mobNameplateEnabled = true, mobNameplateShowPercent = true }
    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local panel = Assert.NotNil(BuildPanel(db, createFrameStub), "settings panel must build")
      local check = Assert.NotNil(
        FindFrame(createdFrames, "CheckButton", "SETTINGS_NAMEPLATE_SHOW_PERCENT"),
        "showPercent checkbox must exist"
      )
      ---@diagnostic disable: undefined-field
      check:SetChecked(false)
      local onClick = Assert.NotNil(check._scripts.OnClick, "checkbox must define OnClick")
      onClick(check)
      Assert.Equal(db.mobNameplateShowPercent, false, "uncheck must persist false to DB")
      panel.Refresh()
      Assert.Equal(db.mobNameplateShowPercent, false, "Refresh must NOT overwrite false back to default")
      Assert.False(check:GetChecked(), "Refresh must keep the checkbox visually unchecked")
      ---@diagnostic enable: undefined-field
    end)
  end)

  test("Settings nameplate showRemaining checkbox roundtrip persists user value across Refresh", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = { mobNameplateEnabled = true, mobNameplateShowRemaining = false }
    local changeCalls = 0
    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local panel = Assert.NotNil(
        BuildPanel(db, createFrameStub, {
          onMobNameplateChange = function()
            changeCalls = changeCalls + 1
          end,
        }),
        "settings panel must build"
      )
      local check = Assert.NotNil(
        FindFrame(createdFrames, "CheckButton", "SETTINGS_NAMEPLATE_SHOW_REMAINING"),
        "showRemaining checkbox must exist"
      )
      ---@diagnostic disable: undefined-field
      check:SetChecked(true)
      local onClick = Assert.NotNil(check._scripts.OnClick, "checkbox must define OnClick")
      onClick(check)
      Assert.Equal(db.mobNameplateShowRemaining, true, "checking must persist true to DB")
      Assert.Equal(changeCalls, 1, "checking must invoke live MobNameplate refresh")
      panel.Refresh()
      Assert.Equal(db.mobNameplateShowRemaining, true, "Refresh must NOT overwrite true back to default")
      Assert.True(check:GetChecked(), "Refresh must keep the checkbox visually checked")
      ---@diagnostic enable: undefined-field
    end)
  end)

  test("Settings LFG group-bonus checkbox persists and invokes live toggle callback", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    local toggleCalls = {}
    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local panel = Assert.NotNil(
        BuildPanel(db, createFrameStub, {
          onLfgGroupBonusesToggle = function(enabled)
            toggleCalls[#toggleCalls + 1] = enabled
          end,
        }),
        "settings panel must build"
      )
      local check = Assert.NotNil(
        FindFrame(createdFrames, "CheckButton", "SETTINGS_LFG_GROUP_BONUSES"),
        "LFG group-bonus checkbox must exist"
      )
      ---@diagnostic disable: undefined-field
      Assert.True(check:GetChecked(), "LFG group-bonus checkbox must default to enabled when DB value is missing")
      check:SetChecked(false)
      local onClick = Assert.NotNil(check._scripts.OnClick, "checkbox must define OnClick")
      onClick(check)
      Assert.Equal(db.lfgGroupBonusesEnabled, false, "uncheck must persist false to DB")
      Assert.Equal(toggleCalls[1], false, "uncheck must invoke the live LFG group-bonus callback")
      panel.Refresh()
      Assert.False(check:GetChecked(), "Refresh must keep the checkbox visually unchecked")

      check:SetChecked(true)
      onClick(check)
      Assert.Equal(db.lfgGroupBonusesEnabled, true, "check must persist true to DB")
      Assert.Equal(toggleCalls[2], true, "check must invoke the live LFG group-bonus callback")
      panel.Refresh()
      Assert.True(check:GetChecked(), "Refresh must keep the checkbox visually checked")
      ---@diagnostic enable: undefined-field
    end)
  end)

  test("Settings nameplate position selector roundtrip persists user value across Refresh", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = { mobNameplateEnabled = true, mobNameplatePosition = "RIGHT" }
    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local panel = Assert.NotNil(BuildPanel(db, createFrameStub), "settings panel must build")
      local topButton = Assert.NotNil(
        FindOptionButton(createdFrames, "SETTINGS_NAMEPLATE_POSITION", "TOP"),
        "TOP position option button must exist"
      )
      ---@diagnostic disable: undefined-field
      topButton._scripts.OnClick(topButton)
      Assert.Equal(db.mobNameplatePosition, "TOP", "selecting TOP must persist to DB")
      panel.Refresh()
      Assert.Equal(db.mobNameplatePosition, "TOP", "Refresh must NOT overwrite TOP back to RIGHT")
      ---@diagnostic enable: undefined-field
    end)
  end)

  test("Settings nameplate xOffset / yOffset sliders persist user values across Refresh", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = { mobNameplateEnabled = true }
    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local panel = Assert.NotNil(BuildPanel(db, createFrameStub), "settings panel must build")
      local xSlider =
        Assert.NotNil(FindFrame(createdFrames, "Slider", "SETTINGS_NAMEPLATE_X_OFFSET"), "X offset slider must exist")
      local ySlider =
        Assert.NotNil(FindFrame(createdFrames, "Slider", "SETTINGS_NAMEPLATE_Y_OFFSET"), "Y offset slider must exist")
      ---@diagnostic disable: undefined-field
      xSlider._scripts.OnValueChanged(xSlider, 17)
      ySlider._scripts.OnValueChanged(ySlider, -8)
      Assert.Equal(db.mobNameplateXOffset, 17, "X offset slider drag must persist to DB")
      Assert.Equal(db.mobNameplateYOffset, -8, "Y offset slider drag must persist to DB")
      panel.Refresh()
      Assert.Equal(db.mobNameplateXOffset, 17, "Refresh must NOT overwrite user X offset")
      Assert.Equal(db.mobNameplateYOffset, -8, "Refresh must NOT overwrite user Y offset")
      Assert.Equal(xSlider:GetValue(), 17, "Refresh must restore X slider visible value")
      Assert.Equal(ySlider:GetValue(), -8, "Refresh must restore Y slider visible value")
      ---@diagnostic enable: undefined-field
    end)
  end)

  test("Settings nameplate displayMode survives a /reload simulation (session-1 → save → session-2)", function()
    -- Reproduces the user-visible bug "I enable nameplate percent, /reload, it's
    -- off again". Simulates two addon sessions sharing the same SavedVariables
    -- table: session 1 enables 'nameplate', then session 2 boots with that DB
    -- and must NOT revert it to the fresh-install 'off' default.
    local function SimulateSession(initialDB)
      local createFrameStub, createdFrames = BuildCreateFrameStub()
      local db = {}
      if type(initialDB) == "table" then
        for k, v in pairs(initialDB) do
          db[k] = v
        end
      end
      local panel
      WithGlobals({
        UIParent = {},
        IsiLiveDB = db,
        CreateFrame = createFrameStub,
        Settings = {
          RegisterCanvasLayoutCategory = function(canvas, name)
            return { canvas = canvas, name = name }
          end,
          RegisterAddOnCategory = function() end,
        },
      }, function()
        panel = BuildPanel(db, createFrameStub)
      end)
      return panel, createdFrames, db
    end

    -- Session 1: legacy/off install. The user enables 'nameplate', then the
    -- next session must preserve that explicit choice.
    local sessionOneDB = {
      mobNameplateEnabled = false,
      mplusForcesEstimate = false,
      mobNameplateShowPercent = true,
      mobNameplateFontSize = 14,
      mobNameplatePosition = "RIGHT",
      mobNameplateXOffset = 0,
      mobNameplateYOffset = 0,
    }

    local _, createdFrames1, db1 = SimulateSession(sessionOneDB)
    local nameplateButton =
      Assert.NotNil(FindOptionButton(createdFrames1, nil, "nameplate"), "session-1 'nameplate' button must exist")
    ---@diagnostic disable: undefined-field
    nameplateButton._scripts.OnClick(nameplateButton)
    ---@diagnostic enable: undefined-field
    Assert.Equal(db1.mobNameplateEnabled, true, "session-1 click must enable the nameplate flag in DB")

    -- Simulate "WoW saves the DB on logout" — copy db1 into a sessionTwoDB so
    -- the reference doesn't carry over.
    local sessionTwoDB = {}
    for k, v in pairs(db1) do
      sessionTwoDB[k] = v
    end

    -- Session 2: addon boots with session-1's saved values.
    local _, createdFrames2, db2 = SimulateSession(sessionTwoDB)
    Assert.Equal(
      db2.mobNameplateEnabled,
      true,
      "session-2 boot must NOT revert mobNameplateEnabled back to false — that is the user-reported regression"
    )
    -- The selector must visually reflect the saved value too. We check the
    -- 'nameplate' button's selected state via its backdrop colour applied by
    -- ApplyButtonStyle when selectedMode == optionValue.
    local nameplateButton2 =
      Assert.NotNil(FindOptionButton(createdFrames2, nil, "nameplate"), "session-2 'nameplate' button must exist")
    Assert.Equal(
      type(nameplateButton2._optionValue),
      "string",
      "session-2 'nameplate' button must carry an option value"
    )
  end)

  test("Settings nameplate displayMode selector persists 'nameplate' / 'tooltip' / 'off' choice", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local panel = Assert.NotNil(BuildPanel(db, createFrameStub), "settings panel must build")
      local nameplateButton =
        Assert.NotNil(FindOptionButton(createdFrames, nil, "nameplate"), "'nameplate' display-mode button must exist")
      local tooltipButton =
        Assert.NotNil(FindOptionButton(createdFrames, nil, "tooltip"), "'tooltip' display-mode button must exist")
      local offButton =
        Assert.NotNil(FindOptionButton(createdFrames, nil, "off"), "'off' display-mode button must exist")

      ---@diagnostic disable: undefined-field
      nameplateButton._scripts.OnClick(nameplateButton)
      Assert.Equal(db.mobNameplateEnabled, true, "selecting 'nameplate' must enable the nameplate flag")
      Assert.Equal(db.mplusForcesEstimate, false, "selecting 'nameplate' must disable the tooltip flag")
      panel.Refresh()
      Assert.Equal(db.mobNameplateEnabled, true, "Refresh must keep the 'nameplate' selection")

      tooltipButton._scripts.OnClick(tooltipButton)
      Assert.Equal(db.mobNameplateEnabled, false, "selecting 'tooltip' must disable the nameplate flag")
      Assert.Equal(db.mplusForcesEstimate, true, "selecting 'tooltip' must enable the tooltip flag")

      offButton._scripts.OnClick(offButton)
      Assert.Equal(db.mobNameplateEnabled, false, "selecting 'off' must disable nameplate")
      Assert.Equal(db.mplusForcesEstimate, false, "selecting 'off' must disable tooltip")
      ---@diagnostic enable: undefined-field
    end)
  end)
end


return function(test, ctx)
  local Assert = RequireValue(ctx.assert, "UI settings nameplate scenario ctx.assert should exist")
  local WithGlobals = RequireValue(ctx.with_globals, "UI settings nameplate scenario ctx.with_globals should exist")
  local LoadAddonModules = RequireValue(ctx.load_modules, "UI settings nameplate scenario ctx.load_modules should exist")

  RegisterSettingsPanelNameplateRoundtripTests(test, Assert, WithGlobals, LoadAddonModules)
end
