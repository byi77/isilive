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
- [x] M+-Run-Zone und kompakte Layouts auf schnelle Erfassbarkeit ueberarbeiten. Im kompakten M+-Layout sind der Prozentwert auf 14 px und der Fortschrittsbalken auf 10 px hervorgehoben; Breite, Zeilenhoehe, Daten und Farben bleiben erhalten.
- [x] ESC-Panels und Teleport-Grid in Gruppierung und Zustaenden angleichen. Tooling, Travel, Mounts und Addons sind in benannten Panel-Flaechen gruppiert und verwenden denselben semantischen Sekundaerbutton-Stil; das Portal-Grid zeigt Abklingzeit, Verfuegbarkeit und aktives Ziel getrennt.

## P3 — Lesbarkeit im Detail

- [x] Statsbox-Zahlen und Zeilenabstaende optisch verfeinern, bei unveraenderten Stat-Farben. Zahlen- und Prozentwerte sind 1 px groesser als Labels; der Zeilenabstand hat 18 px Grundmass und skaliert mit der Schriftoption. Die gepflegten Statfarben bleiben unveraendert.
- [ ] Nameplates und LFG-Marker mit echten Client-Screenshots auf kleine UI-Skalen pruefen.
- [x] Tooltip-Breiten, Abstaende und Zahlenformatierung angleichen. Private Tooltip-Karten starten wie Roster-Tooltips bei 220 px Breite mit 10 px Seitenrand und 3 px Zeilenabstand; kompakte Rosterzahlen nutzen Blizzards `AbbreviateNumbers`, soweit verfuegbar.
