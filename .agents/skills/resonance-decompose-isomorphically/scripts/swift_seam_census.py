#!/usr/bin/env python3
"""Read-only Swift seam census for the Resonance repository.

The script intentionally uses only the Python standard library. It does not
compile or modify the repository. Its output is evidence for seam selection,
not a substitute for source review or the repository validation ladder.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import subprocess
import sys
from collections import Counter
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable, Sequence

SCHEMA_VERSION = 1
DEFAULT_EXCLUDED_PARTS = {
    ".git",
    ".build",
    "DerivedData",
    "build",
    "Pods",
    "Carthage",
    "vendor",
    "third_party",
}

TYPE_RE = re.compile(
    r"^\s*(?:@[A-Za-z_][\w.]*?(?:\([^)]*\))?\s+)*"
    r"(?:(?:open|public|package|internal|fileprivate|private)\s+)?"
    r"(?:final\s+|indirect\s+)?"
    r"(actor|class|struct|enum|protocol|extension)\s+([A-Za-z_][\w.]*)",
    re.MULTILINE,
)
FUNC_RE = re.compile(r"^\s*(?:@[\w.]+(?:\([^)]*\))?\s+)*(?:[\w<>]+\s+)*func\s+([A-Za-z_]\w*)", re.MULTILINE)
PROPERTY_RE = re.compile(
    r"^\s*(?:@[A-Za-z_][\w.]*?(?:\([^)]*\))?\s+)*"
    r"(?:(?:open|public|package|internal|fileprivate|private)\s+)?"
    r"(?:static\s+|class\s+|lazy\s+|nonisolated\s+)*"
    r"(let|var)\s+([A-Za-z_]\w*)",
    re.MULTILINE,
)
IMPORT_RE = re.compile(r"^\s*(?:@preconcurrency\s+|@testable\s+)?import\s+([A-Za-z_]\w*)", re.MULTILINE)
MARK_RE = re.compile(r"^\s*//\s*MARK:\s*-?\s*(.+?)\s*$", re.MULTILINE)
WRAPPER_RE = re.compile(r"@(StateObject|State|ObservedObject|EnvironmentObject|Environment|Published|AppStorage|FocusState|Binding)\b")
ACCESS_RE = re.compile(r"\b(open|public|package|internal|fileprivate|private)\b")

SIDE_EFFECT_TOKENS = {
    "audio": (
        "AVAudioEngine",
        "AVAudioPlayer",
        "AVPlayer",
        "AudioUnit",
        "MediaPlayer",
        "MPRemoteCommandCenter",
        "playImmediately",
        "seek(",
    ),
    "network": (
        "URLSession",
        "URLRequest",
        "HTTPURLResponse",
        "dataTask",
        "downloadTask",
        ".view\"",
    ),
    "persistence": (
        "sqlite3_",
        "UserDefaults",
        "FileManager",
        ".write(",
        "Data(contentsOf:",
        "Keychain",
        "SecItem",
    ),
    "concurrency": (
        "Task {",
        "Task.detached",
        "async ",
        "await ",
        "@MainActor",
        "nonisolated",
        "actor ",
        "DispatchQueue",
    ),
    "swiftui_identity": (
        "@State",
        "@StateObject",
        "@EnvironmentObject",
        "NavigationStack",
        "ScrollViewReader",
        ".id(",
        ".task(",
        ".gesture(",
        ".highPriorityGesture(",
        ".simultaneousGesture(",
    ),
    "diagnostics": (
        "ResonanceDiagnostics",
        ".record(",
        ".recordDeferred(",
        "AppErrorLog",
    ),
}


@dataclass
class SwiftFileCensus:
    path: str
    lines: int
    nonblank_lines: int
    comment_lines: int
    import_count: int
    imports: list[str]
    type_declarations: int
    declaration_kinds: dict[str, int]
    function_declarations: int
    property_declarations: int
    mark_regions: list[str]
    property_wrappers: dict[str, int]
    access_modifiers: dict[str, int]
    side_effect_signals: dict[str, int]
    target_source_membership_count: int
    project_reference_count: int
    git_commits: int
    git_lines_added: int
    git_lines_deleted: int
    generated_likelihood: str
    seam_risk_score: float
    reasons: list[str]


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create a read-only Swift seam census.")
    parser.add_argument("repo", type=Path, help="Repository root")
    parser.add_argument("--json-out", type=Path, required=True, help="Machine-readable output path")
    parser.add_argument("--markdown-out", type=Path, required=True, help="Human-readable output path")
    parser.add_argument("--min-lines", type=int, default=400, help="Line threshold used for candidate labels")
    parser.add_argument("--git-top", type=int, default=20, help="Collect git churn for the N largest files")
    parser.add_argument("--no-git", action="store_true", help="Skip git churn collection")
    parser.add_argument(
        "--include-tests",
        action="store_true",
        help="Include Swift files under test directories in the ranked candidate table",
    )
    return parser.parse_args(argv)


def is_excluded(path: Path, repo: Path) -> bool:
    try:
        relative = path.relative_to(repo)
    except ValueError:
        return True
    for part in relative.parts:
        if part in DEFAULT_EXCLUDED_PARTS or part.startswith("build-"):
            return True
    return False


def iter_swift_files(repo: Path) -> Iterable[Path]:
    for path in repo.rglob("*.swift"):
        if path.is_file() and not is_excluded(path, repo):
            yield path


def count_comment_lines(lines: list[str]) -> int:
    count = 0
    in_block = False
    for line in lines:
        stripped = line.strip()
        if in_block:
            count += 1
            if "*/" in stripped:
                in_block = False
            continue
        if stripped.startswith("//"):
            count += 1
        elif "/*" in stripped:
            count += 1
            if "*/" not in stripped.split("/*", 1)[1]:
                in_block = True
    return count


def generated_likelihood(path: Path, text: str) -> str:
    head = "\n".join(text.splitlines()[:12]).lower()
    parts = {part.lower() for part in path.parts}
    if "generated" in head or "do not edit" in head or "sourcery" in head:
        return "high"
    if {"generated", "derivedsources"} & parts:
        return "high"
    if path.name.endswith("+Generated.swift"):
        return "high"
    return "low"


def read_project_text(repo: Path) -> tuple[str, int]:
    chunks: list[str] = []
    count = 0
    for path in repo.rglob("project.pbxproj"):
        if is_excluded(path, repo):
            continue
        try:
            chunks.append(path.read_text(encoding="utf-8", errors="replace"))
            count += 1
        except OSError:
            continue
    return "\n".join(chunks), count


def membership_counts(project_text: str, filename: str) -> tuple[int, int]:
    if not project_text:
        return 0, 0
    escaped = re.escape(filename)
    source_count = len(re.findall(escaped + r"\s+in\s+Sources", project_text))
    reference_count = len(re.findall(r"(?:path\s*=\s*)?" + escaped + r"\b", project_text))
    return source_count, reference_count


def git_churn(repo: Path, relative_path: str) -> tuple[int, int, int]:
    try:
        completed = subprocess.run(
            ["git", "-C", str(repo), "log", "--format=@@%H", "--numstat", "--", relative_path],
            check=False,
            capture_output=True,
            text=True,
            timeout=20,
        )
    except (OSError, subprocess.TimeoutExpired):
        return 0, 0, 0
    if completed.returncode != 0:
        return 0, 0, 0
    commits = 0
    added = 0
    deleted = 0
    for line in completed.stdout.splitlines():
        if line.startswith("@@"):
            commits += 1
            continue
        fields = line.split("\t", 2)
        if len(fields) < 2:
            continue
        if fields[0].isdigit():
            added += int(fields[0])
        if fields[1].isdigit():
            deleted += int(fields[1])
    return commits, added, deleted


def test_path(relative: str) -> bool:
    parts = {part.lower() for part in Path(relative).parts}
    return any(part.endswith("tests") or part in {"test", "tests", "uitests"} for part in parts)


def inspect_file(repo: Path, path: Path, project_text: str) -> SwiftFileCensus:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    relative = path.relative_to(repo).as_posix()
    types = TYPE_RE.findall(text)
    type_kinds = Counter(kind for kind, _ in types)
    wrappers = Counter(WRAPPER_RE.findall(text))
    access = Counter(ACCESS_RE.findall(text))
    side_effects = {
        category: sum(text.count(token) for token in tokens)
        for category, tokens in SIDE_EFFECT_TOKENS.items()
    }
    source_membership, references = membership_counts(project_text, path.name)
    marks = [match.strip() for match in MARK_RE.findall(text)]
    generated = generated_likelihood(path, text)

    reasons: list[str] = []
    if len(lines) >= 1000:
        reasons.append("very large file")
    elif len(lines) >= 400:
        reasons.append("large file")
    if len(types) >= 10:
        reasons.append("many type/extension declarations")
    if len(marks) >= 8:
        reasons.append("many responsibility regions")
    if sum(wrappers.values()) >= 8:
        reasons.append("dense observed/UI state")
    if side_effects["audio"] and side_effects["network"]:
        reasons.append("audio and network effects coexist")
    if side_effects["persistence"] and side_effects["swiftui_identity"]:
        reasons.append("persistence and SwiftUI identity coexist")
    if side_effects["concurrency"] >= 12:
        reasons.append("heavy concurrency surface")
    if generated == "high":
        reasons.append("likely generated; do not hand-decompose")
    if source_membership == 0 and path.parts and "Tests" not in path.parts:
        reasons.append("no Xcode Sources membership detected")
    if source_membership > 2:
        reasons.append("ambiguous/repeated Xcode Sources membership")

    size_component = min(5.0, math.log2(max(1, len(lines) / 150.0) + 1.0) * 1.6)
    declaration_component = min(3.0, (len(types) + len(FUNC_RE.findall(text)) / 10.0) / 6.0)
    state_component = min(3.0, sum(wrappers.values()) / 4.0)
    effect_categories = sum(1 for count in side_effects.values() if count > 0)
    effect_component = min(4.0, effect_categories * 0.75)
    risk = round(size_component + declaration_component + state_component + effect_component, 2)
    if generated == "high":
        risk = round(risk + 3.0, 2)

    return SwiftFileCensus(
        path=relative,
        lines=len(lines),
        nonblank_lines=sum(1 for line in lines if line.strip()),
        comment_lines=count_comment_lines(lines),
        import_count=len(IMPORT_RE.findall(text)),
        imports=sorted(set(IMPORT_RE.findall(text))),
        type_declarations=len(types),
        declaration_kinds=dict(sorted(type_kinds.items())),
        function_declarations=len(FUNC_RE.findall(text)),
        property_declarations=len(PROPERTY_RE.findall(text)),
        mark_regions=marks,
        property_wrappers=dict(sorted(wrappers.items())),
        access_modifiers=dict(sorted(access.items())),
        side_effect_signals=side_effects,
        target_source_membership_count=source_membership,
        project_reference_count=references,
        git_commits=0,
        git_lines_added=0,
        git_lines_deleted=0,
        generated_likelihood=generated,
        seam_risk_score=risk,
        reasons=reasons,
    )


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def markdown_table(rows: list[SwiftFileCensus], min_lines: int) -> str:
    lines = [
        "# Resonance Swift Seam Census",
        "",
        "> Read-only heuristic census. Review source, callers, state ownership, target membership, and runtime evidence before selecting a seam.",
        "",
        f"Candidate threshold: **{min_lines} lines**. Requested files remain in scope even when smaller.",
        "",
        "| Rank | File | Lines | Types | Functions | State wrappers | Effect categories | Xcode Sources refs | Git commits | Risk | Signals |",
        "|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|",
    ]
    for index, item in enumerate(rows, start=1):
        effect_categories = sum(1 for value in item.side_effect_signals.values() if value > 0)
        reason_text = "; ".join(item.reasons[:4]) or "review manually"
        lines.append(
            "| {rank} | `{path}` | {loc} | {types} | {funcs} | {wrappers} | {effects} | {membership} | {commits} | {risk:.2f} | {reasons} |".format(
                rank=index,
                path=item.path.replace("|", "\\|"),
                loc=item.lines,
                types=item.type_declarations,
                funcs=item.function_declarations,
                wrappers=sum(item.property_wrappers.values()),
                effects=effect_categories,
                membership=item.target_source_membership_count,
                commits=item.git_commits,
                risk=item.seam_risk_score,
                reasons=reason_text.replace("|", "\\|"),
            )
        )
    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "- A high score means the file deserves seam analysis, not that it should automatically be split.",
            "- Generated files, state owners, audio paths, and files mixing SwiftUI identity with persistence require stricter review.",
            "- Zero target-membership detections can be a parser limitation or a real project-file defect; verify in Xcode before editing.",
            "- Git churn is collected only for the largest configured candidates and is zero when history is unavailable.",
            "",
        ]
    )
    return "\n".join(lines)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    repo = args.repo.expanduser().resolve()
    if not repo.is_dir():
        print(f"error: repository directory does not exist: {repo}", file=sys.stderr)
        return 2
    if args.min_lines < 1 or args.git_top < 0:
        print("error: --min-lines must be positive and --git-top must be non-negative", file=sys.stderr)
        return 2

    project_text, project_file_count = read_project_text(repo)
    records = [inspect_file(repo, path, project_text) for path in sorted(iter_swift_files(repo))]
    ranked = sorted(records, key=lambda item: (item.seam_risk_score, item.lines, item.path), reverse=True)

    if not args.no_git and args.git_top:
        for item in sorted(records, key=lambda entry: entry.lines, reverse=True)[: args.git_top]:
            commits, added, deleted = git_churn(repo, item.path)
            item.git_commits = commits
            item.git_lines_added = added
            item.git_lines_deleted = deleted
        ranked = sorted(records, key=lambda item: (item.seam_risk_score, item.lines, item.git_commits, item.path), reverse=True)

    candidates = [
        item
        for item in ranked
        if item.generated_likelihood != "high"
        and (args.include_tests or not test_path(item.path))
        and (item.lines >= args.min_lines or item.seam_risk_score >= 7.0)
    ]

    payload = {
        "schema_version": SCHEMA_VERSION,
        "repository": str(repo),
        "configuration": {
            "min_lines": args.min_lines,
            "git_top": 0 if args.no_git else args.git_top,
            "include_tests": bool(args.include_tests),
        },
        "summary": {
            "swift_files": len(records),
            "total_lines": sum(item.lines for item in records),
            "candidate_files": len(candidates),
            "project_files_found": project_file_count,
        },
        "candidates": [asdict(item) for item in candidates],
        "files": [asdict(item) for item in sorted(records, key=lambda entry: entry.path)],
    }
    write_json(args.json_out, payload)
    args.markdown_out.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_out.write_text(markdown_table(candidates or ranked[:20], args.min_lines), encoding="utf-8")
    print(f"Scanned {len(records)} Swift files; ranked {len(candidates)} candidates.")
    print(f"JSON: {args.json_out}")
    print(f"Markdown: {args.markdown_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
