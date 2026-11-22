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
- [x] Kick-Spells (`KickTracker.GetInterruptSpellIDs()`) und das Keystone-Item
  (neu `data/isiLive_items.lua`, `ItemManifest.mythicKeystone`) sind in der
  Datenpruefung; das Keystone-Literal steht nur noch dort (Test "Item manifest
  owns the keystone item ID"). Das Verschieben von `SPEC_DATA` nach `data/`
  bleibt Paket 5 (J).
- [x] Generator mit echtem MDT-Lauf geprueft (2026-11-20, MDT-Cache 6.3.31):
  aktive plus kommende Season ergibt zwei Abschnitte, ohne MDT-Daten der
  kommenden Season nur die aktive mit Hinweis; dauerhaft gepinnt mit einem
  kleinen MDT-Baum im Test "MDT forces sync writes a prepared season once MDT
  ships it and leaves it out before".
- [x] In-Game bestaetigt (User, 2026-11-20, Build 70961): der Patch-Waechter
  meldete 2 Probleme, beide geklaert. `C_Item.GetAverageItemLevel` fehlt in
  12.1, die Laufzeit nutzt das globale `GetAverageItemLevel` (Selbsttest kennt
  jetzt Ausweich-APIs); Rune-Buff 1295329 kennt der Client nicht und wurde auf
  User-Entscheidung entfernt. Danach `/isilive selftest`: 35/35 APIs, 74/74
  Daten-IDs ok. Nebenbei gefunden und behoben: `/isilive selftest` und
  `/isilive errorlog` liefen seit 0.9.521 ins Leere (Bootstrap reichte die
  Optionen nicht weiter); `errorlog status` zeigt jetzt `installed`.

Paket 3 (P0/P1):
- [x] D: Woechentlicher Workflow `.github/workflows/patch-watch.yml`
  (User-Entscheidung 2026-11-21: mittwochs 12 Uhr deutscher Zeit, 11:00 UTC) prueft mit
  `tools/check_toc_interface.lua`, ob die Interface-Nummer von Live und jedem
  neueren Test-Client (PTR, xPTR, Beta) in `isiLive.toc` steht; fehlt eine,
  oeffnet er das Issue "Patch Watch: TOC interface". Die TOC aendert er nie
  (Regel 262). Stand 2026-11-20: Live 12.1.5 (120105) und PTR 12.1.7 (120107)
  stehen beide in der TOC.
- [x] E: Derselbe Workflow vergleicht mit `tools/check_api_surface.lua` die von
  isiLive genutzten Blizzard-Funktionen, Events und Enums zwischen Live und
  PTR/PTR2/Beta (generierte API-Doku aus `Gethe/wow-ui-source`) und oeffnet bei
  `removed`/`changed` das Issue "Patch Watch: API surface". Geprueft gegen
  12.1.7 (70986): `GetInstanceInfo` bekommt hinten `instanceServerID`
  (kompatibel); `PARTY_INVITE_REQUEST` bekommt `isCrossShard` in der Mitte
  des Payloads, der isiLive-Handler liest kein Payload, deshalb in
  `tools/patch_watch_ack.lua` quittiert. Ein geprueft harmloser Fund wird dort
  mit exaktem Detailtext und Begruendung eingetragen; nach dem Patch-Tag
  wieder entfernen.
- Termin (User, 2026-11-20): Patch 12.1.7 kommt am 2026-12-02, nur ein Patch,
  keine neue Season. `## Interface: 120105, 120107` deckt ihn bereits ab.
  Am Patch-Tag die Patch-Waechter-Chatzeile bzw. `/isilive selftest` pruefen.
  Die Quittierung `PARTY_INVITE_REQUEST` meldet der API-Abgleich selbst zum
  Entfernen, sobald kein Fund sie mehr braucht (Hinweis im Issue).

Paket 4 (P1):
- [x] G: wowsim-Szenario `navigator_layouts` rendert alle 32 Belegungen der
  Navigator-Slots mit den laengsten Dungeonnamen und prueft: jeder Text in der
  Karte, keine Ueberlappung, kein abgeschnittener einzeiliger Text (Regel 263,
  alle fuenf UI-Sprachen, in der CI). wowsim schaetzt dafuer jetzt auch
  Zeilenumbrueche. Gegenprobe: mit der alten zu knappen Kartenhoehe meldet es
  112 Funde, genau den S2-Starttag-Fehler.
- [x] H: wowsim-Szenario `season_smoke` fuer jede Season (`--season <id>`,
  Standard `upcomingSeasonID`, sonst `activeSeasonID`). Blizzard fuehrt im
  Simulator die gewaehlte Season, isiLive muss zur Laufzeit umschalten (echte
  Tag-0-Probe); IDs kommen aus `docs/SEASON_INTAKE.md`. Ersetzt
  `season_s2_smoke`. In der CI in enUS und deDE.
- [x] I: Tests laufen auf einem eingefrorenen Referenz-Stand der Season-Daten
  (`testmodul/isilive_test_reference_seasons.lua`,
  `testmodul/isilive_test_reference_forces.lua`). Ein Saisonwechsel bricht
  statt 105 nur noch 2 Tests, beide gewollte Erinnerungen (Forces-DB neu
  erzeugen, `docs/WARTUNG.md` auf die neue aktive Season umstellen). Gate:
  nur fest gelistete Testdateien lesen die echten `data/`-Season-Dateien.
- Notiz aus G/H (erledigt 2026-11-21, siehe Nachzuegler): drei veraltete
  wowsim-Szenarien und die fehlende Uebersetzung von "Unbelegt".

Paket 5 (P1/P2):
- [x] J: Interrupt-Daten in `data/isiLive_interrupts.lua`, Augmentation-Bonus
  (Ebon Might) als `lfgSpecBonuses` im Spec-Manifest, Keystone-Item in
  `data/isiLive_items.lua` (Paket 2). Bewusst geblieben: DK-Assist-Spells
  (Modul stillgelegt, Besitzer isiBlightfallTracker) und Map 2662 im
  Teleport-Debug-Befehl (Regel 264).
- [x] K: User-Entscheidung 2026-11-20: LFG-Activity-IDs und deutsche
  Dungeonnamen bleiben Pflichtfelder (keine Aenderung).
- [x] N: `lua tools/season_doctor.lua [--season=<id>] [--no-sim]
  [--versions=<dir>]` fuehrt alle automatischen Pruefungen einer Season aus und
  listet nur das Offene plus die Ingame-Schritte (Regel 264).
- [x] O: Abschnitt "Erweiterungswechsel" unten; neue Specs meldet der
  Selbsttest am Patch-Tag selbst (`MISSING spec <id> - Specs`).

Paket 6 (P2, Komfort):
- [x] M: Der Patch-Waechter prueft jede ID aus `data/` gegen die Spieldaten-
  Tabellen des neuesten Clients (wago.tools DB2, PTR wenn neuer) und meldet
  Fehlendes im Issue "Patch Watch: game data" (Regel 265). Stand 12.1.7: alles ok.
- [x] L: Statt eines Ingame-Dumps erkennt derselbe Lauf eine neue Mythic+-
  Rotation (`MythicPlusSeasonTrackedMap`) und erzeugt Intake-Zeilen
  (`candidate`, mit Quelle) plus Manifest-Geruest: Maps, Namen enUS/deDE,
  Instanz, Timer, Activity und Portal-Spell, mehrdeutige Werte bleiben
  `unresolved` mit allen Kandidaten. Kurzcodes, Reihenfolge und Navigator
  bleiben Handarbeit. Lokal: `lua tools/check_db2.lua --db2=<dir>` (Tabellen wie
  im Workflow laden).

Nachzuegler (erledigt 2026-11-21):
- [x] wowsim: `offseason` und `card_stack` sind seit dem Wegfall der
  What's-New-Karte (0.9.530) wieder gruen; `language_dungeon_names` prueft statt
  der seit 2026-11-13 entfallenen Kartenzeilen (Quelle, Talente) die
  sprachabhaengigen Kartenkoepfe. `tools/run_wowsim_scenarios.lua` fuehrt in CI
  und lokalem Preflight jetzt alle Szenarien aus (Regel 263), damit keines mehr
  unbemerkt veraltet.
- [x] `docs/RULES.md` (Season-Rahmen): Forces-DB nicht mehr als
  Aktivierungsbedingung genannt.
- [x] "Unbelegt" im Portal-Navigator ist in frFR, ruRU und trTR uebersetzt.
- [ ] Saisonpause: in der naechsten Pause `/isilive seasondump` (Abschnitt 3c);
  vorher nicht pruefbar.

Zeitplan je Season (Ziel):
- T-8 Wochen (PTR): Das Issue "Patch Watch: game data" meldet die neue Rotation
  mit fertigen Intake-Zeilen (`candidate`) und Manifest-Geruest: uebernehmen,
  offene Werte (Kurzcodes, Reihenfolge, Navigator, mehrdeutige IDs) klaeren,
  `upcomingSeasonID` setzen; auf dem PTR `/isilive selftest` und
  `/isilive seasondump`; `lua tools/season_doctor.lua` zeigt den Rest.
- T-4 Wochen: User-Freigabe der IDs -> `verified`; Intake, Readiness,
  Simulator-Smoke gruen; PTR-Interface-Nummer auf Auftrag in die TOC.
- T-2 Wochen: MDT-Daten pruefen, `autoDetectFromChallengeMaps = true`, Release.
- Tag 0: nichts zu tun; die Auswahl wechselt automatisch.
- T+1 Woche: `activeSeasonID` umstellen, `upcomingSeasonID` leeren, Nachweis.

## 0b. Erweiterungswechsel (zusaetzlich zu den Season-Schritten)

Eine neue Erweiterung bringt Daten, die eine neue Season derselben Erweiterung
nicht braucht. Erster Schritt immer: `lua tools/season_doctor.lua` und auf dem
PTR `/isilive selftest`.

- [ ] Neue Spezialisierungen: Der Selbsttest meldet `MISSING spec <id> - Specs`.
  Datensatz in `data/isiLive_specs.lua` (alle Pflichtfelder), Interrupt-
  Entscheidung in `data/isiLive_interrupts.lua` (Cooldown aus dem Tooltip),
  dann `lua tools/check_spec_coverage.lua`.
- [ ] Neue oder geaenderte Interrupts und Cooldowns: Skill `interrupt-audit`;
  ein entfernter Spell erscheint als `MISSING interrupt spell <id> - Kicks`.
- [ ] Consumables: neuer Satz in `data/isiLive_consumables.lua` (der Test
  "Consumable check finds a buff set for every season of the manifest" und der
  Season-Doktor melden die Luecke); IDs per `/isilive probe on` beim
  Ready-Check aufnehmen.
- [ ] Bloodlust und Battle Res: neue Drums oder Pet-Faehigkeiten in
  `lustCasts`/`lustSated`/`battleRes` (`data/isiLive_spells.lua`); der
  Selbsttest meldet nur entfernte IDs, neue muessen gesucht werden.
- [ ] Defensiv- und External-Cooldowns (Regel 267, auch bei jedem Klassen-Patch
  innerhalb einer Season): `lua tools/check_db2.lua --db2=<dir>` gegen den neuen
  Build (die Tabellen `SpellCooldowns`, `SpellCategories`, `SpellCategory`
  gehoeren dazu; der Patch-Waechter laedt sie). Er meldet jede entfernte Cast-
  oder Aura-ID, jede Spec-Zuordnung ausserhalb der Klasse und jeden `cooldown`
  in `data/isiLive_defensives.lua`, der nicht mehr zu DB2 passt; der Selbsttest
  meldet `MISSING defensive spell <id> - Defensives`. Neue Defensives, Talent-
  Umbauten und neue Specs sucht niemand automatisch: Liste je Klasse pruefen.
  Cooldowns nur aus DB2 oder dem Spiel-Tooltip, nie aus Fremd-Addons.
- [ ] Defensiv-Schaetzung (Regel 268) nach jedem Patch: `/isilive selftest` muss
  `C_XMLUtil.GetTemplateInfo` (CustomAuraContainerTemplate) und
  `C_CurveUtil.EvaluateColorValueFromBoolean` als ok melden und darf keine Zeile
  `ERROR AuraContainer setup` zeigen; sonst ist die Schaetzung aus. Die
  Sensor-Kette haengt an undokumentiertem Verhalten (Element-Layout +
  `IsMouseOver`): in einem Key mit `defensiveEstimateEnabled` pruefen, dass ein
  External eines Nicht-isiLive-Mitspielers den blauen Rahmen zeigt und danach
  die Fuellung abnimmt; bei Bruch die Probe (`/isilive probe on`, Regel 239)
  als Diagnose nutzen.
- [ ] Mythic Keystone: neues Item nur in `ItemManifest.mythicKeystone`
  (`data/isiLive_items.lua`); der Selbsttest meldet ein unbekanntes Item.
- [ ] Levelcap: `minimumPlayerLevel` der neuen Dungeons im Manifest.
- [ ] Portalraum: neue Hub-Zone (`portalNavigator.zone`, Map-IDs ueber
  `/isilive seasondump` -> `playerBestMapID` im Portalraum).
- [ ] Interface-Nummer und API-Aenderungen: Issues des Patch-Watch-Workflows
  (Regel 262).

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
- [ ] Nach dem Umstellen von `activeSeasonID`: genau zwei Tests duerfen
  fehlschlagen und erinnern an Pflicht-Schritte ("Season readiness inspect ..."
  -> Forces-DB fuer die neue aktive Season erzeugen; "Maintenance doc names
  only the manifest activeSeasonID ..." -> `docs/WARTUNG.md` 3.4 umstellen).
  Jeder weitere Fehlschlag ist ein Fehler.
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
