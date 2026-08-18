# MeiKyo 鳴響 Privacy Policy — Draft

**Effective date:** 2026-08-08  
**App:** MeiKyo 鳴響 for iPhone  
**Publisher:** `[replace with the legal publisher name]`  
**Privacy contact:** `[replace with a monitored support email address]`  
**Support URL:** `[replace with the public support URL]`

This is a publication draft, not legal advice. Replace the bracketed fields, confirm the retention practices of every
external service listed below, and publish the final policy at a stable HTTPS URL before submitting MeiKyo to the
App Store.

## What MeiKyo does

MeiKyo is an iPhone music player for local audio files and music libraries provided by a server configured by the
user. It can browse, stream, download, edit metadata for supported local files, display lyrics, display artwork, and
render audio visualizations.

## Information MeiKyo processes

### Local music and library information

When the user imports or downloads music, MeiKyo processes audio files, filenames, embedded tags, album artwork,
playlists, favorites, playback history, audiobook positions, and other library metadata on the iPhone. This information
is stored inside the app’s container. It is not sent to the MeiKyo publisher by default.

The user may choose to make files in the app’s shared Documents folder visible to Finder or the Files app. This is an
explicit local file-management feature. MeiKyo does not use that feature to access files outside its app container.

### Configured music server

The user may configure a Navidrome, Subsonic, OpenSubsonic, or Resonance Manifest server. MeiKyo sends the server
address, selected backend, username, and the authentication information needed by that backend. The password is stored
in the iOS Keychain. For Subsonic-compatible servers, MeiKyo uses the protocol’s salted authentication token rather
than placing the plain password in the request URL.

The configured server receives requests needed to authenticate, browse, play, download, favorite, scrobble, edit
playlists, and perform other enabled server operations. The server operator controls that server’s logs, account data,
library data, and retention practices. Users should only connect to servers they trust and should prefer HTTPS.

### Lyrics lookup

MeiKyo does not include or select a lyrics provider by default. If the user configures an HTTPS lyrics provider and
requests a match, MeiKyo sends the fields selected in that provider profile, commonly the track title, artist, album,
and rounded duration. MeiKyo receives the returned lyrics in memory for the current visualization and does not send
the audio file to the provider. The configured provider controls its own terms, rights, network metadata, and retention.

### Optional visualizer diagnostics

If the user enables **Share anonymous visualizer diagnostics** in Settings → Visualizer, MeiKyo sends automatic
low-framerate banishment events to `https://music.koolkidz.us/resonance/telemetry/events`. Each event contains a stable
event ID, bundled preset ID, ProjectM label, app build, iOS major version, measured FPS, an estimated frame gap, the
low-framerate reason, and the event time. It does not contain track names, lyrics, credentials, configured server URLs,
account IDs, device IDs, or audio. Manual banishments are not sent.

The setting is off by default. Events are queued only in bounded memory and network work is performed away from the
visualizer renderer, main display callback, playback, and controls. The publisher uses the events to identify and
prioritize visualizations for later performance work. The current service requires a private bearer token supplied to the
release build and reports that it stores no IP address, forwarded headers, account ID, track data, lyrics, URLs, or
credentials. The publisher must keep those practices current; normal HTTPS infrastructure may still process transient
connection metadata needed to deliver a request.

### Artwork lookup

When the user searches for artwork, MeiKyo sends relevant artist and album metadata to the artwork
providers used by the current build: MusicBrainz. Matching artwork may be retrieved from the Cover Art Archive or from
the configured music server. MeiKyo does not upload the user’s audio files to these providers.

Provider names, endpoints, and terms may change. The publisher will update this policy before shipping a build that
adds or removes a provider.

### Camera and selected photos

MeiKyo requests camera access only when the user opens the QR scanner for a server address. The QR image is processed
to obtain configuration text and is not intentionally retained by MeiKyo.

The user may select an image through Apple’s system photo picker for artwork or a custom theme. The selected image is
processed locally and is not uploaded by MeiKyo to the publisher.

### Diagnostics

MeiKyo maintains a bounded, local diagnostics log for playback, catalog, download, UI, and visualization troubleshooting.
The intended diagnostic records contain event names, timing, sizes, and result categories rather than track names,
audio, passwords, authenticated URLs, or private music. The user controls the optional detailed diagnostics mode and
can delete the local diagnostics file. If the user voluntarily exports or sends a diagnostic file, the recipient can
process that file as part of support.

The current build does not include advertising, behavioral analytics, crash-reporting SDKs, or cross-app tracking. The
optional visualizer reports are limited to technical app-functionality diagnostics and are not used to identify or track
users. This statement must be updated if any such service is added.

## How information is used

MeiKyo uses the information above only to provide app functionality: authenticate to the selected server, browse and
play the user’s library, download selected files, edit supported local metadata, find optional lyrics or artwork, render
the interface, display the optional local FPS counter, and diagnose failures when the user chooses to provide
diagnostics.

MeiKyo does not sell personal information, use it for targeted advertising, or use it to track people across apps or
websites.

## Storage and deletion

The user can remove local music, metadata, artwork overrides, cached catalogs, credentials, and diagnostics through the
app’s available controls or by deleting the app. Data retained by a configured music server must be deleted through that
server or its administrator. External lyrics and artwork providers control their own request logs and retention under
their policies.

The publisher does not receive local library content or server credentials unless the user voluntarily provides them for
support. A user may contact the publisher at the privacy contact above with a privacy question or deletion request for
information that the publisher actually controls.

## Security

MeiKyo uses the iOS Keychain for the configured server password and uses HTTPS whenever the configured server supports
it. Users should not enter credentials into an untrusted server address or use plain HTTP across an untrusted network.

No security measure is perfect. Users are responsible for securing their server, Tailscale account, DNS, reverse proxy,
Navidrome account, and network.

## Children

MeiKyo is not directed to children and does not knowingly collect personal information from children.

## Changes to this policy

The publisher may update this policy when MeiKyo’s features, providers, or data practices change. The effective date
at the top of this page will identify the current version.

## Contact

For privacy questions, contact `[replace with a monitored support email address]`.
