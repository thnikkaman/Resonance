# App Store Connect Privacy Questionnaire — MeiKyo 鳴響 Draft

This is a working answer sheet for the current source. It is not a substitute for confirming the data-retention terms of
the configured Navidrome server and every external provider. Apple’s definition of “collect” turns on whether data is
transmitted off-device and retained or accessible beyond what is needed to service the request.

## Current network destinations

| Destination | Current purpose | Data sent by MeiKyo |
| --- | --- | --- |
| User-configured Navidrome/Subsonic/OpenSubsonic server, such as `music.koolkidz.us` | Authentication, catalog, playback, downloads, favorites, scrobbling, playlists | Server address, username, salted authentication token and salt, track/album/playlist identifiers, requested stream or artwork URLs, and feature requests |
| User-configured Resonance Manifest server | Catalog, playback, downloads, and artwork | Server address, catalog/track requests, requested stream and artwork URLs |
| User-configured HTTPS lyrics provider | Optional lyrics lookup | Track title, artist, album, rounded duration, and any configured request fields |
| `musicbrainz.org` | Optional artist/album artwork metadata lookup | Artist and album metadata used to form searches |
| `coverartarchive.org` | Optional artwork retrieval | MusicBrainz release or artwork identifiers and image requests |
| `music.koolkidz.us/resonance/telemetry/events` | Optional visualizer performance diagnostics | Stable event ID, bundled preset ID, ProjectM label, app build, iOS major version, FPS, estimated frame gap, low-FPS reason, and event time |

The app also retrieves remote artwork URLs supplied by the configured server or artwork providers. The app does not send
local audio files to the lyrics or artwork services.

## Provider-use requirements verified from current documentation

### User-configured lyrics provider

MeiKyo does not include or select a lyrics provider by default. The user may configure a provider’s HTTPS endpoint,
request mapping, response mapping, and optional authorization when the provider supports the documented GET/POST JSON,
plain-text, or LRC interface. The configured provider receives the fields selected by the user, such as title, artist,
album, and rounded duration, and controls its own terms, rights, and retention.

An endpoint’s technical accessibility does not by itself grant a copyright license for displaying or reproducing lyric
text. Confirm the provider’s terms and obtain any commercial lyric-display rights required before a commercial release.

### MusicBrainz API

MusicBrainz states in its [API documentation](https://musicbrainz.org/doc/MusicBrainz_API) that its web service is free
for non-commercial use, while commercial use should use its commercial plans or contact MetaBrainz. No API key is
currently required, but each request must include a meaningful application
`User-Agent`, and each client application must not exceed one API call per second. MeiKyo now serializes its
MusicBrainz calls and identifies itself as `MeiKyo/2.1` with the project URL.

The [MusicBrainz database license](https://musicbrainz.org/doc/About/Data_License) is separate from API access: core
data is CC0, while supplementary data is CC BY-NC-SA 3.0. Confirm which data the app relies on and obtain a
commercial-use arrangement if the App Store publisher’s use is commercial. The [rate-limit rules](https://musicbrainz.org/doc/MusicBrainz_API/Rate_Limiting)
also require a meaningful User-Agent and no more than one request per second per client application.

### Cover Art Archive

Cover Art Archive requests must go through `coverartarchive.org`; its [API documentation](https://musicbrainz.org/doc/Cover_Art_Archive/API)
currently describes the JSON and image endpoints and no API-key requirement. Its [policy](https://musicbrainz.org/doc/Cover_Art_Archive)
says the collection is public but also says to use images at the user’s own risk and respect artist and label rights.
This is not a blanket copyright license for album artwork. Confirm the intended commercial use or restrict production
artwork to content supplied by the user’s authorized music server/local library.

## Recommended answers, assuming the stated deployment

These answers assume there is no analytics, advertising, crash-reporting SDK, ATT usage, or device-ID collection. They
also assume the publisher-operated telemetry endpoint at `music.koolkidz.us` stores the opt-in performance events for
diagnostic review, does not associate them with a MeiKyo account, and does not retain connection metadata longer
than needed for abuse prevention and service operation. Confirm those server practices before submitting.

| App Store Connect question | Provisional answer | Condition |
| --- | --- | --- |
| Does the app track users? | **No** | Keep this answer unless an analytics, advertising, attribution, or cross-app identity service is added. |
| Does the app use data for third-party advertising? | **No** | No advertising SDK or advertising network is present in the current source audit. |
| Does the app use data for developer advertising or marketing? | **No** | Do not use library or playback data for marketing. |
| Does the app use analytics? | **No** | The opt-in banishment reports are for app-functionality diagnostics, not user-behavior analytics; change this if the server starts measuring user behavior or audience characteristics. |
| Does the app collect precise/coarse location, contacts, health, financial, phone, email, or device ID? | **No** | The current source audit found no such API or data flow. |
| Does the app collect camera images? | **No** | The camera is used transiently to decode a QR value; no image is retained or uploaded. |
| Does the app collect selected photos? | **No**, if they remain local | The app uses the system picker and stores selected artwork/theme images locally. |
| Does the app collect local audio? | **No**, if it remains on-device | Local files are not uploaded by MeiKyo. A configured server may separately retain its own library and request logs. |
| Does the app collect diagnostics or performance data? | **Yes — Performance Data** | The user can opt in to send automatic low-framerate banishment events to the publisher-operated endpoint for App Functionality. Mark it not linked to the user and not used for tracking only if the server does not associate or retain identifying metadata with the events. |
| Does the app collect a User ID? | **Conditional: Yes if the publisher operates and retains the remote account** | The Navidrome username is sent to the configured server. If the publisher does not operate or retain that account data, confirm Apple’s treatment before selecting No. |
| Does the app collect Other User Content? | **Conditional: Yes if the publisher’s server retains user library/account content** | This can include remote library metadata, playlists, favorites, or scrobble information retained by the server. |
| Does the app collect Search History? | **Usually No** | Lyrics/artwork lookups are metadata requests generated for the current track, not a general user search history. Confirm if future UI adds persistent search history. |

## The important server-owner branch

If `music.koolkidz.us` is operated by the publisher and stores the review account, users, playlists, favorites, scrobbles,
or request logs, conservatively disclose the relevant **User ID** and **Other User Content** categories as used for **App
Functionality**, linked to the user where the server associates them with an account, and not used for tracking.

If each user supplies an independent server and the publisher does not operate, retain, or access that server’s data,
the app may not be collecting those categories as the publisher under Apple’s definition. The privacy policy should still
explain that the user-selected server and external providers receive the requests and have their own retention practices.

Do not select “Data Not Collected” until this server-owner question and the provider-retention terms have been confirmed.
