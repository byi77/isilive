#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Patch watch, API surface (rule 262). Compares the Blizzard API surface
-- isiLive uses between the live client and a newer test client (PTR, beta),
-- using Blizzard's generated API documentation as mirrored by
-- github.com/Gethe/wow-ui-source (Interface/AddOns/Blizzard_APIDocumentationGenerated).
-- The PTR runs weeks ahead of a patch, so a removed function, event or enum
-- field and a changed signature show up here long before patch day.
--
-- Usage (from repo root):
--   lua tools/check_api_surface.lua --live=<docs dir> --target=<docs dir>
--     [--label=ptr] [--live-version=12.1.5] [--target-version=12.1.7]
--
-- What counts as "used": names found in the production files of isiLive.toc
-- (libs excluded) that the LIVE documentation knows: `C_X.Fn` (direct, via a
-- `rawget(_G, "C_X")` alias, or as "C_X", "Fn" string pairs), documented
-- global functions, event names as string literals, and `Enum.X.Y`. Names the
-- live documentation does not know (undocumented globals such as
-- GetAverageItemLevel) are listed separately and not compared.
--
-- A target that is not newer than live (stale beta branch) is skipped.
-- Exit codes: 0 no finding (or skipped), 1 removed or changed surface,
-- 2 input error. The documentation files are third-party data: they run in
-- an empty environment that only offers APIDocumentation:AddDocumentationTable.

local M = {}

local MAX_DOC_BYTES = 2 * 1024 * 1024

local function ReadFile(path)
  local file = io.open(path, "rb")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

local function ListLuaFiles(dir)
  local files = {}
  local isWindows = package.config:sub(1, 1) == "\\"
  local command = isWindows and ('dir /b "' .. dir:gsub("/", "\\") .. '\\*.lua" 2>nul')
    or ("ls -1 '" .. dir:gsub("'", "'\\''") .. "' 2>/dev/null")
  local pipe = io.popen(command)
  if not pipe then
    return files
  end
  for name in pipe:lines() do
    if name:match("%.lua$") then
      files[#files + 1] = dir .. "/" .. name
    end
  end
  pipe:close()
  table.sort(files)
  return files
end

-- Runs one documentation chunk in an empty environment; Lua 5.1 and 5.2+.
local function RunDocChunk(text, chunkName, env)
  if text:sub(1, 1) == "\27" then
    return false, "bytecode rejected"
  end
  local chunk, err
  local setfenvFn = rawget(_G, "setfenv")
  local loadstringFn = rawget(_G, "loadstring")
  if setfenvFn and loadstringFn then
    chunk, err = loadstringFn(text, chunkName)
    if chunk then
      setfenvFn(chunk, env)
    end
  else
    chunk, err = load(text, chunkName, "t", env)
  end
  if not chunk then
    return false, err
  end
  return pcall(chunk)
end

-- A table that returns another placeholder for every key (Enum.X.Y,
-- Constants.X.Y) and 0 when used as a number.
local function Placeholder()
  local placeholder
  local meta = {}
  meta.__index = function()
    return placeholder
  end
  for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__unm", "__mod", "__pow" }) do
    meta[op] = function()
      return 0
    end
  end
  meta.__tostring = function()
    return "0"
  end
  placeholder = setmetatable({}, meta)
  return placeholder
end

local function Signature(list)
  local parts = {}
  for _, field in ipairs(type(list) == "table" and list or {}) do
    parts[#parts + 1] =
      string.format("%s:%s%s", tostring(field.Name), tostring(field.Type), field.Nilable and "?" or "")
  end
  return table.concat(parts, ", ")
end

--- Loads every documentation table of `dir` into an index:
-- functions["C_X.Fn" or "Fn"] = { args, returns }, events[LITERAL] = payload,
-- enums["Name"] = { [field] = true }. Returns index or nil, error.
function M.LoadDocs(dir)
  local files = ListLuaFiles(dir)
  if #files == 0 then
    return nil, "no documentation files in " .. tostring(dir)
  end
  local index = { functions = {}, events = {}, enums = {}, files = #files }
  local collector = {}
  function collector.AddDocumentationTable(_self, documentation)
    if type(documentation) ~= "table" then
      return
    end
    local namespace = type(documentation.Namespace) == "string" and documentation.Namespace or nil
    for _, fn in ipairs(type(documentation.Functions) == "table" and documentation.Functions or {}) do
      if type(fn) == "table" and type(fn.Name) == "string" then
        local key = namespace and (namespace .. "." .. fn.Name) or fn.Name
        index.functions[key] = { args = Signature(fn.Arguments), returns = Signature(fn.Returns) }
      end
    end
    for _, event in ipairs(type(documentation.Events) == "table" and documentation.Events or {}) do
      if type(event) == "table" and type(event.LiteralName) == "string" then
        index.events[event.LiteralName] = Signature(event.Payload)
      end
    end
    for _, tbl in ipairs(type(documentation.Tables) == "table" and documentation.Tables or {}) do
      if type(tbl) == "table" and tbl.Type == "Enumeration" and type(tbl.Name) == "string" then
        local fields = {}
        for _, field in ipairs(type(tbl.Fields) == "table" and tbl.Fields or {}) do
          if type(field) == "table" and type(field.Name) == "string" then
            fields[field.Name] = true
          end
        end
        index.enums[tbl.Name] = fields
      end
    end
  end
  for _, path in ipairs(files) do
    local text = ReadFile(path)
    if text and #text <= MAX_DOC_BYTES then
      -- Some files read Enum.X.Y or Constants.X.Y for default and range
      -- values; a placeholder that answers every path lets them load.
      local env = { APIDocumentation = collector, Enum = Placeholder(), Constants = Placeholder() }
      local ok, err = RunDocChunk(text, "@" .. path, env)
      if not ok then
        io.stderr:write(string.format("[api_surface] skip %s: %s\n", path, tostring(err)))
      end
    end
  end
  return index
end

local function ProductionFiles(tocPath)
  local files = {}
  for line in (ReadFile(tocPath) or ""):gmatch("[^\r\n]+") do
    local path = line:match("^%s*([%w_/]+%.lua)%s*$")
    if path and not path:match("^libs/") then
      files[#files + 1] = path
    end
  end
  return files
end

--- Collects candidate names from source texts (list of strings).
-- Returns { namespaced = set, globals = set, literals = set, enums = set of "X" and "X.Y" }.
function M.CollectCandidates(texts)
  local found = { namespaced = {}, globals = {}, literals = {}, enums = {} }
  for _, text in ipairs(texts) do
    for ns, fn in text:gmatch("(C_%w+)[%.:](%u%w*)") do
      found.namespaced[ns .. "." .. fn] = true
    end
    for ns, fn in text:gmatch('"(C_%w+)",%s*"(%u%w*)"') do
      found.namespaced[ns .. "." .. fn] = true
    end
    local aliases = {}
    for var, ns in text:gmatch('([%a_][%w_]*)%s*=%s*rawget%(_G,%s*"(C_%w+)"%)') do
      aliases[var] = ns
    end
    for var, fn in text:gmatch('rawget%(([%a_][%w_]*),%s*"(%u%w*)"%)') do
      if aliases[var] then
        found.namespaced[aliases[var] .. "." .. fn] = true
      end
    end
    for var, fn in text:gmatch("([%a_][%w_]*)%.(%u%w*)") do
      if aliases[var] then
        found.namespaced[aliases[var] .. "." .. fn] = true
      end
    end
    for name in text:gmatch('rawget%(_G,%s*"(%u%w*)"%)') do
      found.globals[name] = true
    end
    for name in text:gmatch("[^%w_%.:](%u%w*)%s*%(") do
      found.globals[name] = true
    end
    for literal in text:gmatch('"(%u[%u%d_]+)"') do
      found.literals[literal] = true
    end
    for enumName, field in text:gmatch("Enum%.(%u%w*)%.(%u%w*)") do
      found.enums[enumName] = true
      found.enums[enumName .. "." .. field] = true
    end
    for enumName in text:gmatch("Enum%.(%u%w*)") do
      found.enums[enumName] = true
    end
  end
  return found
end

local function SortedKeys(set)
  local keys = {}
  for key in pairs(set) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

--- The used surface: candidates the live documentation knows.
function M.ResolveUsage(candidates, liveDocs)
  local used = { functions = {}, events = {}, enums = {}, enumFields = {}, undocumented = {} }
  for name in pairs(candidates.namespaced) do
    if liveDocs.functions[name] then
      used.functions[name] = true
    else
      used.undocumented[name] = true
    end
  end
  for name in pairs(candidates.globals) do
    if liveDocs.functions[name] then
      used.functions[name] = true
    end
  end
  for literal in pairs(candidates.literals) do
    if liveDocs.events[literal] then
      used.events[literal] = true
    end
  end
  for key in pairs(candidates.enums) do
    local enumName, field = key:match("^(%w+)%.(%w+)$")
    if enumName then
      if liveDocs.enums[enumName] and liveDocs.enums[enumName][field] then
        used.enumFields[key] = true
      end
    elseif liveDocs.enums[key] then
      used.enums[key] = true
    end
  end
  return used
end

--- Findings of `target` for the used surface: list of { kind, name, detail }.
function M.Compare(used, liveDocs, targetDocs)
  local findings = {}
  local function Add(kind, name, detail)
    findings[#findings + 1] = { kind = kind, name = name, detail = detail }
  end
  -- Fields appended at the end keep every position a caller reads: returns and
  -- payload values always, arguments only when the new ones may be omitted.
  local function Appended(before, after, onlyNilable)
    if after == before or before ~= "" and after:sub(1, #before + 2) ~= before .. ", " then
      return false
    end
    local tail = before == "" and after or after:sub(#before + 3)
    if not onlyNilable then
      return true
    end
    for field in (tail .. ", "):gmatch("(.-), ") do
      if field:sub(-1) ~= "?" then
        return false
      end
    end
    return true
  end
  local function Diff(name, what, before, after, onlyNilable)
    local kind = Appended(before, after, onlyNilable) and "extended" or "changed"
    Add(kind, name, string.format("%s `(%s)` -> `(%s)`", what, before, after))
  end
  for _, name in ipairs(SortedKeys(used.functions)) do
    local live, target = liveDocs.functions[name], targetDocs.functions[name]
    if not target then
      Add("removed", name, "function")
    elseif live.args ~= target.args then
      Diff(name, "arguments", live.args, target.args, true)
    elseif live.returns ~= target.returns then
      Diff(name, "returns", live.returns, target.returns, false)
    end
  end
  for _, name in ipairs(SortedKeys(used.events)) do
    local target = targetDocs.events[name]
    if target == nil then
      Add("removed", name, "event")
    elseif target ~= liveDocs.events[name] then
      Diff(name, "payload", liveDocs.events[name], target, false)
    end
  end
  for _, name in ipairs(SortedKeys(used.enums)) do
    if not targetDocs.enums[name] then
      Add("removed", "Enum." .. name, "enum")
    end
  end
  for _, key in ipairs(SortedKeys(used.enumFields)) do
    local enumName, field = key:match("^(%w+)%.(%w+)$")
    if not (targetDocs.enums[enumName] and targetDocs.enums[enumName][field]) then
      Add("removed", "Enum." .. key, "enum field")
    end
  end
  return findings
end

local function VersionKey(text)
  local major, minor, patch = tostring(text or ""):match("(%d+)%.(%d+)%.(%d+)")
  if not major then
    return nil
  end
  return tonumber(major) * 1000000 + tonumber(minor) * 1000 + tonumber(patch)
end

local function CountKeys(set)
  local count = 0
  for _ in pairs(set) do
    count = count + 1
  end
  return count
end

--- Full run. Returns code, markdown report.
function M.Run(opts)
  local label = opts.label or "target"
  local header = string.format("## API surface: live vs %s", label)
  local liveKey, targetKey = VersionKey(opts.liveVersion), VersionKey(opts.targetVersion)
  if liveKey and targetKey and targetKey <= liveKey then
    return 0,
      string.format(
        "%s\n\n- Status: skipped, %s (%s) is not newer than live (%s).",
        header,
        label,
        tostring(opts.targetVersion),
        tostring(opts.liveVersion)
      )
  end
  local liveDocs, liveErr = M.LoadDocs(opts.live)
  if not liveDocs then
    return 2, header .. "\n\n- Status: unresolved\n- Reason: " .. tostring(liveErr)
  end
  local targetDocs, targetErr = M.LoadDocs(opts.target)
  if not targetDocs then
    return 2, header .. "\n\n- Status: unresolved\n- Reason: " .. tostring(targetErr)
  end
  local texts = opts.texts
  if not texts then
    texts = {}
    for _, path in ipairs(ProductionFiles(opts.toc or "isiLive.toc")) do
      texts[#texts + 1] = ReadFile(path) or ""
    end
  end
  local used = M.ResolveUsage(M.CollectCandidates(texts), liveDocs)
  local findings = M.Compare(used, liveDocs, targetDocs)
  local acknowledged = opts.acknowledged
  if acknowledged == nil then
    local loader = loadfile(opts.ackPath or "tools/patch_watch_ack.lua")
    acknowledged = loader and loader() or {}
  end
  for _, finding in ipairs(findings) do
    local ack = type(acknowledged) == "table" and acknowledged[finding.name] or nil
    if type(ack) == "table" and ack.detail == finding.detail and finding.kind ~= "extended" then
      finding.kind = "acknowledged"
      finding.detail = finding.detail .. " (" .. tostring(ack.reason) .. ")"
    end
  end
  local lines = {
    header,
    "",
    string.format(
      "- Versions: live %s, %s %s",
      tostring(opts.liveVersion or "?"),
      label,
      tostring(opts.targetVersion or "?")
    ),
    string.format(
      "- Used and documented: %d functions, %d events, %d enums, %d enum fields",
      CountKeys(used.functions),
      CountKeys(used.events),
      CountKeys(used.enums),
      CountKeys(used.enumFields)
    ),
    string.format(
      "- Not in the live documentation (not compared): %s",
      #SortedKeys(used.undocumented) > 0 and table.concat(SortedKeys(used.undocumented), ", ") or "-"
    ),
    "",
  }
  if #findings == 0 then
    lines[#lines + 1] = "- Status: ok, nothing isiLive uses is removed or changed."
    return 0, table.concat(lines, "\n")
  end
  local breaking = 0
  for _, finding in ipairs(findings) do
    if finding.kind ~= "extended" and finding.kind ~= "acknowledged" then
      breaking = breaking + 1
    end
  end
  lines[#lines + 1] = breaking > 0
      and "- Status: check the changes below; `changed` and `removed` can break isiLive on patch day."
    or "- Status: ok, only compatible extensions or acknowledged changes (tools/patch_watch_ack.lua)."
  lines[#lines + 1] = ""
  lines[#lines + 1] = "| Change | Name | Detail |"
  lines[#lines + 1] = "| --- | --- | --- |"
  for _, finding in ipairs(findings) do
    lines[#lines + 1] = string.format("| %s | `%s` | %s |", finding.kind, finding.name, finding.detail)
  end
  return breaking > 0 and 1 or 0, table.concat(lines, "\n")
end

local function ParseArgs(argv)
  local args = {}
  for _, value in ipairs(argv or {}) do
    local key, val = value:match("^%-%-([%w_%-]+)=(.*)$")
    if key then
      args[key] = val
    end
  end
  return args
end

function M.Main(argv)
  local args = ParseArgs(argv)
  if not args.live or not args.target then
    io.stderr:write("usage: lua tools/check_api_surface.lua --live=<dir> --target=<dir> [--label=ptr]\n")
    return 2
  end
  local code, report = M.Run({
    live = args.live,
    target = args.target,
    label = args.label,
    liveVersion = args["live-version"],
    targetVersion = args["target-version"],
  })
  io.write(report, "\n")
  return code
end

if ... == "module" then
  return M
end

os.exit(M.Main(arg))
