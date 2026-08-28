# Resonance service-layer contract

Read the repository root `AGENTS.md` and `Docs/ARCHITECTURE.md` before changing a
service. Services own durable behavior and state; Views consume their projections.

## Ownership map

- `LibraryStore.swift` owns local catalog state, grouping, artwork overrides, targeted
  refresh, and the local-library mutation boundary.
- `LibraryDatabase.swift` owns SQLite persistence behind its actor boundary.
- `MetadataReader.swift` and `MetadataWriteBatch.swift` own file metadata reads and
  supported FLAC/MP3 writes.
- `RemoteLibraryStore.swift` owns remote requests, cached catalog activation, refresh
  generations, canonicalization, and remote browse projections.
- `RemoteDownloadService.swift` owns download queue state, atomic file writes,
  cancellation, replacement choices, restoration, and indexing handoff.
- `PlayerController.swift` owns queue state, current-track state, seek authority,
  backend selection, and Now Playing state.
- `GaplessAudioEngine.swift` owns audio graph lifecycle, preload, explicit 5.1 matrix
  routing, and matrix-failure fallback/quarantine.
- `ArtworkSearchService.swift` owns provider requests, relevance ranking, bounded
  decoding, candidate identity, and artwork provenance.
- `AppSettings.swift` owns persisted settings and Keychain access boundaries.
- `ResonanceDiagnostics.swift` and `AppErrorLog.swift` own privacy-safe diagnostics
  and persistent error reporting.

## Service rules

- Keep one authoritative owner for each durable value. Expose projections or explicit
  mutation methods instead of making views or neighboring services copy the truth.
- Keep async work cancellable or generation-gated. Stale remote, artwork, download,
  or scan results must not overwrite newer state.
- Preserve stable IDs, ordering, grouping, cache authority, cancellation semantics,
  and persisted data when changing an implementation.
- Keep download writes atomic and duplicate-safe; partial files must never be indexed.
- Keep playback and audio changes separate from browse, artwork, and download changes.
- Services must not import SwiftUI merely to perform layout or presentation work.
- Never place credentials, authenticated URLs, private music, signing secrets, or
  private keys in diagnostics, tests, or documentation.

## Change checklist

Before editing, name the service owner, invariant, input/output boundary, behavior
oracle, and rollback point in `Docs/WORK-QUEUE.md`. If a view needs a new capability,
add the narrow service interface and keep presentation logic in `Resonance/Views`.

Validate with the narrowest relevant contract checks, then `Tools/RegressionChecks.sh`
and the appropriate build preflight. A successful compile is not runtime acceptance;
audio, background, thermal, and 5.1 claims require physical-device evidence.
