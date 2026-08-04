---@diagnostic disable: undefined-global

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Sync SendKick encodes no-interrupt state and deduplicates payloads", function()
    local sentMessages = {}
    local now = 100

    WithGlobals({
      GetTime = function()
        return now
      end,
      IsInGroup = function(category)
        -- Home party only: category 2 (instance group) must answer false, or
        -- the resolver correctly prefers INSTANCE_CHAT over PARTY.
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

      addon.Sync.SendKick({
        hasKick = false,
        onCooldown = false,
        cooldownRemain = 0,
      })
      Assert.Equal(#sentMessages, 1, "no-interrupt kick state must publish once")
      Assert.Equal(sentMessages[1].message, "KICK:-1:0", "no-interrupt state must serialize distinctly from ready")

      now = 100.5
      addon.Sync.SendKick({
        hasKick = false,
        onCooldown = false,
        cooldownRemain = 0,
      })
      Assert.Equal(#sentMessages, 1, "duplicate no-interrupt kick payload within cooldown must be suppressed")

      now = 101.5
      addon.Sync.SendKick({
        hasKick = true,
        onCooldown = true,
        cooldownRemain = 2.1,
      })
      Assert.Equal(#sentMessages, 2, "changed kick state after cooldown window must publish again")
      Assert.Equal(sentMessages[2].message, "KICK:1:3", "cooldown kick state must ceil remaining seconds")
      Assert.Equal(sentMessages[2].prefix, "ISILIVE", "kick payload must use isiLive prefix")
      Assert.Equal(sentMessages[2].channel, "PARTY", "kick payload must use grouped sync channel")

      now = 102.5
      addon.Sync.SendKick({
        onCooldown = false,
        cooldownRemain = 0,
      })
      Assert.Equal(#sentMessages, 2, "kick send without explicit hasKick must be rejected")
    end)
  end)

  test("Sync SendKick retries identical payload after a rejected dispatch", function()
    local sentMessages = {}
    local now = 100
    local allowSend = false

    WithGlobals({
      GetTime = function()
        return now
      end,
      IsInGroup = function(category)
        -- Home party only: category 2 (instance group) must answer false, or
        -- the resolver correctly prefers INSTANCE_CHAT over PARTY.
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

      local firstSent = addon.Sync.SendKick({
        hasKick = true,
        onCooldown = false,
        cooldownRemain = 0,
      })
      Assert.False(firstSent, "rejected kick dispatch must report false")
      Assert.Equal(#sentMessages, 0, "rejected kick dispatch must not publish")

      allowSend = true
      now = 100.1
      local retrySent = addon.Sync.SendKick({
        hasKick = true,
        onCooldown = false,
        cooldownRemain = 0,
      })
      Assert.True(retrySent, "identical kick payload must retry immediately after dispatch rejection")
      Assert.Equal(#sentMessages, 1, "retry after rejected dispatch must publish once")
      Assert.Equal(sentMessages[1].message, "KICK:0:0", "retry must carry the original ready payload")
    end)
  end)

  test("Sync SendKick appends extras suffix when multi-kick extras are on cooldown", function()
    local sentMessages = {}
    local now = 100

    WithGlobals({
      GetTime = function()
        return now
      end,
      IsInGroup = function(category)
        -- Home party only: category 2 (instance group) must answer false, or
        -- the resolver correctly prefers INSTANCE_CHAT over PARTY.
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

      -- Prot Pala: primary Rebuke ready, Avenger's Shield extra on cooldown.
      addon.Sync.SendKick({
        hasKick = true,
        onCooldown = false,
        cooldownRemain = 0,
        extras = {
          [31935] = { cooldownRemain = 22 },
        },
      })
      Assert.Equal(#sentMessages, 1, "kick with extras must publish")
      Assert.Equal(
        sentMessages[1].message,
        "KICK:0:0:E:31935,22",
        "extras suffix must use ':E:' prefix and 'spellID,remain' encoding"
      )

      -- Two extras must be sorted (table.sort) and ';'-separated.
      now = 200
      addon.Sync.SendKick({
        hasKick = true,
        onCooldown = false,
        cooldownRemain = 0,
        extras = {
          [31935] = { cooldownRemain = 8 },
          [19647] = { cooldownRemain = 12 },
        },
      })
      Assert.Equal(
        sentMessages[2].message,
        "KICK:0:0:E:19647,12;31935,8",
        "multiple extras must be sorted and ';'-separated"
      )

      -- Empty extras map must NOT add the ':E:' suffix.
      now = 300
      addon.Sync.SendKick({
        hasKick = true,
        onCooldown = false,
        cooldownRemain = 0,
        extras = {},
        force = true,
      })
      Assert.Equal(sentMessages[3].message, "KICK:0:0", "empty extras map must NOT append the ':E:' suffix")
    end)
  end)

  test("Sync SendKick appends primary spell suffix when spellID is explicit", function()
    local sentMessages = {}
    local now = 100

    WithGlobals({
      GetTime = function()
        return now
      end,
      IsInGroup = function(category)
        -- Home party only: category 2 (instance group) must answer false, or
        -- the resolver correctly prefers INSTANCE_CHAT over PARTY.
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

      addon.Sync.SendKick({
        hasKick = true,
        onCooldown = false,
        cooldownRemain = 0,
        spellID = 119914,
      })

      Assert.Equal(#sentMessages, 1, "kick with explicit spellID must publish")
      Assert.Equal(sentMessages[1].message, "KICK:0:0:S:119914", "spell suffix must use ':S:<spellID>'")

      now = 101
      addon.Sync.SendKick({
        hasKick = true,
        onCooldown = false,
        cooldownRemain = 0,
        spellID = 119914,
        extras = {
          [31935] = { cooldownRemain = 22 },
        },
      })

      Assert.Equal(#sentMessages, 2, "kick with explicit spellID and extras must publish")
      Assert.Equal(
        sentMessages[2].message,
        "KICK:0:0:E:31935,22:S:119914",
        "extras suffix must stay before spell suffix so older peers still parse parts[4]/parts[5]"
      )
    end)
  end)

  test("Sync ProcessAddonMessage parses KICK extras suffix and stores it on the peer", function()
    WithGlobals({
      GetTime = function()
        return 100
      end,
      strsplit = function(sep, str, max)
        local parts = {}
        local pattern = "([^" .. sep .. "]*)"
        local count = 0
        for part in str:gmatch(pattern) do
          count = count + 1
          table.insert(parts, part)
          if max and count >= max then
            break
          end
        end
        return unpack(parts)
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local result =
        addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:0:0:E:31935,22;19647,8", "Peer-Realm", "Me", "Realm")
      Assert.True(result.kickUpdated, "KICK with extras must update peer kick state")

      local stored = addon.Sync.GetPlayerKickInfo("Peer", "Realm")
      Assert.NotNil(stored, "peer kick info must be stored")
      Assert.NotNil(stored.extras, "extras map must be stored on the peer")
      Assert.NotNil(stored.extras[31935], "Avenger's Shield (31935) must be in extras")
      Assert.Equal(stored.extras[31935].cooldownRemain, 22, "extras remain must round-trip")
      Assert.NotNil(stored.extras[19647], "Spell Lock (19647) must be in extras")
      Assert.Equal(stored.extras[19647].cooldownRemain, 8, "extras remain must round-trip")

      local spellResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:0:0:S:119914:E:31935,22", "Peer-Realm", "Me", "Realm")
      Assert.True(spellResult.kickUpdated, "KICK with primary spell suffix must update peer kick state")
      stored = addon.Sync.GetPlayerKickInfo("Peer", "Realm")
      Assert.Equal(stored.spellID, 119914, "primary spell suffix must be stored on peer kick info")
      Assert.NotNil(stored.extras[31935], "extras after spell suffix must still be stored")

      local compatOrderResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:0:0:E:31935,21:S:119914", "Peer-Realm", "Me", "Realm")
      Assert.True(compatOrderResult.kickUpdated, "KICK with extras before spell suffix must update peer kick state")
      stored = addon.Sync.GetPlayerKickInfo("Peer", "Realm")
      Assert.Equal(stored.spellID, 119914, "primary spell suffix must be stored when it follows extras")
      Assert.Equal(stored.extras[31935].cooldownRemain, 21, "extras before spell suffix must still be stored")

      -- Peer with NO extras suffix must clear stored extras (backwards compat).
      addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:0:0", "Peer-Realm", "Me", "Realm")
      stored = addon.Sync.GetPlayerKickInfo("Peer", "Realm")
      Assert.Equal(stored.extras, nil, "absent extras suffix must clear previously-stored extras")
      Assert.Nil(stored.spellID, "absent spell suffix must clear previously-stored primary spellID")
    end)
  end)

  test("Sync ProcessAddonMessage caps extras list at 8 entries (defense-in-depth)", function()
    WithGlobals({
      GetTime = function()
        return 100
      end,
      strsplit = function(sep, str, max)
        local parts = {}
        local pattern = "([^" .. sep .. "]*)"
        local count = 0
        for part in str:gmatch(pattern) do
          count = count + 1
          table.insert(parts, part)
          if max and count >= max then
            break
          end
        end
        return unpack(parts)
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      -- Build a payload with 12 extras; only the first 8 should be accepted.
      local pieces = {}
      for i = 1, 12 do
        table.insert(pieces, string.format("%d,%d", 100000 + i, 5))
      end
      local payload = "KICK:0:0:E:" .. table.concat(pieces, ";")
      local result = addon.Sync.ProcessAddonMessage("ISILIVE", payload, "Peer-Realm", "Me", "Realm")
      Assert.True(result.kickUpdated, "oversized extras payload still updates the basic kick state")

      local stored = addon.Sync.GetPlayerKickInfo("Peer", "Realm")
      local count = 0
      for _ in pairs(stored.extras or {}) do
        count = count + 1
      end
      Assert.Equal(count, 8, "extras receive must cap at 8 entries")
    end)
  end)

  test(
    "Sync multi-kick roundtrip: SendKick payload feeds back through ProcessAddonMessage to the peer entry",
    function()
      local sentMessages = {}
      WithGlobals({
        GetTime = function()
          return 100
        end,
        IsInGroup = function(category)
          -- Home party only; see the category note on the other group stubs.
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
        strsplit = function(sep, str, max)
          local parts = {}
          local pattern = "([^" .. sep .. "]*)"
          local count = 0
          for part in str:gmatch(pattern) do
            count = count + 1
            table.insert(parts, part)
            if max and count >= max then
              break
            end
          end
          return unpack(parts)
        end,
        GetRealmName = function()
          return "Realm"
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_sync.lua" })

        -- Sender side: produce a KICK payload with two extras.
        addon.Sync.SendKick({
          hasKick = true,
          onCooldown = false,
          cooldownRemain = 0,
          extras = {
            [31935] = { cooldownRemain = 22 }, -- Avenger's Shield
            [19647] = { cooldownRemain = 8 }, -- Spell Lock
          },
        })
        Assert.Equal(#sentMessages, 1, "multi-extras kick must publish")

        -- Roundtrip: feed the produced payload back through ProcessAddonMessage
        -- as if a peer received it. Stored extras must contain BOTH entries
        -- with the same remain values that went in.
        local payload = sentMessages[1].message
        local result = addon.Sync.ProcessAddonMessage("ISILIVE", payload, "Peer-Realm", "Me", "Realm")
        Assert.True(result.kickUpdated, "roundtrip payload must update peer state")

        local stored = addon.Sync.GetPlayerKickInfo("Peer", "Realm")
        Assert.NotNil(stored, "peer entry must exist after roundtrip")
        Assert.NotNil(stored.extras, "peer extras must exist after roundtrip")
        Assert.Equal(
          stored.extras[31935] and stored.extras[31935].cooldownRemain,
          22,
          "Avenger's Shield remain must roundtrip unchanged"
        )
        Assert.Equal(
          stored.extras[19647] and stored.extras[19647].cooldownRemain,
          8,
          "Spell Lock remain must roundtrip unchanged"
        )
      end)
    end
  )

  test("Sync SendKick rejects malformed kick payload inputs without guessing", function()
    local sentMessages = {}
    local now = 200

    WithGlobals({
      GetTime = function()
        return now
      end,
      IsInGroup = function(category)
        -- Home party only: category 2 (instance group) must answer false, or
        -- the resolver correctly prefers INSTANCE_CHAT over PARTY.
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

      addon.Sync.SendKick({
        hasKick = true,
        onCooldown = true,
      })
      Assert.Equal(#sentMessages, 0, "kick send without explicit remain must be rejected")

      addon.Sync.SendKick({
        hasKick = true,
        cooldownRemain = 5,
      })
      Assert.Equal(#sentMessages, 0, "kick send without explicit cooldown state must be rejected")
    end)
  end)

  test("Sync ProcessAddonMessage parses TARGET payload and stores it", function()
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

      local result = addon.Sync.ProcessAddonMessage("ISILIVE", "TARGET:2441:14", "Peer-Realm", "Me", "Realm")
      Assert.NotNil(result, "TARGET message must return result")
      Assert.True(result.targetUpdated, "first TARGET must report update")

      local targetInfo = addon.Sync.GetPlayerTargetInfo("Peer", "Realm")
      Assert.NotNil(targetInfo, "TARGET info must be stored")
      Assert.Equal(targetInfo.mapID, 2441, "stored target mapID must match payload")
      Assert.Equal(targetInfo.level, 14, "stored target level must match payload")

      local dupResult = addon.Sync.ProcessAddonMessage("ISILIVE", "TARGET:2441:14", "Peer-Realm", "Me", "Realm")
      Assert.False(dupResult.targetUpdated, "duplicate TARGET must not report update")

      local levelTextResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "TARGET:2441:0:100:remote:LT:|Kk584|k", "Peer-Realm", "Me", "Realm")
      Assert.True(levelTextResult.targetUpdated, "TARGET with verified levelText must update peer target info")
      targetInfo = addon.Sync.GetPlayerTargetInfo("Peer", "Realm")
      Assert.Equal(targetInfo.mapID, 2441, "levelText TARGET must keep mapID")
      Assert.Nil(targetInfo.level, "levelText TARGET must not synthesize a numeric level")
      Assert.Equal(targetInfo.levelText, "|Kk584|k", "verified Blizzard keystone markup must be stored")

      local invalidLevelTextResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "TARGET:2441:0:101:remote:LT:+14", "Peer-Realm", "Me", "Realm")
      Assert.True(invalidLevelTextResult.targetUpdated, "dropping invalid levelText must update stored target detail")
      targetInfo = addon.Sync.GetPlayerTargetInfo("Peer", "Realm")
      Assert.Nil(targetInfo.levelText, "free-form target levelText must not be stored")
    end)
  end)

  test("Sync ProcessAddonMessage parses KICK payloads with no-interrupt state", function()
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

      local unavailableResult = addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:-1:0", "Peer-Realm", "Me", "Realm")
      Assert.NotNil(unavailableResult, "KICK message must return result")
      Assert.True(unavailableResult.kickUpdated, "first KICK no-interrupt payload must report update")

      local kickInfo = addon.Sync.GetPlayerKickInfo("Peer", "Realm")
      Assert.NotNil(kickInfo, "KICK info must be stored")
      Assert.False(kickInfo.hasKick, "no-interrupt payload must preserve hasKick=false")
      Assert.False(kickInfo.onCooldown, "no-interrupt payload must not mark the spell on cooldown")
      Assert.Equal(kickInfo.cooldownRemain, 0, "no-interrupt payload must store zero remaining cooldown")

      local duplicateResult = addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:-1:0", "Peer-Realm", "Me", "Realm")
      Assert.False(duplicateResult.kickUpdated, "duplicate no-interrupt KICK must not report update")
    end)
  end)

  test("Sync ProcessAddonMessage reports kick updates when remaining cooldown changes", function()
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

      local firstResult = addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:1:8", "Peer-Realm", "Me", "Realm")
      Assert.True(firstResult.kickUpdated, "first active KICK payload must report update")

      local secondResult = addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:1:7", "Peer-Realm", "Me", "Realm")
      Assert.True(secondResult.kickUpdated, "changed remaining cooldown must report update")

      local kickInfo = addon.Sync.GetPlayerKickInfo("Peer", "Realm")
      Assert.NotNil(kickInfo, "active KICK info must be stored")
      Assert.True(kickInfo.hasKick, "active KICK payload must preserve hasKick=true")
      Assert.True(kickInfo.onCooldown, "active KICK payload must preserve cooldown state")
      Assert.Equal(kickInfo.cooldownRemain, 7, "updated remaining cooldown must be stored")
    end)
  end)

  test("Sync ProcessAddonMessage rejects malformed KICK payloads without inventing a state", function()
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

      local invalidStateResult = addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:bogus:0", "Peer-Realm", "Me", "Realm")
      Assert.False(invalidStateResult.kickUpdated, "invalid KICK state must be rejected without inventing a payload")
      Assert.Nil(addon.Sync.GetPlayerKickInfo("Peer", "Realm"), "invalid KICK state must not store any kick info")

      local invalidRemainResult = addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:1:bogus", "Peer-Realm", "Me", "Realm")
      Assert.False(invalidRemainResult.kickUpdated, "invalid KICK remain must be rejected without inventing a payload")
      Assert.Nil(addon.Sync.GetPlayerKickInfo("Peer", "Realm"), "invalid KICK remain must not store any kick info")

      local invalidExtrasMarkerResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:0:0:X:31935,8", "Peer-Realm", "Me", "Realm")
      Assert.False(invalidExtrasMarkerResult.kickUpdated, "invalid KICK suffix marker must reject the full payload")
      Assert.Nil(addon.Sync.GetPlayerKickInfo("Peer", "Realm"), "invalid suffix marker must not store basic kick info")

      local invalidExtrasEntryResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:0:0:E:bad", "Peer-Realm", "Me", "Realm")
      Assert.False(invalidExtrasEntryResult.kickUpdated, "malformed KICK extras must reject the full payload")
      Assert.Nil(addon.Sync.GetPlayerKickInfo("Peer", "Realm"), "malformed extras must not store basic kick info")

      local emptyExtrasResult = addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:0:0:E:", "Peer-Realm", "Me", "Realm")
      Assert.False(emptyExtrasResult.kickUpdated, "empty KICK extras suffix must reject the full payload")
      Assert.Nil(addon.Sync.GetPlayerKickInfo("Peer", "Realm"), "empty extras suffix must not store basic kick info")

      local noKickSpellResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:-1:0:S:119914", "Peer-Realm", "Me", "Realm")
      Assert.False(noKickSpellResult.kickUpdated, "no-interrupt KICK payload must reject a primary spell suffix")
      Assert.Nil(addon.Sync.GetPlayerKickInfo("Peer", "Realm"), "no-interrupt spell suffix must not store kick info")
    end)
  end)

  test("KeySync ApplyKnownKeyToRosterEntry backfills syncDps and syncLocMapID", function()
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
      local addon = LoadAddonModules({ "isiLive_sync.lua", "isiLive_keysync.lua" })
      local controller = addon.KeySync.CreateController({
        sync = addon.Sync,
        getUnitNameAndRealm = function(_unit)
          return "Me", "Realm"
        end,
        getAddonVersionRaw = function()
          return "1.0"
        end,
        isFrameVisible = function()
          return true
        end,
      })

      addon.Sync.SetPlayerDpsInfo("Peer", "Realm", 250000)
      addon.Sync.SetPlayerLocInfo("Peer", "Realm", 2649)

      local info = {
        name = "Peer",
        realm = "Realm",
      }

      local changed = controller.ApplyKnownKeyToRosterEntry(info)
      Assert.True(changed, "DPS/LOC backfill should mark entry as changed")
      Assert.Equal(info.syncDps, 250000, "syncDps should be backfilled from sync data")
      Assert.Equal(info.syncLocMapID, 2649, "syncLocMapID should be backfilled from sync data")

      local pendingInfo = {
        name = "Peer",
        realm = "Realm",
        _refreshQueued = true,
      }

      local pendingChanged = controller.ApplyKnownKeyToRosterEntry(pendingInfo)
      Assert.True(pendingChanged, "pending forced refresh should still backfill missing DPS and LOC fallback data")
      Assert.Equal(pendingInfo.syncDps, 250000, "pending forced refresh must backfill missing syncDps")
      Assert.Equal(pendingInfo.syncLocMapID, 2649, "pending forced refresh should still backfill syncLocMapID")

      local unchanged = controller.ApplyKnownKeyToRosterEntry(info)
      Assert.False(unchanged, "repeat apply with same data should not mark as changed")
    end)
  end)

  test("Sync ClearKnownUsers also clears DPS, LOC, and TARGET caches", function()
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

      addon.Sync.SetPlayerDpsInfo("Peer", "Realm", 100000)
      addon.Sync.SetPlayerLocInfo("Peer", "Realm", 2649)
      addon.Sync.SetPlayerTargetInfo("Peer", "Realm", 2441, 14)
      Assert.NotNil(addon.Sync.GetPlayerDpsInfo("Peer", "Realm"), "DPS info should exist before clear")
      Assert.NotNil(addon.Sync.GetPlayerLocInfo("Peer", "Realm"), "LOC info should exist before clear")
      Assert.NotNil(addon.Sync.GetPlayerTargetInfo("Peer", "Realm"), "TARGET info should exist before clear")

      addon.Sync.ClearKnownUsers()
      Assert.Nil(addon.Sync.GetPlayerDpsInfo("Peer", "Realm"), "DPS info should be cleared")
      Assert.Nil(addon.Sync.GetPlayerLocInfo("Peer", "Realm"), "LOC info should be cleared")
      Assert.Nil(addon.Sync.GetPlayerTargetInfo("Peer", "Realm"), "TARGET info should be cleared")
    end)
  end)
end
