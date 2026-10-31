-- Regression: the M+ killtracker keeps the target dungeon and its key level
-- after entering the dungeon.
--
-- Found 2026-10-28: entering the target dungeon runs CheckIfEnteredTargetDungeon,
-- which clears the LFG and queue target so the teleport hints go away. The
-- killtracker read the same status target, so the dungeon name, key level,
-- gold bar and light sweep vanished on entry, and the running key showed no
-- dungeon either. A finished key keeps its dungeon and level until the player
-- leaves the dungeon.
local KINGS_REST_MAP_ID = 249
local KINGS_REST_ACTIVITY_ID = 514
local LISTING_LEADER = "Sagehd-Ravencrest"
local PARTY_NAMES = { "Sagehd", "Tankone", "Healone", "Dpsone" }

local function InstallLfgList(sim, status)
  local lfgList = sim.Env().C_LFGList
  lfgList.GetSearchResultInfo = function(searchResultID)
    if status[searchResultID] == nil then
      return nil
    end
    return {
      searchResultID = searchResultID,
      activityIDs = { KINGS_REST_ACTIVITY_ID },
      leaderName = LISTING_LEADER,
      name = "Königsruh +15",
      numMembers = 4,
    }
  end
  lfgList.GetActivityInfoTable = function(activityID)
    if activityID ~= KINGS_REST_ACTIVITY_ID then
      return nil
    end
    return { mapID = 1762, isMythicPlusActivity = true, categoryID = 2, fullName = "Königsruh" }
  end
  lfgList.GetApplications = function()
    local ids = {}
    for searchResultID in pairs(status) do
      ids[#ids + 1] = searchResultID
    end
    table.sort(ids)
    return ids
  end
  lfgList.GetApplicationInfo = function(searchResultID)
    return searchResultID, status[searchResultID], nil
  end
end

local function SetStatus(sim, status, searchResultID, newStatus)
  status[searchResultID] = newStatus
  sim.Fire("LFG_LIST_APPLICATION_STATUS_UPDATED", searchResultID, newStatus, nil, "|Kt635|k")
end

local function CollectTexts(frame, out)
  for _, child in ipairs(frame._children or {}) do
    if child:IsVisible() then
      if child._isFrame then
        CollectTexts(child, out)
      elseif type(child.GetText) == "function" then
        local text = child:GetText()
        if type(text) == "string" and text ~= "" then
          out[#out + 1] = text
        end
      end
    end
  end
  return out
end

local function FindKillTrackBox(frame)
  for _, child in ipairs(frame._children or {}) do
    if not child._isFrame and type(child.GetText) == "function" and child:GetText() == "M+Tracker" then
      return frame
    end
    if child._isFrame then
      local hit = FindKillTrackBox(child)
      if hit then
        return hit
      end
    end
  end
  return nil
end

-- Visible texts on the killtracker row, joined by "|".
local function KillTrackText(sim)
  local box = FindKillTrackBox(sim.Env().isiLiveMainFrame)
  if not box then
    return ""
  end
  return table.concat(CollectTexts(box, {}), "|")
end

local function ExpectRow(sim, pattern, message)
  local text = KillTrackText(sim)
  sim.Expect(text:find(pattern) ~= nil, message .. " (row: " .. text .. ")")
end

local function ExpectNoTarget(sim, message)
  local text = KillTrackText(sim)
  sim.Expect(text:find("Königsruh", 1, true) == nil, message .. " (row: " .. text .. ")")
end

return {
  name = "killtrack_dungeon_entry",
  description = "Regression: killtracker keeps dungeon and key level from dungeon entry until leaving",
  setup = {
    locale = "deDE",
    party = {
      {
        name = "Isiplayer",
        class = "ROGUE",
        specID = 261,
        role = "DAMAGER",
        ilvl = 330,
        rating = 3310,
        key = { mapID = 584, level = 13 },
      },
      { name = "Sagehd", realm = "Ravencrest", class = "HUNTER", specID = 253, role = "DAMAGER", addon = "none" },
      { name = "Tankone", class = "WARRIOR", specID = 73, role = "TANK", addon = "none" },
      { name = "Healone", class = "PRIEST", specID = 257, role = "HEALER", addon = "none" },
      { name = "Dpsone", class = "MAGE", specID = 63, role = "DAMAGER", addon = "none" },
    },
  },
  run = function(sim)
    sim.Login()
    -- The killtracker row lives in the M+ layout.
    sim.Slash("/il m2")
    sim.SetLeader("Sagehd")
    sim.Wait(2)

    local status = {}
    InstallLfgList(sim, status)
    SetStatus(sim, status, 101, "applied")
    sim.Wait(1)
    SetStatus(sim, status, 101, "invited")
    sim.Wait(2)
    SetStatus(sim, status, 101, "inviteaccepted")
    sim.Wait(0.1)
    sim.focus.member.inGroup = true
    for _, name in ipairs(PARTY_NAMES) do
      sim.Member(name).inGroup = true
    end
    sim.Fire("GROUP_ROSTER_UPDATE")
    sim.Fire("PARTY_LEADER_CHANGED")
    sim.Wait(6)
    sim.Step("Invite accepted")
    ExpectRow(sim, "Königsruh|%+15", "target dungeon and level on the bar before entry")

    sim.EnterDungeon(KINGS_REST_MAP_ID)
    sim.Wait(3)
    sim.Step("Entered the dungeon")
    ExpectRow(sim, "Königsruh|%+15", "target dungeon and level stay on the bar after entry")

    sim.StartKey({ mapID = KINGS_REST_MAP_ID, level = 15, owner = "Isiplayer" })
    sim.Wait(12)
    sim.Step("Key running")
    ExpectRow(sim, "Königsruh|%+15", "the running key shows its dungeon and level")

    sim.CompleteKey()
    -- Wait past the upgraded keystone (+16/+17): the bar keeps the level
    -- the key ran at.
    sim.Wait(6)
    sim.Step("Key completed")
    ExpectRow(sim, "Königsruh|%+15|", "the finished key keeps its dungeon and the level it ran at")

    sim.LeaveDungeon()
    sim.Wait(3)
    sim.Step("Left the dungeon")
    ExpectNoTarget(sim, "no target after leaving the dungeon")
  end,
}
