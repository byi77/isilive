---@diagnostic disable: undefined-global

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Runtime log controller appends entries only when enabled", function()
    WithGlobals({
      IsiLiveDB = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_log_buffer.lua", "isiLive_runtime_log.lua" })
      local controller = addon.RuntimeLog.CreateController({
        getTimestamp = function()
          return "12:00:00"
        end,
        maxEntries = 10,
      })

      controller.Log("before-enable")
      Assert.Equal(controller.GetLogCount(), 0, "disabled runtime log must ignore entries")

      controller.SetEnabled(true)
      controller.Log("after-enable")
      Assert.Equal(controller.GetLogCount(), 1, "enabled runtime log must append entries")
    end)
  end)

  test("Runtime log controller trims old entries beyond max entries", function()
    WithGlobals({
      IsiLiveDB = {},
    }, function()
      local tick = 0
      local addon = LoadAddonModules({ "isiLive_log_buffer.lua", "isiLive_runtime_log.lua" })
      local controller = addon.RuntimeLog.CreateController({
        getTimestamp = function()
          tick = tick + 1
          return string.format("12:00:%02d", tick)
        end,
        maxEntries = 2,
      })
      controller.SetEnabled(true)

      controller.Log("one")
      controller.Log("two")
      controller.Log("three")

      local tail = controller.GetLogTail(10)
      Assert.Equal(#tail, 2, "runtime log must keep only maxEntries newest entries")
      Assert.True(tail[1]:find("two", 1, true) ~= nil, "oldest retained entry should be second message")
      Assert.True(tail[2]:find("three", 1, true) ~= nil, "newest retained entry should be third message")
    end)
  end)

  test("Runtime log controller sanitizes non-ASCII bytes", function()
    WithGlobals({
      IsiLiveDB = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_log_buffer.lua", "isiLive_runtime_log.lua" })
      local controller = addon.RuntimeLog.CreateController({
        getTimestamp = function()
          return "12:00:00"
        end,
        maxEntries = 10,
      })
      controller.SetEnabled(true)

      controller.Log("abc\195\164xyz")
      local tail = controller.GetLogTail(1)

      Assert.Equal(#tail, 1, "sanitizing test should produce one log entry")
      Assert.True(tail[1]:find("abcxyz", 1, true) ~= nil, "non-ASCII bytes must be removed from stored log text")
    end)
  end)

  test("Runtime log controller tail enforces min/max limits", function()
    WithGlobals({
      IsiLiveDB = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_log_buffer.lua", "isiLive_runtime_log.lua" })
      local controller = addon.RuntimeLog.CreateController({
        getTimestamp = function()
          return "12:00:00"
        end,
        maxEntries = 150,
      })
      controller.SetEnabled(true)

      for i = 1, 120 do
        controller.Log("entry-" .. tostring(i))
      end

      Assert.Equal(#controller.GetLogTail(0), 1, "tail limit below 1 must clamp to one entry")
      Assert.Equal(#controller.GetLogTail(500), 100, "tail limit above cap must clamp to 100 entries")
    end)
  end)
end
