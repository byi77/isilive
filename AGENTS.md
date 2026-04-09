# AGENTS

## Verbindliche Regelquelle

- Lies vor Runtime-Verhaltensaenderungen immer zuerst `RULES_LOGIC.md`.
- Behandle jeden Regelblock mit `Status: active` als harten Vertrag.
- Wenn Codeaenderungen eine aktive Regel beruehren, aktualisiere im selben Change die deterministischen Tests und die Regel-zu-Test-Zuordnung.
- `RULES_LOGIC.md` wird auf Deutsch gepflegt; die deutsche Formulierung in dieser Datei ist zu erhalten.
- Halte `RULES_LOGIC.md` append-only in der Reihenfolge der Benutzereingaben; keine erzwungene Sortierung und kein Umordnen bestehender Regelbloecke.
- Vorlaeufig doppelte Entwurfsideen sind erlaubt; doppelte Zusammenfassungen als Warnung sichtbar machen und erst nach Bestaetigung durch den User zusammenfuehren oder bereinigen.
- Nach jeder Aenderung an `RULES_LOGIC.md` pruefe jeden neuen oder geaenderten Satz, formuliere daraus eine praezise maschinenpruefbare Intention und frage den User nach, wenn die Bedeutung nicht eindeutig ist.

## Sprachregel Fuer Dokus

- `README.md` sowie alle Changelog-Dateien bleiben Englisch.
- Alle anderen gepflegten Projektdokumente werden auf Deutsch gehalten.
- Neue Dokus, Regeltexte und Runbooks folgen derselben Sprachregel.

## No-Guess-Vertrag

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
