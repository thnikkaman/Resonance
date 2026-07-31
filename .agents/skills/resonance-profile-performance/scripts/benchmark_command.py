#!/usr/bin/env python3
"""Run a command repeatedly and emit privacy-conscious timing evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import resource
import statistics
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Sequence
from urllib.parse import urlsplit, urlunsplit

SCHEMA_VERSION = 2
SENSITIVE_KEY_RE = re.compile(r"(?i)(password|passwd|token|secret|credential|authorization|api[_-]?key|cookie)")


@dataclass
class Sample:
    phase: str
    index: int
    duration_ms: float
    user_cpu_ms: float
    system_cpu_ms: float
    returncode: int
    timed_out: bool
    stdout_bytes: int
    stderr_bytes: int
    output_sha256: str | None
    output_matches_golden: bool | None


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Benchmark a command with warmups and repeated measured runs.")
    parser.add_argument("--label", required=True, help="Stable scenario label")
    parser.add_argument("--runs", type=int, default=10, help="Measured runs")
    parser.add_argument("--warmups", type=int, default=3, help="Warmup runs")
    parser.add_argument("--timeout", type=float, default=None, help="Per-run timeout in seconds")
    parser.add_argument("--cwd", type=Path, default=None, help="Working directory for the command")
    parser.add_argument("--out", type=Path, required=True, help="JSON output path")
    parser.add_argument("--expected-exit", type=int, default=0, help="Expected command exit code")
    parser.add_argument(
        "--hash-output",
        choices=("combined", "stdout", "stderr", "none"),
        default="combined",
        help="Output stream used for a correctness digest",
    )
    parser.add_argument(
        "--allow-varying-output",
        action="store_true",
        help="Do not fail when measured output digests differ",
    )
    parser.add_argument(
        "--env",
        action="append",
        default=[],
        metavar="KEY=VALUE",
        help="Additional environment entry; values are never written to the report",
    )
    parser.add_argument("command", nargs=argparse.REMAINDER, help="Command after --")
    args = parser.parse_args(argv)
    if args.command and args.command[0] == "--":
        args.command = args.command[1:]
    return args


def sanitized_arg(value: str) -> str:
    """Return a useful command shape without hosts, paths, or secret values."""
    if value.startswith(("http://", "https://")):
        try:
            parts = urlsplit(value)
            path_marker = "/<redacted-path>" if parts.path not in ("", "/") else parts.path
            query_marker = "<redacted>" if parts.query else ""
            return urlunsplit((parts.scheme, "<host>", path_marker, query_marker, ""))
        except ValueError:
            return "<redacted-url>"
    if SENSITIVE_KEY_RE.search(value):
        if "=" in value:
            return value.split("=", 1)[0] + "=<redacted>"
        return "<redacted>"
    if "?" in value and "=" in value:
        return value.split("?", 1)[0] + "?<redacted>"
    if value.startswith("~/"):
        return "<home-path>"
    try:
        if Path(value).is_absolute():
            return "<absolute-path>"
    except (OSError, ValueError):
        return "<redacted-path>"
    return value


def sanitized_command(command: Sequence[str]) -> list[str]:
    sanitized = [sanitized_arg(part) for part in command]
    if command and Path(command[0]).is_absolute():
        sanitized[0] = f"<absolute-executable>/{Path(command[0]).name}"
    return sanitized


def parse_env(entries: Sequence[str]) -> tuple[dict[str, str], list[str]]:
    environment = dict(os.environ)
    keys: list[str] = []
    for entry in entries:
        if "=" not in entry:
            raise ValueError(f"invalid --env entry (expected KEY=VALUE): {entry}")
        key, value = entry.split("=", 1)
        if not key or "\x00" in key or "\x00" in value:
            raise ValueError(f"invalid --env entry: {entry}")
        environment[key] = value
        keys.append(key)
    return environment, sorted(set(keys))


def digest_output(stdout: bytes, stderr: bytes, mode: str) -> str | None:
    if mode == "none":
        return None
    if mode == "stdout":
        payload = stdout
    elif mode == "stderr":
        payload = stderr
    else:
        payload = stdout + b"\0STDERR\0" + stderr
    return hashlib.sha256(payload).hexdigest()


def resource_snapshot() -> tuple[float, float]:
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    return usage.ru_utime, usage.ru_stime


def run_once(command: Sequence[str], cwd: Path | None, environment: dict[str, str], timeout: float | None, phase: str, index: int, hash_mode: str, golden: str | None) -> Sample:
    before_user, before_system = resource_snapshot()
    started = time.perf_counter_ns()
    timed_out = False
    try:
        completed = subprocess.run(list(command), cwd=str(cwd) if cwd else None, env=environment, capture_output=True, timeout=timeout, check=False)
        returncode = completed.returncode
        stdout = completed.stdout
        stderr = completed.stderr
    except subprocess.TimeoutExpired as exc:
        timed_out = True
        returncode = 124
        stdout = exc.stdout or b""
        stderr = exc.stderr or b""
    elapsed_ms = (time.perf_counter_ns() - started) / 1_000_000.0
    after_user, after_system = resource_snapshot()
    output_hash = digest_output(stdout, stderr, hash_mode)
    return Sample(phase=phase,index=index,duration_ms=round(elapsed_ms,3),user_cpu_ms=round(max(0.0,after_user-before_user)*1000.0,3),system_cpu_ms=round(max(0.0,after_system-before_system)*1000.0,3),returncode=returncode,timed_out=timed_out,stdout_bytes=len(stdout),stderr_bytes=len(stderr),output_sha256=output_hash,output_matches_golden=None if golden is None or output_hash is None else output_hash==golden)


def percentile(values: Sequence[float], fraction: float) -> float:
    if not values: return math.nan
    ordered = sorted(values)
    if len(ordered)==1: return ordered[0]
    position=(len(ordered)-1)*fraction
    lower=math.floor(position); upper=math.ceil(position)
    if lower==upper: return ordered[lower]
    weight=position-lower
    return ordered[lower]*(1.0-weight)+ordered[upper]*weight


def summarize(values: Sequence[float]) -> dict[str, float | int | None]:
    if not values:
        return {"count":0,"minimum_ms":None,"median_ms":None,"p95_ms":None,"maximum_ms":None,"mad_ms":None,"mean_ms":None,"stdev_ms":None,"coefficient_of_variation":None}
    median_value=statistics.median(values)
    deviations=[abs(value-median_value) for value in values]
    mean_value=statistics.fmean(values)
    stdev=statistics.stdev(values) if len(values)>1 else 0.0
    return {"count":len(values),"minimum_ms":round(min(values),3),"median_ms":round(median_value,3),"p95_ms":round(percentile(values,0.95),3),"maximum_ms":round(max(values),3),"mad_ms":round(statistics.median(deviations),3),"mean_ms":round(mean_value,3),"stdev_ms":round(stdev,3),"coefficient_of_variation":round(stdev/mean_value,6) if mean_value else None}


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True)+"\n", encoding="utf-8")


def main(argv: Sequence[str] | None = None) -> int:
    args=parse_args(argv or sys.argv[1:])
    if not args.command:
        print("error: provide a command after --", file=sys.stderr); return 2
    if args.runs<1 or args.warmups<0:
        print("error: --runs must be positive and --warmups must be non-negative", file=sys.stderr); return 2
    if args.timeout is not None and args.timeout<=0:
        print("error: --timeout must be positive", file=sys.stderr); return 2
    cwd=args.cwd.expanduser().resolve() if args.cwd else None
    if cwd is not None and not cwd.is_dir():
        print(f"error: --cwd is not a directory: {cwd}", file=sys.stderr); return 2
    try:
        environment,reported_env_keys=parse_env(args.env)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr); return 2
    samples=[]; golden=None
    for index in range(1,args.warmups+1):
        samples.append(run_once(args.command,cwd,environment,args.timeout,"warmup",index,args.hash_output,None))
    for index in range(1,args.runs+1):
        sample=run_once(args.command,cwd,environment,args.timeout,"measured",index,args.hash_output,golden)
        if golden is None and sample.output_sha256 is not None and sample.returncode==args.expected_exit:
            golden=sample.output_sha256; sample.output_matches_golden=True
        elif golden is not None and sample.output_sha256 is not None:
            sample.output_matches_golden=sample.output_sha256==golden
        samples.append(sample)
    measured=[s for s in samples if s.phase=="measured"]
    exit_failures=[s.index for s in measured if s.returncode!=args.expected_exit or s.timed_out]
    output_mismatches=[s.index for s in measured if s.output_matches_golden is False]
    durations=[s.duration_ms for s in measured if not s.timed_out]
    status="pass"; reasons=[]
    if exit_failures:
        status="fail"; reasons.append(f"unexpected exit or timeout in measured runs: {exit_failures}")
    if output_mismatches and not args.allow_varying_output:
        status="fail"; reasons.append(f"output digest differed from the first successful measured run: {output_mismatches}")
    report_command=sanitized_command(args.command)
    payload={"schema_version":SCHEMA_VERSION,"label":args.label,"status":status,"failure_reasons":reasons,"command":report_command,"command_sha256":hashlib.sha256("\0".join(report_command).encode("utf-8",errors="replace")).hexdigest(),"command_fingerprint_scope":"sanitized","cwd":"<provided>" if cwd else None,"cwd_sha256":hashlib.sha256(str(cwd).encode("utf-8")).hexdigest() if cwd else None,"environment_override_keys":reported_env_keys,"configuration":{"runs":args.runs,"warmups":args.warmups,"timeout_seconds":args.timeout,"expected_exit":args.expected_exit,"hash_output":args.hash_output,"allow_varying_output":bool(args.allow_varying_output)},"summary":summarize(durations),"failure_count":len(exit_failures),"output_mismatch_count":len(output_mismatches),"golden_output_sha256":golden,"samples":[asdict(s) for s in samples]}
    write_json(args.out,payload)
    summary=payload["summary"]
    print(f"{args.label}: {status}; n={summary['count']} median={summary['median_ms']} ms p95={summary['p95_ms']} ms")
    print(f"Report: {args.out}")
    return 0 if status=="pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
