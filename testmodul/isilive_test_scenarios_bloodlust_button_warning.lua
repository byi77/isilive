---@diagnostic disable: undefined-global
local function RegisterBloodlustButtonWarningTests(test, Assert, WithGlobals, LoadAddonModules)
  local function LoadController()
    local addon = LoadAddonModules({ "isiLive_action_button_overlay.lua", "isiLive_bloodlust_button_warning.lua" })
    return addon.BloodlustButtonWarning
  end

  local function BuildOverlay(button, overlays)
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
  end

  test("BloodlustButtonWarning shows a cross on a Bloodlust button while debuffed when enabled", function()
    WithGlobals({}, function()
      local overlays = {}
      local button = { id = "lust-button" }
      local controller = LoadController().CreateController({
        getDB = function()
          return { vipBloodlustDebuffButtonWarningEnabled = true }
        end,
        isLocalBloodlustClass = function()
          return true
        end,
        hasBloodlustExhaustionDebuff = function()
          return true
        end,
        scanBloodlustButtons = function()
          return { button }
        end,
        createOverlay = function(target)
          return BuildOverlay(target, overlays)
        end,
      })

      controller.Refresh()

      Assert.Equal(#overlays, 1, "one Bloodlust button overlay should be created")
      Assert.Equal(overlays[1].button, button, "overlay must be attached to the scanned Bloodlust button")
      Assert.True(overlays[1].shown, "overlay should be visible while the debuff is active")
    end)
  end)

  test("BloodlustButtonWarning hides when the setting is missing disabled or the class is not verified", function()
    WithGlobals({}, function()
      local overlays = {}
      local controller = LoadController().CreateController({
        getDB = function()
          return {}
        end,
        isLocalBloodlustClass = function()
          return true
        end,
        hasBloodlustExhaustionDebuff = function()
          return true
        end,
        scanBloodlustButtons = function()
          return { { id = "lust-button" } }
        end,
        createOverlay = function(target)
          return BuildOverlay(target, overlays)
        end,
      })

      controller.Refresh()
      Assert.Equal(#overlays, 0, "missing setting must default to disabled and not create overlays")

      controller = LoadController().CreateController({
        getDB = function()
          return { vipBloodlustDebuffButtonWarningEnabled = false }
        end,
        isLocalBloodlustClass = function()
          return true
        end,
        hasBloodlustExhaustionDebuff = function()
          return true
        end,
        scanBloodlustButtons = function()
          return { { id = "lust-button" } }
        end,
        createOverlay = function(target)
          return BuildOverlay(target, overlays)
        end,
      })

      controller.Refresh()
      Assert.Equal(#overlays, 0, "disabled setting must not create overlays")

      controller = LoadController().CreateController({
        getDB = function()
          return { vipBloodlustDebuffButtonWarningEnabled = true }
        end,
        isLocalBloodlustClass = function()
          return false
        end,
        hasBloodlustExhaustionDebuff = function()
          return true
        end,
        scanBloodlustButtons = function()
          return { { id = "lust-button" } }
        end,
        createOverlay = function(target)
          return BuildOverlay(target, overlays)
        end,
      })

      controller.Refresh()
      Assert.Equal(#overlays, 0, "unverified non-Bloodlust classes must stay hidden")
    end)
  end)

  test("BloodlustButtonWarning hides an existing overlay when the debuff expires", function()
    WithGlobals({}, function()
      local overlays = {}
      local hasDebuff = true
      local button = { id = "lust-button" }
      local controller = LoadController().CreateController({
        getDB = function()
          return { vipBloodlustDebuffButtonWarningEnabled = true }
        end,
        isLocalBloodlustClass = function()
          return true
        end,
        hasBloodlustExhaustionDebuff = function()
          return hasDebuff
        end,
        scanBloodlustButtons = function()
          return { button }
        end,
        createOverlay = function(target)
          return BuildOverlay(target, overlays)
        end,
      })

      controller.Refresh()
      Assert.True(overlays[1].shown, "overlay should start visible")

      hasDebuff = false
      controller.Refresh()
      Assert.False(overlays[1].shown, "overlay must hide when the debuff is gone")
    end)
  end)

  test("BloodlustButtonWarning central event path ignores non-player UNIT_AURA and refreshes player events", function()
    WithGlobals({}, function()
      local refreshes = 0
      local BloodlustButtonWarning = LoadController()
      BloodlustButtonWarning.SetDependencies({
        getDB = function()
          return { vipBloodlustDebuffButtonWarningEnabled = true }
        end,
        isLocalBloodlustClass = function()
          return true
        end,
        hasBloodlustExhaustionDebuff = function()
          refreshes = refreshes + 1
          return false
        end,
      })

      Assert.Equal(refreshes, 0, "SetDependencies should only wire dependencies")
      BloodlustButtonWarning.HandleEvent("UNIT_AURA", "party1")
      Assert.Equal(refreshes, 0, "non-player UNIT_AURA must be ignored")
      BloodlustButtonWarning.HandleEvent("UNIT_AURA", "player")
      Assert.Equal(refreshes, 1, "player UNIT_AURA must refresh the warning state")
      BloodlustButtonWarning.HandleEvent("PLAYER_REGEN_ENABLED")
      Assert.Equal(refreshes, 2, "PLAYER_REGEN_ENABLED must refresh the warning state")
    end)
  end)

  local function BuildVisibleActionButton(spellID)
    return {
      IsVisible = function()
        return true
      end,
      GetSize = function()
        return 36, 36
      end,
      GetFrameLevel = function()
        return 4
      end,
      GetSpellId = function()
        return spellID
      end,
    }
  end

  test("BloodlustButtonWarning default dependencies use exact Bloodlust spells and ignore drums", function()
    local overlays = {}
    local globals = {
      IsiLiveDB = { vipBloodlustDebuffButtonWarningEnabled = true },
      UnitClass = function(unit)
        if unit == "player" then
          return "Shaman", "SHAMAN"
        end
        return nil
      end,
      C_UnitAuras = {
        GetAuraDataByIndex = function(unit, index, filter)
          if unit == "player" and index == 1 and filter == "HARMFUL" then
            return { spellId = 57724 }
          end
          return nil
        end,
      },
      ActionButton1 = BuildVisibleActionButton(2825),
      ActionButton2 = BuildVisibleActionButton(381301),
      CreateFrame = function(_, _, parent)
        local overlay = {
          parent = parent,
          textures = {},
          shown = nil,
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
              SetColorTexture = function() end,
              ClearAllPoints = function() end,
              SetPoint = function() end,
              SetHeight = function() end,
              SetWidth = function() end,
            }
            self.textures[#self.textures + 1] = texture
            return texture
          end,
          GetSize = function()
            return 36, 36
          end,
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
    }

    WithGlobals(globals, function()
      local controller = LoadController().CreateController()
      controller.Refresh()

      Assert.Equal(#overlays, 1, "only the exact class Bloodlust spell should receive an overlay")
      Assert.Equal(overlays[1].parent, globals.ActionButton1, "drums must not count as a Bloodlust class button")
      Assert.True(overlays[1].shown, "exact Bloodlust overlay should be shown")
      Assert.Equal(#overlays[1].textures, 2, "shared cross overlay should create both red bars")
    end)
  end)
end

return function(test, ctx)
  RegisterBloodlustButtonWarningTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
end
