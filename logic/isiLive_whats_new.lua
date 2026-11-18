local _, addonTable = ...
addonTable = addonTable or {}

-- What's new (rule 256): one center notice card for the newest feature,
-- shown once shortly after login and then never again until a newer entry is
-- added. The seen state is the entry ID in IsiLiveDB.whatsNewSeen
-- (account-wide). Fresh installs see the card too.
--
-- Adding a feature notice: append an entry to WhatsNew.ENTRIES with a new,
-- unique `id` and its locale keys (all five languages). Only the last entry
-- is ever shown; older entries stay for the record and are never re-shown.
local WhatsNew = {}
addonTable.WhatsNew = WhatsNew

WhatsNew.ENTRIES = {
  {
    id = "time_pace_announce",
    titleKey = "WHATS_NEW_PACE_ANNOUNCE_TITLE",
    titleFallback = "New: post the pace to your group",
    fields = {
      {
        labelKey = "WHATS_NEW_LABEL_WHAT",
        labelFallback = "What",
        valueKey = "WHATS_NEW_PACE_ANNOUNCE_WHAT",
        valueFallback = "Click the time pace badge (ON TIME / CLOSE / TOO SLOW) on the right of the killtracker bar. "
          .. "isiLive posts one short line to your group chat: INTIME or OUT-OF-TIME, the time to spare or "
          .. "over the timer, and a short call-out for the group.",
      },
      {
        labelKey = "WHATS_NEW_LABEL_EXAMPLE",
        labelFallback = "Example",
        -- The chat line itself is English in every language (rule 255).
        valueFallback = "KR +15 expected: INTIME - 1:12 spare. Go for it! (via isiLive M+Addon)", -- i18n-ok
      },
      {
        labelKey = "WHATS_NEW_LABEL_WHEN",
        labelFallback = "When",
        valueKey = "WHATS_NEW_PACE_ANNOUNCE_WHEN",
        valueFallback = "While a key runs, also in combat, at most once every 10 seconds. The line is always "
          .. "in English, so everyone in the group can read it.",
      },
      {
        labelKey = "WHATS_NEW_LABEL_TIP",
        labelFallback = "Tip",
        valueKey = "WHATS_NEW_PACE_ANNOUNCE_TIP",
        valueFallback = "Hover the badge to see the line before you post it.",
      },
    },
  },
}

-- Delay after PLAYER_LOGIN, so the card does not land in the loading burst.
WhatsNew.LOGIN_DELAY_SECONDS = 8
-- How long the card stays (it can be closed earlier).
WhatsNew.DURATION_SECONDS = 60

--- The newest entry, or nil when there is none.
function WhatsNew.GetLatest()
  return WhatsNew.ENTRIES[#WhatsNew.ENTRIES]
end

--- The entry still to show for `db`, or nil when it was seen already.
function WhatsNew.GetPending(db)
  local latest = WhatsNew.GetLatest()
  if type(latest) ~= "table" or type(latest.id) ~= "string" then
    return nil
  end
  if type(db) == "table" and db.whatsNewSeen == latest.id then
    return nil
  end
  return latest
end

local function Text(L, key, fallback)
  local value = type(L) == "table" and L[key] or nil
  return type(value) == "string" and value ~= "" and value or fallback
end

--- Center notice options for `entry` in the language of `L`.
function WhatsNew.BuildNoticeOptions(entry, L)
  local fields = {}
  for _, field in ipairs(entry.fields or {}) do
    -- Description values use the smaller compact field font.
    fields[#fields + 1] = {
      label = Text(L, field.labelKey, field.labelFallback),
      value = field.valueKey and Text(L, field.valueKey, field.valueFallback) or field.valueFallback,
      compact = true,
    }
  end
  return {
    noticeKind = "info",
    eyebrow = Text(L, "WHATS_NEW_EYEBROW", "What's new"),
    title = Text(L, entry.titleKey, entry.titleFallback),
    fields = fields,
  }
end

local function DefaultAfter(delay, fn)
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    timer.After(delay, fn)
    return
  end
  fn()
end

--- Creates the login hook.
-- @param deps table { getDB, getL, showCenterNotice, after? }
-- @return table { OnLogin, ShowPending }
function WhatsNew.Create(deps)
  deps = type(deps) == "table" and deps or {}
  local after = type(deps.after) == "function" and deps.after or DefaultAfter
  local scheduled = false
  local controller = {}

  --- Shows the pending card now and marks it seen. Returns true when shown.
  function controller.ShowPending()
    local db = type(deps.getDB) == "function" and deps.getDB() or nil
    local entry = WhatsNew.GetPending(db)
    if not entry or type(db) ~= "table" or type(deps.showCenterNotice) ~= "function" then
      return false
    end
    local function Build()
      local L = type(deps.getL) == "function" and deps.getL() or nil
      local options = WhatsNew.BuildNoticeOptions(entry, L)
      -- A language switch rebuilds the open card in the new language.
      options.rebuild = function()
        return { durationSeconds = WhatsNew.DURATION_SECONDS, showOptions = Build() }
      end
      return options
    end
    deps.showCenterNotice(nil, WhatsNew.DURATION_SECONDS, nil, nil, Build())
    db.whatsNewSeen = entry.id
    return true
  end

  --- PLAYER_LOGIN: schedules the card once per session.
  function controller.OnLogin()
    if scheduled then
      return
    end
    scheduled = true
    after(WhatsNew.LOGIN_DELAY_SECONDS, controller.ShowPending)
  end

  return controller
end
