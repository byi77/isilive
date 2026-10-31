local _, addonTable = ...

addonTable = addonTable or {}

-- GENERATED, do not edit by hand.
-- Start values for the forces pace, used for a dungeon until the player has a
-- learned route that fits the run (game/isiLive_forces_pace.lua).
--
-- Median enemy-forces percentage at each boss kill of timed +12 to
-- +18 keys from public Warcraft Logs reports, as of 2026-10-31. Do not fill
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
          checkpoints = { 24.7, 72.7, 100, 100 },
          leanScore = 297.4,
        },
      },
    },
    [250] = { -- Temple of Sethraliss
      routes = {
        ["1-2-3-4"] = {
          order = { 1, 2, 3, 4 },
          checkpoints = { 22.9, 65.2, 81.5, 100 },
          leanScore = 269.6,
        },
      },
    },
    [399] = { -- Ruby Life Pools
      routes = {
        ["1-2-3"] = {
          order = { 1, 2, 3 },
          checkpoints = { 30.1, 75.7, 100 },
          leanScore = 205.8,
        },
      },
    },
    [584] = { -- The Blinding Vale
      routes = {
        ["1-2-3-4"] = {
          order = { 1, 2, 3, 4 },
          checkpoints = { 41.4, 53.2, 68.1, 100 },
          leanScore = 262.7,
        },
      },
    },
    [585] = { -- Voidscar Arena
      routes = {
        ["1-2-3"] = {
          order = { 1, 2, 3 },
          checkpoints = { 35.5, 60.6, 100 },
          leanScore = 196.1,
        },
      },
    },
    [586] = { -- Den of Nalorakk
      routes = {
        ["1-2-3"] = {
          order = { 1, 2, 3 },
          checkpoints = { 21.8, 74.1, 100 },
          leanScore = 195.9,
        },
      },
    },
    [587] = { -- Murder Row
      routes = {
        ["1-2-3-4"] = {
          order = { 1, 2, 3, 4 },
          checkpoints = { 36.3, 40.3, 74.6, 100 },
          leanScore = 251.2,
        },
      },
    },
    [588] = { -- Altar of Fangs
      routes = {
        ["1-2-3"] = {
          order = { 1, 2, 3 },
          checkpoints = { 43.8, 64.8, 100 },
          leanScore = 208.6,
        },
      },
    },
  },
}
