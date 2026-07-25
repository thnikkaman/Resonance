import SwiftUI

struct NowPlayingView: View {
  @EnvironmentObject private var player: PlayerController
  @EnvironmentObject private var library: LibraryStore
  @EnvironmentObject private var settings: AppSettings
  @State private var showingQueue = false
  @State private var showingBookmarks = false
  @State private var showingPlaylistPicker = false
  let openLibrary: () -> Void

  private var currentTrackIsFavorite: Bool {
    guard let track = player.currentTrack else { return false }
    return library.isFavorite(track)
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        Spacer(minLength: 4)

      VStack(spacing: 16) {
        NowPlayingArtworkPager()

        VStack(spacing: 5) {
          Text(player.currentTrack?.title ?? "Nothing Playing")
            .font(.title2.bold())
            .lineLimit(1)
          Text(
            player.currentTrack.map { "\($0.artist) — \($0.album)" }
              ?? "Choose music from your library"
          )
          .foregroundStyle(.secondary)
          .lineLimit(1)
          Text(
            player.currentTrack.map {
              "Length \(format(player.duration > 0 ? player.duration : $0.duration))"
            } ?? "Length —"
          )
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)

          if player.currentTrack != nil {
            Label(
              player.preloadedTrackTitle.map { "Gapless ready: \($0)" }
                ?? player.playbackEngineStatus,
              systemImage: player.preloadedTrackTitle == nil ? "waveform" : "waveform.badge.plus"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          }
        }
      }

      TrackScrubber()
        .frame(maxWidth: 320)

      HStack(spacing: 23) {
        Button(action: player.previous) {
          Image(systemName: "backward.fill")
        }
        .accessibilityLabel("Previous track")

        Button {
          player.skip(by: -15)
        } label: {
          Image(systemName: "gobackward.15")
        }
        .accessibilityLabel("Rewind 15 seconds")

        Button(action: player.toggle) {
          Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
            .font(.system(size: 42))
        }
        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

        Button {
          player.skip(by: 15)
        } label: {
          Image(systemName: "goforward.15")
        }
        .accessibilityLabel("Jump ahead 15 seconds")

        Button(action: player.next) {
          Image(systemName: "forward.fill")
        }
        .accessibilityLabel("Next track")
      }
      .font(.title2)

      HStack(spacing: 24) {
        Button {
          if let track = player.currentTrack { library.toggleFavorite(track) }
        } label: {
          Image(systemName: currentTrackIsFavorite ? "heart.fill" : "heart")
            .foregroundStyle(currentTrackIsFavorite ? settings.accentColor : .secondary)
        }
        .disabled(player.currentTrack == nil)
        .accessibilityLabel(currentTrackIsFavorite ? "Remove from favorites" : "Add to favorites")

        Button {
          showingBookmarks = true
        } label: {
          Image(systemName: player.currentTrackBookmarks.isEmpty ? "bookmark" : "bookmark.fill")
            .foregroundStyle(
              player.currentTrackBookmarks.isEmpty ? Color.secondary : settings.accentColor
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

        Button(action: player.toggleShuffle) {
          Image(systemName: "shuffle")
            .foregroundStyle(player.shuffleEnabled ? settings.accentColor : .secondary)
        }
        .accessibilityLabel(player.shuffleEnabled ? "Turn shuffle off" : "Turn shuffle on")

        Button(action: player.cycleRepeatMode) {
          Image(systemName: player.repeatMode.systemImage)
            .foregroundStyle(player.repeatMode == .off ? Color.secondary : settings.accentColor)
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

        Button {
          showingQueue = true
        } label: {
          Image(systemName: "list.bullet")
        }
        .accessibilityLabel("Show playback queue")

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
              player.sleepTimerOption == .off ? Color.secondary : settings.accentColor)
        }
        .accessibilityLabel("Sleep timer: \(player.sleepTimerLabel)")
      }
      .font(.title3)

      HStack(spacing: 10) {
        Image(systemName: "speaker.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
        Slider(value: $player.volume, in: 0...1)
        Image(systemName: "speaker.wave.3.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: 300)

      if player.sleepTimerOption != .off {
        Label("Sleep timer: \(player.sleepTimerLabel)", systemImage: "moon.zzz.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
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
        Spacer(minLength: 4)
      }
      .padding(24)
      .padding(.bottom, 76)
    }
    .scrollIndicators(.hidden)
    .scrollDismissesKeyboard(.interactively)
    .navigationTitle("Now Playing")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button(action: openLibrary) {
          Label("Library", systemImage: "chevron.left")
        }
      }
      ToolbarItemGroup(placement: .topBarTrailing) {
        if player.currentTrack != nil {
          Button {
            showingPlaylistPicker = true
          } label: {
            Image(systemName: "text.badge.plus")
          }
          .accessibilityLabel(
            library.playlists.isEmpty ? "Add a playlist" : "Add current track to playlist")
        }

        Button {
          showingQueue = true
        } label: {
          Label("Queue", systemImage: "list.bullet")
        }
      }
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
      .frame(width: pageWidth, height: 294, alignment: .leading)
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
    .frame(height: 294)
  }

  @ViewBuilder
  private func artworkPage(_ track: Track?, pageWidth: CGFloat) -> some View {
    HStack {
      Spacer(minLength: 0)
      CachedPagerArtwork(
        trackID: track?.id,
        data: track.flatMap { player.artworkData(for: $0) },
        embedded: track.map { player.artworkIsEmbedded(for: $0) } ?? true
      )
      .shadow(radius: 18, y: 8)
      .accessibilityLabel(track.map { "\($0.album) artwork" } ?? "No adjacent track")
      Spacer(minLength: 0)
    }
    .frame(width: pageWidth, height: 294)
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
  @EnvironmentObject private var settings: AppSettings
  let trackID: UUID?
  let data: Data?
  let embedded: Bool
  @State private var image: UIImage?

  var body: some View {
    Group {
      if let image {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        ZStack {
          LinearGradient(
            colors: [.secondary.opacity(0.35), .secondary.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          Image(systemName: "music.note")
            .font(.system(size: 90))
            .foregroundStyle(.secondary)
        }
      }
    }
    .frame(width: 286, height: 286)
    .clipShape(RoundedRectangle(cornerRadius: 23))
    .overlay {
      if settings.showArtworkWarning && data != nil && !embedded {
        RoundedRectangle(cornerRadius: 23).stroke(.red, lineWidth: 1)
      }
    }
    .onAppear(perform: decodeArtwork)
    .onChange(of: trackID) { _, _ in decodeArtwork() }
  }

  private func decodeArtwork() {
    image = data.flatMap(UIImage.init(data:))
  }
}

private struct TrackScrubber: View {
  @EnvironmentObject private var player: PlayerController
  @EnvironmentObject private var settings: AppSettings
  @State private var previewTime: Double?
  @State private var fingerX: CGFloat = 0

  private var displayedTime: Double { previewTime ?? player.elapsed }
  private var isScrubbing: Bool { previewTime != nil }

  var body: some View {
    VStack(spacing: 8) {
      GeometryReader { proxy in
        let width = max(proxy.size.width, 1)
        let duration = max(player.duration, 1)
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
              // A drag covering 80% of the visible bar reaches the full track.
              let normalized = min(max(fingerX / max(1, width * 0.8), 0), 1)
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
        Text("−\(format(max(0, player.duration - displayedTime)))")
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
}

private struct PlaybackBookmarksView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var player: PlayerController

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
  @EnvironmentObject private var player: PlayerController
  let openNowPlaying: () -> Void

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
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    .shadow(radius: 5, y: 2)
  }
}
