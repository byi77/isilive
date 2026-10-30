#!/usr/bin/env python3
"""Build isiLive forces start values from Warcraft Logs.

For timed keys in a level band it sums the forces of every enemy death up to
each boss kill, keeps only runs whose sum matches the logged forces, and writes
the median per boss for the common kill order as data/isiLive_forces_seed.lua.

Only aggregated percentages leave this tool: no player, guild or report data
goes into the generated file. Results per run are cached, so a repeated run
only pays for keys it has not seen.
"""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path
from statistics import median
from typing import Any

TOKEN_URL = "https://www.warcraftlogs.com/oauth/token"
GRAPHQL_URL = "https://www.warcraftlogs.com/api/v2/client"

# Warcraft Logs dungeon encounter ID -> (challenge map ID, name) for Midnight S2.
SEASON_DUNGEONS = {
    "midnight_s2": {
        12993: (588, "Altar of Fangs"),
        12825: (586, "Den of Nalorakk"),
        61762: (249, "King's Rest"),
        12813: (587, "Murder Row"),
        112521: (399, "Ruby Life Pools"),
        61877: (250, "Temple of Sethraliss"),
        12859: (584, "The Blinding Vale"),
        12923: (585, "Voidscar Arena"),
    }
}

# Share of the required forces a run has to log to count.
MIN_LOGGED_SHARE = 0.9

# Guards before a result may replace the published start values.
MAX_CHECKPOINT_SHIFT = 10
MIN_FINAL_CHECKPOINT = 95

# Progress points of the time curve, same progress as game/isiLive_time_pace.lua:
# half forces, half killed bosses.
# The API serves 20 pages per key level; fallback levels end here.
LAST_RANKING_PAGE = 20
TIGHT_MAX_LEVEL = 22
CURVE_PROGRESS = [round(0.05 * step, 2) for step in range(1, 20)]

RANKINGS_QUERY = """
query($id: Int!, $bracket: Int, $page: Int) {
  worldData { encounter(id: $id) {
    fightRankings(page: $page, leaderboard: LogsOnly, bracket: $bracket)
  } }
}
"""

FIGHT_QUERY = """
query($code: String!, $fights: [Int]) {
  reportData { report(code: $code) { fights(fightIDs: $fights) {
    startTime endTime keystoneLevel keystoneBonus countReached countRequired npcCountMap
    enemyNPCs { id gameID }
    dungeonPulls { encounterID kill endTime }
  } } }
  rateLimitData { limitPerHour pointsSpentThisHour pointsResetIn }
}
"""

DEATHS_QUERY = """
query($code: String!, $fights: [Int], $start: Float, $end: Float) {
  reportData { report(code: $code) {
    events(dataType: Deaths, hostilityType: Enemies, fightIDs: $fights,
           startTime: $start, endTime: $end, limit: 10000) { data nextPageTimestamp }
  } }
}
"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--season", default="midnight_s2")
    parser.add_argument("--min-level", type=int, default=12)
    parser.add_argument("--max-level", type=int, default=18)
    parser.add_argument("--runs-per-level", type=int, default=7, help="new runs per dungeon and key level")
    parser.add_argument("--max-age-days", type=int, default=42, help="ignore runs older than this")
    parser.add_argument("--min-route-runs", type=int, default=20, help="runs a kill order needs to be written")
    parser.add_argument("--point-reserve", type=float, default=100, help="wait for the reset below this many points")
    parser.add_argument("--cache", type=Path, default=Path(".wcl-cache/runs.json"))
    parser.add_argument("--out", type=Path, default=None, help="generated Lua file; without it only the summary prints")
    parser.add_argument("--tight-runs", type=int, default=25, help="barely timed runs per dungeon for the time curve")
    parser.add_argument("--time-out", type=Path, default=None, help="generated time curve Lua file")
    return parser.parse_args()


def post_json(url: str, headers: dict[str, str], body: bytes) -> Any:
    request = urllib.request.Request(url, data=body, headers=headers, method="POST")
    with urllib.request.urlopen(request, timeout=120) as response:
        return json.loads(response.read().decode("utf-8"))


class Client:
    def __init__(self, reserve: float) -> None:
        client_id = os.environ.get("WARCRAFTLOGS_CLIENT_ID")
        client_secret = os.environ.get("WARCRAFTLOGS_CLIENT_SECRET")
        if not client_id or not client_secret:
            raise SystemExit("set WARCRAFTLOGS_CLIENT_ID and WARCRAFTLOGS_CLIENT_SECRET")
        auth = base64.b64encode(f"{client_id}:{client_secret}".encode("utf-8")).decode("ascii")
        token = post_json(
            TOKEN_URL,
            {"Authorization": f"Basic {auth}", "Content-Type": "application/x-www-form-urlencoded"},
            urllib.parse.urlencode({"grant_type": "client_credentials"}).encode("ascii"),
        )["access_token"]
        self.headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
        self.reserve = reserve

    def query(self, query: str, variables: dict[str, Any]) -> dict[str, Any]:
        body = json.dumps({"query": query, "variables": variables}).encode("utf-8")
        payload = post_json(GRAPHQL_URL, self.headers, body)
        if payload.get("errors"):
            raise RuntimeError(json.dumps(payload["errors"], ensure_ascii=False)[:400])
        return payload["data"]

    def respect_limit(self, limits: dict[str, Any]) -> None:
        left = limits["limitPerHour"] - limits["pointsSpentThisHour"]
        if left < self.reserve:
            wait = int(limits["pointsResetIn"]) + 5
            print(f"rate limit: {left:.0f} points left, waiting {wait}s", flush=True)
            time.sleep(wait)


def fetch_rankings(client: Client, encounter: int, level: int, page: int = 1) -> list[dict[str, Any]]:
    # The bracket argument is one below the keystone level it returns.
    data = client.query(RANKINGS_QUERY, {"id": encounter, "bracket": level - 1, "page": page})
    rankings = data["worldData"]["encounter"]["fightRankings"].get("rankings", [])
    return [row for row in rankings if row["report"]["code"] and row.get("bracketData") == level]


def spread(rows: list[dict[str, Any]], count: int) -> list[dict[str, Any]]:
    """Evenly over the ranking, so a sample is not only the fastest keys."""
    if len(rows) <= count:
        return rows
    return [rows[i * len(rows) // count] for i in range(count)]


def fetch_deaths(client: Client, code: str, fight_id: int, start: float, end: float) -> list[dict[str, Any]]:
    deaths: list[dict[str, Any]] = []
    cursor: float | None = start
    while cursor is not None:
        data = client.query(DEATHS_QUERY, {"code": code, "fights": [fight_id], "start": cursor, "end": end})
        events = data["reportData"]["report"]["events"]
        deaths.extend(events["data"])
        cursor = events["nextPageTimestamp"]
    return deaths


def time_curve(
    deaths: list[dict[str, Any]],
    bosses: list[tuple[float, int]],
    actors: dict[int, int],
    values: dict[int, int],
    base: int,
    start: float,
    end: float,
) -> list[float]:
    """Share of the run's duration at which each CURVE_PROGRESS point was reached."""
    moments = [(event["timestamp"], values.get(actors.get(event.get("targetID")), 0), 0) for event in deaths]
    moments += [(boss_end, 0, 1) for boss_end, _ in bosses]
    forces, kills, index = 0, 0, 0
    curve = []
    for moment, gained, killed in sorted(moments):
        forces += gained
        kills += killed
        progress = 0.5 * min(forces / base, 1) + 0.5 * kills / len(bosses)
        while index < len(CURVE_PROGRESS) and progress >= CURVE_PROGRESS[index]:
            curve.append(round(min((moment - start) / (end - start), 1), 4))
            index += 1
    return curve


def collect_tight(client: Client, args: argparse.Namespace, cache: dict[str, Any]) -> None:
    """Bronze keys made the timer with little to spare: the pace a key must hold.

    The API serves the fastest 1000 keys of a level, so they sit on its last
    pages and mostly on high levels. Levels above the band only add curves: the
    curve is a shape, and its forces values stay out of the start values.
    """
    levels = list(range(args.max_level, args.min_level - 1, -1)) + list(range(args.max_level + 1, TIGHT_MAX_LEVEL + 1))
    for encounter, (map_id, name) in SEASON_DUNGEONS[args.season].items():
        found = sum(1 for record in cache.values() if record.get("tight") and record.get("mapID") == map_id)
        for level in levels:
            for page in (LAST_RANKING_PAGE, LAST_RANKING_PAGE - 1):
                if found >= args.tight_runs:
                    break
                for row in fetch_rankings(client, encounter, level, page):
                    key = f"{row['report']['code']}:{row['report']['fightID']}"
                    if row.get("medal") != "bronze" or found >= args.tight_runs or cache.get(key, {}).get("tight"):
                        continue
                    record = cache.get(key, {})
                    if "curve" not in record:
                        try:
                            record = analyse_fight(client, *split_key(key), row["startTime"])
                        except (RuntimeError, urllib.error.URLError, KeyError, TypeError) as err:
                            print(f"  skipped run: {type(err).__name__}", flush=True)
                            continue
                    if "invalid" in record:
                        cache[key] = {**record, "mapID": map_id}
                        continue
                    record.update(mapID=map_id, tight=True)
                    cache[key] = record
                    found += 1
        print(f"{name}: {found} tight runs", flush=True)
        args.cache.write_text(json.dumps(cache), encoding="utf-8")


def split_key(key: str) -> tuple[str, int]:
    code, fight_id = key.split(":")
    return code, int(fight_id)


def aggregate_curves(args: argparse.Namespace, cache: dict[str, Any]) -> dict[int, dict[str, Any]]:
    # No age limit: the curve is a shape, and old dungeons see few barely timed keys.
    by_map: dict[int, list[list[float]]] = defaultdict(list)
    for record in cache.values():
        curve = record.get("curve")
        if record.get("tight") and curve and len(curve) == len(CURVE_PROGRESS):
            by_map[record["mapID"]].append(curve)
    result = {}
    for map_id, curves in by_map.items():
        if len(curves) < args.min_route_runs:
            continue
        times, previous = [], 0.0
        for column in zip(*curves):
            previous = max(previous, round(median(column), 4))
            times.append(previous)
        result[map_id] = {"times": times, "runs": len(curves)}
    return result


def render_time_lua(args: argparse.Namespace, data: dict[int, dict[str, Any]]) -> str:
    names = {map_id: name for map_id, name in SEASON_DUNGEONS[args.season].values()}
    today = dt.datetime.now(dt.timezone.utc).date().isoformat()
    progress = ", ".join(f"{value:g}" for value in CURVE_PROGRESS + [1])
    lines = [
        "local _, addonTable = ...",
        "",
        "addonTable = addonTable or {}",
        "",
        "-- GENERATED by sync_wcl_forces.py, do not edit by hand.",
        "-- Time curve for the time pace (game/isiLive_time_pace.lua): the share of a",
        "-- key's time at which it typically reaches each progress step, so a key on",
        "-- this curve finishes exactly on its time limit.",
        "--",
        f"-- Median of keys that barely made the timer, from public Warcraft Logs reports",
        f"-- as of {today}. The curve is a shape: the game scales it to the running key's",
        "-- time limit, so it holds for every key level.",
        "addonTable.TimeSeed = {",
        f"  {args.season} = {{",
        f"    progress = {{ {progress} }},",
    ]
    for map_id in sorted(data):
        times = ", ".join(f"{value:g}" for value in data[map_id]["times"] + [1])
        lines.append(f"    [{map_id}] = {{ -- {names[map_id]}")
        lines.append(f"      {times},")
        lines.append("    },")
    lines += ["  },", "}", ""]
    return "\n".join(lines)


def analyse_fight(client: Client, code: str, fight_id: int, ranking_start: float) -> dict[str, Any]:
    """Returns a run record; `invalid` names the reason a run cannot be used."""
    data = client.query(FIGHT_QUERY, {"code": code, "fights": [fight_id]})
    client.respect_limit(data["rateLimitData"])
    report = data["reportData"]["report"]
    fights = report["fights"] if report else None
    if not fights:
        return {"invalid": "no fight"}
    fight = fights[0]
    required = fight.get("countRequired") or 0
    reached = fight.get("countReached") or 0
    if not (fight.get("keystoneBonus") or 0) >= 1:
        return {"invalid": "not timed"}
    # A timed key has full forces, yet some deaths never reach the log. Percentages
    # are taken of what was logged, as long as nearly everything was.
    if required <= 0 or reached < required * MIN_LOGGED_SHARE or not fight.get("npcCountMap"):
        return {"invalid": "no forces data"}
    base = min(reached, required)

    bosses = sorted(
        (pull["endTime"], pull["encounterID"]) for pull in fight["dungeonPulls"] if pull["encounterID"] and pull["kill"]
    )
    if len({boss for _, boss in bosses}) != len(bosses) or not bosses:
        return {"invalid": "boss list"}

    actors = {npc["id"]: npc["gameID"] for npc in fight["enemyNPCs"]}
    values = {int(npc): count for npc, count in fight["npcCountMap"].items()}
    deaths = sorted(
        fetch_deaths(client, code, fight_id, fight["startTime"], fight["endTime"]), key=lambda event: event["timestamp"]
    )

    curve = time_curve(deaths, bosses, actors, values, base, fight["startTime"], fight["endTime"])
    total = 0
    position = 0
    checkpoints = []
    for boss_end, _ in bosses:
        while position < len(deaths) and deaths[position]["timestamp"] <= boss_end:
            total += values.get(actors.get(deaths[position].get("targetID")), 0)
            position += 1
        checkpoints.append(round(min(total / base * 100, 100), 2))
    for event in deaths[position:]:
        total += values.get(actors.get(event.get("targetID")), 0)
    # Logged forces stop at the requirement, so an overshooting sum is fine.
    if total != reached and not (reached == required and total >= required):
        return {"invalid": "forces sum"}
    return {
        "level": fight["keystoneLevel"],
        "order": [boss for _, boss in bosses],
        "checkpoints": checkpoints,
        "seenAt": ranking_start,
        "curve": curve,
    }


def collect(client: Client, args: argparse.Namespace, cache: dict[str, Any]) -> None:
    for encounter, (map_id, name) in SEASON_DUNGEONS[args.season].items():
        for level in range(args.min_level, args.max_level + 1):
            rows = [
                row
                for row in fetch_rankings(client, encounter, level)
                if f"{row['report']['code']}:{row['report']['fightID']}" not in cache
            ]
            added = 0
            for row in spread(rows, args.runs_per_level):
                code, fight_id = row["report"]["code"], row["report"]["fightID"]
                try:
                    record = analyse_fight(client, code, fight_id, row["startTime"])
                except (RuntimeError, urllib.error.URLError, KeyError, TypeError) as err:
                    print(f"  skipped run: {type(err).__name__}", flush=True)
                    continue
                record["mapID"] = map_id
                cache[f"{code}:{fight_id}"] = record
                added += "invalid" not in record
            print(f"{name} +{level}: {added} new valid", flush=True)
            args.cache.write_text(json.dumps(cache), encoding="utf-8")


def aggregate(args: argparse.Namespace, cache: dict[str, Any]) -> dict[int, dict[str, Any]]:
    oldest = (time.time() - args.max_age_days * 86400) * 1000
    by_map: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for record in cache.values():
        if "invalid" in record or record["seenAt"] < oldest:
            continue
        if args.min_level <= record["level"] <= args.max_level:
            by_map[record["mapID"]].append(record)

    result = {}
    for map_id, runs in by_map.items():
        counts = Counter(tuple(run["order"]) for run in runs)
        # Encounter IDs do not follow the boss order. The criteria index is the
        # position in the most common kill order, which holds for every route
        # measured in game; a wrong guess only keeps a route from fitting.
        common = counts.most_common(1)[0][0]
        rank = {boss: i + 1 for i, boss in enumerate(common)}
        routes = {}
        for order, count in counts.items():
            if count < args.min_route_runs:
                continue
            if set(order) != set(common):
                continue
            matching = [run["checkpoints"] for run in runs if tuple(run["order"]) == order]
            checkpoints = [round(median(column), 1) for column in zip(*matching)]
            routes["-".join(str(rank[boss]) for boss in order)] = {
                "order": [rank[boss] for boss in order],
                "checkpoints": checkpoints,
                "leanScore": round(sum(checkpoints), 1),
                "runs": count,
            }
        result[map_id] = {"runs": len(runs), "routes": routes}
    return result


def render_lua(args: argparse.Namespace, data: dict[int, dict[str, Any]]) -> str:
    names = {map_id: name for map_id, name in SEASON_DUNGEONS[args.season].values()}
    today = dt.datetime.now(dt.timezone.utc).date().isoformat()
    lines = [
        "local _, addonTable = ...",
        "",
        "addonTable = addonTable or {}",
        "",
        "-- GENERATED by sync_wcl_forces.py, do not edit by hand.",
        "-- Start values for the forces pace, used for a dungeon until the player has a",
        "-- learned route that fits the run (game/isiLive_forces_pace.lua).",
        "--",
        f"-- Median enemy-forces percentage at each boss kill of timed +{args.min_level} to",
        f"-- +{args.max_level} keys from public Warcraft Logs reports, as of {today}. Do not fill",
        "-- this table from another addon: external route tables are not ours to",
        "-- redistribute.",
        "--",
        "-- Same shape as IsiLiveDB.forcesPace[seasonID][mapID].routes, and read through",
        "-- the same validation. A season without an entry shows learned values only.",
        "addonTable.ForcesSeed = {",
        f"  {args.season} = {{",
    ]
    for map_id in sorted(data):
        routes = data[map_id]["routes"]
        if not routes:
            continue
        lines.append(f"    [{map_id}] = {{ -- {names[map_id]}")
        lines.append("      routes = {")
        for key in sorted(routes):
            route = routes[key]
            order = ", ".join(str(index) for index in route["order"])
            checkpoints = ", ".join(f"{value:g}" for value in route["checkpoints"])
            lines.append(f'        ["{key}"] = {{')
            lines.append(f"          order = {{ {order} }},")
            lines.append(f"          checkpoints = {{ {checkpoints} }},")
            lines.append(f"          leanScore = {route['leanScore']:g},")
            lines.append("        },")
        lines.append("      },")
        lines.append("    },")
    lines += ["  },", "}", ""]
    return "\n".join(lines)


def read_existing_routes(path: Path) -> dict[tuple[int, str], list[float]]:
    """Checkpoints of the current seed file by (map ID, route key)."""
    if not path.exists():
        return {}
    routes = {}
    map_id = None
    route_key = None
    for line in path.read_text(encoding="utf-8").splitlines():
        map_match = re.match(r"\s*\[(\d+)\] = \{", line)
        route_match = re.match(r'\s*\["([\d-]+)"\] = \{', line)
        values_match = re.match(r"\s*checkpoints = \{ ([\d., ]+) \}", line)
        if map_match:
            map_id = int(map_match.group(1))
        elif route_match:
            route_key = route_match.group(1)
        elif values_match and map_id is not None and route_key is not None:
            routes[(map_id, route_key)] = [float(value) for value in values_match.group(1).split(",")]
    return routes


def check_seeds(args: argparse.Namespace, data: dict[int, dict[str, Any]], curves: dict[int, dict[str, Any]]) -> list[str]:
    """Reasons not to publish this result; the run then fails and writes nothing."""
    problems = []
    existing = read_existing_routes(args.out) if args.out else {}
    for map_id, name in SEASON_DUNGEONS[args.season].values():
        routes = data.get(map_id, {}).get("routes")
        if not routes:
            problems.append(f"{name}: no route")
            continue
        if map_id not in curves:
            problems.append(f"{name}: no time curve")
        for key, route in routes.items():
            checkpoints = route["checkpoints"]
            if checkpoints != sorted(checkpoints) or checkpoints[-1] < MIN_FINAL_CHECKPOINT:
                problems.append(f"{name} {key}: implausible checkpoints {checkpoints}")
            before = existing.get((map_id, key))
            if before and len(before) == len(checkpoints):
                shift = max(abs(new - old) for new, old in zip(checkpoints, before))
                if shift > MAX_CHECKPOINT_SHIFT:
                    problems.append(f"{name} {key}: moved {shift:.1f} points, {before} -> {checkpoints}")
    return problems


def main() -> int:
    args = parse_args()
    args.cache.parent.mkdir(parents=True, exist_ok=True)
    cache = json.loads(args.cache.read_text(encoding="utf-8")) if args.cache.exists() else {}
    client = Client(args.point_reserve)
    if args.runs_per_level > 0:
        collect(client, args, cache)
    collect_tight(client, args, cache)

    reasons = Counter(record["invalid"] for record in cache.values() if "invalid" in record)
    print(f"runs cached: {len(cache)}, rejected: {dict(reasons)}")
    data = aggregate(args, cache)
    names = {map_id: name for map_id, name in SEASON_DUNGEONS[args.season].values()}
    for map_id in sorted(data):
        print(f"{names[map_id]}: {data[map_id]['runs']} valid runs")
        for key, route in sorted(data[map_id]["routes"].items(), key=lambda item: -item[1]["runs"]):
            print(f"  {key}: {route['checkpoints']} ({route['runs']} runs)")
    curves = aggregate_curves(args, cache)
    for map_id in sorted(curves):
        print(f"{names[map_id]}: curve from {curves[map_id]['runs']} runs: {curves[map_id]['times']}")
    problems = check_seeds(args, data, curves)
    if problems:
        print("not publishing:", *problems, sep="\n  ")
        return 1
    if args.out:
        args.out.write_text(render_lua(args, data), encoding="utf-8", newline="\n")
        print(f"wrote {args.out}")
    if args.time_out:
        args.time_out.write_text(render_time_lua(args, curves), encoding="utf-8", newline="\n")
        print(f"wrote {args.time_out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
