#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

find Resonance -name '*.swift' -print0 | xargs -0 -n1 swiftc -frontend -swift-version 6 -parse
plutil -lint Resonance/Info.plist
plutil -lint Resonance.xcodeproj/project.pbxproj
python3 -m py_compile Tools/ResonanceServer.py

python3 - <<'PY'
from pathlib import Path
root = Path('.')
pbx = (root / 'Resonance.xcodeproj/project.pbxproj').read_text()
metadata = (root / 'Resonance/Services/MetadataReader.swift').read_text()
smart = (root / 'Resonance/Views/SmartLibraryViews.swift').read_text()
player = (root / 'Resonance/Services/PlayerController.swift').read_text()
gapless = (root / 'Resonance/Services/GaplessAudioEngine.swift').read_text()
database = (root / 'Resonance/Services/LibraryDatabase.swift').read_text()
views = (root / 'Resonance/Views/PlayerViews.swift').read_text()
remote = (root / 'Resonance/Services/RemoteLibraryStore.swift').read_text()
library_store = (root / 'Resonance/Services/LibraryStore.swift').read_text()
settings = (root / 'Resonance/Services/AppSettings.swift').read_text()
settings_view = (root / 'Resonance/Views/SettingsView.swift').read_text()
diagnostics = (root / 'Resonance/Services/ResonanceDiagnostics.swift').read_text()
error_log = (root / 'Resonance/Services/AppErrorLog.swift').read_text()
streaming = (root / 'Resonance/Views/StreamingLibraryView.swift').read_text()
library_view = (root / 'Resonance/Views/LibraryView.swift').read_text()
root_view = (root / 'Resonance/Views/RootView.swift').read_text()
plist = (root / 'Resonance/Info.plist').read_text()
now_playing = views.split('struct NowPlayingView: View {', 1)[1].split(
    'private struct NowPlayingArtworkPager', 1
)[0]

assert 'RemoteLibraryStore.swift in Sources' in pbx
assert 'StreamingLibraryView.swift in Sources' in pbx
assert 'AppErrorLog.swift in Sources' in pbx
assert pbx.count('CURRENT_PROJECT_VERSION = 59;') == 2
assert pbx.count('MARKETING_VERSION = 0.3.7.4;') == 2

# Previous current-SDK and Swift 6 fixes.
assert '?? await' not in metadata
assert '?? try await' not in metadata
assert 'content:' in smart and 'header:' in smart
assert 'track.flatMap { player.artworkData(for: $0) }' in views
assert 'Timer(timeInterval:' not in player
assert 'deinit { sqlite3_close(db) }' not in database
assert 'appendPreloaded' in gapless and 'appendRemainder' in gapless
assert 'kAudioUnitSubType_MatrixMixer' in gapless
assert 'rear left → left only' in gapless
assert 'rear right → right only' in gapless
assert 'center → both' in gapless
assert 'LFE → both' in gapless

# Alpha 3.7.1 focused playback crash hotfix.
assert 'private var remotePlayer: AVPlayer?' in player
assert 'AVPlayer(playerItem:' in player
assert 'AVQueuePlayer(items:' not in player
assert 'appendRemotePreloadedItem' not in player
assert 'remoteItemContexts' not in player
assert 'private func tearDownActiveBackend()' in player
assert 'gaplessEngine.stop(resetEngine: true)' in player
assert 'Stable single-item remote playback' in player
assert 'playbackStartupDiagnostic' in player
assert 'preferredForwardBufferDuration' in player
assert 'networkBufferStatus' in player

# Navidrome/OpenSubsonic backend and playlist management.
assert 'RemoteLibraryBackend' in settings
assert 'KeychainCredentialStore' in settings
assert 'kSecClassGenericPassword' in settings
assert 'ping.view' in remote
assert 'getAlbumList2.view' in remote
assert 'getAlbum.view' in remote
assert 'getPlaylists.view' in remote
assert 'getPlaylist.view' in remote
assert 'createPlaylist.view' in remote
assert 'updatePlaylist.view' in remote
assert 'deletePlaylist.view' in remote
assert 'getCoverArt.view' in remote
assert 'stream.view' in remote
assert 'format", value: "raw"' in remote
assert 'star.view' in remote and 'unstar.view' in remote
assert 'scrobble.view' in remote
assert 'Insecure.MD5' in remote
assert 'subsonic-response' in remote
assert 'sourceID' in remote
assert 'uniqueTracks(resolved)' in remote
assert 'resonanceNormalizedRemoteKey' in remote

# Browse parity and adaptive artist index.
assert 'VerticalArtistIndex' in library_view
assert 'resonanceArtistIndexKey' in library_view
assert 'case albumArtists' in remote
assert 'case favorites' in remote
assert 'case recentlyAdded' in remote
assert 'case recentlyPlayed' in remote
assert 'RemoteLibraryOptionsSheet' in streaming
assert 'groupCompilationArtists' in settings
assert 'streamingConnectionInfoExpanded' in settings
assert 'Group compilation-only artists' in streaming
assert 'compilationAlbumKeys' in remote
assert 'Various Artists' in remote
assert 'RemotePlaylistCollectionView' in streaming
assert 'RemotePlaylistPickerSheet' in streaming
assert 'Play Artist' in streaming and 'contrastingAccentTextColor' in streaming
assert 'Play Album' in streaming and 'Play All Albums' in streaming
assert 'VerticalArtistIndex' in streaming
assert 'RemoteAlbumCollectionView' in streaming
assert 'streaming-albums' in streaming
assert 'scrollIndicators(.hidden)' in streaming
assert 'highPriorityGesture' in library_view
assert 'alphabet.gesture.begin' in library_view
assert 'alphabet.scrollTo' in streaming
assert 'streaming.connectionInfo.changed' in streaming
assert 'isExpanded.toggle()' in streaming
assert '.accessibilityElement(children: .combine)' in streaming
assert 'navigationBarTitleDisplayMode(.inline)' in streaming
assert 'commands.nextTrackCommand.isEnabled = true' in player
assert 'commands.previousTrackCommand.isEnabled = true' in player
assert 'commands.skipForwardCommand.isEnabled = false' in player
assert 'commands.skipBackwardCommand.isEnabled = false' in player
assert '.safeAreaInset(edge: .top, spacing: 0)' in streaming
assert '.navigationBarTitleDisplayMode(.large)' in streaming
assert 'streaming.option.compilationGrouping.changed' in streaming
assert 'compilationAlbumIdentity' in remote
assert 'albumArtists(groupCompilationArtists:' in remote
assert 'RemotePlaylistCollectionView' in streaming
assert 'albumArtists: remoteArtists(' in remote
assert 'albumArtists: remoteArtists(\n                usingAlbumArtist: true,' in remote
assert 'recordDeferred' in diagnostics
assert 'playback.gapless.boundary.begin' in player
assert 'playback.gapless.preload' in player
assert 'remoteSeekInFlight' in player
assert 'remote.player.seek.completed' in player
assert 'remote.player.endFallback' in player
assert '.safeAreaInset(edge: .top, spacing: 0)' in root_view
assert 'ToolbarItemGroup(placement: .keyboard)' in root_view
assert 'MiniPlayerDock' in root_view
assert 'MiniPlayerEdgeHandle' in root_view
assert 'ScrollView' not in now_playing
assert '.padding(.bottom, 8)' in now_playing
assert '.frame(width: pageWidth, height: 260' in views
assert '.frame(width: 252, height: 252)' in views
assert 'matrixConfiguration = configureSignalPath' in gapless
assert 'try startEngineIfNeeded()' in gapless
assert 'kAudioUnitScope_Input' in gapless
assert 'kAudioUnitScope_Output' in gapless
assert 'AudioUnitElement(UInt32.max)' in gapless
assert 'var isEngineRunning: Bool' in gapless
assert 'sampleRatesMatch' in gapless
assert 'sourceSampleRate' in gapless and 'graphSampleRate' in player
assert 'playback.gapless.prepared' in player
assert 'playback.seek.begin' in player
assert 'playback.seek.completed' in player
assert 'makeSections' in streaming
assert 'Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")' in settings_view
assert 'Alpha 3.7.4 (47)' not in settings_view
assert 'markPlayed(trackID:' in root_view
assert 'ErrorReportingCoordinatorView' in root_view
assert 'collectDocumentInventory' in library_store
assert 'Task.detached(priority: .utility)' in library_store
assert 'if !forceCheck, !tracks.isEmpty { return }' in remote
assert 'scheduleNowPlayingArtworkPreparation' in player
assert 'prepareNowPlayingArtwork(data: data)' in player
artwork = (root / 'Resonance/Views/ArtworkView.swift').read_text()
assert 'LocalArtworkLoader' in artwork
assert 'CGImageSourceCreateThumbnailAtIndex' in artwork
assert 'artwork.local.thumbnail' in artwork
assert 'UIImage(data: data)' not in artwork

assert 'SecureField("Navidrome / Subsonic password"' in settings_view
assert 'Backend in use' in settings_view
assert 'NSAllowsArbitraryLoads' in plist
assert '<key>CFBundleIdentifier</key>' in plist
assert '<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>' in plist
assert '<key>CFBundleExecutable</key>' in plist
assert '<string>$(EXECUTABLE_NAME)</string>' in plist
assert '<key>CFBundleName</key>' in plist
assert '<string>$(PRODUCT_NAME)</string>' in plist
assert '<key>CFBundleShortVersionString</key>' in plist
assert '<string>$(MARKETING_VERSION)</string>' in plist
assert '<key>CFBundleVersion</key>' in plist
assert '<string>$(CURRENT_PROJECT_VERSION)</string>' in plist

# Alpha 3.7.4 build 43 playback crash isolation and device diagnostics.
diagnostics = (root / 'Resonance/Services/ResonanceDiagnostics.swift').read_text()
assert 'ResonanceDiagnostics.swift in Sources' in pbx
assert 'Documents/Resonance-Diagnostics.log' in diagnostics
assert 'playback.timer.tick.begin' in player
assert 'private nonisolated static func makeNowPlayingArtwork' in player
assert 'UIImage(data: imageData) ?? UIImage()' in player
assert 'remote.catalogCheck.cancelled' in remote
assert 'remote.catalogCache.activated' in remote
assert 'canonicalizeAlbumArtists' in remote
assert 'Showing cached catalog — remote check available in Settings' in remote
assert 'Indexing albums' in remote and 'batchSize * 8' in remote
assert 'song.artist?.nonEmpty' in remote and 'let albumArtist = song.albumArtist?.nonEmpty' in remote

# Alpha 3.6 locally reported compile fixes.
assert 'nonisolated fileprivate static func uniqueTracks' in remote
assert 'nonisolated fileprivate static func stableUUID' in remote
assert 'let starred: String?' in remote
assert 'let created: String?' in remote
assert 'let played: String?' in remote

# Alpha 3.7 streaming stability, indexing, and cache phase.
assert 'player.canInsert(item, after: tail)' not in player
assert 'activateCachedCatalogAndCheckForChanges' in remote
assert 'CachedRemoteCatalog' in remote
assert 'remote-subsonic-catalog.json' in remote
assert 'catalogSyncStatus' in remote
assert 'remote-artist-section-' in streaming
assert 'RemoteArtworkLoader' in streaming and 'ImageIO' in streaming
assert 'Showing cached catalog' in remote
assert 'frame(width: indexColumnWidth)' in library_view
assert 'coordinateSpace: .local' in library_view
assert 'y - topInset' in library_view
assert 'if first.isLetter { return String(first) }' in library_view
assert 'func resonanceArtistIndexOrder' in library_view
assert r'.id("artist-section-\(section.key)")' in library_view
assert r'.id("remote-artist-section-\(section.key)")' in streaming
assert '.frame(width: 24)' in streaming
assert 'MiniPlayerOverlay' in root_view
assert 'MiniPlayerInsets' in root_view
assert 'PlaybackCoordinatorView' in root_view
assert 'private var browseCache: BrowseCache?' in remote
assert 'trackRevision &+= 1' in remote
# Alpha 3.7.2 post-start crash diagnostics and safe MediaPlayer artwork.
assert 'playbackRuntimeDiagnostic' in player
assert 'First playback timer tick completed' in player
assert 'resonancePreparedNowPlayingImage' in player
assert 'resonanceAspectFit' not in player
assert 'showLockScreenArtwork' in settings
assert 'Reported Errors' in settings_view
assert '.foregroundStyle(.red)' in settings_view
assert 'AppReportedError' in error_log and 'Copy Errors' in settings_view
assert 'SettingsCategory' in settings_view
assert 'settings.category.changed' in settings_view
assert 'settingsAppearanceExpanded' in settings
assert 'settingsPrototypeExpanded' in settings
assert 'return String(' in remote and ').lowercased()' in remote

# Alpha 3.7.4 matrix-failure circuit breaker and deterministic index navigation.
assert 'abandonFailedPreparation' in gapless
assert 'if engine.isRunning { engine.stop() }' in gapless
assert 'gaplessDisabledForSession' in player
assert 'quarantineGaplessEngineAfterMatrixFailure' in player
assert 'Compatibility playback started successfully after matrix failure' in player
assert 'gapless disabled until relaunch' in player
assert 'gestureKey' in library_view
assert 'selectedKey = key' in library_view
assert 'RemoteArtworkLoader.shared.image' in streaming

# Coordinate mapping should select the expected first, middle, and last rows.
def mapped_index(y, top, row_height, count):
    relative = min(max(0.0, y - top), max(0.0, row_height * count - 0.001))
    return min(count - 1, max(0, int(relative // max(1.0, row_height))))

assert mapped_index(0, 8, 10, 26) == 0
assert mapped_index(8 + 12 * 10 + 5, 8, 10, 26) == 12
assert mapped_index(10_000, 8, 10, 26) == 25



print('Resonance Alpha 3.7.4 regression checks passed.')
PY
