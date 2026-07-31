# Resonance Behavior Proof and Validation

## Contents

1. General change proof
2. Performance proof
3. Subsystem proof matrix
4. Validation ladder
5. Claim boundaries
6. Acceptance and rejection

## 1. General change proof

Use this for every repair, feature, refactor, or release build:

```markdown
# Resonance build proof

## Source and identity
- repository/ref/commit:
- dirty state at start:
- version/build:
- stability/rollback reference:

## Primary intent
- user-visible intent:
- reproduction or feature scenario:
- explicit non-goals:

## Behavior contract
- inputs and outputs:
- ordering/tie-breaking:
- stable IDs/navigation identity:
- legal state transitions:
- cancellation/latest-generation-wins:
- cache authority/refresh semantics:
- persistence and unrelated-data preservation:
- numeric clamps/timing authority/randomness:
- actor isolation/Sendable assumptions:
- privacy boundary:

## Regression protection
- assertions/fixtures added or changed:
- obsolete assertion deliberately replaced:
- new Swift target membership:

## Validation
- contract audit:
- RegressionChecks.sh:
- git diff --check:
- PreflightBuild.sh:
- simulator scenario:
- fixture/authorized remote scenario:
- physical-device scenario:
- produced app version/build:
- signature/install/launch facts:
- diagnostics privacy audit:

## Remaining uncertainty
- pending/not run/blocked:

## Rollback
- reference:
- instructions:
- post-rollback verification:
```

Write the proof before accepting the patch, not after a failure forces reconstruction.

## 2. Performance proof

Add these fields for performance work:

```markdown
## Workload
- before/after manifest hashes:
- environment/cache/network/configuration:
- warmups/repetitions:

## Performance evidence
- confirmed hotspot and profiler:
- before p50/p95/p99/N:
- after p50/p95/p99/N:
- median delta confidence interval:
- Cliff's delta:
- secondary metric:
- new profile after patch:
```

A faster single run or source inspection is not proof.

## 3. Subsystem proof matrix

| Area | Required proof | Runtime check |
|---|---|---|
| App activation/startup | Same cache authority and activation order; cache I/O off-main; no stale prewarm publication | Cold, warm local, warm remote offline, rapid scene phase |
| SwiftUI publication | Only intended views observe changed state; unchanged values are not republished | Fixed interaction during playback plus SwiftUI/body-update evidence |
| Navigation | Layer/tab/detail IDs, gestures, safe areas, hit testing, and accessibility remain stable | Every affected path, ordinary scroll, screenshots/snapshots |
| Local library | Cached startup, ignored paths, stable IDs/grouping, targeted refresh, unrelated records intact | Warm launch, one-file save/download, remove/delete, manual scan, relaunch |
| Metadata | Direct write support, per-file results, editor dismissal/background work, artwork semantics | FLAC/MP3 external reader, unsupported format, relaunch |
| Remote catalog | Cached offline browse, explicit refresh, grouping, revision/cache keys, stale rejection | Offline cache, large first transition, slow/rapid refresh |
| Downloads | Ordering, replacement, cancellation, cleanup, restore, progress bounds, targeted index | Queue active/completed/failed/cancelled/requeue/background |
| Local playback | Queue/index, formats, matrix, preload compatibility, completion, quarantine/fallback | Stereo, high-rate, 5.1, boundary, forced matrix failure |
| Remote playback | Preparation generation, start, seek ordering, clamps, queue advance, fallback | Rapid/exact-end seek, next/repeat/shuffle, long playback while browsing |
| Artwork | Off-main size-specific decode, cache bounds, source precedence, warning/persistence | Scroll/memory, provider failure, change artwork, relaunch/file check |
| Settings/themes | Narrow observation, debounce/focus, dynamic version, persistence, contrast, credential privacy | Edit during playback, all themes/appearance, QR permission cases |
| Diagnostics | Events are private, bounded, and do not block hot paths | Privacy audit, delete/copy, correlation to behavior |
| Release | Version/build synchronized and read from output; sign/install/launch separated | Bundle inspection, signature/archive integrity, exact device record |

## 4. Validation ladder

### Level 0: bundled scripts

```bash
python3 -m unittest discover -s scripts -p 'test_*.py'
python3 -m py_compile scripts/*.py
```

### Level 1: repository contracts

```bash
python3 <skill>/scripts/resonance_build_workbench.py audit . --strict
bash Tools/RegressionChecks.sh
git diff --check
```

Do not delete a failing assertion merely to pass. Preserve or deliberately replace its behavior contract.

### Level 2: strict compile

```bash
bash Tools/PreflightBuild.sh
```

Require simulator and generic iPhoneOS compilation under Swift 6 complete strict concurrency with warnings as errors.

### Level 3: controlled simulator

Run the scoped scenario and one stress case. Record configuration, cache state, fixture, visible result, diagnostics range, and screenshots/traces.

### Level 4: physical device

Required for:

- audible playback and gaplessness
- 5.1 routing and playback speed
- route changes and interruptions
- background download/suspension
- Lock Screen behavior
- energy, thermal, and memory pressure
- file sharing/permission behavior
- long-idle stability

Do not install or launch without explicit authorization. Do not uninstall first.

### Level 5: release evidence

Verify output bundle version/build, signature, bundle identifier, archive integrity, install status, launch status, diagnostics privacy, and README provenance.

## 5. Claim boundaries

Keep these statements separate:

- source parses
- simulator/generic device compiles
- signed device build succeeds
- signature verifies
- app installs in place
- app launches
- scenario executes
- manual user acceptance succeeds
- audible/background/thermal behavior succeeds

Never infer a later statement from an earlier one.

## 6. Acceptance and rejection

Accept when:

- exact source and build identity are recorded
- the primary intent is demonstrated
- continuation contracts and regression protection are equal or stronger
- required static/compile/runtime/device gates pass
- remaining uncertainty is explicit and does not invalidate the claim
- rollback is practical and verified
- no private data is present

Reject or block when:

- version/build provenance conflicts remain unexplained
- a patch mixes unrelated intents
- tests/contracts are weakened to fit code
- work is merely shifted to another visible interaction
- cache, memory, requests, or tasks become unbounded
- stale publication/state ordering is unproven
- data integrity or audio behavior lacks required device evidence
- signed/install/launch/release claims exceed actual evidence
