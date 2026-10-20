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
([core/isiLive_db_schema.lua:202-214](core/isiLive_db_schema.lua#L202-L214)) —
aber kein freies Format, keine Farbe, keine Mob-Anzahl.

Wichtig zur Einordnung: Bei der **Datenquelle** sind wir gut aufgestellt. Wir
treffen zuerst die generierte Forces-DB über `byNpcId`
([ui/isiLive_mob_nameplate.lua:140](ui/isiLive_mob_nameplate.lua#L140)) und
nutzen `C_ScenarioInfo.GetUnitCriteriaProgressValues` nur als Fallback
([:776-779](ui/isiLive_mob_nameplate.lua#L776-L779)) — billiger und robuster als ein
reiner API-Ansatz, der ohne diese API gar nichts anzeigt. Der Rückstand liegt
allein in der Textdarstellung.

**Use-Case:** Wer in Mobs zählt statt in Prozent, will `12/340` auf der
Nameplate sehen. Heute gibt es Prozent oder Remaining, sonst nichts.

**Präzisierung 2026-09-13 (ersetzt "kleinster Aufwand der Liste"):**

Bereits vorhanden: `ResolveMobContributionFromDB` liefert den Mob-Count schon mit
([ui/isiLive_mob_nameplate.lua:151](ui/isiLive_mob_nameplate.lua#L151)), der
Aufrufer verwirft ihn nur ([:774](ui/isiLive_mob_nameplate.lua#L774)); die
Gesamtzahl steht in `dungeonTotal[mapID].total`
([:144](ui/isiLive_mob_nameplate.lua#L144)). Die Textfarbe ist fest auf
`TEXT_SECTION` verdrahtet ([:514-517](ui/isiLive_mob_nameplate.lua#L514-L517)).

Der Blocker: Der Prozentwert kann ein Secret Value sein — im DB-Pfad nie, im
API-Fallback schon ([:776-779](ui/isiLive_mob_nameplate.lua#L776-L779)). Der Code
behandelt das als eng gefasste Ausnahme nach Regel 102 (reine Durchreichung an
den Renderer, "never compared, reformatted, stored"). Ein `string.format` über
eine Nutzervorlage wäre eine Lua-seitige Auswertung und damit ein Regelbruch,
der das Addon für die Sitzung taintet.

Machbar nur so: Vorlage einmalig in Literalsegmente und Platzhalter zerlegen
und zur Laufzeit ausschließlich konkatenieren, innerhalb des bestehenden
`pcall`. `%c`/`%t` können nur im DB-Pfad gefüllt werden; im API-Fallback
existieren weder Count noch Total.

**Offen:** In zwei Schritten bauen — erst Farbe sowie Count/Total als
schaltbare Werte (unkritisch), die freie Vorlage separat und mit einem Test,
der einen Secret-Value-Stub durchreicht. Einsortiert hinter Punkt 3, 10.1 und 9.2.

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

**Bewertung 2026-09-13 — EMPFEHLUNG: STREICHEN.**

Der unterstellte Nutzen ist bereits abgedeckt:

- Live-Vorschau der Nameplate im Settings-Panel über `MobNameplate.ApplyPreview`
  ([ui/isiLive_settings_nameplates.lua:438-446](ui/isiLive_settings_nameplates.lua#L438-L446));
  Regel 75 pinnt fest, dass sie denselben Renderer nutzt wie die Runtime.
- Demo-Simulator mit rund 2.200 Zeilen über drei Module, inklusive der selten
  sichtbaren Zustände.
- Schaltbare Spaltenhilfslinien im M+-Layout (`CreateM2ColumnGuides`,
  [ui/isiLive_roster_panel_chrome.lua:406](ui/isiLive_roster_panel_chrome.lua#L406)).
- Drag mit `lockMainFramePosition`, Clamp-to-Screen für Notices.

Es fehlen nur Bildschirmraster, sichtbarer Anker und die Selbstbeendung eines
Vorschaumodus bei Kampf/Dungeonstart/Zonenwechsel — für ein Fenster, das man
ohnehin frei zieht und dessen Position gespeichert wird. Das rechtfertigt kein
eigenes Overlay-System.

Billiger Teilschritt, falls beim Verschieben doch etwas stört: die vorhandenen
Spaltenhilfslinien auch in V und H zeigen statt nur im M+-Layout (eine Zeile in
den Sichtbarkeitsregeln).

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

**Bewertung 2026-09-13 — EMPFEHLUNG: STREICHEN, bis auf einen Rest.**

Korrektur zur Ausgangsnotiz: Die Behauptung, Start- und Enddatum lägen bereits
in den Season-Daten, war falsch — sie stammte aus der Vergleichsquelle, nicht
aus unserem Code. [data/isiLive_seasons.lua](data/isiLive_seasons.lua) enthält
kein einziges Datumsfeld.

Vorhanden ist stattdessen: der automatische Wechsel über
`TryAutoSelectSeasonFromChallengeMapIDs` / `SetActiveSeasonID`
([game/isiLive_season_data.lua:623](game/isiLive_season_data.lua#L623)), die
lokalisierte Meldung `inactivePortalMessageByLocale` für den Vorher-Zustand und
eine Pre-Season-Statuszeile.

Gegen den Punkt sprechen zwei Dinge:

- Die Rückfragen sind gegenstandslos: Sie setzen nutzergepflegte Dungeonwerte
  voraus, die wir nicht haben. Das käme erst mit Punkt 1 und gehörte dann dort
  entschieden.
- Der Countdown bräuchte handgepflegte Daten pro Region. Verschiebt Blizzard
  einen Termin, zeigt das Addon eine falsche Zahl mit dem Anschein von
  Gewissheit — genau was Regel 54 untersagt. Das einzige Datum, das bei uns
  wirklich abläuft, ist `expiresAt` der Forces-DB, und das pflegt der
  wöchentliche Sync selbst.

**Verbleibender Rest (eigener, kleinerer Punkt):** eine einmalige Chatzeile,
wenn der automatische Season-Wechsel tatsächlich stattgefunden hat.
Ereignisgetrieben, ohne gepflegtes Datum — der Nutzer erfährt, warum plötzlich
andere Dungeons in der Liste stehen. Infrastruktur dafür ist vorhanden.

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

**Bewertung 2026-09-13 — nur ein Posten bleibt:**

1. **Changelog im Spiel — gehört nicht hierher.** Liegt bereits als
   ausgearbeiteter Abschnitt in [todo.md](todo.md) (Welcome-/What's-New-Panel,
   offen seit 2026-06-12), inklusive geplanter Quelle
   `core/isiLive_release_notes.lua` und CI-Abgleich gegen den obersten
   Changelog-Abschnitt. Dort stehen auch die zwei offenen Fragen. Hier nur als
   Verweis führen.
2. **Compartment-Icon — BAUEN.** Kein einziger `AddonCompartment`-Aufruf im
   Code; es gibt nur den Minimap-Button (`showMinimapButton`, default aus).
   TOC-Eintrag plus zwei Handler. Kleinster echter Zugewinn der Liste,
   besonders für Nutzer mit abgeschaltetem Minimap-Button.
3. **Rollenfilter — nicht klein.** Das Nameplate-Modul hat keinerlei
   Rollenbezug; die lokale Rolle müsste hineingeführt werden, und
   `UnitGroupRolesAssigned` kann in M+ maskiert sein. Eingriff in die
   Sichtbarkeitslogik an der empfindlichsten API-Stelle.
4. **Weitere Sprachen — eigenes Vorhaben.** `SUPPORTED` führt acht Sprachen,
   `SETTINGS_SUPPORTED` bewusst nur fünf
   ([locale/isiLive_languages.lua:37](locale/isiLive_languages.lua#L37)). Eine
   neue Sprache heißt sechs Registrierungsorte plus ~1000 Zeilen Übersetzung,
   deren Qualität kein Gate prüft.
5. **Legacy-Seasons — streichen.** Widerspricht Regel 92 (isiLive bleibt ein
   M+-Tool); Pflegeaufwand für Inhalte, die niemand als M+ spielt.

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

**Bewertung 2026-09-13 — Korrektur: "ein einzelnes Boolean" war falsch.**

Das Boolean schaltet das Feature; die Karte selbst ist bereits reich
([factory/isiLive_factory_notices.lua](factory/isiLive_factory_notices.lua)):
akzeptierte Rolle ([:10](factory/isiLive_factory_notices.lua#L10)),
Dungeonname über eine dreistufige Kette mit dokumentierter Bug-Historie
([:27-62](factory/isiLive_factory_notices.lua#L27-L62)), Keystufe aus dem
Gruppentitel, Teleport-Button, dazu eine Demo-Simulation. Im Memory liegt ein
9-Schritte-Plan mit festgehaltenen Entscheidungen: Auto-Hide nur per
12-Sekunden-Timer und Rechtsklick, kein Group-Leave- und kein Map-Change-Hook.

Es fehlen:

1. **Blizzards Quick-Join-Einblendung unterdrücken** — kein Code dafür im
   Repo. Einziger Posten mit spürbarem Alltagsnutzen: heute stehen zwei
   Hinweise übereinander. **Klein, lohnt sich.**
2. Wiederanzeige bei voller Gruppe — kein Trigger vorhanden. Weglassen.
3. **Slash-Befehl für die letzte Karte** — der nützlichste Posten, berührt
   aber die Auto-Hide-Entscheidung des bestehenden Plans: die Daten müssten
   über das Ausblenden hinaus vorgehalten werden. **Braucht User-Entscheidung.**
4. Gruppenname / Beschreibung / Playstyle plus Einzelschalter — weglassen,
   zu viele Optionen für eine Karte mit zwölf Sekunden Standzeit.

---

## Technische Notiz

Für Gruppenansagen aus einem Feature heraus ist der belastbare Weg unter 12.0
ein vorbereitetes Makro, das der Spieler klickt — nicht `SendChatMessage` aus
dem Addon. Das ist dieselbe Antwort, die wir beim Rollenmarker-Klick gewählt
haben, und sie umgeht zugleich die Chat-Filterung bei eckigen Klammern
(siehe `CLAUDE.md`, Abschnitte zum Rollenmarker und zu Chat-Farbcodes).

---

## Gesamtstand nach der Einzelprüfung (2026-09-13)

Alle zehn Punkte wurden gegen den Code geprüft. Ergebnis:

| # | Thema | Stand |
| --- | --- | --- |
| 1 | Boss-Sektionen | offen, großes Vorhaben; Bausteine da, erste Frage ungeklärt |
| 2 | Routen-Import | hängt vollständig an 1 |
| 3 | Import/Export | **offen, empfohlen als Nächstes** |
| 4 | Fortschrittsbalken | erledigt — war bereits vorhanden |
| 5 | Schriftwahl | **umgesetzt, released in 0.9.394** |
| 6 | Nameplate-Format | offen, in zwei Schritten; Vorlage berührt Regel 102 |
| 7 | Positioniermodus | gestrichen — Nutzen bereits abgedeckt |
| 8 | Season-Meta | gestrichen bis auf eine Wechsel-Meldung |
| 9 | Kleinkram | vier von fünf gestrichen/verschoben, Compartment-Icon bleibt |
| 10 | Invite-Notice | Toast-Unterdrückung lohnt; Rest weitgehend gestrichen |

Von zehn Punkten bleiben damit **fünf** übrig, die sich zu bauen lohnen:

1. **Punkt 3 — Import/Export.** Größter Hebel; `DBSchema.Sanitize` und
   `GetKnownFieldNames` erledigen die halbe Arbeit, kein Fremdcode nötig.
2. **Punkt 10.1 — Blizzards Quick-Join-Einblendung unterdrücken.** Klein,
   behebt zwei übereinanderliegende Hinweise.
3. **Punkt 9.2 — Addon-Compartment-Icon.** TOC-Eintrag plus zwei Handler.
4. **Punkt 6, Schritt 1 — Nameplate-Farbe sowie Count/Total.** Additiv und
   secret-unkritisch; die freie Formatvorlage bleibt davon getrennt.
5. **Punkt 8-Rest — einmalige Meldung beim automatischen Season-Wechsel.**

Punkt 1 und alles, was daran hängt (2, der Rest von 4, Teile von 8), ist ein
eigenes Vorhaben in Season-Pflege-Größe. Ein halbes Routenmodell ist schlechter
als keins.

**Wiederkehrende Lehre aus dieser Runde:** Die Liste entstand aus einem
Funktionsvergleich, nicht aus einer Bestandsaufnahme unseres Codes. Drei Punkte
(4, 6, 10) beschrieben Lücken, die teilweise oder ganz keine waren, und Punkt 8
berief sich auf Datenfelder, die es bei uns nie gab. Künftige Vergleichslisten
erst gegen den Code prüfen, dann bewerten.
