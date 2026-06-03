---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

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
    Assert.True(
      row.mpDeathText:GetText():find("(+30s)", 1, true) ~= nil,
      "death cell must include both deaths and deathTimeLost penalty"
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
