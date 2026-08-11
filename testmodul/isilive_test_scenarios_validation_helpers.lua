---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Validators.RequireFunction passes for function values", function()
    local addon = LoadAddonModules({ "isiLive_validation_helpers.lua" })
    local fn = function() end
    local result = addon.Validators.RequireFunction(fn, "testFn", "TestModule")
    Assert.Equal(result, fn, "RequireFunction must return the function it received")
  end)

  test("Validators.RequireFunction fails for non-function values", function()
    local addon = LoadAddonModules({ "isiLive_validation_helpers.lua" })
    local ok, err = pcall(addon.Validators.RequireFunction, "not a function", "badValue", "TestModule")
    Assert.True(not ok, "RequireFunction must fail for non-function")
    Assert.True(type(err) == "string" and err:find("TestModule") ~= nil, "error message must include module name")
    Assert.True(type(err) == "string" and err:find("badValue") ~= nil, "error message must include dependency name")
  end)

  test("Validators.RequireFunction uses default module name when omitted", function()
    local addon = LoadAddonModules({ "isiLive_validation_helpers.lua" })
    local ok, err = pcall(addon.Validators.RequireFunction, nil, "missingFn")
    Assert.True(not ok, "RequireFunction must fail for nil")
    Assert.True(type(err) == "string" and err:find("module") ~= nil, "error message must include default module name")
  end)

  test("Validators.RequireTable passes for table values", function()
    local addon = LoadAddonModules({ "isiLive_validation_helpers.lua" })
    local tbl = { x = 1 }
    local result = addon.Validators.RequireTable(tbl, "testTable", "TestModule")
    Assert.Equal(result, tbl, "RequireTable must return the table it received")
  end)

  test("Validators.RequireTable fails for non-table values", function()
    local addon = LoadAddonModules({ "isiLive_validation_helpers.lua" })
    local ok, err = pcall(addon.Validators.RequireTable, "not a table", "badTable", "TestModule")
    Assert.True(not ok, "RequireTable must fail for non-table")
    Assert.True(type(err) == "string" and err:find("TestModule") ~= nil, "error message must include module name")
  end)

  test("Validators.IsExistingUnit returns false for nil and empty string", function()
    local addon = LoadAddonModules({ "isiLive_validation_helpers.lua" })
    Assert.Equal(addon.Validators.IsExistingUnit(nil), false, "nil must return false")
    Assert.Equal(addon.Validators.IsExistingUnit(""), false, "empty string must return false")
    Assert.Equal(addon.Validators.IsExistingUnit(123), false, "number must return false")
  end)

  test("Validators.IsExistingUnit returns false when UnitExists is missing", function()
    WithGlobals({
      UnitExists = nil,
    }, function()
      local addon = LoadAddonModules({ "isiLive_validation_helpers.lua" })
      Assert.Equal(addon.Validators.IsExistingUnit("player"), false, "must return false when UnitExists is absent")
    end)
  end)

  test("Validators.IsExistingUnit delegates to UnitExists safely", function()
    WithGlobals({
      UnitExists = function(unit)
        return unit == "player"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_validation_helpers.lua" })
      Assert.Equal(addon.Validators.IsExistingUnit("player"), true, "existing unit must return true")
      Assert.Equal(addon.Validators.IsExistingUnit("party1"), false, "non-existing unit must return false")
    end)
  end)

  test("Validators.IsExistingUnit catches UnitExists errors via pcall", function()
    WithGlobals({
      UnitExists = function()
        error("simulated WoW API error")
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_validation_helpers.lua" })
      Assert.Equal(addon.Validators.IsExistingUnit("player"), false, "must return false on API error")
    end)
  end)

  test("Validators.IsExistingUnit rejects secret existence values", function()
    local secret = {}
    WithGlobals({
      UnitExists = function()
        return secret
      end,
      issecretvalue = function(value)
        return value == secret
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_validation_helpers.lua" })
      Assert.Equal(addon.Validators.IsExistingUnit("player"), false, "secret UnitExists result must fail closed")
      Assert.True(addon.Validators.IsSecretValue(secret), "shared secret-value detector must expose protected values")
    end)
  end)

  test("Validators.GetInstanceInfoSafe preserves clean instance metadata", function()
    WithGlobals({
      GetInstanceInfo = function()
        return "Test Dungeon", "party", 23, "Mythic", 5, nil, nil, 777, 12345
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_validation_helpers.lua" })
      local ok, info = addon.Validators.GetInstanceInfoSafe()
      Assert.True(ok, "clean instance metadata must be accepted")
      Assert.Equal(info.instanceName, "Test Dungeon", "instance name must be preserved")
      Assert.Equal(info.instanceType, "party", "instance type must be preserved")
      Assert.Equal(info.difficultyID, 23, "difficulty ID must be preserved")
      Assert.Equal(info.difficultyName, "Mythic", "difficulty name must be preserved")
      Assert.Equal(info.maxPlayers, 5, "max players must be preserved")
      Assert.Equal(info.instanceMapID, 777, "instance map ID must be preserved")
      Assert.Equal(info.instanceID, 12345, "instance ID must be preserved")
    end)
  end)

  test("Validators.GetInstanceInfoSafe rejects missing, failing, or secret instance metadata", function()
    WithGlobals({ GetInstanceInfo = nil }, function()
      local addon = LoadAddonModules({ "isiLive_validation_helpers.lua" })
      Assert.False(addon.Validators.GetInstanceInfoSafe(), "missing instance API must fail closed")
    end)

    WithGlobals({
      GetInstanceInfo = function()
        error("simulated WoW API error")
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_validation_helpers.lua" })
      Assert.False(addon.Validators.GetInstanceInfoSafe(), "instance API errors must fail closed")
    end)

    local secret = {}
    WithGlobals({
      GetInstanceInfo = function()
        return "Test Dungeon", "party", 23, "Mythic", 5, nil, nil, secret, 12345
      end,
      issecretvalue = function(value)
        return value == secret
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_validation_helpers.lua" })
      Assert.False(addon.Validators.GetInstanceInfoSafe(), "secret instance metadata must fail closed")
    end)
  end)
end
