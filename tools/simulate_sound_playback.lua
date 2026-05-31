---@diagnostic disable: undefined-global
-- End-to-end simulation: drive the real SoundUtils helpers and verify that
-- every emitted sound path resolves to a file that actually exists on disk.
--
-- This is the missing piece in the architecture-test coverage: the unit test
-- stubs PlaySoundFile and only asserts on the registry mapping, so a missing
-- OGG file would slip through (WoW PlaySoundFile silently fails on a missing
-- asset; nobody hears anything but no error fires).

local function script_dir()
  local src = debug.getinfo(1, "S").source:sub(2)
  return src:match("^(.*[/\\])") or "./"
end

local addon_root = script_dir() .. ".." .. package.config:sub(1, 1)
local sound_utils_path = addon_root .. "core" .. package.config:sub(1, 1) .. "isiLive_sound_utils.lua"

local addonTable = {}
local fakeDB = {}
_G.IsiLiveDB = fakeDB

local playCalls = {}
_G.PlaySoundFile = function(path, channel)
  playCalls[#playCalls + 1] = { kind = "file", path = path, channel = channel }
end
_G.PlaySound = function(id, channel)
  playCalls[#playCalls + 1] = { kind = "kit", soundKit = id, channel = channel }
end

local fakeNow = 0
_G.GetTime = function()
  return fakeNow
end

local chunk, err = loadfile(
  sound_utils_path,
  "t",
  setmetatable({
    ["..."] = nil,
  }, { __index = _G })
)
if not chunk then
  io.stderr:write("failed to load sound utils: " .. tostring(err) .. "\n")
  os.exit(1)
end

-- Lua addon files use the `local _, addonTable = ...` idiom; we have to invoke
-- them with the same vararg pattern.
local ok, loadErr = pcall(function()
  chunk("isiLive", addonTable)
end)
if not ok then
  io.stderr:write("sound utils chunk raised: " .. tostring(loadErr) .. "\n")
  os.exit(1)
end

local SoundUtils = addonTable.SoundUtils
assert(SoundUtils, "SoundUtils must be exported via addonTable")
assert(SoundUtils.Registry, "SoundUtils.Registry must be present")

local function file_exists(absPath)
  -- absPath is in WoW form: Interface\AddOns\isiLive\sounds\X.ogg
  -- map back to the local source folder.
  local rel = absPath:match("[Ii]siLive[\\/](.+)$")
  if not rel then
    return false, "could not parse asset path: " .. tostring(absPath)
  end
  rel = rel:gsub("\\", "/")
  local full = addon_root .. rel:gsub("/", package.config:sub(1, 1))
  local f = io.open(full, "rb")
  if f then
    f:close()
    return true, full
  end
  return false, full
end

local helpers = {
  {
    key = "leader_transfer",
    fn = function()
      SoundUtils.PlayKey("leader_transfer")
    end,
  },
  { key = "group_join", fn = SoundUtils.PlayGroupJoin },
  { key = "portal_available", fn = SoundUtils.PlayPortalAvailable },
  { key = "portal_available", fn = SoundUtils.PlayIncomingSummon, label = "incoming_summon" },
  { key = "battle_res", fn = SoundUtils.PlayBattleRes },
  { key = "battle_res_ready", fn = SoundUtils.PlayBattleResReady },
  { key = "bloodlust", fn = SoundUtils.PlayBloodlust },
  { key = "bloodlust_ready", fn = SoundUtils.PlayBloodlustReady },
}

local fail = false
print(string.rep("=", 72))
print(" isiLive sound playback simulation (end-to-end)")
print(string.rep("=", 72))

for i, h in ipairs(helpers) do
  fakeNow = i * 10 -- step well past SPAM_WINDOW so every call fires
  local before = #playCalls
  h.fn()
  local after = #playCalls
  local label = h.label or h.key
  if after == before then
    print(
      string.format("  [FAIL] %-22s did not call PlaySound/PlaySoundFile (helper or settings gate dropped it)", label)
    )
    fail = true
  else
    local call = playCalls[after]
    if call.kind == "kit" then
      local kitOk = type(call.soundKit) == "number"
      local status = kitOk and "OK  " or "MISS"
      print(
        string.format("  [%s] %-22s channel=%-7s soundKit=%s", status, label, call.channel, tostring(call.soundKit))
      )
      if not kitOk then
        print(string.format("         SoundKit did not resolve to a numeric id (got %s)", type(call.soundKit)))
        fail = true
      end
    else
      local existsOk, full = file_exists(call.path)
      local status = existsOk and "OK  " or "MISS"
      print(string.format("  [%s] %-22s channel=%-7s path=%s", status, label, call.channel, call.path))
      if not existsOk then
        print(string.format("         expected on disk: %s", full))
        fail = true
      end
    end
    if call.channel ~= "Master" then
      print(string.format("         WRONG CHANNEL: expected Master, got %s", tostring(call.channel)))
      fail = true
    end
  end
end

print(string.rep("-", 72))
print(string.format(" total play calls captured: %d", #playCalls))

-- Cross-check: every Registry entry resolves either to an existing file on
-- disk OR to a numeric SOUNDKIT id present in the (mocked) SOUNDKIT table.
print(string.rep("-", 72))
print(" Registry resolution:")
for _, key in ipairs(SoundUtils.SettingsOrder) do
  local entry = SoundUtils.Registry[key]
  if entry.soundKit ~= nil then
    local resolved = entry.soundKit
    if type(resolved) == "string" then
      resolved = _G.SOUNDKIT and _G.SOUNDKIT[entry.soundKit] or nil
    end
    local kitOk = type(resolved) == "number"
    print(
      string.format(
        "  [%s] %-22s -> SOUNDKIT.%s (id=%s)",
        kitOk and "OK  " or "MISS",
        key,
        tostring(entry.soundKit),
        tostring(resolved)
      )
    )
    if not kitOk then
      print("         SOUNDKIT name did not resolve to a numeric id")
      fail = true
    end
  else
    local existsOk, full = file_exists(entry.file)
    print(string.format("  [%s] %-22s -> %s", existsOk and "OK  " or "MISS", key, entry.file))
    if not existsOk then
      print(string.format("         expected on disk: %s", full))
      fail = true
    end
  end
end

print(string.rep("=", 72))
if fail then
  print(" RESULT: FAIL — at least one sound asset is missing from disk")
  os.exit(1)
end
print(" RESULT: PASS — every helper emits an existing asset on the Master channel")
