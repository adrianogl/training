import Foundation
import GarminAPI
import Synchronization
import Testing
@testable import trAIning

private final class AccountTransport: HTTPTransport {
    private let replies: Mutex<[(Int, String)]>
    private let sent = Mutex<[URLRequest]>([])

    init(_ replies: [(Int, String)]) {
        self.replies = Mutex(replies)
    }

    var requests: [URLRequest] { sent.withLock { $0 } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        sent.withLock { $0.append(request) }
        let (status, body) = replies.withLock { $0.isEmpty ? (500, "") : $0.removeFirst() }
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

@MainActor
@Suite struct AccountModelTests {
    private static let user = #"{"email":"atleta@exemplo.com","name":"Atleta","emailVerified":false}"#
    private static let baseURL = URL(string: "https://sync.example.test")!

    private func model(_ transport: AccountTransport, store: MemoryKeyStore = MemoryKeyStore()) -> (AccountModel, UserDefaults) {
        let defaults = UserDefaults(suiteName: "account-\(UUID().uuidString)")!
        return (AccountModel(store: store, transport: transport, baseURL: Self.baseURL, defaults: defaults, device: "iPhone"), defaults)
    }

    @Test func signupSavesSessionAndSendsLegacyKey() async throws {
        let transport = AccountTransport([(201, #"{"token":"sessao","user":\#(Self.user)}"#)])
        let store = MemoryKeyStore()
        let (account, _) = model(transport, store: store)
        account.legacyKey = { "legado" }

        let ok = await account.signup(name: "Atleta", email: "atleta@exemplo.com", password: "corrida-longa-42")

        let body = try JSONDecoder().decode([String: String].self, from: try #require(transport.requests.first?.httpBody))
        #expect(ok)
        #expect(account.isSignedIn)
        #expect(try store.read() == "sessao")
        #expect(body["legacyKey"] == "legado")
        #expect(body["device"] == "iPhone")
    }

    @Test func wrongLoginShowsMessageAndStaysSignedOut() async {
        let transport = AccountTransport([(401, #"{"error":"invalid_credentials"}"#)])
        let (account, _) = model(transport)

        let ok = await account.login(email: "atleta@exemplo.com", password: "errada-1234")

        #expect(!ok)
        #expect(!account.isSignedIn)
        #expect(account.errorMessage == AccountConstants.invalidCredentials)
    }

    @Test func revokedSessionSignsOutOnRefresh() async throws {
        let transport = AccountTransport([(401, #"{"error":"unauthorized"}"#)])
        let store = MemoryKeyStore("sessao")
        let (account, _) = model(transport, store: store)
        var signedOut = false
        account.onSignedOut = { _ in signedOut = true }

        await account.refresh()

        #expect(!account.isSignedIn)
        #expect(try store.read() == nil)
        #expect(signedOut)
    }

    @Test func wrongCurrentPasswordGetsItsOwnMessage() async {
        let transport = AccountTransport([(401, #"{"error":"invalid_credentials"}"#)])
        let (account, _) = model(transport, store: MemoryKeyStore("sessao"))

        let ok = await account.changePassword(current: "errada-1234", next: "nova-senha-123", endOtherSessions: true)

        #expect(!ok)
        #expect(account.errorMessage == AccountConstants.wrongCurrent)
    }

    @Test func userSurvivesRelaunchFromDefaults() async {
        let transport = AccountTransport([(200, #"{"token":"sessao","user":\#(Self.user)}"#)])
        let store = MemoryKeyStore()
        let (account, defaults) = model(transport, store: store)
        _ = await account.login(email: "atleta@exemplo.com", password: "corrida-longa-42")

        let relaunched = AccountModel(store: store, transport: transport, baseURL: Self.baseURL, defaults: defaults, device: "iPhone")

        #expect(relaunched.isSignedIn)
        #expect(relaunched.user?.name == "Atleta")
    }
}

@MainActor
@Suite struct AccountWebOnlyTests {
    @Test func guestLoginFromTheAppShowsTheWebNotice() async {
        let transport = AccountTransport([(403, #"{"error":"web_only"}"#)])
        let defaults = UserDefaults(suiteName: "account-\(UUID().uuidString)")!
        let account = AccountModel(store: MemoryKeyStore(), transport: transport, baseURL: URL(string: "https://sync.example.test")!, defaults: defaults, device: "iPhone")

        let ok = await account.login(email: "marina@exemplo.com", password: "corrida-longa-42")

        #expect(!ok)
        #expect(account.webOnly)
        #expect(!account.isSignedIn)
        #expect(transport.requests.first?.value(forHTTPHeaderField: "X-Training-Client") == "app")
    }
}
