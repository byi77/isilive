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
    announcePowerInfusion = function(casterName, recipientName, isLocalRecipient)
      table.insert(announces, {
        casterName = casterName,
        recipientName = recipientName,
        isLocalRecipient = isLocalRecipient,
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
end
