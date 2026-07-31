#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import tempfile
import unittest
from pathlib import Path

import resonance_build_workbench as rbw


class BuildWorkbenchTests(unittest.TestCase):
    def make_repo(self, root: Path) -> Path:
        repo = root / "repo"
        (repo / "Resonance.xcodeproj").mkdir(parents=True)
        (repo / "Resonance/Services").mkdir(parents=True)
        (repo / "Resonance/Views").mkdir(parents=True)
        (repo / "Tools").mkdir(parents=True)
        (repo / ".xcodebuildmcp").mkdir(parents=True)

        (repo / "README.md").write_text(
            """# Resonance Beta v1.0.6

## Current stable beta - 1.0.6 (build 210)
Release source build: `1.0.6` (build `210`)
Latest device validation build: `1.0.6` (build `214`). The physical app was not launched by Codex.
Authoritative continuation source: the `Resonance-Beta-v1.0.6` tag on `agent/alpha-3.7.4-source`.
""",
            encoding="utf-8",
        )
        project = """
/* ResonanceApp.swift in Sources */
/* LibraryStore.swift in Sources */
/* RemoteLibraryStore.swift in Sources */
/* SettingsView.swift in Sources */
MARKETING_VERSION = 1.0.6;
CURRENT_PROJECT_VERSION = 210;
MARKETING_VERSION = 1.0.6;
CURRENT_PROJECT_VERSION = 210;
SWIFT_VERSION = 5.0;
SWIFT_VERSION = 5.0;
"""
        (repo / "Resonance.xcodeproj/project.pbxproj").write_text(project, encoding="utf-8")
        (repo / "Resonance/Info.plist").write_text(
            "<plist><dict><string>$(MARKETING_VERSION)</string><string>$(CURRENT_PROJECT_VERSION)</string></dict></plist>",
            encoding="utf-8",
        )
        (repo / "Resonance/ResonanceApp.swift").write_text("remote.prewarmBrowseCache()\n", encoding="utf-8")
        (repo / "Resonance/Services/LibraryStore.swift").write_text("var isBootstrapping = true\n", encoding="utf-8")
        (repo / "Resonance/Services/RemoteLibraryStore.swift").write_text(
            "func loadCachedStartupStateIfNeeded() {}\nfunc prewarmBrowseCache() {}\nfunc makeBrowseCache() {}\n",
            encoding="utf-8",
        )
        (repo / "Resonance/Views/SettingsView.swift").write_text(
            'let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")\n'
            'let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")\n',
            encoding="utf-8",
        )
        (repo / "Tools/RegressionChecks.sh").write_text(
            """#!/bin/bash
python3 - <<'INNERPY'
pbx = open('Resonance.xcodeproj/project.pbxproj').read()
assert pbx.count('CURRENT_PROJECT_VERSION = 210;') == 2
assert pbx.count('MARKETING_VERSION = 1.0.6;') == 2
print('Resonance Beta v1.0.7 regression checks passed.')
INNERPY
""",
            encoding="utf-8",
        )
        (repo / "Tools/PreflightBuild.sh").write_text(
            "SWIFT_VERSION=6\nSWIFT_STRICT_CONCURRENCY=complete\nSWIFT_TREAT_WARNINGS_AS_ERRORS=YES\niphonesimulator\niphoneos\n",
            encoding="utf-8",
        )
        (repo / "Tools/ResonanceServer.py").write_text("print('fixture')\n", encoding="utf-8")
        (repo / ".xcodebuildmcp/config.yaml").write_text(
            "schemaVersion: 1\nsessionDefaults:\n  projectPath: ./Resonance.xcodeproj\n  scheme: Resonance\n  simulatorName: iPhone 17 Pro\n",
            encoding="utf-8",
        )
        return repo

    def test_audit_detects_current_contract_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = self.make_repo(Path(directory))
            data = rbw.audit_repository(repo)
            self.assertEqual(data["summary"]["error"], 0)
            codes = {item["code"] for item in data["findings"]}
            self.assertIn("device-build-ahead-of-source", codes)
            self.assertIn("regression-label-drift", codes)
            self.assertIn("unprotected-current-contract", codes)
            self.assertEqual(data["suggested_next_build"], 215)

    def test_audit_detects_new_swift_file_not_in_target(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = self.make_repo(Path(directory))
            (repo / "Resonance/Services/NewService.swift").write_text("struct NewService {}\n", encoding="utf-8")
            data = rbw.audit_repository(repo)
            codes = {item["code"] for item in data["findings"]}
            self.assertIn("swift-file-not-in-target", codes)
            self.assertEqual(data["summary"]["status"], "error")

    def test_scope_playback_and_download_requires_device(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = self.make_repo(Path(directory))
            data = rbw.scope_changes(
                repo,
                [
                    "Resonance/Services/PlayerController.swift",
                    "Resonance/Services/RemoteDownloadService.swift",
                ],
            )
            names = {item["name"] for item in data["categories"]}
            self.assertIn("playback-controller", names)
            self.assertIn("downloads", names)
            self.assertTrue(data["requires_physical_device"])
            self.assertEqual(data["max_risk"], 5)

    def test_init_infers_next_build_from_device_history(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            repo = self.make_repo(base)
            workspace = base / "build-215"
            args = argparse.Namespace(
                directory=workspace,
                repo=repo,
                repository=rbw.DEFAULT_REPOSITORY,
                ref=rbw.DEFAULT_REF,
                commit="641b868b3171c0748e360294c51eebdcb7a84dcb",
                intent="Protect cached startup while adding one focused change.",
                issue_or_pr="",
                version=None,
                build=None,
                base=None,
                files=["Resonance/Views/SettingsView.swift"],
                force=False,
            )
            self.assertEqual(rbw.init_workspace(args), 0)
            manifest = json.loads((workspace / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(manifest["version"], "1.0.6")
            self.assertEqual(manifest["build"], 215)
            self.assertTrue((workspace / "contract-audit.md").is_file())
            self.assertTrue((workspace / "release-note.md").is_file())

    def test_record_rejects_embedded_credentials(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            repo = self.make_repo(base)
            workspace = base / "work"
            init_args = argparse.Namespace(
                directory=workspace,
                repo=repo,
                repository=rbw.DEFAULT_REPOSITORY,
                ref=rbw.DEFAULT_REF,
                commit="abc123",
                intent="Test evidence recording.",
                issue_or_pr="",
                version="1.0.6",
                build=215,
                base=None,
                files=[],
                force=False,
            )
            self.assertEqual(rbw.init_workspace(init_args), 0)
            record_args = argparse.Namespace(
                workspace=workspace,
                gate="custom",
                status="passed",
                kind="command",
                command="curl https://user:password@example.com",
                evidence="",
                notes="",
                create=True,
            )
            self.assertEqual(rbw.record_gate(record_args), 2)

    def test_init_tracks_every_scoped_runtime_validation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            repo = self.make_repo(base)
            workspace = base / "work"
            args = argparse.Namespace(
                directory=workspace,
                repo=repo,
                repository=rbw.DEFAULT_REPOSITORY,
                ref=rbw.DEFAULT_REF,
                commit="abc123",
                intent="Validate playback behavior.",
                issue_or_pr="",
                version="1.0.6",
                build=215,
                base=None,
                files=["Resonance/Services/PlayerController.swift"],
                force=False,
            )
            self.assertEqual(rbw.init_workspace(args), 0)
            manifest = json.loads((workspace / "manifest.json").read_text(encoding="utf-8"))
            runtime_entries = [name for name in manifest["validation"] if name.startswith("runtime_")]
            self.assertGreaterEqual(len(runtime_entries), 4)
            self.assertIn("physical_device_runtime_acceptance", manifest["validation"])
            self.assertIn("produced_app_bundle_identity", manifest["validation"])

    def test_permission_command_records_explicit_decision(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            repo = self.make_repo(base)
            workspace = base / "work"
            init_args = argparse.Namespace(
                directory=workspace,
                repo=repo,
                repository=rbw.DEFAULT_REPOSITORY,
                ref=rbw.DEFAULT_REF,
                commit="abc123",
                intent="Test permission recording.",
                issue_or_pr="",
                version="1.0.6",
                build=215,
                base=None,
                files=[],
                force=False,
            )
            self.assertEqual(rbw.init_workspace(init_args), 0)
            permission_args = argparse.Namespace(
                workspace=workspace,
                name="launch_physical_app",
                allow=True,
                deny=False,
                notes="User explicitly authorized launching the test build.",
            )
            self.assertEqual(rbw.record_permission(permission_args), 0)
            manifest = json.loads((workspace / "manifest.json").read_text(encoding="utf-8"))
            self.assertTrue(manifest["permissions"]["launch_physical_app"])
            records = (workspace / "evidence/permissions.jsonl").read_text(encoding="utf-8").splitlines()
            self.assertEqual(len(records), 1)
            self.assertTrue(json.loads(records[0])["allowed"])

    def test_release_ready_requires_device_permissions_and_complete_gates(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            repo = self.make_repo(base)
            workspace = base / "work"
            init_args = argparse.Namespace(
                directory=workspace,
                repo=repo,
                repository=rbw.DEFAULT_REPOSITORY,
                ref=rbw.DEFAULT_REF,
                commit="abc123",
                intent="Validate playback behavior.",
                issue_or_pr="",
                version="1.0.6",
                build=215,
                base=None,
                files=["Resonance/Services/PlayerController.swift"],
                force=False,
            )
            self.assertEqual(rbw.init_workspace(init_args), 0)
            for relative in ("change-plan.md", "validation-plan.md", "acceptance.md", "release-note.md"):
                target = workspace / relative
                target.write_text(
                    target.read_text(encoding="utf-8").replace("[TODO", "[DONE").replace("TBD", "resolved"),
                    encoding="utf-8",
                )
            manifest_path = workspace / "manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            for entry in manifest["validation"].values():
                entry["status"] = "passed"
                entry["command"] = "echo validated" if entry.get("kind") == "command" else ""
                entry["notes"] = "Validated with privacy-safe evidence."
                entry["evidence"] = ""
            manifest["release_decision"] = "accepted"
            manifest["rollback"] = {
                "reference": "stable-build",
                "instructions": "Restore the stable commit and rerun gates.",
                "verified": True,
            }
            manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
            verify_args = argparse.Namespace(workspace=workspace, release_ready=True)
            self.assertEqual(rbw.verify_workspace(verify_args), 1)
            manifest["permissions"]["signed_device_install"] = True
            manifest["permissions"]["launch_physical_app"] = True
            manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
            self.assertEqual(rbw.verify_workspace(verify_args), 0)

    def test_version_plan_is_non_mutating_and_complete(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = self.make_repo(Path(directory))
            data = rbw.version_plan(repo, "1.0.7", 215)
            paths = {item["path"] for item in data["edits"]}
            self.assertIn("Resonance.xcodeproj/project.pbxproj", paths)
            self.assertIn("Tools/RegressionChecks.sh", paths)
            self.assertIn("README.md", paths)
            self.assertIn("Resonance/Info.plist", paths)


if __name__ == "__main__":
    unittest.main()
