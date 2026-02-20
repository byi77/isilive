---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  test("All enUS keys exist in deDE locale", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    Assert.NotNil(locales.enUS, "enUS locale must exist")
    Assert.NotNil(locales.deDE, "deDE locale must exist")

    for key, _ in pairs(locales.enUS) do
      Assert.NotNil(
        locales.deDE[key],
        "deDE must have key: " .. tostring(key)
      )
    end
  end)

  test("All deDE keys exist in enUS locale", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    for key, _ in pairs(locales.deDE) do
      Assert.NotNil(
        locales.enUS[key],
        "enUS must have key: " .. tostring(key)
      )
    end
  end)

  test("LOADED_HINT contains format placeholder in both locales", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    Assert.True(
      locales.enUS.LOADED_HINT:find("%%s") ~= nil,
      "enUS LOADED_HINT must contain %s placeholder"
    )
    Assert.True(
      locales.deDE.LOADED_HINT:find("%%s") ~= nil,
      "deDE LOADED_HINT must contain %s placeholder"
    )
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

  test("Locale tag resolver returns enUS as default fallback", function()
    local addon = LoadAddonModules({ "isiLive_locale.lua" })

    Assert.Equal(addon.Locale.ResolveLocaleTag(nil), "enUS", "nil tag must default to enUS")
    Assert.Equal(addon.Locale.ResolveLocaleTag("fr"), "enUS", "unsupported tag must fallback to enUS")
    Assert.Equal(addon.Locale.ResolveLocaleTag("de"), "deDE", "de tag must resolve to deDE")
    Assert.Equal(addon.Locale.ResolveLocaleTag("dede"), "deDE", "dede tag must resolve to deDE")
    Assert.Equal(addon.Locale.ResolveLocaleTag("en"), "enUS", "en tag must resolve to enUS")
  end)
end
