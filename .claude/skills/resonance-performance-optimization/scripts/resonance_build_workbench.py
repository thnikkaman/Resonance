#!/usr/bin/env python3
"""Audit, scope, plan, and verify future Resonance builds.

This tool is intentionally repository-local and dependency-free. It does not
invoke Xcode or mutate source files. It turns the current checkout into a
machine-readable contract, maps changed files to required validation, creates
an evidence workspace, and verifies release claims.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Sequence

SCHEMA_VERSION = 1
DEFAULT_REPOSITORY = "thnikkaman/Resonance"
DEFAULT_REF = "agent/alpha-3.7.4-source"

PERMISSION_NAMES = (
    "signed_device_install",
    "launch_physical_app",
    "use_remote_credentials",
    "use_private_media",
    "destructive_library_actions",
)

REQUIRED_PATHS = (
    "README.md",
    "Resonance.xcodeproj/project.pbxproj",
    "Resonance/Info.plist",
    "Resonance/ResonanceApp.swift",
    "Resonance/Views/SettingsView.swift",
    ".xcodebuildmcp/config.yaml",
    "Tools/RegressionChecks.sh",
    "Tools/PreflightBuild.sh",
    "Tools/ResonanceServer.py",
)

CURRENT_CONTRACT_SYMBOLS = (
    ("Resonance/Services/LibraryStore.swift", "isBootstrapping"),
    ("Resonance/Services/RemoteLibraryStore.swift", "loadCachedStartupStateIfNeeded"),
    ("Resonance/Services/RemoteLibraryStore.swift", "prewarmBrowseCache"),
    ("Resonance/Services/RemoteLibraryStore.swift", "makeBrowseCache"),
    ("Resonance/ResonanceApp.swift", "prewarmBrowseCache"),
)

SENSITIVE_COMMAND_PATTERNS = (
    re.compile(r"(?:password|passwd|token|secret|authorization|credential)\s*[=:]", re.I),
    re.compile(r"https?://[^\s/@:]+:[^\s/@]+@", re.I),
)


def contains_sensitive_text(value: str) -> bool:
    return any(pattern.search(value) for pattern in SENSITIVE_COMMAND_PATTERNS)


def relative_evidence_path(value: str) -> Path | None:
    if not value:
        return None
    path = Path(value)
    if path.is_absolute() or ".." in path.parts:
        return None
    return path


@dataclass(frozen=True)
class Finding:
    severity: str
    code: str
    message: str
    path: str | None = None

    def as_dict(self) -> dict[str, object]:
        return {
            "severity": self.severity,
            "code": self.code,
            "message": self.message,
            "path": self.path,
        }


SUBSYSTEMS: dict[str, dict[str, object]] = {
    "release-contract": {
        "risk": 3,
        "patterns": [
            "README.md",
            "Resonance.xcodeproj/project.pbxproj",
            "Resonance/Info.plist",
            ".xcodebuildmcp/*",
            "Tools/RegressionChecks.sh",
            "Tools/PreflightBuild.sh",
        ],
        "guardrails": [
            "Keep Debug and Release marketing/build values identical.",
            "Keep Info.plist build/version values inherited from project settings.",
            "Reconcile README release source, latest device validation, regression assertions, and the regression success label.",
            "Do not claim a signed or installed build unless evidence records the exact artifact and device action.",
        ],
        "validations": [
            "Run the strict repository contract audit.",
            "Run plist/project lint, RegressionChecks.sh, git diff --check, and PreflightBuild.sh.",
            "Verify source membership for every new Swift file.",
            "Verify archive/ZIP integrity and record version/build from the produced app bundle.",
        ],
    },
    "app-lifecycle-startup": {
        "risk": 4,
        "patterns": ["Resonance/ResonanceApp.swift", "Resonance/Services/LibraryStore.swift"],
        "guardrails": [
            "Preserve cache-first startup and explicit refresh semantics.",
            "Keep display-cache and file inventory I/O off the main actor.",
            "Reject stale remote browse prewarm results by catalog revision and sort state.",
            "Do not resume persisted downloads before remote activation and local-store readiness are coherent.",
        ],
        "validations": [
            "Cold first launch with a known fixture.",
            "Warm local startup with cached rows and deferred artwork hydration.",
            "Warm remote offline startup with cached browse data.",
            "Rapid active/background/active scene transitions without duplicate scans or stale publication.",
        ],
    },
    "local-library-database": {
        "risk": 4,
        "patterns": [
            "Resonance/Models/*",
            "Resonance/Services/LibraryDatabase.swift",
            "Resonance/Services/LibraryStore.swift",
            "Resonance/Services/LibraryBrowseGrouping.swift",
        ],
        "guardrails": [
            "Preserve stable track, artist, album, and section identity and deterministic ordering.",
            "Use targeted refresh/upsert after one-file changes; never replace it with a full Documents scan.",
            "Preserve ignored-path behavior for Remove from Library versus Delete from iPhone.",
            "Do not load artwork blobs before the first usable cached-library frame.",
        ],
        "validations": [
            "Large-library grouping and alphabet navigation parity.",
            "Targeted completed-download refresh while local detail views remain open.",
            "Remove from Library and Delete from iPhone persistence across manual scan and relaunch.",
            "SQLite record-count and unrelated-ID preservation checks.",
        ],
    },
    "metadata": {
        "risk": 4,
        "patterns": [
            "Resonance/Services/MetadataReader.swift",
            "Resonance/Services/MetadataWriteBatch.swift",
            "Resonance/Views/SmartLibraryViews.swift",
        ],
        "guardrails": [
            "Preserve direct FLAC/MP3 writes, unsupported-format errors, and per-file result accounting.",
            "Keep the editor responsive while sequential writes and targeted rereads continue.",
            "Preserve embedded-artwork versus app-only artwork warning semantics.",
        ],
        "validations": [
            "Edit FLAC and MP3 title, artist, album artist, album, track/disc, year, and optional artwork.",
            "Verify tags with an external reader and after relaunch.",
            "Verify unsupported formats report read-only behavior without claiming a write.",
            "Verify no unrelated library record disappears and no full scan occurs.",
        ],
    },
    "remote-catalog": {
        "risk": 4,
        "patterns": [
            "Resonance/Services/RemoteLibraryStore.swift",
            "Resonance/Services/RemoteURLSupport.swift",
            "Resonance/Views/StreamingLibraryView.swift",
        ],
        "guardrails": [
            "Keep cached catalogs usable while offline and make server checks explicit.",
            "Key browse caches by revision, sort direction, compilation grouping, and every semantic input.",
            "Latest generation wins; stale catalog, browse, artwork, and playback preparation cannot publish.",
            "Preserve Navidrome/OpenSubsonic identity, canonical album-artist grouping, favorites, playlists, and scrobbling behavior.",
        ],
        "validations": [
            "Cached offline browse and explicit failed refresh without cache loss.",
            "Large catalog first Streaming transition and all grouping/sort surfaces.",
            "Rapid repeated refresh with stale-result rejection.",
            "Compilation and mixed-artist parity across Artists, Album Artists, and Albums.",
        ],
    },
    "downloads": {
        "risk": 5,
        "patterns": [
            "Resonance/Services/RemoteDownloadService.swift",
            "Resonance/Views/StreamingLibraryView.swift",
            "Resonance/ResonanceApp.swift",
        ],
        "guardrails": [
            "Preserve queue order, bounded progress publication, cancellation cleanup, and background-session restoration.",
            "Never index a partial file and keep Replace Existing versus Keep Existing explicit and duplicate-safe.",
            "Index each completed track with a targeted local upsert/refresh.",
            "Treat force-quit, lock-screen continuation, and background delivery as physical-device behavior.",
        ],
        "validations": [
            "Queue, cancel active/queued, requeue, cancel all, and verify .part cleanup.",
            "Replace Existing and Keep Existing with one resulting library record.",
            "Multi-track album/artist download with incremental local indexing.",
            "Background suspension/restore on a physical device with explicit authorization.",
        ],
    },
    "playback-controller": {
        "risk": 5,
        "patterns": ["Resonance/Services/PlayerController.swift", "Resonance/Views/PlayerViews.swift"],
        "guardrails": [
            "Keep high-frequency elapsed and meter state outside broad PlayerController publication.",
            "Preserve queue/current-index, repeat, shuffle, play-next, add-to-queue, and Now Playing command semantics.",
            "Pending remote seek targets remain authoritative and stale completions cannot win.",
            "Clamp elapsed/remaining values at exact end and preserve stable single-item remote fallback.",
        ],
        "validations": [
            "Local and remote start/pause/resume/seek/end/next/previous/repeat/shuffle matrix.",
            "Rapid remote seek and exact-end seek with target/actual diagnostic correlation.",
            "Lock Screen previous/next and in-app seek behavior.",
            "Long-running playback while switching tabs and scrolling Streaming.",
        ],
    },
    "audio-engine": {
        "risk": 5,
        "patterns": ["Resonance/Services/GaplessAudioEngine.swift"],
        "guardrails": [
            "Preserve Matrix Mixer routing/gains, native source sample rate, preload compatibility, timeline generations, and quarantine fallback.",
            "Do not infer audible gaplessness, speed, or 5.1 routing from simulator control flow.",
            "Keep failed graphs alive but disconnected for the session when the circuit breaker requires it.",
        ],
        "validations": [
            "Simulator control-flow fixture for boundaries, preload, seek, and fallback.",
            "Physical-device stereo/high-rate/5.1 speed and channel-routing acceptance.",
            "Matrix failure to compatibility playback without process termination.",
            "Route change and next-track behavior after a failed graph.",
        ],
    },
    "navigation-ui": {
        "risk": 4,
        "patterns": [
            "Resonance/Views/RootView.swift",
            "Resonance/Views/LibraryView.swift",
            "Resonance/Views/AlbumDetailView.swift",
            "Resonance/Views/StreamingLibraryView.swift",
        ],
        "guardrails": [
            "Preserve layered navigation, stable tab/detail identity, safe areas, hit testing, accessibility visibility, and gesture ownership.",
            "Do not let selection, alphabet, tab-swipe, mini-player, or hierarchy gestures steal normal vertical scrolling.",
            "Keep the custom tab bar and mini-player clear of content in every dock position.",
        ],
        "validations": [
            "Tap and swipe through every tab while playback runs.",
            "Library/Streaming artist and album detail navigation and top-down/back gestures.",
            "Alphabet index first/middle/last, repeated letter, and ordinary scroll behavior.",
            "Mini-player top/bottom/side docking, restore, overshoot, keyboard, safe area, and accessibility checks.",
        ],
    },
    "artwork": {
        "risk": 4,
        "patterns": [
            "Resonance/Views/ArtworkView.swift",
            "Resonance/Services/ArtworkSearchService.swift",
            "Resonance/Views/OnlineArtworkSearchView.swift",
            "Resonance/Assets.xcassets/*",
        ],
        "guardrails": [
            "Decode/downsample outside SwiftUI body and off the main actor; bound caches by count/cost and pixel size.",
            "Preserve source precedence, credible-match rules, recommended selection, warning state, and sidecar persistence.",
            "Do not share scrolling thumbnail work with playback artwork preparation.",
        ],
        "validations": [
            "Large local and remote artwork scroll with allocations and cache-hit evidence.",
            "Online provider partial failure and fallback queries.",
            "Embedded, downloaded, app-only, and automatically selected warning states.",
            "Artwork persistence after relaunch and external tag verification when written to file.",
        ],
    },
    "settings-theme": {
        "risk": 3,
        "patterns": ["Resonance/Services/AppSettings.swift", "Resonance/Views/SettingsView.swift"],
        "guardrails": [
            "Do not make RootView observe the entire settings object or retheme inactive trees per keystroke.",
            "Preserve draft/debounce editing, focus, dynamic build display, persisted category state, and theme contrast.",
            "Never log credentials, server addresses, QR contents, or private artwork.",
        ],
        "validations": [
            "Hex/color editing with keyboard and playback active.",
            "Every visual style in light/dark/system appearance with readable contrast.",
            "Category expansion persistence and no inactive-tab redraw storm.",
            "QR plain URL/host parsing, denied camera permission, and credential-free payload behavior.",
        ],
    },
    "diagnostics-errors": {
        "risk": 4,
        "patterns": [
            "Resonance/Services/ResonanceDiagnostics.swift",
            "Resonance/Services/AppErrorLog.swift",
        ],
        "guardrails": [
            "Use synchronous diagnostics only for crash-critical boundaries and deferred diagnostics for optional UI/catalog timing.",
            "Never record titles, paths, URLs, hosts, usernames, credentials, QR payloads, or media data.",
            "Diagnostics and error reporting must never interfere with startup or playback.",
        ],
        "validations": [
            "Run the bundled diagnostics privacy audit on fresh logs.",
            "Verify bounded file behavior and deletion/copy controls.",
            "Correlate boundary events to behavior without private identifiers.",
        ],
    },
    "fixture-server": {
        "risk": 3,
        "patterns": ["Tools/ResonanceServer.py"],
        "guardrails": [
            "Preserve manifest metadata, range requests, content lengths, and deterministic fixture ordering.",
            "Do not expose private media or credentials in committed fixtures or logs.",
        ],
        "validations": [
            "Python compile and deterministic manifest output.",
            "Range, seek, exact-end, invalid-range, and concurrent request tests.",
            "Simulator playback against known stereo and multichannel fixtures.",
        ],
    },
}

GLOBAL_VALIDATIONS = (
    "python3 -m unittest discover -s <skill>/scripts -p 'test_*.py'",
    "python3 <skill>/scripts/resonance_build_workbench.py audit <repo> --strict",
    "bash Tools/RegressionChecks.sh",
    "git diff --check",
    "bash Tools/PreflightBuild.sh",
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8")


def run_git(repo: Path, *args: str) -> tuple[int, str, str]:
    try:
        completed = subprocess.run(
            ["git", "-C", str(repo), *args],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except OSError as exc:
        return 127, "", str(exc)
    return completed.returncode, completed.stdout.strip(), completed.stderr.strip()


def parse_project_values(text: str, key: str) -> list[str]:
    return [value.strip().strip('"') for value in re.findall(rf"\b{re.escape(key)}\s*=\s*([^;]+);", text)]


def unique(values: Iterable[str]) -> list[str]:
    return sorted(set(values))


def first_match(pattern: str, text: str, flags: int = 0) -> tuple[str, ...] | None:
    match = re.search(pattern, text, flags)
    return tuple(match.groups()) if match else None


def parse_readme_contract(text: str) -> dict[str, object]:
    stable = first_match(r"Current stable beta\s+[\-—]+\s+([0-9.]+)\s+\(build\s+([0-9]+)\)", text)
    release = first_match(r"Release source build:\s*`([0-9.]+)`\s*\(build\s*`([0-9]+)`\)", text)
    latest = first_match(r"Latest device validation build:\s*`([0-9.]+)`\s*\(build\s*`([0-9]+)`\)", text)
    tag = first_match(r"Authoritative continuation source:\s*the\s*`([^`]+)`\s*tag\s*on\s*`([^`]+)`", text)
    lowered = text.lower()
    if "physical app was not launched" in lowered or "app was not launched" in lowered:
        launch_status = "not-launched"
    elif "physical app was launched" in lowered or "app was launched" in lowered:
        launch_status = "launched"
    else:
        launch_status = "unspecified"
    return {
        "stable": {"version": stable[0], "build": int(stable[1])} if stable else None,
        "release_source": {"version": release[0], "build": int(release[1])} if release else None,
        "latest_device_validation": {"version": latest[0], "build": int(latest[1])} if latest else None,
        "authoritative_tag": {"tag": tag[0], "ref": tag[1]} if tag else None,
        "device_launch_status": launch_status,
        "device_not_launched": launch_status == "not-launched",
    }


def parse_regression_contract(text: str) -> dict[str, object]:
    build = first_match(r"CURRENT_PROJECT_VERSION = ([0-9]+);'\)\s*==\s*2", text)
    version = first_match(r"MARKETING_VERSION = ([0-9.]+);'\)\s*==\s*2", text)
    label = first_match(r"print\(['\"]Resonance Beta v([0-9.]+) regression checks passed\.", text)
    return {
        "expected_build": int(build[0]) if build else None,
        "expected_version": version[0] if version else None,
        "success_label_version": label[0] if label else None,
    }


def parse_xcodebuildmcp(text: str) -> dict[str, str | None]:
    def value_for(key: str) -> str | None:
        match = re.search(rf"^\s*{re.escape(key)}:\s*(.+?)\s*$", text, re.M)
        return match.group(1).strip().strip('"\'') if match else None

    return {
        "project_path": value_for("projectPath"),
        "scheme": value_for("scheme"),
        "simulator_name": value_for("simulatorName"),
    }


def project_source_membership(project_text: str, repo: Path) -> dict[str, object]:
    members = unique(re.findall(r"/\*\s*([^*/]+\.swift) in Sources\s*\*/", project_text))
    disk_paths = sorted(path.relative_to(repo).as_posix() for path in (repo / "Resonance").rglob("*.swift"))
    disk_by_name: dict[str, list[str]] = {}
    for path in disk_paths:
        disk_by_name.setdefault(Path(path).name, []).append(path)
    missing_membership = [path for path in disk_paths if Path(path).name not in members]
    missing_files = [name for name in members if name not in disk_by_name]
    duplicate_names = {name: paths for name, paths in disk_by_name.items() if len(paths) > 1}
    return {
        "project_source_basenames": members,
        "disk_swift_files": disk_paths,
        "missing_project_membership": missing_membership,
        "project_members_without_file": missing_files,
        "duplicate_swift_basenames": duplicate_names,
    }


def git_snapshot(repo: Path) -> dict[str, object]:
    code, commit, _ = run_git(repo, "rev-parse", "HEAD")
    branch_code, branch, _ = run_git(repo, "branch", "--show-current")
    status_code, status, _ = run_git(repo, "status", "--porcelain=v1")
    return {
        "available": code == 0,
        "commit": commit if code == 0 else None,
        "branch": branch if branch_code == 0 and branch else None,
        "dirty": bool(status) if status_code == 0 else None,
        "status_lines": status.splitlines() if status_code == 0 and status else [],
    }


def audit_repository(repo: Path) -> dict[str, object]:
    repo = repo.resolve()
    findings: list[Finding] = []
    for relative in REQUIRED_PATHS:
        if not (repo / relative).is_file():
            findings.append(Finding("error", "missing-required-path", f"Required file is missing: {relative}", relative))

    if any(item.severity == "error" for item in findings):
        return {
            "schema_version": SCHEMA_VERSION,
            "generated_at": utc_now(),
            "repository_path": str(repo),
            "findings": [item.as_dict() for item in findings],
            "summary": summarize_findings(findings),
        }

    readme = read_text(repo / "README.md")
    project = read_text(repo / "Resonance.xcodeproj/project.pbxproj")
    plist = read_text(repo / "Resonance/Info.plist")
    regression = read_text(repo / "Tools/RegressionChecks.sh")
    preflight = read_text(repo / "Tools/PreflightBuild.sh")
    mcp = read_text(repo / ".xcodebuildmcp/config.yaml")
    settings_view = read_text(repo / "Resonance/Views/SettingsView.swift")

    versions = unique(parse_project_values(project, "MARKETING_VERSION"))
    builds = unique(parse_project_values(project, "CURRENT_PROJECT_VERSION"))
    swift_defaults = unique(parse_project_values(project, "SWIFT_VERSION"))
    readme_contract = parse_readme_contract(readme)
    regression_contract = parse_regression_contract(regression)
    mcp_contract = parse_xcodebuildmcp(mcp)
    membership = project_source_membership(project, repo)
    git = git_snapshot(repo)

    if len(versions) != 1:
        findings.append(Finding("error", "project-version-divergence", f"Expected one MARKETING_VERSION across target configurations, found {versions}.", "Resonance.xcodeproj/project.pbxproj"))
    if len(builds) != 1:
        findings.append(Finding("error", "project-build-divergence", f"Expected one CURRENT_PROJECT_VERSION across target configurations, found {builds}.", "Resonance.xcodeproj/project.pbxproj"))

    project_version = versions[0] if len(versions) == 1 else None
    try:
        project_build = int(builds[0]) if len(builds) == 1 else None
    except ValueError:
        project_build = None
        findings.append(Finding("error", "non-numeric-build", f"CURRENT_PROJECT_VERSION must be numeric, found {builds[0]!r}.", "Resonance.xcodeproj/project.pbxproj"))

    if "$(MARKETING_VERSION)" not in plist or "$(CURRENT_PROJECT_VERSION)" not in plist:
        findings.append(Finding("error", "plist-version-inheritance", "Info.plist must inherit marketing and build versions from project settings.", "Resonance/Info.plist"))

    for bundle_key in ("CFBundleShortVersionString", "CFBundleVersion"):
        if f'Bundle.main.object(forInfoDictionaryKey: "{bundle_key}")' not in settings_view:
            findings.append(Finding("warning", "settings-build-display-drift", f"SettingsView.swift should read {bundle_key} dynamically from Bundle metadata.", "Resonance/Views/SettingsView.swift"))

    release = readme_contract.get("release_source")
    stable = readme_contract.get("stable")
    latest = readme_contract.get("latest_device_validation")
    if not release:
        findings.append(Finding("warning", "missing-readme-release-source", "README does not expose a parseable release source build.", "README.md"))
    elif project_version is not None and project_build is not None:
        if release["version"] != project_version or release["build"] != project_build:
            findings.append(Finding("warning", "release-source-drift", f"README release source is {release['version']} ({release['build']}) but project settings are {project_version} ({project_build}).", "README.md"))
    if stable and release and stable != release:
        findings.append(Finding("warning", "stable-release-drift", f"README stable beta {stable} differs from release source {release}.", "README.md"))
    if latest and project_build is not None and latest["build"] > project_build:
        findings.append(Finding("warning", "device-build-ahead-of-source", f"README records device validation build {latest['build']} while project settings remain build {project_build}. Resolve provenance before choosing the next build number or claiming a release.", "README.md"))

    if latest and readme_contract.get("device_launch_status") == "unspecified":
        findings.append(Finding("warning", "device-launch-status-unspecified", "README records a latest device validation build but does not state whether the physical app was launched.", "README.md"))
    authoritative = readme_contract.get("authoritative_tag")
    if authoritative and authoritative.get("ref") != DEFAULT_REF:
        findings.append(Finding("warning", "authoritative-ref-drift", f"README authoritative continuation ref is {authoritative.get('ref')!r}; this skill targets {DEFAULT_REF!r}.", "README.md"))

    expected_build = regression_contract.get("expected_build")
    expected_version = regression_contract.get("expected_version")
    label_version = regression_contract.get("success_label_version")
    if expected_build is None or expected_version is None:
        findings.append(Finding("error", "missing-regression-version-assertion", "RegressionChecks.sh must assert both project build and marketing version twice.", "Tools/RegressionChecks.sh"))
    else:
        if project_build is not None and expected_build != project_build:
            findings.append(Finding("error", "regression-build-drift", f"RegressionChecks.sh expects build {expected_build}, project settings use {project_build}.", "Tools/RegressionChecks.sh"))
        if project_version is not None and expected_version != project_version:
            findings.append(Finding("error", "regression-version-drift", f"RegressionChecks.sh expects version {expected_version}, project settings use {project_version}.", "Tools/RegressionChecks.sh"))
    if label_version and project_version and label_version != project_version:
        findings.append(Finding("warning", "regression-label-drift", f"RegressionChecks.sh success label says v{label_version}, but project marketing version is {project_version}.", "Tools/RegressionChecks.sh"))
    elif label_version is None:
        findings.append(Finding("warning", "missing-regression-label", "RegressionChecks.sh has no parseable versioned success label.", "Tools/RegressionChecks.sh"))

    required_preflight_tokens = (
        "SWIFT_VERSION=6",
        "SWIFT_STRICT_CONCURRENCY=complete",
        "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES",
        "iphonesimulator",
        "iphoneos",
    )
    for token in required_preflight_tokens:
        if token not in preflight:
            findings.append(Finding("error", "preflight-contract-missing", f"PreflightBuild.sh is missing required token {token!r}.", "Tools/PreflightBuild.sh"))

    if mcp_contract != {
        "project_path": "./Resonance.xcodeproj",
        "scheme": "Resonance",
        "simulator_name": "iPhone 17 Pro",
    }:
        findings.append(Finding("warning", "xcodebuildmcp-default-drift", f"Unexpected XcodeBuildMCP defaults: {mcp_contract}.", ".xcodebuildmcp/config.yaml"))

    for missing in membership["missing_project_membership"]:
        findings.append(Finding("error", "swift-file-not-in-target", f"Swift source exists on disk but is not listed in the target Sources phase: {missing}.", missing))
    for missing in membership["project_members_without_file"]:
        findings.append(Finding("error", "project-source-missing-on-disk", f"Target Sources phase references {missing}, but no matching Swift file exists.", "Resonance.xcodeproj/project.pbxproj"))
    if membership["duplicate_swift_basenames"]:
        findings.append(Finding("warning", "duplicate-swift-basename", f"Duplicate Swift basenames make the membership audit ambiguous: {membership['duplicate_swift_basenames']}.", "Resonance"))

    for source_path, symbol in CURRENT_CONTRACT_SYMBOLS:
        path = repo / source_path
        if path.is_file() and symbol in read_text(path) and symbol not in regression:
            findings.append(Finding("warning", "unprotected-current-contract", f"Current source contains {symbol!r}, but RegressionChecks.sh does not protect that continuation contract.", source_path))

    if swift_defaults and swift_defaults != ["6"]:
        findings.append(Finding("info", "project-default-swift-version", f"Project default SWIFT_VERSION values are {swift_defaults}; repository validation intentionally overrides Swift 6 strict concurrency.", "Resonance.xcodeproj/project.pbxproj"))

    findings.sort(key=lambda item: ({"error": 0, "warning": 1, "info": 2}.get(item.severity, 3), item.code, item.path or ""))
    max_known_build = max(
        [value for value in [project_build, stable["build"] if stable else None, release["build"] if release else None, latest["build"] if latest else None] if isinstance(value, int)],
        default=0,
    )
    return {
        "schema_version": SCHEMA_VERSION,
        "generated_at": utc_now(),
        "repository_path": str(repo),
        "git": git,
        "project": {
            "marketing_versions": versions,
            "build_versions": builds,
            "marketing_version": project_version,
            "build": project_build,
            "swift_defaults": swift_defaults,
        },
        "readme": readme_contract,
        "regression": regression_contract,
        "xcodebuildmcp": mcp_contract,
        "source_membership": membership,
        "suggested_next_build": max_known_build + 1 if max_known_build else None,
        "findings": [item.as_dict() for item in findings],
        "summary": summarize_findings(findings),
    }


def summarize_findings(findings: Sequence[Finding]) -> dict[str, int | str]:
    counts = {severity: sum(1 for item in findings if item.severity == severity) for severity in ("error", "warning", "info")}
    status = "error" if counts["error"] else "warning" if counts["warning"] else "pass"
    return {**counts, "status": status}


def matches_any(path: str, patterns: Sequence[str]) -> bool:
    return any(fnmatch.fnmatch(path, pattern) for pattern in patterns)


def changed_files_from_git(repo: Path, base: str | None = None) -> tuple[list[str], list[str]]:
    warnings: list[str] = []
    if base:
        code, output, error = run_git(repo, "diff", "--name-only", f"{base}...HEAD", "--")
        if code != 0:
            warnings.append(f"Could not diff {base}...HEAD: {error or 'git diff failed'}")
            return [], warnings
        return sorted(set(line for line in output.splitlines() if line)), warnings

    files: set[str] = set()
    for args in (("diff", "--name-only", "--"), ("diff", "--cached", "--name-only", "--"), ("ls-files", "--others", "--exclude-standard")):
        code, output, error = run_git(repo, *args)
        if code != 0:
            warnings.append(error or f"git {' '.join(args)} failed")
            continue
        files.update(line for line in output.splitlines() if line)
    return sorted(files), warnings


def scope_changes(repo: Path, files: Sequence[str], base: str | None = None) -> dict[str, object]:
    repo = repo.resolve()
    warnings: list[str] = []
    normalized = sorted(set(Path(path).as_posix().lstrip("./") for path in files if path.strip()))
    if not normalized:
        normalized, warnings = changed_files_from_git(repo, base=base)

    categories: list[dict[str, object]] = []
    matched_files: set[str] = set()
    for name, rule in SUBSYSTEMS.items():
        patterns = rule["patterns"]
        assert isinstance(patterns, list)
        hits = [path for path in normalized if matches_any(path, patterns)]
        if not hits:
            continue
        matched_files.update(hits)
        categories.append(
            {
                "name": name,
                "risk": rule["risk"],
                "files": hits,
                "guardrails": rule["guardrails"],
                "validations": rule["validations"],
            }
        )
    unmatched = [path for path in normalized if path not in matched_files]
    if unmatched:
        categories.append(
            {
                "name": "unclassified",
                "risk": 3,
                "files": unmatched,
                "guardrails": ["Inspect ownership and user-visible contracts before editing; do not assume an unclassified file is low risk."],
                "validations": ["Add a targeted regression assertion and manual acceptance path for the behavior owned by each unclassified file."],
            }
        )

    max_risk = max((int(category["risk"]) for category in categories), default=1)
    requires_device = any(category["name"] in {"downloads", "playback-controller", "audio-engine"} for category in categories)
    requires_remote = any(category["name"] in {"remote-catalog", "downloads", "playback-controller"} for category in categories)
    requires_destructive = any(category["name"] in {"local-library-database", "downloads"} for category in categories)
    all_validations: list[str] = list(GLOBAL_VALIDATIONS)
    for category in categories:
        for validation in category["validations"]:
            if validation not in all_validations:
                all_validations.append(validation)

    return {
        "schema_version": SCHEMA_VERSION,
        "generated_at": utc_now(),
        "repository_path": str(repo),
        "changed_files": normalized,
        "categories": categories,
        "max_risk": max_risk,
        "requires_physical_device": requires_device,
        "requires_remote_credentials_or_fixture": requires_remote,
        "may_require_destructive_library_actions": requires_destructive,
        "global_validations": list(GLOBAL_VALIDATIONS),
        "required_validations": all_validations,
        "warnings": warnings,
    }


def audit_markdown(data: dict[str, object]) -> str:
    project = data.get("project", {})
    git = data.get("git", {})
    readme = data.get("readme", {})
    summary = data.get("summary", {})
    lines = ["# Resonance repository contract audit", ""]
    lines.append(f"- Status: **{summary.get('status', 'unknown')}**")
    lines.append(f"- Repository path: `{data.get('repository_path')}`")
    if isinstance(git, dict):
        lines.append(f"- Git branch: `{git.get('branch') or 'unavailable'}`")
        lines.append(f"- Git commit: `{git.get('commit') or 'unavailable'}`")
        lines.append(f"- Dirty checkout: `{git.get('dirty')}`")
    if isinstance(project, dict):
        lines.append(f"- Project version/build: `{project.get('marketing_version')}` / `{project.get('build')}`")
    if isinstance(readme, dict):
        lines.append(f"- README latest device validation: `{readme.get('latest_device_validation')}`")
    lines.append(f"- Suggested next build: `{data.get('suggested_next_build')}`")
    lines.extend(["", "## Findings", "", "| Severity | Code | Path | Finding |", "|---|---|---|---|"])
    findings = data.get("findings", [])
    assert isinstance(findings, list)
    if not findings:
        lines.append("| pass | none |  | No contract drift detected. |")
    for finding in findings:
        path = str(finding.get("path") or "").replace("|", "\\|")
        message = str(finding.get("message") or "").replace("|", "\\|")
        lines.append(f"| {finding.get('severity')} | `{finding.get('code')}` | `{path}` | {message} |")
    return "\n".join(lines) + "\n"


def scope_markdown(data: dict[str, object]) -> str:
    lines = ["# Resonance change scope", ""]
    lines.append(f"- Changed files: {len(data.get('changed_files', []))}")
    lines.append(f"- Maximum risk: **{data.get('max_risk')}/5**")
    lines.append(f"- Physical-device acceptance required: **{data.get('requires_physical_device')}**")
    lines.append(f"- Remote credential or fixture path required: **{data.get('requires_remote_credentials_or_fixture')}**")
    lines.append(f"- Destructive library authorization may be required: **{data.get('may_require_destructive_library_actions')}**")
    lines.extend(["", "## Changed files", ""])
    for path in data.get("changed_files", []):
        lines.append(f"- `{path}`")
    if not data.get("changed_files"):
        lines.append("- No changed files detected.")
    for category in data.get("categories", []):
        lines.extend(["", f"## {category['name']} (risk {category['risk']}/5)", "", "Files:"])
        for path in category["files"]:
            lines.append(f"- `{path}`")
        lines.extend(["", "Guardrails:"])
        for item in category["guardrails"]:
            lines.append(f"- {item}")
        lines.extend(["", "Required acceptance:"])
        for item in category["validations"]:
            lines.append(f"- {item}")
    lines.extend(["", "## Global gates", ""])
    for item in data.get("global_validations", []):
        lines.append(f"- `{item}`")
    warnings = data.get("warnings", [])
    if warnings:
        lines.extend(["", "## Warnings", ""])
        for item in warnings:
            lines.append(f"- {item}")
    return "\n".join(lines) + "\n"


def validation_key(text: str) -> str:
    key = re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")
    return key[:80] or "validation"


def make_validation_entries(scope: dict[str, object]) -> dict[str, dict[str, str]]:
    entries: dict[str, dict[str, str]] = {}

    def add_entry(base_key: str, entry: dict[str, str]) -> None:
        key = base_key
        suffix = 2
        while key in entries:
            key = f"{base_key}_{suffix}"
            suffix += 1
        entries[key] = entry

    global_commands = [str(item) for item in scope.get("global_validations", [])]
    for command in global_commands:
        add_entry(
            validation_key(command),
            {"status": "pending", "kind": "command", "command": command, "evidence": "", "notes": ""},
        )

    for validation in (str(item) for item in scope.get("required_validations", [])):
        if validation in global_commands:
            continue
        add_entry(
            f"runtime_{validation_key(validation)}",
            {
                "status": "pending",
                "kind": "manual",
                "command": "",
                "evidence": "",
                "notes": validation,
            },
        )

    add_entry(
        "produced_app_bundle_identity",
        {
            "status": "pending",
            "kind": "command",
            "command": "Read CFBundleShortVersionString and CFBundleVersion from the produced Resonance.app bundle.",
            "evidence": "",
            "notes": "Record the exact artifact path and values; source settings alone are not bundle proof.",
        },
    )
    add_entry(
        "readme_and_release_provenance_review",
        {
            "status": "pending",
            "kind": "manual",
            "command": "",
            "evidence": "",
            "notes": "Confirm release-source, device install/test, and physical launch statements describe only actions actually completed.",
        },
    )
    add_entry(
        "artifact_integrity",
        {
            "status": "pending",
            "kind": "command",
            "command": "Verify the final archive or ZIP integrity and record its checksum.",
            "evidence": "",
            "notes": "Mark not-applicable only when no distributable artifact is part of the build decision.",
        },
    )

    if scope.get("requires_physical_device"):
        entries["physical_device_runtime_acceptance"] = {"status": "pending", "kind": "manual", "command": "", "evidence": "", "notes": "Do not sign, install, or launch without explicit user authorization. Record install and launch as separate facts."}
    if scope.get("requires_remote_credentials_or_fixture"):
        entries["remote_fixture_or_authorized_server_acceptance"] = {"status": "pending", "kind": "manual", "command": "", "evidence": "", "notes": "Prefer a local fixture; never store credentials, private URLs, or private media in the workspace."}
    return entries


def init_workspace(args: argparse.Namespace) -> int:
    root: Path = args.directory.resolve()
    if root.exists() and any(root.iterdir()) and not args.force:
        print(f"error: {root} is not empty; use --force to overwrite generated files", file=sys.stderr)
        return 2
    root.mkdir(parents=True, exist_ok=True)
    audit = audit_repository(args.repo)
    scope = scope_changes(args.repo, args.files, base=args.base)
    project = audit.get("project", {})
    git = audit.get("git", {})
    version = args.version or (project.get("marketing_version") if isinstance(project, dict) else None) or "0.0.0"
    build = args.build or audit.get("suggested_next_build")
    if not isinstance(build, int) or build < 1:
        print("error: could not infer a build number; pass --build", file=sys.stderr)
        return 2
    ref = args.ref or (git.get("branch") if isinstance(git, dict) else None) or DEFAULT_REF
    commit = args.commit or (git.get("commit") if isinstance(git, dict) else None)
    if not commit:
        print("error: could not resolve a source commit; pass --commit", file=sys.stderr)
        return 2

    manifest = {
        "schema_version": SCHEMA_VERSION,
        "created_at": utc_now(),
        "repository": args.repository,
        "repository_path": str(args.repo.resolve()),
        "ref": ref,
        "commit": commit,
        "dirty_at_start": git.get("dirty") if isinstance(git, dict) else None,
        "intent": args.intent,
        "issue_or_pr": args.issue_or_pr,
        "version": version,
        "build": build,
        "baseline_project_build": project.get("build") if isinstance(project, dict) else None,
        "latest_documented_device_build": (audit.get("readme", {}).get("latest_device_validation") or {}).get("build") if isinstance(audit.get("readme"), dict) else None,
        "changed_files": scope.get("changed_files", []),
        "scope_categories": [category["name"] for category in scope.get("categories", [])],
        "max_risk": scope.get("max_risk"),
        "permissions": {
            "signed_device_install": False,
            "launch_physical_app": False,
            "use_remote_credentials": False,
            "use_private_media": False,
            "destructive_library_actions": False,
        },
        "validation": make_validation_entries(scope),
        "rollback": {"reference": "", "instructions": "", "verified": False},
        "release_decision": "pending",
    }
    write_json(root / "manifest.json", manifest)
    write_json(root / "contract-audit.json", audit)
    write_json(root / "change-scope.json", scope)
    write_text(root / "contract-audit.md", audit_markdown(audit))
    write_text(root / "change-scope.md", scope_markdown(scope))
    write_text(root / "change-plan.md", change_plan_template(manifest, audit, scope))
    write_text(root / "validation-plan.md", validation_plan_template(manifest, scope))
    write_text(root / "acceptance.md", acceptance_template(manifest, scope))
    write_text(root / "release-note.md", release_note_template(manifest))
    write_text(root / "evidence/README.md", evidence_readme())
    write_text(root / "evidence/commands.jsonl", "")
    write_text(root / "evidence/permissions.jsonl", "")
    for directory in ("evidence/build", "evidence/simulator", "evidence/device", "evidence/diagnostics", "evidence/screenshots", "performance"):
        (root / directory).mkdir(parents=True, exist_ok=True)
    print(f"Created {root}")
    print(f"Planned Resonance {version} build {build} from {ref}@{commit}")
    return 0


def change_plan_template(manifest: dict[str, object], audit: dict[str, object], scope: dict[str, object]) -> str:
    findings = audit.get("findings", [])
    warnings = [item for item in findings if item.get("severity") in {"error", "warning"}]
    lines = [
        "# Resonance change plan",
        "",
        "## Source",
        f"- Repository/ref: `{manifest['repository']}` / `{manifest['ref']}`",
        f"- Commit: `{manifest['commit']}`",
        f"- Dirty at start: `{manifest['dirty_at_start']}`",
        f"- Planned version/build: `{manifest['version']}` / `{manifest['build']}`",
        "",
        "## Primary intent",
        str(manifest["intent"]),
        "",
        "## Success criteria",
        "- [TODO] State the user-visible outcome in observable terms.",
        "- [TODO] State the measurable or reproducible acceptance signal.",
        "",
        "## Non-goals",
        "- [TODO] List adjacent cleanup, redesign, or experiments that must not enter this build.",
        "",
        "## Continuation contracts",
        "- Preserve cache-first startup and explicit refresh behavior.",
        "- Preserve stable identity, ordering, queue/state transitions, targeted refreshes, and stale-result rejection.",
        "- Preserve high-frequency observation isolation and privacy-safe diagnostics.",
        "- Keep the patch limited to one primary intent; split unrelated work into another build.",
        "",
        "## Contract drift to resolve before release",
    ]
    if warnings:
        for item in warnings:
            lines.append(f"- [{item.get('severity')}] `{item.get('code')}`: {item.get('message')}")
    else:
        lines.append("- None detected by the generated audit.")
    lines.extend(["", "## Changed files and ownership"])
    for category in scope.get("categories", []):
        lines.append(f"- **{category['name']}** (risk {category['risk']}/5): {', '.join(category['files'])}")
    if not scope.get("categories"):
        lines.append("- [TODO] Add intended files before implementation.")
    lines.extend(
        [
            "",
            "## Implementation sequence",
            "1. Reproduce and capture the baseline behavior.",
            "2. Write or update the smallest durable regression assertion that protects the behavior contract.",
            "3. Implement the narrow patch without unrelated cleanup.",
            "4. Run scoped checks, then global gates, then runtime acceptance.",
            "5. Re-audit version/build and README provenance before claiming a build.",
            "",
            "## Rollback",
            "- [TODO] Record the exact commit/tag/build reference and post-rollback checks.",
        ]
    )
    return "\n".join(lines) + "\n"


def validation_plan_template(manifest: dict[str, object], scope: dict[str, object]) -> str:
    lines = [
        "# Resonance validation plan",
        "",
        f"Target: `{manifest['version']}` build `{manifest['build']}` from `{manifest['commit']}`",
        "",
        "## Global gates",
    ]
    for command in scope.get("global_validations", []):
        lines.append(f"- [ ] `{command}`")
    lines.extend(["", "## Scoped acceptance"])
    seen: set[str] = set()
    for category in scope.get("categories", []):
        lines.append(f"\n### {category['name']}")
        for validation in category["validations"]:
            if validation in seen:
                continue
            seen.add(validation)
            lines.append(f"- [ ] {validation}")
    lines.extend(
        [
            "",
            "## Evidence rules",
            "- Record exact commands, result codes, configuration, simulator/device, OS, and artifact paths.",
            "- Separate simulator control-flow evidence from physical-device audible/background/thermal evidence.",
            "- Mark checks not run as pending or blocked; never convert missing evidence into a pass.",
            "- Do not store credentials, private URLs, file paths, track names, QR payloads, or private media.",
        ]
    )
    return "\n".join(lines) + "\n"


def acceptance_template(manifest: dict[str, object], scope: dict[str, object]) -> str:
    return f"""# Resonance build acceptance

## Build identity
- [ ] App bundle reports version {manifest['version']} and build {manifest['build']}.
- [ ] Source commit/ref and dirty state are recorded.
- [ ] README release source and latest device validation statements are accurate.
- [ ] RegressionChecks.sh assertions and success label match the project version/build.

## Behavior
- [ ] Primary intent is accepted.
- [ ] Stability reference behaviors remain intact.
- [ ] No unrelated feature or redesign entered the patch.
- [ ] Privacy audit passes for fresh diagnostics.

## Runtime boundary
- Physical device required by scope: {scope.get('requires_physical_device')}
- Remote fixture or authorized server required by scope: {scope.get('requires_remote_credentials_or_fixture')}
- Destructive library authorization may be required: {scope.get('may_require_destructive_library_actions')}

## Release decision
- [ ] All required checks have evidence.
- [ ] Pending limitations are stated with exact scope.
- [ ] Rollback reference and instructions are verified.
- [ ] Release decision in manifest.json is set to accepted, rejected, or blocked.
"""


def release_note_template(manifest: dict[str, object]) -> str:
    return f"""# README build note draft

Resonance {manifest['version']} build {manifest['build']} is a focused [TODO: repair/feature/performance/release] for [TODO: user-visible intent]. [TODO: Describe the exact implementation boundary and the behavior preserved.] Source commit: `{manifest['commit']}`. Validation completed: [TODO: list only checks actually completed]. Validation pending or not performed: [TODO: device launch, audible acceptance, remote credentials, background behavior, or none]. [TODO: State whether the build was compiled, signed, installed in place, and launched; never imply an action that was not performed.]
"""


def evidence_readme() -> str:
    return """# Evidence directory

Store only privacy-safe build outputs, command summaries, screenshots, diagnostics, and trace exports. Do not copy credentials, private URLs, QR payloads, track names, absolute user paths, private music, or raw audio into this workspace.

Use `resonance_build_workbench.py record` to update a validation gate and append a sanitized command record. Use `permission` only after an explicit user decision; authorization and completed device actions are recorded separately.
"""


def record_gate(args: argparse.Namespace) -> int:
    root = args.workspace.resolve()
    manifest_path = root / "manifest.json"
    if not manifest_path.is_file():
        print(f"error: {manifest_path} does not exist", file=sys.stderr)
        return 2
    manifest = json.loads(read_text(manifest_path))
    validation = manifest.get("validation")
    if not isinstance(validation, dict):
        print("error: manifest validation object is missing", file=sys.stderr)
        return 2
    if args.gate not in validation and not args.create:
        print(f"error: unknown gate {args.gate!r}; use --create to add it", file=sys.stderr)
        return 2
    for label, value in (("command", args.command), ("evidence", args.evidence), ("notes", args.notes)):
        if value and contains_sensitive_text(value):
            print(f"error: {label} appears to contain credentials or embedded authentication; record sanitized evidence", file=sys.stderr)
            return 2
    evidence_path = relative_evidence_path(args.evidence)
    if args.evidence and evidence_path is None:
        print("error: --evidence must be a workspace-relative path without '..'", file=sys.stderr)
        return 2
    if args.status == "passed" and not (args.command or args.evidence or args.notes):
        print("error: a passed gate requires a command, evidence path, or notes", file=sys.stderr)
        return 2
    if args.status == "passed" and evidence_path is not None and not (root / evidence_path).exists():
        print(f"error: passed-gate evidence does not exist: {evidence_path}", file=sys.stderr)
        return 2
    entry = validation.setdefault(args.gate, {"status": "pending", "kind": args.kind, "command": "", "evidence": "", "notes": ""})
    entry.update(
        {
            "status": args.status,
            "kind": args.kind or entry.get("kind", "manual"),
            "command": args.command or entry.get("command", ""),
            "evidence": args.evidence or entry.get("evidence", ""),
            "notes": args.notes or entry.get("notes", ""),
            "recorded_at": utc_now(),
        }
    )
    write_json(manifest_path, manifest)
    record = {
        "recorded_at": utc_now(),
        "gate": args.gate,
        "status": args.status,
        "kind": entry["kind"],
        "command": entry["command"],
        "evidence": entry["evidence"],
        "notes": entry["notes"],
    }
    commands_path = root / "evidence/commands.jsonl"
    commands_path.parent.mkdir(parents=True, exist_ok=True)
    with commands_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, sort_keys=True) + "\n")
    print(f"Recorded {args.gate}: {args.status}")
    return 0


def record_permission(args: argparse.Namespace) -> int:
    root = args.workspace.resolve()
    manifest_path = root / "manifest.json"
    if not manifest_path.is_file():
        print(f"error: {manifest_path} does not exist", file=sys.stderr)
        return 2
    if not args.notes.strip():
        print("error: permission changes require a privacy-safe authorization note", file=sys.stderr)
        return 2
    if contains_sensitive_text(args.notes):
        print("error: permission notes appear to contain credentials", file=sys.stderr)
        return 2
    manifest = json.loads(read_text(manifest_path))
    permissions = manifest.get("permissions")
    if not isinstance(permissions, dict):
        print("error: manifest permissions object is missing", file=sys.stderr)
        return 2
    value = bool(args.allow)
    permissions[args.name] = value
    manifest["permissions"] = permissions
    write_json(manifest_path, manifest)
    record = {
        "recorded_at": utc_now(),
        "permission": args.name,
        "allowed": value,
        "notes": args.notes.strip(),
    }
    permissions_path = root / "evidence/permissions.jsonl"
    permissions_path.parent.mkdir(parents=True, exist_ok=True)
    with permissions_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, sort_keys=True) + "\n")
    state = "allowed" if value else "denied"
    print(f"Recorded permission {args.name}: {state}")
    return 0


def verify_workspace(args: argparse.Namespace) -> int:
    root = args.workspace.resolve()
    required = (
        "manifest.json",
        "contract-audit.json",
        "change-scope.json",
        "change-plan.md",
        "validation-plan.md",
        "acceptance.md",
        "release-note.md",
        "evidence/commands.jsonl",
        "evidence/permissions.jsonl",
    )
    problems: list[str] = []
    for relative in required:
        if not (root / relative).is_file():
            problems.append(f"missing {relative}")
    if problems:
        for problem in problems:
            print(f"error: {problem}", file=sys.stderr)
        return 2

    manifest = json.loads(read_text(root / "manifest.json"))
    scope = json.loads(read_text(root / "change-scope.json"))
    version = str(manifest.get("version", ""))
    build = manifest.get("build")
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+)+", version):
        problems.append(f"invalid version {version!r}")
    if not isinstance(build, int) or build < 1:
        problems.append(f"invalid build {build!r}")
    baseline_values = [manifest.get("baseline_project_build"), manifest.get("latest_documented_device_build")]
    baseline_numbers = [value for value in baseline_values if isinstance(value, int)]
    if isinstance(build, int) and baseline_numbers and build <= max(baseline_numbers):
        problems.append(f"planned build {build} must exceed known build {max(baseline_numbers)}")

    for relative in ("change-plan.md", "validation-plan.md", "acceptance.md", "release-note.md"):
        text = read_text(root / relative)
        if "[TODO" in text or "TBD" in text:
            problems.append(f"unresolved placeholder in {relative}")
    release_note = read_text(root / "release-note.md")
    if version not in release_note or str(build) not in release_note:
        problems.append("release-note.md does not contain the manifest version/build")

    validation = manifest.get("validation")
    if not isinstance(validation, dict):
        problems.append("manifest validation object is missing")
        validation = {}

    allowed_statuses = {"pending", "passed", "failed", "blocked", "not-run", "not-applicable"}
    for name, entry in validation.items():
        if not isinstance(entry, dict):
            problems.append(f"validation gate {name} is not an object")
            continue
        status = entry.get("status")
        if status not in allowed_statuses:
            problems.append(f"validation gate {name} has invalid status {status!r}")
        command = str(entry.get("command", ""))
        evidence = str(entry.get("evidence", ""))
        notes = str(entry.get("notes", ""))
        for label, value in (("command", command), ("evidence", evidence), ("notes", notes)):
            if value and contains_sensitive_text(value):
                problems.append(f"validation gate {name} {label} appears to contain credentials")
        if status == "passed":
            if not (command or evidence or notes):
                problems.append(f"passed validation gate {name} has no command, evidence, or notes")
            if any(marker in f"{command} {evidence} {notes}" for marker in ("[TODO", "TBD", "<skill>", "<repo>")):
                problems.append(f"passed validation gate {name} still contains a placeholder")
            if evidence:
                evidence_path = relative_evidence_path(evidence)
                if evidence_path is None:
                    problems.append(f"validation gate {name} evidence must be workspace-relative")
                elif not (root / evidence_path).exists():
                    problems.append(f"validation gate {name} evidence does not exist: {evidence}")

    if args.release_ready:
        acceptable = {"passed", "not-applicable"}
        for name, entry in validation.items():
            status = entry.get("status") if isinstance(entry, dict) else None
            if status not in acceptable:
                problems.append(f"validation gate {name} is {status!r}, not release-ready")
        for required_gate in (
            "produced_app_bundle_identity",
            "readme_and_release_provenance_review",
            "artifact_integrity",
        ):
            entry = validation.get(required_gate, {})
            if entry.get("status") != "passed":
                problems.append(f"release gate {required_gate} must pass")
        if scope.get("requires_physical_device"):
            entry = validation.get("physical_device_runtime_acceptance", {})
            if entry.get("status") != "passed":
                problems.append("physical-device runtime acceptance is required and has not passed")
            permissions = manifest.get("permissions", {})
            if not isinstance(permissions, dict) or permissions.get("signed_device_install") is not True or permissions.get("launch_physical_app") is not True:
                problems.append("physical-device acceptance requires recorded install and launch authorization/completion")
        if manifest.get("release_decision") != "accepted":
            problems.append("manifest release_decision must be 'accepted' for --release-ready")
        rollback = manifest.get("rollback", {})
        if not isinstance(rollback, dict) or not rollback.get("reference") or not rollback.get("instructions") or rollback.get("verified") is not True:
            problems.append("rollback reference/instructions/verified state are incomplete")

    if problems:
        for problem in problems:
            print(f"error: {problem}", file=sys.stderr)
        return 1
    print("Workspace verification passed.")
    return 0


def version_plan(repo: Path, version: str, build: int) -> dict[str, object]:
    audit = audit_repository(repo)
    return {
        "target_version": version,
        "target_build": build,
        "current_project": audit.get("project"),
        "current_readme": audit.get("readme"),
        "edits": [
            {
                "path": "Resonance.xcodeproj/project.pbxproj",
                "action": f"Set both target MARKETING_VERSION values to {version} and both CURRENT_PROJECT_VERSION values to {build}.",
            },
            {
                "path": "Tools/RegressionChecks.sh",
                "action": f"Update exact project assertions to {version}/{build}, update the versioned success label, and add durable assertions for every new continuation contract.",
            },
            {
                "path": "README.md",
                "action": "Update release source only when this checkout becomes the authoritative release source; update latest device validation only after the exact build is installed/tested, and state whether it was launched.",
            },
            {
                "path": "Resonance/Info.plist",
                "action": "Do not hardcode version/build; retain $(MARKETING_VERSION) and $(CURRENT_PROJECT_VERSION).",
            },
            {
                "path": "Resonance/Views/SettingsView.swift",
                "action": "Do not hardcode a build label; retain Bundle-based dynamic display.",
            },
        ],
        "required_checks": [
            "Run contract audit --strict after edits.",
            "Run RegressionChecks.sh and PreflightBuild.sh.",
            "Read CFBundleShortVersionString and CFBundleVersion from the produced app bundle.",
            "Record signed/install/launch status separately and truthfully in README and evidence.",
        ],
    }


def version_plan_markdown(data: dict[str, object]) -> str:
    lines = [
        "# Resonance version/build synchronization plan",
        "",
        f"Target: **{data['target_version']} ({data['target_build']})**",
        "",
        "## Required edits",
        "",
        "| Path | Action |",
        "|---|---|",
    ]
    for item in data["edits"]:
        lines.append(f"| `{item['path']}` | {item['action']} |")
    lines.extend(["", "## Required checks", ""])
    for item in data["required_checks"]:
        lines.append(f"- {item}")
    return "\n".join(lines) + "\n"


def emit(data: dict[str, object], output_format: str, markdown: str, output: Path | None) -> None:
    text = json.dumps(data, indent=2, sort_keys=True) + "\n" if output_format == "json" else markdown
    if output:
        write_text(output, text)
        print(f"Wrote {output}")
    else:
        print(text, end="")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    audit = subparsers.add_parser("audit", help="audit repository and continuation contracts")
    audit.add_argument("repo", type=Path)
    audit.add_argument("--format", choices=("markdown", "json"), default="markdown")
    audit.add_argument("--output", type=Path)
    audit.add_argument("--strict", action="store_true", help="return 1 when warnings exist")

    scope = subparsers.add_parser("scope", help="map changed files to risk and validation")
    scope.add_argument("repo", type=Path)
    scope.add_argument("files", nargs="*")
    scope.add_argument("--base", help="git base ref for base...HEAD changed-file discovery")
    scope.add_argument("--format", choices=("markdown", "json"), default="markdown")
    scope.add_argument("--output", type=Path)

    init = subparsers.add_parser("init", help="create a future-build evidence workspace")
    init.add_argument("directory", type=Path)
    init.add_argument("--repo", type=Path, required=True)
    init.add_argument("--repository", default=DEFAULT_REPOSITORY)
    init.add_argument("--ref")
    init.add_argument("--commit")
    init.add_argument("--intent", required=True)
    init.add_argument("--issue-or-pr", default="")
    init.add_argument("--version")
    init.add_argument("--build", type=int)
    init.add_argument("--base")
    init.add_argument("--files", nargs="*", default=[])
    init.add_argument("--force", action="store_true")

    record = subparsers.add_parser("record", help="record one validation result")
    record.add_argument("workspace", type=Path)
    record.add_argument("--gate", required=True)
    record.add_argument("--status", choices=("pending", "passed", "failed", "blocked", "not-run", "not-applicable"), required=True)
    record.add_argument("--kind", choices=("command", "manual"), default="command")
    record.add_argument("--command", default="")
    record.add_argument("--evidence", default="")
    record.add_argument("--notes", default="")
    record.add_argument("--create", action="store_true")

    permission = subparsers.add_parser("permission", help="record an explicit user permission decision")
    permission.add_argument("workspace", type=Path)
    permission.add_argument("--name", choices=PERMISSION_NAMES, required=True)
    decision = permission.add_mutually_exclusive_group(required=True)
    decision.add_argument("--allow", action="store_true")
    decision.add_argument("--deny", action="store_true")
    permission.add_argument("--notes", required=True, help="privacy-safe record of the user's explicit decision")

    verify = subparsers.add_parser("verify", help="verify a build evidence workspace")
    verify.add_argument("workspace", type=Path)
    verify.add_argument("--release-ready", action="store_true")

    version = subparsers.add_parser("version-plan", help="show synchronized version/build edits")
    version.add_argument("repo", type=Path)
    version.add_argument("--version", required=True)
    version.add_argument("--build", required=True, type=int)
    version.add_argument("--format", choices=("markdown", "json"), default="markdown")
    version.add_argument("--output", type=Path)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "audit":
        data = audit_repository(args.repo)
        emit(data, args.format, audit_markdown(data), args.output)
        summary = data.get("summary", {})
        if summary.get("error", 0):
            return 2
        if args.strict and summary.get("warning", 0):
            return 1
        return 0
    if args.command == "scope":
        data = scope_changes(args.repo, args.files, base=args.base)
        emit(data, args.format, scope_markdown(data), args.output)
        return 0
    if args.command == "init":
        if args.build is not None and args.build < 1:
            print("error: --build must be positive", file=sys.stderr)
            return 2
        return init_workspace(args)
    if args.command == "record":
        return record_gate(args)
    if args.command == "permission":
        return record_permission(args)
    if args.command == "verify":
        return verify_workspace(args)
    if args.build < 1:
        print("error: --build must be positive", file=sys.stderr)
        return 2
    data = version_plan(args.repo, args.version, args.build)
    emit(data, args.format, version_plan_markdown(data), args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
