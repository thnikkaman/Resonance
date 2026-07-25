import SwiftUI

struct ArtworkView: View {
    @EnvironmentObject private var settings: AppSettings
    let data: Data?
    let embedded: Bool
    let size: CGFloat
    let showWarningBorder: Bool

    init(data: Data?, embedded: Bool, size: CGFloat, showWarningBorder: Bool = true) {
        self.data = data
        self.embedded = embedded
        self.size = size
        self.showWarningBorder = showWarningBorder
    }

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [.secondary.opacity(0.35), .secondary.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note").font(.system(size: size * 0.32)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(8, size * 0.08)))
        .overlay {
            if showWarningBorder && settings.showArtworkWarning && data != nil && !embedded {
                RoundedRectangle(cornerRadius: max(8, size * 0.08)).stroke(.red, lineWidth: 1)
            }
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
