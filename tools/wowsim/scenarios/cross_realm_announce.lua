-- Regression: BR / Bloodlust / Power Infusion announces from a cross-realm
-- isiLive peer must reach the other isiLive clients.
--
-- The caster names itself through GetUnitName("player", true), which carries
-- no realm. Up to 0.9.453 the receiver normalized that bare name with its own
-- realm, so every announce from a cross-realm caster was dropped silently.
-- Found with wowsim on 2026-10-25 (mplus_run: Zidane-Thrall's Bloodlust never
-- reached Isiplayer-Blackrock, the same-realm battle res did); fixed in
-- 0.9.454 on both ends (sender qualifies the name, receiver resolves bare
-- names against the sender's realm).
return {
  name = "cross_realm_announce",
  description = "Regression: BR / Lust announces from a cross-realm peer reach the group",
  setup = {
    party = {
      { name = "Isiplayer", class = "MAGE", specID = 63, role = "DAMAGER", key = { mapID = 249, level = 12 } },
      {
        name = "Velindra",
        realm = "Antonidas",
        class = "DRUID",
        specID = 105,
        role = "HEALER",
        key = { mapID = 250, level = 12 },
        simulate = true,
      },
      {
        name = "Zidane",
        realm = "Thrall",
        class = "SHAMAN",
        specID = 262,
        role = "DAMAGER",
        key = { mapID = 399, level = 12 },
        simulate = true,
      },
      -- Same realm as Velindra: control case for the battle res below.
      {
        name = "Stormbreaker",
        realm = "Antonidas",
        class = "WARRIOR",
        specID = 73,
        role = "TANK",
        simulate = true,
      },
    },
  },
  run = function(sim)
    sim.Login()
    sim.JoinGroup("Velindra", "Zidane", "Stormbreaker")
    sim.Wait(8)
    sim.StartKey({ mapID = 249, level = 12 })
    sim.Wait(12)
    sim.Combat(true)

    local t = sim.Now()
    sim.Cast("Zidane", 2825) -- Bloodlust, caster on Thrall
    sim.Wait(1)
    sim.Step("Cross-realm Bloodlust")
    sim.ExpectLog("print", "Zidane", "Isiplayer", "Blackrock receiver shows Thrall caster's Bloodlust", t)
    sim.ExpectLog("print", "Zidane", "Velindra", "Antonidas receiver shows Thrall caster's Bloodlust", t)

    sim.Death("Stormbreaker")
    t = sim.Now()
    sim.Cast("Velindra", 20484) -- Rebirth, caster on Antonidas
    sim.Wait(1)
    sim.Step("Cross-realm battle res")
    sim.ExpectLog("print", "Velindra", "Isiplayer", "Blackrock receiver shows Antonidas caster's BR", t)
    sim.ExpectLog("print", "Velindra", "Stormbreaker", "same-realm receiver shows Antonidas caster's BR", t)
  end,
}
