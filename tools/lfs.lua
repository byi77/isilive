---@diagnostic disable: undefined-global,different-requires

local ok, compat = pcall(require, "tools.lfs_compat")
if ok then
  return compat
end

return require("lfs_compat")
