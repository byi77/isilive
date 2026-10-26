-- Regression: a /reload while the demo preview runs must not change the
-- user's settings.
--
-- Found 2026-10-26 (the M+ forces display mode kept switching from
-- "Namensplakette" to "Kurzinfo" without user action). The demo writes its
-- overrides into the saved IsiLiveDB, among them mobNameplateEnabled = true
-- AND mplusForcesEstimate = true. The pre-demo values lived only in memory, so
-- a /reload, logout or crash during the preview persisted the overrides, and
-- on the next load ApplyDBSettings read "both on" as the legacy tooltip setup
-- and switched the mode to tooltip ("Kurzinfo").
local function ForcesMode(db)
  if db.mobNameplateEnabled == true then
    return "nameplate"
  end
  if db.mplusForcesEstimate == true then
    return "tooltip"
  end
  return "off"
end

local function Db(sim)
  return sim.Env().IsiLiveDB or {}
end

return {
  name = "demo_reload_settings",
  description = "Regression: /reload during the demo preview keeps the user's settings",
  setup = {
    locale = "deDE",
    party = {
      { name = "Isiplayer", class = "MAGE", specID = 63, role = "DAMAGER", key = { mapID = 249, level = 12 } },
    },
  },
  run = function(sim)
    sim.Login()
    local db = Db(sim)
    -- User choices that differ from what the demo forces.
    db.mobNameplateEnabled = true
    db.mplusForcesEstimate = false
    db.deathAlertEnabled = false
    db.mobNameplateShowRemaining = nil
    sim.Step("Nameplate mode chosen")
    sim.Expect(ForcesMode(db) == "nameplate", "setup: forces mode is nameplate")

    sim.Slash("/il testall")
    sim.Wait(1)
    sim.Step("Demo preview running")
    sim.Expect(Db(sim).mplusForcesEstimate == true, "setup: the demo overrides the saved flags")

    sim.Reload()
    sim.Wait(1)
    sim.Step("After /reload during the demo")
    db = Db(sim)
    sim.Expect(ForcesMode(db) == "nameplate", "forces mode is still nameplate after the reload")
    sim.Expect(db.mplusForcesEstimate == false, "tooltip forces stay off")
    sim.Expect(db.deathAlertEnabled == false, "other demo-owned settings keep the user's value")
    sim.Expect(db.demoFeatureSnapshot == nil, "the persisted demo snapshot is consumed on load")

    -- A demo that ends normally restores the settings and leaves no snapshot.
    -- Combat start ends the preview; PLAYER_REGEN_DISABLED fires just before
    -- the lockdown begins, so it is fired here without entering combat.
    sim.Slash("/il testall")
    sim.Wait(1)
    sim.Expect(Db(sim).demoFeatureSnapshot ~= nil, "setup: the running demo keeps a persisted snapshot")
    sim.Fire("PLAYER_REGEN_DISABLED")
    sim.Fire("PLAYER_REGEN_ENABLED")
    sim.Wait(1)
    sim.Step("Demo started and ended normally")
    db = Db(sim)
    sim.Expect(ForcesMode(db) == "nameplate", "forces mode is nameplate after a normal demo exit")
    sim.Expect(db.demoFeatureSnapshot == nil, "a normal demo exit clears the persisted snapshot")
  end,
}
