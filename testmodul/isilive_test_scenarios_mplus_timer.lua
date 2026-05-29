---@diagnostic disable: undefined-global, undefined-field

-- Scenarios for game/isiLive_mplus_timer.lua.
-- The module is event-driven: CHALLENGE_MODE_START loads the map's time
-- limits + key level and starts a tick loop; _COMPLETED / _RESET stop
-- it and wipes the visible timer; _DEATH_COUNT_UPDATED pulls Blizzard's death count + lost seconds.
-- We stub Blizzard's challenge-mode APIs, load the module, dispatch
-- each event and assert on GetTimerData().

local function BuildEnv(overrides)
  overrides = overrides or {}

  local state = {
    worldElapsed = overrides.worldElapsed or 0,
    deaths = overrides.deaths or 0,
    deathTimeLost = overrides.deathTimeLost or 0,
    keyLevel = overrides.keyLevel or 5,
    mapID = overrides.mapID or 2649,
    timeLimit = overrides.timeLimit or 1800,
    eventHandler = nil,
    tickFrame = nil,
    eventFrame = nil,
    registeredEvents = {},
    createdFrames = {},
  }

  local function makeFrame()
    local f = { _scripts = {}, _registered = {} }
    function f:RegisterEvent(e)
      self._registered[e] = true
      state.registeredEvents[e] = true
    end
    function f:UnregisterEvent(e)
      self._registered[e] = nil
      state.registeredEvents[e] = nil
    end
    function f:SetScript(name, fn)
      self._scripts[name] = fn
    end
    function f:GetScript(name)
      return self._scripts[name]
    end
    return f
  end

  local frames = {}
  local globals = {
    CreateFrame = function()
      local f = makeFrame()
      table.insert(frames, f)
      state.createdFrames = frames
      return f
    end,
    GetWorldElapsedTime = overrides.GetWorldElapsedTime or function()
      return 1, state.worldElapsed
    end,
    C_ChallengeMode = overrides.C_ChallengeMode or {
      GetActiveChallengeMapID = function()
        return state.mapID
      end,
      GetActiveKeystoneInfo = function()
        return state.keyLevel, {}, 0
      end,
      GetMapUIInfo = function()
        return "Dungeon", 1, state.timeLimit
      end,
      GetDeathCount = function()
        return state.deaths, state.deathTimeLost
      end,
    },
  }

  return globals, state, frames
end

local function AfterLoad(frames)
  local eventFrame = {
    GetScript = function(_, scriptName)
      if scriptName ~= "OnEvent" then
        return nil
      end
      return function(_, event)
        local addon = rawget(_G, "__isilive_last_loaded_addon")
        addon.MplusTimer.HandleEvent(event)
      end
    end,
  }
  local tickFrame = {
    GetScript = function(_, scriptName)
      local frame = frames[1]
      return frame and frame:GetScript(scriptName) or nil
    end,
  }
  return eventFrame, tickFrame
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  test("mplus_timer: exposes central event handler and creates no direct event frame on load", function()
    local globals, state = BuildEnv()
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
    end)
    Assert.Equal(type(addon.MplusTimer.HandleEvent), "function", "MplusTimer must expose HandleEvent")
    Assert.Nil(state.registeredEvents["CHALLENGE_MODE_START"], "module load must not directly register events")
    Assert.Equal(#state.createdFrames, 0, "module load must not create event/tick frames before runtime start")
  end)

  test("mplus_timer: idle snapshot before CHALLENGE_MODE_START reports zeros", function()
    local globals = BuildEnv()
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
    end)
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(data.running, false)
    Assert.Equal(data.completed, false)
    Assert.Equal(data.timer, 0)
    Assert.Equal(data.timeLimit, 0)
    Assert.Equal(data.deaths, 0)
    Assert.Equal(data.deathTimeLost, 0)
    Assert.Equal(data.keyLevel, 0, "keyLevel defaults to 0 until a key starts")
  end)

  test("mplus_timer: CHALLENGE_MODE_START loads map limits and arms death penalty above lv4", function()
    local globals, _state, frames = BuildEnv({ keyLevel = 7, timeLimit = 2000 })
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
      local eventFrame = AfterLoad(frames)
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_START")
    end)
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(data.running, true, "key must be marked running after START")
    Assert.Equal(data.timeLimit, 2000, "map time limit must be loaded")
    Assert.Equal(data.keyLevel, 7)
    -- +1 cutoff matches the full time limit.
    Assert.Equal(data.timeRemaining1, 2000)
    Assert.Equal(data.timeRemaining2, 2000 * 0.8)
    Assert.Equal(data.timeRemaining3, 2000 * 0.6)
  end)

  test("mplus_timer: START with key level < 4 disables death-penalty accounting", function()
    local globals, state, frames = BuildEnv({ keyLevel = 3, timeLimit = 1500 })
    state.deaths = 4
    state.deathTimeLost = 60
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
      local eventFrame = AfterLoad(frames)
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_START")
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_DEATH_COUNT_UPDATED")
    end)
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(data.deaths, 4, "death count is still reported")
    Assert.Equal(data.deathTimeLost, 0, "deathTimeLost must be suppressed below lv4")
  end)

  test("mplus_timer: START with level 4 activates death-penalty accounting", function()
    local globals, state, frames = BuildEnv({ keyLevel = 4, timeLimit = 1500 })
    state.deaths = 2
    state.deathTimeLost = 30
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
      local eventFrame = AfterLoad(frames)
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_START")
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_DEATH_COUNT_UPDATED")
    end)
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(data.deathTimeLost, 30, "lv4 is the boundary where penalty turns on")
  end)

  test("mplus_timer: OnUpdate tick pulls elapsed time from GetWorldElapsedTime", function()
    local globals, state, frames = BuildEnv({ keyLevel = 6, timeLimit = 1800 })
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
      local eventFrame, tickFrame = AfterLoad(frames)
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_START")
      -- The key is running; OnUpdate was installed. Pump time > 0.1s
      -- so the tick accumulator fires.
      state.worldElapsed = 120
      tickFrame:GetScript("OnUpdate")(tickFrame, 0.15)
    end)
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(data.timer, 120, "timer must reflect the world elapsed time on tick")
    Assert.Equal(data.timeRemaining1, 1800 - 120)
  end)

  test("mplus_timer: tick accumulator stays under 0.1s without triggering OnUpdate", function()
    local globals, state, frames = BuildEnv({ keyLevel = 6, timeLimit = 1800 })
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
      local eventFrame, tickFrame = AfterLoad(frames)
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_START")
      state.worldElapsed = 50
      tickFrame:GetScript("OnUpdate")(tickFrame, 0.05)
    end)
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(data.timer, 0, "sub-threshold accumulator must not yet update the timer")
  end)

  test("mplus_timer: OnUpdate is a no-op when GetWorldElapsedTime raises", function()
    local globals, state, frames = BuildEnv({ keyLevel = 6, timeLimit = 1800 })
    globals.GetWorldElapsedTime = function()
      error("blizzard api missing", 0)
    end
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
      local eventFrame, tickFrame = AfterLoad(frames)
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_START")
      tickFrame:GetScript("OnUpdate")(tickFrame, 0.5)
    end)
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(data.timer, 0, "pcall failure must leave the timer at zero")
  end)

  test("mplus_timer: CHALLENGE_MODE_COMPLETED wipes timer, deaths, and time limits", function()
    local globals, state, frames = BuildEnv({ keyLevel = 6, timeLimit = 1800 })
    state.deaths = 3
    state.deathTimeLost = 45
    state.worldElapsed = 1500
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
      local eventFrame, tickFrame = AfterLoad(frames)
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_START")
      tickFrame:GetScript("OnUpdate")(tickFrame, 0.15)
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_DEATH_COUNT_UPDATED")
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_COMPLETED")
      Assert.Nil(tickFrame:GetScript("OnUpdate"), "StopTimer must unregister OnUpdate")
    end)
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(data.running, false)
    Assert.Equal(data.completed, false, "COMPLETED must clear the completed timer snapshot")
    Assert.Equal(data.timer, 0)
    Assert.Equal(data.timeLimit, 0)
    Assert.Equal(data.keyLevel, 0)
    Assert.Equal(data.deaths, 0)
    Assert.Equal(data.deathTimeLost, 0)
    Assert.Equal(data.timeRemaining1, 0)
  end)

  test("mplus_timer: PLAYER_ENTERING_WORLD stays cleared after completed key reset", function()
    local globals, state, frames = BuildEnv({ keyLevel = 6, timeLimit = 1800 })
    state.deaths = 3
    state.deathTimeLost = 45
    state.worldElapsed = 1500
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
      local eventFrame, tickFrame = AfterLoad(frames)
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_START")
      tickFrame:GetScript("OnUpdate")(tickFrame, 0.15)
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_DEATH_COUNT_UPDATED")
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_COMPLETED")
      eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_ENTERING_WORLD")
    end)
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(data.completed, false, "PEW must clear completed flag")
    Assert.Equal(data.timer, 0)
    Assert.Equal(data.timeLimit, 0)
    Assert.Equal(data.keyLevel, 0)
    Assert.Equal(data.deaths, 0)
    Assert.Equal(data.deathTimeLost, 0)
    Assert.Equal(data.timeRemaining1, 0)
  end)

  test("mplus_timer: PLAYER_ENTERING_WORLD is a no-op while the key is still running", function()
    local globals, state, frames = BuildEnv({ keyLevel = 6, timeLimit = 1800 })
    state.worldElapsed = 600
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
      local eventFrame, tickFrame = AfterLoad(frames)
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_START")
      tickFrame:GetScript("OnUpdate")(tickFrame, 0.15)
      eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_ENTERING_WORLD")
    end)
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(data.running, true, "PEW mid-key must not stop the run")
    Assert.Equal(data.timer, 600, "PEW mid-key must not reset the timer")
    Assert.Equal(data.timeLimit, 1800)
  end)

  test("mplus_timer: PLAYER_ENTERING_WORLD before any key is a no-op", function()
    local globals, _state, frames = BuildEnv()
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
      local eventFrame = AfterLoad(frames)
      eventFrame:GetScript("OnEvent")(eventFrame, "PLAYER_ENTERING_WORLD")
    end)
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(data.running, false)
    Assert.Equal(data.completed, false)
    Assert.Equal(data.timer, 0)
  end)

  test("mplus_timer: CHALLENGE_MODE_RESET wipes timer, deaths, and time limits", function()
    local globals, state, frames = BuildEnv({ keyLevel = 6, timeLimit = 1800 })
    state.deaths = 5
    state.deathTimeLost = 75
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
      local eventFrame = AfterLoad(frames)
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_START")
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_DEATH_COUNT_UPDATED")
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_RESET")
    end)
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(data.running, false)
    Assert.Equal(data.completed, false, "RESET must not mark the key completed")
    Assert.Equal(data.timer, 0)
    Assert.Equal(data.timeLimit, 0)
    Assert.Equal(data.keyLevel, 0)
    Assert.Equal(data.deaths, 0)
    Assert.Equal(data.deathTimeLost, 0)
    Assert.Equal(data.timeRemaining1, 0, "RESET must zero all cutoffs")
  end)

  test("mplus_timer: GetActiveChallengeMapID pcall failure falls back to zero limits", function()
    local globals, state, frames = BuildEnv({ keyLevel = 6 })
    state.mapID = nil
    globals.C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        error("no active challenge", 0)
      end,
      GetActiveKeystoneInfo = function()
        return 6, {}, 0
      end,
      GetMapUIInfo = function()
        return "Dungeon", 1, 1800
      end,
      GetDeathCount = function()
        return 0, 0
      end,
    }
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
      local eventFrame = AfterLoad(frames)
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_START")
    end)
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(data.timeLimit, 0, "no map ID must keep limits at zero")
    Assert.Equal(data.timeRemaining1, 0)
  end)

  test("mplus_timer: GetMapUIInfo returning non-positive time limit keeps limits at zero", function()
    local globals, _state, frames = BuildEnv({ keyLevel = 6 })
    globals.C_ChallengeMode.GetMapUIInfo = function()
      return "Dungeon", 1, 0
    end
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
      local eventFrame = AfterLoad(frames)
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_START")
    end)
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(data.timeLimit, 0)
  end)

  test("mplus_timer: GetActiveKeystoneInfo non-number result defaults key level to zero", function()
    local globals, _state, frames = BuildEnv({ timeLimit = 1500 })
    globals.C_ChallengeMode.GetActiveKeystoneInfo = function()
      return "not-a-number", {}, 0
    end
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
      local eventFrame = AfterLoad(frames)
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_START")
    end)
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(data.keyLevel, 0)
    Assert.Equal(data.deathTimeLost, 0, "lv0 < lv4 => death penalty off")
  end)

  test("mplus_timer: SetDemoData short-circuits GetTimerData", function()
    local globals = BuildEnv()
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
    end)
    addon.MplusTimer.SetDemoData({ running = true, timer = 999, timeLimit = 1234 })
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(data.timer, 999)
    Assert.Equal(data.timeLimit, 1234)
    addon.MplusTimer.ClearDemoData()
    Assert.Equal(addon.MplusTimer.GetTimerData().timer, 0, "ClearDemoData must return to the live state snapshot")
  end)

  test("mplus_timer: UpdateDeaths tolerates GetDeathCount pcall failure", function()
    local globals, _state, frames = BuildEnv({ keyLevel = 6 })
    globals.C_ChallengeMode.GetDeathCount = function()
      error("dead api", 0)
    end
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_mplus_timer.lua" })
      local eventFrame = AfterLoad(frames)
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_START")
      eventFrame:GetScript("OnEvent")(eventFrame, "CHALLENGE_MODE_DEATH_COUNT_UPDATED")
    end)
    -- Without raising, GetTimerData still returns coherent numbers.
    local data = addon.MplusTimer.GetTimerData()
    Assert.Equal(type(data.deaths), "number")
  end)
end
