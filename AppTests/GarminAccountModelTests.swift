import Foundation
import GarminAPI
import Synchronization
import Testing
@testable import trAIning

private final class ScriptedTransport: HTTPTransport {
    private let replies: Mutex<[(Int, String)]>

    init(_ replies: [(Int, String)]) {
        self.replies = Mutex(replies)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (status, body) = replies.withLock { $0.isEmpty ? (500, "") : $0.removeFirst() }
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

private func accessToken(exp: Int) -> String {
    func encode(_ text: String) -> String {
        Data(text.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    }
    return "\(encode(#"{"alg":"none"}"#)).\(encode(#"{"exp":\#(exp),"client_id":"C"}"#)).sig"
}

@MainActor
@Suite struct GarminAccountModelTests {
    @Test func codeFlowSavesOnlyTheSession() async throws {
        let keychain = MemoryKeyStore()
        let transport = ScriptedTransport([
            (200, #"{"responseStatus":{"type":"MFA_REQUIRED"},"customerMfaInfo":{"mfaLastMethodUsed":"email"}}"#),
            (200, #"{"responseStatus":{"type":"INVALID_MFA_CODE"}}"#),
            (200, #"{"responseStatus":{"type":"SUCCESSFUL"},"serviceTicketId":"ST-1"}"#),
            (200, #"{"access_token":"\#(accessToken(exp: 4_000_000_000))","refresh_token":"r"}"#),
        ])
        let model = GarminAccountModel(store: KeychainGarminSessionStore(keychain: keychain), makeTransport: { transport })

        await model.signIn(email: " corredor@exemplo.com ", password: "segredo")
        #expect(model.phase == .needsCode(GarminMFAChallenge(method: "email")))
        #expect(model.message == "O Garmin mandou um código por e-mail.")

        await model.verify(code: "000000")
        #expect(model.message == GarminAccountConstants.invalidCode)
        #expect(!model.isSignedIn)

        await model.verify(code: "123456")
        #expect(model.isSignedIn)
        #expect(model.phase == .idle)
        let stored = try #require(try keychain.read())
        #expect(!stored.contains("segredo"))
        #expect(stored.contains("\"refreshToken\":\"r\""))

        model.signOut()
        #expect(!model.isSignedIn)
        #expect(try keychain.read() == nil)
    }

    @Test func wrongPasswordShowsMessage() async {
        let transport = ScriptedTransport([(200, #"{"responseStatus":{"type":"INVALID_USERNAME_PASSWORD"}}"#)])
        let model = GarminAccountModel(store: KeychainGarminSessionStore(keychain: MemoryKeyStore()), makeTransport: { transport })

        await model.signIn(email: "a", password: "b")

        #expect(model.message == GarminAccountConstants.invalidCredentials)
        #expect(model.phase == .idle)
    }
}
