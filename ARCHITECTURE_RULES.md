# Architekturregeln

Diese Datei beschreibt verbindliche Strukturregeln fuer den aktuellen Modulzuschnitt.
Im Gegensatz zu `RULES_LOGIC.md` geht es hier nicht um Runtime-Verhalten, sondern um
stabile Architekturgrenzen, die ueber deterministische Strukturtests geprueft werden.

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

1. `isiLive.lua` bleibt Composition Root und verdrahtet Runtime-State und Runtime-Setup zentral.
2. `isiLive_event_handlers.lua` bleibt Aggregator fuer Lifecycle-Handler und enthaelt keine direkten Event-Bodies.
3. `isiLive_runtime_setup.lua` erstellt Group- und Event-Controller nur ueber Context-Factories aus `ControllerWiring`.
4. `RuntimeState` bleibt die zentrale API fuer gemeinsam genutzten, mutierbaren Runtime-State.
5. `ControllerWiring` exportiert Context-Factories fuer Group- und Event-Controller.
6. `ConfigBuilders` bleibt fokussiert und fuehrt keine Legacy-Builder fuer Group-/Event-Handler-Dependencies wieder ein.

## Regelbloecke

### RULE-ARCH-COMPOSITION-ROOT
- Regelnummer: 1
- Status: aktiv
- Zusammenfassung: `isiLive.lua` bleibt Composition Root und verdrahtet Runtime-State und Runtime-Setup zentral.
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
