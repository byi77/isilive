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

  test("Locale texts aggregator loadfile fallback loads split locale tables", function()
    local realLoadfile = loadfile
    local loadedFiles = {}
    local addonTable = {}

    WithGlobals({
      loadfile = function(path)
        loadedFiles[#loadedFiles + 1] = path
        return assert(realLoadfile(path))
      end,
    }, function()
      local chunk = assert(realLoadfile("locale/isiLive_texts.lua"))
      chunk("isiLive", addonTable)
    end)

    local locales = addonTable.Texts.GetLocaleTables()
    Assert.True(#loadedFiles >= 9, "standalone fallback should load the split locale files")
    Assert.NotNil(locales.enUS, "loadfile fallback should provide enUS texts")
    Assert.Equal(locales.enUS.SETTINGS_SOUND_CHANNEL_MASTER, "Master", "aggregator should add Master label")
    Assert.Equal(locales.enUS.SETTINGS_SOUND_CHANNEL_SFX, "SFX", "aggregator should add SFX label")
  end)

  test("Locale texts aggregator stays empty when no locale source is available", function()
    local realLoadfile = loadfile
    local addonTable = {}

    WithGlobals({
      loadfile = false,
    }, function()
      local chunk = assert(realLoadfile("locale/isiLive_texts.lua"))
      chunk("isiLive", addonTable)
    end)

    local locales = addonTable.Texts.GetLocaleTables()
    Assert.Equal(next(locales), nil, "missing preloaded locales and loadfile must produce an empty table")
  end)

  test("LOADED_HINT contains format placeholder in both locales", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    Assert.True(locales.enUS.LOADED_HINT:find("%%s") ~= nil, "enUS LOADED_HINT must contain %s placeholder")
    Assert.True(locales.deDE.LOADED_HINT:find("%%s") ~= nil, "deDE LOADED_HINT must contain %s placeholder")
  end)

  test("Format placeholder counts match enUS across all locales", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    -- string.format crashes at runtime if a locale has a different %s/%d count
    -- than the call site expects. Guard against silent placeholder drift by
    -- comparing every translated string against its enUS counterpart.
    local function countPlaceholders(s)
      local count = 0
      for _ in s:gmatch("%%[sd]") do
        count = count + 1
      end
      return count
    end

    for localeName, localeTable in pairs(locales) do
      if localeName ~= "enUS" then
        for key, enValue in pairs(locales.enUS) do
          local translated = localeTable[key]
          if type(enValue) == "string" and type(translated) == "string" then
            local enCount = countPlaceholders(enValue)
            local trCount = countPlaceholders(translated)
            Assert.Equal(
              trCount,
              enCount,
              localeName
                .. "."
                .. tostring(key)
                .. " has "
                .. tostring(trCount)
                .. " %s/%d placeholders but enUS has "
                .. tostring(enCount)
                .. ': enUS="'
                .. enValue
                .. '" '
                .. localeName
                .. '="'
                .. translated
                .. '"'
            )
          end
        end
      end
    end
  end)

  test("Locale title key is present in all locales", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    Assert.Equal(locales.enUS.TITLE, "isiLive", "enUS TITLE must be present")
    Assert.Equal(locales.deDE.TITLE, "isiLive", "deDE TITLE must be present")
  end)

  test("Locale center-notice titles use isiLive prefix in every locale", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()
    local titleKeys = {
      "PORTAL_NAVIGATOR_TITLE",
      "INVITE_ACCEPTED_NOTICE_TITLE",
      "INVITE_ACCEPTED_RAID_NOTICE_TITLE",
    }

    for localeName, localeTable in pairs(locales) do
      for _, key in ipairs(titleKeys) do
        local value = localeTable[key]
        Assert.Equal(type(value), "string", localeName .. "." .. key .. " must be a string title")
        Assert.True(
          value:find("isiLive - ", 1, true) == 1,
          localeName .. "." .. key .. ' must start with "isiLive - ": ' .. tostring(value)
        )
      end
    end
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

  test("enUS values must not contain German-only stopwords", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    -- Words that are unambiguously German and must never appear in English text.
    -- Catches accidental cross-locale copy/paste like CHAT_QUEUE_PREFIX
    -- ("Warteschlangenbeitritt") leaking into the enUS table.
    local germanStopwords = {
      "Warteschlange",
      "Schlüssel",
      "Hauptfenster",
      "Befehle",
      "Sprache",
      "Gesperrt",
      "Entsperr",
      "Einstellung",
      "Gruppe",
      "Bereit",
      "Gilde",
      "Charakter",
      "Berufe",
      "Talente",
      "Zauber",
      "Erfolge",
      "Sammlung",
      "Ruhestein",
      "ä",
      "ö",
      "ü",
      "Ä",
      "Ö",
      "Ü",
      "ß",
    }

    for key, value in pairs(locales.enUS) do
      if type(value) == "string" then
        for _, stopword in ipairs(germanStopwords) do
          Assert.True(
            value:find(stopword, 1, true) == nil,
            "enUS." .. tostring(key) .. ' contains German stopword "' .. stopword .. '": ' .. tostring(value)
          )
        end
      end
    end
  end)

  test("deDE values must not contain English-only stopwords", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    -- Words that are unambiguously English and must never appear in German text.
    -- Whitelist of keys that legitimately keep English shared terms (technical
    -- WoW vocabulary, slash commands, brand names).
    local englishStopwordKeyAllowlist = {
      HELP_HEADER = true,
      HELP_ADMIN = true,
      HELP_TESTALL = true,
      HELP_TPTEST = true,
      HELP_TPDEBUG = true,
      HELP_NPTEST = true,
      HELP_NPSTATE = true,
      HELP_LOG = true,
      HELP_QDEBUG = true,
      HELP_ERRORLOG = true,
      HELP_LOCK = true,
      HELP_UNLOCK = true,
      HELP_RESETUI = true,
      HELP_BINDCHECK = true,
      HELP_RESET = true,
      -- Proper nouns: WoW dungeon names stay English in every locale.
      TESTALL_DUMMY_DUNGEON = true,
    }

    local englishStopwords = {
      " the ",
      " and ",
      " with ",
      " from ",
      " your ",
    }

    for key, value in pairs(locales.deDE) do
      if type(value) == "string" and not englishStopwordKeyAllowlist[key] then
        local lowered = " " .. value:lower() .. " "
        for _, stopword in ipairs(englishStopwords) do
          Assert.True(
            lowered:find(stopword, 1, true) == nil,
            "deDE." .. tostring(key) .. ' contains English stopword "' .. stopword .. '": ' .. tostring(value)
          )
        end
      end
    end
  end)

  test("German settings stats-box descriptions are localized", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()
    local deDE = locales.deDE or {}

    Assert.Equal(
      deDE.SETTINGS_STATS_BOX_ENABLED_DESC,
      "Zeigt eine separate verschiebbare Statsbox mit deinen Echtzeit-Spielerwerten.",
      "deDE stats-box enabled description must not fall back to English"
    )
    Assert.Equal(
      deDE.SETTINGS_STATS_BOX_LOCKED_DESC,
      "Verhindert das Ziehen der Statsbox.",
      "deDE stats-box lock description must not fall back to English"
    )
    Assert.Equal(
      deDE.SETTINGS_STATS_BOX_BG_ALPHA_DESC,
      "Passt die Hintergrund-Deckkraft der Statsbox an.",
      "deDE stats-box opacity description must not fall back to English"
    )
    Assert.Equal(
      deDE.SETTINGS_STATS_BOX_FONT_SIZE_OFFSET_DESC,
      "Passt die Textgroesse der Statsbox an.",
      "deDE stats-box font-size description must not fall back to English"
    )
    Assert.Equal(
      deDE.SETTINGS_STATS_BOX_DISPLAY_MODE_DESC,
      "Waehlt, ob die Statsbox Werte, Prozente oder beides anzeigt.",
      "deDE stats-box display-mode description must not fall back to English"
    )
    Assert.Equal(deDE.SETTINGS_STATS_BOX_SHOW_DURABILITY, "Haltbarkeit", "deDE durability setting label")
    Assert.Equal(deDE.SETTINGS_STATS_BOX_SHOW_STAMINA, "Ausdauer", "deDE stamina setting label")
  end)

  test("Locale LFG group-bonus settings strings support prepared fallbacks and post-edited translations", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()
    local enUS = locales.enUS or {}
    local deDE = locales.deDE or {}
    local ruRU = locales.ruRU or {}

    Assert.Equal(
      enUS.SETTINGS_LFG_GROUP_BONUSES,
      "Group Finder: Buff rating hearts",
      "enUS LFG group-bonus setting label must describe the heart rating"
    )
    Assert.True(
      type(enUS.SETTINGS_LFG_GROUP_BONUSES_DESC) == "string"
        and enUS.SETTINGS_LFG_GROUP_BONUSES_DESC:find("heart_bonus_green:10:10", 1, true) ~= nil
        and enUS.SETTINGS_LFG_GROUP_BONUSES_DESC:find("Atrophic Poison.", 1, true) ~= nil,
      "enUS LFG group-bonus setting description must show fixed-size green heart texture examples"
    )
    Assert.Equal(
      deDE.SETTINGS_LFG_GROUP_BONUSES,
      "Gruppensuche: Buff-Rating-Herzen",
      "deDE LFG group-bonus setting label must be German"
    )
    Assert.True(
      type(deDE.SETTINGS_LFG_GROUP_BONUSES_DESC) == "string"
        and deDE.SETTINGS_LFG_GROUP_BONUSES_DESC:find("heart_bonus_green:10:10", 1, true) ~= nil
        and deDE.SETTINGS_LFG_GROUP_BONUSES_DESC:find("Atrophisches Gift", 1, true) ~= nil,
      "deDE LFG group-bonus setting description must show fixed-size green heart texture examples in German"
    )
    for localeName, localeTable in pairs(locales) do
      Assert.True(
        type(localeTable.SETTINGS_LFG_GROUP_BONUSES) == "string" and localeTable.SETTINGS_LFG_GROUP_BONUSES ~= "",
        localeName .. " LFG group-bonus setting label must be prepared"
      )
      Assert.True(
        type(localeTable.SETTINGS_LFG_GROUP_BONUSES_DESC) == "string"
          and localeTable.SETTINGS_LFG_GROUP_BONUSES_DESC:find("heart_bonus_green:10:10", 1, true) ~= nil,
        localeName .. " LFG group-bonus setting description must use fixed-size green heart textures"
      )
      Assert.True(
        localeTable.SETTINGS_LFG_GROUP_BONUSES_DESC:find("♥", 1, true) == nil,
        localeName .. " LFG group-bonus setting description must not use unstable font heart glyphs"
      )
    end
    Assert.True(
      type(ruRU.SETTINGS_LFG_GROUP_BONUSES_DESC) == "string"
        and ruRU.SETTINGS_LFG_GROUP_BONUSES_DESC:find("Атрофический яд", 1, true) ~= nil,
      "ruRU post-edited LFG group-bonus setting description must be accepted"
    )
  end)

  test("Locale sound-channel settings strings support prepared translations", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()
    local enUS = locales.enUS or {}
    local deDE = locales.deDE or {}

    Assert.Equal(
      enUS.SETTINGS_SOUND_CHANNEL,
      "Sound output channel",
      "enUS sound-channel setting label must describe the output channel"
    )
    Assert.Equal(deDE.SETTINGS_SOUND_CHANNEL, "Klangkanal", "deDE sound-channel setting label must be German")

    for localeName, localeTable in pairs(locales) do
      Assert.True(
        type(localeTable.SETTINGS_SOUND_CHANNEL) == "string" and localeTable.SETTINGS_SOUND_CHANNEL ~= "",
        localeName .. " sound-channel setting label must be prepared"
      )
      Assert.True(
        type(localeTable.SETTINGS_SOUND_CHANNEL_DESC) == "string" and localeTable.SETTINGS_SOUND_CHANNEL_DESC ~= "",
        localeName .. " sound-channel setting description must be prepared"
      )
      Assert.Equal(localeTable.SETTINGS_SOUND_CHANNEL_MASTER, "Master", localeName .. " Master option label")
      Assert.Equal(localeTable.SETTINGS_SOUND_CHANNEL_SFX, "SFX", localeName .. " SFX option label")
      if localeName ~= "enUS" then
        Assert.False(
          localeTable.SETTINGS_SOUND_CHANNEL_DESC == enUS.SETTINGS_SOUND_CHANNEL_DESC,
          localeName .. " sound-channel description must not fall back to English"
        )
      end
    end
  end)

  test("Full-width action button labels exist for fitted rendering", function()
    local addon = LoadAddonModules({ "isiLive_texts.lua" })
    local locales = addon.Texts.GetLocaleTables()

    -- Long localized labels are accepted here because SetFlatButtonText fits
    -- flat-button labels to their fixed button width at render time.
    local fullWidthActionButtonKeys = {
      "BTN_READYCHECK",
      "BTN_COUNTDOWN10",
      "BTN_COUNTDOWN_CANCEL",
      "BTN_REFRESH",
      "BTN_SHARE_KEYS",
    }

    local localeNames = { "enUS", "deDE", "frFR", "esES", "ptBR", "itIT", "ruRU", "trTR" }
    for _, localeName in ipairs(localeNames) do
      local localeTable = locales[localeName]
      if localeTable then
        for _, key in ipairs(fullWidthActionButtonKeys) do
          local value = localeTable[key]
          Assert.True(
            type(value) == "string" and value ~= "",
            localeName .. "." .. key .. " must be a non-empty string"
          )
        end
      end
    end
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

  -- ----------------------------------------------------------------------
  -- Branch coverage: language flag/markup/name helpers and realm-locale
  -- lookup paths.
  -- ----------------------------------------------------------------------

  test("Locale.GetLanguageNameTables returns the LANGUAGE_NAME_BY_LOCALE map", function()
    local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })
    local tables = addon.Locale.GetLanguageNameTables()
    Assert.True(type(tables) == "table", "must return a table")
    Assert.True(type(tables.enUS) == "table", "must include enUS row")
    Assert.True(type(tables.deDE) == "table", "must include deDE row")
  end)

  test("Locale.LocaleToLanguageTag returns '??' for nil input", function()
    local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })
    Assert.Equal(addon.Locale.LocaleToLanguageTag(nil), "??", "nil locale must resolve to '??'")
  end)

  test("Locale.LocaleToLanguageTag normalizes dashed locales and resolves supported tags", function()
    local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })
    Assert.Equal(addon.Locale.LocaleToLanguageTag("de-DE"), "DE", "dash-separated locale must normalize")
    Assert.Equal(addon.Locale.LocaleToLanguageTag("en"), "EN", "alias 'en' must resolve to 'EN'")
    Assert.Equal(addon.Locale.LocaleToLanguageTag("kokr"), "KR", "extra locale 'kokr' must resolve to 'KR'")
  end)

  test("Languages ResolveTag accepts canonical tags and dashed aliases", function()
    local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })
    Assert.Equal(addon.Languages.ResolveTag("frFR"), "frFR", "canonical supported locale must resolve directly")
    Assert.Equal(addon.Languages.ResolveTag("de-DE"), "deDE", "dashed supported locale must normalize")
    Assert.Equal(addon.Languages.ResolveTag("unknown"), "enUS", "unknown locale must fall back to enUS")
  end)

  test("Languages IsSupported distinguishes supported aliases and unknown tags", function()
    local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })
    Assert.False(addon.Languages.IsSupported(nil), "nil must not be reported as supported")
    Assert.True(addon.Languages.IsSupported("de"), "command alias must be supported")
    Assert.True(addon.Languages.IsSupported("deDE"), "canonical locale must be supported")
    Assert.True(addon.Languages.IsSupported("pt-BR"), "dashed locale must be supported")
    Assert.False(addon.Languages.IsSupported("zhCN"), "unprepared locale must not be supported")
  end)

  test("Locale.LocaleToLanguageTag resolves from static lookup without iterating supported languages", function()
    local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })
    addon.Languages.SUPPORTED = setmetatable({}, {
      __index = function()
        error("LocaleToLanguageTag must not iterate supported languages on the tooltip hot path")
      end,
    })

    Assert.Equal(addon.Locale.LocaleToLanguageTag("deDE"), "DE", "canonical deDE must resolve from static lookup")
    Assert.Equal(addon.Locale.LocaleToLanguageTag("ru-RU"), "RU", "dashed ruRU must resolve from static lookup")
    Assert.Equal(addon.Locale.LocaleToLanguageTag("zhCN"), "CN", "extra locale must resolve from static lookup")
  end)

  test("Locale.GetLanguageFlagTexturePath returns nil for unknown languages", function()
    local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })
    Assert.Nil(addon.Locale.GetLanguageFlagTexturePath("ZZ"), "unknown tag must return nil texture path")
    Assert.Nil(addon.Locale.GetLanguageFlagTexturePath(nil), "nil tag must return nil texture path")
  end)

  test("Locale.GetLanguageFlagMarkup returns texture markup when texture exists, gray text otherwise", function()
    local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })
    local deMarkup = addon.Locale.GetLanguageFlagMarkup("DE")
    Assert.True(deMarkup:find("|T", 1, true) ~= nil, "DE flag must render as a |T texture markup")
    local krMarkup = addon.Locale.GetLanguageFlagMarkup("KR")
    Assert.True(krMarkup:find("|cffbfbfbf", 1, true) ~= nil, "KR (no texture asset) must fall back to gray text")
    Assert.True(krMarkup:find("KR", 1, true) ~= nil, "fallback markup must include the language tag")
  end)

  test("Locale.GetLanguageDisplayName looks up the localized name and falls back to the tag", function()
    local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })
    -- Forcing a known display locale; the result must be a non-empty string.
    local nameDE = addon.Locale.GetLanguageDisplayName("DE", "enUS")
    Assert.True(type(nameDE) == "string" and nameDE ~= "", "DE display name in enUS must be set")
    -- Unknown tag should fall back to the tag itself.
    Assert.Equal(
      addon.Locale.GetLanguageDisplayName("ZZ", "enUS"),
      "ZZ",
      "unknown language tag must fall back to itself"
    )
  end)

  test("Locale.GetLanguageTooltipMarkup combines flag and display name", function()
    local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })
    local markup = addon.Locale.GetLanguageTooltipMarkup("DE", "enUS")
    Assert.True(type(markup) == "string", "tooltip markup must be a string")
    Assert.True(markup:find("|T", 1, true) ~= nil, "tooltip markup must include flag texture")
  end)

  test("Locale.NormalizeRealmLookupKey returns empty string for nil input", function()
    local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })
    Assert.Equal(addon.Locale.NormalizeRealmLookupKey(nil), "", "nil realm must normalize to empty string")
  end)

  test("Locale.NormalizeRealmLookupKey strips whitespace + punctuation and lowercases", function()
    local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })
    Assert.Equal(
      addon.Locale.NormalizeRealmLookupKey("Twisting Nether"),
      "twistingnether",
      "spaces must be stripped, casing lowered"
    )
    Assert.Equal(
      addon.Locale.NormalizeRealmLookupKey("Aegwynn-Nethersturm"),
      "aegwynnnethersturm",
      "dashes must be stripped, casing lowered"
    )
  end)

  test("Locale.GetRealmLocaleFromStaticData returns nil for blank realm", function()
    local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })
    Assert.Nil(addon.Locale.GetRealmLocaleFromStaticData(""), "blank realm must return nil")
    Assert.Nil(addon.Locale.GetRealmLocaleFromStaticData(nil), "nil realm must return nil")
  end)

  test("Locale.GetRealmLocaleFromStaticData uses exact-name lookup when present", function()
    local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })
    addon.RealmData = {
      IsiLiveRealmLocaleByExactName = {
        ["aegwynn"] = "deDE",
      },
      IsiLiveRealmLocaleByNormalizedName = {
        someothernormalized = "frFR",
      },
    }
    Assert.Equal(
      addon.Locale.GetRealmLocaleFromStaticData("Aegwynn"),
      "deDE",
      "exact-lookup hit must be returned (case-folded)"
    )
  end)

  test("Locale.GetRealmLocaleFromStaticData falls back to normalized lookup when exact misses", function()
    local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua" })
    addon.RealmData = {
      IsiLiveRealmLocaleByExactName = {},
      IsiLiveRealmLocaleByNormalizedName = {
        ["twistingnether"] = "enGB",
      },
    }
    Assert.Equal(
      addon.Locale.GetRealmLocaleFromStaticData("Twisting Nether"),
      "enGB",
      "normalized lookup must catch space-and-case variations"
    )
  end)
end
