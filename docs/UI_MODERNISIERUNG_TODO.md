# UI-Modernisierung nach Prioritaet

Stand: 2026-09-27. Abgehakt wird nach Implementierung und deterministischer Pruefung. Eine noch ausstehende Sichtpruefung im WoW-Client steht getrennt.

## P1 — Orientierung und Zustaende

- [x] Feste, lokalisierte Abschnittsnavigation fuer alle zehn Settings-Bereiche mit Sprungmarken und aktivem Abschnitt implementieren und deterministisch pruefen.
- [ ] Abschnittsnavigation im WoW-Client bei verschiedenen UI-Skalen und langen lokalisierten Texten visuell pruefen. Der deutsche Screenshot bei normaler Skala ist geprueft; kleine Skala und lange andere Sprachen stehen aus.
- [x] Direkte Vorschau und Standardwert-Aktion fuer Anzeige-Settings konzipieren und umsetzen.
- [x] Main-UI-Hierarchie von Gruppenwerten, M+-Run-Zone und Leader-Aktionen verbessern.
- [ ] Verfuegbar-, Cooldown-, Kampf- und Leader-Sperren mit einheitlichem Icon-/Text-/Helligkeitsmuster gestalten. Das gemeinsame Muster und die Live-Zustaende fuer Leader-Sperre und Share-Keys-Cooldown sind umgesetzt; fuer eine echte Kampf-Sperranzeige fehlt weiterhin ein belegter Aktionsstatus, da der Kampfzustand allein nicht beweist, dass diese Aktion gesperrt ist.
- [x] Center-Notices fuer Information, Warnung und Portal-Aktion klar differenzieren. Notices verwenden zusaetzlich zur gemeinsamen Kartenflaeche einen semantischen Marker und Farbstreifen; Warnfelder stufen die Karte als Warnung ein, Portal-Navigator-Karten als Aktion.

## P2 — Bewegung und Nebenflaechen

- [x] Kurze, konsistente Einblend- und Statuswechsel-Animationen definieren und umsetzen. Center-Notices blenden mit einer 0,14-Sekunden-Alpha-Animation ein; ein Wechsel der Notice-Kategorie startet denselben Uebergang erneut. Portal-Navigator-Karten nutzen denselben kurzen Uebergang.
- [x] Option fuer reduzierte Animationen ergaenzen. Die Anzeigeoption schaltet dekorative Notice-Fades und Portal-Zielpulse sofort ab; Inhalt und statische Zielmarkierung bleiben sichtbar.
- [x] Gemeinsame Bewegungs-Tokens (`UICommon.Motion`: 0,14 / 0,2 / 0,35 s) und zentraler Alpha-Uebergang `UICommon.PlayAlphaTransition` mit Register; reduzierte Animationen stoppen alle registrierten Uebergaenge sofort (Regel 125).
- [x] Death-/PI-Alert respektiert reduzierte Animationen: ohne Scale-Punch und Einblendung, gleiche Standzeit, Ausblenden bleibt (Regel 125).
- [ ] Death-Alert mit reduzierter Animation im WoW-Client visuell pruefen.
- [x] M+-Timer als Zeitleiste: 2-px-Leiste am unteren Innenrand der Timerbox mit +3/+2-Markierungen und Fuellfarbe der erreichbaren Stufe; aktive Stufe voll deckend, uebrige auf 50 %, einmaliges Aufblenden beim Stufenwechsel (Regel 126).
- [ ] Zeitleiste und Stufenfokus im WoW-Client pruefen (Demo-Simulation und echter Key, auch bei kleiner UI-Skala).
- [x] Killtracker: ruhiges Blau bis 99,99 %, Gruen ab 100 % (Gelb/Rot-Warnbaender entfallen), weiche Breitenaenderung ueber 0,2 s, einmaliges Aufblenden bei 100 %, Dezimaltrennzeichen nach isiLive-Sprache (Regel 127).
- [ ] Killtracker-Bewegung und Pull-Balken waehrend eines echten Pulls im WoW-Client pruefen.
- [x] Center-Notice und Portal-Navigator blenden beim Erscheinen von 0 auf 1 ueber 0,2 s ein; Kategoriewechsel behalten den kurzen Refresh; hoechstens ein Alpha-Uebergang pro Frame; Ausblenden bleibt sofort (Regel 128).
- [x] Offline-Mitglieder und Ghost-Zeilen im Roster als ganze Zeile abgedunkelt (Daten 45 %, Name 75 %) (Regel 129).
- [ ] Notice-Einblendung und abgedunkelte Roster-Zeilen im WoW-Client pruefen (Lesbarkeit bei niedriger Hintergrund-Deckkraft).
- [x] Zustandssymbole aus belegten Client-Texturen statt ASCII: Aktions-Sperren, Notice-Kategorien, Tode-Symbol der M+-Timerbox, Schloss und Zahnrad in der Titelleiste (Regel 130).
- [x] BR/BL mit Cooldown-Swipe, leerer BR entsaettigt; `BR: --`/`BL: --` bleiben wegen Regel 71 (Regel 131).
- [x] Weltmarker-Buttons mit kuehlem Hover und vom Client lokalisierten Markernamen (Regel 132).
- [x] Flache Checkboxen in Settings und Main-UI-Systemoptionen (Regel 133).
- [ ] Symbole, Swipes, Marker-Hover und Checkboxen im WoW-Client pruefen, besonders Groesse/Ausschnitt der Zustandssymbole bei 12-16 px.
- [x] Center-Notice-Teleport-Button mit Cooldown-Swipe wie im Portal-Grid (Regel 134).
- [x] ESC-Panel-Buttons ohne doppelten Hover (Regel 135).
- [x] Statsbox: dauerhaft unsichtbaren Werte-Prozent-Trennstrich entfernt; der 1-s-Refresh bleibt, weil Buff-Procs nicht zuverlaessig ein registriertes Event ausloesen.
- [x] Center-Notice-Karten modernisiert (Regel 70 angepasst): Kopfband mit Kategorie-Chip (Symbol + Eyebrow in Kategoriefarbe) und Marke `isiLive`, Headline ohne `isiLive - ` in `TEXT_HEADING`, Akzentlinie oben in Kategoriefarbe, Feldzeilen mit Haarlinien und Labels ohne Doppelpunkt, Warnzeile als roter Streifen mit ruhigem 1,2-s-Alpha-Puls (55-100 %, bei reduzierten Animationen statisch), Portal-Kachel mit Rahmen und Label-Streifen unten. Behoben: Kategorie-Symbol lag ueber dem Eyebrow; beim Kartenwechsel blieben Zeilen der vorherigen Karte sichtbar. Der Portal-Navigator nutzt denselben Kartenkopf (Aktionskarte, Halbkreis 12 px tiefer). Galerie inkl. Navigator: `lua tools/wowsim/wowsim.lua center_notice_cards`.
- [ ] Neue Center-Notice-Karten im WoW-Client pruefen (Chip-Symbol 14 px, Markenposition neben dem Schliessen-Button, Portal-Kachel mit Dungeon-Artwork, Warnstreifen bei niedriger Deckkraft, lange frFR/ruRU-Titel, Portal-Navigator-Kopf und Halbkreis-Abstand).
- [ ] Timer-Ziffern ruhiger machen (B10): rechtsbuendig wuerde mit den festen 48-px-Feldern in das naechste Stufenbadge ragen; erst nach Pruefung der Ziffernbreiten im Client oder einer Layout-Entscheidung.
- Nicht umgesetzt (bewusste Entscheidung): Center-Notice-Position speichern (D2) - die Position ist laut Code absichtlich nicht persistent.
- [x] Roster: 2-px-Klassenfarbstreifen links (grau fuer inaktive Zeilen) und kurz eingeblendetes Hover-Highlight (Regel 136).
- [x] Roster: Ready-Check-Toenung blendet bei neuem Status ein; Restzeitleiste des 20-s-Nachhaltefensters per Scale-Animation (Regel 137). Die Restzeit des laufenden Ready-Checks selbst wird nicht angezeigt, weil `GetReadyCheckTimeLeft` nicht belegt ist.
- [ ] Klassenstreifen, Hover und Ready-Check-Restzeitleiste im WoW-Client pruefen (Streifen neben rechtsbuendigen langen Spec-Namen, Leiste am Zeilenrand).
- [x] Hauptfenster blendet beim Oeffnen ausserhalb des Kampfs ein (Regel 138); reduzierte Animationen setzen nur noch laufende Uebergaenge zurueck, damit der Kampf-Fade nicht ueberschrieben wird (Regel 125).
- [x] Statsbox: geaenderte Werte blenden kurz auf, Settings-Aenderungen nicht (Regel 139).
- [x] Settings-Slider mit gefuelltem Anteil, 12-px-Regler und Hover (Regel 140).
- [x] Schrift-Dropdown zeigt jede Schrift in ihrer eigenen Schriftart (Regel 141).
- [ ] Hauptfenster-Einblendung, Statsbox-Aufblenden bei Procs, Slider und Schrift-Vorschau im WoW-Client pruefen.
- Nicht umgesetzt (bewusste Entscheidung): Spielername unter dem Death-Alert (D4) - in einer 5er-Gruppe benennt die Rolle die Person bereits eindeutig. Rahmen fuer die entsperrte Statsbox (E2) - widerspricht Regel 65 ("rahmenlos").
- [x] Farbpalette konsolidiert (A3): 11 fast gleiche Kompatibilitaetsfarben (<= 0,05 je Kanal, gleiche Bedeutung) in bestehende Tokens zusammengelegt, 4 ungenutzte entfernt, Fallbacks angeglichen, Notice-Feldfarben aus Tokens; ein Waechtertest verhindert neue Beinahe-Duplikate (Regel 142).
- [ ] Farbwirkung nach der Konsolidierung im WoW-Client pruefen (Settings-Rahmen, ESC-Panel, Portal-Navigator, Killtracker-Pulltext).
- Offen zur Machbarkeitspruefung: Verlaeufe (A4), schraffierte Pull-Vorhersage (B6), Abschluss-Banner (B11).
- [x] M+-Run-Zone und kompakte Layouts auf schnelle Erfassbarkeit ueberarbeiten. Im kompakten M+-Layout sind der Prozentwert auf 14 px und der Fortschrittsbalken auf 10 px hervorgehoben; Breite, Zeilenhoehe, Daten und Farben bleiben erhalten.
- [x] ESC-Panels und Teleport-Grid in Gruppierung und Zustaenden angleichen. Tooling, Travel, Mounts und Addons sind in benannten Panel-Flaechen gruppiert und verwenden denselben semantischen Sekundaerbutton-Stil; das Portal-Grid zeigt Abklingzeit, Verfuegbarkeit und aktives Ziel getrennt.

## P3 — Lesbarkeit im Detail

- [x] Statsbox-Zahlen und Zeilenabstaende optisch verfeinern, bei unveraenderten Stat-Farben. Zahlen- und Prozentwerte sind 1 px groesser als Labels; der Zeilenabstand hat 18 px Grundmass und skaliert mit der Schriftoption. Die gepflegten Statfarben bleiben unveraendert.
- [ ] Nameplates und LFG-Marker mit echten Client-Screenshots auf kleine UI-Skalen pruefen.
- [x] Tooltip-Breiten, Abstaende und Zahlenformatierung angleichen. Private Tooltip-Karten starten wie Roster-Tooltips bei 220 px Breite mit 10 px Seitenrand und 3 px Zeilenabstand; kompakte Rosterzahlen nutzen Blizzards `AbbreviateNumbers`, soweit verfuegbar.

## P4 — Modern-Design (Branch `feature/mplus-ui-redesign`, Regel 233)

Stand: 2026-11-03, in `main` (Version 0.9.478, kein Tag). Ruecksprungpunkt: Tag `isiLive_release_0.9.477`. Alles Modern liegt hinter dem Schalter `IsiLiveDB.uiDesign` (Einstellungen > Allgemein > Design, `/isilive design classic|modern`, wirkt ausserhalb des Kampfs sofort). Seit 2026-11-03 ist Modern der Standard; Classic bleibt waehlbar und unveraendert.

Plan nach Stufen (zusammengefuehrt 2026-11-02 aus beiden Planungs-Chats). Abgehakt = umgesetzt und deterministisch geprueft; Simulator-Vorschau mit `--savedvars`-Datei `IsiLiveDB = { uiDesign = "modern" }`.

### Grundlage

- [x] Design-Schalter Classic/Modern: Settings-Selektor unter "Standard-Layout beim Oeffnen", Slash-Befehl, Schema-Sanitizer, Locale in fuenf Sprachen.
- [x] Repaint-Grundlage (die frueher offene Luecke "Farben bleiben nach /reload Classic"): `ApplyBackdrop` merkt sich Flaechen, `PaintToken` beim Bau gefaerbte Regionen, `RegisterDesignSurface` Flaechen ohne Backdrop, `RepaintDesign` malt nach ADDON_LOADED neu; dazu `DesignBackdropPresets`, `DesignDecorators`, `DesignAvailabilityBorders`, `DesignComponents`.
- [x] wowsim rendert `SetGradient`-Verlaeufe.
- [x] wowsim: `WHITE8X8` mit Vertex-Farbe als Vollflaeche (Forces-Fuellung, Pull-Segment sichtbar) und Kreismaske als runder Ausschnitt (BR/BL-Icons).
- [~] wowsim: andere Masken, `CreateLine`-Linien und Textur-Slicing — nicht noetig, solange isiLive sie nicht nutzt (siehe unten).
- Hinweis: wowsim zeigte den Readycheck-Verlauf korrekt, der Client deckend weiss — Verlaeufe auf Render-Pfaden immer ingame pruefen.
- [~] Mockups vor dem Code: uebersprungen, stattdessen direkt Code mit Simulator-Vorschau und Ingame-Screenshots je Schritt (User-Entscheidung "lass sehen was du kannst").

- [x] Design-Wechsel ohne `/reload` ausserhalb des Kampfs (2026-11-03); im Kampf weiter gespeichert und nach `/reload` wirksam.
- [ ] Live-Wechsel ingame pruefen (Settings-Schalter und `/isilive design`, hin und zurueck, auch mit offener Gruppe).

### Stufe 1 — Skin

- [x] Palette: Grafit-Flaechen, neue Modern-Werte nur fuer bestehende Tokens.
- [x] Rahmen: Haarlinien statt Kaesten, dezenter Schatten, Akzentlinie oben, Titel-Schimmer, Glanz auf Fenster und Buttons. Echte 9-Slice-/Rundungs-Rahmen noch nicht (siehe offen).
- [x] Kopfzeile und Spaltenkoepfe gedaempft, Version gedaempft.
- [x] Einheitliche Buttons ohne Rahmen; alle Aktionsbuttons gleich ruhig, keine blaue Hauptaktion mehr (User-Entscheidung 2026-11-02, `DesignButtonRoles`); gesperrte Buttons nur abgedunkelt.
- [x] Run-Karten (BR/BL, Timer, Tracker) als Flaechen mit Akzentstreifen links.
- [x] Zebra-Zeilen (bestehendes `ROW_ALT`, in Modern leicht angepasst).
- [x] Ruhigere Zeilen: Readycheck als halb so kraeftige Toenung statt Vollton-Zeile, ohne zweiten Farbstreifen neben der Klassenfarbe (Verlauf war ingame deckend weiss, ersetzt) (Komponente `READY_CHECK_ROW`).
- [x] Typografie, erster Schritt: Text-Rollen (`RegisterDesignText`); BR/BL-Werte kuehl-weiss statt Blizzard-Gold.
- [ ] Typografie, weiter: Groessenstufen fuer Labels und Werte (Schriftart bleibt User-Wahl); Kandidaten erst ingame bewerten.
- [x] Abgerundete Ecken fuer Hauptfenster (6 px, Ring, runder Titelbalken) und Run-Karten (4 px), aus Einzelteilen statt Textur-Slicing; neue Texturen `media/corner_disc.tga` / `corner_ring6.tga` (Generator `tools/generate_rounded_corners.py`).
- [x] Abgerundete Ecken ingame geprueft (2026-11-03, User-Screenshot): Ecken sauber, Ring durchgehend, Schatten folgt der Rundung (`media/corner_shadow.tga`), keine Ecken-Kaestchen.
- [x] Buttons abgerundet (3 px): Aktions-, Titel- und Schliessen-Buttons malen ihre Zustandsfarbe ueber `PaintButtonSurface` auf eine runde Flaeche (`DesignButtonShapes`).
- [ ] Runde Buttons ingame pruefen: Hover, Druck, gesperrt, Schliessen-Button rot beim Hover.
- [~] Portal-Kacheln bleiben eckig (Bild abrunden braeuchte eine verzerrte Maske).

### Stufe 2 — Komponenten

- [x] Timer (`MPLUS_TIMER`): verstrichene Zeit gross vor dem Limit, Zeitleiste mit +3/+2-Markern, nur erreichbare Stufe mit Restzeit, Ueberzeit rot.
- [x] Killtracker-Leiste: 12 px, Haarlinie, Glas-Glanz, leere Spur halbtransparent. Boss-Abschnitte und Pull-Segment gab es schon in Classic und bleiben.
- [x] Teleport-Kacheln: Bild fast randlos, Haarlinie, Verlauf unter dem Kuerzel, Hover.
- [x] Runde Cooldown-Sweeps fuer BR/BL: runde Icons (Portraet-Kreismaske), feiner Ring, runder Swipe (`RUN_ICONS`).
- [ ] Ingame pruefen: runde BR/BL-Icons, Ring und Swipe nach einem BR bzw. Bloodlust (wowsim zeigt keine Masken).
- [x] Demo zeigt BR/BL-Werte jetzt auch solo und ausserhalb eines Keys (vorher `BR: --` / `BL: --`, Kontext-Sperre der Anzeige).
- [~] Kick: hat kein Icon (Textspalte im Roster); ein runder Swipe braeuchte neue Bauteile — vorerst nicht.

### Stufe 3 — Relayout (nur wenn noetig, nur nach User-OK)

- [x] Symmetrisches M+-Raster fuer beide Designs (User-Entscheidung 2026-11-02): Inhalt 8 px links und rechts, Titeltext und Titel-Buttons 8 px vom Rand, Kopfband und Kopf-Trennlinien bis zum Fensterrand, einheitlich 4 px zwischen Roster, Buttons, Portalen, BR/BL+Timer und Tracker. Portal-Zeile nutzte vorher eigene Ersatzwerte (10/70), weil sie vor dem Layout-Modul laedt.
- [x] Raster M+ ingame geprueft mit 1 und 5 Gruppenmitgliedern (User-Screenshots 2026-11-02).
- [ ] Raster H und V ingame pruefen.

- [ ] Hinweis "Benoetigt noch ..." und TTK in die Tracker-Karte holen (Box hoeher, verschiebt das Fensterlayout).
- [x] H- und V-Layout im Modern-Design im Simulator geprueft: gleiche Anordnung wie Classic, Palette, rahmenlose Buttons, Fenster-Dekoration; kein Nachziehen noetig.
- [ ] H- und V-Layout ingame ansehen (Titel-Schimmer ohne Titeltext, schmale Fenster).

### Uebrige Flaechen

- [x] Einstellungsfenster und Center-Notices im Modern-Design im Simulator geprueft (0 Fehler, Layout unveraendert).
- [ ] ESC-Panel und Statsbox im Modern-Design ingame ansehen (ESC-Panel-Buttons sind jetzt rahmenlos).

### Ingame-Pruefung (User)

- [ ] Grundlook, Buttons, Portal-Kacheln (Kuerzel lesbar, Cooldown-Swipe, Zielmarkierung).
- [ ] Timer im echten Key: Stufenwechsel +3 → +2 → +1, Ueberzeit, Key-Ende; Demo-Vorschau `/il testall` vorab.
- [ ] Forces-Leiste waehrend eines Pulls (Pull-Segment, Abschnitts-Ticks, Zeitstreifen, Run-End-Banner).

### Spaeter / optional

- [x] AddonCompartment-Eintrag (2026-11-03): Linksklick Fenster, Rechtsklick Einstellungen, Tooltip wie am Minimap-Button.
- [x] LuaLS-Annotationen, erster Schritt: Design-API in `UICommon`, `MplusTimerData`, `DBSchema` (2026-11-03).
- [x] LuaLS-Annotationen, zweiter Schritt: `ContextHelpers`, `KillTrack` (`KillTrackData`), `RosterPanelController` (2026-11-03).
- [x] Alte lokale Branches aufgeraeumt (2026-11-03): `backup/pre-trailer-cleanup` (Inhalt in `main`), Dependabot-Checkout (in `main` bereits v7.0.1), `feature/ace-support-log-transfer` (geparkter Support-Paket-Spike vom 2026-05-28 mit Ace3-Libs; gesichtet und am 2026-11-03 auf User-Wunsch endgueltig verworfen, Archiv-Tag geloescht).
- [~] Simulator-Ausbau nicht noetig (2026-11-03): isiLive nutzt keine Line-Regionen (`CreateLine` in der Loadout-Karte ist ein eigener Helfer fuer Textzeilen) und kein Textur-Slicing; die einzige Maske (Kreis fuer BR/BL) rendert wowsim bereits. Wieder aufgreifen, sobald eine dieser APIs im Addon auftaucht.
- [~] Object Pools, MenuUtil, LibEditMode: vorerst nicht (User-Entscheidung 2026-11-03, nur risikoarme Punkte).
- [ ] LibEditMode (Vor-/Nachteile besprochen 2026-11-02, neue Abhaengigkeit) — erst nach dem Redesign entscheiden.
- [ ] ruRU-Text "Модерн" von jemandem mit Russischkenntnissen pruefen lassen.
- [x] Abschluss: Redesign am 2026-11-03 per Fast-Forward nach `main` gefuehrt (`a538be0`), Modern als Standard, einmalige Migration aller Nutzer auf Modern (Schema-Schritt 5); Feature-Branch geloescht.
- [x] Release-Commit `release(v0.9.479)` mit README, `CHANGELOG_RELEASE.md` (Highlights, Pruefvermerk 0.9.479) und Baseline-Sync (2026-11-03).
- [ ] Tag `isiLive_release_0.9.479` und CurseForge-Release nur auf ausdrueckliche Freigabe.

Verworfen (User-Entscheidung 2026-11-02): Roster entschlacken (Version nur im Tooltip, DPS/Kick erst ab Key-Start, Flagge nur bei Fremdsprache).
