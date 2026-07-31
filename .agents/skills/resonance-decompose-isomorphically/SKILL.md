---
name: resonance-decompose-isomorphically
description: >-
  Find and split oversized or over-coupled Swift files in the Resonance iOS repository while preserving behavior, internal and public symbol access, Xcode target membership, SwiftUI identity, actor isolation, playback timing, diagnostics, and measured performance. Use for requests to de-monolithize, modularize, split a giant file, reduce compile pressure, extract extensions or services, or plan safe seams in Resonance. Require repository baselines, characterization tests, one seam per commit, and the full Resonance validation ladder; do not use for ordinary duplication cleanup without file-splitting intent.
---

# Resonance Decompose Isomorphically

> **One Rule:** A split is valid only when the code moved and the observable product did not. No baseline, confirmed seam, and four-axis proof means no extraction.

## First actions

Resolve `SKILL_DIR` to the directory containing this `SKILL.md`. Run bundled tools as `python3 "$SKILL_DIR/scripts/<tool>.py"`; run repository commands from the repository root.

1. Read [references/RESONANCE-CONTRACT.md](references/RESONANCE-CONTRACT.md).
2. Resolve the repository root, branch, SHA, dirty state, current versions, Xcode target, and available Mac/device tooling.
3. Create or resume a sibling workspace at `<repo>__resonance_runs/decompose/<run-id>/`; never put generated analysis artifacts in the app repository.
4. Run `python3 "$SKILL_DIR/scripts/swift_seam_census.py" <repo> --json-out <workspace>/census.json --markdown-out <workspace>/census.md`.
5. Select the requested file even when it is below the default threshold. Report higher-risk files found by the census without silently expanding scope.
6. Run the existing regression gate before proposing a seam. If the baseline is red, stop extraction and separate the pre-existing failure.

## Route the request

| Request | Mode |
|---|---|
| Split one named file | Scoped: analyze that file plus direct collaborators, then pilot one seam. |
| De-monolithize the repository | Standard: census, rank, analyze top candidates, produce a staged plan, then execute only approved seams. |
| Reduce compile time or type-check pressure | Compile-first: capture clean/incremental build timing and compiler diagnostics before choosing a file boundary. |
| Simplify duplication without moving file boundaries | Use `resonance-refactor-isomorphically` instead. |
| Make the app faster | Use `resonance-profile-performance` first; decomposition is not an optimization by itself. |

## Mandatory loop

```text
1. CENSUS       -> measure size, declarations, state, responsibilities, churn, and target membership
2. MAP          -> trace state ownership, callers, effects, actor boundaries, and UI identity
3. BASELINE     -> regression, build, scenario, diagnostics, public/internal surface, and performance
4. HYPOTHESIZE  -> name a seam and the exact invariant it should isolate
5. CHARACTERIZE -> add tests or probes before moving uncovered behavior
6. PILOT        -> move one cohesive cluster with no cleanup or redesign
7. PROVE        -> behavior + symbol/access + performance + build/resource gates
8. COMMIT       -> one seam, one commit, one filled isomorphism card
9. REPEAT       -> re-run the census; stop when remaining seams are weaker than their risk
```

Every phase writes an artifact. Use the templates in `assets/seam-ledger.md` and the project contract as the required report vocabulary.

## Build the seam map

For each candidate file, record:

- declarations and `// MARK:` regions;
- stored state and property wrappers (`@State`, `@StateObject`, `@EnvironmentObject`, `@Published`, `@AppStorage`);
- actor isolation and `Task` ownership;
- imports and frameworks used (AVFoundation, MediaPlayer, UIKit, SwiftUI, SQLite, networking);
- direct callers, notification/selector strings, diagnostics events, cache keys, route names, and Xcode target membership;
- side effects: playback graph mutation, file writes, SQLite writes, network calls, downloads, navigation, animation, and logging;
- tests and regression assertions that reach the region;
- churn and co-change history from `git log --numstat -- <path>`.

Treat a seam as a hypothesis, not a visual preference. A good seam has cohesive state, narrow inputs/outputs, independent tests, and low cross-boundary mutation. A large `// MARK:` section alone is not evidence.

## Swift and Resonance landmines

Abort or redesign the seam when any of these are unresolved:

1. **File-scoped access:** moving an extension can break `private` members. Do not widen access merely to make the move compile without recording and reviewing the new module surface.
2. **Stored state:** Swift extensions cannot hold stored properties. Extracting state into a new object changes ownership, lifetime, observation, and concurrency; classify that as architecture work, not a mechanical split.
3. **SwiftUI identity:** replacing a nested view, changing generic type shape, moving `@State`, or changing environment injection can reset state, alter animation/navigation, or move gesture priority.
4. **Actor inference:** moving code can change inferred `@MainActor`, `Sendable` diagnostics, capture lifetime, task cancellation, or publication order.
5. **Overload/name lookup:** an extracted helper or extension can select a different overload or expose a symbol elsewhere in the target.
6. **Selectors and strings:** `#selector`, notifications, persistence keys, diagnostic event names, endpoint strings, and restoration identifiers are runtime API.
7. **Xcode membership:** every new Swift file must be in the Resonance Sources phase exactly once and in the intended target.
8. **Audio real-time safety:** do not introduce locks, allocations, logging, actor hops, or extra dispatch on render/boundary-sensitive paths.
9. **Fallback ownership:** keep the failed gapless graph quarantined and the remote player independent.
10. **Revision safety:** preserve catalog generation checks, stale-result rejection, and in-flight task coalescing.

Read [references/SEAM-PLAYBOOK.md](references/SEAM-PLAYBOOK.md) before extracting PlayerController, GaplessAudioEngine, LibraryStore, RemoteLibraryStore, RemoteDownloadService, RootView, LibraryView, StreamingLibraryView, SettingsView, or any type owning persistent state.

## Four-axis proof

Fill all four rows before marking a seam complete.

| Axis | Required evidence |
|---|---|
| Behavior | Same regression assertions and targeted scenario outcomes; same ordering, errors, persistence, UI identity, and diagnostics. Add characterization tests before the move for uncovered code. |
| Symbol/access | No unintended removals or visibility widening; old call sites compile; selector/string contracts remain; Xcode membership is correct. |
| Performance | Same-device, same-build-profile scenario remains inside the recorded variance envelope; no new main-actor work or audio-path indirection. |
| Build/resource | Swift 6 parse and strict simulator/device builds pass; clean/incremental build or type-check cost is neutral or better when compile pressure motivated the split. |

Run, in order:

```bash
git diff --check
Tools/RegressionChecks.sh
Tools/PreflightBuild.sh  # on a Mac with current Xcode
```

Then run the targeted simulator/device scenario named in the seam card. Never claim physical acceptance from compilation or a simulator.

## Extraction discipline

- Move code before improving it. Keep names, signatures, control flow, ordering, errors, strings, and comments stable in the extraction commit.
- Keep façade/call sites stable. Do not combine a split with a new protocol, state machine, data model, cache, or dependency injection layer.
- Add a new file only for a cohesive responsibility with a clear owner. Avoid `Helpers.swift`, `Utils.swift`, and extension dumping grounds.
- Make one mechanical move per commit. Re-run all gates before the next seam.
- Preserve the original file until the target membership and call sites prove the move. Ask before deleting any file.
- Reject a split whose only benefit is a smaller line count but whose coupling, build cost, or state topology becomes worse.

## Required outputs

Write these files in the sibling workspace:

```text
run.json
census.json
census.md
seam-ledger.md
baseline/validation.txt
baseline/performance.json              # when a hot path or compile pressure is involved
cards/<candidate>.md
verification/<candidate>.md
DECOMPOSITION_PLAN.md
FINAL_DECOMPOSITION_REPORT.md
```

The final report must list completed seams, rejected seams with reasons, validation rungs run/skipped, performance deltas, access-control changes, new files/target membership, remaining risks, and exact manual device checks.

## Stop conditions

Stop and report instead of extracting when the baseline is red, the working tree contains overlapping user edits, the target is generated, the seam requires state-ownership redesign, no characterization path exists, the only available comparison crosses machines/devices/build modes, or the physical-only acceptance criterion cannot be truthfully completed.

## Resources

- Project invariants and validation: [references/RESONANCE-CONTRACT.md](references/RESONANCE-CONTRACT.md)
- Swift/Resonance seam decisions: [references/SEAM-PLAYBOOK.md](references/SEAM-PLAYBOOK.md)
- Read-only census: `scripts/swift_seam_census.py`
- Artifact template: `assets/seam-ledger.md`
- Trigger and workflow checks: [SELF-TEST.md](SELF-TEST.md)
