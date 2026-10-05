local _, addonTable = ...

addonTable = addonTable or {}

addonTable.SyncReceiveFactory = function(deps)
  local Sync = deps.Sync
  local ISILIVE_SYNC_PREFIX = deps.ISILIVE_SYNC_PREFIX
  local LIBKEYSTONE_SYNC_PREFIX = deps.LIBKEYSTONE_SYNC_PREFIX
  local LIBKEYSTONE_SOURCE = deps.LIBKEYSTONE_SOURCE
  local ISILIVE_SHAREKEYS_CD_MAX_SECONDS = deps.ISILIVE_SHAREKEYS_CD_MAX_SECONDS
  local ToFiniteNumber = deps.ToFiniteNumber
  local IsExplicitNonFiniteNumber = deps.IsExplicitNonFiniteNumber
  local IsPlainPeerName = deps.IsPlainPeerName
  local SyncLog = deps.SyncLog
  local SyncLogDeep = deps.SyncLogDeep
  local FormatBytes = deps.FormatBytes
  local SplitPayload = deps.SplitPayload
  local ParseKickPayload = deps.ParseKickPayload
  local MAX_ADDON_MESSAGE_LENGTH = 255

  local function IsIsiLiveReceiveChannelAllowed(message, channel)
    if channel == nil or channel == "PARTY" or channel == "INSTANCE_CHAT" then
      return true
    end
    return channel == "WHISPER" and type(message) == "string" and message:find("^ACK:") ~= nil
  end

  local function ProcessLibKeystoneMessage(message, sender, localName, localRealm, channel)
    if type(sender) ~= "string" or sender == "" then
      return nil
    end
    if type(message) ~= "string" or #message == 0 or #message > MAX_ADDON_MESSAGE_LENGTH then
      return nil
    end
    -- LibKeystone is party-only protocol, but inside an instance the WoW server
    -- delivers party addon messages on the INSTANCE_CHAT channel. Accept both
    -- so peers running RaiderIO (or any other LibKeystone-using addon) reach us
    -- inside M+ keys, dungeons, and scenarios.
    if channel ~= nil and channel ~= "PARTY" and channel ~= "INSTANCE_CHAT" then
      return nil
    end

    local senderKey = Sync.NormalizePlayerKey(sender)
    local selfKey = Sync.NormalizePlayerKey(localName, localRealm)
    if type(message) == "string" and message == "R" then
      SyncLog("libkeystone_request", "sender=%s shouldReply=%s", tostring(sender), tostring(senderKey ~= selfKey))
      return {
        sender = sender,
        shouldReplyLibKeystone = senderKey ~= selfKey,
      }
    end

    local levelRaw, mapIDRaw, ratingRaw = nil, nil, nil
    if type(message) == "string" then
      levelRaw, mapIDRaw, ratingRaw = string.match(message, "^(%d+),(%d+),(%d+)$")
    end
    if not levelRaw or not mapIDRaw or not ratingRaw then
      return nil
    end

    local keyLevel = ToFiniteNumber(levelRaw)
    local keyMapID = ToFiniteNumber(mapIDRaw)
    local playerRating = ToFiniteNumber(ratingRaw)
    if playerRating == nil or playerRating < 0 then
      return nil
    end

    SyncLog(
      "libkeystone_received",
      "sender=%s mapID=%s level=%s rio=%s",
      tostring(sender),
      tostring(keyMapID),
      tostring(keyLevel),
      tostring(playerRating)
    )
    local keyUpdated = Sync.SetPlayerKeyInfo(sender, nil, keyMapID, keyLevel, nil, LIBKEYSTONE_SOURCE)
    local previousStats = Sync.GetPlayerStatsInfo(sender, nil)
    local statsUpdated = Sync.SetPlayerStatsInfo(
      sender,
      nil,
      previousStats and previousStats.specID or nil,
      previousStats and previousStats.ilvl or nil,
      playerRating,
      nil,
      LIBKEYSTONE_SOURCE
    )

    return {
      sender = sender,
      keyUpdated = keyUpdated and true or false,
      statsUpdated = statsUpdated and true or false,
      shouldReplyLibKeystone = false,
    }
  end

  --- Processes an incoming addon message and updates peer sync state accordingly.
  -- Routes ISILIVE payloads (KEY, STATS, DPS, LOC, TARGET, KICK, HELLO, ACK, REQSYNC, SHAREKEYS, SKCD)
  -- and LibKS payloads to their respective handlers. Silently drops messages that fail
  -- prefix, sender, or length validation.
  -- @param prefix string Addon message prefix ("ISILIVE" or "LibKS").
  -- @param message string Raw payload (max 255 bytes; empty or oversized are dropped).
  -- @param sender string Sender's "Name-Realm" string (must be non-empty).
  -- @param localName string Local player name (used to detect self-messages).
  -- @param localRealm string|nil Local player realm.
  -- @param channel string|nil Arrival channel (LibKS accepts PARTY + INSTANCE_CHAT).
  -- @return table|nil Result with fields: shouldAck, shouldRequestRefresh, shouldShareKeys, sender,
  --   peerAddonVersion, peerProtocolVersion, peerCapturedAt, peerSource,
  --   keyUpdated, statsUpdated, dpsUpdated, locUpdated, targetUpdated, kickUpdated,
  --   shareKeysCooldownRemain (number|nil, mirrored share-keys lock from a peer).
  --   Returns nil when the message is rejected or the prefix is unrecognized.
  local function ProcessAddonMessage(prefix, message, sender, localName, localRealm, channel)
    if prefix == LIBKEYSTONE_SYNC_PREFIX then
      return ProcessLibKeystoneMessage(message, sender, localName, localRealm, channel)
    end
    if prefix ~= ISILIVE_SYNC_PREFIX then
      return nil
    end
    if type(sender) ~= "string" or sender == "" then
      return nil
    end
    if type(message) ~= "string" or #message == 0 or #message > MAX_ADDON_MESSAGE_LENGTH then
      return nil
    end
    if not IsIsiLiveReceiveChannelAllowed(message, channel) then
      return nil
    end

    SyncLog("message_received", "sender=%s type=%s", tostring(sender), tostring(message:match("^(%a+)") or "unknown"))

    local senderKey = Sync.NormalizePlayerKey(sender)
    local selfKey = Sync.NormalizePlayerKey(localName, localRealm)
    local isHelloMessage = message:find("^HELLO:") ~= nil
    local isAckMessage = message:find("^ACK:") ~= nil
    local shouldAck = isHelloMessage and senderKey ~= selfKey
    local shouldRequestRefresh = message == "REQSYNC" and senderKey ~= selfKey
    local shouldShareKeys = message == "SHAREKEYS" and senderKey ~= selfKey

    local keyUpdated = false
    local statsUpdated = false
    local dpsUpdated = false
    local locUpdated = false
    local kickUpdated = false
    local targetUpdated = false
    local combatAnnounce = nil
    local powerInfusionAnnounce = nil
    local shareKeysCooldownRemain = nil
    local payloadValid = message == "REQSYNC" or message == "SHAREKEYS"

    local parts = SplitPayload(message)
    local bucket = parts[1]
    SyncLogDeep("message_payload", function()
      return string.format(
        "sender=%s senderBytes=%s bucket=%s raw=%s",
        tostring(sender),
        FormatBytes(sender),
        tostring(bucket or "unknown"),
        tostring(message)
      )
    end)

    if bucket == "KEY" and parts[2] and parts[3] then
      local mapID = ToFiniteNumber(parts[2])
      local level = ToFiniteNumber(parts[3])
      local capturedAt = ToFiniteNumber(parts[4])
      if mapID and level and (parts[4] == nil or capturedAt) then
        payloadValid = true
        keyUpdated = Sync.SetPlayerKeyInfo(sender, nil, mapID, level, capturedAt, parts[5])
      end
    elseif bucket == "STATS" and parts[2] and parts[3] and parts[4] then
      local specID = ToFiniteNumber(parts[2])
      local ilvl = ToFiniteNumber(parts[3])
      local rio = ToFiniteNumber(parts[4])
      local capturedAt = ToFiniteNumber(parts[5])
      if specID and ilvl and rio and (parts[5] == nil or capturedAt) then
        payloadValid = true
        statsUpdated = Sync.SetPlayerStatsInfo(sender, nil, specID, ilvl, rio, capturedAt, parts[6])
      end
    elseif bucket == "DPS" and parts[2] then
      local dps = ToFiniteNumber(parts[2])
      local capturedAt = ToFiniteNumber(parts[3])
      if dps and (parts[3] == nil or capturedAt) then
        payloadValid = true
        dpsUpdated = Sync.SetPlayerDpsInfo(sender, nil, dps, capturedAt, parts[4])
      end
    elseif bucket == "LOC" and parts[2] then
      local mapID = ToFiniteNumber(parts[2])
      local capturedAt = ToFiniteNumber(parts[3])
      if mapID and (parts[3] == nil or capturedAt) then
        payloadValid = true
        locUpdated = Sync.SetPlayerLocInfo(sender, nil, mapID, capturedAt, parts[4])
      end
    elseif bucket == "TARGET" and parts[2] and parts[3] then
      local levelText = nil
      if parts[6] == "LT" and type(parts[7]) == "string" then
        levelText = parts[7]
      end
      local mapID = ToFiniteNumber(parts[2])
      local level = ToFiniteNumber(parts[3])
      local capturedAt = ToFiniteNumber(parts[4])
      if mapID and level and (parts[4] == nil or capturedAt) then
        payloadValid = true
        targetUpdated = Sync.SetPlayerTargetInfo(sender, nil, mapID, level, capturedAt, parts[5], levelText)
      end
    elseif bucket == "KICK" then
      local parsedKick = ParseKickPayload(message)
      if parsedKick then
        payloadValid = true
        kickUpdated = Sync.SetPlayerKickInfo(
          sender,
          nil,
          parsedKick.state == 1,
          parsedKick.remain,
          nil,
          parsedKick.hasKick,
          parsedKick.extras,
          parsedKick.spellID
        )
      end
    elseif bucket == "SKCD" and parts[2] then
      -- Mirrored share-keys button lock from a peer (hello-ack / REQSYNC fan-out).
      -- Self-echo is skipped: the local button is already on cooldown.
      if senderKey ~= selfKey then
        local remain = ToFiniteNumber(parts[2])
        if remain and remain > 0 then
          payloadValid = true
          remain = math.ceil(remain)
          if remain > ISILIVE_SHAREKEYS_CD_MAX_SECONDS then
            remain = ISILIVE_SHAREKEYS_CD_MAX_SECONDS
          end
          shareKeysCooldownRemain = remain
        end
      end
    elseif bucket == "BRLUST" and parts[2] and parts[3] then
      -- Skip self-echo: BroadcastCombatAnnounce already rendered the announce
      -- locally before sending. CHAT_MSG_ADDON on PARTY/INSTANCE_CHAT echoes
      -- back to the sender, so without this guard the print + sound fire twice
      -- for the caster.
      if senderKey ~= selfKey and Sync.NormalizePlayerKey(parts[3]) == senderKey then
        local kind = parts[2]
        if kind == "BR" or kind == "LUST" then
          local spellID = ToFiniteNumber(parts[4])
          if not spellID or spellID <= 0 then
            spellID = nil
          end
          if spellID then
            payloadValid = true
            combatAnnounce = {
              kind = kind,
              caster = parts[3],
              spellID = math.floor(spellID),
            }
          end
        end
      end
    elseif bucket == "PI" and parts[2] and parts[3] then
      -- Skip self-echo: BroadcastPowerInfusionAnnounce already rendered the
      -- announce locally before sending.
      if senderKey ~= selfKey and Sync.NormalizePlayerKey(parts[2]) == senderKey then
        local caster = parts[2]
        local recipient = parts[3]
        local spellID = ToFiniteNumber(parts[4]) or 0
        if caster ~= "" and IsPlainPeerName(recipient) and spellID == 10060 then
          payloadValid = true
          powerInfusionAnnounce = {
            caster = caster,
            recipient = recipient,
            spellID = spellID,
            isLocalRecipient = Sync.NormalizePlayerKey(recipient) == selfKey,
          }
        end
      end
    end

    local peerAddonVersion = nil
    local peerProtocolVersion = nil
    local peerCapturedAt = nil
    local peerSource = nil
    if isHelloMessage or isAckMessage then
      peerAddonVersion = parts[2]
      if isHelloMessage then
        peerProtocolVersion = ToFiniteNumber(parts[3])
        peerCapturedAt = ToFiniteNumber(parts[4])
        peerSource = parts[5]
        local metadataValid = not IsExplicitNonFiniteNumber(parts[3]) and not IsExplicitNonFiniteNumber(parts[4])
        if metadataValid then
          payloadValid = true
          Sync.SetPlayerHelloInfo(sender, nil, peerAddonVersion, peerProtocolVersion, peerCapturedAt, peerSource)
        else
          peerAddonVersion = nil
          peerProtocolVersion = nil
          peerCapturedAt = nil
          peerSource = nil
          shouldAck = false
        end
      elseif peerAddonVersion and peerAddonVersion ~= "" then
        payloadValid = true
        peerSource = "ack"
        Sync.SetPlayerHelloAckInfo(sender, nil, peerAddonVersion)
      end
    end

    -- Loop breaker: a HELLO that is itself an ack fan-out reply must not be
    -- acked again. Without this, two peers answer each other's hello-acks
    -- forever (the fan-out hello is force-sent past the 8 s rate limit), the
    -- resulting message flood backs up the ChatThrottleLib queue by ~30 s, and
    -- the mirrored SKCD locks reflect between the peers indefinitely.
    if shouldAck and (peerSource == "hello-ack" or peerSource == "reqsync-ack") then
      shouldAck = false
    end

    if payloadValid then
      Sync.MarkUser(sender)
    end

    local anyFlag = keyUpdated
      or statsUpdated
      or dpsUpdated
      or locUpdated
      or targetUpdated
      or kickUpdated
      or shouldAck
      or shouldRequestRefresh
      or shouldShareKeys
      or shareKeysCooldownRemain ~= nil
    local logFn = anyFlag and SyncLog or SyncLogDeep
    logFn(
      "message_applied",
      "sender=%s key=%s stats=%s dps=%s loc=%s target=%s kick=%s ack=%s reqsync=%s sharekeys=%s skcd=%s",
      tostring(sender),
      tostring(keyUpdated),
      tostring(statsUpdated),
      tostring(dpsUpdated),
      tostring(locUpdated),
      tostring(targetUpdated),
      tostring(kickUpdated),
      tostring(shouldAck),
      tostring(shouldRequestRefresh),
      tostring(shouldShareKeys),
      tostring(shareKeysCooldownRemain)
    )
    return {
      shouldAck = shouldAck and true or false,
      shouldRequestRefresh = shouldRequestRefresh and true or false,
      sender = sender,
      peerAddonVersion = peerAddonVersion,
      peerProtocolVersion = peerProtocolVersion,
      peerCapturedAt = peerCapturedAt,
      peerSource = peerSource,
      keyUpdated = keyUpdated and true or false,
      statsUpdated = statsUpdated and true or false,
      dpsUpdated = dpsUpdated and true or false,
      locUpdated = locUpdated and true or false,
      targetUpdated = targetUpdated and true or false,
      kickUpdated = kickUpdated and true or false,
      shouldShareKeys = shouldShareKeys and true or false,
      shareKeysCooldownRemain = shareKeysCooldownRemain,
      combatAnnounce = combatAnnounce,
      powerInfusionAnnounce = powerInfusionAnnounce,
    }
  end

  return ProcessAddonMessage
end
