---@diagnostic disable: undefined-global

local function LoadPiTracker(ctx)
  return ctx.load_modules({ "isiLive_pi_tracker.lua" }).PiTracker
end

local function BuildController(PiTracker, opts)
  opts = opts or {}
  local announces = opts.announces or {}
  local nowRef = opts.nowRef or { value = 100 }
  local classByUnit = opts.classByUnit or { party1 = "PRIEST" }
  local nameByUnit = opts.nameByUnit or { player = "Target-Realm", party1 = "Priest-Realm" }
  return PiTracker.CreateController({
    getTime = function()
      return nowRef.value
    end,
    getUnitName = function(unit)
      return nameByUnit[unit] or unit
    end,
    getUnitClassToken = function(unit)
      return classByUnit[unit]
    end,
    getAuraDataByIndex = opts.getAuraDataByIndex,
    getPlayerAuraBySpellID = opts.getPlayerAuraBySpellID,
    spellIDMatches = opts.spellIDMatches,
    announcePowerInfusion = function(casterName, recipientName, isLocalRecipient, isLocalCaster)
      table.insert(announces, {
        casterName = casterName,
        recipientName = recipientName,
        isLocalRecipient = isLocalRecipient,
        isLocalCaster = isLocalCaster,
      })
    end,
  }),
    announces,
    nowRef
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals

  test("PiTracker announces verified Power Infusion on player from UNIT_AURA addedAuras", function()
    local PiTracker
    WithGlobals({}, function()
      PiTracker = LoadPiTracker(ctx)
    end)
    local controller, announces = BuildController(PiTracker)
    controller.HandleUnitAura("player", {
      addedAuras = {
        { spellId = 10060, auraInstanceID = 77, sourceUnit = "party1" },
      },
    })
    Assert.Equal(#announces, 1, "PI on player must announce once")
    Assert.Equal(announces[1].casterName, "Priest-Realm", "verified priest source must be announced")
    Assert.Equal(announces[1].recipientName, "Target-Realm", "player recipient must be announced")
    Assert.True(announces[1].isLocalRecipient == true, "player recipient must be marked local")
    Assert.True(announces[1].isLocalCaster == false, "non-player priest source must not be marked local caster")
  end)

  test("PiTracker marks local Power Infusion caster from verified player source", function()
    local PiTracker
    WithGlobals({}, function()
      PiTracker = LoadPiTracker(ctx)
    end)
    local controller, announces = BuildController(PiTracker, {
      classByUnit = { player = "PRIEST" },
      nameByUnit = { player = "Priest-Realm", party2 = "Target-Realm" },
    })
    controller.HandleUnitAura("party2", {
      addedAuras = {
        { spellId = 10060, auraInstanceID = 88, sourceUnit = "player" },
      },
    })
    Assert.Equal(#announces, 1, "local PI caster must still announce verified PI")
    Assert.True(announces[1].isLocalRecipient == false, "party recipient must not be marked local")
    Assert.True(announces[1].isLocalCaster == true, "player source must be marked as local caster")
  end)

  test("PiTracker announces verified Power Infusion on party recipient without local flag", function()
    local PiTracker
    WithGlobals({}, function()
      PiTracker = LoadPiTracker(ctx)
    end)
    local controller, announces = BuildController(PiTracker, {
      nameByUnit = { player = "Me-Realm", party1 = "Priest-Realm", party2 = "TargetTwo-Realm" },
    })
    controller.HandleUnitAura("party2", {
      addedAuras = {
        { spellId = 10060, auraInstanceID = 78, sourceUnit = "party1" },
      },
    })
    Assert.Equal(#announces, 1, "PI on party member must still produce a local chat announce")
    Assert.Equal(announces[1].recipientName, "TargetTwo-Realm", "party recipient must be announced")
    Assert.True(announces[1].isLocalRecipient == false, "party recipient must not trigger local center alert")
  end)

  test("PiTracker does not guess Power Infusion caster when aura source is missing or not priest", function()
    local PiTracker
    WithGlobals({}, function()
      PiTracker = LoadPiTracker(ctx)
    end)
    local controller, announces = BuildController(PiTracker, {
      classByUnit = { party1 = "MAGE" },
    })
    controller.HandleUnitAura("player", {
      addedAuras = {
        { spellId = 10060, auraInstanceID = 79 },
        { spellId = 10060, auraInstanceID = 80, sourceUnit = "party1" },
      },
    })
    Assert.Equal(#announces, 0, "missing or non-priest source must stay silent")
  end)

  test("PiTracker ignores protected Power Infusion spell ids without dispatch failure", function()
    local PiTracker
    WithGlobals({}, function()
      PiTracker = LoadPiTracker(ctx)
    end)
    local controller, announces = BuildController(PiTracker, {
      spellIDMatches = function()
        error("attempt to compare a secret number value")
      end,
    })
    Assert.True(controller.HandleUnitAura("player", {
      addedAuras = {
        { spellId = 10060, auraInstanceID = 87, sourceUnit = "party1" },
      },
    }) == false, "protected spell ids must fail closed instead of aborting UNIT_AURA dispatch")
    Assert.Equal(#announces, 0, "protected spell ids must not announce PI from an unverifiable payload")
  end)

  test("PiTracker stays silent when caster or recipient name is unresolved", function()
    local PiTracker
    WithGlobals({}, function()
      PiTracker = LoadPiTracker(ctx)
    end)
    local controller, announces = BuildController(PiTracker, {
      nameByUnit = { party1 = "Priest-Realm", player = "player", party2 = "" },
    })
    controller.HandleUnitAura("player", {
      addedAuras = {
        { spellId = 10060, auraInstanceID = 85, sourceUnit = "party1" },
      },
    })
    controller.HandleUnitAura("party2", {
      addedAuras = {
        { spellId = 10060, auraInstanceID = 86, sourceUnit = "party1" },
      },
    })
    Assert.Equal(#announces, 0, "unresolved caster or recipient names must not be guessed from unit tokens")
  end)

  test("PiTracker scans full aura updates for verified Power Infusion", function()
    local PiTracker
    WithGlobals({}, function()
      PiTracker = LoadPiTracker(ctx)
    end)
    local controller, announces = BuildController(PiTracker, {
      getAuraDataByIndex = function(_unit, index, filter)
        if filter == "HELPFUL" and index == 3 then
          return { spellId = 10060, auraInstanceID = 81, sourceUnit = "party1" }
        end
        return nil
      end,
    })
    controller.HandleUnitAura("player", { isFullUpdate = true })
    Assert.Equal(#announces, 1, "full update scan must detect verified PI")
  end)

  test("PiTracker deduplicates repeated Power Infusion aura updates", function()
    local PiTracker
    WithGlobals({}, function()
      PiTracker = LoadPiTracker(ctx)
    end)
    local controller, announces, nowRef = BuildController(PiTracker)
    local payload = {
      addedAuras = {
        { spellId = 10060, auraInstanceID = 82, sourceUnit = "party1" },
      },
    }
    controller.HandleUnitAura("player", payload)
    nowRef.value = 110
    controller.HandleUnitAura("player", payload)
    Assert.Equal(#announces, 1, "same PI aura inside dedup window must not announce twice")
    nowRef.value = 131
    controller.HandleUnitAura("player", payload)
    Assert.Equal(#announces, 2, "PI aura may announce again after dedup window")
  end)

  test("PiTracker default WoW adapters read time aura names and priest class token", function()
    local PiTracker
    local announces = {}
    WithGlobals({
      UnitExists = function()
        return true
      end,
      GetTime = function()
        return 250
      end,
      C_UnitAuras = {
        GetAuraDataByIndex = function(unit, index, filter)
          if unit == "player" and index == 2 and filter == "HELPFUL" then
            return { spellId = 10060, auraInstanceID = "default-aura", sourceUnit = "party1" }
          end
          return nil
        end,
      },
      GetUnitName = function(unit, _showServerName)
        if unit == "player" then
          return "DefaultTarget-Realm"
        end
        if unit == "party1" then
          return "DefaultPriest-Realm"
        end
        return ""
      end,
      UnitClass = function(unit)
        if unit == "party1" then
          return "Priest", "PRIEST"
        end
        return "Mage", "MAGE"
      end,
    }, function()
      PiTracker = LoadPiTracker(ctx)
      local controller = PiTracker.CreateController({
        announcePowerInfusion = function(casterName, recipientName, isLocalRecipient)
          table.insert(announces, {
            casterName = casterName,
            recipientName = recipientName,
            isLocalRecipient = isLocalRecipient,
          })
        end,
      })
      Assert.True(controller.HandleUnitAura("player", { isFullUpdate = true }) == true, "default scan must announce PI")
    end)
    Assert.Equal(#announces, 1, "default adapters must announce exactly once")
    Assert.Equal(announces[1].casterName, "DefaultPriest-Realm", "default GetUnitName must resolve caster")
    Assert.Equal(announces[1].recipientName, "DefaultTarget-Realm", "default GetUnitName must resolve recipient")
    Assert.True(announces[1].isLocalRecipient == true, "player recipient remains local")
  end)

  test("PiTracker default WoW name adapter fails closed when names are unavailable", function()
    local PiTracker
    local announces = {}
    WithGlobals({
      GetTime = function()
        return 251
      end,
      C_UnitAuras = {
        GetAuraDataByIndex = function(unit, index, filter)
          if unit == "player" and index == 1 and filter == "HELPFUL" then
            return { spellId = 10060, auraInstanceID = "unnamed-aura", sourceUnit = "party1" }
          end
          return nil
        end,
      },
      GetUnitName = function()
        return ""
      end,
      UnitName = function()
        return nil
      end,
      UnitClass = function(unit)
        if unit == "party1" then
          return "Priest", "PRIEST"
        end
        return "Mage", "MAGE"
      end,
    }, function()
      PiTracker = LoadPiTracker(ctx)
      local controller = PiTracker.CreateController({
        announcePowerInfusion = function(casterName, recipientName, isLocalRecipient)
          table.insert(announces, {
            casterName = casterName,
            recipientName = recipientName,
            isLocalRecipient = isLocalRecipient,
          })
        end,
      })
      Assert.True(
        controller.HandleUnitAura("player", { isFullUpdate = true }) == false,
        "unresolved names must fail closed"
      )
    end)
    Assert.Equal(#announces, 0, "default adapter must not synthesize names from unit tokens")
  end)

  test("PiTracker controller fails closed for unsupported units partial updates and reset", function()
    local PiTracker
    WithGlobals({}, function()
      PiTracker = LoadPiTracker(ctx)
    end)
    local controller, announces = BuildController(PiTracker, {
      getAuraDataByIndex = function()
        return nil
      end,
    })
    Assert.True(controller.HandleUnitAura("target", nil) == false, "unsupported units must stay silent")
    Assert.True(
      controller.HandleUnitAura("player", { updatedAuraInstanceIDs = { 99 } }) == false,
      "partial non-added updates must stay silent"
    )
    Assert.True(
      controller.HandleUnitAura("player", nil) == false,
      "nil update may scan but stays silent without verified aura"
    )
    Assert.Equal(controller._Test_GetRecentSize(), 0, "empty tracker starts with no recent entries")

    controller.HandleUnitAura("player", {
      addedAuras = {
        { spellId = 10060, auraInstanceID = 83, sourceUnit = "party1" },
      },
    })
    Assert.Equal(#announces, 1, "verified PI must be stored before reset")
    Assert.Equal(controller._Test_GetRecentSize(), 1, "verified PI must create one dedup entry")
    controller.Reset()
    Assert.Equal(controller._Test_GetRecentSize(), 0, "reset must clear dedup entries")
  end)

  test("PiTracker module event wrapper installs dependencies handles aura and reset events", function()
    local PiTracker
    local announces = {}
    WithGlobals({}, function()
      PiTracker = LoadPiTracker(ctx)
    end)
    PiTracker.HandleEvent("UNIT_AURA", "player", {
      addedAuras = {
        { spellId = 10060, auraInstanceID = 84, sourceUnit = "party1" },
      },
    })
    PiTracker.SetDependencies(nil)
    PiTracker.SetDependencies({
      getTime = function()
        return 300
      end,
      getUnitName = function(unit)
        return unit == "party1" and "WrapperPriest-Realm" or "WrapperTarget-Realm"
      end,
      getUnitClassToken = function(unit)
        return unit == "party1" and "PRIEST" or "MAGE"
      end,
      announcePowerInfusion = function(casterName, recipientName, isLocalRecipient)
        table.insert(announces, {
          casterName = casterName,
          recipientName = recipientName,
          isLocalRecipient = isLocalRecipient,
        })
      end,
    })
    PiTracker.HandleEvent("UNIT_AURA", "player", {
      addedAuras = {
        { spellId = 10060, auraInstanceID = 84, sourceUnit = "party1" },
      },
    })
    PiTracker.HandleEvent("GROUP_ROSTER_UPDATE")
    PiTracker.HandleEvent("UNIT_AURA", "player", {
      addedAuras = {
        { spellId = 10060, auraInstanceID = 84, sourceUnit = "party1" },
      },
    })
    PiTracker.HandleEvent("PLAYER_ENTERING_WORLD")
    Assert.Equal(#announces, 2, "reset event must allow the same verified PI aura to announce again")
    Assert.Equal(announces[1].casterName, "WrapperPriest-Realm", "wrapper must use configured caster resolver")
    Assert.True(announces[1].isLocalRecipient == true, "wrapper must preserve local recipient flag")
  end)

  -- WoW 12.1 masks `unitAuraUpdateInfo.isFullUpdate` as a Secret Value inside
  -- restricted instances. Comparing it raised "attempt to compare field
  -- 'isFullUpdate' (a secret boolean value)", which killed the whole UNIT_AURA
  -- dispatch and printed one error line per event.
  test("PiTracker treats a masked UNIT_AURA full-update flag as a full update", function()
    local PiTracker
    local secret = {}
    WithGlobals({
      issecretvalue = function(value)
        return value == secret
      end,
    }, function()
      PiTracker = LoadPiTracker(ctx)
      local controller, announces = BuildController(PiTracker, {
        getAuraDataByIndex = function(unit, index)
          if unit == "player" and index == 1 then
            return { spellId = 10060, auraInstanceID = 91, sourceUnit = "party1" }
          end
          return nil
        end,
      })

      Assert.True(
        controller.HandleUnitAura("player", { isFullUpdate = secret }) == true,
        "a masked flag without any delta list must still be scanned like a full update"
      )
      Assert.Equal(#announces, 1, "the inferred full-update scan must announce the verified PI")
    end)
  end)

  test("PiTracker skips the full scan when a masked flag arrives next to a delta list", function()
    local PiTracker
    local secret = {}
    local scans = 0
    WithGlobals({
      issecretvalue = function(value)
        return value == secret
      end,
    }, function()
      PiTracker = LoadPiTracker(ctx)
      local controller = BuildController(PiTracker, {
        getAuraDataByIndex = function()
          scans = scans + 1
          return nil
        end,
      })

      Assert.True(
        controller.HandleUnitAura("player", { isFullUpdate = secret, updatedAuraInstanceIDs = { 7 } }) == false,
        "a delta payload must not be promoted to a full update just because the flag is masked"
      )
      Assert.Equal(scans, 0, "an incremental payload must not trigger the 40-slot scan")
    end)
  end)

  test("PiTracker survives a UNIT_AURA payload whose field reads raise", function()
    local PiTracker
    WithGlobals({}, function()
      PiTracker = LoadPiTracker(ctx)
    end)
    local controller, announces = BuildController(PiTracker, {
      getAuraDataByIndex = function()
        return nil
      end,
    })

    local hostilePayload = setmetatable({}, {
      __index = function()
        error("attempt to compare field 'isFullUpdate' (a secret boolean value)", 0)
      end,
    })
    Assert.False(
      pcall(function()
        return hostilePayload.isFullUpdate == true
      end),
      "the fixture must reproduce a payload whose plain field read raises"
    )
    Assert.True(controller.HandleUnitAura("player", hostilePayload) == false, "a hostile payload must fail closed")
    Assert.Equal(#announces, 0, "a hostile payload must not synthesize an announce")
  end)

  test("PiTracker keeps masked aura fields out of the announce path", function()
    local PiTracker
    local secret = {}
    WithGlobals({
      issecretvalue = function(value)
        return value == secret
      end,
    }, function()
      PiTracker = LoadPiTracker(ctx)
      local controller, announces = BuildController(PiTracker)

      Assert.True(controller.HandleUnitAura("player", {
        addedAuras = { { spellId = 10060, auraInstanceID = 92, sourceUnit = secret } },
      }) == false, "a masked source unit must not be compared or announced")
      Assert.True(controller.HandleUnitAura("player", {
        addedAuras = { { spellId = secret, auraInstanceID = 93, sourceUnit = "party1" } },
      }) == false, "a masked spell id must not reach the spell-id match")
      Assert.Equal(#announces, 0, "masked aura fields must keep the tracker silent")
    end)
  end)
  -- The payload path stays silent on masked fields, which is correct -- but that
  -- left the player without any Power Infusion feedback inside instances, where
  -- 12.1 masks spellId/sourceUnit. The self-receive path answers from the
  -- player's own buff instead and does not depend on those fields.
  test("PiTracker announces own Power Infusion when the aura payload is masked", function()
    local PiTracker
    WithGlobals({}, function()
      PiTracker = LoadPiTracker(ctx)
    end)
    local controller, announces = BuildController(PiTracker, {
      getPlayerAuraBySpellID = function(spellID)
        Assert.Equal(spellID, 10060, "the self lookup must ask for the Power Infusion spell id")
        return { spellId = nil, sourceUnit = nil }
      end,
    })

    Assert.True(controller.HandleUnitAura("player", { isFullUpdate = false }), "masked payload must still announce")
    Assert.Equal(#announces, 1, "exactly one announcement for the received buff")
    Assert.Equal(announces[1].isLocalRecipient, true, "the player is the recipient")
    Assert.Equal(announces[1].recipientName, "Target-Realm", "the recipient name comes from the player unit")
    Assert.Nil(announces[1].casterName, "an unknown caster must not be invented")
  end)

  test("PiTracker does not repeat the own-Power-Infusion announcement while it lasts", function()
    local PiTracker
    WithGlobals({}, function()
      PiTracker = LoadPiTracker(ctx)
    end)
    local hasAura = true
    local controller, announces = BuildController(PiTracker, {
      getPlayerAuraBySpellID = function()
        return hasAura and {} or nil
      end,
    })

    controller.HandleUnitAura("player", { isFullUpdate = false })
    controller.HandleUnitAura("player", { isFullUpdate = false })
    Assert.Equal(#announces, 1, "a still-running buff must not announce again")

    hasAura = false
    controller.HandleUnitAura("player", { isFullUpdate = false })
    Assert.Equal(#announces, 1, "losing the buff must not announce")

    hasAura = true
    controller.HandleUnitAura("player", { isFullUpdate = false })
    Assert.Equal(#announces, 2, "receiving it again must announce again")
  end)

  test("PiTracker announces own Power Infusion once when both paths see it", function()
    local PiTracker
    WithGlobals({}, function()
      PiTracker = LoadPiTracker(ctx)
    end)
    local controller, announces = BuildController(PiTracker, {
      getPlayerAuraBySpellID = function()
        return { sourceUnit = "party1" }
      end,
    })

    -- Readable payload AND a readable self aura: the caster is known, and the
    -- shared latch keeps it to a single message.
    controller.HandleUnitAura("player", {
      isFullUpdate = false,
      addedAuras = { { spellId = 10060, sourceUnit = "party1", auraInstanceID = 7 } },
    })
    Assert.Equal(#announces, 1, "both paths seeing the same buff must announce once")
    Assert.Equal(announces[1].casterName, "Priest-Realm", "a readable sourceUnit must still name the caster")
  end)
end
