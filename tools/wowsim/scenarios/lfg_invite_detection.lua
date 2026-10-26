-- Regression: the dungeon of an accepted LFG invite must survive the join.
--
-- Found 2026-10-25 (about 2 of 10 invites showed no target dungeon in the UI
-- and printed no "Ziel-Dungeon" line). Two independent causes, both covered:
--
--   1. Several open applications. Accepting one makes Blizzard cancel the
--      others in the same frame, before IsInGroup() is true; the queue
--      lifecycle then cleared the latest queue target. The live client also
--      fires PARTY_LEADER_CHANGED after the first GROUP_ROSTER_UPDATE, and
--      LFGDetect read that join as a leader handoff and cleared the accepted
--      invite. With a title without "+N" the chat announce waits for the
--      resolver, which then had no local target left.
--   2. Accept in combat. The event gate dropped "inviteaccepted" in combat,
--      and the "invited" exception stopped before the detection, so the
--      GROUP_ROSTER_UPDATE recovery had nothing to resolve.
--
-- The listing title is opaque Blizzard markup ("|Kt635|k"), so the direct
-- push stays silent and the chat line depends on the resolver path.
local KINGS_REST_MAP_ID = 249
local KINGS_REST_ACTIVITY_ID = 514
local KINGS_REST_PORTAL_SPELL_ID = 1286831
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
      name = "|Kt635|k",
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

local function RuntimeLogSize(sim)
  local db = sim.Env().IsiLiveDB or {}
  return #(db.runtimeLog or {})
end

-- Last teleport-button update logged after `fromIndex`.
local function LastTeleportUpdate(sim, fromIndex)
  local db = sim.Env().IsiLiveDB or {}
  local last = nil
  for index, line in ipairs(db.runtimeLog or {}) do
    if index > fromIndex and tostring(line):find("[TP] event=update_button", 1, true) then
      last = tostring(line)
    end
  end
  return last
end

-- Applies to `apps`, gets invited to and accepts `acceptID`, then joins the
-- group with the roster update ahead of the leader change (live order).
local function RunInviteCycle(sim, label, apps, acceptID, inCombat)
  local status = {}
  InstallLfgList(sim, status)
  for _, searchResultID in ipairs(apps) do
    SetStatus(sim, status, searchResultID, "applied")
    sim.Wait(1)
  end
  sim.Step(label .. ": applied to " .. #apps .. " listings")

  if inCombat then
    sim.Combat(true)
  end
  SetStatus(sim, status, acceptID, "invited")
  sim.Wait(2)
  local acceptAt = sim.Now()
  local logIndex = RuntimeLogSize(sim)
  SetStatus(sim, status, acceptID, "inviteaccepted")
  for _, searchResultID in ipairs(apps) do
    if searchResultID ~= acceptID then
      SetStatus(sim, status, searchResultID, "cancelled")
    end
  end
  sim.Wait(0.1)

  sim.focus.member.inGroup = true
  for _, name in ipairs(PARTY_NAMES) do
    sim.Member(name).inGroup = true
  end
  sim.Fire("GROUP_ROSTER_UPDATE")
  sim.Fire("PARTY_LEADER_CHANGED")
  sim.Wait(1)
  if inCombat then
    sim.Combat(false)
  end
  sim.Wait(6)
  sim.Step(label .. ": joined the group")

  sim.ExpectLog("print", "Ziel%-Dungeon: .*Königsruh", nil, label .. ": target dungeon announced in chat", acceptAt)
  local lastTeleport = LastTeleportUpdate(sim, logIndex)
  sim.Expect(
    lastTeleport ~= nil and lastTeleport:find("spellID=" .. KINGS_REST_PORTAL_SPELL_ID, 1, true) ~= nil,
    label .. ": teleport highlight stays on the accepted dungeon (map " .. KINGS_REST_MAP_ID .. ")"
  )
end

return {
  name = "lfg_invite_detection",
  description = "Regression: accepted LFG invite keeps its dungeon (parallel applications, accept in combat)",
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
    sim.Slash("/il log on")
    -- The listing leader leads the group the player joins. Set while solo,
    -- before any LFG state exists.
    sim.SetLeader("Sagehd")
    sim.Wait(2)

    RunInviteCycle(sim, "Parallel applications", { 101, 102, 103 }, 102, false)

    sim.LeaveGroup("Isiplayer")
    sim.Wait(3)
    sim.Step("Left the group")

    RunInviteCycle(sim, "Accept in combat", { 201 }, 201, true)
  end,
}
