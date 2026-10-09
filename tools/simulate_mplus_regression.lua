---@diagnostic disable: undefined-global
-- Shared production-wired R5 workload; exits nonzero for any budget failure.
local Harness = dofile("testmodul/isilive_test_harness.lua")
local Assert = dofile("testmodul/isilive_test_assert.lua")
local runner = Harness.NewRunner()
local scenario = dofile("testmodul/isilive_test_scenarios_mplus_regression.lua")
scenario(runner.Test, {
  assert = Assert,
  with_globals = Harness.WithGlobals,
  load_modules = Harness.LoadAddonModules,
})
local passed, failed = runner.Run()
print(string.format("R5 regression simulator: %s passed, %s failed", tostring(passed), tostring(failed)))
os.exit(failed == 0 and 0 or 1)
