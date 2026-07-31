# Resonance Agent Skills

This catalog packages four repository-specific Agent Skills for the Resonance Swift/iOS codebase. Each skill is self-contained so it can also be validated and distributed independently.

The catalog was authored from the `agent/alpha-3.7.4-source` line and its repository-owned validation contracts. Every run must rediscover the current branch, SHA, versions, Xcode configuration, source membership, diagnostics, tests, and device availability instead of treating the authored snapshot as permanent truth.

## Routing

| Intent | Skill | Primary output |
|---|---|---|
| Split a giant or over-coupled Swift file | `resonance-decompose-isomorphically` | Confirmed seam ledger and staged decomposition plan |
| Find why startup, Streaming, playback, downloads, metadata, or builds are slow | `resonance-profile-performance` | Reproducible baseline and ranked hotspot table |
| Simplify, deduplicate, collapse wrappers, or remove proven-dead code | `resonance-refactor-isomorphically` | Per-change isomorphism cards and drift ledger |
| Exercise HTTP, files, SQLite, URLSession, OpenSubsonic, simulator, or device behavior without boundary mocks | `resonance-real-service-e2e` | Tiered real-boundary evidence and cleanup report |

Do not route by filename alone. Route by the user’s primary intent. Compose skills only when the evidence requires it:

1. Performance complaint: profile first; use real-service E2E for service fidelity; then choose refactor or decomposition as the smallest lever.
2. File-splitting request: use decomposition; invoke profiling only for claimed runtime/build gains and real-service E2E only for affected boundaries.
3. Cleanup request: use refactoring; route to decomposition if file boundaries become the primary change.
4. Production regression hidden by a stub: use real-service E2E first, then the narrow implementation skill.

## Shared rules

- Treat the checked-out repository as the source of truth.
- Put generated evidence in `<repo>__resonance_runs/<skill>/<run-id>/`, not in the app repository.
- Establish a green baseline before editing and distinguish pre-existing failures.
- Keep measurement, mechanical movement, refactoring, behavior fixes, and version bumps in separate commits.
- Preserve installed state; never uninstall the physical-device app as a validation shortcut.
- Keep diagnostics and artifacts free of media names, paths, server URLs, account data, and credentials.
- Run the repository validation ladder from deterministic checks through simulator/device evidence as required. Never promote a lower evidence tier into a stronger claim.

## Catalog checks

Run from the repository root:

```bash
python3 Tools/ValidateAgentSkills.py
python3 Tools/SmokeTestAgentSkills.py
```

The static validator checks format, trigger metadata, progressive-loading references, script syntax/dependencies, package size, executable bits, and shared-contract consistency. The smoke test exercises every bundled script against the current repository, including the real loopback fixture server unless `--skip-server` is passed.

Then run normal repository gates:

```bash
Tools/RegressionChecks.sh
Tools/PreflightBuild.sh  # current-Xcode Mac
```

## Future-build maintenance

1. Update the four copies of `references/RESONANCE-CONTRACT.md` together when a durable product invariant, canonical path, or validation rung changes. The validator rejects drift between copies.
2. Update scenario/playbook references rather than bloating `SKILL.md`; keep entrypoints below 500 lines.
3. Add a positive and negative trigger to `SELF-TEST.md` for every newly supported workflow or routing ambiguity.
4. Add deterministic script coverage for fragile repeatable operations. Keep scripts standard-library-only unless dependencies are explicitly documented.
5. Turn each confirmed production regression into a characterization, real-boundary, or privacy assertion in the appropriate skill and repository gate.
6. Re-run both catalog tools and the repository validation ladder before merging skill changes.
