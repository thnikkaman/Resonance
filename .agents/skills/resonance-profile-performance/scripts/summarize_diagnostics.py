#!/usr/bin/env python3
"""Summarize Resonance diagnostics and block obvious privacy regressions."""

from __future__ import annotations

import argparse
import json
import math
import re
import statistics
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Sequence

SCHEMA_VERSION = 1
TIMESTAMP_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})$")
DETAIL_KEY_RE = re.compile(r"(?:^|\s)([A-Za-z_][\w.-]*)=")
URL_RE = re.compile(r"(?i)\b(?:https?|file|ftp)://")
ABSOLUTE_PATH_RE = re.compile(r"(?:^|\s)(?:/Users/|/private/|/var/|/tmp/|[A-Za-z]:\\)")
EMAIL_RE = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
IPV4_RE = re.compile(r"(?<!\d)(?:\d{1,3}\.){3}\d{1,3}(?!\d)")
AUTH_QUERY_RE = re.compile(r"(?i)(?:^|[?&\s])(u|p|t|s|token|password|credential|api[_-]?key)=")
LONG_SECRET_RE = re.compile(r"\b[A-Za-z0-9+/=_-]{48,}\b")
DURATION_KEYS = {"duration_ms", "elapsed_ms", "latency_ms", "wall_ms", "startup_ms"}

SENSITIVE_KEY_FRAGMENTS = {
    "password",
    "passwd",
    "credential",
    "secret",
    "token",
    "authorization",
    "cookie",
    "username",
    "email",
    "serverurl",
    "server_url",
    "url",
    "hostname",
    "host",
    "query",
    "salt",
    "artist",
    "album",
    "title",
    "trackname",
    "track_name",
    "filepath",
    "file_path",
    "filename",
}

SAFE_LOCATION_VALUES = {
    "Documents/Resonance-Diagnostics.log",
    "documents-log",
    "temporary",
}


@dataclass
class ParsedLine:
    line_number: int
    timestamp: datetime
    event: str
    details: dict[str, str]


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Summarize a Resonance diagnostics log.")
    parser.add_argument("log", type=Path, help="Copied Resonance-Diagnostics.log")
    parser.add_argument("--out", type=Path, required=True, help="JSON summary path")
    parser.add_argument("--top", type=int, default=50, help="Maximum event rows in the summary")
    parser.add_argument(
        "--no-fail-on-privacy",
        action="store_true",
        help="Return success while still recording privacy warnings",
    )
    return parser.parse_args(argv)


def parse_timestamp(value: str) -> datetime:
    if not TIMESTAMP_RE.match(value):
        raise ValueError("invalid ISO-8601 timestamp")
    normalized = value.replace("Z", "+00:00")
    parsed = datetime.fromisoformat(normalized)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def parse_details(raw: str) -> dict[str, str]:
    matches = list(DETAIL_KEY_RE.finditer(raw))
    details: dict[str, str] = {}
    for index, match in enumerate(matches):
        key = match.group(1)
        value_start = match.end()
        value_end = matches[index + 1].start() if index + 1 < len(matches) else len(raw)
        details[key] = raw[value_start:value_end].strip()
    return details


def parse_line(line_number: int, raw: str) -> ParsedLine:
    stripped = raw.strip()
    if not stripped:
        raise ValueError("empty")
    fields = stripped.split(maxsplit=2)
    if len(fields) < 2:
        raise ValueError("expected timestamp and event")
    timestamp = parse_timestamp(fields[0])
    event = fields[1]
    if not re.fullmatch(r"[A-Za-z0-9_.:-]+", event):
        raise ValueError("event name contains unsupported characters")
    details = parse_details(fields[2]) if len(fields) == 3 else {}
    return ParsedLine(line_number=line_number, timestamp=timestamp, event=event, details=details)


def normalized_key(key: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", key.lower()).strip("_")


def sensitive_key_reason(key: str, value: str) -> str | None:
    normalized = normalized_key(key)
    compact = normalized.replace("_", "")
    if normalized in {"track_count", "album_count", "artist_count", "file_count", "byte_count", "bytes", "file_extension", "extension"}:
        return None
    if normalized == "location":
        return None if value in SAFE_LOCATION_VALUES else "non-coarse location field"
    for fragment in SENSITIVE_KEY_FRAGMENTS:
        fragment_normalized = fragment.replace("_", "")
        if fragment in normalized or fragment_normalized in compact:
            return f"sensitive detail key: {key}"
    if normalized == "path" or normalized.endswith("_path"):
        return f"path-like detail key: {key}"
    return None


def privacy_value_reason(value: str) -> str | None:
    if URL_RE.search(value):
        return "URL-like value"
    if ABSOLUTE_PATH_RE.search(value):
        return "absolute path-like value"
    if EMAIL_RE.search(value):
        return "email-like value"
    if AUTH_QUERY_RE.search(value):
        return "authentication query-like value"
    if IPV4_RE.search(value):
        return "IP address-like value"
    if LONG_SECRET_RE.search(value):
        return "long token-like value"
    return None


def percentile(values: Sequence[float], fraction: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    position = (len(ordered) - 1) * fraction
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    weight = position - lower
    return ordered[lower] * (1.0 - weight) + ordered[upper] * weight


def duration_summary(values: Sequence[float]) -> dict[str, float | int | None]:
    if not values:
        return {
            "count": 0,
            "minimum_ms": None,
            "median_ms": None,
            "p95_ms": None,
            "maximum_ms": None,
            "mean_ms": None,
        }
    return {
        "count": len(values),
        "minimum_ms": round(min(values), 3),
        "median_ms": round(statistics.median(values), 3),
        "p95_ms": round(percentile(values, 0.95) or 0.0, 3),
        "maximum_ms": round(max(values), 3),
        "mean_ms": round(statistics.fmean(values), 3),
    }


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    log_path = args.log.expanduser().resolve()
    if not log_path.is_file():
        print(f"error: diagnostics log does not exist: {log_path}", file=sys.stderr)
        return 2
    if args.top < 1:
        print("error: --top must be positive", file=sys.stderr)
        return 2

    parsed: list[ParsedLine] = []
    parse_errors: list[dict[str, object]] = []
    privacy_warnings: list[dict[str, object]] = []

    with log_path.open("r", encoding="utf-8", errors="replace") as handle:
        for line_number, raw in enumerate(handle, start=1):
            if not raw.strip():
                continue
            try:
                entry = parse_line(line_number, raw)
            except ValueError as exc:
                parse_errors.append({"line": line_number, "reason": str(exc)})
                continue
            parsed.append(entry)
            for key, value in entry.details.items():
                reason = sensitive_key_reason(key, value)
                if reason is None:
                    reason = privacy_value_reason(value)
                if reason is not None:
                    privacy_warnings.append(
                        {
                            "line": line_number,
                            "event": entry.event,
                            "key": key,
                            "reason": reason,
                        }
                    )

    event_counts = Counter(entry.event for entry in parsed)
    detail_keys = Counter(key for entry in parsed for key in entry.details)
    explicit_durations: dict[str, list[float]] = defaultdict(list)
    paired_durations: dict[str, list[float]] = defaultdict(list)
    open_intervals: dict[str, list[datetime]] = defaultdict(list)
    unmatched_end_events: Counter[str] = Counter()

    for entry in parsed:
        for key, value in entry.details.items():
            if normalized_key(key) in DURATION_KEYS or normalized_key(key).endswith("_duration_ms"):
                try:
                    number = float(value)
                except ValueError:
                    continue
                if math.isfinite(number) and number >= 0:
                    explicit_durations[entry.event].append(number)
        if entry.event.endswith(".begin"):
            open_intervals[entry.event[: -len(".begin")]].append(entry.timestamp)
        elif entry.event.endswith(".end"):
            prefix = entry.event[: -len(".end")]
            if open_intervals[prefix]:
                started = open_intervals[prefix].pop()
                delta_ms = (entry.timestamp - started).total_seconds() * 1000.0
                if delta_ms >= 0:
                    paired_durations[prefix].append(delta_ms)
            else:
                unmatched_end_events[prefix] += 1

    unmatched_begin_events = {
        prefix: len(starts) for prefix, starts in sorted(open_intervals.items()) if starts
    }
    first_timestamp = min((entry.timestamp for entry in parsed), default=None)
    last_timestamp = max((entry.timestamp for entry in parsed), default=None)
    event_rows = [
        {"event": event, "count": count}
        for event, count in event_counts.most_common(args.top)
    ]
    payload = {
        "schema_version": SCHEMA_VERSION,
        "status": "fail" if privacy_warnings else "pass",
        "source": {
            "name": log_path.name,
            "bytes": log_path.stat().st_size,
        },
        "summary": {
            "parsed_lines": len(parsed),
            "parse_error_count": len(parse_errors),
            "privacy_warning_count": len(privacy_warnings),
            "unique_events": len(event_counts),
            "first_timestamp": first_timestamp.isoformat() if first_timestamp else None,
            "last_timestamp": last_timestamp.isoformat() if last_timestamp else None,
            "span_ms": round((last_timestamp - first_timestamp).total_seconds() * 1000.0, 3)
            if first_timestamp and last_timestamp
            else None,
        },
        "privacy": {
            "ok": not privacy_warnings,
            "warnings": privacy_warnings,
            "policy": "No media names, filesystem paths, URLs/hosts, credentials, usernames, raw queries, or token-like values.",
        },
        "parse_errors": parse_errors,
        "events": event_rows,
        "detail_keys": [
            {"key": key, "count": count}
            for key, count in detail_keys.most_common(args.top)
        ],
        "explicit_duration_ms": {
            event: duration_summary(values)
            for event, values in sorted(explicit_durations.items())
        },
        "paired_begin_end_duration_ms": {
            event: duration_summary(values)
            for event, values in sorted(paired_durations.items())
        },
        "unmatched_begin_events": unmatched_begin_events,
        "unmatched_end_events": dict(sorted(unmatched_end_events.items())),
    }
    write_json(args.out, payload)

    print(
        f"Parsed {len(parsed)} diagnostics events across {len(event_counts)} names; "
        f"privacy warnings={len(privacy_warnings)}."
    )
    print(f"Report: {args.out}")
    if privacy_warnings and not args.no_fail_on_privacy:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
