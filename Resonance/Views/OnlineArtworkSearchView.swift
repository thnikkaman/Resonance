import SwiftUI

struct OnlineArtworkSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    let artist: String
    let album: String?
    let onApplyToApp: (Data) -> Void
    let onSaveToFiles: (Data) async -> String?

    @State private var suggestions: [ArtworkSearchSuggestion] = []
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
                                    isSaving: isSaving,
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
            suggestions = try await ArtworkSearchService.search(artist: artist, album: album)
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
    let isSaving: Bool
    let onApplyToApp: (Data) -> Void
    let onSaveToFiles: (Data) -> Void
    @State private var imageData: Data?
    @State private var isLoading = true
    @State private var loadError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            .frame(maxWidth: .infinity)

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
                .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
        }
        .task { await loadImage() }
    }

    private func loadImage() async {
        do {
            imageData = try await ArtworkSearchService.imageData(from: suggestion.imageURL)
            isLoading = false
        } catch {
            loadError = true
            isLoading = false
        }
    }
}
