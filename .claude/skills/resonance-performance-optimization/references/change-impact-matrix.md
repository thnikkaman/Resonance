# Resonance Change Impact Matrix

## Contents

1. Global rules
2. Subsystem matrix
3. Cross-subsystem escalation
4. Regression assertion guidance

## 1. Global rules

Every source change requires:

- exact ref/commit and dirty state
- repository contract audit
- `Tools/RegressionChecks.sh`
- `git diff --check`
- `Tools/PreflightBuild.sh`
- a scoped runtime check when behavior can execute
- explicit pending/not-run reporting

Use `resonance_build_workbench.py scope` as the machine-readable source of truth. This document explains the rationale.

## 2. Subsystem matrix

| Files/area | Risk | Preserve | Minimum runtime acceptance |
|---|---:|---|---|
| `ResonanceApp.swift`, startup portions of `LibraryStore.swift` and `RemoteLibraryStore.swift` | 4 | Activation order, cache-first authority, off-main cache I/O, stale browse rejection, download resume order | Cold launch, warm local launch, warm remote offline, rapid scene transitions |
| `LibraryDatabase.swift`, `LibraryStore.swift`, `Track.swift`, `LibraryBrowseGrouping.swift` | 4 | IDs, ordering, transactions, ignored paths, targeted refresh, lightweight startup rows | Grouping parity, one-file refresh, removal semantics, relaunch/persistence |
| `MetadataReader.swift`, `MetadataWriteBatch.swift`, `SmartLibraryViews.swift` | 4 | Direct FLAC/MP3 writes, unsupported errors, per-file results, embedded/app-only artwork distinction | FLAC/MP3 external-reader check, unsupported format, no full scan |
| `RemoteLibraryStore.swift`, `RemoteURLSupport.swift`, Streaming catalog views | 4 | Cached offline use, explicit refresh, cache keys, latest-generation-wins, OpenSubsonic identity/grouping | Offline cached browse, slow/rapid refresh, grouping/sort parity |
| `RemoteDownloadService.swift` and download UI | 5 | Queue order, bounded progress, cancellation cleanup, replacement choices, background restore, targeted index | Cancel/requeue/replace/keep/incremental index; physical-device background test |
| `PlayerController.swift`, `PlayerViews.swift` | 5 | Queue/index, repeat/shuffle, progress isolation, seek authority, exact-end clamp, fallback | Start/seek/end/next matrix, rapid seek, Lock Screen, long playback while navigating |
| `GaplessAudioEngine.swift` | 5 | Matrix routes/gains, source rate, preload compatibility, generations, quarantine/fallback | Simulator control flow plus physical stereo/high-rate/5.1 audible acceptance |
| `RootView.swift`, Library/album/Streaming navigation views | 4 | Layer/tab identity, gestures, safe areas, tab bar, mini-player, hit testing, accessibility | All tab/detail paths, index gestures, mini-player docks, keyboard, screenshots |
| `ArtworkView.swift`, `ArtworkSearchService.swift`, online picker, image assets | 4 | Off-main thumbnailing, bounded cache, source precedence, match credibility, warning/persistence | Scroll/memory, provider failure, warning states, relaunch/file verification |
| `AppSettings.swift`, `SettingsView.swift` | 3 | Narrow observation, debounce/focus, dynamic build label, category state, contrast, credential privacy | Edit while playing, all themes/appearance, QR permission/payload behavior |
| `ResonanceDiagnostics.swift`, `AppErrorLog.swift` | 4 | Privacy, bounded file, noninterference, synchronous-only critical boundaries | Privacy audit, file controls, event correlation |
| Project, plist, validation scripts, README | 3 | Version/build consistency, target membership, truthful provenance, strict gates | Strict audit, produced-bundle version, signature/archive evidence |
| `Tools/ResonanceServer.py` | 3 | Deterministic manifest/ranges/content lengths, private-data isolation | Python compile, range/seek/end fixture tests |

## 3. Cross-subsystem escalation

Escalate to the highest risk and union all validation when a patch crosses boundaries.

Examples:

- `PlayerController.swift` plus `RemoteLibraryStore.swift`: test playback preparation generation, seek, queue, and large-catalog responsiveness.
- `RemoteDownloadService.swift` plus `LibraryStore.swift`: test cancellation cleanup, targeted SQLite upsert, open detail refresh, removal semantics, and background restore.
- `RootView.swift` plus `AppSettings.swift`: test settings edits during playback, inactive-tab invalidation, every safe area/dock, and theme contrast.
- `ArtworkSearchService.swift` plus metadata files: test online selection, warning state, sidecar/app override, direct file write, and relaunch.
- project/version files plus source: do not bump version until the source patch and gates are final; then synchronize all provenance in one deliberate release step.

## 4. Regression assertion guidance

Good assertions protect:

- source target membership
- dynamic version/build behavior
- required state variables and generation guards
- absence of a known hazardous path
- exact count of a deliberately unique modifier/task/overlay
- deterministic coordinate/grouping fixtures
- privacy or fallback boundaries

Weak assertions protect:

- arbitrary whitespace
- an entire function body
- a local variable name with no behavioral meaning
- a temporary implementation detail
- a hardcoded UI label that should be dynamic

When replacing an implementation, replace obsolete assertions with equal or stronger semantic protection in the same build.
