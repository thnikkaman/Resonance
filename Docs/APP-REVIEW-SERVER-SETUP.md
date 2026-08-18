# App Review server setup — MeiKyo 鳴響 with Navidrome and Tailscale

This procedure prepares a review-only environment. Never commit the review username, password, authenticated URLs,
Tailscale keys, or private music to the repository. Enter credentials only in App Store Connect’s App Review Information
or TestFlight beta-review fields.

## Required public endpoint

Use:

`https://music.koolkidz.us`

The endpoint must be reachable from an ordinary internet connection without a Tailscale login, device approval,
MagicDNS-only resolution, VPN membership, CAPTCHA, two-factor prompt, or expiring invitation. It must present a valid
public TLS certificate and remain available throughout review.

Tailscale Serve and MagicDNS are private tailnet services and are not sufficient for Apple’s reviewers. Tailscale Funnel
can publish a local service to the public internet over HTTPS, but its current public hostname and custom-domain behavior
must be verified separately. A public reverse proxy or forwarder that terminates HTTPS for `music.koolkidz.us` and
forwards privately to Navidrome is the most predictable review arrangement.

## Recommended network topology

```text
Apple reviewer / iPhone
        |
        | HTTPS 443: music.koolkidz.com
        v
Public reverse proxy or Tailscale Funnel
        |
        | private Tailscale/LAN connection
        v
Navidrome on localhost or a private server address
```

Keep Navidrome off the public internet except through the HTTPS endpoint. If using a reverse proxy, bind Navidrome to
localhost or a private interface and allow only the proxy to reach it. Navidrome recommends running behind a reverse
proxy with SSL and limiting its listening address where practical.

## Current private upstream

The live server configuration is the source of truth: Navidrome currently listens on private LAN address
`192.168.1.7:4533`. FortiWiFi has no public VIP or WAN policy for port 4533, so the public review path remains only
the Caddy HTTPS endpoint. The private upstream is HTTP and must remain inaccessible from the public internet. This
differs from an older note that described Navidrome as binding to `0.0.0.0`; do not use that stale value for review setup.

## Navidrome review account

Create a dedicated account named something like `meikyo-review`. Do not use the administrator account.

The account should:

- Browse the full sample library.
- Stream at least stereo music and one longer audiobook-style item if those features are submitted.
- Download at least one track and one album if downloads are advertised.
- Exercise favorites, scrobbling, and playlists if those features are submitted.
- Have no administrative access, server configuration access, or access to private personal music.
- Have no CAPTCHA, forced password rotation, email confirmation, or two-factor challenge.
- Remain valid for the entire review window.

Populate the review library with music and artwork that the publisher is authorized to use for testing. Use fictional
artist, album, and account information in screenshots and review materials.

## MeiKyo settings for the reviewer

Provide these steps in App Review notes:

1. Open Settings.
2. Select the Navidrome / Subsonic backend.
3. Enter server address `music.koolkidz.us`.
4. Use HTTPS and the standard HTTPS port, or leave the port blank if the app supplies 443.
5. Use API path `/rest`.
6. Enter the review username and password supplied privately in App Store Connect.
7. Tap the connection/check control.
8. Open Streaming, play a track, open lyrics, inspect artwork, and test the submitted download and library features.

If the QR scanner is part of the review path, attach a QR image containing only the non-secret server configuration. Do
not put the password in the QR value.

## App Review notes template

Paste and complete this privately in App Store Connect:

```text
MeiKyo is a local and personal-server music player. No account is required for the local-library features.

To review the remote-library features:
1. Open Settings.
2. Select Navidrome / Subsonic.
3. Server: https://music.koolkidz.us
4. API path: /rest
5. Username: [ENTER PRIVATELY IN APP STORE CONNECT]
6. Password: [ENTER PRIVATELY IN APP STORE CONNECT]
7. Tap Check for Remote Changes, then open Streaming.

The review account is a restricted account containing only authorized sample media. It does not require Tailscale,
VPN access, CAPTCHA, or two-factor authentication. The reviewer may test streaming, lyrics, artwork lookup, favorites,
playlists, and downloads.

Support contact: [name, phone, email]
```

## External verification before submission

From a network that is not on the tailnet, verify:

- DNS resolves `music.koolkidz.us` publicly.
- HTTPS certificate validation succeeds.
- The Navidrome web endpoint does not expose administrator access.
- The client connection test works with the review account.
- Streaming and downloading work over HTTPS.
- The account still works after restarting Navidrome and the reverse proxy.
- Server logs do not contain the password or a reusable authentication token.

Disable or rotate the review account after the review window if it is no longer needed.
