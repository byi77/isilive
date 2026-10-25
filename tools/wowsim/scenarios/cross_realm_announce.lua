-- Regression: BR / Bloodlust / Power Infusion announces from a cross-realm
-- isiLive peer must reach the other isiLive clients.
--
-- The caster broadcasts "BRLUST:<kind>:<caster>:<spellID>" with its own name
-- from GetUnitName("player", true), which carries no realm for the local
-- player. The receiver accepts the payload only when the caster name
-- normalizes to the sender key; on a different realm the bare name picks up
-- the receiver's realm and the announce is dropped silently.
-- Found with wowsim on 2026-10-25 (mplus_run: Zidane-Thrall's Bloodlust never
-- reached Isiplayer-Blackrock, the same-realm battle res did).
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
