-- Search in the config window (rule 241): typing in the title-band search box
-- filters the settings to matching controls plus their section heading,
-- English tags match in every language, several words must all match, the
-- nameplate preview follows hits in its block, an unknown word shows the
-- "no matches" hint, a language switch keeps the filter, ESC clears the
-- search first and closes the window second, and reopening shows everything.
local function Window(sim)
  return sim.Env().isiLiveConfigWindow
end

local function IsOpen(sim)
  local window = Window(sim)
  return window ~= nil and window:IsShown() == true
end

local function SearchBox(sim)
  local window = Window(sim)
  for _, widget in ipairs(sim.Client().engine.all) do
    if widget._type == "EditBox" and widget:GetParent() == window then
      return widget
    end
  end
  return nil
end

-- Types like a player: OnTextChanged per change, the filter runs after the
-- debounce on the simulated clock.
local function Type(sim, text)
  local box = SearchBox(sim)
  box:SetText(text)
  sim.Wait(1)
end

local function ClickLanguage(sim, tag)
  for _, widget in ipairs(sim.Client().engine.all) do
    if widget._languageTag == tag and widget:IsVisible() then
      widget:GetScript("OnClick")(widget, "LeftButton")
      return true
    end
  end
  return false
end

local function Visible(sim, pattern)
  return #sim.FindText(pattern) > 0
end

return {
  name = "config_search",
  description = "Config window search: filter, tags across languages, multi-word, preview, no matches, language, ESC",
  setup = {
    locale = "deDE",
    party = {
      { name = "Isiplayer", class = "MAGE", specID = 63, role = "DAMAGER", key = { mapID = 249, level = 12 } },
    },
  },
  run = function(sim)
    sim.Login()
    sim.Slash("/il settings")
    sim.Wait(1)
    sim.Expect(IsOpen(sim), "/il settings opens the config window")
    sim.Expect(SearchBox(sim) ~= nil, "the title band carries a search box")
    sim.ExpectText("^Optionen suchen%.%.%.$", "German search placeholder")
    sim.Step("Config window before a search")

    -- English tag on a German client.
    Type(sim, "interrupt")
    sim.Step("Search 'interrupt' (English tag, German client)")
    sim.ExpectText("^Kick: Hinweis bei Kick ins Leere$", "the missed-kick option matches its English tag")
    sim.ExpectText("^Kick ins Leere: nur im Key$", "every kick option matches")
    sim.Expect(not Visible(sim, "^Sprache$"), "unrelated options are hidden")
    sim.Expect(not Visible(sim, "^Beta$"), "sections without a hit lose their heading")

    -- Several words: all must match (section heading counts).
    Type(sim, "klang tank")
    sim.Step("Search 'klang tank' (two words)")
    sim.ExpectText("^Klanghinweis wenn der Tank stirbt$", "both words match the tank sound alert")
    sim.Expect(not Visible(sim, "Heiler stirbt$"), "the healer alert misses the word 'tank'")
    sim.ExpectText("^Klanghinweise$", "the section heading of the hit stays visible")

    -- Nameplate preview follows hits in its block.
    Type(sim, "versatz")
    sim.Step("Search 'versatz' (nameplate offsets with preview)")
    sim.ExpectText("^X%-Versatz$", "the nameplate X offset matches")
    sim.ExpectText("^Vorschau$", "the nameplate preview stays next to its options")

    -- Hearthstone dropdown stays usable while filtered.
    Type(sim, "hearthstone")
    sim.Step("Search 'hearthstone' (dropdown)")
    sim.ExpectText("^Ruhestein%-Auswahl$", "the hearthstone selection matches its English tag")
    local dropdown, menu = nil, nil
    for _, widget in ipairs(sim.Client().engine.all) do
      if widget._options ~= nil and widget:IsVisible() then
        dropdown = widget
      end
    end
    sim.Expect(dropdown ~= nil, "the hearthstone dropdown is visible in the filtered view")
    if dropdown then
      dropdown:GetScript("OnClick")(dropdown, "LeftButton")
      for _, widget in ipairs(sim.Client().engine.all) do
        local _, relativeTo = widget:GetPoint(1)
        if relativeTo == dropdown and widget:GetFrameStrata() == "DIALOG" then
          menu = widget
        end
      end
    end
    sim.Expect(menu ~= nil and menu:IsShown(), "the dropdown menu opens while filtered")
    sim.Step("Hearthstone dropdown open during the search")
    Type(sim, "minimap")
    sim.Expect(menu ~= nil and not menu:IsShown(), "filtering the dropdown away closes its menu")

    -- Nothing matches.
    Type(sim, "xyzzy")
    sim.Step("Search 'xyzzy' (no matches)")
    sim.ExpectText('Keine Option passt zu "xyzzy"', "the no-matches hint names the query")

    -- Language switch while a search is active: the filter runs again with
    -- the new labels (the English tag keeps the language row visible).
    Type(sim, "language")
    sim.Expect(ClickLanguage(sim, "enUS"), "the language buttons stay usable in the filtered view")
    sim.Wait(1)
    sim.Step("Language switched to English during the search 'language'")
    sim.ExpectText("^Language$", "the language row relabels and stays visible")
    sim.Expect(not Visible(sim, "^Sprache$"), "the old German label is gone")
    sim.Expect(not Visible(sim, "^Default layout"), "the filter still hides unrelated options")

    -- ESC: first clears the search, then closes the window.
    local box = SearchBox(sim)
    box:SetFocus()
    box:GetScript("OnEscapePressed")(box)
    sim.Wait(1)
    sim.Step("First ESC clears the search")
    sim.Expect(box:GetText() == "", "the first ESC empties the search box")
    sim.Expect(IsOpen(sim), "the first ESC keeps the window open")
    sim.ExpectText("^Default layout", "every option is back after clearing")
    box:GetScript("OnEscapePressed")(box)
    sim.Wait(1)
    sim.Expect(not IsOpen(sim), "the second ESC closes the window")

    -- Closing ends the search; reopening shows the full list.
    sim.Slash("/il settings")
    sim.Wait(1)
    Type(sim, "minimap")
    Window(sim):Hide()
    sim.Wait(1)
    sim.Slash("/il settings")
    sim.Wait(1)
    sim.Step("Reopened after closing with an active search")
    sim.Expect(SearchBox(sim):GetText() == "", "closing clears the search text")
    sim.ExpectText("^Language$", "reopening shows every option")
  end,
}
