#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Patch watch, TOC interface (rule 262). Reads the Blizzard product version
-- tables (`http://us.patch.battle.net:1119/<product>/versions`, saved as
-- <dir>/<product>.txt by .github/workflows/patch-watch.yml) and reports every
-- client build newer than live whose `## Interface` number is missing from
-- isiLive.toc. The TOC itself is never changed: the interface number is only
-- raised on an explicit user order; the weekly issue is the reminder.
--
-- Usage (from repo root):
--   lua tools/check_toc_interface.lua --versions=<dir> [--toc=isiLive.toc]
--
-- Exit codes: 0 every relevant interface is listed, 1 an interface is
-- missing, 2 input error (no live version, unreadable TOC).

local PRODUCTS = {
  { id = "wow", label = "Live" },
  { id = "wowt", label = "PTR" },
  { id = "wowxptr", label = "xPTR" },
  { id = "wow_beta", label = "Beta" },
}

local M = {}

local function ReadFile(path)
  local file = io.open(path, "rb")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

--- Parses one product version table. Prefers the `us` row, falls back to the
-- first data row. Returns { major, minor, patch, build, name } or nil.
function M.ParseVersions(text)
  if type(text) ~= "string" then
    return nil
  end
  local header, nameIndex, regionIndex
  local fallback
  for line in text:gmatch("[^\r\n]+") do
    if not line:match("^##") then
      local fields = {}
      for field in (line .. "|"):gmatch("([^|]*)|") do
        fields[#fields + 1] = field
      end
      if not header then
        header = fields
        for index, column in ipairs(fields) do
          local name = column:match("^([^!]+)")
          if name == "VersionsName" then
            nameIndex = index
          elseif name == "Region" then
            regionIndex = index
          end
        end
        if not nameIndex then
          return nil
        end
      else
        local versionName = fields[nameIndex]
        local major, minor, patch, build = tostring(versionName or ""):match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
        if major then
          local parsed = {
            major = tonumber(major),
            minor = tonumber(minor),
            patch = tonumber(patch),
            build = tonumber(build),
            name = versionName,
          }
          if regionIndex and fields[regionIndex] == "us" then
            return parsed
          end
          fallback = fallback or parsed
        end
      end
    end
  end
  return fallback
end

--- TOC interface number of a version: MAJOR, two-digit MINOR, two-digit PATCH.
function M.InterfaceOf(version)
  return version.major * 10000 + version.minor * 100 + version.patch
end

local function IsNewer(left, right)
  if left.major ~= right.major then
    return left.major > right.major
  end
  if left.minor ~= right.minor then
    return left.minor > right.minor
  end
  if left.patch ~= right.patch then
    return left.patch > right.patch
  end
  return left.build > right.build
end

--- Interface numbers of the TOC's `## Interface:` line.
function M.ParseTocInterfaces(text)
  local list = {}
  local line = type(text) == "string" and text:match("##%s*Interface:%s*([^\r\n]*)") or nil
  if not line then
    return nil
  end
  for value in line:gmatch("%d+") do
    list[tonumber(value)] = true
  end
  return list
end

--- versionsByProduct: { [productID] = parsed version or nil }.
-- Returns code, markdown report.
function M.Evaluate(versionsByProduct, tocInterfaces)
  local live = versionsByProduct.wow
  if type(live) ~= "table" then
    return 2, "## TOC Interface\n\n- Status: unresolved\n- Reason: no live (`wow`) version"
  end
  if type(tocInterfaces) ~= "table" then
    return 2, "## TOC Interface\n\n- Status: unresolved\n- Reason: `## Interface:` missing in isiLive.toc"
  end
  local lines = {
    "## TOC Interface",
    "",
    "| Product | Version | Interface | In TOC | Relevant |",
    "| --- | --- | --- | --- | --- |",
  }
  local missing = {}
  for _, product in ipairs(PRODUCTS) do
    local version = versionsByProduct[product.id]
    if type(version) == "table" then
      local interface = M.InterfaceOf(version)
      local relevant = product.id == "wow" or IsNewer(version, live)
      local listed = tocInterfaces[interface] == true
      lines[#lines + 1] = string.format(
        "| %s (`%s`) | %s | %d | %s | %s |",
        product.label,
        product.id,
        version.name,
        interface,
        listed and "yes" or "no",
        relevant and "yes" or "no (not newer than live)"
      )
      if relevant and not listed and not missing[interface] then
        missing[interface] = product.label
        missing[#missing + 1] = interface
      end
    else
      lines[#lines + 1] = string.format("| %s (`%s`) | unresolved | - | - | - |", product.label, product.id)
    end
  end
  lines[#lines + 1] = ""
  if #missing == 0 then
    lines[#lines + 1] = "- Status: ok, every interface of live and newer test clients is listed."
    return 0, table.concat(lines, "\n")
  end
  table.sort(missing)
  for _, interface in ipairs(missing) do
    lines[#lines + 1] = string.format(
      "- Missing: `%d` (%s). Add it to `## Interface:` in isiLive.toc on an explicit user order.",
      interface,
      missing[interface]
    )
  end
  return 1, table.concat(lines, "\n")
end

local function ParseArgs(argv)
  local args = { toc = "isiLive.toc" }
  for _, value in ipairs(argv or {}) do
    local key, val = value:match("^%-%-([%w_]+)=(.*)$")
    if key then
      args[key] = val
    end
  end
  return args
end

function M.Main(argv)
  local args = ParseArgs(argv)
  if type(args.versions) ~= "string" or args.versions == "" then
    io.stderr:write("usage: lua tools/check_toc_interface.lua --versions=<dir> [--toc=isiLive.toc]\n")
    return 2
  end
  local versions = {}
  for _, product in ipairs(PRODUCTS) do
    versions[product.id] = M.ParseVersions(ReadFile(args.versions .. "/" .. product.id .. ".txt"))
  end
  local code, report = M.Evaluate(versions, M.ParseTocInterfaces(ReadFile(args.toc)))
  io.write(report, "\n")
  return code
end

if ... == "module" then
  return M
end

os.exit(M.Main(arg))
