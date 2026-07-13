# Season-Intake

Diese Datei ist die strukturierte Sammelstelle fuer kommende Season-Daten.
Sie ist keine Aktivierung der Season. `SeasonData.ACTIVE_SEASON_ID` bleibt die
einzige Runtime-Aktivierung.

Maschinenregeln:
- `Status` ist `unresolved`, `candidate`, `partial` oder `verified`.
- `unresolved` bedeutet: alle technischen Felder sowie `Source` und `VerifiedAt` bleiben `unresolved`.
- `candidate` bedeutet: es gibt eine Quelle oder einen Fundhinweis, aber noch keine vollstaendig verifizierte ID-Kette.
- `partial` bedeutet: mindestens eine technische ID ist verifiziert, aber nicht alle Pflichtfelder sind vollstaendig.
- `verified` bedeutet: alle Pflichtfelder der Zeile sind numerisch verifiziert und haben `Source` plus `VerifiedAt`.
- `VerifiedAt` nutzt `YYYY-MM-DD`.
- Werte werden nicht geraten. Ohne belastbare Quelle bleibt der Wert `unresolved`.

Aktueller Stand `2026-07-13`: `8/8 verified`, `0/8 partial`. Der User hat die Uebernahme aller acht castbaren PortalSpellIDs nach dem Crosscheck von DBM, EnhanceQoL Teleport Compendium, Chonky Character Sheet und Wowhead-PTR-Spell-Daten ausdruecklich freigegeben. Die `128680x`-Reihe enthaelt die castbaren 10-Sekunden-Portalspells; die abweichenden `128977x`-Instant-Spells werden nicht als Portal-Cast-IDs uebernommen. ChallengeMapIDs und Mythic+-LFG-Activity-IDs sind dokumentiert. Englische und deutsche Namen, Default-/deDE-Kurzcodes sowie die ausdruecklich freigegebene aufsteigende Map-ID-Anzeigereihenfolge sind im Season-Datensatz gepflegt. S2 wird bewusst manuell aktiviert und ist nicht von der optionalen MDT-Forces-DB abhaengig; bis eine passende S2-DB vorliegt, bleiben nur die MDT-abhaengigen Mob-Anzeigen geschlossen.

## Dungeon-Intake

| Season | Dungeon | ChallengeMapID | PortalSpellID | LFGActivityID | Source | VerifiedAt | Status | Notiz |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| midnight_s2 | Altar of Fangs | 588 | 1286812 | 1933 | PortalSpellID: User-Freigabe nach Crosscheck DBM, EnhanceQoL, Chonky und Wowhead-PTR; LFG: PTR Blizzard-Activity-Suche | 2026-07-13 | verified | deDE Der Altar der Faenge; castbarer Portalspell Path of Venomous Evolution; Activity-mapID 2993 bleibt getrennt von ChallengeMapID 588 |
| midnight_s2 | Murder Row | 587 | 1286809 | 1950 | PortalSpellID: User-Freigabe nach Crosscheck DBM, EnhanceQoL, Chonky und Wowhead-PTR; LFG: PTR Blizzard-Activity-Suche | 2026-07-13 | verified | deDE Moerdergasse; castbarer Portalspell Path of the Devious Smuggler; Instanz-mapID 2813 bleibt getrennt von ChallengeMapID 587 |
| midnight_s2 | Den of Nalorakk | 586 | 1286807 | 1952 | PortalSpellID: User-Freigabe nach Crosscheck DBM, EnhanceQoL, Chonky und Wowhead-PTR; LFG: PTR Blizzard-Activity-Suche | 2026-07-13 | verified | deDE Nalorakks Bau; castbarer Portalspell Path of the Worthy Aspirant; Instanz-mapID 2825 bleibt getrennt von ChallengeMapID 586 |
| midnight_s2 | The Blinding Vale | 584 | 1286801 | 1949 | PortalSpellID: User-Freigabe nach Crosscheck DBM, EnhanceQoL, Chonky und Wowhead-PTR; LFG: PTR Blizzard-Activity-Suche | 2026-07-13 | verified | deDE Das blendende Tal; castbarer Portalspell Path of the Blooming Verdure; Activity-mapID 2859 bleibt getrennt von ChallengeMapID 584 |
| midnight_s2 | Voidscar Arena | 585 | 1286804 | 1951 | PortalSpellID: User-Freigabe nach Crosscheck DBM, EnhanceQoL, Chonky und Wowhead-PTR; LFG: PTR Blizzard-Activity-Suche | 2026-07-13 | verified | deDE Arena der Leerennarbe; castbarer Portalspell Path of the Brutal Combatant; Activity-mapID 2923 bleibt getrennt von ChallengeMapID 585 |
| midnight_s2 | King's Rest | 249 | 1286831 | 514 | PortalSpellID: User-Freigabe nach Crosscheck DBM, EnhanceQoL, Chonky und Wowhead-PTR; LFG: PTR C_LFGList.GetActivityInfoTable | 2026-07-13 | verified | deDE Koenigsruh; castbarer Portalspell Path of the Slumbering Conqueror; Instanz-mapID 1762 bleibt getrennt von ChallengeMapID 249 |
| midnight_s2 | Ruby Life Pools | 399 | 393256 | 1176 | PortalSpellID: User-Freigabe nach Crosscheck DBM, EnhanceQoL, Chonky und Wowhead-PTR; PTR C_Spell.GetSpellInfo; LFG: PTR C_LFGList.GetActivityInfoTable | 2026-07-13 | verified | deDE Rubinlebensbecken; bereits ingame verifizierter castbarer Portalspell Pfad des Nestverteidigers bestaetigt; Instanz-mapID 2521 bleibt getrennt von ChallengeMapID 399 |
| midnight_s2 | Temple of Sethraliss | 250 | 1286828 | 504 | PortalSpellID: User-Freigabe nach Crosscheck DBM, EnhanceQoL, Chonky und Wowhead-PTR; LFG: PTR Blizzard-Activity-Suche | 2026-07-13 | verified | deDE Tempel von Sethraliss; castbarer Portalspell Path of the Sacred Temple; Instanz-mapID 1877 bleibt getrennt von ChallengeMapID 250 |

## Ruhestein-Intake

| Season | Name | ToyID | Source | VerifiedAt | Status | Notiz |
| --- | --- | --- | --- | --- | --- | --- |
| midnight_s2 | unresolved | unresolved | unresolved | unresolved | unresolved | Neue Ruhesteine erst nach verifizierter Quelle eintragen |

## Mount-Intake

| Season | Name | SpellID | Source | VerifiedAt | Status | Notiz |
| --- | --- | --- | --- | --- | --- | --- |
| midnight_s2 | unresolved | unresolved | unresolved | unresolved | unresolved | Neue Mounts erst nach verifizierter Quelle eintragen |
