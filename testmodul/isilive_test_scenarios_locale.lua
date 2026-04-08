---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  test("All enUS keys exist in deDE locale", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    Assert.NotNil(locales.enUS, "enUS locale must exist")
    Assert.NotNil(locales.deDE, "deDE locale must exist")

    for key, _ in pairs(locales.enUS) do
      Assert.NotNil(locales.deDE[key], "deDE must have key: " .. tostring(key))
    end
  end)

  test("All deDE keys exist in enUS locale", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    for key, _ in pairs(locales.deDE) do
      Assert.NotNil(locales.enUS[key], "enUS must have key: " .. tostring(key))
    end
  end)

  test("All enUS keys exist in frFR locale", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    Assert.NotNil(locales.frFR, "frFR locale must exist")

    for key, _ in pairs(locales.enUS) do
      Assert.NotNil(locales.frFR[key], "frFR must have key: " .. tostring(key))
    end
  end)

  test("All frFR keys exist in enUS locale", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    for key, _ in pairs(locales.frFR) do
      Assert.NotNil(locales.enUS[key], "enUS must have key: " .. tostring(key))
    end
  end)

  test("All enUS keys exist in esES locale", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    Assert.NotNil(locales.esES, "esES locale must exist")

    for key, _ in pairs(locales.enUS) do
      Assert.NotNil(locales.esES[key], "esES must have key: " .. tostring(key))
    end
  end)

  test("All esES keys exist in enUS locale", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    for key, _ in pairs(locales.esES) do
      Assert.NotNil(locales.enUS[key], "enUS must have key: " .. tostring(key))
    end
  end)

  test("All enUS keys exist in ptBR locale", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    Assert.NotNil(locales.ptBR, "ptBR locale must exist")

    for key, _ in pairs(locales.enUS) do
      Assert.NotNil(locales.ptBR[key], "ptBR must have key: " .. tostring(key))
    end
  end)

  test("All ptBR keys exist in enUS locale", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    for key, _ in pairs(locales.ptBR) do
      Assert.NotNil(locales.enUS[key], "enUS must have key: " .. tostring(key))
    end
  end)

  test("LOADED_HINT contains format placeholder in both locales", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    Assert.True(locales.enUS.LOADED_HINT:find("%%s") ~= nil, "enUS LOADED_HINT must contain %s placeholder")
    Assert.True(locales.deDE.LOADED_HINT:find("%%s") ~= nil, "deDE LOADED_HINT must contain %s placeholder")
  end)

  test("RAID_GROUP_HIDDEN is defined in both locales", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    Assert.NotNil(locales.enUS.RAID_GROUP_HIDDEN, "enUS must have RAID_GROUP_HIDDEN")
    Assert.NotNil(locales.deDE.RAID_GROUP_HIDDEN, "deDE must have RAID_GROUP_HIDDEN")
    Assert.True(
      type(locales.enUS.RAID_GROUP_HIDDEN) == "string" and #locales.enUS.RAID_GROUP_HIDDEN > 0,
      "enUS RAID_GROUP_HIDDEN must be non-empty string"
    )
    Assert.True(
      type(locales.deDE.RAID_GROUP_HIDDEN) == "string" and #locales.deDE.RAID_GROUP_HIDDEN > 0,
      "deDE RAID_GROUP_HIDDEN must be non-empty string"
    )
  end)

  test("Locale title key is present in all locales", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    Assert.Equal(locales.enUS.TITLE, "isiLive", "enUS TITLE must be present")
    Assert.Equal(locales.deDE.TITLE, "isiLive", "deDE TITLE must be present")
  end)

  test("Locale tag resolver returns enUS as default fallback", function()
    local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })

    Assert.Equal(addon.Locale.ResolveLocaleTag(nil), "enUS", "nil tag must default to enUS")
    Assert.Equal(addon.Locale.ResolveLocaleTag("fr"), "frFR", "fr tag must resolve to frFR")
    Assert.Equal(addon.Locale.ResolveLocaleTag("frfr"), "frFR", "frfr tag must resolve to frFR")
    Assert.Equal(addon.Locale.ResolveLocaleTag("de"), "deDE", "de tag must resolve to deDE")
    Assert.Equal(addon.Locale.ResolveLocaleTag("dede"), "deDE", "dede tag must resolve to deDE")
    Assert.Equal(addon.Locale.ResolveLocaleTag("en"), "enUS", "en tag must resolve to enUS")
    Assert.Equal(addon.Locale.ResolveLocaleTag("es"), "esES", "es tag must resolve to esES")
    Assert.Equal(addon.Locale.ResolveLocaleTag("eses"), "esES", "eses tag must resolve to esES")
    Assert.Equal(addon.Locale.ResolveLocaleTag("pt"), "ptBR", "pt tag must resolve to ptBR")
    Assert.Equal(addon.Locale.ResolveLocaleTag("ptbr"), "ptBR", "ptbr tag must resolve to ptBR")
    Assert.Equal(addon.Locale.ResolveLocaleTag("xx"), "enUS", "unsupported tag must fallback to enUS")
  end)

  test("Locale GetUnitServerLanguage skips missing units without UnitGUID or UnitIsUnit", function()
    WithGlobals({
      UnitExists = function(unit)
        return unit == "player"
      end,
      UnitGUID = function(_unit)
        error("UnitGUID must not be called for missing units")
      end,
      UnitIsUnit = function(_unit, _other)
        error("UnitIsUnit must not be called for missing units")
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })
      local language = addon.Locale.GetUnitServerLanguage("party1", "TestRealm", function()
        return nil
      end)

      Assert.Equal(language, "??", "missing units must resolve to unknown language without raw unit API calls")
    end)
  end)
end
