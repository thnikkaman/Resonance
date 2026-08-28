# Resonance work queue

## R-MEIKYO-1.1-BUILD351-SUBMISSION — Process and submit the production upload

- Status: uploaded to App Store Connect as MeiKyo version 1.1/build 351; Apple reported that the package is
  processing. It is not yet verified as processed, attached to the 1.1 submission, or submitted for review.
- Source: `RemoteDownloadService.swift` contains the build-351 move/access-mode and failure-diagnostic repair. The
  handoff, README, and this queue are updated with the exact provenance and remaining acceptance work.
- Automated evidence: archive, export, local signing checks, and authenticated upload passed. The physical phone was
  not launched or updated, and the download behavior has not been claimed as runtime-verified.
- Next: attach build 351 to version 1.1, finish export compliance and review metadata, submit for review, then test an
  all-caps PIERROT download and the resume flow on the phone.

## R-AUDIOBOOK-LRC-REPRESENTATION-MATCH — Match the phone's audio filename to its adjacent LRC

- Status: implemented, strictly validated, signed, and installed in place as MeiKyo 1.0/build 342; physical runtime
  acceptance remains user-run.
- Owner: `LibraryStore.swift` inventory matching through the pure `LyricsCompanionMatcher.swift` service helper.
- Proven baseline: build 334 enumerated 36 LRC files but cached zero companions. The copied phone database stores the
  first audio filename as `01 - Chapter 01_ An Unexpected Party.mp3`, while the adjacent file is named
  `Chapter 01 - An Unexpected Party.lrc`; exact stem matching therefore cannot pair them.
- Goal: pair representation-equivalent audio/LRC stems only when both files have the same normalized parent folder.
- Preserved invariants: direct exact sibling lookup remains first, files stay in their selected folder, no LRC is copied
  into MeiKyo's music folder, manual overrides retain priority, and unrelated folders cannot cross-match.
- Smallest causal lever: normalize importer-added leading numbers and punctuation in one production matcher used by the
  scan; do not change playback, import, folder authorization, or LRC parsing.
- Automated oracle: compile and execute `Tools/LyricsCompanionMatcherFixture.swift` with the production matcher. It must
  match the exact Chapter 01 device representation, Chapter 1/01 Prisoner representation, plus Chapters 02/04, reject
  another chapter, and reject another folder.
- Manual acceptance: after an in-place build install, run a library scan and play Chapters 2 and 4. Their Lyrics buttons
  must enable automatically in Now Playing and the visualizer. Chapter 3 remains excluded because it has a manual override.
- Rollback: remove `LyricsCompanionMatcher.swift` and restore exact match-key construction in `LibraryStore.swift`.

- Build 337 validation: the focused fixture, signed Release build, strict signature verification, and in-place install
  passed; standard no-scheme, AppIntents SSU, and vendored HLSL warnings remained non-blocking.

- Build 338 adds LRC header metadata matching for `[resonance-id]`, title, album, artist, track, and disc fields. The
  local sidecar must still be present on the phone; the filename is now only a fallback identity.
- Build 339 adds a selected-folder-wide coordinated metadata search for File Provider cases where immediate sibling
  enumeration returns no LRC files.
- Build 340 makes the rescan happen in the audiobook playback-load path, before lyric lookup, and replaces the
  one-shot enumerator fallback with an explicit coordinated directory walk so newly copied LRC files are checked.
- Build 340 manual acceptance: play Chapters 2 and 3 with their LRC files already beside the MP3s; each should load
  automatically without manual import. Do not treat the signed install as runtime acceptance.
- Build 342 fixes verified metadata decoding for BOM-less UTF-16LE LRC files and retains the exact MP3-parent-folder
  lookup. The focused fixture proves title/album/track matching from UTF-16LE metadata before device installation.

## R-REMOTE-DOWNLOAD-ORIGINAL-FILENAME — Preserve server filenames for future downloads

- Status: implemented, strictly validated, signed, and installed in place as MeiKyo 1.0/build 337; physical download
  acceptance remains user-run.
- Owner: `RemoteLibraryStore.swift` carries the original manifest/Subsonic path filename, and
  `RemoteDownloadService.swift` owns foreground/background destination naming.
- Proven baseline: the prior downloader generated `01 - Chapter 01_ An Unexpected Party.mp3` from track metadata and
  sanitized `:`, rather than retaining `Chapter 01 - An Unexpected Party.mp3`.
- Goal: preserve the remote catalog/path filename first; use HTTP `Content-Disposition`/suggested filename as a fallback,
  and use the generated metadata name only when neither original source provides a usable name.
- Preserved invariants: artist/album folder organization, supported-audio extension checks, duplicate replacement choices,
  atomic moves, background resume, indexing, artwork writing, and existing downloaded files remain unchanged.
- Manual acceptance: download a newly removed test track whose server filename differs from its metadata-generated name,
  then inspect Files and confirm the server filename is retained. Existing files are not automatically renamed.
- Build-336 warning record: the standard empty/no-scheme destination warning, AppIntents SSU archive warning, and
  existing vendored HLSL `format-extra-args`/deprecated `sprintf` warnings were observed and were non-blocking.
- Rollback: remove original filename propagation and restore the generated destination leaf while retaining the LRC matcher.

This is the lightweight execution record for the current phase. Each item names its owner, evidence, acceptance
oracle, and rollback point. Generated logs, diagnostics, screenshots, and build outputs remain outside Git.

### R-PROJECTM-TRANSPORT-AUDIOBOOK-LRC — Add fullscreen transport and reliable local audiobook lyrics

- Status: implemented in MeiKyo version 1.0/build 320 and installed in place; physical UI/audio acceptance remains user-run.
- Owners: `ProjectMFullscreenView.swift` owns the dismissible HUD layout and transport presentation; `PlayerController.swift`
  remains the sole owner of previous/next/seek playback mutations; `LyricsService.swift` owns local companion-file lookup
  and parsing.
- Goal: place Exit in the former play/pause position, place transport controls in the former Exit position, add previous/
  next buttons and a bottom seek bar, and automatically recognize same-basename local `.lrc` files for local playback.
- Invariants: all transport controls remain inside the existing dismissible HUD; playback queue, seek authority, imported
  lyric precedence, provider fallback, and local file parsing remain unchanged; no individual visualization assets change.
- Behavior oracle: reveal the visualizer HUD, verify Exit, previous, play/pause, next, and seek all occupy the intended HUD;
  mark an album as an audiobook, start a track with an adjacent same-basename `.lrc`, and verify lyrics load without import.
- Automated acceptance: `git diff --check`, source contracts, strict simulator/generic-device preflight, signed arm64
  Release build, deep signature verification, and in-place device install passed. Physical-device interaction remains user-run.
- Rollback: revert the HUD transport view and the local sibling lookup change; no data migration is required.

Follow-up: build 321 also makes the fullscreen visualizer refresh `LyricsStore` on presentation so the local scan does not
depend on the parent Now Playing task winning a lifecycle race.

Correction: build 323 removes the build-322 copy behavior. The selected library folder remains authoritative; lyrics are
read in place beside the actual audio file through coordinated external-file access.

Build 324 adds common audiobook LRC encoding fallbacks and privacy-safe lookup diagnostics. Acceptance requires playing
the reported Hobbit chapters on the selected external folder and confirming both Now Playing and the visualizer load the
adjacent files without import or copying.

Build 325 fixes the confirmed stale cached managed-folder URL: cached/database tracks are rebased into the selected
external library folder before playback, restoring sibling LRC visibility without copying sidecars.

Build 326 adds the same relative-path translation directly in LyricsService as a cache-independent fallback.

Build 327 makes directory selection itself authoritative and in-place, eliminating the copied-audio URL that caused the
companion lookup failure.

Build 328 adds a recursive exact-basename search under the selected library bookmark as a cache-independent fallback.

Correction: the physical device database proved that all Hobbit tracks already use external Files URLs. Build 329 removes
the remaining invalid assumption: finding a provider URL and reading it later is not sufficient. It coordinates the actual
audio item, inspects its parent directory, and reads the matching LRC before leaving that coordinated access window, with the selected-folder
security scope active and all directory work off the main thread. Manual acceptance should use Chapters 2 and 4 because
Chapter 3 has an imported override.

Build 331 makes the exact same-basename LRC URL the primary read while the audio URL's security scope is active, then
retains the audio-item coordination fallback. Physical acceptance remains the
Chapter 2/4 test above.

Build 332 adds the selected-folder path as the authority for the companion read: the scan bookmarks the exact matching
LRC, and playback first derives the same-relative-path LRC under the selected folder's security scope. The scan logs
the companion count, separating discovery failure from provider-read failure. Build 331's no-change user result is
recorded as failed runtime evidence.

Correction: build 332 also produced no behavior change. Its fresh device diagnostics showed that playback-time sibling
access still returned no bytes and that no post-upgrade companion scan had occurred. Build 333 removes per-file bookmark
rediscovery: the authorized library scan reads exact adjacent LRC contents into a replaceable private cache, and existing
cached libraries automatically run that scan once after upgrade. Playback uses the cached bytes through the normal parser.

Correction: build 333's private companion cache remained empty after the user waited and manually scanned. Build 334
tries both `<stem>.lrc` and `<full audio filename>.lrc` directly for every audio URL before relying on File Provider
enumeration, forces a v2 upgrade scan, and always logs aggregate candidate/read counts.

### R-SETTINGS-CATEGORY-NAVIGATION — Push Settings categories into dedicated pages

- Status: implemented and corrected for single-tap activation in MeiKyo version 1.0/build 316 and installed in place;
  physical UI acceptance remains user-run.
- Owner: `SettingsView.swift` owns the category hub, category-page presentation, settings controls, and transient
  navigation interaction. No service or persisted-state boundary changes are required.
- Goal: replace the old inline expandable Settings sections with a modern category hub. Selecting a category must push
  its complete controls page from right to left above the hub; the native back action must pop it from left to right and
  reveal the unchanged parent Settings page.
- Invariants: preserve all existing settings bindings, AppStorage/Keychain behavior, QR/file/photo pickers, diagnostics,
  theme rendering, keyboard dismissal, accessibility labels, tab/layer entry points, and the current custom themed
  surfaces. The root Settings edge gesture must not intercept a child page's interactive back gesture.
- Behavior oracle: open Settings from both the layered Settings entry and the Settings tab, confirm the hub shows every
  category without its controls, open each category, confirm the full controls page slides in, use the visible back
  control and an edge swipe to return, and verify a changed toggle/picker persists after returning and relaunching.
- Automated acceptance: `Tools/RegressionChecks.sh`, Swift parsing, `git diff --check`, strict simulator/generic-device
  preflight, signed arm64 Release compilation, deep signature verification, and in-place install on `SaiyanDenawa`
  passed for build 316. Codex did not launch the physical app.
- Rollback: restore `SettingsCategory` to its `DisclosureGroup` implementation and restore the removed root Settings
  edge-drag dismiss gesture; no migration or service rollback is required.

### R-VISUALIZER-ENTRY-EXIT-CONTROLS — Add explicit Playing and fullscreen visualizer controls

- Status: implemented and corrected so Exit belongs to the dismissible visualizer HUD in MeiKyo version 1.0/build 316 and
  installed in place; physical UI acceptance remains user-run.
- Owner: `PlayerViews.swift` owns the Playing-screen entry button and existing photosensitivity gate; `ProjectMFullscreenView.swift`
  owns the fullscreen Exit control and existing `dismiss` boundary. No playback, renderer, preset, or persistence logic changes.
- Goal: expose a clear Visualizer button on the Playing screen and an Exit button inside the same dismissible fullscreen
  visualizer HUD as the other visualizer actions.
- Invariants: the existing first-use photosensitivity warning remains mandatory, the renderer still owns fullscreen
  orientation/lifecycle, double-tap dismissal remains available, and the button actions do not alter presets, playback,
  lyrics, downloads, or visualizer settings.
- Behavior oracle: tap Playing → Visualizer, confirm the existing safety notice appears when unacknowledged, continue into
  the renderer, and tap Exit both before and after revealing visualizer controls; the fullscreen cover must dismiss cleanly.
- Automated acceptance: regression contracts, Swift parsing, strict simulator/generic-device preflight, signed arm64
  Release compilation, deep signature verification, and in-place install on `SaiyanDenawa` passed for build 316; Codex
  did not launch the physical app.
- Rollback: remove the `openVisualizer` callback/button and the fullscreen Exit overlay; retain the existing artwork-tap
  visualizer entry and double-tap dismissal.

### R-NOW-PLAYING-LYRICS-PERSISTENCE — Keep the artwork lyrics panel open during playback controls

- Status: implemented in MeiKyo version 1.0/build 316 and installed in place; physical playback/UI acceptance remains
  user-run.
- Owner: `PlayerViews.swift` owns the artwork lyrics panel state and explicit dismiss actions; `LyricsStore` continues
  to own document refreshes and playback synchronization.
- Goal: seeking, pausing, and resuming must not dismiss the lyrics panel when a transient document refresh publishes an
  empty or replacement value. The panel remains until its X is pressed, apart from intentional track changes and the
  existing fullscreen/import transitions.
- Automated acceptance: regression contracts, Swift parsing, strict simulator/generic-device preflight, signed arm64
  Release compilation, deep signature verification, and in-place install on `SaiyanDenawa` passed for build 316. Codex
  did not launch the physical app.
- Rollback: restore only the document-change dismissal handler in `NowPlayingView`; retain the lyrics store refresh path.

### R-NOW-PLAYING-LYRICS-LOCAL-RESCAN — Re-read sibling LRC files when playback restarts

- Status: implemented in MeiKyo version 1.0/build 313; signed in-place install completed; physical playback
  acceptance remains user-run.
- Owner: `PlayerController.swift` owns the playback-restart event; `LyricsStore` and `NowPlayingView` own the
  local-lyrics refresh boundary. `LyricsService.localDocument` remains the off-main file reader and parser.
- Goal: when a local track starts or restarts playback—including a seek that rebuilds the local gapless backend—re-read
  the current app-private override and eligible sibling `.lrc` file instead of retaining the previously displayed
  document for the same track identity.
- Invariants: local reads remain detached from the main actor; imported overrides retain precedence; provider lookup,
  remote lyric caching, active-line timestamp selection, playback timing, and visualizer lyric consumption remain
  unchanged. Duplicate layered Now Playing views must not start duplicate restart reloads for one playback event.
- Behavior oracle: replace an audiobook's sibling `.lrc` with different timestamps, restart or seek playback without
  changing tracks, and confirm the new timestamps are used. Repeat after pause/resume and verify a non-local remote
  track does not trigger a local file scan.
- Automated acceptance: regression contracts, `git diff --check`, Swift 6 parsing/preflight, signed Release build,
  deep signature verification, and in-place install passed for build 313. The physical device was updated but not
  launched; playback acceptance remains user-run.
- Rollback: revert the playback restart token, the `LyricsStore.reloadForPlayback` entry point, and its Now Playing
  change handler; normal track-change lyrics loading remains intact.

### R-NOW-PLAYING-LYRICS-GEOMETRY — Keep the lyrics panel centered and dismissible

- Status: implemented in MeiKyo version 1.0/build 312 and installed in place; physical UI acceptance remains user-run.
- Owner: `PlayerViews.swift` owns the Now Playing artwork pager, lyrics overlay geometry, and transient control
  hit-testing; no lyrics service, playback, or durable state change is required.
- Seek invariant: `NowPlayingLyricsBubble` observes the shared `PlaybackProgress` publisher directly; it must not use a
  separate timer snapshot for active-line selection after a seek.
- Audiobook invariant: the gapless playback clock must multiply wall-time advancement by the effective time-pitch rate
  and re-anchor when the user changes speed, so synced lyrics track media time rather than elapsed wall time.
- Goal: keep the lyrics panel fully inside the artwork region, center it on every iPhone width, and keep its close,
  maximize, and restore controls above adjacent Now Playing controls.
- Invariants: preserve the 90% opaque panel, active-line centering, LRC import, fullscreen promotion, track changes,
  visualizer lyrics, playback, and tab/navigation gestures. The animation may use a bounded scale/fade transition;
  the unstable matched-geometry path is intentionally removed.
- Behavior oracle: open lyrics from the Now Playing Lyrics button, verify the panel is centered over artwork, tap
  maximize and restore, close it from both states, and confirm the transport controls remain separate and usable.
- Automated acceptance: `Tools/RegressionChecks.sh`, `git diff --check`, strict simulator/generic-device Swift 6
  preflight, signed arm64 Release compilation, deep signature verification, and in-place installation passed. The
  physical app was not launched automatically.
- Rollback: revert only the lyrics overlay geometry/stacking/transition changes while retaining the shared lyrics store
  and importer behavior.

### R-FLAC-METADATA-VENDOR-LENGTH — Prevent rebranded FLAC tags from corrupting

- Status: implemented and installed in MeiKyo version 1.0/build 312; manual file round-trip acceptance remains
  user-run.
- Owner: `MetadataReader.swift` owns FLAC Vorbis-comment serialization; `Tools/RegressionChecks.sh` owns the source
  contract that prevents a stale vendor-length constant.
- Root cause: the vendor text changed from `Resonance` (9 bytes) to `MeiKyo` (6 bytes), but the serialized vendor
  length remained 9. This shifted every later Vorbis-comment field by three bytes after a metadata save.
- Behavior oracle: edit only the track number of a restored `10,000 Days` FLAC and confirm the title, `Tool` artist,
  `10,000 Days` album, and new track number remain unchanged in MeiKyo and an external tag reader.
- Automated acceptance: source-contract regression checks, `git diff --check`, strict simulator/generic-device
  preflight, signed arm64 Release compilation, deep signature verification, and in-place install passed. The physical
  app was not launched.
- Important recovery note: files already written with the malformed block must be restored or re-downloaded; their
  original metadata cannot be safely reconstructed from the corrupted tags.
- Rollback: restore the prior `makeVorbisComments` implementation only if a verified known-good build demonstrates a
  regression; do not roll back to the stale fixed-length vendor field.

### R-NOW-PLAYING-LYRICS-BUBBLE — Show available lyrics over Now Playing artwork

- Status: implemented in the MeiKyo 1.0/build 312 source; regression checks, strict preflight, signed Release
  validation, deep signature verification, and in-place installation passed. Physical UI acceptance remains user-run.
- Owners: `LyricsStore` remains the shared provider/cache/local-override owner; `NowPlayingView` and
  `NowPlayingLyricsControl` own button availability, popover presentation, and long-press import; `NowPlayingLyricsBubble`
  owns scrollable rendering, low-rate active-line highlighting, and full-screen promotion; `NowPlayingArtworkPager`
  owns the artwork-positioned panel and matched-geometry destination; `ProjectMLyricsFeedHost` consumes the shared
  store without starting a second lookup.
- Goal: show a grey disabled Lyrics control when the configured provider has no readable plain or synced lyrics, and a
  gold control plus opaque album-art bubble when lyrics are available.
- Invariants: imported lyrics are stored only in the app-private Application Support override directory; provider
  configuration, HTTPS validation, timing, visualizer rendering, audio, presets, transitions, and fullscreen lifecycle
  remain unchanged; no high-frequency playback observation is added to the visualizer or the Now Playing root.
- Behavior oracle: a no-match track has an unavailable grey button; a synced track has a gold button, opens a 90%
  opaque panel that animates from the Lyrics button back over the album artwork, highlights and centers the active
  timestamped line, and continues to feed the visualizer from the same cached document. The maximize control opens a
  full-screen lyrics view; restore returns to the artwork panel. A long hold opens the `.lrc` importer; an imported file is immediately
  usable and survives relaunch. A local audiobook checks its parent folder for a case-insensitive same-basename `.lrc`
  before remote lookup; missing or invalid sibling files fall back without crashing. First and final lines can also
  be centered, and a plain-lyrics track displays scrollable text without timestamp highlighting.
- Automated acceptance: source-contract regression checks, Swift parsing, `git diff --check`, strict simulator and
  generic-device preflight, signed arm64 Release compilation, deep signature verification, and in-place installation
  passed for beta build 312. The physical phone was updated but not launched; runtime acceptance remains user-run.
- Rollback: revert the local sibling search, app-private override storage, importer modifier, popover presentation, and
  related `LyricsStore` state while retaining the shared provider/cache and existing visualizer lyric feed.

### R-PROJECTM-LYRICS-THREE-LINE-WIDTH — Expand long synced lyrics to an 80%-wide band

- Status: implemented; regression checks, strict preflight, signed Release validation, and in-place installation
  completed as MeiKyo version 1.0/build 309; physical long-verse acceptance remains user-run.
- Owner: `MilkdropText.cpp` owns the native lyric mesh width; `ResonanceProjectMBridge.mm` retains the existing
  1536×256 rasterization and three-row font fitting.
- Goal: allow long synced lyric lines to display up to three complete wrapped rows across approximately 80% of the
  fullscreen visualization width.
- Invariants: preserve lyric text, provider lookup, timing, font fitting, full-text vertical sampling, entry scale,
  fade/feedback animation, audio, presets, transitions, controls, and renderer lifecycle.
- Behavior oracle: use the previously failing long-verse screenshots and confirm the rightmost words remain visible
  in a three-row lyric texture while controls and preset transitions remain responsive.
- Automated acceptance: focused lyric contract, `git diff --check`, Swift parsing, strict preflight, signed Release
  compilation, deep signature verification, and in-place device installation without launching the physical app.
- Rollback: restore the native lyric mesh width from `0.80` to `0.68`; no persisted-data migration is required.

### R-LIBRARY-METADATA-DOWNLOAD-RACE — Preserve local tag edits and prevent stale scan publication

- Status: source implementation complete in the current dirty 1.0/build-313 checkout; automated validation passed;
  physical runtime acceptance remains user-run.
- Owner: `LibraryStore.swift` owns scan publication and targeted metadata refresh; `RemoteDownloadService.swift`
  owns replacement destination selection; `MetadataWriteBatch.swift` owns file-tag writes.
- Change: `LibraryStore` now captures a mutation generation when a scan begins, invalidates it before targeted
  download/metadata refreshes and removals, and discards the scan before or after its database write when newer local
  state exists. The discard is recorded as `library.scan.discarded` without names, paths, credentials, or audio data.
- Evidence: build-311 diagnostics record successful FLAC album/track writes, explicit file deletions, replacement
  downloads, and a full forced scan overlapping metadata saves. The scan can publish a stale `tracks` snapshot after
  targeted saves; replacement downloads also derive their folder and fresh file from remote album metadata.
- Invariants: never delete or move user files during metadata editing; preserve explicit Delete from iPhone behavior;
  replacement downloads must remain deterministic; local library grouping must reflect the current file tags after a
  successful save; external edits must be reread only through an explicit or safely coordinated scan.
- Behavior oracle: edit a downloaded FLAC album to `Yugen`, verify every file’s tag and the Library album after save,
  run a concurrent scan, then replace the download and verify the documented remote-metadata behavior without stale
  library rows or unintended deletion.
- Automated acceptance: source-contract regression checks, `Tools/ProjectStateCheck.sh --source-only`,
  `git diff --check`, and strict simulator/generic-device Swift 6 preflight passed. The preflight emitted only the
  known no-scheme destination, vendored hlslparser, and AppIntents SSU archive warnings. No device install or launch
  was performed for this source change.
- Rollback: revert the eventual scan-generation/metadata-refresh coordination change and any replacement-policy change
  as one isolated commit.

### R-LYRICS-LRCLIB-SEARCH-FALLBACK — Recover lyrics when exact metadata lookup misses

- Status: search-first fix implemented, strictly validated, signed as build 311, and installed in place; physical
  runtime acceptance remains user-run.
- Owner: `LyricsService.swift` owns the opt-in provider-specific fallback; `LyricsStore` continues to own
  cancellation and in-memory result caching.
- Goal: query the corresponding user-configured `/api/search` path first for LRCLIB-compatible profiles and select
  only a candidate matching title, artist, optional album, and duration tolerance; retain bounded ±5-second `/get`
  attempts when search does not produce a match.
- Invariants: no built-in endpoint is enabled or added; the fallback is available only for a provider named LRCLIB
  using a GET endpoint whose final path component is `get`; unrelated providers, POST profiles, authorization, parsing,
  and current-track-only behavior remain unchanged.
- Behavior oracle: the live Kolm / Yugen / Mycelia search record must be selected even when `/api/get` returns 404
  for the app’s duration, while a same-title result for another artist or album must be rejected.
- Automated acceptance: source-contract regression checks, Swift parsing, `git diff --check`, project-state checks,
  and strict preflight passed. Signed legacy-bundle compatibility build 2.1/build 311 passed deep strict
  code-signature verification and was installed in place on SaiyanDenawa without uninstalling or launching. Runtime
  acceptance of Mycelia remains user-run.
- Rollback: revert the LRCLIB search-candidate model, derived search request, and matching path in `LyricsService.swift`.

### R-LYRICS-DURATION-TOLERANCE — Accept lyrics matches within ±5 seconds

- Status: source implementation, strict preflight, signed compatibility build, and in-place device installation
  completed; the uploaded App Store build 308 does not contain this follow-up.
- Owner: `LyricsService.swift` owns the current-track provider request and bounded duration fallback; `LyricsStore`
  continues to own cancellation and in-memory result caching.
- Goal: preserve the exact-duration lookup while allowing a configured LRCLIB-compatible provider to return lyrics
  when its stored duration differs from the track metadata by up to five seconds.
- Invariants: title, artist, album, provider configuration, authorization, response parsing, cancellation, and cache
  behavior remain unchanged; nearby retries are attempted only after a response contains no usable lyrics and never
  run concurrently.
- Behavior oracle: the known `Kolm` / `Yugen` / `Mycelia` record is found when the app track duration is 529 seconds
  even though LRCLIB's exact `/api/get` request currently returns 404 and a nearby duration returns the record.
- Automated acceptance: source-contract regression checks, Swift parsing, `git diff --check`, ProjectStateCheck, and
  the configured simulator/generic-device preflight passed. A signed legacy-bundle compatibility build 2.1/build 309
  passed code-signature verification and was installed in place on SaiyanDenawa without uninstalling or launching.
  Manual acceptance remains: play a previously failing Kolm track and verify synced lyrics appear without changing the
  provider profile.
- Rollback: revert the duration-candidate helper and request loop in `LyricsService.swift`; no persisted settings or
  provider profiles require migration.

### R-MEIKYO-FULL-RELEASE-1.0 — Complete processing and submit the full release

- Status: version 1.0/build 308 was exported, signed, and uploaded successfully to App Store Connect on 2026-08-09;
  Apple reports the package is processing. No physical-device installation or launch was performed.
- Evidence: Settings source-contract checks passed; strict simulator/generic-device preflight passed;
  `/Users/brian/Downloads/MeiKyo-1.0-build-308-AppStore.xcarchive` reports the MeiKyo bundle, version 1.0/build 308,
  `CFBundlePackageType = APPL`, and passed deep strict code-signature verification; Xcode reported `Upload succeeded`.
  The first archive attempt hit the existing generated-projectM path-length limit and succeeded after using a short
  explicit DerivedData path.
- Next: wait for processing, confirm 1.0/build 308 is selectable, resolve export-compliance questions, complete the
  required App Store metadata, screenshots, privacy answers, and review information, then submit the release.

## Active baseline

### R-MEIKYO-BRAND-AND-BUNDLE — Rebrand the public app while retaining Project Resonance

- Status: source implementation, regression validation, strict preflight, and unsigned source archive completed.
  Public app identity is MeiKyo 鳴響, bundle `com.briangarcia.meikyo`, version 1.0/build 308.
- Owner: `Info.plist` and Xcode build settings own the product identity; SwiftUI/App Intents own visible wording;
  Project Resonance source names, compatibility keys, storage filenames, protocol paths, and historical documents remain
  stable intentionally.
- Invariant: the new bundle is a distinct app identity. Do not claim that a MeiKyo install upgrades the old
  `com.briangarcia.Resonance.saiyandenwa` test app in place. Existing persistent Files-folder content is not deleted,
  but credentials and app-container state may need to be configured again.
- Acceptance: compiled bundle reports `com.briangarcia.meikyo`, product/display name shows MeiKyo 鳴響, visible app
  strings and App Intents use MeiKyo, the GitHub project URL and technical Resonance protocol identifiers remain valid,
  and source/build validation passes.
- Evidence: `git diff --check`, source-contract regression checks, strict simulator/generic-device preflight, signed
  archives, and App Store Connect upload passed. The final archive reports `com.briangarcia.meikyo`, `MeiKyo`,
  `MeiKyo 鳴響`, version 2.1/build 307, `CFBundlePackageType = APPL`, an empty telemetry token, and no
  collected-performance-data declaration. App Store Connect accepted the corrected package and is processing it.
- Rollback: restore the prior bundle/product/display identity and build number if the public release must continue from
  the existing installed Resonance test app.

### R-APP-PRIVACY-CONSENT-AND-RELEASE-BUILD — Require first-use privacy consent and separate telemetry testing

- Status: implementation, source validation, build/archive validation, and in-place telemetry-test installation
  completed. Build 305 is installed on SaiyanDenawa; build 306 is the saved no-telemetry public-preparation archive.
- Owner: `AppSettings.swift` owns the persisted consent and About expansion state; `RootView.swift` owns the
  non-dismissible first-launch presentation; `SettingsView.swift` owns About and the internal-build telemetry
  disclosure; `VisualizerTelemetryService.swift` owns the compile-time telemetry capability boundary.
- Invariants: the user must check the privacy-policy acknowledgment before the app begins its active refresh work;
  the consent remains available in Settings through the About section; public builds compile without telemetry and
  cannot submit events merely because a persisted toggle exists; internal telemetry builds require the private build
  configuration and bearer token.
- Acceptance: fresh launch shows the policy sheet with a disabled Continue button until the checkbox is selected;
  the full policy opens; accepting dismisses it and allows refresh; later launches do not repeat it; Settings → About
  remains at the bottom and opens the same HTTPS policy; the internal telemetry build exposes its opt-in control while
  the App Store build does not; both builds pass static and signed validation.
- Evidence: `git diff --check`, source-contract regression checks, Swift 6 simulator/generic-device preflight, signed
  Release archives, and deep strict code-signature verification passed. Build 305 was installed in place and verified
  on the phone as version 2.1/build 305. The public build 306 archive contains no telemetry compilation condition,
  no bearer token, and the public no-collected-performance-data privacy manifest. The known AppIntents SSU archive
  message and vendored hlslparser warnings were non-blocking.
- Rollback: remove the consent sheet, About category, metadata constants, and compile-time telemetry guard together;
  restore the previous settings presentation and token-gated runtime-only telemetry behavior.

Exact continuation point: wait for App Store Connect to finish processing build 307, select it for TestFlight, and
complete the metadata/review checklist. Install MeiKyo as a new app identity only when explicitly requested, then
manually verify MeiKyo branding, first-use consent, About, local Files-folder setup, QR configuration, playback,
downloads, lyrics, artwork, visualizer safety, and visualizer exit. Do not uninstall the old Resonance test app during
current-build testing.

### R-PERSISTENT-LIBRARY-FOLDER — Keep the local music tree outside the app container

- Status: coordinated-access implementation, build-304 URL-scope fix, strict preflight, signed Release/build-304
  validation, deep code-signature verification, and in-place installation completed. The physical phone is on build
  304; user-run external-provider/reinstall acceptance remains.
- Owner: `LibraryStore.swift` owns the active root, migration copy, scan scope, and external-folder access;
  `PersistentMusicFolderBookmarkStore.swift` owns the opaque Keychain bookmark; `SettingsView.swift` owns the picker
  and user-facing warning. `RemoteDownloadService.swift` continues to target `LibraryStore.sharedMusicFolderURL`.
- Invariant: choosing a Files folder never deletes or overwrites existing library files; the current folder tree is
  copied into the selected root, and all subsequent local-library operations use that root. The legacy Finder folder
  remains visibly identified as app-container storage that iOS removes with the app.
- Acceptance: choose an `On My iPhone` Files folder, confirm existing nested music folders are copied, scan and play
  from the selected root, download a track, edit metadata/artwork, test Remove from Library versus Delete from iPhone,
  delete/reinstall Resonance, reconnect the folder if prompted, and confirm the complete folder tree and audio remain.
  Also test iCloud Drive as a separate availability case; do not automatically delete the app during routine build
  validation.
- Rollback: restore `LibraryStore.sharedMusicFolderURL` to the app-container `Resonance Music` path and remove the
  storage section/bookmark service; no migrated external files are modified by rollback.

### R-LYRICS-PROVIDER-QR — Populate the complete lyrics provider profile from QR

- Status: source implementation and signed Release validation completed; build 301 is not installed; physical runtime
  acceptance remains user-run.
- Owner: `SettingsView.swift` owns the scanner, versioned JSON schema, HTTPS validation, field mapping, and error UI;
  `AppSettings.swift` and `LyricsService.swift` remain the storage/request owners.
- Invariant: a scan can only apply a recognized HTTPS `resonance.lyrics.provider` version-1 profile; provider tokens use
  the existing Keychain-backed setting and are never logged; no playback, visualizer, or remote-server behavior changes.
- Acceptance: Settings → Visualizer → Lyrics Provider shows the QR button even when the provider is disabled; scanning
  the LRCLIB profile fills every field, enables the provider, and reports a ready configuration. Invalid types, versions,
  HTTP endpoints, enum values, response paths, or authorization fields are rejected without applying partial settings.
- Validation: focused source assertions pass through the existing unrelated `preservingArtworkOverride` assertion;
  `git diff --check`, plist validation, strict simulator and generic-device preflight, signed arm64 Release build 2.1/
  build 301, and deep strict code-signature verification passed. No physical installation was requested.
- Rollback: remove the lyrics QR state, scanner sheet, profile parser, regression assertions, and documentation entry;
  manual provider configuration remains unchanged.

### R-VISUALIZER-EXIT-CRASH — Prevent FPS state mutation during fullscreen teardown

- Status: source fix, signed validation, and build-300 installation completed; physical runtime acceptance remains
  user-run.
- Evidence: Swift `SIGABRT` exclusivity failure on the main thread in the FPS callback during
  `UIViewRepresentable.dismantleUIView`, after `Coordinator.stop()` calls `resetFPSCounter(notify: true)`.
- Invariant: exiting fullscreen must not mutate SwiftUI `@State` from native-view dismantling; renderer, audio,
  lyrics, safety gate, FPS display while active, and telemetry behavior must remain unchanged.
- Acceptance: repeatedly exit fullscreen with the FPS counter both enabled and disabled, confirm no crash, verify the
  native stop/destroy diagnostics remain ordered, and confirm the counter still updates once per second while active.
- Validation: focused source assertions pass through the existing unrelated `preservingArtworkOverride` assertion;
  `git diff --check`, plist validation, strict simulator and generic-device preflight, signed arm64 Release build 2.1/
  build 300, deep strict code-signature verification, and in-place installation passed. The app was not launched.
- Rollback: revert only the teardown callback/lifecycle guard if the active counter or renderer lifecycle regresses.

### R-VISUALIZER-FPS-COUNTER — Optional once-per-second fullscreen FPS readout

- Status: source implementation and token-provisioned build 299 validation/install are complete; physical runtime
  acceptance remains user-run.
- Owner: `ProjectMFullscreenView.swift` owns the renderer frame window and borderless overlay; `AppSettings.swift`
  owns the persisted opt-in; `SettingsView.swift` owns the toggle and explanation.
- Invariant: the setting defaults off. When enabled, only one rounded FPS number is published once per second; no
  per-frame SwiftUI update, frame, response-time metric, or hit-test surface is added. Disabling it removes the number.
- Acceptance: Settings → Visualizer shows **Show FPS counter**; fullscreen ProjectM displays only a plain number in the
  upper-right corner after the first one-second window, updates once per second, disappears when disabled, and does not
  change controls, transitions, banishment, lyrics, audio, or rendering workload.
- Rollback: remove the persisted setting, toggle/copy, coordinator FPS window, and overlay together.

### R-VISUALIZER-SAFETY-GATE — First-use photosensitivity acknowledgment

- Status: source implementation and token-provisioned build 299 validation/install are complete; physical runtime
  acceptance remains user-run.
- Owner: `PlayerViews.swift` owns the first-use gate, checkbox, persisted acknowledgment, and Continue/Cancel behavior.
- Invariant: fullscreen ProjectM cannot start until the user checks the acknowledgment and taps Continue. Cancel keeps
  the visualizer closed; the acknowledgment persists after Continue; no medical diagnosis or user health data is stored.
- Acceptance: the first artwork tap shows the warning and unchecked square, Continue is disabled until checked, Cancel
  dismisses without opening ProjectM, Continue opens ProjectM, and later artwork taps skip the warning.
- Rollback: remove the safety state, notice view, and gate while leaving the visualizer controls unchanged.

### R-VISUALIZER-ANONYMOUS-TELEMETRY — Opt-in low-framerate banishment reports

- Status: source implementation and token-provisioned build 299 validation/install are complete; live submission still
  requires the user opt-in and an automatic low-FPS banishment.
- Owner: `VisualizerTelemetryService.swift` owns the bounded HTTPS submission queue and payload contract;
  `AppSettings.swift` owns the persisted opt-in; `SettingsView.swift` owns disclosure and presentation;
  `ProjectMFullscreenView.swift` emits one event after an automatic low-framerate banishment.
- Endpoint contract: the app posts one JSON event at a time to
  `https://music.koolkidz.us/resonance/telemetry/events`. Caddy strips the prefix and the API accepts `POST /events`
  only with `Authorization: Bearer <private build token>`, `Content-Type: application/json`, and the exact fields
  `eventId`, `presetId`, `visualization`, `banishmentReason`, `fps`, `frameGapMilliseconds`, `appBuild`, `osMajor`,
  and `occurredAt`; it returns 202 after persistence. The token is supplied with the private
  `VISUALIZER_TELEMETRY_BEARER_TOKEN` build setting and is never committed, logged, or shown in Settings.
- Privacy invariant: the toggle defaults off. The app sends only a stable event ID, bundled preset ID, ProjectM label,
  low-framerate reason and measurements, app build, iOS major version, and event time; it sends no track names, lyrics,
  credentials, configured server URLs, account/device identifiers, or audio. The app does not log the telemetry request
  or response body. The service keeps a bounded in-memory queue and submits off the renderer/main display path. The
  server agent reports that it stores no IP address, forwarded headers, account ID, track data, lyrics, URLs, or
  credentials.
- Acceptance: with the toggle off, no telemetry request is created; with it on, one automatic low-framerate event is
  submitted without changing banishment, preset selection, frame timing, or controls. Failed requests do
  not block playback or rendering. Settings clearly identifies the destination and contents of the opt-in.
- Validation: focused source assertions pass through the existing unrelated `preservingArtworkOverride` regression
  assertion; Swift 6 parsing, `git diff --check`, ProjectStateCheck, plist validation, strict simulator and
  generic-device preflight, signed arm64 Release build 2.1/build 298, PrivacyInfo inspection, bundle identity, and
  deep strict code-signature verification passed for build 298. Xcode emitted only the known vendored hlslparser
  warnings and non-blocking AppIntents SSU archive warning. Build 299 was built with the user-supplied bearer token only
  in the private build environment; the token is not stored in source, logs, or documentation. Build 299 was installed
  in place on SaiyanDenawa and the app was not launched. Live POST acceptance remains user-run.
- Rollback: remove the service, setting, Settings disclosure, ProjectM enqueue call, project registration, and
  documentation entry together; local diagnostics and existing manual/automatic banishment behavior remain intact.

- Build target: 2.1/build 299. Build 299 is installed in place on the physical phone and was not launched by Codex.

### R-BYO-LYRICS-VISUALIZER-SETTINGS — Remove the built-in lyrics provider and expose visualizer controls

- Status: source implementation and signed Release validation completed; build 294 installed in place on SaiyanDenwa;
  physical runtime acceptance remains pending.
- Owners: `AppSettings.swift` owns persisted visualizer and user-configured lyrics-provider settings; `LyricsService.swift`
  owns the generic HTTPS GET/LRC-or-JSON provider boundary; `ProjectMFullscreenView.swift` consumes the visualizer
  settings; `SettingsView.swift` owns the Visualizer section and Prototype Status presentation.
- User-visible goal: ship no bundled/default lyrics service, let users configure a documented HTTPS lyrics endpoint with
  request/auth/response mappings, place Visualizer between Finder File Sharing and Reported Errors, and document the
  current ProjectM/MilkDrop feature set in Prototype Status.
- Invariants: no lyrics request occurs while the provider is disabled or incomplete; provider tokens remain in the
  Keychain and never enter diagnostics; only HTTPS endpoints are accepted; renderer/audio/playlist/download behavior and
  existing visualizer persistence remain unchanged; Settings remains presentation-only.
- Acceptance: a fresh install has no active lyrics provider; a configured provider can receive title/artist/album/duration,
  parse plain or synchronized LRC/JSON responses, and use no/bearer/custom-header/query-token authentication; the new
  Visualizer section appears exactly between Finder File Sharing and Reported Errors; Prototype Status lists the staged
  full catalog, one-at-a-time loading, lyrics, favorites, banish/manual and low-FPS auto-banish, and diagnostics features.
- Validation: focused source assertions, Swift 6 parsing, `git diff --check`, ProjectStateCheck, strict simulator and
  generic-device preflight, signed arm64 Release build 2.1/build 294, bundle inspection, active-endpoint inspection,
  and deep strict code-signature verification passed. The full regression script still stops at its unrelated
  existing `preservingArtworkOverride` assertion. Build 294 installed in place on SaiyanDenwa; the app was not
  launched.
- Named source oracle: `LyricsService.fetch(for:configuration:)` performs no work for a missing configuration and never
  contains a built-in LRCLIB endpoint. Manual validation remains required for a user-supplied provider and Settings order.
- Rollback: revert the provider abstraction, AppSettings fields, Settings section, ProjectM bindings, build increment, and
  documentation entry as one change; existing visualizer renderer code remains untouched.

### R-MUSICBRAINZ-FIRST-USE-NOTICE — Disclose artwork-provider terms before manual search

- Status: source implementation and signed Release validation completed; physical installation remains explicitly
  unrequested.
- Owners: `AppSettings.swift` owns the persisted acknowledgment; `OnlineArtworkSearchView.swift` owns the first-use
  alert and manual-search gate; `ArtworkSearchService.swift` remains the provider/request owner.
- Invariant: no MusicBrainz or Cover Art Archive request starts from the manual artwork picker before the user sees and
  dismisses the notice; after one OK acknowledgment, existing search, thumbnail fetch, apply, and save behavior is
  unchanged. Automatic remote artwork fallback remains non-interactive and unchanged.
- Acceptance: first manual Online Artwork Search shows one OK-only notice explaining MusicBrainz metadata, Cover Art
  Archive images, meaningful User-Agent, one-request-per-second limit, core/supplementary licenses, commercial-use
  caveat, network disclosure, and user responsibility for artwork rights; subsequent searches skip it.
- Validation: focused source assertions, Swift parsing, `git diff --check`, strict simulator/generic-device preflight,
  signed Release build 2.1/293, embedded-string inspection, and deep strict code-signature verification passed. The
  full regression script still stops at its unrelated existing `preservingArtworkOverride` assertion at line 221.
  No physical installation was requested.
- Rollback: remove the acknowledgment setting, notice, and manual-search gate; restore build 292.

### R-STREAMING-PRIVATE-USE-WARNING — Disclose intended private, non-commercial streaming use

- Status: source implementation and signed Release validation completed; physical installation remains explicitly
  unrequested.
- Owner: `Resonance/Views/SettingsView.swift`; the warning is presentation-only and does not alter remote-server,
  playback, download, credential, or catalog behavior.
- Invariant: Streaming remains available for the existing HTTPS Manifest and Subsonic/Navidrome configurations;
  users retain responsibility for rights and lawful use of their server and its content.
- Acceptance: Settings → Streaming Library visibly states private, non-commercial intended use; lawful acquisition and
  entitlement to access/play/stream; user responsibility for licenses and permissions; and prohibition on unauthorized,
  infringing, public, or commercial use.
- Validation: focused source assertions, Swift parsing, `git diff --check`, strict simulator/generic-device preflight,
  signed Release build 2.1/292, embedded-string inspection, and deep strict code-signature verification passed. The
  full regression script still stops at its unrelated existing `preservingArtworkOverride` assertion at line 220.
  No physical installation was requested.
- Rollback: remove the warning block and restore build 291 if legal review rejects the proposed copy.

### R-APP-STORE-HTTPS-ONLY — Require encrypted remote-server connections

- Status: source implementation and signed Release validation completed; user-reported physical HTTPS acceptance passed.
- Owners: `RemoteURLSupport.swift`, `RemoteLibraryStore.swift`, `RemoteDownloadService.swift`, `SettingsView.swift`,
  `Track.swift`, `PlayerController.swift`, and `Resonance/Info.plist`.
- Invariant: local files, Finder sharing, audio playback, lyrics providers, artwork providers, and server credentials
  remain unchanged; only configured remote-server transport is restricted to HTTPS.
- Behavior: bare hostnames use HTTPS; typed or QR-provided `http://` addresses are rejected; manifest stream/artwork,
  Subsonic API/stream/artwork, playback, cached manifest, and download URLs cannot use HTTP.
- Acceptance: `music.koolkidz.us` connects over HTTPS; an explicit `http://` address produces an actionable error;
  malformed/non-HTTPS server URLs fail before network access; cached insecure manifest links are discarded or sanitized.
- Validation: focused HTTPS contract passed; `git diff --check`, strict simulator/generic-device preflight, signed
  Release build 2.1/291, compiled ATS inspection, and deep code-signature verification passed. The phone remains on
  an unverified installed build; the user reports that `http://` is rejected and `music.koolkidz.us` works over HTTPS.
- Rollback: restore the ATS exceptions and the prior HTTP-capable URL construction only if HTTPS-only deployment is
  rejected for a documented local-server requirement.

### R-PROJECTM-LYRICS-LAST-WORD — Preserve the complete rasterized lyric line

- Status: source fix and validation completed; physical-device acceptance remains user-run.
- Owner: `Resonance/ThirdParty/ProjectM/vendor/projectm/libprojectM-4.1.7/src/libprojectM/Renderer/MilkdropText.cpp`
  owns the native lyric mesh and vertical texture coverage; `ResonanceProjectMBridge.mm` owns rasterization.
- Invariant: lyric text returned by the existing LRCLIB parser and the existing fade/feedback animation remain
  unchanged; only the native mesh's visible texture region may change.
- Baseline oracle: the supplied phone screenshots show “Liar, lawyer; mirror / show me, what's the” and
  “Kangaroo done hung / the guilty with the” while the final words are present in the lyric line but outside the
  mesh's sampled vertical range. The baseline source uses `VerticalClip = 0.75f`.
- Acceptance: the full rasterized lyric texture is sampled, including a third wrapped line when required; the two
  supplied examples display `difference.` and `innocent`; no lyric-service, timing, playback, or ProjectM preset
  behavior changes.
- Validation: focused lyric-render contract passed; equivalent before/after workload manifests matched; `git diff
  --check`, strict simulator/generic-device preflight, and signed Release compilation passed. The full regression script
  still stops at its unrelated pre-existing `preservingArtworkOverride` assertion at embedded Python line 219.
- Rollback: restore `VerticalClip` to `0.75f` and its prior comment without changing lyric parsing or rasterization.

### R-ARTWORK-LYRICS-PROVIDER-TERMS — Remove iTunes and document provider compliance

- Status: completed in source and documentation; physical-device artwork/lyrics acceptance remains user-run; playback,
  lyrics parsing, download behavior, and local artwork overrides are
  unchanged.
- Owners: `ArtworkSearchService.swift` for provider requests and ranking; `SettingsView.swift` and release documents
  for provider disclosure; `LyricsService.swift` requires a compliant LRCLIB User-Agent and rate-limit behavior.
- Invariants: MusicBrainz/Cover Art Archive remains the only online artwork-search path; no provider credentials or
  copyrighted media are bundled; local/server artwork paths remain available; all requests remain cancellable.
- Acceptance: no active iTunes endpoint, provider label, model, or positive provider assertion remains; negative
  regression guards may mention the retired provider; MusicBrainz uses a meaningful User-Agent and no more than one API
  call per second; LRCLIB identifies Resonance and honors 429/Retry-After; provider terms and commercial-use status are
  recorded in the handoff.
- Validation: provider-specific regression assertions passed before the pre-existing unrelated
  `preservingArtworkOverride` assertion stopped `Tools/RegressionChecks.sh`; `git diff --check`, project-state checks,
  privacy-manifest lint, and the simulator Debug build passed. No physical-device install or launch was requested.
- Rollback: restore the iTunes provider implementation and provider disclosure text without changing artwork storage
  or local/server artwork behavior.

### R-APP-STORE-READINESS-DOCUMENTATION — Prepare privacy and review materials

- Status: completed for the documentation/manifest scope; no ATS or storage-policy behavior change in this pass.
- Owners: `Resonance/PrivacyInfo.xcprivacy` for required-reason API declarations; `Docs/PRIVACY-POLICY.md` for the
  public policy draft; `Docs/APP-PRIVACY-QUESTIONNAIRE.md` for App Store Connect answers; and
  `Docs/APP-REVIEW-SERVER-SETUP.md` for the review backend procedure.
- Invariants: local music remains in the app container, credentials remain in the Keychain, no credentials or
  authenticated URLs enter source or documentation, and the current ProjectM/audio behavior is untouched.
- Acceptance: `PrivacyInfo.xcprivacy` passed `plutil -lint`, is registered in the app Resources phase, and was found
  in the built simulator app. The three release documents contain no credentials or authenticated URLs; the project
  parsed and built successfully. Provider-retention, provider terms, and content-rights decisions remain explicitly
  marked where evidence is still required.
- Validation: simulator Debug build succeeded at `/tmp/resonance-privacy-manifest-build`; the build emitted the
  existing empty supported-platforms destination warning and vendored hlslparser format/deprecation warnings. No
  device install or launch was performed.
- Rollback: remove the new manifest resource and documentation-only files; no user data migration is involved.

### R-PROJECTM-BANISH-TELEMETRY — Recover manual versus low-FPS removals

- Status: planned; no behavior change in build 290.
- Current evidence: manual removal emits `projectm.preset.banished`; automatic removal emits
  `projectm.preset.auto_banished` with measured FPS and duration, but both currently persist in the same banished
  set and diagnostics identify the preset only with process-randomized `hashValue` output.
- Required design: add a stable bundled preset identifier plus `reason=manual|low_fps`, FPS/duration when applicable,
  and a privacy-safe timestamp/event record so later logs can identify candidates for optimization without storing
  credentials, URLs, private media, or authenticated paths.
- Acceptance: collect a substantial automatic-rotation sample, recover the stable preset IDs and low-FPS metrics from
  the diagnostic log, and verify manually banished entries remain distinguishable.

### R-PROJECTM-LYRICS-HORIZONTAL-FIT — Keep long synced lyric lines on-screen

- Status: source implemented; build 290 strictly compiled and signed; physical runtime acceptance pending.
- Owner: `ResonanceProjectMBridge.mm` lyric rasterizer and vendored `MilkdropText.cpp` mesh.
- Failure evidence: build 289 rasterized lyrics into a 1024×256 canvas and used an uncapped MilkDrop title-entry
  scale. The user reported final words disappearing from many verses.
- Lever: use a 1536px lyric canvas, a bounded `0.68` native display band, and a `1.0` maximum entry scale. Lyric
  timing, text identity, feedback burn, preset rotation, audio, and catalog behavior remain unchanged.
- Automated acceptance: ProjectM source contracts passed, strict preflight passed, signed Release build 2.1/290
  passed, and deep signature verification passed. Physical acceptance remains user-run.
- Manual oracle: with a long synced lyric track, verify the first second of at least ten lyric lines, especially the
  rightmost word; then reveal/hide controls and change presets while lyrics remain enabled.
- Rollback: revert the focused lyric-layout patch and rebuild the retained build-289 artifact.

### R-PROJECTM-FULL-CATALOG-STAGED-ROTATION — Cycle the complete archive without live catalog pressure

- Status: implemented, strictly compiled, signed, installed in place as build 289; physical runtime acceptance pending.
- Owner: `ProjectMPresetCatalogStore` and `ProjectMFullscreenView` active-preset boundary.
- Failure evidence: the first build-289 implementation kept all 9,795 archive entries in fullscreen state; the user
  reported the old lock returned, and its device log contains repeated 100–190 ms gaps around transitions and controls.
- Lever: the actor owns the complete index; fullscreen state retains only the focused startup list and one active
  archive item. Timer/swipe advances select one catalog entry at a time, with archive hard cuts and no full-array view
  invalidation.
- Preserved invariants: focused startup IDs/order, renderer/audio/lyrics/download paths, favorites, banishment,
  persistence, bundled resources, and Browse search. Automatic rotation now includes all 9,795 bundled presets.
- Presentation: native lyric mesh width is half-size (`0.44`); browser names remain compact and multi-line.
- Automated acceptance: Swift parse, strict preflight, signed Release build, deep signature verification, in-place
  install, and `devicectl` version check for `2.1/289` passed. The full regression script remains blocked by its
  unrelated `preservingArtworkOverride` assertion.
- Manual oracle: leave auto-cycle running until an archive preset appears, then reveal/hide controls, Favorite, swipe,
  verify lyric size, open Browse/search, and confirm no lock or sustained stalls. Pull fresh diagnostics afterward.
- Rollback: restore the focused-only build-288 source if full-catalog rotation fails the named workload.

### R-PROJECTM-MATCH-STANDALONE-FOCUSED-CATALOG — Match ProjectMD's smooth live workload

- Status: implemented, strictly validated, signed, and installed as build 288; physical runtime acceptance pending.
- Owner: `ProjectMFullscreenView.loadPresets` live ProjectM catalog boundary.
- Evidence: fresh build-287 SaiyanDenawa diagnostics contain Cream of the Crop preset paths during normal rotation and
  record 84 `projectm.frame.stall` events with 183.4 ms p50 and 445.4 ms p95 gaps. Standalone ProjectMD build 42 is
  user-confirmed flawless after its live catalog was narrowed to the ten focused fixtures.
- Lever: return the focused ten-entry fixture list from Resonance's detached preset loader and stop enumerating the
  9,795 additional Cream of the Crop files for ordinary fullscreen rotation.
- Preserved invariants: focused preset IDs/order, rendering, transitions, lyrics, controls, favorites, banishment,
  shuffle behavior over the available set, playback, downloads, persistence, and bundled resources.
- Named workload: `evidence/projectm-focused-catalog-round-08`, five warm physical repetitions with downloads stopped,
  music paused, fullscreen controls and five preset transitions.
- Automated acceptance: focused source contracts, Swift 6 strict simulator/generic-device preflight, `git diff --check`,
  signed Release build, deep signature verification, in-place device installation, and `devicectl` verification of
  Resonance `2.1/288` alongside ProjectMD `0.2.0/42`.
- Manual oracle: the active list remains the focused ten, controls reveal/hide immediately, and five transitions stay
  fluid with no new 100 ms frame stalls. Retrieve a fresh credential-free diagnostics log after the run.
- Rollback: revert the single `return focusedPresets` catalog-scope change in `ProjectMFullscreenView.swift`.

### R-PROJECTM-BOUND-MAIN-THREAD-RENDER — Bound synchronous ProjectM work during interaction

- Status: implemented, signed, and installed as build 287; physical validation pending.
- Owner: `ProjectMFullscreenGLView.Coordinator` render budget and preset lifecycle.
- Evidence: build-286 diagnostics disproved the stale-FBO theory: the post-test log had no new GL error or incomplete
  framebuffer events and the user reported no behavior change. The same log measured 23–26 ms frames at 0.75 scale;
  earlier pathological presets blocked the main run loop for 183–400 ms. The renderer is synchronous on the main
  `CADisplayLink`, so SwiftUI controls and transitions cannot run during those calls.
- Lever: use a fixed 0.5 drawable scale and keep the existing GLKView/bridge alive when auto-banishing a slow preset,
  instead of tearing down and recreating the renderer during interaction.
- Preserved invariants: audio playback, PCM handoff, lyrics content/timing, preset catalog and selection, downloads,
  favorites, app data, and in-place installation behavior.
- Automated result: strict Swift 6 simulator and generic-device preflight, signed arm64 Release compilation, deep
  strict signature verification, in-place installation, and device version verification passed. The full regression
  script still stops at its unrelated existing Streaming alphabet assertion.
- Manual oracle: with downloads stopped and music paused, reveal/hide controls repeatedly, tap Favorite, switch presets,
  use Banish, and dismiss/reopen fullscreen. Compare control latency, visualization continuity, and fresh diagnostics
  against build 286.
- Rollback: restore the 0.75 drawable scale and the prior auto-banish renderer-generation toggle.

### R-PROJECTM-BOUND-PCM-VISUALIZATION-WINDOW — Match ProjectMD's bounded audio feed

- Status: implemented, signed, and installed as build 286; physical validation pending.
- Owner: `ResonanceProjectMBridge.mm` PCM staging boundary.
- Evidence: the build-286 no-download reproduction froze immediately after controls appeared; prior logs also showed
  high heat and 2–5 FPS after ProjectM integration. Resonance drained all pending PCM scalars per render, whereas
  ProjectMD submits a fixed 480-frame window.
- Lever: before `projectm_pcm_add_float`, discard stale backlog and cap each visualization submission at 480 frames,
  matching ProjectMD. Playback continues through the existing audio graph and only visualization history is dropped.
- Preserved invariants: audio playback, channel order, preset selection, lyrics, renderer lifecycle, download transfer,
  queue state, and the current ProjectM display surface.
- Manual oracle: with downloads stopped, run ProjectM for five minutes, reveal/hide controls repeatedly, switch presets,
  and dismiss/reopen fullscreen. Confirm no heat spike, no interaction lock, continuous visualization, and uninterrupted
  audio. Retrieve diagnostics and compare frame windows and PCM submitted/consumed counts.
- Rollback: restore the prior full-backlog `Drain` behavior and renderer scratch capacity.

### R-PROJECTM-SUSPEND-HIGH-FREQUENCY-LYRICS-OBSERVATION — Keep no-download fullscreen controls responsive

- Status: implemented in source; strict simulator and generic-device preflight passed; physical runtime pending.
- Owner: `ProjectMLyricsFeedHost` in `ProjectMFullscreenView.swift`.
- Evidence: the latest no-download device session recorded 120-frame ProjectM windows with approximately 6–18 ms
  render times and no sustained frame gaps while presets and controls changed. Resonance uniquely observed the
  120 ms `PlaybackProgress` publisher from a zero-size SwiftUI host inside the fullscreen hierarchy.
- Lever: replace that high-frequency observation with 250 ms elapsed anchors from `PlayerController`; lyric progress
  remains smooth through `ProjectMLyricsFeed` interpolation, while control and preset state no longer reconciles at
  the playback timer cadence.
- Preserved invariants: playback state, audio graph, PCM handoff, ProjectM render path, preset transitions, lyrics
  content, download transfers, and queue behavior.
- Manual oracle: with downloads stopped, verify control reveal/hide, lyrics toggle, playback toggle, favorite/banish,
  preset switches, automatic cycling, and fullscreen dismissal remain responsive while visualization stays fluid.
- Rollback: restore the `PlaybackProgress` environment object and 120 ms publisher subscription in the lyrics host.

### R-PROJECTM-SUSPEND-DOWNLOAD-PROGRESS — Suspend presentation-only progress during fullscreen ProjectM

- Status: implementation in progress; motivated by the build-286 device reproduction.
- Owner: `RemoteDownloadService.swift` progress-delivery boundary.
- Goal: keep fullscreen ProjectM's main display path free of download progress UI publications while preserving
  transfer, completion, failure, queue, persistence, and cancellation behavior.
- Evidence: the latest Resonance log records 2–5 FPS behavior without a completed performance window; the earlier
  failed slice measured 10.29 ms average native render time but 394.8–481.6 ms display gaps. Standalone ProjectMD
  has no corresponding download-progress publisher. Build 286 still posts background progress to the main actor and
  updates `RemoteDownloadLiveProgress` while ProjectM is active.
- Smallest causal lever: suppress only foreground/background byte-progress notifications and live-progress updates
  while `ProjectMActivityCoordinator` reports fullscreen active. Track completion/failure callbacks remain enabled.
- Preserved invariants: network transfer bytes, throughput, completion/failure finalization, queue IDs/order/state,
  cancellation, resume, replacement behavior, persistence, library refresh, playback, and ProjectM renderer code.
- Behavior oracle: while a large download batch runs, fullscreen ProjectM should remain near its normal frame cadence;
  after dismissal, the download overlay resumes progress and all completed files remain indexed exactly once.
- Rollback: remove the three fullscreen-active progress guards and reinstall the prior build if required.

### R-PROJECTM-DOWNLOAD-PROGRESS-ISOLATION — Keep byte progress off the full queue publisher

- Status: implemented, strictly validated, signed, and installed as build 286; physical runtime acceptance pending.
- Owner: `RemoteDownloadManager` live byte-progress publication and `RemoteDownloadBanner` presentation.
- Evidence: the build-285 SaiyanDenawa log records 23 ProjectM display-link stalls in the latest reproduction with a
  403.8 ms median gap (394.8–481.6 ms) while ProjectM render and lyric-upload work remained only a few milliseconds.
  Background progress is correctly reduced to a 400 ms cadence, but every accepted event still changes several
  `@Published` scalars and rewrites the full `itemProgress` dictionary and `downloadQueue` array on the main actor.
- Lever: publish byte progress through one small active-transfer object; mutate and publish the full queue only when a
  track starts, completes, fails, is cancelled, or is requeued.
- Preserved invariants: network requests and bytes, one-file background concurrency, queue order and IDs, cancellation,
  resume, replacement choices, persisted queue semantics, completion finalization, metadata parsing, library refresh,
  playback, ProjectM rendering quality, and the 400 ms visible progress cadence.
- Manual oracle: with the same large local-LAN download batch active, open ProjectM for at least 20 seconds and confirm
  normal interaction and near-60 FPS behavior rather than a repeated 400 ms cadence. Expand the queue separately and
  confirm the active row and compact byte counter continue to advance; test cancel and requeue.
- Rollback: restore live progress to the manager's scalar/full-collection publishers, or reinstall build 285 in place
  without uninstalling.
- Automated result: focused contracts, Swift parsing, `git diff --check`, workload equivalence, strict simulator and
  generic-device preflight, signed arm64 Release compilation, deep strict signature verification, in-place installation,
  and device build verification passed. The full regression script reaches the unrelated Streaming alphabet assertion
  at line 196.

### R-BACKGROUND-DOWNLOAD-ENERGY — Coalesce background progress before main-actor publication

- Status: implemented, validated, signed, and installed as build 285; physical thermal acceptance remains user-run.
- Owner: `RemoteBackgroundDownloadSession` progress delivery in `RemoteDownloadService.swift`.
- Evidence: SaiyanDenawa has `experimentalBackgroundDownloads=true`. The background delegate handled every network
  callback by decoding its persisted record and publishing through NotificationCenter/main actor/SwiftUI, while the
  foreground path already used a 400 ms cadence.
- Lever: throttle background progress to one publication per 400 ms plus the final update, use the task description for
  track identity, and emit one privacy-safe callback/publication summary per completed or failed file.
- Preserved invariants: transfer speed, one-file background concurrency, cancellation, resume, duplicate behavior,
  queue ordering, completion finalization, metadata parsing, library indexing, playback, and ProjectM quality.
- Automated result: focused contracts, Swift parse, `git diff --check`, strict simulator/generic-device preflight,
  signed Release build, strict signature verification, in-place install, and device version verification passed. The
  full regression script reaches the unrelated existing Streaming alphabet assertion at line 196.
- Manual oracle: after cooldown, download several uncached tracks with background downloads enabled. Confirm normal
  speed and queue progress with materially less heat and responsive navigation. If stable, repeat while ProjectM is
  active and confirm progress/completion no longer causes a visualizer lock. Retrieve the diagnostics log and verify
  `download.background_progress.summary` has far fewer publications than callbacks.
- Rollback: restore per-callback `record(for:)` lookup and NotificationCenter publication, or reinstall build 284 in
  place without uninstalling.

### R-PROJECTM-PCM-ENERGY — Remove Resonance-only PCM allocation and lock contention

- Status: build 284 remains included, but physical thermal acceptance failed; build 285 addresses the independently
  confirmed download-side energy path.
- Owner: `ResonanceProjectMBridge.mm` at the audio-to-ProjectM staging boundary. `GaplessAudioEngine.swift`, the
  playback graph, and the ProjectM renderer remain unchanged.
- Goal: replace the Resonance-only mutex plus grow/swap/destroy `std::vector` handoff with the bounded, preallocated,
  single-producer/single-consumer PCM ring already proven by standalone ProjectMD.
- Preserved invariants: PCM is accepted only while the native fullscreen renderer exists; input channel count and
  sample order are unchanged; the existing ProjectM PCM submission API is unchanged; playback, explicit 5.1
  routing, meter calculation, preset selection, lyrics, 60 FPS target, drawable scale, and transition behavior remain
  unchanged.
- Named workload: `projectm-pcm-staging`; play one local stereo track, open the same light preset for five minutes,
  dismiss fullscreen for one minute, then repeat with one heavy preset after the phone cools.
- Behavior oracle: the visualization continues reacting to audio; playback remains uninterrupted; fullscreen teardown
  stops PCM acceptance; no samples are allocated, copied through a growable container, or protected by a mutex on the
  audio/render hot path.
- Automated acceptance: focused source contracts, `Tools/RegressionChecks.sh`, `git diff --check`, strict simulator
  and generic-device preflight, signed Release compilation, strict signature verification, and in-place installation.
- Automated result: focused PCM contracts, equivalent workload manifests, `git diff --check`, strict simulator and
  generic-device preflight, signed Release compilation, strict signature verification, in-place installation, and
  device version verification passed. The full regression script reaches its unrelated existing Streaming alphabet
  assertion at line 196 after the new PCM checks pass.
- Manual acceptance: run build 284 on SaiyanDenawa for heat and battery drain under the named workload, then inspect
  privacy-safe PCM and renderer summaries. No standalone ProjectMD comparison is required. Physical thermal improvement
  is not inferred from compilation or installation.
- Rollback: restore the build-283 `gAudioMutex`/`gPendingPCM` implementation or reinstall build 283 in place without
  uninstalling.

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

### R-PROJECTM-NATIVE-LYRICS — Port MilkDrop song-title feedback into ProjectM

- Status: implemented, strictly built, signed, and installed in place in build 280; physical runtime acceptance pending.
  Build 279's custom SwiftUI dissolve is rejected.
- Goal: display the current timestamped LRCLIB line at the center using MilkDrop 2's original song-title mesh, then
  inject the completed line into the preset feedback buffer so the active visualization manipulates it on later frames.
- Owners: `LyricsService.swift` keeps LRCLIB/LRC data; `ProjectMFullscreenView.swift` forwards only the current lyric
  identity and timing; `ResonanceProjectMBridge.mm` rasterizes text at line changes; vendored ProjectM owns the OpenGL
  texture, original 16-by-8 mesh animation, and feedback injection stage.
- Cross-boundary transition: a lightweight main-actor lyric feed transfers current line/timing to the GL coordinator;
  a detached preparation task rasterizes only the changed line, and the current GL context uploads it and supplies
  progress without making SwiftUI draw text.
- Preserved invariants: audio routing and playback controls, preset catalog/order, shuffle/favorite/banish semantics,
  fullscreen rotation, app-private ProjectMD assets, renderer teardown while inactive, and existing LRCLIB lookup/cache.
- Named workload: `projectm-controls-lyrics-transitions`, one warmup and five repetitions of show controls, enable lyrics,
  hide controls, and change preset while audio plays.
- Behavior oracle: one centered current lyric line; no previous/next overlay; at the next timestamp the completed line is
  visible in the ProjectM feedback and is subsequently warped by the preset; audio and preset advance remain correct.
- Automated acceptance: Swift parse, focused native lyric/performance source contracts, strict simulator/device
  preflight, signed Release build, signature verification, and in-place install passed. A clean strict simulator build
  also passed with the generated ProjectM framework absent. The full regression script still reaches an unrelated,
  pre-existing stale Streaming alphabet assertion; no ProjectM contract failed.
- Manual acceptance: user runs the named workload on SaiyanDenawa and confirms the feedback behavior, no control/lyric
  hitch, smooth transitions, orientation, audio response, and acceptable temperature. Physical runtime is not inferred
  from build/install evidence.
- Rollback: restore build 279 sources or reinstall its signed artifact without uninstalling.

### R-PROJECTM-STALLS — Remove measured renderer contention without reducing preset behavior

- Status: build-280 implementation complete; evidence round 01 physical after-sample pending.
- Owner: ProjectM GL coordinator, native bridge, and vendored ProjectM integration only.
- Applied levers: ignore unchanged texture search paths; remove synchronous native-render GL state/pixel probes;
  stop transition-driven drawable-scale oscillation; move lyric glyph rasterization outside the GL display callback.
- Performance oracle: equivalent workload and preset sequence, fewer long frame intervals and render-target resizes,
  unchanged 60 FPS target, unchanged 0.75 drawable scale, and no black/slanted/partial transition regression.
- Rollback: revert each isolated lever independently.

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

### R-ALPHABET-TOUCH-PROBE — Identify touches lost before the alphabet gesture

- Status: diagnostic probe installed in place on `SaiyanDenwa`; awaiting user reproduction.
- Owner: `StreamingLibraryView.swift` root simultaneous gesture observer.
- Evidence target: compare `streaming.alphabetProbe.begin/end` with `alphabet.touch.begin/end` to identify touches received by Streaming but not claimed by `VerticalArtistIndex`.
- Manual acceptance: enable Debugging Mode, reproduce failed and successful left-handed Streaming alphabet attempts in Artists and Albums, then retrieve `Documents/Resonance-Diagnostics.log`.

### R-ALPHABET-STREAM-DISPATCH — Match local direct section jumps

- Status: implemented and installed in place on `SaiyanDenwa`; physical runtime acceptance remains user-run.
- Owner: `StreamingLibraryView.swift` Streaming Artists, Albums, and artist-album alphabet callbacks.
- Change: removed per-update `withAnimation` wrappers so Streaming uses the same direct `ScrollViewProxy.scrollTo` dispatch as local Library.
- Preserved invariants: 48-point left-handed Streaming hit strip, section IDs, selection bubble, haptics, and ordinary content scrolling.
- Automated evidence: `git diff --check`, Swift 6 strict simulator/generic-device preflight, signed arm64 Release build, deep signature verification, and in-place device installation passed.

### R-ALPHABET-EDGE-GEOMETRY — Anchor Streaming index to the screen edge

- Status: implemented and installed in place on `SaiyanDenwa`; physical runtime acceptance remains user-run.
- Owner: `StreamingLibraryView.swift` Streaming Artists, Albums, and artist-album alphabet ZStacks.
- Change: explicitly expand each index container to available width and align it to the active handedness edge.
- Evidence: device diagnostics measured the previous left-handed frame at global x `-7...41`; signed 2.0/268 installation passed after the geometry change.
- Manual acceptance: verify the visible letters and their hit area share the same left-edge origin in Streaming Artists, Albums, and artist-album views; repeat right-handed mode afterward.

### R-ALPHABET-BACK-SWIPE-ARBITRATION — Remove the Streaming left-edge gesture conflict

- Status: implemented and installed in place on `SaiyanDenawa`; physical runtime acceptance remains user-run.
- Owner: `StreamingLibraryView.swift` root back-swipe overlay and shared `VerticalArtistIndex` gesture arbitration.
- Root cause: a full-height 24-point leading overlay sat above the Streaming alphabet, blocking its leftmost hit area.
- Change: use simultaneous gesture recognition for the overlay so vertical alphabet touches reach the high-priority index
  while horizontal drags greater than 70 points retain root back navigation.
- Automated evidence: signed arm64 Release build, strict deep code-signature verification, and in-place version
  `2.0`/build `268` installation passed. The app was not launched by Codex.
- Manual acceptance: test far-left alphabet taps and vertical drags in Streaming Artists, Albums, and artist-album views;
  test root horizontal back swipe, ordinary scrolling, and right-handed mode.

### R-ALPHABET-COPY-LOCAL-SHELL — Use the known-good Local browse layout for Streaming

- Status: implemented and installed in place on `SaiyanDenawa`; physical runtime acceptance remains user-run.
- Owner: `StreamingLibraryView.swift` remote artist, album, and artist-album browse containers.
- Change: copied the Local alphabet container behavior by removing Streaming-only hit-width overrides, full-size frames,
  and the leading overlay that participated in hit testing. Remote-specific content and navigation remain intact.
- Automated evidence: `git diff --check`, signed arm64 Release build, strict deep signature verification, and in-place
  version `2.0`/build `268` installation passed. The app was not launched by Codex.
- Manual acceptance: compare Local and Streaming alphabet taps/drags at the far-left edge in every browse mode, then
  verify ordinary scrolling, navigation, and right-handed mode.

### R-MINIMAL-TRANSPARENT-ICON-LINE — Remove underline from Minimal Transparent toolbar icons

- Status: implemented and installed on the iPhone 17 Pro simulator; physical runtime acceptance remains user-run.
- Owner: shared `ResonanceToolbarIconButton` and `ResonanceToolbarIconLabel` components in `RootView.swift`.
- Change: removed only the Minimal Transparent bottom capsule from icon buttons and passive icon labels; text and hero
  button treatments remain unchanged.
- Automated evidence: `git diff --check`, signed arm64 Release build, simulator Debug build, and simulator install passed.
- Manual acceptance: inspect all Minimal Transparent toolbar icon locations and verify other themes and non-icon buttons.

### R-MINIMAL-TRANSPARENT-ALL-BUTTONS — Remove remaining Minimal Transparent underlines

- Status: implemented and installed on the iPhone 17 Pro simulator; physical runtime acceptance remains user-run.
- Owner: shared button renderers in `RootView.swift` and `ResonanceHeroButtonStyle` description in `AppSettings.swift`.
- Change: removed Minimal Transparent underline capsules from hierarchy, hero action, hero menu, and text buttons in
  addition to toolbar icon buttons.
- Automated evidence: `git diff --check`, simulator Debug build, and simulator install passed.
- Manual acceptance: inspect every Minimal Transparent button surface and confirm no underline remains; verify other
  visual styles are unchanged.

### R-WATERFALL-CUSTOM-CROP — Save selected Waterfall background region

- Status: implemented; final signed 2.0/build 268 installed in place on `SaiyanDenawa`; physical runtime acceptance
  remains user-run.
- Owner: `SettingsView.swift` crop presentation and `AppSettings.swift` Waterfall background persistence, with the
  existing page-level backdrop in `RootView.swift`.
- Change: Waterfall Meadow accepts images at least 1206 × 2622 pixels, supports pan/pinch selection, normalizes image
  orientation, and saves the selected result as a new 1206 × 2622 JPEG without changing layout or other themes.
- Invariants: the selected background remains private to the device, existing app data is preserved, and Restore
  Waterfall Meadow removes the override.
- Evidence: `git diff --check`, signed arm64 Release build, deep strict code-signature verification, and in-place
  `devicectl` installation passed. The app was not launched by Codex.
- Manual acceptance: import an image, place a distinctive feature inside the crop frame, tap Use This Crop, verify the
  saved background matches the selection and fills the canvas without distortion, then test Restore Waterfall Meadow.

### R-BRUSHED-METAL-SINGLE-SURFACE — Remove decorative hardware from Brushed Metal

- Status: implemented; signed device build pending installation on `SaiyanDenawa`.
- Owner: `Resonance/Assets.xcassets/ThemeBrushedMetal.imageset/brushed-metal.png` only.
- Change: replace the hardware-panel illustration with a single continuous 1206 × 2622 brushed-metal surface.
- Invariants: preserve the existing theme identifier, palette, layout, controls, navigation, and all other theme assets.
- Acceptance oracle: asset dimensions remain 1206 × 2622 and visual inspection shows only uninterrupted brushed metal.
- Automated acceptance: `git diff --check`, `Tools/RegressionChecks.sh`, strict preflight, signed Release build, and
  deep code-signature verification; install in place without launching the physical app.
- Rollback: revert the single asset commit.

### R-PSYCHEDELIC-DIM-LAYER — Restore the prior Psychedelic readability veil

- Status: implemented and installed on the configured iPhone 17 Pro simulator.
- Owner: `Resonance/Views/RootView.swift`, `ResonanceThemeBackdrop`.
- Change: restore the historical `0.42` artwork opacity and `0.12` themed-gradient veil for Psychedelic only.
- Invariants: preserve the Psychedelic artwork, layout, controls, navigation, and all other theme appearance.
- Acceptance oracle: Psychedelic is visibly dimmer and more readable; Waterfall, Brushed Metal, Electronic, and
  Classic Wood render as before.
- Automated acceptance: `git diff --check`, simulator Debug build, and simulator install. The repository regression
  script remains blocked by its unrelated existing `LibraryStore.swift` assertion at line 172.
- Rollback: revert the single backdrop conditional.

### R-AQUA-THEME-BACKGROUNDS — Replace Gallery Light and Nocturne Glass artwork

- Status: implemented and installed on the configured iPhone 17 Pro simulator.
- Owner: `AppSettings.swift` theme image mapping and the two new image assets in `Assets.xcassets`.
- Change: Gallery Light uses the approved pale Aqua glass background; Nocturne Glass uses its dark Aqua companion.
- Invariants: preserve the existing theme names, palettes, appearance recommendations, layout, controls, and all
  other theme assets.
- Acceptance oracle: both assets remain 1206 × 2622; Gallery Light is bright/light Aqua, Nocturne Glass is dark
  navy/cyan Aqua, and no other theme changes.
- Automated acceptance: `git diff --check`, simulator Debug build, and simulator install. The repository regression
  script remains blocked by its unrelated existing `LibraryStore.swift` assertion at line 172.
- Rollback: restore `backgroundImageName` to `nil` for these two cases and remove the two image sets.

### R-LEFT-HANDED-MODE-LABEL — Clarify alphabet setting and default

- Status: implemented; simulator validation pending.
- Owner: `SettingsView.swift`, with the existing `AppSettings.leftHandedAlphabet` persisted setting.
- Change: rename the toggle to **Left Handed Mode**; retain the existing `false` default for new installations.
- Invariants: preserve existing users' saved preference and all alphabet geometry/gesture behavior.
- Acceptance oracle: Settings shows “Left Handed Mode,” a fresh default is off, and enabling it still moves the index.
- Automated acceptance: `git diff --check`, `Tools/RegressionChecks.sh`, simulator build, and simulator install.
- Rollback: restore the prior label and contract assertion.

### R-ELECTRONIC-MINIMAL-CIRCUIT — Replace busy Electronic artwork

- Status: implemented and installed on Sarah's iPhone; Chase installation pending device reachability.
- Owner: `Resonance/Assets.xcassets/ThemeElectronic.imageset/electronic.png` only.
- Change: replace the dial-heavy artwork with a minimal dark circuit board and sparse fluorescent paths.
- Invariants: preserve the Electronic theme name, palette, layout, controls, navigation, and all other themes.
- Acceptance oracle: asset dimensions remain 1206 × 2622 and visual inspection shows no dials or dense hardware.
- Automated acceptance: `git diff --check`, signed Release build with Sarah's team, deep signature verification, and
  in-place install on Sarah's paired phone. A Chase-specific artifact was manually signed with the valid Chase
  profile; CoreDevice reported Chase's phone unavailable during its install attempt. Do not launch automatically.
- Rollback: revert the single asset commit.

### R-RESONANCE-PROJECTMD-FULLSCREEN — Replace broken projectM proof of concept

- Status: partially implemented and installed; physical rendering remains unresolved.
- Goal: replace the black, diagnostics-only projectM proof of concept with the ProjectMD fullscreen visualization module. Tapping the current Playing-page album artwork opens fullscreen visualizations with ProjectMD’s single-tap controls, double-tap exit, swipe navigation, weighted favorites, persistent banish exclusions, and one-second transitions. The regular ProjectMD options/diagnostics shell is not imported.
- Owners: `PlayerViews.swift` owns the album-art entry point and fullscreen presentation; new Resonance visualization view owns transient fullscreen gestures and controls; `ResonanceProjectMBridge.mm` owns the GL framebuffer/render/audio boundary; bundled preset resources own catalog discovery; `PlayerController`/`GaplessAudioEngine` remain playback owners.
- Preserved invariants: playback, queue, Now Playing hierarchy, orientation policy, local/remote audio routing, credentials, and app data remain unchanged; visualization PCM input is a non-blocking projection of the existing audio tap.
- Baseline: the old idle-preset proof of concept rendered black and reported `GL_INVALID_FRAMEBUFFER_OPERATION`; the replacement now renders to the active GLKView framebuffer through projectM’s FBO API. The renderer uses the actual drawable size and the projectM library’s default mesh while the framebuffer path is stabilized. Presets and texture dependencies are namespaced under the app bundle’s `ProjectMD/` directory.
- Validation: Swift 6 strict simulator and generic-device preflight, signed arm64 Release build, deep code-signature verification, and repeated in-place installation on `SaiyanDenawa` passed for version `2.0`/build `268`. Physical testing confirms preset loading but still shows black output.
- Exact next step: retrieve device diagnostics after reproducing black output, then compare and repair Resonance’s active framebuffer/viewport/render-call sequence against `ProjectMDNativeVisualizerView.swift`. Physical visual acceptance is not complete.
- Rollback: revert the focused ProjectMD bridge/view/resource/project-file changes and restore the prior proof-of-concept entry point.
