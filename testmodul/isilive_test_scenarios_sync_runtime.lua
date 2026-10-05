---@diagnostic disable: undefined-global

local function RegisterSyncRuntimeLogBurstTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Sync runtime logger keeps capped trace across 2000 message burst", function()
    WithGlobals({
      IsiLiveDB = {},
      GetTime = function()
        return 1000
      end,
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str:sub(1, pos - 1)
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_log_buffer.lua", "isiLive_runtime_log.lua", "isiLive_sync.lua" })
      local runtimeLog = addon.RuntimeLog.CreateController({
        getTimestamp = function()
          return "1000.000"
        end,
        maxEntries = 100,
      })
      runtimeLog.SetEnabled(true)
      addon.Sync.SetTraceLogger(runtimeLog.Trace)

      -- Index is a counter, not a key level: keep it under the sanity bound.
      local lastLevel
      for i = 1, 2000 do
        lastLevel = ((i - 1) % 500) + 1
        addon.Sync.ProcessAddonMessage("ISILIVE", "KEY:2649:" .. tostring(lastLevel), "Peer-Realm", "Me", "Realm")
      end

      local keyInfo = addon.Sync.GetPlayerKeyInfo("Peer", "Realm")
      local tail = runtimeLog.GetLogTail(100)
      Assert.Equal(runtimeLog.GetLogCount(), 100, "sync burst trace must stay capped")
      Assert.Equal(#tail, 100, "sync burst tail must stay capped")
      Assert.NotNil(keyInfo, "sync burst must keep applying latest key state")
      Assert.Equal(keyInfo.level, lastLevel, "sync burst must retain latest applied key level")
      Assert.True(
        tail[#tail]:find("%[SYNC%] event=message_applied sender=Peer%-Realm") ~= nil,
        "tail must include applied sync trace"
      )
    end)
  end)

  test("Sync runtime trace logger passes a lazy builder to runtime logging", function()
    WithGlobals({
      IsiLiveDB = {},
      GetTime = function()
        return 1000
      end,
      IsInGroup = function(category)
        -- Home party only; see the category note on the other group stubs.
        return category ~= 2
      end,
      IsInRaid = function()
        return false
      end,
      UnitExists = function(unit)
        return unit == "player"
      end,
      C_ChatInfo = {
        SendAddonMessage = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      local capturedBuilder = nil

      addon.Sync.SetTraceLogger(function(builder)
        capturedBuilder = builder
      end)
      addon.Sync.SendRefreshRequest({ force = true })

      Assert.Equal(type(capturedBuilder), "function", "sync trace logger must receive a lazy message builder")
      local formatted = capturedBuilder and capturedBuilder() or nil
      Assert.Equal(formatted, "[SYNC] send_reqsync channel=PARTY sent=true", "sync trace builder must format on demand")
    end)
  end)

  test("Sync ProcessAddonMessage deep trace exposes raw bucket payloads and sender bytes", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str:sub(1, pos - 1)
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      local lines = {}
      addon.Sync.SetDeepTraceLogger(function(builder)
        table.insert(lines, builder())
      end)

      addon.Sync.ProcessAddonMessage("ISILIVE", "KEY:2649:17:123:hello", "Kürshad-Blackmoore", "Me", "Realm")

      local sawPayload = false
      local expectedPayload = "[SYNC] message_payload sender=Kürshad-Blackmoore"
        .. " senderBytes=4B-C3-BC-72-73-68-61-64-2D-42-6C-61-63-6B-6D-6F-6F-72-65"
        .. " bucket=KEY raw=KEY:2649:17:123:hello"
      for _, line in ipairs(lines) do
        if line == expectedPayload then
          sawPayload = true
        end
      end
      Assert.True(sawPayload, "deep trace must expose the raw incoming bucket payload")
    end)
  end)

  test("Sync RegisterVerifiedAlias exposes exact sender data through a verified roster name", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str:sub(1, pos - 1)
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.ProcessAddonMessage("ISILIVE", "KEY:239:17", "Kørshad-Blackmoore", "Me", "Realm")

      Assert.Nil(
        addon.Sync.GetPlayerKeyInfo("Kürshad", "Blackmoore"),
        "different unicode names must not match before a verified alias exists"
      )
      Assert.True(
        addon.Sync.RegisterVerifiedAlias("Kørshad-Blackmoore", nil, "Kürshad", "Blackmoore"),
        "verified same-realm alias must be accepted for a known sync sender"
      )

      local aliasedInfo = addon.Sync.GetPlayerKeyInfo("Kürshad", "Blackmoore")
      Assert.NotNil(aliasedInfo, "verified alias must expose sender key data through the roster key")
      Assert.Equal(aliasedInfo.mapID, 239, "aliased mapID must match sender payload")
      Assert.Equal(aliasedInfo.level, 17, "aliased level must match sender payload")
      Assert.True(addon.Sync.IsUserKnown("Kürshad", "Blackmoore"), "verified alias must mark roster name as known")
    end)
  end)

  test("Sync RegisterVerifiedAlias rejects cross-realm and unknown sender aliases", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str:sub(1, pos - 1)
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      Assert.False(
        addon.Sync.RegisterVerifiedAlias("Kørshad-Blackmoore", nil, "Kürshad", "Blackmoore"),
        "alias must reject senders that have not been observed through sync"
      )
      addon.Sync.ProcessAddonMessage("ISILIVE", "KEY:239:17", "Kørshad-Blackmoore", "Me", "Realm")
      Assert.False(
        addon.Sync.RegisterVerifiedAlias("Kørshad-Blackmoore", nil, "Kürshad", "Malfurion"),
        "alias must reject cross-realm mappings"
      )
      Assert.Nil(
        addon.Sync.GetPlayerKeyInfo("Kürshad", "Malfurion"),
        "rejected cross-realm alias must not expose sender data"
      )
    end)
  end)
end

local function RegisterSyncLazyPayloadTests(test, ctx)
  test("Sync deep payload formatting waits for consumed trace builders", function()
    local formats = 0
    local originalFormat = string.format
    local proxy = setmetatable({
      format = function(pattern, ...)
        if pattern == "%02X" then
          formats = formats + 1
        end
        return originalFormat(pattern, ...)
      end,
    }, { __index = string })
    ctx.with_globals({
      string = proxy,
      GetTime = function()
        return 100
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local sync = ctx.load_modules({ "isiLive_sync.lua" }).Sync
      local function Burst()
        for _ = 1, 10000 do
          sync.ProcessAddonMessage("ISILIVE", "KEY:2662:12:100:audit", "Peer-Realm", "Me", "Realm", "PARTY")
        end
      end
      Burst()
      ctx.assert.Equal(formats, 0, "disabled logging must not prepare sender bytes")
      sync.SetTraceLogger(function() end)
      Burst()
      ctx.assert.Equal(formats, 0, "normal trace must not prepare deep payload bytes")
      local deferred
      sync.SetDeepTraceLogger(function(builder)
        deferred = deferred or builder
      end)
      Burst()
      ctx.assert.Equal(formats, 0, "discarded deep builders must not prepare sender bytes")
      ctx.assert.Equal(type(deferred), "function", "deep logging must retain the lazy builder contract")
      local line = deferred()
      ctx.assert.Equal(formats, 10, "consuming one payload builder must format exactly its sender bytes")
      ctx.assert.True(
        line:find("senderBytes=50-65-65-72-2D-52-65-61-6C-6D", 1, true) ~= nil,
        "consumed builder must preserve the exact sender byte dump"
      )
      ctx.assert.Equal(sync.GetPlayerKeyInfo("Peer", "Realm").level, 12, "lazy logging must not change sync state")
      sync.SetTraceLogger(nil)
      sync.SetDeepTraceLogger(nil)
      local legacyPayload
      sync.SetLogger(function(message)
        if message:find("message_payload", 1, true) then
          legacyPayload = message
        end
      end)
      sync.ProcessAddonMessage("ISILIVE", "KEY:2662:12:100:audit", "Peer-Realm", "Me", "Realm", "PARTY")
      ctx.assert.Equal(formats, 20, "direct legacy logger must consume one additional payload dump")
      ctx.assert.True(
        legacyPayload:find("senderBytes=50-65-65-72-2D-52-65-61-6C-6D", 1, true) ~= nil,
        "direct logger must retain its original payload text"
      )
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterSyncRuntimeLogBurstTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterSyncLazyPayloadTests(test, ctx)
end
