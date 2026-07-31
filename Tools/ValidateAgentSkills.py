#!/usr/bin/env python3
"""Validate the repository-local Resonance Agent Skills catalog.

The validator is intentionally standard-library-only so it can run before Xcode
or optional Python packages are installed.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
import re
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable, Sequence

NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
MARKDOWN_LINK_RE = re.compile(r"!?(?:\[[^\]]*\])\(([^)]+)\)")
PLACEHOLDER_RE = re.compile(
    r"(?:\bTODO\b|\bTBD\b|PLACEHOLDER|example_asset|api_reference|lorem ipsum)",
    re.IGNORECASE,
)
TOP_LEVEL_KEYS = {"name", "description"}
REQUIRED_FILES = {"SKILL.md", "SELF-TEST.md", "agents/openai.yaml"}
IGNORED_DIRS = {"__pycache__", ".pytest_cache", ".mypy_cache"}
MAX_SKILL_ZIP_BYTES = 25 * 1024 * 1024
EXPECTED_SKILLS = (
    "resonance-decompose-isomorphically",
    "resonance-profile-performance",
    "resonance-real-service-e2e",
    "resonance-refactor-isomorphically",
)


@dataclass
class Finding:
    severity: str
    path: str
    message: str


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate repository-local Agent Skills.")
    parser.add_argument(
        "--repo",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Repository root (defaults to this script's repository)",
    )
    parser.add_argument("--json-out", type=Path, default=None, help="Optional JSON report")
    return parser.parse_args(argv)


def parse_frontmatter(text: str) -> tuple[dict[str, str], str]:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        raise ValueError("SKILL.md must begin with YAML frontmatter")
    try:
        end = next(index for index, line in enumerate(lines[1:], start=1) if line.strip() == "---")
    except StopIteration as exc:
        raise ValueError("frontmatter closing delimiter is missing") from exc

    raw = lines[1:end]
    values: dict[str, str] = {}
    index = 0
    while index < len(raw):
        line = raw[index]
        if not line.strip() or line.lstrip().startswith("#"):
            index += 1
            continue
        match = re.match(r"^([A-Za-z][A-Za-z0-9_-]*):(?:\s*(.*))?$", line)
        if not match:
            raise ValueError(f"unsupported frontmatter line: {line!r}")
        key, value = match.group(1), (match.group(2) or "").strip()
        if key in values:
            raise ValueError(f"duplicate frontmatter key: {key}")
        if value in {">", ">-", "|", "|-"}:
            block: list[str] = []
            index += 1
            while index < len(raw) and (not raw[index].strip() or raw[index].startswith((" ", "\t"))):
                block.append(raw[index].strip())
                index += 1
            values[key] = " ".join(part for part in block if part).strip()
            continue
        values[key] = value.strip('"\'')
        index += 1
    return values, "\n".join(lines[end + 1 :])


def relative_display(path: Path, repo: Path) -> str:
    try:
        return path.relative_to(repo).as_posix()
    except ValueError:
        return str(path)


def iter_files(root: Path) -> Iterable[Path]:
    for path in root.rglob("*"):
        if any(part in IGNORED_DIRS for part in path.parts):
            continue
        if path.is_file() or path.is_symlink():
            yield path


def package_size(skill: Path) -> int:
    return sum(path.stat().st_size for path in iter_files(skill) if path.is_file() and not path.is_symlink())


def markdown_links(path: Path) -> Iterable[str]:
    text = path.read_text(encoding="utf-8", errors="replace")
    for match in MARKDOWN_LINK_RE.finditer(text):
        target = match.group(1).strip().split(maxsplit=1)[0].strip("<>\"")
        if target:
            yield target


def imported_roots(tree: ast.AST) -> set[str]:
    roots: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            roots.update(alias.name.split(".", 1)[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            roots.add(node.module.split(".", 1)[0])
    return roots


def validate_skill(skill: Path, repo: Path) -> list[Finding]:
    findings: list[Finding] = []
    display = relative_display(skill, repo)

    for required in REQUIRED_FILES:
        if not (skill / required).is_file():
            findings.append(Finding("error", display, f"missing required file: {required}"))

    for path in iter_files(skill):
        item_display = relative_display(path, repo)
        if path.is_symlink():
            findings.append(Finding("error", item_display, "symlinks are not allowed in a portable skill"))
        if path.name in {".DS_Store"} or path.suffix == ".pyc" or "__pycache__" in path.parts:
            findings.append(Finding("error", item_display, "generated/cache file must not be committed"))
        if path.is_file() and path.stat().st_size > MAX_SKILL_ZIP_BYTES:
            findings.append(Finding("error", item_display, "single file exceeds the 25 MB skill limit"))

    if package_size(skill) > MAX_SKILL_ZIP_BYTES:
        findings.append(Finding("error", display, "uncompressed skill exceeds the 25 MB upload limit"))

    skill_md = skill / "SKILL.md"
    if not skill_md.is_file():
        return findings
    text = skill_md.read_text(encoding="utf-8", errors="replace")
    try:
        frontmatter, body = parse_frontmatter(text)
    except ValueError as exc:
        findings.append(Finding("error", relative_display(skill_md, repo), str(exc)))
        return findings

    extra = set(frontmatter) - TOP_LEVEL_KEYS
    missing = TOP_LEVEL_KEYS - set(frontmatter)
    if extra:
        findings.append(Finding("error", relative_display(skill_md, repo), f"unsupported frontmatter keys: {sorted(extra)}"))
    if missing:
        findings.append(Finding("error", relative_display(skill_md, repo), f"missing frontmatter keys: {sorted(missing)}"))

    name = frontmatter.get("name", "")
    description = frontmatter.get("description", "")
    if name != skill.name:
        findings.append(Finding("error", relative_display(skill_md, repo), f"name {name!r} must match directory {skill.name!r}"))
    if not NAME_RE.fullmatch(name) or len(name) > 64:
        findings.append(Finding("error", relative_display(skill_md, repo), "name must be <=64 lowercase letters/numbers/hyphens"))
    if not description or len(description) > 1024:
        findings.append(Finding("error", relative_display(skill_md, repo), "description must be 1-1024 characters"))
    if len(description.split()) < 20 or "use" not in description.lower():
        findings.append(Finding("error", relative_display(skill_md, repo), "description must clearly state capability and trigger conditions"))
    if len(text.splitlines()) > 500:
        findings.append(Finding("error", relative_display(skill_md, repo), "SKILL.md exceeds the 500-line progressive-loading budget"))
    if not body.strip():
        findings.append(Finding("error", relative_display(skill_md, repo), "SKILL.md instruction body is empty"))

    for markdown in sorted(skill.rglob("*.md")):
        markdown_text = markdown.read_text(encoding="utf-8", errors="replace")
        if PLACEHOLDER_RE.search(markdown_text):
            findings.append(Finding("error", relative_display(markdown, repo), "generated placeholder text remains"))
        for target in markdown_links(markdown):
            if target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            target_path = target.split("#", 1)[0]
            if not target_path:
                continue
            resolved = (markdown.parent / target_path).resolve()
            try:
                resolved.relative_to(skill.resolve())
            except ValueError:
                findings.append(Finding("error", relative_display(markdown, repo), f"link escapes skill root: {target}"))
                continue
            if not resolved.exists():
                findings.append(Finding("error", relative_display(markdown, repo), f"broken relative link: {target}"))

    metadata = skill / "agents/openai.yaml"
    if metadata.is_file():
        metadata_text = metadata.read_text(encoding="utf-8", errors="replace")
        for key in ("interface:", "display_name:", "short_description:"):
            if key not in metadata_text:
                findings.append(Finding("error", relative_display(metadata, repo), f"missing UI metadata key: {key}"))

    scripts = skill / "scripts"
    if scripts.is_dir():
        for script in sorted(scripts.glob("*.py")):
            script_display = relative_display(script, repo)
            source = script.read_text(encoding="utf-8", errors="replace")
            if not source.startswith("#!/usr/bin/env python3"):
                findings.append(Finding("error", script_display, "Python script must have a portable python3 shebang"))
            if not os.access(script, os.X_OK):
                findings.append(Finding("error", script_display, "script must be executable"))
            try:
                tree = ast.parse(source, filename=str(script))
            except SyntaxError as exc:
                findings.append(Finding("error", script_display, f"Python syntax error: {exc}"))
                continue
            non_stdlib = sorted(root for root in imported_roots(tree) if root not in sys.stdlib_module_names and root != "__future__")
            if non_stdlib and not any((skill / name).is_file() for name in ("requirements.txt", "DEPENDENCIES.md")):
                findings.append(Finding("error", script_display, f"undocumented non-stdlib imports: {non_stdlib}"))

    return findings


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    repo = args.repo.expanduser().resolve()
    skills_root = repo / ".agents/skills"
    if not skills_root.is_dir():
        print(f"error: skills directory does not exist: {skills_root}", file=sys.stderr)
        return 2

    skill_dirs = sorted(path for path in skills_root.iterdir() if path.is_dir() and (path / "SKILL.md").is_file())
    if not skill_dirs:
        print(f"error: no skills found under {skills_root}", file=sys.stderr)
        return 2

    findings: list[Finding] = []
    actual_names = tuple(path.name for path in skill_dirs)
    if actual_names != EXPECTED_SKILLS:
        missing = sorted(set(EXPECTED_SKILLS) - set(actual_names))
        extra = sorted(set(actual_names) - set(EXPECTED_SKILLS))
        findings.append(
            Finding(
                "error",
                ".agents/skills",
                f"catalog must contain exactly the four expected skills; missing={missing} extra={extra}",
            )
        )
    if not (skills_root / "README.md").is_file():
        findings.append(Finding("error", ".agents/skills", "catalog README.md is missing"))

    for skill in skill_dirs:
        findings.extend(validate_skill(skill, repo))

    contracts = [skill / "references/RESONANCE-CONTRACT.md" for skill in skill_dirs]
    existing_contracts = [path for path in contracts if path.is_file()]
    if len(existing_contracts) != len(skill_dirs):
        missing = [relative_display(path, repo) for path in contracts if not path.is_file()]
        findings.append(Finding("error", ".agents/skills", f"missing shared contract copies: {missing}"))
    elif existing_contracts:
        digests = {hashlib.sha256(path.read_bytes()).hexdigest() for path in existing_contracts}
        if len(digests) != 1:
            findings.append(Finding("error", ".agents/skills", "RESONANCE-CONTRACT.md copies have drifted"))

    report = {
        "status": "pass" if not any(item.severity == "error" for item in findings) else "fail",
        "skills": [path.name for path in skill_dirs],
        "skill_count": len(skill_dirs),
        "findings": [asdict(item) for item in findings],
    }
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    for item in findings:
        print(f"{item.severity.upper()}: {item.path}: {item.message}")
    print(f"Validated {len(skill_dirs)} skills: {report['status']} ({len(findings)} findings).")
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
