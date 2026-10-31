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
  function bar.GetAlpha(self)
    return self._alpha or 1
  end
  function bar.SetAlpha(self, alpha)
    self._alpha = alpha
  end
  -- Records decorative transitions started through UICommon.PlayAlphaTransition.
  function bar.CreateAnimationGroup(self)
    local group = { plays = 0, _playing = false }
    function group.CreateAnimation()
      return {
        SetFromAlpha = function() end,
        SetToAlpha = function() end,
        SetDuration = function() end,
        SetSmoothing = function() end,
      }
    end
    function group.SetScript() end
    function group.IsPlaying(g)
      return g._playing
    end
    function group.Play(g)
      g.plays = g.plays + 1
      g._playing = true
    end
    function group.Stop(g)
      g._playing = false
    end
    self._animGroup = group
    return group
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

local function NewPulseGroupStub()
  local group = { plays = 0, stops = 0, _playing = false }
  function group.SetLooping(g, mode)
    g._looping = mode
  end
  function group.CreateAnimation(g)
    local anim = {}
    function anim.SetFromAlpha(a, v)
      a._from = v
    end
    function anim.SetToAlpha(a, v)
      a._to = v
    end
    function anim.SetDuration(a, v)
      a._duration = v
    end
    function anim.SetSmoothing() end
    function anim.SetOffset(a, x, y)
      a._offset = { x, y }
    end
    g._anim = anim
    return anim
  end
  function group.IsPlaying(g)
    return g._playing
  end
  function group.Play(g)
    g.plays = g.plays + 1
    g._playing = true
  end
  function group.Stop(g)
    g.stops = g.stops + 1
    g._playing = false
  end
  return group
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
    function fs.SetTextColor(self, ...)
      self._textColor = { ... }
    end
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
    function frame.SetAlpha(self, alpha)
      self._alpha = alpha
    end
    function frame.SetWidth(self, width)
      self._width = width
    end
    function frame.GetWidth(self)
      return self._width or 0
    end
    function frame.SetScript(self, name, fn)
      self._scripts = self._scripts or {}
      self._scripts[name] = fn
    end
    function frame.CreateAnimationGroup(self)
      self._animGroup = NewPulseGroupStub()
      return self._animGroup
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
    killTrackTargetPulse = NewBarStub(),
    killTrackTargetPulseGroup = NewPulseGroupStub(),
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

  -- Row-shaped stub for the key end banner; `row.visible` answers IsVisible.
  local function NewRunEndRow()
    local banner = NewBarStub(function()
      return 200
    end)
    banner._scripts = {}
    function banner.SetScript(self, name, fn)
      self._scripts[name] = fn
    end
    local sweep = NewBarStub()
    function sweep.ClearAllPoints() end
    local row = {
      visible = true,
      killTrackRunEnd = banner,
      killTrackRunEndWash = NewBarStub(),
      killTrackRunEndSweep = sweep,
      killTrackRunEndText = NewFontStringStub(),
    }
    function banner.IsVisible()
      return row.visible
    end
    return row
  end

  local function Tick(row, seconds)
    row.killTrackRunEnd._scripts.OnUpdate(row.killTrackRunEnd, seconds)
  end

  test("Key end banner loops until it is cleared and then removes its OnUpdate", function()
    WithGlobals({ IsiLiveDB = {} }, function()
      local addon = LoadKillRow(nil)
      local row = NewRunEndRow()
      Assert.True(addon._RosterInternal.PlayKillTrackRunEnd(row, "timed"), "a visible row plays")
      Assert.True(row.killTrackRunEnd._shown, "the banner is shown")
      Assert.Equal(row.killTrackRunEnd._alpha, 0, "the banner starts transparent")
      Tick(row, 0.7)
      Assert.Equal(row.killTrackRunEnd._alpha, 1, "the banner has faded in")
      Assert.True(row.killTrackRunEndSweep._shown, "the timed banner sweeps")
      Tick(row, 1.0)
      Assert.True(row.killTrackRunEndSweep._shown == false, "the sweep pauses between two passes")
      for _ = 1, 100 do
        Tick(row, 2.4)
      end
      Assert.True(row.killTrackRunEnd._shown, "the banner has no duration of its own")
      Assert.Equal(row.killTrackRunEnd._alpha, 1, "the loop keeps the banner opaque")
      Assert.True(addon._RosterInternal.ClearKillTrackRunEnd(row), "a standing banner can be cleared")
      Tick(row, 0.2)
      Assert.True(row.killTrackRunEnd._alpha < 1, "the cleared banner fades out")
      Tick(row, 0.2)
      Assert.True(row.killTrackRunEnd._shown == false, "the banner hides after its fade")
      Assert.Nil(row.killTrackRunEnd._scripts.OnUpdate, "no OnUpdate is left behind")
    end)
  end)

  test("Key end banner ends on its own 60 seconds after it appeared", function()
    local timers = {}
    local clock = {
      After = function(seconds, fn)
        table.insert(timers, { seconds = seconds, fn = fn })
      end,
    }
    WithGlobals({ IsiLiveDB = {}, C_Timer = clock }, function()
      local addon = LoadKillRow(nil)
      local row = NewRunEndRow()
      row.visible = false
      addon._RosterInternal.PlayKillTrackRunEnd(row, "timed")
      addon._RosterInternal.PlayKillTrackRunEnd(row, "late")
      Assert.Equal(#timers, 2, "every banner gets its own limit")
      Assert.Equal(timers[1].seconds, 60, "the limit is 60 seconds")
      timers[1].fn()
      Assert.True(row.killTrackRunEnd._shown, "the replaced banner's limit leaves the newer one alone")
      timers[2].fn()
      Assert.True(row.killTrackRunEnd._shown == false, "the limit ends the banner, also in a hidden row")
    end)
  end)

  test("Key end banner waits in a hidden row and is cleared without a fade", function()
    WithGlobals({ IsiLiveDB = {} }, function()
      local addon = LoadKillRow(nil)
      local row = NewRunEndRow()
      row.visible = false
      Assert.True(addon._RosterInternal.PlayKillTrackRunEnd(row, "late"), "a hidden row keeps the outcome")
      Assert.True(row.killTrackRunEnd._shown, "the banner stands ready for the opening window")
      addon._RosterInternal.ClearKillTrackRunEnd(row)
      Assert.True(row.killTrackRunEnd._shown == false, "nobody sees it, so it ends at once")
      Assert.False(addon._RosterInternal.ClearKillTrackRunEnd(row), "nothing is left to clear")
    end)
  end)

  test("Key end banner ignores an unknown outcome", function()
    WithGlobals({ IsiLiveDB = {} }, function()
      local addon = LoadKillRow(nil)
      local row = NewRunEndRow()
      Assert.False(addon._RosterInternal.PlayKillTrackRunEnd(row, "guess"), "unknown outcomes do nothing")
      Assert.True(row.killTrackRunEnd._shown == false, "the banner stays hidden")
    end)
  end)

  test("Key end banner with reduced motion stays readable without fade or sweep", function()
    WithGlobals({ IsiLiveDB = { reduceMotion = true } }, function()
      local addon = LoadKillRow(nil)
      local row = NewRunEndRow()
      addon._RosterInternal.PlayKillTrackRunEnd(row, "timed")
      Assert.Equal(row.killTrackRunEnd._alpha, 1, "the banner appears fully opaque")
      Tick(row, 0.5)
      Assert.True(row.killTrackRunEndSweep._shown == false, "reduced motion has no sweep")
      Assert.Equal(row.killTrackRunEndWash._width, 200, "the colour stays complete")
      Tick(row, 60)
      Assert.Equal(row.killTrackRunEnd._alpha, 1, "reduced motion stays opaque")
      Assert.True(row.killTrackRunEnd._shown, "the outcome stays readable until it is cleared")
      addon._RosterInternal.ClearKillTrackRunEnd(row)
      Assert.True(row.killTrackRunEnd._shown == false, "reduced motion has no fade-out")
    end)
  end)

  test("Key end banner settles at once when reduced motion is switched on", function()
    local db = {}
    WithGlobals({ IsiLiveDB = db }, function()
      local addon = LoadKillRow(nil)
      local row = NewRunEndRow()
      addon._RosterInternal.PlayKillTrackRunEnd(row, "abandoned")
      Tick(row, 2)
      Assert.True(row.killTrackRunEndWash._width < 200, "the colour is draining")
      db.reduceMotion = true
      Tick(row, 0.05)
      Assert.Equal(row.killTrackRunEnd._alpha, 1, "the banner is opaque on the next tick")
      Assert.Equal(row.killTrackRunEndWash._width, 200, "the colour is complete again on the next tick")
    end)
  end)

  test("CreateKillTrackRow puts the time pace text on an overlay above the bar", function()
    local recorder = NewCreateFrameRecorder()
    WithGlobals({
      CreateFrame = recorder.createFrame,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel_helpers.lua", "isiLive_roster_panel_kill_row.lua" })
      local mainFrame = recorder.createFrame("Frame", nil, nil)
      local row = addon._RosterInternal.CreateKillTrackRow(mainFrame)
      local overlay = Assert.NotNil(row.killTrackBarOverlay, "bar overlay frame must be created")
      local paceText = row.killTrackTimePaceText

      Assert.Nil(row.killTrackActiveDungeonText, "an active run shows no dungeon name on the bar")
      Assert.True(
        overlay._frameLevel > row.killTrackBarContainer._frameLevel,
        "bar overlay must be above the bar container frame"
      )
      Assert.True(
        overlay._points[1][2] ~= row.killTrackBarContainer,
        "bar overlay must not be anchored to the 8px bar container"
      )
      Assert.Equal(paceText._parent, overlay, "time pace text lives on the bar overlay")
      Assert.Equal(paceText._points[1][1], "RIGHT", "time pace text is right-aligned on the bar")
      Assert.Equal(paceText._drawLayer[1], "OVERLAY", "time pace text must render above bar textures")
      Assert.Equal(paceText._drawLayer[2], 7, "time pace text uses a high overlay sublayer")
      Assert.Equal(row._points[2][1], "BOTTOMRIGHT", "kill tracker row must expose an explicit right anchor")
      Assert.Equal(row._points[2][2], -6, "kill tracker row must end at the shared M+ right edge")
    end)
  end)

  test("CreateKillTrackRow groups the pre-key target under one pulse frame", function()
    local recorder = NewCreateFrameRecorder()
    WithGlobals({
      CreateFrame = recorder.createFrame,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel_helpers.lua", "isiLive_roster_panel_kill_row.lua" })
      local row = addon._RosterInternal.CreateKillTrackRow(recorder.createFrame("Frame", nil, nil))
      local pulse = Assert.NotNil(row.killTrackTargetPulse, "pulse frame must be created")
      local group = Assert.NotNil(row.killTrackTargetPulseGroup, "pulse animation must be created")
      Assert.Equal(pulse._parent, row.killTrackBarOverlay, "the pre-key target is drawn on top of the bar")
      Assert.Equal(row.killTrackTargetText._points[1][1], "LEFT", "the dungeon name starts at the left of the bar")
      Assert.Equal(row.killTrackTargetLevelText._points[1][2], row.killTrackTargetText, "the level follows the name")
      Assert.Equal(row.killTrackTargetText._parent, pulse, "dungeon name pulses with the frame")
      Assert.Equal(row.killTrackTargetLevelText._parent, pulse, "key level pulses with the frame")
      Assert.Equal(group._looping, "BOUNCE", "pulse loops back and forth")
      Assert.Equal(group._anim._from, 1, "pulse starts fully visible")
      Assert.True(group._anim._to > 0, "pulse never fades the target out completely")
      Assert.False(group._playing, "pulse does not run before an update")

      row._targetPulseWanted = true
      pulse._scripts.OnShow()
      Assert.True(group._playing, "showing the frame resumes a wanted pulse")
      pulse._scripts.OnHide()
      Assert.False(group._playing, "hiding the frame stops the pulse")
    end)
  end)

  test("CreateKillTrackRow uses readable section color for its run label", function()
    local recorder = NewCreateFrameRecorder()
    WithGlobals({ CreateFrame = recorder.createFrame }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_roster_panel_helpers.lua",
        "isiLive_roster_panel_kill_row.lua",
      })
      local row = addon._RosterInternal.CreateKillTrackRow(recorder.createFrame("Frame", nil, nil))
      local label = Assert.NotNil(row.killTrackLabel, "run label must be exposed")
      Assert.Equal(label._text, "M+Tracker", "run label must remain the same brand text")
      Assert.Equal(
        label._textColor[1],
        addon.UICommon.Colors.TEXT_SECTION[1],
        "run label must use readable section contrast"
      )
      Assert.Equal(
        row.killTrackBarContainer._height,
        10,
        "run progress bar must remain easy to scan in the compact row"
      )
      Assert.Equal(row.killTrackPctText._font[2], 14, "run percentage must be the strongest compact-row data label")
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
      Assert.False(row.killTrackTargetPulseGroup._playing, "no target means no pulse")
      Assert.Equal(row.killTrackPctText._text, "--.--", "pct text must reset to the enUS placeholder")
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
      Assert.Equal(row.killTrackPctText._text, "--.--", "inactive must reset pct text")
    end)
  end)

  test("UpdateKillTrackRow renders verified target key on the bar before challenge start", function()
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
      Assert.True(row.killTrackBarContainer._shown == true, "pre-key target keeps the empty bar visible")
      Assert.True(row.killTrackBarBg._shown == true, "pre-key target keeps the bar background visible")
      Assert.Equal(row.killTrackTargetText._text, "Windlaeufer Turm", "pre-key target must show the dungeon name")
      Assert.Equal(row.killTrackTargetLevelText._text, "+14", "pre-key target must show the colored key level")
      Assert.True(row.killTrackTargetPulseGroup._playing, "pre-key target must pulse until the key starts")
      Assert.Equal(row.killTrackTargetText._color[1], 1.0, "pre-key dungeon text must be gold-tinted")
      Assert.Equal(row.killTrackTargetLevelText._color[3], 1.0, "pre-key level text must be blue-tinted")
      Assert.Equal(row.killTrackPctText._text, "--.--", "pre-key target keeps the percent placeholder")
      Assert.Equal(row.killTrackPullText._text, "", "pre-key target must clear pull text")
    end)
  end)

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
      Assert.True(row.killTrackBarContainer._shown == true, "pre-key dungeon keeps the bar visible without level")
      Assert.Equal(row.killTrackTargetText._text, "Nexuspunkt Xenas", "verified dungeon name must render")
      Assert.Equal(row.killTrackTargetLevelText._text, "", "unresolved level must stay hidden")
      Assert.Equal(row.killTrackPctText._text, "--.--", "pre-key dungeon keeps the percent placeholder")
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

  test("UpdateKillTrackRow keeps the target key after challenge start until percent data is active", function()
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
      Assert.Equal(row.killTrackTargetText._text, "Windlaeufer Turm", "inserted key keeps the dungeon on the bar")
      Assert.Equal(row.killTrackTargetLevelText._text, "+14", "inserted key keeps the level on the bar")
      Assert.True(row.killTrackTargetPulseGroup._playing, "the target pulses until the key starts")
      Assert.Equal(row.killTrackPctText._text, "--.--", "inactive row keeps the percent placeholder")
      Assert.True(row.killTrackBarContainer._shown == true, "inactive row keeps the bar visible")
    end)
  end)

  test("UpdateKillTrackRow prefers the inserted key level over the target level before start", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = false, percent = 0 })
      addon.MplusTimer = {
        GetKeyLevel = function()
          return 16
        end,
      }
      local row = NewRow()
      addon._RosterInternal.UpdateKillTrackRow(row, {
        getTargetDungeonInfo = function()
          return { name = "Windlaeufer Turm", level = 14 }
        end,
        isInChallengeMode = function()
          return true
        end,
      })
      Assert.Equal(row.killTrackTargetLevelText._text, "+16", "the inserted key level wins once challenge mode runs")
    end)
  end)

  test("UpdateKillTrackRow fills the bar after the pre-key target display", function()
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
      Assert.True(row.killTrackBarContainer._shown == true, "pre-key target keeps the bar")
      Assert.True(row.killTrackBarFill._shown == false, "pre-key bar stays empty")

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

  test("UpdateKillTrackRow keeps the dungeon on the bar steady once the key runs", function()
    WithGlobals({}, function()
      local killTrackData = { active = false, percent = 0 }
      local addon = LoadKillRow(killTrackData)
      addon.MplusTimer = {
        GetTimerData = function()
          return { running = true, keyLevel = 16 }
        end,
      }
      local row = NewRow(200)
      local deps = {
        getTargetDungeonInfo = function()
          return { name = "  Nexuspunkt Xenas  ", level = 14 }
        end,
        isInChallengeMode = function()
          return false
        end,
      }
      addon._RosterInternal.UpdateKillTrackRow(row, deps)
      Assert.True(row.killTrackTargetPulseGroup._playing, "pre-key target pulses")
      Assert.Equal(row.killTrackTargetLevelText._text, "+14", "pre-key level comes from the target")

      killTrackData.active = true
      killTrackData.percent = 42
      addon._RosterInternal.UpdateKillTrackRow(row, deps)
      Assert.False(row.killTrackTargetPulseGroup._playing, "a running key stops the pulse")
      Assert.Equal(row.killTrackTargetPulse._alpha, 1, "a stopped pulse leaves the target opaque")
      Assert.Equal(row.killTrackTargetText._text, "Nexuspunkt Xenas", "the running key keeps its dungeon on the bar")
      Assert.Equal(row.killTrackTargetLevelText._text, "+16", "the running key shows the started level from the timer")
      Assert.Equal(row.killTrackPctText._text, "42.00%", "active percent text stays primary")
    end)
  end)

  test("UpdateKillTrackRow omits the running key level when the timer has none", function()
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
          return { name = "Nexuspunkt Xenas", level = 14 }
        end,
        isInChallengeMode = function()
          return true
        end,
      })
      Assert.Equal(row.killTrackTargetText._text, "Nexuspunkt Xenas", "the dungeon name still shows")
      Assert.Equal(row.killTrackTargetLevelText._text, "", "the target level must not stand in for the started level")
    end)
  end)

  test("UpdateKillTrackRow glows the empty bar gold with a light sweep until the key starts", function()
    local recorder = NewCreateFrameRecorder()
    WithGlobals({ CreateFrame = recorder.createFrame }, function()
      local killTrackData = { active = false, percent = 0 }
      local addon = LoadKillRow(killTrackData)
      local row = addon._RosterInternal.CreateKillTrackRow(recorder.createFrame("Frame", nil, nil))
      local surface = Assert.NotNil(row.killTrackPreKeySurface, "the pre-key banner must be created")
      surface._width = 200
      local fill = Assert.NotNil(row.killTrackReadyFill, "the gold ready fill must be created")
      local shimmer = Assert.NotNil(row.killTrackShimmer, "the light sweep must be created")
      local sweep = Assert.NotNil(row.killTrackShimmerGroup, "the light sweep must be animated")
      Assert.Equal(shimmer._parent, surface, "the sweep is clipped by the banner over the whole row")
      Assert.Equal(surface._parent, row.runSurface, "the banner covers the whole row")
      Assert.True(surface._shown == false, "the banner starts hidden")
      Assert.True(fill._shown == false, "the gold fill starts hidden")
      Assert.True(shimmer._shown == false, "the sweep starts hidden")

      local deps = {
        getTargetDungeonInfo = function()
          return { name = "Windlaeufer Turm", level = 14 }
        end,
        isInChallengeMode = function()
          return false
        end,
      }
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.True(fill._shown == false, "without a target the bar stays plain")

      addon._RosterInternal.UpdateKillTrackRow(row, deps)
      Assert.True(surface._shown == true, "a known target shows the banner")
      Assert.True(fill._shown == true, "a known target glows the empty bar gold")
      Assert.True(shimmer._shown == true, "a known target shows the light sweep")
      Assert.True(sweep._playing, "the light sweep runs before the key")
      Assert.Equal(sweep._looping, "REPEAT", "the sweep repeats in one direction")
      Assert.Equal(sweep._anim._offset[1], 272, "the sweep crosses the whole row plus its own width")

      killTrackData.active = true
      killTrackData.percent = 12
      addon._RosterInternal.UpdateKillTrackRow(row, deps)
      Assert.True(surface._shown == false, "a running key drops the banner")
      Assert.True(fill._shown == false, "a running key drops the gold fill")
      Assert.True(shimmer._shown == false, "a running key hides the sweep")
      Assert.False(sweep._playing, "a running key stops the sweep")
    end)
  end)

  test("UpdateKillTrackRow keeps a finished key steady on the plain bar", function()
    local recorder = NewCreateFrameRecorder()
    WithGlobals({ CreateFrame = recorder.createFrame }, function()
      local addon = LoadKillRow({ active = false, percent = 0 })
      local row = addon._RosterInternal.CreateKillTrackRow(recorder.createFrame("Frame", nil, nil))
      row.killTrackBarContainer._width = 200
      addon._RosterInternal.UpdateKillTrackRow(row, {
        getTargetDungeonInfo = function()
          return { name = "Nexuspunkt Xenas", level = 15, finished = true }
        end,
        isInChallengeMode = function()
          return true
        end,
      })
      Assert.Equal(row.killTrackTargetText._text, "Nexuspunkt Xenas", "the finished key keeps its dungeon")
      Assert.Equal(row.killTrackTargetLevelText._text, "+15", "the finished key keeps its level")
      Assert.False(row.killTrackTargetPulseGroup._playing, "a finished key does not pulse")
      Assert.True(row.killTrackReadyFill._shown == false, "a finished key does not glow gold")
      Assert.True(row.killTrackShimmer._shown == false, "a finished key shows no light sweep")
    end)
  end)

  test("UpdateKillTrackRow keeps the pre-key target steady with reduced motion", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = false, percent = 0 })
      addon.UICommon.IsReducedMotionEnabled = function()
        return true
      end
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row, {
        getTargetDungeonInfo = function()
          return { name = "Nexuspunkt Xenas", level = 14 }
        end,
        isInChallengeMode = function()
          return false
        end,
      })
      Assert.Equal(row.killTrackTargetText._text, "Nexuspunkt Xenas", "the target still shows")
      Assert.False(row.killTrackTargetPulseGroup._playing, "reduced motion keeps the target steady")
    end)
  end)

  -- Active path: colors, number format, motion ---------------------------------

  local function AssertRgb(actual, expected, message)
    Assert.Equal(actual[1], expected[1], message .. " (r)")
    Assert.Equal(actual[2], expected[2], message .. " (g)")
    Assert.Equal(actual[3], expected[3], message .. " (b)")
  end

  -- NewRow's bar container has no SetScript, so updates apply directly. This
  -- variant records OnUpdate like a real frame so the easing can be driven.
  local function NewAnimatedRow(barContainerWidth)
    local row = NewRow(barContainerWidth)
    local container = row.killTrackBarContainer
    container._scripts = {}
    function container.SetScript(self, name, handler)
      self._scripts[name] = handler
    end
    return row
  end

  test("UpdateKillTrackRow renders open forces in calm blue and full forces in green", function()
    WithGlobals({}, function()
      local killTrackData = { active = true, percent = 50 }
      local addon = LoadKillRow(killTrackData)
      local Colors = addon.UICommon.Colors
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      local fill = row.killTrackBarFill
      Assert.True(fill._shown == true, "fill must show for active data")
      Assert.Equal(fill._width, 100, "fill width must be 50% of 200")
      AssertRgb(fill._color, Colors.MPLUS_FORCES_PROGRESS_FILL, "open forces must use the calm progress blue")
      AssertRgb(row.killTrackPctText._color, Colors.LIGHT_BLUE_LEVEL_TEXT, "open forces text must stay cool")
      Assert.Equal(row.killTrackPctText._text, "50.00%", "enUS percent text must use a decimal point")

      killTrackData.percent = 99
      addon._RosterInternal.UpdateKillTrackRow(row)
      AssertRgb(fill._color, Colors.MPLUS_FORCES_PROGRESS_FILL, "near-complete forces must not turn into a warning")

      killTrackData.percent = 100
      addon._RosterInternal.UpdateKillTrackRow(row)
      AssertRgb(fill._color, Colors.SUCCESS_GREEN_BAR, "complete forces must turn green")
      AssertRgb(row.killTrackPctText._color, Colors.GREEN_HINT_TEXT, "complete forces text must turn green")
    end)
  end)

  test("UpdateKillTrackRow formats percentages with the addon language decimal separator", function()
    WithGlobals({ IsiLiveDB = { locale = "deDE" } }, function()
      local killTrackData = { active = true, percent = 42.5, inCombat = true, pullPercent = 3.25 }
      local addon = LoadKillRow(killTrackData)
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackPctText._text, "42,50%", "deDE percent text must use a decimal comma")
      Assert.Equal(row.killTrackPullText._text, "+3,25%", "deDE pull text must use a decimal comma")

      killTrackData.active = false
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackPctText._text, "--,--", "deDE placeholder must use a decimal comma")
    end)
  end)

  test("UpdateKillTrackRow draws the pull inside the fill so the bar never overshoots", function()
    WithGlobals({}, function()
      local killTrackData = { active = true, percent = 43, inCombat = true, pullPercent = 34 }
      local addon = LoadKillRow(killTrackData)
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackBarFill._width, 86, "the fill alone shows the real forces")
      Assert.Equal(row.killTrackBarPull._width, 68, "the pull colours its share of the fill")

      killTrackData.inCombat = false
      killTrackData.pullPercent = 0
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackBarFill._width, 86, "the end of the pull display does not move the bar")
      Assert.True(row.killTrackBarPull._shown == false, "only the colour goes away")

      killTrackData.percent = 10
      killTrackData.inCombat = true
      killTrackData.pullPercent = 50
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackBarPull._width, 20, "a larger pull value stays inside the fill")
    end)
  end)

  test("CreateKillTrackRow anchors the pull to the right end of the fill", function()
    local recorder = NewCreateFrameRecorder()
    WithGlobals({ CreateFrame = recorder.createFrame }, function()
      local addon = LoadKillRow({ active = false, percent = 0 })
      local row = addon._RosterInternal.CreateKillTrackRow(recorder.createFrame("Frame", nil, nil))
      local points = row.killTrackBarPull._points
      Assert.Equal(points[1][1], "TOPRIGHT", "the pull grows from the fill's end to the left")
      Assert.Equal(points[1][2], row.killTrackBarFill, "the pull follows the easing fill")
      Assert.Equal(points[1][3], "TOPRIGHT", "the pull ends where the fill ends")
    end)
  end)

  test("Key end banner and pre-key target use white text", function()
    local recorder = NewCreateFrameRecorder()
    WithGlobals({ CreateFrame = recorder.createFrame }, function()
      local addon = LoadKillRow({ active = false, percent = 0 })
      local row = addon._RosterInternal.CreateKillTrackRow(recorder.createFrame("Frame", nil, nil))
      Assert.Equal(row.killTrackRunEndText._textColor[3], 1, "the banner text is white")
      addon._RosterInternal.UpdateKillTrackRow(row, {
        getTargetDungeonInfo = function()
          return { name = "Nexuspunkt Xenas", level = 14 }
        end,
      })
      Assert.Equal(row.killTrackTargetText._textColor[3], 1, "the pre-key name is white on the gold banner")
    end)
  end)

  test("UpdateKillTrackRow eases a changed fill width over the shared motion duration", function()
    WithGlobals({}, function()
      local killTrackData = { active = true, percent = 40 }
      local addon = LoadKillRow(killTrackData)
      local row = NewAnimatedRow(200)
      local container = row.killTrackBarContainer
      local fill = row.killTrackBarFill

      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(fill._width, 80, "the first width must apply directly")
      Assert.Nil(container._scripts.OnUpdate, "the first width must not start an animation")

      killTrackData.percent = 60
      killTrackData.inCombat = true
      killTrackData.pullPercent = 50
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(fill._width, 80, "a changed width must not jump to the target")
      Assert.Equal(row.killTrackBarPull._width, 100, "the pull sits inside the target fill (120 wide)")
      local onUpdate = Assert.NotNil(container._scripts.OnUpdate, "a changed width must animate")

      onUpdate(container, 0.1)
      Assert.Equal(fill._width, 110, "halfway through 0.2 s the ease-out must cover 75% of the change")
      onUpdate(container, 0.1)
      Assert.Equal(fill._width, 120, "the animation must end exactly on the target width")
      Assert.Nil(container._scripts.OnUpdate, "the finished animation must release its OnUpdate script")

      killTrackData.percent = 80
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.NotNil(container._scripts.OnUpdate, "a further change must animate again")
      killTrackData.active = false
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Nil(container._scripts.OnUpdate, "hiding the fill must stop a running animation")
      Assert.True(fill._shown == false, "inactive data must hide the fill")
    end)
  end)

  test("UpdateKillTrackRow applies fill width directly when reduced motion is enabled", function()
    WithGlobals({ IsiLiveDB = { reduceMotion = true } }, function()
      local killTrackData = { active = true, percent = 40 }
      local addon = LoadKillRow(killTrackData)
      local row = NewAnimatedRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      killTrackData.percent = 60
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackBarFill._width, 120, "reduced motion must apply the new width at once")
      Assert.Nil(row.killTrackBarContainer._scripts.OnUpdate, "reduced motion must not start an animation")
    end)
  end)

  test("UpdateKillTrackRow flashes the fill once when forces reach 100 percent", function()
    WithGlobals({}, function()
      local killTrackData = { active = true, percent = 90 }
      local addon = LoadKillRow(killTrackData)
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Nil(row.killTrackBarFill._animGroup, "open forces must not flash")

      killTrackData.percent = 100
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackBarFill._animGroup.plays, 1, "reaching 100% must flash the fill once")
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackBarFill._animGroup.plays, 1, "staying at 100% must not flash again")

      local freshRow = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(freshRow)
      Assert.Nil(freshRow.killTrackBarFill._animGroup, "a first render already at 100% must stay quiet")
    end)
  end)

  -- Active path: percent clamped to 100 ----------------------------------------

  test("UpdateKillTrackRow clamps percent to [0, 100]", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = true, percent = 130 })
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackBarFill._width, 200, "clamped percent must yield full width")
      Assert.Equal(row.killTrackPctText._text, "100%", "pct text must be clamped to a short 100%")
    end)
  end)

  test("UpdateKillTrackRow never rounds open forces up to 100%", function()
    WithGlobals({}, function()
      local addon = LoadKillRow({ active = true, percent = 99.997 })
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackPctText._text, "99.99%", "open forces must stay below 100%")
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
      Assert.Equal(row.killTrackPullText._text, "+20.00%", "pull text must show pull percent with plus prefix")
      Assert.Equal(
        row.killTrackPullText._color[1],
        addon.UICommon.Colors.LIGHT_BLUE_LEVEL_TEXT[1],
        "pull text uses the light-blue level color"
      )
    end)
  end)

  test("UpdateKillTrackRow keeps a large pull inside the fill width", function()
    WithGlobals({}, function()
      -- 200 wide, fill = 80% (160), pull = 30% (60): the pull lies inside the
      -- fill, so the end of the bar does not limit it.
      local addon = LoadKillRow({ active = true, percent = 80, inCombat = true, pullPercent = 30 })
      local row = NewRow(200)
      addon._RosterInternal.UpdateKillTrackRow(row)
      Assert.Equal(row.killTrackBarPull._width, 60, "the pull keeps its share inside the fill")
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
