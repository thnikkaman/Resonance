# Resonance verified project state

Last verified: 2026-07-31

## Source identity

- Repository: `thnikkaman/Resonance`
- Branch: `agent/alpha-3.7.4-source`
- Checkout: `/Users/brian/Resonance/Resonance-Alpha-3.7.4`
- Release commit: `Resonance-Beta-v1.0.8` tagged publication commit.
- GitHub tag/release: `Resonance-Beta-v1.0.8` prerelease publication.
- GitHub PR: not applicable; the development branch has no common history with the ZIP-history `main` branch.
- Project defaults: version `1.0.8`, build `260`, Swift language mode `5.0`.
- Untracked build outputs, logs, diagnostics, and screenshots are not release files and remain outside Git.

## Current beta artifact

- Product: Resonance Beta v1.0.8/build 260.
- Bundle: `com.example.ResonancePrototype`.
- Signed arm64 Release build passed with development team `98CWMFS26R`.
- Deep strict code-signature verification passed.
- In-place installation on `SaiyanDenawa` passed; existing app data was preserved.
- `devicectl` verified version `1.0.8`, build `260`.
- Codex did not launch the physical app; playback, keyboard behavior, and other physical runtime acceptance remain user-run checks.

## Implemented change

Beta v1.0.8 stages metadata-editor artwork selections until Save, exposes both Artist and Album Artist in track,
album, and artist metadata forms, places read-only album/artist information below artwork pickers, and adds keyboard
dismissal to the online artwork search. Automatic artwork recommendations during library ingestion remain unchanged.

## Validation

- `git diff --check` passed.
- `Tools/RegressionChecks.sh` passed for project default `1.0.8/260`.
- `Tools/PreflightBuild.sh` passed simulator and generic-device strict compilation.
- Signed Release build, code-signature verification, in-place install, and device bundle inspection passed.
- Known non-blocking warning: AppIntents metadata extraction is skipped because the target has no AppIntents framework dependency.

## Beta v1.0.8 release scope

- Artwork selected inside a metadata editor remains staged until that editor’s Save; Cancel discards it.
- Automatic artwork recommendations during local ingestion and remote catalog acquisition remain unchanged.
- Track, album, and artist editors expose both Artist and Album Artist and write the fields to the affected files.
- Read-only track names, counts, and reset/status information follow the artwork picker.
- Online artwork search supports Done, outside-tap, submit, and scroll keyboard dismissal.
- Final signed Release build and in-place install verified `1.0.8`/`260` on `SaiyanDenawa`; the app was not launched.

## Manual continuation

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
