-- Instance reset button after a key (rule 235): a timed key in a season
-- dungeon, then outside as group leader the reset button joins the leader
-- buttons -- in M below Mark-T/H, in M+ as the sixth toolbar button -- and
-- leaves again once the client confirms the reset. The layout checks assert
-- that the button overlaps no other button of the main window.
local MAP_ID = 249
local DUNGEON_NAME = "King's Rest"
local SUCCESS_FORMAT = "%s has been reset."

local function FindResetButton(frame)
  for _, child in ipairs(frame._children or {}) do
    if child._isFrame then
      if child._m2ToolbarText ~= nil and child._verticalY == -210 then
        return child
      end
      local hit = FindResetButton(child)
      if hit then
        return hit
      end
    end
  end
  return nil
end

local function FindModeButton(frame, target)
  for _, child in ipairs(frame._children or {}) do
    if child._isFrame then
      if child._modeTarget == target then
        return child
      end
      local hit = FindModeButton(child, target)
      if hit then
        return hit
      end
    end
  end
  return nil
end

-- Visible flat buttons (text label on a button frame) of the main window.
local function CollectButtons(frame, out)
  for _, child in ipairs(frame._children or {}) do
    if child._isFrame and child:IsVisible() then
      if child._flatLabel ~= nil then
        out[#out + 1] = child
      end
      CollectButtons(child, out)
    end
  end
  return out
end

local function Rect(frame)
  local left, bottom, width, height = frame:GetRect()
  return left, bottom, width, height
end

local function Overlaps(a, b)
  local al, ab, aw, ah = Rect(a)
  local bl, bb, bw, bh = Rect(b)
  if not (al and bl) then
    return false
  end
  return al < bl + bw and bl < al + aw and ab < bb + bh and bb < ab + ah
end

local function ExpectNoOverlap(sim, mainFrame, button, label)
  local overlapping = 0
  for _, other in ipairs(CollectButtons(mainFrame, {})) do
    if other ~= button and Overlaps(button, other) then
      overlapping = overlapping + 1
    end
  end
  sim.Expect(overlapping == 0, label .. ": the reset button overlaps no other button")
  local left, bottom, width, height = Rect(button)
  local fl, fb, fw, fh = Rect(mainFrame)
  sim.Expect(
    left >= fl and bottom >= fb and left + width <= fl + fw and bottom + height <= fb + fh,
    label .. ": the reset button stays inside the main window"
  )
end

local function InstallResetApi(sim, calls)
  local env = sim.Env()
  env.INSTANCE_RESET_SUCCESS = SUCCESS_FORMAT
  env.ResetInstances = function()
    calls.count = calls.count + 1
  end
end

local function RunKeyAndLeave(sim)
  sim.EnterDungeon(MAP_ID)
  sim.Wait(1)
  sim.StartKey({ mapID = MAP_ID, level = 14 })
  sim.Wait(12)
  sim.CompleteKey()
  sim.Wait(2)
  sim.LeaveDungeon()
  sim.Wait(2)
end

return {
  name = "instance_reset_button",
  description = "Instance reset button after a season key: M and M+ placement, click, confirmation",
  timeLimits = { [MAP_ID] = 33 * 60 },
  setup = {
    locale = "enUS",
    party = {
      { name = "Isiplayer", class = "MAGE", specID = 63, role = "DAMAGER", key = { mapID = MAP_ID, level = 14 } },
      { name = "Stormbreaker", class = "WARRIOR", specID = 73, role = "TANK", addon = "none" },
      { name = "Velindra", class = "DRUID", specID = 105, role = "HEALER", addon = "none" },
      { name = "Ravencast", class = "PRIEST", specID = 258, role = "DAMAGER", addon = "none" },
      { name = "Embersong", class = "SHAMAN", specID = 262, role = "DAMAGER", addon = "none" },
    },
  },
  run = function(sim)
    sim.Login()
    sim.JoinGroup("Stormbreaker", "Velindra", "Ravencast", "Embersong")
    sim.Wait(3)
    local db = sim.Env().IsiLiveDB
    db.instanceResetButtonEnabled = true
    db.instanceResetAnnounce = true
    db.rosterDefaultLayoutMode = "expanded"
    sim.Reload()
    sim.Wait(3)
    local calls = { count = 0 }
    InstallResetApi(sim, calls)
    local mainFrame = sim.Env().isiLiveMainFrame
    local button = FindResetButton(mainFrame)
    sim.Expect(button ~= nil, "the main window owns the reset button")
    sim.Expect(not button:IsVisible(), "no key ended yet: hidden")

    RunKeyAndLeave(sim)
    sim.Step("M layout: outside after the key")
    sim.Expect(button:IsVisible(), "M: the reset button shows below Mark-T/H")
    ExpectNoOverlap(sim, mainFrame, button, "M")

    local modeButton = FindModeButton(mainFrame, "compact_main_horizontal")
    sim.Expect(modeButton ~= nil, "the M+ mode button exists")
    modeButton:GetScript("OnClick")(modeButton, "LeftButton")
    sim.Wait(1)
    sim.Step("M+ layout: six toolbar buttons")
    sim.Expect(button:IsVisible(), "M+: the reset button joins the toolbar row")
    ExpectNoOverlap(sim, mainFrame, button, "M+")

    local onClick = button:GetScript("OnClick")
    onClick(button, "LeftButton")
    sim.Expect(calls.count == 1, "the click calls ResetInstances once")
    sim.Fire("CHAT_MSG_SYSTEM", string.format(SUCCESS_FORMAT, DUNGEON_NAME))
    sim.Wait(1)
    sim.Step("Reset confirmed")
    sim.Expect(not button:IsVisible(), "the confirmed reset hides the button")
    sim.ExpectLog("chat", DUNGEON_NAME, nil, "the reset is announced in party chat")
  end,
}
