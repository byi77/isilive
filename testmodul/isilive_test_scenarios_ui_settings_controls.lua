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

  test("Settings language refresh reflows existing rows navigation and scroll range without rebuilding", function()
    local createFrame, frames = BuildCreateFrameStub()
    local labels = {
      SETTINGS_PAGE_HINT = "Short intro",
      BETA_NOTICE_TEXT = "Short beta notice",
      SETTINGS_SECTION_GENERAL_HINT = "Short hint",
      SETTINGS_LANGUAGE_DESC = "Short language explanation",
      SETTINGS_MINIMAP_BUTTON = "Short minimap label",
      SETTINGS_MINIMAP_BUTTON_DESC = "Short minimap explanation",
      SETTINGS_FONT_FAMILY_DESC = "Short font explanation",
      SETTINGS_LFG_GROUP_BONUSES_DESC = "Short buff explanation",
      SETTINGS_RESET_UI_POSITION_HINT = "Short reset explanation",
    }
    local longLabels = {}
    for key in pairs(labels) do
      longLabels[key] = string.rep("Localized wrapped text ", 40)
    end
    WithGlobals({
      UIParent = {},
      IsiLiveDB = {},
      CreateFrame = createFrame,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas)
          return { canvas = canvas }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_languages.lua", "isiLive_settings.lua" })
      local active = labels
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return active
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return {}
        end,
        deferBuild = true,
      })
      local deferredCount = #frames
      active = longLabels
      panel.Refresh()
      Assert.Equal(#frames, deferredCount, "language change before first open does not allocate controls")
      active = labels
      panel.EnsureBuilt()
      panel.Refresh()
      local count = #frames
      local shortHeight = panel.content:GetHeight()
      local shortOffsets = {}
      for key, offset in pairs(panel.navigation.offsets) do
        shortOffsets[key] = offset
      end
      local rectUpdates = 0
      panel.scrollFrame.UpdateScrollChildRect = function()
        rectUpdates = rectUpdates + 1
      end
      panel.scrollFrame.GetVerticalScrollRange = function()
        return math.max(0, panel.content:GetHeight() - 600)
      end
      local shortPositions = {}
      for _, frame in ipairs(frames) do
        if frame._parent == panel.content and frame._settingKey then
          shortPositions[frame] = { frame:GetPoint(1) }
        end
      end
      active = longLabels
      panel.Refresh()
      Assert.True(panel.content:GetHeight() > shortHeight, "translated wrapped text must increase the content height")
      Assert.True(
        panel.navigation.offsets.general > shortOffsets.general,
        "intro and beta growth moves general navigation"
      )
      Assert.True(
        panel.navigation.offsets.display > shortOffsets.display,
        "language controls and hints move following sections"
      )
      Assert.True(panel.navigation.offsets.vip > shortOffsets.vip, "all downstream sections move")
      for _, frame in ipairs(frames) do
        if frame._settingKey == "SETTINGS_MINIMAP_BUTTON" then
          Assert.Equal(frame.label._point[1], "TOPLEFT", "wrapped checkbox labels grow down from their own row")
          local _, _, _, _, rowY = frame:GetPoint(1)
          Assert.True(
            frame.description._point[5] < rowY - frame.label:GetStringHeight(),
            "translated description stays below the entire wrapped label"
          )
        end
      end
      local longHeight = panel.content:GetHeight()
      panel.Refresh()
      Assert.Equal(panel.content:GetHeight(), longHeight, "repeated refresh cannot accumulate layout drift")
      panel.scrollFrame:SetVerticalScroll(longHeight)
      active = labels
      panel.Refresh()
      Assert.Equal(panel.content:GetHeight(), shortHeight, "switching back restores the original content height")
      for key, offset in pairs(shortOffsets) do
        Assert.Equal(panel.navigation.offsets[key], offset, "switching back restores every section target")
      end
      for frame, point in pairs(shortPositions) do
        local restored = { frame:GetPoint(1) }
        Assert.Equal(restored[4], point[4], "child controls keep their indentation")
        Assert.Equal(restored[5], point[5], "existing controls return to their original anchors")
      end
      Assert.Equal(#frames, count, "refresh reuses frames and menu pools")
      Assert.True(rectUpdates >= 3, "scroll child bounds are updated after each reflow")
      Assert.Equal(
        panel.scrollFrame:GetVerticalScroll(),
        shortHeight - 600,
        "shrinking content clamps the scroll position"
      )
      panel.navigation.buttons.display._scripts.OnClick()
      Assert.Equal(
        panel.scrollFrame:GetVerticalScroll(),
        panel.navigation.offsets.display,
        "navigation jumps to the updated section"
      )
    end)
  end)

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

  test("Settings raid section offers default-off sound opt-ins that persist", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      GetTime = function()
        return 100
      end,
      PlaySoundFile = function() end,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_sound_utils.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return { SETTINGS_SECTION_RAID = "Raid", SETTINGS_RAID_SUMMON_SOUND = "Incoming summon alert in raids" }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      local checks = {}
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "CheckButton" and type(frame._settingKey) == "string" then
          checks[frame._settingKey] = frame
        end
      end
      local optIns = {
        SETTINGS_RAID_SUMMON_SOUND = "raidIncomingSummonSoundEnabled",
        SETTINGS_RAID_PET_STUCK_SOUND = "raidPetStuckSoundEnabled",
        SETTINGS_RAID_LEADER_SOUND = "raidLeaderTransferSoundEnabled",
      }
      for settingKey, dbKey in pairs(optIns) do
        local check = Assert.NotNil(checks[settingKey], settingKey .. " must be rendered in the raid section")
        Assert.False(check:GetChecked(), settingKey .. " must default to off: raids stay hard off")
        Assert.Nil(db[dbKey], "opening settings must not persist " .. dbKey)
        check:SetChecked(true)
        check._scripts.OnClick(check)
        Assert.True(db[dbKey], settingKey .. " must persist true when enabled")
        Assert.True(
          addon.SoundUtils.IsRaidOptInEnabled(({
            raidIncomingSummonSoundEnabled = "portal_available",
            raidPetStuckSoundEnabled = "pet_stuck",
            raidLeaderTransferSoundEnabled = "leader_transfer",
          })[dbKey]),
          dbKey .. " must lift the raid gate for its alert"
        )
      end
      Assert.False(addon.SoundUtils.IsRaidOptInEnabled("tank_died"), "alerts without an opt-in stay raid-gated")

      db.raidPetStuckSoundEnabled = false
      panel.Refresh()
      Assert.False(checks.SETTINGS_RAID_PET_STUCK_SOUND:GetChecked(), "refresh must mirror the stored opt-in")
      Assert.Equal(
        panel.navigation.buttons.raid._isiLiveSettingsSection,
        "raid",
        "the raid section needs its own navigation tab"
      )
    end)
  end)

  test("Settings group-invite repeat sits directly below the group-invite alert and persists", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      GetTime = function()
        return 100
      end,
      PlaySoundFile = function() end,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_sound_utils.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {}
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      local order = {}
      local loopCheck = nil
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "CheckButton" and type(frame._settingKey) == "string" then
          order[#order + 1] = frame._settingKey
          if frame._settingKey == "SETTINGS_SOUND_GROUP_INVITE_LOOP" then
            loopCheck = frame
          end
        end
      end
      loopCheck = Assert.NotNil(loopCheck, "the group-invite repeat checkbox must be rendered")
      local parentIndex = nil
      for index, key in ipairs(order) do
        if key == "SETTINGS_SOUND_GROUP_INVITE" then
          parentIndex = index
        end
      end
      Assert.Equal(
        order[(parentIndex or 0) + 1],
        "SETTINGS_SOUND_GROUP_INVITE_LOOP",
        "the repeat toggle must follow its group-invite alert"
      )
      Assert.True(loopCheck:GetChecked(), "the group-invite repeat must default to on")
      Assert.Nil(db.soundGroupInviteLoopEnabled, "opening settings must not persist the repeat default")

      loopCheck:SetChecked(false)
      loopCheck._scripts.OnClick(loopCheck)
      Assert.False(db.soundGroupInviteLoopEnabled, "disabling the repeat must persist false")

      db.soundGroupInviteLoopEnabled = true
      panel.Refresh()
      Assert.True(loopCheck:GetChecked(), "refresh must mirror the stored repeat setting")
    end)
  end)
end
