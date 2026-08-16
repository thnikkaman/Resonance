import Foundation

/// Matches an audio file to an adjacent LRC while preserving the same-folder boundary.
///
/// Some audiobook importers prepend a disc/track number and replace title punctuation
/// in the audio filename without making the same changes to the companion LRC. The
/// normalized stem accommodates that representation difference; the normalized parent
/// path remains part of the key so an LRC from another folder can never match.
enum LyricsCompanionMatcher {
    static func matchKey(parentPath: String, stem: String) -> String {
        normalizedParentPath(parentPath) + "\u{001F}" + normalizedStem(stem)
    }

    static func normalizedStem(_ rawStem: String) -> String {
        let folded = rawStem
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        let audiobookStem: String
        if let chapterRange = folded.range(of: "chapter") {
            audiobookStem = String(folded[chapterRange.lowerBound...])
        } else {
            audiobookStem = folded.replacingOccurrences(
                of: #"^\s*\d+\s*[-_.]+\s*"#,
                with: "",
                options: .regularExpression
            )
        }
        return String(audiobookStem.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        })
    }

    private static func normalizedParentPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }
}
