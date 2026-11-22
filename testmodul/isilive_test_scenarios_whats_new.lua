---@diagnostic disable: undefined-global, undefined-field
-- What's new (rule 256, logic/isiLive_whats_new.lua). The login flows boot
-- the real factory through the stress fixture and pump PLAYER_LOGIN through
-- the real gated dispatcher; the card is the real center notice.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

-- The login flows add this entry as the newest one right after login, so
-- they do not depend on the shipped cards.
local TITLE_EN = "New: test feature"
local EXAMPLE_LINE = "Example value of the test feature"
local TEST_ENTRY = {
  id = "test_feature",
  titleKey = "WHATS_NEW_TEST_TITLE",
  titleFallback = TITLE_EN,
  fields = {
    { labelFallback = "What", valueFallback = EXAMPLE_LINE }, -- i18n-ok
  },
}

-- ShowPending reads the list when the login timer fires, so an entry added
-- right after PLAYER_LOGIN is the one the real flow shows.
local function AddTestEntry(session)
  local entries = session.addon.WhatsNew.ENTRIES
  entries[#entries + 1] = TEST_ENTRY
end

local function ShownTexts(session)
  local texts = {}
  for _, frame in ipairs(session.frames) do
    for _, fontString in ipairs(frame._fontStrings or {}) do
      local text = type(fontString.GetText) == "function" and fontString:GetText() or nil
      if type(text) == "string" and text ~= "" then
        texts[text] = true
      end
    end
  end
  return texts
end

local function FindFontString(session, text)
  for _, frame in ipairs(session.frames) do
    for _, fontString in ipairs(frame._fontStrings or {}) do
      if type(fontString.GetText) == "function" and fontString:GetText() == text then
        return fontString
      end
    end
  end
  return nil
end

local function SeenBefore(id)
  return function(globals)
    globals.IsiLiveDB.whatsNewSeen = id
  end
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  test("WhatsNew shows the newest feature card once after login and marks it seen", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local WhatsNew = session.addon.WhatsNew
      local db = session.globals.IsiLiveDB
      AddTestEntry(session)
      Assert.True(db.whatsNewSeen ~= WhatsNew.GetLatest().id, "the card is still pending right after login")
      Assert.Nil(ShownTexts(session)[TITLE_EN], "the card waits for the login delay")
      session.Advance(WhatsNew.LOGIN_DELAY_SECONDS)
      Assert.True(ShownTexts(session)[TITLE_EN] == true, "the card appears after the login delay")
      local label = FindFontString(session, "What")
      local value = FindFontString(session, EXAMPLE_LINE)
      Assert.NotNil(label, "the card shows the What label")
      Assert.NotNil(value, "the card shows the field value")
      local _, labelSize = label:GetFont()
      local _, valueSize = value:GetFont()
      Assert.True(valueSize < labelSize, "description values use the smaller compact font")
      Assert.Equal(db.whatsNewSeen, WhatsNew.GetLatest().id, "the shown card is marked seen")
    end)
  end)

  test("WhatsNew shows no card while the entry list is empty", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local WhatsNew = session.addon.WhatsNew
      for index = #WhatsNew.ENTRIES, 1, -1 do
        WhatsNew.ENTRIES[index] = nil
      end
      Assert.Nil(WhatsNew.GetPending(session.globals.IsiLiveDB), "nothing is pending")
      session.Advance(WhatsNew.LOGIN_DELAY_SECONDS + 5)
      Assert.Nil(session.globals.IsiLiveDB.whatsNewSeen, "no card was shown or marked seen")
    end)
  end)

  test("WhatsNew stays silent after login when the newest card was seen", function()
    Stress.WithParty(ctx, Fixture, function(session)
      AddTestEntry(session)
      session.Advance(session.addon.WhatsNew.LOGIN_DELAY_SECONDS + 5)
      Assert.Nil(ShownTexts(session)[TITLE_EN], "a seen card never comes back")
    end, SeenBefore(TEST_ENTRY.id))
  end)

  test("WhatsNew ships the voice announcement card in five languages", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local entry = session.addon.WhatsNew.GetLatest()
      Assert.Equal(entry.id, "voice_announcements", "the voice card is the newest entry")
      session.Advance(session.addon.WhatsNew.LOGIN_DELAY_SECONDS)
      Assert.True(ShownTexts(session)[entry.titleFallback] == true, "the card appears after login")
      Assert.Equal(session.globals.IsiLiveDB.whatsNewSeen, entry.id, "and is marked seen")
      for _, locale in ipairs({ "enUS", "deDE", "frFR", "ruRU", "trTR" }) do
        local handle = assert(io.open("locale/isiLive_texts_" .. locale .. ".lua", "r"))
        local source = handle:read("*a")
        handle:close()
        local keys = { entry.titleKey }
        for _, field in ipairs(entry.fields) do
          keys[#keys + 1] = field.labelKey
          keys[#keys + 1] = field.valueKey
        end
        for _, key in ipairs(keys) do
          Assert.NotNil(source:find("  " .. key .. " = ", 1, true), locale .. " has " .. key)
        end
      end
    end)
  end)

  test("WhatsNew shows again only for a newer entry", function()
    local WhatsNew = LoadAddonModules({ "isiLive_whats_new.lua" }).WhatsNew
    local shown = {}
    WhatsNew.ENTRIES[#WhatsNew.ENTRIES + 1] = TEST_ENTRY
    local db = { whatsNewSeen = WhatsNew.GetLatest().id }
    local controller = WhatsNew.Create({
      getDB = function()
        return db
      end,
      getL = function()
        return { WHATS_NEW_EYEBROW = "Neu in isiLive", NEXT_TITLE = "Neu: X" }
      end,
      showCenterNotice = function(message, duration, _, _, options)
        shown[#shown + 1] = { message = message, duration = duration, options = options }
      end,
      after = function(_, fn)
        fn()
      end,
    })
    Assert.False(controller.ShowPending(), "the seen entry is not shown")
    WhatsNew.ENTRIES[#WhatsNew.ENTRIES + 1] = { id = "next_feature", titleKey = "NEXT_TITLE", fields = {} }
    controller.OnLogin()
    controller.OnLogin()
    Assert.Equal(#shown, 1, "a newer entry is shown once per session")
    Assert.Equal(shown[1].options.title, "Neu: X", "the card uses the player's language")
    Assert.Equal(shown[1].options.eyebrow, "Neu in isiLive", "the eyebrow is localized")
    Assert.Equal(shown[1].duration, WhatsNew.DURATION_SECONDS, "the card stays for its duration")
    Assert.Equal(type(shown[1].options.rebuild), "function", "a language switch can rebuild the card")
    Assert.Equal(db.whatsNewSeen, "next_feature", "the newer entry is marked seen")
    Assert.False(controller.ShowPending(), "and is not shown again")
  end)
end
