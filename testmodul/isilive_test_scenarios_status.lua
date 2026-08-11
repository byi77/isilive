local function BuildLocale()
  return {
    DUNGEON_DIFF_OUTSIDE = "Outside",
    DUNGEON_DIFF_UNKNOWN = "Unknown",
    DUNGEON_DIFF_NORMAL = "Normal",
    DUNGEON_DIFF_HEROIC = "Heroic",
    DUNGEON_DIFF_TIMEWALKING = "Timewalking",
    DUNGEON_DIFF_MYTHIC = "Mythic",
    DUNGEON_DIFF_RAID_LFR = "LFR",
    DUNGEON_DIFF_RAID_NORMAL = "Normal Raid",
    DUNGEON_DIFF_RAID_HEROIC = "Heroic Raid",
    DUNGEON_DIFF_RAID_MYTHIC = "Mythic Raid",
    DUNGEON_DIFF_RAID_UNKNOWN = "Raid",
    NON_MYTHIC_ENTERED = "Warning: Entered non-Mythic dungeon (%s).",
    NON_MYTHIC_NOTICE_DUNGEON_EYEBROW = "Dungeon",
    NON_MYTHIC_NOTICE_RAID_EYEBROW = "Raid",
    NON_MYTHIC_NOTICE_DUNGEON_TITLE = "isiLive - Dungeon entered",
    NON_MYTHIC_NOTICE_RAID_TITLE = "isiLive - Raid entered",
    NON_MYTHIC_NOTICE_LABEL_DUNGEON = "Dungeon:",
    NON_MYTHIC_NOTICE_LABEL_RAID = "Raid:",
    NON_MYTHIC_NOTICE_LABEL_DIFFICULTY = "Difficulty:",
    NON_MYTHIC_NOTICE_LABEL_HINT = "Hint:",
    NON_MYTHIC_NOTICE_LABEL_SOURCE = "Source:",
    NON_MYTHIC_NOTICE_HINT_NON_MYTHIC = "Not a Mythic+ dungeon",
    NON_MYTHIC_NOTICE_SOURCE_INSTANCE_ENTERED = "Instance entered",
    RAID_ENTERED = "Entered raid: %s",
    PORTAL_NAVIGATOR_TITLE = "isiLive - Midnight Season One M+ Navigator",
    PORTAL_NAVIGATOR_EYEBROW = "Portal - Navigation",
    PORTAL_NAVIGATOR_HALF_LEFT = "Half left",
    PORTAL_NAVIGATOR_LEFT = "Left",
    PORTAL_NAVIGATOR_RIGHT = "Right",
    PORTAL_NAVIGATOR_HALF_RIGHT = "Half right",
    PORTAL_NAVIGATOR_CENTER = "Straight ahead",
    PORTAL_NAVIGATOR_SKYREACH = "Skyreach",
    PORTAL_NAVIGATOR_TRIUMVIRATE = "Seat of the Triumvirate",
    PORTAL_NAVIGATOR_PIT_OF_SARON = "Pit of Saron",
    PORTAL_NAVIGATOR_ALGETHAR = "Algeth'ar Academy",
    PORTAL_NAVIGATOR_HEAVEN = "Heaven",
    PORTAL_NAVIGATOR_UNOCCUPIED = "Unoccupied",
    PORTAL_NAVIGATOR_TEXT = "isiLive - Portal Navigator\n"
      .. "Left: Skyreach\n"
      .. "Right: Seat of the Triumvirate\n"
      .. "Half left: Pit of Saron\n"
      .. "Half right: Algeth'ar Academy",
    STATUS_LEAD_YES = "Lead: Yes",
    STATUS_LEAD_NO = "Lead: No",
    STATUS_MPLUS_YES = "M+: Active",
    STATUS_MPLUS_NO = "M+: Inactive",
    STATUS_TARGET_DUNGEON_TEXT = "Target Dungeon: %s",
    STATUS_TARGET_DUNGEON_NONE = "Target Dungeon: -",
    STATUS_TARGET_DUNGEON_PRESEASON = "Target Dungeon: Pre-Season (%s)",
    STATUS_STATE_RUNNING = "State: Running",
    STATUS_STATE_PAUSED = "State: Paused",
    STATUS_STATE_STOPPED = "State: Stopped",
    STATUS_STATE_TEST = "State: Test Mode",
    DUNGEON_DIFF_TEXT = "Dungeon: %s",
  }
end

local function RegisterDungeonDifficultyTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Status rejects secret instance metadata", function()
    local secret = {}
    WithGlobals({
      GetInstanceInfo = function()
        return "Secret Dungeon", secret, 8, "Mythic", 5, nil, nil, 777, 12345
      end,
      issecretvalue = function(value)
        return value == secret
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
      })

      local label, isMythic, inDungeon, instanceType, difficultyID, instanceName =
        controller.GetDungeonDifficultyLabel()
      Assert.Equal(label, "Unknown", "secret instance metadata must render as unknown")
      Assert.False(isMythic, "secret instance metadata must not enable Mythic mode")
      Assert.False(inDungeon, "secret instance metadata must not establish dungeon context")
      Assert.Nil(instanceType, "secret instance type must remain unresolved")
      Assert.Nil(difficultyID, "secret difficulty ID must remain unresolved")
      Assert.Nil(instanceName, "secret instance name must remain unresolved")
    end)
  end)

  test("Status labels timewalking dungeons as timewalking and not as mythic", function()
    -- difficultyID 24 is Timewalking. It used to sit in the mythic table, which
    -- printed "Mythic" next to "M+: Inactive" in the status line and suppressed
    -- the dungeon-entry notice, because that notice skips party dungeons
    -- reported as mythic.
    WithGlobals({
      GetInstanceInfo = function()
        return "Pit of Saron", "party", 24, "Timewalking"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
      })

      local label, isMythic, inDungeon = controller.GetDungeonDifficultyLabel()
      Assert.Equal(label, "Timewalking", "difficulty 24 must resolve as timewalking")
      Assert.False(isMythic, "timewalking must not be reported as mythic")
      Assert.True(inDungeon, "timewalking must be treated as dungeon context")
    end)
  end)

  test("Status maps heroic fallback difficulty IDs as non-mythic heroic", function()
    local current = {
      instanceName = "Priory of the Sacred Flame",
      instanceType = "party",
      difficultyID = 174,
    }

    WithGlobals({
      GetInstanceInfo = function()
        return current.instanceName, current.instanceType, current.difficultyID, "Heroic"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
      })

      local label, isMythic, inDungeon = controller.GetDungeonDifficultyLabel()
      Assert.Equal(label, "Heroic", "difficulty 174 should resolve as heroic")
      Assert.False(isMythic, "heroic fallback difficulty must not be mythic")
      Assert.True(inDungeon, "heroic fallback difficulty must be treated as dungeon context")
    end)
  end)

  test("Status warns when switching from normal to heroic without leaving dungeon context", function()
    local notices = {}
    local current = {
      instanceName = "Priory of the Sacred Flame",
      instanceType = "none",
      difficultyID = 0,
    }

    WithGlobals({
      GetInstanceInfo = function()
        return current.instanceName, current.instanceType, current.difficultyID, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
      C_Timer = {
        After = function(_delay, fn)
          fn()
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        showCenterNotice = function(message, duration, _dungeonName, _activityID, _showOptions)
          table.insert(notices, { message = message, duration = duration })
        end,
        hideCenterNotice = function() end,
      })

      controller.MaybeShowNonMythicDungeonEntryNotice()

      current.instanceType = "party"
      current.difficultyID = 1
      controller.MaybeShowNonMythicDungeonEntryNotice()
      Assert.Equal(#notices, 1, "normal dungeon entry should show non-mythic notice")
      Assert.True(
        string.find(notices[1].message, "Normal", 1, true) ~= nil,
        "normal notice should include normal difficulty label"
      )

      current.difficultyID = 2
      controller.MaybeShowNonMythicDungeonEntryNotice()
      Assert.Equal(#notices, 2, "normal -> heroic switch should show another non-mythic notice")
      Assert.True(
        string.find(notices[2].message, "Heroic", 1, true) ~= nil,
        "heroic notice should include heroic difficulty label"
      )

      controller.MaybeShowNonMythicDungeonEntryNotice()
      Assert.Equal(#notices, 2, "repeated heroic refresh should not re-show same notice")
    end)
  end)

  -- BUG-CENTERNOTICE-FLICKER: MaybeShowNonMythicDungeonEntryNotice used to
  -- call deps.hideCenterNotice() unconditionally whenever the player was
  -- outside a dungeon. The shared center-notice frame is also used by the
  -- Accepted-Invite / Lead-Transfer / Test-Mode paths, so every
  -- INSTANCE_CONTEXT_CHANGED event a second after accepting an LFG invite
  -- closed the Accepted-Invite notice after roughly one second of visibility.
  -- The fix gates the hide call behind a controller-owned tracking flag.
  test("Status MaybeShowNonMythicDungeonEntryNotice must NOT hide notices it does not own", function()
    local hideCallCount = 0
    local current = {
      instanceName = "Stormwind",
      instanceType = "none",
      difficultyID = 0,
    }
    WithGlobals({
      GetInstanceInfo = function()
        return current.instanceName, current.instanceType, current.difficultyID, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
      C_Timer = {
        After = function(_delay, fn)
          fn()
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        showCenterNotice = function() end,
        hideCenterNotice = function()
          hideCallCount = hideCallCount + 1
        end,
      })

      -- First call seeds wasInDungeon=false (no notice ever shown). Second
      -- call confirms the leave-path no longer fires hide while the
      -- controller doesn't own the current notice content.
      controller.MaybeShowNonMythicDungeonEntryNotice()
      controller.MaybeShowNonMythicDungeonEntryNotice()
      Assert.Equal(hideCallCount, 0, "hideCenterNotice must not fire when this controller never showed a notice")
    end)
  end)

  test("Status MaybeShowNonMythicDungeonEntryNotice still hides its OWN notice on dungeon leave", function()
    local hideCallCount = 0
    local notices = {}
    local current = {
      instanceName = "Stormwind",
      instanceType = "none",
      difficultyID = 0,
    }
    WithGlobals({
      GetInstanceInfo = function()
        return current.instanceName, current.instanceType, current.difficultyID, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
      C_Timer = {
        After = function(_delay, fn)
          fn()
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        showCenterNotice = function(message, duration)
          notices[#notices + 1] = { message = message, duration = duration }
        end,
        hideCenterNotice = function()
          hideCallCount = hideCallCount + 1
        end,
      })

      -- Seed the previous-state once outside any dungeon.
      controller.MaybeShowNonMythicDungeonEntryNotice()

      -- Enter a normal dungeon -> controller shows its own non-mythic notice.
      current.instanceType = "party"
      current.difficultyID = 1
      controller.MaybeShowNonMythicDungeonEntryNotice()
      Assert.Equal(#notices, 1, "entering a non-mythic dungeon must show the warning")
      Assert.Equal(hideCallCount, 0, "no hide call during the show phase")

      -- Leave the dungeon -> THIS time the hide call IS expected because the
      -- controller still owns the visible notice.
      current.instanceType = "none"
      current.difficultyID = 0
      controller.MaybeShowNonMythicDungeonEntryNotice()
      Assert.Equal(hideCallCount, 1, "leaving the dungeon must hide the controller's own notice once")

      -- Further leave-state ticks must be no-ops (flag was reset).
      controller.MaybeShowNonMythicDungeonEntryNotice()
      Assert.Equal(hideCallCount, 1, "subsequent ticks outside the dungeon must not re-fire hide")
    end)
  end)

  -- Raid Center Notice support (0.9.237). GetDungeonDifficultyLabel must
  -- recognise the four current Blizzard raid difficulties (LFR 17, Normal 14,
  -- Heroic 15, Mythic 16) and return inDungeon=true so the entry-notice flow
  -- treats raid like a dungeon for enter/leave bookkeeping. isMythic stays
  -- false for all four because the suppress rule in MaybeShowNonMythic-
  -- DungeonEntryNotice is "M+ keystone in party dungeon" only — every raid
  -- difficulty INCLUDING Mythic Raid must surface its label.
  test("Status GetDungeonDifficultyLabel returns localized raid labels for difficulties 14/15/16/17", function()
    local raidCases = {
      { difficultyID = 14, expected = "Normal Raid" },
      { difficultyID = 15, expected = "Heroic Raid" },
      { difficultyID = 16, expected = "Mythic Raid" },
      { difficultyID = 17, expected = "LFR" },
    }

    for _, case in ipairs(raidCases) do
      WithGlobals({
        GetInstanceInfo = function()
          return "Manaforge Omega", "raid", case.difficultyID, "Heroic"
        end,
        C_ChallengeMode = {
          GetActiveChallengeMapID = function()
            return nil
          end,
        },
      }, function()
        local addon = LoadAddonModules({ "isiLive_status.lua" })
        local controller = addon.Status.CreateController({
          getL = BuildLocale,
        })
        local label, isMythic, inDungeon, instanceType = controller.GetDungeonDifficultyLabel()
        Assert.Equal(label, case.expected, "raid difficulty " .. case.difficultyID .. " must map to " .. case.expected)
        Assert.False(isMythic, "raid difficulties must report isMythic=false so the suppress rule does not kick in")
        Assert.True(inDungeon, "raid must report inDungeon=true so enter/leave bookkeeping fires")
        Assert.Equal(instanceType, "raid", "instanceType must be propagated as 'raid'")
      end)
    end
  end)

  test("Status GetDungeonDifficultyLabel falls back to DUNGEON_DIFF_RAID_UNKNOWN for unmapped raid IDs", function()
    WithGlobals({
      GetInstanceInfo = function()
        return "Legacy Raid", "raid", 9, "40-Player"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
      })
      local label, isMythic, inDungeon = controller.GetDungeonDifficultyLabel()
      Assert.Equal(label, "Raid", "unmapped raid difficulty must fall back to DUNGEON_DIFF_RAID_UNKNOWN")
      Assert.False(isMythic, "unmapped raid still reports isMythic=false")
      Assert.True(inDungeon, "unmapped raid still reports inDungeon=true so leave-bookkeeping works")
    end)
  end)

  test("Status MaybeShowNonMythicDungeonEntryNotice fires for every raid difficulty with the raid template", function()
    local raidCases = {
      { difficultyID = 17, expectedDifficulty = "LFR" },
      { difficultyID = 14, expectedDifficulty = "Normal Raid" },
      { difficultyID = 15, expectedDifficulty = "Heroic Raid" },
      { difficultyID = 16, expectedDifficulty = "Mythic Raid" },
    }

    for _, case in ipairs(raidCases) do
      local notices = {}
      local current = {
        instanceName = "Manaforge Omega",
        instanceType = "none",
        difficultyID = 0,
      }
      WithGlobals({
        GetInstanceInfo = function()
          return current.instanceName, current.instanceType, current.difficultyID, "Outside"
        end,
        C_ChallengeMode = {
          GetActiveChallengeMapID = function()
            return nil
          end,
        },
        C_Timer = {
          After = function(_delay, fn)
            fn()
          end,
        },
      }, function()
        local addon = LoadAddonModules({ "isiLive_status.lua" })
        local controller = addon.Status.CreateController({
          getL = BuildLocale,
          showCenterNotice = function(message, duration, _dungeonName, _activityID, showOptions)
            table.insert(notices, { message = message, duration = duration, showOptions = showOptions })
          end,
          hideCenterNotice = function() end,
        })

        -- Seed wasInDungeon=false on the first sample so the second call
        -- represents an actual transition into the raid.
        controller.MaybeShowNonMythicDungeonEntryNotice()
        current.instanceType = "raid"
        current.difficultyID = case.difficultyID
        controller.MaybeShowNonMythicDungeonEntryNotice()

        Assert.Equal(#notices, 1, "raid entry must produce exactly one notice for difficulty " .. case.difficultyID)
        Assert.Equal(
          notices[1].message,
          "Entered raid: " .. case.expectedDifficulty,
          "raid notice must use the RAID_ENTERED template with the localized difficulty label"
        )
        Assert.Nil(
          notices[1].showOptions and notices[1].showOptions.textColor,
          "raid entry notice must NOT apply the red warning color used for non-mythic dungeons"
        )
        Assert.Equal(
          notices[1].showOptions and notices[1].showOptions.title,
          "isiLive - Raid entered",
          "raid entry notice must use the modern rich title"
        )
        Assert.Equal(
          notices[1].showOptions and notices[1].showOptions.fields and notices[1].showOptions.fields[1].value,
          "Manaforge Omega",
          "raid entry notice must render the verified instance name"
        )
        Assert.Equal(
          notices[1].showOptions and notices[1].showOptions.fields and notices[1].showOptions.fields[2].value,
          case.expectedDifficulty,
          "raid entry notice must render the difficulty row"
        )
      end)
    end
  end)

  test("Status MaybeShowNonMythicDungeonEntryNotice still suppresses M+ keystone entries", function()
    local notices = {}
    local current = {
      instanceName = "Manaforge Omega",
      instanceType = "none",
      difficultyID = 0,
      challengeMapID = nil,
    }
    WithGlobals({
      GetInstanceInfo = function()
        return current.instanceName, current.instanceType, current.difficultyID, "Outside"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return current.challengeMapID
        end,
      },
      C_Timer = {
        After = function(_delay, fn)
          fn()
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        showCenterNotice = function(message)
          table.insert(notices, message)
        end,
        hideCenterNotice = function() end,
      })

      controller.MaybeShowNonMythicDungeonEntryNotice()
      -- Enter an active M+ keystone: party + ChallengeMode reports a mapID.
      current.instanceType = "party"
      current.difficultyID = 8
      current.challengeMapID = 402
      controller.MaybeShowNonMythicDungeonEntryNotice()

      Assert.Equal(#notices, 0, "M+ keystone entries must stay silent — the addon's main UI already surfaces them")
    end)
  end)

  test("Status MaybeShowNonMythicDungeonEntryNotice renders rich notice on non-mythic party dungeon", function()
    local notices = {}
    local current = {
      instanceName = "Priory of the Sacred Flame",
      instanceType = "none",
      difficultyID = 0,
    }
    WithGlobals({
      GetInstanceInfo = function()
        return current.instanceName, current.instanceType, current.difficultyID, "Outside"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
      C_Timer = {
        After = function(_delay, fn)
          fn()
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        showCenterNotice = function(message, _duration, _dungeon, _activity, showOptions)
          table.insert(notices, { message = message, showOptions = showOptions })
        end,
        hideCenterNotice = function() end,
      })

      controller.MaybeShowNonMythicDungeonEntryNotice()
      current.instanceType = "party"
      current.difficultyID = 1
      controller.MaybeShowNonMythicDungeonEntryNotice()

      Assert.Equal(#notices, 1, "non-mythic party dungeon entry still produces the warning notice")
      Assert.True(
        string.find(notices[1].message, "Warning", 1, true) ~= nil,
        "legacy message payload still keeps the warning prefix for compatibility"
      )
      Assert.Equal(
        notices[1].showOptions and notices[1].showOptions.title,
        "isiLive - Dungeon entered",
        "non-mythic dungeon notice must use the modern rich title"
      )
      Assert.Equal(
        notices[1].showOptions and notices[1].showOptions.eyebrow,
        "Dungeon",
        "non-mythic dungeon notice must use the dungeon eyebrow"
      )
      Assert.Nil(
        notices[1].showOptions and notices[1].showOptions.textColor,
        "non-mythic dungeon notice no longer uses the red legacy text accent"
      )
      Assert.Equal(
        notices[1].showOptions and notices[1].showOptions.fields and notices[1].showOptions.fields[1].value,
        "Priory of the Sacred Flame",
        "non-mythic dungeon notice must render the verified instance name"
      )
      Assert.Equal(
        notices[1].showOptions and notices[1].showOptions.fields and notices[1].showOptions.fields[2].value,
        "Normal",
        "non-mythic dungeon notice must render the difficulty row"
      )
      Assert.Equal(
        notices[1].showOptions and notices[1].showOptions.fields and notices[1].showOptions.fields[3].value,
        "Not a Mythic+ dungeon",
        "non-mythic dungeon notice must render the non-mythic hint"
      )
      Assert.True(
        notices[1].showOptions and notices[1].showOptions.fields and notices[1].showOptions.fields[3].warning == true,
        "non-mythic dungeon notice hint must be marked as a warning row"
      )
      Assert.True(
        notices[1].showOptions and notices[1].showOptions.fields and notices[1].showOptions.fields[3].blink == true,
        "non-mythic dungeon notice hint must blink for emphasis"
      )
    end)
  end)
end

local function RegisterPortalNavigatorTests(test, Assert, WithGlobals, LoadAddonModules)
  local function AssertPortalNavigatorLayout(layout)
    Assert.Equal(type(layout), "table", "portal navigator should pass a structured layout table")
    Assert.Equal(layout.eyebrow, BuildLocale().PORTAL_NAVIGATOR_EYEBROW, "portal navigator should expose the eyebrow")
    Assert.Equal(layout.title, BuildLocale().PORTAL_NAVIGATOR_TITLE, "portal navigator should expose the title")
    Assert.Equal(type(layout.entries), "table", "portal navigator should expose entry widgets")
    Assert.Equal(#layout.entries, 5, "portal navigator should expose five portal positions")

    Assert.Equal(layout.entries[1].slot, "left", "first portal entry should be left")
    Assert.Equal(layout.entries[1].direction, BuildLocale().PORTAL_NAVIGATOR_LEFT, "left entry should use left label")
    Assert.Equal(
      layout.entries[1].destination,
      BuildLocale().PORTAL_NAVIGATOR_SKYREACH,
      "left entry should point to Skyreach"
    )
    Assert.Equal(layout.entries[1].mapID, 161, "left entry should carry the Skyreach map id")

    Assert.Equal(layout.entries[2].slot, "half_left", "second portal entry should be half left")
    Assert.Equal(
      layout.entries[2].direction,
      BuildLocale().PORTAL_NAVIGATOR_HALF_LEFT,
      "half left entry should use the localized direction label"
    )
    Assert.Equal(
      layout.entries[2].destination,
      BuildLocale().PORTAL_NAVIGATOR_PIT_OF_SARON,
      "half left entry should point to Pit of Saron"
    )
    Assert.Equal(layout.entries[2].mapID, 556, "half-left entry should carry the Pit of Saron map id")

    Assert.Equal(layout.entries[3].slot, "center", "third portal entry should be center")
    Assert.Equal(
      layout.entries[3].direction,
      BuildLocale().PORTAL_NAVIGATOR_CENTER,
      "center entry should use straight-ahead label"
    )
    Assert.Equal(
      layout.entries[3].destination,
      BuildLocale().PORTAL_NAVIGATOR_HEAVEN,
      "center entry should show the configured Heaven placeholder"
    )
    Assert.Equal(
      layout.entries[3].detail,
      BuildLocale().PORTAL_NAVIGATOR_UNOCCUPIED,
      "center entry should mark the portal as unoccupied"
    )
    Assert.True(layout.entries[3].isEmpty, "center entry should be flagged as empty for muted rendering")
    Assert.Nil(layout.entries[3].mapID, "center placeholder should not carry a dungeon map id")

    Assert.Equal(layout.entries[4].slot, "half_right", "fourth portal entry should be half right")
    Assert.Equal(
      layout.entries[4].direction,
      BuildLocale().PORTAL_NAVIGATOR_HALF_RIGHT,
      "half right entry should use the localized direction label"
    )
    Assert.Equal(
      layout.entries[4].destination,
      BuildLocale().PORTAL_NAVIGATOR_ALGETHAR,
      "half right entry should point to Algeth'ar Academy"
    )
    Assert.Equal(layout.entries[4].mapID, 402, "half-right entry should carry the Algeth'ar Academy map id")

    Assert.Equal(layout.entries[5].slot, "right", "fifth portal entry should be right")
    Assert.Equal(
      layout.entries[5].direction,
      BuildLocale().PORTAL_NAVIGATOR_RIGHT,
      "right entry should use right label"
    )
    Assert.Equal(
      layout.entries[5].destination,
      BuildLocale().PORTAL_NAVIGATOR_TRIUMVIRATE,
      "right entry should point to Seat of the Triumvirate"
    )
    Assert.Equal(layout.entries[5].mapID, 239, "right entry should carry the Seat of the Triumvirate map id")
  end

  test("Portal navigator shows the five portal positions only in the Timeways room", function()
    local current = {
      zoneText = nil,
      subZoneText = nil,
      playerMapID = 100,
      mapNames = {
        [100] = "Valdrakken",
        [2266] = "Jahrhunderschwelle",
      },
    }
    local notices = {}
    local hides = 0

    WithGlobals({
      UnitExists = function(unit)
        return unit == "player"
      end,
      GetZoneText = function()
        return current.zoneText
      end,
      GetSubZoneText = function()
        return current.subZoneText
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return current.playerMapID
          end
          return nil
        end,
        GetMapInfo = function(mapID)
          local name = current.mapNames[mapID]
          if type(name) ~= "string" then
            return nil
          end
          return { name = name }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        showPortalNavigatorNotice = function(layout)
          table.insert(notices, layout)
        end,
        hidePortalNavigatorNotice = function()
          hides = hides + 1
        end,
      })

      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(#notices, 0, "outdoor zone must not show the portal navigator")
      Assert.Equal(hides, 0, "outdoor zone must not hide the portal navigator before it was shown")

      current.zoneText = "Jahrhunderschwelle"
      current.playerMapID = 2266
      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(#notices, 1, "portal room should show the navigator exactly once")
      AssertPortalNavigatorLayout(notices[1])

      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(#notices, 1, "same portal room should not re-show the navigator")

      current.zoneText = nil
      current.subZoneText = nil
      current.playerMapID = 100
      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(hides, 1, "leaving the portal room should hide the portal navigator")
    end)
  end)

  test("Portal navigator attaches verified teleport icons from map lookup", function()
    local notices = {}

    WithGlobals({
      GetZoneText = function()
        return "Jahrhunderschwelle"
      end,
      GetSubZoneText = function()
        return nil
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return 2266
          end
          return nil
        end,
        GetMapInfo = function(mapID)
          if mapID == 2266 then
            return { name = "Jahrhunderschwelle" }
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        getTeleportInfoByMapID = function(mapID)
          return {
            mapID = mapID,
            spellID = mapID + 1000,
            icon = "icon-" .. tostring(mapID),
          }
        end,
        showPortalNavigatorNotice = function(layout)
          table.insert(notices, layout)
        end,
        hidePortalNavigatorNotice = function() end,
      })

      controller.MaybeShowPortalNavigatorNotice()

      Assert.Equal(#notices, 1, "portal room should show the navigator with teleport icon metadata")
      local entriesBySlot = {}
      for _, entry in ipairs(notices[1].entries or {}) do
        entriesBySlot[entry.slot] = entry
      end

      Assert.Equal(entriesBySlot.left.icon, "icon-161", "left portal should use the Skyreach teleport icon")
      Assert.Equal(entriesBySlot.left.spellID, 1161, "left portal should keep the verified Skyreach spell id")
      Assert.Equal(entriesBySlot.half_left.icon, "icon-556", "half-left portal should use the Pit of Saron icon")
      Assert.Equal(entriesBySlot.half_right.icon, "icon-402", "half-right portal should use the Algeth'ar icon")
      Assert.Equal(entriesBySlot.right.icon, "icon-239", "right portal should use the Seat of the Triumvirate icon")
      Assert.Nil(entriesBySlot.center.icon, "empty center portal should not synthesize an icon")
      Assert.Nil(entriesBySlot.center.spellID, "empty center portal should not synthesize a spell id")
    end)
  end)

  test("Portal navigator also detects the room from subzone text", function()
    local current = {
      subZoneText = nil,
      playerMapID = nil,
      mapNames = {},
    }
    local notices = {}

    WithGlobals({
      UnitExists = function(unit)
        return unit == "player"
      end,
      GetSubZoneText = function()
        return current.subZoneText
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return current.playerMapID
          end
          return nil
        end,
        GetMapInfo = function(mapID)
          local name = current.mapNames[mapID]
          if type(name) ~= "string" then
            return nil
          end
          return { name = name }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        showPortalNavigatorNotice = function(layout)
          table.insert(notices, layout)
        end,
      })

      current.subZoneText = "Timeways"
      controller.MaybeShowPortalNavigatorNotice()

      Assert.Equal(#notices, 1, "subzone text should also trigger the portal navigator")
      AssertPortalNavigatorLayout(notices[1])
    end)
  end)

  test("Portal navigator also detects the room from zone text", function()
    local current = {
      zoneText = nil,
      subZoneText = nil,
      playerMapID = nil,
      mapNames = {},
    }
    local notices = {}

    WithGlobals({
      GetZoneText = function()
        return current.zoneText
      end,
      GetSubZoneText = function()
        return current.subZoneText
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return current.playerMapID
          end
          return nil
        end,
        GetMapInfo = function(mapID)
          local name = current.mapNames[mapID]
          if type(name) ~= "string" then
            return nil
          end
          return { name = name }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        showPortalNavigatorNotice = function(layout)
          table.insert(notices, layout)
        end,
      })

      current.zoneText = "Jahrhunderschwelle"
      controller.MaybeShowPortalNavigatorNotice()

      Assert.Equal(#notices, 1, "zone text should also trigger the portal navigator")
      AssertPortalNavigatorLayout(notices[1])
    end)
  end)

  test("Portal navigator retries when the portal map resolves one tick later", function()
    local current = {
      subZoneText = nil,
      playerMapID = nil,
    }
    local notices = {}
    local scheduled = {}

    WithGlobals({
      UnitExists = function(unit)
        return unit == "player"
      end,
      GetSubZoneText = function()
        return current.subZoneText
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return current.playerMapID
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        showPortalNavigatorNotice = function(layout)
          table.insert(notices, layout)
        end,
        timerAfter = function(seconds, callback)
          table.insert(scheduled, { seconds = seconds, callback = callback })
        end,
      })

      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(#notices, 0, "missing zone data should not show the navigator immediately")
      Assert.Equal(#scheduled, 1, "missing zone data should schedule one retry")

      current.playerMapID = 2266
      scheduled[1].callback()

      Assert.Equal(#notices, 1, "retry should show the navigator once the portal map resolves")
      AssertPortalNavigatorLayout(notices[1])
    end)
  end)

  test("Portal navigator respects the settings toggle", function()
    local current = {
      zoneText = "Jahrhunderschwelle",
      playerMapID = 2266,
      enabled = false,
      mapNames = {
        [2266] = "Jahrhunderschwelle",
      },
    }
    local notices = {}
    local hides = 0

    WithGlobals({
      GetZoneText = function()
        return current.zoneText
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return current.playerMapID
          end
          return nil
        end,
        GetMapInfo = function(mapID)
          local name = current.mapNames[mapID]
          if type(name) ~= "string" then
            return nil
          end
          return { name = name }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        isPortalNavigatorEnabled = function()
          return current.enabled
        end,
        showPortalNavigatorNotice = function(layout)
          table.insert(notices, layout)
        end,
        hidePortalNavigatorNotice = function()
          hides = hides + 1
        end,
      })

      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(#notices, 0, "disabled portal navigator should stay hidden")
      Assert.Equal(hides, 0, "disabled portal navigator should not emit a hide event before showing")

      current.enabled = true
      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(#notices, 1, "enabled portal navigator should show in the portal room")
      AssertPortalNavigatorLayout(notices[1])

      current.enabled = false
      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(hides, 1, "disabling the portal navigator should hide the visible notice")
    end)
  end)

  -- 0.9.240: direct-push entry point for the LFG-accept trigger. Bypasses
  -- the resolver chain inside MaybeAnnounceTargetDungeonChat — name + level
  -- come straight from the listing payload (the same one the Center Notice
  -- rendered), so chat and notice always agree and no race-condition guard
  -- is needed. Sets the lock-in flag so the resolver-driven
  -- MaybeAnnounceTargetDungeonChat does not re-fire later.

  test("Status AnnounceTargetDungeonFromPayload emits the +N line and sets the lock-in", function()
    local prints = {}
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        isInGroup = function()
          return true
        end,
        printFn = function(message)
          table.insert(prints, tostring(message))
        end,
      })

      controller.AnnounceTargetDungeonFromPayload({ name = "Grube von Saron", level = 13 })
      Assert.Equal(#prints, 1, "direct-push payload emits exactly one announce")
      Assert.Equal(
        prints[1],
        "Target Dungeon: |cffffd200Grube von Saron +13|r",
        "direct-push announce carries the listing's +N exactly as supplied"
      )

      -- Lock-in: a subsequent resolver-driven MaybeAnnounceTargetDungeonChat
      -- with the same dungeon name must stay silent.
      controller.AnnounceTargetDungeonFromPayload({ name = "Grube von Saron", level = 13 })
      Assert.Equal(#prints, 1, "repeated direct-push for the same dungeon must stay silent (lock-in)")
    end)
  end)

  test("Status AnnounceTargetDungeonFromPayload bails out without emitting or locking when level is nil", function()
    -- Vorfall 2026-05-15: modern WoW (12.0+) encodes the listing title
    -- as opaque pipe markup "|Kk<id>|k". ParseTitleKeyLevel returns nil
    -- by design — the <id> is a client-side lookup, NOT the level. We
    -- explicitly REFUSE to emit a level-less direct-push: the user
    -- wants "Dungeon +N" only, never a level-less placeholder.
    -- Bailing out without setting levelAnnouncedTargetDungeonName lets
    -- the resolver-driven path (MaybeAnnounceTargetDungeonChat) supply
    -- +N later from the roster-owner key / synced target.
    local prints = {}
    local current = { targetInfo = { name = "Maisarakavernen", level = 13 } }
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        isInGroup = function()
          return true
        end,
        getTargetDungeonInfo = function()
          return current.targetInfo
        end,
        printFn = function(message)
          table.insert(prints, tostring(message))
        end,
      })

      controller.AnnounceTargetDungeonFromPayload({ name = "Maisarakavernen", level = nil })
      Assert.Equal(#prints, 0, "level-less direct-push must NOT emit a chat line")

      -- Resolver path runs later (e.g. via UpdateStatusLine after
      -- GROUP_ROSTER_UPDATE) with the roster-owner +N. Because the
      -- direct-push did not set the lock-in, the resolver is free to fire.
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 1, "resolver-driven announce takes over with the roster-owner level")
      Assert.Equal(
        prints[1],
        "Target Dungeon: |cffffd200Maisarakavernen +13|r",
        "chat line carries the resolver-supplied +N exactly — no descriptive title fragments"
      )
    end)
  end)

  test("Status AnnounceTargetDungeonFromPayload emits exact Blizzard keystone level markup", function()
    local prints = {}
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        isInGroup = function()
          return true
        end,
        getTargetDungeonInfo = function()
          return { name = "Die Himmelsnadel" }
        end,
        printFn = function(message)
          table.insert(prints, tostring(message))
        end,
      })

      controller.AnnounceTargetDungeonFromPayload({ name = "Die Himmelsnadel", levelText = "|Kk584|k" })

      Assert.Equal(#prints, 1, "exact Blizzard keystone markup must emit a direct-push chat line")
      Assert.Equal(
        prints[1],
        "Target Dungeon: |cffffd200Die Himmelsnadel |Kk584|k|r",
        "chat line must preserve the exact renderable Blizzard markup after the dungeon name"
      )

      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 1, "markup direct-push must lock out the later level-less resolver fallback")
    end)
  end)

  test("Status AnnounceTargetDungeonFromPayload is a no-op for invalid payloads", function()
    local prints = {}
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        isInGroup = function()
          return true
        end,
        printFn = function(message)
          table.insert(prints, tostring(message))
        end,
      })

      controller.AnnounceTargetDungeonFromPayload(nil)
      controller.AnnounceTargetDungeonFromPayload("not-a-table")
      controller.AnnounceTargetDungeonFromPayload(42)
      controller.AnnounceTargetDungeonFromPayload({ level = 14 })
      controller.AnnounceTargetDungeonFromPayload({ name = "" })
      controller.AnnounceTargetDungeonFromPayload({ name = "  " })
      Assert.Equal(#prints, 0, "invalid / missing-name payloads must not emit any announce")
    end)
  end)

  test("Status AnnounceTargetDungeonFromPayload locks out the resolver-driven path", function()
    local prints = {}
    local current = { targetInfo = { name = "Grube von Saron", level = 13 } }
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        isInGroup = function()
          return true
        end,
        getTargetDungeonInfo = function()
          return current.targetInfo
        end,
        printFn = function(message)
          table.insert(prints, tostring(message))
        end,
      })

      -- Direct push from the LFG-accept callback lands first.
      controller.AnnounceTargetDungeonFromPayload({ name = "Grube von Saron", level = 13 })
      Assert.Equal(#prints, 1, "direct push emits the announce")

      -- A subsequent UpdateStatusLine-driven re-evaluation (e.g. the
      -- GROUP_ROSTER_UPDATE-triggered status refresh) must stay silent
      -- because the lock-in is already set.
      controller.MaybeAnnounceTargetDungeonChat()
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 1, "resolver-driven path respects the direct-push lock-in")
    end)
  end)
end

local function RegisterStatusLineTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Status line includes target dungeon and key level when available", function()
    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        getTargetDungeonInfo = function()
          return {
            name = "Ara-Kara",
            level = 14,
          }
        end,
      })

      local text = controller.BuildStatusLineText({})
      Assert.True(
        string.find(text, "\nTarget Dungeon: Ara-Kara +14", 1, true) ~= nil,
        "status line should include resolved target dungeon with key level on the second line"
      )
    end)
  end)

  test("Status line floors a fractional target key level instead of erroring on %d", function()
    -- Regression: info.level reaches BuildTargetDungeonText through several
    -- unfloored tonumber() hops (LFG title hint, reload snapshot, roster owner
    -- key, synced target). The %d format used to receive it raw, which Lua 5.1
    -- truncates silently but Lua 5.4 rejects with "number has no integer
    -- representation" -- while the announce path already floored the same field.
    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        getTargetDungeonInfo = function()
          return {
            name = "Ara-Kara",
            level = 14.7,
          }
        end,
      })

      local ok, text = pcall(controller.BuildStatusLineText, {})
      Assert.True(ok, "a fractional key level must not throw while formatting the status line")
      Assert.True(
        string.find(text, "\nTarget Dungeon: Ara-Kara +14", 1, true) ~= nil,
        "fractional key level must render floored, matching the announce path"
      )
    end)
  end)

  test("Status target dungeon chat defers the level-less announce and fires once the level resolves", function()
    local current = {
      inGroup = false,
      targetInfo = {
        name = "Ara-Kara",
        level = 14,
      },
    }
    local prints = {}
    local now = 100
    local scheduled = {}

    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        isInGroup = function()
          return current.inGroup
        end,
        getTargetDungeonInfo = function()
          return current.targetInfo
        end,
        getTime = function()
          return now
        end,
        timerAfter = function(seconds, callback)
          table.insert(scheduled, { at = now + seconds, callback = callback })
        end,
        printFn = function(message)
          table.insert(prints, tostring(message))
        end,
      })

      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 0, "solo target resolution must not write key chat lines")

      current.inGroup = true
      current.targetInfo = {
        name = "Ara-Kara",
      }
      controller.MaybeAnnounceTargetDungeonChat()
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(
        #prints,
        0,
        "level-less target must defer the announce until the level resolves or the timeout elapses"
      )

      -- Level resolves before the deferred timer fires -> announce once, with +N.
      current.targetInfo = {
        name = "Ara-Kara",
        level = 14,
      }
      controller.MaybeAnnounceTargetDungeonChat()
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 1, "resolved level before fallback must produce one +N announce")
      Assert.Equal(
        prints[1],
        "Target Dungeon: |cffffd200Ara-Kara +14|r",
        "deferred announce carries the resolved +14 level"
      )

      -- Late firing of the scheduled timer hits the lock-in and stays silent.
      now = now + 5
      for _, entry in ipairs(scheduled) do
        entry.callback()
      end
      Assert.Equal(#prints, 1, "deferred timer firing after the +N announce must stay silent (lock-in)")

      -- Clearing the target resets the lock; a fresh +N for the same name announces again.
      current.targetInfo = nil
      controller.MaybeAnnounceTargetDungeonChat()
      current.targetInfo = {
        name = "Ara-Kara",
        level = 14,
      }
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 2, "clearing the target must allow a fresh grouped key announce later")
      Assert.Equal(
        prints[2],
        "Target Dungeon: |cffffd200Ara-Kara +14|r",
        "fresh grouped key chat should highlight the dungeon + key level in yellow"
      )
    end)
  end)

  test("Status target dungeon chat falls back to a level-less announce once the deferred wait elapses", function()
    local current = {
      inGroup = true,
      targetInfo = { name = "Ara-Kara" },
    }
    local prints = {}
    local now = 1000
    local scheduled = {}

    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        isInGroup = function()
          return current.inGroup
        end,
        getTargetDungeonInfo = function()
          return current.targetInfo
        end,
        getTime = function()
          return now
        end,
        timerAfter = function(seconds, callback)
          table.insert(scheduled, { at = now + seconds, callback = callback })
        end,
        printFn = function(message)
          table.insert(prints, tostring(message))
        end,
      })

      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 0, "first level-less sighting must stay silent and arm the deferred timer")
      Assert.Equal(#scheduled, 1, "deferred timer must be scheduled exactly once on the first sighting")

      -- Re-evaluation inside the wait window still suppresses.
      now = now + 1.5
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 0, "re-evaluation within the deferred wait must remain silent")

      -- Deferred timer fires after the wait window: level still unresolved -> fallback.
      now = scheduled[1].at + 0.1
      scheduled[1].callback()
      Assert.Equal(#prints, 1, "deferred timer firing after timeout must emit the level-less fallback")
      Assert.Equal(
        prints[1],
        "Target Dungeon: |cffffd200Ara-Kara|r",
        "fallback announce keeps the level off when no key info ever surfaced"
      )
    end)
  end)

  test("Status target dungeon chat locks in after first level announce and ignores level downgrade", function()
    -- Fix 2 reproduction: after the first +N announce, downstream level
    -- sources can flicker to a *lower* number (own-key surfacing in the
    -- roster after the LFG-title hint disappeared) or to nil (sync round-
    -- trip in flight). Neither must produce a second chat line for the
    -- same dungeon name — the production bug printed three near-identical
    -- "Ziel-Dungeon" lines per accept event.
    local current = {
      inGroup = true,
      targetInfo = { name = "Nexus-Point Xenas", level = 14 },
    }
    local prints = {}

    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        isInGroup = function()
          return current.inGroup
        end,
        getTargetDungeonInfo = function()
          return current.targetInfo
        end,
        printFn = function(message)
          table.insert(prints, tostring(message))
        end,
      })

      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 1, "first +14 announce fires once")
      Assert.Equal(prints[1], "Target Dungeon: |cffffd200Nexus-Point Xenas +14|r", "+14 form printed")

      current.targetInfo = { name = "Nexus-Point Xenas", level = 13 }
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(
        #prints,
        1,
        "level downgrade for the same dungeon must NOT trigger a second chat line — Fix 2 lock-in"
      )

      current.targetInfo = { name = "Nexus-Point Xenas" }
      controller.MaybeAnnounceTargetDungeonChat()
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(
        #prints,
        1,
        "level disappearing for the locked dungeon must NOT trigger a level-less third chat line"
      )

      current.targetInfo = { name = "Nexus-Point Xenas", level = 14 }
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 1, "level recovering to the original +N must not produce a duplicate line")
    end)
  end)

  test("Status target dungeon chat lock-in resets when group leaves so a fresh key can announce again", function()
    -- Real group-leave path: GetStatusTargetDungeonInfo collapses to nil
    -- once no roster / queue / synced target survives. Reset is driven by
    -- the info=nil branch — NOT by a transient IsInGroup=false alone,
    -- because IsInGroup() is known to flicker false between
    -- LFG_LIST_APPLICATION_STATUS_UPDATED=inviteaccepted and the delayed
    -- GROUP_ROSTER_UPDATE, and resetting on every transient flicker would
    -- erase the direct-push lock-in. See MaybeAnnounceTargetDungeonChat's
    -- lock-in protection guard.
    local current = {
      inGroup = true,
      targetInfo = { name = "Nexus-Point Xenas", level = 14 },
    }
    local prints = {}

    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        isInGroup = function()
          return current.inGroup
        end,
        getTargetDungeonInfo = function()
          return current.targetInfo
        end,
        printFn = function(message)
          table.insert(prints, tostring(message))
        end,
      })

      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 1, "setup: locked-in announce printed once")

      -- Group leave: the roster collapses, GetStatusTargetDungeonInfo
      -- returns nil. That is the real-life signal — not IsInGroup alone.
      current.inGroup = false
      current.targetInfo = nil
      controller.MaybeAnnounceTargetDungeonChat() -- info=nil branch resets the state

      current.inGroup = true
      current.targetInfo = { name = "Nexus-Point Xenas", level = 14 }
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(
        #prints,
        2,
        "leaving the group resets the lock-in; the next key for the same dungeon must announce again"
      )
    end)
  end)

  test("Status target dungeon chat preserves the lock-in during transient IsInGroup=false", function()
    -- Reproduces the LFG_LIST_APPLICATION_STATUS_UPDATED=inviteaccepted
    -- race: the direct-push lock-in is set before GROUP_ROSTER_UPDATE
    -- flips IsInGroup() to true. The queue handler runs updateStatusLine
    -- synchronously right after the accept event, so MaybeAnnounceTarget-
    -- DungeonChat hits with IsInGroup()=false. Without the lock-in guard
    -- the next resolver pass would re-announce — often without "+N" once
    -- the LFG-title hint ages out.
    local current = {
      inGroup = true,
      targetInfo = { name = "Die Himmelsnadel", level = 13 },
    }
    local prints = {}

    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        isInGroup = function()
          return current.inGroup
        end,
        getTargetDungeonInfo = function()
          return current.targetInfo
        end,
        printFn = function(message)
          table.insert(prints, tostring(message))
        end,
      })

      -- Direct-push (simulated): emits the announce + sets the lock-in.
      controller.AnnounceTargetDungeonFromPayload({ name = "Die Himmelsnadel", level = 13 })
      Assert.Equal(#prints, 1, "direct push emits the first announce with +13")

      -- Race window: queue handler's synchronous updateStatusLine fires
      -- while IsInGroup() is still transient-false. The target info still
      -- carries the listing (pendingAcceptedInviteMapID feeds the resolver).
      current.inGroup = false
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 1, "transient IsInGroup=false must not erase the lock-in or re-announce")

      -- GROUP_ROSTER_UPDATE: IsInGroup flips to true. Even if the resolver
      -- can no longer produce a level (LFG-title hint aged out), the
      -- lock-in must keep the chat line quiet.
      current.inGroup = true
      current.targetInfo = { name = "Die Himmelsnadel" }
      controller.MaybeAnnounceTargetDungeonChat()
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 1, "lock-in survives the IsInGroup flicker — no level-less duplicate")
    end)
  end)

  test("Status target dungeon chat suppresses the announce when only a synced peer target is available", function()
    -- Manual /invite scenario: the player joined a group with no own
    -- LFG-listing and no own LFG-accept, so ResolveLocalStatusTargetMapID
    -- in the factory returns nil and the resolver chain falls back to the
    -- synced-target consensus across the roster. That consensus is fine
    -- for the status frame (which always renders getTargetDungeonInfo)
    -- but must NOT drop a chat line — it merely reflects whichever member
    -- is currently broadcasting a mapID, not a semantic "this is the
    -- dungeon the group has decided to play" signal. The gate also has
    -- to flip the right way once the local player does establish a
    -- local trigger (own LFG-accept / own queue), and direct-push must
    -- continue to bypass the gate completely.
    local current = {
      inGroup = true,
      targetInfo = { name = "Maisarakavernen" },
      hasLocalTarget = false,
    }
    local prints = {}

    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        isInGroup = function()
          return current.inGroup
        end,
        getTargetDungeonInfo = function()
          return current.targetInfo
        end,
        hasLocalTargetSource = function()
          return current.hasLocalTarget
        end,
        printFn = function(message)
          table.insert(prints, tostring(message))
        end,
      })

      controller.MaybeAnnounceTargetDungeonChat()
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 0, "synced-only target must not surface in chat without a local trigger")

      -- Roster reshuffle: the previously syncing member leaves, another
      -- member's target takes over. With only synced sources, the chat
      -- still stays quiet.
      current.targetInfo = { name = "Grube von Saron" }
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 0, "synced-target name flip across roster changes still stays silent")

      -- Local trigger appears (own LFG-accept / own queue): the gate
      -- opens and the announce fires for the now-authoritative target.
      current.hasLocalTarget = true
      current.targetInfo = { name = "Akademie von Algeth'ar", level = 12 }
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 1, "once a local trigger exists, the announce drops normally")
      Assert.Equal(
        prints[1],
        "Target Dungeon: |cffffd200Akademie von Algeth'ar +12|r",
        "the announce carries the resolved local-trigger target"
      )

      -- Direct-push bypasses the gate by design: it sets the lock-in
      -- itself, and EmitTargetDungeonAnnouncement does not consult
      -- hasLocalTargetSource. Pin that contract.
      current.hasLocalTarget = false
      current.targetInfo = { name = "Akademie von Algeth'ar", level = 12 }
      controller.AnnounceTargetDungeonFromPayload({ name = "Die Himmelsnadel", level = 13 })
      Assert.Equal(#prints, 2, "direct-push from LFG-accept ignores the local-trigger gate")
      Assert.Equal(
        prints[2],
        "Target Dungeon: |cffffd200Die Himmelsnadel +13|r",
        "direct-push announce carries the listing's +N regardless of synced-only state"
      )
    end)
  end)

  test("Status target dungeon chat upgrades to key level when level resolves before fallback announce", function()
    local current = {
      inGroup = true,
      targetInfo = {
        name = "Ara-Kara",
      },
    }
    local prints = {}

    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        isInGroup = function()
          return current.inGroup
        end,
        getTargetDungeonInfo = function()
          return current.targetInfo
        end,
        printFn = function(message)
          table.insert(prints, tostring(message))
        end,
      })

      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 0, "first level-less sighting must defer the announce")

      current.targetInfo = {
        name = "Ara-Kara",
        level = 14,
      }
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 1, "resolved level before the deferred timeout must announce the level form")
      Assert.Equal(prints[1], "Target Dungeon: |cffffd200Ara-Kara +14|r", "level form must be printed")
    end)
  end)

  test("Status line places target dungeon at the end", function()
    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        getTargetDungeonInfo = function()
          return {
            name = "Ara-Kara",
            level = 14,
          }
        end,
      })

      local text = controller.BuildStatusLineText({})
      Assert.Equal(
        text,
        "Lead: No | M+: Inactive | State: Running | Dungeon: Outside\nTarget Dungeon: Ara-Kara +14",
        "target dungeon should be rendered on a second line below the lead/status summary"
      )
    end)
  end)

  test("Status line keeps target placeholder when no target is available", function()
    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
      })

      local text = controller.BuildStatusLineText({})
      Assert.True(
        string.find(text, "\nTarget Dungeon: -", 1, true) ~= nil,
        "status line should show target placeholder on the second line when no target is known"
      )
    end)
  end)

  test("Status line keeps M+ inactive when challenge API is unavailable", function()
    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = nil,
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
      })

      local text = controller.BuildStatusLineText({})
      Assert.True(
        string.find(text, "M+: Inactive", 1, true) ~= nil,
        "status line should keep M+ inactive when the Blizzard challenge API is missing"
      )
    end)
  end)

  test("Status line shows pre-season placeholder when active portal pool is empty", function()
    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        hasActiveDungeons = function()
          return false
        end,
        getActiveSeasonLabel = function()
          return "Midnight Season 1 (prepared, inactive)"
        end,
      })

      local text = controller.BuildStatusLineText({})
      Assert.True(
        string.find(text, "\nTarget Dungeon: Pre-Season (Midnight Season 1 (prepared, inactive))", 1, true) ~= nil,
        "status line should explain the empty pre-season portal pool on the second line"
      )
    end)
  end)
end

local function BuildFactoryRuntimeHelperContext(initial, LoadAddonModules)
  local addon = LoadAddonModules({ "isiLive_factory_controllers.lua" }, {
    _FactoryInternal = {},
  })

  local state = initial or {}
  local runtimeState = {
    GetRoster = function()
      return state.roster or {}
    end,
    GetPendingQueueJoinInfo = function()
      return state.pendingQueueJoinInfo
    end,
    SetPendingQueueJoinInfo = function(value)
      state.pendingQueueJoinInfo = value
    end,
    GetLatestQueueState = function()
      return state.latestQueueDungeonName, state.latestQueueActivityID, nil, state.latestQueueMapID
    end,
    GetActiveJoinedKeyMapID = function()
      return state.activeJoinedKeyMapID
    end,
  }

  local ctx = {
    modules = {
      sync = {
        NormalizePlayerKey = function(name, realm)
          return tostring(name or "") .. "-" .. tostring(realm or "")
        end,
        GetPlayerTargetInfo = function(name, realm)
          local targetInfoByPlayer = state.targetInfoByPlayer or {}
          return targetInfoByPlayer[tostring(name or "") .. "-" .. tostring(realm or "")]
        end,
        SendTarget = function(opts)
          state.sentTargetSnapshots = state.sentTargetSnapshots or {}
          table.insert(state.sentTargetSnapshots, opts)
        end,
      },
      teleport = {
        GetTeleportInfoByMapID = function(mapID)
          local infoByMapID = state.teleportInfoByMapID or {}
          return infoByMapID[mapID]
        end,
      },
      queue = {
        GetActivityName = function(activityID)
          local namesByActivityID = state.activityNamesByActivityID or {}
          return namesByActivityID[activityID]
        end,
      },
    },
    runtimeState = runtimeState,
    addonTable = {},
    GetL = function()
      return {
        UNKNOWN_GROUP = "Unknown",
        JOINED_FROM_QUEUE = "Joined from queue: %s",
        CHAT_QUEUE_PREFIX = "Queue Join",
      }
    end,
    Print = function(message)
      state.prints = state.prints or {}
      table.insert(state.prints, tostring(message))
    end,
    IsPlayerLeader = function()
      return state.isPlayerLeader == true
    end,
    keySyncController = {
      ResolveActiveKeyOwnerUnit = function(roster, targetMapID)
        if type(state.resolveActiveKeyOwnerUnit) == "function" then
          return state.resolveActiveKeyOwnerUnit(roster, targetMapID)
        end
        return nil
      end,
    },
    ResolveMapIDByActivityID = function(activityID)
      local mapIDsByActivityID = state.mapIDsByActivityID or {}
      return mapIDsByActivityID[activityID]
    end,
  }

  addon._FactoryInternal.InitializeFactoryRuntimeHelpers(ctx)
  return ctx, state
end

local function RegisterFactoryRuntimeQueueTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Factory runtime queue capture ignores queue events while challenge mode is active", function()
    WithGlobals({
      IsInGroup = function()
        return false
      end,
      GetTime = function()
        return 42
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return 507
        end,
      },
    }, function()
      local ctx, state = BuildFactoryRuntimeHelperContext({}, LoadAddonModules)

      ctx.CaptureQueueJoinCandidate({ groupName = "Queued Group" })

      Assert.Nil(state.pendingQueueJoinInfo, "challenge mode must not capture pending queue join info")
      Assert.Equal(#(state.prints or {}), 0, "challenge mode capture path must stay silent")
    end)
  end)

  test("Factory runtime queue capture stores pending info when not in group", function()
    WithGlobals({
      IsInGroup = function()
        return false
      end,
      GetTime = function()
        return 42
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local ctx, state = BuildFactoryRuntimeHelperContext({}, LoadAddonModules)

      ctx.CaptureQueueJoinCandidate({ groupName = "Queued Group" })

      Assert.NotNil(state.pendingQueueJoinInfo, "queue capture must store pending queue join info outside a group")
      Assert.Equal(
        state.pendingQueueJoinInfo.groupName,
        "Queued Group",
        "queue capture must keep the queued group name for the later announce"
      )
      Assert.Equal(state.pendingQueueJoinInfo.capturedAt, 42, "queue capture must stamp deterministic capture time")
    end)
  end)

  test("Factory runtime queue capture announces immediately when already grouped", function()
    WithGlobals({
      IsInGroup = function()
        return true
      end,
      GetTime = function()
        return 42
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local ctx, state = BuildFactoryRuntimeHelperContext({
        pendingQueueJoinInfo = {
          groupName = "Late Group",
          capturedAt = 1,
        },
      }, LoadAddonModules)

      ctx.CaptureQueueJoinCandidate()

      Assert.Nil(state.pendingQueueJoinInfo, "already-grouped capture must consume pending queue join info immediately")
      Assert.True(#(state.prints or {}) >= 3, "already-grouped capture must print the queue join summary")
    end)
  end)

  test("Factory runtime queue capture preserves verified pending info across informational event noise", function()
    WithGlobals({
      IsInGroup = function()
        return false
      end,
      GetTime = function()
        return 42
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local ctx, state = BuildFactoryRuntimeHelperContext({
        pendingQueueJoinInfo = {
          groupName = "Old Group",
          capturedAt = 1,
        },
      }, LoadAddonModules)

      ctx.CaptureQueueJoinCandidate(98765)

      Assert.Equal(
        state.pendingQueueJoinInfo.groupName,
        "Old Group",
        "an event without a verified group name must not erase the pending queue join"
      )
      Assert.Equal(#(state.prints or {}), 0, "informational event noise outside a group must stay silent")
    end)
  end)

  test("Factory runtime queue announce prints queue joined message for members and clears pending", function()
    local ctx, state = BuildFactoryRuntimeHelperContext({
      pendingQueueJoinInfo = {
        groupName = "Queued Group",
        capturedAt = 42,
      },
    }, LoadAddonModules)

    ctx.AnnounceQueuedGroupJoin()

    Assert.Nil(state.pendingQueueJoinInfo, "member announce path must clear pending queue join info")
    Assert.True(#(state.prints or {}) >= 3, "member announce path must print the queue join summary")
  end)

  test("Factory runtime queue announce clears pending for leaders without printing", function()
    local ctx, state = BuildFactoryRuntimeHelperContext({
      isPlayerLeader = true,
      pendingQueueJoinInfo = {
        groupName = "Queued Group",
        capturedAt = 42,
      },
    }, LoadAddonModules)

    ctx.AnnounceQueuedGroupJoin()

    Assert.Nil(state.pendingQueueJoinInfo, "leader announce path must clear pending queue join info")
    Assert.Equal(#(state.prints or {}), 0, "leader announce path must not print the queue join summary")
  end)
end

local function RegisterFactoryTargetContextResolutionTests(test, Assert, LoadAddonModules)
  test("Factory target dungeon stays unresolved without queue or joined-key map context", function()
    local ctx = BuildFactoryRuntimeHelperContext({
      roster = {
        player = { name = "Me", realm = "Realm", keyMapID = 2441, keyLevel = 12 },
        party1 = { name = "Other", realm = "Realm", keyMapID = 2441, keyLevel = 14 },
      },
      teleportInfoByMapID = {
        [2441] = { mapName = "Ara-Kara" },
      },
    }, LoadAddonModules)

    Assert.Nil(ctx.ResolveStatusTargetMapID(), "target map must stay unresolved without queue or joined-key context")
    Assert.Nil(ctx.GetStatusTargetDungeonInfo(), "target dungeon text must stay unresolved without strict map context")
  end)

  test("Factory target dungeon omits key level without unique owner resolution", function()
    local ctx = BuildFactoryRuntimeHelperContext({
      latestQueueMapID = 2441,
      latestQueueDungeonName = "Ara-Kara",
      roster = {
        player = { name = "Me", realm = "Realm", keyMapID = 2441, keyLevel = 12 },
      },
      resolveActiveKeyOwnerUnit = function(_roster, _targetMapID)
        return nil
      end,
    }, LoadAddonModules)

    local info = ctx.GetStatusTargetDungeonInfo()
    Assert.NotNil(info, "queue-backed target dungeon should still resolve by name")
    Assert.Equal(info.name, "Ara-Kara", "queue-backed target dungeon should keep the known dungeon name")
    Assert.Nil(info.level, "target key level must stay unresolved without a uniquely resolved owner")
  end)

  test("Factory target dungeon resolves from synced exact target context", function()
    local ctx = BuildFactoryRuntimeHelperContext({
      roster = {
        party1 = { name = "Owner", realm = "Realm" },
      },
      targetInfoByPlayer = {
        ["Owner-Realm"] = { mapID = 2441, level = 14 },
      },
      teleportInfoByMapID = {
        [2441] = { mapName = "Ara-Kara" },
      },
    }, LoadAddonModules)

    Assert.Equal(
      ctx.ResolveStatusTargetMapID(),
      2441,
      "synced exact target map should resolve without local queue context"
    )

    local info = ctx.GetStatusTargetDungeonInfo()
    Assert.NotNil(info, "synced exact target should populate target dungeon info")
    Assert.Equal(info.name, "Ara-Kara", "synced exact target should resolve the map name")
    Assert.Equal(info.level, 14, "synced exact target should keep the explicit synced key level")
  end)

  test("Factory target dungeon stays unresolved on conflicting synced exact targets", function()
    local ctx = BuildFactoryRuntimeHelperContext({
      roster = {
        party1 = { name = "OwnerA", realm = "Realm" },
        party2 = { name = "OwnerB", realm = "Realm" },
      },
      targetInfoByPlayer = {
        ["OwnerA-Realm"] = { mapID = 2441, level = 14 },
        ["OwnerB-Realm"] = { mapID = 2662, level = 12 },
      },
    }, LoadAddonModules)

    Assert.Nil(ctx.ResolveStatusTargetMapID(), "conflicting synced exact targets must stay unresolved")
    Assert.Nil(ctx.GetStatusTargetDungeonInfo(), "conflicting synced exact targets must not guess a dungeon name")
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterDungeonDifficultyTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterPortalNavigatorTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterStatusLineTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterFactoryRuntimeQueueTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterFactoryTargetContextResolutionTests(test, Assert, LoadAddonModules)
end
