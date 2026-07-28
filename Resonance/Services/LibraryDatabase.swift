import Foundation
import SQLite3

private final class SQLiteConnection: @unchecked Sendable {
    var pointer: OpaquePointer?

    deinit {
        if let pointer { sqlite3_close(pointer) }
    }
}

actor LibraryDatabase {
    private let connection = SQLiteConnection()
    private var db: OpaquePointer? { connection.pointer }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let path = base.appendingPathComponent("resonance.sqlite").path
        var openedDatabase: OpaquePointer?
        if sqlite3_open(path, &openedDatabase) == SQLITE_OK {
            connection.pointer = openedDatabase
            Self.createSchema(on: openedDatabase)
        } else if let openedDatabase {
            sqlite3_close(openedDatabase)
        }
    }

    private static func createSchema(on db: OpaquePointer?) {
        let sql = """
        CREATE TABLE IF NOT EXISTS tracks (
          id TEXT PRIMARY KEY, title TEXT NOT NULL, artist TEXT NOT NULL,
          album_artist TEXT NOT NULL, album_name TEXT NOT NULL,
          track_number INTEGER, disc_number INTEGER, release_year INTEGER DEFAULT 0,
          duration REAL, file_url TEXT UNIQUE, artwork BLOB, artwork_embedded INTEGER,
          date_added REAL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_artist ON tracks(artist);
        CREATE INDEX IF NOT EXISTS idx_album ON tracks(album_name);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE tracks ADD COLUMN release_year INTEGER DEFAULT 0;", nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE tracks ADD COLUMN date_added REAL DEFAULT 0;", nil, nil, nil)
    }

    func replaceAll(with tracks: [Track]) {
        guard let db else { return }
        sqlite3_exec(db, "BEGIN; DELETE FROM tracks;", nil, nil, nil)
        let sql = """
        INSERT OR REPLACE INTO tracks
        (id,title,artist,album_artist,album_name,track_number,disc_number,release_year,duration,file_url,artwork,artwork_embedded,date_added)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return
        }
        defer { sqlite3_finalize(statement); sqlite3_exec(db, "COMMIT;", nil, nil, nil) }
        for track in tracks {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            bind(track.id.uuidString, 1, statement)
            bind(track.title, 2, statement)
            bind(track.artist, 3, statement)
            bind(track.albumArtist, 4, statement)
            bind(track.album, 5, statement)
            sqlite3_bind_int(statement, 6, Int32(track.trackNumber))
            sqlite3_bind_int(statement, 7, Int32(track.discNumber))
            sqlite3_bind_int(statement, 8, Int32(track.releaseYear))
            sqlite3_bind_double(statement, 9, track.duration)
            bind(persistedPath(for: track.fileURL), 10, statement)
            if let data = track.artworkData {
                _ = data.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(statement, 11, buffer.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
                }
            } else { sqlite3_bind_null(statement, 11) }
            sqlite3_bind_int(statement, 12, track.artworkIsEmbedded ? 1 : 0)
            sqlite3_bind_double(statement, 13, track.dateAdded.timeIntervalSince1970)
            sqlite3_step(statement)
        }
    }

    func upsert(_ track: Track) {
        guard let db else { return }
        let sql = """
        INSERT OR REPLACE INTO tracks
        (id,title,artist,album_artist,album_name,track_number,disc_number,release_year,duration,file_url,artwork,artwork_embedded,date_added)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        bind(track.id.uuidString, 1, statement)
        bind(track.title, 2, statement)
        bind(track.artist, 3, statement)
        bind(track.albumArtist, 4, statement)
        bind(track.album, 5, statement)
        sqlite3_bind_int(statement, 6, Int32(track.trackNumber))
        sqlite3_bind_int(statement, 7, Int32(track.discNumber))
        sqlite3_bind_int(statement, 8, Int32(track.releaseYear))
        sqlite3_bind_double(statement, 9, track.duration)
        bind(persistedPath(for: track.fileURL), 10, statement)
        if let data = track.artworkData {
            _ = data.withUnsafeBytes { buffer in
                sqlite3_bind_blob(statement, 11, buffer.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
            }
        } else { sqlite3_bind_null(statement, 11) }
        sqlite3_bind_int(statement, 12, track.artworkIsEmbedded ? 1 : 0)
        sqlite3_bind_double(statement, 13, track.dateAdded.timeIntervalSince1970)
        sqlite3_step(statement)
    }

    func loadAll() -> [Track] {
        guard let db else { return [] }
        let sql = """
        SELECT id,title,artist,album_artist,album_name,track_number,disc_number,
               release_year,duration,file_url,artwork,artwork_embedded,date_added
        FROM tracks;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        var result: [Track] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let artwork: Data? = {
                guard let bytes = sqlite3_column_blob(statement, 10) else { return nil }
                let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 10)))
                return MetadataReader.renderableArtworkData(from: data)
            }()
            result.append(Track(
                id: UUID(uuidString: text(statement, 0)) ?? UUID(),
                title: text(statement, 1), artist: text(statement, 2),
                albumArtist: text(statement, 3), album: text(statement, 4),
                trackNumber: Int(sqlite3_column_int(statement, 5)),
                discNumber: Int(sqlite3_column_int(statement, 6)),
                releaseYear: Int(sqlite3_column_int(statement, 7)),
                duration: sqlite3_column_double(statement, 8),
                fileURL: resolvedURL(from: text(statement, 9)), artworkData: artwork,
                artworkIsEmbedded: sqlite3_column_int(statement, 11) == 1,
                dateAdded: Self.dateAdded(from: sqlite3_column_double(statement, 12), fileURL: resolvedURL(from: text(statement, 9)))
            ))
        }
        return result
    }

    private static func dateAdded(from timestamp: Double, fileURL: URL?) -> Date {
        if timestamp > 0 { return Date(timeIntervalSince1970: timestamp) }
        guard let fileURL else { return .distantPast }
        let values = try? fileURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return values?.creationDate ?? values?.contentModificationDate ?? .distantPast
    }

    private func persistedPath(for url: URL?) -> String? {
        guard let url else { return nil }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path = url.standardizedFileURL.path
        let base = documents.standardizedFileURL.path + "/"
        if path.hasPrefix(base) { return "documents://" + String(path.dropFirst(base.count)) }
        return url.absoluteString
    }

    private func resolvedURL(from stored: String) -> URL? {
        guard !stored.isEmpty else { return nil }
        if stored.hasPrefix("documents://") {
            let relative = String(stored.dropFirst("documents://".count))
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(relative)
        }
        if let old = URL(string: stored), old.isFileURL {
            let marker = "/Documents/"
            if let range = old.path.range(of: marker) {
                let relative = String(old.path[range.upperBound...])
                return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(relative)
            }
            return old
        }
        return URL(string: stored)
    }

    private func bind(_ string: String?, _ index: Int32, _ statement: OpaquePointer?) {
        guard let string else { sqlite3_bind_null(statement, index); return }
        sqlite3_bind_text(statement, index, string, -1, SQLITE_TRANSIENT)
    }

    private func text(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let c = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: c)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
