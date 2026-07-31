# Resonance verified project state

Last verified: 2026-07-30

## Source identity

- Repository: `thnikkaman/Resonance`
- Branch: `agent/alpha-3.7.4-source`
- Checkout: `/Users/brian/Resonance/Resonance-Alpha-3.7.4`
- Release commit: `6aa68ae` (`Release Resonance Beta v1.0.7 build 259`)
- GitHub tag/release: `Resonance-Beta-v1.0.7` (prerelease published).
- GitHub PR: not applicable; the development branch has no common history with the ZIP-history `main` branch.
- Project defaults: version `1.0.7`, build `259`, Swift language mode `5.0`.
- Untracked build outputs, logs, diagnostics, and screenshots are not release files and remain outside Git.

## Current beta artifact

- Product: Resonance Beta v1.0.7/build 259.
- Bundle: `com.example.ResonancePrototype`.
- Signed arm64 Release build passed with development team `98CWMFS26R`.
- Deep strict code-signature verification passed.
- In-place installation on `SaiyanDenawa` passed; existing app data was preserved.
- `devicectl` verified version `1.0.7`, build `259`.
- Codex did not launch the physical app; playback, keyboard behavior, and other physical runtime acceptance remain user-run checks.

## Implemented change

Settings appearance now uses centered custom option popovers for the Hero Buttons and Backend categories. The RGB
hex-channel slider still changes values, but no longer calls the text-field editing callback. Only touching the actual
red, green, or blue hex field requests first responder and opens the keyboard. The layout and slider math are unchanged.

## Validation

- `git diff --check` passed.
- `Tools/RegressionChecks.sh` passed for project default `1.0.7/259`.
- `Tools/PreflightBuild.sh` passed simulator and generic-device strict compilation.
- Signed Release build, code-signature verification, in-place install, and device bundle inspection passed.
- Known non-blocking warning: AppIntents metadata extraction is skipped because the target has no AppIntents framework dependency.

## Manual continuation

On `SaiyanDenawa`, launch Beta v1.0.7 manually and verify:

- tapping each actual hex value opens the keyboard;
- tapping or dragging each RGB slider changes its value without opening the keyboard;
- Hero Buttons and Backend option lists are centered;
- Browse Files, Download, centered navigation, playback, and existing data remain intact.

Do not uninstall first. Codex must not launch the physical app automatically.

## Evidence commands

```sh
Tools/ProjectStateCheck.sh --source-only
Tools/RegressionChecks.sh
Tools/PreflightBuild.sh
xcrun devicectl device info apps --device 00008150-001144383612401C --bundle-id com.example.ResonancePrototype
```
