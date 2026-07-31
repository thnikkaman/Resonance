# Resonance verified project state

Last verified: 2026-07-30

## Source identity

- Repository: `thnikkaman/Resonance`
- Branch: `agent/alpha-3.7.4-source`
- Checkout: `/Users/brian/Resonance/Resonance-Alpha-3.7.4`
- Implementation baseline commit: `3cc3d35` (`Document restored navigation toolbar state`)
- Documentation commits may sit on top; use `Tools/ProjectStateCheck.sh` for the exact current checkout commit.
- Remote branch: `origin/agent/alpha-3.7.4-source`; it is pushed from this checkout.
- Tracked tree: clean; pre-existing untracked build outputs, logs, diagnostics, and simulator artifacts are not release files.
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
- Installed build: `247`
- Artifact build command used `MARKETING_VERSION=1.0.7 CURRENT_PROJECT_VERSION=247`.
- The handoff identifies the toolbar artifact source as commit `1c52501`; the checkout
  now adds continuity/documentation commits on top.
- Installation was verified with `xcrun simctl listapps` and bundle `Info.plist` inspection.
- The simulator app was not launched or screenshot-captured by Codex in this verification.

This distinction is intentional:

```text
canonical checkout defaults  ->  1.0.6 / 210
installed simulator artifact ->  1.0.7 / 247
```

## Physical device state

- Physical target: `SaiyanDenawa`.
- No physical-device install or launch was performed for the build-247 simulator verification.
- Do not claim audible playback, 5.1 routing, background suspension, thermal behavior,
  or physical-device acceptance from simulator evidence.

## Current continuation point

The next manual simulator check is to launch the already-installed `1.0.7/247` artifact
and verify the restored Library/Streaming toolbar arrangement:

- centered Library ↔ Streaming hierarchy buttons;
- leading view-options and playlist controls;
- stacked refresh/settings controls;
- `Browse Files` opens the existing importer;
- `Download` opens the existing remote download flow;
- no unrelated navigation or toolbar behavior changed.

Codex must not launch the simulator or capture the screenshot unless explicitly asked.

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
