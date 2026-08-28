# Resonance view-layer contract

Read the repository root `AGENTS.md` and `Docs/ARCHITECTURE.md` before changing a
view. This file narrows those rules to SwiftUI presentation code.

## Layout and interaction ownership

- `RootView.swift` owns tab composition, navigation stacks, safe-area placement,
  mini-player placement, and gesture arbitration between hierarchy navigation and
  content scrolling.
- `LibraryView.swift` and `SmartLibraryViews.swift` own local browse presentation,
  local selection gestures, and local editor presentation.
- `StreamingLibraryView.swift` owns remote browse presentation, remote selection,
  alphabet-strip gestures, and download action presentation.
- `AlbumDetailView.swift` owns shared album/detail presentation and its layout-level
  actions; catalog mutations remain in the stores or download service.
- `PlayerViews.swift` owns Now Playing and mini-player rendering, transport controls,
  and transient drag/docking presentation.
- `SettingsView.swift` owns Settings layout, section presentation, and transient
  form interaction.
- `ArtworkView.swift` and `OnlineArtworkSearchView.swift` own artwork rendering and
  picker presentation; provider requests and artwork persistence remain elsewhere.

Views are the authority for layout: hierarchy, spacing, sizing, grids, lists,
overlays, adaptive presentation, accessibility, and presentation-only gestures.

## State boundary

- `@State`, `@FocusState`, gesture phases, selected sheets, expanded sections, and
  similar values are allowed when they are transient presentation state.
- Durable catalog, download, playback, settings, artwork, and persistence truth must
  come from the owning service/store. Do not create a second durable copy in a view.
- Views must not become network clients, download managers, tag writers, SQLite owners,
  playback engines, or audio-routing code.
- Do not perform broad scans, provider searches, database writes, or remote requests
  from `body` or from a high-frequency rendering path.
- Keep high-frequency elapsed, meter, byte-progress, and buffer observations below the
  root tab tree so unrelated browse surfaces do not redraw.

## Change checklist

Before changing layout, identify the owning view, the affected service/store boundary,
the preserved navigation and gesture invariants, and the manual interaction oracle.
If a view change needs new business behavior, define that interface in the owning
service first and record the cross-boundary change in `Docs/WORK-QUEUE.md`.

Validate with Swift parsing and `Tools/RegressionChecks.sh`. Runtime layout claims
require an explicitly run simulator or device check; compilation and installation do
not prove interaction behavior. Do not launch `SaiyanDenawa` or capture screenshots
automatically.
