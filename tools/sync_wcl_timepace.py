#!/usr/bin/env python3
"""Fetch a Warcraft Logs Mythic+ TimePace sample snapshot.

This is an inspection/extraction tool, not runtime addon code. It deliberately
writes artifacts instead of touching the packaged Lua data file so we can first
verify which Warcraft Logs fields are available and how many +12 intime samples
exist per dungeon/key level.
"""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from pathlib import Path
from statistics import median
from typing import Any


TOKEN_URL = "https://www.warcraftlogs.com/oauth/token"
GRAPHQL_URL = "https://www.warcraftlogs.com/api/v2/client"


def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fetch Warcraft Logs +12 intime M+ samples for TimePace.")
    parser.add_argument("--window-days", type=int, default=10)
    parser.add_argument("--min-key-level", type=int, default=12)
    parser.add_argument("--min-samples", type=int, default=30)
    parser.add_argument("--report-page-limit", type=int, default=20)
    parser.add_argument("--report-limit", type=int, default=100)
    parser.add_argument("--report-code", action="append", default=[])
    parser.add_argument("--game-zone-id", type=int, default=None)
    parser.add_argument("--out-dir", default="tools/cache/wcl_timepace")
    parser.add_argument("--token-url", default=TOKEN_URL)
    parser.add_argument("--graphql-url", default=GRAPHQL_URL)
    parser.add_argument("--client-id-env", default="WARCRAFTLOGS_CLIENT_ID")
    parser.add_argument("--client-secret-env", default="WARCRAFTLOGS_CLIENT_SECRET")
    return parser.parse_args()


def http_json(url: str, *, method: str = "GET", headers: dict[str, str] | None = None, data: Any = None) -> Any:
    encoded = None
    if data is not None:
        if isinstance(data, bytes):
            encoded = data
        else:
            encoded = json.dumps(data, separators=(",", ":")).encode("utf-8")
    req = urllib.request.Request(url, data=encoded, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            raw = response.read().decode("utf-8")
            return json.loads(raw)
    except urllib.error.HTTPError as err:
        body = err.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {err.code} for {url}: {body[:1000]}") from err


def get_access_token(args: argparse.Namespace) -> str:
    client_id = os.getenv(args.client_id_env)
    client_secret = os.getenv(args.client_secret_env)
    if not client_id or not client_secret:
        raise RuntimeError(
            f"missing Warcraft Logs credentials: set {args.client_id_env} and {args.client_secret_env}"
        )

    auth = base64.b64encode(f"{client_id}:{client_secret}".encode("utf-8")).decode("ascii")
    body = urllib.parse.urlencode({"grant_type": "client_credentials"}).encode("ascii")
    payload = http_json(
        args.token_url,
        method="POST",
        headers={
            "Authorization": f"Basic {auth}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        data=body,
    )
    token = payload.get("access_token")
    if not token:
        raise RuntimeError("Warcraft Logs token response did not contain access_token")
    return str(token)


def graphql(args: argparse.Namespace, token: str, query: str, variables: dict[str, Any] | None = None) -> Any:
    payload = http_json(
        args.graphql_url,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        data={"query": query, "variables": variables or {}},
    )
    if payload.get("errors"):
        raise RuntimeError(json.dumps(payload["errors"], indent=2, ensure_ascii=False))
    return payload.get("data")


INTROSPECTION_QUERY = """
query IntrospectTimePace {
  reportType: __type(name: "Report") {
    fields { name }
  }
  reportFightType: __type(name: "ReportFight") {
    fields { name }
  }
  reportDataType: __type(name: "ReportData") {
    fields { name }
  }
  rateLimitData {
    limitPerHour
    pointsSpentThisHour
    pointsResetIn
  }
}
"""


def field_names(type_info: dict[str, Any] | None) -> set[str]:
    return {str(field.get("name")) for field in (type_info or {}).get("fields") or [] if field.get("name")}


def build_fights_selection(fight_fields: set[str]) -> str:
    wanted = [
        "id",
        "name",
        "startTime",
        "endTime",
        "kill",
        "keystoneLevel",
        "keystoneBonus",
        "difficulty",
        "encounterID",
        "bossPercentage",
        "fightPercentage",
    ]
    selected = [field for field in wanted if field in fight_fields]
    if "id" not in selected:
        selected.insert(0, "id")
    return "\n          ".join(selected)


def fetch_reports(
    args: argparse.Namespace,
    token: str,
    start_ms: int,
    end_ms: int,
    report_fields: set[str],
    fight_fields: set[str],
) -> list[dict[str, Any]]:
    fights_selection = build_fights_selection(fight_fields)
    report_selection = ["code", "title", "startTime", "endTime"]
    report_selection = [field for field in report_selection if field in report_fields]
    report_selection.append(f"fights {{\n          {fights_selection}\n        }}")

    has_zone_filter = args.game_zone_id is not None
    zone_arg = "\n          gameZoneID: $gameZoneID" if has_zone_filter else ""
    zone_variable = ", $gameZoneID: Int" if has_zone_filter else ""
    query = (
        "query TimePaceReports($startTime: Float!, $endTime: Float!, $page: Int!, "
        "$limit: Int!"
        + zone_variable
        + ") {\n"
        "  reportData {\n"
        "    reports(startTime: $startTime, endTime: $endTime, page: $page, limit: $limit"
        + zone_arg
        + ") {\n"
        "      current_page\n"
        "      last_page\n"
        "      total\n"
        "      data {\n        "
        + "\n        ".join(report_selection)
        + "\n      }\n"
        "    }\n"
        "  }\n"
        "}\n"
    )

    reports: list[dict[str, Any]] = []
    for page in range(1, args.report_page_limit + 1):
        data = graphql(
            args,
            token,
            query,
            {
                "startTime": start_ms,
                "endTime": end_ms,
                "page": page,
                "limit": args.report_limit,
                "gameZoneID": args.game_zone_id,
            },
        )
        page_data = (((data or {}).get("reportData") or {}).get("reports") or {})
        reports.extend(page_data.get("data") or [])
        last_page = int(page_data.get("last_page") or page)
        if page >= last_page:
            break
    return reports


def fetch_report_codes(
    args: argparse.Namespace,
    token: str,
    report_codes: list[str],
    report_fields: set[str],
    fight_fields: set[str],
) -> list[dict[str, Any]]:
    fights_selection = build_fights_selection(fight_fields)
    report_selection = ["code", "title", "startTime", "endTime"]
    report_selection = [field for field in report_selection if field in report_fields]
    report_selection.append(f"fights {{\n          {fights_selection}\n        }}")
    query = (
        "query TimePaceReport($code: String!) {\n"
        "  reportData {\n"
        "    report(code: $code) {\n      "
        + "\n      ".join(report_selection)
        + "\n    }\n"
        "  }\n"
        "}\n"
    )

    reports: list[dict[str, Any]] = []
    for raw_code in report_codes:
        code = str(raw_code or "").strip()
        if not code:
            continue
        data = graphql(args, token, query, {"code": code})
        report = ((data or {}).get("reportData") or {}).get("report")
        if report:
            reports.append(report)
    return reports


def as_number(value: Any) -> float | None:
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return None
    return None


def is_intime_fight(fight: dict[str, Any]) -> bool:
    bonus = as_number(fight.get("keystoneBonus"))
    if bonus is not None:
        return bonus > 0
    kill = fight.get("kill")
    if isinstance(kill, bool):
        return kill
    return False


def collect_samples(reports: list[dict[str, Any]], min_key_level: int) -> tuple[list[dict[str, Any]], dict[str, int]]:
    samples: list[dict[str, Any]] = []
    counters = defaultdict(int)
    for report in reports:
        counters["reports"] += 1
        for fight in report.get("fights") or []:
            counters["fights"] += 1
            key_level = as_number(fight.get("keystoneLevel"))
            if key_level is None:
                counters["skip_no_key_level"] += 1
                continue
            if key_level < min_key_level:
                counters["skip_low_key"] += 1
                continue
            if not is_intime_fight(fight):
                counters["skip_not_intime"] += 1
                continue
            start_time = as_number(fight.get("startTime"))
            end_time = as_number(fight.get("endTime"))
            if start_time is None or end_time is None or end_time <= start_time:
                counters["skip_bad_duration"] += 1
                continue
            duration_seconds = (end_time - start_time) / 1000.0
            samples.append(
                {
                    "reportCode": report.get("code"),
                    "reportTitle": report.get("title"),
                    "fightID": fight.get("id"),
                    "fightName": fight.get("name"),
                    "keyLevel": int(key_level),
                    "durationSeconds": round(duration_seconds, 3),
                    "keystoneBonus": fight.get("keystoneBonus"),
                    "difficulty": fight.get("difficulty"),
                    "encounterID": fight.get("encounterID"),
                    "reportStartTime": report.get("startTime"),
                    "reportEndTime": report.get("endTime"),
                }
            )
            counters["samples"] += 1
    return samples, dict(counters)


def aggregate(samples: list[dict[str, Any]], min_samples: int) -> dict[str, Any]:
    by_name_level: dict[str, dict[str, list[float]]] = defaultdict(lambda: defaultdict(list))
    for sample in samples:
        name = str(sample.get("fightName") or "unknown")
        level = str(sample["keyLevel"])
        by_name_level[name][level].append(float(sample["durationSeconds"]))

    profiles: dict[str, Any] = {}
    for name in sorted(by_name_level):
        levels: dict[str, Any] = {}
        for level in sorted(by_name_level[name], key=lambda x: int(x)):
            durations = sorted(by_name_level[name][level])
            if len(durations) < min_samples:
                continue
            levels[level] = {
                "samples": len(durations),
                "medianDurationSeconds": round(float(median(durations)), 3),
                "minDurationSeconds": round(durations[0], 3),
                "maxDurationSeconds": round(durations[-1], 3),
            }
        if levels:
            profiles[name] = levels
    return profiles


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    out_dir = Path(args.out_dir)
    now = utc_now()
    start = now - dt.timedelta(days=args.window_days)
    start_ms = int(start.timestamp() * 1000)
    end_ms = int(now.timestamp() * 1000)

    try:
        token = get_access_token(args)
        introspection = graphql(args, token, INTROSPECTION_QUERY)
        report_fields = field_names((introspection or {}).get("reportType"))
        fight_fields = field_names((introspection or {}).get("reportFightType"))
        report_codes = [code for item in args.report_code for code in str(item).split(",")]
        if report_codes:
            reports = fetch_report_codes(args, token, report_codes, report_fields, fight_fields)
        else:
            reports = fetch_reports(args, token, start_ms, end_ms, report_fields, fight_fields)
        samples, counters = collect_samples(reports, args.min_key_level)
        profiles = aggregate(samples, args.min_samples)
    except Exception as err:  # noqa: BLE001 - CLI must surface API/schema errors as artifacts-friendly text.
        sys.stderr.write(f"sync_wcl_timepace: {err}\n")
        return 2

    snapshot = {
        "tool": "tools/sync_wcl_timepace.py",
        "source": "warcraftlogs",
        "generatedAt": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "windowDays": args.window_days,
        "windowStart": start.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "windowEnd": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "minKeyLevel": args.min_key_level,
        "minSamples": args.min_samples,
        "gameZoneID": args.game_zone_id,
        "reportCodes": [code for item in args.report_code for code in str(item).split(",") if code.strip()],
        "counters": counters,
        "profiles": profiles,
        "samples": samples,
    }

    schema = {
        "rateLimitData": (introspection or {}).get("rateLimitData"),
        "reportFields": sorted(report_fields),
        "reportFightFields": sorted(fight_fields),
        "reportDataFields": sorted(field_names((introspection or {}).get("reportDataType"))),
    }

    write_json(out_dir / "schema.json", schema)
    write_json(out_dir / "snapshot.json", snapshot)
    write_json(out_dir / "samples.json", samples)
    write_json(out_dir / "profiles.json", profiles)

    print(
        "sync_wcl_timepace: "
        f"reports={counters.get('reports', 0)} "
        f"fights={counters.get('fights', 0)} "
        f"samples={counters.get('samples', 0)} "
        f"profiles={sum(len(levels) for levels in profiles.values())}"
    )
    print(f"sync_wcl_timepace: wrote {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
