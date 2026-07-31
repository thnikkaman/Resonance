#!/usr/bin/env python3
"""Run safe, deterministic smoke tests for every bundled Resonance skill script."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Sequence

SENSITIVE_ARG_RE = re.compile(r"(?i)(password|passwd|token|secret|credential|authorization|api[_-]?key|cookie)")


def report_arg(value: str) -> str:
    if value.startswith(("http://", "https://")):
        return "<url>"
    if SENSITIVE_ARG_RE.search(value):
        return value.split("=", 1)[0] + "=<redacted>" if "=" in value else "<redacted>"
    try:
        path = Path(value)
        if path.is_absolute():
            return f"<absolute-path>/{path.name}"
    except (OSError, ValueError):
        return "<redacted-path>"
    return value


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Smoke-test repository-local Agent Skill scripts.")
    parser.add_argument(
        "--repo",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Repository root (defaults to this script's repository)",
    )
    parser.add_argument("--skip-server", action="store_true", help="Skip the real fixture-server contract harness")
    parser.add_argument("--keep-workspace", type=Path, default=None, help="Keep artifacts at this path")
    return parser.parse_args(argv)


def run(
    command: list[str],
    *,
    cwd: Path,
    log: list[dict[str, object]],
    expected_exit: int = 0,
) -> None:
    completed = subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=120)
    log.append(
        {
            "command": [report_arg(part) for part in command],
            "exit_code": completed.returncode,
            "stdout": completed.stdout[-4000:],
            "stderr": completed.stderr[-4000:],
        }
    )
    if completed.returncode != expected_exit:
        raise RuntimeError(
            f"command failed ({completed.returncode}; expected {expected_exit}): {' '.join(command)}\n"
            f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    repo = args.repo.expanduser().resolve()
    skills = repo / ".agents/skills"
    if not (repo / "Tools/ResonanceServer.py").is_file() and not args.skip_server:
        print("error: Tools/ResonanceServer.py is required unless --skip-server is used", file=sys.stderr)
        return 2

    if args.keep_workspace:
        workspace = args.keep_workspace.expanduser().resolve()
        workspace.mkdir(parents=True, exist_ok=True)
        temporary = None
    else:
        temporary = tempfile.TemporaryDirectory(prefix="resonance-skill-smoke-")
        workspace = Path(temporary.name)

    commands: list[dict[str, object]] = []
    py = sys.executable
    try:
        run([py, str(repo / "Tools/ValidateAgentSkills.py"), "--repo", str(repo)], cwd=repo, log=commands)

        census_json = workspace / "census.json"
        census_md = workspace / "census.md"
        run(
            [
                py,
                str(skills / "resonance-decompose-isomorphically/scripts/swift_seam_census.py"),
                str(repo),
                "--json-out",
                str(census_json),
                "--markdown-out",
                str(census_md),
                "--no-git",
            ],
            cwd=repo,
            log=commands,
        )
        census = json.loads(census_json.read_text(encoding="utf-8"))
        if census.get("summary", {}).get("swift_files", 0) < 1:
            raise RuntimeError("seam census did not discover Swift files")

        seam_fixture = workspace / "seam-fixture"
        seam_fixture.mkdir()
        large = seam_fixture / "Large.swift"
        large.write_text(
            "import Foundation\nstruct Large {\n"
            + "".join(f"  func helper{index}() -> Int {{ {index} }}\n" for index in range(180))
            + "}\n",
            encoding="utf-8",
        )
        generated = seam_fixture / "Generated.swift"
        generated.write_text(
            "// GENERATED FILE - DO NOT EDIT\nimport Foundation\nstruct Generated {\n"
            + "".join(f"  static let value{index} = {index}\n" for index in range(220))
            + "}\n",
            encoding="utf-8",
        )
        seam_fixture_json = workspace / "seam-fixture.json"
        run(
            [
                py,
                str(skills / "resonance-decompose-isomorphically/scripts/swift_seam_census.py"),
                str(seam_fixture),
                "--json-out",
                str(seam_fixture_json),
                "--markdown-out",
                str(workspace / "seam-fixture.md"),
                "--min-lines",
                "100",
                "--no-git",
            ],
            cwd=repo,
            log=commands,
        )
        seam_fixture_data = json.loads(seam_fixture_json.read_text(encoding="utf-8"))
        seam_candidates = {item["path"] for item in seam_fixture_data.get("candidates", [])}
        seam_files = {item["path"]: item for item in seam_fixture_data.get("files", [])}
        if "Large.swift" not in seam_candidates or "Generated.swift" in seam_candidates:
            raise RuntimeError("seam census did not rank the hand-written file and exclude generated source")
        if seam_files.get("Generated.swift", {}).get("generated_likelihood") != "high":
            raise RuntimeError("generated-source detection did not classify the fixture")

        snapshot = workspace / "surface.json"
        comparison = workspace / "surface-compare.json"
        snapshot_tool = skills / "resonance-refactor-isomorphically/scripts/isomorphism_snapshot.py"
        run([py, str(snapshot_tool), "capture", str(repo), "--out", str(snapshot)], cwd=repo, log=commands)
        run(
            [py, str(snapshot_tool), "compare", str(repo), "--baseline", str(snapshot), "--out", str(comparison)],
            cwd=repo,
            log=commands,
        )
        if json.loads(comparison.read_text(encoding="utf-8")).get("status") != "pass":
            raise RuntimeError("unchanged surface comparison did not pass")

        surface_fixture = workspace / "surface-drift"
        surface_fixture.mkdir()
        contract_file = surface_fixture / "Contract.swift"
        contract_file.write_text(
            'final class Contract {\n  func play() {\n    record("playback.start")\n  }\n  func record(_ event: String) {}\n}\n',
            encoding="utf-8",
        )
        surface_baseline = workspace / "surface-drift-baseline.json"
        surface_compare = workspace / "surface-drift-compare.json"
        run([py, str(snapshot_tool), "capture", str(surface_fixture), "--out", str(surface_baseline)], cwd=repo, log=commands)
        contract_file.write_text(
            'final class Contract {\n  func playRenamed() {\n    record("playback.start.changed")\n  }\n  func record(_ event: String) {}\n}\n',
            encoding="utf-8",
        )
        run(
            [py, str(snapshot_tool), "compare", str(surface_fixture), "--baseline", str(surface_baseline), "--out", str(surface_compare)],
            cwd=repo,
            log=commands,
            expected_exit=1,
        )
        surface_drift = json.loads(surface_compare.read_text(encoding="utf-8"))
        categories = {item.get("category") for item in surface_drift.get("blockers", [])}
        if surface_drift.get("status") != "fail" or not {"removed_declarations", "removed_contracts"}.issubset(categories):
            raise RuntimeError("surface snapshot did not block declaration and diagnostic-contract drift")

        benchmark = workspace / "benchmark.json"
        run(
            [
                py,
                str(skills / "resonance-profile-performance/scripts/benchmark_command.py"),
                "--label",
                "agent-skill-smoke",
                "--runs",
                "2",
                "--warmups",
                "1",
                "--out",
                str(benchmark),
                "--",
                py,
                "-c",
                "print('resonance-skill-smoke')",
            ],
            cwd=repo,
            log=commands,
        )
        benchmark_data = json.loads(benchmark.read_text(encoding="utf-8"))
        if benchmark_data.get("status") != "pass" or benchmark_data.get("summary", {}).get("count") != 2:
            raise RuntimeError("benchmark smoke result is invalid")

        benchmark_redaction = workspace / "benchmark-redaction.json"
        run(
            [
                py,
                str(skills / "resonance-profile-performance/scripts/benchmark_command.py"),
                "--label",
                "agent-skill-smoke-redaction",
                "--runs",
                "1",
                "--warmups",
                "0",
                "--cwd",
                str(repo),
                "--out",
                str(benchmark_redaction),
                "--env",
                "FAKE_TOKEN=FAKE_TEST_SECRET_VALUE",
                "--",
                py,
                "-c",
                "print('resonance-skill-smoke')",
                "--token=FAKE_ARG_SECRET_VALUE",
                "https://example.invalid/media?q=FAKE_QUERY_VALUE",
            ],
            cwd=repo,
            log=commands,
        )
        benchmark_redaction_raw = benchmark_redaction.read_text(encoding="utf-8")
        for forbidden in (
            "FAKE_TEST_SECRET_VALUE",
            "FAKE_ARG_SECRET_VALUE",
            "FAKE_QUERY_VALUE",
            "example.invalid",
            str(repo),
        ):
            if forbidden in benchmark_redaction_raw:
                raise RuntimeError(f"benchmark report leaked redaction fixture: {forbidden}")
        benchmark_redaction_data = json.loads(benchmark_redaction_raw)
        if (
            benchmark_redaction_data.get("status") != "pass"
            or benchmark_redaction_data.get("cwd") != "<provided>"
            or benchmark_redaction_data.get("command_fingerprint_scope") != "sanitized"
        ):
            raise RuntimeError("benchmark redaction metadata is invalid")

        diagnostics_log = workspace / "Resonance-Diagnostics.log"
        diagnostics_log.write_text(
            "2026-01-01T00:00:00Z smoke.operation.begin count=3\n"
            "2026-01-01T00:00:00.125Z smoke.operation.end duration_ms=125 result=ok\n",
            encoding="utf-8",
        )
        diagnostics_summary = workspace / "diagnostics-summary.json"
        run(
            [
                py,
                str(skills / "resonance-profile-performance/scripts/summarize_diagnostics.py"),
                str(diagnostics_log),
                "--out",
                str(diagnostics_summary),
            ],
            cwd=repo,
            log=commands,
        )
        diagnostics = json.loads(diagnostics_summary.read_text(encoding="utf-8"))
        if diagnostics.get("status") != "pass" or diagnostics.get("summary", {}).get("parsed_lines") != 2:
            raise RuntimeError("diagnostics smoke result is invalid")

        unsafe_log = workspace / "Resonance-Diagnostics-unsafe.log"
        unsafe_log.write_text(
            "2026-01-01T00:00:00Z smoke.request server_url=https://private.invalid/path token=not-a-real-token\n",
            encoding="utf-8",
        )
        unsafe_summary = workspace / "diagnostics-unsafe.json"
        run(
            [
                py,
                str(skills / "resonance-profile-performance/scripts/summarize_diagnostics.py"),
                str(unsafe_log),
                "--out",
                str(unsafe_summary),
            ],
            cwd=repo,
            log=commands,
            expected_exit=2,
        )
        unsafe_raw = unsafe_summary.read_text(encoding="utf-8")
        unsafe = json.loads(unsafe_raw)
        if unsafe.get("status") != "fail" or unsafe.get("summary", {}).get("privacy_warning_count", 0) < 1:
            raise RuntimeError("privacy-negative diagnostic smoke did not fail closed")
        if "private.invalid" in unsafe_raw or "not-a-real-token" in unsafe_raw:
            raise RuntimeError("privacy-negative report leaked a sensitive fixture value")

        varying = workspace / "benchmark-varying.json"
        run(
            [
                py,
                str(skills / "resonance-profile-performance/scripts/benchmark_command.py"),
                "--label",
                "agent-skill-smoke-varying-output",
                "--runs",
                "3",
                "--warmups",
                "0",
                "--out",
                str(varying),
                "--",
                py,
                "-c",
                "import time; print(time.time_ns())",
            ],
            cwd=repo,
            log=commands,
            expected_exit=1,
        )
        varying_data = json.loads(varying.read_text(encoding="utf-8"))
        if varying_data.get("status") != "fail" or varying_data.get("output_mismatch_count", 0) < 1:
            raise RuntimeError("varying-output benchmark smoke did not fail closed")

        drift_repo = workspace / "catalog-drift"
        (drift_repo / ".agents").mkdir(parents=True)
        shutil.copytree(skills, drift_repo / ".agents/skills")
        drift_contract = drift_repo / ".agents/skills/resonance-profile-performance/references/RESONANCE-CONTRACT.md"
        drift_contract.write_text(drift_contract.read_text(encoding="utf-8") + "\nIntentional smoke drift.\n", encoding="utf-8")
        run(
            [py, str(repo / "Tools/ValidateAgentSkills.py"), "--repo", str(drift_repo)],
            cwd=repo,
            log=commands,
            expected_exit=1,
        )

        if not args.skip_server:
            evidence = workspace / "fixture-service.jsonl"
            run(
                [
                    py,
                    str(skills / "resonance-real-service-e2e/scripts/real_service_harness.py"),
                    str(repo),
                    "--out",
                    str(evidence),
                ],
                cwd=repo,
                log=commands,
            )
            rows = [json.loads(line) for line in evidence.read_text(encoding="utf-8").splitlines() if line.strip()]
            if not rows or not any(row.get("event") == "completed" and row.get("result") == "pass" for row in rows):
                raise RuntimeError("real-service harness did not emit a passing summary")

        report = {"status":"pass","workspace":str(workspace),"commands":commands}
        (workspace / "smoke-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"Agent Skill smoke tests passed ({len(commands)} commands).")
        if args.keep_workspace:
            print(f"Artifacts: {workspace}")
        return 0
    except (OSError, subprocess.TimeoutExpired, RuntimeError, json.JSONDecodeError) as exc:
        report = {"status":"fail","workspace":str(workspace),"error":str(exc),"commands":commands}
        (workspace / "smoke-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"Agent Skill smoke tests failed: {exc}", file=sys.stderr)
        if args.keep_workspace:
            print(f"Artifacts: {workspace}", file=sys.stderr)
        return 1
    finally:
        if temporary is not None:
            temporary.cleanup()


if __name__ == "__main__":
    raise SystemExit(main())
