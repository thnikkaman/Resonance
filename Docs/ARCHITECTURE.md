# Resonance architecture and ownership

This document describes the boundaries that make changes safe. It is intentionally
shorter than the historical release log in `README.md`; it records ownership and
invariants, not every past experiment.

Scoped contracts live beside the code they govern: `Resonance/Views/AGENTS.md`,
`Resonance/Services/AGENTS.md`, and `Resonance/Models/AGENTS.md`. Read the root
contract plus the closest scoped contract for a single-module change; read every
affected scoped contract for a cross-module change. These files explain local rules,
while this document remains the canonical cross-module ownership map.

## Runtime layers

| Layer | Primary owner | Responsibility | Must not own |
| --- | --- | --- | --- |
| App composition | `ResonanceApp.swift`, `RootView.swift` | Shared stores, tab stacks, safe areas, navigation and gesture arbitration | Catalog queries, tag writes, playback backend logic |
| Local catalog | `LibraryStore.swift`, `LibraryDatabase.swift`, `MetadataReader.swift` | File inventory, metadata, grouping, overrides, targeted refresh, SQLite persistence | Remote requests, AVAudioEngine graph setup |
| Remote catalog | `RemoteLibraryStore.swift` | Backend requests, cached activation, refresh generations, remote browse projections | Local file writes, audio graph lifecycle |
| Downloads | `RemoteDownloadService.swift` and download manager types | Queue state, progress, cancellation, replacement, background restoration, indexing handoff | UI layout, duplicate catalog ownership |
| Playback | `PlayerController.swift` | Queue, current item, seek authority, backend selection, Now Playing state | View layout, catalog grouping, tag persistence |
| Audio | `GaplessAudioEngine.swift` | AVAudioEngine graph, preload, explicit 5.1 matrix, fallback quarantine | Remote catalog policy, UI state |
| Presentation | `LibraryView.swift`, `StreamingLibraryView.swift`, `SmartLibraryViews.swift`, `PlayerViews.swift`, `SettingsView.swift` | User interaction, rendering, accessibility, presentation-local state | Durable business state or network/file/database work in `body` |
| Artwork | `ArtworkSearchService.swift`, `ArtworkView.swift`, artwork caches | Provider search, relevance, bounded decode/cache, provenance | Playback state or catalog authority |
| Diagnostics | `ResonanceDiagnostics.swift`, `AppErrorLog.swift` | Persistent privacy-safe errors and deferred event traces | Credentials, private content, synchronous hot-path logging |

## State ownership rules

- A persisted value has one authoritative owner. Other layers receive a projection or callback.
- A view may hold transient presentation state, such as a selected sheet or gesture phase, but not a second durable copy of catalog or playback truth.
- High-frequency elapsed, meter, byte-progress, and buffer values must not invalidate the root tab tree or unrelated browse surfaces.
- Cached local and remote snapshots remain usable when their server or file refresh is deferred or unavailable.
- A targeted edit or completed download refreshes only affected records; ordinary activation does not become a full-library scan.
- Async work must be cancellable or generation-gated so stale results cannot overwrite a newer request.
- Stable IDs and explicit secondary sort keys preserve navigation, animation, and deterministic ordering.

## Product invariants

- Local playback may use the explicit Matrix Mixer route: front/rear left remain left-only, front/rear right remain right-only, and center/LFE feed both outputs with headroom.
- A failed local graph is quarantined and compatibility playback must be proven to start before success is recorded.
- Remote playback remains on the stable single-item path unless a separately accepted experiment proves its behavior.
- Cached remote browsing remains available while automatic checks are deferred.
- Local and remote alphabet indexes own only their right-edge strip; vertical list scrolling and hierarchy dismissal must not share an unintended gesture region.
- Downloads are atomic, duplicate-safe, cancellable, resumable where supported, and must never index a partial file.
- Artwork provenance remains distinguishable: embedded/provided art is not silently treated as an automatic fallback override.

## Change design

Before editing, write the change in `Docs/WORK-QUEUE.md` with:

- the user-visible goal;
- the owning module and exact files;
- the invariant(s) being preserved;
- the smallest causal lever;
- the behavior oracle and named workload;
- automated and manual acceptance;
- rollback/revert strategy.

If a change crosses two ownership boundaries, record the interface or state transition
explicitly instead of duplicating logic in both modules.
