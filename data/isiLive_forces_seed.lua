local _, addonTable = ...

addonTable = addonTable or {}

-- GENERATED, do not edit by hand.
-- Start values for the forces pace, used for a dungeon until the player has a
-- learned route that fits the run (game/isiLive_forces_pace.lua).
--
-- Median enemy-forces percentage at each boss kill of timed +12 to
-- +21 keys from public Warcraft Logs reports, as of 2026-11-14. Do not fill
-- this table from another addon: external route tables are not ours to
-- redistribute.
--
-- Same shape as IsiLiveDB.forcesPace[seasonID][mapID].routes, and read through
-- the same validation. A season without an entry shows learned values only.
addonTable.ForcesSeed = {
  midnight_s2 = {
    [249] = { -- King's Rest
      routes = {
        ["1-2-3-4"] = {
          order = { 1, 2, 3, 4 },
          checkpoints = { 28.7, 77.2, 100, 100 },
          leanScore = 305.9,
        },
      },
    },
    [250] = { -- Temple of Sethraliss
      routes = {
        ["1-2-3-4"] = {
          order = { 1, 2, 3, 4 },
          checkpoints = { 22.9, 64.9, 81.5, 100 },
          leanScore = 269.3,
        },
      },
    },
    [399] = { -- Ruby Life Pools
      routes = {
        ["1-2-3"] = {
          order = { 1, 2, 3 },
          checkpoints = { 29.9, 75.7, 100 },
          leanScore = 205.6,
        },
      },
    },
    [584] = { -- The Blinding Vale
      routes = {
        ["1-2-3-4"] = {
          order = { 1, 2, 3, 4 },
          checkpoints = { 41.4, 53.1, 66.8, 100 },
          leanScore = 261.3,
        },
      },
    },
    [585] = { -- Voidscar Arena
      routes = {
        ["1-2-3"] = {
          order = { 1, 2, 3 },
          checkpoints = { 34.7, 51.8, 100 },
          leanScore = 186.5,
        },
      },
    },
    [586] = { -- Den of Nalorakk
      routes = {
        ["1-2-3"] = {
          order = { 1, 2, 3 },
          checkpoints = { 22.2, 74.8, 100 },
          leanScore = 197,
        },
      },
    },
    [587] = { -- Murder Row
      routes = {
        ["1-2-3-4"] = {
          order = { 1, 2, 3, 4 },
          checkpoints = { 36.3, 40.3, 77, 100 },
          leanScore = 253.6,
        },
      },
    },
    [588] = { -- Altar of Fangs
      routes = {
        ["1-2-3"] = {
          order = { 1, 2, 3 },
          checkpoints = { 45.5, 64.9, 100 },
          leanScore = 210.4,
        },
      },
    },
  },
}
