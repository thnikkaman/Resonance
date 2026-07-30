import AVFoundation
import AudioToolbox
import Foundation
import ImageIO

struct MetadataReader {
    static let supportedExtensions: Set<String> = ["flac", "mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "alac"]

    func track(from url: URL) async -> Track? {
        guard Self.supportedExtensions.contains(url.pathExtension.lowercased()) else { return nil }

        let asset = AVURLAsset(url: url)
        let duration = (try? await asset.load(.duration).seconds) ?? 0
        let metadata = await loadAllMetadata(from: asset)
        let audioInfo = audioFileInfo(for: url)
        let flac = url.pathExtension.lowercased() == "flac" ? FLACMetadata.read(url: url) : nil

        var titleCandidate = flac?.first("TITLE")
        if titleCandidate == nil {
            titleCandidate = await firstString(keys: ["title", "tit2"], metadata: metadata, dictionary: audioInfo)
        }
        var title = titleCandidate ?? url.deletingPathExtension().lastPathComponent

        var artistCandidate = flac?.first("ARTIST")
        if artistCandidate == nil {
            artistCandidate = await firstString(keys: ["artist", "tpe1"], metadata: metadata, dictionary: audioInfo)
        }
        var artist = artistCandidate ?? "Unknown Artist"

        var albumArtistCandidate = flac?.first("ALBUMARTIST")
        if albumArtistCandidate == nil { albumArtistCandidate = flac?.first("ALBUM ARTIST") }
        if albumArtistCandidate == nil {
            albumArtistCandidate = await firstString(keys: ["albumartist", "album artist", "tpe2"], metadata: metadata, dictionary: audioInfo)
        }
        let albumArtist = albumArtistCandidate ?? artist

        var albumCandidate = flac?.first("ALBUM")
        if albumCandidate == nil {
            albumCandidate = await firstString(keys: ["album", "albumname", "talb"], metadata: metadata, dictionary: audioInfo)
        }
        var album = albumCandidate ?? "Unknown Album"

        var trackNumberCandidate = integer(flac?.first("TRACKNUMBER"))
        if trackNumberCandidate == nil {
            trackNumberCandidate = await firstInteger(keys: ["tracknumber", "track number", "trck"], metadata: metadata, dictionary: audioInfo)
        }
        let trackNumber = trackNumberCandidate ?? inferredNumber(from: url)

        var discNumberCandidate = integer(flac?.first("DISCNUMBER"))
        if discNumberCandidate == nil {
            discNumberCandidate = await firstInteger(keys: ["discnumber", "disc number", "tpos"], metadata: metadata, dictionary: audioInfo)
        }
        let discNumber = discNumberCandidate ?? 1

        var releaseYearCandidate = year(flac?.first("DATE") ?? flac?.first("YEAR") ?? flac?.first("ORIGINALDATE"))
        if releaseYearCandidate == nil {
            releaseYearCandidate = await firstYear(keys: ["date", "year", "releasedate", "tdrc", "day"], metadata: metadata, dictionary: audioInfo)
        }
        let releaseYear = releaseYearCandidate ?? 0

        let artwork: Data?
        if let flacArtwork = flac?.pictureData {
            artwork = flacArtwork
        } else {
            artwork = await embeddedArtwork(metadata: metadata, dictionary: audioInfo)
        }

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { title = url.deletingPathExtension().lastPathComponent }
        if artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { artist = "Unknown Artist" }
        if album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { album = "Unknown Album" }

        return Track(
            title: title,
            artist: artist,
            albumArtist: albumArtist,
            album: album,
            trackNumber: trackNumber,
            discNumber: discNumber,
            releaseYear: releaseYear,
            duration: duration,
            fileURL: url,
            artworkData: artwork,
            artworkIsEmbedded: artwork != nil
        )
    }

    private func loadAllMetadata(from asset: AVURLAsset) async -> [AVMetadataItem] {
        var result = (try? await asset.load(.commonMetadata)) ?? []
        for format in (try? await asset.load(.availableMetadataFormats)) ?? [] {
            result.append(contentsOf: (try? await asset.loadMetadata(for: format)) ?? [])
        }
        return result
    }

    private func firstString(keys: [String], metadata: [AVMetadataItem], dictionary: [String: Any]) async -> String? {
        let normalizedKeys = Set(keys.map(normalize))
        for item in metadata {
            let candidates = [item.commonKey?.rawValue, item.identifier?.rawValue, String(describing: item.key)]
                .compactMap { $0 }
                .map(normalize)
            guard candidates.contains(where: { candidate in normalizedKeys.contains(where: candidate.contains) }) else { continue }

            if let loadedString = try? await item.load(.stringValue) {
                let trimmed = loadedString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
            if let loadedNumber = try? await item.load(.numberValue) {
                return loadedNumber.stringValue
            }
            if let loadedDate = try? await item.load(.dateValue) {
                return ISO8601DateFormatter().string(from: loadedDate)
            }
        }
        for (key, value) in dictionary where normalizedKeys.contains(where: normalize(key).contains) {
            if let string = value as? String, !string.isEmpty { return string }
            if let number = value as? NSNumber { return number.stringValue }
            if let date = value as? Date { return ISO8601DateFormatter().string(from: date) }
        }
        return nil
    }

    private func firstInteger(keys: [String], metadata: [AVMetadataItem], dictionary: [String: Any]) async -> Int? {
        let value = await firstString(keys: keys, metadata: metadata, dictionary: dictionary)
        return integer(value)
    }

    private func firstYear(keys: [String], metadata: [AVMetadataItem], dictionary: [String: Any]) async -> Int? {
        let value = await firstString(keys: keys, metadata: metadata, dictionary: dictionary)
        return year(value)
    }

    private func integer(_ value: String?) -> Int? {
        guard let value else { return nil }
        return Int(value.split(separator: "/").first?.filter(\.isNumber) ?? "")
    }

    private func year(_ value: String?) -> Int? {
        guard let value else { return nil }
        let digits = value.filter(\.isNumber)
        guard digits.count >= 4, let parsed = Int(digits.prefix(4)), (1000...9999).contains(parsed) else { return nil }
        return parsed
    }

    private func embeddedArtwork(metadata: [AVMetadataItem], dictionary: [String: Any]) async -> Data? {
        for item in metadata {
            let label = normalize([item.commonKey?.rawValue, item.identifier?.rawValue, String(describing: item.key)].compactMap { $0 }.joined(separator: " "))
            guard label.contains("artwork") || label.contains("picture") || item.commonKey == .commonKeyArtwork else { continue }
            do {
                let loadedData = try await item.load(.dataValue)
                if let loadedData, let imageData = Self.renderableArtworkData(from: loadedData) { return imageData }
            } catch {
                continue
            }
        }
        for (key, value) in dictionary where normalize(key).contains("artwork") || normalize(key).contains("picture") {
            if let data = value as? Data, let imageData = Self.renderableArtworkData(from: data) { return imageData }
        }
        return nil
    }

    /// AVFoundation may expose an MP3 APIC frame as data rather than returning
    /// only its image payload. ImageIO cannot render that wrapper directly.
    /// Keep already-valid image data unchanged, then unwrap the common ID3
    /// APIC layout before handing artwork to the library and UI.
    static func renderableArtworkData(from data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        if let imageData = repairedRenderableImage(data) { return imageData }
        guard data.count > 4 else { return nil }

        // Some MP3 metadata paths prepend little-endian thumbnail dimensions
        // and a terminator before the JPEG/PNG payload.
        let width = UInt16(data[0]) | UInt16(data[1]) << 8
        let height = UInt16(data[2]) | UInt16(data[3]) << 8
        if data[4] == 0, width > 0, height > 0 {
            let imageData = data.subdata(in: 5..<data.count)
            if let imageData = repairedRenderableImage(imageData) { return imageData }
        }

        let encoding = data[0]
        var offset = 1
        guard let mimeTerminator = data[offset...].firstIndex(of: 0) else { return nil }
        offset = Int(mimeTerminator) + 1
        guard offset < data.count else { return nil }
        offset += 1 // APIC picture type.
        guard offset < data.count else { return nil }

        if encoding == 1 || encoding == 2 {
            while offset + 1 < data.count {
                if data[offset] == 0 && data[offset + 1] == 0 {
                    offset += 2
                    break
                }
                offset += 2
            }
        } else {
            guard let descriptionTerminator = data[offset...].firstIndex(of: 0) else { return nil }
            offset = Int(descriptionTerminator) + 1
        }

        guard offset < data.count else { return nil }
        let imageData = data.subdata(in: offset..<data.count)
        return repairedRenderableImage(imageData)
    }

    private static func repairedRenderableImage(_ data: Data) -> Data? {
        if isRenderableImage(data) { return data }
        guard data.count > 2, data[0] == 0xFF, (0xE0...0xEF).contains(data[1]) else { return nil }
        var repaired = Data([0xFF, 0xD8])
        repaired.append(data)
        return isRenderableImage(repaired) ? repaired : nil
    }

    private static func isRenderableImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetCount(source) > 0
    }

    private func audioFileInfo(for url: URL) -> [String: Any] {
        var file: AudioFileID?
        guard AudioFileOpenURL(url as CFURL, .readPermission, 0, &file) == noErr, let file else { return [:] }
        defer { AudioFileClose(file) }

        var size = UInt32(MemoryLayout<CFDictionary?>.size)
        var writable: UInt32 = 0
        guard AudioFileGetPropertyInfo(file, kAudioFilePropertyInfoDictionary, &size, &writable) == noErr else { return [:] }

        var unmanagedDictionary: Unmanaged<CFDictionary>?
        let status = withUnsafeMutablePointer(to: &unmanagedDictionary) { pointer in
            AudioFileGetProperty(
                file,
                kAudioFilePropertyInfoDictionary,
                &size,
                UnsafeMutableRawPointer(pointer)
            )
        }
        guard status == noErr, let unmanagedDictionary else { return [:] }
        let dictionary = unmanagedDictionary.takeRetainedValue()
        return dictionary as? [String: Any] ?? [:]
    }

    private func inferredNumber(from url: URL) -> Int {
        Int(url.deletingPathExtension().lastPathComponent.prefix { $0.isNumber }) ?? 0
    }

    private func normalize(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

private struct FLACMetadata {
    var comments: [String: [String]] = [:]
    var pictureData: Data?

    func first(_ key: String) -> String? { comments[key.uppercased()]?.first }

    static func read(url: URL) -> FLACMetadata? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let signature = try? handle.read(upToCount: 4), signature == Data("fLaC".utf8) else { return nil }
        var result = FLACMetadata()
        var isLast = false
        while !isLast {
            guard let header = try? handle.read(upToCount: 4), header.count == 4 else { break }
            isLast = (header[0] & 0x80) != 0
            let type = header[0] & 0x7F
            let length = Int(header[1]) << 16 | Int(header[2]) << 8 | Int(header[3])
            guard length >= 0, length <= 64 * 1024 * 1024,
                  let block = try? handle.read(upToCount: length), block.count == length else { break }
            if type == 4 { parseVorbis(block, into: &result) }
            // FLAC front-cover artwork is conventionally picture type 3.
            // Type 6 is also seen in existing libraries, so accept both.
            else if (type == 3 || type == 6), result.pictureData == nil {
                result.pictureData = parsePicture(block)
            }
        }
        return result
    }

    private static func parseVorbis(_ data: Data, into result: inout FLACMetadata) {
        var offset = 0
        guard let vendorLength = readLE32(data, &offset), offset + vendorLength <= data.count else { return }
        offset += vendorLength
        guard let count = readLE32(data, &offset) else { return }
        for _ in 0..<min(count, 100_000) {
            guard let length = readLE32(data, &offset), offset + length <= data.count else { break }
            let raw = data.subdata(in: offset..<(offset + length))
            offset += length
            guard let text = String(data: raw, encoding: .utf8), let equals = text.firstIndex(of: "=") else { continue }
            let key = String(text[..<equals]).uppercased()
            let value = String(text[text.index(after: equals)...])
            result.comments[key, default: []].append(value)
        }
        if result.pictureData == nil,
           let encoded = result.first("METADATA_BLOCK_PICTURE"),
           let block = Data(base64Encoded: encoded) {
            result.pictureData = parsePicture(block)
        }
    }

    private static func parsePicture(_ data: Data) -> Data? {
        var offset = 0
        guard readBE32(data, &offset) != nil,
              let mimeLength = readBE32(data, &offset), offset + mimeLength <= data.count else { return nil }
        offset += mimeLength
        guard let descriptionLength = readBE32(data, &offset), offset + descriptionLength <= data.count else { return nil }
        offset += descriptionLength
        guard readBE32(data, &offset) != nil,
              readBE32(data, &offset) != nil,
              readBE32(data, &offset) != nil,
              readBE32(data, &offset) != nil,
              let imageLength = readBE32(data, &offset),
              imageLength > 0,
              offset + imageLength <= data.count else { return nil }
        return data.subdata(in: offset..<(offset + imageLength))
    }

    private static func readLE32(_ data: Data, _ offset: inout Int) -> Int? {
        guard offset + 4 <= data.count else { return nil }
        let value = Int(data[offset]) | Int(data[offset + 1]) << 8 | Int(data[offset + 2]) << 16 | Int(data[offset + 3]) << 24
        offset += 4
        return value
    }

    private static func readBE32(_ data: Data, _ offset: inout Int) -> Int? {
        guard offset + 4 <= data.count else { return nil }
        let value = Int(data[offset]) << 24 | Int(data[offset + 1]) << 16 | Int(data[offset + 2]) << 8 | Int(data[offset + 3])
        offset += 4
        return value
    }
}

struct MetadataTagValues: Sendable {
    let title: String
    let artist: String
    let albumArtist: String
    let album: String
    let trackNumber: Int
    let discNumber: Int
    let releaseYear: Int
}

enum MetadataTagWriterError: LocalizedError {
    case unsupportedFormat(String)
    case invalidFile
    case invalidMetadata
    case writeFailed

    var errorDescription: String? {
        switch self {
        case let .unsupportedFormat(extensionName):
            return "Direct tag writing currently supports FLAC and MP3 files, not .\(extensionName)."
        case .invalidFile:
            return "The local audio file is not a valid FLAC or MP3 file."
        case .invalidMetadata:
            return "The metadata values could not be encoded safely."
        case .writeFailed:
            return "The audio file could not be updated."
        }
    }
}

enum MetadataTagWriter {
    static let directlyWritableExtensions: Set<String> = ["flac", "mp3"]

    static func write(
        to url: URL,
        values: MetadataTagValues,
        artworkData: Data?,
        replaceArtwork: Bool
    ) throws {
        let extensionName = url.pathExtension.lowercased()
        switch extensionName {
        case "flac":
            try writeFLAC(to: url, values: values, artworkData: artworkData, replaceArtwork: replaceArtwork)
        case "mp3":
            try writeMP3(to: url, values: values, artworkData: artworkData, replaceArtwork: replaceArtwork)
        default:
            throw MetadataTagWriterError.unsupportedFormat(extensionName.isEmpty ? "audio" : extensionName)
        }
    }

    private struct FLACBlock {
        var type: UInt8
        var data: Data
    }

    private static func writeFLAC(
        to url: URL,
        values: MetadataTagValues,
        artworkData: Data?,
        replaceArtwork: Bool
    ) throws {
        let original = try Data(contentsOf: url)
        guard original.count >= 8, original.prefix(4) == Data("fLaC".utf8) else {
            throw MetadataTagWriterError.invalidFile
        }

        var offset = 4
        var blocks: [FLACBlock] = []
        var isLast = false
        while !isLast {
            guard offset + 4 <= original.count else { throw MetadataTagWriterError.invalidFile }
            let header = original[offset]
            isLast = (header & 0x80) != 0
            let type = header & 0x7F
            let length = Int(original[offset + 1]) << 16 |
                Int(original[offset + 2]) << 8 |
                Int(original[offset + 3])
            offset += 4
            guard length <= 0xFFFFFF, offset + length <= original.count else {
                throw MetadataTagWriterError.invalidFile
            }
            blocks.append(FLACBlock(type: type, data: original.subdata(in: offset..<(offset + length))))
            offset += length
        }

        var commentIndex: Int?
        var rewritten: [FLACBlock] = []
        for block in blocks {
            if block.type == 4 {
                if commentIndex == nil {
                    commentIndex = rewritten.count
                    rewritten.append(FLACBlock(type: 4, data: makeVorbisComments(from: block.data, values: values)))
                }
            } else if replaceArtwork && block.type == 6 {
                continue
            } else {
                rewritten.append(block)
            }
        }
        if commentIndex == nil {
            let index = rewritten.firstIndex(where: { $0.type == 0 }).map { $0 + 1 } ?? rewritten.count
            rewritten.insert(
                FLACBlock(type: 4, data: makeVorbisComments(from: nil, values: values)),
                at: index
            )
        }
        if replaceArtwork, let artworkData, !artworkData.isEmpty {
            rewritten.append(FLACBlock(type: 6, data: makePictureBlock(artworkData)))
        }

        var output = Data("fLaC".utf8)
        for (index, block) in rewritten.enumerated() {
            guard block.data.count <= 0xFFFFFF else { throw MetadataTagWriterError.invalidMetadata }
            output.append(block.type | (index == rewritten.count - 1 ? 0x80 : 0))
            output.append(UInt8((block.data.count >> 16) & 0xFF))
            output.append(UInt8((block.data.count >> 8) & 0xFF))
            output.append(UInt8(block.data.count & 0xFF))
            output.append(block.data)
        }
        output.append(original.subdata(in: offset..<original.count))
        try atomicallyReplace(url, with: output)
    }

    private static func makeVorbisComments(from block: Data?, values: MetadataTagValues) -> Data {
        var comments: [(String, String)] = []
        if let block {
            var cursor = 0
            if let vendorLength = readLE32(block, &cursor), cursor + vendorLength <= block.count {
                cursor += vendorLength
                if let count = readLE32(block, &cursor) {
                    for _ in 0..<min(count, 100_000) {
                        guard let length = readLE32(block, &cursor), cursor + length <= block.count else { break }
                        let raw = block.subdata(in: cursor..<(cursor + length))
                        cursor += length
                        guard let text = String(data: raw, encoding: .utf8), let separator = text.firstIndex(of: "=") else { continue }
                        comments.append((String(text[..<separator]).uppercased(), String(text[text.index(after: separator)...])))
                    }
                }
            }
        }
        let replacedKeys: Set<String> = ["TITLE", "ARTIST", "ALBUMARTIST", "ALBUM ARTIST", "ALBUM", "TRACKNUMBER", "DISCNUMBER", "DATE", "YEAR", "ORIGINALDATE", "METADATA_BLOCK_PICTURE"]
        comments.removeAll { replacedKeys.contains($0.0) }
        let newValues: [(String, String)] = [
            ("TITLE", values.title),
            ("ARTIST", values.artist),
            ("ALBUMARTIST", values.albumArtist),
            ("ALBUM", values.album),
            ("TRACKNUMBER", values.trackNumber > 0 ? String(values.trackNumber) : ""),
            ("DISCNUMBER", values.discNumber > 0 ? String(values.discNumber) : ""),
            ("DATE", values.releaseYear > 0 ? String(values.releaseYear) : "")
        ]
        comments.append(contentsOf: newValues.filter { !$0.1.isEmpty })

        var result = Data()
        appendLE32(9, to: &result)
        result.append(Data("Resonance".utf8))
        appendLE32(comments.count, to: &result)
        for (key, value) in comments {
            let encoded = Data("\(key)=\(value)".utf8)
            appendLE32(encoded.count, to: &result)
            result.append(encoded)
        }
        return result
    }

    private static func makePictureBlock(_ image: Data) -> Data {
        let mime = image.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? "image/png" : "image/jpeg"
        var result = Data()
        appendBE32(3, to: &result)
        appendBE32(mime.utf8.count, to: &result)
        result.append(Data(mime.utf8))
        appendBE32(0, to: &result)
        appendBE32(0, to: &result)
        appendBE32(0, to: &result)
        appendBE32(0, to: &result)
        appendBE32(0, to: &result)
        appendBE32(image.count, to: &result)
        result.append(image)
        return result
    }

    private struct ID3Frame {
        let id: String
        let raw: Data
    }

    private static func writeMP3(
        to url: URL,
        values: MetadataTagValues,
        artworkData: Data?,
        replaceArtwork: Bool
    ) throws {
        let original = try Data(contentsOf: url)
        var audioOffset = 0
        var existingFrames: [ID3Frame] = []
        if original.count >= 10, String(data: original.subdata(in: 0..<3), encoding: .ascii) == "ID3" {
            let version = original[3]
            let tagSize = syncSafeInt(original.subdata(in: 6..<10))
            let end = min(original.count, 10 + tagSize)
            audioOffset = end
            var cursor = 10
            while cursor + 10 <= end {
                let idData = original.subdata(in: cursor..<(cursor + 4))
                guard let id = String(data: idData, encoding: .ascii), id.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }), id != "\0\0\0\0" else { break }
                let rawSize = original.subdata(in: (cursor + 4)..<(cursor + 8))
                let frameSize = version >= 4 ? syncSafeInt(rawSize) : bigEndianInt(rawSize)
                guard frameSize > 0, cursor + 10 + frameSize <= end else { break }
                existingFrames.append(ID3Frame(id: id, raw: original.subdata(in: cursor..<(cursor + 10 + frameSize))))
                cursor += 10 + frameSize
            }
        }

        let replacedIDs: Set<String> = ["TIT2", "TPE1", "TPE2", "TALB", "TRCK", "TPOS", "TDRC"]
        var frames = existingFrames.filter { frame in
            !replacedIDs.contains(frame.id) && (replaceArtwork ? frame.id != "APIC" : true)
        }.map(\.raw)
        frames.insert(textFrame("TIT2", values.title), at: 0)
        frames.insert(textFrame("TPE1", values.artist), at: 1)
        frames.insert(textFrame("TPE2", values.albumArtist), at: 2)
        frames.insert(textFrame("TALB", values.album), at: 3)
        if values.trackNumber > 0 { frames.append(textFrame("TRCK", String(values.trackNumber))) }
        if values.discNumber > 0 { frames.append(textFrame("TPOS", String(values.discNumber))) }
        if values.releaseYear > 0 { frames.append(textFrame("TDRC", String(values.releaseYear))) }
        if replaceArtwork, let artworkData, !artworkData.isEmpty {
            frames.append(artworkFrame(artworkData))
        }

        var tagBody = Data()
        for frame in frames { tagBody.append(frame) }
        guard tagBody.count <= 0x0FFFFFFF else { throw MetadataTagWriterError.invalidMetadata }
        var output = Data([0x49, 0x44, 0x33, 0x03, 0x00, 0x00])
        output.append(syncSafeData(tagBody.count))
        output.append(tagBody)
        output.append(original.subdata(in: audioOffset..<original.count))
        try atomicallyReplace(url, with: output)
    }

    private static func textFrame(_ id: String, _ value: String) -> Data {
        var body = Data([1, 0xFF, 0xFE])
        body.append(value.data(using: .utf16LittleEndian) ?? Data())
        body.append(contentsOf: [0, 0])
        return frame(id, body: body)
    }

    private static func artworkFrame(_ image: Data) -> Data {
        let mime = image.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? "image/png" : "image/jpeg"
        var body = Data([1])
        body.append(Data(mime.utf8))
        body.append(0)
        body.append(3)
        body.append(contentsOf: [1, 0xFF, 0xFE, 0, 0])
        body.append(image)
        return frame("APIC", body: body)
    }

    private static func frame(_ id: String, body: Data) -> Data {
        var result = Data(id.utf8.prefix(4))
        result.append(UInt8((body.count >> 24) & 0xFF))
        result.append(UInt8((body.count >> 16) & 0xFF))
        result.append(UInt8((body.count >> 8) & 0xFF))
        result.append(UInt8(body.count & 0xFF))
        result.append(contentsOf: [0, 0])
        result.append(body)
        return result
    }

    private static func atomicallyReplace(_ url: URL, with data: Data) throws {
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw MetadataTagWriterError.writeFailed
        }
    }

    private static func appendLE32(_ value: Int, to data: inout Data) {
        let value = UInt32(clamping: value)
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 24) & 0xFF))
    }

    private static func appendBE32(_ value: Int, to data: inout Data) {
        let value = UInt32(clamping: value)
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    private static func readLE32(_ data: Data, _ offset: inout Int) -> Int? {
        guard offset + 4 <= data.count else { return nil }
        let value = Int(data[offset]) | Int(data[offset + 1]) << 8 | Int(data[offset + 2]) << 16 | Int(data[offset + 3]) << 24
        offset += 4
        return value
    }

    private static func syncSafeInt(_ data: Data) -> Int {
        guard data.count == 4 else { return 0 }
        return Int(data[0] & 0x7F) << 21 | Int(data[1] & 0x7F) << 14 | Int(data[2] & 0x7F) << 7 | Int(data[3] & 0x7F)
    }

    private static func bigEndianInt(_ data: Data) -> Int {
        guard data.count == 4 else { return 0 }
        return Int(data[0]) << 24 | Int(data[1]) << 16 | Int(data[2]) << 8 | Int(data[3])
    }

    private static func syncSafeData(_ value: Int) -> Data {
        Data([
            UInt8((value >> 21) & 0x7F),
            UInt8((value >> 14) & 0x7F),
            UInt8((value >> 7) & 0x7F),
            UInt8(value & 0x7F)
        ])
    }
}
