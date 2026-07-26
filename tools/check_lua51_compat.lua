#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Scans the repository for Lua 5.2+/5.3+/5.4-only constructs.
--
-- Rationale: the WoW client AND the GitHub `Lua Check` workflow both run
-- Lua 5.1, while local tooling runs Lua 5.4. The local preflight therefore
-- cannot see 5.1 incompatibilities at all -- v0.9.354 shipped a red build
-- because `load("<source>", name)` compiles on 5.4 but needs `loadstring` on
-- 5.1, where load() takes a reader FUNCTION. The same defect class already
-- forced the `rawget(_G, "unpack") or rawget(table, "unpack")` bridging that
-- runs through two dozen files.
--
-- This gate is a static approximation, not an interpreter. It strips comments
-- and string literals first so that URLs ("https://"), WoW colour codes and
-- prose in comments cannot trip it.
--
-- Correct bridging patterns (all pass):
--   local unpack = rawget(_G, "unpack") or rawget(table, "unpack")
--   local Compile = rawget(_G, "loadstring") or load
--
-- Inline override: append `-- lua51-ok` to a line.
--
-- Exits 0 on clean, 1 on findings, 2 on IO/setup errors.
-- Run from repo root:
--   lua tools/check_lua51_compat.lua

local SCAN_DIRS = { "core", "logic", "game", "ui", "factory", "data", "locale", "testmodul", "tools" }

-- Each rule: pattern applied to the comment/string-stripped line, plus the
-- 5.1-safe replacement to name in the message.
local RULES = {
  {
    pattern = "[^%w_.:]load%s*%(%s*[\"'%[]",
    label = "load() with a source string",
    fix = 'use `rawget(_G, "loadstring") or load` -- on 5.1 load() takes a reader function',
  },
  { pattern = "table%.unpack", label = "table.unpack", fix = 'use `rawget(_G, "unpack") or rawget(table, "unpack")`' },
  { pattern = "table%.pack%s*%(", label = "table.pack", fix = "build the table manually with select('#', ...)" },
  { pattern = "table%.move%s*%(", label = "table.move", fix = "copy the range with an explicit loop" },
  { pattern = "math%.type%s*%(", label = "math.type", fix = "compare against math.floor(x) instead" },
  { pattern = "math%.tointeger%s*%(", label = "math.tointeger", fix = "use math.floor plus a range check" },
  { pattern = "math%.maxinteger", label = "math.maxinteger", fix = "use an explicit numeric bound" },
  { pattern = "math%.mininteger", label = "math.mininteger", fix = "use an explicit numeric bound" },
  { pattern = "rawlen%s*%(", label = "rawlen", fix = "use the # operator" },
  { pattern = "string%.pack%s*%(", label = "string.pack", fix = "not available on 5.1" },
  { pattern = "string%.unpack%s*%(", label = "string.unpack", fix = "not available on 5.1" },
  -- `root` marks rules whose library can legitimately be reached through a
  -- bridged local (`local utf8 = rawget(_G, "utf8")` plus a type guard). Those
  -- are the CORRECT 5.1 pattern, so they must not be flagged.
  { pattern = "[^%w_.]utf8%.", label = "utf8 library", fix = "not available on 5.1", root = "utf8" },
  { pattern = "coroutine%.close%s*%(", label = "coroutine.close", fix = "not available on 5.1" },
  { pattern = "[^%w_.:]warn%s*%(", label = "warn()", fix = "use the project logger" },
  { pattern = "::%s*[%a_][%w_]*%s*::", label = "goto label", fix = "restructure with if/else or a helper function" },
  { pattern = "[^%w_.]goto%s+[%a_]", label = "goto statement", fix = "restructure with if/else or a helper function" },
  { pattern = "//", label = "integer division //", fix = "use math.floor(a / b)" },
  { pattern = "<<", label = "bitwise shift <<", fix = "not available on 5.1" },
  { pattern = ">>", label = "bitwise shift >>", fix = "not available on 5.1" },
}

local ok_lfs, lfs = pcall(require, "lfs")
if not ok_lfs then
  lfs = require("tools.lfs_compat")
end

local function walkDir(dir, files)
  for entry in lfs.dir(dir) do
    if entry ~= "." and entry ~= ".." then
      local path = dir .. "/" .. entry
      local mode = lfs.attributes(path, "mode")
      if mode == "directory" then
        walkDir(path, files)
      elseif mode == "file" and path:match("%.lua$") then
        files[#files + 1] = path
      end
    end
  end
  return files
end

-- Replaces comment and string-literal spans with spaces, preserving column
-- positions. `state` carries an open long bracket ("]]", "]=]", ...) across
-- lines. Returns the stripped line and the new state.
local function stripCommentsAndStrings(line, state)
  local out = {}
  local index = 1
  local length = #line

  local function emitBlank(count)
    out[#out + 1] = string.rep(" ", count)
  end

  while index <= length do
    if state.longClose then
      local closeStart, closeEnd = line:find(state.longClose, index, true)
      if closeStart then
        emitBlank(closeEnd - index + 1)
        index = closeEnd + 1
        state.longClose = nil
      else
        emitBlank(length - index + 1)
        index = length + 1
      end
    else
      local char = line:sub(index, index)
      local longOpen, equals = line:match("^(%[(=*)%[)", index)
      local isComment = line:sub(index, index + 1) == "--"
      local commentLongOpen, commentEquals = line:match("^%-%-(%[(=*)%[)", index)

      if commentLongOpen then
        state.longClose = "]" .. string.rep("=", #commentEquals) .. "]"
        emitBlank(2 + #commentLongOpen)
        index = index + 2 + #commentLongOpen
      elseif isComment then
        emitBlank(length - index + 1)
        index = length + 1
      elseif longOpen then
        -- Keep the opening bracket visible: the load() rule needs to see THAT
        -- a literal was passed, only its contents must be hidden.
        state.longClose = "]" .. string.rep("=", #equals) .. "]"
        out[#out + 1] = "["
        emitBlank(#longOpen - 1)
        index = index + #longOpen
      elseif char == '"' or char == "'" then
        local quote = char
        local cursor = index + 1
        while cursor <= length do
          local current = line:sub(cursor, cursor)
          if current == "\\" then
            cursor = cursor + 2
          elseif current == quote then
            cursor = cursor + 1
            break
          else
            cursor = cursor + 1
          end
        end
        -- Preserve the quotes, blank the contents. Rules that care about
        -- string CONTENT (integer division inside "a // b") stay silent, while
        -- rules that care about the ARGUMENT SHAPE -- load("source") -- can
        -- still tell a literal from an expression.
        local span = math.min(cursor, length + 1) - index
        out[#out + 1] = quote
        if span >= 2 then
          emitBlank(span - 2)
          out[#out + 1] = quote
        end
        index = cursor
      else
        out[#out + 1] = char
        index = index + 1
      end
    end
  end

  return table.concat(out), state
end

local function lineHasOverride(line)
  return line:match("%-%-%s*lua51[%s%-:]+ok") ~= nil
end

local function main()
  local issues = {}
  local files = {}
  for _, dir in ipairs(SCAN_DIRS) do
    if lfs.attributes(dir, "mode") == "directory" then
      walkDir(dir, files)
    end
  end
  table.sort(files)

  for _, path in ipairs(files) do
    local handle = io.open(path, "r")
    if not handle then
      io.stderr:write(string.format("lua51-compat: cannot read %s\n", path))
      os.exit(2)
    end
    local sourceLines = {}
    for rawLine in handle:lines() do
      sourceLines[#sourceLines + 1] = rawLine
    end
    handle:close()

    -- Pass 1: collect locals bound via rawget, e.g.
    --   local utf8 = rawget(_G, "utf8")
    -- Reaching a newer library through such a guarded local IS the 5.1-safe
    -- pattern, so rules carrying a matching `root` are suppressed for the file.
    local bridgedLocals = {}
    for _, rawLine in ipairs(sourceLines) do
      local name = rawLine:match("^%s*local%s+([%a_][%w_]*)%s*=%s*rawget%s*%(")
      if name then
        bridgedLocals[name] = true
      end
    end

    -- Pass 2: scan the comment/string-stripped source.
    local state = {}
    for lineno, rawLine in ipairs(sourceLines) do
      local stripped
      stripped, state = stripCommentsAndStrings(rawLine, state)
      if not lineHasOverride(rawLine) then
        for _, rule in ipairs(RULES) do
          local suppressed = rule.root ~= nil and bridgedLocals[rule.root] == true
          if not suppressed and stripped:find(rule.pattern) then
            issues[#issues + 1] = string.format("%s:%d: %s is Lua 5.2+ only -- %s", path, lineno, rule.label, rule.fix)
          end
        end
      end
    end
  end

  if #issues == 0 then
    io.write("lua51-compat: clean — no Lua 5.2+ only constructs outside bridged accessors\n")
    os.exit(0)
  end

  io.write(string.format("lua51-compat: %d issue(s) found\n\n", #issues))
  for _, issue in ipairs(issues) do
    io.write("  " .. issue .. "\n")
  end
  os.exit(1)
end

main()
