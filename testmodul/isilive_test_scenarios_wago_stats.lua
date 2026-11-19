---@diagnostic disable: undefined-global

-- Wago Analytics usage statistics (rule 257, game/isiLive_wago_stats.lua).

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  -- WagoAnalytics library as the Wago App ships it: Register returns a
  -- handle with counters and switches.
  local function NewLibrary()
    local lib = { registered = {} }
    function lib:Register(wagoId, options)
      local handle = { counters = {}, switches = {}, options = options }
      function handle:IncrementCounter(name, increment)
        self.counters[name] = (self.counters[name] or 0) + (increment or 1)
      end
      function handle:Switch(name, value)
        self.switches[name] = value
      end
      self.registered[wagoId] = handle
      return handle
    end
    return lib
  end

  local function AddOns(wagoId)
    return {
      GetAddOnMetadata = function(_name, field)
        if field == "X-Wago-ID" then
          return wagoId
        end
        return nil
      end,
    }
  end

  local function WithWago(lib, wagoId, fn)
    WithGlobals({ WagoAnalytics = lib, C_AddOns = AddOns(wagoId) }, function()
      fn(LoadAddonModules({ "isiLive_wago_stats.lua" }).WagoStats)
    end)
  end

  test("WagoStats reports one session, the design and TTK under the TOC Wago ID", function()
    local lib = NewLibrary()
    WithWago(lib, "rN4r1zKD", function(WagoStats)
      Assert.Equal(WagoStats.Report({ uiDesign = "classic", ttkEnabled = false }), true, "reported")
      local handle = lib.registered.rN4r1zKD
      Assert.True(handle ~= nil, "registered with the X-Wago-ID")
      Assert.Equal(handle.options.reportErrors, false, "no Lua error reports")
      Assert.Equal(handle.counters.sessions, 1, "one session")
      Assert.Equal(handle.switches.design_classic, true, "classic design")
      Assert.Equal(handle.switches.design_modern, false, "not modern")
      Assert.Equal(handle.switches.ttk_enabled, false, "TTK off")
    end)
  end)

  test("WagoStats defaults to modern design and TTK on for a fresh database", function()
    local lib = NewLibrary()
    WithWago(lib, "rN4r1zKD", function(WagoStats)
      WagoStats.Report({})
      local handle = lib.registered.rN4r1zKD
      Assert.Equal(handle.switches.design_modern, true, "modern is the default")
      Assert.Equal(handle.switches.ttk_enabled, true, "TTK default on")
    end)
  end)

  test("WagoStats does nothing without the Wago addon or the Wago ID", function()
    WithWago(nil, "rN4r1zKD", function(WagoStats)
      Assert.Equal(WagoStats.Report({}), false, "no WagoAnalytics addon")
    end)
    local lib = NewLibrary()
    WithWago(lib, nil, function(WagoStats)
      Assert.Equal(WagoStats.Report({}), false, "no X-Wago-ID")
      Assert.Equal(next(lib.registered), nil, "nothing registered")
    end)
  end)
end
