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
local LFG_GROUP_BONUSES_DESC_FR = "Affiche des coeurs verts pour les buffs de classe utiles qui ne se cumulent pas:\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = un buff utile\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = deux buffs utiles\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = trois buffs utiles\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = quatre buffs utiles ou plus\n"
  .. "L'utilitaire reste uniquement dans l'infobulle: BL, BR, PI,\n"
  .. "Aura de devouement, Poison atrophiant."
local LFG_GROUP_BONUSES_DESC_ES = "Muestra corazones verdes para beneficios de clase utiles que no se acumulan:\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = un beneficio util\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = dos beneficios utiles\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = tres beneficios utiles\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = cuatro o mas beneficios utiles\n"
  .. "La utilidad queda solo en la descripcion: BL, BR, PI,\n"
  .. "Aura de devocion, Veneno atrofico."
local LFG_GROUP_BONUSES_DESC_PT = "Mostra coracoes verdes para buffs de classe uteis que nao acumulam:\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = um buff util\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = dois buffs uteis\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = tres buffs uteis\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = quatro ou mais buffs uteis\n"
  .. "A utilidade fica apenas na dica: BL, BR, PI,\n"
  .. "Aura de Devocao, Veneno Atrofico."
local LFG_GROUP_BONUSES_DESC_IT = "Mostra cuori verdi per i buff di classe utili che non si accumulano:\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = un buff utile\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = due buff utili\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = tre buff utili\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = quattro o piu buff utili\n"
  .. "L'utilita resta solo nel suggerimento: BL, BR, PI,\n"
  .. "Aura di Devozione, Veleno Atrofico."
local LFG_GROUP_BONUSES_DESC_TR = "Birbirine eklenmeyen yararli sinif bufflari icin yesil kalpler gosterir:\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = bir yararli buff\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = iki yararli buff\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = uc yararli buff\n"
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. LFG_GROUP_BONUS_HEART_ICON
  .. " = dort veya daha fazla yararli buff\n"
  .. "Yardimci etkiler yalnizca ipucunda kalir: BL, BR, PI,\n"
  .. "Devotion Aura, Atrofik Zehir."

addonTable.TextsCommon = {
  LFG_GROUP_BONUSES_DESC_EN = LFG_GROUP_BONUSES_DESC_EN,
  LFG_GROUP_BONUSES_DESC_DE = LFG_GROUP_BONUSES_DESC_DE,
  LFG_GROUP_BONUSES_DESC_RU = LFG_GROUP_BONUSES_DESC_RU,
  LFG_GROUP_BONUSES_DESC_FR = LFG_GROUP_BONUSES_DESC_FR,
  LFG_GROUP_BONUSES_DESC_ES = LFG_GROUP_BONUSES_DESC_ES,
  LFG_GROUP_BONUSES_DESC_PT = LFG_GROUP_BONUSES_DESC_PT,
  LFG_GROUP_BONUSES_DESC_IT = LFG_GROUP_BONUSES_DESC_IT,
  LFG_GROUP_BONUSES_DESC_TR = LFG_GROUP_BONUSES_DESC_TR,
}
