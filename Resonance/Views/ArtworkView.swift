import SwiftUI
import ImageIO

private final class LocalArtworkImageBox: NSObject, @unchecked Sendable {
    let image: CGImage

    init(_ image: CGImage) {
        self.image = image
    }
}

private actor LocalArtworkLoader {
    static let shared = LocalArtworkLoader()

    private let thumbnails = NSCache<NSString, LocalArtworkImageBox>()

    init() {
        thumbnails.countLimit = 600
        thumbnails.totalCostLimit = 96 * 1024 * 1024
    }

    func image(data: Data, sourceKey: String, maxPixelSize: Int) async -> LocalArtworkImageBox? {
        let boundedPixelSize = min(1536, max(96, maxPixelSize))
        let key = "\(sourceKey)|\(boundedPixelSize)" as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }

        let box = await Task.detached(priority: .utility) {
            Self.downsample(data: data, maxPixelSize: boundedPixelSize)
        }.value
        guard let box else { return nil }
        let cost = max(1, box.image.bytesPerRow * box.image.height)
        thumbnails.setObject(box, forKey: key, cost: cost)
        return box
    }

    nonisolated private static func downsample(data: Data, maxPixelSize: Int) -> LocalArtworkImageBox? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return LocalArtworkImageBox(image)
    }
}

struct ArtworkView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.displayScale) private var displayScale
    let data: Data?
    let embedded: Bool
    let size: CGFloat
    let showWarningBorder: Bool
    let borderColor: Color?
    let fallbackTrack: StreamingArtworkTrackQuery?

    init(
        data: Data?,
        embedded: Bool,
        size: CGFloat,
        showWarningBorder: Bool = true,
        borderColor: Color? = nil,
        fallbackTrack: StreamingArtworkTrackQuery? = nil
    ) {
        self.data = data
        self.embedded = embedded
        self.size = size
        self.showWarningBorder = showWarningBorder
        self.borderColor = borderColor
        self.fallbackTrack = fallbackTrack
    }

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var didFail = false

    private var sourceKey: String {
        if let data {
            return "data:\(data.count):\(data.prefix(24).base64EncodedString()):\(data.suffix(24).base64EncodedString())"
        }
        if let fallbackTrack {
            return "online:\(fallbackTrack.artist)|\(fallbackTrack.albumArtist ?? "")|\(fallbackTrack.album)|\(fallbackTrack.title)"
        }
        return "placeholder"
    }

    private var taskKey: String {
        "\(sourceKey)|\(Int((size * displayScale).rounded(.up)))"
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [.secondary.opacity(0.35), .secondary.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note").font(.system(size: size * 0.32)).foregroundStyle(.secondary)
                    if isLoading && !didFail { ProgressView().controlSize(.small) }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(8, size * 0.08)))
        .overlay {
            if let borderColor {
                RoundedRectangle(cornerRadius: max(8, size * 0.08)).stroke(borderColor, lineWidth: 2)
            }
            if showWarningBorder && settings.showArtworkWarning && data != nil && !embedded {
                RoundedRectangle(cornerRadius: max(8, size * 0.08)).stroke(.red, lineWidth: 1)
            }
        }
        .task(id: taskKey) { await loadArtwork() }
    }

    @MainActor
    private func loadArtwork() async {
        guard let data else {
            image = nil
            didFail = false
            guard let fallbackTrack else { return }

            isLoading = true
            defer { isLoading = false }
            let fallbackData = await StreamingArtworkCache.shared.artwork(
                artist: fallbackTrack.artist,
                album: fallbackTrack.album,
                trackQueries: [fallbackTrack]
            )
            guard !Task.isCancelled, let fallbackData else {
                didFail = true
                return
            }
            let pixels = Int((size * displayScale).rounded(.up))
            let loaded = await LocalArtworkLoader.shared.image(
                data: fallbackData,
                sourceKey: sourceKey,
                maxPixelSize: pixels
            )
            guard !Task.isCancelled, let loaded else {
                didFail = true
                return
            }
            image = UIImage(cgImage: loaded.image, scale: displayScale, orientation: .up)
            return
        }

        isLoading = true
        didFail = false
        let startedAt = Date()
        defer { isLoading = false }

        let pixels = Int((size * displayScale).rounded(.up))
        let loaded = await LocalArtworkLoader.shared.image(
            data: data,
            sourceKey: sourceKey,
            maxPixelSize: pixels
        )
        guard !Task.isCancelled else { return }
        if let loaded {
            image = UIImage(cgImage: loaded.image, scale: displayScale, orientation: .up)
        } else {
            image = nil
            didFail = true
        }

        let elapsedMilliseconds = Int((Date().timeIntervalSince(startedAt) * 1_000).rounded())
        if elapsedMilliseconds >= 100 {
            ResonanceDiagnostics.shared.recordDeferred(
                "artwork.local.thumbnail",
                details: [
                    "bytes": String(data.count),
                    "pixels": String(pixels),
                    "durationMs": String(elapsedMilliseconds),
                    "result": loaded == nil ? "failed" : "ready"
                ]
            )
        }
    }
}

struct PlaceholderArtwork: View {
    let symbol: String
    let size: CGFloat
    var body: some View {
        ZStack { RoundedRectangle(cornerRadius: 10).fill(.secondary.opacity(0.15)); Image(systemName: symbol).foregroundStyle(.secondary) }
            .frame(width: size, height: size)
    }
}
