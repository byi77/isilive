---@diagnostic disable: undefined-global
local function RegisterVipDkAssistTests(test, Assert, WithGlobals, LoadAddonModules)
  local function LoadController()
    local addon = LoadAddonModules({ "isiLive_vip_dk_assist.lua" })
    return addon.VipDkAssist
  end

  local function BuildHarness(overrides)
    overrides = overrides or {}
    local scheduled = {}
    local overlays = {}
    local db = overrides.db or { vipDkSoulReaperWarningEnabled = true }
    local controller = LoadController().CreateController({
      getDB = function()
        return db
      end,
      isLocalUnholyDeathKnight = function()
        return overrides.isUnholy ~= false
      end,
      scanSoulReaperButtons = function()
        return overrides.buttons or { { id = "soul-reaper-button" } }
      end,
      scanPutrefyButtons = function()
        return overrides.putrefyButtons or { { id = "putrefy-button" } }
      end,
      createOverlay = function(button)
        local overlay = {
          button = button,
          shown = false,
          Show = function(self)
            self.shown = true
          end,
          Hide = function(self)
            self.shown = false
          end,
        }
        overlays[#overlays + 1] = overlay
        return overlay
      end,
      timerAfter = function(delay, callback)
        local timer = {
          delay = delay,
          callback = callback,
          canceled = false,
          Cancel = function(self)
            self.canceled = true
          end,
        }
        scheduled[#scheduled + 1] = timer
        return timer
      end,
    })

    return controller, scheduled, overlays, db
  end

  test("VipDkAssist starts Soul Reaper warning after Dark Transformation", function()
    WithGlobals({}, function()
      local controller, scheduled, overlays = BuildHarness()

      controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)

      Assert.Equal(#scheduled, 1, "Dark Transformation should schedule the warning delay")
      Assert.Equal(scheduled[1].delay, 30, "warning delay should be 30 seconds")
      scheduled[1].callback()

      Assert.True(controller.IsWarningActive(), "warning should be active after the delay")
      Assert.Equal(#overlays, 1, "one Soul Reaper overlay should be created")
      Assert.True(overlays[1].shown, "Soul Reaper overlay should be shown")
      Assert.Equal(#scheduled, 2, "warning should schedule its hide timer")
      Assert.Equal(scheduled[2].delay, 15, "warning duration should be 15 seconds")

      scheduled[2].callback()
      Assert.False(controller.IsWarningActive(), "warning should stop after the duration")
      Assert.False(overlays[1].shown, "Soul Reaper overlay should be hidden after the duration")
    end)
  end)

  test("VipDkAssist starts Putrefy warning after Dark Transformation", function()
    WithGlobals({}, function()
      local controller, scheduled, overlays = BuildHarness({
        db = { vipDkPutrefyWarningEnabled = true },
        buttons = {},
      })

      controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
      scheduled[1].callback()

      Assert.True(controller.IsWarningActive(), "Putrefy warning should be active after the delay")
      Assert.Equal(#overlays, 1, "one Putrefy overlay should be created")
      Assert.Equal(overlays[1].button.id, "putrefy-button", "Putrefy scanner should provide the warning target")
      Assert.True(overlays[1].shown, "Putrefy overlay should be shown")
    end)
  end)

  test("VipDkAssist can warn Soul Reaper and Putrefy together", function()
    WithGlobals({}, function()
      local controller, scheduled, overlays = BuildHarness({
        db = {
          vipDkSoulReaperWarningEnabled = true,
          vipDkPutrefyWarningEnabled = true,
        },
      })

      controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
      scheduled[1].callback()

      Assert.Equal(#overlays, 2, "both enabled VIP DK warnings should create overlays")
      Assert.Equal(overlays[1].button.id, "soul-reaper-button", "Soul Reaper overlay should be created first")
      Assert.Equal(overlays[2].button.id, "putrefy-button", "Putrefy overlay should be created second")
    end)
  end)

  test("VipDkAssist ignores non-player and unrelated casts", function()
    WithGlobals({}, function()
      local controller, scheduled = BuildHarness()

      controller.HandleUnitSpellcastSucceeded("party1", nil, 1233448)
      controller.HandleUnitSpellcastSucceeded("player", nil, 343294)

      Assert.Equal(#scheduled, 0, "only local Dark Transformation casts may schedule a warning")
    end)
  end)

  test("VipDkAssist respects disabled VIP setting", function()
    WithGlobals({}, function()
      local controller, scheduled = BuildHarness({
        db = {
          vipDkSoulReaperWarningEnabled = false,
          vipDkPutrefyWarningEnabled = false,
        },
      })

      controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)

      Assert.Equal(#scheduled, 0, "disabled VIP setting must keep the feature silent")
    end)
  end)

  test("VipDkAssist fails closed when player is not verified Unholy Death Knight", function()
    WithGlobals({}, function()
      local controller, scheduled = BuildHarness({ isUnholy = false })

      controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)

      Assert.Equal(#scheduled, 0, "non-Unholy or unverifiable player state must keep the feature silent")
    end)
  end)

  test("VipDkAssist SetDependencies exposes central HandleEvent path", function()
    WithGlobals({}, function()
      local VipDkAssist = LoadController()
      local scheduled = {}
      VipDkAssist.SetDependencies({
        getDB = function()
          return { vipDkSoulReaperWarningEnabled = true, vipDkPutrefyWarningEnabled = false }
        end,
        isLocalUnholyDeathKnight = function()
          return true
        end,
        scanSoulReaperButtons = function()
          return {}
        end,
        createOverlay = function()
          return nil
        end,
        timerAfter = function(delay, callback)
          scheduled[#scheduled + 1] = { delay = delay, callback = callback }
        end,
      })

      VipDkAssist.HandleEvent("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 1233448)

      Assert.Equal(#scheduled, 1, "central HandleEvent should route player casts to the controller")
      Assert.Equal(scheduled[1].delay, 30, "central HandleEvent should preserve the warning delay")
    end)
  end)
end

return function(test, ctx)
  RegisterVipDkAssistTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
end
