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

  local function BuildDefaultGlobals(db, buttons)
    local scheduled = {}
    local overlays = {}
    local globals = {
      IsiLiveDB = db,
      UnitClass = function(unit)
        if unit == "player" then
          return "Death Knight", "DEATHKNIGHT"
        end
        return nil
      end,
      C_SpecializationInfo = {
        GetSpecialization = function()
          return 3
        end,
        GetSpecializationInfo = function(specIndex)
          if specIndex == 3 then
            return 252
          end
          return nil
        end,
      },
      C_Timer = {
        NewTimer = function(delay, callback)
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
      },
      CreateFrame = function(_, _, parent)
        local overlay = {
          parent = parent,
          shown = nil,
          textures = {},
          frameLevel = nil,
          SetFrameStrata = function(self, strata)
            self.strata = strata
          end,
          SetAllPoints = function(self, target)
            self.allPointsTarget = target
          end,
          SetFrameLevel = function(self, level)
            self.frameLevel = level
          end,
          CreateTexture = function(self)
            local texture = {
              points = {},
              SetColorTexture = function(tex, r, g, b, a)
                tex.color = { r, g, b, a }
              end,
              ClearAllPoints = function(tex)
                tex.points = {}
              end,
              SetPoint = function(tex, ...)
                tex.points[#tex.points + 1] = { ... }
              end,
              SetHeight = function(tex, height)
                tex.height = height
              end,
              SetWidth = function(tex, width)
                tex.width = width
              end,
            }
            self.textures[#self.textures + 1] = texture
            return texture
          end,
          GetSize = function()
            return 40, 50
          end,
          Hide = function(self)
            self.shown = false
          end,
          Show = function(self)
            self.shown = true
          end,
        }
        overlays[#overlays + 1] = overlay
        return overlay
      end,
    }
    for name, button in pairs(buttons or {}) do
      globals[name] = button
    end
    return globals, scheduled, overlays
  end

  local function BuildVisibleActionButton(spellID, actionSlot)
    return {
      action = actionSlot,
      IsVisible = function()
        return true
      end,
      GetSize = function()
        return 36, 36
      end,
      GetFrameLevel = function()
        return 4
      end,
      GetSpellId = spellID and function()
        return spellID
      end or nil,
      GetAction = actionSlot and function()
        return actionSlot
      end or nil,
    }
  end

  test("VipDkAssist default dependencies scan visible action buttons and build overlays", function()
    local globals, scheduled, overlays = BuildDefaultGlobals({
      vipDkSoulReaperWarningEnabled = true,
      vipDkPutrefyWarningEnabled = true,
    }, {
      ActionButton1 = BuildVisibleActionButton(343294),
      MultiBarBottomLeftButton1 = BuildVisibleActionButton(nil, 7),
    })
    globals.GetActionInfo = function(slot)
      if slot == 7 then
        return "spell", 1247378
      end
      return nil
    end

    WithGlobals(globals, function()
      local controller = LoadController().CreateController()

      controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
      Assert.Equal(#scheduled, 1, "default timer should use C_Timer.NewTimer")
      scheduled[1].callback()

      Assert.True(controller.IsWarningActive(), "default controller should show warnings")
      Assert.Equal(#overlays, 2, "default scanners should find both configured buttons")
      Assert.Equal(overlays[1].frameLevel, 14, "overlay should render above the action button")
      Assert.Equal(#overlays[1].textures, 2, "overlay should create the red cross textures")
      Assert.True(overlays[1].shown, "first overlay should be shown")
      Assert.True(overlays[2].shown, "second overlay should be shown")

      scheduled[2].callback()
      Assert.False(controller.IsWarningActive(), "hide timer should clear active state")
      Assert.False(overlays[1].shown, "hide timer should hide the overlay")
    end)
  end)

  test("VipDkAssist default spell resolver supports macro action buttons", function()
    local globals, scheduled, overlays = BuildDefaultGlobals({
      vipDkPutrefyWarningEnabled = true,
    }, {
      ActionButton1 = BuildVisibleActionButton(nil, 9),
    })
    globals.GetActionInfo = function(slot)
      if slot == 9 then
        return "macro", 42
      end
      return nil
    end
    globals.GetMacroSpell = function(macroID)
      if macroID == 42 then
        return 1247378
      end
      return nil
    end

    WithGlobals(globals, function()
      local controller = LoadController().CreateController()

      controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
      scheduled[1].callback()

      Assert.True(controller.IsWarningActive(), "macro spell should resolve to the Putrefy warning")
      Assert.Equal(#overlays, 1, "macro-backed Putrefy button should receive an overlay")
    end)
  end)

  test("VipDkAssist default guards fail closed for unverifiable class and spec APIs", function()
    WithGlobals({
      IsiLiveDB = { vipDkSoulReaperWarningEnabled = true },
      UnitClass = function()
        return "Mage", "MAGE"
      end,
    }, function()
      local controller = LoadController().CreateController()
      controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
      Assert.False(controller.IsWarningActive(), "wrong class should not activate warnings")
    end)

    WithGlobals({
      IsiLiveDB = { vipDkSoulReaperWarningEnabled = true },
      UnitClass = function()
        return "Death Knight", "DEATHKNIGHT"
      end,
    }, function()
      local controller = LoadController().CreateController()
      controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
      Assert.False(controller.IsWarningActive(), "missing specialization API should not activate warnings")
    end)
  end)

  test("VipDkAssist central HandleEvent stops warnings on regen and spec change", function()
    WithGlobals({}, function()
      local VipDkAssist = LoadController()
      local stopped = 0
      VipDkAssist.SetDependencies({
        getDB = function()
          return { vipDkSoulReaperWarningEnabled = true }
        end,
        isLocalUnholyDeathKnight = function()
          return true
        end,
        timerAfter = function()
          return {
            Cancel = function()
              stopped = stopped + 1
            end,
          }
        end,
      })

      VipDkAssist.HandleEvent("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 1233448)
      VipDkAssist.HandleEvent("PLAYER_REGEN_ENABLED")
      VipDkAssist.HandleEvent("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 1233448)
      VipDkAssist.HandleEvent("PLAYER_SPECIALIZATION_CHANGED")
      VipDkAssist.HandleEvent("PLAYER_ENTERING_WORLD")

      Assert.Equal(stopped, 2, "regen and spec changes should stop pending warning timers")
    end)
  end)
end

return function(test, ctx)
  RegisterVipDkAssistTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
end
