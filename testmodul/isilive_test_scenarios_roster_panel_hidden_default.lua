---@diagnostic disable: undefined-global
local function LoadRosterPanelHelpers()
  local chunk, loadErr = loadfile("testmodul/isilive_test_scenarios_roster_panel.lua")
  if not chunk then
    error(string.format("cannot load roster_panel helpers: %s", tostring(loadErr)))
  end
  local helperAddon = {}
  local ok, runErr = pcall(chunk, "isiLive", helperAddon)
  if not ok then
    error(string.format("cannot execute roster_panel helpers: %s", tostring(runErr)))
  end
  return helperAddon._RosterPanelTests or {}
end

local H = LoadRosterPanelHelpers()
local NewRecordedFrame = H.NewRecordedFrame
local FindFrameByProperty = H.FindFrameByProperty
local FindM2ColumnGuides = H.FindM2ColumnGuides
local BuildHiddenSettingTestController = H.BuildHiddenSettingTestController

local function RegisterRosterPanelHiddenDisplayDefaultTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster panel keeps active members visible ahead of persisted ghosts", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_roster.lua",
        "isiLive_roster_panel.lua",
      })

      local roster = {
        player = { name = "Player", role = "DAMAGER" },
        party1 = { name = "Bircan", role = "DAMAGER" },
        party2 = { name = "Zidane", role = "DAMAGER" },
        party3 = { name = "Kurshad", role = "DAMAGER" },
        ["ghost:OldTank-Realm"] = { name = "OldTank", role = "TANK", isGhost = true },
        ["ghost:OldHeal-Realm"] = { name = "OldHeal", role = "HEALER", isGhost = true },
      }

      local controller = BuildHiddenSettingTestController(addon, createdFontStrings, {
        buildOrderedRoster = function(currentRoster, rolePriority, unitPriority)
          return addon.Roster.BuildOrderedRoster(currentRoster, rolePriority, unitPriority)
        end,
        buildDisplayData = function(info)
          return {
            colorHex = info.isGhost and "ff808080" or "ffffffff",
            displayName = info.name,
            languageDisplay = "",
            specText = "-",
            ilvlText = "-",
            rioText = "-",
            keyText = "-",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        rolePriority = {
          TANK = 1,
          HEALER = 2,
          DAMAGER = 3,
          NONE = 4,
        },
        unitPriority = {
          player = 1,
          party1 = 2,
          party2 = 3,
          party3 = 4,
          party4 = 5,
        },
      })

      controller.RenderRoster(roster)

      local visibleRowNames = {}
      for _, fontString in ipairs(createdFontStrings) do
        if
          fontString.pointX == 93
          and fontString.pointY ~= -34
          and type(fontString.text) == "string"
          and fontString.text ~= ""
        then
          table.insert(visibleRowNames, fontString.text)
        end
      end

      Assert.Equal(#visibleRowNames, 5, "roster should still render only five visible rows")
      Assert.True(visibleRowNames[1]:find("Player", 1, true) ~= nil, "player should stay visible before ghosts")
      Assert.True(visibleRowNames[2]:find("Bircan", 1, true) ~= nil, "first active party member should stay visible")
      Assert.True(visibleRowNames[3]:find("Zidane", 1, true) ~= nil, "second active party member should stay visible")
      Assert.True(visibleRowNames[4]:find("Kurshad", 1, true) ~= nil, "active members must not be pushed out by ghosts")
      Assert.True(
        visibleRowNames[5]:find("OldTank", 1, true) ~= nil,
        "a persisted ghost may consume only leftover row budget"
      )
      for _, rowText in ipairs(visibleRowNames) do
        Assert.False(
          rowText:find("OldHeal", 1, true) ~= nil,
          "extra ghosts must stay behind all active members when the row budget is exhausted"
        )
      end
    end)
  end)

  test("Roster panel first visible render rescans cd tracker after hidden mode", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local mainFrameShownState = { value = false }
    local cdScans = 0

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings, {
        mainFrameShownState = mainFrameShownState,
      })

      controller.SetCdController({
        Scan = function()
          cdScans = cdScans + 1
        end,
        GetBResInfo = function()
          return nil
        end,
        GetLustInfo = function()
          return nil
        end,
      })

      controller.RenderRoster({})
      Assert.Equal(cdScans, 0, "hidden pre-render must not rescan the local CD tracker")

      mainFrameShownState.value = true
      controller.MarkCdTrackerDirty()
      controller.RenderRoster({})
      controller.RenderRoster({})
    end)

    Assert.Equal(cdScans, 1, "first visible render after hidden mode must rescan the CD tracker exactly once")
  end)

  test("Roster panel visible render does not rescan cd tracker after an explicit cd refresh", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local cdScans = 0

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings)

      controller.SetCdController({
        Scan = function()
          cdScans = cdScans + 1
        end,
        GetBResInfo = function()
          return nil
        end,
        GetLustInfo = function()
          return nil
        end,
      })

      controller.RefreshCdTracker()
      controller.RenderRoster({})
    end)

    Assert.Equal(
      cdScans,
      0,
      "visible render must not rescan immediately after an explicit CD refresh already updated the row"
    )
  end)

  test("Roster panel keeps column guides hidden even when stale saved data is present", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local createdTextures = {}

    WithGlobals({
      IsiLiveDB = {
        rosterDefaultLayoutMode = "compact_main_horizontal",
      },
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings, {
        createdTextures = createdTextures,
      })

      local guides = FindM2ColumnGuides(createdTextures)
      local expectedGuideX = {
        spec = 56,
        server = 93,
        name = 215,
        key = 278,
        ilvl = 314,
        rio = 388,
        dps = 430,
      }

      for guideKey, expectedX in pairs(expectedGuideX) do
        local guide = guides[guideKey]
        Assert.NotNil(guide, "M2 guide " .. guideKey .. " should exist")
        Assert.Equal(guide.pointX, expectedX, "M2 guide " .. guideKey .. " should sit at the expected boundary")
        Assert.False(guide:IsShown(), "column guides should start hidden while the setting is off")
      end

      IsiLiveDB.showRosterColumnGuides = true
      controller.RefreshLayoutState()

      for guideKey, _ in pairs(expectedGuideX) do
        Assert.False(guides[guideKey]:IsShown(), "stale column-guide saved data must not show guides")
      end

      controller.RestoreSavedState()

      for guideKey, _ in pairs(expectedGuideX) do
        Assert.False(guides[guideKey]:IsShown(), "stale column-guide saved data must stay ignored in M2")
      end
    end)
  end)
end

local function RegisterRosterPanelMainLayoutVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster panel keeps the status line only in the main M layout", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      IsiLiveDB = {},
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings)

      local statusLine = controller.GetStatusLine()
      Assert.NotNil(statusLine, "status line should exist")
      Assert.True(statusLine:IsShown(), "status line should be visible in the main M layout")

      controller.RestoreSavedState()

      Assert.False(statusLine:IsShown(), "status line should hide in M2")
    end)
  end)

  test("Roster panel hides the main-panel combat logging and DM reset toggles", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      IsiLiveDB = {},
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      BuildHiddenSettingTestController(addon, createdFontStrings)

      local combatLoggingToggle = FindFrameByProperty(createdFrames, "_cvarName", "advancedCombatLogging")
      local damageMeterResetToggle = FindFrameByProperty(createdFrames, "_cvarName", "damageMeterResetOnNewInstance")

      Assert.NotNil(combatLoggingToggle, "combat logging toggle should exist in the main panel")
      Assert.NotNil(damageMeterResetToggle, "damage-meter reset toggle should exist in the main panel")
      ---@diagnostic disable-next-line: undefined-field
      Assert.False(combatLoggingToggle:IsShown(), "combat logging toggle should stay hidden in the main panel")
      ---@diagnostic disable-next-line: undefined-field
      Assert.False(damageMeterResetToggle:IsShown(), "DM reset toggle should stay hidden in the main panel")
    end)
  end)
end

local function RegisterRosterPanelRestoreDefaultLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster panel restore prefers the configured default layout when opening", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      IsiLiveDB = {
        rosterLayoutMode = "compact_vertical",
        rosterDefaultLayoutMode = "compact_main_horizontal",
      },
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings)

      controller.RestoreSavedState()

      Assert.Equal(
        controller.GetLayoutMode(),
        "compact_main_horizontal",
        "configured default layout should override the saved layout mode when opening"
      )
      Assert.False(controller.IsCollapsed(), "configured default M2 layout should stay in the main horizontal mode")
    end)
  end)

  test("Roster panel defaults to M2 when no default is configured", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      IsiLiveDB = {},
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings)

      controller.RestoreSavedState()

      Assert.Equal(
        controller.GetLayoutMode(),
        "compact_main_horizontal",
        "without a configured default, the roster should open in M2"
      )
      Assert.False(controller.IsCollapsed(), "M2 should keep the roster visible")
    end)
  end)

  test("Roster panel restore honors explicit last-used default layout when configured", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      IsiLiveDB = {
        rosterLayoutMode = "compact_horizontal",
        rosterDefaultLayoutMode = "last_used",
      },
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings)

      controller.RestoreSavedState()

      Assert.Equal(
        controller.GetLayoutMode(),
        "compact_horizontal",
        "explicit last-used default should restore the saved compact layout"
      )
      Assert.True(controller.IsCollapsed(), "explicit last-used default should keep compact horizontal collapsed")
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterRosterPanelHiddenDisplayDefaultTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelMainLayoutVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRestoreDefaultLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
end
