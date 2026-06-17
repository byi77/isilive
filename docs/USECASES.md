# isiLive Anwendungsfaelle

Versionsbasis: `0.9.325`
Zuletzt aktualisiert: `2026-06-17`

## Akteure

1. Spieler (Gruppenleiter oder Mitglied).
2. isiLive-Addon-Runtime (interner Namespace: `isiLive_*`).
3. WoW-APIs und Events.

## Voraussetzungen

1. Das Addon ist geladen und nicht im Zustand `stopped`.
2. Das Season-Dataset wird ueber `ACTIVE_SEASON_ID` ausgewaehlt; aktuell `midnight_s1` mit dem live 8-Dungeon-Midnight-Season-1-Portalpool.
3. Die relevante UI ist fuer Queue-Scanning und Rendering sichtbar; waehrend hidden duerfen Addon-Message-Sync und Roster-Updates im Hintergrund weiterlaufen, die UI darf durch frischen Gruppenjoin, Key-Ende, echten Dungeon-Entry-Transition-Flow oder UI-Reload waehrend bestehender Gruppe auto-openen, und explizite Refresh-Requests duerfen genau eine hidden Sync-Reply triggern, auch waehrend eines aktiven Mythic+-Runs; derselbe Refresh-Pfad darf zusaetzlich genau eine `LibKS`-Party-Anfrage an kompatible Nicht-`isiLive`-Peers senden. Wenn LFGDetect bereits einen konkreten lokalen Map-Kontext kennt, gewinnt dieser fuer das Portal-Highlight gegen peer-synced Zielkontext. Nur stopped oder paused unterdruecken die hidden `isiLive`-Reply.
4. Nicht-`isiLive`-Spieler koennen nur dann `Key` und `RIO` beitragen, wenn auf ihrer Seite ein kompatibles `LibKeystone`-sprechendes Addon laeuft; ohne sendenden Addon-Code bleiben diese Daten unresolved.
5. Raid-Gruppen sind ein eigener Hard-off-Zustand: UI aus und Background-Processing aus.
6. Die optionalen `Esc`-Tooling-, Travel-, Mounts- und Addons-Strips sind aktiv, solange der User sie nicht explizit in den Addon-Settings deaktiviert.
7. Die Addon-Sprache kommt aus der Lokalisierungstabelle. Neue produktive Texte werden in Deutsch und Englisch gepflegt; vorbereitete weitere Locales duerfen englischen Fallback oder nachbearbeitete Community-Uebersetzungen tragen. Nur die Sound-Settings-Texte sind fuer die vorbereiteten Locales `frFR`, `esES`, `ptBR`, `itIT`, `ruRU` und `trTR` nachbearbeitet; andere Bereiche duerfen weiterhin englische Fallbacks tragen.

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
| UC-14 | Combat-Utility-Tracker | Live-BRes, Lust, Mythic+-Timer, M+-Killtracker und gesyncter Interrupt-State bleiben im Roster-Panel sichtbar |
| UC-15 | LFG-Detektion und Portal-Highlight | LFG-Einladungen und eigene Listings loesen lokalisierte Hinweise und das passende Portal-Highlight deterministisch aus |
| UC-16 | BR- und Bloodlust-Gruppen-Announce im Mythic+ | Jeder BR- und Bloodlust-Cast eines isiLive-Spielers wird innerhalb eines aktiven Keys genau einmal als lokalisierte Chat-Zeile an alle isiLive-Peers verteilt |
| UC-17 | Mob-Tooltip mit Forces-Anteil | Hovern ueber einen Mob in einem aktiven M+-Run haengt eine Forces-Zeile aus der DB an den Blizzard-Tooltip an |
| UC-18 | Nameplate-Forces-Overlay im Mythic+ | Optionales Live-Overlay auf jeder feindlichen Namensplakette zeigt den Mob-Forces-Beitrag |
| UC-19 | (reserviert / nicht vergeben) | Nummer ausgelassen; nicht neu belegen, damit bereits referenzierte Test-/Commit-Querverweise stabil bleiben |
| UC-20 | Clear-Log-Buttons im Settings-Administrativ | Zwei dedizierte Action-Buttons in Settings -> Administrative leeren Runtime-Log und Queue-Debug-Log ohne Slash-Command |
| UC-21 | Multi-Kick-Extras im Roster-Tooltip | Zusaetzliche Interrupt-Spells einer Klasse (Prot Pala Avenger's Shield) werden separat vom Primary getrackt, ueber den Sync-Pfad an Peers verteilt und im Hover-Tooltip angezeigt |
| UC-22 | LFG-Invite-Liste entfernt | Die verworfene offene Premade-LFG-Invite-Liste hat keine Module, keine Settings, keine SavedVariable und kein Runtime-Wiring |
| UC-23 | Spieler-Stats-Box | Eine optionale, eigenstaendige Stats-Box zeigt live gelesene Spielerwerte ohne Guessing und bleibt unabhaengig von den Main-UI-Layouts verschiebbar |
| UC-24 | Gruppensuche- und Roster-Klassenbonus-Hinweise | Bewerber-, Suchergebnis- und Roster-Zeilen zeigen relevante nicht-Utility-Gruppenboni kompakt an und ergaenzen LFG-Tooltips mit lokalisierten Bonusdetails |

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
8. Regel: Das Teleport-Grid spielt beim Ready- oder Highlight-Wechsel keinen Portal-Sound mehr; `sounds/Portal.ogg` gehoert zum eingehenden Beschwoerungsdialog des lokalen Spielers.
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
2. Verarbeitung: Das Addon broadcastet zuerst `SHAREKEYS` ueber den Addon-Sync-Channel, damit andere `isiLive`-Peers ihre eigene lokale Key-Zeile posten koennen, ohne einen vollen `Re-Sync` zu brauchen; dieser Request gilt nur dann als erfolgreich, wenn der Addon-Message-Dispatch selbst Erfolg meldet.
3. Verarbeitung: Danach postet das Addon die Key-Zeile des lokalen Spielers in den passenden Gruppenchat (`PARTY` oder `INSTANCE_CHAT`), bevorzugt mit Blizzard-Owned-Keystone-Hyperlink und als Fallback mit lokalisiertem Dungeon-Short-Code plus Level; der Fallback bleibt dabei anklickbar.
4. Output: Der Peer-Request wird vor der sichtbaren lokalen Key-Zeile dispatcht; bei Sendefehler gibt es einen lokalen Print-Fallback, der nicht als erfolgreicher Gruppenchat-Share zaehlt. Weitere Peer-Zeilen duerfen danach von antwortenden Gruppenmitgliedern folgen.
5. Regel: `Share Keys`-Button-Klicks werden entprellt, um schnelle doppelte Chat-Ausgaben zu vermeiden, und der Button zeigt waehrend der Sperre sichtbar die Restzeit als Cooldown-Text ohne Wechsel auf den nackten Buttontext; ein fehlgeschlagener eigener Gruppenchat-Post ohne erfolgreich dispatchten `SHAREKEYS`-Request darf keine Sperre starten.
5a. Regel: Wenn ein Client eine eingehende `SHAREKEYS`-Sync-Message erhaelt, wird der lokale `Share Keys`-Button ueber `TriggerRemoteCooldown` fuer `30s` gesperrt, auch wenn dieser Empfangspfad keinen eigenen Gruppenchat-Share ausloesen kann; ein bereits laufender lokaler Cooldown wird nicht zurueckgesetzt.
5b. Regel: Im Hello-Ack-/REQSYNC-Fan-out spiegelt jeder Client eine laufende Button-Sperre als `SKCD:<rest>`-Payload an neu beigetretene Gruppenmitglieder. Der Empfaenger uebernimmt die Restzeit per Max-Merge (verlaengern ja, verkuerzen nie) und klemmt sie auf das lokale `30s`-Fenster; aeltere Clients ignorieren das unbekannte Payload.
5c. Regel: Die laufende Button-Sperre wirkt zugleich als Ruhefenster fuer den Antwortpfad: solange sie aktiv ist, beantwortet der Client eingehende `SHAREKEYS` nicht mit einem erneuten eigenen Key-Post (schliesst den Doppelpost nach eigenem Klick aus, da der Klickpfad den Antwort-Zeitstempel nicht schreibt).
6. Verwandte Aktion: Der danebenliegende `Re-Sync`-Button erzwingt den Hidden-Peer-Sync-Handshake, sendet zusaetzlich eine `LibKS`-Party-Anfrage fuer kompatible Nicht-`isiLive`-Peers und bleibt danach sichtbar `10s` auf Cooldown. Im kompakten vertikalen `V`-Layout ist der `Re-Sync`-Button verborgen; in den anderen Layouts bleibt er sichtbar.
7. Erfolgskriterium: Der ausloesende User bekommt eine eigene Owned-Keystone-Zeile, waehrend der Peer-Request vorher bereits dispatcht wurde, und Peer-Antworten bleiben senderverteilt statt aus gecachten Remote-Roster-Daten rekonstruiert zu werden.

## UC-07 RIO-Delta-Sichtbarkeit

Ziel: Rating-Aenderungen vor und nach einem Run pro Spieler im Roster zeigen, ohne negatives Anzeige-Rauschen.

1. Trigger: `CHALLENGE_MODE_START` feuert, waehrend ein Roster verfuegbar ist.
2. Verarbeitung: Das Addon erfasst eine RIO-Baseline pro normalisierter Spieleridentitaet.
3. Trigger: `CHALLENGE_MODE_COMPLETED` oder `CHALLENGE_MODE_RESET` planen einen delayed Post-Run-Refresh.
4. Verarbeitung: Die Delta-Anzeige wird erst aktiviert, nachdem der delayed Refresh-Pfad erfolgreich war; wenn er durch transientes Challenge-State-Timing blockiert ist, wird retryt. Das gilt auch, wenn Completion oder Reset eingetroffen sind, waehrend das Main-Window hidden war. Wenn vor Ausfuehrung des delayed Callbacks Raid-Hard-off aktiv wird, wird der Refresh verschoben und erst nach Raid-Ende fortgesetzt.
5. Trigger: Das Roster wird nach Rating-Updates gerendert.
6. Output: Die `RIO`-Spalte zeigt `(+X)RIO`, wenn Baseline und aktueller Wert vorhanden sind.
7. Regel: Delta wird auf nicht-negative Werte geklemmt; Minimum ist `+0`, Minus-Rendering ist verboten.
8. Regel: Der Admin-Testmodus (`/isilive testall`) verwendet den Full-Dummy-Preview-Pfad, inklusive sichtbarem positivem Dummy-Delta, einer Ghost-/Leaver-Zeile, Demo-Daten fuer M+-Timer, Combat-CDs, unteren M+-Forces-Tracker, Statsbox, Portal-Navigator, Centerbox-Portal, Non-Mythic-Dungeon-Entry-Centerbox, M+-Forces-Nameplates/-Tooltip, LFG-Bonusmarker, Ready-Check-Hold-Zeilen, Share-Keys-Cooldown, Death-Alert-Preview, Sound-Preview und verschiebbarem Demo-Simulations-Tablet. Das Tablet ist zusaetzlich ueber `/isilive sim` umschaltbar, fuehrt nur lokale Vorschau-Hooks aus, markiert blockierte Simulationen rot und sendet keine echten Chatposts oder Gruppenaktionen. Centerbox-Portal und Non-Mythic-Dungeon-Entry-Centerbox bleiben im Demomodus parallel sichtbar, damit sie sich nicht gegenseitig verdraengen. Demo-Feature-Schalter einschliesslich `Accepted-invite notice`, `Group-join target notice` und Sound-Preview-Settings werden nur temporaer gesetzt und beim Verlassen auf die vorherigen User-Settings zurueckgesetzt.
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
2. Ergebnis A: Das Addon zeigt links von `GameMenuFrame` einen lokalisierten Tooling-Strip mit Buttons fuer `Professions`, `Talents`, `Spells`, `Achievements`, `Quests`, `Dungeons`, `Journal`, `Collections`, `Guild` und einen abgesetzten `ReloadUI`-Button, plus einen zweiten Travel-Strip weiter links mit `Arkantine`, `Hearthstone` und `Housing`, einen Mounts-Strip unter `Reisen` mit verifizierten Shortcuts fuer Favoriten-Mount, Auktionshaus-Mount und Reparatur-Mount sowie einen Addons-Strip mit installierten und aktivierten Schnellzugriffen fuer isiLive, MDT, MRT, DBM, BigWigs, Details, SimC und Platynator.
3. Aktion: Ein Klick auf einen Tooling-Shortcut schliesst zuerst das Game-Menu und oeffnet dann das Zielpanel ueber den dedizierten Microbutton- oder Direct-Opener-Pfad; `ReloadUI` nutzt stattdessen einen Secure-Macro-Pfad, der Blizzard-`Continue` klickt und dann `/reload` ausfuehrt. Mount-Shortcuts sind sichere Macro-Buttons, schliessen zuerst das Game-Menu und casten danach den verifizierten lokalisierten Spellnamen; der Favoriten-Shortcut castet den Spell eines verifiziert favorisierten Mounts statt den globalen Random-Favorite-Spellnamen. Mount-Shortcuts werden nur angezeigt, wenn die Favoriten- beziehungsweise Mount-Verfuegbarkeit ueber `C_MountJournal` und der Spellname ueber Blizzard-Spell-APIs verifiziert ist. Externe Addon-Schnellzugriffe erscheinen nur fuer den aktuellen Charakter aktivierte Addons, laden ein aktiviertes Load-on-Demand-Addon verifiziert nach, warten vor dem Slash-Dispatch auf ein beobachtet geschlossenes `GameMenuFrame`, tolerieren eine kurze verzoegerte Registrierung desselben exakten Slash-Alias und rufen danach dessen registrierten `SlashCmdList`-Handler direkt mit `msg, editBox` auf, ohne Slash-Text in den Chat zu schreiben; der isiLive-Schnellzugriff oeffnet direkt die isiLive-Settings.
4. Combat-Sicherheit: Wenn Combat-Lockdown Secure-`ReloadUI`-Button-Refreshes oder sichere Mount-Button-Attribute blockiert, zum Beispiel Click-Registration oder Macro-Attribute-Updates, verschiebt das Addon diese Aktualisierung und wiederholt sie auf `PLAYER_REGEN_ENABLED`. Die gemounteten `Esc`-Strips selbst bleiben im Combat read-only, bleiben ueber `GameMenuFrame` sichtbar und machen aus insecure Shortcut-Klicks No-Ops statt Overlay-Layout zu mutieren.
5. Regel: Der Spellbook-Shortcut muss spellbook-spezifische Opener nutzen und darf nicht ueber das Talents-Panel routen.
6. Trigger B: Der Spieler oeffnet `Settings -> AddOns -> isiLive`.
7. Ergebnis B: Blizzard Settings zeigen — gruppiert in eigene Hauptsektionen mit Beta-Hinweis oben und VIP-Gast-Einstellungen unten:
   - **Beta-Hinweis**: Issue-Tracker- und CurseForge-Kommentar-Link.
   - **General**: Sprache und `Default UI on Open`.
   - **ESC-Menue**: `Show ESC Menu Shortcuts` und `Hearthstone Selection`.
   - **Display**: `UI Scale`, `Background Opacity`, Spieler-Stats-Box mit Enable-, Lock-, Hintergrund-Deckkraft-, Schriftgroessen-Offset-, Zahlenmodus- und Detailzeilen-Control fuer Leech, Speed, Haltbarkeit, Ausdauer und Vermeidung, `Minimap Button`, `Show Timeways Navigator`, `Group Finder: Language Flags`, `Group Finder: Buff rating hearts`, `Tooltip: Language Flags`, `Accepted-invite notice`, `Group-join target notice`.
   - **Behavior**: `Addon Sync`, `Lock main frame position`, `Fade out in Combat (M2 only)`, gefolgt vom Auto-Show/Hide-Block mit Erklaerung (`Show on Login / Reload`, `Auto-Open on M+ Queue`, `Auto-Open on Key End`, `Auto-close when key starts`, `Auto-close when leaving the group`), und einem statischen Raid-Behavior-Hinweis statt einem 1-Optionen-Selector.
   - **Nameplates**: 3-Modi-Selector `Off / Tooltip / Nameplate` fuer den M+-Forces-Overlay, plus `Show percentage`, `Show remaining needed`, `Font size`, `Position`, `X offset`, `Y offset` und ein Live-Preview.
   - **Sounds**: Soundkanal-Selector `Master / SFX` mit Default `Master`; `Sound: Lead Transfer`, `Sound: Full Group`, `Sound: Incoming Summon`, `Sound: Battle Res`, `Sound: Battle Res Ready`, `Sound: Bloodlust`, `Sound: Bloodlust Ready`, `Sound: Ready Check Complete`, `Sound: Tank died` und `Sound: Healer died`, jeweils mit eigenem Play-Button zum Probehoeren auch bei deaktiviertem Toggle und nachbearbeiteten Sound-Settings-Texten fuer alle acht gepflegten UI-Locale-Tabellen. Native WoW-Text-to-Speech-Controls werden nicht gerendert. Diese Nachbearbeitung gilt nur fuer den Sound-Settings-Bereich, nicht fuer alle Texte der vorbereiteten Locales. Eingehende Beschwoerungen des lokalen Spielers spielen den Summon-Sound ueber den klassischen `CONFIRM_SUMMON`-Pfad und ueber den statusbasierten `INCOMING_SUMMON_CHANGED`-Pfad nur bei `Enum.SummonStatus.Pending`.
   - **Chat Announcements**: `Chat: Announce Battle Res usage in M+`, `Chat: Announce Bloodlust casts in M+`.
   - **Administrative**: `Advanced Combat Logging`, `DM Reset on Dungeon Entry`, `Queue Debug Log (resets on reload)`, `Clear Queue Debug Log`, `Runtime Log (resets on reload)`, `Clear Runtime Log`.
   - **Reset-Aktionen**: `/isilive resetui` und `Reset All Settings`, jeweils mit Bestaetigung.
   - **VIP Guest Settings**: VIP-Gast-Sound-Schalter fuer Astral Aurochs, Grand Expedition Yak und Trader's Gilded Brutosaur.
8. Regel: Settings-Controls spiegeln live Blizzard-CVars und SavedVariables und wenden Aenderungen sofort an, ohne dass das Main-Addon-Fenster sichtbar sein muss; eine Aenderung von `Background Opacity` aktualisiert live den Main-Frame, die optionalen `Esc`-Tooling-, Travel-, Mounts- und Addons-Strips und den Settings-Canvas. Der neue `Lock main frame position`-Schalter, der Top-right-Lock-Button sowie die Slash-Commands `/isilive lock`, `/isilive unlock` und `/isilive resetui` spiegeln denselben gespeicherten Lock-State und verhindern unabsichtliches Verschieben der Haupt-UI; `resetui` setzt Position, UI-Skalierung und Hintergrund-Deckkraft wieder auf ihre Default-Werte zurueck und zeigt den Default-Hinweis als separate Textzeile unter dem Button, bevor eine Reset-Bestaetigung abgefragt wird. Hidden Legacy-Controls (`Name Length`, `Teleport Grid Columns`, `Show DPS Column`, `Markers: Leader Only`) bleiben aus der Settings-UI draussen und nutzen derzeit feste Runtime-Defaults: `DPS` an, Marker fuer alle sichtbar, feste Namenstrunkierung und Legacy-`Travel`-Layout mit 2 Spalten.
9. Regel: Die Ruhestein-Auswahl bietet `random-owned`, den Standard-Ruhestein `item:6948` und nur konkret besessene Ruhestein-Toys an. Die Liste aktualisiert sich bei `TOYS_UPDATED` und `GET_ITEM_INFO_RECEIVED`, zeigt im deutschen Addon-Locale client-lokalisierte Namen und in allen anderen Addon-Sprachen die verifizierten englischen Namen. Nicht verifizierte oder nicht besessene Toy-Ziele bleiben verborgen statt als numerischer Fallback angezeigt zu werden.
10. Regel: Der `Esc`-Travel-Ruhestein-Button wendet die gespeicherte Auswahl auf seinen sicheren Action-Button an. Wenn Combat-Lockdown oder ein aktiver Keydown sichere Attribut-Updates blockiert, wird die Aktualisierung verschoben und auf dem naechsten erlaubten Refresh wiederholt.
11. Regel: VIP-Gast-Sound-Schalter muten oder entmuten nur die verifizierten Sound-Datei-IDs fuer Astral Aurochs, Grand Expedition Yak und Trader's Gilded Brutosaur, persistieren als SavedVariables und werden beim Laden sowie bei Settings-Aenderungen erneut angewendet.
12. Regel: Wenn die Addon-Sprache `ruRU` aktiv ist, nutzen lokalisierte Hauptfenster-Texte und gefittete Button-Labels einen kyrillisch-faehigen Font. Addon-eigene sichtbare FontStrings und private isiLive-Tooltips wechseln bei konkreten kyrillischen Payload-Texten aus Locale-, Blizzard-API-, Spieler-/Realm- oder Dungeon-/Map-Daten ebenfalls vor dem Schreiben auf diesen Font, damit russische Zeichen auch auf nicht-russischen WoW-Clients nicht als Platzhalterkaestchen erscheinen. Blizzard-eigene Fenster bleiben unveraendert.
13. Erfolgskriterium: Beide Einstiegspunkte bleiben lokalisiert, deterministisch und spiegeln den aktuellen Config- und Runtime-State.

## UC-14 Combat-Utility-Tracker

Ziel: Live-BRes, Bloodlust/Heroism/Time Warp, aktive Mythic+-Timer-Cutoffs, den M+-Killtracker und gesyncten Interrupt-Cooldown-State im Roster-Panel zeigen, ohne zu raten.

1. Trigger: Das Roster-Panel ist sichtbar und der One-Second-Utility-Ticker feuert, oder ein manueller Refresh, ein lokaler Lust-Spellcast oder ein `UNIT_AURA`-Update des Spielers verlangt einen Tracker-Refresh, oder die UI wird erneut sichtbar, waehrend der Utility-Tracker aus dem Hidden-Modus als dirty markiert ist.
2. Verarbeitung: Das Addon scannt `C_Spell.GetSpellCharges` mit Struct-Return (`currentCharges`, `maxCharges`, `cooldownStartTime`, `cooldownDuration`) fuer Battle Resurrection und iteriert die `HARMFUL`-Auren des Spielers ueber `C_UnitAuras.GetAuraDataByIndex("player", index, "HARMFUL")` fuer die Erschoepfungsvarianten von Bloodlust, Heroism und Time Warp.
3. Regel: Nur numerische Aura-`spellId`-Werte duerfen am Lust-Lookup teilnehmen; geschuetzte, geheime, String- oder sonstige nicht-numerische Werte muessen sicher ignoriert werden, ohne den gesamten Lust-Scan abzubrechen.
4. Regel: `UNIT_AURA`-Updates mit `isFullUpdate=true` nach Zone-/World-Transitions oder UI-Reloads muessen den aktiven Lust-State hydrieren, ohne einen neuen Onset-Callback auszufeuern.
5. Regel: `PLAYER_ENTERING_WORLD` darf beim Uebergang in eine Party-Instanz keine Battle-Res-ready- oder Bloodlust-ready-Ansage ausloesen; ein aktiver Challenge-Kontext darf dabei keinen synthetischen Timer-Reset erhalten.
6. Verarbeitung: Solange ein aktiver Mythic+-Timer laeuft und das Roster-Panel sichtbar ist, muss derselbe One-Second-Utility-Ticker auch einen Vollrender des Panels ausloesen, damit die sichtbaren `+3/+2/+1`-Cutoffs live herunterzaehlen; Hidden-Modus darf diesen Utility-Poller nicht weiterlaufen lassen, und beim erneuten Oeffnen der UI darf genau ein frischer Utility-Rescan nur auf dem ersten sichtbaren Render nach Dirty-Markierung stattfinden.
6a. Verarbeitung: Nach einem verifizierten LFG-Invite-Target-Announce zeigt die untere M+-Killtracker-Zeile bis `CHALLENGE_MODE_START` den belastbaren Ziel-Dungeon plus Keystufe als rechtsbuendigen kombinierten Text; die Keystufe erscheint nur, wenn sie positiv verifiziert numerisch vorliegt. Sobald der Key gestartet ist, wird dieser Pre-Key-Zieltext unterdrueckt und die Zeile nutzt wieder die Forces-Prozentanzeige.
6b. Verarbeitung: Wenn waehrend aktiver Prozentdaten ein verifizierter Ziel-Dungeon bekannt ist, bleibt dessen Name linksbuendig als helles Outline-Label mit dunkler Hinterlegung auf dem Prozentbalken sichtbar; die aktive Keystufe wird direkt daneben nur angezeigt, wenn sie positiv aus dem gestarteten M+-Timer-Keylevel stammt, und darf nicht aus der Target-Dungeon-Aufloesung uebernommen werden.
6c. Verarbeitung: `KillTrack` muss auf `PLAYER_REGEN_ENABLED` und vor jedem aktiven Refresh-Ticker-Notify die Blizzard-Live-Szenariodaten erneut lesen und daraus die Pull-/Gesamtprozentwerte aktualisieren, damit abgeschlossene Pulls sofort in UI und Nameplate-Restbedarf sichtbar werden.
7. Output: Die Tracker-Zeile zeigt BRes-Charges/Cooldown, das aktuelle Lust-Icon samt kompakter Restzeit ohne redundantes `BL:`-Praefix, aktive `+3/+2/+1`-Timer-Cutoffs und Death-Penalty-Loss, den Pre-Key-Zieltext oder den aktuellen Killtracker-Prozentstand mit aktivem Dungeon-plus-Keylevel-Label, oder `--`, wenn Daten fehlen. Wenn der Tracker waehrend eines laufenden M+-Timers zuvor null verfuegbare Battle-Res-Aufladungen oder einen positiven Battle-Res-Cooldown beobachtet hat und ein spaeterer natuerlicher Scan entweder den angezeigten Battle-Res-Cooldown bei null sieht oder mindestens eine verfuegbare Aufladung findet, spielt der eigene Battle-Res-ready-Klanghinweis genau einmal pro Wiederverfuegbarkeit; der erste verfuegbare Battle-Res-Zustand direkt nach Key-Start bleibt stumm, danach wird jede weitere Wiederverfuegbarkeit angesagt. Sichtbare UI-Rescans muessen denselben Transition-Pfad verwenden wie der Factory-CD-Tracker, damit der angezeigte Nullpunkt nicht an der Ready-Ansage vorbei aktualisiert wird. Key-Ende-, Key-Abbruch-, Dungeon-Eintritts-, Dungeon-Verlassen-, Gruppen-Verlassen- oder sonstige Nicht-laufend-Refreshes duerfen diesen Klanghinweis nicht ausloesen und verwerfen den beobachteten Ready-Zyklus, damit ein spaeterer Welt-/Zonen-Refresh keine nachtraegliche Ansage erzeugt. Wenn der Tracker waehrend eines laufenden M+-Timers mit aktiver Gruppe zuvor einen aktiven Bloodlust-/Heroism-/Time-Warp-Erschoepfungsdebuff beobachtet hat und entweder der angezeigte Erschoepfungs-Timer null erreicht oder ein spaeterer natuerlicher Scan keinen aktiven Erschoepfungsdebuff mehr findet, spielt der eigene Bloodlust-ready-Klanghinweis und wiederholt ihn bei unbenutzter Verfuegbarkeit alle 60 Sekunden, bis ein neuer aktiver Erschoepfungsdebuff beobachtet wird; UNIT_AURA-Removal-Payloads muessen dafuer einen CD-Scan ausloesen, weil Aura-Entfernungen keine belastbare `spellId` mehr liefern muessen. Key-Ende-, Key-Abbruch-, Dungeon-Eintritts-, Dungeon-Verlassen-, Gruppen-Verlassen- oder sonstige Nicht-laufend-Refreshes oder fehlende aktive Gruppe duerfen diesen Klanghinweis und seine 60-Sekunden-Erinnerungen nicht ausloesen und verwerfen den beobachteten Ready-Zyklus, damit ein spaeterer Welt-/Zonen-Refresh keine nachtraegliche Ansage erzeugt. Bei ausgeblendeter UI bleiben die eventgetriebenen CD-Refreshes fuer diese Ready-Klanghinweise erlaubt, waehrend der dauerhafte Hidden-CD-Ticker aus bleibt.
8. Output: Roster-Zeilen zeigen zusaetzlich gesyncten Interrupt-Status in der `Kick`-Spalte: `ready` in Gruen, wenn verfuegbar, rote Restsekunden waehrend Cooldown und `-` in Grau, wenn die Spec keinen Interrupt hat oder der Pet-Interrupt aktuell nicht verfuegbar ist, zum Beispiel Demonology Warlock ohne Pet.
9. Verarbeitung: Interrupt-State wird lokal ueber `KickTracker` verfolgt; pet-basierte Interrupts fuer Warlock Affliction/Destruction (`Spell Lock`) und Demonology (`Axe Toss`/`Spell Lock`) tracken die Pet-Cast-Unit getrennt, damit der Cooldown nur startet, wenn das Pet wirklich castet und nicht der Spieler. Heal-Specs ohne Interrupt (Holy Paladin spec 65, Mistweaver Monk spec 270, Restoration Druid spec 105, Discipline Priest spec 256, Holy Priest spec 257) sind explizit in `NO_INTERRUPT_SPEC_IDS` gelistet und liefern `hasKick=false`, sodass die `Kick`-Spalte ein graues `-` rendert statt einen ungueltigen Cooldown.
10. Regel: Gesynctes `hasKick = false` fuer No-Interrupt-Specs muss in der `Kick`-Spalte als `-` gerendert werden, nicht als `0s` oder `ready`, und als `KICK:-1:0` uebertragen werden, damit Peers es von einem ready Interrupt unterscheiden koennen.
11. Regel: Ein lokaler Kick-Cooldown darf nur durch beobachteten Interrupt-Cast oder exakte Blizzard-Cooldown-API-Daten in den laufenden Zustand wechseln; wenn keine dieser Quellen einen aktiven Cooldown belegt, darf das Addon keinen synthetischen oder geratenen Cooldown erzeugen.
12. Regel: Wenn Raid-Hard-off lokales Kick-Tracking unterdrueckt, darf Kick-Sync erst wieder aufgenommen werden, nachdem exakte Blizzard-Cooldown-Daten, ein neu beobachteter Post-Raid-Interrupt-Cast oder eine exakte `no kick`-Aufloesung den Zustand erneut belastbar hergestellt haben; malformed KICK-Payloads werden fail-closed verworfen, fremde Casts duerfen die Suppression nicht aufheben, und solange kein exakter Zustand vorhanden ist, bleibt der Kick-State unresolved und unsent.
13. Regel: `CHALLENGE_MODE_COMPLETED` und `CHALLENGE_MODE_RESET` raeumen den M+-Timer-Snapshot sofort vollstaendig auf (`completed=false`, `timer=0`, `timeLimit=0`, `keyLevel=0`, `deaths=0`) und aktualisieren die CD-Tracker-Zeile, sodass die Timer-Box nach beendetem oder abgebrochenem Key nicht mit veralteten Werten stehen bleibt. `PLAYER_ENTERING_WORLD` darf einen aktiv laufenden Key niemals stoppen oder Zeitstaende zuruecksetzen und bleibt nach bereits geloeschtem Snapshot wirkungslos.
14. Erfolgskriterium: Die Zeile, der M+-Killtracker und die `Kick`-Spalte aktualisieren deterministisch, bleiben nicht-negativ und verhalten sich stabil, wenn relevante APIs fehlen, gemischte Aura-Payloads mit valider und invalider Datenform auftreten oder Zone-/Reload-Aura-Restores spaet eintreffen; beim erneuten Oeffnen nach Hidden-Modus muss der aktuelle Utility-Zeilenstate sofort sichtbar sein, und ein abgeschlossener Pull darf nicht bis zum naechsten Combat-Start unsichtbar bleiben.

## UC-15 LFG-Detektion und Portal-Highlight

Ziel: LFG-Einladungen und eigene Listings sollen das Portal-Highlight und die Chat-Hinweise deterministisch ausloesen, ohne Pending-Invite-Races oder Sprach-Fallbacks.

1. Trigger: `LFG_LIST_APPLICATION_STATUS_UPDATED` meldet `invited` oder `inviteaccepted`, `LFG_LIST_ACTIVE_ENTRY_UPDATE` meldet eine eigene aktive Listing-Info, oder ein bestaetigter Gruppenbeitritt trifft ein, nachdem der lokale LFG-Status bereits ein verifiziertes Dungeon-Ziel kennt.
2. Verarbeitung: Der Status wird kleingeschrieben normalisiert; die Activity-zu-Map-Aufloesung nutzt nur exakte Aktivitaetsdaten. Namen, Tokens oder andere heuristische Fallbacks bleiben unresolved.
3. Verarbeitung: Der Invite-Kontext bleibt bis zur exakten Bestaetigung per `inviteaccepted` pending; danach wird der erkannte Dungeon-Zielzustand gesetzt und das Portal-Highlight ohne Sound aktiviert. Wenn LFGDetect bereits einen konkreten lokalen Map-Kontext hat, wird dieser an den gemeinsamen Highlight-Resolver weitergereicht und hat Vorrang vor peer-synced Highlight-Quellen. Der direkte Target-Dungeon-Chat fuer einen Accepted-Invite nutzt denselben verifizierten Listing-Payload wie die Centerbox und wird vor einem moeglichen synchronen Highlight-/Status-Refresh gelockt, damit stale Resolver-Zustaende keine zweite alte Chatzeile ausgeben.
4. Regel: Eine eigene Queue-/Listing-Detektion triggert das Portal-Highlight ueber den injizierten Callback; Portal-Sound bleibt fuer Queue- und Invite-getriebene Updates unterdrueckt.
5. Anzeige: Die Centerbox fuer eine angenommene M+-Einladung zeigt den verifizierten Dungeon und, wenn der akzeptierte LFG-Kontext eine konkrete `activityID` oder `mapID` liefert, einen klickbaren Portal-Button ueber denselben strikten Activity-/Map-Resolver.
6. Fallback: Wenn beim Gruppenbeitritt kein direktes `inviteaccepted` beim Accepted-Invite-Pfad angekommen ist, darf dieselbe Centerbox nur bei aktiviertem `Group-join target notice` aus `ResolveLocalStatusTargetMapID` plus vorhandener Status-Dungeon-Info gerendert werden. Die Dungeon-Zeile darf die Keystufe aus Status-Dungeon-Info oder aus einem konkret im LFG-Gruppentitel enthaltenen `+N` anzeigen; ohne diese Quelle bleibt die Dungeon-Zeile level-los. Ein accepted `mapID` darf nicht mit einem veralteten `latestQueueDungeonName` aus einem anderen Queue-/Activity-Kontext kombiniert werden; der Name muss entweder aus passendem Queue-Kontext, Teleport-MapID-Aufloesung oder gar nicht kommen. Ohne diesen verifizierten lokalen Zielkontext, bei deaktiviertem Gruppenbeitritts-Zielhinweis oder bei einem Reload-Roster-Mirror-Restore einer bestehenden Gruppe bleibt der Fallback stumm; `Accepted-invite notice` und `Group-join target notice` sind getrennt schaltbar. Wenn die direkte Accepted-Invite-Centerbox bereits gerendert wurde, erzeugt der Gruppenbeitritt keine zweite Centerbox fuer denselben Join.
7. Regel: `GROUP_ROSTER_UPDATE` ohne Gruppe loescht den gesamten LFG-Zustand inklusive pending invites, aber nur beim echten Gruppenende (`GetNumGroupMembers() == 0`); `CHALLENGE_MODE_START` und die aktive Challenge-Map allein loeschen den Invite-Zustand nicht mehr, sondern erst der echte Dungeon-Eintritt ueber den finalen Map-Check.
8. Erfolgskriterium: Erkennungen erscheinen einmalig und lokalisiert, late `inviteaccepted`-Events bleiben korrekt aufloesbar, identische Listing-Updates erzeugen keinen inkonsistenten Highlight-State, und unbekannte Namen werden nie als Dungeon-Ziel geraten.

## UC-16 BR- und Bloodlust-Gruppen-Announce im Mythic+

Ziel: Jeder BR- und Bloodlust-Cast eines isiLive-Spielers wird im Mythic+ genau einmal als lokalisierte Chat-Zeile an alle isiLive-Peers verteilt, ohne die 12.0-`ADDON_ACTION_FORBIDDEN`-Regression von `SendChatMessage` zu treffen und ohne `"table index is secret"`-Spam durch Casts anderer Spieler zu produzieren.

1. Trigger: `UNIT_SPELLCAST_SUCCEEDED` feuert mit `unit == "player"` waehrend `C_ChallengeMode.GetActiveChallengeMapID()` einen aktiven Key meldet.
2. Regel: Casts anderer Spieler werden vor jeder Spell-ID-Inspektion verworfen, weil deren `spellID` in 12.0-Protected-Zonen als Secret-Value maskiert ist und ein direkter Table-Lookup `BR_SPELL_IDS[spellID]` die Fehlermeldung `"table index is secret"` ausloest.
3. Verarbeitung: Die eigene `spellID` wird gegen `BR_SPELL_IDS` (Rebirth, Raise Ally, Intercession, Soulstone Resurrection) und `LUST_CAST_IDS` (Bloodlust, Heroism, Time Warp, Primal Rage, Fury of the Aspects, Feral Hide Drums, Drums of Fury / Mountain / Maelstrom / Deathly Ferocity, Ancient Hysteria, Netherwinds) geprueft.
4. Regel: Ein 3-Sekunden-Dedup-Fenster pro `sourceGUID|spellID` schluckt duplizierte Cast-Events im selben Burst; `CHALLENGE_MODE_START` und `CHALLENGE_MODE_COMPLETED` rufen `Reset()` und loeschen die Dedup-Map vollstaendig.
5. Regel: Der Sender broadcastet nur, wenn der zugehoerige Toggle aktiv ist. `chatAnnounceBR == false` blockiert BR-Announces, `chatAnnounceLust == false` blockiert Lust-Announces; beide sind standardmaessig aktiv und leben in der `Chat Announcements`-Sektion der Blizzard-Settings.
6. Verarbeitung: Der Sender ruft `Sync.SendCombatAnnounce(kind, sourceName, spellID)` auf. Die Payload `BRLUST:<KIND>:<caster>:<spellID>` geht mit Prioritaet `NORMAL` ueber `DispatchAddonMessage` und damit ueber den ChatThrottleLib-Pfad; wenn die Lib nicht geladen ist, fallback auf raw `C_ChatInfo.SendAddonMessage`. `SendChatMessage` wird nicht verwendet, damit 12.0-Taint-Zonen keinen `ADDON_ACTION_FORBIDDEN`-Popup ausloesen.
7. Verarbeitung: Der Sender rendert parallel die eigene Chat-Zeile lokal via `ctx.ShowCombatAnnounce` in `DEFAULT_CHAT_FRAME`, damit er seinen eigenen Cast auch solo oder ohne isiLive-Peers in der Gruppe sieht.
8. Verarbeitung: `Sync.ProcessAddonMessage` erkennt `BRLUST:` als eigenen Bucket und exponiert `{kind, caster, spellID}` als `result.combatAnnounce`; `HandleChatMsgAddonEvent` ruft `ctx.showCombatAnnounce(...)`, das den lokalisierten Template-Text (`COMBAT_CHAT_BR_USED` / `COMBAT_CHAT_LUST_STARTED`) via `ctx.Print` in den Chat schreibt.
9. Regel: Unbekannte `BRLUST`-Kinds (also alles ausser `"BR"` und `"LUST"`) werden auf Empfaengerseite still verworfen, damit ein zukuenftiger Sender mit neuem Kind keinen Log-Spam produziert.
10. Regel: Nicht-isiLive-Gruppenmitglieder sehen nichts; die Verteilung laeuft ausschliesslich ueber den Addon-Message-Kanal zwischen isiLive-Peers. Bei `N` isiLive-Usern in einer Gruppe meldet jeder Caster seinen eigenen Cast, und alle `N-1` Peers bekommen die Zeile.
11. Realm-Darstellung: Die realm-strippende Display-Logik liegt in `factory/isiLive_factory_combat_announces.lua.FormatDisplayName` und wird sowohl vom Self-Render- als auch vom Peer-Render-Pfad genutzt; Cross-Realm-Namen behalten dabei ihren Realm-Suffix.
12. Erfolgskriterium: Ein BR- oder Lust-Cast im Mythic+ erzeugt genau eine sichtbare Chat-Zeile pro isiLive-Empfaenger, der Self-Render beim Sender, keinen `ADDON_ACTION_FORBIDDEN`-Popup und keinen `"table index is secret"`-Fehler; Toggles entfernen die Zeile vollstaendig auf Senderseite, Peers ausserhalb eines aktiven Keys sehen keine Zeile.

## UC-24 Gruppensuche- und Roster-Klassenbonus-Hinweise

Ziel: Der Spieler soll in der Blizzard-Gruppensuche und im Roster schnell erkennen, ob eine Gruppe, ein Bewerber oder ein Gruppenmitglied relevante Klassenboni fuer den aktuell eingeloggten Charakter mitbringt.

1. Trigger: Eine LFG-Suchergebniszeile, ein Suchergebnis-Tooltip, eine Bewerberzeile oder eine Roster-Zeile wird aktualisiert.
2. Verarbeitung: Das Addon liest nur die von Blizzard bereitgestellten Klassen-/Spezialisierungsdaten fuer die sichtbare Zeile beziehungsweise den sichtbaren Tooltip oder die verifizierten Roster-Klassen-/Spec-Daten. Nicht aufloesbare Klassen oder Spezialisierungen bleiben unresolved.
3. Verarbeitung: Die Relevanz wird gegen das live aufgeloeste Spielerprofil bewertet. Staerke-, Beweglichkeits- und Intelligenzboni, physischer und magischer Schadensbonus sowie Ausdauer-, Meisterschafts-, Versa- und Schadensreduktionsboni zaehlen nur, wenn sie fuer den lokalen Charakter relevant sind.
4. Regel: Battle Res, Bloodlust, Power Infusion, Devotion Aura, Atrophic Poison und aehnliche Utility-Hinweise duerfen in Tooltip-Details erscheinen, zaehlen aber nicht als kompakte gruene Suchergebnis-Marker.
5. Anzeige: Suchergebniszeilen zeigen bis zu vier gruene Herzmarker rechtsbuendig innerhalb der Blizzard-Zeile und unabhaengig davon, ob ein Drittanbieter-Addon zusaetzliche Klassenbadges zeichnet. Roster-Zeilen zeigen dieselben Marker direkt am Spielernamen, wenn die Roster-Klasse verifiziert ist und eine vorhandene Spec-ID zur Klasse passt. Der Roster-Mouseover zeigt fuer diese Marker die konkrete lokalisierte Bonuszeile, zum Beispiel `+2% Mastery`, und darf BR/BL dort zusaetzlich auffuehren; BR/BL erzeugen weiterhin keine Herzchen und erhoehen die Markerzahl nicht. Die Settings-Option `Group Finder: Buff rating hearts` ist standardmaessig aktiv, kann diese Marker und die zugehoerigen Bonus-Tooltip-Ergaenzungen ausschalten und beschreibt mit untereinander stehenden fix grossen Herz-Textur-Beispielzeilen, dass 1/2/3/4 Herzen einen, zwei, drei beziehungsweise vier oder mehr relevante Buffs bedeuten.
6. Anzeige: Gleiche nicht stapelnde Boni zaehlen pro Suchergebnis nur einmal, auch wenn mehrere Gruppenmitglieder denselben Buff liefern.
7. Texturvertrag: Kompakte Marker und Settings-Beispiele nutzen die Datei `Interface\AddOns\isiLive\media\heart_bonus_green.tga`; der WoW-API-Pfad darf extensionless `Interface\AddOns\isiLive\media\heart_bonus_green` sein. Instabile Font-Herz-Glyphen sind fuer dieses Feature nicht zulaessig. Bewerberzeilen platzieren echte Texturmarker rechts neben dem Klassenbadge, damit sie nicht unter Blizzard-Badges verschwinden, und duerfen keinen FontString-Markup-Fallback fuer diese Herzchen verwenden.
8. Verarbeitung: Bewerberzeilen duerfen Sprachflaggen nur anzeigen, wenn der Realm aus dem konkreten Bewerber-Mitgliedsnamen oder dem lokalen Realm belastbar aufgeloest werden kann; ohne Realm-/Sprachquelle bleibt die Flagge verborgen.
8. Anzeige: Bewerberzeilen zeigen die Marker neben dem Rollenbadge. Roster-Zeilen zeigen die Marker im Namensfeld vor Portal-, Sync- und Leader-Markern. Suchergebnis-Tooltips ergaenzen passende Mitgliedszeilen mit lokalisierten Bonusdetails; Roster-Mouseover ergaenzen die konkrete Bonuszeile fuer den gehoverten Spieler. Beim Programmieren werden Deutsch und Englisch gepflegt, weitere vorbereitete Locales duerfen bis zur Nachbearbeitung englische Fallback-Texte verwenden oder nachbearbeitete Uebersetzungen tragen.
9. Uebersetzungsregel: Community-PRs fuer vorbereitete Locales werden angenommen, wenn sie mit den aktuellen UI- und Regelvertraegen kompatibel gemacht werden koennen; der einreichende User wird im Changelog bedankt.
10. Ausnahme: Zeilen mit `Beförderung angeboten` beziehungsweise dessen lokalisierter Spielstil-Anzeige zeigen keine kompakten Suchergebnis-Marker.
11. Erfolgskriterium: Relevante nicht-Utility-Boni sind sichtbar und im Roster-Mouseover konkret benannt, irrelevante oder unbekannte Boni bleiben ausgeblendet, doppelte Buffquellen erhoehen die Markerzahl nicht, fehlende Drittanbieter-Badges entfernen die Marker nicht aus der Blizzard-Default-Anzeige, und Roster-Zeilen zeigen keine Marker ohne verifizierte Klasse.

## UC-17 Mob-Tooltip mit Forces-Anteil im Mythic+

Ziel: Hovern ueber einen Mob in einem aktiven M+-Run haengt eine Forces-Zeile an den Blizzard-Tooltip an, damit der Spieler vor dem Pull sieht, wie viel Forces dieser Mob beitraegt.

1. Trigger: Die Blizzard-`TooltipDataProcessor`-Post-Call-Chain feuert fuer `Enum.TooltipDataType.Unit`, waehrend `C_ChallengeMode.GetActiveChallengeMapID()` eine aktive Map-ID liefert.
2. Voraussetzung: `data/isiLive_mplus_forces.lua` ist geladen und stellt `MPlusForces.byNpcId` sowie `MPlusForces.dungeonTotal` bereit. Ohne validen Datensatz wird die Zeile nicht gerendert.
3. Verarbeitung: Der GUID wird entweder direkt aus den Tooltip-Daten oder als Fallback aus `UnitGUID("mouseover")` gezogen; `NpcIdFromGuid` parsed den Blizzard-GUID und akzeptiert nur `Creature` oder `Vehicle`. Spieler-GUIDs werden verworfen.
4. Regel: Der Eintrag wird nur gerendert, wenn die NPC-Map-ID des Datensatzes mit der aktiven Challenge-Map-ID uebereinstimmt; fremde Dungeon-NPCs (zum Beispiel in World-Quests) erhalten keine Zeile.
5. Verarbeitung: Die Zeile wird ueber die lokalisierte Format-Vorlage `L.TOOLTIP_MOB_PROGRESS_LINE` mit `count`, `(count / total) * 100` und `total` formatiert (enUS `+%d progress (%.2f%% of %d)`, deDE `+%d Fortschritt (%.2f%% von %d)`, alle 8 Sprachen synchron) und mit der Farbe `(0.4, 0.8, 1)` via `tooltip:AddLine(...)` angehaengt. Der Locale-Getter wird ueber `MobTooltip.SetLocaleGetter(ctx.GetL)` von der Factory verdrahtet.
6. Regel: Ein `OnTooltipCleared`-Hook auf `GameTooltip` loescht die per-Tooltip-Dedup-Map, damit `TooltipDataProcessor`-Rerenders desselben Mobs keine Doppelzeilen stapeln.
7. Regel: `MobTooltip.SetEnabled(false)` gated das Rendering komplett; bei deaktiviertem Feature wird keine Zeile gerendert, auch wenn alle anderen Voraussetzungen stimmen.
8. Regel: 12.0-Secret-Value-Guards greifen an drei Stellen, bevor ein Wert verglichen oder als Pattern-Match ausgewertet wird: `C_ChallengeMode.GetActiveChallengeMapID()` (secret gemachter Wert zaehlt als kein aktiver Key), `tooltipData.guid` und der Fallback `UnitGUID("mouseover")` (secret gemachte GUID wird verworfen, damit der SetWorldCursor-Tooltip-Pfad keinen `"attempt to compare field 'guid' (a secret string value tainted by 'isiLive')"`-Fehler produziert). Ein secret gemachter Wert an irgendeiner dieser Stellen unterdrueckt das Rendering.
9. Erfolgskriterium: Hovern ueber einen Dungeon-Mob im aktiven Key zeigt eine stabile Forces-Zeile, Hovern ausserhalb eines Keys oder auf fremden Mobs erzeugt keine Zeile, Tooltip-Rerenders duplizieren die Zeile nicht.

## UC-18 Nameplate-Forces-Overlay im Mythic+

Ziel: Eine optionale Live-Anzeige auf jeder feindlichen Namensplakette waehrend eines aktiven M+-Keys zeigt dem Spieler den Forces-Beitrag dieses Mobs ohne Mouseover.

1. Trigger: `NAME_PLATE_UNIT_ADDED` / `NAME_PLATE_UNIT_REMOVED` / `CHALLENGE_MODE_START` / `PLAYER_ENTERING_WORLD` / `SCENARIO_UPDATE` feuern, waehrend `C_ChallengeMode.IsChallengeModeActive()` `true` liefert und der User `mobNameplateEnabled` aktiviert hat.
2. Voraussetzung: `data/isiLive_mplus_forces.lua` ist geladen und liefert `MPlusForces.byNpcId` plus `MPlusForces.dungeonTotal[mapID].total`.
3. Aktivierungs-Gate (alle vier muessen halten): aktiver Key, User-Toggle gesetzt, `UnitReaction(unit,"player") <= 4` (hostile/neutral, friendly Units skipped), `UnitGUID` ist ein nicht-leerer String und kein Secret Value.
4. Verarbeitung: Der GUID wird in eine NpcID umgewandelt (Pattern-Match auf den Blizzard-GUID, akzeptiert nur `Creature` und `Vehicle`), und der `count`-Wert aus `MPlusForces.byNpcId[npcId]` wird durch `MPlusForces.dungeonTotal[mapID].total` geteilt -> `percent = count / total * 100`. Diese DB-basierte Berechnung ist die primaere Quelle und muss auch rendern, wenn `C_ScenarioInfo.GetUnitCriteriaProgressValues` nicht verfuegbar ist; die Blizzard-API wird nur als Fallback genutzt, wenn die DB den NPC nicht kennt (frischer Patch-Mob vor naechstem MDT-Refresh).
5. Regel: `BuildText` rendert `<percent>%` oder versteckt das Frame, wenn der Anteil nicht ermittelbar ist (Secret Value, leerer String, fehlender NPC im DB). Standardmaessig bleibt nur der Mob-Anteil sichtbar. Nur wenn `mobNameplateShowRemaining == true` ist und `KillTrack.GetData()` fuer dieselbe aktive `mapID` einen belastbaren `rawCount`/`total`- oder `percent`/`total`-Stand liefert, wird zusaetzlich `/<remaining>%` angehaengt; ohne passende KillTrack-Daten bleibt nur der Mob-Anteil sichtbar. Nach Combat-Ende muss der Restbedarf mit dem live aktualisierten KillTrack-Gesamtstand konvergieren.
6. Regel: 12.0-Secret-Value-Guards greifen vor jedem `==`/`~=`/`<=`/`<`/Pattern-Match-Operator: `mapID`, `numCriteria`, `quantity`, `totalQuantity`, `unitGUID`, `unitReaction`, `percentString`. Die Reihenfolge ist `type() -> IsSecretValue() -> Comparison`, niemals umgekehrt, da der Comparison-Operator den Stack tainted, bevor der Guard laeuft.
7. Regel: Frame-Pool pro `unit`-Token, sodass `CreateFrame` hoechstens einmal pro gleichzeitig aktivem Nameplate-Slot gerufen wird. `NAME_PLATE_UNIT_REMOVED` versteckt das Frame und entfernt den Pool-Eintrag.
8. Regel: Plater- oder Platynator-Soft-Detect zeigt eine dezente Warnung in den Settings; `mobNameplateEnabled` defaultet auf `true` fuer Frischinstallationen, damit die Forces-Prozentanzeige im Key ohne manuelles Aktivieren sichtbar ist.
9. Verarbeitung: `appearance.fontSize` wird via `ApplyFont(fontString)` als `SetFont(file, size, flags)` mit dem Template `GameFontNormalOutline` und Default-Fallback `Fonts\\FRIZQT__.TTF` / `OUTLINE` auf den FontString uebertragen, sowohl bei Frame-Erstellung als auch bei jedem Refresh, sodass Slider-Aenderungen ohne `/reload` durchschlagen.
10. Positionierung: Wenn Platynator auf dem beobachteten Blizzard-Nameplate-Objekt ein sichtbares Display mit `widgets` und einem Health-Widget `details.kind == "health"` bereitstellt, wird dieses sichtbare Health-Widget als Anchor-Ziel genutzt. Wenn kein solcher Platynator-Anker vorhanden ist und Plater oder ein kompatibler Renderer `unitFrame.healthBar` bereitstellt, wird dieser Healthbar-Frame genutzt. Danach wird ein direkt benannter Blizzard-Healthbar-Frame wie `UnitFrame.healthBar` genutzt; sonst bleibt das Nameplate-Frame selbst das Anchor-Ziel. Das Overlay-Frame bleibt auf `UIParent`, damit externe Nameplate-Skalierung die konfigurierte Schriftgroesse nicht veraendert. Bei Position `RIGHT` beginnt der Text direkt am rechten Rand des Anchor-Ziels und ist linksbuendig; bei `LEFT` endet der Text direkt am linken Rand und ist rechtsbuendig; `TOP` und `BOTTOM` bleiben zentriert. Dadurch darf die Zahl nicht durch Zentrierung in einem breiten Overlay-Frame sichtbar vom HP-Balken wegrutschen.
11. Erfolgskriterium: Im aktiven Key zeigt jede feindliche Namensplakette eine deterministische, lokalisierungsneutrale Forces-Zahl, die der Mouseover-Tooltip-Zeile entspricht; bei aktivierter Restbedarfs-Option folgt der noch benoetigte Dungeon-Fortschritt im Format `<mob>%/<rest>%`. Ausserhalb eines Keys oder bei nicht-feindlichen Units bleibt das Overlay versteckt.

## UC-20 Clear-Log-Buttons im Settings-Administrativ

Ziel: Den User die beiden On-Reload-Debug-Logs (Queue-Debug, Runtime-Log) per Klick aus dem Settings-Panel leeren lassen, ohne die Slash-Command-Variante kennen zu muessen.

1. Trigger: Klick auf den `Clear Queue Debug Log`- oder `Clear Runtime Log`-Action-Button in der Administrative-Sektion des Blizzard-Settings-Canvas.
2. Verarbeitung: Der Klick ruft `config.onClearQueueDebugLog()` bzw. `config.onClearRuntimeLog()`. Die Factory verdrahtet diese auf `ctx.clearQueueDebugLog` und `ctx.clearRuntimeLog`, dieselben Dispatcher die auch `/isilive qdebug clear` und `/isilive log clear` nutzen.
3. Regel: Beide Buttons zeigen einen lokalisierten Label-Text aus `L.SETTINGS_QUEUE_DEBUG_CLEAR` / `L.SETTINGS_RUNTIME_LOG_CLEAR`; alle 8 Sprachen synchron.
4. Regel: Der Refresh-on-Language-Change-Pfad in `RefreshSettingsControls` zieht die Button-Labels nach Sprachwechsel automatisch nach.
5. Erfolgskriterium: Klick auf einen der beiden Buttons leert sofort den jeweiligen Log-Buffer (verifizierbar via `/isilive log status` oder `/isilive qdebug status`); die Slash-Command-Variante bleibt parallel verfuegbar.

## UC-21 Multi-Kick-Extras im Roster-Tooltip

Ziel: Klassen mit mehreren Interrupt-Spells (Prot Paladin via Avenger's-Shield-Talent, theoretisch auch Demo Warlock Inner Demons) sollen alle ihre aktiven Kick-Cooldowns sichtbar machen, nicht nur den primary. Die Mehrwert-Information bleibt im Hover-Tooltip, damit die `Kick`-Spalte selbst weiterhin kompakt bleibt.

1. Trigger: Der lokale Spieler castet einen Spell, der in der klassen-spezifischen `CLASS_INTERRUPT_LIST` aufgefuehrt ist, aber nicht der aktuell registrierte primary-Slot fuer seine Spec ist. `KickTracker.OnCast(unit, spellID)` erkennt das via zweistufigem Match: erst `GetSpellDataByID(specData, spellID)` (primary), dann `FindExtraKickSpell(spellID)` (extras-Whitelist).
2. Voraussetzung: Die Klasse muss in `CLASS_INTERRUPT_LIST` gelistet sein. Aktuell unterstuetzt: `PALADIN = {96231, 31935}` (Rebuke + Avenger's Shield) und `WARLOCK = {19647, 119914}` (Spell Lock + Axe Toss). Andere Klassen erhalten Spec-Switches via `RefreshSpec` auf `PLAYER_SPECIALIZATION_CHANGED` und brauchen keine dynamische Multi-Kick-Erkennung.
3. Verarbeitung: Bei einem extras-Match wird `extras[spellID] = {cd, cdEnd}` gesetzt, ohne den primary-Cooldown anzuruehren. Die CD kommt aus `EXTRA_KICK_CD` (z.B. `[31935] = 30` fuer Avenger's Shield) oder via Cross-Spec-Lookup in `SPEC_DATA` als Fallback. `Scan()` raeumt expirierte Eintraege automatisch beim 0.5-Sekunden-Ticker auf.
4. Verarbeitung: `GetKickInfo()` liefert jetzt zusaetzlich `extras = {[spellID] = {onCooldown, cooldownRemain, cd}}`. Der Factory-KickTracker reicht das direkt durch zu `Sync.SendKick({extras=...})` und parallel zu `Sync.SetPlayerKickInfo(self, ..., extras)`, sodass die lokale UI die eigenen extras ohne Round-Trip ueber den Addon-Channel sieht.
5. Sync: Der `KICK:`-Payload wird auf `KICK:<state>:<remain>:E:<spellID,remain>;<spellID,remain>` erweitert, wenn extras vorhanden sind; wenn zusaetzlich ein primary `spellID` synchronisiert wird, bleibt `:E:` vor `:S:<spellID>`, damit aeltere isiLive-Peers `parts[4]/parts[5]` weiterhin als Extras lesen koennen. Das `:E:`-Suffix ist optional und backwards-compatible: aeltere isiLive-Peers ignorieren unbekannte spaetere Felder und sehen den primary normal. Empty-Extras-Map fuegt das Suffix nicht an, damit der Common-Single-Kick-Case keine Bytes verschwendet. Sortierung der Pieces via `table.sort` macht das Payload deterministisch fuer die `IsBlockedBySendGate`-Dedup.
6. Receive: `Sync.ProcessAddonMessage` erkennt `parts[4] == "E"` und parsed `parts[5]` via `gmatch("[^;]+")` fuer einzelne `<spellID>,<remain>`-Paare. Sanitize-Logic in `Sync.SetPlayerKickInfo` filtert non-numerische oder negative Werte raus.
7. Peer-Propagation: `KeySync.ApplyKnownKeyToRosterEntry` interpoliert die extras analog zum primary-Remain (subtract elapsed time von `receivedAtGetTime`), filtert expirierte Eintraege raus und persistiert die Map als `info.syncKickExtras` auf dem Roster-Entry. Drift-Detection (Schwellenwert 0.6s) triggert nur dann ein UI-Refresh, wenn sich tatsaechlich was aendert.
8. Render: `ShowRosterInfoTooltip` (Roster-Hover) zeigt direkt nach der Rio-Zeile einen lokalisierten "Extra kicks:"-Header (Locale-Key `TOOLTIP_KICK_EXTRAS_HEADER` in 8 Sprachen) gefolgt von einer eingerueckten Zeile pro extra: `  <SpellName>: <remain>s`. SpellName kommt aus `C_Spell.GetSpellName(spellID)` (pcall-guarded), Fallback auf `Spell <ID>`.
9. Bekannter Constraint: Demonology Warlock Inner Demons (Felguard + Felhunter parallel, beide casten ihren eigenen Interrupt-Spell) wird aktuell **nicht** als Multi-Kick gehandhabt, weil `Spell Lock 19647` in `SPEC_DATA[266].spells` als alternativer Primary fuer den Pet-Switch-Fall (Felhunter ohne Felguard) gelistet ist. Den Array auf einen Spell zu reduzieren wuerde den Pet-Switch-Pfad brechen. Dokumentiert als Future-Work.
10. Erfolgskriterium: Im aktiven Mythic+-Run zeigt der Roster-Hover-Tooltip eines Prot Paladin mit Avenger's-Shield-Talent zwei separate Cooldowns (Rebuke in der `Kick`-Spalte und Avenger's Shield im Tooltip-Extras-Block) ohne dass der primary-Cooldown durch den Avenger's-Shield-Cast gestoert wird; Peers ohne Talent-Kick sehen weder Header noch Extras-Zeilen.

## UC-22 LFG-Invite-Liste entfernt

Ziel: Die verworfene offene Premade-LFG-Invite-Liste ist vollstaendig aus dem Addon entfernt.

1. Settings: Es gibt kein sichtbares Settings-Control fuer eine LFG-Invite-Liste.
2. Persistenz: `inviteListEnabled` ist kein bekanntes SavedVariable-Schemafeld und wird bei frischer DB nicht als Default erzeugt.
3. Module: Es gibt kein `logic/isiLive_invites.lua`, kein `ui/isiLive_invite_list.lua` und keinen TOC-Eintrag fuer diese Dateien.
4. Runtime-Wiring: Die Factory erzeugt keinen Invite-Listen-Controller und kein Invite-Listen-UI-Wiring.
5. Event-Verhalten: `LFG_LIST_APPLICATION_STATUS_UPDATED` wird nicht an einen Invite-Listenpfad weitergeleitet; die bestehende sichtbare LFGDetect-/Queue-Verarbeitung fuer positive Status-Events bleibt aktiv.
6. Hidden-Verhalten: Hidden bleibt `LFG_LIST_APPLICATION_STATUS_UPDATED` fuer Queue- und Invite-Listenverarbeitung blockiert.
7. Erfolgskriterium: User sehen keine experimentelle Extra-Liste, koennen sie nicht aktivieren, und fehlende oder mehrdeutige LFG-Invite-Daten erzeugen keinen neuen UI-Pfad.

## UC-23 Spieler-Stats-Box

Ziel: Eine optionale, eigenstaendige Spieler-Stats-Box zeigt live gelesene Primär- und Sekundaerwerte, ohne vom aktuellen Main-UI-Layout abzuhaengen.

1. Trigger: Das Addon ist geladen und der User aktiviert die Stats-Box in den Settings (`statsBoxEnabled=true`).
2. Voraussetzung: Die Stats-Box startet fuer neue oder sanitizte DBs deaktiviert; ohne explizites Enable bleibt sie unsichtbar.
3. Verarbeitung: Die Box liest Attribute ueber `UnitStat`, Combat-Ratings ueber die verfuegbaren Rating-APIs und Prozentwerte ueber direkt verfuegbare Blizzard-Live-APIs. Fehlende Werte erzeugen keine Zeile.
4. Regel: Secret Values duerfen fuer die Anzeige nur direkt via `string.format` in Text gewandelt werden; Lua-Arithmetik, `tonumber` oder Vergleiche auf diesen Werten sind verboten.
5. Regel: Klassen mit eindeutigem Primärstat nutzen den live gelesenen Klassentoken; Hybridklassen zeigen den Primärstat nur, wenn die Spezialisierungs-ID exakt live gelesen wurde. Ohne belastbare Quelle bleibt die Primärstat-Zeile unsichtbar.
6. Darstellung: Sichtbare Labels sind feste englische Kurzlabels (`Str`, `Agi`, `Int`, `Crit`, `Haste`, `Mast`, `Vers`, `Leech`, `Speed`, `Dur`, `Avoid`). Labels, Werte und Prozentwerte sind rechtsbuendig, die Werte-Spalte behaelt fuer drei- und vierstellige Zahlen eine stabile kompakte Mindestbreite, die Prozent-Spalte bleibt breit genug fuer `(999.99%)`, und alle sichtbaren Texte nutzen feste Blizzard-like Farben sowie einen dunklen Textschatten ohne Outline.
7. Settings: Der User kann die Box ein-/ausschalten, sperren, die Hintergrund-Deckkraft separat setzen, die Schriftgroesse inklusive Box-Geometrie ueber einen relativen Offset von `-3` bis `+3` anpassen, den Zahlenmodus auf Werte+Prozente, nur Werte oder nur Prozente setzen und Leech, Speed, Haltbarkeit, Ausdauer sowie Vermeidung einzeln ausblenden.
8. Position: Die Box speichert ihre Position in `statsBoxPosition` und aendert die Main-UI-Position nicht.
9. Screen-Clamp: Beim Ziehen bleibt die Stats-Box wie Main-UI, Center-Notice und Portal-Navigator am WoW-Sichtbereich geklemmt; der Fensterrand kann nicht ausserhalb des WoW-Fensters verschwinden.
10. Erfolgskriterium: Die Box zeigt nur verifizierte Live-Werte, bleibt layout-unabhaengig bedienbar und kann nicht ausserhalb des WoW-Fensters gezogen werden.

## UC-24 Tank-/Heiler-Todesalarm im Mythic+

Ziel: Der Spieler wird im laufenden M+-Run sofort und unuebersehbar informiert, wenn Tank oder Heiler stirbt.

1. Trigger: `UNIT_HEALTH` fuer `player` oder `party1`-`party4` waehrend eines aktiven M+-Runs.
2. Voraussetzung: `deathAlertEnabled` ist aktiv (Default an); ausserhalb eines aktiven Keys, im Raidmodus oder bei deaktivierter Option bleibt der Pfad stumm.
3. Verarbeitung: Die Erkennung ist pro GUID edge-getriggert: nur der Uebergang lebendig zu tot loest genau einen Alarm aus; wiederholte Health-Ticks toter Spieler und der Uebergang tot zu Geist bleiben stumm. Eine Wiederbelebung schaltet die Flanke neu scharf; `CHALLENGE_MODE_START/COMPLETED/RESET` setzen Flags, Audio-Burst-Pause und sichtbare Death-Counter zurueck, und `GROUP_ROSTER_UPDATE` verwirft Flags verlassener Spieler.
4. Regel: Die Rolle kommt aus der verifizierten Rollenaufloesung (`Units.GetUnitRole`); nur `TANK` und `HEALER` erzeugen Bildschirmwarnung und WAV-Audio. Schadensausteiler-Tode werden fuer Death-Counter und Tooltips gezaehlt, bleiben aber ohne Bildschirmtext und ohne WAV. Disconnects und unlesbare (Secret-Value-)Zustaende gelten fail-closed als nicht tot.
5. Darstellung: Eine grosse rote rahmenlose Bildschirmwarnung (`Tank died` / `Healer died`) mit Scale-Punch-Animation (uebergross einfliegend, Fade-out nach rund 1,7 Sekunden). Die Audioform ist statisch: Tank-Tode spielen `TankDied.wav`, Heiler-Tode spielen `HealerDied.wav`, jeweils ueber den konfigurierten isiLive-Soundkanal. Der gezaehlte Gesamtwert erscheint im M+-Timer-Totenkopf und im aktiven M+-Killtracker direkt hinter dem Dungeon-/Keynamen als Totenkopfmarker mit roter Zahl.
6. Native Text-to-Speech-Ausgabe bleibt deaktiviert: Es gibt keinen `C_VoiceChat.SpeakText`-Pfad, keinen TTS-Schalter und keine dynamischen Namen-/Klassenansagen. Der `deathAlertEnabled`-Gate und die Raid-Unterdrueckung bleiben vorgelagert wirksam.
7. Eigener Tod: Stirbt der Spieler selbst als Tank oder Heiler, werden Text und Audio ebenfalls ausgegeben.
8. Settings: `deathAlertEnabled` schaltet die DeathWatch-Erkennung und den Bildschirmtext. Tank- und Heiler-WAV-Ausgaben sind getrennt ueber `soundTankDiedEnabled` und `soundHealerDiedEnabled` schaltbar und laufen weiterhin ueber den global gewaehlt gespeicherten Soundkanal.
9. Diagnose: Wenn ein Tank-/Heiler-WAV-Start fehlschlaegt, wird Rolle, Fehlergrund, Kanal und Asset-Pfad diagnostizierbar ausgegeben; es gibt keinen TTS-Fallback.
10. Erfolgskriterium: Genau ein Alarm pro Tod; keine Alarme ausserhalb aktiver Keys, fuer DPS-Tode oder fuer Disconnects.

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
14. Roster-Rollen nutzen die vorhandene Gruppenrollenzuweisung nur bis eine verifizierte Inspect-Spezialisierung vorliegt; danach korrigiert `GetSpecializationRoleByID` fuer genau diese Spezialisierung die sichtbare und sortierende Rolle, ohne Namen, Labels oder unvollstaendige Daten zu raten.
15. Raid-Gruppenerkennung bei mehr als 5 Mitgliedern blendet die Addon-UI aus, unterdrueckt Background-Processing einschliesslich hidden Kick-Keep-Alive und delayed Post-Run-Refresh-Ausfuehrung, gibt keine Raid-Transition-Notice aus und blockiert das Zurueckschalten auf M/V, bis die Gruppengroesse wieder Party ist.
16. Die optionalen `Esc`-Tooling-, Travel-, Mounts- und Addons-Strips bleiben lokalisiert, schliessen das Game-Menu vor dem Oeffnen ihrer Ziele und halten `ReloadUI` auf einem Secure-Macro-Pfad (`/click GameMenuButtonContinue` + `/reload`), der `ActionButtonUseKeyDown` spiegelt; blockierte Secure-Refreshes fuer diesen Button und sichere Mount-Macro-Buttons werden auf `PLAYER_REGEN_ENABLED` wiederholt, waehrend die Strips als vorab gemountete `GameMenuFrame`-Kinder keinen deferred Host-Frame-Re-Show-Pfad im Combat ausfuehren. Externe Addon-Shortcuts bleiben an verifizierte Addon-Installation, Aktivierung, optionales Load-on-Demand-Laden, beobachtet geschlossenes `GameMenuFrame` und registrierte Slash-Aliase gebunden, tolerieren eine kurze verzoegerte Registrierung desselben exakten Slash-Alias, fuehren den verifizierten Handler direkt mit `msg, editBox` aus und nutzen keinen Chat-Edit-Fallback; der isiLive-Shortcut oeffnet direkt die Settings.
17. Hidden Legacy-Settings-Controls bleiben aus den Blizzard Settings entfernt und nutzen aktuell feste Runtime-Defaults: `DPS`-Spalte an, Marker fuer alle sichtbar, feste Namenstrunkierung und Legacy-`Travel`-Grid mit 2 Spalten.
18. Ready-Check-Lifecycle-Updates muessen den dedizierten Ready-Check-Refresh-Pfad nutzen, damit Row-Background-State, Waiting-Sandglass-Marker sowie der 20-Sekunden-Hold fuer `ready` und fuer explizit/unbeantwortet `notready` deterministisch zurueckgesetzt werden, ohne Secure-Role-Button-Attribute neu zu schreiben. Der Readycheck-Button bleibt ein Secure-Macro-Button fuer `/readycheck`; Lua-Click-Logging darf diesen Secure-OnClick nicht ersetzen. Wenn exakt fuenf gueltige Ready-Check-Teilnehmer in einem aktiven Ready-Check als bereit markiert sind, spielt der abschaltbare Ready-Check-Komplett-Klang genau einmal.
19. Locale-Tag-zu-Sprachflaggen-Aufloesung muss tooltip-hotpath-sicher aus einer statischen Lookup-Tabelle erfolgen. Ein Tooltip-Hover darf nicht `Languages.SUPPORTED` iterieren oder die Alias-Map lazy neu aufbauen.
20. Roster-Leader-Marker muessen den echten `UnitIsGroupLeader`-State spiegeln; Leader-Zeilen bekommen eine 16x16-Krone, und wenn dieselbe Zeile auch den blauen `isiLive`-Heart-Marker hat, bleibt die Reihenfolge `heart -> crown`.

Das Runtime-Verhalten in diesem Dokument wird von `tools/validate_usecases.lua` validiert.
Aktive Regelvertraege aus `RULES_LOGIC.md` werden von `tools/validate_rules_logic.lua` validiert und ebenfalls waehrend `tools/validate_usecases.lua` erzwungen.
Aktuelle Validator-Baseline: `2021` Szenarien ueber die in `tools/usecase_scenarios.lua` registrierten Module.

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
11. UC-13 und UC-14: Game-Menu-Tooling-/Travel-/Mounts-/Addons-Strips, Ruhestein-Auswahl, VIP-Gast-Sound-Schalter, Lokalisierung inklusive ruRU-Font-Override, Close-then-Open-Verhalten, verschobener Secure-Reload-Button-Refresh, sichere Mount-Macro-Shortcuts, Direct-Opener-Fallback-Auswahl, Settings-Canvas-State-Mirroring, Background-Opacity-Verhalten, Live-BRes-/Bloodlust-/M+-Timer-Rendering, kompakter aktiver Lust-Timer, M+-Killtracker-Live-Refresh mit aktiver Keylevel-Anzeige und gesyncte Interrupt-Cooldown-Anzeige.
12. UC-15: LFG-Detektion ohne Name-Fallbacks, locale-aware Chat-Hinweise, pending-invite Race-Hardening, konkrete lokale LFG-Map-Prioritaet, Highlight-Dispatch und Centerbox-Portalbutton aus verifiziertem Activity-/Map-Kontext.
13. UC-24: Gruppensuche- und Roster-Buff-Rating-Herzchen ohne Guessing, mit Spielerprofil-Relevanz, Utility-Ausschluss fuer kompakte Marker, BR/BL nur in Roster-Mouseover-Bonuszeilen, nicht-stapelnder Buffzaehlung, Blizzard-Default-kompatibler Suchergebnisposition, Bewerber-Herzchen rechts neben dem Klassenbadge als echte Texturen, Roster-Herzchen direkt am Spielernamen aus verifizierter Klasse und passender Spec-ID, Bewerber-Sprachflaggen aus verifiziertem Realm, default-aktivem Settings-Schalter, `media/heart_bonus_green.tga`-Texturvertrag sowie vorbereiteten Locale-Fallbacks inklusive akzeptierter Community-Uebersetzungen.
14. UC-16: BR-/Lust-Self-Cast-Filter gegen 12.0-Secret-Value-Spam, 3s-`sourceGUID|spellID`-Dedup, Toggle-Gating, ChatThrottleLib-Routing via `BRLUST`-Addon-Message, Receiver-Dispatch in lokalisierten Template-Zeilen und Drop-On-Unknown-Kind.
15. UC-17: Mob-Tooltip-Forces-Rendering nur bei aktiver Challenge-Map-ID mit passendem NPC-Dataset, Per-Tooltip-Dedup gegen `TooltipDataProcessor`-Rerender und `SetEnabled(false)`-Gate.

## Rueckverfolgbarkeit zu Quelldateien

| Thema | Dateien |
|---|---|
| Queue-Erkennung und Target-Capture | `isiLive_queue.lua`, `isiLive_event_handlers_queue.lua` |
| LFG-Detektion, Chat-Hinweise und Highlight-Dispatch | `isiLive_lfg_detect.lua`, `isiLive_factory_lfg_wiring.lua`, `isiLive_factory_notices.lua`, `isiLive_texts.lua`, `isiLive_teleport_ui.lua` |
| Highlight-Aufloesung und Inside-Dungeon-Suppression | `isiLive_highlight.lua` |
| Teleport-Spell-Mapping und Cooldown-Verhalten | `isiLive_teleport.lua`, `isiLive_spell_utils.lua`, `isiLive_teleport_ui.lua` |
| Gruppen-Lifecycle, Leader-State-Mirroring und Roster-Rebuild | `isiLive_group.lua`, `isiLive_roster.lua` |
| RIO-Baseline-Capture und Delta-Preview | `isiLive_event_handlers_challenge.lua`, `isiLive_roster.lua`, `isiLive_test_mode.lua`, `isiLive_runtime_state.lua` |
| Last-Run-DPS-Capture und begrenzte Stats-Persistenz | `isiLive_stats.lua`, `isiLive_event_handlers_challenge.lua`, `isiLive_event_handlers_runtime.lua`, `isiLive_roster_panel.lua`, `isiLive_roster_tooltip.lua` |
| Combat-Utility-Tracker-Zeile, M+-Killtracker, Kick-State und LibKeystone-Key-Interop | `isiLive_cd_tracker.lua`, `isiLive_mplus_timer.lua`, `isiLive_killtrack.lua`, `isiLive_kick_tracker.lua`, `isiLive_sync.lua`, `isiLive_keysync.lua`, `isiLive_factory_cd_tracker.lua`, `isiLive_factory_status_helpers.lua`, `isiLive_factory_kick_tracker.lua`, `isiLive_roster_panel.lua`, `isiLive_roster_panel_kill_row.lua`, `isiLive_roster_tooltip.lua`, `isiLive_texts.lua` |
| Leader-Transfer-Erkennung und Feedback | `isiLive_leader_watch.lua` |
| UI-Aktionen, Rollen-Buttons, Key-Share-Button | `isiLive_roster_panel.lua` |
| Esc-Tooling-/Travel-/Mounts-/Addons-Strips und Blizzard-Settings-Canvas | `isiLive_ui.lua`, `isiLive_settings.lua`, `isiLive_factory.lua`, `isiLive_texts.lua`, `isiLive_ui_common.lua` |
| Auto-Marker-Logik, entfernt oder ersetzt | `isiLive_group.lua` nach Bereinigung |
| Raid-Size-H-Mode-UI | `isiLive_roster_panel.lua`, `isiLive_group.lua` |
| Event-Routing und Gate | `isiLive_events.lua`, `isiLive_event_handlers.lua`, `isiLive_event_handlers_runtime.lua`, `isiLive_event_handlers_queue.lua`, `isiLive_event_handlers_challenge.lua` |
| BR-/Lust-Combat-Announce und Addon-Message-Routing | `isiLive_combat_events.lua`, `isiLive_sync.lua` (`SendCombatAnnounce`, `ProcessAddonMessage.BRLUST`), `isiLive_event_handlers_runtime.lua` (`HandleChatMsgAddonEvent`), `isiLive_factory_combat_announces.lua` (`FormatDisplayName`, `broadcastCombatAnnounce`), `isiLive_texts.lua` (`COMBAT_CHAT_BR_USED`, `COMBAT_CHAT_LUST_STARTED`, `SETTINGS_SECTION_CHAT`, `SETTINGS_CHAT_BR_ANNOUNCE`, `SETTINGS_CHAT_LUST_ANNOUNCE`), `libs/ChatThrottleLib/ChatThrottleLib.lua` |
| Mob-Tooltip-Forces-Anreicherung | `isiLive_mob_tooltip.lua`, `data/isiLive_mplus_forces.lua`, `tools/sync_mdt_forces.lua`, `tools/check_mplus_db_lifetime.lua`, `.github/workflows/sync-mplus-forces.yml` |
| Gruppensuche-Buff-Rating und Sprachflaggen | `isiLive_lfg_flags.lua`, `isiLive_locale.lua`, `isiLive_texts.lua`, `isiLive_settings_sections.lua`, `isiLive_db_schema.lua` |
