# Resonance Alpha 3.7.4 — Compilation Artist Grouping

Version: **0.3.7.4**  
Build: **45**

Install directly over Alpha 3.7.3 with the same bundle identifier and signing team. Do not delete the installed app first, because uninstalling removes local library state, playlists, metadata overrides, credentials, and the cached remote catalog.

## Observed problems

- Local playback reported: `The explicit surround downmix matrix could not be configured (OSStatus -10867)` and the process could still terminate after startup diagnostics were written.
- Streaming and Library alphabet touches did not reliably scroll to the selected artist section.
- The streaming screen's full-screen back-swipe recognizer competed with normal vertical scrolling.
- Remote artwork decoding could occupy the main actor while the streaming catalog was scrolling.

## Playback recovery

The explicit 5.1 matrix remains the first-choice path. If Matrix Mixer configuration fails:

1. Resonance records the complete matrix error in the red **Reported Errors** section.
2. The partially configured `AVAudioEngine` is stopped, disconnected, and quarantined.
3. Resonance does not reset, reuse, or deallocate that failed graph during playback switching.
4. Gapless playback is disabled for the remainder of the current app session.
5. The selected file starts through the stable `AVAudioPlayer` compatibility backend.
6. Later local tracks use the compatibility backend directly until Resonance is relaunched.
7. Remote playback continues through the stable single-item `AVPlayer` path and never touches the quarantined local graph.

A relaunch creates a fresh gapless engine and allows the explicit matrix to be attempted again.

## Artist alphabet navigation

- The right-edge index orders numeric names first, then A–Z Roman names, then each available leading Kanji or other Unicode letter; punctuation-only names remain in a final `#` section.
- Normal vertical drags over artist names belong only to the list or grid.
- Touching or dragging inside the right-edge strip maps the finger position in the index container's coordinate space.
- Every available section has a stable container ID used by `ScrollViewReader`.
- A large letter bubble appears to the left of the index while touching or dragging.
- Releasing over a letter keeps the bubble briefly visible and leaves the list at that section.
- A new touch on the same letter dispatches the navigation again.
- Streaming back navigation is restricted to a 24-point left-edge strip.

## Streaming performance

- High-frequency playback progress updates are isolated to the mini-player and Now Playing views instead of invalidating the root tab tree.
- Remote catalog filtering, album grouping, and artist grouping are cached by track revision, search text, and sort direction.
- Remote cover art is downloaded and downsampled outside the main actor into a bounded, size-specific thumbnail cache. Playback code does not share this path.

## Compilation-only artist grouping

The Streaming Library options include **Group compilation-only artists**. When enabled, artists whose remote tracks appear only on compilation or Various Artists albums are grouped under one synthetic artist named **Various Artists**. Artists who also have regular albums remain visible separately, with only their compilation tracks moved into the grouped entry. The setting is stored locally and is off by default to preserve the existing view until enabled.

## Validation performed here

- Every Swift source passed Swift 6 syntax parsing.
- `Info.plist` and the Xcode project passed property-list validation.
- The regression suite checked the matrix circuit breaker, safe engine shutdown, stable section IDs, index coordinate mapping, left-edge gesture isolation, prior compile fixes, and remote single-item playback.
- The companion server passed Python compilation.
- The final ZIP passed archive-integrity validation.

Alpha 3.7.4 build 45 additionally passed the supplied simulator and generic-device preflight builds with warnings treated as errors, followed by a signed physical-device build.

## Device diagnostics

Build 44 writes a bounded, privacy-safe playback trace to:

`Documents/Resonance-Diagnostics.log`

The trace records lifecycle, playback-stage, timer, Now Playing, and remote-catalog cancellation boundaries. It does not record track names, local paths, server URLs, credentials, private music, or audio data. After manually reproducing a problem on the iPhone, the file can be copied from the app container with:

```sh
xcrun devicectl device copy from \
  --device 00008150-001144383612401C \
  --domain-type appDataContainer \
  --domain-identifier com.example.ResonancePrototype \
  --source Documents/Resonance-Diagnostics.log \
  --destination /Users/brian/Resonance/diagnostics/Resonance-Diagnostics.log
```
