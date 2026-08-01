import Foundation
import SwiftUI

struct Track: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var title: String
    var artist: String
    var albumArtist: String
    var album: String
    var trackNumber: Int
    var discNumber: Int
    var releaseYear: Int
    var duration: Double
    var fileURL: URL?
    var artworkData: Data?
    var artworkIsEmbedded: Bool
    var dateAdded: Date
    var sourceByteSize: Int64

    init(
        id: UUID = UUID(), title: String, artist: String, albumArtist: String = "",
        album: String, trackNumber: Int = 0, discNumber: Int = 1,
        releaseYear: Int = 0, duration: Double = 0, fileURL: URL? = nil,
        artworkData: Data? = nil, artworkIsEmbedded: Bool = false,
        dateAdded: Date = Date(), sourceByteSize: Int64 = 0
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.albumArtist = albumArtist.isEmpty ? artist : albumArtist
        self.album = album
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.releaseYear = releaseYear
        self.duration = duration
        self.fileURL = fileURL
        self.artworkData = artworkData
        self.artworkIsEmbedded = artworkIsEmbedded
        self.dateAdded = dateAdded
        self.sourceByteSize = sourceByteSize
    }
    var isRemote: Bool {
        guard let scheme = fileURL?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

}

struct Album: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let tracks: [Track]

    var artworkData: Data? { tracks.compactMap(\.artworkData).first }
    var artworkIsEmbedded: Bool { tracks.first(where: { $0.artworkData != nil })?.artworkIsEmbedded ?? true }
    var isFlacOnly: Bool {
        !tracks.isEmpty && tracks.allSatisfy {
            $0.fileURL?.pathExtension.caseInsensitiveCompare("flac") == .orderedSame
        }
    }
    var releaseYear: Int { tracks.map(\.releaseYear).filter { $0 > 0 }.min() ?? 0 }
    var yearLabel: String { releaseYear > 0 ? String(releaseYear) : "Release date unavailable" }
}

struct UserPlaylist: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var trackIDs: [UUID]
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        trackIDs: [UUID] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.trackIDs = trackIDs
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

struct Artist: Identifiable, Hashable {
    let id: String
    let name: String
    let albums: [Album]
    let usesAlbumArtist: Bool
    let customArtworkData: Data?
    let hasArtworkOverride: Bool
    let hasMetadataOverride: Bool

    init(
        id: String,
        name: String,
        albums: [Album],
        usesAlbumArtist: Bool = false,
        customArtworkData: Data? = nil,
        hasArtworkOverride: Bool = false,
        hasMetadataOverride: Bool = false
    ) {
        self.id = id
        self.name = name
        self.albums = albums
        self.usesAlbumArtist = usesAlbumArtist
        self.customArtworkData = customArtworkData
        self.hasArtworkOverride = hasArtworkOverride
        self.hasMetadataOverride = hasMetadataOverride
    }

    var artworkData: Data? {
        customArtworkData ?? albums.compactMap(\.artworkData).first
    }

    var artworkIsEmbedded: Bool {
        customArtworkData == nil && !hasArtworkOverride
            ? (albums.first(where: { $0.artworkData != nil })?.artworkIsEmbedded ?? true)
            : false
    }
}

enum LibraryGrouping: String, CaseIterable, Identifiable {
    case artists = "Artists"
    case albumArtists = "Album Artists"
    case albums = "Albums"
    case songs = "Songs"
    case favorites = "Favorites"
    case recentlyAdded = "Recently Added"
    case recentlyPlayed = "Recently Played"
    var id: String { rawValue }
}

enum SortDirection: String, CaseIterable, Identifiable {
    case ascending = "Ascending"
    case descending = "Descending"
    var id: String { rawValue }
}

enum AlbumLayout: String, CaseIterable, Identifiable {
    case grid = "Grid"
    case compact = "Compact"
    case large = "Large"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grid: "Album Artwork Grid"
        case .compact: "Compact List"
        case .large: "Large List"
        }
    }
}

enum ArtistAlbumLayout: String, CaseIterable, Identifiable {
    case grid = "Grid"
    case list = "List"
    var id: String { rawValue }
}

enum ArtistAlbumSort: String, CaseIterable, Identifiable {
    case title = "Album Title (A–Z)"
    case newest = "Release Date (Newest First)"
    case oldest = "Release Date (Oldest First)"
    var id: String { rawValue }
}

enum LibraryThumbnailSize: String, CaseIterable, Identifiable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    var id: String { rawValue }

    var points: CGFloat {
        switch self {
        case .small: 24
        case .medium: 36
        case .large: 50
        }
    }

    var gridColumnCount: Int {
        switch self {
        case .small: 4
        case .medium: 3
        case .large: 2
        }
    }

    var gridArtworkPoints: CGFloat {
        switch self {
        case .small: 72
        case .medium: 108
        case .large: 156
        }
    }
}

enum LibraryTextSize: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case standard = "Standard"
    case large = "Large"
    var id: String { rawValue }

    var font: Font {
        switch self {
        case .compact: .caption
        case .standard: .subheadline
        case .large: .body
        }
    }
}

struct TrackMetadataOverride: Codable, Sendable {
    var title: String?
    var artist: String?
    var albumArtist: String?
    var album: String?
    var trackNumber: Int?
    var discNumber: Int?
    var releaseYear: Int?
    var artworkData: Data?
    var artworkFileName: String?
    var hasArtworkOverride = false

    func applying(to track: Track) -> Track {
        var updated = track
        if let title, !title.isEmpty { updated.title = title }
        if let artist, !artist.isEmpty { updated.artist = artist }
        if let albumArtist, !albumArtist.isEmpty { updated.albumArtist = albumArtist }
        if let album, !album.isEmpty { updated.album = album }
        if let trackNumber { updated.trackNumber = max(0, trackNumber) }
        if let discNumber { updated.discNumber = max(1, discNumber) }
        if let releaseYear { updated.releaseYear = max(0, releaseYear) }
        if hasArtworkOverride {
            updated.artworkData = artworkData
            updated.artworkIsEmbedded = false
        }
        return updated
    }
}

struct ArtistMetadataOverride: Codable, Sendable {
    var artworkData: Data?
    var artworkFileName: String?
    var hasArtworkOverride = false
}
