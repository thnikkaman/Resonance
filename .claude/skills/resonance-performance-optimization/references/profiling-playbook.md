# Resonance Profiling Playbook

## Contents

1. Comparable capture
2. Diagnostics logs
3. SwiftUI invalidation
4. Startup and local library
5. Remote catalog and network
6. Artwork and memory
7. Downloads
8. Playback and seeking
9. Build performance

## 1. Comparable capture

Record for every run:

- exact ref and commit
- simulator/device model and OS
- Debug/Release
- cold/warm and cache state
- local/remote track counts
- network condition
- exact interaction sequence
- diagnostics mode
- warmups and repetitions
- trace time range

Do not compare cold Debug simulator data with warm Release device data. Use the workflow manifest check before declaring a before/after result.

## 2. Diagnostics logs

Resonance emits:

```text
ISO-8601 event.name key=value key=value
```

Values may contain spaces. Use the bundled parser.

```bash
python3 scripts/resonance_diagnostics.py summary Resonance-Diagnostics.log
python3 scripts/resonance_diagnostics.py compare before.log after.log --min-samples 5
python3 scripts/resonance_diagnostics.py audit Resonance-Diagnostics.log
```

The comparison reports timing distributions, bootstrap median-delta confidence intervals, Cliff's delta, and event-count changes. Missing events are missing evidence. Diagnostics mode adds work; confirm hot-path findings with Instruments when overhead matters.

## 3. SwiftUI invalidation

Use SwiftUI and Time Profiler together. Reproduce a fixed sequence during playback.

Inspect:

- inactive tab/layer body evaluation
- root dependency changes from playback or settings
- sort/group/filter work in computed view properties
- unstable IDs and row replacement
- repeated tasks from incomplete `.task(id:)` keys
- overlays observing full download/player objects
- main-thread image, JSON, SQLite, file, or diagnostic I/O

Prefer narrowing ownership/observation, dedicated projections, revision-keyed snapshots, lazy inactive construction, and unchanged-publication suppression at the owner.

Avoid blanket `EquatableView`, `AnyView`, or manual `objectWillChange` tricks unless the trace isolates the benefit and identity/animation behavior is proven.

## 4. Startup and local library

Measure separately:

- first launch without persisted data
- warm launch with display snapshot and database
- explicit full refresh
- one-file metadata refresh
- one completed download refresh

Inspect:

- time to first cached content
- SQLite rows with/without artwork
- file inventory and modification-date calls
- metadata parse count
- display snapshot encoding/writes
- `tracks` publication count and size

Guardrails:

- do not block first content on artwork hydration
- do not scan the full tree during ordinary warm startup
- do not rewrite a display snapshot per item in a batch
- preserve ignored paths, stable IDs, and explicit refresh semantics

## 5. Remote catalog and network

Test cached offline browse, explicit refresh, large first load, grouping switches, rapid refresh replacement, slow artwork, and playback start.

Inspect:

- main-actor decode/grouping
- serial artwork requests before playback
- projections built for invisible surfaces
- stale work publishing after a new generation
- unbounded request fan-out
- repeated unchanged status strings

A correct change keeps cached browsing usable while the server is unavailable.

## 6. Artwork and memory

Use Allocations plus Time Profiler while scrolling grids and revisiting details.

Inspect:

- full-resolution decode instead of thumbnail decode
- duplicate conversion for the same source/pixel size
- incomplete cache keys
- caches without count/cost limits
- main-actor fallback search/decode
- retained source data or images after rows disappear

Preserve source precedence and the warning distinction between embedded/provided artwork and automatic fallback artwork.

## 7. Downloads

Exercise queue growth, active progress, cancellation, replacement, failure, completion, restoration, and incremental library appearance.

Inspect:

- publication frequency versus transport cadence
- full queue copies
- temporary file cleanup
- background delegate actor hops
- full-library scans after each completion
- unbounded concurrent requests

## 8. Playback and seeking

Profile each backend separately.

Capture:

- request to control-flow/audible start
- preparation duration and formats
- timer cadence and publication counts
- seek request ID, target, completion, and resumed clock
- preload readiness
- boundary begin/end and fallback
- Lock Screen artwork work

Verify:

- no broad invalidation at timer cadence
- no stale seek completion wins
- elapsed/duration remain clamped
- queue and repeat/shuffle order remain stable
- matrix failure still reaches fallback
- remote experimental paths retain normal-load fallback

Require physical-device acceptance for audible gaps, speed, 5.1, route changes, energy, thermals, and long-idle behavior.

## 9. Build performance

Use build timing only when compilation is the reported issue.

```bash
xcodebuild -project Resonance.xcodeproj -target Resonance \
  -configuration Debug -showBuildTimingSummary build
```

Separate clean and incremental builds. Preserve Swift 6 complete strict concurrency and warnings-as-errors. Do not weaken compile gates to improve build time.
