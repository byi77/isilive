# Season-Intake

Diese Datei ist die strukturierte Sammelstelle fuer kommende Season-Daten.
Sie ist keine Aktivierung der Season. `activeSeasonID` in
`data/isiLive_seasons.lua` bleibt die einzige manuell gepflegte
Runtime-Aktivierung; `SeasonData.ACTIVE_SEASON_ID` spiegelt diesen Wert.

Maschinenregeln:
- `Status` ist `unresolved`, `candidate`, `partial` oder `verified`.
- `unresolved` bedeutet: alle technischen Felder sowie `Source` und `VerifiedAt` bleiben `unresolved`.
- `candidate` bedeutet: es gibt eine Quelle oder einen Fundhinweis, aber noch keine vollstaendig verifizierte ID-Kette.
- `partial` bedeutet: mindestens eine technische ID ist verifiziert, aber nicht alle Pflichtfelder sind vollstaendig.
- `verified` bedeutet: alle Pflichtfelder der Zeile sind numerisch verifiziert und haben `Source` plus `VerifiedAt`.
- `VerifiedAt` nutzt `YYYY-MM-DD`.
- Werte werden nicht geraten. Ohne belastbare Quelle bleibt der Wert `unresolved`.
- `tools/check_season_intake.lua` gleicht verifizierte Dungeonzeilen mit dem
  normalisierten Saisonmanifest ab. ChallengeMapID, PortalSpellID,
  LFGActivityID, Status und VerifiedAt duerfen nicht auseinanderlaufen.
- Die Datei darf Zeilen mehrerer Seasons enthalten. Ohne `--season=<id>` prueft
  `tools/check_season_intake.lua` jede vorkommende Season einzeln; das Gate ist
  nur gruen, wenn jede davon gueltig ist. Verifizierte Zeilen der laufenden
  Season bleiben deshalb stehen, wenn die naechste Season gesammelt wird.
- Eine Season, die noch keinen Eintrag in `data/isiLive_seasons.lua` hat, ist eine
  reine Sammelstelle: ihre Zeilen duerfen `unresolved`, `candidate` oder
  `partial` sein, aber nie `verified`. Erst mit dem Manifest-Eintrag gelten die
  Plan- und Drift-Pruefungen.
- `lua tools/check_season_intake.lua --list-seasons` listet die geprueften Seasons;
  der taegliche Workflow fuehrt pro Season ein eigenes Status-Issue.

Der aktuelle Stand wird nicht als Prosa gepflegt, weil er driftet. Massgeblich sind
die generierten Reports: `lua tools/check_season_intake.lua` (Fortschritt und Fehler
pro Season, taeglich als GitHub-Issue je Season ueber
`.github/workflows/season-intake.yml`) und `lua tools/inspect_season_readiness.lua`
(aktive und vorbereitete Season, Readiness, Forces-Gate).

Freigabe-Nachweis `midnight_s2` (`2026-07-13`): Der User hat die Uebernahme aller acht castbaren PortalSpellIDs nach dem Crosscheck von DBM, EnhanceQoL Teleport Compendium, Chonky Character Sheet und Wowhead-PTR-Spell-Daten ausdruecklich freigegeben. Die `128680x`-Reihe enthaelt die castbaren 10-Sekunden-Portalspells; die abweichenden `128977x`-Instant-Spells werden nicht als Portal-Cast-IDs uebernommen. Die aufsteigende Map-ID-Anzeigereihenfolge ist ausdruecklich freigegeben.

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

## Ruhesteine, Mounts und Reise-Items

Ruhesteine, Mounts und Reise-Items sind nicht saisonal. Ihre Sammelstelle ist
`docs/TRAVEL_INTAKE.md`, das Gate `tools/check_travel_items.lua`.
