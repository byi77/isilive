-- Season break and unknown season (rule 250).
--
-- Between two seasons Blizzard runs no Mythic+ season; only Normal, Heroic
-- and M0 are playable. The scenario drives the challenge map list the way the
-- client delivers it (CHALLENGE_MODE_MAPS_UPDATE after the server answer):
--   1. empty list -> season break: one chat line, a heroic dungeon
--      shows the calm 30 s card instead of the blinking warning, heroic runs
--      the full runtime profile;
--   2. a map set no configured season knows -> one chat line asking for an
--      update, no repeat on the next map update;
--   3. the real season set again -> active.
local DEN_OF_NALORAKK = 586
local HEROIC_DIFFICULTY_ID = 2

local function SetMapTable(sim, list)
  sim.world.mapTable = list
  sim.Fire("CHALLENGE_MODE_MAPS_UPDATE")
  sim.Wait(1)
end

local function EnterHeroic(sim, mapID)
  local info = sim.world.challengeMaps[mapID]
  sim.world.instance = {
    name = info.name,
    mapID = mapID,
    instanceID = 2000 + mapID,
    type = "party",
    difficultyID = HEROIC_DIFFICULTY_ID,
  }
  sim.Fire("PLAYER_ENTERING_WORLD", false, false)
  sim.Fire("ZONE_CHANGED_NEW_AREA")
end

return {
  name = "offseason",
  description = "Season break: chat line, calm heroic card, heroic full profile; unknown season: one update notice",
  setup = {
    locale = "enUS",
    party = {
      { name = "Isiplayer", class = "MAGE", specID = 63, role = "DAMAGER", ilvl = 712, rating = 3120 },
    },
  },
  run = function(sim)
    sim.Login()
    local addon = sim.Client().addonTable
    sim.Slash("/il show")
    sim.Wait(2)
    sim.Step("Login in season")
    sim.Expect(addon.SeasonData.GetBlizzardSeasonState() ~= "offseason", "a normal login is no season break")

    SetMapTable(sim, {})
    sim.Step("Season break: empty map list")
    sim.Expect(addon.SeasonData.IsOffSeason(), "an empty server map list is the season break")
    -- The status line is hidden in the locked M+ layout (rule 249); the chat
    -- line is the visible signal.
    sim.ExpectLog("print", "season break %- no Mythic%+ season is running", nil, "the chat announces the season break")

    EnterHeroic(sim, DEN_OF_NALORAKK)
    sim.Wait(4)
    sim.Step("Heroic dungeon during the season break")
    sim.ExpectText("Season break %- no Mythic%+ possible", "the dungeon card is the calm season-break hint")
    sim.Expect(#sim.FindText("Not a Mythic%+ dungeon") == 0, "the blinking warning row is gone")
    sim.Expect(addon.RuntimeMode.Resolve() == "KEY", "heroic runs the full profile during the season break")

    sim.LeaveDungeon()
    sim.Wait(2)
    local since = sim.Now()
    SetMapTable(sim, { 9991, 9992 })
    sim.Step("Unknown season map set")
    sim.Expect(addon.SeasonData.IsSeasonUnrecognized(), "an unknown map set is an unrecognized season")
    sim.ExpectLog("print", "does not know the current Mythic%+ season", nil, "the chat asks for an update", since)
    SetMapTable(sim, { 9991, 9992 })
    sim.Expect(
      #sim.FindLog("print", "does not know the current Mythic%+ season", nil, since) == 1,
      "the update notice appears once per session"
    )
    sim.Expect(addon.SeasonData.GetActiveSeasonID() == "midnight_s2", "the active season stays the fallback")

    SetMapTable(sim, nil)
    sim.Step("Season map set again")
    sim.Expect(addon.SeasonData.GetBlizzardSeasonState() == "active", "the real season set is active again")
    sim.Expect(addon.RuntimeMode.Resolve() == "IDLE", "outside a dungeon the reduced profile returns")
  end,
}
