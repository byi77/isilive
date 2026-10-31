local _, addonTable = ...

addonTable = addonTable or {}

-- Time curves for the time pace (game/isiLive_time_pace.lua): the share of a
-- key's time at which it typically reaches each progress step. No curve ships
-- at the moment; without one the forecast uses whole run and rolling tempo.
addonTable.TimeSeed = {}
