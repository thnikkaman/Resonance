#!/usr/bin/env python3
"""Create and validate Resonance optimization evidence workspaces."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Sequence

SCHEMA_VERSION = 1
IGNORED_COMPARE_KEYS = {"recorded_at", "notes", "artifact_paths"}


def write_json(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def stable_hash(data: object) -> str:
    encoded = json.dumps(data, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def make_workload(args: argparse.Namespace) -> dict[str, object]:
    return {
        "schema_version": SCHEMA_VERSION,
        "repository": args.repo,
        "ref": args.ref,
        "commit": args.commit,
        "scenario": args.scenario,
        "environment": {
            "device": args.device,
            "os": args.os,
            "configuration": args.configuration,
            "cache_state": args.cache_state,
            "local_track_count": args.local_tracks,
            "remote_track_count": args.remote_tracks,
            "network": args.network,
            "diagnostics_enabled": args.diagnostics_enabled,
        },
        "protocol": {
            "warmups": args.warmups,
            "repetitions": args.repetitions,
            "steps": [],
        },
        "expected_behavior": [],
        "primary_metrics": [],
        "secondary_metrics": [],
        "notes": "Fill steps, behavior oracle, and metrics before measuring.",
    }


def init_workspace(args: argparse.Namespace) -> int:
    root: Path = args.directory
    if root.exists() and any(root.iterdir()) and not args.force:
        print(f"error: {root} is not empty; use --force to overwrite generated files", file=sys.stderr)
        return 2
    for side in ("before", "after"):
        (root / side / "traces").mkdir(parents=True, exist_ok=True)
    workload = make_workload(args)
    write_json(root / "before" / "workload.json", workload)
    write_json(root / "after" / "workload.json", workload)
    manifest = {
        "schema_version": SCHEMA_VERSION,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "repository": args.repo,
        "ref": args.ref,
        "commit": args.commit,
        "scenario": args.scenario,
        "workload_hash": stable_hash(normalize_for_compare(workload)),
    }
    write_json(root / "manifest.json", manifest)
    write_json(
        root / "opportunities.json",
        [
            {
                "candidate": "replace with exact symbol/state flow",
                "evidence": "trace, repeated diagnostic, or measured count",
                "impact": 1,
                "confidence": 1,
                "effort": 1,
                "risk": 1,
                "validation": "describe subsystem validation",
            }
        ],
    )
    proof_text = proof_template("replace with one optimization lever")
    (root / "proof.md").write_text(proof_text, encoding="utf-8")
    print(f"Created {root}")
    print(f"Workload hash: {manifest['workload_hash']}")
    return 0


def normalize_for_compare(value: Any) -> Any:
    if isinstance(value, dict):
        return {
            key: normalize_for_compare(item)
            for key, item in sorted(value.items())
            if key not in IGNORED_COMPARE_KEYS
        }
    if isinstance(value, list):
        return [normalize_for_compare(item) for item in value]
    return value


def differences(before: Any, after: Any, path: str = "$") -> list[str]:
    if type(before) is not type(after):
        return [f"{path}: type {type(before).__name__} != {type(after).__name__}"]
    if isinstance(before, dict):
        result: list[str] = []
        keys = sorted(set(before) | set(after))
        for key in keys:
            next_path = f"{path}.{key}"
            if key not in before:
                result.append(f"{next_path}: missing before")
            elif key not in after:
                result.append(f"{next_path}: missing after")
            else:
                result.extend(differences(before[key], after[key], next_path))
        return result
    if isinstance(before, list):
        result = []
        if len(before) != len(after):
            result.append(f"{path}: length {len(before)} != {len(after)}")
        for index, (left, right) in enumerate(zip(before, after)):
            result.extend(differences(left, right, f"{path}[{index}]"))
        return result
    return [] if before == after else [f"{path}: {before!r} != {after!r}"]


def compare_manifests(args: argparse.Namespace) -> int:
    before = normalize_for_compare(read_json(args.before))
    after = normalize_for_compare(read_json(args.after))
    diffs = differences(before, after)
    print(f"Before hash: {stable_hash(before)}")
    print(f"After hash:  {stable_hash(after)}")
    if diffs:
        print("Workloads are not equivalent:")
        for item in diffs:
            print(f"- {item}")
        return 1
    print("Workloads are equivalent for declared fields.")
    return 0


def validate_rating(name: str, value: Any) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or not 1 <= value <= 5:
        raise ValueError(f"{name} must be an integer from 1 to 5")
    return value


def score_candidates(args: argparse.Namespace) -> int:
    raw = read_json(args.candidates)
    if not isinstance(raw, list):
        print("error: candidates file must contain a JSON list", file=sys.stderr)
        return 2
    rows: list[dict[str, object]] = []
    try:
        for index, item in enumerate(raw, 1):
            if not isinstance(item, dict):
                raise ValueError(f"candidate {index} must be an object")
            impact = validate_rating("impact", item.get("impact"))
            confidence = validate_rating("confidence", item.get("confidence"))
            effort = validate_rating("effort", item.get("effort"))
            risk = validate_rating("risk", item.get("risk"))
            score = (impact * confidence) / (effort * risk)
            accepted = score >= args.threshold and confidence >= args.min_confidence
            rows.append({**item, "score": score, "decision": "qualifies" if accepted else "defer"})
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    rows.sort(key=lambda row: (-float(row["score"]), str(row.get("candidate", ""))))
    if args.format == "json":
        print(json.dumps(rows, indent=2, sort_keys=True))
    else:
        print("# Resonance opportunity matrix")
        print()
        print(f"Threshold: score >= {args.threshold:.2f}, confidence >= {args.min_confidence}")
        print()
        print("| Candidate | Impact | Confidence | Effort | Risk | Score | Decision | Evidence |")
        print("|---|---:|---:|---:|---:|---:|---|---|")
        for row in rows:
            candidate = str(row.get("candidate", "unnamed")).replace("|", "\\|")
            evidence = str(row.get("evidence", "")).replace("|", "\\|")
            print(
                f"| {candidate} | {row['impact']} | {row['confidence']} | {row['effort']} | "
                f"{row['risk']} | {row['score']:.2f} | {row['decision']} | {evidence} |"
            )
    return 0


def proof_template(change: str) -> str:
    return f"""# Resonance optimization proof

## Change
{change}

## Workload
- manifest:
- repository/ref/commit:
- repetitions:

## Performance evidence
- confirmed hotspot:
- before p50/p95/p99/N:
- after p50/p95/p99/N:
- median delta CI95:
- Cliff's delta:
- secondary metrics:

## Equivalence proof
- same inputs -> same outputs:
- ordering and tie-breaking:
- stable IDs and navigation identity:
- queue/state-machine transitions:
- cache authority and refresh semantics:
- cancellation and stale-result rejection:
- numeric clamps/floating point/randomness:
- persistence/file/database behavior:
- actor isolation and Sendable safety:
- privacy-safe diagnostics:

## Validation
- diagnostics audit:
- unit tests:
- Tools/RegressionChecks.sh:
- git diff --check:
- Tools/PreflightBuild.sh:
- simulator scenario:
- physical-device scenario, when required:

## Rollback
- command or reversal:
- post-rollback checks:
"""


def write_proof(args: argparse.Namespace) -> int:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(proof_template(args.change), encoding="utf-8")
    print(f"Wrote {args.output}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    init = subparsers.add_parser("init", help="create an evidence workspace")
    init.add_argument("directory", type=Path)
    init.add_argument("--repo", required=True)
    init.add_argument("--ref", required=True)
    init.add_argument("--commit", required=True)
    init.add_argument("--scenario", required=True)
    init.add_argument("--device", required=True)
    init.add_argument("--os", required=True)
    init.add_argument("--configuration", choices=("Debug", "Release"), required=True)
    init.add_argument("--cache-state", required=True)
    init.add_argument("--local-tracks", type=int, required=True)
    init.add_argument("--remote-tracks", type=int, required=True)
    init.add_argument("--network", required=True)
    init.add_argument("--diagnostics-enabled", action="store_true")
    init.add_argument("--warmups", type=int, default=1)
    init.add_argument("--repetitions", type=int, default=5)
    init.add_argument("--force", action="store_true")

    compare_parser = subparsers.add_parser("compare-manifests", help="check workload equivalence")
    compare_parser.add_argument("before", type=Path)
    compare_parser.add_argument("after", type=Path)

    score = subparsers.add_parser("score", help="score optimization candidates")
    score.add_argument("candidates", type=Path)
    score.add_argument("--threshold", type=float, default=2.0)
    score.add_argument("--min-confidence", type=int, default=3)
    score.add_argument("--format", choices=("markdown", "json"), default="markdown")

    proof = subparsers.add_parser("proof", help="create a proof template")
    proof.add_argument("output", type=Path)
    proof.add_argument("--change", required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "init":
        if args.local_tracks < 0 or args.remote_tracks < 0:
            print("error: track counts must be non-negative", file=sys.stderr)
            return 2
        if args.warmups < 0 or args.repetitions < 1:
            print("error: warmups must be >= 0 and repetitions must be >= 1", file=sys.stderr)
            return 2
        return init_workspace(args)
    if args.command == "compare-manifests":
        return compare_manifests(args)
    if args.command == "score":
        return score_candidates(args)
    return write_proof(args)


if __name__ == "__main__":
    raise SystemExit(main())
