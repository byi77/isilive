# Architekturregeln

Diese Datei beschreibt verbindliche Strukturregeln fuer den aktuellen Modulzuschnitt.
Im Gegensatz zu `RULES_LOGIC.md` geht es hier nicht um Runtime-Verhalten, sondern um
stabile Architekturgrenzen, die ueber deterministische Strukturtests geprueft werden.

Aktueller Dokumentationsstand: `0.9.345`. Die seit 0.9.310 hinzugekommenen
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
14. Logic- und Factory-Module konsumieren keine private Roster-UI-Registry, sondern nur explizite oeffentliche UI-Fassaden.
15. Der mutierbare Factory-Kompositionskontext wird nicht auf der Addon-Tabelle publiziert.
16. Der MDT-Forces-Generator verarbeitet fremde Dungeonquellen nur in einer globalfreien, groessen- und instruktionsbegrenzten Sandbox.
17. Manuell gepflegte Runtime-Saisondaten liegen ausschliesslich im normalisierten Saisonmanifest; Verbraucher und Werkzeuge leiten ihre Indizes daraus ab.

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
- Zusammenfassung: Der lokale CI-Preflight muss die GitHub-Lua-Check-Gates spiegeln; die lokalen Wrapper bleiben reine Delegationsschichten und duerfen keine eigene Parallel- oder Sonderlogik einfuehren. Alle externen GitHub Actions werden unveraenderlich auf einen vollstaendigen 40-stelligen Commit-SHA gepinnt, behalten den lesbaren Major-Tag als Kommentar und werden ueber Dependabot fuer `github-actions` gepflegt. Stable- und Pre-Release-Workflows verwenden denselben verifizierten Checkout-v5-SHA wie die uebrigen gepflegten Workflows.
- Erforderliche Tests:
  - Architecture external workflow actions use immutable SHA pins with version comments
  - Architecture release workflows use checkout v5
  - Architecture GitHub Lua Check workflow keeps CI validation steps wired
  - Architecture local CI preflight mirrors the GitHub Lua Check workflow
  - Architecture CTL wire-order simulator is enforced by local and GitHub CI
  - Architecture local CI wrapper forwards directly into the preflight script
  - Architecture local CI shorthand wrapper forwards into the local CI wrapper
  - Architecture local CI cmd wrapper forwards into the PowerShell shortcut

### RULE-ARCH-RUNTIME-SETUP-CONTEXT-BUNDLES
- Regelnummer: 11
- Status: aktiv
- Zusammenfassung: `RuntimeSetup` erhaelt verpflichtende benannte Controller-Context-Bundles; der Group-Controller wird aus einem eigenen Group-Context verdrahtet und der Event-Handler-Controller aus einem separat konstruierten Event-Context. Fallbacks auf den RuntimeSetup-Root und selbstreferenzielle Event-Kontexte sind verboten.
- Erforderliche Tests:
  - Architecture runtime setup uses context-based wiring factories
  - Architecture factory passes named runtime setup controller contexts
  - RuntimeSetup.Configure rejects missing named dependency contexts

### RULE-ARCH-OPTIONALE-WOW-GLOBALS-GESCHUETZT
- Regelnummer: 12
- Status: aktiv
- Zusammenfassung: Produktive Zugriffe auf optionale WoW-Globale wie `C_Timer`, `C_Spell`, `C_Map`, `UnitExists`, `GetInstanceInfo`, `hooksecurefunc` und fallback-faehige `CreateFrame`-Pfade muessen ueber lokale `rawget(_G, "...")`-Caches laufen und bei fehlender API geschlossen bleiben, statt bare globale Short-Circuit-Ketten zu verwenden.
- Erforderliche Tests:
  - Architecture optional WoW globals use guarded rawget caches

### RULE-ARCH-GROSSMODULE-WATCHLIST
- Regelnummer: 13
- Status: aktiv
- Zusammenfassung: Alle Produktionsdateien oberhalb der Metrik-Warnschwelle muessen in `docs/ARCHITECTURE.md` als Refactoring-Watchlist dokumentiert sein; das Metrik-Gate gleicht Warnungen und Watchlist deterministisch ab. Splits duerfen nur entlang klarer Runtime- oder UI-Verantwortlichkeiten und mit deterministischen Tests fuer extrahierte Module erfolgen.
- Erforderliche Tests:
  - Architecture large-module watchlist is documented and gate-pinned

### RULE-ARCH-ROSTER-UI-GRENZE
- Regelnummer: 14
- Status: aktiv
- Zusammenfassung: `_RosterInternal` ist eine private Integrationsflaeche innerhalb der Roster-UI. Logic- und Factory-Module duerfen sie nicht lesen; benoetigte Funktionen werden ueber die explizite `RosterUI`-Fassade angeboten.
- Erforderliche Tests:
  - Architecture production layers do not consume private roster UI registry

### RULE-ARCH-FACTORY-KONTEXT-KAPSELUNG
- Regelnummer: 15
- Status: aktiv
- Zusammenfassung: `Factory.InitializeAddon` darf den mutierbaren Factory-Kompositionskontext weder auf der Addon-Tabelle publizieren noch im normalen Produktionspfad zurueckgeben. Nur deterministische Kompositionstests duerfen die interne Test-Introspection explizit anfordern.
- Erforderliche Tests:
  - Architecture factory does not publish mutable composition context

### RULE-ARCH-MDT-QUELLEN-SANDBOX
- Regelnummer: 16
- Status: aktiv
- Zusammenfassung: `tools/sync_mdt_forces.lua` darf fremde MDT-Dungeonquellen weder ueber `loadfile` mit geerbtem `_G` noch mit Zugriff auf `os`, `io`, `debug`, `require` oder andere Umgebungsfunktionen ausfuehren. Zulaessig sind nur der injizierte MDT-Datencontainer und `ipairs`; Bytecode, Quellen oberhalb des Groessenlimits und Ausfuehrungen oberhalb des Instruktionslimits werden geschlossen abgelehnt. Ein fuer das Instruktionslimit temporaer ersetzter Host-Debug-Hook muss danach einschliesslich Maske und Zaehler wiederhergestellt werden, damit Coverage- oder andere Instrumentierung nicht verloren geht.
- Erforderliche Tests:
  - MDT forces sync executes dungeon data without ambient globals

### RULE-ARCH-SEASON-MANIFEST-SINGLE-SOURCE
- Regelnummer: 17
- Status: aktiv
- Zusammenfassung: `data/isiLive_seasons.lua` ist die einzige manuell gepflegte Runtime-Quelle fuer aktive und vorbereitete Seasons. Jeder Dungeon wird dort als ein normalisierter Datensatz mit Challenge-Map-ID, Portalzaubern, LFG-Activity-IDs, Reihenfolge, Namen, Kurzcodes, optionalem Stufengate und Verifikationsmetadaten gepflegt. `SeasonData` erzeugt daraus die Runtime-Indizes. LFG-Erkennung, Portal-Navigator und MDT-Werkzeuge duerfen keine parallelen saisonalen Zuordnungstabellen fuehren. Der generierte, grosse und verfallende MDT-Forces-Datensatz bleibt separat.
- Erforderliche Tests:
  - Architecture season manifest is the only manually maintained runtime season source
  - Season manifest compiles dungeon records into all runtime indexes
  - Season intake check rejects IDs that diverge from the season manifest
