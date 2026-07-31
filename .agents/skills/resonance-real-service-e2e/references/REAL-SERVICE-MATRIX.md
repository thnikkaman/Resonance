# Resonance Real-Service Matrix

## Contents

- Safety declaration
- Fixture server cases
- OpenSubsonic cases
- App integration cases
- Physical acceptance cases
- Failure and cleanup matrix

## Safety declaration

Complete before contacting anything except loopback:

```markdown
- Server owner:
- Test hostname/classification:
- Dedicated test account:
- Dedicated test library/data:
- Allowed reads:
- Allowed writes:
- Forbidden operations:
- Reset/cleanup procedure:
- Credential source (never value):
- Approval and expiry:
```

Unknown or shared production state means read-only probes only, or stop.

## Fixture server cases

| Case | Real action | Assertions |
|---|---|---|
| Manifest cold/warm | GET `/resonance/library.json` | JSON schema, one entry per supported file, stable ID/path, cache behavior, no sensitive logs. |
| HEAD media | HEAD real media path | `200`, content type/length, `Accept-Ranges`, empty body. |
| Full media | GET real bytes | Exact byte hash and length. |
| Prefix range | `Range: bytes=0-15` | `206`, exact bytes, `Content-Range`, length 16. |
| Suffix range | `Range: bytes=-16` | Last 16 bytes and correct range. |
| Invalid range | Beyond EOF/malformed | `416` and valid total-size header where applicable. |
| Traversal | Encoded `..` path | Forbidden/not found; never reads outside fixture root. |
| Artwork | Real tagged fixture when available | Exact content type/bytes and cache header. |
| Concurrency | Multiple clients/ranges | Correct independent responses; no corruption/hang. |

## OpenSubsonic cases

Use the API/version supported by the configured server; capture the returned protocol version instead of assuming one.

| Domain | Success | Failure/edge |
|---|---|---|
| Auth/ping | dedicated account succeeds | bad password/token, disabled account, server unavailable |
| Catalog | IDs, title/artist/album fields, duration, track/disc, album artist | missing/unknown fields, Unicode, mixed artists, large catalog, stale revision |
| Album/artist grouping | stable canonical grouping and order | composite/unknown album artist, compilations, duplicate spellings |
| Cover art | real bytes and decode | missing ID, invalid image, slow/large image, cache refresh |
| Stream | startup and exact range behavior | 401/404/416, interruption, retry, format/content length differences |
| Playlist | create/read/update/delete run-owned playlist | duplicate names, missing IDs, partial failure, cleanup after restart |
| Favorite | star then fetch, unstar then fetch | stale cache, server rejection, cleanup |
| Scrobble | dedicated test track only | duplicate/time semantics, rejected request; never pollute real history |

Never save auth-bearing request URLs. Log endpoint names and status categories only.

## App integration cases

- cached local snapshot appears before background reconciliation;
- cached remote catalog appears without automatic destructive refresh;
- explicit scan/refresh discovers fixture changes;
- local and remote identity/grouping remain stable after relaunch;
- real download writes exact bytes, handles conflicts, cancel/requeue, and targeted indexing;
- metadata writes to disposable FLAC/MP3 are verified by an external parser and app reread;
- seek and queue advancement use real server responses;
- errors are visible and diagnostics remain privacy-safe;
- navigation/theme changes do not break service activity.

## Physical acceptance cases

- stereo and multichannel local start;
- explicit matrix success or visible quarantine/fallback;
- track boundary and queue order by ear plus diagnostics;
- remote seek target/clock and exact-end advance;
- lock-screen metadata and commands;
- background download while suspended/locked and after relaunch;
- Wi-Fi/Tailscale transition and server interruption recovery;
- playback during downloads and catalog browsing;
- thermal/battery observation for sustained scenarios.

## Failure and cleanup matrix

For every test write:

| Resource | Created by run | Cleanup action | Idempotent | Verified | Failure artifact |
|---|---|---|---|---|---|

Cleanup must only touch run-owned IDs/files/accounts. If cleanup fails, report it prominently and preserve the registry; do not broaden deletion scope to “make it clean.”
