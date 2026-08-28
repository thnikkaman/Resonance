import Foundation

/// The metadata needed to calculate stable browse identities is shared by
/// local and remote tracks. The stores still own loading, caching, and view
/// model construction; this type only centralizes pure identity rules.
protocol LibraryBrowseTrack {
    var artist: String { get }
    var album: String { get }
    var releaseYear: Int { get }
}

enum LibraryBrowseGrouping {
    static func mixedArtistAlbumIdentity<T: LibraryBrowseTrack>(for track: T) -> String {
        [
            track.album.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            track.releaseYear > 0 ? String(track.releaseYear) : ""
        ].joined(separator: "|")
    }

    static func mixedArtistAlbumKeys<T>(
        in tracks: [T],
        albumIdentity: (T) -> String,
        artistIdentity: (T) -> String
    ) -> Set<String> {
        Dictionary(grouping: tracks, by: albumIdentity)
            .compactMap { key, albumTracks in
                let artistKeys = Set(
                    albumTracks.map(artistIdentity).filter { !$0.isEmpty }
                )
                return artistKeys.count > 1 ? key : nil
            }
            .reduce(into: Set<String>()) { result, key in
                result.insert(key)
            }
    }
}

extension Track: LibraryBrowseTrack {}
extension RemoteTrackItem: LibraryBrowseTrack {}
