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
