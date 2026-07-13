# Wartungsdatei

Diese Datei ist fuer den Fall gedacht, dass das Addon laenger nicht gepflegt wurde und du schnell wieder in einen sicheren Arbeitsmodus kommen musst.

## 1) Erstes Vorgehen nach laengerer Pause

Arbeite immer in dieser Reihenfolge:

1. `CHANGELOG.md` oben lesen:
   - letzte reale Version
   - letzte geplante Version
   - offene Produktentscheidungen
2. `TODO.md` lesen:
   - offene Nachzuegler
   - Doku-/Release-Sync
3. `RULES_LOGIC.md` lesen:
   - aktive Regeln sind harte Runtime-Vertraege
   - besonders wichtig: No Guess, KICK-Hard-off und Rate-Limit-Vertraege niemals nur implizit ableiten
4. `ARCHITECTURE_RULES.md` lesen:
   - aktive Architekturregeln sind ebenfalls Gate-relevant
5. `AGENTS.md` lesen:
   - Workflow-/Gate-Pflichten nicht vergessen
6. `README.md` lesen:
   - aktueller Produkt- und Verhaltensstand fuer Nutzer
7. `RELEASE.md` lesen:
   - offizieller Release-Ablauf und Freigabe-Gates
   - Release-Tag erst nach gruenem `Lua Check` auf `main`
8. `USECASES.md` lesen:
   - deterministische Laufzeit- und Validierungsbasis
9. `ARCHITECTURE.md` lesen:
   - aktueller Struktur- und Wiring-Stand

## 2) Pflicht-Gates vor jeder echten Aenderung

Mindestens das hier laufen lassen:

```powershell
lua tools/validate_usecases.lua
```

Fuer groessere Wartung oder Release-Vorbereitung immer komplett:

```powershell
stylua --check .
powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1
ISILIVE_MAX_FILE_LINES=3200 ISILIVE_MAX_FUNCTION_LINES=420 lua tools/lua_metrics_check.lua
lua tools/validate_rules_logic.lua
lua tools/validate_architecture_rules.lua
lua tools/validate_usecases.lua
```

Optional, wenn du die aktuelle Coverage-Zahl lokal messen willst (CI macht das automatisch und laedt `luacov.report.out` als Artefakt hoch):

```powershell
luarocks install luacov 0.15.0-1
lua -lluacov tools/validate_usecases.lua
lua $env:APPDATA\luarocks\bin\luacov
lua tools/coverage_summary.lua luacov.report.out
```

In Git Bash / MSYS gibt `luarocks path` cmd-Syntax (`SET X=Y`) statt `export X=Y` aus. `tools/env.sh` uebersetzt die Variablen einmalig fuer die Session; ohne das findet `luacheck` seine eigenen Lua-Module nicht und `lua -lluacov ...` schlaegt an der Modul-Ladephase fehl:

```bash
source tools/env.sh
luacheck --version
lua -lluacov tools/validate_usecases.lua
```

Wenn das nicht gruen ist, nicht "kurz weiterbauen".
Vor jedem Release-Tag gilt zusaetzlich: erst `main` pushen, dann den gruenen `Lua Check` fuer genau diesen Commit abwarten. Lokal entspricht der Einstieg dafuer `tools/check.ps1` bzw. `tools/check.cmd`.

## 2.1) Agenten-Delegation

Wenn Hilfsagenten fuer Recherche, Review, Tests oder kleine Patches genutzt
werden, gilt zusaetzlich `docs/AGENTEN_WORKFLOW.md`.

Kurzfassung:
- Agenten bleiben strikt dirigiert und arbeiten nur in klar begrenzten
  Aufgaben.
- Keine Agentenaufgabe darf den No-Guess-Vertrag aufweichen.
- Schreibende Agenten brauchen einen eindeutigen Dateiumfang und duerfen keine
  parallelen Aenderungen an denselben Dateien vornehmen.
- Release-, Commit-, Push-, Tag- und Versionierungsaktionen bleiben
  ausdruecklichen User-Kommandos vorbehalten.
- Nach Agentenarbeit bleibt mindestens `lua tools/validate_usecases.lua`
  Pflicht.

## 3) Die Stellen, die nach WoW-Patches zuerst brechen koennen

### 3.1 WoW-Interface / Addon-Load

Pruefen:
- `isiLive.toc`
  - `## Interface`
  - `## Version`
- ob das Addon nach Login ohne Lua-Fehler laedt

Typische Ursache:
- neuer WoW-Patch, aber `Interface` noch alt

### 3.2 Dungeon-/Schwierigkeits-Kontext

Pruefen:
- `isiLive_status.lua`
- `isiLive_event_handlers_runtime.lua`

Kritisch:
- `GetInstanceInfo()`
- `difficultyID`-Mapping fuer Normal/Heroic/Mythic
- `C_Map.GetBestMapForUnit("player")`

Wichtig:
- `M+` wird ueber `CHALLENGE_MODE_COMPLETED/RESET` erkannt
- `M0` wird aktuell ueber `mythic non-challenge dungeon exit` erkannt
- fuer `M0` wird der Gruppen-Roster beim Eintritt eingefroren und spaeter beim Exit verwendet

Wenn Blizzard Difficulty-IDs aendert, muss das dort angepasst werden.

### 3.3 Blizzard Damage Meter API

Pruefen:
- `isiLive_stats.lua`
- `isiLive_event_handlers_challenge.lua`

Kritisch:
- `C_DamageMeter`
- `GetCombatSessionFromType`
- Session-Typen `overall/current`
- `combatSources`
- `amountPerSecond`
- `totalAmount`

Wenn Blizzard die Struktur aendert, bricht die DPS-Anzeige.

### 3.4 Season-/Dungeon-Daten

Pruefen:
- `isiLive_season_data.lua`
- `docs/SEASON_INTAKE.md`
- `tools/check_season_intake.lua`

Kritisch:
- `SeasonData.ACTIVE_SEASON_ID`
- `mapToTeleport`
- `displayOrder`
- `shortCodesByLocale`
- `challengeMapAliases`
- `inactivePortalMessageByLocale`

Aktueller Stand:
- `midnight_s1` ist die aktive Runtime-Season.
- `midnight_s2` ist als vorbereitetes Dataset mit verifizierten Portal-/Challenge-Mappings und vollstaendigen Darstellungsdaten vorhanden. Die Aktivierung erfolgt manuell und darf nicht von MDT-Forces abhaengen.
- Freigabe-Intake vom `2026-07-13`: alle acht ChallengeMapIDs, castbaren PortalSpellIDs, Mythic+-LFG-Activity-IDs und Darstellungsdaten sind gepflegt. Die abweichenden `128977x`-Instant-Spells sind keine Portal-Cast-IDs. Nur die optionale S2-MDT-Forces-DB fehlt; `midnight_s1` bleibt bis zur bewussten manuellen Umstellung aktiv.
- Die Portalraum-Belegung fuer `midnight_s2` ist dokumentiert, aber nicht aktiviert: ganz links leer, halb links Koenigsruh, oben Rubinlebensbecken, halb rechts Tempel von Sethraliss, ganz rechts leer.
- `midnight_s2.autoDetectFromChallengeMaps=false`; Login und `CHALLENGE_MODE_MAPS_UPDATE` duerfen S2 nicht aktivieren. Der User stellt S2 manuell um.

Wenn eine neue Season startet:
- neue Season als vollstaendigen Datensatz eintragen und die automatische Auswahl explizit erlauben oder verbieten
- Forces-DB getrennt pflegen und nur bei exaktem Match zur aktiven Season an Runtime-Verbraucher ausgeben
- bei `midnight_s2` die manuelle Aktivierungsentscheidung beibehalten
- keine halbfertige Season live schalten und kein Datum als Umschaltquelle verwenden

Fuer Midnight Season 2 muessen vor Aktivierung verifiziert werden:
- Challenge-Map-IDs fuer alle acht Dungeons (erledigt 2026-07-13)
- Portal-Spell-IDs fuer alle acht Dungeons (erledigt 2026-07-13)
- `displayOrder`, englische/deutsche Namen und alle Default-/deDE-Kurzcodes (erledigt 2026-07-13; Reihenfolge aufsteigend nach Map-ID)
- eine zu `midnight_s2` passende Forces-DB mit allen acht Dungeon-Gesamtwerten und NPC-Daten fuer die spaetere Freischaltung der optionalen Mob-Anzeigen; kein Aktivierungsblocker

Forces-Quelle fuer S2 ist der offizielle MythicDungeonTools-Quellstand. Stand `2026-07-13` / MDT `6.1.20` ist er noch nicht verwendbar: Im `Midnight`-Ordner existiert fuer S2 nur ein unvollstaendiges `MurderRow.lua`-Geruest mit `mapID = 12345 -- FIXME`, waehrend die sieben weiteren S2-Dungeon-Dateien fehlen. S2 kann trotzdem manuell aktiv sein. `SeasonData.GetMatchingForcesData()` liefert in diesem Zustand fuer die weiterhin gebuendelte S1-DB `nil`; Nameplate-Mobprozente, Mob-Tooltips und MDT-Total-Fallback bleiben unsichtbar, waehrend Blizzard-Scenario-Gesamtfortschritt weiterlaeuft.
- LFG-Activity-IDs fuer Mythic+-Listings (erledigt 2026-07-12)
- MDT-/Forces-Daten inklusive Dungeon-Gesamtwerten und NPC-Zaehlern
- Lokalisierte Dungeonnamen und stabile Kurz-Codes fuer `enUS`/Default und `deDE` (erledigt 2026-07-13)

Bis zur Aktivierung werden verifizierte oder teilweise verifizierte Funde in `docs/SEASON_INTAKE.md` gesammelt. Jede konkrete ID braucht `Source` und `VerifiedAt`; fehlende Werte bleiben `unresolved`. `tools/check_season_intake.lua` validiert die Struktur lokal, in CI und ueber den taeglichen Workflow `.github/workflows/season-intake.yml`, der ein GitHub Issue mit dem aktuellen Intake-Stand aktualisiert.

### 3.5 BR-/Bloodlust-Combat-Events und Addon-Message-Transport

Pruefen:
- `game/isiLive_combat_events.lua`
- `logic/isiLive_sync.lua` (`SendCombatAnnounce`, `ProcessAddonMessage.BRLUST`)
- `logic/isiLive_event_handlers_runtime.lua` (`HandleChatMsgAddonEvent`)
- `factory/isiLive_factory_combat_announces.lua` (`FormatDisplayName`, `broadcastCombatAnnounce`)
- `libs/ChatThrottleLib/ChatThrottleLib.lua`

Aktueller Soll-Zustand:
- `UNIT_SPELLCAST_SUCCEEDED` wird **nur** fuer `unit == "player"` verarbeitet. Casts anderer Spieler werden vor jeder Spell-ID-Inspektion verworfen, weil 12.0-Secret-Values sonst `"table index is secret"` werfen.
- Die Gruppen-Verteilung laeuft ueber den Addon-Message-Kanal (`BRLUST:<KIND>:<caster>:<spellID>`, Prioritaet `NORMAL` ueber `DispatchAddonMessage`), **nicht** ueber `SendChatMessage`. Sonst triggert 12.0 den `ADDON_ACTION_FORBIDDEN`-Popup in Protected-Zonen.
- 3-Sekunden-Dedup pro `sourceGUID|spellID`; `CHALLENGE_MODE_START` und `CHALLENGE_MODE_COMPLETED` rufen `Reset()`.
- Empfaenger rendern die lokalisierten Templates `COMBAT_CHAT_BR_USED` und `COMBAT_CHAT_LUST_STARTED`; unbekannte `BRLUST`-Kinds werden still verworfen.
- Toggles `chatAnnounceBR` und `chatAnnounceLust` sind standardmaessig an und leben in der `Chat Announcements`-Sektion der Blizzard-Settings.

Typische Ursachen fuer Brueche:
- Jemand legt `SendChatMessage` zurueck in den Broadcast-Pfad → `ADDON_ACTION_FORBIDDEN`-Popup im Live-Key.
- Der Self-Cast-Filter (`unit == "player"`) wird aufgeweicht → sofortiger Log-Spam aus anderen Spielern in protected Zonen.
- Blizzard erweitert BR- oder Lust-Spell-Liste → `BR_SPELL_IDS` / `LUST_CAST_IDS` entsprechend ergaenzen, sonst fehlen Ansagen.

### 3.6 ChatThrottleLib und Addon-Message-Prioritaeten

Pruefen:
- `libs/ChatThrottleLib/ChatThrottleLib.lua` (vendored, v24)
- `logic/isiLive_sync.lua` (`DispatchAddonMessage`, `Sync.ProcessAddonMessage`, `Sync.NormalizePlayerKey`)
- `isiLive.toc` — muss `libs/ChatThrottleLib/ChatThrottleLib.lua` vor allen isiLive-Modulen laden
- E2E-Simulatoren fuer den SHAREKEYS-Pfad und die Wire-Format-Toleranz:
  - `tools/simulate_sender_receiver.lua roundtrip` — Sender->Wire->Receiver-Handoff fuer SHAREKEYS (1 Sender + 1 Receiver), pinnt Channel-Resolve und 30s-Cooldown.
  - `tools/simulate_multi_peer_convergence.lua` — 1 Sender + 4 unabhaengige Receiver, pinnt Konvergenz und Cooldown-Isolation pro Peer.
  - `tools/simulate_cross_realm_realm_suffix.lua` — `NormalizePlayerKey` ueber Cross-Realm-Formate (Spaces, Apostrophe, Dashes); pinnt Self-Echo auch bei serverseitig gestripptem Sender-Suffix.
  - `tools/simulate_version_skew.lua` — HELLO/ACK-Parser-Toleranz ueber Versionsgrenzen, Mixed-Version-Group-State, `SplitPayload`-Empty-Field-Collapsing als bewusste Toleranz gepinnt.
  - `tools/simulate_hello_handshake.lua` — vollstaendiger HELLO/ACK/REQSYNC-Fan-Out (8 Messages: 1 ACK whisper + 7 Group-Broadcasts).

Aktueller Soll-Zustand:
- Alle Addon-Message-Sends laufen ueber `DispatchAddonMessage(prefix, payload, channel, priority)`.
- Wenn ChatThrottleLib geladen ist, wird `ChatThrottleLib:SendAddonMessage(priority, prefix, text, chattype)` verwendet; andernfalls Fallback auf raw `C_ChatInfo.SendAddonMessage`.
- Prioritaets-Schema:
  - `ALERT` → `KICK`, `REQSYNC`, `SHAREKEYS` (zeitkritische Coordination und schneller User-Fanout)
  - `NORMAL` → `HELLO`, `KEY`, `TARGET`, `BRLUST`, LibKeystone-Party-/Request-Envelopes
  - `BULK` → `STATS`, `DPS`, `LOC` (Metriken, duerfen unter Last zurueckstehen)
- Jeder Send loggt `sent=true|false` in den SyncLog-Trace; ChatThrottleLib-Drops werden dort sichtbar.
- `Sync.SendShareKeysRequest()` darf nur `true` zurueckgeben, wenn `DispatchAddonMessage()` den `SHAREKEYS`-Payload tatsaechlich erfolgreich angenommen hat; ein vorhandener Kanal allein reicht nicht als Erfolg.

Typische Ursachen fuer Brueche:
- `.luacheckrc` oder `.stylua`-Ausnahmen fuer `libs/` werden entfernt → StyLua- oder Luacheck-Diagnose bricht auf der vendored Lib.
- Jemand sendet wieder raw `C_ChatInfo.SendAddonMessage` direkt → unter Last droppt die Nachricht ohne Trace.
- Ein SHAREKEYS-Caller ignoriert den Rueckgabewert von `DispatchAddonMessage` → der Button kann faelschlich sperren, obwohl kein Peer die Anfrage erhalten hat.

### 3.7 Mob-Tooltip mit Forces-Anteil

Pruefen:
- `ui/isiLive_mob_tooltip.lua`
- `data/isiLive_mplus_forces.lua`
- `tools/sync_mdt_forces.lua`
- `tools/check_mplus_db_lifetime.lua`
- `.github/workflows/sync-mplus-forces.yml`

Aktueller Soll-Zustand:
- Der geplante Forces-Workflow darf die frisch geklonten MDT-Dungeondateien nicht mit einem `_G`-Fallback laden. `tools/sync_mdt_forces.lua` stellt nur `MDT` und `ipairs` bereit, lehnt Bytecode und Quellen oberhalb von 8 MiB ab und bricht eine Quelle nach einer Million Instruktionen ab.
- Externe Actions in allen Workflows tragen einen vollstaendigen Commit-SHA plus lesbaren Major-Kommentar. `.github/dependabot.yml` pflegt diese Pins woechentlich; bewegliche `@vN`-Referenzen duerfen nicht direkt zurueckkehren.
- Registrierung laeuft ueber `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, ...)`. Fehlen dieser APIs = Feature bleibt still inaktiv.
- Die Forces-Zeile wird nur gerendert, wenn `C_ChallengeMode.GetActiveChallengeMapID()` eine aktive Map meldet und die NPC-Map-ID aus dem Datensatz damit uebereinstimmt.
- `OnTooltipCleared`-Hook verhindert Doppelzeilen auf `TooltipDataProcessor`-Rerender.
- `MobTooltip.SetEnabled(false)` gated das Rendering komplett.
- 12.0-Secret-Value-Guards an drei Stellen: `C_ChallengeMode.GetActiveChallengeMapID()`, `tooltipData.guid` und der Fallback `UnitGUID("mouseover")`. Ohne diesen Guard wirft der SetWorldCursor-Tooltip-Pfad `"attempt to compare field 'guid' (a secret string value tainted by 'isiLive')"`, sobald ein Mob-GUID als Secret-String zurueckkommt.

Typische Ursachen fuer Brueche:
- Blizzard aendert die `TooltipDataProcessor`-API oder `Enum.TooltipDataType.Unit` → Feature registriert sich nicht mehr.
- `data/isiLive_mplus_forces.lua` laeuft ueber `expiresAt` → CI-Lifetime-Gate blockiert den Release; der wochenweise MDT-Refresh-Workflow regeneriert normalerweise rechtzeitig, manueller Retrigger ueber `workflow_dispatch` falls der Donnerstag-Run gescheitert ist.

### 3.8 Mob-Nameplate-Forces-Anker

Pruefen:
- `ui/isiLive_mob_nameplate.lua`
- `ui/isiLive_settings_nameplates.lua`
- `factory/isiLive_config_builders.lua` (`/il npstate`)
- `testmodul/isilive_test_scenarios_mob_nameplate.lua`
- `testmodul/isilive_test_scenarios_ui_settings_nameplate.lua`
- `docs/RULES_LOGIC.md` Regel 75
- `docs/USECASES.md` UC-18

Aktueller Soll-Zustand:
- Settings-Preview und Runtime nutzen denselben Renderer (`MobNameplate.ApplyPreview` / `ApplyPosition`) fuer Text, Fontgroesse, Position und Offsets. Wenn die Preview sichtbar anders ist als live, ist die Preview selbst verdaechtig, nicht der User-Offset.
- Der Live-Anker ist eine verifizierbare Frame-Kette, kein Kalibrierwert:
  - Platynator: sichtbares Display-Kind der Blizzard-Namensplatte mit `widgets`; das Widget mit `details.kind == "health"` gewinnt vor Blizzard-`UnitFrame.healthBar`, weil Platynator den originalen Blizzard-UnitFrame verstecken kann.
  - Plater: `nameplate.unitFrame.healthBar`, passend zum Plater-`unitFrame.healthBar`-Pfad.
  - Blizzard/default: `nameplate.UnitFrame.healthBar`.
  - Fallback nur wenn kein Healthbar-Anker existiert: Nameplate-Root-Frame.
- Das Overlay bleibt auf `UIParent`, damit externe Nameplate-Skalierung nicht die isiLive-Schriftgroesse veraendert. Die Strata kommt von der Root-Namensplatte; das FrameLevel wird relativ zum beobachteten Healthbar-Anker erhoeht.
- Position `RIGHT`/`LEFT` muss die Textkante an die Healthbar-Kante haengen, nicht den Text in einem breiten Overlay zentrieren. `Y-Offset = 0` bedeutet vertikale Mitte des gewaehlten Ankers.
- `/il npstate [unit]` muss bei betroffenen Plates `anchorSource` ausgeben. Erwartete Werte sind z. B. `platynator-health-widget`, `unitFrame.healthBar`, `UnitFrame.healthBar` oder `nameplate-root`.

Learnings:
- Offsets duerfen einen falschen Anker nicht kaschieren. Wenn erst extreme X/Y-Offsets "mittig" wirken, haengt der Text sehr wahrscheinlich an der falschen Platte oder am falschen Root-Frame.
- Bei externen Nameplate-Addons reicht "Addon geladen" nicht als Quelle. Belastbar ist nur die tatsaechlich am Nameplate vorhandene Frame-Struktur.
- Platynator und Plater sind unterschiedlich: Platynator baut eigene Display-Widgets auf die Blizzard-Nameplate; Plater arbeitet mit einem Plater-`unitFrame` und dessen `healthBar`.
- Eine Settings-Vorschau ist nur nuetzlich, wenn sie denselben Ankerpfad simuliert wie die Runtime. Fake-Previews muessen daher mindestens einen `UnitFrame.healthBar` bereitstellen und ueber den Shared-Renderer laufen.
- Neue Nameplate-Addon-Kompatibilitaet immer mit einem konkreten Anker-Test pinnen, nicht nur mit "Addon geladen -> Overlay rendert".

Typische Ursachen fuer Brueche:
- Ein externer Nameplate-Addon-Update benennt seine sichtbare Healthbar-Struktur um → `anchorSource` faellt auf `nameplate-root` oder einen versteckten Blizzard-Frame zurueck.
- Das Overlay wird wieder direkt auf ein extern skaliertes Nameplate-Child geparentet → Fontgroesse driftet gegenueber dem Settings-Wert.
- Die Preview baut ein eigenes SetPoint-Verhalten statt `MobNameplate.ApplyPreview` zu nutzen → Preview und Liveposition laufen auseinander.
- Jemand erzwingt wieder globale Top-Strata wie `TOOLTIP` → Anzeige liegt ueber UI-Panels statt auf Nameplate-Ebene.

### 3.9 M+ Forces DB / MDT-Sync

Pruefen:
- `data/isiLive_mplus_forces.lua` (generierter Datensatz, niemals von Hand editieren)
- `tools/sync_mdt_forces.lua` (Generator, liest MDT und erzeugt den Datensatz)
- `tools/check_mplus_db_lifetime.lua` (Lifetime-Gate in CI)
- `.github/workflows/sync-mplus-forces.yml` (wochenweiser Auto-Refresh)
- `.github/workflows/season-readiness.yml` (taeglicher Readiness-Report ohne Schreibrechte)
- `.github/workflows/inspect-mplus-season-preview.yml` (taeglicher MDT-Forces-Verfuegbarkeitsreport mit stabilem Issue bei strukturell nutzbaren Quellen)
- `.github/workflows/season-intake.yml` (taeglicher Intake-Status mit Issue-Update)

Aktueller Soll-Zustand:
- Der Auto-Refresh laeuft donnerstags 06:00 UTC nach dem MDT-Release-Fenster (US Tuesday Patch + EU Wednesday Reset). Manuell ausloesbar ueber `workflow_dispatch`.
- Der Workflow klont MDT, regeneriert den Datensatz, laeuft den vollen CI-Preflight (stylua, luacheck, syntax, metrics, locale drift, lifetime, usecases) und committet nur bei echtem Diff direkt nach `main`.
- `expiresAt` ist `generatedAt + 15 Tage`. Das Lifetime-Gate blockiert jeden Release mit abgelaufenem DB-File; Override ausschliesslich ueber `ISILIVE_ALLOW_STALE_MPLUS_DB=1`.
- Der Generator schreibt Single-Space-Key-Format (`season = %q,`), damit StyLua den regenerierten Datensatz akzeptiert.
- Der Season-Readiness-Workflow fuehrt `tools/inspect_season_readiness.lua` aus, berichtet aktive/vorbereitete Seasons, Readiness-Fehler und den Abgleich zwischen aktiver Season und Forces-DB als Summary/Artifact und committet nichts.
- Der M+-Season-Preview-Workflow klont MDT taeglich und fuehrt `tools/inspect_mdt_season_preview.lua` fuer die angefragte Season aus. Ein stabiles GitHub Issue wird erst erstellt oder wieder geoeffnet, wenn alle acht Dungeons als ausfuehrbare Datensaetze mit exakt passender Map-ID, positivem normalem Dungeon-Gesamtwert und mindestens einem positiven NPC-Forces-Eintrag strukturell nutzbar sind. Der Inspector prueft nach ungueltigen Texttreffern weitere Dateien. Das Signal beweist nicht, dass upstream bereits jeden beabsichtigten NPC enthaelt; die generierte Runtime-DB bleibt separat zu validieren. Locale-/Moduldateien und Platzhalter wie `mapID = 12345` erzeugen keinen Alarm. Das Issue wird seitenuebergreifend anhand seines Markers gefunden, damit geschlossene Issues nicht dupliziert werden.

Typische Ursachen fuer Brueche:
- MDT aendert die Struktur von `dungeonEnemies` / `dungeonTotalCount` / `mapInfo` → `sync_mdt_forces.lua` anpassen, lokal per `lua tools/sync_mdt_forces.lua` gegen einen frischen `tools/cache/mdt`-Clone testen.
- MDT-Clone schlaegt im Workflow fehl → Auto-Refresh bleibt still, Lifetime-Gate wird irgendwann rot.
- Season-Wechsel → `SEASON_TO_MDT_DIR` in `sync_mdt_forces.lua` erweitern, Default-`SEASON_DEFAULT` umstellen.

### 3.10 Gruppensuche-Buff-Rating-Herzchen

Pruefen:
- `ui/isiLive_lfg_flags.lua`
- `ui/isiLive_settings_sections.lua`
- `locale/isiLive_texts.lua`
- `core/isiLive_db_schema.lua`
- `testmodul/isilive_test_scenarios_lfg_flags*.lua`
- `testmodul/isilive_test_scenarios_ui_settings*.lua`
- `testmodul/isilive_test_scenarios_locale.lua`

Aktueller Soll-Zustand:
- `lfgGroupBonusesEnabled` ist ein SavedVariable-Schemafeld mit Default `true`.
- Suchergebniszeilen und Bewerberzeilen zeigen nur relevante, nicht stapelnde Nicht-Utility-Boni als gruene Marker.
- Battle Res, Bloodlust, Power Infusion, Devotion Aura, Atrophic Poison und vergleichbare Utility-Hinweise duerfen im Tooltip erscheinen, zaehlen aber nicht fuer die kompakten Marker.
- Settings-Beschreibung und sichtbare Marker verwenden `Interface\AddOns\isiLive\media\heart_bonus_green.tga`; Font-Herz-Glyphen sind fuer dieses Feature nicht stabil genug.
- Die Settings-Beschreibung erklaert untereinander 1/2/3/4 Herzchen als einen, zwei, drei beziehungsweise vier oder mehr relevante Buffs.
- `SetGroupBonusesEnabled(false)` leert Suchergebnis-Caches und sichtbare Bewerbermarker.

Typische Ursachen fuer Brueche:
- Ein neuer Bonus wird als Utility oder als stapelnder Gruppenbuff falsch einsortiert → Markerzahl wird irrefuehrend.
- Eine Locale-Beschreibung nutzt ein rohes Herzzeichen statt `heart_bonus_green.tga` → Darstellung driftet zwischen Fonts/Clients.
- Ein Settings-Schalter schreibt nur DB, ruft aber nicht den Live-Callback → Anzeige aendert sich erst nach Reload.

### 3.11 Lokalisierung und Uebersetzungs-PRs

Pruefen:
- `locale/isiLive_languages.lua`
- `locale/isiLive_locale.lua`
- `locale/isiLive_texts.lua`
- `tools/check_locale_drift.lua`
- `testmodul/isilive_test_scenarios_locale.lua`
- `docs/CHANGELOG.md`

Aktueller Soll-Zustand:
- Beim Programmieren werden neue Texte mindestens in Englisch und Deutsch gepflegt.
- Weitere vorbereitete Locales duerfen bewusst englischen Fallback behalten, bis sie nachbearbeitet werden.
- Settings-Texte sind fuer `frFR`, `esES`, `ptBR`, `itIT`, `ruRU` und `trTR` nachbearbeitet; andere vorbereitete Locale-Bereiche duerfen weiterhin englische Fallbacks tragen. Neue Settings-Texte duerfen diesen Stand nicht wieder auf englische Fallbacks zuruecksetzen.
- Hilfreiche Uebersetzungs-PRs werden angenommen, wenn sie technisch zum aktuellen UI- und Regelvertrag passen; der User wird im Changelog bedankt.
- `Locale.LocaleToLanguageTag` ist tooltip-hotpath-sicher: statischer Lookup, kein Iterieren ueber `Languages.SUPPORTED` beim Hover.
- `koKR`, `zhCN` und `zhTW` bleiben display-only Flag-Tags ohne vollstaendige UI-Sprache.

Typische Ursachen fuer Brueche:
- Ein PR uebersetzt eine vorbereitete Locale, aber die aktuellen UI-Begriffe oder Texturvertraege werden nicht angepasst → Uebersetzung erst kompatibel machen, dann uebernehmen.
- Neue Keys werden nur in enUS gesetzt → Locale-Drift-Gate wird rot.
- Locale-Flag-Aufloesung wird wieder lazy aus der Sprachliste gebaut → Tooltip-Hover kann erneut `script ran too long` ausloesen.

## 4) Dinge, die bewusst so gebaut sind und nicht versehentlich rueckgaengig gemacht werden duerfen

### 4.1 Kein Raten

Das Projekt folgt strikt:
- keine guessed dungeon names
- keine guessed activity/map fallbacks
- keine guessed DPS-Zuordnung

Wenn etwas nicht eindeutig ist, bleibt es ungelost.

### 4.2 Speicher darf nicht explodieren

Aktueller Soll-Zustand:
- keine persistente Fremdspieler-Historie
- keine persistente `Runs together`-Historie
- fremde Last-Run-DPS nur session-only
- persistent bleibt nur der eigene letzte Run-DPS

Wenn du hier wieder Fremdspieler persistierst, baust du wieder unbounded Wachstum ein.

**Zusaetzliches Sicherheitsnetz seit dem Schema-Sanitizer ([core/isiLive_db_schema.lua](../core/isiLive_db_schema.lua)):** Map-typed Felder mit `maxMapEntries`-Property werden bei Cap-Ueberschreitung automatisch beim ADDON_LOADED beschnitten. Aktuelle Caps:
- `errorLog` ≤ 200 (ErrorLog-Modul cappt selbst auf 100; Schema ist Sicherheitsnetz)
- `rioBaseline` ≤ 5000 (lifetime cross-realm players)
- `stats.playerLastRunByCharacter` ≤ 5000 (per-character Run-Stats)
- `runtimeLog` ≤ 800 (LogBuffer-Ring, schon vorher)
- `queueDebugLog` ≤ 400 (LogBuffer-Ring, schon vorher)

Beim Laden beziehungsweise ersten Diagnosezugriff verdichtet `RuntimeLog` alte uebergrosse oder mit einem frueheren Cap rotierte Ringe physisch auf die neuesten 800 Eintraege. Gefilterte Tails durchsuchen alle 800 behaltenen Eintraege; ein internes 500er-Suchfenster darf nicht wieder eingefuehrt werden.

Realistische User sollten diese Caps nie erreichen. Wenn doch, surfaced der Trim einen echten Bug upstream (infinite append in einer Schleife) und haelt die SavedVariables-Datei unter ~3MB statt sie auf Gigabyte-Skala wachsen zu lassen. Jede Trim-Aktion wird via `[DBSCHEMA] trimmed ...` geloggt.

Wenn du ein neues map-typed Feld in IsiLiveDB einfuehrst (z.B. ein per-Player-Cache), MUSS es im Schema mit `maxMapEntries` deklariert werden. Sonst waechst es ungebunden.

### 4.2b Always-on Lua-Error-Erfassung

Pruefen:
- [core/isiLive_error_log.lua](../core/isiLive_error_log.lua)
- `IsiLiveDB.errorLog` (Ring-Buffer, persistent)
- Slash: `/isilive errorlog [N|status|clear]`

Aktueller Soll-Zustand:
- `geterrorhandler/seterrorhandler`-Hook bei `ADDON_LOADED`, **immer aktiv** (unabhaengig von `runtimeLogEnabled`)
- Chain-of-responsibility: BugSack/`!BugGrabber`/Blizzard-Default kriegen Errors immer ZUERST, bevor wir capturen
- Filter auf `isiLive`-mention in Message ODER Stack-Frame; Plater/WeakAuras/Blizzard-UI-Errors werden bewusst gedroppt
- Dedup via `count++` auf gleichem `fullText`; Combat-Storm = 1 Eintrag mit `count=N`, nicht N Duplikate
- Hard-Cap 100 Eintraege; oldest-by-`lastSeen` evicted bei Ueberlauf
- Defensive: jeder interner Schritt `pcall`-wrapped; Error im Error-Logger selbst loest keinen Sekundaer-Cascade aus

Wenn du den Filter aufweichst (alle Errors statt nur isiLive-Errors), wird der Buffer von Fremd-Addon-Errors zugemuellt. Wenn du den Chain-of-responsibility brichst (eigenen Handler statt previous-call-first), zerstoerst du BugSack-Workflow fuer alle isiLive-User.

### 4.3 Roster-Layout ist absichtlich eng

Pruefen:
- `isiLive_roster.lua`
- `isiLive_roster_panel.lua`
- `RULES_LOGIC.md` Regeln 35 und 36

Aktueller Soll-Zustand:
- Name max 12 Zeichen
- Spec max 5 Zeichen
- Sprache nur Flagge
- Key-Code max 4 Zeichen
- kein numerischer `mapID`-Fallback im Key
- feste Kompaktbreiten fuer Spec/Name/iLvl/Key/Rio/DPS/Flagge

Nicht "nur mal eben breiter" machen, ohne Tests und Regeln mitzuziehen.

### 4.4 Hidden-Mode ist nicht mehr "UI komplett schlafen legen"

Pruefen:
- `isiLive_events.lua`
- `isiLive_bootstrap.lua`
- `isiLive_config_builders.lua`
- `isiLive_event_handlers_runtime.lua`
- `isiLive_event_handlers_challenge.lua`
- `isiLive_factory_status.lua`
- `isiLive_factory_secondary_runtime.lua`
- `isiLive_factory_cd_tracker.lua`
- `isiLive_factory_kick_tracker.lua`
- `isiLive_roster_panel.lua`
- `isiLive_leader_watch.lua`

Aktueller Soll-Zustand:
- Hidden stoppt Queue-Scanning und dauerhafte Polling-Last
- `CHAT_MSG_ADDON` und `GROUP_ROSTER_UPDATE` duerfen weiterlaufen
- eventgetriebenes Vor-Rendern der UI ist erlaubt
- der dedizierte Kick-Keep-Alive darf hidden fuer normale Gruppen und verifizierte automatische Instanzgruppen weiterlaufen, darf solo aber nicht scannen oder senden
- der Utility/CD-Poller darf hidden nicht dauerhaft laufen; beim erneuten Anzeigen markiert die Show-Logik den Tracker dirty, und der erste sichtbare Render zieht genau einen frischen CD-Scan
- Leader-State wird hidden still synchronisiert
- hidden gibt es keine Notice-/Chat-Ausgabe fuer Leader-Transfers
- verzoegerter Post-Run-Refresh darf im Raid nicht laufen; er muss nach Raid-Ende sauber wieder aufgenommen werden
- lokale LuaLS-/VS-Code-Konfiguration wie `.luarc.json` bleibt developer-spezifisch, kann absolute Pfade enthalten und gehoert nicht ins Repo; falls die Datei existiert, muss sie in `.gitignore` stehen

Nicht versehentlich zurueckbauen auf:
- "alles hidden komplett aus"
- oder das Gegenteil: permanente Hidden-CPU-Last / Polling
- oder solo laufender Kick-Heartbeat ohne verifizierte normale Gruppe oder automatische Instanzgruppe
- oder "Raid verhaelt sich nur wie Hidden" statt echtem Hard-Off

## 5) Wenn UI oder Runtime geaendert wurde, diese Dateien mitziehen

Pflicht nachziehen je nach Aenderung:
- `CHANGELOG.md`
- `USECASES.md`
- `README.md`
- `RELEASE.md`
- `TODO.md`
- `RULES_LOGIC.md` nur wenn echte Runtime-Regel geaendert/neu ist
- `ARCHITECTURE_RULES.md` nur wenn echte Strukturregel geaendert/neu ist

Wichtig:
- `RULES_LOGIC.md` ist append-only
- bei neuen aktiven Regeln immer Testnamen im selben Change ergaenzen
- ein geloeschter Git-Tag loescht kein bereits erzeugtes CurseForge-Paket; das muss dort separat archiviert/entfernt werden
- `.pkgmeta` und die GitHub/WowUp-Ausschlussliste halten PNG-Screenshots, Logo-Dateien, die grosse `CHANGELOG.md`, `TODO.md` und die `.claude/`-Helper aus Nutzerpaketen raus; der Paritaetstest muss bei jeder Aenderung beider Listen gruen bleiben. Die Release-Notiz nutzt stattdessen `CHANGELOG_RELEASE.md` als kurzen Link-Hinweis auf das Repo.
- `CHANGELOG_RELEASE.md` ist kurz, aber nicht leer: bei user-visible Features gehoeren 3-5 Release-Highlights hinein.

## 6) Wenn die Season gewechselt oder Dungeon-Daten angefasst wurden

Dann immer:

1. `isiLive_season_data.lua` komplett pruefen
2. `CHANGELOG.md` aktualisieren
3. `README.md` auf aktive/prepared Season abgleichen
4. `USECASES.md` pruefen, falls Verhalten sichtbar anders ist
5. `lua tools/validate_usecases.lua` laufen lassen

## 7) Ingame-Smoke nach groesseren Aenderungen

Mindestens das testen:

1. Addon laedt ohne Fehler
2. UI oeffnen/schliessen
3. Gruppeneintritt / Gruppenaustritt
4. Demo-Modus + Refresh
5. M+-Run Ende -> DPS sichtbar
6. M0 betreten, Gruppe teilweise aufloesen, Dungeon verlassen -> DPS bleibt ueber frozen roster matchbar
7. Key-Anzeige zeigt echte Shortcodes, keine `228`/`277`-Zahlen
8. Tooltip zeigt `Level`, `Lang`, `Last run DPS`
9. LFG-Suchergebnis und Bewerberzeile zeigen Buff-Rating-Herzchen nur, wenn der Settings-Schalter aktiv ist
10. Settings-Beschreibung fuer `Group Finder: Buff rating hearts` nutzt gruene Texturbeispiele untereinander
11. Readycheck-Button funktioniert als Leader und bleibt fuer Nicht-Leader optisch deaktiviert
12. Ready-Check-Zeilen zeigen Ready, Not-ready und Waiting jeweils mit Hintergrundfarbe und passendem Blizzard-Symbol; die Resultat-Holds behalten beides und entfernen beides nach Ablauf

## 8) Wenn du nur 20 Minuten hast

Dann genau das:

1. `CHANGELOG.md` oben lesen
2. `TODO.md` lesen
3. `lua tools/validate_usecases.lua`
4. `isiLive_season_data.lua` auf aktive Season pruefen
5. `isiLive.toc` auf aktuelle WoW-Interface-Version pruefen

Wenn einer dieser Punkte rot ist, nicht blind releasen.
