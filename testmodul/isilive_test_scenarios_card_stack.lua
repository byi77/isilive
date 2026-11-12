---@diagnostic disable: undefined-global

-- Rule 242: the shared card stack (ui/isiLive_card_stack.lua). Every test
-- drives the real card modules (center notice, portal navigator, talent &
-- loot check card) through their public controllers on the simulated widget
-- layer of testmodul/isilive_test_ui_world.lua.

local UIWorld = dofile("testmodul/isilive_test_ui_world.lua")
local NewWorld = UIWorld.NewWorld
local Globals = UIWorld.Globals
local AlphaAnim = UIWorld.AlphaAnim

local function NoticeOpts()
  return {
    parent = UIParent,
    isInCombat = function()
      return InCombatLockdown()
    end,
  }
end

local PORTAL_LAYOUT = {
  eyebrow = "Portal - Navigation",
  title = "isiLive - Midnight Season Two M+ Navigator",
  entries = {
    { slot = "left", direction = "Left", destination = "Skyreach", icon = "icon-skyreach" },
    { slot = "center", direction = "Straight", destination = "Pit", icon = "icon-pit" },
  },
}

local function RichNotice(title)
  return {
    title = title,
    fields = {
      { label = "Dungeon:", value = "Skyreach +12" },
      { label = "Leader:", value = "Isiplayer" },
    },
  }
end

local function LoadoutModel()
  return {
    dungeonName = "Skyreach",
    specName = "Fire",
    remembers = false,
    inCombat = false,
    talents = {
      status = "unknown",
      currentName = "Raid",
      options = { { id = 1, name = "Raid", active = true }, { id = 2, name = "M+" } },
    },
    loot = {
      status = "unknown",
      currentName = "Fire",
      currentIsSpecDefault = true,
      options = { { id = 0, name = "Fire", isCurrentSpec = true, active = true } },
    },
  }
end

local function LoadoutController()
  return {
    SelectLoadout = function() end,
    SelectLootSpec = function() end,
    Confirm = function() end,
    Dismiss = function() end,
    GetText = function(_, fallback)
      return fallback
    end,
  }
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function LoadCards()
    return LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua", "isiLive_loadout_check_card.lua" })
  end

  test("Card stack orders cards by priority and arrival and replaces the same kind in place", function()
    local world = NewWorld()
    WithGlobals(Globals(world), function()
      local addon = LoadCards()
      local Notice = addon.Notice
      local notice = Notice.CreateCenterNotice(NoticeOpts())
      local portal = Notice.CreatePortalNavigatorNotice({ parent = UIParent })
      local loadout = addon.LoadoutCheckCard.Create()
      local CardStack = addon.CardStack

      portal.Show(PORTAL_LAYOUT)
      world.Advance(1)
      notice.Show(nil, 20, nil, nil, RichNotice("isiLive - Invite accepted"))
      world.Advance(1)
      loadout:Show(LoadoutModel(), LoadoutController())
      world.Advance(1)
      Assert.Equal(
        table.concat(CardStack.GetOrder(), ","),
        "notice,loadout,portal",
        "the center notice leads, the talent check follows and the portal navigator closes the stack"
      )

      local entranceGroup = notice.frame._groups and notice.frame._groups[1]
      local plays = entranceGroup and entranceGroup.plays or 0
      local container = CardStack.GetContainer()
      local _, _, _, _, loadoutY = world.named.IsiLiveLoadoutCheckCard:GetPoint()
      notice.Show(nil, 20, nil, nil, RichNotice("isiLive - Group is full"))
      Assert.Equal(
        table.concat(CardStack.GetOrder(), ","),
        "notice,loadout,portal",
        "showing the same kind again keeps its place"
      )
      Assert.Equal(entranceGroup and entranceGroup.plays or 0, plays, "a card replaced in place gets no new entrance")
      Assert.Equal(notice.titleText:GetText(), "Group is full", "the replaced card shows the new content")
      local _, _, _, _, loadoutYAfter = world.named.IsiLiveLoadoutCheckCard:GetPoint()
      Assert.Equal(loadoutYAfter, loadoutY, "cards below a replaced card of the same height stay put")
      Assert.True(container:IsShown(), "the stack stays visible")
    end)
  end)

  test("Card stack reads as one card with one header and hairlines between sections", function()
    local world = NewWorld()
    WithGlobals(Globals(world), function()
      local addon = LoadCards()
      local notice = addon.Notice.CreateCenterNotice(NoticeOpts())
      local portal = addon.Notice.CreatePortalNavigatorNotice({ parent = UIParent })
      notice.Show(nil, 20, nil, nil, RichNotice("isiLive - Invite accepted"))
      portal.Show(PORTAL_LAYOUT)
      world.Advance(1)

      local container = addon.CardStack.GetContainer()
      Assert.NotNil(container._backdropColor, "the stack paints the one card surface")
      Assert.Nil(notice.frame._backdropColor, "a section paints no surface of its own")
      Assert.True(
        notice.frame:GetFrameLevel() > container:GetFrameLevel(),
        "a card built before the stack still renders above the stack's background"
      )
      Assert.True(
        notice.closeButton:GetFrameLevel() > notice.frame:GetFrameLevel(),
        "the card's own children keep their order above the card"
      )
      Assert.Nil(portal.frame._backdropColor, "a section paints no surface of its own")
      Assert.True(notice.brandText:IsShown(), "the lead section carries the brand mark")
      Assert.True(notice.headerBand:IsShown(), "the lead section carries the header band")
      Assert.False(portal.brandText:IsShown(), "a further section shows no second brand mark")
      Assert.False(portal.headerBand:IsShown(), "a further section shows no second header band")
      Assert.True(portal.titleText:IsShown(), "a further section keeps its own headline")
      Assert.True(notice.frame._isiLiveNoticeAccent:IsShown(), "the top accent belongs to the lead section")
      Assert.False(portal.frame._isiLiveNoticeAccent:IsShown(), "a further section hides its top accent")

      local _, relativeTo, _, _, y = portal.frame:GetPoint()
      Assert.Equal(relativeTo, container, "sections anchor to the stack")
      Assert.Equal(y, -notice.frame:GetHeight(), "the second section starts right below the first")
      Assert.Equal(
        container:GetHeight(),
        notice.frame:GetHeight() + portal.frame:GetHeight(),
        "the stack is exactly as tall as its sections"
      )
      Assert.Equal(container:GetWidth(), 760, "the widest card sets the stack width")
      Assert.Equal(notice.frame:GetWidth(), 760, "every section takes the stack width")
    end)
  end)

  test("Card stack lets the remaining cards slide up after a card faded out", function()
    local world = NewWorld()
    WithGlobals(Globals(world), function()
      local addon = LoadCards()
      local notice = addon.Notice.CreateCenterNotice(NoticeOpts())
      local portal = addon.Notice.CreatePortalNavigatorNotice({ parent = UIParent })
      notice.Show(nil, 20, nil, nil, RichNotice("isiLive - Invite accepted"))
      portal.Show(PORTAL_LAYOUT)
      world.Advance(1)
      local noticeHeight = notice.frame:GetHeight()

      notice.SetVisible(false)
      Assert.True(addon.UICommon.IsHiding(notice.frame), "the closed card fades out first")
      Assert.True(notice.frame:IsShown(), "the card keeps its slot while it fades")
      Assert.False(notice.frame:IsMouseEnabled(), "a fading card catches no clicks")
      local _, _, _, _, yDuring = portal.frame:GetPoint()
      Assert.Equal(yDuring, -noticeHeight, "the card below waits until the fade has finished")
      local alpha = AlphaAnim(notice.frame)
      Assert.Equal(alpha._duration, addon.UICommon.Motion.duration.fast, "cards fade out over `fast`")

      world.Advance(addon.UICommon.Motion.duration.fast)
      Assert.False(notice.frame:IsShown(), "the faded card is hidden for real")
      local _, _, _, _, yAfter = portal.frame:GetPoint()
      Assert.Equal(yAfter, 0, "the remaining card moves up into the free slot")
      local slide, group = AlphaAnim(portal.frame)
      Assert.NotNil(slide, "the moved card animates")
      Assert.True(group:IsPlaying(), "the moved card slides instead of jumping")
      Assert.Equal(group:Find("Translation", 1)._offset[2], -noticeHeight, "the slide starts at the old place")
      Assert.Equal(group:Find("Translation", 2)._offset[2], noticeHeight, "and ends at the new anchor")
      Assert.True(portal.brandText:IsShown(), "the new lead section takes over the header")
      Assert.Equal(table.concat(addon.CardStack.GetOrder(), ","), "portal", "only the navigator is left")
    end)
  end)

  test("Card stack drag moves the whole stack and every card keeps its slot", function()
    local world = NewWorld()
    WithGlobals(Globals(world), function()
      local addon = LoadCards()
      local notice = addon.Notice.CreateCenterNotice(NoticeOpts())
      local portal = addon.Notice.CreatePortalNavigatorNotice({ parent = UIParent })
      notice.Show("Plain notice", 20)
      portal.Show(PORTAL_LAYOUT)
      local container = addon.CardStack.GetContainer()
      portal.frame:GetScript("OnDragStart")(portal.frame)
      portal.frame:GetScript("OnDragStop")(portal.frame)
      notice.frame:GetScript("OnDragStart")(notice.frame)
      Assert.Equal(container._moving, 2, "dragging any card moves the stack")
      Assert.Nil(portal.frame._moving, "a card never moves out of the stack")
      Assert.Nil(notice.frame._moving, "a card never moves out of the stack")
      Assert.True(container._mouse ~= true, "the stack itself is moved through its cards")
      Assert.Nil(IsiLiveDB.cardStackPosition, "the position is not saved yet")
    end)
  end)

  test("Card stack moves up to keep a tall stack on screen and never jumps back down", function()
    local world = NewWorld()
    WithGlobals(Globals(world), function()
      local addon = LoadCards()
      local CardStack = addon.CardStack
      local half = UIParent:GetHeight() / 2
      -- Three plain 300 px sections: 900 px do not fit below the default
      -- place (half + TOP_OFFSET = 740 px) but fit on the 1080 px screen.
      local handles = {}
      for index, kind in ipairs({ "notice", "loadout", "portal" }) do
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:SetSize(600, 300)
        handles[index] = CardStack.Register(kind, frame)
      end
      local container = CardStack.GetContainer()

      handles[1].Show()
      world.Advance(1)
      local _, _, _, _, firstOffset = container:GetPoint()
      Assert.Equal(firstOffset, CardStack.TOP_OFFSET, "a card that fits keeps the default place")

      handles[2].Show()
      handles[3].Show()
      local slide = select(2, AlphaAnim(container))
      Assert.True(slide ~= nil and slide:IsPlaying(), "the stack slides up instead of jumping")
      world.Advance(1)
      local _, _, _, _, offset = container:GetPoint()
      Assert.Equal(container:GetHeight(), 900, "three sections stack")
      Assert.Equal(offset - 900, CardStack.SCREEN_MARGIN - half, "the bottom keeps the margin to the screen edge")
      Assert.True(offset <= half - CardStack.SCREEN_MARGIN, "the top stays on screen")

      handles[2].Hide()
      world.Advance(1)
      local _, _, _, _, afterLeave = container:GetPoint()
      Assert.Equal(afterLeave, offset, "a card leaving never makes the stack jump down")

      handles[1].Hide()
      handles[3].Hide()
      world.Advance(1)
      handles[1].Show()
      world.Advance(1)
      local _, _, _, _, reopened = container:GetPoint()
      Assert.Equal(reopened, CardStack.TOP_OFFSET, "an emptied stack starts at the default place again")

      local frame = select(1, container:GetChildren())
      frame:GetScript("OnDragStart")(frame)
      frame:GetScript("OnDragStop")(frame)
      local _, _, _, _, dragged = container:GetPoint()
      handles[2].Show()
      handles[3].Show()
      world.Advance(1)
      local _, _, _, _, afterDrag = container:GetPoint()
      Assert.Equal(afterDrag, dragged, "a dragged stack stays where the player put it")
    end)
  end)

  test("Card stack in combat shows and hides cards without protected calls", function()
    local world = NewWorld()
    WithGlobals(Globals(world), function()
      local addon = LoadCards()
      local notice = addon.Notice.CreateCenterNotice(NoticeOpts())
      local portal = addon.Notice.CreatePortalNavigatorNotice({ parent = UIParent })
      world.inCombat = true
      notice.Show("Combat notice", 20)
      portal.Show(PORTAL_LAYOUT)
      world.Advance(1)
      Assert.True(notice.frame:IsShown() and portal.frame:IsShown(), "unprotected cards open in combat")
      portal.SetVisible(false)
      world.Advance(1)
      notice.SetVisible(false)
      world.Advance(1)
      Assert.False(addon.CardStack.GetContainer():IsShown(), "the empty stack hides in combat")
      Assert.Equal(#world.violations, 0, "no blocked call reached the client")
    end)
  end)
end
