---@diagnostic disable: undefined-global, undefined-field

-- Render scenarios for the pre-key loadout check card
-- (ui/isiLive_loadout_check_card.lua). The model comes from the real
-- LoadoutCheck.BuildModel; frames come from the shared UI stub, the controller
-- only records the clicks the card forwards.
-- COMPONENT-ONLY: the card is a pure renderer of the model it receives; the
-- event path that produces the model is covered in
-- isilive_test_scenarios_loadout_check.lua and the wowsim scenario
-- `loadout_check`.

local helpers = dofile("testmodul/isilive_test_ui_helpers.lua")

local FROST_MAGE = 64
local FIRE_MAGE = 63

local function BuildLive(overrides)
  local live = {
    specID = FROST_MAGE,
    specName = "Frost",
    loadouts = { { id = 101, name = "M+ AoE" }, { id = 102, name = "M+ Single" } },
    selectedLoadoutID = 101,
    specs = { { id = FIRE_MAGE, name = "Fire" }, { id = FROST_MAGE, name = "Frost" } },
    lootSpecID = FIRE_MAGE,
  }
  for key, value in pairs(overrides or {}) do
    live[key] = value
  end
  return live
end

local function BuildController()
  local controller = { calls = {} }
  function controller.GetText(_, fallback)
    return fallback
  end
  for _, name in ipairs({ "SelectLoadout", "SelectLootSpec", "Confirm", "Dismiss" }) do
    controller[name] = function(arg)
      controller.calls[#controller.calls + 1] = { name = name, arg = arg }
    end
  end
  return controller
end

-- The shared stub has no SetWidth on frames; the card sizes its own width.
local function BuildCreateFrame()
  local createFrameStub, createdFrames = helpers.BuildCreateFrameStub()
  local function CreateFrame(...)
    local frame = createFrameStub(...)
    frame.SetWidth = frame.SetWidth or function(self, width)
      self._width = width
    end
    return frame
  end
  return CreateFrame, createdFrames
end

local function LabelOf(button)
  return button._flatLabel and button._flatLabel:GetText() or nil
end

local function VisibleOptionButtons(createdFrames)
  local buttons = {}
  for _, frame in ipairs(createdFrames) do
    if frame._frameType == "Button" and frame._flatLabel and frame:IsShown() and frame._width == 134 then
      buttons[#buttons + 1] = frame
    end
  end
  return buttons
end

local function FindButton(createdFrames, label)
  for _, frame in ipairs(createdFrames) do
    if frame._frameType == "Button" and frame:IsShown() and LabelOf(frame) == label then
      return frame
    end
  end
  return nil
end

local function Click(button)
  local onClick = button._scripts and button._scripts.OnClick
  assert(type(onClick) == "function", "button has no OnClick")
  onClick(button, "LeftButton")
end

local function RegisterLoadoutCheckCardTests(test, Assert, WithGlobals, LoadAddonModules)
  local function WithCard(fn)
    local createFrame, createdFrames = BuildCreateFrame()
    WithGlobals({ CreateFrame = createFrame, UIParent = {} }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_loadout_check_card.lua",
        "isiLive_loadout_check.lua",
      })
      fn(addon, addon.LoadoutCheckCard.Create(), createdFrames)
    end)
  end

  test("LoadoutCheckCard renders the status lines, options and confirm label of a mismatch", function()
    WithCard(function(addon, card, createdFrames)
      local controller = BuildController()
      local model = addon.LoadoutCheck.BuildModel(BuildLive(), { configID = 102, lootSpecID = 0 })
      model.dungeonName = "Floodgate"

      Assert.True(card:Show(model, controller), "a valid model renders")
      Assert.True(card:IsShown(), "the card is shown after rendering")

      local options = VisibleOptionButtons(createdFrames)
      Assert.Equal(#options, 5, "two loadouts plus current-spec default and two class specs")
      Assert.NotNil(FindButton(createdFrames, "» M+ Single"), "the target loadout carries the marker")
      Assert.NotNil(FindButton(createdFrames, "M+ AoE"), "the active loadout is offered without marker")
      Assert.NotNil(FindButton(createdFrames, "» Current spec (Frost)"), "the current-spec target is marked")
      Assert.NotNil(FindButton(createdFrames, "Keep current"), "a mismatch offers keep current")

      Assert.True((createdFrames[1]._height or 0) > 100, "the card grows to fit its rows")

      Click(FindButton(createdFrames, "» M+ Single"))
      Click(FindButton(createdFrames, "Fire"))
      Click(FindButton(createdFrames, "Keep current"))
      Assert.Equal(controller.calls[1].name, "SelectLoadout", "a loadout click goes to SelectLoadout")
      Assert.Equal(controller.calls[1].arg, 102, "the clicked loadout ID is forwarded")
      Assert.Equal(controller.calls[2].name, "SelectLootSpec", "a loot click goes to SelectLootSpec")
      Assert.Equal(controller.calls[2].arg, FIRE_MAGE, "the clicked spec ID is forwarded")
      Assert.Equal(controller.calls[3].name, "Confirm", "the confirm button confirms")
    end)
  end)

  test("LoadoutCheckCard labels confirm by state, hides surplus options and closes", function()
    WithCard(function(addon, card, createdFrames)
      local controller = BuildController()
      local unknown = addon.LoadoutCheck.BuildModel(BuildLive(), nil)
      card:Show(unknown, controller)
      Assert.NotNil(FindButton(createdFrames, "OK - remember"), "without a target the card offers to remember")

      local ok = addon.LoadoutCheck.BuildModel(BuildLive({ lootSpecID = 0 }), { configID = 101, lootSpecID = 0 })
      ok.inCombat = true
      card:Show(ok, controller)
      Assert.NotNil(FindButton(createdFrames, "All OK"), "a full match reads all OK")

      local fewer = addon.LoadoutCheck.BuildModel(
        BuildLive({ loadouts = { { id = 101, name = "M+ AoE" } }, selectedLoadoutID = nil }),
        { configID = 101, lootSpecID = FIRE_MAGE }
      )
      card:Show(fewer, controller)
      Assert.Equal(#VisibleOptionButtons(createdFrames), 4, "a shorter loadout list hides the surplus button")
      Assert.NotNil(FindButton(createdFrames, "» M+ AoE"), "the remaining target loadout is marked")

      local closeButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "Button" and frame._isiLiveCloseButtonLabel then
          closeButton = frame
        end
      end
      Assert.NotNil(closeButton, "the card has a close button")
      Click(closeButton)
      Assert.Equal(controller.calls[#controller.calls].name, "Dismiss", "the close button dismisses")

      card:Hide()
      Assert.False(card:IsShown(), "hide closes the card")
      Assert.False(card:Show(nil, controller), "a missing model does not render")
    end)
  end)

  test("LoadoutCheckCard falls back to client texts without a controller text getter", function()
    WithCard(function(addon, card, createdFrames)
      local controller = BuildController()
      controller.GetText = nil
      local model = addon.LoadoutCheck.BuildModel(BuildLive(), { configID = 102, lootSpecID = FROST_MAGE })
      card:Show(model, controller)
      Assert.NotNil(FindButton(createdFrames, "» Frost"), "an explicit loot spec target is marked by name")
      local hidden = addon.LoadoutCheckCard.Create()
      Assert.False(hidden:IsShown(), "a card that never rendered is not shown")
      hidden:Hide()
    end)
  end)
end

return function(test, ctx)
  RegisterLoadoutCheckCardTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
end
