import SwiftUI

struct OnlineArtworkSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    let artist: String
    let albumArtist: String?
    let album: String?
    let onApplyToApp: (Data) -> Void
    let onSaveToFiles: (Data) async -> String?

    init(
        artist: String,
        albumArtist: String? = nil,
        album: String?,
        onApplyToApp: @escaping (Data) -> Void,
        onSaveToFiles: @escaping (Data) async -> String?
    ) {
        self.artist = artist
        self.albumArtist = albumArtist
        self.album = album
        self.onApplyToApp = onApplyToApp
        self.onSaveToFiles = onSaveToFiles
    }

    @State private var suggestions: [ArtworkSearchSuggestion] = []
    @State private var selectedSuggestionID: String?
    @State private var recommendedSuggestionID: String?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Searching album art…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if suggestions.isEmpty {
                    VStack(spacing: 14) {
                        ContentUnavailableView(
                            "No Artwork Found",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("The repositories returned no matching covers.")
                        )
                        Button("Try Again") {
                            Task { await search() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(suggestions) { suggestion in
                                OnlineArtworkSuggestionCard(
                                    suggestion: suggestion,
                                    isSelected: selectedSuggestionID == suggestion.id,
                                    isRecommended: recommendedSuggestionID == suggestion.id,
                                    isSaving: isSaving,
                                    onSelect: { selectedSuggestionID = suggestion.id },
                                    onImageAvailabilityChanged: { id, available in
                                        guard !available, recommendedSuggestionID == id else { return }
                                        let next = suggestions.first { $0.id != id }
                                        recommendedSuggestionID = next?.id
                                        if selectedSuggestionID == id { selectedSuggestionID = next?.id }
                                    },
                                    onApplyToApp: chooseForApp,
                                    onSaveToFiles: saveToFiles
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .background { ResonanceThemeBackdrop() }
            .navigationTitle("Search Online Artwork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Artwork Search", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "The artwork could not be loaded.")
            }
            .task { await search() }
        }
        .tint(settings.accentColor)
    }

    private func search() async {
        isLoading = true
        do {
            suggestions = try await ArtworkSearchService.search(
                artist: artist,
                album: album,
                albumArtist: albumArtist
            )
            selectedSuggestionID = suggestions.first?.id
            recommendedSuggestionID = suggestions.first?.id
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func chooseForApp(_ data: Data) {
        onApplyToApp(data)
        dismiss()
    }

    private func saveToFiles(_ data: Data) {
        isSaving = true
        Task {
            if let error = await onSaveToFiles(data) {
                isSaving = false
                errorMessage = error
            } else {
                isSaving = false
                dismiss()
            }
        }
    }
}

private struct OnlineArtworkSuggestionCard: View {
    let suggestion: ArtworkSearchSuggestion
    let isSelected: Bool
    let isRecommended: Bool
    let isSaving: Bool
    let onSelect: () -> Void
    let onImageAvailabilityChanged: (String, Bool) -> Void
    let onApplyToApp: (Data) -> Void
    let onSaveToFiles: (Data) -> Void
    @State private var imageData: Data?
    @State private var isLoading = true
    @State private var loadError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onSelect) {
                Group {
                    if let imageData {
                        ArtworkView(data: imageData, embedded: false, size: 150, showWarningBorder: false)
                    } else if isLoading {
                        ProgressView().frame(width: 150, height: 150)
                    } else {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.largeTitle)
                            .frame(width: 150, height: 150)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            if isSelected {
                Text(isRecommended ? "Recommended match" : "Selected cover")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
            Text(suggestion.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            Text(suggestion.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(suggestion.source)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Button("Apply to App") {
                guard let imageData else { return }
                onApplyToApp(imageData)
            }
            .buttonStyle(.borderedProminent)
            .disabled(imageData == nil || isSaving)

            Button("Save to Files") {
                guard let imageData else { return }
                onSaveToFiles(imageData)
            }
            .buttonStyle(.bordered)
            .disabled(imageData == nil || isSaving)
        }
        .padding(10)
        .background { ResonanceThemeSurfaceBackdrop() }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? .red : Color.accentColor.opacity(0.22), lineWidth: isSelected ? 3 : 1)
        }
        .task { await loadImage() }
    }

    private func loadImage() async {
        do {
            imageData = try await ArtworkSearchService.imageData(from: suggestion.imageURL)
            isLoading = false
            onImageAvailabilityChanged(suggestion.id, true)
        } catch {
            loadError = true
            isLoading = false
            onImageAvailabilityChanged(suggestion.id, false)
        }
    }
}
