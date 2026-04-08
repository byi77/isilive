---@diagnostic disable: undefined-global
local loaderChunk, loaderErr = loadfile("testmodul/isilive_test_loader.lua")
if not loaderChunk then
  error(string.format("cannot load test loader: %s", tostring(loaderErr)))
end

local Loader = loaderChunk()
local Assert = Loader.LoadModule("testmodul/isilive_test_assert.lua")
local Harness = Loader.LoadModule("testmodul/isilive_test_harness.lua")
local Fixtures = Loader.LoadModule("testmodul/isilive_test_fixtures.lua")
local RulesLogicValidator = Loader.LoadModule("tools/rules_logic_validator.lua")
local ArchitectureRulesValidator = Loader.LoadModule("tools/rules_logic_validator.lua")
local scenarioFiles = Loader.LoadModule("tools/usecase_scenarios.lua")

local runner = Harness.NewRunner()
local currentBeforeEach = nil
local test = {}
setmetatable(test, {
  __call = function(_, name, fn)
    runner.Test(name, fn)
  end,
})

function test.describe(_name, fn)
  local parentBeforeEach = currentBeforeEach
  fn()
  currentBeforeEach = parentBeforeEach
end

function test.before_each(fn)
  currentBeforeEach = fn
end

function test.it(name, fn)
  local setup = currentBeforeEach
  runner.Test(name, function()
    if setup then
      setup()
    end
    fn()
  end)
end

if type(RulesLogicValidator) ~= "table" or type(RulesLogicValidator.Run) ~= "function" then
  error("rules logic validator module must return table with Run(opts)")
end
if type(scenarioFiles) ~= "table" then
  error("scenario manifest must return table")
end

local rulesOk = RulesLogicValidator.Run({
  rulesPath = "docs/RULES_LOGIC.md",
  scenarioFiles = scenarioFiles,
  printFn = print,
})
if not rulesOk then
  os.exit(1)
end

local architectureRulesOk = ArchitectureRulesValidator.Run({
  rulesPath = "docs/ARCHITECTURE_RULES.md",
  scenarioFiles = scenarioFiles,
  printFn = print,
})
if not architectureRulesOk then
  os.exit(1)
end

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

local _, failed = runner.Run()
if failed > 0 then
  os.exit(1)
end

os.exit(0)
