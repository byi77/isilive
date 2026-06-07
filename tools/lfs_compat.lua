---@diagnostic disable: undefined-global

-- Minimal LuaFileSystem compatibility layer for local validation tools.
-- It intentionally implements only the subset used in tools/*.lua.

local io = io
local os = os
local package = package
local tostring = tostring

local isWindows = package.config:sub(1, 1) == "\\"

local function quotePath(path)
  path = tostring(path or "")
  if isWindows then
    return '"' .. path:gsub('"', '""') .. '"'
  end
  return "'" .. path:gsub("'", "'\\''") .. "'"
end

local function listEntries(path)
  local command
  if isWindows then
    command = "dir /b /a " .. quotePath(path) .. " 2>nul"
  else
    command = "find " .. quotePath(path) .. " -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null"
  end

  local handle = io.popen(command, "r")
  if not handle then
    return nil
  end

  local entries = {}
  for entry in handle:lines() do
    entries[#entries + 1] = entry
  end
  local ok = handle:close()
  if ok == nil then
    return nil
  end
  return entries
end

local function dir(path)
  local entries = listEntries(path)
  if not entries then
    error("cannot open directory: " .. tostring(path), 2)
  end

  local index = 0
  return function()
    index = index + 1
    return entries[index]
  end
end

local function attributes(path, name)
  local file = io.open(path, "rb")
  local mode
  if file then
    file:close()
    mode = "file"
  elseif listEntries(path) then
    mode = "directory"
  else
    return nil
  end

  local attrs = {
    mode = mode,
    modification = 0,
  }
  if name then
    return attrs[name]
  end
  return attrs
end

local function currentdir()
  local command = isWindows and "cd" or "pwd"
  local handle = io.popen(command, "r")
  if not handle then
    return nil
  end
  local path = handle:read("*l")
  handle:close()
  return path
end

local function mkdir(path)
  local command
  if isWindows then
    command = "mkdir " .. quotePath(path) .. " 2>nul"
  else
    command = "mkdir -p " .. quotePath(path) .. " 2>/dev/null"
  end
  local ok = os.execute(command)
  if ok == true or ok == 0 then
    return true
  end
  return nil, "mkdir failed"
end

return {
  _VERSION = "LuaFileSystem compat",
  attributes = attributes,
  currentdir = currentdir,
  dir = dir,
  mkdir = mkdir,
}
