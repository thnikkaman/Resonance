import Foundation

@main
struct LyricsCompanionMatcherFixture {
    static func main() {
        let hobbitFolder = "/Music/J.R.R. Tolkien/The Hobbit"
        let chapterPairs = [
            (
                audio: "01 - Chapter 01_ An Unexpected Party",
                lrc: "Chapter 01 - An Unexpected Party",
                normalized: "chapter1anunexpectedparty"
            ),
            (
                audio: "02 - Chapter 02_ Roast Mutton",
                lrc: "Chapter 02 - Roast Mutton",
                normalized: "chapter2roastmutton"
            ),
            (
                audio: "04 - Chapter 04_ Over Hill and Under Hill",
                lrc: "Chapter 04 - Over Hill and Under Hill",
                normalized: "chapter4overhillandunderhill"
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

        let prisonerAudio = "01 - Chapter 1_ “Owl Post”"
        let prisonerLRC = "Chapter 01 - Owl Post"
        precondition(
            LyricsCompanionMatcher.normalizedStem(prisonerAudio)
                == LyricsCompanionMatcher.normalizedStem(prisonerLRC)
        )
        precondition(
            LyricsCompanionMatcher.matchKey(parentPath: "/Music/J.K. Rowling/Prisoner of Azkaban", stem: prisonerAudio)
                == LyricsCompanionMatcher.matchKey(parentPath: "/Music/J.K. Rowling/Prisoner of Azkaban", stem: prisonerLRC)
        )
        let metadata = LyricsCompanionMatcher.metadata(from: Data("[ti:Chapter 1: Owl Post]\n[al:Harry Potter and the Prisoner of Azkaban]\n[tr:1]\n".utf8))
        precondition(metadata.map {
            LyricsCompanionMatcher.metadataMatches(
                $0,
                title: "Chapter 1: Owl Post",
                album: "Harry Potter and the Prisoner of Azkaban",
                artist: "Stephen Fry",
                trackNumber: 1,
                discNumber: 1
            )
        } == true)

        // The audiobook exporter writes CRLF metadata records and the title
        // itself contains a colon and curly apostrophes. Keep this exact
        // parser contract so the production format cannot regress to reading
        // only the first header record.
        let chamberOfSecretsCRLF = Data(
            "[ar:J.K. Rowling read by Stephen Fry]\r\n[al:Harry Potter and the Chamber of Secrets]\r\n[ti:Chapter 2: “Dobby’s Warning”]\r\n[00:00.00] CHAPTER TWO\r\n".utf8
        )
        let decodedCRLF = LyricsCompanionMatcher.metadata(from: chamberOfSecretsCRLF)
        precondition(decodedCRLF?.title == "Chapter 2: “Dobby’s Warning”")
        precondition(decodedCRLF?.album == "Harry Potter and the Chamber of Secrets")
        precondition(decodedCRLF?.artist == "J.K. Rowling read by Stephen Fry")
        precondition(decodedCRLF.map {
            LyricsCompanionMatcher.metadataMatches(
                $0,
                title: "Chapter 2: “Dobby’s Warning”",
                album: "Harry Potter and the Chamber of Secrets",
                artist: "J.K. Rowling read by Stephen Fry",
                trackNumber: 2,
                discNumber: 1
            )
        } == true)
        let utf16Metadata = Data(
            "[ti:Chapter 2: Dobby's Warning]\n[al:Harry Potter and the Chamber of Secrets]\n[tr:2]\n".utf16
                .flatMap { [UInt8($0 & 0xFF), UInt8($0 >> 8)] }
        )
        let decodedUTF16 = LyricsCompanionMatcher.metadata(from: utf16Metadata)
        precondition(decodedUTF16?.album == "Harry Potter and the Chamber of Secrets")
        precondition(decodedUTF16.map {
            LyricsCompanionMatcher.metadataMatches(
                $0,
                title: "Chapter 2: Dobby's Warning",
                album: "Harry Potter and the Chamber of Secrets",
                artist: "Stephen Fry",
                trackNumber: 2,
                discNumber: 1
            )
        } == true)

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

        print("Lyrics companion matcher fixture passed: Chapter 1/01 representation matched adjacent LRC")
    }
}
