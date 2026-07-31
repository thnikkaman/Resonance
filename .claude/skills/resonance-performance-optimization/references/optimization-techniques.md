# Resonance Optimization Techniques

Use only after profiling confirms the affected path. Every technique requires the listed proof.

## SwiftUI and state

| Technique | Apply when | Required proof |
|---|---|---|
| Narrow observation | Broad object changes rebuild unrelated surfaces | Intended views still receive every required update |
| Dedicated projection object | One high-frequency scalar or compact state drives a few views | Projection remains synchronized with owner and lifecycle |
| Revision-keyed snapshot | Group/sort/filter repeats for unchanged semantic inputs | Key includes every input; output order and IDs are identical |
| Active-surface derivation | Multiple browse projections build but one is visible | Switching surfaces produces the same result and no stale publication |
| Owner-side deduplication | Identical values are repeatedly published | Equality criterion matches user-visible semantics |
| Lazy inactive construction | Hidden tabs/layers allocate or launch work | State restoration, navigation identity, animation, and accessibility remain intact |

## Async and concurrency

| Technique | Apply when | Required proof |
|---|---|---|
| Generation gate | Older async work can publish after a newer request | Latest request always wins; old task cannot mutate visible state |
| Cancellation | Work is obsolete after identity/input changes | Cleanup runs and cancellation does not remove valid shared state |
| Off-main transformation | Sendable CPU/file/decode work blocks main actor | Inputs are immutable/Sendable; publication occurs deterministically on main actor |
| Bounded task group | Independent requests dominate latency | Concurrency limit is justified; output ordering and failure semantics are preserved |
| Debounce/throttle | Human-readable state publishes faster than useful | Final state and important transitions are never lost |

Do not add tasks merely because work is slow. Actor hops, contention, memory, and out-of-order completion can make performance worse.

## Local library and SQLite

| Technique | Apply when | Required proof |
|---|---|---|
| Transactional batch | Many related writes pay per-write commit cost | Same records and error accounting; unrelated rows preserved |
| Prepared statement reuse | Repeated statement preparation is visible | Bind/reset lifecycle is correct and thread ownership is deterministic |
| Targeted query/refresh | Full table/tree work follows a one-file change | Affected and dependent records are complete; unrelated IDs unchanged |
| Lightweight startup rows | Artwork blobs delay first content | Artwork hydrates later without identity/order churn |
| Coalesced snapshot write | Bursts rewrite the same display snapshot | Latest complete state reaches disk; crash/atomicity expectations remain acceptable |
| Modification inventory cache | Unchanged files are reparsed | Cache invalidates for every meaningful file change and ignored-path rule |

## Remote catalog and network

| Technique | Apply when | Required proof |
|---|---|---|
| Cache-first activation | Availability checks block cached browse | Explicit refresh still works; offline cache is not cleared |
| Conditional projection cache | Grouping repeatedly scans a large catalog | Key includes revision/sort/grouping; only requested projection is built |
| Batch or parallel requests | Independent serial calls dominate | Bound concurrency, deterministic merge/order, equivalent errors/cancellation |
| ETag/fingerprint skip | Same catalog is repeatedly decoded/grouped | Server identity and change detector cannot cross-contaminate caches |
| Status deduplication | Same text is published repeatedly | User sees all meaningful transitions and failures |

## Artwork

| Technique | Apply when | Required proof |
|---|---|---|
| ImageIO downsampling | Full images decode for thumbnails | Pixel target and scale are correct; orientation/quality acceptable |
| Source+size cache key | Same bytes are decoded repeatedly | Different sources and pixel sizes cannot collide |
| Cost-aware `NSCache` | Memory grows with scrolling | Count/cost limits exist; eviction preserves correctness |
| Candidate/request bounds | Online fallback fans out | Source precedence, credible-match threshold, and cancellation remain intact |
| Decode outside main actor | Decode stacks block scrolling | No UIKit/SwiftUI state mutation occurs off-main |

## Playback and audio

Treat all playback changes as high risk.

| Technique | Apply when | Required proof |
|---|---|---|
| Narrow progress publication | Timer cadence invalidates broad UI | Progress-aware views update; queue/status views do not miss state |
| Cache prepared artwork | Lock Screen updates repeatedly decode | Cache invalidates by track/artwork identity and size |
| Reject stale seek completion | Rapid seeks show old position | Request ID/generation ordering and pending target authority remain correct |
| Preload compatible item | Boundary preparation dominates | Format, sample rate, channel layout, timeline, and fallback are identical |
| Reduce status publication | Buffer/timer strings publish too often | Error and meaningful transition visibility remains intact |

Never claim audible improvement from simulator timing. Never change Matrix Mixer routing, graph lifecycle, or fallback based on a generic optimization pattern.

## Data-structure and algorithm checks

Apply general algorithmic changes only when the actual access pattern warrants them:

- use dictionaries/sets for repeated keyed membership while preserving output order separately
- use stable precomputed keys for repeated normalization/grouping
- use partial selection instead of full sort only when final ordering requirements allow it
- use prefix/range indexes only when updates and memory costs are bounded
- avoid duplicate arrays and full copies in high-frequency queue/progress paths

For every change, state complexity before/after and prove ordering, tie-breaking, identity, and memory bounds.
