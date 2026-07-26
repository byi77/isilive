---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  -- Drives SoundUtils.Play with a controllable clock and records every handle
  -- StopAllActiveSounds passes to StopSound.
  local function BuildSoundEnv()
    local env = { now = 1000, stopped = {}, handleSeq = 0 }
    env.globals = {
      IsiLiveDB = {},
      GetTime = function()
        return env.now
      end,
      PlaySoundFile = function()
        env.handleSeq = env.handleSeq + 1
        return true, "handle:" .. env.handleSeq
      end,
      StopSound = function(handle)
        env.stopped[#env.stopped + 1] = handle
      end,
    }
    return env
  end

  -- Handles were previously kept forever: every played sound left a permanent
  -- entry, so the set grew for the whole session and StopAllActiveSounds fired
  -- StopSound at thousands of long-finished handles. Only the demo tablet ever
  -- cleared it, so a player who never opened the simulation never recovered.
  test("SoundUtils drops sound handles once they can no longer be playing", function()
    local env = BuildSoundEnv()
    WithGlobals(env.globals, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })

      Assert.True(addon.SoundUtils.Play("sounds/a.ogg", "Master"), "first sound must play")

      -- Well past any bundled asset's length: the first handle cannot still be
      -- playing when the second one starts.
      env.now = env.now + 120
      Assert.True(addon.SoundUtils.Play("sounds/b.ogg", "Master"), "second sound must play")

      addon.SoundUtils.StopAllActiveSounds()
      Assert.Equal(#env.stopped, 1, "only the handle that can still be playing may be stopped")
      Assert.Equal(env.stopped[1], "handle:2", "the surviving handle must be the recent one")
    end)
  end)

  test("SoundUtils keeps concurrent handles that can still be playing", function()
    local env = BuildSoundEnv()
    WithGlobals(env.globals, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })

      addon.SoundUtils.Play("sounds/a.ogg", "Master")
      env.now = env.now + 2
      addon.SoundUtils.Play("sounds/b.ogg", "Master")
      env.now = env.now + 2
      addon.SoundUtils.Play("sounds/c.ogg", "Master")

      addon.SoundUtils.StopAllActiveSounds()
      Assert.Equal(#env.stopped, 3, "overlapping playbacks must all still be stoppable")
    end)
  end)

  test("SoundUtils clears every tracked handle after StopAllActiveSounds", function()
    local env = BuildSoundEnv()
    WithGlobals(env.globals, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })

      addon.SoundUtils.Play("sounds/a.ogg", "Master")
      addon.SoundUtils.StopAllActiveSounds()
      Assert.Equal(#env.stopped, 1, "the played handle must be stopped")

      addon.SoundUtils.StopAllActiveSounds()
      Assert.Equal(#env.stopped, 1, "a second stop-all must not re-stop already released handles")
    end)
  end)
end
