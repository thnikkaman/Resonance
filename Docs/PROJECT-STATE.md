# Resonance verified project state

Last verified: 2026-07-31

## Source identity

- Repository: `thnikkaman/Resonance`
- Branch: `agent/alpha-3.7.4-source`
- Checkout: `/Users/brian/Resonance/Resonance-Alpha-3.7.4`
- Release commit: `3d455a0` (`Prepare Resonance Beta v1.0.9`).
- GitHub tag/release: `Resonance-Beta-v1.0.9` prerelease publication.
- GitHub PR: not applicable; the development branch has no common history with the ZIP-history `main` branch.
- Project defaults: version `1.0.9`, build `261`, Swift language mode `5.0`.
- Untracked build outputs, logs, diagnostics, and screenshots are not release files and remain outside Git.

## Current beta source and installed artifact

- Source product: Resonance Beta v1.0.9/build 261.
- Bundle: `com.example.ResonancePrototype`.
- Signed arm64 Release build passed with development team `98CWMFS26R`.
- Deep strict code-signature verification passed.
- In-place installation on `SaiyanDenawa` passed; existing app data was preserved.
- The installed physical artifact remains version `1.0.8`, build `260`; Beta v1.0.9 was not installed during this GitHub publication task.
- Codex did not launch the physical app; playback, keyboard behavior, and other physical runtime acceptance remain user-run checks.

The v1.0.9 source was published at https://github.com/thnikkaman/Resonance/releases/tag/Resonance-Beta-v1.0.9. A signed
physical-device build/install remains a separate explicit step.

## Implemented change

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
