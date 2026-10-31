-- Dungeon names, abbreviations and invite card texts follow the addon language,
-- never the client: the demo runs on a deDE client, the language switches to
-- enUS and back through the real settings button. Every open surface must
-- relabel at once. Temple of Sethraliss is the target because name and
-- abbreviation differ between both languages (Tempel von Sethraliss, TVS / TOS).
-- Run with --locale enUS for the reverse direction: the client stays English and
-- the addon goes German and back.
local function SwitchLanguage(sim, tag)
  sim.Slash("/il settings")
  sim.Wait(1)
  local clicked = false
  for _, widget in ipairs(sim.Client().engine.all) do
    if widget._languageTag == tag then
      widget:GetScript("OnClick")(widget, "LeftButton")
      clicked = true
    end
  end
  sim.Expect(clicked, "language button " .. tag .. " exists")
  sim.Env().SettingsPanel:Hide()
  sim.Wait(1)
end

local function CheckGerman(sim, label)
  sim.Step(label)
  sim.ExpectText("TVS %+14", "German abbreviation in the roster key column")
  sim.ExpectText("^Tempel von Sethraliss$", "German name in the open portal navigator")
  sim.ExpectText("^Rubinlebensbecken$", "second navigator slot in German")
  sim.ExpectText("^Unbelegt$", "navigator detail text in German")
  sim.ExpectText("Tempel von Sethraliss %+14", "German name on the invite card and killtracker")
  sim.ExpectText("^Quelle$", "invite card label in German")
  sim.ExpectText("^Simulations%-Tablet$", "invite card value in German")
  sim.ExpectText("^Talente$", "invite card loadout row in German")
  sim.Expect(#sim.FindText("Temple of Sethraliss") == 0, "no English dungeon name left")
end

local function CheckEnglish(sim, label)
  sim.Step(label)
  sim.ExpectText("TOS %+14", "English abbreviation in the roster key column")
  sim.ExpectText("^Temple of Sethraliss$", "English name in the open portal navigator")
  sim.ExpectText("^Ruby Life Pools$", "second navigator slot in English")
  sim.ExpectText("^Unoccupied$", "navigator detail text in English")
  sim.ExpectText("Temple of Sethraliss %+14", "English name on the invite card and killtracker")
  sim.ExpectText("^Source$", "invite card label in English")
  sim.ExpectText("^Simulation tablet$", "invite card value in English")
  sim.ExpectText("^Talents$", "invite card loadout row in English")
  sim.Expect(#sim.FindText("Tempel von Sethraliss") == 0, "no German dungeon name left")
  -- A German client must not leak its map names; on an English client they are
  -- the right ones and the simulator answers with its stub map.
  if sim.Env().GetLocale() == "deDE" then
    sim.ExpectText("Vol'dun\nPortal Millennia's Threshold", "English zone and portal room on the invite card")
    sim.Expect(#sim.FindText("Dornogal") == 0, "no client map name left on the card")
  end
  sim.Expect(#sim.FindText("TVS") == 0, "no German abbreviation left")
  sim.Expect(#sim.FindText("^Quelle$") == 0, "no German invite label left")
end

return {
  name = "language_dungeon_names",
  description = "Dungeon names, abbreviations and card texts follow the addon language on a deDE client",
  setup = {
    locale = "deDE",
    party = {
      {
        name = "Isiplayer",
        class = "MAGE",
        specID = 63,
        role = "DAMAGER",
        ilvl = 712,
        rating = 3120,
        key = { mapID = 250, level = 14 },
      },
      { name = "Stormbreaker", class = "WARRIOR", specID = 73, role = "TANK", addon = "none" },
    },
  },
  run = function(sim)
    sim.Login()
    sim.Slash("/il testall")
    sim.Wait(2)
    if sim.Env().GetLocale() == "deDE" then
      CheckGerman(sim, "Demo on a deDE client, addon German")
      SwitchLanguage(sim, "enUS")
      CheckEnglish(sim, "Switched to English during the demo")
      SwitchLanguage(sim, "deDE")
      CheckGerman(sim, "Switched back to German during the demo")
    else
      CheckEnglish(sim, "Demo on an enUS client, addon English")
      SwitchLanguage(sim, "deDE")
      CheckGerman(sim, "Switched to German during the demo")
      SwitchLanguage(sim, "enUS")
      CheckEnglish(sim, "Switched back to English during the demo")
    end

    -- Running and finished key: the bar holds the mapID, not a stored name.
    -- Combat start ends the preview, as in demo_reload_settings.
    sim.Fire("PLAYER_REGEN_DISABLED")
    sim.Fire("PLAYER_REGEN_ENABLED")
    sim.Wait(1)
    SwitchLanguage(sim, "deDE")
    sim.JoinGroup("Stormbreaker")
    sim.EnterDungeon(250)
    sim.StartKey({ mapID = 250, level = 12, bosses = { "Boss" } })
    sim.Wait(2)
    sim.Step("Key running, addon German")
    sim.ExpectText("^Tempel von Sethraliss$", "running key on the bar in German")
    SwitchLanguage(sim, "enUS")
    sim.Step("Key running, switched to English")
    sim.ExpectText("^Temple of Sethraliss$", "running key on the bar follows the switch")
    sim.Expect(#sim.FindText("Tempel von Sethraliss") == 0, "no German name left during the key")
    sim.CompleteKey()
    sim.Wait(2)
    SwitchLanguage(sim, "deDE")
    sim.Step("Key finished, switched to German")
    sim.ExpectText("^Tempel von Sethraliss$", "finished key on the bar follows the switch")
    sim.Expect(#sim.FindText("Temple of Sethraliss") == 0, "no English name left after the key")
  end,
}
