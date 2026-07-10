# Agenten-Workflow

Dieses Runbook beschreibt, wie Hilfsagenten fuer isiLive genutzt werden duerfen.
Es ersetzt keine Projektregeln. Bei Widerspruch gelten zuerst
`docs/RULES_LOGIC.md`, danach `docs/ARCHITECTURE_RULES.md`, `AGENTS.md`,
`CLAUDE.md`, `docs/RULES.md` und die konkreten User-Entscheidungen.

## Grundsatz

Agenten sind dirigierte Werkzeuge fuer abgegrenzte Teilaufgaben. Sie duerfen
Kontext sammeln, Patches in klar begrenzten Dateien vorbereiten, Gates laufen
lassen und Reviews liefern. Sie duerfen nicht eigenstaendig Produktentscheidungen
treffen, Runtime-Werte raten, Release-Aktionen ausfuehren oder fehlende Quellen
durch "wahrscheinliche" Daten ersetzen.

Fuer alle Agenten gilt:

- Keine geratenen Dungeon-, Spell-, Activity-, Map-, Toy-, Mount-, DPS- oder
  Runtime-Zustaende.
- Unbekannte Daten bleiben `unresolved`.
- Verifizierbare Quellen sind nur beobachtete Live-/PTR-Daten, explizit
  persistierte verifizierte Daten oder eindeutig dokumentierte
  User-Entscheidungen.
- Bei fehlender Quelle stoppt der Agent und benennt die konkrete Luecke.
- Jeder Code- oder Runtime-Verhaltenspatch muss die betroffenen aktiven Regeln,
  deterministischen Tests und Dokumente nennen.
- Commits, Pushes, Tags, Releases und Version-Bumps erfolgen nur auf
  ausdrueckliches User-Kommando.

## Geeignete Agentenrollen

### Explorer

Zweck: schnelle, read-only Code- und Doku-Orientierung.

Geeignete Aufgaben:

- Betroffene Module, Regeln und Tests fuer ein Feature identifizieren.
- Bestehende Architekturgrenzen und Wiring-Pfade zusammenfassen.
- Abhaengige Lokalisierungs-, Settings- oder SavedVariables-Felder finden.
- Vorhandene Simulatoren und deterministische Tests einem Verhalten zuordnen.

Nicht erlaubt:

- Daten interpretieren, wenn die Quelle nicht eindeutig ist.
- Aenderungen direkt umsetzen.
- Bestehende User-Aenderungen zuruecksetzen.

### Worker

Zweck: kleine, klar abgegrenzte Umsetzung in disjunkten Dateien.

Geeignete Aufgaben:

- Ein einzelnes Modul oder einen einzelnen Testbereich patchen.
- Einen Generator oder Validator fokussiert erweitern.
- Dokumentation fuer eine bereits entschiedene Verhaltensaenderung nachziehen.

Pflichten:

- Vor Runtime-Verhaltensaenderungen `docs/RULES_LOGIC.md` lesen.
- Schreibbereich vorab nennen.
- Keine parallelen Worker auf denselben Dateien.
- Geaenderte Dateien im Abschluss nennen.
- Tests und Regel-zu-Test-Zuordnung im selben Change pflegen, wenn eine aktive
  Regel betroffen ist.

### Review

Zweck: unabhaengige Pruefung eines Patches.

Geeignete Aufgaben:

- No-Guess-Verletzungen suchen.
- Combat-, Secure-, Hidden- und Raid-Hard-off-Pfade pruefen.
- Fehlende Tests oder Doku-Sync-Luecken melden.
- Locale-, Packaging- und Release-Risiken benennen.

Review-Agenten liefern Findings zuerst, mit Datei- und Zeilenbezug. Sie fixen
nicht automatisch, ausser der User gibt dafuer einen separaten Auftrag.

### Gate

Zweck: Validierung und Fehlerverdichtung.

Geeignete Aufgaben:

- `lua tools/validate_usecases.lua` ausfuehren.
- Fuer Release-nahe Arbeit `powershell -ExecutionPolicy Bypass -File
  tools\validate_ci_local.ps1` ausfuehren.
- Fehlerausgaben auf den ersten relevanten Gate-Fehler verdichten.

Pflichten:

- Keine Gates ueberspringen.
- Bei rotem Gate nicht "best effort" abschliessen.
- Keine Auto-Fixes ohne Freigabe.

### Season-Intake

Zweck: Vorarbeit fuer neue Seasons und Dungeon-Daten.

Geeignete Aufgaben:

- `docs/SEASON_INTAKE.md` gegen `tools/check_season_intake.lua` pruefen.
- PTR-/Live-Dumps strukturiert einordnen.
- Fehlende `Source`- oder `VerifiedAt`-Felder melden.
- `unresolved`-Felder als offene Luecken listen.

Nicht erlaubt:

- IDs aus Namen, Screenshots, externen Listen oder Plausibilitaet ableiten.
- `SeasonData.ACTIVE_SEASON_ID` umstellen.
- Halbfertige Season-Daten als aktiv vorschlagen.

### Doku-Sync

Zweck: Konsistenz zwischen Code, Regeln und Nutzerdoku.

Geeignete Aufgaben:

- Pruefen, ob `README.md`, `docs/CHANGELOG.md`, `docs/USECASES.md`,
  `docs/ARCHITECTURE.md`, `docs/RULES.md`, `docs/WARTUNG.md` oder
  `CHANGELOG_RELEASE.md` nachgezogen werden muessen.
- Sprachregel pruefen: README und Changelogs Englisch, sonst Deutsch.
- UI-Labels gegen Locale-Keys und Dokumentation abgleichen.

Nicht erlaubt:

- `docs/RULES_LOGIC.md` umsortieren.
- Aktive Regeln zusammenfuehren oder bereinigen ohne User-Bestaetigung.
- Unklare Regelsaetze still interpretieren.

## Delegationsmuster

Ein sinnvoller Agentenauftrag enthaelt immer:

1. Ziel.
2. Erlaubte Dateien oder read-only Umfang.
3. Relevante Regeln oder Dokumente.
4. Erwartetes Ergebnisformat.
5. Explizite Stop-Bedingungen.

Beispiel:

```text
Explorer: Lies docs/RULES_LOGIC.md, docs/USECASES.md und die Module zum
Share-Keys-Pfad. Melde nur, welche aktiven Regeln und Tests ein Fix am
SHAREKEYS-Cooldown beruehren wuerde. Keine Codeaenderungen.
```

Beispiel:

```text
Worker: Patch nur ui/isiLive_settings_sound.lua und den passenden
Settings-Test. Ziel ist ein bereits entschiedener Sound-Schalter. Keine
Locale-Fallbacks raten; neue Texte nur enUS/deDE, vorbereitete Locales nur
bewusst mit Fallback. Fuehre danach lua tools/validate_usecases.lua aus.
```

## Nicht delegieren

Diese Aufgaben bleiben beim Hauptagenten oder beim User:

- Produktentscheidungen bei mehrdeutigen Regeln.
- Live-/PTR-Beobachtung im Spiel.
- Bewertung, ob eine unverifizierte externe Quelle ausreichend belastbar ist.
- Release-Freigabe, Version-Bump, Tagging, Commit und Push.
- Zusammenfuehren widerspruechlicher Entwurfsregeln.
- Aenderungen an `docs/RULES_LOGIC.md`, wenn die maschinenpruefbare Intention
  nicht eindeutig formulierbar ist.

## Abschlusscheck

Nach Agentenarbeit muss der Hauptagent:

1. Ergebnisse gegen die Projektregeln pruefen.
2. Konflikte mit laufenden User-Aenderungen erkennen.
3. Geaenderte Dateien selbst kurz reviewen.
4. Das passende Gate ausfuehren, mindestens `lua tools/validate_usecases.lua`.
5. Dem User klar sagen, was geaendert wurde und was nicht validiert werden
   konnte.
