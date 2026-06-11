#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Worst-case wire-format size guard for every Sync.Send* function in
-- logic/isiLive_sync.lua.
--
-- WoW silently drops C_ChatInfo.SendAddonMessage payloads longer than 255
-- bytes — the call returns true, ChatThrottleLib accepts the message,
-- nobody on the receiving end ever sees it, and the sender has no way to
-- know it failed. This gate fakes a runtime call to each Send* function
-- with maximally-sized arguments (long player names, large numeric IDs,
-- 8-entry kick extras list, etc.) and records the payload via a stub
-- DispatchAddonMessage. If the recorded length exceeds the safety budget
-- (245 bytes — leaves 10 bytes of headroom for future field additions),
-- the gate fails.
--
-- This complements the runtime guard in Sync.ProcessAddonMessage which
-- rejects payloads >MAX_ADDON_MESSAGE_LENGTH on receive: catching it at
-- send time means the bug is found at preflight, not in production.
--
-- Exits 0 on clean, 1 on violations, 2 on IO/setup errors.
-- Run from repo root:
--   lua tools/check_addon_message_size.lua

local MAX_ADDON_MESSAGE_LENGTH = 255
local SAFETY_BUDGET = 245
local LIBKS_PREFIX = "LibKS"

local function fail(code, message)
  io.stderr:write("addon-message-size: " .. message .. "\n")
  os.exit(code)
end

local addonTable = {}

local function LoadFile(path)
  local chunk, err = loadfile(path)
  if not chunk then
    fail(2, "cannot load " .. path .. ": " .. tostring(err))
  end
  local ok, runErr = pcall(chunk, "isiLive", addonTable)
  if not ok then
    fail(2, "error executing " .. path .. ": " .. tostring(runErr))
  end
end

-- Captured outgoing payloads. Each entry: { prefix=..., payload=..., channel=... }
local captured = {}

-- Build a maximal-size player name + realm: WoW caps player names at 12 chars
-- and realm names at 24, but we use 24+24 here as belt-and-braces in case the
-- limits change. Realm token strips dashes/dots/spaces in NormalizePlayerKey;
-- using all alphabetic keeps the logic faithful to upstream realms.
local LONG_PLAYER = string.rep("X", 24)
local LONG_REALM = string.rep("Y", 24)
local LONG_CASTER = LONG_PLAYER .. "-" .. LONG_REALM

-- Source labels are normalized to lowercase alnum/underscore/dash and
-- trimmed; the longest source token in production today is ~30 chars
-- ("background-broadcast-after-reload"). Use 40 for headroom.
local LONG_SOURCE = "background-broadcast-after-reload-x"

-- Mock the Blizzard chat API so DispatchAddonMessage records the payload.
local function CaptureSendAddonMessage(prefix, payload, channel)
  captured[#captured + 1] = { prefix = prefix, payload = payload, channel = channel }
  return true
end

local globals = {
  GetTime = function()
    return 1000
  end,
  GetRealmName = function()
    return LONG_REALM
  end,
  UnitName = function()
    return LONG_PLAYER
  end,
  IsInGroup = function()
    return true
  end,
  IsInRaid = function()
    return false
  end,
  IsInInstance = function()
    return false, "none"
  end,
  LE_PARTY_CATEGORY_INSTANCE = nil,
  C_ChatInfo = {
    SendAddonMessage = CaptureSendAddonMessage,
    RegisterAddonMessagePrefix = function()
      return true
    end,
  },
  IsiLiveDB = {
    syncEnabled = true,
  },
  strsplit = function(sep, str, max)
    local pos = str:find(sep, 1, true)
    if not pos then
      return str
    end
    if max and max >= 2 then
      return str:sub(1, pos - 1), str:sub(pos + 1)
    end
    return str:sub(1, pos - 1)
  end,
}

-- Apply mocks before loading the module so file-scope state initialises with
-- our globals visible.
local previous = {}
for k, v in pairs(globals) do
  previous[k] = rawget(_G, k)
  _G[k] = v
end

-- Sync depends on a small slice of the addon: bootstrap helpers + season-data
-- (NormalizeMapID). LoadFile mutates the shared addonTable.
LoadFile("core/isiLive_validation_helpers.lua")
LoadFile("core/isiLive_string_utils.lua")
LoadFile("locale/isiLive_languages.lua")
LoadFile("game/isiLive_season_data.lua")
LoadFile("logic/isiLive_sync.lua")

local Sync = addonTable.Sync
if type(Sync) ~= "table" then
  fail(2, "addonTable.Sync did not initialise — check loader order")
end

Sync.RegisterPrefix()

local function ClearCaptured()
  captured = {}
end

local function LastPayload()
  return captured[#captured] and captured[#captured].payload or nil
end

local function CallAndMeasure(label, sendFn)
  ClearCaptured()
  sendFn()
  local payload = LastPayload()
  if not payload then
    return label, nil, "no payload was recorded — Send function returned without dispatch"
  end
  return label, payload, nil
end

-- Worst-case argument sets. For each Send function we choose values that push
-- every numeric field to its maximum digit count and every string field to
-- its maximum normalized length.
local cases = {
  {
    label = "SendHello",
    run = function()
      Sync.SendHello({
        force = true,
        version = "0.99.999-beta-rc-very-long",
        protocolVersion = 99,
        source = LONG_SOURCE,
      })
    end,
  },
  {
    label = "SendKey",
    run = function()
      Sync.SendKey({
        force = true,
        mapID = 99999,
        level = 999,
        capturedAt = 999999999,
        source = LONG_SOURCE,
      })
    end,
  },
  {
    label = "SendStats",
    run = function()
      Sync.SendStats({
        force = true,
        specID = 99999,
        ilvl = 9999,
        rio = 99999,
        capturedAt = 999999999,
        source = LONG_SOURCE,
      })
    end,
  },
  {
    label = "SendDps",
    run = function()
      Sync.SendDps({
        force = true,
        dps = 999999999,
        capturedAt = 999999999,
        source = LONG_SOURCE,
      })
    end,
  },
  {
    label = "SendLoc",
    run = function()
      Sync.SendLoc({
        force = true,
        mapID = 99999,
        capturedAt = 999999999,
        source = LONG_SOURCE,
      })
    end,
  },
  {
    label = "SendTarget",
    run = function()
      Sync.SendTarget({
        force = true,
        mapID = 99999,
        level = 999,
        capturedAt = 999999999,
        source = LONG_SOURCE,
      })
    end,
  },
  {
    label = "SendKick",
    run = function()
      -- 8-entry extras with maximum spell-ID width (6 digits) and remain (3 digits)
      local extras = {}
      for i = 1, 8 do
        extras[100000 + i] = { cooldownRemain = 999 }
      end
      Sync.SendKick({
        force = true,
        hasKick = true,
        onCooldown = true,
        cooldownRemain = 999,
        extras = extras,
      })
    end,
  },
  {
    label = "SendCombatAnnounce/BR",
    run = function()
      Sync.SendCombatAnnounce({
        kind = "BR",
        caster = LONG_CASTER,
        spellID = 999999,
      })
    end,
  },
  {
    label = "SendCombatAnnounce/LUST",
    run = function()
      Sync.SendCombatAnnounce({
        kind = "LUST",
        caster = LONG_CASTER,
        spellID = 999999,
      })
    end,
  },
  {
    label = "SendRefreshRequest",
    run = function()
      Sync.SendRefreshRequest({ force = true })
    end,
  },
  {
    label = "SendShareKeysRequest",
    run = function()
      Sync.SendShareKeysRequest()
    end,
  },
  {
    label = "SendShareKeysCooldown",
    run = function()
      Sync.SendShareKeysCooldown({ force = true, remain = 99999 })
    end,
  },
  {
    label = "SendLibKeystonePartyData",
    run = function()
      Sync.SendLibKeystonePartyData({
        force = true,
        level = 999,
        mapID = 99999,
        rio = 99999,
      })
    end,
  },
}

local violations = {}
local results = {}

for _, case in ipairs(cases) do
  local label, payload, err = CallAndMeasure(case.label, case.run)
  if err then
    violations[#violations + 1] = string.format("[%s] %s", label, err)
  else
    local n = #payload
    results[#results + 1] = { label = label, length = n, payload = payload }
    if n > SAFETY_BUDGET then
      violations[#violations + 1] = string.format(
        "[%s] worst-case payload is %d bytes (>%d safety budget, >%d MAX = %s) -- payload=%q",
        label,
        n,
        SAFETY_BUDGET,
        MAX_ADDON_MESSAGE_LENGTH,
        n > MAX_ADDON_MESSAGE_LENGTH and "FATAL: server will silently drop" or "WARN: shrinking headroom",
        payload
      )
    end
  end
end

-- Restore previous globals so a future require chain stays clean.
for k in pairs(globals) do
  _G[k] = previous[k]
end

if #violations > 0 then
  io.write(string.format("addon-message-size: %d violation(s) found\n\n", #violations))
  for _, v in ipairs(violations) do
    io.write("  " .. v .. "\n")
  end
  io.write(
    string.format("\n  MAX_ADDON_MESSAGE_LENGTH = %d, safety budget = %d\n", MAX_ADDON_MESSAGE_LENGTH, SAFETY_BUDGET)
  )
  os.exit(1)
end

io.write(
  string.format("addon-message-size: clean -- all %d Send* worst-case payloads <= %d bytes\n", #results, SAFETY_BUDGET)
)
table.sort(results, function(a, b)
  return a.length > b.length
end)
io.write("  Top-5 longest payloads (worst-case):\n")
for i = 1, math.min(5, #results) do
  local r = results[i]
  io.write(string.format("    %2d. %-32s %d bytes\n", i, r.label, r.length))
end

-- Suppress unused-variable warnings.
local _ = LIBKS_PREFIX
os.exit(0)
