---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  test("StringUtils.Trim removes leading and trailing whitespace", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    Assert.Equal(addon.StringUtils.Trim("  hello  "), "hello", "must trim both sides")
    Assert.Equal(addon.StringUtils.Trim("hello"), "hello", "must leave clean string unchanged")
    Assert.Equal(addon.StringUtils.Trim("  "), "", "whitespace-only must become empty")
    Assert.Equal(addon.StringUtils.Trim("\t\n hello \n\t"), "hello", "must trim tabs and newlines")
  end)

  test("StringUtils.Trim handles non-string inputs gracefully", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    Assert.Equal(addon.StringUtils.Trim(nil), "", "nil must return empty string")
    Assert.Equal(addon.StringUtils.Trim(123), "", "number must return empty string")
    Assert.Equal(addon.StringUtils.Trim(true), "", "boolean must return empty string")
  end)

  test("StringUtils.StripWhitespace removes all whitespace", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    Assert.Equal(addon.StringUtils.StripWhitespace("a b c"), "abc", "must remove internal spaces")
    Assert.Equal(addon.StringUtils.StripWhitespace("  a  b  "), "ab", "must remove all whitespace")
    Assert.Equal(addon.StringUtils.StripWhitespace("abc"), "abc", "no-space string must be unchanged")
  end)

  test("StringUtils.StripWhitespace handles non-string inputs gracefully", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    Assert.Equal(addon.StringUtils.StripWhitespace(nil), "", "nil must return empty string")
    Assert.Equal(addon.StringUtils.StripWhitespace(42), "", "number must return empty string")
  end)

  test("StringUtils.NormalizeRealmName strips spaces, dashes, dots, parens, and quotes", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    Assert.Equal(addon.StringUtils.NormalizeRealmName("Der Rat von Dalaran"), "DerRatvonDalaran", "must strip spaces")
    Assert.Equal(addon.StringUtils.NormalizeRealmName("Mal'Ganis"), "MalGanis", "must strip single quotes")
    Assert.Equal(addon.StringUtils.NormalizeRealmName("Area-52"), "Area52", "must strip dashes")
    Assert.Equal(
      addon.StringUtils.NormalizeRealmName("Test.Realm(EU)`s"),
      "TestRealmEUs",
      "must strip dots, parens, and backticks"
    )
  end)

  test("StringUtils.NormalizeRealmName handles non-string inputs gracefully", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    Assert.Equal(addon.StringUtils.NormalizeRealmName(nil), "", "nil must return empty string")
    Assert.Equal(addon.StringUtils.NormalizeRealmName(99), "", "number must return empty string")
  end)

  test("StringUtils.NormalizeRealmName matches canonical pattern used by Sync and Stats", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    -- Verify the exact same characters are stripped as in the canonical pattern [%s%-%.%(%)'`]
    local input = "A B-C.D(E)F'G`H"
    local expected = "ABCDEFGH"
    Assert.Equal(
      addon.StringUtils.NormalizeRealmName(input),
      expected,
      "must strip exactly the canonical character set"
    )
  end)

  test("StringUtils.IsBlank returns true for nil, empty string, and non-strings", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    Assert.Equal(addon.StringUtils.IsBlank(nil), true, "nil must be blank")
    Assert.Equal(addon.StringUtils.IsBlank(""), true, "empty string must be blank")
    Assert.Equal(addon.StringUtils.IsBlank(0), true, "number must be blank (non-string)")
    Assert.Equal(addon.StringUtils.IsBlank(false), true, "false must be blank (non-string)")
    Assert.Equal(addon.StringUtils.IsBlank({}), true, "table must be blank (non-string)")
  end)

  test("StringUtils.IsBlank returns false for any non-empty string", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    Assert.Equal(addon.StringUtils.IsBlank("x"), false, "single char must not be blank")
    Assert.Equal(addon.StringUtils.IsBlank(" "), false, "whitespace-only is intentionally NOT blank")
    Assert.Equal(addon.StringUtils.IsBlank("hello"), false, "regular string must not be blank")
  end)

  test("StringUtils.BuildQualifiedName returns nil when name is blank or non-string", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    Assert.Equal(addon.StringUtils.BuildQualifiedName(nil, "Realm"), nil, "nil name must yield nil")
    Assert.Equal(addon.StringUtils.BuildQualifiedName("", "Realm"), nil, "empty name must yield nil")
    Assert.Equal(addon.StringUtils.BuildQualifiedName(123, "Realm"), nil, "non-string name must yield nil")
  end)

  test("StringUtils.BuildQualifiedName returns bare name when realm is blank", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    Assert.Equal(addon.StringUtils.BuildQualifiedName("Felix", nil), "Felix", "nil realm yields bare name")
    Assert.Equal(addon.StringUtils.BuildQualifiedName("Felix", ""), "Felix", "empty realm yields bare name")
    Assert.Equal(addon.StringUtils.BuildQualifiedName("Felix", 0), "Felix", "non-string realm yields bare name")
  end)

  test("StringUtils.BuildQualifiedName joins name and realm with a dash for cross-realm", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    Assert.Equal(
      addon.StringUtils.BuildQualifiedName("Felix", "Tichondrius"),
      "Felix-Tichondrius",
      "name + realm joined with dash"
    )
    Assert.Equal(
      addon.StringUtils.BuildQualifiedName("Anna", "TwistingNether"),
      "Anna-TwistingNether",
      "compound realm name preserved as-is"
    )
  end)

  test("StringUtils.BuildQualifiedName preserves UTF-8 multi-byte names byte-for-byte", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    -- ü = \195\188 (0xC3 0xBC); ç = \195\167; ı = \196\177
    Assert.Equal(
      addon.StringUtils.BuildQualifiedName("M\195\188ller", ""),
      "M\195\188ller",
      "UTF-8 same-realm passthrough"
    )
    Assert.Equal(
      addon.StringUtils.BuildQualifiedName("\195\135a\196\159r\196\177", "Tichondrius"),
      "\195\135a\196\159r\196\177-Tichondrius",
      "UTF-8 cross-realm passthrough"
    )
  end)

  test("StringUtils.BuildSlashTargetName strips realm suffix when it matches the home realm", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    Assert.Equal(
      addon.StringUtils.BuildSlashTargetName("Pella", "Stormrage", "Stormrage"),
      "Pella",
      "matching home realm must drop the suffix so /target acquires the local-realm unit"
    )
    Assert.Equal(
      addon.StringUtils.BuildSlashTargetName("Pella", "Twisting Nether", "Twisting Nether"),
      "Pella",
      "matching home realm with a space must still strip cleanly"
    )
  end)

  test("StringUtils.BuildSlashTargetName keeps the realm suffix for cross-realm units", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    Assert.Equal(
      addon.StringUtils.BuildSlashTargetName("Felix", "Tichondrius", "Stormrage"),
      "Felix-Tichondrius",
      "different realm must retain the cross-realm suffix"
    )
  end)

  test("StringUtils.BuildSlashTargetName returns bare name when realm is blank", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    Assert.Equal(
      addon.StringUtils.BuildSlashTargetName("Felix", "", "Stormrage"),
      "Felix",
      "empty realm short-circuits before any home-realm comparison"
    )
    Assert.Equal(
      addon.StringUtils.BuildSlashTargetName("Felix", nil, "Stormrage"),
      "Felix",
      "nil realm short-circuits before any home-realm comparison"
    )
  end)

  test("StringUtils.BuildSlashTargetName falls back to GetRealmName when no homeRealm arg is passed", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    local previousGetRealmName = rawget(_G, "GetRealmName")
    rawset(_G, "GetRealmName", function()
      return "Stormrage"
    end)
    Assert.Equal(
      addon.StringUtils.BuildSlashTargetName("Pella", "Stormrage"),
      "Pella",
      "must consult GetRealmName when caller does not pass homeRealm explicitly"
    )
    Assert.Equal(
      addon.StringUtils.BuildSlashTargetName("Cross", "Tichondrius"),
      "Cross-Tichondrius",
      "different realm via GetRealmName fallback must keep the suffix"
    )
    rawset(_G, "GetRealmName", previousGetRealmName)
  end)

  test("StringUtils.BuildSlashTargetName returns nil when name is blank", function()
    local addon = LoadAddonModules({ "isiLive_string_utils.lua" })
    Assert.Equal(
      addon.StringUtils.BuildSlashTargetName(nil, "Stormrage", "Stormrage"),
      nil,
      "missing name must yield nil so the macro builder skips the click entirely"
    )
    Assert.Equal(addon.StringUtils.BuildSlashTargetName("", "Stormrage", "Stormrage"), nil, "empty name must yield nil")
  end)
end
