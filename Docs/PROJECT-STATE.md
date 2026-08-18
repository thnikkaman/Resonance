# Resonance verified project state

Last verified: 2026-08-16

## MeiKyo App Store Connect test upload — version 1.0/build 346 — 2026-08-16

- Build 346 prevents an invalid short LRC timeline from auto-highlighting and scrolling to its final line. The
  Chapter 2 file has valid metadata but timestamps ending at 2.1 seconds for a 21-minute audio track; the app now
  opens that timeline at the top without claiming false synchronization.
- Regression checks, full preflight, signed Release archive, and deep strict code-signature verification passed.
- Xcode exported and uploaded `com.briangarcia.meikyo` version 1.0/build 346 to App Store Connect. Apple reported
  `Upload succeeded` and `Uploaded package is processing`. The build was not installed or launched on the phone.
- Standard non-blocking warnings remain: empty/no-scheme destination metadata, AppIntents SSU archive, and vendored
  HLSL `format-extra-args`/deprecated `sprintf` warnings.
- Next manual check: install build 346 through TestFlight after processing, then open Chapter 2 and confirm it starts
  at the top rather than jumping to the final lyric line. Properly timed LRC files should continue highlighting.

## UTF-16 LRC metadata decoding — version 1.0/build 342 — 2026-08-16

- Device verification showed the selected-folder scan could read LRC files, but chapters without filename matches
  still failed metadata lookup. The production metadata parser accepted malformed UTF-8-with-NUL or generic UTF-16
  decoding before trying UTF-16LE, so BOM-less Windows-exported LRC metadata was not decoded correctly.
- Build 342 rejects NUL-contaminated UTF-8, tries UTF-16LE/BE metadata text with marker validation, and keeps the
  playback lookup scoped to the playing MP3's parent folder. The focused fixture now verifies a BOM-less UTF-16LE LRC
  containing title, album, and track metadata.
- Regression checks, signed arm64 Release archive, deep strict signature verification, and in-place installation passed.
  `devicectl` verified MeiKyo version 1.0/build 342 on `SaiyanDenawa`; the app was not launched.
- Standard non-blocking warnings remained: empty/no-scheme destination metadata, AppIntents SSU archive, and vendored
  HLSL `format-extra-args`/deprecated `sprintf` warnings.
- Manual acceptance: play the Chamber of Secrets chapters whose LRC files are beside the MP3s and confirm lyrics load
  without playback delay or manual import.

## Playback-triggered fresh audiobook LRC rescan — version 1.0/build 340 — 2026-08-16

- Build 339 still left the one-time companion-cache behavior in place, so LRC files copied into the selected Files
  folder after indexing were not guaranteed to be checked when a later audiobook track started.
- Build 340 rescans the selected library folder from the Now Playing playback-load path for audiobook tracks before
  local lyric lookup. The lookup now walks coordinated directories explicitly, reads newly visible LRC files, and then
  applies their metadata match; it no longer relies on the old one-time cache or one enumerator snapshot.
- Regression checks, signed arm64 Release archive, deep strict signature verification, and in-place installation passed.
  `devicectl` verified MeiKyo version 1.0/build 340 on `SaiyanDenawa`; the app was not launched.
- Standard non-blocking warnings remained: empty/no-scheme destination metadata, AppIntents SSU archive, and vendored
  HLSL `format-extra-args`/deprecated `sprintf` warnings.
- Manual acceptance: start Chapters 2 and 3 after their LRC files are already beside the MP3s; verify each loads
  automatically without manual import. This is a physical-device runtime check and has not been performed by Codex.

## Selected-folder-wide metadata LRC fallback — version 1.0/build 339 — 2026-08-16

- Build-338 diagnostics after the Chamber of Secrets test showed `audioExists=true`, an active selected-folder bookmark,
  and `siblingCandidate=false`; the File Provider did not expose the LRC beside the audio during immediate-parent lookup.
- Build 339 adds a final coordinated scan of the entire authorized selected library folder. It reads LRC metadata and
  selects a title/album/artist/track match even when the sidecar is hidden from the audio directory listing. Exact-name
  lookup remains the fallback when metadata is absent.
- Regression checks, signed arm64 Release archive, deep strict signature verification, and in-place installation passed.
  `devicectl` verified MeiKyo version 1.0/build 339 on `SaiyanDenawa`; the app was not launched.
- Standard non-blocking warnings remained: empty/no-scheme destination metadata, AppIntents SSU archive, and vendored
  HLSL `format-extra-args`/deprecated `sprintf` warnings.

## Metadata-aware LRC companion matching — version 1.0/build 338 — 2026-08-16

- Build 338 parses optional LRC headers `[resonance-id]`/`[id]`, `[ti]`, `[al]`, `[ar]`/`[au]`, `[tr]`, and `[di]`.
- Local sibling lookup now prefers LRC metadata: stable ID when available, then title plus album/track identity, then
  album and track identity, with the normalized filename matcher as a fallback. This removes the audio filename from
  the primary lyric identity and handles `Chapter 1` versus `Chapter 01`.
- The LRC bytes still must exist on the phone beside the audio or in the selected library folder; metadata identifies a
  local sidecar but does not download one from Navidrome.
- The metadata fixture, regression checks, signed arm64 Release archive, deep strict signature verification, and
  in-place installation passed. `devicectl` verified MeiKyo version 1.0/build 338 on `SaiyanDenawa`; the app was not
  launched.
- Standard non-blocking warnings remained: empty/no-scheme destination metadata, AppIntents SSU archive, and vendored
  HLSL `format-extra-args`/deprecated `sprintf` warnings.

## Audiobook LRC chapter-number normalization — version 1.0/build 337 — 2026-08-16

- Build-336 diagnostics showed 8,071 audio files and 36 LRC files but zero companion matches. The downloaded Prisoner
  representation uses `Chapter 1`, while common sidecars use `Chapter 01`; punctuation normalization alone rejected
  the pair.
- Build 337 canonicalizes leading zeroes in chapter numbers, so `Chapter 1: “Owl Post”` matches `Chapter 01 - Owl Post`
  within the same folder. The focused fixture covers that exact representation and the existing Hobbit cases.
- The server is being updated to expose the actual source filename. Once exposed, the existing downloader precedence
  preserves it; generated `01 - …` naming remains only a final fallback. Existing local files are not renamed.
- Regression checks, signed arm64 Release archive, deep strict signature verification, and in-place installation passed.
  `devicectl` verified MeiKyo `com.briangarcia.meikyo`, version 1.0/build 337 on `SaiyanDenawa`. The app was not launched.
- Standard non-blocking warnings remained: empty/no-scheme destination metadata, the AppIntents SSU archive warning,
  and existing vendored HLSL `format-extra-args`/deprecated `sprintf` warnings.

## Audiobook download filename precedence correction — version 1.0/build 336 — 2026-08-16

- Build 335 still allowed the HTTP response's suggested filename to override the remote catalog/path filename. That
  response can be a metadata-generated name such as `01 - Chapter 01_ An Unexpected Party.mp3`, so the intended
  preservation change did not work for the user's audiobook.
- Build 336 corrects the precedence in `RemoteDownloadService`: the original catalog/path filename wins, the HTTP
  suggested filename is a fallback, and the generated metadata filename remains the final fallback. Foreground and
  background downloads use the same destination logic. Existing files are intentionally not renamed.
- `git diff --check`, source-contract regression checks, signed arm64 Release archive, deep strict signature
  verification, and in-place installation passed. `devicectl` verified MeiKyo `com.briangarcia.meikyo`, version 1.0/build
  336 on `SaiyanDenawa`. The app was not launched; physical redownload acceptance remains user-run.
- The production handoff/source commit is `5133d6c` (`Preserve original audiobook download filenames`).
- Standard non-blocking warnings remained: Xcode's `IDERunDestination: Supported platforms for the buildables in the
  current scheme is empty`, the no-scheme generic-destination warning from preflight, the AppIntents SSU archive warning
  because this target has no AppIntents dependency, and existing vendored HLSL `format-extra-args`/deprecated `sprintf`
  warnings. None prevented compilation, signing, installation, or device verification.

## Audiobook filename reconciliation and download filename preservation — version 1.0/build 335 — 2026-08-16

- Build 334 was user-tested with no behavior change. Its always-on inventory event reported 8,071 audio files, 36 LRC
  files, zero direct candidates, zero enumerated matches, and zero cached companions.
- The copied build-334 phone database proves the first Hobbit audio URL ends in
  `01 - Chapter 01_ An Unexpected Party.mp3`; the user-provided adjacent LRC is
  `Chapter 01 - An Unexpected Party.lrc`. The former exactly matches `RemoteDownloadService`'s prior generated naming
  rule: two-digit track number, metadata title, and replacement of `:` with `_`.
- `LyricsCompanionMatcher.swift` is now the single production representation matcher for scan-time caching and direct
  playback sibling enumeration. It keeps parent-folder identity in every key, normalizes the proven prefix/punctuation
  difference, and does not move or copy either file. Build 335 uses a v3 one-time scan key.
- `Tools/LyricsCompanionMatcherFixture.swift` compiles with that production source and passes the exact Chapter 01 pair,
  Chapters 02/04, a different-chapter rejection, and a different-folder rejection.
- Future remote downloads preserve a usable server response/catalog filename; generated metadata filenames are fallback
  only. Existing downloaded files are deliberately not renamed.
- Current validation state: source-contract regression checks, the focused executable matcher fixture, Swift 6 strict
  simulator and generic-device preflight, signed arm64 Release archive, deep strict signature verification, and
  in-place installation passed. The archive was built from checkout commit `0a34c86` with the intentional working-tree
  changes present. `devicectl` verified MeiKyo `com.briangarcia.meikyo`, version 1.0/build 335 on `SaiyanDenawa`.
  The app was not launched; physical audiobook runtime acceptance remains user-run.
- The authoritative DOCX at `/Users/brian/Downloads/Resonance Alpha — Codex Development Handoff.docx` is currently
  inaccessible to this process because macOS returns `Operation not permitted` for Downloads. These repository handoff
  documents contain the pending synchronized entry; the DOCX still requires Downloads Folder or Full Disk Access.

## Direct dual-name LRC scan — version 1.0/build 334 — 2026-08-16

- The user waited for build 333 and ran the manual library scan, but automatic lyrics still failed. The copied private
  companion cache was a valid empty plist, proving zero LRC bytes were captured.
- Missing `library.scan` lines did not prove the scan was skipped: those older events use optional verbose diagnostics.
  The Settings and Library scan controls both call `scanSharedMusicFolder` correctly.
- Build 334 directly tries `<audio stem>.lrc` and `<complete audio filename>.lrc` for every scanned audio URL while the
  selected folder is coordinated, then falls back to case-insensitive enumerated matches. Aggregate inventory counts are
  now always recorded. A v2 migration key forces one new scan after upgrade.
- Source-state validation, regression contracts, signed arm64 Release compilation, strict deep signature verification,
  and in-place installation passed. `devicectl` verified MeiKyo 1.0/build 334. The app was not launched automatically.

## Scan and cache adjacent LRC contents — version 1.0/build 333 — 2026-08-16

- Build 332 was user-tested with no behavior change. Its fresh diagnostics showed a valid audio URL and selected-folder
  bookmark but no bytes from any automatic sibling candidate; no build-332 `library.scan.inventory` event occurred.
- Build 333 removes the per-LRC bookmark approach. The authorized selected-library scan reads exact same-folder,
  same-basename LRC bytes and atomically replaces a private Application Support cache. Playback parses those cached
  bytes through the existing LRC parser. No file is copied into the user-visible MeiKyo music folder.
- Existing cached libraries schedule one automatic companion scan after the build-333 upgrade. The completion key is
  set only after that scan returns, and `library.scan.inventory companionCount` reports the number captured.
- Source-state validation, regression contracts, signed arm64 Release compilation, strict deep signature verification,
  and in-place installation passed. `devicectl` verified `com.briangarcia.meikyo` version 1.0/build 333. The physical
  app was not launched automatically. Runtime audiobook acceptance remains user-run.

## Selected-folder exact-basename LRC read — version 1.0/build 332 — 2026-08-16

- Build 331 was installed and user-tested on Hobbit Chapters 2 and 4 with no behavior change. It is not considered
  runtime validation.
- Build 332 retains a security-scoped bookmark for each exact same-basename `.lrc` found while scanning the selected
  library. Playback derives the companion URL from the selected folder and reads it under that folder scope before
  trying item-based fallbacks. No file is copied into MeiKyo.
- `library.scan.inventory` now records `companionCount`, and `lyrics.local.lookup.result` identifies the successful
  source, so the next device test can show whether discovery or read access is failing.
- Source contracts, diff validation, signed arm64 Release compilation, strict deep code-signature verification, and
  in-place installation passed. `devicectl` verified `com.briangarcia.meikyo` version 1.0/build 332. The app was not
  launched automatically. Xcode emitted only the known no-scheme destination warning and harmless AppIntents SSU
  archive warning.

## Direct exact-basename LRC read — version 1.0/build 331 — 2026-08-16

- A read-only copy of the physical device's build-328 SQLite library showed 8,072 external file URLs and zero managed
  file URLs; all 19 Hobbit tracks were external. This disproves the stale-managed-path theory behind earlier attempts.
- Build 331 attempts a direct read of the exact `<audio basename>.lrc` URL first while the audio URL's security scope is
  active. If that fails, sibling discovery and data reading continue while the actual audio item is the `NSFileCoordinator` anchor;
  it then inspects that item's parent directory before leaving the coordinated access while the persisted selected-folder
  security scope is active. The exact `<audio basename>.lrc` is preferred, followed by a
  case-insensitive extension/name match. The recursive selected-folder fallback is also coordinated, is reached only
  after the direct lookup fails, and all of this work runs on a utility task rather than the main actor.
- No audio or lyric files are copied, moved, renamed, or written. Imported lyric overrides remain first in precedence.
- `git diff --check`, source-state validation, regression checks, ordinary dual-architecture simulator compilation,
  signed arm64 Release compilation, and strict deep signature verification passed. Build 330 installed in place on
  `SaiyanDenawa`; `devicectl` verified `com.briangarcia.meikyo` version 1.0/build 331. The physical app was not launched.
- Exact continuation point: manually play Hobbit Chapters 2 and 4 and open Lyrics in Now Playing and the visualizer.
  Do not use Chapter 3 as the primary test because it has a manually imported override. If a direct match still fails,
  retrieve the diagnostics log; build 329 records whether the selected bookmark resolved and which lookup route supplied
  bytes without recording filenames or paths.

## Search selected library for exact LRC basename — version 1.0/build 328 — 2026-08-16

- Build 328 recursively searches the selected library folder for an exact same-basename LRC, independent of stale cached
  audio paths. No file copying is involved.

## Use selected audiobook folder in place — version 1.0/build 327 — 2026-08-16

- Build 327 fixes the workflow mismatch: selecting a directory now stores its security-scoped bookmark and scans it in
  place rather than copying audio into MeiKyo’s managed folder. Adjacent LRC files remain at their original URLs.

## Resolve companion LRCs from selected folder — version 1.0/build 326 — 2026-08-16

- Build 326 adds a direct LyricsService fallback from stale managed-folder audio URLs to the persisted selected-folder
  bookmark, so lookup does not depend on cache rehydration timing.

## Rebase cached tracks into selected library folder — version 1.0/build 325 — 2026-08-16

- Build 325 addresses the confirmed diagnostics result: the audio URL existed, but no sibling LRC candidate existed
  because cached playback tracks still referenced MeiKyo’s managed-folder copy. Stale managed-folder paths are now
  rebased into the active selected folder before entering the queue; no files are copied or deleted.
- The physical device build/install is the next release step; the app must not be launched automatically.

## Read audiobook LRCs beside original audio — version 1.0/build 323 — 2026-08-16

## Decode audiobook LRC companion files reliably — version 1.0/build 324 — 2026-08-16

- Build 324 preserves in-place sibling lookup in the selected external library folder, rebases stale cached managed-folder
  tracks into that folder before playback, adds UTF-8/UTF-16/UTF-32/ISO-Latin-1 LRC decoding, and records privacy-safe
  lookup/result booleans for diagnosing inaccessible or unparsable companions.
- Simulator compilation and source-contract validation passed. The signed physical build/install is the next release step;
  the physical app must not be launched automatically.

- Build 323 removes the incorrect import-time sidecar-copy behavior. LyricsService reads the exact same-basename `.lrc`
  beside the actual audio file and uses `ExternalFileCoordinator` for selected external library folders; no lyric file is
  copied into MeiKyo’s managed music folder. The parsed document feeds both Now Playing and the visualizer.
- Source contracts, strict preflight, signed Release compilation, deep signature verification, and in-place install passed;
  `devicectl` verified version 1.0/build 323 on `SaiyanDenawa`. The physical app was not launched. Manual acceptance:
  with the Hobbit folder selected as the library, play Chapters 2 and 3 and verify their adjacent LRC files load without
  import and remain visible in Now Playing and the visualizer.

## Import audiobook LRC companions — version 1.0/build 322 — 2026-08-16

- Build 322 fixes the root cause of missing Chapter 2 lyrics: `LibraryStore.importURLs` copied supported audio files but
  skipped adjacent `.lrc` files. Import now copies a matching LRC beside each imported audio file, using coordinated
  external-file-provider reads/writes and preserving existing sidecars. Existing imported audiobook folders need one
  re-import to copy their sidecars; app-private manual overrides remain unchanged.
- Source contracts, strict preflight, signed Release compilation, deep signature verification, and in-place install passed;
  `devicectl` verified version 1.0/build 322 on `SaiyanDenawa`. The physical app was not launched. Manual acceptance:
  re-import the Hobbit folder once, play Chapters 2 and 3, and verify both Lyrics buttons become available automatically.

## Fullscreen local lyrics refresh — version 1.0/build 321 — 2026-08-16

- Build 321 makes `ProjectMFullscreenView` explicitly load the active track through the shared `LyricsStore` when the
  fullscreen cover opens. This ensures the local same-basename `.lrc` scan runs even if the parent Now Playing task has
  not completed. Imported overrides remain first and provider lookup remains fallback.
- Source contracts, strict preflight, signed Release compilation, deep signature verification, and in-place install passed;
  `devicectl` verified version 1.0/build 321 on `SaiyanDenawa`. The physical app was not launched. Manual acceptance is
  to open the visualizer directly for a Hobbit track with a matching adjacent `.lrc` and verify lyrics appear without import.

## Visualizer transport and local audiobook LRC lookup — version 1.0/build 320 — 2026-08-16

- Build 320 keeps Exit, preset actions, and the new previous/play-pause/next controls in the same dismissible
  visualizer HUD. Exit occupies the former play/pause position; transport controls occupy the former Exit position,
  with a bottom seek bar and elapsed/duration labels.
- Local lyrics lookup now checks a local audio track's exact same-basename `.lrc` companion before remote lookup,
  while app-imported overrides remain first. This removes reliance on a stale audiobook-marker presentation state;
  marked audiobook albums therefore discover adjacent LRC files automatically.
- Regression checks, strict simulator and generic-device preflight, signed arm64 Release compilation, and deep signature
  verification passed. Build 320 was installed in place on `SaiyanDenawa` without uninstalling; `devicectl` verified
  version 1.0/build 320. The physical app was not launched. Manual acceptance: reveal the HUD and test Exit, previous,
  play/pause, next, seek, and dismissal; mark an audiobook, start a track with an adjacent `.lrc`, and verify lyrics
  appear without manual import. Known non-blocking warnings remain the no-scheme destination, vendored HLSL parser, and
  AppIntents SSU archive warnings.

## Visualizer opening title and ProjectM safety cap — version 1.0/build 319 — 2026-08-16

- The current source keeps the global ProjectM custom-shape `num_inst` cap at 128 and adds an immediate native
  visualizer lyrics cue. With fullscreen visualizer lyrics enabled, the current track title is shown from playback
  start, yielding immediately if the first synced lyric begins, or for five seconds when lyrics do not start promptly;
  title-only tracks clear after the same five-second window. Lyric lookup, playback, and the renderer loop are unchanged.
- Build 319 passed regression checks, source/build validation, strict simulator and generic-device preflight, signed
  arm64 Release compilation, and deep signature verification. It was installed in place on `SaiyanDenwa` without
  uninstalling; `devicectl` verified bundle `com.briangarcia.meikyo`, version 1.0/build 319. The physical app was not
  launched. Xcode retained the known no-scheme destination, vendored HLSL parser, and AppIntents SSU archive
  warnings; none blocked the build or install. Manual acceptance is to start tracks in the visualizer, verify the
  immediate title and lyric handoff, and compare the shape-heavy low-framerate presets with build 317.

## ProjectM global shape-instance safety budget — version 1.0/build 317 — 2026-08-16

- The current source adds one global engine-level guard in
  `Resonance/ThirdParty/ProjectM/vendor/projectm/libprojectM-4.1.7/src/libprojectM/MilkdropPreset/CustomShape.cpp`:
  `num_inst` is clamped to 128 when each preset is loaded. No individual visualization resource was edited or
  deleted. The reported 50 low-framerate presets all use custom warp shaders, 41 request at least 129 shape
  instances, and none contains per-pixel mesh code; the ProjectM mesh remains 32×24.
- The current checkout remains `/Users/brian/Resonance/Resonance-Alpha-3.7.4` on
  `agent/alpha-3.7.4-source` at source commit `0a34c869f7bec86d1eaf783b9264a1eef3c50711`, with this build-317
  change uncommitted alongside the existing intentional dirty worktree. Project defaults are MeiKyo version 1.0/build
  317.
- This source change is not yet device-performance evidence. The next manual run must use the same archive-rotation
  workload with audio playing and downloads stopped, compare native render windows and low-framerate banishments with
  the prior build, and inspect shape-heavy presets for acceptable visual continuity. If the same IDs remain below the
  threshold, quarantine them from the next catalog instead of editing their files.

## Settings, visualizer HUD, and lyrics persistence — version 1.0/build 316 — 2026-08-16

- The current checkout remains `/Users/brian/Resonance/Resonance-Alpha-3.7.4` on
  `agent/alpha-3.7.4-source` at source commit `0a34c869f7bec86d1eaf783b9264a1eef3c50711`, with the existing
  intentional dirty worktree preserved. Project defaults are MeiKyo version 1.0/build 316.
- Settings is now a non-scrolling category hub. Each category is a full-width single-tap button that pushes its
  dedicated settings page through an explicit navigation destination, so the existing `NavigationStack` provides the
  requested right-to-left push and left-to-right back pop while preserving all existing controls, bindings, pickers,
  alerts, and persistence. The old form-wide tap recognizer that could interfere with row activation is removed.
- Playing now has an explicit Visualizer button using the existing photosensitivity acknowledgment gate. The fullscreen
  visualizer's Exit control is part of the same dismissible HUD as Browse, Favorites, and Banish, rather than a separate
  overlay; the existing double-tap dismissal and renderer lifecycle remain intact.
- The Now Playing lyrics overlay no longer closes when seeking, pausing, or resuming causes the shared lyrics document
  to refresh. It closes through its X control (or an intentional track change/fullscreen transition), preserving the
  lyrics panel while playback controls are used.
- `Tools/ProjectStateCheck.sh --source-only`, `Tools/RegressionChecks.sh`, Swift parsing, `git diff --check`, strict
  simulator/generic-device preflight, signed arm64 Release compilation, and `codesign --verify --deep --strict`
  passed. Known non-blocking output remains the no-scheme destination warning, vendored ProjectM hlslparser warnings,
  and AppIntents SSU artifact archive message.
- The signed `com.briangarcia.meikyo` app was installed in place on `SaiyanDenawa`; read-only `devicectl` verification
  confirms version 1.0/build 316. No uninstall occurred and Codex did not launch the physical app.
- Exact continuation: manually launch MeiKyo on SaiyanDenawa. Tap every Settings category once from both entry points,
  verify the native push/back animation and edge-swipe back, and change a representative setting to confirm persistence.
  From Playing, tap Visualizer, confirm the first-use safety notice when applicable, reveal the HUD, verify Exit is in the
  same HUD as Favorites/Banish/Browse, and confirm both Exit and double-tap dismissal work. Open lyrics over album art,
  seek, pause, and resume; confirm the panel remains until its X is pressed. Also verify artwork-tap visualizer entry,
  playback, and orientation behavior. Do not uninstall first.

## Local metadata scan publication guard — 2026-08-14

- The current checkout remains `/Users/brian/Resonance/Resonance-Alpha-3.7.4` on
  `agent/alpha-3.7.4-source` at source commit `0a34c869f7bec86d1eaf783b9264a1eef3c50711`, with the existing
  intentional dirty worktree preserved. Project defaults are MeiKyo version 1.0/build 313, while the current
  `origin/agent/alpha-3.7.4-source` ref matches that commit.
- `LibraryStore` now generation-gates full scans against targeted download/metadata refreshes and removals. A scan
  that becomes stale is discarded before catalog publication and again after its database write; it records the
  privacy-safe `library.scan.discarded` event. Replacement-download destination and remote-tag behavior are unchanged.
- `Tools/RegressionChecks.sh`, `Tools/ProjectStateCheck.sh --source-only`, `git diff --check`, and strict simulator plus
  generic-device Swift 6 preflight passed. Preflight warnings were the known no-scheme destination, vendored
  hlslparser, and AppIntents SSU archive messages; no build error occurred.
- Read-only `devicectl` state on 2026-08-14 reports `SaiyanDenwa` available and the installed
  `com.briangarcia.meikyo` bundle as version 2.1/build 307, so the current source build 313 is not the installed
  physical artifact. No install or launch was performed.
- Exact continuation: run the named concurrent FLAC metadata-save/full-scan/replacement workload against a matching
  build before claiming runtime acceptance, then update this state with the observed `library.scan.discarded` events
  and final library/database contents.

## MeiKyo local lyrics rescan — version 1.0/build 313 — 2026-08-11

- The affected audiobook could retain an earlier parsed `LyricsDocument` when its sibling `.lrc` file was replaced,
  because `LyricsStore` only reloaded on track/provider identity changes. Replacing the file with corrected timestamps
  therefore appeared to have no effect until another load path, such as a track change or relaunch, occurred.
- `PlayerController` now publishes a monotonic playback-restart identity for explicit starts/resumes and backend
  restarts, including the local gapless restart used by an active seek. `NowPlayingView` asks the shared `LyricsStore`
  to reload once for that identity; the store re-reads the app-private override and eligible local sibling file off the
  main actor, preserves override precedence, and leaves remote tracks on their existing provider/cache path.
- The restart identity is coalesced in the shared store so layered Now Playing views do not duplicate file reads. A
  paused seek is picked up when playback is started again, which is the point at which the new local file is required
  for active-line selection.
- `Tools/RegressionChecks.sh`, `git diff --check`, Swift parsing, strict simulator/generic-device preflight, signed
  arm64 Release compilation, deep strict code-signature verification, and in-place installation passed for
  `com.briangarcia.meikyo`, version 1.0/build 313. The physical app was not launched.
- Exact continuation: replace a local audiobook sibling `.lrc` with visibly different timestamps, pause/resume without
  changing tracks, and seek while playing and paused. Confirm the new active lines are used. Repeat after relaunch,
  confirm imported app-private overrides still win, and verify a remote track does not trigger a local scan. Do not
  uninstall first.

## MeiKyo Now Playing lyrics beta — version 1.0/build 312 — 2026-08-10

- The synced lyrics bubble in Now Playing uses `ScrollViewReader` to keep the active timestamped line centered as
  playback advances. Top and bottom breathing room lets the first and final lines reach the same centered position;
  plain lyrics retain normal scrolling.
- This follow-up presents the lyrics from a centered artwork panel with a 90% opaque background. A
  touch-and-hold on that button opens the system `.lrc` importer. Imported files are parsed and copied into the
  app-private `Application Support/LyricsOverrides` directory, then become available immediately and after relaunch.
- For a locally saved audiobook, `LyricsStore` checks the audio file's parent folder for a case-insensitive `.lrc`
  file with the same basename before trying the configured remote provider. The visualizer continues to consume the
  shared document and does not perform a second lookup.
- The latest build-312 UI pass uses a bounded scale/fade transition for the panel over the album artwork. The panel has
  a maximize button for a full-screen lyrics view and a restore button to return over the artwork; closing either view
  dismisses the lyrics panel.
- `Tools/RegressionChecks.sh`, `git diff --check`, Swift parsing, and strict simulator/generic-device Swift 6
  preflight passed. The signed arm64 Release build passed deep strict code-signature verification for
  `com.briangarcia.meikyo`, `MeiKyo 鳴響`, version 1.0/build 312.
- The signed follow-up was installed in place on `SaiyanDenawa` without uninstalling. `devicectl` readback confirmed
  `com.briangarcia.meikyo`, version 1.0/build 312; the legacy compatibility app remains installed as
  `com.briangarcia.Resonance.saiyandenwa`, version 2.1/build 311. Codex did not launch the physical app. Xcode emitted
  only the existing non-blocking AppIntents SSU archive warning.
- Exact continuation: manually verify a synced lyric popover,
  active-line centering, long-press `.lrc` import and relaunch persistence, audiobook sibling lookup, remote fallback,
  invalid-file handling, track changes, visualizer lyrics, and popover dismissal/reopening. Do not uninstall either
  app first.

## MeiKyo Now Playing lyrics geometry repair — version 1.0/build 312 — 2026-08-11

- The physical screenshot showed the lyrics panel displaced mostly off the left edge, with its Close and Maximize
  controls behind the transport controls. The cause was matching the entire bubble frame from the small Lyrics icon
  inside a leading-aligned three-page artwork pager; the transform could override the intended centered placement.
- `NowPlayingArtworkPager` now places the bubble in an explicit centered overlay constrained to the artwork width,
  limits the panel to the available width, clips overflow to the 260-point artwork region, and gives the pager/panel
  explicit stacking priority. The first geometry repair still left the destination coupled to the always-present Lyrics
  button, so the final repair removed matched geometry entirely; a bounded scale/fade transition now animates the panel
  without allowing the button to control its visibility, final size, or location.
- `Tools/RegressionChecks.sh`, `git diff --check`, strict simulator/generic-device Swift 6 preflight, signed arm64
  Release compilation, and deep strict code-signature verification passed. The signed app was installed in place on
  `SaiyanDenawa`; `devicectl` confirmed `com.briangarcia.meikyo`, version 1.0/build 312. Codex did not launch it.
- Exact continuation: manually open lyrics from Now Playing, confirm the panel is centered over album artwork, tap
  Maximize, Restore, and Close from both states, and verify the transport controls remain separate and responsive.
  Do not uninstall first.

## MeiKyo Now Playing lyrics visibility repair — version 1.0/build 312 — 2026-08-11

- The first geometry repair corrected the panel's frame and stacking but the physical follow-up reported that the panel
  was no longer visible. The remaining cause was the `matchedGeometryEffect` coupling between the always-present Lyrics
  button and the conditional destination bubble; the matched transition could still transform the destination away from
  its intended overlay position.
- `NowPlayingArtworkPager` now presents the lyrics bubble as a normal centered overlay with a bounded scale/fade
  transition. The panel width remains constrained to the artwork region, the pager and bubble retain explicit z-order,
  and the 90% opacity, close/maximize/restore controls, active-line centering, LRC import, and fullscreen behavior are
  unchanged.
- `Tools/RegressionChecks.sh`, `git diff --check`, strict simulator/generic-device Swift 6 preflight, signed arm64
  Release compilation, and deep strict code-signature verification passed. The signed app was installed in place on
  `SaiyanDenawa`; `devicectl` confirmed `com.briangarcia.meikyo`, version 1.0/build 312. Codex did not launch it.
- Exact continuation: manually open lyrics for a track with readable lyrics and confirm the centered panel is visible;
  close it, reopen it, test Maximize and Restore, close from both states, and verify transport controls remain separate.
  Do not uninstall first.

## MeiKyo Now Playing lyrics seek synchronization — version 1.0/build 312 — 2026-08-11

- The seek bar publishes position changes through the shared `PlaybackProgress` object, but the lyrics bubble kept a
  private elapsed value fed by a separate 250 ms timer. This could leave the highlighted line and centered scroll
  position stale after seeking, particularly while paused.
- `NowPlayingLyricsBubble` now observes `PlaybackProgress` directly and derives its active line from the published
  elapsed value. The separate lyric timer and local elapsed snapshot were removed; lyric parsing, playback seeking,
  active-line centering, and fullscreen behavior remain unchanged.
- `Tools/RegressionChecks.sh`, `git diff --check`, strict simulator/generic-device Swift 6 preflight, signed arm64
  Release compilation, and deep strict code-signature verification passed. The signed app was installed in place on
  `SaiyanDenawa`; `devicectl` confirmed `com.briangarcia.meikyo`, version 1.0/build 312. Codex did not launch it.
- Exact continuation: manually open a synced lyric file, seek forward and backward while playing, repeat while paused,
  and confirm the highlighted line and centered lyric position change to the requested timestamp immediately. Do not
  uninstall first.

## MeiKyo audiobook clock/lyrics synchronization — version 1.0/build 312 — 2026-08-11

- A fresh device diagnostics pull showed the affected audiobook using the local gapless backend with synced local
  lyrics. The remaining drift was not a lyrics-store or parser failure: `updateElapsedFromClock()` advanced the
  gapless position by wall time while `AVAudioUnitTimePitch` could play the audiobook at 0.75×–2.0×.
- The gapless clock now multiplies elapsed wall time by the effective audiobook rate. `setPlaybackRate` first captures
  the current media position and then re-anchors the clock at the new rate, preventing a discontinuity when speed is
  changed. Normal music remains at 1×; legacy and remote backends retain their media-clock behavior.
- `Tools/RegressionChecks.sh`, `git diff --check`, strict simulator/generic-device Swift 6 preflight, signed arm64
  Release compilation, and deep strict code-signature verification passed. The signed app was installed in place on
  `SaiyanDenawa`; `devicectl` confirmed `com.briangarcia.meikyo`, version 1.0/build 312. Codex did not launch it.
- Exact continuation: test the audiobook at 1×, 1.25×, and 1.5×. Seek to positions before and after several lyric
  timestamps while playing and paused, then change speed during playback and confirm the highlighted lyric follows the
  audio rather than drifting behind. Do not uninstall first.

## MeiKyo FLAC metadata writer repair — version 1.0/build 312 — 2026-08-10

- Root cause confirmed: `MetadataTagWriter.makeVorbisComments` wrote a vendor length of 9 for the rebranded `MeiKyo`
  vendor string, which is 6 bytes. The following Vorbis-comment count and fields were consequently read three bytes
  out of alignment after a FLAC metadata save, matching the reported numeric/hyphenated album, artist, and title data.
- The writer now stores `vendor.count` beside the actual vendor bytes. `Tools/RegressionChecks.sh` asserts the derived
  length and rejects the stale literal.
- `Tools/RegressionChecks.sh`, `git diff --check`, strict simulator/generic-device preflight, signed arm64 Release
  compilation, and deep strict code-signature verification passed. The signed app was installed in place on
  `SaiyanDenawa`; `devicectl` confirmed `com.briangarcia.meikyo`, version 1.0/build 312. Codex did not launch the app.
- Existing files already saved with the malformed block are not auto-repaired because their original titles cannot be
  recovered safely from the damaged tags. Restore those files from the source library or re-download them before
  retesting metadata edits.
- Exact continuation: manually restore one original `10,000 Days` FLAC, edit only its track number, save, rescan or
  relaunch, and verify with an external tag reader that the title, `Tool` artist, `10,000 Days` album, and track number
  all remain correct. Repeat on several tracks before repairing the remaining copies. Do not uninstall first.

## MeiKyo Now Playing lyrics test build — version 1.0/build 310 — 2026-08-10

- Now Playing and the fullscreen visualizer share one app-level `LyricsStore`. Now Playing loads the configured HTTPS
  lyrics provider for the current track; the visualizer consumes the same cached document rather than starting a
  second provider lookup.
- The Playing controls include a Lyrics button. It is grey and disabled when the provider returns no plain or synced
  lyrics, and gold when readable lyrics exist. Tapping it opens an opaque, scrollable album-art bubble; synchronized
  lines highlight the active timestamped line and refresh at 250 ms only while the bubble is visible.
- `LyricsDocument` now exposes readable-content and display-text helpers. Provider lookup, timing, visualizer lyrics,
  audio, presets, transitions, and renderer lifecycle remain unchanged.
- `Tools/RegressionChecks.sh`, `git diff --check`, shell syntax checks, Swift parsing, and strict simulator/generic-
  device Swift 6 preflight passed. The signed arm64 Release build passed deep strict code-signature verification.
- The app reports `com.briangarcia.meikyo`, `MeiKyo 鳴響`, version 1.0/build 310. It was installed in place on
  `SaiyanDenawa` without uninstalling; `devicectl` readback confirmed build 310. Codex did not launch the physical
  app, so button color, bubble layout, lyrics scrolling, and visualizer-sharing acceptance remain user-run.
- Xcode emitted the existing non-blocking AppIntents SSU archive warning; no build or install error remained.
- Exact continuation: launch MeiKyo manually with a configured lyrics provider. Verify a no-lyrics track shows a grey
  disabled button, a lyrics track shows gold, tapping it opens the opaque bubble over artwork, synced lines advance,
  plain lyrics scroll, and visualizer lyrics continue to work without duplicate requests or UI lockups. Do not
  uninstall the app first.

## MeiKyo lyric-layout test build — version 1.0/build 309 — 2026-08-10

- The native ProjectM lyric mesh now uses an approximately 80%-wide band instead of 68%, giving long synced verses
  more horizontal room while preserving the existing 1536×256 raster, three-row font fit, full vertical sampling,
  timing/provider behavior, entry scale, fade/feedback animation, audio, presets, transitions, and controls.
- `Tools/RegressionChecks.sh`, `git diff --check`, shell syntax checks, and the strict simulator/generic-device
  Swift 6 preflight passed. The signed arm64 Release build passed deep strict code-signature verification.
- The app reports `com.briangarcia.meikyo`, `MeiKyo 鳴響`, version 1.0/build 309. It was installed in place on
  `SaiyanDenawa` without uninstalling; `devicectl` readback confirmed build 309. Codex did not launch the physical
  app, so long-verse layout and interaction acceptance remains user-run.
- The first signed invocation omitted the required explicit Xcode scheme when using a custom DerivedData path; the
  corrected `-scheme Resonance` invocation succeeded. Xcode's existing non-blocking AppIntents SSU archive warning
  remained; no build or install error remained.
- Exact continuation: launch MeiKyo manually, configure/use lyrics, and test previously clipped long verses. Confirm
  three complete visible lyric rows with the final words retained across the wider band, then test controls, favorite,
  visualization transitions, and exit. Do not uninstall the app first.

## Local metadata and replacement-download diagnosis — 2026-08-10

- The latest legacy-bundle diagnostics show successful local metadata writes: album saves report
  `failureCount=0` with all requested files writable, and individual FLAC saves also report success.
- The same diagnostics show explicit file deletion events (`deleted=4`, then another `deleted=4`, then `deleted=10`).
  These are the app’s requested **Delete from iPhone** action, not spontaneous disappearance.
- Replacement downloads use the remote track’s `albumArtist`/`album` to construct the destination folder and download
  fresh server-provided audio. If the remote catalog calls the album `Kolm`, replacement can recreate `Kolm/Kolm` and
  restore the server’s tags, overwriting local edits by design.
- A forced full scan began at 02:48:25 UTC and completed at 02:49:51 UTC while multiple metadata saves completed.
  `scanDocuments` can publish its accumulated `tracks` array after those targeted writes, replacing the newer targeted
  library state with a stale scan result. Foreground activation also intentionally trusts the cached database after
  bootstrap, so external file edits are not automatically reread.
- No source fix was applied during this diagnosis. The next implementation should generation-gate stale scan
  publication, coordinate scans with targeted metadata/download refreshes, surface background-save failures, and
  document that replacement downloads follow remote metadata unless a preserve-local-tags policy is added.

## LRCLIB search-first fallback — legacy compatibility build 311 — 2026-08-09

- Device diagnostics from legacy build 309 confirmed that the provider profile was correct and that the duration
  fallback was active, but Mycelia still ended `lyrics.lookup.completed found=false synced=false` on build 310. The
  user reported the phone album as `Yugen (24 Bit)`; the matcher already normalizes that against LRCLIB’s
  `Yūgen (24 bit)` form, so the album suffix was not itself a mismatch.
- `LyricsService` now derives a search endpoint from a user-configured GET profile named LRCLIB when its endpoint path
  ends in `/get`. It now tries that corresponding `/search` endpoint first, avoiding a burst of near-duplicate
  `/get` requests; if search does not produce a match, the original exact and ±5-second duration sequence remains.
  The search accepts only a result whose normalized title and artist, optional album, and duration match. No LRCLIB
  endpoint is enabled by default; other providers, POST profiles, and current-track-only behavior are unchanged.
- The live search oracle returned one `Mycelia / Kolm / Yūgen (24 bit)` result for the combined metadata query, with
  synced lyrics and duration 534 seconds; that is within five seconds of the phone track’s 529.846-second duration.
- `swiftc -parse Resonance/Services/LyricsService.swift`, `Tools/RegressionChecks.sh`, `git diff --check`, and
  `Tools/ProjectStateCheck.sh --source-only` passed. `Tools/PreflightBuild.sh` passed; its only actionable output was
  the known non-blocking AppIntents SSU archive warning.
- The source was built with temporary legacy-bundle overrides as version 2.1/build 311. The signed app passed deep
  strict code-signature verification and was installed in place on SaiyanDenawa as
  `com.briangarcia.Resonance.saiyandenwa`; the separate `com.briangarcia.meikyo` build 307 remains installed. No
  physical launch was performed.
- Exact continuation: manually launch the legacy-bundle app, play **Mycelia**, and verify synchronized lyrics appear.
  Then test an exact match, a duration-tolerance match, a same-title wrong-artist/album case, a no-match case, and
  provider cancellation/rate limiting.

## Lyrics duration-tolerance follow-up — legacy compatibility build 309 — 2026-08-09

- `LyricsService` now tries the configured provider with the exact rounded track duration first, then sequentially
  retries -1/+1 through -5/+5 seconds when the response is a 404 or contains no usable lyrics. This addresses
  provider-side rounding or encoder-duration differences without changing the provider profile, response parsing,
  cancellation, or in-memory cache behavior.
- The known `Kolm` / `Yugen` / `Mycelia` LRCLIB record demonstrates the failure this covers: the service returns 404
  for the exact 529-second `/api/get` request but returns the record for a nearby duration.
- A live endpoint smoke check reproduced that result on 2026-08-09: duration 529 returned HTTP 404, while duration
  528 returned HTTP 200 with LRCLIB record 37666721.
- `swiftc -parse Resonance/Services/LyricsService.swift`, `Tools/RegressionChecks.sh`, `Tools/ProjectStateCheck.sh
  --source-only`, `git diff --check`, and `Tools/PreflightBuild.sh` passed. The preflight log is
  `/Users/brian/Resonance/Resonance-Alpha-3.7.4/preflight-lyrics-duration-tolerance.log`.
- The source was built with temporary overrides `PRODUCT_BUNDLE_IDENTIFIER=com.briangarcia.Resonance.saiyandenwa`,
  `MARKETING_VERSION=2.1`, and `CURRENT_PROJECT_VERSION=309` so it replaced the old Resonance app identity without
  changing the public MeiKyo project defaults. The signed app passed deep strict code-signature verification and was
  installed in place on SaiyanDenawa without uninstalling or launching. `devicectl` verified the legacy bundle at
  version 2.1/build 309; the separate MeiKyo bundle remains installed at build 307.
- The already-uploaded MeiKyo 1.0/build 308 App Store archive does not contain this change. Physical runtime lyric
  acceptance remains pending.
- Exact continuation: manually play a previously failing Kolm track and verify synced lyrics appear. Then test an
  exact-duration match, a ±1–5-second match, a no-match track, cancellation during lookup, and a provider rate-limit
  response.

## MeiKyo full release — version 1.0/build 308 — 2026-08-09

- Settings renames **Prototype Status** to **App Feature List**. The existing feature inventory remains intact, while
  the prototype stage-completion label, percentage, progress bar, and prototype-coverage disclaimer were removed.
  The Settings version description is now the plain marketing/build value rather than a `Beta` label.
- External API User-Agent defaults now identify the release as `MeiKyo/1.0`; public telemetry remains compiled out.
- `Tools/RegressionChecks.sh` passed with the project defaults at marketing version 1.0 and build 308. The strict
  simulator and generic-device preflight also passed with Swift 6 strict-concurrency and warnings-as-errors settings.
- The signed archive `/Users/brian/Downloads/MeiKyo-1.0-build-308-AppStore.xcarchive` reports bundle
  `com.briangarcia.meikyo`, display name `MeiKyo 鳴響`, product name `MeiKyo`, `CFBundlePackageType = APPL`, version
  1.0/build 308, and iOS 17.0 minimum. Deep strict code-signature verification passed.
- Xcode exported and uploaded the archive with automatic App Store signing. App Store Connect reported `Upload
  succeeded` and that the package is processing. No physical-device installation or launch was performed.
- The verified Debug simulator bundle was installed and launched on the newer available iPhone 17 Pro Max
  simulator (`9C36F09D-F9B0-4C48-B09D-17F41A32FEE5`). The app reported MeiKyo 鳴響, version 1.0/build 308, and a
  screenshot confirmed the running Library surface. This is simulator evidence only; no physical device was changed.
- For App Store Connect's 6.5-inch screenshot class, a new iPhone 14 Plus simulator was created and launched
  (`924133FD-B515-418F-993A-A497DBD10961`). It runs MeiKyo 1.0/build 308 and produces the accepted portrait size
  1284×2778. The current capture shows the first-use privacy sheet; dismiss the simulator notification banner before
  using captures as store screenshots.
- The first archive attempt failed only because Xcode's default DerivedData path made a generated projectM object
  filename exceed the filesystem path limit. Repeating the same archive with `/tmp/meikyo-308-dd` as the explicit
  DerivedData path succeeded. Existing vendored projectM/hlslparser warnings and the non-blocking AppIntents SSU
  artifact message did not prevent validation or upload.
- Exact continuation point: wait for Apple processing to finish, confirm version 1.0/build 308 is selectable in the
  MeiKyo App Store Connect record, then complete export-compliance, metadata, screenshots, privacy, and App Review
  information before submitting the release. Manually test the App Feature List and first-use/privacy/About flow on a
  device or simulator before submission.

## MeiKyo App Store Connect upload — build 307 — 2026-08-09

- The explicit App ID `com.briangarcia.meikyo` and the App Store Connect app record were created for the public
  **MeiKyo 鳴響** identity. Xcode automatic signing now persists development team `98CWMFS26R` and automatic
  provisioning at the target and Debug/Release configuration levels.
- The first App Store Connect upload was rejected before delivery because the generated application plist omitted
  `CFBundlePackageType`. The source plist now explicitly contains `CFBundlePackageType = APPL`.
- The corrected Release archive `/Users/brian/Downloads/MeiKyo-2.1-build-307-AppStore-v2.xcarchive` passed plist
  validation and deep strict code-signature verification. Xcode exported with `method = app-store-connect`,
  `destination = upload`, and automatic signing; App Store Connect accepted the package and reported that it is
  processing. No phone installation or launch was performed.
- Known non-blocking warnings during the build were the existing empty supported-platforms destination warning and
  vendored projectM/hlslparser format/deprecated-`sprintf` warnings. They did not block the archive or upload.
- Next continuation point: wait for App Store Connect processing, answer export-compliance questions if presented,
  select the processed build under TestFlight, and complete the remaining app metadata before any review submission.

## MeiKyo 鳴響 product identity and bundle change — build 307 — 2026-08-09

- The public app identity is now **MeiKyo 鳴響** with bundle identifier `com.briangarcia.meikyo` and product name
  `MeiKyo`. The repository, Xcode project/target name, source namespace, compatibility keys, diagnostic filenames,
  server protocols, and historical records remain Project Resonance intentionally.
- Visible app branding now uses MeiKyo in the launch metadata, permission explanations, privacy-consent sheet, About
  section, Settings warnings, App Intents, artwork notices, and user-facing accessibility/status text. External API
  User-Agent/client identification now uses MeiKyo while retaining the Resonance GitHub project URL.
- Build 307 is the first source build with the new identity and preserves the public no-telemetry behavior. The phone
  remains on the prior bundle `com.briangarcia.Resonance.saiyandenwa` build 305; no reinstallation or launch was done.
  Because the bundle identifier changed, the next MeiKyo install is a new app identity rather than an in-place update.
- Source-contract regression checks passed after the rename. Strict simulator/generic-device preflight, signed
  archives, and App Store Connect upload validation passed for bundle `com.briangarcia.meikyo`.

## Builds 305/306 privacy consent, About information, and telemetry split — 2026-08-09

- Settings now ends with an About category describing Resonance, the projectM/MilkDrop visualizer, LGPL-2.1 and
  preset licensing context, network services, and the public privacy-policy URL.
- A non-dismissible first-use privacy-policy sheet requires the user to open/review the policy and check an
  acknowledgment before **Agree and Continue** becomes available. Active app refresh work waits for that consent;
  later launches do not repeat the sheet.
- The telemetry test build uses the `RESONANCE_TELEMETRY` compilation condition and the private bearer-token build
  setting. Public builds omit that condition, cannot submit telemetry, hide the telemetry setting, and use a privacy
  manifest without collected performance data. The selector keeps the internal manifest accurate for test builds.
- Build 305 was archived, signed, installed in place on SaiyanDenawa, and verified as version 2.1/build 305. Build 306
  was archived and verified as version 2.1/build 306 with an empty telemetry token and no public performance-data
  declaration. Both archives passed deep strict code-signature verification. Neither build was launched by Codex.
- Manual continuation: launch build 305 on the phone, verify the first-use consent sheet, Settings → About, and the
  internal telemetry control. The public build remains saved for later distribution signing and was not installed.

Artifacts:

- `/Users/brian/Downloads/Resonance-2.1-build-305-telemetry-test.xcarchive`
- `/Users/brian/Downloads/Resonance-2.1-build-306-app-store-final.xcarchive`

## Build 304 persistent-folder access fix — 2026-08-09

- Build 303 rejected a valid Files folder because `configurePersistentMusicFolder` called `standardizedFileURL` before
  `startAccessingSecurityScopedResource()`. Build 304 preserves the exact picker URL and bookmark-resolved URL for
  security-scoped access, coordination, bookmark creation, and active-root operations; standardized paths are used
  only for comparisons.
- Strict simulator/generic-device preflight, signed arm64 Release compilation, and deep strict code-signature
  verification passed. Build 304 was installed in place on SaiyanDenawa as version 2.1/build 304 without launch.
- Exact manual test: choose `On My iPhone → Music` outside Resonance’s own app folder, confirm the persistent-folder
  connection and migration, then test scans, playback, imports, downloads, metadata/artwork writes, removal, and
  relaunch. iCloud Drive and delete/reinstall recovery remain separate user-run tests.

## Build 303 coordinated external-folder access — 2026-08-09

- `ExternalFileCoordinator.swift` wraps external-folder reads and writes with `NSFileCoordinator`. Library migration,
  user imports, inventory scans, metadata/artwork tag writes, remote download finalization, duplicate checks, and
  file deletion now arbitrate with Files, iCloud Drive, and other File Provider implementations.
- Operations remain off the main actor where they were already background work; the active security-scoped bookmark
  remains held for the selected persistent folder. App-container settings, databases, and artwork sidecars remain
  internal app data and are not coordinated with the user-owned folder.
- Build 303 source and strict simulator/generic-device preflight passed. Signed arm64 Release compilation and deep
  strict code-signature verification passed, and build 303 was installed in place on SaiyanDenwa as version 2.1/build
  303 without launch. The full regression script still stops at the unrelated existing Streaming `.frame(width: 24)`
  assertion. User-run external-provider/reinstall acceptance is the continuation point.

## Build 302 persistent local-library storage — 2026-08-09

- Settings adds **Music Library Storage** with a Files-folder picker. The selected user-owned folder becomes the local
  library root for scans, imports, remote downloads, direct metadata/artwork writes, and file-removal actions.
- Selecting a persistent folder copies the current app-container `Resonance Music` contents into it without deleting
  the original, preserving all existing subfolders and giving the user a recoverable migration path. The Finder
  File Sharing folder is now labeled legacy temporary storage because iOS deletes the app container when Resonance is
  deleted.
- The iOS bookmark is stored in Keychain and resolved at launch; the app maintains its security-scoped access while
  the selected folder is active. If iOS invalidates the authorization, Settings provides the same folder picker again.
- Build 302 has not been installed on the physical phone. The source implementation passed Swift 6 parsing, plist
  checks, strict simulator/generic-device preflight, signed arm64 Release compilation, and deep strict code-signature
  verification. Manual persistent-folder, reinstall, download, metadata, and removal acceptance remain required.

## Build 301 lyrics-provider QR setup — 2026-08-09

- Settings now places a QR scanner beside **Enable user-configured lyrics service**. Scanning a version-1
  `resonance.lyrics.provider` JSON profile fills the enabled state, service name, HTTPS endpoint, GET/POST JSON choice,
  JSON/LRC response format, title/artist/album/duration parameter names, plain/synchronized response paths,
  authorization mode/name/token, and User-Agent. The token continues through the existing Keychain-backed setting and
  is not logged.
- The profile is rejected unless its type/version are recognized, the endpoint is HTTPS with a host, enum values are
  valid, JSON response paths are present for JSON providers, and required authorization fields are complete.
- LRCLIB profile example:

  ```json
  {"type":"resonance.lyrics.provider","version":1,"enabled":true,"name":"LRCLIB","endpoint":"https://lrclib.net/api/get","requestMethod":"get","responseFormat":"json","titleParameter":"track_name","artistParameter":"artist_name","albumParameter":"album_name","durationParameter":"duration","plainResponsePath":"plainLyrics","syncedResponsePath":"syncedLyrics","authorizationMode":"none","authorizationName":"","token":"","userAgent":"Resonance/2.1 (https://github.com/thnikkaman/Resonance)"}
  ```

- Focused source assertions, `git diff --check`, plist validation, strict simulator and generic-device preflight,
  signed arm64 Release build 2.1/build 301, and deep strict code-signature verification passed. The phone remains on
  build 300; build 301 was not installed or launched.

## Build 300 visualizer-exit crash fix — 2026-08-09

- `ProjectMFullscreenGLView.Coordinator.stop()` now detaches the FPS and low-FPS SwiftUI callbacks before native
  teardown and calls `resetFPSCounter(notify: false)`. Exiting fullscreen therefore cannot write `@State` during
  `UIViewRepresentable.dismantleUIView`; active rendering still receives the once-per-second FPS updates.
- Focused source assertions, `git diff --check`, plist validation, strict simulator and generic-device preflight, signed
  arm64 Release compilation, deep strict code-signature verification, and in-place installation passed. Build 300 is
  installed on SaiyanDenawa as `com.briangarcia.Resonance.saiyandenwa`, version 2.1/build 300; the app was not launched.
- The full regression script still stops at the unrelated existing `preservingArtworkOverride` assertion. Physical exit,
  reopen, and FPS-counter runtime acceptance remain the next manual test.

## Build 299 visualizer-exit crash diagnosis — 2026-08-09

- Fresh `systemCrashLogs` from SaiyanDenawa contain matching Resonance `SIGABRT` crashes for build 298 at 09:57:40
  and build 299 at 10:13:40. Both fault on the main thread in Swift exclusivity enforcement:
  `State.wrappedValue.setter` → the `ProjectMFullscreenView.body` FPS callback closure →
  `ProjectMFullscreenGLView.Coordinator.stop()` → `UIViewRepresentable.dismantleUIView`.
- The current source path is `ProjectMFullscreenView.swift`: the FPS callback writes `displayedFPS`, while
  `Coordinator.stop()` calls `resetFPSCounter(notify: true)`, which invokes that callback with `nil` during SwiftUI
  view-graph destruction. This is a SwiftUI state mutation during teardown, not an OpenGL, audio, telemetry, or
  bearer-token failure.
- The app diagnostics show orderly native renderer teardown immediately before the process restart:
  `projectm.display.stop` → `projectm.native.destroy`. The targeted crash evidence is under
  `diagnostics/build299-system-crashes/` and the fresh app log is `diagnostics/Resonance-Diagnostics-build299-exit.log`.
- No source change or reinstall was performed during this diagnosis. The next fix must prevent the teardown path from
  notifying the SwiftUI FPS state after the view has begun dismantling, while preserving the counter’s once-per-second
  updates during active rendering.

## Visualizer telemetry, FPS counter, and first-use safety gate — build 299 — 2026-08-09

- Settings → Visualizer now offers **Share anonymous visualizer diagnostics**, disabled by default. When enabled,
  the app posts one bounded JSON event at a time to `https://music.koolkidz.us/resonance/telemetry/events`.
- The deployed API contract is one JSON event per `POST`, with `eventId`, `presetId`, `visualization`,
  `banishmentReason`, `fps`, `frameGapMilliseconds`, `appBuild`, `osMajor`, and `occurredAt`; it requires the server
  bearer token supplied through the private `VISUALIZER_TELEMETRY_BEARER_TOKEN` build setting and returns 202 on
  persistence. No track names, lyrics, credentials, configured server URLs, account/device identifiers, or audio are
  included. The server stores no IP address or forwarded headers according to the updated server handoff.
- `VisualizerTelemetryService` is an actor with a bounded in-memory queue. The enqueue is scheduled only after the
  existing automatic low-framerate banishment boundary; URLSession work never runs in the display callback or blocks
  controls, rendering, audio, downloads, or preset selection. Manual banishment is not submitted. Each event keeps a
  stable UUID across retries for the server’s `INSERT OR IGNORE` idempotency behavior; builds without a provisioned
  bearer token silently skip upload.
- `Resonance/PrivacyInfo.xcprivacy` now declares opt-in performance data collected for App Functionality, not linked to
  a user and not used for tracking. The App Store questionnaire and privacy-policy draft describe the new destination
  and remain conditional on confirming the server’s retention and access practices.
- Settings also offers **Show FPS counter**, disabled by default. The fullscreen renderer counts presented frames in a
  one-second window and publishes only one rounded number per second to a plain, borderless upper-right text overlay;
  it does not publish per-frame SwiftUI state or display response/frame-time metrics.
- The first attempt to open fullscreen ProjectM now presents a non-dismissible safety sheet with a checkbox covering
  photosensitivity/seizure risks and stop-use symptoms. Continue is disabled until the user checks the acknowledgment;
  Cancel leaves the visualizer closed. The acknowledgment is persisted in AppStorage and the renderer does not start
  before the user continues.
- Build 298 was the tokenless baseline. Build 299 is the private token-provisioned follow-up; it passed signed
  validation and was installed in place on SaiyanDenawa as `com.briangarcia.Resonance.saiyandenwa`, version 2.1/build
  299. The app was not launched.

## User-configured lyrics and Visualizer Settings — build 294 — 2026-08-09

- The active lyrics implementation no longer contains or calls a built-in LRCLIB endpoint. A fresh install has the
  provider disabled, and fullscreen lyrics remain inactive until the user enables and completes a provider profile.
- Settings now supports a user-configured HTTPS lyrics service with GET or POST/JSON requests, configurable title,
  artist, album, and duration field names, plain LRC/text or JSON responses, dot-separated JSON response paths, and
  no, bearer, custom-header, or query-parameter authorization. The optional API token is stored in the Keychain and
  is never written to diagnostics or source-controlled documentation. This supports documented providers with these
  interfaces; OAuth, signed requests, proprietary SDKs, and other provider-specific protocols still need an adapter.
- ProjectM lyric loading consumes the configured provider through `AppSettings`; disabling or clearing the provider
  prevents network work and clears the current in-memory lyric document. Existing native MilkDrop rendering and
  visualizer controls remain unchanged.
- Settings places the new Visualizer category exactly between Finder File Sharing and Reported Errors. It exposes the
  persisted ProjectM/MilkDrop lyrics, auto-cycle, shuffle, and frame-diagnostics controls and documents staged,
  one-at-a-time catalog loading, low-framerate auto-banish, and privacy-safe manual/automatic diagnostics.
- Prototype Status now lists the complete 9,795-entry catalog, staged loading, rotation, favorites/banishment,
  low-framerate auto-banish, native synchronized lyrics, configurable lyrics providers, and visualizer diagnostics.
- Validation passed focused source assertions, Swift 6 parsing, `git diff --check`, ProjectStateCheck, strict
  simulator and generic-device preflight, signed arm64 Release build 2.1/build 294, bundle identity inspection,
  active-endpoint inspection, and deep strict code-signature verification. Xcode emitted the existing vendored
  hlslparser warnings and non-blocking AppIntents SSU archive warning. The full regression script still stops at
  the unrelated existing `preservingArtworkOverride` assertion. Build 294 was installed in place on SaiyanDenwa as
  `com.briangarcia.Resonance.saiyandenwa`, version 2.1/build 294; the app was not launched.

## First-use MusicBrainz artwork notice — 2026-08-09

- The first manual opening of Online Artwork Search now presents an OK-only notice before any MusicBrainz or Cover Art
  Archive request begins. The acknowledgment persists in `AppSettings` and the existing search/download flow then
  continues unchanged; later manual searches do not repeat the notice.
- The notice identifies MusicBrainz as the metadata source and Cover Art Archive as the image source; explains the
  meaningful User-Agent and one-request-per-second requirements, MusicBrainz core/supplementary licenses, commercial
  use caveat, provider network disclosure, and the user’s responsibility for artwork rights.
- Automatic Streaming artwork fallback remains unchanged and does not present an interruptive alert.
- Source build is 2.1/293. This is a product disclosure, not a provider contract or legal opinion.

## Streaming private-use warning — 2026-08-09

- Settings → Streaming Library now displays a prominent legal-use notice stating that Streaming is intended only for
  private, non-commercial use with music the user lawfully purchased or otherwise lawfully acquired and is legally
  entitled to access, play, and stream.
- The notice assigns responsibility for required licenses, permissions, server content, and compliance with applicable
  law to the user; it does not grant content rights or change streaming behavior, server validation, credentials, or
  download behavior.
- Source build is 2.1/292. This is product warning language, not a legal opinion or substitute for publisher counsel.

## HTTPS-only remote servers — 2026-08-09

- Configured Navidrome/Subsonic and Resonance Manifest servers now require HTTPS. Bare hostnames are normalized to
  `https://`; explicit `http://` input is rejected in typed settings and QR configuration.
- Generated manifest, stream, artwork, API, playback, and download URLs are independently checked so a server response
  cannot downgrade a remote request to HTTP. Existing cached manifest entries are sanitized on restore.
- The global `NSAllowsArbitraryLoads` and local-network ATS exceptions were removed from `Resonance/Info.plist`.
  `NSLocalNetworkUsageDescription` remains because the app still explains its configured server access to the user.
- The tested review endpoint is `https://music.koolkidz.us`. The included development companion server remains HTTP-only
  and is not a valid endpoint for this HTTPS-only app unless placed behind a TLS reverse proxy.
- Current review-network topology is Caddy HTTPS at `music.koolkidz.us` forwarding privately to Navidrome at
  `192.168.1.7:4533`; FortiWiFi has no public VIP or WAN policy for port 4533. The live Navidrome binding supersedes
  the older `0.0.0.0` memory note.
- Focused HTTPS contract, `git diff --check`, strict simulator/generic-device preflight, signed Release build 2.1/291,
  compiled ATS inspection, and deep code-signature verification passed. The user reports physical-device acceptance:
  `http://` is rejected and `music.koolkidz.us` works over HTTPS. The installed build identity was not independently
  verified in this acceptance report.

## Build 290 lyric crop follow-up — 2026-08-09

- The supplied phone screenshots showed long synced lyric lines wrapping to a third row while the native MilkDrop
  lyric mesh sampled only the center 75% of its raster (`VerticalClip = 0.75f`). The lyric service and rasterizer still
  contained the final words; the mesh discarded the lower wrapped row.
- The current source changes only `MilkdropText.cpp`'s vertical texture coverage to `1.0f`, preserving the existing
  1536×256 raster, font fitting, timing, animation warp, feedback burn, preset rendering, audio, and lyrics parsing.
- The two supplied examples are the behavior oracle: the previously absent final words must appear after the change.
  No phone install or launch was performed; physical acceptance remains the user's test.
- The equivalent workload manifest and proof are under
  `/Users/brian/Resonance/Resonance-Alpha-3.7.4/evidence/projectm-lyrics-last-word-round-12`.

## App Store readiness documentation — 2026-08-08

- Added `Resonance/PrivacyInfo.xcprivacy` to the Resonance target resources. It declares the required-reason API
  categories used by the current app: app-container file timestamps, elapsed-time/system boot-time timing, and
  app-only UserDefaults. Tracking is declared false; collected-data declarations remain a separate App Store
  Connect decision based on remote-server ownership and retention.
- Added `Docs/PRIVACY-POLICY.md`, `Docs/APP-PRIVACY-QUESTIONNAIRE.md`, and
  `Docs/APP-REVIEW-SERVER-SETUP.md`. They contain no credentials, authenticated URLs, private music, or signing
  material. The policy is a publication draft with placeholders for the publisher, contact, deletion procedure, and
  provider-rights decisions.
- This pass intentionally changed no ATS exceptions, Finder file-sharing keys, remote endpoints, credential storage,
  lyrics/artwork behavior, ProjectM behavior, playback behavior, or device state. Public review access must use
  HTTPS at `music.koolkidz.com` and must not require Tailscale membership.
- Source checkout: `agent/alpha-3.7.4-source`, project default `2.1/291`, Xcode 26.6 / iOS SDK 26.5. Physical-device
  launch and runtime acceptance were not performed for this documentation change.

## Provider policy and iTunes removal — 2026-08-08

- The active online artwork implementation now uses MusicBrainz release-group metadata and Cover Art Archive images
  only. The iTunes Search API request code, response models, source label, and current settings disclosure were
  removed. Historical README entries retain their original release notes and are not active provider behavior.
- MusicBrainz API compliance now includes a meaningful `Resonance/2.1` User-Agent with the project URL and an actor
  gate that serializes MusicBrainz requests to no more than one call per second across concurrent artwork searches.
- LRCLIB requests identify Resonance with a project URL and retry one `429` response only after honoring its numeric
  `Retry-After` value. Lyrics lookup remains one current-track request at a time and does not scan the library.
- Current provider decision: LRCLIB exposes an open, no-key API but its published API documentation does not grant a
  clear commercial lyric-content license; MusicBrainz says non-commercial API use is free but commercial use requires
  its commercial plans or contact, and MusicBrainz supplementary data is CC BY-NC-SA 3.0; Cover Art Archive says use
  its images at the user’s own risk and respect artist/label rights. These are release-gating legal/terms decisions,
  not claims that public endpoints license all returned content.

## Current ProjectM lyric horizontal-fit repair — build 290 source

- Build 290 widens the lyric raster canvas from 1024 to 1536 pixels and the native display band from `0.44` to
  `0.68`, preserving a controlled size below the original title mesh. The MilkDrop entry scale is capped at `1.0`
  so the first lyric animation cannot move the fitted final word off-screen.
- The existing full 9,795-entry staged catalog remains unchanged: its background actor owns the index and fullscreen
  state retains only the focused fixtures plus one active archive preset.
- Build 290 passed strict simulator/generic-device preflight, signed arm64 Release compilation, and deep strict
  signature verification. The artifact is ready for an explicitly requested in-place phone install; Codex did not
  install or launch it.
- Banish telemetry remains a planned follow-up: current logs distinguish manual and automatic events but use unstable
  process hashes instead of recoverable preset IDs.
- Evidence: `/Users/brian/Resonance/Resonance-Alpha-3.7.4/evidence/projectm-lyrics-horizontal-round-11` and
  `/Users/brian/Resonance/Resonance-Alpha-3.7.4/signed-projectm-lyrics-horizontal-device-290.log`.

## Current ProjectM full-catalog staged rotation — build 289 in place

- The first build-289 catalog implementation was rejected because all 9,795 archive entries were attached to live
  fullscreen state; physical testing reported the old lock returning and the log showed repeated 100–190 ms gaps.
- The completed implementation keeps the full 9,795-entry index in `ProjectMPresetCatalogStore`, a background actor.
  The fullscreen view retains only the focused startup fixtures and the one currently selected archive item. Every
  automatic or swipe advance asks the actor for one next preset; projectM loads only that item, and archive changes
  remain hard cuts.
- Browse uses the same actor-owned catalog and no longer performs a second archive scan. The native lyric mesh remains
  half-width (`0.88` → `0.44`) in `MilkdropText.cpp`.
- Strict simulator and generic-device preflight, signed arm64 Release compilation, deep strict signature verification,
  in-place installation, and `devicectl` verification passed for Resonance `2.1/289` on SaiyanDenawa. Codex did not
  launch the physical app. The full regression script still stops at its unrelated existing artwork assertion.
- Physical continuation: launch the installed build and confirm automatic rotation reaches archive presets, controls/
  Favorite remain responsive, lyric text is half-size, and Browse still reports/searches the complete catalog. Pull
  fresh credential-free diagnostics after the run.
- Evidence: `/Users/brian/Resonance/Resonance-Alpha-3.7.4/signed-staged-full-catalog-device-289.log` and
  `/Users/brian/Resonance/Resonance-Alpha-3.7.4/preflight-staged-full-catalog.log`.

## Current ProjectM standalone-parity catalog repair — build 288

- Fresh build-287 physical diagnostics showed Resonance still rotating full Cream of the Crop preset paths, unlike
  standalone ProjectMD build 42, which the user reports is flawless after narrowing live rotation to ten focused
  MilkDrop3 fixtures.
- The build-287 log contained 84 `projectm.frame.stall` events with 183.4 ms p50 and 445.4 ms p95 gaps. The selected
  source lever is to return Resonance's focused fixture list directly and stop enumerating the 9,795 additional native
  presets in the ordinary fullscreen path.
- Build 288 passed strict simulator and generic-device preflight, signed arm64 Release compilation, deep strict
  signature verification, and in-place installation. `devicectl` verified Resonance `2.1/288` alongside ProjectMD
  `0.2.0/42`. No ProjectM renderer, audio, lyrics, download, or persistence code was otherwise changed. Physical
  device acceptance remains required.

## Current ProjectM main-run-loop budget repair — build 287 installed

- The build-286 GLKView framebuffer refresh hypothesis is disproven. After the user tested build 286 with downloads
  stopped and music paused, the fresh diagnostics contained no new `projectm.frame.gl_error`, framebuffer-preexisting,
  or incomplete-target events and the interaction behavior was unchanged.
- The confirmed common cause remains synchronous ProjectM rendering from `glkView(_:drawIn:)` on the main run loop.
  Normal frames measured approximately 23–26 ms at the prior 0.75 drawable scale, while pathological presets in the
  earlier logs blocked the run loop for approximately 183–400 ms. That explains the apparent lock during controls,
  favorites, and preset transitions without requiring audio or downloads.
- Build 287 keeps a fixed 0.5 drawable scale to bound ProjectM's pixel workload and stops auto-banish from tearing down
  and recreating the GLKView/bridge during a low-FPS decision. Preset changes now stay within the existing renderer
  lifecycle, reducing interaction-time lifecycle churn while preserving the audio and lyrics paths.
- Swift 6 simulator and generic-device preflight, signed arm64 Release compilation, deep code-signature verification,
  and in-place installation passed. `devicectl` verified Resonance `2.1` / build `287` on SaiyanDenawa. Codex did not
  launch the physical app.
- Exact continuation point: manually open ProjectM on build 287 with downloads stopped and music paused. Reveal/hide
  controls repeatedly, tap Favorite, switch presets several times, use Banish, and dismiss/reopen fullscreen. Report
  whether controls respond immediately and whether the visualization remains fluid. Retrieve a fresh diagnostics log
  after the run so render windows and frame stalls can be compared against build 286.

## Current common ProjectM hot-path repair — build 286 reinstalled

- Physical testing of the reinstalled build 286 reproduced the lockup immediately after the fullscreen controls
  appeared. The latest log shows normal ProjectM timing immediately before `projectm.controls.toggle`, then no later
  display-window records in the hung interval; the earlier lyric-observer repair was therefore insufficient.
- The common Resonance-only cause is the PCM staging boundary: Resonance drained the entire pending audio backlog into
  `projectm_pcm_add_float` on each main-thread render, while standalone ProjectMD submits one bounded 480-frame
  visualization window. Backlog size could therefore increase render cost, heat the phone, starve SwiftUI controls,
  and collapse the visualizer into 2–5 FPS.
- The source repair keeps the bounded ring for recent audio but discards stale samples before each render and submits
  at most the same 480-frame window as ProjectMD. Playback audio, queue behavior, and ProjectM visual quality inputs
  remain unchanged; only stale visualization backlog is discarded.
- The bounded-PCM source was rebuilt, deep-signature verified, and installed in place as Resonance 2.1/build 286 on
  SaiyanDenawa. The app was not launched by Codex. The continuation point is a no-download manual test of heat,
  continuous frame rate, controls, preset switching, and dismissal, followed by a fresh diagnostics pull.

## Current no-download ProjectM control-lock repair — build 286 reinstalled

- The latest no-download device log showed ProjectM rendering near its normal cadence during control use and preset
  switches: approximately 6–18 ms render times, 120-frame windows, and no sustained frame gaps. This rules out the
  native renderer or preset shader as the primary cause of the interaction lockup in that reproduction.
- Resonance still embedded a zero-size `ProjectMLyricsFeedHost` that observed `PlaybackProgress` every 120 ms. That
  high-frequency SwiftUI observation is not present in standalone ProjectMD and can compete with the fullscreen
  controls and preset handoff on the main run loop.
- The source repair removes that `PlaybackProgress` observation and anchors lyric timing from `PlayerController` on a
  250 ms main timer; `ProjectMLyricsFeed` continues to interpolate between anchors. Playback, audio submission,
  ProjectM rendering, preset loading, and download transfer behavior are unchanged.
- Strict simulator and generic-device Swift 6 preflight, signed arm64 Release compilation, deep code-signature
  verification, and in-place installation passed after the repair. `devicectl` verified Resonance `2.1` / build `286`
  on SaiyanDenawa. Codex did not launch the physical app. The continuation point is manual no-download testing of
  control reveal/hide, lyrics, playback, preset switches, and dismissal on SaiyanDenawa.

## Current ProjectM/download progress isolation repair — build 286

- Current working source is Resonance Beta `2.1` / build `286` on `agent/alpha-3.7.4-source`; committed rollback point
  `0a34c869f7bec86d1eaf783b9264a1eef3c50711` and the intentional uncommitted ProjectM/build-283–285 work remain
  preserved.
- Fresh build-285 device diagnostics showed 23 `projectm.frame.stall` events in the latest reproduction with a 403.8 ms
  median gap and 394.8–481.6 ms range. The same log showed inexpensive native render/lyric work and active background
  downloads, proving display-link starvation rather than a 400 ms ProjectM render cost.
- Build 285 successfully reduced 10,745 raw background progress callbacks to 767 publications across the available
  log, but each accepted publication still changed multiple `RemoteDownloadManager` values and rewrote the complete
  `itemProgress` dictionary and `downloadQueue` array on `@MainActor`.
- Build 286 applies one lever: byte progress is published through `RemoteDownloadLiveProgress`, while the manager's full
  queue collections publish only at track-state boundaries. The compact banner and expanded active row consume the
  narrow publisher and retain the existing 400 ms visible cadence.
- Network requests and bytes, one-file background concurrency, stable IDs and queue order, cancellation, requeue,
  resume, replacement decisions, persistence, completed-file handling, metadata parsing, deferred library refresh,
  playback, ProjectM quality, audio submission, lyrics, and transitions are unchanged.
- Equivalent workload manifests and ranked opportunities are under
  `/Users/brian/Resonance/Resonance-Alpha-3.7.4/performance-evidence/background-download-projectm-round-07`.
- Focused contracts, Swift parsing, `git diff --check`, workload equivalence, strict Swift 6 simulator and generic-device
  preflight, signed arm64 Release compilation, and deep strict code-signature verification passed. The full regression
  script reaches the unrelated existing Streaming alphabet assertion at line 196. Existing vendored hlslparser warnings
  and the non-blocking AppIntents SSU archive message remain.
- Build 286 installed in place on SaiyanDenawa. `devicectl` verified bundle
  `com.briangarcia.Resonance.saiyandenwa`, version `2.1`, build `286`. Codex did not launch the physical app.
- Exact continuation point: manually launch build 286 while the same large local-LAN batch is downloading. Keep the
  queue collapsed, open ProjectM for at least 20 seconds, and confirm normal interaction and frame rate. Then close
  ProjectM, expand the queue, verify byte progress and the active row advance, and test one cancel/requeue. If ProjectM
  still stalls, retrieve the fresh diagnostics before another code change so completion-boundary work can be measured
  separately.

## Current background-download energy repair — build 285

- Current working source is Resonance Beta `2.1` / build `285` on `agent/alpha-3.7.4-source`, with committed rollback
  point `0a34c869f7bec86d1eaf783b9264a1eef3c50711` and intentional uncommitted ProjectM/build-284 work preserved.
- The phone preference snapshot confirmed `experimentalBackgroundDownloads=true`. That code path processed every
  URLSession byte-progress callback by decoding the persisted task-record JSON, posting NotificationCenter work to the
  main queue, and mutating multiple `@Published` download values. The foreground path already limited equivalent UI
  publication to once per 400 ms.
- Build 285 applies that same 400 ms gate in the background delegate before record decoding, NotificationCenter, the
  main actor, or SwiftUI. It reads the UUID already stored in `URLSessionTask.taskDescription`, always permits final
  progress, and clears per-task counters after completion or failure.
- One credential-free `download.background_progress.summary` event per file records only callback and publication
  counts. It provides direct phone-side evidence that redundant callbacks were discarded without verbose diagnostics.
- Equivalent before/after workload manifests, opportunity scoring, and proof notes are under
  `/Users/brian/Resonance/Resonance-Alpha-3.7.4/evidence/background-download-progress-round-06`.
- Download bytes, transfer concurrency, queue order, cancellation, persistence/resume, duplicate handling, metadata
  parsing, completed-file moves, incremental library refresh, playback, and ProjectM frame-rate/quality are unchanged.
- Focused contracts, Swift parsing, `git diff --check`, strict Swift 6 simulator and generic-device preflight, signed
  arm64 Release compilation, and deep strict code-signature verification passed. The full regression script reaches
  the unrelated stale Streaming alphabet assertion at line 196. Known non-blocking build output remains the vendored
  hlslparser warnings and AppIntents SSU archive message.
- Build 285 installed in place on SaiyanDenawa. `devicectl` verified bundle
  `com.briangarcia.Resonance.saiyandenwa`, version `2.1`, build `285`. Codex did not launch the physical app.
- Exact continuation point: after the phone cools, manually start a representative multi-track background download.
  Compare warmth and UI responsiveness with build 284, first without ProjectM and then with fullscreen ProjectM if the
  first run is stable. Retrieve `Documents/Resonance-Diagnostics.log` and inspect
  `download.background_progress.summary`; publications should be substantially fewer than callbacks. Thermal
  improvement is not inferred from compilation or installation.

## ProjectM PCM energy repair — build 284

- Current working source is Resonance Beta `2.1` / build `284` on `agent/alpha-3.7.4-source`. The committed rollback
  point is `0a34c869f7bec86d1eaf783b9264a1eef3c50711`; the build-283 transition and diagnostics work remains intentionally
  uncommitted in the active working tree together with this build-284 repair.
- Build 284 replaces the Resonance-only PCM mutex and growable vector handoff with bounded, preallocated
  single-producer/single-consumer storage plus a renderer-owned scratch buffer. The mixer callback and render drain no
  longer allocate, erase, swap, or destroy PCM containers. Audio sample order and channel count are preserved.
- Playback, `GaplessAudioEngine`, explicit 5.1 routing, meter calculation, ProjectM rendering, lyrics, controls, presets,
  the 60 FPS target, fixed 0.75 drawable scale, and build-283's single-render transition behavior are unchanged.
- The named workload is `projectm-pcm-staging`; equivalent before/after manifests and proof notes are under
  `/Users/brian/Resonance/Resonance-Alpha-3.7.4/evidence/projectm-pcm-round-05`. Physical acceptance uses Resonance
  build 284 directly and does not require another standalone ProjectMD comparison.
- Focused PCM contracts, manifest equivalence, `git diff --check`, strict Swift 6 simulator and generic-device
  preflight, signed arm64 Release compilation, and deep strict code-signature verification passed. The full regression
  script reaches its unrelated existing Streaming alphabet assertion at line 196 after the PCM assertions pass.
- Build 284 installed in place on SaiyanDenawa. `devicectl` verified bundle
  `com.briangarcia.Resonance.saiyandenwa`, version `2.1`, build `284`. Codex did not launch the physical app.
- Physical testing found that the phone still heated on build 284, including during downloads with ProjectM closed.
  The final ProjectM run also showed active render cost around 17–21 ms for the selected heavy presets. The aggregate
  PCM summary reported dropped windows; zero drops is not a valid acceptance target because ProjectM consumes recent
  visualization audio and stale windows may be discarded when rendering falls behind.
- Previous continuation point: after the phone cools and with downloads stopped, manually run one local stereo track and a
  light preset for five minutes, close fullscreen for one minute, then test one heavy preset after cooldown. Confirm
  audio response and build-283 transition behavior, note heat/battery, and retrieve the diagnostics after dismissal.
  Interpret `projectm.pcm.staging_summary` as workload evidence rather than requiring zero dropped frames.

## Active ProjectM lyric-feedback and stall repair

- `Tools/ProjectStateCheck.sh --source-only` verified branch `agent/alpha-3.7.4-source`, checkout
  `d811b948fceb7697b85b0429399482e5c70b2a4a`, and project default `2.1`/build `279` before editing.
- Build 279 is installed in place on SaiyanDenawa as `com.briangarcia.Resonance.saiyandenwa`; Codex did not launch it.
- The build-279 SwiftUI lyric dissolve is rejected. The accepted behavior is the original MilkDrop 2 mechanism:
  render text once to a texture, animate its 16-by-8 mesh, then burn the completed text into the feedback surface so
  subsequent preset warps and shaders manipulate it.
- The named baseline workload is `projectm-controls-lyrics-transitions`; evidence lives under
  `performance-evidence/projectm-lyrics-native-round-01`. The current device log is privacy-audited and contains no
  obvious sensitive values.
- Static and device-log inspection identified three independent stall candidates to validate separately: texture search
  paths are reset before every preset and ProjectM documents that this clears the texture manager and can lag; native
  diagnostics perform synchronous GL state/error checks on every frame and pixel readback on error; adaptive drawable
  scaling oscillates after brief transition FPS dips and reallocates ProjectM render targets.
- Build 280 implements the native MilkDrop title path at the ProjectM feedback stage. UIKit/Core Graphics only prepares
  the glyph texture; the 16-by-8 mesh, progress curves, two-pass blend, one-frame feedback burn, and later manipulation
  are owned by ProjectM's OpenGL renderer. Text preparation is detached from the display callback.
- The three identified avoidable stall sources are removed in build 280: identical texture paths are ignored, the
  synchronous GL pixel probe is absent from the production native render entry point, and drawable scale remains fixed
  at 0.75 instead of reallocating render targets after transition dips. Aggregate 120-frame timing windows replace
  per-frame diagnostic synchronization.
- Strict Swift 6 simulator and generic-device preflight passed for build 280. A signed arm64 Release build passed
  deep strict code-signature verification and installed in place on SaiyanDenawa as
  `com.briangarcia.Resonance.saiyandenwa`, version `2.1`, build `280`; Codex did not launch the app. A second clean
  strict simulator build passed while the generated ProjectM XCFramework was physically absent, proving the target
  reproduces the renderer from the checked-in vendored source and `Tools/BuildProjectMNativeIOS.sh`.
- Physical lyric-feedback, transition smoothness, thermal, and before/after timing acceptance remain user-run. GitHub
  publication is the exact continuation point.
- The first-party/app diff passes `git diff --check`. The newly vendored upstream ProjectM tree intentionally preserves
  its original CRLF and generated-source whitespace, so an all-path check reports vendor-only whitespace warnings.

## Source identity

- Repository: `thnikkaman/Resonance`
- Branch: `agent/alpha-3.7.4-source`
- Checkout: `/Users/brian/Resonance/Resonance-Alpha-3.7.4`
- Build-280 implementation commit: `348a5d6` (`Integrate ProjectMD renderer and native MilkDrop lyrics`).
- GitHub tag/release: `Resonance-Beta-v2.0-build268` remains the latest packaged public prerelease; build 280 is
  published as source on `agent/alpha-3.7.4-source` rather than as a new packaged release.
- GitHub PR: not applicable; the development branch has no common history with the ZIP-history `main` branch.
- Project defaults: version `2.1`, build `280`, Swift language mode `5.0`.
- Untracked build outputs, logs, diagnostics, and screenshots are not release files and remain outside Git.

## Current beta source and installed artifact

- Source product: Resonance Beta v2.1/build 280.
- Bundle: `com.briangarcia.Resonance.saiyandenwa`.
- Signed arm64 Release build passed with development team `98CWMFS26R`; deep strict code-signature verification passed.
- Build 280 installed in place on `SaiyanDenawa`, and `devicectl` verified version `2.1`, build `280`.
- Codex did not launch the physical app. Lyric-feedback appearance, transition smoothness, controls, rotation, thermal,
  audio response, and timing metrics remain user-run acceptance.

## Final Waterfall custom-background crop work — 2026-08-01

- Settings → Appearance → Waterfall Meadow accepts replacement images at least 1206 × 2622 pixels.
- The crop interaction supports pan and pinch selection and exports a new 1206 × 2622 JPEG for the backdrop.
- Orientation is normalized before export; Restore Waterfall Meadow removes the replacement image. No layout changes were
  made for this feature.
- The signed arm64 Release build from the final source was built with development team `98CWMFS26R`, passed strict
  code-signature verification, and installed in place on SaiyanDenawa (`9629DEED-EBF9-5835-B98A-9FAEC81CBDC6`) as
  `com.example.ResonancePrototype` version `2.0`/build `268`.
- The physical app was not launched. Manual acceptance remains user-run. The known AppIntents SSU artifact archive
  warning did not prevent the successful build or installation.

## Brushed Metal single-surface artwork — 2026-08-01

- Replaced the detailed hardware-panel Brushed Metal artwork with one continuous 1206 × 2622 brushed-metal surface.
- Removed dials, knobs, vents, screws, panel seams, borders, and decorative lines from the theme asset only.
- No SwiftUI layout, theme selection, navigation, controls, or persistence code changed.
- The generated raster asset was visually inspected before validation; physical runtime appearance remains manual.
- Signed Release build and deep strict code-signature verification passed. Installation is pending because
  SaiyanDenwa is paired but currently unavailable with `ddiServicesAvailable: false` and `tunnelState: unavailable`.

## Psychedelic readability veil — 2026-08-01

- Restored the historical Psychedelic-only treatment in `ResonanceThemeBackdrop`: artwork opacity `0.42` plus the
  themed-gradient veil at opacity `0.12`.
- Waterfall, Brushed Metal, Electronic, and Classic Wood retain their current rendering.
- `git diff --check` passed and the Debug 2.0/build 268 simulator build installed on the configured iPhone 17 Pro.
- The app was not launched; visual acceptance remains user-run.

## Aqua theme backgrounds — 2026-08-01

- Gallery Light now maps to `ThemeGalleryAqua`, a minimal pale Aqua glass background.
- Nocturne Glass now maps to `ThemeNocturneAqua`, the matching dark navy/cyan Aqua background.
- Both assets are 1206 × 2622. Theme names, palettes, layout, controls, appearance recommendations, and other
  backgrounds remain unchanged.
- `git diff --check` and the Debug 2.0/build 268 simulator build passed; the app installed on the configured iPhone
  17 Pro simulator and was not launched.

## Left Handed Mode setting label — 2026-08-01

- Renamed the Settings toggle from “Left-handed alphabet” to “Left Handed Mode.”
- The existing `@AppStorage("leftHandedAlphabet")` default remains `false`; existing saved preferences are not reset.
- Alphabet layout and gesture behavior are unchanged.
- `git diff --check` passed and the Debug 2.0/build 268 simulator build installed on the configured iPhone 17 Pro.

## Electronic minimal circuit artwork — 2026-08-01

- Replaced the busy Electronic artwork with a 1206 × 2622 dark circuit-board background.
- The new asset contains sparse fluorescent cyan, blue, and magenta paths without dials, gauges, sliders, or dense
  hardware components.
- No layout, theme logic, controls, or navigation code changed.
- Sarah's currently paired phone is `67843DDD-CEF7-5AAC-ADCB-13171D2D7589`; signed version 2.0/build 268 installation
  passed with team `M4Q367H7K2`.
- Chase's phone is currently unavailable to CoreDevice. The Chase-specific app was built and manually signed with the
  valid team `U37R4TL69` profile, but installation remains pending until the phone becomes reachable.

## Latest SarahSue device artifact

- Source: GitHub-synchronized `agent/alpha-3.7.4-source` commit `baef8bc`.
- Automated validation: `git diff --check`, `Tools/RegressionChecks.sh`, and `Tools/PreflightBuild.sh` passed.
- Signed artifact: version `2.0`, build `268`, bundle `com.example.ResonancePrototype`.
- Signing: Sarah Garcia personal team `M4Q367H7K2`; Xcode identity `Apple Development: sarahsue621@gmail.com (D75HLRVZDX)`.
- Device: Sarah's iPhone (3), identifier `00008140-00067D620E10401C`.
- `codesign --verify --deep --strict` passed; `devicectl` installed the app and verified version `2.0`/build `268`.
- The app was not launched. Playback, navigation, audiobook behavior, and other runtime acceptance remain manual tests.

## Latest Chaseatron device artifact

- Source: GitHub-synchronized `agent/alpha-3.7.4-source` commit `baef8bc`; source behavior and project version/build are unchanged.
- Signed artifact: version `2.0`, build `268`, Chase-specific bundle `com.chaseatron.Resonance`.
- Signing: Chase Peterson personal team `U37R4TL69A`; Xcode identity `Apple Development: chaseatron8110@gmail.com (RU994287VG)`.
- The original `com.example.ResonancePrototype` identifier was unavailable to Chase's team, so this is a separate app/data container.
- Device: Chase’s iphone, identifier `016D50FF-A5D1-52C4-8577-6C416B1C15FF`.
- `codesign --verify --deep --strict` passed; `devicectl` installed and verified version `2.0`/build `268`.
- The app was not launched. Playback and all other runtime acceptance remain manual tests.

The current v2.0/build-268 source and public release are published at https://github.com/thnikkaman/Resonance/releases/tag/Resonance-Beta-v2.0-build268.

## Current alphabet diagnostic build

- Current source commit: `d6fbd37` (`Make alphabet gestures reset between touches`). Earlier commits `981e839` and
  `3be137f` added local and global touch-coordinate diagnostics.
- The existing Reported Errors → Debugging Mode setting now records `alphabet.touch.begin` and `alphabet.touch.end`
  events with only surface, handedness, local touch coordinates, container geometry, hit-column width, and sample count.
- The separate alphabet-diagnostics setting was intentionally not added; the trace uses the existing diagnostics setting.
- `Tools/RegressionChecks.sh` and `git diff --check` passed. A signed arm64 Release build passed strict code-signature verification.
- Left-handed Streaming indexes now retain a 32-point visible letter column but use a 48-point edge hit strip; local
  Library indexes remain 32 points. The `2.0`/`268` diagnostic build was installed in place on `SaiyanDenwa`
  (`9629DEED-EBF9-5835-B98A-9FAEC81CBDC6`); Codex did not launch it. The installed app remains ready for user reproduction.
- After reproduction, copy `Documents/Resonance-Diagnostics.log` from the app container before disabling Debugging Mode.

- The latest Streaming trace showed 9 complete touch/gesture pairs and 425 selections on the left-handed Streaming
  Artists index. The remaining intermittent behavior was traced to `gestureStarted` and `gestureKey` being cleared only
  inside a yielded task after release. The shared alphabet gesture now resets synchronously, applies the release target
  immediately, and uses a generation guard to suppress stale deferred callbacks. Commit `d6fbd37` is installed in place
  on `SaiyanDenwa` as version `2.0`/build `268`; the physical app was not launched. The latest copied trace is
  `/Users/brian/Resonance/diagnostics/latest/Resonance-Diagnostics.log` and remains uncommitted diagnostic evidence.

- A non-owning simultaneous `streaming.alphabetProbe.begin/end` observer was added to the Streaming root to capture
  left-edge touches that never reach `VerticalArtistIndex`. It records only coordinates, handedness, and sample counts
  under the existing Debugging Mode setting. The signed 2.0/268 probe build is installed in place on `SaiyanDenwa` and
  was not launched. Retrieve the post-reproduction log before disabling Debugging Mode.

- The post-probe trace contained one Streaming Artists gesture and nine local Library gestures. The Streaming gesture
  was recognized and issued eight scroll requests, so hit testing was not the only difference. Streaming had wrapped
  each alphabet update in a new 200 ms animation while local Library called `ScrollViewProxy.scrollTo` directly. The
  three Streaming alphabet handlers now match the local direct-dispatch behavior. The signed 2.0/268 build is installed
  in place on `SaiyanDenwa`; physical runtime acceptance remains user-run.

- The latest trace confirmed the user-visible geometry concern: Streaming’s left-handed alphabet frame reported
  `globalMinX=-7` and `globalMaxX=41`, centering the 48-point hit frame around x=17 rather than anchoring it to the
  screen edge. The three Streaming alphabet ZStacks now explicitly fill available width and align leading/trailing
  according to handedness. The signed 2.0/268 build is installed in place on `SaiyanDenwa`; Codex did not launch it.

## Beta 2.0 build 268 release scope

- Optional gold FLAC-only artwork borders now cover local and Streaming album grids, rows, artist album modules, and album detail.
- Siri/App Intents provide Play Song, Play Album, Play Artist, and Resume Audiobook actions.
- Cached Subsonic catalogs missing file extensions receive a one-time format refresh when Flac Alert is enabled.
- Left-handed Streaming artist-album padding and the alphabet gesture hit column are corrected without changing right-handed geometry.

## Beta 2.0 build 268 validation and installation

- `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` passed.
- Signed arm64 Release compilation and strict deep code-signature verification passed.
- Build `2.0`/`268` installed in place on Sarah’s iPhone under team `M4Q367H7K2` using `com.example.ResonancePrototype`.
- Build `2.0`/`268` installed in place on Chase’s iPhone under team `U37R4TL69` using `com.chaseatron.Resonance`; the original identifier was unavailable to Chase’s team.
- A matching Debug build installed on the iPhone 17 Pro simulator and was visually inspected by the user.
- Codex did not launch either physical app; physical playback and full runtime acceptance remain user-run.

## Implemented change

The audiobook feature is implemented in the current `2.0/267` source and installed on `SaiyanDenawa`. Local and
personal Streaming albums can be marked or unmarked as audiobooks from their album context actions. Audiobook album
Play resumes the newest saved pause/stop position, with a persisted five-entry-per-album recovery history and no
global audiobook limit. The Now Playing
speed menu is visible only for an active audiobook and applies to AVAudioPlayer, AVPlayer, and the local gapless
AVAudioEngine path through `AVAudioUnitTimePitch`. Existing manual track bookmarks and normal-music controls remain
separate. The bookmark viewer scopes recent positions to the active audiobook and shows album/book and track titles.
When an active audiobook leaves the foreground, one additional position is saved. The phone was not launched by Codex.

Beta v1.0.9 makes the album-wide disc-number override blank by default. A blank Save preserves every track’s current
disc number, including multi-disc albums; an entered value remains an intentional album-wide update.

Beta v1.0.8 stages metadata-editor artwork selections until Save, exposes both Artist and Album Artist in track,
album, and artist metadata forms, places read-only album/artist information below artwork pickers, and adds keyboard
dismissal to the online artwork search. Automatic artwork recommendations during library ingestion remain unchanged.

## Validation

- `git diff --check` passed.
- `Tools/RegressionChecks.sh` passed for project default `1.0.9/261`.
- `Tools/PreflightBuild.sh` passed simulator and generic-device strict compilation.
- Signed Release build, code-signature verification, in-place install, and device bundle inspection passed.
- Audiobook validation passed `Tools/RegressionChecks.sh`, `git diff --check`, strict preflight, signed arm64 Release
  compilation, deep strict code-signature verification, and in-place installation. `devicectl` verified
  `com.example.ResonancePrototype` version `1.0.9`, build `261` on `SaiyanDenawa`.
- Known non-blocking warning: AppIntents metadata extraction is skipped because the target has no AppIntents framework dependency.

## Beta v1.0.9 release scope

- Album disc-number editing opens blank and preserves existing per-track disc numbers when left blank.
- Entering a disc number applies it intentionally to every track in the album.

## Beta v1.0.8 release scope

- Artwork selected inside a metadata editor remains staged until that editor’s Save; Cancel discards it.
- Automatic artwork recommendations during local ingestion and remote catalog acquisition remain unchanged.
- Track, album, and artist editors expose both Artist and Album Artist and write the fields to the affected files.
- Read-only track names, counts, and reset/status information follow the artwork picker.
- Online artwork search supports Done, outside-tap, submit, and scroll keyboard dismissal.
- Final signed Release build and in-place install verified `1.0.8`/`260` on `SaiyanDenawa`; the app was not launched.

## Manual continuation

Launch the installed `1.0.9/261` build manually and test the audiobook feature: mark local and Streaming albums, pause
or stop at a later track, use the album’s main Play action to resume, switch tracks and use the recent bookmark list,
test all audiobook speeds, confirm normal albums do not show the speed menu, and relaunch to verify the flags and
five-entry-per-album history across multiple audiobook albums persists. Do not uninstall first.

The album-wide disc-number editor initializes its override field blank on every open. Leaving it blank
preserves each track’s existing disc number, including multi-disc albums; entering a value applies that value to every
track. Beta v1.0.9 was published after the source-contract regression check, strict simulator/generic-device preflight,
and signed device build passed. The physical app was not launched by Codex.

On `SaiyanDenawa`, launch Beta v1.0.8 manually and verify:

- choosing artwork in a metadata editor is discarded by Cancel and committed by Save;
- both Artist and Album Artist can be edited in track, album, and artist forms;
- read-only track names/counts appear below artwork pickers;
- the artwork-search keyboard dismisses with Done, outside taps, submission, or scrolling;
- Browse Files, Download, centered navigation, playback, and existing data remain intact.

Do not uninstall first. Codex must not launch the physical app automatically.

## Evidence commands

```sh
Tools/ProjectStateCheck.sh --source-only
Tools/RegressionChecks.sh
Tools/PreflightBuild.sh
xcrun devicectl device info apps --device 00008150-001144383612401C --bundle-id com.example.ResonancePrototype
```

## Streaming alphabet edge-overlay repair — Beta 2.0 build 268 — 2026-08-01

A formal local-versus-Streaming layout comparison found the shared `VerticalArtistIndex`, ZStack alignment, and edge
padding are equivalent. Streaming additionally had a full-height 24-point leading overlay for root back-swipe
navigation. That overlay was above the alphabet and explains why touches only worked at the album-art edge. Its gesture
now uses simultaneous recognition, preserving qualifying horizontal back swipes while allowing the alphabet’s
high-priority vertical gesture to receive left-edge touches.

Signed 2.0/268 build, strict deep signature verification, and in-place device installation passed. Physical runtime
acceptance remains user-run; Codex did not launch the phone app.

## Streaming alphabet copied from Local layout — Beta 2.0 build 268 — 2026-08-01

The previous Streaming-specific hit-width, full-size alignment frames, and leading back-swipe overlay were removed.
The three Streaming browse containers now use the Local template directly: shared default `VerticalArtistIndex`
width, matching ZStack sizing/modifier order, and matching edge padding. Remote rows, section IDs, diagnostics, labels,
and navigation remain the only intentional Streaming differences around the browse content.

Signed 2.0/268 build, strict signature verification, and in-place installation passed. Physical runtime acceptance
remains user-run; Codex did not launch the phone app.

## Minimal Transparent toolbar icon cleanup — Beta 2.0 build 268 — 2026-08-01

Removed the Minimal Transparent accent capsule from the shared `ResonanceToolbarIconButton` and
`ResonanceToolbarIconLabel` components. Text buttons and hero action buttons retain their existing Minimal Transparent
underline treatment.

Signed arm64 Release compilation, simulator Debug compilation, `git diff --check`, and in-place simulator installation
passed. Build `2.0`/`268` is installed on the iPhone 17 Pro simulator; the physical phone was not updated or launched.

## Remove remaining Minimal Transparent button lines — simulator build 268 — 2026-08-01

Screenshot review identified four additional shared underline implementations: hierarchy labels, hero action buttons,
hero menu labels, and text buttons. All Minimal Transparent underline capsules are now removed; the style description
now says “no button chrome.” Simulator Debug build and in-place installation passed on the iPhone 17 Pro simulator.
The physical phone was not updated or launched.

## ProjectMD fullscreen replacement and physical push — 2026-08-07

The broken projectM proof of concept was replaced by `ProjectMFullscreenView.swift` and the native
`ResonanceProjectMBridge` FBO path. Playing-page album art now opens fullscreen visualizations from the bundled
ProjectMD CreamOfTheCrop catalog. The regular ProjectMD options and diagnostics shell is not imported. Single tap
reveals the fullscreen controls, double tap dismisses, horizontal swipes change presets, Favorite persists, and Banish
persists an exclusion. The bridge uses the actual drawable size while the framebuffer path is stabilized and leaves
mesh sizing at the projectM library default.

The bundled visualizer resources are namespaced under the app bundle's `ProjectMD/` directory. The preset loader uses
`Bundle.main` with subdirectory `ProjectMD` and the texture search path is likewise `ProjectMD/MilkDrop3Test`; no
top-level preset directories are emitted.

The existing regression script still stops at its known stale artwork assertion; `Tools/PreflightBuild.sh` passed after
the actor-isolation repair and the bridge changes.

The original `com.example.ResonancePrototype` profile was expired and could not be renewed for team `98CWMFS26R`, so
the project Debug and Release bundle identity was changed to the unique `com.briangarcia.Resonance.saiyandenwa`.
Automatic signing generated a new team profile. Signed arm64 Release compilation and deep strict code-signature
verification passed. The app was installed on `SaiyanDenawa` as version `2.0`, build `268`, without uninstalling or
launching. This is a separate app/data container; the existing `com.example.ResonancePrototype` installation remains
untouched.

Signed arm64 Release compilation, deep strict code-signature verification, and in-place installation passed on
`SaiyanDenawa`. The installed bundle is `com.briangarcia.Resonance.saiyandenwa`, version `2.0`, build `268`; the old
container remains installed and untouched. The app was not launched automatically.

Physical acceptance remains unresolved: the catalog loads on SaiyanDenawa, but fullscreen output is still black after
the namespaced-resource and FBO-path builds. The next continuation is to retrieve device diagnostics and compare the
active framebuffer, viewport, target attachment, and render-call sequence against ProjectMDNativeVisualizerView.swift.
Do not change playback or navigation code while isolating the renderer.
