---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  local function LoadSchema()
    local addon = LoadAddonModules({ "isiLive_db_schema.lua" })
    return addon.DBSchema
  end

  -- ----------------------------------------------------------------------
  -- Empty db / fresh install
  -- ----------------------------------------------------------------------

  test("DBSchema.Sanitize fills all defaults on an empty db", function()
    local DBSchema = LoadSchema()
    local db = {}
    local corrections, migrations = DBSchema.Sanitize(db)
    Assert.True(corrections > 0, "fresh install must have corrections (every field defaulted)")
    Assert.Equal(migrations, 0, "fresh install needs no migrations")
    Assert.NotNil(db.position, "position table must be filled")
    Assert.Equal(db.position.point, "CENTER", "position.point default")
    Assert.Equal(db.position.x, 0, "position.x default")
    Assert.NotNil(db.statsBoxPosition, "statsBoxPosition table must be filled")
    Assert.Equal(db.statsBoxPosition.point, "CENTER", "statsBoxPosition.point default")
    Assert.Equal(db.statsBoxPosition.x, 320, "statsBoxPosition.x default")
    Assert.Equal(db.uiScale, 1.0, "uiScale default")
    Assert.Equal(db.statsBoxEnabled, false, "statsBoxEnabled default false")
    Assert.Equal(db.statsBoxLocked, false, "statsBoxLocked default false")
    Assert.Equal(db.statsBoxBgAlpha, 0.0, "statsBoxBgAlpha default transparent")
    Assert.Equal(db.statsBoxFontSizeOffset, 0, "statsBoxFontSizeOffset default zero")
    Assert.Equal(db.statsBoxDisplayMode, "both", "statsBoxDisplayMode default both")
    Assert.Equal(db.statsBoxShowLeech, true, "statsBoxShowLeech default true")
    Assert.Equal(db.statsBoxShowSpeed, true, "statsBoxShowSpeed default true")
    Assert.Equal(db.statsBoxShowDurability, false, "statsBoxShowDurability default false")
    Assert.Equal(db.statsBoxShowStamina, false, "statsBoxShowStamina default false")
    Assert.Equal(db.statsBoxShowAvoidance, false, "statsBoxShowAvoidance default false")
    Assert.Equal(db.groupJoinNoticeEnabled, true, "groupJoinNoticeEnabled default true")
    Assert.Equal(db.lockMainFramePosition, true, "lockMainFramePosition default true")
    Assert.Equal(db.syncEnabled, true, "syncEnabled default true")
    Assert.Equal(db.soundOutputChannel, "Master", "soundOutputChannel default Master")
    Assert.Equal(db.soundBloodlustReadyReminderEnabled, true, "bloodlust-ready reminder default true")
    Assert.Equal(db.soundPowerInfusionReceivedEnabled, true, "PI received sound default true")
    Assert.Equal(db.soundIncomingSummonLoopEnabled, true, "incoming-summon loop default true")
    Assert.Equal(db.soundTankDiedEnabled, true, "tank death sound default true")
    Assert.Equal(db.soundHealerDiedEnabled, true, "healer death sound default true")
    Assert.Equal(db.soundOwnTankDiedEnabled, true, "own tank death sound default true")
    Assert.Equal(db.soundOwnHealerDiedEnabled, true, "own healer death sound default true")
    Assert.Equal(db.powerInfusionTextEnabled, true, "power infusion text alert default true")
    Assert.Equal(db.autoCloseOnKeyStart, false, "key-start auto-close default false")
    Assert.Equal(db.autoCloseOnSoloChange, false, "solo-change auto-close default false")
    Assert.Equal(db.locale, "enUS", "locale default")
    Assert.Nil(db.inviteListEnabled, "removed invite-list feature must not create a DB default")
    Assert.Nil(db.inviteHintEnabled, "removed pre-accept invite hint must not create a DB default")
  end)

  test("DBSchema.Sanitize stamps __schemaVersion on first run", function()
    local DBSchema = LoadSchema()
    local db = {}
    DBSchema.Sanitize(db)
    Assert.Equal(db.__schemaVersion, DBSchema.GetSchemaVersion(), "version must be stamped after sanitize")
  end)

  test("DBSchema.Sanitize does not create removed invite hint default", function()
    local DBSchema = LoadSchema()
    local db = {}
    DBSchema.Sanitize(db)
    Assert.Nil(db.inviteHintEnabled, "removed pre-accept invite hint must not have a SavedVariable field")
  end)

  test("DBSchema.Sanitize does not create removed native TTS defaults", function()
    local DBSchema = LoadSchema()
    local db = {}
    DBSchema.Sanitize(db)
    Assert.Nil(db.ttsAnnouncementsEnabled, "removed native TTS enable field must not have a SavedVariable default")
    Assert.Nil(db.ttsAnnounceName, "removed native TTS name field must not have a SavedVariable default")
    Assert.Nil(db.ttsAnnounceClass, "removed native TTS class field must not have a SavedVariable default")
    Assert.Nil(db.ttsVoiceID, "removed native TTS voice field must not have a SavedVariable default")
    Assert.Nil(db.ttsVolume, "removed native TTS volume field must not have a SavedVariable default")
  end)

  test("DBSchema.Sanitize is idempotent on a fully-sanitized db", function()
    local DBSchema = LoadSchema()
    local db = {}
    DBSchema.Sanitize(db)
    local corrections, migrations = DBSchema.Sanitize(db)
    Assert.Equal(corrections, 0, "second run on clean db must produce no corrections")
    Assert.Equal(migrations, 0, "second run must skip migrations (version already stamped)")
  end)

  -- ----------------------------------------------------------------------
  -- Type-error repair
  -- ----------------------------------------------------------------------

  test("DBSchema.Sanitize resets wrong-type uiScale to default", function()
    local DBSchema = LoadSchema()
    local db = { uiScale = "not a number" }
    DBSchema.Sanitize(db)
    Assert.Equal(db.uiScale, 1.0, "string uiScale must reset to default")
  end)

  test("DBSchema.Sanitize resets wrong-type boolean to default", function()
    local DBSchema = LoadSchema()
    local db = { syncEnabled = "true" }
    DBSchema.Sanitize(db)
    Assert.Equal(db.syncEnabled, true, "string syncEnabled must reset to default true")
  end)

  test("DBSchema.Sanitize resets wrong-type table field to default", function()
    local DBSchema = LoadSchema()
    local db = { position = "corrupted" }
    DBSchema.Sanitize(db)
    Assert.Equal(type(db.position), "table", "string position must reset to default table")
    ---@diagnostic disable-next-line: undefined-field
    Assert.Equal(db.position.point, "CENTER", "default position.point")
  end)

  -- ----------------------------------------------------------------------
  -- Numeric range clamping
  -- ----------------------------------------------------------------------

  test("DBSchema.Sanitize clamps uiScale below min", function()
    local DBSchema = LoadSchema()
    local db = { uiScale = -5 }
    DBSchema.Sanitize(db)
    Assert.Equal(db.uiScale, 0.5, "below-min uiScale must clamp to 0.5")
  end)

  test("DBSchema.Sanitize clamps uiScale above max", function()
    local DBSchema = LoadSchema()
    local db = { uiScale = 100 }
    DBSchema.Sanitize(db)
    Assert.Equal(db.uiScale, 2.0, "above-max uiScale must clamp to 2.0")
  end)

  test("DBSchema.Sanitize clamps bgAlpha into [0, 1]", function()
    local DBSchema = LoadSchema()
    local db = { bgAlpha = 5 }
    DBSchema.Sanitize(db)
    Assert.Equal(db.bgAlpha, 1.0, "above-max bgAlpha must clamp to 1.0")

    db = { bgAlpha = -1 }
    DBSchema.Sanitize(db)
    Assert.Equal(db.bgAlpha, 0.0, "below-min bgAlpha must clamp to 0.0")
  end)

  test("DBSchema.Sanitize preserves valid in-range numeric value", function()
    local DBSchema = LoadSchema()
    local db = { uiScale = 1.25 }
    DBSchema.Sanitize(db)
    Assert.Equal(db.uiScale, 1.25, "in-range uiScale must be preserved")
  end)

  -- ----------------------------------------------------------------------
  -- Enum validation
  -- ----------------------------------------------------------------------

  test("DBSchema.Sanitize resets invalid enum string to default", function()
    local DBSchema = LoadSchema()
    local db = { mobNameplatePosition = "MIDDLE" }
    DBSchema.Sanitize(db)
    Assert.Equal(db.mobNameplatePosition, "RIGHT", "invalid enum must reset to default")
  end)

  test("DBSchema.Sanitize preserves valid enum string", function()
    local DBSchema = LoadSchema()
    local db = { mobNameplatePosition = "TOP" }
    DBSchema.Sanitize(db)
    Assert.Equal(db.mobNameplatePosition, "TOP", "valid enum must be preserved")
  end)

  test("DBSchema.Sanitize resets invalid soundOutputChannel to Master and preserves SFX", function()
    local DBSchema = LoadSchema()
    local db = { soundOutputChannel = "Dialog" }
    DBSchema.Sanitize(db)
    Assert.Equal(db.soundOutputChannel, "Master", "invalid sound output channel must reset to Master")

    db.soundOutputChannel = "SFX"
    DBSchema.Sanitize(db)
    Assert.Equal(db.soundOutputChannel, "SFX", "SFX sound output channel must be preserved")
  end)

  -- ----------------------------------------------------------------------
  -- Nested table validation (position is the canonical case)
  -- ----------------------------------------------------------------------

  test("DBSchema.Sanitize repairs partially-broken position (point=nil)", function()
    local DBSchema = LoadSchema()
    -- This is the v0.9.208-era corruption: the table exists, but a sub-field
    -- is nil. Pre-schema code crashed in mainFrame:SetPoint(nil, ...).
    local db = { position = { relativePoint = "CENTER", x = 100, y = 200 } }
    DBSchema.Sanitize(db)
    Assert.Equal(db.position.point, "CENTER", "missing point must be filled")
    Assert.Equal(db.position.relativePoint, "CENTER", "valid relativePoint preserved")
    Assert.Equal(db.position.x, 100, "valid x preserved")
    Assert.Equal(db.position.y, 200, "valid y preserved")
  end)

  test("DBSchema.Sanitize repairs wrong-type position subfield", function()
    local DBSchema = LoadSchema()
    local db = { position = { point = 42, relativePoint = "CENTER", x = "abc", y = 0 } }
    DBSchema.Sanitize(db)
    Assert.Equal(db.position.point, "CENTER", "number point must reset to string default")
    Assert.Equal(db.position.x, 0, "string x must reset to number default")
  end)

  test("DBSchema.Sanitize fills nested fields when parent table is missing", function()
    local DBSchema = LoadSchema()
    local db = {}
    DBSchema.Sanitize(db)
    Assert.Equal(type(db.position), "table", "position table must be created")
    Assert.NotNil(db.position.point, "position.point must be filled")
    Assert.NotNil(db.position.relativePoint, "position.relativePoint must be filled")
    Assert.NotNil(db.position.x, "position.x must be filled")
    Assert.NotNil(db.position.y, "position.y must be filled")
  end)

  -- ----------------------------------------------------------------------
  -- User-set values preserved
  -- ----------------------------------------------------------------------

  test("DBSchema.Sanitize preserves valid user-set boolean", function()
    local DBSchema = LoadSchema()
    local db = {
      syncEnabled = false,
      autoCloseOnKeyStart = true,
      mobNameplateEnabled = false,
    }
    DBSchema.Sanitize(db)
    Assert.Equal(db.syncEnabled, false, "user-disabled syncEnabled stays false")
    Assert.Equal(db.autoCloseOnKeyStart, true, "user-enabled autoCloseOnKeyStart stays true")
    Assert.Equal(db.mobNameplateEnabled, false, "user-disabled mobNameplateEnabled stays false")
  end)

  test("DBSchema.Sanitize migrates legacy autoCloseMainFrame into split auto-close fields", function()
    local DBSchema = LoadSchema()
    local db = {
      autoCloseMainFrame = true,
      __schemaVersion = 1,
    }
    local corrections, migrations = DBSchema.Sanitize(db)
    Assert.Equal(migrations, 1, "legacy auto-close split migration must report one applied migration")
    Assert.True(corrections > 0, "legacy auto-close split migration must log a correction")
    Assert.Equal(db.autoCloseMainFrame, false, "legacy autoCloseMainFrame must be cleared after migration")
    Assert.Equal(db.autoCloseOnKeyStart, true, "legacy auto-close must enable key-start auto-close explicitly")
    Assert.Equal(db.autoCloseOnSoloChange, true, "legacy auto-close must enable solo-change auto-close explicitly")
  end)

  test("DBSchema.Sanitize migrates legacy astral aurochs disabled sound into muted option", function()
    local DBSchema = LoadSchema()
    local db = {
      __schemaVersion = 2,
      vipAstralAurochsSoundEnabled = false,
    }
    local corrections, migrations = DBSchema.Sanitize(db)
    Assert.Equal(migrations, 1, "legacy VIP sound migration must report one applied migration")
    Assert.True(corrections > 0, "legacy VIP sound migration must log a correction")
    Assert.Equal(db.vipAstralAurochsSoundMuted, true, "legacy disabled sound must become muted=true")
    Assert.Nil(db.vipAstralAurochsSoundEnabled, "legacy enabled field must be removed after migration")
  end)

  test("DBSchema.Sanitize preserves valid user-set table contents", function()
    local DBSchema = LoadSchema()
    local db = { position = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 50, y = -50 } }
    DBSchema.Sanitize(db)
    Assert.Equal(db.position.point, "TOPLEFT", "user point preserved")
    Assert.Equal(db.position.x, 50, "user x preserved")
    Assert.Equal(db.position.y, -50, "user y preserved")
  end)

  -- ----------------------------------------------------------------------
  -- Unknown fields are preserved (forward-compat for future migrations)
  -- ----------------------------------------------------------------------

  test("DBSchema.Sanitize does NOT delete unknown fields", function()
    local DBSchema = LoadSchema()
    -- A field from a future version (or a removed field that has not yet
    -- received a migration step) must not be silently dropped.
    local db = { someFutureField = "value-from-future-version" }
    DBSchema.Sanitize(db)
    Assert.Equal(db.someFutureField, "value-from-future-version", "unknown field must be preserved")
  end)

  -- ----------------------------------------------------------------------
  -- Default mutable references are isolated (no cross-user contamination)
  -- ----------------------------------------------------------------------

  test("DBSchema.Sanitize gives each db an isolated position table", function()
    local DBSchema = LoadSchema()
    local db1, db2 = {}, {}
    DBSchema.Sanitize(db1)
    DBSchema.Sanitize(db2)
    db1.position.x = 999
    Assert.Equal(db2.position.x, 0, "mutating db1 must not affect db2 (no shared default ref)")
  end)

  test("DBSchema.Sanitize gives each db an isolated rioBaseline table", function()
    local DBSchema = LoadSchema()
    local db1, db2 = {}, {}
    DBSchema.Sanitize(db1)
    DBSchema.Sanitize(db2)
    db1.rioBaseline["Player-Realm"] = 2400
    Assert.Equal(db2.rioBaseline["Player-Realm"], nil, "mutating db1 baseline must not bleed into db2")
  end)

  test("DBSchema.Sanitize gives each db an isolated reload roster mirror", function()
    local DBSchema = LoadSchema()
    local db1, db2 = {}, {}
    DBSchema.Sanitize(db1)
    DBSchema.Sanitize(db2)
    db1.reloadRosterMirror.signature = "Player-Realm"
    Assert.Nil(db2.reloadRosterMirror.signature, "mutating db1 reload mirror must not bleed into db2")
  end)

  -- ----------------------------------------------------------------------
  -- Correction logging
  -- ----------------------------------------------------------------------

  test("DBSchema.Sanitize calls logFn for each correction", function()
    local DBSchema = LoadSchema()
    local messages = {}
    local db = { uiScale = "nope" }
    DBSchema.Sanitize(db, function(msg)
      messages[#messages + 1] = msg
    end)
    -- At least one message names the offending field.
    local foundUiScale = false
    for _, msg in ipairs(messages) do
      if type(msg) == "string" and msg:find("uiScale", 1, true) then
        foundUiScale = true
        break
      end
    end
    Assert.True(foundUiScale, "logFn must receive a message naming the corrected field")
  end)

  test("DBSchema.Sanitize tolerates a nil logFn", function()
    local DBSchema = LoadSchema()
    local db = { uiScale = "nope" }
    local ok = pcall(DBSchema.Sanitize, db) -- no logFn
    Assert.True(ok, "Sanitize without logFn must not throw")
    Assert.Equal(db.uiScale, 1.0, "correction still applied without logFn")
  end)

  -- ----------------------------------------------------------------------
  -- Boundary: non-table input
  -- ----------------------------------------------------------------------

  test("DBSchema.Sanitize returns 0/0 when db is not a table", function()
    local DBSchema = LoadSchema()
    local corrections, migrations = DBSchema.Sanitize(nil)
    Assert.Equal(corrections, 0, "nil db must produce zero corrections")
    Assert.Equal(migrations, 0, "nil db must produce zero migrations")

    corrections, migrations = DBSchema.Sanitize("string")
    Assert.Equal(corrections, 0, "string db must produce zero corrections")
    Assert.Equal(migrations, 0, "string db must produce zero migrations")
  end)

  -- ----------------------------------------------------------------------
  -- Schema introspection
  -- ----------------------------------------------------------------------

  test("DBSchema.GetKnownFieldNames includes core persistent fields", function()
    local DBSchema = LoadSchema()
    local known = DBSchema.GetKnownFieldNames()
    Assert.Equal(known.position, true, "position must be in known fields")
    Assert.Equal(known.statsBoxPosition, true, "statsBoxPosition must be in known fields")
    Assert.Equal(known.uiScale, true, "uiScale must be in known fields")
    Assert.Equal(known.statsBoxEnabled, true, "statsBoxEnabled must be in known fields")
    Assert.Equal(known.statsBoxLocked, true, "statsBoxLocked must be in known fields")
    Assert.Equal(known.statsBoxBgAlpha, true, "statsBoxBgAlpha must be in known fields")
    Assert.Equal(known.statsBoxFontSizeOffset, true, "statsBoxFontSizeOffset must be in known fields")
    Assert.Equal(known.statsBoxDisplayMode, true, "statsBoxDisplayMode must be in known fields")
    Assert.Equal(known.statsBoxShowLeech, true, "statsBoxShowLeech must be in known fields")
    Assert.Equal(known.statsBoxShowSpeed, true, "statsBoxShowSpeed must be in known fields")
    Assert.Equal(known.statsBoxShowDurability, true, "statsBoxShowDurability must be in known fields")
    Assert.Equal(known.statsBoxShowStamina, true, "statsBoxShowStamina must be in known fields")
    Assert.Equal(known.statsBoxShowAvoidance, true, "statsBoxShowAvoidance must be in known fields")
    Assert.Equal(known.groupJoinNoticeEnabled, true, "groupJoinNoticeEnabled must be in known fields")
    Assert.Equal(known.syncEnabled, true, "syncEnabled must be in known fields")
    Assert.Equal(
      known.soundBloodlustReadyReminderEnabled,
      true,
      "soundBloodlustReadyReminderEnabled must be in known fields"
    )
    Assert.Equal(known.soundOutputChannel, true, "soundOutputChannel must be in known fields")
    Assert.Equal(
      known.soundPowerInfusionReceivedEnabled,
      true,
      "soundPowerInfusionReceivedEnabled must be in known fields"
    )
    Assert.Equal(known.soundIncomingSummonLoopEnabled, true, "soundIncomingSummonLoopEnabled must be in known fields")
    Assert.Equal(known.soundTankDiedEnabled, true, "soundTankDiedEnabled must be in known fields")
    Assert.Equal(known.soundHealerDiedEnabled, true, "soundHealerDiedEnabled must be in known fields")
    Assert.Equal(known.soundOwnTankDiedEnabled, true, "soundOwnTankDiedEnabled must be in known fields")
    Assert.Equal(known.soundOwnHealerDiedEnabled, true, "soundOwnHealerDiedEnabled must be in known fields")
    Assert.Equal(known.hearthstoneChoice, true, "hearthstoneChoice must be in known fields")
    Assert.Equal(known.vipAstralAurochsSoundMuted, true, "vipAstralAurochsSoundMuted must be in known fields")
    Assert.Equal(known.vipGrandExpeditionYakSoundMuted, true, "vipGrandExpeditionYakSoundMuted must be in known fields")
    Assert.Equal(known.vipGildedBrutosaurSoundMuted, true, "vipGildedBrutosaurSoundMuted must be in known fields")
    Assert.Equal(known.mobNameplateEnabled, true, "mobNameplateEnabled must be in known fields")
    -- Runtime-only fields are intentionally excluded.
    Assert.Equal(known.queueDebug, nil, "queueDebug is runtime-only, must NOT be in schema")
    Assert.Equal(known.runtimeLogEnabled, nil, "runtimeLogEnabled is runtime-only, must NOT be in schema")
    Assert.Equal(known.inviteListEnabled, nil, "removed invite-list setting must NOT be in schema")
  end)

  test("DBSchema.GetSchemaVersion returns the current LATEST_SCHEMA_VERSION", function()
    local DBSchema = LoadSchema()
    Assert.Equal(type(DBSchema.GetSchemaVersion()), "number", "schema version must be a number")
    Assert.True(DBSchema.GetSchemaVersion() >= 1, "schema version must be at least 1")
  end)
end
