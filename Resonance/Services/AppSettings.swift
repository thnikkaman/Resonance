import SwiftUI
import Security

enum RemoteLibraryBackend: String, CaseIterable, Identifiable {
    case subsonic = "Navidrome / Subsonic / OpenSubsonic"
    case resonanceManifest = "Resonance Manifest"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .subsonic: "Navidrome / Subsonic"
        case .resonanceManifest: "Resonance Manifest"
        }
    }
}


@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("appearance") private var appearanceRaw = "system"
    @AppStorage("accentHex") var accentHex = "A855F7"
    @AppStorage("applyThemeColorToText") var applyThemeColorToText = false
    @AppStorage("albumLayout") private var albumLayoutRaw = AlbumLayout.grid.rawValue
    @AppStorage("artistAlbumLayout") private var artistAlbumLayoutRaw = ArtistAlbumLayout.grid.rawValue
    @AppStorage("artistAlbumSort") private var artistAlbumSortRaw = ArtistAlbumSort.title.rawValue
    @AppStorage("libraryThumbnailSize") private var libraryThumbnailSizeRaw = LibraryThumbnailSize.medium.rawValue
    @AppStorage("libraryTextSize") private var libraryTextSizeRaw = LibraryTextSize.standard.rawValue
    @AppStorage("showArtworkWarning") var showArtworkWarning = true
    @AppStorage("showLockScreenArtwork") var showLockScreenArtwork = true
    @AppStorage("preloadNextTrack") var preloadNextTrack = true
    @AppStorage("localBufferMB") var localBufferMB = 64.0
    @AppStorage("networkBufferMB") var networkBufferMB = 128.0
    @AppStorage("streamBackend") private var streamBackendRaw = RemoteLibraryBackend.subsonic.rawValue
    @AppStorage("streamBackendDefaultsApplied") private var streamBackendDefaultsApplied = false
    @AppStorage("streamHost") var streamHost = ""
    @AppStorage("streamPort") var streamPort = ""
    @AppStorage("streamUseHTTPS") var streamUseHTTPS = true
    @AppStorage("streamManifestPath") var streamManifestPath = "/rest"
    @AppStorage("streamUsername") var streamUsername = ""
    @Published var streamPassword: String {
        didSet { KeychainCredentialStore.save(streamPassword, account: "remote-library-password") }
    }

    init() {
        streamPassword = KeychainCredentialStore.load(account: "remote-library-password") ?? ""

        if !streamBackendDefaultsApplied {
            streamBackendRaw = RemoteLibraryBackend.subsonic.rawValue
            if streamPort == "8080" { streamPort = "" }
            if streamManifestPath == "/resonance/library.json" { streamManifestPath = "/rest" }
            streamUseHTTPS = true
            streamBackendDefaultsApplied = true
        }
    }

    var streamBackend: RemoteLibraryBackend {
        get { RemoteLibraryBackend(rawValue: streamBackendRaw) ?? .subsonic }
        set { streamBackendRaw = newValue.rawValue; objectWillChange.send() }
    }

    func applyStreamingDefaults(for backend: RemoteLibraryBackend) {
        streamBackend = backend
        switch backend {
        case .subsonic:
            if streamPort == "8080" { streamPort = "" }
            if streamManifestPath.isEmpty || streamManifestPath == "/resonance/library.json" {
                streamManifestPath = "/rest"
            }
            streamUseHTTPS = true
        case .resonanceManifest:
            if streamPort.isEmpty { streamPort = "8080" }
            if streamManifestPath.isEmpty || streamManifestPath == "/rest" {
                streamManifestPath = "/resonance/library.json"
            }
        }
    }

    var appearance: String {
        get { appearanceRaw }
        set { appearanceRaw = newValue; objectWillChange.send() }
    }

    var albumLayout: AlbumLayout {
        get { AlbumLayout(rawValue: albumLayoutRaw) ?? .grid }
        set { albumLayoutRaw = newValue.rawValue; objectWillChange.send() }
    }

    var artistAlbumLayout: ArtistAlbumLayout {
        get { ArtistAlbumLayout(rawValue: artistAlbumLayoutRaw) ?? .grid }
        set { artistAlbumLayoutRaw = newValue.rawValue; objectWillChange.send() }
    }

    var artistAlbumSort: ArtistAlbumSort {
        get { ArtistAlbumSort(rawValue: artistAlbumSortRaw) ?? .title }
        set { artistAlbumSortRaw = newValue.rawValue; objectWillChange.send() }
    }

    var libraryThumbnailSize: LibraryThumbnailSize {
        get { LibraryThumbnailSize(rawValue: libraryThumbnailSizeRaw) ?? .medium }
        set { libraryThumbnailSizeRaw = newValue.rawValue; objectWillChange.send() }
    }

    var libraryTextSize: LibraryTextSize {
        get { LibraryTextSize(rawValue: libraryTextSizeRaw) ?? .standard }
        set { libraryTextSizeRaw = newValue.rawValue; objectWillChange.send() }
    }

    var colorScheme: ColorScheme? {
        switch appearanceRaw {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    var normalizedAccentHex: String {
        let cleaned = accentHex.uppercased().filter { $0.isHexDigit }
        return String(cleaned.prefix(6)).padding(toLength: 6, withPad: "0", startingAt: 0)
    }

    var accentColor: Color { Color(hex: normalizedAccentHex) ?? .purple }

    var contrastingAccentTextColor: Color {
        guard let value = UInt64(normalizedAccentHex, radix: 16) else { return .white }
        let r = 255 - Int((value >> 16) & 0xFF)
        let g = 255 - Int((value >> 8) & 0xFF)
        let b = 255 - Int(value & 0xFF)
        return Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}

extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}


private enum KeychainCredentialStore {
    private static let service = "com.example.ResonancePrototype.remote-library"

    static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String, account: String) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        guard !value.isEmpty else {
            _ = SecItemDelete(baseQuery as CFDictionary)
            return
        }

        let data = Data(value.utf8)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = baseQuery
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            _ = SecItemAdd(newItem as CFDictionary, nil)
        }
    }
}
