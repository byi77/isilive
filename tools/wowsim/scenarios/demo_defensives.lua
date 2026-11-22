-- Demo preview of the defensives column (rule 270, tablet action C14),
-- regression and viewer: `/il testall`, M+ tab, click C14 "Defensives im Key".
-- No key, no group, all three switches off: every state of the key display,
-- the countdown, the row tooltips, the Classic design and the cleanup on
-- reload, dungeon entry and demo end.
local MAP_ID = 249
local SWITCHES = { "defensiveTrackerEnabled" }

local function Cells(sim)
  local out = {}
  for _, child in ipairs({ sim.Env().isiLiveMainFrame:GetChildren() }) do
    if type(child.slots) == "table" and child:IsVisible() then
      out[#out + 1] = child
    end
  end
  return out
end

local function States(sim)
  local seen = {}
  for _, cell in ipairs(Cells(sim)) do
    for _, slot in ipairs(cell.slots) do
      if slot:IsVisible() then
        local kind = slot.state
        if kind == "cd" then
          kind = (slot.text:GetText() or ""):find("m$") and "minutes" or "seconds"
        end
        seen[kind] = slot
      end
    end
  end
  return seen
end

-- Same column as in a key, and every slot text fits.
local function Measure(sim, label)
  local frame = sim.Env().isiLiveMainFrame
  local cellX = sim.Client().addonTable.RosterDefensiveCell.CELL_X
  local cells = Cells(sim)
  sim.Expect(#cells >= 4, label .. ": the demo rows carry a cell")
  for _, cell in ipairs(cells) do
    local left, right = cell:GetLeft() - frame:GetLeft(), cell:GetRight() - frame:GetLeft()
    sim.Expect(math.abs(left - cellX) < 0.5, label .. ": cell at its column")
    sim.Expect(right <= 446.5, label .. ": cell ends left of the kick column")
    for _, slot in ipairs(cell.slots) do
      if slot:IsVisible() then
        sim.Expect(slot.text:IsTruncated() ~= true, label .. ": slot text fits")
      end
    end
  end
end

local function Hover(sim, unit)
  for _, child in ipairs({ sim.Env().isiLiveMainFrame:GetChildren() }) do
    if child.unit == unit and child:GetScript("OnEnter") then
      local x, y = child:GetLeft() + 380, child:GetBottom() + 8
      sim.Env().GetCursorPosition = function()
        return x, y
      end
      child:GetScript("OnEnter")(child)
      sim.Wait(0.2)
      return child
    end
  end
  return nil
end

local function Leave(child)
  if child and child:GetScript("OnLeave") then
    child:GetScript("OnLeave")(child)
  end
end

local function ExpectGone(sim, label)
  sim.Expect(not sim.Client().addonTable.RosterDefensiveCell.IsDemoActive(), label .. ": demo source dropped")
  sim.Expect(#Cells(sim) == 0, label .. ": no defensives cell")
  sim.Expect(#sim.FindText("^Def$") == 0, label .. ": no Def header")
end

-- The tablet buttons carry their text in a child label (sim.Click matches
-- button texts only): click the visible button of the action.
local function ClickTabletAction(sim, id)
  sim.ExpectText("Defensives im Key", "the tablet labels the action")
  for _, child in ipairs({ sim.Env().isiLiveSimulationTablet:GetChildren() }) do
    if child._isiLiveAction and child._isiLiveAction.id == id and child:IsVisible() then
      child:GetScript("OnClick")(child, "LeftButton")
      return
    end
  end
  sim.Expect(false, "the tablet shows a button for " .. id)
end

local function StartDemo(sim)
  sim.Slash("/il testall")
  sim.Wait(1)
  ClickTabletAction(sim, "C14")
  sim.Wait(0.6) -- the demo cards fade out
end

return {
  name = "demo_defensives",
  description = "Demo tablet C14: defensives column as in a key, without key, group or settings",
  setup = {
    locale = "deDE",
    party = {
      {
        name = "Isiplayer",
        class = "PALADIN",
        specID = 70,
        role = "DAMAGER",
        ilvl = 712,
        rating = 3120,
        key = { mapID = MAP_ID, level = 14 },
      },
    },
  },
  run = function(sim)
    sim.Login()
    for _, key in ipairs(SWITCHES) do
      sim.Env().IsiLiveDB[key] = false
    end

    StartDemo(sim)
    sim.Step("1 Demo C14: Def statt DPS mit allen Zuständen")
    sim.ExpectText("^Def$", "Def header without a key")
    sim.Expect(#sim.FindText("^DPS$") == 0, "no DPS header")
    Measure(sim, "modern")
    local seen = States(sim)
    for _, state in ipairs({ "ready", "seconds", "minutes", "active", "frozen", "estimate" }) do
      sim.Expect(seen[state] ~= nil, "state visible: " .. state)
    end
    sim.Expect(seen.frozen and seen.frozen.clock:IsVisible(), "frozen: clock glyph")
    sim.Expect(seen.active and seen.active.border:IsVisible(), "active: blue border")
    local before = seen.seconds and seen.seconds.text:GetText()

    sim.Wait(5)
    sim.Step("2 Countdown und Füllung laufen")
    local after = States(sim).seconds
    sim.Expect(after ~= nil and after.text:GetText() ~= before, "the countdown runs")

    local hover = Hover(sim, "player")
    sim.Step("3 Tooltip: eigener Client")
    sim.ExpectText("Quelle: eigener Client", "own source")
    Leave(hover)
    hover = Hover(sim, "party1")
    sim.Step("4 Tooltip: Sync mit Alter")
    sim.ExpectText("isiLive%-Sync, vor", "sync source with its age")
    Leave(hover)
    hover = Hover(sim, "party2")
    sim.Step("5 Tooltip: geschätzt")
    sim.ExpectText("geschätzt, siehe Symbol", "estimated entries")
    Leave(hover)
    for _, key in ipairs(SWITCHES) do
      sim.Expect(sim.Env().IsiLiveDB[key] == false, key .. " untouched")
    end
    sim.Expect(#sim.FindLog("chat", ".") == 0, "no chat line")

    sim.Reload()
    sim.Wait(2)
    sim.Step("6 Nach /reload in der Demo: nichts bleibt")
    ExpectGone(sim, "reload")
    sim.Expect(sim.Env().IsiLiveDB.demoFeatureSnapshot == nil, "no demo snapshot left")
    for _, key in ipairs(SWITCHES) do
      sim.Expect(sim.Env().IsiLiveDB[key] == false, key .. " untouched after the reload")
    end

    sim.Env().IsiLiveDB.uiDesign = "classic"
    sim.Reload()
    sim.Wait(2)
    StartDemo(sim)
    sim.Step("7 Classic-Design")
    Measure(sim, "classic")

    sim.Fire("PLAYER_REGEN_DISABLED")
    sim.Fire("PLAYER_REGEN_ENABLED")
    sim.Wait(1)
    sim.Step("8 Demo-Ende durch Kampf: DPS zurück")
    ExpectGone(sim, "combat")
    sim.ExpectText("^DPS$", "DPS header back")

    StartDemo(sim)
    sim.EnterDungeon(MAP_ID)
    sim.Wait(1)
    sim.Step("9 Dungeon-Eintritt beendet die Demo")
    ExpectGone(sim, "dungeon")
  end,
}
