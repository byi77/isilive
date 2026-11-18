---@diagnostic disable: undefined-global, undefined-field
-- What's new (rule 256, logic/isiLive_whats_new.lua). The login flows boot
-- the real factory through the stress fixture and pump PLAYER_LOGIN through
-- the real gated dispatcher; the card is the real center notice.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

local TITLE_EN = "New: post the pace to your group"

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
      Assert.True(db.whatsNewSeen ~= WhatsNew.GetLatest().id, "the card is still pending right after login")
      Assert.Nil(ShownTexts(session)[TITLE_EN], "the card waits for the login delay")
      session.Advance(WhatsNew.LOGIN_DELAY_SECONDS)
      Assert.True(ShownTexts(session)[TITLE_EN] == true, "the card appears after the login delay")
      local label = FindFontString(session, "What")
      local value = FindFontString(session, "KR +15 expected: INTIME - 1:12 spare. Go for it! (via isiLive M+Addon)")
      Assert.NotNil(label, "the card shows the What label")
      Assert.NotNil(value, "the card shows the English example line")
      local _, labelSize = label:GetFont()
      local _, valueSize = value:GetFont()
      Assert.True(valueSize < labelSize, "description values use the smaller compact font")
      Assert.Equal(db.whatsNewSeen, WhatsNew.GetLatest().id, "the shown card is marked seen")
    end)
  end)

  test("WhatsNew stays silent after login when the newest card was seen", function()
    Stress.WithParty(ctx, Fixture, function(session)
      session.Advance(session.addon.WhatsNew.LOGIN_DELAY_SECONDS + 5)
      Assert.Nil(ShownTexts(session)[TITLE_EN], "a seen card never comes back")
    end, SeenBefore("time_pace_announce"))
  end)

  test("WhatsNew shows again only for a newer entry", function()
    local WhatsNew = LoadAddonModules({ "isiLive_whats_new.lua" }).WhatsNew
    local shown = {}
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
