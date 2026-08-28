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
        sqlite3_exec(db, "BEGIN; CREATE TEMP TABLE IF NOT EXISTS resonance_incoming_track_ids (id TEXT PRIMARY KEY); DELETE FROM resonance_incoming_track_ids;", nil, nil, nil)
        let sql = """
        INSERT INTO tracks
        (id,title,artist,album_artist,album_name,track_number,disc_number,release_year,duration,file_url,artwork,artwork_embedded,date_added)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET
          title=excluded.title,
          artist=excluded.artist,
          album_artist=excluded.album_artist,
          album_name=excluded.album_name,
          track_number=excluded.track_number,
          disc_number=excluded.disc_number,
          release_year=excluded.release_year,
          duration=excluded.duration,
          file_url=excluded.file_url,
          artwork=COALESCE(excluded.artwork, tracks.artwork),
          artwork_embedded=CASE WHEN excluded.artwork IS NULL THEN tracks.artwork_embedded ELSE excluded.artwork_embedded END,
          date_added=excluded.date_added;
        """
        var statement: OpaquePointer?
        var idStatement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK; DROP TABLE IF EXISTS resonance_incoming_track_ids;", nil, nil, nil)
            return
        }
        guard sqlite3_prepare_v2(db, "INSERT OR IGNORE INTO resonance_incoming_track_ids (id) VALUES (?);", -1, &idStatement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            sqlite3_exec(db, "ROLLBACK; DROP TABLE IF EXISTS resonance_incoming_track_ids;", nil, nil, nil)
            return
        }
        defer {
            sqlite3_finalize(statement)
            sqlite3_finalize(idStatement)
            sqlite3_exec(db, "DELETE FROM tracks WHERE id NOT IN (SELECT id FROM resonance_incoming_track_ids); DROP TABLE IF EXISTS resonance_incoming_track_ids; COMMIT;", nil, nil, nil)
        }
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

            sqlite3_reset(idStatement)
            sqlite3_clear_bindings(idStatement)
            bind(track.id.uuidString, 1, idStatement)
            sqlite3_step(idStatement)
        }
    }

    func upsert(_ track: Track) {
        guard let db else { return }
        let sql = """
        INSERT INTO tracks
        (id,title,artist,album_artist,album_name,track_number,disc_number,release_year,duration,file_url,artwork,artwork_embedded,date_added)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET
          title=excluded.title,
          artist=excluded.artist,
          album_artist=excluded.album_artist,
          album_name=excluded.album_name,
          track_number=excluded.track_number,
          disc_number=excluded.disc_number,
          release_year=excluded.release_year,
          duration=excluded.duration,
          file_url=excluded.file_url,
          artwork=COALESCE(excluded.artwork, tracks.artwork),
          artwork_embedded=CASE WHEN excluded.artwork IS NULL THEN tracks.artwork_embedded ELSE excluded.artwork_embedded END,
          date_added=excluded.date_added;
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

    func delete(ids: Set<UUID>) {
        guard let db, !ids.isEmpty else { return }
        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
        let sql = "DELETE FROM tracks WHERE id IN (\(placeholders));"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        for (index, id) in ids.enumerated() {
            bind(id.uuidString, Int32(index + 1), statement)
        }
        sqlite3_step(statement)
    }

    func loadAll(includeArtwork: Bool = true) -> [Track] {
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
                guard includeArtwork else { return nil }
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
