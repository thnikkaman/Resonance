# Resonance Profiling Scenarios

## Contents

- Scenario contract
- App scenarios
- Service scenarios
- Build scenarios
- Acceptance budgets
- Honest comparison checklist

## Scenario contract

Every scenario definition must contain:

```yaml
name: stable-slug
surface: app | service | build
build: Debug | Release
platform: simulator | physical | mac-host
preconditions: []
fixture_or_catalog: description and size
cold_or_warm: exact reset rule
start_marker: observable event
action: exact steps
end_marker: observable event
golden: correctness assertions
primary_metric: milliseconds | bytes | MB | energy | build-seconds
budget: absolute or baseline-relative
samples: warmups and measured runs
required_tools: []
physical_only: true | false
```

Do not start timing at “when it seems to begin” or stop at “when it looks ready.” Add stable privacy-safe markers when needed.

## App scenarios

### Cached local-library launch

Preload a known persisted snapshot and SQLite index. Start at process/app lifecycle activation and end when cached tracks are visibly available and interactive. Golden: no full Documents scan, correct track count/grouping, artwork may hydrate later without replacing identity. Capture main-thread, file activity, and diagnostics.

### Empty first launch

Use an isolated simulator/app container with no persisted library, only after permission to reset that test environment. End after initial discovery completes. Golden: fixture files appear exactly once; no production user data is involved.

### First cached Streaming presentation

Use a fixed cached catalog, preferably a large representative fixture. Start at the navigation request and end at the first correct interactive projection. Golden: correct selected grouping/order/section IDs and no duplicate activation or projection build. Capture actor/task, main thread, allocation, and `remote.browse.*` diagnostics.

### Repeated tab switch

After the first Streaming load, switch Library ↔ Streaming for a fixed count. Golden: retained view/state, no repeated catalog activation or projection rebuild unless revision changed, playback/download state unaffected.

### Projection change

Switch among Artists, Album Artists, and Albums with fixed sort/grouping. Golden: stable canonical grouping, Various Artists behavior, alphabet sections, and stale-result rejection. Measure each projection separately.

### Artwork scroll

Use a fixed catalog with known artwork coverage and cache state. Scroll a scripted distance. Golden: correct images/cell reuse, no playback impact, bounded cache. Capture main thread, decoding threads, allocations, network, and frame responsiveness.

### Local playback startup/fallback

Use known stereo and multichannel fixtures. Measure selection-to-audible-start and boundary jitter on a physical device. Golden: correct route, explicit matrix when supported, quarantine plus compatibility fallback on failure, app remains alive, remote playback remains independent. Never use simulator audio as final evidence.

### Remote playback start/seek/end

Use an isolated real server and fixed track set. Measure request-to-play, seek target-to-stable-clock, and boundary-to-next-item. Golden: range/stream behavior, stale seek rejection, elapsed clamp, queue order, Now Playing, remote commands, no credential leakage.

### Download plus targeted indexing

Download a fixed set from a test server. Golden: destination conflict behavior, progress/cancel/requeue, completed files indexed incrementally, no unrelated full-library scan, background restore tested physically when claimed.

### Metadata save

Use disposable FLAC/MP3 fixtures. Measure single-track and album-batch save. Golden: tags/artwork readable by an external parser, editor responsiveness, targeted reread/upsert, unrelated library unchanged. Never mutate the user’s real music.

### Theme/root redraw

Change theme and Hero Button style while recording main-thread and SwiftUI work. Golden: all shared controls update, readability/accessibility preserved, playback and scrolling unaffected.

## Service scenarios

### Manifest generation

Run `Tools/ResonanceServer.py` on a generated fixture tree. Measure cold manifest construction and warm 10-second cache hit separately. Golden: stable IDs, metadata fields, URL encoding, supported-file filtering, and no path escape.

### Media byte ranges

Measure full GET, HEAD, prefix range, suffix range, invalid range, and concurrent clients. Golden: exact bytes, lengths, status codes, `Accept-Ranges`, and `Content-Range`.

## Build scenarios

Capture three matrices on the same Mac/Xcode and symmetric DerivedData state:

1. clean build;
2. no-op incremental build;
3. edit one representative Swift file and rebuild.

Record wall time, build-timing summary when available, peak memory if measured, warnings, and output success. Do not compare a clean baseline to a warm incremental candidate.

## Acceptance budgets

Use product/user requirements when supplied. Otherwise establish a baseline envelope and propose a provisional budget; label it provisional. Keep separate budgets for startup, interaction, audio boundary/seek, background work, service requests, memory, and build time. Never use a browsing budget for an audio path.

## Honest comparison checklist

- same source golden and feature set;
- same device/OS/Xcode/build/signing;
- same fixture/catalog and cache state;
- same network/server and playback/download background state;
- symmetric warmups and resets;
- enough samples with raw data retained;
- output/error counts identical;
- losses and regressions reported, not hidden;
- no physical-only claim from simulator;
- no sensitive data in trace names or logs.
