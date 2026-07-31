# Resonance Refactor Playbook

## Contents

- Equivalence axes
- Pattern guidance
- Domain traps
- Dead-code evidence
- Commit and review rubric

## Equivalence axes

### Values and ordering

Preserve stable IDs, equality/hash behavior, sort keys, locale/case handling, tie breakers, album/artist canonicalization, track/disc ordering, section IDs, playlist order, queue order, and deterministic cache keys.

### Errors and fallback

Preserve thrown/error-return behavior, user-visible messages, partial success counts, retry/cancel behavior, compatibility playback fallback, stale-result rejection, unsupported metadata formats, HTTP status handling, and failure diagnostics.

### Time and concurrency

Preserve actor isolation, main-actor publication, task priorities, cancellation, generation/request IDs, in-flight coalescing, timer/observer lifetime, callback order, and synchronous crash-boundary diagnostics. A helper that awaits or dispatches differently is not isomorphic by default.

### SwiftUI identity

Preserve ownership/location of `@State`, `@StateObject`, `@EnvironmentObject`, focus, scroll proxies, navigation destinations, stable IDs, view type/branch identity, animations/transitions, gesture priority, hit testing, safe-area insets, toolbar placement, accessibility labels/traits, and theme contrast.

### Persistence and network

Preserve plist/UserDefaults/Keychain keys, SQLite schema/transactions, file paths, atomic writes, metadata tag semantics, cache versioning, URL encoding, OpenSubsonic auth/token construction, endpoints, HTTP methods/ranges, background session identifiers, and restoration behavior.

### Diagnostics and privacy

Preserve event names consumed by regression/manual analysis, synchronous vs deferred durability, detail keys, and sanitization. Never “simplify” by adding sensitive context.

## Pattern guidance

### Extract pure function

Good when all inputs are explicit values, output is deterministic, ordering/error semantics are identical, and no environment/global actor state is captured. Add table-driven tests before extraction.

### Parameterize repeated views

Use an explicit enum/struct for truly variant styling or labels. Keep action closures, accessibility, frame geometry, toolbar placement, animation, and environment reads at the call site when they differ. Verify screenshots/interaction in multiple themes and dynamic type where relevant.

### Share local/remote grouping

Share only the pure normalization kernel whose identity inputs and tie-break rules are equal. Keep data-source-specific cache revision, persistence, and presentation ownership separate. Cross-check mixed-artist/Various Artists behavior.

### Collapse wrapper

Confirm the wrapper does not define actor isolation, diagnostics, error translation, cancellation, weak capture, queueing, default arguments, overload selection, or test seam. One line can carry a contract.

### Remove dead branch

Search source, project, scripts, docs, persisted keys, selectors/strings, and runtime diagnostics. For old persisted enum/config values, keep decoding/migration even if the UI can no longer create them.

### Introduce protocol or generic

Reject by default when there is one implementation or when it erases concrete capabilities, adds dynamic dispatch, complicates actor isolation, or makes the call graph less legible. Require three stable cases and a measured maintenance benefit.

## Domain traps

- `PlayerController` duplicates can encode intentionally different local/remote semantics.
- `AVAudioPlayer`, `AVPlayer`, and `AVAudioEngine` are not interchangeable abstractions merely because they “play.”
- Local and remote track identity/persistence are different even when UI fields overlap.
- Similar toolbar code can live in different placement/gesture/navigation contexts.
- Similar cache-loading code can have different authority, revision, and refresh rules.
- Similar download/file-write code can have different background-system ownership.
- Similar error messages may be tied to diagnostic categories or manual acceptance steps.

## Dead-code evidence

Use layered evidence:

1. textual and symbol search;
2. Xcode project/resource membership;
3. call graph and runtime entry-point audit;
4. persisted/config decode audit;
5. representative diagnostics/coverage;
6. targeted removal experiment on a scratch branch;
7. full validation ladder.

Do not use “compiler says unused” as sole proof for code reachable through Objective-C/runtime strings, delegates, URLSession restoration, SwiftUI, or persisted data.

## Commit and review rubric

A strong commit:

- names one simplification lever;
- links a filled pre-edit card;
- has a small reviewable diff;
- reduces duplicated logic or concepts;
- adds no behavior/UI/performance change;
- includes raw gate output and targeted evidence;
- reports LOC and abstraction delta;
- keeps rejected alternatives visible.

Reject a commit that bundles formatting churn, renames broad surfaces, changes behavior while tests are sparse, widens access for convenience, moves state ownership, or claims safety from compilation alone.
