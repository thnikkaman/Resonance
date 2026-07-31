# Resonance work queue

This is the lightweight execution record for the current phase. Each item names its owner, evidence, acceptance
oracle, and rollback point. Generated logs, diagnostics, screenshots, and build outputs remain outside Git.

## Active baseline

- Runtime baseline: signed Beta v1.0.9/build 261 installed in place on `SaiyanDenawa`; physical runtime acceptance remains user-run.
- Source baseline: `Resonance-Beta-v1.0.9` publication commit `3d455a0` on `agent/alpha-3.7.4-source`.
- Physical device: installed but not launched by Codex; user runtime acceptance remains pending.
- Full state record: `Docs/PROJECT-STATE.md`.

## Completed release work

### R-BETA-1.0.9 — Safe multi-disc album metadata editing

- Status: source corrected, signed, installed in place, committed, and published as a GitHub prerelease.
- Scope: keep the album-wide Disc Number for Every Track override blank by default so unrelated metadata saves preserve
  existing multi-disc assignments.
- Validation: `Tools/RegressionChecks.sh`, `git diff --check`, and strict simulator compilation passed.
- Release: https://github.com/thnikkaman/Resonance/releases/tag/Resonance-Beta-v1.0.9; device artifact `1.0.9/261`.
- Manual oracle: open a multi-disc album, confirm the field is blank, save an unrelated title change, and verify disc 1
  and disc 2 assignments remain intact; enter a value separately to verify intentional album-wide replacement.
- Rollback: revert the default-value correction and release identity bump.

### R-BETA-1.0.8 — Metadata editing and artwork-search polish

- Status: implemented, signed, installed in place, and published as a GitHub prerelease.
- Scope: stage artwork-search choices until metadata-editor Save; expose Artist and Album Artist in all metadata forms;
  place read-only album/artist information below artwork; add artwork-search keyboard dismissal.
- Source: `OnlineArtworkSearchView.swift`, `SmartLibraryViews.swift`, `LibraryStore.swift`, `AlbumDetailView.swift`;
  tag: `Resonance-Beta-v1.0.8`.
- Validation: `Tools/RegressionChecks.sh`, `git diff --check`, strict simulator compilation, signed Release build,
  deep code-signature verification, and `devicectl` in-place install passed.
- Manual oracle: launch Beta v1.0.8, test artwork Save versus Cancel, edit both Artist fields in every form, verify
  read-only content follows artwork, and dismiss the artwork-search keyboard.
- Rollback: reinstall Beta v1.0.7/build 259 without uninstalling.

### R-TOOLBAR-ACTIONS — Preserve stacked Browse Files and Download actions

- Status: implemented and included in Beta v1.0.7.
- Owner: Library/Streaming toolbar presentation.
- Preserved invariants: centered hierarchy navigation, leading controls, existing importer/download actions, and no hit regions.
- Evidence: regression checks, strict preflight, signed Release build, and in-place device installation passed.
- Manual oracle: user taps Browse Files, Download, and centered navigation on the installed beta.
- Rollback: revert the toolbar portion of the prior source commit.

### R-SETTINGS-HEX-KEYBOARD — Keep keyboard activation on the hex fields

- Status: implemented and included in Beta v1.0.7.
- Owner: `SettingsView.swift` RGB hex editor.
- Causal lever: remove the slider’s `onBeginEditing` callback; retain the callback on `HexChannelTextField`.
- Preserved invariants: slider value mapping, RGB editing, appearance layout, and keyboard behavior for actual fields.
- Evidence: regression checks, strict preflight, signed Release build, code-signature verification, and device install passed.
- Manual oracle: slider touches never summon the keyboard; actual hex-field touches do.
- Rollback: revert the focused `HexChannelSlider` callback removal.

### R-BETA-1.0.7 — Publish the completed beta

- Status: installed and pushed; user runtime acceptance pending.
- Artifact: `com.example.ResonancePrototype`, version `1.0.7`, build `259`.
- Source: commit `6aa68ae`; GitHub tag `Resonance-Beta-v1.0.7` and prerelease are published.
- Release: https://github.com/thnikkaman/Resonance/releases/tag/Resonance-Beta-v1.0.7
- Pull request: not created because `agent/alpha-3.7.4-source` has no common history with the ZIP-history `main` branch.
- Validation: `Tools/RegressionChecks.sh`, `Tools/PreflightBuild.sh`, signed Release build, deep signature verification, and `devicectl` install/info passed.
- Rollback: reinstall the preceding signed build without uninstalling.

## Ongoing safeguards

- R-PERF: profile before any new performance change; require a named reproduced workload and before/after evidence.
- R-DEVICE: physical playback, explicit 5.1 routing, background suspension, thermal, and long-idle acceptance require a user-launched device test.
- R-VIEWPORT: title, toolbar, and mini-player fixes must preserve the accepted browse viewport geometry; do not change content padding, offsets, safe-area insets, or scroll clearance without explicit user instruction.

## Active interface-polish work

### R-ALBUM-DISC-NUMBER — Edit album disc number in one operation

- Status: implemented and simulator-compiled; the follow-up default-value correction is complete. Physical runtime acceptance remains pending.
- Owner: `SmartLibraryViews.swift` album editor and `LibraryStore.swift` album metadata save boundary.
- Goal: expose one editable Disc Number field and apply it to every track in the selected album.
- Preserved invariants: track titles, track numbers, Artist, Album Artist, artwork behavior, targeted refresh, and
  disc-first/track-second ordering in album and All Albums lists.
- Manual oracle: enter a disc number in an album editor, Save, and confirm every affected file has that disc number;
  Cancel must leave all files unchanged.
- Rollback: revert the album-save signature and editor field changes.
- Evidence: `Tools/RegressionChecks.sh`, `git diff --check`, and the strict simulator build passed.
- Follow-up correction: the field now always opens blank. It no longer copies the first track’s disc number, so saving an
  unrelated album title change cannot rewrite a multi-disc album as disc 1. A blank value continues to preserve each
  track’s existing disc number.

### R-MINI-PLAYER-TOP-POSITION — Align top-docked mini-player below module headers

- Status: implemented and installed in the simulator; active-track visual confirmation remains pending.
- Owner: shared layered mini-player overlay in `RootView.swift`.
- Goal: place the top-docked mini-player directly below the common navigation/header controls at the same vertical position on every module.
- Acceptance oracle: the top-docked player clears the module label and Browse/Download controls without covering content or changing bottom/side docking.
- Rollback: revert the shared top inset change.
- Evidence: shared layered overlay inset changed from 176 to 100, then corrected to 158 and 145 points after user visual feedback. `git diff --check`, regression checks, simulator build, and in-place install passed.

### R-DETAIL-TITLE-HERO — Unify detail titles and top-player hero clearance

- Status: implemented and simulator-validated for the updated detail layout.
- Owner: shared detail-header presentation in `RootView.swift`, consumed by local/remote artist and album detail views.
- Goal: show artist and album titles above the top-docked mini-player using the same heading treatment as the local Library, then place artwork and hero actions below the player clearance.
- Preserved invariants: existing artwork, hero actions, hierarchy navigation, track lists, gestures, and bottom/side mini-player docking.
- Smallest causal lever: one shared detail-header container with conditional clearance only when the top mini-player is active.
- Acceptance oracle: local and Streaming artist/album detail screens use the same title size/style and hero vertical placement; no module-specific positioning workaround.
- Rollback: revert the shared detail-header component and its four call sites.
- Evidence: `git diff --check`, `Tools/RegressionChecks.sh`, `Tools/ProjectStateCheck.sh --source-only`, strict simulator build, in-place simulator install, and a launched simulator screenshot of the updated album detail passed. The screenshot used bottom-docked playback; top-docked playback was not manually reproduced in this run.

### R-DETAIL-BROWSE-CLEARANCE — Keep artist album rows below the top mini-player

- Status: reverted after visual regression; the structural inset caused the album cutoff to move lower.
- Owner: shared top-player content clearance in `RootView.swift`, consumed by local/remote artist and album browse surfaces.
- Goal: prevent Streaming and Library album content from reaching behind the top-docked mini-player.
- Preserved invariants: normal scrolling, alphabet indexes, detail hero layout, and bottom/side mini-player docking.
- Smallest causal lever: one conditional safe-area content inset shared by the affected browse surfaces.
- Acceptance oracle: the first album/artist rows remain fully visible below the top player when it is docked at the top, with no extra gap when it is docked elsewhere.
- Rollback: revert the shared modifier and its browse-surface call sites.
- Evidence: the shared structural inset was removed. Regression checks, simulator build, in-place install, and relaunch passed after rollback.
- Follow-up: removed the remaining conditional 70-point hero offset so title restoration cannot move the browse viewport.

### R-LOCAL-ALBUMS-HEADING — Restore the local Albums page heading

- Status: implemented as a non-layout overlay.
- Owner: shared Library browse heading in `LibraryView.swift`.
- Goal: make the local Albums page visibly match the restored Artists and Album Artists page structure.
- Preserved invariants: local album grid/list ordering, selection, navigation, and shared mini-player clearance.
- Acceptance oracle: local Library → Albums shows an “Albums” heading above the album content with the same themed typography and spacing as the artist pages.
- Rollback: revert the focused heading condition/text change.
- Evidence: the heading wrapper was removed and the label restored as an overlay over the existing top clearance; final simulator rebuild is pending.

### R-BROWSE-TITLES — Restore Artists and Album Artists page headings

- Status: implemented and validated through source checks and strict simulator preflight.
- Owner: `LibraryView.swift` root artist and album-artist browse presentation.
- Goal: restore visible page headings below the navigation bar while preserving the centered hierarchy control.
- Acceptance oracle: Artists and Album Artists show their headings above the existing grid/list, with normal scrolling and navigation unchanged.
- Rollback: revert the focused heading presentation change.
- Evidence: `git diff --check`, `Tools/RegressionChecks.sh`, and `Tools/PreflightBuild.sh` passed. The preflight retained only the known no-scheme destination and AppIntents metadata-skip warnings.

### R-HIERARCHY-ARTIST-TRIGGER — Match album-to-artist navigation trigger

- Status: implemented and validated through source checks and simulator compilation.
- Owner: `AlbumDetailView.swift` and `StreamingLibraryView.swift` hierarchy toolbar actions.
- Goal: make the album detail “Artist, move up” action use the same immediate parent-layer trigger as the other detail modules.
- Preserved invariants: local/remote parent selection, layered navigation state, standard 350 ms hierarchy animation, and fallback behavior for top-level album entries.
- Smallest causal lever: use the already-held parent artist immediately; retain catalog lookup only when no parent is present.
- Acceptance oracle: artist → album → Artist returns without a catalog-scan delay in local and Streaming album detail; top-level album entry still returns to its resolved artist.
- Rollback: revert the focused toolbar-action changes.
- Evidence: `git diff --check`, `Tools/RegressionChecks.sh`, `Tools/PreflightBuild.sh`, and the configured iPhone 17 Pro simulator build passed. Runtime interaction remains a manual simulator check.

## Definition of done

An implementation item is complete only when its source revision, artifact identity, owning module, preserved invariants,
automated gates, and manual acceptance status are documented. Credentials, private data, and generated outputs stay outside commits.
