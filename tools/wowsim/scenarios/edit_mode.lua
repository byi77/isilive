-- Blizzard Edit Mode for the main window (rule 243), end-to-end with the
-- embedded LibEditMode, the real factory and the real main window: entering
-- the Edit Mode shows the hidden window, a drag of the isiLive element stores
-- the position, every Edit Mode layout keeps its own position, scale and
-- layout, and leaving the Edit Mode hides the window again.

-- The selection overlay LibEditMode puts on the main window.
local function FindSelection(sim, mainFrame)
  local engine = sim.Client().engine
  for _, obj in ipairs(engine.all) do
    local system = obj._isFrame and obj:GetParent() == mainFrame and rawget(obj, "system")
    if type(system) == "table" and type(system.GetSystemName) == "function" and system.GetSystemName() == "isiLive" then
      return obj
    end
  end
  return nil
end

-- Moves the window like a drag would and lets LibEditMode finish the drag.
local function DragTo(sim, selection, mainFrame, left, top)
  local env = sim.Env()
  mainFrame:ClearAllPoints()
  mainFrame:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", left, top)
  selection:GetScript("OnDragStop")(selection)
end

local function Left(frame)
  return math.floor((tonumber(frame:GetLeft()) or 0) * (tonumber(frame:GetScale()) or 1) + 0.5)
end

return {
  name = "edit_mode",
  description = "Blizzard Edit Mode: isiLive element, drag, one position / scale / layout per Edit Mode layout",
  setup = {
    locale = "enUS",
    party = {
      { name = "Isiplayer", class = "MAGE", specID = 63, role = "DAMAGER", ilvl = 712, rating = 3120 },
    },
  },
  run = function(sim)
    sim.Login()
    sim.Wait(1)
    local env = sim.Env()
    local mainFrame = env.isiLiveMainFrame
    local editMode = env.__wowsimEditMode
    local db = env.IsiLiveDB
    mainFrame:Hide()
    sim.Expect(not mainFrame:IsShown(), "the window starts closed")

    env.EditModeManagerFrame:Show()
    sim.Wait(0.5)
    sim.Expect(mainFrame:IsShown(), "entering the Edit Mode shows the closed window")
    local selection = FindSelection(sim, mainFrame)
    sim.Expect(selection ~= nil, "LibEditMode put the isiLive selection on the window")
    sim.Step("Edit Mode open: isiLive is an element")
    if not selection then
      return
    end

    DragTo(sim, selection, mainFrame, 200, -150)
    sim.Expect(type(db.position) == "table", "the drag stored a position")
    sim.Expect(Left(mainFrame) == 200, "the window stays where it was dropped")
    db.uiScale = 1.0

    -- Second layout: no snapshot yet, the window stays; then it gets its own place.
    editMode.activeLayout = 2
    editMode.FireLayoutsUpdated()
    sim.Expect(type(db.editModeLayouts) == "table" and db.editModeLayouts.Modern ~= nil, "Modern keeps its values")
    sim.Expect(Left(mainFrame) == 200, "a layout without its own values keeps the current place")
    DragTo(sim, selection, mainFrame, 600, -300)
    sim.Expect(Left(mainFrame) == 600, "Classic gets its own place")
    sim.Step("Classic layout: own position")

    editMode.activeLayout = 1
    editMode.FireLayoutsUpdated()
    sim.Expect(Left(mainFrame) == 200, "back in Modern the window returns to its Modern place")
    sim.Expect(db.editModeActiveLayout == "Modern", "the live values belong to Modern again")
    sim.Step("Modern layout: position restored")

    env.EditModeManagerFrame:Hide()
    sim.Wait(0.5)
    sim.Expect(not mainFrame:IsShown(), "leaving the Edit Mode hides the window it opened")
    sim.Step("Edit Mode closed: window closed again")
  end,
}
