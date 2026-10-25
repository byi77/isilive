-- Shared world model for the wowsim simulator.
--
-- Owns everything that is common to all simulated clients: the simulated
-- clock and timer queue, the party (members, specs, keys, health), the
-- instance / challenge-mode / scenario state and the addon-message network.
-- Each client (wowsim.lua) reads this model through its own WoW API surface
-- (api.lua), so every client sees the same group from its own perspective.

local World = {}

local CLASS_IDS = {
  WARRIOR = 1,
  PALADIN = 2,
  HUNTER = 3,
  ROGUE = 4,
  PRIEST = 5,
  DEATHKNIGHT = 6,
  SHAMAN = 7,
  MAGE = 8,
  WARLOCK = 9,
  MONK = 10,
  DRUID = 11,
  DEMONHUNTER = 12,
  EVOKER = 13,
}
World.CLASS_IDS = CLASS_IDS

function World.New(opts)
  opts = opts or {}
  local world = {
    t = 0,
    epoch = opts.epoch or os.time({ year = 2026, month = 10, day = 25, hour = 20, min = 0, sec = 0 }),
    timers = {},
    timerSeq = 0,
    clients = {},
    members = {}, -- ordered party; members[1] is the group leader
    leaderIndex = 1,
    instance = nil, -- { name, mapID (challenge map), instanceID, type, difficultyID }
    challenge = nil, -- { mapID, level, affixes, startedAt, deaths, timeLost, completed, ... }
    scenario = nil, -- { forcesTotal, forcesCurrent, bosses = { {name, done} } }
    log = {},
    specManifest = opts.specManifest or {},
    zone = opts.zone or "Dornogal",
  }

  ---------------------------------------------------------------------------
  -- Clock and timers
  ---------------------------------------------------------------------------
  local clock = {}
  function clock.now()
    return world.t
  end
  function clock.after(seconds, fn)
    world.timerSeq = world.timerSeq + 1
    local timer = { due = world.t + math.max(0, tonumber(seconds) or 0), fn = fn, seq = world.timerSeq }
    world.timers[#world.timers + 1] = timer
    return timer
  end
  world.clock = clock

  -- Runs all timers due at or before `limit`, in due order. Timers scheduled
  -- by callbacks for the same instant run in the same pass.
  local function RunDueTimers(limit)
    while true do
      local best, bestIndex = nil, nil
      for i, timer in ipairs(world.timers) do
        if not timer.cancelled and timer.due <= limit + 1e-9 then
          if not best or timer.due < best.due or (timer.due == best.due and timer.seq < best.seq) then
            best, bestIndex = timer, i
          end
        end
      end
      if not best then
        break
      end
      table.remove(world.timers, bestIndex)
      if best.due > world.t then
        world.t = best.due
      end
      local ok, err = xpcall(best.fn, debug.traceback)
      if not ok then
        world.Log("error", "timer: " .. tostring(err), best.client)
      end
    end
    -- Drop cancelled timers.
    local kept = {}
    for _, timer in ipairs(world.timers) do
      if not timer.cancelled then
        kept[#kept + 1] = timer
      end
    end
    world.timers = kept
  end

  -- Advances the simulated clock by `seconds`, ticking OnUpdate at `tickRate`
  -- (seconds per frame) on every client and firing due timers in between.
  function world.Advance(seconds, tickRate)
    tickRate = tickRate or 0.1
    local target = world.t + seconds
    while world.t < target - 1e-9 do
      local stepEnd = math.min(target, world.t + tickRate)
      RunDueTimers(stepEnd)
      local elapsed = stepEnd - world.t
      world.t = stepEnd
      for _, client in ipairs(world.clients) do
        client.engine.RunOnUpdate(elapsed > 0 and elapsed or tickRate)
      end
    end
    RunDueTimers(world.t)
  end

  ---------------------------------------------------------------------------
  -- Logging
  ---------------------------------------------------------------------------
  function world.Log(kind, text, client)
    local entry = { t = math.floor(world.t * 100 + 0.5) / 100, kind = kind, text = tostring(text) }
    if client then
      entry.client = client.label
    end
    world.log[#world.log + 1] = entry
    if world.onLog then
      world.onLog(entry)
    end
  end

  ---------------------------------------------------------------------------
  -- Party model
  ---------------------------------------------------------------------------
  local guidSeq = 0
  function world.NewMember(spec)
    guidSeq = guidSeq + 1
    local specInfo = world.specManifest[spec.specID] or {}
    local member = {
      name = spec.name,
      realm = spec.realm or "Blackrock",
      class = spec.class or specInfo.class or "WARRIOR",
      specID = spec.specID,
      specName = spec.specName or specInfo.name or "Spec",
      role = spec.role or "DAMAGER",
      ilvl = spec.ilvl or 700,
      rating = spec.rating or 2500,
      key = spec.key, -- { mapID, level }
      guid = string.format("Player-1403-%08X", 0x0A000000 + guidSeq),
      level = spec.level or 90,
      health = 1,
      dead = false,
      connected = true,
      addon = spec.addon or "isilive", -- "isilive" | "libks" | "none"
      raceFile = spec.race or "Human",
      sex = spec.sex or 2,
    }
    member.classID = CLASS_IDS[member.class] or 1
    return member
  end

  function world.FindMember(name)
    for i, m in ipairs(world.members) do
      if m.name == name then
        return m, i
      end
    end
    return nil
  end

  function world.MemberFullName(member)
    return member.name .. "-" .. member.realm
  end

  ---------------------------------------------------------------------------
  -- Event fan-out
  ---------------------------------------------------------------------------
  -- Fires an event on every client. `argsFor(client)` may return per-client
  -- arguments (unit tokens differ between clients); plain varargs otherwise.
  function world.FireAll(event, ...)
    for _, client in ipairs(world.clients) do
      client.Fire(event, ...)
    end
  end

  function world.FireAllPerClient(event, argsFor)
    for _, client in ipairs(world.clients) do
      local args = argsFor(client)
      if args then
        client.Fire(event, (rawget(table, "unpack") or rawget(_G, "unpack"))(args))
      end
    end
  end

  ---------------------------------------------------------------------------
  -- Addon-message network
  ---------------------------------------------------------------------------
  world.registeredPrefixes = {}
  world.virtualPeers = {} -- name -> handler(prefix, msg, channel, sender)

  function world.SendAddonMessage(fromClient, prefix, message, channel, target)
    local sender = fromClient.member
    world.Log(
      "addon",
      string.format("%s > %s [%s] %s", sender.name, tostring(channel), tostring(prefix), tostring(message)),
      fromClient
    )
    local senderFull = world.MemberFullName(sender)
    -- Deliver after a small network delay, like the real server round trip.
    world.clock.after(0.05, function()
      for _, client in ipairs(world.clients) do
        local inGroup = client.member.inGroup
        local whisperOk = channel ~= "WHISPER"
          or (target and (target == client.member.name or target == world.MemberFullName(client.member)))
        if inGroup and sender.inGroup and whisperOk and client.prefixes[prefix] then
          local deliverChannel = channel
          if channel == "PARTY" and world.instance then
            deliverChannel = "INSTANCE_CHAT"
          end
          client.Fire("CHAT_MSG_ADDON", prefix, message, deliverChannel, senderFull, client.member.name, 0, 0, "", 0)
        end
      end
      for name, handler in pairs(world.virtualPeers) do
        local m = world.FindMember(name)
        if m and m.inGroup and m ~= sender then
          handler(prefix, message, channel, senderFull)
        end
      end
    end)
  end

  -- Sends a message from a virtual (non-simulated) group member to all clients.
  function world.SendFromVirtual(member, prefix, message, channel)
    world.Log(
      "addon",
      string.format("%s > %s [%s] %s", member.name, tostring(channel), tostring(prefix), tostring(message))
    )
    world.clock.after(0.05, function()
      for _, client in ipairs(world.clients) do
        if client.member.inGroup and client.prefixes[prefix] then
          local deliverChannel = channel
          if channel == "PARTY" and world.instance then
            deliverChannel = "INSTANCE_CHAT"
          end
          client.Fire(
            "CHAT_MSG_ADDON",
            prefix,
            message,
            deliverChannel,
            world.MemberFullName(member),
            client.member.name,
            0,
            0,
            "",
            0
          )
        end
      end
    end)
  end

  function world.SendChatMessage(fromClient, text, chatType)
    local sender = fromClient.member
    world.Log("chat", string.format("[%s] %s: %s", tostring(chatType), sender.name, tostring(text)), fromClient)
    local event = ({
      PARTY = "CHAT_MSG_PARTY",
      PARTY_LEADER = "CHAT_MSG_PARTY_LEADER",
      INSTANCE_CHAT = "CHAT_MSG_INSTANCE_CHAT",
      SAY = "CHAT_MSG_SAY",
      RAID = "CHAT_MSG_RAID",
    })[chatType or "SAY"]
    if event then
      world.clock.after(0.05, function()
        world.FireAll(event, text, world.MemberFullName(sender), "", "", sender.name, "", 0, 0, "", 0, 0, sender.guid)
      end)
    end
  end

  return world
end

return World
