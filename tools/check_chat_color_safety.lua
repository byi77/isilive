#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Pins CLAUDE.md rule: WoW's chat server silently drops addon SendChatMessage
-- calls that contain "|cffXXXXXX[...]|r" (color codes wrapping square
-- brackets) unless embedded in a real "|H...|h" hyperlink. The server filters
-- the payload as a fake item link. pcall reports success, sender + receiver
-- see nothing — extremely hard to debug after the fact.
--
-- Strategy:
-- 1. Identify production files that fan out into SendChatMessage / its
--    C_ChatInfo wrapper / the ContextHelpers.SendPartyChatMessage helper.
-- 2. In those files, scan every line for a string literal that contains the
--    forbidden pattern: a |c<hex> color-code prefix immediately followed by
--    "[" anywhere in the literal, OR "]" immediately followed by |r — when
--    that literal does NOT also contain a "|H" hyperlink prefix.
-- 3. Also scan string.format templates that would compose such a literal at
--    runtime (e.g. "|cff00ff00[%s]|r").
--
-- Inline override: append `-- chat-color-ok` to a line to silence the gate.
-- Use only for genuinely non-chat usages (Print / AddMessage / tooltip text)
-- where the server filter does not apply.
--
-- Exits 0 on clean, 1 on violations, 2 on IO/setup errors.
-- Run from repo root:
--   lua tools/check_chat_color_safety.lua

local SCAN_DIRS = { "core", "factory", "game", "logic", "ui" }

-- Production sinks that fan out into the WoW chat server. A file is only
-- considered "chat-relevant" if it references one of these tokens.
local CHAT_SINKS = {
  "SendChatMessage",
  "SendPartyChatMessage",
  "SendChatMessageCompat",
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

local function readFile(path)
  local fh = io.open(path, "r")
  if not fh then
    return nil
  end
  local content = fh:read("*a")
  fh:close()
  return content
end

local function readLines(path)
  local lines = {}
  local fh = io.open(path, "r")
  if not fh then
    return nil
  end
  for line in fh:lines() do
    lines[#lines + 1] = line
  end
  fh:close()
  return lines
end

local function fileFansIntoChat(content)
  for _, sink in ipairs(CHAT_SINKS) do
    if content:find(sink, 1, true) then
      return true
    end
  end
  return false
end

local function literalIsHyperlinkSafe(literal)
  -- A "|H...|h<text>|h" hyperlink is safe even if it contains color codes
  -- around brackets — the server preserves the wrapper. We treat any literal
  -- that contains "|H" as opted-out of this gate.
  return literal:find("|H", 1, true) ~= nil
end

local function literalHasUnsafePattern(literal)
  -- Pattern A: a color-code prefix |c<hex>* followed (anywhere) by an
  -- opening square bracket [. Captures both `"|cff00ff00[Lust]|r"` and
  -- `"|cffff0000[%s]|r"` style format strings.
  if literal:find("|c%x[^%[%]]*%[") then
    return "color-code precedes open bracket"
  end
  -- Pattern B: a closing square bracket directly followed (anywhere) by |r.
  -- Catches strings that compose only the closing half via concatenation —
  -- still a server-filter trigger when joined back together.
  if literal:find("%][^%[%]]*|r") then
    return "close bracket precedes color-reset"
  end
  return nil
end

local function extractStringLiterals(line)
  -- Returns list of double-quoted string contents in line. Mirrors the
  -- approach in check_hardcoded_strings.lua. Single-quoted literals are
  -- rare in this codebase; the Lua style guide prefers double quotes and
  -- StyLua enforces it.
  local literals = {}
  for content in line:gmatch('"([^"]*)"') do
    literals[#literals + 1] = content
  end
  return literals
end

local function lineHasChatColorOk(line)
  return line:match("%-%-%s*chat%-color%-ok") ~= nil or line:match("%-%-%s*chat:color%-ok") ~= nil
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
    local content = readFile(path)
    if not content then
      io.stderr:write(string.format("chat-color-safety: cannot read %s\n", path))
      os.exit(2)
    end
    if fileFansIntoChat(content) then
      local lines = readLines(path)
      for lineno, raw in ipairs(lines or {}) do
        if not lineHasChatColorOk(raw) then
          for _, lit in ipairs(extractStringLiterals(raw)) do
            if not literalIsHyperlinkSafe(lit) then
              local reason = literalHasUnsafePattern(lit)
              if reason then
                issues[#issues + 1] = string.format(
                  '%s:%d: chat literal "%s" — %s. Server silently drops "|c..[..]|r" '
                    .. "in addon-sent chat unless wrapped in a real |H...|h hyperlink.",
                  path,
                  lineno,
                  lit,
                  reason
                )
              end
            end
          end
        end
      end
    end
  end

  if #issues == 0 then
    io.write("chat-color-safety: clean — no |cff...[...]|r-without-hyperlink in chat-fan-out files\n")
    os.exit(0)
  end

  io.write(string.format("chat-color-safety: %d violation(s) found\n\n", #issues))
  for _, line in ipairs(issues) do
    io.write("  " .. line .. "\n")
  end
  os.exit(1)
end

main()
