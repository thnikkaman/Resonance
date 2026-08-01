# Resonance work queue

This is the lightweight execution record for the current phase. Each item names its owner, evidence, acceptance
oracle, and rollback point. Generated logs, diagnostics, screenshots, and build outputs remain outside Git.

## Active baseline

### R-STREAMING-FLAC-LEFT-HAND — Repair Streaming FLAC alert cache activation and left-handed artist albums

- Status: implemented; automated validation, physical-device installation, simulator installation, and public build-268 publication passed; physical runtime acceptance remains user-run.
- Owners: `RemoteLibraryStore.swift` for cached remote format metadata; `StreamingLibraryView.swift` for remote browse layout.
- Goal: show the enabled gold FLAC border in Streaming even when the catalog was cached before file extensions were persisted, and keep Streaming artist album content clear of the left alphabet strip.
- Preserved invariants: cached browsing remains available, remote refresh remains explicit except for this one-time format migration, right-handed geometry is unchanged, and the alphabet strip remains in its existing hit region.
- Smallest causal levers: one conditional Subsonic cache-refresh predicate, the existing local-library left-handed padding values applied to the Streaming artist album grid, and a 32-point alphabet gesture column that does not overlap browse content.
- Manual oracle: enable Flac Alert and inspect Streaming album grids/lists and album detail; enable left-handed mode and confirm artist album artwork/cards begin to the right of the alphabet while right-handed mode is unchanged.
- Rollback: revert this queue entry and the focused `RemoteLibraryStore.swift` and `StreamingLibraryView.swift` changes.

- Runtime baseline: signed Beta v2.0/build 268 installed on Sarah's iPhone and Chase's iPhone; physical runtime acceptance remains user-run.
- Source baseline: GitHub-synchronized commit `baef8bc` on `agent/alpha-3.7.4-source`.
- Physical devices: installed but not launched by Codex; user runtime acceptance remains pending. Chase's installation uses the separate bundle `com.chaseatron.Resonance` because the original bundle is owned by another team.
- Full state record: `Docs/PROJECT-STATE.md`.

### R-ALPHABET-TOUCH-TRACE — Capture left-handed alphabet gesture delivery

- Status: diagnostic trace implemented, validated, and installed on `SaiyanDenawa`; user reproduction pending.
- Owner: `LibraryView.swift` `VerticalArtistIndex` gesture boundary.
- Scope: extend the existing Debugging Mode log with opt-in touch begin/end coordinates and layout geometry for local
  artists, Streaming artists, Streaming albums, and Streaming artist-album indexes; give left-handed Streaming indexes
  a 48-point edge hit strip while preserving the 32-point visible column and local Library behavior.
- Privacy boundary: no track names, URLs, credentials, file paths, or audio data are recorded.
- Evidence: commits `981e839`, `3be137f`, and `7da4ed2`; `Tools/RegressionChecks.sh`, `git diff --check`, signed Release compilation, strict
  code-signature verification, and in-place `devicectl` installation passed. The app was not launched by Codex.
- Manual oracle: enable Debugging Mode, enable Left-handed alphabet, reproduce touches directly on the visible letters
  and then just to their right in each affected Streaming surface, and copy `Documents/Resonance-Diagnostics.log`.
- Continuation: retrieve the log before disabling Debugging Mode; compare whether `alphabet.touch.begin/end` appear for
  the visible-letter touches and record their `x`, `width`, `hitWidth`, and `columnWidth` values.

### R-BETA-2.0-BUILD-268 — Publish the latest Beta 2.0 build

- Status: implemented, validated, installed in place, pushed, and published publicly.
- Scope: gold FLAC-only artwork borders across Streaming and local album presentations; Siri/App Intents for song,
  album, artist, and audiobook playback; remote FLAC cache migration; and left-handed Streaming layout correction.
- Source: `agent/alpha-3.7.4-source` at commit `baef8bc`.
- Release: https://github.com/thnikkaman/Resonance/releases/tag/Resonance-Beta-v2.0-build268
- Validation: regression checks, diff check, strict preflight, signed Release compilation, deep signature verification,
  Sarah/Chase in-place installations, and iPhone 17 Pro simulator installation passed.
- Manual oracle: enable Flac Alert in local and Streaming libraries, inspect grid/list/artist-detail/album-detail artwork,
  test Siri/App Intents, enable left-handed alphabet mode, and verify scrolling and album positioning.
- Physical devices were not launched by Codex; playback and full runtime acceptance remain user-run.

## Completed release work

### R-BETA-2.0 — Audiobook playback and bookmark history

- Status: implemented, validated, installed in place, committed, and published as a GitHub prerelease.
- Scope: mark local and personal Streaming albums as audiobooks; resume the newest saved position; expose audiobook-only
  speed controls; retain five pause/stop positions per audiobook album; save one position when an active audiobook exits
  the foreground; keep manual bookmarks separate; and scope the viewer to the active audiobook with album/book and track titles.
- Preserved invariants: normal-music controls, explicit 5.1 routing, existing library geometry, in-place app data, and
  manual bookmark storage.
- Validation: source parsing, `git diff --check`, signed Release compilation, strict signature verification, and device install.
- Manual oracle: mark multiple albums, pause/stop several tracks in each, verify five positions per album, reopen the app
  while an audiobook is playing, and confirm the active audiobook’s positions appear above manual Saved Positions.
- Rollback: reinstall the prior signed beta without uninstalling.
- Release: https://github.com/thnikkaman/Resonance/releases/tag/Resonance-Beta-v2.0; branch commit `088c291`.

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

## Active feature work

### R-AUDIOBOOK-RESUME — Persist audiobook flags, resume positions, and speed controls

- Status: implemented, validated, and installed in place in Beta 2.0; physical runtime acceptance remains user-run.
- Goal: let users mark local and personal Streaming albums as audiobooks, resume the album from the most recent
  pause/stop position, retain the five most recent audiobook pause bookmarks per audiobook album, and expose playback
  speed only for the active audiobook. There is no global limit on the number of audiobook albums.
- Owners: `PlayerController.swift` and `GaplessAudioEngine.swift` own durable playback state and backend rate
  application; `AlbumDetailView.swift`, `LibraryView.swift`, and `StreamingLibraryView.swift` expose matching album
  context actions; `PlayerViews.swift` exposes the audiobook-only speed/history controls.
- Preserved invariants: explicit 5.1 routing, existing manual per-track bookmarks, normal-music controls and speed,
  local/remote album ordering, existing navigation geometry, and in-place app data.
- Smallest causal lever: one normalized album identity and one PlayerController resume API used by both local and
  remote album Play actions; no duplicate album-specific playback logic.
- Behavior oracle: mark an album, pause/stop in a later track, play the album’s main Play action, and return to that
  track/position after switching tracks and relaunching; recent history remains capped at five; explicit track taps
  still start that track normally; speed controls are absent for normal music.
- Automated acceptance: regression contracts, `git diff --check`, strict simulator/generic-device preflight, signed
  Release build, code-signature verification, and in-place `devicectl` install.
- Manual acceptance: user launches the installed build and tests local plus Streaming albums, pause/stop recovery,
  five-entry-per-album history across multiple audiobook albums, speed changes, normal music controls, and persistence
  after relaunch.
- Rollback: revert the focused audiobook commits without uninstalling the prior app, preserving existing UserDefaults
  and library data.
- Evidence: source build `2.0/267`; source parsing, `git diff --check`, signed Release,
  deep signature verification, and `devicectl` install/info all passed on 2026-07-31. The phone was not launched.

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

### R-ALPHABET-FIRST-TOUCH — Make alphabet jumps reliable on the first attempt

- Status: implemented and installed in place on `SaiyanDenwa`; physical runtime acceptance remains user-run.
- Owner: `LibraryView.swift` `VerticalArtistIndex`, shared by local and Streaming alphabetized surfaces.
- Goal: prevent intermittent jumps and stale gesture state from making the first touch after a prior alphabet gesture appear ineffective.
- Smallest causal lever: synchronously reset gesture state at release, apply the release target immediately, and guard the deferred repeat with a gesture generation.
- Preserved invariants: left-handed 48-point Streaming hit strip, visible 32-point alphabet column, normal browse scrolling outside the strip, selection bubble, haptics, and section-jump behavior.
- Automated evidence: `git diff --check`, strict Swift 6 simulator/generic-device preflight, signed arm64 Release build, deep signature verification, and in-place `devicectl` installation passed. `Tools/RegressionChecks.sh` is currently blocked by its unrelated stale `confirmed file artwork` assertion.
- Manual acceptance: with Debugging Mode enabled, test repeated first-touch jumps and quick successive gestures in Streaming Artists, Streaming Albums, Streaming artist albums, and local Library; then copy the diagnostics log if any attempt still fails.
