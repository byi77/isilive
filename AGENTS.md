# AGENTS

## Verbindliche Regelquelle

- Lies vor Runtime-Verhaltensaenderungen immer zuerst `docs/RULES_LOGIC.md`.
- Behandle jeden Regelblock mit `Status: aktiv` als harten Vertrag.
- Wenn Codeaenderungen eine aktive Regel beruehren, aktualisiere im selben Change die deterministischen Tests und die Regel-zu-Test-Zuordnung (Pflichtfeld `Erforderliche Tests:` im jeweiligen Detailblock in `docs/RULES_LOGIC.md`).
- `docs/RULES_LOGIC.md` wird auf Deutsch gepflegt; die deutsche Formulierung in dieser Datei ist zu erhalten.
- Halte `docs/RULES_LOGIC.md` append-only in der Reihenfolge der Benutzereingaben; keine erzwungene Sortierung und kein Umordnen bestehender Regelb loecke.
- Vorlaeufig doppelte Entwurfsideen sind erlaubt, wenn eine Regel noch im Status `entwurf` ist und noch nicht konsolidiert wurde; doppelte Zusammenfassungen als Warnung sichtbar machen und erst nach Bestaetigung durch den User zusammenfuehren oder bereinigen.
- Nach jeder Aenderung an `docs/RULES_LOGIC.md` pruefe jeden neuen oder geaenderten Satz, formuliere daraus eine praezise maschinenpruefbare Intention und frage den User nach, wenn die Bedeutung nicht eindeutig ist.

## Dokument- und Verzeichnisstruktur

Alle gepflegten Projektdokumente liegen unter `docs/`:

- `docs/RULES_LOGIC.md` — verbindliche Regelquelle, Gate-geprueft
- `docs/ARCHITECTURE.md` — Architekturueberblick
- `docs/ARCHITECTURE_RULES.md` — Architekturvertraege
- `docs/USECASES.md` — deterministische Usecases
- `docs/RELEASE.md` — Release-Prozess
- `docs/WARTUNG.md` — Wartungsrunbook (nicht im CurseForge-Paket)
- `docs/CHANGELOG.md` — vollstaendiges Changelog (nicht im CurseForge-Paket)

Im Root liegen nur: `README.md`, `CHANGELOG_RELEASE.md` (kurzer Stub), `CLAUDE.md`, `AGENTS.md`, `TODO.md`.

## Sprachregel Fuer Dokus

- `README.md` sowie alle Changelog-Dateien bleiben Englisch.
- Alle anderen gepflegten Projektdokumente werden auf Deutsch gehalten.
- Neue Dokus, Regeltexte und Runbooks folgen derselben Sprachregel.
- Fuer Chat-Antworten und Code-Kommentare gilt die Sprachregel aus `CLAUDE.md`: Antworten auf Deutsch, Code und Kommentare auf Englisch.

## No-Guess-Vertrag

Dieser Vertrag spiegelt die Regeln 23 und 24 aus `docs/RULES_LOGIC.md`. Die Quelle dort ist massgeblich; bei Widerspruch gilt `docs/RULES_LOGIC.md`.

- Niemals raten.
- Niemals spekulative Fallbacks bauen.
- Wenn ein Zustand, Wert oder Zusammenhang nicht direkt aus einer belastbaren Quelle stammt, gilt er als unbekannt und bleibt unresolved.
- Unbekannte oder mehrdeutige Daten duerfen nicht als wahrscheinlich behandelt, interpoliert, synthetisiert oder heuristisch ersetzt werden.
- Erlaubte Quellen sind nur beobachtete Live-Daten, explizit persistierte verifizierte Daten oder eindeutig dokumentierte Benutzerentscheidungen.
- Wenn eine belastbare Quelle fehlt, stoppe, benenne die Luecke konkret und frage den User gezielt nach der fehlenden Entscheidung oder Quelle.
- Wo keine verifizierbare Quelle existiert, ist fail-closed Pflicht: kein Guess, kein stiller Default, kein "best effort".

## Verbindliche Validierung

- Fuehre vor dem Finalisieren immer `lua tools/validate_usecases.lua` aus.
- `tools/validate_usecases.lua` enthaelt die Rule-Logic-Validierung und die deterministische Runtime-Szenario-Validierung.
- Wenn die Validierung fehlschlaegt, wird nicht abgeschlossen, bis die Ursache behoben ist.
