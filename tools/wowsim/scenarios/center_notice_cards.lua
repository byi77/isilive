-- Center-notice card gallery: every rich card the simulation tablet can
-- show (accepted invite with portal action, group full, joined target,
-- non-Mythic warning), one step each, for layout checks of the card design.
local CARDS = {
  { action = "^Accepted invite$", label = "Accepted invite (action)" },
  { action = "^Group full$", label = "Group full (warning)" },
  { action = "^Joined target$", label = "Joined target group (action)" },
  { action = "^Non%-M%+ warning$", label = "Non-Mythic dungeon (warning)" },
}

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

return {
  name = "center_notice_cards",
  description = "Center-notice card gallery: invite, group full, joined target, non-Mythic warning",
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
    ClickTabletButton(sim, "^Group$")
    -- Cards are switched in place (without closing in between) on purpose: a
    -- card with fewer rows must not keep rows or strips of the previous one.
    local env = sim.Env()
    for _, card in ipairs(CARDS) do
      env.isiLiveMainFrame:Show()
      env.isiLiveSimulationTablet:Show()
      ClickTabletButton(sim, card.action)
      sim.Wait(1)
      sim.Expect(env.isiLiveCenterNotice:IsShown(), card.label .. ": center notice is shown")
      -- Only the card in the snapshot, nothing of the main UI behind it.
      env.isiLiveMainFrame:Hide()
      env.isiLiveSimulationTablet:Hide()
      sim.Step(card.label)
    end

    -- The portal navigator shares the card header (kind chip, brand, headline).
    -- The main window stays closed: its title bar has an "M+" button too.
    env.isiLiveCenterNotice:Hide()
    env.isiLiveSimulationTablet:Show()
    ClickTabletButton(sim, "^M%+$")
    ClickTabletButton(sim, "^Portal navigator$")
    sim.Wait(1)
    sim.Expect(env.isiLivePortalNavigatorNotice:IsShown(), "Portal navigator: notice is shown")
    env.isiLiveSimulationTablet:Hide()
    sim.Step("Portal navigator (action)")
  end,
}
