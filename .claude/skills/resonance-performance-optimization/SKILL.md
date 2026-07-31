---
name: resonance-performance-optimization
description: >-
  Repository-specific build engineering for thnikkaman/Resonance on
  agent/alpha-3.7.4-source. Use for future builds, bug fixes, features,
  performance optimization, SwiftUI responsiveness, startup and cache work,
  local library and metadata changes, Navidrome/OpenSubsonic streaming,
  downloads, artwork, AVPlayer/AVAudioEngine playback, version/build updates,
  Xcode validation, diagnostics, release evidence, GitHub review, or publishing.
  Resolve the exact ref and commit, audit continuation contracts, map changed
  files to risk and required acceptance, preserve branch-specific behavior,
  run Swift 6 and runtime gates, and make only evidence-backed claims.
---

# Resonance Build Engineer

Treat this skill as the build control plane for the Resonance continuation branch. Preserve working behavior first; make each build narrow, attributable, reversible, and truthfully validated.

## Default target

Unless the user supplies another checkout, target:

- repository: `thnikkaman/Resonance`
- ref: `agent/alpha-3.7.4-source`
- project/target/scheme: `Resonance.xcodeproj`, `Resonance`, `Resonance`
- minimum repository gate: Swift 6 parse plus plist/project validation
- strict compile gate: Swift 6 complete concurrency with warnings as errors
- simulator default: `iPhone 17 Pro` from `.xcodebuildmcp/config.yaml`

Always re-resolve the current ref. The bundled snapshot is an orientation baseline, not permission to assume the branch has not advanced.

## Resolve GitHub context first

Use the GitHub connector before relying on memory or `main`:

1. Resolve the repository and explicit ref.
2. Resolve the exact head commit. A slash-named branch may not appear in branch search; fetch a known file with the explicit ref or compare the ref with itself to obtain the commit.
3. Fetch `README.md`, `Tools/RegressionChecks.sh`, `Tools/PreflightBuild.sh`, `.xcodebuildmcp/config.yaml`, `Resonance.xcodeproj/project.pbxproj`, and every source file in the proposed patch.
4. Do not compare against `main` until a common ancestor is proven. This branch has previously reported no common ancestor with `main`.
5. Use connector data for repository/PR/issue context and local `git` for checkout state, diffs, builds, tests, commits, and pushes.

Read [github-workflow.md](references/github-workflow.md) for the connector/local workflow.

## Start every nontrivial build with an audit

From the skill directory:

```bash
python3 scripts/resonance_build_workbench.py audit <repo-path>
python3 scripts/resonance_build_workbench.py audit <repo-path> --strict
```

The audit checks:

- required repository files
- exact project marketing/build values in both target configurations
- README stable, release-source, and latest-device-build provenance
- `RegressionChecks.sh` version/build assertions and success label
- `Info.plist` inheritance from project settings
- XcodeBuildMCP defaults and strict preflight tokens
- Swift source target membership
- current startup/browse contracts that exist in source but lack regression protection
- suggested next build as one greater than every known project/README build

Do not hide an audit warning. Resolve it, explicitly carry it as known debt, or mark the build blocked.

The verified orientation snapshot and current known drift are in [current-repository-contract.md](references/current-repository-contract.md).

## Map the proposed patch before editing

Run:

```bash
python3 scripts/resonance_build_workbench.py scope <repo-path>
python3 scripts/resonance_build_workbench.py scope <repo-path> \
  Resonance/Services/PlayerController.swift \
  Resonance/Views/PlayerViews.swift
```

The scope report maps files to subsystem risk, guardrails, simulator checks, physical-device requirements, remote fixture/credential needs, and destructive-library permissions.

For multi-step work, create the evidence workspace before implementation:

```bash
python3 scripts/resonance_build_workbench.py init evidence/build-<n> \
  --repo <repo-path> \
  --repository thnikkaman/Resonance \
  --ref agent/alpha-3.7.4-source \
  --commit <sha> \
  --intent '<one primary user-visible intent>' \
  --files <changed-file> [<changed-file> ...]
```

The tool infers the next safe build number from project and README provenance. Override `--version` or `--build` only after reviewing the audit.

## Classify the task

### Repair or feature build

1. Reproduce the current behavior.
2. State one primary intent and explicit non-goals.
3. Define the behavior contract before code.
4. Add or strengthen the smallest durable regression assertion.
5. Implement the narrow patch.
6. Run the scope-specific acceptance matrix and global gates.
7. Record what passed, failed, was blocked, and was not run.

### Performance build

Use the mandatory evidence loop:

```text
RESOLVE -> BASELINE -> PROFILE -> RANK -> PROVE -> IMPLEMENT -> VERIFY -> RE-PROFILE
```

Never optimize from source inspection alone. Use equivalent workloads and retain the existing statistical diagnostics workflow. Read [methodology.md](references/methodology.md), [profiling-playbook.md](references/profiling-playbook.md), [optimization-techniques.md](references/optimization-techniques.md), and [workload-catalog.md](references/workload-catalog.md).

### Build or compile failure

1. Run the lightest failing gate exactly.
2. Capture the first real error, not the cascade.
3. Classify project membership, Swift 6/concurrency, SDK/API, shell wrapper, signing, or environment.
4. Fix the smallest cause without weakening warnings, concurrency, or source assertions.
5. Re-run the failed gate and every earlier gate.
6. Do not describe a generic-device compile as a signed device build.

### Release or publication

1. Re-run the strict audit.
2. Use `version-plan` before changing version/build metadata.
3. Run all required gates and runtime acceptance.
4. Read version/build from the produced app bundle.
5. Verify signing and archive integrity when applicable.
6. Record compile, sign, install, and launch as separate facts.
7. Update README provenance with only actions actually completed.
8. Commit/push/open a PR only when the user explicitly requests publication.

## One primary intent per build

A build may touch several files, but it must have one causal purpose. Do not mix:

- feature work with unrelated cleanup
- performance work with redesign
- playback changes with catalog refactors
- version bumps with speculative code changes
- test weakening with implementation

Split unrelated work into another build. This preserves rollback, diagnostic attribution, and user acceptance.

## Branch-specific continuation contracts

Protect these unless the user explicitly changes product behavior:

- cache-first local and remote startup
- explicit refresh instead of automatic destructive rescans/checks
- display-cache hydration and file/cache I/O off the main actor
- first Streaming browse prewarm off-main with revision/sort stale-result rejection
- stable track/artist/album/section IDs and deterministic ordering
- targeted metadata/download refresh instead of full-library scan
- Remove from Library versus Delete from iPhone semantics
- high-frequency progress/meter isolation from broad view invalidation
- remote seek request ordering and exact-end clamping
- stable remote fallback and explicit local Matrix Mixer quarantine/fallback
- bounded, size-specific artwork caches and off-main decoding
- bounded download progress publication, cancellation cleanup, and background restoration
- privacy-safe diagnostics and error reporting
- custom tab/navigation/mini-player gesture, safe-area, hit-testing, and accessibility behavior

Read [repository-map.md](references/repository-map.md) and [change-impact-matrix.md](references/change-impact-matrix.md) before changing a high-risk subsystem.

## RegressionChecks.sh is a continuation contract

Do not remove an assertion merely because the implementation changed. Determine whether it protects required behavior.

When a new build introduces a durable contract:

- add a semantic assertion for the intended invariant
- avoid asserting incidental whitespace or an entire implementation body
- add a small deterministic fixture for ordering/mapping logic when possible
- update project version/build assertions together with actual project settings
- keep the versioned success label accurate
- keep new Swift files in the target Sources phase

Static assertions are a fast tripwire, not runtime proof.

## Version and build discipline

Run:

```bash
python3 scripts/resonance_build_workbench.py version-plan <repo-path> \
  --version <marketing-version> --build <build-number>
```

Rules:

- keep both Debug and Release target values identical
- keep `Info.plist` dynamic through `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)`
- keep Settings build display dynamic through `Bundle`
- update regression assertions and success label with project settings
- update README release-source only when the checkout becomes authoritative
- update latest-device-validation only after that exact build is installed/tested
- state explicitly whether the physical app was launched
- choose the next build above both project settings and every documented device build

## Validation ladder

Stop at the first real failure, fix it, then restart from that level.

### Level 0: skill tools

```bash
python3 -m unittest discover -s scripts -p 'test_*.py'
python3 -m py_compile scripts/*.py
```

### Level 1: repository contract

```bash
python3 <skill>/scripts/resonance_build_workbench.py audit . --strict
bash Tools/RegressionChecks.sh
git diff --check
```

### Level 2: strict compile

```bash
bash Tools/PreflightBuild.sh
```

This must compile simulator and generic iPhoneOS under Swift 6 complete strict concurrency with warnings as errors.

### Level 3: controlled simulator

Use the configured XcodeBuildMCP flow when available:

```bash
npx -y xcodebuildmcp@latest simulator build
```

Install/snapshot only when needed. Run the exact affected scenario and one stress case. Simulator results prove control flow and UI composition, not audible or background-device behavior.

### Level 4: fixture or authorized remote runtime

Prefer `Tools/ResonanceServer.py` and known non-private fixtures. Never place credentials, private URLs, QR payloads, track names, or private media in commands, launch arguments, logs, or committed evidence.

### Level 5: physical device

Require explicit authorization before signed install, launch, private media, remote credentials, or destructive library actions. Record the decision only after the user explicitly grants or denies it:

```bash
python3 scripts/resonance_build_workbench.py permission evidence/build-<n> \
  --name signed_device_install --allow \
  --notes 'User explicitly authorized an in-place install for this build.'
```

Record install permission and launch permission separately. The permission record proves authorization, not completion; the matching validation gate proves what actually happened. Install in place and do not uninstall first because uninstalling removes local library state, playlists, overrides, credentials, and caches.

Physical-device evidence is required for audible gaplessness, 5.1 routing, playback speed, route changes, background downloads/suspension, lock-screen behavior, energy/thermal behavior, file-sharing permissions, and long-idle stability.

### Level 6: release evidence

Verify produced app version/build, signature, install result, launch status, diagnostics privacy, and ZIP/archive integrity. Report pending runtime work explicitly.

Read [build-lifecycle.md](references/build-lifecycle.md) and [proof-and-validation.md](references/proof-and-validation.md).

## Record evidence without overclaiming

Use:

```bash
python3 scripts/resonance_build_workbench.py record evidence/build-<n> \
  --gate <gate-name> --status passed \
  --command '<sanitized command>' \
  --evidence '<relative evidence path>' \
  --notes '<result>'

python3 scripts/resonance_build_workbench.py verify evidence/build-<n>
python3 scripts/resonance_build_workbench.py verify evidence/build-<n> --release-ready
```

A pass requires a command, an existing workspace-relative evidence path, or an explicit manual note. The recorder rejects obvious embedded credentials and unsafe evidence paths. Every scoped runtime scenario is represented as a manifest gate, not merely a prose checklist. Release-ready verification requires all scoped/global gates, produced-bundle identity, README provenance review, artifact integrity, rollback data, and device acceptance plus recorded install/launch authorization when the changed subsystem requires it.

## Analyze performance diagnostics

```bash
python3 scripts/resonance_diagnostics.py summary before.log --format markdown
python3 scripts/resonance_diagnostics.py compare before.log after.log \
  --min-samples 5 --regression-threshold 10
python3 scripts/resonance_diagnostics.py compare before.log after.log \
  --min-samples 5 --regression-threshold 10 --fail-on-regression
python3 scripts/resonance_diagnostics.py audit diagnostics.log
```

Treat missing timings as missing evidence, not zero. Inspect p50, p95, p99, sample count, confidence interval, effect size, and event-count drift.

## Final report structure

Report in this order:

1. exact repository/ref/commit and dirty state
2. version/build and provenance drift resolved or still open
3. one primary intent and changed files
4. behavior contract and regression protection
5. implementation summary
6. validation actually performed, with exact results
7. checks blocked, pending, or not run
8. physical-device/install/launch facts stated separately
9. rollback reference
10. next action only when evidence justifies it

Never claim a performance gain, runtime fix, signed build, installation, launch, audible result, or release readiness from source inspection alone.
