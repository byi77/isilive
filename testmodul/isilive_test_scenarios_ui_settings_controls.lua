---@diagnostic disable: undefined-global
-- Settings control visuals: slider fill and hover, font-menu previews.
-- Split from isilive_test_scenarios_ui_settings.lua, which sits at the
-- 3200-line file limit.
local helpersChunk, helpersErr = loadfile("testmodul/isilive_test_ui_helpers.lua")
if not helpersChunk then
  error("cannot load UI helpers: " .. tostring(helpersErr))
end
local helpers = helpersChunk()
local BuildCreateFrameStub = helpers.BuildCreateFrameStub

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Settings sliders show a filled share and a hover state, and the font menu previews each font", function()
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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_fonts.lua", "isiLive_settings.lua" })
      addon.SettingsPanel.Create({
        getL = function()
          return { SETTINGS_BG_ALPHA = "Background Opacity", SETTINGS_FONT_FAMILY = "Font" }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
        onBgAlphaChange = function() end,
      })

      local slider, fontDropdown = nil, nil
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "Slider" and frame._settingKey == "SETTINGS_BG_ALPHA" then
          slider = frame
        elseif frame._settingKey == "SETTINGS_FONT_FAMILY" and frame._dropdownLabel then
          fontDropdown = frame
        end
      end
      ---@diagnostic disable: undefined-field
      slider = Assert.NotNil(slider, "settings panel should create a background alpha slider")
      local fill = Assert.NotNil(slider.fill, "sliders should carry a filled share")
      -- 0.30-1.00 range, 180 px track, 12 px thumb: 6 px + 168 px * share.
      Assert.Equal(fill._width, 54, "the 50% default should fill up to the thumb centre")
      slider._scripts.OnValueChanged(slider, 0.70)
      Assert.Equal(fill._width, 102, "moving the slider should move the filled share with it")
      slider._scripts.OnValueChanged(slider, 0.30)
      Assert.Equal(fill._width, 6, "the minimum should fill only up to half a thumb")

      Assert.Equal(slider.thumb._color[4], 0.8, "the thumb should rest at its calm strength")
      slider._scripts.OnEnter(slider)
      Assert.Equal(slider.thumb._color[4], 1, "hovering should brighten the thumb")
      slider._scripts.OnLeave(slider)
      Assert.Equal(slider.thumb._color[4], 0.8, "leaving should restore the calm thumb")

      fontDropdown = Assert.NotNil(fontDropdown, "settings panel should create the font dropdown")
      fontDropdown._scripts.OnClick(fontDropdown)
      local optionLabels = {}
      for _, frame in ipairs(createdFrames) do
        if frame.label and type(frame.label._text) == "string" then
          optionLabels[frame.label._text] = frame.label
        end
      end
      local morpheus = Assert.NotNil(optionLabels.Morpheus, "the font menu should list Morpheus")
      Assert.Equal(morpheus:GetFont(), "Fonts\\MORPHEUS.TTF", "Morpheus should be shown in Morpheus")
      local arial = Assert.NotNil(optionLabels["Arial Narrow"], "the font menu should list Arial Narrow")
      Assert.Equal(arial:GetFont(), "Fonts\\ARIALN.TTF", "Arial Narrow should be shown in Arial Narrow")
      local default = Assert.NotNil(optionLabels.Default, "the font menu should list the default entry")
      Assert.Equal(default:GetFont(), "Fonts\\FRIZQT__.TTF", "the default entry should keep the template font")
      ---@diagnostic enable: undefined-field
    end)
  end)
end
