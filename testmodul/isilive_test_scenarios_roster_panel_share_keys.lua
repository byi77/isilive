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
  RegisterShareKeysEndToEndButtonRuntimeTest()
  RegisterShareKeysDeterministicLinkTest()
  RegisterShareKeysFallbackLinkTest()
  RegisterShareKeysLiveSnapshotTest()
  RegisterShareKeysDebounceTests()
  RegisterShareKeysNoOpAndRemoteTests()
end
