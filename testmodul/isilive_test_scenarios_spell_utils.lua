local function RegisterSpellKnownAndCooldownTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Spell utils keep teleports recognized during cooldown", function()
    WithGlobals({
      C_SpellBook = {
        IsSpellKnownOrOverridesKnown = function(_spellID)
          return false
        end,
        IsSpellKnown = function(_spellID)
          return false
        end,
      },
      C_Spell = {
        GetSpellCooldown = function(_spellID)
          return {
            startTime = 100,
            duration = 300,
            isEnabled = true,
          }
        end,
      },
      GetTime = function()
        return 250
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
      local known = addon.SpellUtils.IsSpellKnownSafe(12345)
      Assert.True(known, "spell should be treated as known while on meaningful cooldown")

      local remaining = addon.SpellUtils.GetTeleportCooldownRemaining(12345)
      Assert.Equal(remaining, 150, "cooldown remaining must be computed from start + duration")

      local formatted = addon.SpellUtils.FormatCooldownSeconds(28800)
      Assert.Equal(formatted, "08:00", "8h cooldown should format to 08:00")
    end)
  end)

  test("Spell utils cooldown-safe lookup returns defaults without API", function()
    local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
    local startTime, duration, isEnabled = addon.SpellUtils.GetSpellCooldownSafe(42)

    Assert.Equal(startTime, 0, "missing cooldown API should return start=0")
    Assert.Equal(duration, 0, "missing cooldown API should return duration=0")
    Assert.True(isEnabled, "missing cooldown API should return enabled=true")
  end)

  test("Spell utils cooldown remaining is zero when disabled or expired", function()
    WithGlobals({
      C_Spell = {
        GetSpellCooldown = function(_spellID)
          return {
            startTime = 100,
            duration = 30,
            isEnabled = false,
          }
        end,
      },
      GetTime = function()
        return 1000
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
      local disabled = addon.SpellUtils.GetTeleportCooldownRemaining(777)
      Assert.Equal(disabled, 0, "disabled cooldown should report zero remaining")
    end)

    WithGlobals({
      C_Spell = {
        GetSpellCooldown = function(_spellID)
          return {
            startTime = 100,
            duration = 30,
            isEnabled = true,
          }
        end,
      },
      GetTime = function()
        return 1000
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
      local expired = addon.SpellUtils.GetTeleportCooldownRemaining(777)
      Assert.Equal(expired, 0, "expired cooldown should clamp to zero remaining")
    end)
  end)
end

local function RegisterCooldownFrameApplyTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Spell utils apply cooldown uses CooldownFrame_Set when available", function()
    local called = nil
    local frame = {
      SetCooldown = function(_self, _start, _duration)
        error("SetCooldown should not be called when CooldownFrame_Set exists")
      end,
    }

    WithGlobals({
      CooldownFrame_Set = function(cooldownFrame, startTime, duration, isEnabled)
        called = {
          cooldownFrame = cooldownFrame,
          startTime = startTime,
          duration = duration,
          isEnabled = isEnabled,
        }
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
      addon.SpellUtils.ApplyCooldownFrameSafe(frame, 11, 22, true)
    end)

    Assert.NotNil(called, "CooldownFrame_Set should be called when available")
    Assert.Equal(called.cooldownFrame, frame, "CooldownFrame_Set should receive original frame")
    Assert.Equal(called.startTime, 11, "CooldownFrame_Set should receive start time")
    Assert.Equal(called.duration, 22, "CooldownFrame_Set should receive duration")
    Assert.True(called.isEnabled, "CooldownFrame_Set should receive enabled state")
  end)

  test("Spell utils apply cooldown fallback clears frame when disabled", function()
    local appliedStart = nil
    local appliedDuration = nil
    local frame = {
      SetCooldown = function(_self, startTime, duration)
        appliedStart = startTime
        appliedDuration = duration
      end,
    }

    local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
    addon.SpellUtils.ApplyCooldownFrameSafe(frame, 100, 300, false)

    Assert.Equal(appliedStart, 0, "disabled cooldown should clear with start=0")
    Assert.Equal(appliedDuration, 0, "disabled cooldown should clear with duration=0")
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterSpellKnownAndCooldownTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCooldownFrameApplyTests(test, Assert, WithGlobals, LoadAddonModules)
end
