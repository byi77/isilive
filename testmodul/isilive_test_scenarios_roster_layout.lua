---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  local function loadRI()
    return LoadAddonModules({ "isiLive_roster_layout.lua" })._RosterInternal
  end

  local function loadRIWithUICommon()
    return LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_roster_layout.lua" })._RosterInternal
  end

  local function loadChromeRIWithUICommon()
    return LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_roster_panel_chrome.lua" })._RosterInternal
  end

  test("RosterLayout system option watcher owns ticker only while main frame is visible", function()
    local watcher
    local ticker
    local mainShown = true
    WithGlobals({
      CreateFrame = function()
        watcher = {
          scripts = {},
          SetScript = function(self, name, fn)
            self.scripts[name] = fn
          end,
        }
        return watcher
      end,
      C_Timer = {
        NewTicker = function(interval, callback)
          Assert.Equal(interval, 5, "system option watcher must use a five-second ticker")
          ticker = {
            callback = callback,
            cancelled = false,
            Cancel = function(self)
              self.cancelled = true
            end,
          }
          return ticker
        end,
      },
    }, function()
      local RI = loadRI()
      local mainFrame = {
        IsShown = function()
          return mainShown
        end,
      }
      local ui = {}

      RI.AttachSystemOptionToggleWatcher(mainFrame, ui)
      Assert.NotNil(ticker, "visible main frame must start the owned ticker")
      Assert.Nil(watcher.scripts.OnUpdate, "watcher must not poll once per render frame")

      mainShown = false
      watcher.scripts.OnHide()
      Assert.True(ticker.cancelled, "hiding the main frame must cancel the owned ticker")
      Assert.Nil(watcher._isiLiveTicker, "hidden watcher must release its ticker handle")
    end)
  end)

  -- NormalizeLayoutMode

  test("RosterLayout NormalizeLayoutMode maps nil to expanded", function()
    local RI = loadRI()
    Assert.Equal(RI.NormalizeLayoutMode(nil), RI.LAYOUT_MODE_EXPANDED)
  end)

  test("RosterLayout NormalizeLayoutMode maps unknown string to expanded", function()
    local RI = loadRI()
    Assert.Equal(RI.NormalizeLayoutMode("not_a_real_mode"), RI.LAYOUT_MODE_EXPANDED)
  end)

  test("RosterLayout NormalizeLayoutMode returns compact_vertical unchanged", function()
    local RI = loadRI()
    Assert.Equal(RI.NormalizeLayoutMode(RI.LAYOUT_MODE_COMPACT_VERTICAL), RI.LAYOUT_MODE_COMPACT_VERTICAL)
  end)

  test("RosterLayout NormalizeLayoutMode returns compact_horizontal unchanged", function()
    local RI = loadRI()
    Assert.Equal(RI.NormalizeLayoutMode(RI.LAYOUT_MODE_COMPACT_HORIZONTAL), RI.LAYOUT_MODE_COMPACT_HORIZONTAL)
  end)

  test("RosterLayout NormalizeLayoutMode returns compact_main_horizontal unchanged", function()
    local RI = loadRI()
    Assert.Equal(RI.NormalizeLayoutMode(RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL), RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL)
  end)

  test("RosterLayout NormalizeLayoutMode migrates legacy compact_horizontal_2 to compact_main_horizontal", function()
    local RI = loadRI()
    Assert.Equal(RI.NormalizeLayoutMode("compact_horizontal_2"), RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL)
  end)

  -- IsCompactLayoutMode

  test("RosterLayout IsCompactLayoutMode returns true for compact_vertical", function()
    local RI = loadRI()
    Assert.True(RI.IsCompactLayoutMode(RI.LAYOUT_MODE_COMPACT_VERTICAL))
  end)

  test("RosterLayout IsCompactLayoutMode returns true for compact_horizontal", function()
    local RI = loadRI()
    Assert.True(RI.IsCompactLayoutMode(RI.LAYOUT_MODE_COMPACT_HORIZONTAL))
  end)

  test("RosterLayout IsCompactLayoutMode returns false for expanded", function()
    local RI = loadRI()
    Assert.False(RI.IsCompactLayoutMode(RI.LAYOUT_MODE_EXPANDED))
  end)

  test("RosterLayout IsCompactLayoutMode returns false for compact_main_horizontal", function()
    local RI = loadRI()
    Assert.False(
      RI.IsCompactLayoutMode(RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL),
      "M2 mode uses its own toolbar row — IsCompactLayoutMode must not include it"
    )
  end)

  -- IsHorizontalCompactLayoutMode

  test("RosterLayout IsHorizontalCompactLayoutMode returns true only for compact_horizontal", function()
    local RI = loadRI()
    Assert.True(RI.IsHorizontalCompactLayoutMode(RI.LAYOUT_MODE_COMPACT_HORIZONTAL))
    Assert.False(RI.IsHorizontalCompactLayoutMode(RI.LAYOUT_MODE_COMPACT_VERTICAL))
    Assert.False(RI.IsHorizontalCompactLayoutMode(RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL))
    Assert.False(RI.IsHorizontalCompactLayoutMode(RI.LAYOUT_MODE_EXPANDED))
  end)

  -- IsMainHorizontalLayoutMode

  test("RosterLayout IsMainHorizontalLayoutMode returns true only for compact_main_horizontal", function()
    local RI = loadRI()
    Assert.True(RI.IsMainHorizontalLayoutMode(RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL))
    Assert.False(RI.IsMainHorizontalLayoutMode(RI.LAYOUT_MODE_COMPACT_HORIZONTAL))
    Assert.False(RI.IsMainHorizontalLayoutMode(RI.LAYOUT_MODE_COMPACT_VERTICAL))
    Assert.False(RI.IsMainHorizontalLayoutMode(RI.LAYOUT_MODE_EXPANDED))
  end)

  test("RosterLayout IsMainHorizontalLayoutMode accepts legacy compact_horizontal_2 alias", function()
    local RI = loadRI()
    Assert.True(
      RI.IsMainHorizontalLayoutMode("compact_horizontal_2"),
      "legacy alias must resolve to compact_main_horizontal"
    )
  end)

  -- IsHorizontalToolbarLayoutMode

  test(
    "RosterLayout IsHorizontalToolbarLayoutMode returns true for compact_horizontal and compact_main_horizontal",
    function()
      local RI = loadRI()
      Assert.True(RI.IsHorizontalToolbarLayoutMode(RI.LAYOUT_MODE_COMPACT_HORIZONTAL))
      Assert.True(RI.IsHorizontalToolbarLayoutMode(RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL))
      Assert.False(RI.IsHorizontalToolbarLayoutMode(RI.LAYOUT_MODE_COMPACT_VERTICAL))
      Assert.False(RI.IsHorizontalToolbarLayoutMode(RI.LAYOUT_MODE_EXPANDED))
    end
  )

  -- GetFrameWidthForLayoutMode

  test("RosterLayout GetFrameWidthForLayoutMode returns full width for expanded", function()
    local RI = loadRI()
    Assert.Equal(RI.GetFrameWidthForLayoutMode(RI.LAYOUT_MODE_EXPANDED), RI.FULL_FRAME_WIDTH)
  end)

  test("RosterLayout GetFrameWidthForLayoutMode returns mini width for compact_vertical", function()
    local RI = loadRI()
    Assert.Equal(RI.GetFrameWidthForLayoutMode(RI.LAYOUT_MODE_COMPACT_VERTICAL), RI.MINI_FRAME_WIDTH)
  end)

  test("RosterLayout GetFrameWidthForLayoutMode returns mini horizontal width for compact_horizontal", function()
    local RI = loadRI()
    Assert.Equal(RI.GetFrameWidthForLayoutMode(RI.LAYOUT_MODE_COMPACT_HORIZONTAL), RI.MINI_HORIZONTAL_FRAME_WIDTH)
  end)

  test("RosterLayout GetFrameWidthForLayoutMode returns M2 width for compact_main_horizontal", function()
    local RI = loadRI()
    Assert.Equal(
      RI.GetFrameWidthForLayoutMode(RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL),
      RI.MINI_MAIN_HORIZONTAL_FRAME_WIDTH
    )
  end)

  test("RosterLayout GetFrameWidthForLayoutMode falls back to full width for unknown mode", function()
    local RI = loadRI()
    Assert.Equal(RI.GetFrameWidthForLayoutMode("unknown"), RI.FULL_FRAME_WIDTH)
  end)

  -- GetFrameHeightForLayoutMode

  test("RosterLayout GetFrameHeightForLayoutMode returns fixed mini height for compact_horizontal", function()
    local RI = loadRI()
    Assert.Equal(RI.GetFrameHeightForLayoutMode(RI.LAYOUT_MODE_COMPACT_HORIZONTAL), RI.MINI_HORIZONTAL_FRAME_HEIGHT)
  end)

  test(
    "RosterLayout GetFrameHeightForLayoutMode returns at least 272 for compact_main_horizontal with default min",
    function()
      local RI = loadRI()
      -- MINI_MAIN_HORIZONTAL_MIN_HEIGHT (244) + 28 = 272 when default minFrameHeight (236) is below the minimum
      local height = RI.GetFrameHeightForLayoutMode(RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL, nil)
      Assert.True(height >= 272, "M2 height must be at least MINI_MAIN_HORIZONTAL_MIN_HEIGHT + 28")
    end
  )

  test("RosterLayout GetFrameHeightForLayoutMode respects larger minFrameHeight for compact_main_horizontal", function()
    local RI = loadRI()
    local height = RI.GetFrameHeightForLayoutMode(RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL, 300)
    Assert.Equal(height, 328, "M2 height must be max(300, 244) + 28 = 328")
  end)

  test("RosterLayout GetFrameHeightForLayoutMode ignores minFrameHeight below M2 minimum", function()
    local RI = loadRI()
    local height = RI.GetFrameHeightForLayoutMode(RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL, 100)
    Assert.Equal(height, 272, "M2 height must clamp to MINI_MAIN_HORIZONTAL_MIN_HEIGHT (244) + 28 = 272")
  end)

  test("RosterLayout GetFrameHeightForLayoutMode returns default min for expanded mode", function()
    local RI = loadRI()
    Assert.Equal(
      RI.GetFrameHeightForLayoutMode(RI.LAYOUT_MODE_EXPANDED, nil),
      RI.DEFAULT_MIN_FRAME_HEIGHT,
      "expanded mode height must equal DEFAULT_MIN_FRAME_HEIGHT when no override given"
    )
  end)

  test("RosterLayout GetFrameHeightForLayoutMode honours custom min for expanded mode", function()
    local RI = loadRI()
    Assert.Equal(RI.GetFrameHeightForLayoutMode(RI.LAYOUT_MODE_EXPANDED, 400), 400)
  end)

  local function NewFlatButtonFitStub(width, baseSize)
    local label = {}
    local button = { _flatLabel = label }
    local currentText = ""
    local currentSize = baseSize or 12
    local fontCalls = {}

    function button:GetWidth()
      return width
    end

    function button:SetText(text)
      self.buttonText = tostring(text or "")
    end

    function label:SetText(text)
      currentText = tostring(text or "")
    end

    function label:SetWidth(nextWidth)
      self.width = nextWidth
    end

    function label:SetWordWrap(value)
      self.wordWrap = value
    end

    function label:SetNonSpaceWrap(value)
      self.nonSpaceWrap = value
    end

    function label:GetFont()
      return "Fonts\\FRIZQT__.TTF", currentSize, "OUTLINE"
    end

    function label:SetFont(path, size, flags)
      currentSize = size
      fontCalls[#fontCalls + 1] = { path = path, size = size, flags = flags }
    end

    function label:GetStringWidth()
      return #currentText * currentSize
    end

    return button, label, fontCalls, function()
      return currentSize
    end
  end

  test("RosterLayout SetFlatButtonText keeps short labels at the base font size", function()
    local RI = loadRI()
    local button, label, _, getSize = NewFlatButtonFitStub(120, 12)

    RI.SetFlatButtonText(button, "Ready")

    Assert.Equal(label.width, 116, "label width should match button width minus padding")
    Assert.Equal(getSize(), 12, "short labels should stay at the base font size")
    Assert.False(label.wordWrap, "flat button labels must not word-wrap")
    Assert.False(label.nonSpaceWrap, "flat button labels must not non-space-wrap")
    Assert.Equal(button.buttonText, "Ready", "native button text mirrors the visible label")
  end)

  test("RosterLayout SetFlatButtonText shrinks long labels down to the minimum fit size", function()
    local RI = loadRI()
    local button, _, _, getSize = NewFlatButtonFitStub(100, 12)

    RI.SetFlatButtonText(button, "Поделиться ключами")

    Assert.Equal(getSize(), 8, "long labels should shrink to the minimum readable fit size")
  end)

  test("RosterLayout SetFlatButtonText resets a previously shrunken label before refitting", function()
    local RI = loadRI()
    local button, _, _, getSize = NewFlatButtonFitStub(100, 12)

    RI.SetFlatButtonText(button, "Поделиться ключами")
    Assert.Equal(getSize(), 8, "setup should shrink the long label")

    RI.SetFlatButtonText(button, "OK")
    Assert.Equal(getSize(), 12, "short follow-up labels should restore the base font size")
  end)

  test("RosterLayout SetFlatButtonText uses ruRU font override before fitting Cyrillic labels", function()
    WithGlobals({
      IsiLiveDB = { locale = "ruRU" },
    }, function()
      local RI = loadRIWithUICommon()
      local button, _, fontCalls = NewFlatButtonFitStub(120, 12)

      RI.SetFlatButtonText(button, "Готовность")

      Assert.True(#fontCalls > 0, "font fitting must call SetFont")
      Assert.Equal(fontCalls[1].path, "Fonts\\ARIALN.TTF", "first fit pass must use the ruRU override font")
    end)
  end)

  test("RosterLayout SetPanelHeaderText fits ruRU headers to fixed roster columns", function()
    WithGlobals({
      IsiLiveDB = { locale = "ruRU" },
    }, function()
      local RI = loadChromeRIWithUICommon()
      local currentText = ""
      local currentSize = 12
      local fontCalls = {}
      local function CountCodepoints(text)
        local count = 0
        for i = 1, #text do
          local byte = string.byte(text, i)
          if byte < 128 or byte >= 192 then
            count = count + 1
          end
        end
        return count
      end
      local header = {
        _isiLiveHeaderWidth = 40,
        SetWordWrap = function(self, value)
          self.wordWrap = value
        end,
        SetNonSpaceWrap = function(self, value)
          self.nonSpaceWrap = value
        end,
        SetMaxLines = function(self, value)
          self.maxLines = value
        end,
        GetFont = function()
          return "Fonts\\FRIZQT__.TTF", currentSize, "OUTLINE"
        end,
        SetFont = function(_self, path, size, flags)
          currentSize = size
          fontCalls[#fontCalls + 1] = { path = path, size = size, flags = flags }
        end,
        SetText = function(_self, value)
          currentText = tostring(value or "")
        end,
        GetStringWidth = function()
          return CountCodepoints(currentText) * currentSize
        end,
      }

      RI.SetPanelHeaderText(header, "Исключить")

      Assert.Equal(currentText, "Исключить", "header text should keep the localized value")
      Assert.False(header.wordWrap, "header labels must not wrap into the roster row")
      Assert.False(header.nonSpaceWrap, "header labels must not non-space-wrap")
      Assert.Equal(header.maxLines, 1, "header labels must stay single-line")
      local usedRuFont = false
      for _, call in ipairs(fontCalls) do
        if call.path == "Fonts\\ARIALN.TTF" then
          usedRuFont = true
        end
      end
      Assert.True(usedRuFont, "ruRU header fitting must use the Cyrillic font")
      Assert.Equal(currentSize, 8, "long ruRU headers should shrink to the readable minimum")

      RI.SetPanelHeaderText(header, "Кик")
      Assert.Equal(currentSize, 12, "short follow-up headers should restore the base font size")
    end)
  end)
end
