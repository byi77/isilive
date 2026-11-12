-- Card stack and show/hide motion (rule 242): three different cards at once
-- (tablet action F5: accepted invite, talent & loot check, portal navigator)
-- read as one card; then the motion tour (F6) shows the cards one after the
-- other, lets the middle one leave (the card below slides up), empties the
-- stack and fades the main window out and back in.

-- The tablet's tabs and action tiles carry their text on a child `label`
-- FontString, which sim.Click's own text match does not see.
local function ClickTabletButton(sim, pattern)
  local engine = sim.Client().engine
  for _, obj in ipairs(engine.all) do
    local label = obj._isFrame and obj:IsVisible() and obj.label
    local text = type(label) == "table" and label._text
    if text and engine.StripEscapes(text):find(pattern) then
      obj:GetScript("OnClick")(obj, "LeftButton", false)
      return true
    end
  end
  sim.Expect(false, "tablet button '" .. pattern .. "' found")
  return false
end

local function TopOffset(frame)
  local _, _, _, _, y = frame:GetPoint(1)
  return -(tonumber(y) or 0)
end

return {
  name = "card_stack",
  description = "Card stack: three cards as one card, then every card and window animation (F5, F6)",
  setup = {
    locale = "enUS",
    party = {
      {
        name = "Isiplayer",
        class = "MAGE",
        specID = 63,
        role = "DAMAGER",
        ilvl = 712,
        rating = 3120,
        key = { mapID = 249, level = 14 },
      },
    },
  },
  run = function(sim)
    sim.Login()
    sim.Slash("/il sim")
    sim.Wait(1)
    local env = sim.Env()
    local stack = env.isiLiveCardStack
    local notice = env.isiLiveCenterNotice
    local portal = env.isiLivePortalNavigatorNotice

    ClickTabletButton(sim, "^Extras$")
    ClickTabletButton(sim, "^Card stack$")
    sim.Wait(1)
    local loadout = env.IsiLiveLoadoutCheckCard
    sim.Expect(stack and stack:IsShown(), "the card stack is shown")
    sim.Expect(notice:IsShown() and loadout:IsShown() and portal:IsShown(), "all three cards are shown")
    sim.Expect(notice:GetParent() == stack and loadout:GetParent() == stack, "the cards are sections of the stack")
    sim.Expect(TopOffset(notice) == 0, "the invite card leads the stack")
    sim.Expect(TopOffset(loadout) == notice:GetHeight(), "the talent check follows right below the invite")
    sim.Expect(
      TopOffset(portal) == notice:GetHeight() + loadout:GetHeight(),
      "the portal navigator closes the stack without a gap"
    )
    sim.Expect(
      math.abs(stack:GetHeight() - (notice:GetHeight() + loadout:GetHeight() + portal:GetHeight())) < 0.5,
      "the stack is exactly as tall as its three cards"
    )
    sim.Expect(notice:GetWidth() == stack:GetWidth(), "every card takes the stack width")
    -- The stack's anchor is its TOP at the screen center (positive = above).
    local _, _, _, _, stackTop = stack:GetPoint(1)
    local screenHalf = env.UIParent:GetHeight() / 2
    sim.Expect(
      stackTop - stack:GetHeight() >= 16 - screenHalf - 0.5,
      "the three cards stay on screen: the stack moved up so its bottom keeps the margin"
    )
    sim.Expect(stackTop <= screenHalf, "the stack's top stays on screen")
    env.isiLiveMainFrame:Hide()
    env.isiLiveSimulationTablet:Hide()
    sim.Step("Card stack: invite, talents & loot, portal navigator")

    -- Motion tour: one step every 0.9 s.
    env.isiLiveMainFrame:Show()
    env.isiLiveSimulationTablet:Show()
    ClickTabletButton(sim, "^Extras$")
    ClickTabletButton(sim, "^Play animations$")
    -- Checks land 0.3 s after each tour step, once its motion has finished.
    sim.Wait(0.5)
    sim.Expect(not stack:IsShown(), "the tour starts from an empty stack")
    sim.Wait(0.7)
    sim.Expect(notice:IsShown() and stack:IsShown(), "1: the invite card appears")
    sim.Step("Tour 1: invite card fades in")
    sim.Wait(0.9)
    sim.Expect(loadout:IsShown() and TopOffset(loadout) == notice:GetHeight(), "2: the talent check slides in below")
    sim.Step("Tour 2: talent check slides in below")
    sim.Wait(0.9)
    sim.Expect(portal:IsShown(), "3: the portal navigator slides in below")
    sim.Step("Tour 3: portal navigator slides in below")
    sim.Wait(0.9)
    sim.Expect(not loadout:IsShown(), "4: the talent check has faded out")
    sim.Expect(TopOffset(portal) == notice:GetHeight(), "4: the portal navigator moved up into the free slot")
    sim.Step("Tour 4: middle card leaves, the card below slides up")
    sim.Wait(0.9)
    sim.Expect(not notice:IsShown() and TopOffset(portal) == 0, "5: the invite left, the navigator leads")
    sim.Step("Tour 5: lead card leaves, the navigator takes the header")
    sim.Wait(0.9)
    sim.Expect(not stack:IsShown() and not portal:IsShown(), "6: the last card leaves with the stack")
    sim.Wait(0.9)
    sim.Expect(not env.isiLiveMainFrame:IsShown(), "7: the main window has faded out")
    sim.Step("Tour 7: main window faded out")
    sim.Wait(0.9)
    sim.Expect(env.isiLiveMainFrame:IsShown(), "8: the main window fades back in")
    sim.Expect(env.isiLiveMainFrame:GetAlpha() == 1, "8: the main window is fully visible again")
    sim.Step("Tour 8: main window faded back in")
  end,
}
