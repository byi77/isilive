-- Standalone CLI tool: end-to-end roundtrip for the multi-kick "extras"
-- pipeline introduced in v0.9.193 / v0.9.194.
--
-- Background: certain specs run a SECOND interrupt alongside their spec's
-- primary kick — Prot Paladin (Rebuke + Avenger's Shield), Demo Warlock
-- (Spell Lock + Axe Toss). The extra spell's cooldown is broadcast over the
-- KICK addon-message channel via an optional ":E:<spellID>,<remain>;..."
-- suffix, so peers can show all available interrupts on the kick tooltip.
--
-- Verifies:
--   * KickTracker.OnCast(extra spellID) populates the extras map with
--     {cd, cdEnd}.
--   * KickTracker.GetKickInfo().extras exposes the live cooldown remain.
--   * Sync.SendKick({extras=...}) emits the wire format
--     "KICK:<state>:<remain>:E:<spellID>,<remain>;..." with numerically
--     sorted spellIDs (deterministic dedup-payload across pairs() orderings).
--   * Sync.ProcessAddonMessage decodes the same bytes back into
--     player.kick.extras = { [spellID] = { cooldownRemain } }.
--   * Backwards compat: old peers without the suffix still ingest cleanly
--     (kickUpdated=true, extras=nil).
--   * 8-entry memory cap: a hostile or buggy peer broadcasting 20 extras
--     gets capped at 8 in the receiver's state.
--   * Expiry: Scan() sweeps extras whose cdEnd has passed.
--
-- End-to-end discipline (CLAUDE.md "Tests & simulators: end-to-end by default"):
-- the real KickTracker.CreateController + Sync.SendKick + Sync.ProcessAddonMessage
-- are loaded; OnCast drives the production extras-population path; wire
-- bytes flow through DispatchAddonMessage's captured payload (no hard-coded
-- KICK strings); the receiver decode is the same code production runs at
-- runtime.
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

-- ----------------------------------------------------------------------
-- WoW-globals model: KickTracker reads UnitClass / GetTime / GetSpellBaseCooldown
-- on init; OnCast rewrites extras based on these. Sync needs strsplit /
-- IsInGroup / IsInRaid / GetTime / C_ChatInfo / GetRealmName / UnitName.
-- ----------------------------------------------------------------------
local model = {
  now = 1000,
  playerClass = "PALADIN", -- has Rebuke (primary) + Avenger's Shield (extra)
  specID = 66, -- Protection Paladin: primary Rebuke, verified Avenger's Shield extra
  sentMessages = {},
}

local function buildGlobals()
  return {
    GetTime = function()
      return model.now
    end,
    UnitClass = function(unit)
      if unit == "player" then
        return "Paladin", model.playerClass
      end
      return nil, nil
    end,
    -- KickTracker probes these on init/refresh; resolve Protection Paladin so
    -- Avenger's Shield is tested as a verified extra, not as unresolved-spec guesswork.
    GetSpecialization = function()
      return model.specID and 1 or nil
    end,
    GetSpecializationInfo = function(index)
      if index == 1 then
        return model.specID
      end
      return nil
    end,
    GetSpellBaseCooldown = function(spellID)
      if spellID == 96231 then
        return 15000
      end
      return nil
    end,
    -- Sync needs these:
    strsplit = StrSplitStub,
    GetRealmName = function()
      return "Realm"
    end,
    UnitName = function()
      return "MyPlayer", "Realm"
    end,
    IsInGroup = function()
      return true
    end,
    IsInRaid = function()
      return false
    end,
    C_ChatInfo = {
      RegisterAddonMessagePrefix = function()
        return true
      end,
      SendAddonMessage = function(prefix, payload, channel)
        model.sentMessages[#model.sentMessages + 1] = { prefix = prefix, payload = payload, channel = channel }
        return true
      end,
    },
    LE_PARTY_CATEGORY_INSTANCE = 2,
    IsiLiveDB = { syncEnabled = true },
  }
end

local function BuildSession()
  model.sentMessages = {}
  local addon
  Harness.WithGlobals(buildGlobals(), function()
    addon = Harness.LoadAddonModules({
      "isiLive_kick_tracker.lua",
      "isiLive_sync.lua",
    })
  end)

  local kickController
  Harness.WithGlobals(buildGlobals(), function()
    kickController = addon.KickTracker.CreateController({
      getTime = function()
        return model.now
      end,
    })
  end)

  return {
    addon = addon,
    kick = kickController,
    onCast = function(unit, spellID)
      Harness.WithGlobals(buildGlobals(), function()
        kickController.OnCast(unit, spellID)
      end)
    end,
    scan = function()
      Harness.WithGlobals(buildGlobals(), function()
        kickController.Scan()
      end)
    end,
    getKickInfo = function()
      local info
      Harness.WithGlobals(buildGlobals(), function()
        info = kickController.GetKickInfo()
      end)
      return info
    end,
    -- Drive Sync.SendKick with the production capture path (returns the
    -- emitted addon-message payload string).
    sendKick = function(opts)
      local before = #model.sentMessages
      opts = opts or {}
      opts.isVisible = false
      opts.allowHidden = true
      opts.force = true
      Harness.WithGlobals(buildGlobals(), function()
        addon.Sync.SendKick(opts)
      end)
      if #model.sentMessages > before then
        return model.sentMessages[#model.sentMessages].payload
      end
      return nil
    end,
    process = function(payload, sender)
      local result
      Harness.WithGlobals(buildGlobals(), function()
        result = addon.Sync.ProcessAddonMessage("ISILIVE", payload, sender, "MyPlayer", "Realm")
      end)
      return result
    end,
    advance = function(seconds)
      model.now = model.now + (seconds or 0)
    end,
  }
end

-- ----------------------------------------------------------------------
-- Phase 1: OnCast(extra spellID) populates the extras map.
-- For Prot Pala the primary is Rebuke (96231); Avenger's Shield (31935)
-- is the extra. The simulator resolves the spec explicitly, matching the
-- fail-closed runtime contract for unknown specs.
-- ----------------------------------------------------------------------
local function ScenarioExtraOnCastPopulates()
  print("\n========== Scenario 1: OnCast(extra) populates extras map ==========")
  model.now = 1000
  model.playerClass = "PALADIN"
  local session = BuildSession()

  session.onCast("player", 31935) -- Avenger's Shield
  local info = session.getKickInfo()
  Check(
    type(info.extras) == "table" and type(info.extras[31935]) == "table",
    "OnCast(31935 Avenger's Shield) populates extras[31935]"
  )
  Check(
    info.extras and info.extras[31935] and info.extras[31935].onCooldown == true,
    "extras[31935].onCooldown == true after the cast"
  )
  Check(
    info.extras and info.extras[31935] and info.extras[31935].cooldownRemain == 30,
    "extras[31935].cooldownRemain == 30 (EXTRA_KICK_CD entry for Avenger's Shield)"
  )
end

-- ----------------------------------------------------------------------
-- Phase 2: Sync wire-roundtrip — SendKick({extras=...}) emits the :E:
-- suffix, ProcessAddonMessage decodes it back into the receiver's state.
-- ----------------------------------------------------------------------
local function ScenarioWireRoundtrip()
  print("\n========== Scenario 2: extras wire-roundtrip via Sync ==========")
  model.now = 1000
  local session = BuildSession()

  local payload = session.sendKick({
    hasKick = true,
    onCooldown = false,
    cooldownRemain = 0,
    extras = {
      [31935] = { cooldownRemain = 18 }, -- Avenger's Shield, 18s left
      [96231] = { cooldownRemain = 7 }, -- Rebuke (would normally be primary, here as 2nd extra for sort test)
    },
  })
  Check(
    payload == "KICK:0:0:E:31935,18;96231,7" or payload == "KICK:0:0:E:96231,7;31935,18",
    "wire payload contains :E: suffix with both extras (got: " .. tostring(payload) .. ")"
  )
  -- The production sender sorts entries numerically by spellID — pin that.
  Check(
    payload == "KICK:0:0:E:31935,18;96231,7",
    "sender sorts extras numerically by spellID (deterministic dedup-payload across pairs() orderings)"
  )

  -- Feed the captured bytes into a fresh receiver session.
  local receiver = BuildSession()
  local result = receiver.process(payload, "Peer-OtherRealm")
  Check(result and result.kickUpdated == true, "receiver applies the wire payload")

  local kickInfo = receiver.addon.Sync.GetPlayerKickInfo("Peer", "OtherRealm")
  Check(kickInfo ~= nil, "receiver Sync state has Peer kick info after roundtrip")
  Check(kickInfo and kickInfo.hasKick == true, "kickInfo.hasKick=true (state=0 in wire)")
  Check(type(kickInfo.extras) == "table", "kickInfo.extras is a table after wire-roundtrip")
  Check(
    kickInfo.extras and kickInfo.extras[31935] and kickInfo.extras[31935].cooldownRemain == 18,
    "extras[31935].cooldownRemain decoded as 18"
  )
  Check(
    kickInfo.extras and kickInfo.extras[96231] and kickInfo.extras[96231].cooldownRemain == 7,
    "extras[96231].cooldownRemain decoded as 7"
  )
end

-- ----------------------------------------------------------------------
-- Phase 3: 8-entry memory cap. A peer broadcasting 20 extras should land
-- at most 8 entries in the receiver's state. Send 20 extras, expect 8.
-- ----------------------------------------------------------------------
local function Scenario8ExtraCap()
  print("\n========== Scenario 3: 8-extra memory cap on the receiver ==========")
  model.now = 1000
  local session = BuildSession()
  local manyExtras = {}
  for i = 1, 20 do
    manyExtras[10000 + i] = { cooldownRemain = i * 2 }
  end
  local payload = session.sendKick({
    hasKick = true,
    onCooldown = false,
    cooldownRemain = 0,
    extras = manyExtras,
  })
  Check(payload ~= nil, "sender emits a payload even with 20 extras")

  local receiver = BuildSession()
  receiver.process(payload, "Peer-OtherRealm")
  local kickInfo = receiver.addon.Sync.GetPlayerKickInfo("Peer", "OtherRealm")
  local count = 0
  if kickInfo and type(kickInfo.extras) == "table" then
    for _ in pairs(kickInfo.extras) do
      count = count + 1
    end
  end
  Check(
    count <= 8,
    string.format(
      "receiver caps decoded extras at <= 8 entries (got %d) — defense against malformed/hostile peers",
      count
    )
  )
end

-- ----------------------------------------------------------------------
-- Phase 4: Backwards-compat — receiver sees old wire format with no :E:
-- suffix → kickUpdated=true, extras=nil.
-- ----------------------------------------------------------------------
local function ScenarioBackwardsCompatNoSuffix()
  print("\n========== Scenario 4: backwards-compat for peers without :E: suffix ==========")
  local receiver = BuildSession()
  local result = receiver.process("KICK:0:0", "OldPeer-OtherRealm")
  Check(result and result.kickUpdated == true, "old wire format (no :E: suffix) still ingests cleanly")
  local kickInfo = receiver.addon.Sync.GetPlayerKickInfo("OldPeer", "OtherRealm")
  Check(kickInfo ~= nil, "old peer's kick info is recorded")
  Check(kickInfo and kickInfo.hasKick == true, "old peer hasKick=true (no extras)")
  Check(kickInfo == nil or kickInfo.extras == nil, "no extras field synthesised for old wire format")
end

-- ----------------------------------------------------------------------
-- Phase 5: Scan() sweeps expired extras. After the cd window passes,
-- the entry vanishes from GetKickInfo().extras.
-- ----------------------------------------------------------------------
local function ScenarioScanSweepsExpired()
  print("\n========== Scenario 5: Scan() drops expired extras ==========")
  model.now = 1000
  model.playerClass = "PALADIN"
  local session = BuildSession()

  session.onCast("player", 31935) -- 30s CD window
  Check(session.getKickInfo().extras and session.getKickInfo().extras[31935], "extras populated immediately after cast")

  session.advance(15)
  session.scan()
  Check(
    session.getKickInfo().extras and session.getKickInfo().extras[31935],
    "extras still present mid-window (15s into 30s CD)"
  )

  session.advance(20) -- now past 30s
  session.scan()
  local info = session.getKickInfo()
  Check(info.extras == nil or info.extras[31935] == nil, "extras[31935] is dropped by Scan() after the 30s CD expires")
end

-- ----------------------------------------------------------------------
-- Phase 6: Extras for a non-class-interrupt spell are ignored.
-- ----------------------------------------------------------------------
local function ScenarioOnCastIgnoresUnknownSpell()
  print("\n========== Scenario 6: OnCast(non-class-interrupt) is ignored ==========")
  model.now = 1000
  model.playerClass = "PALADIN"
  local session = BuildSession()

  session.onCast("player", 1234567) -- not in CLASS_INTERRUPT_LIST.PALADIN
  local info = session.getKickInfo()
  Check(info.extras == nil, "OnCast(unknown spellID) does not populate extras")
end

ScenarioExtraOnCastPopulates()
ScenarioWireRoundtrip()
Scenario8ExtraCap()
ScenarioBackwardsCompatNoSuffix()
ScenarioScanSweepsExpired()
ScenarioOnCastIgnoresUnknownSpell()

if failures > 0 then
  print(string.format("\nKick-tracker extras simulator failed: %d check(s) failed", failures))
  os.exit(1)
end

print("\nKick-tracker extras simulator passed.")
