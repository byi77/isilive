# isiLive Anwendungsfaelle

Versionsbasis: `0.9.153`
Zuletzt aktualisiert: `2026-04-13`

## Akteure

1. Spieler (Gruppenleiter oder Mitglied).
2. isiLive-Addon-Runtime (interner Namespace: `isiLive_*`).
3. WoW-APIs und Events.

## Voraussetzungen

1. Das Addon ist geladen und nicht im Zustand `stopped`.
2. Das Season-Dataset wird ueber `ACTIVE_SEASON_ID` ausgewaehlt; aktuell `midnight_s1` mit dem live 8-Dungeon-Midnight-Season-1-Portalpool.
3. Die relevante UI ist fuer Queue-Scanning und Rendering sichtbar; waehrend hidden duerfen Addon-Message-Sync und Roster-Updates im Hintergrund weiterlaufen, die UI darf durch frischen Gruppenjoin, Key-Ende, echten Dungeon-Entry-Transition-Flow oder UI-Reload waehrend bestehender Gruppe auto-openen, und explizite Refresh-Requests duerfen genau eine hidden Sync-Reply triggern, auch waehrend eines aktiven Mythic+-Runs; derselbe Refresh-Pfad darf zusaetzlich genau eine `LibKS`-Party-Anfrage an kompatible Nicht-`isiLive`-Peers senden. Nur stopped oder paused unterdruecken die hidden `isiLive`-Reply.
4. Nicht-`isiLive`-Spieler koennen nur dann `Key` und `RIO` beitragen, wenn auf ihrer Seite ein kompatibles `LibKeystone`-sprechendes Addon laeuft; ohne sendenden Addon-Code bleiben diese Daten unresolved.
5. Raid-Gruppen sind ein eigener Hard-off-Zustand: UI aus und Background-Processing aus.
6. Die optionalen `Esc`-Tooling- und Travel-Strips sind aktiv, solange der User sie nicht explizit in den Addon-Settings deaktiviert.

## Usecase-Matrix

| ID | Titel | Primaeres Ergebnis |
|---|---|---|
| UC-01 | Invite-Erkennung und Target-Aufloesung | Das korrekte Dungeon-Ziel wird deterministisch aufgeloest |
| UC-02 | Chat-Hinweis und Teleport-Highlight | Der User bekommt einen Chat-/Info-Hinweis und sieht das korrekte Portal-Highlight |
| UC-03 | Exaktes Ziel-Dungeon betreten | Das Highlight geht sofort aus, wenn das exakte Ziel betreten wird |
| UC-04 | Portal-Cast benutzen | Alle Portal-Casts bekommen das 8h-Cooldown-Verhalten |
| UC-05 | Cooldown-Lifecycle | Cooldown laeuft natuerlich ab oder wird nach Dungeon-Ende zurueckgesetzt |
| UC-06 | Share-Keys-Aktion | Gruppen-Keys werden ueber einen Button im Party-Chat angekuendigt |
| UC-07 | RIO-Delta-Sichtbarkeit | Pro-Run-RIO-Delta wird als nicht-negatives Praefix `(+X)` angezeigt |
| UC-08 | Post-Run-Stats-Snapshot | Letzte Dungeon-DPS pro Spieler werden aus dem Blizzard-Damage-Meter gelesen und in Roster plus Tooltip gezeigt |
| UC-09 | Manuelle Rollen-Marker-Buttons | Tank-/Heiler-Rollenicons sind Secure Buttons zum Setzen von Raid-Markern |
| UC-10 | Raid-Zero-Process-Transition | Raid-Gruppen blenden die Addon-UI aus und unterdruecken Background-Processing |
| UC-11 | M+Marker World Marker | Vertikaler Balken mit 8 sicheren World-Marker-Buttons fuer direktes Place/Clear |
| UC-12 | Roster-Panel Mini Mode | Collapse-Toggle blendet Roster-Liste und `Travel` aus, waehrend kompakte Marker- und Management-Tools sichtbar bleiben |
| UC-13 | Esc-Shortcuts und Addon-Settings | Der User bekommt zwei Blizzard-UI-Einstiegsflaechen plus lokalisierte Config-Toggles und eine dedizierte Sounds-Sektion |
| UC-14 | Combat-Utility-Tracker | Live-BRes, Lust, Mythic+-Timer und gesyncter Interrupt-State bleiben im Roster-Panel sichtbar |
| UC-15 | LFG-Detektion und Portal-Highlight | LFG-Einladungen und eigene Listings loesen lokalisierte Hinweise und das passende Portal-Highlight deterministisch aus |

## UC-01 Invite-Erkennung ohne Target-Guessing

Ziel: Queue-Invite- und Join-Kontext erkennen, ohne ein Dungeon-Ziel zu raten.

1. Trigger: LFG-List- und Queue-Events treffen ein, waehrend die Main-UI sichtbar ist.
2. Inputs: Pending-Status plus eventuell sichtbare Gruppenmetadaten aus dem Queue-Payload.
3. Verarbeitung: Das Queue-Handling speichert nur den Kontext fuer einen gruppierten Join; Dungeon- oder Teleport-Aufloesung aus Queue-Payloads ist deaktiviert.
4. Output: Der Pending-Kontext fuer den gruppierten Join enthaelt hoechstens den erfassten Gruppennamen.
5. Erfolgskriterium: Der gruppierte Queue-Chat kann den erfassten Gruppenkontext nutzen, und aus Queue-Events wird kein Dungeon-Ziel geraten.

## UC-02 Gruppierte Queue-Chat-Zusammenfassung

Ziel: Den User ueber einen gruppierten Queue-Join informieren, ohne Portal- oder Dungeon-Kontext zu erfinden.

1. Trigger: Gruppenjoin ist bestaetigt, gruppierter Queue-Kontext ist vorhanden, und der Spieler ist nicht der lokale Gruppenleiter.
2. Verarbeitung: Das Addon schreibt genau einen gruppierten Queue-/Join-Zusammenfassungsblock in den Chat; Invite-Hint, Queue-Center-Notice und queue-basiertes Teleport-Highlight werden dabei nicht erzeugt.
3. Verarbeitung: Queue-Joins aktualisieren den Dungeon-Target-State nicht.
4. Benutzeraktion: Der Spieler kann den Portal-Button klicken oder manuell ins Dungeon gehen.
5. Regel: Negative Application-Status-Follow-ups duerfen queue-basierten Dungeon-Kontext weder erfinden noch wiederherstellen.
6. Regel: Es gibt keine separate generische Chat-Zeile `Dungeon erkannt`; persistenter Target-Kontext lebt in `Target Dungeon`, wenn er aus nicht-Queue-Quellen verfuegbar ist.
7. Erfolgskriterium: Gruppierter Queue-Chat feuert nur fuer gueltige Mitglieder-Joins, bleibt leader-suppressed und erzeugt nie ein geratenes Dungeon-Ziel.

## UC-03 Exaktes Target-Dungeon betreten

Ziel: Das Highlight sofort entfernen, sobald sich der Spieler im exakten Ziel-Dungeon befindet.

1. Trigger: Zone- oder Instance-Change-Events melden die aktuelle Dungeon-Map.
2. Verarbeitung: Die aktuelle Map wird mit der aktiven Ziel-Map abgeglichen.
3. Regel: Wenn die exakte Ziel-Map bekannt ist und die aktuelle Map identisch ist, wird das Highlight sofort ausgeschaltet.
4. Regel: Bei Shared-Portcasts wie Tazavesh Streets/Gambit darf spell-only-Suppression nicht mehrdeutig leeren, solange mehrere Maps auf denselben Spell gemappt sind.
5. Regel: Spell-only-Suppression ist nur erlaubt, wenn das Mapping genau eine Ziel-Map aufloest.
6. Erfolgskriterium: Kein aktives Highlight, waehrend man bereits im exakten Ziel-Dungeon ist, und kein zu fruehes Clear auf sibling Shared-Portcast-Maps.

## UC-04 Portal-Cast benutzen

Ziel: Das Portal-Cooldown-Verhalten nur dann anwenden, wenn der Portal-Cast tatsaechlich benutzt wurde.

1. Trigger: Der Spieler klickt einen Portal-Button und der Cast ist erfolgreich.
2. Verarbeitung: Portal-Action-Buttons verwenden `InsecureActionButtonTemplate`, damit Show/Hide des Parent-Frames combat-togglebar bleibt.
3. Verarbeitung: Der Cooldown-State wird aus den WoW-Spell-Cooldown-APIs gelesen.
4. Regel: Alle Dungeon-Portal-Casts teilen sich nach Benutzung dasselbe 8h-Cooldown-Fenster.
5. Regel: Sichtbare Portal-Slots bleiben in deterministischer Season-Display-Reihenfolge, auch wenn mehrere Dungeons denselben Teleport-Spell nutzen.
6. Output: Das Teleport-Grid zeigt Cooldown-Zeit und Lock-State konsistent; in `M2` zeigen ready Buttons zusaetzlich den locale-aware Dungeon-Short-Code direkt auf dem Icon.
7. Regel: Solange ein Teleport auf Cooldown ist, wird das `M2`-Short-Code-Overlay versteckt, damit der Cooldown-Timer lesbar bleibt.
8. Regel: Wenn ein Teleport-Ziel neu verfuegbar wird, wird `sounds/Portal.ogg` genau einmal als Audio-Feedback ausgespielt, ohne Secure-Attributes oder Combat-Lockdown zu beruehren.
9. Erfolgskriterium: Jeder Portal-Button spiegelt den gemeinsamen Cooldown ohne Slot-Drift wider, und `M2` behaelt die Zielerkennung ohne Mouseover.

## UC-05 Cooldown-Lifecycle

Ziel: Sowohl natuerliches Cooldown-Ende als auch Dungeon-Finish-Reset unterstuetzen.

1. Trigger A: Der Cooldown-Timer erreicht natuerlich null.
2. Ergebnis A: Portal-Casts kehren in den ready-Zustand zurueck.
3. Trigger B: Dungeon-Completion- oder Reset-Flow erzeugt Completion-Signale.
4. Ergebnis B: Der Cooldown kann entsprechend der Completion-Logik zurueckgesetzt werden.
5. Erfolgskriterium: Der Cooldown-State konvergiert in beiden unterstuetzten Pfaden wieder zu ready.

## UC-06 Share-Keys-Aktion

Ziel: Dem User erlauben, aktuelle Party-Keys schnell zu posten.

1. Trigger: Der User klickt den Button `Share Keys` im rechten Kontrollstapel.
2. Verarbeitung: Das Addon postet sofort die Key-Zeile des lokalen Spielers, bevorzugt mit Blizzard-Owned-Keystone-Hyperlink und als Fallback mit lokalisiertem Dungeon-Short-Code plus Level; der Fallback bleibt dabei anklickbar.
3. Verarbeitung: Danach broadcastet das Addon `SHAREKEYS` ueber den Addon-Sync-Channel, damit andere `isiLive`-Peers ihre eigene lokale Key-Zeile posten koennen, ohne einen vollen `Re-Sync` zu brauchen.
4. Output: Eine lokale Key-Zeile geht sofort an `PARTY`; bei Sendefehler gibt es einen lokalen Print-Fallback. Weitere Peer-Zeilen duerfen danach von antwortenden Gruppenmitgliedern folgen.
5. Regel: `Share Keys`-Button-Klicks werden entprellt, um schnelle doppelte Chat-Ausgaben zu vermeiden, und der Button zeigt waehrend der Sperre sichtbar `30s` Cooldown.
5a. Regel: Wenn ein Client eine eingehende `SHAREKEYS`-Sync-Message erhaelt, wird der lokale `Share Keys`-Button ebenfalls ueber `TriggerRemoteCooldown` fuer `30s` gesperrt; ein bereits laufender lokaler Cooldown wird nicht zurueckgesetzt.
6. Verwandte Aktion: Der danebenliegende `Re-Sync`-Button erzwingt den Hidden-Peer-Sync-Handshake, sendet zusaetzlich eine `LibKS`-Party-Anfrage fuer kompatible Nicht-`isiLive`-Peers und bleibt danach sichtbar `10s` auf Cooldown.
7. Erfolgskriterium: Der ausloesende User bekommt immer zuerst die eigene Owned-Keystone-Zeile, und Peer-Antworten bleiben senderverteilt statt aus gecachten Remote-Roster-Daten rekonstruiert zu werden.

## UC-07 RIO-Delta-Sichtbarkeit

Ziel: Rating-Aenderungen vor und nach einem Run pro Spieler im Roster zeigen, ohne negatives Anzeige-Rauschen.

1. Trigger: `CHALLENGE_MODE_START` feuert, waehrend ein Roster verfuegbar ist.
2. Verarbeitung: Das Addon erfasst eine RIO-Baseline pro normalisierter Spieleridentitaet.
3. Trigger: `CHALLENGE_MODE_COMPLETED` oder `CHALLENGE_MODE_RESET` planen einen delayed Post-Run-Refresh.
4. Verarbeitung: Die Delta-Anzeige wird erst aktiviert, nachdem der delayed Refresh-Pfad erfolgreich war; wenn er durch transientes Challenge-State-Timing blockiert ist, wird retryt. Das gilt auch, wenn Completion oder Reset eingetroffen sind, waehrend das Main-Window hidden war. Wenn vor Ausfuehrung des delayed Callbacks Raid-Hard-off aktiv wird, wird der Refresh verschoben und erst nach Raid-Ende fortgesetzt.
5. Trigger: Das Roster wird nach Rating-Updates gerendert.
6. Output: Die `RIO`-Spalte zeigt `(+X)RIO`, wenn Baseline und aktueller Wert vorhanden sind.
7. Regel: Delta wird auf nicht-negative Werte geklemmt; Minimum ist `+0`, Minus-Rendering ist verboten.
8. Regel: Testmodi (`/isilive test`, `/isilive testall`) verwenden denselben Full-Dummy-Preview-Pfad, inklusive sichtbarem positivem Dummy-Delta und einer Ghost-/Leaver-Zeile.
9. Erfolgskriterium: Die Anzeige bleibt pro Spieler ueber Unit-Slot-Wechsel stabil und zeigt niemals ein negatives Delta.

## UC-08 Post-Run-Stats-Snapshot

Ziel: Die letzte abgeschlossene Dungeon-DPS pro Spieler aus dem Blizzard-Damage-Meter ohne Guessing und ohne Layout-Churn verfuegbar machen, waehrend persistente Speicherung begrenzt bleibt.

1. Trigger: `CHALLENGE_MODE_COMPLETED` oder `CHALLENGE_MODE_RESET` zeichnen einen abgeschlossenen `M+`-Run auf; das Verlassen eines verfolgten Non-Challenge-Party-Dungeons (`Normal`, `Heroic`, `Mythic`) zeichnet einen Non-Key-Run-Snapshot auf.
2. Verarbeitung: Das Addon liest die Blizzard-`C_DamageMeter`-Overall-Run-Session, wenn `combatSources` verfuegbar sind.
3. Verarbeitung: Wenn der erste Post-Run-Read noch leer ist, weil Blizzard die Session noch nicht finalisiert hat, wird kurz auf einem deterministischen Timer retryt, statt einen leeren Snapshot dauerhaft zu akzeptieren.
4. Verarbeitung: Non-Challenge-Matching nutzt den auf Dungeon-Entry eingefrorenen Roster-Snapshot, damit spaetere Gruppenleaver am Dungeon-Ausgang weiterhin matchbar bleiben.
5. Verarbeitung: Damage-Meter-Source-Namen werden deterministisch gegen das aktuelle Roster oder den eingefrorenen Roster-Snapshot gematcht; behalten werden nur exakte Spielermatches.
6. Speicherung: Foreign-Player-Stats-Snapshots bleiben runtime-only fuer die aktuelle Session; persistent gespeichert werden nur die Last-Run-Snapshot-Felder des passenden lokalen Charakters.
7. Output: Das Roster zeigt eine eigene `DPS`-Spalte, und beim Hover ueber eine Roster-Zeile zeigt der Tooltip eine lokalisierte Zeile `Last run DPS`, wenn fuer diesen Spieler aktuell Werte vorhanden sind.
8. Output: Der Tooltip zeigt ausserdem `Level` und `Lang`, ohne das Roster-Layout erneut aufzuspannen.
9. UI-Regel: Hover ueber Roster, Buttons und Teleports nutzt isolierte `isiLive`-Tooltip-Frames mit kompakter, umbrochener Textdarstellung statt des geteilten Blizzard-`GameTooltip`.
10. Regel: Wenn Blizzard-Damage-Meter-API oder Session nicht verfuegbar sind oder fuer einen Spieler kein exakter Source-Match existiert, werden keine Stats-Zeilen gezeigt.
11. Erfolgskriterium: Roster und Tooltip zeigen in der Session die letzten Dungeon-Stats fuer passende Roster-Spieler, behalten persistent nur den Snapshot des passenden lokalen Charakters und bleiben fuer unresolved Spieler leer statt zu raten.

## UC-13 Esc-Shortcuts und Addon-Settings

Ziel: Schnelle Blizzard-Panel-Shortcuts und lokalisierte Addon-Toggles anbieten, ohne live CVars oder SavedVariables zu desynchronisieren.

1. Trigger A: Der Spieler oeffnet das WoW-`Esc`-Game-Menu, waehrend `IsiLiveDB.showEscPanel ~= false`.
2. Ergebnis A: Das Addon zeigt links von `GameMenuFrame` einen lokalisierten Tooling-Strip mit Buttons fuer `Professions`, `Talents`, `Spells`, `Achievements`, `Quests`, `Dungeons`, `Journal`, `Collections`, `Guild` und einen abgesetzten `ReloadUI`-Button, plus einen zweiten Travel-Strip weiter links mit `Arkantine`, `Hearthstone` und `Housing`.
3. Aktion: Ein Klick auf einen Tooling-Shortcut schliesst zuerst das Game-Menu und oeffnet dann das Zielpanel ueber den dedizierten Microbutton- oder Direct-Opener-Pfad; `ReloadUI` nutzt stattdessen einen Secure-Macro-Pfad, der Blizzard-`Continue` klickt und dann `/reload` ausfuehrt.
4. Combat-Sicherheit: Wenn Combat-Lockdown Secure-`ReloadUI`-Button-Refreshes blockiert, zum Beispiel Click-Registration oder Macro-Attribute-Updates, verschiebt das Addon diese Aktualisierung und wiederholt sie auf `PLAYER_REGEN_ENABLED`. Die gemounteten `Esc`-Strips selbst bleiben im Combat read-only, bleiben ueber `GameMenuFrame` sichtbar und machen aus insecure Shortcut-Klicks No-Ops statt Overlay-Layout zu mutieren.
5. Regel: Der Spellbook-Shortcut muss spellbook-spezifische Opener nutzen und darf nicht ueber das Talents-Panel routen.
6. Trigger B: Der Spieler oeffnet `Settings -> AddOns -> isiLive`.
7. Ergebnis B: Blizzard Settings zeigen Sprache, `Advanced Combat Logging`, `DM Reset on Dungeon Entry`, `Show ESC Menu Shortcuts`, `Background Opacity`, `UI Scale`, `Default UI on Open`, `Minimap Button`, `Addon Sync`, `Auto-Open on M+ Queue`, `Auto-Close on Key Start / Solo`, `Column Guides`, die dedizierte `Sounds`-Sektion mit `Sound: Lead Transfer`, `Sound: Group Join` und `Sound: Portal Available`, `Queue Debug Log (resets on reload)` und `Runtime Log (resets on reload)`.
8. Regel: Settings-Controls spiegeln live Blizzard-CVars und SavedVariables und wenden Aenderungen sofort an, ohne dass das Main-Addon-Fenster sichtbar sein muss; eine Aenderung von `Background Opacity` aktualisiert live den Main-Frame, die optionalen `Esc`-Tooling- und Travel-Strips und den Settings-Canvas. Der neue `Lock main frame position`-Schalter, der Top-right-Lock-Button sowie die Slash-Commands `/isilive lock`, `/isilive unlock` und `/isilive resetui` spiegeln denselben gespeicherten Lock-State und verhindern unabsichtliches Verschieben der Haupt-UI; `resetui` setzt Position, UI-Skalierung und Hintergrund-Deckkraft wieder auf ihre Default-Werte zurueck und zeigt den Default-Hinweis als separate Textzeile unter dem Button, bevor eine Reset-Bestaetigung abgefragt wird. Hidden Legacy-Controls (`Name Length`, `Teleport Grid Columns`, `Show DPS Column`, `Markers: Leader Only`) bleiben aus der Settings-UI draussen und nutzen derzeit feste Runtime-Defaults: `DPS` an, Marker fuer alle sichtbar, feste Namenstrunkierung und Legacy-`Travel`-Layout mit 2 Spalten.
9. Erfolgskriterium: Beide Einstiegspunkte bleiben lokalisiert, deterministisch und spiegeln den aktuellen Config- und Runtime-State.

## UC-14 Combat-Utility-Tracker

Ziel: Live-BRes, Bloodlust/Heroism/Time Warp, aktive Mythic+-Timer-Cutoffs und gesyncten Interrupt-Cooldown-State im Roster-Panel zeigen, ohne zu raten.

1. Trigger: Das Roster-Panel ist sichtbar und der One-Second-Utility-Ticker feuert, oder ein manueller Refresh, ein lokaler Lust-Spellcast oder ein `UNIT_AURA`-Update des Spielers verlangt einen Tracker-Refresh, oder die UI wird erneut sichtbar, waehrend der Utility-Tracker aus dem Hidden-Modus als dirty markiert ist.
2. Verarbeitung: Das Addon scannt `C_Spell.GetSpellCharges` mit Struct-Return (`currentCharges`, `maxCharges`, `cooldownStartTime`, `cooldownDuration`) fuer Battle Resurrection und iteriert die `HARMFUL`-Auren des Spielers ueber `C_UnitAuras.GetAuraDataByIndex("player", index, "HARMFUL")` fuer die Erschoepfungsvarianten von Bloodlust, Heroism und Time Warp.
3. Regel: Nur numerische Aura-`spellId`-Werte duerfen am Lust-Lookup teilnehmen; geschuetzte, geheime, String- oder sonstige nicht-numerische Werte muessen sicher ignoriert werden, ohne den gesamten Lust-Scan abzubrechen.
4. Regel: `UNIT_AURA`-Updates mit `isFullUpdate=true` nach Zone-/World-Transitions oder UI-Reloads muessen den aktiven Lust-State hydrieren, ohne einen neuen Onset-Callback auszufeuern.
5. Regel: `PLAYER_ENTERING_WORLD` darf nur ein kurzes 2-Sekunden-Suppress-Fenster als Sicherheitsnetz bis zum Full-Aura-Restore-Event behalten.
6. Verarbeitung: Solange ein aktiver Mythic+-Timer laeuft und das Roster-Panel sichtbar ist, muss derselbe One-Second-Utility-Ticker auch einen Vollrender des Panels ausloesen, damit die sichtbaren `+3/+2/+1`-Cutoffs live herunterzaehlen; Hidden-Modus darf diesen Utility-Poller nicht weiterlaufen lassen, und beim erneuten Oeffnen der UI darf genau ein frischer Utility-Rescan nur auf dem ersten sichtbaren Render nach Dirty-Markierung stattfinden.
7. Output: Die Tracker-Zeile zeigt BRes-Charges/Cooldown, das aktuelle Lust-Icon samt Restzeit sowie aktive `+3/+2/+1`-Timer-Cutoffs und Death-Penalty-Loss, oder `--`, wenn Daten fehlen.
8. Output: Roster-Zeilen zeigen zusaetzlich gesyncten Interrupt-Status in der `Kick`-Spalte: `ready` in Gruen, wenn verfuegbar, rote Restsekunden waehrend Cooldown und `-` in Grau, wenn die Spec keinen Interrupt hat oder der Pet-Interrupt aktuell nicht verfuegbar ist, zum Beispiel Demonology Warlock ohne Pet.
9. Verarbeitung: Interrupt-State wird lokal ueber `KickTracker` verfolgt; pet-basierte Interrupts fuer Warlock Affliction/Destruction (`Spell Lock`) und Demonology (`Axe Toss`/`Spell Lock`) tracken die Pet-Cast-Unit getrennt, damit der Cooldown nur startet, wenn das Pet wirklich castet und nicht der Spieler.
10. Regel: Gesynctes `hasKick = false` fuer No-Interrupt-Specs muss in der `Kick`-Spalte als `-` gerendert werden, nicht als `0s` oder `ready`, und als `KICK:-1:0` uebertragen werden, damit Peers es von einem ready Interrupt unterscheiden koennen.
11. Regel: Ein lokaler Kick-Cooldown darf nur durch beobachteten Interrupt-Cast oder exakte Blizzard-Cooldown-API-Daten in den laufenden Zustand wechseln; wenn keine dieser Quellen einen aktiven Cooldown belegt, darf das Addon keinen synthetischen oder geratenen Cooldown erzeugen.
12. Regel: Wenn Raid-Hard-off lokales Kick-Tracking unterdrueckt, darf Kick-Sync erst wieder aufgenommen werden, nachdem exakte Blizzard-Cooldown-Daten, ein neu beobachteter Post-Raid-Interrupt-Cast oder eine exakte `no kick`-Aufloesung den Zustand erneut belastbar hergestellt haben; malformed KICK-Payloads werden fail-closed verworfen, fremde Casts duerfen die Suppression nicht aufheben, und solange kein exakter Zustand vorhanden ist, bleibt der Kick-State unresolved und unsent.
13. Erfolgskriterium: Die Zeile und die `Kick`-Spalte aktualisieren deterministisch, bleiben nicht-negativ und verhalten sich stabil, wenn relevante APIs fehlen, gemischte Aura-Payloads mit valider und invalider Datenform auftreten oder Zone-/Reload-Aura-Restores spaet eintreffen; beim erneuten Oeffnen nach Hidden-Modus muss der aktuelle Utility-Zeilenstate sofort sichtbar sein.

## UC-15 LFG-Detektion und Portal-Highlight

Ziel: LFG-Einladungen und eigene Listings sollen das Portal-Highlight und die Chat-Hinweise deterministisch ausloesen, ohne Pending-Invite-Races oder Sprach-Fallbacks.

1. Trigger: `LFG_LIST_APPLICATION_STATUS_UPDATED` meldet `invited` oder `inviteaccepted`, oder `LFG_LIST_ACTIVE_ENTRY_UPDATE` meldet eine eigene aktive Listing-Info.
2. Verarbeitung: Der Status wird kleingeschrieben normalisiert; die Activity-zu-Map-Aufloesung nutzt nur exakte Aktivitaetsdaten. Namen, Tokens oder andere heuristische Fallbacks bleiben unresolved.
3. Verarbeitung: Der Invite-Kontext bleibt bis zur exakten Bestaetigung per `inviteaccepted` pending; danach wird der erkannte Dungeon-Zielzustand gesetzt und das Portal-Highlight ohne Sound aktiviert. Die locale-injizierte Chatmeldung bleibt an den Invite-/Join-Confirm-Pfad gebunden.
4. Regel: Eine eigene Queue-/Listing-Detektion triggert das Portal-Highlight ueber den injizierten Callback; Portal-Sound bleibt fuer Queue- und Invite-getriebene Updates unterdrueckt.
5. Regel: `GROUP_ROSTER_UPDATE` ohne Gruppe sowie `CHALLENGE_MODE_START` loeschen den gesamten LFG-Zustand inklusive pending invites.
6. Erfolgskriterium: Erkennungen erscheinen einmalig und lokalisiert, late `inviteaccepted`-Events bleiben korrekt aufloesbar, identische Listing-Updates erzeugen keinen inkonsistenten Highlight-State, und unbekannte Namen werden nie als Dungeon-Ziel geraten.

## Nichtfunktionale Regeln

1. Kein spekulatives Verhalten: unresolved oder mehrdeutiger Map-Kontext bleibt unresolved; kein Name-/Token-Fallback-Guessing.
2. Combat-protected UI-Operationen werden sicher verschoben, waehrend Fensterverschieben moeglich bleibt; Teleport-Action-Buttons duerfen Parent-Frames nicht auf protected promoten.
3. Leader-only-Aktionen bleiben fuer Nicht-Leader deaktiviert.
4. Hidden-Modus soll nicht-essentielle Verarbeitung anhalten, Queue-Scanning und permanentes Polling unterdruecken, Background-Roster- und Addon-Message-Sync aktiv halten, eventgetriebene Pre-Rendered-UI-State-Updates erlauben und nur erforderliche Auto-Open-Transitions aktiv halten; das dedizierte Party-Kick-Keep-Alive bleibt hidden aktiv, hidden Leader-Promotions spielen weiterhin den Transfer-Sound, unterdruecken aber Center-Notice und Chat-Output, und hidden `LFG_LIST_*`-Suppression bedeutet, dass verpasste Queue-Capture spaeter beim Gruppenjoin nicht als Chat nachgereicht wird.
5. Blizzard-CVar-State bleibt autoritativ: `isiLive` spiegelt `advancedCombatLogging` und `damageMeterResetOnNewInstance` nur im Blizzard-Settings-Canvas und schreibt sie nur auf explizite User-Klicks; der Blizzard-Damage-Meter-Reset auf Challenge-Start bleibt aktiv, wenn API-Support existiert.
6. RIO-Delta-Rendering muss deterministisch und nicht-negativ bleiben; nur `(+X)`.
7. UI-Visibility-Toggle ueber `CTRL+F9` muss auch im Combat anforderbar bleiben; wenn Combat-Lockdown `Show` oder `Hide` blockiert, wird der angeforderte Zustand auf `PLAYER_REGEN_ENABLED` wiederholt. `CHALLENGE_MODE_START` auto-hidet das Main-Window nur, wenn `Auto-Close on Key Start / Solo` aktiviert ist.
8. Während Combat ist nicht-essentielle Event-Verarbeitung durch das Runtime-Gate suspendiert; essentielle Events laufen weiter.
9. Re-Sync- und Key-Share-UI-Aktionen muessen Click-Spam-Guards erzwingen.
10. Event-Gate-Dispatch-Fehler muessen ueber Error-Callbacks fuer Diagnostik gemeldet werden, ohne den Gate-Loop zu terminieren.
11. Persistente Stats-Speicherung bleibt begrenzt: keine persistente History fremder Spieler und kein persistenter `Runs together`-Cache.
12. Das Verlassen oder Entferntwerden aus einer normalen Party muss den aktuellen Frame-Visibility-State behalten und ehemalige Mitglieder als Ghost-Zeilen halten, bis ein deterministischer Prune-Pfad eintritt; aktive Mitglieder muessen dabei weiterhin vor persistierten Ghosts sichtbar bleiben.
13. Manuelles Markieren, Tank blau und Heiler gruen, ist ueber sichere Rollenicon-Buttons fuer alle Gruppenmitglieder in 5er-Gruppen ohne Leader-Beschraenkung verfuegbar.
14. Raid-Gruppenerkennung bei mehr als 5 Mitgliedern blendet die Addon-UI aus, unterdrueckt Background-Processing einschliesslich hidden Kick-Keep-Alive und delayed Post-Run-Refresh-Ausfuehrung, gibt keine Raid-Transition-Notice aus und blockiert das Zurueckschalten auf M/V, bis die Gruppengroesse wieder Party ist.
15. Die optionalen `Esc`-Tooling- und Travel-Strips bleiben lokalisiert, schliessen das Game-Menu vor dem Oeffnen ihrer Ziele und halten `ReloadUI` auf einem Secure-Macro-Pfad (`/click GameMenuButtonContinue` + `/reload`), der `ActionButtonUseKeyDown` spiegelt; blockierte Secure-Refreshes fuer diesen Button werden auf `PLAYER_REGEN_ENABLED` wiederholt, waehrend beide Strips als vorab gemountete `GameMenuFrame`-Kinder keinen deferred Host-Frame-Re-Show-Pfad im Combat ausfuehren.
16. Hidden Legacy-Settings-Controls bleiben aus den Blizzard Settings entfernt und nutzen aktuell feste Runtime-Defaults: `DPS`-Spalte an, Marker fuer alle sichtbar, feste Namenstrunkierung und Legacy-`Travel`-Grid mit 2 Spalten.
17. Ready-Check-Lifecycle-Updates muessen den dedizierten Ready-Check-Refresh-Pfad nutzen, damit Row-Background-State, Waiting-Sandglass-Marker und der 20-Sekunden-Declined-Hold deterministisch zurueckgesetzt werden, ohne Secure-Role-Button-Attribute neu zu schreiben.
18. Roster-Leader-Marker muessen den echten `UnitIsGroupLeader`-State spiegeln; Leader-Zeilen bekommen eine 16x16-Krone, und wenn dieselbe Zeile auch den blauen `isiLive`-Heart-Marker hat, bleibt die Reihenfolge `heart -> crown`.

Das Runtime-Verhalten in diesem Dokument wird von `tools/validate_usecases.lua` validiert.
Aktive Regelvertraege aus `RULES_LOGIC.md` werden von `tools/validate_rules_logic.lua` validiert und ebenfalls waehrend `tools/validate_usecases.lua` erzwungen.
Aktuelle Validator-Baseline: `559` Szenarien ueber `40` Module.

1. UC-01 und UC-02: strikte Queue-Target-Aufloesung und Queue-Highlight-Verhalten ohne spekulativen Fallback.
2. UC-03: Exact-Map-Suppression und Umgang mit Shared-Portcast-Mehrdeutigkeit.
3. UC-04 und UC-05: Cooldown-Erkennung, Formatverhalten und State-Behandlung.
4. Event-Konsistenz: Target-Clear-Verhalten unter API-Shape-Varianten, gruppierte negative Application-Follow-ups und geschuetzte API-Fehler.
5. UC-07: Challenge-Start-Baseline-Capture und `(+X)RIO`-Rendering im Roster inklusive non-negativer Clamp.
6. UC-08: Post-Run-Stats-Snapshot-Capture fuer `M+` und verfolgte Non-Challenge-Party-Exits, begrenzte Persistenz sowie Tooltip- und Roster-Rendering.
7. UC-09: Secure-Button-Konfiguration der manuellen Role-Marker.
8. UC-10: Raid-Size-Zero-Process-Verhalten, hidden UI-Suppression und kein Raid-Notice-Output.
9. UC-11 und UC-12: Secure-World-Marker-Button-Konfiguration fuer M+Marker und Compact-Layout-Visibility-Logik fuer M/V/H.
10. Taint-Hardening: verschobene Secure-Attribute-Writes, verschobene `Esc`-Shortcut-Secure-Button-Refreshes, insecure Teleport-Grid-Aktionen und combat-sicheres Collapse-Handling.
11. UC-13 und UC-14: Game-Menu-Tooling-/Travel-Strips, Lokalisierung, Close-then-Open-Verhalten, verschobener Secure-Reload-Button-Refresh, Direct-Opener-Fallback-Auswahl, Settings-Canvas-State-Mirroring, Background-Opacity-Verhalten, Live-BRes-/Bloodlust-/M+-Timer-Rendering und gesyncte Interrupt-Cooldown-Anzeige.
12. UC-15: LFG-Detektion ohne Name-Fallbacks, locale-aware Chat-Hinweise, pending-invite Race-Hardening und Highlight-Dispatch.

## Rueckverfolgbarkeit zu Quelldateien

| Thema | Dateien |
|---|---|
| Queue-Erkennung und Target-Capture | `isiLive_queue.lua`, `isiLive_event_handlers_queue.lua` |
| LFG-Detektion, Chat-Hinweise und Highlight-Dispatch | `isiLive_lfg_detect.lua`, `isiLive_factory_controllers.lua`, `isiLive_texts.lua`, `isiLive_teleport_ui.lua` |
| Highlight-Aufloesung und Inside-Dungeon-Suppression | `isiLive_highlight.lua` |
| Teleport-Spell-Mapping und Cooldown-Verhalten | `isiLive_teleport.lua`, `isiLive_spell_utils.lua`, `isiLive_teleport_ui.lua` |
| Gruppen-Lifecycle, Leader-State-Mirroring und Roster-Rebuild | `isiLive_group.lua`, `isiLive_roster.lua` |
| RIO-Baseline-Capture und Delta-Preview | `isiLive_event_handlers_challenge.lua`, `isiLive_roster.lua`, `isiLive_test_mode.lua`, `isiLive_runtime_state.lua` |
| Last-Run-DPS-Capture und begrenzte Stats-Persistenz | `isiLive_stats.lua`, `isiLive_event_handlers_challenge.lua`, `isiLive_event_handlers_runtime.lua`, `isiLive_roster_panel.lua`, `isiLive_roster_tooltip.lua` |
| Combat-Utility-Tracker-Zeile, Kick-State und LibKeystone-Key-Interop | `isiLive_cd_tracker.lua`, `isiLive_mplus_timer.lua`, `isiLive_kick_tracker.lua`, `isiLive_sync.lua`, `isiLive_keysync.lua`, `isiLive_factory_controllers.lua`, `isiLive_roster_panel.lua`, `isiLive_roster_tooltip.lua`, `isiLive_texts.lua` |
| Leader-Transfer-Erkennung und Feedback | `isiLive_leader_watch.lua` |
| UI-Aktionen, Rollen-Buttons, Key-Share-Button | `isiLive_roster_panel.lua` |
| Esc-Tooling-/Travel-Strips und Blizzard-Settings-Canvas | `isiLive_ui.lua`, `isiLive_settings.lua`, `isiLive_factory.lua`, `isiLive_texts.lua`, `isiLive_ui_common.lua` |
| Auto-Marker-Logik, entfernt oder ersetzt | `isiLive_group.lua` nach Bereinigung |
| Raid-Size-H-Mode-UI | `isiLive_roster_panel.lua`, `isiLive_group.lua` |
| Event-Routing und Gate | `isiLive_events.lua`, `isiLive_event_handlers.lua`, `isiLive_event_handlers_runtime.lua`, `isiLive_event_handlers_queue.lua`, `isiLive_event_handlers_challenge.lua` |
