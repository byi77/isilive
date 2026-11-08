-- Own config window (rule 237): /il settings opens isiLive's window instead of
-- Blizzard's Settings panel; the Blizzard category is a searchable stub whose
-- button closes the Settings panel and opens the window. Covers open, close,
-- ESC registration, the stub (search + click), position persistence across a
-- reload, opening in combat, and language / design switches while open.
local function Window(sim)
  return sim.Env().isiLiveConfigWindow
end

local function IsOpen(sim)
  local window = Window(sim)
  return window ~= nil and window:IsShown() == true
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

local function ClickOption(sim, value)
  for _, widget in ipairs(sim.Client().engine.all) do
    if widget._optionValue == value and widget:IsVisible() then
      widget:GetScript("OnClick")(widget, "LeftButton")
      return true
    end
  end
  return false
end

return {
  name = "config_window",
  description = "Own config window: open/close/ESC, Blizzard stub search + button, position, combat, language/design",
  setup = {
    locale = "deDE",
    party = {
      { name = "Isiplayer", class = "MAGE", specID = 63, role = "DAMAGER", key = { mapID = 249, level = 12 } },
    },
  },
  run = function(sim)
    sim.Login()
    local env = sim.Env()
    sim.Expect(Window(sim) ~= nil, "the config window exists after login")
    sim.Expect(not IsOpen(sim), "the config window starts closed")
    local escapeRegistered = false
    for _, name in ipairs(env.UISpecialFrames) do
      if name == "isiLiveConfigWindow" then
        escapeRegistered = true
      end
    end
    sim.Expect(escapeRegistered, "ESC closes the config window (UISpecialFrames)")

    sim.Slash("/il settings")
    sim.Wait(1)
    sim.Step("Config window (/il settings)")
    sim.Expect(IsOpen(sim), "/il settings opens the config window")
    sim.Expect(not env.SettingsPanel:IsShown(), "Blizzard's Settings panel stays closed")
    sim.ExpectText("^Konfiguration$", "German window title")
    sim.ExpectText("^Allgemein$", "the settings sections are built on the first open")
    sim.Expect(Window(sim):GetFrameStrata() == "HIGH", "the window sits above the main frame strata")

    -- Blizzard search finds the stub, not the canvas content.
    local matches = env.Settings._SearchInitializers("isilive")
    sim.Expect(#matches >= 1, "Blizzard settings search finds the isiLive stub")
    sim.Expect(#env.Settings._SearchInitializers("konfiguration") >= 1, "the localized stub label is searchable")

    -- Stub: open Blizzard's panel on the isiLive category, click the button.
    Window(sim):Hide()
    env.Settings.OpenToCategory(matches[1].category.ID)
    sim.Wait(1)
    sim.Step("Blizzard settings stub")
    sim.ExpectText("Alle isiLive%-Optionen liegen in einem eigenen Fenster", "stub hint in German")
    sim.Click("^Konfig öffnen$")
    sim.Wait(1)
    sim.Step("Stub button clicked")
    sim.Expect(IsOpen(sim), "the stub button opens the config window")
    sim.Expect(not env.SettingsPanel:IsShown(), "the stub button closes Blizzard's Settings panel")

    -- Position: a drag on the title band stores the drop point.
    local window = Window(sim)
    local handle = nil
    for _, widget in ipairs(sim.Client().engine.all) do
      if widget:GetParent() == window and widget:GetScript("OnDragStart") then
        handle = widget
      end
    end
    sim.Expect(handle ~= nil, "the title band is a drag handle")
    if handle then
      handle:GetScript("OnDragStart")(handle)
      window:ClearAllPoints()
      window:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 120, -90)
      handle:GetScript("OnDragStop")(handle)
    end
    local stored = env.IsiLiveDB.configWindowPosition
    sim.Expect(
      type(stored) == "table" and stored.point == "TOPLEFT" and stored.x == 120 and stored.y == -90,
      "the drop point is saved in IsiLiveDB.configWindowPosition"
    )

    -- Language and design switch while open.
    sim.Expect(ClickLanguage(sim, "enUS"), "language button enUS exists in the open window")
    sim.Wait(1)
    sim.Step("Language switched to English while open")
    sim.ExpectText("^Configuration$", "window title follows the language at once")
    sim.ExpectText("^General$", "section navigation follows the language at once")
    sim.Expect(ClickOption(sim, "classic"), "design option classic exists in the open window")
    sim.Wait(1)
    sim.Step("Classic design while open")
    sim.Expect(env.IsiLiveDB.uiDesign == "classic", "design switch from the open window is stored")
    sim.Expect(ClickOption(sim, "modern"), "design option modern exists in the open window")
    sim.Wait(1)
    sim.Step("Modern design again while open")

    -- Reload: the window comes back closed and reopens at the saved place.
    sim.Reload()
    sim.Wait(1)
    sim.Expect(not IsOpen(sim), "after a reload the config window is closed")
    sim.Slash("/il settings")
    sim.Wait(1)
    local point, _, relativePoint, x, y = Window(sim):GetPoint()
    sim.Expect(
      point == "TOPLEFT" and relativePoint == "TOPLEFT" and x == 120 and y == -90,
      "the config window reopens at the saved position after a reload"
    )
    sim.Step("Reopened after reload")

    -- Combat: the window is not protected and opens in combat.
    Window(sim):Hide()
    sim.Combat(true)
    sim.Slash("/il settings")
    sim.Wait(1)
    sim.Step("Opened in combat")
    sim.Expect(IsOpen(sim), "the config window opens in combat")
    sim.Combat(false)
  end,
}
