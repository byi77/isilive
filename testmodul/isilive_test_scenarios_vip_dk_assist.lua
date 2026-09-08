---@diagnostic disable: undefined-global
local function RegisterVipDkAssistTests(test, Assert, WithGlobals, LoadAddonModules)
  local function LoadController()
    local addon = LoadAddonModules({ "isiLive_action_button_overlay.lua", "isiLive_vip_dk_assist.lua" })
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
      getPutrefyCharges = function()
        return overrides.putrefyCharges
      end,
      getDarkTransformationCooldownRemaining = function()
        return overrides.cooldownRemaining
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

  test("VipDkAssist suppresses the Putrefy warning while 2 or more charges are banked", function()
    WithGlobals({}, function()
      for _, charges in ipairs({ 2, 3 }) do
        local controller, scheduled, overlays = BuildHarness({
          db = { vipDkPutrefyWarningEnabled = true },
          buttons = {},
          putrefyCharges = charges,
        })

        controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
        scheduled[1].callback()

        Assert.Equal(#overlays, 0, "banked Putrefy charges must not be held back into the recharge cap")
        Assert.False(controller.IsWarningActive(), "a warning without any overlay must not report itself active")
      end
    end)
  end)

  test("VipDkAssist warns Putrefy while a single charge is left", function()
    WithGlobals({}, function()
      local controller, scheduled, overlays = BuildHarness({
        db = { vipDkPutrefyWarningEnabled = true },
        buttons = {},
        putrefyCharges = 1,
      })

      controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
      scheduled[1].callback()

      Assert.Equal(#overlays, 1, "the last Putrefy charge should be banked for Dark Transformation")
      Assert.True(overlays[1].shown, "Putrefy overlay should be shown for the last charge")
    end)
  end)

  test("VipDkAssist keeps the Putrefy warning when charges are unreadable", function()
    WithGlobals({}, function()
      local controller, scheduled, overlays = BuildHarness({
        db = { vipDkPutrefyWarningEnabled = true },
        buttons = {},
        putrefyCharges = nil,
      })

      controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
      scheduled[1].callback()

      Assert.Equal(#overlays, 1, "unreadable charges must fall back to the previous warning behaviour")
    end)
  end)

  test("VipDkAssist charge guard leaves the Soul Reaper warning untouched", function()
    WithGlobals({}, function()
      local controller, scheduled, overlays = BuildHarness({
        db = {
          vipDkSoulReaperWarningEnabled = true,
          vipDkPutrefyWarningEnabled = true,
        },
        putrefyCharges = 3,
      })

      controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
      scheduled[1].callback()

      Assert.Equal(#overlays, 1, "only the Putrefy overlay may be suppressed by the charge guard")
      Assert.Equal(overlays[1].button.id, "soul-reaper-button", "Soul Reaper must warn independently of Putrefy")
    end)
  end)

  test("VipDkAssist anchors the warning window to the live Dark Transformation cooldown", function()
    WithGlobals({}, function()
      local controller, scheduled = BuildHarness({ cooldownRemaining = 60 })
      controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
      Assert.Equal(scheduled[1].delay, 45, "a 60s cooldown should warn during its last 15 seconds")

      local shortened, shortenedScheduled = BuildHarness({ cooldownRemaining = 20 })
      shortened.HandleUnitSpellcastSucceeded("player", nil, 1233448)
      Assert.Equal(shortenedScheduled[1].delay, 5, "a shortened cooldown must move the window with it")

      local immediate, immediateScheduled = BuildHarness({ cooldownRemaining = 12 })
      immediate.HandleUnitSpellcastSucceeded("player", nil, 1233448)
      Assert.Equal(immediateScheduled[1].delay, 0, "a cooldown below the window length must warn immediately")
    end)
  end)

  test("VipDkAssist falls back to the fixed delay for untrusted cooldown reads", function()
    WithGlobals({}, function()
      for _, remaining in ipairs({ 1.5, 400 }) do
        local controller, scheduled = BuildHarness({ cooldownRemaining = remaining })
        controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
        Assert.Equal(scheduled[1].delay, 30, "a GCD-sized or absurd cooldown read must fall back to 30 seconds")
      end

      local unreadable, unreadableScheduled = BuildHarness({ cooldownRemaining = nil })
      unreadable.HandleUnitSpellcastSucceeded("player", nil, 1233448)
      Assert.Equal(unreadableScheduled[1].delay, 30, "an unreadable cooldown must fall back to 30 seconds")
    end)
  end)

  test("VipDkAssist preview shows the warning without waiting for the cooldown", function()
    WithGlobals({}, function()
      local controller, scheduled, overlays = BuildHarness()

      Assert.True(controller.ShowWarningPreview(), "preview should report the warning as visible")
      Assert.True(controller.IsWarningActive(), "preview should activate the warning immediately")
      Assert.Equal(#overlays, 1, "preview should build the same overlay as a real Dark Transformation")
      Assert.Equal(#scheduled, 1, "preview should only schedule the hide timer")
      Assert.Equal(scheduled[1].delay, 15, "preview should expire after the normal warning duration")

      scheduled[1].callback()
      Assert.False(controller.IsWarningActive(), "preview should clear itself like the real warning")
    end)
  end)

  test("VipDkAssist preview keeps every guard that the real warning has", function()
    WithGlobals({}, function()
      local disabled = BuildHarness({ db = { vipDkSoulReaperWarningEnabled = false } })
      Assert.False(disabled.ShowWarningPreview(), "preview must stay silent while the VIP toggle is off")

      local wrongSpec = BuildHarness({ isUnholy = false })
      Assert.False(wrongSpec.ShowWarningPreview(), "preview must stay silent for a non-Unholy player")

      local banked = BuildHarness({
        db = { vipDkPutrefyWarningEnabled = true },
        buttons = {},
        putrefyCharges = 3,
      })
      Assert.False(banked.ShowWarningPreview(), "preview must respect the Putrefy charge guard")

      local noButtons = BuildHarness({ buttons = {} })
      Assert.False(noButtons.ShowWarningPreview(), "preview must stay silent when no action button resolves")
    end)
  end)

  test("VipDkAssist preview replaces a pending warning instead of stacking it", function()
    WithGlobals({}, function()
      local controller, scheduled = BuildHarness()

      controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
      Assert.Equal(#scheduled, 1, "the cast should schedule the delayed warning")

      controller.ShowWarningPreview()
      Assert.True(scheduled[1].canceled, "the preview must cancel the pending delayed warning")
    end)
  end)

  test("VipDkAssist module-level preview needs a wired controller", function()
    WithGlobals({}, function()
      local VipDkAssist = LoadController()
      Assert.False(VipDkAssist.ShowWarningPreview(), "preview must fail closed before dependencies are set")

      VipDkAssist.SetDependencies({
        getDB = function()
          return { vipDkSoulReaperWarningEnabled = true }
        end,
        isLocalUnholyDeathKnight = function()
          return true
        end,
        scanSoulReaperButtons = function()
          return { { id = "soul-reaper-button" } }
        end,
        createOverlay = function(button)
          return {
            button = button,
            Show = function() end,
            Hide = function() end,
          }
        end,
        timerAfter = function() end,
      })

      Assert.True(VipDkAssist.ShowWarningPreview(), "a wired controller should expose the preview")
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
      UnitExists = function()
        return true
      end,
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

  test("VipDkAssist default charge reader unpacks the GetSpellCharges struct return", function()
    for _, case in ipairs({
      { charges = 3, expectedOverlays = 0, message = "3 banked charges must suppress the default Putrefy warning" },
      { charges = 1, expectedOverlays = 1, message = "a single charge must still warn through the default reader" },
    }) do
      local globals, scheduled, overlays = BuildDefaultGlobals({
        vipDkPutrefyWarningEnabled = true,
      }, {
        ActionButton1 = BuildVisibleActionButton(1247378),
      })
      globals.C_Spell = {
        GetSpellCharges = function(spellID)
          if spellID ~= 1247378 then
            return nil
          end
          return { currentCharges = case.charges, maxCharges = 3, cooldownStartTime = 100, cooldownDuration = 30 }
        end,
      }

      WithGlobals(globals, function()
        local controller = LoadController().CreateController()

        controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
        scheduled[1].callback()

        Assert.Equal(#overlays, case.expectedOverlays, case.message)
      end)
    end
  end)

  test("VipDkAssist default spell resolver reads secure action button attributes", function()
    local globals, scheduled, overlays = BuildDefaultGlobals({
      vipDkSoulReaperWarningEnabled = true,
    }, {
      ActionButton1 = {
        IsVisible = function()
          return true
        end,
        GetSize = function()
          return 36, 36
        end,
        GetFrameLevel = function()
          return 4
        end,
        GetAttribute = function(_, key)
          if key == "action" then
            return 8
          end
          return nil
        end,
      },
    })
    globals.GetActionInfo = function(slot)
      if slot == 8 then
        return "spell", 343294
      end
      return nil
    end

    WithGlobals(globals, function()
      local controller = LoadController().CreateController()

      controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
      scheduled[1].callback()

      Assert.True(controller.IsWarningActive(), "secure action attribute should resolve to the Soul Reaper warning")
      Assert.Equal(#overlays, 1, "attribute-backed Soul Reaper button should receive an overlay")
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

  test("VipDkAssist keeps pending warning timer across regen and stops on spec change", function()
    WithGlobals({}, function()
      local VipDkAssist = LoadController()
      local stopped = 0
      local scheduled = {}
      VipDkAssist.SetDependencies({
        getDB = function()
          return { vipDkSoulReaperWarningEnabled = true }
        end,
        isLocalUnholyDeathKnight = function()
          return true
        end,
        scanSoulReaperButtons = function()
          return { { id = "soul-reaper-button" } }
        end,
        createOverlay = function(button)
          return {
            button = button,
            shown = false,
            Show = function(self)
              self.shown = true
            end,
            Hide = function(self)
              self.shown = false
            end,
          }
        end,
        timerAfter = function(delay, callback)
          local timer = {
            delay = delay,
            callback = callback,
            Cancel = function()
              stopped = stopped + 1
            end,
          }
          scheduled[#scheduled + 1] = timer
          return timer
        end,
      })

      VipDkAssist.HandleEvent("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 1233448)
      VipDkAssist.HandleEvent("PLAYER_REGEN_ENABLED")
      Assert.Equal(stopped, 0, "regen must not cancel the pending Dark Transformation warning timer")
      scheduled[1].callback()
      Assert.Equal(#scheduled, 2, "pending warning should still show and schedule its hide timer after regen")

      VipDkAssist.HandleEvent("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 1233448)
      VipDkAssist.HandleEvent("PLAYER_SPECIALIZATION_CHANGED")
      VipDkAssist.HandleEvent("PLAYER_ENTERING_WORLD")

      Assert.Equal(
        stopped,
        2,
        "a new cast should cancel the old hide timer and spec changes should stop pending timers"
      )
    end)
  end)

  test("VipDkAssist applies missing-ghoul reminder only for enabled Unholy DK", function()
    WithGlobals({}, function()
      local db = { vipDkGhoulReminderEnabled = true }
      local registered = {}
      local unregistered = {}
      local frame = {
        hidden = false,
        text = {
          SetText = function(self, text)
            self.text = text
          end,
        },
        Hide = function(self)
          self.hidden = true
        end,
      }
      local controller = LoadController().CreateController({
        getDB = function()
          return db
        end,
        getL = function()
          return { VIP_DK_GHOUL_REMINDER_TEXT = "SUMMON GHOUL" }
        end,
        isLocalUnholyDeathKnight = function()
          return db.isUnholy ~= false
        end,
        createGhoulReminderFrame = function()
          return frame
        end,
        registerStateDriver = function(target, attribute, driver)
          registered[#registered + 1] = { target = target, attribute = attribute, driver = driver }
        end,
        unregisterStateDriver = function(target, attribute)
          unregistered[#unregistered + 1] = { target = target, attribute = attribute }
        end,
      })

      controller.ApplyGhoulReminder()

      Assert.Equal(#registered, 1, "enabled Unholy DK ghoul reminder should register the visibility driver")
      Assert.Equal(registered[1].attribute, "visibility", "ghoul reminder must use the visibility state driver")
      Assert.Equal(
        registered[1].driver,
        "[spec:3,nopet,nomounted,novehicleui] show; hide",
        "ghoul reminder visibility must be owned by the verified state driver"
      )
      Assert.Equal(frame.text.text, "SUMMON GHOUL", "ghoul reminder should localize its displayed warning text")

      db.isUnholy = false
      controller.ApplyGhoulReminder()

      Assert.Equal(#unregistered, 1, "non-Unholy state must unregister the ghoul reminder driver")
      Assert.True(frame.hidden, "non-Unholy state must hide the ghoul reminder")
    end)
  end)

  test("VipDkAssist defers ghoul reminder state-driver changes during combat", function()
    WithGlobals({}, function()
      local inCombat = true
      local registered = 0
      local db = { vipDkGhoulReminderEnabled = true }
      local controller = LoadController().CreateController({
        getDB = function()
          return db
        end,
        isLocalUnholyDeathKnight = function()
          return true
        end,
        isInCombat = function()
          return inCombat
        end,
        createGhoulReminderFrame = function()
          return {
            Hide = function() end,
            text = {
              SetText = function() end,
            },
          }
        end,
        registerStateDriver = function()
          registered = registered + 1
        end,
      })

      controller.ApplyGhoulReminder()
      Assert.Equal(registered, 0, "combat lockdown must defer ghoul reminder state-driver registration")

      inCombat = false
      controller.ApplyPendingGhoulReminder()

      Assert.Equal(registered, 1, "regen must apply the deferred ghoul reminder state-driver registration")
    end)
  end)

  test("VipDkAssist ghoul reminder frame restores and saves its own position", function()
    local db = {
      vipDkGhoulReminderEnabled = true,
      vipDkGhoulReminderPosition = {
        point = "TOP",
        relativePoint = "TOP",
        x = 12,
        y = -80,
      },
    }
    local frame
    local function CreateFrameStub()
      frame = {
        points = {},
        scripts = {},
        textures = {},
        fontStrings = {},
        SetSize = function(self, width, height)
          self.width = width
          self.height = height
        end,
        SetPoint = function(self, point, _relativeTo, relativePoint, x, y)
          self.points[#self.points + 1] = { point = point, relativePoint = relativePoint, x = x, y = y }
        end,
        ClearAllPoints = function(self)
          self.points = {}
        end,
        GetPoint = function()
          return "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 22, 33
        end,
        SetFrameStrata = function(self, strata)
          self.strata = strata
        end,
        SetClampedToScreen = function(self, clamped)
          self.clamped = clamped
        end,
        SetMovable = function(self, movable)
          self.movable = movable
        end,
        EnableMouse = function(self, enabled)
          self.mouseEnabled = enabled
        end,
        RegisterForDrag = function(self, button)
          self.dragButton = button
        end,
        CreateTexture = function(self)
          local texture = {
            SetAllPoints = function(tex, target)
              tex.allPoints = target
            end,
            SetColorTexture = function(tex, r, g, b, a)
              tex.color = { r, g, b, a }
            end,
          }
          self.textures[#self.textures + 1] = texture
          return texture
        end,
        CreateFontString = function(self)
          local fontString = {
            SetPoint = function(fs, ...)
              fs.point = { ... }
            end,
            SetTextColor = function(fs, ...)
              fs.color = { ... }
            end,
            SetText = function(fs, text)
              fs.text = text
            end,
            SetFont = function(fs, ...)
              fs.font = { ... }
            end,
          }
          self.fontStrings[#self.fontStrings + 1] = fontString
          return fontString
        end,
        SetScript = function(self, scriptName, handler)
          self.scripts[scriptName] = handler
        end,
        StartMoving = function(self)
          self.startedMoving = true
        end,
        StopMovingOrSizing = function(self)
          self.stoppedMoving = true
        end,
        Hide = function(self)
          self.hidden = true
        end,
      }
      return frame
    end

    WithGlobals({
      UIParent = {},
      CreateFrame = function()
        return CreateFrameStub()
      end,
    }, function()
      local controller = LoadController().CreateController({
        getDB = function()
          return db
        end,
        isLocalUnholyDeathKnight = function()
          return true
        end,
        registerStateDriver = function() end,
      })

      controller.ApplyGhoulReminder()

      local reminderFrame = Assert.NotNil(controller.GetGhoulReminderFrame(), "ghoul reminder frame should be created")
      Assert.True(reminderFrame.clamped, "ghoul reminder frame should be clamped to the screen")
      Assert.True(reminderFrame.movable, "ghoul reminder frame should be movable")
      Assert.Equal(reminderFrame.dragButton, "LeftButton", "ghoul reminder should use left-button dragging")
      Assert.Equal(reminderFrame.points[1].point, "TOP", "ghoul reminder should restore saved point")
      Assert.Equal(reminderFrame.points[1].relativePoint, "TOP", "ghoul reminder should restore saved relative point")
      Assert.Equal(reminderFrame.points[1].x, 12, "ghoul reminder should restore saved x")
      Assert.Equal(reminderFrame.points[1].y, -80, "ghoul reminder should restore saved y")
      Assert.Equal(reminderFrame.fontStrings[1].text, "SUMMON GHOUL", "default ghoul reminder text should render")

      reminderFrame.scripts.OnDragStart(reminderFrame)
      reminderFrame.scripts.OnDragStop(reminderFrame)

      Assert.True(reminderFrame.startedMoving, "drag start should move the ghoul reminder")
      Assert.True(reminderFrame.stoppedMoving, "drag stop should stop moving the ghoul reminder")
      Assert.Equal(db.vipDkGhoulReminderPosition.point, "BOTTOMLEFT", "drag stop should save ghoul reminder point")
      Assert.Equal(db.vipDkGhoulReminderPosition.x, 22, "drag stop should save ghoul reminder x")
      Assert.Equal(db.vipDkGhoulReminderPosition.y, 33, "drag stop should save ghoul reminder y")
    end)
  end)
end

return function(test, ctx)
  RegisterVipDkAssistTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
end
