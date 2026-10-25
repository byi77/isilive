-- Full Mythic+ run: group forms, keys sync, ready check, key start, kicks,
-- Bloodlust, a tank death with battle res, bosses, forces to 100%, timed
-- completion and the post-key state.
--
-- Party:
--   Isiplayer  (focus client, Fire Mage)         - isiLive, simulated
--   Velindra   (Restoration Druid, healer)       - isiLive, simulated (2nd client,
--              so BR / sync travel as real addon-message bytes)
--   Zidane     (Elemental Shaman)                - isiLive, simulated (casts Bloodlust)
--   Stormbreaker (Protection Warrior, tank)      - LibKeystone only (e.g. RaiderIO)
--   Ravencast  (Shadow Priest)                   - no addon
local KR = 249 -- King's Rest

return {
  name = "mplus_run",
  description = "Full M+ run: group sync, ready check, key start, kicks, lust, death + BR, timed completion",
  timeLimits = { [KR] = 33 * 60 },
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
        key = { mapID = KR, level = 14 },
      },
      {
        name = "Stormbreaker",
        realm = "Antonidas",
        class = "WARRIOR",
        specID = 73,
        role = "TANK",
        ilvl = 715,
        rating = 3188,
        key = { mapID = 250, level = 15 },
        addon = "libks",
      },
      {
        name = "Velindra",
        class = "DRUID",
        specID = 105,
        role = "HEALER",
        ilvl = 709,
        rating = 2990,
        key = { mapID = 399, level = 12 },
        simulate = true,
      },
      {
        name = "Zidane",
        realm = "Thrall",
        class = "SHAMAN",
        specID = 262,
        role = "DAMAGER",
        ilvl = 711,
        rating = 3050,
        key = { mapID = 584, level = 13 },
        simulate = true,
      },
      {
        name = "Ravencast",
        class = "PRIEST",
        specID = 258,
        role = "DAMAGER",
        ilvl = 704,
        rating = 2870,
        key = { mapID = 588, level = 10 },
        addon = "none",
      },
    },
  },
  run = function(sim)
    sim.Login()
    sim.Step("Login (solo)")

    sim.JoinGroup("Stormbreaker", "Velindra", "Zidane", "Ravencast")
    sim.Wait(1)
    sim.Step("Group formed")
    sim.Wait(8)
    sim.Step("Group synced (keys, stats)")
    sim.ExpectText("Stormbreaker", "tank listed in roster")
    sim.ExpectText("Velindra", "healer listed in roster")

    sim.ReadyCheck("Isiplayer", { Stormbreaker = true, Velindra = true, Zidane = true, Ravencast = true })
    sim.Wait(1)
    sim.Step("Ready check")
    sim.FinishReadyCheck()

    sim.EnterDungeon(KR)
    sim.Wait(3)
    sim.Step("Entered King's Rest")

    sim.StartKey({ mapID = KR, level = 14, bosses = { "Golden Serpent", "Mchimba", "Council of Tribes", "Dazar" } })
    sim.Wait(1)
    sim.Step("Key started (countdown)")
    sim.Wait(10)
    sim.Step("Timer running")

    sim.Combat(true)
    sim.Wait(5)
    sim.Cast("Isiplayer", 2139) -- Counterspell
    sim.Wait(1)
    sim.Cast("Zidane", 57994) -- Wind Shear
    sim.Wait(1)
    sim.Step("First pull: kicks")
    sim.Cast("Zidane", 2825) -- Bloodlust
    sim.Wait(2)
    sim.Step("Bloodlust")
    sim.KillForces(85)
    sim.Wait(20, 0.5)
    sim.Combat(false)
    sim.Wait(2)
    sim.Step("Pull 1 done (14%)")

    sim.Wait(180, 1)
    sim.Combat(true)
    sim.KillForces(110)
    sim.SetHealth("Stormbreaker", 0.2)
    sim.Wait(2)
    sim.Death("Stormbreaker")
    sim.Wait(1)
    sim.Step("Tank died")
    sim.Cast("Velindra", 20484) -- Rebirth
    sim.Wait(1)
    sim.Resurrect("Stormbreaker")
    sim.Wait(2)
    sim.Step("Battle res")
    sim.KillBoss(1)
    sim.Combat(false)
    sim.Wait(3)
    sim.Step("Boss 1 down")

    sim.Wait(420, 1)
    sim.KillForces(200)
    sim.KillBoss(2)
    sim.Wait(300, 1)
    sim.KillForces(150)
    sim.KillBoss(3)
    sim.Wait(2)
    sim.Step("3 bosses, ~89% forces")

    sim.Wait(240, 1)
    sim.KillForces(80)
    sim.Wait(1)
    sim.Step("Forces 100%")
    sim.KillBoss(4)
    sim.CompleteKey()
    sim.Wait(2)
    sim.Step("Key completed")
    sim.Wait(15)
    sim.Step("After key (new keystone)")
    sim.ExpectText("%+15", "upgraded keystone of the keyholder is shown")
  end,
}
