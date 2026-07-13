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

  test("Spell utils ignore global cooldown for teleport remaining", function()
    WithGlobals({
      C_Spell = {
        GetSpellCooldown = function(_spellID)
          return {
            startTime = 100,
            duration = 1.5,
            isEnabled = true,
          }
        end,
      },
      GetTime = function()
        return 100.2
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
      local remaining = addon.SpellUtils.GetTeleportCooldownRemaining(777)
      Assert.Equal(remaining, 0, "global cooldown must not count as a teleport cooldown")
    end)
  end)

  test("SpellUtils.GetTeleportCooldownRemaining normalizes wrapped portal cooldown start times", function()
    WithGlobals({
      C_Spell = {
        GetSpellCooldown = function(_spellID)
          return {
            startTime = 4402120,
            duration = 28800,
            isEnabled = true,
          }
        end,
      },
      GetTime = function()
        return 100000
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
      local remaining = addon.SpellUtils.GetTeleportCooldownRemaining(777)
      Assert.Equal(remaining, 10920, "wrapped portal cooldown must keep only the current 8h-cycle remainder")
      Assert.Equal(
        addon.SpellUtils.FormatCooldownSeconds(remaining),
        "03:02",
        "wrapped portal cooldown must format the normalized remainder"
      )
      local start, duration = addon.SpellUtils.GetSpellCooldownSafe(777)
      Assert.Equal(duration, 28800, "duration must remain the observed portal cooldown duration")
      Assert.Equal(start, 4402120, "raw cooldown lookup must preserve the observed Blizzard start time")
      local frameStart, frameDuration = addon.SpellUtils.GetCooldownFrameStartForRemaining(remaining)
      Assert.Equal(frameStart, 100000, "cooldown frame start must use the current session time")
      Assert.Equal(frameDuration, 10920, "cooldown frame duration must use the normalized remaining time")
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
    local recorded = called or {}
    Assert.Equal(recorded["cooldownFrame"], frame, "CooldownFrame_Set should receive original frame")
    Assert.Equal(recorded["startTime"], 11, "CooldownFrame_Set should receive start time")
    Assert.Equal(recorded["duration"], 22, "CooldownFrame_Set should receive duration")
    Assert.True(recorded["isEnabled"], "CooldownFrame_Set should receive enabled state")
  end)

  test("Spell utils apply cooldown prefers SetCooldownFromDurationObject when available", function()
    local durationObjectUsed = false
    local frame = {
      SetCooldownFromDurationObject = function(_self, dur)
        durationObjectUsed = dur
      end,
      SetCooldown = function(_self, _start, _duration)
        error("SetCooldown must not be called when SetCooldownFromDurationObject exists")
      end,
    }

    WithGlobals({
      CreateCooldownDuration = function(start, duration)
        return { start = start, duration = duration, _isDurationObject = true }
      end,
      CooldownFrame_Set = function()
        error("CooldownFrame_Set must not be called when duration object path works")
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
      addon.SpellUtils.ApplyCooldownFrameSafe(frame, 10, 20, true)
    end)

    Assert.NotNil(durationObjectUsed, "must use SetCooldownFromDurationObject")
    local durationObject = durationObjectUsed or {}
    Assert.Equal(durationObject["start"], 10, "duration object must carry start time")
    Assert.Equal(durationObject["duration"], 20, "duration object must carry duration")
  end)

  test("Spell utils apply cooldown duration object path clears when disabled", function()
    local durationObjectUsed = false
    local frame = {
      SetCooldownFromDurationObject = function(_self, dur)
        durationObjectUsed = dur
      end,
      SetCooldown = function()
        error("SetCooldown must not be called")
      end,
    }

    WithGlobals({
      CreateCooldownDuration = function(start, duration)
        return { start = start or 0, duration = duration or 0, _isDurationObject = true }
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
      addon.SpellUtils.ApplyCooldownFrameSafe(frame, 100, 300, false)
    end)

    Assert.NotNil(durationObjectUsed, "must use duration object for disabled cooldown")
  end)

  test("Spell utils apply cooldown falls back to legacy when duration object API is missing", function()
    local called = nil
    local frame = {
      SetCooldownFromDurationObject = function(_self, _dur)
        error("should not be called without CreateCooldownDuration")
      end,
      SetCooldown = function(_self, _start, _duration)
        error("SetCooldown should not be called when CooldownFrame_Set exists")
      end,
    }

    WithGlobals({
      CreateCooldownDuration = nil,
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
      addon.SpellUtils.ApplyCooldownFrameSafe(frame, 5, 15, true)
    end)

    Assert.NotNil(called, "must fall back to CooldownFrame_Set when CreateCooldownDuration is nil")
    local recorded = called or {}
    Assert.Equal(recorded["startTime"], 5, "must pass start to legacy path")
    Assert.Equal(recorded["duration"], 15, "must pass duration to legacy path")
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

-- Branch coverage for the secret-value defensive paths in GetSpellCooldownSafe,
-- the IsSpellKnownSafe early returns + happy paths, and the legacy SetCooldown
-- duration > 0 path in ApplyCooldownFrameSafe.
local function RegisterSpellUtilsBranchTests(test, Assert, WithGlobals, LoadAddonModules)
  test("SpellUtils.GetSpellCooldownSafe replaces secret values for enabled, start, duration", function()
    local SECRET_ENABLED = setmetatable({}, {
      __tostring = function()
        return "secret-enabled"
      end,
    })
    local SECRET_START = setmetatable({}, {
      __tostring = function()
        return "secret-start"
      end,
    })
    local SECRET_DURATION = setmetatable({}, {
      __tostring = function()
        return "secret-duration"
      end,
    })
    WithGlobals({
      C_Spell = {
        GetSpellCooldown = function()
          return {
            startTime = SECRET_START,
            duration = SECRET_DURATION,
            isEnabled = SECRET_ENABLED,
          }
        end,
      },
      issecretvalue = function(value)
        return value == SECRET_ENABLED or value == SECRET_START or value == SECRET_DURATION
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
      local startTime, duration, enabled = addon.SpellUtils.GetSpellCooldownSafe(42)
      Assert.Equal(startTime, 0, "secret start must be replaced with 0")
      Assert.Equal(duration, 0, "secret duration must be replaced with 0")
      Assert.Equal(enabled, true, "secret enabled must be replaced with true")
    end)
  end)

  test("SpellUtils.GetSpellCooldownSafe returns defaults when GetSpellCooldown raises an error", function()
    WithGlobals({
      C_Spell = {
        GetSpellCooldown = function()
          error("simulated API failure")
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
      local startTime, duration, enabled = addon.SpellUtils.GetSpellCooldownSafe(42)
      Assert.Equal(startTime, 0, "API failure must yield default 0 start")
      Assert.Equal(duration, 0, "API failure must yield default 0 duration")
      Assert.Equal(enabled, true, "API failure must yield default true enabled")
    end)
  end)

  test("SpellUtils.IsSpellKnownSafe returns false for nil spellID without invoking the API", function()
    WithGlobals({
      C_SpellBook = {
        IsSpellKnown = function()
          error("must not be called for nil spellID")
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
      Assert.False(addon.SpellUtils.IsSpellKnownSafe(nil), "nil spellID must short-circuit to false")
    end)
  end)

  test("SpellUtils.IsSpellKnownSafe returns true via IsSpellKnownOrOverridesKnown happy path", function()
    WithGlobals({
      C_SpellBook = {
        IsSpellKnownOrOverridesKnown = function()
          return true
        end,
        IsSpellKnown = function()
          return false
        end,
      },
      C_Spell = {
        GetSpellCooldown = function()
          return { startTime = 0, duration = 0, isEnabled = true }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
      Assert.True(addon.SpellUtils.IsSpellKnownSafe(2139), "IsSpellKnownOrOverridesKnown=true must report known")
    end)
  end)

  test("SpellUtils persists only live-confirmed configured portals for account-wide alt reuse", function()
    local portalKnown = true
    WithGlobals({
      IsiLiveDB = {
        verifiedAccountTeleportSpells = {},
      },
      C_SpellBook = {
        IsSpellInSpellBook = function(spellID)
          return portalKnown and (spellID == 1254555 or spellID == 2139)
        end,
        IsSpellKnownOrOverridesKnown = function()
          return false
        end,
        IsSpellKnown = function()
          return false
        end,
      },
      C_Spell = {
        GetSpellCooldown = function()
          return { startTime = 0, duration = 0, isEnabled = true }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
      addon.SeasonData = {
        SEASONS = {
          midnight_s1 = {
            mapToTeleport = {
              [556] = 1254555,
            },
          },
        },
      }
      Assert.True(
        addon.SpellUtils.IsSpellKnownSafe(1254555),
        "a configured portal present in the live player spellbook must be available"
      )
      Assert.Equal(
        IsiLiveDB.verifiedAccountTeleportSpells[1254555],
        true,
        "the live-confirmed configured portal must be persisted"
      )

      Assert.True(addon.SpellUtils.IsSpellKnownSafe(2139), "an unrelated known spell must remain available")
      Assert.Nil(
        IsiLiveDB.verifiedAccountTeleportSpells[2139],
        "an unrelated spell must never enter the account teleport cache"
      )

      portalKnown = false
      Assert.True(
        addon.SpellUtils.IsSpellKnownSafe(1254555),
        "a later alt with false character-local spellbook results must reuse the verified account unlock"
      )
    end)
  end)

  test("SpellUtils.IsSpellKnownSafe falls back to IsSpellKnown when override-aware API misses", function()
    WithGlobals({
      C_SpellBook = {
        IsSpellKnownOrOverridesKnown = function()
          return false
        end,
        IsSpellKnown = function()
          return true
        end,
      },
      C_Spell = {
        GetSpellCooldown = function()
          return { startTime = 0, duration = 0, isEnabled = true }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
      Assert.True(addon.SpellUtils.IsSpellKnownSafe(2139), "IsSpellKnown=true (after override miss) must report known")
    end)
  end)

  test("SpellUtils.GetTeleportCooldownRemaining returns 0 when start is zero", function()
    WithGlobals({
      C_Spell = {
        GetSpellCooldown = function()
          -- Long duration but start=0 → cannot anchor remaining → 0.
          return { startTime = 0, duration = 600, isEnabled = true }
        end,
      },
      GetTime = function()
        return 100
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
      local remaining = addon.SpellUtils.GetTeleportCooldownRemaining(2139)
      Assert.Equal(remaining, 0, "start<=0 with long duration must still report 0 remaining")
    end)
  end)

  test(
    "SpellUtils.ApplyCooldownFrameSafe legacy SetCooldown writes start+duration when enabled and duration > 0",
    function()
      -- Force the last-resort legacy path: no SetCooldownFromDurationObject and
      -- no global CooldownFrame_Set.
      WithGlobals({
        CooldownFrame_Set = false,
        CreateCooldownDuration = false,
      }, function()
        local applied
        local frame = {
          SetCooldown = function(_self, startTime, duration)
            applied = { start = startTime, duration = duration }
          end,
        }
        local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
        addon.SpellUtils.ApplyCooldownFrameSafe(frame, 100, 300, true)

        Assert.NotNil(applied, "legacy SetCooldown must fire")
        Assert.Equal(applied.start, 100, "legacy path must forward the start time")
        Assert.Equal(applied.duration, 300, "legacy path must forward the duration")
      end)
    end
  )

  test("SpellUtils.ApplyCooldownFrameSafe returns silently for nil cooldownFrame", function()
    local addon = LoadAddonModules({ "isiLive_spell_utils.lua" })
    -- No assert needed: must not raise.
    addon.SpellUtils.ApplyCooldownFrameSafe(nil, 100, 300, true)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterSpellKnownAndCooldownTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCooldownFrameApplyTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterSpellUtilsBranchTests(test, Assert, WithGlobals, LoadAddonModules)
end
