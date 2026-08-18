import Foundation

struct LyricsCompanionMetadata: Sendable, Hashable {
    let id: String?
    let title: String?
    let album: String?
    let artist: String?
    let trackNumber: Int?
    let discNumber: Int?
}

/// Matches an audio file to an adjacent LRC while preserving the same-folder boundary.
///
/// Some audiobook importers prepend a disc/track number and replace title punctuation
/// in the audio filename without making the same changes to the companion LRC. The
/// normalized stem accommodates that representation difference; the normalized parent
/// path remains part of the key so an LRC from another folder can never match.
enum LyricsCompanionMatcher {
    static func metadata(from data: Data) -> LyricsCompanionMetadata? {
        let text = String(data: data, encoding: .utf8).flatMap { text in
            text.contains("\u{0000}") ? nil : text
        }
            ?? [String.Encoding.utf16LittleEndian, .utf16BigEndian, .utf16]
                .compactMap { encoding in String(data: data, encoding: encoding) }
                .first { text in text.contains("[") && !text.contains("\u{0000}") }
            ?? String(data: data, encoding: .utf32)
            ?? String(data: data, encoding: .isoLatin1)
        guard let text else { return nil }

        var values: [String: String] = [:]
        let supportedKeys: Set<String> = [
            "resonance-id", "id", "ti", "title", "al", "album", "ar", "artist", "au",
            "tr", "track", "tracknumber", "di", "disc", "discnumber"
        ]
        // `String.split` was not separating the CRLF records emitted by the
        // audiobook exporter on device.  `components(separatedBy: .newlines)`
        // handles CRLF, LF, and mixed line endings explicitly.
        for line in text.components(separatedBy: .newlines) {
            let rawLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard rawLine.first == "[" else { continue }
            let contentStart = rawLine.index(after: rawLine.startIndex)
            guard let closeBracket = rawLine.firstIndex(of: "]"), closeBracket > contentStart else { continue }
            let header = String(rawLine[contentStart..<closeBracket])
            let separator = [header.firstIndex(of: ":"), header.firstIndex(of: "=")]
                .compactMap { $0 }
                .min()
            let key: String
            var value: String
            if let separator {
                key = String(header[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                value = String(header[header.index(after: separator)...])
            } else {
                key = header.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                value = String(rawLine[rawLine.index(after: closeBracket)...])
            }
            guard supportedKeys.contains(key) else { continue }
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            while value.last == "]" { value = String(value.dropLast()) }
            if !value.isEmpty { values[key] = value }
        }

        let result = LyricsCompanionMetadata(
            id: values["resonance-id"] ?? values["id"],
            title: values["ti"] ?? values["title"],
            album: values["al"] ?? values["album"],
            artist: values["ar"] ?? values["artist"] ?? values["au"],
            trackNumber: integer(values["tr"] ?? values["track"] ?? values["tracknumber"]),
            discNumber: integer(values["di"] ?? values["disc"] ?? values["discnumber"])
        )
        return [result.id, result.title, result.album, result.artist].contains(where: { $0 != nil })
            || result.trackNumber != nil
            || result.discNumber != nil
            ? result : nil
    }

    static func metadataMatches(
        _ metadata: LyricsCompanionMetadata,
        title: String,
        album: String,
        artist: String,
        trackNumber: Int,
        discNumber: Int
    ) -> Bool {
        let titleMatch = metadata.title.map { titlesMatch($0, title) } ?? false
        let albumMatch = metadata.album.map { normalizedValue($0) == normalizedValue(album) } ?? false
        let artistMatch = metadata.artist.map { normalizedValue($0) == normalizedValue(artist) } ?? false
        let trackMatch = metadata.trackNumber.map { $0 == trackNumber && trackNumber > 0 } ?? false
        let discMatch = metadata.discNumber.map { $0 == discNumber && discNumber > 0 } ?? false
        if titleMatch && (albumMatch || trackMatch) { return true }
        if albumMatch && trackMatch && (discMatch || metadata.discNumber == nil) { return true }
        if titleMatch && trackMatch && (artistMatch || metadata.artist == nil) { return true }
        // A title-only LRC is still safe to use for an audiobook chapter: the
        // lookup is already constrained to the user's selected library folder,
        // and chapter titles are the stable identity when exporters omit album
        // and track headers.
        // The lookup has already been restricted to the MP3's own directory;
        // the chapter title is therefore sufficient when an exporter supplies
        // incomplete or non-canonical album/track fields.
        return titleMatch
    }

    static func matchKey(parentPath: String, stem: String) -> String {
        normalizedParentPath(parentPath) + "\u{001F}" + normalizedStem(stem)
    }

    static func normalizedStem(_ rawStem: String) -> String {
        let folded = rawStem
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        let audiobookStem: String
        if let chapterRange = folded.range(of: "chapter") {
            audiobookStem = String(folded[chapterRange.lowerBound...])
        } else {
            audiobookStem = folded.replacingOccurrences(
                of: #"^\s*\d+\s*[-_.]+\s*"#,
                with: "",
                options: .regularExpression
            )
        }
        // Metadata titles commonly use "Chapter 1" while exported sidecars
        // use "Chapter 01". Canonicalize that chapter number before removing
        // punctuation so the two representations remain equivalent.
        let canonicalChapterNumber = audiobookStem.replacingOccurrences(
            of: #"^chapter\s*0*(\d+)"#,
            with: "chapter$1",
            options: .regularExpression
        )
        return String(canonicalChapterNumber.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        })
    }

    private static func integer(_ value: String?) -> Int? {
        guard let value else { return nil }
        return Int(value.split(separator: "/").first?.filter(\.isNumber) ?? "")
    }

    private static func normalizedValue(_ value: String) -> String {
        String(value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }).lowercased()
    }

    private static func titlesMatch(_ lhs: String, _ rhs: String) -> Bool {
        normalizedValue(lhs) == normalizedValue(rhs)
            || normalizedStem(lhs) == normalizedStem(rhs)
    }

    private static func normalizedParentPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }
}
