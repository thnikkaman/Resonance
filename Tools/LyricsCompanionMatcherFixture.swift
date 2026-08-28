import Foundation

@main
struct LyricsCompanionMatcherFixture {
    static func main() {
        let hobbitFolder = "/Music/J.R.R. Tolkien/The Hobbit"
        let chapterPairs = [
            (
                audio: "01 - Chapter 01_ An Unexpected Party",
                lrc: "Chapter 01 - An Unexpected Party",
                normalized: "chapter01anunexpectedparty"
            ),
            (
                audio: "02 - Chapter 02_ Roast Mutton",
                lrc: "Chapter 02 - Roast Mutton",
                normalized: "chapter02roastmutton"
            ),
            (
                audio: "04 - Chapter 04_ Over Hill and Under Hill",
                lrc: "Chapter 04 - Over Hill and Under Hill",
                normalized: "chapter04overhillandunderhill"
            )
        ]

        for pair in chapterPairs {
            precondition(LyricsCompanionMatcher.normalizedStem(pair.audio) == pair.normalized)
            precondition(LyricsCompanionMatcher.normalizedStem(pair.lrc) == pair.normalized)
            precondition(
                LyricsCompanionMatcher.matchKey(parentPath: hobbitFolder, stem: pair.audio)
                    == LyricsCompanionMatcher.matchKey(parentPath: hobbitFolder, stem: pair.lrc)
            )
        }

        precondition(
            LyricsCompanionMatcher.matchKey(parentPath: hobbitFolder, stem: chapterPairs[0].audio)
                != LyricsCompanionMatcher.matchKey(parentPath: hobbitFolder, stem: chapterPairs[1].lrc)
        )
        precondition(
            LyricsCompanionMatcher.matchKey(parentPath: hobbitFolder, stem: chapterPairs[0].audio)
                != LyricsCompanionMatcher.matchKey(
                    parentPath: "/Music/Another Audiobook",
                    stem: chapterPairs[0].lrc
                )
        )

        print("Lyrics companion matcher fixture passed: exact device Chapter 01 representation matched adjacent LRC")
    }
}
