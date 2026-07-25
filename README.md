# Resonance Alpha 3.7.4 — Playback Recovery and Artist Index Fix

Version: **0.3.7.4**  
Build: **41**

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

- The alphabet is fixed to a 32-point strip at the right edge.
- Normal vertical drags over artist names belong only to the list or grid.
- Touching or dragging inside the right-edge strip maps the finger position in the index container's coordinate space.
- Every available section has a stable container ID used by `ScrollViewReader`.
- A large letter bubble appears to the left of the index while touching or dragging.
- Releasing over a letter keeps the bubble briefly visible and leaves the list at that section.
- A new touch on the same letter dispatches the navigation again.
- Streaming back navigation is restricted to a 24-point left-edge strip.

## Streaming performance retained

Remote cover art is downloaded and downsampled outside the main actor into a bounded, size-specific thumbnail cache. Playback code does not share this path.

## Validation performed here

- Every Swift source passed Swift 6 syntax parsing.
- `Info.plist` and the Xcode project passed property-list validation.
- The regression suite checked the matrix circuit breaker, safe engine shutdown, stable section IDs, index coordinate mapping, left-edge gesture isolation, prior compile fixes, and remote single-item playback.
- The companion server passed Python compilation.
- The final ZIP passed archive-integrity validation.

This environment does not contain Xcode or an Apple SDK, so a signed current-SDK compile and definitive playback/UI validation must be performed on the Mac and physical iPhone.
