---
name: resonance-refactor-isomorphically
description: >-
  Simplify and deduplicate the Resonance Swift/iOS and Python codebase without changing playback, queue/seek behavior, cache or persistence semantics, OpenSubsonic requests, downloads, SwiftUI identity, navigation, themes, diagnostics, performance, or Xcode target surface. Use for requests to refactor, DRY, remove duplication, collapse wrappers, extract shared controls or pure grouping logic, reduce accidental complexity, or remove proven-dead code in Resonance. Require an isomorphism card before editing, one lever per commit, characterization tests for unknown behavior, repository gates, and a measured ledger; use the decomposition skill when file splitting is the primary goal.
---

# Resonance Refactor Isomorphically

> **One Rule:** Prove the current contract, then remove accidental complexity. No proof means no delete, merge, rename, or abstraction.

## First actions

Resolve `SKILL_DIR` to the directory containing this `SKILL.md`. Run bundled tools as `python3 "$SKILL_DIR/scripts/<tool>.py"`; run repository commands from the repository root.

1. Read [references/RESONANCE-CONTRACT.md](references/RESONANCE-CONTRACT.md).
2. Create `<repo>__resonance_runs/refactor/<run-id>/` and record branch, SHA, dirty state, versions, and available validation rungs.
3. Run `Tools/RegressionChecks.sh` before editing.
4. Capture a machine-readable surface with `python3 "$SKILL_DIR/scripts/isomorphism_snapshot.py" capture <repo> --out <workspace>/baseline.json`.
5. Map every candidate and score it. Do not start with the largest visual duplicate; start with the highest-confidence contract match.
6. Fill `assets/isomorphism-card.md` before changing code.

## Mandatory loop

```text
1. BASELINE  -> regression, snapshot, targeted goldens, performance where relevant
2. MAP       -> duplicate/callsite/state/effect census
3. SCORE     -> (benefit x confidence) / risk; reject weak abstractions
4. PROVE     -> fill the isomorphism card and characterize unknown rows
5. CHANGE    -> one lever, minimal diff, no unrelated cleanup
6. VERIFY    -> snapshot compare, regression, build, target scenario, performance
7. LEDGER    -> before/after LOC, duplicate count, surface drift, risks, evidence
8. REPEAT    -> rescan; stop before the last low-confidence cleanup
```

## Candidate selection

Score each candidate from 1-5:

```text
score = (maintenance_benefit * confidence) / behavior_risk
```

Use net LOC reduction and duplicate-block reduction as supporting metrics, not the objective. Prefer candidates with three or more truly equivalent sites and a narrow pure contract.

Strong early candidates:

- repeated pure formatting, normalization, sectioning, or sort-key code with identical inputs/order/error behavior;
- repeated themed toolbar/button rendering with identical action, accessibility, geometry, and environment dependencies;
- pass-through wrappers with one caller and no diagnostic, actor, error, or lifetime semantics;
- repeated query construction where encoding, authentication, endpoint, and error behavior are proven equal;
- dead branches/flags with exhaustive callsite, persistence, configuration, and telemetry evidence.

High-risk candidates:

- local `Track` and remote item/model unification;
- playback state machine, seek/boundary, audio graph, or MediaPlayer consolidation;
- LibraryStore/RemoteLibraryStore state ownership;
- background URLSession delegate lifecycle;
- SwiftUI root navigation, tab gestures, `@State`, focus, scroll proxies, and environment objects;
- metadata/persistence path merging;
- anything justified by “cleaner” without a measurable duplicate/coupling problem.

Read [references/REFACTOR-PLAYBOOK.md](references/REFACTOR-PLAYBOOK.md) for project-specific equivalence axes.

## Isomorphism card

Fill every applicable row before the edit:

1. inputs and outputs;
2. ordering and stable identity;
3. errors, fallback, cancellation, and partial failure;
4. actor/thread, task lifetime, and publication timing;
5. SwiftUI identity, state, animation, gesture, accessibility, and layout;
6. persistence, cache keys, file paths, transactions, and targeted refresh;
7. API/access control, selector/string contracts, and Xcode membership;
8. diagnostics event names, timing class, and privacy;
9. performance and allocation budget;
10. validation commands, goldens, simulator, and physical checks.

Unknown is not “same.” Add a characterization test or reject the merge.

## Change discipline

- Use one named pattern per commit: extract pure helper, parameterize literals, unify identical variant rendering, collapse wrapper, remove proven dead branch, or share a value transform.
- Keep signatures, default values, ordering, errors, diagnostic names, actor annotations, and strings unchanged unless the card explicitly authorizes and tests a change.
- Apply the Rule of Three. Two similar sites can be coincidence; document them and wait unless the maintenance burden is already proven.
- Prefer a small value function or explicit variant enum over inheritance, a one-implementation protocol, global manager, generic utility bucket, or new state owner.
- Do not mass-rewrite Swift with regex/codemods. Review each call site and keep the diff auditable.
- Do not mix behavior fixes, UI redesign, performance changes, file decomposition, or version bumps into the refactor commit.
- Never delete a file or persisted key without explicit approval and a migration/compatibility plan.

## Verification

Run the strict surface comparison first:

```bash
python3 "$SKILL_DIR/scripts/isomorphism_snapshot.py" compare <repo> \
  --baseline <workspace>/baseline.json \
  --out <workspace>/compare.json
```

Any removed declaration, diagnostic event, route, Xcode source membership, or tracked source file is a stop condition until explained in an allowlist reviewed in the card.

Then run:

```bash
git diff --check
Tools/RegressionChecks.sh
Tools/PreflightBuild.sh  # current-Xcode Mac
```

Add targeted real-service, simulator, physical-device, metadata-file, or performance checks according to the affected contract. Use `resonance-real-service-e2e` for network/service paths and `resonance-profile-performance` for hot paths.

## Dead-code gauntlet

Before removing code, prove all of the following:

- no static call sites, selectors, notifications, restoration IDs, persistence keys, or reflection/string references;
- no Xcode build-phase/resource reference;
- no app lifecycle, delegate, URLSession restoration, remote command, or background entry point;
- no tests, scripts, README/manual workflow, migration, or old persisted state depends on it;
- feature/config values cannot enable it;
- diagnostic evidence from a representative run supports non-use when runtime reachability matters;
- removal does not change public/internal surface or decode old data.

If any row is unknown, deprecate or leave it; do not delete it as “probably unused.”

## Metrics ledger

Report per commit:

- source LOC before/after and net delta;
- duplicate sites/blocks before/after;
- number of call sites migrated;
- snapshot removals/additions and approved waivers;
- regression/build result and warnings;
- golden/test count before/after;
- performance delta for hot paths;
- new abstractions/types/files introduced;
- rejected candidates and why.

A refactor that adds more concepts than it removes needs an explicit justification. A green build with fewer collected checks is a failure.

## Required outputs

```text
run.json
baseline.json
candidate-map.md
cards/<candidate>.md
compare/<candidate>.json
ledger.md
rejections.md
FINAL_REFACTOR_REPORT.md
```

## Stop conditions

Stop when the baseline is red, equivalence depends on undocumented behavior, call sites have divergent invariants, actor/state ownership would change, performance cannot be compared honestly, the candidate needs a migration rather than a refactor, or only aesthetic benefit remains.

## Resources

- Project invariants: [references/RESONANCE-CONTRACT.md](references/RESONANCE-CONTRACT.md)
- Equivalence and pattern guidance: [references/REFACTOR-PLAYBOOK.md](references/REFACTOR-PLAYBOOK.md)
- Surface capture/compare: `scripts/isomorphism_snapshot.py`
- Card template: `assets/isomorphism-card.md`
- Trigger checks: [SELF-TEST.md](SELF-TEST.md)
