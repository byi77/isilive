---@diagnostic disable: undefined-global, undefined-field, unused-local

-- Scenarios for core/isiLive_context_helpers.lua.
-- Covers the API-fallback branches the composition-root test cannot
-- reach (missing C_AddOns, LibStub unavailable, C_MythicPlus keystone
-- link path, bag scan for item 180653, INSTANCE_CHAT vs PARTY channel
-- resolution, SendChatMessage fallback to C_ChatInfo).

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function Load()
    return LoadAddonModules({ "isiLive_context_helpers.lua" })
  end

  test("context_helpers: GetAddonVersionRaw prefers C_AddOns over the legacy global", function()
    WithGlobals({
      C_AddOns = {
        GetAddOnMetadata = function(_name, field)
          if field == "Version" then
            return "2.3.4"
          end
        end,
      },
      GetAddOnMetadata = function()
        error("legacy path must not fire when C_AddOns exists", 0)
      end,
    }, function()
      local addon = Load()
      Assert.Equal(addon.ContextHelpers.GetAddonVersionRaw("isiLive"), "2.3.4")
    end)
  end)

  test("context_helpers: GetAddonVersionRaw falls back to legacy GetAddOnMetadata", function()
    WithGlobals({
      C_AddOns = false,
      GetAddOnMetadata = function(_name, field)
        if field == "Version" then
          return "legacy-1.0"
        end
      end,
    }, function()
      local addon = Load()
      Assert.Equal(addon.ContextHelpers.GetAddonVersionRaw("isiLive"), "legacy-1.0")
    end)
  end)

  test("context_helpers: GetAddonVersionRaw returns '?' when both APIs are unavailable", function()
    WithGlobals({ C_AddOns = false, GetAddOnMetadata = false }, function()
      local addon = Load()
      Assert.Equal(addon.ContextHelpers.GetAddonVersionRaw("isiLive"), "?")
    end)
  end)

  test("context_helpers: CreateRealmInfoGetter memoizes the LibStub lookup", function()
    local calls = 0
    WithGlobals({
      LibStub = setmetatable({}, {
        __index = function(_, key)
          if key == "GetLibrary" then
            return function(_, _name, _silent)
              calls = calls + 1
              return { name = "LibRealmInfo" }
            end
          end
        end,
      }),
    }, function()
      local addon = Load()
      local getter = addon.ContextHelpers.CreateRealmInfoGetter()
      local first = getter()
      Assert.NotNil(first)
      local second = getter()
      Assert.Equal(second, first, "memoized lib must be the same table instance")
      Assert.Equal(calls, 1, "LibStub lookup must run exactly once")
    end)
  end)

  test("context_helpers: CreateRealmInfoGetter returns false when LibStub is missing", function()
    WithGlobals({ LibStub = false }, function()
      local addon = Load()
      local getter = addon.ContextHelpers.CreateRealmInfoGetter()
      Assert.Equal(getter(), false)
      Assert.Equal(getter(), false, "memoized false must stick across calls")
    end)
  end)

  test("context_helpers: BuildKeystoneChatLink returns nil for invalid mapID/level", function()
    WithGlobals({}, function()
      local addon = Load()
      Assert.Nil(addon.ContextHelpers.BuildKeystoneChatLink(nil, nil))
      Assert.Nil(addon.ContextHelpers.BuildKeystoneChatLink(0, 12))
      Assert.Nil(addon.ContextHelpers.BuildKeystoneChatLink(2649, 0))
    end)
  end)

  test("context_helpers: BuildKeystoneChatLink uses GetOwnedKeystoneLink when available", function()
    WithGlobals({
      C_MythicPlus = {
        GetOwnedKeystoneLink = function()
          return "|cffa335ee|Hkeystone:180653:2649:12|h[Keystone: Ara-Kara +12]|h|r"
        end,
      },
    }, function()
      local addon = Load()
      local link = addon.ContextHelpers.BuildKeystoneChatLink(2649, 12)
      Assert.True(link:find("|Hkeystone:", 1, true) ~= nil)
    end)
  end)

  test("context_helpers: BuildKeystoneChatLink accepts verified keystone item hyperlinks", function()
    local itemLink = "|cffa335ee|Hitem:180653::::::::80:250:::::|h[Keystone: Windrunner's Tower (16)]|h|r"
    WithGlobals({
      C_MythicPlus = false,
      C_Container = {
        GetContainerNumSlots = function(bag)
          if bag == 0 then
            return 2
          end
          return 0
        end,
        GetContainerItemID = function(bag, slot)
          if bag == 0 and slot == 1 then
            return 180653
          end
          return nil
        end,
        GetContainerItemLink = function(bag, slot)
          if bag == 0 and slot == 1 then
            return itemLink
          end
          return nil
        end,
      },
      C_ChallengeMode = {
        GetMapUIInfo = function()
          error("verified item hyperlink must be used before plain fallback", 0)
        end,
      },
    }, function()
      local addon = Load()
      local link = addon.ContextHelpers.BuildKeystoneChatLink(2649, 16)
      Assert.Equal(link, itemLink, "verified Keystone item hyperlink must stay clickable")
      Assert.True(link:find("|Hitem:180653", 1, true) ~= nil)
    end)
  end)

  test("context_helpers: BuildKeystoneChatLink scans bags for keystone item 180653", function()
    WithGlobals({
      C_MythicPlus = false,
      C_Container = {
        GetContainerNumSlots = function(bag)
          if bag == 0 then
            return 3
          end
          return 0
        end,
        GetContainerItemID = function(bag, slot)
          if bag == 0 and slot == 2 then
            return 180653
          end
          return nil
        end,
        GetContainerItemLink = function(bag, slot)
          if bag == 0 and slot == 2 then
            return "|Hkeystone:180653:2649:12|h[Keystone]|h"
          end
          return nil
        end,
      },
    }, function()
      local addon = Load()
      local link = addon.ContextHelpers.BuildKeystoneChatLink(2649, 12)
      Assert.True(link:find("|Hkeystone:", 1, true) ~= nil, "bag scan must find the real keystone link")
    end)
  end)

  test("context_helpers: BuildKeystoneChatLink falls back to plain text with dungeon name", function()
    WithGlobals({
      C_MythicPlus = false,
      C_Container = false,
      C_ChallengeMode = {
        GetMapUIInfo = function(mapID)
          if mapID == 2649 then
            return "Ara-Kara", 1, 1800
          end
        end,
      },
    }, function()
      local addon = Load()
      local link = addon.ContextHelpers.BuildKeystoneChatLink(2649, 12)
      Assert.Equal(link, "[Keystone: Ara-Kara +12]", "fallback label must include localized name + level")
    end)
  end)

  test("context_helpers: BuildKeystoneChatLink falls back to generic label when dungeon name is unknown", function()
    WithGlobals({
      C_MythicPlus = false,
      C_Container = false,
      C_ChallengeMode = false,
    }, function()
      local addon = Load()
      Assert.Equal(addon.ContextHelpers.BuildKeystoneChatLink(2649, 12), "[Keystone +12]")
    end)
  end)

  test("context_helpers: BuildOwnKeystoneAnnounceLine resolves via getOwnedKeystoneSnapshot first", function()
    WithGlobals({
      C_MythicPlus = false,
      C_Container = false,
      C_ChallengeMode = false,
    }, function()
      local addon = Load()
      local line = addon.ContextHelpers.BuildOwnKeystoneAnnounceLine({
        getOwnedKeystoneSnapshot = function()
          return 2649, 14
        end,
        getL = function()
          return { ANNOUNCE_PREFIX = "PartyKeys:" }
        end,
      })
      Assert.True(line:find("isiLive", 1, true) ~= nil)
      Assert.True(line:find("+14", 1, true) ~= nil)
    end)
  end)

  test("context_helpers: BuildOwnKeystoneAnnounceLine falls back to roster when snapshot is missing", function()
    WithGlobals({
      C_MythicPlus = false,
      C_Container = false,
      C_ChallengeMode = false,
    }, function()
      local addon = Load()
      local line = addon.ContextHelpers.BuildOwnKeystoneAnnounceLine({
        getRoster = function()
          return { player = { keyMapID = 2649, keyLevel = 10 } }
        end,
        getL = function()
          return {}
        end,
      })
      Assert.True(line:find("+10", 1, true) ~= nil)
    end)
  end)

  test("context_helpers: BuildOwnKeystoneAnnounceLine returns nil when no source yields a key", function()
    WithGlobals({}, function()
      local addon = Load()
      Assert.Nil(addon.ContextHelpers.BuildOwnKeystoneAnnounceLine({}))
    end)
  end)

  test("context_helpers: BuildOwnKeystoneAnnounceLine strips whitespace from the L prefix", function()
    WithGlobals({
      C_MythicPlus = false,
      C_Container = false,
      C_ChallengeMode = false,
    }, function()
      local addon = Load()
      local line = addon.ContextHelpers.BuildOwnKeystoneAnnounceLine({
        getOwnedKeystoneSnapshot = function()
          return 2649, 12
        end,
        getL = function()
          return { ANNOUNCE_PREFIX = "Party Keys:" }
        end,
      })
      Assert.True(
        line:find("PartyKeys:", 1, true) ~= nil,
        "whitespace inside the prefix must be stripped: " .. tostring(line)
      )
    end)
  end)

  test(
    "context_helpers: ResolveGroupChatChannel returns INSTANCE_CHAT for an instance group without home party",
    function()
      WithGlobals({
        IsInGroup = function(category)
          return category == 2
        end,
        LE_PARTY_CATEGORY_INSTANCE = 2,
        LE_PARTY_CATEGORY_HOME = 1,
        UnitInParty = function()
          return false
        end,
      }, function()
        local addon = Load()
        Assert.Equal(addon.ContextHelpers.ResolveGroupChatChannel(), "INSTANCE_CHAT")
      end)
    end
  )

  test("context_helpers: ResolveGroupChatChannel returns PARTY for a verified home party", function()
    WithGlobals({
      IsInGroup = function(category)
        return category == 1
      end,
      LE_PARTY_CATEGORY_INSTANCE = 2,
      LE_PARTY_CATEGORY_HOME = 1,
      UnitInParty = function()
        return true
      end,
    }, function()
      local addon = Load()
      Assert.Equal(addon.ContextHelpers.ResolveGroupChatChannel(), "PARTY")
    end)
  end)

  test("context_helpers: ResolveGroupChatChannel fails closed when IsInGroup is missing", function()
    WithGlobals({ IsInGroup = false }, function()
      local addon = Load()
      Assert.Nil(addon.ContextHelpers.ResolveGroupChatChannel())
    end)
  end)

  test("context_helpers: SendPartyChatMessage rejects non-string / empty input", function()
    WithGlobals({}, function()
      local addon = Load()
      Assert.Equal(addon.ContextHelpers.SendPartyChatMessage(""), false)
      Assert.Equal(addon.ContextHelpers.SendPartyChatMessage(nil), false)
      Assert.Equal(addon.ContextHelpers.SendPartyChatMessage(42), false)
    end)
  end)

  test("context_helpers: SendPartyChatMessage uses SendChatMessage first", function()
    local sentVia = nil
    WithGlobals({
      IsInGroup = function(category)
        return category == 1
      end,
      LE_PARTY_CATEGORY_INSTANCE = 2,
      LE_PARTY_CATEGORY_HOME = 1,
      UnitInParty = function()
        return true
      end,
      SendChatMessage = function(_msg, channel)
        sentVia = { api = "legacy", channel = channel }
      end,
    }, function()
      local addon = Load()
      Assert.Equal(addon.ContextHelpers.SendPartyChatMessage("hi"), true)
      Assert.Equal(sentVia.api, "legacy")
      Assert.Equal(sentVia.channel, "PARTY")
    end)
  end)

  test("context_helpers: SendPartyChatMessage falls back to C_ChatInfo when SendChatMessage raises", function()
    local usedCompat = false
    WithGlobals({
      IsInGroup = function(category)
        return category == 1
      end,
      LE_PARTY_CATEGORY_INSTANCE = 2,
      LE_PARTY_CATEGORY_HOME = 1,
      UnitInParty = function()
        return true
      end,
      SendChatMessage = function()
        error("legacy busted", 0)
      end,
      C_ChatInfo = {
        SendChatMessage = function()
          usedCompat = true
        end,
      },
    }, function()
      local addon = Load()
      Assert.Equal(addon.ContextHelpers.SendPartyChatMessage("hi"), true, "fallback API must succeed")
      Assert.Equal(usedCompat, true, "C_ChatInfo.SendChatMessage must fire once the legacy pcall failed")
    end)
  end)

  test("context_helpers: SendPartyChatMessage returns false when no chat API is available", function()
    WithGlobals({
      IsInGroup = function(category)
        return category == 1
      end,
      LE_PARTY_CATEGORY_INSTANCE = 2,
      LE_PARTY_CATEGORY_HOME = 1,
      UnitInParty = function()
        return true
      end,
      SendChatMessage = false,
      C_ChatInfo = false,
    }, function()
      local addon = Load()
      Assert.Equal(addon.ContextHelpers.SendPartyChatMessage("hi"), false)
    end)
  end)

  test("context_helpers: SendPartyChatMessage returns false without a verified group channel", function()
    local attempted = false
    WithGlobals({
      IsInGroup = function()
        return false
      end,
      LE_PARTY_CATEGORY_INSTANCE = 2,
      LE_PARTY_CATEGORY_HOME = 1,
      UnitInParty = function()
        return false
      end,
      SendChatMessage = function()
        attempted = true
      end,
    }, function()
      local addon = Load()
      Assert.Equal(addon.ContextHelpers.SendPartyChatMessage("hi"), false)
      Assert.False(attempted, "chat API must not be called without a verified group channel")
    end)
  end)
end
