return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Sync raw dispatch failure is contained and does not consume payload dedupe", function()
    local shouldRaise = true
    local sentMessages = {}
    WithGlobals({
      GetTime = function()
        return 100
      end,
      IsInGroup = function()
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          if shouldRaise then
            error("protected send", 0)
          end
          table.insert(sentMessages, { prefix = prefix, message = message, channel = channel })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      local ok = pcall(addon.Sync.SendStats, { isVisible = true, specID = 72, ilvl = 615, rio = 3210 })
      Assert.True(ok, "raw Blizzard send failures must stay contained")
      Assert.Equal(#sentMessages, 0, "failed dispatch must not report a sent message")

      shouldRaise = false
      addon.Sync.SendStats({ isVisible = true, specID = 72, ilvl = 615, rio = 3210 })
      Assert.Equal(#sentMessages, 1, "identical payload must be immediately retryable after failed dispatch")
    end)
  end)

  test("Sync CTL dispatch failure does not consume payload dedupe", function()
    local shouldRaise = true
    local sentMessages = {}
    WithGlobals({
      GetTime = function()
        return 100
      end,
      IsInGroup = function()
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function()
          error("raw fallback must not run while CTL is available", 0)
        end,
      },
      ChatThrottleLib = {
        SendAddonMessage = function(_, priority, prefix, message, channel)
          if shouldRaise then
            error("CTL send failed", 0)
          end
          table.insert(sentMessages, { priority = priority, prefix = prefix, message = message, channel = channel })
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      local ok = pcall(addon.Sync.SendKey, { isVisible = true, mapID = 2649, level = 12 })
      Assert.True(ok, "CTL failures must stay contained")
      shouldRaise = false
      addon.Sync.SendKey({ isVisible = true, mapID = 2649, level = 12 })
      Assert.Equal(#sentMessages, 1, "failed CTL payload must remain immediately retryable")
    end)
  end)

  test("Sync malformed and unknown isiLive payloads do not establish peer trust", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos or max == 1 then
          return str
        end
        return str:sub(1, pos - 1), str:sub(pos + 1)
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      addon.Sync.ProcessAddonMessage("ISILIVE", "UNKNOWN:anything", "Unknown-Realm", "Me", "Realm")
      addon.Sync.ProcessAddonMessage("ISILIVE", "KEY:not-a-map:not-a-level", "Malformed-Realm", "Me", "Realm")
      Assert.False(addon.Sync.IsUserKnown("Unknown", "Realm"), "unknown payload must not mark its sender")
      Assert.False(addon.Sync.IsUserKnown("Malformed", "Realm"), "malformed payload must not mark its sender")

      addon.Sync.ProcessAddonMessage("ISILIVE", "HELLO:1.0:2:100:test", "Valid-Realm", "Me", "Realm")
      Assert.True(addon.Sync.IsUserKnown("Valid", "Realm"), "valid recognized payload must establish peer trust")
    end)
  end)
end
