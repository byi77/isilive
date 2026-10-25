-- Minimal scenario: a solo player logs in; snapshot of the idle UI.
return {
  name = "login",
  description = "Solo login, idle UI after startup",
  setup = {
    party = {
      {
        name = "Isiplayer",
        realm = "Blackrock",
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
    sim.Step("Login")
    sim.Wait(5)
    sim.Step("5s after login")
  end,
}
