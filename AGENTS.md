# Resonance Agent Guide

This file applies to the entire repository. A more specific `AGENTS.md` may add stricter rules for its subtree.

## Start every run

1. Record the repository root, branch, commit SHA, dirty state, current `MARKETING_VERSION`, current `CURRENT_PROJECT_VERSION`, and available Mac/simulator/device tooling. Do not infer a build number from old documentation.
2. Read the current README sections relevant to the requested surface and inspect the current implementation before proposing a change.
3. Keep generated evidence outside the app repository under `<repo>__resonance_runs/<workflow>/<run-id>/` unless the user explicitly requests a committed fixture or report.
4. Run the existing baseline before editing. Separate pre-existing failures from regressions introduced by the change.
5. Select the narrowest repository skill below and follow its proof gates. Do not combine refactoring, behavior repair, redesign, and optimization in one unreviewable change.

## Repository skills

| Intent | Skill |
|---|---|
| Split a large Swift file, discover seams, reduce compile pressure, or modularize without product drift | `.agents/skills/resonance-decompose-isomorphically/SKILL.md` |
| Find and rank startup, UI, playback, network, persistence, memory, energy, or build bottlenecks | `.agents/skills/resonance-profile-performance/SKILL.md` |
| Simplify, deduplicate, remove proven-dead code, or extract a shared kernel without behavior change | `.agents/skills/resonance-refactor-isomorphically/SKILL.md` |
| Test HTTP ranges, OpenSubsonic, files, SQLite, downloads, simulator flows, or physical-device behavior through real boundaries | `.agents/skills/resonance-real-service-e2e/SKILL.md` |

Read `.agents/skills/README.md` when maintaining or packaging the skills themselves.

## Product invariants

Treat these as contracts unless the task explicitly changes one and adds migration/acceptance evidence:

- Preserve local and remote playback semantics, queue order, seek arbitration, end-of-item behavior, fallback ownership, Now Playing publication, and remote-command routing.
- Never reuse a quarantined failed audio graph. Do not add logging, allocation, locking, actor hops, or other non-real-time-safe work to render or boundary-sensitive paths.
- Preserve SwiftUI identity, state ownership, environment injection, gesture priority, navigation restoration, focus, animation, accessibility, and stable scroll IDs.
- Preserve Swift concurrency isolation, cancellation, publication order, stale-result rejection, generation/revision checks, and in-flight task coalescing.
- Preserve database transactions, file naming, cache keys, metadata fields, targeted refresh behavior, exclusions, playlists, favorites, history, credentials, and persisted settings unless a migration is part of the task.
- Treat diagnostics event names, endpoint strings, notification names, selectors, persistence keys, plist values, access control, and Xcode Sources membership as API surface.
- Keep diagnostics privacy-safe: never record media names, filesystem paths, private URLs/hosts, credentials, usernames, raw authenticated queries, or media bytes.
- Do not uninstall the app as part of an in-place validation flow unless the user explicitly approves destructive state loss.
- Do not claim audible playback, lock-screen controls, route behavior, thermal/battery behavior, background transfer, or private-network acceptance from simulator evidence.

## Validation ladder

Run the lowest rungs early and all applicable higher rungs before claiming completion:

1. `git diff --check`
2. `python3 Tools/ValidateAgentSkills.py` when `.agents/skills`, this file, or the validator changes
3. `Tools/RegressionChecks.sh`
4. Targeted unit, characterization, contract, performance, or real-service tests added for the change
5. `Tools/PreflightBuild.sh` for strict Swift 6 simulator and generic-device compilation
6. XcodeBuildMCP simulator build/install/launch and visual or accessibility inspection for UI behavior
7. Signed Release build, strict code-signature verification, and in-place physical-device install when release evidence is requested
8. Explicit physical-device acceptance for audio, MediaPlayer, background, route, network, thermal, and battery claims

Record the exact command, build configuration, destination, input state, result, and artifact path. A compile is not a UI test; an install is not a launch; a launch is not physical acceptance.

## Change and evidence discipline

- State the observed problem, baseline, hypothesis, intended invariant, and rollback before editing.
- Prefer one behavioral hypothesis or one isomorphic lever per commit. Keep measurement-only instrumentation separate from optimization when practical.
- Add characterization before moving or deleting behavior that is not already covered.
- Use real services and real bytes for boundary behavior; mocks may support pure unit tests but cannot certify HTTP, SQLite, filesystem, URLSession, audio, or app lifecycle behavior.
- Report distributions and raw samples for performance work. Never fabricate timing, device, profiler, signing, installation, launch, or acceptance evidence.
- Update regression checks and documentation when a stable contract, diagnostic, build workflow, or manual continuation step changes.
- End every handoff with what changed, what was proven, what was not run, remaining risks, and the exact next manual acceptance step.
