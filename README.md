# Resonance Alpha 3.7.4 — Playback and Streaming Stabilization

Version: **0.3.7.4**  
Build: **53**

Install directly over Alpha 3.7.3 with the same bundle identifier and signing team. Do not delete the installed app first, because uninstalling removes local library state, playlists, metadata overrides, credentials, and the cached remote catalog.

## Observed problems

- Local playback reported: `The explicit surround downmix matrix could not be configured (OSStatus -10867)` and the process could still terminate after startup diagnostics were written.
- Streaming and Library alphabet touches did not reliably scroll to the selected artist section.
- The streaming screen's full-screen back-swipe recognizer competed with normal vertical scrolling.
- Remote artwork decoding could occupy the main actor while the streaming catalog was scrolling.
- The streaming connection header consumed browse space and could visually compete with the active grouping title during pull-down.
- The native right-side scroll indicator competed with the custom alphabet index.
- Streaming artist and album alphabet gestures did not always claim the intended touch strip or complete the section jump.
- The streaming header could disappear visually, cached catalog loading competed with the first browse render, and inconsistent Subsonic display album-artist values split one artist into multiple entries.
- The Now Playing action row could be laid out underneath the persistent tab bar, and the mini-player could cover Streaming and Settings content.
- Remote seeking could be overwritten by the playback timer, and a remote item reaching its end did not always advance the queue.
- The explicit matrix was configured before the Matrix Mixer audio unit had started, producing `kAudioUnitErr_Uninitialized` (`-10867`) on some 5.1 files.

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
- The native scroll indicator is hidden in streaming collections; normal scrolling belongs to the main artwork/text area,
  while the right strip belongs to the alphabet index.
- Albums use the same alphabet index as artists, based on album title.

## Streaming connection panel

The server connection information is now a persisted disclosure panel. Collapse it from the streaming tab to reclaim
vertical space for artists and albums. The active grouping remains visible in the compact panel label, and the
streaming navigation title stays inline so “Album Artists” does not overlay the connection panel during pull-down.

## Streaming performance

- High-frequency playback progress updates are isolated to the mini-player and Now Playing views instead of invalidating the root tab tree.
- Remote catalog filtering, album grouping, and artist grouping are cached by track revision, search text, and sort direction.
- Remote cover art is downloaded and downsampled outside the main actor into a bounded, size-specific thumbnail cache. Playback code does not share this path.
- A cached Subsonic catalog is activated immediately and automatic server checks are deferred until **Check for Remote Changes** is selected in Settings. This keeps the cached browse surface responsive while the server is unavailable or slow.
- Album-artist values are canonicalized per artist/album when Subsonic exposes display composites such as `Tool • Unknown Artist`; the most common clean track-artist spelling is retained.

## Settings categories

Each top-level Settings category is independently collapsible. Its expanded or collapsed state is stored locally and restored on the next launch, so the page can stay focused on the areas currently being tested.

## Compilation-only artist grouping

The Streaming Library options include **Group compilation-only artists**. When enabled, artists whose remote tracks appear only on compilation or Various Artists albums are grouped under one synthetic artist named **Various Artists**. Artists who also have regular albums remain visible separately, with only their compilation tracks moved into the grouped entry. The setting is stored locally and is off by default to preserve the existing view until enabled.

## Validation performed here

- Every Swift source passed Swift 6 syntax parsing.
- `Info.plist` and the Xcode project passed property-list validation.
- The regression suite checked the matrix circuit breaker, safe engine shutdown, stable section IDs, index coordinate mapping, left-edge gesture isolation, prior compile fixes, and remote single-item playback.
- The companion server passed Python compilation.
- The final ZIP passed archive-integrity validation.

Alpha 3.7.4 build 51 keeps the Streaming connection header visible, gives the navigation-bar principal title enough space by moving playlist navigation into a compact menu, prioritizes Lock Screen previous/next track commands while retaining in-app 15-second seeking, groups compilation tracks in both Artists and Album Artists views using album identity independent of inconsistent album-artist tags, and reports the installed bundle version/build dynamically in Settings. The system-owned Lock Screen audio-output control remains a platform limitation; Resonance does not expose an app-owned route picker.

Alpha 3.7.4 build 52 defers non-critical catalog and UI diagnostics writes so screen transitions, Streaming scrolling, and alphabet gestures do not synchronously block the main actor. It also passes the computed compilation-album set into Album Artists browsing and adds privacy-safe synchronous boundary/preload diagnostics for reproducing the reported local and streaming gapless failures. The remote backend remains the deliberately stable single-item `AVPlayer` path pending a separate gapless streaming design decision.

Alpha 3.7.4 build 53 removes the Now Playing scroll container, compacts the fixed layout and artwork so Browse Library and Stop stay above the tab bar, and adds a keyboard Done action at the root. The mini-player can be swiped to the top, bottom, or either side; side docking leaves a small edge handle that can be swiped inward to restore it. Remote seeking now stays stable until AVPlayer confirms the seek, remote end detection has a guarded fallback for advancing the queue, and the explicit 5.1 matrix is configured after the engine starts. Remote artist and album index sections are also cached to reduce repeated SwiftUI layout work during long sessions. The AirPlay/output control visible in iOS Control Center remains system-owned; Resonance has no app-owned output picker.

## Next major phase

- Complete physical-device Lock Screen acceptance: previous/next must be the primary transport controls, in-app 15-second seek must remain available, and the system-owned output control must be documented and investigated only through supported Now Playing/MediaPlayer APIs.
- Complete Streaming navigation-chrome acceptance: the white **Streaming Library** title must remain visible like the **Library** and **Settings** titles while the connection panel expands, collapses, and the catalog scrolls.
- Complete compilation grouping acceptance in the **Artists** and **Album Artists** views with mixed album-artist metadata, including albums such as *Trigun: The First Donuts*; verify that regular artist catalogs remain separate and that each compilation appears once under **Various Artists**.
- Complete build 53 physical-device acceptance: fixed Now Playing layout, mini-player top/bottom/side docking and restore, keyboard dismissal, local stereo/5.1 gapless, remote queue advance, and accurate remote seeking.
- Re-run the cached-catalog, manual-change-check, artwork, settings-category, Streaming title, grouping, and long-idle performance checks after these runtime fixes.
- Profile the deferred-diagnostics build on the physical device while switching tabs, scrolling Streaming, dragging the alphabet, and leaving playback stopped; inspect the diagnostics and system crash logs after any sluggishness or lockup. Complete local gapless acceptance and decide whether remote gapless can be implemented without regressing the single-item playback crash shield.

## Device diagnostics

Build 46 writes a bounded, privacy-safe playback and streaming interaction trace to:

`Documents/Resonance-Diagnostics.log`

The trace records lifecycle, playback-stage, timer, Now Playing, remote-catalog cancellation boundaries, connection-panel
state, selected browse grouping/layout, and alphabet gesture/section-jump events. It does not record track names, local
paths, server URLs, credentials, private music, or audio data. After manually reproducing a problem on the iPhone, the
file can be copied from the app container with:

```sh
xcrun devicectl device copy from \
  --device 00008150-001144383612401C \
  --domain-type appDataContainer \
  --domain-identifier com.example.ResonancePrototype \
  --source Documents/Resonance-Diagnostics.log \
  --destination /Users/brian/Resonance/diagnostics/Resonance-Diagnostics.log
```
