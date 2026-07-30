import SwiftUI
import UIKit
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var errorLog: AppErrorLog
    @EnvironmentObject private var gestureCoordinator: ResonanceGestureCoordinator
    let closeSettings: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    @State private var accentHexDraft = ""
    @State private var showingServerQRCodeScanner = false
    @State private var serverQRCodeError: String?
    @StateObject private var accentHexCommitter = DebouncedSettingCommitter()
    private let palette = ["A855F7", "3B82F6", "14B8A6", "22C55E", "EAB308", "F97316", "EF4444"]

    private var buildDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "Beta \(version) (\(build))"
    }

    var body: some View {
        Form {
            SettingsCategory(
                "Appearance",
                key: "appearance",
                isExpanded: $settings.settingsAppearanceExpanded
            ) {
                Picker("Theme", selection: $settings.appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)

                Text("Visual style")
                    .font(.subheadline.weight(.semibold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(ResonanceVisualTheme.allCases) { theme in
                        ThemeChoiceButton(theme: theme) {
                            guard !gestureCoordinator.isHorizontalSwipeSuppressed else { return }
                            settings.visualTheme = theme
                        }
                    }
                }

                Text(settings.visualTheme.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Hero buttons", selection: $settings.heroButtonStyle) {
                    ForEach(ResonanceHeroButtonStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.menu)

                Text(settings.heroButtonStyle.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HeroButtonStylePreview()

                HStack {
                    ForEach(palette, id: \.self) { hex in
                        Button {
                            guard !gestureCoordinator.isHorizontalSwipeSuppressed else { return }
                            applyAccentHex(hex)
                        } label: {
                            Circle()
                                .fill(Color(hex: hex) ?? .purple)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if settings.normalizedAccentHex == hex {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(settings.contrastingAccentTextColor)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .buttonStyle(ResonanceSwipeAwareButtonStyle())
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Hex Color Code")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        ColorPicker(
                            "Choose accent color",
                            selection: accentColorPickerBinding,
                            supportsOpacity: false
                        )
                        .labelsHidden()
                        .accessibilityLabel("Choose accent color from color wheel")
                    }
                    RGBHexField(
                        hex: $accentHexDraft,
                        onBeginEditing: { isTextFieldFocused = false }
                    )
                }

                Toggle("Apply theme color to text", isOn: applyThemeColorToTextBinding)
                Toggle("Red outline for cached artwork", isOn: $settings.showArtworkWarning)
                Toggle("Show frame diagnostics", isOn: $settings.showFrameDiagnostics)
                Text("Draws a 1-pixel red outline and a small label around the app's major layout surfaces. This is useful for locating clipping, safe-area, and background-sizing problems.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ThemePreview()
            }

            SettingsCategory(
                "Playback",
                key: "playback",
                isExpanded: $settings.settingsPlaybackExpanded
            ) {
                Text("Library")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(settings.accentColor)

                Toggle("Gapless preload next track", isOn: $settings.preloadNextTrack)
                LabeledContent("Local preload budget", value: "\(Int(settings.localBufferMB)) MB")
                Slider(value: $settings.localBufferMB, in: 10...250, step: 10)

                if let preloaded = player.preloadedTrackTitle {
                    LabeledContent("Preloaded next track", value: preloaded)
                } else {
                    LabeledContent("Preloaded next track", value: "None")
                }
                Text(player.preloadDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("The budget controls how much of a large next file is scheduled before the boundary. Files larger than the budget receive a partial opening preload and continue from disk after playback starts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Shared Playback")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(settings.accentColor)

                LabeledContent("Playback engine", value: player.playbackEngineStatus)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last playback startup stage")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(player.playbackStartupDiagnostic)
                        .font(.caption.monospaced())
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Last playback runtime stage")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Text(player.playbackRuntimeDiagnostic)
                        .font(.caption.monospaced())
                        .fixedSize(horizontal: false, vertical: true)
                }
                Toggle("Show album artwork on Lock Screen", isOn: $settings.showLockScreenArtwork)
                LabeledContent("Audio channels", value: player.audioFormatStatus)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Active channel routing")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(player.downmixRoutingStatus)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if player.audioFormatStatus.contains("channel source") {
                    DisclosureGroup("5.1 Routing Monitor") {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Front left + rear left → left only", systemImage: "speaker.wave.2")
                            Label("Front right + rear right → right only", systemImage: "speaker.wave.2")
                            Label("Center + subwoofer → left and right", systemImage: "speaker.wave.3")
                            Label("50% output headroom protects summed channels", systemImage: "waveform.badge.shield")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Text("Streaming Library")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(settings.accentColor)

                LabeledContent("Streaming buffer budget", value: "\(Int(settings.networkBufferMB)) MB")
                Slider(value: $settings.networkBufferMB, in: 10...250, step: 10)
                if player.currentTrack?.isRemote == true {
                    LabeledContent("Active network buffer", value: player.networkBufferStatus)
                }
            }

            SettingsCategory(
                "Streaming Library",
                key: "streaming",
                isExpanded: $settings.settingsStreamingExpanded
            ) {
                Picker("Backend", selection: $settings.streamBackend) {
                    ForEach(RemoteLibraryBackend.allCases) { backend in
                        Text(backend.rawValue).tag(backend)
                    }
                }
                .onChange(of: settings.streamBackend) { _, backend in
                    settings.applyStreamingDefaults(for: backend)
                }

                HStack(spacing: 10) {
                    TextField("Server URL or Tailscale host", text: $settings.streamHost)
                        .focused($isTextFieldFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button {
                        isTextFieldFocused = false
                        showingServerQRCodeScanner = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Scan server address QR code")
                }

                TextField(
                    settings.streamBackend == .subsonic
                        ? "Port (blank uses the URL or HTTPS default)"
                        : "Port (8080 for the included test server)",
                    text: $settings.streamPort
                )
                .focused($isTextFieldFocused)
                .keyboardType(.numberPad)

                Toggle("Use HTTPS", isOn: $settings.streamUseHTTPS)
                LabeledContent(settings.streamBackend == .subsonic ? "API path" : "Manifest path") {
                    TextField(
                        settings.streamBackend == .subsonic ? "/rest" : "/resonance/library.json",
                        text: $settings.streamManifestPath
                    )
                    .focused($isTextFieldFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }

                if settings.streamBackend == .subsonic {
                    LabeledContent("Username") {
                        TextField("Navidrome / Subsonic", text: $settings.streamUsername)
                            .focused($isTextFieldFocused)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    LabeledContent("Password") {
                        SecureField("Navidrome / Subsonic", text: $settings.streamPassword)
                            .focused($isTextFieldFocused)
                            .textContentType(.password)
                    }
                    Label("The password is stored in the iOS Keychain.", systemImage: "key.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await remote.testConnection(using: settings) }
                } label: {
                    Label(remote.isLoading ? "Testing…" : "Test Connection", systemImage: "network")
                        .foregroundStyle(settings.contrastingAccentTextColor)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(settings.accentColor)
                .disabled(
                    remote.isLoading
                    || settings.streamHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || (settings.streamBackend == .subsonic
                        && (settings.streamUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || settings.streamPassword.isEmpty))
                )

                LabeledContent("Connection") {
                    Text(remote.connectionStatus)
                        .foregroundStyle(
                            remote.hasConnectionIssue
                                ? Color.red
                                : settings.textAccentColor
                        )
                        .fontWeight(remote.hasConnectionIssue ? .bold : .regular)
                }

                Toggle("Experimental background downloads", isOn: $settings.experimentalBackgroundDownloads)
                Text("Uses iOS background transfers so requested music can continue while the screen is locked. iOS may delay transfers, and force-quitting Resonance cancels them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await remote.activateCachedCatalogAndCheckForChanges(using: settings, forceCheck: true) }
                } label: {
                    Label("Check for Remote Changes", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(
                    remote.isLoading
                    || settings.streamHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || (settings.streamBackend == .subsonic
                        && (settings.streamUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || settings.streamPassword.isEmpty))
                )

                Button {
                    Task { await remote.refresh(using: settings) }
                } label: {
                    Label("Rebuild Remote Catalog", systemImage: "arrow.clockwise")
                }
                .disabled(
                    remote.isLoading
                    || settings.streamHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || (settings.streamBackend == .subsonic
                        && (settings.streamUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || settings.streamPassword.isEmpty))
                )

                LabeledContent("Backend in use", value: settings.streamBackend.shortName)
                LabeledContent("Cached catalog", value: remote.catalogSyncStatus)
                if let lastCheck = remote.lastCatalogCheck {
                    LabeledContent("Last background check", value: lastCheck.formatted(date: .abbreviated, time: .shortened))
                }

                if settings.streamBackend == .subsonic {
                    Text("Use the HTTPS server URL or Tailscale hostname, leave the port blank for standard HTTPS (or enter 443), and use /rest as the API path. Resonance authenticates with a salted Subsonic token and requests JSON responses.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("The Resonance Manifest backend uses the included companion server, normally on port 8080 with /resonance/library.json as the manifest path.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SettingsCategory(
                "Finder File Sharing",
                key: "finder-file-sharing",
                isExpanded: $settings.settingsFinderExpanded
            ) {
                LabeledContent("Status") {
                    Label(
                        library.sharedFolderIsReady ? "Ready" : "Unavailable",
                        systemImage: library.sharedFolderIsReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(library.sharedFolderIsReady ? Color.green : Color.orange)
                }
                LabeledContent("Shared folder", value: LibraryStore.sharedMusicFolderName)
                LabeledContent("Files in shared folder", value: "\(library.sharedFolderTrackCount)")
                if let lastScan = library.lastSharedFolderScan {
                    LabeledContent(
                        "Last scan",
                        value: lastScan.formatted(date: .abbreviated, time: .shortened)
                    )
                }
                Button {
                    Task { await library.scanSharedMusicFolder(forceMetadataRefresh: true) }
                } label: {
                    Label(
                        library.isScanning ? "Scanning…" : "Scan Shared Music Folder",
                        systemImage: "arrow.clockwise"
                    )
                }
                .disabled(library.isScanning)

                Text("Connect the iPhone to your Mac, open it in Finder, choose Resonance Alpha, and drop music or folders into ‘\(LibraryStore.sharedMusicFolderName)’. Resonance scans subfolders automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(library.sharedMusicFolderDisplayPath)
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
                Text(library.scanStatus)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            SettingsCategory(
                "Reported Errors",
                key: "reported-errors",
                isExpanded: $settings.settingsReportedErrorsExpanded
            ) {
                if errorLog.entries.isEmpty {
                    Label("No errors have been reported", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    if let latest = errorLog.latest {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(latest.source)
                                .font(.caption.weight(.semibold))
                            Text(latest.message)
                                .font(.callout.monospaced())
                                .fixedSize(horizontal: false, vertical: true)
                            Text(latest.timestamp.formatted(date: .abbreviated, time: .standard))
                                .font(.caption2)
                        }
                        .foregroundStyle(.red)
                    }

                    DisclosureGroup("Error History (\(errorLog.entries.count))") {
                        ForEach(errorLog.entries) { entry in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.source)
                                    .font(.caption.weight(.semibold))
                                Text(entry.message)
                                    .font(.caption.monospaced())
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(entry.timestamp.formatted(date: .numeric, time: .standard))
                                    .font(.caption2)
                            }
                            .foregroundStyle(.red)
                            .padding(.vertical, 3)
                        }
                    }

                    HStack {
                        Button {
                            UIPasteboard.general.string = errorLog.copyText()
                        } label: {
                            Label("Copy Errors", systemImage: "doc.on.doc")
                        }
                        Spacer()
                        Button {
                            errorLog.clear()
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .accessibilityLabel("Delete reported errors")
                    }
                }
            }

            SettingsCategory(
                "Prototype Status",
                key: "prototype-status",
                isExpanded: $settings.settingsPrototypeExpanded
            ) {
                LabeledContent("Build", value: buildDescription)
                StatusRow(title: "Finder and Files app transfer folder", detail: "Available", icon: "checkmark.circle.fill")
                StatusRow(title: "Shared-folder rescanning", detail: "Launch, foreground, import, or manual", icon: "checkmark.circle.fill")
                StatusRow(title: "Local import and indexing", detail: "Available", icon: "checkmark.circle.fill")
                StatusRow(title: "Artist → albums → numbered tracks", detail: "Available", icon: "checkmark.circle.fill")
                StatusRow(title: "Playback and lock-screen controls", detail: "Artwork enabled", icon: "checkmark.circle.fill")
                StatusRow(title: "Shuffle, repeat, and queue controls", detail: "Artwork-complete queue", icon: "checkmark.circle.fill")
                StatusRow(title: "Play Next and Add to Queue actions", detail: "Tracks and albums", icon: "checkmark.circle.fill")
                StatusRow(title: "Now Playing track-swipe controls", detail: "Artwork and metadata swipe zone", icon: "checkmark.circle.fill")
                StatusRow(title: "Mini-player transport controls", detail: "Previous, play/pause, and next", icon: "checkmark.circle.fill")
                StatusRow(title: "Precision scrubbing and 15-second skips", detail: "Available", icon: "checkmark.circle.fill")
                StatusRow(title: "Volume and sleep timer", detail: "Available", icon: "checkmark.circle.fill")
                StatusRow(title: "Persistent navigation and mini-player", detail: "Available", icon: "checkmark.circle.fill")
                StatusRow(title: "Favorites and smart library collections", detail: "Persistent", icon: "checkmark.circle.fill")
                StatusRow(title: "Recently added and recently played", detail: "Up to 100 tracks", icon: "checkmark.circle.fill")
                StatusRow(title: "User playlists", detail: "Create, reorder, rename, and delete", icon: "checkmark.circle.fill")
                StatusRow(title: "Streaming library browser", detail: "Navidrome/Subsonic and Resonance manifest backends", icon: "checkmark.circle.fill")
                StatusRow(title: "Streaming browse parity", detail: "Artists, album artists, albums, songs, favorites, recents, view modes, and alphabet index", icon: "checkmark.circle.fill")
                StatusRow(title: "Navidrome playlists", detail: "Create, rename, delete, add, remove, reorder, and play", icon: "checkmark.circle.fill")
                StatusRow(title: "Remote playback crash shield", detail: "Stable single-item AVPlayer path", icon: "checkmark.circle.fill")
                StatusRow(title: "Preloaded gapless audio engine", detail: "Beta — local files", icon: "checkmark.circle.fill")
                StatusRow(title: "Library metadata and custom artwork editing", detail: "Track, album, and artist edits", icon: "checkmark.circle.fill")
                StatusRow(title: "Direct audio-file tag writing", detail: "FLAC and MP3", icon: "checkmark.circle.fill")
                StatusRow(title: "Remote downloads", detail: "Progress, cancellation, replacement, and local indexing", icon: "checkmark.circle.fill")
                StatusRow(title: "QR server setup", detail: "Camera scan", icon: "checkmark.circle.fill")
                StatusRow(title: "Online artwork search", detail: "Apple and MusicBrainz / Cover Art Archive sources", icon: "checkmark.circle.fill")

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Stage completion")
                        Spacer()
                        Text("100%").font(.caption.monospacedDigit())
                    }
                    ProgressView(value: 1.0)
                    Text("This percentage represents prototype feature coverage, not App Store readiness.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Settings")
        .safeAreaPadding(.top, 84)
        .tint(settings.accentColor)
        .scrollContentBackground(.hidden)
        .listRowBackground(Color.clear)
        .listSectionSpacing(4)
        .listRowSpacing(2)
        // Keep the final categories and Prototype Status above the custom tab
        // bar so they can be scrolled fully into view on every theme.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 112)
        }
            .background {
                ResonanceThemeBackdrop()
            }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(
            TapGesture().onEnded {
                guard isTextFieldFocused else { return }
                isTextFieldFocused = false
                UIApplication.shared.endEditing()
            }
        )
        .onChange(of: settings.showLockScreenArtwork) { _, _ in
            player.refreshNowPlayingMetadata()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 45)
                .onEnded { value in
                    if value.startLocation.x < 36 && value.translation.width > 70 {
                        isTextFieldFocused = false
                        UIApplication.shared.endEditing()
                        closeSettings()
                    }
                }
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: closeSettings) { Label("Close Settings", systemImage: "chevron.left") }
            }
        }
        .onAppear {
            if accentHexDraft.isEmpty { accentHexDraft = settings.accentHex }
        }
        .sheet(isPresented: $showingServerQRCodeScanner) {
            ServerQRCodeScannerView { value in
                showingServerQRCodeScanner = false
                do {
                    try ServerQRCodeConfiguration.apply(value, to: settings)
                } catch {
                    serverQRCodeError = error.localizedDescription
                }
            }
            .ignoresSafeArea()
        }
        .alert(
            "Could Not Read Server QR Code",
            isPresented: Binding(
                get: { serverQRCodeError != nil },
                set: { if !$0 { serverQRCodeError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { serverQRCodeError = nil }
        } message: {
            Text(serverQRCodeError ?? "The QR code did not contain a usable server address.")
        }
        .onChange(of: settings.accentHex) { _, value in
            if accentHexDraft != value { accentHexDraft = value }
        }
        .onChange(of: accentHexDraft) { _, value in
            guard value.count == 6 else { return }
            accentHexCommitter.schedule(value) { [weak settings] value in
                guard let settings else { return }
                guard settings.accentHex != value else { return }
                settings.accentHex = value
                settings.applyThemeColorToText = false
            }
        }
    }

    private func applyAccentHex(_ value: String) {
        accentHexCommitter.cancel()
        accentHexDraft = value
        settings.accentHex = value
        settings.applyThemeColorToText = false
    }

    private var accentColorPickerBinding: Binding<Color> {
        Binding(
            get: {
                Color(hex: accentHexDraft)
                    ?? Color(hex: settings.accentHex)
                    ?? settings.accentColor
            },
            set: { color in
                guard let hex = hexValue(from: color) else { return }
                applyAccentHex(hex)
            }
        )
    }

    private func hexValue(from color: Color) -> String? {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        return String(
            format: "%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }

    private var applyThemeColorToTextBinding: Binding<Bool> {
        Binding(
            get: { settings.applyThemeColorToText },
            set: { value in
                // A pending hex edit must not finish after the user changes
                // this preference during a tab transition.
                accentHexCommitter.cancel()
                settings.applyThemeColorToText = value
            }
        )
    }
}

private enum ServerQRCodeError: LocalizedError {
    case empty
    case missingHost
    case unsupported

    var errorDescription: String? {
        switch self {
        case .empty:
            "The QR code was empty."
        case .missingHost:
            "The QR code did not contain a server host or URL."
        case .unsupported:
            "Use a server URL, hostname, or a JSON object containing a url or host value."
        }
    }
}

private struct ServerQRCodeJSONPayload: Decodable {
    let url: String?
    let server: String?
    let host: String?
    let port: String?
    let https: Bool?
    let backend: String?
    let path: String?
}

@MainActor
private enum ServerQRCodeConfiguration {
    static func apply(_ rawValue: String, to settings: AppSettings) throws {
        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { throw ServerQRCodeError.empty }

        var address = raw
        var jsonPort: String?
        var jsonHTTPS: Bool?
        var jsonBackend: String?
        var jsonPath: String?
        if let data = raw.data(using: .utf8),
           let payload = try? JSONDecoder().decode(ServerQRCodeJSONPayload.self, from: data) {
            address = payload.url ?? payload.server ?? payload.host ?? ""
            jsonPort = payload.port
            jsonHTTPS = payload.https
            jsonBackend = payload.backend
            jsonPath = payload.path
        }
        guard !address.isEmpty else { throw ServerQRCodeError.missingHost }

        let candidate = address.contains("://") ? address : "http://\(address)"
        guard var components = URLComponents(string: candidate),
              let host = components.host,
              !host.isEmpty
        else {
            throw ServerQRCodeError.unsupported
        }

        settings.streamHost = host
        settings.streamPort = components.port.map(String.init) ?? jsonPort ?? ""
        settings.streamUseHTTPS = jsonHTTPS ?? (components.scheme?.lowercased() == "https")

        let path = jsonPath ?? components.path
        if let jsonBackend {
            let normalized = jsonBackend.lowercased()
            settings.streamBackend = normalized.contains("manifest")
                ? .resonanceManifest
                : .subsonic
        } else if path.localizedCaseInsensitiveContains("resonance/library.json") {
            settings.streamBackend = .resonanceManifest
        }
        if !path.isEmpty, path != "/" {
            settings.streamManifestPath = path
        }
        if settings.streamBackend == .resonanceManifest,
           settings.streamManifestPath == "/rest" {
            settings.streamManifestPath = "/resonance/library.json"
        }
        components = URLComponents()
    }
}

private struct ServerQRCodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onCode: (String) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ServerQRCodeScannerRepresentable(onCode: onCode)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 18)
                .padding(.trailing, 16)
        }
        .background(Color.black)
    }
}

private struct ServerQRCodeScannerRepresentable: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ServerQRCodeScannerController {
        ServerQRCodeScannerController(onCode: onCode)
    }

    func updateUIViewController(_ controller: ServerQRCodeScannerController, context: Context) { }
}

@MainActor
private final class ServerQRCodeScannerController: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
    private let onCode: (String) -> Void
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didEmitCode = false

    init(onCode: @escaping (String) -> Void) {
        self.onCode = onCode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        requestCameraIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning, previewLayer != nil {
            session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    private func requestCameraIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.configureCaptureSession()
                    } else {
                        self.showMessage("Camera access is required to scan a server QR code.")
                    }
                }
            }
        default:
            showMessage("Allow camera access in Settings to scan a server QR code.")
        }
    }

    private func configureCaptureSession() {
        guard previewLayer == nil,
              let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        guard session.canAddInput(input) else {
            showMessage("The camera could not be configured.")
            return
        }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            showMessage("The camera could not scan QR codes.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
        session.startRunning()
    }

    private func showMessage(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didEmitCode,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue
        else { return }
        didEmitCode = true
        session.stopRunning()
        onCode(value)
    }
}

@MainActor
private final class DebouncedSettingCommitter: ObservableObject {
    private var task: Task<Void, Never>?

    func schedule(_ value: String, commit: @escaping (String) -> Void) {
        task?.cancel()
        task = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 180_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            commit(value)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}

private struct SettingsCategory<Content: View>: View {
    @EnvironmentObject private var settings: AppSettings
    let title: String
    let key: String
    @Binding var isExpanded: Bool
    let content: () -> Content

    init(
        _ title: String,
        key: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.key = key
        self._isExpanded = isExpanded
        self.content = content
    }

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                if isExpanded {
                    content()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.system(size: 34, weight: .bold))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 1.5)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(settings.accentColor.opacity(0.22), lineWidth: 1)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
            .onChange(of: isExpanded) { _, expanded in
                ResonanceDiagnostics.shared.record(
                    "settings.category.changed",
                    details: [
                        "category": key,
                        "expanded": String(expanded)
                    ]
                )
            }
        }
    }
}

private struct RGBHexField: View {
    @Binding var hex: String
    let onBeginEditing: () -> Void
    @State private var red = "A8"
    @State private var green = "55"
    @State private var blue = "F7"
    @State private var selected: Channel = .red
    @State private var focusedChannel: Channel?

    private enum Channel { case red, green, blue }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text("#")
                    .foregroundStyle(.secondary)
                    .font(.title3.monospaced())
                channelField("Red", text: $red, color: .red, channel: .red)
                channelField("Green", text: $green, color: .green, channel: .green)
                channelField("Blue", text: $blue, color: .blue, channel: .blue)
                Spacer()
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(hex: combined) ?? .clear)
                    .frame(width: 34, height: 28)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(.quaternary))
            }

            HStack {
                Text(selectedLabel + " channel")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selectedColor)
                Spacer()
                Text(selectedValue)
                    .font(.caption.monospaced().weight(.semibold))
            }

            GeometryReader { proxy in
                let controlWidth = proxy.size.width * 0.8
                HexChannelSlider(
                    value: Binding(
                        get: { selectedInteger },
                        set: { setSelectedInteger($0) }
                    ),
                    color: selectedColor,
                    accessibilityLabel: selectedLabel + " channel",
                    onBeginEditing: {
                        onBeginEditing()
                        focusedChannel = selected
                    }
                )
                .frame(width: controlWidth, height: 55)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(height: 55)

            Text("Tap a two-character value to edit it. The insertion point opens at the right edge.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .onAppear { loadFromHex() }
        .onChange(of: hex) { _, _ in loadFromHex() }
        .onChange(of: red) { _, value in red = sanitize(value); saveToHex() }
        .onChange(of: green) { _, value in green = sanitize(value); saveToHex() }
        .onChange(of: blue) { _, value in blue = sanitize(value); saveToHex() }
    }

    private func channelField(
        _ label: String,
        text: Binding<String>,
        color: Color,
        channel: Channel
    ) -> some View {
        HexChannelTextField(
            text: text,
            isFocused: Binding(
                get: { focusedChannel == channel },
                set: { focused in
                    if focused {
                        selected = channel
                        focusedChannel = channel
                    } else if focusedChannel == channel {
                        focusedChannel = nil
                    }
                }
            ),
            textColor: channel == .red ? .systemRed : (channel == .green ? .systemGreen : .systemBlue),
            onBeginEditing: {
                onBeginEditing()
                selected = channel
            }
        )
        .frame(width: 43, height: 32)
        .background(
            selected == channel ? color.opacity(0.16) : Color.secondary.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(selected == channel ? color : .clear, lineWidth: 1.5)
        )
        .accessibilityLabel(label + " hex value")
    }

    private var combined: String { red + green + blue }
    private var selectedValue: String { selected == .red ? red : selected == .green ? green : blue }
    private var selectedInteger: Int { Int(selectedValue, radix: 16) ?? 0 }
    private var selectedColor: Color { selected == .red ? .red : selected == .green ? .green : .blue }
    private var selectedLabel: String { selected == .red ? "Red" : selected == .green ? "Green" : "Blue" }

    private func setSelectedInteger(_ value: Int) {
        let formatted = String(format: "%02X", max(0, min(255, value)))
        switch selected {
        case .red: red = formatted
        case .green: green = formatted
        case .blue: blue = formatted
        }
    }

    private func sanitize(_ value: String) -> String {
        String(value.uppercased().filter { $0.isHexDigit }.prefix(2))
    }

    private func loadFromHex() {
        let cleaned = hex.uppercased().filter { $0.isHexDigit }
        let padded = String(cleaned.prefix(6)).padding(toLength: 6, withPad: "0", startingAt: 0)
        let values = [
            String(padded.prefix(2)),
            String(padded.dropFirst(2).prefix(2)),
            String(padded.dropFirst(4).prefix(2))
        ]
        if [red, green, blue] != values {
            red = values[0]
            green = values[1]
            blue = values[2]
        }
    }

    private func saveToHex() {
        guard red.count == 2, green.count == 2, blue.count == 2 else { return }
        if hex != combined { hex = combined }
    }
}

private struct HexChannelSlider: View {
    @Binding var value: Int
    let color: Color
    let accessibilityLabel: String
    let onBeginEditing: () -> Void

    private let thumbDiameter: CGFloat = 24
    private let trackHeight: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, thumbDiameter)
            let thumbRadius = thumbDiameter / 2
            let usableWidth = max(1, width - thumbDiameter)
            let clampedValue = min(255, max(0, value))
            let ratio = CGFloat(clampedValue) / 255
            let thumbCenterX = thumbRadius + usableWidth * ratio

            VStack(spacing: 2) {
                ZStack(alignment: .topLeading) {
                    ForEach(0..<16, id: \.self) { nibble in
                        // Each marker represents the high nibble at its exact
                        // byte value: 0 = 00, 1 = 10, …, F = F0.
                        let hexValue = nibble * 16
                        let x = thumbRadius + usableWidth * CGFloat(hexValue) / 255
                        VStack(spacing: 1) {
                            Text(String(format: "%X", nibble))
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                            Rectangle()
                                .fill(color.opacity(0.65))
                                .frame(width: 1, height: 4)
                        }
                        .frame(width: 16)
                        .position(x: x, y: 7)
                    }
                }
                .foregroundStyle(.secondary)
                .frame(width: width, height: 16, alignment: .topLeading)
                .accessibilityHidden(true)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.28))
                        .frame(width: usableWidth, height: trackHeight)
                        .offset(x: thumbRadius)

                    Capsule()
                        .fill(color)
                        .frame(width: max(0, usableWidth * ratio), height: trackHeight)
                        .offset(x: thumbRadius)

                    Circle()
                        .fill(color)
                        .frame(width: thumbDiameter, height: thumbDiameter)
                        .shadow(radius: 1)
                        .offset(x: thumbCenterX - thumbRadius)
                }
                // Keep the track layer in the same full-width coordinate
                // space as the nibble markers. Without this explicit leading
                // frame, its intrinsic width is centered before the thumb
                // inset is applied a second time.
                .frame(width: width, height: 28, alignment: .leading)
            }
            .frame(width: width, height: 46, alignment: .top)
            .contentShape(Rectangle())
            // Claim the drag before the enclosing Form can interpret it as
            // vertical scrolling. The slider should move only its channel.
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { gesture in
                        onBeginEditing()
                        let x = min(max(0, gesture.location.x - thumbRadius), usableWidth)
                        let nextValue = Int((x / usableWidth * 255).rounded())
                        if nextValue != value {
                            value = nextValue
                        }
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(String(format: "%02X", clampedValue))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: value = min(255, value + 1)
                case .decrement: value = max(0, value - 1)
                @unknown default: break
                }
            }
        }
    }
}

private struct HexChannelTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let textColor: UIColor
    let onBeginEditing: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.delegate = context.coordinator
        field.textAlignment = .center
        field.font = .monospacedSystemFont(ofSize: 19, weight: .semibold)
        field.textColor = textColor
        field.keyboardType = .asciiCapable
        field.autocapitalizationType = .allCharacters
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.text = text
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(title: "Done", style: .done, target: context.coordinator, action: #selector(Coordinator.done))
        ]
        field.inputAccessoryView = toolbar
        context.coordinator.textField = field
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        uiView.textColor = textColor
        if isFocused, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
        if uiView.text != text {
            uiView.text = text
            if uiView.isFirstResponder {
                moveCursorToEnd(uiView)
            }
        }
    }

    private func moveCursorToEnd(_ textField: UITextField) {
        let end = textField.endOfDocument
        textField.selectedTextRange = textField.textRange(from: end, to: end)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: HexChannelTextField
        weak var textField: UITextField?

        init(parent: HexChannelTextField) {
            self.parent = parent
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.isFocused = true
            parent.onBeginEditing()
            DispatchQueue.main.async {
                let end = textField.endOfDocument
                textField.selectedTextRange = textField.textRange(from: end, to: end)
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.isFocused = false
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            guard let current = textField.text,
                  let swiftRange = Range(range, in: current) else { return false }
            let proposed = current.replacingCharacters(in: swiftRange, with: string).uppercased()
            return proposed.count <= 2 && proposed.allSatisfy(\.isHexDigit)
        }

        @objc func textChanged(_ sender: UITextField) {
            let cleaned = String((sender.text ?? "").uppercased().filter { $0.isHexDigit }.prefix(2))
            if sender.text != cleaned { sender.text = cleaned }
            parent.text = cleaned
        }

        @objc func done() {
            textField?.resignFirstResponder()
        }
    }
}

private extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct ThemePreview: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var player: PlayerController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Theme Preview").font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                CurrentTrackArtworkPreview(size: 62)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sample Album").font(.headline)
                    Text("Sample Artist").font(.caption).foregroundStyle(.secondary)
                    Text("01  First Track").font(.caption)
                }
                Spacer()
                Image(systemName: "pause.fill")
                Image(systemName: "forward.fill")
            }
            .padding(10)
            .background(settings.themeSurfaceColor, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(settings.accentColor.opacity(0.35), lineWidth: 1)
            }
        }
        .foregroundStyle(settings.textAccentColor)
        .padding(.vertical, 4)
    }
}

private struct HeroButtonStylePreview: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hero button preview")
                .font(.subheadline.weight(.semibold))

            HStack(alignment: .center, spacing: 8) {
                VStack(spacing: 4) {
                    ResonanceHeroActionButton(
                        title: "Play",
                        systemImage: "play.fill",
                        tint: settings.accentColor,
                        prominent: true,
                        action: {}
                    )
                    ResonanceHeroActionButton(
                        title: "Favorite",
                        systemImage: "heart",
                        tint: settings.accentColor,
                        prominent: false,
                        action: {}
                    )
                }

                CurrentTrackArtworkPreview(size: 112)

                VStack(spacing: 4) {
                    ResonanceHeroActionButton(
                        title: "Play Next",
                        systemImage: "text.insert",
                        tint: settings.accentColor,
                        prominent: false,
                        action: {}
                    )
                    ResonanceHeroActionButton(
                        title: "Add to Queue",
                        systemImage: "text.append",
                        tint: settings.accentColor,
                        prominent: false,
                        action: {}
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(
                settings.themeSurfaceColor.opacity(0.22),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(settings.accentColor.opacity(0.25), lineWidth: 1)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

private struct CurrentTrackArtworkPreview: View {
    @EnvironmentObject private var player: PlayerController
    let size: CGFloat

    var body: some View {
        ArtworkView(
            data: player.currentTrack.flatMap { player.artworkData(for: $0) },
            embedded: player.currentTrack.map { player.artworkIsEmbedded(for: $0) } ?? true,
            size: size
        )
    }
}

private struct ThemeChoiceButton: View {
    @EnvironmentObject private var settings: AppSettings
    let theme: ResonanceVisualTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: theme.accentHex) ?? .purple,
                                    Color(hex: theme.backgroundHex) ?? .black
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    if let imageName = theme.backgroundImageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .opacity(0.40)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if settings.visualTheme == theme {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                                .padding(7)
                        }
                    }

                Text(theme.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(theme.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(
                settings.visualTheme == theme
                    ? settings.accentColor.opacity(0.12)
                    : Color.secondary.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        settings.visualTheme == theme ? settings.accentColor : .clear,
                        lineWidth: 1.5
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .buttonStyle(ResonanceSwipeAwareButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityAddTraits(settings.visualTheme == theme ? .isSelected : [])
    }
}

private struct StatusRow: View {
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
