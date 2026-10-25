# Saisonwechsel-Checkliste

Diese oeffentliche Checkliste ist bei jedem Wechsel auf eine neue Mythic+-Season
abzuarbeiten. Die einzige manuell gepflegte Runtime-Saisonquelle ist
`data/isiLive_seasons.lua`. Technische IDs werden niemals geraten. Unbekannte
Werte bleiben `unresolved` und blockieren den betroffenen Schritt.

## 1. Daten sammeln und verifizieren

- [ ] Neue Season in `docs/SEASON_INTAKE.md` anlegen, ohne sie zu aktivieren.
  Die verifizierten Zeilen der laufenden Season bleiben stehen; das Gate prueft
  jede Season im Intake einzeln. Solange die neue Season nicht im Manifest
  steht, duerfen ihre Zeilen noch nicht `verified` sein.
- [ ] Fuer jeden Dungeon `ChallengeMapID`, castbare `PortalSpellID` und
  Mythic+-`LFGActivityID` aus belastbaren Quellen erfassen.
- [ ] Fuer jeden konkreten Wert `Source`, `VerifiedAt` und `Status` pflegen.
- [ ] Englische und deutsche Namen sowie Default-/deDE-Kurzcodes bestaetigen.
- [ ] Anzeige-Reihenfolge, optionale Mindeststufe und Portalraum-Slots
  ausdruecklich festlegen.
- [ ] Unbekannte Werte als `unresolved` stehen lassen; keine Kandidaten als
  Runtime-Daten uebernehmen.
- [ ] `lua tools/check_season_intake.lua` erfolgreich ausfuehren.

## 2. Saisonmanifest vorbereiten

- [ ] In `data/isiLive_seasons.lua` einen neuen Season-Eintrag hinzufuegen;
  historische Eintraege nicht ueberschreiben.
- [ ] Jeden Dungeon genau einmal als vollstaendigen Datensatz eintragen.
- [ ] `autoDetectFromChallengeMaps` bewusst setzen. Solange noch Dungeonzeilen
  unverifiziert sind, bleibt der Wert `false`. Nach `8/8 verified` darf er schon
  vor dem Season-Start auf `true` stehen: die Auswahl ist ein exakter Abgleich
  gegen `C_ChallengeMode.GetMapTable()`, eine vorbereitete Season gewinnt also
  erst, wenn Blizzard sie tatsaechlich ausliefert.
- [ ] `requiresForces`, `inactivePortalMessageByLocale` und `portalNavigator`
  bewusst festlegen. `requiresForces` ist ein reines Build-/CI-Gate fuer die
  generierte Forces-DB (`SeasonData.GetForcesReadiness`) und entscheidet nie
  ueber die Season-Aktivierung; eine vorbereitete Season darf `true` tragen,
  bevor ihre eigene Forces-DB existiert.
- [ ] `portalNavigator.zone` gegen den echten Portalraum pruefen (Map-IDs und
  Zonennamen). Eine falsche Zone laesst den Navigator stumm geschlossen.
- [ ] `mdtDirectory` nur mit verifiziertem exaktem MDT-Verzeichnis setzen.
  Fehlt es bei `requiresForces = false`, ueberspringt `sync_mdt_forces.lua`
  den Lauf bewusst und laesst die bestehende DB unangetastet.
- [ ] `upcomingSeasonID` auf die neue Season setzen. Die Season-Tools
  (`inspect_mdt_season_preview.lua`, Preview-Workflow) zielen dann ohne
  Argument auf sie; `sync_mdt_forces.lua` bleibt bewusst bei `activeSeasonID`.
- [ ] `activeSeasonID` in dieser Phase noch nicht umstellen.
- [ ] Keine saisonalen Zuordnungstabellen in LFG-, Status-, Demo-, UI- oder
  Tooldateien duplizieren.

## 3. Optionale MDT-Forces-Daten

- [ ] Pruefen, ob fuer die neue Season ein vollstaendiger und verifizierter
  MythicDungeonTools-Datensatz existiert.
- [ ] Falls `requiresForces = true`, `lua tools/sync_mdt_forces.lua` ausfuehren
  und den erzeugten Datensatz kontrollieren.
- [ ] `data/isiLive_mplus_forces.lua` niemals von Hand bearbeiten.
- [ ] `lua tools/check_mplus_db_lifetime.lua` erfolgreich ausfuehren. Das Gate
  prueft Ablaufdatum und Struktur (Season-Match, Gesamtwert und NPC-Abdeckung
  je Season-Map) fuer die `activeSeasonID`.
- [ ] Fehlen verifizierte Forces-Daten, die MDT-abhaengigen Anzeigen fail-closed
  lassen und keine Ersatzwerte erzeugen.

## 4. Aktivierung

- [ ] `lua tools/inspect_season_readiness.lua` ausfuehren und alle gemeldeten
  Luecken klaeren. Die Spalte `Ready` ist die Aktivierungsbereitschaft; die
  Spalte `Forces` und der Abschnitt `M+ Forces gate` zeigen getrennt davon den
  Stand der Forces-DB und blockieren keine Aktivierung.
- [ ] Die bewusste Freigabe des Users fuer den Saisonwechsel einholen.
- [ ] Regelfall: Steht `autoDetectFromChallengeMaps = true` und stimmt der
  Mapsatz, wechselt die Season zur Laufzeit von selbst — auch ohne passende
  oder mit abgelaufener Forces-DB; dann bleiben nur die MDT-Mob-Anzeigen zu.
  `activeSeasonID` bleibt dabei unveraendert, und die CI-Gates laufen weiter
  gegen die alte Season.
- [ ] Fallback: Nur wenn kein Datensatz exakt passt (Blizzards Mapsatz weicht
  vom Manifest ab), `activeSeasonID` in `data/isiLive_seasons.lua` umstellen.
  Danach `lua tools/check_mplus_db_lifetime.lua` pruefen — bei
  `requiresForces = true` muss fuer den Release vorher eine passende Forces-DB
  erzeugt sein (Build-Gate, keine Laufzeit-Sperre).
- [ ] Sobald die neue Season aktiv ist, `upcomingSeasonID` wieder entfernen.
- [ ] TOC-Version und `## Interface` nur nach ausdruecklichem Auftrag erhoehen.

## 5. Deterministische und In-Game-Pruefung

- [ ] `lua tools/check_season_intake.lua` erneut ausfuehren.
- [ ] `lua tools/validate_usecases.lua` erfolgreich ausfuehren.
- [ ] Portalbuttons auf richtigen Dungeon, richtigen Zauber und richtige
  Reihenfolge pruefen.
- [ ] LFG-Erkennung fuer jeden neuen Dungeon pruefen.
- [ ] Portal-Navigator, lokalisierte Namen, Kurzcodes und leere Slots pruefen.
  Namen ausserhalb `enUS`/`deDE` kommen aus `C_ChallengeMode.GetMapUIInfo`
  und muessen nicht ins Manifest.
- [ ] Demo-Modus (`Ctrl + Alt + F9`) oeffnen: Dummy-Keys, Demo-Ziel und
  Demo-Navigator muessen die neue Season zeigen. Sie leiten sich aus
  `SeasonData` ab; dafuer ist keine Code-Aenderung noetig.
- [ ] Verhalten mit nicht erlernten Portalen und laufenden Cooldowns pruefen.
- [ ] Blizzard-Forces-Fortschritt sowie aktivierte oder bewusst deaktivierte
  MDT-abhaengige Mob-Anzeigen pruefen.
- [ ] TTK pruefen: `/isilive ttktest` an der Trainingspuppe (Zahl in der
  Lebensleiste, Testpanel `Auswertung: ok`), danach im ersten Key der neuen
  Season `evaluated=true` in `IsiLiveDB.ttkDebug`. Fuer Bosse, Minibosse und
  Caster der neuen Dungeons an echten Packs kontrollieren, dass der Filter
  „nur wichtige Gegner“ sie erkennt. Der TTK hat keine Saisondaten; Details und
  Fehlersuche stehen in `docs/WARTUNG.md` Abschnitt 3.15.
- [ ] Zeit-Tempo und Forces-Tempo brauchen keine Pflege: beide lernen je
  `seasonID` und starten in der neuen Season leer (Prognose statt Vergleich,
  kein Zielstrich), bis die ersten eigenen Runs abgeschlossen sind.
- [ ] Mindestens `enUS` und `deDE` im Spiel kontrollieren.

## 6. Dokumentation, Release und CI

- [ ] `README.md`, `docs/ARCHITECTURE.md`, `docs/USECASES.md`,
  `docs/WARTUNG.md` und bei Bedarf `docs/RULES.md` aktualisieren.
- [ ] `docs/CHANGELOG.md` und `CHANGELOG_RELEASE.md` aktualisieren.
- [ ] Maintainer spiegeln dauerhafte interne Wartungs-Learnings zusaetzlich in
  den dafuer vorgesehenen privaten Workspace; externe Beitragende ueberspringen
  diesen internen Schritt.
- [ ] Den vollstaendigen lokalen CI-Lauf starten:
  `powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate_ci_local.ps1`.
- [ ] Erst abschliessen, wenn CI, Coverage-Gates und alle Simulatoren gruen sind.
- [ ] Commit, Push oder Release nur nach ausdruecklichem User-Auftrag ausfuehren.

## 7. Alte Season entfernen (optional)

Eine beendete Season darf aus `data/isiLive_seasons.lua` entfernt werden, muss
aber nicht. Sie bleibt sonst als manueller Fallback und fuer die exakte
Mapset-Erkennung erhalten. Tests haengen nicht an historischen Seasons: Wer
"irgendeine zweite Season" braucht, nutzt die synthetische Fixture-Season aus
`testmodul/isilive_test_fixture_seasons.lua` (geprueft am 2026-10-20, als
`midnight_s1` probeweise entfernt wurde: alle Usecases und Simulatoren gruen).

- [ ] Nur entfernen, wenn die Nachfolge-Season aktiv ist: `activeSeasonID` zeigt
  nicht mehr auf die alte Season, und `lua tools/inspect_season_readiness.lua`
  meldet die aktive Season als bereit.
- [ ] `upcomingSeasonID` darf nicht auf die alte Season zeigen.
- [ ] Die Forces-DB `data/isiLive_mplus_forces.lua` darf nicht fuer die alte
  Season erzeugt sein (`lua tools/check_mplus_db_lifetime.lua`).
- [ ] Die Intake-Zeilen der alten Season in `docs/SEASON_INTAKE.md` gleichzeitig
  entfernen: `verified`-Zeilen einer Season, die nicht mehr im Manifest steht,
  lassen `tools/check_season_intake.lua` scheitern.
- [ ] Den Saison-Nachweis unten (Abschlussnachweis) als Historie stehen lassen.
- [ ] Danach den vollstaendigen lokalen CI-Lauf ausfuehren
  (`powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate_ci_local.ps1`).
- [ ] Tests, die bewusst echte Produktionsdaten pruefen (Manifestinhalt der
  aktiven Season, Intake-Drift, Forces-DB-Abgleich), beziehen sich auf die
  aktive Season; Literal-IDs einer entfernten Season duerfen dort nicht
  stehen bleiben.

## Abschlussnachweis

- Season-ID: `____________________`
- Aktivierungsdatum: `____________`
- Freigegeben durch: `____________`
- Intake: `[ ] gruen`
- Readiness: `[ ] gruen`
- Usecases: `________ passed, 0 failed`
- Coverage: `________ %`
- In-Game-Smoke-Test: `[ ] enUS  [ ] deDE`
- Voller lokaler CI-Lauf: `[ ] gruen`

### Nachweis Midnight Season 2

Vorlage oben bleibt fuer den naechsten Wechsel leer. Werte am 2026-10-07 gegen
den Stand 0.9.418 erhoben; Aktivierung aus der Git-Historie.

- Season-ID: `midnight_s2`
- Aktivierungsdatum: `2026-09-06` (Commit `f162c6b`, ausgeliefert mit `isiLive_release_0.9.383`)
- Freigegeben durch: `byi77`
- Intake: `[x] gruen` (`check_season_intake.lua`: valid, 8/8 verified)
- Readiness: `[x] gruen` (`inspect_season_readiness.lua`: ready yes, 8 Dungeons, Forces-DB passt zur aktiven Season)
- Usecases: `2573 passed, 0 failed`
- Coverage: `93.08 %`
- In-Game-Smoke-Test: `[ ] enUS  [ ] deDE` (offen: Portalbuttons, LFG-Erkennung je Dungeon, Navigator-Slots)
- Voller lokaler CI-Lauf: `[x] gruen`
