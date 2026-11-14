import Foundation
import GarminAPI
import RemoteSync
import Synchronization
import Testing
@testable import trAIning

private final class LinkTransport: HTTPTransport {
    private let replies: Mutex<[(Int, String)]>
    private let paths = Mutex<[String]>([])

    init(_ replies: [(Int, String)]) {
        self.replies = Mutex(replies)
    }

    var requested: [String] { paths.withLock { $0 } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        paths.withLock { $0.append("\(request.httpMethod ?? "") \(request.url?.path ?? "")") }
        let (status, body) = replies.withLock { $0.isEmpty ? (500, "") : $0.removeFirst() }
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

@MainActor
@Suite struct GarminLinkModelTests {
    private static let session = #"{"accessToken":"a","refreshToken":"r","clientId":"C","expiresAt":"2026-11-14T13:00:00.000Z"}"#

    private func model(_ transport: LinkTransport, keychain: MemoryKeyStore) -> GarminAccountModel {
        let model = GarminAccountModel(store: KeychainGarminSessionStore(keychain: keychain), makeTransport: { transport })
        model.link = { GarminLinkClient(baseURL: URL(string: "https://sync.example.test")!, token: "sessao", transport: transport) }
        return model
    }

    @Test func codeFlowGoesThroughTheServerAndKeepsTheSession() async throws {
        let transport = LinkTransport([
            (200, #"{"status":"needs_code","method":"email"}"#),
            (200, #"{"status":"connected"}"#),
            (200, Self.session),
        ])
        let keychain = MemoryKeyStore()
        let garmin = model(transport, keychain: keychain)

        await garmin.signIn(email: "a@b.com", password: "x")
        let askedCode = garmin.phase == .needsCode(GarminMFAChallenge(method: "email"))
        await garmin.verify(code: "123456")

        #expect(askedCode)
        #expect(garmin.isSignedIn)
        #expect(transport.requested == ["POST /api/v1/garmin/connect", "POST /api/v1/garmin/verify", "GET /api/v1/garmin/session"])
        #expect(try keychain.read()?.contains("\"accessToken\":\"a\"") == true)
    }

    @Test func newDeviceAdoptsTheAccountSessionWithoutLogin() async {
        let transport = LinkTransport([(200, Self.session)])
        let garmin = model(transport, keychain: MemoryKeyStore())

        await garmin.adoptAccountSession()

        #expect(garmin.isSignedIn)
    }

    @Test func accountWithoutGarminStaysSignedOut() async {
        let transport = LinkTransport([(404, #"{"error":"garmin_not_connected"}"#)])
        let garmin = model(transport, keychain: MemoryKeyStore())

        await garmin.adoptAccountSession()

        #expect(!garmin.isSignedIn)
    }

    @Test func expiredCodeAsksForLoginAgain() async {
        let transport = LinkTransport([
            (200, #"{"status":"needs_code","method":"email"}"#),
            (409, #"{"error":"garmin_login_expired"}"#),
        ])
        let garmin = model(transport, keychain: MemoryKeyStore())

        await garmin.signIn(email: "a@b.com", password: "x")
        await garmin.verify(code: "123456")

        #expect(garmin.phase == .idle)
        #expect(garmin.message == GarminAccountConstants.loginExpired)
    }
}
