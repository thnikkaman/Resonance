import AVFoundation
import AudioToolbox
import Foundation

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
                if let loadedData, !loadedData.isEmpty { return loadedData }
            } catch {
                continue
            }
        }
        for (key, value) in dictionary where normalize(key).contains("artwork") || normalize(key).contains("picture") {
            if let data = value as? Data, !data.isEmpty { return data }
        }
        return nil
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
            else if type == 6, result.pictureData == nil { result.pictureData = parsePicture(block) }
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
