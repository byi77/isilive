---@diagnostic disable: undefined-global
local helpersChunk, helpersErr = loadfile("testmodul/isilive_test_ui_helpers.lua")
if not helpersChunk then
  error("cannot load UI helpers: " .. tostring(helpersErr))
end
local helpers = helpersChunk()
local BuildCreateFrameStub = helpers.BuildCreateFrameStub
local RequireValue = helpers.RequireValue

local function RegisterSettingsPanelResetActionTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Settings reset confirmation styles popup chrome and hover feedback", function()
    local staticPopupDialogs = {}
    local shownPopup = nil
    local acceptCalls = 0
    local backdropCalls = {}

    local function MakeButton(text)
      local button = { _text = text, _scripts = {} }
      function button:SetSize(width, height)
        self._size = { width, height }
      end
      function button:SetBackdrop(backdrop)
        self._backdrop = backdrop
      end
      function button:SetBackdropColor(...)
        self._backdropColor = { ... }
      end
      function button:SetBackdropBorderColor(...)
        self._backdropBorderColor = { ... }
      end
      function button:CreateTexture()
        local texture = {}
        function texture:SetAllPoints()
          self._allPoints = true
        end
        function texture:SetColorTexture(...)
          self._color = { ... }
        end
        function texture:Hide()
          self._hidden = true
        end
        function texture:Show()
          self._shown = true
        end
        return texture
      end
      function button:GetText()
        return self._text
      end
      function button:SetText(value)
        self._text = value
      end
      function button:SetScript(scriptName, fn)
        self._scripts[scriptName] = fn
      end
      return button
    end

    WithGlobals({
      YES = "Yep",
      NO = "Nope",
      StaticPopupDialogs = staticPopupDialogs,
      StaticPopup_Show = function(name)
        shownPopup = name
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_settings_reset.lua" }, {
        UICommon = {
          Colors = {
            TEXT_NORMAL = { 0.9, 0.9, 1 },
            ACCENT_BLUE = { 0.1, 0.2, 0.8 },
            ACCENT_GOLD = { 1, 0.7, 0 },
          },
          ApplyBackdrop = function(frame, preset)
            backdropCalls[#backdropCalls + 1] = { frame = frame, preset = preset }
            frame._appliedPreset = preset
            return true
          end,
        },
      })

      addon.SettingsReset.ShowResetConfirmation("STYLE", "Confirm reset?", function()
        acceptCalls = acceptCalls + 1
      end)

      local dialog = Assert.NotNil(staticPopupDialogs[shownPopup], "reset confirmation dialog must be registered")
      local text = {}
      function text:SetTextColor(...)
        self._color = { ... }
      end
      function text:SetWordWrap(value)
        self._wordWrap = value
      end
      local styledDialog = {
        text = text,
        button1 = MakeButton("Yes"),
        button2 = MakeButton("No"),
      }
      function styledDialog:SetMovable(value)
        self._movable = value
      end
      function styledDialog:SetResizable(value)
        self._resizable = value
      end

      dialog.OnShow(styledDialog)
      Assert.Equal(styledDialog._appliedPreset, "NOTICE", "dialog backdrop preset must be applied")
      Assert.False(styledDialog._movable, "reset confirmation must not be movable")
      Assert.False(styledDialog._resizable, "reset confirmation must not be resizable")
      Assert.True(text._wordWrap == true, "reset confirmation text must word-wrap")
      Assert.NotNil(styledDialog.button1._isiLiveHoverGlow, "confirm button must get hover glow")

      styledDialog.button1._scripts.OnEnter(styledDialog.button1)
      Assert.True(styledDialog.button1._isiLiveHoverGlow._shown == true, "hover must show confirm glow")
      styledDialog.button1._scripts.OnLeave(styledDialog.button1)
      Assert.True(styledDialog.button1._isiLiveHoverGlow._hidden == true, "leave must hide confirm glow")

      dialog.OnAccept()
      Assert.Equal(acceptCalls, 1, "accept must run the pending reset action")
      Assert.True(#backdropCalls >= 1, "ApplyBackdrop must be used while styling the popup")
    end)
  end)

  test("Settings reset confirmation falls back to immediate accept without StaticPopup", function()
    local acceptCalls = 0
    WithGlobals({
      StaticPopupDialogs = nil,
      StaticPopup_Show = nil,
    }, function()
      local addon = LoadAddonModules({ "isiLive_settings_reset.lua" })
      addon.SettingsReset.ShowResetConfirmation(nil, nil, function()
        acceptCalls = acceptCalls + 1
      end)
      Assert.Equal(acceptCalls, 1, "missing StaticPopup API must execute the reset action immediately")
    end)
  end)

  test("UI game-menu default actions use secure clicks and combat guards", function()
    local professionClicks = 0
    local spellbookCalls = 0
    local professionsFrame = {
      IsShown = function(self)
        return self._shown == true
      end,
    }
    local function MakeShownFrame()
      return {
        IsShown = function(self)
          return self._shown == true
        end,
      }
    end
    local achievementFrame = MakeShownFrame()
    local questLogFrame = MakeShownFrame()
    local pveFrame = MakeShownFrame()
    local encounterJournal = MakeShownFrame()
    local collectionsJournal = MakeShownFrame()
    local communitiesFrame = MakeShownFrame()
    local function MakeButton(targetFrame)
      return {
        Click = function()
          targetFrame._shown = true
        end,
      }
    end

    WithGlobals({
      ProfessionsFrame = professionsFrame,
      AchievementFrame = achievementFrame,
      QuestLogFrame = questLogFrame,
      PVEFrame = pveFrame,
      EncounterJournal = encounterJournal,
      CollectionsJournal = collectionsJournal,
      CommunitiesFrame = communitiesFrame,
      ProfessionMicroButton = {
        Click = function()
          professionClicks = professionClicks + 1
          professionsFrame._shown = true
        end,
      },
      AchievementMicroButton = MakeButton(achievementFrame),
      QuestLogMicroButton = MakeButton(questLogFrame),
      LFDMicroButton = MakeButton(pveFrame),
      EJMicroButton = MakeButton(encounterJournal),
      CollectionsMicroButton = MakeButton(collectionsJournal),
      GuildMicroButton = MakeButton(communitiesFrame),
      C_AddOns = {
        IsAddOnLoaded = function()
          return true
        end,
        LoadAddOn = function() end,
      },
      PlayerSpellsUtil = {
        ToggleSpellBookFrame = function()
          spellbookCalls = spellbookCalls + 1
          return true
        end,
      },
      securecallfunction = function(fn, ...)
        return fn(...)
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_game_menu_actions.lua" })
      local blockedActions = addon.UIGameMenuActions.BuildDefaultPanelUIActions(function()
        return true
      end)
      Assert.False(blockedActions.talents(), "talent action must be blocked during combat")

      local actions = addon.UIGameMenuActions.BuildDefaultPanelUIActions(function()
        return false
      end)
      Assert.True(actions.professions(), "profession action must click the micro button through the secure path")
      Assert.Equal(professionClicks, 1, "profession micro button must be clicked exactly once")
      Assert.True(actions.spellbook(), "spellbook action must use PlayerSpellsUtil when available")
      Assert.Equal(spellbookCalls, 1, "spellbook util must be invoked")
      Assert.True(actions.achievements(), "achievement action must click the matching micro button")
      Assert.True(actions.quests(), "quest action must open through the quest micro button")
      Assert.True(actions.dungeons(), "dungeon action must open through the LFD micro button")
      Assert.True(actions.journal(), "journal action must open through the encounter journal button")
      Assert.True(actions.collections(), "collections action must open through the collections button")
      Assert.True(actions.guild(), "guild action must open through the guild button")
    end)
  end)

  test("UI game-menu addon actions resolve enabled addons and localized slash text", function()
    local slashArgs = nil
    local loadCalls = 0
    local loaded = { isiLive = true }

    WithGlobals({
      GetLocale = function()
        return "deDE"
      end,
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if addOnName == "Details" or addOnName == "isiLive" then
            return addOnName
          end
          return nil
        end,
        GetAddOnEnableState = function(_addOnName)
          return 2
        end,
        IsAddOnLoaded = function(addOnName)
          return loaded[addOnName] == true
        end,
        LoadAddOn = function(addOnName)
          loadCalls = loadCalls + 1
          loaded[addOnName] = true
        end,
      },
      SlashCmdList = {
        DETAILS = function(args)
          slashArgs = args
          return true
        end,
      },
      SLASH_DETAILS1 = "/details",
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_game_menu_actions.lua" })
      local actions = addon.UIGameMenuActions.BuildAddonPanelUIActions({
        custom = function()
          return true
        end,
      })

      Assert.True(actions.custom(), "addon action overrides must be merged")
      Assert.True(actions.details(), "Details action must run through the slash handler")
      Assert.Equal(slashArgs, "optionen", "German locale must use the localized Details slash arguments")
      Assert.Equal(loadCalls, 1, "unloaded enabled addon must be load-attempted before slash execution")

      local visible = addon.UIGameMenuActions.ResolveVisibleAddonPanelEntries()
      Assert.True(#visible >= 2, "visible addon entries must include enabled installed addons")
    end)
  end)

  test(
    "Settings panel exposes resetui action in reset section and styles Reset all Settings like the other buttons",
    function()
      local createFrameStub, createdFrames = BuildCreateFrameStub()
      local db = {}
      local resetUiCalls = 0
      local resetDbCalls = 0
      local lastPopupName = nil
      local staticPopupDialogs = {}

      WithGlobals({
        UIParent = {},
        IsiLiveDB = db,
        CreateFrame = createFrameStub,
        StaticPopupDialogs = staticPopupDialogs,
        StaticPopup_Show = function(name)
          lastPopupName = name
        end,
        Settings = {
          RegisterCanvasLayoutCategory = function(canvas, name)
            return { canvas = canvas, name = name }
          end,
          RegisterAddOnCategory = function() end,
        },
      }, function()
        local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
        local panel = addon.SettingsPanel.Create({
          getL = function()
            return {
              SETTINGS_SECTION_GENERAL = "General",
              SETTINGS_SECTION_BEHAVIOR = "Behavior",
              SETTINGS_SECTION_DISPLAY = "Display",
              SETTINGS_SECTION_DEBUG = "Debug",
              SETTINGS_LANGUAGE = "Language",
              SETTINGS_COMBAT_LOGGING = "Combat Logging",
              SETTINGS_DM_RESET = "DM Reset",
              SETTINGS_ESC_PANEL = "ESC Panel",
              SETTINGS_BG_ALPHA = "Background Opacity",
              SETTINGS_UI_SCALE = "UI Scale",
              SETTINGS_RESET_UI_POSITION = "Reset UI position (/isilive resetui)",
              SETTINGS_RESET_UI_POSITION_HINT = "Default: position center, UI scale 100%, background opacity 50%",
              SETTINGS_MINIMAP_BUTTON = "Minimap Button",
              SETTINGS_SYNC_ENABLED = "Addon Sync",
              SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
              SETTINGS_AUTO_CLOSE_ON_KEY_START = "Auto Close On Key Start",
              SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE = "Auto Close On Solo Change",
              SETTINGS_DEFAULT_OPEN_UI = "Default UI on Open",
              SETTINGS_DEFAULT_OPEN_UI_LAST = "Last Used",
              SETTINGS_DEFAULT_OPEN_UI_V = "V",
              SETTINGS_DEFAULT_OPEN_UI_H = "H",
              SETTINGS_DEFAULT_OPEN_UI_M2 = "M2",
              SETTINGS_QUEUE_DEBUG = "Queue Debug",
              SETTINGS_RUNTIME_LOG = "Runtime Log",
              SETTINGS_RESET_DB = "Reset All Settings",
            }
          end,
          getCurrentLocale = function()
            return "enUS"
          end,
          setLanguage = function() end,
          getDB = function()
            return db
          end,
          onResetMainFramePosition = function()
            resetUiCalls = resetUiCalls + 1
          end,
          onResetDB = function()
            resetDbCalls = resetDbCalls + 1
          end,
        })

        Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")

        local resetUiButton = nil
        local resetDbButton = nil
        for _, frame in ipairs(createdFrames) do
          if frame._settingKey == "SETTINGS_RESET_UI_POSITION" then
            resetUiButton = frame
          elseif frame._settingKey == "SETTINGS_RESET_DB" then
            resetDbButton = frame
          end
        end

        resetUiButton =
          Assert.NotNil(resetUiButton, "settings panel should create a resetui action button in the reset section")
        resetDbButton = Assert.NotNil(resetDbButton, "settings panel should create a reset all settings button")
        ---@diagnostic disable: undefined-field
        Assert.Equal(
          resetUiButton.label:GetText(),
          "Reset UI position (/isilive resetui)",
          "resetui button should use the localized display label"
        )
        Assert.Equal(
          resetUiButton.label:GetText(),
          "Reset UI position (/isilive resetui)",
          "resetui button should keep its clickable label"
        )
        Assert.NotNil(resetUiButton.hint, "resetui hint should exist under the button")
        Assert.Equal(
          resetUiButton.hint:GetText(),
          "Default: position center, UI scale 100%, background opacity 50%",
          "resetui button should explain the default values"
        )
        Assert.Equal(
          resetDbButton.label:GetText(),
          "Reset All Settings",
          "reset all settings button should keep its label"
        )
        Assert.NotNil(resetUiButton.hoverGlow, "resetui button should expose a hover glow for clickable feedback")
        Assert.True(
          resetUiButton._point[5] > resetDbButton._point[5],
          "resetui action should sit above reset-all inside the administrative reset area"
        )
        Assert.NotNil(
          resetDbButton.hoverGlow,
          "reset all settings button should expose a hover glow for clickable feedback"
        )
        Assert.NotNil(resetDbButton._backdropColor, "reset all settings button should use the styled backdrop")
        Assert.NotNil(
          resetDbButton._backdropBorderColor,
          "reset all settings button should use the styled backdrop border"
        )
        Assert.False(
          resetDbButton._template == "UIPanelButtonTemplate",
          "reset all settings button should no longer use the legacy UIPanelButtonTemplate"
        )
        local onClickResetUi = resetUiButton._scripts and resetUiButton._scripts.OnClick or nil
        local onClickResetDb = resetDbButton._scripts and resetDbButton._scripts.OnClick or nil
        local onEnterResetDb = resetDbButton._scripts and resetDbButton._scripts.OnEnter or nil
        local onLeaveResetDb = resetDbButton._scripts and resetDbButton._scripts.OnLeave or nil
        onClickResetUi = Assert.NotNil(onClickResetUi, "resetui button should define OnClick")
        onClickResetDb = Assert.NotNil(onClickResetDb, "reset all settings button should define OnClick")
        onEnterResetDb = Assert.NotNil(onEnterResetDb, "reset all settings button should define OnEnter")
        onLeaveResetDb = Assert.NotNil(onLeaveResetDb, "reset all settings button should define OnLeave")

        onEnterResetDb(resetDbButton)
        Assert.NotNil(
          resetDbButton._backdropColor,
          "hover should keep the reset all settings button visually highlighted"
        )
        onLeaveResetDb(resetDbButton)
        Assert.NotNil(resetDbButton._backdropColor, "leave should restore the reset all settings button backdrop")

        onClickResetUi(resetUiButton, "LeftButton")
        Assert.Equal(resetUiCalls, 0, "resetui button should wait for confirmation before calling the reset helper")
        Assert.NotNil(lastPopupName, "resetui button should open a confirmation popup")
        Assert.NotNil(staticPopupDialogs[lastPopupName], "resetui confirmation popup should be registered")
        staticPopupDialogs[lastPopupName].OnCancel()
        Assert.Equal(resetUiCalls, 0, "resetui cancel should abort the reset helper")

        onClickResetDb(resetDbButton, "LeftButton")
        Assert.Equal(
          resetDbCalls,
          0,
          "reset all settings button should wait for confirmation before calling the DB reset"
        )
        Assert.NotNil(lastPopupName, "reset all settings button should open a confirmation popup")
        Assert.NotNil(staticPopupDialogs[lastPopupName], "reset all settings confirmation popup should be registered")
        staticPopupDialogs[lastPopupName].OnAccept()
        ---@diagnostic enable: undefined-field

        Assert.Equal(resetUiCalls, 0, "resetui cancel should not call the reset-main-frame callback")
        Assert.Equal(resetDbCalls, 1, "reset all settings button should call the DB reset callback once")
      end)
    end
  )
end

local function RegisterSettingsPanelTests(test, Assert, WithGlobals, LoadAddonModules)
  test("UICommon background alpha defaults to 50 percent and honors saved override", function()
    WithGlobals({
      IsiLiveDB = nil,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      Assert.Equal(addon.UICommon.GetBackgroundAlpha(), 0.50, "default background alpha should be 50 percent")
    end)

    WithGlobals({
      IsiLiveDB = { bgAlpha = 0.65 },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      Assert.Equal(addon.UICommon.GetBackgroundAlpha(), 0.65, "saved background alpha should override the default")
    end)
  end)

  test("Settings panel background opacity keeps 50 percent default until user changes it", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    local bgAlphaChanges = 0
    local lastBgAlpha = nil

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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
        onBgAlphaChange = function(val)
          bgAlphaChanges = bgAlphaChanges + 1
          lastBgAlpha = val
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")
      Assert.Nil(db.bgAlpha, "default background alpha should not be written just by opening settings")

      local slider = nil
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "Slider" and frame._settingKey == "SETTINGS_BG_ALPHA" then
          slider = frame
          break
        end
      end

      slider = Assert.NotNil(slider, "settings panel should create a background alpha slider")
      ---@diagnostic disable: undefined-field
      Assert.Equal(slider:GetValue(), 0.50, "slider should initialize with a 50 percent default")

      panel.Refresh()

      Assert.Nil(db.bgAlpha, "refresh should not persist the default background alpha")
      Assert.Equal(bgAlphaChanges, 0, "refresh should not fire background alpha change callbacks")

      local onValueChanged = slider._scripts and slider._scripts.OnValueChanged or nil
      onValueChanged = Assert.NotNil(onValueChanged, "slider should define OnValueChanged")
      onValueChanged(slider, 0.70)
      ---@diagnostic enable: undefined-field

      Assert.Equal(db.bgAlpha, 0.70, "user changes should be persisted")
      Assert.Equal(lastBgAlpha, 0.70, "user changes should call the background alpha callback")
      Assert.Equal(bgAlphaChanges, 1, "user changes should fire exactly one callback")
    end)
  end)

  RegisterSettingsPanelResetActionTests(test, Assert, WithGlobals, LoadAddonModules)

  test("Settings panel exposes stats box position lock toggle", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = { statsBoxLocked = false }
    local lockCalls = 0
    local lastLocked = nil

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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
        onStatsBoxLockToggle = function(locked)
          lockCalls = lockCalls + 1
          lastLocked = locked
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")

      local lockCheck = nil
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "CheckButton" and frame._settingKey == "SETTINGS_STATS_BOX_LOCKED" then
          lockCheck = frame
          break
        end
      end
      lockCheck = Assert.NotNil(lockCheck, "settings panel should create a stats-box lock checkbox")

      ---@diagnostic disable: undefined-field
      Assert.False(lockCheck:GetChecked(), "stats-box lock checkbox should reflect the unlocked default")
      lockCheck:SetChecked(true)
      local onClick = Assert.NotNil(lockCheck._scripts.OnClick, "stats-box lock checkbox should define OnClick")
      onClick(lockCheck)
      ---@diagnostic enable: undefined-field

      Assert.True(db.statsBoxLocked, "checking stats-box lock should persist true to DB")
      Assert.Equal(lockCalls, 1, "checking stats-box lock should invoke live callback once")
      Assert.Equal(lastLocked, true, "stats-box lock callback should receive true")

      panel.Refresh()
      Assert.True(lockCheck:GetChecked(), "refresh should keep stats-box lock visually checked")
    end)
  end)

  test("Settings panel exposes stats box detail checkboxes and display mode", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {
      statsBoxDisplayMode = "value",
      statsBoxShowLeech = true,
      statsBoxShowSpeed = false,
      statsBoxShowDurability = true,
      statsBoxShowStamina = true,
      statsBoxShowAvoidance = true,
    }
    local optionChanges = 0

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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
            SETTINGS_STATS_BOX_DISPLAY_MODE = "Stats box numbers",
            SETTINGS_STATS_BOX_DISPLAY_MODE_BOTH = "Values + percentages",
            SETTINGS_STATS_BOX_DISPLAY_MODE_VALUE = "Values only",
            SETTINGS_STATS_BOX_DISPLAY_MODE_PERCENT = "Percentages only",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
        onStatsBoxOptionsChange = function()
          optionChanges = optionChanges + 1
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")

      local checks = {}
      local percentButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "CheckButton" and type(frame._settingKey) == "string" then
          checks[frame._settingKey] = frame
        end
        if frame._frameType == "Button" and frame._optionValue == "percent" then
          percentButton = frame
        end
      end

      Assert.NotNil(checks.SETTINGS_STATS_BOX_SHOW_LEECH, "stats-box details should include Leech checkbox")
      Assert.NotNil(checks.SETTINGS_STATS_BOX_SHOW_SPEED, "stats-box details should include Speed checkbox")
      Assert.NotNil(checks.SETTINGS_STATS_BOX_SHOW_DURABILITY, "stats-box details should include durability checkbox")
      Assert.NotNil(checks.SETTINGS_STATS_BOX_SHOW_STAMINA, "stats-box details should include stamina checkbox")
      Assert.NotNil(checks.SETTINGS_STATS_BOX_SHOW_AVOIDANCE, "stats-box details should include avoidance checkbox")
      Assert.False(checks.SETTINGS_STATS_BOX_SHOW_SPEED:GetChecked(), "Speed checkbox should reflect disabled DB state")

      checks.SETTINGS_STATS_BOX_SHOW_SPEED:SetChecked(true)
      checks.SETTINGS_STATS_BOX_SHOW_SPEED._scripts.OnClick(checks.SETTINGS_STATS_BOX_SHOW_SPEED)
      Assert.True(db.statsBoxShowSpeed, "checking Speed should persist true to DB")
      Assert.Equal(optionChanges, 1, "checking one stats-box detail should refresh the live stats box")

      percentButton = Assert.NotNil(percentButton, "stats-box display mode should expose a percent option")
      percentButton._scripts.OnClick(percentButton)
      Assert.Equal(db.statsBoxDisplayMode, "percent", "percent mode button should persist the display mode")
      Assert.Equal(optionChanges, 2, "changing display mode should refresh the live stats box")
    end)
  end)

  test("Settings display section separates child groups with quiet and cool hierarchy lines", function()
    local createFrameStub = BuildCreateFrameStub()
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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" }, {
        UICommon = {
          Colors = {
            TEXT_DIM = { 0.5, 0.5, 0.6 },
            TEXT_NORMAL = { 0.85, 0.85, 0.9 },
            ACCENT_BLUE = { 0.1, 0.2, 0.8 },
            BORDER_DEFAULT = { 0.2, 0.22, 0.28, 0.5 },
          },
        },
      })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      local textures = Assert.NotNil(panel.content, "settings panel should expose content")._textures or {}
      local childSeparators = 0
      local sectionSeparators = 0
      for _, texture in ipairs(textures) do
        if texture._isiLiveSettingsSeparator == "child" then
          childSeparators = childSeparators + 1
          Assert.Equal(texture._height, 1, "child separator must be a thin one-pixel line")
          Assert.Equal(texture._color[1], 0.35, "child separator should use the subtle border color")
          Assert.Equal(texture._color[4], 0.28, "child separator should stay visually lighter than section lines")
        elseif texture._isiLiveSettingsSeparator == "section" then
          sectionSeparators = sectionSeparators + 1
          Assert.Equal(texture._height, 2, "section separator should remain stronger than child lines")
          Assert.Equal(texture._color[1], 0.26, "section separator should use the cool title-border red channel")
          Assert.Equal(texture._color[4], 0.55, "section separator fallback should use restrained cool-border alpha")
        end
      end

      Assert.True(childSeparators >= 2, "display settings should separate distinct child groups with thin lines")
      Assert.True(sectionSeparators >= 2, "main settings topics should keep their cool section separators")
    end)
  end)

  test("Settings section headers use cool section-card styling", function()
    local createFrameStub = BuildCreateFrameStub()
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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      local generalHeader = nil
      for _, fontString in ipairs(panel.content._fontStrings or {}) do
        if fontString:GetText() == "General" then
          generalHeader = fontString
          break
        end
      end

      generalHeader = Assert.NotNil(generalHeader, "settings panel should render the General section header")
      Assert.Equal(generalHeader._fontObject, "GameFontNormal", "section headers should use the larger title font")
      local r, g, b, a = generalHeader:GetTextColor()
      Assert.Equal(r, 0.64, "section headers should use the shared cool-section red channel")
      Assert.Equal(g, 0.80, "section headers should use the shared cool-section green channel")
      Assert.Equal(b, 0.96, "section headers should use the shared cool-section blue channel")
      Assert.Equal(a, 1, "section headers should be fully opaque")
      Assert.Equal(
        generalHeader._isiLiveSurfaceRole,
        "settings_section",
        "section headers should expose their surface role"
      )
      Assert.NotNil(generalHeader._isiLiveSectionSurface, "section headers should render a quiet card surface")
    end)
  end)

  test("Settings language buttons sit below the language description", function()
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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_languages.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_LANGUAGE_DESC = "Changes the isiLive addon language.",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      local description = nil
      for _, fontString in ipairs(panel.content._fontStrings or {}) do
        if fontString:GetText() == "Changes the isiLive addon language." then
          description = fontString
          break
        end
      end

      local firstLanguageButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "Button" and frame._languageTag == "enUS" then
          firstLanguageButton = frame
          break
        end
      end

      description = Assert.NotNil(description, "language description should be rendered")
      firstLanguageButton = Assert.NotNil(firstLanguageButton, "English language button should be rendered")
      local descriptionBottom = description._point[5] - description:GetStringHeight()
      Assert.True(
        firstLanguageButton._point[5] <= descriptionBottom - 4,
        "language buttons must be placed below the description text"
      )
      Assert.Equal(firstLanguageButton._point[4], 16, "language buttons must start at the settings row left edge")
    end)
  end)

  test("Settings panel lets the user choose the default layout on open", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    local defaultLayoutChanges = {}

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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_NAME_MAX_CHARS = "Name Length",
            SETTINGS_TELEPORT_COLUMNS = "Teleport Grid Columns",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
            SETTINGS_AUTO_CLOSE_ON_KEY_START = "Auto Close On Key Start",
            SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE = "Auto Close On Solo Change",
            SETTINGS_DEFAULT_OPEN_UI = "Default UI on Open",
            SETTINGS_DEFAULT_OPEN_UI_LAST = "Last Used",
            SETTINGS_DEFAULT_OPEN_UI_V = "V",
            SETTINGS_DEFAULT_OPEN_UI_H = "H",
            SETTINGS_DEFAULT_OPEN_UI_M2 = "M2",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
        onDefaultLayoutModeChange = function(mode)
          defaultLayoutChanges[#defaultLayoutChanges + 1] = mode or false
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")
      Assert.Nil(db.rosterDefaultLayoutMode, "default layout should stay unset until the user chooses one")

      local expandedButton = nil
      local m2Button = nil
      local lastUsedButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame._optionValue == "expanded" then
          expandedButton = frame
        elseif frame._optionValue == "compact_main_horizontal" then
          m2Button = frame
        elseif frame._optionValue == "last_used" and frame._optionLabelKey == "SETTINGS_DEFAULT_OPEN_UI_LAST" then
          lastUsedButton = frame
        end
      end

      Assert.Nil(expandedButton, "settings panel should hide the expanded default-layout option")
      m2Button = Assert.NotNil(m2Button, "settings panel should create an M2 default-layout button")
      lastUsedButton = Assert.NotNil(lastUsedButton, "settings panel should create a last-used default-layout button")
      local defaultLayoutLabel = nil
      for _, fontString in ipairs(panel.content._fontStrings or {}) do
        if fontString:GetText() == "Default UI on Open" then
          defaultLayoutLabel = fontString
          break
        end
      end
      defaultLayoutLabel = Assert.NotNil(defaultLayoutLabel, "settings panel should create a default-layout label")
      local _, _, _, _, labelY = defaultLayoutLabel:GetPoint()
      local _, _, _, _, buttonY = lastUsedButton:GetPoint()
      Assert.Equal(
        defaultLayoutLabel._width,
        668,
        "top-aligned default-layout label must use the full settings text width"
      )
      Assert.True(buttonY <= labelY - 30, "default-layout option buttons must sit on a separate row below the label")
      ---@diagnostic disable: undefined-field
      Assert.Equal(
        m2Button._backdropColor[4],
        0.25,
        "M2 should be highlighted by default when no saved default layout exists"
      )
      Assert.Equal(
        lastUsedButton._backdropColor[4],
        0.7,
        "Last Used should stay unselected by default when no saved default layout exists"
      )
      local onClickM2 = (m2Button._scripts and m2Button._scripts.OnClick) or nil
      local onClickLast = (lastUsedButton._scripts and lastUsedButton._scripts.OnClick) or nil
      onClickM2 = Assert.NotNil(onClickM2, "M2 button should define OnClick")
      onClickLast = Assert.NotNil(onClickLast, "Last Used button should define OnClick")

      onClickM2(m2Button, "LeftButton")
      onClickLast(lastUsedButton, "LeftButton")

      Assert.Equal(
        db.rosterDefaultLayoutMode,
        "last_used",
        "choosing Last Used should store the explicit last-used sentinel"
      )
      Assert.Equal(
        defaultLayoutChanges[1],
        "compact_main_horizontal",
        "clicking M2 should persist the normalized layout mode and notify the callback"
      )
      Assert.Equal(
        defaultLayoutChanges[2],
        false,
        "clicking Last Used should notify the callback with a nil layout mode"
      )
    end)
  end)

  test("Settings panel fits localized default-layout option buttons", function()
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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "Allgemein",
            SETTINGS_SECTION_DISPLAY = "Anzeige",
            SETTINGS_SECTION_BEHAVIOR = "Verhalten",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Sprache",
            SETTINGS_COMBAT_LOGGING = "Erweiterte Kampfprotokollierung",
            SETTINGS_DM_RESET = "Schadensmeter zuruecksetzen",
            SETTINGS_ESC_PANEL = "ESC-Menue-Schnellzugriffe",
            SETTINGS_BG_ALPHA = "Hintergrund-Deckkraft",
            SETTINGS_UI_SCALE = "UI-Skalierung",
            SETTINGS_MINIMAP_BUTTON = "Minimap-Button",
            SETTINGS_SYNC_ENABLED = "Addon-Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto-Open bei M+ Queue",
            SETTINGS_AUTO_CLOSE_ON_KEY_START = "Auto-Close bei Key-Start",
            SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE = "Auto-Close beim Gruppenende",
            SETTINGS_DEFAULT_OPEN_UI = "Standard-Layout beim Oeffnen",
            SETTINGS_DEFAULT_OPEN_UI_LAST = "Zuletzt",
            SETTINGS_DEFAULT_OPEN_UI_V = "V",
            SETTINGS_DEFAULT_OPEN_UI_H = "H",
            SETTINGS_DEFAULT_OPEN_UI_M2 = "M+",
            SETTINGS_QUEUE_DEBUG = "Queue-Debug",
            SETTINGS_RUNTIME_LOG = "Runtime-Log",
          }
        end,
        getCurrentLocale = function()
          return "deDE"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      local lastUsedButton = nil
      local verticalButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame._optionValue == "last_used" and frame._optionLabelKey == "SETTINGS_DEFAULT_OPEN_UI_LAST" then
          lastUsedButton = frame
        elseif frame._optionValue == "compact_vertical" and frame._optionLabelKey == "SETTINGS_DEFAULT_OPEN_UI_V" then
          verticalButton = frame
        end
      end

      lastUsedButton = Assert.NotNil(lastUsedButton, "settings panel should create the localized last-used button")
      verticalButton = Assert.NotNil(verticalButton, "settings panel should create the vertical-layout button")

      local _, _, _, lastX = lastUsedButton:GetPoint()
      local _, _, _, verticalX = verticalButton:GetPoint()
      local measuredLastTextWidth = lastUsedButton.label:GetStringWidth()
      Assert.True(
        lastUsedButton._width >= measuredLastTextWidth + 22,
        "localized last-used button must fit its rendered label"
      )
      Assert.True(
        verticalX >= lastX + lastUsedButton._width + 4,
        "vertical layout button must be anchored after the fitted last-used button"
      )
    end)
  end)

  test("Settings panel normalizes persisted expanded default layout to M2", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {
      rosterDefaultLayoutMode = "expanded",
    }
    local defaultLayoutChanges = {}

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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
            SETTINGS_AUTO_CLOSE_ON_KEY_START = "Auto Close On Key Start",
            SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE = "Auto Close On Solo Change",
            SETTINGS_DEFAULT_OPEN_UI = "Default UI on Open",
            SETTINGS_DEFAULT_OPEN_UI_LAST = "Last Used",
            SETTINGS_DEFAULT_OPEN_UI_V = "V",
            SETTINGS_DEFAULT_OPEN_UI_H = "H",
            SETTINGS_DEFAULT_OPEN_UI_M2 = "M2",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
        onDefaultLayoutModeChange = function(mode)
          defaultLayoutChanges[#defaultLayoutChanges + 1] = mode or false
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")

      local expandedButton = nil
      local m2Button = nil
      for _, frame in ipairs(createdFrames) do
        if frame._optionValue == "expanded" then
          expandedButton = frame
        elseif frame._optionValue == "compact_main_horizontal" then
          m2Button = frame
        end
      end

      Assert.Nil(expandedButton, "settings panel should not expose the expanded layout option")
      m2Button = Assert.NotNil(m2Button, "settings panel should still expose the M2 layout option")
      ---@diagnostic disable: undefined-field
      Assert.Equal(
        m2Button._backdropColor[4],
        0.25,
        "persisted expanded defaults should be normalized onto the visible M2 option"
      )

      local onClickM2 = (m2Button._scripts and m2Button._scripts.OnClick) or nil
      onClickM2 = Assert.NotNil(onClickM2, "M2 button should define OnClick")
      onClickM2(m2Button, "LeftButton")
      ---@diagnostic enable: undefined-field

      Assert.Equal(
        db.rosterDefaultLayoutMode,
        "compact_main_horizontal",
        "saving the normalized visible option should persist M2 instead of expanded"
      )
      Assert.Equal(
        defaultLayoutChanges[1],
        "compact_main_horizontal",
        "callback should receive the normalized visible layout mode"
      )
    end)
  end)

  test("Settings hearthstone selector shows English toy names for non-German addon locales", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = { hearthstoneChoice = "random" }

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      C_ToyBox = {
        GetToyInfo = function(itemID)
          if itemID == 180290 then
            return itemID, "Nachtfae-Ruhestein", "Interface\\Icons\\inv_hearthstonepet"
          end
          return nil
        end,
      },
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      addon.UI = addon.UI or {}
      addon.UI.CollectOwnedHearthstoneToys = function()
        return { 180290 }
      end
      addon.UI.GetHearthstoneToyEnglishName = function(itemID)
        if itemID == 180290 then
          return "Night Fae Hearthstone"
        end
        return nil
      end

      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_HEARTHSTONE_SELECT = "Hearthstone Selection",
            SETTINGS_HEARTHSTONE_RANDOM = "Random owned Hearthstone",
            SETTINGS_HEARTHSTONE_DEFAULT = "Default Hearthstone (6948)",
          }
        end,
        getCurrentLocale = function()
          return "frFR"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })
      Assert.NotNil(panel, "settings panel should be created")

      local dropdown = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_HEARTHSTONE_SELECT" then
          dropdown = frame
          break
        end
      end
      dropdown = Assert.NotNil(dropdown, "hearthstone selector dropdown must exist")
      local options = dropdown._options or {}
      local found = false
      for _, option in ipairs(options) do
        if option.value == "toy:180290" then
          found = true
          Assert.Equal(
            option.fallback,
            "Night Fae Hearthstone",
            "non-German addon locale must use the verified English toy name"
          )
        end
        Assert.False(option.fallback == "180290", "selector must not show a raw item id as its label")
      end
      Assert.True(found, "owned toy with a verified name must be selectable")
    end)
  end)

  test("Settings hearthstone option builder uses DB and client locale fallbacks", function()
    local requestedItemIDs = {}
    local createdItemIDs = {}
    WithGlobals({
      GetLocale = function()
        return "deDE"
      end,
      C_Item = {
        GetItemNameByID = function(itemID)
          if itemID == 222 then
            return "C_Item Hearthstone"
          end
          return nil
        end,
      },
      Item = {
        CreateFromItemID = function(itemID)
          createdItemIDs[#createdItemIDs + 1] = itemID
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_settings_hearthstone.lua" }, {
        UI = {
          CollectOwnedHearthstoneToys = function()
            return { 222, 333, "bad" }
          end,
        },
      })
      local options = addon.SettingsHearthstone.BuildOptions({
        getCurrentLocale = function()
          return ""
        end,
        getDB = function()
          return { locale = "deDE" }
        end,
      }, {})

      Assert.Equal(options[3].value, "toy:222", "German DB locale fallback must keep resolved C_Item toy")
      Assert.Equal(options[3].fallback, "C_Item Hearthstone", "C_Item name must be used for German toy labels")
      Assert.Equal(#createdItemIDs, 1, "unresolved toy name must request item data through Item fallback")
      Assert.Equal(createdItemIDs[1], 333, "Item fallback must request the unresolved toy ID")
      Assert.Equal(#requestedItemIDs, 0, "test guard: C_Item request path is not configured here")
    end)
  end)

  test("Settings hearthstone option builder requests C_Item data for unresolved toys", function()
    local requestedItemIDs = {}
    WithGlobals({
      GetLocale = function()
        return "deDE"
      end,
      C_Item = {
        RequestLoadItemDataByID = function(itemID)
          requestedItemIDs[#requestedItemIDs + 1] = itemID
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_settings_hearthstone.lua" }, {
        UI = {
          CollectOwnedHearthstoneToys = function()
            return { 444 }
          end,
        },
      })
      local options = addon.SettingsHearthstone.BuildOptions(nil, nil)

      Assert.Equal(#options, 2, "unresolved toy names must not be shown as numeric fallback labels")
      Assert.Equal(requestedItemIDs[1], 444, "C_Item request path must warm unresolved toy item data")
    end)
  end)

  test("Settings hearthstone selector uses client-localized toy names for German addon locale", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = { hearthstoneChoice = "random" }
    local toyName = nil
    local requestedItemID = nil

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      C_ToyBox = {
        GetToyInfo = function(itemID)
          return itemID, toyName, "Interface\\Icons\\inv_hearthstonepet"
        end,
      },
      C_Item = {
        RequestLoadItemDataByID = function(itemID)
          requestedItemID = itemID
        end,
      },
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      addon.UI = addon.UI or {}
      addon.UI.CollectOwnedHearthstoneToys = function()
        return { 180290 }
      end

      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_HEARTHSTONE_SELECT = "Hearthstone Selection",
            SETTINGS_HEARTHSTONE_RANDOM = "Random owned Hearthstone",
            SETTINGS_HEARTHSTONE_DEFAULT = "Default Hearthstone (6948)",
          }
        end,
        getCurrentLocale = function()
          return "deDE"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })
      Assert.NotNil(panel, "settings panel should be created")

      local dropdown = nil
      local itemDataFrame = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_HEARTHSTONE_SELECT" then
          dropdown = frame
        elseif frame.IsEventRegistered and frame:IsEventRegistered("GET_ITEM_INFO_RECEIVED") then
          itemDataFrame = frame
        end
      end
      dropdown = Assert.NotNil(dropdown, "hearthstone selector dropdown must exist")
      itemDataFrame = Assert.NotNil(itemDataFrame, "settings must refresh when item info becomes available")
      Assert.Equal(requestedItemID, 180290, "missing toy name must request item data")
      for _, option in ipairs(dropdown._options or {}) do
        Assert.False(option.value == "toy:180290", "uncached toy name must not be shown as a raw numeric fallback")
      end

      toyName = "Nachtfae-Ruhestein"
      itemDataFrame:FireEvent("GET_ITEM_INFO_RECEIVED", 180290, true)

      local found = false
      for _, option in ipairs(dropdown._options or {}) do
        if option.value == "toy:180290" then
          found = true
          Assert.Equal(
            option.fallback,
            "Nachtfae-Ruhestein",
            "loaded item info must refresh the German toy option label"
          )
        end
      end
      Assert.True(found, "loaded toy name must make the owned toy selectable")
    end)
  end)
end

local function RegisterSettingsPanelBehaviorTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Settings panel defaults Auto-Close on Key Start / Solo to disabled until the user turns it on", function()
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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
            SETTINGS_AUTO_CLOSE_ON_KEY_START = "Auto Close On Key Start",
            SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE = "Auto Close On Solo Change",
            SETTINGS_DEFAULT_OPEN_UI = "Default UI on Open",
            SETTINGS_DEFAULT_OPEN_UI_LAST = "Last Used",
            SETTINGS_DEFAULT_OPEN_UI_V = "V",
            SETTINGS_DEFAULT_OPEN_UI_H = "H",
            SETTINGS_DEFAULT_OPEN_UI_M2 = "M2",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")
      Assert.Nil(db.autoCloseOnKeyStart, "opening settings should not persist the default key-start auto-close value")

      local autoCloseCheck = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_AUTO_CLOSE_ON_KEY_START" then
          autoCloseCheck = frame
          break
        end
      end

      autoCloseCheck = Assert.NotNil(autoCloseCheck, "settings panel should create a key-start auto-close checkbox")
      ---@diagnostic disable: undefined-field
      Assert.False(
        autoCloseCheck:GetChecked(),
        "key-start auto-close should default to disabled when no saved value exists"
      )

      db.autoCloseOnKeyStart = false
      panel.Refresh()
      Assert.False(autoCloseCheck:GetChecked(), "refresh should honor an explicit false value")

      db.autoCloseOnKeyStart = true
      panel.Refresh()
      Assert.True(autoCloseCheck:GetChecked(), "refresh should honor an explicit true override")
      ---@diagnostic enable: undefined-field
    end)
  end)

  test("Settings panel defaults combat fade to disabled until the user turns it on", function()
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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
            SETTINGS_AUTO_CLOSE_ON_KEY_START = "Auto Close On Key Start",
            SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE = "Auto Close On Solo Change",
            SETTINGS_DEFAULT_OPEN_UI = "Default UI on Open",
            SETTINGS_DEFAULT_OPEN_UI_LAST = "Last Used",
            SETTINGS_DEFAULT_OPEN_UI_V = "V",
            SETTINGS_DEFAULT_OPEN_UI_H = "H",
            SETTINGS_DEFAULT_OPEN_UI_M2 = "M2",
            SETTINGS_COMBAT_FADE_MM = "Fade out in Combat (M2 only)",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")
      Assert.Nil(db.combatFadeMM, "opening settings should not persist the combat fade default")

      local combatFadeCheck = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_COMBAT_FADE_MM" then
          combatFadeCheck = frame
          break
        end
      end

      combatFadeCheck = Assert.NotNil(combatFadeCheck, "settings panel should create a combat fade checkbox")
      ---@diagnostic disable: undefined-field
      Assert.False(combatFadeCheck:GetChecked(), "combat fade should default to disabled when no saved value exists")

      panel.Refresh()

      Assert.Nil(db.combatFadeMM, "refresh should not persist the combat fade default")

      combatFadeCheck:SetChecked(true)
      local onClick = combatFadeCheck._scripts and combatFadeCheck._scripts.OnClick or nil
      onClick = Assert.NotNil(onClick, "combat fade checkbox should define OnClick")
      onClick(combatFadeCheck)
      ---@diagnostic enable: undefined-field

      Assert.True(db.combatFadeMM, "user enabling combat fade should be persisted")
      Assert.True(combatFadeCheck:GetChecked(), "user enabling combat fade should keep the checkbox checked")
    end)
  end)

  test("Settings panel refresh localizes behavior auto and raid notes", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    local activeLocale = "enUS"

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
      local addon = LoadAddonModules({ "isiLive_texts.lua", "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local localeTexts = addon.Texts.GetLocaleTables()
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return localeTexts[activeLocale] or localeTexts.enUS
        end,
        getCurrentLocale = function()
          return activeLocale
        end,
        setLanguage = function(locale)
          activeLocale = locale
        end,
        getDB = function()
          return db
        end,
      })

      local autoNote = nil
      local raidNote = nil
      for _, fontString in ipairs(panel.content._fontStrings or {}) do
        if fontString:GetText() == localeTexts.enUS.SETTINGS_AUTO_TRIGGERS_NOTE then
          autoNote = fontString
        elseif fontString:GetText() == localeTexts.enUS.SETTINGS_RAID_TRANSITION_NOTE then
          raidNote = fontString
        end
      end
      autoNote = Assert.NotNil(autoNote, "settings panel should create the auto-trigger note")
      raidNote = Assert.NotNil(raidNote, "settings panel should create the raid behavior note")
      Assert.Equal(autoNote._sectionKey, "SETTINGS_AUTO_TRIGGERS_NOTE", "auto-trigger note should keep its locale key")
      Assert.Equal(raidNote._sectionKey, "SETTINGS_RAID_TRANSITION_NOTE", "raid note should keep its locale key")
      local hearthstoneDropdown = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_HEARTHSTONE_SELECT" then
          hearthstoneDropdown = frame
          break
        end
      end
      hearthstoneDropdown = Assert.NotNil(hearthstoneDropdown, "settings panel should create the hearthstone selector")
      Assert.NotNil(hearthstoneDropdown._label, "hearthstone selector must expose its localized label")

      for locale, texts in pairs(localeTexts) do
        activeLocale = locale
        panel.Refresh()
        Assert.Equal(
          autoNote:GetText(),
          texts.SETTINGS_AUTO_TRIGGERS_NOTE,
          "auto-trigger note must refresh for " .. locale
        )
        Assert.Equal(raidNote:GetText(), texts.SETTINGS_RAID_TRANSITION_NOTE, "raid note must refresh for " .. locale)
        Assert.Equal(
          hearthstoneDropdown._label:GetText(),
          texts.SETTINGS_HEARTHSTONE_SELECT,
          "hearthstone selector label must refresh for " .. locale
        )
      end
    end)
  end)

  test("Locale hearthstone settings strings are localized per supported language", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local localeTexts = addon.Texts.GetLocaleTables()
    Assert.Equal(
      localeTexts.deDE.SETTINGS_HEARTHSTONE_SELECT,
      "Ruhestein-Auswahl",
      "German hearthstone selector label must not fall back to English"
    )
    Assert.Equal(
      localeTexts.deDE.SETTINGS_HEARTHSTONE_RANDOM,
      "Zufaelliger eigener Ruhestein",
      "German random hearthstone option must be localized"
    )
    Assert.Equal(
      localeTexts.deDE.SETTINGS_HEARTHSTONE_DEFAULT,
      "Standard-Ruhestein (6948)",
      "German default hearthstone option must be localized"
    )

    for locale, texts in pairs(localeTexts) do
      Assert.True(
        type(texts.SETTINGS_HEARTHSTONE_SELECT) == "string" and texts.SETTINGS_HEARTHSTONE_SELECT ~= "",
        "hearthstone selector label must be present for " .. locale
      )
      Assert.True(
        type(texts.SETTINGS_HEARTHSTONE_RANDOM) == "string" and texts.SETTINGS_HEARTHSTONE_RANDOM ~= "",
        "random hearthstone option must be present for " .. locale
      )
      Assert.True(
        type(texts.SETTINGS_HEARTHSTONE_DEFAULT) == "string" and texts.SETTINGS_HEARTHSTONE_DEFAULT ~= "",
        "default hearthstone option must be present for " .. locale
      )
      if locale ~= "deDE" then
        Assert.False(
          texts.SETTINGS_HEARTHSTONE_SELECT:find("Ruhestein", 1, true) ~= nil,
          "non-German hearthstone selector label must not contain German text for " .. locale
        )
        Assert.False(
          texts.SETTINGS_HEARTHSTONE_RANDOM:find("Ruhestein", 1, true) ~= nil,
          "non-German random hearthstone option must not contain German text for " .. locale
        )
        Assert.False(
          texts.SETTINGS_HEARTHSTONE_DEFAULT:find("Ruhestein", 1, true) ~= nil,
          "non-German default hearthstone option must not contain German text for " .. locale
        )
      end
    end
  end)

  test("Settings panel defaults Login / Reload auto-show and Key-End auto-open to enabled", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    local startupToggleStates = {}
    local keyEndToggleStates = {}

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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
            SETTINGS_AUTO_CLOSE_ON_KEY_START = "Auto Close On Key Start",
            SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE = "Auto Close On Solo Change",
            SETTINGS_AUTO_SHOW_MAIN_FRAME_ON_STARTUP = "Show on Login / Reload",
            SETTINGS_AUTO_OPEN_MAIN_FRAME_ON_KEY_END = "Auto Open on Key End",
            SETTINGS_DEFAULT_OPEN_UI = "Default UI on Open",
            SETTINGS_DEFAULT_OPEN_UI_LAST = "Last Used",
            SETTINGS_DEFAULT_OPEN_UI_V = "V",
            SETTINGS_DEFAULT_OPEN_UI_H = "H",
            SETTINGS_DEFAULT_OPEN_UI_M2 = "M2",
            SETTINGS_RAID_TRANSITION_BEHAVIOR = "Raid Behavior",
            SETTINGS_RAID_TRANSITION_BEHAVIOR_HIDE = "Raid Off",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
        onAutoShowMainFrameOnStartupToggle = function(enabled)
          startupToggleStates[#startupToggleStates + 1] = enabled and true or false
        end,
        onAutoOpenMainFrameOnKeyEndToggle = function(enabled)
          keyEndToggleStates[#keyEndToggleStates + 1] = enabled and true or false
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")
      Assert.Nil(db.autoShowMainFrameOnStartup, "opening settings should not persist the default startup auto-show")
      Assert.Nil(db.autoOpenMainFrameOnKeyEnd, "opening settings should not persist the default key-end auto-open")

      local startupCheck = nil
      local keyEndCheck = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_AUTO_SHOW_MAIN_FRAME_ON_STARTUP" then
          startupCheck = frame
        elseif frame._settingKey == "SETTINGS_AUTO_OPEN_MAIN_FRAME_ON_KEY_END" then
          keyEndCheck = frame
        end
      end

      startupCheck = Assert.NotNil(startupCheck, "settings panel should create a startup auto-show checkbox")
      keyEndCheck = Assert.NotNil(keyEndCheck, "settings panel should create a key-end auto-open checkbox")
      ---@diagnostic disable: undefined-field
      Assert.True(startupCheck:GetChecked(), "startup auto-show should default to enabled")
      Assert.True(keyEndCheck:GetChecked(), "key-end auto-open should default to enabled")

      local onClickStartup = startupCheck._scripts and startupCheck._scripts.OnClick or nil
      local onClickKeyEnd = keyEndCheck._scripts and keyEndCheck._scripts.OnClick or nil
      onClickStartup = Assert.NotNil(onClickStartup, "startup checkbox should define OnClick")
      onClickKeyEnd = Assert.NotNil(onClickKeyEnd, "key-end checkbox should define OnClick")

      startupCheck:SetChecked(false)
      onClickStartup(startupCheck)
      keyEndCheck:SetChecked(false)
      onClickKeyEnd(keyEndCheck)

      Assert.False(db.autoShowMainFrameOnStartup, "disabling startup auto-show should persist false")
      Assert.False(db.autoOpenMainFrameOnKeyEnd, "disabling key-end auto-open should persist false")
      Assert.Equal(startupToggleStates[1], false, "startup checkbox should notify its callback")
      Assert.Equal(keyEndToggleStates[1], false, "key-end checkbox should notify its callback")
      ---@diagnostic enable: undefined-field
    end)
  end)
end

local function RegisterSettingsPanelAdvancedTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Settings panel does not expose the removed roster column guides option", function()
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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
            SETTINGS_AUTO_CLOSE_ON_KEY_START = "Auto Close On Key Start",
            SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE = "Auto Close On Solo Change",
            SETTINGS_DEFAULT_OPEN_UI = "Default UI on Open",
            SETTINGS_DEFAULT_OPEN_UI_LAST = "Last Used",
            SETTINGS_DEFAULT_OPEN_UI_V = "V",
            SETTINGS_DEFAULT_OPEN_UI_H = "H",
            SETTINGS_DEFAULT_OPEN_UI_M2 = "M2",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")

      local guideCheck = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_ROSTER_COLUMN_GUIDES" then
          guideCheck = frame
          break
        end
      end

      Assert.Nil(guideCheck, "settings panel must not create a column-guides checkbox")
      panel.Refresh()
      Assert.Nil(db.showRosterColumnGuides, "removed setting must not be written by settings refresh")
    end)
  end)

  test("Settings panel defaults Timeways Navigator to enabled until the user turns it off", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    local callbackStates = {}

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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
            SETTINGS_AUTO_CLOSE_ON_KEY_START = "Auto Close On Key Start",
            SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE = "Auto Close On Solo Change",
            SETTINGS_DEFAULT_OPEN_UI = "Default UI on Open",
            SETTINGS_DEFAULT_OPEN_UI_LAST = "Last Used",
            SETTINGS_DEFAULT_OPEN_UI_V = "V",
            SETTINGS_DEFAULT_OPEN_UI_H = "H",
            SETTINGS_DEFAULT_OPEN_UI_M2 = "M2",
            SETTINGS_ROSTER_COLUMN_GUIDES = "Column Guides",
            SETTINGS_SHOW_TIMEWAYS_NAVIGATOR = "Show Timeways Navigator",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
        onPortalNavigatorToggle = function(enabled)
          callbackStates[#callbackStates + 1] = enabled and true or false
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")
      Assert.Nil(db.showPortalNavigator, "opening settings should not persist the default portal navigator value")

      local navigatorCheck = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_SHOW_TIMEWAYS_NAVIGATOR" then
          navigatorCheck = frame
          break
        end
      end

      navigatorCheck = Assert.NotNil(navigatorCheck, "settings panel should create a portal navigator checkbox")
      ---@diagnostic disable: undefined-field
      Assert.True(navigatorCheck:GetChecked(), "portal navigator should default to enabled when no saved value exists")
      Assert.Equal(
        navigatorCheck.label:GetText(),
        "Show Timeways Navigator",
        "portal navigator label should use the English settings text"
      )

      local onClick = navigatorCheck._scripts and navigatorCheck._scripts.OnClick or nil
      onClick = Assert.NotNil(onClick, "portal navigator checkbox should define OnClick")

      navigatorCheck:SetChecked(false)
      onClick(navigatorCheck)
      Assert.False(db.showPortalNavigator, "disabling the checkbox should persist the disabled setting")
      Assert.Equal(callbackStates[1], false, "disabling the checkbox should notify the callback")

      panel.Refresh()
      Assert.False(navigatorCheck:GetChecked(), "refresh should keep the disabled portal navigator state")
      ---@diagnostic enable: undefined-field
    end)
  end)

  test("Settings panel keeps the removed LFG invite list out of the UI", function()
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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
            SETTINGS_AUTO_CLOSE_ON_KEY_START = "Auto Close On Key Start",
            SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE = "Auto Close On Solo Change",
            SETTINGS_DEFAULT_OPEN_UI = "Default UI on Open",
            SETTINGS_DEFAULT_OPEN_UI_LAST = "Last Used",
            SETTINGS_DEFAULT_OPEN_UI_V = "V",
            SETTINGS_DEFAULT_OPEN_UI_H = "H",
            SETTINGS_DEFAULT_OPEN_UI_M2 = "M2",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")
      Assert.Nil(db.inviteListEnabled, "removed invite list must not create a saved value")

      local inviteListCheck = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_INVITE_LIST_ENABLED" then
          inviteListCheck = frame
          break
        end
      end

      Assert.Nil(inviteListCheck, "removed invite-list feature must not create a settings checkbox")
      panel.Refresh()
      Assert.Nil(db.inviteListEnabled, "refresh must not create removed invite-list setting")
    end)
  end)

  test("Settings panel keeps removed LFG invite hint out of the UI", function()
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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")
      Assert.Nil(db.inviteHintEnabled, "removed invite hint must not create a saved value")

      local inviteHintCheck = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_INVITE_HINT_ENABLED" then
          inviteHintCheck = frame
          break
        end
      end

      Assert.Nil(inviteHintCheck, "removed invite hint must not create a settings checkbox")
      panel.Refresh()
      Assert.Nil(db.inviteHintEnabled, "refresh must not create removed invite hint setting")
    end)
  end)

  test("Settings panel renders raid behavior as a status note instead of a single-option selector", function()
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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
            SETTINGS_AUTO_CLOSE_ON_KEY_START = "Auto Close On Key Start",
            SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE = "Auto Close On Solo Change",
            SETTINGS_AUTO_SHOW_MAIN_FRAME_ON_STARTUP = "Show on Login / Reload",
            SETTINGS_AUTO_OPEN_MAIN_FRAME_ON_KEY_END = "Auto Open on Key End",
            SETTINGS_DEFAULT_OPEN_UI = "Default UI on Open",
            SETTINGS_DEFAULT_OPEN_UI_LAST = "Last Used",
            SETTINGS_DEFAULT_OPEN_UI_V = "V",
            SETTINGS_DEFAULT_OPEN_UI_H = "H",
            SETTINGS_DEFAULT_OPEN_UI_M2 = "M2",
            SETTINGS_RAID_TRANSITION_NOTE = "Raid: main window hides automatically while in a raid group.",
            SETTINGS_ROSTER_COLUMN_GUIDES = "Column Guides",
            SETTINGS_SHOW_TIMEWAYS_NAVIGATOR = "Show Timeways Navigator",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")
      Assert.Nil(db.raidTransitionBehavior, "opening settings should not persist the default raid behavior")

      -- The single-option raid-behavior selector was replaced with a static
      -- status note. No clickable "hide" option button must be created.
      for _, frame in ipairs(createdFrames) do
        Assert.False(frame._optionValue == "hide", "no raid-behavior option button should be created")
      end
    end)
  end)
end

local function RegisterSettingsPanelSoundAndLegacyTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Settings panel exposes sound toggles with the intended defaults", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    local now = 100
    local previewCalls = {}

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      GetTime = function()
        return now
      end,
      PlaySoundFile = function(path, channel)
        previewCalls[#previewCalls + 1] = { path = path, channel = channel }
      end,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_sound_utils.lua", "isiLive_settings.lua" })
      local summonLoopDesc = "Wiederholt den Beschwoerungston alle 5 Sekunden, "
        .. "solange die Beschwoerung noch aussteht."
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_SOUNDS = "Sounds",
            SETTINGS_SOUND_INCOMING_SUMMON_LOOP = "Eingehende-Beschwoerung-Hinweis alle 5 Sekunden wiederholen",
            SETTINGS_SOUND_INCOMING_SUMMON_LOOP_DESC = summonLoopDesc,
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")
      Assert.Nil(db.soundLeadEnabled, "opening settings should not persist the default leader-sound state")
      Assert.Nil(db.soundGroupJoinEnabled, "opening settings should not persist the default group-join sound state")
      Assert.Nil(db.soundPortalAvailableEnabled, "opening settings should not persist the default portal sound state")
      Assert.Nil(
        db.soundIncomingSummonLoopEnabled,
        "opening settings should not persist the incoming-summon loop default"
      )
      Assert.Nil(db.soundBattleResEnabled, "opening settings should not persist the default battle-res sound state")
      Assert.Nil(db.soundBloodlustEnabled, "opening settings should not persist the default bloodlust sound state")
      Assert.Nil(
        db.powerInfusionTextEnabled,
        "opening settings should not persist the default Power Infusion text state"
      )
      Assert.Nil(db.soundOutputChannel, "opening settings should not persist the default sound output channel")
      local unstoredDefaultKeys = {
        "soundBattleResReadyEnabled",
        "soundBloodlustReadyEnabled",
        "soundBloodlustReadyReminderEnabled",
        "soundPowerInfusionReceivedEnabled",
      }
      for _, key in ipairs(unstoredDefaultKeys) do
        Assert.Nil(db[key], "opening settings should not persist " .. key)
      end

      local soundSectionHeader = nil
      local leadSoundCheck = nil
      local groupJoinSoundCheck = nil
      local portalSoundCheck = nil
      local incomingSummonLoopCheck = nil
      local battleResSoundCheck = nil
      local battleResReadySoundCheck = nil
      local bloodlustSoundCheck = nil
      local bloodlustReadySoundCheck = nil
      local bloodlustReadyReminderCheck = nil
      local powerInfusionSoundCheck = nil
      local powerInfusionTextAlertCheck = nil
      local soundChannelMasterButton = nil
      local soundChannelSfxButton = nil
      local soundPreviewButtons = {}
      for _, frame in ipairs(createdFrames) do
        if frame._sectionKey == "SETTINGS_SECTION_SOUNDS" then
          soundSectionHeader = frame
        end
        if frame._settingKey == "SETTINGS_SOUND_LEAD_ENABLED" then
          leadSoundCheck = frame
        elseif frame._settingKey == "SETTINGS_SOUND_GROUP_JOIN_ENABLED" then
          groupJoinSoundCheck = frame
        elseif frame._settingKey == "SETTINGS_SOUND_PORTAL_AVAILABLE" then
          portalSoundCheck = frame
        elseif frame._settingKey == "SETTINGS_SOUND_INCOMING_SUMMON_LOOP" then
          incomingSummonLoopCheck = frame
        elseif frame._settingKey == "SETTINGS_SOUND_BATTLE_RES" then
          battleResSoundCheck = frame
        elseif frame._settingKey == "SETTINGS_SOUND_BATTLE_RES_READY" then
          battleResReadySoundCheck = frame
        elseif frame._settingKey == "SETTINGS_SOUND_BLOODLUST" then
          bloodlustSoundCheck = frame
        elseif frame._settingKey == "SETTINGS_SOUND_BLOODLUST_READY" then
          bloodlustReadySoundCheck = frame
        elseif frame._settingKey == "SETTINGS_SOUND_BLOODLUST_READY_REMINDER" then
          bloodlustReadyReminderCheck = frame
        elseif frame._settingKey == "SETTINGS_SOUND_POWER_INFUSION_RECEIVED" then
          powerInfusionSoundCheck = frame
        elseif frame._settingKey == "SETTINGS_TEXT_POWER_INFUSION_ALERT" then
          powerInfusionTextAlertCheck = frame
        elseif frame._settingKey == "SETTINGS_SOUND_CHANNEL" and frame._optionValue == "Master" then
          soundChannelMasterButton = frame
        elseif frame._settingKey == "SETTINGS_SOUND_CHANNEL" and frame._optionValue == "SFX" then
          soundChannelSfxButton = frame
        end
        if frame._soundPreviewKey then
          soundPreviewButtons[frame._soundPreviewKey] = frame
        end
      end

      Assert.NotNil(soundSectionHeader, "settings panel should create a dedicated sounds section")
      leadSoundCheck = Assert.NotNil(leadSoundCheck, "settings panel should create a leader-transfer sound checkbox")
      groupJoinSoundCheck =
        Assert.NotNil(groupJoinSoundCheck, "settings panel should create a group-join sound checkbox")
      portalSoundCheck = Assert.NotNil(portalSoundCheck, "settings panel should create a portal sound checkbox")
      incomingSummonLoopCheck =
        Assert.NotNil(incomingSummonLoopCheck, "settings panel should create an incoming-summon loop checkbox")
      battleResSoundCheck =
        Assert.NotNil(battleResSoundCheck, "settings panel should create a battle-res sound checkbox")
      battleResReadySoundCheck =
        Assert.NotNil(battleResReadySoundCheck, "settings panel should create a battle-res-ready sound checkbox")
      bloodlustSoundCheck =
        Assert.NotNil(bloodlustSoundCheck, "settings panel should create a bloodlust sound checkbox")
      bloodlustReadySoundCheck =
        Assert.NotNil(bloodlustReadySoundCheck, "settings panel should create a bloodlust-ready sound checkbox")
      bloodlustReadyReminderCheck =
        Assert.NotNil(bloodlustReadyReminderCheck, "settings panel should create a bloodlust-ready reminder checkbox")
      powerInfusionSoundCheck =
        Assert.NotNil(powerInfusionSoundCheck, "settings panel should create a Power Infusion sound checkbox")
      powerInfusionTextAlertCheck =
        Assert.NotNil(powerInfusionTextAlertCheck, "settings panel should create a Power Infusion text checkbox")
      soundChannelMasterButton =
        Assert.NotNil(soundChannelMasterButton, "settings panel should create a Master sound-channel option")
      soundChannelSfxButton =
        Assert.NotNil(soundChannelSfxButton, "settings panel should create an SFX sound-channel option")
      Assert.Equal(
        soundChannelMasterButton._backdropColor and soundChannelMasterButton._backdropColor[4],
        0.25,
        "Master sound channel should be highlighted by default"
      )
      Assert.NotNil(soundPreviewButtons.leader_transfer, "settings panel should create a leader sound preview button")
      Assert.NotNil(soundPreviewButtons.group_join, "settings panel should create a group-join sound preview button")
      Assert.NotNil(soundPreviewButtons.portal_available, "settings panel should create a portal sound preview button")
      Assert.NotNil(soundPreviewButtons.battle_res, "settings panel should create a battle-res sound preview button")
      Assert.NotNil(
        soundPreviewButtons.battle_res_ready,
        "settings panel should create a battle-res-ready sound preview button"
      )
      Assert.NotNil(soundPreviewButtons.bloodlust, "settings panel should create a bloodlust sound preview button")
      Assert.NotNil(
        soundPreviewButtons.bloodlust_ready,
        "settings panel should create a bloodlust-ready sound preview button"
      )
      Assert.NotNil(
        soundPreviewButtons.power_infusion_received,
        "settings panel should create a Power Infusion sound preview button"
      )
      Assert.Equal(
        soundPreviewButtons.leader_transfer._point[1],
        "LEFT",
        "sound preview buttons should be anchored inline instead of to the far right edge"
      )
      Assert.Equal(
        soundPreviewButtons.leader_transfer._point[2],
        leadSoundCheck,
        "sound preview buttons should sit next to their checkbox"
      )
      local defaultCheckedSoundControls = {
        leadSoundCheck,
        groupJoinSoundCheck,
        portalSoundCheck,
        incomingSummonLoopCheck,
        battleResSoundCheck,
        battleResReadySoundCheck,
        bloodlustSoundCheck,
        bloodlustReadySoundCheck,
        bloodlustReadyReminderCheck,
        powerInfusionSoundCheck,
        powerInfusionTextAlertCheck,
      }
      for _, check in ipairs(defaultCheckedSoundControls) do
        Assert.True(check:GetChecked(), "sound setting should default to enabled")
      end

      local onClickLead = leadSoundCheck._scripts and leadSoundCheck._scripts.OnClick or nil
      local onClickJoin = groupJoinSoundCheck._scripts and groupJoinSoundCheck._scripts.OnClick or nil
      local onClickPortal = portalSoundCheck._scripts and portalSoundCheck._scripts.OnClick or nil
      local onClickIncomingSummonLoop = incomingSummonLoopCheck._scripts and incomingSummonLoopCheck._scripts.OnClick
        or nil
      local onClickBattleRes = battleResSoundCheck._scripts and battleResSoundCheck._scripts.OnClick or nil
      local onClickBattleResReady = battleResReadySoundCheck._scripts and battleResReadySoundCheck._scripts.OnClick
        or nil
      local onClickBloodlust = bloodlustSoundCheck._scripts and bloodlustSoundCheck._scripts.OnClick or nil
      local onClickBloodlustReady = bloodlustReadySoundCheck._scripts and bloodlustReadySoundCheck._scripts.OnClick
        or nil
      local onClickBloodlustReadyReminder = bloodlustReadyReminderCheck._scripts
          and bloodlustReadyReminderCheck._scripts.OnClick
        or nil
      local onClickPowerInfusionSound = powerInfusionSoundCheck._scripts and powerInfusionSoundCheck._scripts.OnClick
        or nil
      local onClickPowerInfusionText = powerInfusionTextAlertCheck._scripts
          and powerInfusionTextAlertCheck._scripts.OnClick
        or nil
      local onClickSoundChannelSfx = soundChannelSfxButton._scripts and soundChannelSfxButton._scripts.OnClick or nil
      onClickLead = Assert.NotNil(onClickLead, "leader-transfer sound checkbox should define OnClick")
      onClickJoin = Assert.NotNil(onClickJoin, "group-join sound checkbox should define OnClick")
      onClickPortal = Assert.NotNil(onClickPortal, "portal sound checkbox should define OnClick")
      onClickIncomingSummonLoop =
        Assert.NotNil(onClickIncomingSummonLoop, "incoming-summon loop checkbox should define OnClick")
      onClickBattleRes = Assert.NotNil(onClickBattleRes, "battle-res sound checkbox should define OnClick")
      onClickBattleResReady =
        Assert.NotNil(onClickBattleResReady, "battle-res-ready sound checkbox should define OnClick")
      onClickBloodlust = Assert.NotNil(onClickBloodlust, "bloodlust sound checkbox should define OnClick")
      onClickBloodlustReady =
        Assert.NotNil(onClickBloodlustReady, "bloodlust-ready sound checkbox should define OnClick")
      onClickBloodlustReadyReminder =
        Assert.NotNil(onClickBloodlustReadyReminder, "bloodlust-ready reminder checkbox should define OnClick")
      onClickPowerInfusionSound =
        Assert.NotNil(onClickPowerInfusionSound, "Power Infusion sound checkbox should define OnClick")
      onClickPowerInfusionText =
        Assert.NotNil(onClickPowerInfusionText, "Power Infusion text checkbox should define OnClick")
      onClickSoundChannelSfx = Assert.NotNil(onClickSoundChannelSfx, "SFX sound-channel option should define OnClick")

      leadSoundCheck:SetChecked(false)
      onClickLead(leadSoundCheck)
      groupJoinSoundCheck:SetChecked(true)
      onClickJoin(groupJoinSoundCheck)
      portalSoundCheck:SetChecked(false)
      onClickPortal(portalSoundCheck)
      incomingSummonLoopCheck:SetChecked(false)
      onClickIncomingSummonLoop(incomingSummonLoopCheck)
      battleResSoundCheck:SetChecked(false)
      onClickBattleRes(battleResSoundCheck)
      battleResReadySoundCheck:SetChecked(false)
      onClickBattleResReady(battleResReadySoundCheck)
      bloodlustSoundCheck:SetChecked(true)
      onClickBloodlust(bloodlustSoundCheck)
      bloodlustReadySoundCheck:SetChecked(false)
      onClickBloodlustReady(bloodlustReadySoundCheck)
      bloodlustReadyReminderCheck:SetChecked(false)
      onClickBloodlustReadyReminder(bloodlustReadyReminderCheck)
      powerInfusionSoundCheck:SetChecked(false)
      onClickPowerInfusionSound(powerInfusionSoundCheck)
      powerInfusionTextAlertCheck:SetChecked(false)
      onClickPowerInfusionText(powerInfusionTextAlertCheck)
      onClickSoundChannelSfx(soundChannelSfxButton)

      Assert.False(db.soundLeadEnabled, "disabling leader-transfer sound should persist false")
      Assert.True(db.soundGroupJoinEnabled, "enabling group-join sound should persist true")
      Assert.False(db.soundPortalAvailableEnabled, "disabling portal sound should persist false")
      Assert.False(db.soundIncomingSummonLoopEnabled, "disabling incoming-summon loop should persist false")
      Assert.False(db.soundBattleResEnabled, "disabling battle-res sound should persist false")
      Assert.False(db.soundBattleResReadyEnabled, "disabling battle-res-ready sound should persist false")
      Assert.True(db.soundBloodlustEnabled, "enabling bloodlust sound should persist true")
      Assert.False(db.soundBloodlustReadyEnabled, "disabling bloodlust-ready sound should persist false")
      Assert.False(db.soundBloodlustReadyReminderEnabled, "disabling bloodlust-ready reminders should persist false")
      Assert.False(db.soundPowerInfusionReceivedEnabled, "disabling Power Infusion sound should persist false")
      Assert.False(db.powerInfusionTextEnabled, "disabling Power Infusion text should persist false")
      Assert.Equal(db.soundOutputChannel, "SFX", "selecting the SFX sound channel should persist SFX")

      local onPreviewLead = Assert.NotNil(
        soundPreviewButtons.leader_transfer._scripts and soundPreviewButtons.leader_transfer._scripts.OnClick or nil,
        "leader-transfer preview button should define OnClick"
      )
      onPreviewLead(soundPreviewButtons.leader_transfer, "LeftButton")
      Assert.Equal(#previewCalls, 1, "previewing a disabled sound should still play once")
      Assert.Equal(
        previewCalls[1].path,
        "Interface\\AddOns\\isiLive\\sounds\\CartoonVoiceBaritone.ogg",
        "leader-transfer preview should play the configured sound asset"
      )
      Assert.Equal(previewCalls[1].channel, "SFX", "sound previews should use the configured SFX channel")

      panel.Refresh()
      Assert.False(leadSoundCheck:GetChecked(), "refresh should keep the disabled leader-transfer sound state")
      Assert.True(groupJoinSoundCheck:GetChecked(), "refresh should keep the enabled group-join sound state")
      Assert.False(portalSoundCheck:GetChecked(), "refresh should keep the disabled portal sound state")
      Assert.False(incomingSummonLoopCheck:GetChecked(), "refresh should keep the disabled incoming-summon loop state")
      Assert.False(battleResSoundCheck:GetChecked(), "refresh should keep the disabled battle-res sound state")
      Assert.False(
        battleResReadySoundCheck:GetChecked(),
        "refresh should keep the disabled battle-res-ready sound state"
      )
      Assert.True(bloodlustSoundCheck:GetChecked(), "refresh should keep the enabled bloodlust sound state")
      Assert.False(
        bloodlustReadySoundCheck:GetChecked(),
        "refresh should keep the disabled bloodlust-ready sound state"
      )
      Assert.False(
        bloodlustReadyReminderCheck:GetChecked(),
        "refresh should keep the disabled bloodlust-ready reminder state"
      )
      Assert.False(powerInfusionSoundCheck:GetChecked(), "refresh should keep the disabled Power Infusion sound state")
      Assert.False(
        powerInfusionTextAlertCheck:GetChecked(),
        "refresh should keep the disabled Power Infusion text state"
      )
      incomingSummonLoopCheck.label:SetText("Repeat incoming-summon alert every 5 seconds")
      incomingSummonLoopCheck.description:SetText(
        "Repeats the incoming-summon sound every 5 seconds while the summon is still pending."
      )
      panel.Refresh()
      Assert.Equal(
        incomingSummonLoopCheck.label:GetText(),
        "Eingehende-Beschwoerung-Hinweis alle 5 Sekunden wiederholen",
        "refresh should localize the incoming-summon loop label"
      )
      Assert.Equal(
        incomingSummonLoopCheck.description:GetText(),
        "Wiederholt den Beschwoerungston alle 5 Sekunden, solange die Beschwoerung noch aussteht.",
        "refresh should localize the incoming-summon loop description"
      )
      Assert.Equal(
        soundChannelSfxButton._backdropColor and soundChannelSfxButton._backdropColor[4],
        0.25,
        "refresh should keep the selected SFX sound-channel highlight"
      )
    end)
  end)

  test("Settings panel expands layout height for wrapped intro and hint text", function()
    local function BuildPanelHeight(textSet)
      local createFrameStub = BuildCreateFrameStub()
      local db = {}
      local panel = nil

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
        local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
        panel = addon.SettingsPanel.Create({
          getL = function()
            return textSet
          end,
          getCurrentLocale = function()
            return "enUS"
          end,
          setLanguage = function() end,
          getDB = function()
            return db
          end,
        })
      end)

      return RequireValue(panel, "settings panel should exist").content:GetHeight()
    end

    local shortHeight = BuildPanelHeight({
      SETTINGS_SECTION_GENERAL = "General",
      SETTINGS_SECTION_GENERAL_HINT = "Short general hint.",
      SETTINGS_SECTION_DISPLAY = "Display",
      SETTINGS_SECTION_DISPLAY_HINT = "Short display hint.",
      SETTINGS_SECTION_BEHAVIOR = "Behavior",
      SETTINGS_SECTION_BEHAVIOR_HINT = "Short behavior hint.",
      SETTINGS_SECTION_SOUNDS = "Sounds",
      SETTINGS_SECTION_SOUNDS_HINT = "Short sounds hint.",
      SETTINGS_SECTION_DEBUG = "Debug",
      SETTINGS_SECTION_DEBUG_HINT = "Short debug hint.",
      SETTINGS_SECTION_RESET_HINT = "Short reset hint.",
      SETTINGS_PAGE_HINT = "Short intro.",
      SETTINGS_BETA_NOTICE = "Beta",
      BETA_NOTICE_TEXT = "Short beta notice.",
      SETTINGS_LANGUAGE = "Language",
      SETTINGS_COMBAT_LOGGING = "Combat Logging",
      SETTINGS_DM_RESET = "DM Reset",
      SETTINGS_ESC_PANEL = "ESC Panel",
      SETTINGS_BG_ALPHA = "Background Opacity",
      SETTINGS_UI_SCALE = "UI Scale",
      SETTINGS_MINIMAP_BUTTON = "Minimap Button",
      SETTINGS_SYNC_ENABLED = "Addon Sync",
      SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
      SETTINGS_AUTO_CLOSE_MAIN_FRAME = "Auto Close Main Frame",
      SETTINGS_AUTO_SHOW_MAIN_FRAME_ON_STARTUP = "Show on Login / Reload",
      SETTINGS_AUTO_OPEN_MAIN_FRAME_ON_KEY_END = "Auto Open on Key End",
      SETTINGS_RAID_TRANSITION_BEHAVIOR = "Raid Behavior",
      SETTINGS_RAID_TRANSITION_BEHAVIOR_HIDE = "Raid Off",
      SETTINGS_ROSTER_COLUMN_GUIDES = "Column Guides",
      SETTINGS_SHOW_TIMEWAYS_NAVIGATOR = "Show Timeways Navigator",
      SETTINGS_SOUND_LEAD_ENABLED = "Sound: Lead Transfer",
      SETTINGS_SOUND_GROUP_JOIN_ENABLED = "Sound: Full Group",
      SETTINGS_SOUND_PORTAL_AVAILABLE = "Sound: Incoming Summon",
      SETTINGS_SOUND_BATTLE_RES = "Sound: Battle Res",
      SETTINGS_SOUND_BLOODLUST = "Sound: Bloodlust",
      SETTINGS_QUEUE_DEBUG = "Queue Debug",
      SETTINGS_RUNTIME_LOG = "Runtime Log",
    })
    local longHeight = BuildPanelHeight({
      SETTINGS_SECTION_GENERAL = "General",
      SETTINGS_SECTION_GENERAL_HINT = "This is a much longer general section hint "
        .. "that wraps across multiple lines and should increase the layout height.",
      SETTINGS_SECTION_DISPLAY = "Display",
      SETTINGS_SECTION_DISPLAY_HINT = "This display hint is intentionally long so "
        .. "the wrapped helper has to measure a taller block of text in the settings page.",
      SETTINGS_SECTION_BEHAVIOR = "Behavior",
      SETTINGS_SECTION_BEHAVIOR_HINT = "This behavior hint is intentionally long so "
        .. "the wrapped helper has to measure a taller block of text in the settings page.",
      SETTINGS_SECTION_SOUNDS = "Sounds",
      SETTINGS_SECTION_SOUNDS_HINT = "This sounds hint is intentionally long so "
        .. "the wrapped helper has to measure a taller block of text in the settings page.",
      SETTINGS_SECTION_DEBUG = "Debug",
      SETTINGS_SECTION_DEBUG_HINT = "This debug hint is intentionally long so "
        .. "the wrapped helper has to measure a taller block of text in the settings page.",
      SETTINGS_SECTION_RESET_HINT = "This reset hint is intentionally long so "
        .. "the wrapped helper has to measure a taller block of text in the settings page.",
      SETTINGS_PAGE_HINT = "This is a much longer intro text for the settings page "
        .. "that should wrap and reserve additional vertical space before the first section starts.",
      SETTINGS_BETA_NOTICE = "Beta",
      BETA_NOTICE_TEXT = "This beta notice text is intentionally much longer so it "
        .. "wraps and increases the height of the beta block above the URL fields.",
      SETTINGS_LANGUAGE = "Language",
      SETTINGS_COMBAT_LOGGING = "Combat Logging",
      SETTINGS_DM_RESET = "DM Reset",
      SETTINGS_ESC_PANEL = "ESC Panel",
      SETTINGS_BG_ALPHA = "Background Opacity",
      SETTINGS_UI_SCALE = "UI Scale",
      SETTINGS_MINIMAP_BUTTON = "Minimap Button",
      SETTINGS_SYNC_ENABLED = "Addon Sync",
      SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
      SETTINGS_AUTO_CLOSE_MAIN_FRAME = "Auto Close Main Frame",
      SETTINGS_AUTO_SHOW_MAIN_FRAME_ON_STARTUP = "Show on Login / Reload",
      SETTINGS_AUTO_OPEN_MAIN_FRAME_ON_KEY_END = "Auto Open on Key End",
      SETTINGS_RAID_TRANSITION_BEHAVIOR = "Raid Behavior",
      SETTINGS_RAID_TRANSITION_BEHAVIOR_HIDE = "Raid Off",
      SETTINGS_ROSTER_COLUMN_GUIDES = "Column Guides",
      SETTINGS_SHOW_TIMEWAYS_NAVIGATOR = "Show Timeways Navigator",
      SETTINGS_SOUND_LEAD_ENABLED = "Sound: Lead Transfer",
      SETTINGS_SOUND_GROUP_JOIN_ENABLED = "Sound: Full Group",
      SETTINGS_SOUND_PORTAL_AVAILABLE = "Sound: Incoming Summon",
      SETTINGS_SOUND_BATTLE_RES = "Sound: Battle Res",
      SETTINGS_SOUND_BLOODLUST = "Sound: Bloodlust",
      SETTINGS_QUEUE_DEBUG = "Queue Debug",
      SETTINGS_RUNTIME_LOG = "Runtime Log",
    })

    Assert.True(
      longHeight > shortHeight,
      "wrapped settings hints must increase the total content height when texts become longer"
    )
  end)

  test("Settings slider labels are width-constrained so long locale text cannot overlap the slider", function()
    local createFrameStub = BuildCreateFrameStub()
    local db = {}
    local longSliderLabel = "Very long background opacity label that must wrap before the slider track"

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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = longSliderLabel,
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
            SETTINGS_AUTO_CLOSE_ON_KEY_START = "Auto Close On Key Start",
            SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE = "Auto Close On Solo Change",
            SETTINGS_AUTO_SHOW_MAIN_FRAME_ON_STARTUP = "Show on Login / Reload",
            SETTINGS_AUTO_OPEN_MAIN_FRAME_ON_KEY_END = "Auto Open on Key End",
            SETTINGS_RAID_TRANSITION_BEHAVIOR = "Raid Behavior",
            SETTINGS_RAID_TRANSITION_BEHAVIOR_HIDE = "Raid Off",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      local matched = 0
      for _, fontString in ipairs(RequireValue(panel, "settings panel should exist").content._fontStrings or {}) do
        if fontString:GetText() == longSliderLabel then
          matched = matched + 1
          Assert.Equal(fontString._width, 150, "slider label should reserve only the left label column")
          Assert.Equal(fontString._justifyH, "LEFT", "slider label should stay left-aligned inside its column")
          Assert.True(fontString._wordWrap, "slider label should wrap instead of drawing into the slider")
        end
      end

      Assert.Equal(matched, 1, "test must find the localized slider label")
    end)
  end)

  test("Settings panel hides disabled legacy display and behavior controls", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {
      nameMaxChars = 18,
      teleportColumns = 2,
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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_NAME_MAX_CHARS = "Name Length",
            SETTINGS_TELEPORT_COLUMNS = "Teleport Grid Columns",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
            SETTINGS_AUTO_CLOSE_ON_KEY_START = "Auto Close On Key Start",
            SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE = "Auto Close On Solo Change",
            SETTINGS_AUTO_SHOW_MAIN_FRAME_ON_STARTUP = "Show on Login / Reload",
            SETTINGS_AUTO_OPEN_MAIN_FRAME_ON_KEY_END = "Auto Open on Key End",
            SETTINGS_RAID_TRANSITION_BEHAVIOR = "Raid Behavior",
            SETTINGS_RAID_TRANSITION_BEHAVIOR_HIDE = "Raid Off",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      Assert.NotNil(panel, "settings panel should still be created")
      Assert.NotNil(panel.scrollFrame, "settings panel should expose a scroll frame for overflowing content")
      Assert.NotNil(panel.content, "settings panel should expose a scroll child for overflowing content")
      Assert.Equal(
        panel.scrollFrame:GetScrollChild(),
        panel.content,
        "settings scroll frame should be wired to the content child"
      )
      Assert.True(
        panel.content:GetHeight() > panel.scrollFrame:GetHeight(),
        "settings content should exceed the viewport height so the lower controls remain reachable via scrolling"
      )
      Assert.True(
        panel.scrollFrame:GetVerticalScrollRange() > 0,
        "settings scroll frame should expose a positive scroll range when content overflows"
      )

      local sliderCount = 0
      local checkboxCount = 0
      local scrollFrameCount = 0
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "Slider" then
          sliderCount = sliderCount + 1
        elseif frame._frameType == "CheckButton" then
          checkboxCount = checkboxCount + 1
        elseif frame._frameType == "ScrollFrame" then
          scrollFrameCount = scrollFrameCount + 1
        end
      end

      Assert.Equal(scrollFrameCount, 1, "settings should allocate exactly one content scroll frame")
      Assert.Equal(
        sliderCount,
        7,
        "settings should expose bg-alpha, UI-scale, stats-box alpha, stats-box font-size,"
          .. " nameplate font-size, nameplate X-offset, and nameplate Y-offset sliders"
      )
      Assert.Equal(
        checkboxCount,
        49,
        "settings should hide only the legacy name-length"
          .. " and teleport-column controls while keeping the startup/key-end, navigator, sound,"
          .. " incoming-summon loop, chat/text-announce, combat-fade, nameplate-subtoggle,"
          .. " accepted-invite/group-join notices, LFG class-bonus, stats-box toggles/detail rows,"
          .. " VIP sound toggles, the VIP DK Soul Reaper and Putrefy warnings,"
          .. " the VIP Bloodlust debuff warning, the DK horse-sound child mute, the DK ghoul-reminder child toggle,"
          .. " and the two auto-close split checkboxes visible"
          .. " (M+ forces tooltip/nameplate toggles replaced by a single 3-way display-mode selector)"
      )

      panel.Refresh()
      Assert.Equal(sliderCount, 7, "refresh should keep the stats-box and nameplate sliders visible")
      Assert.Equal(
        checkboxCount,
        49,
        "refresh should keep the hidden legacy checkboxes out of the settings UI"
          .. " while preserving the visible sound, incoming-summon loop, chat/text-announce,"
          .. " combat-fade, nameplate-subtoggle,"
          .. " accepted-invite/group-join notices, LFG class-bonus, stats-box toggles/detail rows, VIP sound toggles,"
          .. " the VIP DK Soul Reaper and Putrefy warnings,"
          .. " the VIP Bloodlust debuff warning, the DK horse-sound child mute, the DK ghoul-reminder child toggle,"
          .. " and the two auto-close split checkboxes"
      )
    end)
  end)

  test("Settings nameplate font-size slider invokes onMobNameplateChange so live MobNameplate refreshes", function()
    -- Regression: ResolveSettingsOptions previously dropped onMobNameplateChange,
    -- so dragging the slider only persisted to DB but never reapplied SetAppearance
    -- on the live module — the rendered font size only changed after /reload.
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = { mobNameplateEnabled = true, mobNameplateFontSize = 12 }
    local nameplateChangeCalls = 0

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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_NAMEPLATE_FONT_SIZE = "Font size",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
        onMobNameplateChange = function()
          nameplateChangeCalls = nameplateChangeCalls + 1
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")

      local slider = nil
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "Slider" and frame._settingKey == "SETTINGS_NAMEPLATE_FONT_SIZE" then
          slider = frame
          break
        end
      end
      slider = Assert.NotNil(slider, "settings should create the nameplate font-size slider")

      ---@diagnostic disable: undefined-field
      local onValueChanged = slider._scripts and slider._scripts.OnValueChanged or nil
      onValueChanged = Assert.NotNil(onValueChanged, "font-size slider should define OnValueChanged")
      onValueChanged(slider, 18)
      ---@diagnostic enable: undefined-field

      Assert.Equal(db.mobNameplateFontSize, 18, "slider drag should persist the new font size")
      Assert.Equal(
        nameplateChangeCalls,
        1,
        "slider drag must invoke onMobNameplateChange so the live MobNameplate module reapplies SetAppearance"
      )
    end)
  end)

  test(
    "Settings debug-log checkboxes reflect live controller state via getQueueDebugEnabled / getRuntimeLogEnabled",
    function()
      -- Regression: ResolveSettingsOptions used to drop both getters, so the
      -- queue-debug + runtime-log checkboxes always rendered unchecked when
      -- the settings panel was opened, even if the loggers were actively
      -- capturing.
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
        local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
        local panel = addon.SettingsPanel.Create({
          getL = function()
            return {
              SETTINGS_SECTION_DEBUG = "Debug",
              SETTINGS_QUEUE_DEBUG = "Queue Debug Log",
              SETTINGS_RUNTIME_LOG = "Runtime Log",
            }
          end,
          getCurrentLocale = function()
            return "enUS"
          end,
          setLanguage = function() end,
          getDB = function()
            return db
          end,
          getQueueDebugEnabled = function()
            return true
          end,
          getRuntimeLogEnabled = function()
            return true
          end,
        })

        Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")

        local queueCheck, runtimeCheck = nil, nil
        for _, frame in ipairs(createdFrames) do
          if frame._settingKey == "SETTINGS_QUEUE_DEBUG" then
            queueCheck = frame
          elseif frame._settingKey == "SETTINGS_RUNTIME_LOG" then
            runtimeCheck = frame
          end
        end
        queueCheck = Assert.NotNil(queueCheck, "settings should expose the queue-debug checkbox")
        runtimeCheck = Assert.NotNil(runtimeCheck, "settings should expose the runtime-log checkbox")

        ---@diagnostic disable: undefined-field
        Assert.True(
          queueCheck:GetChecked() == true,
          "queue-debug checkbox must mirror getQueueDebugEnabled() == true on initial render"
        )
        Assert.True(
          runtimeCheck:GetChecked() == true,
          "runtime-log checkbox must mirror getRuntimeLogEnabled() == true on initial render"
        )
        ---@diagnostic enable: undefined-field
      end)
    end
  )

  test("Settings Refresh resyncs chatAnnounce checkboxes from DB after a reset", function()
    -- Regression: Refresh() updated the chat-announce checkbox labels but
    -- never called SetChecked, so the visible state could lag DB after
    -- /isilive reset until the panel was reopened.
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = { chatAnnounceBR = true, chatAnnounceLust = true, powerInfusionTextEnabled = true }

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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_CHAT_BR_ANNOUNCE = "Chat BR",
            SETTINGS_CHAT_LUST_ANNOUNCE = "Chat Lust",
            SETTINGS_TEXT_POWER_INFUSION_ALERT = "PI Text",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")

      local brCheck, lustCheck, piTextCheck = nil, nil, nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_CHAT_BR_ANNOUNCE" then
          brCheck = frame
        elseif frame._settingKey == "SETTINGS_CHAT_LUST_ANNOUNCE" then
          lustCheck = frame
        elseif frame._settingKey == "SETTINGS_TEXT_POWER_INFUSION_ALERT" then
          piTextCheck = frame
        end
      end
      brCheck = Assert.NotNil(brCheck, "settings should expose the chatAnnounceBR checkbox")
      lustCheck = Assert.NotNil(lustCheck, "settings should expose the chatAnnounceLust checkbox")
      piTextCheck = Assert.NotNil(piTextCheck, "settings should expose the Power Infusion text checkbox")

      ---@diagnostic disable: undefined-field
      Assert.True(brCheck:GetChecked(), "chatAnnounceBR should start checked when DB says true")
      Assert.True(lustCheck:GetChecked(), "chatAnnounceLust should start checked when DB says true")
      Assert.True(piTextCheck:GetChecked(), "powerInfusionTextEnabled should start checked when DB says true")

      -- Simulate /isilive reset: DB defaults flip to nil/false; Refresh must resync.
      db.chatAnnounceBR = false
      db.chatAnnounceLust = false
      db.powerInfusionTextEnabled = false
      panel.Refresh()

      Assert.False(brCheck:GetChecked(), "Refresh must resync chatAnnounceBR to false after DB reset")
      Assert.False(lustCheck:GetChecked(), "Refresh must resync chatAnnounceLust to false after DB reset")
      Assert.False(piTextCheck:GetChecked(), "Refresh must resync powerInfusionTextEnabled to false after DB reset")
      ---@diagnostic enable: undefined-field
    end)
  end)
end

-- UC-20: Settings -> Debug clear-log buttons. The button-creation path is
-- exercised by the broader Advanced tests via Refresh / frame counting, but
-- the OnClick handler that actually calls config.onClearQueueDebugLog /
-- config.onClearRuntimeLog had zero coverage. These tests trigger the
-- handler directly and assert the wired callback runs.
return function(test, ctx)
  local Assert = RequireValue(ctx.assert, "UI settings scenario ctx.assert should exist")
  local WithGlobals = RequireValue(ctx.with_globals, "UI settings scenario ctx.with_globals should exist")
  local LoadAddonModules = RequireValue(ctx.load_modules, "UI settings scenario ctx.load_modules should exist")

  RegisterSettingsPanelTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterSettingsPanelBehaviorTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterSettingsPanelAdvancedTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterSettingsPanelSoundAndLegacyTests(test, Assert, WithGlobals, LoadAddonModules)
end
