# isiLive Architektur

Versionsbasis: `0.9.135`
Zuletzt aktualisiert: `2026-04-09`

## Zweck

`isiLive` ist ein WoW-Mythic+-Gruppenhelfer.
Interner Runtime-Namespace und Moduldateien bleiben `isiLive_*`.
Die Architektur ist eventgetrieben und in klare Runtime-Schichten aufgeteilt:

1. WoW-Event-Eingang und Gate.
2. Fachlogik fuer Queue, Gruppe, Sync, Highlight und Inspect.
3. UI-Rendering und Benutzeraktionen.

## Schichtueberblick

| Schicht | Verantwortung | Primaere Dateien |
|---|---|---|
| Einstieg und Orchestrierung | Composition Root, Runtime-State, Wiring, Controller-Lifecycle, Keybindings, Modulguards | `isiLive.lua`, `isiLive_runtime_state.lua`, `isiLive_bootstrap.lua`, `isiLive_runtime_setup.lua`, `isiLive_controller_wiring.lua`, `isiLive_controller_init.lua`, `isiLive_factory.lua`, `isiLive_factory_frame_bridge.lua`, `isiLive_factory_controllers.lua`, `isiLive_frame_bridge.lua`, `isiLive_context_helpers.lua`, `isiLive_guards.lua`, `isiLive_bindings.lua` |
| Event-Gate und Dispatch | Stop/Pause/Hidden/Test erzwingen, Lifecycle-Handler routen, Slash-Commands dispatchen | `isiLive_events.lua`, `isiLive_event_handlers.lua`, `isiLive_event_handlers_runtime.lua`, `isiLive_event_handlers_queue.lua`, `isiLive_event_handlers_challenge.lua`, `isiLive_event_utils.lua`, `isiLive_commands.lua` |
| Fachlogik | Queue-Parsing und Join-Flow, Gruppenmodell, Highlight-Aufloesung, Key-Sync, Refresh, Inspect, Leader-Transitions, begrenzte Run-Stats, Cooldown-/Interrupt-Tracking, per-Spec-Kick-Daten, Mythic+-Timer-State | `isiLive_queue.lua`, `isiLive_queue_flow.lua`, `isiLive_group.lua`, `isiLive_highlight.lua`, `isiLive_keysync.lua`, `isiLive_refresh.lua`, `isiLive_inspect.lua`, `isiLive_sync.lua`, `isiLive_stats.lua`, `isiLive_cd_tracker.lua`, `isiLive_kick_tracker.lua`, `isiLive_mplus_timer.lua`, `isiLive_leader_watch.lua` |
| UI-Komposition | Main-Frame, Roster-Zeilenmarkup, Roster-Panel, optionale Game-Menu-Tooling-/Travel-Panels, Blizzard-Settings-Canvas, Combat-Utility-Zeile, Teleport-Grid und Debug-Navigator, Notices, Statuszeile | `isiLive_ui.lua`, `isiLive_settings.lua`, `isiLive_roster.lua`, `isiLive_roster_panel.lua`, `isiLive_roster_tooltip.lua`, `isiLive_roster_layout.lua`, `isiLive_teleport_ui.lua`, `isiLive_teleport_debug.lua`, `isiLive_notice.lua`, `isiLive_status.lua` |
| Gemeinsame Helfer und Daten | Locale, lokalisierte Texte, Units, Realm-Sprachdaten, Season-Map-/Spell-Daten, sichere Spell-Cooldown-Wrapper, Runtime-Logging, fokussierte Config-Builder, private Tooltip-/UI-Helfer, zentrale Backdrop-Presets, gemeinsame Validierungs-/String-Helfer, Debug-Helfer, Demo-/Test-Helfer | `isiLive_validation_helpers.lua`, `isiLive_string_utils.lua`, `isiLive_spell_utils.lua`, `isiLive_locale.lua`, `isiLive_texts.lua`, `realm_language_data.lua`, `isiLive_units.lua`, `isiLive_season_data.lua`, `isiLive_teleport.lua`, `isiLive_ui_common.lua`, `isiLive_runtime_log.lua`, `isiLive_log_buffer.lua`, `isiLive_config_builders.lua`, `isiLive_queue_debug.lua`, `isiLive_demo.lua`, `isiLive_test_mode.lua` |

## Runtime-Flow

```text
WoW Event
  -> Event Gate (stopped/paused/hidden/test checks)
  -> Event Handler Aggregator
  -> Lifecycle Handler (runtime/queue/challenge)
  -> Domain Controllers (queue/group/highlight/sync/inspect/refresh/stats/cd-tracker/kick-tracker)
  -> Runtime State Update
  -> UI Controllers Render
```

## Zentrale Runtime-Zustaende

| Zustand | Verhalten |
|---|---|
| Running | Volle Verarbeitung aktiv |
| Paused | Verarbeitung blockiert ausser fuer erforderliche Uebergaenge |
| Stopped | Addon-Verarbeitung deaktiviert ausser fuer minimale Kontrollpfade |
| Hidden | Fenster ist verborgen, Queue-Scanning ist ausgesetzt; Background-Addon-Sync und Roster-Updates laufen weiter und duerfen UI-State eventgetrieben vor-rendern, ohne zu pollen; das dedizierte Kick-Keep-Alive bleibt fuer Party-Peers aktiv, und hidden `LFG_LIST_*`-Luecken werden spaeter nicht als Queue-Chat nachgereicht. Raid-Gruppen sind ein eigener Hard-off-Zustand, der die UI ausblendet und selbst diesen Background-Sync aussetzt, statt dem Hidden-Keep-Alive-Verhalten zu folgen. |
| Test/TestAll | Einheitlicher Dummy-Vollpreview-Modus fuer UI und Tests, inklusive positivem RIO-Delta-Preview und Ghost-/Leaver-Zeile |

## Deterministischer Regelsatz

1. Dungeon-Ziele werden nur ueber konkrete `activityID -> mapID -> spellID`-Daten aufgeloest.
2. Wenn `mapID`-Kontext fehlt oder mehrdeutig ist, bleibt das Ziel unresolved; es gibt kein Name-/Token-Guessing.
3. Leader-only-Aktionen bleiben explizit und fuer Unbefugte deaktiviert.
4. Combat-sichere UI-Updates werden verschoben, wenn geschuetzte Operationen blockiert sind; Teleport-Action-Buttons duerfen Parent-Frames nicht auf protected promoten, blockierte Main-Frame-Visibility-/Height-Aenderungen sowie blockierte `Esc`-Shortcut-Secure-Button-Refreshes muessen auf `PLAYER_REGEN_ENABLED` wiederholt werden, und die gemounteten `Esc`-Strips bleiben waehrend Combat read-only statt Host-Frame-Re-Shows zu planen.
5. Strata und Level der Teleport-Grid-Buttons bleiben mit Strata und Level des Main-Frames synchron.
6. Bei Shared-Portcast-Spells hat exaktes Activity-Map-Matching Vorrang vor spell-only-Suppression.
7. Highlight-State wird nicht aus mehrdeutigen Shared-Spell-Mappings geloescht, solange exakter Map-Kontext fehlt.
8. Queue-basiertes Target wird bei negativen Application-Follow-up-Events nicht geloescht, wenn bereits eine Gruppe besteht.
9. Blizzard-CVar-State fuer `advancedCombatLogging` und `damageMeterResetOnNewInstance` wird im Blizzard-Settings-Canvas nur gespiegelt und nur auf explizite User-Toggles geschrieben; der Blizzard-Damage-Meter-Reset auf Challenge-Start bleibt aktiv, wenn API-Support vorhanden ist.
10. Pro Spieler wird auf Challenge-Start ein RIO-Baseline-Snapshot erfasst; Delta-Rendering wird erst nach erfolgreichem delayed Post-Run-Refresh aktiviert und bleibt immer nicht-negativ mit Praefix `(+X)`.
11. Completed-Run-Stats muessen verzoegerte Blizzard-Damage-Meter-Verfuegbarkeit ueber kurze deterministische Retries tolerieren, sowohl fuer `M+` als auch fuer verfolgte Non-Challenge-Party-Exits (`Normal`, `Heroic`, `Mythic`); gespeist wird nur die `DPS`-Roster-Spalte.
12. Post-Run-Refresh- und Delta-Pipeline bleibt aktiv, wenn Challenge-Completion-/Reset-Events eintreffen, waehrend das Main-Window hidden ist; der delayed Post-Run-Refresh wird jedoch waehrend Raid-Hard-off verschoben und erst nach erkanntem Raid-Ende fortgesetzt.
13. Der Sync-Handshake bleibt robust: `HELLO`-Empfaenger bestaetigen mit `ACK`, antworten sofort mit dem vollstaendigen lokalen Snapshot `KEY/STATS/DPS/LOC` plus aktuellem Kick-State, explizite lokale Refreshes force-senden das lokale `HELLO` plus `KEY/STATS/DPS/LOC`, und manuelle `REQSYNC`-Refresh-Requests triggern genau eine hidden Reply fuer alle Buckets (`KEY`, `STATS`, `DPS`, `LOC`, `TARGET`, `KICK`), solange der Client nicht stopped oder paused ist. `DPS` ist in Background-Snapshots immer enthalten, unabhaengig von der Frame-Sichtbarkeit, damit Peers aktuelle Run-Stats auch hidden erhalten.
14. Im Hidden-Modus sind Queue-Scanning und permanentes Polling ausgesetzt, mit Ausnahme des dedizierten Kick-Keep-Alive fuer Party-Peers; Background-Roster-/Addon-Message-Sync, erforderliche Auto-Open-Transitions, eventgetriebene Pre-Render-Updates und genau eine erzwungene Refresh-Reply ohne Unhide bleiben aktiv. Frische Gruppenjoins duerfen zwar auto-open ausloesen, duerfen aber ohne vorherige sichtbare Queue-Capture keine Queue-Chat-Zusammenfassung nachliefern. Nach einem UI-Reload waehrend man bereits gruppiert ist, muss `PLAYER_ENTERING_WORLD` einen vollstaendigen Group-Roster-Rebuild triggern, damit das Roster-Panel sofort wieder erscheint, selbst in Party-Instanzen, in denen das Hidden-Frame-Gate sonst `GROUP_ROSTER_UPDATE` blockieren wuerde; beim erneuten Oeffnen der UI wird ausserdem der Utility-Tracker als dirty markiert, damit der erste sichtbare Render genau einen frischen Utility-Rescan vor dem Zeichnen ausfuehrt.
15. UI-Aktion-Spam-Guards fuer `Re-Sync` und `Share Keys` bleiben aktiv; der manuelle Re-Sync-Button verwendet sichtbar 10 Sekunden Cooldown, `Share Keys` 30 Sekunden. Wenn ein `SHAREKEYS`-Sync von irgendeinem isiLive-Peer eingeht, wird der lokale `Share Keys`-Button auf allen empfangenden Clients ueber `TriggerRemoteCooldown` fuer 30 Sekunden gesperrt; ein bereits laufender lokaler Cooldown wird dadurch nicht zurueckgesetzt.
16. Event-Gate-Dispatch bleibt robust: Fehler in Runtime-Handlern muessen gemeldet werden und duerfen den Gate-Loop nicht brechen.
17. LuaLS-Kompatibilitaet in gemeinsamen Helfern bleibt erhalten: `_G.debug` wird geschuetzt abgefragt, und wo Blizzard-Tooltip-APIs noch verwendet werden, kommen explizite Color-Signatures zum Einsatz.
18. Gemeinsame `isiLive`-Tooltip-Frames besitzen ihr eigenes Textlayout und duerfen UI-Hover-Rendering nicht zurueck ueber den geteilten Blizzard-`GameTooltip` leiten.
19. Raid-Gruppen blenden das sichtbare Roster-Panel aus, suspendieren Background-Sync und unterdruecken doppelte Raid-Transition-Notices, indem das Addon bis zum Verlassen der Raid-Groesse in einem Hard-off-Zustand bleibt.
20. Der optionale Game-Menu-Tooling-Strip schliesst das Menu, bevor sein Zielpanel geoeffnet wird; `ReloadUI` gehoert einem Secure-Macro-Button (`/click GameMenuButtonContinue` + `/reload`), der `ActionButtonUseKeyDown` spiegelt und blockierte Secure-Refreshes auf `PLAYER_REGEN_ENABLED` verschiebt, waehrend die anderen Eintraege direkte Opener-Pfade fuer `Professions`, `Talents`, `Spells`, `Achievements`, `Quests`, `Dungeons`, `Journal`, `Collections` und `Guild` behalten. Beide Game-Menu-Strips sind direkt als `GameMenuFrame`-Kinder gemountet, sodass Combat-Open-Pfade keine Overlay-`Show`/`Hide`- oder Layout-Mutationen ausfuehren; der sekundäre Travel-Strip bleibt weiter links und bietet `Arkantine`, `Hearthstone` und `Housing`.
21. Voruebergehend versteckte Legacy-Settings-Controls bleiben aus den Blizzard Settings entfernt, waehrend die Runtime ihre festen Defaults (`DPS` an, Markers leader-only aus, feste Namenstrunkierung, Legacy-`Travel`-Grid mit 2 Spalten) erzwingt, bis die Controls wieder freigeschaltet werden.
22. Die Lust-Onset-Erkennung des CdTrackers kombiniert Spieler-Harmful-Aura-Scans mit direkten lokalen Lust-Spellcasts, akzeptiert fuer den Lookup nur numerische Aura-`spellId`-Werte, ignoriert geschuetzte oder andere nicht-numerische Werte sicher, behandelt `UNIT_AURA(..., { isFullUpdate = true })`-Restores nach Zone/Reload als nicht-onsetartige Hydration und verwendet nur ein kurzes `PLAYER_ENTERING_WORLD`-Suppress-Fenster von 2 Sekunden als Sicherheitsnetz, bis der vollstaendige Aura-Restore eingetroffen ist.
23. Leader-Gain/Loss-Erkennung vergleicht den aktuellen lokalen Leader-State mit dem gecachten State sowohl auf `GROUP_ROSTER_UPDATE` als auch auf `PARTY_LEADER_CHANGED`; hidden Promotions unterdruecken Center-Notice und Chat-Output, spielen aber weiterhin den Transfer-Sound.
24. Ready-Check-Lifecycle-Events muessen ueber einen dedizierten Roster-Refresh-Pfad laufen, der row-background-State, Waiting-Sandglass-Marker und den 20-Sekunden-Declined-Hold erneut anlegt, ohne den generischen Vollrender des Rosters erneut auszufuehren oder Secure-Role-Button-Attribute anzufassen.
25. Roster-Leader-Marker werden ausschliesslich aus dem gespiegelten `UnitIsGroupLeader`-State abgeleitet; das Roster rendert fuer diese Zeilen eine 16x16-Krone, und bei gesyncten Leadern bleibt die blaue Heart-Markierung vor der Krone.
26. Persistierte Ghost-Zeilen duerfen in nicht-vollen Gruppen bestehen bleiben, aber die Roster-Sortierung muss immer alle aktiven Mitglieder vor Ghosts halten, damit das sichtbare 5-Zeilen-Clipping nie ein aktuelles Gruppenmitglied hinter stale Leavern versteckt.

## Architektur-Vertragssatz

`ARCHITECTURE_RULES.md` definiert die Strukturvertraege fuer den aktuellen Modulzuschnitt.
Diese Regeln sind keine Stilregeln wie `pep8`, sondern beschreiben erlaubte Ownership- und Dependency-Grenzen und werden ueber deterministische Source-/Modultests erzwungen.

Aktuell aktive Architekturvertraege decken ab:
- `isiLive.lua` als Composition Root
- `isiLive_event_handlers.lua` als Lifecycle-Aggregator
- `isiLive_runtime_setup.lua` mit context-basierten Controller-Factories
- `isiLive_runtime_state.lua` als zentrale API fuer gemeinsam genutzten mutierbaren Runtime-State
- `isiLive_controller_wiring.lua` mit exportierten Context-Factories
- `isiLive_config_builders.lua` als fokussierte Builder ohne Legacy-Event-/Group-Dependency-Builder

## Deterministische Validierungs-Gates

Lokale Release-Qualitaet ist absichtlich in statische und Runtime-Gates aufgeteilt:

1. Statische Checks:
   - `stylua --check .`
   - `powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1`
   - `cmd /c tools\check.cmd`
   - Lua-Syntax-Parse (`luac -p` fuer alle `.lua`-Dateien)
   - `ISILIVE_MAX_FILE_LINES=3200 ISILIVE_MAX_FUNCTION_LINES=420 lua tools/lua_metrics_check.lua`
2. Runtime-Logik-Checks:
   - `lua tools/validate_rules_logic.lua`
   - `lua tools/validate_architecture_rules.lua`
   - `lua tools/validate_usecases.lua`
3. `tools/validate_rules_logic.lua` validiert aktive Vertraege aus `RULES_LOGIC.md` gegen deterministische Testnamen.
4. `tools/validate_architecture_rules.lua` validiert aktive Architekturvertraege aus `ARCHITECTURE_RULES.md` gegen deterministische Testnamen.
5. `tools/validate_usecases.lua` fuehrt beide Validatoren zuerst aus und deckt danach 515 Szenarien ueber 38 Module ab; die Regelvalidatoren indizieren aktuell 515 deterministische Tests.

Die lokalen Wrapper `tools/check.ps1` und `tools/check.cmd` sind der bevorzugte Einstiegspunkt fuer das statische Gate, weil sie `luacheck` ueber den repo-lokalen Windows-Shim routen, statt direkt das LuaRocks-Script aufzurufen.

## UI-Struktur (ASCII-Skizze)

```text
| isiLive                                                 v0.9.135 Open/Close CTRL-F9 [H][V][M][M2][X]|
|---------------------------------------------------------------------------------------------------|
| Spec   Name         Flag Key     iLvl RIO        DPS                M+Managment  Marker    Travel  |
|---------------------------------------------------------------------------------------------------|
| [Tank] PlayerOne    [ ]  DB +14  633  (+12)3521 321.1K  [Blue]              [Readycheck]          |
| [Heal] PlayerTwo    [ ]  DAWN+12 629  (+0)3410  287.4K  [Grn]               [Countdown10]         |
| [DPS]  PlayerThree  [ ]  -       631  3377      -       [Purp]              [Countdown 0]         |
| [DPS]  PlayerFour   [ ]  AK +10  626  3290      301.8K  [Red]               [Share Keys]          |
| [DPS]  PlayerFive   [ ]  OFG+11  628  3333      298.2K  [Yel]               [Re-Sync]             |
|                                               ... [Circle] [Moon] [Skull] ...                     |
|                                                                             [Teleport Grid...]    |
| BR: 2/3 06:20  BL: 05:00                                                                        |
|---------------------------------------------------------------------------------------------------|
| Lead: Yes   M+: Active   State: Running   Dungeon: Mythic   Target Dungeon: Ara-Kara +14          |
+---------------------------------------------------------------------------------------------------+

Collapsed / Vertical Mini Mode:

|                                          [H][V][M][X]|
|----------------------------------------------------------------|
| M+Managment                 Marker                              |
| [Readycheck]                [Blue]                              |
| [Countdown10]               [Green]                             |
| [Countdown 0]               [Purple]                            |
| [Share Keys]                [Red]                               |
| [Re-Sync]                   [Yellow]                            |
| [... Circle / Moon / Skull stay stacked below in mini mode ...] |
+----------------------------------------------------------------+

Horizontal Mini Mode:

|                                      [H][V][M][X]|
|---------------------------------------------------|
| [CD 0] [CD] [RC]                                  |
| [Blue][Green][Purple][Red][Yel][Cir][Moo][Sku]    |
+-------------------------------------+
```

Zusaetzlich zum Main-Roster-Frame kann `isiLive_ui.lua` optionale Tooling- und Travel-Panels links an `GameMenuFrame` anhaengen, und `isiLive_settings.lua` registriert den Blizzard-Settings-Canvas fuer lokalisierte Config- und State-Mirror.

## Aktuelle Controller-Grenzen

| Controller | Input | Output |
|---|---|---|
| RuntimeState | Root-Orchestrierung und Controller-Callbacks | Zentraler mutierbarer Runtime-Snapshot (`roster`, Queue-Target, Flags, RIO-Baseline, Ready-Check-State, Layout-/Collapse-State) |
| Group | Group-Roster-Events | Neu aufgebautes Roster-Modell, gespiegelter lokaler Leader-State pro Roster-Eintrag, Ghost-Retention/Pruning und Lifecycle-Transitions |
| Highlight | Aktive Listings und Queue-Target | Aktiver Teleport-Spell und Highlight-State |
| KeySync | Sync-Messages und Owned-Snapshot-Daten | Roster-Backfill fuer Key/Stats/DPS/Location, Key-Ownership und Sync-Marker |
| Re-Sync | User-Refresh-Aktion | Erzwungener lokaler Snapshot, gruppenweiter Sync-Request, Inspect-Refresh-Pipeline und sichtbarer 10s-Cooldown |
| Share Keys | User-Chat-/Share-Aktion | Sofortiger eigener Key-Post in Party, gruppenweiter `SHAREKEYS`-Request an Peers, sichtbarer 30s lokaler Cooldown und remote getriggerter 30s-Cooldown-Lock auf allen Peer-Clients, die `SHAREKEYS` empfangen; ein bereits laufender lokaler Cooldown wird dabei nicht zurueckgesetzt |
| EventHandlersRuntime | Addon-, World-, Combat-, Inspect- und Sync-Events | Startup, Hidden-Mode-Sync, sofortige Full-State-Reply auf neues Peer-`HELLO`, Forwarding von `UNIT_AURA`-Full-Updates fuer den CdTracker, Regen-Recovery fuer pending Visibility/Height und Inspect-Dispatch |
| EventHandlersQueue | LFG-Queue-/Listing-Events | Sichtbare Queue-Capture, Erhalt von Pending-Join-Kontext auf negativen Follow-ups und Joined-Key-Tracking |
| EventHandlersChallenge | Challenge- und Ready-Check-Events | Run-Lifecycle, delayed Refresh, Raid-deferred Post-Run-Refresh-Resume, RIO-Delta-Aktivierung, Ready-Check-State, Declined-Hold-Tracking und dedizierter Ready-Check-UI-Refresh-Dispatch |
| Stats | Completion-Signale fuer Challenge- und Non-Challenge-Party-Runs plus Blizzard-Damage-Meter-Session | Begrenzte Last-Run-DPS-Snapshots mit kurzem Delayed-Session-Retry; persistent nur fuer den passenden lokalen Character, fuer fremde Spieler nur sessionweit |
| CdTracker | Battle-Res-Charges ueber `C_Spell.GetSpellCharges` mit Struct-Return, numerische Harmful-Lust-Aura-Scans, direkte lokale Lust-Spellcasts und `isFullUpdate`-Aura-Restore-Hydration | Live-Zeilenstate fuer BRes-Charges/Cooldown und Lust-Countdown mit zone-transition-sicherer Onset-Suppression |
| KickTracker | Spec-ID-Lookup, Spec-Change-Benachrichtigungen und lokaler Kick-State-Sync; Pet-Interrupt-Support fuer Warlock (`Spell Lock` 24s / `Axe Toss` 30s) und Devourer Demon Hunter | Per-Spec-Interrupt-Spell-ID und exakter Cooldown-State; stale Cooldowns werden bei Spec-Wechsel sofort geloescht; wenn Raid-Hard-off lokales Tracking unterdrueckt hat, darf Recovery nur aus exaktem Zustand fortgesetzt werden: exakte Blizzard-Cooldown-Daten, ein neu beobachteter Post-Raid-Kick-Cast oder eine exakte `no kick`-Aufloesung; malformed KICK-Payloads werden fail-closed verworfen; fremde Casts duerfen die Suppression nicht aufheben; hidden Kick-Keep-Alive-Sync fuer Party-Peers; Raid-Hard-off unterdrueckt jede Kick-Aktivitaet bis Raid-Ende; der Kick-State wird an den Sync weitergereicht fuer das Kick-Spalten-Rendering im Roster |
| LeaderWatch | `GROUP_ROSTER_UPDATE` / `PARTY_LEADER_CHANGED` plus gecachter Leader-State | Refresh fuer Leader-only-Buttons, sichtbare Center-Notice bei Promotion und Transfer-Sound-Feedback auch fuer hidden Promotions, sofern der User es nicht deaktiviert |
| RosterPanel | Roster-Modell und Lokalisierung | Main-Table-Rendering, aktive-vor-Ghost-Zeilenordnung unter dem 5-Zeilen-Budget, 16x16-Leader-Krone plus gesyncte Heart-Marker-Reihenfolge, dedizierter Ready-Check-Row-Background-Refresh mit Waiting-Sandglass und Declined-Hold, DPS-Spalte, dedizierter Kick-Column-Refresh-Pfad, dirty-on-show-Utility-Rescan nur auf dem ersten sichtbaren Roster-Render und Action-Button-Callbacks |
| SettingsPanel | Locale-, CVar- und SavedVariable-Getter plus Toggle-Callbacks | Blizzard-Settings-Canvas, Sprachwaehler, sichtbare Display-/Behavior-/Debug-Toggles, Slider fuer UI und Hintergrund, Selektor fuer Default-Open-Layout, optionaler Roster-Column-Guide-Toggle, Sound-Toggles fuer Leader-Transfer und Group-Join sowie temporaere Unterdrueckung von Legacy-Settings |
| TeleportUI | Season-Teleport-Eintraege und State | Insecure-Action-Teleport-Button-State, deterministische Season-Slot-Platzierung, locale-aware `M2`-Short-Code-Overlays im ready-Zustand und Cooldown-Labels mit Prioritaet solange Cooldown aktiv ist |

## Erweiterungspunkte

1. Neue Season-Unterstuetzung wird in `isiLive_season_data.lua` hinzugefuegt und ueber `isiLive_teleport.lua` genutzt.
2. Neue UI-Aktionen und Config-Flaechen werden ueber `isiLive_roster_panel.lua`, `isiLive_ui.lua` oder `isiLive_settings.lua` eingefuehrt und anschliessend ueber `isiLive_controller_wiring.lua` oder `isiLive_factory.lua` verdrahtet. Roster-Tooltip- und Layout-Helfer gehoeren nach `isiLive_roster_tooltip.lua` bzw. `isiLive_roster_layout.lua`; Factory-Context- und Controller-Helfer nach `isiLive_factory_frame_bridge.lua` und `isiLive_factory_controllers.lua`.
3. Neues Event-Verhalten geht zuerst durch die Gate-Logik und landet dann im passenden Lifecycle-Handler, damit der Runtime-State konsistent bleibt.
