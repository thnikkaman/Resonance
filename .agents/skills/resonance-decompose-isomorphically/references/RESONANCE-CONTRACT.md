# Resonance Engineering Contract

## Contents

- Repository shape
- Non-negotiable product invariants
- Validation ladder
- Evidence and privacy rules
- Environment and state safety
- Dynamic facts to rediscover

## Repository shape

Treat the checked-out repository as the source of truth. The current project is an iOS Swift application with a Python fixture server and repository-owned validation scripts.

| Surface | Canonical location | Contract |
|---|---|---|
| Xcode project | `Resonance.xcodeproj` | Build the `Resonance` target/scheme; never hand-edit membership without verifying the PBX project. |
| Application source | `Resonance/` | Swift 6, strict concurrency, warnings-as-errors in the preflight build. |
| Structural regression gate | `Tools/RegressionChecks.sh` | Parse every Swift file, lint plist/project files, compile the Python server, and assert project-specific invariants. |
| Current-SDK build gate | `Tools/PreflightBuild.sh` | Build both generic iOS Simulator and generic iOS device destinations with signing disabled. |
| Real fixture service | `Tools/ResonanceServer.py` | Serve a real manifest, media bytes, artwork, HEAD requests, and HTTP byte ranges. Bind only to loopback, trusted LAN, or Tailscale. |
| Simulator defaults | `.xcodebuildmcp/config.yaml` | Read the file at run time; do not hardcode the simulator model or assume it is installed. |
| Runtime diagnostics | `Resonance/Services/ResonanceDiagnostics.swift` | Keep logs privacy-safe and useful across crashes. |

The source tree evolves quickly. Discover files, build numbers, target membership, and test counts at the start of every run. Never copy a historical README value into a new assertion.

## Non-negotiable product invariants

Preserve all applicable invariants unless the user explicitly authorizes a behavior change and the change is isolated from the refactor/profiling/decomposition work.

1. **Installed state survives.** Never uninstall the physical-device app as part of validation. Uninstalling can remove local music-library state, playlists, metadata overrides, credentials, downloads, and cached remote catalog data. Install in place.
2. **Playback fallback survives.** Preserve the explicit multichannel `AVAudioEngine`/Matrix Mixer path, its failure quarantine, session-level compatibility fallback, and the independent remote `AVPlayer` path. Do not reuse a failed audio graph.
3. **Queue, seek, and boundary semantics survive.** Preserve local/remote ordering, preloading decisions, stale seek rejection, end-of-item advancement, Now Playing publication, and remote-command behavior.
4. **Cache-first startup survives.** Persisted local and remote state should render before expensive discovery, hydration, grouping, or network work. An explicit refresh/scan remains the authority for external changes.
5. **Identity and grouping survive.** Preserve stable track/album/artist identity, compilation and mixed-artist grouping, sort order, alphabet section IDs, playlist membership, favorites, recent history, and cache keys.
6. **Metadata writes remain targeted and durable.** Preserve file-format support, atomic/persistent metadata behavior, per-file reread/upsert, artwork semantics, and unsupported-format errors. Do not turn a targeted refresh into a whole-library scan.
7. **Downloads remain resumable and isolated.** Preserve destination conflict handling, cancellation/requeue, background-session restoration, targeted indexing, progress coalescing, and storage location.
8. **SwiftUI behavior survives.** Preserve `@State`/environment ownership, view identity, navigation hierarchy, tab gestures, safe-area placement, animation timing, toolbar actions, accessibility, and theme propagation.
9. **Concurrency ownership survives.** Preserve actor isolation, task cancellation, generation/revision checks, in-flight request coalescing, and main-actor publication. Never move blocking file/network/decoding work onto the main actor.
10. **Diagnostics remain private.** Never record track names, artists, albums, file paths, server URLs, usernames, passwords, tokens, salts, audio bytes, or user library contents. Record event names, counts, durations, categories, result codes, and coarse state only.

## Validation ladder

Run the cheapest deterministic gate first and stop on failure. Record every command, exit code, and artifact path.

1. `git status --short --branch` and `git diff --check`.
2. `Tools/RegressionChecks.sh`.
3. Targeted tests or harnesses for the changed subsystem.
4. `Tools/PreflightBuild.sh` on a Mac with the current Xcode/SDK.
5. XcodeBuildMCP simulator build/install/launch and focused UI inspection when available.
6. Signed Release build, deep code-signature verification, and in-place physical install when the task requires device evidence.
7. Manual physical-device acceptance for audible playback, lock-screen controls, background transfer, Tailscale/private-server behavior, thermal/battery behavior, and real-library latency.

Do not collapse these into “tests passed.” Report which rungs ran, which did not, and why. A simulator cannot prove audible gaplessness or physical background execution. A compile cannot prove UI behavior. A physical install without launch is not runtime acceptance.

## Evidence and privacy rules

- Use a sibling workspace outside the repository: `<repo>__resonance_runs/<skill>/<run-id>/`.
- Name the run `<UTC-date>-<short-sha>-<scenario>` and write `run.json` with source path, branch, SHA, dirty state, tool versions, and skipped gates.
- Keep raw outputs. Summaries must link to raw evidence rather than replace it.
- Sanitize copied diagnostics and command output. Redact secrets; prefer omitting sensitive fields entirely.
- Never put credentials in command-line arguments, Git history, launch arguments, screenshots, trace names, or fixture files.
- Do not mix measurement-only instrumentation with product behavior changes in one commit.
- Do not overwrite unrelated working-tree changes. If the tree is dirty, scope the run and record the pre-existing diff.

## Environment and state safety

Ask before any destructive or global operation: erasing a simulator, deleting app containers, clearing caches, resetting a library, changing power/thermal settings, installing toolchains, changing signing, launching a physical-device app, or contacting a non-loopback service.

Use dedicated test fixtures and accounts. Treat any live Navidrome/OpenSubsonic server as production unless the user identifies it as an isolated test server. Default to read-only probes. Never mass-download, delete playlists, star/unstar, scrobble, or write metadata against a live account without explicit scope.

## Dynamic facts to rediscover

At the start of every future build, inspect rather than assume:

- current branch, SHA, dirty files, marketing version, and build number;
- Xcode version, SDKs, scheme, destinations, signing team, and connected devices;
- simulator name from `.xcodebuildmcp/config.yaml`;
- current files referenced by `Tools/RegressionChecks.sh` and the Xcode Sources phase;
- available local fixtures, remote test server, catalog size, and network path;
- diagnostic event names and whether debugging diagnostics are enabled;
- baseline test counts, warnings, trace settings, and performance variance.
