---@diagnostic disable: undefined-global
local Loader = {}

function Loader.LoadModule(file)
  local chunk, loadErr = loadfile(file)
  if not chunk then
    error(string.format("cannot load %s: %s", file, tostring(loadErr)), 2)
  end

  local ok, result = pcall(chunk)
  if not ok then
    error(string.format("cannot execute %s: %s", file, tostring(result)), 2)
  end

  return result
end

return Loader
