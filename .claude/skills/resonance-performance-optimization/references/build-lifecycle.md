# Resonance Future-Build Lifecycle

## Contents

1. Intake and source lock
2. Contract audit
3. Build workspace
4. Baseline and reproduction
5. Implementation
6. Validation ladder
7. Version and release synchronization
8. Device and private-data boundary
9. Evidence recording
10. Release decision and publication

## 1. Intake and source lock

Record:

- repository/ref/commit
- dirty state and pre-existing local changes
- current project version/build
- README stable, release-source, and latest-device build
- one primary intent
- issue/PR or user report, when applicable
- affected files and subsystems
- explicit non-goals

Do not begin from a mutable label alone. Resolve the exact commit.

## 2. Contract audit

Run:

```bash
python3 <skill>/scripts/resonance_build_workbench.py audit <repo>
```

Use `--strict` before implementation and before release. The current branch contains known drift, so an initial strict audit may intentionally fail with warnings. Record the warnings and the disposition of each one.

Audit errors are structural blockers. Audit warnings require an explicit resolution or release-blocked decision.

## 3. Build workspace

Create one workspace per build:

```bash
python3 <skill>/scripts/resonance_build_workbench.py init evidence/build-215 \
  --repo . \
  --ref agent/alpha-3.7.4-source \
  --commit <sha> \
  --intent 'Reduce the first Streaming transition stall without changing catalog ordering' \
  --files Resonance/ResonanceApp.swift Resonance/Services/RemoteLibraryStore.swift
```

Generated files:

```text
manifest.json
contract-audit.json
contract-audit.md
change-scope.json
change-scope.md
change-plan.md
validation-plan.md
acceptance.md
release-note.md
evidence/
performance/
```

Fill all TODO fields before release verification.

## 4. Baseline and reproduction

For a defect:

- write exact steps
- record current visible result
- identify stable IDs/state/events relevant to the defect
- capture a minimal reproducer and one stress/edge case

For a performance issue:

- define equivalent before/after workload manifests
- run at least five repetitions, preferably ten for noisy paths
- capture p50/p95/p99 and a secondary metric
- profile the real user path

For a feature:

- define the new behavior and every existing behavior that must remain unchanged
- identify persistence, ordering, cancellation, permissions, and rollback

## 5. Implementation

Use this sequence:

1. Add or strengthen a deterministic regression tripwire for the intended contract.
2. Implement the smallest patch that satisfies the primary intent.
3. Avoid unrelated refactors, formatting churn, and product changes.
4. Add new Swift files to the target Sources phase.
5. Keep actor isolation, Sendable boundaries, cache keys, generation guards, and state ordering explicit.
6. Keep private data out of source, tests, diagnostics, commands, and evidence.

Do not edit `RegressionChecks.sh` only to match implementation text. Prefer assertions on durable symbols, state-machine boundaries, dynamic version behavior, and small deterministic fixtures.

## 6. Validation ladder

### A. Skill and repository contract

```bash
python3 -m unittest discover -s <skill>/scripts -p 'test_*.py'
python3 <skill>/scripts/resonance_build_workbench.py audit . --strict
bash Tools/RegressionChecks.sh
git diff --check
```

### B. Strict compile

```bash
bash Tools/PreflightBuild.sh
```

### C. Simulator build and runtime

```bash
npx -y xcodebuildmcp@latest simulator build
```

Then run the scoped simulator scenarios. Use `--output jsonl` for long machine-readable operations when supported.

### D. Fixture/remote validation

Prefer a local `Tools/ResonanceServer.py` fixture. Use authorized remote credentials only when the user explicitly authorizes them. Keep secrets out of commands and logs.

### E. Signed/device validation

Separate these facts:

- signed arm64 build succeeded
- signature verification succeeded
- in-place install succeeded
- application was launched
- manual runtime behavior was accepted

One does not imply the next.

### F. Artifact integrity

Verify:

- app bundle version/build
- code signature when signed
- expected bundle identifier
- archive/ZIP integrity
- no private evidence or derived artifacts in the package

## 7. Version and release synchronization

Generate a plan:

```bash
python3 <skill>/scripts/resonance_build_workbench.py version-plan . \
  --version 1.0.7 --build 215
```

Synchronize:

- both target `MARKETING_VERSION` values
- both target `CURRENT_PROJECT_VERSION` values
- exact regression assertions
- regression success label
- README release-source only when authoritative
- README latest-device build only after actual device validation

Do not hardcode `Info.plist` or Settings labels.

## 8. Device and private-data boundary

Require explicit user authorization before:

- signing or installing to a device
- launching the physical application
- using private remote credentials
- reading/copying private diagnostics or media
- destructive library actions

After the user explicitly decides, record the narrow permission separately from execution evidence:

```bash
python3 <skill>/scripts/resonance_build_workbench.py permission evidence/build-215 \
  --name signed_device_install --allow \
  --notes 'User explicitly authorized an in-place install for build 215.'

python3 <skill>/scripts/resonance_build_workbench.py permission evidence/build-215 \
  --name launch_physical_app --deny \
  --notes 'User authorized installation but did not authorize launch.'
```

Never set an allow flag by inference. Install in place. Do not uninstall first.

Do not auto-launch after installation when the user has not authorized launch. A physical-device build/install without launch does not establish runtime acceptance.

## 9. Evidence recording

Record each gate:

```bash
python3 <skill>/scripts/resonance_build_workbench.py record evidence/build-215 \
  --gate bash_tools_regressionchecks_sh \
  --status passed \
  --command 'bash Tools/RegressionChecks.sh' \
  --evidence 'evidence/build/regression.txt'
```

Use workspace-relative evidence paths; a passed gate with an evidence path requires that file to exist. Sanitize commands, notes, and paths. Mark failed, blocked, not-run, and not-applicable states honestly. The generated manifest contains every global gate and every scoped runtime acceptance item so release verification cannot silently skip a prose-only check.

## 10. Release decision and publication

Before release:

```bash
python3 <skill>/scripts/resonance_build_workbench.py verify evidence/build-215 --release-ready
```

A release-ready workspace requires:

- no TODO placeholders
- build above every known baseline/device build
- all global and scoped runtime gates passed or justified not-applicable
- produced app-bundle identity, README provenance review, and artifact integrity passed
- physical-device acceptance plus recorded install/launch permission when required by scope
- accepted release decision
- rollback reference/instructions verified
- accurate release note

Publish only when requested. Include exact completed and pending validation in the commit/PR/release description.
