# Saisonwechsel-Checkliste

Diese oeffentliche Checkliste ist bei jedem Wechsel auf eine neue Mythic+-Season
abzuarbeiten. Die einzige manuell gepflegte Runtime-Saisonquelle ist
`data/isiLive_seasons.lua`. Technische IDs werden niemals geraten. Unbekannte
Werte bleiben `unresolved` und blockieren den betroffenen Schritt.

## 1. Daten sammeln und verifizieren

- [ ] Neue Season in `docs/SEASON_INTAKE.md` anlegen, ohne sie zu aktivieren.
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
  bewusst festlegen.
- [ ] `portalNavigator.zone` gegen den echten Portalraum pruefen (Map-IDs und
  Zonennamen). Eine falsche Zone laesst den Navigator stumm geschlossen.
- [ ] `mdtDirectory` nur mit verifiziertem exaktem MDT-Verzeichnis setzen.
  Fehlt es bei `requiresForces = false`, ueberspringt `sync_mdt_forces.lua`
  den Lauf bewusst und laesst die bestehende DB unangetastet.
- [ ] `activeSeasonID` in dieser Phase noch nicht umstellen.
- [ ] Keine saisonalen Zuordnungstabellen in LFG-, Status-, Demo-, UI- oder
  Tooldateien duplizieren.

## 3. Optionale MDT-Forces-Daten

- [ ] Pruefen, ob fuer die neue Season ein vollstaendiger und verifizierter
  MythicDungeonTools-Datensatz existiert.
- [ ] Falls `requiresForces = true`, `lua tools/sync_mdt_forces.lua` ausfuehren
  und den erzeugten Datensatz kontrollieren.
- [ ] `data/isiLive_mplus_forces.lua` niemals von Hand bearbeiten.
- [ ] `lua tools/check_mplus_db_lifetime.lua` erfolgreich ausfuehren.
- [ ] Fehlen verifizierte Forces-Daten, die MDT-abhaengigen Anzeigen fail-closed
  lassen und keine Ersatzwerte erzeugen.

## 4. Aktivierung

- [ ] `lua tools/inspect_season_readiness.lua` ausfuehren und alle gemeldeten
  Luecken klaeren.
- [ ] Die bewusste Freigabe des Users fuer den Saisonwechsel einholen.
- [ ] Regelfall: Steht `autoDetectFromChallengeMaps = true` und stimmt der
  Mapsatz, wechselt die Season zur Laufzeit von selbst. `activeSeasonID` bleibt
  dann unveraendert, und die CI-Gates laufen weiter gegen die alte Season.
- [ ] Fallback: Nur wenn kein Datensatz exakt passt (Blizzards Mapsatz weicht
  vom Manifest ab), `activeSeasonID` in `data/isiLive_seasons.lua` umstellen.
  Danach `lua tools/check_mplus_db_lifetime.lua` pruefen — bei
  `requiresForces = true` muss vorher eine passende Forces-DB erzeugt sein.
- [ ] TOC-Version und `## Interface` nur nach ausdruecklichem Auftrag erhoehen.

## 5. Deterministische und In-Game-Pruefung

- [ ] `lua tools/check_season_intake.lua` erneut ausfuehren.
- [ ] `lua tools/validate_usecases.lua` erfolgreich ausfuehren.
- [ ] Portalbuttons auf richtigen Dungeon, richtigen Zauber und richtige
  Reihenfolge pruefen.
- [ ] LFG-Erkennung fuer jeden neuen Dungeon pruefen.
- [ ] Portal-Navigator, lokalisierte Namen, Kurzcodes und leere Slots pruefen.
- [ ] Verhalten mit nicht erlernten Portalen und laufenden Cooldowns pruefen.
- [ ] Blizzard-Forces-Fortschritt sowie aktivierte oder bewusst deaktivierte
  MDT-abhaengige Mob-Anzeigen pruefen.
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
