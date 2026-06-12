local _, addonTable = ...
addonTable = addonTable or {}

-- Shared building blocks for the per-language tables in
-- locale/isiLive_texts_<tag>.lua. Loaded before them via the TOC (or the
-- standalone loadfile fallback in locale/isiLive_texts.lua).
local LFG_GROUP_BONUS_HEART_ICON = "|TInterface\\AddOns\\isiLive\\media\\heart_bonus_green:10:10:0:0|t"
local LFG_GROUP_BONUSES_DESC_EN = "Shows green hearts for relevant non-stacking class buffs:\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = one useful buff\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = two useful buffs\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = three useful buffs\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = four or more useful buffs\n"
  .. "Utility stays tooltip-only: BL, BR, PI, Devotion Aura,\n"
  .. "Atrophic Poison."
local LFG_GROUP_BONUSES_DESC_DE = "Zeigt gruene Herzen fuer relevante, nicht stapelnde Klassenbuffs:\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = ein nuetzlicher Buff\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = zwei nuetzliche Buffs\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = drei nuetzliche Buffs\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = vier oder mehr nuetzliche Buffs\n"
  .. "Utility bleibt nur im Tooltip: BL, BR, PI, Aura der Hingabe,\n"
  .. "Atrophisches Gift."
local LFG_GROUP_BONUSES_DESC_RU = "Показывает зеленые сердца для полезных нестакующихся классовых баффов:\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = один полезный бафф\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = два полезных баффа\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = три полезных баффа\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = четыре или больше полезных баффов\n"
  .. "Utility остается только в подсказках: БЛ, БР, ПИ,\n"
  .. "Аура благочестия, Атрофический яд."

addonTable.TextsCommon = {
  LFG_GROUP_BONUSES_DESC_EN = LFG_GROUP_BONUSES_DESC_EN,
  LFG_GROUP_BONUSES_DESC_DE = LFG_GROUP_BONUSES_DESC_DE,
  LFG_GROUP_BONUSES_DESC_RU = LFG_GROUP_BONUSES_DESC_RU,
}
