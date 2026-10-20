# Reise-Intake

Diese Datei ist die Sammelstelle fuer Ruhestein-Toys, Mount-Spells und feste
Reise-Items des ESC-Travel- und Mount-Panels. Diese Daten sind nicht saisonal;
neue Eintraege kommen mit Patches, Events oder dem Shop. Die Runtime-Quelle ist
`data/isiLive_travel_items.lua`, das Gate `tools/check_travel_items.lua`.

Maschinenregeln:
- `Status` ist `unresolved`, `candidate`, `partial` oder `verified` (gleicher
  Vertrag wie `docs/SEASON_INTAKE.md`).
- `unresolved` bedeutet: ID, `Source` und `VerifiedAt` bleiben `unresolved`.
- `verified` bedeutet: die ID ist numerisch belegt und hat `Source` plus `VerifiedAt` (`YYYY-MM-DD`).
- `Patch` ist eine Patch-Version (`12.0.5`) oder `unresolved`.
- Werte werden nicht geraten. Ohne belastbare Quelle bleibt der Wert `unresolved`.
- Jede `verified`-Zeile muss mit derselben ID und demselben `VerifiedAt` im
  Datenfile stehen, und jeder `verified`-Eintrag im Datenfile braucht seine
  `verified`-Zeile hier. Eintraege mit `legacy` (Bestand vor 2026-10-20 ohne
  dokumentierte Herkunft) brauchen keine Zeile.

Neuer Ruhestein: Zeile hier eintragen, dann einen Datensatz in
`data/isiLive_travel_items.lua` (`hearthstoneToys`) mit `verification.status =
"verified"`, `source` und `verifiedAt`; bedingte Toys nutzen `requires`.

## Ruhestein-Intake

| Patch | Name | ToyID | Source | VerifiedAt | Status | Notiz |
| --- | --- | --- | --- | --- | --- | --- |
| unresolved | unresolved | unresolved | unresolved | unresolved | unresolved | Neue Ruhesteine erst nach verifizierter Quelle eintragen |

## Mount-Intake

| Patch | Name | SpellID | Source | VerifiedAt | Status | Notiz |
| --- | --- | --- | --- | --- | --- | --- |
| unresolved | unresolved | unresolved | unresolved | unresolved | unresolved | Neue Mounts erst nach verifizierter Quelle eintragen |

## Reise-Item-Intake

| Patch | Name | ItemID | Source | VerifiedAt | Status | Notiz |
| --- | --- | --- | --- | --- | --- | --- |
| unresolved | Personal Key to the Arcantina | 253629 | warcraft.wiki.gg Personal_Key_to_the_Arcantina; wowhead item=253629 | 2026-10-20 | verified | `arcantinaKeyItemID`; englischer Itemname lautet "Arcantina"; `/use item:253629` braucht noch In-Game-Bestaetigung |
