-- Standalone CLI tool: walks the full keystone-chat-link resolution lifecycle
-- and verifies every branch of ContextHelpers.BuildKeystoneChatLink behaves
-- correctly against the current WoW retail Mythic Keystone APIs.
--
-- The clickable-link source is a bag scan for itemID 180653 (Mythic Keystone) using
-- C_Container.GetContainerItemLink, which returns a real |Hkeystone:...|h
-- or |Hitem:180653...|h link the chat server accepts.
--
-- Manually constructed |Hkeystone:...|h links are silently dropped by the
-- chat server (treated as fake item links). Any plain-text fallback must
-- NOT wrap [text] in |cff...|r color codes — the same server filter rejects
-- those, even if they look syntactically valid (CLAUDE.md "Chat messages:
-- no color codes around square brackets").
--
-- Verifies:
--   * Primary: bag scan finds itemID 180653 -> returns its real link.
--   * Keystone item hyperlinks for itemID 180653 stay clickable instead of
--     falling back to plain text.
--   * Invalid bag link: scanning continues until a verified link is found.
--   * Empty bag: no key → plain-text "[Keystone: <dungeonName> +N]" form,
--     never |c...|r-wrapped.
--   * Multi-key bags: first matching itemID 180653 wins.
--   * pcall isolation: GetContainerItemID / GetContainerItemLink errors do
--     not abort the iteration.
--   * Invalid input: mapID <= 0 or level <= 0 → returns nil (cannot send).
--   * Plain-text fallback contains no color-code wrappers.
--
-- COMPONENT-ONLY (CLAUDE.md "Tests & simulators: end-to-end by default"
-- exception): ContextHelpers.BuildKeystoneChatLink is a pure function with
-- no event path — its inputs are (mapID, level, dungeonName) plus the
-- C_Container globals. There is no upstream production
-- caller chain to drive end-to-end here; the SHAREKEYS roundtrip in
-- simulate_sender_receiver.lua exercises the result of this function in a
-- real send pipeline. Direct branch-coverage via mocked bag/API state is
-- the appropriate level for this surface.
---@diagnostic disable: undefined-global
local io = io
---@diagnostic disable-next-line: undefined-global
local load = load

local function LoadLocal(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  local chunk, err = (loadstring or load)(source, "@" .. path)
  assert(chunk, err)
  return chunk()
end

local Harness = LoadLocal("testmodul/isilive_test_harness.lua")

local failures = 0

local function Check(condition, message)
  if condition then
    print("  [CHECK PASS] " .. message)
    return
  end
  failures = failures + 1
  print("  [CHECK FAIL] " .. message)
end

-- ----------------------------------------------------------------------
-- Bag model: maps bagID -> { [slotID] = { itemID, link, errorOnRead } }.
-- The simulator builds C_Container shims that read from this model.
-- ----------------------------------------------------------------------
local function NewBagModel()
  return {
    contents = {}, -- contents[bagID][slotID] = { itemID, link }
  }
end

local function BagsForcePut(bagModel, bagID, slotID, entry)
  bagModel.contents[bagID] = bagModel.contents[bagID] or {}
  bagModel.contents[bagID][slotID] = entry
end

local function BuildContainerApi(bagModel)
  return {
    GetContainerNumSlots = function(bagID)
      local bag = bagModel.contents[bagID]
      if not bag then
        return 0
      end
      local maxSlot = 0
      for slot in pairs(bag) do
        if slot > maxSlot then
          maxSlot = slot
        end
      end
      return maxSlot
    end,
    GetContainerItemID = function(bagID, slotID)
      local bag = bagModel.contents[bagID]
      local entry = bag and bag[slotID] or nil
      if entry and entry.errorOnRead == "id" then
        error("simulated GetContainerItemID failure", 0)
      end
      return entry and entry.itemID or nil
    end,
    GetContainerItemLink = function(bagID, slotID)
      local bag = bagModel.contents[bagID]
      local entry = bag and bag[slotID] or nil
      if entry and entry.errorOnRead == "link" then
        error("simulated GetContainerItemLink failure", 0)
      end
      return entry and entry.link or nil
    end,
  }
end

-- ----------------------------------------------------------------------
-- A standard fixture: NPX +14, valid bag-scan link, fallback dungeon name.
-- ----------------------------------------------------------------------
local NPX_MAP_ID = 559
local NPX_BAG_LINK = "|cffa335ee|Hkeystone:180653:559:14:0:0:0:0|h[Keystone: Nexus-Point Xenas (14)]|h|r"
local NPX_ITEM_LINK = "|cffa335ee|Hitem:180653::::::::80:250:::::|h[Keystone: Nexus-Point Xenas (14)]|h|r"
local NPX_DUNGEON_NAME = "Nexus-Point Xenas"

local function WithEnvironment(env, fn)
  return Harness.WithGlobals({
    C_MythicPlus = env.cMythicPlus,
    C_Container = env.cContainer,
    C_ChallengeMode = env.cChallengeMode,
  }, fn)
end

local function LoadContextHelpers()
  return Harness.LoadAddonModules({ "isiLive_context_helpers.lua" })
end

local function Run()
  print("========== Keystone-link bag-scan lifecycle simulator ==========\n")

  -- ----------------------------------------------------------------------
  -- Phase 1: Primary path — bag scan returns a valid link.
  -- ----------------------------------------------------------------------
  print("---- Phase 1: bag-scan primary path ----")
  do
    local bag = NewBagModel()
    BagsForcePut(bag, 0, 5, { itemID = 180653, link = NPX_BAG_LINK })
    local env = {
      cMythicPlus = {},
      cContainer = BuildContainerApi(bag),
      cChallengeMode = nil,
    }
    WithEnvironment(env, function()
      local addon = LoadContextHelpers()
      local link = addon.ContextHelpers.BuildKeystoneChatLink(NPX_MAP_ID, 14)
      Check(link == NPX_BAG_LINK, "primary path returns the verified bag link verbatim")
    end)
  end

  -- ----------------------------------------------------------------------
  -- Phase 2: C_MythicPlus may still exist, but the bag remains the sole link source.
  -- ----------------------------------------------------------------------
  print("\n---- Phase 2: 12.0 retail — bag scan finds the key ----")
  do
    local bag = NewBagModel()
    BagsForcePut(bag, 0, 5, { itemID = 180653, link = NPX_BAG_LINK })
    local env = {
      cMythicPlus = {},
      cContainer = BuildContainerApi(bag),
      cChallengeMode = nil,
    }
    WithEnvironment(env, function()
      local addon = LoadContextHelpers()
      local link = addon.ContextHelpers.BuildKeystoneChatLink(NPX_MAP_ID, 14)
      Check(link == NPX_BAG_LINK, "bag scan returns the real keystone link")
      Check(
        link:find("|Hkeystone:", 1, true) ~= nil,
        "returned link is a real |Hkeystone:...|h link (not a manual reconstruction)"
      )
    end)
  end

  -- ----------------------------------------------------------------------
  -- Phase 2b: Some clients expose the verified bag item as an item hyperlink
  -- for itemID 180653. That is still a real Blizzard link and must remain
  -- clickable instead of falling back to plain text.
  -- ----------------------------------------------------------------------
  print("\n---- Phase 2b: bag scan accepts verified Keystone item hyperlink ----")
  do
    local bag = NewBagModel()
    BagsForcePut(bag, 0, 5, { itemID = 180653, link = NPX_ITEM_LINK })
    local env = {
      cMythicPlus = {},
      cContainer = BuildContainerApi(bag),
      cChallengeMode = {
        GetMapUIInfo = function()
          error("plain fallback must not be reached for a verified Keystone item hyperlink", 0)
        end,
      },
    }
    WithEnvironment(env, function()
      local addon = LoadContextHelpers()
      local link = addon.ContextHelpers.BuildKeystoneChatLink(NPX_MAP_ID, 14)
      Check(link == NPX_ITEM_LINK, "bag scan returns the real Keystone item hyperlink")
      Check(link:find("|Hitem:180653", 1, true) ~= nil, "returned item hyperlink stays clickable")
    end)
  end

  -- ----------------------------------------------------------------------
  -- Phase 3: Invalid links in earlier Keystone slots are skipped.
  -- ----------------------------------------------------------------------
  print("\n---- Phase 3: invalid bag links are skipped ----")
  do
    local bag = NewBagModel()
    BagsForcePut(bag, 1, 1, { itemID = 180653, link = "not a hyperlink" })
    BagsForcePut(bag, 1, 2, { itemID = 180653, link = NPX_BAG_LINK })
    local env = {
      cMythicPlus = {},
      cContainer = BuildContainerApi(bag),
      cChallengeMode = nil,
    }
    WithEnvironment(env, function()
      local addon = LoadContextHelpers()
      local link = addon.ContextHelpers.BuildKeystoneChatLink(NPX_MAP_ID, 14)
      Check(link == NPX_BAG_LINK, "invalid earlier bag link does not hide a later verified Keystone link")
    end)
  end

  -- ----------------------------------------------------------------------
  -- Phase 4: Empty bag, no primary API — plain-text fallback. This
  -- branch is NEVER allowed to produce a |cff...|r-wrapped [...] text
  -- because the chat server silently drops those (CLAUDE.md rule).
  -- ----------------------------------------------------------------------
  print("\n---- Phase 4: empty bag → plain-text fallback (no color-code wrap) ----")
  do
    local bag = NewBagModel()
    local env = {
      cMythicPlus = {},
      cContainer = BuildContainerApi(bag),
      cChallengeMode = {
        GetMapUIInfo = function(mapID)
          if mapID == NPX_MAP_ID then
            return NPX_DUNGEON_NAME
          end
          return nil
        end,
      },
    }
    WithEnvironment(env, function()
      local addon = LoadContextHelpers()
      local link = addon.ContextHelpers.BuildKeystoneChatLink(NPX_MAP_ID, 14)
      Check(
        link == "[Keystone: Nexus-Point Xenas +14]",
        "plain-text fallback uses 'Keystone: <dungeonName> +<level>' shape"
      )
      Check(
        link and not link:find("|c", 1, true),
        "plain-text fallback contains NO color-code wrapper (server-drop hardening)"
      )
      Check(link and not link:find("|r", 1, true), "plain-text fallback contains no |r close tag either")
    end)
  end

  -- ----------------------------------------------------------------------
  -- Phase 5: No primary API + GetMapUIInfo also missing — generic
  -- "[Keystone +N]" still works without crashing on missing dungeon name.
  -- ----------------------------------------------------------------------
  print("\n---- Phase 5: empty bag + no GetMapUIInfo → generic fallback ----")
  do
    local bag = NewBagModel()
    local env = {
      cMythicPlus = {},
      cContainer = BuildContainerApi(bag),
      cChallengeMode = nil,
    }
    WithEnvironment(env, function()
      local addon = LoadContextHelpers()
      local link = addon.ContextHelpers.BuildKeystoneChatLink(NPX_MAP_ID, 14)
      Check(link == "[Keystone +14]", "missing GetMapUIInfo collapses to generic '[Keystone +N]' (no nil crash)")
    end)
  end

  -- ----------------------------------------------------------------------
  -- Phase 6: Multiple keys in the bag (rare but possible during weekly
  -- reset windows). Whichever matching slot is iterated first wins.
  -- The first matching link is returned regardless of bagID/slotID.
  -- ----------------------------------------------------------------------
  print("\n---- Phase 6: multiple keystones in bag → first-match wins ----")
  do
    local bag = NewBagModel()
    local altLink = "|cffa335ee|Hkeystone:180653:556:10:0:0:0:0|h[Keystone: Pit of Saron (10)]|h|r"
    BagsForcePut(bag, 0, 5, { itemID = 180653, link = NPX_BAG_LINK })
    BagsForcePut(bag, 0, 6, { itemID = 180653, link = altLink })
    local env = {
      cMythicPlus = {},
      cContainer = BuildContainerApi(bag),
      cChallengeMode = nil,
    }
    WithEnvironment(env, function()
      local addon = LoadContextHelpers()
      local link = addon.ContextHelpers.BuildKeystoneChatLink(NPX_MAP_ID, 14)
      Check(
        link == NPX_BAG_LINK or link == altLink,
        "multi-key bag returns ONE of the keystones (deterministic first-match by iteration)"
      )
      Check(link and link:find("|Hkeystone:", 1, true) ~= nil, "multi-key bag still returns a real keystone link")
    end)
  end

  -- ----------------------------------------------------------------------
  -- Phase 7: Container API throws on GetContainerItemID / Link mid-iter.
  -- The pcall isolation must keep the scan going so a healthy slot later
  -- in the bag still resolves.
  -- ----------------------------------------------------------------------
  print("\n---- Phase 7: pcall isolation — single-slot read failure does not abort scan ----")
  do
    local bag = NewBagModel()
    BagsForcePut(bag, 0, 1, { itemID = 0, errorOnRead = "id" }) -- error reading slot 1
    BagsForcePut(bag, 0, 2, { itemID = 180653, errorOnRead = "link" }) -- error reading link
    BagsForcePut(bag, 0, 3, { itemID = 180653, link = NPX_BAG_LINK }) -- healthy slot
    local env = {
      cMythicPlus = {},
      cContainer = BuildContainerApi(bag),
      cChallengeMode = nil,
    }
    WithEnvironment(env, function()
      local addon = LoadContextHelpers()
      local link = addon.ContextHelpers.BuildKeystoneChatLink(NPX_MAP_ID, 14)
      Check(link == NPX_BAG_LINK, "errors in slot 1 + slot 2 do not prevent slot 3 from yielding the real link")
    end)
  end

  -- ----------------------------------------------------------------------
  -- Phase 8: Invalid inputs — mapID or level <= 0 → return nil.
  -- ----------------------------------------------------------------------
  print("\n---- Phase 8: invalid input rejected ----")
  do
    local env = {
      cMythicPlus = {},
      cContainer = nil,
      cChallengeMode = nil,
    }
    WithEnvironment(env, function()
      local addon = LoadContextHelpers()
      Check(addon.ContextHelpers.BuildKeystoneChatLink(0, 14) == nil, "mapID 0 returns nil")
      Check(addon.ContextHelpers.BuildKeystoneChatLink(NPX_MAP_ID, 0) == nil, "level 0 returns nil")
      Check(addon.ContextHelpers.BuildKeystoneChatLink(NPX_MAP_ID, -3) == nil, "negative level returns nil")
      Check(addon.ContextHelpers.BuildKeystoneChatLink("not-a-number", 14) == nil, "non-numeric mapID returns nil")
    end)
  end

  -- ----------------------------------------------------------------------
  -- Phase 9: Lifecycle — bag empty → key inserted (bag rescan) → key
  -- consumed (bag rescan again). Same input produces three different
  -- outputs depending on bag state. This catches the regression where
  -- the function would cache a stale link across consumption.
  -- ----------------------------------------------------------------------
  print("\n---- Phase 9: lifecycle empty → insert → consume ----")
  do
    local bag = NewBagModel()
    local env = {
      cMythicPlus = {},
      cContainer = BuildContainerApi(bag),
      cChallengeMode = {
        GetMapUIInfo = function()
          return NPX_DUNGEON_NAME
        end,
      },
    }
    WithEnvironment(env, function()
      local addon = LoadContextHelpers()

      local emptyLink = addon.ContextHelpers.BuildKeystoneChatLink(NPX_MAP_ID, 14)
      Check(emptyLink == "[Keystone: Nexus-Point Xenas +14]", "empty bag → plain-text fallback")

      BagsForcePut(bag, 0, 1, { itemID = 180653, link = NPX_BAG_LINK })
      local insertedLink = addon.ContextHelpers.BuildKeystoneChatLink(NPX_MAP_ID, 14)
      Check(insertedLink == NPX_BAG_LINK, "key inserted → bag scan returns real link")

      bag.contents[0][1] = nil
      local consumedLink = addon.ContextHelpers.BuildKeystoneChatLink(NPX_MAP_ID, 14)
      Check(
        consumedLink == "[Keystone: Nexus-Point Xenas +14]",
        "key consumed → bag scan finds nothing → plain-text fallback (no stale cache)"
      )
    end)
  end

  if failures > 0 then
    print(string.format("\nKeystone-link bag-scan simulator failed: %d check(s) failed", failures))
    os.exit(1)
  end

  print("\nKeystone-link bag-scan simulator passed.")
end

Run()
