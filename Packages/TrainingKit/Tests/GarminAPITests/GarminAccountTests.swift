import Foundation
import Synchronization
import Testing
@testable import GarminAPI

private let epoch = Date(timeIntervalSince1970: 1_000_000)

private func accessToken(exp: Int, clientId: String) -> String {
    func encode(_ text: String) -> String {
        Data(text.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    }
    return "\(encode(#"{"alg":"none"}"#)).\(encode(#"{"exp":\#(exp),"client_id":"\#(clientId)"}"#)).sig"
}

private func tokenBody(_ token: String, refresh: String? = "refresh-1") -> String {
    refresh.map { #"{"access_token":"\#(token)","refresh_token":"\#($0)"}"# } ?? #"{"access_token":"\#(token)"}"#
}

private func body(_ request: URLRequest) -> String {
    String(decoding: request.httpBody ?? Data(), as: UTF8.self)
}

private final class MemoryStore: GarminSessionStore {
    private let value: Mutex<GarminAccountSession?>

    init(_ session: GarminAccountSession?) {
        value = Mutex(session)
    }

    var session: GarminAccountSession? { value.withLock { $0 } }

    func load() throws -> GarminAccountSession? { value.withLock { $0 } }

    func save(_ session: GarminAccountSession) throws { value.withLock { $0 = session } }
}

@Suite struct GarminAccountTests {
    @Test func signInExchangesTicketForSession() async throws {
        let token = accessToken(exp: 1_100_000, clientId: "GARMIN_CONNECT_MOBILE_ANDROID_DI_2025Q2")
        let stub = StubTransport([
            .ok(#"{"responseStatus":{"type":"SUCCESSFUL"},"serviceTicketId":"ST-1"}"#),
            .ok(tokenBody(token)),
        ])

        let result = try await GarminAccountAuth(transport: stub).signIn(email: "a@b.c", password: "senha")

        #expect(result == .signedIn(GarminAccountSession(
            accessToken: token, refreshToken: "refresh-1", clientId: "GARMIN_CONNECT_MOBILE_ANDROID_DI_2025Q2",
            expiresAt: Date(timeIntervalSince1970: 1_100_000)
        )))
        let login = stub.requests[0]
        #expect(login.url?.path == "/mobile/api/login")
        #expect(login.url?.query?.contains("clientId=GCM_IOS_DARK") == true)
        #expect(body(login).contains(#""username":"a@b.c""#))
        let exchange = stub.requests[1]
        #expect(exchange.url == GarminAccountEndpoints.tokenURL)
        #expect(exchange.value(forHTTPHeaderField: "Authorization") == "Basic " + Data("GARMIN_CONNECT_MOBILE_ANDROID_DI_2025Q2:".utf8).base64EncodedString())
        #expect(body(exchange).contains("service_ticket=ST-1"))
    }

    @Test func signInAsksForCodeAndVerifiesIt() async throws {
        let token = accessToken(exp: 1_100_000, clientId: "GARMIN_CONNECT_MOBILE_IOS_DI")
        let stub = StubTransport([
            .ok(#"{"responseStatus":{"type":"MFA_REQUIRED"},"customerMfaInfo":{"mfaLastMethodUsed":"sms"}}"#),
            .ok(#"{"responseStatus":{"type":"SUCCESSFUL"},"serviceTicketId":"ST-2"}"#),
            .ok(tokenBody(token)),
        ])
        let auth = GarminAccountAuth(transport: stub)

        let first = try await auth.signIn(email: "a@b.c", password: "senha")
        #expect(first == .needsCode(GarminMFAChallenge(method: "sms")))
        let session = try await auth.verify(code: "123456", challenge: GarminMFAChallenge(method: "sms"))

        #expect(session.clientId == "GARMIN_CONNECT_MOBILE_IOS_DI")
        #expect(stub.requests[1].url?.path == "/mobile/api/mfa/verifyCode")
        #expect(body(stub.requests[1]).contains(#""mfaVerificationCode":"123456""#))
        #expect(body(stub.requests[2]).contains("service_ticket=ST-2"))
    }

    @Test func wrongPasswordAndWrongCodeAreReported() async throws {
        let wrongPassword = StubTransport([.ok(#"{"responseStatus":{"type":"INVALID_USERNAME_PASSWORD"}}"#)])
        await #expect(throws: GarminAccountError.invalidCredentials) {
            try await GarminAccountAuth(transport: wrongPassword).signIn(email: "a", password: "b")
        }
        let wrongCode = StubTransport([.ok(#"{"responseStatus":{"type":"INVALID_MFA_CODE"}}"#)])
        await #expect(throws: GarminAccountError.invalidCode) {
            try await GarminAccountAuth(transport: wrongCode).verify(code: "000000", challenge: GarminMFAChallenge(method: "email"))
        }
        let limited = StubTransport([.status(429, "")])
        await #expect(throws: GarminAccountError.rateLimited) {
            try await GarminAccountAuth(transport: limited).signIn(email: "a", password: "b")
        }
    }

    @Test func exchangeTriesNextClientId() async throws {
        let token = accessToken(exp: 1_100_000, clientId: "GARMIN_CONNECT_MOBILE_ANDROID_DI_2024Q4")
        let stub = StubTransport([
            .ok(#"{"responseStatus":{"type":"SUCCESSFUL"},"serviceTicketId":"ST-3"}"#),
            .status(400, #"{"error":"invalid_client"}"#),
            .ok(tokenBody(token)),
        ])

        let result = try await GarminAccountAuth(transport: stub).signIn(email: "a", password: "b")

        guard case .signedIn(let session) = result else { Issue.record("sem sessão"); return }
        #expect(session.clientId == "GARMIN_CONNECT_MOBILE_ANDROID_DI_2024Q4")
        #expect(body(stub.requests[2]).contains("client_id=GARMIN_CONNECT_MOBILE_ANDROID_DI_2024Q4"))
    }

    @Test func clientRefreshesSessionCloseToExpiry() async throws {
        let old = GarminAccountSession(accessToken: "old", refreshToken: "refresh-1", clientId: "C", expiresAt: epoch.addingTimeInterval(300))
        let renewed = accessToken(exp: 1_090_000, clientId: "C")
        let store = MemoryStore(old)
        let stub = StubTransport([.ok(tokenBody(renewed, refresh: nil)), .ok("[]")])
        let client = GarminAccountClient(transport: stub, store: store, now: { epoch })

        _ = try await client.get(GarminAccountEndpoints.coursesPath)

        #expect(body(stub.requests[0]).contains("grant_type=refresh_token"))
        #expect(stub.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer \(renewed)")
        #expect(stub.requests[1].url?.absoluteString == "https://connectapi.garmin.com/course-service/course")
        #expect(store.session?.accessToken == renewed)
        #expect(store.session?.refreshToken == "refresh-1")
    }

    @Test func clientRetriesOnceAfterUnauthorized() async throws {
        let valid = GarminAccountSession(accessToken: "valid", refreshToken: "refresh-1", clientId: "C", expiresAt: epoch.addingTimeInterval(36_000))
        let renewed = accessToken(exp: 1_090_000, clientId: "C")
        let stub = StubTransport([.status(401, ""), .ok(tokenBody(renewed)), .ok("{}")])
        let client = GarminAccountClient(transport: stub, store: MemoryStore(valid), now: { epoch })

        let data = try await client.get("/workout-service/workouts")

        #expect(String(decoding: data, as: UTF8.self) == "{}")
        #expect(stub.requests.count == 3)
        #expect(stub.requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer \(renewed)")
    }

    @Test func clientWithoutSessionAsksToSignIn() async throws {
        let client = GarminAccountClient(transport: StubTransport([]), store: MemoryStore(nil), now: { epoch })
        await #expect(throws: GarminAccountError.sessionExpired) {
            try await client.get(GarminAccountEndpoints.coursesPath)
        }
    }
}
