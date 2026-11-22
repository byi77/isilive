---@diagnostic disable: undefined-global, undefined-field
-- Defensive / external cooldowns, stage 1 (rule 267): manifest, own tracker,
-- DEF sync bucket and store. The flows boot the real factory through the
-- stress fixture, cast through the real dispatcher (UNIT_SPELLCAST_SUCCEEDED
-- delivered to the registered isiLive frame) and let the production ticker
-- run. Sender -> receiver uses the bytes the sender handed to the mocked
-- C_ChatInfo.SendAddonMessage, replayed as a peer's CHAT_MSG_ADDON through the
-- real event frame. Only client APIs are stubbed: spellbook, cooldowns,
-- charges, auras, C_Secrets and the addon chat lockdown.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

local PAIN_SUPPRESSION = 33206
local PW_BARRIER = 62618
local PW_BARRIER_AURA = 81782
local DESPERATE_PRAYER = 19236
local PEER = "Peer1-Realm"

-- Masked client value: any comparison or arithmetic raises like the client.
local SECRET = setmetatable({}, {
  __lt = function()
    error("attempt to compare a secret value")
  end,
  __le = function()
    error("attempt to compare a secret value")
  end,
  __add = function()
    error("attempt to perform arithmetic on a secret value")
  end,
  __sub = function()
    error("attempt to perform arithmetic on a secret value")
  end,
  __concat = function()
    error("attempt to concatenate a secret value")
  end,
})

-- Former SpellManifest.defensiveProbe aura IDs (2026-11-21); the probe keeps them.
local FORMER_PROBE_AURAS = {
  33206,
  47788,
  102342,
  116849,
  6940,
  1022,
  357170,
  145629,
  209426,
  97463,
  325174,
  81782,
  31821,
  48792,
  48707,
  212800,
  22812,
  61336,
  363916,
  186265,
  45438,
  120954,
  642,
  498,
  31850,
  86659,
  47585,
  19236,
  31224,
  5277,
  1966,
  108271,
  104773,
  871,
  12975,
  118038,
  184364,
}

local function Prepare(enabled)
  return function(globals, session)
    session.lockdown = false
    session.known = { [PAIN_SUPPRESSION] = true, [PW_BARRIER] = true, [DESPERATE_PRAYER] = true }
    session.cooldowns = {}
    session.charges = {}
    session.auras = {}
    session.secretCooldown = {}
    globals.IsiLiveDB.defensiveTrackerEnabled = enabled
    globals.issecretvalue = function(value)
      return rawequal(value, SECRET)
    end
    globals.UnitClass = function(unit)
      if unit == "player" then
        return "Priest", "PRIEST", 5
      end
      return "Mage", "MAGE", 8
    end
    globals.C_ChatInfo.InChatMessagingLockdown = function()
      return session.lockdown
    end
    globals.C_SpellBook = {
      IsSpellKnown = function(spellID)
        return session.known[spellID] == true
      end,
    }
    globals.C_Secrets = {
      ShouldSpellCooldownBeSecret = function(spellID)
        return session.secretCooldown[spellID] == true
      end,
    }
    local baseCooldown = globals.C_Spell.GetSpellCooldown
    globals.C_Spell.GetSpellCooldown = function(spellID)
      local cooldown = session.cooldowns[spellID]
      if cooldown then
        return {
          startTime = cooldown.start,
          duration = cooldown.duration,
          isEnabled = true,
          isActive = cooldown.active,
          isOnGCD = cooldown.onGCD,
          modRate = 1,
        }
      end
      return baseCooldown(spellID)
    end
    globals.C_Spell.GetSpellCharges = function(spellID)
      return session.charges[spellID]
    end
    globals.C_UnitAuras.GetPlayerAuraBySpellID = function(auraID)
      return session.auras[auraID]
    end
  end
end

local function DefMessages(session)
  local out = {}
  for _, message in ipairs(session.messages) do
    if message.prefix == "ISILIVE" and string.find(message.payload, "^DEF:") then
      out[#out + 1] = message
    end
  end
  return out
end

local function LastDefPayload(session)
  local list = DefMessages(session)
  return list[#list] and list[#list].payload or nil
end

local function CountPayload(session, payload)
  local count = 0
  for _, message in ipairs(session.messages) do
    if message.prefix == "ISILIVE" and message.payload == payload then
      count = count + 1
    end
  end
  return count
end

local function Cast(session, spellID)
  session.DispatchToFrames("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-" .. tostring(spellID), spellID)
end

local function Receive(session, payload, sender)
  session.Dispatch("CHAT_MSG_ADDON", "ISILIVE", payload, "PARTY", sender or PEER)
end

local function PeerKey(session, sender)
  return session.addon.Sync.NormalizePlayerKey(sender or PEER)
end

local function PeerView(session, sender)
  return session.addon.DefensiveStore.GetForPlayer(PeerKey(session, sender), session.now)
end

local function FindEntry(view, spellID)
  for _, entry in ipairs(view.entries) do
    if entry.spellID == spellID then
      return entry
    end
  end
  return nil
end

local function StartPainSuppression(session, ago)
  session.cooldowns[PAIN_SUPPRESSION] = { start = session.now - (ago or 0), duration = 180 }
end

local function RegisterManifestTests(test, ctx)
  local Assert = ctx.assert

  test("Defensive manifest covers every class with a personal defensive and only manifest spec IDs", function()
    local addon = ctx.load_modules({ "isiLive_defensives.lua", "isiLive_specs.lua" })
    local manifest, specs = addon.DefensiveManifest, addon.SpecManifest.specs
    local personalByClass = {}
    local count = 0
    for castID, record in pairs(manifest.spells) do
      count = count + 1
      Assert.True(manifest.kindOrder[record.kind] ~= nil, "known kind for " .. castID)
      Assert.True(type(record.aura) == "number", "aura ID for " .. castID)
      Assert.True(record.cooldown == nil or record.cooldown > 0, "cooldown is nil or positive for " .. castID)
      for _, specID in ipairs(record.specs or {}) do
        Assert.NotNil(specs[specID], string.format("spec %d of %d is in data/isiLive_specs.lua", specID, castID))
        Assert.Equal(
          specs[specID].class,
          record.class,
          string.format("spec %d belongs to the class of %d", specID, castID)
        )
      end
      if record.kind == "personal" then
        personalByClass[record.class] = true
      end
    end
    Assert.Equal(count, #manifest.list, "every list record is in the cast map once")
    local classes = {}
    for _, spec in pairs(specs) do
      classes[spec.class] = true
    end
    for class in pairs(classes) do
      Assert.True(personalByClass[class] == true, class .. " has at least one personal defensive")
    end
  end)

  test("Defensive manifest keeps the former probe aura list for the aura container probe", function()
    local addon = ctx.load_modules({ "isiLive_defensives.lua" })
    local probeAuras = {}
    for _, record in ipairs(addon.DefensiveManifest.list) do
      if record.probe == true then
        probeAuras[#probeAuras + 1] = record.aura
      end
    end
    Assert.Equal(#probeAuras, #FORMER_PROBE_AURAS, "same probe list length")
    for index, auraID in ipairs(FORMER_PROBE_AURAS) do
      Assert.Equal(probeAuras[index], auraID, "same probe order at " .. index)
    end
    Assert.Equal(addon.DefensiveManifest.forbearance, 25771, "Forbearance moved along")
  end)

  test("Game data check verifies defensive cooldowns and specs against DB2", function()
    local tool = assert(loadfile("tools/check_db2.lua"))("module")
    local tables = {
      cooldownsBySpell = {
        [100] = { { SpellID = "100", DifficultyID = "0", RecoveryTime = "120000", CategoryRecoveryTime = "0" } },
        [200] = { { SpellID = "200", DifficultyID = "0", RecoveryTime = "1500", CategoryRecoveryTime = "0" } },
      },
      categoriesBySpell = { [200] = { { SpellID = "200", DifficultyID = "0", ChargeCategory = "7" } } },
      categoryByID = { [7] = { ID = "7", ChargeRecoveryTime = "180000" } },
    }
    Assert.Equal(tool.DeriveCooldownSeconds(100, tables), 120, "plain recovery time")
    Assert.Equal(tool.DeriveCooldownSeconds(200, tables), 180, "the charge category wins over the GCD row")
    Assert.Nil(tool.DeriveCooldownSeconds(300, tables), "no row, no cooldown")
    local data = {
      SpellManifest = { battleRes = {}, lustCasts = {}, lustSated = {}, icons = {} },
      InterruptManifest = { specs = {}, classAlternatives = {}, extraCooldowns = {} },
      DefensiveManifest = {
        spells = {
          [100] = { aura = 101, name = "A", kind = "personal", class = "WARRIOR", specs = { 71 }, cooldown = 120 },
          [200] = { aura = 200, name = "B", kind = "external", class = "PRIEST", specs = { 71 }, cooldown = 90 },
        },
      },
      SpecManifest = { specs = { [71] = { class = "WARRIOR" } } },
      -- An empty configured rotation matches the empty tracked-map table.
      SeasonManifest = { seasons = { fixture = { dungeons = {} } } },
    }
    local db2 = {
      spellIDs = { [100] = true, [101] = true, [200] = true },
      itemIDs = {},
      maps = {},
      activities = {},
      specs = { { ID = "71", ClassID = "1", OrderIndex = "0", Name_lang = "Arms" } },
      tracked = {},
      flyoutItems = {},
      cooldownTables = tables,
    }
    local code, report = tool.Evaluate(db2, data, { version = "1.2.3.4" })
    Assert.Equal(code, 1, "findings fail the check")
    Assert.True(report:find("ERROR defensive 200 (B): spec 71 is no PRIEST spec", 1, true) ~= nil, "foreign spec")
    Assert.True(report:find("ERROR defensive cooldown 200 (B): manifest 90 s, DB2 180 s", 1, true) ~= nil, "drift")
    Assert.Nil(report:find("defensive cooldown 100", 1, true), "a matching cooldown passes")
    db2.cooldownTables = nil
    local _, skipped = tool.Evaluate(db2, data, { version = "1.2.3.4" })
    Assert.True(skipped:find("cooldowns not checked", 1, true) ~= nil, "without the tables the check says so")
  end)
end

local function RegisterCodecTests(test, ctx)
  local Assert = ctx.assert

  -- COMPONENT-ONLY: the encoder is a pure function; the wire flows below run
  -- it through the real sender.
  test("Defensive codec encodes sorted entries and drops an unusable one as a whole", function()
    local addon = ctx.load_modules({ "isiLive_sync.lua" })
    local Codec = addon.SyncCodec
    local payload, key = Codec.EncodeDefPayload({
      { spellID = DESPERATE_PRAYER, state = "ready", remain = 0 },
      { spellID = PAIN_SUPPRESSION, state = "cd", remain = 12.2 },
      { spellID = PW_BARRIER, state = "active", remain = 170, charges = 1 },
    })
    Assert.Equal(payload, "DEF:19236,1,0;33206,0,13;62618,2,170,1", "numerically sorted, ceil remain")
    Assert.Equal(key, "DEF:19236,1;33206,0;62618,2,1", "dedupe key without the remain")
    Assert.Equal(Codec.EncodeDefPayload({}), "DEF:-", "an empty list")
    Assert.Nil(Codec.EncodeDefPayload({ { spellID = 99999, state = "ready", remain = 0 } }), "foreign ID")
    Assert.Nil(Codec.EncodeDefPayload({ { spellID = PAIN_SUPPRESSION, state = "ready", remain = 3601 } }), "range")
    Assert.Nil(Codec.EncodeDefPayload({ { spellID = PAIN_SUPPRESSION, state = "x", remain = 0 } }), "state")
  end)
end

local function RegisterTalentTests(test, ctx)
  local Assert = ctx.assert

  -- COMPONENT-ONLY: the reader is a pure read of C_Traits; the inspect flow
  -- that calls it has its own tests.
  test("Defensive talents read the taken manifest talents and keep nothing unreadable", function()
    local nodes = {
      [1] = { entryIDs = { 11 }, activeRank = 1, activeEntry = { entryID = 11 } },
      [2] = { entryIDs = { 21, 22 }, activeRank = 1, activeEntry = { entryID = 22 } },
      [3] = { entryIDs = { 31 }, activeRank = 0 },
    }
    local spells = { [11] = PAIN_SUPPRESSION, [21] = DESPERATE_PRAYER, [22] = 1, [31] = PW_BARRIER }
    local valid = true
    ctx.with_globals({
      issecretvalue = function(value)
        return rawequal(value, SECRET)
      end,
      UnitGUID = function(unit)
        return "guid-" .. unit
      end,
      C_Traits = {
        HasValidInspectData = function()
          return valid
        end,
        GetConfigInfo = function(configID)
          return configID == -1 and { treeIDs = { 900 } } or nil
        end,
        GetTreeNodes = function()
          return { 1, 2, 3 }
        end,
        GetNodeInfo = function(_, nodeID)
          return nodes[nodeID]
        end,
        GetEntryInfo = function(_, entryID)
          return { definitionID = entryID }
        end,
        GetDefinitionInfo = function(definitionID)
          return { spellID = spells[definitionID] }
        end,
      },
    }, function()
      local addon = ctx.load_modules({
        "isiLive_validation_helpers.lua",
        "isiLive_defensives.lua",
        "isiLive_defensive_talents.lua",
      })
      local talents = addon.DefensiveTalents
      Assert.True(talents.CaptureInspect("guid-party1"), "a readable inspect is kept")
      local taken = talents.GetTalents("party1")
      Assert.True(taken[PAIN_SUPPRESSION] == true, "taken")
      Assert.False(taken[DESPERATE_PRAYER], "the other choice of the node")
      Assert.False(taken[PW_BARRIER], "no rank")
      Assert.Nil(talents.GetTalents("party2"), "never inspected: unknown")
      nodes[1].activeRank = SECRET
      Assert.False(talents.CaptureInspect("guid-party2"), "a masked rank keeps nothing")
      Assert.Nil(talents.GetTalents("party2"), "still unknown")
      valid = false
      Assert.False(talents.CaptureInspect("guid-party3"), "no valid inspect data")
    end)
  end)
end

local function RegisterSettingsTests(test, ctx)
  local Assert = ctx.assert

  test("Defensive tracker settings default off: nothing is tracked, stored or sent", function()
    local addon = ctx.load_modules({ "isiLive_db_schema.lua" })
    local db = {}
    addon.DBSchema.Sanitize(db)
    Assert.Equal(db.defensiveTrackerEnabled, false, "schema default of the feature switch")

    Stress.WithKey(ctx, Fixture, function(session)
      session.messages = {}
      StartPainSuppression(session, 0)
      Cast(session, PAIN_SUPPRESSION)
      session.Advance(20)
      Assert.Equal(#DefMessages(session), 0, "no DEF message with the feature off")
      local store = session.addon.DefensiveStore
      Assert.Nil(store.GetOwnKey(), "the tracker never started")
      Assert.Equal(store.GetForPlayer("tester-realm", session.now).source, "none", "no own state")
      Receive(session, "DEF:33206,1,0")
      Assert.Equal(PeerView(session).source, "none", "a peer DEF is not stored with the feature off")
    end, Prepare(nil))
  end)

  test("Defensive sync follows the main switch", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.messages = {}
      session.Advance(20)
      Assert.True(#DefMessages(session) > 0, "the one switch shares the own state")
      Receive(session, "DEF:33206,1,0")
      Assert.Equal(PeerView(session).source, "sync", "and takes a peer's")
    end, Prepare(true))
  end)
end

local function RegisterWireTests(test, ctx)
  local Assert = ctx.assert

  test("Defensive sync carries the own state from sender to receiver through the real wire bytes", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.messages = {}
      StartPainSuppression(session, 0)
      Cast(session, PAIN_SUPPRESSION)
      session.Advance(1)
      local payload = LastDefPayload(session)
      Assert.Equal(payload, "DEF:19236,1,0;33206,0,180;62618,1,0", "the cast goes out at once with the own state")
      Assert.Equal(DefMessages(session)[1].channel, "PARTY", "on the group channel")

      Receive(session, payload)
      local view = PeerView(session)
      Assert.Equal(view.source, "sync", "the receiver stores the peer state")
      Assert.Nil(view.frozenAt, "not frozen")
      Assert.Equal(view.entries[1].spellID, PAIN_SUPPRESSION, "external first")
      Assert.Equal(view.entries[2].spellID, PW_BARRIER, "then the group cooldown")
      Assert.Equal(view.entries[3].spellID, DESPERATE_PRAYER, "then the personal one")
      Assert.Equal(view.entries[1].state, "cd", "cooldown state")
      Assert.Equal(view.entries[1].remain, 180, "remain as sent")
      session.Advance(10)
      Assert.Equal(FindEntry(PeerView(session), PAIN_SUPPRESSION).remain, 170, "counts down locally from receipt")
      Assert.Equal(PeerView(session).ageSeconds, 10, "age since receipt")

      -- Sent at cast + 0.2 s; now cast + 11 s.
      local before = #DefMessages(session)
      session.Advance(3)
      Assert.Equal(#DefMessages(session), before, "a running remain alone sends nothing")
      session.Advance(2)
      Assert.Equal(#DefMessages(session), before + 1, "the 15 s heartbeat repeats the state")

      Receive(session, payload, "Tester-Realm")
      local store = session.addon.DefensiveStore
      Assert.Equal(store.GetForPlayer(store.GetOwnKey(), session.now).source, "own", "the own echo is ignored")
    end, Prepare(true))
  end)

  test("Defensive receiver drops broken, oversized and foreign payloads as a whole", function()
    Stress.WithKey(ctx, Fixture, function(session)
      local nine = {}
      for _, id in ipairs({ 498, 642, 871, 1022, 1966, 5277, 6940, 12975, 19236 }) do
        nine[#nine + 1] = id .. ",1,0"
      end
      local long = {}
      for _, id in ipairs({ 102342, 104773, 108271, 116849, 118038, 145629, 184364, 186265 }) do
        long[#long + 1] = id .. ",0,3600,9"
      end
      local broken = {
        "DEF:33206,1,0;99999,1,0", -- foreign ID
        "DEF:145629,1,0", -- aura ID, not a cast ID
        "DEF:33206,3,0", -- unknown state
        "DEF:33206,1,3601", -- remain out of range
        "DEF:33206,1,0,10", -- charges out of range
        "DEF:62618,1,0;33206,1,0", -- not sorted
        "DEF:33206,1,0;33206,1,0", -- duplicate
        "DEF:033206,1,0", -- non-canonical number
        "DEF:33206,1,0;", -- trailing separator
        "DEF:33206,1", -- missing remain
        "DEF:", -- empty
        "DEF:" .. table.concat(nine, ";"), -- more than 8 entries
        "DEF:" .. table.concat(long, ";") .. ";19236,1,0", -- over 140 bytes
      }
      for _, payload in ipairs(broken) do
        Receive(session, payload)
        Assert.Equal(PeerView(session).source, "none", "dropped: " .. payload)
        Assert.Nil(session.addon.SyncCodec.ParseDefPayload(payload), "parser rejects: " .. payload)
      end
      Receive(session, "DEF:-")
      local view = PeerView(session)
      Assert.Equal(view.source, "sync", "an empty list is a valid state")
      Assert.Equal(#view.entries, 0, "with no entries")
    end, Prepare(true))
  end)
end

local function RegisterLockdownTests(test, ctx)
  local Assert = ctx.assert

  test("Defensive sync sends nothing in the chat lockdown and forces the first send after it", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.Advance(2)
      session.lockdown = true
      session.messages = {}
      StartPainSuppression(session, 0)
      Cast(session, PAIN_SUPPRESSION)
      session.Advance(30)
      Assert.Equal(#DefMessages(session), 0, "nothing is dispatched while addon chat is locked down")
      Assert.Equal(CountPayload(session, "REQSYNC"), 0, "and no REQSYNC")

      session.lockdown = false
      session.Advance(1)
      Assert.Equal(#DefMessages(session), 1, "the first tick after the lockdown sends the state")
      Assert.Equal(LastDefPayload(session), "DEF:19236,1,0;33206,0,149;62618,1,0", "the current state")
      Assert.Equal(CountPayload(session, "REQSYNC"), 1, "the thaw asks the peers for their state")
    end, Prepare(true))
  end)

  test("Defensive store freezes peers in the own lockdown, shows their age and thaws with a REQSYNC", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.messages = {}
      StartPainSuppression(session, 0)
      Cast(session, PAIN_SUPPRESSION)
      session.Advance(1)
      Receive(session, LastDefPayload(session))
      session.Advance(5)
      session.lockdown = true
      session.Advance(1)
      local store = session.addon.DefensiveStore
      Assert.True(store.IsFrozen(), "the own lockdown freezes the store")
      local frozenRemain = FindEntry(PeerView(session), PAIN_SUPPRESSION).remain
      session.Advance(300)
      local view = PeerView(session)
      Assert.Equal(view.source, "sync", "the last peer state stays visible")
      Assert.NotNil(view.frozenAt, "marked frozen")
      Assert.Equal(FindEntry(view, PAIN_SUPPRESSION).remain, frozenRemain, "no countdown while frozen")
      Assert.True(view.ageSeconds >= 300, "the age keeps growing")

      session.lockdown = false
      session.Advance(1)
      Assert.False(store.IsFrozen(), "thawed")
      Assert.Equal(CountPayload(session, "REQSYNC"), 1, "REQSYNC after the lockdown")
      Assert.Equal(PeerView(session).source, "none", "the old record is stale after the thaw (fail-closed)")
    end, Prepare(true))
  end)

  test("Defensive peer records expire 60 s without a heartbeat", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.messages = {}
      session.Advance(1)
      Receive(session, LastDefPayload(session) or "DEF:-")
      session.Advance(59)
      Assert.Equal(PeerView(session).source, "sync", "still valid after 59 s")
      session.Advance(2)
      Assert.Equal(PeerView(session).source, "none", "expired after 60 s without a message")
    end, Prepare(true))
  end)
end

local function RegisterContextTests(test, ctx)
  local Assert = ctx.assert

  test("Defensive tracker stays off in a raid and drops what it held", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.Advance(1)
      Receive(session, LastDefPayload(session) or "DEF:-")
      Assert.Equal(PeerView(session).source, "sync", "peer stored in the party")
      session.raid = true
      session.Dispatch("GROUP_ROSTER_UPDATE")
      session.messages = {}
      session.Advance(20)
      Assert.Equal(#DefMessages(session), 0, "no DEF in a raid")
      Assert.Equal(PeerView(session).source, "none", "the store answers none in a raid")
      session.raid = false
      Assert.Equal(PeerView(session).source, "none", "and kept nothing from before")
    end, Prepare(true))
  end)

  test("Defensive tracker runs only in the KEY profile", function()
    Stress.WithParty(ctx, Fixture, function(session)
      session.messages = {}
      Cast(session, PAIN_SUPPRESSION)
      session.Dispatch("PLAYER_ENTERING_WORLD")
      session.Advance(20)
      Assert.Equal(#DefMessages(session), 0, "no DEF outside a mythic dungeon")
      Receive(session, "DEF:33206,1,0")
      Assert.Equal(PeerView(session).source, "none", "no peer record outside the KEY profile")
      local store = session.addon.DefensiveStore
      Assert.Equal(store.GetForPlayer("tester-realm", session.now).source, "none", "no own state either")
    end, function(globals, session)
      Prepare(true)(globals, session)
      globals.GetInstanceInfo = function()
        return "Dornogal", "none", 0, "", 5, false, false, 2552
      end
    end)
  end)
end

local function RegisterOwnStateTests(test, ctx)
  local Assert = ctx.assert

  test("Defensive tracker reads cooldown, charges and the own buff from the live client", function()
    Stress.WithKey(ctx, Fixture, function(session)
      StartPainSuppression(session, 30)
      session.charges[DESPERATE_PRAYER] = {
        currentCharges = 1,
        maxCharges = 2,
        cooldownStartTime = session.now - 10,
        cooldownDuration = 90,
        chargeModRate = 1,
        isActive = true,
      }
      session.cooldowns[PW_BARRIER] = { start = session.now - 2, duration = 180 }
      session.auras[PW_BARRIER_AURA] = { spellId = PW_BARRIER_AURA, sourceUnit = "player" }
      session.known[47788] = nil
      Cast(session, PW_BARRIER)
      session.Advance(1)
      local store = session.addon.DefensiveStore
      local view = store.GetForPlayer(store.GetOwnKey(), session.now)
      Assert.Equal(view.source, "own", "own state")
      Assert.Equal(#view.entries, 3, "only the spells the player knows")
      local pain = FindEntry(view, PAIN_SUPPRESSION)
      Assert.Equal(pain.state, "cd", "cooldown from C_Spell.GetSpellCooldown")
      Assert.Equal(pain.remain, 149, "remain from start and duration")
      local barrier = FindEntry(view, PW_BARRIER)
      Assert.Equal(barrier.state, "active", "the own buff runs")
      local prayer = FindEntry(view, DESPERATE_PRAYER)
      Assert.Equal(prayer.state, "ready", "one of two charges left")
      Assert.Equal(prayer.charges, 1, "charge count")
      Assert.Equal(prayer.remain, 79, "time to the next charge")
      -- Sent by the re-read 0.2 s after the cast (remain rounded up).
      Assert.Equal(LastDefPayload(session), "DEF:19236,1,80,1;33206,0,150;62618,2,178", "and that goes out")
    end, Prepare(true))
  end)

  test("Defensive tracker leaves a spell out when the client masks its cooldown", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.secretCooldown[PAIN_SUPPRESSION] = true
      session.cooldowns[PW_BARRIER] = { start = SECRET, duration = 180 }
      session.auras[PW_BARRIER_AURA] = SECRET
      session.charges[DESPERATE_PRAYER] = {
        currentCharges = SECRET,
        maxCharges = 2,
        cooldownStartTime = 0,
        cooldownDuration = 90,
      }
      session.DispatchToFrames("UNIT_SPELLCAST_SUCCEEDED", "player", SECRET, SECRET)
      Cast(session, PAIN_SUPPRESSION)
      session.Advance(2)
      local store = session.addon.DefensiveStore
      local view = store.GetForPlayer(store.GetOwnKey(), session.now)
      Assert.Equal(view.source, "own", "the own state exists")
      Assert.Equal(#view.entries, 0, "without the NeverSecret state every masked spell is left out")
      Assert.True(LastDefPayload(session) ~= "DEF:-", "masked is not none: no empty list goes out")
    end, Prepare(true))
  end)
end

-- A key as logged on 2026-11-21: every cooldown number is masked, isActive,
-- isEnabled and isOnGCD stay plain (NeverSecret).
local function MaskAll(session, states)
  for _, spellID in ipairs({ PAIN_SUPPRESSION, PW_BARRIER, DESPERATE_PRAYER }) do
    local state = states[spellID] or {}
    session.secretCooldown[spellID] = true
    session.cooldowns[spellID] = { start = SECRET, duration = SECRET, active = state.active == true, onGCD = state.gcd }
  end
end

local function RegisterMaskedCooldownTests(test, ctx)
  local Assert = ctx.assert

  test("Defensive tracker keeps ready and cooldown of a masked cooldown from the NeverSecret fields", function()
    Stress.WithKey(ctx, Fixture, function(session)
      MaskAll(session, { [PAIN_SUPPRESSION] = { active = true }, [PW_BARRIER] = { active = true, gcd = true } })
      Cast(session, PAIN_SUPPRESSION)
      session.Advance(2)
      local store = session.addon.DefensiveStore
      local view = store.GetForPlayer(store.GetOwnKey(), session.now)
      Assert.Equal(#view.entries, 3, "no masked spell disappears")
      local pain = FindEntry(view, PAIN_SUPPRESSION)
      Assert.Equal(pain.state, "cd", "isActive is a cooldown")
      Assert.True(pain.hidden == true, "without a number")
      Assert.Equal(FindEntry(view, PW_BARRIER).state, "ready", "the global cooldown is no cooldown")
      Assert.Equal(FindEntry(view, DESPERATE_PRAYER).state, "ready", "inactive is ready")
      session.Advance(30)
      view = store.GetForPlayer(store.GetOwnKey(), session.now)
      Assert.Equal(FindEntry(view, PAIN_SUPPRESSION).state, "cd", "a hidden cooldown never runs out by itself")
      session.cooldowns[PAIN_SUPPRESSION].active = false
      session.Advance(2)
      view = store.GetForPlayer(store.GetOwnKey(), session.now)
      Assert.Equal(FindEntry(view, PAIN_SUPPRESSION).state, "ready", "the client ends it")
    end, Prepare(true))
  end)

  test("Defensive sync never replaces a good state with a masked, empty or partial one", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.Advance(2)
      session.messages = {}
      -- Map 249: cooldowns still masked after the key, addon chat already open.
      MaskAll(session, {})
      Cast(session, PAIN_SUPPRESSION)
      session.Advance(20)
      Assert.Equal(#DefMessages(session), 0, "all masked: nothing goes out")
      session.secretCooldown[PW_BARRIER] = nil
      session.cooldowns[PW_BARRIER] = nil
      session.Advance(20)
      Assert.Equal(#DefMessages(session), 0, "partly masked: no shorter list")
      session.secretCooldown, session.cooldowns = {}, {}
      session.Advance(16)
      Assert.Equal(LastDefPayload(session), "DEF:19236,1,0;33206,1,0;62618,1,0", "readable again: the full list")
    end, Prepare(true))
  end)

  test("Defensive cell draws a masked own cooldown through the duration object", function()
    local durationObject = {}
    local applied = {}
    local function PrepareWidgets(globals, session)
      Prepare(true)(globals, session)
      globals.C_Spell.GetSpellCooldownDuration = function(spellID, ignoreGCD)
        session.askedDuration = { spellID, ignoreGCD }
        return durationObject
      end
      local createFrame = globals.CreateFrame
      globals.CreateFrame = function(frameType, ...)
        local frame = createFrame(frameType, ...)
        if frameType == "Cooldown" then
          function frame:SetCooldownFromDurationObject(object)
            applied[#applied + 1] = { frame = self, object = object }
          end
        end
        return frame
      end
    end
    Stress.WithKey(ctx, Fixture, function(session)
      MaskAll(session, { [PAIN_SUPPRESSION] = { active = true } })
      Cast(session, PAIN_SUPPRESSION)
      session.Advance(2)
      local cell = session.addon.RosterDefensiveCell
      local row, parent = {}, session.globals.CreateFrame("Frame")
      cell.ApplyRow(row, { name = "Tester", realm = "Realm" }, parent, 1, session.now)
      local slot = row.defCell.slots[1]
      Assert.Equal(slot.state, "cd", "the own slot shows the cooldown")
      Assert.Equal(applied[#applied].object, durationObject, "Blizzard gets the duration object untouched")
      Assert.Equal(session.askedDuration[1], PAIN_SUPPRESSION, "for this spell")
      Assert.True(session.askedDuration[2] == true, "without the global cooldown")
      Assert.True(slot.countdown:IsShown(), "the countdown shows")
      session.cooldowns[PAIN_SUPPRESSION].active = false
      session.Advance(2)
      cell.ApplyRow(row, { name = "Tester", realm = "Realm" }, parent, 1, session.now)
      Assert.Equal(slot.state, "ready", "ready again")
      Assert.False(slot.countdown:IsShown(), "and the countdown is gone")
    end, PrepareWidgets)
  end)
end

local function RegisterOwnStateFallbackTests(test, ctx)
  local Assert = ctx.assert

  local function OwnView(session)
    local store = session.addon.DefensiveStore
    return store.GetForPlayer(store.GetOwnKey(), session.now)
  end

  local function Reread(session)
    Cast(session, PAIN_SUPPRESSION)
    session.Advance(1)
    return OwnView(session)
  end

  test("Defensive tracker falls back to the duration object and fails closed on an unreadable one", function()
    Stress.WithKey(ctx, Fixture, function(session)
      local durations = {}
      local function Duration(remain, secret)
        return {
          HasSecretValues = function()
            return secret
          end,
          GetRemainingDuration = function()
            return remain
          end,
        }
      end
      session.globals.C_Spell.GetSpellCooldown = nil
      session.globals.C_Spell.GetSpellCooldownDuration = function(spellID)
        return durations[spellID]
      end

      durations[PAIN_SUPPRESSION] = Duration(120, false)
      durations[PW_BARRIER] = Duration(1.5, false)
      durations[DESPERATE_PRAYER] = Duration(50, true)
      local view = Reread(session)
      Assert.Equal(#view.entries, 2, "a duration object with secret values is left out")
      Assert.Equal(FindEntry(view, PAIN_SUPPRESSION).state, "cd", "cooldown from the duration object")
      Assert.Equal(FindEntry(view, PW_BARRIER).state, "ready", "the global cooldown is no cooldown")

      durations[PAIN_SUPPRESSION] = Duration(SECRET, false)
      durations[PW_BARRIER] = {}
      durations[DESPERATE_PRAYER] = {
        HasSecretValues = function()
          return false
        end,
      }
      Assert.Equal(#Reread(session).entries, 0, "secret or incomplete duration objects are left out")

      durations[PAIN_SUPPRESSION], durations[PW_BARRIER], durations[DESPERATE_PRAYER] = nil, nil, nil
      Assert.Equal(#Reread(session).entries, 0, "no duration object, no state")
    end, Prepare(true))
  end)

  test("Defensive tracker reads empty charges as cooldown and drops states without a known remain", function()
    Stress.WithKey(ctx, Fixture, function(session)
      local cooldown = { startTime = 0, duration = 0, isEnabled = false }
      session.globals.C_Spell.GetSpellCooldown = function(spellID)
        if spellID == PW_BARRIER then
          return cooldown
        end
        return { startTime = 0, duration = 0, isEnabled = true }
      end
      local charges = {
        currentCharges = 0,
        maxCharges = 2,
        cooldownStartTime = session.now,
        cooldownDuration = 90,
      }
      session.charges[DESPERATE_PRAYER] = charges
      session.charges[PAIN_SUPPRESSION] = { maxCharges = 0 }
      local view = Reread(session)
      local prayer = FindEntry(view, DESPERATE_PRAYER)
      Assert.Equal(prayer.state, "cd", "no charge left")
      Assert.Equal(prayer.charges, 0, "zero charges")
      Assert.Equal(FindEntry(view, PAIN_SUPPRESSION).state, "ready", "no charge spell reads the cooldown")
      Assert.Nil(FindEntry(view, PW_BARRIER), "an on-hold cooldown has no known remain")

      cooldown.isEnabled = true
      cooldown.startTime, cooldown.duration = session.now - 200, 180
      charges.cooldownStartTime = session.now - 100
      view = Reread(session)
      Assert.Equal(FindEntry(view, PW_BARRIER).state, "ready", "an expired cooldown is ready")
      Assert.Nil(FindEntry(view, DESPERATE_PRAYER), "zero charges without a remain are not guessed")

      session.globals.C_Spell.GetSpellCooldown = function()
        error("client refused")
      end
      Assert.Equal(#Reread(session).entries, 0, "a failing cooldown read leaves the spell out")
    end, Prepare(true))
  end)

  test("Defensive tracker fails closed when the client cannot answer class, spellbook or secrecy", function()
    local function PrepareWith(change)
      return function(globals, session)
        Prepare(true)(globals, session)
        change(globals)
      end
    end

    Stress.WithKey(
      ctx,
      Fixture,
      function(session)
        local view = Reread(session)
        Assert.Equal(#view.entries, 1, "IsPlayerSpell stands in for the missing spellbook API")
        Assert.Equal(view.entries[1].spellID, PAIN_SUPPRESSION, "only the spell it confirms")

        session.globals.C_Secrets.ShouldSpellCooldownBeSecret = function()
          return SECRET
        end
        Assert.Equal(#Reread(session).entries, 0, "a secret answer about secrecy counts as secret")
        session.globals.C_Secrets.ShouldSpellCooldownBeSecret = function()
          error("client refused")
        end
        Assert.Equal(#Reread(session).entries, 0, "a failing secrecy check counts as secret")
      end,
      PrepareWith(function(globals)
        globals.C_SpellBook = {}
        globals.IsPlayerSpell = function(spellID)
          return spellID == PAIN_SUPPRESSION
        end
      end)
    )

    Stress.WithKey(
      ctx,
      Fixture,
      function(session)
        Assert.Equal(#Reread(session).entries, 0, "an unknown spellbook answer is not known")
      end,
      PrepareWith(function(globals)
        globals.C_SpellBook = {}
        globals.IsPlayerSpell = function()
          return SECRET
        end
      end)
    )

    Stress.WithKey(
      ctx,
      Fixture,
      function(session)
        Assert.Equal(#Reread(session).entries, 0, "an unreadable class tracks nothing")
      end,
      PrepareWith(function(globals)
        local unitClass = globals.UnitClass
        globals.UnitClass = function(unit)
          if unit == "player" then
            return nil
          end
          return unitClass(unit)
        end
      end)
    )
  end)
end

return function(test, ctx)
  RegisterManifestTests(test, ctx)
  RegisterCodecTests(test, ctx)
  RegisterSettingsTests(test, ctx)
  RegisterWireTests(test, ctx)
  RegisterLockdownTests(test, ctx)
  RegisterContextTests(test, ctx)
  RegisterOwnStateTests(test, ctx)
  RegisterOwnStateFallbackTests(test, ctx)
  RegisterMaskedCooldownTests(test, ctx)
  RegisterTalentTests(test, ctx)
end
