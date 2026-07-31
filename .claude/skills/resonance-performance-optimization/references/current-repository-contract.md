# Current Resonance Repository Contract

## Contents

1. Snapshot identity
2. Current source and build provenance
3. Head change contract
4. Known contract drift
5. Validation surface
6. Continuation rules

## 1. Snapshot identity

Verified against GitHub on 2026-07-30:

- repository: `thnikkaman/Resonance`
- ref: `agent/alpha-3.7.4-source`
- head: `641b868b3171c0748e360294c51eebdcb7a84dcb`
- head message: `Reduce startup and Streaming transition stalls`
- authoritative continuation tag named by README: `Resonance-Beta-v1.0.6`
- Xcode project/target/scheme: `Resonance.xcodeproj` / `Resonance` / `Resonance`
- XcodeBuildMCP simulator default: `iPhone 17 Pro`

Re-resolve this information for every task. The branch may advance after this snapshot.

The target branch has previously reported no common ancestor with `main`. Do not use a `main...branch` diff until the relationship is proven for the current refs.

## 2. Current source and build provenance

The current files expose three distinct facts:

| Source | Version | Build | Meaning |
|---|---:|---:|---|
| `README.md` current stable/release source | 1.0.6 | 210 | Authoritative source snapshot described by README |
| `Resonance.xcodeproj/project.pbxproj` | 1.0.6 | 210 | Current Debug and Release target settings |
| `README.md` latest device validation | 1.0.6 | 214 | Build installed in place; README says the physical app was not launched by Codex |

`Resonance/Info.plist` inherits `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)`. Settings reads bundle version/build dynamically. Do not hardcode either surface.

Choose a future build number above every known project and documented device build. At this snapshot, the first collision-free candidate is build 215, but always rerun the audit.

## 3. Head change contract

Head build 214 changes startup and the first Streaming transition without changing the project build setting:

### Local startup

- `LibraryStore` exposes `isBootstrapping`.
- Display-snapshot decoding no longer occurs synchronously in `LibraryStore.init`.
- `bootstrap()` loads the display snapshot in a utility-priority detached task after the app shell can render.
- Cache URL/static display-load helpers are `nonisolated` so immutable file work can execute outside the main actor.
- Cached rows remain the startup authority; artwork hydration and explicit refresh semantics remain separate.

### Remote startup

- `RemoteLibraryStore` loads cached startup state in a utility-priority detached task.
- Cache URLs, cache keys, browse needs, and browse cache values are Sendable/nonisolated where required.
- `prewarmBrowseCache(groupCompilationArtists:)` builds filtered tracks, albums, artists, and album artists off-main.
- Publication is accepted only when catalog revision and sort direction still match.
- Compilation grouping is part of the cache key.

### App activation order

`ResonanceApp` currently:

1. starts local and remote activation concurrently
2. awaits both activations
3. prewarms the remote browse cache using the current compilation-grouping setting
4. resumes persisted downloads using the activated remote catalog and local store

Preserve this ordering unless the new design explicitly replaces it with a proven equivalent state machine.

## 4. Known contract drift

The current checkout contains drift that future build work must not silently inherit:

1. `README.md` documents latest device validation build 214 while project settings and release source remain build 210.
2. `Tools/RegressionChecks.sh` asserts project version/build 1.0.6/210 but its final success message says `Resonance Beta v1.0.7 regression checks passed.`
3. The build-214 startup/prewarm symbols are present in source, but the current regression script does not explicitly protect `isBootstrapping`, `loadCachedStartupStateIfNeeded`, `prewarmBrowseCache`, or `makeBrowseCache`.
4. The Xcode project default `SWIFT_VERSION` remains 5.0, while repository validation deliberately overrides Swift 6, complete strict concurrency, and warnings as errors.

The bundled workbench reports these as warnings or information. Before release, resolve the version/label drift and add durable assertions for any continuation behavior the next build depends on.

## 5. Validation surface

### Fast contract gate

`Tools/RegressionChecks.sh` currently performs:

- Swift 6 syntax parsing for every Swift source
- `plutil` validation for `Info.plist` and the project file
- Python compilation for `Tools/ResonanceServer.py`
- exact source-membership, version/build, UI, catalog, download, artwork, playback, matrix, persistence, and diagnostics assertions
- deterministic fixture checks for alphabet coordinate mapping and mixed-artist grouping

The script is extensive but static. It cannot prove runtime behavior, audible output, background execution, signing, installation, or user-perceived performance.

### Strict compile gate

`Tools/PreflightBuild.sh` runs clean Debug builds for:

- generic iOS Simulator
- generic iPhoneOS

with:

- `SWIFT_VERSION=6`
- `SWIFT_STRICT_CONCURRENCY=complete`
- `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`
- code signing disabled

### Agent build defaults

`.xcodebuildmcp/config.yaml` sets:

- project: `./Resonance.xcodeproj`
- scheme: `Resonance`
- simulator: `iPhone 17 Pro`

## 6. Continuation rules

For every future build:

- resolve the new head and rerun the repository audit
- preserve or deliberately supersede every affected continuation contract
- add regression protection for new durable behavior
- keep one primary intent per build
- keep compile, sign, install, launch, simulator acceptance, and physical-device acceptance as separate facts
- install in place when authorized; do not uninstall first
- never place credentials, private URLs, QR payloads, track names, private paths, or private media in committed evidence
- update README provenance with exact completed and pending validation
