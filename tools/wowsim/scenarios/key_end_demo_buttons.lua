-- Demo tablet: one button per key end outcome on the M+ tab, a fifth ends the
-- banner (rule 231). Each text then shows twice: button and banner.
local OUTCOMES = { "Key in der Zeit", "Key über der Zeit", "Key abgebrochen", "Gruppe verlassen" }

-- sim.Click reads button text only; the tablet buttons carry theirs in a label.
local function ClickTabletButton(sim, tablet, text)
  for _, child in ipairs(tablet._children) do
    if child._isFrame and child:IsVisible() and child:GetScript("OnClick") then
      for _, region in ipairs(child._children or {}) do
        if not region._isFrame and type(region.GetText) == "function" and region:GetText() == text then
          child:GetScript("OnClick")(child, "LeftButton", false)
          return
        end
      end
    end
  end
  sim.Expect(false, "no tablet button: " .. text)
end

return {
  name = "key_end_demo_buttons",
  description = "Demo tablet: a button per key end banner and one to end it",
  setup = {
    locale = "deDE",
    party = {
      { name = "Isiplayer", class = "MAGE", specID = 63, role = "DAMAGER", key = { mapID = 249, level = 14 } },
    },
  },
  run = function(sim)
    sim.Login()
    sim.Slash("/il m2")
    sim.Wait(1)
    sim.Slash("/il testall")
    sim.Wait(1)
    local tablet = sim.Env().isiLiveSimulationTablet
    for _, child in ipairs(tablet._children) do
      local label = child._isFrame and child.label or nil
      if label and label:GetText() == "M+" then
        child:GetScript("OnClick")(child, "LeftButton", false)
      end
    end
    sim.Wait(0.5)
    sim.Step("M+ tab of the demo tablet")
    for _, text in ipairs(OUTCOMES) do
      sim.Expect(#sim.FindText(text) == 1, text .. ": the button is there, the banner is not")
    end

    for _, text in ipairs(OUTCOMES) do
      ClickTabletButton(sim, tablet, text)
      sim.Wait(1)
      sim.Step(text)
      sim.Expect(#sim.FindText(text) == 2, text .. ": the button shows its banner")
    end

    ClickTabletButton(sim, tablet, "Banner beenden")
    sim.Wait(1)
    sim.Step("Banner ended")
    for _, text in ipairs(OUTCOMES) do
      sim.Expect(#sim.FindText(text) == 1, text .. ": only the button is left")
    end
  end,
}
