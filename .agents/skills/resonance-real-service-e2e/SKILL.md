---
name: resonance-real-service-e2e
description: >-
  Build and run mock-free integration and end-to-end tests for Resonance across real HTTP byte ranges, the repository fixture server, isolated Navidrome/OpenSubsonic test servers, SQLite/filesystem metadata, URLSession downloads, simulator UI, and physical-device playback/background behavior. Use when validating manifests, streaming, artwork, auth, playlists, favorites, scrobbling, seek/queue boundaries, downloads, metadata writes, persistence, or production regressions hidden by stubs. Require endpoint safety guards, disposable fixtures/accounts, structured privacy-safe JSONL evidence, exact cleanup, and honest separation of host, simulator, and physical-device proof.
---

# Resonance Real-Service E2E

> **One Rule:** Critical Resonance paths must cross the same real boundary that can fail in production. A mock may support a pure unit test; it cannot certify HTTP, filesystem, SQLite, URLSession, audio, app lifecycle, or device behavior.

## First actions

Resolve `SKILL_DIR` to the directory containing this `SKILL.md`. Run bundled tools as `python3 "$SKILL_DIR/scripts/<tool>.py"`; run repository commands from the repository root.

1. Read [references/RESONANCE-CONTRACT.md](references/RESONANCE-CONTRACT.md).
2. Create `<repo>__resonance_runs/e2e/<run-id>/` and record the target tier, fixture/account, URL classification, and destructive operations.
3. Run `Tools/RegressionChecks.sh` before provisioning services.
4. Start with the deterministic loopback contract harness:

```bash
python3 "$SKILL_DIR/scripts/real_service_harness.py" <repo> \
  --out <workspace>/fixture-service.jsonl
```

5. Escalate to an isolated real OpenSubsonic server, simulator, or physical device only when the scenario requires it and the user has supplied/approved the environment.
6. Never point mutation tests at an unconfirmed live account or real music library.

## Test tiers

| Tier | Real boundary | Suitable claims |
|---|---|---|
| A: host contract | Real `Tools/ResonanceServer.py`, real filesystem, HTTP client, full/range/HEAD/error requests | Manifest/media server semantics and deterministic CI coverage. |
| B: isolated OpenSubsonic | Real Navidrome/OpenSubsonic test instance and dedicated account/library | Auth, ping, catalog, playlists, favorites, scrobble, cover art, stream/range behavior. |
| C: simulator app | Real built app, URLSession, SQLite/files, SwiftUI, fixture/test server | App integration, persistence, navigation, downloads, metadata/UI flows; not audible/physical background proof. |
| D: physical device | Signed in-place app, real audio route, lock screen, background transfer, private network | Audible playback/fallback, seek/boundary, remote commands, background URLSession, Tailscale, thermal/battery acceptance. |

Do not describe Tier A as app E2E or Tier C as physical acceptance.

## Mock risk matrix

Score `impact x boundary-divergence` from 1-25.

| Surface | Typical score | Rule |
|---|---:|---|
| HTTP manifest, artwork, full/range media | 16-25 | Must use a real server and bytes. |
| OpenSubsonic auth/catalog/playlist/favorite/scrobble | 16-25 | Must use an isolated real server for release confidence. |
| SQLite, metadata files, cache restoration | 12-25 | Use disposable real files/database/container. |
| URLSession download/cancel/requeue/background restore | 16-25 | Use real HTTP and app/system task lifecycle. |
| AVAudioEngine/AVPlayer/MediaPlayer/route changes | 20-25 | Physical-device acceptance required for final claims. |
| Pure sort/key/format function | 1-4 | Deterministic unit tests are sufficient; no service mock needed. |

A mock may drive a view preview or a pure error branch, but label it as unit coverage. Do not count it as real-service evidence.

## Mandatory loop

```text
1. RISK       -> choose the mocked/untested boundary with highest product risk
2. PROVISION  -> disposable files, isolated account/server, dedicated simulator/device state
3. GUARD      -> classify endpoint and block production/destructive scope
4. EXERCISE   -> real protocol/filesystem/database/system lifecycle
5. OBSERVE    -> JSONL phases, exact status/bytes/state, privacy-safe diagnostics
6. ASSERT     -> user-visible result plus server/file/database truth
7. CLEAN      -> terminate services and remove only run-owned state
8. REGRESS    -> turn every confirmed production bug into a deterministic real-boundary test
```

## Endpoint and credential safety

Before any non-loopback request, require a written test-server declaration containing owner, hostname, data set, account, permitted mutations, reset/cleanup method, and expiry. Default to read-only.

Hard constraints:

- Reject production credentials and unknown endpoints.
- Use environment variables or secure connector/keychain paths; never commit or echo secrets.
- Do not place credentials/tokens/salts in CLI arguments, URLs saved to logs, screenshots, trace names, or JSONL.
- Redact query strings before logging OpenSubsonic requests because auth material may be present.
- Require explicit approval for playlist creation/deletion, star/unstar, scrobble, downloads, metadata writes, or server changes.
- Use unique run prefixes and a cleanup registry for every created remote entity/file.
- Bind the bundled unauthenticated fixture server to `127.0.0.1` by default. Trusted LAN/Tailscale exposure requires user approval.

## Tier A: fixture-service contract

The bundled harness creates a valid disposable WAV fixture, launches the repository’s real Python server, and verifies:

- manifest JSON and stable media path;
- full GET bytes;
- HEAD headers with no body;
- prefix and suffix byte ranges (`206` and exact `Content-Range`);
- invalid range (`416`);
- missing path and traversal protection;
- server process startup/teardown and structured evidence.

Keep this as the fast smoke gate for every server/range/download change. Extend the harness with a regression assertion when a production server bug is found; do not replace the server with an in-memory fake.

## Tier B: real OpenSubsonic matrix

Read [references/REAL-SERVICE-MATRIX.md](references/REAL-SERVICE-MATRIX.md). Test protocol behavior in this order:

1. `ping` and version/error envelope;
2. catalog/album/track decoding and identity;
3. cover art;
4. stream startup, HEAD/ranges, seek-relevant behavior;
5. playlists in a run-owned namespace;
6. favorite/star round trip;
7. scrobble only on a dedicated test track/account;
8. failures: bad credential, missing ID, network interruption, server restart, stale catalog.

Assert both the app response and the server’s resulting state. A successful HTTP status with wrong playlist/favorite state is a failed test.

## Tier C: simulator app

Use a dedicated simulator or dedicated test app/container. Ask before erasing/resetting it. Build/install with the repository configuration and drive focused flows:

- cache-first local/remote startup;
- Library/Streaming navigation and grouping;
- real server configuration and catalog activation;
- download/cancel/requeue and targeted indexing;
- disposable metadata write/read-back;
- relaunch persistence;
- error presentation and diagnostics privacy.

Capture screenshots only when they add evidence; avoid private library/account content. Verify database/file state in addition to visible UI.

## Tier D: physical device

Install in place; never uninstall the user’s app. Separate install, launch, and acceptance permissions. Use disposable tracks/server data.

Physical-only checks include audible start/boundary/downmix fallback, route changes, lock-screen/remote commands, exact-end seek behavior, background downloads while suspended/locked, Tailscale/private-network transitions, battery/thermal impact, and relaunch restoration. Record objective diagnostics and a manual acceptance checklist. Do not claim “gapless” from logs alone.

## Structured evidence

Emit JSON Lines with one object per event:

```json
{"ts":"...","suite":"fixture-range","test":"prefix-range","phase":"act","event":"http_response","status":206,"bytes":16}
{"ts":"...","suite":"download","test":"cancel-requeue","phase":"assert","event":"state","expected":"queued","actual":"queued","match":true}
```

Allowed fields: timestamps, suite/test IDs, phase, event, duration, counts, coarse categories, status/result, expected/actual non-sensitive enums/numbers, artifact path. Never include media names, paths, URLs, usernames, tokens, or raw catalog rows.

On failure preserve run-owned server logs, sanitized diagnostics, response headers, byte hashes, database/file snapshots, screenshot, and cleanup status.

## Migration from mocks

1. Read the mocked test and state the production boundary it avoids.
2. Score risk and define the real fixture/account.
3. Write the real-boundary test beside the mock temporarily.
4. Run both and compare assertions. When the real test fails and the mock passes, treat it as a discovered fidelity bug.
5. Make the real test deterministic and safe.
6. Remove the redundant boundary mock after explicit review; keep pure unit tests that still add value.

Do not maintain two conflicting authoritative suites.

## Required outputs

```text
run.json
safety-declaration.md
fixture-service.jsonl
real-service-matrix.md
artifacts/index.md
cleanup-registry.json
FINAL_E2E_REPORT.md
```

The final report must separate claims by tier, list exact real boundaries, fixtures/accounts, mutations, cleanup, pass/fail counts, discovered mock divergences, privacy audit, and unperformed physical checks.

## Resources

- Project invariants: [references/RESONANCE-CONTRACT.md](references/RESONANCE-CONTRACT.md)
- Endpoint/test matrix: [references/REAL-SERVICE-MATRIX.md](references/REAL-SERVICE-MATRIX.md)
- Loopback server harness: `scripts/real_service_harness.py`
- Run-report template: `assets/e2e-run-report.md`
- Trigger checks: [SELF-TEST.md](SELF-TEST.md)
