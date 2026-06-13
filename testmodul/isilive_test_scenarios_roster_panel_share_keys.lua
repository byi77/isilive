---@diagnostic disable: undefined-global
local function RequireRosterPanelHelpers()
  local chunk, loadErr = loadfile("testmodul/isilive_test_scenarios_roster_panel.lua")
  if not chunk then
    error(string.format("cannot load roster panel scenario helper: %s", tostring(loadErr)))
  end

  local helperAddon = {}
  local ok, runErr = pcall(chunk, "isiLive", helperAddon)
  if not ok then
    error(string.format("cannot execute roster panel scenario helper: %s", tostring(runErr)))
  end

  local helpers = helperAddon._RosterPanelTests or {}
  if
    type(helpers.NewRecordedFrame) ~= "function"
    or type(helpers.NewRecordedMainFrame) ~= "function"
    or type(helpers.NewRecordedFontString) ~= "function"
  then
    error("Roster panel test helpers are unavailable")
  end
  return helpers
end

local function RequireFixtures()
  local chunk, loadErr = loadfile("testmodul/isilive_test_fixtures.lua")
  if not chunk then
    error(string.format("cannot load fixture helper: %s", tostring(loadErr)))
  end
  return chunk()
end

-- Upvalue locals — set once from the scenario entry point before any test is called.
local NewRecordedFrame
local NewRecordedMainFrame
local test, Assert, WithGlobals, LoadAddonModules
local RegisterShareKeysRemoteCooldownTests

local function RegisterShareKeysGlobalPathTest()
  test("Roster panel share keys button uses the global SendChatMessage runtime path", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local sentMessages = {}
    local shareKeyRequests = 0
    local currentTime = 300

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      SendChatMessage = function(text, channel)
        table.insert(sentMessages, {
          text = text,
          channel = channel,
        })
      end,
      print = function() end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(roster)
          return {
            { unit = "player", info = roster.player },
          }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Self",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {
            player = {
              name = "Self",
              role = "DAMAGER",
              keyMapID = 2662,
              keyLevel = 10,
            },
          }
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {
          DAMAGER = 1,
          NONE = 2,
        },
        unitPriority = {
          player = 1,
        },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 1,
        sendShareKeysRequest = function()
          shareKeyRequests = shareKeyRequests + 1
          return true
        end,
      })

      controller.RenderRoster({
        player = {
          name = "Self",
          role = "DAMAGER",
          keyMapID = 2662,
          keyLevel = 10,
        },
      })

      local shareKeysButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.pointY == -150 then
          shareKeysButton = frame
          break
        end
      end

      shareKeysButton = Assert.NotNil(shareKeysButton, "share-keys button should exist")
      ---@diagnostic disable: undefined-field
      shareKeysButton.OnClick()
      ---@diagnostic enable: undefined-field

      Assert.Equal(#sentMessages, 1, "share-keys should use the global SendChatMessage path in runtime")
      Assert.Equal(sentMessages[1].channel, "PARTY", "share-keys global chat path should still announce to party chat")
      Assert.Equal(shareKeyRequests, 1, "share-keys global chat path should still broadcast the sync request")
    end)
  end)
end

local function RegisterShareKeysDispatchOrderTest()
  test("Roster panel share keys button dispatches SHAREKEYS before party chat", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local effectOrder = {}
    local currentTime = 350

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      SendChatMessage = function(text, channel)
        table.insert(effectOrder, {
          kind = "chat",
          text = text,
          channel = channel,
        })
      end,
      print = function() end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(roster)
          return {
            { unit = "player", info = roster.player },
          }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Self",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {
            player = {
              name = "Self",
              role = "DAMAGER",
              keyMapID = 2662,
              keyLevel = 10,
            },
          }
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {
          DAMAGER = 1,
          NONE = 2,
        },
        unitPriority = {
          player = 1,
        },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 30,
        sendShareKeysRequest = function()
          table.insert(effectOrder, {
            kind = "sync",
          })
          return true
        end,
      })

      controller.RenderRoster({
        player = {
          name = "Self",
          role = "DAMAGER",
          keyMapID = 2662,
          keyLevel = 10,
        },
      })

      local shareKeysButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.pointY == -150 then
          shareKeysButton = frame
          break
        end
      end

      shareKeysButton = Assert.NotNil(shareKeysButton, "share-keys button should exist")
      ---@diagnostic disable: undefined-field
      shareKeysButton.OnClick()
      ---@diagnostic enable: undefined-field

      Assert.Equal(#effectOrder, 2, "share-keys click must perform one sync request and one party chat")
      Assert.Equal(effectOrder[1].kind, "sync", "SHAREKEYS must be dispatched before the visible party chat")
      Assert.Equal(effectOrder[2].kind, "chat", "own key party chat must follow the SHAREKEYS dispatch")
      Assert.Equal(effectOrder[2].channel, "PARTY", "own key line must still announce to party chat")
    end)
  end)
end

local function RegisterShareKeysEndToEndButtonRuntimeTest()
  test("Roster panel share keys button drives full sender receiver chat chain", function()
    local Fixtures = RequireFixtures()
    local createdFrames = {}
    local createdFontStrings = {}
    local chatMessages = {}
    local addonMessages = {}
    local runtimeLogs = {}
    local cooldownTriggers = 0
    local currentTime = 900
    local counters = { uiUpdates = 0, refreshResponses = 0 }
    local senderRoster = {
      player = {
        name = "Sender",
        realm = "RealmA",
        role = "DAMAGER",
        keyMapID = 2649,
        keyLevel = 12,
      },
    }
    local receiverRoster = {
      sender = {
        name = "Sender",
        realm = "RealmA",
        hasIsiLive = true,
      },
      player = {
        name = "Receiver",
        realm = "RealmB",
        role = "HEALER",
        keyMapID = 2660,
        keyLevel = 15,
      },
    }

    local function Strsplit(sep, str, max)
      local pos = str:find(sep, 1, true)
      if not pos then
        return str
      end
      if max and max >= 2 then
        return str:sub(1, pos - 1), str:sub(pos + 1)
      end
      return str:sub(1, pos - 1)
    end

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      GetRealmName = function()
        return "RealmA"
      end,
      GetTime = function()
        return currentTime
      end,
      IsInRaid = function()
        return false
      end,
      IsInGroup = function(category)
        if category == 2 then
          return false
        end
        return true
      end,
      LE_PARTY_CATEGORY_INSTANCE = 2,
      IsiLiveDB = { syncEnabled = true },
      C_MythicPlus = false,
      C_Container = false,
      C_ChallengeMode = {
        GetMapUIInfo = function(mapID)
          if mapID == 2649 then
            return "Sender Dungeon"
          end
          if mapID == 2660 then
            return "Receiver Dungeon"
          end
          return nil
        end,
      },
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(addonMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
          return true
        end,
      },
      SendChatMessage = function(message, channel)
        table.insert(chatMessages, {
          message = message,
          channel = channel,
        })
      end,
      strsplit = Strsplit,
      print = function() end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_context_helpers.lua",
        "isiLive_sync.lua",
        "isiLive_event_handlers.lua",
        "isiLive_roster_panel.lua",
      })

      local helloResult = addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "HELLO:1.0:2:899:hello",
        "Sender-RealmA",
        "Receiver",
        "RealmB",
        "PARTY"
      )
      Assert.NotNil(helloResult, "pre-sync HELLO must be accepted before the share-keys click")
      Assert.True(addon.Sync.IsUserKnown("Sender", "RealmA"), "sender must already be known from normal sync")

      local senderController = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return { ANNOUNCE_PREFIX = "PartyKeys:" }
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(roster)
          return {
            { unit = "player", info = roster.player },
          }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Sender",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "SD +12",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function(mapID)
          return mapID == 2649 and "SD" or "RD"
        end,
        getOwnedKeystoneSnapshot = function()
          return 2649, 12
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return senderRoster
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {
          HEALER = 1,
          DAMAGER = 2,
          NONE = 3,
        },
        unitPriority = {
          player = 1,
        },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 30,
        sendShareKeysRequest = function()
          return addon.Sync.SendShareKeysRequest()
        end,
      })

      senderController.RenderRoster(senderRoster)

      local shareKeysButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.pointY == -150 then
          shareKeysButton = frame
          break
        end
      end
      shareKeysButton = Assert.NotNil(shareKeysButton, "share-keys button should exist")
      ---@cast shareKeysButton any
      Assert.True(shareKeysButton.enabled, "sender share-keys button must start enabled")

      ---@diagnostic disable: undefined-field
      shareKeysButton.OnClick()
      ---@diagnostic enable: undefined-field

      Assert.Equal(#chatMessages, 1, "sender click must first publish the sender's own key to chat")
      Assert.Equal(
        chatMessages[1].message,
        "[isiLive] PartyKeys: [Keystone: Sender Dungeon +12]",
        "sender chat output must be built from the live sender keystone snapshot"
      )
      Assert.Equal(chatMessages[1].channel, "PARTY", "sender own-key chat must use the party channel")
      Assert.Equal(#addonMessages, 1, "sender click must publish exactly one SHAREKEYS addon request")
      Assert.Equal(addonMessages[1].prefix, addon.Sync.GetPrefix(), "addon request must use the ISILIVE prefix")
      Assert.Equal(addonMessages[1].message, "SHAREKEYS", "addon request must carry the SHAREKEYS payload")
      Assert.Equal(addonMessages[1].channel, "PARTY", "addon request must use the party sync channel")
      Assert.False(shareKeysButton.enabled, "successful sender click must start the local share-keys cooldown")

      local receiverController = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, counters, {
        isMainFrameShown = function()
          return false
        end,
        processAddonMessage = function(prefix, message, sender, channel)
          return addon.Sync.ProcessAddonMessage(prefix, message, sender, "Receiver", "RealmB", channel)
        end,
        sendOwnKeystoneToChat = function()
          local line = addon.ContextHelpers.BuildOwnKeystoneAnnounceLine({
            getL = function()
              return { ANNOUNCE_PREFIX = "PartyKeys:" }
            end,
            getOwnedKeystoneSnapshot = function()
              return 2660, 15
            end,
            getDungeonShortCode = function(mapID)
              return mapID == 2660 and "RD" or nil
            end,
          })
          return addon.ContextHelpers.SendPartyChatMessage(line)
        end,
        triggerShareKeysCooldown = function()
          cooldownTriggers = cooldownTriggers + 1
        end,
        logRuntimeTracef = function(formatText, ...)
          table.insert(runtimeLogs, string.format(formatText, ...))
        end,
        getRoster = function()
          return receiverRoster
        end,
        forEachRosterInfo = function(visitor)
          visitor(receiverRoster.sender)
          visitor(receiverRoster.player)
        end,
        isSyncUserKnown = function(name, realm)
          return addon.Sync.IsUserKnown(name, realm)
        end,
      })

      receiverController:Dispatch(
        "CHAT_MSG_ADDON",
        addonMessages[1].prefix,
        addonMessages[1].message,
        addonMessages[1].channel,
        "Sender-RealmA"
      )
    end)

    Assert.Equal(#chatMessages, 2, "receiver must add exactly one answer chat line after processing SHAREKEYS")
    Assert.Equal(
      chatMessages[2].message,
      "[isiLive] PartyKeys: [Keystone: Receiver Dungeon +15]",
      "receiver chat output must be built from the receiver's own keystone snapshot"
    )
    Assert.Equal(chatMessages[2].channel, "PARTY", "receiver own-key chat must use the party channel")
    Assert.Equal(cooldownTriggers, 1, "receiver must trigger the remote share-keys cooldown")
    Assert.True(receiverRoster.sender.hasIsiLive, "pre-synced sender must stay marked as isiLive-known")
    Assert.Equal(
      counters.uiUpdates,
      0,
      "SHAREKEYS must not force a roster UI refresh when the sender was already known"
    )
    Assert.Equal(
      counters.updates,
      0,
      "SHAREKEYS must not refresh target-dependent status when no roster, target, or kick state changed"
    )

    local sawReceiveLog = false
    local sawReplyLog = false
    local sawCooldownLog = false
    for _, line in ipairs(runtimeLogs) do
      if line == "[SHAREKEYS] received sender=Sender-RealmA" then
        sawReceiveLog = true
      elseif line == "[SHAREKEYS] reply_result sender=Sender-RealmA sent=true" then
        sawReplyLog = true
      elseif line == "[SHAREKEYS] cooldown_triggered sender=Sender-RealmA" then
        sawCooldownLog = true
      end
    end
    Assert.True(sawReceiveLog, "receiver must log SHAREKEYS receive")
    Assert.True(sawReplyLog, "receiver must log successful own-key reply")
    Assert.True(sawCooldownLog, "receiver must log remote cooldown trigger")
  end)
end

local function RegisterShareKeysDeterministicLinkTest()
  test("Roster panel share keys button builds a deterministic keystone link", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local sentMessages = {}
    local shareKeyRequests = 0
    local currentTime = 300

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      C_ChallengeMode = {
        GetMapUIInfo = function(mapID)
          if mapID == 2662 then
            return "Mists of Tirna Scithe"
          end
          return nil
        end,
      },
      C_MythicPlus = {
        GetOwnedKeystoneLink = function()
          return "|Hitem:19019|h[Thunderfury, Blessed Blade of the Windseeker]|h"
        end,
      },
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      C_ChatInfo = {
        SendChatMessage = function(text, channel)
          table.insert(sentMessages, {
            text = text,
            channel = channel,
          })
        end,
      },
      print = function() end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(roster)
          return {
            { unit = "player", info = roster.player },
          }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Self",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {
            player = {
              name = "Self",
              role = "DAMAGER",
              keyMapID = 2662,
              keyLevel = 10,
            },
          }
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {
          DAMAGER = 1,
          NONE = 2,
        },
        unitPriority = {
          player = 1,
        },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 1,
        sendShareKeysRequest = function()
          shareKeyRequests = shareKeyRequests + 1
        end,
      })

      controller.RenderRoster({
        player = {
          name = "Self",
          role = "DAMAGER",
          keyMapID = 2662,
          keyLevel = 10,
        },
      })

      local shareKeysButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.pointY == -150 then
          shareKeysButton = frame
          break
        end
      end

      shareKeysButton = Assert.NotNil(shareKeysButton, "share-keys button should exist")
      ---@diagnostic disable: undefined-field
      shareKeysButton.OnClick()
      ---@diagnostic enable: undefined-field

      Assert.Equal(#sentMessages, 1, "share-keys should emit one chat message")
      Assert.Equal(sentMessages[1].channel, "PARTY", "share-keys should still announce to party chat")
      Assert.True(
        sentMessages[1].text:find("|Hkeystone:", 1, true) == nil,
        "share-keys fallback must not construct a manual keystone hyperlink (WoW silently drops those)"
      )
      Assert.True(
        sentMessages[1].text:find("%+10", 1) ~= nil,
        "share-keys fallback must still surface the keystone level in the plain-text announcement"
      )
      Assert.True(
        sentMessages[1].text:find("|Hitem:", 1, true) == nil,
        "share-keys must not forward a foreign item hyperlink"
      )
      Assert.Equal(shareKeyRequests, 1, "share-keys should still broadcast the sync request")
    end)
  end)
end

local function RegisterShareKeysFallbackLinkTest()
  test("Roster panel share keys button keeps the fallback keystone message clickable", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local sentMessages = {}
    local shareKeyRequests = 0
    local currentTime = 300

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      C_ChallengeMode = {
        GetMapUIInfo = function()
          return nil
        end,
      },
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      C_ChatInfo = {
        SendChatMessage = function(text, channel)
          table.insert(sentMessages, {
            text = text,
            channel = channel,
          })
        end,
      },
      print = function() end,
    }, function()
      local addon = LoadAddonModules({
        "core/isiLive_context_helpers.lua",
        "isiLive_roster_panel.lua",
      })

      addon.ContextHelpers.BuildKeystoneChatLink = function()
        return nil
      end

      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(roster)
          return {
            { unit = "player", info = roster.player },
          }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Self",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {
            player = {
              name = "Self",
              role = "DAMAGER",
              keyMapID = 2662,
              keyLevel = 10,
            },
          }
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {
          DAMAGER = 1,
          NONE = 2,
        },
        unitPriority = {
          player = 1,
        },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 1,
        sendShareKeysRequest = function()
          shareKeyRequests = shareKeyRequests + 1
        end,
      })

      controller.RenderRoster({
        player = {
          name = "Self",
          role = "DAMAGER",
          keyMapID = 2662,
          keyLevel = 10,
        },
      })

      local shareKeysButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.pointY == -150 then
          shareKeysButton = frame
          break
        end
      end

      shareKeysButton = Assert.NotNil(shareKeysButton, "share-keys button should exist")
      ---@diagnostic disable: undefined-field
      shareKeysButton.OnClick()
      ---@diagnostic enable: undefined-field

      Assert.Equal(#sentMessages, 1, "share-keys should still emit one chat message")
      Assert.Equal(sentMessages[1].channel, "PARTY", "fallback share-keys message should still announce to party chat")
      -- Manually constructed |Hkeystone:...|h links are server-rejected in
      -- retail — SendChatMessage silently drops them. The fallback must stay
      -- plain-text so the message actually reaches the party.
      Assert.True(
        sentMessages[1].text:find("|Hkeystone:", 1, true) == nil,
        "fallback share-keys message must not contain a manually constructed keystone link"
      )
      Assert.True(
        sentMessages[1].text:find("DB +10", 1, true) ~= nil,
        "fallback share-keys message should still carry the dungeon short code label"
      )
      Assert.Equal(shareKeyRequests, 1, "fallback share-keys flow should still broadcast the sync request")
    end)
  end)
end

local function RegisterShareKeysLiveSnapshotTest()
  test("Roster panel share keys button prefers the live owned keystone snapshot over a stale roster cache", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local sentMessages = {}
    local shareKeyRequests = 0
    local currentTime = 300

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      C_ChatInfo = {
        SendChatMessage = function(text, channel)
          table.insert(sentMessages, {
            text = text,
            channel = channel,
          })
        end,
      },
      print = function() end,
    }, function()
      local addon = LoadAddonModules({
        "core/isiLive_context_helpers.lua",
        "isiLive_roster_panel.lua",
      })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(roster)
          return {
            { unit = "player", info = roster.player },
          }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Self",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "-",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "MOTS"
        end,
        getOwnedKeystoneSnapshot = function()
          return 2662, 10
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {
            player = {
              name = "Self",
              role = "DAMAGER",
              keyMapID = 0,
              keyLevel = 0,
            },
          }
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {
          DAMAGER = 1,
          NONE = 2,
        },
        unitPriority = {
          player = 1,
        },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 1,
        sendShareKeysRequest = function()
          shareKeyRequests = shareKeyRequests + 1
          return true
        end,
      })

      controller.RenderRoster({
        player = {
          name = "Self",
          role = "DAMAGER",
          keyMapID = 0,
          keyLevel = 0,
        },
      })

      local shareKeysButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.pointY == -150 then
          shareKeysButton = frame
          break
        end
      end

      shareKeysButton = Assert.NotNil(shareKeysButton, "share-keys button should exist")
      ---@cast shareKeysButton any
      Assert.True(shareKeysButton.enabled, "live owned keystone data should keep the share-keys button available")
      ---@diagnostic disable: undefined-field
      shareKeysButton.OnClick()
      ---@diagnostic enable: undefined-field

      Assert.Equal(#sentMessages, 1, "share-keys should announce the live owned keystone snapshot")
      Assert.Equal(sentMessages[1].channel, "PARTY", "live owned keystone snapshot should still announce to party chat")
      Assert.True(
        sentMessages[1].text:find("|Hkeystone:", 1, true) == nil,
        "live owned keystone snapshot must not emit a manual keystone hyperlink (WoW drops those)"
      )
      Assert.True(
        sentMessages[1].text:find("%+10", 1) ~= nil,
        "live owned keystone snapshot must still surface the keystone level in the plain-text announcement"
      )
      Assert.Equal(shareKeyRequests, 1, "share-keys should still broadcast the peer sync request")
    end)
  end)
end

local function RegisterShareKeysDebounceTests()
  test("Roster panel share keys button debounces rapid clicks", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local sentMessages = {}
    local shareKeyRequests = 0
    local currentTime = 100

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      C_ChatInfo = {
        SendChatMessage = function(text, channel)
          table.insert(sentMessages, {
            text = text,
            channel = channel,
          })
        end,
      },
      print = function() end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(roster)
          return {
            { unit = "player", info = roster.player },
          }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Self",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {
            player = {
              name = "Self",
              role = "DAMAGER",
              keyMapID = 2441,
              keyLevel = 10,
            },
          }
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {
          DAMAGER = 1,
          NONE = 2,
        },
        unitPriority = {
          player = 1,
        },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 1,
        sendShareKeysRequest = function()
          shareKeyRequests = shareKeyRequests + 1
        end,
      })

      controller.RenderRoster({
        player = {
          name = "Self",
          role = "DAMAGER",
          keyMapID = 2441,
          keyLevel = 10,
        },
      })

      local shareKeysButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.pointY == -150 then
          shareKeysButton = frame
          break
        end
      end

      shareKeysButton = Assert.NotNil(shareKeysButton, "share-keys button should exist")
      ---@diagnostic disable: undefined-field
      shareKeysButton.OnClick()
      shareKeysButton.OnClick()
      Assert.Equal(#sentMessages, 1, "rapid repeated share-keys clicks should be debounced")
      Assert.Equal(sentMessages[1].channel, "PARTY", "share-keys should announce to party chat")
      Assert.Equal(shareKeyRequests, 1, "share-keys should send one sync request on the first click")

      currentTime = 101.5
      shareKeysButton.OnClick()
      ---@diagnostic enable: undefined-field
      Assert.Equal(#sentMessages, 2, "share-keys click should fire again after debounce window")
      Assert.Equal(shareKeyRequests, 2, "share-keys should send another sync request after the debounce window")
    end)
  end)

  test("Roster panel share keys button does not treat the local print fallback as a successful party share", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local printedMessages = {}
    local shareKeyRequests = 0
    local currentTime = 700

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      SendChatMessage = function()
        error("party chat blocked")
      end,
      print = function(message)
        table.insert(printedMessages, tostring(message))
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(roster)
          return {
            { unit = "player", info = roster.player },
          }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Self",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {
            player = {
              name = "Self",
              role = "DAMAGER",
              keyMapID = 2441,
              keyLevel = 10,
            },
          }
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {
          DAMAGER = 1,
          NONE = 2,
        },
        unitPriority = {
          player = 1,
        },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 30,
        sendShareKeysRequest = function()
          shareKeyRequests = shareKeyRequests + 1
          return false
        end,
      })

      controller.RenderRoster({
        player = {
          name = "Self",
          role = "DAMAGER",
          keyMapID = 2441,
          keyLevel = 10,
        },
      })

      local shareKeysButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.pointY == -150 then
          shareKeysButton = frame
          break
        end
      end

      shareKeysButton = Assert.NotNil(shareKeysButton, "share-keys button should exist")
      ---@cast shareKeysButton any
      ---@diagnostic disable: undefined-field
      shareKeysButton.OnClick()
      shareKeysButton.OnClick()
      ---@diagnostic enable: undefined-field
      Assert.Equal(#printedMessages, 2, "local print fallback should still run on every failed click attempt")
      Assert.Equal(
        shareKeyRequests,
        2,
        "failed party-chat sends must not start the share-keys cooldown when the sync request also fails"
      )
      Assert.True(shareKeysButton.enabled, "failed party-chat sends must leave the share-keys button usable")
    end)
  end)
end

local function RegisterShareKeysNoOpAndRemoteTests()
  test("Roster panel share keys button ignores no-op clicks without chat or sync success", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local sentMessages = {}
    local shareKeyRequests = 0
    local currentTime = 500

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      C_ChatInfo = {},
      print = function() end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(roster)
          return {
            { unit = "player", info = roster.player },
            { unit = "party1", info = roster.party1 },
          }
        end,
        buildDisplayData = function(info)
          return {
            colorHex = "ffffffff",
            displayName = info.name,
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = tonumber(info.keyLevel) and tonumber(info.keyLevel) > 0 and "DB +10" or "-",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {
            player = {
              name = "Self",
              role = "DAMAGER",
              keyMapID = 0,
              keyLevel = 0,
            },
            party1 = {
              name = "Mate",
              role = "DAMAGER",
              keyMapID = 2441,
              keyLevel = 10,
            },
          }
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {
          DAMAGER = 1,
          NONE = 2,
        },
        unitPriority = {
          player = 1,
          party1 = 2,
        },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 30,
        sendShareKeysRequest = function()
          shareKeyRequests = shareKeyRequests + 1
          return false
        end,
      })

      controller.RenderRoster({
        player = {
          name = "Self",
          role = "DAMAGER",
          keyMapID = 0,
          keyLevel = 0,
        },
        party1 = {
          name = "Mate",
          role = "DAMAGER",
          keyMapID = 2441,
          keyLevel = 10,
        },
      })

      local shareKeysButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.pointY == -150 then
          shareKeysButton = frame
          break
        end
      end

      shareKeysButton = Assert.NotNil(shareKeysButton, "share-keys button should exist")
      ---@cast shareKeysButton any
      Assert.True(shareKeysButton.enabled, "foreign group keys should still make the button clickable")
      ---@diagnostic disable: undefined-field
      shareKeysButton.OnClick()
      shareKeysButton.OnClick()
      ---@diagnostic enable: undefined-field
      Assert.Equal(#sentMessages, 0, "no-op clicks must not emit chat output")
      Assert.Equal(shareKeyRequests, 2, "failed no-op clicks must stay usable and not start the debounce lock")
      Assert.True(shareKeysButton.enabled, "no-op clicks must leave the share-keys button enabled")
    end)
  end)

  RegisterShareKeysRemoteCooldownTests()
end

RegisterShareKeysRemoteCooldownTests = function()
  test("Roster panel share keys button locks on remote SHAREKEYS signal", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local shareKeyRequests = 0
    local currentTime = 200

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      C_ChatInfo = { SendChatMessage = function() end },
      print = function() end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(roster)
          return { { unit = "player", info = roster.player } }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Self",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return { player = { name = "Self", role = "DAMAGER", keyMapID = 2441, keyLevel = 10 } }
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = { DAMAGER = 1, NONE = 2 },
        unitPriority = { player = 1 },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 30,
        sendShareKeysRequest = function()
          shareKeyRequests = shareKeyRequests + 1
        end,
      })

      controller.RenderRoster({
        player = { name = "Self", role = "DAMAGER", keyMapID = 2441, keyLevel = 10 },
      })

      local shareKeysButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.pointY == -150 then
          shareKeysButton = frame
          break
        end
      end

      shareKeysButton = Assert.NotNil(shareKeysButton, "share-keys button should exist")
      ---@diagnostic disable: undefined-field

      controller.TriggerShareKeysCooldown()

      shareKeysButton.OnClick()
      Assert.Equal(shareKeyRequests, 0, "local click must be blocked after remote SHAREKEYS locks the button")

      currentTime = 231
      shareKeysButton.OnClick()
      ---@diagnostic enable: undefined-field
      Assert.Equal(shareKeyRequests, 1, "local click must succeed once debounce window has passed")
    end)
  end)

  test("Roster panel share keys button mirrors a partial remote cooldown with max-merge", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local shareKeyRequests = 0
    local currentTime = 200

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      C_ChatInfo = { SendChatMessage = function() end },
      print = function() end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(roster)
          return { { unit = "player", info = roster.player } }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Self",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return { player = { name = "Self", role = "DAMAGER", keyMapID = 2441, keyLevel = 10 } }
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = { DAMAGER = 1, NONE = 2 },
        unitPriority = { player = 1 },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 30,
        sendShareKeysRequest = function()
          shareKeyRequests = shareKeyRequests + 1
          return true
        end,
      })

      controller.RenderRoster({
        player = { name = "Self", role = "DAMAGER", keyMapID = 2441, keyLevel = 10 },
      })

      local shareKeysButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.pointY == -150 then
          shareKeysButton = frame
          break
        end
      end
      shareKeysButton = Assert.NotNil(shareKeysButton, "share-keys button should exist")

      Assert.Equal(controller.GetShareKeysCooldownRemaining(), 0, "button must report zero remaining when unlocked")

      controller.TriggerShareKeysCooldown(12)
      Assert.Equal(controller.GetShareKeysCooldownRemaining(), 12, "partial remote cooldown must be mirrored")

      controller.TriggerShareKeysCooldown(5)
      Assert.Equal(
        controller.GetShareKeysCooldownRemaining(),
        12,
        "a shorter remote cooldown must never shorten the running lock (max-merge)"
      )

      ---@diagnostic disable: undefined-field
      shareKeysButton.OnClick()
      ---@diagnostic enable: undefined-field
      Assert.Equal(shareKeyRequests, 0, "local click must stay blocked while the mirrored cooldown runs")

      controller.TriggerShareKeysCooldown(25)
      Assert.Equal(controller.GetShareKeysCooldownRemaining(), 25, "a longer remote cooldown must extend the lock")

      controller.TriggerShareKeysCooldown(999)
      Assert.Equal(
        controller.GetShareKeysCooldownRemaining(),
        30,
        "remote cooldown must be clamped to the local debounce window"
      )

      currentTime = 226
      ---@diagnostic disable: undefined-field
      shareKeysButton.OnClick()
      ---@diagnostic enable: undefined-field
      Assert.Equal(shareKeyRequests, 0, "click must stay blocked until the extended lock expires")

      currentTime = 231
      ---@diagnostic disable: undefined-field
      shareKeysButton.OnClick()
      ---@diagnostic enable: undefined-field
      Assert.Equal(shareKeyRequests, 1, "click must succeed once the extended lock has expired")
    end)
  end)

  test("Roster panel share keys button reports only locally owned locks for SKCD mirroring", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local shareKeyRequests = 0
    local currentTime = 200

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      C_ChatInfo = { SendChatMessage = function() end },
      print = function() end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(roster)
          return { { unit = "player", info = roster.player } }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Self",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return { player = { name = "Self", role = "DAMAGER", keyMapID = 2441, keyLevel = 10 } }
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = { DAMAGER = 1, NONE = 2 },
        unitPriority = { player = 1 },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 30,
        sendShareKeysRequest = function()
          shareKeyRequests = shareKeyRequests + 1
          return true
        end,
      })

      controller.RenderRoster({
        player = { name = "Self", role = "DAMAGER", keyMapID = 2441, keyLevel = 10 },
      })

      local shareKeysButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.pointY == -150 then
          shareKeysButton = frame
          break
        end
      end
      shareKeysButton = Assert.NotNil(shareKeysButton, "share-keys button should exist")

      Assert.Equal(controller.GetShareKeysLocalCooldownRemaining(), 0, "idle button must report no locally owned lock")

      controller.TriggerShareKeysCooldown(12)
      Assert.Equal(controller.GetShareKeysCooldownRemaining(), 12, "remote mirror must lock the button")
      Assert.Equal(
        controller.GetShareKeysLocalCooldownRemaining(),
        0,
        "a remote-mirrored lock must never be re-broadcast via SKCD"
      )

      controller.TriggerShareKeysCooldown()
      Assert.Equal(
        controller.GetShareKeysLocalCooldownRemaining(),
        30,
        "a received SHAREKEYS lock is locally owned and may be mirrored"
      )

      controller.TriggerShareKeysCooldown(20)
      Assert.Equal(
        controller.GetShareKeysLocalCooldownRemaining(),
        30,
        "a shorter remote mirror must not demote the locally owned lock"
      )

      currentTime = 205
      controller.TriggerShareKeysCooldown(30)
      Assert.Equal(controller.GetShareKeysCooldownRemaining(), 30, "a longer remote mirror must extend the lock")
      Assert.Equal(
        controller.GetShareKeysLocalCooldownRemaining(),
        0,
        "a remote-extended lock loses local ownership and must not be re-broadcast"
      )

      currentTime = 236
      ---@diagnostic disable: undefined-field
      shareKeysButton.OnClick()
      ---@diagnostic enable: undefined-field
      Assert.Equal(shareKeyRequests, 1, "click must succeed once the remote lock has expired")
      Assert.Equal(
        controller.GetShareKeysLocalCooldownRemaining(),
        30,
        "an own click creates a locally owned lock for SKCD mirroring"
      )
    end)
  end)

  test("Share keys cooldown mirror drives full sender receiver SKCD chain", function()
    local Fixtures = RequireFixtures()
    local createdFrames = {}
    local createdFontStrings = {}
    local addonMessages = {}
    local currentTime = 500

    local function Strsplit(sep, str, max)
      local pos = str:find(sep, 1, true)
      if not pos then
        return str
      end
      if max and max >= 2 then
        return str:sub(1, pos - 1), str:sub(pos + 1)
      end
      return str:sub(1, pos - 1)
    end

    local function BuildPanelOpts(addon)
      return {
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(roster)
          return { { unit = "player", info = roster.player } }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Self",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return { player = { name = "Self", role = "DAMAGER", keyMapID = 2441, keyLevel = 10 } }
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = { DAMAGER = 1, NONE = 2 },
        unitPriority = { player = 1 },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 30,
        sendShareKeysRequest = function()
          return addon.Sync.SendShareKeysRequest()
        end,
      }
    end

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      GetRealmName = function()
        return "RealmA"
      end,
      GetTime = function()
        return currentTime
      end,
      IsInRaid = function()
        return false
      end,
      IsInGroup = function(category)
        if category == 2 then
          return false
        end
        return true
      end,
      LE_PARTY_CATEGORY_INSTANCE = 2,
      IsiLiveDB = { syncEnabled = true },
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(addonMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
          return true
        end,
      },
      strsplit = Strsplit,
      print = function() end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_context_helpers.lua",
        "isiLive_sync.lua",
        "isiLive_event_handlers.lua",
        "isiLive_roster_panel.lua",
      })

      -- Sender: button locked at t=500 (full 30s window), 13s elapse, then
      -- the hello-ack fan-out mirrors the real remaining time onto the wire.
      local senderController = addon.RosterPanel.CreateController(BuildPanelOpts(addon))
      senderController.TriggerShareKeysCooldown()
      currentTime = 513
      local senderRemain = senderController.GetShareKeysCooldownRemaining()
      Assert.Equal(senderRemain, 17, "sender getter must report the real remaining lock time")

      local sendOk = addon.Sync.SendShareKeysCooldown({ remain = senderRemain })
      Assert.True(sendOk, "sender must publish the mirrored cooldown")
      Assert.Equal(#addonMessages, 1, "exactly one SKCD addon message must hit the wire")
      Assert.Equal(addonMessages[1].message, "SKCD:17", "wire payload must carry the sender's remaining seconds")

      -- Receiver: feed the captured wire bytes through the real dispatcher,
      -- parser, and a real receiver-side roster panel button.
      local receiverPanel = addon.RosterPanel.CreateController(BuildPanelOpts(addon))
      local receiverController = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, nil, {
        isMainFrameShown = function()
          return false
        end,
        processAddonMessage = function(prefix, message, sender, channel)
          return addon.Sync.ProcessAddonMessage(prefix, message, sender, "Receiver", "RealmB", channel)
        end,
        triggerShareKeysCooldown = function(seconds)
          receiverPanel.TriggerShareKeysCooldown(seconds)
        end,
      })

      receiverController:Dispatch(
        "CHAT_MSG_ADDON",
        addonMessages[1].prefix,
        addonMessages[1].message,
        addonMessages[1].channel,
        "Sender-RealmA"
      )

      Assert.Equal(
        receiverPanel.GetShareKeysCooldownRemaining(),
        17,
        "receiver button must mirror the sender's remaining lock time"
      )

      currentTime = 531
      Assert.Equal(
        receiverPanel.GetShareKeysCooldownRemaining(),
        0,
        "mirrored lock must expire exactly when the sender's window ends"
      )
    end)
  end)

  test("Share keys SKCD reflection dies after one hop across real wiring and buttons", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local addonMessages = {}
    local currentTime = 500

    local function Strsplit(sep, str, max)
      local pos = str:find(sep, 1, true)
      if not pos then
        return str
      end
      if max and max >= 2 then
        return str:sub(1, pos - 1), str:sub(pos + 1)
      end
      return str:sub(1, pos - 1)
    end

    local function Noop() end

    local function BuildPanelOpts()
      return {
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(roster)
          return { { unit = "player", info = roster.player } }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Self",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return { player = { name = "Self", role = "DAMAGER", keyMapID = 2441, keyLevel = 10 } }
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = { DAMAGER = 1, NONE = 2 },
        unitPriority = { player = 1 },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 30,
        sendShareKeysRequest = function()
          return true
        end,
      }
    end

    -- Minimal required deps for the real ControllerWiring event-handlers
    -- config; modules.sync is the real Sync module so
    -- sendShareKeysCooldownState produces real SKCD wire bytes.
    local function BuildWiringDeps(addon, panelController)
      return {
        addonName = "isiLive",
        defaultLocale = "enUS",
        locales = { enUS = {} },
        resolveLocaleTag = Noop,
        setLocaleTable = Noop,
        isInGroup = Noop,
        isInChallengeMode = Noop,
        isNegativeApplicationStatusEvent = Noop,
        getNormalizedActiveEntryInfo = Noop,
        sendIsiLiveHello = Noop,
        sendOwnKeySnapshot = Noop,
        sendOwnBackgroundSnapshot = Noop,
        sendRefreshResponse = Noop,
        ensureQueueDebugStorage = Noop,
        setQueueDebugEnabled = Noop,
        registerIsiLiveSyncPrefix = Noop,
        applyHotkeyBindings = Noop,
        startBindingWatchdog = Noop,
        getUnitNameAndRealm = Noop,
        markIsiLiveUser = Noop,
        applyKnownKeyToRosterEntry = Noop,
        runFullRefresh = Noop,
        getShareKeysLocalCooldownRemaining = function()
          return panelController.GetShareKeysLocalCooldownRemaining()
        end,
        state = {
          isTestMode = Noop,
          isTestAllMode = Noop,
          setPendingQueueJoinInfo = Noop,
          setPendingPostChallengeRefresh = Noop,
          getActiveJoinedKeyMapID = Noop,
          setActiveJoinedKeyMapID = Noop,
          getPendingBindingApply = Noop,
          getRoster = function()
            return {}
          end,
        },
        refs = {
          mainFrame = {
            IsShown = function()
              return false
            end,
          },
          mainUI = {
            GetPendingHeight = Noop,
            GetPendingWidth = Noop,
            GetPendingVisible = Noop,
          },
          applySecureSpellToButton = Noop,
        },
        controllers = {
          group = {
            HandleGroupRosterUpdate = Noop,
          },
        },
        callbacks = {
          exitTestMode = Noop,
          clearLatestQueueTarget = Noop,
          updateMPlusTeleportButton = Noop,
          captureQueueJoinCandidate = Noop,
          updateUI = Noop,
          refreshReadyCheckUI = Noop,
          setMainFrameVisible = Noop,
          updateLeaderButtons = Noop,
          updateStatusLine = Noop,
          applyLocalizationToUI = Noop,
          restoreLayoutState = Noop,
          updateCountdownCancelButton = Noop,
          checkIfEnteredTargetDungeon = Noop,
          setMainFrameHeightSafe = Noop,
          setMainFrameWidthSafe = Noop,
        },
        modules = { sync = addon.Sync },
      }
    end

    local function CaptureConfigModule()
      local captured
      return {
        CreateController = function(config)
          captured = config
          return {}
        end,
      }, function()
        return captured
      end
    end

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      GetRealmName = function()
        return "RealmA"
      end,
      GetTime = function()
        return currentTime
      end,
      IsInRaid = function()
        return false
      end,
      IsInGroup = function()
        return true
      end,
      LE_PARTY_CATEGORY_INSTANCE = 2,
      IsiLiveDB = { syncEnabled = true },
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(addonMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
          return true
        end,
      },
      strsplit = Strsplit,
      print = function() end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_context_helpers.lua",
        "isiLive_sync.lua",
        "isiLive_roster_panel.lua",
        "isiLive_controller_wiring.lua",
      })

      local senderPanel = addon.RosterPanel.CreateController(BuildPanelOpts())
      local receiverPanel = addon.RosterPanel.CreateController(BuildPanelOpts())

      local senderModule, getSenderConfig = CaptureConfigModule()
      addon.ControllerWiring.CreateEventHandlersController(senderModule, BuildWiringDeps(addon, senderPanel))
      local senderConfig = getSenderConfig()

      local receiverModule, getReceiverConfig = CaptureConfigModule()
      addon.ControllerWiring.CreateEventHandlersController(receiverModule, BuildWiringDeps(addon, receiverPanel))
      local receiverConfig = getReceiverConfig()

      -- Sender: lock is locally owned (received SHAREKEYS request path).
      senderPanel.TriggerShareKeysCooldown()
      Assert.True(senderConfig.sendShareKeysCooldownState(), "sender must mirror its locally owned lock")
      Assert.Equal(#addonMessages, 1, "exactly one SKCD message must hit the wire")
      Assert.Equal(addonMessages[1].message, "SKCD:30", "wire payload must carry the sender's full window")

      -- Receiver: real parser, then the production mirror path
      -- (ApplyMirroredShareKeysCooldown passes the remain argument).
      local result = addon.Sync.ProcessAddonMessage(
        addonMessages[1].prefix,
        addonMessages[1].message,
        "PeerA-RealmA",
        "Receiver",
        "RealmB",
        addonMessages[1].channel
      )
      Assert.Equal(result.shareKeysCooldownRemain, 30, "receiver parser must surface the mirrored remain")
      receiverPanel.TriggerShareKeysCooldown(result.shareKeysCooldownRemain)
      Assert.Equal(receiverPanel.GetShareKeysCooldownRemaining(), 30, "receiver button must be locked by the mirror")

      -- Reflection must die here: the receiver's lock is remote-owned, so
      -- its fan-out sends no SKCD. The clock is advanced past the 1 s send
      -- rate limit so only the ownership gate can suppress the send.
      currentTime = 502
      Assert.False(receiverConfig.sendShareKeysCooldownState(), "receiver must not re-broadcast the mirrored lock")
      Assert.Equal(#addonMessages, 1, "no second SKCD message may hit the wire (reflection loop)")

      -- Positive control: once the receiver owns a lock locally (incoming
      -- SHAREKEYS), its fan-out mirrors again.
      currentTime = 504
      receiverPanel.TriggerShareKeysCooldown()
      Assert.True(receiverConfig.sendShareKeysCooldownState(), "receiver must mirror its own locally owned lock")
      Assert.Equal(#addonMessages, 2, "a locally owned lock must produce a new SKCD message")
    end)
  end)

  test("Roster panel share keys remote cooldown survives a normal roster rerender", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local shareKeyRequests = 0
    local currentTime = 200
    local roster = {
      player = { name = "Self", role = "DAMAGER", keyMapID = 2441, keyLevel = 10 },
    }

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      C_ChatInfo = { SendChatMessage = function() end },
      print = function() end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(currentRoster)
          return { { unit = "player", info = currentRoster.player } }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Self",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return roster
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = { DAMAGER = 1, NONE = 2 },
        unitPriority = { player = 1 },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 30,
        sendShareKeysRequest = function()
          shareKeyRequests = shareKeyRequests + 1
          return true
        end,
      })

      controller.RenderRoster(roster)

      local shareKeysButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.pointY == -150 then
          shareKeysButton = frame
          break
        end
      end

      shareKeysButton = Assert.NotNil(shareKeysButton, "share-keys button should exist")
      ---@diagnostic disable: undefined-field
      controller.TriggerShareKeysCooldown()
      controller.RenderRoster(roster)
      shareKeysButton.OnClick()
      ---@diagnostic enable: undefined-field

      Assert.Equal(
        shareKeyRequests,
        0,
        "normal roster rerenders must not drop the remotely triggered share-keys cooldown"
      )

      currentTime = 231
      ---@diagnostic disable: undefined-field
      shareKeysButton.OnClick()
      ---@diagnostic enable: undefined-field
      Assert.Equal(shareKeyRequests, 1, "share-keys should become usable again once the cooldown expires")
    end)
  end)

  test("Roster panel share keys cooldown text survives localization and layout refresh", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local currentTime = 200
    local roster = {
      player = { name = "Self", role = "DAMAGER", keyMapID = 2441, keyLevel = 10 },
    }

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      C_ChatInfo = { SendChatMessage = function() end },
      print = function() end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_roster_layout.lua",
        "isiLive_roster_panel_chrome.lua",
        "isiLive_roster_panel.lua",
      })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {
            TITLE = "isiLive",
            BTN_READYCHECK = "Readycheck",
            BTN_COUNTDOWN10 = "Countdown10",
            BTN_COUNTDOWN_CANCEL = "Countdown 0",
            BTN_REFRESH = "Re-Sync",
            BTN_SHARE_KEYS = "Share Keys",
          }
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(currentRoster)
          return { { unit = "player", info = currentRoster.player } }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Self",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return roster
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = { DAMAGER = 1, NONE = 2 },
        unitPriority = { player = 1 },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 30,
        sendShareKeysRequest = function()
          return true
        end,
      })

      controller.ApplyLocalization()
      controller.RenderRoster(roster)

      local shareKeysButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.pointY == -150 then
          shareKeysButton = frame
          break
        end
      end
      shareKeysButton = Assert.NotNil(shareKeysButton, "share-keys button should exist")

      controller.TriggerShareKeysCooldown()
      Assert.Equal(
        shareKeysButton._flatLabel.text,
        "Share Keys (30s)",
        "started share-keys cooldown must show the remaining time"
      )

      currentTime = 207
      controller.ApplyLocalization()
      Assert.Equal(
        shareKeysButton._flatLabel.text,
        "Share Keys (23s)",
        "localization refresh must not replace the cooldown label with the base label"
      )

      controller.RefreshLayoutState()
      Assert.Equal(
        shareKeysButton._flatLabel.text,
        "Share Keys (23s)",
        "layout refresh must not replace the cooldown label with the base label"
      )
    end)
  end)
end

return function(test_arg, ctx)
  test = test_arg
  Assert = ctx.assert
  WithGlobals = ctx.with_globals
  LoadAddonModules = ctx.load_modules
  local Helpers = RequireRosterPanelHelpers()
  NewRecordedFrame = Helpers.NewRecordedFrame
  NewRecordedMainFrame = Helpers.NewRecordedMainFrame
  RegisterShareKeysGlobalPathTest()
  RegisterShareKeysDispatchOrderTest()
  RegisterShareKeysEndToEndButtonRuntimeTest()
  RegisterShareKeysDeterministicLinkTest()
  RegisterShareKeysFallbackLinkTest()
  RegisterShareKeysLiveSnapshotTest()
  RegisterShareKeysDebounceTests()
  RegisterShareKeysNoOpAndRemoteTests()
end
