-- Time pace badge on the killtracker bar (rule 208): during a running key the
-- bar shows no dungeon name, only forces and the badge. The badge says in one
-- word whether the key makes it (IN TIME / KNAPP / ZU LANGSAM on deDE) with
-- the unsigned margin. During a fight the answer moves only on kills: a stall
-- without kills holds it, the next kill charges the lost time.
local MAP_ID = 586

return {
  name = "time_pace_badge",
  description = "Time pace badge: on time, a long fight that holds until a kill, too slow",
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
    sim.Wait(600)
    sim.Step("Long fight without kills: answer holds")
    sim.ExpectText("IN TIME %d+:%d%d", "without kills the fight keeps the answer from before the pull")

    sim.KillForces(5)
    sim.Wait(2)
    sim.Step("A kill after the stall: the lost time counts")
    -- 24:50 ahead before the fight; the stall of 600 s is charged, the kill's
    -- own forces are credited at the tempo before the pull.
    sim.ExpectText("IN TIME 14:%d%d", "the kill charges the stalled ten minutes")

    sim.Wait(900)
    sim.Combat(false)
    sim.Wait(4)
    sim.Step("Fight over without kills: too slow")
    sim.ExpectText("ZU LANGSAM %d+:%d%d", "after the fight the slow pace reads ZU LANGSAM")
  end,
}
