---@diagnostic disable: undefined-global
local validatorChunk, validatorErr = loadfile("tools/rules_logic_validator.lua")
if not validatorChunk then
  error(string.format("cannot load architecture rules validator: %s", tostring(validatorErr)))
end

local scenarioChunk, scenarioErr = loadfile("tools/usecase_scenarios.lua")
if not scenarioChunk then
  error(string.format("cannot load scenario manifest: %s", tostring(scenarioErr)))
end

local RulesLogicValidator = validatorChunk()
if type(RulesLogicValidator) ~= "table" or type(RulesLogicValidator.Run) ~= "function" then
  error("architecture rules validator must return table with Run(opts)")
end

local scenarioFiles = scenarioChunk()
if type(scenarioFiles) ~= "table" then
  error("scenario manifest must return table")
end

local ok = RulesLogicValidator.Run({
  rulesPath = "docs/ARCHITECTURE_RULES.md",
  scenarioFiles = scenarioFiles,
  printFn = print,
})

if not ok then
  os.exit(1)
end

os.exit(0)
