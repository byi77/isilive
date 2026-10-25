-- UI tour: the addon's own preview surfaces, for layout checks without a
-- group. Full dummy preview (/il testall), the simulation tablet (/il sim)
-- and the settings panel (/il settings), in the scenario locale.
return {
  name = "ui_tour",
  description = "Layout tour: dummy preview, simulation tablet, settings panel",
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
        key = { mapID = 249, level = 14 },
      },
    },
  },
  run = function(sim)
    sim.Login()
    sim.Step("Idle after login")
    -- Fresh install (no SavedVariables) on a German client must start German.
    sim.ExpectText("Keys teilen", "fresh install follows the deDE client locale")

    sim.Slash("/il sim")
    sim.Wait(1)
    sim.Step("Simulation tablet (/il sim)")
    sim.Slash("/il sim")

    sim.Slash("/il settings")
    sim.Wait(1)
    sim.Step("Settings panel (/il settings)")
    sim.Env().SettingsPanel:Hide()

    -- The full preview opens every surface at once, the tablet included.
    sim.Slash("/il testall")
    sim.Wait(2)
    sim.Step("Full dummy preview (/il testall)")
  end,
}
