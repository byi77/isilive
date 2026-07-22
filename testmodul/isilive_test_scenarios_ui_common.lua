---@diagnostic disable: undefined-global

-- Branch-coverage scenarios for ui/isiLive_ui_common.lua. Targets the
-- GetLocalizedText / GetBackgroundAlpha / ApplyBgAlpha / ApplyBackdrop
-- helpers and the CreatePrivateTooltip + PreparePrivateTooltip + Hide
-- pipeline, which together account for the bulk of the file's
-- previously-uncovered branches.

local function MakeFontStringStub()
  local fs = { _text = "", _shown = false }
  function fs:SetText(text)
    self._text = tostring(text or "")
  end
  function fs:GetText()
    return self._text
  end
  function fs:SetWidth() end
  function fs:SetJustifyH() end
  function fs:SetJustifyV() end
  function fs:SetWordWrap() end
  function fs:SetNonSpaceWrap() end
  function fs:SetMaxLines() end
  function fs:SetTextColor() end
  function fs:SetFont(path, size, flags)
    self._fontPath = path
    self._fontSize = size
    self._fontFlags = flags
  end
  function fs:GetFont()
    return self._fontPath or "Fonts\\\\X.TTF", self._fontSize or 12, self._fontFlags or "OUTLINE"
  end
  function fs:SetPoint() end
  function fs:ClearAllPoints() end
  function fs:Show()
    self._shown = true
  end
  function fs:Hide()
    self._shown = false
  end
  function fs:GetStringHeight()
    return 14
  end
  return fs
end

local function MakeFrameStub()
  local frame = {
    _shown = false,
    _backdrop = nil,
    _backdropColor = nil,
    _borderColor = nil,
    _points = {},
    _scripts = {},
    _attrs = {},
  }
  function frame:Show()
    self._shown = true
  end
  function frame:Hide()
    self._shown = false
  end
  function frame:IsShown()
    return self._shown == true
  end
  function frame:SetBackdrop(b)
    self._backdrop = b
  end
  function frame:SetBackdropColor(r, g, b, a)
    self._backdropColor = { r, g, b, a }
  end
  function frame:SetBackdropBorderColor(r, g, b, a)
    self._borderColor = { r, g, b, a }
  end
  function frame:SetPoint(...)
    table.insert(self._points, { ... })
  end
  function frame:ClearAllPoints()
    self._points = {}
  end
  function frame:SetSize() end
  function frame:SetWidth() end
  function frame:SetHeight() end
  function frame:SetFrameStrata() end
  function frame:SetFrameLevel() end
  function frame:SetScript(name, fn)
    self._scripts[name] = fn
  end
  function frame:GetEffectiveScale()
    return 1
  end
  function frame:CreateFontString()
    return MakeFontStringStub()
  end
  function frame:CreateTexture()
    local tex = { _points = {} }
    function tex:SetAllPoints()
      self._allPoints = true
    end
    function tex:SetPoint(...)
      table.insert(self._points, { ... })
    end
    function tex:ClearAllPoints()
      self._points = {}
      self._allPoints = false
    end
    function tex:SetTexture(texture)
      self._texture = texture
    end
    function tex:SetTexCoord(...)
      self._texCoord = { ... }
    end
    function tex:SetBlendMode(mode)
      self._blendMode = mode
    end
    function tex:SetAlpha(alpha)
      self._alpha = alpha
    end
    function tex:SetColorTexture(...)
      self._colorTexture = { ... }
    end
    function tex:Hide() end
    function tex:Show() end
    return tex
  end
  return frame
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function LoadUICommon(globals)
    local addon
    WithGlobals(globals or {}, function()
      addon = LoadAddonModules({ "isiLive_ui_common.lua" })
    end)
    return addon.UICommon, addon
  end

  -- GetLocalizedText -----------------------------------------------------------

  test("UICommon.GetLocalizedText returns the localized string when the key exists in the resolved locale", function()
    -- GetLocale is read lazily inside GetLocalizedText, so the call must happen
    -- inside the WithGlobals scope where the override is still active.
    WithGlobals({
      GetLocale = function()
        return "deDE"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      addon.Texts = {
        GetLocaleTables = function()
          return {
            enUS = { TEST_KEY = "Test EN" },
            deDE = { TEST_KEY = "Test DE" },
          }
        end,
      }
      Assert.Equal(addon.UICommon.GetLocalizedText("TEST_KEY", "fb"), "Test DE", "deDE locale must win over enUS")
    end)
  end)

  test("UICommon.GetLocalizedText falls back to enUS when the resolved locale is missing", function()
    WithGlobals({
      GetLocale = function()
        return "ruRU" -- no ruRU table → fall back to enUS
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      addon.Texts = {
        GetLocaleTables = function()
          return {
            enUS = { TEST_KEY = "Test EN" },
          }
        end,
      }
      Assert.Equal(
        addon.UICommon.GetLocalizedText("TEST_KEY", "fb"),
        "Test EN",
        "missing locale must fall back to enUS"
      )
    end)
  end)

  test("UICommon.GetLocalizedText returns the fallback when the key is missing", function()
    local UICommon, addon = LoadUICommon()
    addon.Texts = {
      GetLocaleTables = function()
        return { enUS = {} }
      end,
    }
    Assert.Equal(UICommon.GetLocalizedText("MISSING", "fallback"), "fallback", "missing key returns fallback")
  end)

  test("UICommon.GetLocalizedText returns fallback for non-string or empty key input", function()
    local UICommon = LoadUICommon()
    Assert.Equal(UICommon.GetLocalizedText(nil, "fb"), "fb", "nil key returns fallback")
    Assert.Equal(UICommon.GetLocalizedText("", "fb"), "fb", "empty key returns fallback")
    Assert.Equal(UICommon.GetLocalizedText(nil, nil), "", "nil key + nil fallback returns empty string")
  end)

  test("UICommon.GetLocalizedText returns fallback when addonTable.Texts is absent", function()
    local UICommon = LoadUICommon()
    -- addon.Texts intentionally not set
    Assert.Equal(UICommon.GetLocalizedText("KEY", "fb"), "fb", "missing Texts module must fall back")
  end)

  test("UICommon.ApplyLocaleFont uses Cyrillic-capable font for ruRU addon locale", function()
    WithGlobals({
      IsiLiveDB = { locale = "ruRU" },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      local captured
      local fontString = {
        GetFont = function()
          return "Fonts\\FRIZQT__.TTF", 12, "OUTLINE"
        end,
        SetFont = function(_, path, size, flags)
          captured = { path = path, size = size, flags = flags }
        end,
      }

      Assert.True(addon.UICommon.ApplyLocaleFont(fontString), "ruRU locale must apply a font override")
      Assert.Equal(captured.path, "Fonts\\ARIALN.TTF", "ruRU must use a Cyrillic-capable WoW font")
      Assert.Equal(captured.size, 12, "font size must be preserved")
      Assert.Equal(captured.flags, "OUTLINE", "font flags must be preserved")
    end)
  end)

  test("UICommon.ApplyLocaleFont leaves non-overridden locales unchanged", function()
    WithGlobals({
      IsiLiveDB = { locale = "enUS" },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      local setCalls = 0
      local fontString = {
        GetFont = function()
          return "Fonts\\FRIZQT__.TTF", 12, "OUTLINE"
        end,
        SetFont = function()
          setCalls = setCalls + 1
        end,
      }

      Assert.False(addon.UICommon.ApplyLocaleFont(fontString), "enUS must not apply a locale font override")
      Assert.Equal(setCalls, 0, "non-overridden locale must not rewrite font")
    end)
  end)

  test("UICommon.ApplyReadableFontForText uses Cyrillic-capable font for Cyrillic payload text", function()
    WithGlobals({
      IsiLiveDB = { locale = "enUS" },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      local captured
      local fontString = {
        GetFont = function()
          return "Fonts\\FRIZQT__.TTF", 13, "OUTLINE"
        end,
        SetFont = function(_, path, size, flags)
          captured = { path = path, size = size, flags = flags }
        end,
      }

      Assert.True(
        addon.UICommon.ApplyReadableFontForText(fontString, "\208\157\208\184\209\129\208\176\208\189-Realm"),
        "Cyrillic payload text must apply a font override"
      )
      Assert.Equal(captured.path, "Fonts\\ARIALN.TTF", "Cyrillic payload text must use a Cyrillic-capable font")
      Assert.Equal(captured.size, 13, "font size must be preserved")
      Assert.Equal(captured.flags, "OUTLINE", "font flags must be preserved")
    end)
  end)

  test("UICommon.ApplyReadableFontForText restores the baseline font after Cyrillic payload text clears", function()
    WithGlobals({
      IsiLiveDB = { locale = "enUS" },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      local fontPath = "Fonts\\FRIZQT__.TTF"
      local fontString = {
        GetFont = function()
          return fontPath, 12, ""
        end,
        SetFont = function(_, path)
          fontPath = path
        end,
      }

      Assert.True(
        addon.UICommon.ApplyReadableFontForText(fontString, "\208\155\208\184\208\180\208\181\209\128"),
        "Cyrillic payload text must switch fonts"
      )
      Assert.Equal(fontPath, "Fonts\\ARIALN.TTF", "setup should switch to Cyrillic-capable font")

      Assert.True(
        addon.UICommon.ApplyReadableFontForText(fontString, "Leader-Realm"),
        "ASCII payload text should restore the recorded baseline font"
      )
      Assert.Equal(fontPath, "Fonts\\FRIZQT__.TTF", "ASCII payload should restore the original font path")
    end)
  end)

  test("UICommon.SetReadableText applies Cyrillic-capable font before writing Cyrillic text", function()
    WithGlobals({
      IsiLiveDB = { locale = "enUS" },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      local fontString = MakeFontStringStub()

      Assert.True(
        addon.UICommon.SetReadableText(fontString, "\208\159\208\184\208\189\209\130\208\190"),
        "SetReadableText should report a successful write"
      )
      Assert.Equal(fontString._text, "\208\159\208\184\208\189\209\130\208\190", "text must be written")
      Assert.Equal(fontString._fontPath, "Fonts\\ARIALN.TTF", "Cyrillic text must use a readable font")
    end)
  end)

  test("UICommon private tooltip lines use Cyrillic-capable font for Cyrillic payload text", function()
    WithGlobals({
      UIParent = MakeFrameStub(),
      CreateFrame = function()
        return MakeFrameStub()
      end,
      IsiLiveDB = { locale = "enUS" },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      local tooltip = addon.UICommon.CreatePrivateTooltip(UIParent)
      addon.UICommon.PreparePrivateTooltip(tooltip, UIParent, "ANCHOR_CURSOR")
      tooltip:SetText("\208\155\208\184\208\180\208\181\209\128", 1, 1, 1)

      Assert.Equal(
        tooltip._isiLiveTooltipLines[1]._fontPath,
        "Fonts\\ARIALN.TTF",
        "private tooltip titles must switch to a Cyrillic-capable font"
      )
    end)
  end)

  -- GetBackgroundAlpha ---------------------------------------------------------

  test("UICommon.GetBackgroundAlpha reads the configured value from IsiLiveDB", function()
    rawset(_G, "IsiLiveDB", { bgAlpha = 0.42 })
    local UICommon = LoadUICommon()
    Assert.Equal(UICommon.GetBackgroundAlpha(), 0.42, "must read bgAlpha from IsiLiveDB")
    rawset(_G, "IsiLiveDB", nil)
  end)

  test("UICommon.GetBackgroundAlpha returns DEFAULT_BG_ALPHA when IsiLiveDB is missing or has wrong type", function()
    rawset(_G, "IsiLiveDB", nil)
    local UICommon = LoadUICommon()
    Assert.Equal(UICommon.GetBackgroundAlpha(), UICommon.DEFAULT_BG_ALPHA, "missing IsiLiveDB returns default")

    rawset(_G, "IsiLiveDB", { bgAlpha = "not-a-number" })
    Assert.Equal(UICommon.GetBackgroundAlpha(), UICommon.DEFAULT_BG_ALPHA, "non-numeric bgAlpha returns default")
    rawset(_G, "IsiLiveDB", nil)
  end)

  -- ApplyBgAlpha ---------------------------------------------------------------

  test("UICommon.ApplyBgAlpha writes the alpha into the BG_PRIMARY palette + the main/panel/settings frames", function()
    local UICommon = LoadUICommon()
    local mainFrame = MakeFrameStub()
    local panelFrame = MakeFrameStub()
    local settingsCanvas = MakeFrameStub()
    UICommon.ApplyBgAlpha({
      mainFrame = mainFrame,
      panelFrame = panelFrame,
      settingsCanvas = settingsCanvas,
    }, 0.7)

    Assert.Equal(UICommon.Colors.BG_PRIMARY[4], 0.7, "BG_PRIMARY[4] must mutate to the new alpha")
    Assert.Equal(mainFrame._backdropColor[4], 0.7, "mainFrame must receive the new alpha")
    Assert.Equal(panelFrame._backdropColor[4], 0.7, "panelFrame must receive the new alpha")
    Assert.Equal(settingsCanvas._backdropColor[4], 0.7, "settingsCanvas must receive the new alpha")
  end)

  test("UICommon.ApplyBgAlpha returns silently for non-number alpha", function()
    local UICommon = LoadUICommon()
    -- Must not throw.
    UICommon.ApplyBgAlpha({}, "not-a-number")
    UICommon.ApplyBgAlpha({}, nil)
  end)

  test("UICommon.ApplyBgAlpha tolerates a missing frames table", function()
    local UICommon = LoadUICommon()
    -- Must not throw when frames is nil.
    UICommon.ApplyBgAlpha(nil, 0.5)
    Assert.Equal(UICommon.Colors.BG_PRIMARY[4], 0.5, "palette must mutate even without frames")
  end)

  -- ApplyBackdrop --------------------------------------------------------------

  test("UICommon.ApplyBackdrop applies preset backdrop + bg + border colors when both setters exist", function()
    local UICommon = LoadUICommon()
    local frame = MakeFrameStub()
    local ok = UICommon.ApplyBackdrop(frame, "CD_BOX")
    Assert.True(ok, "ApplyBackdrop must report success for known preset")
    Assert.NotNil(frame._backdrop, "SetBackdrop must be called")
    Assert.NotNil(frame._backdropColor, "SetBackdropColor must be called for the preset bg")
    Assert.NotNil(frame._borderColor, "SetBackdropBorderColor must be called for the preset border")
  end)

  test("UICommon.ApplyBackdrop returns false for nil frame or frames without SetBackdrop", function()
    local UICommon = LoadUICommon()
    Assert.False(UICommon.ApplyBackdrop(nil, "CD_BOX"), "nil frame must short-circuit to false")
    Assert.False(UICommon.ApplyBackdrop({}, "CD_BOX"), "frame without SetBackdrop must short-circuit to false")
  end)

  test("UICommon.ApplyBackdrop returns false for unknown preset name", function()
    local UICommon = LoadUICommon()
    Assert.False(
      UICommon.ApplyBackdrop(MakeFrameStub(), "DOES_NOT_EXIST"),
      "unknown preset name must short-circuit to false"
    )
  end)

  test("UICommon.CreateRedCloseButton renders themed WoW close art", function()
    WithGlobals({
      CreateFrame = function()
        return MakeFrameStub()
      end,
      UIParent = MakeFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      local parent = MakeFrameStub()
      local button = addon.UICommon.CreateRedCloseButton(parent, { size = 22 })

      local art = Assert.NotNil(button._isiLiveCloseButtonArt, "close button should expose its themed art")
      Assert.Equal(button._borderColor[1], 1.0, "close button border should use a gold red channel")
      Assert.Equal(button._borderColor[2], 0.68, "close button border should use a warm gold green channel")
      Assert.Equal(
        art.icon._texture,
        "Interface\\Buttons\\UI-Panel-MinimizeButton-Up",
        "close button should use WoW panel close art"
      )
      Assert.Equal(
        art.highlight._texture,
        "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight",
        "close button should include WoW highlight art"
      )

      button._scripts.OnMouseDown()
      Assert.Equal(
        art.icon._texture,
        "Interface\\Buttons\\UI-Panel-MinimizeButton-Down",
        "pressed state should swap to WoW down art"
      )

      button._scripts.OnLeave()
      Assert.Equal(
        art.icon._texture,
        "Interface\\Buttons\\UI-Panel-MinimizeButton-Up",
        "leave state should restore normal art"
      )
    end)
  end)

  -- Private tooltip pipeline ---------------------------------------------------

  test("UICommon.CreatePrivateTooltip + PreparePrivateTooltip + HidePrivateTooltip pipeline renders + hides", function()
    -- CreateFrame is needed to construct the tooltip frame; it returns a fresh
    -- MakeFrameStub() each call so the captured tooltip behaves like a frame.
    WithGlobals({
      CreateFrame = function()
        return MakeFrameStub()
      end,
      UIParent = MakeFrameStub(),
      GetCursorPosition = function()
        return 100, 200
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      local UICommon = addon.UICommon

      local parent = MakeFrameStub()
      local tooltip = UICommon.CreatePrivateTooltip(parent)
      Assert.True(type(tooltip) == "table", "tooltip must be a table")
      Assert.True(type(tooltip.SetText) == "function", "tooltip exposes SetText (provided by EnsurePrivateTooltipAPI)")
      Assert.True(type(tooltip.AddLine) == "function", "tooltip exposes AddLine")
      Assert.True(type(tooltip.SetOwner) == "function", "tooltip exposes SetOwner")

      local owner = MakeFrameStub()
      UICommon.PreparePrivateTooltip(tooltip, owner, "ANCHOR_BOTTOM")
      tooltip:SetText("Header", 1, 1, 1)
      tooltip:AddLine("Body line", 0.8, 0.8, 0.8, true)
      tooltip:Show()

      Assert.True(tooltip._shown == true, "tooltip must be visible after Show()")
      Assert.Equal(tooltip._isiLiveTooltipLineCount, 2, "two lines (header + body) recorded")

      -- Hide pipeline must not throw and must clear the visible flag.
      UICommon.HidePrivateTooltip(tooltip)
      Assert.True(tooltip._shown == false, "tooltip must be hidden after HidePrivateTooltip")
    end)
  end)

  test("UICommon.HidePrivateTooltip is a no-op for non-table input", function()
    local UICommon = LoadUICommon()
    -- Must not throw.
    UICommon.HidePrivateTooltip(nil)
    UICommon.HidePrivateTooltip("not-a-table")
  end)

  test("UICommon.PreparePrivateTooltip is a no-op for non-table tooltip input", function()
    local UICommon = LoadUICommon()
    UICommon.PreparePrivateTooltip(nil, MakeFrameStub())
    UICommon.PreparePrivateTooltip("not-a-table", MakeFrameStub())
  end)

  -- UICommon.Colors ------------------------------------------------------------
  -- Guards the 2026-07-22 UI color-token consolidation: every entry must be a
  -- well-formed RGB(A) tuple, and no two keys may carry the exact same value
  -- -- a new token should always reuse an existing exact match instead of
  -- duplicating it (see the token catalog comment in isiLive_ui_common.lua).

  test("UICommon.Colors entries are well-formed RGB or RGBA tuples with values in [0, 1]", function()
    local UICommon = LoadUICommon()
    for name, color in pairs(UICommon.Colors) do
      Assert.True(type(color) == "table", "Colors." .. name .. " must be a table")
      local count = #color
      Assert.True(count == 3 or count == 4, "Colors." .. name .. " must have 3 (RGB) or 4 (RGBA) entries")
      for i = 1, count do
        local component = color[i]
        Assert.True(type(component) == "number", "Colors." .. name .. "[" .. i .. "] must be numeric")
        Assert.True(component >= 0 and component <= 1, "Colors." .. name .. "[" .. i .. "] must be in [0, 1]")
      end
    end
  end)

  test("UICommon.Colors has no two keys sharing the exact same value tuple", function()
    local UICommon = LoadUICommon()
    local seenBy = {}
    for name, color in pairs(UICommon.Colors) do
      local key = table.concat(color, ",")
      local existing = seenBy[key]
      Assert.True(
        existing == nil,
        "Colors."
          .. name
          .. " duplicates Colors."
          .. tostring(existing)
          .. " ("
          .. key
          .. ") -- reuse the token instead"
      )
      seenBy[key] = name
    end
  end)
end
