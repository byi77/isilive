-- Run kicks in the kick column after a key (rule 238), through the real
-- events: own kicks as UNIT_SPELLCAST_SUCCEEDED during the key, the damage
-- meter's Interrupts session read at CHALLENGE_MODE_COMPLETED, the isiLive
-- peer's own cast count through the real DPS sync (KC suffix). The roster
-- shows "cast/landed" for isiLive users and "landed" for everybody else, in
-- every layout that has roster rows (M, M+); H and V hide the rows.
local MAP_ID = 249
local COUNTERSPELL = 2139
local WIND_SHEAR = 57994
local INTERRUPTS_TYPE = 5

-- Landed interrupts per meter name (the own character without realm, the
-- others as Name-Realm like the client reports them). Ravencast (healer) is
-- absent: a member missing from a readable list landed none.
local LANDED = {
  Isiplayer = 32,
  ["Velindra-Antonidas"] = 10,
  ["Stormbreaker-Antonidas"] = 20,
  ["Thornwick-Antonidas"] = 3,
}
local DPS = {
  Isiplayer = 412000,
  ["Velindra-Antonidas"] = 398000,
  ["Stormbreaker-Antonidas"] = 151000,
  ["Thornwick-Antonidas"] = 377000,
  ["Ravencast-Antonidas"] = 48000,
}

-- The meter as seen by one client: its own character carries no realm.
local function BuildMeter(ownName)
  local function Rename(name)
    if name == ownName .. "-Antonidas" then
      return ownName
    end
    if name == "Isiplayer" and ownName ~= "Isiplayer" then
      return "Isiplayer-Antonidas"
    end
    return name
  end
  return {
    IsDamageMeterAvailable = function()
      return true
    end,
    ResetAllCombatSessions = function() end,
    GetCombatSessionFromType = function(_sessionType, meterType)
      local source = meterType == INTERRUPTS_TYPE and LANDED or (meterType == 0 and DPS or nil)
      if not source then
        return nil
      end
      local sources = {}
      for name, amount in pairs(source) do
        sources[#sources + 1] = {
          name = Rename(name),
          totalAmount = amount,
          amountPerSecond = meterType == 0 and amount or 0,
        }
      end
      table.sort(sources, function(a, b)
        return a.name < b.name
      end)
      return { durationSeconds = 1800, combatSources = sources }
    end,
  }
end

-- The layout buttons carry their label in a child FontString; they are found
-- by the mode label the roster layout stores on them.
local function ClickLayout(sim, label)
  for _, obj in ipairs(sim.Client().engine.all) do
    if obj._isFrame and obj._modeLabel == label and obj:IsVisible() then
      local onClick = obj:GetScript("OnClick")
      sim.Expect(onClick ~= nil, "layout button " .. label .. " has a click handler")
      onClick(obj, "LeftButton", false)
      return
    end
  end
  sim.Expect(false, "layout button " .. label .. " found")
end

local function InstallMeter(sim, name)
  local env = sim.Env(name)
  env.C_DamageMeter = BuildMeter(name)
end

return {
  name = "run_kicks",
  description = "Run kicks (cast/landed) in the kick column after a key, in the M and M+ layouts",
  timeLimits = { [MAP_ID] = 33 * 60 },
  setup = {
    locale = "deDE",
    party = {
      {
        name = "Isiplayer",
        realm = "Antonidas",
        class = "MAGE",
        specID = 63,
        role = "DAMAGER",
        key = { mapID = MAP_ID, level = 14 },
      },
      { name = "Velindra", realm = "Antonidas", class = "SHAMAN", specID = 263, role = "DAMAGER", simulate = true },
      { name = "Stormbreaker", realm = "Antonidas", class = "WARRIOR", specID = 73, role = "TANK", addon = "none" },
      { name = "Thornwick", realm = "Antonidas", class = "HUNTER", specID = 254, role = "DAMAGER", addon = "none" },
      { name = "Ravencast", realm = "Antonidas", class = "PRIEST", specID = 257, role = "HEALER", addon = "none" },
    },
  },
  run = function(sim)
    sim.Login()
    sim.JoinGroup("Velindra", "Stormbreaker", "Thornwick", "Ravencast")
    sim.Wait(8)
    -- Start in the M layout (no title-bar button; the default-layout setting).
    sim.Env().IsiLiveDB.rosterDefaultLayoutMode = "expanded"
    sim.Reload()
    sim.Wait(3)
    InstallMeter(sim, "Isiplayer")
    InstallMeter(sim, "Velindra")

    sim.EnterDungeon(MAP_ID)
    sim.Wait(1)
    sim.StartKey({ mapID = MAP_ID, level = 14 })
    sim.Wait(12)
    sim.Combat(true)
    for index = 1, 37 do
      sim.Cast("Isiplayer", COUNTERSPELL)
      if index <= 12 then
        sim.Cast("Velindra", WIND_SHEAR)
      end
      sim.Wait(2)
    end
    sim.Combat(false)
    sim.Wait(2)
    sim.Step("Key running: kick column shows the kick cooldown")
    sim.Expect(#sim.FindText("^37/32$") == 0, "no run kicks while the key runs")

    sim.CompleteKey()
    sim.Wait(15)
    sim.Step("Run end, M layout: cast/landed for isiLive users, landed for the rest")
    sim.ExpectText("^37/32$", "own row shows 37 cast / 32 landed")
    sim.ExpectText("^12/10$", "the isiLive peer's synced cast count pairs with the landed kicks")
    sim.ExpectText("^20$", "a member without isiLive shows the landed count only")
    sim.ExpectText("^0$", "the healer without kicks shows 0 landed")

    ClickLayout(sim, "M+")
    sim.Wait(1)
    sim.Step("Run end, M+ layout")
    sim.ExpectText("^37/32$", "M+ shows the run kicks as well")

    ClickLayout(sim, "H")
    sim.Wait(1)
    sim.Step("Run end, H layout (no roster rows)")

    ClickLayout(sim, "V")
    sim.Wait(1)
    sim.Step("Run end, V layout (no roster rows)")

    ClickLayout(sim, "M+")
    sim.Wait(1)
    sim.StartKey({ mapID = MAP_ID, level = 15 })
    sim.Wait(3)
    sim.Step("Next key started: kick cooldown again")
    sim.Expect(#sim.FindText("^37/32$") == 0, "the previous run's kicks hide when the next key starts")
  end,
}
