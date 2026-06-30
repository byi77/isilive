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

## Dungeon-Intake

| Season | Dungeon | ChallengeMapID | PortalSpellID | LFGActivityID | Source | VerifiedAt | Status | Notiz |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| midnight_s2 | Altar of Fangs | unresolved | unresolved | unresolved | unresolved | unresolved | unresolved | PTR/Live verifizieren |
| midnight_s2 | Murder Row | unresolved | unresolved | unresolved | unresolved | unresolved | unresolved | PTR/Live verifizieren |
| midnight_s2 | Den of Nalorakk | unresolved | unresolved | unresolved | unresolved | unresolved | unresolved | PTR/Live verifizieren |
| midnight_s2 | The Blinding Vale | unresolved | unresolved | unresolved | unresolved | unresolved | unresolved | PTR/Live verifizieren |
| midnight_s2 | Voidscar Arena | unresolved | unresolved | unresolved | unresolved | unresolved | unresolved | PTR/Live verifizieren |
| midnight_s2 | King's Rest | unresolved | unresolved | unresolved | unresolved | unresolved | unresolved | PTR/Live verifizieren |
| midnight_s2 | Ruby Life Pools | unresolved | unresolved | unresolved | unresolved | unresolved | unresolved | PTR/Live verifizieren |
| midnight_s2 | Temple of Sethraliss | unresolved | unresolved | unresolved | unresolved | unresolved | unresolved | PTR/Live verifizieren |

## Ruhestein-Intake

| Season | Name | ToyID | Source | VerifiedAt | Status | Notiz |
| --- | --- | --- | --- | --- | --- | --- |
| midnight_s2 | unresolved | unresolved | unresolved | unresolved | unresolved | Neue Ruhesteine erst nach verifizierter Quelle eintragen |

## Mount-Intake

| Season | Name | SpellID | Source | VerifiedAt | Status | Notiz |
| --- | --- | --- | --- | --- | --- | --- |
| midnight_s2 | unresolved | unresolved | unresolved | unresolved | unresolved | Neue Mounts erst nach verifizierter Quelle eintragen |
