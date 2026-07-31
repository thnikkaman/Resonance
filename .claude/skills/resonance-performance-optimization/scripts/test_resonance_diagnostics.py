#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import resonance_diagnostics as rd


class DiagnosticsTests(unittest.TestCase):
    def test_parse_values_with_spaces(self) -> None:
        record = rd.parse_line(
            "2026-07-30T12:00:00Z playback.stage message=Preparing remote track result=ready durationMs=120.5",
            1,
        )
        self.assertIsNotNone(record)
        assert record is not None
        self.assertEqual(record.details["message"], "Preparing remote track")
        self.assertEqual(record.details["result"], "ready")
        self.assertEqual(record.details["durationMs"], "120.5")

    def test_summary_has_percentiles_and_rate(self) -> None:
        records = [
            rd.parse_line("2026-07-30T12:00:00Z artwork.thumbnail durationMs=100", 1),
            rd.parse_line("2026-07-30T12:01:00Z artwork.thumbnail durationMs=200", 2),
        ]
        data = rd.summarize([record for record in records if record is not None])
        timing = data["timings_ms"][0]
        self.assertEqual(timing["p50"], 150)
        self.assertEqual(data["event_rates_per_minute"]["artwork.thumbnail"], 2.0)

    def test_compare_confirms_improvement(self) -> None:
        before = [
            rd.parse_line(f"2026-07-30T12:00:{i:02d}Z artwork.thumbnail durationMs={100 + i}", i + 1)
            for i in range(10)
        ]
        after = [
            rd.parse_line(f"2026-07-30T12:01:{i:02d}Z artwork.thumbnail durationMs={50 + i}", i + 1)
            for i in range(10)
        ]
        result = rd.compare(
            [record for record in before if record is not None],
            [record for record in after if record is not None],
            min_samples=5,
            regression_threshold=10,
            bootstrap_iterations=300,
            seed=7,
        )
        row = result["timings_ms"][0]
        self.assertEqual(row["status"], "improved")
        self.assertLess(row["cliffs_delta"], 0)
        self.assertEqual(result["improvement_count"], 1)

    def test_compare_confirms_regression_and_cli_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            before_path = Path(directory) / "before.log"
            after_path = Path(directory) / "after.log"
            before_path.write_text(
                "\n".join(
                    f"2026-07-30T12:00:{i:02d}Z playback.start durationMs={50 + i}"
                    for i in range(10)
                )
                + "\n",
                encoding="utf-8",
            )
            after_path.write_text(
                "\n".join(
                    f"2026-07-30T12:01:{i:02d}Z playback.start durationMs={100 + i}"
                    for i in range(10)
                )
                + "\n",
                encoding="utf-8",
            )
            code = rd.main(
                [
                    "compare",
                    str(before_path),
                    str(after_path),
                    "--bootstrap",
                    "300",
                    "--fail-on-regression",
                    "--format",
                    "json",
                ]
            )
            self.assertEqual(code, 2)

    def test_small_sample_is_insufficient(self) -> None:
        before = [rd.parse_line("2026-07-30T12:00:00Z e durationMs=100", 1)]
        after = [rd.parse_line("2026-07-30T12:01:00Z e durationMs=50", 1)]
        result = rd.compare(
            [record for record in before if record is not None],
            [record for record in after if record is not None],
            min_samples=5,
            bootstrap_iterations=10,
        )
        self.assertEqual(result["timings_ms"][0]["status"], "insufficient")

    def test_audit_flags_sensitive_key_and_url(self) -> None:
        records = [
            rd.parse_line("2026-07-30T12:00:00Z remote.test token=abc", 1),
            rd.parse_line("2026-07-30T12:00:01Z remote.test endpoint=https://private.example", 2),
        ]
        findings = rd.audit([record for record in records if record is not None])
        categories = {finding["category"] for finding in findings}
        self.assertIn("credential", categories)
        self.assertIn("url", categories)


if __name__ == "__main__":
    unittest.main()
