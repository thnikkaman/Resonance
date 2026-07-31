#!/usr/bin/env python3
"""Summarize, compare, and privacy-audit Resonance diagnostics logs."""

from __future__ import annotations

import argparse
import bisect
import json
import math
import random
import re
import statistics
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable, Sequence

KEY_MARKER = re.compile(r"(?:^| )([A-Za-z][A-Za-z0-9_.-]*)=")
SENSITIVE_PATTERNS = {
    "url": re.compile(r"(?:https?|file)://", re.IGNORECASE),
    "absolute_path": re.compile(r"(?:/Users/|/private/|/var/mobile/|[A-Za-z]:\\)"),
    "credential": re.compile(
        r"(?:password|passwd|token|secret|credential|authorization|username|user)\s*=",
        re.IGNORECASE,
    ),
    "email": re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.IGNORECASE),
}


@dataclass(frozen=True)
class Record:
    timestamp: datetime
    timestamp_text: str
    event: str
    details: dict[str, str]
    line_number: int
    raw: str


def parse_details(text: str) -> dict[str, str]:
    matches = list(KEY_MARKER.finditer(text))
    details: dict[str, str] = {}
    for index, match in enumerate(matches):
        key = match.group(1)
        value_start = match.end()
        value_end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        details[key] = text[value_start:value_end].strip()
    return details


def parse_line(line: str, line_number: int) -> Record | None:
    stripped = line.strip()
    if not stripped:
        return None
    parts = stripped.split(" ", 2)
    if len(parts) < 2:
        raise ValueError(f"line {line_number}: expected timestamp and event")
    timestamp_text, event = parts[0], parts[1]
    try:
        timestamp = datetime.fromisoformat(timestamp_text.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError(
            f"line {line_number}: invalid ISO-8601 timestamp {timestamp_text!r}"
        ) from exc
    details = parse_details(parts[2] if len(parts) == 3 else "")
    return Record(timestamp, timestamp_text, event, details, line_number, stripped)


def read_records(path: Path) -> list[Record]:
    records: list[Record] = []
    for line_number, line in enumerate(
        path.read_text(encoding="utf-8", errors="replace").splitlines(), 1
    ):
        try:
            record = parse_line(line, line_number)
        except ValueError as exc:
            print(f"warning: {path}: {exc}", file=sys.stderr)
            continue
        if record is not None:
            records.append(record)
    return records


def filter_records(records: list[Record], include: str | None) -> list[Record]:
    if not include:
        return records
    pattern = re.compile(include)
    return [record for record in records if pattern.search(record.event)]


def numeric_value(value: str) -> float | None:
    try:
        number = float(value)
    except ValueError:
        return None
    return number if math.isfinite(number) else None


def percentile(values: Sequence[float], fraction: float) -> float:
    if not values:
        raise ValueError("percentile requires values")
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    position = (len(ordered) - 1) * fraction
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    weight = position - lower
    return ordered[lower] * (1 - weight) + ordered[upper] * weight


def distribution(values: Sequence[float]) -> dict[str, float | int]:
    if not values:
        raise ValueError("distribution requires values")
    return {
        "count": len(values),
        "min": min(values),
        "mean": statistics.fmean(values),
        "stdev": statistics.stdev(values) if len(values) > 1 else 0.0,
        "p50": percentile(values, 0.50),
        "p95": percentile(values, 0.95),
        "p99": percentile(values, 0.99),
        "max": max(values),
    }


def timing_fields(records: Iterable[Record]) -> dict[tuple[str, str], list[float]]:
    values: dict[tuple[str, str], list[float]] = defaultdict(list)
    for record in records:
        for key, raw_value in record.details.items():
            if not key.lower().endswith("ms"):
                continue
            parsed = numeric_value(raw_value)
            if parsed is not None:
                values[(record.event, key)].append(parsed)
    return values


def summarize(records: list[Record]) -> dict[str, object]:
    event_counts = Counter(record.event for record in records)
    elapsed_seconds = 0.0
    if len(records) >= 2:
        elapsed_seconds = max(0.0, (records[-1].timestamp - records[0].timestamp).total_seconds())
    event_rates = {
        event: (count / elapsed_seconds * 60.0 if elapsed_seconds > 0 else None)
        for event, count in event_counts.most_common()
    }
    timings = []
    for (event, field), values in sorted(timing_fields(records).items()):
        timings.append({"event": event, "field": field, **distribution(values)})
    return {
        "records": len(records),
        "first_timestamp": records[0].timestamp_text if records else None,
        "last_timestamp": records[-1].timestamp_text if records else None,
        "elapsed_seconds": elapsed_seconds,
        "event_counts": dict(event_counts.most_common()),
        "event_rates_per_minute": event_rates,
        "timings_ms": timings,
    }


def percent_change(before: float | None, after: float | None) -> float | None:
    if before in (None, 0) or after is None:
        return None
    return ((after - before) / before) * 100.0


def cliffs_delta(before: Sequence[float], after: Sequence[float]) -> float | None:
    if not before or not after:
        return None
    ordered_before = sorted(before)
    greater = 0
    less = 0
    for value in after:
        less += bisect.bisect_left(ordered_before, value)
        greater += len(ordered_before) - bisect.bisect_right(ordered_before, value)
    # Positive means after values tend to be larger/slower.
    return (less - greater) / (len(before) * len(after))


def bootstrap_median_delta_ci(
    before: Sequence[float],
    after: Sequence[float],
    iterations: int,
    seed: int,
) -> tuple[float, float] | None:
    if not before or not after or iterations <= 0:
        return None
    rng = random.Random(seed)
    deltas: list[float] = []
    for _ in range(iterations):
        before_sample = [before[rng.randrange(len(before))] for _ in before]
        after_sample = [after[rng.randrange(len(after))] for _ in after]
        deltas.append(statistics.median(after_sample) - statistics.median(before_sample))
    return percentile(deltas, 0.025), percentile(deltas, 0.975)


def timing_status(
    before_count: int,
    after_count: int,
    median_change_percent: float | None,
    ci: tuple[float, float] | None,
    min_samples: int,
    threshold: float,
) -> str:
    if before_count == 0 or after_count == 0:
        return "missing"
    if min(before_count, after_count) < min_samples:
        return "insufficient"
    if median_change_percent is None or ci is None:
        return "inconclusive"
    low, high = ci
    if median_change_percent >= threshold and low > 0:
        return "regressed"
    if median_change_percent <= -threshold and high < 0:
        return "improved"
    return "inconclusive"


def compare(
    before: list[Record],
    after: list[Record],
    min_samples: int = 5,
    regression_threshold: float = 10.0,
    bootstrap_iterations: int = 2000,
    seed: int = 20260730,
) -> dict[str, object]:
    before_fields = timing_fields(before)
    after_fields = timing_fields(after)
    timings: list[dict[str, object]] = []
    for index, key in enumerate(sorted(set(before_fields) | set(after_fields))):
        before_values = before_fields.get(key, [])
        after_values = after_fields.get(key, [])
        before_stats = distribution(before_values) if before_values else None
        after_stats = distribution(after_values) if after_values else None
        before_median = float(before_stats["p50"]) if before_stats else None
        after_median = float(after_stats["p50"]) if after_stats else None
        ci = bootstrap_median_delta_ci(
            before_values,
            after_values,
            bootstrap_iterations,
            seed + index,
        )
        median_change = percent_change(before_median, after_median)
        status = timing_status(
            len(before_values),
            len(after_values),
            median_change,
            ci,
            min_samples,
            regression_threshold,
        )
        timings.append(
            {
                "event": key[0],
                "field": key[1],
                "before": before_stats,
                "after": after_stats,
                "median_change_percent": median_change,
                "p95_change_percent": percent_change(
                    float(before_stats["p95"]) if before_stats else None,
                    float(after_stats["p95"]) if after_stats else None,
                ),
                "p99_change_percent": percent_change(
                    float(before_stats["p99"]) if before_stats else None,
                    float(after_stats["p99"]) if after_stats else None,
                ),
                "median_delta_ci95_ms": list(ci) if ci else None,
                "cliffs_delta": cliffs_delta(before_values, after_values),
                "status": status,
            }
        )

    before_counts = Counter(record.event for record in before)
    after_counts = Counter(record.event for record in after)
    event_counts = []
    for event in sorted(set(before_counts) | set(after_counts)):
        before_count = before_counts[event]
        after_count = after_counts[event]
        event_counts.append(
            {
                "event": event,
                "before": before_count,
                "after": after_count,
                "delta": after_count - before_count,
                "change_percent": percent_change(float(before_count), float(after_count)),
            }
        )

    return {
        "before_records": len(before),
        "after_records": len(after),
        "min_samples": min_samples,
        "regression_threshold_percent": regression_threshold,
        "bootstrap_iterations": bootstrap_iterations,
        "timings_ms": timings,
        "event_counts": event_counts,
        "regression_count": sum(1 for row in timings if row["status"] == "regressed"),
        "improvement_count": sum(1 for row in timings if row["status"] == "improved"),
    }


def fmt(value: object, digits: int = 2) -> str:
    if value is None:
        return "n/a"
    if isinstance(value, (int, float)):
        return f"{value:.{digits}f}"
    return str(value)


def format_summary_markdown(data: dict[str, object], top: int) -> str:
    lines = ["# Resonance diagnostics summary", ""]
    lines.append(f"- Records: {data['records']}")
    lines.append(f"- First: {data['first_timestamp'] or 'n/a'}")
    lines.append(f"- Last: {data['last_timestamp'] or 'n/a'}")
    lines.append(f"- Elapsed: {fmt(data['elapsed_seconds'])} s")
    lines.extend(["", "## Most frequent events", "", "| Event | Count | Rate/min |", "|---|---:|---:|"])
    counts = data["event_counts"]
    rates = data["event_rates_per_minute"]
    assert isinstance(counts, dict) and isinstance(rates, dict)
    for event, count in list(counts.items())[:top]:
        lines.append(f"| `{event}` | {count} | {fmt(rates.get(event))} |")
    if not counts:
        lines.append("| n/a | 0 | n/a |")
    lines.extend(
        [
            "",
            "## Timing fields",
            "",
            "| Event | Field | N | Min | Mean | SD | P50 | P95 | P99 | Max |",
            "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|",
        ]
    )
    timings = data["timings_ms"]
    assert isinstance(timings, list)
    for row in timings:
        lines.append(
            f"| `{row['event']}` | `{row['field']}` | {row['count']} | "
            f"{fmt(row['min'])} | {fmt(row['mean'])} | {fmt(row['stdev'])} | "
            f"{fmt(row['p50'])} | {fmt(row['p95'])} | {fmt(row['p99'])} | {fmt(row['max'])} |"
        )
    if not timings:
        lines.append("| n/a | n/a | 0 | n/a | n/a | n/a | n/a | n/a | n/a | n/a |")
    return "\n".join(lines)


def format_compare_markdown(data: dict[str, object]) -> str:
    lines = [
        "# Resonance diagnostics comparison",
        "",
        "Negative timing change is faster. Compare only equivalent workload manifests.",
        "",
        f"- Before records: {data['before_records']}",
        f"- After records: {data['after_records']}",
        f"- Confirmed regressions: {data['regression_count']}",
        f"- Confirmed improvements: {data['improvement_count']}",
        "",
        "## Timing fields",
        "",
        "| Event | Field | Before N | After N | Before P50 | After P50 | P50 change | P95 change | P99 change | Median delta CI95 ms | Cliff's delta | Status |",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|---|---:|---|",
    ]
    timings = data["timings_ms"]
    assert isinstance(timings, list)
    for row in timings:
        before_stats = row["before"] or {}
        after_stats = row["after"] or {}
        ci = row["median_delta_ci95_ms"]
        ci_text = "n/a" if ci is None else f"[{fmt(ci[0])}, {fmt(ci[1])}]"
        change = row["median_change_percent"]
        p95_change = row["p95_change_percent"]
        p99_change = row["p99_change_percent"]
        lines.append(
            f"| `{row['event']}` | `{row['field']}` | {before_stats.get('count', 0)} | "
            f"{after_stats.get('count', 0)} | {fmt(before_stats.get('p50'))} | "
            f"{fmt(after_stats.get('p50'))} | {fmt(change, 1)}% | {fmt(p95_change, 1)}% | "
            f"{fmt(p99_change, 1)}% | {ci_text} | {fmt(row['cliffs_delta'], 3)} | {row['status']} |"
        )
    if not timings:
        lines.append("| n/a | n/a | 0 | 0 | n/a | n/a | n/a | n/a | n/a | n/a | n/a | missing |")

    lines.extend(
        [
            "",
            "## Event counts",
            "",
            "Event-count changes are behavior evidence, not automatically errors.",
            "",
            "| Event | Before | After | Delta | Change |",
            "|---|---:|---:|---:|---:|",
        ]
    )
    event_counts = data["event_counts"]
    assert isinstance(event_counts, list)
    for row in event_counts:
        change = row["change_percent"]
        lines.append(
            f"| `{row['event']}` | {row['before']} | {row['after']} | {row['delta']:+d} | "
            f"{fmt(change, 1)}% |"
        )
    return "\n".join(lines)


def audit(records: list[Record]) -> list[dict[str, object]]:
    findings: list[dict[str, object]] = []
    for record in records:
        # Inspect the full line so sensitive key names are not lost.
        payload = record.raw
        for category, pattern in SENSITIVE_PATTERNS.items():
            if pattern.search(payload):
                findings.append(
                    {"line": record.line_number, "event": record.event, "category": category}
                )
    return findings


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    summary_parser = subparsers.add_parser("summary", help="summarize one log")
    summary_parser.add_argument("log", type=Path)
    summary_parser.add_argument("--format", choices=("markdown", "json"), default="markdown")
    summary_parser.add_argument("--top", type=int, default=20)
    summary_parser.add_argument("--include", help="regular expression matched against event names")

    compare_parser = subparsers.add_parser("compare", help="compare two equivalent logs")
    compare_parser.add_argument("before", type=Path)
    compare_parser.add_argument("after", type=Path)
    compare_parser.add_argument("--format", choices=("markdown", "json"), default="markdown")
    compare_parser.add_argument("--include", help="regular expression matched against event names")
    compare_parser.add_argument("--min-samples", type=int, default=5)
    compare_parser.add_argument("--regression-threshold", type=float, default=10.0)
    compare_parser.add_argument("--bootstrap", type=int, default=2000)
    compare_parser.add_argument("--seed", type=int, default=20260730)
    compare_parser.add_argument("--fail-on-regression", action="store_true")

    audit_parser = subparsers.add_parser("audit", help="flag potentially sensitive values")
    audit_parser.add_argument("log", type=Path)
    audit_parser.add_argument("--format", choices=("text", "json"), default="text")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "summary":
        records = filter_records(read_records(args.log), args.include)
        data = summarize(records)
        if args.format == "json":
            print(json.dumps(data, indent=2, sort_keys=True))
        else:
            print(format_summary_markdown(data, max(1, args.top)))
        return 0

    if args.command == "compare":
        before = filter_records(read_records(args.before), args.include)
        after = filter_records(read_records(args.after), args.include)
        data = compare(
            before,
            after,
            min_samples=max(1, args.min_samples),
            regression_threshold=max(0.0, args.regression_threshold),
            bootstrap_iterations=max(0, args.bootstrap),
            seed=args.seed,
        )
        if args.format == "json":
            print(json.dumps(data, indent=2, sort_keys=True))
        else:
            print(format_compare_markdown(data))
        if args.fail_on_regression and data["regression_count"]:
            return 2
        return 0

    findings = audit(read_records(args.log))
    if args.format == "json":
        print(json.dumps(findings, indent=2, sort_keys=True))
    elif findings:
        for finding in findings:
            print(f"line {finding['line']}: {finding['event']} may contain {finding['category']} data")
    else:
        print("No obvious sensitive values detected.")
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
