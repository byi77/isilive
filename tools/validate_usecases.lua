local loaderChunk, loaderErr = loadfile("testmodul/isilive_test_loader.lua")
if not loaderChunk then
  error(string.format("cannot load test loader: %s", tostring(loaderErr)))
end

local Loader = loaderChunk()
local Assert = Loader.LoadModule("testmodul/isilive_test_assert.lua")
local Harness = Loader.LoadModule("testmodul/isilive_test_harness.lua")
local Fixtures = Loader.LoadModule("testmodul/isilive_test_fixtures.lua")

local runner = Harness.NewRunner()
local function test(name, fn)
  runner.Test(name, fn)
end

local scenarioFiles = {
  "testmodul/isilive_test_scenarios_queue.lua",
  "testmodul/isilive_test_scenarios_highlight.lua",
  "testmodul/isilive_test_scenarios_event_handlers.lua",
  "testmodul/isilive_test_scenarios_queue_flow.lua",
  "testmodul/isilive_test_scenarios_spell_utils.lua",
  "testmodul/isilive_test_scenarios_teleport.lua",
}

local context = {
  assert = Assert,
  with_globals = Harness.WithGlobals,
  load_modules = Harness.LoadAddonModules,
  fixtures = Fixtures,
}

for _, file in ipairs(scenarioFiles) do
  local register = Loader.LoadModule(file)
  if type(register) ~= "function" then
    error(string.format("scenario module must return register function: %s", file))
  end
  register(test, context)
end

print(string.format("Loaded %d usecase scenarios from %d modules", runner.GetCount(), #scenarioFiles))

local _passed, failed = runner.Run()
if failed > 0 then
  os.exit(1)
end

os.exit(0)
