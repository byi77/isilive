---@diagnostic disable: undefined-global
local helpersChunk, helpersErr = loadfile("testmodul/isilive_test_ui_helpers.lua")
if not helpersChunk then
  error("cannot load UI helpers: " .. tostring(helpersErr))
end
local helpers = helpersChunk()
local RequireValue = helpers.RequireValue
local FindCombatRetryFrame = helpers.FindCombatRetryFrame
local BuildCreateFrameStub = helpers.BuildCreateFrameStub
local function RegisterGameMenuReloadButtonDeferredTests(test, Assert, WithGlobals, LoadAddonModules)
  test("UI game-menu panels rely on parent visibility instead of deferred host callbacks", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
      })
      local onHide = gameMenuFrame._scripts and gameMenuFrame._scripts.OnHide or nil
      Assert.Nil(onHide, "game menu should not need an OnHide hook for mounted panel children")
      Assert.True(
        strip.panelFrame:IsShown(),
        "mounted panel should stay shown and inherit visibility from GameMenuFrame"
      )
      local professionsButton = RequireValue(strip.buttonsById.professions, "profession shortcut should exist")
      Assert.Equal(
        professionsButton._isiLiveSemanticRole,
        "secondary",
        "game-menu shortcuts must use the shared secondary action role"
      )
      professionsButton._scripts.OnEnter(professionsButton)
      Assert.Equal(professionsButton._isiLiveVisualState, "hover", "game-menu shortcut hover must repaint semantically")
      professionsButton._scripts.OnLeave(professionsButton)
      Assert.Equal(professionsButton._isiLiveVisualState, "default", "game-menu shortcut leave must restore its role")
    end)
  end)
  test(
    "UI game-menu first combat open keeps mounted panel visible while insecure shortcuts are combat-blocked",
    function()
      local inCombat = false
      local createFrameStub, createdFrames = BuildCreateFrameStub({
        simulateProtectedFrames = true,
        isInCombat = function()
          return inCombat
        end,
      })
      local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
      gameMenuFrame._isProtected = true
      local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
      gameMenuFrame.CloseButton = closeButton
      WithGlobals({
        CreateFrame = createFrameStub,
        GameMenuFrame = gameMenuFrame,
      }, function()
        local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
        local UI = RequireValue(addon.UI, "UI module should load")
        local professionsActionCalls = 0
        local strip = UI.EnsurePanelUI({
          gameMenuFrame = gameMenuFrame,
          isInCombat = function()
            return inCombat
          end,
          panelActions = {
            professions = function()
              professionsActionCalls = professionsActionCalls + 1
            end,
          },
        })
        local panelFrame = RequireValue(strip.panelFrame, "panel frame should exist")
        local professionsButton = RequireValue(strip.buttonsById.professions, "profession shortcut should exist")
        gameMenuFrame:Hide()
        local onShow = gameMenuFrame._scripts and gameMenuFrame._scripts.OnShow or nil
        onShow = Assert.NotNil(onShow, "game menu should register an OnShow hook")
        inCombat = true
        gameMenuFrame._shown = true
        local okShow, errShow = pcall(function()
          onShow(gameMenuFrame)
        end)
        Assert.True(okShow, "combat game-menu OnShow should stay mutation-free: " .. tostring(errShow))
        Assert.True(panelFrame:IsShown(), "mounted panel should stay shown through the first combat open")
        Assert.True(professionsButton:IsShown(), "insecure shortcut button should stay visible during combat")
        local onClick = professionsButton._scripts and professionsButton._scripts.OnClick or nil
        onClick = Assert.NotNil(onClick, "profession shortcut should keep an OnClick handler")
        onClick(professionsButton)
        Assert.Equal(professionsActionCalls, 0, "insecure shortcut action should no-op during combat")
        local retryFrame = FindCombatRetryFrame(createdFrames)
        Assert.NotNil(retryFrame, "combat secure refresh should rely on the regen retry frame")
        inCombat = false
        retryFrame = RequireValue(retryFrame, "combat secure refresh should rely on the regen retry frame")
        retryFrame:FireEvent("PLAYER_REGEN_ENABLED")
        Assert.True(panelFrame:IsShown(), "mounted panel should remain visible after regen")
        onClick(professionsButton)
        Assert.Equal(professionsActionCalls, 1, "insecure shortcut action should execute again after combat")
      end)
    end
  )
  test("UI second game-menu panel also stays visible during combat", function()
    local inCombat = false
    local createFrameStub, createdFrames = BuildCreateFrameStub({
      simulateProtectedFrames = true,
      isInCombat = function()
        return inCombat
      end,
    })
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    gameMenuFrame._isProtected = true
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
        isInCombat = function()
          return inCombat
        end,
      })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = strip,
        isInCombat = function()
          return inCombat
        end,
        getL = function()
          return {
            BTN_SECOND_HEARTHSTONE = "Hearthstone",
            BTN_SECOND_HOUSING = "Housing",
            PANEL_HEADER_TRAVEL = "Travel",
          }
        end,
      })
      local travelPanel = RequireValue(travelStrip.panelFrame, "travel panel frame should exist")
      gameMenuFrame:Hide()
      local onShow = gameMenuFrame._scripts and gameMenuFrame._scripts.OnShow or nil
      onShow = Assert.NotNil(onShow, "game menu should register a shared OnShow hook")
      inCombat = true
      gameMenuFrame._shown = true
      local okShow, errShow = pcall(function()
        onShow(gameMenuFrame)
      end)

      Assert.True(okShow, "combat game-menu OnShow should keep the second panel mounted: " .. tostring(errShow))
      Assert.True(travelPanel:IsShown(), "second panel should remain visible through the combat open")
      Assert.True(
        travelStrip.buttonsById.hearthstone:IsShown(),
        "second-panel button should stay visible during combat"
      )

      local retryFrame = FindCombatRetryFrame(createdFrames)
      Assert.NotNil(retryFrame, "combat second-panel show should rely on the regen retry frame")

      inCombat = false
      retryFrame = RequireValue(retryFrame, "combat second-panel show should rely on the regen retry frame")
      retryFrame:FireEvent("PLAYER_REGEN_ENABLED")

      Assert.True(travelPanel:IsShown(), "second panel should remain visible after regen")
    end)
  end)

  test("UI third game-menu addon panel also stays visible during combat", function()
    local inCombat = false
    local createFrameStub, createdFrames = BuildCreateFrameStub({
      simulateProtectedFrames = true,
      isInCombat = function()
        return inCombat
      end,
    })
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    gameMenuFrame._isProtected = true
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if addOnName == "MythicDungeonTools" then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(addOnName)
          return addOnName == "MythicDungeonTools" and 2 or 0
        end,
        IsAddOnLoaded = function(addOnName)
          return addOnName == "MythicDungeonTools"
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
        isInCombat = function()
          return inCombat
        end,
      })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = strip,
        isInCombat = function()
          return inCombat
        end,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
        isInCombat = function()
          return inCombat
        end,
        getL = function()
          return {
            BTN_ADDON_MDT = "MDT",
            PANEL_HEADER_ADDONS = "Addons",
          }
        end,
      })
      addonStrip = Assert.NotNil(addonStrip, "addon shortcut panel should exist for loaded addons")
      local addonPanel = RequireValue(addonStrip.panelFrame, "addon panel frame should exist")
      local mdtButton = RequireValue(addonStrip.buttonsById.mdt, "MDT button should exist")
      gameMenuFrame:Hide()

      local onShow = gameMenuFrame._scripts and gameMenuFrame._scripts.OnShow or nil
      onShow = Assert.NotNil(onShow, "game menu should register a shared OnShow hook")

      inCombat = true
      gameMenuFrame._shown = true
      local okShow, errShow = pcall(function()
        onShow(gameMenuFrame)
      end)

      Assert.True(okShow, "combat game-menu OnShow should keep the addon panel mounted: " .. tostring(errShow))
      Assert.True(addonPanel:IsShown(), "addon panel should remain visible through the combat open")
      Assert.True(mdtButton:IsShown(), "addon-panel button should stay visible during combat")

      local retryFrame = FindCombatRetryFrame(createdFrames)
      Assert.NotNil(retryFrame, "combat addon-panel show should rely on the regen retry frame")

      inCombat = false
      retryFrame = RequireValue(retryFrame, "combat addon-panel show should rely on the regen retry frame")
      retryFrame:FireEvent("PLAYER_REGEN_ENABLED")

      Assert.True(addonPanel:IsShown(), "addon panel should remain visible after regen")
    end)
  end)

  test("UI second game-menu Arkantine shortcut uses the exact localized item name", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      GetLocale = function()
        return "deDE"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
      })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = strip,
        getL = function()
          return {
            BTN_SECOND_ARKANATINE_KEY = "Arkantine",
            BTN_SECOND_HEARTHSTONE = "Hearthstone",
            BTN_SECOND_HOUSING = "Housing",
            PANEL_HEADER_TRAVEL = "Travel",
          }
        end,
      })

      local arkanatineButton =
        RequireValue(travelStrip.buttonsById.arkanatine_key, "arkantine shortcut button should exist")
      Assert.Equal(
        arkanatineButton:GetAttribute("macrotext1"),
        "/use Persönlicher Schlüssel zur Arkantine",
        "German Arkantine shortcut must use the exact localized item name"
      )
    end)
  end)

  test("UI third game-menu addon panel shows installed and enabled addon shortcuts", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local installed = {
      isiLive = true,
      MythicDungeonTools = true,
      ["DBM-Core"] = true,
      BigWigs = true,
      Details = true,
      Simulationcraft = true,
      Platynator = true,
    }
    local enabled = {
      isiLive = true,
      MythicDungeonTools = true,
      ["DBM-Core"] = true,
      BigWigs = true,
      Details = true,
      Simulationcraft = true,
      Platynator = true,
    }
    local loaded = {
      isiLive = true,
      MythicDungeonTools = true,
      ["DBM-Core"] = true,
      BigWigs = true,
      Details = false,
      Simulationcraft = true,
      Platynator = true,
    }
    local slashCalls = {}

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if installed[addOnName] then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(addOnName)
          return enabled[addOnName] and 2 or 0
        end,
        IsAddOnLoaded = function(addOnName)
          return loaded[addOnName] == true
        end,
        LoadAddOn = function() end,
      },
      SlashCmdList = {
        ISILIVE = function()
          slashCalls[#slashCalls + 1] = "ISILIVE"
        end,
        MYTHICDUNGEONTOOLS = function()
          slashCalls[#slashCalls + 1] = "MDT"
        end,
        DEADLYBOSSMODS = function()
          slashCalls[#slashCalls + 1] = "DBM"
        end,
        BigWigs = function()
          slashCalls[#slashCalls + 1] = "BigWigs"
        end,
        Simulationcraft = function()
          slashCalls[#slashCalls + 1] = "SIMC"
        end,
        Platynator = function()
          slashCalls[#slashCalls + 1] = "PLATYNATOR"
        end,
      },
      SLASH_ISILIVE1 = "/isilive",
      SLASH_MYTHICDUNGEONTOOLS2 = "/mdt",
      SLASH_DEADLYBOSSMODS1 = "/dbm",
      SLASH_BigWigs2 = "/bigwigs",
      SLASH_Simulationcraft1 = "/simc",
      SLASH_Platynator1 = "/platynator",
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
        getL = function()
          return {
            PANEL_HEADER_TRAVEL = "Travel",
          }
        end,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
        getL = function()
          return {
            PANEL_HEADER_ADDONS = "Addons",
            BTN_ADDON_ISILIVE = "isiLive",
            BTN_ADDON_MDT = "MDT",
            BTN_ADDON_DBM = "DBM",
            BTN_ADDON_BIGWIGS = "BigWigs",
            BTN_ADDON_DETAILS = "Details",
            BTN_ADDON_SIMC = "SimC",
            BTN_ADDON_PLATYNATOR = "Platynator",
          }
        end,
      })

      addonStrip = Assert.NotNil(addonStrip, "addon shortcut panel should exist when supported addons are loaded")
      Assert.NotNil(addonStrip.buttonsById.isilive, "enabled isiLive must create a shortcut button")
      Assert.NotNil(addonStrip.buttonsById.mdt, "loaded MDT must create a shortcut button")
      Assert.NotNil(addonStrip.buttonsById.dbm, "loaded DBM must create a shortcut button")
      Assert.NotNil(addonStrip.buttonsById.bigwigs, "loaded BigWigs must create a shortcut button")
      Assert.Nil(addonStrip.buttonsById.mrt, "missing MRT must not create a shortcut button")
      Assert.NotNil(addonStrip.buttonsById.details, "enabled Details must create a shortcut button before it is loaded")
      Assert.NotNil(addonStrip.buttonsById.simc, "loaded SimC must create a shortcut button")
      Assert.NotNil(addonStrip.buttonsById.platynator, "loaded Platynator must create a shortcut button")
      Assert.Equal(addonStrip.shortcutsHeader:GetText(), "Addons", "addon panel header must be localized")

      local _, relativeTo = addonStrip.panelFrame:GetPoint()
      Assert.Equal(relativeTo, travelStrip.panelFrame, "addon panel must anchor to the left of the travel panel")

      local onClickSimc = addonStrip.buttonsById.simc._scripts and addonStrip.buttonsById.simc._scripts.OnClick
      onClickSimc = Assert.NotNil(onClickSimc, "SimC shortcut must define OnClick")
      onClickSimc(addonStrip.buttonsById.simc, "LeftButton")
      Assert.Equal(slashCalls[1], "SIMC", "SimC shortcut must call the registered slash handler")
    end)
  end)

  test("UI third game-menu addon shortcut loads enabled addon before running slash", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local installed = {
      Details = true,
    }
    local enabled = {
      Details = true,
    }
    local loaded = {
      Details = false,
    }
    local slashCmdList = {}
    local loadCalls = {}
    local slashCalls = {}

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      GetLocale = function()
        return "deDE"
      end,
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if installed[addOnName] then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(addOnName)
          return enabled[addOnName] and 2 or 0
        end,
        IsAddOnLoaded = function(addOnName)
          return loaded[addOnName] == true
        end,
        LoadAddOn = function(addOnName)
          loadCalls[#loadCalls + 1] = addOnName
          loaded[addOnName] = true
          slashCmdList.DETAILS = function(msg)
            slashCalls[#slashCalls + 1] = msg
          end
          _G.SLASH_DETAILS1 = "/details"
        end,
      },
      SlashCmdList = slashCmdList,
      SLASH_DETAILS1 = false,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
      })
      addonStrip = Assert.NotNil(addonStrip, "addon shortcut panel should exist for enabled Details")

      local detailsButton = RequireValue(addonStrip.buttonsById.details, "Details shortcut button should exist")
      local onClick = detailsButton._scripts and detailsButton._scripts.OnClick
      onClick = Assert.NotNil(onClick, "Details shortcut must define OnClick")
      onClick(detailsButton, "LeftButton")

      Assert.Equal(loadCalls[1], "Details", "Details shortcut must load the enabled addon before invoking slash")
      Assert.Equal(slashCalls[1], "optionen", "Details shortcut must run the localized slash after loading")
    end)
  end)

  test("UI third game-menu addon shortcut uses current-character enable state", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local loaded = {
      Details = false,
    }
    local loadCalls = {}
    local slashCalls = {}

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      UnitExists = function()
        return true
      end,
      UnitName = function(unit)
        Assert.Equal(unit, "player", "addon shortcut enable state should resolve the current player name")
        return "Activechar"
      end,
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if addOnName == "Details" then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(addOnName, character)
          Assert.Equal(addOnName, "Details", "enable state should be queried for Details")
          Assert.Equal(character, "Activechar", "enable state must be scoped to the current character")
          return 2
        end,
        IsAddOnLoaded = function(addOnName)
          return loaded[addOnName] == true
        end,
        LoadAddOn = function(addOnName)
          loadCalls[#loadCalls + 1] = addOnName
          loaded[addOnName] = true
        end,
      },
      SlashCmdList = {
        DETAILS = function(msg)
          slashCalls[#slashCalls + 1] = msg
        end,
      },
      SLASH_DETAILS1 = "/details",
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
      })
      addonStrip = Assert.NotNil(addonStrip, "addon shortcut panel should exist for current-character Details")

      local detailsButton =
        RequireValue(addonStrip.buttonsById.details, "current-character Details button should exist")
      local onClick = detailsButton._scripts and detailsButton._scripts.OnClick
      onClick = Assert.NotNil(onClick, "Details shortcut must define OnClick")
      onClick(detailsButton, "LeftButton")

      Assert.Equal(loadCalls[1], "Details", "current-character enabled addon should be loaded on click")
      Assert.Equal(slashCalls[1], "options", "current-character enabled addon should run its slash handler")
    end)
  end)

  test("UI third game-menu addon shortcut accepts character-scoped enabled state", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local loaded = {
      MythicDungeonTools = true,
    }
    local slashCalls = 0

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      UnitExists = function()
        return true
      end,
      UnitName = function()
        return "Currentchar"
      end,
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if addOnName == "MythicDungeonTools" then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(addOnName, character)
          Assert.Equal(addOnName, "MythicDungeonTools", "enable state should be queried for MDT")
          Assert.Equal(character, "Currentchar", "enable state must use the current character")
          return 1
        end,
        IsAddOnLoaded = function(addOnName)
          return loaded[addOnName] == true
        end,
        LoadAddOn = function() end,
      },
      SlashCmdList = {
        MYTHICDUNGEONTOOLS = function(msg)
          if msg == "" then
            slashCalls = slashCalls + 1
          end
        end,
      },
      SLASH_MYTHICDUNGEONTOOLS2 = "/mdt",
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
      })
      addonStrip = Assert.NotNil(addonStrip, "addon shortcut panel should exist for character-scoped MDT")

      local mdtButton = RequireValue(addonStrip.buttonsById.mdt, "character-scoped MDT button should exist")
      local onClick = mdtButton._scripts and mdtButton._scripts.OnClick
      onClick = Assert.NotNil(onClick, "MDT shortcut must define OnClick")
      onClick(mdtButton, "LeftButton")

      Assert.Equal(slashCalls, 1, "character-scoped enabled addon should run its slash handler")
    end)
  end)

  test("UI third game-menu addon panel hides addons enabled only on another character", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local loadCalls = 0

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      -- UnitExists must be stubbed, otherwise the character name never resolves
      -- and this scenario would pass through the unresolved-character path
      -- instead of the character-scoped one it is named after.
      UnitExists = function()
        return true
      end,
      UnitName = function()
        return "Currentchar"
      end,
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if addOnName == "Details" then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(_addOnName, character)
          if character == "Currentchar" then
            return 0
          end
          return 1
        end,
        IsAddOnLoaded = function()
          return false
        end,
        LoadAddOn = function()
          loadCalls = loadCalls + 1
        end,
      },
      SlashCmdList = {
        DETAILS = function() end,
      },
      SLASH_DETAILS1 = "/details",
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
      })

      Assert.Nil(addonStrip, "addon panel must stay hidden when supported addons are disabled on this character")
      Assert.Equal(loadCalls, 0, "disabled current-character addons must not be loaded by shortcut setup")
    end)
  end)

  test("UI third game-menu isiLive shortcut can use direct settings action without self-load", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local loadCalls = {}
    local openSettingsCalls = 0
    local slashCalls = {}

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if addOnName == "isiLive" then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(addOnName)
          return addOnName == "isiLive" and 2 or 0
        end,
        IsAddOnLoaded = function()
          return false
        end,
        LoadAddOn = function(addOnName)
          loadCalls[#loadCalls + 1] = addOnName
        end,
      },
      SlashCmdList = {
        ISILIVE = function(msg)
          slashCalls[#slashCalls + 1] = msg
        end,
      },
      SLASH_ISILIVE1 = "/isilive",
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
        panelActions = {
          isilive = function()
            openSettingsCalls = openSettingsCalls + 1
            return true
          end,
        },
      })
      addonStrip = Assert.NotNil(addonStrip, "addon shortcut panel should exist for enabled isiLive")

      local isiLiveButton = RequireValue(addonStrip.buttonsById.isilive, "isiLive shortcut button should exist")
      local onClick = isiLiveButton._scripts and isiLiveButton._scripts.OnClick
      onClick = Assert.NotNil(onClick, "isiLive shortcut must define OnClick")
      onClick(isiLiveButton, "LeftButton")

      Assert.Equal(#loadCalls, 0, "isiLive shortcut must not try to load its own already-running addon")
      Assert.Equal(openSettingsCalls, 1, "isiLive shortcut must call the direct settings opener")
      Assert.Equal(#slashCalls, 0, "direct isiLive settings action must not depend on slash dispatch")
    end)
  end)

  test("UI third game-menu addon shortcuts resolve registered slash aliases and arguments", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local installed = {
      isiLive = true,
      MRT = true,
      ["DBM-Core"] = true,
      BigWigs = true,
      Details = true,
      Simulationcraft = true,
      Platynator = true,
    }
    local slashCalls = {}

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      GetLocale = function()
        return "deDE"
      end,
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if installed[addOnName] then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(addOnName)
          return installed[addOnName] and 2 or 0
        end,
        IsAddOnLoaded = function(addOnName)
          return installed[addOnName] == true
        end,
        LoadAddOn = function() end,
      },
      SlashCmdList = {
        ISILIVE = function(msg)
          slashCalls[#slashCalls + 1] = { id = "isilive", msg = msg }
        end,
        mrtSlash = function(msg)
          slashCalls[#slashCalls + 1] = { id = "mrt", msg = msg }
        end,
        DEADLYBOSSMODS = function(msg)
          slashCalls[#slashCalls + 1] = { id = "dbm", msg = msg }
        end,
        BigWigs = function(msg)
          slashCalls[#slashCalls + 1] = { id = "bigwigs", msg = msg }
        end,
        DETAILS = function(msg)
          slashCalls[#slashCalls + 1] = { id = "details", msg = msg }
        end,
        Simulationcraft = function(msg)
          slashCalls[#slashCalls + 1] = { id = "simc", msg = msg }
        end,
        Platynator = function(msg)
          slashCalls[#slashCalls + 1] = { id = "platynator", msg = msg }
        end,
      },
      SLASH_ISILIVE1 = "/isilive",
      SLASH_mrtSlash6 = "/mrt",
      SLASH_DEADLYBOSSMODS1 = "/dbm",
      SLASH_BigWigs2 = "/bigwigs",
      SLASH_DETAILS1 = "/details",
      SLASH_Simulationcraft1 = "/simc",
      SLASH_Platynator1 = "/platynator",
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
      })
      addonStrip = Assert.NotNil(addonStrip, "addon shortcut panel should exist")

      local ids = { "isilive", "mrt", "dbm", "bigwigs", "details", "simc", "platynator" }
      for _, id in ipairs(ids) do
        local button = RequireValue(addonStrip.buttonsById[id], id .. " shortcut button should exist")
        local onClick = button._scripts and button._scripts.OnClick
        onClick = Assert.NotNil(onClick, id .. " shortcut must define OnClick")
        onClick(button, "LeftButton")
      end

      Assert.Equal(slashCalls[1].id, "isilive", "isiLive shortcut must resolve /isilive")
      Assert.Equal(slashCalls[1].msg, "settings", "isiLive shortcut must pass the settings argument")
      Assert.Equal(slashCalls[2].id, "mrt", "MRT shortcut must resolve the mixed-case mrtSlash alias")
      Assert.Equal(slashCalls[2].msg, "", "MRT shortcut should pass no arguments")
      Assert.Equal(slashCalls[3].id, "dbm", "DBM shortcut must resolve /dbm")
      Assert.Equal(slashCalls[3].msg, "", "DBM shortcut should pass no arguments")
      Assert.Equal(slashCalls[4].id, "bigwigs", "BigWigs shortcut must resolve /bigwigs")
      Assert.Equal(slashCalls[4].msg, "", "BigWigs shortcut should pass no arguments")
      Assert.Equal(slashCalls[5].id, "details", "Details shortcut must resolve /details")
      Assert.Equal(slashCalls[5].msg, "optionen", "German Details shortcut must pass the localized options argument")
      Assert.Equal(slashCalls[6].id, "simc", "SimC shortcut must resolve AceConsole's registered /simc alias")
      Assert.Equal(slashCalls[6].msg, "", "SimC shortcut should pass no arguments")
      Assert.Equal(slashCalls[7].id, "platynator", "Platynator shortcut must resolve the mixed-case alias")
      Assert.Equal(slashCalls[7].msg, "", "Platynator shortcut should pass no arguments")
    end)
  end)

  test("UI third game-menu addon shortcut repeatedly invokes the verified slash handler", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local sendCalls = 0
    local slashCalls = {}

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if addOnName == "Simulationcraft" then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(addOnName)
          return addOnName == "Simulationcraft" and 2 or 0
        end,
        IsAddOnLoaded = function(addOnName)
          return addOnName == "Simulationcraft"
        end,
        LoadAddOn = function() end,
      },
      SlashCmdList = {
        Simulationcraft = function(msg)
          slashCalls[#slashCalls + 1] = msg
        end,
      },
      SLASH_Simulationcraft1 = "/simc",
      ChatEdit_SendText = function()
        sendCalls = sendCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
      })
      addonStrip = Assert.NotNil(addonStrip, "addon shortcut panel should exist")

      local simcButton = RequireValue(addonStrip.buttonsById.simc, "SimC shortcut button should exist")
      local onClick = simcButton._scripts and simcButton._scripts.OnClick
      onClick = Assert.NotNil(onClick, "SimC shortcut must define OnClick")
      onClick(simcButton, "LeftButton")
      onClick(simcButton, "LeftButton")

      Assert.Equal(#slashCalls, 2, "registered addon slash should call the verified handler on every click")
      Assert.Equal(slashCalls[1], "", "first direct slash call should pass the parsed argument string")
      Assert.Equal(slashCalls[2], "", "second direct slash call should pass the parsed argument string")
      Assert.Equal(sendCalls, 0, "successful direct slash dispatch should not touch the chat edit sender")
    end)
  end)

  test("UI third game-menu addon shortcut waits until the game menu is closed before slash dispatch", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    gameMenuFrame._shown = true
    local scheduled = {}
    local slashCalls = 0

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      HideUIPanel = function()
        return true
      end,
      C_Timer = {
        After = function(delay, callback)
          scheduled[#scheduled + 1] = { delay = delay, callback = callback }
        end,
      },
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if addOnName == "Simulationcraft" then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(addOnName)
          return addOnName == "Simulationcraft" and 2 or 0
        end,
        IsAddOnLoaded = function(addOnName)
          return addOnName == "Simulationcraft"
        end,
        LoadAddOn = function() end,
      },
      SlashCmdList = {
        Simulationcraft = function()
          slashCalls = slashCalls + 1
        end,
      },
      SLASH_Simulationcraft1 = "/simc",
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
      })
      addonStrip = Assert.NotNil(addonStrip, "addon shortcut panel should exist")

      local simcButton = RequireValue(addonStrip.buttonsById.simc, "SimC shortcut button should exist")
      local onClick = simcButton._scripts and simcButton._scripts.OnClick
      onClick = Assert.NotNil(onClick, "SimC shortcut must define OnClick")
      onClick(simcButton, "LeftButton")

      Assert.Equal(slashCalls, 0, "slash dispatch must wait while GameMenuFrame is still shown")
      Assert.Equal(#scheduled, 1, "shown game menu should schedule a bounded close retry")
      Assert.Equal(scheduled[1].delay, 0.05, "game-menu close retry should use a short fixed delay")

      scheduled[1].callback()
      Assert.Equal(slashCalls, 0, "slash dispatch must keep waiting until the menu is observed closed")
      Assert.Equal(#scheduled, 2, "still-shown game menu should keep the bounded close retry chain")

      gameMenuFrame._shown = false
      scheduled[2].callback()
      Assert.Equal(slashCalls, 1, "slash dispatch should run once after the menu is closed")
    end)
  end)

  test("UI third game-menu addon close-before-slash path is shared by supported external addons", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    gameMenuFrame._shown = true
    local scheduled = {}
    local slashCalls = {}

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      HideUIPanel = function()
        return true
      end,
      C_Timer = {
        After = function(delay, callback)
          scheduled[#scheduled + 1] = { delay = delay, callback = callback }
        end,
      },
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if addOnName == "MythicDungeonTools" or addOnName == "Details" then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(addOnName)
          return (addOnName == "MythicDungeonTools" or addOnName == "Details") and 2 or 0
        end,
        IsAddOnLoaded = function(addOnName)
          return addOnName == "MythicDungeonTools" or addOnName == "Details"
        end,
        LoadAddOn = function() end,
      },
      SlashCmdList = {
        MYTHICDUNGEONTOOLS = function(msg)
          slashCalls[#slashCalls + 1] = { id = "mdt", msg = msg }
        end,
        DETAILS = function(msg)
          slashCalls[#slashCalls + 1] = { id = "details", msg = msg }
        end,
      },
      SLASH_MYTHICDUNGEONTOOLS1 = "/mdt",
      SLASH_DETAILS1 = "/details",
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
      })
      addonStrip = Assert.NotNil(addonStrip, "addon shortcut panel should exist")

      local mdtButton = RequireValue(addonStrip.buttonsById.mdt, "MDT shortcut button should exist")
      local detailsButton = RequireValue(addonStrip.buttonsById.details, "Details shortcut button should exist")
      local onClickMdt = mdtButton._scripts and mdtButton._scripts.OnClick
      local onClickDetails = detailsButton._scripts and detailsButton._scripts.OnClick
      onClickMdt = Assert.NotNil(onClickMdt, "MDT shortcut must define OnClick")
      onClickDetails = Assert.NotNil(onClickDetails, "Details shortcut must define OnClick")

      onClickMdt(mdtButton, "LeftButton")
      Assert.Equal(#slashCalls, 0, "MDT slash dispatch must wait while GameMenuFrame is still shown")
      Assert.Equal(#scheduled, 1, "MDT should use the shared game-menu close retry")
      gameMenuFrame._shown = false
      scheduled[1].callback()
      Assert.Equal(slashCalls[1].id, "mdt", "MDT slash should run after observed menu close")

      gameMenuFrame._shown = true
      onClickDetails(detailsButton, "LeftButton")
      Assert.Equal(#slashCalls, 1, "Details slash dispatch must wait while GameMenuFrame is still shown")
      Assert.Equal(#scheduled, 2, "Details should use the same game-menu close retry")
      gameMenuFrame._shown = false
      scheduled[2].callback()
      Assert.Equal(slashCalls[2].id, "details", "Details slash should run after observed menu close")
    end)
  end)

  test("UI third game-menu addon shortcut passes the default chat edit box to slash handlers", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local observedMsg = nil
    local observedEditBox = nil
    local editBox = {}

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      DEFAULT_CHAT_FRAME = {
        editBox = editBox,
      },
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if addOnName == "Simulationcraft" then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(addOnName)
          return addOnName == "Simulationcraft" and 2 or 0
        end,
        IsAddOnLoaded = function(addOnName)
          return addOnName == "Simulationcraft"
        end,
        LoadAddOn = function() end,
      },
      SlashCmdList = {
        Simulationcraft = function(msg, handlerEditBox)
          observedMsg = msg
          observedEditBox = handlerEditBox
        end,
      },
      SLASH_Simulationcraft1 = "/simc",
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
      })
      addonStrip = Assert.NotNil(addonStrip, "addon shortcut panel should exist")

      local simcButton = RequireValue(addonStrip.buttonsById.simc, "SimC shortcut button should exist")
      local onClick = simcButton._scripts and simcButton._scripts.OnClick
      onClick = Assert.NotNil(onClick, "SimC shortcut must define OnClick")
      onClick(simcButton, "LeftButton")

      Assert.Equal(observedMsg, "", "direct slash dispatch should pass the parsed argument string")
      Assert.Equal(observedEditBox, editBox, "direct slash dispatch should mirror WoW's editBox argument")
    end)
  end)

  test("UI third game-menu addon shortcut retries briefly when loaded addon registers slash late", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local loaded = {
      Simulationcraft = true,
    }
    local scheduled = {}
    local slashCalls = {}
    local chatCalls = 0
    local slashCmdList = {}

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if addOnName == "Simulationcraft" then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(addOnName)
          return addOnName == "Simulationcraft" and 2 or 0
        end,
        IsAddOnLoaded = function(addOnName)
          return loaded[addOnName] == true
        end,
        LoadAddOn = function() end,
      },
      C_Timer = {
        After = function(delay, callback)
          if tonumber(delay) == 0 then
            callback()
            return
          end
          scheduled[#scheduled + 1] = callback
        end,
      },
      SlashCmdList = slashCmdList,
      ChatEdit_SendText = function()
        chatCalls = chatCalls + 1
      end,
      ChatEdit_ParseText = function()
        chatCalls = chatCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
      })
      addonStrip = Assert.NotNil(addonStrip, "addon shortcut panel should exist")

      local simcButton = RequireValue(addonStrip.buttonsById.simc, "SimC shortcut button should exist")
      local onClick = simcButton._scripts and simcButton._scripts.OnClick
      onClick = Assert.NotNil(onClick, "SimC shortcut must define OnClick")
      onClick(simcButton, "LeftButton")

      Assert.Equal(#slashCalls, 0, "late SimC slash should not run before its alias exists")
      Assert.Equal(#scheduled, 1, "missing slash alias should schedule a bounded retry")

      scheduled[1]()

      Assert.Equal(#slashCalls, 0, "late SimC slash should keep waiting while the alias is still missing")
      Assert.Equal(#scheduled, 2, "missing slash alias should continue the bounded retry chain")

      slashCmdList.Simulationcraft = function(msg)
        slashCalls[#slashCalls + 1] = msg
      end
      _G.SLASH_Simulationcraft1 = "/simc"
      scheduled[2]()

      Assert.Equal(#slashCalls, 1, "late SimC slash should run once after the verified alias appears")
      Assert.Equal(slashCalls[1], "", "late SimC slash should pass the parsed argument string")
      Assert.Equal(chatCalls, 0, "late slash retry must not use chat edit fallback")
    end)
  end)

  test("UI third game-menu addon shortcut retry path is shared by supported external addons", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local scheduled = {}
    local slashCalls = {}
    local slashCmdList = {}

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if addOnName == "MythicDungeonTools" then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(addOnName)
          return addOnName == "MythicDungeonTools" and 2 or 0
        end,
        IsAddOnLoaded = function(addOnName)
          return addOnName == "MythicDungeonTools"
        end,
        LoadAddOn = function() end,
      },
      C_Timer = {
        After = function(delay, callback)
          if tonumber(delay) == 0 then
            callback()
            return
          end
          scheduled[#scheduled + 1] = callback
        end,
      },
      SlashCmdList = slashCmdList,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
      })
      addonStrip = Assert.NotNil(addonStrip, "addon shortcut panel should exist")

      local mdtButton = RequireValue(addonStrip.buttonsById.mdt, "MDT shortcut button should exist")
      local onClick = mdtButton._scripts and mdtButton._scripts.OnClick
      onClick = Assert.NotNil(onClick, "MDT shortcut must define OnClick")
      onClick(mdtButton, "LeftButton")

      Assert.Equal(#scheduled, 1, "MDT should use the shared missing-alias retry path")

      slashCmdList.MythicDungeonTools = function(msg)
        slashCalls[#slashCalls + 1] = msg
      end
      _G.SLASH_MythicDungeonTools1 = "/mdt"
      scheduled[1]()

      Assert.Equal(#slashCalls, 1, "MDT slash should run after its verified alias appears")
      Assert.Equal(slashCalls[1], "", "MDT slash should pass the parsed argument string")
    end)
  end)

  test("UI third game-menu addon shortcut does not fall back to chat edit when handler fails", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local sendCalls = 0
    local retryCalls = 0

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if addOnName == "Simulationcraft" then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(addOnName)
          return addOnName == "Simulationcraft" and 2 or 0
        end,
        IsAddOnLoaded = function(addOnName)
          return addOnName == "Simulationcraft"
        end,
        LoadAddOn = function() end,
      },
      SlashCmdList = {
        Simulationcraft = function()
          error("simc handler failed", 0)
        end,
      },
      SLASH_Simulationcraft1 = "/simc",
      ChatEdit_SendText = function()
        sendCalls = sendCalls + 1
      end,
      ChatEdit_ParseText = function()
        sendCalls = sendCalls + 1
      end,
      C_Timer = {
        After = function(delay, callback)
          if tonumber(delay) == 0 then
            callback()
            return
          end
          retryCalls = retryCalls + 1
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
      })
      addonStrip = Assert.NotNil(addonStrip, "addon shortcut panel should exist")

      local simcButton = RequireValue(addonStrip.buttonsById.simc, "SimC shortcut button should exist")
      local onClick = simcButton._scripts and simcButton._scripts.OnClick
      onClick = Assert.NotNil(onClick, "SimC shortcut must define OnClick")
      onClick(simcButton, "LeftButton")

      Assert.Equal(sendCalls, 0, "failed handler dispatch must stay closed instead of writing slash text to chat")
      Assert.Equal(retryCalls, 0, "failed registered handlers must not be retried as missing aliases")
    end)
  end)

  test("UI third game-menu addon shortcut fails closed without a registered slash alias", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local calls = 0

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if addOnName == "Simulationcraft" then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(addOnName)
          return addOnName == "Simulationcraft" and 2 or 0
        end,
        IsAddOnLoaded = function(addOnName)
          return addOnName == "Simulationcraft"
        end,
        LoadAddOn = function() end,
      },
      SlashCmdList = {
        UnknownInternalKey = function()
          calls = calls + 1
        end,
      },
      ChatEdit_ParseText = function()
        calls = calls + 1
      end,
      ChatFrame1EditBox = {
        SetText = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
      })
      addonStrip = Assert.NotNil(addonStrip, "addon shortcut panel should exist")

      local simcButton = RequireValue(addonStrip.buttonsById.simc, "SimC shortcut button should exist")
      local onClick = simcButton._scripts and simcButton._scripts.OnClick
      onClick = Assert.NotNil(onClick, "SimC shortcut must define OnClick")
      onClick(simcButton, "LeftButton")

      Assert.Equal(calls, 0, "addon shortcut must not guess internal keys or fall back to chat parsing")
    end)
  end)

  test("UI third game-menu addon panel stays hidden when no supported addon is enabled", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      C_AddOns = {
        GetAddOnInfo = function()
          return nil
        end,
        GetAddOnEnableState = function()
          return 0
        end,
        IsAddOnLoaded = function()
          return false
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
      })
      Assert.Nil(addonStrip, "addon shortcut panel must not render when no supported addon is enabled")
    end)
  end)
end

local function RegisterGameMenuAddonPanelCharacterScopeTests(test, Assert, WithGlobals, LoadAddonModules)
  test("UI third game-menu addon panel survives an unresolvable current character", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      -- WoW 12.0 can mask unit reads inside protected dispatch, so the current
      -- character name is unavailable while the ESC panel is being built. A
      -- character-scoped addon then reports 1, and the shortcut must remain
      -- offered instead of collapsing the whole panel.
      UnitExists = function()
        return true
      end,
      UnitName = function()
        return nil
      end,
      C_AddOns = {
        GetAddOnInfo = function(addOnName)
          if addOnName == "Details" then
            return { name = addOnName }
          end
          return nil
        end,
        GetAddOnEnableState = function(_addOnName, character)
          Assert.Nil(character, "an unresolved character must be forwarded as nil, not guessed")
          return 1
        end,
        IsAddOnLoaded = function()
          return false
        end,
        LoadAddOn = function() end,
      },
      SlashCmdList = {
        DETAILS = function() end,
      },
      SLASH_DETAILS1 = "/details",
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local addonStrip = UI.EnsureThirdPanelUI({
        gameMenuFrame = gameMenuFrame,
        secondPanelState = travelStrip,
      })

      addonStrip = RequireValue(addonStrip, "addon panel must still be built without a resolvable character name")
      RequireValue(addonStrip.buttonsById.details, "character-scoped addon shortcut must stay visible")
    end)
  end)
end

local function RegisterGameMenuMountPanelTests(test, Assert, WithGlobals, LoadAddonModules)
  test("UI mount game-menu panel shows verified mount shortcuts under travel panel", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local spellToMount = {
      [465235] = 2001,
      [122708] = 2002,
    }
    local mountInfo = {
      [1001] = { spellID = 999001, favorite = true, collected = true },
      [2001] = { spellID = 465235, favorite = false, collected = true },
      [2002] = { spellID = 122708, favorite = false, collected = true },
    }

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      C_MountJournal = {
        GetMountIDs = function()
          return { 1001, 2001, 2002 }
        end,
        GetMountFromSpell = function(spellID)
          return spellToMount[spellID]
        end,
        GetMountInfoByID = function(mountID)
          local info = mountInfo[mountID]
          if not info then
            return nil
          end
          return "Mount", info.spellID, nil, false, true, nil, info.favorite, false, nil, false, info.collected
        end,
      },
      C_Spell = {
        GetSpellName = function(spellID)
          local names = {
            [999001] = "Favorite Drake",
            [465235] = "Gilded Trader's Brutosaur",
            [122708] = "Grand Expedition Yak",
          }
          return names[spellID]
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local mountStrip = UI.EnsureMountPanelUI({
        gameMenuFrame = gameMenuFrame,
        travelPanelState = travelStrip,
        getL = function()
          return {
            PANEL_HEADER_MOUNTS = "Mounts",
            BTN_MOUNT_FAVORITE = "Favorite Mount",
            BTN_MOUNT_AH = "AH Mount",
            BTN_MOUNT_REPAIR = "Repair Mount",
          }
        end,
      })

      mountStrip = Assert.NotNil(mountStrip, "mount shortcut panel should exist when verified mounts are available")
      Assert.NotNil(mountStrip.buttonsById.favorite_mount, "favorite mount shortcut must be visible")
      Assert.NotNil(mountStrip.buttonsById.auction_house_mount, "AH mount shortcut must be visible")
      Assert.NotNil(mountStrip.buttonsById.repair_mount, "repair mount shortcut must be visible")
      Assert.Equal(mountStrip.shortcutsHeader:GetText(), "Mounts", "mount panel header must be localized")

      local point, relativeTo, relativePoint = mountStrip.panelFrame:GetPoint()
      Assert.Equal(point, "TOPLEFT", "mount panel must use a below-panel top-left anchor")
      Assert.Equal(relativeTo, travelStrip.panelFrame, "mount panel must anchor below the travel panel")
      Assert.Equal(relativePoint, "BOTTOMLEFT", "mount panel must attach to the travel panel bottom-left")

      local favoriteButton = mountStrip.buttonsById.favorite_mount
      Assert.Equal(favoriteButton:GetAttribute("type"), "macro", "favorite shortcut must be a secure macro button")
      Assert.Equal(
        favoriteButton:GetAttribute("macrotext"),
        "/click GameMenuButtonContinue\n/cast Favorite Drake",
        "favorite shortcut must close the game menu and cast a verified favorite mount spell"
      )
      Assert.Equal(
        mountStrip.buttonsById.auction_house_mount:GetAttribute("macrotext"),
        "/click GameMenuButtonContinue\n/cast Gilded Trader's Brutosaur",
        "AH shortcut must cast the verified Brutosaur spell by localized spell name"
      )
      Assert.Equal(
        mountStrip.buttonsById.auction_house_mount._panelIcon._texture,
        1529269,
        "AH shortcut must use the verified devilsaur lunchbox icon file ID"
      )
      Assert.Equal(
        mountStrip.buttonsById.repair_mount:GetAttribute("macrotext"),
        "/click GameMenuButtonContinue\n/cast Grand Expedition Yak",
        "repair shortcut must cast the verified Expedition Yak spell by localized spell name"
      )
    end)
  end)

  test("UI mount game-menu panel stays hidden when spell names cannot be verified", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      C_MountJournal = {
        GetMountIDs = function()
          return { 1001 }
        end,
        GetMountFromSpell = function(spellID)
          return spellID == 122708 and 1001 or nil
        end,
        GetMountInfoByID = function(mountID)
          if mountID ~= 1001 then
            return nil
          end
          return "Mount", 122708, nil, false, true, nil, false, false, nil, false, true
        end,
      },
      C_Spell = {
        GetSpellName = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local mountStrip = UI.EnsureMountPanelUI({
        gameMenuFrame = gameMenuFrame,
        travelPanelState = travelStrip,
      })
      mountStrip = Assert.NotNil(mountStrip, "mount shortcut panel should stay mounted without a verified spell name")
      Assert.False(
        mountStrip.panelFrame:IsShown(),
        "mount shortcut panel must stay hidden without a verified spell name"
      )
      Assert.False(mountStrip.buttonsById.repair_mount:IsShown(), "unverified mount shortcut must stay hidden")
    end)
  end)

  test("UI mount game-menu panel refreshes mounted shortcuts when verified spell names become available", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local spellNameAvailable = false

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      C_MountJournal = {
        GetMountIDs = function()
          return { 1001 }
        end,
        GetMountFromSpell = function(spellID)
          return spellID == 122708 and 1001 or nil
        end,
        GetMountInfoByID = function(mountID)
          if mountID ~= 1001 then
            return nil
          end
          return "Mount", 122708, nil, false, true, nil, false, false, nil, false, true
        end,
      },
      C_Spell = {
        GetSpellName = function(spellID)
          if spellNameAvailable and spellID == 122708 then
            return "Grand Expedition Yak"
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local mountStrip = UI.EnsureMountPanelUI({
        gameMenuFrame = gameMenuFrame,
        travelPanelState = travelStrip,
        getL = function()
          return {
            PANEL_HEADER_MOUNTS = "Mounts",
            BTN_MOUNT_REPAIR = "Repair Mount",
          }
        end,
      })
      mountStrip = Assert.NotNil(mountStrip, "mount panel should be mounted before spell names are verified")
      Assert.False(
        mountStrip.panelFrame:IsShown(),
        "initial mount panel should stay hidden without verified spell names"
      )
      Assert.False(mountStrip.buttonsById.repair_mount:IsShown(), "initial repair mount shortcut should stay hidden")

      local onShow = gameMenuFrame._scripts and gameMenuFrame._scripts.OnShow or nil
      onShow = Assert.NotNil(onShow, "mount panel should share the GameMenuFrame OnShow refresh")
      spellNameAvailable = true
      onShow(gameMenuFrame)

      mountStrip = UI.EnsureMountPanelUI({
        gameMenuFrame = gameMenuFrame,
        travelPanelState = travelStrip,
      })
      mountStrip = Assert.NotNil(mountStrip, "mount panel should be reused after deferred spell verification")
      Assert.True(mountStrip.panelFrame:IsShown(), "mount panel should show after spell verification")
      Assert.True(
        mountStrip.buttonsById.repair_mount:IsShown(),
        "repair mount shortcut should appear after spell verification"
      )
      Assert.Equal(
        mountStrip.buttonsById.repair_mount:GetAttribute("macrotext"),
        "/click GameMenuButtonContinue\n/cast Grand Expedition Yak",
        "refreshed shortcut must use the verified spell name"
      )
    end)
  end)

  test("UI mount game-menu panel stays hidden when no verified mount shortcut is available", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      C_MountJournal = {
        GetMountIDs = function()
          return {}
        end,
        GetMountFromSpell = function()
          return nil
        end,
        GetMountInfoByID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local toolingStrip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = toolingStrip,
      })
      local mountStrip = UI.EnsureMountPanelUI({
        gameMenuFrame = gameMenuFrame,
        travelPanelState = travelStrip,
      })
      mountStrip =
        Assert.NotNil(mountStrip, "mount shortcut panel should stay mounted without verified available mounts")
      Assert.False(
        mountStrip.panelFrame:IsShown(),
        "mount shortcut panel must stay hidden without verified available mounts"
      )
      Assert.False(mountStrip.buttonsById.favorite_mount:IsShown(), "favorite mount shortcut must stay hidden")
      Assert.False(mountStrip.buttonsById.auction_house_mount:IsShown(), "AH mount shortcut must stay hidden")
      Assert.False(mountStrip.buttonsById.repair_mount:IsShown(), "repair mount shortcut must stay hidden")
    end)
  end)

  test("UI mount game-menu panel also stays visible during combat", function()
    local inCombat = false
    local createFrameStub, createdFrames = BuildCreateFrameStub({
      simulateProtectedFrames = true,
      isInCombat = function()
        return inCombat
      end,
    })
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    gameMenuFrame._isProtected = true
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      C_MountJournal = {
        GetMountIDs = function()
          return { 1001 }
        end,
        GetMountFromSpell = function()
          return nil
        end,
        GetMountInfoByID = function(mountID)
          if mountID ~= 1001 then
            return nil
          end
          return "Mount", 999001, nil, false, true, nil, true, false, nil, false, true
        end,
      },
      C_Spell = {
        GetSpellName = function(spellID)
          if spellID == 999001 then
            return "Favorite Drake"
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
        isInCombat = function()
          return inCombat
        end,
      })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = strip,
        isInCombat = function()
          return inCombat
        end,
      })
      local mountStrip = UI.EnsureMountPanelUI({
        gameMenuFrame = gameMenuFrame,
        travelPanelState = travelStrip,
        isInCombat = function()
          return inCombat
        end,
      })
      mountStrip = Assert.NotNil(mountStrip, "mount shortcut panel should exist")
      local mountPanel = RequireValue(mountStrip.panelFrame, "mount panel frame should exist")
      local favoriteButton = RequireValue(mountStrip.buttonsById.favorite_mount, "favorite button should exist")
      gameMenuFrame:Hide()

      local onShow = gameMenuFrame._scripts and gameMenuFrame._scripts.OnShow or nil
      onShow = Assert.NotNil(onShow, "game menu should register a shared OnShow hook")

      inCombat = true
      gameMenuFrame._shown = true
      local okShow, errShow = pcall(function()
        onShow(gameMenuFrame)
      end)

      Assert.True(okShow, "combat game-menu OnShow should keep the mount panel mounted: " .. tostring(errShow))
      Assert.True(mountPanel:IsShown(), "mount panel should remain visible through the combat open")
      Assert.True(favoriteButton:IsShown(), "mount-panel secure button should stay visible during combat")

      local retryFrame = FindCombatRetryFrame(createdFrames)
      Assert.NotNil(retryFrame, "combat mount-panel show should rely on the regen retry frame")

      inCombat = false
      retryFrame = RequireValue(retryFrame, "combat mount-panel show should rely on the regen retry frame")
      retryFrame:FireEvent("PLAYER_REGEN_ENABLED")

      Assert.True(mountPanel:IsShown(), "mount panel should remain visible after regen")
    end)
  end)
end

local function RegisterHearthstonePickTests(test, Assert, WithGlobals, LoadAddonModules)
  local function LoadPicker()
    local picker
    -- isiLive_ui_game_menu.lua creates its combat-retry frame in the main
    -- chunk, so the module cannot load without a CreateFrame stub.
    WithGlobals({ CreateFrame = BuildCreateFrameStub() }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      picker = RequireValue(UI._Test_PickDifferentEntry, "bounded hearthstone picker should be exposed")
    end)
    return picker
  end

  test("Hearthstone picker terminates on an all-duplicates pool", function()
    -- Regression: the old `repeat ... until pick ~= current` had no bound, so
    -- a pool whose entries all equal the current toy spun forever and froze
    -- the client on a hearthstone click. The toy catalogue has no duplicates
    -- today, which is exactly why this needs a test rather than trust.
    local picker = LoadPicker()
    local pool = { 54452, 54452, 54452 }
    local pick = picker(pool, 54452)
    Assert.Equal(pick, 54452, "an exhausted pool must fall back to the current entry, not loop")
  end)

  test("Hearthstone picker still avoids repeating the current entry when it can", function()
    local picker = LoadPicker()
    local pool = { 1, 2, 3, 4, 5 }
    for _ = 1, 50 do
      Assert.True(picker(pool, 1) ~= 1, "a pool with alternatives must not reroll the current entry")
    end
  end)

  test("Hearthstone picker handles empty and single-entry pools", function()
    local picker = LoadPicker()
    Assert.Nil(picker({}, nil), "an empty pool must yield nil instead of indexing out of range")
    Assert.Equal(picker({ 7 }, 7), 7, "a single-entry pool must return that entry even when it is current")
  end)
end

-- isiLive deliberately registers NO handler in Blizzard's ESC chain.
--
-- Blizzard walks that chain as `securecallfunction(entry.handler)` inside one
-- loop (Blizzard_GameMenuEsc.lua). securecallfunction isolates the handler it
-- calls, but the loop itself stays tainted by whoever ran in it before -- so an
-- addon handler registered ahead of the "Casting" step (priority 4) makes
-- Blizzard's own SpellStopCasting() call fail with ADDON_ACTION_FORBIDDEN.
-- That is exactly what happened in 0.9.379/0.9.380, which is why the priority
-- levels below AddOn (8) belong to Blizzard's own systems.
local function RegisterGameMenuEscChainAbstinenceTests(test, Assert, WithGlobals, LoadAddonModules)
  test("ESC panel registers no handler in Blizzard's ESC chain", function()
    local registrations = {}
    WithGlobals({
      CreateFrame = BuildCreateFrameStub(),
      GameMenuFrame = {
        IsShown = function()
          return false
        end,
      },
      GameMenuEscPriority = { Dialog = 1, Menu = 2, Casting = 4, Framework = 6, AddOn = 8 },
      RegisterGameMenuEscHandler = function(priority, handler)
        table.insert(registrations, { priority = priority, handler = handler })
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")

      Assert.Nil(rawget(UI, "_Test_HandleGameMenuEscapeDuringCast"), "the removed ESC cast guard must not come back")
      Assert.Equal(#registrations, 0, "loading the ESC panel must not register an ESC handler")
    end)
  end)
end

return function(test, ctx)
  local Assert = RequireValue(ctx.assert, "UI game-menu addons scenario ctx.assert should exist")
  local WithGlobals = RequireValue(ctx.with_globals, "UI game-menu addons scenario ctx.with_globals should exist")
  local LoadAddonModules = RequireValue(ctx.load_modules, "UI game-menu addons scenario ctx.load_modules should exist")

  RegisterGameMenuReloadButtonDeferredTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterGameMenuAddonPanelCharacterScopeTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterGameMenuMountPanelTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterHearthstonePickTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterGameMenuEscChainAbstinenceTests(test, Assert, WithGlobals, LoadAddonModules)
end
