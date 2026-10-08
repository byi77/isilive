-- Rule 194: the LOC sync bucket carries the sender's party instance ID in a
-- tagged "IN" suffix, and the roster "stands in the target dungeon" marker
-- compares only instance IDs. Ingame 2026-10-08, Murder Row (rule 193):
-- challenge map 587 -> instance 2813 (GetInstanceInfo #8 and
-- C_ChallengeMode.GetMapUIInfo(587) #6), UiMapID 2433.
--
-- The roundtrip tests run end-to-end in one shared global scope: the real
-- KeySync sender (SendOwnKeySnapshot -> Sync.SendLoc) emits the wire bytes,
-- they are captured from the mocked C_ChatInfo.SendAddonMessage and fed
-- through the real CHAT_MSG_ADDON dispatcher into the real
-- Sync.ProcessAddonMessage, the real KeySync backfill writes the roster entry,
-- and the real RenderRosterImpl renders the row whose name text is asserted.
-- RenderRosterImpl is reached through addon._RosterInternal: the roster panel
-- exposes no other render entry point without the full frame/controller stack.

local MURDER_ROW_CHALLENGE_MAP_ID = 587
local MURDER_ROW_INSTANCE_ID = 2813
local MURDER_ROW_UI_MAP_ID = 2433
local OTHER_INSTANCE_ID = 2649
local AT_DUNGEON_ICON = "Minimap_Summon_Icon"

local INSTANCE_ID_BY_CHALLENGE_MAP_ID = {
  [MURDER_ROW_CHALLENGE_MAP_ID] = MURDER_ROW_INSTANCE_ID,
}

local function LoadRosterMocks()
  local chunk = assert(loadfile("testmodul/isilive_test_render_roster_mocks.lua"))
  return chunk()
end

local function Strsplit(sep, str, max)
  local pos = str:find(sep, 1, true)
  if not pos then
    return str
  end
  if max and max >= 2 then
    return str:sub(1, pos - 1), str:sub(pos + 1)
  end
  return str:sub(1, pos - 1)
end

-- `location` is mutable: the sender side and the receiver side run in the same
-- global scope, so a scenario switches it between the send and the render.
local function BuildGlobals(location, sentMessages, mapLookups)
  return {
    strsplit = Strsplit,
    GetRealmName = function()
      return "Realm"
    end,
    GetTime = function()
      return 100
    end,
    UnitExists = function(unit)
      return unit == "player"
    end,
    UnitIsConnected = function()
      return true
    end,
    IsInGroup = function(category)
      return category ~= 2
    end,
    IsInRaid = function()
      return false
    end,
    LE_PARTY_CATEGORY_INSTANCE = 2,
    IsiLiveDB = { syncEnabled = true },
    GetReadyCheckStatus = function()
      return nil
    end,
    RAID_CLASS_COLORS = {},
    CreateColor = function()
      return {
        GenerateHexColor = function()
          return "ffffffff"
        end,
      }
    end,
    InCombatLockdown = function()
      return false
    end,
    GetInstanceInfo = function()
      return "Instance", location.instanceType or "none", 8, "Mythic Keystone", 5, 0, false, location.instanceID, 5, nil
    end,
    C_Map = {
      GetBestMapForUnit = function(unit)
        mapLookups[#mapLookups + 1] = unit
        if unit == "player" then
          return location.uiMapID
        end
        return location.memberUiMapID
      end,
    },
    C_ChallengeMode = {
      GetMapUIInfo = function(challengeMapID)
        local instanceID = INSTANCE_ID_BY_CHALLENGE_MAP_ID[challengeMapID]
        if not instanceID then
          return nil
        end
        return "Dungeon", challengeMapID, 1800, nil, nil, instanceID
      end,
    },
    C_ChatInfo = {
      SendAddonMessage = function(prefix, message, channel)
        sentMessages[#sentMessages + 1] = { prefix = prefix, message = message, channel = channel }
        return true
      end,
    },
  }
end

local function FindLocMessage(sentMessages)
  for _, sent in ipairs(sentMessages) do
    if sent.message:find("^LOC:") then
      return sent
    end
  end
  return nil
end

local function FindRowForUnit(memberRows, unit)
  for _, row in ipairs(memberRows) do
    if row.unit == unit then
      return row
    end
  end
  return nil
end

local function BuildMemberRows(RosterMocks)
  local rows = {}
  for i = 1, 5 do
    local row = {}
    for _, field in ipairs({ "spec", "name", "realm", "key", "ilvl", "rio", "dps", "kick" }) do
      local fontString = RosterMocks.MakeFontStringMock()
      fontString.SetText = function(self, text)
        self.text = text
      end
      row[field] = fontString
    end
    row.hoverFrame = RosterMocks.MakeFrameMock()
    row.readyCheckBackground = RosterMocks.MakeFrameMock()
    row.roleButton = RosterMocks.MakeFrameMock()
    row.roleButton.SetAttribute = RosterMocks.NoOp
    row.roleButton.GetAttribute = RosterMocks.NoOp
    row.roleButton.icon = row.roleButton:CreateTexture()
    rows[i] = row
  end
  return rows
end

-- Runs one sender -> receiver roundtrip. The sender stands at
-- `senderLocation`; `payloadOverride` replaces the captured LOC bytes with a
-- legacy payload (a client up to 0.9.423 that sends only the UiMapID). Returns
-- the captured wire bytes, the rendered member and own rows, the receiver's
-- roster entry and the GetBestMapForUnit lookups made during the render.
local function RunLocRoundtrip(WithGlobals, LoadAddonModules, Fixtures, senderLocation, opts)
  opts = opts or {}
  local location = {}
  for key, value in pairs(senderLocation) do
    location[key] = value
  end
  local sentMessages = {}
  local mapLookups = {}
  local result = {}
  local RosterMocks = LoadRosterMocks()

  WithGlobals(BuildGlobals(location, sentMessages, mapLookups), function()
    local addon = LoadAddonModules({
      "isiLive_sync.lua",
      "isiLive_keysync.lua",
      "isiLive_event_handlers.lua",
      "isiLive_roster.lua",
      "isiLive_roster_layout.lua",
      "isiLive_roster_panel_render.lua",
    })
    local function CreateKeySync(name)
      return addon.KeySync.CreateController({
        sync = addon.Sync,
        getUnitNameAndRealm = function(_unit)
          return name, "Realm"
        end,
        isFrameVisible = function()
          return true
        end,
      })
    end

    -- Sender: the real snapshot path builds and sends the LOC bytes.
    CreateKeySync("Alpha").SendOwnKeySnapshot(true, "test", true, false, false)
    local sent = FindLocMessage(sentMessages)
    result.wire = sent and sent.message or nil
    local wireMessage = opts.payloadOverride or result.wire

    -- Receiver: stands outside any instance unless the scenario says so.
    for key in pairs(location) do
      location[key] = nil
    end
    for key, value in pairs(opts.receiverLocation or {}) do
      location[key] = value
    end
    local keysync = CreateKeySync("Me")
    local roster = {
      player = { name = "Me", realm = "Realm", class = "WARRIOR", role = "DAMAGER" },
      party1 = { name = "Alpha", realm = "Realm", class = "PRIEST", role = "DAMAGER" },
    }
    local controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      isMainFrameShown = function()
        return true
      end,
      processAddonMessage = function(prefix, message, sender, channel)
        return addon.Sync.ProcessAddonMessage(prefix, message, sender, "Me", "Realm", channel)
      end,
      applyKnownKeyToRosterEntry = function(info)
        return keysync.ApplyKnownKeyToRosterEntry(info)
      end,
      forEachRosterInfo = function(visitor)
        visitor(roster.party1)
      end,
      isSyncUserKnown = function(name, _realm)
        return name == "Alpha"
      end,
    })
    if wireMessage then
      controller:Dispatch("CHAT_MSG_ADDON", addon.Sync.GetPrefix(), wireMessage, "PARTY", "Alpha-Realm")
    end

    local memberRows = BuildMemberRows(RosterMocks)
    local state = RosterMocks.BuildDefaultRenderState(memberRows, addon, {
      resolveTargetMapID = function()
        return MURDER_ROW_CHALLENGE_MAP_ID
      end,
    })
    for key in pairs(mapLookups) do
      mapLookups[key] = nil
    end
    addon._RosterInternal.RenderRosterImpl(state, roster)

    local memberRow = FindRowForUnit(memberRows, "party1")
    local ownRow = FindRowForUnit(memberRows, "player")
    result.memberNameText = memberRow and memberRow.name.text or ""
    result.ownNameText = ownRow and ownRow.name.text or ""
    result.memberInfo = roster.party1
    result.renderMapLookups = #mapLookups
  end)

  return result
end

local function HasMarker(text)
  return type(text) == "string" and text:find(AT_DUNGEON_ICON, 1, true) ~= nil
end

local MURDER_ROW_SENDER = {
  instanceType = "party",
  instanceID = MURDER_ROW_INSTANCE_ID,
  uiMapID = MURDER_ROW_UI_MAP_ID,
}

local function RegisterLocInstanceRoundtripTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  test("LOC roundtrip marks a member who stands in the target dungeon instance", function()
    local result = RunLocRoundtrip(WithGlobals, LoadAddonModules, Fixtures, MURDER_ROW_SENDER)

    Assert.Equal(
      result.wire,
      "LOC:2433:100:test:IN:2813",
      "sender keeps the UiMapID in field 2 and appends the instance ID as IN suffix"
    )
    Assert.Equal(result.memberInfo.syncLocInstanceID, 2813, "receiver backfills the synced instance ID")
    Assert.True(HasMarker(result.memberNameText), "member inside instance 2813 gets the at-dungeon marker")
    Assert.False(HasMarker(result.ownNameText), "receiver outside any instance stays unmarked")
    Assert.Equal(result.renderMapLookups, 0, "the marker never reads a UiMapID")
  end)

  test("LOC roundtrip leaves a member in another instance unmarked", function()
    local result = RunLocRoundtrip(WithGlobals, LoadAddonModules, Fixtures, {
      instanceType = "party",
      instanceID = OTHER_INSTANCE_ID,
      uiMapID = MURDER_ROW_CHALLENGE_MAP_ID,
    })

    Assert.Equal(result.wire, "LOC:587:100:test:IN:2649", "sender sends its own instance ID")
    Assert.Equal(result.memberInfo.syncLocInstanceID, OTHER_INSTANCE_ID, "receiver stores the other instance")
    Assert.False(
      HasMarker(result.memberNameText),
      "a different instance stays unmarked even when its UiMapID equals the challenge map ID"
    )
  end)

  test("LOC roundtrip ignores a legacy payload without instance ID", function()
    for _, legacyPayload in ipairs({ "LOC:2433:100:hello", "LOC:587:100:hello" }) do
      local result = RunLocRoundtrip(WithGlobals, LoadAddonModules, Fixtures, MURDER_ROW_SENDER, {
        payloadOverride = legacyPayload,
      })
      Assert.Equal(
        result.memberInfo.syncLocMapID,
        tonumber(legacyPayload:match("^LOC:(%d+)")),
        legacyPayload .. " is still accepted as a valid LOC payload"
      )
      Assert.Nil(result.memberInfo.syncLocInstanceID, legacyPayload .. " carries no instance ID")
      Assert.False(HasMarker(result.memberNameText), legacyPayload .. " never marks the member")
    end
  end)

  test("LOC roundtrip marks the own row only inside the target dungeon instance", function()
    local inside = RunLocRoundtrip(WithGlobals, LoadAddonModules, Fixtures, MURDER_ROW_SENDER, {
      receiverLocation = MURDER_ROW_SENDER,
    })
    Assert.True(HasMarker(inside.ownNameText), "own row inside instance 2813 gets the marker")

    local collidingUiMap = RunLocRoundtrip(WithGlobals, LoadAddonModules, Fixtures, MURDER_ROW_SENDER, {
      receiverLocation = {
        instanceType = "party",
        instanceID = OTHER_INSTANCE_ID,
        uiMapID = MURDER_ROW_CHALLENGE_MAP_ID,
      },
    })
    Assert.False(
      HasMarker(collidingUiMap.ownNameText),
      "own row stays unmarked when only its UiMapID equals the challenge map ID"
    )
    Assert.Equal(collidingUiMap.renderMapLookups, 0, "the own row never reads a UiMapID")
  end)

  test("LOC sender omits the IN suffix outside a party instance", function()
    local result = RunLocRoundtrip(WithGlobals, LoadAddonModules, Fixtures, {
      instanceType = "none",
      instanceID = 2552,
      uiMapID = 2339,
    })
    Assert.Equal(result.wire, "LOC:0:100:test", "outside a party instance the legacy empty LOC is sent")
    Assert.Nil(result.memberInfo.syncLocInstanceID, "no instance ID reaches the receiver")
    Assert.False(HasMarker(result.memberNameText), "the member stays unmarked")
  end)
end

local function RegisterLocInstanceSkewTests(test, Assert, WithGlobals, LoadAddonModules)
  test("LOC IN suffix keeps the legacy fields that older parsers read", function()
    local sentMessages = {}
    WithGlobals(BuildGlobals(MURDER_ROW_SENDER, sentMessages, {}), function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      addon.Sync.SendLoc({ force = true, mapID = 2433, capturedAt = 100, source = "test" })
      addon.Sync.SendLoc({ force = true, mapID = 2433, capturedAt = 100, source = "test", instanceID = 2813 })
    end)

    local legacy = sentMessages[1] and sentMessages[1].message
    local current = sentMessages[2] and sentMessages[2].message
    Assert.Equal(legacy, "LOC:2433:100:test", "without instance ID the payload is byte-identical to the old one")
    Assert.Equal(current, "LOC:2433:100:test:IN:2813", "an instance change is not swallowed by the send dedupe")
    -- Every LOC-capable release (0.9.178 .. 0.9.423) splits on ":" into at
    -- most 10 fields and reads only fields 2-4 of a LOC payload.
    Assert.Equal(current:sub(1, #legacy + 1), legacy .. ":", "fields 1-4 stay byte-identical for older parsers")
    local fieldCount = select(2, current:gsub("[^:]+", ""))
    Assert.True(fieldCount <= 10, "the payload stays within the 10-field split limit of older parsers")
  end)

  test("LOC receiver ignores a malformed IN suffix", function()
    WithGlobals(BuildGlobals({}, {}, {}), function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      for _, payload in ipairs({ "LOC:2433:100:test:IN:abc", "LOC:2433:100:test:IN", "LOC:2433:100:test:IN:-5" }) do
        local result = addon.Sync.ProcessAddonMessage("ISILIVE", payload, "Alpha-Realm", "Me", "Realm", "PARTY")
        Assert.True(result ~= nil and result.locUpdated ~= nil, payload .. " is processed without error")
        local locInfo = addon.Sync.GetPlayerLocInfo("Alpha", "Realm")
        Assert.Equal(locInfo and locInfo.mapID, 2433, payload .. " keeps the legacy UiMapID")
        Assert.Nil(locInfo and locInfo.instanceID, payload .. " stores no instance ID")
      end
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules
  local Fixtures = ctx.fixtures

  RegisterLocInstanceRoundtripTests(test, Assert, WithGlobals, LoadAddonModules, Fixtures)
  RegisterLocInstanceSkewTests(test, Assert, WithGlobals, LoadAddonModules)
end
