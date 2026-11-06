-- Time pace badge on the killtracker bar (rule 208): during a running key the
-- bar shows no dungeon name, only forces and the badge. The badge says in one
-- word whether the key makes it (IN TIME / KNAPP / ZU LANGSAM on deDE) with
-- the unsigned margin; a fight turns it grey with a pause sign and keeps the
-- answer from before the pull until the pull's kills are counted.
local MAP_ID = 586

return {
  name = "time_pace_badge",
  description = "Time pace badge: on time, too slow, frozen grey with pause sign in a fight",
  timeLimits = { [MAP_ID] = 30 * 60 },
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
    sim.EnterDungeon(MAP_ID)
    sim.StartKey({ mapID = MAP_ID, level = 12, bosses = { "The Hoardmonger", "Sentinel of Winter", "Nalorakk" } })
    sim.Wait(90)
    sim.KillForces(120)
    sim.KillBoss(1)
    sim.Wait(2)
    sim.Step("Fast start: on time")
    sim.ExpectText("IN TIME %d+:%d%d", "a fast start reads IN TIME with the margin")

    sim.Combat(true)
    sim.Wait(1500)
    sim.Step("Long fight: answer frozen")
    sim.ExpectText("IN TIME %d+:%d%d", "a fight keeps the answer from before the pull")

    sim.Combat(false)
    sim.Wait(4)
    sim.Step("Fight over without kills: too slow")
    sim.ExpectText("ZU LANGSAM %d+:%d%d", "after the fight the slow pace reads ZU LANGSAM")
  end,
}
