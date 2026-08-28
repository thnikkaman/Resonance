# Alpha 3.7.4 Playback and Artist Index Validation

## Observed Problem

- User-visible symptom: playback can terminate after local startup; artist-index touches do not navigate; streaming scrolling conflicts with gestures.
- Reproduction evidence: Settings reported `Local gapless engine failed: The explicit surround downmix matrix could not be configured (OSStatus -10867)` alongside startup/timer diagnostics.
- Affected layers: AVAudioEngine/AudioToolbox matrix setup, playback backend state, SwiftUI scroll targeting, gesture ownership, remote artwork decoding.

## Baseline

| Signal | Scenario | Before | Source |
|---|---|---:|---|
| Matrix configuration | Local multichannel playback | OSStatus -10867 | App error log |
| Recovery state | After matrix failure | Failed graph could be reset/reused | Source inspection |
| Index target | Touch or drag alphabet | No visible section jump | Device report |
| Gesture ownership | Vertical drag in Streaming | Full-screen back gesture competed | Source inspection |

No fabricated timing values are recorded. Physical-device hitch and startup measurements remain required.

## Evidence

- Matrix configuration throws after the player node and matrix node have already been connected.
- The previous catch path called `reset()` on that partially configured engine and then retained it for later backend changes.
- The alphabet gesture was attached to a positioned child while the mapping assumed a different vertical coordinate origin.
- Section IDs were attached to lazy header text rather than the complete section container.
- Streaming attached a drag recognizer to the entire screen.

## Opportunity Matrix

| Change | Impact | Confidence | Effort | Score |
|---|---:|---:|---:|---:|
| Quarantine failed matrix graph and use compatibility playback | 5 | 5 | 2 | 12.5 |
| Full-height right-edge hit testing with stable section IDs | 5 | 5 | 2 | 12.5 |
| Restrict back swipe to left edge | 4 | 5 | 1 | 20.0 |
| Off-main bounded artwork thumbnails | 4 | 4 | 2 | 8.0 |

## Behavior Proof

- Audible PCM or file bytes preserved: source files are unchanged; the explicit matrix remains preferred when it configures successfully. Compatibility fallback uses the system player only after matrix failure.
- Playback position and seek semantics preserved: existing local compatibility and remote seek paths are unchanged.
- Queue and gapless ordering preserved: gapless behavior is unchanged on successful engine setup; after matrix failure, gapless is intentionally disabled for that session to preserve reliable playback.
- Metadata, artwork, favorites, playlists, and history preserved: no database or identity changes.
- Now Playing and remote-command behavior preserved: existing MediaPlayer publication and command routing are unchanged.
- Authentication and privacy preserved: credentials and URLs are not added to diagnostics.
- Failure behavior improved: OSStatus -10867 is visible in red, the bad graph is quarantined, and fallback success has a distinct startup diagnostic.

## Implementation

- Playback lever: circuit-break the local gapless backend after a matrix configuration failure.
- Navigation lever: map touch coordinates in a fixed full-height right-edge container and scroll to stable section-container IDs.
- Performance lever: retain the off-main, bounded remote-artwork thumbnail loader.
- Files changed:
  - `Resonance/Services/GaplessAudioEngine.swift`
  - `Resonance/Services/PlayerController.swift`
  - `Resonance/Views/LibraryView.swift`
  - `Resonance/Views/StreamingLibraryView.swift`
  - project version, regression checks, and documentation
- Rollback: restore the corresponding files from Alpha 3.7.2.

## Physical-device verification

1. Clear **Reported Errors** in Settings.
2. Play the multichannel file that previously generated OSStatus -10867.
3. Verify the error is shown in red and the startup stage becomes `Compatibility playback started successfully after matrix failure`.
4. Verify the app remains alive for at least one complete track and after selecting a second local track.
5. Select and play a Navidrome track after the matrix failure; verify remote playback starts without touching the quarantined local engine.
6. Relaunch Resonance and play a stereo local track; verify the normal gapless backend can start.
7. In Library Artists, vertically scroll over artist names; verify normal inertial scrolling.
8. Tap a visible index letter; verify the corresponding section reaches the top.
9. Drag through several letters; verify the list follows and the large bubble updates.
10. Release on a letter; verify the final section remains selected.
11. Repeat steps 7–10 in Streaming Artists.
12. Verify the alphabet remains pinned to the right edge in compact, large, and grid layouts.

## Pass conditions

- No process termination after OSStatus -10867.
- The failed matrix graph is not reset or reused during the session.
- Compatibility playback and subsequent remote playback both remain operational.
- Artist-name drags scroll normally.
- Right-edge taps and drags navigate to the selected available section.
- The large letter bubble is visible during interaction.
- Streaming scrolling has no full-screen gesture conflict.
