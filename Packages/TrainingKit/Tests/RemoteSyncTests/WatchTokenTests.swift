import CryptoKit
import Foundation
import Testing
@testable import RemoteSync

@Suite struct WatchTokenTests {
    @Test func generatesThirtyTwoBytesInBase64URLWithoutPadding() throws {
        let token = WatchToken.generate()

        #expect(token.count == 43)
        #expect(!token.contains("="))
        #expect(token.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
        #expect(Base64URL.decode(token)?.count == 32)
        #expect(WatchToken.generate() != token)
    }

    @Test func hashIsLowercaseSHA256HexOfDecodedBytes() throws {
        let token = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"
        let bytes = Data(0..<32)
        let expected = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()

        #expect(WatchToken.hash(token) == expected)
        #expect(WatchToken.hash(token)?.count == 64)
    }

    @Test func hashRejectsMalformedToken() {
        #expect(WatchToken.hash("curto") == nil)
        #expect(WatchToken.hash("AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=") == nil)
    }

    @Test func readinessTruncatesVerdictAndClampsScore() {
        let readiness = WatchReadiness(day: "2026-11-12", score: 130, verdict: String(repeating: "a", count: 30))

        #expect(readiness.verdict.count == 24)
        #expect(readiness.score == 100)
        #expect(WatchReadiness(day: "2026-11-12", score: -4, verdict: "x").score == 0)
        let decomposed = String(repeating: "e\u{301}", count: 13)
        #expect(WatchReadiness(day: "2026-11-12", score: 50, verdict: decomposed).verdict.unicodeScalars.count == 24)
    }
}
