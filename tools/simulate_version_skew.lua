-- Standalone CLI tool: HELLO version-skew end-to-end simulator.
--
-- Background: when 1.0 ships, hundreds of users will still be on
-- 0.9.180-0.9.215 for weeks. The HELLO/ACK wire format must absorb peer
-- versions both older and newer than self, including:
--   * old peer with HELLO format we still understand
--   * future peer with extra trailing fields (forward-compat)
--   * peer that bumps protocolVersion past ours (currently 2)
--   * peer with malformed HELLO (truncated, garbage version)
--   * ACK without protocolVersion (HELLO/ACK asymmetry)
--
-- This simulator pins the HELLO-parsing tolerance and the per-peer state
-- write under each variant. A regression that throws on a stray ":" in
-- HELLO bytes (e.g., a future "HELLO:1.0.0:3:1234:hello:newfield"), or
-- one that crashes on a peer with no protocolVersion, would surface here
-- before any user sees a stack trace.
--
-- HELLO wire format (logic/isiLive_sync.lua:1081-1087):
--   HELLO:<version>:<protocolVersion>:<capturedAt>:<source>
--
-- ACK wire format (factory/isiLive_controller_wiring.lua):
--   ACK:<version>
--
-- ProcessAddonMessage extracts via SplitPayload (colon-split, no length
-- check on field count), so we test what happens when fields are added,
-- removed, or have non-numeric content.
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

local function BuildBaseGlobals(now)
  return {
    GetTime = function()
      return now or 1000
    end,
    GetRealmName = function()
      return "Realm"
    end,
    UnitName = function()
      return "Me", "Realm"
    end,
    IsInGroup = function()
      return true
    end,
    IsInRaid = function()
      return false
    end,
    LE_PARTY_CATEGORY_INSTANCE = 2,
    strsplit = StrSplitStub,
    C_ChatInfo = {
      RegisterAddonMessagePrefix = function()
        return true
      end,
      SendAddonMessage = function()
        return true
      end,
    },
  }
end

-- ----------------------------------------------------------------------
-- Phase A: ProcessAddonMessage tolerates HELLO across versions.
-- Drive a fresh Sync instance and dispatch each HELLO variant; check
-- shouldAck, peerAddonVersion, peerProtocolVersion, and the stored
-- helloInfo state. A throw or nil-result on any variant would FAIL.
-- ----------------------------------------------------------------------
local function ScenarioHelloVersionVariants()
  print("\n========== Phase A: HELLO version-skew variants ==========")

  local cases = {
    {
      label = "old peer 0.9.180 (current format, lower version)",
      payload = "HELLO:0.9.180:2:1000:hello",
      expectVersion = "0.9.180",
      expectProtocol = 2,
      expectAck = true,
    },
    {
      label = "current peer 0.9.217 (matches self)",
      payload = "HELLO:0.9.217:2:1000:hello",
      expectVersion = "0.9.217",
      expectProtocol = 2,
      expectAck = true,
    },
    {
      label = "future peer 1.0.0 with same protocol 2",
      payload = "HELLO:1.0.0:2:1000:hello",
      expectVersion = "1.0.0",
      expectProtocol = 2,
      expectAck = true,
    },
    {
      label = "future peer 1.1.0 with bumped protocol 3 (forward-compat)",
      payload = "HELLO:1.1.0:3:1000:hello",
      expectVersion = "1.1.0",
      expectProtocol = 3,
      expectAck = true,
    },
    {
      label = "future peer with extra trailing fields (forward-compat — extras ignored)",
      payload = "HELLO:1.2.0:3:1000:hello:newfield:another",
      expectVersion = "1.2.0",
      expectProtocol = 3,
      expectAck = true,
    },
    {
      label = "very old peer with no protocol field (pre-protocol HELLO format)",
      payload = "HELLO:0.9.50",
      expectVersion = "0.9.50",
      -- protocol will be NormalizeSyncProtocolVersion(nil) -> falls back
      -- to ISILIVE_SYNC_PROTOCOL_VERSION (2) at the SetPlayerHelloInfo
      -- write site. ProcessAddonMessage's local peerProtocolVersion is
      -- tonumber(parts[3]) which is nil for missing field — that's the
      -- field returned to callers. We pin both: result.peerProtocolVersion
      -- = nil, but stored helloInfo.protocolVersion = 2 (the fallback).
      expectProtocol = nil,
      expectStoredProtocol = 2,
      expectAck = true,
    },
    {
      label = "peer with garbage protocol field 'abc' — tonumber returns nil",
      payload = "HELLO:0.9.200:abc:1000:hello",
      expectVersion = "0.9.200",
      expectProtocol = nil,
      expectStoredProtocol = 2,
      expectAck = true,
    },
    {
      -- Empty fields retain their positions; a missing version never
      -- establishes trust or stores shifted protocol/timestamp metadata.
      label = "peer with empty version field is rejected without shifting fields",
      payload = "HELLO::2:1000:hello",
      expectVersion = nil,
      expectProtocol = nil,
      expectStored = false,
      expectAck = false,
    },
  }

  for _, c in ipairs(cases) do
    print("  -- " .. c.label)
    local addon
    local result
    Harness.WithGlobals(BuildBaseGlobals(1000), function()
      addon = Harness.LoadAddonModules({ "isiLive_sync.lua" })
      result = addon.Sync.ProcessAddonMessage("ISILIVE", c.payload, "Peer-OtherRealm", "Me", "Realm", "PARTY")
    end)
    Check(result ~= nil, "    ProcessAddonMessage returned a result (no throw / no nil)")
    if result then
      Check(
        result.shouldAck == c.expectAck,
        string.format("    shouldAck=%s (expected %s)", tostring(result.shouldAck), tostring(c.expectAck))
      )
      Check(
        result.peerAddonVersion == c.expectVersion,
        string.format(
          "    peerAddonVersion=%q (expected %q)",
          tostring(result.peerAddonVersion),
          tostring(c.expectVersion)
        )
      )
      Check(
        result.peerProtocolVersion == c.expectProtocol,
        string.format(
          "    peerProtocolVersion=%s (expected %s)",
          tostring(result.peerProtocolVersion),
          tostring(c.expectProtocol)
        )
      )
      -- Verify stored state.
      local stored = addon.Sync.GetPlayerHelloInfo("Peer", "OtherRealm")
      Check((stored ~= nil) == (c.expectStored ~= false), "    helloInfo storage matches payload validity")
      if c.expectStored == false then
        Check(not addon.Sync.IsUserKnown("Peer", "OtherRealm"), "    invalid HELLO never establishes peer trust")
      end
      if stored then
        Check(
          stored.addonVersion == c.expectVersion,
          string.format("    stored.addonVersion=%q", tostring(stored.addonVersion))
        )
        local expectedStoredProtocol = c.expectStoredProtocol or c.expectProtocol
        Check(
          stored.protocolVersion == expectedStoredProtocol,
          string.format(
            "    stored.protocolVersion=%s (expected %s)",
            tostring(stored.protocolVersion),
            tostring(expectedStoredProtocol)
          )
        )
      end
    end
  end
end

-- ----------------------------------------------------------------------
-- Phase B: ACK twin path. ACK:<version> stores addon version only,
-- protocolVersion stays nil (HELLO/ACK asymmetry). Pin both the result
-- field AND the persisted state.
-- ----------------------------------------------------------------------
local function ScenarioAckVersionVariants()
  print("\n========== Phase B: ACK version-skew variants ==========")

  local cases = {
    {
      label = "ACK from 0.9.180 (lower)",
      payload = "ACK:0.9.180",
      expectVersion = "0.9.180",
    },
    {
      label = "ACK from 1.0.0 (future)",
      payload = "ACK:1.0.0",
      expectVersion = "1.0.0",
    },
    {
      label = "ACK with extra trailing field (forward-compat)",
      payload = "ACK:1.1.0:newfield",
      expectVersion = "1.1.0",
    },
    {
      -- The empty version stays empty and cannot create a stored ACK entry.
      label = "ACK with empty version retains its empty field without storing an entry",
      payload = "ACK:",
      expectVersion = "",
      expectStored = false,
    },
  }

  for _, c in ipairs(cases) do
    print("  -- " .. c.label)
    local addon
    local result
    Harness.WithGlobals(BuildBaseGlobals(1000), function()
      addon = Harness.LoadAddonModules({ "isiLive_sync.lua" })
      result = addon.Sync.ProcessAddonMessage("ISILIVE", c.payload, "Peer-OtherRealm", "Me", "Realm", "PARTY")
    end)
    Check(result ~= nil, "    ProcessAddonMessage returned a result")
    if result then
      Check(result.shouldAck == false, "    ACK does not trigger shouldAck (HELLO-only)")
      Check(
        result.peerAddonVersion == c.expectVersion,
        string.format(
          "    peerAddonVersion=%q (expected %q)",
          tostring(result.peerAddonVersion),
          tostring(c.expectVersion)
        )
      )
      Check(result.peerProtocolVersion == nil, "    peerProtocolVersion=nil for ACK (HELLO/ACK asymmetry)")
      local stored = addon.Sync.GetPlayerHelloInfo("Peer", "OtherRealm")
      if c.expectStored == false then
        Check(stored == nil, "    no helloInfo stored for empty ACK")
      else
        Check(stored ~= nil, "    helloInfo stored for ACK")
        if stored then
          Check(
            stored.addonVersion == c.expectVersion,
            string.format("    stored.addonVersion=%q", tostring(stored.addonVersion))
          )
          Check(stored.source == "ack", "    stored.source=ack (not hello)")
        end
      end
    end
  end
end

-- ----------------------------------------------------------------------
-- Phase C: mixed-version group state. Three peers send HELLOs at three
-- different versions/protocols; the receiver tracks all three independently
-- via NormalizePlayerKey. Pin that no peer's state overwrites another.
-- ----------------------------------------------------------------------
local function ScenarioMixedVersionGroup()
  print("\n========== Phase C: mixed-version group — no state overwrite ==========")

  local addon
  Harness.WithGlobals(BuildBaseGlobals(1000), function()
    addon = Harness.LoadAddonModules({ "isiLive_sync.lua" })

    addon.Sync.ProcessAddonMessage("ISILIVE", "HELLO:0.9.180:2:1000:hello", "OldPeer-RealmX", "Me", "Realm", "PARTY")
    addon.Sync.ProcessAddonMessage("ISILIVE", "HELLO:0.9.216:2:1100:hello", "MidPeer-RealmY", "Me", "Realm", "PARTY")
    addon.Sync.ProcessAddonMessage("ISILIVE", "HELLO:1.1.0:3:1200:hello", "NewPeer-RealmZ", "Me", "Realm", "PARTY")
  end)

  local oldPeer = addon.Sync.GetPlayerHelloInfo("OldPeer", "RealmX")
  local midPeer = addon.Sync.GetPlayerHelloInfo("MidPeer", "RealmY")
  local newPeer = addon.Sync.GetPlayerHelloInfo("NewPeer", "RealmZ")

  Check(oldPeer ~= nil and oldPeer.addonVersion == "0.9.180", "OldPeer addonVersion=0.9.180")
  Check(midPeer ~= nil and midPeer.addonVersion == "0.9.216", "MidPeer addonVersion=0.9.216")
  Check(newPeer ~= nil and newPeer.addonVersion == "1.1.0", "NewPeer addonVersion=1.1.0")
  Check(oldPeer and oldPeer.protocolVersion == 2, "OldPeer protocolVersion=2")
  Check(midPeer and midPeer.protocolVersion == 2, "MidPeer protocolVersion=2")
  Check(newPeer and newPeer.protocolVersion == 3, "NewPeer protocolVersion=3 (future bump preserved)")
  Check(oldPeer and oldPeer.capturedAt == 1000, "OldPeer capturedAt=1000")
  Check(midPeer and midPeer.capturedAt == 1100, "MidPeer capturedAt=1100")
  Check(newPeer and newPeer.capturedAt == 1200, "NewPeer capturedAt=1200")
end

-- ----------------------------------------------------------------------
-- Phase D: HELLO updates in-place when peer re-broadcasts (e.g. version
-- bump after /reload). Pin that the second HELLO with a NEWER version
-- replaces the stored version, not appends a new entry under a different
-- key. Same realm, same name, version goes 0.9.180 -> 0.9.216.
-- ----------------------------------------------------------------------
local function ScenarioPeerVersionBumpInPlace()
  print("\n========== Phase D: peer version bump replaces stored state ==========")

  local addon
  Harness.WithGlobals(BuildBaseGlobals(1000), function()
    addon = Harness.LoadAddonModules({ "isiLive_sync.lua" })
    addon.Sync.ProcessAddonMessage("ISILIVE", "HELLO:0.9.180:2:1000:hello", "Peer-RealmA", "Me", "Realm", "PARTY")
    addon.Sync.ProcessAddonMessage("ISILIVE", "HELLO:0.9.216:2:1500:hello", "Peer-RealmA", "Me", "Realm", "PARTY")
  end)

  local stored = addon.Sync.GetPlayerHelloInfo("Peer", "RealmA")
  Check(stored ~= nil, "Peer-RealmA helloInfo present")
  Check(stored and stored.addonVersion == "0.9.216", "version bumped to 0.9.216 in-place")
  Check(stored and stored.capturedAt == 1500, "capturedAt updated to 1500 (newer)")
end

-- ----------------------------------------------------------------------
-- Phase E: ACK does NOT clobber HELLO-stored protocolVersion. After
-- HELLO:0.9.216:2:..., a follow-up ACK:0.9.220 must update addonVersion
-- AND change source to "ack" but NOT zero protocolVersion (the field is
-- not in the ACK payload, so SetPlayerHelloAckInfo leaves it untouched).
-- ----------------------------------------------------------------------
local function ScenarioAckPreservesProtocolVersion()
  print("\n========== Phase E: ACK after HELLO preserves stored protocolVersion ==========")

  local addon
  Harness.WithGlobals(BuildBaseGlobals(1000), function()
    addon = Harness.LoadAddonModules({ "isiLive_sync.lua" })
    addon.Sync.ProcessAddonMessage("ISILIVE", "HELLO:0.9.216:2:1000:hello", "Peer-RealmA", "Me", "Realm", "PARTY")
    addon.Sync.ProcessAddonMessage("ISILIVE", "ACK:0.9.220", "Peer-RealmA", "Me", "Realm", "PARTY")
  end)

  local stored = addon.Sync.GetPlayerHelloInfo("Peer", "RealmA")
  Check(stored ~= nil, "Peer-RealmA helloInfo still present after ACK")
  Check(stored and stored.addonVersion == "0.9.220", "addonVersion bumped via ACK")
  Check(stored and stored.protocolVersion == 2, "protocolVersion preserved at 2 (ACK does not carry it)")
  Check(stored and stored.source == "ack", "source flipped to 'ack'")
end

-- ----------------------------------------------------------------------
-- Phase F: SHAREKEYS works regardless of peer protocol version. Pin that
-- the SHAREKEYS literal-match path is independent of HELLO state — even
-- a peer who never sent HELLO can trigger SHAREKEYS, because the literal
-- check is `message == "SHAREKEYS"`, not "must have shaken hands first".
-- ----------------------------------------------------------------------
local function ScenarioShareKeysWithoutHandshake()
  print("\n========== Phase F: SHAREKEYS works without prior HELLO ==========")

  local addon
  local result
  Harness.WithGlobals(BuildBaseGlobals(1000), function()
    addon = Harness.LoadAddonModules({ "isiLive_sync.lua" })
    result = addon.Sync.ProcessAddonMessage("ISILIVE", "SHAREKEYS", "Stranger-RealmZ", "Me", "Realm", "PARTY")
  end)

  Check(result ~= nil, "ProcessAddonMessage accepted SHAREKEYS from never-handshaked peer")
  Check(result and result.shouldShareKeys == true, "shouldShareKeys=true (no handshake gate)")
  Check(result and result.shouldAck == false, "shouldAck=false (SHAREKEYS is not HELLO)")
end

ScenarioHelloVersionVariants()
ScenarioAckVersionVariants()
ScenarioMixedVersionGroup()
ScenarioPeerVersionBumpInPlace()
ScenarioAckPreservesProtocolVersion()
ScenarioShareKeysWithoutHandshake()

if failures > 0 then
  print(string.format("\nVersion-skew simulator failed: %d check(s) failed", failures))
  os.exit(1)
end

print("\nVersion-skew simulator passed.")
