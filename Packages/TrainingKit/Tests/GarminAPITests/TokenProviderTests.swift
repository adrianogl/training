import Foundation
import Testing
@testable import GarminAPI

private let epoch = Date(timeIntervalSince1970: 1_000_000)

private func provider(_ stub: StubTransport) -> TokenProvider {
    TokenProvider(apiKey: "k", baseURL: GarminEndpoints.base, transport: stub, now: { epoch })
}

@Test func exchangesKeyAndCachesToken() async throws {
    let jwt = makeJWT(exp: 1_000_000 + 86_400)
    let stub = StubTransport([.ok(jwt + "\n")])
    let p = provider(stub)
    #expect(try await p.bearer() == jwt)
    #expect(try await p.bearer() == jwt)
    #expect(stub.requests.count == 1)
    #expect(stub.requests[0].httpMethod == "POST")
    #expect(stub.requests[0].value(forHTTPHeaderField: "Authorization") == "ApiKey k")
    #expect(stub.requests[0].value(forHTTPHeaderField: "Accept") == "*/*")
    #expect(stub.requests[0].url == GarminEndpoints.base.appending(path: GarminEndpoints.tokenPath))
}

@Test func refreshesWhenLessThanOneHourLeft() async throws {
    let first = makeJWT(exp: 1_000_000 + 3599)
    let second = makeJWT(exp: 1_000_000 + 86_400)
    let stub = StubTransport([.ok(first), .ok(second)])
    let p = provider(stub)
    #expect(try await p.bearer() == first)
    #expect(try await p.bearer() == second)
    #expect(stub.requests.count == 2)
}

@Test func invalidateForcesNewExchange() async throws {
    let jwt = makeJWT(exp: 1_000_000 + 86_400)
    let stub = StubTransport([.ok(jwt), .ok(jwt)])
    let p = provider(stub)
    _ = try await p.bearer()
    await p.invalidate()
    _ = try await p.bearer()
    #expect(stub.requests.count == 2)
}

@Test(arguments: [(401, GarminAPIError.invalidKey), (403, .invalidKey), (400, .invalidKey), (429, .rateLimited), (503, .server(status: 503))])
func tokenExchangeMapsStatus(status: Int, expected: GarminAPIError) async {
    let p = provider(StubTransport([.status(status, "")]))
    await #expect(throws: expected) { try await p.bearer() }
}

@Test func jwtWithoutExpIsInvalidKey() async {
    let p = provider(StubTransport([.ok(makeJWT(exp: nil))]))
    await #expect(throws: GarminAPIError.invalidKey) { try await p.bearer() }
}
