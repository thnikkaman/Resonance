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

enum ResonanceVisualTheme: String, CaseIterable, Identifiable {
    case nocturne
    case galleryLight
    case colorBloom
    case brushedMetal
    case classicWood
    case electronic
    case psychedelic
    case waterfall

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nocturne: "Nocturne Glass"
        case .galleryLight: "Gallery Light"
        case .colorBloom: "Color Bloom"
        case .brushedMetal: "Brushed Metal"
        case .classicWood: "Classic Wood"
        case .electronic: "Electronic"
        case .psychedelic: "Psychedelic"
        case .waterfall: "Waterfall Meadow"
        }
    }

    var description: String {
        switch self {
        case .nocturne: "Cinematic graphite with violet glass"
        case .galleryLight: "Warm ivory with editorial terracotta"
        case .colorBloom: "Deep navy with luminous color"
        case .brushedMetal: "Cool steel with a soft silver sheen"
        case .classicWood: "Warm cherry with flowing flame grain"
        case .electronic: "Midnight circuitry with electric cyan"
        case .psychedelic: "Ultraviolet color with acid-lime energy"
        case .waterfall: "Mountain waterfall with purple and orange flowers"
        }
    }

    var accentHex: String {
        switch self {
        case .nocturne: "A78BFA"
        case .galleryLight: "C55A32"
        case .colorBloom: "FF89B5"
        case .brushedMetal: "5EC8FF"
        case .classicWood: "D68A36"
        case .electronic: "00E5FF"
        case .psychedelic: "F533FF"
        case .waterfall: "7B4DCC"
        }
    }

    var backgroundHex: String {
        switch self {
        case .nocturne: "0B1020"
        case .galleryLight: "F5F0E8"
        case .colorBloom: "07142B"
        case .brushedMetal: "161B20"
        case .classicWood: "2A170E"
        case .electronic: "050914"
        case .psychedelic: "18042D"
        case .waterfall: "123B2A"
        }
    }

    var surfaceHex: String {
        switch self {
        case .nocturne: "151A2C"
        case .galleryLight: "FFFDF8"
        case .colorBloom: "10254A"
        case .brushedMetal: "303840"
        case .classicWood: "4A2A18"
        case .electronic: "0D1830"
        case .psychedelic: "351050"
        case .waterfall: "214F38"
        }
    }

    var secondaryHex: String {
        switch self {
        case .nocturne: "F4C95D"
        case .galleryLight: "0B7285"
        case .colorBloom: "F6D365"
        case .brushedMetal: "E9A23B"
        case .classicWood: "7FDBDA"
        case .electronic: "FF9F68"
        case .psychedelic: "FFFF00"
        case .waterfall: "D7A8FF"
        }
    }

    /// Text accents intentionally use a complementary hue to the theme artwork.
    /// Keeping this separate from `accentHex` preserves each theme's control tint
    /// while making labels and section markers readable over its background.
    var textAccentHex: String {
        switch self {
        case .nocturne: "FFD166"
        case .galleryLight: "006D77"
        case .colorBloom: "FFD166"
        case .brushedMetal: "FFC857"
        case .classicWood: "8BE9FD"
        case .electronic: "FFB86C"
        case .psychedelic: "FFFF00"
        case .waterfall: "E5B8FF"
        }
    }

    var recommendedColorScheme: ColorScheme {
        switch self {
        case .galleryLight, .waterfall: .light
        case .nocturne, .colorBloom, .brushedMetal, .classicWood, .electronic, .psychedelic: .dark
        }
    }

    var backgroundGradientHex: [String] {
        switch self {
        case .nocturne: ["0B1020", "271A4A", "080B15"]
        case .galleryLight: ["F4E5D2", "C97955", "FFF8EE"]
        case .colorBloom: ["07142B", "8A245F", "0B4560"]
        case .brushedMetal: ["11161B", "46515A", "1A2026"]
        case .classicWood: ["241109", "5B321B", "2A140B"]
        case .electronic: ["030711", "0A1D32", "04101D"]
        case .psychedelic: ["120022", "3A0A52", "13062E"]
        case .waterfall: ["123B2A", "2E6B4A"]
        }
    }

    var surfaceGradientHex: [String] {
        switch self {
        case .nocturne: ["151A2C", "3A2A5A", "101522"]
        case .galleryLight: ["FFF8EE", "E8B79A", "F6E4D2"]
        case .colorBloom: ["10254A", "5B2262", "123C5A"]
        case .brushedMetal: ["303840", "59656D", "333D45"]
        case .classicWood: ["4A2A18", "6C3D20"]
        case .electronic: ["0D1830", "122C4A"]
        case .psychedelic: ["351050", "59105F"]
        case .waterfall: ["214F38", "3E7A57"]
        }
    }

    var isBrightAppearance: Bool {
        self == .galleryLight
    }

    var backgroundImageName: String? {
        switch self {
        case .brushedMetal: "ThemeBrushedMetal"
        case .classicWood: "ThemeClassicWood"
        case .electronic: "ThemeElectronic"
        case .psychedelic: "ThemePsychedelic"
        case .nocturne, .galleryLight, .colorBloom: nil
        case .waterfall: "ThemeWaterfallMeadow"
        }
    }
}

enum ResonanceHeroButtonStyle: String, CaseIterable, Identifiable, Hashable {
    case softGlass
    case matteCrystal
    case innerGlow
    case minimalTransparent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .softGlass: "Soft Glass"
        case .matteCrystal: "Matte Crystal"
        case .innerGlow: "Inner Glow"
        case .minimalTransparent: "Minimal Transparent"
        }
    }

    var description: String {
        switch self {
        case .softGlass: "Frosted, translucent buttons with a gentle tint"
        case .matteCrystal: "A denser satin surface with a crisp edge"
        case .innerGlow: "Open buttons with a soft accent glow"
        case .minimalTransparent: "Nearly invisible controls with an accent underline"
        }
    }
}


@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("appearance") private var appearanceRaw = "system"
    @AppStorage("visualTheme") private var visualThemeRaw = ResonanceVisualTheme.nocturne.rawValue
    @AppStorage("heroButtonStyle") private var heroButtonStyleRaw = ResonanceHeroButtonStyle.softGlass.rawValue
    @AppStorage("accentHex") private var accentHexStorage = "A855F7"
    @AppStorage("applyThemeColorToText") private var applyThemeColorToTextStorage = true
    @AppStorage("applyThemeColorToTextConfigured") private var applyThemeColorToTextConfigured = false
    @AppStorage("albumLayout") private var albumLayoutRaw = AlbumLayout.grid.rawValue
    @AppStorage("artistAlbumLayout") private var artistAlbumLayoutRaw = ArtistAlbumLayout.grid.rawValue
    @AppStorage("artistAlbumSort") private var artistAlbumSortRaw = ArtistAlbumSort.title.rawValue
    @AppStorage("libraryThumbnailSize") private var libraryThumbnailSizeRaw = LibraryThumbnailSize.medium.rawValue
    @AppStorage("libraryTextSize") private var libraryTextSizeRaw = LibraryTextSize.standard.rawValue
    @AppStorage("groupCompilationArtists") var groupCompilationArtists = false
    @AppStorage("leftHandedAlphabet") var leftHandedAlphabet = false
    @AppStorage("settingsAppearanceExpanded") var settingsAppearanceExpanded = true
    @AppStorage("settingsPlaybackExpanded") var settingsPlaybackExpanded = true
    @AppStorage("settingsReportedErrorsExpanded") var settingsReportedErrorsExpanded = true
    @AppStorage("settingsStreamingExpanded") var settingsStreamingExpanded = true
    @AppStorage("settingsFinderExpanded") var settingsFinderExpanded = true
    @AppStorage("settingsLibraryExpanded") var settingsLibraryExpanded = true
    @AppStorage("settingsPrototypeExpanded") var settingsPrototypeExpanded = true
    @AppStorage("showArtworkWarning") var showArtworkWarning = true
    @AppStorage("flacAlert") var flacAlert = false
    @AppStorage("showFrameDiagnostics") var showFrameDiagnostics = false
    @AppStorage("showLockScreenArtwork") var showLockScreenArtwork = true
    @AppStorage("preloadNextTrack") var preloadNextTrack = true
    @AppStorage("localBufferMB") var localBufferMB = 64.0
    @AppStorage("networkBufferMB") var networkBufferMB = 128.0
    @AppStorage("streamingGaplessExperimental") var streamingGaplessExperimental = false
    @AppStorage("experimentalBackgroundDownloads") var experimentalBackgroundDownloads = false
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

        // Build 85 stored this option as false by default. Migrate existing users
        // once so themed text is the default; a custom visual theme remains the
        // signal that the user previously chose their own accent.
        if !applyThemeColorToTextConfigured {
            applyThemeColorToText = true
            applyThemeColorToTextConfigured = true
        }

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

    var visualTheme: ResonanceVisualTheme {
        get {
            // Replace the removed Custom Accent theme without resetting an
            // existing user's selected visual theme.
            if visualThemeRaw == "custom" { return .waterfall }
            return ResonanceVisualTheme(rawValue: visualThemeRaw) ?? .nocturne
        }
        set {
            visualThemeRaw = newValue.rawValue
            if newValue.isBrightAppearance, appearanceRaw == "dark" {
                appearanceRaw = "system"
            }
            objectWillChange.send()
        }
    }

    var heroButtonStyle: ResonanceHeroButtonStyle {
        get { ResonanceHeroButtonStyle(rawValue: heroButtonStyleRaw) ?? .softGlass }
        set { heroButtonStyleRaw = newValue.rawValue; objectWillChange.send() }
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
        default: visualTheme.recommendedColorScheme
        }
    }

    var normalizedAccentHex: String {
        let cleaned = accentHex.uppercased().filter { $0.isHexDigit }
        return String(cleaned.prefix(6)).padding(toLength: 6, withPad: "0", startingAt: 0)
    }

    var accentHex: String {
        get { accentHexStorage }
        set {
            objectWillChange.send()
            accentHexStorage = newValue
        }
    }

    var applyThemeColorToText: Bool {
        get { applyThemeColorToTextStorage }
        set {
            objectWillChange.send()
            applyThemeColorToTextStorage = newValue
        }
    }

    var accentColor: Color {
            Color(hex: visualTheme.accentHex) ?? .purple
    }

    var textAccentColor: Color {
        if applyThemeColorToText {
            return Color(hex: visualTheme.textAccentHex) ?? accentColor
        }
        return Color(hex: normalizedAccentHex) ?? .purple
    }

    var themeBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: visualTheme.backgroundGradientHex.compactMap(Color.init(hex:)),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var themeSurfaceGradient: LinearGradient {
        LinearGradient(
            colors: visualTheme.surfaceGradientHex.compactMap(Color.init(hex:)),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var themeBackgroundColor: Color {
        return Color(hex: visualTheme.backgroundHex) ?? Color(uiColor: .systemBackground)
    }

    var themeSurfaceColor: Color {
        return Color(hex: visualTheme.surfaceHex) ?? Color(uiColor: .secondarySystemBackground)
    }

    var themeSecondaryColor: Color {
        return Color(hex: visualTheme.secondaryHex) ?? .secondary
    }

    var contrastingAccentTextColor: Color {
        let source = visualTheme.accentHex
        guard let value = UInt64(source, radix: 16) else { return .white }
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
