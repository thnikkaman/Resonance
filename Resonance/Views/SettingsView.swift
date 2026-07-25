import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var remote: RemoteLibraryStore
    @EnvironmentObject private var errorLog: AppErrorLog
    let openLibrary: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    @State private var accentHexDraft = ""
    @StateObject private var accentHexCommitter = DebouncedSettingCommitter()
    private let palette = ["A855F7", "3B82F6", "14B8A6", "22C55E", "EAB308", "F97316", "EF4444"]

    private var buildDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "Alpha \(version) (\(build))"
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

                HStack {
                    ForEach(palette, id: \.self) { hex in
                        Button { applyAccentHex(hex) } label: {
                            Circle()
                                .fill(Color(hex: hex) ?? .purple)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if settings.normalizedAccentHex == hex {
                                        Image(systemName: "checkmark").foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Hex Color Code")
                        .font(.subheadline.weight(.semibold))
                    RGBHexField(hex: $accentHexDraft)
                }

                Toggle("Apply theme color to text", isOn: $settings.applyThemeColorToText)
                Toggle("Red outline for cached artwork", isOn: $settings.showArtworkWarning)

                ThemePreview()
            }

            SettingsCategory(
                "Playback",
                key: "playback",
                isExpanded: $settings.settingsPlaybackExpanded
            ) {
                Toggle("Gapless preload next track", isOn: $settings.preloadNextTrack)
                LabeledContent("Local preload budget", value: "\(Int(settings.localBufferMB)) MB")
                Slider(value: $settings.localBufferMB, in: 10...250, step: 10)
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
                if let preloaded = player.preloadedTrackTitle {
                    LabeledContent("Preloaded next track", value: preloaded)
                } else {
                    LabeledContent("Preloaded next track", value: "None")
                }
                Text(player.preloadDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("The budget controls how much of a large next file is scheduled before the boundary. Files larger than the budget receive a partial opening preload and continue from disk after playback starts. Multichannel sources use an explicit stereo matrix. Left-side channels stay on the left, right-side channels stay on the right, and center plus LFE are folded equally into both outputs.")
                    .font(.caption)
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
                        Button(role: .destructive) {
                            errorLog.clear()
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                    }
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

                TextField("Server URL or Tailscale host", text: $settings.streamHost)
                    .focused($isTextFieldFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                TextField(
                    settings.streamBackend == .subsonic
                        ? "Port (blank uses the URL or HTTPS default)"
                        : "Port (8080 for the included test server)",
                    text: $settings.streamPort
                )
                .focused($isTextFieldFocused)
                .keyboardType(.numberPad)

                Toggle("Use HTTPS", isOn: $settings.streamUseHTTPS)
                TextField(
                    settings.streamBackend == .subsonic ? "API path" : "Manifest path",
                    text: $settings.streamManifestPath
                )
                .focused($isTextFieldFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                if settings.streamBackend == .subsonic {
                    TextField("Navidrome / Subsonic username", text: $settings.streamUsername)
                        .focused($isTextFieldFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Navidrome / Subsonic password", text: $settings.streamPassword)
                        .focused($isTextFieldFocused)
                        .textContentType(.password)
                    Label("The password is stored in the iOS Keychain.", systemImage: "key.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Backend in use", value: settings.streamBackend.shortName)
                LabeledContent("Streaming buffer budget", value: "\(Int(settings.networkBufferMB)) MB")
                Slider(value: $settings.networkBufferMB, in: 10...250, step: 10)
                Toggle("Experimental streaming gapless", isOn: $settings.streamingGaplessExperimental)
                Text("When enabled, the remote player queues the next stream ahead of the current one. This is an experimental phase and may fall back to normal remote playback at a boundary.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("Connection", value: remote.connectionStatus)
                LabeledContent("Cached catalog", value: remote.catalogSyncStatus)
                if let lastCheck = remote.lastCatalogCheck {
                    LabeledContent("Last background check", value: lastCheck.formatted(date: .abbreviated, time: .shortened))
                }
                if player.currentTrack?.isRemote == true {
                    LabeledContent("Active network buffer", value: player.networkBufferStatus)
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

                Text("Connect the iPhone to your Mac, open it in Finder, choose Files, select Resonance Alpha, and drop music or folders into ‘\(LibraryStore.sharedMusicFolderName)’. Resonance scans subfolders automatically.")
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
                "Library",
                key: "library",
                isExpanded: $settings.settingsLibraryExpanded
            ) {
                Button("Restore demo library") { Task { await library.resetDemoLibrary() } }
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
                StatusRow(title: "Direct audio-file tag writing", detail: "Planned", icon: "clock")
                StatusRow(title: "Online artwork search", detail: "Planned", icon: "clock")

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Stage completion")
                        Spacer()
                        Text("96%").font(.caption.monospacedDigit())
                    }
                    ProgressView(value: 0.96)
                    Text("This percentage represents prototype feature coverage, not App Store readiness.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Settings")
        .scrollDismissesKeyboard(.interactively)
        .contentShape(Rectangle())
        .onTapGesture {
            isTextFieldFocused = false
            UIApplication.shared.endEditing()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 45)
                .onEnded { value in
                    if value.startLocation.x < 36 && value.translation.width > 70 {
                        isTextFieldFocused = false
                        UIApplication.shared.endEditing()
                        openLibrary()
                    }
                }
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: openLibrary) { Label("Library", systemImage: "chevron.left") }
            }
        }
        .onAppear {
            if accentHexDraft.isEmpty { accentHexDraft = settings.accentHex }
        }
        .onChange(of: settings.accentHex) { _, value in
            if accentHexDraft != value { accentHexDraft = value }
        }
        .onChange(of: accentHexDraft) { _, value in
            guard value.count == 6 else { return }
            accentHexCommitter.schedule(value) { [weak settings] value in
                if settings?.accentHex != value { settings?.accentHex = value }
            }
        }
    }

    private func applyAccentHex(_ value: String) {
        accentHexCommitter.cancel()
        accentHexDraft = value
        settings.accentHex = value
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
                Text(title)
                    .font(.headline)
            }
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
    @State private var red = "A8"
    @State private var green = "55"
    @State private var blue = "F7"
    @State private var selected: Channel = .red

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

                VStack(spacing: 3) {
                    ZStack(alignment: .topLeading) {
                        let thumbRadius: CGFloat = 14
                        let usableWidth = max(0, controlWidth - (thumbRadius * 2))
                        ForEach(0..<16, id: \.self) { value in
                            let highNibbleValue = CGFloat(value * 16)
                            let x = thumbRadius + usableWidth * (highNibbleValue / 255)
                            VStack(spacing: 1) {
                                Text(String(format: "%X", value))
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                Rectangle()
                                    .fill(selectedColor.opacity(0.65))
                                    .frame(width: 1, height: 4)
                            }
                            .frame(width: 16)
                            .position(x: x, y: 7)
                        }
                    }
                    .foregroundStyle(.secondary)
                    .frame(width: controlWidth, height: 14)
                    .accessibilityHidden(true)

                    Slider(
                        value: Binding(
                            get: { Double(selectedInteger) },
                            set: { setSelectedInteger(Int($0.rounded())) }
                        ),
                        in: 0...255,
                        step: 1
                    )
                    .tint(selectedColor)
                    .frame(width: controlWidth)
                }
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
            textColor: channel == .red ? .systemRed : (channel == .green ? .systemGreen : .systemBlue),
            onBeginEditing: { selected = channel }
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

private struct HexChannelTextField: UIViewRepresentable {
    @Binding var text: String
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
            parent.onBeginEditing()
            DispatchQueue.main.async {
                let end = textField.endOfDocument
                textField.selectedTextRange = textField.textRange(from: end, to: end)
            }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Theme Preview").font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                PlaceholderArtwork(symbol: "music.note", size: 62)
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .foregroundStyle(settings.applyThemeColorToText ? settings.accentColor : Color.primary)
        .padding(.vertical, 4)
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
