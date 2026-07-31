# Resonance Seam Playbook

## Contents

- Candidate classification
- Boundary tests
- High-risk surfaces
- Compile-pressure track
- Seam experiment template
- Rejection rules

## Candidate classification

Classify before proposing a file move.

| Class | Typical shape | Default action |
|---|---|---|
| Pure model/formatting cluster | Deterministic transforms with value inputs and no global state | Strong extraction candidate after characterization tests. |
| View leaf | Small SwiftUI view with explicit inputs/actions and no navigation ownership | Good candidate if identity, accessibility, and environment dependencies are pinned. |
| View section with local state | `@State`, focus, gesture, animation, task, scroll proxy | Medium risk; prove lifetime and gesture ordering. |
| Store projection | Sorting/grouping/filtering over immutable snapshots | Extract only if revision checks, ordering, cache keys, and main-actor publication remain identical. |
| Persistence adapter | SQLite/file metadata/cache read/write | High risk; preserve transactions, atomic writes, paths, and targeted refresh behavior. |
| Playback state transition | AVAudioEngine/AVPlayer/MediaPlayer/seek/queue | Very high risk; prefer private extension grouping first and require device evidence. |
| Download lifecycle | URLSession background tasks, restoration, file moves, cancellation | Very high risk; preserve task identifiers and system callback ownership. |
| Root navigation/state owner | tabs, layered navigation, mini-player docking, app lifecycle | Very high risk; split leaf rendering before state ownership. |

## Boundary tests

A proposed boundary must answer all questions with evidence:

1. What state does it own, read, and mutate?
2. Who creates it and how long does it live?
3. Which actor/thread executes each entry point?
4. Which callbacks, tasks, observers, timers, delegates, or commands retain it?
5. Which orderings are observable?
6. Which errors/fallbacks are observable?
7. Which strings act as runtime contracts?
8. Which files, databases, caches, credentials, or network endpoints can it touch?
9. Which diagnostic events prove the boundary worked?
10. Which existing gate detects a bad move, and what new characterization test fills any gap?

A seam is confirmed only when the answers describe a smaller, coherent responsibility and the experiment passes. “This section looks self-contained” is not evidence.

## High-risk surfaces

### PlayerController and GaplessAudioEngine

Prefer extracting pure calculations, command setup, metadata publication, and remote/local adapters before splitting the state machine. Preserve audio-session setup, graph quarantine, engine start order, preloading, boundary callbacks, seek request IDs, clock holds, queue advancement, and MediaPlayer commands. Compare physical-device diagnostics and audible behavior.

### LibraryStore and LibraryDatabase

Separate pure inventory/grouping logic from state publication before separating persistence. Preserve ignored paths, stable IDs, display snapshot precedence, SQLite reconciliation, artwork hydration, targeted upserts, metadata overrides, and explicit scan semantics.

### RemoteLibraryStore

Separate decoding and pure projections before moving activation state. Preserve OpenSubsonic request signing, endpoint/query encoding, credentials, catalog revision/generation, cache activation, canonical album-artist behavior, playlists/favorites/history, artwork loading, and stale-result rejection.

### RemoteDownloadService

Do not move URLSession delegate ownership casually. Preserve background session identifiers, restoration maps, destination resolution, temporary inbox moves, cancellation/requeue, progress coalescing, and targeted library indexing.

### RootView and large views

Extract leaf controls and pure view models first. Preserve environment-object injection, `@State` location, navigation-layer identity, scroll IDs, safe-area insets, toolbar placement, gestures, tab hit testing, mini-player docking, focus/keyboard behavior, and accessibility.

## Compile-pressure track

When compile cost is the motivation:

1. Capture clean build, no-op incremental build, and one-file edit rebuild on the same Mac/Xcode.
2. Save the full build log and `-showBuildTimingSummary` output when supported by the installed Xcode.
3. Identify type-check-heavy expressions from compiler diagnostics or build logs; do not assume the longest file is the culprit.
4. Pilot a file or expression boundary without adding generic indirection.
5. Repeat the exact three builds with caches treated symmetrically.
6. Accept only neutral/better runtime behavior and a meaningful compile-resource improvement outside noise.

Never compare a warm incremental post-split build against a cold baseline or different DerivedData directory.

## Seam experiment template

```markdown
# Seam: <name>

## Hypothesis
Moving <declarations> from <source> to <destination> will reduce <coupling/build cost> because <evidence> while preserving <invariants>.

## State and effects
- Owner/lifetime:
- Actor/thread:
- Inputs/outputs:
- Side effects:
- Runtime strings:
- Target membership:

## Characterization before move
- Existing coverage:
- New test/probe:
- Golden/diagnostic evidence:

## Four-axis gates
- Behavior:
- Symbol/access:
- Performance:
- Build/resource:

## Verdict
SEAM_CONFIRMED | SEAM_REFUTED | DEFERRED

## Evidence paths
- ...
```

## Rejection rules

Reject or defer when the split requires broader access solely to compile, creates a generic helper bucket, adds a protocol with one implementation, changes a value type to reference semantics, moves stored SwiftUI state, changes actor ownership, adds audio-path indirection, duplicates cache state, changes target membership ambiguously, or cannot be validated on the required device.
