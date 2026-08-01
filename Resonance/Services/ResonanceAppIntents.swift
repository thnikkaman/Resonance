import AppIntents
import Foundation

@MainActor
final class ResonanceAppIntentRuntime {
    static let shared = ResonanceAppIntentRuntime()

    private weak var library: LibraryStore?
    private weak var player: PlayerController?
    private weak var remoteLibrary: RemoteLibraryStore?

    func configure(
        library: LibraryStore,
        player: PlayerController,
        remoteLibrary: RemoteLibraryStore
    ) {
        self.library = library
        self.player = player
        self.remoteLibrary = remoteLibrary
    }

    func playSong(named name: String) async throws {
        guard let player else { throw ResonanceIntentError.runtimeUnavailable }
        let query = name.resonanceIntentQuery

        if let local = library?.tracks.first(where: { $0.title.resonanceIntentQuery == query }) {
            player.play(local, in: library?.tracks ?? [local])
            return
        }

        if let remote = remoteLibrary?.tracks.first(where: { $0.title.resonanceIntentQuery == query }),
           let remoteLibrary
        {
            await remoteLibrary.play(remote, in: remoteLibrary.tracks, using: player)
            return
        }

        throw ResonanceIntentError.notFound("I couldn't find the song \(name) in Resonance.")
    }

    func playAlbum(named name: String) async throws {
        guard let player else { throw ResonanceIntentError.runtimeUnavailable }
        let query = name.resonanceIntentQuery

        if let local = library?.albums.first(where: { $0.title.resonanceIntentQuery == query }) {
            player.resumeAudiobookAlbum(local.tracks, albumArtist: local.artist, album: local.title)
            return
        }

        if let remote = remoteLibrary?.albums.first(where: { $0.title.resonanceIntentQuery == query }),
           let remoteLibrary
        {
            await remoteLibrary.playAlbum(remote, using: player)
            return
        }

        throw ResonanceIntentError.notFound("I couldn't find the album \(name) in Resonance.")
    }

    func playArtist(named name: String) async throws {
        guard let player else { throw ResonanceIntentError.runtimeUnavailable }
        let query = name.resonanceIntentQuery

        if let local = library?.artists.first(where: { $0.name.resonanceIntentQuery == query }) {
            let tracks = local.albums.flatMap(\.tracks)
            guard let first = tracks.first else { throw ResonanceIntentError.notFound("That artist has no playable tracks.") }
            player.play(first, in: tracks)
            return
        }

        if let remote = remoteLibrary?.artists.first(where: { $0.name.resonanceIntentQuery == query }),
           let remoteLibrary
        {
            await remoteLibrary.playArtist(remote, using: player)
            return
        }

        throw ResonanceIntentError.notFound("I couldn't find the artist \(name) in Resonance.")
    }

    func resumeAudiobook() async throws {
        guard let player, let library else { throw ResonanceIntentError.runtimeUnavailable }
        let candidates = library.albums.filter { player.isAudiobook(albumArtist: $0.artist, album: $0.title) }
        guard !candidates.isEmpty else {
            throw ResonanceIntentError.notFound("I couldn't find a marked audiobook in Resonance.")
        }

        let candidateKeys = Set(candidates.map { PlayerController.audiobookAlbumKey(albumArtist: $0.artist, album: $0.title) })
        let bookmark = player.audiobookBookmarks
            .filter { candidateKeys.contains($0.albumKey) }
            .max { $0.createdAt < $1.createdAt }

        if let bookmark,
           let album = candidates.first(where: {
               PlayerController.audiobookAlbumKey(albumArtist: $0.artist, album: $0.title) == bookmark.albumKey
           })
        {
            player.resumeAudiobookAlbum(album.tracks, albumArtist: album.artist, album: album.title)
            return
        }

        let album = candidates[0]
        player.resumeAudiobookAlbum(album.tracks, albumArtist: album.artist, album: album.title)
    }
}

private enum ResonanceIntentError: LocalizedError {
    case runtimeUnavailable
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .runtimeUnavailable:
            return "Resonance is still starting. Please try again."
        case .notFound(let message):
            return message
        }
    }
}

private extension String {
    var resonanceIntentQuery: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ResonanceMediaEntity: AppEntity, Identifiable, Sendable {
    let id: String
    @Property(title: "Name")
    var title: String

    init(id: String, title: String) {
        self.id = id
        self.title = title
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Resonance media")
    static let defaultQuery = ResonanceMediaEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct ResonanceMediaEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ResonanceMediaEntity] {
        identifiers.map { ResonanceMediaEntity(id: $0, title: $0) }
    }

    func suggestedEntities() async throws -> [ResonanceMediaEntity] {
        []
    }

    func entities(matching string: String) async throws -> [ResonanceMediaEntity] {
        let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return [] }
        return [ResonanceMediaEntity(id: value, title: value)]
    }
}

struct ResonancePlaySongIntent: AppIntent {
    static let title: LocalizedStringResource = "Play Song"
    static let description = IntentDescription("Play a song in Resonance.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Song")
    var song: ResonanceMediaEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await ResonanceAppIntentRuntime.shared.playSong(named: song.title)
        return .result(dialog: "Playing \(song.title) in Resonance.")
    }
}

struct ResonancePlayAlbumIntent: AppIntent {
    static let title: LocalizedStringResource = "Play Album"
    static let description = IntentDescription("Play an album in Resonance.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Album")
    var album: ResonanceMediaEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await ResonanceAppIntentRuntime.shared.playAlbum(named: album.title)
        return .result(dialog: "Playing \(album.title) in Resonance.")
    }
}

struct ResonancePlayArtistIntent: AppIntent {
    static let title: LocalizedStringResource = "Play Artist"
    static let description = IntentDescription("Play an artist in Resonance.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Artist")
    var artist: ResonanceMediaEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await ResonanceAppIntentRuntime.shared.playArtist(named: artist.title)
        return .result(dialog: "Playing \(artist.title) in Resonance.")
    }
}

struct ResonanceResumeAudiobookIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Audiobook"
    static let description = IntentDescription("Resume the most recently bookmarked audiobook in Resonance.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await ResonanceAppIntentRuntime.shared.resumeAudiobook()
        return .result(dialog: "Resuming your audiobook in Resonance.")
    }
}

struct ResonanceAppShortcuts: AppShortcutsProvider {
    nonisolated(unsafe) static let appShortcuts: [AppShortcut] = [
            AppShortcut(
                intent: ResonancePlaySongIntent(),
                phrases: ["Play \(\.$song) in \(.applicationName)"],
                shortTitle: "Play Song",
                systemImageName: "play.fill"
            ),
            AppShortcut(
                intent: ResonancePlayAlbumIntent(),
                phrases: ["Play \(\.$album) in \(.applicationName)"],
                shortTitle: "Play Album",
                systemImageName: "square.stack.fill"
            ),
            AppShortcut(
                intent: ResonancePlayArtistIntent(),
                phrases: ["Play \(\.$artist) in \(.applicationName)"],
                shortTitle: "Play Artist",
                systemImageName: "person.fill"
            ),
            AppShortcut(
                intent: ResonanceResumeAudiobookIntent(),
                phrases: ["Resume my audiobook in \(.applicationName)"],
                shortTitle: "Resume Audiobook",
                systemImageName: "bookmark.fill"
            )
        ]
}
