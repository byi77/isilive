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
  function fs:SetWidth(width)
    self._width = width
  end
  function fs:SetJustifyH() end
  function fs:SetJustifyV() end
  function fs:SetWordWrap() end
  function fs:SetNonSpaceWrap() end
  function fs:SetMaxLines() end
  function fs:SetTextColor(...)
    self._textColor = { ... }
  end
  function fs:SetFont(path, size, flags)
    self._fontPath = path
    self._fontSize = size
    self._fontFlags = flags
  end
  function fs:GetFont()
    return self._fontPath or "Fonts\\\\X.TTF", self._fontSize or 12, self._fontFlags or "OUTLINE"
  end
  function fs:SetPoint(...)
    self._point = { ... }
  end
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
    _hookScripts = {},
    _textures = {},
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
  function frame:SetSize(width, height)
    self._width = width
    self._height = height
  end
  function frame:SetWidth(width)
    self._width = width
  end
  function frame:SetHeight(height)
    self._height = height
  end
  function frame:SetFrameStrata() end
  function frame:SetFrameLevel() end
  function frame:SetScript(name, fn)
    self._scripts[name] = fn
  end
  function frame:HookScript(name, fn)
    self._hookScripts[name] = fn
  end
  function frame:EnableMouse() end
  function frame:RegisterForClicks(...)
    self._registeredClicks = { ... }
  end
  function frame:IsMouseOver()
    return self._mouseOver == true
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
    function tex:SetHeight(height)
      self._height = height
    end
    function tex:Hide() end
    function tex:Show() end
    table.insert(self._textures, tex)
    return tex
  end
  function frame:CreateAnimationGroup()
    local group = { _playing = false }
    function group:CreateAnimation()
      return {
        SetFromAlpha = function() end,
        SetToAlpha = function() end,
        SetDuration = function() end,
        SetSmoothing = function() end,
      }
    end
    function group:IsPlaying()
      return self._playing
    end
    function group:Play()
      self._playing = true
    end
    function group:Stop()
      self._playing = false
    end
    return group
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
    Assert.Equal(
      mainFrame._backdropColor[1],
      UICommon.Colors.SURFACE_MAIN_FRAME[1],
      "mainFrame must retain the semantic slate surface when alpha changes"
    )
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

  test("UICommon background opacity repaints semantic title and run surfaces", function()
    rawset(_G, "IsiLiveDB", { bgAlpha = 0.4 })
    local UICommon = LoadUICommon()
    local parent = MakeFrameStub()
    local chrome = UICommon.CreatePanelChrome(parent, { height = 27 })
    local runBox = MakeFrameStub()
    UICommon.ApplyBackdrop(runBox, "CD_BOX")

    local expectedInitialAlpha = 0.4 * UICommon.STRUCTURAL_TINT_ALPHA_FACTOR
    Assert.Equal(
      chrome.titleBar._colorTexture[4],
      expectedInitialAlpha,
      "title tint must derive its initial alpha from the configured background opacity"
    )
    Assert.Equal(
      runBox._backdropColor[4],
      expectedInitialAlpha,
      "run-zone tint must derive its initial alpha from the configured background opacity"
    )

    UICommon.ApplyBgAlpha(nil, 0.75)
    local expectedLiveAlpha = 0.75 * UICommon.STRUCTURAL_TINT_ALPHA_FACTOR
    Assert.Equal(
      chrome.titleBar._colorTexture[4],
      expectedLiveAlpha,
      "title tint must repaint immediately when the background opacity changes"
    )
    Assert.Equal(
      runBox._backdropColor[4],
      expectedLiveAlpha,
      "run-zone tint must repaint immediately when the background opacity changes"
    )
    rawset(_G, "IsiLiveDB", nil)
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

  test("UICommon close button uses compact semantic visual states", function()
    WithGlobals({
      CreateFrame = function()
        return MakeFrameStub()
      end,
      UIParent = MakeFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      local parent = MakeFrameStub()
      local button = addon.UICommon.CreateCloseButton(parent, { size = 22 })

      Assert.True(
        addon.UICommon.CreateRedCloseButton == addon.UICommon.CreateCloseButton,
        "legacy close-button factory must remain a compatibility alias"
      )
      Assert.Equal(button._isiLiveCloseButtonLabel._text, "×", "close button should render a compact multiplication X")
      Assert.Equal(button._isiLiveVisualState, "default", "close button should start in the quiet default state")
      Assert.Equal(
        button._backdropColor[1],
        addon.UICommon.Colors.SURFACE_ACTION_SECONDARY[1],
        "default close surface should share the title-control slate"
      )

      button._scripts.OnEnter()
      Assert.Equal(button._isiLiveVisualState, "hover", "hover should reveal the restrained danger state")
      Assert.Equal(
        button._backdropColor[1],
        addon.UICommon.Colors.SURFACE_CLOSE_DANGER_HOVER[1],
        "hover danger surface must come from the shared color token, not a literal"
      )
      button._scripts.OnMouseDown()
      Assert.Equal(button._isiLiveVisualState, "pressed", "mouse down should render the pressed danger state")
      Assert.Equal(
        button._backdropColor[1],
        addon.UICommon.Colors.SURFACE_CLOSE_DANGER_PRESSED[1],
        "pressed danger surface must come from the shared color token, not a literal"
      )

      button._scripts.OnLeave()
      Assert.Equal(button._isiLiveVisualState, "default", "leave should restore the quiet default state")
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
      Assert.Equal(tooltip._width, 220, "private tooltip should share the roster tooltip minimum width")
      Assert.Equal(
        tooltip._isiLiveTooltipLines[1]._width,
        200,
        "private tooltip text should use the shared ten-pixel horizontal insets"
      )
      Assert.Equal(
        tooltip._isiLiveTooltipLines[2]._point[5],
        -3,
        "private tooltip rows should keep the shared three-pixel line gap"
      )
      Assert.Equal(
        tooltip._isiLiveTooltipLines[1]._point[5],
        -10,
        "private tooltip content should keep the shared ten-pixel top inset"
      )
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

  test("UICommon private tooltip uses the shared notice surface", function()
    WithGlobals({
      CreateFrame = function()
        return MakeFrameStub()
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      local tooltip = addon.UICommon.CreatePrivateTooltip(MakeFrameStub())
      Assert.Equal(
        tooltip._backdropColor[1],
        addon.UICommon.Colors.SURFACE_NOTICE[1],
        "tooltip surface must use the shared notice token"
      )
      Assert.Equal(
        tooltip._borderColor[1],
        addon.UICommon.Colors.BORDER_NOTICE[1],
        "tooltip border must use the shared notice token"
      )
    end)
  end)

  test("UICommon.PreparePrivateTooltip is a no-op for non-table tooltip input", function()
    local UICommon = LoadUICommon()
    UICommon.PreparePrivateTooltip(nil, MakeFrameStub())
    UICommon.PreparePrivateTooltip("not-a-table", MakeFrameStub())
  end)

  -- Shared semantic design system --------------------------------------------

  test("UICommon semantic design system exposes shared modern surface and spacing roles", function()
    local UICommon = LoadUICommon()
    Assert.Equal(UICommon.Theme.spacing.xs, 4, "extra-small spacing must stay on the 4 px base unit")
    Assert.Equal(UICommon.Theme.spacing.sm, 8, "small spacing must stay on the 8 px base unit")
    Assert.True(
      UICommon.Theme.color.surface.main == UICommon.Colors.SURFACE_MAIN_FRAME,
      "main surface role must reference the shared semantic color token"
    )
    Assert.True(
      UICommon.Theme.color.text.primary == UICommon.Colors.TEXT_HEADING,
      "primary text role must reference the shared heading token"
    )
    Assert.True(
      UICommon.Theme.color.surface.run == UICommon.Colors.SURFACE_RUN_ZONE,
      "M+ run surfaces must reference the shared run-zone token"
    )
    Assert.True(
      UICommon.Theme.color.surface.notice == UICommon.Colors.SURFACE_NOTICE,
      "notice cards must reference the shared notice token"
    )
  end)

  test("UICommon action button switches deterministic primary visual states", function()
    WithGlobals({
      CreateFrame = function()
        return MakeFrameStub()
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      local UICommon = addon.UICommon
      local button = UICommon.CreateActionButton(MakeFrameStub(), {
        width = 92,
        height = 22,
        role = "primary",
      })

      Assert.Equal(button._isiLiveSemanticRole, "primary", "button must retain its semantic role")
      Assert.Equal(
        button._backdropColor[1],
        UICommon.Colors.SURFACE_ACTION_PRIMARY[1],
        "primary default surface must use the shared token"
      )
      button._hookScripts.OnEnter(button)
      Assert.Equal(button._isiLiveVisualState, "hover", "hover hook must apply the hover state")
      Assert.Equal(
        button._backdropColor[1],
        UICommon.Colors.SURFACE_ACTION_PRIMARY_HOVER[1],
        "primary hover surface must use the shared token"
      )
      button._hookScripts.OnMouseDown(button)
      Assert.Equal(button._isiLiveVisualState, "pressed", "mouse-down hook must apply the pressed state")
      button:SetSemanticRole("secondary")
      Assert.Equal(button._isiLiveSemanticRole, "secondary", "semantic role changes must repaint deterministically")
    end)
  end)

  test("UICommon action availability keeps locked and cooldown visuals through hover", function()
    WithGlobals({
      CreateFrame = function()
        return MakeFrameStub()
      end,
    }, function()
      local common = LoadAddonModules({ "isiLive_ui_common.lua" }).UICommon
      local button = common.CreateActionButton(MakeFrameStub(), { role = "primary" })
      button:SetAvailabilityState("leader")
      Assert.Equal(button._isiLiveAvailability, "leader", "leader lock must be explicit")
      Assert.Nil(button._availabilityIcon._isiLiveStateIcon, "leader lock is dimmed only, without a lock icon")
      button._hookScripts.OnEnter(button)
      Assert.Equal(
        button._backdropColor[1],
        common.Colors.SURFACE_ACTION_SECONDARY_PRESSED[1],
        "locked hover must stay muted"
      )
      button:SetAvailabilityState("cooldown")
      Assert.Equal(button._availabilityIcon._isiLiveStateIcon, "cooldown", "cooldown must show the hourglass icon")
      button:SetAvailabilityState("combat")
      Assert.Equal(button._availabilityIcon._isiLiveStateIcon, "warning", "combat lock must show the warning icon")
      button:SetAvailabilityState("unavailable")
      Assert.Equal(button._availabilityIcon._isiLiveStateIcon, "unavailable", "unavailable must show its own icon")
      button:SetAvailabilityState("available")
      Assert.Nil(button._availabilityIcon._isiLiveStateIcon, "available action must clear the icon")
      Assert.Equal(
        button._backdropColor[1],
        common.Colors.SURFACE_ACTION_PRIMARY[1],
        "available action must regain its primary role"
      )
    end)
  end)

  test("UICommon panel chrome creates a bounded title surface and separator", function()
    local UICommon = LoadUICommon()
    local parent = MakeFrameStub()
    local chrome = UICommon.CreatePanelChrome(parent, { height = 27 })

    Assert.NotNil(chrome, "panel chrome must be created for a texture-capable parent")
    Assert.Equal(chrome.height, 27, "title chrome must preserve its explicit height budget")
    Assert.Equal(chrome.titleBar._height, 27, "title surface must use the explicit height budget")
    Assert.Equal(chrome.separator._height, 1, "title separator must remain a quiet one-pixel rule")
    Assert.Equal(
      chrome.titleBar._colorTexture[1],
      UICommon.Colors.SURFACE_TITLE_BAR[1],
      "title surface must use the shared semantic token"
    )
  end)

  test("UICommon notice chrome creates a shared top accent and semantic role", function()
    local UICommon = LoadUICommon()
    local parent = MakeFrameStub()
    local accent = UICommon.CreateNoticeChrome(parent)
    Assert.NotNil(accent, "notice chrome should create the shared top accent")
    Assert.Equal(parent._isiLiveSurfaceRole, "notice", "notice chrome should expose the semantic surface role")
    Assert.Equal(accent._height, 2, "notice top accent should stay subtle")
  end)

  test("UICommon notice kind and reduced motion use semantic markers and brief transitions", function()
    local UICommon = LoadUICommon()
    local parent = MakeFrameStub()
    UICommon.CreateNoticeChrome(parent)
    local ok, changed = UICommon.ApplyNoticeKind(parent, "info")
    Assert.True(ok, "info notice kind should apply")
    Assert.False(changed, "initial notice kind is not a status switch")
    Assert.Equal(parent._isiLiveNoticeKindIcon._isiLiveStateIcon, "info", "info uses the info icon")
    local _, switched = UICommon.ApplyNoticeKind(parent, "warning")
    Assert.True(switched, "changing notice kind should report a status switch")
    Assert.Equal(parent._isiLiveNoticeKindIcon._isiLiveStateIcon, "warning", "warning uses the alert icon")
    Assert.True(UICommon.PlayNoticeTransition(parent), "notice transition should start")
    Assert.True(parent._isiLiveNoticeTransition:IsPlaying(), "transition group should be playing")
    Assert.Equal(UICommon.ApplyNoticeKind(parent, "unknown"), false, "unknown notice kind should fail closed")
    WithGlobals({ IsiLiveDB = { reduceMotion = true } }, function()
      Assert.True(UICommon.IsReducedMotionEnabled(), "saved reduce-motion setting should be read live")
      Assert.True(UICommon.SetReducedMotionEnabled(true), "motion setting should apply immediately")
      Assert.False(
        parent._isiLiveNoticeTransition:IsPlaying(),
        "enabling reduced motion should stop an active notice fade"
      )
      Assert.False(UICommon.PlayNoticeTransition(parent), "reduced motion should skip decorative notice fades")
    end)
  end)

  local function MakeMotionFrameStub(initialAlpha)
    local frame = { alpha = initialAlpha or 1, groupCount = 0 }
    function frame:GetAlpha()
      return self.alpha
    end
    function frame:SetAlpha(alpha)
      self.alpha = alpha
    end
    function frame:CreateAnimationGroup()
      self.groupCount = self.groupCount + 1
      local group = { _playing = false, scripts = {}, animations = {} }
      function group:CreateAnimation(animType)
        local anim = { type = animType }
        function anim:SetFromAlpha(value)
          self.fromAlpha = value
        end
        function anim:SetToAlpha(value)
          self.toAlpha = value
        end
        function anim:SetDuration(value)
          self.duration = value
        end
        function anim:SetSmoothing(value)
          self.smoothing = value
        end
        table.insert(self.animations, anim)
        return anim
      end
      function group:SetScript(name, handler)
        self.scripts[name] = handler
      end
      function group:IsPlaying()
        return self._playing
      end
      function group:Play()
        self._playing = true
      end
      function group:Stop()
        self._playing = false
      end
      self.lastGroup = group
      return group
    end
    return frame
  end

  local function MakeRecordingTexture()
    local texture = { _shown = true }
    function texture:SetTexture(path)
      self._path = path
    end
    function texture:SetTexCoord(...)
      self._texCoord = { ... }
    end
    function texture:Show()
      self._shown = true
    end
    function texture:Hide()
      self._shown = false
    end
    function texture:ClearAllPoints()
      self._points = {}
    end
    function texture:SetPoint(...)
      self._points = self._points or {}
      self._points[#self._points + 1] = { ... }
    end
    function texture:SetVertexColor(...)
      self._vertexColor = { ... }
    end
    function texture:SetColorTexture(...)
      self._colorTexture = { ... }
    end
    function texture:SetDrawLayer(layer, sublevel)
      self._drawLayer = { layer, sublevel }
    end
    function texture:SetBlendMode(mode)
      self._blendMode = mode
    end
    return texture
  end

  test("UICommon state icons map semantic keys to client textures and clear on nil", function()
    local UICommon = LoadUICommon()
    local texture = MakeRecordingTexture()

    Assert.True(UICommon.ApplyStateIcon(texture, "death"), "known icon keys must apply")
    Assert.Equal(texture._path, "Interface\\WorldStateFrame\\SkullBones", "death must use the skull-and-bones art")
    Assert.Equal(texture._texCoord[1], 0.046875, "death must crop the skull from its sprite sheet")
    Assert.Equal(texture._texCoord[4], 0.46875, "death crop must end at the skull's lower edge")
    Assert.Equal(texture._isiLiveStateIcon, "death", "applied icon key must be observable")

    UICommon.ApplyStateIcon(texture, "lock")
    Assert.Equal(texture._path, "Interface\\PetBattles\\PetBattle-LockIcon", "lock must use the pet battle lock")
    Assert.Equal(texture._texCoord[2], 1, "a plain texture must reset a previous crop")

    UICommon.ApplyStateIcon(texture, "cooldown")
    Assert.Equal(texture._texCoord[1], 0.08, "item icons must drop their built-in border")

    Assert.False(UICommon.ApplyStateIcon(texture, nil), "nil must clear the icon")
    Assert.False(texture._shown, "a cleared icon must be hidden")
    Assert.Nil(texture._isiLiveStateIcon, "a cleared icon must drop its key")
    Assert.False(UICommon.ApplyStateIcon(texture, "unknown"), "unknown icon keys must fail closed")
    Assert.False(UICommon.ApplyStateIcon(nil, "lock"), "a missing texture must fail closed")
  end)

  test("UICommon flat checkbox style replaces template art with layered flat textures", function()
    local UICommon = LoadUICommon()
    local function MakeCheckStub(width)
      local check = { _slots = {}, _created = {} }
      function check:GetWidth()
        return width
      end
      function check:CreateTexture(_, layer)
        local texture = MakeRecordingTexture()
        texture._createdLayer = layer
        table.insert(self._created, texture)
        return texture
      end
      for _, slot in ipairs({
        "NormalTexture",
        "PushedTexture",
        "HighlightTexture",
        "CheckedTexture",
        "DisabledCheckedTexture",
      }) do
        check["Set" .. slot] = function(self, path)
          self._slots[slot] = self._slots[slot] or MakeRecordingTexture()
          self._slots[slot]._path = path
        end
        check["Get" .. slot] = function(self)
          return self._slots[slot]
        end
      end
      return check
    end

    local check = MakeCheckStub(24)
    Assert.True(UICommon.ApplyFlatCheckboxStyle(check), "flat style must apply to a check button")
    Assert.True(check._isiLiveFlatCheckbox, "styled checkboxes must be observable")
    Assert.Equal(check._slots.NormalTexture._path, "Interface\\Buttons\\WHITE8X8", "template art must be replaced")
    Assert.Equal(check._slots.NormalTexture._drawLayer[1], "ARTWORK", "the box fill must draw on ARTWORK")
    Assert.Equal(check._slots.CheckedTexture._drawLayer[1], "OVERLAY", "the check mark must draw above the fill")
    Assert.Equal(check._slots.HighlightTexture._blendMode, "ADD", "hover must blend additively")
    Assert.Equal(
      check._slots.CheckedTexture._vertexColor[1],
      UICommon.Colors.ACCENT_BLUE[1],
      "the check mark must use the cool accent"
    )
    Assert.Equal(check._slots.NormalTexture._points[1][4], 4, "a 24 px box fill must sit 4 px inside")
    Assert.Equal(check._slots.CheckedTexture._points[1][4], 7, "a 24 px check mark must sit 7 px inside")
    Assert.Equal(check._isiLiveFlatOutline._createdLayer, "BACKGROUND", "the outline must stay behind the fill")
    Assert.Equal(check._isiLiveFlatOutline._points[1][4], 3, "a 24 px outline must sit 3 px inside")

    local small = MakeCheckStub(18)
    UICommon.ApplyFlatCheckboxStyle(small)
    Assert.Equal(small._isiLiveFlatOutline._points[1][4], 2, "an 18 px outline must sit 2 px inside")
    Assert.Equal(small._slots.CheckedTexture._points[1][4], 5, "an 18 px check mark must sit 5 px inside")

    UICommon.ApplyFlatCheckboxStyle(check)
    Assert.Equal(#check._created, 1, "restyling must not stack a second outline")
    Assert.False(UICommon.ApplyFlatCheckboxStyle(nil), "a missing check button must fail closed")
  end)

  test("UICommon decimal format follows the addon language and fails closed", function()
    local UICommon = LoadUICommon()
    WithGlobals({ IsiLiveDB = { locale = "deDE" } }, function()
      Assert.Equal(UICommon.GetDecimalSeparator(), ",", "stored deDE addon language must use a decimal comma")
      Assert.Equal(UICommon.FormatDecimal(12.345, 2), "12,35", "deDE decimals must be rounded and comma separated")
    end)
    WithGlobals({ IsiLiveDB = { locale = "enUS" } }, function()
      Assert.Equal(UICommon.FormatDecimal(12.345, 2), "12.35", "enUS decimals must use a decimal point")
    end)
    for _, tag in ipairs({ "frFR", "esES", "ptBR", "itIT", "ruRU", "trTR" }) do
      Assert.Equal(UICommon.GetDecimalSeparator(tag), ",", tag .. " must use a decimal comma")
    end
    Assert.Equal(UICommon.GetDecimalSeparator("enUS"), ".", "enUS must use a decimal point")
    Assert.Equal(UICommon.FormatDecimal(7, 0, "deDE"), "7", "zero decimals must not add a separator")
    Assert.Nil(UICommon.FormatDecimal("abc", 2, "enUS"), "non-numeric input must fail closed")
  end)

  test("UICommon motion tokens resolve shared durations and easing", function()
    local UICommon = LoadUICommon()
    Assert.Equal(UICommon.Motion.duration.fast, 0.14, "fast must stay the existing Center-Notice fade")
    Assert.Equal(UICommon.Motion.duration.normal, 0.2, "normal transition token")
    Assert.Equal(UICommon.Motion.duration.slow, 0.35, "slow transition token")
    Assert.Equal(UICommon.Motion.smoothing.enter, "OUT", "entering motion decelerates")
    Assert.Equal(UICommon.Motion.smoothing.exit, "IN", "leaving motion accelerates")
    Assert.Equal(UICommon.ResolveMotionDuration("slow"), 0.35, "named tokens resolve to their duration")
    Assert.Equal(UICommon.ResolveMotionDuration(0.5), 0.5, "explicit seconds pass through")
    Assert.Equal(UICommon.ResolveMotionDuration("unknown"), 0.2, "unknown tokens fall back to normal")
    Assert.Equal(UICommon.ResolveMotionDuration(-1), 0.2, "negative seconds fall back to normal")
  end)

  test("UICommon alpha transition builds once, restarts and settles at the resting alpha", function()
    local UICommon = LoadUICommon()
    local frame = MakeMotionFrameStub(0.8)

    Assert.True(
      UICommon.PlayAlphaTransition(frame, "fade", { fromAlpha = 0, toAlpha = 1, duration = "normal" }),
      "alpha transition should start"
    )
    local group = frame.lastGroup
    local anim = group.animations[1]
    Assert.Equal(anim.type, "Alpha", "transition must animate alpha only")
    Assert.Equal(anim.fromAlpha, 0, "transition must start at the requested alpha")
    Assert.Equal(anim.toAlpha, 1, "transition must end at the requested alpha")
    Assert.Equal(anim.duration, 0.2, "duration tokens must resolve through the motion table")
    Assert.Equal(anim.smoothing, "OUT", "transition must default to the enter easing")
    Assert.True(group:IsPlaying(), "transition group should be playing")

    Assert.True(UICommon.PlayAlphaTransition(frame, "fade"), "a repeated transition should restart")
    Assert.Equal(frame.groupCount, 1, "the animation group must be built once per frame and key")

    frame.alpha = 0.3
    group.scripts.OnFinished()
    Assert.Equal(frame.alpha, 0.8, "a finished transition must settle at the frame's resting alpha")

    Assert.False(UICommon.PlayAlphaTransition(frame, nil), "a transition without a key must fail closed")
    Assert.False(UICommon.PlayAlphaTransition({}, "fade"), "a frame that cannot animate must fail closed")
  end)

  test("UICommon notice entrance fades a hidden card fully in and yields to a refresh", function()
    local UICommon = LoadUICommon()
    local frame = MakeMotionFrameStub(1)
    Assert.True(UICommon.PlayNoticeEntrance(frame), "notice entrance should start")
    local entrance = frame._isiLiveNoticeEntrance
    local anim = entrance.animations[1]
    Assert.Equal(anim.fromAlpha, 0, "entrance must start fully transparent")
    Assert.Equal(anim.toAlpha, 1, "entrance must end fully opaque")
    Assert.Equal(anim.duration, 0.2, "entrance must use the normal motion duration")
    Assert.Equal(anim.smoothing, "OUT", "entrance must decelerate")
    Assert.True(entrance:IsPlaying(), "entrance group should be playing")

    Assert.True(UICommon.PlayNoticeTransition(frame), "refresh transition should start")
    Assert.False(entrance:IsPlaying(), "a refresh must replace a running entrance instead of stacking")
    Assert.True(frame._isiLiveNoticeTransition:IsPlaying(), "refresh group should be playing")

    WithGlobals({ IsiLiveDB = { reduceMotion = true } }, function()
      local fresh = MakeMotionFrameStub(1)
      Assert.False(UICommon.PlayNoticeEntrance(fresh), "reduced motion must skip the entrance")
      Assert.Equal(fresh.groupCount, 0, "a skipped entrance must not build an animation group")
    end)
  end)

  test("UICommon reduced motion stops every registered transition and skips new ones", function()
    local UICommon = LoadUICommon()
    local notice = MakeMotionFrameStub(1)
    local panel = MakeMotionFrameStub(0.6)
    Assert.True(UICommon.PlayNoticeTransition(notice), "notice transition should start")
    Assert.True(UICommon.PlayAlphaTransition(panel, "panel", { duration = "slow" }), "panel transition should start")
    panel.alpha = 0.1

    local db = { reduceMotion = false }
    WithGlobals({ IsiLiveDB = db }, function()
      Assert.True(UICommon.SetReducedMotionEnabled(true), "motion setting should apply immediately")
      Assert.False(notice.lastGroup:IsPlaying(), "reduced motion must stop the notice transition")
      Assert.False(panel.lastGroup:IsPlaying(), "reduced motion must stop every other registered transition")
      Assert.Equal(panel.alpha, 0.6, "a stopped transition must leave the frame at its resting alpha")

      local fresh = MakeMotionFrameStub(1)
      Assert.False(UICommon.PlayAlphaTransition(fresh, "fade"), "reduced motion must skip new transitions")
      Assert.Equal(fresh.groupCount, 0, "a skipped transition must not build an animation group")

      Assert.True(UICommon.SetReducedMotionEnabled(false), "motion can be re-enabled live")
      Assert.True(UICommon.PlayAlphaTransition(panel, "panel"), "transitions must resume once motion is allowed")

      -- An idle transition must not overwrite an alpha set elsewhere since
      -- (the main frame's combat fade drops it to 0 while fighting).
      panel.lastGroup:Stop()
      panel.alpha = 0
      Assert.True(UICommon.SetReducedMotionEnabled(true), "motion setting should apply again")
      Assert.Equal(panel.alpha, 0, "an idle transition must leave the frame's current alpha untouched")
    end)
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

  -- Rule 142: colors within 0.05 per channel (and 0.05 alpha) must be one
  -- token unless they are deliberate, distinctly named design steps. A new
  -- near-duplicate fails here until it either reuses the existing token or is
  -- added to this list with its reason.
  local DELIBERATE_NEAR_PAIRS = {
    -- Semantic surface tiers: main frame, title bar, run zone, notice, compact overlay.
    ["SURFACE_ACTION_SECONDARY|SURFACE_NOTICE"] = true,
    ["SURFACE_ACTION_SECONDARY|SURFACE_RUN_ZONE"] = true,
    ["SURFACE_ACTION_SECONDARY_PRESSED|SURFACE_MAIN_FRAME"] = true,
    ["SURFACE_COMPACT_OVERLAY|SURFACE_TITLE_BAR"] = true,
    ["SURFACE_NOTICE|SURFACE_RUN_ZONE"] = true,
    ["SURFACE_RUN_ZONE|SURFACE_TITLE_BAR"] = true,
    -- Notice top accent vs. primary button border: separate semantic roles.
    ["ACCENT_NOTICE_TOP|BORDER_ACTION_PRIMARY"] = true,
    -- Notice fallback card vs. compact layout overlay: unrelated surfaces.
    ["BG_NOTICE_CARD|SURFACE_COMPACT_OVERLAY"] = true,
    -- M+ timeline track vs. generic black overlay: named for rule 126.
    ["BLACK_OVERLAY_50|MPLUS_TIMELINE_TRACK"] = true,
    -- Killtracker level/progress text (rule 127) vs. section headings.
    ["LIGHT_BLUE_LEVEL_TEXT|TEXT_SECTION"] = true,
  }

  test("UICommon.Colors keeps near-identical colors as one token unless deliberately distinct", function()
    local UICommon = LoadUICommon()
    local names = {}
    for name in pairs(UICommon.Colors) do
      names[#names + 1] = name
    end
    table.sort(names)
    local tolerance = 0.05 + 1e-9
    for i = 1, #names do
      for j = i + 1, #names do
        local a, b = UICommon.Colors[names[i]], UICommon.Colors[names[j]]
        local rgb = math.max(math.abs(a[1] - b[1]), math.abs(a[2] - b[2]), math.abs(a[3] - b[3]))
        local alpha = math.abs((a[4] or 1) - (b[4] or 1))
        if rgb <= tolerance and alpha <= tolerance then
          local pair = names[i] .. "|" .. names[j]
          Assert.True(
            DELIBERATE_NEAR_PAIRS[pair] == true,
            pair .. " are within 0.05 per channel -- reuse one token or list the pair as a deliberate step"
          )
        end
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
