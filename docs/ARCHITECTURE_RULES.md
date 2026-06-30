# Architekturregeln

Diese Datei beschreibt verbindliche Strukturregeln fuer den aktuellen Modulzuschnitt.
Im Gegensatz zu `RULES_LOGIC.md` geht es hier nicht um Runtime-Verhalten, sondern um
stabile Architekturgrenzen, die ueber deterministische Strukturtests geprueft werden.

Aktueller Dokumentationsstand: `0.9.341`. Die seit 0.9.310 hinzugekommenen
Runtime- und UI-Aenderungen sind in `RULES_LOGIC.md` als aktive Projektregeln
gepinnt und werden ueber deterministische Szenarien validiert. Native WoW-TTS
ist durch Regel 84 deaktiviert; Death-Audio nutzt statische WAV-Dateien. Der
Locale-Split bleibt durch die bestehenden Locale-Symmetrie- und
TOC-Strukturtests abgedeckt.

## Schreibformat

1. Oben steht eine nummerierte `Regeluebersicht` mit je einem Kurzsatz pro Regel.
2. Darunter folgt pro Regel ein Detailblock mit Heading `### RULE-ID`.
3. Erlaubte Statuswerte:
   - `aktiv`: harte Gate-Regel
   - `entwurf`: vorbereitet, aber noch kein Gate-Blocker
   - `veraltet`: dokumentiert, nicht mehr aktiv erzwungen
   - `deaktiviert`: temporaer deaktiviert
4. Pflichtfelder pro Detailblock:
   - `- Regelnummer: ...`
   - `- Status: ...`
   - `- Zusammenfassung: ...`
   - `- Erforderliche Tests:`
5. Unter `Erforderliche Tests` muessen exakte deterministische Testnamen aus `tools/validate_usecases.lua` stehen.

## Regeluebersicht

1. `isiLive.lua` bleibt Composition Root und delegiert an `Factory.InitializeAddon`, das Runtime-State und Runtime-Setup zentral verdrahtet.
2. `isiLive_event_handlers.lua` bleibt Aggregator fuer Lifecycle-Handler und enthaelt keine direkten Event-Bodies.
3. `isiLive_runtime_setup.lua` erstellt Group- und Event-Controller nur ueber Context-Factories aus `ControllerWiring`.
4. `RuntimeState` bleibt die zentrale API fuer gemeinsam genutzten, mutierbaren Runtime-State.
5. `ControllerWiring` exportiert Context-Factories fuer Group- und Event-Controller.
6. `ConfigBuilders` bleibt fokussiert und fuehrt keine Legacy-Builder fuer Group-/Event-Handler-Dependencies wieder ein.
7. Der Rule-Validator muss Testdateien aus dem Szenario-Manifest sowie statisch eingebundene Split-Dateien aus `dofile` und `require` indizieren.
8. Die Hidden-Gate-Policy wird zentral in `ConfigBuilders` gepflegt und nicht nachtraeglich in `RuntimeSetup` mutiert.
9. Secure- und Klick-Mutationsflaechen muessen explizit fuer Kampf- und Key-Sicherheit auditiert sein.
10. Lokale CI-Wrapper muessen die GitHub-Lua-Check-Workflow-Gates spiegeln und nur delegierend verschalten.
11. `RuntimeSetup` erhaelt benannte Controller-Context-Bundles, damit Group- und Event-Handler-Wiring nicht mehr aus einem unmarkierten Gesamtcontext gelesen werden.
12. Optionale WoW-Globals wie `C_Timer` und `C_Spell` werden ueber geschuetzte `_G`-Caches gelesen.
13. Bekannte Grossmodule bleiben als Refactoring-Watchlist dokumentiert und duerfen nicht still aus der Architektur verschwinden.

## Regelbloecke

### RULE-ARCH-COMPOSITION-ROOT
- Regelnummer: 1
- Status: aktiv
- Zusammenfassung: `isiLive.lua` bleibt Composition Root und delegiert an `Factory.InitializeAddon`, das Runtime-State und Runtime-Setup zentral verdrahtet.
- Erforderliche Tests:
  - Architecture root wires runtime through RuntimeState and RuntimeSetup

### RULE-ARCH-EVENT-HANDLER-AGGREGATOR
- Regelnummer: 2
- Status: aktiv
- Zusammenfassung: `isiLive_event_handlers.lua` bleibt Aggregator fuer Lifecycle-Handler und enthaelt keine direkten Event-Bodies.
- Erforderliche Tests:
  - Architecture event handler aggregator uses split lifecycle modules

### RULE-ARCH-RUNTIME-SETUP-CONTEXT-WIRING
- Regelnummer: 3
- Status: aktiv
- Zusammenfassung: `isiLive_runtime_setup.lua` erstellt Group- und Event-Controller nur ueber Context-Factories aus `ControllerWiring`.
- Erforderliche Tests:
  - Architecture runtime setup uses context-based wiring factories

### RULE-ARCH-RUNTIME-STATE-API
- Regelnummer: 4
- Status: aktiv
- Zusammenfassung: `RuntimeState` bleibt die zentrale API fuer gemeinsam genutzten, mutierbaren Runtime-State.
- Erforderliche Tests:
  - Architecture runtime state exposes shared mutable state API

### RULE-ARCH-CONTROLLER-WIRING-CONTEXT-FACTORIES
- Regelnummer: 5
- Status: aktiv
- Zusammenfassung: `ControllerWiring` exportiert Context-Factories fuer Group- und Event-Controller.
- Erforderliche Tests:
  - Architecture controller wiring exports context factories

### RULE-ARCH-CONFIG-BUILDERS-FOCUSED
- Regelnummer: 6
- Status: aktiv
- Zusammenfassung: `ConfigBuilders` bleibt fokussiert und fuehrt keine Legacy-Builder fuer Group-/Event-Handler-Dependencies wieder ein.
- Erforderliche Tests:
  - Architecture config builders omit legacy event and group dependency builders

### RULE-ARCH-RULE-VALIDATOR-SPLIT-SCENARIOS
- Regelnummer: 7
- Status: aktiv
- Zusammenfassung: Der Rule-Validator muss Testdateien aus dem Szenario-Manifest sowie statisch eingebundene Split-Dateien aus `dofile` und `require` indizieren.
- Erforderliche Tests:
  - Architecture rules validator indexes split scenario files from dofile and require

### RULE-ARCH-HIDDEN-GATE-CONFIG-BUILDERS
- Regelnummer: 8
- Status: aktiv
- Zusammenfassung: Die Hidden-Gate-Policy wird zentral in `ConfigBuilders` gepflegt und darf nicht nachtraeglich in `RuntimeSetup` mutiert werden.
- Erforderliche Tests:
  - Architecture hidden-gate policy is owned by config builders instead of runtime setup

### RULE-ARCH-SECURE-MUTATION-AUDIT
- Regelnummer: 9
- Status: aktiv
- Zusammenfassung: Alle Produktionsdateien, die Secure-, Insecure-Action- oder Klick-Mutationsflaechen beruehren, muessen explizit fuer Kampf- und Key-Sicherheit auditiert sein.
- Erforderliche Tests:
  - Architecture secure button mutation surface is explicitly audited for combat and key safety

### RULE-ARCH-CI-WRAPPER-PARITAET
- Regelnummer: 10
- Status: aktiv
- Zusammenfassung: Der lokale CI-Preflight muss die GitHub-Lua-Check-Gates spiegeln; die lokalen Wrapper bleiben reine Delegationsschichten und duerfen keine eigene Parallel- oder Sonderlogik einfuehren.
- Erforderliche Tests:
  - Architecture GitHub Lua Check workflow keeps CI validation steps wired
  - Architecture local CI preflight mirrors the GitHub Lua Check workflow
  - Architecture local CI wrapper forwards directly into the preflight script
  - Architecture local CI shorthand wrapper forwards into the local CI wrapper
  - Architecture local CI cmd wrapper forwards into the PowerShell shortcut

### RULE-ARCH-RUNTIME-SETUP-CONTEXT-BUNDLES
- Regelnummer: 11
- Status: aktiv
- Zusammenfassung: `RuntimeSetup` erhaelt benannte Controller-Context-Bundles; der Group-Controller wird aus einem eigenen Group-Context verdrahtet und der Event-Handler-Controller aus einem expliziten Event-Context.
- Erforderliche Tests:
  - Architecture runtime setup uses context-based wiring factories
  - Architecture factory passes named runtime setup controller contexts

### RULE-ARCH-OPTIONALE-WOW-GLOBALS-GESCHUETZT
- Regelnummer: 12
- Status: aktiv
- Zusammenfassung: Produktive Zugriffe auf optionale WoW-Globale wie `C_Timer`, `C_Spell`, `hooksecurefunc` und fallback-faehige `CreateFrame`-Pfade muessen ueber lokale `rawget(_G, "...")`-Caches laufen und bei fehlender API geschlossen bleiben, statt bare globale Short-Circuit-Ketten zu verwenden.
- Erforderliche Tests:
  - Architecture optional WoW globals use guarded rawget caches

### RULE-ARCH-GROSSMODULE-WATCHLIST
- Regelnummer: 13
- Status: aktiv
- Zusammenfassung: Die bekannten grossen Ownership-Flaechen `ui/isiLive_lfg_flags.lua`, `logic/isiLive_sync.lua` und `ui/isiLive_notice.lua` bleiben in `docs/ARCHITECTURE.md` als Refactoring-Watchlist dokumentiert. Splits duerfen nur entlang klarer Runtime- oder UI-Verantwortlichkeiten und mit deterministischen Tests fuer extrahierte Module erfolgen.
- Erforderliche Tests:
  - Architecture large-module watchlist is documented and gate-pinned
