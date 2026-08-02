---@diagnostic disable: undefined-global

-- Branch-coverage scenarios for ui/isiLive_roster_panel_kill_row.lua.
-- The active-data update path (RI.UpdateKillTrackRow with
-- KillTrack.GetData() returning data.active = true) is fully
-- uncovered. This file drives every percentage band, the in-combat
-- pull-percent overlay, and the pull-width clamp by feeding a
-- KillTrack stub plus a row-shaped table directly into UpdateKillTrackRow.

local function NewBarStub(getWidth)
  local bar = {
    _shown = false,
    _width = 0,
    _color = nil,
  }
  function bar.SetWidth(self, w)
    self._width = w
  end
  function bar.SetVertexColor(self, ...)
    self._color = { ... }
  end
  function bar.SetTexture(self, _path) end
  function bar.SetPoint(self, ...) end
  function bar.Show(self)
    self._shown = true
  end
  function bar.Hide(self)
    self._shown = false
  end
  function bar.GetWidth(self)
    return getWidth and getWidth(self) or self._width
  end
  return bar
end

local function NewFontStringStub()
  local fs = {
    _text = "",
    _color = nil,
    _fontPath = "Fonts\\FRIZQT__.TTF",
    _fontSize = 12,
    _fontFlags = "",
  }
  function fs.SetText(self, text)
    self._text = text
  end
  function fs.GetFont(self)
    return self._fontPath, self._fontSize, self._fontFlags
  end
  function fs.SetFont(self, path, size, flags)
    self._fontPath = path
    self._fontSize = size
    self._fontFlags = flags
  end
  function fs.SetTextColor(self, r, g, b)
    self._color = { r, g, b }
  end
  function fs.SetJustifyH(self, justifyH)
    self._justifyH = justifyH
  end
  return fs
end

local function NewCreateFrameRecorder()
  local createdFrames = {}
  local createdFontStrings = {}

  local function NewFontString(parent)
    local fs = {
      _parent = parent,
      _points = {},
      _drawLayer = nil,
      _alpha = nil,
    }
    function fs.SetPoint(self, ...)
      table.insert(self._points, { ... })
    end
    function fs.SetWidth(self, width)
      self._width = width
    end
    function fs.SetJustifyH(self, justifyH)
      self._justifyH = justifyH
    end
    function fs.SetJustifyV(self, justifyV)
      self._justifyV = justifyV
    end
    function fs.SetDrawLayer(self, layer, sublayer)
      self._drawLayer = { layer, sublayer }
    end
    function fs.SetAlpha(self, alpha)
      self._alpha = alpha
    end
    function fs.SetText(self, text)
      self._text = text
    end
    function fs.SetTextColor() end
    function fs.GetFont()
      return "font", 10, ""
    end
    function fs.SetFont(self, path, size, flags)
      self._font = { path, size, flags }
    end
    table.insert(createdFontStrings, fs)
    return fs
  end

  local function NewTexture()
    local tex = {
      _points = {},
      _shown = true,
    }
    function tex.SetAllPoints(self, owner)
      self._allPoints = owner or true
    end
    function tex.SetTexture() end
    function tex.SetVertexColor(self, ...)
      self._color = { ... }
    end
    function tex.SetPoint(self, ...)
      table.insert(self._points, { ... })
    end
    function tex.SetWidth(self, width)
      self._width = width
    end
    function tex.SetHeight(self, height)
      self._height = height
    end
    function tex.Hide(self)
      self._shown = false
    end
    function tex.Show(self)
      self._shown = true
    end
    return tex
  end

  local function NewFrame(parent)
    local frame = {
      _parent = parent,
      _points = {},
      _shown = true,
      _frameLevel = 1,
    }
    function frame.SetHeight(self, height)
      self._height = height
    end
    function frame.SetPoint(self, ...)
      table.insert(self._points, { ... })
    end
    function frame.SetFrameLevel(self, level)
      self._frameLevel = level
    end
    function frame.GetFrameLevel(self)
      return self._frameLevel
    end
    function frame.CreateTexture()
      return NewTexture()
    end
    function frame.CreateFontString(self)
      return NewFontString(self)
    end
    function frame.Hide(self)
      self._shown = false
    end
    function frame.Show(self)
      self._shown = true
    end
    table.insert(createdFrames, frame)
    return frame
  end

  return {
    createdFrames = createdFrames,
    createdFontStrings = createdFontStrings,
    createFrame = function(_frameType, _name, parent)
      return NewFrame(parent)
    end,
  }
end

local function NewRow(barContainerWidth)
  local barContainer = {
    _shown = true,
    GetWidth = function()
      return barContainerWidth or 100
    end,
    Show = function(self)
      self._shown = true
    end,
    Hide = function(self)
      self._shown = false
    end,
  }
  return {
    killTrackBarContainer = barContainer,
    killTrackBarBg = NewBarStub(),
    killTrackBarFill = NewBarStub(),
    killTrackBarPull = NewBarStub(),
    killTrackTargetText = NewFontStringStub(),
    killTrackTargetLevelText = NewFontStringStub(),
    killTrackActiveDungeonBackdrop = NewBarStub(),
    killTrackActiveDungeonText = NewFontStringStub(),
    killTrackPctText = NewFontStringStub(),
    killTrackPullText = NewFontStringStub(),
  }
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  local function LoadKillRow(killTrackData)
    local addon = LoadAddonModules({
      "isiLive_ui_common.lua",
      "isiLive_roster_panel_helpers.lua",
      "isiLive_roster_panel_kill_row.lua",
    })
    addon.KillTrack = {
      GetData = function()
        return killTrackData
      end,
    }
    return addon
  end

  test("CreateKillTrackRow anchors active dungeon text to the full row overlay", function()
    local recorder = NewCreateFrameRecorder()
    WithGlobals({
      CreateFrame = recorder.createFrame,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel_helpers.lua", "isiLive_roster_panel_kill_row.lua" })
      local mainFrame = recorder.createFrame("Frame", nil, nil)
      local row = addon._RosterInternal.CreateKillTrackRow(mainFrame)
      local overlay = row.killTrackActiveDungeonOverlay
      local backdrop = row.killTrackActiveDungeonBackdrop
      local activeText = row.killTrackActiveDungeonText

      Assert.NotNil(overlay, "active dungeon context overlay frame must be created")
      Assert.NotNil(backdrop, "active dungeon context contrast backdrop must be created")
      Assert.NotNil(activeText, "active dungeon context fontstring must be created")
      Assert.True(
        overlay._frameLevel > row.killTrackBarContainer._frameLevel,
        "active dungeon context overlay must be above the bar container frame"
      )
      Assert.True(
        overlay._points[1][2] ~= row.killTrackBarContainer,
        "active dungeon context overlay must not be anchored to the 8px bar container"
      )
      Assert.Equal(activeText._points[1][1], "LEFT", "active dungeon context keeps a left anchor")
      Assert.Equal(activeText._points[1][2], overlay, "active dungeon context anchors inside the overlay frame")
      Assert.Equal(backdrop._points[1][2], overlay, "active dungeon backdrop anchors inside the overlay frame")
      Assert.Equal(backdrop._width, 146, "active dungeon backdrop reserves a stable contrast label width")
      Assert.Equal(backdrop._color[4], 0.5, "active dungeon backdrop must subtly darken the bar below the label")
      Assert.True(backdrop._shown == false, "active dungeon backdrop starts hidden until text is available")
      Assert.Equal(activeText._justifyV, "MIDDLE", "active dungeon context must be vertically centered in the row")
      Assert.Equal(activeText._drawLayer[1], "OVERLAY", "active dungeon context must render above bar textures")
      Assert.Equal(activeText._drawLayer[2], 7, "active dungeon context uses a high overlay sublayer")
      Assert.Equal(activeText._alpha, 0.92, "active dungeon context starts with the configured default alpha")
      Assert.Equal(row._points[2][1], "BOTTOMRIGHT", "kill tracker row must expose an explicit right anchor")
      Assert.Equal(row._points[2][2], -6, "kill tracker row must end at the shared M+ right edge")
    end)
  end)

  -- Early return ---------------------------------------------------------------

  test("UpdateKillTrackRow returns silently for nil row", function()
    WithGlobals({}, function()
      local addon = LoadKillRow(nil)
      addon._RosterInternal.UpdateKillTrackRow(nil)
    end)
  end)

  -- Inactive data: reset path (already partly covered, asserted explicitly) ----

  test("UpdateKillTrackRow hides bars and resets pct text when data is missing", function()
    WithGlobals({}, function()
      local addon = LoadKillRow(nil) -- KillTrack returns nil data
      local row = NewRow()
      row.killTrackBarFill._shown = true
      row.killTrackBarPull._shown = true
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.True(row.killTrackBarFill._shown == false, "fill bar must hide")
      Assert.True(row.killTrackBarPull._shown == false, "pull bar must hide")
      Assert.Equal(row.killTrackTargetText._text, "", "target text must clear")
      Assert.Equal(row.killTrackTargetLevelText._text, "", "target level text must clear")
      Assert.Equal(row.killTrackActiveDungeonText._text, "", "active dungeon context must clear")
      Assert.Equal(row.killTrackPctText._text, "--,--", "pct text must reset")
      Assert.Equal(row.killTrackPullText._text, "", "pull text must clear")
    end)
  end)

  test("UpdateKillTrackRow resets bars when data.active is false", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = false, percent = 50 })
      local row = NewRow()
      row.killTrackBarFill._shown = true
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.True(row.killTrackBarFill._shown == false, "inactive must hide fill bar")
      Assert.Equal(row.killTrackPctText._text, "--,--", "inactive must reset pct text")
    end)
  end)

  test(
    "UpdateKillTrackRow renders verified target key as right-aligned combined text before challenge start",
    function()
      WithGlobals({}, function()
        local addon = LoadKillRow({ active = false, percent = 0 })
        local row = NewRow()
        row.killTrackBarFill._shown = true
        row.killTrackBarPull._shown = true
        addon._RosterInternal.UpdateKillTrackRow(row, {
          getTargetDungeonInfo = function()
            return {
              name = "  Windlaeufer Turm  ",
              level = 14,
            }
          end,
          isInChallengeMode = function()
            return false
          end,
        })
        Assert.True(row.killTrackBarFill._shown == false, "pre-key target must hide percent fill")
        Assert.True(row.killTrackBarPull._shown == false, "pre-key target must hide pull overlay")
        Assert.True(row.killTrackBarContainer._shown == false, "pre-key target must hide percent bar background")
        Assert.True(row.killTrackBarBg._shown == false, "pre-key target must hide static bar background")
        Assert.Equal(row.killTrackTargetText._text, "Windlaeufer Turm", "pre-key target must show the dungeon name")
        Assert.Equal(row.killTrackTargetLevelText._text, "+14", "pre-key target must show the colored key level")
        Assert.Equal(
          row.killTrackActiveDungeonText._text,
          "",
          "pre-key target must not duplicate active dungeon context"
        )
        Assert.Equal(row.killTrackTargetText._color[1], 1.0, "pre-key dungeon text must be gold-tinted")
        Assert.Equal(row.killTrackTargetLevelText._color[3], 1.0, "pre-key level text must be blue-tinted")
        Assert.Equal(row.killTrackTargetText._justifyH, "RIGHT", "pre-key target must be right-aligned")
        Assert.Equal(row.killTrackTargetLevelText._justifyH, "RIGHT", "pre-key level must be right-aligned")
        Assert.Equal(row.killTrackPctText._text, "", "pre-key target must not split the level into the percent field")
        Assert.Equal(row.killTrackPullText._text, "", "pre-key target must clear pull text")
      end)
    end
  )

  test("UpdateKillTrackRow renders literal pipe characters in verified pre-key dungeon names", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = false, percent = 0 })
      local row = NewRow()
      addon._RosterInternal.UpdateKillTrackRow(row, {
        getTargetDungeonInfo = function()
          return {
            name = "A|B",
            level = 2,
          }
        end,
        isInChallengeMode = function()
          return false
        end,
      })
      Assert.Equal(row.killTrackTargetText._text, "A|B", "pre-key target must not inject inline color markup")
      Assert.Equal(row.killTrackTargetLevelText._text, "+2", "pre-key target level must be rendered separately")
    end)
  end)

  test("UpdateKillTrackRow renders verified pre-key dungeon when level is unresolved", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = false, percent = 0 })
      local row = NewRow()
      addon._RosterInternal.UpdateKillTrackRow(row, {
        getTargetDungeonInfo = function()
          return {
            name = "  Nexuspunkt Xenas  ",
            level = nil,
          }
        end,
        isInChallengeMode = function()
          return false
        end,
      })
      Assert.True(row.killTrackBarContainer._shown == false, "pre-key dungeon must hide percent bar even without level")
      Assert.Equal(row.killTrackTargetText._text, "Nexuspunkt Xenas", "verified dungeon name must render")
      Assert.Equal(row.killTrackTargetLevelText._text, "", "unresolved level must stay hidden")
      Assert.Equal(row.killTrackPctText._text, "", "pre-key dungeon must clear percent placeholder")
      Assert.Equal(row.killTrackTargetText._justifyH, "RIGHT", "pre-key dungeon must stay right-aligned")
    end)
  end)

  test("UpdateKillTrackRow uses Cyrillic-capable font for verified Cyrillic dungeon names", function()
    WithGlobals({
      IsiLiveDB = { locale = "enUS" },
    }, function()
      local addon = LoadKillRow({ active = false, percent = 0 })
      local row = NewRow()
      addon._RosterInternal.UpdateKillTrackRow(row, {
        getTargetDungeonInfo = function()
          return {
            name = "\208\156\208\176\208\185\209\129\208\176\209\128"
              .. "\208\176\208\186\208\176\208\178\208\181\209\128"
              .. "\208\189\208\181\208\189",
          }
        end,
        isInChallengeMode = function()
          return false
        end,
      })

      Assert.Equal(
        row.killTrackTargetText._fontPath,
        "Fonts\\ARIALN.TTF",
        "verified Cyrillic dungeon names must switch the killtracker font"
      )
    end)
  end)

  test("UpdateKillTrackRow drops raw level text when no numeric level resolves", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = false, percent = 0 })
      local row = NewRow()
      addon._RosterInternal.UpdateKillTrackRow(row, {
        getTargetDungeonInfo = function()
          return {
            name = "Windlaeuferturm",
            levelText = "|Kk584|k",
          }
        end,
        isInChallengeMode = function()
          return false
        end,
      })
      Assert.Equal(row.killTrackTargetText._text, "Windlaeuferturm", "verified dungeon name must render")
      Assert.Equal(
        row.killTrackTargetLevelText._text,
        "",
        "raw level text (Blizzard markup or LFG title scraps) must not leak into the pre-key level cell"
      )
    end)
  end)

  test("UpdateKillTrackRow suppresses target key after challenge start until percent data is active", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = false, percent = 0 })
      local row = NewRow()
      addon._RosterInternal.UpdateKillTrackRow(row, {
        getTargetDungeonInfo = function()
          return {
            name = "Windlaeufer Turm",
            level = 14,
          }
        end,
        isInChallengeMode = function()
          return true
        end,
      })
      Assert.Equal(row.killTrackTargetText._text, "", "key-start boundary must clear pre-key target text")
      Assert.Equal(row.killTrackTargetLevelText._text, "", "key-start boundary must clear pre-key level text")
      Assert.Equal(row.killTrackActiveDungeonText._text, "", "inactive post-start row must not show active context")
      Assert.Equal(row.killTrackPctText._text, "--,--", "inactive post-start row must use the percent placeholder")
      Assert.True(row.killTrackBarContainer._shown == true, "post-start placeholder must restore the percent bar")
    end)
  end)

  test("UpdateKillTrackRow restores percent bar after pre-key target display", function()
    WithGlobals({}, function()
      local killTrackData = { active = false, percent = 0 }
      local addon = LoadKillRow(killTrackData)
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row, {
        getTargetDungeonInfo = function()
          return {
            name = "Windlaeufer Turm",
            level = 14,
          }
        end,
        isInChallengeMode = function()
          return false
        end,
      })
      Assert.True(row.killTrackBarContainer._shown == false, "pre-key target must hide the bar")

      killTrackData.active = true
      killTrackData.percent = 42
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.True(row.killTrackBarContainer._shown == true, "active percent data must restore the bar")
      Assert.True(row.killTrackBarBg._shown == true, "active percent data must restore the bar background")
      Assert.True(row.killTrackBarFill._shown == true, "active percent data must show the percent fill")
      Assert.Equal(row.killTrackTargetText._text, "", "active percent data must clear the pre-key target")
      Assert.Equal(row.killTrackTargetLevelText._text, "", "active percent data must clear the pre-key level")
    end)
  end)

  test("UpdateKillTrackRow keeps dungeon context visible while active percent data is visible", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = true, percent = 42 })
      addon.MplusTimer = {
        GetTimerData = function()
          return { running = true, keyLevel = 16 }
        end,
      }
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row, {
        getTargetDungeonInfo = function()
          return {
            name = "  Nexuspunkt Xenas  ",
            level = 14,
          }
        end,
        isInChallengeMode = function()
          return true
        end,
      })
      Assert.True(row.killTrackBarContainer._shown == true, "active percent bar must stay visible")
      Assert.Equal(row.killTrackTargetText._text, "", "active percent view must clear pre-key dungeon text")
      Assert.Equal(row.killTrackTargetLevelText._text, "", "active percent view must clear pre-key level text")
      Assert.Equal(
        row.killTrackActiveDungeonText._text,
        "Nexuspunkt Xenas +16",
        "active percent view must append the started key level from MplusTimer"
      )
      Assert.Equal(
        row.killTrackActiveDungeonText._justifyH,
        "LEFT",
        "active dungeon context must be left-aligned on the progress row"
      )
      Assert.Equal(
        row.killTrackActiveDungeonText._color[1],
        1.0,
        "active dungeon context must use bright outline text for bar legibility"
      )
      Assert.True(row.killTrackActiveDungeonBackdrop._shown == true, "active dungeon backdrop must show behind text")
      Assert.Equal(row.killTrackPctText._text, "42,00%", "active percent text must stay primary")
    end)
  end)

  test("UpdateKillTrackRow appends death count behind active dungeon name", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = true, percent = 42 })
      addon.MplusTimer = {
        GetTimerData = function()
          return { running = true, keyLevel = 16 }
        end,
      }
      addon.DeathWatch = {
        GetAllDeathSummaries = function()
          return {
            { name = "Tankadin", count = 1 },
            { name = "Magey", count = 2 },
          }
        end,
      }
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row, {
        getTargetDungeonInfo = function()
          return {
            name = "Nexuspunkt Xenas",
          }
        end,
        isInChallengeMode = function()
          return true
        end,
      })

      Assert.True(
        row.killTrackActiveDungeonText._text:find("Nexuspunkt Xenas +16", 1, true) == 1,
        "active dungeon name and started key level must stay first"
      )
      Assert.True(
        row.killTrackActiveDungeonText._text:find("UI%-RaidTargetingIcon_8", 1, false) ~= nil,
        "active dungeon name must append the skull marker"
      )
      Assert.True(
        row.killTrackActiveDungeonText._text:find("|cffff60603|r", 1, true) ~= nil,
        "active dungeon name must append the summed death count"
      )
    end)
  end)

  test("UpdateKillTrackRow omits active key level when MplusTimer has no started level", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = true, percent = 42 })
      addon.MplusTimer = {
        GetTimerData = function()
          return { running = true, keyLevel = 0 }
        end,
      }
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row, {
        getTargetDungeonInfo = function()
          return {
            name = "  Nexuspunkt Xenas  ",
            level = 14,
          }
        end,
        isInChallengeMode = function()
          return true
        end,
      })
      Assert.Equal(
        row.killTrackActiveDungeonText._text,
        "Nexuspunkt Xenas",
        "target-dungeon level must not be used as an active-key fallback"
      )
    end)
  end)

  -- Active path: green band (pct < 80) -----------------------------------------

  test("UpdateKillTrackRow renders green fill when percent < 80", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = true, percent = 50 })
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      local fill = row.killTrackBarFill
      Assert.True(fill._shown == true, "fill must show for active data")
      Assert.Equal(fill._width, 100, "fill width must be 50% of 200")
      Assert.Equal(fill._color[1], 0.2, "green r")
      Assert.Equal(fill._color[2], 0.75, "green g")
      Assert.Equal(fill._color[3], 0.35, "green b")
      Assert.Equal(row.killTrackPctText._text, "50,00%", "pct text must be 50,00%% with comma")
      Assert.Equal(row.killTrackPctText._color[1], 0.2, "pct text color matches band")
    end)
  end)

  -- Active path: yellow band (80 <= pct < 95) ---------------------------------

  test("UpdateKillTrackRow renders yellow fill when 80 <= percent < 95", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = true, percent = 90 })
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackBarFill._color[1], 0.9, "yellow r")
      Assert.Equal(row.killTrackBarFill._color[2], 0.75, "yellow g")
      Assert.Equal(row.killTrackBarFill._color[3], 0.1, "yellow b")
    end)
  end)

  -- Active path: red band (pct >= 95) ------------------------------------------

  test("UpdateKillTrackRow renders red fill when percent >= 95", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = true, percent = 99 })
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackBarFill._color[1], 0.9, "red r")
      Assert.Equal(row.killTrackBarFill._color[2], 0.3, "red g")
      Assert.Equal(row.killTrackBarFill._color[3], 0.15, "red b")
    end)
  end)

  -- Active path: percent clamped to 100 ----------------------------------------

  test("UpdateKillTrackRow clamps percent to [0, 100]", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = true, percent = 130 })
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackBarFill._width, 200, "clamped percent must yield full width")
      Assert.Equal(row.killTrackPctText._text, "100,00%", "pct text must be clamped to 100")
    end)
  end)

  -- Active path: zero-width fill bar hides instead of showing ------------------

  test("UpdateKillTrackRow hides fill bar when computed width rounds to 0", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = true, percent = 0 })
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.True(row.killTrackBarFill._shown == false, "0%% percent must hide fill bar")
    end)
  end)

  -- Active path: in-combat pull overlay ----------------------------------------

  test("UpdateKillTrackRow shows pull overlay during combat with pullPercent > 0", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = true, percent = 50, inCombat = true, pullPercent = 20 })
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.True(row.killTrackBarPull._shown == true, "pull bar must show in combat")
      Assert.Equal(row.killTrackBarPull._width, 40, "pull width = 20% of 200 = 40")
      Assert.Equal(row.killTrackPullText._text, "+20,00%", "pull text must show pull percent with plus prefix")
      Assert.Equal(row.killTrackPullText._color[1], 0.6, "pull text color r")
    end)
  end)

  test("UpdateKillTrackRow clamps pull width when fill + pull would exceed bar width", function()
    WithGlobals({}, function()
      -- 200 wide, fill = 80% (160), pull = 30% (60). 160 + 60 = 220 > 200,
      -- so pull width must be clamped to (200 - 160) = 40.
      local addon = LoadKillRow({ active = true, percent = 80, inCombat = true, pullPercent = 30 })
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackBarPull._width, 40, "pull width must be clamped to remaining space")
    end)
  end)

  test("UpdateKillTrackRow hides pull overlay outside of combat", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = true, percent = 50, inCombat = false, pullPercent = 20 })
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.True(row.killTrackBarPull._shown == false, "no combat must hide pull bar")
      Assert.Equal(row.killTrackPullText._text, "", "no combat must clear pull text")
    end)
  end)

  test("UpdateKillTrackRow hides pull overlay when pullPercent is zero", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = true, percent = 50, inCombat = true, pullPercent = 0 })
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.True(row.killTrackBarPull._shown == false, "zero pull must hide pull bar")
    end)
  end)
end
