-- wowsim: headless simulator for isiLive.
--
-- Loads the real addon (every file of isiLive.toc, in TOC order) into one or
-- more simulated WoW clients, drives them through a scripted scenario
-- (tools/wowsim/scenarios/*.lua) on a simulated clock, and records after
-- every scenario step:
--   * a snapshot of the visible UI with absolute screen rectangles,
--   * the log of events, chat lines, addon messages, sounds, prints, errors.
-- The result is written as JSON and rendered into a self-contained HTML
-- viewer (tools/wowsim/viewer_template.html) with a timeline.
--
-- Each simulated client runs its own copy of the addon in a private global
-- environment, so isiLive peers exchange real addon-message bytes.
--
-- Usage (from the addon root):
--   lua tools/wowsim/wowsim.lua <scenario> [options]
--     <scenario>          name in tools/wowsim/scenarios/ or a path to a .lua file
--     --out <dir>         output directory (default tools/wowsim/out)
--     --locale <tag>      client locale for the focus client (default from scenario / enUS)
--     --screen <WxH>      UI size in UI units (default 1920x1080)
--     --savedvars <path>  load IsiLiveDB from a WTF SavedVariables file ("auto" = first found)
--     --quiet             do not echo the log to stdout
--     --list              list the available scenarios
-- Exit code is non-zero when a scenario expectation failed or a Lua error was
-- raised inside the addon.

local SCRIPT_DIR = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local ADDON_ROOT = SCRIPT_DIR .. "/../.."

package.path = SCRIPT_DIR .. "/?.lua;" .. package.path
local World = require("world")
local Widgets = require("widgets")
local Api = require("api")

local Compat = require("compat")
local unpack = Compat.unpack

-------------------------------------------------------------------------------
-- Small helpers
-------------------------------------------------------------------------------
local function ReadFile(path)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local data = f:read("*a")
  f:close()
  return data
end

local function WriteFile(path, data)
  local f = assert(io.open(path, "wb"))
  f:write(data)
  f:close()
end

local function EnsureDir(path)
  local winPath = path:gsub("/", "\\")
  if package.config:sub(1, 1) == "\\" then
    os.execute('if not exist "' .. winPath .. '" mkdir "' .. winPath .. '"')
  else
    os.execute('mkdir -p "' .. path .. '"')
  end
end

-- Minimal JSON encoder: arrays are tables with consecutive integer keys from 1.
local function EncodeJson(value)
  local out = {}
  local function Str(s)
    s = s:gsub('[%c"\\]', function(c)
      local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
      return map[c] or string.format("\\u%04x", c:byte())
    end)
    return '"' .. s .. '"'
  end
  local function Enc(v)
    local t = type(v)
    if t == "nil" then
      out[#out + 1] = "null"
    elseif t == "boolean" then
      out[#out + 1] = tostring(v)
    elseif t == "number" then
      if v ~= v or v == math.huge or v == -math.huge then
        out[#out + 1] = "null"
      elseif Compat.IsInteger(v) then
        out[#out + 1] = tostring(v)
      else
        out[#out + 1] = string.format("%.4g", v)
      end
    elseif t == "string" then
      out[#out + 1] = Str(v)
    elseif t == "table" then
      local n = #v
      local isArray = n > 0 or next(v) == nil
      if isArray then
        for k in pairs(v) do
          if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
            isArray = false
            break
          end
        end
      end
      if isArray then
        out[#out + 1] = "["
        for i = 1, n do
          if i > 1 then
            out[#out + 1] = ","
          end
          Enc(v[i])
        end
        out[#out + 1] = "]"
      else
        out[#out + 1] = "{"
        local keys = {}
        for k in pairs(v) do
          keys[#keys + 1] = k
        end
        table.sort(keys, function(a, b)
          return tostring(a) < tostring(b)
        end)
        for i, k in ipairs(keys) do
          if i > 1 then
            out[#out + 1] = ","
          end
          out[#out + 1] = Str(tostring(k)) .. ":"
          Enc(v[k])
        end
        out[#out + 1] = "}"
      end
    else
      out[#out + 1] = Str(tostring(v))
    end
  end
  Enc(value)
  return table.concat(out)
end

-- Loads a data file of the addon in a throwaway environment and returns the
-- addonTable it populated (used for spec / season / forces manifests).
local function LoadAddonData(relPath)
  local addonTable = {}
  local chunk = assert(Compat.LoadFileWithEnv(ADDON_ROOT .. "/" .. relPath, setmetatable({}, { __index = _G })))
  chunk("isiLive", addonTable)
  return addonTable
end

local function ReadToc()
  local toc = assert(ReadFile(ADDON_ROOT .. "/isiLive.toc"), "isiLive.toc not found")
  local files, meta = {}, {}
  for line in toc:gmatch("[^\r\n]+") do
    local key, value = line:match("^##%s*([%w%-_]+)%s*:%s*(.-)%s*$")
    if key then
      meta[key] = value
    elseif not line:match("^%s*#") and line:match("%S") then
      files[#files + 1] = (line:gsub("\\", "/"):gsub("%s+$", ""))
    end
  end
  return files, meta
end

-------------------------------------------------------------------------------
-- Argument parsing
-------------------------------------------------------------------------------
local args = { out = SCRIPT_DIR .. "/out" }
do
  local i = 1
  while arg and i <= #arg do
    local a = arg[i]
    if a == "--out" then
      args.out = arg[i + 1]
      i = i + 1
    elseif a == "--locale" then
      args.locale = arg[i + 1]
      i = i + 1
    elseif a == "--screen" then
      local w, h = tostring(arg[i + 1]):match("^(%d+)x(%d+)$")
      args.screenW, args.screenH = tonumber(w), tonumber(h)
      i = i + 1
    elseif a == "--savedvars" then
      args.savedvars = arg[i + 1]
      i = i + 1
    elseif a == "--quiet" then
      args.quiet = true
    elseif a == "--list" then
      args.list = true
    elseif not args.scenario then
      args.scenario = a
    end
    i = i + 1
  end
end

if args.list or not args.scenario then
  print("Available scenarios (tools/wowsim/scenarios):")
  local p = io.popen(
    package.config:sub(1, 1) == "\\" and ('dir /b "' .. (SCRIPT_DIR .. "/scenarios"):gsub("/", "\\") .. '"')
      or ('ls "' .. SCRIPT_DIR .. '/scenarios"')
  )
  if p then
    for name in p:lines() do
      local base = name:match("^(.-)%.lua$")
      if base then
        local scenario = dofile(SCRIPT_DIR .. "/scenarios/" .. name)
        print(string.format("  %-24s %s", base, scenario.description or ""))
      end
    end
    p:close()
  end
  if not args.scenario then
    print("\nUsage: lua tools/wowsim/wowsim.lua <scenario> [--locale deDE] [--out dir] [--savedvars auto|path]")
  end
  os.exit(0)
end

local scenarioPath = args.scenario
if not scenarioPath:match("%.lua$") then
  scenarioPath = SCRIPT_DIR .. "/scenarios/" .. scenarioPath .. ".lua"
end
local scenario = dofile(scenarioPath)
local scenarioName = scenario.name or args.scenario:match("([^/\\]+)%.lua$") or args.scenario

-------------------------------------------------------------------------------
-- World setup
-------------------------------------------------------------------------------
local tocFiles, tocMeta = ReadToc()
local specManifest = LoadAddonData("data/isiLive_specs.lua").SpecManifest.specs
local seasonManifest = LoadAddonData("data/isiLive_seasons.lua").SeasonManifest
local forcesDB = LoadAddonData("data/isiLive_mplus_forces.lua").MPlusForces

local world = World.New({ specManifest = specManifest, zone = scenario.zone })

-- Challenge maps of the active season. Time limits are not part of the
-- addon's data; the scenario may override them, otherwise 30 minutes.
world.challengeMaps = {}
do
  local season = seasonManifest.seasons[seasonManifest.activeSeasonID]
  for _, d in ipairs(season and season.dungeons or {}) do
    local total = forcesDB.dungeonTotal and forcesDB.dungeonTotal[d.mapID]
    world.challengeMaps[d.mapID] = {
      name = d.names and d.names.enUS or ("Map " .. d.mapID),
      timeLimit = (scenario.timeLimits and scenario.timeLimits[d.mapID]) or 1800,
      forcesTotal = total and total.total or 300,
    }
  end
end

local stats = { unknownMethods = {}, missingGlobals = {}, errors = 0, expectFailed = 0, expectPassed = 0 }

world.onLog = function(entry)
  if entry.kind == "error" then
    stats.errors = stats.errors + 1
  end
  if not args.quiet and entry.kind ~= "event" and entry.kind ~= "addon" then
    print(
      string.format(
        "[%7.2f] %-6s %s%s",
        entry.t,
        entry.kind,
        entry.client and ("<" .. entry.client .. "> ") or "",
        entry.text
      )
    )
  end
end

-------------------------------------------------------------------------------
-- Clients
-------------------------------------------------------------------------------
local function LoadSavedVariables(env)
  local path = args.savedvars
  if not path then
    return
  end
  if path == "auto" then
    local base = ADDON_ROOT .. "/../../../WTF/Account"
    local p = io.popen(
      package.config:sub(1, 1) == "\\" and ('dir /b /s "' .. base:gsub("/", "\\") .. '\\isiLive.lua" 2>nul')
        or ('find "' .. base .. '" -name isiLive.lua')
    )
    path = p and p:read("*l") or nil
    if p then
      p:close()
    end
    if not path then
      print("wowsim: --savedvars auto found no isiLive.lua")
      return
    end
  end
  local chunk, err = Compat.LoadFileWithEnv(path, env)
  if not chunk then
    print("wowsim: cannot load savedvars: " .. tostring(err))
    return
  end
  chunk()
  print("wowsim: IsiLiveDB loaded from " .. path)
end

local function CreateClient(member, opts)
  local client = { member = member, label = member.name, locale = opts.locale or "enUS", prefixes = {} }
  local env = {}
  client.env = env
  client.engine = Widgets.New({
    clock = world.clock,
    env = env,
    screenW = args.screenW or scenario.screenW,
    screenH = args.screenH or scenario.screenH,
    onUnknownMethod = function(objectType, key)
      local k = objectType .. ":" .. key
      stats.unknownMethods[k] = (stats.unknownMethods[k] or 0) + 1
    end,
    onScriptError = function(err)
      world.Log("error", err, client)
    end,
  })
  Api.Build({ world = world, client = client, engine = client.engine, env = env, addonMeta = tocMeta })
  if scenario.patchApi then
    scenario.patchApi(env, client, world)
  end
  -- Record reads of globals the API does not provide; they read as nil.
  setmetatable(env, {
    __index = function(_, key)
      if type(key) == "string" and key:match("^[A-Z]") then
        stats.missingGlobals[key] = (stats.missingGlobals[key] or 0) + 1
      end
      return nil
    end,
  })

  function client.Fire(event, ...)
    if client.isFocus then
      local parts = {}
      for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
      end
      world.Log("event", event .. (#parts > 0 and (" " .. table.concat(parts, " ")) or ""), client)
    end
    return client.engine.FireEvent(event, ...)
  end

  -- savedVariables: the IsiLiveDB a /reload hands back (see sim.Reload);
  -- otherwise the focus client may load one from --savedvars.
  function client.Load(savedVariables)
    if type(savedVariables) == "table" then
      env.IsiLiveDB = savedVariables
    elseif member.isFocus then
      LoadSavedVariables(env)
    end
    local addonTable = {}
    client.addonTable = addonTable
    for _, file in ipairs(tocFiles) do
      local chunk, err = Compat.LoadFileWithEnv(ADDON_ROOT .. "/" .. file, env)
      if not chunk then
        world.Log("error", "load " .. file .. ": " .. tostring(err), client)
      else
        local ok, runErr = Compat.XCall(chunk, "isiLive", addonTable)
        if not ok then
          world.Log("error", "exec " .. file .. ": " .. tostring(runErr), client)
        end
      end
    end
    client.Fire("ADDON_LOADED", "isiLive")
    client.Fire("VARIABLES_LOADED")
    client.Fire("SPELLS_CHANGED")
    client.Fire("PLAYER_LOGIN")
    client.Fire("PLAYER_ENTERING_WORLD", true, false)
    client.Fire("UPDATE_BINDINGS")
  end

  -- Runs a slash command the way the chat edit box would.
  function client.Slash(text)
    local cmd, rest = text:match("^(/%S+)%s*(.-)$")
    cmd = (cmd or text):lower()
    for key, handler in pairs(env.SlashCmdList) do
      for i = 1, 9 do
        local alias = rawget(env, "SLASH_" .. key .. i)
        if alias == nil then
          break
        end
        if alias:lower() == cmd then
          world.Log("note", "slash " .. text, client)
          local ok, err = Compat.XCall(handler, rest or "", env.ChatFrame1EditBox)
          if not ok then
            world.Log("error", err, client)
          end
          return true
        end
      end
    end
    world.Log("error", "unknown slash command " .. tostring(cmd), client)
    return false
  end

  world.clients[#world.clients + 1] = client
  return client
end

-------------------------------------------------------------------------------
-- Scenario API
-------------------------------------------------------------------------------
local sim = { world = world, steps = {}, clients = {} }
local lastLogIndex = 0

local setup = scenario.setup or {}
for i, spec in ipairs(setup.party or {}) do
  local member = world.NewMember(spec)
  member.isFocus = i == 1
  member.simulate = (i == 1) or (spec.simulate == true and member.addon == "isilive")
  member.inGroup = false
  world.members[#world.members + 1] = member
end
assert(#world.members > 0, "scenario.setup.party must list at least the player")

for _, member in ipairs(world.members) do
  if member.simulate then
    local client = CreateClient(member, { locale = member.isFocus and (args.locale or setup.locale) or member.locale })
    client.isFocus = member.isFocus
    sim.clients[member.name] = client
    if member.isFocus then
      sim.focus = client
    end
  end
end

-- Virtual LibKeystone peers (other addons such as RaiderIO): answer "R"
-- requests and announce their key when the group forms.
local function LibKsPayload(m)
  local k = m.key or { level = 0, mapID = 0 }
  return string.format("%d,%d,%d", k.level or 0, k.mapID or 0, m.rating or 0)
end
for _, member in ipairs(world.members) do
  if not member.simulate and member.addon == "libks" then
    world.virtualPeers[member.name] = function(prefix, message)
      if prefix == "LibKS" and message == "R" then
        world.SendFromVirtual(member, "LibKS", LibKsPayload(member), "PARTY")
      end
    end
  end
end

local function ClientOf(name)
  return name and sim.clients[name] or sim.focus
end

function sim.Log(text)
  world.Log("note", text)
end

-- Records a UI snapshot of the focus client (or `opts.client`) together with
-- all log entries since the previous step.
function sim.Step(label, opts)
  opts = opts or {}
  local client = ClientOf(opts.client)
  local entries = {}
  for i = lastLogIndex + 1, #world.log do
    entries[#entries + 1] = world.log[i]
  end
  lastLogIndex = #world.log
  local frames = client.engine.Snapshot()
  sim.steps[#sim.steps + 1] =
    { t = math.floor(world.t * 100 + 0.5) / 100, label = label, frames = frames, log = entries }
  if not args.quiet then
    print(string.format("== step %d [%6.1fs] %s  (%d visible regions)", #sim.steps, world.t, label, #frames))
  end
  return frames
end

function sim.Wait(seconds, tickRate)
  world.Advance(seconds, tickRate)
end

function sim.Fire(event, ...)
  world.FireAll(event, ...)
end

function sim.Slash(text, name)
  return ClientOf(name).Slash(text)
end

function sim.Client(name)
  return ClientOf(name)
end

function sim.Env(name)
  return ClientOf(name).env
end

function sim.Member(name)
  return world.FindMember(name)
end

-- Fires a per-client unit event for `member` (unit tokens differ per client).
local function FireUnitEvent(event, member, ...)
  local extra = { ... }
  for _, client in ipairs(world.clients) do
    local token = client.UnitTokenOf(member)
    if token then
      client.Fire(event, token, unpack(extra))
    end
  end
end
sim.FireUnitEvent = FireUnitEvent

function sim.Login()
  for _, client in ipairs(world.clients) do
    client.Load()
  end
  world.Advance(1)
end

local function DeepCopy(value)
  if type(value) ~= "table" then
    return value
  end
  local copy = {}
  for key, inner in pairs(value) do
    copy[DeepCopy(key)] = DeepCopy(inner)
  end
  return copy
end

-- Simulates /reload for one client (default: the player). WoW fires
-- PLAYER_LOGOUT, writes the SavedVariables to disk and loads the addon into a
-- fresh UI; only IsiLiveDB survives, as a copy of what was saved.
function sim.Reload(name)
  local old = ClientOf(name)
  old.Fire("PLAYER_LOGOUT")
  local saved = DeepCopy(rawget(old.env, "IsiLiveDB"))
  for index, client in ipairs(world.clients) do
    if client == old then
      table.remove(world.clients, index)
      break
    end
  end
  local fresh = CreateClient(old.member, { locale = old.locale })
  fresh.isFocus = old.isFocus
  sim.clients[old.member.name] = fresh
  if sim.focus == old then
    sim.focus = fresh
  end
  world.Log("note", "/reload", fresh)
  fresh.Load(saved or {})
  world.Advance(1)
  return fresh
end

-- Puts the listed members (by name) into the group with the player.
function sim.JoinGroup(...)
  local names = { ... }
  local focus = sim.focus.member
  focus.inGroup = true
  for _, name in ipairs(names) do
    local m = assert(world.FindMember(name), "unknown member " .. tostring(name))
    m.inGroup = true
    world.Log("note", m.name .. " joined the group")
  end
  world.FireAll("GROUP_ROSTER_UPDATE")
  world.FireAll("GROUP_JOINED", 1, "0x0")
  world.FireAll("PARTY_LEADER_CHANGED")
  for _, name in ipairs(names) do
    local m = world.FindMember(name)
    if not m.simulate and m.addon == "libks" then
      world.SendFromVirtual(m, "LibKS", LibKsPayload(m), "PARTY")
    end
  end
end

function sim.LeaveGroup(name)
  local m = assert(world.FindMember(name))
  m.inGroup = false
  world.Log("note", m.name .. " left the group")
  if m == sim.focus.member then
    for _, other in ipairs(world.members) do
      other.inGroup = false
    end
    world.FireAll("GROUP_LEFT", 1, "0x0")
  end
  world.FireAll("GROUP_ROSTER_UPDATE")
end

function sim.SetLeader(name)
  local _, index = world.FindMember(name)
  world.leaderIndex = assert(index)
  world.FireAll("PARTY_LEADER_CHANGED")
  world.FireAll("GROUP_ROSTER_UPDATE")
end

function sim.Combat(on)
  for _, client in ipairs(world.clients) do
    client.inCombat = on and true or false
    client.Fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
  end
end

function sim.EnterDungeon(mapID)
  local info = assert(world.challengeMaps[mapID], "unknown challenge map " .. tostring(mapID))
  world.instance = { name = info.name, mapID = mapID, instanceID = 2000 + mapID, type = "party", difficultyID = 8 }
  world.Log("note", "entering " .. info.name)
  world.FireAll("PLAYER_ENTERING_WORLD", false, false)
  world.FireAll("ZONE_CHANGED_NEW_AREA")
  world.FireAll("UPDATE_INSTANCE_INFO")
end

function sim.LeaveDungeon()
  world.instance = nil
  world.challenge = nil
  world.scenario = nil
  world.FireAll("PLAYER_ENTERING_WORLD", false, false)
  world.FireAll("ZONE_CHANGED_NEW_AREA")
end

function sim.StartKey(opts)
  opts = opts or {}
  local mapID = opts.mapID or (world.instance and world.instance.mapID)
  local info = assert(world.challengeMaps[mapID])
  if not world.instance then
    sim.EnterDungeon(mapID)
  end
  world.challenge = {
    mapID = mapID,
    level = opts.level or 10,
    affixes = opts.affixes or { 9, 10, 147 },
    startedAt = world.t + 10, -- the 10 s countdown before the timer runs
    deaths = 0,
    timeLost = 0,
    deathPenalty = opts.deathPenalty or 15,
    ownerName = opts.owner or sim.focus.member.name,
  }
  local bosses = {}
  for i, name in ipairs(opts.bosses or { "Boss 1", "Boss 2", "Boss 3", "Boss 4" }) do
    bosses[i] = { name = name, done = false }
  end
  world.scenario = { title = info.name, bosses = bosses, forcesTotal = info.forcesTotal, forcesCurrent = 0 }
  world.Log("note", string.format("key start %s +%d", info.name, world.challenge.level))
  world.FireAll("CHALLENGE_MODE_START", mapID)
  world.FireAll("WORLD_STATE_TIMER_START", 1)
  world.FireAll("SCENARIO_UPDATE")
  world.FireAll("SCENARIO_CRITERIA_UPDATE", 999)
end

function sim.KillForces(count)
  local s = assert(world.scenario, "no active scenario")
  s.forcesCurrent = math.min(s.forcesTotal, s.forcesCurrent + count)
  world.FireAll("SCENARIO_CRITERIA_UPDATE", 999)
end

function sim.KillBoss(index)
  local s = assert(world.scenario, "no active scenario")
  s.bosses[index].done = true
  world.Log("note", "boss killed: " .. s.bosses[index].name)
  world.FireAll("ENCOUNTER_END", 3000 + index, s.bosses[index].name, 8, 5, 1)
  world.FireAll("SCENARIO_CRITERIA_UPDATE", 1000 + index)
end

function sim.Death(name)
  local m = assert(world.FindMember(name))
  m.dead = true
  m.health = 0
  world.Log("note", m.name .. " died")
  local c = world.challenge
  if c and not c.completed then
    c.deaths = c.deaths + 1
    c.timeLost = c.timeLost + c.deathPenalty
  end
  FireUnitEvent("UNIT_HEALTH", m)
  local client = sim.clients[m.name]
  if client then
    client.Fire("PLAYER_DEAD")
  end
  if c then
    world.FireAll("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
  end
end

function sim.Resurrect(name)
  local m = assert(world.FindMember(name))
  m.dead = false
  m.health = 0.6
  world.Log("note", m.name .. " resurrected")
  FireUnitEvent("UNIT_HEALTH", m)
  local client = sim.clients[m.name]
  if client then
    client.Fire("PLAYER_ALIVE")
  end
end

function sim.SetHealth(name, fraction)
  local m = assert(world.FindMember(name))
  m.health = fraction
  FireUnitEvent("UNIT_HEALTH", m)
end

local castSeq = 0
-- A member casts a spell. Only the caster's own client sees
-- UNIT_SPELLCAST_SUCCEEDED (isiLive registers it for player/pet only); the
-- others learn about it through the addon's own sync, exactly like in game.
function sim.Cast(name, spellID)
  local m = assert(world.FindMember(name))
  castSeq = castSeq + 1
  local castGUID = string.format("Cast-3-1403-0-0-%d-%010d", spellID, castSeq)
  world.Log("note", string.format("%s casts %d", m.name, spellID))
  local client = sim.clients[m.name]
  if client then
    client.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", castGUID, spellID)
  end
end

function sim.CompleteKey(opts)
  opts = opts or {}
  local c = assert(world.challenge, "no active key")
  local info = world.challengeMaps[c.mapID]
  c.completed = true
  c.completedTime = world.t - c.startedAt + c.timeLost
  c.onTime = opts.onTime ~= false and c.completedTime <= info.timeLimit
  c.upgrades = c.onTime and 1 or 0
  world.Log("note", string.format("key completed in %.0fs (onTime=%s)", c.completedTime, tostring(c.onTime)))
  world.FireAll("CHALLENGE_MODE_COMPLETED")
  world.FireAll("SCENARIO_COMPLETED")
  -- The keyholder receives the new keystone a moment later: timed runs
  -- upgrade by the upgrade count, depleted runs drop one level; the dungeon
  -- rotates to another map of the season.
  local owner = c.ownerName and world.FindMember(c.ownerName)
  if owner and owner.key then
    local maps = {}
    for mapID in pairs(world.challengeMaps) do
      if mapID ~= c.mapID then
        maps[#maps + 1] = mapID
      end
    end
    table.sort(maps)
    local newLevel = c.onTime and (c.level + c.upgrades) or math.max(2, c.level - 1)
    world.clock.after(opts.newKeyDelay or 3, function()
      owner.key = { mapID = maps[(c.level % #maps) + 1] or c.mapID, level = newLevel }
      world.Log("note", string.format("%s receives new keystone +%d (map %d)", owner.name, newLevel, owner.key.mapID))
      local client = sim.clients[owner.name]
      if client then
        client.Fire("ITEM_PUSH", 0, 525134)
        client.Fire("BAG_UPDATE", 0)
        client.Fire("BAG_UPDATE_DELAYED")
      end
    end)
  end
end

function sim.ResetKey()
  world.challenge = nil
  world.scenario = nil
  world.FireAll("CHALLENGE_MODE_RESET", 0)
end

function sim.ReadyCheck(initiatorName, responses)
  local initiator = assert(world.FindMember(initiatorName))
  world.FireAllPerClient("READY_CHECK", function(client)
    return { client.UnitTokenOf(initiator) and initiator.name or initiator.name, 30 }
  end)
  for name, ready in pairs(responses or {}) do
    local m = world.FindMember(name)
    if m then
      m.readyStatus = ready and "ready" or "notready"
      FireUnitEvent("READY_CHECK_CONFIRM", m, ready and true or false)
    end
  end
end

function sim.FinishReadyCheck()
  for _, m in ipairs(world.members) do
    m.readyStatus = nil
  end
  world.FireAll("READY_CHECK_FINISHED", false)
end

-- Clicks the first visible button whose (escape-stripped) text matches
-- `pattern`, or the frame with the given global name.
function sim.Click(pattern, name)
  local client = ClientOf(name)
  local engine = client.engine
  local target = engine.byName[pattern]
  if not target then
    for _, obj in ipairs(engine.all) do
      if obj._isFrame and obj.GetText and obj:IsVisible() then
        local text = obj._fontString and obj._fontString._text
        if text and engine.StripEscapes(text):find(pattern) then
          target = obj
          break
        end
      end
    end
  end
  if not target then
    world.Log("error", "Click: no visible button matching '" .. tostring(pattern) .. "'", client)
    return false
  end
  world.Log("note", "click " .. tostring(target._name or pattern), client)
  local fn = target:GetScript("OnClick")
  if fn then
    local ok, err = Compat.XCall(fn, target, "LeftButton", false)
    if not ok then
      world.Log("error", err, client)
    end
  end
  return true
end

-- Returns the visible text regions of the focus client whose text matches.
function sim.FindText(pattern, name)
  local client = ClientOf(name)
  local found = {}
  for _, entry in ipairs(client.engine.Snapshot()) do
    if entry.text and client.engine.StripEscapes(entry.text.s):find(pattern) then
      found[#found + 1] = entry
    end
  end
  return found
end

function sim.Expect(condition, message)
  if condition then
    stats.expectPassed = stats.expectPassed + 1
    world.Log("note", "PASS " .. tostring(message))
  else
    stats.expectFailed = stats.expectFailed + 1
    world.Log("error", "EXPECT FAILED: " .. tostring(message))
  end
  return condition
end

function sim.ExpectText(pattern, message, name)
  return sim.Expect(#sim.FindText(pattern, name) > 0, message or ("text visible: " .. pattern))
end

-- Returns log entries of `kind` ("print", "sound", "addon", ...) whose text
-- matches `pattern`, optionally limited to one client and to entries logged
-- at or after `since` (simulated seconds).
function sim.FindLog(kind, pattern, clientName, since)
  local found = {}
  for _, entry in ipairs(world.log) do
    if
      entry.kind == kind
      and (clientName == nil or entry.client == clientName)
      and (since == nil or entry.t >= since)
      and entry.text:find(pattern)
    then
      found[#found + 1] = entry
    end
  end
  return found
end

function sim.ExpectLog(kind, pattern, clientName, message, since)
  local text = message or string.format("%s log on %s: %s", kind, tostring(clientName or "any"), pattern)
  return sim.Expect(#sim.FindLog(kind, pattern, clientName, since) > 0, text)
end

function sim.Now()
  return world.t
end

-------------------------------------------------------------------------------
-- Run
-------------------------------------------------------------------------------
local ok, err = Compat.XCall(scenario.run, sim)
if not ok then
  world.Log("error", "scenario aborted: " .. tostring(err))
  sim.Step("scenario aborted")
end
if #sim.steps == 0 or lastLogIndex < #world.log then
  sim.Step("end")
end

local function SortedCounts(map)
  local list = {}
  for k, v in pairs(map) do
    list[#list + 1] = { k, v }
  end
  table.sort(list, function(a, b)
    return a[2] > b[2]
  end)
  return list
end

local data = {
  meta = {
    addon = "isiLive",
    version = tocMeta.Version,
    scenario = scenarioName,
    description = scenario.description,
    screen = { w = sim.focus.engine.screenW, h = sim.focus.engine.screenH },
    generatedAt = os.date("%Y-%m-%d %H:%M"),
    stats = {
      errors = stats.errors,
      expectPassed = stats.expectPassed,
      expectFailed = stats.expectFailed,
    },
  },
  steps = sim.steps,
}

EnsureDir(args.out)
local jsonPath = args.out .. "/" .. scenarioName .. ".json"
local htmlPath = args.out .. "/" .. scenarioName .. ".html"
local jsonText = EncodeJson(data)
WriteFile(jsonPath, jsonText)

WOWSIM_BUILD_VIEWER_AS_LIB = true
local viewer = dofile(SCRIPT_DIR .. "/build_viewer.lua")
WOWSIM_BUILD_VIEWER_AS_LIB = nil
local built, buildErr = pcall(viewer.build, jsonText, htmlPath, ADDON_ROOT)
if not built then
  print("wowsim: viewer build failed: " .. tostring(buildErr))
end

print("")
print(
  string.format(
    "wowsim: scenario '%s' finished: %d steps, %d errors, expectations %d passed / %d failed",
    scenarioName,
    #sim.steps,
    stats.errors,
    stats.expectPassed,
    stats.expectFailed
  )
)
local missing = SortedCounts(stats.missingGlobals)
if #missing > 0 then
  local names = {}
  for i = 1, math.min(#missing, 25) do
    names[#names + 1] = missing[i][1] .. "(" .. missing[i][2] .. ")"
  end
  print("wowsim: globals read but not simulated: " .. table.concat(names, ", "))
end
local unknown = SortedCounts(stats.unknownMethods)
if #unknown > 0 then
  local names = {}
  for i = 1, math.min(#unknown, 25) do
    names[#names + 1] = unknown[i][1] .. "(" .. unknown[i][2] .. ")"
  end
  print("wowsim: widget methods not simulated (no-op): " .. table.concat(names, ", "))
end
print("wowsim: JSON   " .. jsonPath)
print("wowsim: viewer " .. htmlPath)

os.exit((stats.errors > 0 or stats.expectFailed > 0) and 1 or 0)
