# UI-Modernisierung nach Prioritaet

Stand: 2026-09-27. Abgehakt wird nach Implementierung und deterministischer Pruefung. Eine noch ausstehende Sichtpruefung im WoW-Client steht getrennt.

## P1 — Orientierung und Zustaende

- [x] Feste, lokalisierte Abschnittsnavigation fuer alle zehn Settings-Bereiche mit Sprungmarken und aktivem Abschnitt implementieren und deterministisch pruefen.
- [ ] Abschnittsnavigation im WoW-Client bei verschiedenen UI-Skalen und langen lokalisierten Texten visuell pruefen. Der deutsche Screenshot bei normaler Skala ist geprueft; kleine Skala und lange andere Sprachen stehen aus.
- [x] Direkte Vorschau und Standardwert-Aktion fuer Anzeige-Settings konzipieren und umsetzen.
- [x] Main-UI-Hierarchie von Gruppenwerten, M+-Run-Zone und Leader-Aktionen verbessern.
- [ ] Verfuegbar-, Cooldown-, Kampf- und Leader-Sperren mit einheitlichem Icon-/Text-/Helligkeitsmuster gestalten. Das gemeinsame Muster und die Live-Zustaende fuer Leader-Sperre und Share-Keys-Cooldown sind umgesetzt; die Anzeige eines tatsaechlichen Kampf-Sperrzustands wird erst nach sicherer Client-Pruefung an eine Aktion gebunden.
- [ ] Center-Notices fuer Information, Warnung und Portal-Aktion klar differenzieren.

## P2 — Bewegung und Nebenflaechen

- [ ] Kurze, konsistente Einblend- und Statuswechsel-Animationen definieren und umsetzen.
- [ ] Option fuer reduzierte Animationen ergaenzen.
- [ ] M+-Run-Zone und kompakte Layouts auf schnelle Erfassbarkeit ueberarbeiten.
- [ ] ESC-Panels und Teleport-Grid in Gruppierung und Zustaenden angleichen.

## P3 — Lesbarkeit im Detail

- [ ] Statsbox-Zahlen und Zeilenabstaende optisch verfeinern, bei unveraenderten Stat-Farben.
- [ ] Nameplates und LFG-Marker mit echten Client-Screenshots auf kleine UI-Skalen pruefen.
- [ ] Tooltip-Breiten, Abstaende und Zahlenformatierung angleichen.
