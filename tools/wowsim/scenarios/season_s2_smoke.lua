-- Smoke test Midnight Season 2 (docs/SAISON_WECHSEL.md, "Nachweis Midnight
-- Season 2"): portal buttons, LFG detection per dungeon and the portal
-- navigator. Run once per client locale:
--
--   lua tools/wowsim/wowsim.lua season_s2_smoke --locale deDE
--   lua tools/wowsim/wowsim.lua season_s2_smoke --locale enUS
--
-- Covers what the simulator can prove: isiLive's own data path and UI. Still
-- ingame only: that Blizzard's real portal spells, activity IDs and zone
-- texts match these values.
local SEASON_ID = "midnight_s2"

-- Expected values, copied from data/isiLive_seasons.lua (midnight_s2) so a
-- manifest edit that breaks the season shows up here.
local DUNGEONS = {
  { mapID = 249, spellID = 1286831, activityID = 514, enUS = "King's Rest", deDE = "Königsruh" },
  { mapID = 250, spellID = 1286828, activityID = 504, enUS = "Temple of Sethraliss", deDE = "Tempel von Sethraliss" },
  { mapID = 399, spellID = 393256, activityID = 1176, enUS = "Ruby Life Pools", deDE = "Rubinlebensbecken" },
  { mapID = 584, spellID = 1286801, activityID = 1949, enUS = "The Blinding Vale", deDE = "Das blendende Tal" },
  { mapID = 585, spellID = 1286804, activityID = 1951, enUS = "Voidscar Arena", deDE = "Arena der Leerennarbe" },
  { mapID = 586, spellID = 1286807, activityID = 1952, enUS = "Den of Nalorakk", deDE = "Nalorakks Bau" },
  { mapID = 587, spellID = 1286809, activityID = 1950, enUS = "Murder Row", deDE = "Mördergasse" },
  { mapID = 588, spellID = 1286812, activityID = 1933, enUS = "Altar of Fangs", deDE = "Der Altar der Fänge" },
}

local NAVIGATOR = {
  zone = { enUS = "Millennia's Threshold", deDE = "Die Jahrhundertschwelle" },
  title = {
    -- The card header shows the title without the "isiLive - " prefix.
    enUS = "Midnight Season Two M%+ Navigator",
    deDE = "Midnight Saison Zwei M%+ Navigator",
  },
  filled = { 249, 399, 250 }, -- half_left, center, half_right
  emptySlots = 2, -- left = false, right = false
  unoccupied = { enUS = "^Unoccupied$", deDE = "^Unbelegt$" },
}

local TARGET_ANNOUNCE = { enUS = "Target Dungeon: ", deDE = "Ziel%-Dungeon: " }
local PARTY_NAMES = { "Sagehd", "Tankone", "Healone", "Dpsone" }

local function Locale(sim)
  local tag = sim.Env().GetLocale()
  return (tag == "enUS" or tag == "deDE") and tag or "enUS"
end

local function EscapePattern(text)
  return (text:gsub("[%-%+%.%(%)%[%]%*%?%^%$%%]", "%%%0"))
end

local function CheckSeasonData(sim, locale)
  local seasonData = sim.Client().addonTable.SeasonData
  sim.Expect(seasonData.GetActiveSeasonID() == SEASON_ID, "active season is " .. SEASON_ID)
  local ordered = seasonData.GetOrderedMapIDs(SEASON_ID) or {}
  local teleports = seasonData.GetMapToTeleport(SEASON_ID) or {}
  sim.Expect(#ordered == #DUNGEONS, "season lists " .. #DUNGEONS .. " dungeons (got " .. #ordered .. ")")
  for index, dungeon in ipairs(DUNGEONS) do
    local label = string.format("#%d %s", index, dungeon[locale])
    sim.Expect(ordered[index] == dungeon.mapID, label .. ": order position")
    sim.Expect(teleports[dungeon.mapID] == dungeon.spellID, label .. ": portal spell " .. dungeon.spellID)
    sim.Expect(seasonData.GetDungeonName(dungeon.mapID, locale, SEASON_ID) == dungeon[locale], label .. ": name")
    sim.Expect(
      seasonData.GetMapIDByActivityID(dungeon.activityID, SEASON_ID) == dungeon.mapID,
      label .. ": LFG activity " .. dungeon.activityID .. " maps to the dungeon"
    )
  end
end

-- Visible portal buttons of the main frame, left to right / top to bottom.
local function VisiblePortalButtons(sim)
  local engine = sim.Client().engine
  local buttons = {}
  for _, obj in ipairs(engine.all) do
    if obj._isFrame and type(rawget(obj, "spellID")) == "number" and obj:IsVisible() then
      local rect = engine.ResolveRect(obj)
      if rect then
        buttons[#buttons + 1] = { spellID = obj.spellID, x = rect.x or rect.left or 0, y = rect.y or rect.top or 0 }
      end
    end
  end
  table.sort(buttons, function(a, b)
    if math.abs(a.y - b.y) > 4 then
      return a.y < b.y
    end
    return a.x < b.x
  end)
  return buttons
end

local function CheckPortalButtons(sim)
  local buttons = VisiblePortalButtons(sim)
  sim.Expect(#buttons == #DUNGEONS, "main frame shows " .. #DUNGEONS .. " portal buttons (got " .. #buttons .. ")")
  for index, dungeon in ipairs(DUNGEONS) do
    local button = buttons[index]
    sim.Expect(
      button ~= nil and button.spellID == dungeon.spellID,
      string.format(
        "portal button %d casts %d (%s), got %s",
        index,
        dungeon.spellID,
        dungeon.enUS,
        tostring(button and button.spellID)
      )
    )
  end
end

local function InstallLfgList(sim, dungeon, locale, status)
  local lfgList = sim.Env().C_LFGList
  lfgList.GetSearchResultInfo = function(searchResultID)
    if status[searchResultID] == nil then
      return nil
    end
    return {
      searchResultID = searchResultID,
      activityIDs = { dungeon.activityID },
      leaderName = "Sagehd-Ravencrest",
      name = "|Kt635|k",
      numMembers = 4,
    }
  end
  lfgList.GetActivityInfoTable = function(activityID)
    if activityID ~= dungeon.activityID then
      return nil
    end
    return { isMythicPlusActivity = true, categoryID = 2, fullName = dungeon[locale] }
  end
  lfgList.GetApplications = function()
    local ids = {}
    for searchResultID in pairs(status) do
      ids[#ids + 1] = searchResultID
    end
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

local function CheckLfgDetection(sim, locale, index, dungeon)
  local label = string.format("LFG #%d %s", index, dungeon[locale])
  local status = {}
  local searchResultID = 300 + index
  InstallLfgList(sim, dungeon, locale, status)
  SetStatus(sim, status, searchResultID, "applied")
  sim.Wait(1)
  SetStatus(sim, status, searchResultID, "invited")
  sim.Wait(1)
  local acceptAt = sim.Now()
  local logIndex = #((sim.Env().IsiLiveDB or {}).runtimeLog or {})
  SetStatus(sim, status, searchResultID, "inviteaccepted")
  sim.Wait(0.1)
  sim.focus.member.inGroup = true
  for _, name in ipairs(PARTY_NAMES) do
    sim.Member(name).inGroup = true
  end
  sim.Fire("GROUP_ROSTER_UPDATE")
  sim.Fire("PARTY_LEADER_CHANGED")
  sim.Wait(6)
  sim.Step(label)

  sim.ExpectLog(
    "print",
    TARGET_ANNOUNCE[locale] .. ".*" .. EscapePattern(dungeon[locale]),
    nil,
    label .. ": target dungeon announced",
    acceptAt
  )
  local lastTeleport = LastTeleportUpdate(sim, logIndex)
  sim.Expect(
    lastTeleport ~= nil and lastTeleport:find("spellID=" .. dungeon.spellID, 1, true) ~= nil,
    label .. ": teleport highlight on portal " .. dungeon.spellID
  )

  sim.LeaveGroup("Isiplayer")
  sim.Wait(3)
end

local function CheckNavigator(sim, locale)
  sim.world.zone = NAVIGATOR.zone[locale]
  sim.world.FireAll("ZONE_CHANGED_NEW_AREA")
  sim.world.FireAll("ZONE_CHANGED")
  sim.Wait(3)
  sim.Step("Portal navigator: " .. NAVIGATOR.zone[locale])

  sim.ExpectText(NAVIGATOR.title[locale], "navigator title (" .. locale .. ")")
  local byName = {}
  for _, dungeon in ipairs(DUNGEONS) do
    byName[dungeon.mapID] = dungeon
  end
  local lastX = -1
  for slot, mapID in ipairs(NAVIGATOR.filled) do
    local name = byName[mapID][locale]
    local found = sim.FindText("^" .. EscapePattern(name) .. "$")
    local x = found[1] and found[1].x or nil
    sim.Expect(x ~= nil and x > lastX, string.format("navigator slot %d shows %s left-to-right", slot, name))
    lastX = x or lastX
  end
  local empty = #sim.FindText(NAVIGATOR.unoccupied[locale])
  sim.Expect(empty == NAVIGATOR.emptySlots, "navigator keeps the two outer slots empty (got " .. empty .. ")")

  sim.world.zone = "Dornogal"
  sim.world.FireAll("ZONE_CHANGED_NEW_AREA")
  sim.Wait(2)
end

return {
  name = "season_s2_smoke",
  description = "Smoke test Midnight S2: portal buttons, LFG per dungeon, navigator (--locale enUS|deDE)",
  setup = {
    locale = "deDE",
    party = {
      { name = "Isiplayer", class = "MAGE", specID = 63, role = "DAMAGER", ilvl = 330, rating = 3310 },
      { name = "Sagehd", realm = "Ravencrest", class = "HUNTER", specID = 253, role = "DAMAGER", addon = "none" },
      { name = "Tankone", class = "WARRIOR", specID = 73, role = "TANK", addon = "none" },
      { name = "Healone", class = "PRIEST", specID = 257, role = "HEALER", addon = "none" },
      { name = "Dpsone", class = "MAGE", specID = 63, role = "DAMAGER", addon = "none" },
    },
  },
  run = function(sim)
    local client = sim.Client()
    client.knownSpells = client.knownSpells or {}
    for _, dungeon in ipairs(DUNGEONS) do
      client.knownSpells[dungeon.spellID] = true
    end
    sim.Login()
    sim.Slash("/il log on")
    sim.SetLeader("Sagehd")
    sim.Fire("SPELLS_CHANGED")
    sim.Wait(3)
    local locale = Locale(sim)
    sim.Step("Logged in (" .. locale .. ")")

    CheckSeasonData(sim, locale)
    CheckPortalButtons(sim)
    for index, dungeon in ipairs(DUNGEONS) do
      CheckLfgDetection(sim, locale, index, dungeon)
    end
    CheckNavigator(sim, locale)
  end,
}
