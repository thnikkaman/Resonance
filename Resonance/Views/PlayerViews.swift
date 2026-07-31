import SwiftUI

struct NowPlayingView: View {
  @EnvironmentObject private var player: PlayerController
  @EnvironmentObject private var library: LibraryStore
  @EnvironmentObject private var remote: RemoteLibraryStore
  @EnvironmentObject private var settings: AppSettings
  @EnvironmentObject private var layeredNavigationState: ResonanceLayerNavigation
  @State private var showingQueue = false
  @State private var showingBookmarks = false
  @State private var showingPlaylistPicker = false
  let openLibrary: () -> Void
  let onHorizontalTabSwipeChanged: (CGFloat, CGFloat) -> Void
  let onHorizontalTabSwipeEnded: (CGFloat, CGFloat) -> Void

  init(
    openLibrary: @escaping () -> Void,
    onHorizontalTabSwipeChanged: @escaping (CGFloat, CGFloat) -> Void = { _, _ in },
    onHorizontalTabSwipeEnded: @escaping (CGFloat, CGFloat) -> Void = { _, _ in }
  ) {
    self.openLibrary = openLibrary
    self.onHorizontalTabSwipeChanged = onHorizontalTabSwipeChanged
    self.onHorizontalTabSwipeEnded = onHorizontalTabSwipeEnded
  }

  private var currentTrackIsFavorite: Bool {
    guard let track = player.currentTrack else { return false }
    return library.isFavorite(track)
  }

  private var nowPlayingPrimaryColor: Color {
    settings.textAccentColor
  }

  private var nowPlayingSecondaryColor: Color {
    settings.textAccentColor.opacity(0.72)
  }

  var body: some View {
    VStack(spacing: 18) {
      VStack(spacing: 14) {
        NowPlayingArtworkPager()

        // This is the only tab-navigation hit-test region on Playing. Its
        // clear insets cover the gap around the metadata while leaving the
        // artwork pager and seek bar outside its bounds.
        VStack(spacing: 0) {
          Color.clear.frame(height: 10)

          VStack(spacing: 4) {
            Text(player.currentTrack?.title ?? "Nothing Playing")
              .font(.title2.bold())
              .lineLimit(1)
              .foregroundStyle(nowPlayingPrimaryColor)
            Text(
              player.currentTrack.map { "\($0.artist) — \($0.album)" }
                ?? "Choose music from your library"
            )
            .foregroundStyle(nowPlayingSecondaryColor)
            .lineLimit(1)
            Text(
              player.currentTrack.map {
                "Length \(format(player.duration > 0 ? player.duration : $0.duration))"
              } ?? "Length —"
            )
            .font(.caption.monospacedDigit())
            .foregroundStyle(nowPlayingSecondaryColor)

            if player.currentTrack != nil {
              Label(
                player.preloadedTrackTitle.map { "Gapless ready: \($0)" }
                  ?? player.playbackEngineStatus,
                systemImage: player.preloadedTrackTitle == nil ? "waveform" : "waveform.badge.plus"
              )
              .font(.caption2)
              .foregroundStyle(nowPlayingSecondaryColor)
              .lineLimit(1)
            }
          }

          Color.clear.frame(height: 10)
        }

        .contentShape(Rectangle())
        .highPriorityGesture(
          // The page itself is translated during a live tab swipe. A local
          // coordinate space therefore moves with the gesture's view and can
          // feed back into translation, producing the visible vibration on
          // Playing. Global coordinates remain fixed to the screen.
          DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { value in
              onHorizontalTabSwipeChanged(
                value.translation.width,
                value.translation.height
              )
            }
            .onEnded { value in
              // Always notify the root on release. If the gesture became
              // vertical near the end, the root must cancel the live offset
              // instead of leaving the transition in an indeterminate state.
              onHorizontalTabSwipeEnded(
                value.translation.width,
                value.translation.height
              )
            }
        )
      }

      TrackScrubber()
        .frame(maxWidth: 320)

      HStack(spacing: 0) {
        Button(action: player.previous) {
          Image(systemName: "backward.fill")
        }
        .accessibilityLabel("Previous track")
        .frame(maxWidth: .infinity)

        Button {
          player.skip(by: -15)
        } label: {
          Image(systemName: "gobackward.15")
        }
        .accessibilityLabel("Rewind 15 seconds")
        .frame(maxWidth: .infinity)

        Button(action: player.toggle) {
          Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
            .font(.system(size: 42))
        }
        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
        .frame(maxWidth: .infinity)

        Button {
          player.skip(by: 15)
        } label: {
          Image(systemName: "goforward.15")
        }
        .accessibilityLabel("Jump ahead 15 seconds")
        .frame(maxWidth: .infinity)

        Button(action: player.next) {
          Image(systemName: "forward.fill")
        }
        .accessibilityLabel("Next track")
        .frame(maxWidth: .infinity)
      }
      .foregroundStyle(nowPlayingPrimaryColor)
      .font(.title2)
      .frame(maxWidth: 420)
      .padding(.horizontal, 4)

      HStack(spacing: 0) {
        Button {
          if let track = player.currentTrack { library.toggleFavorite(track) }
        } label: {
          Image(systemName: currentTrackIsFavorite ? "heart.fill" : "heart")
            .foregroundStyle(currentTrackIsFavorite ? settings.accentColor : nowPlayingSecondaryColor)
        }
        .disabled(player.currentTrack == nil)
        .accessibilityLabel(currentTrackIsFavorite ? "Remove from favorites" : "Add to favorites")
        .frame(maxWidth: .infinity)

        Button {
          showingBookmarks = true
        } label: {
          Image(systemName: player.currentTrackBookmarks.isEmpty ? "bookmark" : "bookmark.fill")
            .foregroundStyle(
              player.currentTrackBookmarks.isEmpty ? nowPlayingSecondaryColor : settings.accentColor
            )
            .overlay(alignment: .topTrailing) {
              if !player.currentTrackBookmarks.isEmpty {
                Text("\(player.currentTrackBookmarks.count)")
                  .font(.system(size: 8, weight: .bold))
                  .foregroundStyle(settings.contrastingAccentTextColor)
                  .padding(3)
                  .background(settings.accentColor, in: Circle())
                  .offset(x: 8, y: -8)
              }
            }
        }
        .disabled(player.currentTrack == nil)
        .accessibilityLabel("Playback bookmarks")
        .frame(maxWidth: .infinity)

        if player.isCurrentAudiobook {
          Menu {
            ForEach([0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { rate in
              Button {
                player.setPlaybackRate(rate)
              } label: {
                if abs(player.playbackRate - rate) < 0.01 {
                  Label("\(rate, specifier: "%g")×", systemImage: "checkmark")
                } else {
                  Text("\(rate, specifier: "%g")×")
                }
              }
            }
          } label: {
            Text("\(player.playbackRate, specifier: "%g")×")
              .font(.caption.weight(.bold).monospacedDigit())
              .foregroundStyle(nowPlayingSecondaryColor)
          }
          .accessibilityLabel("Audiobook playback speed")
          .frame(maxWidth: .infinity)
        }

        Button(action: player.toggleShuffle) {
          Image(systemName: "shuffle")
            .foregroundStyle(player.shuffleEnabled ? settings.accentColor : nowPlayingSecondaryColor)
        }
        .accessibilityLabel(player.shuffleEnabled ? "Turn shuffle off" : "Turn shuffle on")
        .frame(maxWidth: .infinity)

        Button(action: player.cycleRepeatMode) {
          Image(systemName: player.repeatMode.systemImage)
            .foregroundStyle(player.repeatMode == .off ? nowPlayingSecondaryColor : settings.accentColor)
            .overlay(alignment: .topTrailing) {
              if player.repeatMode == .all {
                Circle()
                  .fill(settings.accentColor)
                  .frame(width: 5, height: 5)
                  .offset(x: 3, y: -3)
              }
            }
        }
        .accessibilityLabel(player.repeatMode.rawValue)
        .frame(maxWidth: .infinity)

        Button {
          showingQueue = true
        } label: {
          Image(systemName: "list.bullet")
        }
        .accessibilityLabel("Show playback queue")
        .frame(maxWidth: .infinity)

        Menu {
          ForEach(SleepTimerOption.allCases) { option in
            Button {
              player.setSleepTimer(option)
            } label: {
              if option == player.sleepTimerOption {
                Label(option.rawValue, systemImage: "checkmark")
              } else {
                Text(option.rawValue)
              }
            }
          }
        } label: {
          Image(systemName: player.sleepTimerOption == .off ? "moon.zzz" : "moon.zzz.fill")
            .foregroundStyle(
              player.sleepTimerOption == .off ? nowPlayingSecondaryColor : settings.accentColor)
        }
        .accessibilityLabel("Sleep timer: \(player.sleepTimerLabel)")
        .frame(maxWidth: .infinity)
      }
      .font(.title3)
      .frame(maxWidth: 420)
      .padding(.horizontal, 4)

      HStack(spacing: 8) {
        Image(systemName: "speaker.fill")
          .font(.caption)
          .foregroundStyle(nowPlayingSecondaryColor)
        VolumeSlider(value: $player.volume, tint: settings.accentColor)
        Image(systemName: "speaker.wave.3.fill")
          .font(.caption)
          .foregroundStyle(nowPlayingSecondaryColor)
      }
      .frame(maxWidth: 300)
      .tint(settings.accentColor)

      if player.sleepTimerOption != .off {
        Label("Sleep timer: \(player.sleepTimerLabel)", systemImage: "moon.zzz.fill")
          .font(.caption)
          .foregroundStyle(nowPlayingSecondaryColor)
      }

      HStack {
        Button(action: openLibrary) {
          HStack(spacing: 6) {
            Text("Browse Library")
            Image(systemName: "chevron.right")
          }
        }
        .buttonStyle(.bordered)

        Button(action: player.stop) {
          Label("Stop", systemImage: "stop.fill")
        }
        .buttonStyle(.bordered)
      }
      .tint(settings.accentColor)
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background {
      ResonanceThemeBackdrop()
    }
    .navigationTitle("Now Playing")
      .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        ResonanceToolbarTextButton(
          title: "Back",
          systemImage: "chevron.left",
          width: 76,
          action: openLibrary
        )
      }
      .resonanceHideSharedBackground()
      ToolbarItem(placement: .principal) {
        Button {
          openCurrentAlbum()
        } label: {
          ResonanceHierarchyNavigationLabel(title: "Album")
        }
        .accessibilityLabel("Album, move up")
      }
      ToolbarItem(placement: .topBarTrailing) {
        HStack(spacing: 4) {
          if player.currentTrack != nil {
            ResonanceToolbarIconButton(
              accessibilityLabel: library.playlists.isEmpty ? "Add a playlist" : "Add current track to playlist",
              systemImage: "text.badge.plus"
            ) {
              showingPlaylistPicker = true
            }
          }

          ResonanceToolbarTextButton(
            title: "Queue",
            systemImage: "list.bullet",
            width: 76
          ) {
            showingQueue = true
          }
        }
      }
      .resonanceHideSharedBackground()
    }
    .sheet(isPresented: $showingQueue) {
      PlaybackQueueView()
        .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $showingBookmarks) {
      PlaybackBookmarksView()
        .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $showingPlaylistPicker) {
      if let track = player.currentTrack {
        PlaylistPickerSheet(tracks: [track])
          .presentationDetents([.medium, .large])
      }
    }
  }

  private func openCurrentAlbum() {
    guard let track = player.currentTrack else { return }

    if track.isRemote {
      let remoteTrack = remote.tracks.first(where: { $0.id == track.id })
        ?? remote.albums.flatMap(\.tracks).first(where: { $0.id == track.id })
      let album = remote.albums.first { candidate in
        if let remoteTrack {
          return candidate.tracks.contains(where: { $0.id == remoteTrack.id })
        }
        return candidate.title.localizedCaseInsensitiveCompare(track.album) == .orderedSame
          && candidate.artist.localizedCaseInsensitiveCompare(track.albumArtist) == .orderedSame
      }

      guard let album else {
        ResonanceDiagnostics.shared.recordDeferred(
          "navigation.nowPlayingAlbum.missing",
          details: ["source": "streaming"]
        )
        return
      }

      layeredNavigationState.root = .streaming
      layeredNavigationState.localAlbum = nil
      layeredNavigationState.localArtist = nil
      layeredNavigationState.remoteAlbum = album
      layeredNavigationState.remoteArtist = remote.artists.first { artist in
        artist.albums.contains(where: { $0.id == album.id })
      }
    } else {
      guard let album = library.albums.first(where: { album in
        album.tracks.contains(where: { $0.id == track.id })
      }) else {
        ResonanceDiagnostics.shared.recordDeferred(
          "navigation.nowPlayingAlbum.missing",
          details: ["source": "library"]
        )
        return
      }

      layeredNavigationState.root = .library
      layeredNavigationState.remoteAlbum = nil
      layeredNavigationState.remoteArtist = nil
      layeredNavigationState.localAlbum = album
      layeredNavigationState.localArtist = library.artists.first { artist in
        artist.albums.contains(where: { $0.id == album.id })
      }
    }

    layeredNavigationState.showAlbum()
  }
}

private struct VolumeSlider: View {
  @Binding var value: Double
  let tint: Color

  private let thumbDiameter: CGFloat = 20
  private let trackHeight: CGFloat = 4

  var body: some View {
    GeometryReader { proxy in
      let width = max(proxy.size.width, thumbDiameter)
      let thumbRadius = thumbDiameter / 2
      let usableWidth = max(1, width - thumbDiameter)
      let clampedValue = min(1, max(0, value))
      let thumbCenterX = thumbRadius + usableWidth * clampedValue

      ZStack(alignment: .leading) {
        Capsule()
          .fill(.secondary.opacity(0.28))
          .frame(width: usableWidth, height: trackHeight)
          .offset(x: thumbRadius)

        Capsule()
          .fill(tint)
          .frame(width: max(0, usableWidth * clampedValue), height: trackHeight)
          .offset(x: thumbRadius)

        Circle()
          .fill(tint)
          .frame(width: thumbDiameter, height: thumbDiameter)
          .shadow(radius: 1)
          .offset(x: thumbCenterX - thumbRadius)
      }
      .frame(width: width, height: 32)
      .contentShape(Rectangle())
      .highPriorityGesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
          .onChanged { gesture in
            let x = min(max(0, gesture.location.x - thumbRadius), usableWidth)
            value = min(1, max(0, x / usableWidth))
          }
      )
      .accessibilityElement()
      .accessibilityLabel("Volume")
      .accessibilityValue("\(Int((clampedValue * 100).rounded())) percent")
      .accessibilityAdjustableAction { direction in
        switch direction {
        case .increment: value = min(1, value + 0.05)
        case .decrement: value = max(0, value - 0.05)
        @unknown default: break
        }
      }
    }
    .frame(height: 32)
  }
}

private struct NowPlayingArtworkPager: View {
  @EnvironmentObject private var player: PlayerController
  @State private var dragOffset: CGFloat = 0
  @State private var isCompletingTransition = false
  @State private var transitionToken = UUID()

  private var currentTrack: Track? {
    guard player.queue.indices.contains(player.currentQueueIndex) else { return player.currentTrack }
    return player.queue[player.currentQueueIndex]
  }

  private var previousTrack: Track? {
    let index = player.currentQueueIndex - 1
    if player.queue.indices.contains(index) { return player.queue[index] }
    if player.repeatMode == .all { return player.queue.last }
    return nil
  }

  private var nextTrack: Track? {
    let index = player.currentQueueIndex + 1
    if player.queue.indices.contains(index) { return player.queue[index] }
    if player.repeatMode == .all { return player.queue.first }
    return nil
  }

  var body: some View {
    GeometryReader { proxy in
      let pageWidth = max(1, proxy.size.width)
      ZStack(alignment: .leading) {
        HStack(spacing: 0) {
          artworkPage(previousTrack, pageWidth: pageWidth)
          artworkPage(currentTrack, pageWidth: pageWidth)
          artworkPage(nextTrack, pageWidth: pageWidth)
        }
        .frame(width: pageWidth * 3, alignment: .leading)
        .offset(x: -pageWidth + dragOffset)
      }
      .frame(width: pageWidth, height: 260, alignment: .leading)
      .contentShape(Rectangle())
      .clipped()
      .gesture(
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
          .onChanged { value in
            guard !isCompletingTransition else { return }
            guard abs(value.translation.width) > abs(value.translation.height) else { return }
            let hasDestination = value.translation.width < 0 ? nextTrack != nil : previousTrack != nil
            dragOffset = hasDestination ? value.translation.width : value.translation.width * 0.18
          }
          .onEnded { value in
            guard !isCompletingTransition else { return }
            let projected = value.predictedEndTranslation.width
            let threshold = pageWidth * 0.20
            let moveToNext = nextTrack != nil && min(value.translation.width, projected) < -threshold
            let moveToPrevious = previousTrack != nil && max(value.translation.width, projected) > threshold

            if moveToNext {
              completeTransition(toOffset: -pageWidth) { player.next() }
            } else if moveToPrevious {
              completeTransition(toOffset: pageWidth) { player.previousTrack() }
            } else {
              withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.9)) {
                dragOffset = 0
              }
            }
          }
      )
      .accessibilityElement(children: .contain)
      .accessibilityHint("Swipe left for the next track or right for the previous track")
    }
    .frame(height: 260)
  }

  @ViewBuilder
  private func artworkPage(_ track: Track?, pageWidth: CGFloat) -> some View {
    HStack {
      Spacer(minLength: 0)
      CachedPagerArtwork(
        data: track.flatMap { player.artworkData(for: $0) },
        embedded: track.map { player.artworkIsEmbedded(for: $0) } ?? true
      )
      .shadow(radius: 18, y: 8)
      .accessibilityLabel(track.map { "\($0.album) artwork" } ?? "No adjacent track")
      Spacer(minLength: 0)
    }
    .frame(width: pageWidth, height: 260)
  }

  private func completeTransition(toOffset: CGFloat, action: @escaping () -> Void) {
    isCompletingTransition = true
    let token = UUID()
    transitionToken = token
    withAnimation(
      .interactiveSpring(response: 0.25, dampingFraction: 0.92),
      completionCriteria: .logicallyComplete
    ) {
      dragOffset = toOffset
    } completion: {
      guard transitionToken == token else { return }
      action()
      var transaction = Transaction()
      transaction.disablesAnimations = true
      withTransaction(transaction) {
        dragOffset = 0
        isCompletingTransition = false
      }
    }
  }
}

private struct CachedPagerArtwork: View {
  let data: Data?
  let embedded: Bool

  var body: some View {
    ArtworkView(data: data, embedded: embedded, size: 252)
      .frame(width: 252, height: 252)
  }
}

private struct TrackScrubber: View {
  @EnvironmentObject private var player: PlayerController
  @EnvironmentObject private var playbackProgress: PlaybackProgress
  @EnvironmentObject private var settings: AppSettings
  @State private var previewTime: Double?
  @State private var fingerX: CGFloat = 0

  private var effectiveDuration: Double {
    let controllerDuration = player.duration
    guard !controllerDuration.isFinite || controllerDuration <= 0 else {
      return controllerDuration
    }
    return max(0, player.currentTrack?.duration ?? 0)
  }

  private var displayedTime: Double {
    let raw = previewTime ?? playbackProgress.elapsed
    guard effectiveDuration.isFinite, effectiveDuration > 0 else { return max(0, raw) }
    return min(max(0, raw), effectiveDuration)
  }
  private var isScrubbing: Bool { previewTime != nil }

  var body: some View {
    VStack(spacing: 8) {
      GeometryReader { proxy in
        let width = max(proxy.size.width, 1)
        let duration = max(effectiveDuration, 1)
        let ratio = min(max(displayedTime / duration, 0), 1)
        let thumbX = width * ratio
        let bubbleWidth: CGFloat = 66
        let bubbleX = min(max(0, fingerX - bubbleWidth / 2), max(0, width - bubbleWidth))

        ZStack(alignment: .topLeading) {
          if isScrubbing {
            Text(formatScrubTime(displayedTime))
              .font(.caption2.monospacedDigit().weight(.semibold))
              .foregroundStyle(settings.contrastingAccentTextColor)
              .frame(width: bubbleWidth)
              .padding(.vertical, 5)
              .background(settings.accentColor, in: Capsule())
              .offset(x: bubbleX, y: 0)
          }

          Capsule()
            .fill(.secondary.opacity(0.28))
            .frame(height: 4)
            .offset(y: 34)

          Capsule()
            .fill(settings.accentColor)
            .frame(width: max(4, thumbX), height: 4)
            .offset(y: 34)

          Circle()
            .fill(settings.accentColor)
            .frame(width: isScrubbing ? 22 : 16, height: isScrubbing ? 22 : 16)
            .shadow(radius: isScrubbing ? 3 : 1)
            .offset(
              x: min(
                max(0, thumbX - (isScrubbing ? 11 : 8)),
                width - (isScrubbing ? 22 : 16)
              ),
              y: isScrubbing ? 25 : 28
            )
            .animation(.easeOut(duration: 0.12), value: isScrubbing)
        }
        .frame(width: width, height: 50)
        .contentShape(Rectangle())
        .highPriorityGesture(
          DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
              guard player.currentTrack != nil else { return }
              fingerX = min(max(0, value.location.x), width)
              let normalized = min(max(fingerX / max(1, width), 0), 1)
              previewTime = normalized * duration
            }
            .onEnded { _ in
              guard let previewTime else { return }
              player.seek(to: previewTime)
              self.previewTime = nil
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Track position")
        .accessibilityValue(formatScrubTime(displayedTime))
        .accessibilityAdjustableAction { direction in
          switch direction {
          case .increment: player.skip(by: 15)
          case .decrement: player.skip(by: -15)
          @unknown default: break
          }
        }
      }
      .frame(height: 50)

      HStack {
        Text(format(displayedTime))
        Spacer()
        Text("−\(formatRemainingTime(effectiveDuration - displayedTime))")
      }
      .font(.caption.monospacedDigit())
      .foregroundStyle(.secondary)
      .padding(.horizontal, 2)
    }
    .opacity(player.currentTrack == nil ? 0.45 : 1)
  }

  private func formatScrubTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
  }

  private func formatRemainingTime(_ seconds: Double) -> String {
    guard seconds.isFinite else { return "—:—" }
    return formatScrubTime(max(0, seconds))
  }
}

private struct PlaybackBookmarksView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var player: PlayerController

  private var currentAudiobookPositions: [AudiobookPlaybackBookmark] {
    guard let currentTrack = player.currentTrack, player.isCurrentAudiobook else { return [] }
    let albumKey = player.audiobookAlbumKey(for: currentTrack)
    return player.audiobookBookmarks.filter { $0.albumKey == albumKey }
  }

  private func audiobookTitle(_ albumKey: String) -> String {
    let parts = albumKey.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2 else { return albumKey }
    return "\(parts[1]) — \(parts[0])"
  }

  var body: some View {
    NavigationStack {
      List {
        Section(
          content: {
            Button {
              player.addBookmarkAtCurrentPosition()
            } label: {
              Label("Bookmark Current Position", systemImage: "bookmark.badge.plus")
            }
            .disabled(player.currentTrack == nil)
          },
          header: { EmptyView() },
          footer: {
            Text(
              "Bookmarks are saved for this track and remain available after restarting Resonance.")
          }
        )

        if !currentAudiobookPositions.isEmpty {
          Section("Recent Audiobook Positions") {
            ForEach(currentAudiobookPositions) { bookmark in
              Button {
                player.playAudiobookBookmark(bookmark)
                dismiss()
              } label: {
                HStack {
                  Image(systemName: "book.closed.fill")
                  VStack(alignment: .leading, spacing: 2) {
                    Text(format(bookmark.time))
                      .font(.headline.monospacedDigit())
                    Text(audiobookTitle(bookmark.albumKey))
                      .font(.caption)
                      .lineLimit(1)
                      .foregroundStyle(.secondary)
                    if let track = player.queue.first(where: { $0.id == bookmark.trackID }) {
                      Text(track.title)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    }
                  }
                  Spacer()
                  Image(systemName: "arrow.right.circle")
                    .foregroundStyle(.secondary)
                }
              }
              .buttonStyle(.plain)
              .disabled(!player.queue.contains { $0.id == bookmark.trackID })
            }
          }
        }

        Section("Saved Positions") {
          if player.currentTrackBookmarks.isEmpty {
            ContentUnavailableView(
              "No Bookmarks",
              systemImage: "bookmark",
              description: Text("Add a bookmark to return to an exact point in this track.")
            )
          } else {
            ForEach(player.currentTrackBookmarks) { bookmark in
              Button {
                player.seek(to: bookmark)
                dismiss()
              } label: {
                HStack {
                  Image(systemName: "bookmark.fill")
                  VStack(alignment: .leading, spacing: 2) {
                    Text(format(bookmark.time))
                      .font(.headline.monospacedDigit())
                    Text(bookmark.createdAt.formatted(date: .abbreviated, time: .shortened))
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                  Spacer()
                  Image(systemName: "arrow.right.circle")
                    .foregroundStyle(.secondary)
                }
              }
              .buttonStyle(.plain)
            }
            .onDelete(perform: player.removeBookmarks)
          }
        }

      }
      .navigationTitle("Playback Bookmarks")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}

struct PlaybackQueueView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var player: PlayerController

  var body: some View {
    NavigationStack {
      List {
        if let current = player.currentTrack {
          Section("Now Playing") {
            queueRow(current, isCurrent: true)
          }
        }

        Section("Up Next") {
          if player.upcomingTracks.isEmpty {
            ContentUnavailableView(
              "Queue Is Empty",
              systemImage: "text.line.last.and.arrowtriangle.forward",
              description: Text("Choose an album or song to create a new playback queue.")
            )
          } else {
            ForEach(player.upcomingTracks) { track in
              Button {
                player.playQueueItem(track)
              } label: {
                queueRow(track, isCurrent: false)
              }
              .buttonStyle(.plain)
            }
            .onDelete(perform: player.removeUpcoming)
            .onMove(perform: player.moveUpcoming)

            Button(role: .destructive) {
              player.clearUpcoming()
            } label: {
              Label("Clear Upcoming Tracks", systemImage: "trash")
            }
          }
        }
      }
      .navigationTitle("Playback Queue")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          if !player.upcomingTracks.isEmpty {
            EditButton()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }

  private func queueRow(_ track: Track, isCurrent: Bool) -> some View {
    HStack(spacing: 10) {
      ArtworkView(
        data: player.artworkData(for: track),
        embedded: player.artworkIsEmbedded(for: track),
        size: 44
      )
      if isCurrent {
        PlayingTrackVisualizer(track: track)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(track.title)
          .font(.subheadline.weight(isCurrent ? .semibold : .regular))
          .lineLimit(1)
        Text("\(track.artist) — \(track.album)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
      if isCurrent {
        Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
          .foregroundStyle(.tint)
      }
    }
    .contentShape(Rectangle())
  }
}

struct MiniPlayerView: View {
  @EnvironmentObject private var settings: AppSettings
  @EnvironmentObject private var player: PlayerController
  let dock: MiniPlayerDock
  let openNowPlaying: () -> Void
  let onDock: (MiniPlayerDock) -> Void

  var body: some View {
    HStack(spacing: 10) {
      Button(action: openNowPlaying) {
        HStack(spacing: 10) {
          if let track = player.currentTrack {
            ArtworkView(
              data: player.artworkData(for: track),
              embedded: player.artworkIsEmbedded(for: track),
              size: 42
            )
            PlayingTrackVisualizer(track: track)
          }
          VStack(alignment: .leading, spacing: 2) {
            Text(player.currentTrack?.title ?? "")
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
            Text(player.currentTrack?.artist ?? "")
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
      }
      .buttonStyle(.plain)

      Spacer(minLength: 10)

      HStack(spacing: 20) {
        Button {
          onDock(dock == .top ? .bottom : .top)
        } label: {
          Image(systemName: dock == .top ? "arrow.down" : "arrow.up")
            .frame(width: 30, height: 36)
        }
        .accessibilityLabel(dock == .top ? "Move mini player to bottom" : "Move mini player to top")

        Button(action: player.previous) {
          Image(systemName: "backward.fill")
            .frame(width: 30, height: 36)
        }
        .accessibilityLabel("Previous track")

        Button(action: player.toggle) {
          Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
            .frame(width: 34, height: 36)
        }
        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

        Button(action: player.next) {
          Image(systemName: "forward.fill")
            .frame(width: 30, height: 36)
        }
        .accessibilityLabel("Next track")
      }
      .font(.title3)
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(settings.themeSurfaceGradient.opacity(0.28))
        }
    }
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(settings.accentColor.opacity(0.3), lineWidth: 1)
    }
    .shadow(radius: 5, y: 2)
  }
}
