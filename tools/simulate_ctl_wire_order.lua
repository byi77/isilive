-- Standalone probe: wire-order of the share-keys click sequence through the
-- REAL embedded ChatThrottleLib (not a mock). Answers two audit questions:
--   1. Does SHAREKEYS hit the wire BEFORE the visible own-key chat line?
--   2. If CTL is congested (other addons ate the budget), what is the real
--      wire order, and does the receiver chain still process correctly?
--
-- The click sequence mirrors ui/isiLive_roster_panel.lua OnClick exactly:
--   (1) Sync.SendShareKeysRequest()            -- via CTL, ALERT priority
--   (2) ContextHelpers.SendPartyChatMessage()  -- raw SendChatMessage, no CTL
--
-- Run from repo root: lua <this file>
---@diagnostic disable: undefined-global

-- Lua 5.1/5.4 compat (same bridge as tools/validate_usecases.lua): the
-- embedded CTL uses the 5.1 global `unpack`.
if type(rawget(_G, "unpack")) ~= "function" and type(rawget(table, "unpack")) == "function" then
  rawset(_G, "unpack", rawget(table, "unpack"))
end

local function LoadLocal(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  local chunk, err = (loadstring or load)(source, "@" .. path)
  assert(chunk, err)
  return chunk()
end

local Harness = LoadLocal("testmodul/isilive_test_harness.lua")

local rawprint = print
local failures = 0
local function Check(condition, message)
  if condition then
    rawprint("  [CHECK PASS] " .. message)
  else
    failures = failures + 1
    rawprint("  [CHECK FAIL] " .. message)
  end
end

-- Shared wire ledger: every outgoing message in the exact order the WoW
-- client would hand it to the server (addon messages AND chat messages).
local wire = {}
local model = { now = 1000 }

local function WireSummary()
  local parts = {}
  for i, entry in ipairs(wire) do
    parts[#parts + 1] = string.format("%d:%s/%s", i, entry.kind, entry.payload:sub(1, 12))
  end
  return table.concat(parts, "  ")
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

local globals = {
  GetTime = function()
    return model.now
  end,
  GetFramerate = function()
    return 60
  end,
  CreateFrame = function()
    local frame = {}
    function frame.Hide() end
    function frame.Show() end
    function frame.SetScript(_, key, value)
      frame[key] = value
    end
    function frame.RegisterEvent() end
    return frame
  end,
  hooksecurefunc = function() end,
  strsplit = StrSplitStub,
  GetRealmName = function()
    return "Realm"
  end,
  UnitName = function()
    return "Sender", "Realm"
  end,
  IsInGroup = function(category)
    if category == 2 then
      return false
    end
    return true
  end,
  IsInRaid = function()
    return false
  end,
  UnitInParty = function()
    return true
  end,
  UnitInRaid = function()
    return false
  end,
  LE_PARTY_CATEGORY_INSTANCE = 2,
  IsiLiveDB = { syncEnabled = true },
  C_ChatInfo = {
    RegisterAddonMessagePrefix = function()
      return true
    end,
    SendAddonMessage = function(prefix, payload, channel)
      wire[#wire + 1] = { kind = "ADDON", prefix = prefix, payload = payload, channel = channel }
      return true
    end,
  },
  SendChatMessage = function(message, channel)
    wire[#wire + 1] = { kind = "CHAT", payload = message, channel = channel }
  end,
  print = function() end,
}

Harness.WithGlobals(globals, function()
  -- Real CTL + real Sync + real ContextHelpers in one shared global scope.
  local addon = Harness.LoadAddonModules({
    "ChatThrottleLib.lua",
    "isiLive_context_helpers.lua",
    "isiLive_sync.lua",
  })
  local ctl = rawget(_G, "ChatThrottleLib")
  Check(ctl ~= nil and type(ctl.SendAddonMessage) == "function", "real ChatThrottleLib is loaded and active")

  local ownLine = "[isiLive] PartyKeys: [Keystone: Probe Dungeon +12]"

  -- The production click sequence (ui/isiLive_roster_panel.lua OnClick):
  local function ClickSequence()
    local requested = addon.Sync.SendShareKeysRequest()
    local announced = addon.ContextHelpers.SendPartyChatMessage(ownLine)
    return requested, announced
  end

  -- ==========================================================================
  print("\n========== Scenario 1: idle network — CTL budget free ==========")
  -- 20s after CTL init: hard-throttle window over, BURST budget fully refilled.
  model.now = 1020
  wire = {}
  local requested, announced = ClickSequence()

  rawprint("  wire order: " .. WireSummary())
  Check(requested == true, "SendShareKeysRequest reports success (CTL accepted)")
  Check(announced == true, "own-key chat line was sent")
  Check(#wire == 2, "exactly two messages hit the wire")
  Check(
    wire[1] and wire[1].kind == "ADDON" and wire[1].payload == "SHAREKEYS",
    "wire #1 is the SHAREKEYS addon message (CTL sent it synchronously in the same frame)"
  )
  Check(
    wire[2] and wire[2].kind == "CHAT" and wire[2].payload == ownLine,
    "wire #2 is the visible own-key chat line — order matches the click sequence"
  )

  -- ==========================================================================
  print("\n========== Scenario 2: congested network — another addon drained the CTL budget ==========")
  -- Simulate a foreign addon (WeakAuras/MDT-style) pushing bulk sync traffic
  -- through CTL until the 4000-byte burst budget is gone and CTL queues.
  model.now = 1100
  wire = {}
  local bulkPayload = string.rep("x", 250)
  for _ = 1, 20 do
    ctl:SendAddonMessage("BULK", "OTHER", bulkPayload, "PARTY")
  end
  local floodDirect = #wire
  Check(
    floodDirect > 0 and floodDirect < 20,
    string.format("flood: %d/20 foreign messages went out directly, the rest queued (budget exhausted)", floodDirect)
  )
  Check(ctl.bQueueing == true, "CTL is now in queueing mode")

  wire = {}
  requested = ClickSequence()
  rawprint("  wire order: " .. WireSummary())
  Check(requested == true, "SendShareKeysRequest still reports success (enqueued, not dropped)")
  Check(
    #wire == 1 and wire[1].kind == "CHAT",
    "INVERSION: only the chat line went out immediately — SHAREKEYS is stuck in the CTL queue"
  )

  -- Pump CTL OnUpdate with advancing time until the queue despools.
  local pumped = 0
  while pumped < 100 do
    pumped = pumped + 1
    model.now = model.now + 0.1
    ctl.OnUpdate(ctl.Frame, 0.1)
    local found = false
    for _, entry in ipairs(wire) do
      if entry.kind == "ADDON" and entry.payload == "SHAREKEYS" then
        found = true
        break
      end
    end
    if found then
      break
    end
  end
  rawprint("  wire order after despool: " .. WireSummary())
  local shareKeysPos, firstBulkPos = nil, nil
  for i, entry in ipairs(wire) do
    if entry.payload == "SHAREKEYS" and not shareKeysPos then
      shareKeysPos = i
    end
    if entry.prefix == "OTHER" and not firstBulkPos then
      firstBulkPos = i
    end
  end
  Check(
    shareKeysPos ~= nil,
    string.format(
      "SHAREKEYS despooled after %.1fs simulated lag — delayed but DELIVERED, never dropped",
      pumped * 0.1
    )
  )
  Check(
    firstBulkPos == nil or shareKeysPos < firstBulkPos,
    "ALERT priority: SHAREKEYS overtakes the queued foreign BULK backlog"
  )

  -- ==========================================================================
  print("\n========== Scenario 3: receiver processes the inverted order correctly ==========")
  -- The receiver sees: (a) the sender's chat line first (plain chat, no addon
  -- handler attached), (b) SHAREKEYS later. Assert that SHAREKEYS processing
  -- has no ordering dependency: no prior HELLO, no prior chat needed.
  local result = addon.Sync.ProcessAddonMessage("ISILIVE", "SHAREKEYS", "Sender-Realm", "Receiver", "Realm")
  Check(
    result ~= nil and result.shouldShareKeys == true,
    "late SHAREKEYS still triggers the receiver reply — no handshake or ordering gate"
  )

  -- SKCD arriving before/after other fan-out messages is equally order-free:
  local skcd = addon.Sync.ProcessAddonMessage("ISILIVE", "SKCD:17", "Sender-Realm", "Receiver", "Realm")
  Check(
    skcd ~= nil and skcd.shareKeysCooldownRemain == 17,
    "SKCD is processed standalone — no dependency on HELLO/KEY arriving first"
  )

  -- In-order guarantee within one CTL priority+pipe (FIFO ring):
  print("\n========== Scenario 4: FIFO within the ISILIVE ALERT pipe under congestion ==========")
  model.now = 1200
  wire = {}
  for _ = 1, 20 do
    ctl:SendAddonMessage("BULK", "OTHER", bulkPayload, "PARTY")
  end
  wire = {}
  addon.Sync.SendRefreshRequest({ force = true }) -- ALERT, pipe ISILIVE+PARTY
  addon.Sync.SendShareKeysRequest() -- ALERT, same pipe
  for _ = 1, 100 do
    model.now = model.now + 0.1
    ctl.OnUpdate(ctl.Frame, 0.1)
  end
  local reqPos, skPos = nil, nil
  for i, entry in ipairs(wire) do
    if entry.payload == "REQSYNC" then
      reqPos = i
    elseif entry.payload == "SHAREKEYS" then
      skPos = i
    end
  end
  rawprint("  wire order after despool: " .. WireSummary())
  Check(reqPos ~= nil and skPos ~= nil, "both ISILIVE ALERT messages were delivered")
  Check(
    reqPos ~= nil and skPos ~= nil and reqPos < skPos,
    "FIFO holds inside the ISILIVE pipe: REQSYNC stays ahead of SHAREKEYS"
  )
end)

print("")
if failures > 0 then
  print(string.format("CTL wire-order probe FAILED: %d check(s)", failures))
  os.exit(1)
end
print("CTL wire-order probe passed.")
