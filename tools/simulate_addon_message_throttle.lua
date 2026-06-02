-- Standalone CLI tool: pins the ChatThrottleLib (CTL) priority routing
-- introduced in v0.9.179. Every Sync.Send* fans out through
-- DispatchAddonMessage which prefers ChatThrottleLib when present and
-- falls back to raw C_ChatInfo.SendAddonMessage otherwise.
--
-- Per-message-type priority, as set by the production senders in sync.lua:
--   ALERT  -> SendKick, SendRefreshRequest, SendShareKeysRequest
--   NORMAL -> SendHello, SendKey, SendTarget, SendCombatAnnounce,
--             SendLibKeystoneRequest, SendLibKeystonePartyData
--   BULK   -> SendStats, SendDps, SendLoc
--
-- Verifies:
--   * With CTL present: each Sync.Send* call hands the right priority to
--     ChatThrottleLib.SendAddonMessage (CTL signature: self, prio, prefix,
--     payload, channel).
--   * pcall isolation: CTL.SendAddonMessage raising does NOT propagate out
--     of DispatchAddonMessage.
--   * Without CTL: falls back to raw C_ChatInfo.SendAddonMessage with no
--     priority arg (Blizzard API doesn't take one).
--   * Burst order: 5 sends in sequence land in the CTL ledger in the same
--     order they were emitted.
--
-- End-to-end discipline (CLAUDE.md "Tests & simulators: end-to-end by default"):
-- the real Sync module is loaded; Sync.Send* are invoked with their
-- production opts shapes; CTL is a steerable mock that records every
-- call. The fallback path is verified by removing the CTL global and
-- re-loading the module.
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
-- WoW-globals model. ctlEnabled flips between CTL-present and CTL-absent.
-- ctlRaises makes the CTL.SendAddonMessage call throw, simulating an
-- internal CTL bug.
-- ----------------------------------------------------------------------
local model = {
  ctlEnabled = true,
  ctlRaises = false,
  ctlCalls = {}, -- list of { priority, prefix, payload, channel }
  blizzardCalls = {}, -- list of { prefix, payload, channel } for the fallback path
}

local function ResetModel()
  model.ctlEnabled = true
  model.ctlRaises = false
  model.ctlCalls = {}
  model.blizzardCalls = {}
end

local function buildGlobals()
  local globals = {
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
    GetTime = function()
      return 1000
    end,
    LE_PARTY_CATEGORY_INSTANCE = 2,
    IsiLiveDB = { syncEnabled = true },
    C_ChatInfo = {
      RegisterAddonMessagePrefix = function()
        return true
      end,
      SendAddonMessage = function(prefix, payload, channel)
        model.blizzardCalls[#model.blizzardCalls + 1] = {
          prefix = prefix,
          payload = payload,
          channel = channel,
        }
        return true
      end,
    },
  }
  if model.ctlEnabled then
    globals.ChatThrottleLib = {
      SendAddonMessage = function(_self, priority, prefix, payload, channel)
        if model.ctlRaises then
          error("simulated CTL internal failure", 0)
        end
        model.ctlCalls[#model.ctlCalls + 1] = {
          priority = priority,
          prefix = prefix,
          payload = payload,
          channel = channel,
        }
      end,
    }
  end
  return globals
end

local function BuildSession()
  local addon
  Harness.WithGlobals(buildGlobals(), function()
    addon = Harness.LoadAddonModules({ "isiLive_sync.lua" })
  end)
  return {
    addon = addon,
    -- Drive a Sync.Send* and return the priority + prefix the dispatcher
    -- handed to CTL (or nil if it went down the fallback path).
    send = function(sendFn, opts)
      opts = opts or {}
      opts.isVisible = false
      opts.allowHidden = true
      opts.force = true
      Harness.WithGlobals(buildGlobals(), function()
        sendFn(opts)
      end)
    end,
  }
end

local function LastCTL()
  return model.ctlCalls[#model.ctlCalls]
end

local function LastBlizzard()
  return model.blizzardCalls[#model.blizzardCalls]
end

-- ----------------------------------------------------------------------
-- Phase 1: CTL present, each Send* routes the documented priority.
-- ----------------------------------------------------------------------
local function ScenarioCTLPriorityRouting()
  print("\n========== Scenario 1: CTL priority routing per message type ==========")
  ResetModel()
  local session = BuildSession()

  -- HELLO: NORMAL
  session.send(session.addon.Sync.SendHello, {
    version = "0.9.250",
    protocolVersion = 2,
    capturedAt = 1000,
    source = "test",
  })
  local last = LastCTL()
  Check(last and last.priority == "NORMAL", "HELLO routes priority=NORMAL")
  Check(last and last.prefix == "ISILIVE", "HELLO routes prefix=ISILIVE")

  -- KEY: NORMAL
  session.send(session.addon.Sync.SendKey, {
    mapID = 2649,
    level = 14,
    capturedAt = 1000,
    source = "test",
  })
  Check(LastCTL().priority == "NORMAL", "KEY routes priority=NORMAL")

  -- STATS: BULK
  session.send(session.addon.Sync.SendStats, {
    specID = 71,
    ilvl = 615,
    rio = 3000,
    capturedAt = 1000,
    source = "test",
  })
  Check(LastCTL().priority == "BULK", "STATS routes priority=BULK")

  -- DPS: BULK
  session.send(session.addon.Sync.SendDps, {
    dps = 250000,
    capturedAt = 1000,
    source = "test",
  })
  Check(LastCTL().priority == "BULK", "DPS routes priority=BULK")

  -- LOC: BULK
  session.send(session.addon.Sync.SendLoc, {
    mapID = 2649,
    capturedAt = 1000,
    source = "test",
  })
  Check(LastCTL().priority == "BULK", "LOC routes priority=BULK")

  -- TARGET: NORMAL
  session.send(session.addon.Sync.SendTarget, {
    mapID = 2649,
    level = 14,
    capturedAt = 1000,
    source = "test",
  })
  Check(LastCTL().priority == "NORMAL", "TARGET routes priority=NORMAL")

  -- KICK: ALERT (highest)
  session.send(session.addon.Sync.SendKick, {
    hasKick = true,
    onCooldown = false,
    cooldownRemain = 0,
  })
  Check(LastCTL().priority == "ALERT", "KICK routes priority=ALERT (highest)")

  -- REQSYNC: ALERT
  session.send(session.addon.Sync.SendRefreshRequest, {})
  Check(LastCTL().priority == "ALERT", "REQSYNC routes priority=ALERT")

  -- SHAREKEYS: ALERT
  Harness.WithGlobals(buildGlobals(), function()
    session.addon.Sync.SendShareKeysRequest()
  end)
  Check(LastCTL().priority == "ALERT", "SHAREKEYS routes priority=ALERT")
end

-- ----------------------------------------------------------------------
-- Phase 2: CTL absent -> fallback to C_ChatInfo.SendAddonMessage with no
-- priority arg (Blizzard API doesn't take one).
-- ----------------------------------------------------------------------
local function ScenarioFallbackToBlizzardWhenCTLAbsent()
  print("\n========== Scenario 2: CTL absent -> fallback to C_ChatInfo.SendAddonMessage ==========")
  ResetModel()
  model.ctlEnabled = false
  local session = BuildSession()

  session.send(session.addon.Sync.SendHello, {
    version = "0.9.250",
    protocolVersion = 2,
    capturedAt = 1000,
    source = "test",
  })
  Check(#model.ctlCalls == 0, "no CTL call recorded when ChatThrottleLib global is absent")
  Check(#model.blizzardCalls == 1, "fallback path landed exactly one C_ChatInfo.SendAddonMessage call")
  local last = LastBlizzard()
  Check(last and last.prefix == "ISILIVE", "fallback uses prefix=ISILIVE")
  Check(last and last.payload:find("HELLO:", 1, true), "fallback payload starts with HELLO:")

  -- KICK on the fallback path: still goes through SendAddonMessage with no priority.
  session.send(session.addon.Sync.SendKick, {
    hasKick = true,
    onCooldown = false,
    cooldownRemain = 0,
  })
  Check(#model.blizzardCalls == 2, "fallback path catches KICK as well (no priority discrimination on raw API)")
  Check(LastBlizzard().payload == "KICK:0:0", "fallback KICK payload is 'KICK:0:0'")
end

-- ----------------------------------------------------------------------
-- Phase 3: pcall isolation. CTL raises -> DispatchAddonMessage returns
-- false but does not propagate the error. Subsequent sends still work
-- (the next call gets a clean dispatch attempt).
-- ----------------------------------------------------------------------
local function ScenarioCTLPcallIsolation()
  print("\n========== Scenario 3: CTL.SendAddonMessage raising is contained by pcall ==========")
  ResetModel()
  model.ctlRaises = true
  local session = BuildSession()

  -- Production calls pcall around CTL — the error must NOT leak to the caller.
  local ok = pcall(function()
    session.send(session.addon.Sync.SendHello, {
      version = "0.9.250",
      protocolVersion = 2,
      capturedAt = 1000,
      source = "test",
    })
  end)
  Check(ok == true, "Sync.SendHello with raising CTL does NOT propagate the error to the caller")

  -- After the error, recovery: clear the raise flag and retry.
  model.ctlRaises = false
  session.send(session.addon.Sync.SendKey, {
    mapID = 2649,
    level = 14,
    capturedAt = 1000,
    source = "test",
  })
  Check(
    LastCTL() and LastCTL().priority == "NORMAL",
    "subsequent send (after CTL recovers) lands cleanly with priority=NORMAL"
  )
end

-- ----------------------------------------------------------------------
-- Phase 4: Burst order preserved. 5 sequential Send* calls land in the
-- CTL ledger in the same order they were emitted. (CTL itself reorders
-- by priority on flush, but the per-call ENQUEUE order from our side
-- must match the call order.)
-- ----------------------------------------------------------------------
local function ScenarioBurstOrderPreserved()
  print("\n========== Scenario 4: 5-send burst preserves enqueue order ==========")
  ResetModel()
  local session = BuildSession()

  -- Five distinct send types in a known order.
  session.send(session.addon.Sync.SendHello, {
    version = "0.9.250",
    protocolVersion = 2,
    capturedAt = 1000,
    source = "test",
  })
  session.send(session.addon.Sync.SendKey, {
    mapID = 2649,
    level = 14,
    capturedAt = 1000,
    source = "test",
  })
  session.send(session.addon.Sync.SendStats, {
    specID = 71,
    ilvl = 615,
    rio = 3000,
    capturedAt = 1000,
    source = "test",
  })
  session.send(session.addon.Sync.SendKick, {
    hasKick = true,
    onCooldown = false,
    cooldownRemain = 0,
  })
  session.send(session.addon.Sync.SendDps, {
    dps = 250000,
    capturedAt = 1000,
    source = "test",
  })

  Check(#model.ctlCalls == 5, "5 sends produce 5 CTL ledger entries")
  Check(model.ctlCalls[1].payload:find("HELLO:", 1, true) ~= nil, "ledger[1] is HELLO")
  Check(model.ctlCalls[2].payload:find("KEY:", 1, true) ~= nil, "ledger[2] is KEY")
  Check(model.ctlCalls[3].payload:find("STATS:", 1, true) ~= nil, "ledger[3] is STATS")
  Check(model.ctlCalls[4].payload:find("KICK:", 1, true) ~= nil, "ledger[4] is KICK")
  Check(model.ctlCalls[5].payload:find("DPS:", 1, true) ~= nil, "ledger[5] is DPS")
end

ScenarioCTLPriorityRouting()
ScenarioFallbackToBlizzardWhenCTLAbsent()
ScenarioCTLPcallIsolation()
ScenarioBurstOrderPreserved()

if failures > 0 then
  print(string.format("\nAddon-message throttle simulator failed: %d check(s) failed", failures))
  os.exit(1)
end

print("\nAddon-message throttle simulator passed.")
