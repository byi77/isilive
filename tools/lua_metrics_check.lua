-- Standalone CLI tool: uses standard Lua globals outside the WoW runtime.
---@diagnostic disable-next-line: undefined-global
local require = require
---@diagnostic disable-next-line: undefined-global
local io = io
---@diagnostic disable-next-line: undefined-global
local os = os

local ok_lfs, lfs = pcall(require, "lfs")
if not ok_lfs then
  io.stderr:write("metrics: missing dependency 'lfs' (LuaFileSystem)\n")
  os.exit(1)
end

local ok_decoder, decoder = pcall(require, "luacheck.decoder")
if not ok_decoder then
  io.stderr:write("metrics: missing dependency 'luacheck.decoder'\n")
  os.exit(1)
end

local ok_parser, parser = pcall(require, "luacheck.parser")
if not ok_parser then
  io.stderr:write("metrics: missing dependency 'luacheck.parser'\n")
  os.exit(1)
end

local function getenv_number(name, default_value)
  local raw = os.getenv(name)
  if not raw or raw == "" then
    return default_value
  end
  local parsed = tonumber(raw)
  if not parsed then
    return default_value
  end
  return parsed
end

local WARN_FILE_LINES = getenv_number("ISILIVE_WARN_FILE_LINES", 1200)
local MAX_FILE_LINES = getenv_number("ISILIVE_MAX_FILE_LINES", 3200)
local WARN_FUNCTION_LINES = getenv_number("ISILIVE_WARN_FUNCTION_LINES", 120)
local MAX_FUNCTION_LINES = getenv_number("ISILIVE_MAX_FUNCTION_LINES", 420)

if WARN_FILE_LINES > MAX_FILE_LINES then
  WARN_FILE_LINES = MAX_FILE_LINES
end
if WARN_FUNCTION_LINES > MAX_FUNCTION_LINES then
  WARN_FUNCTION_LINES = MAX_FUNCTION_LINES
end

local EXCLUDED_DIRS = {
  [".git"] = true,
  [".luarocks"] = true,
}

local function normalize_path(path)
  path = tostring(path or "")
  path = path:gsub("\\", "/")
  path = path:gsub("^%./", "")
  return path
end

local function read_file(path)
  local file, err = io.open(path, "rb")
  if not file then
    return nil, err
  end
  local contents = file:read("*a")
  file:close()
  return contents
end

local function count_lines(contents)
  if not contents or contents == "" then
    return 0
  end
  local _, newlines = contents:gsub("\n", "\n")
  if contents:sub(-1) == "\n" then
    return newlines
  end
  return newlines + 1
end

local function collect_lua_files(dir, out_files)
  for entry in lfs.dir(dir) do
    if entry ~= "." and entry ~= ".." then
      local full_path
      if dir == "." then
        full_path = entry
      else
        full_path = dir .. "/" .. entry
      end

      local attrs = lfs.attributes(full_path)
      if attrs and attrs.mode == "directory" then
        if not EXCLUDED_DIRS[entry] then
          collect_lua_files(full_path, out_files)
        end
      elseif attrs and attrs.mode == "file" and entry:match("%.lua$") then
        table.insert(out_files, normalize_path(full_path))
      end
    end
  end
end

local function line_for_offset(line_offsets, offset)
  if type(offset) ~= "number" then
    return nil
  end
  local left, right = 1, #line_offsets
  while left <= right do
    local mid = math.floor((left + right) / 2)
    local start_offset = line_offsets[mid]
    local next_offset = line_offsets[mid + 1]
    if start_offset <= offset and (not next_offset or next_offset > offset) then
      return mid
    end
    if start_offset > offset then
      right = mid - 1
    else
      left = mid + 1
    end
  end
  return nil
end

local function expression_name(node)
  if type(node) ~= "table" then
    return "<expr>"
  end
  if node.tag == "Id" then
    return tostring(node[1] or "<id>")
  end
  if node.tag == "Index" then
    local base = expression_name(node[1])
    local key = node[2]
    if type(key) == "table" then
      if key.tag == "String" or key.tag == "Id" then
        return base .. "." .. tostring(key[1] or "?")
      end
    end
    return base .. "[?]"
  end
  if node.tag == "Paren" then
    return expression_name(node[1])
  end
  return "<expr>"
end

local function register_named_functions(node, names_by_node)
  if type(node) ~= "table" then
    return
  end

  if node.tag == "Set" or node.tag == "Local" or node.tag == "Localrec" then
    local lhs = node[1]
    local rhs = node[2]
    if type(lhs) == "table" and type(rhs) == "table" then
      for i, value in ipairs(rhs) do
        if type(value) == "table" and value.tag == "Function" and lhs[i] ~= nil then
          names_by_node[value] = expression_name(lhs[i])
        end
      end
    end
  end

  for _, child in pairs(node) do
    if type(child) == "table" then
      register_named_functions(child, names_by_node)
    end
  end
end

local function collect_functions(node, file_path, line_offsets, names_by_node, out_functions)
  if type(node) ~= "table" then
    return
  end

  if node.tag == "Function" then
    local start_line = line_for_offset(line_offsets, node.offset) or node.line or 0
    local end_line = line_for_offset(line_offsets, node.end_offset) or start_line
    local length = end_line - start_line + 1
    if length < 0 then
      length = 0
    end
    table.insert(out_functions, {
      file = file_path,
      name = names_by_node[node] or "<anonymous>",
      start_line = start_line,
      end_line = end_line,
      lines = length,
    })
  end

  for _, child in pairs(node) do
    if type(child) == "table" then
      collect_functions(child, file_path, line_offsets, names_by_node, out_functions)
    end
  end
end

local function sort_desc_lines_then_path(a, b)
  if a.lines ~= b.lines then
    return a.lines > b.lines
  end
  if a.file ~= b.file then
    return a.file < b.file
  end
  return tostring(a.name or "") < tostring(b.name or "")
end

local files = {}
collect_lua_files(".", files)
table.sort(files)

if #files == 0 then
  print("metrics: no .lua files found")
  os.exit(1)
end

local file_metrics = {}
local function_metrics = {}
local parse_errors = {}

for _, file_path in ipairs(files) do
  local contents, read_err = read_file(file_path)
  if not contents then
    table.insert(parse_errors, string.format("%s: read error: %s", file_path, tostring(read_err)))
  else
    local ok_parse, ast_or_err, _, _, _, _, line_offsets = pcall(function()
      local source = decoder.decode(contents)
      return parser.parse(source, {}, {})
    end)

    table.insert(file_metrics, {
      file = file_path,
      lines = count_lines(contents),
    })

    if not ok_parse then
      table.insert(parse_errors, string.format("%s: parse error: %s", file_path, tostring(ast_or_err)))
    else
      local ast = ast_or_err
      local names_by_node = {}
      register_named_functions(ast, names_by_node)
      collect_functions(ast, file_path, line_offsets or {}, names_by_node, function_metrics)
    end
  end
end

table.sort(file_metrics, sort_desc_lines_then_path)
table.sort(function_metrics, sort_desc_lines_then_path)

local warn_files = {}
local hard_files = {}
local warn_functions = {}
local hard_functions = {}

for _, info in ipairs(file_metrics) do
  if info.lines > WARN_FILE_LINES then
    table.insert(warn_files, info)
  end
  if info.lines > MAX_FILE_LINES then
    table.insert(hard_files, info)
  end
end

for _, info in ipairs(function_metrics) do
  if info.lines > WARN_FUNCTION_LINES then
    table.insert(warn_functions, info)
  end
  if info.lines > MAX_FUNCTION_LINES then
    table.insert(hard_functions, info)
  end
end

print("Lua Metrics Check")
print(string.format("Files: %d | Functions: %d", #file_metrics, #function_metrics))
print(
  string.format(
    "Thresholds: file warn>%d hard>%d | function warn>%d hard>%d",
    WARN_FILE_LINES,
    MAX_FILE_LINES,
    WARN_FUNCTION_LINES,
    MAX_FUNCTION_LINES
  )
)
print("")

print("Top Files (by lines)")
for i = 1, math.min(10, #file_metrics) do
  local info = file_metrics[i]
  print(string.format("  %4d  %s", info.lines, info.file))
end
print("")

print("Top Functions (by lines)")
for i = 1, math.min(15, #function_metrics) do
  local info = function_metrics[i]
  print(string.format("  %4d  %s  (%s:%d)", info.lines, info.name, info.file, info.start_line))
end
print("")

if #parse_errors > 0 then
  print("Parse Errors")
  for _, err in ipairs(parse_errors) do
    print("  " .. err)
  end
  os.exit(1)
end

if #hard_files > 0 or #hard_functions > 0 then
  print("Hard Limit Violations")
  for _, info in ipairs(hard_files) do
    print(string.format("  file  %4d > %d  %s", info.lines, MAX_FILE_LINES, info.file))
  end
  for _, info in ipairs(hard_functions) do
    print(
      string.format(
        "  func  %4d > %d  %s  (%s:%d-%d)",
        info.lines,
        MAX_FUNCTION_LINES,
        info.name,
        info.file,
        info.start_line,
        info.end_line
      )
    )
  end
  os.exit(1)
end

if #warn_files > 0 or #warn_functions > 0 then
  print("Warnings")
  for _, info in ipairs(warn_files) do
    print(string.format("  file  %4d > %d  %s", info.lines, WARN_FILE_LINES, info.file))
  end
  for _, info in ipairs(warn_functions) do
    print(
      string.format(
        "  func  %4d > %d  %s  (%s:%d-%d)",
        info.lines,
        WARN_FUNCTION_LINES,
        info.name,
        info.file,
        info.start_line,
        info.end_line
      )
    )
  end
else
  print("No metric warnings.")
end

os.exit(0)
