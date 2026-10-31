-- Key end banner on the M+ killtracker row (rule 231), through the real events:
-- timed, over time, abandoned, group left, each looping until the status changes.
-- Walking out of the dungeon while the group stays is no key end.
local MAP_ID = 249
local TIMED = "Key in der Zeit"
local LATE = "Key über der Zeit"
local ABANDONED = "Key abgebrochen"
local LEFT = "Gruppe verlassen"
local ALL_TEXTS = { TIMED, LATE, ABANDONED, LEFT }

local function CountBanners(sim)
  local count = 0
  for _, text in ipairs(ALL_TEXTS) do
    count = count + #sim.FindText(text)
  end
  return count
end

local function ExpectBanner(sim, text, message)
  sim.Expect(#sim.FindText(text) == 1 and CountBanners(sim) == 1, message)
end

local function ExpectNoBanner(sim, message)
  sim.Expect(CountBanners(sim) == 0, message)
end

-- The frame directly holding the visible banner text.
local function FindBannerFrame(frame)
  for _, child in ipairs(frame._children or {}) do
    if child._isFrame then
      local hit = FindBannerFrame(child)
      if hit then
        return hit
      end
    elseif type(child.GetText) == "function" and child:GetText() == TIMED then
      return frame
    end
  end
  return nil
end

local function StartRunningKey(sim)
  sim.EnterDungeon(MAP_ID)
  sim.Wait(1)
  sim.StartKey({ mapID = MAP_ID, level = 14 })
  sim.Wait(12)
  ExpectNoBanner(sim, "no banner while the key runs")
end

return {
  name = "key_end_banner",
  description = "Key end banner: outcomes, loop until key start, new group or 60 s after leaving, reload",
  timeLimits = { [MAP_ID] = 33 * 60 },
  setup = {
    locale = "deDE",
    party = {
      { name = "Isiplayer", class = "MAGE", specID = 63, role = "DAMAGER", key = { mapID = MAP_ID, level = 14 } },
      { name = "Stormbreaker", class = "WARRIOR", specID = 73, role = "TANK", addon = "none" },
      { name = "Ravencast", class = "PRIEST", specID = 258, role = "DAMAGER", addon = "none" },
    },
  },
  run = function(sim)
    sim.Login()
    sim.JoinGroup("Stormbreaker", "Ravencast")
    -- The killtracker row lives in the M+ layout.
    sim.Slash("/il m2")
    sim.Wait(2)
    local frame = sim.Env().isiLiveMainFrame

    StartRunningKey(sim)
    sim.CompleteKey()
    sim.Wait(1)
    sim.Step("Timed: light sweep")
    ExpectBanner(sim, TIMED, "a timed key shows its banner")
    local banner = FindBannerFrame(frame)
    sim.Expect(banner ~= nil and banner._scripts.OnUpdate ~= nil, "the banner animates while it is shown")
    sim.Wait(30)
    sim.LeaveDungeon()
    sim.Wait(1)
    sim.Step("30 s later, outside the dungeon")
    ExpectBanner(sim, TIMED, "the banner loops through time and zoning")
    sim.Wait(30)
    sim.Step("Same group, no new key, 61 s after the key end")
    ExpectNoBanner(sim, "the banner ends after 60 seconds while the group stays")
    sim.Expect(banner ~= nil and banner._scripts.OnUpdate == nil, "no OnUpdate is left after the banner")

    -- A new key ends a standing banner at once.
    StartRunningKey(sim)
    sim.CompleteKey()
    sim.Wait(1)
    ExpectBanner(sim, TIMED, "the next key end shows its banner")
    sim.LeaveDungeon()
    sim.Wait(1)
    sim.EnterDungeon(MAP_ID)
    sim.Wait(1)
    sim.StartKey({ mapID = MAP_ID, level = 14 })
    sim.Wait(1)
    sim.Step("New key started")
    ExpectNoBanner(sim, "a new key ends the banner at once")
    sim.Wait(11)
    sim.CompleteKey({ onTime = false })
    sim.Wait(1)
    sim.Step("Over time: red pulse")
    ExpectBanner(sim, LATE, "a key over time shows its banner")
    sim.LeaveDungeon()
    sim.Wait(1)

    StartRunningKey(sim)
    sim.ResetKey()
    sim.Wait(1)
    sim.Step("Abandoned: colour drains")
    ExpectBanner(sim, ABANDONED, "an abandoned key shows its banner")
    sim.LeaveDungeon()
    sim.Wait(1)

    -- Walking out is no key end: the key goes on for the group.
    StartRunningKey(sim)
    sim.LeaveDungeon()
    sim.Wait(1)
    sim.Step("Left the dungeon, group stays")
    ExpectNoBanner(sim, "walking out of the dungeon shows no banner")
    sim.Wait(1)

    -- The challenge map stays active after leaving the group.
    StartRunningKey(sim)
    sim.LeaveGroup("Isiplayer")
    sim.Wait(1)
    sim.Step("Group left, still in the dungeon")
    ExpectBanner(sim, LEFT, "leaving the group shows its banner at once")
    sim.LeaveDungeon()
    sim.Wait(50)
    sim.Step("50 s after leaving the group")
    ExpectBanner(sim, LEFT, "the banner still stands inside the 60 seconds")
    sim.Wait(11)
    sim.Step("61 s after leaving the group")
    ExpectNoBanner(sim, "the left banner ends after 60 seconds")

    -- A finished key, then the group changes.
    sim.JoinGroup("Stormbreaker", "Ravencast")
    sim.Wait(2)
    StartRunningKey(sim)
    sim.CompleteKey()
    sim.Wait(1)
    sim.LeaveGroup("Isiplayer")
    sim.Wait(30)
    ExpectBanner(sim, TIMED, "the outcome stands 30 s after leaving the group")
    sim.JoinGroup("Stormbreaker", "Ravencast")
    sim.Wait(1)
    sim.Step("New group joined")
    ExpectNoBanner(sim, "a joined group ends the banner at once")
    sim.LeaveDungeon()
    sim.Wait(1)

    -- A closed window pauses the banner, however long.
    sim.Env().IsiLiveDB.autoOpenMainFrameOnKeyEnd = false
    StartRunningKey(sim)
    frame:Hide()
    sim.CompleteKey()
    sim.Wait(30)
    frame:Show()
    sim.Wait(0.5)
    sim.Step("Window opened 30 s after the key end")
    ExpectBanner(sim, TIMED, "a window opened later still shows the outcome")
    sim.LeaveDungeon()
    sim.Wait(1)

    sim.Env().IsiLiveDB.autoOpenMainFrameOnKeyEnd = true
    sim.Slash("/il keyend late")
    sim.Wait(1)
    sim.Step("Preview command")
    ExpectBanner(sim, LATE, "the preview command shows the banner")
    sim.Slash("/il keyend off")
    sim.Wait(1)
    ExpectNoBanner(sim, "the preview ends with off")
    sim.Slash("/il keyend timed")
    sim.Wait(61)
    ExpectNoBanner(sim, "a preview banner ends after 60 seconds as well")
    sim.Slash("/il keyend nonsense")
    sim.Wait(1)
    ExpectNoBanner(sim, "an unknown outcome plays nothing")
    sim.ExpectLog("print", "keyend timed", nil, "an unknown outcome prints the usage")

    StartRunningKey(sim)
    sim.CompleteKey()
    sim.Wait(1)
    ExpectBanner(sim, TIMED, "the outcome stands before the reload")
    sim.Reload()
    sim.Wait(2)
    sim.Step("After a reload")
    ExpectNoBanner(sim, "a reload ends the banner")
  end,
}
