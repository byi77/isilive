---@diagnostic disable: undefined-global

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Demo default adapters reject successful secret unit and item-level values", function()
    local secret = {}
    WithGlobals({
      issecretvalue = function(value)
        return value == secret
      end,
      UnitExists = function()
        return true
      end,
      UnitFullName = function()
        return secret, secret
      end,
      UnitName = function()
        return secret
      end,
      UnitClass = function()
        return secret, secret
      end,
      GetRealmName = function()
        return secret
      end,
      C_Item = {
        GetAverageItemLevel = function()
          return secret, secret
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_demo.lua" })
      local roster = addon.Demo.BuildDummyRoster({})
      Assert.Equal(roster.player.name, "Player", "secret unit names must remain unresolved")
      Assert.Equal(roster.player.realm, "", "secret realm names must remain unresolved")
      Assert.Equal(roster.player.class, "WARRIOR", "secret class values must not enter preview state")
      Assert.Nil(roster.player.ilvl, "secret item-level values must not enter preview state")
    end)
  end)

  test("KeySync ResolveAverageItemLevel rejects successful secret values", function()
    local secret = {}
    WithGlobals({
      issecretvalue = function(value)
        return value == secret
      end,
      C_Item = {
        GetAverageItemLevel = function()
          return secret, secret
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_keysync.lua" })
      Assert.Nil(addon.KeySync.ResolveAverageItemLevel(), "secret item-level values must remain unresolved")
    end)
  end)

  test("KickTracker keeps specialization unresolved when its index is secret", function()
    local secret = {}
    WithGlobals({
      issecretvalue = function(value)
        return value == secret
      end,
      GetSpecialization = function()
        return secret
      end,
      GetSpecializationInfo = function()
        error("secret specialization index must stop before info lookup", 0)
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
      local controller = addon.KickTracker.CreateController({
        getTime = function()
          return 100
        end,
      })
      controller.ResolveKickState()
      local info = controller.GetKickInfo()
      Assert.False(info.availabilityResolved, "secret specialization index must not resolve kick availability")
      Assert.False(info.hasKick, "secret specialization index must not synthesize an interrupt")
    end)
  end)

  test("Secret value checker rejects method aliases and late guards", function()
    local chunk = assert(loadfile("tools/check_secret_value_guards.lua"))
    local checker = chunk("test")

    local methodAliasHits = checker.AnalyzeLines("fixture.lua", {
      'local mapApi = rawget(_G, "C_Map")',
      "local getBestMapForUnit = mapApi and mapApi.GetBestMapForUnit",
      'local ok, mapID = pcall(getBestMapForUnit, "player")',
      "mapID = ok and tonumber(mapID) or nil",
    })
    Assert.Equal(#methodAliasHits, 1, "table-method aliases must be audited")

    local lateGuardHits = checker.AnalyzeLines("fixture.lua", {
      'local api = rawget(_G, "C_ChallengeMode")',
      "local ok, mapID = pcall(api.GetActiveChallengeMapID)",
      "if ok and type(mapID) == 'number' and mapID > 0 and not IsSecretValue(mapID) then",
      "  return mapID",
      "end",
    })
    Assert.Equal(#lateGuardHits, 1, "a Secret check after comparison must not satisfy the gate")

    local orderedGuardHits = checker.AnalyzeLines("fixture.lua", {
      'local api = rawget(_G, "C_ChallengeMode")',
      "local ok, mapID = pcall(api.GetActiveChallengeMapID)",
      "if not ok or IsSecretValue(mapID) or type(mapID) ~= 'number' then",
      "  return nil",
      "end",
    })
    Assert.Equal(#orderedGuardHits, 0, "the same pcall result checked before use must pass")

    -- StyLua wraps long pcall assignments; the shipped BRes scan compared the
    -- GetSpellCharges result with `~= nil` in exactly that shape.
    local wrappedHits = checker.AnalyzeLines("fixture.lua", {
      "local ok, chargeInfoOrCharges, maxCharges =",
      "  pcall(C_Spell_ref.GetSpellCharges, spellID)",
      "if ok and chargeInfoOrCharges ~= nil then",
      "  return chargeInfoOrCharges, maxCharges",
      "end",
    })
    Assert.Equal(#wrappedHits, 2, "a wrapped GetSpellCharges pcall must still be audited per result")

    local wrappedGuardedHits = checker.AnalyzeLines("fixture.lua", {
      "local ok, chargeInfoOrCharges, maxCharges =",
      "  pcall(C_Spell_ref.GetSpellCharges, spellID)",
      "if not ok or IsSecretValue(chargeInfoOrCharges) or IsSecretValue(maxCharges) then",
      "  return nil",
      "end",
    })
    Assert.Equal(#wrappedGuardedHits, 0, "a wrapped pcall whose results are rejected first must pass")

    local wrapperHits = checker.AnalyzeLines("fixture.lua", {
      "local function IsChallengeModeActive()",
      "  return false",
      "end",
      "return IsChallengeModeActive()",
    })
    Assert.Equal(#wrapperHits, 0, "file-local wrappers must not be mistaken for Blizzard method calls")
  end)

  -- The API-name rules above cannot see a masked value that arrives as a FIELD
  -- of a Blizzard payload: no watched name appears on such a line. That is how
  -- `unitAuraUpdateInfo.isFullUpdate == true` shipped while this gate was green.
  test("Secret value checker audits masked payload fields", function()
    local chunk = assert(loadfile("tools/check_secret_value_guards.lua"))
    local checker = chunk("test")

    local shippedDefectHits = checker.AnalyzePayloadFields("fixture.lua", {
      'if type(updateInfo) ~= "table" or updateInfo.isFullUpdate == true then',
    })
    Assert.Equal(#shippedDefectHits, 1, "comparing a masked payload field must be audited")

    local branchHits = checker.AnalyzePayloadFields("fixture.lua", {
      "if updateInfo.isFullUpdate then",
    })
    Assert.Equal(#branchHits, 1, "branching on a masked payload field must be audited")

    local lengthHits = checker.AnalyzePayloadFields("fixture.lua", {
      "if #updateInfo.removedAuraInstanceIDs > 0 then",
    })
    Assert.Equal(#lengthHits, 1, "length-reading a masked payload list must be audited")

    local tableKeyHits = checker.AnalyzePayloadFields("fixture.lua", {
      "if LUST_SATED_IDS[aura.spellId] then",
    })
    Assert.Equal(#tableKeyHits, 1, "using a masked payload field as a table key must be audited")

    local arithmeticHits = checker.AnalyzePayloadFields("fixture.lua", {
      'local remain = rawget(aura, "expirationTime") - getTime()',
    })
    Assert.Equal(#arithmeticHits, 1, "arithmetic on a masked payload field must be audited")

    local guardedHits = checker.AnalyzePayloadFields("fixture.lua", {
      'local isFullUpdate = ReadPlainBoolean(updateInfo, "isFullUpdate")',
      "if isFullUpdate == true then",
      '  local added = ReadPlainField(updateInfo, "addedAuras")',
      "end",
    })
    Assert.Equal(#guardedHits, 0, "fields routed through the central readers must pass")

    local copyHits = checker.AnalyzePayloadFields("fixture.lua", {
      "local snapshot = { spellId = aura.spellId }",
      "-- aura.expirationTime - now would be unsafe",
      "if updateInfo.isFullUpdate == true then -- secret-value-ok",
    })
    Assert.Equal(#copyHits, 0, "copies, comments and annotated lines must not be audited")
  end)

  test("Units reject secret specialization and inspect values", function()
    local secret = {}
    WithGlobals({
      issecretvalue = function(value)
        return value == secret
      end,
      UnitExists = function()
        return true
      end,
      UnitIsUnit = function()
        return true
      end,
      GetSpecialization = function()
        return secret
      end,
      GetSpecializationRole = function()
        error("secret specialization index must not reach role lookup", 0)
      end,
      GetInspectSpecialization = function()
        return secret
      end,
      GetSpecializationInfoByID = function()
        error("secret inspect specialization must not reach info lookup", 0)
      end,
      GetSpecializationRoleByID = function()
        error("secret inspect specialization must not reach role lookup", 0)
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_units.lua" })
      Assert.Equal(addon.Units.GetUnitRole("player"), "NONE", "secret player specialization must keep role unresolved")
      Assert.Nil(addon.Units.GetInspectSpecName("party1"), "secret inspect specialization must keep name unresolved")
      Assert.Nil(addon.Units.GetInspectSpecRole("party1"), "secret inspect specialization must keep role unresolved")
    end)
  end)

  test("KeySync location snapshot requires existing player and rejects secret map", function()
    local secret = {}
    local sentLoc = {}
    local function noOp() end
    local sync = {
      MarkUser = noOp,
      IsUnitKnown = function()
        return false
      end,
      RegisterPrefix = noOp,
      SendHello = noOp,
      SendKey = noOp,
      SendStats = noOp,
      SendDps = noOp,
      SendLoc = function(payload)
        sentLoc[#sentLoc + 1] = payload
      end,
      SendRefreshRequest = noOp,
      SendLibKeystoneRequest = noOp,
      SendLibKeystonePartyData = noOp,
      GetPlayerKeyInfo = noOp,
      GetPlayerStatsInfo = noOp,
      GetPlayerDpsInfo = noOp,
      GetPlayerLocInfo = noOp,
      SetPlayerKeyInfo = noOp,
    }

    WithGlobals({
      issecretvalue = function(value)
        return value == secret
      end,
      GetInstanceInfo = function()
        return nil, "party"
      end,
      UnitExists = function()
        return true
      end,
      C_Map = {
        GetBestMapForUnit = function()
          return secret
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_keysync.lua" })
      local controller = addon.KeySync.CreateController({
        sync = sync,
        isFrameVisible = function()
          return true
        end,
      })
      controller.SendOwnKeySnapshot(true, "test", false, false, false)
      Assert.Equal(#sentLoc, 1)
      Assert.Nil(sentLoc[1].mapID, "secret player map must not enter LOC sync")
    end)

    sentLoc = {}
    WithGlobals({
      GetInstanceInfo = function()
        return nil, "party"
      end,
      UnitExists = function()
        return false
      end,
      C_Map = {
        GetBestMapForUnit = function()
          error("missing player must stop before map lookup", 0)
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_keysync.lua" })
      local controller = addon.KeySync.CreateController({
        sync = sync,
        isFrameVisible = function()
          return true
        end,
      })
      controller.SendOwnKeySnapshot(true, "test", false, false, false)
      Assert.Nil(sentLoc[1].mapID, "missing player must keep LOC sync unresolved")
    end)
  end)

  test("Inspect rejects secret item level", function()
    local secret = {}
    WithGlobals({
      issecretvalue = function(value)
        return value == secret
      end,
      UnitExists = function()
        return true
      end,
      UnitGUID = function()
        return "Player-1"
      end,
      C_PaperDollInfo = {
        GetInspectItemLevel = function()
          return secret
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_inspect.lua" })
      local controller = addon.Inspect.CreateController({})
      controller.isInspecting = "player"
      local roster = {
        player = {},
      }
      controller.OnInspectReady("Player-1", roster, function()
        return nil
      end, function()
        return nil
      end, function()
        return nil
      end, function()
        return nil
      end, function()
        return nil
      end)
      Assert.Nil(roster.player.ilvl, "secret inspect item level must not enter roster state")
      Assert.Nil(controller.ilvlCache["Player-1"], "secret inspect item level must not enter cache state")
    end)
  end)

  test("MplusTimer and KillTrack reject secret challenge values", function()
    local secret = {}
    WithGlobals({
      issecretvalue = function(value)
        return value == secret
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return secret
        end,
        GetActiveKeystoneInfo = function()
          return secret
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_mplus_timer.lua", "isiLive_killtrack.lua" })
      addon.MplusTimer.HandleEvent("CHALLENGE_MODE_START")
      local timer = addon.MplusTimer.GetTimerData()
      Assert.Equal(timer.keyLevel, 0, "secret keystone level must keep timer level unresolved")
      Assert.Equal(timer.timeLimit, 0, "secret challenge map must keep time limit unresolved")

      addon.KillTrack._DispatchEvent("CHALLENGE_MODE_START")
      Assert.False(addon.KillTrack.GetData().active, "secret challenge map must keep forces tracker inactive")
    end)
  end)

  test("Roster target location requires existing unit and rejects secret map", function()
    -- Rule 194: the marker compares instance IDs only. A secret target map,
    -- a secret instance ID from GetMapUIInfo or a secret own instance ID
    -- must leave the row unmarked, and no UiMapID is ever read.
    local secret = {}
    local mapLookups = 0
    local function BuildGlobals(targetInstanceID, ownInstanceID)
      return {
        issecretvalue = function(value)
          return value == secret
        end,
        UnitExists = function()
          return true
        end,
        C_Map = {
          GetBestMapForUnit = function()
            mapLookups = mapLookups + 1
            error("the at-dungeon marker must not read a UiMapID", 0)
          end,
        },
        C_ChallengeMode = {
          GetMapUIInfo = function(challengeMapID)
            return "Dungeon", challengeMapID, 1800, nil, nil, targetInstanceID
          end,
        },
        GetInstanceInfo = function()
          return "Dungeon", "party", 8, "Mythic Keystone", 5, 0, false, ownInstanceID, 5, nil
        end,
      }
    end

    WithGlobals(BuildGlobals(2813, 2813), function()
      local addon = LoadAddonModules({ "isiLive_roster_panel_render.lua" })
      local isAt = addon._RosterInternal.IsEntryAtTargetDungeon
      Assert.False(isAt(secret, { unit = "party1" }, { syncLocInstanceID = 2813 }), "secret target map")
      Assert.False(isAt(secret, { unit = "player" }, {}), "secret target map on the own row")
      Assert.True(isAt(587, { unit = "party1" }, { syncLocInstanceID = 2813 }), "synced instance matches")
      Assert.True(isAt(587, { unit = "player" }, {}), "own instance matches")
    end)

    WithGlobals(BuildGlobals(secret, 2813), function()
      local addon = LoadAddonModules({ "isiLive_roster_panel_render.lua" })
      local isAt = addon._RosterInternal.IsEntryAtTargetDungeon
      Assert.False(isAt(587, { unit = "party1" }, { syncLocInstanceID = 2813 }), "secret target instance")
      Assert.False(isAt(587, { unit = "player" }, {}), "secret target instance on the own row")
    end)

    WithGlobals(BuildGlobals(2813, secret), function()
      local addon = LoadAddonModules({ "isiLive_roster_panel_render.lua" })
      Assert.False(
        addon._RosterInternal.IsEntryAtTargetDungeon(587, { unit = "player" }, {}),
        "secret own instance must not mark the own row"
      )
    end)
    Assert.Equal(mapLookups, 0, "the at-dungeon marker never reads a UiMapID")
  end)

  test("VIP DK assist rejects secret specialization index", function()
    local secret = {}
    local scheduled = 0
    WithGlobals({
      issecretvalue = function(value)
        return value == secret
      end,
      UnitExists = function()
        return true
      end,
      UnitClass = function()
        return nil, "DEATHKNIGHT"
      end,
      C_SpecializationInfo = {
        GetSpecialization = function()
          return secret
        end,
        GetSpecializationInfo = function()
          error("secret specialization index must stop before info lookup", 0)
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_vip_dk_assist.lua" })
      local controller = addon.VipDkAssist.CreateController({
        getDB = function()
          return { vipDkSoulReaperWarningEnabled = true }
        end,
        timerAfter = function()
          scheduled = scheduled + 1
        end,
      })
      controller.HandleUnitSpellcastSucceeded("player", nil, 1233448)
      Assert.Equal(scheduled, 0, "secret specialization index must not schedule a warning")
    end)
  end)

  test("Status portal lookup rejects secret player map", function()
    local secret = {}
    local notices = 0
    WithGlobals({
      issecretvalue = function(value)
        return value == secret
      end,
      UnitExists = function()
        return true
      end,
      C_Map = {
        GetBestMapForUnit = function()
          return secret
        end,
        GetMapInfo = function()
          error("secret map must stop before map-info lookup", 0)
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = function()
          return {}
        end,
        showPortalNavigatorNotice = function()
          notices = notices + 1
        end,
        timerAfter = function() end,
      })
      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(notices, 0, "secret player map must not show the portal navigator")
    end)
  end)

  test("Unit-bound adapters stop before APIs for missing units", function()
    WithGlobals({
      UnitExists = function()
        return false
      end,
      GetReadyCheckStatus = function()
        error("missing unit must stop before ready-check lookup", 0)
      end,
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function()
        return 71
      end,
      UnitStat = function()
        error("missing player must stop before stat lookup", 0)
      end,
      C_UnitAuras = {
        GetAuraDataByIndex = function()
          error("missing unit must stop before aura lookup", 0)
        end,
      },
      UnitGUID = function()
        error("missing unit must stop before GUID lookup", 0)
      end,
      UnitName = function()
        error("missing unit must stop before name lookup", 0)
      end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_roster.lua",
        "isiLive_stats_box.lua",
        "isiLive_pi_tracker.lua",
        "isiLive_death_watch.lua",
        "isiLive_mob_nameplate.lua",
      })

      local display = addon.Roster.BuildDisplayData({
        name = "Player",
        class = "WARRIOR",
        role = "DAMAGER",
      }, {
        unit = "player",
        isReadyCheckActive = true,
      })
      Assert.Nil(display.readyCheckStatus, "missing unit must keep ready-check state unresolved")

      Assert.Equal(#addon.StatsBox.CollectPlayerStats({}), 0, "missing player must not produce stat rows")

      local pi = addon.PiTracker.CreateController({})
      Assert.False(pi.HandleUnitAura("party1", nil), "missing unit must not be scanned for auras")

      local deaths = addon.DeathWatch.CreateController({})
      Assert.Nil(deaths.GetDeathSummaryForUnit("party1"), "missing unit must not be read for a death summary")

      local dump = addon.MobNameplate.DumpState("nameplate1")
      Assert.False(dump.eligible, "missing nameplate unit must remain ineligible")
      Assert.Nil(dump.guid, "missing nameplate unit must not be read for a GUID")
      Assert.Nil(dump.unitName, "missing nameplate unit must not be read for a name")
    end)
  end)

  -- STATIC: a masked spell ID used as a table key or compared with `==`
  -- raises in the client, but plain Lua never consults a metamethod for either,
  -- so no runtime stub can turn the missing guard red. This pins the order on
  -- the source instead: the first statement of every UNIT_SPELLCAST_SUCCEEDED
  -- handler rejects the spell ID as secret, before the unit filter and before
  -- any lookup. The runtime half lives in the Mplus stress scenarios.
  test("UNIT_SPELLCAST_SUCCEEDED handlers reject a masked spell ID first", function()
    local handlers = {
      { path = "game/isiLive_kick_tracker.lua", signature = "function controller.OnCast(unit, spellID)" },
      {
        path = "game/isiLive_combat_events.lua",
        signature = "function controller.HandleUnitSpellcastSucceeded(unit, _, spellID)",
      },
      {
        path = "game/isiLive_vip_dk_assist.lua",
        signature = "function controller.HandleUnitSpellcastSucceeded(unit, _, spellID)",
      },
    }
    for _, handler in ipairs(handlers) do
      local file = assert(io.open(handler.path, "r"))
      local source = file:read("*a")
      file:close()
      local signatureAt = source:find(handler.signature, 1, true)
      signatureAt = Assert.NotNil(signatureAt, handler.path .. " must define " .. handler.signature)
      local bodyStart = source:find("\n", signatureAt, true) + 1
      local firstStatement = nil
      for line in source:sub(bodyStart):gmatch("[^\n]*") do
        local code = line:gsub("%-%-.*$", ""):match("^%s*(.-)%s*$")
        if code ~= "" then
          firstStatement = code
          break
        end
      end
      Assert.Equal(
        firstStatement,
        "if IsSecretValue(spellID) then",
        handler.path .. " must reject a masked spell ID before any other statement"
      )
    end
  end)

  -- STATIC: `== nil`, `~= nil`, a truth test and `tonumber` on a masked field
  -- never reach a Lua metamethod, so no runtime stub can turn these orderings
  -- red. Every local copied out of a Blizzard struct below must be rejected as
  -- secret before its first use (same ordering rule the gate applies to
  -- watched pcall results), and the tooltip flags must go through ReadPlain*.
  test("Masked-capable struct fields are rejected as secret before their first use", function()
    local checker = assert(loadfile("tools/check_secret_value_guards.lua"))("test")
    local function ReadSourceLines(path)
      local lines = {}
      for line in io.lines(path) do
        lines[#lines + 1] = line
      end
      return lines
    end

    local orderedLocals = {
      {
        path = "game/isiLive_killtrack.lua",
        anchor = "local numCriteria = stepInfo.numCriteria",
        name = "numCriteria",
      },
      { path = "game/isiLive_killtrack.lua", anchor = "local value = cInfo[field]", name = "value" },
      { path = "game/isiLive_killtrack.lua", anchor = "local apiTotalRaw = cInfo.totalQuantity", name = "apiTotalRaw" },
      { path = "game/isiLive_killtrack.lua", anchor = "local qStr = cInfo.quantityString", name = "qStr" },
      { path = "game/isiLive_killtrack.lua", anchor = "local qty = cInfo.quantity", name = "qty" },
    }
    for _, entry in ipairs(orderedLocals) do
      local lines = ReadSourceLines(entry.path)
      local anchorLine = nil
      for lineno, line in ipairs(lines) do
        if line:find(entry.anchor, 1, true) then
          anchorLine = lineno
          break
        end
      end
      anchorLine = Assert.NotNil(anchorLine, entry.path .. " must still read " .. entry.anchor)
      Assert.True(
        checker.ResultHasOrderedGuard(lines, anchorLine, entry.name),
        entry.path .. ":" .. anchorLine .. " must reject " .. entry.name .. " as secret before its first use"
      )
    end

    local file = assert(io.open("ui/isiLive_roster_tooltip.lua", "r"))
    local tooltipSource = file:read("*a")
    file:close()
    for _, rawRead in ipairs({ "tooltipData.isPlayer", "tooltipData.dataInstanceID" }) do
      Assert.Nil(
        tooltipSource:find(rawRead, 1, true),
        "ui/isiLive_roster_tooltip.lua must read " .. rawRead .. " through ReadPlainField"
      )
    end
  end)
end
