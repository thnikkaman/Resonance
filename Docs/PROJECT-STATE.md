# Resonance verified project state

Last verified: 2026-08-01

## Source identity

- Repository: `thnikkaman/Resonance`
- Branch: `agent/alpha-3.7.4-source`
- Checkout: `/Users/brian/Resonance/Resonance-Alpha-3.7.4`
- Release commit: pending local commit for the Brushed Metal artwork replacement.
- GitHub tag/release: `Resonance-Beta-v2.0-build268` public prerelease publication.
- GitHub PR: not applicable; the development branch has no common history with the ZIP-history `main` branch.
- Project defaults: version `2.0`, build `268`, Swift language mode `5.0`.
- Untracked build outputs, logs, diagnostics, and screenshots are not release files and remain outside Git.

## Current beta source and installed artifact

- Source product: Resonance Beta v2.0/build 268.
- Bundle: `com.example.ResonancePrototype`.
- Signed arm64 Release build passed with development team `98CWMFS26R`.
- Deep strict code-signature verification passed.
- The prior build-267 artifact was installed in place on `SaiyanDenawa`; build 268 was installed in place on Sarah’s and Chase’s iPhones.
- Sarah’s and Chase’s physical artifacts are version `2.0`, build `268`; both were installed in place after signed verification.
- A Debug `2.0`/`268` build was installed on the configured iPhone 17 Pro simulator for visual inspection.
- Codex did not launch the physical apps; playback, keyboard behavior, and other physical runtime acceptance remain user-run checks.

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
