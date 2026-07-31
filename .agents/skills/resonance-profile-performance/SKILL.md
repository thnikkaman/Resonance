---
name: resonance-profile-performance
description: >-
  Profile the Resonance iOS app and its Python fixture service with reproducible, privacy-safe evidence. Use when startup, Streaming, scrolling, grouping, artwork, playback, seek, queue boundaries, metadata saves, downloads, SQLite work, network activity, memory, battery, or build performance is slow or regresses. Establish a scenario fingerprint and same-device baseline; combine diagnostic timings with Instruments or equivalent samples and user-visible latency; report a ranked hotspot table and hypothesis ledger before changing code. Do not use simulator-only or cross-device numbers to claim physical audio, background-transfer, or real-library performance.
---

# Resonance Profile Performance

> **One Rule:** Rank measured hot paths before optimizing. No reproducible scenario, baseline distribution, and triangulated evidence means no performance change.

## First actions

Resolve `SKILL_DIR` to the directory containing this `SKILL.md`. Run bundled tools as `python3 "$SKILL_DIR/scripts/<tool>.py"`; run repository commands from the repository root.

1. Read [references/RESONANCE-CONTRACT.md](references/RESONANCE-CONTRACT.md).
2. Create `<repo>__resonance_runs/profile/<run-id>/` and write a scenario fingerprint before launching a profiler.
3. Identify one user-visible scenario, one primary metric, one correctness golden, and one budget.
4. Run the repository regression gate so a broken baseline is not misdiagnosed as a performance issue.
5. Use `scripts/benchmark_command.py` for repeatable command/service timings and `scripts/summarize_diagnostics.py` for privacy-safe event analysis.
6. Stop at a ranked evidence handoff unless the user also asks for an implementation; optimization changes belong in a separate commit/run.

## Mandatory loop

```text
1. DEFINE       -> scenario, state, input size, metric, budget, golden result
2. FINGERPRINT  -> SHA, versions, device, OS, Xcode, build mode, power/thermal/network state
3. BASELINE     -> warmups + repeated samples + correctness hashes
4. INSTRUMENT   -> privacy-safe diagnostics/signposts behind a debug gate when needed
5. PROFILE      -> CPU, main thread, Swift concurrency, allocation, I/O, network, and waits
6. TRIANGULATE  -> three independent angles for each actionable hypothesis
7. RANK         -> hotspot table with impact, confidence, risk, and evidence paths
8. HAND OFF     -> smallest verified lever; keep measurement and optimization separate
```

Every run must preserve raw samples and trace metadata. “It feels faster” is not a result.

## Choose a canonical scenario

Start with [references/PROFILING-SCENARIOS.md](references/PROFILING-SCENARIOS.md). Prefer one of these named scenarios rather than an ad hoc tap sequence:

- cached local-library launch;
- first launch with no persisted library;
- first Streaming presentation with a cached large catalog;
- repeated Library ↔ Streaming tab switches;
- Artists/Album Artists/Albums projection changes;
- remote artwork-heavy scrolling;
- local stereo or multichannel playback startup and fallback;
- remote playback start, seek, end, and queue advancement;
- multi-track download progress plus targeted indexing;
- single-track and album metadata save;
- theme/Hero Button change and root redraw;
- Python fixture manifest generation and byte-range serving;
- clean, no-op incremental, and one-file edit Xcode builds.

Pin fixture/library size, selected grouping, sort, artwork state, network path, cache state, and exact start/end markers. Cold and warm are separate scenarios.

## Scenario fingerprint

Record at minimum:

```text
run ID, UTC timestamp, repo SHA and dirty state
marketing/build version read from the project
Mac model/CPU/RAM, iPhone model, OS, Xcode and SDK
scheme, configuration, optimization, signing/install method
simulator vs physical, power source, Low Power Mode, thermal state
network path, server class, catalog/fixture size
cold/warm cache definition and reset method
playback/download state and diagnostics-debugging state
primary metric, budget, sample count, correctness golden
```

Never compare simulator and physical-device latency, Debug and Release, different catalog sizes, or different network paths as an A/B result.

## Baseline discipline

- Use at least 3 warmups and 10 measured runs for exploration; use 20+ measured runs for a decision. Tail percentiles need substantially more samples; label sparse p95/p99 as descriptive rather than statistically strong.
- Report median, p95, minimum, maximum, median absolute deviation or coefficient of variation, and failures. Keep every raw sample.
- Use the same device, build, input, state reset, and background load before and after.
- Hash or assert the scenario outcome so a faster empty/failed path cannot win.
- Separate cold-cache, warm-cache, foreground, background, playback-active, and download-active runs.
- Treat a change inside the established variance envelope as noise. Establish the envelope from the baseline rather than hardcoding one universal percentage.

Example command benchmark:

```bash
python3 "$SKILL_DIR/scripts/benchmark_command.py" \
  --label regression-gate --runs 20 --warmups 3 \
  --out <workspace>/baseline/regression.json -- \
  Tools/RegressionChecks.sh
```

## Pick independent tools

Use at most one signal from each mechanism when triangulating:

| Mechanism | Resonance choices |
|---|---|
| Wall/user-visible timing | signposted interval, diagnostic begin/end pair, XCTest metric, or controlled stopwatch/video frame count |
| CPU/main-thread sampling | Instruments Time Profiler, `xcrun xctrace` with the installed template, or Xcode Debug Navigator |
| Swift concurrency/waits | Swift Concurrency instrument, thread states, task/actor hops, main-thread stalls |
| Allocation/lifetime | Allocations, Leaks, VM Tracker, memory graph |
| File/SQLite | File Activity, System Trace, SQLite timing probes, targeted command benchmark |
| Network | Network instrument, server timestamps, range-request timing, URLSession metrics |
| Energy/thermal | Energy Log, MetricKit/device thermal state, long physical run |
| Build | `xcodebuild` logs/timing summary, clean vs incremental matrix |

Run `xcrun xctrace help record` on the installed Xcode before scripting trace commands; template names and flags are tool-version facts. Save the exact command and trace path.

## Instrumentation rules

Prefer existing `ResonanceDiagnostics` events. Add measurement-only events only when attribution is impossible otherwise.

- Use stable names such as `remote.browse.prewarm.begin/end` or one event with `duration_ms`, count, projection, and result.
- Use `recordDeferred` for non-crash-boundary UI/catalog performance events so main-actor work does not wait on disk.
- Keep synchronous records only where crash-boundary ordering is the product requirement.
- Never log names, paths, URLs, credentials, query tokens, or media bytes.
- Do not add logging, allocations, locks, string formatting, or actor hops to an audio render callback.
- Gate verbose instrumentation with the existing debugging setting and remove or clearly label temporary probes before handoff.

Summarize a copied diagnostics file:

```bash
python3 "$SKILL_DIR/scripts/summarize_diagnostics.py" Resonance-Diagnostics.log \
  --out <workspace>/diagnostics-summary.json
```

A privacy warning from the script is a release blocker for the instrumentation.

## Triangulation gate

Classify a hypothesis:

- **3/3 independent angles support:** actionable kernel; rank it.
- **2/3 support:** disputed; investigate tool bias or add a fourth cheap angle.
- **0-1/3 support:** reject as likely artifact.

Example: “Streaming grouping blocks the main actor” should combine user-visible first-frame timing, a Time Profiler/main-thread trace, and diagnostic projection durations or task/actor evidence. Three screenshots of the same trace count as one angle.

## Hotspot table

Use `assets/hotspot-report.md`. Rank by user impact and confidence, not sample count alone.

Required columns: scenario, hotspot, category, inclusive/exclusive cost, frequency, p50/p95 contribution, scaling behavior, three evidence paths, confidence, correctness risk, proposed smallest lever, and acceptance budget.

Do not recommend an optimization that merely moves work outside the measured interval, disables required behavior, reduces catalog size, skips artwork/metadata, changes audio quality, or makes diagnostics less truthful.

## Resonance-specific interpretation rules

- High CPU in a function does not prove it dominates wall time; inspect waits, file I/O, network, and actor scheduling.
- Fast simulator results do not prove physical audio, background URLSession, lock-screen, or thermal behavior.
- A faster first Streaming frame that renders empty/incorrect grouping fails the golden.
- A faster launch that scans less only counts when the persisted library and explicit-refresh semantics remain correct.
- Main-thread decode/group/sort work is suspicious, but verify revision safety before moving it.
- Playback work has stricter jitter and allocation constraints than browse work; use separate budgets.
- Build-time improvement must use symmetric DerivedData/cache conditions and the same Xcode.

## Required outputs

```text
run.json
scenario.json
baseline/raw-samples.json
baseline/summary.md
traces/index.md
diagnostics-summary.json
hypothesis-ledger.md
hotspot-report.md
honest-gate.json
FINAL_PROFILING_REPORT.md
```

The final report must state what was measured, exact environment, correctness golden, distributions, variance, ranked hotspots, rejected/disputed hypotheses, instrumentation changes, privacy audit, and validation/device limits.

## Resources

- Project invariants: [references/RESONANCE-CONTRACT.md](references/RESONANCE-CONTRACT.md)
- Scenario definitions and budgets: [references/PROFILING-SCENARIOS.md](references/PROFILING-SCENARIOS.md)
- Repeated command benchmark: `scripts/benchmark_command.py`
- Diagnostics parser/privacy check: `scripts/summarize_diagnostics.py`
- Report template: `assets/hotspot-report.md`
- Trigger checks: [SELF-TEST.md](SELF-TEST.md)
