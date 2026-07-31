# Resonance work queue

This is the lightweight execution record for the current phase. Each item names its owner, evidence, acceptance
oracle, and rollback point. Generated logs, diagnostics, screenshots, and build outputs remain outside Git.

## Active baseline

- Runtime baseline: signed Beta v1.0.7/build 259 installed in place on `SaiyanDenawa`.
- Source baseline: commit `6aa68ae` on `agent/alpha-3.7.4-source`.
- Physical device: installed but not launched by Codex; user runtime acceptance remains pending.
- Full state record: `Docs/PROJECT-STATE.md`.

## Completed release work

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
- Source: commit `6aa68ae`, tag/release metadata to be recorded after GitHub publication.
- Validation: `Tools/RegressionChecks.sh`, `Tools/PreflightBuild.sh`, signed Release build, deep signature verification, and `devicectl` install/info passed.
- Rollback: reinstall the preceding signed build without uninstalling.

## Ongoing safeguards

- R-PERF: profile before any new performance change; require a named reproduced workload and before/after evidence.
- R-DEVICE: physical playback, explicit 5.1 routing, background suspension, thermal, and long-idle acceptance require a user-launched device test.

## Definition of done

An implementation item is complete only when its source revision, artifact identity, owning module, preserved invariants,
automated gates, and manual acceptance status are documented. Credentials, private data, and generated outputs stay outside commits.
