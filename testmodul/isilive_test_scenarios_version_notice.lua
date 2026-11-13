---@diagnostic disable: undefined-global
-- Rule 247: update notice. Every scenario boots the real factory and pumps
-- CHAT_MSG_ADDON through the real gated dispatcher
-- (testmodul/isilive_test_mplus_stress_helpers.lua). Peer payloads are built
-- from the bytes the own client puts on the wire, with the version swapped.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

local SYNC_PREFIX = "ISILIVE"
local OWN_VERSION = "0.9.120"
local LOGIN_DELAY = 15
local REPLY_WINDOW = 13

local function PrepareGuild(inGuild)
  return function(globals, session)
    session.chatLines = {}
    local basePrint = globals.print
    globals.print = function(message)
      session.chatLines[#session.chatLines + 1] = tostring(message)
      return basePrint(message)
    end
    globals.IsInGuild = function()
      return inGuild ~= false
    end
  end
end

local function GuildPayloads(session, fromIndex)
  local found = {}
  for index = fromIndex or 1, #session.messages do
    local message = session.messages[index]
    if message.prefix == SYNC_PREFIX and message.channel == "GUILD" then
      found[#found + 1] = message.payload
    end
  end
  return found
end

local function NoticeLines(session)
  local found = {}
  for _, line in ipairs(session.chatLines) do
    if line:find("is available on CurseForge", 1, true) then
      found[#found + 1] = line
    end
  end
  return found
end

-- The login ping is the sender; peer pings reuse its bytes with another version.
local function CaptureOwnPing(ctx, session)
  session.Advance(LOGIN_DELAY)
  local pings = GuildPayloads(session)
  ctx.assert.Equal(#pings, 1, "login must send exactly one guild version ping")
  ctx.assert.Equal(pings[1], "VER:" .. OWN_VERSION, "the guild ping carries the own TOC version")
  return function(version)
    return (pings[1]:gsub(OWN_VERSION:gsub("%.", "%%."), version))
  end
end

return function(test, ctx)
  local Assert = ctx.assert

  -- COMPONENT-ONLY: Compare is a pure function with no event path.
  test("Version notice compares dotted release versions part by part", function()
    local addon = ctx.load_modules({ "isiLive_version_notice.lua" })
    local Compare = addon.VersionNotice.Compare
    Assert.Equal(Compare("0.9.517", "0.9.516"), 1)
    Assert.Equal(Compare("0.9.99", "0.9.516"), -1)
    Assert.Equal(Compare("1.0", "0.9.999"), 1)
    Assert.Equal(Compare("0.9.516", "0.9.516.0"), 0)
    Assert.Nil(Compare("0.9.x", "0.9.516"), "a non-numeric version is no version")
    Assert.Nil(Compare("0..9", "0.9.516"), "an empty part is no version")
    Assert.Nil(Compare("1.2.3.4.5", "0.9.516"), "more than four parts is no version")
    Assert.Nil(Compare(nil, "0.9.516"))
  end)

  test("Version notice prints once per newer group peer version", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local ping = CaptureOwnPing(ctx, session)
      local helloNewer = "HELLO:0.9.130:2:1000:local"
      session.Dispatch("CHAT_MSG_ADDON", SYNC_PREFIX, helloNewer, "PARTY", "Peer1-Realm")
      local lines = NoticeLines(session)
      Assert.Equal(#lines, 1, "a newer group peer must print the update notice")
      Assert.True(lines[1]:find("0.9.130", 1, true) ~= nil, "the notice names the newer version")
      Assert.True(lines[1]:find(OWN_VERSION, 1, true) ~= nil, "the notice names the own version")

      session.Dispatch("CHAT_MSG_ADDON", SYNC_PREFIX, "ACK:0.9.130", "PARTY", "Peer2-Realm")
      session.Dispatch("CHAT_MSG_ADDON", SYNC_PREFIX, "HELLO:0.9.110:2:1000:local", "PARTY", "Peer3-Realm")
      Assert.Equal(#NoticeLines(session), 1, "the same or an older version must not repeat the notice")

      session.Dispatch("CHAT_MSG_ADDON", SYNC_PREFIX, ping("0.9.140"), "GUILD", "Guildie-Realm")
      Assert.Equal(#NoticeLines(session), 2, "an even newer version notifies again")
    end, PrepareGuild(true))
  end)

  test("Version notice stays quiet when the setting is off", function()
    Stress.WithParty(ctx, Fixture, function(session)
      session.globals.IsiLiveDB.versionNoticeEnabled = false
      session.Dispatch("CHAT_MSG_ADDON", SYNC_PREFIX, "HELLO:0.9.130:2:1000:local", "PARTY", "Peer1-Realm")
      session.Dispatch("CHAT_MSG_ADDON", SYNC_PREFIX, "VER:0.9.140", "GUILD", "Guildie-Realm")
      Assert.Equal(#NoticeLines(session), 0, "versionNoticeEnabled=false must suppress the notice")
    end, PrepareGuild(true))
  end)

  test("Version notice answers an older guild ping unless someone else answered first", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local ping = CaptureOwnPing(ctx, session)
      local before = #session.messages + 1
      session.Dispatch("CHAT_MSG_ADDON", SYNC_PREFIX, ping("0.9.100"), "GUILD", "Oldie-Realm")
      session.Advance(REPLY_WINDOW)
      local replies = GuildPayloads(session, before)
      Assert.Equal(#replies, 1, "an older guild ping gets one answer")
      Assert.Equal(replies[1], "VER:" .. OWN_VERSION, "the answer carries the own version")
      Assert.Equal(#NoticeLines(session), 0, "an older version never prints the notice")
      Assert.False(session.addon.Sync.IsUserKnown("Oldie", "Realm"), "a guild ping must not register a sync peer")
      session.Dispatch("CHAT_MSG_ADDON", SYNC_PREFIX, ping("0.9.101"), "GUILD", "Oldie2-Realm")
      session.Advance(REPLY_WINDOW)
      Assert.Equal(#GuildPayloads(session, before), 1, "a second answer within five minutes is suppressed")
      session.Advance(300)
      session.Dispatch("CHAT_MSG_ADDON", SYNC_PREFIX, ping("0.9.102"), "GUILD", "Oldie3-Realm")
      session.Advance(REPLY_WINDOW)
      Assert.Equal(#GuildPayloads(session, before), 2, "after five minutes an older ping is answered again")
    end, PrepareGuild(true))

    Stress.WithParty(ctx, Fixture, function(session)
      local ping = CaptureOwnPing(ctx, session)
      local before = #session.messages + 1
      session.Dispatch("CHAT_MSG_ADDON", SYNC_PREFIX, ping("0.9.100"), "GUILD", "Oldie-Realm")
      session.Dispatch("CHAT_MSG_ADDON", SYNC_PREFIX, ping(OWN_VERSION), "GUILD", "Other-Realm")
      session.Advance(REPLY_WINDOW)
      Assert.Equal(#GuildPayloads(session, before), 0, "a guild answer from another client cancels the own one")
    end, PrepareGuild(true))
  end)

  test("Version notice keeps the guild channel closed to everything but VER", function()
    Stress.WithParty(ctx, Fixture, function(session)
      session.Dispatch("CHAT_MSG_ADDON", SYNC_PREFIX, "KEY:2662:15:1000:local", "GUILD", "Guildie-Realm")
      Assert.Nil(session.addon.Sync.GetPlayerKeyInfo("Guildie", "Realm"), "a guild KEY must be dropped")
      session.Dispatch("CHAT_MSG_ADDON", SYNC_PREFIX, "HELLO:0.9.130:2:1000:local", "GUILD", "Guildie-Realm")
      Assert.Equal(#NoticeLines(session), 0, "a guild HELLO must be dropped")
    end, PrepareGuild(true))
  end)

  test("Version notice sends no guild ping without a guild or with sync off", function()
    Stress.WithParty(ctx, Fixture, function(session)
      session.Advance(LOGIN_DELAY)
      Assert.Equal(#GuildPayloads(session), 0, "no guild, no ping")
    end, PrepareGuild(false))

    Stress.WithParty(ctx, Fixture, function(session)
      session.globals.IsiLiveDB.syncEnabled = false
      session.Advance(LOGIN_DELAY)
      Assert.Equal(#GuildPayloads(session), 0, "syncEnabled=false must suppress the guild ping")
    end, PrepareGuild(true))
  end)
end
