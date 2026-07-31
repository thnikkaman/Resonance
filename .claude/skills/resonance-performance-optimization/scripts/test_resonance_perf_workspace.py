#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import tempfile
import unittest
from pathlib import Path

import resonance_perf_workspace as rw


class WorkspaceTests(unittest.TestCase):
    def test_normalized_manifests_ignore_notes(self) -> None:
        before = {"scenario": "x", "notes": "before", "steps": [1, 2]}
        after = {"scenario": "x", "notes": "after", "steps": [1, 2]}
        self.assertEqual(rw.normalize_for_compare(before), rw.normalize_for_compare(after))

    def test_manifest_difference_is_detected(self) -> None:
        diffs = rw.differences({"cache": "warm"}, {"cache": "cold"})
        self.assertEqual(len(diffs), 1)
        self.assertIn("warm", diffs[0])

    def test_candidate_scoring(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "candidates.json"
            path.write_text(
                json.dumps(
                    [
                        {
                            "candidate": "narrow observation",
                            "evidence": "SwiftUI trace",
                            "impact": 4,
                            "confidence": 5,
                            "effort": 2,
                            "risk": 1,
                        }
                    ]
                ),
                encoding="utf-8",
            )
            args = argparse.Namespace(
                candidates=path,
                threshold=2.0,
                min_confidence=3,
                format="json",
            )
            self.assertEqual(rw.score_candidates(args), 0)

    def test_workspace_init_and_compare(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "round-01"
            args = argparse.Namespace(
                directory=root,
                repo="thnikkaman/Resonance",
                ref="agent/alpha-3.7.4-source",
                commit="abc123",
                scenario="warm-library-startup",
                device="iPhone simulator",
                os="iOS",
                configuration="Debug",
                cache_state="warm",
                local_tracks=10,
                remote_tracks=20,
                network="offline",
                diagnostics_enabled=False,
                warmups=1,
                repetitions=5,
                force=False,
            )
            self.assertEqual(rw.init_workspace(args), 0)
            compare_args = argparse.Namespace(
                before=root / "before" / "workload.json",
                after=root / "after" / "workload.json",
            )
            self.assertEqual(rw.compare_manifests(compare_args), 0)
            self.assertTrue((root / "proof.md").exists())


if __name__ == "__main__":
    unittest.main()
