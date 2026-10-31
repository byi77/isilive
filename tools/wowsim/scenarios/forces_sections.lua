-- Forces sections on the killtracker bar: a dungeon without a learned route
-- runs on the start values of data/isiLive_forces_seed.lua, which change with
-- every data refresh: only the last section has a fixed target of 100.
return {
  name = "forces_sections",
  description = "Forces sections: start values, later ticks, last section at 100",
  setup = {
    locale = "deDE",
    party = {
      { name = "Isiplayer", class = "MAGE", specID = 63, role = "DAMAGER", ilvl = 712, rating = 3120 },
      { name = "Stormbreaker", class = "WARRIOR", specID = 73, role = "TANK", addon = "none" },
    },
  },
  run = function(sim)
    sim.Login()
    sim.JoinGroup("Stormbreaker")
    sim.EnterDungeon(586)
    sim.StartKey({ mapID = 586, level = 12, bosses = { "The Hoardmonger", "Sentinel of Winter", "Nalorakk" } })
    sim.Wait(2)
    sim.KillForces(146)
    sim.Wait(2)
    sim.Step("Short of the first section")
    sim.ExpectText("%-%d+,%d%%", "delta to the first start value")
    sim.ExpectText("Benötigt noch %d+,%d+%% in diesem Abschnitt", "missing forces next to the TTK")

    sim.KillForces(80)
    sim.Wait(2)
    sim.KillBoss(1)
    sim.Wait(2)
    sim.Step("Boss 1 dead, next section")
    sim.ExpectText("%-%d+,%d%%", "delta to the second start value")

    sim.KillBoss(2)
    sim.Wait(2)
    sim.Step("Last section targets 100%")
    sim.ExpectText("%-69,0%%", "delta to full forces")
  end,
}
