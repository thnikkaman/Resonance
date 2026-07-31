# Resonance project operating contract

This file is the project-local operating manual. It keeps implementation work tied to
the verified source, the documented product contracts, and observable validation.

## Source and artifact truth

Use this precedence when records disagree:

1. Actual checkout, Git state, build settings, and installed bundle metadata.
2. The latest dated entry in `/Users/brian/Downloads/Resonance Alpha — Codex Development Handoff.docx`.
3. The current README summary.
4. Older historical entries and conversational assumptions.

Never resolve a conflict by guessing. Run `Tools/ProjectStateCheck.sh` and record the
result in `Docs/PROJECT-STATE.md` before continuing.

The project default version/build and an explicitly overridden simulator or device
artifact are separate identities. Report both when they differ. An installed bundle
is runtime evidence; it does not prove that the checkout's default build settings
were changed.

## Required work loop

Every non-trivial change follows this sequence:

1. Resolve the exact branch, commit, dirty state, target, and artifact.
2. Read this file, `README.md`, `Docs/ARCHITECTURE.md`, `Docs/PROJECT-STATE.md`, and the handoff.
3. Reproduce the reported behavior or establish a named baseline workload.
4. Define the owner, invariant, acceptance oracle, and rollback point before editing.
5. Change one causal mechanism at a time. Keep feature, cleanup, and optimization work separate.
6. Run the narrowest relevant tests, then the repository gates.
7. Update the work queue, README, and handoff only with evidence that actually exists.

Do not claim simulator or physical-device runtime behavior from compilation, installation,
source inspection, or a screenshot-free automation step. Do not launch or install on
`SaiyanDenawa` unless the user explicitly requests it. Do not launch the simulator or
capture screenshots unless the user requests that validation; the user owns screenshot
capture by default.

## Stable ownership boundaries

Keep behavior in its owning module. Consult `Docs/ARCHITECTURE.md` before moving code.

- `RootView.swift` owns tab composition, navigation layers, safe areas, and gesture arbitration.
- `LibraryView.swift` and `SmartLibraryViews.swift` own local browsing and local editing presentation.
- `StreamingLibraryView.swift` owns remote browsing presentation and alphabet gestures.
- `LibraryStore.swift` owns local catalog state, grouping, overrides, and targeted refresh.
- `RemoteLibraryStore.swift` owns remote catalogs, cache activation, refresh generations, and remote projections.
- `RemoteDownloadService.swift` and its manager own download queue state, cancellation, persistence, and indexing handoff.
- `PlayerController.swift` owns playback state and backend selection.
- `GaplessAudioEngine.swift` owns graph lifecycle, preload, explicit routing, and compatibility fallback.
- `LibraryDatabase.swift` owns SQLite persistence through its actor boundary.
- `ArtworkSearchService.swift` and artwork caches own provider work, candidate bounds, decoding, and artwork identity.
- `ResonanceDiagnostics.swift` owns privacy-safe diagnostics; hot UI/catalog paths use deferred records.

Views must not become alternate stores, playback engines, persistence layers, or network clients.

## Evidence and safety rules

- Preserve stable IDs, ordering, grouping, cache authority, cancellation semantics, and persisted data.
- Keep credentials, authenticated URLs, private music, signing secrets, and private keys out of source, logs, tests, and docs.
- Treat `Tools/RegressionChecks.sh` as source-contract evidence, not runtime acceptance.
- Treat simulator playback, performance, and audio traces as control-flow evidence only; audible, thermal, background, and 5.1 claims require the physical device.
- Use named workloads and an equivalence oracle for performance work. Do not optimize from static inspection alone.
- Keep build logs, `.build/`, diagnostics, screenshots, and simulator artifacts untracked.

