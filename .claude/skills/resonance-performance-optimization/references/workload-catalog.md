# Resonance Workload Catalog

## Contents

1. Startup
2. SwiftUI and navigation
3. Local browse and metadata
4. Remote catalog and artwork
5. Downloads
6. Playback
7. Capture rules

Use a named scenario and preserve its exact action sequence across before/after runs. Add one smaller reproducer and one stress case when practical.

## Startup

### `cold-first-library`

- no local database/display cache
- known fixture file count
- launch to first usable Library content
- allow initial discovery scan

Metrics: time to first content, total scan duration, metadata parse count, main-thread blocked time, peak memory.

Oracle: discovered track IDs/count, grouping counts, shared-folder state, persistence after relaunch.

### `warm-library-startup`

- persisted database and display snapshot
- warm cache state documented
- launch to first usable Library content

Metrics: first content, lightweight row load, artwork hydration duration, number of `tracks` publications.

Oracle: no automatic full scan, same ordered track IDs, artwork eventually hydrates, explicit refresh remains available.

### `shell-before-local-cache-hydration`

- persisted display snapshot with representative artwork sidecars
- start from a terminated process
- capture app shell presentation, `isBootstrapping`, cached row publication, and artwork hydration separately

Metrics: process start to first shell frame, cache-read/decode duration, time to first usable Library rows, main-actor blocked intervals, number of `tracks` publications.

Oracle: the shell can render before the display snapshot finishes decoding; cache file I/O and decoding run off-main; cached IDs/order remain stable; no automatic full Documents scan is introduced.

### `warm-remote-offline`

- persisted remote cache
- server unavailable
- launch and browse Streaming

Metrics: first cached content, main-thread work, status publication count.

Oracle: cached tracks/sections remain usable, no destructive cache replacement, explicit refresh reports failure without clearing browse data.

### `cached-remote-prewarm-first-transition`

- persisted large remote display snapshot and catalog
- activate the app shell without opening Streaming immediately
- allow `prewarmBrowseCache(groupCompilationArtists:)` to complete
- open Artists, Album Artists, and Albums in a fixed order

Metrics: remote activation duration, detached prewarm duration, first Streaming frame, synchronous main-actor grouping time, projection count, memory high-water mark.

Oracle: all three cached browse projections preserve deterministic order and IDs; prewarm runs off-main; publication occurs only when catalog revision and sort direction still match; first Streaming transition does not synchronously regroup the full catalog.

### `remote-prewarm-stale-result-race`

- begin prewarm on a large cached catalog
- change sort direction or replace the catalog before detached work finishes
- open the affected Streaming surface

Metrics: task duration, discarded-result count, visible publication count, main-thread work.

Oracle: the obsolete prewarm result is rejected; visible data matches the newest revision and sort state; a later on-demand or replacement prewarm produces the correct projection.

### `active-state-ordering-with-persisted-downloads`

- persisted local and remote caches plus a restorable download queue
- transition terminated -> active and background -> active
- observe concurrent local/remote activation, browse prewarm, then download restoration

Metrics: activation task count, ordering timestamps, duplicate resume attempts, status publications.

Oracle: local and remote activation can overlap; browse prewarm follows remote activation; persisted downloads resume only after activation/prewarm sequencing; rapid scene changes do not duplicate scans, catalog checks, or queue restoration.

## SwiftUI and navigation

### `tab-swipe-during-playback`

1. start playback
2. Library -> Streaming -> Settings -> Playing -> Library
3. use tap and swipe navigation
4. repeat ten cycles

Metrics: body updates by surface, frame stalls, root invalidations, allocation growth.

Oracle: selected tab/layer, mini-player placement, safe areas, gesture ownership, accessibility visibility, playback continuity.

### `settings-edit-during-playback`

- type in a settings text field
- move color controls
- expand/collapse large categories

Metrics: root/view updates, main-thread time, status publications.

Oracle: values persist, focus behavior remains correct, playback timer and queue remain stable.

## Local browse and metadata

### `large-library-scroll`

- fixed large fixture count
- scroll artist and album grids from top to bottom and back
- jump via alphabet index

Metrics: frame stalls, thumbnail decode time/count, cache hit ratio, memory high-water mark.

Oracle: stable item/section order, same target section on index jump, artwork warning state, no missing rows.

### `local-search-sort-group`

- fixed search strings
- all sort directions and groupings

Metrics: projection build duration, publication count, repeated body work.

Oracle: ordered IDs and section IDs for every input combination.

### `targeted-metadata-save`

- edit one MP3/FLAC item or one album batch
- return to open list/detail and relaunch

Metrics: write duration, affected-file reread count, database writes, UI unblock time.

Oracle: changed fields persist, unrelated IDs remain, no full scan, artwork semantics preserved.

## Remote catalog and artwork

### `large-remote-grouping`

- fixed cached catalog revision and count
- switch artists, album artists, albums, songs, favorites, recent surfaces

Metrics: requested projection build duration, number of unrequested projections, main-actor time.

Oracle: same ordered section/item IDs and compilation grouping.

### `slow-remote-refresh`

- controlled latency/error fixture
- trigger refresh twice rapidly

Metrics: request count, decode/group time, status publication count.

Oracle: newest generation wins, stale result is discarded, cached catalog remains available.

### `remote-artwork-scroll`

- fixed thumbnail size and candidate source
- rapidly scroll and revisit rows

Metrics: decode time, requests, cache hits/misses, memory.

Oracle: source precedence and warning state remain unchanged; stale row tasks do not publish into reused identity.

## Downloads

### `download-queue-stress`

- queue known set
- cancel one queued and one active item
- include replace/keep decision
- background/foreground mode documented

Metrics: queue publication count, progress update rate, temporary bytes, targeted refresh time.

Oracle: order/status transitions, cleanup, replacement semantics, completed items appear incrementally, no full-library scan.

## Playback

Keep local legacy, local gapless, stable remote, and experimental remote sample-contiguous scenarios separate.

### `local-stereo-boundary`
### `local-5_1-fallback`
### `remote-start-seek-end`
### `remote-rapid-seek`
### `queue-repeat-shuffle`

Capture request IDs, generations, backend, target/actual elapsed, duration clamps, preload readiness, boundary begin/end, and fallback events.

Oracle:

- current track and queue index
- queue order and repeat/shuffle semantics
- no stale seek completion wins
- exact-end labels remain valid
- matrix failure reaches compatibility fallback
- next-track transition occurs once

Simulator evidence is control-flow only. Use a physical device for audible gap, speed, 5.1 routing, route changes, thermal behavior, and long-idle acceptance.

## Capture rules

For every named workload, record the exact ref/commit, build configuration, simulator/device, OS, fixture counts, cache state, network condition, diagnostics mode, warmups, repetitions, and action sequence. Keep those fields identical across before/after runs or declare the comparison invalid.
