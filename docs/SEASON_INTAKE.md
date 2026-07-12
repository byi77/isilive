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

Aktueller Stand `2026-07-12`: `0/8 verified`, `8/8 partial`. Alle acht Mythic+-LFG-Activity-IDs und der Portalspell fuer Rubinlebensbecken sind verifiziert. Alle acht ChallengeMapIDs, sieben Portalspells und die M+-Forces-Daten bleiben unresolved. `midnight_s1` bleibt bis zur ausdruecklichen manuellen Umstellung aktiv.

## Dungeon-Intake

| Season | Dungeon | ChallengeMapID | PortalSpellID | LFGActivityID | Source | VerifiedAt | Status | Notiz |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| midnight_s2 | Altar of Fangs | unresolved | unresolved | 1933 | PTR Blizzard-Activity-Suche nach Mythic+-Activities; PTR /isilive seasondump | 2026-07-12 | partial | deDE Der Altar der Faenge; Activity 1933 ist laut Blizzard-API Altar der Faenge (Mythischer Schluesselstein), mapID=2993 und difficultyID=8; vor dem Eingang ohne Key: GetInstanceInfo name=Kammern von Atal'Utek type=none difficultyID=0 mapID=2916 groupSize=5 instanceID=0, playerBestMapID=2509, activeChallengeMapID=nil, activeLfgEntry=nil; Betreten auf Mythisch war auf dem PTR noch nicht verfuegbar; Activity-mapID 2993, Aussenbereich-mapID 2916 und playerBestMapID 2509 werden ohne direkten Challenge-Mode-Nachweis nicht als ChallengeMapID uebernommen |
| midnight_s2 | Murder Row | unresolved | unresolved | 1950 | PTR /isilive seasondump; PTR Blizzard-Activity-Suche nach Mythic+-Activities | 2026-07-12 | partial | deDE Moerdergasse; Activity 1950 ist laut Blizzard-API Moerdergasse (Mythischer Schluesselstein), mapID=2813 und difficultyID=8; im Dungeon: GetInstanceInfo type=party difficultyID=23 mapID=2813 groupSize=5 instanceID=5, playerBestMapID=2433, activeChallengeMapID=nil, activeLfgEntry=nil; Activity-/Instanz-mapID 2813 wird ohne direkten Challenge-Mode-Nachweis nicht als ChallengeMapID uebernommen |
| midnight_s2 | Den of Nalorakk | unresolved | unresolved | 1952 | PTR /isilive seasondump; PTR Blizzard-Activity-Suche nach Mythic+-Activities | 2026-07-12 | partial | deDE Nalorakks Bau; Activity 1952 ist laut Blizzard-API Nalorakks Bau (Mythischer Schluesselstein), mapID=2825 und difficultyID=8; im Dungeon: GetInstanceInfo type=party difficultyID=23 mapID=2825 groupSize=5 instanceID=5, playerBestMapID=2564, activeChallengeMapID=nil, activeLfgEntry=nil; Activity-/Instanz-mapID 2825 wird ohne direkten Challenge-Mode-Nachweis nicht als ChallengeMapID uebernommen |
| midnight_s2 | The Blinding Vale | unresolved | unresolved | 1949 | PTR /isilive seasondump; PTR Blizzard-Activity-Suche nach Mythic+-Activities | 2026-07-12 | partial | deDE Das blendende Tal; Activity 1949 ist laut Blizzard-API Das blendende Tal (Mythischer Schluesselstein), mapID=2859 und difficultyID=8; vor dem Eingang: GetInstanceInfo name=Harandar type=none difficultyID=0 mapID=2694 groupSize=5 instanceID=0, playerBestMapID=2413, activeChallengeMapID=nil, activeLfgEntry=nil; Betreten auf Mythisch war auf dem PTR mit der Meldung "noch nicht auf mythisch verfuegbar" blockiert; Activity-mapID 2859 wird ohne direkten Challenge-Mode-Nachweis nicht als ChallengeMapID uebernommen |
| midnight_s2 | Voidscar Arena | unresolved | unresolved | 1951 | PTR /isilive seasondump; PTR Blizzard-Activity-Suche nach Mythic+-Activities | 2026-07-12 | partial | deDE Arena der Leerennarbe; Activity 1951 ist laut Blizzard-API Arena der Leerennarbe (Mythischer Schluesselstein), mapID=2923 und difficultyID=8; vor dem Eingang: GetInstanceInfo name=Leerensturm type=none difficultyID=0 mapID=2771 groupSize=5 instanceID=0, playerBestMapID=2444, activeChallengeMapID=nil, activeLfgEntry=nil; Betreten auf Mythisch war auf dem PTR mit der Meldung "noch nicht auf mythisch verfuegbar" blockiert; Activity-mapID 2923 wird ohne direkten Challenge-Mode-Nachweis nicht als ChallengeMapID uebernommen |
| midnight_s2 | King's Rest | unresolved | unresolved | 514 | PTR /isilive seasondump; PTR C_LFGList.GetActivityInfoTable(513/514) | 2026-07-12 | partial | deDE Koenigsruh; Activity 513 ist laut Blizzard-API Koenigsruh (Mythisch), mapID=1762, difficultyID=23, isMythicActivity=true und isMythicPlusActivity=false; Activity 514 ist Koenigsruh (Mythischer Schluesselstein), mapID=1762, difficultyID=8 und isMythicPlusActivity=true; die beobachtete LFG-mapID 1762 wird ohne direkten Challenge-Mode-Nachweis nicht als ChallengeMapID uebernommen; vor dem Eingang: GetInstanceInfo name=Zandalar type=none difficultyID=0 mapID=1642 groupSize=5 instanceID=0, playerBestMapID=862, activeChallengeMapID=nil, activeLfgEntry=nil; im Dungeon ohne eingelegten Key: GetInstanceInfo name=Koenigsruh type=party difficultyID=23 mapID=1762 groupSize=5 instanceID=5, playerBestMapID=1004, activeChallengeMapID=nil, activeLfgEntry=nil |
| midnight_s2 | Ruby Life Pools | unresolved | 393256 | 1176 | PTR C_Spell.GetSpellInfo("Pfad des Nestverteidigers"); PTR eigenes Mythic+-Listing und C_LFGList.GetActivityInfoTable(1176) | 2026-07-12 | partial | deDE Portalspell Pfad des Nestverteidigers verifiziert; Activity 1175 ist laut Blizzard-API Rubinlebensbecken (Mythisch), mapID=2521, difficultyID=23, isMythicActivity=true und isMythicPlusActivity=false; Activity 1176 ist Rubinlebensbecken (Mythischer Schluesselstein), mapID=2521, difficultyID=8 und isMythicPlusActivity=true; die beobachtete LFG-mapID 2521 wird ohne direkten Challenge-Mode-Nachweis nicht als ChallengeMapID uebernommen; Dungeon war beim frueheren PTR-Test noch nicht freigeschaltet; Outdoor-Dump vor Eingang: GetInstanceInfo name=Dracheninseln type=none difficultyID=0 mapID=2444, playerBestMapID=2022; Listing-Dumps im Leerensturm: GetInstanceInfo type=none mapID=2771, playerBestMapID=2444, activeChallengeMapID=nil |
| midnight_s2 | Temple of Sethraliss | unresolved | unresolved | 504 | PTR /isilive seasondump; PTR Blizzard-Activity-Suche nach mapID=1877 | 2026-07-12 | partial | deDE Tempel von Sethraliss; die Blizzard-API-Suche nach mapID=1877 lieferte Activity 504 als Tempel von Sethraliss (Mythischer Schluesselstein), isMythicPlusActivity=true und difficultyID=8; Activity 503 und 542 sind Normal, 505 ist Heroisch und 645 ist normales Mythisch; vor dem Eingang: GetInstanceInfo name=Zandalar type=none difficultyID=0 mapID=1642 groupSize=5 instanceID=0, playerBestMapID=864, activeChallengeMapID=nil, activeLfgEntry=nil; im Dungeon ohne eingelegten Key: GetInstanceInfo name=Tempel von Sethraliss type=party difficultyID=23 mapID=1877 groupSize=5 instanceID=5, playerBestMapID=1038, activeChallengeMapID=nil, activeLfgEntry=nil; die beobachtete Activity-/Instanz-mapID 1877 wird ohne direkten Challenge-Mode-Nachweis nicht als ChallengeMapID uebernommen |

## Ruhestein-Intake

| Season | Name | ToyID | Source | VerifiedAt | Status | Notiz |
| --- | --- | --- | --- | --- | --- | --- |
| midnight_s2 | unresolved | unresolved | unresolved | unresolved | unresolved | Neue Ruhesteine erst nach verifizierter Quelle eintragen |

## Mount-Intake

| Season | Name | SpellID | Source | VerifiedAt | Status | Notiz |
| --- | --- | --- | --- | --- | --- | --- |
| midnight_s2 | unresolved | unresolved | unresolved | unresolved | unresolved | Neue Mounts erst nach verifizierter Quelle eintragen |
