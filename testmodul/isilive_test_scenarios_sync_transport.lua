---@diagnostic disable: undefined-global

local function RegisterDpsLocSyncTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Sync ProcessAddonMessage parses DPS payload and stores it", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local result = addon.Sync.ProcessAddonMessage("ISILIVE", "DPS:321100", "Peer-Realm", "Me", "Realm")
      Assert.NotNil(result, "DPS message must return result")
      Assert.True(result.dpsUpdated, "first DPS must report update")

      local dpsInfo = addon.Sync.GetPlayerDpsInfo("Peer", "Realm")
      Assert.NotNil(dpsInfo, "DPS info must be stored")
      Assert.Equal(dpsInfo.dps, 321100, "stored DPS must match payload")

      local dupResult = addon.Sync.ProcessAddonMessage("ISILIVE", "DPS:321100", "Peer-Realm", "Me", "Realm")
      Assert.False(dupResult.dpsUpdated, "duplicate DPS must not report update")
    end)
  end)

  test("Sync ProcessAddonMessage parses LOC payload and stores it", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local result = addon.Sync.ProcessAddonMessage("ISILIVE", "LOC:2649", "Peer-Realm", "Me", "Realm")
      Assert.NotNil(result, "LOC message must return result")
      Assert.True(result.locUpdated, "first LOC must report update")

      local locInfo = addon.Sync.GetPlayerLocInfo("Peer", "Realm")
      Assert.NotNil(locInfo, "LOC info must be stored")
      Assert.Equal(locInfo.mapID, 2649, "stored mapID must match payload")

      local dupResult = addon.Sync.ProcessAddonMessage("ISILIVE", "LOC:2649", "Peer-Realm", "Me", "Realm")
      Assert.False(dupResult.locUpdated, "duplicate LOC must not report update")
    end)
  end)

  test("Sync SendTarget respects visibility and deduplicates payloads", function()
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
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendTarget({
        isVisible = false,
        mapID = 2441,
        level = 14,
      })
      Assert.Equal(#sentMessages, 0, "hidden target send must be suppressed")

      addon.Sync.SendTarget({
        isVisible = false,
        allowHidden = true,
        mapID = 2441,
        level = 14,
      })
      Assert.Equal(#sentMessages, 1, "hidden target send must publish when full hidden sync explicitly allows it")
      Assert.Equal(
        sentMessages[1].message,
        "TARGET:2441:14:100:local",
        "hidden full-sync target payload must still encode exact target map, level, and metadata"
      )

      addon.Sync.SendTarget({
        isVisible = true,
        mapID = 2441,
        level = 14,
      })
      Assert.Equal(
        #sentMessages,
        1,
        "duplicate visible target payload must stay deduplicated after hidden full-sync send"
      )
      Assert.Equal(sentMessages[1].prefix, "ISILIVE", "target payload must use isiLive prefix")
      Assert.Equal(
        sentMessages[1].message,
        "TARGET:2441:14:100:local",
        "target payload must encode exact target map, level, and metadata"
      )
      Assert.Equal(sentMessages[1].channel, "PARTY", "target payload must use party channel while grouped")

      now = 101
      addon.Sync.SendTarget({
        isVisible = true,
        mapID = 2441,
        level = 14,
      })
      Assert.Equal(#sentMessages, 1, "duplicate target payload within cooldown must be suppressed")

      now = 106
      addon.Sync.SendTarget({
        isVisible = true,
        mapID = 2441,
        level = nil,
      })
      Assert.Equal(#sentMessages, 2, "changed target payload should publish again after cooldown window")
      Assert.Equal(
        sentMessages[2].message,
        "TARGET:2441:0:106:local",
        "missing level must serialize as exact map without guess"
      )

      now = 112
      addon.Sync.SendTarget({
        isVisible = true,
        mapID = 2441,
        level = nil,
        levelText = "|Kk584|k",
      })
      Assert.Equal(#sentMessages, 3, "verified Blizzard level markup must publish as changed target detail")
      Assert.Equal(
        sentMessages[3].message,
        "TARGET:2441:0:112:local:LT:|Kk584|k",
        "levelText must serialize only as verified opaque Blizzard keystone markup"
      )

      now = 118
      addon.Sync.SendTarget({
        isVisible = true,
        mapID = 2441,
        level = nil,
        levelText = "+14 freeform",
      })
      Assert.Equal(#sentMessages, 4, "dropping invalid levelText must still publish the changed target detail")
      Assert.Equal(
        sentMessages[4].message,
        "TARGET:2441:0:118:local",
        "free-form levelText must not be serialized into TARGET sync"
      )
    end)
  end)
end

local function RegisterChatThrottleLibRoutingTests(test, Assert, WithGlobals, LoadAddonModules)
  local function SetupRoutingGlobals(ctlMessages, fallbackMessages)
    return {
      GetTime = function()
        return 100
      end,
      IsInGroup = function()
        return true
      end,
      IsInRaid = function()
        return false
      end,
      ChatThrottleLib = ctlMessages and {
        SendAddonMessage = function(_self, priority, prefix, text, chattype)
          table.insert(ctlMessages, { priority = priority, prefix = prefix, text = text, chattype = chattype })
        end,
      } or nil,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          if fallbackMessages then
            table.insert(fallbackMessages, { prefix = prefix, message = message, channel = channel })
          end
          return true
        end,
      },
    }
  end

  test("Sync routes send through ChatThrottleLib with correct priority per message type", function()
    local ctlMessages = {}
    WithGlobals(SetupRoutingGlobals(ctlMessages, nil), function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendKick({ hasKick = true, onCooldown = false, cooldownRemain = 0 })
      addon.Sync.SendStats({ isVisible = true, specID = 72, ilvl = 615, rio = 3210 })
      addon.Sync.SendKey({ isVisible = true, mapID = 2649, level = 14 })
      addon.Sync.SendDps({ isVisible = true, dps = 100000 })
      addon.Sync.SendLoc({ isVisible = true, mapID = 2649 })
      addon.Sync.SendTarget({ isVisible = true, mapID = 2649, level = 14 })
      addon.Sync.SendRefreshRequest({ force = true })
      addon.Sync.SendShareKeysRequest()
      addon.Sync.SendHello({ force = true, version = "0.9.175", protocolVersion = 2, source = "test" })

      local byKind = {}
      for _, m in ipairs(ctlMessages) do
        byKind[m.text:match("^(%a+)") or m.text] = m
      end

      Assert.Equal(byKind["KICK"].priority, "ALERT", "KICK must use ALERT priority")
      Assert.Equal(byKind["REQSYNC"].priority, "ALERT", "REQSYNC must use ALERT priority")
      Assert.Equal(byKind["SHAREKEYS"].priority, "ALERT", "SHAREKEYS must use ALERT priority")
      Assert.Equal(byKind["STATS"].priority, "BULK", "STATS must use BULK priority")
      Assert.Equal(byKind["DPS"].priority, "BULK", "DPS must use BULK priority")
      Assert.Equal(byKind["LOC"].priority, "BULK", "LOC must use BULK priority")
      Assert.Equal(byKind["KEY"].priority, "NORMAL", "KEY must use NORMAL priority")
      Assert.Equal(byKind["TARGET"].priority, "NORMAL", "TARGET must use NORMAL priority")
      Assert.Equal(byKind["HELLO"].priority, "NORMAL", "HELLO must use NORMAL priority")
    end)
  end)

  test("Sync falls back to raw C_ChatInfo.SendAddonMessage when ChatThrottleLib is absent", function()
    local fallbackMessages = {}
    WithGlobals(SetupRoutingGlobals(nil, fallbackMessages), function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendKick({ hasKick = true, onCooldown = false, cooldownRemain = 0 })

      Assert.Equal(#fallbackMessages, 1, "send without ChatThrottleLib must dispatch via C_ChatInfo")
      Assert.Equal(fallbackMessages[1].prefix, "ISILIVE", "fallback dispatch must use isiLive prefix")
      Assert.True(fallbackMessages[1].message:match("^KICK:") ~= nil, "fallback dispatch must carry kick payload")
    end)
  end)

  test("ChatThrottleLib drops queued INSTANCE_CHAT addon messages after instance group leave", function()
    local sentMessages = {}
    local callbackDidSend = nil
    local inInstanceGroup = true

    WithGlobals({
      ChatThrottleLib = false,
      LE_PARTY_CATEGORY_INSTANCE = 2,
      GetTime = function()
        return 100
      end,
      GetFramerate = function()
        return 60
      end,
      IsInGroup = function(category)
        if category == 2 then
          return inInstanceGroup
        end
        return inInstanceGroup
      end,
      UnitInRaid = function()
        return false
      end,
      UnitInParty = function()
        return inInstanceGroup
      end,
      hooksecurefunc = function() end,
      wipe = function(t)
        for key in pairs(t) do
          t[key] = nil
        end
      end,
      unpack = rawget(table, "unpack"),
      CreateFrame = function()
        return {
          SetScript = function() end,
          RegisterEvent = function() end,
          Show = function() end,
          Hide = function() end,
        }
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, { prefix = prefix, message = message, channel = channel })
          return true
        end,
      },
    }, function()
      LoadAddonModules({ "ChatThrottleLib.lua" })

      local ctl = Assert.NotNil(rawget(_G, "ChatThrottleLib"), "ChatThrottleLib must load into globals")
      ctl.bQueueing = true
      ctl:SendAddonMessage(
        "NORMAL",
        "ISILIVE",
        "HELLO:0.9.293",
        "INSTANCE_CHAT",
        nil,
        "leave-test",
        function(_, didSend)
          callbackDidSend = didSend
        end
      )

      inInstanceGroup = false
      ctl.Prio.NORMAL.avail = 1000
      ctl:Despool(ctl.Prio.NORMAL)

      Assert.Equal(#sentMessages, 0, "queued INSTANCE_CHAT send must be dropped after instance group leave")
      Assert.Equal(callbackDidSend, false, "ChatThrottleLib callback must report that the queued send was dropped")
    end)
  end)
end

local function RegisterSyncResetTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Sync ClearKnownUsers resets send cooldowns so next identical payload fires immediately", function()
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
          table.insert(sentMessages, { prefix = prefix, message = message, channel = channel })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendStats({ isVisible = true, specID = 72, ilvl = 615, rio = 3210 })
      Assert.Equal(#sentMessages, 1, "first send must go through")

      now = 102
      addon.Sync.SendStats({ isVisible = true, specID = 72, ilvl = 615, rio = 3210 })
      Assert.Equal(#sentMessages, 1, "identical send within cooldown must be suppressed")

      addon.Sync.ClearKnownUsers()
      addon.Sync.SendStats({ isVisible = true, specID = 72, ilvl = 615, rio = 3210 })
      Assert.Equal(#sentMessages, 2, "send after ClearKnownUsers must bypass cooldown and dedup")
    end)
  end)

  test("Sync ClearKnownUsers resets kick send cooldowns so next identical payload fires immediately", function()
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
          table.insert(sentMessages, { prefix = prefix, message = message, channel = channel })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendKick({ hasKick = true, onCooldown = false, cooldownRemain = 0 })
      Assert.Equal(#sentMessages, 1, "first kick send must go through")

      now = 100.5
      addon.Sync.SendKick({ hasKick = true, onCooldown = false, cooldownRemain = 0 })
      Assert.Equal(#sentMessages, 1, "identical kick send within cooldown must be suppressed")

      addon.Sync.ClearKnownUsers()
      addon.Sync.SendKick({ hasKick = true, onCooldown = false, cooldownRemain = 0 })
      Assert.Equal(#sentMessages, 2, "kick send after ClearKnownUsers must bypass cooldown and dedup")
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterDpsLocSyncTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterChatThrottleLibRoutingTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterSyncResetTests(test, Assert, WithGlobals, LoadAddonModules)
end
