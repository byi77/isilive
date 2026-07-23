-- Standalone CLI tool: uses standard Lua globals outside the WoW runtime.
---@diagnostic disable-next-line: undefined-global
local io = io
---@diagnostic disable-next-line: undefined-global
local load = load
---@diagnostic disable-next-line: undefined-global
local os = os

local function LoadLocal(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  local chunk, err = (loadstring or load)(source, "@" .. path)
  assert(chunk, err)
  return chunk()
end

local Harness = LoadLocal("testmodul/isilive_test_harness.lua")
local Fixtures = LoadLocal("testmodul/isilive_test_fixtures.lua")

local function BuildStrsplit()
  return function(sep, str, max)
    local pos = str:find(sep, 1, true)
    if not pos then
      return str
    end
    if max and max >= 2 then
      return str:sub(1, pos - 1), str:sub(pos + 1)
    end
    return str:sub(1, pos - 1)
  end
end

local function WithSyncGlobals(fn, opts)
  opts = opts or {}
  Harness.WithGlobals({
    GetRealmName = function()
      return opts.realm or "Realm"
    end,
    GetTime = function()
      return opts.now or 100
    end,
    IsInGroup = function()
      return opts.inGroup ~= false
    end,
    IsInRaid = function()
      return opts.inRaid == true
    end,
    strsplit = BuildStrsplit(),
    C_ChatInfo = opts.chatInfo,
  }, fn)
end

local function LoadSync()
  return Harness.LoadAddonModules({ "isiLive_sync.lua" })
end

local function PrintTable(prefix, t)
  if type(t) ~= "table" then
    print(prefix .. tostring(t))
    return
  end
  local parts = {}
  for key, value in pairs(t) do
    parts[#parts + 1] = string.format("%s=%s", tostring(key), tostring(value))
  end
  table.sort(parts)
  print(prefix .. table.concat(parts, ", "))
end

local function SimulateShareKeys()
  local sent = {}
  WithSyncGlobals(function()
    local addon = LoadSync()
    local ok = addon.Sync.SendShareKeysRequest()
    print("sender.sharekeys.ok=" .. tostring(ok))
  end, {
    chatInfo = {
      SendAddonMessage = function(prefix, message, channel)
        sent[#sent + 1] = {
          prefix = prefix,
          message = message,
          channel = channel,
        }
        return true
      end,
    },
  })

  WithSyncGlobals(function()
    local addon = LoadSync()
    local result = addon.Sync.ProcessAddonMessage(
      sent[1].prefix,
      sent[1].message,
      "OtherPlayer-OtherRealm",
      "Me",
      "Realm",
      sent[1].channel
    )
    PrintTable("receiver.sharekeys.", result)
  end, {})
end

local function SimulateKey()
  WithSyncGlobals(function()
    local addon = LoadSync()
    local result = addon.Sync.ProcessAddonMessage("ISILIVE", "KEY:2649:15:100:local", "Peer-OtherRealm", "Me", "Realm")
    PrintTable("receiver.key.", result)
    PrintTable("receiver.key.state.", addon.Sync.GetPlayerKeyInfo("Peer", "OtherRealm"))
  end, {})
end

local function SimulateStats()
  WithSyncGlobals(function()
    local addon = LoadSync()
    local result =
      addon.Sync.ProcessAddonMessage("ISILIVE", "STATS:72:615:3210:100:local", "Peer-OtherRealm", "Me", "Realm")
    PrintTable("receiver.stats.", result)
    PrintTable("receiver.stats.state.", addon.Sync.GetPlayerStatsInfo("Peer", "OtherRealm"))
  end, {})
end

local function SimulateKick()
  WithSyncGlobals(function()
    local addon = LoadSync()
    local result = addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:1:8", "Peer-OtherRealm", "Me", "Realm")
    PrintTable("receiver.kick.", result)
    PrintTable("receiver.kick.state.", addon.Sync.GetPlayerKickInfo("Peer", "OtherRealm"))
  end, {})
end

local function LoadContextHelpers()
  return Harness.LoadAddonModules({ "isiLive_context_helpers.lua" })
end

local function MakeBagApi(hasKey)
  return {
    GetContainerNumSlots = function(bagID)
      return bagID == 0 and 16 or 0
    end,
    GetContainerItemID = function(bagID, slotID)
      if hasKey and bagID == 0 and slotID == 5 then
        return 180653
      end
      return nil
    end,
    GetContainerItemLink = function(bagID, slotID)
      if hasKey and bagID == 0 and slotID == 5 then
        return "|cffa335ee|Hkeystone:180653:2649:12:10:10:10:10|h[Keystone: Ara-Kara +12]|h|r"
      end
      return nil
    end,
  }
end

local function MakeChallengeModeApi()
  return {
    GetMapUIInfo = function(mapID)
      if mapID == 2649 then
        return "Ara-Kara, City of Echoes"
      end
      return nil
    end,
  }
end

local function RunPipelineScenario(name, opts)
  local sentMessages = {}
  local sentChannels = {}

  local globals = {
    GetTime = function()
      return 100
    end,
    IsInGroup = function(category)
      if category == 2 then
        return opts.inInstance == true
      end
      return opts.inGroup ~= false
    end,
    LE_PARTY_CATEGORY_INSTANCE = 2,
    C_MythicPlus = {},
    C_Container = MakeBagApi(opts.bagHasKey == true),
    C_ChallengeMode = MakeChallengeModeApi(),
    SendChatMessage = opts.sendChatMessageFails and function()
      error("simulated SendChatMessage failure", 0)
    end or function(message, channel)
      sentMessages[#sentMessages + 1] = message
      sentChannels[#sentChannels + 1] = channel
    end,
    C_ChatInfo = opts.chatInfoFallbackOnly and {
      SendChatMessage = function(message, channel)
        sentMessages[#sentMessages + 1] = "[fallback]" .. message
        sentChannels[#sentChannels + 1] = channel
      end,
    } or nil,
  }

  local resultLine, sendOk
  Harness.WithGlobals(globals, function()
    local addon = LoadContextHelpers()
    local Helpers = addon.ContextHelpers

    resultLine = Helpers.BuildOwnKeystoneAnnounceLine({
      getL = function()
        return { ANNOUNCE_PREFIX = "PartyKeys:" }
      end,
      getOwnedKeystoneSnapshot = function()
        if opts.snapshotMissing then
          return nil
        end
        return 2649, 12
      end,
      getDungeonShortCode = function(mapID)
        return mapID == 2649 and "ARA" or nil
      end,
    })

    if type(resultLine) == "string" and resultLine ~= "" then
      sendOk = Helpers.SendPartyChatMessage(resultLine)
    end
  end)

  print("---- " .. name)
  print("  line     = " .. tostring(resultLine))
  print("  sendOk   = " .. tostring(sendOk))
  print("  channels = [" .. table.concat(sentChannels, ", ") .. "]")
  print("  messages = " .. tostring(#sentMessages) .. " sent")
  for i, msg in ipairs(sentMessages) do
    print(string.format("    msg[%d] = %s", i, msg))
  end
  if not resultLine then
    print("  >> abort_reason = no_line")
  elseif sendOk == false then
    print("  >> abort_reason = send_failed")
  end
end

local function SimulateSharePipeline()
  RunPipelineScenario("1. happy_path: Bag-Scan liefert echten Link", {
    bagHasKey = true,
    inGroup = true,
    inInstance = true,
  })

  RunPipelineScenario("2. happy_path: kein API, Bag-Scan findet 180653", {
    bagHasKey = true,
    inGroup = true,
    inInstance = true,
  })

  RunPipelineScenario("3. plain-text-fallback: kein API, kein Key im Bag", {
    inGroup = true,
    inInstance = true,
  })

  RunPipelineScenario(
    "4. snapshot_missing: getOwnedKeystoneSnapshot=nil (keysync bag-scan-fallback abgefedert — siehe keysync tests)",
    {
      snapshotMissing = true,
      bagHasKey = true,
      inGroup = true,
      inInstance = true,
    }
  )

  RunPipelineScenario("5. not_in_group: solo, sollte PARTY channel resolven", {
    bagHasKey = true,
    inGroup = false,
    inInstance = false,
  })

  RunPipelineScenario("6. send_fails: SendChatMessage wirft, kein C_ChatInfo-Fallback", {
    bagHasKey = true,
    inGroup = true,
    inInstance = true,
    sendChatMessageFails = true,
  })

  RunPipelineScenario("7. send_fails_with_fallback: SendChatMessage wirft, C_ChatInfo greift", {
    bagHasKey = true,
    inGroup = true,
    inInstance = true,
    sendChatMessageFails = true,
    chatInfoFallbackOnly = true,
  })
end

local function SimulateShareKeysEventHandler()
  local counts = {
    keystoneChatShares = 0,
    cooldownTriggers = 0,
  }

  local addon = nil
  local controller = nil

  WithSyncGlobals(function()
    addon = Harness.LoadAddonModules({ "isiLive_sync.lua", "isiLive_event_handlers.lua" })
    controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      isMainFrameShown = function()
        return false
      end,
      processAddonMessage = function(prefix, message, sender, _localName, _localRealm, channel)
        return addon.Sync.ProcessAddonMessage(prefix, message, sender, "Me", "Realm", channel)
      end,
      sendOwnKeystoneToChat = function()
        counts.keystoneChatShares = counts.keystoneChatShares + 1
        return true
      end,
      triggerShareKeysCooldown = function()
        counts.cooldownTriggers = counts.cooldownTriggers + 1
      end,
    })

    controller:Dispatch("CHAT_MSG_ADDON", addon.Sync.GetPrefix(), "SHAREKEYS", "PARTY", "OtherPlayer-OtherRealm")
  end, {
    chatInfo = {
      SendAddonMessage = function()
        return true
      end,
    },
  })

  PrintTable("event.sharekeys.counts.", counts)
end

-- ============================================================================
-- Mode: roundtrip
--
-- End-to-end SHAREKEYS flow in a single shared global scope:
--   sender Sync.SendShareKeysRequest()
--     -> capture (prefix, message, channel) via mocked C_ChatInfo.SendAddonMessage
--     -> dispatch CHAT_MSG_ADDON with the captured bytes into a receiver
--        EventHandlers controller running the real Sync.ProcessAddonMessage
--     -> receiver sendOwnKeystoneToChat closure runs the real
--        ContextHelpers.BuildOwnKeystoneAnnounceLine + SendPartyChatMessage
--     -> capture chat bytes via mocked SendChatMessage
--
-- Pins the wire-level handoff (sender bytes equal receiver bytes), the
-- shouldShareKeys validity check, the channel resolution on both ends, and
-- the 30s self-cooldown.
-- ============================================================================

local function BuildRoundtripGlobals(opts)
  return {
    GetRealmName = function()
      return opts.realm or "Realm"
    end,
    GetTime = function()
      opts._timeCalls = (opts._timeCalls or 0) + 1
      return opts._now
    end,
    IsInGroup = function(category)
      if category == 2 then
        return opts.inInstance == true
      end
      return opts.inGroup ~= false
    end,
    IsInRaid = function()
      return opts.inRaid == true
    end,
    LE_PARTY_CATEGORY_INSTANCE = 2,
    strsplit = BuildStrsplit(),
    C_MythicPlus = {},
    C_Container = MakeBagApi(opts.bagHasKey == true),
    C_ChallengeMode = MakeChallengeModeApi(),
    SendChatMessage = function(message, channel)
      opts._chatMessages[#opts._chatMessages + 1] = message
      opts._chatChannels[#opts._chatChannels + 1] = channel
    end,
    C_ChatInfo = {
      SendAddonMessage = function(prefix, message, channel)
        opts._addonMessages[#opts._addonMessages + 1] = {
          prefix = prefix,
          message = message,
          channel = channel,
        }
        return true
      end,
    },
  }
end

local function BuildReceiverSendOwnKeystoneToChat(addon, opts, state)
  return function()
    state.sendOwnKeystoneCalls = state.sendOwnKeystoneCalls + 1
    local now = opts._now
    if state.lastKeystoneAt and (now - state.lastKeystoneAt) < 30 then
      state.cooldownAborts = state.cooldownAborts + 1
      return false
    end
    local line = addon.ContextHelpers.BuildOwnKeystoneAnnounceLine({
      getL = function()
        return { ANNOUNCE_PREFIX = "PartyKeys:" }
      end,
      getOwnedKeystoneSnapshot = function()
        return 2649, 12
      end,
      getDungeonShortCode = function(mapID)
        return mapID == 2649 and "ARA" or nil
      end,
    })
    if type(line) ~= "string" or line == "" then
      return false
    end
    local sent = addon.ContextHelpers.SendPartyChatMessage(line)
    if sent then
      state.lastKeystoneAt = now
    end
    return sent == true
  end
end

local function CheckExpectations(opts, sentBytes, state)
  local expected = opts.expect or {}
  local fails = {}
  if expected.wireChannel ~= nil then
    local actual = sentBytes and sentBytes.channel
    if actual ~= expected.wireChannel then
      fails[#fails + 1] =
        string.format("wireChannel=%s (expected %s)", tostring(actual), tostring(expected.wireChannel))
    end
  end
  if expected.wireMessage ~= nil then
    local actual = sentBytes and sentBytes.message
    if actual ~= expected.wireMessage then
      fails[#fails + 1] =
        string.format("wireMessage=%s (expected %s)", tostring(actual), tostring(expected.wireMessage))
    end
  end
  if expected.chatMessages ~= nil and #opts._chatMessages ~= expected.chatMessages then
    fails[#fails + 1] = string.format("chatMessages=%d (expected %d)", #opts._chatMessages, expected.chatMessages)
  end
  if expected.chatChannel ~= nil then
    local actual = opts._chatChannels[1]
    if actual ~= expected.chatChannel then
      fails[#fails + 1] =
        string.format("chatChannel=%s (expected %s)", tostring(actual), tostring(expected.chatChannel))
    end
  end
  if expected.sendOwnKeystoneCalls ~= nil and state.sendOwnKeystoneCalls ~= expected.sendOwnKeystoneCalls then
    fails[#fails + 1] =
      string.format("sendOwnKeystoneCalls=%d (expected %d)", state.sendOwnKeystoneCalls, expected.sendOwnKeystoneCalls)
  end
  if expected.cooldownAborts ~= nil and state.cooldownAborts ~= expected.cooldownAborts then
    fails[#fails + 1] = string.format("cooldownAborts=%d (expected %d)", state.cooldownAborts, expected.cooldownAborts)
  end
  return fails
end

local function RunRoundtripScenario(name, opts)
  opts._now = opts.now or 100
  opts._addonMessages = {}
  opts._chatMessages = {}
  opts._chatChannels = {}

  local senderSendOk
  local sentBytes
  local state = { sendOwnKeystoneCalls = 0, cooldownAborts = 0, lastKeystoneAt = 0 }

  Harness.WithGlobals(BuildRoundtripGlobals(opts), function()
    local addon = Harness.LoadAddonModules({
      "isiLive_context_helpers.lua",
      "isiLive_sync.lua",
      "isiLive_event_handlers.lua",
    })

    -- ====== SENDER side: simulate the "Keys teilen" button click ======
    -- The button onClick (ui/isiLive_roster_panel.lua:262) calls
    -- deps.sendShareKeysRequest, which is wired to Sync.SendShareKeysRequest.
    senderSendOk = addon.Sync.SendShareKeysRequest()
    sentBytes = opts._addonMessages[1]

    -- ====== RECEIVER side: dispatch the captured wire bytes ======
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      isMainFrameShown = function()
        return false
      end,
      processAddonMessage = function(prefix, message, sender, channel)
        return addon.Sync.ProcessAddonMessage(
          prefix,
          message,
          sender,
          opts.receiverName or "Me",
          opts.receiverRealm or "Realm",
          channel
        )
      end,
      sendOwnKeystoneToChat = BuildReceiverSendOwnKeystoneToChat(addon, opts, state),
      triggerShareKeysCooldown = function() end,
    })

    local function dispatch(prefixOverride, sender)
      if not sentBytes then
        return
      end
      controller:Dispatch(
        "CHAT_MSG_ADDON",
        prefixOverride or sentBytes.prefix,
        sentBytes.message,
        sentBytes.channel,
        sender or opts.senderName or "OtherPlayer-OtherRealm"
      )
    end

    if opts.dispatchWrongPrefix then
      dispatch("OTHER_ADDON", nil)
    elseif opts.dispatchSelfEcho then
      -- Sender uses the receiver's own player key, ProcessAddonMessage must
      -- short-circuit shouldShareKeys.
      dispatch(nil, (opts.receiverName or "Me") .. "-" .. (opts.receiverRealm or "Realm"))
    else
      dispatch(nil, nil)
      if opts.dispatchAgain then
        opts._now = opts._now + (opts.secondDelay or 5)
        dispatch(nil, nil)
      end
    end
  end)

  local fails = CheckExpectations(opts, sentBytes, state)
  print("---- " .. name)
  print("  sender.SendShareKeysRequest.ok = " .. tostring(senderSendOk))
  print("  wire.addonMessageCount         = " .. tostring(#opts._addonMessages))
  if sentBytes then
    print(
      "  wire.prefix / msg / channel    = "
        .. tostring(sentBytes.prefix)
        .. " / "
        .. tostring(sentBytes.message)
        .. " / "
        .. tostring(sentBytes.channel)
    )
  end
  print("  receiver.sendOwnKeystoneCalls  = " .. tostring(state.sendOwnKeystoneCalls))
  print("  receiver.cooldownAborts        = " .. tostring(state.cooldownAborts))
  print("  receiver.chatMessages          = " .. tostring(#opts._chatMessages))
  print("  receiver.chatChannels          = [" .. table.concat(opts._chatChannels, ", ") .. "]")
  if #fails == 0 then
    print("  >> PASS")
  else
    print("  >> FAIL: " .. table.concat(fails, "; "))
  end
  return #fails == 0
end

local function SimulateRoundtrip()
  local results = {}

  results[#results + 1] = RunRoundtripScenario("1. happy_in_instance: M+ key — wire & chat go INSTANCE_CHAT", {
    inGroup = true,
    inInstance = true,
    bagHasKey = true,
    expect = {
      wireChannel = "INSTANCE_CHAT",
      wireMessage = "SHAREKEYS",
      chatChannel = "INSTANCE_CHAT",
      chatMessages = 1,
      sendOwnKeystoneCalls = 1,
    },
  })

  results[#results + 1] = RunRoundtripScenario("2. happy_in_party: party (no instance) — wire & chat go PARTY", {
    inGroup = true,
    inInstance = false,
    bagHasKey = true,
    expect = {
      wireChannel = "PARTY",
      wireMessage = "SHAREKEYS",
      chatChannel = "PARTY",
      chatMessages = 1,
      sendOwnKeystoneCalls = 1,
    },
  })

  results[#results + 1] = RunRoundtripScenario("3. self_echo: sender == receiver, shouldShareKeys=false, no chat", {
    inGroup = true,
    inInstance = true,
    bagHasKey = true,
    receiverName = "Me",
    receiverRealm = "Realm",
    dispatchSelfEcho = true,
    expect = {
      wireChannel = "INSTANCE_CHAT",
      chatMessages = 0,
      sendOwnKeystoneCalls = 0,
    },
  })

  results[#results + 1] = RunRoundtripScenario("4. wrong_prefix: SHAREKEYS via 'OTHER_ADDON' prefix is dropped", {
    inGroup = true,
    inInstance = true,
    bagHasKey = true,
    dispatchWrongPrefix = true,
    expect = {
      wireChannel = "INSTANCE_CHAT",
      chatMessages = 0,
      sendOwnKeystoneCalls = 0,
    },
  })

  results[#results + 1] = RunRoundtripScenario("5. cooldown_re_trigger: 2x SHAREKEYS within 30s, only 1 chat sent", {
    inGroup = true,
    inInstance = true,
    bagHasKey = true,
    dispatchAgain = true,
    secondDelay = 5,
    expect = {
      wireChannel = "INSTANCE_CHAT",
      chatMessages = 1,
      sendOwnKeystoneCalls = 2,
      cooldownAborts = 1,
    },
  })

  results[#results + 1] = RunRoundtripScenario("6. cooldown_expired: 2nd SHAREKEYS after 35s succeeds", {
    inGroup = true,
    inInstance = true,
    bagHasKey = true,
    dispatchAgain = true,
    secondDelay = 35,
    expect = {
      wireChannel = "INSTANCE_CHAT",
      chatMessages = 2,
      sendOwnKeystoneCalls = 2,
      cooldownAborts = 0,
    },
  })

  local pass, fail = 0, 0
  for _, ok in ipairs(results) do
    if ok then
      pass = pass + 1
    else
      fail = fail + 1
    end
  end
  print(string.format("---- roundtrip summary: %d pass, %d fail", pass, fail))
  if fail > 0 then
    os.exit(1)
  end
end

local mode = tostring((...)) or "all"
if mode == "sharekeys" then
  SimulateShareKeys()
elseif mode == "key" then
  SimulateKey()
elseif mode == "stats" then
  SimulateStats()
elseif mode == "kick" then
  SimulateKick()
elseif mode == "event" then
  SimulateShareKeysEventHandler()
elseif mode == "share_pipeline" then
  SimulateSharePipeline()
elseif mode == "roundtrip" then
  SimulateRoundtrip()
else
  SimulateShareKeys()
  SimulateKey()
  SimulateStats()
  SimulateKick()
  SimulateShareKeysEventHandler()
  SimulateSharePipeline()
  SimulateRoundtrip()
end
