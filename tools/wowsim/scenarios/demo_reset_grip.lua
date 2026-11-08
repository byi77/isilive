-- Demo preview of the instance reset button (rule 235) and the resize grip
-- (rule 234): `/il testall` shows both without a key, a group or an unlocked
-- window. The layout checks assert that neither overlaps another button of the
-- main window in M+ and M; a demo click never reaches ResetInstances() or the
-- chat, and the demo end hides both again and restores the reset setting.
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

-- The resize grip is the only main-window child with a double-click script.
local function FindGrip(frame)
  for _, child in ipairs(frame._children or {}) do
    if child._isFrame and child:GetScript("OnDoubleClick") then
      return child
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

local function Overlaps(a, b)
  local al, ab, aw, ah = a:GetRect()
  local bl, bb, bw, bh = b:GetRect()
  if not (al and bl) then
    return false
  end
  return al < bl + bw and bl < al + aw and ab < bb + bh and bb < ab + ah
end

local function ExpectFreeAndInside(sim, mainFrame, widget, label)
  local overlapping = 0
  for _, other in ipairs(CollectButtons(mainFrame, {})) do
    if other ~= widget and Overlaps(widget, other) then
      overlapping = overlapping + 1
    end
  end
  sim.Expect(overlapping == 0, label .. " overlaps no other button")
  local left, bottom, width, height = widget:GetRect()
  local fl, fb, fw, fh = mainFrame:GetRect()
  sim.Expect(
    left >= fl and bottom >= fb and left + width <= fl + fw and bottom + height <= fb + fh,
    label .. " stays inside the main window"
  )
end

return {
  name = "demo_reset_grip",
  description = "Demo preview: instance reset button and resize grip in M+ and M, harmless demo click",
  setup = {
    locale = "enUS",
    party = {
      { name = "Isiplayer", class = "MAGE", specID = 63, role = "DAMAGER", key = { mapID = 249, level = 14 } },
    },
  },
  run = function(sim)
    sim.Login()
    local resetCalls = 0
    local function Prepare(layout)
      local env = sim.Env()
      env.ResetInstances = function()
        resetCalls = resetCalls + 1
      end
      local mainFrame = env.isiLiveMainFrame
      local button = FindResetButton(mainFrame)
      sim.Expect(button ~= nil, layout .. ": the main window owns the reset button")
      local grip = FindGrip(mainFrame)
      sim.Expect(grip ~= nil, layout .. ": the main window owns the resize grip")
      sim.Expect(not grip:IsVisible(), layout .. ": the locked window hides the grip")
      sim.Expect(not button:IsVisible(), layout .. ": no key, no group: no reset button")
      return env, mainFrame, button, grip
    end
    local function ExpectDemo(layout, mainFrame, button, grip)
      sim.Expect(button:IsVisible(), layout .. ": the demo shows the reset button")
      ExpectFreeAndInside(sim, mainFrame, button, layout .. ": the reset button")
      sim.Expect(grip:IsVisible(), layout .. ": the demo shows the grip")
      ExpectFreeAndInside(sim, mainFrame, grip, layout .. ": the grip")
    end
    local function EndDemo()
      -- PLAYER_REGEN_DISABLED ends the preview just before the lockdown.
      sim.Fire("PLAYER_REGEN_DISABLED")
      sim.Fire("PLAYER_REGEN_ENABLED")
      sim.Wait(1)
    end

    sim.Env().IsiLiveDB.instanceResetButtonEnabled = false
    local env, mainFrame, button, grip = Prepare("M+")
    sim.Slash("/il testall")
    sim.Wait(1)
    sim.Step("Demo in M+")
    sim.Expect(({ button:GetPoint() })[1] == "BOTTOMLEFT", "M+: the reset button sits in the toolbar row")
    ExpectDemo("M+", mainFrame, button, grip)
    sim.Expect(env.IsiLiveDB.lockMainFramePosition ~= false, "the window stays locked")
    EndDemo()
    sim.Step("Demo in M+ ended")
    sim.Expect(not button:IsVisible(), "M+: the demo end hides the reset button")
    sim.Expect(not grip:IsVisible(), "M+: the demo end hides the grip")

    env.IsiLiveDB.rosterDefaultLayoutMode = "expanded"
    sim.Reload()
    sim.Wait(2)
    env, mainFrame, button, grip = Prepare("M")
    sim.Slash("/il testall")
    sim.Wait(1)
    sim.Step("Demo in M")
    sim.Expect(({ button:GetPoint() })[1] == "TOPRIGHT", "M: the reset button sits in the leader column")
    ExpectDemo("M", mainFrame, button, grip)

    button:GetScript("OnClick")(button, "LeftButton")
    sim.Wait(1)
    sim.Step("Demo click")
    sim.Expect(resetCalls == 0, "the demo click never calls ResetInstances")
    sim.Expect(#sim.FindLog("chat", ".") == 0, "the demo click sends no chat line")
    sim.ExpectLog("print", "Demo: no instance was reset", nil, "the demo click prints a local notice")
    sim.Expect(not button:IsVisible(), "the demo click removes the demo button")

    EndDemo()
    sim.Step("Demo ended")
    sim.Expect(not button:IsVisible(), "after the demo the reset button stays hidden")
    sim.Expect(not grip:IsVisible(), "after the demo the locked window hides the grip again")
    sim.Expect(env.IsiLiveDB.instanceResetButtonEnabled == false, "the reset setting is restored")
    sim.Expect(env.IsiLiveDB.demoFeatureSnapshot == nil, "no demo snapshot is left")
    sim.Expect(resetCalls == 0, "the whole scenario never called ResetInstances")
  end,
}
