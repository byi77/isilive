---@diagnostic disable: undefined-global, need-check-nil
local LoadAddonModules = nil
local MakeController = nil
local LUST_ZONE_TRANSITION_SUPPRESS_SECONDS = 2

local function BuildHarmfulAuraApi(getAuras)
  return {
    GetAuraDataByIndex = function(unit, index, filter)
      if unit ~= "player" or filter ~= "HARMFUL" then
        return nil
      end
      local auras = type(getAuras) == "function" and getAuras() or nil
      if type(auras) ~= "table" then
        return nil
      end
      return auras[index]
    end,
  }
end

local function MakeLustAura(expirationTime, spellId, icon)
  return {
    spellId = spellId or 57723,
    expirationTime = expirationTime,
    icon = icon or 132114,
  }
end

local function RegisterCdTrackerLustCallbackTests(test, Assert, WithGlobals)
  -- onLustStart / SuppressOnset tests

  test("CdTracker fires onLustStart callback on first lust detection", function()
    local now = 1000
    local auras = { MakeLustAura(now + 300) }
    local fired = 0
    WithGlobals({
      C_UnitAuras = BuildHarmfulAuraApi(function()
        return auras
      end),
    }, function()
      local ctrl = MakeController({
        getTime = function()
          return now
        end,
        onLustStart = function()
          fired = fired + 1
        end,
      })
      ctrl.Scan()
      Assert.Equal(fired, 1, "onLustStart must fire once when lust appears for the first time")
      ctrl.Scan()
      Assert.Equal(fired, 1, "onLustStart must not fire again while lust remains active")
    end)
  end)

  test("CdTracker fires onLustStart again after lust drops and reappears", function()
    local now = 1000
    local lustActive = true
    local fired = 0
    WithGlobals({
      C_UnitAuras = BuildHarmfulAuraApi(function()
        if lustActive then
          return { MakeLustAura(now + 300) }
        end
        return {}
      end),
    }, function()
      local ctrl = MakeController({
        getTime = function()
          return now
        end,
        onLustStart = function()
          fired = fired + 1
        end,
      })
      ctrl.Scan()
      Assert.Equal(fired, 1, "onLustStart must fire on first detection")
      lustActive = false
      ctrl.Scan()
      Assert.Equal(fired, 1, "onLustStart must not fire when lust drops")
      lustActive = true
      ctrl.Scan()
      Assert.Equal(fired, 2, "onLustStart must fire again when lust reappears after a gap")
    end)
  end)

  test("CdTracker SuppressOnset blocks onLustStart within the suppress window", function()
    local now = 1000
    local lustActive = false
    local fired = 0
    WithGlobals({
      C_UnitAuras = BuildHarmfulAuraApi(function()
        if lustActive then
          return { MakeLustAura(now + 300) }
        end
        return {}
      end),
    }, function()
      local ctrl = MakeController({
        getTime = function()
          return now
        end,
        onLustStart = function()
          fired = fired + 1
        end,
      })
      ctrl.SuppressOnset(3)
      lustActive = true
      ctrl.Scan()
      Assert.Equal(fired, 0, "onLustStart must be suppressed within the 3-second window")
    end)
  end)

  test("CdTracker SuppressOnset allows onLustStart after the suppress window expires", function()
    local now = 1000
    local lustActive = false
    local fired = 0
    WithGlobals({
      C_UnitAuras = BuildHarmfulAuraApi(function()
        if lustActive then
          return { MakeLustAura(now + 300) }
        end
        return {}
      end),
    }, function()
      local ctrl = MakeController({
        getTime = function()
          return now
        end,
        onLustStart = function()
          fired = fired + 1
        end,
      })
      ctrl.SuppressOnset(3)
      now = 1004
      lustActive = true
      ctrl.Scan()
      Assert.Equal(fired, 1, "onLustStart must fire once the suppress window has expired")
    end)
  end)

  test(
    "CdTracker SuppressOnset + immediate Scan blocks false positive when lust reappears after zone change",
    function()
      local now = 1000
      local lustActive = true
      local fired = 0
      WithGlobals({
        C_UnitAuras = BuildHarmfulAuraApi(function()
          if lustActive then
            return { MakeLustAura(now + 300) }
          end
          return {}
        end),
      }, function()
        local ctrl = MakeController({
          getTime = function()
            return now
          end,
          onLustStart = function()
            fired = fired + 1
          end,
        })
        -- Lust was active before zone change
        ctrl.Scan()
        Assert.Equal(fired, 1, "onLustStart must fire on first detection before zone change")

        -- Zone change: lust temporarily disappears
        lustActive = false
        ctrl.Scan()
        Assert.Equal(fired, 1, "onLustStart must not fire when lust disappears")

        -- Simulate PLAYER_ENTERING_WORLD: suppress (3s) + immediate scan while lust still absent
        ctrl.SuppressOnset(LUST_ZONE_TRANSITION_SUPPRESS_SECONDS)
        ctrl.Scan()
        Assert.Equal(fired, 1, "immediate scan during suppress must not fire onset even with lust absent")

        -- Lust reappears after loading screen (before suppress expires)
        lustActive = true
        now = 1000 + LUST_ZONE_TRANSITION_SUPPRESS_SECONDS - 1
        ctrl.Scan()
        Assert.Equal(
          fired,
          1,
          "onLustStart must not fire again when lust reappears within suppress window after zone change"
        )

        -- After suppress expires, lust is still active - no second onset
        now = 1000 + LUST_ZONE_TRANSITION_SUPPRESS_SECONDS + 1
        ctrl.Scan()
        Assert.Equal(
          fired,
          1,
          "onLustStart must not fire again after suppress expires while lust remains continuously active"
        )
      end)
    end
  )

  test("CdTracker Scan with isFullUpdate=true does not fire onset when lust appears", function()
    local now = 1000
    local lustActive = true
    local fired = 0
    WithGlobals({
      C_UnitAuras = BuildHarmfulAuraApi(function()
        if lustActive then
          return { MakeLustAura(now + 300) }
        end
        return {}
      end),
    }, function()
      local ctrl = MakeController({
        getTime = function()
          return now
        end,
        onLustStart = function()
          fired = fired + 1
        end,
      })
      ctrl.Scan(true) -- isFullUpdate: zone/reload aura restore
      Assert.Equal(fired, 0, "isFullUpdate scan must not fire onset")
      Assert.NotNil(ctrl.GetLustInfo(), "lust info must still be populated after isFullUpdate scan")
      ctrl.Scan(false) -- subsequent normal scan: wasLustActive already true
      Assert.Equal(fired, 0, "normal scan after isFullUpdate must not fire onset (wasLustActive already set)")
    end)
  end)

  test("CdTracker Scan with isFullUpdate=true blocks false positive even after suppress window expires", function()
    -- Slow loading screen: UNIT_AURA(isFullUpdate=true) arrives after the suppress window.
    -- isFullUpdate must still prevent the false positive regardless of timing.
    local now = 1000
    local lustActive = false
    local fired = 0
    WithGlobals({
      C_UnitAuras = BuildHarmfulAuraApi(function()
        if lustActive then
          return { MakeLustAura(now + 300) }
        end
        return {}
      end),
    }, function()
      local ctrl = MakeController({
        getTime = function()
          return now
        end,
        onLustStart = function()
          fired = fired + 1
        end,
      })
      ctrl.SuppressOnset(LUST_ZONE_TRANSITION_SUPPRESS_SECONDS)
      now = 1000 + LUST_ZONE_TRANSITION_SUPPRESS_SECONDS + 5 -- suppress long expired
      lustActive = true
      ctrl.Scan(true) -- UNIT_AURA(isFullUpdate=true) arrives late
      Assert.Equal(fired, 0, "isFullUpdate must block false positive even after suppress window has expired")
      ctrl.Scan(false) -- ticker fires after: wasLustActive already true
      Assert.Equal(fired, 0, "normal scan after late isFullUpdate must not fire onset")
    end)
  end)

  test("CdTracker SuppressOnset with active lust blocks onset on reload via internal full scan", function()
    -- On UI reload the Sated aura is already present when PLAYER_ENTERING_WORLD fires.
    -- SuppressOnset must capture this state so that a subsequent aura removal+re-add
    -- from UNIT_AURA does not trigger a false onset.
    local now = 1000
    local lustExpiration = 1600
    local lustActive = true
    local fired = 0
    WithGlobals({
      C_UnitAuras = BuildHarmfulAuraApi(function()
        if lustActive then
          return { MakeLustAura(lustExpiration) }
        end
        return {}
      end),
    }, function()
      local ctrl = MakeController({
        getTime = function()
          return now
        end,
        onLustStart = function()
          fired = fired + 1
        end,
      })

      -- PLAYER_ENTERING_WORLD: SuppressOnset does internal isFullUpdate scan, finds Sated
      ctrl.SuppressOnset(LUST_ZONE_TRANSITION_SUPPRESS_SECONDS)
      Assert.Equal(fired, 0, "SuppressOnset internal scan must not fire onset")

      -- Aura briefly removed (UNIT_AURA removal signal)
      lustActive = false
      ctrl.Scan(false)
      Assert.Equal(fired, 0, "scan with absent aura must not fire onset")

      -- Aura reappears via UNIT_AURA(isFullUpdate=true) after suppress window expires
      now = 1000 + LUST_ZONE_TRANSITION_SUPPRESS_SECONDS + 2
      lustActive = true
      ctrl.Scan(true)
      Assert.Equal(fired, 0, "isFullUpdate re-appearance after suppress window must not fire onset")
    end)
  end)

  -- NotifySpellCast tests

  test("CdTracker NotifySpellCast fires onLustStart for a known lust spell ID", function()
    WithGlobals({}, function()
      local fired = 0
      local ctrl = MakeController({
        onLustStart = function()
          fired = fired + 1
        end,
      })
      ctrl.NotifySpellCast(2825) -- Bloodlust
      Assert.Equal(fired, 1, "onLustStart must fire for a known lust spell ID")
    end)
  end)

  test("CdTracker NotifySpellCast ignores unknown spell IDs", function()
    WithGlobals({}, function()
      local fired = 0
      local ctrl = MakeController({
        onLustStart = function()
          fired = fired + 1
        end,
      })
      ctrl.NotifySpellCast(12345) -- not a lust spell
      Assert.Equal(fired, 0, "onLustStart must not fire for an unknown spell ID")
    end)
  end)

  test("CdTracker NotifySpellCast fires onLustStart even within the suppress window", function()
    local now = 1000
    WithGlobals({}, function()
      local fired = 0
      local ctrl = MakeController({
        getTime = function()
          return now
        end,
        onLustStart = function()
          fired = fired + 1
        end,
      })
      ctrl.SuppressOnset(3) -- window active until now+3
      ctrl.NotifySpellCast(32182) -- Heroism bypasses suppress
      Assert.Equal(fired, 1, "onLustStart must fire via NotifySpellCast even inside the suppress window")
    end)
  end)

  test("CdTracker Scan does not double-fire onLustStart after NotifySpellCast", function()
    local now = 1000
    local auras = { MakeLustAura(now + 300) }
    WithGlobals({
      C_UnitAuras = BuildHarmfulAuraApi(function()
        return auras
      end),
    }, function()
      local fired = 0
      local ctrl = MakeController({
        getTime = function()
          return now
        end,
        onLustStart = function()
          fired = fired + 1
        end,
      })
      ctrl.NotifySpellCast(2825) -- sets wasLustActive = true
      Assert.Equal(fired, 1, "onLustStart must fire once via NotifySpellCast")
      ctrl.Scan() -- aura is active, but wasLustActive is already true
      Assert.Equal(fired, 1, "Scan must not fire onLustStart again after NotifySpellCast already fired it")
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  LoadAddonModules = ctx.load_modules

  MakeController = function(overrides)
    overrides = overrides or {}
    local addon = LoadAddonModules({ "isiLive_cd_tracker.lua" })
    return addon.CdTracker.CreateController({
      getTime = overrides.getTime or function()
        return 0
      end,
      onLustStart = overrides.onLustStart,
      -- Tests exercise onset directly without simulating PLAYER_ENTERING_WORLD first,
      -- so bypass the ready-gate that blocks onset before SuppressOnset is ever called.
      skipReadyGate = true,
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
      C_UnitAuras = BuildHarmfulAuraApi(function()
        return {}
      end),
    }, function()
      local ctrl = MakeController()
      ctrl.Scan()
      Assert.Nil(ctrl.GetLustInfo(), "Lust info must be nil when no matching aura is found")
    end)
  end)

  test("CdTracker detects active Bloodlust and reports remaining time", function()
    local NOW = 1000
    -- Sated debuff (57723) with 350 seconds remaining
    local auras = { MakeLustAura(NOW + 350, 57723) }
    WithGlobals({
      C_UnitAuras = BuildHarmfulAuraApi(function()
        return auras
      end),
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
    local auras = { MakeLustAura(NOW - 10, 57723) }
    WithGlobals({
      C_UnitAuras = BuildHarmfulAuraApi(function()
        return auras
      end),
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
    "CdTracker reads aura fields via rawget - direct table fields are accessible, __index trap is not triggered",
    function()
      local NOW = 1000
      local unexpectedKeyAccessed = false
      -- Simulate a WoW aura object: real fields stored directly in the table (rawget works),
      -- __index trap catches any non-direct access to unexpected keys.
      local aura = setmetatable({ spellId = 57724, expirationTime = NOW + 200, icon = 132114 }, {
        __index = function(_, key)
          if key ~= "spellId" and key ~= "expirationTime" and key ~= "icon" then
            unexpectedKeyAccessed = true
          end
          return nil
        end,
      })
      local auras = { aura }
      WithGlobals({
        C_UnitAuras = BuildHarmfulAuraApi(function()
          return auras
        end),
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

  test("CdTracker skips invalid aura spellId keys and still detects later lust aura", function()
    local NOW = 1000
    local invalidSpellId = 0 / 0 -- NaN; plain table indexing would error in Lua
    WithGlobals({
      C_UnitAuras = BuildHarmfulAuraApi(function()
        return {
          MakeLustAura(NOW + 50, invalidSpellId, 123456),
          MakeLustAura(NOW + 200, 57723, 132114),
        }
      end),
    }, function()
      local ctrl = MakeController({
        getTime = function()
          return NOW
        end,
      })
      local ok, err = pcall(function()
        ctrl.Scan()
      end)
      Assert.True(ok, "Scan must not fail on invalid aura spellId values: " .. tostring(err))
      local info = ctrl.GetLustInfo()
      Assert.NotNil(info, "valid lust aura after invalid spellId must still be detected")
      Assert.Equal(info.remain, 200, "later valid lust aura must determine the reported remaining time")
      Assert.Equal(info.icon, 132114, "later valid lust aura must determine the reported icon")
    end)
  end)

  test("CdTracker ignores non-numeric aura spellId values and still detects later numeric lust aura", function()
    local NOW = 1000
    WithGlobals({
      C_UnitAuras = BuildHarmfulAuraApi(function()
        return {
          MakeLustAura(NOW + 50, "57723", 123456),
          MakeLustAura(NOW + 200, 57723, 132114),
        }
      end),
    }, function()
      local ctrl = MakeController({
        getTime = function()
          return NOW
        end,
      })
      local ok, err = pcall(function()
        ctrl.Scan()
      end)
      Assert.True(ok, "Scan must not fail on non-numeric aura spellId values: " .. tostring(err))
      local info = ctrl.GetLustInfo()
      Assert.NotNil(info, "later numeric lust aura must still be detected")
      Assert.Equal(info.remain, 200, "numeric lust aura must determine the reported remaining time")
      Assert.Equal(info.icon, 132114, "numeric lust aura must determine the reported icon")
    end)
  end)

  RegisterCdTrackerLustCallbackTests(test, Assert, WithGlobals)

  test("CdTracker Scan updates BRes and Lust state independently", function()
    local NOW = 500
    WithGlobals({
      C_Spell = {
        GetSpellCharges = function()
          return 2, 3, 0, 400, 200
        end,
      },
      C_UnitAuras = BuildHarmfulAuraApi(function()
        return {}
      end),
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
