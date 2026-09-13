---@diagnostic disable: undefined-global

-- Scenarios for ui/isiLive_ui_fonts.lua -- the font-family selection that
-- feeds UICommon.ApplyLocaleFont. The contract these pin down:
--   * a locale that needs its own font always beats the user's pick,
--   * an unknown or empty key resolves to nil so the template font stands,
--   * switching the font reaches FontStrings that already exist.

local function MakeFontStringStub()
  local fs = {}
  function fs:GetFont()
    return self._fontPath or "Fonts\\FRIZQT__.TTF", self._fontSize or 12, self._fontFlags
  end
  function fs:SetFont(path, size, flags)
    self._fontPath = path
    self._fontSize = size
    self._fontFlags = flags
  end
  return fs
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function LoadFonts(globals)
    local addon
    WithGlobals(globals or {}, function()
      addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_fonts.lua" })
    end)
    return addon.UICommon, addon
  end

  test("UICommon.GetFontChoices lists exactly the fonts the client ships", function()
    local UICommon = LoadFonts()
    local choices = UICommon.GetFontChoices()
    Assert.Equal(#choices, 5, "the list must carry the default entry plus four client fonts")
    Assert.Equal(choices[1].key, "", "the default entry must come first")
  end)

  test("UICommon.ResolveFontPathByKey maps a built-in key to its client font path", function()
    local UICommon = LoadFonts()
    Assert.Equal(
      UICommon.ResolveFontPathByKey("morpheus"),
      "Fonts\\MORPHEUS.TTF",
      "a known key must resolve to the shipped font path"
    )
  end)

  test("UICommon.ResolveFontPathByKey returns nil for empty and unknown keys", function()
    local UICommon = LoadFonts()
    Assert.Nil(UICommon.ResolveFontPathByKey(""), "the default key must not resolve to a path")
    Assert.Nil(UICommon.ResolveFontPathByKey("media:Gone"), "a key from an older choice list must not resolve")
    Assert.Nil(UICommon.ResolveFontPathByKey(nil), "a non-string key must not resolve")
  end)

  test("UICommon.GetPreferredFontPath returns the user font when the locale needs no override", function()
    WithGlobals({
      IsiLiveDB = { locale = "enUS", uiFontFamily = "skurri" },
      GetLocale = function()
        return "enUS"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_fonts.lua" })
      Assert.Equal(
        addon.UICommon.GetPreferredFontPath(),
        "Fonts\\SKURRI.TTF",
        "the user's pick must apply where the locale has no font requirement"
      )
    end)
  end)

  test("UICommon.GetPreferredFontPath lets the locale override win over the user font", function()
    -- The regression this guards: a Latin-only pick would turn every ruRU
    -- label into boxes. The locale requirement is not negotiable.
    WithGlobals({
      IsiLiveDB = { locale = "ruRU", uiFontFamily = "morpheus" },
      GetLocale = function()
        return "ruRU"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_fonts.lua" })
      Assert.Equal(
        addon.UICommon.GetPreferredFontPath(),
        addon.UICommon.CYRILLIC_FONT_PATH,
        "ruRU must keep its Cyrillic-capable font even when another font is selected"
      )
    end)
  end)

  test("UICommon.ApplyLocaleFont applies the selected user font to a FontString", function()
    WithGlobals({
      IsiLiveDB = { locale = "enUS", uiFontFamily = "arial" },
      GetLocale = function()
        return "enUS"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_fonts.lua" })
      local fontString = MakeFontStringStub()
      Assert.True(addon.UICommon.ApplyLocaleFont(fontString), "a selected font must be applied")
      Assert.Equal(fontString._fontPath, "Fonts\\ARIALN.TTF", "the FontString must carry the selected font")
      Assert.Equal(fontString._fontSize, 12, "the existing font size must survive a family change")
    end)
  end)

  test("UICommon.ApplyLocaleFont keeps the template font when no font is selected", function()
    WithGlobals({
      IsiLiveDB = { locale = "enUS", uiFontFamily = "" },
      GetLocale = function()
        return "enUS"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_fonts.lua" })
      local fontString = MakeFontStringStub()
      Assert.False(addon.UICommon.ApplyLocaleFont(fontString), "the default must not touch the template font")
      Assert.Nil(fontString._fontPath, "no SetFont call may happen for the default selection")
    end)
  end)

  test("UICommon.ApplyReadableFontForText keeps Cyrillic text readable under a Latin-only pick", function()
    WithGlobals({
      IsiLiveDB = { locale = "enUS", uiFontFamily = "morpheus" },
      GetLocale = function()
        return "enUS"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_fonts.lua" })
      local fontString = MakeFontStringStub()
      addon.UICommon.ApplyReadableFontForText(fontString, "Юрий")
      Assert.Equal(
        fontString._fontPath,
        addon.UICommon.CYRILLIC_FONT_PATH,
        "a Cyrillic player name must override the selected Latin-only font"
      )
    end)
  end)

  -- RefreshTrackedFonts ------------------------------------------------------
  --
  -- The bug this exists for: every ApplyLocaleFont call site sits in the
  -- *creation* of a row, header or label, and roster rows are pooled and
  -- reused. Changing the setting therefore reached no existing FontString at
  -- all, and the selection looked like it did nothing.

  test("UICommon.RefreshTrackedFonts re-applies a changed selection to existing FontStrings", function()
    local db = { locale = "enUS", uiFontFamily = "" }
    WithGlobals({
      IsiLiveDB = db,
      GetLocale = function()
        return "enUS"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_fonts.lua" })
      -- Built under the default, exactly like a row created before the user
      -- ever opens the settings panel: nothing is applied, but it is tracked.
      local fontString = MakeFontStringStub()
      addon.UICommon.ApplyLocaleFont(fontString)
      Assert.Nil(fontString._fontPath, "the default must not have touched the string")

      db.uiFontFamily = "skurri"
      Assert.Equal(addon.UICommon.RefreshTrackedFonts(), 1, "the tracked string must be visited")
      Assert.Equal(
        fontString._fontPath,
        "Fonts\\SKURRI.TTF",
        "an already existing FontString must pick up the new selection"
      )
    end)
  end)

  test("UICommon.RefreshTrackedFonts keeps the Cyrillic veto for text-carrying strings", function()
    local db = { locale = "enUS", uiFontFamily = "" }
    WithGlobals({
      IsiLiveDB = db,
      GetLocale = function()
        return "enUS"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_fonts.lua" })
      local cyrillic = MakeFontStringStub()
      function cyrillic:GetText()
        return "Юрий"
      end
      local latin = MakeFontStringStub()
      function latin:GetText()
        return "Felix"
      end
      addon.UICommon.ApplyLocaleFont(cyrillic)
      addon.UICommon.ApplyLocaleFont(latin)

      db.uiFontFamily = "morpheus"
      addon.UICommon.RefreshTrackedFonts()
      Assert.Equal(
        cyrillic._fontPath,
        addon.UICommon.CYRILLIC_FONT_PATH,
        "a Cyrillic label must stay on the Cyrillic-capable font after a refresh"
      )
      Assert.Equal(latin._fontPath, "Fonts\\MORPHEUS.TTF", "a Latin label must take the new selection")
    end)
  end)

  test("UICommon.RefreshTrackedFonts restores the template font when the selection is cleared", function()
    local db = { locale = "enUS", uiFontFamily = "skurri" }
    WithGlobals({
      IsiLiveDB = db,
      GetLocale = function()
        return "enUS"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_fonts.lua" })
      local fontString = MakeFontStringStub()
      function fontString:GetText()
        return "Felix"
      end
      addon.UICommon.ApplyReadableFontForText(fontString, "Felix")
      Assert.Equal(fontString._fontPath, "Fonts\\SKURRI.TTF", "the selection must apply first")

      db.uiFontFamily = ""
      addon.UICommon.RefreshTrackedFonts()
      Assert.Equal(
        fontString._fontPath,
        "Fonts\\FRIZQT__.TTF",
        "clearing the selection must return the string to its captured baseline"
      )
    end)
  end)

  test("UICommon.GetUserFontPath tolerates a missing IsiLiveDB", function()
    WithGlobals({ IsiLiveDB = nil }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_fonts.lua" })
      Assert.Nil(addon.UICommon.GetUserFontPath(), "a missing saved-variables table must resolve to no font")
    end)
  end)
end
