---@diagnostic disable: undefined-global
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

  test("StatsBox renders class primary stat and directly observed secondary values", function()
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local StatsBox = addon.StatsBox
      local rows = StatsBox.CollectPlayerStats({
        UnitStat = function(_unit, statIndex)
          if statIndex == 2 then
            return 0, 515
          end
          return nil
        end,
        GetCombatRating = function(ratingID)
          if ratingID == 100 then
            return 60
          end
          return nil
        end,
        GetCombatRatingBonus = function(ratingID)
          if ratingID == 100 then
            return 25.48
          end
          return nil
        end,
        GetCritChance = function()
          return 25.48
        end,
        UnitClass = function()
          return "Hunter", "HUNTER"
        end,
        CR_CRIT_MELEE = 100,
      })

      Assert.Equal(#rows, 2, "unreadable stats must not be rendered as guessed fallback rows")
      Assert.Equal(rows[1].label, "Agi", "hunter primary stat should use the short agility label")
      Assert.Equal(rows[1].value, 515, "primary stat value should come from UnitStat")
      Assert.Equal(rows[2].label, "Crit", "combat rating should render when its rating constant and value exist")
      Assert.Equal(rows[2].percent, 25.48, "crit percent should come from GetCritChance")
    end)
  end)

  test("StatsBox resolves hybrid primary stat only from exact specialization", function()
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local StatsBox = addon.StatsBox
      local unresolvedRows = StatsBox.CollectPlayerStats({
        UnitStat = function(_unit, statIndex)
          if statIndex == 4 then
            return 0, 2200
          end
          return nil
        end,
        UnitClass = function()
          return "Paladin", "PALADIN"
        end,
      })
      Assert.Equal(#unresolvedRows, 0, "hybrid classes must not guess a primary stat when spec is unreadable")

      local holyRows = StatsBox.CollectPlayerStats({
        UnitStat = function(_unit, statIndex)
          if statIndex == 4 then
            return 0, 2200
          end
          return nil
        end,
        UnitClass = function()
          return "Paladin", "PALADIN"
        end,
        GetSpecialization = function()
          return 1
        end,
        GetSpecializationInfo = function(specIndex)
          Assert.Equal(specIndex, 1, "specialization info should be looked up from live specialization index")
          return 65
        end,
      })

      Assert.Equal(#holyRows, 1, "exact hybrid specialization should render one primary row")
      Assert.Equal(holyRows[1].label, "Int", "holy paladin should render the short intellect label")
      Assert.Equal(holyRows[1].value, 2200, "hybrid primary value should come from UnitStat")
    end)
  end)

  test("StatsBox uses fixed English short labels without locale variants", function()
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local StatsBox = addon.StatsBox
      local rows = StatsBox.CollectPlayerStats({
        locale = "deDE",
        UnitStat = function(_unit, statIndex)
          if statIndex == 1 then
            return 0, 2105
          end
          return nil
        end,
        UnitClass = function()
          return "Warrior", "WARRIOR"
        end,
      })
      Assert.Equal(rows[1].label, "Str", "deDE should still use the fixed short English strength label")

      rows = StatsBox.CollectPlayerStats({
        locale = "frFR",
        UnitStat = function(_unit, statIndex)
          if statIndex == 4 then
            return 0, 3300
          end
          return nil
        end,
        UnitClass = function()
          return "Mage", "MAGE"
        end,
      })
      Assert.Equal(rows[1].label, "Int", "unsupported locales should still use the fixed short English intellect label")
    end)
  end)

  test("StatsBox restores and saves its own position independently", function()
    local createFrameStub = BuildCreateFrameStub()
    local db = {
      statsBoxPosition = {
        point = "TOPRIGHT",
        relativePoint = "TOPRIGHT",
        x = -40,
        y = -90,
      },
    }

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local box = Assert.NotNil(addon.StatsBox.instance, "stats box should create an independent instance")
      box.frame:FireEvent("ADDON_LOADED", "isiLive")

      local point, _, relativePoint, x, y = box.frame:GetPoint()
      Assert.Equal(point, "TOPRIGHT", "stats box should restore its own saved anchor")
      Assert.Equal(relativePoint, "TOPRIGHT", "stats box should restore its own saved relative anchor")
      Assert.Equal(x, -40, "stats box should restore its own saved x offset")
      Assert.Equal(y, -90, "stats box should restore its own saved y offset")

      box.frame:ClearAllPoints()
      box.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 12, 34)
      local onDragStop = Assert.NotNil(box.frame._scripts.OnDragStop, "stats box should save position on drag stop")
      onDragStop(box.frame)

      Assert.Equal(db.statsBoxPosition.point, "BOTTOMLEFT", "drag stop should persist stats box point")
      Assert.Equal(db.statsBoxPosition.relativePoint, "BOTTOMLEFT", "drag stop should persist stats box relative point")
      Assert.Equal(db.statsBoxPosition.x, 12, "drag stop should persist stats box x")
      Assert.Equal(db.statsBoxPosition.y, 34, "drag stop should persist stats box y")
      Assert.Nil(db.position, "stats box dragging must not mutate main UI position")
    end)
  end)

  test("StatsBox clamps its movable frame to the screen", function()
    WithGlobals({
      UIParent = {},
      IsiLiveDB = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local box = Assert.NotNil(addon.StatsBox.instance, "stats box should create an independent instance")

      Assert.True(box.frame._clampedToScreen, "stats box must be clamped to the WoW screen")
      Assert.Equal(box.frame._clampRectInsets[1], 0, "stats box left clamp inset must stay at the edge")
      Assert.Equal(box.frame._clampRectInsets[2], 0, "stats box right clamp inset must stay at the edge")
      Assert.Equal(box.frame._clampRectInsets[3], 0, "stats box top clamp inset must stay at the edge")
      Assert.Equal(box.frame._clampRectInsets[4], 0, "stats box bottom clamp inset must stay at the edge")
    end)
  end)

  test("StatsBox lock blocks dragging without changing its saved position", function()
    local createFrameStub = BuildCreateFrameStub()
    local db = {
      statsBoxLocked = true,
      statsBoxPosition = {
        point = "TOPRIGHT",
        relativePoint = "TOPRIGHT",
        x = -40,
        y = -90,
      },
    }

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local box = Assert.NotNil(addon.StatsBox.instance, "stats box should create an instance")
      local onDragStart = Assert.NotNil(box.frame._scripts.OnDragStart, "stats box should define OnDragStart")
      local onDragStop = Assert.NotNil(box.frame._scripts.OnDragStop, "stats box should define OnDragStop")

      Assert.False(box.frame._movable, "locked stats box should mark the frame as not movable")
      onDragStart(box.frame)
      onDragStop(box.frame)

      Assert.Equal(box.frame._startMovingCalls, 0, "locked stats box must not start moving")
      Assert.Equal(db.statsBoxPosition.point, "TOPRIGHT", "locked drag stop must not rewrite saved position")
      Assert.Equal(db.statsBoxPosition.x, -40, "locked drag stop must preserve saved x")

      addon.StatsBox.SetLocked(false)
      Assert.False(db.statsBoxLocked, "unlock setter should persist to db")
      Assert.True(box.frame._movable, "unlocked stats box should become movable again")
      onDragStart(box.frame)
      Assert.Equal(box.frame._startMovingCalls, 1, "unlocked stats box should start moving")
    end)
  end)

  test("StatsBox applies enabled toggle and background opacity without a border", function()
    local createFrameStub = BuildCreateFrameStub()
    local db = {
      statsBoxBgAlpha = 0.35,
    }

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local box = Assert.NotNil(addon.StatsBox.instance, "stats box should create an instance")

      Assert.False(box.frame:IsShown(), "stats box should be hidden unless explicitly enabled")
      Assert.Equal(box.frame._backdrop.edgeFile, nil, "stats box backdrop must not draw a border")
      Assert.Equal(box.frame._backdropColor[4], 0.35, "stats box should apply its own background opacity")

      addon.StatsBox.SetEnabled(true)
      Assert.True(db.statsBoxEnabled, "enabled setter should persist true to db")
      Assert.True(box.frame:IsShown(), "enabled stats box should be shown")

      addon.StatsBox.SetBackgroundAlpha(0.6)
      Assert.Equal(db.statsBoxBgAlpha, 0.6, "background alpha setter should persist to db")
      Assert.Equal(box.frame._backdropColor[4], 0.6, "background alpha setter should repaint the frame")
    end)
  end)

  test("StatsBox renders subtle row tint backgrounds without a border", function()
    WithGlobals({
      UIParent = {},
      IsiLiveDB = { statsBoxEnabled = true, statsBoxBgAlpha = 0.4 },
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local box = addon.StatsBox.Create({
        parent = UIParent,
        collectStats = function()
          return {
            { key = "crit", label = "Crit", value = 923, percent = 25.07 },
            { key = "haste", label = "Haste", value = 512, percent = 16.10 },
          }
        end,
      })

      Assert.Equal(box.frame._backdrop.edgeFile, nil, "stats box must stay borderless")
      Assert.NotNil(box.lines[1].tint, "visible rows should get a tint texture")
      Assert.Equal(box.lines[1].tint._color[1], 1.00, "crit tint should use the fixed stat red channel")
      Assert.Equal(box.lines[1].tint._color[2], 0.25, "crit tint should use the fixed stat green channel")
      Assert.Equal(box.lines[1].tint._color[3], 0.25, "crit tint should use the fixed stat blue channel")
      Assert.Equal(box.lines[1].tint._color[4], 0.12, "row tint should stay subtle")
      Assert.Equal(box.lines[2].tint._color[3], 0.87, "haste tint should follow the fixed stat palette")
      Assert.False(box.lines[1].tint.hidden, "visible stat row tint should be shown")
      Assert.True(box.lines[3].tint.hidden, "unused stat row tint should stay hidden")
      Assert.Equal(box.lines[1].tint._points[1][1], "TOPLEFT", "row tint should start at the row left edge")
      Assert.Equal(box.lines[1].tint._points[2][1], "BOTTOMRIGHT", "row tint should end at the fitted right edge")
    end)
  end)

  test("StatsBox renders separator primary highlight and unlocked hover affordance", function()
    local db = {
      statsBoxEnabled = true,
      statsBoxBgAlpha = 0,
    }

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local box = addon.StatsBox.Create({
        parent = UIParent,
        collectStats = function()
          return {
            { key = "strength", label = "Str", value = 2052 },
            { key = "haste", label = "Haste", value = 528, percent = 16.48 },
          }
        end,
      })

      Assert.Nil(box.header, "stats box should not render a title/header row")
      Assert.False(box.separator.hidden, "value-percent separator should show when percent data is visible")
      Assert.Equal(box.separator._color[4], 0.18, "value-percent separator should stay subtle")
      Assert.Equal(box.lines[1].tint._color[4], 0.22, "primary stat tint should be stronger than secondary rows")
      Assert.Equal(box.lines[2].tint._color[4], 0.12, "secondary stat tint should stay subtle")

      local onEnter = Assert.NotNil(box.frame._scripts.OnEnter, "stats box should define hover enter affordance")
      local onLeave = Assert.NotNil(box.frame._scripts.OnLeave, "stats box should define hover leave affordance")
      onEnter(box.frame)
      Assert.Equal(box.frame._backdropColor[4], 0.18, "unlocked hover should raise transparent background opacity")
      onLeave(box.frame)
      Assert.Equal(box.frame._backdropColor[4], 0, "hover leave should restore configured background opacity")

      box.SetLocked(true)
      onEnter(box.frame)
      Assert.Equal(box.frame._backdropColor[4], 0, "locked stats box should not show drag hover affordance")
    end)
  end)

  test("StatsBox applies font size offset from settings", function()
    local createFrameStub = BuildCreateFrameStub()
    local db = {
      statsBoxFontSizeOffset = 2,
    }

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local box = Assert.NotNil(
        addon.StatsBox.Create({
          parent = UIParent,
          collectStats = function()
            return {
              { key = "strength", label = "Str", value = 2000 },
              { key = "haste", label = "Haste", value = 500, percent = 17.03 },
            }
          end,
        }),
        "stats box should create an instance"
      )
      local _, size = box.lines[1].label:GetFont()
      Assert.Equal(size, 16, "font size should apply default 14 plus saved offset")
      Assert.Equal(box.frame._width, 223, "positive font offset should keep the enlarged percent column stable")
      Assert.Equal(box.frame._height, 50, "positive font offset should enlarge the fitted stats box height")
      Assert.Equal(box.lines[1].label._width, 40, "positive font offset should enlarge the fitted label column")

      box.SetFontSizeOffset(-3)
      _, size = box.lines[1].value:GetFont()
      Assert.Equal(db.statsBoxFontSizeOffset, -3, "font offset setter should persist to db")
      Assert.Equal(size, 11, "font size should apply default 14 plus negative offset")
      Assert.Equal(box.frame._width, 150, "negative font offset should shrink while keeping the percent column stable")
      Assert.Equal(box.frame._height, 36, "negative font offset should shrink the fitted stats box height")
      Assert.Equal(box.lines[1].label._width, 25, "negative font offset should shrink the fitted label column")
    end)
  end)

  test("StatsBox applies high contrast text shadow", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      UIParent = {},
      IsiLiveDB = { statsBoxEnabled = true },
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local box = Assert.NotNil(addon.StatsBox.instance, "stats box should create an instance")
      local _, _, labelFlags = box.lines[1].label:GetFont()
      local _, _, valueFlags = box.lines[1].value:GetFont()

      Assert.Equal(labelFlags, "", "label text should avoid outline at compact sizes")
      Assert.Equal(valueFlags, "", "value text should avoid outline at compact sizes")
      Assert.Equal(box.lines[1].label._shadowColor[4], 0.9, "label text should use a high opacity dark shadow")
      Assert.Equal(box.lines[1].value._shadowOffset[1], 1, "value text should use a visible x shadow offset")
      Assert.Equal(box.lines[1].value._shadowOffset[2], -1, "value text should use a visible y shadow offset")
    end)
  end)

  test("StatsBox renders labels and values right-aligned", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      UIParent = {},
      IsiLiveDB = { statsBoxEnabled = true },
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local box = addon.StatsBox.Create({
        parent = UIParent,
        collectStats = function()
          return {
            {
              key = "strength",
              label = "Strength",
              value = 2105,
            },
            {
              key = "haste",
              label = "Haste",
              value = 551,
              percent = 17.03,
            },
          }
        end,
      })

      Assert.Equal(box.lines[1].label._text, "Strength", "label column should contain the stat label")
      Assert.Equal(box.lines[1].value._text, "2105", "value column should contain the stat value")
      Assert.Equal(box.frame._width, 216, "stats box background should fit the rendered text width")
      Assert.Equal(box.frame._height, 44, "stats box background should fit the rendered visible row count")
      Assert.Equal(box.lines[1].label._point[1], "TOPLEFT", "label column should keep its left-side column anchor")
      Assert.Equal(box.lines[1].label._justifyH, "RIGHT", "label text should align to the right edge of its column")
      Assert.Equal(box.lines[1].value._point[1], "TOPLEFT", "value column should anchor after the label column")
      Assert.Equal(box.lines[1].value._justifyH, "RIGHT", "value text should align right")
      Assert.Equal(box.lines[1].label._width, 56, "label column should fit the widest rendered label")
      Assert.Equal(box.lines[1].value._width, 60, "value column should keep enough stable room for larger stat values")
      Assert.Equal(box.lines[2].value._text, "551", "rating column should keep the numeric rating separate")
      Assert.Equal(box.lines[2].percent._text, "(17.03%)", "percent column should keep the percent text separate")
      Assert.Equal(box.lines[2].percent._point[1], "TOPLEFT", "percent column should anchor after the value column")
      Assert.Equal(box.lines[2].percent._width, 70, "percent column should reserve room for high percent values")
      Assert.True(
        box.lines[1].value._width >= box.lines[1].label._width,
        "value column should reserve enough room even beside a long label"
      )
    end)
  end)

  test("StatsBox keeps value column stable for four-digit stats", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      UIParent = {},
      IsiLiveDB = { statsBoxEnabled = true },
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local box = addon.StatsBox.Create({
        parent = UIParent,
        collectStats = function()
          return {
            { key = "strength", label = "Str", value = 2052 },
            { key = "crit", label = "Crit", value = 939, percent = 25.41 },
            { key = "haste", label = "Haste", value = 528, percent = 16.48 },
          }
        end,
      })

      Assert.Equal(box.lines[1].value._text, "2052", "four-digit primary stat should render in the value column")
      Assert.Equal(box.lines[1].value._width, 60, "value column should keep the compact minimum width")
      Assert.Equal(box.lines[2].value._width, 60, "three-digit rows should use the same stable value column")
      Assert.Equal(
        box.lines[2].percent._point[4],
        117,
        "percent column should not shift left after a three-digit value"
      )
      Assert.Equal(box.lines[3].percent._point[4], 117, "percent column should stay aligned across visible rows")
    end)
  end)

  test("StatsBox keeps stamina value column stable without percent text", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      UIParent = {},
      IsiLiveDB = { statsBoxEnabled = true },
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local box = addon.StatsBox.Create({
        parent = UIParent,
        collectStats = function()
          return {
            { key = "intellect", label = "Int", value = 2426 },
            { key = "stamina", label = "Stam", value = 22242 },
            { key = "crit", label = "Crit", value = 1044, percent = 29.70 },
          }
        end,
      })

      Assert.Equal(box.lines[2].label._text, "Stam", "stamina row should render with its short label")
      Assert.Equal(box.lines[2].value._text, "22242", "stamina should keep the full observed value text")
      Assert.Equal(
        box.lines[2].value._width,
        60,
        "stamina value column should reserve enough room without percent text"
      )
      Assert.Equal(box.lines[2].percent._text, "", "stamina row should not synthesize a percent text")
      Assert.Equal(box.lines[2].percent._shown, false, "stamina percent column should stay hidden")
      Assert.Equal(
        box.lines[3].percent._point[4],
        110,
        "later percent rows should stay aligned after the wider value column"
      )
    end)
  end)

  test("StatsBox keeps percent column stable for 999.99 percent", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      UIParent = {},
      IsiLiveDB = { statsBoxEnabled = true },
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local box = addon.StatsBox.Create({
        parent = UIParent,
        collectStats = function()
          return {
            { key = "crit", label = "Crit", value = 939, percent = 999.99 },
            { key = "haste", label = "Haste", value = 528, percent = 16.48 },
          }
        end,
      })

      Assert.Equal(box.lines[1].percent._text, "(999.99%)", "large percent text should render in one percent column")
      Assert.Equal(box.lines[1].percent._width, 70, "percent column should keep enough room for 999.99 percent")
      Assert.Equal(box.lines[2].percent._width, 70, "shorter percent rows should use the same stable percent column")
      Assert.Equal(box.lines[1].percent._point[4], 117, "large percent text should stay aligned after the value column")
      Assert.Equal(
        box.lines[2].percent._point[4],
        117,
        "shorter percent text should stay aligned with large percent rows"
      )
    end)
  end)

  test("StatsBox fits background to rendered text bounds", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      UIParent = {},
      IsiLiveDB = { statsBoxEnabled = true },
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local box = addon.StatsBox.Create({
        parent = UIParent,
        collectStats = function()
          return {
            { key = "strength", label = "Str", value = 1918 },
            { key = "crit", label = "Crit", value = 923, percent = 25.07 },
            { key = "haste", label = "Haste", value = 512, percent = 16.10 },
            { key = "mastery", label = "Mast", value = 911, percent = 50.05 },
            { key = "versatility", label = "Vers", value = 62, percent = 1.15 },
            { key = "leech", label = "Leech", value = 0, percent = 0.00 },
            { key = "speed", label = "Speed", value = 169, percent = 13.76 },
          }
        end,
      })

      Assert.Equal(box.frame._width, 195, "background width should preserve the compact minimum percent column")
      Assert.Equal(box.frame._height, 124, "background height should follow the seven visible stat rows")
      Assert.Equal(box.lines[1].label._point[4], 8, "label text should start at the fitted left padding")
      Assert.Equal(box.lines[1].value._point[4], 51, "value text should start after fitted labels and gap")
      Assert.Equal(
        box.lines[2].percent._point[4],
        117,
        "percent text should start after the stable value column and gap"
      )

      local sizeWrites = {}
      local originalSetSize = box.frame.SetSize
      box.frame.SetSize = function(self, width, height)
        sizeWrites[#sizeWrites + 1] = { width = width, height = height }
        return originalSetSize(self, width, height)
      end
      box.SetBackgroundAlpha(0.6)

      Assert.Equal(box.frame._width, 195, "settings refresh should keep the stable fitted text width")
      Assert.Equal(box.frame._height, 124, "settings refresh should keep the background fitted to rendered text height")
      Assert.Equal(#sizeWrites, 1, "settings refresh should apply only the fitted content size")
      Assert.Equal(sizeWrites[1].width, 195, "settings refresh must not write the wide default frame first")
    end)
  end)

  test("StatsBox ignores secret text width measurements", function()
    local secretWidth = {}
    local secretWidths = false
    local originalTonumber = tonumber
    local createFrameStub = BuildCreateFrameStub()
    local createFrame = function(...)
      local frame = createFrameStub(...)
      local originalCreateFontString = frame.CreateFontString
      frame.CreateFontString = function(self, ...)
        local fontString = originalCreateFontString(self, ...)
        local originalGetStringWidth = fontString.GetStringWidth
        fontString.GetStringWidth = function(widthSelf)
          if secretWidths then
            return secretWidth
          end
          return originalGetStringWidth(widthSelf)
        end
        return fontString
      end
      return frame
    end

    local function CollectSevenRows()
      return {
        { key = "strength", label = "Str", value = 1918 },
        { key = "crit", label = "Crit", value = 923, percent = 25.07 },
        { key = "haste", label = "Haste", value = 512, percent = 16.10 },
        { key = "mastery", label = "Mast", value = 911, percent = 50.05 },
        { key = "versatility", label = "Vers", value = 62, percent = 1.15 },
        { key = "leech", label = "Leech", value = 0, percent = 0.00 },
        { key = "speed", label = "Speed", value = 169, percent = 13.76 },
      }
    end

    WithGlobals({
      UIParent = {},
      IsiLiveDB = { statsBoxEnabled = true },
      CreateFrame = createFrame,
      issecretvalue = function(value)
        return value == secretWidth
      end,
      tonumber = function(value, base)
        if value == secretWidth then
          error("secret width must not be coerced")
        end
        return originalTonumber(value, base)
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local box = addon.StatsBox.Create({
        parent = UIParent,
        collectStats = CollectSevenRows,
      })

      Assert.Equal(box.frame._width, 195, "trusted text measurements should keep the stable percent column")
      secretWidths = true
      local ok, err = pcall(box.SetBackgroundAlpha, 0.6)
      Assert.True(ok, "secret text-width measurements must not throw: " .. tostring(err))
      Assert.Equal(box.frame._width, 195, "secret width refresh should keep the last trusted fitted width")

      local firstSecretBox = addon.StatsBox.Create({
        parent = UIParent,
        collectStats = CollectSevenRows,
      })
      Assert.Equal(firstSecretBox.frame._width, 195, "first secret-width refresh should use compact fallback columns")
      Assert.Equal(firstSecretBox.frame._height, 124, "secret-width fallback should still fit the visible row count")
    end)
  end)

  test("StatsBox reads haste percent from player spell haste", function()
    WithGlobals({
      UIParent = {},
      IsiLiveDB = { statsBoxEnabled = true },
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local rows = addon.StatsBox.CollectPlayerStats({
        GetCombatRating = function(ratingID)
          if ratingID == 101 then
            return 567
          end
          return nil
        end,
        UnitSpellHaste = function(unit)
          Assert.Equal(unit, "player", "haste percent should be read for the player unit")
          return 17.4
        end,
        CR_HASTE_MELEE = 101,
      })

      Assert.Equal(#rows, 1, "only haste should render in this focused scenario")
      Assert.Equal(rows[1].key, "haste", "row should be haste")
      Assert.Equal(rows[1].percent, 17.4, "haste percent should come from UnitSpellHaste('player')")
    end)
  end)

  test("StatsBox renders stamina durability and avoidance from direct APIs", function()
    WithGlobals({
      UIParent = {},
      IsiLiveDB = {
        statsBoxEnabled = true,
        statsBoxShowStamina = true,
        statsBoxShowDurability = true,
        statsBoxShowAvoidance = true,
      },
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local rows = addon.StatsBox.CollectPlayerStats({
        UnitStat = function(_unit, statIndex)
          if statIndex == 2 then
            return 0, 515
          end
          if statIndex == 3 then
            return 0, 6812
          end
          return nil
        end,
        UnitClass = function()
          return "Hunter", "HUNTER"
        end,
        GetInventoryItemDurability = function(slot)
          if slot == 1 then
            return 80, 100
          end
          if slot == 2 then
            return 20, 50
          end
          return nil, nil
        end,
        GetCombatRating = function(ratingID)
          if ratingID == 40 then
            return 412
          end
          return nil
        end,
        GetCombatRatingBonus = function(ratingID)
          if ratingID == 40 then
            return 5.18
          end
          return nil
        end,
        CR_AVOIDANCE = 40,
      })

      local found = {}
      for _, row in ipairs(rows) do
        found[row.key] = row
      end

      Assert.Equal(found.stamina.value, 6812, "stamina must come from UnitStat(3)")
      Assert.Equal(found.durability.valueText, "100", "durability must show the summed current durability")
      Assert.True(
        math.abs(found.durability.percent - ((100 / 150) * 100)) < 0.0001,
        "durability percent must come from summed durability"
      )
      Assert.Equal(found.avoidance.value, 412, "avoidance value must come from GetCombatRating(CR_AVOIDANCE)")
      Assert.Equal(found.avoidance.percent, 5.18, "avoidance percent must come from GetCombatRatingBonus(CR_AVOIDANCE)")
    end)
  end)

  test("StatsBox optional row toggles suppress configured rows", function()
    WithGlobals({
      UIParent = {},
      IsiLiveDB = {
        statsBoxEnabled = true,
        statsBoxShowLeech = false,
        statsBoxShowSpeed = false,
        statsBoxShowDurability = false,
        statsBoxShowStamina = false,
        statsBoxShowAvoidance = false,
      },
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local rows = addon.StatsBox.CollectPlayerStats({
        UnitStat = function(_unit, statIndex)
          if statIndex == 3 then
            return 0, 6812
          end
          return nil
        end,
        GetCombatRating = function(_ratingID)
          return 123
        end,
        GetCombatRatingBonus = function(_ratingID)
          return 7.5
        end,
        GetInventoryItemDurability = function()
          return 10, 10
        end,
        CR_LIFESTEAL = 1,
        CR_SPEED = 2,
        CR_AVOIDANCE = 3,
      })

      for _, row in ipairs(rows) do
        Assert.True(row.key ~= "stamina", "disabled stamina row must stay hidden")
        Assert.True(row.key ~= "leech", "disabled leech row must stay hidden")
        Assert.True(row.key ~= "speed", "disabled speed row must stay hidden")
        Assert.True(row.key ~= "durability", "disabled durability row must stay hidden")
        Assert.True(row.key ~= "avoidance", "disabled avoidance row must stay hidden")
      end
    end)
  end)

  test("StatsBox optional row defaults show leech and speed only", function()
    WithGlobals({
      UIParent = {},
      IsiLiveDB = {
        statsBoxEnabled = true,
      },
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local rows = addon.StatsBox.CollectPlayerStats({
        UnitStat = function(_unit, statIndex)
          if statIndex == 3 then
            return 0, 6812
          end
          return nil
        end,
        GetCombatRating = function(ratingID)
          return ratingID * 10
        end,
        GetCombatRatingBonus = function(ratingID)
          return ratingID
        end,
        GetInventoryItemDurability = function(slot)
          if slot == 1 then
            return 10, 20
          end
          return nil, nil
        end,
        CR_LIFESTEAL = 1,
        CR_SPEED = 2,
        CR_AVOIDANCE = 3,
      })

      local found = {}
      for _, row in ipairs(rows) do
        found[row.key] = row
      end

      Assert.NotNil(found.leech, "leech must be enabled by default")
      Assert.NotNil(found.speed, "speed must be enabled by default")
      Assert.Nil(found.durability, "durability must be disabled by default")
      Assert.Nil(found.stamina, "stamina must be disabled by default")
      Assert.Nil(found.avoidance, "avoidance must be disabled by default")
    end)
  end)

  test("StatsBox display mode renders values only or percentages only", function()
    local createFrameStub = BuildCreateFrameStub()
    local db = {
      statsBoxEnabled = true,
      statsBoxDisplayMode = "percent",
    }

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local box = addon.StatsBox.Create({
        parent = UIParent,
        collectStats = function()
          return {
            { key = "strength", label = "Str", value = 4210 },
            { key = "crit", label = "Crit", value = 1824, percent = 24.85 },
          }
        end,
      })

      Assert.Equal(box.lines[1].label._text, "Crit", "percent-only mode must skip rows without percent")
      Assert.Equal(box.lines[1].value._text, "", "percent-only mode must hide the value text")
      Assert.Equal(box.lines[1].percent._text, "(24.85%)", "percent-only mode must keep percent text visible")

      db.statsBoxDisplayMode = "value"
      box.ApplySettings()
      Assert.Equal(box.lines[1].label._text, "Str", "value-only mode should render rows with values")
      Assert.Equal(box.lines[1].value._text, "4210", "value-only mode must keep value text visible")
      Assert.Equal(box.lines[1].percent._text, "", "value-only mode must hide percent text")
    end)
  end)

  test("StatsBox applies Blizzard-like fixed stat colors", function()
    WithGlobals({
      UIParent = {},
      IsiLiveDB = { statsBoxEnabled = true },
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local box = addon.StatsBox.Create({
        parent = UIParent,
        collectStats = function()
          return {
            { key = "strength", label = "Strength", value = 2105 },
            { key = "crit", label = "Crit", value = 926 },
            { key = "haste", label = "Haste", value = 551, percent = 17.03 },
            { key = "mastery", label = "Mastery", value = 921, percent = 50.44 },
            { key = "versatility", label = "Vers", value = 62, percent = 1.15 },
            { key = "leech", label = "Leech", value = 0, percent = 0 },
            { key = "speed", label = "Speed", value = 169, percent = 13.76 },
          }
        end,
      })

      local expected = {
        { 1.00, 0.82, 0.00, 1 },
        { 1.00, 0.25, 0.25, 1 },
        { 0.00, 0.44, 0.87, 1 },
        { 0.10, 1.00, 0.10, 1 },
        { 0.64, 0.21, 0.93, 1 },
        { 1.00, 0.50, 0.00, 1 },
        { 1.00, 0.82, 0.00, 1 },
      }

      for index, color in ipairs(expected) do
        local actual = box.lines[index].label._textColor
        Assert.Equal(actual[1], color[1], "stat label red channel should match the fixed palette")
        Assert.Equal(actual[2], color[2], "stat label green channel should match the fixed palette")
        Assert.Equal(actual[3], color[3], "stat label blue channel should match the fixed palette")
        Assert.Equal(actual[4], color[4], "stat label alpha channel should match the fixed palette")
        Assert.Equal(
          box.lines[index].value._textColor[1],
          color[1],
          "value column should use the same fixed stat color"
        )
        Assert.Equal(
          box.lines[index].percent._textColor[1],
          color[1],
          "percent column should use the same fixed stat color"
        )
      end
    end)
  end)

  test("StatsBox formats secret API values without arithmetic", function()
    local secretPrimary = 2105
    local secretRating = 926
    local secretPercent = 25.48
    WithGlobals({
      UIParent = {},
      IsiLiveDB = { statsBoxEnabled = true },
      CreateFrame = BuildCreateFrameStub(),
      issecretvalue = function(value)
        return value == secretPrimary or value == secretRating or value == secretPercent
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      local ok, rows = pcall(addon.StatsBox.CollectPlayerStats, {
        UnitClass = function()
          return "Warrior", "WARRIOR"
        end,
        UnitStat = function(_unit, statIndex)
          if statIndex ~= 1 then
            return nil
          end
          return nil, secretPrimary
        end,
        GetCombatRating = function(ratingID)
          if ratingID == 100 then
            return secretRating
          end
          return nil
        end,
        GetCritChance = function()
          return secretPercent
        end,
        CR_CRIT_MELEE = 100,
      })

      Assert.True(ok, "secret stat API values must not throw from numeric conversion or rounding")
      Assert.Equal(#rows, 2, "directly observed secret stat API values should still render")

      local box = addon.StatsBox.Create({
        parent = UIParent,
        collectStats = function()
          return rows
        end,
      })

      Assert.Equal(box.lines[1].value._text, "2105", "secret primary stat should be formatted directly for SetText")
      Assert.Equal(box.lines[2].value._text, "926", "secret combat rating should be formatted directly for SetText")
      Assert.Equal(box.lines[2].percent._text, "(25.48%)", "secret percent should be formatted directly for SetText")
    end)
  end)

  test("StatsBox uses explicit demo rows only while demo data is set", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
      addon.StatsBox.SetDemoData({
        { key = "strength", label = "Str", value = 4210 },
        { key = "crit", label = "Crit", value = 1824, percent = 24.85 },
      })

      local rows = addon.StatsBox.CollectPlayerStats({})
      Assert.Equal(#rows, 2, "demo stats must replace live API collection")
      Assert.Equal(rows[1].label, "Str", "demo primary stat label must be carried")
      Assert.Equal(rows[2].percent, 24.85, "demo percent must be carried")

      addon.StatsBox.ClearDemoData()
      local liveRows = addon.StatsBox.CollectPlayerStats({})
      Assert.Equal(#liveRows, 0, "clearing demo data must restore live API collection")
    end)
  end)
end
