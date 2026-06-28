-- Standalone CLI tool: full end-to-end HELLO / ACK / REQSYNC handshake.
--
-- Background: when a peer joins the group, isiLive's first peer-discovery
-- exchange is a HELLO sync message. The receiving client must then fan out
-- a multi-message bootstrap response so the joining peer learns the full
-- state of every existing group member without waiting for the next
-- periodic refresh.
--
-- Production fan-out, triggered by Sync.ProcessAddonMessage returning
-- shouldAck=true (initial HELLO from a non-self sender; HELLOs with source
-- hello-ack/reqsync-ack are themselves fan-out replies and are loop-broken,
-- see RULE-SYNC-HELLO-ACK-LOOP-BREAKER) — see
-- logic/isiLive_event_handlers_runtime.lua:554-561:
--
--   ctx.sendAck(syncResult.sender)             -- 1 ACK WHISPER
--   ctx.sendIsiLiveHello(true, "hello-ack")    -- 1 HELLO (force, source=hello-ack)
--   ctx.sendRefreshResponse()                  -- 4 broadcasts: KEY+STATS+DPS+LOC
--   ctx.sendOwnTargetSnapshot(true, "hello", true)  -- 1 TARGET
--   ctx.sendOwnKickState()                     -- 1 KICK
--   = 1 + 1 + 4 + 1 + 1 = 8 messages out (7 to the group channel,
--                                          1 ACK to the sender as WHISPER)
--
-- The same fan-out is triggered by REQSYNC (shouldRequestRefresh=true), per
-- event_handlers_runtime.lua:562-567 — same 4-call block plus
-- sendIsiLiveHello/source="reqsync-ack" instead of "hello-ack".
--
-- Self-echo: A's own HELLO arriving back at A must NOT trigger the fan-out
-- (Sync.ProcessAddonMessage's senderKey ~= selfKey guard); same for REQSYNC.
--
-- This simulator drives that complete chain:
--   1. Sender A: real Sync.SendHello -> captured wire bytes
--   2. Dispatcher: real EventHandlers controller:Dispatch("CHAT_MSG_ADDON", ...)
--   3. Receiver Sync layer: real Sync.ProcessAddonMessage -> shouldAck flag
--   4. Receiver runtime fan-out: real ctx.sendAck / sendIsiLiveHello /
--      sendRefreshResponse / sendOwnTargetSnapshot / sendOwnKickState
--   5. Each sub-send produces real Sync.Send* wire bytes captured at the
--      mocked C_ChatInfo.SendAddonMessage layer.
--
-- End-to-end discipline (CLAUDE.md "Tests & simulators: end-to-end by default"):
-- every layer in the fan-out is the production module:
--   * Sync (real)                — wire format + ProcessAddonMessage
--   * KeySync.CreateController   — provides SendIsiLiveHello + SendRefreshResponse
--   * factory_controllers via FI.InitializeFactoryRuntimeHelpers(ctx)
--                                — provides ctx.SendOwnTargetSnapshot
--   * FactorySecondaryKickTracker — provides ctx.SendOwnKickState
--   * EventHandlers controller   — runtime dispatcher
--   * controller_wiring.sendAck  — inlined in test (~5 lines verbatim from
--     factory/isiLive_controller_wiring.lua:386-390 — too small to extract,
--     too coupled to ctx-builder to stand up via the production wiring path).
--
-- COMPONENT-ONLY exception (justified): the kickTrackerController returned
-- by KickTracker.CreateController needs a fully resolved player class +
-- spec + spell base CD setup to report availabilityResolved=true. Setting
-- that up via real GetSpecialization / GetSpellBaseCooldown / etc. globals
-- is covered in detail by simulate_kick_tracker_extras.lua. Here we
-- replace ctx.kickTrackerController.GetKickInfo with a stable test stub
-- that returns a valid Tank-with-CD state so the production SyncOwnKickState
-- path can run end-to-end and emit the real KICK wire bytes.
---@diagnostic disable: undefined-global
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

local failures = 0

local function Check(condition, message)
  if condition then
    print("  [CHECK PASS] " .. message)
    return
  end
  failures = failures + 1
  print("  [CHECK FAIL] " .. message)
end

local function StrSplitStub(sep, str, max)
  local pos = str:find(sep, 1, true)
  if not pos then
    return str
  end
  if max and max >= 2 then
    return str:sub(1, pos - 1), str:sub(pos + 1)
  end
  return str:sub(1, pos - 1)
end

-- ----------------------------------------------------------------------
-- WoW-globals model. The captured-bytes lists let scenarios assert which
-- production sub-sends fired during the fan-out.
-- ----------------------------------------------------------------------
local model = {
  now = 1000,
  selfName = "Me",
  selfRealm = "Realm",
  groupBroadcasts = {}, -- list of { prefix, payload, channel } from C_ChatInfo.SendAddonMessage (no target arg)
  whisperBroadcasts = {}, -- list of { prefix, payload, target } from C_ChatInfo.SendAddonMessage with WHISPER target
}

local function ResetModel()
  model.now = 1000
  model.selfName = "Me"
  model.selfRealm = "Realm"
  model.groupBroadcasts = {}
  model.whisperBroadcasts = {}
end

local function buildGlobals()
  return {
    GetTime = function()
      return model.now
    end,
    GetRealmName = function()
      return model.selfRealm
    end,
    UnitName = function()
      return model.selfName, model.selfRealm
    end,
    IsInGroup = function()
      return true
    end,
    IsInRaid = function()
      return false
    end,
    LE_PARTY_CATEGORY_INSTANCE = 2,
    strsplit = StrSplitStub,
    IsiLiveDB = { syncEnabled = true },
    C_ChatInfo = {
      RegisterAddonMessagePrefix = function()
        return true
      end,
      SendAddonMessage = function(prefix, payload, channel, target)
        if channel == "WHISPER" then
          model.whisperBroadcasts[#model.whisperBroadcasts + 1] = {
            prefix = prefix,
            payload = payload,
            target = target,
          }
        else
          model.groupBroadcasts[#model.groupBroadcasts + 1] = {
            prefix = prefix,
            payload = payload,
            channel = channel,
          }
        end
        return true
      end,
    },
    -- KickTracker module needs UnitClass / GetSpecialization / GetSpellBaseCooldown
    -- to resolve a watched-spell. The COMPONENT-ONLY exception in the header
    -- explains why we override kickTrackerController.GetKickInfo instead.
    UnitClass = function()
      return "Paladin", "PALADIN"
    end,
    GetSpecialization = function()
      return nil
    end,
    GetSpecializationInfo = function()
      return nil
    end,
    GetSpellBaseCooldown = function()
      return nil
    end,
  }
end

-- Build a session: load all production modules, wire ctx end-to-end via
-- KeySync + InitializeFactoryRuntimeHelpers + InitializeFactorySecondaryKickTracker,
-- and return the EventHandlers controller plus access to capture buffers.
local function BuildSession()
  ResetModel()
  local addon
  Harness.WithGlobals(buildGlobals(), function()
    addon = Harness.LoadAddonModules({
      "isiLive_runtime_state.lua",
      "isiLive_units.lua",
      "isiLive_lfg_detect.lua",
      "isiLive_status.lua",
      "isiLive_kick_tracker.lua",
      "isiLive_sync.lua",
      "isiLive_keysync.lua",
      "isiLive_factory_controllers.lua",
      "isiLive_factory_kick_tracker.lua",
      "isiLive_event_handlers.lua",
    })
  end)

  -- Real RuntimeState + minimal modules table.
  local runtimeState = addon.RuntimeState.CreateController({})
  local modules = {
    sync = addon.Sync,
    teleport = {
      GetTeleportInfoByMapID = function(mapID)
        if mapID == 559 then
          return { mapName = "Nexus-Point Xenas" }
        end
        return nil
      end,
    },
    queue = {
      GetActivityName = function()
        return nil
      end,
    },
  }

  -- Build a real KeySync controller (provides SendIsiLiveHello +
  -- SendRefreshResponse closures with full production behaviour).
  local keySyncController
  Harness.WithGlobals(buildGlobals(), function()
    keySyncController = addon.KeySync.CreateController({
      sync = addon.Sync,
      getUnitNameAndRealm = function(unit)
        if unit == "player" then
          return model.selfName, model.selfRealm
        end
        return nil, nil
      end,
      getAddonVersionRaw = function()
        return "0.9.250"
      end,
      getUnitRio = function()
        return nil
      end,
      isFrameVisible = function()
        return false
      end,
      canRespondToRefreshRequest = function()
        return true
      end,
    })
  end)

  -- Build the ctx the factory_controllers helpers expect.
  local ctx = {
    addonTable = addon,
    modules = modules,
    runtimeState = runtimeState,
    locale = "enUS",
    L = {
      UNKNOWN_GROUP = "unknown",
      CHAT_QUEUE_PREFIX = "ISI-Q",
      JOINED_FROM_QUEUE = "joined %s",
    },
    GetRoster = function()
      return {}
    end,
    IsPlayerLeader = function()
      return false
    end,
    Print = function() end,
    UpdateStatusLine = function() end,
    ResolveMapIDByActivityID = function()
      return nil
    end,
    keySyncController = keySyncController,
    -- Wire the production hello / refresh-response closures from KeySync into ctx.
    SendIsiLiveHello = keySyncController.SendIsiLiveHello,
    SendRefreshResponse = keySyncController.SendRefreshResponse,
    SendRefreshRequest = keySyncController.SendRefreshRequest,
    mainFrame = nil, -- isFrameVisible() returns false either way
    rosterPanelController = nil,
  }
  ctx.GetL = function()
    return ctx.L
  end

  -- Initialize the factory runtime helpers — this is what attaches
  -- ctx.SendOwnTargetSnapshot, ctx.ResolveLocalStatusTargetMapID, etc.
  Harness.WithGlobals(buildGlobals(), function()
    addon._FactoryInternal.InitializeFactoryRuntimeHelpers(ctx)
  end)

  -- ResolveActiveKeyOwnerUnit lives outside InitializeFactoryRuntimeHelpers
  -- (needs highlightController in production). Stub for the test.
  ctx.ResolveActiveKeyOwnerUnit = function()
    return nil
  end
  -- KeySync controller exposes ResolveActiveKeyOwnerUnit too — set to nil so
  -- ctx.SendOwnTargetSnapshot's branch finds no roster owner and the
  -- LFG-title-hint branch wins (or yields nil level, which is fine for the
  -- wire-emission assertion).
  if keySyncController.ResolveActiveKeyOwnerUnit then
    keySyncController.ResolveActiveKeyOwnerUnit = function()
      return nil
    end
  end

  -- Initialize factory_kick_tracker — attaches ctx.SendOwnKickState.
  Harness.WithGlobals(buildGlobals(), function()
    addon._FactoryInternal.InitializeFactorySecondaryKickTracker(
      ctx,
      modules,
      function()
        return model.now
      end,
      function(unit)
        if unit == "player" then
          return model.selfName
        end
        return nil
      end,
      function()
        return model.selfRealm
      end,
      function()
        return false
      end,
      function()
        return false
      end, -- IsRaidModeActive
      function()
        return IsInGroup() == true
      end -- IsGroupSyncActive
    )
  end)

  -- Override kickTrackerController.GetKickInfo with a stable stub so
  -- SyncOwnKickState's `availabilityResolved == true` gate passes and the
  -- production Sync.SendKick branch fires. See COMPONENT-ONLY note in header.
  if ctx.kickTrackerController then
    ctx.kickTrackerController.GetKickInfo = function()
      return {
        spellID = 96231, -- Rebuke (Prot Pala)
        hasKick = true,
        availabilityResolved = true,
        onCooldown = true,
        cooldownRemain = 12,
        extras = nil,
      }
    end
  end

  -- Build the EventHandlers controller via the test fixture; override the
  -- HELLO fan-out callbacks to point at the real ctx-attached production
  -- closures we set up above.
  local controller
  Harness.WithGlobals(buildGlobals(), function()
    controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      isMainFrameShown = function()
        return false
      end,
      processAddonMessage = function(prefix, message, sender, channel)
        return addon.Sync.ProcessAddonMessage(prefix, message, sender, model.selfName, model.selfRealm, channel)
      end,
      sendAck = function(sender)
        -- Verbatim from factory/isiLive_controller_wiring.lua:386-390 — see
        -- COMPONENT-ONLY note in header.
        if type(sender) == "string" and sender ~= "" then
          rawget(_G, "C_ChatInfo").SendAddonMessage(addon.Sync.GetPrefix(), "ACK:0.9.250", "WHISPER", sender)
        end
      end,
      sendIsiLiveHello = function(force, source)
        ctx.SendIsiLiveHello(force, source)
      end,
      sendRefreshResponse = function()
        return ctx.SendRefreshResponse()
      end,
      sendOwnTargetSnapshot = function(force, source, allowHidden)
        ctx.SendOwnTargetSnapshot(force, source, allowHidden)
      end,
      sendOwnKickState = function()
        return ctx.SendOwnKickState(true)
      end,
    })
  end)

  return {
    addon = addon,
    ctx = ctx,
    controller = controller,
    captureSenderHello = function(source)
      local before = #model.groupBroadcasts
      Harness.WithGlobals(buildGlobals(), function()
        addon.Sync.SendHello({
          version = "0.9.250",
          protocolVersion = 2,
          capturedAt = 1000,
          source = source or "hello",
          force = true,
          isVisible = false,
          allowHidden = true,
        })
      end)
      if #model.groupBroadcasts > before then
        return model.groupBroadcasts[#model.groupBroadcasts]
      end
      return nil
    end,
    dispatchOnReceiver = function(prefix, message, channel, sender)
      Harness.WithGlobals(buildGlobals(), function()
        controller:Dispatch("CHAT_MSG_ADDON", prefix, message, channel, sender)
      end)
    end,
  }
end

-- Helpers to summarize the captured wire bytes by type.
local function CountByMessageType(broadcasts, marker)
  local n = 0
  for _, msg in ipairs(broadcasts) do
    if type(msg.payload) == "string" and msg.payload:find(marker, 1, true) then
      n = n + 1
    end
  end
  return n
end

local function FindByMessageType(broadcasts, marker)
  for i, msg in ipairs(broadcasts) do
    if type(msg.payload) == "string" and msg.payload:find(marker, 1, true) then
      return i, msg
    end
  end
  return nil, nil
end

-- ----------------------------------------------------------------------
-- Phase 1: HELLO from a remote peer triggers the full 8-message fan-out
-- (1 ACK whisper + 7 group broadcasts: HELLO + KEY + STATS + DPS + LOC +
-- TARGET + KICK).
-- ----------------------------------------------------------------------
local function ScenarioHelloTriggersFanOut()
  print("\n========== Scenario 1: HELLO from peer -> 8-message fan-out ==========")
  local session = BuildSession()

  -- Capture A's HELLO bytes via real Sync.SendHello, then dispatch them
  -- into B's receiver (B = self = "Me-Realm").
  local senderHello = session.captureSenderHello("hello")
  Check(senderHello ~= nil, "sender produced HELLO wire bytes via Sync.SendHello")
  Check(senderHello and senderHello.payload:find("HELLO:", 1, true) == 1, "sender HELLO payload starts with 'HELLO:'")

  -- Reset capture buffers so we measure only the FAN-OUT, not the sender
  -- preamble.
  model.groupBroadcasts = {}
  model.whisperBroadcasts = {}

  -- Dispatch A's bytes into B as if from "Peer-OtherRealm".
  session.dispatchOnReceiver("ISILIVE", senderHello.payload, "PARTY", "Peer-OtherRealm")

  -- Whisper-channel: exactly one ACK to the sender.
  Check(#model.whisperBroadcasts == 1, "ACK whisper sent exactly once")
  Check(
    model.whisperBroadcasts[1] and model.whisperBroadcasts[1].payload:find("ACK:", 1, true) == 1,
    "ACK payload starts with 'ACK:'"
  )
  Check(model.whisperBroadcasts[1].target == "Peer-OtherRealm", "ACK whispered TO the original sender")

  -- Group-channel: 7 broadcasts total — HELLO + KEY + STATS + DPS + LOC + TARGET + KICK.
  Check(#model.groupBroadcasts == 7, string.format("7 group broadcasts emitted (got %d)", #model.groupBroadcasts))
  Check(CountByMessageType(model.groupBroadcasts, "HELLO:") == 1, "fan-out emits 1 HELLO (the hello-ack)")
  Check(CountByMessageType(model.groupBroadcasts, "KEY:") == 1, "fan-out emits 1 KEY (from sendRefreshResponse)")
  Check(CountByMessageType(model.groupBroadcasts, "STATS:") == 1, "fan-out emits 1 STATS (from sendRefreshResponse)")
  Check(CountByMessageType(model.groupBroadcasts, "DPS:") == 1, "fan-out emits 1 DPS (from sendRefreshResponse)")
  Check(CountByMessageType(model.groupBroadcasts, "LOC:") == 1, "fan-out emits 1 LOC (from sendRefreshResponse)")
  Check(
    CountByMessageType(model.groupBroadcasts, "TARGET:") == 1,
    "fan-out emits 1 TARGET (from sendOwnTargetSnapshot)"
  )
  Check(CountByMessageType(model.groupBroadcasts, "KICK:") == 1, "fan-out emits 1 KICK (from sendOwnKickState)")
end

-- ----------------------------------------------------------------------
-- Phase 2: HELLO source=hello-ack arrives. The fan-out hello is itself an
-- ack reply; acking it again would make two peers answer each other's
-- hello-acks forever (the fan-out hello is force-sent past the 8 s rate
-- limit), flood the ChatThrottleLib send queue, and reflect mirrored SKCD
-- locks between the peers indefinitely. ProcessAddonMessage therefore
-- drops shouldAck for hello-ack/reqsync-ack sources
-- (RULE-SYNC-HELLO-ACK-LOOP-BREAKER). The join bootstrap stays intact:
-- the joiner broadcasts its own snapshot and a delayed REQSYNC itself.
-- ----------------------------------------------------------------------
local function ScenarioHelloAckDoesNotTrigger()
  print("\n========== Scenario 2: HELLO with source=hello-ack -> NO fan-out (loop breaker) ==========")
  local session = BuildSession()
  local hello = session.captureSenderHello("hello-ack")
  model.groupBroadcasts = {}
  model.whisperBroadcasts = {}

  session.dispatchOnReceiver("ISILIVE", hello.payload, "PARTY", "Peer-OtherRealm")
  Check(#model.whisperBroadcasts == 0, "hello-ack must not produce an ACK whisper")
  Check(#model.groupBroadcasts == 0, "hello-ack must not trigger another fan-out (no ack ping-pong)")

  local reqsyncAckHello = session.captureSenderHello("reqsync-ack")
  model.groupBroadcasts = {}
  model.whisperBroadcasts = {}

  session.dispatchOnReceiver("ISILIVE", reqsyncAckHello.payload, "PARTY", "Peer-OtherRealm")
  Check(#model.whisperBroadcasts == 0, "reqsync-ack hello must not produce an ACK whisper")
  Check(#model.groupBroadcasts == 0, "reqsync-ack hello must not trigger another fan-out")
end

-- ----------------------------------------------------------------------
-- Phase 3: self-echo guard. A's own HELLO arriving back at A must NOT
-- trigger the fan-out (Sync.ProcessAddonMessage's senderKey ~= selfKey).
-- ----------------------------------------------------------------------
local function ScenarioSelfEchoSuppressed()
  print("\n========== Scenario 3: self-echo HELLO -> NO fan-out ==========")
  local session = BuildSession()
  local hello = session.captureSenderHello("hello")
  model.groupBroadcasts = {}
  model.whisperBroadcasts = {}

  -- Sender == self ("Me-Realm").
  session.dispatchOnReceiver("ISILIVE", hello.payload, "PARTY", model.selfName .. "-" .. model.selfRealm)
  Check(#model.whisperBroadcasts == 0, "self-echo: no ACK whisper")
  Check(#model.groupBroadcasts == 0, "self-echo: no group fan-out (senderKey == selfKey guard)")
end

-- ----------------------------------------------------------------------
-- Phase 4: REQSYNC twin-path. Production's HandleChatMsgAddonEvent fires
-- the same fan-out block on shouldRequestRefresh=true (event_handlers_runtime
-- lines 562-567). The only difference is sendIsiLiveHello source="reqsync-ack".
-- ----------------------------------------------------------------------
local function ScenarioReqSyncTwinPath()
  print("\n========== Scenario 4: REQSYNC twin-path -> same fan-out shape ==========")
  local session = BuildSession()
  -- REQSYNC is a literal, no SendREQSYNC helper exists in production.
  model.groupBroadcasts = {}
  model.whisperBroadcasts = {}

  session.dispatchOnReceiver("ISILIVE", "REQSYNC", "PARTY", "Peer-OtherRealm")
  -- REQSYNC does NOT go through the shouldAck branch (no whisper ACK), but
  -- shouldRequestRefresh fires the same hello + refresh + target + kick block.
  Check(#model.whisperBroadcasts == 0, "REQSYNC: no ACK whisper (shouldAck path is HELLO-only)")
  Check(#model.groupBroadcasts == 7, "REQSYNC: same 7-message fan-out as HELLO")
  Check(CountByMessageType(model.groupBroadcasts, "HELLO:") == 1, "REQSYNC fan-out emits 1 HELLO (the reqsync-ack)")
  Check(CountByMessageType(model.groupBroadcasts, "KICK:") == 1, "REQSYNC fan-out emits 1 KICK")
end

-- ----------------------------------------------------------------------
-- Phase 5: REQSYNC self-echo. A sending REQSYNC to itself (e.g. own
-- broadcast wraps back via INSTANCE_CHAT) must NOT fan-out.
-- ----------------------------------------------------------------------
local function ScenarioReqSyncSelfEchoSuppressed()
  print("\n========== Scenario 5: REQSYNC self-echo -> NO fan-out ==========")
  local session = BuildSession()
  model.groupBroadcasts = {}
  model.whisperBroadcasts = {}

  session.dispatchOnReceiver("ISILIVE", "REQSYNC", "PARTY", model.selfName .. "-" .. model.selfRealm)
  Check(#model.groupBroadcasts == 0, "REQSYNC self-echo: no fan-out (senderKey == selfKey guard)")
end

-- ----------------------------------------------------------------------
-- Phase 6: source=hello-ack on the OUTGOING HELLO (the one inside the
-- fan-out). Pin that the production hello-ack carries the right source
-- string so peers can distinguish "first hello" from "ack-hello".
-- ----------------------------------------------------------------------
local function ScenarioHelloAckSourceString()
  print("\n========== Scenario 6: outgoing hello-ack carries source='hello-ack' ==========")
  local session = BuildSession()
  local senderHello = session.captureSenderHello("hello")
  model.groupBroadcasts = {}
  model.whisperBroadcasts = {}

  session.dispatchOnReceiver("ISILIVE", senderHello.payload, "PARTY", "Peer-OtherRealm")
  local _, helloMsg = FindByMessageType(model.groupBroadcasts, "HELLO:")
  Check(helloMsg ~= nil, "fan-out HELLO is present")
  -- Wire format: HELLO:<version>:<protocol>:<capturedAt>:<source>
  Check(
    helloMsg and helloMsg.payload:find("hello-ack", 1, true) ~= nil,
    "outgoing fan-out HELLO carries source=hello-ack (peers can distinguish from initial hello)"
  )
end

ScenarioHelloTriggersFanOut()
ScenarioHelloAckDoesNotTrigger()
ScenarioSelfEchoSuppressed()
ScenarioReqSyncTwinPath()
ScenarioReqSyncSelfEchoSuppressed()
ScenarioHelloAckSourceString()

if failures > 0 then
  print(string.format("\nHELLO handshake simulator failed: %d check(s) failed", failures))
  os.exit(1)
end

print("\nHELLO handshake simulator passed.")
