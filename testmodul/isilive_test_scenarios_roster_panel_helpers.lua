---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  local function LoadHelpers()
    local addon = LoadAddonModules({ "isiLive_roster_panel_helpers.lua" })
    return addon._RosterInternal
  end

  test("ApplyFontStringSize returns silently for nil fontString", function()
    local RI = LoadHelpers()
    -- Must not throw; uncovered early-return guard.
    RI.ApplyFontStringSize(nil, 12)
  end)

  test("ApplyFontStringSize ignores objects without GetFont/SetFont", function()
    local RI = LoadHelpers()
    RI.ApplyFontStringSize({}, 14)
    RI.ApplyFontStringSize({ GetFont = function() end }, 14)
  end)

  test("ApplyFontStringSize ignores empty or non-string fontPath", function()
    local RI = LoadHelpers()
    local setCalls = 0
    local stub = {
      GetFont = function()
        return "", 12, "OUTLINE"
      end,
      SetFont = function()
        setCalls = setCalls + 1
      end,
    }
    RI.ApplyFontStringSize(stub, 18)
    Assert.Equal(setCalls, 0, "empty fontPath must skip SetFont")

    stub.GetFont = function()
      return nil, 12, "OUTLINE"
    end
    RI.ApplyFontStringSize(stub, 18)
    Assert.Equal(setCalls, 0, "nil fontPath must skip SetFont")
  end)

  test("ApplyFontStringSize calls SetFont with new size and preserved flags", function()
    local RI = LoadHelpers()
    local captured
    local stub = {
      GetFont = function()
        return "Fonts\\FRIZQT__.TTF", 11, "OUTLINE"
      end,
      SetFont = function(_, path, size, flags)
        captured = { path = path, size = size, flags = flags }
      end,
    }
    RI.ApplyFontStringSize(stub, 22)
    Assert.Equal(captured.path, "Fonts\\FRIZQT__.TTF", "font path must be preserved")
    Assert.Equal(captured.size, 22, "size must be the new value")
    Assert.Equal(captured.flags, "OUTLINE", "flags must be preserved")
  end)

  test("FormatMplusTime formats positive seconds as M:SS", function()
    local RI = LoadHelpers()
    Assert.Equal(RI.FormatMplusTime(0), "0:00", "zero seconds")
    Assert.Equal(RI.FormatMplusTime(5), "0:05", "single digit seconds pad to two digits")
    Assert.Equal(RI.FormatMplusTime(59), "0:59", "boundary just before minute")
    Assert.Equal(RI.FormatMplusTime(60), "1:00", "exactly one minute")
    Assert.Equal(RI.FormatMplusTime(125), "2:05", "two minutes five seconds")
    Assert.Equal(RI.FormatMplusTime(3599), "59:59", "just under one hour")
  end)

  test("FormatMplusTime treats negative seconds via abs (no leading minus)", function()
    local RI = LoadHelpers()
    -- Helper returns the absolute formatted time; the minus prefix for
    -- "over time" is added by callers (see roster_panel_cd_row mp1Text path).
    Assert.Equal(RI.FormatMplusTime(-30), "0:30", "negative seconds use abs value")
    Assert.Equal(RI.FormatMplusTime(-125), "2:05", "negative minutes/seconds use abs value")
  end)

  test("SetFontStringTextColorSafe forwards rgb to SetTextColor", function()
    local RI = LoadHelpers()
    local captured
    local stub = {
      SetTextColor = function(_, r, g, b)
        captured = { r, g, b }
      end,
    }
    RI.SetFontStringTextColorSafe(stub, 0.4, 1.0, 0.4)
    Assert.Equal(captured[1], 0.4, "r forwarded")
    Assert.Equal(captured[2], 1.0, "g forwarded")
    Assert.Equal(captured[3], 0.4, "b forwarded")
  end)

  test("SetFontStringTextColorSafe is a no-op for nil and SetTextColor-less objects", function()
    local RI = LoadHelpers()
    -- Both branches must not throw.
    RI.SetFontStringTextColorSafe(nil, 1, 1, 1)
    RI.SetFontStringTextColorSafe({}, 1, 1, 1)
  end)

  test("BuildDeathSummaryTooltipLines sorts tracked Mythic+ deaths by player name", function()
    local RI = LoadAddonModules({ "isiLive_roster_panel.lua" })._RosterInternal
    local lines = RI.BuildDeathSummaryTooltipLines({
      { name = "Pinto", count = 5 },
      { name = "Abi", count = 3 },
      { name = "Bircan", count = 6 },
      { name = "Ignored", count = 0 },
    })

    Assert.Equal(#lines, 3, "zero-count entries must not render")
    Assert.Equal(lines[1].name, "Abi", "death tooltip should sort alphabetically by player")
    Assert.Equal(lines[1].count, 3, "Abi count")
    Assert.Equal(lines[2].name, "Bircan", "second player")
    Assert.Equal(lines[2].count, 6, "Bircan count")
    Assert.Equal(lines[3].name, "Pinto", "third player")
    Assert.Equal(lines[3].count, 5, "Pinto count")
  end)

  test("BuildDeathTimeLostTooltipLine moves death penalty into the skull tooltip", function()
    local RI = LoadAddonModules({ "isiLive_roster_panel.lua" })._RosterInternal

    Assert.Nil(RI.BuildDeathTimeLostTooltipLine(0, {}), "zero time penalty must not add a tooltip line")
    Assert.Nil(RI.BuildDeathTimeLostTooltipLine(nil, {}), "missing time penalty must not add a tooltip line")
    Assert.Equal(
      RI.BuildDeathTimeLostTooltipLine(150, { TOOLTIP_DEATH_TIME_LOST_FMT = "Zeitstrafe: +%ds" }),
      "Zeitstrafe: +150s",
      "positive death penalty must render as a tooltip-only line"
    )
  end)

  -- UpdateCdTrackerRow branch coverage. Lives in isiLive_roster_panel_cd_row.lua;
  -- exposed via _RosterInternal. Pure-function over a row stub + cdController
  -- stub, so we drive every branch without FrameXML.
  local function MakeFontStringStub()
    local fs = { _text = "", _color = nil }
    function fs:SetText(text)
      self._text = tostring(text or "")
    end
    function fs:SetTextColor(r, g, b, a)
      self._color = { r, g, b, a }
    end
    function fs:GetText()
      return self._text
    end
    function fs:SetPoint(...)
      self._point = { ... }
    end
    function fs:SetAllPoints(parent)
      self._allPoints = parent
    end
    function fs:SetWidth(width)
      self._width = width
    end
    function fs:SetJustifyH(justify)
      self._justifyH = justify
    end
    function fs:SetJustifyV(justify)
      self._justifyV = justify
    end
    -- Helpers used by ApplyFontStringSize via cd_row CD_TRACKER_FONT_SIZE
    -- writeback (called once during row creation only — not in update path).
    fs.SetFont = function() end
    fs.GetFont = function()
      return "Fonts\\\\X.TTF", 12, "OUTLINE"
    end
    fs._alpha = 1
    function fs:SetAlpha(alpha)
      self._alpha = alpha
    end
    function fs:GetAlpha()
      return self._alpha
    end
    -- Records decorative transitions started through UICommon.PlayAlphaTransition.
    function fs:CreateAnimationGroup()
      local group = { plays = 0, _playing = false }
      function group:CreateAnimation()
        return {
          SetFromAlpha = function() end,
          SetToAlpha = function() end,
          SetDuration = function() end,
          SetSmoothing = function() end,
        }
      end
      function group:SetScript() end
      function group:IsPlaying()
        return self._playing
      end
      function group:Play()
        self.plays = self.plays + 1
        self._playing = true
      end
      function group:Stop()
        self._playing = false
      end
      fs._animGroup = group
      return group
    end
    return fs
  end

  local function MakeIconStub()
    local icon = { _shown = false, _texture = nil }
    function icon:SetTexture(tex)
      self._texture = tex
    end
    function icon:SetSize(width, height)
      self._size = { width, height }
    end
    function icon:SetPoint(...)
      self._point = { ... }
      self._points = self._points or {}
      self._points[#self._points + 1] = { ... }
    end
    function icon:ClearAllPoints()
      self._points = {}
    end
    function icon:SetHeight(height)
      self._height = height
    end
    function icon:SetWidth(width)
      self._width = width
    end
    function icon:SetColorTexture(r, g, b, a)
      self._colorTexture = { r, g, b, a }
    end
    function icon:SetTexCoord(...)
      self._texCoord = { ... }
    end
    function icon:SetAllPoints(parent)
      self._allPoints = parent
    end
    function icon:SetVertexColor(r, g, b, a)
      self._vertexColor = { r, g, b, a }
    end
    function icon:SetDesaturated(desaturated)
      self._desaturated = desaturated
    end
    function icon:Show()
      self._shown = true
    end
    function icon:Hide()
      self._shown = false
    end
    return icon
  end

  local function MakeCdRowStub(opts)
    opts = opts or {}
    return {
      bresIcon = MakeIconStub(),
      bresText = MakeFontStringStub(),
      lustIcon = MakeIconStub(),
      lustText = MakeFontStringStub(),
      mplusBox = {
        _shown = false,
        Show = function(self)
          self._shown = true
        end,
        Hide = function(self)
          self._shown = false
        end,
      },
      mp1Text = MakeFontStringStub(),
      mp2Text = MakeFontStringStub(),
      mp3Text = MakeFontStringStub(),
      mpDeathText = MakeFontStringStub(),
      _bresIconReady = opts.bresIconReady ~= false,
      _lustIconReady = opts.lustIconReady ~= false,
      _lustDefaultIcon = opts.lustDefaultIcon or "Interface\\Icons\\BL_Default",
    }
  end

  local function LoadCdRow()
    local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
    return addon._RosterInternal
  end

  local function MakeFrameStub()
    local frame = { _shown = true, _scripts = {} }
    function frame:SetHeight(height)
      self._height = height
    end
    function frame:SetWidth(width)
      self._width = width
    end
    function frame:SetSize(width, height)
      self._size = { width, height }
    end
    function frame:SetPoint(...)
      self._point = self._point or {}
      self._point[#self._point + 1] = { ... }
    end
    function frame:Show()
      self._shown = true
    end
    function frame:Hide()
      self._shown = false
    end
    function frame:CreateTexture()
      return MakeIconStub()
    end
    function frame:CreateFontString()
      return MakeFontStringStub()
    end
    function frame:EnableMouse(enabled)
      self._mouseEnabled = enabled
    end
    function frame:SetFrameLevel(level)
      self._frameLevel = level
    end
    function frame:GetFrameLevel()
      return self._frameLevel or 1
    end
    function frame:SetScript(scriptName, handler)
      self._scripts[scriptName] = handler
    end
    function frame:GetWidth()
      return self._layoutWidth or 0
    end
    -- Cooldown-frame surface (CreateFrame("Cooldown", ...) returns this stub too).
    function frame:SetAllPoints(target)
      self._allPoints = target
    end
    function frame:SetDrawEdge(enabled)
      self._drawEdge = enabled
    end
    function frame:SetHideCountdownNumbers(hidden)
      self._hideCountdownNumbers = hidden
    end
    function frame:SetCooldown(start, duration)
      self._cooldownCalls = self._cooldownCalls or {}
      self._cooldownCalls[#self._cooldownCalls + 1] = { start, duration }
    end
    function frame:SetAlpha(alpha)
      self._alpha = alpha
    end
    return frame
  end

  test("UpdateCdTrackerRow returns silently for nil row", function()
    local RI = LoadCdRow()
    RI.UpdateCdTrackerRow(nil, {
      GetBResInfo = function()
        return nil
      end,
      GetLustInfo = function()
        return nil
      end,
    })
  end)

  test("CreateCdTrackerRow renders M+ grade badges and wide timer fields", function()
    local row
    WithGlobals({
      CreateFrame = function()
        return MakeFrameStub()
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" }, {
        UICommon = {
          ApplyBackdrop = function() end,
        },
      })
      row = addon._RosterInternal.CreateCdTrackerRow(MakeFrameStub(), {})
    end)

    Assert.NotNil(row, "cd tracker row should be created")
    Assert.Equal(row.cdBox._isiLiveSurfaceRole, "run", "cooldown box should use the shared M+ run surface")
    Assert.Equal(row.mplusBox._isiLiveSurfaceRole, "run", "timer box should use the shared M+ run surface")
    Assert.Equal(row.mp3Icon._size[1], 20, "+3 badge must be wider than the old ellipsizing 16px")
    Assert.Equal(row.mp2Icon._size[1], 20, "+2 badge must be wider than the old ellipsizing 16px")
    Assert.Equal(row.mp1Icon._size[1], 20, "+1 badge must be wider than the old ellipsizing 16px")
    Assert.Equal(row.mp3Text._width, 48, "+3 timer must fit five-character M+ times")
    Assert.Equal(row.mp2Text._width, 48, "+2 timer must fit five-character M+ times")
    Assert.Equal(row.mp1Text._width, 48, "+1 timer must fit five-character M+ times")
    Assert.Equal(row._point[2][1], "BOTTOMRIGHT", "timer row must expose an explicit right anchor")
    Assert.Equal(row._point[2][2], -6, "BR/BL and M+ timer row must end at the shared M+ right edge")
  end)

  test("UpdateCdTrackerRow renders BR charges + remaining cooldown when remain > 0", function()
    local RI = LoadCdRow()
    local row = MakeCdRowStub()
    RI.UpdateCdTrackerRow(row, {
      GetBResInfo = function()
        return { charges = 1, maxCharges = 2, cooldownRemain = 95 }
      end,
      GetLustInfo = function()
        return nil
      end,
    })
    Assert.Equal(row.bresText:GetText(), "1/2  1:35", "BR text must include charges + mm:ss cooldown")
  end)

  test("UpdateCdTrackerRow renders BR charges-only when cooldownRemain is zero", function()
    local RI = LoadCdRow()
    local row = MakeCdRowStub()
    RI.UpdateCdTrackerRow(row, {
      GetBResInfo = function()
        return { charges = 2, maxCharges = 2, cooldownRemain = 0 }
      end,
      GetLustInfo = function()
        return nil
      end,
    })
    Assert.Equal(row.bresText:GetText(), "2/2", "BR text must omit cooldown when remain is zero")
  end)

  test("UpdateCdTrackerRow renders BR placeholder when controller has no BR info", function()
    local RI = LoadCdRow()
    local row = MakeCdRowStub()
    RI.UpdateCdTrackerRow(row, {
      GetBResInfo = function()
        return nil
      end,
      GetLustInfo = function()
        return nil
      end,
    })
    Assert.Equal(row.bresText:GetText(), "BR: --", "BR text must render '--' when info is missing")
  end)

  test("UpdateCdTrackerRow renders BL countdown with active aura icon override", function()
    local RI = LoadCdRow()
    local row = MakeCdRowStub()
    RI.UpdateCdTrackerRow(row, {
      GetBResInfo = function()
        return nil
      end,
      GetLustInfo = function()
        return { remain = 35, icon = "Interface\\Icons\\Heroism" }
      end,
    })
    Assert.Equal(row.lustText:GetText(), "00:35", "active BL text must show only the mm:ss countdown")
    Assert.Equal(row.lustIcon._texture, "Interface\\Icons\\Heroism", "active aura icon must override the default")
    Assert.True(row.lustIcon._shown, "lust icon must be shown while active")
  end)

  test("UpdateCdTrackerRow renders BL ready as 00:00 when cooldown reached zero", function()
    local RI = LoadCdRow()
    local row = MakeCdRowStub({ lustDefaultIcon = "Interface\\Icons\\BL_Default" })
    -- Pretend a previous render had set a different texture; default must be re-applied.
    row.lustIcon._texture = "Interface\\Icons\\Heroism"
    RI.UpdateCdTrackerRow(row, {
      GetBResInfo = function()
        return nil
      end,
      GetLustInfo = function()
        return { remain = 0 }
      end,
    })
    Assert.Equal(row.lustText:GetText(), "00:00", "BL text must render 00:00 when the cooldown is ready in-key")
    Assert.Equal(row.lustIcon._texture, "Interface\\Icons\\BL_Default", "icon must revert to the default texture")
  end)

  test("UpdateCdTrackerRow restores default BL icon and renders BL: -- when no BL context exists", function()
    local RI = LoadCdRow()
    local row = MakeCdRowStub({ lustDefaultIcon = "Interface\\Icons\\BL_Default" })
    row.lustIcon._texture = "Interface\\Icons\\Heroism"
    RI.UpdateCdTrackerRow(row, {
      GetBResInfo = function()
        return nil
      end,
      GetLustInfo = function()
        return nil
      end,
    })
    Assert.Equal(row.lustText:GetText(), "BL: --", "BL text must render '--' when no in-key BL context exists")
    Assert.Equal(row.lustIcon._texture, "Interface\\Icons\\BL_Default", "icon must revert to the default texture")
  end)

  test("UpdateCdTrackerRow renders the M+ timer block when MplusTimer is running", function()
    -- Inject MplusTimer onto the SAME addonTable that owns _RosterInternal —
    -- the production code reads addonTable.MplusTimer at the closure scope, so
    -- a second LoadAddonModules() call would land on a different table.
    local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
    local RI = addon._RosterInternal
    local row = MakeCdRowStub()
    addon.MplusTimer = {
      GetTimerData = function()
        return {
          running = true,
          completed = false,
          timeRemaining3 = 130,
          timeRemaining2 = 65,
          timeRemaining1 = 30,
          deaths = 2,
          deathTimeLost = 30,
        }
      end,
    }
    RI.UpdateCdTrackerRow(row, {
      GetBResInfo = function()
        return nil
      end,
      GetLustInfo = function()
        return nil
      end,
    })
    addon.MplusTimer = nil

    Assert.True(row.mplusBox._shown, "M+ box must be visible during a running key")
    Assert.Equal(row.mp3Text:GetText(), "2:10", "+3 timer formats mm:ss")
    Assert.Equal(row.mp2Text:GetText(), "1:05", "+2 timer formats mm:ss")
    Assert.Equal(row.mp1Text:GetText(), "0:30", "+1 timer formats mm:ss")
    Assert.Equal(row.mpDeathText:GetText(), "|cffff60602|r", "death cell must show only the visible death count")
    Assert.Equal(row._deathTimeLost, 30, "death time penalty must stay available for the skull tooltip")
    Assert.True(
      row.mpDeathText:GetText():find("(+30s)", 1, true) == nil,
      "death cell must keep the time penalty out of the visible row"
    )
  end)

  test("UpdateCdTrackerRow renders red overshoot text on +1 when timeRemaining1 is negative", function()
    local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
    local RI = addon._RosterInternal
    local row = MakeCdRowStub()
    addon.MplusTimer = {
      GetTimerData = function()
        return {
          running = true,
          completed = false,
          timeRemaining3 = -5, -- already past +3 cap
          timeRemaining2 = -3, -- already past +2 cap
          timeRemaining1 = -120, -- 2 minutes overshoot on the par cap
          deaths = 0,
          deathTimeLost = 0,
        }
      end,
    }
    RI.UpdateCdTrackerRow(row, {
      GetBResInfo = function()
        return nil
      end,
      GetLustInfo = function()
        return nil
      end,
    })
    addon.MplusTimer = nil

    Assert.Equal(row.mp3Text:GetText(), "--:--", "+3 collapses to placeholder when negative")
    Assert.Equal(row.mp2Text:GetText(), "--:--", "+2 collapses to placeholder when negative")
    Assert.True(row.mp1Text:GetText():sub(1, 1) == "-", "+1 overshoot must render with leading '-'")
  end)

  -- M+ timer timeline + grade emphasis. Driven through the real
  -- CreateCdTrackerRow and UpdateCdTrackerRow, with the snapshot shape that
  -- MplusTimer.GetTimerData returns (1800 s limit: +3 at 1080 s, +2 at 1440 s).
  local NO_CD_CONTROLLER = {
    GetBResInfo = function()
      return nil
    end,
    GetLustInfo = function()
      return nil
    end,
  }

  local function BuildTimerSnapshot(timer)
    return {
      running = true,
      completed = false,
      timer = timer,
      timeLimit = 1800,
      keyLevel = 12,
      timeRemaining1 = 1800 - timer,
      timeRemaining2 = 1440 - timer,
      timeRemaining3 = 1080 - timer,
      deaths = 0,
      deathTimeLost = 0,
    }
  end

  local function BuildTimelineHarness(globals)
    local harness = { snapshot = nil }
    WithGlobals(globals or {}, function()
      WithGlobals({
        CreateFrame = function()
          return MakeFrameStub()
        end,
      }, function()
        harness.addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_roster_panel.lua" })
        harness.row = harness.addon._RosterInternal.CreateCdTrackerRow(MakeFrameStub(), {})
      end)
    end)
    -- 204 px box leaves a 200 px track between the 2 px insets.
    harness.row.mplusBox._layoutWidth = 204
    harness.addon.MplusTimer = {
      GetTimerData = function()
        return harness.snapshot
      end,
    }
    function harness.Render(snapshot)
      harness.snapshot = snapshot
      harness.addon._RosterInternal.UpdateCdTrackerRow(harness.row, NO_CD_CONTROLLER)
    end
    return harness
  end

  local function AssertColor(texture, color, message)
    Assert.Equal(texture._colorTexture[1], color[1], message .. " (r)")
    Assert.Equal(texture._colorTexture[2], color[2], message .. " (g)")
    Assert.Equal(texture._colorTexture[3], color[3], message .. " (b)")
  end

  test("CreateCdTrackerRow places a slim hidden timeline inside the M+ timer box", function()
    local harness = BuildTimelineHarness()
    local timeline = harness.row.mpTimeline
    Assert.NotNil(timeline, "timer row must carry a timeline")
    Assert.Equal(timeline.track._height, 2, "timeline must stay a slim 2 px strip")
    Assert.Equal(timeline.track._points[1][1], "BOTTOMLEFT", "timeline must sit on the bottom edge")
    Assert.Equal(timeline.track._points[1][2], harness.row.mplusBox, "timeline must live inside the timer box")
    Assert.Equal(timeline.track._points[1][4], 2, "timeline must clear the box border on the left")
    Assert.Equal(timeline.track._points[2][4], -2, "timeline must clear the box border on the right")
    Assert.Equal(#timeline.ticks, 2, "timeline must mark the +3 and +2 cutoffs")
    Assert.False(timeline.track._shown, "timeline must stay hidden until a key runs")
    Assert.Equal(harness.row.mp3Text._width, 48, "timeline must not change the 48 px timer fields")
  end)

  test("UpdateCdTrackerRow draws elapsed time and cutoff ticks and emphasizes the reachable grade", function()
    local harness = BuildTimelineHarness()
    local row = harness.row
    local timeline = row.mpTimeline
    local Colors = harness.addon.UICommon.Colors

    harness.Render(BuildTimerSnapshot(540))
    Assert.True(timeline.track._shown, "timeline must show during a running key")
    Assert.Equal(timeline.fill._width, 60, "fill must cover 30% of the 200 px track at 540 of 1800 s")
    AssertColor(timeline.fill, Colors.MPLUS_GRADE3_FILL, "fill must use the +3 color while +3 is reachable")
    Assert.Equal(timeline.ticks[1]._points[1][4], 120, "+3 tick must sit at 60% of the track")
    Assert.Equal(timeline.ticks[2]._points[1][4], 160, "+2 tick must sit at 80% of the track")
    Assert.True(timeline.ticks[1]._shown and timeline.ticks[2]._shown, "cutoff ticks must be visible")
    Assert.Equal(row.mp3Text._alpha, 1, "reachable +3 time must stay at full opacity")
    Assert.Equal(row.mp3Icon._alpha, 1, "reachable +3 badge must stay at full opacity")
    Assert.Equal(row.mp2Text._alpha, 0.5, "+2 must be dimmed while +3 is still reachable")
    Assert.Equal(row.mp1Icon._alpha, 0.5, "+1 badge must be dimmed while +3 is still reachable")
    Assert.Nil(row.mp3Text._animGroup, "the first render must not flash a grade")

    harness.Render(BuildTimerSnapshot(1200))
    Assert.Equal(timeline.fill._width, 133, "fill must follow the elapsed time")
    AssertColor(timeline.fill, Colors.MPLUS_GRADE2_FILL, "fill must switch to the +2 color once +3 is missed")
    Assert.Equal(row.mp2Text._alpha, 1, "+2 must take the emphasis once +3 is missed")
    Assert.Equal(row.mp3Text._alpha, 0.5, "the missed +3 must be dimmed")
    Assert.Equal(row.mp2Text._animGroup.plays, 1, "a grade change must briefly fade the new grade in")

    harness.Render(BuildTimerSnapshot(1900))
    Assert.Equal(timeline.fill._width, 200, "fill must stop at the end of the track in overtime")
    AssertColor(timeline.fill, Colors.MPLUS_OVERTIME_FILL, "fill must turn red in overtime")
    Assert.Equal(row.mp1Text._alpha, 1, "the red +1 overshoot must stay emphasized in overtime")
    Assert.Equal(row.mp2Text._alpha, 0.5, "+2 must be dimmed in overtime")

    harness.Render(nil)
    Assert.False(timeline.track._shown, "timeline must hide without an active key")
    Assert.False(timeline.fill._shown, "timeline fill must hide without an active key")
    Assert.Equal(row.mp3Text._alpha, 1, "every grade must return to full opacity without a key")
    Assert.Equal(row.mp2Icon._alpha, 1, "every badge must return to full opacity without a key")
  end)

  test("UpdateCdTrackerRow re-anchors and repaints the timeline only when it changes", function()
    local harness = BuildTimelineHarness()
    local timeline = harness.row.mpTimeline
    local anchorWrites, colorWrites = 0, 0
    local function Count(texture)
      local originalSetPoint, originalPaint = texture.SetPoint, texture.SetColorTexture
      texture.SetPoint = function(...)
        anchorWrites = anchorWrites + 1
        return originalSetPoint(...)
      end
      texture.SetColorTexture = function(...)
        colorWrites = colorWrites + 1
        return originalPaint(...)
      end
    end
    Count(timeline.track)
    for _, tick in ipairs(timeline.ticks) do
      Count(tick)
    end

    for second = 540, 599 do
      harness.Render(BuildTimerSnapshot(second))
    end
    Assert.Equal(anchorWrites, #timeline.ticks, "a minute of timer ticks anchors each cutoff tick once")
    Assert.Equal(colorWrites, 1 + #timeline.ticks, "track and ticks are painted once, not every second")
    Assert.True(timeline.ticks[1]._shown and timeline.track._shown, "the timeline stays visible")

    harness.row.mplusBox._layoutWidth = 304
    harness.Render(BuildTimerSnapshot(600))
    Assert.Equal(anchorWrites, #timeline.ticks * 2, "a wider box re-anchors every cutoff tick")
    Assert.Equal(timeline.ticks[1]._points[#timeline.ticks[1]._points][4], 180, "+3 tick follows the new width")

    harness.Render(nil)
    harness.Render(BuildTimerSnapshot(601))
    Assert.True(timeline.ticks[1]._shown and timeline.track._shown, "a timeline hidden in between shows again")
  end)

  test("UpdateCdTrackerRow hides the timeline for snapshots without a usable limit", function()
    local harness = BuildTimelineHarness()
    local snapshot = BuildTimerSnapshot(300)
    snapshot.timeLimit = 0
    harness.Render(snapshot)
    Assert.False(harness.row.mpTimeline.track._shown, "a zero time limit must not draw a timeline")
    Assert.Equal(harness.row.mp3Text:GetText(), "13:00", "the text timers must still render")

    harness.row.mplusBox._layoutWidth = 0
    harness.Render(BuildTimerSnapshot(300))
    Assert.False(harness.row.mpTimeline.track._shown, "an unmeasured box must not draw a timeline")
  end)

  test("UpdateCdTrackerRow draws BR and BL cooldown swipes and greys out an empty BR", function()
    local harness = BuildTimelineHarness()
    local row = harness.row
    local now = 1000
    local bres = { charges = 0, maxCharges = 1, cooldownRemain = 112, cooldownDuration = 600 }
    local lust = { remain = 23, duration = 600 }
    local controller = {
      GetBResInfo = function()
        return bres
      end,
      GetLustInfo = function()
        return lust
      end,
    }
    local function Render()
      WithGlobals({
        GetTime = function()
          return now
        end,
      }, function()
        harness.addon._RosterInternal.UpdateCdTrackerRow(row, controller)
      end)
    end

    Assert.Equal(row.mpDeathIcon._isiLiveStateIcon, "death", "the timer death counter must use the death icon")
    Assert.Equal(row.bresCooldown._allPoints, row.bresIcon, "the BR swipe must cover the BR icon")
    Assert.True(row.bresCooldown._hideCountdownNumbers, "the swipe must not duplicate the printed time")

    Render()
    Assert.Equal(row.bresCooldown._cooldownCalls[1][1], 512, "BR swipe must start at now + remain - duration")
    Assert.Equal(row.bresCooldown._cooldownCalls[1][2], 600, "BR swipe must span the full recharge")
    Assert.Equal(row.lustCooldown._cooldownCalls[1][1], 423, "BL swipe must start at now + remain - duration")
    Assert.True(row.bresIcon._desaturated, "an empty BR must grey out its icon")
    Assert.Equal(row.bresText:GetText(), "0/1  1:52", "BR text must stay unchanged")

    now = 1001
    bres.cooldownRemain = 111
    lust.remain = 22
    Render()
    Assert.Equal(#row.bresCooldown._cooldownCalls, 1, "an unchanged end time must not restart the BR swipe")
    Assert.Equal(#row.lustCooldown._cooldownCalls, 1, "an unchanged end time must not restart the BL swipe")

    bres = { charges = 1, maxCharges = 1, cooldownRemain = 0 }
    lust = nil
    Render()
    Assert.Equal(row.bresCooldown._cooldownCalls[2][2], 0, "a recharged BR must clear its swipe")
    Assert.False(row.bresIcon._desaturated, "a recharged BR must restore its icon colors")
    Assert.Equal(row.lustCooldown._cooldownCalls[2][2], 0, "missing BL context must clear its swipe")
    Assert.Equal(row.lustText:GetText(), "BL: --", "missing BL context keeps its reserved placeholder")

    Render()
    Assert.Equal(#row.bresCooldown._cooldownCalls, 2, "an already cleared swipe must not be cleared again")
  end)

  test("UpdateCdTrackerRow grade change skips the fade when reduced motion is enabled", function()
    local db = { reduceMotion = true }
    local harness = BuildTimelineHarness({ IsiLiveDB = db })
    WithGlobals({ IsiLiveDB = db }, function()
      harness.Render(BuildTimerSnapshot(540))
      harness.Render(BuildTimerSnapshot(1200))
    end)
    Assert.Equal(harness.row.mp2Text._alpha, 1, "emphasis itself must not depend on the motion setting")
    Assert.Nil(harness.row.mp2Text._animGroup, "reduced motion must skip the grade fade")
  end)
end
