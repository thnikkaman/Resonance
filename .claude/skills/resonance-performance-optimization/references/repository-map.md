# Resonance Repository Map

## Contents

1. Branch and build surface
2. App lifecycle
3. Model, persistence, and metadata
4. Remote catalog and downloads
5. Playback and audio
6. Views, navigation, and artwork
7. Settings, diagnostics, and fixture server
8. Source membership checklist

Verify every path against the exact target ref before editing.

## 1. Branch and build surface

| Path | Role | Key contract |
|---|---|---|
| `README.md` | Continuation source, build history, observed problems, manual acceptance, next work | Version/build provenance and truthful completed/pending validation |
| `Resonance.xcodeproj/project.pbxproj` | Target source membership and build settings | Both target configurations remain synchronized; new Swift files enter Sources |
| `Resonance/Info.plist` | Bundle metadata and permissions | Version/build inherit project settings; bundle identity remains stable |
| `.xcodebuildmcp/config.yaml` | Agent build defaults | Project, scheme, and stable simulator name |
| `Tools/RegressionChecks.sh` | Fast source and deterministic contract gate | Do not weaken; update durable contracts and version label deliberately |
| `Tools/PreflightBuild.sh` | Strict simulator/generic-device compile | Swift 6 complete concurrency and warnings as errors |
| `Tools/ResonanceServer.py` | Local manifest/range playback fixture | Deterministic metadata, ranges, and privacy-safe fixtures |

The branch may not share history with `main`. Resolve the explicit ref and a valid baseline before diffing.

## 2. App lifecycle

### `Resonance/ResonanceApp.swift`

Owns long-lived stores and active-scene work:

- `LibraryStore`
- `PlayerController` and `PlaybackProgress`
- `AppSettings`
- `RemoteLibraryStore`
- `RemoteDownloadManager`
- `AppErrorLog`

Current active-scene order:

1. run local and remote activation concurrently
2. await both
3. prewarm the remote browse cache off-main
4. resume persisted downloads

Watch for duplicate scene tasks, synchronous initialization I/O, broad environment-object invalidation, stale prewarm publication, and download resume before catalog/local state is ready.

## 3. Model, persistence, and metadata

### `Resonance/Models/Track.swift`

Preserve stable IDs, local/remote URL semantics, duration, source byte size, date added, artwork data/embedded flags, album identity, and deterministic order.

### `Resonance/Services/LibraryDatabase.swift`

Potential risk:

- missing transactions around batches
- statement lifecycle/thread ownership
- full-table work after one-file changes
- artwork blobs on startup
- close/deinit actor hazards

Prefer targeted queries/upserts, transactions, prepared statements, and lightweight rows before artwork hydration.

### `Resonance/Services/LibraryBrowseGrouping.swift`

Owns shared album/mixed-artist identity. Preserve local/remote parity and one synthetic Various Artists album for mixed-track-artist albums.

### `Resonance/Services/MetadataReader.swift`

Owns local format parsing, direct tag writing support, artwork extraction, and file I/O. Keep heavy work off-main and preserve supported/unsupported format behavior.

### `Resonance/Services/MetadataWriteBatch.swift`

Preserve sequential/per-file result accounting, cancellation/error behavior, direct file writes, and targeted reread after success.

### `Resonance/Services/LibraryStore.swift`

Current boundaries:

- `isBootstrapping` distinguishes initial cache hydration
- display snapshot loads off-main after the app shell can render
- cached rows publish before expensive artwork hydration
- warm startup treats persisted data as authority
- explicit refresh discovers external file changes
- file inventory runs at utility priority and is throttled
- browse projections are cached and invalidated by semantic inputs
- snapshot writes are deferred/coalesced and artwork uses sidecars
- metadata/download completion refreshes affected files rather than the full tree
- ignored paths preserve Remove from Library across scans

Watch for repeated `tracks` publication, incomplete cache keys, synchronous cache decode, full Documents traversal on activation, full rescans after one-file changes, and persistence rewrites per item.

## 4. Remote catalog and downloads

### `Resonance/Services/RemoteURLSupport.swift`

Owns normalized remote URL/host interpretation. Preserve HTTPS/host/port behavior and keep credentials out of URLs, QR payloads, and logs.

### `Resonance/Services/RemoteLibraryStore.swift`

Current boundaries:

- cached startup state loads off-main
- cached display/catalog data can activate before server checks
- `tracks` changes advance a separate browse revision
- browse cache key includes revision, sort direction, and compilation grouping
- only requested projections are built synchronously
- `prewarmBrowseCache` builds all first-transition projections off-main after activation
- prewarm results publish only when revision and sort direction still match
- stale catalog and playback preparation use cancellation/generation gates
- automatic checks do not destroy usable cached browse state
- status publication remains slower than internal network/playback state

Preserve OpenSubsonic endpoints, stable source IDs, canonical album artists, favorites, recent lists, playlists, star/unstar, scrobbling, and raw streaming format behavior.

### `Resonance/Services/RemoteDownloadService.swift`

Preserve:

- ordered queued/active/cancelled/failed states
- bounded/coalesced byte progress
- disk-backed partial file cleanup
- explicit Replace Existing/Keep Existing
- requeue and cancel-all
- persisted queue and background-session restoration
- atomic completion move
- targeted local-library indexing
- artwork memory/persistence behavior

Background continuation, lock-screen delivery, and force-quit behavior require a physical device.

## 5. Playback and audio

### `Resonance/Services/PlayerController.swift`

Current boundaries:

- `PlaybackProgress` owns high-frequency elapsed publication
- meter values do not publish through broad controller observation
- queue/sourceQueue/current index remain synchronized
- play next/add to queue deduplicate while preserving requested order
- remote seek request IDs prevent stale completion wins
- pending target/clock hold preserve requested position during transient AVPlayer clocks
- elapsed/duration clamp at exact end
- status text publication is throttled/deduplicated
- Now Playing artwork prepares off-main and caches by track identity
- stable remote single-item path and experimental/preload paths retain explicit fallback
- local Matrix Mixer failure quarantines the graph and uses compatibility playback

Any change requires state-machine and queue/seek oracle coverage.

### `Resonance/Services/GaplessAudioEngine.swift`

Preserve:

- explicit Matrix Mixer routing and gains
- rear-left/right isolation, center/LFE distribution
- native source sample rate through the intended conversion stage
- format compatibility before preload
- partial preload/remainder scheduling
- timeline/generation ordering
- safe stop/disconnect and failed-graph abandonment
- compatibility fallback after matrix failure

Simulator proves control flow only. Physical listening is required for gap, speed, route, and 5.1 claims.

## 6. Views, navigation, and artwork

### `Resonance/Views/RootView.swift`

Owns:

- layered navigation and full-screen detail presentation
- active/inactive tab composition
- custom tab bar
- mini-player overlay, docks, and edge handle
- tab swipe and hierarchy gestures
- safe-area insets, hit testing, visibility, and accessibility
- theme surface/text boundaries
- error-reporting and playback coordinator views

Keep broad player/settings observation narrow. Test every gesture against ordinary vertical scrolling.

### `Resonance/Views/LibraryView.swift`

Owns local grouping, alphabet sections/index, artist/album presentation, removal/deletion actions, and local browse identity.

### `Resonance/Views/AlbumDetailView.swift`

Owns album hero/detail actions, metadata/artwork entry points, removal/deletion confirmation, and detail navigation spacing.

### `Resonance/Views/PlayerViews.swift`

Owns Now Playing, mini-player, scrubber, duration/remaining formatting, volume, queue, sleep, and playback controls. Only progress-aware surfaces should observe `PlaybackProgress`.

### `Resonance/Views/ArtworkView.swift`

Local artwork must use ImageIO thumbnailing off-main, keyed by source and pixel size, with bounded cache count/cost. Avoid full-resolution `UIImage(data:)` in scrolling/body paths.

### `Resonance/Views/SmartLibraryViews.swift`

Owns smart collections and metadata editors. Preserve persistent labels, focus, direct-write semantics, and asynchronous save behavior.

### `Resonance/Views/StreamingLibraryView.swift`

Owns remote browse surfaces, section tasks/indexes, detail presentations, playlists, selection mode, artwork, downloads, and remote actions. Watch for synchronous grouping, task fan-out, download-progress observation leaking into catalog rows, and gestures stealing scroll.

### `Resonance/Services/ArtworkSearchService.swift`
### `Resonance/Views/OnlineArtworkSearchView.swift`

Preserve independent provider failure, query fallbacks, credible matching, recommendation, source precedence, bounded candidates, cancellation, and selected/automatic warning state.

## 7. Settings, diagnostics, and fixture server

### `Resonance/Services/AppSettings.swift`

Owns credentials through Keychain, remote backend/settings, visual themes, colors, grouping, diagnostics toggles, background download option, and persisted category state. Do not log secrets or make root navigation observe all settings at keystroke cadence.

### `Resonance/Views/SettingsView.swift`

Owns dynamic bundle version/build display, credential fields, QR scanner, color editing, theme previews, diagnostics/error controls, and category disclosures. Preserve draft/debounce/focus behavior and contrast across themes.

### `Resonance/Services/ResonanceDiagnostics.swift`

- `record`: synchronous serial append for crash-critical boundaries only
- `recordDeferred`: debugging-only async append for optional UI/catalog timing

Keep logs bounded and privacy-safe.

### `Resonance/Services/AppErrorLog.swift`

Preserve user-visible errors, copy/delete controls, red presentation, and privacy-safe messages without interfering with playback/startup.

### `Tools/ResonanceServer.py`

Use for controlled manifest/range/seek/boundary tests with non-private fixtures. Compile it in every fast gate.

## 8. Source membership checklist

The current project Sources phase includes these Swift basenames:

- `ResonanceApp.swift`
- `Track.swift`
- `AppErrorLog.swift`
- `ResonanceDiagnostics.swift`
- `AppSettings.swift`
- `LibraryDatabase.swift`
- `MetadataReader.swift`
- `MetadataWriteBatch.swift`
- `LibraryBrowseGrouping.swift`
- `LibraryStore.swift`
- `PlayerController.swift`
- `GaplessAudioEngine.swift`
- `RemoteLibraryStore.swift`
- `RemoteURLSupport.swift`
- `RemoteDownloadService.swift`
- `ArtworkSearchService.swift`
- `RootView.swift`
- `LibraryView.swift`
- `AlbumDetailView.swift`
- `PlayerViews.swift`
- `ArtworkView.swift`
- `SettingsView.swift`
- `SmartLibraryViews.swift`
- `StreamingLibraryView.swift`
- `OnlineArtworkSearchView.swift`

Run the workbench audit after adding, moving, or deleting a Swift file.
