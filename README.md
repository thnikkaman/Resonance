# Resonance Beta v1.0.9 — Multi-Disc Metadata Safety

## Current beta — 1.0.9 (build 261)

The current beta is the verified current source snapshot. It includes the layered navigation and animations,
themed Library/Streaming interfaces, cached local and remote catalogs, artwork search and persistence, targeted local
file refreshes, album-detail clearance above the mini-player, unified mini-player docking, standard FLAC front-cover
artwork parsing, and consistent Artist/Album Artist metadata editing.

The Streaming toolbar now mirrors the local Library toolbar: local-library navigation, streaming view options, playlists,
refresh, and Settings. The local file-browser/import control is intentionally omitted.

## Verified source and release artifact identity — 2026-07-31

The canonical checkout is `/Users/brian/Resonance/Resonance-Alpha-3.7.4` on
`agent/alpha-3.7.4-source`; the release source is the `Resonance-Beta-v1.0.9` publication tag recorded below. The project’s
default Xcode settings are version `1.0.9`, build `261`. See `Docs/PROJECT-STATE.md`
and run `Tools/ProjectStateCheck.sh` before making source or runtime claims.

Release source build: `1.0.9` (build `261`)

Latest device validation build: `1.0.9` (build `261`). It was signed with team `98CWMFS26R`, verified with deep strict
code-signature checks, and installed in place on `SaiyanDenawa` without uninstalling or launching the app.

## Resonance Beta v1.0.9 — 2026-07-31 UTC

The album-wide Disc Number for Every Track field now opens blank on every album. It no longer copies the first track’s
disc number, so saving an unrelated album title or metadata change cannot rewrite a multi-disc album as disc 1. Leaving
the field blank preserves each track’s existing disc number; entering a value intentionally applies it to every track.

Validation passed `Tools/RegressionChecks.sh`, `git diff --check`, and strict simulator compilation. The signed physical
Release build and GitHub publication are recorded below.

The signed Release build for `1.0.9`/build `261` passed deep strict code-signature verification and was installed in
place on `SaiyanDenawa` without uninstalling or launching the app. The source was committed as `3d455a0`, pushed to
`agent/alpha-3.7.4-source`, and published as the prerelease
`Resonance-Beta-v1.0.9`: https://github.com/thnikkaman/Resonance/releases/tag/Resonance-Beta-v1.0.9.

## Resonance Beta v1.0.8 — 2026-07-31 UTC

This beta stages artwork chosen from Search Online Artwork while a metadata editor is open. Canceling the metadata
editor discards the selection; the editor’s Save commits it. Automatic artwork recommendations during library
ingestion remain unchanged. Metadata editors now expose both Artist and Album Artist fields consistently: track edits
write one file, album edits write every track in the album, and artist edits write every represented track. Read-only
track names, counts, and reset/status information appear below the artwork picker. The artwork-search keyboard can be
dismissed with Done, by tapping outside the field, by submitting, or by scrolling.

Validation passed `Tools/RegressionChecks.sh`, `git diff --check`, strict simulator compilation, signed arm64 Release
compilation, deep strict code-signature verification, and in-place installation on `SaiyanDenawa`. The device reports
`1.0.8`/build `260`; the app was not launched by Codex. Manual acceptance remains: launch the installed beta, test
metadata Save versus Cancel for artwork, edit both Artist fields in track/album/artist forms, verify read-only content
is below artwork, and dismiss the artwork-search keyboard.

## GitHub publication — Resonance Beta v1.0.8 — 2026-07-31

The development branch is published at `Resonance-Beta-v1.0.8` as a GitHub prerelease. The repository’s `main` branch
is historical release-ZIP storage and has no common history with this development branch, so no pull request was
created. The release source includes the staged artwork-selection behavior, consistent Artist/Album Artist editing,
read-only metadata ordering, and keyboard dismissal described above.

## Resonance Beta v1.0.7 — 2026-07-30 UTC

Beta v1.0.7 preserves the established Library and Streaming toolbar layout while keeping Browse Files and Download as
direct button actions. Settings now centers Hero Buttons and Backend choices in custom popovers. The RGB hex color
sliders continue to update channel values but no longer request text-field editing; the keyboard appears only when a
user touches an actual red, green, or blue hex value.

Automated validation passed `Tools/RegressionChecks.sh`, `git diff --check`, `Tools/PreflightBuild.sh`, signed arm64
Release compilation, deep strict code-signature verification, and in-place device installation. The physical app was
not launched by Codex. Manual acceptance remains: launch the installed beta, verify the hex-field/slider keyboard
behavior, centered Settings options, toolbar actions, navigation, and preserved app data.

Authoritative continuation source: the `Resonance-Beta-v1.0.6` tag on `agent/alpha-3.7.4-source`,
checked out at `/Users/brian/Resonance/Resonance-Alpha-3.7.4`. This preserves the current
layered navigation, animations, Streaming toolbar/options, and synchronized custom accent-color controls. The
simulator artifact for this source is `.build/color-picker/Build/Products/Debug-iphonesimulator/Resonance.app`.

## Toolbar layout correction — simulator build 249 — 2026-07-30

The Library and Streaming roots are back to the established stacked toolbar
arrangement: leading options/playlists, centered Streaming/Local hierarchy
navigation, and refresh/settings above the second-row Browse Files/Download action.
The existing SwiftUI button actions remain unchanged; no custom hit region or
navigation redesign was added. The intermediate build 248 separate-toolbar-item
experiment was rejected because it visibly moved the controls and compressed the
centered navigation.

Regression checks, `git diff --check`, and the strict simulator/generic-device
preflight passed. Simulator build `1.0.7/249` succeeded and was installed in place
on the configured iPhone 17 Pro simulator. The simulator was not launched or
screenshot-captured by Codex, and the physical phone was not changed.

Manual continuation: launch build 249 manually. Confirm the toolbar matches the
prior arrangement, then tap Browse Files and Download to verify their existing
importer/download flows. Also verify the centered Streaming/Local navigation and
leading options/playlists controls. Do not uninstall first.

## Experimental build 110 — metadata-save regression repair

This experimental build keeps metadata saves from triggering a forced rescan of the entire local library. After a
successful FLAC or MP3 write, Resonance rereads only the files involved in that save and updates their existing
library records. This keeps the editor responsive and prevents stale whole-library read-back from making a track
number or other edited tag appear to revert. The save path also records a privacy-safe track-save diagnostic with
the writable file extension and result counts.

Manual test checklist: edit an MP3 track number and confirm it remains changed after closing and reopening the editor;
edit the title and track number of one FLAC file and confirm both the album page and an external tag reader see the
change; edit an album title and confirm the editor leaves Saving promptly; repeat with an album containing several
FLAC/MP3 files. Confirm no unrelated library contents disappear and normal playback remains available.

## Experimental build 111 — background album saves and file-artwork warning state

Album metadata editors now dismiss immediately after starting a save. The existing sequential writer and targeted
per-file reread continue in the background, with completion and failure counts recorded in privacy-safe diagnostics.
Artwork explicitly saved into FLAC or MP3 files no longer creates a Resonance-only artwork override, so it is treated as
confirmed embedded artwork and does not receive the red automatic-artwork warning border. Apply to App remains an
app-only suggested-artwork path and retains the warning border when enabled.

Manual test checklist: save artwork to a multi-track album and confirm the editor closes immediately, the files finish
updating, and the album art has no red border. Confirm Apply to App still shows the red border when the artwork-warning
setting is enabled. Verify the album title/artwork after relaunch and confirm unrelated playback and library browsing
remain responsive.

## Experimental build 112 — cache-first startup

Startup now treats the persisted local SQLite library and cached remote catalog as authoritative. With cached data
available, app activation no longer scans the local Documents tree or performs a remote server/catalog status check.
The first launch without a local library still performs the initial discovery scan, and the explicit Library/Settings
scan and Streaming refresh controls remain available for rare changes.

Manual test checklist: launch with cached local and Streaming data while observing that the Library and Streaming tabs
open without a scan/status panel; confirm cached tracks, albums, artists, and artwork appear immediately. Add or alter
a local file, verify it does not appear until the explicit Library scan, then confirm the scan finds it. Change the
remote catalog or server availability, confirm cached Streaming data remains usable at launch, and use explicit
Streaming/Settings refresh to retrieve the change or show the connection error. Verify metadata saves, downloads,
playback, tab switching, and relaunch behavior remain intact.

Version: **0.3.7.4**  
Build: **106**

Install directly over Resonance Beta v1.0.1 with the same bundle identifier and signing team. Do not delete the installed app first, because uninstalling removes local library state, playlists, metadata overrides, credentials, and the cached remote catalog.

## Observed problems

- Local playback reported: `The explicit surround downmix matrix could not be configured (OSStatus -10867)` and the process could still terminate after startup diagnostics were written.
- Streaming and Library alphabet touches did not reliably scroll to the selected artist section.
- The streaming screen's full-screen back-swipe recognizer competed with normal vertical scrolling.
- Remote artwork decoding could occupy the main actor while the streaming catalog was scrolling.
- The streaming connection header consumed browse space and could visually compete with the active grouping title during pull-down.
- The native right-side scroll indicator competed with the custom alphabet index.
- Streaming artist and album alphabet gestures did not always claim the intended touch strip or complete the section jump.
- The streaming header could disappear visually, cached catalog loading competed with the first browse render, and inconsistent Subsonic display album-artist values split one artist into multiple entries.
- The Now Playing action row could be laid out underneath the persistent tab bar, and the mini-player could cover Streaming and Settings content.
- Remote seeking could be overwritten by the playback timer, and a remote item reaching its end did not always advance the queue.
- The build-64 recordings show the remote seek labels can exceed the current track duration after fast-forwarding, even though the visual thumb is clamped at the end.
- Build 61's performance isolation removed the root-wide accent foreground modifier; this improved settings-driven redraw cost but unintentionally stopped the **Apply theme color to text** setting from styling ordinary text throughout the app.
- The explicit matrix was configured before the Matrix Mixer audio unit had started, producing `kAudioUnitErr_Uninitialized` (`-10867`) on some 5.1 files.
- The new build-66 recording showed the remote queue advancing correctly but retaining a short audible boundary interruption.
- Remote seeks to the end were still displayed about 0.75 seconds early, and rapid seek completions could overwrite a newer target.
- The device recording showed the root tab bar floating above the bottom of the screen, with Streaming search rendered underneath it, and an exact-end seek displayed a malformed remaining-time label.
- The latest recordings still contained a short measured silence at remote boundaries and showed that manual seek display could be overwritten by AVPlayer's transient pre-seek clock.

## Playback recovery

The explicit 5.1 matrix remains the first-choice path. If Matrix Mixer configuration fails:

1. Resonance records the complete matrix error in the red **Reported Errors** section.
2. The partially configured `AVAudioEngine` is stopped, disconnected, and quarantined.
3. Resonance does not reset, reuse, or deallocate that failed graph during playback switching.
4. Gapless playback is disabled for the remainder of the current app session.
5. The selected file starts through the stable `AVAudioPlayer` compatibility backend.
6. Later local tracks use the compatibility backend directly until Resonance is relaunched.
7. Remote playback continues through the stable single-item `AVPlayer` path and never touches the quarantined local graph.

A relaunch creates a fresh gapless engine and allows the explicit matrix to be attempted again.

## Artist alphabet navigation

- The right-edge index orders numeric names first, then A–Z Roman names, then each available leading Kanji or other Unicode letter; punctuation-only names remain in a final `#` section.
- Normal vertical drags over artist names belong only to the list or grid.
- Touching or dragging inside the right-edge strip maps the finger position in the index container's coordinate space.
- Every available section has a stable container ID used by `ScrollViewReader`.
- A large letter bubble appears to the left of the index while touching or dragging.
- Releasing over a letter keeps the bubble briefly visible and leaves the list at that section.
- A new touch on the same letter dispatches the navigation again.
- Streaming back navigation is restricted to a 24-point left-edge strip.
- The native scroll indicator is hidden in streaming collections; normal scrolling belongs to the main artwork/text area,
  while the right strip belongs to the alphabet index.
- Albums use the same alphabet index as artists, based on album title.

## Streaming connection panel

The server connection information is now a persisted disclosure panel. Collapse it from the streaming tab to reclaim
vertical space for artists and albums. The active grouping remains visible in the compact panel label, and the
streaming navigation title uses the large Library/Settings treatment so the full “Streaming Library” label remains visible
while the connection panel expands, collapses, and the catalog scrolls.

## Streaming performance

- High-frequency playback progress updates are isolated to the mini-player and Now Playing views instead of invalidating the root tab tree.
- Remote catalog filtering, album grouping, and artist grouping are cached by track revision, search text, and sort direction.
- Cached artist, album-artist, and album browse projections are precomputed off the main actor after remote activation, so the first Streaming transition does not synchronously group the full cached catalog.
- Remote cover art is downloaded and downsampled outside the main actor into a bounded, size-specific thumbnail cache. Playback code does not share this path.
- A cached Subsonic catalog is activated immediately and automatic server checks are deferred until **Check for Remote Changes** is selected in Settings. This keeps the cached browse surface responsive while the server is unavailable or slow.
- Album-artist values are canonicalized per artist/album when Subsonic exposes display composites such as `Tool • Unknown Artist`; the most common clean track-artist spelling is retained.

## Experimental background downloads

Build 106 adds an opt-in **Experimental background downloads** setting under Streaming Library. When enabled, requested
remote tracks use an iOS background `URLSession` download task instead of Resonance's foreground byte stream. The
system can continue those HTTP(S) transfers while Resonance is suspended, wake the app to deliver completed files, and
restore the task map after a relaunch. Completed files are moved atomically through a private application-support inbox
before the existing library index refresh runs. The foreground downloader remains the default fallback. iOS may delay
background transfers, and force-quitting the app cancels system-managed background work; physical-device lock-screen
acceptance remains required for this experiment.

## Settings categories

Each top-level Settings category is independently collapsible. Its expanded or collapsed state is stored locally and restored on the next launch, so the page can stay focused on the areas currently being tested.

## Compilation-only artist grouping

Albums containing tracks by more than one distinct artist are now always grouped under one synthetic **Various Artists** entry in local Library and Streaming Artists, Album Artists, and album listings. The album is consolidated once under that entry, while regular single-artist albums remain under their existing artists. The existing **Group compilation-only artists** option continues to additionally group explicit compilation/Various Artists albums that do not contain multiple track artists.

## Validation performed here

- Every Swift source passed Swift 6 syntax parsing.
- `Info.plist` and the Xcode project passed property-list validation.
- The regression suite checked the matrix circuit breaker, safe engine shutdown, stable section IDs, index coordinate mapping, left-edge gesture isolation, prior compile fixes, and remote single-item playback.
- The companion server passed Python compilation.
- The final ZIP passed archive-integrity validation.
- A local fixture server exposed the exact Tool stereo pair and available Yes America A–E 5.1 files; manifest metadata, range responses, remote startup, seek completion, endpoint clamping, and queued boundary advancement were exercised on the iOS simulator.

## Agent validation workflow

- `.xcodebuildmcp/config.yaml` supplies the project, scheme, and stable simulator-name defaults for repeatable agent checks.
- Use `npx -y xcodebuildmcp@latest simulator build` for the fast compile path, `simulator install` and `simulator snapshot-ui` for controlled UI checks, and `--output jsonl` when a long build or test needs machine-readable live progress.
- Keep the explicit `Tools/PreflightBuild.sh`, signed `xcodebuild`, `codesign`, and `devicectl` sequence as the release evidence path because it verifies this project's warning policy, physical-device code signature, and in-place install without launching the app.
- XcodeBuildMCP artifacts and daemon logs are workspace-local diagnostics; do not commit them, and never pass credentials, private URLs, or private music through launch arguments or logs.

Alpha 3.7.4 build 71 removes the experimental 350 ms dual-player overlap that cut off the end of Parabol and consumed the opening of the following track. Experimental remote playback still prepares and prerolls the next HTTP(S) item, but now hands off at the natural item boundary using the warmed player; this avoids truncation while leaving true sample-contiguous streaming gapless pending a decoded PCM/AudioUnit/AVAudioEngine or compatible authored-HLS design. Remote seek display now holds the requested position for only a short 150 ms settle interval and accepts AVPlayer's clock when it is within 0.75 seconds of the target; the scrubber falls back to track metadata during transient player replacement. The live Navidrome catalog was authenticated through a temporary local SSH tunnel: 8,071 tracks loaded, Parabol→Parabola advanced at the boundary, and seek actual/target values agreed within approximately 2 ms. Simulator control-flow validation cannot replace physical-device audible acceptance. Stable local playback, the explicit 5.1 graph, and the responsive tab composition were not changed.

Alpha 3.7.4 build 72 begins the offline-library phase. Experimental streaming gapless is no longer exposed or honored; remote playback always uses the stable single-item AVPlayer path until a post-alpha sample-contiguous design is available. Remote tracks, complete albums, and complete artist collections can be downloaded into the local Resonance Music folder, where they are indexed by the existing library scanner. Local FLAC and MP3 metadata editors now write title, artist, album artist, album, track/disc position, release year, and optional artwork directly into the audio file before rescanning it. Other local formats remain read-only for direct tags in this phase and report that limitation instead of silently creating a Resonance-only edit.

Alpha 3.7.4 build 73 completes the first offline-library download workflow. Downloads now use a disk-backed byte stream with per-file byte progress, a visible cancellation control, cancellation cleanup, and a library rescan after every newly completed track so tracks appear incrementally. Existing destination names trigger an explicit Replace Existing or Keep Existing choice; completed downloads remain duplicate-safe. Streaming artists now support a touch-and-hold Select Artists to Download action that opens a multi-select sheet for downloading several collections together. Local track, album, and artist removal now distinguishes Remove from Library—which preserves the file and persists an exclusion from automatic rescans—from Delete from iPhone, which removes the audio file. Settings adds a QR-camera icon beside the server address field; it accepts a plain URL/host and common JSON address payloads, and requires camera permission only while scanning. The direct FLAC/MP3 tag-writing and stable single-item streaming playback paths are unchanged.

Alpha 3.7.4 build 74 refines the Streaming artist detail surface with three full-width, icon-led action tiles for Play, Shuffle, and Download, using consistent hierarchy, contrast, and touch targets. The local album detail screen now offers Remove from Library and Delete from iPhone alongside its metadata and playback actions. The download banner expands into a queue panel showing queued, active, completed, failed, and cancelled tracks; queued or active tracks have a red circular cancel control, while the header retains a red cancel-all control and can collapse back to the compact progress view. Playback, remote transport, QR setup, and the underlying download storage behavior are unchanged.

Alpha 3.7.4 build 75 keeps the download manager’s high-frequency progress observation inside the download overlay so the Streaming catalog remains responsive while files arrive. Each completed file now performs a targeted library refresh, allowing open local artist and album views to update immediately without rescanning the entire Documents folder. The expanded queue has a visible Collapse control and a bounded scroll area, and local artist album cards now expose the same Remove from Library and Delete from iPhone choices as the album collection and detail screens. Playback, remote transport, QR setup, and download storage behavior are unchanged.

Alpha 3.7.4 build 76 makes open local artist and album screens follow stable artist/album identity, so newly downloaded albums and tracks appear without navigating away and back. Cancelled download rows now offer Requeue, returning the track to the active queue while preserving the existing ordered progress list. Artist long-press menus now put immediate Download Artist above Select Artists to Download. Download progress is coalesced, disk writes use larger buffers, and completed-track indexing uses a single SQLite upsert to reduce interface churn, CPU, and battery work. Playback, Streaming responsiveness, QR setup, and download storage behavior are unchanged.

Alpha 3.7.4 build 79 completes the build-78 polish: all inactive in-app Now Playing controls and the selected Settings palette checkmark now use the configured theme color treatment. Build 79 retains the extra album/track bottom space, top-down detail swipe-back navigation, finger-following mini-player docking, faster Streaming first frame, persistent metadata-field labels, and artwork-or-transparent Lock Screen metadata behavior. iOS does not permit third-party apps to recolor the system Lock Screen controls. Downloads, playback, and remote transport are otherwise unchanged.

Alpha 3.7.4 build 80 makes Streaming artist-detail swipe-back navigation claim the fixed artist header, matching the Library hierarchy gesture without stealing the album list's normal vertical scrolling. Remote album, all-albums, playlist, and other track lists now expose leading Play Next and Add to Queue swipe actions. Mini-player drag gestures now have priority over their tap controls; top/bottom overshoots and side-bubble drags follow the finger without opening the Playing tab or activating content underneath. Playback, downloads, and remote transport are otherwise unchanged.

Alpha 3.7.4 build 81 adds three persisted visual styles in Settings—Nocturne Glass, Gallery Light, and Color Bloom—with a Custom Accent compatibility option. The selected style drives the app's accent, surfaces, background, secondary text, and recommended system appearance while preserving the existing explicit Light/Dark override. Local and Streaming artist/album detail screens now share a fixed, large centered-art hero with playback and queue/download controls arranged around it and an independent scrolling content pane below. Top-down hierarchy dismissal is available from the fixed detail surface, and the mini-player's side bubble can now dock at the bottom as well as the top. Playback, downloads, remote transport, and the alpha streaming-gapless policy are unchanged.

Alpha 3.7.4 build 82 removes the global Streaming Library search and shows Navidrome connection details only when a connection or catalog error is present. Bright Gallery Light selection clears a previously forced dark appearance so text remains readable; Brushed Metal, Classic Wood, Electronic, and Psychedelic styles add additional themed gradients. The Library and Streaming top controls now use one compact themed icon-button treatment, artist indexes no longer draw explicit dark separators across Streaming, album overflow actions use a stable confirmation dialog, and local/remote artwork heroes use titled controls with accessibility, help, and long-press hints. Mini-player surfaces and side handles now use the active theme gradient. Playback, downloads, remote transport, and the alpha streaming-gapless policy are unchanged.

Alpha 3.7.4 build 83 gives Library and Streaming album actions the same themed overflow button and confirmation dialog, fixes prominent album Play controls with explicit contrast, removes completed downloads from the live queue while keeping the active track at the top, and adds generated Brushed Metal, Classic Wood, Electronic, and Psychedelic background artwork to the corresponding selectable themes. Shared toolbar, hero-action, surface, and backdrop components keep the two browsing tabs visually congruent. Playback, downloads, remote transport, and the alpha streaming-gapless policy are unchanged.

Alpha 3.7.4 build 84 keeps the download banner stationary while Streaming content scrolls. Long-pressing Streaming artists or albums now enters inline multi-selection with circular selection bubbles; the top menu provides Download Artist, Download Artists, Download Album, and Download Albums actions without opening a separate window. Generated material-theme imagery is clipped and translucent behind the active gradients and surfaces, preventing it from covering the top half of the app or obscuring the theme controls. Playback, downloads, remote transport, and the alpha streaming-gapless policy are unchanged.

Alpha 3.7.4 build 85 fixes the runtime issues shown in the 02:11 recording. Streaming artist and album section letters no longer paint opaque full-width bars beside the alphabet index. Artist and album holds now use a high-priority long-press recognizer, provide tactile feedback, and enter the existing inline circular multi-selection mode without navigating. Now Playing renders the same active full-screen theme as Library, Streaming, and Settings. Theme cards have a complete hit target, no longer compete with the Settings keyboard-dismiss tap, and preview image-backed styles more clearly. Electronic and Psychedelic use newly generated, more colorful high-detail circuit-control and liquid-fractal artwork, with stronger but still layered background visibility. Playback, downloads, remote transport, and the alpha streaming-gapless policy are unchanged.

Alpha 3.7.4 build 92 adds reliable artwork persistence and restores image themes safely. Artwork overrides now store image data in background-written sidecar files instead of blocking or inflating the metadata JSON. Online search providers fail independently and use broader fallback queries, so one unavailable repository no longer produces an empty result. Custom theme images are rendered only by a dedicated page-level backdrop behind the navigation stack; interactive surfaces remain gradient-only, preventing the prior obstruction. Streaming download progress is isolated to the download controls, coalesced to reduce view invalidation, and no longer re-sorts the queue for every byte update. Build 91's online artwork picker remains included.

Alpha 3.7.4 build 93 restores bottom navigation contrast after image-theme backdrop changes. The custom tab bar is now an opaque themed surface above page artwork, uses the theme's secondary text color for unselected tabs, and the decorative backdrop stops at the content boundary instead of extending into the bottom home-area region.

Alpha 3.7.4 build 94 fixes Library and Streaming artist/album selection gestures stealing vertical scrolling. Selection now uses a bounded long-press recognizer that cancels when the finger moves, so touching a tile while scrolling no longer rechecks it or reopens selection controls.

Alpha 3.7.4 build 51 keeps the Streaming connection header visible, gives the navigation-bar principal title enough space by moving playlist navigation into a compact menu, prioritizes Lock Screen previous/next track commands while retaining in-app 15-second seeking, groups compilation tracks in both Artists and Album Artists views using album identity independent of inconsistent album-artist tags, and reports the installed bundle version/build dynamically in Settings. The system-owned Lock Screen audio-output control remains a platform limitation; Resonance does not expose an app-owned route picker.

Alpha 3.7.4 build 52 defers non-critical catalog and UI diagnostics writes so screen transitions, Streaming scrolling, and alphabet gestures do not synchronously block the main actor. It also passes the computed compilation-album set into Album Artists browsing and adds privacy-safe synchronous boundary/preload diagnostics for reproducing the reported local and streaming gapless failures. The remote backend remains the deliberately stable single-item `AVPlayer` path pending a separate gapless streaming design decision.

Alpha 3.7.4 build 53 removes the Now Playing scroll container, compacts the fixed layout and artwork so Browse Library and Stop stay above the tab bar, and adds a keyboard Done action at the root. The mini-player can be swiped to the top, bottom, or either side; side docking leaves a small edge handle that can be swiped inward to restore it. Remote seeking now stays stable until AVPlayer confirms the seek, remote end detection has a guarded fallback for advancing the queue, and the explicit 5.1 matrix is configured after the engine starts. Remote artist and album index sections are also cached to reduce repeated SwiftUI layout work during long sessions. The AirPlay/output control visible in iOS Control Center remains system-owned; Resonance has no app-owned output picker.

Alpha 3.7.4 build 54 changes Streaming Library to the same large navigation-title treatment used by Library and Settings, so the full white title remains visible instead of truncating to “Stream…” between toolbar controls.

Alpha 3.7.4 build 55 applies the mini-player safe-area insets to each navigation stack, keeping top docking above navigation content and bottom docking above the custom tab bar. It enables the Matrix Mixer master, input, and output gains in addition to the explicit cross-point routing so gapless local playback cannot report ready while rendering silence. The playback trace now records gapless engine/render state and begin/completed seek events, including the measured audio meter level.

The first build-55 device recording review found that the title still was not visually present on the Streaming Library surface, bottom docking still covered catalog rows and the tab bar, and top docking/keyboard editing could still be obstructed by the mini-player. The matching diagnostics show the 5.1 engine running with six source channels and a nonzero render meter, and the tested 5.1 boundary advanced; the recording does not independently establish playback speed from its audio track. No new build-55 crash or CPU-resource report was present; the latest resource report remains from build 52.

Alpha 3.7.4 build 56 is a performance-focused pass. The 120 ms playback clock and meter no longer publish through the shared `PlayerController` observed by catalog, library, settings, and queue rows; only the Now Playing scrubber observes the separate high-frequency progress store, and list visualizers use a static current-track indicator. Inactive tab stacks no longer construct mini-player overlays. Regression checks, simulator and generic-device preflight, signed arm64 compilation, strict code-signature verification, and in-place installation succeeded on 2026-07-25. The device reports version 0.3.7.4/build 56; the app was not launched, so runtime performance acceptance remains pending.

Alpha 3.7.4 build 57 is a second performance pass based on the build-56 screen recording and diagnostics. Root-level catalog/scanner error observation is isolated into a coordinator, cached-catalog automatic checks return before scheduling or logging redundant work, foreground local-file inventory runs at utility priority and is throttled across rapid scene activations, playback-stage diagnostics no longer synchronously write diagnostics/UserDefaults on the main actor, and Lock Screen artwork conversion is prepared off-main and cached per track. Regression checks, simulator and generic-device preflight with warnings treated as errors, signed arm64 compilation, strict code-signature verification, and in-place installation succeeded on 2026-07-25. Before installation, the on-device `Documents/Resonance-Diagnostics.log` was overwritten with a verified zero-byte file; after installation it remained zero bytes because the app was not launched. The device reports version 0.3.7.4/build 57. Source commit: `28fe77c`. Runtime performance, FLAC startup, and playback acceptance remain pending.

Alpha 3.7.4 build 58 addresses the remaining common UI blocker identified by the build-57 recording: local `ArtworkView` decoded full-resolution artwork synchronously during SwiftUI body evaluation across album detail, Now Playing, Settings, and mini-player surfaces. Local artwork now uses a bounded ImageIO thumbnail cache and utility-priority preparation, matching the existing remote artwork path; slow thumbnail loads emit privacy-safe `artwork.local.thumbnail` timing records. Regression checks, simulator and generic-device preflight with warnings treated as errors, signed arm64 compilation, strict code-signature verification, and in-place installation succeeded on 2026-07-25. Before installation, the on-device `Documents/Resonance-Diagnostics.log` was overwritten with a verified zero-byte file; after installation it remained zero bytes because the app was not launched. The device reports version 0.3.7.4/build 58. Runtime acceptance remains pending.

Alpha 3.7.4 build 59 is a focused FLAC/5.1 playback repair. The gapless graph now keeps the source file's native sample rate through the player, explicit surround matrix, and stereo mixer; the main mixer is the first stage that converts to the active hardware route. Gapless preloading now rejects a following file with a different sample rate instead of scheduling it on the current player format, allowing that track to load normally at the boundary. The playback trace records source channels, source sample rate/frame count/duration, graph and output sample rates, and synchronous preparation time. Regression checks, simulator and generic-device preflight with warnings treated as errors, signed arm64 compilation, strict code-signature verification, and in-place installation succeeded on 2026-07-25. Before installation, the on-device `Documents/Resonance-Diagnostics.log` was overwritten with a verified zero-byte file; after installation it remained zero bytes because the app was not launched. The device reports version 0.3.7.4/build 59. Runtime FLAC, 5.1 speed/routing, gapless, and interface acceptance remain pending.
Alpha 3.7.4 build 60 is a focused streaming-interface performance repair based on the 12:55 screen recording and build-59 diagnostics. The remote playback timer now suppresses unchanged status publications and throttles human-readable buffer text to twice per second, preventing the 120 ms timer from invalidating inactive SwiftUI screens. Remote playback preparation now loads only the selected track's artwork, discards stale preparations when a newer selection arrives, and maps large queues without serially fetching 24 album covers. Streaming artist and album section indexes are populated by task only when their input changes instead of rebuilding synchronously during every view-value refresh. No local audio or gapless graph code was changed. Regression checks, simulator and generic-device preflight with warnings treated as errors, signed arm64 compilation, strict code-signature verification, and in-place installation succeeded on 2026-07-25. Before installation, the on-device `Documents/Resonance-Diagnostics.log` was overwritten with a verified zero-byte file; after installation it remained zero bytes because the app was not launched. The device reports version 0.3.7.4/build 60. Runtime interface smoothness and streaming playback acceptance remain pending.
Alpha 3.7.4 build 61 is a focused navigation and editing responsiveness repair based on the 13:16 screen recording and build-60 diagnostics. The root view no longer observes the entire `AppSettings` object or applies theme modifiers to the complete four-tab tree, so settings keystrokes do not invalidate every inactive navigation stack. The system liquid-glass tab bar is hidden and replaced with a stable opaque tab bar that reserves its own safe-area space, preventing tab controls from ghosting over Settings, Now Playing, and Streaming content during navigation. No audio, catalog, or gapless code was changed. Source commit: `4f49061`. Regression checks, simulator and generic-device preflight with warnings treated as errors, signed arm64 compilation, strict code-signature verification, and in-place installation succeeded on 2026-07-25. The initial signed-build command was rejected because Xcode requires a scheme when `-derivedDataPath` is supplied; rerunning with the explicit build output directory succeeded. Before installation, the on-device `Documents/Resonance-Diagnostics.log` was overwritten with a verified zero-byte file; after installation it remained zero bytes because the app was not launched. The device reports version 0.3.7.4/build 61. Runtime navigation, settings editing, and long-idle acceptance remain pending.
Alpha 3.7.4 build 62 is a focused repair for the remaining startup and Settings interaction stalls found in the 13:32 screen recording and fresh build-61 diagnostics. Local startup now seeds file modification dates from the cached database and avoids reparsing unchanged files on every launch. Existing Library content remains visible and interactive while a background inventory checks for transferred-file changes, with privacy-safe scan timing events recorded for diagnosis. Settings hex editing now uses a draft value and a short debounce, so each keystroke does not immediately retheme and redraw the whole interface. No audio, catalog, or gapless code was changed. Regression checks, simulator and generic-device preflight with warnings treated as errors, signed arm64 compilation, strict code-signature verification, and in-place installation succeeded on 2026-07-25. Before installation, the on-device `Documents/Resonance-Diagnostics.log` was overwritten with a verified zero-byte file; after installation it remained zero bytes because the app was not launched. The device reports version 0.3.7.4/build 62. Runtime interface smoothness and Settings editing acceptance remain pending.
Alpha 3.7.4 build 63 is a focused tab, Streaming, and Settings composition repair based on the 13:48 screen recording and fresh build-62 diagnostics. The root no longer constructs all four navigation stacks simultaneously; only the selected tab is composed, while the stable custom tab bar and playback coordinators remain available. Settings category content is now built only while its disclosure is expanded. Streaming browse caching now derives only the selected surface—artists, album artists, or albums—instead of building every large collection before the first screen can respond. No audio, PlayerController, or gapless graph code was changed. Regression checks, simulator and generic-device preflight with warnings treated as errors, signed arm64 compilation, strict code-signature verification, and in-place installation succeeded on 2026-07-25. The first preflight wrapper attempt reported a shell status-variable error after both builds had succeeded; the corrected rerun passed. Before installation, the on-device `Documents/Resonance-Diagnostics.log` was overwritten with a verified zero-byte file; after installation it remained zero bytes because the app was not launched. The device reports version 0.3.7.4/build 63. The user subsequently reported that build 63 is working flawlessly, including tab switching, Library/Streaming/Settings navigation, Now Playing, audio playback, and the confirmed 5.1 gapless path. Build 63 is the current stability reference point for the next phase.
Alpha 3.7.4 build 64 begins the next phase with an opt-in experimental streaming-gapless queue. When enabled in Settings, remote playback uses `AVQueuePlayer` to queue the next eligible HTTP(S) stream, handles queue boundaries, repeat-one, repeat-all, and queue edits, and falls back to normal single-item loading when a queued target cannot be resolved. The setting is off by default, so the build-63 remote playback path remains the rollback behavior; local playback, the explicit 5.1 graph, and the tab/navigation composition were not changed. Regression checks, simulator and generic-device preflight with warnings treated as errors, signed arm64 compilation, strict code-signature verification, and in-place installation succeeded on 2026-07-25. The first signed-build command was rejected because Xcode requires a scheme when `-derivedDataPath` is supplied; rerunning with the explicit build-output directory succeeded. Before installation, the on-device `Documents/Resonance-Diagnostics.log` was overwritten with a verified zero-byte file; after installation it remained zero bytes because the app was not launched. The device reports version 0.3.7.4/build 64. Source commit: `21b037c`.

User runtime review of build 64 on 2026-07-25 confirms remote gapless playback in stereo and 5.1, and confirms that disabling and re-enabling the experimental setting works. The recordings `ScreenRecording_07-25-2026 16-17-05_1.MP4` and `ScreenRecording_07-25-2026 16-18-11_1.MP4`, together with the 487-line log at `/Users/brian/Resonance/diagnostics/build64-review-20260725-1617/Resonance-Diagnostics.log`, show a separate seek-display defect: remote seeks complete, but raw `AVPlayer` time can be published beyond the current track duration after fast-forwarding. The progress thumb clamps at the end while the elapsed/remaining labels can show values such as `3:54` for a `3:46` track or `1:36` for a `1:32` track. The same review confirms the build-61 accent-text regression described above. Runtime streaming gapless is therefore accepted for stereo/5.1, while seek-display clamping and theme-text restoration remain open.

Alpha 3.7.4 build 65 repairs the build-64 seek-display defect by clamping remote elapsed time after AVPlayer clock updates, seek completion, duration discovery, and remote-player initialization to the current track duration. It also restores the **Apply theme color to text** preference through a `ViewModifier` attached only to the active tab surface; RootView still does not observe `AppSettings` directly, so inactive navigation trees remain isolated. Local playback, the explicit 5.1 graph, and the build-63 tab/navigation composition were not changed. Source commits are `0b99444` and `93d67c6`. Regression checks, simulator and generic-device preflight with warnings treated as errors, signed arm64 Release compilation, strict deep code-signature verification, and in-place installation succeeded on 2026-07-25. The known no-scheme/empty-supported-platform destination warning and harmless AppIntents metadata-skip warning remain non-blocking. The device reports version 0.3.7.4/build 65. The diagnostics file was cleared before installation, and the app was not launched by Codex; runtime seek and theme-text acceptance remain pending.

Alpha 3.7.4 build 66 repairs the experimental streaming-gapless boundary wait identified in the `ScreenRecording_07-25-2026 16-41-55_1.MP4` review. The recording's captured audio contained approximately two seconds of silence immediately after a remote queue boundary even though the next item was queued and the UI reported it as gapless-ready. Experimental `AVQueuePlayer` playback now disables AVPlayer's stall-minimization wait and explicitly advances at item end; stable single-item remote playback keeps its existing wait behavior. Local playback, the explicit 5.1 graph, seeking clamps, and the tab/Streaming responsiveness work were not changed. Source commit: `4f7001b`. Regression checks, simulator and generic-device preflight with warnings treated as errors, signed arm64 Release compilation, strict deep code-signature verification, and in-place installation succeeded on 2026-07-25. The known empty-supported-platforms destination, no-scheme preflight, harmless AppIntents metadata-skip, and stale prior-output-directory warnings were non-blocking. The device reports version 0.3.7.4/build 66. Diagnostics were cleared before installation, and the app was not launched by Codex; physical-device gapless acceptance remains pending.

Alpha 3.7.4 build 67 is a focused repair based on `ScreenRecording_07-25-2026 16-56-30_1.MP4`. Experimental remote queue playback now uses `playImmediately(atRate:)` for initial start, resume, repeat-one, and queue boundaries so AVPlayer does not reintroduce a stall-minimization wait at a stream transition. Remote seeking now permits the exact track endpoint, serializes completion callbacks so stale seeks cannot overwrite the latest target, bases rapid skip gestures on the pending target, and keeps the requested position authoritative when AVPlayer briefly reports its pre-seek clock. The scrubber also clamps its displayed elapsed and remaining labels to the active duration. Local playback, the explicit 5.1 graph, catalog behavior, and tab/Streaming composition were not changed. Regression checks, simulator and generic-device preflight with warnings treated as errors, signed arm64 Release compilation, strict deep code-signature verification, and in-place installation succeeded on 2026-07-25. The known empty-supported-platforms destination, no-scheme preflight, and harmless AppIntents metadata-skip warnings remained non-blocking; there were no build or install errors. The device reports version 0.3.7.4/build 67. Diagnostics were cleared before installation and remained zero bytes afterward because the app was not launched by Codex. Physical-device seek and residual-gap acceptance remain pending.

Alpha 3.7.4 build 68 repairs the device layout regressions without touching the verified streaming queue/audio path. Root content now explicitly fills the device container so the custom tab bar remains anchored to the actual bottom safe area. Streaming connection information and a custom remote search field are fixed above the browse surface; the native search bottom inset is removed so it cannot push the tab bar upward or appear underneath it. The scrubber now renders an exact-end remaining time as `−0:00` instead of `−—:—`. Local playback, the explicit 5.1 graph, remote gapless playback, and remote seek ordering were not changed. The signed build is installed on SaiyanDenwa; physical-device audible playback and UI acceptance remain pending because Codex did not launch the app.

Controlled build-68 simulator validation used the exact Tool `Parabol`/`Parabola` FLACs and the available Yes `America: A–E` 5.1 FLACs through a local Resonance Manifest server. The Tool pair started remotely, accepted ordinary and exact-end seeks with millisecond-level diagnostic agreement, and advanced from Parabol to Parabola at the boundary. The Yes files were indexed as six-channel, 96 kHz 5.1 media; America: A started with America: B preloaded, and a near-end resume advanced to America: B with `preloadedTarget=true`. The simulator verified control flow and queue handoff, but cannot replace physical-device listening for audible gap and channel-routing acceptance. The simulator also confirmed the tab bar remains at the bottom, the custom Streaming search field stays above the browse surface, and the exact-end label is `−0:00`.

Alpha 3.7.4 build 69 replaces the experimental remote `AVQueuePlayer` handoff with a readiness-aware dual-player preloader. The next HTTP(S) track is independently prepared and prerolled at zero volume; a boundary reuses that warmed player only after it is ready, while stable single-item remote playback remains unchanged. Remote seeking now explicitly resumes a stream that was playing after seek completion, including the failed-seek recovery path, and records a privacy-safe resume diagnostic. Local playback, the explicit 5.1 graph, and the responsive tab composition were not changed. The simulator endpoint test exercised Tool Parabol→Parabola and all available Yes America A–E boundaries by jumping to approximately 15 seconds before each endpoint; every tested transition reported `preloadReady=true`, and seek actual/target values agreed within milliseconds. Physical-device listening remains required for audible gap and surround-routing acceptance.

## Next major phase

- Preserve build 63 (0.3.7.4, source commit c3c1ebc) as the stability and rollback reference while testing build 73. Any new playback or Streaming work must retain responsive tab switching, Library/Streaming/Settings navigation, Now Playing behavior, audio playback, and confirmed local 5.1 gapless behavior.
- Build-73 download acceptance: start a multi-track artist or multi-artist download, confirm the current file shows byte progress and the Cancel button, cancel mid-file, and verify no partial .part file is indexed. Start again and confirm the local library refreshes after each completed track rather than waiting for the whole batch.
- Build-73 replacement acceptance: download a track twice, verify the second attempt asks whether to replace the same-named file, choose Keep Existing and then Replace Existing, and confirm the library contains one track rather than duplicates.
- Build-73 removal acceptance: for a track, album, and artist use Remove from Library and confirm the files remain in Files/Finder but stay absent after a manual or relaunch scan; repeat with Delete from iPhone and confirm the files are removed.
- Build-73 multi-artist acceptance: touch and hold an artist in Streaming, select several artists, start the combined download, and confirm deduplication, progress, incremental local indexing, and cancellation.
- Build-73 QR acceptance: open Settings → Streaming Library, tap the QR icon, scan a plain HTTPS server URL and a host with a port, confirm the host/port/HTTPS fields populate, and verify a denied camera permission produces an actionable message. Do not put credentials in the QR payload or diagnostics.
- Preserve build 63 (`0.3.7.4`, source commit `c3c1ebc`) as the stability and rollback reference while testing build 72. Any new playback or Streaming work must retain responsive tab switching, Library/Streaming/Settings navigation, Now Playing behavior, audio playback, and confirmed local 5.1 gapless behavior.
- Build-72 manual acceptance: verify the Streaming settings no longer expose a gapless toggle; download one track, one album, and one artist collection; confirm progress, duplicate-safe behavior, local-library indexing, offline playback, and correct artist/album/track ordering.
- Build-72 metadata acceptance: edit a local FLAC track, album, and artist; verify the changed tags and artwork survive app relaunch and are visible to another tag reader. Repeat with MP3, and verify an unsupported format presents the direct-write limitation without claiming the file was changed.
- Perform the remaining physical-device acceptance on build 71: audible stereo Parabol→Parabola boundary behavior, exact-end seeking, rapid seeks, and responsive tab switching/Streaming scrolling while audio is playing. Do not uninstall first. America A–F 5.1 was intentionally deferred for this pass.
- Retrieve a fresh `Documents/Resonance-Diagnostics.log` after the physical runtime test and correlate `remote.player.queueConfigured`, `remote.player.finished`, `remote.player.boundary.end`, `remote.player.endFallback`, and seek `target`/`actual` details with the recording. Do not launch Resonance automatically or commit the copied diagnostics file.
- If physical evidence exposes a new defect, make the next build narrowly targeted; the controlled fixture run did not justify changing `PlayerController.swift` or `GaplessAudioEngine.swift`.
- Perform focused FLAC acceptance on build 59: play a normal stereo FLAC, a high-rate stereo FLAC if available, and the known 5.1 FLAC; confirm audible playback starts at normal speed, front/rear/center/LFE routing remains correct, seeking is accurate, and the next track starts. Retrieve the log and compare `sourceSampleRate`, `graphSampleRate`, `outputSampleRate`, `sourceFrames`, `duration`, `preparationMs`, and render-meter entries. If audio is still wrong, make the next build an explicit FLAC-only compatibility-player experiment to separate AVAudioEngine graph behavior from the system decoder.
- Complete physical-device Lock Screen acceptance: previous/next must be the primary transport controls, in-app 15-second seek must remain available, and the system-owned output control must be documented and investigated only through supported Now Playing/MediaPlayer APIs.
- Complete Streaming navigation-chrome acceptance: the white **Streaming Library** title must remain visible like the **Library** and **Settings** titles while the connection panel expands, collapses, and the catalog scrolls.
- Complete compilation grouping acceptance in the **Artists** and **Album Artists** views with mixed album-artist metadata, including albums such as *Trigun: The First Donuts*; verify that regular artist catalogs remain separate and that each compilation appears once under **Various Artists**.
- Complete build 55 physical-device acceptance: fixed Now Playing layout, mini-player top/bottom/side docking and restore without covering navigation or the tab bar, keyboard dismissal, audible local stereo/5.1 gapless, remote queue advance, accurate remote seeking, and the full Streaming Library title.
- After playback and seek tests, retrieve `Resonance-Diagnostics.log` and verify `playback.gapless.prepared`, `playback.timer.gapless.end` meter/render-state details, and `playback.seek.begin`/completion events correlate with the user-visible behavior.
- Re-run the cached-catalog, manual-change-check, artwork, settings-category, Streaming title, grouping, and long-idle performance checks after these runtime fixes.
- Profile the deferred-diagnostics build on the physical device while switching tabs, scrolling Streaming, dragging the alphabet, and leaving playback stopped; inspect the diagnostics and system crash logs after any sluggishness or lockup. Complete local gapless acceptance and decide whether remote gapless can be implemented without regressing the single-item playback crash shield.

## Device diagnostics

Build 46 writes a bounded, privacy-safe playback and streaming interaction trace to:

`Documents/Resonance-Diagnostics.log`

The trace records lifecycle, playback-stage, timer, Now Playing, remote-catalog cancellation boundaries, connection-panel
state, selected browse grouping/layout, and alphabet gesture/section-jump events. It does not record track names, local
paths, server URLs, credentials, private music, or audio data. After manually reproducing a problem on the iPhone, the
file can be copied from the app container with:

```sh
xcrun devicectl device copy from \
  --device 9629DEED-EBF9-5835-B98A-9FAEC81CBDC6 \
  --domain-type appDataContainer \
  --domain-identifier com.example.ResonancePrototype \
  --source Documents/Resonance-Diagnostics.log \
  --destination /Users/brian/Resonance/diagnostics/Resonance-Diagnostics.log
```

## Handoff update — 2026-07-27

The current checkout is `/Users/brian/Resonance/Resonance-Alpha-3.7.4` on
`agent/alpha-3.7.4-source`. The source release commit is `5796010`, followed
by handoff metadata commit `f50dd84`; it is prepared as the
`Resonance-Beta-v1.0.2` Release Candidate 1 with version `0.3.7.4` and project
build `102`. The release candidate source and documentation are pushed to
GitHub; generated build logs remain local and are not release files.

The pending changes move `RemoteDownloadOverlay` into the Streaming content
flow with the existing 84-point title clearance, so the download banner sits
below the “Streaming Library” navigation title instead of behind navigation
buttons. A temporary DEBUG-only position preview was used in the simulator and
removed before the final check; the non-downloading state uses `EmptyView` so
it does not create a blank spacer.

Online artwork saves now retain an app artwork override when an artist or album
has no writable local audio file, refresh SwiftUI immediately, persist sidecar
artwork, and keep the override after the metadata editor closes. Atmosphere was
verified in the signed-in iPhone 17 Pro simulator: the override JSON and 600×600
JPEG sidecar were present, and the artist page displayed the saved artwork.
Artist sidecar persistence remains utility-priority and detached from the main
actor to preserve the build-92 performance protection.

The mixed-artist grouping requirement is implemented in both `LibraryStore` and
`RemoteLibraryStore`. Album identity is normalized by album title and release
year; an album with more than one distinct track artist is assigned to
**Various Artists**, with all of its tracks kept together and regular albums
left unchanged. Regression checks, including the deterministic split-album
contract, and the clean Swift 6 simulator/generic-device preflight passed on
this tree. The configured simulator also opened an existing Various Artists
album and showed two differently credited tracks together; that verifies the
runtime display path but is not a substitute for a fresh non-explicit fixture.
The preflight retained the known non-blocking no-scheme/empty-destination and
AppIntents metadata-skip warnings. The physical device was not launched or
updated; a fresh representative mixed-artist runtime fixture remains the next
manual check.

The artwork workflow is now shared across artist, album, and individual-track
editing. `ArtworkSearchService` queries Apple iTunes and MusicBrainz/
Cover Art Archive candidates, scores them by normalized artist/album/title
matches, and presents multiple choices in `OnlineArtworkSearchView`. The best
available candidate starts selected with a red outline; selecting another card
moves the outline, and failed image loads advance to the next candidate.
Album and track app overrides now publish immediately, persist when local files
are unavailable, and remain active after the metadata editor closes.

Album detail views automatically offer the picker when no usable local or
remote artwork is available. Streaming album selections are shown with the red
override outline and are remembered by the download manager so the selected
cover can be applied when downloaded. This uses the same candidate picker and
apply/save callbacks as artist, album, and track artwork editing.

Validation for this artwork update passed `Tools/RegressionChecks.sh`, the
strict simulator build, and the warnings-as-errors iPhoneOS preflight. In the
configured simulator, the album editor displayed multiple online candidates,
marked the recommended candidate with a red outline, and applying a different
candidate produced the expected Resonance metadata override. The physical
device was not launched or updated.

The app icon is now the generated ToneVault mark in
`Assets.xcassets/AppIcon.appiconset/ToneVault-AppIcon-1024.png`: a midnight
vault door with a cyan-and-amber audio waveform. The asset catalog references
the 1024×1024 source as the universal iOS AppIcon. The strict simulator build,
asset compilation, simulator install/launch, and visual inspection of the
compiled 60×60@2x icon all passed. The physical device was not updated.

Artwork search refinement now sends artist, album artist, album name, and—when
needed—individual song title metadata to the providers. Candidates are filtered
unless the returned artist/album-artist identity and album title are credible
matches, while multiple strong versions from the providers remain available for
selection. If album-level results fail but a song-level query produces usable
art, the first valid image is cached under the album identity and promoted to
the artist identity, so every song row, the album, and the artist display the
same artwork. The existing red-outline preference applies to these automatic
fallbacks.

The refined search passed `Tools/RegressionChecks.sh`, the strict simulator
build, and simulator build/install/launch. The physical device was not updated.

The Streaming artwork display is now driven by one `RemoteArtworkContext` in
`StreamingLibraryView.swift`. Track, album, artist, and playlist models create
the context once; grid tiles, list rows, detail heroes, and track rows all pass
that same context to the shared `RemoteArtwork` resolver. The context carries
all available direct artwork sources from related tracks, deduplicated and
bounded to twelve candidates, before falling back to the shared online search
cache. This removes repeated metadata wiring and prevents one layout from
silently omitting album/artist fallback metadata.

The context refactor was validated with `Tools/RegressionChecks.sh`, the strict
warnings-as-errors simulator build, simulator installation/launch, and manual
navigation through the signed-in Streaming tab's Atmosphere artist and Se7en
album. The known non-blocking no-scheme destination and AppIntents metadata-skip
warnings remain. The physical device was not updated or launched.

Album artwork editor persistence was verified for the local Bob Marley / Catch A
Fire album in the configured simulator. The Search Online Artwork callback and
the editor's final Save now both retain the selected sidecar-backed artwork
override for every album track, even when the MP3 tag writer succeeds but the
immediate AVFoundation rescan does not expose its APIC frame. Track artwork
override persistence is synchronous before the editor dismisses, and the
privacy-safe `library.metadata.albumSave` diagnostic records the preservation
decision and write counts. The final Save, app relaunch, override JSON, sidecar
files, and visible album/track artwork all passed. The physical device was not
updated or launched.

Streaming album artwork now uses the same authoritative fallback principle. The
shared `RemoteArtwork` resolver searches credible artist/album candidates before
accepting a server-provided cover image for album and track contexts. This is
important for Navidrome catalogs where a `coverArtID` can resolve to a generic
blue-disc placeholder even though the album has no usable artwork. Direct server
art remains the fallback when online search cannot produce a valid image, and
server placeholders are no longer seeded into the automatic-art cache. The
configured simulator showed Catch A Fire's album grid tile, album hero, and
track rows using the selected online cover with the red warning outline. The
physical device was not updated or launched.

The streaming artist fallback now searches the distinct albums represented by
the artist's tracks when an artist-only query has no credible result. This fixes
catalogs such as Atmosphere, where the Se7en album search succeeds but the
artist-only search does not: Se7en's artwork is now promoted through the shared
resolver to the Atmosphere artist tile, hero, and All Albums tile. The automatic
art remains marked with the red outline when that preference is enabled. The
fix passed `Tools/RegressionChecks.sh`, the strict warnings-as-errors simulator
build, and manual simulator verification of Atmosphere > Se7en. The physical
device was not updated or launched.

The current source was then built and signed for the physical device with
development team `98CWMFS26R`, verified with strict code-signature checks, and
installed in place on `SaiyanDenwa` using `devicectl`. The device reports bundle
`com.example.ResonancePrototype`, version `0.3.7.4`, build `101`. The app was
not launched; no playback or physical-device runtime acceptance was performed.

The local Albums library now uses the shared vertical alphabet index for both
grid and list layouts. Album titles are grouped into the same numeric, Roman,
Unicode, and punctuation sections used by artist browsing, and the index jumps
to `album-section-*` anchors while preserving ascending or descending order.
Streaming artwork warnings now distinguish searched fallback art from a stream
that already provides artwork: existing server/file artwork is not outlined in
red or overwritten by an automatic cache entry. `Tools/RegressionChecks.sh`
passed, the strict warnings-as-errors simulator build passed, and the configured
simulator showed the local Albums index and the Streaming index without red
outlines around existing artwork. The physical device was not updated or
launched.

Feature-complete turning point — Resonance Beta v1.0.2
--------------------------------------------------------------------------

The repaired library, streaming artwork inheritance/search, artwork editing,
download workflow, artwork provenance warnings, alphabet navigation, tab
transitions, hierarchy swipes, and interface polish are now considered complete
for the Beta v1.0.2 build. The user reports that all installed features are
fully functional. Preserve the current module boundaries and working behavior;
the next phase is limited to a small set of interface-polish improvements.

## Streaming gapless experiment — 2026-07-27

The signed-in simulator reproduced the current remote boundary on Tool / 10,000 Days. The stable path logs a completed
`AVPlayer` item followed by a new remote playback request, which explains the audible interruption. The existing
dual-`AVPlayer` preloader was enabled only in a temporary simulator build; it reported a ready preloaded item and an
`advanced` boundary, but it was not accepted as a gapless fix. A DEBUG-only test then sought directly to five seconds
before the end (`421.684` of `426.684` seconds, and `443.627` of `448.627` seconds on the next track); the remote
session did not produce a reliable boundary completion after that seek. The DEBUG-only seek hook was removed. The
old dual-player flag was later disabled after the sample-contiguous experiment replaced it.

Apple's documented behavior indicates that true sample-contiguous remote playback requires one continuous timeline:
an appropriately authored HLS/fMP4 stream, or a client-side streamed decode into one PCM scheduling/rendering path.
Separate raw Subsonic file URLs and separate `AVPlayer` instances cannot guarantee that property. Do not treat the
phone experiment as a verified release fix. The exact next implementation point remains a new playback-only remote
sample pipeline, with local `GaplessAudioEngine`, artwork, navigation, and interface modules left unchanged.

## Remote sample-contiguous playback experiment — 2026-07-27

The current playback-only experiment now downloads the current and next
same-album remote tracks into `Library/Caches/RemoteGapless`, validates that
their decoded sample rate and channel count match, and schedules both through
the existing single-node `GaplessAudioEngine`. The older dual-`AVPlayer`
experiment is disabled. The sample-contiguous path is enabled in simulator and
device builds; different albums, incompatible decoded formats, failed
preparation, and missing next tracks retain the existing remote fallback.

The signed-in simulator cached two Tool tracks, prepared 44.1 kHz stereo audio,
and recorded `remote.gapless.prepared` followed by
`playback.gapless.boundary.end result=advanced`. The simulator then showed the
next track playing. This verifies the shared decoded timeline and boundary
control flow, but it still requires both tracks to download before playback
starts and is not yet a low-latency streaming architecture.

Validation passed `Tools/PreflightBuild.sh`, `Tools/RegressionChecks.sh`,
`git diff --check`, strict Debug simulator compilation, signed arm64 Release
compilation, and strict deep code-signature verification. The known no-scheme
destination, harmless AppIntents metadata-skip, and stale prior `/tmp` build
artifact warnings remained non-blocking. The signed build was installed in
place on `SaiyanDenwa` as bundle `com.example.ResonancePrototype`, version
`0.3.7.4`, build `101`; the phone was not launched.

Manual phone test: start a same-album remote pair, seek to approximately five
seconds before the first track ends, and listen for truncation or a residual
gap. Also test a different-album transition, preparation cancellation/restart,
and a failed remote download. Do not treat the experiment as fully accepted
until audible phone behavior is confirmed.

## Device runtime log review — 2026-07-27 UTC

The installed build's credential-free device diagnostics were copied after a
manual runtime session. The log recorded three successful sample-contiguous
preparations: one stereo pair decoded at 44.1 kHz and two six-channel pairs
decoded at 96 kHz. Each preparation published a nonzero gapless render meter;
the stereo pair and both six-channel pairs reached
`playback.gapless.boundary.end result=advanced`. A different-album transition
reported `preloadedTarget=false`, used the normal remote fallback, and did not
change the local engine path.

This confirms device-side preparation, rendering, and boundary control flow,
but not audible zero-gap behavior or channel-routing correctness. The log has
no user listening result or recording correlation, and it does not yet prove
preparation cancellation/restart or failed-download recovery. The physical
app was not relaunched or reinstalled by this review; build 101 remains the
installed package, and the current working tree still contains the intentional
uncommitted experiment plus the local Albums/artwork-provenance changes.

Next continuation: obtain the user's audible result or a time-correlated
recording for the stereo and six-channel boundaries, then test cancellation
and restart during the two-file preparation and an unreachable/failed remote
download. Keep the sample path experimental until those results are known.

## Remote album preload continuation — 2026-07-27 UTC

The sample-contiguous remote path previously prepared only the initial two
same-album tracks. At the second-track boundary, its continuation scheduler
used the local-file preload check, so the third remote album track was not
scheduled and the UI reported end of queue. `PlayerController` now downloads
the next same-album remote track into the existing gapless cache while the
current track plays, appends it to the same `GaplessAudioEngine` timeline, and
repeats that process after every album boundary. A late or failed continuation
preload falls back to normal next-track loading rather than stopping playback.

`Tools/RegressionChecks.sh`, strict simulator preflight, and strict generic
device preflight passed. A fresh Debug simulator build was installed in place
on the booted iPhone 17 Pro simulator; it was not launched automatically. The
physical phone was not changed or launched. Known no-scheme destination and
AppIntents metadata-skip warnings remain non-blocking.

Manual simulator test: launch the installed app, play an album with at least
four remote tracks, and verify playback continues from track two through the
remaining album tracks without an end-of-queue state. Also test a slow or
interrupted next-track download and confirm it loads normally, then verify the
final album boundary and a different-album transition.

## Previous-track preload restart — 2026-07-27 UTC

Pressing Previous could reopen a cached earlier album track through the local
gapless path while its remote successor was not cached. That path then showed
`End of queue` because it only considered local preload candidates. It now
detects the remote same-album successor immediately, starts the continuation
download again, and reports ordinary next-track loading for real non-gapless
queue successors instead of mislabeling them as the end.

Regression checks, strict simulator preflight, and strict generic-device
preflight passed. The updated Debug build was installed in the booted iPhone
17 Pro simulator and was not launched automatically. The physical phone was
not changed or launched.

## Artist album alphabet indexes — 2026-07-27 UTC

Local `ArtistDetailView` and Streaming `RemoteArtistDetailView` now group
albums into title-letter sections and expose the same right-side
`VerticalArtistIndex` used by the main Library and Streaming album browsers.
The index works in both grid and list layouts, scrolls the artist's album
content to the selected letter, leaves the All Albums entry at the top, and
keeps the existing album sort order within each letter section.

Regression checks, strict simulator preflight, and strict generic-device
preflight passed. A fresh Debug simulator build was installed in place on the
booted iPhone 17 Pro simulator; it was not launched automatically. The
physical phone was not changed or launched.

Manual simulator test: open an artist with albums spanning several letters in
Library and Streaming, verify the right-side index appears in grid and list
layouts, tap and drag across letters, and confirm normal album taps and
scrolling still work.

## Alphabet index direct-tap commit — 2026-07-27 UTC

The shared `VerticalArtistIndex` now commits the final touch location in
the drag gesture's `onEnded` callback as well as during `onChanged`. This
makes a direct tap on an earlier alphabet letter reliably scroll back to
that section after the content has been scrolled down. Dragging through
letters remains supported across Library, Streaming, local artist album
views, and Streaming artist album views.

Regression checks, strict simulator preflight, and strict generic-device
preflight passed. A fresh Debug simulator build was installed in place on
the booted iPhone 17 Pro simulator; it was not launched automatically.
The physical phone was not changed or launched.

Manual simulator test: scroll deep into Library, Streaming, a local artist
album view, and a Streaming artist album view; tap an earlier letter
directly and then drag across letters, confirming both jump directions.

## Alphabet index release retry — 2026-07-27 UTC

Simulator diagnostics showed that the first touch emitted the selection and
`scrollTo` request during `DragGesture.onChanged`, but the release path did
not reissue the callback because the selected key was already recorded. The
shared index now repeats the final scroll after yielding to the main actor
when the gesture ends. This lets the scroll view finish its touch handling
before the direct-tap jump is applied, while preserving continuous dragging.

Regression checks, strict simulator preflight, and strict generic-device
preflight passed. A fresh Debug simulator build was installed in place on
the booted iPhone 17 Pro simulator; it was not launched automatically.
The physical phone was not changed or launched.

Manual simulator test: from a deep section, tap an earlier letter once in
Library, Streaming, a local artist album view, and a Streaming artist album
view. Repeat with forward jumps and drag gestures.

## Hex channel sliders — 2026-07-27 UTC

The RGB hex editor keeps its intentional 80% visual width but no longer
relies on the native Slider's hidden thumb insets while drawing separate
hex-nibble tick marks. Each channel now uses an explicit track and thumb
geometry, maps the complete visible track directly to 0...255, and exposes
matching accessibility values and increment/decrement actions. This removes
visual tick/indicator drift and prevents the value mapping from depending on
platform Slider geometry.

Regression checks, strict simulator preflight, and strict generic-device
preflight passed. A fresh Debug simulator build was installed in place on
the booted iPhone 17 Pro simulator; it was not launched automatically.
The physical phone was not changed or launched.

Manual simulator test: in Settings → Appearance, select Red, Green, and
Blue fields; tap and drag each custom slider from both endpoints through
the nibble marks, confirm exact 00/FF endpoints and intermediate values,
edit the two-character fields, switch palettes, and relaunch to confirm
the combined six-character accent persists.

## Tappable volume slider — 2026-07-27 UTC

The Now Playing volume control now uses the same explicit track geometry as
the RGB channel controls. Tapping anywhere along the visible volume bar sets
the value immediately, and dragging continues to update it across the full
0...1 range. Accessibility exposes the percentage and five-percent
increment/decrement adjustments.

Regression checks, strict simulator preflight, and strict generic-device
preflight passed. A fresh Debug simulator build was installed in place on
the booted iPhone 17 Pro simulator; it was not launched automatically.
The physical phone was not changed or launched.

Manual simulator test: open Now Playing, tap at several positions on the
volume bar without grabbing the thumb, drag from both endpoints, confirm the
speaker icons and volume response, and verify accessibility adjustments.

## Tab persistence, bottom mini-player, and play navigation — 2026-07-27 UTC

The mini-player now defaults to bottom docking. The root retains a separate
NavigationStack for Playing, Library, Streaming, and Settings inside a hidden
native TabView while the existing themed tab bar remains visible. Switching
from Library or Streaming to Settings or Playing therefore preserves the
selected detail page and its scroll position when returning. Explicit local
and remote play requests emit a low-frequency presentation event that selects
the Playing tab immediately; automatic track changes do not switch tabs.

Regression checks, strict simulator preflight, and strict generic-device
preflight passed. A fresh Debug simulator build was installed in place on the
iPhone 17 Pro simulator. Runtime testing was stopped at the user's request
after confirming a local detail page survived a Settings → Library switch; the
play-navigation and bottom-docking checks remain for manual testing. The
physical phone was not changed or launched.

Manual test: confirm the mini-player opens at the bottom; scroll or open a
local and Streaming detail page, visit Settings or Playing, and return to
verify the same page and position. Tap Play on local and remote track, album,
artist, and playlist controls and confirm the Playing tab opens immediately.
Confirm automatic next/previous playback does not unexpectedly change tabs.

## Disable top-of-list bounce — 2026-07-27 UTC

Resonance now disables UIKit scroll-view bouncing app-wide, including vertical
page and list surfaces. Swiping downward from the top no longer translates the
content and springs it back; horizontal scrolling remains available for
horizontal controls and names.

Regression checks, `git diff --check`, and an XcodeBuildMCP simulator build and
install passed. The simulator was not launched after installation, and the
physical phone was not changed.

Manual test: on Library, Streaming, artist/album detail, Settings, and Now
Playing lists, drag downward from the top edge and confirm the content stays
stationary instead of bouncing. Confirm ordinary vertical scrolling and
horizontal name/control scrolling still work.

## Streaming All Albums themed background — 2026-07-27 UTC

The Streaming All Albums collection now owns the shared themed backdrop, so
its album grid/list no longer exposes the default black scroll surface.

Regression checks, `git diff --check`, XcodeBuildMCP simulator build, and
in-place simulator installation passed. The simulator was not launched and
the physical phone was not changed.

Manual test: open Streaming → Albums → All Albums in each visual theme and
confirm the grid and list backgrounds match the rest of the themed interface.

## Isolate inactive tab content — 2026-07-27 UTC

The retained Playing, Library, Streaming, and Settings navigation stacks now
live in a layered ZStack. Only the selected page is opaque, hit-testable, and
accessible; inactive pages are fully transparent and non-interactive. This
prevents the Playing scrubber/time bubble from appearing over other tabs or
blocking their controls while preserving each tab's navigation position.

Regression checks, `git diff --check`, XcodeBuildMCP simulator build, and
in-place simulator installation passed. The simulator was not launched and
the physical phone was not changed.

Manual test: start playback, switch among Library, Streaming, and Settings,
and confirm the Playing scrubber is absent and all controls remain tappable;
return to Playing and confirm its scrubber remains usable.

## Transparent Streaming All Albums track list — 2026-07-27 UTC

The Streaming All Albums track list now applies clear backgrounds to both the
Play All Albums row and every track row, allowing the active theme backdrop to
show through instead of the default black list surface.

Regression checks, `git diff --check`, simulator build, and in-place simulator
installation passed. The simulator was not launched and the physical phone
was not changed.

Manual test: open Streaming → Albums → All Albums and confirm the Play All
Albums row and track list are transparent in each visual theme.

## Library All Albums theme parity — 2026-07-27 UTC

The local Library All Albums track list now uses the same transparent row and
themed-surface treatment as Streaming All Albums. The Play All Albums row,
track rows, and artist header no longer use opaque black or system-bar grey
backgrounds.

Regression checks, `git diff --check`, simulator build, and in-place simulator
installation passed. The simulator was not launched and the physical phone
was not changed.

Manual test: open Library → an artist → All Albums in each visual theme and
confirm the header, Play All Albums row, and track list match Streaming.

## Interactive horizontal tab transitions — 2026-07-27 UTC

The retained tab pages now support an app-switcher-style horizontal swipe.
Dragging left or right reveals the adjacent page and moves the complete page
surface with the finger; releasing past the threshold completes the tab change
with a short eased transition. Vertical drags and nested vertical scrolling do
not switch tabs, and each tab's navigation state remains retained.

Regression checks, `git diff --check`, simulator build, and in-place simulator
installation passed. The simulator was not launched and the physical phone
was not changed.

Manual test: swipe left and right across Library, Streaming, Settings, and
Playing; confirm the whole page moves together, edge tabs resist the swipe,
vertical scrolling remains normal, and returning to a tab preserves its page.

## Hex slider keyboard focus — 2026-07-27 UTC

Touching or dragging an RGB hex slider now focuses the selected two-character
hex field and presents its ASCII keyboard. Slider changes continue updating
the selected channel, while the field's Done accessory remains available for
dismissing the keyboard.

Regression checks, `git diff --check`, simulator build, and in-place simulator
installation passed. The simulator was not launched and the physical phone
was not changed.

Manual test: open Settings → Appearance, tap and drag each RGB slider, confirm
the keyboard appears, edit the selected two-character value, and use Done to
dismiss it.

## Playing gesture ownership — 2026-07-27 UTC

Now Playing keeps horizontal album-art swipes dedicated to previous/next track
paging. The seek and volume sliders take priority for scrubbing, while a
horizontal swipe on the remaining page surface drives the adjacent-tab
transition. This prevents the tab animation from stealing album-art or slider
gestures.

Regression checks, `git diff --check`, simulator build, and in-place simulator
installation passed. The simulator was not launched and the physical phone
was not changed.

Manual test: on Playing, swipe the artwork left/right to change tracks, drag
the seek and volume bars, and swipe elsewhere on the page to move between tabs.

## Preserve track-list horizontal actions — 2026-07-27 UTC

The horizontal tab transition is now a lower-priority page gesture rather than
a simultaneous gesture. Track-list rows and list scrolling therefore retain
ownership of horizontal touches for Edit Metadata, Play Next, Add to Queue,
and playlist actions; page swiping remains available above the track list.

Regression checks, `git diff --check`, simulator build, and in-place simulator
installation passed. The simulator was not launched and the physical phone
was not changed.

Manual test: in local and Streaming track lists, swipe a row and use metadata,
queue, and playlist actions; then swipe above the list to change tabs.

## Keep hex keyboard visible — 2026-07-27 UTC

Hex field and slider focus now clears Settings’ page-level keyboard-dismiss
state before presenting the custom field keyboard. The Done accessory no longer
leaves the editor with no keyboard, and the keyboard remains interactively
dismissable by swiping down.

Regression checks, `git diff --check`, simulator build, and in-place simulator
installation passed. The simulator was not launched and the physical phone
was not changed.

Manual test: open Settings → Appearance, tap a hex field and each RGB slider,
confirm the keyboard remains visible, swipe it down to dismiss, and repeat.

## Restore track-list artwork tab swipes — 2026-07-27 UTC

Track-list album artwork in local Album/All Albums views and Streaming album,
All Albums, and playlist views now has a scoped horizontal tab-swipe gesture.
The page transition can begin from the artwork thumbnail again, while the rest
of each row remains available for metadata, Play Next, Add to Queue, and
playlist swipe actions.

Regression checks, `git diff --check`, simulator build, and in-place simulator
installation passed. The simulator was not launched and the physical phone
was not changed.

Manual test: in local and Streaming Album and All Albums track lists, swipe on
the album artwork to change tabs; swipe on the text/action area to confirm the
row actions still work.

## Directional hierarchy navigation — 2026-07-27 UTC

Horizontal swipes continue to move to the corresponding adjacent tab. A
predominantly downward swipe now dismisses the active detail level throughout
the local and Streaming artist, album, and all-albums surfaces: tracks return
to the album/artist collection, and album collections return to the artist
view. The vertical gesture is simultaneous with list scrolling and does not
claim horizontal row actions.

Regression checks, `git diff --check`, and the signed phone build/install
passed. The phone app was not launched.

Manual test: swipe left and right on Library, Streaming, and Settings to reach
the corresponding tabs; in an album, All Albums, or artist detail surface,
swipe downward from the content area and confirm it returns exactly one level.

## Library hierarchy presentation direction — 2026-07-27 UTC

Library and Streaming artist and album detail destinations now use full-screen
hierarchy presentations. Selecting an artist or album brings the detail module
up from the bottom; dismissing tracks back to albums or albums back to artists
moves the module downward. The retained horizontal animation between Playing,
Library, Streaming, and Settings is unchanged.

Regression checks, `git diff --check`, strict simulator and generic-device
preflight passed. The next Debug simulator build is for manual animation
acceptance; the physical phone is not launched automatically.

Manual test: select an artist and album in Library and Streaming, confirm each
detail page enters from the bottom, then swipe downward or use Back and confirm
the prior list moves down into place. Verify tab swipes still move the complete
Playing, Library, Streaming, and Settings pages horizontally.

## Interactive horizontal tab gesture repair — 2026-07-27 UTC

The horizontal tab transition now begins after a short five-point movement and
uses a simultaneous root recognizer so nested scrolling and detail surfaces do
not frequently cancel it. Directional locking requires a clearly horizontal
drag, and the selected page follows the finger continuously; releasing below
the transition threshold commits the adjacent tab, while dragging back and
releasing cancels to the original position.

Regression checks, `git diff --check`, strict simulator and generic-device
preflight, signed phone build, and in-place phone installation passed. The
physical app was not launched automatically.

Manual test: from each of Playing, Library, Streaming, and Settings, begin a
horizontal drag and confirm the whole page follows the finger. Return the
finger near its starting point and release to cancel; repeat with a longer
drag to commit the adjacent tab. Confirm vertical scrolling and track-row
actions remain unaffected.

## Prototype status completion — 2026-07-27 UTC

The Settings → Prototype Status list now marks Online artwork search complete,
identifies its Apple and MusicBrainz / Cover Art Archive sources, and reports 100% stage
completion.

## Detail-module bottom navigation — 2026-07-27 UTC

Local and Streaming artist, album, and All Albums detail modules now use the
same environment-backed bottom navigation bar as the four retained root tabs:
Playing, Library, Streaming, and Settings. Selecting a tab from a detail module
dismisses any open detail layer and switches to the requested retained tab.

Regression checks, diff validation, and an XcodeBuildMCP simulator build and
install passed. The simulator detail surfaces exposed all four tab buttons;
the physical phone was not changed or launched.

## Restore detail hierarchy swipe with bottom navigation — 2026-07-27 UTC

The shared detail navigation shell now attaches the downward hierarchy gesture
to the detail content before adding the bottom tab bar as a safe-area inset.
Artist, album, and All Albums content follows the finger and dismisses back to
the previous level, while the Playing/Library/Streaming/Settings bar remains
docked at the bottom.

Regression checks and the simulator build passed. Simulator interaction
confirmed an artist detail downward drag dismisses back to Library; the
physical phone was not changed or launched.

## Restore detail navigation bars — 2026-07-27 UTC

Full-screen local and Streaming artist, album, and All Albums presentations
now wrap their detail content in a `NavigationStack`, allowing the existing
SwiftUI toolbar items to render again. Artist details include Back, view
options, and playlist controls; album details include Back and album actions;
Streaming artist details expose matching view options and playlist access.

Regression checks and the simulator build passed. The simulator showed the
restored artist Back/options controls; the physical phone was not changed or
launched.

## Play actions open Playing — 2026-07-27 UTC

Every explicit play request now selects the Playing tab immediately. Detail
modules also select Playing and dismiss their full-screen presentation when a
play request arrives, so playback started from an artist, album, All Albums, or
track list cannot remain hidden behind the detail layer.

The Debug simulator build and in-place simulator install passed. The simulator
was not launched or interacted with; the physical phone was not changed.

Manual test: start playback from each local and Streaming entry point and
confirm the app immediately shows Playing.

## Mini-player on detail modules — 2026-07-27 UTC

The shared detail navigation shell now includes the same mini-player used by
the root tabs. Artist, album, and All Albums modules inherit the current
top/bottom or side-docked position, controls, Playing-tab action, and bottom
navigation without changing their hierarchy swipe behavior.

The Debug simulator build/install and signed Release phone build/in-place
install passed. Neither device was launched or interacted with.

## Complementary theme text colors — 2026-07-27 UTC

Each visual theme now uses a complementary text accent hue, chosen from the
opposite side of the color wheel from its background artwork. Secondary labels,
inactive tab text, status text, alphabet indexes, and section labels use matching
complementary variants. Existing theme control tints and custom hex behavior are
unchanged; when Apply theme color to text is enabled, themed text uses the new
complementary palette.

`git diff --check`, the Debug simulator build, and in-place simulator
installation passed. The simulator was not launched or interacted with, and the
physical phone was not changed.

Manual test: in Settings → Appearance, enable Apply theme color to text and
switch through every visual theme. Confirm text, alphabet indexes, inactive tab
labels, and status labels contrast with the background image while controls keep
their existing themed tint.

## Psychedelic neon-yellow text — 2026-07-27 UTC

The Psychedelic theme's complementary primary and secondary text colors are now
`F4FF00`, producing a vivid neon yellow against its ultraviolet background.

The strict simulator/device preflight, signed arm64 Release build, deep
code-signature verification, and in-place installation on SaiyanDenawa passed.
The phone reports version 0.3.7.4/build 102. The requested launch was attempted,
but iOS denied it because the phone was locked; no runtime interaction occurred.

Manual test after unlocking the phone: open Settings → Appearance, select
Psychedelic, enable Apply theme color to text, and confirm the text, alphabet
indexes, inactive tab labels, and status labels use the neon-yellow treatment.

## Beta v1.0.2 Release Candidate 1 — 2026-07-27 UTC

Build 102 is the Beta v1.0.2 Release Candidate 1. It includes the selectable
hero-button skins and live current-track artwork in the Appearance previews,
the borderless and more spacious artwork/button hero modules, corrected hex
slider marker alignment, and the complete interface-polish work documented
above.

Validation passed: `Tools/RegressionChecks.sh`, Swift parsing, plist/project
validation, strict simulator and generic-device preflight, signed arm64
Release compilation, deep code-signature verification, and in-place install on
SaiyanDenawa. `devicectl` verified version `0.3.7.4`, build `102`. The phone
was not launched. The source and documentation are pushed to commit `5796010`
on `agent/alpha-3.7.4-source` on GitHub.

Manual release-candidate checklist: on the phone, open Settings → Appearance
and verify all four hero-button styles and both current-track artwork previews;
check the hex markers against `00`, `10`, `A0`, and `F0`; inspect local and
Streaming artist/album heroes; and verify existing playback, navigation, and
scrolling behavior remains intact.

## Appearance hero-button styles — 2026-07-27 UTC

Appearance now includes a persisted Hero buttons picker with four transparent
styles: Soft Glass, Matte Crystal, Inner Glow, and Minimal Transparent. The
shared hero action component applies the selection to the fixed-size controls
around local and Streaming album artwork without changing their layout,
positions, or touch actions. A live preview using the same arrangement appears
immediately below the picker. Existing users default to Soft Glass.

The Swift parser, diff checks, and repository regression checks passed. The
Debug simulator build and in-place install passed on the configured iPhone 17
Pro simulator. The simulator was not launched or interacted with, and the
physical phone was not changed.

Manual test: open Settings → Appearance, select each Hero buttons style, then
open local and Streaming artist/album detail pages. Confirm the four action
buttons keep their current positions and sizes, remain readable over every
theme, and retain their normal tap, long-press, and accessibility behavior.

## Remove hero-surface outline — 2026-07-27 UTC

Removed the 1px accent outline around the shared artwork-and-hero-button module
on local and Streaming artist and album detail pages. The transparent themed
surface, button skins, layout, and controls remain unchanged.

Tools/RegressionChecks.sh, Swift parsing, git diff --check, the Debug simulator
build, and in-place simulator installation passed. The simulator was not
launched or interacted with, and the physical phone was not changed.

## Correct hex slider track alignment — 2026-07-27 UTC

The hex slider track layer now shares the marker row’s explicit full-width,
leading-aligned coordinate frame. This removes the extra thumb-radius shift
that placed the visible track to the right of its `0`–`F` markers.

Tools/RegressionChecks.sh, Swift parsing, git diff --check, the Debug simulator
build, and in-place simulator installation passed. The simulator Settings UI
was opened and visually inspected: the `50` thumb aligned with the `5` marker,
and the `0` and `F` markers aligned with the `00` and `F0` track positions.
The physical phone was not changed.

## Current-track artwork in Appearance previews — 2026-07-27 UTC

The Live Theme Preview and Hero button preview in Settings → Appearance now
show artwork from the currently playing track when available. They retain the
existing placeholder artwork when playback is idle or the track has no artwork,
and both previews use the shared artwork loading and override path.

Tools/RegressionChecks.sh, Swift parsing, git diff --check, the Debug simulator
build, and in-place simulator installation passed. The simulator was not
launched or interacted with, and the physical phone was not changed.

## Align hex slider nibble markers — 2026-07-27 UTC

RGB hex slider markers now use explicit byte positions: 0 aligns with `00`, 1
with `10`, through F aligning with `F0`. The marker row uses the same explicit
80%-width coordinate space as the slider track, including the thumb insets.

Tools/RegressionChecks.sh, Swift parsing, git diff --check, the Debug simulator
build, and in-place simulator installation passed. The simulator was not
launched or interacted with, and the physical phone was not changed.

## Increase hero-button spacing — 2026-07-27 UTC

The horizontal gap between the artwork and adjacent hero-button columns is now
16 points in local and Streaming artist and album detail heroes, up from 12
points. Artwork size, button size, positioning, and actions are unchanged.

Tools/RegressionChecks.sh, Swift parsing, git diff --check, the Debug simulator
build, and in-place simulator installation passed. The simulator was not
launched or interacted with, and the physical phone was not changed.

## Settings swipe-safe theme selection and tighter category spacing — 2026-07-27 UTC

Settings visual-theme cards and accent palette buttons now use the shared
swipe-aware button style and horizontal-swipe suppression guard. A horizontal
navigation swipe therefore cannot accidentally select a theme or accent; a
stationary tap still performs the selection. Settings category rows also use
smaller vertical insets and row spacing so the disclosure controls sit closer
together.

The Debug simulator build and in-place simulator install passed. The
simulator was not launched or interacted with, and the physical phone was not
changed.

The live Connection status now appears immediately below Test Connection. The
Debug simulator was rebuilt and the updated app was installed in place
successfully; it was not launched or interacted with.

Connection failures now render the status value in bold red using the shared
remote-store failure detection. Healthy, cached, and in-progress states retain
the themed text styling. The Debug simulator was rebuilt and the updated app
was installed in place successfully; it was not launched or interacted with.

## Settings playback organization — 2026-07-27 UTC

The empty Library disclosure was removed. Playback is now organized under
titled Library, Shared Playback, and Streaming Library subsections. Local
preload settings and details are under Library; common engine, lock-screen,
and audio-routing information is under Shared Playback; streaming buffer
settings and network-buffer information are under Streaming Library.
Connection configuration remains in the separate Streaming Library disclosure.

The preflight, signed Release device build, deep code-signature verification,
and in-place installation on SaiyanDenawa passed. The installed app reports
version 0.3.7.4, build 101. The physical phone was not launched or
interacted with.

## Remove outdated streaming gapless notice — 2026-07-27 UTC

Removed the Settings message that said streaming gapless playback was
disabled during alpha testing. No build or device validation was performed for
this source-only text change.

## Label Streaming API path — 2026-07-27 UTC

The Streaming Library path field now has a persistent “API path” label when
using Subsonic, so a filled `/rest` value remains clearly identified. Manifest
backends use the corresponding “Manifest path” label.

No build or device validation was performed for this source-only layout change.

Manual test: swipe across Settings, including over theme cards and accent
colors, and confirm no appearance setting changes; then tap a card or color
normally and confirm it still applies.

The Settings disclosure spacing was subsequently reduced by half: list-row
spacing is 2 points, category vertical padding is 1.5 points, and category
row insets are 1 point vertically. The Debug simulator build and in-place
simulator install passed; the simulator was not launched or interacted with.

The Form section spacing was then reduced to 4 points as well, which controls
the visible gap between Appearance, Playback, Streaming Library, and the other
disclosure sections. The Debug simulator was rebuilt and the updated app was
installed in place successfully; it was not launched or interacted with.

## Streaming connection controls moved to the top — 2026-07-27 UTC

Within the Streaming Library disclosure, the server address, port, transport
and API fields, Subsonic credentials, and connection actions now appear before
buffer, catalog status, and other secondary streaming details. The action
behavior and validation rules are unchanged.

The Debug simulator build and in-place simulator install passed. The
simulator was not launched or interacted with, and the physical phone was not
changed.

## Playing gesture arbitration and alphabet accent colors — 2026-07-27 UTC

Playing no longer receives the root tab recognizer while its dedicated upper
content gesture is active. The album-art pager keeps ownership of artwork
drags, preventing the page transition from stuttering or bouncing against an
invisible ancestor gesture. The right-side alphabet index and alphabetical
section labels now use the active theme text accent, including a committed
custom hex accent.

The signed Release phone build and in-place install passed. The physical phone
was not launched or interacted with.

Manual test: on Playing, drag the upper metadata area and confirm the page
follows the finger smoothly; swipe album art to change tracks; verify the seek,
volume, and lower controls do not navigate tabs. In Library and Streaming,
confirm the index letters and section labels use the selected theme or hex
accent color.

## Non-overlapping Playing swipe regions — 2026-07-27 UTC

Playing now has an explicit tab-swipe zone between the album-art pager and the
track seek bar. Clear insets keep that zone separate from both the album-art
track pager and the seek bar, so horizontal navigation cannot steal either
gesture.

No build or device validation was performed for this change. Manual
continuation: swipe in the metadata gap to change tabs, swipe album art to
change tracks, and confirm swipes on the seek bar do not change tabs.

## Restore detail list scrolling — 2026-07-27 UTC

The shared top-down hierarchy gesture now recognizes simultaneously with the
detail content instead of taking high-priority ownership of the entire module.
Its top-origin and vertical-direction guards keep navigation confined to the
upper detail surface, so album and song Lists/ScrollViews retain their normal
vertical scrolling.

Regression source validation, the Debug simulator build/install, signed
Release phone build, code-signature verification, and in-place phone install
passed. Neither device was launched or interacted with.

Manual test: scroll album grids, album track lists, All Albums track lists,
and Streaming detail lists normally; swipe downward from the upper detail
surface and confirm it still dismisses one hierarchy level.

Manual test: with a track playing, open local and Streaming artist, album, and
All Albums modules. Confirm the mini-player remains visible and its controls,
docking, Playing action, and hierarchy swipes remain usable.

## Continuous alphabet grids — 2026-07-27 UTC

Library and Streaming alphabetized grid surfaces now use the shared
`ResonanceAlphabetGrid` layout. Section boundaries no longer reset a nested
grid, so a new artist or album can occupy the remaining cell on the current
row. Letter labels remain attached to section starts and the alphabet index
continues to scroll to those tiles. Non-grid list layouts and non-alphabetized
track grids are unchanged.

The Debug simulator build and in-place simulator install passed. The simulator
was not launched or interacted with, and the physical phone was not changed.

Manual test: switch Library and Streaming Artists, Albums, and artist-detail
album views to Grid, then confirm tiles continue across letter boundaries and
the right-side alphabet still lands on each letter.

## Playing swipe ownership — 2026-07-27 UTC

Playing-page tab navigation now owns only the upper content region ending above
the track seek bar. The seek bar, transport controls, volume slider, and lower
controls no longer initiate horizontal tab navigation. The album-art pager
retains its dedicated left/right gesture for changing tracks.

The Debug simulator build/install and signed Release phone build/in-place
install passed. Neither device was launched or interacted with.

## Resonance Beta v1.0.3 — 2026-07-27 UTC (superseded)

Build 103 was published as the first Beta v1.0.3 attempt, but it retained the
previous `F4FF00` value in the Psychedelic text-color fields. It is superseded
by the corrected build below.

The v1.0.3 source and beta tag remain available in GitHub for history.

## Resonance Beta v1.0.4 — 2026-07-27 UTC

The Psychedelic theme now uses exact `FFFF00` neon yellow for its primary and
secondary themed text when **Apply theme color to text** is enabled. This
keeps the theme's alphabet indexes, section labels, inactive tab labels, and
status text on the requested pure-neon-yellow value.

Build 104 retains version `0.3.7.4` and is published as the corrected
`Resonance-Beta-v1.0.4` beta release. `Tools/RegressionChecks.sh`, the signed
arm64 Release build, deep code-signature verification, and in-place install on
SaiyanDenawa passed. The phone reports version `0.3.7.4`, build `104`; it was
not launched or interacted with.

Manual test: open Settings → Appearance, select Psychedelic, enable **Apply
theme color to text**, and confirm the text, alphabet indexes, section labels,
inactive tab labels, and status text use `FFFF00`.

## Playing tab transition performance — 2026-07-27 UTC

The Playing tab transition no longer changes the root safe-area geometry when
the selected tab changes. The mini-player’s space remains reserved and its
content is hidden and noninteractive while Playing is selected, so entering or
leaving Playing does not insert or remove a layout subtree. The Now Playing
artwork pager now uses the shared asynchronous, downsampled artwork loader
instead of decoding three images synchronously on the main actor.

`Tools/RegressionChecks.sh`, `git diff --check`, signed arm64 Release
compilation, and deep code-signature verification passed. This source patch
was compiled but not installed or launched; the installed phone remains on
build 104 until the next explicit phone push.

Manual test: with a track playing, tap Playing repeatedly from Library,
Streaming, and Settings, then leave Playing for each tab. Confirm both
directions respond without a visible pause and that the mini-player remains
hidden on Playing and interactive on the other tabs.

## Playing swipe stability — 2026-07-27 UTC

The Playing-page tab swipe now measures movement in the fixed screen coordinate
space while the page follows the finger. This removes the moving-local-frame
feedback loop that caused the entire screen to vibrate during a held drag. The
gesture has priority within the metadata region, preserves the album-art and
slider gesture boundaries, and always resolves the release so slight vertical
drift cancels cleanly instead of leaving an incomplete transition.

Commit `1c69b32` records the fix. `Tools/RegressionChecks.sh`, `git diff
--check`, the Debug simulator build, and in-place simulator installation
passed. The simulator was not launched or interacted with, and the physical
phone was not changed.

Manual test: with a track playing, start a left-to-right or right-to-left drag
in the Playing metadata region and hold it at roughly 80% of the screen width.
The page should follow smoothly without vibration; releasing past halfway
should complete the tab transition, while releasing before halfway should
spring back. Album-art and seek/volume gestures should retain their existing
ownership.

## Resonance Beta v1.0.6 — 2026-07-27 UTC

Build 106 adds the opt-in **Experimental background downloads** setting under
Streaming Library. Enabled downloads use a dedicated iOS background
`URLSession` task, persist a credential-free track/task map, and move completed
files through an atomic application-support inbox before the normal targeted
library refresh. The existing foreground downloader remains the default when
the setting is off. iOS may defer transfers, and force-quitting Resonance
cancels system-managed background work, so the physical-device lock-screen
test remains part of this experiment.

The signed arm64 build, strict code-signature verification, and in-place device
installation are the release checks for this build. Codex does not launch the
physical app. Manual acceptance: enable the setting, start a multi-track
download, lock the phone, wait, unlock Resonance, and verify that the transfer
continued or is shown as resumable without partial-file indexing. Repeat after
relaunch, test cancellation and replacement choices, and confirm the setting
off path still uses the existing foreground downloader.

## Resonance Beta v1.0.5 — 2026-07-27 UTC

This beta includes the Playing transition performance repair and the follow-up
gesture-geometry fix. The Playing page now measures its live tab drag in fixed
screen coordinates, preventing the moving page from feeding its own offset back
into the gesture and causing rapid vibration during a held swipe. The metadata
region keeps priority for tab navigation, while album art remains dedicated to
track changes and the seek/volume controls retain their slider gestures. Release
handling also receives the full horizontal and vertical translation so slight
vertical drift cancels cleanly instead of leaving a partial transition.

Build 105 retains version `0.3.7.4` and is published as
`Resonance-Beta-v1.0.5`. The source fix is commit `1c69b32`; release metadata
is commit `898f52a`, and the release tag is `Resonance-Beta-v1.0.5`.

Manual test: with a track playing, swipe from the Playing metadata region and
hold at roughly 80% of the screen width. Confirm the page follows smoothly
without shaking, then release to complete the adjacent-tab transition. Repeat
with a short drag to confirm it springs back, and confirm album-art, seek, and
volume gestures remain independent.

## Artwork search provider and relevance repair — 2026-07-28

Deezer artwork search was removed after its public album endpoint returned an
HTTP 403 permission response. Online artwork search now uses Apple iTunes and
MusicBrainz/Cover Art Archive only. iTunes performs an album-only query before
the full artist/album/track query and combines both result sets, so a noisy
nonempty contextual response no longer suppresses the useful album search.
MusicBrainz searches up to 25 releases using both available artist identities,
uses the returned artist credits for relevance scoring, and automatic artwork
fallback now checks up to 24 candidates for a usable image. Failed image cards
are removed from the picker, and unavailable providers are named in the picker
instead of appearing as an unexplained empty result.

`Tools/RegressionChecks.sh`, `git diff --check`, strict Swift 6 simulator and
generic-device preflight with warnings treated as errors, signed arm64 Release
compilation, and strict deep code-signature verification passed. The signed
app was installed in place on `SaiyanDenawa`; `devicectl` verified bundle
`com.example.ResonancePrototype`, version `0.3.7.4`, build `107`. The phone
app was not launched. Xcode emitted the known empty supported-platforms
destination warning and harmless AppIntents metadata-skip warning; neither
blocked the build or install.

Manual test checklist: open a local album editor for a well-known album such
as *Thriller*, *Abbey Road*, or *OK Computer*; confirm multiple Apple and
MusicBrainz/Cover Art Archive candidates appear; verify a failed image card
disappears and the red recommended outline advances; retry with an album whose
artist metadata contains an alternate album-artist value; confirm Streaming
automatic artwork still finds a usable candidate. Do not uninstall first.

## Poweramp-style MusicBrainz artwork queries — 2026-07-28

The previous release-group repair still used an exact MusicBrainz release query
and synthesized one Cover Art Archive URL per release. The artwork search now
uses the album title as the primary MusicBrainz release-group query, adds an
artist-qualified release-group query when artist metadata is available, and
uses the Cover Art Archive release-group JSON endpoint to obtain only actual
front-image URLs. This matches the observable current Poweramp behavior more
closely: album-art lookup is title-driven and uses MusicBrainz/Cover Art Archive
rather than a generic image search. Apple iTunes remains an additional
album-first source; Deezer remains removed.

Live endpoint checks returned usable release groups and front images for
*Thriller*, *The Dark Side of the Moon*, *Abbey Road*, and *OK Computer*.
`Tools/RegressionChecks.sh`, `git diff --check`, strict Swift 6 simulator and
generic-device preflight with warnings treated as errors, signed arm64 Release
compilation, strict deep code-signature verification, and in-place install
passed. `devicectl` verified `com.example.ResonancePrototype`, version
`0.3.7.4`, build `108` on `SaiyanDenawa`. The phone app was not launched.

Manual test checklist: launch build 108, open Search Online Artwork for a
popular album, confirm the result cards show MusicBrainz/Cover Art Archive
source labels and front artwork, then repeat with an album whose artist or
album-artist tag is incomplete or composite. Confirm the title-only fallback
still finds the album and that Streaming automatic artwork resolves the same
cover. Do not uninstall first.

## Global album-title fallback queries — 2026-07-28

The artwork search no longer assumes an album title must match exactly. Every
album query now retains the original metadata and also generates generic
fallback titles by removing recognized trailing release metadata, including
quality tags such as `24 bit` and parenthesized release tags such as
`(2011 Japan Remaster)`. These variants are used for both Apple iTunes and
MusicBrainz/Cover Art Archive queries; no artist- or album-specific exceptions
or search restrictions are present. Meaningful parenthetical titles remain
untouched unless they contain release-metadata markers.

Build 109 passed `Tools/RegressionChecks.sh`, `git diff --check`, strict Swift
6 simulator and generic-device preflight with warnings treated as errors,
signed arm64 Release compilation, strict deep code-signature verification,
and in-place installation. `devicectl` verified
`com.example.ResonancePrototype`, version `0.3.7.4`, build `109` on
`SaiyanDenawa`. The phone app was not launched. The known empty
supported-platforms destination warning and harmless AppIntents metadata-skip
warning remained non-blocking.

Manual test checklist: launch build 109, search for both an exact album title
and a title with a suffix such as `24 bit` or `(2011 Japan Remaster)`, then
repeat with Deluxe, Anniversary, FLAC, and other release-metadata suffixes.
Confirm the results show the canonical album artwork while preserving the
original local title. Also verify that meaningful parenthetical titles are not
incorrectly shortened. Do not uninstall first.

## Experimental low-risk refactor — 2026-07-28

This experimental source build unifies two behavior-preserving seams without
splitting `RemoteLibraryStore.swift`. `LibraryBrowseGrouping.swift` owns only
the pure mixed-artist/compilation-candidate identity algorithm; local and
remote stores retain their own normalization policies, filtering, caching,
display-name rules, model construction, and explicit compilation behavior.
`MetadataWriteBatch.swift` owns only sequential per-file tag-write
orchestration and ordered failure collection. Track, album, and artist editors
retain their existing validation, artwork sidecar, override, persistence, and
rescan behavior.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, a Debug
simulator build, and `Tools/PreflightBuild.sh` with Swift 6 strict concurrency
and warnings treated as errors for simulator and generic device. A signed
Release build passed deep strict code-signature verification and was installed
in place on `SaiyanDenawa`; `devicectl` verified version `0.3.7.4`, build `109`.
The physical app was not launched. The preflight reported only the existing
no-scheme destination and harmless AppIntents metadata-skip warnings.

Manual checklist: edit a local FLAC and MP3 track, album, and artist; verify
successful writes, partial failures, unsupported-format errors, artwork
replacement, and artwork-only fallback behavior. Browse local and Streaming
mixed-artist albums, including case/whitespace variants, differing release
years, and explicit compilation grouping. Confirm normal single-artist albums
remain unchanged. Do not uninstall the existing app.

## Experimental build 113 — unified background save actions

Track, album, and artist metadata editor saves now dismiss immediately and continue through background tasks. Online
artwork search Apply to App and Save to Files actions also dismiss first; file metadata saves use the same background
entry points, while app-only artwork application is deferred until after the search sheet closes. Completion and
failure counts remain privacy-safe diagnostics rather than modal save errors.

Manual test checklist: trigger Save from track, album, and artist editors; use Apply to App and Save to Files from
online artwork search for track, album, and artist contexts; confirm each sheet dismisses immediately. While each save
runs, switch tabs, scroll, play audio, and open another detail page. Confirm metadata/artwork persistence, red-border
semantics, external tag-reader results, and diagnostics after relaunch.

## Experimental build 114 — isolate artist artwork and validate downloaded images

Artist metadata saves now write artist and album-artist text tags without writing artwork to any track file. Artist
artwork remains an artist-only Resonance override, survives artist renames, and is removed only by an explicit remove
action. Online artwork responses are decoded and normalized to JPEG before they can be applied or written to files,
so an HTTP-success response that is not renderable is rejected instead of producing a blank cover.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `114`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: edit artist artwork and confirm every album/song keeps its own artwork; edit artist text without
artwork and confirm the artist override remains; rename an artist and confirm its artwork follows the rename; explicitly
remove artist artwork and confirm only the artist artwork clears. Search online artwork for an artist, album, and track,
apply each result to the app, save each to FLAC/MP3 files, and confirm the image remains visible after relaunch and an
external tag reader. Do not uninstall the existing app.

## Experimental build 115 — repair MP3 APIC artwork readback

The metadata reader now detects when AVFoundation returns an MP3 ID3 APIC frame wrapper instead of only the embedded
image bytes. It unwraps the MIME, picture-type, and description fields, validates the remaining image with ImageIO, and
stores only renderable artwork in the library database. Existing valid image data remains unchanged.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `115`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: relaunch the app, open Acoustica by A Perfect Circle, and confirm album artwork is visible. Edit
album metadata without changing artwork and confirm it remains visible. Replace album artwork, save it to files, and
confirm all tracks display it after relaunch. Edit one MP3 and one FLAC individually, both with and without artwork,
and confirm the image remains visible in Resonance and in an external tag reader. Repeat with an artwork search result.

## Experimental build 116 — unwrap dimension-prefixed MP3 artwork and repair album fallback

The metadata reader now also handles MP3 artwork returned with a five-byte little-endian thumbnail-dimension prefix
before the image payload. Cached artwork is validated when loaded from the library database, so malformed non-empty data
is discarded and album artwork can fall back to the first renderable track instead of being blocked by an invalid first
track.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `116`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: reopen Mer de Noms and confirm album artwork appears even when the first track has no artwork;
edit album metadata without changing artwork; replace album artwork and confirm every file and the album view update;
repeat for Acoustica, then edit individual MP3 and FLAC tracks and verify artwork in Resonance and an external tag reader.

## Experimental build 117 — repair missing JPEG start markers

Some MP3 artwork payloads contained a valid Exif/JPEG APP segment but were missing the JPEG start marker (`FF D8`).
Artwork normalization now restores that marker when the repaired payload validates with ImageIO. This repaired data is
used both when loading cached artwork and before it is written back into FLAC/MP3 metadata.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `117`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: open Acoustica, save artwork to the album and to two individual MP3 files, and confirm the album
hero, track rows, relaunch, and an external tag reader all show the image. Confirm Mer de Noms still uses valid fallback
artwork when one track is artless. Test one FLAC artwork save as a regression check.

## Experimental build 118 — unify remote URL resolution

Manifest base URLs, Subsonic endpoint URLs, and manifest-relative stream/artwork URLs now share one small URL-support
utility for path joining and relative resolution. Backend-specific request headers, authentication query construction,
response validation, and download behavior remain separate. The change preserves existing host/path normalization while
removing duplicate URL path logic.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `118`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: verify a Resonance Manifest server with a host path, relative track/artwork paths, and absolute
URLs; verify Navidrome/Subsonic login, catalog refresh, album artwork, playback, playlist actions, and downloads. Test
host-only, host-plus-port, HTTPS, and a server URL that already includes the manifest/API path. Do not uninstall first.

## Experimental build 119 — extract shared remote URL support

The URL path-joining and relative-resolution helpers introduced in build 118 now live in `RemoteURLSupport.swift`,
separate from `RemoteLibraryStore.swift`. This is a structural extraction only: Manifest and Subsonic behavior,
authentication, request headers, response validation, and downloads remain unchanged.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `119`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: use Navidrome/Subsonic only—sign in or reconnect, refresh the catalog, open artists, albums, and
tracks, load artwork, play a remote track, test playlists and favorites, and start, cancel, and resume a download.
Also test host-only, host-plus-port, HTTPS, and any server URL that includes a path. Confirm streaming behavior is
unchanged. Do not uninstall first.

## Experimental build 120 — repair duplicate downloads and deletion reporting

Download requests now separate existing destination files from new tracks. The replacement alert is hosted by a stable
visible container; choosing Replace Existing downloads the duplicate and new tracks, while choosing Keep Existing skips
duplicates and downloads the remaining tracks. Local file deletion now records credential-free requested, deleted,
missing, and failed counts so deletion problems can be distinguished from filename collisions.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `120`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: delete one downloaded track with Delete from iPhone and confirm it disappears after a library
refresh; download a track that is not present; select a mix of an existing and a new track and verify the prompt appears.
Choose Keep Existing and confirm only the new track downloads, then repeat and choose Replace Existing to confirm both
download. Also test deleting an album and artist, and inspect diagnostics afterward for the deletion counts.

## Experimental build 121 — share download overlay across Streaming detail views

The existing `RemoteDownloadOverlay` is now shared by the Streaming Library root and the Streaming artist and album
detail surfaces. A download started from an artist or album remains observable through the same
`RemoteDownloadManager` queue while navigating between detail and root views. Duplicate detection now searches all
supported local audio extensions instead of relying only on the remote stream URL extension, so an existing saved file
is recognized even when the server URL has no matching extension.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `121`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: from a Streaming artist detail page, start an artist download and verify the shared overlay is
visible there; from an album detail page, start an album download and verify the overlay and replacement prompt are
visible without returning to the Streaming root. Delete one track from an album, request the album again, and confirm
only the missing track downloads. Test a mixed existing/new batch with Keep Existing and Replace Existing, navigate
between artist, album, and Streaming root while active, and cancel from each visible overlay.

## Experimental build 122 — stabilize detail download controls and replacement UI

Streaming artist detail now has a toolbar download control plus context-menu actions for the artist collection, All
Albums, and individual albums. The shared `RemoteDownloadOverlay` now renders replacement choices in-app instead of
using competing system alerts from multiple presentation levels; this keeps the prompt visible on the active detail
surface and prevents it from flashing away when the full-screen detail presentation changes. The single shared queue
and manager remain unchanged.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `122`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: on a Streaming artist detail page, use the toolbar download control, long-press All Albums and
an album, and confirm each offers a download action. On an album detail page, start a duplicate-containing download
and verify the in-app Files Already Exist prompt stays visible with Keep Existing, Replace Existing, and Cancel. Confirm
the detail page remains open, the shared overlay shows progress, and navigation to the Streaming root preserves the
same queue.

## Experimental build 123 — make hero download controls explicit menus

The artist and album hero Download controls now open the same explicit download-action menu as their context-menu
counterparts. Choosing Download Artist or Download Album then uses the shared `RemoteDownloadManager`, so the user can
see the action before it begins and receives the same duplicate/replacement behavior.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `123`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: tap the artist hero Download control and confirm its menu offers Download Artist; tap the album
hero Download control and confirm its menu offers Download Album. Choose each action and verify the shared overlay and
replacement prompt behave exactly like the context-menu path. Confirm Play, Play Next, Add to Queue, and navigation
remain unchanged.

## Experimental build 124 — correct hero menu scope labels

The shared hero download menu now interpolates its scope correctly. The artist hero menu displays Download Artist and
the album hero menu displays Download Album; both actions invoke the same shared download manager and queue as the
context-menu actions.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `124`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: open a Yes artist detail page and verify the hero menu says Download Artist and downloads the
artist collection. Open Close to the Edge and verify the hero menu says Download Album and starts that album download.
Confirm the shared progress overlay, duplicate prompt, cancellation, and navigation behavior remain functional.

## Experimental build 125 — extract the remote download service

The remote download subsystem now lives in `Resonance/Services/RemoteDownloadService.swift`. The extraction includes
`RemoteDownloadManager`, the background URL session delegate, queue/progress models, duplicate/replacement handling,
resume/cancellation, file finalization, and local-library refresh calls. `RemoteLibraryStore.swift` retains the remote
catalog and backend responsibilities; views continue using the same shared `RemoteDownloadManager` interface.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `125`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: download from the Streaming root, artist hero/menu/context menu, album hero/menu/context menu,
and an individual track. Test a missing track in an otherwise downloaded album; mixed existing/new downloads with Keep
Existing, Replace Existing, and Cancel; progress and per-track cancellation; resume after interruption; navigation
between root, artist, and album while active; offline playback of completed files; and deletion followed by redownload.

## Experimental build 126 — expose root streaming download actions

The Streaming Library root toolbar now uses the shared `StreamingDownloadActionsMenu` for download selections.
Selecting artists or albums exposes explicit Download Artist(s) and Download Album(s) actions instead of starting
immediately from a bare download button. These actions still call the shared `RemoteDownloadManager`, so duplicate
detection, Keep Existing/Replace Existing/Cancel, the persistent queue, and root/artist/album overlay behavior remain
unchanged. The old root-only download helper was removed.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `126`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: in Streaming root, long-press one or more artists and one or more albums, open the root
toolbar menu, and choose Download Artist(s) or Download Album(s). Verify the duplicate prompt appears when appropriate
and that Keep Existing, Replace Existing, and Cancel work. Confirm the download window persists while navigating
root → artist → album, and verify the existing artist/album hero and context-menu actions remain unchanged.

## Experimental build 127 — confine tab swipes to album heroes

Horizontal tab navigation in local and Streaming album detail is now owned by the fixed album hero/artwork area
above the track list. Individual track rows no longer attach the tab-swipe recognizer, so horizontal interaction on
a track remains available for its Play Next, Add to Queue, playlist, download, and related row actions. The track-only
All Albums screens also no longer claim horizontal tab navigation.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `127`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: in a local album and a Streaming album, swipe horizontally across the artwork/header area and
verify tab navigation. Swipe horizontally across several individual tracks and verify tab navigation does not occur;
the track action menu remains available. Test Play Next, Add to Queue, playlist, and Download Track actions, then verify
vertical scrolling, Back, downward hierarchy dismissal, and the root/artist/album download overlay remain unchanged.

## Experimental build 128 — add Streaming track download swipe action

Streaming track rows now keep Play Next and Add to Queue on the leading swipe and expose Download on the trailing
right-to-left swipe. The Download action uses the shared `RemoteDownloadManager`, so existing-file prompts, queue
progress, cancellation, and replacement behavior match the context-menu and hero download paths. The action is present
in album, artist/all-albums, playlist, and other Streaming track collections.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `128`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: in Streaming album, artist/all-albums, playlist, and track-collection views, swipe left-to-right
on a track and verify Play Next/Add to Queue remain available. Swipe right-to-left and verify Download appears and
starts the shared download flow. Test an existing file and confirm Keep Existing, Replace Existing, and Cancel, then
verify the persistent overlay and navigation behavior remain unchanged.

## Beta stabilization build 130 — navigation-rework baseline

Build 130 freezes the currently validated download and gesture behavior before the planned navigation rework. It
contains no navigation implementation changes: Streaming track rows retain leading Play Next/Add to Queue and
trailing Download actions, album-art heroes own horizontal tab navigation, and All Albums renders the shared download
overlay for replacement prompts.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `130`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

This build is the rollback and comparison baseline for the navigation rework. Do not uninstall it before testing the
next navigation build.

## Experimental build 132 — layered vertical navigation

The bottom tab-navigation pane is no longer rendered. RootView now owns a layered vertical navigation coordinator:
Player, current-track Album, Artist, and Library/Streaming root surfaces remain stacked, and moving upward lowers the
front surface to reveal the surface beneath it. The Player’s top-center Album control, Album’s Artist control, and
Artist’s Library/Streaming root control use the same animated surface transitions; downward swipes perform the matching
reverse transition. The root surface has a single Library/Streaming switch control and a gear control that presents
Settings from the bottom. The mini-player is now a compact bottom Player surface rather than part of a bottom tab pane.

The current track resolves its local or remote album and artist context. Library and Streaming artist/album selections
now route into the same layered coordinator, while existing screen-specific menus and actions remain in place. Detail
surfaces hide their legacy Back buttons and bottom tab/mini-player insets when participating in the layered flow.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `132`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: launch build 132 and confirm the bottom tab bar is absent. Start a local track and a Streaming
track, open the Player, press Album ↑, and verify the Player lowers to reveal the correct album. Press Artist ↑, then
Library/Streaming ↑, and verify the vertical transitions. Test downward swipes at each layer. From each root, use the
Library/Streaming switch and gear Settings control; close Settings downward. Confirm existing menus, playback controls,
track actions, downloads, artwork, and metadata actions remain usable. Keep build 130 installed as the rollback baseline.

## Experimental build 134 — transparent layered surfaces and All Albums navigation

The inactive Settings layer now sits completely below the viewport rather than beginning on the bottom pixel. New layered
NavigationStacks and the custom layer header hide their system navigation backgrounds and use clear surfaces so the shared
theme backdrop remains visible through Library, Streaming, Artist, Album, All Albums, Player, and Settings. Local and
Streaming All Albums destinations now participate in the layered coordinator and expose the same `Artist ↑` navigation as
the other artist-level children instead of bypassing the new navigation through a legacy full-screen cover.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed strict
deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version `0.3.7.4`,
build `134`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip warnings
remained non-blocking.

Manual test checklist: open local and Streaming Artist views, enter All Albums from both grid and list layouts, and verify
the `Artist ↑` header appears and returns to the artist. Repeat for normal albums, Player, and Settings. Enable frame
diagnostics and verify Settings has no border or label at the bottom while hidden. Switch through transparent-theme and
image-theme palettes and confirm the theme background remains visible behind every layered module and header.

## Experimental build 135 — restore root theme backgrounds

Library and Streaming now render their own `ResonanceThemeBackdrop()` behind the browse content. This prevents the
`NavigationStack`/system container from presenting an opaque black root surface over the active theme, while the existing
hidden list and scroll backgrounds allow the gradient or theme artwork to remain visible through the collections.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed strict
deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version `0.3.7.4`,
build `135`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip warnings
remained non-blocking.

Manual test checklist: switch among Gallery Light, Nocturne Glass, Color Bloom, Electronic, Psychedelic, and other themes;
confirm the Library and Streaming roots show their active gradient/image background, then verify Artist, All Albums, Album,
Player, and Settings retain the same background continuity. Keep frame diagnostics available for any remaining opaque or
clipped surface investigation.

## Experimental build 138 — centered frame diagnostics

The frame-diagnostics labels are now centered within their red outlined frames. Build 138 also includes the layered-stack
viewport clipping that prevents translated Player, Settings, and other inactive navigation surfaces from leaking their
toolbars or diagnostic labels into the bottom of the visible page. Settings is omitted from the hierarchy while inactive,
and Player and Settings own the active theme backdrop just like Library, Streaming, Artist, Album, and All Albums.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, `Tools/PreflightBuild.sh`, simulator build/install,
and a signed arm64 Release build with strict deep code-signature verification. Build 138 was installed in place on
`SaiyanDenawa`; `devicectl` verified version `0.3.7.4`, build `138`. The physical app was not launched. Existing
no-scheme destination and AppIntents metadata-skip warnings remained non-blocking.

Manual test checklist: enable frame diagnostics and confirm labels are centered in the Library, Artist, Album, All Albums,
Player, Settings, header, and mini-player frames. Confirm no inactive layer or black strip appears at the bottom. Start
playback and verify Now Playing uses the active theme background and controls. Switch themes and repeat the check.

## Experimental build 133 — frame diagnostics for layered navigation

Build 133 keeps the layered vertical navigation and adds a persisted Settings → Appearance → **Show frame diagnostics**
toggle. When enabled, major root, artist, album, Player, Settings, header, and mini-player surfaces receive a 1-device-pixel
red outline with a small frame label. This makes safe-area sizing, clipping, off-screen layers, and background coverage
visible during the experimental navigation work. The legacy side-docked mini-player handle is suppressed while layered
navigation is active, removing the clipped lower-left chevron seen in the simulator.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `133`. The simulator was shut down after inspection. The physical app was not launched. Existing
no-scheme destination and AppIntents metadata-skip warnings remained non-blocking.

Manual test checklist: launch build 133, open Settings, enable **Show frame diagnostics**, and inspect the labeled red
frames on Library, Streaming, Artist, Album, Player, and Settings. Check that no frame or label is unexpectedly clipped,
that the background occupies the intended layer, and that the lower-left chevron is gone. Disable the toggle and verify
the normal surfaces remain unchanged. Do not uninstall first.

## Experimental build 129 — restore All Albums replacement prompt

The Streaming All Albums track-list screen now renders the shared `RemoteDownloadOverlay`. Download requests from
that screen—including its track menus and swipe actions—can therefore display the existing-file prompt with Keep
Existing, Replace Existing, and Cancel, just like the artist and album detail screens. The underlying shared download
manager and queue behavior are unchanged.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build passed
strict deep code-signature verification and was installed in place on `SaiyanDenawa`; `devicectl` verified version
`0.3.7.4`, build `129`. The physical app was not launched. Existing no-scheme destination and AppIntents metadata-skip
warnings remained non-blocking.

Manual test checklist: open Streaming → artist → All Albums, invoke Download from a track menu or right-to-left
track swipe, and confirm the download window and existing-file prompt appear on the All Albums screen. Test Keep
Existing, Replace Existing, and Cancel, then verify progress persists while returning to the artist and Streaming root.

## Experimental build 139 — extend themed surfaces through the status area

The active themed page backdrop now extends through the iPhone status-bar safe area, so the region behind the time,
network, and battery indicators no longer appears black. Layer headers and navigation controls remain inside the safe
area and therefore stay below those system indicators.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and a Debug simulator build for iPhone 17 Pro.
Build 139 was installed and launched in place on the configured simulator, and a screenshot confirmed the active theme
fills the status-bar region while the header controls remain below it. The physical device was not changed or launched.

Manual test checklist: switch among Gallery Light, Nocturne Glass, Color Bloom, Electronic, Psychedelic, and other
themes; inspect Library, Streaming, Artist, All Albums, Album, Player, and Settings; confirm the theme reaches behind
the system status indicators and every navigation control remains below them. With frame diagnostics enabled, confirm
the header frame still begins below the status area.

## Experimental build 147 — extend themed surfaces through the home-indicator area

The root app surface now fills the bottom system inset with a bounded active-theme gradient/image strip. This removes
the black footer visible below Library, Streaming, detail modules, Player, and Settings while leaving navigation and
content controls above the home-indicator region. The fill is deliberately bounded so it cannot expand a module or
alter its scroll layout.

Validation passed: `Tools/RegressionChecks.sh`, `git diff --check`, and a Debug simulator build for iPhone 17 Pro.
Build 147 was installed and launched in place on the configured simulator; the captured screenshot showed themed
coverage through the bottom edge with no black footer and normal module rendering. The physical device was not changed
or launched.

Manual test checklist: inspect Library, Streaming, Artist, All Albums, Album, Player, and Settings with several themes.
Confirm the active theme reaches the bottom edge, the home indicator remains unobstructed, navigation controls stay in
their normal safe-area positions, and scrolling/content layout is unchanged.

## Experimental build 211 — complete local browse-cache audit — 2026-07-30

The cache-audit source preserves embedded artwork during cache-only database refreshes, restores per-track display-cache
sidecars on launch, performs the one-time embedded-artwork recovery scan, serializes background downloads one file at a
time, and caches local filtered tracks, artists, album artists, and albums by search/sort/surface. Track, track-metadata-
override, and artist-override changes invalidate the browse caches. The audit confirmed that explicit inventory scans,
metadata rereads, database replacement/upsert, recent/favorite derivation, and local navigation consume the intended
authoritative state without adding another automatic full Documents scan.

`Tools/RegressionChecks.sh` was corrected to track the current Beta 1.0.6 metadata and the display-snapshot-aware remote
catalog-check guard. Regression checks, `git diff --check`, Swift 6 syntax parsing, and `Tools/PreflightBuild.sh` simulator
and generic-device builds passed. The known AppIntents metadata-skip warning remained non-blocking.

The signed Release app was built from source commit `dad0390` with `CURRENT_PROJECT_VERSION=211`, passed strict deep
code-signature verification, and installed in place on SaiyanDenawa as version 1.0.6/build 211. The previous app data was
preserved, and the physical app was not launched by Codex. The signed build emitted only the known harmless AppIntents
metadata-skip warning.

Manual continuation: launch build 211 on SaiyanDenawa. Verify cached local Library presentation and explicit scan behavior;
confirm artwork survives relaunch and cache refresh; exercise local artist/album/song/favorites/recent views; test FLAC
and MP3 metadata/artwork saves and unsupported-format handling; inspect mixed-artist browse grouping; and confirm local
and remote playback, Streaming responsiveness, downloads, navigation, and themes remain unchanged. Do not uninstall first.

## Streaming browse projection prewarm — working tree, 2026-07-30

Research of the remaining Streaming transition delay found that build 214 prepared artists, album artists, and albums
before showing the selected browse mode. The page also had a race where its snapshot task could synchronously rebuild a
projection on the main actor before the background prewarm completed. The current patch prepares only the selected
projection, coalesces already-cached requests, and makes the Streaming snapshot task await that same utility-priority
preparation. A credential-free `remote.browse.prewarm` diagnostic records duration, track count, and projection name.

Validation passed the 10-test performance-skill suite, `Tools/RegressionChecks.sh`, `git diff --check`, and
`Tools/PreflightBuild.sh` for simulator and generic-device Swift 6 strict builds. XcodeBuildMCP built, installed, and
launched the configured iPhone 17 Pro simulator; Streaming Artists rendered with alphabet sections, the browse-options
sheet opened, and Albums rendered with Various Artists grouping. The simulator app was stopped afterward. The physical
device was not installed or launched, so the warm 8,071-track device latency improvement remains pending manual Release
profiling.

## Physical installation — Streaming projection patch, build 215 — 2026-07-30

The current working tree was signed as arm64 Release version 1.0.6/build 215 with development team `98CWMFS26R`.
Deep strict code-signature verification passed, and `xcrun devicectl device install app` installed it in place on
`SaiyanDenwa` without uninstalling the existing app. `devicectl device info apps` verified
`com.example.ResonancePrototype` version 1.0.6/build 215. The physical app was not launched. The only build warning
was the known harmless AppIntents metadata-skip warning because the target has no AppIntents framework dependency.

Manual continuation: launch build 215 on `SaiyanDenwa` and compare warm Streaming first-frame latency with the cached
8,071-track catalog during playback and multi-track downloads. Verify artist/album ordering, alphabet navigation,
download progress, playback, tab switching, and relaunch persistence. Do not uninstall first.

## Streaming activation regression repair — build 216 — 2026-07-30

Device diagnostics from build 215 showed no local library scan during Streaming activation, but the remote browse
projection was rebuilt twice on each Streaming presentation for the cached 8,071-track catalog, taking approximately
1.1–1.8 seconds per build. The regression came from the startup optimization that conditionally constructed only the
active root NavigationStack; switching away from and back to Streaming destroyed and recreated the Streaming view,
restarting its activation tasks. The browse-prewarm path also lacked in-flight task coalescing.

The repair keeps Library-only startup construction, creates Streaming lazily on first use, then retains it across root
tab switches. Remote browse prewarm requests for the same catalog revision/projection now share one utility-priority
task. Audio, local-library scanning, catalog refresh behavior, and download behavior were not changed.

Validation passed `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build with
development team `98CWMFS26R` passed strict deep code-signature verification and installed in place on `SaiyanDenwa`;
`devicectl` verified `com.example.ResonancePrototype` version 1.0.6/build 216. The physical app was not launched.
The known no-scheme destination and AppIntents metadata-skip warnings remained non-blocking.

Manual continuation: launch build 216 on `SaiyanDenwa`, open Streaming, wait for the first catalog display, switch to
Library and back to Streaming repeatedly, and confirm it does not show local-library indexing or rebuild the catalog
on each return. Confirm Streaming remains responsive during playback and downloads, then test artist/album grouping,
alphabet navigation, selection/download actions, and relaunch persistence. Do not uninstall first.

## Cache-first launch repair — build 217 — 2026-07-30

The local startup path now publishes the lightweight persisted display snapshot first, before waiting on SQLite or
artwork hydration. Cached tracks therefore become visible immediately; SQLite metadata and artwork are reconciled
afterward in the background. A full Documents scan is reserved for a genuinely empty persisted library. Remote
catalog activation and browse projection prewarm run concurrently with local bootstrap instead of waiting for local
startup to finish.

Validation passed `Tools/RegressionChecks.sh`, `git diff --check`, and `Tools/PreflightBuild.sh` with Swift 6 strict
concurrency and warnings treated as errors for simulator and generic device. A signed arm64 Release build with
development team `98CWMFS26R` passed strict deep code-signature verification and installed in place on `SaiyanDenwa`;
`devicectl` verified `com.example.ResonancePrototype` version 1.0.6/build 217. The physical app was not launched.
The known no-scheme destination and AppIntents metadata-skip warnings remained non-blocking.

Manual continuation: launch build 217 on `SaiyanDenwa` and verify a cached Library appears without a prolonged
“Indexing music…” state. Open Streaming for the first time after launch and verify cached remote content appears
without a prolonged “Preparing Streaming…” state. Repeat after relaunch, then verify artwork hydration, playback,
alphabet navigation, downloads, and tab switching. Do not uninstall first.

## Local cache presentation repair — build 218 — 2026-07-30

Device relaunch diagnostics showed a valid persisted local display snapshot and zero `library.scan.begin` or
`library.scan.end` events across repeated launches. The recurring “Indexing music…” text was therefore a misleading
empty-state placeholder while cached bootstrap waited on SQLite, not evidence of a repeated full Documents scan.

Build 218 presents the display snapshot immediately, reconciles the SQLite index and artwork in the background, and
labels the remaining cache wait as “Loading cached library…”. “Indexing music…” is now reserved for an actual local
Documents scan. Regression checks, Swift 6 strict simulator/generic-device preflight, signed arm64 Release build,
and strict deep code-signature verification passed. The update installed in place on `SaiyanDenwa`; `devicectl`
verified `com.example.ResonancePrototype` version 1.0.6/build 218. The physical app was not launched.

Manual continuation: launch build 218 on `SaiyanDenwa`, close and reopen Resonance several times, and confirm the
cached Library appears without a prolonged “Indexing music…” state. Verify Streaming, playback, artwork hydration,
alphabet navigation, downloads, and tab switching remain responsive. Do not uninstall first.

## Background Streaming preparation — build 219 — 2026-07-30

The first Streaming presentation no longer waits on a view-owned activation and browse-prewarm cycle. Launch-time
remote activation and detached browse projection remain the background preparation path; Streaming now consumes only
completed browse snapshots and renders immediately while a missing projection is being prepared. This removes the
duplicate first-tab wait and avoids synchronous fallback grouping of the full remote catalog on the main actor.

Regression checks, Swift 6 strict simulator/generic-device preflight, signed arm64 Release compilation, and strict
deep code-signature verification passed. Build 219 installed in place on `SaiyanDenwa`; `devicectl` verified
`com.example.ResonancePrototype` version 1.0.6/build 219. The physical app was not launched.

Manual continuation: launch build 219, switch to Streaming immediately after launch, and confirm the tab changes
without locking up while the catalog warms. Repeat after relaunch, switch between Artists, Albums, and Library, and
verify scrolling, playback, downloads, and normal tab gestures remain responsive. Do not uninstall first.

## Theme-linked navigation and Settings icons — build 220 — 2026-07-30

Shared toolbar icon buttons and icon labels now use the same four persisted visual treatments as hero actions:
Soft Glass, Matte Crystal, Inner Glow, and Minimal Transparent. They use the active theme accent for their surface,
edge, glow, or underline while retaining contrast-aware navigation text. Changing Hero buttons in Settings therefore
updates the Library, Streaming, detail-screen, playlist, and Settings toolbar icons through the shared component.

Regression checks, Swift 6 strict simulator/generic-device preflight, signed arm64 Release compilation, and strict
deep code-signature verification passed. Build 220 installed in place on `SaiyanDenwa`; `devicectl` verified
`com.example.ResonancePrototype` version 1.0.6/build 220. The physical app was not launched.

Manual continuation: launch build 220 and switch Hero buttons among all four styles in Settings. Confirm the Library,
Streaming, artist, album, playlist, and Settings navigation icons update immediately and remain readable in Gallery
Light, Nocturne Glass, and material themes. Verify each icon still activates the correct action. Do not uninstall first.

## Unified library navigation — build 221 — 2026-07-30

Hierarchy navigation buttons now use the same persisted Hero Button treatments as the rest of the app: Soft Glass,
Matte Crystal, Inner Glow, and Minimal Transparent. The top-level Library/Streaming switch now occupies the centered
navigation slot used by the other module navigation controls: Library presents **Streaming →**, while Streaming presents
**← Local**. The existing options, playlist, refresh, download, scan, add, and Settings controls remain in their toolbar
groups.

Regression checks, Swift 6 strict simulator/generic-device preflight, signed arm64 Release compilation, and strict deep
code-signature verification passed. Build 221 installed in place on `SaiyanDenawa`; `devicectl` verified
`com.example.ResonancePrototype` version 1.0.6/build 221. The physical app was not launched.

Manual continuation: launch build 221 on `SaiyanDenawa`, switch Hero buttons among all four styles and several themes,
and verify the upward Album/Artist/Library hierarchy controls update consistently. Confirm Library shows **Streaming →**
and Streaming shows **← Local**, each opens the correct destination, and the remaining toolbar controls stay in their
expected locations. Do not uninstall first.

## Streaming download toolbar and centered navigation — simulator build 222 — 2026-07-30

The top-level Library navigation uses compact inline toolbar placement so the Local Library’s **Streaming →** control is
centered beneath the camera area. Streaming now puts its browse, grouping, sort, and view options behind a themed left
toolbar settings button. Its right toolbar keeps refresh and Settings in the first row, with a labeled **Download** button
below. With no selection, Download asks whether to download the entire remote library or switch to individual artist
selection; selected artists or albums download directly.

Regression checks and the configured iPhone 17 Pro simulator build passed. The updated app was installed in place on the
simulator through XcodeBuildMCP. The simulator and physical phone were not launched or changed beyond installation.

Manual continuation: launch the installed simulator app, verify the centered **Streaming →** control, open Streaming
options from the left settings icon, and confirm the right-side Download button is below the refresh/Settings row. Test
the no-selection prompt’s whole-library and individual-artist paths, then select artists and confirm Download queues the
selected content. Do not uninstall first.

## Standalone navigation buttons — simulator build 223 — 2026-07-30

Hierarchy navigation controls no longer render inside rounded Hero Button containers; the title and directional arrow now
stand alone while retaining themed contrast. The Streaming download control is explicitly widened to 112 points and
keeps its label on one line so **Download** remains fully visible.

Regression checks and the configured iPhone 17 Pro simulator build passed. The updated app was installed in place on the
simulator only; neither simulator nor physical phone was launched.

Manual continuation: launch the simulator app, inspect Library/Streaming and detail-level upward navigation in each Hero
Button style, and confirm the buttons have no surrounding containers. Verify the full Download label is visible and the
button still opens the whole-library or individual-artist choice when nothing is selected.

## Independent toolbar controls — simulator build 224 — 2026-07-30

The previous screenshot showed that the system’s shared liquid-glass toolbar background was grouping the left options
and right refresh/Settings/Download controls. Build 224 hides that shared background on the top-level Library and
Streaming toolbar groups, leaving each themed control visually independent. The hierarchy navigation labels retain their
standalone rounded treatment.

Regression checks and the configured iPhone 17 Pro simulator build passed. The updated app was installed in place on the
simulator only; the physical phone was not changed or launched.

Manual continuation: launch the simulator and confirm the left options controls, right refresh/Settings controls, and
Download button no longer sit inside a shared outer glass container. Confirm the navigation buttons retain their intended
rounded treatment and Download remains fully visible.

## Navigation border and toolbar spacing polish — simulator build 225 — 2026-07-30

Hierarchy navigation buttons now restore the Hero Button theme surface and border, including the matching Inner Glow and
Minimal Transparent treatments. The right Streaming toolbar is offset slightly downward, keeps visible spacing between
Settings and Download, and renders the full **Download** word beside its arrow icon.

Regression checks and the configured iPhone 17 Pro simulator build passed. The updated app was installed in place on the
simulator only; the physical phone was not changed.

Manual continuation: launch the simulator and verify the themed navigation borders, right-side vertical alignment, spacing
between Settings and Download, and the complete Download label in each supported theme.

## Themed Download control and final toolbar alignment — simulator build 226 — 2026-07-30

The Streaming Download button now uses the same Soft Glass, Matte Crystal, Inner Glow, and Minimal Transparent treatments
as the themed toolbar and navigation controls. The right-side toolbar stack is lowered slightly further while retaining
clear spacing between its Settings row and Download.

Regression checks, the configured iPhone 17 Pro simulator build, simulator installation, and a final simulator screenshot
passed. The physical phone was not changed.

Manual continuation: switch through the available themes and Hero Button styles, confirm Download follows each treatment,
and verify the right-side controls remain vertically aligned with comfortable Settings-to-Download spacing.

## Toolbar height matched to hierarchy navigation — simulator build 227 — 2026-07-30

The shared themed toolbar icon buttons now use the same 34-point control height as the hierarchy navigation buttons.
This aligns the right-side Settings/refresh controls with the centered Local/Streaming navigation control without changing
the Download spacing or themed text-button treatment.

Regression checks, simulator build/install, and a final simulator screenshot passed. The physical phone was not changed.

Manual continuation: inspect both Library and Streaming in the simulator and verify the right-side icon row has the same
vertical height and centerline as the hierarchy navigation button, with Download still separated below it.

## Streaming toolbar baseline alignment — simulator build 228 — 2026-07-30

The Streaming right-side toolbar stack now applies the same alignment baseline as the Library toolbar: its Settings and
refresh row is lowered to match the centered hierarchy navigation control, while the themed Download button remains in a
separate row below with its existing spacing.

Regression checks, simulator build/install, and a final screenshot in the Electronic theme passed. The physical phone was
not changed.

Manual continuation: compare Library and Streaming directly in several themes and confirm the right-side Settings/refresh
row shares the navigation button’s height and centerline, with Download below rather than in the first row.

## Centered Local-to-Streaming navigation — simulator build 230 — 2026-07-30

The Library toolbar now balances its leading slot to the trailing control width, eliminating the principal-toolbar offset
that placed **Streaming →** left of center. The hierarchy label is non-compressing, so the complete title remains visible
while centered under the camera area. Streaming’s **Local ←** layout remains centered as well.

Regression checks, simulator build/install, and a final screenshot confirmed the centered, fully visible control. The
physical phone was not changed.

Manual continuation: compare **Streaming →** in Library with **Local ←** in Streaming across the available themes and
confirm both are centered and fully readable.

## Local file browser moved to second toolbar row — simulator build 231 — 2026-07-30

The Local Library’s file-import control now appears in the second right-side toolbar row as a themed **Browse Files**
button with its folder icon. Scan and Settings remain in the first row, matching Streaming’s first-row controls and
second-row Download placement. The centered **Streaming →** navigation remains intact.

Regression checks, simulator build/install, and a final Local Library screenshot passed. The physical phone was not
changed.

Manual continuation: tap Browse Files to confirm the file importer opens, verify Scan and Settings remain in the first
row, and compare the Local and Streaming second-row controls across themes.

## Detail toolbar cleanup and All Tracks options — simulator build 232 — 2026-07-30

Local and Streaming artist/album detail toolbars now hide the system shared outer toolbar background, leaving their themed
controls independent like the root Library and Streaming toolbars. The local and remote All Tracks/All Albums track
modules now expose a left view-options button and a right Settings button, with the matching options sheet available from
each module.

Regression checks, simulator build, and in-place simulator installation passed. The physical phone was not changed.

## Direct Streaming playlist navigation and unified leading toolbar spacing — simulator build 234 — 2026-07-30

Streaming’s root playlist control now uses a direct `NavigationLink`, matching Local Library instead of opening an
intermediate context menu. Artist, album, and All Tracks modules now use the same leading options-to-playlists HStack
with 4-point spacing; Back remains separate, and All Tracks modules expose matching right-side Settings controls.

Regression checks, simulator build/install, and `git diff --check` passed. The physical phone was not changed.

Manual continuation: tap Playlists from Streaming and verify it opens the playlist page directly. Compare options and
playlist spacing across Library, Streaming, local/remote artist and album details, and both All Tracks modules.

Manual continuation: open local and Streaming artist and album details and confirm no outer glass container surrounds the
toolbar controls. Open each All Tracks module, verify the left options and right Settings controls, and confirm the
options sheets open normally.

## Artist and album toolbar icon theme completion — simulator build 235 — 2026-07-30

The remaining interactive pencil and add-to-playlist controls on local artist and album detail pages now use the shared
themed toolbar icon component. Their sizing, surface, border, tint, and contrast therefore follow the configured Hero
Button style alongside Settings and the other detail-page controls. The Playing toolbar changes from the preceding work
remain included, with a text-labeled Back control and themed Queue/playlist actions.

Regression checks, simulator build/install/launch, and a simulator screenshot passed. The physical phone was not changed.

Manual continuation: open local and Streaming artist and album details in each available Hero Button style. Confirm the
artist pencil, add-to-playlist, download, and Settings controls share the same themed treatment, then verify Now Playing
Back, playlist, and Queue controls remain readable and actionable.

## Remove redundant detail hierarchy bubbles — simulator build 236 — 2026-07-30

The centered hierarchy pills above the navigation controls were removed from the Playing and local/remote album detail
modules. Those screens retain their explicit left Back controls, so the redundant Artist/Album bubble no longer occupies
the top navigation area. Library, Streaming, artist detail, and other hierarchy navigation remain unchanged.

Regression checks, simulator build/install/launch, and a follow-up simulator screenshot passed. The physical phone was not
changed.

Manual continuation: open Playing and both local and Streaming album detail screens. Confirm there is no centered bubble
above the navigation controls, while Back, Settings, playlist, album options, playback, and track-list interactions still
work.

## Restore detail navigation and remove the camera-area header bubble — simulator build 237 — 2026-07-30

The previous cleanup removed the actual centered Artist/Album navigation controls along with the duplicate bubble. The
controls are restored in the Playing and local/remote album toolbars. The separate global layered-navigation header is
now suppressed only for the album and Playing layers, removing the bubble above and slightly behind the camera area while
preserving the in-toolbar navigation.

Regression checks, simulator build/install/launch, and a follow-up simulator screenshot passed. The physical phone was not
changed.

Manual continuation: open Playing and local/Streaming album detail. Confirm the centered Album/Artist navigation control
is present in the navigation bar, the extra bubble above the camera area is gone, and Back navigation still works.

## Remove remaining All Albums camera-area bubble — simulator build 238 — 2026-07-30

The global layered-navigation header is now also suppressed for the All Albums module. Its own in-module Artist
navigation remains available, while the duplicate bubble above and behind the camera area is removed consistently with
Playing and album detail.

Regression checks, simulator build, and in-place simulator installation passed. The physical phone was not changed.

Manual continuation: open All Albums from a local and Streaming artist, confirm the in-module Artist navigation remains,
and verify the extra camera-area bubble is absent.

## Match playlist toolbar icon height universally — simulator build 239 — 2026-07-30

The shared `ResonanceToolbarIconLabel` used by playlist NavigationLinks and menus now uses the same 34-point height as
`ResonanceToolbarIconButton`. Playlist icons therefore match Settings and other themed toolbar controls across the
Library, Streaming, artist, album, All Tracks, and related modules without screen-specific sizing overrides.

Regression checks, simulator build, and in-place simulator installation passed. The physical phone was not changed.

Manual continuation: compare playlist and Settings controls in each module and across all Hero Button styles; verify
playlist navigation and menus remain tappable and visually aligned.

## Match Streaming leading toolbar spacing — simulator build 240 — 2026-07-30

The Streaming root playlist NavigationLink now uses the same plain button style as the corresponding Library, artist,
album, and All Tracks links. This removes the platform NavigationLink padding that made the Streaming playlist icon sit
farther from the library-options icon.

Regression checks, simulator build, and in-place simulator installation passed. The physical phone was not changed.

Manual continuation: compare the options-to-playlist spacing on Library, Streaming, artist, album, and All Tracks modules
and verify the playlist link still opens normally.

## Settings module theme overhaul — simulator build 241 — 2026-07-30

Settings now follows the shared module chrome: its leading control is the themed text-labeled **Back** button, its
centered title uses the themed Settings hierarchy treatment, and the legacy extra top padding was removed. Settings
category cards now use Hero Button style-aware surfaces and borders with compact typography rather than the oversized
legacy headers. Settings action buttons inherit a shared themed card treatment, including QR setup and Test Connection,
while explicit destructive actions retain their destructive styling.

All settings behavior and persisted category expansion remain unchanged. Regression checks, simulator build/install/launch,
and a simulator screenshot passed. The physical phone was not changed.

Manual continuation: open Settings and compare it with Library and Streaming in every Hero Button style. Verify the themed
Back/title chrome, compact category cards, Appearance controls, QR scanner, Test Connection, diagnostics actions, keyboard
dismissal, persisted expansion, and scrolling above the tab bar.

## Album and All Albums action standardization — simulator build 242 — 2026-07-30

Album and All Albums toolbars now use the shared themed Back control and consistent playlist-link geometry. Their Play All
actions use the shared Hero action treatment instead of system-bordered buttons. Local track swipe actions now expose
theme-colored Play Next, Add to Queue, Edit Metadata, and Add to Playlist controls. Streaming album and All Albums track
swipes expose theme-colored Play Next, Add to Queue, Download, and server-playlist actions where supported.

Fixed indigo, teal, blue, and green swipe tints were removed in favor of the active Resonance accent, so the action
surfaces follow the selected theme consistently. Regression checks, simulator build/install/launch, and a simulator
screenshot passed. The physical phone was not changed.

Manual continuation: open local and Streaming albums and All Albums. Swipe tracks from both sides and verify the action
labels, icons, spacing, and active-theme color; test Play Next, Add to Queue, Download, Edit Metadata, and Add to Playlist.

## Revert experimental themed swipe actions — 2026-07-30

The experimental custom swipe surface was reverted after simulator review showed the action cards could appear behind or
over the track text. Album and All Albums rows are back on the stable native `.swipeActions` implementation. The shared
toolbar, Hero Button, navigation, Settings, and Play All theme standardization remains in place.

`Tools/RegressionChecks.sh`, `git diff --check`, Swift 6 strict preflight, signed arm64 Release compilation, and strict
code-signature verification passed. The simulator build was installed and launched. The physical phone install is
pending completion of its iOS update; Codex did not launch the phone app.

Manual continuation: after the phone reconnects, install this build in place and verify album/all-albums native swipe
actions, toolbar consistency, navigation, Settings, playback, and library preservation.

## Restore centered hierarchy navigation and direct Browse/Download actions — simulator build 247 — 2026-07-30

Source commit `1c52501` restores the established Library and Streaming toolbar arrangement: leading options and
playlist controls, centered direct Library ↔ Streaming hierarchy navigation, and stacked trailing refresh/settings
controls with Browse Files or Download. Browse Files and Download use the existing direct `ResonanceToolbarTextButton`
actions. Regression checks and `git diff --check` passed. A strict Debug simulator build version `1.0.7/build 247`
passed and was installed in place on the configured iPhone 17 Pro simulator. The simulator was not launched or
screenshot-captured by Codex; the physical phone was not changed or launched.

Manual continuation: launch build 247 manually and capture a screenshot. Verify the centered hierarchy buttons,
leading options/playlist controls, Browse Files importer, Download flow, and unchanged navigation behavior.

## Restore Streaming root toolbar isolation — simulator build 233 — 2026-07-30

The Streaming root toolbar’s shared-background suppression was restored after the detail-toolbar update accidentally
dropped that modifier. The existing root icon, Download, spacing, and alignment layout was otherwise left unchanged.

Regression checks, simulator build, and in-place simulator installation passed. The physical phone was not changed.
