# Resonance optimization proof

## Change

Build 280 ports MilkDrop 2's title texture/mesh/feedback path into the vendored ProjectM renderer and removes four
identified sources of avoidable frame contention: unchanged texture-path resets, synchronous GL diagnostic probes,
transition-driven drawable reallocations, and UIKit lyric rasterization inside the display callback.

## Workload
- manifest: `performance-evidence/projectm-lyrics-native-round-01/manifest.json`
- repository/ref/commit: `thnikkaman/Resonance`, `agent/alpha-3.7.4-source`, implementation commit `348a5d6`
- repetitions: one warmup plus five equivalent interaction sequences

## Performance evidence
- confirmed hotspot: build 279 repeatedly changed its ProjectM drawable between 1966x904 and 1756x808 during the
  representative session; source inspection also confirmed per-frame synchronous GL state/error probes and texture
  manager resets on every preset load.
- before p50/p95/p99/N: unavailable because build 279 did not yet record bounded aggregate frame windows.
- after p50/p95/p99/N: pending the user-launched build-280 physical workload.
- median delta CI95: pending comparable physical samples.
- Cliff's delta: pending comparable physical samples.
- secondary metrics: build 280 records 120-frame windows, preset-load duration, lyric preparation/upload duration,
  frame-gap threshold counts, and actual drawable changes without logging lyric text, song names, or paths.

## Equivalence proof
- same inputs -> same outputs: preset/audio inputs, shuffle/favorite/banish semantics, and 60 FPS target are preserved.
- ordering and tie-breaking: preset ordering and weighted shuffle are unchanged.
- stable IDs and navigation identity: fullscreen entry/exit and preset identities are unchanged.
- queue/state-machine transitions: completed lyric burns for one frame before the prepared next line is uploaded.
- cache authority and refresh semantics: identical texture paths no longer clear ProjectM's texture manager.
- cancellation and stale-result rejection: detached lyric preparation uses a generation guard and destroys stale data.
- numeric clamps/floating point/randomness: the original MilkDrop 16-by-8 mesh and title progress formulas are ported;
  drawable scale is fixed at 0.75.
- persistence/file/database behavior: no persistence or database format changed.
- actor isolation and Sendable safety: strict Swift 6 simulator and generic-device compilation passed.
- privacy-safe diagnostics: diagnostics contain dimensions, counts, and durations only; lyric and track text are absent.

## Validation
- diagnostics audit: build-279 input log reviewed; no obvious credentials, authenticated URLs, lyric text, or private
  paths were found. Build-280 records only bounded numeric summaries.
- unit tests: focused native ProjectM source contracts passed.
- Tools/RegressionChecks.sh: new ProjectM contracts pass; the full script reaches an unrelated pre-existing stale
  Streaming alphabet assertion.
- git diff --check: first-party/app diff passed. The unmodified upstream ProjectM source retains its original CRLF and
  trailing whitespace in generated/license files, so the all-path check reports vendor-only whitespace warnings.
- Tools/PreflightBuild.sh: strict simulator and generic-device builds passed.
- simulator scenario: a clean strict build passed with the generated ProjectM XCFramework physically absent, proving
  the vendored source/build-script path is sufficient.
- physical-device scenario, when required: signed arm64 Release, strict signature verification, in-place installation,
  and device version/build inspection passed for 2.1/build 280. Codex did not launch the app; runtime metrics are pending.

## Rollback
- command or reversal: revert the build-280 implementation commit and reinstall the retained build-279 artifact in
  place without uninstalling.
- post-rollback checks: strict preflight, signature verification, bundle version inspection, and the same manual
  fullscreen workload.
