# Resonance work queue

This is the lightweight execution record for the current phase. It replaces an
unstructured conversational TODO list without pretending that speculative work is
already approved. Each item must name its owner, evidence, acceptance oracle, and
rollback point before implementation begins.

## Active baseline

- Runtime baseline: installed simulator artifact `1.0.7/247`.
- Source baseline: checkout `3cc3d35`, with toolbar code from `1c52501`.
- Physical device: unchanged and not launched by Codex.
- Full state record: `Docs/PROJECT-STATE.md`.

## Queue

### R-247 — Manual simulator acceptance

- Status: pending user-run validation
- Owner: user/runtime acceptance
- Scope: restored Library/Streaming toolbar arrangement
- Oracle: centered hierarchy controls, leading options/playlist controls, Browse Files
  importer, Download flow, and unchanged navigation behavior
- Evidence required: user-captured screenshot and interaction result
- Rollback: reinstall the previous simulator artifact without changing app data

### R-ARCH — Preserve ownership boundaries

- Status: implemented in project documentation
- Owner: project maintenance
- Scope: `AGENTS.md`, `Docs/ARCHITECTURE.md`, `Docs/PROJECT-STATE.md`, and this queue
- Oracle: every future change identifies one owning module, one causal lever, and an
  explicit acceptance path
- Validation: `Tools/RegressionChecks.sh` checks the contract files exist; state check
  reports actual source and artifact identities

### R-PERF — Profile before the next performance change

- Status: blocked on a named reproduced workload, not a code defect
- Owner: performance investigation
- Scope: Release profiling only if the user reports a current responsiveness regression
- Required evidence: equivalent workload manifest, at least five comparable runs,
  profiler-confirmed hotspot, risk-adjusted opportunity score, and behavior oracle
- Rule: no speculative concurrency, broad refactor, cache expansion, or timer change

### R-DEVICE — Physical-device acceptance

- Status: pending explicit user request
- Owner: user/runtime acceptance
- Scope: audible playback, explicit 5.1 routing, background downloads, thermal and
  long-idle behavior
- Rule: simulator evidence cannot close this item; Codex must not launch the physical app
  automatically

## Definition of done

An implementation item is complete only when:

1. The source revision and artifact identity are recorded.
2. The owning module and preserved invariants are documented.
3. The narrowest relevant automated gates pass.
4. The named runtime acceptance is either performed and recorded or explicitly left pending.
5. README/handoff/state documentation are updated without inventing evidence.
6. Generated logs, private data, credentials, and build outputs remain outside the commit.

