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
    Assert.Equal(row.mp3Icon._size[1], 20, "+3 badge must be wider than the old ellipsizing 16px")
    Assert.Equal(row.mp2Icon._size[1], 20, "+2 badge must be wider than the old ellipsizing 16px")
    Assert.Equal(row.mp1Icon._size[1], 20, "+1 badge must be wider than the old ellipsizing 16px")
    Assert.Equal(row.mp3Text._width, 48, "+3 timer must fit five-character M+ times")
    Assert.Equal(row.mp2Text._width, 48, "+2 timer must fit five-character M+ times")
    Assert.Equal(row.mp1Text._width, 48, "+1 timer must fit five-character M+ times")
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
end
