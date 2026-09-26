---@diagnostic disable: undefined-global

local function RegisterProcessMessageSendTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Sync GetAddonSyncChannel returns nil in raid", function()
    WithGlobals({
      LE_PARTY_CATEGORY_INSTANCE = 1,
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
      end,
      IsInRaid = function()
        return true
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      Assert.Nil(addon.Sync.GetAddonSyncChannel(), "raid hard-off must suppress the addon sync channel")
    end)
  end)
  test("Sync GetAddonSyncChannel returns INSTANCE_CHAT for an instance group without home party", function()
    WithGlobals({
      LE_PARTY_CATEGORY_INSTANCE = 2,
      LE_PARTY_CATEGORY_HOME = 1,
      IsInGroup = function(category)
        return category == 2
      end,
      IsInRaid = function()
        return false
      end,
      UnitInParty = function()
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      Assert.Equal(addon.Sync.GetAddonSyncChannel(), "INSTANCE_CHAT", "instance group must use INSTANCE_CHAT")
    end)
  end)
  test("Sync GetAddonSyncChannel fails closed without verified party or instance group", function()
    WithGlobals({
      LE_PARTY_CATEGORY_INSTANCE = 2,
      LE_PARTY_CATEGORY_HOME = 1,
      IsInGroup = function(category)
        return category == nil
      end,
      IsInRaid = function()
        return false
      end,
      UnitInParty = function()
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      Assert.Nil(addon.Sync.GetAddonSyncChannel(), "unverified group must not synthesize PARTY")
    end)
  end)
  test("Sync SendHello respects cooldown and force bypass", function()
    local sentMessages = {}
    local now = 100

    WithGlobals({
      GetTime = function()
        return now
      end,
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendHello({
        isVisible = true,
        version = "1.0",
        protocolVersion = 2,
        source = "local",
      })
      Assert.Equal(#sentMessages, 1, "first hello must publish once")
      Assert.Equal(
        sentMessages[1].message,
        "HELLO:1.0:2:100:local",
        "hello payload must encode version, protocol, timestamp, and source"
      )

      now = 101
      addon.Sync.SendHello({
        isVisible = true,
        version = "1.0",
        protocolVersion = 2,
        source = "local",
      })
      Assert.Equal(#sentMessages, 1, "duplicate hello within cooldown must be suppressed")

      now = 109
      addon.Sync.SendHello({
        isVisible = true,
        version = "1.0",
        protocolVersion = 2,
        source = "local",
      })
      Assert.Equal(#sentMessages, 2, "hello must resend after cooldown expires")
      Assert.Equal(sentMessages[2].message, "HELLO:1.0:2:109:local", "resend must refresh hello timestamp")

      now = 110
      addon.Sync.SendHello({
        force = true,
        isVisible = true,
        version = "1.0",
        protocolVersion = 2,
        source = "local",
      })
      Assert.Equal(#sentMessages, 3, "forced hello must bypass the cooldown")
      Assert.Equal(sentMessages[3].message, "HELLO:1.0:2:110:local", "forced hello must still encode current metadata")
    end)
  end)

  test("Sync SendShareKeysRequest publishes SHAREKEYS to the addon sync channel", function()
    local sentMessages = {}

    WithGlobals({
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local result = addon.Sync.SendShareKeysRequest()

      Assert.True(result, "share-keys request should report success when the addon sync message is sent")
      Assert.Equal(#sentMessages, 1, "share-keys request should publish one addon message")
      Assert.Equal(sentMessages[1].message, "SHAREKEYS", "share-keys request must use SHAREKEYS payload")
    end)
  end)

  test("Sync SendShareKeysRequest returns false without an addon sync channel", function()
    local sentMessages = {}

    WithGlobals({
      IsInGroup = function(_category)
        return false
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local result = addon.Sync.SendShareKeysRequest()

      Assert.False(result, "share-keys request must report failure when no addon sync channel exists")
      Assert.Equal(#sentMessages, 0, "share-keys request must not publish without an addon sync channel")
    end)
  end)

  test("Sync SendShareKeysRequest does not publish in raid", function()
    local sentMessages = {}

    WithGlobals({
      LE_PARTY_CATEGORY_INSTANCE = 1,
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
      end,
      IsInRaid = function()
        return true
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local result = addon.Sync.SendShareKeysRequest()

      Assert.False(result, "share-keys request must report failure in raid")
      Assert.Equal(#sentMessages, 0, "share-keys request must not publish in raid")
    end)
  end)

  test("Sync SendShareKeysRequest returns false when addon message dispatch fails", function()
    local sentMessages = {}

    WithGlobals({
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
          return false
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local result = addon.Sync.SendShareKeysRequest()

      Assert.False(result, "share-keys request must report failure when the addon message dispatch fails")
      Assert.Equal(#sentMessages, 1, "share-keys request should still attempt one addon message dispatch")
      Assert.Equal(sentMessages[1].message, "SHAREKEYS", "failed dispatch must still carry the SHAREKEYS payload")
    end)
  end)

  test("Sync SendPowerInfusionAnnounce sends verified PI payload", function()
    local sentMessages = {}

    WithGlobals({
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel, priority)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
            priority = priority,
          })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendPowerInfusionAnnounce({
        caster = "Priest-Realm",
        recipient = "Target-Realm",
        spellID = 10060,
      })
      addon.Sync.SendPowerInfusionAnnounce({
        caster = "Priest-Realm",
        recipient = "",
        spellID = 10060,
      })
      addon.Sync.SendPowerInfusionAnnounce({
        caster = "Priest-Realm",
        recipient = "Target-Realm",
        spellID = 123,
      })

      Assert.Equal(#sentMessages, 1, "only the verified PI payload should be sent")
      Assert.Equal(sentMessages[1].prefix, "ISILIVE", "PI announce must use the isiLive prefix")
      Assert.Equal(
        sentMessages[1].message,
        "PI:Priest-Realm:Target-Realm:10060",
        "PI announce must carry caster and recipient"
      )
      Assert.Equal(sentMessages[1].channel, "PARTY", "PI announce must use the addon sync channel")
    end)
  end)

  test("Sync SendShareKeysCooldown publishes SKCD with ceiled and clamped remain", function()
    local sentMessages = {}

    WithGlobals({
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
      end,
      IsInRaid = function()
        return false
      end,
      GetTime = function()
        return 100
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local result = addon.Sync.SendShareKeysCooldown({ remain = 12.4 })
      Assert.True(result, "share-keys cooldown send should report success")
      Assert.Equal(#sentMessages, 1, "share-keys cooldown should publish one addon message")
      Assert.Equal(sentMessages[1].prefix, "ISILIVE", "share-keys cooldown must use the ISILIVE prefix")
      Assert.Equal(sentMessages[1].message, "SKCD:13", "fractional remain must be ceiled to whole seconds")

      local blocked = addon.Sync.SendShareKeysCooldown({ remain = 20 })
      Assert.False(blocked, "second send within the 1s rate limit must be suppressed")
      Assert.Equal(#sentMessages, 1, "rate-limited send must not publish a second message")

      local clamped = addon.Sync.SendShareKeysCooldown({ remain = 999, force = true })
      Assert.True(clamped, "forced send must bypass the rate limit")
      Assert.Equal(sentMessages[2].message, "SKCD:30", "remain must be clamped to the 30s debounce window")
    end)
  end)

  test("Sync SendShareKeysCooldown returns false for invalid remain or missing channel", function()
    local sentMessages = {}

    WithGlobals({
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
      end,
      IsInRaid = function()
        return false
      end,
      GetTime = function()
        return 100
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      Assert.False(addon.Sync.SendShareKeysCooldown({ remain = 0 }), "remain=0 must not publish")
      Assert.False(addon.Sync.SendShareKeysCooldown({ remain = -5 }), "negative remain must not publish")
      Assert.False(addon.Sync.SendShareKeysCooldown({}), "missing remain must not publish")
      Assert.Equal(#sentMessages, 0, "invalid remain must never reach the wire")
    end)

    WithGlobals({
      IsInGroup = function(_category)
        return false
      end,
      IsInRaid = function()
        return false
      end,
      GetTime = function()
        return 100
      end,
      C_ChatInfo = {
        SendAddonMessage = function(_prefix, _message, _channel)
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      Assert.False(addon.Sync.SendShareKeysCooldown({ remain = 10 }), "no group channel must suppress the send")
    end)
  end)

  test("Sync ProcessAddonMessage mirrors SKCD payloads with clamping", function()
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

      local result = addon.Sync.ProcessAddonMessage("ISILIVE", "SKCD:25", "OtherPlayer-OtherRealm", "MyPlayer", "Realm")
      Assert.NotNil(result, "SKCD must return a result")
      Assert.Equal(result.shareKeysCooldownRemain, 25, "SKCD remain must be mirrored verbatim")
      Assert.False(result.shouldShareKeys, "SKCD must not trigger a share-keys chat response")

      local clamped =
        addon.Sync.ProcessAddonMessage("ISILIVE", "SKCD:999", "OtherPlayer-OtherRealm", "MyPlayer", "Realm")
      Assert.Equal(clamped.shareKeysCooldownRemain, 30, "oversized SKCD remain must be clamped to 30s")

      local zero = addon.Sync.ProcessAddonMessage("ISILIVE", "SKCD:0", "OtherPlayer-OtherRealm", "MyPlayer", "Realm")
      Assert.Nil(zero.shareKeysCooldownRemain, "SKCD remain 0 must be ignored")

      local garbage =
        addon.Sync.ProcessAddonMessage("ISILIVE", "SKCD:abc", "OtherPlayer-OtherRealm", "MyPlayer", "Realm")
      Assert.Nil(garbage.shareKeysCooldownRemain, "non-numeric SKCD remain must be ignored")
    end)
  end)

  test("Sync ProcessAddonMessage suppresses SKCD self-echo", function()
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

      local result = addon.Sync.ProcessAddonMessage("ISILIVE", "SKCD:25", "MyPlayer-Realm", "MyPlayer", "Realm")
      Assert.NotNil(result, "SKCD self-echo must still return a result")
      Assert.Nil(result.shareKeysCooldownRemain, "SKCD self-echo must not mirror the own cooldown back")
    end)
  end)

  test("Sync SendLibKeystoneRequest publishes one party request", function()
    local sentMessages = {}
    local now = 100

    WithGlobals({
      GetTime = function()
        return now
      end,
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local firstSent = addon.Sync.SendLibKeystoneRequest()
      Assert.True(firstSent, "LibKeystone request should send while grouped")
      Assert.Equal(#sentMessages, 1, "LibKeystone request should publish exactly one addon message")
      Assert.Equal(sentMessages[1].prefix, "LibKS", "LibKeystone request must use the LibKS prefix")
      Assert.Equal(sentMessages[1].message, "R", "LibKeystone request must use the request payload")
      Assert.Equal(sentMessages[1].channel, "PARTY", "LibKeystone request must use the party channel")

      now = 101
      local secondSent = addon.Sync.SendLibKeystoneRequest()
      Assert.False(secondSent, "LibKeystone request should respect the throttle window")
      Assert.Equal(#sentMessages, 1, "throttled LibKeystone request must not send again")

      now = 104
      local forcedSent = addon.Sync.SendLibKeystoneRequest({ force = true })
      Assert.True(forcedSent, "forced LibKeystone request should bypass the throttle window")
      Assert.Equal(#sentMessages, 2, "forced LibKeystone request must send again")
    end)
  end)

  test("Sync SendLibKeystoneRequest reports rejected dispatch and does not start throttle", function()
    local sentMessages = {}
    local now = 100
    local allowSend = false

    WithGlobals({
      GetTime = function()
        return now
      end,
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          if not allowSend then
            return false
          end
          table.insert(sentMessages, { prefix = prefix, message = message, channel = channel })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local rejected = addon.Sync.SendLibKeystoneRequest()
      Assert.False(rejected, "rejected LibKeystone request dispatch must report false")
      Assert.Equal(#sentMessages, 0, "rejected LibKeystone request must not publish")

      allowSend = true
      now = 100.1
      local retry = addon.Sync.SendLibKeystoneRequest()
      Assert.True(retry, "LibKeystone request must retry immediately after dispatch rejection")
      Assert.Equal(#sentMessages, 1, "retry after rejected LibKeystone request must publish once")
      Assert.Equal(sentMessages[1].message, "R", "LibKeystone retry must keep the request payload")
    end)
  end)

  test("Sync SendLibKeystonePartyData publishes current key and rio to party", function()
    local sentMessages = {}

    WithGlobals({
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local sent = addon.Sync.SendLibKeystonePartyData({
        mapID = 505,
        level = 17,
        rio = 3333,
      })
      Assert.True(sent, "LibKeystone party data should send while grouped")
      Assert.Equal(#sentMessages, 1, "LibKeystone party data should publish exactly one addon message")
      Assert.Equal(sentMessages[1].prefix, "LibKS", "LibKeystone party data must use the LibKS prefix")
      Assert.Equal(sentMessages[1].message, "17,505,3333", "LibKeystone party data must encode level, map, and rio")
      Assert.Equal(sentMessages[1].channel, "PARTY", "LibKeystone party data must use the party channel")
    end)
  end)

  test("Sync SendLibKeystonePartyData reports rejected dispatch", function()
    WithGlobals({
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(_prefix, _message, _channel)
          return false
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local sent = addon.Sync.SendLibKeystonePartyData({
        mapID = 505,
        level = 17,
        rio = 3333,
      })

      Assert.False(sent, "rejected LibKeystone party data dispatch must report false")
    end)
  end)

  test("Sync SendLibKeystoneRequest routes to INSTANCE_CHAT inside an instance group", function()
    local sentMessages = {}

    WithGlobals({
      GetTime = function()
        return 200
      end,
      LE_PARTY_CATEGORY_INSTANCE = 2,
      LE_PARTY_CATEGORY_HOME = 1,
      IsInGroup = function(category)
        return category == 2
      end,
      IsInRaid = function()
        return false
      end,
      UnitInParty = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, { prefix = prefix, message = message, channel = channel })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      addon.Sync.SendLibKeystoneRequest({ force = true })
      Assert.Equal(#sentMessages, 1, "request must send")
      Assert.Equal(
        sentMessages[1].channel,
        "INSTANCE_CHAT",
        "LibKeystone request must use INSTANCE_CHAT inside an instance group"
      )
    end)
  end)

  test("Sync SendLibKeystonePartyData routes to INSTANCE_CHAT inside an instance group", function()
    local sentMessages = {}

    WithGlobals({
      LE_PARTY_CATEGORY_INSTANCE = 2,
      LE_PARTY_CATEGORY_HOME = 1,
      IsInGroup = function(category)
        return category == 2
      end,
      IsInRaid = function()
        return false
      end,
      UnitInParty = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, { prefix = prefix, message = message, channel = channel })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      addon.Sync.SendLibKeystonePartyData({ mapID = 505, level = 17, rio = 3333 })
      Assert.Equal(#sentMessages, 1, "party data must send")
      Assert.Equal(
        sentMessages[1].channel,
        "INSTANCE_CHAT",
        "LibKeystone party data must use INSTANCE_CHAT inside an instance group"
      )
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterProcessMessageSendTests(test, Assert, WithGlobals, LoadAddonModules)
end
