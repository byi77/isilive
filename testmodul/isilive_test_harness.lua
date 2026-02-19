local Harness = {}
local Unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

local function Fail(message)
  error(message or "test harness error", 2)
end

function Harness.WithGlobals(stubs, fn)
  stubs = stubs or {}

  local previous = {}
  local existed = {}
  for key, value in pairs(stubs) do
    existed[key] = rawget(_G, key) ~= nil
    previous[key] = rawget(_G, key)
    _G[key] = value
  end

  local results = { pcall(fn) }

  for key in pairs(stubs) do
    if existed[key] then
      _G[key] = previous[key]
    else
      _G[key] = nil
    end
  end

  if not results[1] then
    error(results[2], 0)
  end

  table.remove(results, 1)
  if Unpack then
    return Unpack(results)
  end
  return nil
end

function Harness.LoadAddonModules(files, seedAddonTable)
  local addonTable = seedAddonTable or {}
  for _, file in ipairs(files) do
    local chunk, loadErr = loadfile(file)
    if not chunk then
      Fail(string.format("cannot load %s: %s", file, tostring(loadErr)))
    end

    local ok, runErr = pcall(chunk, "isiLive", addonTable)
    if not ok then
      Fail(string.format("cannot execute %s: %s", file, tostring(runErr)))
    end
  end
  return addonTable
end

function Harness.NewRunner()
  local tests = {}
  local runner = {}

  function runner.Test(name, fn)
    table.insert(tests, {
      name = name,
      fn = fn,
    })
  end

  function runner.GetCount()
    return #tests
  end

  function runner.Run()
    local passed = 0
    local failed = 0

    for _, item in ipairs(tests) do
      local ok, err = xpcall(item.fn, debug.traceback)
      if ok then
        passed = passed + 1
        print("[PASS] " .. item.name)
      else
        failed = failed + 1
        print("[FAIL] " .. item.name)
        print(err)
      end
    end

    print(string.format("Usecase validation complete: %d passed, %d failed", passed, failed))
    return passed, failed
  end

  return runner
end

return Harness
