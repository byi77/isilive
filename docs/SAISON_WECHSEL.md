# Saisonwechsel-Checkliste

Diese oeffentliche Checkliste ist bei jedem Wechsel auf eine neue Mythic+-Season
abzuarbeiten. Die einzige manuell gepflegte Runtime-Saisonquelle ist
`data/isiLive_seasons.lua`. Technische IDs werden niemals geraten. Unbekannte
Werte bleiben `unresolved` und blockieren den betroffenen Schritt.

## 0. Wartbarkeits-Todos (Analyse vom 2026-11-20)

Ziel: null erwartbare und null verhinderbare Fehler beim Saisonwechsel, isiLive
an Tag 0 voll einsatzbereit. Grundannahme (User, 2026-11-20): Die neuen Dungeons
sind im Normalfall vorher bekannt, ihre IDs lassen sich vorab ueber Wowhead
o. ae. oder den PTR auslesen. Die Season wird deshalb immer **vor** dem Start
vorbereitet und released; die Laufzeit-Absicherungen unten decken nur Nutzer
ohne Update und Blizzard-Ueberraschungen ab. Paketreihenfolge laut Analyse;
jedes Paket wird erst auf ausdrueckliches Kommando begonnen.

Paket 1 (P0):
- [x] C: Patchsichere Event-Registrierung (Regel 258). Ein entferntes oder
  umbenanntes Event legt nicht mehr alle folgenden Events still; der Selbsttest
  meldet es. Gate `raw-event-registration` in `tools/check_wow_api_compliance.lua`.
- [x] A: Unbekannte Season bedient keine Altdaten (Regel 259). Keine Portale,
  kein Navigator, keine LFG-Zuordnung, keine Forces-DB der alten Season;
  Client-Namen und Instanz-IDs der neuen Maps kommen nur von Blizzard.

Paket 2 (P0/P1):
- [x] B: Forces-DB je Season (Regel 260, `MPlusForcesBySeason`). Der Sync
  schreibt die aktive Season und die `upcomingSeasonID`, sobald MDT sie
  vollstaendig liefert; das Lifetime-Gate prueft jede Sektion einzeln. Die
  Mobprozente einer vorbereiteten Season laufen ab dem Starttag ohne Release.
- [x] F: Patch-Waechter und Datenpruefung (Regel 261). Einmal pro Client-Build
  laeuft der Selbsttest 20 s nach dem Login still, Chatzeile nur bei Problemen.
  `/isilive selftest` prueft zusaetzlich Portal-Spells, Challenge-Maps und
  LFG-Activities (inkl. Instanz-Abgleich) der bedienten Season, das
  Spell-Manifest und die Consumables. Auf dem PTR ausgefuehrt ist das die
  Datenpruefung der neuen Season in einem Befehl.
- [ ] Offen aus F: Kick-Spells (`SPEC_DATA`) und das Keystone-Item kommen in
  die Datenpruefung, sobald sie in Paket 5 (J) in Manifeste unter `data/`
  gezogen sind. In-Game bestaetigen, dass `GetMapUIInfo` und
  `GetActivityInfoTable` direkt nach dem Login ohne vorherige Anfrage antworten
  (sonst meldet der Patch-Waechter faelschlich `MISSING`).

Paket 3 (P0/P1):
- [ ] D: Taeglicher Workflow liest die Build-Versionen von Live/PTR/Beta aus
  Blizzards Versions-Endpunkt (URL vor Umsetzung pruefen) und oeffnet ein Issue,
  wenn die Interface-Nummer in `isiLive.toc` fehlt. Die TOC selbst wird nur auf
  ausdruecklichen Auftrag geaendert.
- [ ] E: Workflow gleicht die von isiLive genutzten APIs, Events und
  `Enum`-Felder mit `Gethe/wow-ui-source` (Branches `live`/`ptr`/`beta`,
  `Blizzard_APIDocumentationGenerated`) ab und meldet entfernte oder geaenderte
  Signaturen per Issue (PTR-Vorlauf als Warnzeit).

Paket 4 (P1):
- [ ] G: Test rendert alle 32 Belegungen der Navigator-Slots ueber den echten
  Layout-Builder (Clipping/Ueberlappung). Anlass: Clipping-Fix am S2-Starttag,
  weil erstmals der mittlere Slot belegt war.
- [ ] H: Generisches `wowsim season_smoke --season=<id>`, Erwartungswerte aus
  `docs/SEASON_INTAKE.md` statt kopierter Tabelle je Season.
- [ ] I: Season-ID-Literale aus `testmodul/` entfernen (Stand: 85x die aktive
  Season-ID). Tests auf Produktionsdaten lesen `activeSeasonID` und das Intake,
  Verhaltenstests nutzen die Fixture-Season; Gate gegen neue Literale.

Paket 5 (P1/P2):
- [ ] J: Hartkodierte IDs ausserhalb `data/` in Manifeste verschieben und per
  Gate sperren: Keystone `180653` (`logic/isiLive_keysync.lua`,
  `core/isiLive_context_helpers.lua`), Kick-`SPEC_DATA`
  (`game/isiLive_kick_tracker.lua`), DK-Spells (`game/isiLive_vip_dk_assist.lua`),
  Spec `1473` (`ui/isiLive_lfg_bonus_model.lua`).
- [ ] K: `activityIDs` im Manifest optional machen (die Laufzeit leitet sie
  ueber Instanz-ID ab, Regel 252). Ob enUS/deDE-Namen Pflicht bleiben
  (Regeln 97/98), entscheidet der User.
- [ ] N: Ein Befehl `lua tools/season_doctor.lua [--season=<id>]` fuehrt alle
  automatisierbaren Pruefungen aus und listet nur die offenen Punkte; diese
  Checkliste schrumpft danach auf die echten Ingame-Punkte.
- [ ] O: Eigener Abschnitt Erweiterungswechsel (Keystone-Item,
  Consumable-Set, neue Drums/Pet-Lust, neue Specs, Levelcap und
  `minimumPlayerLevel`, neue Hub-Zone), jeweils mit Gate.

Paket 6 (P2, Komfort):
- [ ] L: `/isilive seasondump draft` auf dem PTR schreibt einen Manifest-Entwurf
  (Maps, Namen, Zeitlimit, Instanz-IDs, Activities ueber
  `C_LFGList.GetAvailableActivities`, Portal-Kandidaten aus dem
  Hero's-Path-Flyout, Hub-Zone) in die SavedVariables; ein Tool erzeugt daraus
  Manifest-Eintrag und Intake-Zeilen mit `Status = candidate`. Freigabe bleibt
  beim User.
- [ ] M: Workflow prueft alle IDs aus `data/` gegen DB2-Daten der PTR-Builds
  (`MapChallengeMode`, `GroupFinderActivity`, `SpellName`; Quelle und
  Nutzungsbedingungen vorher pruefen) und meldet neue Challenge-Maps.

Bekannt und ohne Paket: Der Simulator-Erwartungswert "the dungeon card is the
calm season-break hint" (`lua tools/wowsim/wowsim.lua offseason`) schlaegt
bereits auf 0.9.524 fehl und ist zu untersuchen. `docs/RULES.md` (Season-Rahmen)
nennt noch eine frische Forces-DB als Bedingung fuer die automatische Umstellung;
seit Regel 97 ist die Forces-DB kein Aktivierungskriterium mehr. Der Satz ist
nachzuziehen.

Zeitplan je Season (Ziel):
- T-8 Wochen (PTR): Dungeons und IDs aus Wowhead/PTR ins Intake (`candidate`),
  Manifest-Eintrag anlegen, `upcomingSeasonID` setzen; auf dem PTR
  `/isilive selftest` (keine `MISSING event`-Zeilen) und `/isilive seasondump`.
- T-4 Wochen: User-Freigabe der IDs -> `verified`; Intake, Readiness,
  Simulator-Smoke gruen; PTR-Interface-Nummer auf Auftrag in die TOC.
- T-2 Wochen: MDT-Daten pruefen, `autoDetectFromChallengeMaps = true`, Release.
- Tag 0: nichts zu tun; die Auswahl wechselt automatisch.
- T+1 Woche: `activeSeasonID` umstellen, `upcomingSeasonID` leeren, Nachweis.

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
  Argument auf sie. `sync_mdt_forces.lua` schreibt sie zusaetzlich als eigene
  Sektion in die Forces-DB, sobald MDT alle ihre Dungeons liefert (Regel 260).
- [ ] `activeSeasonID` in dieser Phase noch nicht umstellen.
- [ ] Keine saisonalen Zuordnungstabellen in LFG-, Status-, Demo-, UI- oder
  Tooldateien duplizieren.

## 3. Optionale MDT-Forces-Daten

- [ ] Pruefen, ob fuer die neue Season ein vollstaendiger und verifizierter
  MythicDungeonTools-Datensatz existiert.
- [ ] Falls `requiresForces = true`, `lua tools/sync_mdt_forces.lua` ausfuehren
  und den erzeugten Datensatz kontrollieren. Ohne `--season` schreibt das Tool
  die aktive Season und die `upcomingSeasonID` (Regel 260); die Ausgabe nennt
  `seasons=...`. Fehlt dort die neue Season, liefert MDT sie noch nicht
  vollstaendig ("upcoming season left out"). Ziel: die neue Sektion ist im
  Release vor dem Start enthalten.
- [ ] `data/isiLive_mplus_forces.lua` niemals von Hand bearbeiten.
- [ ] `lua tools/check_mplus_db_lifetime.lua` erfolgreich ausfuehren. Das Gate
  prueft Ablaufdatum und Struktur (Season-Match, Gesamtwert und NPC-Abdeckung
  je Season-Map) fuer die `activeSeasonID`.
- [ ] Fehlen verifizierte Forces-Daten, die MDT-abhaengigen Anzeigen fail-closed
  lassen und keine Ersatzwerte erzeugen.

## 3b. Verbrauchsgueter-Check (Regel 246, optional)

`data/isiLive_consumables.lua` fuehrt je Erweiterung einen Satz (`sets.<name>`) mit den
Aura-Spell-IDs von Essen (`food`: nur Referenz-Buffs fuer den Namen "Well Fed" bzw. "Hearty
Well Fed", jedes Gericht hat eine eigene ID), Flask (`flask`, ein Buff je Flask) und
Augment-Rune (`augmentRune`). `disabled` schaltet eine Kategorie ab, ohne die Daten zu
verlieren (Stand 2026-11-12: Essen und Rune aus). Eine Season findet ihren Satz am Namen
(`midnight_s3` -> `midnight`): eine **neue Season** derselben Erweiterung braucht hier
nichts. Eine **neue Erweiterung** braucht einen neuen Satz (Name = Season-ID ohne `_s<Zahl>`);
bis dahin schlaegt der Test "Consumable check finds a buff set for every season of the
manifest" fehl. Eine Season-ID, die nicht dem Muster folgt, bekommt einen Eintrag in
`seasonSets`. Neue Rangstufen oder Varianten derselben Erweiterung (andere Flask-Buffs, neue
Rune) einfach im Satz ergaenzen. Leere Listen werden nicht geprueft, das Waffenoel braucht keine IDs. Pruefen im
Live-Client: mit `/isilive probe on` schreibt jeder Ready-Check die Spell-IDs der eigenen
Buffs (`[PROBE] event=ready_check ... spellIDs=...`); einen Ready-Check mit Essen, Flask und
Rune aufnehmen und mit den Listen vergleichen.

## 3c. Saisonpause (zwischen zwei Seasons)

Die Erkennung der Saisonpause (Regel 250) setzt voraus, dass Blizzard in der Pause eine
leere Challenge-Map-Liste liefert. Das ist noch nicht ingame belegt und muss in der ersten
Pause nachgewiesen werden.

- [ ] In der Pause einloggen, einmal den Mythic+-Reiter oeffnen (fordert die Map-Daten an)
  und `/isilive seasondump` ausfuehren. Diese Zeilen notieren:
  - `[SEASON] blizzardSeasonState=` (erwartet: `offseason`)
  - `[SEASON] challengeMapTable count= maps=` (erwartet: `count=0`)
  - `[SEASON] C_MythicPlus.GetCurrentSeason=` und `GetCurrentUIDisplaySeason=`
  - `[SEASON] rewardLevels +2= +6= +10=`
  - `[SEASON] activeSeasonID=`
- [ ] Befund mit Datum in `docs/WARTUNG.md` Abschnitt 3.4a eintragen.
- [ ] Je nach Befund:
  - `count=0` und `offseason`: Erkennung bestaetigt, nichts weiter zu tun.
  - `count=8` mit den Maps der alten Season: Blizzard liefert die alte Liste weiter,
    isiLive verhaelt sich wie in der Season. Regel 250 und WARTUNG 3.4a anpassen; ob
    `GetCurrentSeason` als zweiter Ausloeser dient, entscheidet der User.
  - Maps der neuen Season und `unrecognized`: neue Season vorbereiten (Abschnitte 1 und 2).
- [ ] Pruefen: Chat-Hinweis "isiLive: Saisonpause ..." (einmal pro Sitzung), ruhige
  Dungeon-Karte ohne Blinken (30 s), in Heroisch laufen Kick-Tracker und CD-Zeile (volles
  Profil, Regel 250). Ohne Spiel: `lua tools/wowsim/wowsim.lua offseason`.
- [ ] Erscheint stattdessen der Chat-Hinweis "isiLive kennt die aktuelle Mythic+-Season
  nicht", liefert Blizzard bereits den neuen Mapsatz: die neue Season vorbereiten
  (Abschnitte 1 und 2) und releasen; bis dahin lernen Zeit- und Forces-Tempo nicht,
  und Portale, Navigator und LFG-Zuordnung bleiben leer (Regel 259).
- [ ] Scheitert der MDT-Sync, weil MDT sein Verzeichnis umbaut, laufen die Mobprozente im
  Client weiter (kein Laufzeit-Ablauf); ein Hotfix-Release braucht dann
  `ISILIVE_ALLOW_STALE_MPLUS_DB=1`.

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
- [ ] `/isilive selftest` (PTR und Patch-Tag): keine `MISSING`- oder `ERROR`-Zeilen,
  insbesondere keine `MISSING event ...` (Regel 258) und keine fehlenden
  Portal-Spells, Challenge-Maps oder LFG-Activities der Season (Regel 261).
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
- [ ] `data/isiLive_forces_seed.lua` und `data/isiLive_time_seed.lua` sind generiert
  (privater Workspace, `research/mplus-timepace`). Dort die neue Season eintragen;
  Werte nie aus anderen Addons uebernehmen.
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
- [ ] Die Forces-DB `data/isiLive_mplus_forces.lua` darf keine Sektion der alten
  Season mehr enthalten: einmal `lua tools/sync_mdt_forces.lua` laufen lassen
  (schreibt nur aktive und kommende Season) und
  `lua tools/check_mplus_db_lifetime.lua` pruefen (eine Sektion einer nicht
  konfigurierten Season laesst das Gate scheitern).
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
- In-Game-Smoke-Test: `[ ] enUS  [ ] deDE` (offen: echte Portale, echte Gruppensuche, Zonentext im Client)
- Simulator-Smoke-Test: `[x] enUS  [x] deDE` (2026-10-28, `lua tools/wowsim/wowsim.lua season_s2_smoke --locale <tag>`: je 64/64 — Reihenfolge, Portal-Spells, Namen, LFG-Activity→Dungeon, LFG-Einladung je Dungeon mit Ziel-Ansage und Teleport-Highlight, Navigator-Titel/Slots/leere Aussenplaetze)
- Voller lokaler CI-Lauf: `[x] gruen`
