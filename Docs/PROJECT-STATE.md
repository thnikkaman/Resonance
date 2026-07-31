# Resonance verified project state

Last verified: 2026-07-30

## Source identity

- Repository: `thnikkaman/Resonance`
- Branch: `agent/alpha-3.7.4-source`
- Checkout: `/Users/brian/Resonance/Resonance-Alpha-3.7.4`
- Implementation baseline commit: `3cc3d35` (`Document restored navigation toolbar state`)
- Documentation commits may sit on top; use `Tools/ProjectStateCheck.sh` for the exact current checkout commit.
- Remote branch: `origin/agent/alpha-3.7.4-source`; it is pushed from this checkout.
- Tracked tree: intentional regression-contract/documentation changes only; pre-existing untracked build outputs, logs, diagnostics, and simulator artifacts are not release files.
- Project default settings: version `1.0.6`, build `210`, Swift language mode `5.0`.

The implementation baseline contains ten intentional commits through the toolbar
restoration. The latest app-code change is `1c52501`; commits after it are
continuity/documentation records. Use `Tools/ProjectStateCheck.sh` and `git log` for
the exact current checkout and remote-synchronization evidence.
Do not infer that the project default build changed merely because an override artifact
has a newer version/build.

## Verified simulator artifact

- Simulator: iPhone 17 Pro, UDID `75BAB492-8B4C-4496-889C-020C7E746243`
- Bundle: `com.example.ResonancePrototype`
- Installed version: `1.0.7`
- Installed build: `249`
- Artifact build command used `MARKETING_VERSION=1.0.7 CURRENT_PROJECT_VERSION=249`.
- The artifact is built from the restored toolbar source at commit `1c52501`; the
  checkout adds only regression-contract/documentation changes on top.
- Installation was verified with `xcrun simctl listapps` and bundle `Info.plist` inspection.
- The simulator app was not launched or screenshot-captured by Codex in this verification.

This distinction is intentional:

```text
canonical checkout defaults  ->  1.0.6 / 210
installed simulator artifact ->  1.0.7 / 247
```

## Physical device state

- Physical target: `SaiyanDenawa`.
- The device remains on `1.0.6/244`; build `1.0.7/250` was built from the current checkout,
  locally signed, and rejected during in-place installation because its reused development
  provisioning profile had expired. No physical-device files were changed and the app was not launched.
- Do not claim audible playback, 5.1 routing, background suspension, thermal behavior,
  or physical-device acceptance from simulator evidence.

## Current continuation point

The next manual simulator check is to launch the already-installed `1.0.7/249` artifact
and verify the restored Library/Streaming toolbar arrangement:

- centered Library ↔ Streaming hierarchy buttons;
- leading view-options and playlist controls;
- stacked refresh/settings controls;
- `Browse Files` opens the existing importer;
- `Download` opens the existing remote download flow;
- no unrelated navigation or toolbar behavior changed.

Codex must not launch the simulator or capture the screenshot unless explicitly asked.

## Build 250 signing blocker

- Regression checks, strict simulator/device preflight, and unsigned Release compilation passed.
- The normal signed build failed because the Apple developer account could not refresh the
  missing profile; local signing with the last cached profile verified successfully but device
  installation rejected that profile as expired at `2026-07-31T04:40:01Z`.
- Retry the signed build/install after the Apple developer account is available. Do not launch
  the physical app automatically.

## Simulator build 250

- Debug build `1.0.7/250` was built from the current checkout and installed/launched in place on
  iPhone 17 Pro simulator `75BAB492-8B4C-4496-889C-020C7E746243`.
- Screenshot evidence: `sim-toolbar-test-250.png` shows centered Library/Streaming navigation,
  intact leading controls, and the separate Browse Files button. Runtime button activation remains
  a manual tap check; the simulator command-line tools do not inject touch events.

The rejected `1.0.7/248` simulator artifact used separate trailing toolbar items and
visibly changed the layout; it was replaced in place by `1.0.7/249`. No custom hit
region was retained.

## Physical build 256

- Signed Release build `1.0.7/256` used team `98CWMFS26R`, Apple Development signing,
  and the refreshed automatic provisioning profile.
- Codesign verification and in-place installation on SaiyanDenawa passed. `devicectl`
  verified bundle `com.example.ResonancePrototype`, version `1.0.7`, build `256`.
- The physical app was not launched. Manual acceptance remains: verify Browse Files and
  Download activation, centered navigation, unchanged right-side controls, and preserved app data.

## Evidence commands

```sh
Tools/ProjectStateCheck.sh --source-only
Tools/ProjectStateCheck.sh --simulator 75BAB492-8B4C-4496-889C-020C7E746243
Tools/RegressionChecks.sh
Tools/PreflightBuild.sh
```

Update this file only after checking the actual checkout, build artifact, and device or
simulator state. Historical feature notes belong in `README.md` and the authoritative
handoff, not in this short state record.
