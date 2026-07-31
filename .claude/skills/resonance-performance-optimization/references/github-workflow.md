# GitHub and Local Checkout Workflow

## Contents

1. Resolve the target
2. Inspect repository context
3. Work locally
4. Review the patch
5. Publish only on request
6. Failure cases

## 1. Resolve the target

Use the GitHub connector first when the user supplies a GitHub URL or selects GitHub.

For `thnikkaman/Resonance/tree/agent/alpha-3.7.4-source`:

- repository: `thnikkaman/Resonance`
- ref: `agent/alpha-3.7.4-source`

A branch name containing slashes may not appear through branch search. Resolve it by either:

- fetching a known file such as `README.md` with the explicit ref, or
- comparing the ref with itself to retrieve the resolved commit SHA

Do not treat an empty branch-search result as proof that the ref does not exist.

## 2. Inspect repository context

Fetch from the exact ref:

- `README.md`
- `.xcodebuildmcp/config.yaml`
- `Tools/RegressionChecks.sh`
- `Tools/PreflightBuild.sh`
- `Resonance.xcodeproj/project.pbxproj`
- every source file involved in the proposed change

When a task refers to an issue, PR, review, or CI run, retrieve that structured GitHub context before drafting or editing.

Do not compare with `main` until `git merge-base` or a connector comparison proves a common ancestor. If no common ancestor exists, choose an explicit baseline tag/commit or compare file snapshots deliberately.

## 3. Work locally

Use local `git` and build tools for:

- exact branch/commit and dirty-state resolution
- source edits
- changed-file discovery
- build and test execution
- diff inspection
- commit creation and push

Before editing:

```bash
git status --short --branch
git rev-parse HEAD
git branch --show-current
python3 <skill>/scripts/resonance_build_workbench.py audit .
```

Do not overwrite unrelated local changes. If the checkout is dirty, record the pre-existing paths and keep the patch isolated.

## 4. Review the patch

Before publication:

```bash
git diff --stat
git diff --check
git diff -- <changed-files>
python3 <skill>/scripts/resonance_build_workbench.py scope .
```

Review:

- one primary intent
- no accidental project/source membership changes
- no weakened assertions
- no secrets, diagnostics, private media, XcodeBuildMCP artifacts, derived data, or device exports
- version/build and README provenance consistency
- regression and runtime evidence appropriate to the changed subsystem

## 5. Publish only on request

Do not push, create a branch, or open a PR unless the user explicitly requests publication.

When requested:

1. confirm the intended files and build identity
2. stage only the intended patch
3. use a focused commit message
4. push the current branch or a named feature branch
5. open a draft PR when review is still needed
6. include exact validation completed and pending
7. do not claim physical-device launch or audible acceptance without evidence

Use the GitHub publish workflow/tooling available in the environment rather than inventing an unsupported API path.

## 6. Failure cases

### Slash branch is not listed

Fetch by explicit ref or compare the ref to itself. Do not fall back to `main`.

### No common ancestor with `main`

Do not force a misleading three-dot diff. Use the authoritative tag/commit named by README, a user-specified baseline, or a deliberate file-level comparison.

### GitHub connector cannot expose build logs

Use local `gh` only for the missing Actions/log capability when authenticated and appropriate. Do not imply the connector provided logs it cannot provide.

### Local checkout cannot access the network

Use the connector to inspect exact files and history. State that local build/test work requires an available checkout; do not fabricate results.
