---@diagnostic disable: undefined-global
local helpersChunk, helpersErr = loadfile("testmodul/isilive_test_ui_helpers.lua")
if not helpersChunk then
  error("cannot load UI helpers: " .. tostring(helpersErr))
end
local helpers = helpersChunk()
local BuildCreateFrameStub = helpers.BuildCreateFrameStub
local RequireValue = helpers.RequireValue

local function BuildPanel(db, createFrameStub, extraOpts, LoadAddonModules)
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

local function FindFontStringByText(panel, text)
  for _, fontString in ipairs((panel.content and panel.content._fontStrings) or {}) do
    if fontString._text == text then
      return fontString
    end
  end
  return nil
end

return function(test, ctx)
  local Assert = RequireValue(ctx.assert, "UI settings descriptions scenario ctx.assert should exist")
  local WithGlobals = RequireValue(ctx.with_globals, "UI settings descriptions scenario ctx.with_globals should exist")
  local LoadAddonModules =
    RequireValue(ctx.load_modules, "UI settings descriptions scenario ctx.load_modules should exist")

  test("Settings display checkboxes render descriptions below options and refresh localized text", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = { showMinimapButton = true, lfgGroupBonusesEnabled = true }
    local labels = {
      SETTINGS_SECTION_GENERAL = "General",
      SETTINGS_SECTION_DISPLAY = "Display",
      SETTINGS_SECTION_SOUNDS = "Sounds",
      SETTINGS_SECTION_BEHAVIOR = "Behavior",
      SETTINGS_SECTION_CHAT = "Chat",
      SETTINGS_SECTION_DEBUG = "Debug",
      SETTINGS_SECTION_NAMEPLATES = "Nameplates",
      SETTINGS_LANGUAGE = "Language",
      SETTINGS_DEFAULT_OPEN_UI = "Default layout",
      SETTINGS_DEFAULT_OPEN_UI_DESC = "Chooses which main layout opens when isiLive is shown.",
      SETTINGS_COMBAT_LOGGING = "Combat Logging",
      SETTINGS_COMBAT_LOGGING_DESC = "Enables Blizzard's advanced combat log for external log analysis.",
      SETTINGS_DM_RESET = "Reset damage meter",
      SETTINGS_DM_RESET_DESC = "Clears Blizzard's built-in damage meter when you enter a new dungeon.",
      SETTINGS_ESC_PANEL = "Show ESC shortcuts",
      SETTINGS_ESC_PANEL_DESC = "Adds isiLive's shortcut panel to the ESC menu for quick access.",
      SETTINGS_SHOW_TIMEWAYS_NAVIGATOR = "Show Timeways navigator",
      SETTINGS_SHOW_TIMEWAYS_NAVIGATOR_DESC = "Shows the Timeways portal navigator when a known target dungeon "
        .. "can be resolved.",
      SETTINGS_HEARTHSTONE_SELECT = "Hearthstone Selection",
      SETTINGS_HEARTHSTONE_SELECT_DESC = "Choose which Hearthstone the ESC menu shortcut should use.",
      SETTINGS_UI_SCALE = "Main interface scale with intentionally wrapped label",
      SETTINGS_UI_SCALE_DESC = "Scales the main isiLive interface.",
      SETTINGS_MINIMAP_BUTTON = "Show minimap button",
      SETTINGS_MINIMAP_BUTTON_DESC = "Shows the isiLive minimap button.",
      SETTINGS_LFG_GROUP_BONUSES = "Group Finder: Show class bonuses",
      SETTINGS_LFG_GROUP_BONUSES_DESC = "Marks relevant class bonuses on groups and applicants.",
      SETTINGS_SYNC_ENABLED = "Addon Sync",
      SETTINGS_SYNC_ENABLED_DESC = "Shares key, roster, target, DPS, location, and kick data "
        .. "with isiLive group members.",
      SETTINGS_MPLUS_FORCES_DISPLAY_MODE = "Display mode",
      SETTINGS_MPLUS_FORCES_DISPLAY_MODE_DESC = "Chooses where Mythic+ enemy forces progress is shown.",
      SETTINGS_SOUND_LEAD_ENABLED = "Sound: Lead Transfer",
      SETTINGS_SOUND_LEAD_ENABLED_DESC = "Plays a sound when group leadership changes to you.",
      SETTINGS_QUEUE_DEBUG = "Queue debug",
      SETTINGS_QUEUE_DEBUG_DESC = "Records queue detection events until the next UI reload.",
    }
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
          getL = function()
            return labels
          end,
        }, LoadAddonModules),
        "settings panel must build"
      )
      local minimapCheck = Assert.NotNil(
        FindFrame(createdFrames, "CheckButton", "SETTINGS_MINIMAP_BUTTON"),
        "minimap checkbox must carry its setting key"
      )
      local combatLogCheck = Assert.NotNil(
        FindFrame(createdFrames, "CheckButton", "SETTINGS_COMBAT_LOGGING"),
        "combat-log checkbox must carry its setting key"
      )
      local damageMeterCheck = Assert.NotNil(
        FindFrame(createdFrames, "CheckButton", "SETTINGS_DM_RESET"),
        "damage-meter reset checkbox must carry its setting key"
      )
      local escPanelCheck = Assert.NotNil(
        FindFrame(createdFrames, "CheckButton", "SETTINGS_ESC_PANEL"),
        "ESC panel checkbox must carry its setting key"
      )
      local navigatorCheck = Assert.NotNil(
        FindFrame(createdFrames, "CheckButton", "SETTINGS_SHOW_TIMEWAYS_NAVIGATOR"),
        "portal navigator checkbox must carry its setting key"
      )
      local hearthstoneDropdown = Assert.NotNil(
        FindFrame(createdFrames, "Button", "SETTINGS_HEARTHSTONE_SELECT"),
        "hearthstone dropdown must carry its setting key"
      )
      local bonusCheck = Assert.NotNil(
        FindFrame(createdFrames, "CheckButton", "SETTINGS_LFG_GROUP_BONUSES"),
        "LFG group-bonus checkbox must exist"
      )
      local syncCheck =
        Assert.NotNil(FindFrame(createdFrames, "CheckButton", "SETTINGS_SYNC_ENABLED"), "sync checkbox must exist")
      local leadSoundCheck = Assert.NotNil(
        FindFrame(createdFrames, "CheckButton", "SETTINGS_SOUND_LEAD_ENABLED"),
        "lead sound checkbox must exist"
      )
      local queueDebugCheck = Assert.NotNil(
        FindFrame(createdFrames, "CheckButton", "SETTINGS_QUEUE_DEBUG"),
        "queue debug checkbox must exist"
      )
      local uiScaleSlider = Assert.NotNil(
        FindFrame(createdFrames, "Slider", "SETTINGS_UI_SCALE"),
        "UI scale slider must carry its setting key"
      )
      local displayModeLabel =
        Assert.NotNil(FindFontStringByText(panel, "Display mode"), "option selector label must be present")
      ---@diagnostic disable: undefined-field
      Assert.NotNil(minimapCheck.description, "minimap checkbox must render a description font string")
      Assert.NotNil(combatLogCheck.description, "combat-log checkbox must render a description font string")
      Assert.NotNil(damageMeterCheck.description, "damage-meter checkbox must render a description font string")
      Assert.NotNil(escPanelCheck.description, "ESC panel checkbox must render a description font string")
      Assert.NotNil(navigatorCheck.description, "portal navigator checkbox must render a description font string")
      Assert.NotNil(hearthstoneDropdown.description, "hearthstone dropdown must render a description font string")
      Assert.NotNil(bonusCheck.description, "LFG group-bonus checkbox must render a description font string")
      Assert.NotNil(syncCheck.description, "behavior checkbox must render a description font string")
      Assert.NotNil(leadSoundCheck.description, "sound checkbox must render a description font string")
      Assert.NotNil(queueDebugCheck.description, "debug checkbox must render a description font string")
      Assert.NotNil(uiScaleSlider.description, "slider must render a description font string")
      Assert.Equal(minimapCheck.description._fontObject, "GameFontNormalSmall", "description must use the small font")
      Assert.Equal(
        hearthstoneDropdown.description._fontObject,
        "GameFontNormalSmall",
        "dropdown description must use the small font"
      )
      Assert.Equal(
        combatLogCheck.description._text,
        "Enables Blizzard's advanced combat log for external log analysis.",
        "combat-log description must use localized text"
      )
      Assert.Equal(
        damageMeterCheck.description._text,
        "Clears Blizzard's built-in damage meter when you enter a new dungeon.",
        "damage-meter description must use localized text"
      )
      Assert.Equal(
        escPanelCheck.description._text,
        "Adds isiLive's shortcut panel to the ESC menu for quick access.",
        "ESC panel description must use localized text"
      )
      Assert.Equal(
        navigatorCheck.description._text,
        "Shows the Timeways portal navigator when a known target dungeon can be resolved.",
        "portal navigator description must use localized text"
      )
      Assert.Equal(
        hearthstoneDropdown.description._text,
        "Choose which Hearthstone the ESC menu shortcut should use.",
        "hearthstone dropdown description must use localized text"
      )
      Assert.Equal(
        minimapCheck.description._text,
        "Shows the isiLive minimap button.",
        "minimap description must use localized text"
      )
      Assert.Equal(
        bonusCheck.description._text,
        "Marks relevant class bonuses on groups and applicants.",
        "LFG group-bonus description must use localized text"
      )
      Assert.Equal(
        uiScaleSlider.description._text,
        "Scales the main isiLive interface.",
        "slider description must use localized text"
      )
      Assert.Equal(
        syncCheck.description._text,
        "Shares key, roster, target, DPS, location, and kick data with isiLive group members.",
        "behavior description must use localized text"
      )
      Assert.Equal(
        leadSoundCheck.description._text,
        "Plays a sound when group leadership changes to you.",
        "sound description must use localized text"
      )
      Assert.Equal(
        queueDebugCheck.description._text,
        "Records queue detection events until the next UI reload.",
        "debug description must use localized text"
      )
      local hasOptionDescription = false
      for _, fontString in ipairs(panel.content._fontStrings or {}) do
        if fontString._text == "Chooses where Mythic+ enemy forces progress is shown." then
          hasOptionDescription = true
          break
        end
      end
      Assert.True(hasOptionDescription, "option selectors must render description font strings")
      Assert.Equal(minimapCheck.description._point[1], "TOPLEFT", "description must anchor below the option row")
      Assert.True(
        minimapCheck.description._point[2] ~= minimapCheck.label,
        "description must not anchor to the right side of the label"
      )
      Assert.Equal(minimapCheck.description._wordWrap, true, "descriptions below options must wrap for readability")
      Assert.Equal(minimapCheck.description._nonSpaceWrap, true, "descriptions must allow long terms to wrap")
      Assert.Equal(combatLogCheck.label._wordWrap, true, "checkbox labels must wrap inside their row budget")
      Assert.Equal(combatLogCheck.label._nonSpaceWrap, true, "checkbox labels must allow long terms to wrap")
      Assert.Equal(uiScaleSlider.label._wordWrap, true, "slider labels must wrap inside their row budget")
      Assert.Equal(uiScaleSlider.label._nonSpaceWrap, true, "slider labels must allow long terms to wrap")
      Assert.True(
        uiScaleSlider.description._point[5] < (uiScaleSlider.label._point[5] - uiScaleSlider.label:GetStringHeight()),
        "slider descriptions must sit below wrapped labels without visual overlap"
      )
      Assert.Equal(displayModeLabel._wordWrap, true, "option selector labels must wrap inside their row budget")
      Assert.Equal(displayModeLabel._nonSpaceWrap, true, "option selector labels must allow long terms to wrap")
      Assert.Equal(hearthstoneDropdown._label._wordWrap, true, "dropdown labels must wrap inside their row budget")
      Assert.Equal(hearthstoneDropdown._label._nonSpaceWrap, true, "dropdown labels must allow long terms to wrap")
      Assert.True(
        (tonumber(minimapCheck.description._width) or 0) >= 600,
        "descriptions below options must use a readable text width"
      )
      Assert.True(
        (tonumber(combatLogCheck.label._width) or 0) >= 600,
        "checkbox labels with descriptions must not keep the old narrow inline width"
      )

      labels.SETTINGS_LFG_GROUP_BONUSES_DESC = "Updated class bonus description."
      labels.SETTINGS_HEARTHSTONE_SELECT_DESC = "Updated hearthstone description."
      labels.SETTINGS_UI_SCALE_DESC = "Updated slider description."
      labels.SETTINGS_SYNC_ENABLED_DESC = "Updated behavior description."
      labels.SETTINGS_SOUND_LEAD_ENABLED_DESC = "Updated sound description."
      labels.SETTINGS_QUEUE_DEBUG_DESC = "Updated debug description."
      panel.Refresh()
      Assert.Equal(
        bonusCheck.description._text,
        "Updated class bonus description.",
        "Refresh must update checkbox descriptions after locale text changes"
      )
      Assert.Equal(
        hearthstoneDropdown.description._text,
        "Updated hearthstone description.",
        "Refresh must update dropdown descriptions after locale text changes"
      )
      Assert.Equal(
        uiScaleSlider.description._text,
        "Updated slider description.",
        "Refresh must update slider descriptions after locale text changes"
      )
      Assert.Equal(
        syncCheck.description._text,
        "Updated behavior description.",
        "Refresh must update behavior descriptions after locale text changes"
      )
      Assert.Equal(
        leadSoundCheck.description._text,
        "Updated sound description.",
        "Refresh must update sound descriptions after locale text changes"
      )
      Assert.Equal(
        queueDebugCheck.description._text,
        "Updated debug description.",
        "Refresh must update debug descriptions after locale text changes"
      )
      ---@diagnostic enable: undefined-field
    end)
  end)
end
