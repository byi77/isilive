# TODO temp1 — Feature-Kandidaten M+ / Gruppen-UX

Arbeitsliste, Stand 2026-09-13, Basis `0.9.392`. Zehn Kandidaten aus einer
Funktionslückenanalyse im M+-Umfeld. Reihenfolge ist Fundreihenfolge, keine
Priorisierung — die steht am Ende.

Jeder Punkt wird einzeln durchgesprochen, bevor irgendetwas umgesetzt wird.
Nichts hier ist beschlossen.

---

## 1. Routen-Modell mit Boss-Sektionen

**Idee:** Den Dungeon in Abschnitte zwischen den Bossen zerlegen und pro
Abschnitt eine Soll-Prozentzahl führen. Anzeige mit vier Zuständen: offen,
erreicht, verfehlt (Boss lag, bevor das Soll stand), Dungeon fertig.

**Ist-Stand:** Nur Gesamt-Forces plus Pull-Delta
([game/isiLive_killtrack.lua:32](game/isiLive_killtrack.lua#L32)). Kein
Sektionsbegriff, kein Routenbegriff, keine Soll-Werte pro Boss.

**Use-Case:** Dritter Abschnitt, der Tank pullt den Boss. Die Anzeige sagt
"noch 4,12 % für diesen Abschnitt" — die Gruppe weiß *vor* dem Boss, dass sie
Trash schuldig bleibt. Heute steht dort nur "72 %", und wer nicht auswendig
weiß, was an dieser Stelle nötig ist, erfährt es zu spät.

**Offen:** Woher kommen die Soll-Werte? Eigene Pflege pro Season ist Aufwand,
der bei jedem Patch wiederkommt. Größter Brocken der Liste.

---

## 2. Routen-Strings importieren

**Idee:** Extern erzeugte Routen-Strings im Spiel einlesen und in Boss-Soll-Werte
plus Boss-Reihenfolge umrechnen. Fehlschlag mit klarer Meldung, wenn nicht alle
Bosse erkannt werden — kein Teilimport, der halb falsche Werte hinterlässt.

**Ist-Stand:** Routendaten werden nur offline über das Sync-Skript in `tools/`
zur Forces-DB verarbeitet. Der Nutzer kann keine eigene Route einspielen.

**Use-Case:** Der Tank postet vor dem Key seine Route. Man fügt den String ein,
und die Anzeige rechnet ab sofort nach seiner Route statt nach dem Standard.

**Offen:** Hängt vollständig an Punkt 1 — ohne Sektionsmodell gibt es kein Ziel
für den Import. Bis dahin nicht bewertbar.

---

## 3. Import/Export und Profile

**Idee:** Einstellungen als String exportieren und importieren. Vier
Granularitäten denkbar: ganzes Profil, nur Anzeige-/Modul-Einstellungen, pro
Dungeon, pro Season-Abschnitt. Technisch Serialisierung plus Kompression plus
druckbare Kodierung, mit Versionsstempel, der unbekannte Exportversionen
ablehnt statt sie halb einzulesen. Import in ein benanntes Zielprofil, wahlweise
mit oder ohne sofortiges Aktivieren.

**Ist-Stand:** Nicht vorhanden. Grep über `core/ ui/ game/ logic/ factory/`
liefert keinen Treffer. `IsiLiveDB` ist account-weit
([isiLive.toc:6](isiLive.toc#L6)), aber an die jeweilige WoW-Installation
gebunden.

**Use-Case:** Einstellungen auf dem Hauptrechner einrichten, String
exportieren, am Laptop einfügen. Heute muss dort jedes Häkchen neu gesetzt
werden — inklusive aller VIP-Schalter
([core/isiLive_db_schema.lua:228-235](core/isiLive_db_schema.lua#L228-L235)).

**Offen:** Welche Keys gehören in "Settings only"? Positionen und Größen sind
auflösungsabhängig und sollten vermutlich nicht mitwandern.

---

## 4. Fortschrittsbalken für Forces

**Idee:** Eigene Leiste statt reiner Zahl. Füllrichtung, Textur, optionaler
Farbverlauf über abgeschlossene Abschnitte, eigene Farben für abgeschlossen /
laufend / verfehlt, Randstile, Markierungen an den Boss-Schwellen, kleinere
Markierungen an Zwischenzielen, Beschriftung ober- oder unterhalb mit dem Ziel
des aktuellen Abschnitts.

**Ist-Stand — KORREKTUR 2026-09-13:** Die Leiste existiert bereits. Die
KillTrack-Zeile in [ui/isiLive_roster_panel_kill_row.lua](ui/isiLive_roster_panel_kill_row.lua)
(468 Zeilen) rendert Hintergrund- und Füllbalken
([:70-89](ui/isiLive_roster_panel_kill_row.lua#L70-L89)), fortschrittsabhängige
Füllfarbe ([:354](ui/isiLive_roster_panel_kill_row.lua#L354)), einen blauen
Pull-Balken als Vorhersage über dem bestätigten Fortschritt
([:104](ui/isiLive_roster_panel_kill_row.lua#L104)), Prozenttext und Pull-Text.
Außerhalb eines Keys blendet dieselbe Zeile auf Ziel-Dungeon plus Keylevel um
([:392-416](ui/isiLive_roster_panel_kill_row.lua#L392-L416)).

Die ursprüngliche Formulierung "keine Leiste, nur Text" war falsch — sie kam aus
einer Suche nach `progressBar`, während unsere Umsetzung `killTrackRow` heißt.

**Rest des Punktes:**

- Markierungen an Boss-Schwellen — hängt vollständig an Punkt 1.
- Sichtbarkeit nur im M+-Layout
  ([ui/isiLive_roster_layout.lua:193](ui/isiLive_roster_layout.lua#L193)).
  Ob V und H sie auch zeigen sollen, ist eine Produktentscheidung.
- Nicht konfigurierbar: Höhe fest 8 px, Farben aus `UICommon.Colors`.
  Wählbare Textur oder Farbverlauf bräuchte Punkt 5.

**Use-Case:** Im Kampf liest niemand Zahlen. Ein Blick auf die Leiste sagt "kurz
vor dem Tick". Das ist heute schon erfüllt; offen bleibt nur die Markierung der
nächsten Schwelle.

**Offen:** Als eigenständiger Punkt erledigt. Der verbleibende Rest gehört
inhaltlich zu Punkt 1 und sollte dort mitentschieden werden.

---

## 5. Gemeinsame Schrift- und Texturbibliothek — UMGESETZT 2026-09-13

> Gebaut als globale Schriftwahl, Schriftflags unverändert (Entscheidung des
> Users). Bartexturen bewusst ausgelassen: sie beträfen nur die eine
> KillTrack-Leiste.
>
> - Neues Modul [ui/isiLive_ui_fonts.lua](ui/isiLive_ui_fonts.lua): Auswahlliste
>   der Clientschriften, optionale Sondierung eines geteilten Medienpools,
>   Vorrangentscheidung `GetPreferredFontPath`.
> - `UICommon.ApplyLocaleFont` entscheidet jetzt über `GetPreferredFontPath` —
>   dadurch greifen alle rund 20 bestehenden Aufrufstellen ohne Änderung.
> - Schema-Feld `uiFontFamily` (String, Default `""` = Vorlagenschrift).
> - Dropdown in der Display-Sektion, Umschalten ohne Reload über
>   `onUiFontFamilyChange` (Chrome via `ApplyLocalizationToUI`, Zeilen via
>   `RenderRoster`).
> - Drei Locale-Keys in allen acht Sprachen.
> - Regel 116 in `docs/RULES_LOGIC.md`, Split in `docs/ARCHITECTURE.md`
>   dokumentiert, 15 neue Tests in
>   `testmodul/isilive_test_scenarios_ui_fonts.lua`.
>
> Offen: Versionsbump und Changelog-Eintrag stehen noch aus, ebenso der
> In-Game-Test.

## 5. Gemeinsame Schrift- und Texturbibliothek (ursprüngliche Notiz)

**Idee:** Schriften und Balkentexturen aus dem geteilten Medienpool beziehen,
den die verbreiteten UI-Pakete füllen, dazu Schriftflags (Outline, Thick
Outline, Monochrome) und Textausrichtung.

**Ist-Stand:** Keine Anbindung. Feste Schriften, als Stellschraube nur
`mobNameplateFontSize`
([core/isiLive_db_schema.lua:201](core/isiLive_db_schema.lua#L201)).

**Use-Case:** Wer seine gesamte Oberfläche auf eine Hausschrift umgestellt hat,
bekommt von uns Blizzard-Standard mitten hinein. Auf einem sonst durchgestylten
Bildschirm fällt genau das auf.

**Offen:** Neue Abhängigkeit im Ladepfad, plus Fallback, wenn der Pool fehlt.

---

## 6. Nameplate-Text frei formatierbar

**Idee:** Formatvorlage mit Platzhaltern für Prozent, Anzahl und Gesamtzahl —
also `(1,23 %)`, `12/340` oder `1,23 % | 12` nach Geschmack. Dazu Textfarbe und
die drei Werte einzeln schaltbar.

**Ist-Stand:** Prozent und Remaining, Position, Größe, Offsets
([core/isiLive_db_schema.lua:196-208](core/isiLive_db_schema.lua#L196-L208)) —
aber kein freies Format, keine Farbe, keine Mob-Anzahl.

Wichtig zur Einordnung: Bei der **Datenquelle** sind wir gut aufgestellt. Wir
treffen zuerst die generierte Forces-DB über `byNpcId`
([ui/isiLive_mob_nameplate.lua:132](ui/isiLive_mob_nameplate.lua#L132)) und
nutzen `C_ScenarioInfo.GetUnitCriteriaProgressValues` nur als Fallback
([:631](ui/isiLive_mob_nameplate.lua#L631)) — billiger und robuster als ein
reiner API-Ansatz, der ohne diese API gar nichts anzeigt. Der Rückstand liegt
allein in der Textdarstellung.

**Use-Case:** Wer in Mobs zählt statt in Prozent, will `12/340` auf der
Nameplate sehen. Heute gibt es Prozent oder Remaining, sonst nichts.

**Offen:** Rein additiv zu `mobNameplate*`, kein neues Modul. Kleinster Aufwand
der Liste.

---

## 7. Positionierungs- und Vorschaumodus

**Idee:** Eigener Modus mit abgedunkeltem Hintergrund, einblendbarem Raster mit
einstellbarem Abstand und sichtbarem Anker. Dazu Vorschau-Zustände, die im
Alltag selten zu sehen sind: leerlaufend, im Pull, hochgerechnet, Abschnitt
fertig, Abschnitt verfehlt, kurz vor fertig, Dungeon fertig. Der Modus beendet
sich selbst bei Kampfbeginn, Dungeonstart oder Zonenwechsel und sagt, warum.

**Ist-Stand:** Der Demo-Simulator zeigt Abläufe, hat aber kein
Positionier-Overlay mit Raster und Anker.

**Use-Case:** Die Anzeige exakt über der Castbar ausrichten — ohne einen Key zu
starten, und mit Blick auf den Zustand "verfehlt", den man sonst nur im
misslungenen Run zu Gesicht bekommt.

**Offen:** Teilmenge davon existiert im Demo-Simulator. Erst klären, was davon
wirklich fehlt, statt ein zweites System danebenzustellen.

---

## 8. Season-Meta für den Nutzer

**Idee:** Start- und Enddatum pro Region in den Season-Daten führen, daraus
Countdown ("Season endet in 3 Tagen") und zwei Rückfragen bauen: beim
Season-Start "Werte für die neue Season zurücksetzen?", beim Routen-Update
"alles zurücksetzen oder nur die geänderten Dungeons?" — mit Liste der
betroffenen Dungeons.

**Ist-Stand:** Season-Daten sind vorhanden, aber nichts davon erreicht den
Nutzer. Kein Datum, kein Countdown, keine Rückfrage.

**Use-Case:** Eine neue Season startet mittwochs. Beim ersten Login fragt das
Addon, ob es umstellen soll. Heute merkt der Nutzer den Wechsel erst, wenn
Zahlen nicht mehr passen.

**Offen:** Die Rückfragen ergeben nur Sinn, wenn es nutzereigene Werte gibt,
die zurückgesetzt werden können — hängt also wieder an Punkt 1. Der Countdown
steht dagegen für sich und ist billig.

---

## 9. Kleinkram mit echtem Nutzen

Fünf unabhängige Einzelposten, jeder klein genug für sich:

- **Changelog im Spiel**, der nach Kampfende aufgeht statt mitten im Pull.
  Heute liegt der Changelog nur unter `docs/`.
- **Icon im Addon-Compartment** zusätzlich zum Minimap-Button
  (`showMinimapButton`).
- **Rollenfilter**: Anzeige nur für gewählte Rollen. Heute global an oder aus.
- **Unterstützte Sprachen**: aktuell acht (enUS, deDE, frFR, esES, ptBR, itIT,
  ruRU, trTR). Es fehlen koKR, zhCN, zhTW, esMX.
- **Legacy-Seasons**: Wir sind auf die laufende Season ausgerichtet.

**Use-Case Rollenfilter:** Ein DD will die Forces-Anzeige gar nicht sehen, das
ist Tank-Sache. Ein Häkchen, und sie erscheint nur auf dem Tank-Charakter —
statt sie für alle Charaktere gleichzeitig abzuschalten.

**Offen:** Der Rollenfilter greift in bestehende Sichtbarkeitslogik ein und ist
deshalb nicht so klein, wie er klingt.

---

## 10. Invite-Notice ausbauen

**Idee:** Aus dem einzelnen Schalter eine konfigurierbare Karte machen:
Blizzards Quick-Join-Einblendung unterdrücken, Fenster und Chat-Ausgabe getrennt
schalten, Inhalt wählen (Dungeon, Gruppenname, Beschreibung, akzeptierte Rolle,
Spielstil), Fenster erneut zeigen sobald die Gruppe voll ist, letzte Karte per
Slash-Befehl wieder aufrufen, Ganzes simulierbar mit einem Dungeon der
laufenden Season.

**Ist-Stand:** Ein einzelnes Boolean
([core/isiLive_db_schema.lua:192](core/isiLive_db_schema.lua#L192)), dazu
`groupJoinNoticeEnabled` ([:193](core/isiLive_db_schema.lua#L193)).

**Use-Case:** Man bewirbt sich auf zehn Gruppen und tabt raus. Der Invite kommt,
man kommt zurück — welcher Dungeon war das, und als was wurde man genommen? Ein
Slash-Befehl holt die Karte zurück. Heute ist die Notice weg, sobald sie weg
ist.

**Offen:** Die Karte existiert bereits, es geht um Optionen darum herum. Gutes
Verhältnis von Aufwand zu Nutzen.

---

## Technische Notiz

Für Gruppenansagen aus einem Feature heraus ist der belastbare Weg unter 12.0
ein vorbereitetes Makro, das der Spieler klickt — nicht `SendChatMessage` aus
dem Addon. Das ist dieselbe Antwort, die wir beim Rollenmarker-Klick gewählt
haben, und sie umgeht zugleich die Chat-Filterung bei eckigen Klammern
(siehe `CLAUDE.md`, Abschnitte zum Rollenmarker und zu Chat-Farbcodes).

---

## Einschätzung zur Reihenfolge

1. **Punkt 3 (Import/Export)** — größter Hebel, betrifft jeden Nutzer mit zwei
   Rechnern, ohne UI-Umbau machbar.
2. **Punkt 10 (Invite-Notice)** — kleine Erweiterungen an einem Feature, das
   schon steht.
3. **Punkt 6 (Nameplate-Format)** — rein additiv, kein neues Modul.

Punkt 1 und alles, was daran hängt (2, 4 teilweise, 8 teilweise), ist ein
eigenes Vorhaben in Season-Pflege-Größe. Ein halbes Routenmodell ist schlechter
als keins.
