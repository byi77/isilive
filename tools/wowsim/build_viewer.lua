---@diagnostic disable: undefined-global
-- Host-side tool: runs in the local Lua, where io / package / loadfile exist.
-- .luarc.json disables those builtins for the WoW addon code.
-- tools/wowsim/build_viewer.lua
-- Builds a self-contained HTML viewer from a wowsim JSON dump.
--
-- CLI:  lua tools/wowsim/build_viewer.lua <input.json> <output.html>
-- Lib:  WOWSIM_BUILD_VIEWER_AS_LIB = true; local v = dofile("tools/wowsim/build_viewer.lua")
--       v.build(jsonText, outPath, addonRoot)  -- addonRoot optional
--
-- Lua 5.1 / 5.4 compatible (no goto, no //, no bitwise ops, no utf8).

local DATA_PLACEHOLDER = "/*__SIM_DATA__*/null"
local ASSETS_PLACEHOLDER = "/*__SIM_ASSETS__*/{}"
local ADDON_PREFIX = "interface/addons/isilive/"

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- Directory of this script (with trailing slash, "" if unknown).
local function scriptDir()
  local src = debug.getinfo(1, "S").source or ""
  if src:sub(1, 1) == "@" then
    src = src:sub(2)
  elseif arg and arg[0] then
    src = arg[0]
  end
  return src:match("^(.*[/\\])[^/\\]*$") or ""
end

local function readFile(path)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local s = f:read("*a")
  f:close()
  return s
end

-- Base64 encodes a binary string using arithmetic only (Lua 5.1 safe).
local function base64(s)
  local out, n = {}, 0
  local floor = math.floor
  local len = #s
  local i = 1
  while i <= len do
    local b1, b2, b3 = s:byte(i, i + 2)
    local v = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
    local c1 = floor(v / 262144)
    local c2 = floor(v / 4096) % 64
    local c3 = floor(v / 64) % 64
    local c4 = v % 64
    n = n + 1
    if b3 then
      out[n] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1) .. B64:sub(c3 + 1, c3 + 1) .. B64:sub(c4 + 1, c4 + 1)
    elseif b2 then
      out[n] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1) .. B64:sub(c3 + 1, c3 + 1) .. "="
    else
      out[n] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1) .. "=="
    end
    i = i + 3
  end
  return table.concat(out)
end

-- Undo JSON backslash escaping for the characters that matter in paths.
local function jsonUnescape(s)
  s = s:gsub("\\\\", "\0")
  s = s:gsub("\\/", "/")
  s = s:gsub("\\u(%x%x%x%x)", function(h)
    local c = tonumber(h, 16)
    return c < 128 and string.char(c) or "?"
  end)
  return (s:gsub("%z", "\\"))
end

local function jsonEscape(s)
  return (s:gsub('[\\"]', "\\%0"))
end

-- WoW path -> normalized key (lowercase, forward slashes).
local function normalize(path)
  return (path:gsub("\\", "/"):lower())
end

-- Collects distinct texture paths from the raw JSON text (no JSON parser).
local function collectPaths(jsonText)
  local seen, list = {}, {}
  local function add(raw)
    local p = jsonUnescape(raw)
    if p ~= "" and not seen[p] then
      seen[p] = true
      list[#list + 1] = p
    end
  end
  for raw in jsonText:gmatch('"path"%s*:%s*"(.-[^\\])"') do
    add(raw)
  end
  -- Inline textures inside text strings: |TInterface\\...:14|t
  for raw in jsonText:gmatch('|T([^:|"]+)') do
    add(raw)
  end
  return list
end

-- Finds a decodable local file for a WoW path. Returns bytes, type or nil.
local function resolveAsset(path, addonRoot)
  local norm = normalize(path)
  local rel = norm
  if rel:sub(1, #ADDON_PREFIX) == ADDON_PREFIX then
    rel = rel:sub(#ADDON_PREFIX + 1)
  else
    return nil -- not an addon-local file
  end
  local base = rel:gsub("%.%a+$", "")
  local cands = { rel, base .. ".tga", base .. ".png" }
  local tried = {}
  for _, c in ipairs(cands) do
    if not tried[c] and (c:match("%.tga$") or c:match("%.png$")) then
      tried[c] = true
      local data = readFile(addonRoot .. c)
      if data then
        return data, c:match("%.png$") and "png" or "tga"
      end
    end
  end
  return nil
end

-- Builds the JSON object literal for the assets map.
local function buildAssets(jsonText, addonRoot)
  local parts, count = {}, 0
  local done = {}
  for _, p in ipairs(collectPaths(jsonText)) do
    local key = normalize(p)
    if not done[key] then
      done[key] = true
      local data, kind = resolveAsset(p, addonRoot)
      if data then
        count = count + 1
        parts[count] = '"' .. jsonEscape(key) .. '":{"type":"' .. kind .. '","b64":"' .. base64(data) .. '"}'
      end
    end
  end
  return "{" .. table.concat(parts, ",") .. "}", count
end

-- Replaces the first plain occurrence of `needle` in `s` with `repl`.
local function splice(s, needle, repl)
  local a, b = s:find(needle, 1, true)
  if not a then
    return nil
  end
  return s:sub(1, a - 1) .. repl .. s:sub(b + 1)
end

local function build(jsonText, outPath, addonRoot)
  local dir = scriptDir()
  addonRoot = addonRoot or (dir .. "../../")
  if addonRoot ~= "" and not addonRoot:match("[/\\]$") then
    addonRoot = addonRoot .. "/"
  end
  local template = readFile(dir .. "viewer_template.html")
  if not template then
    return nil, "cannot read template: " .. dir .. "viewer_template.html"
  end
  local assetsJson, count = buildAssets(jsonText, addonRoot)
  -- Keep "</script" from terminating the inline script block.
  local safeJson = jsonText:gsub("</", "<\\/")
  local html = splice(template, ASSETS_PLACEHOLDER, assetsJson)
  html = html and splice(html, DATA_PLACEHOLDER, safeJson)
  if not html then
    return nil, "template placeholders missing"
  end
  local f, err = io.open(outPath, "wb")
  if not f then
    return nil, "cannot write " .. tostring(outPath) .. ": " .. tostring(err)
  end
  f:write(html)
  f:close()
  return true, count
end

-- luacheck: globals WOWSIM_BUILD_VIEWER_AS_LIB
if WOWSIM_BUILD_VIEWER_AS_LIB then
  return { build = build }
end

local input, output = arg and arg[1], arg and arg[2]
if not input or not output then
  io.stderr:write("usage: lua tools/wowsim/build_viewer.lua <input.json> <output.html>\n")
  os.exit(2)
end
local text = readFile(input)
if not text then
  io.stderr:write("cannot read " .. input .. "\n")
  os.exit(1)
end
local ok, res = build(text, output)
if not ok then
  io.stderr:write("build failed: " .. tostring(res) .. "\n")
  os.exit(1)
end
print(("wrote %s (%d embedded assets)"):format(output, res))
