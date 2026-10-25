-- Lua 5.1 / 5.4 bridges for wowsim.
--
-- wowsim must run on the Lua 5.1 the CI uses (tools/check_lua51_compat.lua)
-- as well as on the Lua 5.4 of the local tooling. This module hides the
-- differences: unpack, loading a chunk into a private environment, xpcall
-- with arguments, UTF-8 helpers and the `bit` library. On 5.3+ it can also
-- make the addon's view of numbers behave like WoW's Lua 5.1 (no "5.0"
-- from tostring, string.format("%d", 2.5) truncating instead of raising).

local Compat = {}

Compat.unpack = rawget(table, "unpack") or rawget(_G, "unpack")
local unpack = Compat.unpack
local setfenvFn = rawget(_G, "setfenv")

-- Loads a file as a chunk whose globals resolve in `env`.
function Compat.LoadFileWithEnv(path, env)
  if setfenvFn then
    local chunk, err = loadfile(path)
    if chunk then
      setfenvFn(chunk, env)
    end
    return chunk, err
  end
  return loadfile(path, "t", env)
end

-- xpcall with arguments and a traceback (5.1's xpcall forwards no arguments).
function Compat.XCall(fn, ...)
  local n = select("#", ...)
  local args = { ... }
  return xpcall(function()
    return fn(unpack(args, 1, n))
  end, debug.traceback)
end

function Compat.IsInteger(v)
  return type(v) == "number" and v == math.floor(v) and v > -2 ^ 53 and v < 2 ^ 53
end

-- Number of UTF-8 code points in `s` (continuation bytes are not counted).
function Compat.Utf8Len(s)
  local _, count = tostring(s or ""):gsub("[^\128-\191]", "")
  return count
end

-- Byte offset where code point `i` (1-based) starts, or nil past the end.
local function Utf8Offset(s, i)
  local index = 0
  for pos = 1, #s do
    local byte = s:byte(pos)
    if byte < 128 or byte >= 192 then
      index = index + 1
      if index == i then
        return pos
      end
    end
  end
  return nil
end

-- utf8sub semantics of the WoW helper: code point range [i, j], negative
-- indices count from the end.
function Compat.Utf8Sub(s, i, j)
  s = tostring(s or "")
  local len = Compat.Utf8Len(s)
  i = i or 1
  j = j or len
  if i < 0 then
    i = len + i + 1
  end
  if j < 0 then
    j = len + j + 1
  end
  if i < 1 then
    i = 1
  end
  if i > len or j < i then
    return ""
  end
  local startByte = Utf8Offset(s, i) or 1
  local endByte = (Utf8Offset(s, j + 1) or (#s + 1)) - 1
  return s:sub(startByte, endByte)
end

-- WoW's `bit` library on plain arithmetic (32-bit unsigned results).
local TWO32 = 4294967296
local function ToU32(v)
  v = math.floor(tonumber(v) or 0) % TWO32
  return v
end
local function BitOp(a, b, keep)
  a, b = ToU32(a), ToU32(b)
  local result, bitValue = 0, 1
  for _ = 1, 32 do
    local ra, rb = a % 2, b % 2
    if keep(ra, rb) then
      result = result + bitValue
    end
    a, b = (a - ra) / 2, (b - rb) / 2
    bitValue = bitValue * 2
  end
  return result
end
Compat.bit = {
  band = function(a, b, ...)
    local r = BitOp(a, b, function(x, y)
      return x == 1 and y == 1
    end)
    for i = 1, select("#", ...) do
      r = Compat.bit.band(r, (select(i, ...)))
    end
    return r
  end,
  bor = function(a, b, ...)
    local r = BitOp(a, b, function(x, y)
      return x == 1 or y == 1
    end)
    for i = 1, select("#", ...) do
      r = Compat.bit.bor(r, (select(i, ...)))
    end
    return r
  end,
  bxor = function(a, b)
    return BitOp(a, b, function(x, y)
      return x ~= y
    end)
  end,
  bnot = function(a)
    return TWO32 - 1 - ToU32(a)
  end,
  lshift = function(a, n)
    return ToU32(ToU32(a) * 2 ^ n)
  end,
  rshift = function(a, n)
    return math.floor(ToU32(a) / 2 ^ n)
  end,
  arshift = function(a, n)
    local v = ToU32(a)
    if v >= 2 ^ 31 then
      v = v - TWO32
    end
    return math.floor(v / 2 ^ n)
  end,
  mod = function(a, b)
    return a % b
  end,
}

-- On Lua 5.3+ make tostring / string.format inside `env` follow Lua 5.1:
-- integral floats print without ".0" and integer format specifiers truncate
-- floats. String concatenation of floats ("x" .. 10 / 2) cannot be hooked and
-- still yields "5.0" on 5.4.
function Compat.ApplyLua51NumberSemantics(env)
  local mathType = rawget(math, "type")
  if not mathType then
    return
  end
  local nativeToString = tostring
  local function ToString51(v)
    if type(v) == "number" and mathType(v) == "float" then
      if v ~= v then
        return "nan"
      elseif v == math.huge then
        return "inf"
      elseif v == -math.huge then
        return "-inf"
      end
      return string.format("%.14g", v)
    end
    return nativeToString(v)
  end
  local nativeFormat = string.format
  local function Format51(fmt, ...)
    local args = { ... }
    local n = select("#", ...)
    local argIndex = 0
    for spec in tostring(fmt):gmatch("%%[-+ #0]*%d*%.?%d*([%a%%])") do
      if spec ~= "%" then
        argIndex = argIndex + 1
        local v = args[argIndex]
        if type(v) == "number" and spec:match("[dicouxX]") and v == v and v ~= math.huge and v ~= -math.huge then
          args[argIndex] = v >= 0 and math.floor(v) or math.ceil(v)
        end
      end
    end
    return nativeFormat(fmt, unpack(args, 1, n))
  end
  env.tostring = ToString51
  env.string.format = Format51
  env.format = Format51
  env.strformat = Format51
end

return Compat
