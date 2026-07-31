#!/usr/bin/env python3
"""Capture and compare a conservative Resonance code-surface snapshot.

This is a guardrail, not a Swift parser. A reported removal requires review; an
empty removal set does not prove behavioral equivalence.
"""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
import plistlib
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Iterable, Sequence

SCHEMA_VERSION = 1
SOURCE_SUFFIXES = {".swift", ".py", ".sh", ".plist", ".pbxproj", ".yaml", ".yml", ".json"}
EXCLUDED_PARTS = {".git", ".build", "DerivedData", "build", "Pods", "Carthage", "vendor", "third_party"}
ACCESS_WORDS = {"open", "public", "package", "internal", "fileprivate", "private"}

TYPE_RE = re.compile(
    r"^\s*(?P<prefix>(?:(?:@[\w.]+(?:\([^)]*\))?|open|public|package|internal|fileprivate|private|final|indirect|nonisolated|@MainActor)\s+)*)"
    r"(?P<kind>actor|class|struct|enum|protocol|extension|typealias)\s+(?P<name>[A-Za-z_][\w.]*)"
)
FUNC_RE = re.compile(
    r"^\s*(?P<prefix>(?:(?:@[\w.]+(?:\([^)]*\))?|open|public|package|internal|fileprivate|private|final|static|class|mutating|nonmutating|override|required|convenience|nonisolated|@MainActor)\s+)*)"
    r"func\s+(?P<name>[A-Za-z_]\w*|[-+*/%=<>!&|^~?]+)"
)
INIT_RE = re.compile(
    r"^\s*(?P<prefix>(?:(?:@[\w.]+(?:\([^)]*\))?|open|public|package|internal|fileprivate|private|required|convenience|override|nonisolated|@MainActor)\s+)*)"
    r"(?P<name>init|subscript)\b"
)
PROPERTY_RE = re.compile(
    r"^\s*(?P<prefix>(?:(?:@[\w.]+(?:\([^)]*\))?|open|public|package|internal|fileprivate|private|static|class|lazy|weak|unowned|nonisolated|@MainActor)\s+)*)"
    r"(?P<kind>let|var)\s+(?P<name>[A-Za-z_]\w*)"
)
STRING_RE = re.compile(r'"((?:\\.|[^"\\])*)"')
DIAGNOSTIC_RE = re.compile(r"\b(?:ResonanceDiagnostics\.shared\.)?record(?:Deferred)?\s*\(\s*\"([^\"]+)\"")
PERSISTENCE_PATTERNS = [
    re.compile(r"@AppStorage\s*\(\s*\"([^\"]+)\""),
    re.compile(r"forKey\s*:\s*\"([^\"]+)\""),
    re.compile(r"UserDefaults\.standard\.(?:bool|integer|double|string|data|object)\s*\(\s*forKey\s*:\s*\"([^\"]+)\""),
]
NOTIFICATION_RE = re.compile(r"Notification\.Name\s*\(\s*(?:rawValue\s*:\s*)?\"([^\"]+)\"")
SELECTOR_RE = re.compile(r"#selector\s*\(([^)]+)\)")


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Capture or compare a conservative code-surface snapshot.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    capture = subparsers.add_parser("capture", help="Capture a baseline snapshot")
    capture.add_argument("repo", type=Path)
    capture.add_argument("--out", type=Path, required=True)

    compare = subparsers.add_parser("compare", help="Compare the current tree with a baseline")
    compare.add_argument("repo", type=Path)
    compare.add_argument("--baseline", type=Path, required=True)
    compare.add_argument("--out", type=Path, required=True)
    compare.add_argument(
        "--allowlist",
        type=Path,
        default=None,
        help="Optional JSON mapping diff categories to exact or glob patterns",
    )
    return parser.parse_args(argv)


def is_excluded(path: Path, repo: Path) -> bool:
    try:
        relative = path.relative_to(repo)
    except ValueError:
        return True
    return any(part in EXCLUDED_PARTS or part.startswith("build-") for part in relative.parts)


def git_output(repo: Path, args: list[str]) -> str | None:
    try:
        completed = subprocess.run(
            ["git", "-C", str(repo), *args],
            check=False,
            capture_output=True,
            text=True,
            timeout=20,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return completed.stdout.strip() if completed.returncode == 0 else None


def tracked_files(repo: Path) -> list[Path]:
    output = git_output(repo, ["ls-files", "--cached", "--others", "--exclude-standard", "-z"])
    files: list[Path] = []
    if output is not None:
        for relative in output.split("\0"):
            if not relative:
                continue
            path = repo / relative
            if path.is_file() and path.suffix in SOURCE_SUFFIXES and not is_excluded(path, repo):
                files.append(path)
        return sorted(set(files))
    for path in repo.rglob("*"):
        if path.is_file() and path.suffix in SOURCE_SUFFIXES and not is_excluded(path, repo):
            files.append(path)
    return sorted(set(files))


def strip_comments_preserving_lines(text: str) -> str:
    output: list[str] = []
    index = 0
    in_block = False
    in_string = False
    escaped = False
    while index < len(text):
        char = text[index]
        next_char = text[index + 1] if index + 1 < len(text) else ""
        if in_block:
            if char == "*" and next_char == "/":
                output.extend("  ")
                index += 2
                in_block = False
            else:
                output.append("\n" if char == "\n" else " ")
                index += 1
            continue
        if in_string:
            output.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue
        if char == '"':
            in_string = True
            output.append(char)
            index += 1
        elif char == "/" and next_char == "*":
            output.extend("  ")
            index += 2
            in_block = True
        elif char == "/" and next_char == "/":
            while index < len(text) and text[index] != "\n":
                output.append(" ")
                index += 1
        else:
            output.append(char)
            index += 1
    return "".join(output)


def brace_delta(line: str) -> int:
    depth = 0
    in_string = False
    escaped = False
    for char in line:
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
    return depth


def access_from_prefix(prefix: str) -> str:
    words = set(re.findall(r"[A-Za-z_][\w]*", prefix))
    for access in ("open", "public", "package", "internal", "fileprivate", "private"):
        if access in words:
            return access
    return "internal"


def declaration_chunk(lines: list[str], start: int, kind: str, maximum: int = 12) -> str:
    """Capture a declaration header without absorbing the next declaration.

    This is deliberately conservative rather than a Swift parser. In particular,
    single-line properties must stop immediately even when they have neither an
    initializer nor an accessor body; otherwise deleting the following function
    would appear to change the property's signature.
    """

    parts: list[str] = []
    paren_depth = 0
    angle_depth = 0
    bracket_depth = 0
    for line in lines[start : start + maximum]:
        stripped = line.strip()
        if not stripped:
            continue
        parts.append(stripped)
        paren_depth += stripped.count("(") - stripped.count(")")
        angle_depth += stripped.count("<") - stripped.count(">")
        bracket_depth += stripped.count("[") - stripped.count("]")
        balanced = paren_depth <= 0 and angle_depth <= 0 and bracket_depth <= 0

        if "{" in stripped and balanced:
            break
        if kind == "property" and balanced:
            continuation = stripped.rstrip().endswith((":", ",", "=", "(", "[", "<"))
            if not continuation:
                break
        elif stripped.endswith(")") and paren_depth <= 0:
            break
        elif "=" in stripped and balanced:
            break

    joined = " ".join(parts)
    joined = joined.split("{", 1)[0]
    if kind == "property":
        joined = joined.split("=", 1)[0]
    return re.sub(r"\s+", " ", joined).strip().rstrip()


def capture_swift_declarations(relative: str, text: str) -> list[dict[str, str]]:
    cleaned = strip_comments_preserving_lines(text)
    lines = cleaned.splitlines()
    declarations: list[dict[str, str]] = []
    depth = 0
    for index, line in enumerate(lines):
        current_depth = depth
        if current_depth <= 2:
            match = TYPE_RE.match(line)
            kind = ""
            name = ""
            prefix = ""
            if match:
                kind = match.group("kind")
                name = match.group("name")
                prefix = match.group("prefix") or ""
            else:
                match = FUNC_RE.match(line) or INIT_RE.match(line)
                if match:
                    kind = "function"
                    name = match.group("name")
                    prefix = match.group("prefix") or ""
                else:
                    property_match = PROPERTY_RE.match(line)
                    if property_match:
                        prefix = property_match.group("prefix") or ""
                        capture_property = bool(
                            set(re.findall(r"[A-Za-z_][\w]*", prefix)) & ACCESS_WORDS
                            or "@" in prefix
                            or re.search(r"\b(?:static|class|lazy|weak|unowned|nonisolated)\b", prefix)
                            or current_depth == 0
                        )
                        if capture_property:
                            kind = "property"
                            name = property_match.group("name")
                            match = property_match
            if match and kind and name:
                signature = declaration_chunk(lines, index, kind)
                access = access_from_prefix(prefix)
                identifier_source = f"{relative}|{kind}|{access}|{name}|{signature}"
                declarations.append(
                    {
                        "id": hashlib.sha256(identifier_source.encode("utf-8")).hexdigest()[:20],
                        "path": relative,
                        "kind": kind,
                        "name": name,
                        "access": access,
                        "signature": signature,
                    }
                )
        depth = max(0, depth + brace_delta(line))
    unique: dict[str, dict[str, str]] = {}
    for declaration in declarations:
        unique[declaration["id"]] = declaration
    return sorted(unique.values(), key=lambda item: (item["path"], item["kind"], item["name"], item["signature"]))


def unescape_swift_string(value: str) -> str:
    return value.replace(r'\"', '"').replace(r"\\", "\\")


def capture_contracts(relative: str, text: str) -> list[dict[str, str]]:
    contracts: set[tuple[str, str]] = set()
    for match in DIAGNOSTIC_RE.finditer(text):
        contracts.add(("diagnostic_event", unescape_swift_string(match.group(1))))
    for pattern in PERSISTENCE_PATTERNS:
        for match in pattern.finditer(text):
            contracts.add(("persistence_key", unescape_swift_string(match.group(1))))
    for match in NOTIFICATION_RE.finditer(text):
        contracts.add(("notification_name", unescape_swift_string(match.group(1))))
    for match in SELECTOR_RE.finditer(text):
        contracts.add(("selector", re.sub(r"\s+", " ", match.group(1)).strip()))
    for match in STRING_RE.finditer(text):
        value = unescape_swift_string(match.group(1))
        if value.endswith(".view") or value.startswith("/resonance/") or value.startswith("/media/"):
            contracts.add(("endpoint", value))
        elif value.startswith(("resonance.", "com.example.Resonance")) and len(value) <= 160:
            contracts.add(("stable_string", value))
    return [
        {
            "category": category,
            "value": value,
            "source": relative,
        }
        for category, value in sorted(contracts)
    ]


def flatten_plist(value: Any, prefix: str = "") -> dict[str, Any]:
    result: dict[str, Any] = {}
    if isinstance(value, dict):
        for key in sorted(value):
            child_prefix = f"{prefix}.{key}" if prefix else str(key)
            result.update(flatten_plist(value[key], child_prefix))
    elif isinstance(value, list):
        for index, item in enumerate(value):
            result.update(flatten_plist(item, f"{prefix}[{index}]"))
    elif isinstance(value, (str, int, float, bool)) or value is None:
        result[prefix] = value
    else:
        result[prefix] = repr(value)
    return result


def project_settings(project_text: str) -> dict[str, list[str]]:
    settings: dict[str, list[str]] = {}
    for key in ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION", "PRODUCT_BUNDLE_IDENTIFIER", "SWIFT_VERSION", "SWIFT_STRICT_CONCURRENCY"):
        values = sorted(set(re.findall(rf"\b{re.escape(key)}\s*=\s*([^;]+);", project_text)))
        settings[key] = [value.strip().strip('"') for value in values]
    return settings


def capture_snapshot(repo: Path) -> dict[str, Any]:
    files = tracked_files(repo)
    file_rows: list[dict[str, Any]] = []
    declarations: list[dict[str, str]] = []
    contracts: list[dict[str, str]] = []
    plists: dict[str, dict[str, Any]] = {}
    project_texts: list[str] = []

    for path in files:
        relative = path.relative_to(repo).as_posix()
        data = path.read_bytes()
        text = data.decode("utf-8", errors="replace")
        file_rows.append(
            {
                "path": relative,
                "bytes": len(data),
                "lines": len(text.splitlines()),
                "sha256": hashlib.sha256(data).hexdigest(),
            }
        )
        if path.suffix == ".swift":
            declarations.extend(capture_swift_declarations(relative, text))
            contracts.extend(capture_contracts(relative, text))
        elif path.suffix == ".py":
            contracts.extend(capture_contracts(relative, text))
        elif path.suffix == ".plist":
            try:
                plists[relative] = flatten_plist(plistlib.loads(data))
            except Exception as exc:
                plists[relative] = {"__parse_error__": type(exc).__name__}
        elif path.suffix == ".pbxproj":
            project_texts.append(text)

    project_text = "\n".join(project_texts)
    xcode_sources = sorted(set(re.findall(r"([A-Za-z0-9_+.-]+\.swift)\s+in\s+Sources", project_text)))
    contract_global = sorted({f"{item['category']}|{item['value']}" for item in contracts})
    branch = git_output(repo, ["branch", "--show-current"])
    sha = git_output(repo, ["rev-parse", "HEAD"])
    dirty_output = git_output(repo, ["status", "--porcelain"])
    return {
        "schema_version": SCHEMA_VERSION,
        "repository": str(repo),
        "vcs": {
            "branch": branch,
            "sha": sha,
            "dirty": bool(dirty_output) if dirty_output is not None else None,
        },
        "summary": {
            "tracked_source_files": len(file_rows),
            "swift_declarations": len(declarations),
            "global_contracts": len(contract_global),
            "xcode_source_members": len(xcode_sources),
        },
        "files": sorted(file_rows, key=lambda item: item["path"]),
        "swift_declarations": declarations,
        "contracts_by_source": sorted(contracts, key=lambda item: (item["category"], item["value"], item["source"])),
        "global_contracts": contract_global,
        "xcode_sources": xcode_sources,
        "project_settings": project_settings(project_text),
        "plists": plists,
    }


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def load_allowlist(path: Path | None) -> dict[str, list[str]]:
    if path is None:
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("allowlist must be a JSON object")
    result: dict[str, list[str]] = {}
    for key, value in data.items():
        if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
            raise ValueError(f"allowlist category {key!r} must be a list of strings")
        result[str(key)] = value
    return result


def waived(category: str, identifier: str, allowlist: dict[str, list[str]]) -> bool:
    return any(fnmatch.fnmatch(identifier, pattern) for pattern in allowlist.get(category, []))


def dictionary_changes(before: dict[str, Any], after: dict[str, Any]) -> dict[str, Any]:
    before_keys = set(before)
    after_keys = set(after)
    changed = {
        key: {"before": before[key], "after": after[key]}
        for key in sorted(before_keys & after_keys)
        if before[key] != after[key]
    }
    return {
        "removed": sorted(before_keys - after_keys),
        "added": sorted(after_keys - before_keys),
        "changed": changed,
    }


def compare_snapshots(baseline: dict[str, Any], current: dict[str, Any], allowlist: dict[str, list[str]]) -> dict[str, Any]:
    baseline_files = {item["path"] for item in baseline.get("files", [])}
    current_files = {item["path"] for item in current.get("files", [])}
    baseline_declarations = {item["id"]: item for item in baseline.get("swift_declarations", [])}
    current_declarations = {item["id"]: item for item in current.get("swift_declarations", [])}
    baseline_contracts = set(baseline.get("global_contracts", []))
    current_contracts = set(current.get("global_contracts", []))
    baseline_sources = set(baseline.get("xcode_sources", []))
    current_sources = set(current.get("xcode_sources", []))

    removed_files = sorted(baseline_files - current_files)
    added_files = sorted(current_files - baseline_files)
    removed_declaration_ids = sorted(set(baseline_declarations) - set(current_declarations))
    added_declaration_ids = sorted(set(current_declarations) - set(baseline_declarations))
    removed_contracts = sorted(baseline_contracts - current_contracts)
    added_contracts = sorted(current_contracts - baseline_contracts)
    removed_sources = sorted(baseline_sources - current_sources)
    added_sources = sorted(current_sources - baseline_sources)

    plist_changes: dict[str, Any] = {}
    for path in sorted(set(baseline.get("plists", {})) | set(current.get("plists", {}))):
        change = dictionary_changes(
            baseline.get("plists", {}).get(path, {}),
            current.get("plists", {}).get(path, {}),
        )
        if change["removed"] or change["added"] or change["changed"]:
            plist_changes[path] = change
    settings_changes = dictionary_changes(
        baseline.get("project_settings", {}),
        current.get("project_settings", {}),
    )

    blockers: list[dict[str, Any]] = []
    waived_items: list[dict[str, str]] = []

    def classify(category: str, identifier: str, detail: Any = None) -> None:
        row = {"category": category, "identifier": identifier}
        if detail is not None:
            row["detail"] = detail
        if waived(category, identifier, allowlist):
            waived_items.append({"category": category, "identifier": identifier})
        else:
            blockers.append(row)

    for value in removed_files:
        classify("removed_files", value)
    for identifier in removed_declaration_ids:
        declaration = baseline_declarations[identifier]
        readable = f"{declaration['path']}::{declaration['kind']}::{declaration['name']}::{declaration['signature']}"
        classify("removed_declarations", readable, declaration)
    for value in removed_contracts:
        classify("removed_contracts", value)
    for value in removed_sources:
        classify("removed_xcode_sources", value)
    for path, change in plist_changes.items():
        for key in change["removed"]:
            classify("plist_changes", f"{path}::{key}::removed")
        for key, values in change["changed"].items():
            classify("plist_changes", f"{path}::{key}::changed", values)
    for key in settings_changes["removed"]:
        classify("project_setting_changes", f"{key}::removed")
    for key, values in settings_changes["changed"].items():
        classify("project_setting_changes", f"{key}::changed", values)

    return {
        "schema_version": SCHEMA_VERSION,
        "status": "pass" if not blockers else "fail",
        "blocking_change_count": len(blockers),
        "blockers": blockers,
        "waived": waived_items,
        "diff": {
            "files": {"removed": removed_files, "added": added_files},
            "declarations": {
                "removed": [baseline_declarations[item] for item in removed_declaration_ids],
                "added": [current_declarations[item] for item in added_declaration_ids],
            },
            "global_contracts": {"removed": removed_contracts, "added": added_contracts},
            "xcode_sources": {"removed": removed_sources, "added": added_sources},
            "plists": plist_changes,
            "project_settings": settings_changes,
        },
        "baseline_summary": baseline.get("summary", {}),
        "current_summary": current.get("summary", {}),
        "current_vcs": current.get("vcs", {}),
    }


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    repo = args.repo.expanduser().resolve()
    if not repo.is_dir():
        print(f"error: repository directory does not exist: {repo}", file=sys.stderr)
        return 2

    if args.command == "capture":
        snapshot = capture_snapshot(repo)
        write_json(args.out, snapshot)
        print(
            f"Captured {snapshot['summary']['tracked_source_files']} files, "
            f"{snapshot['summary']['swift_declarations']} declarations, and "
            f"{snapshot['summary']['global_contracts']} contracts."
        )
        print(f"Snapshot: {args.out}")
        return 0

    try:
        baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
        if baseline.get("schema_version") != SCHEMA_VERSION:
            raise ValueError(
                f"baseline schema {baseline.get('schema_version')!r} does not match {SCHEMA_VERSION}"
            )
        allowlist = load_allowlist(args.allowlist)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"error: could not load baseline/allowlist: {exc}", file=sys.stderr)
        return 2

    current = capture_snapshot(repo)
    comparison = compare_snapshots(baseline, current, allowlist)
    write_json(args.out, comparison)
    print(
        f"Surface comparison: {comparison['status']}; "
        f"blocking changes={comparison['blocking_change_count']}; "
        f"waived={len(comparison['waived'])}."
    )
    print(f"Comparison: {args.out}")
    return 0 if comparison["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
