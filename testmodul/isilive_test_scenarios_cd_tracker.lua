---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function MakeController(overrides)
    overrides = overrides or {}
    local addon = LoadAddonModules({ "isiLive_cd_tracker.lua" })
    return addon.CdTracker.CreateController({
      getTime = overrides.getTime or function()
        return 0
      end,
    })
  end

  -- BRes tests

  test("CdTracker returns nil BRes info before first scan", function()
    WithGlobals({}, function()
      local ctrl = MakeController()
      Assert.Nil(ctrl.GetBResInfo(), "BRes info must be nil before Scan() is called")
    end)
  end)

  test("CdTracker returns nil BRes info when C_Spell is unavailable", function()
    WithGlobals({ C_Spell = nil }, function()
      local ctrl = MakeController()
      ctrl.Scan()
      Assert.Nil(ctrl.GetBResInfo(), "BRes info must be nil when C_Spell API is missing")
    end)
  end)

  test("CdTracker returns nil BRes info when GetSpellCharges returns no data", function()
    WithGlobals({
      C_Spell = {
        GetSpellCharges = function()
          return nil
        end,
      },
    }, function()
      local ctrl = MakeController()
      ctrl.Scan()
      Assert.Nil(ctrl.GetBResInfo(), "BRes info must be nil when GetSpellCharges returns nil")
    end)
  end)

  test("CdTracker reports BRes charges when spell is available and charges are full", function()
    WithGlobals({
      C_Spell = {
        GetSpellCharges = function()
          return 3, 3, 0, 0, 0
        end,
      },
    }, function()
      local ctrl = MakeController({
        getTime = function()
          return 1000
        end,
      })
      ctrl.Scan()
      local info = ctrl.GetBResInfo()
      Assert.NotNil(info, "BRes info must not be nil when charges are available")
      Assert.Equal(info.charges, 3, "charges should match GetSpellCharges return value")
      Assert.Equal(info.maxCharges, 3, "maxCharges should match GetSpellCharges return value")
      Assert.Equal(info.cooldownRemain, 0, "cooldownRemain must be 0 when charges are full")
    end)
  end)

  test("CdTracker calculates remaining cooldown when BRes is on cooldown", function()
    WithGlobals({
      C_Spell = {
        GetSpellCharges = function()
          -- charges=1, maxCharges=3, rechargeTime=0, chargeStart=900, chargeDuration=480
          return 1, 3, 0, 900, 480
        end,
      },
    }, function()
      local ctrl = MakeController({
        getTime = function()
          return 1000
        end,
      })
      ctrl.Scan()
      local info = ctrl.GetBResInfo()
      Assert.NotNil(info, "BRes info must not be nil when on cooldown")
      Assert.Equal(info.charges, 1, "charges should be 1")
      -- remain = chargeStart + chargeDuration - getTime = 900 + 480 - 1000 = 380
      Assert.Equal(info.cooldownRemain, 380, "cooldownRemain should be chargeStart + duration - now")
    end)
  end)

  test("CdTracker clamps BRes cooldown to zero when timer has expired", function()
    WithGlobals({
      C_Spell = {
        GetSpellCharges = function()
          return 2, 3, 0, 500, 100
        end,
      },
    }, function()
      -- getTime is past the cooldown expiry (500+100=600, now=700)
      local ctrl = MakeController({
        getTime = function()
          return 700
        end,
      })
      ctrl.Scan()
      local info = ctrl.GetBResInfo()
      Assert.NotNil(info, "BRes info must not be nil")
      Assert.Equal(info.cooldownRemain, 0, "expired cooldown must clamp to 0, not go negative")
    end)
  end)

  test("CdTracker tolerates pcall error from GetSpellCharges", function()
    WithGlobals({
      C_Spell = {
        GetSpellCharges = function()
          error("simulated WoW API error")
        end,
      },
    }, function()
      local ctrl = MakeController()
      ctrl.Scan()
      Assert.Nil(ctrl.GetBResInfo(), "BRes info must be nil when GetSpellCharges throws")
    end)
  end)

  -- Lust tests

  test("CdTracker returns nil Lust info before first scan", function()
    WithGlobals({}, function()
      local ctrl = MakeController()
      Assert.Nil(ctrl.GetLustInfo(), "Lust info must be nil before Scan() is called")
    end)
  end)

  test("CdTracker returns nil Lust info when C_UnitAuras is unavailable", function()
    WithGlobals({ C_UnitAuras = nil }, function()
      local ctrl = MakeController()
      ctrl.Scan()
      Assert.Nil(ctrl.GetLustInfo(), "Lust info must be nil when C_UnitAuras API is missing")
    end)
  end)

  test("CdTracker returns nil Lust info when no lust aura is active", function()
    WithGlobals({
      C_UnitAuras = {
        GetPlayerAuraBySpellID = function(_)
          return nil
        end,
      },
    }, function()
      local ctrl = MakeController()
      ctrl.Scan()
      Assert.Nil(ctrl.GetLustInfo(), "Lust info must be nil when no matching aura is found")
    end)
  end)

  test("CdTracker detects active Bloodlust and reports remaining time", function()
    local NOW = 1000
    -- Sated debuff (57723) with 350 seconds remaining
    local auras = {
      [57723] = { expirationTime = NOW + 350, icon = 132114 },
    }
    WithGlobals({
      C_UnitAuras = {
        GetPlayerAuraBySpellID = function(spellId)
          return auras[spellId] or nil
        end,
      },
    }, function()
      local ctrl = MakeController({
        getTime = function()
          return NOW
        end,
      })
      ctrl.Scan()
      local info = ctrl.GetLustInfo()
      Assert.NotNil(info, "Lust info must not be nil when Sated aura is active")
      Assert.Equal(info.remain, 350, "remain should equal expirationTime - now")
      Assert.Equal(info.icon, 132114, "icon should match the aura's icon field")
    end)
  end)

  test("CdTracker returns nil Lust info when aura expiration time is in the past", function()
    local NOW = 1000
    local auras = {
      [2825] = { expirationTime = NOW - 10, icon = 132114 },
    }
    WithGlobals({
      C_UnitAuras = {
        GetPlayerAuraBySpellID = function(spellId)
          return auras[spellId] or nil
        end,
      },
    }, function()
      local ctrl = MakeController({
        getTime = function()
          return NOW
        end,
      })
      ctrl.Scan()
      Assert.Nil(ctrl.GetLustInfo(), "Lust info must be nil when aura expiration is in the past")
    end)
  end)

  test(
    "CdTracker reads aura fields via rawget — direct table fields are accessible, __index trap is not triggered",
    function()
      local NOW = 1000
      local unexpectedKeyAccessed = false
      -- Simulate a WoW aura object: real fields stored directly in the table (rawget works),
      -- __index trap catches any non-direct access to unexpected keys.
      local aura = setmetatable({ expirationTime = NOW + 200, icon = 132114 }, {
        __index = function(_, key)
          if key ~= "expirationTime" and key ~= "icon" then
            unexpectedKeyAccessed = true
          end
          return nil
        end,
      })
      local auras = { [57724] = aura }
      WithGlobals({
        C_UnitAuras = {
          GetPlayerAuraBySpellID = function(spellId)
            return auras[spellId] or nil
          end,
        },
      }, function()
        local ctrl = MakeController({
          getTime = function()
            return NOW
          end,
        })
        ctrl.Scan()
        local info = ctrl.GetLustInfo()
        Assert.NotNil(info, "Lust info must be detected when aura fields are stored directly in the table")
        Assert.Equal(info.remain, 200, "remain should be calculated from the direct expirationTime field")
        Assert.Equal(info.icon, 132114, "icon should be read from the direct icon field")
        Assert.False(unexpectedKeyAccessed, "no unexpected key access should occur via __index")
      end)
    end
  )

  test("CdTracker Scan updates BRes and Lust state independently", function()
    local NOW = 500
    WithGlobals({
      C_Spell = {
        GetSpellCharges = function()
          return 2, 3, 0, 400, 200
        end,
      },
      C_UnitAuras = {
        GetPlayerAuraBySpellID = function(_)
          return nil
        end,
      },
    }, function()
      local ctrl = MakeController({
        getTime = function()
          return NOW
        end,
      })
      ctrl.Scan()
      -- BRes: 2/3 charges, cooldown = 400+200-500 = 100
      local bres = ctrl.GetBResInfo()
      Assert.NotNil(bres, "BRes info must be populated after Scan")
      Assert.Equal(bres.charges, 2, "BRes charges should be 2")
      Assert.Equal(bres.cooldownRemain, 100, "BRes cooldown should be 100s")
      -- Lust: no aura active
      Assert.Nil(ctrl.GetLustInfo(), "Lust info must be nil when no aura is active")
    end)
  end)
end
