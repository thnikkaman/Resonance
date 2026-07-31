#!/usr/bin/env python3
"""Exercise the repository's real fixture server over loopback HTTP.

The harness creates only run-owned files, binds only to 127.0.0.1, records
privacy-safe JSONL evidence, and always tears the server down.
"""

from __future__ import annotations

import argparse
import hashlib
import http.client
import json
import os
import re
import socket
import subprocess
import sys
import tempfile
import time
import wave
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Sequence

SUITE = "resonance-fixture-service"


class HarnessFailure(RuntimeError):
    pass


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the real Resonance fixture-server contract suite.")
    parser.add_argument("repo", type=Path, help="Repository root containing Tools/ResonanceServer.py")
    parser.add_argument("--out", type=Path, required=True, help="Privacy-safe JSONL evidence path")
    parser.add_argument("--startup-timeout", type=float, default=8.0, help="Server startup timeout in seconds")
    return parser.parse_args(argv)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def reserve_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def create_wave_fixture(path: Path) -> bytes:
    path.parent.mkdir(parents=True, exist_ok=True)
    sample_rate = 8000
    frames = 1600
    samples = bytearray()
    for index in range(frames):
        value = ((index * 257) % 65536) - 32768
        samples.extend(int(value).to_bytes(2, byteorder="little", signed=True))
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        handle.writeframes(bytes(samples))
    return path.read_bytes()


def request(
    port: int,
    method: str,
    target: str,
    headers: dict[str, str] | None = None,
    timeout: float = 4.0,
) -> tuple[int, dict[str, str], bytes]:
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=timeout)
    try:
        connection.request(method, target, headers=headers or {})
        response = connection.getresponse()
        body = response.read()
        normalized_headers = {key.lower(): value for key, value in response.getheaders()}
        return response.status, normalized_headers, body
    finally:
        connection.close()


def as_int(value: str | None) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except ValueError:
        return None


def sanitize_server_output(data: bytes, repo: Path, fixture_root: Path, port: int) -> bytes:
    """Redact local paths and generated media names from retained server logs."""

    text = data.decode("utf-8", errors="replace")
    replacements = {
        str(repo): "<repo>",
        str(fixture_root): "<fixture-root>",
        "Fixture Artist": "<fixture-artist>",
        "Fixture%20Artist": "<fixture-artist>",
        "Fixture Album": "<fixture-album>",
        "Fixture%20Album": "<fixture-album>",
        "01 Contract.wav": "<fixture-media>",
        "01%20Contract.wav": "<fixture-media>",
        f"127.0.0.1:{port}": "127.0.0.1:<port>",
    }
    for source, replacement in replacements.items():
        text = text.replace(source, replacement)
    text = re.sub(r"(?m)(Serving\s+)(?:/|[A-Za-z]:\\)[^\r\n]+", r"\1<fixture-root>", text)
    return text.encode("utf-8")


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    repo = args.repo.expanduser().resolve()
    server_script = repo / "Tools" / "ResonanceServer.py"
    if not server_script.is_file():
        print(f"error: fixture server not found: {server_script}", file=sys.stderr)
        return 2
    if args.startup_timeout <= 0:
        print("error: --startup-timeout must be positive", file=sys.stderr)
        return 2

    out = args.out.expanduser().resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    server_log = out.with_suffix(out.suffix + ".server.log")
    events: list[dict[str, Any]] = []
    process: subprocess.Popen[bytes] | None = None
    passed = 0
    failed = 0
    run_started = time.perf_counter()

    def emit(test: str, phase: str, event: str, **fields: Any) -> None:
        row: dict[str, Any] = {
            "ts": utc_now(),
            "suite": SUITE,
            "test": test,
            "phase": phase,
            "event": event,
        }
        for key, value in fields.items():
            if value is not None:
                row[key] = value
        events.append(row)
        with out.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(row, separators=(",", ":"), sort_keys=True) + "\n")

    def evidence_value(value: Any) -> Any:
        if isinstance(value, bytes):
            return {"bytes": len(value), "sha256": hashlib.sha256(value).hexdigest()}
        if isinstance(value, tuple):
            payload = json.dumps(list(value), separators=(",", ":"), sort_keys=True).encode("utf-8")
            return {"tuple_sha256": hashlib.sha256(payload).hexdigest(), "items": len(value)}
        return value

    def assert_equal(test: str, actual: Any, expected: Any, event: str = "value") -> None:
        nonlocal passed, failed
        match = actual == expected
        emit(
            test,
            "assert",
            event,
            expected=evidence_value(expected),
            actual=evidence_value(actual),
            match=match,
        )
        if match:
            passed += 1
        else:
            failed += 1
            raise HarnessFailure(f"{test}: expected {expected!r}, got {actual!r}")

    def assert_true(test: str, condition: bool, event: str, **fields: Any) -> None:
        nonlocal passed, failed
        emit(test, "assert", event, match=bool(condition), **fields)
        if condition:
            passed += 1
        else:
            failed += 1
            raise HarnessFailure(f"{test}: assertion failed")

    out.write_text("", encoding="utf-8")
    emit("suite", "arrange", "safety", endpoint="loopback", mutations="run-owned-files-only")

    outcome = 1
    error_kind: str | None = None
    with tempfile.TemporaryDirectory(prefix="resonance-e2e-") as temporary:
        temp_root = Path(temporary)
        media_root = temp_root / "library"
        fixture_path = media_root / "Fixture Artist" / "Fixture Album" / "01 Contract.wav"
        fixture_bytes = create_wave_fixture(fixture_path)
        fixture_sha = hashlib.sha256(fixture_bytes).hexdigest()
        emit(
            "fixture",
            "arrange",
            "wave_created",
            bytes=len(fixture_bytes),
            sha256=fixture_sha,
            channels=1,
            sample_rate=8000,
        )

        port = reserve_port()
        environment = dict(os.environ)
        environment["PYTHONUNBUFFERED"] = "1"
        process = subprocess.Popen(
            [
                sys.executable,
                str(server_script),
                str(media_root),
                "--host",
                "127.0.0.1",
                "--port",
                str(port),
                "--name",
                "Contract Fixture",
            ],
            cwd=str(repo),
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        emit("server", "act", "process_started", pid_present=process.pid > 0)

        try:
            deadline = time.monotonic() + args.startup_timeout
            startup_status: int | None = None
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    raise HarnessFailure("fixture server exited during startup")
                try:
                    startup_status, _, _ = request(port, "GET", "/resonance/library.json", timeout=0.5)
                    if startup_status == 200:
                        break
                except (OSError, http.client.HTTPException):
                    pass
                time.sleep(0.05)
            assert_equal("startup", startup_status, 200, "http_status")

            status, headers, manifest_body = request(port, "GET", "/resonance/library.json")
            assert_equal("manifest", status, 200, "http_status")
            assert_equal("manifest", headers.get("content-type"), "application/json; charset=utf-8", "content_type")
            manifest = json.loads(manifest_body.decode("utf-8"))
            tracks = manifest.get("tracks") if isinstance(manifest, dict) else None
            assert_true("manifest", isinstance(tracks, list), "tracks_array")
            assert_equal("manifest", len(tracks), 1, "track_count")
            track = tracks[0]
            media_target = track.get("path")
            assert_true(
                "manifest",
                isinstance(media_target, str) and media_target.startswith("/media/"),
                "media_target",
            )
            first_identity = (track.get("id"), media_target)
            status_again, _, manifest_again_body = request(port, "GET", "/resonance/library.json")
            assert_equal("manifest-stability", status_again, 200, "http_status")
            manifest_again = json.loads(manifest_again_body.decode("utf-8"))
            track_again = manifest_again["tracks"][0]
            assert_equal(
                "manifest-stability",
                (track_again.get("id"), track_again.get("path")),
                first_identity,
                "identity_and_path",
            )

            status, headers, body = request(port, "GET", media_target)
            assert_equal("full-get", status, 200, "http_status")
            assert_equal("full-get", as_int(headers.get("content-length")), len(fixture_bytes), "content_length")
            assert_equal("full-get", hashlib.sha256(body).hexdigest(), fixture_sha, "sha256")
            assert_equal("full-get", headers.get("accept-ranges"), "bytes", "accept_ranges")

            status, headers, body = request(port, "HEAD", media_target)
            assert_equal("head", status, 200, "http_status")
            assert_equal("head", len(body), 0, "body_bytes")
            assert_equal("head", as_int(headers.get("content-length")), len(fixture_bytes), "content_length")
            assert_equal("head", headers.get("accept-ranges"), "bytes", "accept_ranges")

            prefix_length = 16
            status, headers, body = request(
                port,
                "GET",
                media_target,
                headers={"Range": f"bytes=0-{prefix_length - 1}"},
            )
            assert_equal("prefix-range", status, 206, "http_status")
            assert_equal("prefix-range", body, fixture_bytes[:prefix_length], "bytes")
            assert_equal(
                "prefix-range",
                headers.get("content-range"),
                f"bytes 0-{prefix_length - 1}/{len(fixture_bytes)}",
                "content_range",
            )

            suffix_length = 16
            status, headers, body = request(
                port,
                "GET",
                media_target,
                headers={"Range": f"bytes=-{suffix_length}"},
            )
            assert_equal("suffix-range", status, 206, "http_status")
            assert_equal("suffix-range", body, fixture_bytes[-suffix_length:], "bytes")
            assert_equal(
                "suffix-range",
                headers.get("content-range"),
                f"bytes {len(fixture_bytes) - suffix_length}-{len(fixture_bytes) - 1}/{len(fixture_bytes)}",
                "content_range",
            )

            status, headers, body = request(
                port,
                "GET",
                media_target,
                headers={"Range": f"bytes={len(fixture_bytes) + 5}-{len(fixture_bytes) + 10}"},
            )
            assert_equal("invalid-range", status, 416, "http_status")
            assert_equal("invalid-range", headers.get("content-range"), f"bytes */{len(fixture_bytes)}", "content_range")
            assert_equal("invalid-range", len(body), 0, "body_bytes")

            status, _, _ = request(port, "GET", "/not-present")
            assert_equal("missing-route", status, 404, "http_status")

            status, _, _ = request(port, "GET", "/media/%2e%2e/%2e%2e/outside.wav")
            assert_equal("traversal-guard", status, 403, "http_status")

            outcome = 0
        except (HarnessFailure, OSError, http.client.HTTPException, json.JSONDecodeError, KeyError, TypeError) as exc:
            error_kind = type(exc).__name__
            emit("suite", "assert", "failure", result="fail", error_kind=error_kind)
            print(f"fixture-service harness failed: {exc}", file=sys.stderr)
            outcome = 1
        finally:
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    stdout, stderr = process.communicate(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    stdout, stderr = process.communicate(timeout=3)
            elif process is not None:
                stdout, stderr = process.communicate(timeout=3)
            else:
                stdout, stderr = b"", b""
            sanitized_stdout = sanitize_server_output(stdout, repo, temp_root, port)
            sanitized_stderr = sanitize_server_output(stderr, repo, temp_root, port)
            server_log.write_bytes(
                b"STDOUT\n" + sanitized_stdout + b"\nSTDERR\n" + sanitized_stderr
            )
            emit(
                "server",
                "cleanup",
                "process_stopped",
                returncode=process.returncode if process is not None else None,
                server_log=server_log.name,
                server_log_sanitized=True,
            )

    emit(
        "suite",
        "cleanup",
        "completed",
        result="pass" if outcome == 0 else "fail",
        assertions_passed=passed,
        assertions_failed=failed,
        duration_ms=round((time.perf_counter() - run_started) * 1000.0, 3),
        error_kind=error_kind,
    )
    print(
        f"Fixture-service contract: {'pass' if outcome == 0 else 'fail'}; "
        f"assertions passed={passed}, failed={failed}."
    )
    print(f"Evidence: {out}")
    print(f"Server log: {server_log}")
    return outcome


if __name__ == "__main__":
    raise SystemExit(main())
