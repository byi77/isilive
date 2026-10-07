---@diagnostic disable: undefined-global

-- Scenarios for the two surfaces UICommon installs while it loads:
-- ui/isiLive_ui_private_tooltip.lua (anchoring, spell-name lookup) and
-- ui/isiLive_ui_motion.lua (reduced-motion setting). Split out of
-- isilive_test_scenarios_ui_common.lua; every test drives the modules through
-- the public UICommon surface only.

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
    return self._fontPath or "Fonts\\X.TTF", self._fontSize or 12, self._fontFlags or "OUTLINE"
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
  local frame = { _shown = false, _points = {}, _scripts = {} }
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
  function frame:EnableMouse() end
  function frame:GetEffectiveScale()
    return 1
  end
  function frame:CreateFontString()
    return MakeFontStringStub()
  end
  function frame:CreateTexture()
    local tex = {}
    function tex:SetAllPoints() end
    function tex:SetPoint() end
    function tex:ClearAllPoints() end
    function tex:SetTexture() end
    function tex:SetTexCoord() end
    function tex:SetBlendMode() end
    function tex:SetAlpha() end
    function tex:SetColorTexture() end
    function tex:SetHeight() end
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

  test("UICommon private tooltip anchors above, at the scaled cursor, or below its owner", function()
    local uiParent = MakeFrameStub()
    function uiParent:GetEffectiveScale()
      return 2
    end
    WithGlobals({
      CreateFrame = function()
        return MakeFrameStub()
      end,
      UIParent = uiParent,
      GetCursorPosition = function()
        return 100, 200
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      Assert.True(type(addon.UIPrivateTooltip) == "table", "ui_common must pull in the private tooltip module")
      local UICommon = addon.UICommon
      local tooltip = UICommon.CreatePrivateTooltip(MakeFrameStub())
      local owner = MakeFrameStub()

      UICommon.PreparePrivateTooltip(tooltip, owner, "ANCHOR_TOP")
      Assert.Equal(#tooltip._points, 1, "anchoring must replace earlier points")
      local point = tooltip._points[1]
      Assert.True(
        point[1] == "BOTTOM" and point[2] == owner and point[3] == "TOP" and point[4] == 0 and point[5] == 8,
        "ANCHOR_TOP must sit 8 px above the owner"
      )

      UICommon.PreparePrivateTooltip(tooltip, owner)
      point = tooltip._points[1]
      Assert.True(
        point[1] == "BOTTOMLEFT" and point[2] == uiParent and point[4] == 66 and point[5] == 116,
        "the default cursor anchor must divide by the UIParent scale and offset by 16 px"
      )

      UICommon.PreparePrivateTooltip(tooltip, owner, "ANCHOR_RIGHT")
      point = tooltip._points[1]
      Assert.True(
        point[1] == "TOPLEFT" and point[2] == owner and point[3] == "BOTTOMLEFT" and point[5] == -4,
        "other anchors must fall back to just below the owner"
      )
    end)
  end)

  test("UICommon private tooltip resolves spell names through C_Spell before the legacy global", function()
    WithGlobals({
      CreateFrame = function()
        return MakeFrameStub()
      end,
      UIParent = MakeFrameStub(),
    }, function()
      local UICommon = LoadAddonModules({ "isiLive_ui_common.lua" }).UICommon
      local tooltip = UICommon.CreatePrivateTooltip(MakeFrameStub())
      local function HeaderText()
        return tooltip._isiLiveTooltipLines[1]:GetText()
      end

      WithGlobals({
        C_Spell = {
          GetSpellName = function()
            return "Kick"
          end,
        },
        GetSpellInfo = function()
          return "Legacy"
        end,
      }, function()
        tooltip:SetSpellByID(1766)
      end)
      Assert.Equal(HeaderText(), "Kick", "C_Spell.GetSpellName must win over every fallback")

      WithGlobals({
        C_Spell = {
          GetSpellName = function()
            return ""
          end,
          GetSpellInfo = function()
            return { name = "Pummel" }
          end,
        },
      }, function()
        tooltip:SetSpellByID(6552)
      end)
      Assert.Equal(HeaderText(), "Pummel", "an empty name must fall through to C_Spell.GetSpellInfo")

      WithGlobals({
        C_Spell = false,
        GetSpellInfo = function()
          return "Legacy"
        end,
      }, function()
        tooltip:SetSpellByID(1)
      end)
      Assert.Equal(HeaderText(), "Legacy", "the legacy global is the last resort")

      WithGlobals({ C_Spell = false, GetSpellInfo = false }, function()
        tooltip:SetSpellByID(42)
      end)
      Assert.Equal(HeaderText(), "Spell 42", "an unresolved spell must fall back to its ID")
      Assert.Equal(tooltip._isiLiveTooltipLineCount, 1, "SetSpellByID must replace, not append")
      Assert.Equal(tooltip._height, 34, "one line must size the tooltip to padding plus line height")
    end)
  end)

  test("UICommon reduced-motion setting persists through IsiLiveDB and fails closed without it", function()
    local UICommon, addon = LoadUICommon()
    Assert.True(type(addon.UIMotion) == "table", "ui_common must pull in the motion module")

    WithGlobals({ IsiLiveDB = false }, function()
      Assert.False(UICommon.SetReducedMotionEnabled(true), "without a saved-variables table the setting must fail")
      Assert.False(UICommon.IsReducedMotionEnabled(), "without a saved-variables table motion stays enabled")
    end)

    local db = {}
    WithGlobals({ IsiLiveDB = db }, function()
      Assert.False(UICommon.IsReducedMotionEnabled(), "an unset setting must default to full motion")
      Assert.True(UICommon.SetReducedMotionEnabled("yes"), "the setting applies with a saved-variables table")
      Assert.Equal(db.reduceMotion, false, "only a literal true may enable reduced motion")
      Assert.True(UICommon.SetReducedMotionEnabled(true), "reduced motion can be enabled")
      Assert.Equal(db.reduceMotion, true, "the setting must persist in IsiLiveDB")
      Assert.True(UICommon.IsReducedMotionEnabled(), "the stored setting must be read back")
    end)
  end)
end
