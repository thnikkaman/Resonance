# Resonance Optimization Methodology

## Contents

1. Evidence bundle
2. Baseline discipline
3. Profiling discipline
4. Equivalence oracle
5. Risk-adjusted opportunity matrix
6. One-lever implementation
7. Statistical acceptance
8. Iteration protocol

## 1. Evidence bundle

Create one directory per optimization round:

```text
round-01/
├── manifest.json
├── opportunities.json
├── proof.md
├── before/
│   ├── workload.json
│   ├── diagnostics.log
│   ├── measurements.json
│   └── traces/
└── after/
    ├── workload.json
    ├── diagnostics.log
    ├── measurements.json
    └── traces/
```

Keep private media, URLs, credentials, and file paths outside the bundle. Use stable IDs, counts, categories, and sanitized state names.

## 2. Baseline discipline

Record:

- repository, ref, commit, and dirty state
- simulator/device and OS
- Debug/Release configuration
- cold/warm launch and cache state
- local and remote track counts
- network condition
- diagnostics mode state
- exact action sequence
- expected behavior
- repetitions and warmups

Use at least five repetitions. Prefer ten or more for noisy UI, network, and playback-preparation timings. Do not discard outliers without a documented reason.

Capture p50, p95, p99, sample count, and a secondary metric such as memory, publication count, frame stalls, request count, or energy. A lower median with a worse p95 can still be a regression.

## 3. Profiling discipline

Start with the real path. Select the profiler by the question:

| Question | Primary evidence |
|---|---|
| What consumes CPU? | Time Profiler |
| Why are views rebuilding? | SwiftUI instrument plus dependency inspection |
| Why does interaction hang? | Hangs and System Trace |
| Why does memory grow? | Allocations, Leaks, VM Tracker |
| Why are remote operations slow? | Network plus signposts/diagnostics |
| Why is battery use high? | Energy Log on device |
| Why is build slow? | Xcode build timing summary |

Rank exact stacks, symbols, actor hops, publications, requests, or allocations. Do not rank generic files.

## 4. Equivalence oracle

Define the oracle before implementation.

### I/O equivalence

State the input and the observable output. Examples:

- same cached database and settings -> same ordered track IDs and selected tab
- same queue and seek target -> same current track, queue index, clamped elapsed, and next-track transition
- same remote catalog revision and grouping -> same ordered section IDs and item IDs

### Ordering and tie-breaking

Document primary and secondary sort keys. Swift sorting changes can alter equal-item order; preserve a stable secondary key where behavior relies on it.

### Identity

Preserve stable UUIDs, album keys, artist keys, section IDs, queue positions, and SwiftUI IDs. Rebuilding equivalent values with new identity is not equivalent for navigation or animation.

### State-machine equivalence

For playback, download, refresh, and navigation changes, list legal state transitions and stale-result rejection rules. Performance improvements must not skip required transitions.

### Persistence equivalence

Capture normalized snapshots or checksums for non-private persisted outputs. Confirm targeted writes do not erase unrelated records.

## 5. Risk-adjusted opportunity matrix

Use 1-5 values:

- impact: expected user-visible improvement
- confidence: quality of evidence
- effort: implementation and validation cost
- risk: chance and severity of behavior regression

```text
score = (impact * confidence) / (effort * risk)
```

Interpretation:

| Value | Impact | Confidence | Effort | Risk |
|---:|---|---|---|---|
| 1 | <5% or barely visible | speculative | minutes | isolated, trivial rollback |
| 2 | 5-10% | static evidence plus plausible path | under two hours | small UI/state surface |
| 3 | 10-25% | repeated diagnostics or counts | several hours | cache/concurrency surface |
| 4 | 25-50% | profiler confirms dominant contributor | about a day | persistence/network/playback |
| 5 | >50% or major stall removal | multiple independent measurements | multi-day | audio/data integrity or broad architecture |

Implement only score >= 2.0 and confidence >= 3. High-risk changes require a stronger oracle and validation plan even when the score passes.

## 6. One-lever implementation

One lever means one causal mechanism, for example:

- narrow one observation boundary
- cache one projection with a complete key
- batch one database write path
- downsample one artwork path
- cancel one stale async pipeline

Do not combine refactoring, naming cleanup, UI redesign, feature changes, and optimization. Minimal patches make performance causality and rollback credible.

## 7. Statistical acceptance

Accept only when:

- before and after manifests are equivalent
- sample counts are adequate
- target metric improves beyond ordinary noise
- confidence interval supports the direction or the effect is large and trace evidence is direct
- no important secondary metric regresses beyond the agreed threshold
- event counts and behavior oracle remain compatible
- validation gates pass

The bundled diagnostics tool reports median/p95/p99 changes, bootstrap median-delta confidence intervals, and Cliff's delta. Treat the statistics as evidence, not a substitute for workload correctness.

Reject when:

- the gain appears only in a microbenchmark that bypasses SwiftUI, AVFoundation, SQLite, files, or network
- work is deferred to a later visible interaction without agreement
- memory or request fan-out becomes unbounded
- concurrency introduces stale or nondeterministic publication
- tests or source contracts are weakened to accommodate the patch

## 8. Iteration protocol

After each accepted patch:

1. save the after evidence as the next baseline
2. re-profile the same stress case
3. rebuild the opportunity matrix from the new profile
4. stop when no candidate passes the threshold or remaining candidates require product tradeoffs

Maintain a history:

| Round | Lever | Metric | Before | After | Change | Validation |
|---|---|---|---:|---:|---:|---|
| 1 | narrow progress observation | p95 frame stall |  |  |  |  |
