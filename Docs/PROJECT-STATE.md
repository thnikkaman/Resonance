# Resonance verified project state

Last verified: 2026-07-31

## Source identity

- Repository: `thnikkaman/Resonance`
- Branch: `agent/alpha-3.7.4-source`
- Checkout: `/Users/brian/Resonance/Resonance-Alpha-3.7.4`
- Release commit: `088c291` (`Prepare Resonance Beta v2.0`).
- GitHub tag/release: `Resonance-Beta-v2.0` prerelease publication.
- GitHub PR: not applicable; the development branch has no common history with the ZIP-history `main` branch.
- Project defaults: version `2.0`, build `267`, Swift language mode `5.0`.
- Untracked build outputs, logs, diagnostics, and screenshots are not release files and remain outside Git.

## Current beta source and installed artifact

- Source product: Resonance Beta v2.0/build 267.
- Bundle: `com.example.ResonancePrototype`.
- Signed arm64 Release build passed with development team `98CWMFS26R`.
- Deep strict code-signature verification passed.
- In-place installation on `SaiyanDenawa` passed; existing app data was preserved.
- The installed physical artifact is version `2.0`, build `267`; it was installed in place after signed verification.
- Codex did not launch the physical app; playback, keyboard behavior, and other physical runtime acceptance remain user-run checks.

The v2.0 source is published at https://github.com/thnikkaman/Resonance/releases/tag/Resonance-Beta-v2.0.

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
