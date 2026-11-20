-- Season smoke test for any configured season (rule 263, maintainability
-- package 4 H; replaces the per-season copy season_s2_smoke). Blizzard runs
-- the chosen season in the simulation, so a prepared season must switch at
-- runtime exactly as on launch day; then portal buttons, LFG detection per
-- dungeon and the portal navigator are checked. Run once per client locale:
--
--   lua tools/wowsim/wowsim.lua season_smoke --locale deDE
--   lua tools/wowsim/wowsim.lua season_smoke --locale enUS --season <id>
--
-- Season: `--season <id>`, else the manifest's upcomingSeasonID, else its
-- activeSeasonID. Expected technical IDs (challenge map, portal spell, LFG
-- activity) and the English names come from docs/SEASON_INTAKE.md, a source
-- kept apart from data/isiLive_seasons.lua, so a manifest edit that diverges
-- from the verified intake fails here. Display order, German names and the
-- navigator layout come from the manifest: what is checked there is that the
-- addon renders them. Still ingame only: that Blizzard's real portal spells,
-- activity IDs and zone texts match these values.

local INTAKE_PATH = "docs/SEASON_INTAKE.md"
local TARGET_ANNOUNCE = { enUS = "Target Dungeon: ", deDE = "Ziel%-Dungeon: " }
local UNOCCUPIED = { enUS = "^Unoccupied$", deDE = "^Unbelegt$" }
local PARTY_NAMES = { "Sylvan", "Tankone", "Healone", "Dpsone" }

local function ReadManifest()
  local addon = {}
  assert(loadfile("data/isiLive_seasons.lua"))("isiLive", addon)
  return addon.SeasonManifest
end

local MANIFEST = ReadManifest()

local function ResolveSeasonID(sim)
  return sim.Param("season") or MANIFEST.upcomingSeasonID or MANIFEST.activeSeasonID
end

local function Trim(text)
  return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Verified intake rows of the season, keyed by challenge map ID.
local function ReadIntake(seasonID)
  local rows = {}
  local file = assert(io.open(INTAKE_PATH, "rb"))
  for line in file:lines() do
    local cells = {}
    for cell in line:gmatch("|([^|]*)") do
      cells[#cells + 1] = Trim(cell)
    end
    if cells[1] == seasonID and cells[8] == "verified" then
      local mapID = tonumber(cells[3])
      rows[mapID] = {
        mapID = mapID,
        enUS = cells[2],
        spellID = tonumber(cells[4]),
        activityID = tonumber(cells[5]),
      }
    end
  end
  file:close()
  return rows
end

-- Dungeons in manifest display order, technical IDs from the intake.
local function BuildDungeons(seasonID)
  local season = MANIFEST.seasons[seasonID]
  local intake = ReadIntake(seasonID)
  local ordered = {}
  for _, dungeon in ipairs(season.dungeons) do
    ordered[#ordered + 1] = dungeon
  end
  table.sort(ordered, function(a, b)
    return a.displayOrder < b.displayOrder
  end)
  local dungeons = {}
  for _, dungeon in ipairs(ordered) do
    local row = intake[dungeon.mapID] or {}
    dungeons[#dungeons + 1] = {
      mapID = dungeon.mapID,
      spellID = row.spellID,
      activityID = row.activityID,
      enUS = row.enUS,
      deDE = dungeon.names and dungeon.names.deDE,
      inIntake = intake[dungeon.mapID] ~= nil,
    }
  end
  return dungeons, season
end

local function Locale(sim)
  local tag = sim.Env().GetLocale()
  return (tag == "enUS" or tag == "deDE") and tag or "enUS"
end

local function EscapePattern(text)
  return (tostring(text):gsub("[%-%+%.%(%)%[%]%*%?%^%$%%]", "%%%0"))
end

local function CheckSeasonData(sim, seasonID, dungeons, locale)
  local seasonData = sim.Client().addonTable.SeasonData
  sim.Expect(
    seasonData.GetActiveSeasonID() == seasonID,
    string.format(
      "Blizzard's map set selects %s at runtime (got %s; needs autoDetectFromChallengeMaps = true and a ready season)",
      seasonID,
      tostring(seasonData.GetActiveSeasonID())
    )
  )
  local ordered = seasonData.GetOrderedMapIDs(seasonID) or {}
  local teleports = seasonData.GetMapToTeleport(seasonID) or {}
  sim.Expect(#ordered == #dungeons, "season lists " .. #dungeons .. " dungeons (got " .. #ordered .. ")")
  for index, dungeon in ipairs(dungeons) do
    local label = string.format("#%d %s", index, tostring(dungeon.enUS or dungeon.mapID))
    sim.Expect(dungeon.inIntake, label .. ": verified row in " .. INTAKE_PATH)
    sim.Expect(ordered[index] == dungeon.mapID, label .. ": display order position")
    local mapped = teleports[dungeon.mapID]
    mapped = type(mapped) == "table" and mapped[1] or mapped
    sim.Expect(mapped == dungeon.spellID, label .. ": portal spell matches the intake " .. tostring(dungeon.spellID))
    sim.Expect(seasonData.GetDungeonName(dungeon.mapID, locale, seasonID) == dungeon[locale], label .. ": name")
    sim.Expect(
      seasonData.GetMapIDByActivityID(dungeon.activityID, seasonID) == dungeon.mapID,
      label .. ": LFG activity " .. tostring(dungeon.activityID) .. " maps to the dungeon"
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
        buttons[#buttons + 1] = { spellID = obj.spellID, x = rect.left or 0, y = rect.bottom or 0 }
      end
    end
  end
  table.sort(buttons, function(a, b)
    if math.abs(a.y - b.y) > 4 then
      return a.y > b.y
    end
    return a.x < b.x
  end)
  return buttons
end

local function CheckPortalButtons(sim, dungeons)
  local buttons = VisiblePortalButtons(sim)
  sim.Expect(#buttons == #dungeons, "main frame shows " .. #dungeons .. " portal buttons (got " .. #buttons .. ")")
  for index, dungeon in ipairs(dungeons) do
    local button = buttons[index]
    sim.Expect(
      button ~= nil and button.spellID == dungeon.spellID,
      string.format(
        "portal button %d casts %s (%s), got %s",
        index,
        tostring(dungeon.spellID),
        tostring(dungeon.enUS),
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
      leaderName = "Sylvan-Ravencrest",
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
  local label = string.format("LFG #%d %s", index, tostring(dungeon[locale]))
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
    lastTeleport ~= nil and lastTeleport:find("spellID=" .. tostring(dungeon.spellID), 1, true) ~= nil,
    label .. ": teleport highlight on portal " .. tostring(dungeon.spellID)
  )

  sim.LeaveGroup("Isiplayer")
  sim.Wait(3)
end

local function CheckNavigator(sim, locale, season, seasonID)
  local navigator = season.portalNavigator
  local zoneName = navigator.zone.names[1]
  sim.world.zone = zoneName
  sim.world.FireAll("ZONE_CHANGED_NEW_AREA")
  sim.world.FireAll("ZONE_CHANGED")
  sim.Wait(3)
  sim.Step("Portal navigator: " .. zoneName)

  -- The card header shows the title without the "isiLive - " prefix.
  local title = navigator.titleByLocale[locale] or navigator.titleByLocale.default
  title = title:gsub("^isiLive %- ", "")
  sim.ExpectText(EscapePattern(title), "navigator title (" .. locale .. ")")

  local seasonData = sim.Client().addonTable.SeasonData
  local lastX = -1
  local empty = 0
  for _, slot in ipairs({ "left", "half_left", "center", "half_right", "right" }) do
    local mapID = navigator.slots[slot]
    if mapID == false then
      empty = empty + 1
    else
      local name = seasonData.GetDungeonName(mapID, locale, seasonID)
      local found = sim.FindText("^" .. EscapePattern(name) .. "$")
      local x = found[1] and found[1].x or nil
      sim.Expect(x ~= nil and x > lastX, string.format("navigator slot %s shows %s left-to-right", slot, name))
      lastX = x or lastX
    end
  end
  local shown = #sim.FindText(UNOCCUPIED[locale])
  sim.Expect(shown == empty, string.format("navigator shows %d empty slot(s) (got %d)", empty, shown))

  sim.world.zone = "Dornogal"
  sim.world.FireAll("ZONE_CHANGED_NEW_AREA")
  sim.Wait(2)
end

return {
  name = "season_smoke",
  -- The season the simulation runs unless --season overrides it.
  season = MANIFEST.upcomingSeasonID or MANIFEST.activeSeasonID,
  description = "Season smoke: runtime switch, portal buttons, LFG per dungeon, navigator "
    .. "(--locale enUS|deDE, --season <id>)",
  setup = {
    locale = "deDE",
    party = {
      { name = "Isiplayer", class = "MAGE", specID = 63, role = "DAMAGER", ilvl = 330, rating = 3310 },
      { name = "Sylvan", realm = "Ravencrest", class = "HUNTER", specID = 253, role = "DAMAGER", addon = "none" },
      { name = "Tankone", class = "WARRIOR", specID = 73, role = "TANK", addon = "none" },
      { name = "Healone", class = "PRIEST", specID = 257, role = "HEALER", addon = "none" },
      { name = "Dpsone", class = "MAGE", specID = 63, role = "DAMAGER", addon = "none" },
    },
  },
  run = function(sim)
    local seasonID = ResolveSeasonID(sim)
    sim.Expect(
      sim.world.seasonID == seasonID,
      "the simulation runs " .. seasonID .. " (pass --season " .. seasonID .. ")"
    )
    local dungeons, season = BuildDungeons(seasonID)
    local client = sim.Client()
    client.knownSpells = client.knownSpells or {}
    for _, dungeon in ipairs(dungeons) do
      if dungeon.spellID then
        client.knownSpells[dungeon.spellID] = true
      end
    end
    sim.Login()
    sim.Slash("/il log on")
    sim.SetLeader("Sylvan")
    sim.Fire("CHALLENGE_MODE_MAPS_UPDATE")
    sim.Fire("SPELLS_CHANGED")
    sim.Wait(3)
    local locale = Locale(sim)
    sim.Step(string.format("Logged in (%s, %s)", locale, seasonID))

    CheckSeasonData(sim, seasonID, dungeons, locale)
    CheckPortalButtons(sim, dungeons)
    for index, dungeon in ipairs(dungeons) do
      CheckLfgDetection(sim, locale, index, dungeon)
    end
    CheckNavigator(sim, locale, season, seasonID)
  end,
}
