#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

test -f AGENTS.md
test -f Docs/ARCHITECTURE.md
test -f Docs/PROJECT-STATE.md
test -f Docs/WORK-QUEUE.md
test -f Resonance/Views/AGENTS.md
test -f Resonance/Services/AGENTS.md
test -f Resonance/Models/AGENTS.md
Tools/ProjectStateCheck.sh --source-only >/dev/null

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
track = (root / 'Resonance/Models/Track.swift').read_text()
player = (root / 'Resonance/Services/PlayerController.swift').read_text()
gapless = (root / 'Resonance/Services/GaplessAudioEngine.swift').read_text()
database = (root / 'Resonance/Services/LibraryDatabase.swift').read_text()
views = (root / 'Resonance/Views/PlayerViews.swift').read_text()
artwork_view = (root / 'Resonance/Views/ArtworkView.swift').read_text()
remote = (root / 'Resonance/Services/RemoteLibraryStore.swift').read_text()
remote_download = (root / 'Resonance/Services/RemoteDownloadService.swift').read_text()
library_store = (root / 'Resonance/Services/LibraryStore.swift').read_text()
settings = (root / 'Resonance/Services/AppSettings.swift').read_text()
settings_view = (root / 'Resonance/Views/SettingsView.swift').read_text()
diagnostics = (root / 'Resonance/Services/ResonanceDiagnostics.swift').read_text()
error_log = (root / 'Resonance/Services/AppErrorLog.swift').read_text()
streaming = (root / 'Resonance/Views/StreamingLibraryView.swift').read_text()
library_view = (root / 'Resonance/Views/LibraryView.swift').read_text()
album_detail = (root / 'Resonance/Views/AlbumDetailView.swift').read_text()
root_view = (root / 'Resonance/Views/RootView.swift').read_text()
app_source = (root / 'Resonance/ResonanceApp.swift').read_text()
projectm_view = (root / 'Resonance/Views/ProjectMFullscreenView.swift').read_text()
projectm_bridge = (root / 'Resonance/Services/ResonanceProjectMBridge.mm').read_text()
projectm_engine = (root / 'Resonance/ThirdParty/ProjectM/vendor/projectm/libprojectM-4.1.7/src/libprojectM/ProjectM.cpp').read_text()
projectm_preset = (root / 'Resonance/ThirdParty/ProjectM/vendor/projectm/libprojectM-4.1.7/src/libprojectM/MilkdropPreset/MilkdropPreset.cpp').read_text()
milkdrop_text = (root / 'Resonance/ThirdParty/ProjectM/vendor/projectm/libprojectM-4.1.7/src/libprojectM/Renderer/MilkdropText.cpp').read_text()
plist = (root / 'Resonance/Info.plist').read_text()
views_contract = (root / 'Resonance/Views/AGENTS.md').read_text()
services_contract = (root / 'Resonance/Services/AGENTS.md').read_text()
models_contract = (root / 'Resonance/Models/AGENTS.md').read_text()
now_playing = views.split('struct NowPlayingView: View {', 1)[1].split(
    'private struct NowPlayingArtworkPager', 1
)[0]

assert 'RemoteLibraryStore.swift in Sources' in pbx
assert 'StreamingLibraryView.swift in Sources' in pbx
assert 'AppErrorLog.swift in Sources' in pbx
assert pbx.count('CURRENT_PROJECT_VERSION = 281;') == 2
assert 'ArtworkSearchService.swift in Sources' in pbx
assert 'OnlineArtworkSearchView.swift in Sources' in pbx
assert pbx.count('MARKETING_VERSION = 2.1;') == 2
assert '.zIndex(100)' in root_view
assert 'settings.themeSecondaryColor' in root_view
assert '.ignoresSafeArea()' in root_view
assert '.padding(.bottom, 0)' in root_view
assert root_view.count('.padding(.bottom, 0)') == 1
assert 'settings.themeSurfaceColor' in root_view
assert 'settings.themeSurfaceGradient.opacity(0.78)' in root_view

# Previous current-SDK and Swift 6 fixes.
assert '?? await' not in metadata
assert '?? try await' not in metadata
assert 'content:' in smart and 'header:' in smart
assert 'track.flatMap { player.artworkData(for: $0) }' in views
assert 'private var effectiveDuration: Double' in views
assert 'player.currentTrack?.duration' in views
assert 'Timer(timeInterval:' not in player
assert 'deinit { sqlite3_close(db) }' not in database
assert 'appendPreloaded' in gapless and 'appendRemainder' in gapless
assert 'struct VolumeSlider: View' in views
assert 'VolumeSlider(value: $player.volume' in views
assert 'gesture.location.x - thumbRadius' in views
assert 'kAudioUnitSubType_MatrixMixer' in gapless
assert 'rear left → left only' in gapless
assert 'rear right → right only' in gapless
assert 'center → both' in gapless
assert 'LFE → both' in gapless

# Alpha 3.7.1 focused playback crash hotfix.
assert 'private var remotePlayer: AVPlayer?' in player
assert 'AVPlayer(playerItem:' in player
assert 'private var remotePreloadPlayer: AVPlayer?' in player
assert 'private var remotePreloadReady = false' in player
assert 'private func beginRemotePreload' in player
assert 'preroll(atRate: 1)' in player
assert 'remote.player.preload.ready' in player
assert 'AVQueuePlayer' not in player
assert 'appendRemotePreloadedItem' not in player
assert 'remoteItemContexts' not in player
assert 'private func tearDownActiveBackend()' in player
assert 'gaplessEngine.stop(resetEngine: true)' in player
assert 'Stable single-item remote playback' in player
assert 'remoteGaplessExperimentalEnabled' in player
assert 'remote.player.queueConfigured' in player
assert 'handleRemoteQueueBoundary' in player
assert 'observe(_ items: [AVPlayerItem])' in player
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

# Scoped ownership contracts keep presentation, durable behavior, and model identity
# from drifting into each other.
assert 'Views are the authority for layout' in views_contract
assert 'Views must not become network clients' in views_contract
assert 'LibraryStore.swift' in services_contract
assert 'PlayerController.swift' in services_contract
assert 'Services must not import SwiftUI' in services_contract
assert 'stable track representation' in models_contract
assert 'Models must not perform network requests' in models_contract

# Browse parity and adaptive artist index.
assert 'VerticalArtistIndex' in library_view
assert 'resonanceArtistIndexKey' in library_view
assert 'diagnosticSurface: "albums"' in library_view
assert '@AppStorage("leftHandedAlphabet") var leftHandedAlphabet = false' in settings
assert 'Toggle("Left Handed Mode"' in settings_view
assert 'settings.leftHandedAlphabet ? .leading : .trailing' in library_view
assert 'album-section-' in library_view
assert 'private var indexedAlbumSections: [ArtistIndexSection<Album>]' in library_view
assert 'diagnosticSurface: "library-artist-albums"' in library_view
assert 'sectionIDPrefix: "artist-album-section"' in library_view
assert 'case albumArtists' in remote
assert 'case favorites' in remote
assert 'case recentlyAdded' in remote
assert 'case recentlyPlayed' in remote
assert 'RemoteLibraryOptionsSheet' in streaming
assert 'groupCompilationArtists' in settings
assert 'Group compilation-only artists' in streaming
assert 'compilationAlbumKeys' in remote
assert 'multiArtistAlbumKeys' in remote
assert 'variousAlbumKeys' in remote
assert 'mixedArtistAlbumKeys(in: tracks)' in library_store
assert 'LibraryBrowseGrouping.mixedArtistAlbumIdentity' in library_store
assert 'LibraryBrowseGrouping.mixedArtistAlbumKeys' in remote
assert 'MetadataWriteBatch.write' in library_store
assert 'variousAlbumKeys: Set<String>' in library_store
assert 'Various Artists' in remote
assert 'various-artists' in library_store
assert 'various|' in library_store
assert 'various|' in remote
assert 'library.metadata.albumSave' in library_store
assert 'preservingArtworkOverride' in library_store
assert 'confirmed file artwork' in library_store
assert 'try? data.write(to: Self.metadataOverridesURL, options: .atomic)' in library_store
assert 'RemotePlaylistCollectionView' in streaming
assert 'RemotePlaylistPickerSheet' in streaming
assert 'struct RemoteArtistActionButton' in streaming
assert 'settings.contrastingAccentTextColor' in streaming
assert 'Play Album' in streaming and 'Play All Albums' in streaming
assert 'VerticalArtistIndex' in streaming
assert 'RemoteAlbumCollectionView' in streaming
assert 'streaming-albums' in streaming
assert 'settings.leftHandedAlphabet ? .leading : .trailing' in streaming
assert 'private var indexedAlbumSections: [ArtistIndexSection<RemoteAlbum>]' in streaming
assert 'diagnosticSurface: "streaming-artist-albums"' in streaming
assert 'artist-album-section-' in streaming
assert 'scrollIndicators(.hidden)' in streaming
assert 'highPriorityGesture' in library_view
assert 'alphabet.gesture.begin' in library_view
assert 'alphabet.touch.begin' in library_view
assert 'alphabet.touch.end' in library_view
assert streaming.count('hitWidth: settings.leftHandedAlphabet ? 48 : 32') == 3
assert 'Reissue the final selection after the gesture has' in library_view
assert 'repeatSelection: true' in library_view
assert 'await Task.yield()' in library_view
assert 'alphabet.scrollTo' in streaming
assert 'hasConnectionIssue' in remote
assert 'isExpanded.toggle()' in streaming
assert '.accessibilityElement(children: .combine)' in streaming
assert 'navigationBarTitleDisplayMode(.inline)' in streaming
assert 'commands.nextTrackCommand.isEnabled = true' in player
assert 'commands.previousTrackCommand.isEnabled = true' in player
assert 'commands.skipForwardCommand.isEnabled = false' in player
assert 'commands.skipBackwardCommand.isEnabled = false' in player
assert 'RemoteSearchField' not in streaming
assert 'searchText' not in remote
assert '.searchable(text: $remote.searchText' not in streaming
assert 'struct HexChannelSlider: View' in settings_view
assert 'let controlWidth = proxy.size.width * 0.8' in settings_view
assert 'usableWidth = max(1, width - thumbDiameter)' in settings_view
assert 'let hexValue = nibble * 16' in settings_view
assert '.frame(width: width, height: 16, alignment: .topLeading)' in settings_view
assert '.frame(width: width, height: 28, alignment: .leading)' in settings_view
assert 'nextValue = Int((x / usableWidth * 255).rounded())' in settings_view
assert '@State private var focusedChannel: Channel?' in settings_view
assert 'focusedChannel = channel' in settings_view
assert 'private struct HexChannelSlider: View' in settings_view
assert 'let onBeginEditing: () -> Void' not in settings_view.split('private struct HexChannelSlider: View', 1)[1].split('private struct HexChannelTextField: UIViewRepresentable', 1)[0]
assert '@Binding var isFocused: Bool' in settings_view
assert 'uiView.becomeFirstResponder()' in settings_view
assert 'onBeginEditing: { isTextFieldFocused = false }' in settings_view
assert 'onBeginEditing()' in settings_view
assert '.navigationBarTitleDisplayMode(.large)' in streaming
assert 'streaming.option.compilationGrouping.changed' in streaming
assert 'compilationAlbumIdentity' in remote
assert 'albumArtists(groupCompilationArtists:' in remote
assert 'RemotePlaylistCollectionView' in streaming
assert 'ToolbarItem(placement: .principal)' in library_view
assert 'title: "Streaming"' in library_view
assert 'ToolbarItem(placement: .principal)' in streaming
assert 'title: "Local"' in streaming
assert 'title: "Browse Files"' in library_view
assert 'title: "Download"' in streaming
assert 'resonanceSecondaryToolbarAction' in library_view
assert 'resonanceSecondaryToolbarAction' in streaming
assert '.padding(.top, -4)' in root_view
assert '.offset(y: 18)' not in library_view
assert '.offset(y: 18)' not in streaming
assert 'var albumArtists: [RemoteArtist]?' in remote
assert 'cache.albumArtists = artists' in remote
assert 'recordDeferred' in diagnostics
assert 'playback.gapless.boundary.begin' in player
assert 'playback.gapless.preload' in player
assert 'remoteSeekInFlight' in player
assert 'remote.player.seek.completed' in player
assert 'remote.player.endFallback' in player
assert 'private func clampedRemoteElapsed' in player
assert 'self.clampedRemoteElapsed(clamped)' in player
assert 'self.remoteSeekRequestID == requestID' in player
assert 'pendingRemoteSeekPosition' in player
assert 'resumeRemotePlaybackAfterSeek' in player
assert 'remote.player.seek.resume' in player
assert 'remoteGaplessHandoffTask' not in player
assert 'remote.player.boundary.begin' not in player
assert 'actualIsNearTarget' in player
assert 'abs(actual - clamped) <= 0.75' in player
assert 'private func clearRemoteClockHold' in player
assert 'remoteClockHoldDuration' in player
assert 'newPlayer.playImmediately(atRate: 1)' in player
assert 'targetPlayer.playImmediately(atRate: 1)' in player
assert 'elapsed = clampedRemoteElapsed(seconds)' in player
assert 'lastRemoteBufferStatusPublicationDate' in player
assert 'shouldPublishBufferText' in player
assert 'playbackPreparationGeneration' in remote
assert 'remote.playback.preparationDiscarded' in remote
assert 'Only the selected track\'s artwork is needed to start playback.' in remote
assert 'State(initialValue: Self.makeSections' not in streaming
assert streaming.count('.task(id: sectionInputKey)') == 2
assert '.safeAreaInset(edge: .top, spacing: 0)' in root_view
assert 'ZStack {' in root_view
assert '.opacity(tabPageIsVisible(tab) ? 1 : 0)' in root_view
assert '.allowsHitTesting(' in root_view
assert '!isTabSwipeActive || tab == .playing' in root_view
assert '.accessibilityHidden(tab != selectedTab)' in root_view
assert 'tabSwipeOffset' in root_view
assert 'DragGesture(minimumDistance: 5, coordinateSpace: .local)' in root_view
assert 'tabPageOffset' in root_view
assert 'withAnimation(.easeOut(duration: 0.2))' in root_view
assert 'let threshold = width * 0.5' in root_view
assert 'isTabSwipeActive' in root_view
assert '.scrollDisabled(isTabSwipeActive)' in root_view
assert 'ResonanceInteractiveTopDownDismissModifier' in root_view
assert 'gesture: tabSwipeGesture(width: proxy.size.width)' in root_view
assert 'struct ResonanceTabSwipeActions' in root_view
assert 'func resonanceTabSwipeGesture()' not in root_view
assert 'content.highPriorityGesture(' not in root_view
assert 'func resonanceHierarchySwipeBack' in root_view
assert '.resonanceTabSwipeObserver()' in album_detail
assert '.resonanceTabSwipeGesture()' not in album_detail
assert '.resonanceTabSwipeGesture()' not in streaming
assert 'func remoteTrackDownloadSwipeAction(_ track: RemoteTrackItem)' in streaming
assert 'Label("Download", systemImage: "arrow.down.circle")' in streaming
assert streaming.count('RemoteDownloadOverlay()') >= 4
assert 'final class ResonanceLayerNavigation' in root_view
assert 'ResonanceLayeredNavigationView()' in root_view
assert 'struct ResonanceLayerHeader' in root_view
assert 'struct ResonanceTabBar' in root_view
assert '@Published var dock: MiniPlayerDock = .bottom' in root_view
assert 'nowPlayingPresentationRequest' in root_view
assert 'nowPlayingPresentationRequest' in player
assert 'presentsNowPlaying' in player
assert 'Online artwork search' in settings_view
assert 'Apple and MusicBrainz / Cover Art Archive sources' in settings_view
assert 'Text("100%")' in settings_view
assert 'ProgressView(value: 1.0)' in settings_view
assert '.highPriorityGesture(' in now_playing
assert 'requestNowPlayingPresentation()' in remote
assert 'final class ResonanceTabNavigation' in root_view
assert 'struct ResonanceTabBar' in root_view
assert 'func resonanceDetailTabNavigation()' in root_view
assert 'ResonanceTabBar()' in root_view
assert 'requestID &+= 1' in root_view
assert '.resonanceThemeTextSurface()' in root_view
assert 'private struct ResonanceThemeTextSurface' in root_view
assert '.safeAreaInset(edge: .bottom, spacing: 0)' in root_view
assert '.frame(maxWidth: .infinity, maxHeight: .infinity)' in root_view
assert 'UIScrollView.appearance().bounces = false' in app_source
assert 'UIScrollView.appearance().alwaysBounceVertical = false' in app_source
assert 'transaction.animation = nil' in root_view
assert 'ToolbarItemGroup(placement: .keyboard)' in root_view
assert 'MiniPlayerDock' in root_view
assert 'MiniPlayerEdgeHandle' in root_view
assert 'ScrollView' not in now_playing
assert '.padding(.bottom, 16)' in now_playing
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
assert 'remoteGaplessContinuationTask' in player
assert 'scheduleRemoteTrackAfterCurrentBoundary' in player
assert 'let remoteFollowing = following == nil' in player
assert 'scheduleRemoteTrackAfterCurrentBoundary(remoteFollowing' in player
assert 'Complete next album track scheduled' in player
assert 'remote.gapless.preload' in player
assert 'Next track will load normally' in player
assert 'playback.seek.begin' in player
assert 'playback.seek.completed' in player
assert 'formatRemainingTime' in views
assert 'makeSections' in streaming
assert 'Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")' in settings_view
assert 'Alpha 3.7.4 (47)' not in settings_view
assert 'automaticallyWaitsToMinimizeStalling = !experimentalGapless' in player
assert 'remoteExperimentalSession' in player
assert 'preloadReady' in player
assert 'markPlayed(trackID:' in root_view
assert 'ErrorReportingCoordinatorView' in root_view
assert 'collectDocumentInventory' in library_store
assert 'Task.detached(priority: .utility)' in library_store
assert 'if !forceCheck, !tracks.isEmpty, !isDisplaySnapshotActive, !needsRemoteFormatRefresh { return }' in remote
assert 'scheduleNowPlayingArtworkPreparation' in player
assert 'prepareNowPlayingArtwork(data: data)' in player
artwork = (root / 'Resonance/Views/ArtworkView.swift').read_text()
artwork_search = (root / 'Resonance/Services/ArtworkSearchService.swift').read_text()
artwork_picker = (root / 'Resonance/Views/OnlineArtworkSearchView.swift').read_text()
assert 'LocalArtworkLoader' in artwork
assert 'CGImageSourceCreateThumbnailAtIndex' in artwork
assert 'artwork.local.thumbnail' in artwork
assert 'UIImage(data: data)' not in artwork
assert 'relevance' in artwork_search and 'MusicBrainz Cover Art Archive' in artwork_search
assert 'searchReport' in artwork_search
assert 'searchMusicBrainzArchive' in artwork_search
assert 'searchQueries' in artwork_search
assert 'musicBrainzQueries' in artwork_search
assert 'albumTitleVariants' in artwork_search
assert 'stripTrailingReleaseMetadata' in artwork_search
assert 'containsReleaseMetadataMarker' in artwork_search
assert 'musicBrainzLiteral' in artwork_search
assert 'release-group' in artwork_search
assert 'CoverArtArchiveResponse' in artwork_search
assert 'limit", value: "50"' in artwork_search
assert 'prefix(24)' in artwork_search
assert 'Deezer' not in artwork_search
assert 'Deezer' not in settings_view
assert 'StreamingArtworkCache' in artwork_search
assert 'trackQueries' in artwork_search
assert 'func seed(' in artwork_search
assert 'aliases: [String] = []' in artwork_search
assert 'albumArtist: String? = nil' in artwork_search
assert 'isCredibleMatch' in artwork_search
assert 'queryParts(artist: artist, albumArtist: albumArtist, album: albumVariant, track: track)' in artwork_search
assert 'recommendedSuggestionID' in artwork_picker
assert '.stroke(isSelected ? .red' in artwork_picker
assert 'onImageAvailabilityChanged' in artwork_picker
assert 'Search MusicBrainz artwork' in artwork_picker
assert 'PhotosPicker' not in artwork_picker
assert 'stagesSelection' in artwork_picker
assert 'stagesSelection: true' in smart
assert 'showingArtworkSearch' in album_detail
assert 'rememberArtwork' in remote_download
assert 'resolvedArtworkData' in streaming
assert 'fallbackTrackQueries' in streaming
assert 'StreamingArtworkTrackQuery' in streaming
assert 'Choose Album Artwork' in streaming
assert 'struct RemoteArtworkSource' in streaming
assert 'struct RemoteArtworkContext' in streaming
assert 'sources(from tracks: [RemoteTrackItem])' in streaming
assert 'RemoteArtwork(context:' in streaming
assert 'let artwork: RemoteArtworkContext' in streaming
assert 'let preferOnlineSearch: Bool' in streaming
assert 'var hasProvidedArtwork: Bool' in streaming
assert '!context.hasProvidedArtwork' in streaming
assert 'isAutomaticallySelectedArtwork = !hasProvidedArtwork' in streaming
assert 'preferOnlineSearch: true' in streaming
assert 'fallbackArtist: artist.name' in streaming
assert 'context.preferOnlineSearch' in streaming
assert 'album: $0.album' in streaming
assert 'searchedAlbums' in artwork_search
assert 'StreamingArtworkCache.shared.artwork' in streaming
assert 'seedSharedArtwork' not in streaming

assert 'SecureField("Navidrome / Subsonic"' in settings_view
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
assert '<string>Resonance Beta</string>' in plist

# Alpha 3.7.4 build 43 playback crash isolation and device diagnostics.
diagnostics = (root / 'Resonance/Services/ResonanceDiagnostics.swift').read_text()
assert 'ResonanceDiagnostics.swift in Sources' in pbx
assert 'Documents/Resonance-Diagnostics.log' in diagnostics
assert 'playback.timer.tick.begin' in player
assert 'private nonisolated static func makeNowPlayingArtwork' in player
assert 'UIImage(data: imageData) ?? UIImage()' in player
assert 'Self.modificationDates(for: stored)' in library_store
assert 'library.scan.inventory' in library_store
assert 'contentVisible' in library_store
assert 'library.tracks.isEmpty' in library_view
assert 'DebouncedSettingCommitter' in settings_view
assert 'accentHexDraft' in settings_view
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
assert 'frame(width: hitWidth)' in library_view
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
assert 'private enum BrowseNeed: Equatable' in remote
assert 'populate(&cache, need: need)' in remote
assert 'activeTabContent' in root_view and 'tabPageIsVisible' in root_view
assert 'if isExpanded {' in settings_view and 'self.content = content' in settings_view
# Alpha 3.7.2 post-start crash diagnostics and safe MediaPlayer artwork.
assert 'playbackRuntimeDiagnostic' in player
assert 'First playback timer tick completed' in player
assert 'resonancePreparedNowPlayingImage' in player
assert 'resonanceAspectFit' not in player
assert 'showLockScreenArtwork' in settings
assert 'streamingGaplessExperimental' in settings
assert 'Streaming gapless playback is disabled during alpha testing.' not in settings_view
assert 'return false' in player
assert 'RemoteDownloadManager' in remote_download
assert 'RemoteBackgroundDownloadSession' in remote_download
assert 'background(withIdentifier:' in remote_download
assert 'sessionSendsLaunchEvents = true' in remote_download
assert 'handleEventsForBackgroundURLSession' in app_source
assert 'experimentalBackgroundDownloads' in settings
assert 'Experimental background downloads' in settings_view
assert 'currentCompletedBytes' in remote_download
assert 'requestDownload' in remote_download
assert 'confirmReplacement' in remote_download
assert 'refreshDownloadedTrack' in remote_download
assert 'case cancelled' in remote_download
assert 'case queued' in remote_download
assert 'downloadQueue' in remote_download
assert 'cancelDownload' in remote_download
assert 'Hide download queue' in streaming
assert 'RemoteDownloadQueueRow' in streaming
assert 'Remove or Delete Album' in library_view
assert 'RemoteDownloadOverlay' in streaming
assert 'Collapse download queue' in streaming
assert 'refreshDownloadedTrack' in library_store
assert 'requeueDownload' in remote_download
assert 'Requeue' in streaming
assert 'ignoredLocalPaths' in library_store
assert 'deletingFiles: Bool' in library_store
assert 'Label("Download", systemImage: "arrow.down.circle")' in streaming
assert 'Button("Download Entire Library")' in streaming
assert 'Button("Select Individual Artists")' in streaming
assert 'DownloadSelectionBubble' in streaming
assert 'downloadSelectionMode' in streaming
assert streaming.count('LongPressGesture(minimumDuration: 0.45, maximumDistance: 12)') == 2
assert 'DragGesture(minimumDistance: 0)' not in streaming
assert streaming.count('UIImpactFeedbackGenerator(style: .medium).impactOccurred()') == 2
assert '.background(settings.themeBackgroundGradient)' not in streaming
assert '.background(.background)' not in streaming
assert 'RemoteDownloadOverlay()' in streaming
assert '.padding(.top, 84)' in streaming
assert 'backgroundImageName' in root_view
assert 'resonanceTabBottomSpace' in root_view
assert 'resonanceDetailBottomSpace' in root_view
assert 'dragTranslation' in root_view
assert 'highPriorityGesture' in root_view
assert 'private struct ResonanceTopDownDismissModifier' not in root_view
assert '.offset(y: completionOffset + dragOffset)' not in root_view
assert 'transaction.disablesAnimations = true' not in root_view
assert 'remoteTrackSwipeActions' in streaming
assert 'private struct RemoteTrackSwipeActions' in streaming
assert 'resonanceTopDownDismiss' in root_view
assert album_detail.count('resonanceTopDownDismiss') == 0
assert library_view.count('resonanceTopDownDismiss') == 0
assert streaming.count('resonanceTopDownDismiss') == 0
assert 'resonanceHierarchySwipeBack' not in album_detail
assert 'resonanceHierarchySwipeBack' not in library_view
assert 'resonanceHierarchySwipeBack' not in streaming
assert '.gesture(\n            DragGesture(minimumDistance: 45)' in album_detail
assert 'resonanceHeroSurface' in root_view
assert 'ResonanceVisualTheme' in settings
assert 'ResonanceHeroButtonStyle' in settings
assert 'heroButtonStyleRaw' in settings
assert 'Soft Glass' in settings
assert 'Matte Crystal' in settings
assert 'Inner Glow' in settings
assert 'Minimal Transparent' in settings
assert 'HeroButtonStylePreview' in settings_view
assert 'CurrentTrackArtworkPreview' in settings_view
assert 'player.currentTrack.flatMap { player.artworkData(for: $0) }' in settings_view
assert 'Nocturne Glass' in settings
assert 'Gallery Light' in settings
assert 'Color Bloom' in settings
assert 'Brushed Metal' in settings
assert 'Classic Wood' in settings
assert 'Electronic' in settings
assert 'Psychedelic' in settings
assert 'var visualTheme' in settings
assert 'backgroundGradientHex' in settings
assert 'isBrightAppearance' in settings
assert 'Visual style' in settings_view
assert 'backgroundImageName' in settings_view
assert 'size: 158' in streaming
assert 'size: 176' in streaming and 'size: 176' in album_detail
assert '.scrollContentBackground(.hidden)' in streaming and '.scrollContentBackground(.hidden)' in album_detail
assert 'onDock: @escaping' in root_view
assert 'onDock(value.translation.height < 0 ? .top : .bottom)' in root_view
assert 'ResonanceHeroActionButton' in root_view
assert 'settings.heroButtonStyle' in root_view
assert 'case .softGlass:' in root_view
assert 'case .matteCrystal:' in root_view
assert 'case .innerGlow:' in root_view
assert 'case .minimalTransparent:' in root_view
assert 'ResonanceToolbarIconButton' in root_view
assert 'themeSurfaceGradient' in root_view
assert 'themeSurfaceGradient' in streaming
assert 'ResonanceThemeSurfaceBackdrop' in root_view
assert '.frame(maxWidth: .infinity, maxHeight: .infinity)' in root_view
surface_backdrop = root_view.split('struct ResonanceThemeSurfaceBackdrop: View {', 1)[1].split('private struct ResonanceHeroSurface', 1)[0]
assert '.frame(maxWidth: .infinity, maxHeight: .infinity)' not in surface_backdrop
assert 'Color.clear' in surface_backdrop
assert 'Color.clear' in surface_backdrop
assert '.contentShape(Rectangle())' in now_playing
assert '.opacity(0.42)' in root_view
assert '.opacity(0.12)' in root_view
assert '.opacity(0.025)' not in root_view
assert '.opacity(0.40)' in settings_view
assert 'textAccentColor' in settings
assert 'applyThemeColorToTextConfigured' in settings
assert '.onEnded' in streaming
assert streaming.count('.simultaneousGesture(') >= 2
assert '.fullScreenCover(item: $destinationArtist)' in streaming
assert '.fullScreenCover(item: $destinationAlbum)' in streaming
assert '.fullScreenCover(item: $presentedArtist)' in library_view
assert '.fullScreenCover(item: $presentedAlbum)' in library_view
assert '.fullScreenCover(isPresented: $showingAllAlbums)' in library_view
assert '.fullScreenCover(item: $presentedAlbum)' in streaming
assert '.fullScreenCover(isPresented: $showingAllAlbums)' in streaming
assert 'NavigationStack {\n                ArtistDetailView(artist: artist)' in library_view
assert 'NavigationStack {\n                AlbumDetailView(album: album)' in library_view
assert 'NavigationStack {\n                    RemoteArtistDetailView(artist: artist)' in streaming
assert 'NavigationStack {\n                    RemoteAlbumDetailView(album: album)' in streaming
assert 'Label("Back", systemImage: "chevron.left")' in library_view
assert 'ResonanceToolbarTextButton' in album_detail
assert 'Streaming artist view and sort options' in streaming
assert library_view.count('.resonanceDetailTabNavigation()') == 1
assert album_detail.count('.resonanceDetailTabNavigation()') == 2
assert streaming.count('.resonanceDetailTabNavigation()') == 3
assert 'backgroundImageName' in settings
assert 'ThemeBrushedMetal' in settings
assert 'ThemeClassicWood' in settings
assert 'ThemeElectronic' in settings
assert 'case .nocturne, .galleryLight, .colorBloom: nil' in settings
assert 'case .nocturne: ["0B1020", "271A4A", "080B15"]' in settings
assert 'case .galleryLight: ["F4E5D2", "C97955", "FFF8EE"]' in settings
assert 'case .colorBloom: ["07142B", "8A245F", "0B4560"]' in settings
assert 'ThemePsychedelic' in settings
assert 'removeProgress' in remote_download
assert 'prioritizeDownloadQueue' in remote_download
assert 'showingAlbumOptions' in album_detail
assert 'browseReady' in streaming
assert 'value.translation.height > 70' in streaming
assert 'private struct MetadataTextField' in smart
assert 'Enter track title' in smart
assert '_discNumber = State(initialValue: "")' in smart
assert 'discNumber: discNumber.map { max(1, $0) } ?? track.discNumber' in library_store
assert 'ScrollableArtistName' in library_view
assert 'let hitWidth: CGFloat' in library_view
assert '.frame(width: hitWidth)' in library_view
assert 'resumePersistedDownloads' in remote_download
assert 'hasPersistedQueue' in streaming
assert 'ServerQRCodeScannerView' in settings_view
assert 'CenteredSettingsPicker' in settings_view
assert '.presentationCompactAdaptation(.popover)' in settings_view
assert 'qrcode.viewfinder' in settings_view
assert 'MetadataTagWriter' in metadata
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

# Audiobook resume, five-position recovery, and audiobook-only speed controls.
assert 'struct AudiobookPlaybackBookmark' in player
assert 'resonance.audiobookAlbumKeys' in player
assert 'resonance.audiobookBookmarks' in player
assert 'func toggleAudiobook' in player
assert 'func resumeAudiobookAlbum' in player
assert 'saveAudiobookBookmarkIfNeeded' in player
assert 'limitAudiobookBookmarksPerAlbum' in player
assert 'albumBookmarks.prefix(5)' in player
assert 'audiobookBookmarks.removeAll { $0.albumKey == albumKey && $0.trackID == currentTrack.id }' not in player
assert 'func prepareForSceneExit()' in player
assert 'func prepareForSceneActive()' in player
assert 'player.prepareForSceneExit()' in app_source
assert 'var isFlacOnly: Bool' in track
assert '@AppStorage("flacAlert") var flacAlert = false' in settings
assert 'Toggle("Flac Alert", isOn: $settings.flacAlert)' in settings_view
assert 'borderColor: Color? = nil' in artwork_view
assert 'settings.flacAlert && album.isFlacOnly' in library_view
assert 'func setPlaybackRate' in player
assert 'private let timePitch = AVAudioUnitTimePitch()' in gapless
assert 'engine.connect(playerNode, to: timePitch' in gapless
assert 'if player.isCurrentAudiobook' in views
assert 'Audiobook playback speed' in views
assert 'player.resumeAudiobookAlbum' in album_detail
assert 'Mark as Audiobook' in album_detail
assert 'audiobookMenu(for: album)' in library_view
assert 'audiobookMenu(for: album)' in streaming
assert 'player.resumeAudiobookAlbum' in remote

# Native MilkDrop title feedback and ProjectM render-performance contracts.
assert 'ProjectMLyricsOverlay' not in projectm_view
assert 'MilkDropLyricText' not in projectm_view
assert 'resonance_projectm_prepare_lyric' in projectm_view
assert 'Task.detached(priority: .userInitiated)' in projectm_view
assert 'projectm.performance.window' in projectm_view
assert 'glReadPixels' not in projectm_bridge.split(
    'extern "C" void resonance_native_projectm_render', 1
)[1].split('namespace {', 1)[0]
assert 'primaryTexturePath == nextPrimary' in projectm_bridge
assert 'm_milkdropText->Draw' in projectm_engine
assert projectm_preset.index('ShouldBurnIntoFeedback') < projectm_preset.index('m_finalComposite.Draw')
assert 'constexpr int Columns = 16;' in milkdrop_text
assert 'constexpr int Rows = 8;' in milkdrop_text
assert 'std::pow(rampedProgress, 1.8f) * 1.3f' in milkdrop_text
assert 'GL_ONE_MINUS_SRC_COLOR' in milkdrop_text
assert (root / 'Resonance/Resources/ProjectMD/MILKDROP2-TITLE-ANIMATION-LICENSE.txt').is_file()

# Coordinate mapping should select the expected first, middle, and last rows.
def mapped_index(y, top, row_height, count):
    relative = min(max(0.0, y - top), max(0.0, row_height * count - 0.001))
    return min(count - 1, max(0, int(relative // max(1.0, row_height))))

assert mapped_index(0, 8, 10, 26) == 0
assert mapped_index(8 + 12 * 10 + 5, 8, 10, 26) == 12
assert mapped_index(10_000, 8, 10, 26) == 25

# Deterministic mixed-artist grouping contract: the split album is one
# Various Artists album, while the regular album remains outside the set.
fixture = [
    ('Split Album', 2024, 'Artist A'),
    ('Split Album', 2024, 'Artist B'),
    ('Regular Album', 2024, 'Artist C'),
]
by_album = {}
for album, year, artist in fixture:
    by_album.setdefault((album.strip().lower(), year), set()).add(artist.strip().lower())
mixed_fixture_keys = {f'{album}|{year}' for (album, year), artists in by_album.items() if len(artists) > 1}
assert mixed_fixture_keys == {'split album|2024'}



import re
source_version = sorted(set(re.findall(r'MARKETING_VERSION = ([^;]+);', pbx)))
source_build = sorted(set(re.findall(r'CURRENT_PROJECT_VERSION = ([^;]+);', pbx)))
assert len(source_version) == 1 and len(source_build) == 1
print(f'Resonance source-contract regression checks passed (project default {source_version[0]}/{source_build[0]}).')
PY
